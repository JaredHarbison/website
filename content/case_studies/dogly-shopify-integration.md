---
title: Evolving Dogly's Shopify Integration
navigation_title: Dogly Shopify Integration
summary: Evolving a production customer-acquisition integration into a carefully staged architecture for catalog reconciliation and multi-brand fulfillment.
date: 2026-07-10
role: Senior Software Engineer
technologies:
  - Ruby on Rails
  - PostgreSQL
  - Shopify Admin API
  - Spree Commerce
  - Active Job
  - RSpec
tags:
  - Rails
  - Integrations
  - Commerce
  - Architecture
  - Legacy Systems
  - Testing
status: published
---

## Overview

Dogly connects dog owners with independent brands, shelters, and professional advocates. Its marketplace runs on Spree inside a mature Rails application, while many partner brands operate their own Shopify stores.

The Shopify work evolved in two distinct stages. The first, launched in late 2025, brought eligible brand customers into Dogly through signed order webhooks and a configurable invitation sequence. The second, developed and tested through a limited rollout in 2026, addressed the other direction: sending Dogly marketplace orders to a brand's Shopify store for fulfillment while reconciling catalog and inventory data between the two systems.

The hard part was not making API requests. It was deciding which system owned customers, products, inventory, orders, and fulfillment state—and designing duplicate guards and retry boundaries around partial failure.

![Shopify integration boundaries](/images/shopify-integration-boundaries.svg)

## Problem

Dogly needed to support brands without asking them to abandon the systems they already used.

For customer acquisition, a qualifying Shopify purchase could introduce someone to Dogly's expert content and membership product. That required ingesting order events, identifying eligible products, associating customers safely, and scheduling brand-specific outreach.

For marketplace fulfillment, a Dogly order could contain products from multiple brands. Each brand needed only its own line items in its own Shopify store. Product and inventory data also needed a durable mapping across two catalogs that used different identifiers and did not always share clean SKUs.

## Constraints

- Preserve an existing Spree checkout and order lifecycle.
- Configure credentials, product filters, and invitation timing per brand.
- Acknowledge webhooks quickly and perform slower work asynchronously.
- Treat webhook delivery as at-least-once and make repeated processing safe at each side effect.
- Split multi-brand orders without leaking another brand's line items.
- Avoid making either catalog an accidental second source of truth.
- Support operator review when automatic SKU or name matching was uncertain.
- Roll the fulfillment path out incrementally and be willing to pull it back when checkout assumptions were not yet safe enough.

## My Role

As Dogly's sole engineer, I owned the work from technical planning through implementation and production support for the acquisition path, plus the design, implementation, and limited rollout of the fulfillment path. That included the webhook boundary, background jobs, customer association, invitation sequencing, per-brand configuration, order transmission, catalog import and reconciliation, inventory mapping, admin workflows, and focused tests around failure-prone paths.

I also worked directly with the founders to separate the immediate business need from the larger integration platform. That distinction kept the first customer-acquisition workflow small enough to launch while giving the later commerce work clearer boundaries.

## Stage One: Customer Acquisition

The first integration accepts signed Shopify order webhooks for a configured brand. The controller does very little: find the brand, verify the HMAC signature with a constant-time comparison, enqueue the raw payload, and return promptly.

The background processor then checked whether the order contained an eligible product. If so, it found or created the customer in Dogly, recorded the Shopify relationship, associated the order, and scheduled the configured invitation sequence.

Several duplicate guards were necessary because there was no single universal definition of "already processed":

- Customer email lookup, backed by the existing account constraint, prevented duplicate Dogly accounts; the processor also recovered from a concurrent-create race.
- Shopify customer and order notes preserved the external relationship.
- Order-plus-day markers let invitation jobs skip work already recorded as sent.
- Jobs rechecked state when they ran instead of trusting the state that existed when they were scheduled.

That last point mattered for delayed jobs. A customer might accept an invitation, unsubscribe, or receive another order between scheduling and execution.

