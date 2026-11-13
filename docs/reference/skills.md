# Skills — inventory reference

Read on demand. The rules that must apply in **every** session stay in user memory; this file
holds the counts and family tables you need only when updating or auditing skills.

Counts drift whenever an installer runs. Regenerate them; never quote a number from here
without checking first.

```powershell
@("$env:USERPROFILE\.agents\skills","$env:USERPROFILE\.copilot\skills") | ForEach-Object {
  (Get-ChildItem $_ -Directory | Where-Object { Test-Path (Join-Path $_.FullName 'SKILL.md') }).Count
}
```

## Where each family lives

| Family | Location | Lock-tracked |
|---|---|---|
| arc-mcp/arc-1 | `~/.agents/skills` | yes |
| mattpocock/skills (`skills/engineering/*`, `skills/productivity/*`) | `~/.agents/skills` | yes |
| JuliusBrussee/caveman | `~/.agents/skills` | yes |
| DietrichGebert/ponytail | `~/.agents/skills` | yes |
| SAP AI Dev Toolkit | `~/.copilot/skills` | **no** |
| No upstream source (hand-installed) | `~/.agents/skills` | **no** |
| `mcp-surface-audit`, `capture-lesson`, `arc-1-add-sap-system` | `~/.copilot/skills` | **no** — hand-maintained |

## `~/.copilot/skills-disabled/` — parked on purpose

Every skill's `name` + `description` loads into **every** request, so a skill that is irrelevant
to the current work still costs tokens forever. On 2026-11-14 these eleven were moved to
`~/.copilot/skills-disabled/`, saving roughly 750 tokens per request:

`btp-platform-administration`, `bw-datasphere-migration`, `cloud-alm-operations`,
`datasphere-administration`, `datasphere-development`, `hana-cloud-inspection`,
`hana-cloud-native-development`, `hana-cloud-validation`, `integration-suite-delivery`,
`process-automation-development`, `sap-integration-architect`

To use one: move the folder back into `~/.copilot/skills/` and start a new chat. A toolkit
reinstall may recreate them in the live root — move them out again rather than deleting them, so
a future reader can see they were parked rather than lost. A copy of all eleven is at
`~/.copilot/docs/archive/skills-disable-2026-11-14/`.

The hand-installed skills with no upstream: `sap-abap`, `sap-abap-cds`, `sapui5`,
`senior-abap-development`, `sap-abap-reverse-engineering`, `sap-se38-report-tester`,
`sap-st22-dump-analysis`. Nothing updates them, so edits survive; keep a copy if an edit is
large.

Extension-provided skills are a fourth source and are not user-managed: ABAP Remote FS ships 13,
plus Pylance, TypeScript, and VS Code built-ins.

## Update coverage

Against `~/.agents/.skill-lock.json`:

- `npx skills update -g -y` refreshes **only** skills that are both lock-tracked and installed.
  Lock entries for uninstalled skills are stale — never assume a lock entry means present.
- Toolkit skills are refreshed only by **reinstalling** (`npm i -g sap-ai-dev-toolkit`); the
  `skills` CLI never touches them.
- Most of `~/.copilot/skills` is **not** lock-tracked, so `skills update` does nothing for it.
- Edits to a lock-tracked skill are overwritten on update. To customise, copy it to a new folder
  name instead of editing in place.

Recount the lock:

```powershell
(Get-Content ~/.agents/.skill-lock.json -Raw | ConvertFrom-Json).skills.PSObject.Properties.Count
```

Regenerate any name list rather than trusting a table:

```powershell
(Get-ChildItem ~/.agents/skills -Directory | Where-Object { Test-Path (Join-Path $_.FullName 'SKILL.md') }).Name
```

## `~/.claude/skills` is not a Copilot loader root

It looks like one and holds real skill files, but Copilot does not load it. A skill that exists
only there is unreachable until it is copied into `~/.agents/skills` or `~/.copilot/skills`.
Check for this whenever a skill "exists but never activates".
