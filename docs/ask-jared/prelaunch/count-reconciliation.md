# Ask Jared knowledge count reconciliation

Generated 2026-09-06T14:01:16Z from the current database.

| Scope | Exact count |
|---|---:|
| Total KnowledgeEntry rows | 56 |
| Approved | 55 |
| Needs review | 0 |
| Rejected | 1 |
| Candidate | 0 |
| Approved recruiter-visible/retrievable | 54 |
| Approved but not recruiter-visible | 1 |
| Recruiter-visible but not retrievable | 0 |
| Embeddings present | 56 |
| Embeddings missing | 0 |
| Stale embeddings | 0 |
| Candidate Context v1 records | 26 |

## Historical count reconciliation

The exact current recruiter scope is **54** out of 56 total rows. The earlier approximate count
of 54 was the production recruiter scope; the prior local count of 34 came from a stale 35-row
SQLite snapshot.

## Breakdowns

- Approval: `{"approved"=>55, "rejected"=>1}`
- Visibility: `{"recruiter_visible"=>54, "private"=>1, "internal"=>1}`
- Source type: `{"repository_evidence"=>55, "jared_confirmed"=>1}`
- Source kind: `{"published_case_study"=>8, "missing"=>2, "repository_and_git"=>20, "direct_statement_from_jared"=>26}`
- Entry type: `{"leadership_story"=>9, "product_story"=>19, "integration_story"=>4, "project"=>4, "engineering_story"=>5, "metric"=>1, "performance_story"=>4, "incident_story"=>4, "debugging_story"=>2, "career_context"=>4}`
- Recruiter utility: `{"secondary_recruiter_evidence"=>21, "missing"=>21, "primary_recruiter_evidence"=>13, "archive_only"=>1}`
- Duplicate source references: `[]`
- Runtime knowledge structures: `KnowledgeEntry.recruiter_retrievable` plus Candidate Context v1 YAML; no other runtime knowledge store found.

## Excluded records

  - `fact:engineering-experience-boundaries` (ID 32) is excluded because approval is `rejected` and visibility is `private`; utility is missing.
  - `archive:urbn-senior-merchandiser-prototype-workshops` (ID 55) is excluded because approval is `approved` and visibility is `internal`; utility is `archive_only`.