## Stage Two: Marketplace Fulfillment

The fulfillment direction introduced a different ownership model. Dogly remained the customer-facing marketplace and source of the complete order. Each Shopify store received a brand-specific fulfillment order containing only its products.

The staged transmission flow grouped line items by brand, selected only brands configured for Shopify fulfillment, built a no-charge Shopify order, and recorded the returned external order ID against the Dogly order.

![Order transmission sequence](/images/shopify-order-sequence.svg)

Recording external IDs per brand made retries safer. Before transmitting, the service checked whether that brand's portion had already succeeded instead of resending the entire marketplace order. This was a pragmatic guard, not a fully atomic idempotency guarantee; a timeout after Shopify accepted an order but before Dogly persisted the ID remained a failure mode to solve before broader release.

Fulfillment webhooks traveled in the reverse direction. After signature verification, they located the corresponding Dogly shipment and recorded tracking and shipment state without re-running unrelated checkout behavior.

## Catalog Reconciliation

Catalog synchronization could not depend on perfect SKUs. Some products matched cleanly by SKU, some only by normalized name, and some required a person to decide.

The admin reconciliation workflow therefore separated three states:

- Already linked.
- Suggested match.
- Unmatched Shopify product.

An operator could confirm a proposed match, import a new product, ignore an irrelevant item, or revisit a partial import. Imported variants retained Shopify variant and inventory-item identifiers so later inventory events did not have to repeat fuzzy matching.

Images were imported through background jobs after the product transaction committed. That kept remote downloads outside the database transaction and made image failure recoverable without rolling back an otherwise valid catalog record.

## Operational Lessons

The fulfillment and catalog work went through integration, rollback, and selective restoration as it met the realities of the mature checkout code and overlapping feature branches. I did not treat a completed implementation as proof that the operational model was ready. The rollout exposed assumptions about payment timing, stock locations, variant ownership, and merge boundaries that were safer to discover at limited scope than after broad adoption.

The implementation added explicit logging, surfaced transaction rollback errors, and provided admin-visible states for missing credentials, taxonomy, option types, and SKU conflicts. The goal was to make incomplete work diagnosable rather than silently wrong. Catalog and configuration tooling could be restored independently while automated order transmission remained held back.

## Outcome

More than 1,000 retained Dogly user records carry a Shopify-customer association from the production acquisition path for our limited rollout to a single product from a single brand in the first month. That is a measure of records connected to the channel—not a claim that every recipient activated or became a paid member. The integration turned partner purchases into configurable onboarding while guarding against duplicate accounts and repeated invitation sequences.

The later commerce work established and exercised the boundaries for per-brand order transmission, fulfillment callbacks, catalog reconciliation, product import, and inventory mapping. The limited rollout produced synchronized catalog and order records, but automated fulfillment was not broadly released; the safer outcome was retaining useful administrative tooling while revisiting the checkout boundary.

The most durable outcome was a clearer model of ownership: Dogly owns the marketplace order and customer experience; partner stores own fulfillment and their source catalog; explicit external identifiers connect the two. Just as importantly, the rollout established where that model still needed stronger guarantees before expansion.

## What I'd Improve Today

I would formalize every cross-system operation around a persisted integration event with a unique idempotency key, payload digest, state, attempt count, and last error. The existing notes and external-ID mappings cover important duplicate cases, but a common event model with database-enforced uniqueness would close the timeout gap and make replay and support work easier.

I would also make the staged rollout explicit through per-brand feature states rather than relying on configuration presence alone. A state such as disabled, shadowing, catalog-only, and fulfillment-live would better communicate operational intent.

I would also set up partner-specific packing inserts that highlight Dogly and guide customers toward follow-up engagement after fulfillment. That would give each brand a lightweight, consistent way to extend the experience beyond the shipment itself.

Finally, I would add contract tests around recorded Shopify payloads and a full integration test covering a multi-brand order in which one transmission succeeds and another fails. That is the scenario where clear retry boundaries matter most.
