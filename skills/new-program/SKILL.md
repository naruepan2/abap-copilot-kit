---
name: new-program
description: Scaffold the local record for a new SAP project or a new program inside an existing project — project.yaml, README, program.yaml, spec index — without guessing a SID, client, or transport. Use when asked to "start a new project", "new program", "add a program to this project", "สร้างโปรแกรมใหม่", "เริ่มโปรเจคใหม่", "set up the record", or when a program is being worked on and has no program.yaml yet. Do not use for read-only analysis of an object that will not be changed.
---

# New project or new program

A record is cheap to create and expensive when wrong: a guessed SID or client sends a later
change to the wrong system. So the first rule is not "ask the user everything" — it is
**let the files answer, then ask only for what a file cannot know.**

## 1. Create a record or not

Create one when the object is about to be **created or changed**, or when the user asks for it.

**Do not create one** for read-only analysis, for reviewing someone else's program, or for a
question about where an object lives. Record growth without work is noise, and it turns
`Projects/` into a log.

## 2. Which of three situations

Determine this from the filesystem, not from the user's wording.

| Check | Situation | Consequence |
|---|---|---|
| `Projects/<PROJECT>/` missing | **new project** | must establish system + clients |
| project exists, `Projects/<PROJECT>/<PROGRAM>/` missing | **new program** | inherit system + clients from the project |
| record missing but the object exists in SAP | **missing record** | do not ask what to build — only record the facts |

The third case is the one that wastes time: the object already exists, so its purpose is not a
question for the user, it is something to read.

## 3. The interview — one round, options, never prose

Ask everything in a single `askQuestions` call. Use options so the answer is one click.

- **Project** — the existing folder names as options, plus "new project".
- **If new project** — SID, code client (ADT), test client (SAP GUI), language.
- **Spec** — `none` / exists in `spec/source` / elsewhere and I will copy it in.
- **Intent** — new build / bug fix / extension / change request.

**Never guess a SID, client, or transport**, and never take one from `mcp.json`, a previous
session, or another project's file. Those are configuration, not confirmation. If the user does
not know, write `transport: none` and leave system blank — an empty field is honest.

## 4. Scaffold from templates

New project:

```
Projects/<PROJECT>/project.yaml     from templates/project.yaml
Projects/<PROJECT>/README.md        from templates/project-README.md
```

New program inside an existing project:

```
Projects/<PROJECT>/<PROGRAM>/program.yaml   from templates/program.yaml  (fill `project:`)
Projects/<PROJECT>/<PROGRAM>/README.md      from templates/program-README.md
```

Spec files:

- FS exists and you were given it → `spec/source/<FS>` untouched, plus `spec/INDEX.md` from
  `templates/spec-INDEX.md`, with real line and byte counts in the integrity block.
- We write the spec → `spec/spec.md` from `templates/spec.md`, `spec_mode: authored`.
- No FS → `spec_mode: none` and **do not create an index**. An index with no spec behind it is
  a broken pointer that will be read as if it were valid.

Never copy a system or client into `program.yaml`. It carries `project:` and an empty
`override:` block; the project owns those facts. Never put `transport` in `project.yaml`.

## 5. Verify before reporting

```powershell
# the record must never reach the repository
git -C D:\abap-copilot-kit check-ignore -v "Projects/<PROJECT>/<PROGRAM>/program.yaml"
```

- `check-ignore` must report IGNORED. If it does not, stop — a customer identifier is about to
  be committed.
- For a vendored spec, confirm the integrity numbers match the file exactly; a wrong count makes
  the index stale from the first day.
- Re-read each file you created and confirm every filled field came from the user or a tool
  result, not from this skill.

## 6. Report

| Created | Path | Filled from |
|---|---|---|
| project.yaml | `Projects/<P>/project.yaml` | user / SAP logon |
| program.yaml | `Projects/<P>/<PROG>/program.yaml` | inherited + user |

Also state what is still unverified — normally the transport, and any field the user could not
answer — and what the next step is. A scaffold that hides an empty field is worse than one that
names it.
