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
| A real project | `Projects/<PROJECT>/README.md` (local only, never committed) |

## Access

- scope: portfolio | workspace | project | program
- read-inside: allowed, targeted only
- write-inside: allowed (one owner per artifact)
- read-outside: require explicit user permission
- write-outside: require explicit user permission
- shared-read-only: `INDEX.md`, `roster.json`, `project.yaml`, `program.yaml`, this file
- forbidden: recursive scan of the workspace root

Never run `Get-ChildItem -Recurse` or `grep -r` from this folder's root. Use `INDEX.md`,
a manifest, or an explicit path.

## Session start

1. Read `INDEX.md`.
2. Read the nearest `AGENTS.md`.
3. Read `project.yaml` / `program.yaml` for the current project or program.
4. Read the memory card (its location is described in `INDEX.md`).
5. Confirm scope and the SAP system/client before any SAP call.
6. Ask before crossing a project boundary.

## Ownership

- `agents/*-by-pongg.agent.md` and self-authored skills are the user's — editable.
- Everything else here, and anything under `%USERPROFILE%\.copilot` that is not
  `*-by-pongg`, is vendor/installer-owned: read-only.
- Moving, deleting, or renaming a file requires the user's explicit approval.

## Never

- Store a password, token, key, or credential in any file.
- Commit customer identifiers (SID, client, transport). `Projects/*` is gitignored.
- State a guess as fact. Write `UNVERIFIED` and name the check instead.
