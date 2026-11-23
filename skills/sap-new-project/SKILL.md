---
name: sap-new-project
description: Scaffold one project record under Projects/<PROJECT>/ - project.yaml and README only. Use for "register new project", "onboard project", "เพิ่มโปรเจคใหม่". Asks for every unknown, never guesses a SID or client, never creates a program, never connects to SAP, never edits mcp.json or reads credentials.
---

# New project — one project record

Creates `Projects/<PROJECT>/` only. No program folder, no SAP call, no config edit. If you need
a program as well, stop here and load skill `sap-new-program` after this record exists.

Read `Projects/README.md` first. It owns the layout and the "one fact, one file" rules.

## 1. Ask, one question at a time

Skip anything the user already stated. Restate known values, ask only what is missing, and
validate each answer before the next question. Use options rather than free prose. Match the
user's language.

- **Project code** — exact characters as typed. `ABC`, `Abc` and `abc` are different names.
  Do not uppercase, lowercase or "fix" it. Check `Projects/README.md` and the folder names;
  if a folder with that exact name exists, stop and tell the user to load skill `sap-new-program`.
- **SID, code client, test client, language** — ask the user. If unknown, leave the field blank.
  A blank field is a pending question, not permission to proceed, and it may be filled later at
  logon with the source stated. Never infer these from `mcp.json`, a connection list, another
  project, or the folder name.
- Do **not** ask for a transport or a password. Transport belongs to a program, and no SAP object
  exists yet. No program means no owner to ask about.

Never read, resolve or echo `${input:...}`, `SAP_PASSWORD`, SAP user or client values from
`mcp.json`. Passing config shape is not part of this skill.

## 2. Create from templates

```
Projects/<PROJECT>/project.yaml     from templates/project.yaml
Projects/<PROJECT>/README.md        from templates/project-README.md
```

Fill only what the user confirmed. Leave unverified fields empty and list them in the report.
Never copy system or client values down into a future program record: the program uses `project:`
and an empty `override:` block. Transport is never written into `project.yaml`.

Do not create `AGENTS.md` at project level: the root `AGENTS.md` already states the access rules,
and a second copy would drift. Do not create `_archive/` or `_sandbox/` until there is content
to put there.

## 3. Verify

From the kit root (use `git -C <kit root>` if the shell is elsewhere; take the root from
`$env:ABAP_KIT_ROOT` or `install-kit.ps1 -ShowPaths`):

```powershell
git check-ignore -v "Projects/<PROJECT>/project.yaml"
```

It must report IGNORED. If it does not, stop — a customer identifier is about to be committed.
Re-read both files and confirm every filled value came from the user or a tool result.

## 4. Report

List the exact files written and every field left blank. State that nothing connected to SAP and
no password was read. Next step: load skill `sap-new-program` for each program in this project.
