# Memory setup — detail moved out of always-on memory

Detail that used to live in `memory-setup.md` and loads into every request. Read this only when
the setup itself is in question. The short rule set stays in user memory; this file is the lookup.

## Paths

- User memory: `%APPDATA%\Code\User\globalStorage\github.copilot-chat\memory-tool\memories\*.md`.
  Roughly the first 200 lines load into every request, across all workspaces. Length is a
  per-request cost, not a one-time one: `verify-all.ps1` section 4 prints `used=/200 headroom=`
  on every run and fails when the budget is exceeded.
- Repo memory: per-workspace, under
  `...\workspaceStorage\<hash>\GitHub.copilot-chat\memory-tool\memories\repo\<PROJECT>\`,
  read on demand.
- Exact paths, hook JSON contract and the repository table: `docs/reference/environment.md`.
- Dated history, sync logs and superseded tables: `~/.copilot/docs/archive/`. When a rule and an
  archive disagree, the memory rule wins, but verify against the live system before acting.

## Repository visibility — corrected 2026-11-19

The framework repo `D:\abap-copilot-kit` = GitHub `naruepan2/abap-copilot-kit` is **public** and
was already public when the co-edit work started. An earlier memory note said "Deliberately
private"; that note was stale and was corrected. Consequences:

- `Projects/` is gitignored. SID, client, customer, host, real TR numbers and user identifiers
  never enter a tracked file. `verify-all.ps1` section 9c-2 derives forbidden names from local
  project records and fails when one appears in the public tree.
- `workspace-sync.ps1` mirrors only an allowlist (`project.yaml`, `program.yaml`, `README.md`,
  `changes.md`, selected `spec/` files) into a separate private repository. Spec source and
  `.baseline/` are excluded.
- An unauthenticated `curl` returning 404 does not prove a repository is private or absent;
  `git ls-remote` succeeds against the public remote. Do not infer visibility from a 404.

## `~/.claude/CLAUDE.md` history

`chat.useClaudeMdFile` defaults to `true`, so this file would load into every request. It was
disabled in `settings.json` on 2026-11-13 because its only instruction pointed at a nonexistent
`/graphify` skill. Re-enable by removing that one line, and only after replacing the instruction.

## Hook and tool-surface details

- Hook firing is per event, not per harness. Never report a hook as having run without a log line
  or a changed file as evidence. The measured per-event table is in `docs/reference/environment.md`.
- Agent `tools:` prefixes: an MCP server is matched by its **`mcp.json` key**; an extension tool
  needs one explicit `<extensionId>/<toolName>` line each, because a wildcard yields zero,
  silently. Full verified/failed list: skill `mcp-surface-audit`, section "Tool entry matching".
