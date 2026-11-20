# Unattended execution

Use `approve once, run to gate`. Freeze spec hash, target, package/TR/task, object scope, actions, data/external policies, checks, budgets, stop conditions, notification policy, and `READY_FOR_UAT` target.

Continue silently when reversible, in scope/envelope, evidence-backed, and free of business ambiguity or production/irreversible effects. Defer non-blocking warnings and successful repairs to the final report.

Interrupt only for completion or a genuine decision boundary: scope/spec change, irreversible action, target mismatch, unresolved drift/lock, API/architecture trade-off, exhausted budget, missing tool/access, security/privacy/LUW blocker, or expired lease.

Default run budget: 8 hours, 500 tool calls, 3 repairs per slice, 2 repeats of the same error, 7 agents, 3 parallel read tracks, 100 preview rows. These are defaults; honor approved project values.

Use start, blocked, and completion notifications only unless the owner opts into a digest. Autonomous development ends before UAT and production.


## V7 interaction compatibility
Unattended is the default execution mode and has `review_level: not_applicable`. It uses Decision Inbox only for genuine authority boundaries. A user request to switch to attended must apply at a reconciled safe checkpoint through `RECONFIGURING`; do not interrupt an atomic SAP operation.
