# Improvement register

**Purpose.** One place to record ideas harvested from external systems, what was actually done with
them, and what is still open. An AI asked to "improve the kit" must read this file first so the work
continues from decisions already made instead of re-discovering them.

**Status:** working document, 2026-11-25. This file is the single intake register: it is read
before any kit/agent/skill improvement, as wired in `AGENTS.md` session start. Update the status
cell **in the same commit** as the change that implements or rejects an idea. This file is a
register, not policy: a rule that appears only here is not active. Policy lives in the agent,
skill and gate files named in each row.

**Public-safe:** this file names public repositories, kit paths and generic techniques. It never
names a customer, host, SAP user, client, transport or private run folder.

**Memory decisions have a second, narrower view:** [`../memory-decisions.md`](../memory-decisions.md)
records *why* a memory idea was adopted/rejected/deferred and aligns vocabulary across sources.
This register stays the record of *what was read* and the status of every idea. The model overview
is [`../memory-model.md`](../memory-model.md). Do not maintain two copies of a decision.

## Evidence tiers

| Mark | Meaning |
|---|---|
| `APPLIED` | Implemented in the named policy file; kit commit hash given |
| `APPLIED-UNCOMMITTED` | Implemented in the live file and backup snapshot, but not yet committed |
| `PENDING` | Accepted as worth doing, not implemented |
| `DEFERRED` | Worth keeping with a measurable trigger; not active until that trigger occurs |
| `REJECTED` | Considered and deliberately not adopted; reason recorded |
| `IDEA` | Not yet evaluated; no action implied. `UNVERIFIED` license or an unread source stays here |

These are **idea statuses**, not evidence states (`BEHAVIOR_*`) and not memory-note states
(`status`, `freshness`). Never promote `IDEA` to policy by repetition. Promotion needs an
implementation plus a test or a gate result; `APPLIED (this commit)` is not reproducible and must
be replaced with a hash.

## Sources read

| Source ID | What it is + revision reviewed | License | Read on / last checked | Evidence basis / scope NOT read | Re-read trigger |
|---|---|---|---|---|---|
| V9.3-bundle | Local design bundle: docs, skills, schemas, validators, exercise evidence; version stated as V9.3, no upstream revision | local design, provenance not asserted | 2026-11-22; last checked same | All files read, duplicate hashes checked. NOT read: two ZIPs claimed in README but absent from the extracted bundle | New local bundle or an incident contradicts a rule |
| abap-skills | 17 composable ABAP skills, `likweitan/abap-skills`; upstream commit UNVERIFIED | MIT | 2026-11-22; last checked same | All text files read in full. NOT read as prose: 129 SVG icons and the 4.7 MB `AppList.json` (data assets) | Upstream tag/commit change; version-sensitive claim needed |
| gsd-core | Meta-prompting / spec-driven phase loop; `@opengsd/gsd-core` v1.23.0 (user also writes `open-gsd/gsd-core` — identity UNVERIFIED) | MIT | 2026-11-23; last checked same | README, context-engineering explanation, ADR-22, ADR-1671, `gsd-verifier.md`, temporal-context note. NOT read in full: large test tree (test names only) | Upstream version change |
| openviking | Context database: virtual filesystem, L0/L1/L2, retrieval, session memory; revision UNVERIFIED | **AGPLv3** | 2026-11-23; last checked same | README + concept docs 03/07/08 read in full. NOT read: implementation tree (~6k files). Code must never be copied | Upstream version change; license re-check |
| opencode-mem | Persistent-memory plugin; Turso/libSQL + vectors, markdown vault, capture/hygiene; revision UNVERIFIED | MIT | 2026-11-23; last checked same | README read in full from GitHub. NOT considered: vector/embedding infrastructure | Upstream version change |
| V9.4-design | Local experimental design: 1,080-line master + 58-line traceability addendum + partial benchmark harness | local design, provenance not asserted | 2026-11-23; last checked 2026-11-25 | Both documents read in full; harness and smoke result inspected. NOT built: migrations 002-008, adapters, validators, full test matrix | A measured trigger in `derived-index-design.md` fires |

