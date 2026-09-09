# Ask Jared intent-routing strategy

## Purpose

Recruiter questions should not require a new exact-match intent for every
paraphrase. The router identifies the question family, detects structural
complexity, and supplies candidate intents to planning and retrieval. It never
authorizes a factual claim.

## Intent families

The taxonomy is intentionally layered:

- Profile and candidacy: `characterization`, `role_fit`, `candidacy`, `career`
- Technical surface: `rails`, `react`, `frontend`, `backend`, `integration`,
  `architecture`, `testing`, `security`, `ai_data`, `typescript`
- Engineering behavior: `ownership`, `production`, `learning`, `failure`,
  `ambiguity`, `prioritization`, `impact`, `status`, `complexity`
- Working with people: `soft_skills`, `collaboration`, `stakeholder`,
  `influence_without_authority`, `disagreement`, `feedback`, `mentorship`,
  `leadership`, `organization`
- Scope and safety: `scope`, `risk`, `availability`

Umbrella intents such as `soft_skills`, `characterization`, and `role_fit` are
important. They answer broad recruiter questions without forcing the system to
pretend that every question has one narrow technical label.

## Routing signals

The deterministic router scores matching patterns and retains all credible
candidate intents. It marks planning as required when it sees:

- multiple close intent families;
- conjunctions or multiple propositions;
- comparisons or superlatives;
- broad category questions;
- no recognized intent;
- unusually long questions.

Known, narrow questions still use the fast deterministic route. Candidate
intents are passed into the plan and retrieval path so compound questions can
gather evidence for more than one dimension.

## Contracts

Every intent must define, or inherit, the following behavior:

1. What evidence kinds and capability mappings qualify.
2. Which boundaries or scopes exclude otherwise similar evidence.
3. Which source families receive a ranking boost.
4. What answer skeleton or broad synthesis shape applies.
5. What to do when one requested dimension lacks evidence.

Private Candidate Context may refine these contracts, but it remains planning
guidance. Recruiter-visible `KnowledgeEntry` claims remain the only factual
authority.

## Future model-assisted planning

If deterministic triage continues to see low-confidence or compound questions,
an optional planner-model call may consume the router analysis. Its output must
be strict JSON containing only allowed intent names, dimensions, scope, and
answer shape. The server must validate that output before retrieval. It may
never add facts, cite private context, or override scope and evidence rules.
