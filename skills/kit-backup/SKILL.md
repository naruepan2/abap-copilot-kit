---
name: kit-backup
description: >-
  User-invoked only: snapshot, verify and restore the self-authored agents and
  skills of this kit into backup/self-authored. Restore is file-by-file with a
  diff first; no automatic overwrite. Never backs up credentials, MCP config,
  Projects, or third-party installer-owned skills.
disable-model-invocation: true
---

# Kit backup

This is a user-invoked maintenance skill. It does not run on its own, and it
never changes SAP, MCP configuration or existing repo configuration.

## Scope — from `backup/self-authored/MANIFEST.md` only

| group | live location | snapshot |
|---|---|---|
| agents | `~/.copilot/agents/*by-pongg.agent.md` | `backup/self-authored/agents/` |
| Copilot skills | kit-authored skills under `~/.copilot/skills/` | `backup/self-authored/copilot-skills/` |
| agent skills | `auto-abap-delivery` under `~/.agents/skills/` | `backup/self-authored/agent-skills/` |

The manifest is the allowlist. A path not named there is out of scope.
Never back up: `mcp.json`, credentials, connections, `Projects/`, SAP data,
third-party skills (npx/SAP AI Dev Toolkit), or extension-contributed tools.

## Modes — ask the user which one

1. **verify** (default / read-only) — compare each snapshot file hash with its
   live counterpart. Report `MATCH`, `DIFFERENT`, `MISSING_LIVE`, `MISSING_SNAPSHOT`.
   Do not copy anything.
2. **snapshot** — copy live files byte-for-byte into the snapshot and refresh
   `MANIFEST.md`. Show the list of files added/updated/removed before writing;
   require approval. Preserve the source filenames exactly.
3. **restore** — restore one or more files the user names explicitly. For each:
   show both paths, the hash of each, and a line-level diff first; ask for
   per-file approval; only then copy. Never restore all files implicitly.

## Rules

- Never overwrite a live file during `verify` or `snapshot`.
- During `restore`, a `DIFFERENT` live file is a decision, not an error: show
  the diff and let the user choose. A stale snapshot never silently wins.
- Do not edit a snapshot to change behaviour. The live copy is authoritative.
- Use byte-for-byte copies. No encoding conversion, no formatter, no BOM change.
- Report terse counts and any file that was skipped, with its reason.
- If the manifest is missing, STOP — do not infer scope from folder names.
