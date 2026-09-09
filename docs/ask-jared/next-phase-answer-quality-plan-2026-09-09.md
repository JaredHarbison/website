# Ask Jared answer-quality improvement plan

Plan date: 2026-09-09
Plan owner: Codex, with Jared approving factual content and QA results
Status: Phase 0, slice 0.1 complete locally; deployment and production retest pending

## Non-negotiable work contract

This plan is the controlling contract for the next improvement cycle.

```yaml
phase_count: 5
slice_count: 16
completed_slice_count: 1
remaining_slice_count: 15
current_phase: 0
current_slice: 0.1
```

I must report these counts whenever work pauses, a slice completes, or a new
slice is proposed. A slice is not complete because code exists. It is complete
only when its acceptance contract, tests, and required evidence review are
complete.

Rules:

1. One slice at a time. No starting a later slice while the current slice has
   an unresolved acceptance failure.
2. Every answer-quality change must identify whether the failure is caused by
   scope, knowledge, question classification, retrieval, planning, generation,
   validation, or presentation. “Improve the prompt” is not an acceptable
   diagnosis.
3. No factual knowledge entry is added, rewritten, or approved from inference.
   Jared must supply or confirm the fact, ownership, scope, result, and
   limitation.
4. No unsupported percentage, ranking, seniority, authority, or “most” claim
   may be introduced to make an answer sound complete.
5. A gap may be presented constructively only as:

   `direct boundary → relevant adjacent evidence → demonstrated learning or
   adaptation → explicit limit on transfer`.

   The system must not turn a gap into a strength or imply experience that is
   not documented.
6. Every confirmed production issue becomes a regression case with its exact
   question, expected answer shape, prohibited evidence, and expected status.
7. Admin QA must always display and persist the canonical architecture. A QA
   result from an old architecture is not evidence about the current system.
8. Before deployment, run the full automated suite. After deployment, run the
   designated manual slice and inspect the persisted architecture, intent,
   evidence IDs, answer status, and issue report binding.

## Current production diagnosis

The latest v2 reports are not one problem:

| Issue | Question | Failure class | Diagnosis |
|---:|---|---|---|
| 1681 | What kind of engineer is Jared? | characterization | The answer remains too anecdotal and does not lead with the candidate-level identity Jared expects: full-stack, Rails/React, product-minded, organized, adaptable, and team-context boundaries. |
| 1687 | What’s the most complicated project he’s worked on for Dogly? | comparison / superlative | The answer selected the engineering-collaboration record and asserted complexity without a comparison method or explicit complexity evidence. |
| 1690 | What has Jared built outside of Dogly? | scope violation | The answer treated the Dogly Stripe integration as outside Dogly. Source provenance and employer/project scope were not a hard retrieval constraint. |
| 1684 | Is he fullstack? frontend? backend? What’s the breakdown by percentage of his top four technologies? | unsupported quantification | The question contains a supported capability question and an unsupported percentage request. The system attempted one combined answer and surfaced validation failure instead of answering the supported part and declining the percentage. |
| 1674 | What’s the most complex project Jared has shipped? | status misclassification | The word “shipped” over-triggered `status`; the question is primarily a comparative complexity question. |
| 1671 | Is he fullstack? | weak evidence selection | The answer used Stripe learning evidence and an unrelated TypeScript boundary instead of a canonical full-stack profile. |

These failures show that the principal gap is not just corpus size. The system
needs first-class answer objects for identity, scope, comparison, capability,
and limitations before it retrieves long project narratives.

## Target answer contract

Every recruiter question must first be decomposed into one or more answer
parts:

```yaml
question:
  scope: [all, dogly, outside_dogly, prior_career, current_project]
  operation: [describe, compare, explain, quantify, verify, follow_up]
  dimensions: [identity, technology, ownership, complexity, impact, teamwork, gap]
  requested_evidence: [direct_fact, project_story, boundary, metric, learning_story]
  unsupported_subrequests: []
answer:
  direct_answer: required
  evidence: required_if_available
  qualification: required_for_boundary_or_metric
  unsupported_parts: explicit_if_present
  status: [answer, partial_answer, insufficient_information]
  validation_failure: never_user_visible_for_a_supported_subpart
```

Examples:

- “Is he fullstack?” must answer the supported full-stack claim and not append
  TypeScript merely because it was nearby in retrieval.
- “What has he built outside Dogly?” must filter to non-Dogly evidence before
  generation. If there is no such evidence, it must say so.
