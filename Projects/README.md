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
        ├── changes.md    one row per activated change
        ├── .baseline\    pre-activation source, one file per object per TR
        └── spec\
            ├── INDEX.md      section map — read this, not the spec
            ├── notes.md      our questions and contradictions
            └── source\       the functional's file, untouched
```

- `<PROJECT>` — uppercase project code, e.g. `ABC`.
- `<PROGRAM>` — the SAP object name, e.g. `ZEXAMPLE01`.
- `_archive` and `_sandbox` are per project, underscore prefix, so they sort apart from
  real objects.
- No `AGENTS.md` at project or program level. The root `AGENTS.md` already states the
  access rules once, and a second copy would drift. This deliberately differs from the
  usual pattern of one `AGENTS.md` per level.

## Change history — the gap SAP leaves open

SAP keeps a version only when a transport is **released**. Between activating a change and
releasing its TR there is no rollback point at all — and that window is where nearly all work
happens. Two lightweight artifacts close it:

| Artifact | Purpose | Lifetime |
|---|---|---|
| `changes.md` | one row per activated change: intent, TR, TR state, objects, evidence | the life of the program |
| `.baseline/<OBJ>_<TR>.abap` | the active source captured **before the first activation** in that TR | deleted when the TR is released |

**Rollback authority is SAP, not these files.** When the TR is released, use
`SAPRead(type="VERSIONS")` and `VERSION_SOURCE` / `action="diff"`. The baseline exists only for
the window where SAP has nothing to offer.

Rules that keep it from rotting:

- **Write the row after activation succeeds**, never before — an earlier row is a plan.
- **Keep `TR state` honest.** A baseline marked `open` after the release becomes permanent by
  accident and nobody dares delete it. Update on the user's word, or when
  `SAPTransport(action="get")` reports `R`, then delete the baseline.
- **A baseline is "before", not "correct"** — it records what was there, not what should be.
- **`changes.md` never replaces verification.** It says what changed, not that the change is right.

Both live under `Projects/`, which is gitignored — so neither has a backup. That is deliberate:
they are working notes, and the durable record is SAP's own version history plus the TR.

## Who owns which fact

One fact, one file. A value copied down becomes a second copy that goes stale without anyone
noticing, so the split is deliberate:

| Fact | Owner | Because |
|---|---|---|
| `system`, `code_client`, `test_client`, `language` | **`project.yaml`** | one landscape per project |
| **`transport`** | **`program.yaml`** | two programs in one project are normally developed on different requests |
| `spec_mode`, `spec_status`, spec paths | `program.yaml` | the spec belongs to the object, not the project |

A program puts `project: <PROJECT>` and an **empty** `override:` block. It fills `override` only
when it genuinely differs from the project — never by copying the project's values down.

**A blank field is a pending question, not an answer.** A record may sit with `system:`,
`code_client:`, `test_client:`, and `owner:` empty until the SAP logon confirms them, or the user
states them. Fill them at logon, or ask — and never infer one to unblock a task. An empty field
that stays empty is correct; an empty field filled with a plausible guess is the failure this
whole structure exists to prevent.

## Scaffolding a new project or program

Load skill `sap-new-record`. It decides whether a record is needed, then routes to
`sap-new-project` or `sap-new-program`. The leaf skill asks only for missing values, scaffolds
from the templates, and verifies the result with `git check-ignore`.

The three situations it distinguishes, since they are worth knowing before you start:

| Check | Situation | What it needs |
|---|---|---|
| `Projects/<PROJECT>/` missing | new project | system + clients from the user |
| project exists, program folder missing | new program | inherits system + clients |
| record missing but the object is in SAP | missing record | record the facts; do not ask what to build |

It creates a record only when the object is about to be **created or changed**, or when you ask
for one. Read-only analysis leaves no trace — otherwise `Projects/` becomes a log.

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
them. Open questions, contradictions **and decisions** go to `spec/notes.md` — that is the one
home for "why", so no `reports/DECISIONS.md` is created beside it. Report the fix back to them.

**Never read the whole spec.** `INDEX.md` maps each section to a line range with its token
cost; read the Summary, then at most the one slice the task touches. If the spec's line or
byte count no longer matches the index, the index is stale — rebuild the map first, because
a stale range silently returns the wrong section.

## Asking about the spec — the file answers, not the user

`program.yaml` exists so nobody has to answer the same question twice. Reading it costs about
160 tokens and interrupts no one, so the agent reads it **silently** and only asks the user
when the file genuinely cannot answer:

- no `program.yaml` for this program (first time this object is worked on)
- `spec_status` missing or `draft`, and the task depends on the acceptance criteria
- more than one file under `spec/source/` could be the current one — then ask **which**, since
  that is the only thing the file cannot settle

Ask **once per program**, not once per task and not once per session. A new session is not a
reason to ask again: the file is the memory, and re-asking would make it pointless. Re-ask only
when the spec's line or byte count no longer matches `spec_index`, when the user says the spec
was updated, or when the work moves to a different program.

When asking, ask with options rather than open prose — "no spec yet / FS exists in
spec/source / FS is elsewhere and I will copy it in" — so the answer is one click.

## Adding a project record

Use skill `sap-new-project` — it runs this sequence with the verification included. The manual
steps, for reference:

1. Create `Projects\<PROJECT>\`.
2. Copy `templates\project.yaml` and fill in `system` and the clients from a verified source.
3. Copy `templates\project-README.md` to `Projects\<PROJECT>\README.md` and fill in only
   what you verified.
4. Add a program folder for each object you will create or change, using
   `templates\program-README.md` and `templates\program.yaml`.

## `project.yaml` — verified facts only

```yaml
project: <PROJECT>
system: <SID>              # verified from the SAP logon, not remembered
code_client: <client>      # ADT / development client
test_client: <client>      # SAP GUI client, if different
language: <EN>
owner: <SAP user>
updated: <YYYY-MM-DD>
```

No `transport` here — that belongs to each program.

Leave a value empty rather than guessing. An empty field is honest; a wrong one causes a
wrong change in the wrong client.

## Pointers, not copies

A program README links to the deployed source, the builder, decisions, and the memory
card. It never pastes ABAP source — the SAP system owns that, and a pasted copy goes
stale silently.