License consequence: ideas from MIT sources may be re-implemented freely; **do not copy OpenViking
code**. Re-express the idea in our own words, as with the other sources. An `UNVERIFIED` license
keeps the source at `IDEA` with no policy home. Use the Source ID in idea rows; add a source row
only for genuinely new provenance, never for an alias of an existing row. A version change updates
the **same** row's revision/checked fields and only opens a new idea row if the diff changes a rule.

Re-checked 2026-11-25: `JuliusBrussee/caveman` (upstream v4.2.0 / main `47c61be`,
2026-11-24), `DietrichGebert/ponytail` (v5.3.3 / main `ebd8654`, 2026-11-22) and
`mattpocock/skills` (v1.3.2 / main `d653911`, 2026-11-24). Verified by byte-level comparison of
every installed `SKILL.md`, supporting reference and `agents/openai.yaml` against upstream main:
ponytail and mattpocock files are identical; caveman differs only by the locally added
`disable-model-invocation: true`. No skill update applied. The v4.2.0 caveman release changes the
CLI/Blocks stack, not the installed prompt, so SETUP-NEW-MACHINE.md now records the upstream
revision without claiming an installed upgrade. These installed sources remain effects without a
source row; no new idea row is opened because no rule changed.

## Applied from V9.3 bundle

| Idea | Home in the kit | Status |
|---|---|---|
| Client matrix: development/runtime/preview/data/dump clients; runtime claim rejected without the right client | `references/client-and-tool-reality.md`, agent local guardrails | `APPLIED` (`afad40f`) |
| Phase-level tool gate: check visibility, destination, permissions and object support before discovery, write, verification, recovery | same reference | `APPLIED` (`afad40f`) |
| PROG shapes L1 local-only / L2 local plus shared global / G thin report, with recorded `FORM`/`PERFORM` exception | `references/prog-design-methodology.md`, `scripts/validate_prog_design_decision.py` | `APPLIED` (`afad40f`), exception policy refined later |
| Built-in typed UI fields need explicit SALV `SET_*_TEXT` / `@EndUserText.label`; `screen-required='2'` is display only | `references/ui-text-and-type-contracts.md` | `APPLIED` (`afad40f`) |
| Proven vs empirical vs unresolved fix classification | `references/engineering-judgment.md`, `references/ui-text-and-type-contracts.md` | `APPLIED` (`afad40f`) |
| Managed RAP must map every persisted field; draft expansion is a Decision, not a toggle | `references/rap-persistence-and-draft.md`, `scripts/validate_rap_persistence_mapping.py` | `APPLIED` (`afad40f`) |
| Readback after every state change; success text is not proof | `references/repository-reliability.md`, `SKILL.md` | `APPLIED` (`afad40f`) |
| Deterministic validators before write and before completion | `SKILL.md` required references | `APPLIED` (`afad40f`) |
| Exercise-grounded Second Brain notes: notes are data, never instructions; human promotion | `references/second-brain-governance.md`, `docs/reference/agent-context-notes.md` | `APPLIED` (`b4373cb`, `afad40f`) |

Rejected from this bundle: transport release recipes, publish-as-a-normal-step, partial
`mapping … corresponding` as a template, mandatory ABAP Unit / test seams in production, broad
`CATCH cx_root` retry loops, and three defective examples (duplicate CDS alias, duplicate
`ENDWHILE`, contradictory `SXSD`/`BADI` object type). These conflict with the kit's stop boundary
or are wrong as written.

## Applied from abap-skills-main