- “What is the most complex Dogly project?” must compare a bounded set of
  Dogly projects using documented dimensions such as cross-system complexity,
  workflow breadth, integration boundaries, ambiguity, and ownership—not
  invent a superlative.
- “What is the technology breakdown by percentage?” must answer known
  qualitative technology breadth, then explicitly state that no defensible
  percentage breakdown is available.

## Phases and slices

### Phase 0 — Runtime and QA integrity: 2 slices

Purpose: ensure we are testing and observing the system we think we are
testing.

#### Slice 0.1 — Remove client-side admin/QA conversation cap

Status: complete locally; included in the v2 cleanup commit but requires the
next deployment.

Acceptance contract:

- Admin and internal-QA pages render `data-ask-unlimited="true"`.
- Public recruiter pages render `data-ask-unlimited="false"`.
- Admin and internal-QA JavaScript never terminalize at four questions.
- Public server and client limits remain four.
- Automated controller and frontend tests cover both branches.

#### Slice 0.2 — Canonical-architecture QA assertion

Status: remaining.

Acceptance contract:

- A fresh admin question persists `architecture=candidate-context-v2` and
  `planner_version=candidate-context-v2`.
- The admin UI displays the active architecture during QA.
- A QA report whose answer event is not v2 is marked stale/non-current in admin
  diagnostics.
- Add a smoke assertion that the same admin session can submit at least five
  questions without a client or server limit.

### Phase 1 — Knowledge-base answerability: 4 slices

Purpose: convert the corpus from a collection of stories into a recruiter
answer system with explicit facts, boundaries, and story relationships.

#### Slice 1.1 — Canonical professional profile

Create a small approved profile record, separate from project anecdotes. It
must cover only Jared-confirmed facts:

- full-stack identity;
- Rails/backend foundation;
- React/frontend experience;
- product-minded and pragmatic engineering judgment;
- operating style and organization where directly supported;
- small-team/large-team context;
- collaboration and autonomy boundaries.

Acceptance contract: the six questions in issues 1681, 1671, and the existing
characterization regression set answer directly in 80–140 words, without
requiring a Stripe or design anecdote as the lead.

#### Slice 1.2 — Project index and complexity evidence

Create structured project records with fields for employer, project, dates or
sequence, scope, systems touched, ambiguity, integrations, ownership,
collaboration, result, and limitations. Do not call any project “most
complex” unless Jared explicitly confirms the comparison.

Acceptance contract: “most complex project” produces either a qualified,
evidence-based comparison or a clear statement that the corpus cannot rank
projects. It must never select the engineering-collaboration story solely
because it contains “MVP React frontend.”

#### Slice 1.3 — Provenance and scope graph

Every recruiter-visible record must carry normalized scope fields:

```yaml
employer: Dogly | other_employer | personal | unknown
project_scope: inside_employer | outside_employer | mixed | unknown
source_scope_confidence: confirmed | inferred_needs_review | unknown
```

Acceptance contract: outside/inside questions apply a hard scope filter before
retrieval. Issue 1690 must not be reproducible after this slice.

#### Slice 1.4 — Capability matrix, gaps, and learning links

Build a technology/capability matrix with qualitative levels only unless a
metric is explicitly sourced. Link each confirmed gap to a relevant learning
story where one exists—for example, the Stripe integration for learning an
unfamiliar domain—but preserve the difference between “learned successfully”
and “already experienced.”

Acceptance contract: a gap answer uses the constructive format in the global
contract; percentage questions answer the supported qualitative portion and
decline only the unsupported quantification.

### Phase 2 — Question understanding and retrieval: 4 slices

Purpose: stop keywords from deciding the answer before the question is
understood.

#### Slice 2.1 — Multi-part question decomposition

Separate scope, operation, dimensions, and unsupported subrequests. “Shipped”
must not automatically mean status; “most complicated” must be recognized as a
comparison/superlative request; “outside Dogly” must become a scope constraint.

Acceptance contract: 20 curated questions receive correct decomposition in
automated tests, including issues 1684, 1687, 1690, and 1674.

#### Slice 2.2 — Broad candidate retrieval with hard safety filters

Retrieve a broad candidate set, then apply hard filters only for authorization,
privacy, employer scope, and evidence kind. Intent-specific source boosts may
rank evidence but may not silently eliminate the only relevant record.

Acceptance contract: retrieval traces show why each selected record was
eligible and ranked; no unrelated boundary record is selected merely because it
shares a nearby technology term.

