# Jared Harbison Website

Personal developer site rebuilt as a small Rails app that behaves like a static
site.

## Architecture

- Rails 8 app with Active Record omitted for now.
- Content lives in Markdown files under `content/`.
- `ContentRepository` loads Markdown entries and exposes model-like POROs.
- `MarkdownRenderer` renders Markdown through Redcarpet.
- Public content routes are available in development and locked by default in
  production with `PUBLIC_SECTIONS_ENABLED`.
- Existing root `index.html`, `static/`, and `CNAME` remain in place so GitHub
  Pages keeps serving the current site until launch.

## Content

Pages:

```text
content/pages/about.md
content/pages/contact.md
```

Case studies:

```text
content/case_studies/my-case-study.md
```

Writing:

```text
content/writing/my-article.md
```

Each Markdown file uses YAML front matter:

```markdown
---
title: Example
summary: Short summary.
date: 2026-07-08
status: published
---

Markdown body.
```

Draft entries are ignored by repositories unless `status: published`.

## Case Study Structure

Case studies should use these sections:

- Overview
- Problem
- Context
- Constraints
- My Role
- Approach
- Technical Implementation
- Tradeoffs
- Outcome
- What I'd Improve Today

## Development

Use the configured asdf Ruby:

```sh
asdf exec bundle install
asdf exec bundle exec rails test
asdf exec bundle exec rails server -p 3001
```

The complete site is available by default in development. To preview the
production lock locally:

```sh
PUBLIC_SECTIONS_ENABLED=false asdf exec bundle exec rails server -p 3001
```

## GitHub Pages

GitHub Pages can serve multiple pages and clean static URLs, but it cannot run a
Rails server. Launch options:

- Generate static HTML from Rails and publish that output to GitHub Pages.
- Deploy the Rails app to a Ruby host such as Render, Fly.io, or Heroku.

Until launch, do not replace the existing root `index.html` or static assets on
the Pages branch.
