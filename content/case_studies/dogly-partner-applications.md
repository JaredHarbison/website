---
title: Dogly Partner Applications
summary: Designing a resumable Advocate application and transparent review workflow inside a mature Rails marketplace without forcing a platform rewrite.
date: 2026-07-08
order: 4
role: Senior Software Engineer
technologies:
  - Ruby on Rails
  - PostgreSQL
  - Stimulus
  - Haml
  - SCSS
  - RSpec
tags:
  - Rails
  - Product Engineering
  - Onboarding
  - Legacy Systems
  - Testing
status: published
---

## Overview

Dogly is a Rails marketplace and community product connecting dog owners with professional advocates, brands, and shelters. The codebase has years of accumulated product surface: ecommerce, community content, subscriptions, advocate profiles, admin tools, reporting, and partner management.

Partner Pro established shared entry points for Dogly's partner ecosystem, while its guided application and review lifecycle was first implemented for Advocates. The work covered resumable onboarding, credential management, admin review, and applicant-visible revisions.

The important engineering challenge was not just adding screens. It was introducing a new product flow into a mature Rails application without destabilizing the existing routes, models, and operational assumptions.

## Problem

Dogly needed a clearer path for professionals to apply and a more transparent way to review those applications.

The previous system had the underlying data concepts, but the experience was fragmented:

- Partner applications existed, but did not fully support a guided, resumable onboarding flow.
- Admin review needed better structure around edits, approval, and applicant-facing feedback.
- Credentials and certifications needed to support both existing options and applicant-submitted entries.
- Public pages for advocates, brands, and shelters needed to share patterns without becoming copy-pasted implementations.

The business need was to reduce friction in partner acquisition while improving trust in the review process.

## Context

This was not a greenfield app. Dogly is an older Rails application with existing conventions, a large route file, Haml views, SCSS page styles, RSpec coverage, Solidus-related commerce concepts, and domain models that had evolved over time.

That context shaped the approach. The safest path was to extend Rails conventions already present in the app: controllers, service objects, query objects, Haml partials, model methods, and focused specs.

The work also had to coexist with existing advocate routes. Partner application routes needed to sit before broad advocate slug routes so onboarding URLs were interpreted correctly.

## Constraints

The main constraints were architectural and product-related:

- Avoid a wholesale rewrite of the partner system.
- Preserve existing public advocate pages and admin workflows.
- Keep controllers understandable despite multi-step onboarding.
- Let anonymous applicants resume draft progress through an expiring, unguessable session token stored in an HTTP-only cookie, while still associating applications with users when available.
- Handle geocoding gracefully when a typed location or browser coordinates were available.
- Avoid overwriting saved application data with blank autosave payloads.
- Make admin edits visible to applicants without exposing internal implementation details.
- Keep the multi-step flow responsive and keyboard usable.

There was also a content-management constraint: many public-facing page sections used configurable copy and images, so the implementation needed to fit that system rather than hard-coding every page.

## My Role

I worked across the Rails stack:

- Designed and implemented the Partner Pro onboarding flow.
- Built the application session manager around JSON-backed step data.
- Added admin review behavior, revision tracking, and applicant-facing review states.
- Connected credentials and applicant-submitted certifications into the application process.
- Established shared partner entry points and directory patterns for advocates, brands, and shelters.
- Wrote focused specs around controller behavior, revision diffs, helpers, and the application lifecycle.

The work was product-minded: every technical choice had to support a clearer application and review experience, not just a cleaner code structure.

## Approach

I separated the work into a few durable boundaries.

First, the onboarding flow became session-based. A `PartnerApplicationSession` stores the current step, a secure token, expiration, completion state, and accumulated JSON data. A small `Partners::ApplicationSessionManager` owns the mechanics of creating sessions, saving steps, merging autosave data, exposing the token, and completing the session.

Second, the final persisted `PartnerApplication` remains the durable business record. The session is a draft workspace; the application is the submitted artifact.

