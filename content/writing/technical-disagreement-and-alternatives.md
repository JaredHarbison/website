---
title: Technical Disagreement and Alternatives
summary: How I adjust technical disagreement for peers, developing engineers, senior engineers, and business stakeholders.
date: 2026-07-11
order: 3
category: Collaboration
tags:
  - Product Engineering
  - Leadership
  - Architecture
  - Operations
status: published
---

I do not think raising a concern is the same as contributing a solution.

If I disagree with a proposed technical direction, I try to bring a clear alternative. Sometimes I can define it during the conversation. Sometimes the responsible answer is, "I think there is a risk here; give me a little time to verify it and I will follow up."

The important part is closing that loop quickly.

## Match the Conversation to the Person

The substance of a concern should remain consistent, but the way I introduce it depends on who owns the proposal.

With an engineer who is still developing, I am more likely to identify the concern and ask whether they see a solution that addresses it. That gives them room to reason through the consequences instead of replacing their work with mine.

With a senior engineer, I am more direct. I will put my alternative next to the proposal and ask how they see the tradeoff. The goal is not to perform deference or certainty. It is to expose assumptions while there is still time to change them.

With a business stakeholder, I translate the disagreement into results, risk, and resources. They do not need a lecture about framework internals. They need to know what each path makes possible, what it costs, and where it can fail.

## A Commerce Example

Consider a marketplace order containing products fulfilled by several independent Shopify stores.

One proposal is to transmit every brand order synchronously inside checkout. The argument is understandable: do not confirm success until every partner store has accepted its portion.

My concern would be that this makes payment and checkout depend on several external systems at once. One slow store could hold open a database transaction. One unavailable API could fail checkout after payment. A retry could repeat transmissions that already succeeded.

I would propose committing the Dogly order first and creating one independently retryable transmission job per brand.

That alone does not answer the stakeholder's concern. The product language has to change with the architecture.

Instead of telling the customer that every item is confirmed and on its way, confirm what is actually true:

> We received your Dogly order and are processing it. We will update you as each brand fulfills its shipment.

Customers already understand that one ecommerce order can produce several shipments and tracking emails. Dogly's legacy ShipStation workflow behaved that way, and large retailers routinely fulfill one order from a distribution center and multiple stores.

The alternative therefore includes both a safer technical boundary and a small product feature: an honest processing state followed by shipment-specific updates.

## Define the First Release

For an initial release, I would require:

- The Dogly order to commit independently of partner APIs.
- One transmission state per brand.
- An idempotency key and external order ID per transmission.
- Automatic retries for transient failures.
- An administrator-visible failure state and manual retry.
- Customer copy that distinguishes order receipt from fulfillment confirmation.
- Shipment updates as brands accept and fulfill their portions.

I would not require a fully generalized integration event platform before the first order. I would require enough state that a failed transmission cannot become invisible or duplicate a successful one.

## Disagreement Is Part of Product Design

The useful alternative is rarely "do the same feature with a different class structure."

Architecture changes what the product can truthfully promise. Product language can remove a false technical requirement. Existing customer expectations can make a safer workflow feel familiar rather than compromised.

That is what I try to bring to disagreement: not only a warning, but another path that connects engineering constraints back to the outcome everyone is trying to achieve.
