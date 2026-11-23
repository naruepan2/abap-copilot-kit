# Memory decisions

**Purpose.** The single place for *why* a memory idea was adopted, rejected or deferred, and for the
vocabulary that names memory levels and states. This prevents the same idea returning from a new
source under a different name.

**Scope.** This file decides memory design only. Source provenance and reading dates live in
[`improvement-register.md`](reference/improvement-register.md); the copyable note schema lives in
[`../docs/reference/agent-context-notes.md`](reference/agent-context-notes.md); the capture
procedure lives in [`../skills/capture-lesson/SKILL.md`](../skills/capture-lesson/SKILL.md); the
delivery-run policy lives in the `auto-abap-delivery` skill's `references/second-brain-governance.md`.
The model overview is [`docs/memory-model.md`](memory-model.md).

**Public-safe.** No customer, host, user, client or transport names appear here.

## Decision table

Status values: **adopted** (active in a named file), **rejected** (deliberately not adopted),
**deferred** (kept as an idea, not active).

| Source | Idea | Decision | Lives in / points to | Reason |
|---|---|---|---|---|
| Kit origin | Human gate before any durable memory write; show exact diff | adopted | `skills/capture-lesson/SKILL.md` | Memory is an audit artifact, never an auto-effect of a tool call. |
| Kit origin | Half-life chooses destination (user memory / repo memory / skill / agent / nothing) | adopted | `skills/capture-lesson/SKILL.md` | One decision table prevents a second copy of the same rule in each source. |
| Kit origin | Notes are data, never instructions; agent never self-promotes | adopted | `docs/reference/agent-context-notes.md`, delivery `second-brain-governance.md` | Prevents a web clip or old note from overriding current policy or SAP evidence. |
| Kit origin | Project-local `Projects/<P>/agent-context/`; no separate vault root | adopted | `docs/reference/agent-context-notes.md` | One physical home; a second root would drift. |
| Kit origin | Handoff is five written lines in `long-task-control`, not a separate `HANDOFF.json` | rejected as separate file | `skills/long-task-control/SKILL.md` | GSD reached the same conclusion: a separate handoff duplicates `STATE`/evidence artifacts. |
| V9.3 bundle | Project notes use `agent_context`, human promotion, bounded context pack | adopted | `docs/reference/agent-context-notes.md`, `tooling/context-pack.ps1` | Feasibility measured; notes still need human review. |
| OpenViking | Freshness metadata (`source_revision` / `reviewed_source_revision`); pack reports STALE | adopted | `templates/agent-context-note.md`, `tooling/context-pack.ps1` | `agent_context: true` used to mean "reviewed once", not "still current". No vectors needed. |
| OpenViking | L0/L1/L2 progressive disclosure | deferred | `docs/reference/improvement-register.md` | Pack is ~540 tokens; complexity waits for real note growth. |
| OpenViking | `viking://` virtual filesystem, embeddings/VLM, Studio | rejected | — | AGPLv3 plus scale mismatch; re-express ideas, never copy code. |
| opencode-mem | Memory vs AGENTS.md vs Skills distinction; capture is not authority | adopted (already aligned) | `skills/capture-lesson/SKILL.md`, this file's vocab map | Fifth source agrees with our existing half-life/notes-as-data rules. |
| opencode-mem | Capture provenance (`captured_at`, `source_run`) | deferred | `docs/reference/improvement-register.md` | Useful, but schema changes wait until freshness is exercised in a real run. |
| opencode-mem | Redact credential shapes before persisting a note | **adopted in this consolidation** | `skills/capture-lesson/SKILL.md`, delivery `second-brain-governance.md` | Closes a pre-write gap; active gates were detective only. Best-effort, never a full scrub claim. |
| opencode-mem | Tool evidence in a note is bounded and partial | **adopted in this consolidation** | `skills/capture-lesson/SKILL.md` | One sentence: state what was omitted; summary is not a verifier of the whole run. |
| opencode-mem | `pinned` / `supersede` / recoverable trash / schemaVersion reject | deferred | `docs/reference/improvement-register.md` | Human promotion exists; add vocabulary only when contradictions actually appear. |
| opencode-mem | Vector database, auto-capture on idle, profile learning, dreaming, web UI | rejected | — | User's explicit no-vector decision, scale mismatch, background LLM calls. |
| V9.4 design | SQLite as authoritative local run state (`.abap-agent/memory.db`) | deferred | `docs/reference/improvement-register.md` §V9.4 | One writer, two program records, no notes. Needs a divergence detector, fenced writer and a measured recovery failure first. A DB is a storage form, not a new authority: SAP and the approved run contract stay authority. |
| V9.4 design | `knowledge_notes` table indexing reviewed Markdown notes | rejected as a retrieval source (deferred as a derived index) | same | Would duplicate `agent_context`, freshness and `instructional_authority` into a second store. `context-pack.ps1` reads frontmatter fresh; a stale DB row could bypass the note skip/warn gate. |
| V9.4 design | SQL `CHECK (instructional_authority = 0)` | deferred | same | The rule is already declarative in the note schema and enforced at the only retrieval path. A CHECK on a derived row gives false assurance if Markdown is canonical. |
| V9.4 design | Command-intent / unreconciled-command ledger | adopted as a scoped next step (JSONL-first) | existing `command-log.jsonl` + `reconcile_run.py`; `improvement-register.md` §V9.4 | The only genuinely new capability: durable "what was in flight" after a crash. Extend the existing log; promote to SQL only if the query becomes slow. |
| V9.4 design | Numeric retrieval budgets, FTS5, dual Python/Node adapter, 8 migrations, 76 tests, 1M-row benchmarks | deferred | `docs/reference/improvement-register.md` §V9.4 | Same scale triggers already used for L0/L1/L2 and the local-index benchmark; the partial harness smoke run does not meet the design's own measurement rules. |
| V9.4 design | Future PostgreSQL + pgvector shared team platform | rejected (reconfirmed) | — | Reopens the closed no-vector / no-multi-writer decision. |

