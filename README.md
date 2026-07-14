# jaredharbison.com

This is the source for my personal site: a place for case studies, technical
writing, and a little context about the way I work.

The site is a small Rails application backed by Markdown files and deployed
from `main`.

## Why I built it this way

I wanted the authoring experience of a static site without introducing a CMS or
a frontend framework. Rails gives me routing, layouts, asset handling, and a
familiar testing setup. Markdown keeps the content portable and reviewable in
Git.

There is intentionally no database. A repository object reads Markdown from
disk and returns small model-like objects to the controllers. That boundary
keeps the rest of the app independent from where the content is stored.

## What is here

- A homepage, about page, and contact page
- Long-form case studies with a consistent section structure
- A writing section for technical notes
- Draft filtering through front matter
- Server-rendered, semantic HTML with no application JavaScript
- A production visibility flag for controlled launches

## Tech stack

- Ruby 3.3
- Rails 8
- ERB and CSS
- Redcarpet for Markdown rendering
- Minitest
- RuboCop and Brakeman

Active Record is omitted because the application has no persistent runtime
data. Propshaft handles the stylesheet without a Node build step.

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

Public sections are enabled by default. To temporarily lock the portfolio while
leaving the homepage available:

```sh
PUBLIC_SECTIONS_ENABLED=false bin/rails server -e production
```

## Quality checks

```sh
bin/rails test
bin/rubocop
bin/brakeman --no-pager
```

## Interesting details

- The content source is behind a repository boundary rather than read directly
  in controllers or views. Moving to another backend would not require a rewrite
  of the delivery layer.
- Markdown rendering filters raw HTML and adds safe relationship attributes to
  generated links.
- Unknown slugs become normal 404 responses instead of leaking repository
  exceptions.

## Future improvements

- Add RSS and sitemap generation once the writing archive grows.
- Cache parsed entries if the content library becomes large enough to justify
  it.

## What I learned

The useful decision here was not choosing Rails or Markdown by itself. It was
putting a small boundary between them. The app stays simple today, but its
controllers and views do not need to know whether content came from a file,
cache, or database. It is a modest example of designing for a likely change
without building that change early.