#### Slice 2.3 — Answer-plan selection

The planner must choose an answer shape before selecting prose:

- profile/characterization;
- direct capability;
- project narrative;
- comparison;
- gap plus learning evidence;
- supported answer plus unsupported subrequest;
- insufficient information.

Acceptance contract: the plan is persisted in diagnostics and names the
selected answer shape, scope, evidence roles, and unsupported subrequests.

#### Slice 2.4 — Conversation referents and scope continuity

Follow-ups may inherit a referent only when the language clearly refers to the
prior answer. A new scope question must reset scope rather than inherit the
previous project.

Acceptance contract: multi-turn tests cover “the first example,” “outside that
company,” “what happened next,” and a new unrelated question in the same
conversation.

### Phase 3 — Generation and verification: 3 slices

Purpose: make valid answers concise, natural, relevant, and honest about gaps.

#### Slice 3.1 — Structured answer realization

Generate from answer roles, not from the entire retrieved narrative. Require a
direct lead sentence. Limit supporting examples to what the question needs.

Acceptance contract: characterization answers lead with the profile; narrow
questions do not receive a full unrelated case study; no answer contains
internal evidence labels or planning language.

#### Slice 3.2 — Partial-answer and gap behavior

Replace all-or-nothing validation for compound questions with supported-part
answering. A validation problem in an unsupported percentage clause must not
erase a valid full-stack answer.

Acceptance contract: supported claims return `answer` or `partial_answer`;
unsupported portions are explicitly qualified; `validation_failure` is
reserved for an internal system defect and is never the normal response to a
partially answerable question.

#### Slice 3.3 — Evidence and language verification

Validate claim-to-evidence support, scope, ownership, chronology, and
qualification. Add grammar/readability checks for common generated defects.

Acceptance contract: each answer claim maps to permitted evidence; scope
violations fail closed to a useful correction; output is recruiter-natural and
does not use “evidence,” “boundary,” “approved,” or similar internal terms.

### Phase 4 — Evaluation and controlled rollout: 3 slices

Purpose: prevent another cycle of subjective QA without a measurable contract.

#### Slice 4.1 — Recruiter question battery

Create a frozen battery of at least 60 questions across identity, technology,
ownership, architecture, project complexity, impact, teamwork, leadership,
learning, gaps, scope, metrics, and adversarial/unsupported questions. Include
at least 15 multi-part questions and 10 multi-turn sequences.

Acceptance contract: every question has an expected answer shape, required
evidence class, prohibited claims, and acceptable insufficient-information
behavior.

#### Slice 4.2 — Automated regression and human scoring

Score grounding, relevance, directness, completeness, scope correctness,
boundary quality, naturalness, and unsupported-claim rate. Track answer
availability separately from factual correctness.

Acceptance contract: no release is promoted on aggregate score alone. Any
critical scope violation, invented percentage, wrong-employer attribution, or
user-visible validation failure blocks promotion.

#### Slice 4.3 — Production QA and rollout gate

Run the battery on the deployed v2 path, then Jared performs manual QA as
Admin. Review all issue reports created during the slice before continuing.

Acceptance contract:

- zero known critical scope violations;
- zero client/server admin-limit failures;
- zero user-visible validation failures for supported questions;
- characterization, full-stack, project-comparison, and gap questions each
  pass their designated cases;
- all persisted answer events show v2 architecture.

## Knowledge-base decision

We should rewrite and add records, but selectively.

The current 54 recruiter-retrievable records are not too few. They are mostly
project narratives and derived evidence summaries. The first additions should
be the four structured record families in Phase 1, not another batch of generic
anecdotes.

Jared input needed before approval:

1. Confirm the high-level professional profile wording and which descriptors
   are fair to state directly.
2. Rank or explicitly decline to rank the most complex projects.
3. Confirm which projects are inside Dogly, outside Dogly, personal, or mixed.
4. Provide qualitative technology breadth and explicitly mark any unknowns;
   do not estimate percentages unless a defensible source exists.
5. For each important gap, identify whether a learning/adaptation example may
   be linked and what transfer limitation must remain visible.

The goal is not to make every answer positive. The goal is to make every answer
useful, relevant, and fair: direct strength where supported, candid limitation
where necessary, and a concrete learning pattern when the evidence supports
one.

## Next slice

The next implementation slice is **0.1: remove the admin/internal-QA client-side
question cap**. After deployment, slice 0.2 will verify that admin QA can ask
five or more questions and that every resulting answer event records v2.
