# Setup — New Machine (ABAP + Copilot)

> Give this file to the AI on a fresh machine. Instruction to AI: follow top to
> bottom, verify each step with a tool result from this session, stop for human
> approval before any write to SAP, any transport, or any irreversible delete.
> Windows only (PowerShell 5.1, `%USERPROFILE%`, Windows Credential Manager).

## 0. What "done" looks like

- `~/.agents/skills` = kit skills + `ponytail`, `ponytail-review`, `caveman` (+ ABAP hand-installed).
- `~/.copilot/skills` = 18 toolkit/hand skills (no `advanced-event-mesh-lifecycle`).
- `~/.copilot/agents`, `~/.copilot/state`, `~/.copilot/hooks` from the kit.
- `verify-all.ps1` clean (terse, exit 0).
- Daily set is 6 skills; everything else is on-demand (see §7).

## 1. Prerequisites

| Need | Source / check |
|---|---|
| VS Code + GitHub Copilot Chat | VS Code Marketplace |
| Node.js ≥ 22.13 (caveman CLI requirement) | `node --version` |
| PowerShell 5.1 (built into Windows) | `$PSVersionTable.PSVersion` |
| Git | `git --version` |
| `skills` CLI (via npx, no install) | `npx skills --help` |
| SAP GUI / ADT access + user + password | from the customer basis team, never in a file |

## 2. Clone the kit

```powershell
git clone <private-kit-remote> D:\abap-copilot-kit
$env:ABAP_KIT_ROOT = 'D:\abap-copilot-kit'
```

The kit has no version — `git pull` inside the clone **is** the update.

## 3. Install kit files (agents, tooling, skills, hooks)

```powershell
Set-Location D:\abap-copilot-kit
.\tooling\install-kit.ps1 -Check    # dry run first
.\tooling\install-kit.ps1           # real copy
```

What it does: copies `agents/*.agent.md` → `~/.copilot/agents`,
`tooling/*.{ps1,js,json}` → `~/.copilot/state`,
`skills/*/SKILL.md` → `~/.copilot/skills`,
`hooks/*.cjs` → `~/.copilot/hooks`. Never overwrites a newer live file
unless `-Force`. Third-party skills are **not** copied from here.

Kit skills installed this way (5): `capture-lesson`, `long-task-control`,
`mcp-surface-audit`, `new-program`, `rap-lifecycle`.
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
  https://github.com/JuliusBrussee/caveman (observed v4.1.0).
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

## 6. Hand-installed ABAP skills (no upstream — copy from backup)

These have no `npx` source; restore from the previous machine's backup:

`senior-abap-development`, `sap-abap`, `sap-abap-cds`, `sapui5`,
`sap-abap-reverse-engineering`, `sap-se38-report-tester`,
`sap-st22-dump-analysis`, `explain-abap-code`, `generate-rap-logic`,
`generate-abap-unit-test`, `generate-cds-unit-test`, `debug-slow-sql`,
`generate-rap-service`, `generate-rap-service-researched`,
`migrate-segw-to-rap`, `convert-ui5-to-fiori-elements`, `modernize-ui5-app`,
`generate-analytics-star-schema`, `generate-cds-analytical-query`,
plus group-3 project/audit skills (see §7).

## 7. Keep / park / delete policy

**Daily (keep loaded, 6):** `senior-abap-development`, `sap-abap`,
`sap-abap-cds`, `ponytail` (full), `ponytail-review`, `caveman` (manual only).

**On-demand (keep installed, call by name):** `explain-abap-code`,
`generate-rap-logic`, `generate-abap-unit-test`, `generate-cds-unit-test`,
`sap-st22-dump-analysis`, `sap-se38-report-tester`, `debug-slow-sql`.

**Delete after every reinstall (they come back with upstream):**

```powershell
Remove-Item -Recurse -Force `
  $env:USERPROFILE\.agents\skills\lean-build, `
  $env:USERPROFILE\.agents\skills\surgical-patch, `
  $env:USERPROFILE\.agents\skills\safe-refactor, `
  $env:USERPROFILE\.agents\skills\migration, `
  $env:USERPROFILE\.agents\skills\verify-and-stop, `
  $env:USERPROFILE\.agents\skills\tdd, `
  $env:USERPROFILE\.agents\skills\diagnosing-bugs, `
  $env:USERPROFILE\.agents\skills\code-review
Remove-Item -Recurse -Force $env:USERPROFILE\.copilot\skills\advanced-event-mesh-lifecycle
```

Why: all 8 duplicate `ponytail` (smallest-diff + test rules already cover
them); `code-review` runs parallel subagents and fights the ABAP flow;
`advanced-event-mesh-lifecycle` is not ABAP. Deletion needs a fresh chat to
take full effect (skills load at session start).

**Parked, not deleted** (`~/.copilot/skills-disabled/`, ~750 tokens/request
saved 2026-11-14): `btp-platform-administration`, `bw-datasphere-migration`,
`cloud-alm-operations`, `datasphere-administration`, `datasphere-development`,
`hana-cloud-inspection`, `hana-cloud-native-development`,
`hana-cloud-validation`, `integration-suite-delivery`,
`process-automation-development`, `sap-integration-architect`. To use one,
move the folder back and start a new chat.

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

1. Copy skeletons from `config-templates/` (`mcp.json`, `settings.json`,
   `arc1.env.template`, `arc1-connections.template.json`) — fill secrets only
   via the scripts below, never paste into a file.
2. `.\tooling\sap-connection.ps1` — add/list logons (like Connection Manager).
3. `.\tooling\sap-secret.ps1` — stores each password in DPAPI.
4. `.\tooling\sap-auth-probe.js` — verdict OK / STALE / UNKNOWN.
5. Self-signed SAP cert breaks **every** call: use a CA bundle, never
   `SAP_INSECURE=true` (it accepts any certificate and masks a MITM):

```jsonc
"SAP_INSECURE": "false",
"NODE_EXTRA_CA_CERTS": "C:\\Users\\<you>\\Documents\\SAP\\Cert\\<ca-bundle>.crt"
```

## 10. Verify

```powershell
.\tooling\verify-all.ps1        # terse audit, must exit 0
```

Then open a **new chat** (skills/hooks load at session start) and confirm the
session-start hook reports no drift.

## Sources

| Item | Upstream | Local path after install |
|---|---|---|
| ponytail skills | https://github.com/DietrichGebert/ponytail | `~/.agents/skills/ponytail`, `ponytail-review` (+ audit/debt/gain/help) |
| caveman skills | https://github.com/JuliusBrussee/caveman | `~/.agents/skills/caveman` (+ ultracave/megacave) |
| ARC-1 runtime | `npm i -g arc-1` (arc-mcp/arc-1) | MCP server `arc-1` |
| SAP AI Dev Toolkit | `npm i -g sap-ai-dev-toolkit` | MCP servers + `~/.copilot/skills/*` (toolkit set) |
| Kit (agents/tooling/skills/hooks/templates) | private repo `abap-copilot-kit` (`git pull` = update) | `D:\abap-copilot-kit` → `~/.copilot/{agents,state,skills,hooks}` |
| ABAP FS extension | https://marketplace.visualstudio.com (murbani.vscode-abap-remote-fs) | VS Code extension |
| Skill inventory detail | `docs/reference/skills.md`, `docs/reference/arc-1.md` in the kit | — |
