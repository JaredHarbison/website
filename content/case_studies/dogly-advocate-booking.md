---
title: Dogly Advocate Booking
summary: Building a reliable booking and paid-entitlement lifecycle inside a mature Rails marketplace, from package purchase through scheduling, fulfillment, and operations.
hero_image: /images/dogly-advocate-booking-system.svg
hero_alt: System context diagram showing members, advocates, and admins using Dogly's Rails booking domain, with PostgreSQL as the durable source of truth; Stripe, Zoom, and email are active integrations, while Google Calendar is implemented for later rollout.
date: 2026-10-08
order: 9
role: Senior Software Engineer
technologies:
  - Ruby on Rails
  - PostgreSQL
  - Stripe
  - Zoom
  - Google Calendar
  - RSpec
tags:
  - Rails
  - Product Engineering
  - Payments
  - Distributed Systems
  - Reliability
status: published
project_status: in_progress
---

## Overview

Dogly's advocate booking work turned a set of marketplace capabilities—paid consultation packages, advocate availability, member requests, and live meetings—into one coordinated system. The hard part was not drawing a calendar. It was preserving correct behavior when people, payment providers, database transactions, and external integrations move at different speeds and fail at different boundaries.

This case study is also a useful walkthrough of how I approach a complex feature in a mature Rails application: start at the user journey, identify the durable business facts, make state transitions explicit, then put correctness checks at more than one layer.

## Problem

Members needed to discover a package, pay for it, use its booking credits, request a time, and manage the resulting appointment. Advocates needed control over package terms and availability, and the ability to confirm, decline, or request changes. Admins needed operational visibility and safe intervention paths.

Those flows cross several failure boundaries. A browser can close after checkout starts. A payment webhook can be retried. Two members can request the same slot at nearly the same time. A meeting provider can fail after a booking has been confirmed. Cancellation rules can affect both appointment state and a member's remaining credits.

The system therefore needed to make payment, booking, entitlement, and provider work consistent without pretending they were one synchronous request.

## Context

Dogly is an established Rails marketplace, not a greenfield scheduling application. The booking domain had to coexist with existing users, advocates, plans, admin workflows, email, and payment conventions. The implementation uses Rails controllers and views for the product surfaces, service objects for consequential transitions, PostgreSQL for durable state and concurrency enforcement, and explicit adapters/reconcilers around external providers.

The system is being delivered incrementally. The architecture and workflows described here are implemented in the application, while operational rollout and remaining product decisions continue to evolve. No conversion, revenue, or reliability metric is claimed here.

## Constraints

- Preserve the existing Rails application and marketplace identity model.
- Never grant booking credits based only on a browser redirect from checkout.
- Prevent overlapping active bookings even when requests race.
- Preserve a traceable explanation for credit balances and booking transitions.
- Make retries safe across payment callbacks and durable asynchronous calendar/notification work.
- Enforce package, advocate, and global policy rules at the domain boundary.
- Keep member, advocate, and admin permissions distinct.
- Handle time zones, buffers, time off, and group events when showing availability.

## My Role

As Dogly's sole engineer, I designed and implemented the booking domain across its data model, migrations, Rails controllers, service layer, provider boundaries, and tests. That included purchase reconciliation, credit accounting, availability and slot integrity, booking lifecycle transitions, operational surfaces, and asynchronous follow-up work.

I also made the work reviewable as a sequence of bounded changes: foundational data and invariants first, then purchase and booking workflows, then the user-facing and operational behavior that depends on those foundations.

## Approach

I organized the system around three related but separate records:

1. A purchase attempt tracks the provider checkout and its reconciliation state.
2. A booking entitlement tracks the purchased quantity and its credit movements.
3. An advocate booking tracks the appointment lifecycle.

Separating them avoids overloading one status field with unrelated facts. A successful payment can activate an entitlement; a later booking reserves a credit; confirmation consumes it; an eligible cancellation can restore it. Each transition has its own rules and audit trail.

The architecture has layered defenses. The request/controller boundary checks identity and authorization. Domain services re-check mutable rules inside the transition. Row locks protect balance changes. PostgreSQL constraints arbitrate conflicting slot writes. Provider event keys and outbox idempotency keys make repeated external signals safe to process.

![Dogly Advocate Booking system context: the Rails booking domain coordinates member, advocate, and admin workflows while PostgreSQL owns durable state; Google Calendar is implemented for later user-facing rollout.](/images/dogly-advocate-booking-system.svg)

*System context: Rails coordinates domain transitions; PostgreSQL owns durable integrity; Stripe, Zoom, calendar, and email effects cross explicit boundaries. Google Calendar sync is implemented but held for later user-facing rollout.*

## Technical Implementation

### Purchase and verified entitlement activation

`Bookings::PurchaseService` creates a durable purchase attempt and snapshots the package terms and price before creating hosted checkout. It uses an idempotency key so a retry can recover the same purchase rather than creating another one.

