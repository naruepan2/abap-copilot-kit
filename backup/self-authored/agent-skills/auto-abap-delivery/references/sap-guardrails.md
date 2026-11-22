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
- Discover organization ATC/CVA/readiness variants live. Record the observed variant and its check IDs with client and timestamp; new priority 1/2 findings fail by default. `processed=0` is `NOT_REPORTED`, never a PASS.
- Check TADIR, package, original system, namespace, transport/task, lock, inactive version, and source hash before write.

## Clean Core levels and ATC

Classify each dependency and extension by the **lowest** level it uses; one internal object demotes
an otherwise clean extension. SAP objects are internal by default — "not classified" is not safe.

| Level | Meaning | ATC | Action |
|---|---|---|---|
| A | Released API/extension point with stability contract | no finding | target state |
| B | Classic API, no stability contract | priority 3 info | accept/monitor, adopt successor where sensible |
| C | Internal object, SAP table **read** | priority 2 warning | minimize; wrap with one finding-level exemption where approved |
| D | `noAPI`, SAP table **write**, modification, disallowed enhancement, critical statement (`EXEC SQL`, DB hint, kernel/system calls) | priority 1 error | remediate immediately; do not exempt |

Relevant live checks to look for: `SYCM_USAGE_OF_APIS`, `SYCM_ALLOWED_ENH_TECHNOLOGY`,
`CI_SEARCH_CUST_MODIFICATIONS`, `CI_CRITICAL_STATEMENTS`, `SLIN_SEC`. A wrapper inherits the
wrapped object's level (classic → B, internal → C, `noAPI` → D — do not build the last one) and
should collapse many findings into one finely scoped exemption with an owner and retirement plan.
Use Cloudification Repository release/classification JSON for the observed product and FPS; an
object in the changelog is not automatically demoted, but must be monitored.

BAdIs are the recommended enhancement technology: implicit/explicit enhancements and
modifications are Level D. Never treat ATC configuration advice ("block transport release") as
permission to configure, release, or import transports — it is an evidence requirement only.

## Release-state verification

Verify release state read-only, in the live client, and record **which channel** produced the
result: `i_apistateofrepositoryobject` / `i_apisforclouddevelopment` /
`I_APIsWithCloudDevSuccessor`, the product/FPS-specific Cloudification JSON, ADT `api:` search or
API State filter, or the F5865 Released Objects app. A zero-row query means `NOT_REPORTED`, not
"not released". Record channel, client, and capture time with the evidence ID.
- Keep transport release/import, production write, mass update/delete, real external effects, and productive job scheduling outside the autonomous envelope.

## Repository hygiene

After every create/edit/activation — especially uncertain or failed ones — persist command intent,
read TADIR/object
directory, read source and active/inactive state, check package/lock/transport-local status, then
classify `ABSENT | PARTIAL | GHOST | ACTIVE | INACTIVE`. Cleanup or open a Decision Request. Retry
only after reconciliation.

Keep a repository hygiene ledger with `intended_objects`, `observed_objects`, `ghost_objects`,
`cleanup_owner` and `cleanup_status`. At `READY_FOR_UAT`: `unapproved_ghost_objects = 0`,
`unknown_partial_creations = 0`, `inactive_unexplained_objects = 0`. `READY_FOR_MANUAL_TEST` is
allowed when an owner cleanup action is explicitly recorded and no further autonomous write is
safe.

Local-package lifecycle must be disclosed: a local package with no transport cannot establish
deployment readiness, only local development behavior.

On timeout, `409`, `500`, or an ambiguous response enter reconciliation; never replay create
blindly. Per-type validators and the full readback contract are in
[repository-reliability.md](repository-reliability.md). Client identity and the phase tool gate are
in [client-and-tool-reality.md](client-and-tool-reality.md). RAP-specific rules are in
[rap-persistence-and-draft.md](rap-persistence-and-draft.md); built-in typed UI fields in
[ui-text-and-type-contracts.md](ui-text-and-type-contracts.md).
