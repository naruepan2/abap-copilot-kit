# Client and tool reality

Current tool state and client identity are run state, not durable knowledge. Verify them in the
live system; never infer them from a workspace root, connection list, or a remembered snapshot.

## Client matrix

Record a matrix before any data, dump, runtime, or UI claim. Use the real identifiers observed in
the target system.

```yaml
client_matrix:
  development_client: null       # where source is edited and activated
  unit_test_client: null
  runtime_client: null           # where the Fiori/OData/function actually runs
  fiori_preview_client: null
  data_validation_client: null
  dump_clients: []
  tool_connections: {}           # tool -> {client, destination, evidence_id}
  unresolved_mismatches: []
```

Hard rules:

- A zero-row query in the wrong client is not evidence that data is absent.
- A dump from another client does not prove failure in the approved target.
- Every runtime, data, performance, and service claim names the client it came from.
- A mismatch stays in `unresolved_mismatches` until reconciled with live evidence. Do not
  silently switch destinations or reuse another client's result.

## Phase tool gate

Check tool availability again before **discovery, write, verification, and recovery** — not only
once at intake. For each phase record:

- tool visible and enabled in the current chat session;
- destination and client the tool is actually pointed at;
- package allowlist / write permission / supported object types;
- last verified tool profile or version hash;
- known quirks observed in this landscape.

When a tool reports disabled, missing, or access denied: re-arm or request owner action. Do not
change destination behind the owner's back. A picker may show stale state in an open chat; a new
chat or reload often fixes it — confirm by a harmless read probe before declaring `BLOCKED_TOOLING`.

## Readback contract

`Edit successful`, `SAP accepted the write`, and activation responses are claims, not proof.
After every state change, read back source, active/inactive state, package, and object inventory.
A whitespace-normalization mismatch usually requires readback, not replay. Tool capability notes
expire when the MCP/tool profile hash changes.

## Evidence

Keep the matrix and per-phase checks in the run folder. Before a runtime or data claim, run
`scripts/validate_client_matrix.py <file.json>`; a non-empty `unresolved_mismatches` list or a
missing runtime client fails the gate.