Stripe's signed event is reconciled independently of the browser return URL. The reconciler correlates the provider event to the purchase attempt, checks the expected metadata, amount, and currency, deduplicates the provider event, then locks and updates the purchase state in a database transaction. Only after successful reconciliation does the system activate booking credits and enqueue the appropriate follow-up events.

![Sequence diagram showing checkout creation, signed payment event verification, locked purchase reconciliation, entitlement activation, and queued notifications.](/images/dogly-advocate-booking-purchase.svg)

*A successful redirect is not payment truth. The verified provider event is the point at which the entitlement becomes available.*

### Booking lifecycle and credit ledger

`Bookings::LifecycleService` owns important booking transitions: requesting, confirmation, decline, cancellation, updates, and the related credit reservation or release. It checks the actor's authority and current policy, records booking events, and coordinates the entitlement change with the booking change.

The entitlement has an append-only entry history for activation, reservation, release, consumption, adjustment, refund, and forfeiture. Balance changes occur under a row lock. This gives the product an explainable ledger instead of treating a mutable integer as the only evidence of what happened.

![Advocate booking lifecycle state machine showing hold, pending, needs-update, confirmed, cancelled, and completed states, with credit effects labeled on transitions.](/images/dogly-advocate-booking-lifecycle.svg)

*Booking state and credit effects move together through explicit, authorized transitions.*

![Booking entitlement ledger showing purchased credits moving through available, reserved, consumed, refunded, and forfeited balances, with each movement recorded in an append-only entry history.](/images/dogly-advocate-booking-ledger.svg?rev=20261008-ledger-lock-routing)

*The ledger explains the balance: each state change is a recorded movement, not an unexplained overwrite.*

### Availability and concurrency

Availability is computed with the advocate's time zone, recurring windows, time off, existing bookings, group meetings, and configured buffers in view. The application can guide a member toward an apparently open start time, but that query is only a snapshot: another request may arrive before the first one is saved.

For that reason, PostgreSQL is the final arbiter. The booking schema enables `btree_gist` and uses an exclusion constraint over advocate identity and a time range for conflicting active states, including temporary holds. The service still handles the expected conflict as a domain outcome; the database constraint closes the race that a UI or preflight availability check cannot.

![Layered booking correctness diagram showing authorization and policy checks, transactional service validation, locked domain state, and PostgreSQL exclusion and uniqueness constraints.](/images/dogly-advocate-booking-correctness.svg)

*Two requests may both pass an early availability check; the database constraint ensures only one conflicting booking can commit.*

### External effects and operations

The application records follow-up work in an outbox with unique idempotency keys. Email and Google Calendar synchronization use durable, asynchronous outbox processing; Google Calendar sync is implemented but intentionally held for later user-facing rollout. Virtual meeting provisioning runs synchronously after the confirmation transaction, so Zoom/provider or local-persistence failures remain a hardening area rather than a retryable outbox flow.

The admin workflow provides visibility into bookings and purchase attempts, with policy, venue, and operational controls kept separate from member-facing actions. This matters because support needs to understand the durable state and its history, not infer it from a failed browser session or a provider dashboard alone.

## Tradeoffs

The design has more records and explicit transitions than a minimal `Booking` table with a `credits_remaining` field. That adds migration, service, and test surface, but it makes payment reconciliation, concurrent scheduling, refunds, and support investigations substantially easier to reason about.

The database constraint intentionally duplicates some availability logic. The application check improves the user experience; the constraint protects correctness. They solve different problems and should not be collapsed into one layer.

External provider work is kept outside the core booking transaction. Calendar and notification work are asynchronous through the outbox, while Zoom provisioning currently runs synchronously after confirmation.

## Outcome

The implementation establishes an end-to-end booking foundation in the existing Rails product:

- Members can purchase booking packages and use the resulting entitlement to request time.
- Payment is reconciled from verified provider events, not inferred from a redirect.
- Booking transitions and credit movements are explicit and auditable.
- PostgreSQL protects against conflicting active slot writes under concurrency.
- Calendar and notification work use durable outbox processing; meeting provisioning is separated from the booking transaction and remains a current hardening area.
- Member, advocate, and admin workflows share one domain model while retaining distinct authorization rules.

The system's value is the set of invariants and recovery paths it makes explicit. Business impact and production reliability improvements have not been quantified here.

## What I'd Improve Today

I would add end-to-end observability across purchase attempt, provider event, entitlement, booking, and outbox identifiers. That would make a single support investigation traceable across the whole lifecycle without joining the evidence manually.

I would also add operational dashboards and alert thresholds for stale purchase attempts, repeatedly failing outbox events, and provider provisioning failures. The data model supports investigation, but durable records are most useful when the team can see which ones need attention.

Finally, I would expand concurrency and recovery tests around real PostgreSQL behavior, especially simultaneous slot claims, duplicate and out-of-order provider events, and retries after partial external failure. Those are the boundaries where the architecture earns its complexity.
