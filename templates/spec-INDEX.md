# Spec index — <PROGRAM>

**Read this file, not the spec.** It exists because a functional specification is large and mostly
not needed: a 400-line FS costs ~4,000 tokens to read, and a 1,700-line one costs ~22,000 — more
than the entire agent. This index is ~40 lines and answers "where is the part I need".

| | |
|---|---|
| current | `source/<FS_FILENAME>` |
| superseded | `source/<older FS, or "none">` |
| owner | <name> — **never edit anything under `source/`** |
| received | <YYYY-MM-DD> |
| integrity | lines=**<n>** bytes=**<n>** |
| status | `approved` / `draft` / `stale` |

## Read this much

| Task | Open | Lines | ~tok |
|---|---|---:|---:|
| What does it do | *Summary* below | 0 | 0 |
| <task that needs a section> | <section heading> | <start>–<end> | <n> |
| **Never read** | <cover page / TOC / appendices> | <start>–<end> | <n> |

Rule: start at *Summary*. Open one mapped slice only when the task touches it. Never read the
whole file.

Build each ~tok figure once, with:
`((Get-Content <spec>)[<start>-1..<end>-1] -join "`n").Length / 4`

## Summary (written by us, from the spec — ≤10 lines)

- **Purpose** — <one sentence>
- **Entry point** — <T-code, BAdI, enhancement, or report>
- **Flow** — <the options / branches, in order>
- **Data** — <tables, structures, forms it reads and writes>
- **Output** — <what the user receives>
- **Must not** — <what the spec forbids, or "nothing stated">

## Integrity

| Check | Expected | How |
|---|---|---|
| line count | <n> | `(Get-Content <spec>).Count` |
| byte count | <n> | `(Get-Item <spec>).Length` |

If either differs, this index is **stale**: the line ranges may point at the wrong text. Rebuild
the map before reading a slice — a stale range silently returns the wrong section, which is worse
than no range at all.

Contradictions and questions go in `notes.md`. Never edit the spec to fix them.
