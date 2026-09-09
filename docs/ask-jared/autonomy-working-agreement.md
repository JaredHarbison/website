# Ask Jared autonomy working agreement

Effective: 2026-09-09

This is a repository-local collaboration agreement. It documents the user's
standing direction for this work; it does not override platform permissions,
sandbox rules, security controls, or required tool approvals.

## Autonomous actions permitted

Codex may proceed without asking for separate approval for normal in-scope
work, including:

- reading repository files, git history, tests, logs, and local artifacts;
- read-only production database queries;
- editing application code, tests, documentation, fixtures, and local configs;
- adding migrations when implementation requires them;
- running tests, linters, security scans, asset builds, and local smoke checks;
- inspecting production issue objects and answer diagnostics without mutation;
- creating commits on the working branch;
- preparing deployment/build commands and monitoring already-authorized builds;
- making conservative implementation decisions that do not add unsupported
  factual claims.

## Explicit approval gates

Codex must ask before:

1. pushing to `main` or any remote branch;
2. performing any non-read production database action, including inserts,
   updates, deletes, migrations, backfills, or administrative SQL;
3. adding or approving recruiter-visible factual claims when Jared has not
   supplied or confirmed the underlying fact;
4. taking an action materially outside Ask Jared's repository, deployment, or
   answer-quality scope.

## Answer-quality safeguards

- A planning document is not evidence.
- Existing approved evidence may be reorganized without factual expansion.
- New profile language, rankings, scope classifications, percentages, and
  outcome claims require inclusion in the consolidated review packet.
- Unknown remains unknown until confirmed.
- Every completed implementation slice reports phase, slice, completed count,
  remaining count, acceptance result, and next slice.

## Deployment reporting

Before requesting a main push, Codex must report the commit contents, test
status, known risks, and whether the change affects production data. After the
push, Codex must report build, deploy, and health-check status before handing
back for manual QA.
