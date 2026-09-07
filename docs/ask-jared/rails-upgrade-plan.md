# Rails lifecycle note

The application is pinned to Rails 8.0.x and currently runs Rails 8.0.5.
Brakeman 8.0.5 marks the 8.0 series with an `EOLRails` warning beginning
2026-10-07. Rails' published maintenance policy retains security support for
Rails 8.0 through 2026-11-07.

The deployment security scan therefore excludes only Brakeman's lifecycle
metadata check (`--except EOLRails`). All substantive Brakeman checks continue
to run and still fail CI at confidence level 2. This is a narrow, documented
date-metadata treatment, not a security-warning suppression.

A Rails 8.1 upgrade is intentionally deferred until a separate compatibility
change can be tested against the full application. It is not part of the Ask
Jared launch change.
