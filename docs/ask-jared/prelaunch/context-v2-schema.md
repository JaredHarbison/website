# Candidate Context v2 schema

Candidate Context v2 is a private, version-controlled planning corpus. It is not a second
evidence store and is never included in recruiter evidence packets, evidence IDs, source URLs,
or public responses.

Each record has:

- `id`: immutable stable key, unique across the corpus
- `category`: positioning, capability_relationship, story_map, career_context, boundary_context,
  recruiter_intent, voice, role_fit, interview_signals, or aspiration
- `approval_status`: `draft`, `approved`, or `retired`; only `approved` records may affect planning
- `privacy_classification`: currently `private` only
- `purpose` and `guidance`: planning intent, never recruiter-facing answer text
- `source_references`: governance links to approved evidence or private provenance
- `provenance`: why the planning concept is trusted or useful
- `affects`: interpretation, retrieval, story ranking, boundary framing, voice, or answer structure
- `intent_tags`: recruiter-question families
- `relationships`: structured links between concepts/stories/constraints
- `priority`: deterministic ordering aid

The database-backed import surface uses `CandidateContextImporter`. Imports are idempotent by
stable ID, update records in place, and never delete omitted records. Retirement is a lifecycle
state, not destructive deletion. Candidate Context v2 is now the sole runtime architecture for
public, admin-preview, and internal QA traffic. The versioned YAML remains the review/import
source, while production planning reads only approved private database records.

The planner also derives explicit contracts from the private context: required evidence roles,
employer/project scope rules, fallback behavior, and retrieval expansions. These contracts guide
retrieval and synthesis but never authorize a claim or replace recruiter-visible evidence.
