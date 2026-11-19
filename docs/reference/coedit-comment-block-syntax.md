# Comment-block syntax by object type — evidence and examples

Status: **examples from measured source + one UNVERIFIED case.** This file does not authorise a
write. The protocol is `docs/reference/coedit-gap-closure.md` §5.12; the full AI-executable spec is
on the Desktop as `coedit-approval-comment-block-design.md`. Never comment out existing code —
insert a block beside the change point.

## Evidence status

| object type | comment form | status | evidence |
|---|---|---|---|
| CLAS / PROG (ABAP) | `*` in column 1 | **EVIDENCED** | standard ABAP; seen in installed source during §5.6–§5.8 probes |
| DDLS / SRVD (`//` header) | `//` | **EVIDENCED** | read from live DDLS source on 2026-11-20: 16-line `////...` header and `// ...` lines before annotations |
| BDEF | `//` expected, not probed | **UNVERIFIED** | no BDEF source read succeeded in the probe session; run a read-only probe before using this form |
| DDLX / SRVB | unknown | **UNVERIFIED** | do not guess — read one object of that type first |

If the form for an object type is UNVERIFIED: `STOP` and ask. Do not fall back to `*`.

## 1. PROG / CLAS — ABAP `*`

```abap
**********************************************************************
* CO-EDIT PROPOSAL <intent-id> OP-1/2 — DISABLED · REPLACE_UNIT
* BEFORE: <sha256-short> · locator: implementations · hash_engine: arc-1.editable
* WHY: replace method body with reviewed version
* Apply this point in SAP, then delete this block. Order: OP-1 -> OP-2
**********************************************************************
* OLD UNIT (method read_status):
*   METHOD read_status.
*     result = 'V1'.
*   ENDMETHOD.
* NEW UNIT (apply in SAP):
*   METHOD read_status.
*     result = 'V2'.
*   ENDMETHOD.
**********************************************************************
  METHOD read_status.
    result = 'V1'.
  ENDMETHOD.                      "<<-- original code untouched
```

Why `REPLACE_UNIT` here: a whole method is one artifact; listing each line as a separate op
creates ordering risk when earlier inserts shift lines.

## 2. DDLS — `//`

```abap
//////////////////////////////////////////////////////////////////////////
// CO-EDIT PROPOSAL <intent-id> OP-1/2 — DISABLED · REPLACE_UNIT
// BEFORE: <sha256-short> · locator: main · hash_engine: arc-1.editable
// WHY: expose one additional field in the projection
// Apply this point in SAP, then delete this block. Order: OP-1 -> OP-2
//////////////////////////////////////////////////////////////////////////
// OLD UNIT (view body excerpt):
//   key DocumentId as DocumentId,
// NEW UNIT (apply in SAP):
//   key DocumentId as DocumentId,
//       ApprovalStatus as ApprovalStatus,
//////////////////////////////////////////////////////////////////////////
define view entity ZC_EXAMPLE as select from ZI_EXAMPLE
{
  key DocumentId as DocumentId,
}
```

DDLS notes:

- the header matches the `//` style already present in the live object — do not mix `*` and `//`;
- annotation lines before the `define` are part of the same unit; changing one is `REPLACE_UNIT`;
- DDLS is usually activated with its BDEF, projection and service objects — see the
  all-or-nothing rule in §5.12.

## 3. BDEF — `//` expected, UNVERIFIED

```abap
//////////////////////////////////////////////////////////////////////////
// CO-EDIT PROPOSAL <intent-id> OP-1/1 — DISABLED · REPLACE_UNIT  [SYNTAX UNVERIFIED]
// BEFORE: <sha256-short> · locator: main · hash_engine: arc-1.editable
// WHY: add validation on save
// Read one BDEF of the target system first and confirm comment form before writing.
//////////////////////////////////////////////////////////////////////////
// OLD UNIT (behavior definition excerpt):
//   validation validateStatus on save { field ApprovalStatus; }
// NEW UNIT (apply in SAP):
//   validation validateStatus on save { field ApprovalStatus; }
//   validation validateDates on save { field StartDate; }
//////////////////////////////////////////////////////////////////////////
managed; // original source continues untouched below
```

Do not write this example into SAP until a read-only probe confirms `//` on the target release.

## 4. Index block — one per object

```abap
* ABAP header (for DDLS/BDEF use // instead)
**********************************************************************
* CO-EDIT PROPOSAL INDEX <intent-id> · 2 points · DISABLED
* OP-1 REPLACE_UNIT method read_status
* OP-2 INSERT_AFTER last assignment in constructor
* Apply in order. Verify each with syntax check. Delete all blocks afterwards.
**********************************************************************
```

The index is navigation only. A conflict between index and an inline block is `STOP` and ask.

## 5. Rules that apply to all four

1. every block insert is a write: fresh read + precondition + read-back;
2. `insert` is the only op a human can apply by uncommenting; `delete`, `replace`,
   `replace_unit` require manual editing of real source in SAP;
3. anchor is `anchor_text` with `occurrence == 1`; `line_hint` is never authoritative;
4. commented code is `UNVERIFIED` for syntax and ATC — never report a check as passed;
5. no activation or publication under a comment-block approval;
6. `DRIFT` never auto-creates a new intent — fresh analysis and human approval required.
