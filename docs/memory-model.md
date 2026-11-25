# Memory model

This kit has one memory model. Its purpose is continuity with evidence, not a second brain that
silently becomes authority.

## What counts as memory

| Layer | Home | Who reads it |
|---|---|---|
| User memory | VS Code user memory folder | loaded on every request |
| Repo memory / project notes | `Projects/<P>/agent-context/` | on demand, through `tooling/context-pack.ps1` |
| Drafts | `Projects/<P>/agent-context/inbox/` | agent writes; human reviews |
| Run evidence | run folder | current run and UAT handoff |
| Skills and agent rules | `skills/`, `~/.copilot/agents/*-by-pongg.agent.md` | on invocation or when always-on |

SAP and the approved run contract are authority. A note is data: it never grants permission, never
overrides a gate, and cannot promote itself to policy. See
[`reference/agent-context-notes.md`](reference/agent-context-notes.md) for the note schema and
freshness rule, and [`../skills/capture-lesson/SKILL.md`](../skills/capture-lesson/SKILL.md) for the
capture procedure.

## One home per decision

- **External-source intake, source provenance and idea status:** [`reference/improvement-register.md`](reference/improvement-register.md).
  It is read before any kit/agent/skill improvement (`AGENTS.md` session start).
- **Why an idea was adopted, rejected or deferred:** [`memory-decisions.md`](memory-decisions.md).
  This is the vocabulary map; it holds rationale only, never a second status column.
- **What external source was read:** [`reference/improvement-register.md`](reference/improvement-register.md).
- **How notes are written and promoted:** `reference/agent-context-notes.md`.
- **How a finding is captured:** `skills/capture-lesson/SKILL.md`.
- **How a long task survives compaction:** `skills/long-task-control/SKILL.md`.
- **How the snapshot is backed up:** `backup/README.md` and `skills/kit-backup/SKILL.md`.

No `vault/`, `memory/` at repo root, or second inbox name. If a new source proposes one, add a row
to `memory-decisions.md` instead of creating the folder.
