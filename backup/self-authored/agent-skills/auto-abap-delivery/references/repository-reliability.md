# Repository reliability

Every state-changing call has a contract: intent recorded before, observed result reconciled after.

## Before and after a write

Before: persist command ID, target object, expected source hash/state, writer lease, package, and
activation expectation.

After **every** create/edit/activation — not only uncertain ones — read back source, active and
inactive state, package, and object inventory. `Edit successful`, `SAP accepted the write`, and
activation responses are claims. Compare hashes where the tool exposes them. A whitespace
normalization mismatch needs readback, not replay.

Classify `ABSENT | PARTIAL | GHOST | ACTIVE | INACTIVE`. On timeout, `409`, `500`, or any ambiguous
response, enter `RUNNING.REPOSITORY_RECONCILIATION`: read TADIR/object directory, inactive objects,
and source; write into the existing object if it is truly there. **Never replay create blindly.**

Keep the hygiene ledger with `intended_objects`, `observed_objects`, `ghost_objects`,
`cleanup_owner`, `cleanup_status`. At `READY_FOR_UAT`: ghost objects, unknown partial creations,
and unexplained inactive objects are all zero.

## Object-type validators

- **DDLS**: TADIR exists, source non-empty, language and dependencies valid, syntax probe done,
  activation state known. A DDLS create can persist an object before returning an error.
- **FUGR/FUNC**: `FUNCTION-POOL` main program, TOP and UXX include chain present and linked,
  generated function include linked, signature read back against the approved contract, all parts
  activated, and the FM executes in the target client. Compare a broken group with a working one
  before changing source.
- **CLAS**: language version, class properties, test include state, and activation readback.
- **SRVD/SRVB**: version/settings, activation sequence; publication is a separate action and no
  runtime claim precedes it.

Tool capability notes expire when the MCP/tool profile hash changes. Refresh them per phase.
