---
title: Designing Idempotent Webhooks in Rails
summary: Practical patterns for making at-least-once delivery safe across controllers, jobs, records, and delayed side effects.
date: 2026-07-10
category: Integrations
tags:
  - Rails
  - Integrations
  - Architecture
  - Testing
status: published
---

A webhook provider is allowed to send the same event more than once. Your application is not allowed to charge, invite, fulfill, or email someone more than once because of it.

That difference is where webhook design begins.

## Keep the Controller Boundary Small

A webhook controller should authenticate the request, capture the information required for processing, enqueue work, and respond quickly.

It should not perform a long synchronization while the provider waits. A timeout can cause the provider to retry an operation that actually succeeded, creating concurrency precisely when the application is least prepared for it.

Signature verification belongs before the enqueue. Store secrets per integration account when multiple customers or partners can connect the same provider.

```ruby
def create
  integration = Integration.find_by!(external_key: params[:account])
  head :unauthorized unless valid_signature?(integration)

  ProcessWebhookJob.perform_later(integration.id, request.raw_post)
  head :ok
end
```

The real implementation also needs payload limits, safe parsing, and useful error reporting. The important boundary is that authentication is synchronous while business processing is not.

## Choose an Idempotency Key for the Side Effect

"Have I seen this payload?" and "Have I performed this action?" are different questions.

One external order can legitimately cause several actions:

- Associate the order with a customer.
- Send an initial invitation.
- Send a follow-up two days later.
- Update an acquisition report.

A single processed flag is too coarse. Each side effect needs a key at the level where duplication would be harmful.

For example:

```text
shopify-order:8472:associate-customer
shopify-order:8472:invite:day-0
shopify-order:8472:invite:day-2
```

That model permits new behavior to be added without reopening old effects.

## Enforce Uniqueness in the Database

An application-level existence check is useful for readability, but it does not prevent two workers from passing the check simultaneously.

The database should enforce the invariant:

```ruby
add_index :integration_events,
  %i[integration_id idempotency_key],
  unique: true
```

The worker can then insert the event and treat a uniqueness violation as evidence that another worker already claimed it. This is more reliable than a distributed lock for many webhook workloads because the record also becomes an audit trail.

## Recheck State When Delayed Work Runs

A delayed email job should not assume the user is still in the state that caused the job to be scheduled.

Between scheduling and execution, the person may have:

- Accepted the invitation.
- Unsubscribed.
- Purchased again.
- Been merged into an existing account.
- Received the same communication through another workflow.

The job should load current state, claim its specific idempotency key, and then decide whether the effect is still appropriate.

## Make Partial Success Visible

Consider a marketplace order split between three external stores. Two transmissions succeed and one fails.

Retrying the entire order is unsafe. Discarding the entire attempt is inaccurate. The useful unit of state is the brand-specific transmission:

```text
Dogly order
├── Brand A → transmitted: external order 101
├── Brand B → failed: invalid variant mapping
└── Brand C → transmitted: external order 303
```

Persist external IDs and failure state at that boundary. A retry can then target Brand B without duplicating A or C.

## Test Repetition, Not Only Success

The happy-path test proves that the integration works once. The risk-oriented tests prove that it remains safe:

- Deliver the same payload twice.
- Run the same job concurrently.
- Fail after the external API succeeds but before the local record updates.
- Schedule a delayed effect, change the user's state, then run it.
- Process a multi-tenant payload with one invalid tenant configuration.

Webhook reliability is less about preventing every failure than ensuring that failure has a stable place to land.

## The Larger Principle

Idempotency is not a controller concern or a job concern. It is a property of a business effect across the whole path.

Authenticate early. Acknowledge quickly. Persist a key at the same granularity as the side effect. Let the database arbitrate concurrency. Recheck delayed decisions. Record partial success.

Once those boundaries are explicit, retries stop being frightening. They become a normal operating mode.
