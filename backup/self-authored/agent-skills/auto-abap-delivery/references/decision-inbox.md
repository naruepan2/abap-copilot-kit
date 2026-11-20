# Decision Inbox

Create only decisions requiring human authority. A card must contain: what happened; why AI cannot decide; current safe state; affected slices/objects/criteria; 2-4 exclusive options; recommendation and confidence; delivery/Clean Core/functional/operational/rollback impacts; required response; safe work that can continue; evidence drawer.

Lifecycle: `OPEN -> VIEWED -> ANSWERED -> VALIDATING -> APPLIED`; alternatives `WITHDRAWN`, `SUPERSEDED`, `REJECTED`. Bind answers to decision revision. Reject stale answers when evidence changes.

Use one notification on creation. Bundle related blockers. Do not spam reminders. Continue unaffected branches when dependency-safe.

Decision packet fields: ID, revision, severity, category, context, current safe state, scope impact, options, recommendation, confidence, evidence IDs, continuation policy, owner response, resulting spec/envelope revision.
