# SAP-native guardrails

Resolve rules by ECC, S/4HANA on-prem/private/public, BTP ABAP, Standard ABAP, or ABAP Cloud.

For every slice classify: language/API compatibility; security/input trust; authorization; client isolation; SAP LUW/update consistency; locking/concurrency; database/performance; exception/cleanup; testability/observability; transport/lifecycle; migration/Clean Core; privacy/external effects.

Mandatory controls:
- Prefer standard/configuration and released APIs/extension points. Record release contract, deprecation, successor, and migration debt.
- Reject unallowlisted dynamic SQL/calls/identifiers, direct physical paths, credential logging, and uncontrolled outbound calls.
- Test allowed/denied authorization. Never ignore `AUTHORITY-CHECK` result.
- Treat cross-client access, Native SQL/ADBC/AMDP client handling, schema/index changes, and authorization changes as high risk.
- Reusable classes/BAdIs/FMs must not own `COMMIT WORK` unless their contract explicitly requires it. Respect RAP transactional buffer/save sequence.
- Define enqueue/ETag strategy before read-modify-write. Test foreign lock, stale ETag, and duplicate submission where relevant.
- Avoid SQL in loops, unbounded reads, needless columns, and unsupported performance guesses. Require SAT/ST05/SQL Monitor evidence for triggered high-volume changes.
- Discover organization ATC/CVA/readiness variants live. New priority 1/2 findings fail by default.
- Check TADIR, package, original system, namespace, transport/task, lock, inactive version, and source hash before write.
- Keep transport release/import, production write, mass update/delete, real external effects, and productive job scheduling outside the autonomous envelope.
