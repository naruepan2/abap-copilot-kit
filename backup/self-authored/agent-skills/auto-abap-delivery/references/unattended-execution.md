# Unattended execution

Use `approve once, run to gate`. Freeze spec hash, target, package/TR/task, object scope, actions, data/external policies, checks, budgets, stop conditions, notification policy, and `READY_FOR_UAT` target.

Continue silently when reversible, in scope/envelope, evidence-backed, and free of business ambiguity or production/irreversible effects. Defer non-blocking warnings and successful repairs to the final report.

Interrupt only for completion or a genuine decision boundary: scope/spec change, irreversible action, target mismatch, unresolved drift/lock, API/architecture trade-off, exhausted budget, missing tool/access, security/privacy/LUW blocker, or expired lease.

Default run budget: 8 hours, 500 tool calls, 3 repairs per slice, 2 repeats of the same error, 7 agents, 3 parallel read tracks, 100 preview rows. These are defaults; honor approved project values.

Use start, blocked, and completion notifications only unless the owner opts into a digest. Autonomous development ends before UAT and production.


## Interaction default
Unattended is **not** the default. Unqualified scope preselects Attended Standard; only qualified
task and topology may default to unattended, and critical scope requires at least Controlled.
An owner override is a shadow trial: it may permit one scoped unattended run with durable approval
evidence, but it does not promote qualification. A switch to attended applies at a reconciled safe
checkpoint through `RECONFIGURING`; do not interrupt an atomic SAP operation.
