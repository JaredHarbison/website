# Architecture

## Context

The portfolio is authored as a Rails application under `app/`, `config/`, and
`content/`. The live hosted runtime is Rails on Heroku with Postgres. A custom
Actions workflow also runs Rails at build time and produces a validated `_site`
artifact for the repository-backed public-content fallback path.

## Application boundaries

### Content

Markdown is the source of truth. Front matter carries metadata such as title,
summary, date, and publication status. Keeping content in the repository makes
changes diffable and avoids adding an administration surface that this site does
not need.

### Repository

`ContentRepository` owns file discovery, front-matter parsing, draft filtering,
sorting, and lookup. It receives a collection name and model class, which keeps
the mechanics shared without forcing every content type to have the same
behavior.

### Domain objects

`ContentEntry` provides the common metadata interface. `Article` and
`CaseStudy` are separate types so domain-specific rules have a clear home.
`CaseStudy`, for example, can report missing sections from the structure used by
the portfolio.

These public-content objects are Active Model objects, not database records.
They give controllers and views a familiar interface without turning editorial
content into a CMS. Separate Active Record models support runtime domains such
as admin authentication, Ask Jared access and engagement, approved recruiter
knowledge, and operational workflows.

### Rendering

`MarkdownRenderer` owns the Redcarpet configuration. Raw HTML is filtered, and
links receive `noopener noreferrer`. Views never configure or instantiate a
Markdown parser themselves.

### Delivery

Controllers remain small: enforce visibility, request content, and select a
view. Missing content is translated into a 404 at this boundary. ERB templates
provide semantic page structure, and the stylesheet supplies the terminal-like
visual system.

`StaticSite::RouteSet` enumerates every public route from the same content
repositories and tag catalog used by the controllers. `StaticSite::Builder`
renders those routes through an HTTPS integration session, copies compiled
assets, and writes directory-indexed HTML. `StaticSite::Validator` verifies the
route inventory and every local link and asset before deployment.

## Publication control

Published front matter controls which entries reach the route inventory and
static artifact. When Rails is run directly for a preview, setting
`PUBLIC_SECTIONS_ENABLED=false` hides navigation and makes non-home routes
unavailable. The Pages workflow does not use that preview flag.

This is a publication control, not authorization. Authentication and private
runtime records belong to the Heroku application and Postgres; the static
artifact contains only published public content.

## Testing strategy

The current suite concentrates on the boundaries most likely to break:

- repository parsing, filtering, ordering, and missing entries;
- case study structure rules;
- Markdown HTML filtering and link attributes;
- route visibility, navigation, rendering, and 404 behavior;
- static route enumeration, rendering, and artifact link validation.

Browser-level tests would add little while the site has no client-side behavior.
They would become more useful if interactive components are introduced.

## Tradeoffs

### Rails for a content site

Rails is more framework than a static site generator, but it is also the
framework I work in most often. Using a narrow slice of it gives the site
conventional routing, testing, mailers, and runtime boundaries while keeping
the public-content layer small. The static exporter preserves a fallback path,
while the Heroku deployment serves the protected runtime features that cannot
be static.

### Parsing during rendering

The repository reads files whenever it is called during Rails rendering. In the
deployed site, that work happens only during the Actions build. This is easy to
reason about and appropriate for the current number of documents. Build-time
caching would add invalidation behavior for no measurable benefit today.

### Front matter without a schema object

The metadata contract is intentionally light. If more content types or required
fields are added, validation should move into explicit content-type rules rather
than accumulating conditionals in the parser.
