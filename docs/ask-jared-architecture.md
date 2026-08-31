# Ask Jared: architecture assessment and MVP plan

Status: discovery complete; implementation follows the corrected Heroku-first prompt.

## Current-state assessment

The repository is a Rails 8.0.5 application used as a Markdown authoring and
static-export tool. `ContentRepository` reads 17 Markdown documents, Rails
renders the public routes, and `StaticSite::Builder` writes `_site/` for
GitHub Pages. The production artifact contains HTML, CSS, and images. The
current deployment does not run Rails, expose an application database, or
provide a public API.

The public content currently includes eight case studies and seven technical
articles, including Dogly membership, Shopify integration, partner
applications, bulk ordering, advocate discovery, product design,
Federation Briefing, and Karaoke Queue. The site already exposes useful public
source URLs for approved entries.

The repository contains no anecdote records or source export. The promised 49
records therefore cannot be imported yet. The importer must accept an explicit
source export and must not create placeholder anecdotes or infer them from
public prose.

The existing test/build/security baseline is healthy: 22 tests pass, RuboCop
passes, and Brakeman reports no warnings. The Pages workflow grants contents
read access only and deploys an artifact; it does not provide write access to a
runtime service. The local clone is writable. Remote read access is confirmed;
remote write access has not been tested because doing so would mutate GitHub.

## Architecture options and recommendation

### Keep Pages plus a small API

Keep the existing site and add a separately deployed Rails API for Ask Jared.
The API owns sessions, rate limits, signed opportunity links, magic-link
verification, admin authorization, retrieval, model calls, audit events, and
secrets. A managed Postgres instance with pgvector stores approved knowledge,
provenance, review state, and embeddings. The Pages frontend calls only the
API's narrow question endpoint.

This preserves the current deployment and attack surface, but creates a second
runtime and splits public delivery from application behavior. It remains the
rollback option, not the target architecture under the corrected prompt.

### Migrate the entire site to Rails runtime

This makes the API, public site, admin dashboard, and knowledge platform share
one Rails application. It adds runtime, database, and deployment responsibility,
but those are now required by the canonical Postgres knowledge store, Devise
admin area, token lifecycle, and engagement workflow. Heroku is already the
intended operating environment for the related Karaoke application.

### Managed edge/database service

An edge function plus managed Postgres/vector storage could reduce server
maintenance, but it would introduce a second language/runtime and still need
custom approval, admin, verification, and audit logic. It is a reasonable later
deployment optimization, not the lowest-risk first implementation for this
codebase.

### Recommendation

Use the second option: run this existing Rails website normally on Heroku,
attach Heroku Postgres with pgvector, and add Ask Jared inside the same Rails
deployment. Preserve the static exporter and GitHub Pages workflow until the
Heroku app passes route, asset, SEO, HTTPS, and rollback checks. The static
deployment remains the emergency fallback, not the runtime architecture for
Ask Jared.

## Candidate project inventory

These are candidate evidence records derived from public case studies and
writing. They are not automatically approved claims beyond the already
published source pages.

| Candidate | Evidence visible in repository | Recruiter value | Confidence / open questions |
| --- | --- | --- | --- |
| Dogly Shopify integration | Webhook boundary, background jobs, signed events, idempotency, catalog/inventory reconciliation, multi-brand fulfillment, RSpec; public case study | External integrations, ownership boundaries, failure handling | High implementation confidence; confirm exact rollout scale and safe code excerpts |
| Dogly membership journey | Stripe, discovery, comments, email, plans, Zoom, AWS; public case study states more than 40% internal subscription comparison increase | Product engineering and measurable growth | High for published claim; document comparison window, attribution limits, and metric query |
| Dogly partner applications | Resumable onboarding, review lifecycle, credentials, applicant feedback, legacy Rails extension | Product flow design in a mature system | High; confirm which implementation details remain confidential |
| Fridge No More bulk ordering | Reused Spree catalog, operational order flow, warehouse/shipping rules; $11,935.90 across 210 cases | Shipping under time pressure and operational product thinking | High for published outcome; confirm partner/publication permission |
| Dogly advocate discovery | Browse/match modes, query layer, tag/topic relationships, visibility rules, graceful geocoding, accessible Stimulus behavior | Search/discovery and pragmatic UX | High; production adoption and matching quality are unknown |
| Dogly product design | Six-year product language, image/performance tradeoffs, Rails/Haml/SCSS/React/Stimulus | Product judgment and design-engineering leadership | Medium-high; separate personal ownership from team history |
| Federation Briefing | Python ingestion, TF-IDF/OpenAI retrieval, source labels, offline mode, refusal behavior, Pytest | AI/RAG, provenance, evaluation, cost-aware fallback | High for repository-described behavior; verify external repository contents before deeper claims |
| Karaoke Queue | Venue/event boundaries, contextual roles, queue rules, YouTube boundary, Turbo/Stimulus, accessibility, tests | Current product-engineering and systems thinking | High for current published foundations; explicitly separate shipped work from roadmap |

