# Ask Jared operations

Ask Jared has two answer paths. Recognized recruiter intents use capability-qualified evidence, a server-selected factual/positioning skeleton, and Terra for natural language realization. Open-ended questions use the protected fallback RAG path. In both paths, aliases and provenance are resolved server-side; recruiter responses never expose internal evidence identifiers.

Prospect sessions persist through the encrypted Rails session. The public Ask interface appends turns, supports story-preserving follow-ups and distinct alternate examples, and caps a conversation at four questions. A valid prospect token is remembered while navigating public pages, where page views and Ask activity are grouped by an anonymous session digest.

Recruiter Intelligence is organized around the Opportunity domain record: company, role, and tokenized access context. Its activity events may include page views, questions, answers, and issue reports. Session and network values are HMAC digests; they are continuity signals, not identity. Multiple sessions or networks are shown only as possible internal sharing.

Issue reports reuse the existing engagement-event store. The server matches the submitted question and answer to the corresponding answer event before attaching intent, evidence, model, and validation context. Owner email delivery is conditional on `JARED_ISSUE_EMAIL` and an existing configured mail transport; missing configuration is surfaced in Admin > System.

Knowledge entries originate from imported or approved source material. Recruiter retrieval requires `approved` status, `recruiter_visible` visibility, and a current embedding. The production-incident candidate is intentionally `needs_review` and private until remediation, impact, validation, and outcome are confirmed.

Do not add a manual knowledge-entry form unless it creates complete provenance, claims, capability mappings, approval/visibility state, embeddings, and finalization-compatible metadata. Do not remove rejected or private history as cleanup. The Rails 8.0.5 lifecycle warning remains a separate maintenance task; no major framework upgrade is part of the Ask product pass.
