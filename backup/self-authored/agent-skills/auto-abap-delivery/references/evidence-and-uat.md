# Evidence and UAT handoff

Evidence fields: ID, task/run, target SID/client, spec revision/hash, autonomy-envelope hash, object, source/dependency hashes, check, raw result location, captured time, limitations, freshness.

Invalidate evidence when source, dependency, spec, target, relevant configuration, or reconciled command boundary changes.

Before `READY_FOR_UAT`: all required slices complete; every acceptance criterion maps to fresh automated evidence or explicit manual UAT; no `REWORK`; syntax/activation, focused/regression tests, required ATC/CVA/readiness and guardrails pass or have approved disposition; temporary artifacts are cleaned/disclosed; transport is unreleased.

UAT pack: executive summary; approved revisions; changed objects; before/after; acceptance traceability; ABAP Unit/ATC/system cross-check/guardrail results; limitations and residual risk; exact UAT client, scenarios, data, steps and expected results; transport status; rollback/disable approach; evidence index; explicit statement that production action was not performed.

## Post-run evidence additions (V9, additive)

Before `READY_FOR_UAT`, create a minimal evidence package in the run folder: `RUN_EVIDENCE.md`
and `evidence-manifest.yaml`. Mark evidence mode as `specification_conformance` only when an
approved spec exists; otherwise use `observed_run` and state that full conformance cannot be
confirmed. Never create a retroactive spec and call it approved.

### Scoped owner confirmation

A free-form owner statement must be mapped to named checks. Record `confirmation_id`,
confirmer, `confirmed_checks` and `does_not_confirm`. A general "it works" statement may close
foreground/output checks only. It never closes authorization-negative tests, full data
reconciliation, performance targets or service runtime contract.

### Test result taxonomy

Classify every result as one of: `ABAP_UNIT`, `SMOKE`, `INTEGRATION`, `SERVICE_RUNTIME`,
`STATIC_REVIEW`, `MANUAL_OWNER_CONFIRMED`, `DIAGNOSTIC_DRIVER`. A diagnostic driver result must not
be reported as ABAP Unit evidence. Record `execution: NOT_RUN_BY_AUNIT_TOOL` when applicable.

### Per-object verification

Do not claim solution-wide ATC or test success from partial results. Each object carries explicit
status: `PASS | FINDINGS | NOT_REPORTED | NOT_SUPPORTED | NOT_RUN | STALE` for syntax, activation,
unit test and ATC. Disclose every `NOT_REPORTED` and `NOT_SUPPORTED`.

### Unpublished service rule

An active service binding that is not published, with no runtime OData/Fiori evidence, resolves
to `READY_FOR_MANUAL_TEST`, not `READY_FOR_UAT`, unless the approved spec explicitly waives
service runtime evidence.