Code archaeology beyond this repository is not possible from the current
checkout: it contains the portfolio source, not the Dogly or Federation Briefing
application repositories. Any deeper implementation record should be attached
from those repositories or supplied as an approved evidence export.

## Candidate metrics inventory

The initial inventory contains only metrics already stated in public content.
No production database is connected to this project, and no metric is treated
as verified analytical evidence yet.

| Metric | Source / calculation | Limitation |
| --- | --- | --- |
| More than 40% subscription increase | `content/case_studies/dogly-membership.md`; compare the stated internal pre/post subscription periods | Window, denominator, attribution, and confounders need Jared's confirmation |
| $11,935.90 first retained order | `content/case_studies/fridge-no-more-bulk-ordering.md`; order total in the case study | One order is not a durable growth measure |
| 210 cases | Same case study; case quantity in the stated first order | Does not establish throughput or repeat usage |
| Roughly two-week initial workflow | Same case study; narrative delivery estimate | Calendar definition and scope need confirmation |
| Up to 25 discussions / seven-day window | Federation Briefing case study; application constraint | Prototype throughput, not business impact |

Future metric scripts must be read-only, aggregate-only, reproducible, PII-free,
and stored as provenance alongside a candidate metric entry. The public API will
never have production database credentials or arbitrary SQL capability.

## Knowledge model and approval

The API will use a `knowledge_entries` table with a stable ID, title, body,
short body, entry type, approval status, visibility, confidence, source type,
source URL, public URL, source reference, source fingerprint, metadata, vector,
created/updated timestamps, and approval timestamp. Source relationships are
kept separately or in structured metadata so one approved claim can cite several
public pages.

Entry types include fact, project, engineering story, product story, metric,
capability, tradeoff, debugging story, leadership story, integration story,
performance story, incident story, career context, and interview story.
`source_type` distinguishes public-site, code-derived, anecdote-derived,
metric-derived, and interview-derived material.

Imported anecdotes are keyed by Anecdote ID and default to `candidate` plus
`private`. The importer stores a normalized source fingerprint and source
reference. Refresh updates source fields and non-review metadata, preserves
reviewer edits and decisions when evidence is unchanged, and moves an approved
entry to `needs_review` when its source evidence changes. Nothing is
auto-approved or recruiter-visible.

The public retriever queries `approval_status=approved` and
`visibility=recruiter_visible` before assembling limited context. Candidate, rejected,
private, and needs-review records are filtered at the storage/service boundary,
not merely hidden by prompt instructions.

## Security and trust model

The browser sends a short question to the API; only the API holds the model
credential. Questions are length-limited, normalized, rejected for obvious
garbage, rate-limited by anonymous session and privacy-preserving IP key, and
subject to token, timeout, per-session, and daily/monthly cost budgets.

The model receives approved entries labeled as untrusted data and a narrow
instruction contract. The server validates structured output, intersects
evidence IDs and URLs with the retrieved records, caps answer length, and
renders only server-approved fields. Injection requests, private-data requests,
unsupported claims, protected-characteristic requests, and off-topic questions
return `blocked`, `out_of_scope`, or `insufficient_information` without
retrieving private data.

The MVP has no generic public Ask Jared tier and no work-email magic-link flow.
Without a valid opportunity token, the ordinary portfolio remains available but
Ask Jared is unavailable. A valid opaque opportunity token unlocks that specific
opportunity; it indicates provenance rather than verified human identity and
may be forwarded internally. Tokens are validated for expiry/revocation and
never used to expose private knowledge. Deeper trust tiers are deferred.

Admin actions require separate authorization and are audited. Logs store
minimal anonymous metadata, status, evidence IDs, latency, and cost estimates;
they do not store raw source text or model secrets.

## Implemented operational slice

The pre-minted token pool is maintained by the protected workbook's
`askJaredRefillTokenPool` time-driven Apps Script function. It counts available
sheet rows, requests only the deficit from Rails, and writes newly minted raw
tokens directly to the protected pool tab under a document lock. Rails stores
only HMAC digests plus an export timestamp; the raw bearer is returned once and
is not recoverable from Rails/Postgres afterward. This makes sheet inventory,
not merely database row count, the usable inventory measure.

The protected Sheets integration endpoint is:

```text
POST /api/job_search/opportunities/submit
X-Job-Search-Key: <JOB_SEARCH_SYNC_TOKEN>
```

