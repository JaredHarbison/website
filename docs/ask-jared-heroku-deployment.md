# Ask Jared Heroku deployment

The intended production runtime is the existing Rails application on Heroku.
The GitHub Pages exporter remains available as a rollback artifact until the
Heroku cutover is verified. Do not put `OPENAI_API_KEY`, Rails secrets, database
credentials, or sync credentials in GitHub Actions or the repository.

## Preflight

1. Identify the Heroku app that currently serves `karaoke.jaredharbison.com`
   and decide whether the portfolio should use that app or a separate Heroku
   app. Do not guess the app name.
2. Confirm the portfolio custom-domain/DNS ownership and record the current
   GitHub Pages DNS values for rollback.
3. Add Heroku Postgres to the chosen app. The production `database.yml` reads
   `DATABASE_URL`; no local SQLite database is used in production.
4. Confirm the Postgres plan supports the `vector` extension. The migration
   enables `vector` and creates the 1536-dimension embedding column/index.

## Deploy

From an authorized checkout, ChatGPT Work/Jared should:

```sh
heroku git:remote -a <HEROKU_APP>
heroku addons:create heroku-postgresql:<PLAN> -a <HEROKU_APP> # skip if already attached
heroku config:set RAILS_ENV=production \
  OPENAI_API_KEY=<entered-directly> \
  JOB_SEARCH_SYNC_TOKEN=<random-secret> \
  JOB_SEARCH_READ_SYNC_TOKEN=<different-random-secret> \
  ASK_JARED_TOKEN_POOL_MINIMUM=100 \
  ASK_JARED_TOKEN_POOL_TARGET=200 \
  -a <HEROKU_APP>
git push heroku feat/ask-jared-rag-platform:main
heroku logs --tail -a <HEROKU_APP>
```

The `release` process runs `rails db:migrate`. Verify `/up`, existing home,
about, case-study, writing, tag, and asset URLs before changing DNS. Create the
Jared admin with a one-time production console command only after the app is
confirmed:

```sh
heroku run rails console -a <HEROKU_APP>
AdminUser.create!(email: "<JARED_EMAIL>", password: "<ONE_TIME_PASSWORD>")
```

Use the deployed admin session to review and explicitly approve knowledge
entries. Imported anecdotes remain private candidates until that review.

## Scheduler

Add one Heroku Scheduler job:

```text
bundle exec rake ask_jared:refill_token_pool
```

Run it daily. The task tops up only when available inventory is below the
minimum; it does not mint a fixed number every day. Confirm the pool target and
threshold in config vars before enabling it.

## Domain cutover and rollback

Use a low-risk window, verify Heroku’s certificate and all canonical URLs, then
switch the portfolio DNS to Heroku. Keep GitHub Pages deploys available during
the observation period. To roll back, restore the recorded Pages DNS values and
disable AskLink distribution until the Heroku runtime is healthy. Do not delete
the database or revoke tokens during a rollback.

## Required external follow-through

- Jared/ChatGPT Work must provide the actual Heroku app name and choose whether
  the portfolio shares the karaoke app or gets a separate app.
- Jared must enter all config vars directly in Heroku and create the admin user;
  values must not be pasted into chat, sheets, or Git.
- Jared/ChatGPT Work must verify the Postgres plan supports `vector`, run the
  release migration, and confirm the migration status in production.
- Jared/ChatGPT Work must configure the Scheduler job and perform URL/DNS,
  HTTPS, asset, SEO, sitemap/robots, analytics, and rollback checks.
