# Classic ABAP report template — YSMILE SALV

## Single source of truth

Repository asset: `reference-assets/salv/` (relative to the kit root). Resolve the kit root
from `$env:ABAP_KIT_ROOT` or the pin in `~/.copilot/state/kit-root.txt`; never hardcode a drive.

`MANIFEST.sha256` in that folder lists all 15 `.abap` files with their SHA-256 hashes.
The manifest is part of the integrity check; never edit it by hand.

Do not create another copy under a skill folder. The installed
`~/.copilot/skills/sap-new-program/SKILL.md` still prints the old relative path
`skills/sap-new-program/references/salv/`. A reinstall overwrites edits to installed skills,
so this repository document is the resolution rule that wins at run time. Do not edit the
installed skill to fix the path.

## Resolve before any PROG write

1. Locate the kit root. Confirm `reference-assets/salv/MANIFEST.sha256` exists.
2. Verify all 15 files against the manifest (hash and relative path). On Windows PowerShell:

```powershell
$kit = if ($env:ABAP_KIT_ROOT) { $env:ABAP_KIT_ROOT } else { (Get-Content "$env:USERPROFILE\.copilot\state\kit-root.txt" -Raw).Trim() }
$asset = Join-Path $kit 'reference-assets\salv'
Get-Content "$asset\MANIFEST.sha256" | ForEach-Object {
  if ($_ -match '^([0-9a-f]{64})  (.+)$') {
    $file = Join-Path $asset $Matches[2]
    if (-not (Test-Path $file)) { "MISSING $($Matches[2])" }
    elseif ((Get-FileHash $file -Algorithm SHA256).Hash.ToLowerInvariant() -ne $Matches[1]) {
      "HASH-DRIFT $($Matches[2])"
    }
  }
}
```

No output means the snapshot is intact.

3. Copy the chosen variant's five `.abap` files byte-for-byte into the delivery run folder
   (`artifacts/template-snapshot/<variant>/`) as evidence before writing code.
4. Read all five files of that variant. They are authoritative; prose summaries and exercise
   Markdown files are not.
5. If any path, file or hash is missing: stop at `BLOCKED_TOOLING`. Do not guess class names,
   include boundaries or event flow from a summary, and do not silently use an installed skill's
   stale relative path.

## Variant rules

| Variant | Folder | Use |
| --- | --- | --- |
| base | `reference-assets/salv/` | read-only classic SALV report (exercise 009) |
| edit1 | `reference-assets/salv/variants/edit1/` | whole-column editing pattern |
| edit2 | `reference-assets/salv/variants/edit2/` | per-cell editing pattern |

Each variant is a set of five files: main, `_TOPZ`, `_S01`, `_C01`, `_C02`.
Keep all five from one variant. Never mix fragments across variants.

For exercise 010, choose edit1 or edit2 only after the live capability decision E1/E2 recorded
in that exercise's spec. Capability evidence comes from the target system, not from the template.

## What must survive into the generated report

- Four `INCLUDE` statements in template order: `_TOPZ`, `_S01`, `_C01`, `_C02`.
- Event flow: `INITIALIZATION` → `AT SELECTION-SCREEN OUTPUT` → `AT SELECTION-SCREEN`
  → `START-OF-SELECTION` → `END-OF-SELECTION`.
- Class responsibilities and names: `lcx_excpt`, `lcl_main`, `lcl_salv_events`, `lcl_salv`,
  with `go_main` / `go_view` and `get_result_data` returning `REF TO data`.
- Extension hooks and method set from the chosen variant.

Requirement-driven deviations are allowed only when recorded in the run decision log
(example exercise 009: `I_COMPANYCODE` instead of `T001`, authority check, row bound).

## Scope and ownership

This asset is ABAP source pattern only. It contains no system, client, host, user or credential.
Historical run evidence that names the old `skills/sap-new-program/references/salv/` path is
immutable; it records where the template came from at that time and is not rewritten.