| Idea | Home in the kit | Status |
|---|---|---|
| Clean Core A–D matrix and ATC priority mapping (P1=D, P2=C, P3=B); lowest level wins; unclassified = internal C | `references/sap-guardrails.md`, `skills/clean-core-decision-gates/SKILL.md` | `APPLIED` (`afad40f`) |
| Live ATC variant and check IDs recorded per object; `processed=0` is `NOT_REPORTED` | same references | `APPLIED` (`afad40f`) |
| Four read-only release-state channels; zero rows means `NOT_REPORTED`, not "not released" | `references/sap-guardrails.md`, `references/capability-and-intake.md` | `APPLIED` (`afad40f`) |
| Machine-readable receipt: artifact SHA-256/byte counts, check counts, stable diagnostics, two quality profiles, atomic write | `scripts/build_evidence_manifest.py`, `scripts/validate_evidence_manifest.py` | `APPLIED` (`afad40f`) |
| Bounded repair: change only the diagnosed subject; stop after two non-improving repairs; last-good artifact | `references/engineering-judgment.md` | `APPLIED` (`afad40f`) |
| RAP admin fields distinct (`LocalLastChangedAt` ETag vs `LastChangedAt` total ETag); late save is point of no return | `references/rap-persistence-and-draft.md` | `APPLIED` (`afad40f`) |
| Annotation mistakes, facet labels, negative authorization at binding/IAM layer | `references/ui-text-and-type-contracts.md`, `references/evidence-and-uat.md` | `APPLIED` (`afad40f`) |
| Test-double vocabulary and prohibition on permanent test drivers | `references/team-and-testing.md` | `APPLIED` (`afad40f`) |
| Skill evals: one in-scope and one boundary case per skill | `evals/evals.json` for `auto-abap-delivery`; census reason in `tooling/census.ps1` | `APPLIED` (`afad40f`) |

## Applied from GSD Core

| Idea | Home in the kit | Status |
|---|---|---|
| Behavior verification as a separate axis from check states: `BEHAVIOR_VERIFIED`, `BEHAVIOR_UNVERIFIED`, `BEHAVIOR_FAILED`, `BEHAVIOR_UNCERTAIN` | `references/evidence-and-uat.md`, `scripts/validate_evidence_manifest.py` | `APPLIED` (`182c976`) |
| `coincidental_reliance` advisory with three details (`undeclared-precondition`, `incidental-ordering`, `fixture-only`); advisory only, no score change | same files | `APPLIED` (`182c976`) |
| Verification coverage block: every check that did not produce a result is named with status, reason and disposition; `READY_FOR_UAT` requires dispositions | `scripts/build_evidence_manifest.py`, `scripts/validate_evidence_manifest.py`, `SKILL.md` | `APPLIED` (`182c976`) |
| Agent upgrade: no pinned `tools:` list, reasoning effort preference, restricted subagents, handoffs, deterministic `PreToolUse` gate | `~/.copilot/agents/abap-auto-delivery-by-pongg.agent.md`, `tooling/aad_write_gate.py` | `APPLIED` (`02c2b57`) |
| README rewritten to match current structure (two agents, inline gate, profile-scoped MCP config) | `README.md` | `APPLIED` (`02c2b57`) |

GSD mechanisms deliberately **not** imported: fresh-context 200k subagents, worktrees, phase loop,
`.planning/` state tree, per-runtime hook matrix, byte-cap ratchet. Scale mismatch. GSD's rejection
of a separate `HANDOFF.json` supports our choice of a written handoff in `long-task-control` and
reviewed notes in `agent-context/`.

## Open ideas from OpenViking

| Idea | Kit analogue | Status | Why / next step |
|---|---|---|---|
| Freshness metadata on notes: `source_revision`/`reviewed_source_revision`, pack marks a note `STALE` if source changed after review | `templates/agent-context-note.md`, `docs/reference/agent-context-notes.md`, `tooling/context-pack.ps1` | `APPLIED` (`9f95178`) | `agent_context: true` used to mean "reviewed once", not "still current". Pack now reports `CURRENT`/`UNDATED`/`STALE`, warns, and places stale notes last. No embedding or VLM needed. |
| L0/L1/L2 progressive disclosure: one-sentence abstract in note, pack loads abstracts by default and full bodies with `-Full` | `tooling/context-pack.ps1` | `PENDING` (defer) | Pack is only ~540 tokens in the measured fixture. Add complexity only when notes actually grow. |
| Scoped `find` vs context-aware `search` at note level | `context-pack.ps1 -Project -AppliesTo` | `PENDING` (defer) | Folder scoping already exists; a `-Query` filter over abstracts can come later without LLM intent analysis. |

Not imported: `viking://` virtual filesystem, vectors, VLM, session→memory LLM extraction, Studio UI.
AGPLv3 plus scale mismatch.

## Ideas from opencode-mem (long-term memory without vectors)

All rows are `PENDING` until a separate decision implements them. The capture pipeline, user-profile
learning, Turso/libSQL, embeddings, dreaming and web UI are out of scope.

