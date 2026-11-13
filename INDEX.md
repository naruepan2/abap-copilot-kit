# INDEX

Shared read-only. Keep it under one screen; it is a map, not documentation.

## Framework files

| Path | What it is |
|---|---|
| `AGENTS.md` | Workspace contract: access scope, session-start order, ownership |
| `roster.json` | Which agents may be delegated to, and which may not |
| `agents/*-by-pongg.agent.md` | The user's agents, editable |
| `skills/mcp-surface-audit/` | Procedure for keeping the tool surface accurate |
| `hooks/` | Detection-only hooks; only `*.json.template` is committed |
| `docs/` | Architecture, ownership, tool routing, anti-hallucination rules |
| `config-templates/` | `mcp.json` and `settings.json` skeletons |
| `memory-templates/` | Seed for user memory |
| `templates/` | `project-README.md`, `program-README.md` |
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

## Projects

Not committed — project folders carry customer identifiers. Each project has
`Projects\<PROJECT>\README.md`, `AGENTS.md`, and `project.yaml`; each program has
`Projects\<PROJECT>\<PROGRAM>\README.md`, `AGENTS.md`, and `program.yaml`.
Conventions are in `Projects/README.md`.
