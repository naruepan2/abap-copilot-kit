---
name: sap-program-unregister
description: Retire one program record from the local Projects notebook and its private mirror - preflight, preview, explicit UNREGISTER confirmation, then _retired locally or hard delete. Use for "unregister program", "retire program record", "remove program from Projects". Never touches SAP objects, transport, MCP config, or a GitHub repository, and never pushes anything.
argument-hint: [PROJECT] [PROGRAM]
---

# SAP program unregister

Retire **one** local program record. This is an offboarding procedure for the notebook, not an
SAP action and not a Git action against GitHub.

Hard rules:

- The kit repository is public. Customer data stays on this machine or in the private mirror.
- Never add retired material to the kit repository, and never push a retired folder anywhere.
- Never modify `mcp.json`, an MCP profile, `settings.json`, a transport, or an SAP object.
- Never ask for a password, token, or secret, and never read one from a config file.
- One program per call. No wildcards, no bulk, no recursive scan from the workspace root.
- Every run ends with a fresh confirmation. An earlier approval never carries over.

## 1. Resolve the target from the filesystem

Read `Projects/README.md`, then match the folder names exactly. Project and program codes are
case-sensitive. `LUF`, `LuF`, and `luf` are three different names; never "correct" the case.

If the user's message is ambiguous, ask again before any read beyond the folder listing:

> Do you mean `project <PROJECT>`, `program <PROGRAM>`, or both?

If neither folder matches exactly, stop. Do not pick a near-match. If the program folder is
missing, report that and stop; there is nothing to unregister.

## 2. Read the record and preflight

Read `program.yaml`, `README.md`, `changes.md`, and `spec/notes.md` when present. Report:

- project and program, transport value, spec mode, and last updated date
- number of files under the program folder and total bytes
- whether `spec/source/**` and `.baseline/**` exist — these are never mirrored, so losing them
  locally loses them completely unless retired locally

**Stop and ask** if any row in `changes.md` has `TR state: open`, or if `.baseline/` exists.
That baseline is the only rollback point before transport release. Deleting it is irreversible.
State the exact rows/files and wait for a separate decision.

**Stop** if the project has no other program only when the user also asked to retire the project —
this skill retires the program; the project skill handles the project.

## 3. Preflight the private mirror

The mirror path is not guessed. Read it from the session or ask the user; the routine is
`tooling/workspace-sync.ps1 -Workspace <private-repo> -Check` with `-RepoMemory <path>` when repo
memory is mirrored.

Stop unless both are true:

- the private repository is clean (`git status --porcelain` empty)
- the mirror check exits 0 with the same arguments that will be used in step 7

A dirty mirror means unreviewed changes could be removed by the later `-Write`. Do not commit
or clean it on the user's behalf.

## 4. Find pointers

Search named files under the repo-memory folder and the kit's own `INDEX.md` for the exact
path `Projects/<PROJECT>/<PROGRAM>`. Do not scan the workspace root recursively.

Report each pointer as `path:line`. A pointer left behind after retirement is a broken reference.
If a pointer exists, say what will happen to it: update it to say the record was retired, or
remove the line. Ask which, then include that edit in the preview.

## 5. Preview

Show, without changing anything:

| Item | Value |
|---|---|
| Target | `<PROJECT>/<PROGRAM>` |
| Local files to retire | exact paths and count |
| Mirror files to remove | exact paths, or none |
| Pointer edits | exact path and line |
| Disposition | local `_retired` or hard delete |
| Not touched | SAP object, transport, MCP config, GitHub |

**Default disposition is local `_retired`**, because the functional specification under
`spec/source/` and the baselines under `.baseline/` are not mirrored. Hard delete is opt-in and
must be named by the user after this preview. There is no GitHub archive option: the kit
repository is public and history cannot be taken back.

## 6. Confirm

Show this line and wait:

```
Type UNREGISTER <PROJECT>/<PROGRAM> to proceed.
```

If the user replies with anything else, stop. If the reply is ambiguous — for example only a
project code, or both project and program — ask again which scope was intended. For hard delete,
require one more explicit line:

```
Type DELETE PERMANENTLY <PROJECT>/<PROGRAM> to skip local retirement.
```

Do not accept "yes", "go ahead", or an approval given for an earlier record.

## 7. Execute

For local retirement:

1. Create `Projects/_retired/<PROJECT>/<PROGRAM>/` and move the whole folder there.
2. Remove the program's row or line from `Projects/<PROJECT>/README.md`.
3. Apply the pointer edits approved in step 4.
4. Run `workspace-sync.ps1 -Write` with the exact arguments from step 3. `_retired` starts with
   an underscore, so the mirror never sees it.

For hard delete, the same steps without the move. State plainly in the report that
`spec/source/**` and `.baseline/**` are gone locally.

Do not commit or push either repository. Do not create a new log file.

## 8. Verify and report

- mirror `-Check` with the same arguments, exit 0
- kit `verify-all.ps1` and `census.ps1` clean
- no pointer resolves to the retired path
- private repository shows only the mirror changes, ready for a human to review and commit

Report the exact paths moved or removed, the mirror result, the pointers edited, and what was
deliberately not touched. Never claim the SAP object was removed — it was not.

## Stop conditions

Ambiguous target, missing folder, open TR or baseline without a separate decision, dirty mirror,
failing preflight, pointer choice not made, wrong confirmation token, or any request to touch SAP,
MCP config, or GitHub.
