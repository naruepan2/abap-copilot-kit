# Relocation runbook — moving the kit

Status: **procedure, 2026-11-24.** Applies when `D:\abap-copilot-kit` (or any later clone path) is
moved, renamed, recloned to another drive, or replaced by a fresh clone. No SAP state is changed.

## Why this exists

A drive letter cannot be baked into a committed script. The four kit scripts already resolve the
root in the same order — `$env:ABAP_KIT_ROOT`, then the pin file, then the parent of `tooling\`
containing `INDEX.md` (`tooling/verify-all.ps1:38-57`, `install-kit.ps1:31-46`,
`workspace-sync.ps1:43-56`, `census.ps1:34-46`). Telling the AI "the toolkit is at path X" is
**not enough by itself**: the installed agent hook, the pin, the copied tooling and the always-on
memory used to point at the old absolute path. Those are machine state, not repo files.

One thing is deliberately path-free: the delivery agent's `PreToolUse` hook calls a shim at a fixed
user-level path (`<user home>\.copilot\state\write-gate-shim.ps1`). The shim reads the pin, so no
agent edit is needed after a move.

## Procedure

Run these in order. Verify each step before the next.

1. **Clone or move.** `git clone <kit-remote> <new-path>` (or move the folder). Confirm
   `Test-Path <new-path>\INDEX.md` and `git -C <new-path> status --short` shows no unexpected
   changes. If the old folder still exists, keep it until step 6 passes; the pin must not point
   at two places at once.

2. **Set the root for this shell and refresh the pin.**
   ```powershell
   $env:ABAP_KIT_ROOT = '<new-path>'
   powershell -ExecutionPolicy Bypass -File '<new-path>\tooling\install-kit.ps1' -Check
   powershell -ExecutionPolicy Bypass -File '<new-path>\tooling\install-kit.ps1'
   ```
   The installer writes `<user home>\.copilot\state\kit-root.txt` and copies every `tooling\*.ps1`
   (including `write-gate-shim.ps1`) to `<user home>\.copilot\state\`. Re-run `-Check` and expect
   zero DIFFERS.

3. **Gate smoke test.** The shim must deny a forbidden action and allow a read:
   ```powershell
   '{"tool":"saptransport","tool_input":{"action":"release"}}' |
     powershell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.copilot\state\write-gate-shim.ps1"
   '{"tool":"sapread","tool_input":{"object":"CL_STANDARD"}}' |
     powershell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.copilot\state\write-gate-shim.ps1"
   ```
   Expect a JSON `permissionDecision: deny` for the first and **no output** for the second. If the
   shim writes "kit root missing or pin stale", step 2 did not update the pin.

4. **Full verification.** `<new-path>\tooling\verify-all.ps1` must end `RESULT: clean`. Run
   `<new-path>\tooling\census.ps1` and expect `no phantom gate`. A stale pin shows up as repository
   drift, not as a SAP error.

5. **Repo memory and project records.** `Projects\` is gitignored and follows the clone **only if**
   you copy it. If the old machine had local project records, copy them into `<new-path>\Projects\`
   and run
   ```powershell
   powershell -ExecutionPolicy Bypass -File '<new-path>\tooling\workspace-sync.ps1' -Workspace <private-mirror-path> -Check
   ```
   The private workspace mirror is a separate clone with its own path; `-Check` reports drift
   without writing. Do not point it at the public kit remote.

6. **Always-on memory.** The four files in `%APPDATA%\Code\User\globalStorage\github.copilot-chat\
   memory-tool\memories\` are machine state and were rewritten to use `<kit-root>` instead of a
   drive letter. Verify with a grep for `D:\` in that folder; if any absolute kit path remains,
   replace it with the kit-root pointer from step 2. Keep the ~200-line total budget.

7. **VS Code session.** Reload Window and open a new chat. The MCP tool cache is session state;
   confirm in the tools picker that the same servers are present, then make one harmless read-only
   call. Old cached server IDs (`abap-mcp`, `sap-docs`) are cosmetic and do not block new keys.

## What must NOT be edited on a move

- Agent hooks: the shim path is fixed; only the pin changes. The `<you>` placeholder in the
  committed agent backup is a template, not a machine-specific value to fill in the repo.
- `reference-assets/salv/`: its `MANIFEST.sha256` uses relative paths and survives a move as-is.
- MCP config (`%APPDATA%\Code\User\mcp.json`): it names connections, not the kit folder.

## Red flags after a move

| Symptom | Meaning |
|---|---|
| Shim prints "kit root missing or pin stale" | step 2 was not run from the new clone |
| `verify-all.ps1` reports repository drift | the copied `~/.copilot/state/*.ps1` are from the old clone |
| An agent tries to open `<old-path>\...` | an uncommitted absolute path is still in that agent; fix the source in `agents/` and reinstall |
| `census.ps1` reports BLIND for a state file | a new installed script has no inventory row; add one in `tooling/census.ps1` |
