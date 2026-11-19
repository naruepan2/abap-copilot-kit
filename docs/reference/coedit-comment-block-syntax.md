# Comment-block syntax by object type — lean framed form

Status: **examples from measured source + two UNVERIFIED cases.** This file does not authorise a
write. Protocol: `docs/reference/coedit-gap-closure.md` §5.12. Full AI-executable spec: Desktop
`coedit-approval-comment-block-design.md`. Never comment out existing code — insert a block beside
the change point.

## Evidence status

| object type | comment form | status | evidence |
|---|---|---|---|
| CLAS / PROG (ABAP) | `*` column 1 | **EVIDENCED** | standard ABAP; seen in installed source during §5.6–§5.8 probes |
| DDLS | `//` | **EVIDENCED** | live DDLS source read 2026-11-20: 16-line `////` header and `// ...` lines before annotations |
| SRVD | `//` expected | **UNVERIFIED** | no SRVD main comment was read in the probe session; read one before writing |
| BDEF | `//` expected | **UNVERIFIED** | no BDEF source read succeeded; read one before writing |
| DDLX / SRVB | unknown | **UNVERIFIED** | do not guess — read one object of that type first |

If the form is UNVERIFIED: `STOP` and ask. Do not fall back to `*`.

## Block anatomy — two levels, one frame

- **index block** at the head of the object: intent, op count, base hash, hash engine, op list,
  cleanup instruction. WHY appears once per op here.
- **inline block** immediately before the code being changed: op id + type, one-line WHY, OLD
  and/or NEW.
- frame = **one separator line above + one below**, same character as the comment prefix (`*` for
  ABAP, `//` for DDLS/BDEF/SRVD). No double header.
- original source below the block stays untouched.

## 1. PROG / CLAS — ABAP `*`

```abap
**********************************************************************
* COEDIT <intent> OP1 REPLACE_UNIT — why: return reviewed V2 value
* OLD: METHOD read_status. result = 'V1'. ENDMETHOD.
* NEW: METHOD read_status. result = 'V2'. ENDMETHOD.
**********************************************************************
  METHOD read_status.
    result = 'V1'.
  ENDMETHOD.
```

`INSERT_AFTER` inline — same frame, no OLD line:

```abap
**********************************************************************
* COEDIT <intent> OP2 INSERT_AFTER — why: set mode from new contract
* NEW: me->mode = c_mode-new.
**********************************************************************
  me->standard = standard.
```

Head index for PROG/CLAS (WHY once per op, base hash once for the object):

```abap
**********************************************************************
* COEDIT INDEX <intent> 2ops base:<hash8> eng:arc-1.editable
* OP1 REPLACE_UNIT read_status — why: return reviewed V2 value
* OP2 INSERT_AFTER constructor — why: set mode from new contract
* APPLY in order, then DELETE ALL BLOCKS
**********************************************************************
```

Why `REPLACE_UNIT` here: a whole method is one artifact; listing each line as a separate op
creates ordering risk when earlier inserts shift lines.

## 2. DDLS — `//`

Head index for DDLS:

```abap
//////////////////////////////////////////////////////////////////////////
// COEDIT INDEX <intent> 1op base:<hash8> eng:arc-1.editable
// OP1 REPLACE_UNIT ZC_EXAMPLE — why: expose ApprovalStatus to Fiori
// APPLY, then DELETE ALL BLOCKS
//////////////////////////////////////////////////////////////////////////
```

```abap
//////////////////////////////////////////////////////////////////////////
// COEDIT <intent> OP1 REPLACE_UNIT — why: expose ApprovalStatus to Fiori
// OLD: key DocumentId as DocumentId,
// NEW: key DocumentId as DocumentId, ApprovalStatus as ApprovalStatus,
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

## 3. SRVD — `//` expected, UNVERIFIED

```abap
//////////////////////////////////////////////////////////////////////////
// COEDIT <intent> OP1 REPLACE_UNIT — why: expose reviewed entity  [SYNTAX UNVERIFIED]
// OLD: expose ZC_EXAMPLE as Example;
// NEW: expose ZC_EXAMPLE as Example; expose ZI_EXAMPLE_TP as ExampleTP;
//////////////////////////////////////////////////////////////////////////
```

Read one SRVD of the target system and confirm the comment form before writing this.

## 4. BDEF — `//` expected, UNVERIFIED

```abap
//////////////////////////////////////////////////////////////////////////
// COEDIT <intent> OP1 REPLACE_UNIT — why: add save validation  [SYNTAX UNVERIFIED]
// OLD: validation validateStatus on save { field ApprovalStatus; }
// NEW: validation validateStatus on save { field ApprovalStatus; }
//      validation validateDates on save { field StartDate; }
//////////////////////////////////////////////////////////////////////////
managed; // original source continues untouched below
```

Do not write this example into SAP until a read-only probe confirms `//` on the target release.

## 5. DDLX / SRVB — no example

UNVERIFIED comment form. `STOP` and read one object of that type first. Do not adapt the DDLS or
ABAP example by analogy.

## 6. Rules that apply to all four

1. every block insert is a write: fresh read + precondition + read-back;
2. `insert` is the only op a human can apply by uncommenting; `delete`, `replace`,
   `replace_unit` require manual editing of real source in SAP;
3. anchor is `anchor_text` with `occurrence == 1`; `line_hint` is never authoritative;
4. commented code is `UNVERIFIED` for syntax and ATC — never report a check as passed;
5. no activation or publication under a comment-block approval;
6. `DRIFT` never auto-creates a new intent — fresh analysis and human approval required.

## 7. Why WHY is in both places

The index WHY explains the **intent** without opening the source. The inline WHY explains the
**local edit** to the person at that line. Same reason, two resolutions — not two decisions. If
they ever disagree, `STOP` and ask; do not auto-reconcile.
