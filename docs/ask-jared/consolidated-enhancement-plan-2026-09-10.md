# Ask Jared consolidated enhancement plan

Plan date: 2026-09-10
Owner: Codex, with Jared approving new factual claims and performing deployed QA
Status: implementation in progress; production is aligned on candidate-context-v2 and the canonical model, while the next release moves the answer path toward public-corpus-first retrieval with a compact policy layer

This document supersedes the planning portions of:

- `next-phase-answer-quality-plan-2026-09-09.md`
- `intent-routing-strategy.md`
- `current-state-answer-quality-audit-2026-09-07.md`

Those documents remain historical evidence. This is the controlling execution
contract for the next release cycle.

## Progress contract

```yaml
phase_count: 6
  slice_count: 22
  completed_slice_count: 6
  remaining_slice_count: 16
  current_phase: 2
  current_slice: 2.1
  canonical_architecture: candidate-context-v2
  canonical_final_model: ASK_JARED_MODEL (default gpt-5.6-sol)
  question_understanding: model-first structured decision output
  primary_answer_corpus: public case studies, public writing, and About page
  policy_layer: compact Rules contracts; not factual answer material
  evaluation_contract: 20-question paired set now; 50-question follow-up battery after core acceptance
```

## Slice status, release gate, and authority

Each slice has three independently recorded states:

- `implemented` — the scoped code or documentation change exists.
- `tested` — its automated acceptance coverage passes.
- `release-verified` — any required deployed or manual-QA evidence has been
  recorded.

A slice counts as complete only when all three applicable states are complete.
Where production verification is intentionally deferred, its implementation is
reported as locally accepted but does not authorize deployment or redefine the
release gate. Whenever work pauses, completes a slice, or proposes a new
slice, report the phase, slice, completed count, remaining count, acceptance
result, deployment state, and next slice.

Until Phase 2.0 establishes the article-only baseline and Phase 2.1 compares
the compact Rules layer against it, no recruiter-visible answer behavior may be
deployed or promoted. Architecture, telemetry, and evaluation-tooling work may
continue locally.

Codex may autonomously refactor, test, commit, and build evaluation tooling.
Jared approval is required only for new recruiter-visible factual claims,
meaning-changing edits to source content, a change to the evaluation or
release gate, or deployment. No absence of feedback is treated as factual
approval.

## Slice handoff record

| Slice | Acceptance result | Evidence | Deployment state | Next slice |
| --- | --- | --- | --- | --- |
| 1.1 Canonical model configuration | locally accepted | `2ac9a632b`; model-path tests | not deployed | 1.2 |
| 1.2 Model-first intent resolution | locally accepted | `62f8673f1`, `5bcb495f9`; resolver regressions | not deployed | 1.3 |
| 1.3 Decision schema and policy | locally accepted | `f33a6a7a9`; service suite: 162 runs, 792 assertions | not deployed | 1.4 |
| 1.4 Explicit question decision object | locally accepted | `f33a6a7a9`; persisted-decision and service-suite coverage | not deployed | 1.5 |
| 1.5 Shared validation and telemetry | locally accepted | bounded-repair regression coverage; service suite: 164 runs, 797 assertions | not deployed | 2.0 |
| 2.0 Corpus baseline and source policy | locally accepted | corpus-only battery: 20/20 completed, 16 answers, 4 narrow insufficiency responses; `phase2/public-corpus-only-gpt-5.6-sol.json` | not deployed | 2.1 |

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
13. Public case studies, public writing, and the About page are the primary
   recruiter-facing evidence corpus. Atomic knowledge records are not an
   independent answer authority; they may be migrated, indexed, or retired
   only when their content is represented in the public corpus or an approved
   Rule.
14. Rules constrain interpretation and claims; they do not supply candidate
   facts, select answers by keyword, or replace model question understanding.
   A Rule may prohibit an unsupported superlative, preserve lifecycle status,
   separate retail from engineering, or preserve metric provenance.
15. The 20-question paired evaluation set is an evaluation and regression
   contract. Its answer types are test labels and optional answer-shape
   guidance, not a production ontology or deterministic vocabulary router.
