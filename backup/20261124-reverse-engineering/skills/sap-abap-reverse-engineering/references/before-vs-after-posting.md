# Before-Posting vs After-Posting Controls

## Before-posting
Use to prevent creation: idempotency lookup, unique business key, source-reference validation, enqueue/lock, duplicate simulation, and deterministic retry handling.

## After-posting
Use to detect or repair: reconciliation, exception report, reversal proposal, alerting, and audit evidence.

## Required conclusion
For each issue state: target behavior, timing, scope, key, persistence, concurrency control, retry behavior, and why prevention or repair is appropriate. Do not present after-posting deletion or reversal as proof that duplicate creation is prevented.
