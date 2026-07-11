---
title: Reconciling Product Catalogs Without Creating a Second Source of Truth
navigation_title: Reconciling Product Catalogs
summary: How to combine exact identifiers, cautious matching, operator decisions, and durable mappings when two commerce systems disagree.
date: 2026-07-09
category: Integrations
tags:
  - Rails
  - Integrations
  - Commerce
  - Architecture
  - Product Engineering
status: published
---

Synchronizing two product catalogs sounds like copying fields until you meet the first real catalog.

One system has products with variants. The other has separate products for each size. SKUs are missing, duplicated, or formatted differently. Categories use different names. One side considers inventory global while the other separates it by location.

The engineering problem is not import. It is identity and ownership.

## Start by Declaring Ownership

Before matching a record, decide which system controls each field.

For a marketplace connected to a brand's commerce platform, a reasonable split might be:

| Concern | Owner |
| --- | --- |
| Brand product identity | Brand platform |
| Marketplace copy and taxonomy | Marketplace |
| Fulfillable inventory | Brand platform |
| Marketplace price promotion | Marketplace |
| Order and customer experience | Marketplace |
| Shipment execution | Brand platform |

Without that decision, "sync" quietly becomes last-write-wins. A copy edit in the marketplace can be erased by inventory polling because both operations update the same undifferentiated record.

## Match in Layers

Use the strongest available identity first:

1. Persisted external product or variant ID.
2. Exact, unique SKU.
3. Normalized SKU.
4. Exact normalized product name.
5. Human review.

Do not allow a weak match to masquerade as a strong one. A name match should produce a suggestion, not silently create a durable mapping.

Each proposed match should explain itself:

```text
Suggested match
Shopify: Trail Harness / Blue / Medium
Dogly:   Trail Harness - Blue (M)
Reason:  normalized SKU TH-BLU-M
```

That explanation is useful both to the operator and to the engineer debugging a bad association later.

## Preserve the Decision

Once an operator confirms a match, persist the external IDs. Do not repeat fuzzy matching during every inventory webhook.

The mapping should reach the lowest level required by later events. If inventory updates identify a variant and inventory item, store both. A product-level mapping alone forces the application to rediscover variant identity at the worst possible moment: during a time-sensitive stock update.

## Make Unmatched a Valid State

An integration UI often treats unmatched records as errors. They are usually work.

An external product might be:

- Not intended for the marketplace.
- Missing required taxonomy.
- A duplicate or archived item.
- Waiting for photography or copy.
- Valid, but not safely matchable.

Useful operator actions include:

- Import.
- Link.
- Ignore.
- Retry.
- Reopen a partial import.

"Ignore" should be persisted. Otherwise every refresh asks the operator to reconsider the same intentional exclusion.

## Keep Remote Work Outside Transactions

Downloading product images inside the product transaction extends locks and couples remote reliability to local consistency.

A safer flow is:

1. Create or update the product and mappings in a transaction.
2. Commit.
3. Enqueue image imports.
4. Record image failures separately.

The product can exist without all images. It should not disappear because a CDN timed out.

The same principle applies to inventory. Update the stock location owned by the integration instead of every stock location attached to the variant.

## Design the Reconciliation Screen as an Operations Tool

An admin page is not a thin wrapper around an API response. It is where uncertainty becomes a decision.

Show:

- Connection and credential status.
- Counts for linked, suggested, unmatched, ignored, and failed records.
- The fields used to make a suggestion.
- Missing SKU, option, taxonomy, and inventory-location warnings.
- The last successful sync and most recent error.
- A safe way to retry one record.

The interface should answer two questions quickly: "What needs attention?" and "What will this action change?"

## Test the Messy Catalog

Useful fixtures include:

- Duplicate SKUs.
- A product with no variants beyond the default variant.
- Multiple option dimensions.
- An image that fails after the product saves.
- An existing mapping whose external product was archived.
- Zero and fractional inventory values.
- Two products whose names normalize to the same string.

A clean three-product fixture proves the parser works. A messy fixture proves the reconciliation model works.

## The Larger Principle

Catalog integrations become reliable when they stop pretending uncertainty can be automated away.

Declare ownership. Prefer durable identifiers. Rank weaker matches. Put a person in the loop where ambiguity is real. Preserve their decision. Separate remote side effects from local transactions.

The goal is not a magical sync button. It is a system in which both automation and uncertainty are visible.
