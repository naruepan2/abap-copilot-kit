# Comment-block syntax by object type — lean framed form

Status: **examples from measured source + two UNVERIFIED cases.** This file does not authorise a
write. Protocol: `docs/reference/coedit-gap-closure.md` §5.12. Full AI-executable spec: Desktop
`coedit-approval-comment-block-design.md`. Never comment out existing code — insert a block beside
the change point.

## Evidence status

| object type | comment form | status | evidence |
|---|---|---|---|
| CLAS / PROG (ABAP) | `*` column 1, plus `"` inline | **EVIDENCED** | CLAS source read 2026-11-20: `"` trailing comments on enum values and in the method body; `*` markers (`*"* public components of class ...`) on generated section headers. Use `*` column 1 for COEDIT blocks; the `"*` lines are generated markers — never place a block on them |
| FUNC (function module) | `*` column 1, plus `"` inline | **EVIDENCED** | a real FUNC was read 2026-11-20 after resolving its FUGR first: `*` column-1 modification header and `"` inline comments in the body. Earlier 500 `[SY/530]` errors came from guessing a group, not from the object type |
| DDLS | `//` | **EVIDENCED** | live DDLS source read 2026-11-20: 16-line `////` header and `// ...` lines before annotations |
| SRVD | `//` expected | **UNVERIFIED** | three SRVD objects read in full 2026-11-20; none had existing comments (`grep //` returned no matches on one). `//` is still an expectation from DDL/BDEF syntax, not an observation — keep STOP until a commented SRVD is read |
| BDEF | `//` | **EVIDENCED** | live BDEF source read 2026-11-20: 16-line `////` header and a commented-out `// static action ...` line inside the behavior block |
| DDLX | `//` expected | **UNVERIFIED** | two DDLX objects read in full 2026-11-20 (48 and 74 lines); neither had any comment. `//` is expected from the DDL family but was not observed on a DDLX object |
| STOB/DO | n/a — generated | **DO NOT EDIT** | read 2026-11-20 returned source identical to its DDLS custom entity; a comment block here would be overwritten on regeneration. Edit the root DDLS instead |
| SRVB | unknown | **UNVERIFIED** | do not guess — read one object of that type first |

Probe note 2026-11-20: BDEF read also returned a candidate-index extension with
`status="incomplete"`, `reason="deadline"`, `applicability="unknown"`, `omissions.deadline=1`.
That is the tool's partial-parsing metadata, **not** evidence about the object's correctness. Do
not promote it into a fact or a finding.

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

## 4. BDEF — `//` EVIDENCED

```abap
//////////////////////////////////////////////////////////////////////////
// COEDIT <intent> OP1 REPLACE_UNIT — why: add save validation
// OLD: validation validateStatus on save { field ApprovalStatus; }
// NEW: validation validateStatus on save { field ApprovalStatus; }
//      validation validateDates on save { field StartDate; }
//////////////////////////////////////////////////////////////////////////
managed; // original source continues untouched below
```

`//` is evidenced on the probed BDEF. The OLD/NEW text and object-specific anchors are still
design examples — confirm them against the target object before any write.

## 5. DDLX / SRVB / STOB — no example

DDLX and SRVB: UNVERIFIED comment form. `STOP` and read one object of that type that actually has
a comment before writing. Do not adapt the DDLS or ABAP example by analogy.

STOB/DO: never place a block here. The probed STOB returned the same 16-line header and entity body
as the corresponding DDLS custom entity — it is a generated stub. Put the proposal in the root
DDLS source; the stub follows on regeneration.

## 6. Rules that apply to all four

1. every block insert is a write: fresh read + precondition + read-back;
2. `insert` is the only op a human can apply by uncommenting; `delete`, `replace`,
   `replace_unit` require manual editing of real source in SAP;
3. anchor is `anchor_text` with `occurrence == 1`; `line_hint` is never authoritative;
4. commented code is `UNVERIFIED` for syntax and ATC — never report a check as passed;
5. no activation or publication under a comment-block approval;
6. `DRIFT` never auto-creates a new intent — fresh analysis and human approval required.
7. never insert a proposal into a generated object (STOB/DO stub); find and edit its root source.

## 7. Why WHY is in both places

The index WHY explains the **intent** without opening the source. The inline WHY explains the
**local edit** to the person at that line. Same reason, two resolutions — not two decisions. If
they ever disagree, `STOP` and ask; do not auto-reconcile.

## 8. Placement near existing comments

**Default: put the COEDIT block BEFORE the existing developer comment**, closest to the code being
changed. The reader sees the proposed change first, then the original comment, then the code.

```abap
**********************************************************************
* COEDIT <intent> OP1 REPLACE_UNIT — why: ...
* OLD: ...
* NEW: ...
**********************************************************************
* existing developer comment about this line       "<<-- original, untouched
  original code below
```

**Exception: structural header.** When the existing comment is a structural header bound to the
code — for example `*\"* public components of class ...` in a CLAS — place the block AFTER that
header. Removing the block then leaves the header attached to its code exactly as before.

Never comment out or move the original comment in either case.

### If a COEDIT marker already exists

| Found | Action |
|---|---|
| same `intent-id` | `STOP` — never stack a second block for one intent; ask for cleanup or a new intent |
| different `intent-id`, OLD/NEW do not overlap | may add a separate intent, without touching the old block |
| different `intent-id`, OLD/NEW overlap or conflict | `STOP` and ask |
| ordinary comment (header, WRICEF, change history) | not a COEDIT block — add the new block using the default or exception above |

For the head index block: append after the existing file header with one blank line between; never
insert inside the header.

### Anchor restriction

Never use text from an existing comment as `anchor_text`. Comments can be edited without changing
compiled behaviour, so they are not stable anchors. Choose text from real code with
`occurrence == 1`.