| Idea | Kit analogue | Status | Why / next step |
|---|---|---|---|
| Distinguish memory from AGENTS.md and Skills; capture is not authority; summaries must separate plans, attempts, failures, observed results and unverified claims | `docs/memory-decisions.md`, `skills/capture-lesson/SKILL.md`, behavior axis in evidence manifest | `APPLIED` (`9f95178`) | Already aligned; `memory-decisions.md` now records the fifth source that agrees. No behavior change. |
| Capture provenance on each note: which session/run produced it and when (`captured_at`, `source_run`) | `templates/agent-context-note.md`, `docs/reference/agent-context-notes.md` | `PENDING` | Makes the new freshness pair meaningful (which run reviewed which source revision). Fits `Seen`/`Last confirmed` in capture-lesson. |
| Redact credential shapes at the write boundary, before a lesson/memory is persisted; `<private>` regions fail closed | `skills/capture-lesson/SKILL.md`, delivery `references/second-brain-governance.md` | `APPLIED` (`9f95178`) | Closes a pre-write gap; gates were detective only. Best-effort, never a full secret scrub claim. |
| Tool evidence in a note is bounded and partial: state omissions; a model summary is not a verifier | `skills/capture-lesson/SKILL.md`, behavior/coverage axes | `APPLIED` (`9f95178`) | `capture-lesson` now says evidence is a sample and omissions must be stated. Complements `coincidental_reliance`. |
| Hygiene vocabulary: `pinned` notes never auto-edited, `status: deprecated` names `superseded_by`, soft-delete recoverable, imports reject newer `schemaVersion` rather than guessing | `references/second-brain-governance.md`, note frontmatter | `PENDING` (lower priority) | Human promotion already exists; add vocabulary only when contradictions actually appear. Do not copy the background LLM consolidation. |

Not imported: local vector search, Turso shards, auto-capture on idle, profile learning, dreaming
consolidation via LLM, web UI, API tokens. Scale and the user's explicit no-vector decision.

## Reviewed from V9.4 Embedded SQL Memory Layer (2026-11-23)

Five read-only analysis teams (idea, memory, delivery, safety, scale) reviewed the design. Verdict:
**keep experimental, revise rather than redesign.** Most of its ideas are existing kit rules in SQL
form; its 8 migrations, 76 tests and 1M-row benchmark profiles are sized for a multi-user platform,
while this kit has one writer, two program records and no agent-context notes. Full decision
rationale is in [`../memory-decisions.md`](../memory-decisions.md).

| Idea | Status | Why / next step |
|---|---|---|
| Unreconciled command-intent ledger (`command_id`, status enum, partial index) for restart recovery | `APPLIED` (`462af99`) — JSONL-first | Genuinely new: after a crash we could not tell "action sent, outcome unknown" from "never sent". `scripts/command_intent.py` appends intent/status events to the existing `command-log.jsonl`, lists open commands with a fail-closed detector, and is exercised by verify-all §5e. No DB, migration or FTS. SQL remains deferred until the query is too slow. |
| SQLite as authoritative run state, `.abap-agent/memory.db` at project root | `DEFERRED` | Only a store form, not new semantics. Requires a Markdown↔index divergence detector, fail-closed rebuild and a fenced single writer first. Recorded scale trigger: a real recovery failure or measured query cost, not the design's SLO table. |
| `knowledge_notes` table as an index of reviewed notes | `DEFERRED` | Would create a second source of truth for `agent_context`, freshness and `instructional_authority`; `context-pack.ps1` parses frontmatter fresh and has nothing to diverge today. Revisit only when a real note corpus exists and divergence detection is implemented. |
| Numeric retrieval budgets (200/50/12 notes, 120 KB) and FTS5 ranking | `DEFERRED` | ~220× the measured ~540-token pack; same reason L0/L1/L2 was deferred. FTS only after the design's own trigger (>5,000 notes or 25,000 chunks). |
| Schema-enforced `instructional_authority = 0` SQL CHECK | `DEFERRED` | Redundant while Markdown is canonical and `context-pack.ps1` skips such notes. Keep as an invariant only if a DB becomes a retrieval source. |
| Evidence metadata fields `source_hash`, `spec_hash`, `tool_profile_hash`, `expires_at` | `DEFERRED` | Evidence manifest 1.1 already has per-artifact SHA-256, behavior/coverage axes and freshness prose. Add fields only after a freshness incident. |
| Python writer + Node read-only dual adapter, migration checksum chain, 76-test matrix, 1M-row benchmark profiles | `DEFERRED` | Scale mismatch and unmet prerequisites: the local harness has 1 SQL file, 8 tables and one smoke run; its config uses 2 warmups/5 iterations against a required ≥5/≥30. |
| Future PostgreSQL + pgvector "shared team platform" | `REJECTED` (reconfirmed) | Reopens the decision already closed by the explicit no-vector and no-multi-writer policy; multi-writer is `PENDING / not qualified` in the register. |
| Commit "sanitized evidence summaries" containing `system_id`, client, `file_path`, hashes | `REJECTED` | Would commit exactly the identifier join that §9c of `verify-all.ps1` exists to prevent. Only schema DDL with placeholders and synthetic benchmark config may be tracked. |
| `OWNER_ACTION_REQUIRED` as a blocking status, or owner approval for migrations during a run | `DEFERRED` with constraint | If ever implemented, define it as a terminal handoff for a genuine decision boundary only, and restrict migrations to initialization. A mid-run gate would break Unattended's "approve once, run to gate" contract. The separate approval-card design stays `IDEA` and is not imported here. |

