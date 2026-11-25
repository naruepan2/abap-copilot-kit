# Setup — New Machine (ABAP + Copilot)

> Give this file to the AI on a fresh machine. Instruction to AI: follow top to
> bottom, verify each step with a tool result from this session, stop for human
> approval before any write to SAP, any transport, or any irreversible delete.
> Windows only (PowerShell 5.1, `%USERPROFILE%`, Windows Credential Manager).

## 0. What "done" looks like

- `~/.agents/skills` = `ponytail`, `ponytail-review`, `caveman` + the ABAP hand-installed set (§6),
  and none of the nine in §7's delete list (5 caveman + 1 toolkit + 3 mattpocock).
- `~/.copilot/skills` holds the toolkit skills still live plus every kit skill from §3.
  The 11 toolkit skills in §7 sit in `~/.copilot/skills-disabled/` after that step. Counts rot on
  every install, so list folders instead of trusting a number here.
- `~/.copilot/{agents,state,hooks}`, plus `~/.copilot/roster.json` and `~/.copilot/hooks/hooks.json`,
  from the kit (§3).
- `verify-all.ps1` clean (terse, exit 0).
- Daily set is 6 skills; everything else is on-demand (see §7).

## 1. Prerequisites

| Need | Source / check |
|---|---|
| VS Code + GitHub Copilot Chat | VS Code Marketplace |
| Node.js ≥ 22.13 (caveman CLI requirement) | `node --version` |
| PowerShell 5.1 (built into Windows) | `$PSVersionTable.PSVersion` |
| Execution policy relaxed for this session | `Get-ExecutionPolicy`. A default Windows client is `Restricted`, which blocks both `.\script.ps1` **and** `powershell -File script.ps1`. Every script below is therefore invoked as `powershell -ExecutionPolicy Bypass -File <path>`, which needs no permanent policy change |
| Git | `git --version` |
| `skills` CLI (via npx, no install) | `npx skills --help` |
| SAP GUI / ADT access + user + password | from the customer basis team, never in a file |

## 2. Clone the kit

```powershell
git clone <kit-remote> <clone-path>          # any local drive or folder
$env:ABAP_KIT_ROOT = '<clone-path>'          # or let install-kit.ps1 write the pin
```

The kit has no package version and no lockfile. Releases are **annotated git tags**
(`git tag` lists them), so `git pull` is the update and `git checkout v0.9.4.3` is the way back
to a known-good state when a pull regresses something.

## 3. Install kit files (agents, tooling, skills, hooks)

```powershell
Set-Location <clone-path>
powershell -ExecutionPolicy Bypass -File .\tooling\install-kit.ps1 -Check   # dry run first
powershell -ExecutionPolicy Bypass -File .\tooling\install-kit.ps1          # real copy
```

What it does: copies `agents/*.agent.md` → `~/.copilot/agents`,
`tooling/*.{ps1,js,json}` → `~/.copilot/state`,
`skills/*/SKILL.md` → `~/.copilot/skills`,
`hooks/*.cjs` → `~/.copilot/hooks`. Never overwrites a newer live file
unless `-Force`. Third-party skills are **not** copied from here.

### 3b. The two files the installer deliberately leaves to you

It prints them on every run. Neither is optional:

```powershell
$cp = "$env:USERPROFILE\.copilot"
Copy-Item .\roster.json $cp -Force
```

- **`roster.json`** is the delegation allowlist. Without it `verify-all.ps1` reports
  `ISSUE roster not found` and exits 1, and no subagent can be classified at all.
- **`hooks/hooks.json`** is what registers the three hooks. The `.cjs` files sitting in
  `~/.copilot/hooks` do nothing on their own: without this file no event is subscribed, so the
  session-start drift check never runs and the subagent roster gate is **silently inert**.

```powershell
Copy-Item .\hooks\hooks.json.template "$cp\hooks\hooks.json" -Force
# then replace every {{COPILOT_HOME}} in that file with the real path, e.g.
(Get-Content "$cp\hooks\hooks.json" -Raw).Replace('{{COPILOT_HOME}}', $cp) |
    Set-Content "$cp\hooks\hooks.json" -Encoding UTF8
```

Every hook command is `node "<path>/hooks/<file>.cjs"`, so `node` must be on `PATH` before the
next session start.

Kit skills installed this way (14): `capture-lesson`, `clean-core-decision-gates`,
`kit-backup`, `long-task-control`, `mcp-surface-audit`, `rap-lifecycle`, `sap-data-verify`,
`sap-evidence-audit`, `sap-mcp-upgrade`, `sap-new-program`, `sap-new-project`,
`sap-new-record`, `sap-program-unregister`, `sap-project-unregister`.
Kit agents (4, `*-by-pongg`, user-editable): `abap-developer`,
`sap-abap-reverse-engineer`, `sap-se38-report-tester`, `sap-st22-dump-analysis`.

## 4. Install npm globals

```powershell
npm i -g arc-1 sap-ai-dev-toolkit
```

