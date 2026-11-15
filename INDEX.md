# INDEX

Shared read-only. Keep it under one screen; it is a map, not documentation.

## Framework files

| Path | What it is |
|---|---|
| `AGENTS.md` | Workspace contract: access scope, session-start order, ownership |
| `roster.json` | Which agents may be delegated to, and which may not |
| `agents/*-by-pongg.agent.md` | The user's agents, editable |
| `skills/mcp-surface-audit/` | Procedure for keeping the tool surface accurate |
| `skills/capture-lesson/` | Procedure for turning a finding into a durable artifact |
| `skills/new-program/` | Scaffold a new project or program record without guessing a SID |
| `hooks/` | Detection-only hooks; only `*.json.template` is committed |
| `docs/` | Architecture, ownership, tool routing, anti-hallucination rules |
| `docs/reference/` | Lookup detail kept out of memory: ARC-1 layers and gotchas, TLS, skill inventory, physical paths, hook contract, detail levels |
| `config-templates/` | `mcp.json`, `settings.json` and ARC-1 skeletons: `arc1.env.template`, `arc1-connections.template.json` |
| `memory-templates/` | Seed for user memory |
| `templates/` | `project.yaml`, `project-README.md`, `program.yaml`, `program-README.md`, `spec.md`, `spec-INDEX.md`, `changes.md` |
| `tooling/` | Audit scripts that measure context and check consistency. `sap-connection.ps1` is the logon list (add/remove/list, like ABAP FS's Connection Manager); `sap-secret.ps1` holds each password in DPAPI; `sap-arc1-launcher.ps1` starts `-Connection <name>` and repairs a stale password; `sap-auth-probe.js` decides whether a stored password still authenticates (OK / STALE / UNKNOWN, Node so the verdict matches ARC-1); `workspace-sync.ps1` mirrors a program's contract files into the private workspace repository by allowlist, never the customer's specification; `install-kit.ps1` copies agents, tooling and skills into place and refuses to overwrite a newer live file |
| `backup/` | A recovery snapshot of user memory. Not loaded by anything — see its README before restoring |
| `Projects/README.md` | How to add a project; project folders are not committed |

## Memory — where the real thing lives

User memory is loaded by VS Code from the user data folder, **not** from this repository:

```
%APPDATA%\Code\User\globalStorage\github.copilot-chat\memory-tool\memories\
```

Repo memory is per-workspace:

```
...\workspaceStorage\<workspace-hash>\GitHub.copilot-chat\memory-tool\memories\repo\
```

This repository does not duplicate either one as a working copy. `memory-templates/` holds a seed
only; a copy stored here would go stale and be loaded by nothing.

`backup/user-memory/` is the one deliberate exception, and it is not a working copy either: it is a
snapshot for disaster recovery, sanitized on the way in, and nothing reads it. Live memory stays
the only thing VS Code loads.

**`docs/reference/` is the counterpart.** Detail that is needed occasionally rather than every
session lives there, and memory carries one pointer line to it. Memory is the expensive place —
roughly 200 lines load into every request — so a lookup table belongs in reference, and only the
rule that governs behaviour belongs in memory.

## Projects

**Not a boundary.** `Projects\` is a local notebook of verified facts; it does not select
a SAP system or restrict any tool. Connections are user-scoped — see **Connections** in
`AGENTS.md` before trusting any project-level assumption.

Not committed — project records carry customer identifiers. A project has
`Projects\<PROJECT>\README.md` and `project.yaml`; a program has
`Projects\<PROJECT>\<PROGRAM>\README.md` and `program.yaml`. There is no per-level
`AGENTS.md`, on purpose. Conventions are in `Projects/README.md`.
