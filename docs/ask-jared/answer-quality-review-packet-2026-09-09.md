# Ask Jared consolidated answer-quality review packet

Packet date: 2026-09-09

Purpose: approve the factual and answer-shape inputs needed for the next Ask
Jared implementation slices. This packet is deliberately separate from the
technical plan. The plan may be implemented autonomously, but these candidate
facts must not become recruiter-visible claims without Jared's approval.

## How to review

For each proposed statement, mark one:

- `APPROVE` — may become recruiter-visible evidence.
- `REVISE` — direction is right, wording or scope needs correction.
- `REJECT` — do not use.
- `UNKNOWN` — preserve as an explicit information gap.

No response is treated as approval. Unreviewed proposals remain planning-only
or are excluded from retrieval.

## A. Candidate-level profile proposals

These are intended to answer “What kind of engineer is Jared?”, “Is Jared
full-stack?”, and “What are Jared's strongest qualities?” without selecting a
random project anecdote as the lead.

| ID | Proposed claim | Evidence basis | Decision |
|---|---|---|---|
| P1 | Jared is a full-stack software engineer with a Rails/backend foundation and professional React/frontend experience. | Knowledge 50, public portfolio, existing candidate context | `PENDING` |
| P2 | Jared is product-minded: he connects user needs, product decisions, technical constraints, and delivery tradeoffs. | Knowledge 1, 31, 48, 52 | `PENDING` |
| P3 | Jared has worked with Ruby/Rails, JavaScript, React, Stimulus, PostgreSQL, integrations, background jobs, and operational workflows. | Knowledge 1–8, 11–30, 50–52 | `PENDING` |
| P4 | Jared has operated autonomously in a small-company environment and has direct engineer-to-engineer collaboration experience. | Knowledge 50 | `PENDING` |
| P5 | Sustained experience in a large conventional engineering organization is newer context. | Knowledge 41, 50 | `PENDING` |
| P6 | Jared is organized and pragmatic when balancing product value, technical risk, consistency, requirement stability, and delivery cost. | Knowledge 31, 48, 52 | `PENDING` |
| P7 | Jared is open-minded and adapts by researching unfamiliar domains, seeking guidance where appropriate, and applying what he learns. | Knowledge 46, 50, 51 | `PENDING` |
| P8 | “Empathetic” and “high emotional intelligence” may be used as recruiter-visible engineering descriptors. | Career/leadership evidence exists, but exact transfer to engineering context needs confirmation | `PENDING` |

Suggested profile answer shape, pending approval:

> Jared is a product-minded full-stack engineer with a Rails/backend foundation
> and professional React/frontend experience. He has worked autonomously in a
> small-company environment, collaborated directly with other engineers, and
> tends to weigh user value, technical risk, delivery cost, and maintainability
> together. Larger conventional engineering-team experience is newer context,
> but his documented work shows a pattern of learning unfamiliar domains and
> turning ambiguous product needs into shipped systems.

This draft is not approved evidence until P1–P7 are reviewed.

## B. Project and complexity proposals

The system must not claim “most complex” merely because a record contains
technical vocabulary. Please rank or decline to rank these candidates.

| ID | Project candidate | Potential complexity dimensions | Decision |
|---|---|---|---|
| C1 | Dogly Shopify integration | two-way partner integration, webhooks, background jobs, catalog/inventory reconciliation, fulfillment boundaries | `PENDING` |
| C2 | Dogly membership journey | multiple product surfaces, subscriptions, Stripe, Zoom, email, personalized guidance, lifecycle concerns | `PENDING` |
| C3 | Dogly partner applications | resumable workflow, authorization, review lifecycle, applicant feedback, mature Rails constraints | `PENDING` |
| C4 | Dogly product/design system work | six years, many product surfaces, Rails/React/Stimulus, performance and responsive tradeoffs | `PENDING` |
| C5 | Dogly MVP React frontend | transition from backend to full-stack, independent frontend implementation, collaboration boundaries | `PENDING` |
| C6 | Federation Briefing | Python ingestion, retrieval, evidence citation, offline/failure behavior | `PENDING` |
| C7 | Karaoke Queue | multi-role live workflow, contextual authorization, event/venue constraints, YouTube boundary | `PENDING` |

Required decision: either rank the candidates, or approve language such as
“one of the more complex projects documented here” with explicit dimensions.
The system will not invent a total ordering.

## C. Employer and project scope

These classifications are required for questions such as “What has Jared built
outside Dogly?”

| Source/project family | Proposed scope | Decision |
|---|---|---|
| Dogly case studies and consolidated Dogly records | inside Dogly | `APPROVE/REVISE` |
| Stripe learning ramp | inside Dogly; Stripe is the integration/domain, not the employer | `APPROVE/REVISE` |
| Federation Briefing | personal/independent project unless Jared specifies another affiliation | `PENDING` |
| Karaoke Queue | personal/current independent project unless Jared specifies otherwise | `PENDING` |
| Retail career records | prior employers: J.Crew, Madewell, URBN/Anthropologie | `APPROVE/REVISE` |
| Ask Jared itself | personal/current independent project | `PENDING` |

Hard rule: “outside Dogly” filters out all Dogly records before generation.

## D. Technology breadth and percentages

The system can answer qualitative technology breadth. It must not fabricate a
percentage breakdown.

Please approve or revise the qualitative categories:

| Category | Proposed description | Decision |
|---|---|---|
| Backend | Ruby/Rails, PostgreSQL, domain/workflow design, background jobs, integrations | `PENDING` |
| Frontend | JavaScript, React, Stimulus/Hotwire, responsive UI, accessibility | `PENDING` |
| Product engineering | user research, product decisions, prioritization, operational UX | `PENDING` |
| Systems/integrations | Stripe, Shopify, Recharge, APIs, webhooks, reconciliation, fulfillment workflows | `PENDING` |
| Python/AI retrieval | documented Federation Briefing project; do not generalize into broad professional Python depth without approval | `PENDING` |

Default response to a percentage request:

> I can describe Jared's technology breadth qualitatively, but I don't have a
> defensible percentage breakdown of his time by technology.

## E. Gaps and constructive learning links

The following format is approved as a design rule, not yet as final wording:

`direct boundary → relevant adjacent evidence → demonstrated learning/adaptation → transfer limitation`

| Gap | Adjacent learning evidence | Required limitation |
|---|---|---|
| Large conventional engineering teams | direct engineer collaboration, senior guidance, autonomy, organizational-scale retail leadership | retail leadership is not engineering management; larger engineering-team experience remains newer context |
| TypeScript depth | current learning trajectory and adjacent React/frontend work | React does not establish professional TypeScript depth |
| New third-party integrations | Stripe research, implementation plan, documentation-led learning, successful implementation | learning one integration does not establish broad integration expertise |
| Quantified outcomes | documented metrics where available | do not turn a bounded/internal/self-estimated figure into causal proof |

## F. Approval checklist

Please provide one response covering these decisions:

1. P1–P7: approve, revise, or reject each.
2. P8: may “empathetic” and “high emotional intelligence” appear in the
   engineering profile, and with what qualification?
3. C1–C7: rank them, identify ties, or approve “cannot rank.”
4. Confirm the employer/project scope table.
5. Confirm the technology categories and whether any important category is
   missing.
6. Confirm the gap/learning links and any wording limits.

Until this checklist is answered, implementation may proceed on contracts,
retrieval mechanics, tests, and diagnostics, but not on approving new factual
claims.