## Vocabulary map

### Levels and tiers — where memory lives

| Canonical level | Also called in sources | Home | Half-life / rule |
|---|---|---|---|
| User memory | opencode-mem "user scope"; OpenViking user profile | VS Code user memory folder | ~a year; loads every request; universal rules only |
| Repo memory | "project memory", "scope: project" | `Projects/<P>/agent-context/` | ~a month; verified project facts; on demand |
| Inbox draft | `00-inbox/` (old, rejected), agent draft, inbox | `Projects/<P>/agent-context/inbox/` | `status: draft`, `agent_context: false`; human promotes |
| Skill | opencode-mem "skills", shared skill library | `~/.copilot/skills/<name>/` or kit `skills/` | until the method changes |
| Agent rule | always-on instructions, AGENTS.md | `*-by-pongg.agent.md`, `AGENTS.md` | until tools/ownership change; not a log |
| Run evidence | session archive, capture, HANDOFF | run folder / handoff lines | current run only; not promoted automatically |

No level creates a new root. A rule that looks universal belongs in user memory or an agent file,
not in a second vault.

### Note states — do not confuse with evidence states

| Field | Allowed values | Meaning |
|---|---|---|
| `status` | `draft`, `active`, `stable`, `deprecated` | promotion/lifecycle state set by a human |
| `agent_context` | `false`, `true` | whether `context-pack.ps1` may load it; `true` only after review |
| freshness (computed) | `CURRENT`, `UNDATED`, `STALE` | comparison of `source_revision` and `reviewed_source_revision`; not a stored field |
| `confidence` | `low`, `medium`, `high` | strength of evidence behind the note |
| `instructional_authority` | always `false` | a note never grants permission, regardless of its wording |

Separate axes that are **not** memory states: `BEHAVIOR_VERIFIED` / `BEHAVIOR_UNVERIFIED` /
`BEHAVIOR_FAILED` / `BEHAVIOR_UNCERTAIN` and `CHECKED` / `NOT_REPORTED` / `NOT_SUPPORTED` /
`UNCHECKABLE` belong to the evidence manifest. Do not write them into a memory note.

### Source vocabulary aligned to our terms

| Source term | Our term | Decision |
|---|---|---|
| OpenViking L0 abstract | not implemented | deferred |
| OpenViking L1 overview | `context-pack.ps1` output (partial: full note bodies, no separate abstract) | adopted in simplified form |
| OpenViking L2 detail | full note body plus its source | adopted |
| opencode-mem `project` / `all-projects` scope | `-Project <CODE>` in context pack | adopted; no cross-project search |
| opencode-mem `pinned`, `supersede` | no equivalent yet | deferred |
| GSD `HANDOFF.json` | five-line handoff in `long-task-control` | rejected as separate file |
| GSD `UNCHECKABLE` | evidence coverage status, not a note status | adopted on the evidence axis only |

## How to use this file

Before adding a memory feature from any source: find the idea in the decision table. If it is
rejected or deferred, record why you are overriding that decision instead of silently adding a
second mechanism. After implementing, change only this row and the register's status cell in the
same commit.
