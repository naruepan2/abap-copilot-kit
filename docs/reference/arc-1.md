# ARC-1 — operating reference

Read on demand. The rules that must apply in **every** session stay in user memory; this file
holds the detail you need only when updating or debugging ARC-1.

## Keeping it current — one command

```powershell
powershell -ExecutionPolicy Bypass -File ~\.agents\arc1-update.ps1 -CheckOnly  # report only
powershell -ExecutionPolicy Bypass -File ~\.agents\arc1-update.ps1            # update
```

Reports drift for all three layers, updates skills, and detects the VS Code file lock on the
plugin package instead of failing. `-InstallSchedule` registers a Windows task (Sundays 09:00).
ARC-1 ships every 1-3 days; **monthly** is plenty.

## Three separate layers — do not confuse them

| Layer | Where | Updated via | VS Code may be open? |
|---|---|---|---|
| **MCP runtime** | `npx -y arc-1@latest` (npm) | nothing — `@latest` self-resolves on next start | yes |
| **Plugin package** | `~/.copilot/installed-plugins/arc-1/arc-1` | `copilot plugin update arc-1@arc-1` | **NO — os error 32** |
| **Skills** | `~/.agents/skills/<name>/` | `npx -y skills@latest add arc-mcp/arc-1 -g -y -s "*"` | yes |

- Plugin version is tracked in `~/.copilot/config.json` (`installedPlugins[].version`).
- No git clone exists — it is a marketplace snapshot (`source_sha`), so `git pull` is not an
  option.

## Gotchas (verified)

- **`copilot plugin update` fails while VS Code is open** — "os error 32 … used by another
  process" on `~/.copilot/installed-plugins/arc-1/arc-1`. Close all VS Code windows first.
- **`npx skills update` only sees skills listed in `.skill-lock.json`.** Manually copied skills
  are invisible to it ("No installed skills found matching: …"). Use `skills add` — it
  overwrites.
- The skills CLI log is polluted by an unrelated broken skill at
  `~/AppData/Local/hermes/skills/email-automation/SKILL.md` (YAML parse error). Filter output.
- Upstream `arc1-cursor-regression` has a YAML frontmatter parse error → silently skipped.
- After a server restart the feature cache clears: the first `SAPManage(action="features")`
  returns "No features probed yet". Run `action="probe"` once.

## TLS: self-signed SAP cert → every call fails as "network error"

Symptom: every `SAPManage(action="features")` returns `available:false, "network error"`.

Diagnose, in this order:

1. `Resolve-DnsName <host>` → resolves
2. `Test-NetConnection <host> -Port <port>` → succeeds
3. `curl.exe -s .../sap/bc/adt/discovery` → `http_code=000` (TLS trust failure)
4. `curl.exe -sk ...` → `http_code=200` ← confirms TLS trust, not connectivity

**Fix — never set `SAP_INSECURE=true`.** It accepts any certificate and masks a MITM.

```jsonc
"SAP_INSECURE": "false",
"NODE_EXTRA_CA_CERTS": "C:\\Users\\<you>\\Documents\\SAP\\Cert\\sap-example-corp-ca-bundle.crt"
```

Restart after an env change. A working `abapfs` does **not** prove the ARC-1 host is fine —
they can point at different landscapes.

## PowerShell 5.1 constraints (this machine)

- No inline `if` expression: `(if($x){1}else{2})` is a parse error — assign to a variable first.
- No `??`. Here-strings with braces get mangled inline.
- `~/.copilot/config.json` starts with a `//` comment line, so `ConvertFrom-Json` needs it
  stripped first.
- Long multi-line command pastes get truncated by the integrated terminal — run one line at a
  time, and pre-assign values instead of chaining `.Count` on a pipeline.
