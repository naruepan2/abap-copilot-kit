# Evidence and UAT handoff

Evidence fields: ID, task/run, target SID/client, spec revision/hash, autonomy-envelope hash, object, source/dependency hashes, check, raw result location, captured time, limitations, freshness.

Invalidate evidence when source, dependency, spec, target, relevant configuration, or reconciled command boundary changes.

Before `READY_FOR_UAT`: all required slices complete; every acceptance criterion maps to fresh automated evidence or explicit manual UAT; no `REWORK`; syntax/activation, focused/regression tests, required ATC/CVA/readiness and guardrails pass or have approved disposition; temporary artifacts are cleaned/disclosed; transport is unreleased.

UAT pack: executive summary; approved revisions; changed objects; before/after; acceptance traceability; ABAP Unit/ATC/system cross-check/guardrail results; limitations and residual risk; exact UAT client, scenarios, data, steps and expected results; transport status; rollback/disable approach; evidence index; explicit statement that production action was not performed.
