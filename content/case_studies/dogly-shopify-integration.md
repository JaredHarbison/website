---
title: Evolving Dogly's Shopify Integration
navigation_title: Dogly Shopify Integration
summary: Building customer acquisition, catalog reconciliation, inventory sync, and multi-brand fulfillment without confusing which system owns each piece of commerce data.
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

The Shopify work evolved in two distinct stages. The first, launched in late 2025, brought eligible brand customers into Dogly through signed order webhooks and a configurable invitation sequence. The second, developed in 2026, addressed the other direction: sending Dogly marketplace orders to a brand's Shopify store for fulfillment while reconciling catalog and inventory data between the two systems.

The hard part was not making API requests. It was deciding which system owned customers, products, inventory, orders, and fulfillment state—and ensuring that retries or partial failures did not create duplicate users, emails, products, or orders.

![Shopify integration boundaries](/images/shopify-integration-boundaries.svg)

## Problem

Dogly needed to support brands without asking them to abandon the systems they already used.

For customer acquisition, a qualifying Shopify purchase could introduce someone to Dogly's expert content and membership product. That required ingesting order events, identifying eligible products, associating customers safely, and scheduling brand-specific outreach.

For marketplace fulfillment, a Dogly order could contain products from multiple brands. Each brand needed only its own line items in its own Shopify store. Product and inventory data also needed a durable mapping across two catalogs that used different identifiers and did not always share clean SKUs.

## Constraints

- Preserve an existing Spree checkout and order lifecycle.
- Configure credentials, product filters, and invitation timing per brand.
- Acknowledge webhooks quickly and perform slower work asynchronously.
- Treat webhook delivery as at-least-once, not exactly-once.
- Split multi-brand orders without leaking another brand's line items.
- Avoid making either catalog an accidental second source of truth.
- Support operator review when automatic SKU or name matching was uncertain.
- Roll the fulfillment path out incrementally and preserve a safe way back.

## My Role

As Dogly's sole engineer, I owned the work from technical planning through implementation and production support. That included the webhook boundary, background jobs, customer association, invitation sequencing, per-brand configuration, order transmission, catalog import and reconciliation, inventory mapping, admin workflows, and focused tests around failure-prone paths.

I also worked directly with the founders to separate the immediate business need from the larger integration platform. That distinction kept the first customer-acquisition workflow small enough to launch while giving the later commerce work clearer boundaries.

## Stage One: Customer Acquisition

The first integration accepted signed Shopify order webhooks for a configured brand. The controller did very little: find the brand, verify the HMAC signature, enqueue the payload, and return promptly.

The background processor then checked whether the order contained an eligible product. If so, it found or created the customer in Dogly, recorded the Shopify relationship, associated the order, and scheduled the configured invitation sequence.

Several idempotency keys were necessary because there was no single universal definition of "already processed":

- Customer email prevented duplicate Dogly accounts.
- Shopify customer and order notes preserved the external relationship.
- Order-plus-day keys prevented duplicate invitation emails.
- Jobs rechecked state when they ran instead of trusting the state that existed when they were scheduled.

That last point mattered for delayed jobs. A customer might accept an invitation, unsubscribe, or receive another order between scheduling and execution.

## Stage Two: Marketplace Fulfillment

The fulfillment direction introduced a different ownership model. Dogly remained the customer-facing marketplace and source of the complete order. Each Shopify store received a brand-specific fulfillment order containing only its products.

The planned transmission flow grouped line items by brand, selected only brands configured for Shopify fulfillment, built a no-charge Shopify order, and recorded the returned external order ID against the Dogly order.

![Order transmission sequence](/images/shopify-order-sequence.svg)

Recording external IDs per brand made retries safer. Before transmitting, the service could determine whether that brand's portion had already succeeded instead of resending the entire marketplace order.

Fulfillment webhooks traveled in the reverse direction. After signature verification, they located the corresponding Dogly shipment and advanced its state without re-running unrelated checkout behavior.

## Catalog Reconciliation

Catalog synchronization could not depend on perfect SKUs. Some products matched cleanly by SKU, some only by normalized name, and some required a person to decide.

The admin reconciliation workflow therefore separated three states:

- Already linked.
- Suggested match.
- Unmatched Shopify product.

An operator could confirm a proposed match, import a new product, ignore an irrelevant item, or revisit a partial import. Imported variants retained Shopify product, variant, and inventory-item identifiers so later inventory events did not have to repeat fuzzy matching.

Images were imported through background jobs after the product transaction committed. That kept remote downloads outside the database transaction and made image failure recoverable without rolling back an otherwise valid catalog record.

## Operational Lessons

The fulfillment and catalog work went through integration, rollback, and restoration as it met the realities of the mature checkout code and overlapping feature branches. That was not merely source-control noise. It exposed assumptions about payment timing, stock locations, variant ownership, and merge boundaries that were safer to discover during a limited rollout than after broad adoption.

The implementation added explicit logging, surfaced transaction rollback errors, and provided admin-visible states for missing credentials, taxonomy, option types, and SKU conflicts. The goal was to make an incomplete integration diagnosable rather than silently wrong.

## Outcome

The customer-acquisition path has associated more than 1,000 Shopify customers with Dogly accounts in the retained production data. It turned partner purchases into a configurable onboarding channel while protecting against duplicate accounts and repeated invitation sequences.

The later commerce work established the integration boundaries for per-brand order transmission, fulfillment callbacks, catalog reconciliation, product import, and inventory mapping. Its limited rollout produced real synchronized catalog and order records while keeping operational control with Dogly's administrators.

The most durable outcome was a clearer model of ownership: Dogly owns the marketplace order and customer experience; partner stores own fulfillment and their source catalog; explicit external identifiers connect the two.

## What I'd Improve Today

I would formalize every cross-system operation around a persisted integration event with a stable idempotency key, payload digest, state, attempt count, and last error. The existing notes and external-ID mappings solve the important duplicate cases, but a common event model would make replay and support work easier.

I would also make the staged rollout explicit through per-brand feature states rather than relying on configuration presence alone. A state such as disabled, shadowing, catalog-only, and fulfillment-live would better communicate operational intent.

Finally, I would add contract tests around recorded Shopify payloads and a full integration test covering a multi-brand order in which one transmission succeeds and another fails. That is the scenario where clear retry boundaries matter most.