Observed 2026-11-16: `arc-1@1.10.1`, `sap-ai-dev-toolkit@0.9.9928`.
Toolkit skills refresh **only** by reinstalling this package —
`npx skills update` never touches them.

## 5. Install third-party skills (ponytail + caveman)

```powershell
npx skills add DietrichGebert/ponytail --global
npx skills add JuliusBrussee/caveman --global
```

- Sources: https://github.com/DietrichGebert/ponytail (observed v5.3.3),
  https://github.com/JuliusBrussee/caveman (upstream v4.2.0, 2026-11-22; installed skill unchanged).
- Install **skills only**. Do NOT install their CLI/proxy/Auto/Blocks/browse
  stack: the caveman CLI sends telemetry by default and Auto sends prompts to
  Caveman Cloud — unacceptable for SAP code.
- `ponytail` = always-on lazy-senior-dev ruleset (smallest complete diff,
  reuse first, test + `shortcut:` comment). `ponytail-review` = review
  Must/Should/Nice with a concrete case per finding.
- `caveman` has `disable-model-invocation: true` — it never auto-triggers.
  Call `/caveman` for a short answer, `stop caveman` right after. Never leave
  it on: it compresses the Pre-Flight and risk report that ABAP skills require.
- Updates: `npx skills update -g -y` refreshes only lock-tracked + installed
  skills (`~/.agents/.skill-lock.json`). Edits to a lock-tracked skill are
  overwritten — copy to a new folder name to customise.

## 6. The ABAP skill set: 7 to copy, 12 to install

Measured 2026-11-16 against `~/.agents/.skill-lock.json`, which is what `npx skills update` reads.
Getting this split wrong is what silently breaks the update path for 12 skills.

**No upstream at all — copy from the previous machine's backup (7):**

`senior-abap-development`, `sap-abap`, `sap-abap-cds`, `sapui5`,
`sap-abap-reverse-engineering`, `sap-se38-report-tester`,
`sap-st22-dump-analysis`

**Lock-tracked to `arc-mcp/arc-1` — install, do not copy (12):**

```powershell
npx -y skills@latest add arc-mcp/arc-1 -g -y -s "*"
```

`explain-abap-code`, `generate-rap-logic`, `generate-abap-unit-test`,
`generate-cds-unit-test`, `debug-slow-sql`, `generate-rap-service`,
`generate-rap-service-researched`, `migrate-segw-to-rap`,
`convert-ui5-to-fiori-elements`, `modernize-ui5-app`,
`generate-analytics-star-schema`, `generate-cds-analytical-query`

A hand-copied skill is invisible to `npx skills update`, so copying these
permanently freezes them at the version in the backup. Full inventory and the
rest of the group-3 set: `docs/reference/skills.md`.

## 7. Keep / park / delete policy

**Daily (keep loaded, 6):** `senior-abap-development`, `sap-abap`,
`sap-abap-cds`, `ponytail` (full), `ponytail-review`, `caveman` (manual only).

**On-demand (keep installed, call by name):** `explain-abap-code`,
`generate-rap-logic`, `generate-abap-unit-test`, `generate-cds-unit-test`,
`sap-st22-dump-analysis`, `sap-se38-report-tester`, `debug-slow-sql`.

**Delete after every reinstall (they come back with upstream):**

```powershell
# 5 from JuliusBrussee/caveman (§5 installs it)
Remove-Item -Recurse -Force `
  $env:USERPROFILE\.agents\skills\lean-build, `
  $env:USERPROFILE\.agents\skills\surgical-patch, `
  $env:USERPROFILE\.agents\skills\safe-refactor, `
  $env:USERPROFILE\.agents\skills\migration, `
  $env:USERPROFILE\.agents\skills\verify-and-stop
# 1 from the toolkit
Remove-Item -Recurse -Force $env:USERPROFILE\.copilot\skills\advanced-event-mesh-lifecycle
# 3 from mattpocock/skills - NOT installed by this guide, so only present on a machine that
# installed that source. -ErrorAction SilentlyContinue keeps the list runnable on a clean one.
Remove-Item -Recurse -Force `
  $env:USERPROFILE\.agents\skills\tdd, `
  $env:USERPROFILE\.agents\skills\diagnosing-bugs, `
  $env:USERPROFILE\.agents\skills\code-review -ErrorAction SilentlyContinue
```

Why: the 8 duplicate `ponytail` (smallest-diff + test rules already cover
them); `code-review` runs parallel subagents and fights the ABAP flow;
`advanced-event-mesh-lifecycle` is not ABAP. Deletion needs a fresh chat to
take full effect (skills load at session start).

`tooling/removed-on-purpose.json` is the machine-readable copy of this decision. `verify-all.ps1`
reads it: a listed file that is absent is `removed on purpose` rather than `MISSING`, and a listed
skill that reappears is an `ISSUE` naming the reason it was deleted. That is what lets §10's
"must exit 0" and this section's deletes both be true.

**Parked, not deleted** (`~/.copilot/skills-disabled/`, ~750 tokens/request
saved 2026-11-14). A toolkit reinstall puts all 24 back, so move these out again before §10:

