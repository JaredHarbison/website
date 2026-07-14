# Portfolio Notes

This file is for interview preparation, not application documentation.

## Technologies demonstrated

- Ruby and Rails 8 without Active Record
- Repository-backed content modeling
- YAML front matter and Markdown rendering
- Conventional controllers and server-rendered ERB
- Semantic HTML and responsive CSS
- Minitest, RuboCop, and Brakeman

## Decisions worth discussing

### Keeping content behind a repository

Controllers do not read files or parse YAML. That work is behind
`ContentRepository`, so the delivery layer depends on content objects rather
than a storage mechanism. This is useful change isolation, not an attempt to
build a generic CMS.

### Omitting the database

The site has no runtime data to persist. Active Record would add setup and
deployment work without solving a current problem. Active Model provides the
small amount of model behavior the views need.

### Separating Markdown rendering

One renderer owns security and feature options. That keeps `html_safe` at a
reviewable boundary and prevents different views from rendering content with
different rules.

### Shipping the rebuild safely

The old static site stays intact while the Rails version is developed on its
own branch. A production flag also keeps unfinished routes closed. This is a
small example of separating implementation from release.

## Tradeoffs

- Rails gives familiar conventions but requires a Ruby runtime unless pages are
  generated during deployment.
- Files are simple and reviewable, but they do not provide editorial workflows
  or efficient query capabilities.
- Parsing on demand avoids cache complexity; it would need measurement before
  the content library became large.
- The visibility flag is operational release control, not a security boundary.

## Challenges solved

- Representing several content types without a database.
- Keeping draft content out of public collections.
- Turning missing files into consistent HTTP responses.
- Rendering useful Markdown while filtering raw HTML.
- Developing a replacement without disturbing the live GitHub Pages site.

## Likely interview questions

- Why use Rails for a site that could be static?
- Why introduce a repository instead of reading Markdown in the controller?
- What would change if content moved to PostgreSQL or a CMS?
- Where would caching belong, and how would it be invalidated?
- Why is `html_safe` acceptable in `MarkdownRenderer`?
- What does the production visibility flag protect, and what does it not
  protect?
- How would you deploy this to GitHub Pages?
- What tests did you choose not to write?

## Strong talking points

- I removed components the product did not need: database, authentication,
  frontend framework, and JavaScript build tooling.
- The main abstraction follows an actual likely change—the content backend—while
  the rest of the application stays conventional.
- Security-sensitive rendering configuration lives in one place and has direct
  tests.
- The migration plan preserves the existing live site until the replacement is
  deliberately published.

## Be prepared to discuss

- The lack of deployment automation for the Rails version.
- Whether Rails remains worthwhile if the final output is fully static.
- The limits of regex-based front-matter parsing.
- How content validation should evolve if non-developers begin authoring files.
- Why this repository demonstrates architecture and communication more strongly
  than algorithmic complexity.
