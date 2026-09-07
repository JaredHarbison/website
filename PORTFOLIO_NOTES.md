# Portfolio Notes

This file is for interview preparation, not application documentation.

## Technologies demonstrated

- Ruby and Rails 8 with Active Model and Active Record
- Repository-backed public content modeling
- YAML front matter and Markdown rendering
- Semantic HTML and responsive CSS
- Minitest, RuboCop, Brakeman, and GitHub Actions
- Rails/Postgres runtime work on Heroku

## Decisions worth discussing

### Keeping public content behind a repository

Controllers do not read files or parse YAML. That work is behind
`ContentRepository`, so public content delivery depends on content objects
rather than a storage mechanism. This keeps published writing and case studies
reviewable in Git while leaving runtime data to the application datastore.

### Separating public content from runtime data

The public portfolio remains repository-backed. Active Record/Postgres supports
the parts that genuinely need persistence: admin authentication, Ask Jared
tokens and engagement, approved recruiter knowledge, Candidate Context planning
records, and operational workflows. Keeping those domains separate avoids
turning editorial content into a database-backed CMS while still supporting a
real application runtime.

### Shipping through two paths

The hosted production runtime is Rails on Heroku with Postgres. GitHub Actions
also renders and validates a static artifact from the same Rails routes; that
artifact is a fallback and publication path for repository-backed public
content, not a description of the live Ask Jared runtime.

### Keeping rendering security centralized

One Markdown renderer owns filtering and link-safety options. That keeps the
`html_safe` boundary reviewable and prevents different views from rendering
content with different rules.

## Tradeoffs

- Repository-backed content stays diffable and portable, while runtime data
  gets transactions, authentication, and queryable persistence.
- Rails provides conventional routing, mailers, admin surfaces, and API
  boundaries without requiring a frontend framework or JavaScript build step.
- The static exporter preserves a low-complexity fallback for public content,
  while Heroku carries the application runtime and its secrets.
- Candidate and recruiter knowledge are separate concerns: Candidate Context
  helps plan answers, while recruiter-facing facts still come from approved
  recruiter evidence.

## Challenges solved

- Representing several content types behind one repository boundary.
- Keeping draft content out of public collections.
- Rendering useful Markdown while filtering raw HTML.
- Persisting and protecting recruiter Ask access and engagement.
- Separating private planning context from recruiter evidence.
- Delivering résumé, contact, and operational email through one mailer system.
- Deploying the Rails runtime through GitHub Actions to Heroku while retaining
  a validated static fallback path.

## Likely interview questions

- Why keep public content in Git while using Postgres for runtime domains?
- Why use Rails for a portfolio that also has a static export?
- How are recruiter evidence and private planning context separated?
- Where would caching belong, and what would justify it?
- Why is `html_safe` acceptable only at the Markdown renderer boundary?
- What tests protect the deployment and access boundaries?

## Strong talking points

- I kept the content backend replaceable without pretending the runtime needed a
  CMS.
- I introduced persistence where the product needed identity, access, workflow,
  and auditability, not merely because Rails made it available.
- The static artifact is a deliberate fallback for public content; production
  Ask Jared is a protected Rails/Postgres runtime.
- The release pipeline separates implementation, verification, and deployment.

## Be prepared to discuss

- When repository-backed content should move to a CMS or database.
- How runtime data and public content should evolve independently.
- How the static exporter stays aligned with Rails routes.
- The limits of regex-based front-matter parsing and when explicit schemas would
  be worthwhile.
