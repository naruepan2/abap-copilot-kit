# Changes — <PROGRAM>

One row per **activated** change. Newest last. Written after activation succeeds — before
that, a row is a hope, not a record.

**Rollback has two owners, and this file is only one of them:**

| Situation | Authority |
|---|---|
| The TR is **released** | SAP version management — `SAPRead(type="VERSIONS")`, then `VERSION_SOURCE` or `action="diff"` |
| The TR is **still open** | SAP has no version yet. This is what `.baseline/` is for |

That second row is the whole reason this file exists: between activating and releasing there is
no rollback point in SAP, which is exactly when most work happens.

| # | Date | Intent | TR | TR state | Objects | Evidence | Baseline |
|---:|---|---|---|---|---|---|---|
| 1 | <YYYY-MM-DD> | <bug fix / extension / change request — one line> | <TR> | open | <objects> | <ATC clean · test 4.1 pass> | `.baseline/<OBJ>_<TR>.abap` |

## `.baseline/` — one file per object per TR

| | |
|---|---|
| Written | **before the first activation** of that object in that TR: read the active source, save it here |
| Not written | on every edit — `action="diff"` with `from="active"` `to="inactive"` already covers pending edits inside one cycle |
| Deleted | when the TR is released — SAP version management takes over, and a stale baseline that nobody dares delete is worse than none |
| Size | roughly the source size, e.g. 130 KB for a 1,700-line program |

To see everything changed since the TR started:

```powershell
git diff --no-index ".baseline/<OBJ>_<TR>.abap" "<path to current source>"
```

## Rules

- **A baseline is "before", not "correct".** It records what was there, not what should be.
- **Keep `TR state` honest.** If it says `open` after the TR was released, the baseline becomes
  permanent by accident. Update it when the user says so, or when
  `SAPTransport(action="get")` reports status `R`.
- **Never let this file replace verification.** "The changelog says it was changed" is not
  evidence that the change is right.
- **No customer data here beyond object names and transport numbers.** No source, no passwords.
