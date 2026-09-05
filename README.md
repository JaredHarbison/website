# jaredharbison.com

This is the source for my personal site: a place for case studies, technical
writing, and a little context about the way I work.

The site is authored as a small Rails application backed primarily by Markdown
files. GitHub Actions renders a verified static fallback artifact for GitHub
Pages. The intended hosted runtime for the Ask Jared knowledge platform is Rails
on Heroku with Heroku Postgres; the static exporter remains the rollback path.

## Why I built it this way

I wanted the authoring experience of a static site without introducing a CMS or
a frontend framework. Rails gives me routing, layouts, asset handling, and a
familiar testing setup. Markdown keeps the content portable and reviewable in
Git.

Public content remains repository-backed: a repository object reads Markdown
from disk and returns small model-like objects to the controllers. The hosted
runtime adds Active Record only for the approved knowledge, token, engagement,
and admin domains, keeping content delivery independent from that datastore.

## What is here

- A homepage, about page, and contact page
- Long-form case studies with a consistent section structure
- A writing section for technical notes
- Draft filtering through front matter
- Rails-rendered, semantic HTML with no application JavaScript

## Tech stack

- Ruby 3.3
- Rails 8
- ERB and CSS
- Redcarpet for Markdown rendering
- Minitest
- RuboCop and Brakeman

Active Record uses SQLite in development/test and Postgres in production.
Propshaft handles the stylesheet without a Node build step. Ask Jared’s
embedding column uses pgvector in production.

## Architecture

Content lives under `content/` and uses YAML front matter. `ContentRepository`
parses those files, filters out drafts, and builds `ContentEntry`, `Article`, or
`CaseStudy` objects. Controllers request entries from the repository and pass
them to conventional Rails views. `MarkdownRenderer` is the only object allowed
to turn Markdown into HTML.

```text
content/*.md
    -> ContentRepository
    -> ContentEntry / Article / CaseStudy
    -> controller
    -> ERB view + MarkdownRenderer
    -> HTML response
```

See [ARCHITECTURE.md](ARCHITECTURE.md) for the boundaries and tradeoffs in more
detail.

## Content format

Each document starts with front matter:

```markdown
---
title: Example
summary: A short description.
date: 2026-07-08
order: 1
status: published
---

Markdown begins here.
```

Files default to `draft` when `status` is missing. Case studies also expose a
check for the standard sections I use when writing about product work.

## Running locally

The project uses the Ruby version in `.ruby-version`.

```sh
bundle install
bin/rails test
bin/rails server
```

Open `http://localhost:3000`. All sections are visible by default in
development.

When running Rails directly, public sections are enabled by default. To
temporarily hide them in a local or hosted preview while leaving the homepage
available:

```sh
PUBLIC_SECTIONS_ENABLED=false bin/rails server -e production
```

## Static build and deployment

Build the same static artifact used by GitHub Pages:

```sh
RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 bin/rails assets:precompile
RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 bin/rails site:build
```

The exporter renders every published page through the Rails controllers and
layouts, copies production assets, and writes the result to `_site/`. Validation
fails the build when a route does not render, an internal link or asset is
missing, or legacy React output appears in the artifact.

The Pages workflow runs tests, RuboCop, Brakeman, production asset compilation,
static export, and validation. The same gated workflow deploys the exact pushed
`main` commit to Heroku using the `HEROKU_API_KEY` secret and `HEROKU_APP_NAME`
repository variable, then checks `/up`. Do not use a direct `git push heroku` for
normal releases.
See [the Heroku deployment runbook](docs/ask-jared-heroku-deployment.md).

## Quality checks

```sh
bin/rails test
bin/rubocop
bundle exec brakeman --no-pager
```

## Interesting details

- The content source is behind a repository boundary rather than read directly
  in controllers or views. Moving to another backend would not require a rewrite
  of the delivery layer.
- Markdown rendering filters raw HTML and adds safe relationship attributes to
  generated links.
- Unknown slugs become normal 404 responses instead of leaking repository
  exceptions.
- Rails remains the single rendering implementation while production keeps the
  smaller attack surface and runtime cost of a static site.

## Future improvements

- Add RSS and sitemap generation once the writing archive grows.
- Cache parsed entries during the build if the content library becomes large
  enough to make repeated parsing measurable.

## What I learned

The useful decision here was not choosing Rails or Markdown by itself. It was
putting a small boundary between them. The app stays simple today, but its
controllers and views do not need to know whether content came from a file,
cache, or database. It is a modest example of designing for a likely change
without building that change early.
