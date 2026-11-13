# Projects — local record convention

**This folder is a notebook, not a boundary.** It does not select a SAP system, does not
restrict a tool, and is not read by VS Code or Copilot. A folder named `ABC` here has no
effect on which system a tool call reaches — see **Connections** in the root `AGENTS.md`.

Use it only to write down what you verified, so a later session does not have to rediscover
it. If it ever disagrees with the SAP system, the SAP system is right.

**Nothing under this folder is committed.** Project records carry customer identifiers
(SID, client, transport) and this repository is public. Only this `README.md` is tracked,
which also means project records have **no backup** unless you keep them somewhere else.

## Layout

```
Projects\
└── <PROJECT>\
    ├── README.md        verified facts for this project
    ├── project.yaml     the same facts, machine-readable
    ├── _archive\        retired work for this project
    ├── _sandbox\        scratch space, safe to delete
    └── <PROGRAM>\
        ├── README.md    verified facts for this object
        └── program.yaml
```

- `<PROJECT>` — uppercase project code, e.g. `ABC`.
- `<PROGRAM>` — the SAP object name, e.g. `ZMME011`.
- `_archive` and `_sandbox` are per project, underscore prefix, so they sort apart from
  real objects.
- No `AGENTS.md` at project or program level. The root `AGENTS.md` already states the
  access rules once, and a second copy would drift. This deliberately differs from the
  usual pattern of one `AGENTS.md` per level.

## Adding a project record

1. Create `Projects\<PROJECT>\`.
2. Copy `templates\project-README.md` to `Projects\<PROJECT>\README.md` and fill in only
   what you verified.
3. Create `project.yaml` from the block below.
4. Add a program folder for each object worth remembering, using
   `templates\program-README.md`.

## `project.yaml` — verified facts only

```yaml
project: <PROJECT>
system: <SID>              # verified from the SAP logon, not remembered
code_client: <client>      # ADT / development client
test_client: <client>      # SAP GUI client, if different
transport: <transport>     # current open request, or "none"
owner: <SAP user>
updated: <YYYY-MM-DD>
```

Leave a value empty rather than guessing. An empty field is honest; a wrong one causes a
wrong change in the wrong client.

## Pointers, not copies

A program README links to the deployed source, the builder, decisions, and the memory
card. It never pastes ABAP source — the SAP system owns that, and a pasted copy goes
stale silently.