Third, admin review became explicit. Admin edits can move an application into review, record a revision log, and show applicants what changed in a review-oriented version of the same onboarding UI.

## Technical Implementation

The onboarding controller handles a small set of explicit steps: profile, expertise, branding, and billing.

Profile data captures identity, handle, category, location, and coordinates. If browser coordinates are present, the flow can reverse-geocode into a readable location. If the user typed a location and coordinates are missing, it attempts forward geocoding. If geocoding fails, the flow keeps the user-entered value rather than blocking progress.

![The Profile step progressively collects identity, contact, handle, and location information.](/images/dogly-partner-pro-profile.webp)

Expertise data captures mission, one-liner, and credentials. Applicants can select existing credentials or request new certifications. New credentials are deduplicated case-insensitively and created as external credentials, with admin approval required unless the current user is an admin.

Branding data captures images (avatar, banner, and mission) and social/profile URLs. Billing captures Stripe setup intent. On final submission, the controller maps the session data into a `PartnerApplication`, sends the submitted email, completes the session, and shows a submitted/review state.

![The Branding step previews uploaded profile and banner imagery within the guided flow.](/images/dogly-partner-pro-branding.webp)

Autosave is deliberately conservative. Blank values and empty arrays are rejected before merging, so a partial browser event does not erase previously saved data. The tradeoff is that intentionally clearing a saved value needs an explicit action rather than relying on the same merge behavior.

For review, admin updates compare a snapshot of application attributes before and after save. `PartnerApplicationRevision.diff` categorizes tracked changes by section and kind: profile, expertise, and branding; text, image, or multi-select. The applicant review page then shows original answers alongside Dogly edits in the relevant step.

Stimulus handles focused enhancements such as progressive questions, location choices, image-upload state, and autosave. Rails remains the source of truth for validation and persistence.

Partner Pro also established shared directory architecture for advocates, brands, and shelters. The specialized browse and match experience is covered separately in [Dogly Advocate Discovery](/case-studies/dogly-advocate-discovery).

## Tradeoffs

The biggest tradeoff was choosing incremental architecture over a new subsystem.

A fully separate onboarding engine might have been cleaner in isolation, but it would have added routing, deployment, authentication, and data integration overhead. Keeping the work inside the Rails app let the flow reuse existing users, credentials, advocates, copy configuration, image configuration, mailers, and admin patterns.

Storing in-progress application data as JSON made the multi-step form easier to evolve. The tradeoff is that field names and shape require discipline. The final `PartnerApplication` remains the canonical record, so the JSON session is treated as temporary state rather than the business source of truth.

The review page currently computes some applicant-facing differences from original session data versus current application attributes. That makes the UI resilient when revision history is incomplete, but it also means the view knows more about field-level comparison than I would want long term.

## Outcome

The result is a more coherent partner lifecycle:

- Applicants can start, resume, autosave, and submit a guided application.
- Admins can review, edit, approve, and present changes back to applicants for review.
- Applicant-facing review pages show what changed instead of leaving edits opaque.
- Credentials and applicant-requested certifications fit into the same review path.
- Public partner pages share a directory controller pattern across advocates, brands, and shelters.

The work also left behind better internal boundaries: a session manager, revision model, reusable Haml partials, and focused specs.

## What I'd Improve Today

I would move more of the applicant review comparison out of Haml and into a presenter or view model. The current implementation is readable once you know the flow, but the view carries too much field-mapping responsibility.

I would also formalize the shape of session data. A small schema object per step would make autosave, validation, final submission, and review diffs easier to reason about, including an explicit way to clear a previously saved answer.

For applications associated with an account, I would add explicit ownership checks and stop treating the resume token as the sole authorization boundary after submission. I would also stage applicant-proposed certifications on the application and promote them to canonical credentials during review, rather than creating credential records during the expertise step.

Geocoding failures currently fall back gracefully, but I would narrow the rescued exception types and add structured logging so operational failures remain observable.

Finally, I would add a stronger end-to-end test around the full applicant lifecycle: start application, autosave, submit, admin edit, applicant review, and approval.
