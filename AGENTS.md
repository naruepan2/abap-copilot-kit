# AGENTS.md — workspace contract

Framework repository for SAP ABAP work with GitHub Copilot in VS Code.
This file is loaded into **every** request when this folder is the open workspace, so it
stays short: it points at other files instead of restating them.

## Map

| Need | Read |
|---|---|
| What exists where | `INDEX.md` |
| Tool routing and evidence rules | `agents/abap-developer-by-pongg.agent.md` |
| Who may be delegated to | `roster.json` |
| Why the design is like this | `docs/architecture.md`, `docs/anti-hallucination.md` |
| A project record, if one exists | `Projects/<PROJECT>/README.md` (local only, never committed) |

## Connections — measure this before trusting any scope claim

**SAP connections are user-scoped, not workspace-scoped.** Opening this folder selects
nothing and restricts nothing. Measured 2026-11-13:

| Where | What is configured there |
|---|---|
| `%APPDATA%\Code\User\mcp.json` | every MCP server: `arc-1`, `adam`, `gsd-120`, `ds4-900`, plus the UI5 server (`@ui5/mcp-server`). The Fiori server is declared in the CLI config instead |
| `%APPDATA%\Code\User\settings.json` → `abapfs.remote` | every ABAP FS destination (more than one customer at a time) |
| `%APPDATA%\Code\User\settings.json` → `adt.mcpServer.*` | the ADT MCP server and its settings |

Consequences, in order of how easy they are to get wrong:

- A folder named after a project does **not** point the tools at that project's system.
  Every configured server stays reachable from every folder.
- Several customers can be reachable simultaneously. Pick the client per task, from the
  picker or the tool parameter, and confirm it out loud before a read or a write.
- A workspace-scoped `.mcp.json` at the folder root is the only real pin, and using it
  would mean duplicating the server configuration. Not adopted here on purpose.
- ABAP FS and the ADT MCP server can point at different landscapes. One working does not
  prove the other is on the same host.

## Access

- scope: workspace | project record (not a system boundary — see **Connections**)
- read-inside: allowed, targeted only
- write-inside: allowed (one owner per artifact)
- read-outside: require explicit user permission
- write-outside: require explicit user permission
- shared-read-only: `INDEX.md`, `roster.json`, `project.yaml`, `program.yaml`, this file
- forbidden: recursive scan of the workspace root

Never run `Get-ChildItem -Recurse` or `grep -r` from this folder's root. Use `INDEX.md`,
a manifest, or an explicit path.

## Session start

Pick an input tier first. It decides what you read, not what you answer.

- `light` — a question, analysis or review: `INDEX.md` and the nearest `AGENTS.md` only.
- `task` — code, file or SAP work: add the project record and its memory card.
- `deep` — a new project, incident or design: add the relevant reference docs and user memory.

`docs/reference/detail-levels.md` governs output length. Do not confuse the two enums.

1. Read `INDEX.md`.
2. Read the nearest `AGENTS.md`.
3. Read `project.yaml` / `program.yaml` if a project record exists for this task.
4. Read the memory card (its location is described in `INDEX.md`).
5. Confirm the SAP system and client explicitly. This folder does not select them.
6. Ask before crossing a project boundary.

## Ownership

- `agents/*-by-pongg.agent.md`, self-authored skills, and this kit's eleven skills
  (`skills/` in the clone — edit there, then reinstall) are editable.
- Everything else here, and any other file under `%USERPROFILE%\.copilot`, is
  installer-owned: read-only.
- Moving, deleting, or renaming a file requires the user's explicit approval.

## Never

- Store a password, token, key, or credential in any file.
- Commit customer identifiers (SID, client, transport). `Projects/*` is gitignored.
- State a guess as fact. Write `UNVERIFIED` and name the check instead.
