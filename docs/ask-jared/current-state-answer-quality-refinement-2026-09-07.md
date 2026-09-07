# Ask Jared current-state answer-quality refinement — 2026-09-07

This companion preserves the original audit at
`docs/ask-jared/current-state-answer-quality-audit-2026-09-07.md`. It records
only the narrow refinement comparison run against the current production path.
No pre-v122 answers, recruiter evidence, Candidate Context records, or model
evaluation results were used.

## Baseline and method

- Before: Heroku v124 / `17830f5` audit baseline, candidate-context-v2,
  gpt-5.6-sol, 1,000-token skeleton path.
- After: deployed commits `3c5f401` and `54cbbe2`, same architecture and model.
- The narrow live comparison used fresh Internal/QA activity only. New event
  IDs are listed below; no raw access tokens are stored here.
- Existing issue reports and Candidate Context remained non-authoritative.

## Validation defects

The old records preserve the validation-failure status and retrieval summary,
but not the model output or the exact validator violation. Therefore the exact
old failed proposition cannot be reconstructed from production history. The
old validator behavior was correctly conservative; the availability defect was
in planning/realization, not a reason to loosen validation.

| Old event | Question | Old result | Generic repair | New event/result | Evidence |
| ---: | --- | --- | --- | --- | --- |
| 1552 | Professional TypeScript experience | validation failure; 5/5 retrieved | Preserve the strict TypeScript boundary while improving the skeleton/sanitizer path and persist validation reasons | 1614, validated answer | 42, 43 |
| 1570 | Collaboration with product stakeholders | validation failure; 6/6 retrieved | Classify stakeholder questions consistently and allow the approved decision-alignment stories in the stakeholder policy | 1616, validated answer | 52 |
| 1594 | Recommendations to stakeholders | validation failure; 6/6 retrieved | Same generic stakeholder planning/policy correction; no authority or persuasion inference added | 1618, validated answer | 52 |

Validation-failure reasons are now persisted for future diagnosis. The validator
still blocks unsupported claims.

## Broad synthesis

The five audited examples were 1542, 1544, 1602, 1606, and 1612. The generic
change limits broad skeleton composition to a characterization-first answer,
two or three dimensions, and at most one brief supporting example. It removes
the broad prompt's invitation to repeat a full implementation anecdote and
reduces selected broad claims from four to three.

Representative after results:

- 1620 — “What kind of engineer is Jared?” — 89 words, validated; evidence 4,
  1, 50.
- 1622 — strongest qualities — 84 words, validated; evidence 4, 1, 50.
- 1624 — best environment — 67 words, validated; evidence 4, 1, 50.
- 1626 — hiring-manager profile — 78 words, validated; evidence 4, 1, 50.
- 1656 — repeated Q1 — 81 words, validated; evidence 4, 1, 50.

The answers lead with candidate-level positioning and retain the large-team
boundary. The remaining prose is still substantive, but the prior repeated
case-study structure is materially reduced.

## Disagreement selection

- Old event 1598 selected collaboration evidence 50 for “How does Jared handle
  disagreement with a teammate?”
- The classifier now recognizes ordinary teammate-disagreement phrasing, and
  the generic disagreement source ranking prefers direct disagreement evidence.
- New event 1628 selected evidence 52, the React migration disagreement. It
  describes Jared's pushback, reasoning, dependencies, and resolution context
  without inferring formal authority.

## Weakness wording

Old event 1574 used the awkward phrase “technology depth varies by technology
and is best considered specifically individually.” New event 1630 remains
validated against 43, 42, and 41 and says TypeScript is newer territory,
large conventional-team experience is limited, and those are technology/team
context boundaries rather than a generalized technical-depth claim. Governance
phrasing is removed without spinning the gap into a strength.

## Planned/prototype directness

Old event 1588 answered a status question with prioritization evidence 48. The
question was unrecognized and reached the fallback model. A generic `status`
intent and status-aware skeleton policy now route prototype/planned/shipped
questions through the bounded path. New event 1644 correctly returns factual
insufficiency because the selected approved evidence does not support a direct
prototype/planned answer. It does not substitute the prioritization anecdote.

## Controls

The narrow post-deployment controls remained substantive and validated:

| New event | Control | Result |
| ---: | --- | --- |
| 1646 | Broad characterization | validated, evidence 4, 1, 50 |
| 1648 | React/frontend | validated, evidence 50, 52 |
| 1650 | Product judgment | validated, evidence 48, 52 |
| 1652 | Ownership versus collaboration | validated, evidence 50 |
| 1654 | Large engineering teams | validated, evidence 50, 41 |

No material control regression was observed. An additional unrecognized role-fit
probe was not used as a control because its fallback path is intentionally a
different generation route.

## Analytics sanity check

The authoritative production breakdown after QA exclusion is:

- Internal/QA opportunities: 22 (`internal_qa`) plus 11 legacy `qa` records;
  these are excluded.
- Real/non-QA opportunities: 126 — 105 with blank tracker source, 20
  `manual`, and 1 `Rapid Tracker`.
- Real question events: 578 — 444 from blank-source opportunities and 134 from
  manual opportunities.
- Real outstanding issue reports: 2, both from `manual` opportunities.

Thus the current headline counts (116 engaged prospects, 404 meaningful
sessions, 578 questions, 2 outstanding issues) represent non-QA activity under
the existing classification. No analytics data was changed in this refinement.

## Question-count attribute

`data-ask-question-count="34"` is the count of all persisted
`question_submitted` events for the browser session when the Ask page is
rendered. It is a session-history/diagnostic count, not a per-token reset
counter. Internal/QA links intentionally bypass the four-question server cap,
which is why a QA session can display a value above four. The ordinary recruiter
cap remains enforced server-side at four completed question events. No change
was made.

## Narrow conclusion

The three original validation-failure defects now produce validated answers
where approved evidence supports them. The planned/prototype question now fails
closed rather than substituting unrelated prioritization evidence. Broad answers
are shorter and candidate-led; disagreement selection and weakness wording are
improved; the STRONG controls remain grounded. No evidence or Candidate Context
changes were made.
