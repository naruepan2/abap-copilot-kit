# abap-copilot-kit

A reproducible VS Code Copilot setup for SAP/ABAP work. Three rules:

1. **One task, one MCP server.** Routing is per task, not a global priority list.
2. **Never guess.** Environmental claims need a tool result from this session.
3. **You decide.** The agent proposes; you approve every file edit.

Servers update and installers rewrite agents. This kit is built to stay correct when that happens.

**Windows only:** Windows Credential Manager, `%USERPROFILE%` paths, PowerShell 5.1. Agent,
skill and hook files are portable; the tooling is not.

**Contents:** [What is here](#what-is-here) · [Read first](#one-fact-worth-reading-before-anything-else) ·
[Hooks](#hooks) · [Design](#design-in-one-diagram) · [Install](#install) ·
[Not here](#what-is-deliberately-not-here) · [Contract backup](#where-a-programs-contract-is-backed-up) ·
[Releasing](#releasing) · [Adapting](#adapting-it) · [License](#license)

## What is here

```
AGENTS.md          workspace contract: connections, access rules, session start
INDEX.md           one-screen map of the repo and of where memory lives
agents/            custom agents: routing, safety, evidence gates
skills/            the kit's five hand-written skills
roster.json        delegation allowlist (read-only subagents)
hooks/             three detection-only hooks
docs/              architecture, tool routing, ownership, anti-hallucination
docs/reference/    lookup detail: ARC-1, skills, paths, hooks, output levels
config-templates/  mcp.json, settings.json, arc1.env and connections skeletons
memory-templates/  user profile template
templates/         project / program / spec templates
tooling/           verify-all, census, install-kit, connection + credential scripts,
                   auth probe, context measure, workspace-sync
backup/            recovery snapshot of user memory (nothing loads it)
Projects/          local notebook, gitignored, mirrored to a private repository
```

## One fact worth reading before anything else

**SAP connections are user-scoped, not workspace-scoped.** MCP servers live in
`%APPDATA%\Code\User\mcp.json`; ABAP FS and ADT endpoints live in user `settings.json`.
Opening a folder selects nothing — several systems may be reachable at once.

A folder named after a project is documentation, not isolation. Confirm the system and client
explicitly before every read or write. A workspace `.mcp.json` would pin them, but only by
duplicating the server config; this kit deliberately does not. `AGENTS.md` repeats the warning
for the agent.

## Hooks

Detection only: no hook edits an agent, skill or config. All three live in one file,
`~/.copilot/hooks/hooks.json` (Copilot CLI format: `version: 1`, camelCase events, one
`{"type":"command","command":"…"}` entry each). Separate per-event files do not load.

| Event | Script | Effect |
| --- | --- | --- |
| `sessionStart` | `session-drift.cjs` | reports changes in agents, skills, MCP servers and tool counts |
| `subagentStart` | `subagent-rules.cjs` | adds namespace/evidence rules; restricts agents not in `roster.json` |
| `postToolUseFailure` | `lesson-capture.cjs` | appends one evidence row per failed call |

A context-injecting hook must answer `{"hookSpecificOutput":{"hookEventName":"<event>",
"additionalContext":"…"}}`; top-level `additionalContext` is ignored.

> Hooks are a preview feature. Confirm one fires before relying on it — for `sessionStart`,
> a new `takenAt` in `~/.copilot/state/surface.json` is the proof.

The subagent hook matters because delegated agents run in their own context. A new agent is
read-only until a human adds it to the roster.


## Design in one diagram

Route → gate → capture → promote:

```mermaid
flowchart LR
    U(["Your request"]) --> A["ABAP Developer<br/>route · evidence · safety"]

    subgraph SESSION["In this session"]
        direction TB
        A --> W["Work: read, change, verify"]
        W --> L["Finding worth keeping<br/>still in context"]
    end

    subgraph DELEGATE["Optional: read-only subagents"]
        direction TB
        D1["reverse engineering"]
        D2["SE38 replay"]
        D3["ST22 dump"]
    end
    A -.->|"allowlisted only"| DELEGATE
    DELEGATE --> L

    L --> C["capture-lesson<br/>choose by half-life"] --> H{"HUMAN GATE<br/>exact diff + approval"}

    subgraph STORE["Durable homes"]
        direction TB
        M["User memory<br/>every request"]
        P["Repo memory<br/>on demand"]
        R["Agent / skill rule<br/>routing or safety"]
    end
    H -->|"approve"| STORE
    H -->|"decline"| X["Nothing — ephemeral"]

    classDef gate fill:#fff3cd,stroke:#b8860b,color:#000,stroke-width:2px
    classDef mem fill:#e8f4ff,stroke:#2f6fa8,color:#000
    classDef task fill:#eef7ee,stroke:#3a7d3a,color:#000
    class H gate
    class M,P,R mem
    class A,W task
```

Both memory layers stay **outside** this repository: user memory in the VS Code user data folder,
repo memory per workspace. A copy here would be a second copy nothing loads.

Capture is a **skill**, not a hook: `postToolUseFailure` has never produced a ledger in this
harness, so the loop runs while the finding is still in context.

## Install

Two scripts do the mechanical work; the remaining steps need a real value or a decision.

### Install and check

```powershell
powershell -File tooling\install-kit.ps1 -Check     # preview
powershell -File tooling\install-kit.ps1           # copy what is missing
powershell -File tooling\verify-all.ps1            # is anything wrong?
powershell -File tooling\census.ps1                # what exists, and what no gate reads?
```

`install-kit.ps1` copies agents, tooling and this kit's five skills. It is idempotent and refuses
to overwrite a differing live file — `-Force` only after you decide the clone is newer. The kit
root comes from `$env:ABAP_KIT_ROOT`, then a `kit-root.txt` pin, then the parent of `tooling\`.

Both checks are read-only and exit non-zero on a problem. `verify-all` prints `SKIP` with a reason
when it cannot evaluate a check; `census` inventories every artifact and flags files no row
accounts for. The census matters: earlier rounds reported clean while six backup files outside
the repository held internal hostnames, because no `git ls-files` check could reach them. Add
`-Detail full` to either script for per-file output.

### Steps

**1–3. Agents, skills, roster.** Copy `agents/*.agent.md` → `~/.copilot/agents/`,
`skills/*/` → `~/.copilot/skills/`, `roster.json` → `~/.copilot/roster.json`. Start a new chat
so skills load. An agent absent from the roster is not delegatable. `install-kit.ps1` can do
all three (it enumerates folders, so a new skill needs no edit here).

**4. MCP servers.** Copy `config-templates/mcp.json.template` → `%APPDATA%\Code\User\mcp.json`
and replace each `{{PLACEHOLDER}}`. The template is JSONC; strip comments if your editor objects.

**5. Credentials — one password, both clients.** Do not put a password in the config: the Copilot
CLI has no Quick Input and its folder is readable by another group. Name a connection instead:

```powershell
tooling\sap-connection.ps1 -Add -Name dev-110 -Url https://host:44381 -Client 110 -User <sap user>
powershell -ExecutionPolicy Bypass -File tooling\sap-secret.ps1 -Set -Key dev-110_SAP_PASSWORD
```

`-Set` stores the value in Windows Credential Manager. Point both harnesses at the launcher in
`config-templates/mcp-config.template.json` (key `mcpServers` for the CLI, `servers` for VS Code);
the password never appears in either config. Keep policy variables (`SAP_ALLOW_WRITES`,
`SAP_ALLOWED_PACKAGES`, …) in `env` and do not duplicate `SAP_URL`/`SAP_USER` — audit checks both
files for that drift.

Always name the interpreter by **absolute path** in spawned processes: a bare `powershell` fails
with `ENOENT` under a trimmed `PATH`, and the only symptom is that the server's tools never appear.
Scripts use `$PSHOME` for the same reason. Typing `powershell` in your own terminal is fine.

At start, `sap-auth-probe.js` (run through `node`) checks the stored password: `OK` starts;
`STALE` opens the native Windows credential dialog and probes again; `UNKNOWN` (network/TLS fault)
reports once and starts anyway — a network fault is not a bad password. The dialog is bounded by
`-PromptTimeoutSec` (default 180).

**6–7. Settings and profile (optional).** Merge `config-templates/settings.json.template` into
your `settings.json` (never paste over it). Optionally copy `memory-templates/user-profile.md` to
your Copilot memory folder — keep it short; user memory loads every request.

**8. Workspace contract (optional).** Opening this repo as a workspace loads `AGENTS.md` into
every request. Drop it if you use the repo only as a source of files to copy.

**9. Hooks (optional).** Copy `hooks/*.cjs` to `~/.copilot/hooks/`, then
`hooks/hooks.json.template` to `hooks.json`, replacing `{{COPILOT_HOME}}`. Check syntax with
`node --check <file>` and test one event at a time before enabling the next.

### Skills without cloning

With collaborator access, the CLI installs just the skills:

```powershell
npx skills add naruepan2/abap-copilot-kit -s capture-lesson -g
```

Agents, tooling and templates still come from the clone.

## What is deliberately not here

| Excluded | Why |
| --- | --- |
| Installed agents and skills | owned by their packages; reinstall rather than copy |
| `mcp.json` with real values | contains hostnames, users, and CA paths |
| `settings.json` | contains an ADT token |
| `.skill-lock.json` | absolute paths and hashes from one machine |
| Memory contents | may contain system identifiers and business data |
| `Projects/<PROJECT>/…` | customer SID, client and transport numbers |
| `Projects/_routing.local.md` | which server reaches which system, and which client is authorized |
| Live `hooks/*.json` | machine-specific absolute paths |

**No tracked file names a customer, host or user.** The routing table in the agent says what each
server *may do* and points to gitignored `Projects/_routing.local.md` for the machine-specific
mapping; the agent reads it before its first SAP call. Audit section 9 derives sensitive patterns
from the gitignored connection store at run time and scans history as well as the working tree —
because a working-tree-only scan missed such a leak for sixteen commits. One-off values go in
`tooling/verify-patterns.local.txt` (gitignored, one per line).

Rule of thumb: **anything identifying a customer, system, person or session belongs in a gitignored
file; the tracked file only says where to find it.**

A fresh clone gives you the files above plus `AGENTS.md`, `INDEX.md`, `templates/` and
`Projects/README.md` — not a working SAP connection, memory, or project records. Run `git ls-files`
for the exact list; counts in prose go stale.

## Where a program's contract is backed up

`Projects\<PROJECT>\<PROGRAM>` is gitignored because it carries customer identifiers — and that
means the contract has no history and no off-machine copy. `tooling/workspace-sync.ps1` mirrors it
into a second private repository, by **allowlist**:

| Mirrored | Never mirrored |
| --- | --- |
| `README.md`, `project.yaml`, `program.yaml`, `changes.md` | `spec\source\**` — the functional's document |
| `spec\INDEX.md`, `spec\notes.md`, `spec\spec.md`, `spec\CHANGELOG.md` | `.baseline\**` — captured customer source |
| `manifest.json` (sha256, bytes, lines) | any file the script does not name |

An allowlist means a new file type is not mirrored until a human names it — nothing leaks
by default. The spec is excluded but its integrity is watched: `program.yaml` stores `spec_lines`
and `spec_bytes`, and `-Check` flags a mismatch when a new document arrives.

```powershell
tooling\workspace-sync.ps1 -Workspace <clone>            # preview
tooling\workspace-sync.ps1 -Workspace <clone> -Check     # drift, exit 1 if any
tooling\workspace-sync.ps1 -Workspace <clone> -Write     # copy and refresh manifest
```

Add `-RepoMemory <path>` to mirror per-workspace memory **recursively** — it is a backup, not a
move; VS Code keeps reading the live folder. Passwords and tokens are refused; customer names are
expected. Hashing folds CRLF→LF and drops BOM, and the mirror pins `eol=lf`, so an editor's line
endings do not show up as false drift.

## Releasing

No `CHANGELOG.md` on purpose: `git log` is the one home for what changed. An annotated tag carries
the release notes, written from the commits since the last tag:

```powershell
git log --oneline v0.9.4.9..HEAD    # changes since the last tag
git tag -a v0.10.0 -F notes.txt
git push origin v0.10.0
```

The tag message is **not** the GitHub release body — paste the notes into the release form too.
`~/.copilot/backups/release-notes-<tag>.md` is the copy of record; the tag is the immutable pointer.
Historically several tags carried only a one-line subject, so audit section 9d compares each tag
with its notes file and reports the mismatch. Never rewrite a released tag — fix forward instead.

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