```powershell
$src = "$env:USERPROFILE\.copilot\skills"
$dst = "$env:USERPROFILE\.copilot\skills-disabled"
New-Item -ItemType Directory -Force -Path $dst | Out-Null
foreach ($n in 'btp-platform-administration','bw-datasphere-migration','cloud-alm-operations',
               'datasphere-administration','datasphere-development','hana-cloud-inspection',
               'hana-cloud-native-development','hana-cloud-validation',
               'integration-suite-delivery','process-automation-development',
               'sap-integration-architect') {
    if (Test-Path (Join-Path $src $n)) { Move-Item (Join-Path $src $n) $dst -Force }
}
```

To use one, move the folder back and start a new chat. Parked is different from deleted on
purpose: a parked skill is a toolkit file whose hash still has to match, so section 5b of the audit
reports it as `parked on purpose` rather than `MISSING`.

## 8. VS Code extensions

Install at minimum (IDs from a working machine, 2026-11-16):

```
murbani.vscode-abap-remote-fs   # ADT virtual FS (adt://)
sapse.adt-vscode                # ADT backend
larshp.vscode-abaplint          # abaplint
saposs.abap-cleaner             # Clean ABAP
sapse.vscode-cds                # CDS language support
sapse.sap-ux-fiori-tools-extension-pack  # Fiori/RAP tooling (optional)
```

## 9. Connections + TLS (per machine, never committed)

1. Copy skeletons from `config-templates/` (`mcp.json.template`, `settings.json.template`,
   `mcp-config.template.json`, `arc1.env.template`, `arc1-connections.template.json`) — fill secrets
   only via the scripts below, never paste into a file. The VS Code template also declares the
   public read-only `sap-abap-docs` server; do not copy that key into the CLI config, or VS Code will
   silently disable one copy.
2. Copy `templates/routing.local.md.template` to `Projects/_routing.local.md` and fill in which
   server reaches which system and which client is authorized. The agent reads this file before
   its first SAP call; without it the agent must ask. The file stays local because it names a
   system, a client and possibly a customer.
3. `powershell -ExecutionPolicy Bypass -File .\tooling\sap-connection.ps1` — add/list logons (like
   Connection Manager).
4. `powershell -ExecutionPolicy Bypass -File .\tooling\sap-secret.ps1` — stores each password in
   Windows Credential Manager (DPAPI, per user).
5. `node .\tooling\sap-auth-probe.js` — verdict OK / STALE / UNKNOWN. It must be run through `node`:
   `.js` is in `PATHEXT` on Windows, so a bare `.\sap-auth-probe.js` hands the file to `WScript.exe`,
   which has no `require` and shows a script-error dialog instead of a verdict. It reads
   `ARC1_PROBE_URL`, `ARC1_PROBE_USER` and `ARC1_PROBE_PASS` and exits 2 with `UNKNOWN` when one is
   missing.
6. Self-signed SAP cert breaks **every** call: use a CA bundle, never
   `SAP_INSECURE=true` (it accepts any certificate and masks a MITM):

```jsonc
"SAP_INSECURE": "false",
"NODE_EXTRA_CA_CERTS": "C:\\Users\\<you>\\Documents\\SAP\\Cert\\<ca-bundle>.crt"
```

## 10. Verify

```powershell
powershell -ExecutionPolicy Bypass -File .\tooling\verify-all.ps1   # terse audit, must exit 0
```

Three results that are setup tasks rather than failures, each with the section that fixes it:

| Line in the audit | Do this |
| --- | --- |
| `ISSUE roster not found` | §3b |
| `ISSUE declared deleted but reinstalled: <name>` | §7's delete list |
| `ISSUE parked but live again: <name>` | §7's park block |

Then open a **new chat** (skills and hooks load at session start) and confirm the session-start hook
reports no drift. That row is only meaningful if §3b wrote `hooks/hooks.json` — without it no hook
runs, and silence is indistinguishable from "nothing changed".

## Sources

| Item | Upstream | Local path after install |
|---|---|---|
| ponytail skills | https://github.com/DietrichGebert/ponytail | `~/.agents/skills/ponytail`, `ponytail-review` (+ audit/debt/gain/help) |
| caveman skills | https://github.com/JuliusBrussee/caveman | `~/.agents/skills/caveman` (+ ultracave/megacave) |
| ARC-1 runtime | `npm i -g arc-1` (arc-mcp/arc-1) | MCP server `arc-1` |
| SAP AI Dev Toolkit | `npm i -g sap-ai-dev-toolkit` | MCP servers + `~/.copilot/skills/*` (toolkit set) |
| Kit (agents/tooling/skills/hooks/templates) | public repo `abap-copilot-kit` (`git pull` = update) | `<clone-path>` → `~/.copilot/{agents,state,skills,hooks}`; pin records the clone path |
| ABAP FS extension | https://marketplace.visualstudio.com (murbani.vscode-abap-remote-fs) | VS Code extension |
| Skill inventory detail | `docs/reference/skills.md`, `docs/reference/arc-1.md` in the kit | — |
