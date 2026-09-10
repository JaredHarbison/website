# Ask Jared consolidated enhancement plan

Plan date: 2026-09-10
Owner: Codex, with Jared approving new factual claims and performing deployed QA
Status: implementation in progress; production is aligned on candidate-context-v2 and the canonical model, while model-first question understanding is the next implementation slice

This document supersedes the planning portions of:

- `next-phase-answer-quality-plan-2026-09-09.md`
- `intent-routing-strategy.md`
- `current-state-answer-quality-audit-2026-09-07.md`

Those documents remain historical evidence. This is the controlling execution
contract for the next release cycle.

## Progress contract

```yaml
phase_count: 6
  slice_count: 21
  completed_slice_count: 1
  remaining_slice_count: 20
  current_phase: 1
  current_slice: 1.2
  canonical_architecture: candidate-context-v2
  canonical_final_model: ASK_JARED_MODEL (default gpt-5.6-sol)
  intent_resolution: model-first structured output constrained by candidate-context-v2
```

A slice is complete only when its acceptance contract, automated tests, and
required production evidence are complete. Whenever work pauses, completes a
slice, or proposes a new slice, report the phase, slice, completed count,
remaining count, acceptance result, and next slice.

## Non-negotiable contracts

1. Candidate Context v2 is the only production architecture. No v1 or legacy
   planner may be selected implicitly, even when planning fails.
2. The same canonical model configuration must govern intent resolution,
   planning, final synthesis, skeleton realization, and repair unless a
   documented cost/latency exception is explicitly tested. Prompts, schemas,
   and roles may differ; capability must not vary accidentally by routing
   branch.
3. Intent routing may select an answer contract, never a factual claim.
4. Every recognized intent must have one explicit retrieval policy, evidence
   boundary policy, answer shape, and fallback behavior.
5. A question may be compound only when it contains independently answerable
   propositions or materially different operations. A conjunction alone is not
   sufficient evidence of compound intent.
6. Compound answers must be decomposed into parts, retrieved per part, and
   synthesized as separate supported answers. One unsupported subrequest must
   not erase a supported subrequest.
7. Unknown, unsupported, or out-of-scope portions fail closed usefully:
   answer supported portions and state only the narrow missing portion.
8. Scope, employer, ownership, chronology, status, metrics, and technology
   boundaries are hard evidence constraints, not prompt suggestions.
9. Knowledge additions may reorganize Jared-confirmed evidence but may not
   invent rankings, percentages, seniority, outcomes, authority, or transfer
   claims. New recruiter-visible factual records require Jared confirmation.
10. User-visible `validation_failure` is an internal defect signal, not the
    normal response to a supported question.
11. Admin and internal-QA traffic bypasses the four-question limit; ordinary
    recruiter traffic remains capped at four on both client and server.
12. Every production issue becomes a regression case with expected answer
    shape, required evidence, prohibited claims, and acceptable fallback.

## Current evidence-based diagnosis

The latest production QA establishes these facts:

| Event | Question | Result | Diagnosis |
| ---: | --- | --- | --- |
| 1705 | What kind of engineer is Jared? | Fixed in 1709 | A single question mark was incorrectly treated as compound, bypassing the Sol skeleton and using `gpt-4o-mini`. |
| 1707 | What are Jared's soft skills? | Fixed in 1711 | Same routing regression; the Sol path now answers, but the source mix is retail-heavy and should be more engineering-contextual. |
| 1713 | What is his experience with product-thinking and tradeoffs? | Still failed | Broad conjunction heuristic classified the question as compound; generic synthesis used `gpt-4o-mini` and failed validation twice. |
| 1715 | Does he have TypeScript experience? | Answered | Grounded, but generated wording repeats “specifically.” |
| 1717 | Can you tell me about a mistake he's made? | Answered | Good grounded failure/learning response; preserve as a control. |

The failure is therefore not primarily a shortage of model intelligence. It is
an architecture consistency problem: branching changes the model, evidence
contract, and generation schema at once.

## Target request architecture

```text
question
  -> validation and access policy
  -> model-first structured intent and answer-contract resolution
  -> schema validation against the internal recruiter ontology
  -> validated answer parts, scope, dimensions, and evidence requirements
  -> per-part approved retrieval with hard safety filters
  -> evidence packet and coverage check
  -> canonical-model synthesis or structured skeleton realization
  -> evidence/scope/language validation and one bounded repair
  -> answer, partial answer, insufficient information, or safe refusal
  -> complete decision-path telemetry
```

The intent model is semantic, structured, and advisory. It may select from
versioned intent families, dimensions, operations, scope values, and answer
shapes, but may not add facts or override deterministic safety constraints.
Internal guidance defines the ontology and behavioral contracts; recruiter
knowledge entries remain the only factual authority. The final model receives
only the validated plan and approved evidence packet.

