# Projects — local record convention

**This folder is a notebook, not a boundary.** It does not select a SAP system, does not
restrict a tool, and is not read by VS Code or Copilot. A folder named `ABC` here has no
effect on which system a tool call reaches — see **Connections** in the root `AGENTS.md`.

Use it only to write down what you verified, so a later session does not have to rediscover
it. If it ever disagrees with the SAP system, the SAP system is right.

**Nothing under this folder is committed.** Project records carry customer identifiers
(SID, client, transport), so they stay local regardless of repository visibility — a
visibility change must never be the only thing protecting a customer name. Only this
`README.md` is tracked, which also means project records have **no backup** unless you
keep them somewhere else.

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
        ├── program.yaml  facts + spec wiring
        └── spec\
            ├── INDEX.md      section map — read this, not the spec
            ├── notes.md      our questions and contradictions
            └── source\       the functional's file, untouched
```

- `<PROJECT>` — uppercase project code, e.g. `ABC`.
- `<PROGRAM>` — the SAP object name, e.g. `ZMME011`.
- `_archive` and `_sandbox` are per project, underscore prefix, so they sort apart from
  real objects.
- No `AGENTS.md` at project or program level. The root `AGENTS.md` already states the
  access rules once, and a second copy would drift. This deliberately differs from the
  usual pattern of one `AGENTS.md` per level.

## Specs — two modes, one rule

A functional specification is large and mostly irrelevant to the task at hand. A 400-line FS
costs ~4,000 tokens to read; a 1,700-line one costs ~22,000, which is three times the whole
agent. So the spec is **never** auto-loaded and **never** read whole.

| Mode | When | We own | File |
|---|---|---|---|
| `authored` | new program, no FS yet | the spec | `spec/INDEX.md` + `spec/spec.md` from `templates/spec.md` |
| `vendored` | a functional already wrote the FS | only the index | `spec/source/<FS>.md` untouched + `spec/INDEX.md` from `templates/spec-INDEX.md` |
| `none` | no spec exists | — | nothing; say so rather than inventing one |

`program.yaml` decides whether the spec is opened at all:

```yaml
spec_mode: vendored       # authored | vendored | none
spec_status: approved     # none | draft | approved | stale
spec_index: spec/INDEX.md
```

- `approved` — usable as the requirement.
- `draft` — readable, but confirm the acceptance criteria before treating it as settled.
- `stale` — do **not** use it to decide anything. The spec and the code disagree, or the
  document's own version metadata does not match the file. Ask, or derive the behaviour
  from the deployed code.

**Never edit anything under `spec/source/`.** It is the functional's document, versioned by
them. Contradictions go to `spec/notes.md`, and the fix is reported back to them.

**Never read the whole spec.** `INDEX.md` maps each section to a line range with its token
cost; read the Summary, then at most the one slice the task touches. If the spec's line or
byte count no longer matches the index, the index is stale — rebuild the map first, because
a stale range silently returns the wrong section.

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
