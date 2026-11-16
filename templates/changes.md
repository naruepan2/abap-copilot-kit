# Changes — <PROGRAM>

Pre-release change log. One row per **activated** change. Newest last. Written after activation
succeeds — before that, a row is a hope, not a record.

**Rollback has two owners. This file is the index; `.baseline/` is the payload.**

| Situation | Authority |
|---|---|
| TR **released** | SAP version management — `SAPRead(type="VERSIONS")`, then `VERSION_SOURCE` or `action="diff"` |
| TR **still open** | SAP has no version yet. `.baseline/` is the only way back |

An AI reads this file to decide *where* to roll back, then reads the named baseline for *what* to
restore. Never infer source from the description: a prose summary is not a byte-exact state. If the
named baseline is missing, report `UNVERIFIED` and recommend a human decision — do not restore.

## Rows

| # | Date | Type | What | Why | TR | TR state | Objects | Activation | Version | Evidence | Baseline | Rollback-to |
|---:|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | <YYYY-MM-DD> | <bug fix / extension / change request> | <object + behaviour changed + condition, one line> | <defect or request, one line; link spec/notes.md instead of copying it> | <TR> | open | <objects> | <n> | v<n> | <ATC clean · test 4.1 pass> | `.baseline/<OBJ>_<TR>.abap` | `.baseline/<OBJ>_<TR>.abap` |

`What` and `Why` are not interchangeable:

- **What** — technical, one line: object, changed behaviour, the condition that triggered it.
  "amount rounding for negative values in ZMME011" — not "bug fix".
- **Why** — business reason or defect, one line: "F-042: VAT off by 1 satang on credit notes".
  For a change request, link `spec/notes.md` rather than copying the functional's text.
- **Type** holds the category; do not repeat it in `What`.
- **Version** is `v1`, `v2`, … in activation order. **Activation** is the same number.
- **Baseline** is the source captured before this activation. **Rollback-to** is the path to read
  when undoing this row. Both must be exact paths, not descriptions.

## `.baseline/` — source captured before each activation

| File | Holds | Used for |
|---|---|---|
| `<OBJ>_<TR>.abap` | active source **before the first activation** in that TR | rollback of the whole TR |
| `<OBJ>_<TR>_v<n>.abap` | active source **before activation n** | rollback of one activation without losing earlier ones |

| | |
|---|---|
| Written | **before** each activation: read the active source and save it here |
| Not written | for an edit that was never activated — `action="diff"` with `from="active"` `to="inactive"` already covers the pending cycle |
| Deleted | when the TR is released — SAP version management takes over, and a stale baseline nobody dares delete is worse than none |
| Size | roughly the source size, e.g. 130 KB for a 1,700-line program |

`_v1` has no separate file — `<OBJ>_<TR>.abap` *is* v1. Every later activation gets its own
`_v<n>` file. All files are **before** states, never after.

See one activation's change:

```powershell
git diff --no-index ".baseline/<OBJ>_<TR>_v2.abap" "<path to current source>"
```

## Rules

- **A baseline is "before", not "correct".** It records what was there, not what should be.
- **Keep `TR state` honest.** A row left `open` after release makes its baseline permanent by
  accident. Update on the user's word, or when `SAPTransport(action="get")` reports `R`, then
  delete every baseline for that TR.
- **Never let this file replace verification.** "The changelog says it was changed" is not
  evidence that the change is right.
- **Restore needs human approval.** The AI may read the baseline and propose the diff; it must not
  call `SAPWrite` to roll back without a fresh Pre-Flight approval.
- **No customer data here beyond object names and transport numbers.** No source, no passwords.
