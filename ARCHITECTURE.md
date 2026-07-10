# Architecture

## Context

The repository currently contains two site implementations:

1. The existing static build at the repository root, which GitHub Pages serves.
2. A Rails rebuild under `app/`, `config/`, and `content/`.

That overlap is temporary and deliberate. The Rails version can be reviewed and
tested without replacing the live entry point before it is ready.

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

These are Active Model objects, not database records. They give controllers and
views a familiar interface without pretending the application needs
persistence.

### Rendering

`MarkdownRenderer` owns the Redcarpet configuration. Raw HTML is filtered, and
links receive `noopener noreferrer`. Views never configure or instantiate a
Markdown parser themselves.

### Delivery

Controllers remain small: enforce visibility, request content, and select a
view. Missing content is translated into a 404 at this boundary. ERB templates
provide semantic page structure, and the stylesheet supplies the terminal-like
visual system.

## Publication control

The Rails version exposes all routes in development. In production, non-home
routes are unavailable unless `PUBLIC_SECTIONS_ENABLED` is true. Navigation uses
the same predicate as the controllers, so a link is not shown when its route is
locked.

This is a release control, not authorization. There are no user accounts or
private records in the application.

## Testing strategy

The current suite concentrates on the boundaries most likely to break:

- repository parsing, filtering, ordering, and missing entries;
- case study structure rules;
- Markdown HTML filtering and link attributes;
- route visibility, navigation, rendering, and 404 behavior.

Browser-level tests would add little while the site has no client-side behavior.
They would become more useful if interactive components are introduced.

## Tradeoffs

### Rails for a content site

Rails is more runtime than a static site generator, but it is also the framework
I work in most often. Using a narrow slice of it gives the site conventional
routing and testing while keeping the application small. A generated static
deployment would remove the runtime cost later without changing the authoring
model.

### Parsing on request

The repository currently reads files when it is called. This is easy to reason
about and appropriate for the current number of documents. Caching would add
invalidation behavior for no measurable benefit today.

### Front matter without a schema object

The metadata contract is intentionally light. If more content types or required
fields are added, validation should move into explicit content-type rules rather
than accumulating conditionals in the parser.
