# jaredharbison.com

This repository contains the source and deployment artifacts for
[jaredharbison.com](https://www.jaredharbison.com), my personal portfolio and
technical writing site.

## Live site

The `main` branch is the current GitHub Pages deployment. Its root contains the
compiled output of the existing Create React App site rather than the original
React source. GitHub Pages serves these files directly and uses `CNAME` to map
the deployment to `www.jaredharbison.com`.

```text
main branch
    -> compiled static assets
    -> GitHub Pages
    -> www.jaredharbison.com
```

Because this branch is the production artifact, changes to `main` should be
reviewed as deployment changes.

## Rails rebuild

The next version of the portfolio is being developed on the `rails-rebuild`
branch. It replaces the generated static bundle with a small server-rendered
Rails application backed by Markdown content.

That branch includes:

- Routed portfolio, case-study, writing, about, and contact pages
- Markdown content with YAML front matter and draft filtering
- A repository boundary between content files and controllers
- Sanitized Markdown rendering
- Automated tests, RuboCop, and Brakeman checks
- Architecture and portfolio decision records

To inspect the rebuild locally:

```sh
git switch rails-rebuild
bundle install
bin/rails test
bin/rails server
```

See the `rails-rebuild` branch's README and `ARCHITECTURE.md` for its design,
content format, quality checks, and launch plan.

## Deployment note

The Rails rebuild is intentionally isolated from `main`. Work on that branch
does not change the live GitHub Pages site unless a separate deployment decision
is made.
