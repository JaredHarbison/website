# Ask Jared knowledge count reconciliation

Generated 2026-09-06T02:39:59Z from the current database.

| Scope | Exact count |
|---|---:|
| Total KnowledgeEntry rows | 35 |
| Approved | 35 |
| Needs review | 0 |
| Rejected | 0 |
| Candidate | 0 |
| Approved recruiter-visible/retrievable | 34 |
| Approved but not recruiter-visible | 1 |
| Recruiter-visible but not retrievable | 0 |
| Embeddings present | 0 |
| Embeddings missing | 35 |
| Stale embeddings | 0 |
| Candidate Context v1 records | 26 |

## 34 vs approximately 54

The exact current recruiter scope is **34**: 35 total rows exist, all approved; 34 are
`visibility=recruiter_visible` and one is `visibility=internal`. The internal row is
`archive:urbn-senior-merchandiser-prototype-workshops`, with recruiter utility `archive_only`;
it is excluded from retrieval. The earlier approximately-54 number was not the current
`KnowledgeEntry.recruiter_retrievable` scope and appears to have combined broader inventory or
legacy concepts with recruiter records.

## Breakdowns

- Approval: `{"approved"=>35}`
- Visibility: `{"recruiter_visible"=>34, "internal"=>1}`
- Source type: `{"repository_evidence"=>34, "jared_confirmed"=>1}`
- Source kind: `{"published_case_study"=>8, "missing"=>2, "direct_statement_from_jared"=>25}`
- Entry type: `{"leadership_story"=>9, "product_story"=>16, "integration_story"=>1, "project"=>3, "engineering_story"=>1, "metric"=>1, "career_context"=>3, "incident_story"=>1}`
- Recruiter utility: `{"secondary_recruiter_evidence"=>21, "primary_recruiter_evidence"=>13, "archive_only"=>1}`
- Duplicate source references: `[]`
- Runtime knowledge structures: `KnowledgeEntry.recruiter_retrievable` plus Candidate Context v1 YAML; no other runtime knowledge store found.

## Excluded records

- `archive:urbn-senior-merchandiser-prototype-workshops` is excluded because approval is `approved` but visibility is `internal` and utility is `archive_only`.
- No records are excluded for approval, duplicate-reference, or stale-embedding reasons.
