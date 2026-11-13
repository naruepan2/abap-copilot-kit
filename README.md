# abap-agent-workspace-vscode-github-copilot

A reproducible VS Code Copilot setup for SAP/ABAP work, built on three rules:

1. **Route, don't overlap.** One task, one MCP server. A per-task table, not a global ranking,
   because a priority list gets skipped the moment the top tool lacks the operation.
2. **Never guess.** Every environmental claim needs a tool result from the current session.
   A hypothesis is fine when labelled; a guess stated as fact is not.
3. **The human decides.** AI detects drift and proposes changes. You approve every file edit.

SAP tooling changes constantly — a server updates, an extension ships new tools, an installer
rewrites its agents. This workspace is built to stay correct when that happens, instead of
accumulating instructions that were true once.

## What is here

```
agents/            custom agents with routing, safety and evidence gates
skills/            hand-written skills (mcp-surface-audit)
roster.json        delegation allowlist — read-only subagents only
hooks/             three detection-only hooks (see below)
docs/              architecture, tool routing, ownership, anti-hallucination
config-templates/  mcp.json and settings fragments with placeholders
memory-templates/  user profile template
```

## Hooks

All three are detection only. None of them edits an agent, skill, or config file.

| Event | Script | What it does | Context cost |
| --- | --- | --- | --- |
| `sessionStart` | `session-drift.cjs` | snapshots agents, both skill roots, MCP servers, extension tool counts; reports only what changed | `{}` when nothing changed |
| `subagentStart` | `subagent-rules.cjs` | prepends the namespace and evidence rules to a delegated task; restricts any agent not in `roster.json` | once per subagent |
| `postToolUseFailure` | `lesson-capture.cjs` | appends one evidence row per failed tool call | `{}` until the third identical failure |

The subagent hook exists because a subagent runs in its own context: the coordinating
agent's rules do not reach it. Without this, delegating a write would bypass the `Z*`/`Y*`
namespace rule and the evidence gate. The default is restrictive, so an agent installed
tomorrow is read-only until a human adds it to the roster.


## Design in one diagram

```
your request
     │
     ▼
┌──────────────────────────────────────────────────────┐
│ agent: routing table → which server for which task   │
│        evidence gate → no unverified assertions      │
│        safety gate   → namespace, pre-flight, ask    │
└───────────────┬──────────────────────────────────────┘
                │  read-only only, allowlisted in roster.json
      ┌─────────┴─────────┬─────────────────┐
      ▼                   ▼                 ▼
 reverse-engineering  se38-testing   dump-analysis
      │                   │                 │
      └─────────┬─────────┴─────────────────┘
                ▼
        lesson inbox (evidence, no action)
                │
                ▼  human gate: which agent, which file
        user memory · agent rule · new skill
```

## Install

**1. Agents.** Copy `agents/*.agent.md` into `~/.copilot/agents/` (`%USERPROFILE%\.copilot\agents`
on Windows). Reload the window, then pick one from the agent dropdown.

**2. Skills.** Copy `skills/mcp-surface-audit` into `~/.copilot/skills/`. Skills only load in a
new chat session, so start a fresh chat after copying.

**3. Roster.** Copy `roster.json` to `~/.copilot/roster.json`. Edit the file names to match the
agents you actually installed. An agent not listed there is not delegatable — that is the point
of an allowlist.

**4. MCP servers.** Copy `config-templates/mcp.json.template` to
`%APPDATA%\Code\User\mcp.json` and replace every `{{PLACEHOLDER}}`. The template is JSONC;
strip the comments if your editor refuses them.

**5. Settings.** Merge the keys in `config-templates/settings.json.template` into your
`settings.json`. Do not paste over your existing file.

**6. Profile (optional).** Copy `memory-templates/user-profile.md` to your Copilot memory folder
and fill it in. Keep it under about 40 lines: user memory is loaded into every session.

**7. Hooks (optional).** Copy the three `hooks/*.cjs` scripts into `~/.copilot/hooks/`, then copy
each `hooks/*.json.template` to the same folder with the `.template` suffix removed and replace
`{{COPILOT_HOME}}` with your Copilot folder path. All three are listed above; drop any you do
not want. Verify the scripts parse before relying on them:

```powershell
Get-ChildItem "$env:USERPROFILE\.copilot\hooks\*.cjs" | ForEach-Object { node --check $_.FullName; "$($_.Name): $LASTEXITCODE" }
```

Hooks are a preview feature. Test one at a time and confirm it fires before adding the next;
the Output channel for the Copilot extension reports hook errors.

## What is deliberately not here

| Excluded | Why |
| --- | --- |
| Installed agents and skills | owned by their packages; reinstall rather than copy |
| `mcp.json` with real values | contains hostnames, users, and CA paths |
| `settings.json` | contains an ADT token |
| `.skill-lock.json` | absolute paths and hashes from one machine |
| Memory contents | may contain system identifiers and business data |

## Adapting it

The parts worth keeping even if you replace everything else:

- **An allowlist, not a denylist.** An agent installed tomorrow is not delegatable by default,
  without anyone needing to notice it appeared.
- **Ownership by hash.** Compare against the installer's manifest instead of trusting a file
  name.
- **Capture separated from action.** Recording a failure writes one line and never edits a rule.
- **One home per rule.** A duplicated table is a future defect, not redundancy.

## License

MIT. The agent and skill files are yours to adapt. Third-party names (SAP, ABAP, RAP, ARC-1)
belong to their owners; this repository is not affiliated with or endorsed by SAP SE.
