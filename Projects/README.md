# Projects

Local working area. **Nothing under this folder is committed** — project files carry
customer identifiers (SID, client, transport numbers) and this repository is public.
Only this `README.md` is tracked.

## Layout

```
Projects\
└── <PROJECT>\
    ├── AGENTS.md
    ├── project.yaml
    ├── README.md
    ├── _archive\        retired work for this project
    ├── _sandbox\        scratch space, safe to delete
    └── <PROGRAM>\
        ├── AGENTS.md
        ├── program.yaml
        └── README.md
```

- `<PROJECT>` — uppercase project code, e.g. `ABC`.
- `<PROGRAM>` — the SAP object name, e.g. `ZMME011`.
- `_archive` and `_sandbox` are per project, underscore prefix, so they sort apart from
  real objects.
- No portfolio-level `_archive` until a whole project is retired.

## Adding a project

1. Create `Projects\<PROJECT>\`.
2. Copy `templates\project-README.md` to `Projects\<PROJECT>\README.md` and fill it in.
3. Create `project.yaml` with the verified system facts (see below).
4. Add `AGENTS.md` — copy the Access and Session start blocks from the root `AGENTS.md`
   and change `scope:` to `project`.
5. Add each program the same way, using `templates\program-README.md`, with
   `scope: program`.

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
