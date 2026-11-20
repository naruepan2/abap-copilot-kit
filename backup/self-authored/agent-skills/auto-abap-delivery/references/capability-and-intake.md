# Capability audit and intake

## Live discovery
- Enumerate MCP servers, tool names/schemas, read/write/destructive classification, health, identity, SID/client, authorization, object coverage, source read/edit, activation, ABAP Unit, ATC, trace, diff, lock, and transport capabilities.
- Save `capability-snapshot.yaml`. Refresh after restart, configuration change, unknown-tool response, or resume.

## Intake order
1. Business outcome, current/expected behavior, work type, ticket/spec, sample input/output, deadline, desired `READY_FOR_UAT` boundary.
2. Read-only target discovery: product/release, ABAP platform, database, language version, current client, object metadata, TADIR, package, original system, active/inactive source, lock, dependencies, test classes, ATC findings, and TR when available.
3. Ask only unresolved landscape mapping: Workbench, unit-test, sandbox, customizing/configuration master, authorization, integration, UAT, and production clients.
4. Resolve package, TR/task, naming, test-data policy, sensitive fields, external destinations, ATC variants, and trace permission.
5. Produce an assignment contract and request approval.

Never store passwords, tokens, tickets, private keys, or client secrets. Store a secure destination alias only.
