# Memory conventions + how this user works

## Where memory lives

User memory: `%APPDATA%\Code\User\globalStorage\github.copilot-chat\memory-tool\memories\*.md` —
roughly the first **200 lines** load into every request, across all workspaces. Measure before
adding anything, because length is a per-request cost, not a one-time one:

```powershell
$m="$env:APPDATA\Code\User\globalStorage\github.copilot-chat\memory-tool\memories"; $t=0; Get-ChildItem $m -Filter *.md | ForEach-Object { $t+=(Get-Content $_.FullName).Count }; "used=$t headroom=$((200-$t))"
```

Repo memory: per-workspace, under `…\workspaceStorage\<hash>\GitHub.copilot-chat\memory-tool\memories\repo\<PROJECT>\`,
read on demand.

Project facts go in repo memory, one subfolder per project — never a flat file. Dated history,
sync logs, and superseded tables go to `~/.copilot/docs/archive/`. When a rule and an archive
disagree, the memory rule wins, but verify against the live system before acting on either.

Exact paths, the hook JSON contract, and the repository table:
`D:\abap-copilot-kit\docs\reference\environment.md`

- Framework repo `D:\abap-copilot-kit` = GitHub `naruepan2/abap-copilot-kit`. **Deliberately
  private** (2026-11-13): its routing table keeps real system names because that is the table's
  value. Do not sanitize it or propose making the repo public without asking. Unauthenticated
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

- **Hooks do not fire in the Copilot harness.** Measured: `surface.json` `takenAt` unchanged across
  a reload. Run any drift check manually, and never report a hook as having run.
- **Agent `tools:` prefixes**: an MCP server is matched by its **`mcp.json` key**; an extension tool
  needs **one explicit `<extensionId>/<toolName>` line each**, because a wildcard yields zero,
  silently. Full verified/failed list: the comment block in
  `~/.copilot/agents/abap-developer-by-pongg.agent.md`.