Regexes may remain as diagnostic signals and test fixtures, but they are not
authoritative intent routing and must not determine the production answer path.
Safe optimization is limited to caching identical normalized requests; it must
not create a second semantic routing system.

## Phases and slices

### Phase 0 — Runtime and QA integrity (2 slices)

#### 0.1 Admin/internal-QA limit bypass — inherited complete

The client and server allow unlimited admin/internal-QA questions while public
recruiter sessions retain the four-question limit.

#### 0.2 Canonical-architecture QA assertion — in progress

Acceptance:

- every fresh QA answer persists `architecture=candidate-context-v2`;
- planner version is persisted and visible in diagnostics;
- model and routing path are persisted together;
- QA can submit at least five questions without a false limit;
- stale non-v2 reports are visibly marked stale.

### Phase 1 — Architecture cleanup and decision contracts (5 slices)

#### 1.1 Canonical model configuration

Replace divergent provider defaults with one `ASK_JARED_MODEL` constant/config,
defaulting to Sol. Permit a separately named planner override only when tested
and intentional. Add a startup/configuration diagnostic showing the selected
model without exposing credentials.

Acceptance: no production answer path silently selects `gpt-4o-mini`; tests
assert model selection for narrow, broad, compound, repair, and planner calls.

#### 1.2 Model-first intent and answer-contract resolution — current

Create a structured intent-resolution service using the canonical model and
private candidate-context guidance. The output must be schema-constrained and
limited to ontology values: intent families, question parts, operations,
dimensions, scope constraints, evidence requirements, answer shape, fallback
behavior, and confidence. It must never contain recruiter facts.

The service receives the current question, clear conversation referent context,
and a bounded internal guidance summary. It does not receive recruiter-facing
knowledge entries before intent resolution, preventing retrieval from defining
the question.

Acceptance: product-pride/ownership, project/role, comparison, gap, scope,
follow-up, and compound questions resolve to stable structured contracts;
malformed or out-of-ontology output fails closed to an explicit unclassified
contract without silently selecting a legacy route.

#### 1.3 Intent registry and ontology contract

Create one registry for intent patterns, candidate scoring, retrieval
qualification, source boosts, skeleton policy, answer shape, and fallback.
Remove duplicated intent lists and add a completeness assertion that every
registry intent has all required contracts.

Acceptance: adding an intent requires one registry definition and its tests;
no recognized intent falls back to first claims due to a missing policy.

#### 1.4 Explicit question decision object

Replace loose routing arguments with a validated decision object containing
classification, answer parts, scope, operation, dimensions, unsupported
subrequests, planning status, and selected model path. Compute the branch once
per request and use it for retrieval, synthesis, validation, and telemetry.

Acceptance: one persisted decision explains every production answer or failure.

#### 1.5 Shared validation and telemetry pipeline

Extract common normalization, claim resolution, repair, failure classification,
and telemetry logic. Preserve strict evidence validation while making partial
answers possible for compound questions.

Acceptance: generic and skeleton paths share the same evidence/scope checks and
cannot produce divergent user-facing failure semantics.

### Phase 2 — Knowledge-base answerability (4 slices)

#### 2.1 Canonical professional profile and characterization contract

Keep the confirmed profile and trajectory records as the lead. The answer
shape is identity, differentiator, scope/trajectory, one concise example, and
only a relevant boundary. Do not let retrieval rank choose the lead.

Acceptance: characterization, full-stack, frontend/backend, role-fit, and
strongest-quality questions lead with candidate-level synthesis in 80–140
words or a narrow supported answer.

#### 2.2 Engineering soft-skills synthesis

Add a recruiter-facing engineering-context synthesis only from existing
confirmed evidence: code review and reciprocal collaboration, stakeholder
clarification, technical tradeoff communication, feedback/adaptation, and
calibrated mentorship. Retail examples may support a transferable behavior but
must be labeled by domain and never presented as engineering management.

Acceptance: soft-skills answers lead with engineering-relevant behaviors and
use retail evidence only as a clearly scoped supporting example.

#### 2.3 Project index and complexity evidence

Represent employer, project, systems touched, ambiguity, integrations,
ownership, collaboration, result, and limitations explicitly. Do not call a
project “most complex” without a confirmed comparison basis; otherwise answer
with the strongest supported candidate and qualify the comparison.

Acceptance: no project is selected as most complex solely because it ranks first
or contains a matching technology term.

#### 2.4 Capability, gap, and learning links