## Open items from earlier work (still valid)

These are not from the source tables above; they are carried forward so they are not lost.

| Item | Status | Reference |
|---|---|---|
| Formal local-index benchmark with a blind agent; current state is dry-run plus guardrails | `INCOMPLETE` — preflight 2026-11-23, 0/24 tasks measured (no SAP tools, no confirmed target, blank gold set, no index to test) | `docs/reference/coedit-index-benchmark-plan.md`; verdict in `docs/reference/coedit-gap-closure.md` §5.11 |
| `activated` hash plus `force_refresh` probe | `UNVERIFIED` | `docs/reference/coedit-gap-closure.md` |
| Approval card + disabled comment blocks (two axes: write mode apply/blocks/save-only, activation strategy groups/selected/defer). Comment blocks are themselves writes (fresh read + hash + read-back); only `INSERT_AFTER` is uncommentable; DDLS/BDEF `//` syntax still `UNVERIFIED`. Not wired into any agent or skill, and it is a human gate, so it conflicts with Unattended — adopting it would mean an explicit attended/deferred run, never a global ask-before-fix rule. | `IDEA` — designed 2026-11-19, not implemented | `docs/reference/coedit-gap-closure.md` §5.12, `docs/reference/coedit-comment-block-syntax.md` |
| Cross-harness ledger, graph server and T3 multi-writer | `PENDING` / not qualified | same |
| `agents/abap-developer-by-pongg.agent.md` mojibake reported by git diff | `RESOLVED` | Bytes were verified `E2 80 94` (valid UTF-8 em dash) in working tree and live profile; the mojibake was a PowerShell pipe display artifact, not file corruption. The diff is a real tools-unpin plus Fast-path addition and is safe to commit. |

## How to maintain this register

1. **Check aliases before adding.** Search this file and `docs/memory-decisions.md` for the idea
   under every known name. An existing row is updated in place; a second row is a defect. Add a
   source row only for genuinely new provenance, not for another name for a source already here.
2. When an idea is implemented, change only its status cell and add the **kit commit hash**. Do not
   move the rule text here; the rule stays in its one home in an agent, skill or gate file.
3. When an idea is rejected or deferred, record the reason and, for `DEFERRED`, the measurable
   trigger. Do not delete it — the next reviewer will otherwise re-propose it.
4. When an upstream version changes, update the **same** source row's revision, last-checked date,
   evidence basis and scope-not-read. Open a new idea row only if the diff changes a rule.
5. `UNVERIFIED` license or model recollection stays at `IDEA` with no policy home; "I heard/saw
   somewhere" is not an evidence basis.
6. Before proposing a change, check the `Not imported` blocks. Most bad proposals fail there.
7. Keep public-safe. If a detail needs a customer, host, user, client or transport, it belongs in a
   gitignored project file, not here.
