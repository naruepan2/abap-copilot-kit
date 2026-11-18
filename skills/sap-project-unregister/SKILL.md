---
name: sap-project-unregister
description: Retire one SAP project record from the local Projects notebook and its private mirror - preflight, preview, explicit UNREGISTER confirmation, then local _retired or hard delete. Use for "unregister project", "retire project record", "remove project from Projects". Refuses when programs remain, and never touches SAP objects, MCP config, or a GitHub repository.
argument-hint: [PROJECT]
---

# SAP project unregister

Retire **one** local project record. This removes a notebook folder and its mirror entries only.
It does not delete an SAP system, a destination, an MCP server, a transport, or a GitHub file.

Hard rules:

- The kit repository is public. Customer data stays on this machine or in the private mirror.
- Never add retired material to the kit repository, and never push a retired folder anywhere.
- Never modify `mcp.json`, `settings.json`, an MCP profile, or an SAP object. A registry skill in
  another toolkit may have created a profile; that is a separate workflow and stays separate.
- Never ask for a password, token, or secret, and never read one from a config file.
- One project per call. No wildcards, no bulk, no recursive scan from the workspace root.
- Every run ends with a fresh confirmation. An earlier approval never carries over.

## 1. Resolve the target from the filesystem

Read `Projects/README.md`, then match the folder name exactly. Codes are case-sensitive.
If the user's message could mean the project or one of its programs, ask again before continuing:

> Do you mean `project <PROJECT>`, `program <PROGRAM>`, or both?

If no folder matches exactly, stop. Do not pick a near-match. Do not infer a code from a folder
name, a connection list, or a previous session.

## 2. Read the record and preflight

Read `project.yaml` and `README.md`. Report system, clients, language, and last updated date.
List every program folder under the project.

**Stop** if any program remains. A project record is the parent for those program records;
retire each program first with skill `sap-program-unregister`. Never cascade.

If a retired copy already exists under `Projects/_retired/<PROJECT>/`, stop and ask before
overwriting it. Do not merge two retirements into one folder.

## 3. Preflight the private mirror

The mirror path is not guessed. Use the same `-Workspace` and optional `-RepoMemory` arguments
that will be used in step 7.

Stop unless both are true:

- the private repository is clean
- `workspace-sync.ps1 -Check` exits 0 with those exact arguments

A dirty mirror could contain unreviewed changes that the later `-Write` would remove. Do not
commit or clean it on the user's behalf.

## 4. Find pointers

Search named files under the repo-memory folder and the kit's `INDEX.md` for the exact path
`Projects/<PROJECT>/`. Do not scan the workspace root recursively.

Report each pointer as `path:line`. Ask whether to update or remove each one; include the answer
in the preview. A pointer left behind after retirement is a broken reference.

## 5. Preview

Show, without changing anything:

| Item | Value |
|---|---|
| Target | `<PROJECT>` |
| Project files to retire | exact paths and count |
| Programs remaining | zero, or STOP |
| Mirror files to remove | exact paths, or none |
| Pointer edits | exact path and line |
| Disposition | local `_retired` or hard delete |
| Not touched | MCP profile, `mcp.json`, SAP object, GitHub |

**Default disposition is local `_retired`**, because project records may carry system and client
facts that are not mirrored. Hard delete is opt-in and must be named by the user after this
preview. There is no GitHub archive option: the kit repository is public and history cannot be
taken back.

## 6. Confirm

Show this line and wait:

```
Type UNREGISTER <PROJECT> to proceed.
```

If the user replies with anything else, stop. If the reply names a program or both a project and
a program, ask again which scope was intended. For hard delete, require one more explicit line:

```
Type DELETE PERMANENTLY <PROJECT> to skip local retirement.
```

Do not accept "yes", "go ahead", or an approval given for an earlier record.

## 7. Execute

For local retirement:

1. Create `Projects/_retired/<PROJECT>/` and move the whole project folder there.
2. Apply the pointer edits approved in step 4. No portfolio INDEX row exists in this kit;
   `Projects/README.md` is a convention file and is not edited for a retirement.
3. Run `workspace-sync.ps1 -Write` with the exact arguments from step 3. `_retired` starts with
   an underscore, so the mirror never sees it.

For hard delete, the same steps without the move. Say plainly in the report that the project
record is gone locally.

Do not commit or push either repository. Do not create a new log file.

## 8. Verify and report

- mirror `-Check` with the same arguments, exit 0
- kit `verify-all.ps1` and `census.ps1` clean
- no pointer resolves to the retired path
- private repository shows only the mirror changes, ready for a human to review and commit

Report the exact paths moved or removed, the mirror result, the pointers edited, and what was
deliberately not touched. Never claim an SAP system or MCP profile was removed — neither was.

## Stop conditions

Ambiguous target, missing folder, programs still present, existing retired folder, dirty mirror,
failing preflight, pointer choice not made, wrong confirmation token, or any request to touch SAP,
MCP config, or GitHub.
