# Ask Jared operations

Ask Jared has two answer paths. Recognized recruiter intents use capability-qualified evidence, a server-selected factual/positioning skeleton, and gpt-5.6-sol for natural language realization. Open-ended questions use the protected gpt-4o-mini fallback path. In both paths, aliases and provenance are resolved server-side; recruiter responses never expose internal evidence identifiers.

Prospect sessions persist through the encrypted Rails session. The public Ask interface appends turns, supports story-preserving follow-ups and distinct alternate examples, and caps a conversation at four questions. A valid prospect token is remembered while navigating public pages, where page views and Ask activity are grouped by an anonymous session digest.

Recruiter Intelligence is organized around the Opportunity domain record: company, role, and tokenized access context. Its activity events may include page views, questions, answers, and issue reports. Session and network values are HMAC digests; they are continuity signals, not identity. Multiple sessions or networks are shown only as possible internal sharing.

Issue reports reuse the existing engagement-event store. The server matches the submitted question and answer to the corresponding answer event before attaching intent, evidence, model, and validation context. Owner email delivery is conditional on `JARED_ISSUE_EMAIL` and an existing configured mail transport; missing configuration is surfaced in Admin > System.

Knowledge entries originate from imported or approved source material. Recruiter retrieval requires `approved` status, `recruiter_visible` visibility, and a current embedding. The production-incident candidate is intentionally `needs_review` and private until remediation, impact, validation, and outcome are confirmed.

Do not add a manual knowledge-entry form unless it creates complete provenance, claims, capability mappings, approval/visibility state, embeddings, and finalization-compatible metadata. Do not remove rejected or private history as cleanup. The Rails 8.0.5 lifecycle warning remains a separate maintenance task; no major framework upgrade is part of the Ask product pass.

## Analytics launch boundary

Live recruiter analytics is defined by the `ASK_JARED_ANALYTICS_LIVE_AT`
configuration value. Only activity from a non-QA AskLink with an event timestamp
at or after that ISO-8601 timestamp is included in default recruiter analytics.
The value is separate from the AskLink's `tracker_source`, so historical
development activity cannot become live analytics merely because it was not
labeled QA.

## Testing Ask Jared in production

Production Ask Jared testing must use an Internal/QA AskLink. This applies to
Codex, Jared, automated checks, smoke tests, answer-quality checks, screenshots,
debugging, and production validation. Testing links must use
`tracker_source=internal_qa`; never create or use a normal recruiter AskLink for
testing. Use the clearly labeled “Create Internal / QA link” action in Admin >
Recruiter Intelligence > Create Access. Genuine recruiter/application links use
the separate recruiter-link path and remain non-QA.
