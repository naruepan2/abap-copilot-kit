---
name: sap-new-program
description: Scaffold one program record under Projects/<PROJECT>/<PROGRAM>/ - program.yaml, README, changes.md and spec wiring. Use for "register new program", "new Z program", "เพิ่มโปรแกรมใหม่", "เริ่มโปรแกรมใหม่". Requires the project record to exist. Asks for every unknown, never guesses a SID, client, transport or FS, never connects to SAP, never reads credentials.
---

# New program — one program record

Creates `Projects/<PROJECT>/<PROGRAM>/` only. Never creates a project, never connects to SAP,
never edits `mcp.json`. If the project record is missing, stop and load skill `sap-new-project`
first. The router for this family is skill `sap-new-record`.

Read `Projects/README.md` first. It owns the layout, the "one fact, one file" rules, and the
spec contract.

## 1. Resolve the project first

A program cannot exist without a project. Resolve it **before any other question or SAP call**.

- If the code came from the user or the session, restate it **exactly as typed** for confirmation.
  `LUF`, `LuF` and `luf` are three different names. Never change the case silently.
- If it is not known, ask the user directly. Do not infer it from the object name, a recent
  conversation, or a folder listing.
- If several projects exist, read `Projects/README.md` (not a recursive scan) and offer the
  project codes as options.
- If nothing matches **exactly**, stop and offer two choices: re-check the spelling, or load
  skill `sap-new-project` to register that exact code first. Do not pick a near-match and do
  not ask which SAP system to use.

Once the folder matches exactly, read that project's `project.yaml` for `system`, `code_client`
and `test_client`. These are the source of truth for the record. If a field is blank, keep it
blank and name it in the report as a pending question — do not infer it to unblock work.

## 2. Ask, one question at a time

Skip values already known. Restate them, ask only what is missing, validate each answer before
the next question, and use options rather than free prose. Match the user's language. Batch
questions only if the user explicitly asks to answer all at once.

- **Program name** — the SAP object name, exactly as typed.
- **One-line purpose** — what the object is for.
- **Spec** — `none` / exists in `spec/source` / elsewhere and the user will copy it in.
- **Transport** — ask only if the project context does not settle it; see step 4. Never invent a
  transport number.

Do not ask for a password and never read or echo `${input:...}`, `SAP_PASSWORD`, SAP user or
client values from `mcp.json`. Asking the user in chat is the only fallback.

## 2b. Template gate — only for a new executable report (PROG)

If the object will be a **new classic executable report (PROG)**, choose the report template before
writing code. Do not run this gate for CLAS, FUGR, FUNC, DDLS, RAP or an existing report.

Ask one question, in the user's language:

```text
Before creating a new classic ABAP report (SE38), choose the reference template:
1. Existing template — give the exact SE38 program name. I will read its main source,
   includes, classes, event flow and comments before writing the new report.
2. No template — use the bundled YSMILE SALV template in
   skills/sap-new-program/references/salv/ (main + _TOPZ, _S01, _C01, _C02;
   variants/edit1 and edit2 for whole-column and per-cell editing).
```

Rules:

- A named template must be checked through a real SAP read tool when the target is confirmed. If
  the name is not found, do **not** silently switch to the bundled one — ask for a corrected name or
  explicit permission to use the built-in template. Two failed lookups is the limit; then ask the
  user to attach the source or choose option 2.
- No SAP connection or search tool → say so. Never claim the named template "does not exist".
- When option 2 is chosen, read the bundled `.abap` files before generating code. They are the
  authoritative pattern, not the Markdown summary. Keep all includes from one variant; do not mix
  base and edit1/edit2 fragments.
- Record the template choice in `spec/notes.md` as a decision. Do not add a new field to
  `program.yaml`.
- Before business logic, scan the template's comments, event flow and extension hooks. Preserve its
  naming, include boundaries, class responsibilities and event flow unless the requirement changes
  them.
- Class-first still applies: a new report is a thin selection/event shell and business logic goes
  to a justified class. The bundled template uses local classes; if material logic grows beyond a
  small scope, record the reason and propose the class extraction rather than silently expanding
  the local class.

## 3. Object lookup — read only

After the name is known, a read-only lookup is useful but optional. Do it only when the target
system and client are confirmed and an ARC-1 connection is available:

```
SAPSearch(searchType="tadir_lookup", names=[<name>], objectTypes=[<types>])
SAPTransport(action="list")   # then get if needed
```

Found → reuse the package and TR. Not found → new object. Lookup failed, no logon, or unclear
result → stop and ask. Never claim "does not exist" from a failed call. No SAP writes.

## 4. Transport

Transport belongs to the **program**, never to `project.yaml` (two programs in one project are
normally developed on different requests). `$TMP` is for throwaway work. If the lookup returned a
package and TR, reuse them. Otherwise offer "has TR / not yet / use $TMP" and record the answer.
Never invent a number. Write `transport: none` when there is no request.

## 5. Create from templates

```
Projects/<PROJECT>/<PROGRAM>/program.yaml   from templates/program.yaml  (fill `project:`)
Projects/<PROJECT>/<PROGRAM>/README.md      from templates/program-README.md
Projects/<PROJECT>/<PROGRAM>/changes.md     from templates/changes.md
Projects/<PROJECT>/<PROGRAM>/spec/notes.md   from templates/spec-NOTES.md
```

`spec/notes.md` is created for every spec mode, including `none`. It is the one home for
questions, contradictions and decisions — do not create a second `reports/DECISIONS.md`.

`.baseline/` is not created here — it appears on the first activation, from `templates/changes.md`.
Do not create an `AGENTS.md` at program level: the root contract already states the access rules.

Never copy a system or client into `program.yaml`. It carries `project:` and an empty `override:`
block; the project owns those facts.

Spec files:

- FS exists and was given → `spec/source/<FS>` untouched, plus `spec/INDEX.md` from
  `templates/spec-INDEX.md`, with real line and byte counts in the integrity block.
- We write the spec → `spec/spec.md` from `templates/spec.md`, `spec_mode: authored`.
- No FS → `spec_mode: none` and **do not create an index**. An index with no spec behind it is a
  broken pointer that will be read as if it were valid.

## 6. Verify

From the kit root (use `git -C <kit root>` if the shell is elsewhere; take the root from
`$env:ABAP_KIT_ROOT` or `install-kit.ps1 -ShowPaths`):

```powershell
git check-ignore -v "Projects/<PROJECT>/<PROGRAM>/program.yaml"
```

It must report IGNORED. If it does not, stop — a customer identifier is about to be committed.
For a vendored spec, confirm the integrity numbers match the file exactly. Re-read every file
you created and confirm each filled value came from the user, a tool result, or the project
record — not from this skill.

## 7. Report

List exact files written, the lookup result (or `SKIPPED — no confirmed target`), and every field
left blank. State that nothing was deployed and no password was read. Never claim a scaffold is
a working program.
