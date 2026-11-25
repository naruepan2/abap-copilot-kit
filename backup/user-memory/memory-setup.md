# Memory conventions + how this user works

## Where memory lives

User memory `*.md` in `%APPDATA%\Code\User\globalStorage\github.copilot-chat\memory-tool\memories\`
loads ~first **200 lines** every request. Repo memory loads on demand. Budget: `verify-all.ps1` §4.
Paths, repo visibility, hook and tool-prefix detail:
`<kit-root>/docs/reference/memory-setup.md` (kit root: `$env:ABAP_KIT_ROOT` or the pin in
`~/.copilot/state/kit-root.txt`).

- Framework repo (GitHub `naruepan2/abap-copilot-kit`) is **public**.
  `Projects/` is gitignored: no system, client, customer, host or user in a tracked file.
  Detail and the 404 caveat: `docs/reference/memory-setup.md`.

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

- **Hook firing is per event, not per harness.** Never report a hook as having run without a log
  line or a changed file as evidence. Per-event table: `docs/reference/environment.md`.
- **Agent `tools:` prefixes**: MCP server = `mcp.json` key; extension tool = one explicit
  `<extensionId>/<toolName>` line (wildcard yields zero). Detail: `docs/reference/memory-setup.md`.
