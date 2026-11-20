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
| Framework repo (agents, skills, hooks, templates, reference) | `$env:ABAP_KIT_ROOT`, else the pin in `~/.copilot/state/kit-root.txt`, else the parent of `tooling\` (the order `install-kit.ps1` uses) |
| GitHub | `naruepan2/abap-copilot-kit` — **public**; customer data stays in gitignored `Projects/` |
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

### Tool picker vs session snapshot — observed 2026-11-20

After the user enables tools in the picker, a chat that was already open may still answer
`disabled by the user` for those tools. In the reported case the persisted state had all tools
set to `true`, yet `SAPWrite`, `SAPSearch`, `SAPRead`, ADT `object_create` and ABAP FS
`get_connected_systems` stayed disabled at runtime; re-arming the tool group in that session made
`SAPSearch` work immediately. Interpretation: the active conversation holds a stale tool
allowlist from before the picker change — a session/cache effect, not a broken `mcp.json`.

Procedure when this happens:

1. Do not retry the same tool more than once and do not edit config to "fix" it.
2. Prefer opening a **new chat** or reloading the window: tool bindings are set at session start.
3. If an immediate retry is needed, re-arm the affected tool group once, then verify with a small
   read-only call before doing real work.
4. If it still fails, inspect the live `tools/list` for that server; the persisted picker state is
   not the same thing as the current session's bound tools.

This is a harness behaviour, not an SAP guardrail. Never widen a tool list or grant write access
to a read-only agent to work around it.

## Hook contract (verified 2026-11-13 from shipped product code)

One file, `~/.copilot/hooks/hooks.json`:

```json
{
  "version": 1,
  "hooks": {
    "sessionStart": [
      { "type": "command", "command": "node \"<path>/session-drift.cjs\"", "timeoutSec": 20 }
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
- **Which hook events fire: measure per event, never assume.** This section used to say "hooks do
  not fire in the Copilot harness", dated from a reload in which `surface.json`'s `takenAt` did not
  move. That is a conclusion about one event, and it was later contradicted:

  | Event | Status 2026-11-15 | Evidence |
  | --- | --- | --- |
  | `subagentStart` | **fires** | `~/.copilot/state/subagent-rules.log` gained five entries during one session (`trusted` / `restricted` per spawn) |
  | `sessionStart` | **writes**, event name unverified | `surface.json` `takenAt` moved twice in one session (`17:00:56Z`, `17:01:34Z`); attribution to this event versus a manual run was not established |
  | `postToolUseFailure` | **no evidence** | no lesson ledger has ever existed at either documented path |

  The rule that survives: **never report a hook as having run until a log line or a changing file
  says so**, and re-measure per event rather than generalising from one. Treat `chat.useHooks` and
  `chat.hookFilesLocations` as Local-harness settings.

### Payload each hook reads from stdin

The output shapes above are documented by the product; the **input** shapes are not, so each hook
defends itself and this table records what it actually parses. A field not listed here is one the
code reads defensively with a fallback.

| Event | Fields the hook reads | Fallback when absent |
| --- | --- | --- |
| `sessionStart` | **none** — it reads no stdin at all | builds its own surface from disk |
| `subagentStart` | `agentName` or `agent_type` (whichever is present) | `'unknown'` agent, treated as not approved |
| `postToolUseFailure` | `toolName` or `tool_name`; `error` or `errorText`, which may be a **string or an object** | no row is written when the tool name is missing; an object is reduced to its `.message` |

Measured 2026-11-16: `{\"error\":{\"message\":\"disk full\",\"code\":28}}` used to be recorded as
`[object Object]`, which lost the only actionable part of the row. The object case is now serialised.
An `agentName` that arrives under a different key is the known weak point of `subagentStart`: a hook
cannot enumerate the harness's payload, so an extra field name has to be added by hand when it
appears.