It accepts `raw_token`, `external_id`, `company`, `role_title`, optional
`tracker_source`, and optional `submitted_at`. It associates the token with the
stable opportunity ID, marks both the token and opportunity submitted, returns
the usable AskLink, and is safe to retry for the same association. The
credential is a Rails/Heroku config var and is intentionally separate from
Devise and all admin permissions. The endpoint is narrowly scoped: it cannot
approve knowledge, query production, or generate recruiter answers.

The protected token-pool endpoint is separate:

```text
POST /api/job_search/token_pool/refill
X-Job-Search-Pool-Key: <JOB_SEARCH_TOKEN_POOL_TOKEN>
```

Apps Script supplies its current `sheet_available_count`; Rails revokes any
undelivered legacy DB-only available rows, mints only the deficit transactionally
under a Postgres advisory lock, marks each new record exported, and returns raw
values through the authenticated response. The protected sheet is the delivery
surface; Rails retains only the digest and export metadata.

The owner dashboard has separate Knowledge management and Recruiter
intelligence areas. The latter shows aggregate engagement and probabilistic
sharing signals per opportunity without raw IPs, session digests, or questions.

## MVP implementation plan

1. Add a backend-neutral knowledge contract and explicit importer with tests for
   49-record-shaped input, idempotency, reviewer preservation, fingerprints,
   and approved-to-needs-review reset.
2. Add a static Ask Jared landing page and a disabled-by-default API client
   configuration so the Pages build remains deterministic without secrets.
3. Add the API service boundary, schema/migrations, approved-only retrieval,
   structured response validation, abuse controls, and provider adapter.
4. Add a minimal authenticated admin workflow for review, provenance, links,
   embedding regeneration, preview, and evidence usage.
5. Add request/service/integration tests for security, trust tiers, malformed or
   unavailable model responses, source rendering, and production-data
   isolation.
6. Add deployment/runbook documentation, security review, cost/latency
   assumptions, and a follow-up roadmap.

Actual anecdote synchronization, production metrics, magic-link delivery, and
API deployment remain gated on supplying the source export, identifying the
Heroku app, and configuring secrets outside GitHub Pages.

## Jared follow-up actions

These are the external inputs and actions needed to complete the hosted MVP.
Secrets should be entered directly into Heroku config vars or the relevant
provider UI; never paste them into chat, commit them to Git, or store them in
the workbooks.

- Provide an export or read-only share of the 49-row Anecdote Library, including
  Anecdote ID, source evidence, and reviewer fields.
- Provide workbook names/tabs and exact column headers for Rapid Tracker,
  Target Tracker, Recruiter/Recruited Tracker, and the shared Action Ledger.
- Identify the Heroku app for the website, or authorize creation of a separate
  app. Confirm custom-domain/DNS ownership for the eventual cutover.
- Add Heroku Postgres and enable pgvector after the app is identified.
- Configure the LLM key, Rails secret, admin email/mail sender, Sheets/API
  credentials, token HMAC secret, and rate/cost limits as Heroku config vars.
- Provide legitimate read-only production analytics access only if a proposed
  metric needs verification. Recruiter requests must never receive production
  credentials.
- Install the delivered Apps Script as an installable `onEdit` trigger plus a
  time-driven `askJaredRefillTokenPool` trigger after workbook mapping is
  confirmed. Its credentials belong in Apps Script Script Properties, never in
  cells.
- Review and explicitly approve candidate knowledge entries before enabling
  recruiter-visible retrieval.

Until these actions are complete, local implementation and automated tests can
continue, but production deployment, real anecdote synchronization, live model
calls, and workbook synchronization must remain disabled.

## Security review checklist

The MVP must be considered incomplete until deployment verification covers API
key exposure, prompt and indirect prompt injection, poisoned source entries,
private-entry retrieval, PII and production-data leakage, SQL injection,
arbitrary URL fetching, sensitive code excerpts, rate-limit bypass, signed-token
forgery/replay, log leakage, admin authorization, and cost-exhaustion attacks.
The current repository changes do not connect production data, call an LLM, or
add an admin surface, so those runtime risks remain deployment gates rather than
hidden assumptions.

## Performance and operations

The first hosted version should use a small approved-entry retrieval limit, a
vector index sized to the corpus, background embedding jobs, a short model
timeout, and response caching only for normalized repeated public questions.
The service should return a deterministic insufficient-information response when
the provider is unavailable. Cost projections require the chosen model and
provider pricing; the API must enforce a configured monthly ceiling before any
model request is made.

## Follow-up roadmap

- Complete now: importer contract, approval state, approved-only retrieval,
  structured response validation, token-gated Ask endpoint, admin review UI,
  token pool refill, and the protected submission boundary.
- Next: workbook column mapping, installable Apps Script submission sync,
  engagement synchronization back to the shared ledger, and actual pgvector
  semantic retrieval on Heroku.
- Later: Turnstile, verified work-email links, controlled job-description
  comparison, interview-derived entries, evaluation datasets, and answer-
  quality review.
