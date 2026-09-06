# Source-boost audit

The baseline retriever currently defines eight intent-specific source-boost groups covering characterization, React, mentorship, ambiguity, technical disagreement, stakeholder influence, and impact. Phase 1 preserves all of them so the comparison does not conflate answer planning with a retrieval-policy rewrite.

## Findings

- The boosts are still materially useful for narrow intents with one especially strong approved story, particularly mentorship, ambiguity, disagreement, stakeholder influence, and impact.
- The characterization and impact boosts can bias broad answers toward the same anecdotes when the question asks for a candidate-level synthesis rather than one story.
- Some boosts compensate for missing story-slot planning: the retriever knows that a source is good for an intent, but not whether it is the primary story, a distinct second example, or a boundary-only source.
- Candidate Context v1 moves that distinction into a bounded plan and preferred story references. It does not remove the baseline boosts in this phase, so no claim is made that they are no longer necessary.

## Future treatment

If the controlled evaluation shows a durable quality gain, replace individual source boosts incrementally with plan-aware story role and diversity scoring. Retain explicit source boosts where the approved corpus has only one safe, high-quality story. Re-run the frozen battery after each removal; do not delete all boosts as a single cleanup.
