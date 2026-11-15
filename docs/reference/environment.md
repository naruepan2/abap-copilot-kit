# Environment — physical paths and the hook contract

Read on demand. Only the paths you actually need during a task, plus the exact hook JSON shape,
which matters only when editing or debugging a hook.

## Memory locations

| Kind | Path | Loaded |
|---|---|---|
| **User memory** | `%APPDATA%\Code\User\globalStorage\github.copilot-chat\memory-tool\memories\*.md` | every request, roughly the first 200 lines, shared across all workspaces |
| **Repo memory** | `…\workspaceStorage\<workspace-hash>\GitHub.copilot-chat\memory-tool\memories\repo\<PROJECT>\` | on demand, per workspace |

The workspace hash changes with the folder set. To find the current one, look for the folder in
`%APPDATA%\Code\User\workspaceStorage` whose `workspace.json` names this window, or read the
`memory` tool output which prints the resolved path.

Known hash for the ABAP workspace used on 2026-11-13/14 — a shortcut, not a guarantee:

```
fbc6ae2e6722b1312ffc2700081aeccb
```

## Repositories and configuration

| What | Where |
|---|---|
| Framework repo (agents, skills, hooks, templates, reference) | wherever you cloned it — `$env:ABAP_KIT_ROOT`, else the parent of `tooling\` |
| GitHub | `naruepan2/abap-copilot-kit` — **private**, on purpose |
| MCP servers (VS Code) | `%APPDATA%\Code\User\mcp.json` — user scope, key `servers` |
| MCP servers (Copilot CLI) | `%USERPROFILE%\.copilot\mcp-config.json` — user scope, key `mcpServers`. VS Code imports this file as a discovery source named `copilot`, and that source is on by default |
| MCP discovery import | `%APPDATA%\Code\User\settings.json` → `chat.mcp.discovery.enabled`. A server declared in both files above is a duplicate, and `chat.mcp.collisionBehavior` (default `disable`) then switches one copy off — it still appears in the tool picker, with no tools |
| ABAP FS destinations | `%APPDATA%\Code\User\settings.json` → `abapfs.remote` — user scope |
| ADT MCP server settings | `%APPDATA%\Code\User\settings.json` → `adt.mcpServer.*` |
| Agents | `%USERPROFILE%\.copilot\agents\` |
| Roster allowlist | `%USERPROFILE%\.copilot\roster.json` |
| Hooks | `%USERPROFILE%\.copilot\hooks\hooks.json` |
| Hook/state scripts and measurement output | `%USERPROFILE%\.copilot\state\` |
| Dated archive | `%USERPROFILE%\.copilot\docs\archive\` |

Because the MCP servers and ABAP FS destinations are **user-scoped**, opening a folder selects
nothing: every configured server stays reachable from every folder. Confirm the system and client
explicitly before a read or a write.

## Hook contract (verified 2026-11-13 from shipped product code)

One file, `~/.copilot/hooks/hooks.json`:

```json
{
  "version": 1,
  "hooks": {
    "sessionStart": [
      { "type": "command", "command": "node \"<path>/session-drift.cjs\"", "timeoutSec": 10 }
    ]
  }
}
```

- `"version": 1`, camelCase event names, one `{type, command, timeoutSec}` entry per handler.
  Per-event files (`sessionStart.json` and friends) are **ignored**.
- A hook that injects context must answer in exactly this shape:

```json
{ "hookSpecificOutput": { "hookEventName": "SessionStart", "additionalContext": "…" } }
```

- `hookEventName` must equal the event that fired. A **top-level** `additionalContext` is
  ignored, and a mismatched `hookEventName` is stripped.
- **Hooks do not fire in the Copilot harness.** Measured: `~/.copilot/state/surface.json`
  `takenAt` did not change across a reload, while the installed hook config was unchanged. Treat
  `chat.useHooks` and `chat.hookFilesLocations` as Local-harness settings; never report a hook as
  having run until a firing is observed in `takenAt` or a log file.