Use qualitative capability levels only unless a sourced metric exists. Pair a
confirmed gap with adjacent foundation and demonstrated learning without
conflating adjacent technologies or contexts.

Acceptance: TypeScript, large-team, leadership, and unfamiliar-technology
questions use direct boundary → relevant foundation → learning/adaptation →
explicit transfer limit.

### Phase 3 — Question understanding and retrieval (4 slices)

#### 3.1 Multi-part decomposition

Separate scope, operation, dimensions, evidence requirements, and unsupported
subrequests. Distinguish coordinated dimensions (“product thinking and
tradeoffs”) from independently answerable questions. “Shipped” must not
override a complexity operation.

Acceptance: a frozen 40-question decomposition matrix covers compound,
comparison, scope, metrics, follow-up, broad recruiter questions, product/story
questions, ownership/contribution questions, and positive gap framing.

#### 3.2 Scope and provenance graph

Normalize employer/project scope on every recruiter-visible record:

```yaml
employer: Dogly | other_employer | personal | unknown
project_scope: inside_employer | outside_employer | mixed | unknown
scope_confidence: confirmed | needs_review | unknown
```

Acceptance: “outside Dogly” cannot retrieve or present the Dogly Stripe
integration as outside evidence.

#### 3.3 Retrieval coverage and hard filters

Retrieve broadly enough to cover each answer part, then apply hard privacy,
approval, scope, evidence-kind, and status filters. Replace unexplained fanout
limits with named coverage rules and trace why each selected record qualified.

Acceptance: traces show part coverage, exclusions, source ranking, and fallback;
boundary records never leak into ordinary capability answers.

#### 3.4 Conversation and referent continuity

Inherit prior evidence only for clear referents. A new scope or operation resets
the relevant constraints. Preserve distinct-example sequencing.

Acceptance: tests cover first/second example, tell-me-more, outside-that-company,
new unrelated question, and mixed follow-ups.

### Phase 4 — Generation and verification (3 slices)

#### 4.1 Structured answer realization

Use answer roles rather than full narratives. Require a direct lead, minimum
sufficient evidence, concise examples, and natural recruiter-facing language.

Acceptance: no internal planning/evidence vocabulary, no repetitive filler,
and no full case study for a narrow question.

#### 4.2 Partial-answer behavior

Return the supported portion of a compound question and narrowly qualify the
unsupported portion. Reserve user-visible validation failure for an internal
defect that could not be safely repaired.

Acceptance: qualitative full-stack answers survive unsupported percentage
requests; supported product judgment survives an unsupported quantification.

#### 4.3 Language and evidence verification

Validate claim support, scope, ownership, chronology, planned status,
technology qualification, and common readability defects. Add deterministic
cleanup for duplicated adjacent words where safe.

Acceptance: all known QA failures become useful answers or narrow
insufficient-information responses, never generic validation failure.

### Phase 5 — Evaluation and controlled rollout (3 slices)

#### 5.1 Frozen recruiter question battery

Maintain at least 60 questions, including 15 multi-part questions and 10
multi-turn sequences. Each case specifies expected shape, evidence class,
prohibited claims, and acceptable fallback.

#### 5.2 Automated and human scoring

Track grounding, relevance, directness, completeness, scope correctness,
boundary quality, naturalness, answer availability, and unsupported-claim rate.
Critical scope violations, invented metrics, wrong-employer attribution, and
user-visible validation failures block promotion.

#### 5.3 Production deployment gate

Run the battery on the deployed v2 path, inspect production telemetry, then
hand back to Jared for Admin QA. The release gate requires zero known critical
failures, no admin-limit regression, no user-visible validation failure for a
supported question, and v2/model-path telemetry on every result.

## Knowledge-base size decision

The corpus is not too small by record count. It currently has enough evidence
for a strong profile, product judgment, learning, collaboration, failure, and
technology-boundary system. It is too thin in *structured answer coverage*:

- canonical identity and differentiator fields;
- engineering soft-skills synthesis;
- project comparison/complexity metadata;
- employer and project scope;
- capability/gap/learning relationships;
- explicit quantitative-claim availability.

The next additions should therefore be structured, recruiter-facing records
derived from confirmed evidence, not an indiscriminate expansion of anecdotes.

## Immediate implementation order

1. Finish the current invariant tests and correct the broad conjunction false
   positive.
2. Unify model selection so compound routing cannot downgrade final synthesis.
3. Add decision-path/model-path regression tests.
4. Implement the registry and shared decision object incrementally without
   changing factual evidence.
5. Add the engineering soft-skills synthesis only after its factual wording is
   included in the review packet and confirmed.
6. Run the full suite, inspect the production event battery, commit, push only
   after reporting risks, and monitor the build before Admin QA.
