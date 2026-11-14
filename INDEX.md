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
| `config-templates/` | `mcp.json` and `settings.json` skeletons |
| `memory-templates/` | Seed for user memory |
| `templates/` | `project.yaml`, `project-README.md`, `program.yaml`, `program-README.md`, `spec.md`, `spec-INDEX.md`, `changes.md` |
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

This repository deliberately does not duplicate either one. `memory-templates/` holds a
seed only; a copy stored here would go stale and be loaded by nothing.

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