16. Do not expand deterministic intent vocabulary to chase individual
   phrasings. New wording belongs in evaluation coverage; recurring semantic
   failures belong in the model decision contract, evidence corpus, or Rules
   layer according to diagnosis.

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
  -> schema validation against a small internal decision contract
  -> validated answer parts, scope, dimensions, and evidence requirements
  -> per-part approved retrieval with hard safety filters
  -> evidence packet and coverage check
  -> canonical-model synthesis or structured skeleton realization
  -> evidence/scope/language validation and one bounded repair
  -> answer, partial answer, insufficient information, or safe refusal
  -> complete decision-path telemetry
```

The intent model is semantic, structured, and advisory. It may select from a
small versioned set of operations, dimensions, scope values, evidence needs,
and answer shapes, but may not add facts or override deterministic safety
constraints. This is a decision schema, not a large ontology or vocabulary
router. Public articles are the primary factual evidence. Rules define claim
and presentation boundaries; they are not evidence. The final model receives
only the validated decision, applicable Rules, and approved public-corpus
evidence packet.

Regexes may remain as diagnostic signals and test fixtures, but they are not
authoritative intent routing and must not determine the production answer path.
Safe optimization is limited to caching identical normalized requests; it must
not create a second semantic routing system.

## Phases and slices

### Phase 0 — Runtime and QA integrity (2 slices)

#### 0.1 Admin/internal-QA limit bypass — inherited complete

The client and server allow unlimited admin/internal-QA questions while public
recruiter sessions retain the four-question limit.

#### 0.2 Canonical-architecture QA assertion — release verification pending

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

#### 1.2 Model-first intent and answer-contract resolution — complete

Create a structured intent-resolution service using the canonical model and
private candidate-context guidance. The output must be schema-constrained and
limited to decision-schema values: question parts, operations,
dimensions, scope constraints, evidence requirements, answer shape, fallback
behavior, and confidence. It must never contain recruiter facts.

The service receives the current question, clear conversation referent context,
and a bounded internal guidance summary. It does not receive recruiter-facing
knowledge entries before intent resolution, preventing retrieval from defining
the question.

Acceptance: product-pride/ownership, project/role, comparison, gap, scope,
follow-up, and compound questions resolve to stable structured contracts;
malformed or out-of-contract output fails closed to an explicit unclassified
contract without silently selecting a legacy route.

#### 1.3 Decision schema and policy contract — complete

Create one small registry for decision fields, retrieval qualification, source
ranking hints, answer shape, policy checks, and fallback. Keep semantic
understanding in the model. Remove duplicated intent lists and add a
completeness assertion that every supported decision shape has all required
contracts. Do not turn this registry into a growing phrase dictionary.

Acceptance: adding a decision shape requires one definition and its tests; no
recognized question falls back to first claims due to a missing policy; adding
synonyms alone is not treated as an architecture improvement.

#### 1.4 Explicit question decision object — complete

Replace loose routing arguments with a validated decision object containing
classification, answer parts, scope, operation, dimensions, unsupported
subrequests, planning status, and selected model path. Compute the branch once
per request and use it for retrieval, synthesis, validation, and telemetry.

Acceptance: one persisted decision explains every production answer or failure.

#### 1.5 Shared validation and telemetry pipeline — complete

Extract common normalization, claim resolution, repair, failure classification,
and telemetry logic. Preserve strict evidence validation while making partial
answers possible for compound questions.

Acceptance: generic and skeleton paths share the same evidence/scope checks and
cannot produce divergent user-facing failure semantics.

### Phase 2 — Public-corpus answerability and policy (5 slices)

Purpose: make the public writing the coherent recruiter evidence system, then
add only the smallest policy layer needed to prevent confident overclaiming.

#### 2.0 Corpus baseline and source policy — complete

Freeze the 20-question paired evaluation set as the first answer-quality
baseline. Run corpus-only answers before adding Rules, then run corpus-plus-
Rules answers using the same questions, model, and scoring dimensions. Record
unsupported-claim flags separately from prose quality. The baseline is not a
claim that model-generated scores are ground truth; it is a reproducible
comparison artifact.

Acceptance: every question has a source-corpus answer, a documented expected
answer shape, required evidence, prohibited claims, and a reviewer-visible
status. No production routing change is justified by a single QA anecdote.

#### 2.1 Compact Rules layer — current

Represent only durable constraints that recur across the evaluation set:
unsupported superlatives and pride claims, ownership boundaries, collaborator
roles, lifecycle status, metric provenance and causality, retail/engineering
separation, adjacent-technology limits, and premise correction. Rules are
versioned, scoped, testable, and invisible in recruiter-facing prose.

Acceptance: Rules can reject or qualify a claim without becoming a second
knowledge base or a keyword router. Each Rule has a test demonstrating both
the prohibited claim and a natural supported alternative.

#### 2.2 Canonical professional profile and characterization contract

Keep the confirmed profile and trajectory records as the lead. The answer
shape is identity, differentiator, scope/trajectory, one concise example, and
only a relevant boundary. Do not let retrieval rank choose the lead.

Acceptance: characterization, full-stack, frontend/backend, role-fit, and
strongest-quality questions lead with candidate-level synthesis in 80–140
words or a narrow supported answer.

#### 2.3 Engineering soft-skills synthesis

Add a recruiter-facing engineering-context synthesis only from existing
confirmed evidence: code review and reciprocal collaboration, stakeholder
clarification, technical tradeoff communication, feedback/adaptation, and
calibrated mentorship. Retail examples may support a transferable behavior but
must be labeled by domain and never presented as engineering management.

Acceptance: soft-skills answers lead with engineering-relevant behaviors and
use retail evidence only as a clearly scoped supporting example.

#### 2.4 Project index and complexity evidence

Represent employer, project, systems touched, ambiguity, integrations,
ownership, collaboration, result, and limitations explicitly. Do not call a
project “most complex” without a confirmed comparison basis; otherwise answer
with the strongest supported candidate and qualify the comparison.

Acceptance: no project is selected as most complex solely because it ranks first
or contains a matching technology term.

#### 2.5 Capability, gap, and learning links

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

Maintain the current 20-question paired set as the core comparison contract.
After the core path meets acceptance, expand to a 50-question battery with
deliberate follow-up chains, compound questions, adversarial premise questions,
scope changes, gap questions, and recruiter-style broad prompts. Each case
specifies expected shape, evidence class, prohibited claims, and acceptable
fallback.

The 50-question run is a content-gap audit, not permission to add content
automatically. Classify each miss as one of:

- missing or insufficient public evidence;
- question decision or decomposition error;
- retrieval coverage or scope error;
- synthesis or answer-shape error;
- Rule or validation error;
- provider or runtime failure.

Only the first category justifies adding or expanding public content. Any new
content must be derived from Jared-confirmed facts and pass the existing
review/approval contract.

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

## Evidence-corpus size decision

The public corpus is not too small by article count. It currently has enough
evidence for a strong profile, product judgment, learning, collaboration,
failure, and technology-boundary system. It is too thin in *explicit answer
coverage* for some recruiter prompts:

- canonical identity and differentiator fields;
- engineering soft-skills synthesis;
- project comparison/complexity metadata;
- employer and project scope;
- capability/gap/learning relationships;
- explicit quantitative-claim availability.

The next additions should therefore be targeted public writing or confirmed
Rules only where the evaluation battery proves a real gap. We will not expand
the corpus indiscriminately, and we will not use the existing atomic knowledge
base as a second competing answer source.

## Immediate implementation order

1. Freeze the current production behavior and build the corpus-only baseline
   from the 20-question evaluation contract.
2. Correct model-resolution/provider failure behavior so a transient planning
   failure cannot become a generic user-visible validation failure when the
   question is answerable.
3. Implement the compact Rules contract and evaluate corpus-only versus
   corpus-plus-Rules on the same battery.
4. Implement the shared decision object and policy checks without adding a
   phrase dictionary or changing factual evidence.
5. Add the engineering soft-skills synthesis only after its factual wording is
   included in the review packet and confirmed.
6. Run the full suite, inspect the production event battery, commit, push only
   after reporting risks, and monitor the build before Admin QA.
7. Once the core path is acceptable, run the 50-question follow-up battery and
   produce a categorized content-gap report before proposing any new content.
