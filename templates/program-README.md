# <PROGRAM>

One-line purpose.

## Status

- Version: <version>
- Deployment state: <in development | active | retired>
- Pending work: <short list or "none">
- Transport / scope constraints: <which request, which client, what must not change>

## Pointers

| What | Where |
|---|---|
| Deployed source | <SAP object name and type — the system is the owner of the source> |
| Builder | `program.yaml` / the object that generates it |
| **Pre-release change log** | `changes.md` — what was activated, in what order, while the TR is open |
| Long-run plan | `plan-<task>.md` when a task spans requests — stop condition and checkpoint |
| Decisions | `spec/notes.md` §Decisions — the one home for why |
| Memory card | <repo memory path, or "not created"> |

`changes.md` is the AI's index for rollback before TR release: it names the version and the exact
baseline path. `.baseline/` holds the byte-exact source. After release, SAP version management
takes over and the baselines are deleted — do not keep a second copy here.

## Test focus

- Key data: <selection values, client, date range>
- Expected checks: <what proves the program works>
- Known traps: <behaviour that looks like a bug but is intended>

<!--
Pointers, not copies: never paste ABAP source into this file. The SAP system owns the
source; a pasted copy goes stale without anyone noticing.

This file is a record, not a boundary. It does not pin the tools to this object's system.
-->
