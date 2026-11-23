---
name: sap-new-record
description: Decide which local record is needed before scaffolding SAP work, then hand off to the matching skill. Use when asked to "start a new project", "new program", "add a program to this project", "set up the record", "สร้างโปรเจคใหม่", "เริ่มโปรแกรมใหม่", or when an object is being worked on and has no record. Never guess a SID, client, or transport. Does not scaffold, connect to SAP, or read credentials.
---

# New record — decide, then delegate

A record is cheap to create and expensive when wrong: a guessed SID or client sends a later
change to the wrong system. This skill only classifies the request. It does not write files.

All three skills in this family are SAP-specific: `sap-new-record` routes, `sap-new-project`
creates a project record, and `sap-new-program` creates a program record. Retirement is a
separate workflow with its own confirmation gate: `sap-project-unregister` and
`sap-program-unregister`.

## 1. Create a record or not

Create one when an object is about to be **created or changed**, or when the user asks for it.
Do not create one for read-only analysis, for reviewing someone else's program, or for a
question about where an object lives. Record growth without work is noise.

## 2. Classify from the filesystem, not the wording

| Check | Situation | Load |
|---|---|---|
| `Projects/<PROJECT>/` missing | new project | skill `sap-new-project` |
| project exists, `Projects/<PROJECT>/<PROGRAM>/` missing | new program | skill `sap-new-program` |
| record missing but the object exists in SAP | missing record | skill `sap-new-program`, with the read-the-facts path — do not ask what to build |
| a record already exists | no new record | read it and continue with the task |

If the project code is ambiguous, resolve it **before** delegating. Codes are case-sensitive:
`ABC`, `Abc` and `abc` are three different names. Read `Projects/README.md` and the folder names
as written; never silently "correct" the case. If no project matches exactly, offer the user two
choices: re-check the spelling, or load skill `sap-new-project` to register that exact code first.
Do not pick a near-match.

## 3. Shared rules for the handoff

- One artifact per call. A project skill never creates a program; a program skill never creates a project.
- Never guess a SID, client, transport, package or program name. Never take one from `mcp.json`,
  a previous session, another project's file, or a folder name. A blank field is a pending question.
- Never ask for a password, and never read or echo `${input:...}`, `SAP_PASSWORD`, user names or
  client numbers from `mcp.json`. Ask the user in chat if a value is needed.
- Never edit `mcp.json` during registration. It is user scope and a duplicate server name is
  silently disabled.
- Ask only what is missing, one question at a time; use options when possible. Batch questions
  only if the user asks to answer all at once.

## 4. Hand off and report

Name the chosen skill and the reason (the table row). Do not scaffold here. If the situation is
not in the table, say so and ask — do not improvise a fourth path.
