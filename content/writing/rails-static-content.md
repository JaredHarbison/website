---
title: Rails for Static Content
summary: Why I chose a small Rails app with Markdown content for this site instead of a static site generator.
date: 2026-07-08
order: 7
category: Architecture
tags:
  - Rails
  - Architecture
  - Content
status: published
---

This site is intentionally boring at the infrastructure level.

It is a Rails app with no database, no authentication, no admin panel, and no frontend framework. Content lives in Markdown files. Rails renders those files through normal controllers and views.

That might seem like using too much framework for a personal site, but I think it is a useful shape.

Rails gives me routing, layouts, helpers, caching, asset handling, testing, and a future path to ActiveRecord without forcing those decisions on day one. Markdown gives me the authoring experience I want right now. The repository layer sits between those two choices so the app does not care whether content comes from files today or database rows later.

The important constraint is keeping the app static in spirit. A personal site does not need a client-side router, a CMS, or a large JavaScript bundle to render essays and case studies. It needs readable templates, good typography, semantic HTML, and a content model that does not fight the author.

The architecture is small on purpose:

- A `ContentRepository` loads Markdown entries from disk.
- A `ContentEntry` behaves like a lightweight model.
- `CaseStudy` and `Article` can grow domain-specific behavior.
- `MarkdownRenderer` owns Markdown-to-HTML rendering.
- Controllers ask repositories for entries and pass them to views.

The future path is straightforward. If I later want tags, search, RSS, sitemap generation, or an admin interface, the public controllers and views do not need to change much. The repository can start reading from ActiveRecord instead of files.

The lesson is not that every static site should use Rails. It is that Rails can be a simple tool when you use the parts you need and decline the parts you do not.
