# Local object index benchmark — preparation plan

Status: **plan only, not run.** No SAP write, lock, activate or transport change is part of this
benchmark. Implementation gate is `docs/reference/coedit-gap-closure.md` §5.11. This file is the
preparation form: task list, proposed gold set for human confirmation, scoring sheet, and rules.
Do not treat a proposed gold-set row as correct until the human ticks it.

## 0. Preconditions before the SAP phase

- destination and target system/client confirmed by the user, not inferred;
- read-only scope confirmed: `SAPContext(impact)`, `object_state`, `SAPRead(format="editable")`;
- the local index (§5.10) is built from tool-confirmed edges only;
- gold set confirmed below; **never derive the gold set from the index under test**.

If any precondition is missing: mark the affected tasks `SKIP`, not `FAIL`.

## 1. Task list — 24 tasks, six kinds, four each

Seed objects come from the RAP stack already probed in §5.9. Use the *shape* here; the human fills
exact object names from the local record. No object names or customer identifiers go in this file.

| id | kind | question pattern | seed role |
|---|---|---|---|
| T01–T04 | locate_sentinel | "which object carries <business phrase>?" | root / projection / behavior / exposure |
| T05–T08 | root_impact | downstream of one root interface view | root view |
| T09–T12 | projection_impact | downstream of one projection view | projection |
| T13–T16 | exposure | which entities does one service definition expose? | service definition |
| T17–T20 | access_control | which DCL guards this projection? | projection + DCL |
| T21–T24 | negative_relation | "does relation <X> exist?" where answer is no | any, chosen by human |

Each task must be run in both modes against the same target and scored with the same sheet:
`source-first` (no index) and `index-assisted` (start from §5.10, verify ranked candidates only).

## 2. Proposed gold set — HUMAN MUST CONFIRM

Fill from the local record before the first measurement. A blank cell is a pending question.

| task | expected object(s) | confirmed by human (Y/N) | note |
|---|---|---|---|
| T01 | <object> | | |
| T02 | <object> | | |
| T03 | <object> | | |
| T04 | <object> | | |
| T05 | <downstream objects from probe §5.9> | | |
| T06 | <object> | | |
| T07 | <object> | | |
| T08 | <object> | | |
| T09 | <service definition + DCL from probe §5.9> | | |
| T10 | <object> | | |
| T11 | <object> | | |
| T12 | <object> | | |
| T13 | <entities exposed by service definition> | | |
| T14 | <object> | | |
| T15 | <object> | | |
| T16 | <object> | | |
| T17 | <DCL guarding projection> | | |
| T18 | <object> | | |
| T19 | <object> | | |
| T20 | <object> | | |
| T21 | none | | |
| T22 | none | | |
| T23 | none | | |
| T24 | none | | |

Only rows with `Y` may be scored. If a row is wrong, correct the expected object list here first —
never silently patch the scoring to match an output.

## 3. Scoring sheet

One row per task per mode. Tokens use `measure-context.ps1` convention: 4 chars/token.

| task | mode | source chars | ~tokens | full source reads | tool calls | duplicate reads | recall | false candidates | impact miss (severity) | elapsed s | status |
|---|---|---:|---:|---:|---:|---:|---:|---:|---|---:|---|
| T01 | source-first | | | | | | | | | | |
| T01 | index-assisted | | | | | | | | | | |
| ... | | | | | | | | | | | |

`recall` = expected objects returned / expected objects. `impact miss` counts an expected
downstream object the mode did not surface; label severity high/medium/low. `status` is
`OK | SKIP | BLOCKED` with a one-line reason. A refused or unavailable call is `SKIP`, never a pass.

## 4. Exit gate — all must hold

| Metric | Threshold |
|---|---|
| median source chars | ≥ 40% lower than source-first |
| gold-set recall | ≥ 95%, no high-severity impact miss |
| duplicate reads | < 5% of calls |
| elapsed time overhead | ≤ 20% versus source-first |
| wrong writes authorised | 0 |

Fail any one: keep the index as an optional read-only experiment or drop it. Do not enlarge it into
a graph, add inferred edges, or start a server to make the number look better. A fail is a result.

## 5. Run rules

- read-only calls only; no write, lock, activate, publish or transport change;
- one task at a time, alternate mode order where practical to avoid a warm-cache advantage for one
  mode; note the order in `status`;
- never reuse a hash from a previous task as a current fact — re-read at task start;
- stop and ask if a target, gold-set row or tool capability is unclear;
- record the tool/server version once at the top of the run, not once per row.

## 6. Output

After the run, write a verdict to `docs/reference/coedit-gap-closure.md` §5.11: `PASS | FAIL |
INCOMPLETE`, the counts, and whether §5.10 moves from IDEA to experimental tool. No code or
template changes follow automatically — a separate approval is required.
