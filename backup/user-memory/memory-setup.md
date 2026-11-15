# Memory conventions + how this user works

## Where memory lives

User memory: `%APPDATA%\Code\User\globalStorage\github.copilot-chat\memory-tool\memories\*.md` —
roughly the first **200 lines** load into every request, across all workspaces. Length is a
per-request cost, not a one-time one, so measure before adding: `verify-all.ps1` section 4 prints
`used=/200 headroom=` on every run, and it fails the run when the budget is exceeded.

Repo memory: per-workspace, under `…\workspaceStorage\<hash>\GitHub.copilot-chat\memory-tool\memories\repo\<PROJECT>\`,
read on demand.

Project facts go in repo memory, one subfolder per project — never a flat file. Dated history,
sync logs, and superseded tables go to `~/.copilot/docs/archive/`. When a rule and an archive
disagree, the memory rule wins, but verify against the live system before acting on either.

Exact paths, the hook JSON contract, and the repository table:
`D:\abap-copilot-kit\docs\reference\environment.md`

- Framework repo `D:\abap-copilot-kit` = GitHub `naruepan2/abap-copilot-kit`. **Deliberately
  private.** The routing table no longer names a system: which server reaches which system is in
  `Projects\_routing.local.md` (gitignored), and history was rewritten on 2026-11-15 to remove the
  names that had leaked into a scanner pattern. Do not put a system, client, customer, host or user
  back into a tracked file — that decision was made twice and reversed twice. Unauthenticated
  `curl` returns 404 for a private repo while `git ls-remote` succeeds, so **404 never proves a
  repo is absent**.
- `~/.claude/CLAUDE.md` loads into every request (`chat.useClaudeMdFile` defaults `true`).
  Disabled in `settings.json` on 2026-11-13 — its only instruction pointed at a nonexistent
  `/graphify` skill. Re-enable by removing that one line.

## How this user works

- **Verify, never guess.** Every environmental claim needs a command output, file read, or tool
  result from this session. Otherwise write `UNVERIFIED` and name the check. A labelled guess is
  acceptable; a guess stated as fact is not.
- **Plan first.** Say what will change and the trade-offs, then wait — especially outside their files.
- **Keep a way back.** Back up or archive before restructuring; move rather than delete.
- **Reject duplication.** Two copies of one rule is a defect. Point at the existing rule.
- **Tool surface.** Prefer the VS Code tools picker per task; config is the fallback.
- **Short and scannable.** Tables, short sections, a one-line conclusion.
- **Language:** Thai with English technical terms; artifacts themselves stay English.
- **Human gates.** Detect automatically, decide only with approval.
- **Ownership.** `*-by-pongg` files are the user's. Everything else under `~/.copilot` belongs to
  its package — ask before touching it.
- **Cheap wins count.** For low-risk cleanup, do it rather than reopening the decision.

## Two rules that bite in practice

- **Hook firing is per event, not per harness** (2026-11-15): `subagentStart` fires (logged per
  spawn); `postToolUseFailure` has never written a ledger here; `sessionStart` moves
  `surface.json` `takenAt` but its event name is unverified. Never report a hook as having run
  without a log line or a changed file as evidence.
- **Agent `tools:` prefixes**: an MCP server is matched by its **`mcp.json` key**; an extension tool
  needs **one explicit `<extensionId>/<toolName>` line each**, because a wildcard yields zero,
  silently. Full verified/failed list: skill `mcp-surface-audit`, section "Tool entry matching".
