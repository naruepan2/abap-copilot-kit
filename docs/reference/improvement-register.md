# Improvement register

**Purpose.** One place to record ideas harvested from external systems, what was actually done with
them, and what is still open. An AI asked to "improve the kit" must read this file first so the work
continues from decisions already made instead of re-discovering them.

**Status:** working document, 2026-11-23. Update the status cell **in the same commit** as the change
that implements or rejects an idea. A rule that appears only here is not active — this file is a
register, not policy. Policy lives in the agent, skill and gate files named in each row.

**Public-safe:** this file names public repositories, kit paths and generic techniques. It never
names a customer, host, SAP user, client, transport or private run folder.

**Memory decisions have a second, narrower view:** [`../memory-decisions.md`](../memory-decisions.md)
records *why* a memory idea was adopted/rejected/deferred and aligns vocabulary across sources.
This register stays the record of *what was read* and the status of every idea. The model overview
is [`../memory-model.md`](../memory-model.md). Do not maintain two copies of a decision.

## Evidence tiers

| Mark | Meaning |
|---|---|
| `APPLIED` | Implemented in the named kit file; commit hash given where known |
| `APPLIED-UNCOMMITTED` | Implemented in the live file and backup snapshot, but not yet committed |
| `PENDING` | Accepted as worth doing, not implemented |
| `REJECTED` | Considered and deliberately not adopted; reason recorded |
| `IDEA` | Not yet evaluated; no action implied |

Never promote `IDEA` to policy by repetition. Promotion needs an implementation plus a test or a
gate result.

## Sources read

| Source | What it is | License | Read on | Evidence basis |
|---|---|---|---|---|
| Auto ABAP Delivery V9.3 bundle | Local bundle of design docs, skills, schemas, validators and exercise evidence | bundled, provenance not asserted | 2026-11-22 | All files read; duplicate hashes checked; two ZIPS claimed in README but absent from the extracted bundle |
| `abap-skills-main` | 17 composable ABAP skills; upstream `likweitan/abap-skills` | MIT | 2026-11-22 | All text files read in full; 129 SVG icons and the 4.7 MB `AppList.json` treated as data assets, not prose |
| GSD Core (`gsd-core-next`) | Meta-prompting / spec-driven phase loop with fresh-context subagents; `@opengsd/gsd-core` v1.23.0 | MIT | 2026-11-23 | README, context-engineering explanation, ADR-22 drift guard, ADR-1671 size budget, `gsd-verifier.md`, out-of-scope temporal-context read in full; test names used as signal across the large test tree |
| OpenViking (`OpenViking-main`) | Context database for agents; virtual filesystem, L0/L1/L2 layers, retrieval and session memory | **AGPLv3** | 2026-11-23 | README, concept docs 03 (context layers), 07 (retrieval), 08 (session) read in full; implementation tree (~6k files) not read wholesale |
| `opencode-mem` (`tickernelz/opencode-mem`) | Persistent-memory plugin for coding agents; Turso/libSQL + vectors, markdown vault backend, capture/hygiene/redaction rules | MIT | 2026-11-23 | README read in full from GitHub; vector/embedding infrastructure deliberately excluded from consideration |
| V9.4 Embedded SQL Memory Layer | Local experimental design: 1,080-line master + 58-line test-traceability addendum + a partial local benchmark harness | local design, provenance not asserted | 2026-11-23 | Both documents read in full; harness files and smoke result inspected by the analysis teams. No V9.4 machinery was implemented or promoted. |

License consequence: ideas from MIT sources may be re-implemented freely; **do not copy OpenViking
code**. Re-express the idea in our own words, as with the other sources.

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
| Behavior verification as a separate axis from check states: `BEHAVIOR_VERIFIED`, `BEHAVIOR_UNVERIFIED`, `BEHAVIOR_FAILED`, `BEHAVIOR_UNCERTAIN` | `references/evidence-and-uat.md`, `scripts/validate_evidence_manifest.py` | `APPLIED` (this commit) |
| `coincidental_reliance` advisory with three details (`undeclared-precondition`, `incidental-ordering`, `fixture-only`); advisory only, no score change | same files | `APPLIED` (this commit) |
| Verification coverage block: every check that did not produce a result is named with status, reason and disposition; `READY_FOR_UAT` requires dispositions | `scripts/build_evidence_manifest.py`, `scripts/validate_evidence_manifest.py`, `SKILL.md` | `APPLIED` (this commit) |
| Agent upgrade: no pinned `tools:` list, reasoning effort preference, restricted subagents, handoffs, deterministic `PreToolUse` gate | `~/.copilot/agents/abap-auto-delivery-by-pongg.agent.md`, `tooling/aad_write_gate.py` | `APPLIED` (`02c2b57`) |
| README rewritten to match current structure (two agents, inline gate, profile-scoped MCP config) | `README.md` | `APPLIED` (`02c2b57`) |

GSD mechanisms deliberately **not** imported: fresh-context 200k subagents, worktrees, phase loop,
`.planning/` state tree, per-runtime hook matrix, byte-cap ratchet. Scale mismatch. GSD's rejection
of a separate `HANDOFF.json` supports our choice of a written handoff in `long-task-control` and
reviewed notes in `agent-context/`.

## Open ideas from OpenViking

| Idea | Kit analogue | Status | Why / next step |
|---|---|---|---|
| Freshness metadata on notes: `source_revision`/`reviewed_source_revision`, pack marks a note `STALE` if source changed after review | `templates/agent-context-note.md`, `docs/reference/agent-context-notes.md`, `tooling/context-pack.ps1` | `APPLIED` (this commit) | `agent_context: true` used to mean "reviewed once", not "still current". Pack now reports `CURRENT`/`UNDATED`/`STALE`, warns, and places stale notes last. No embedding or VLM needed. |
| L0/L1/L2 progressive disclosure: one-sentence abstract in note, pack loads abstracts by default and full bodies with `-Full` | `tooling/context-pack.ps1` | `PENDING` (defer) | Pack is only ~540 tokens in the measured fixture. Add complexity only when notes actually grow. |
| Scoped `find` vs context-aware `search` at note level | `context-pack.ps1 -Project -AppliesTo` | `PENDING` (defer) | Folder scoping already exists; a `-Query` filter over abstracts can come later without LLM intent analysis. |

Not imported: `viking://` virtual filesystem, vectors, VLM, session→memory LLM extraction, Studio UI.
AGPLv3 plus scale mismatch.

## Ideas from opencode-mem (long-term memory without vectors)

All rows are `PENDING` until a separate decision implements them. The capture pipeline, user-profile
learning, Turso/libSQL, embeddings, dreaming and web UI are out of scope.

| Idea | Kit analogue | Status | Why / next step |
|---|---|---|---|
| Distinguish memory from AGENTS.md and Skills; capture is not authority; summaries must separate plans, attempts, failures, observed results and unverified claims | `docs/memory-decisions.md`, `skills/capture-lesson/SKILL.md`, behavior axis in evidence manifest | `APPLIED` (this consolidation) | Already aligned; `memory-decisions.md` now records the fifth source that agrees. No behavior change. |
| Capture provenance on each note: which session/run produced it and when (`captured_at`, `source_run`) | `templates/agent-context-note.md`, `docs/reference/agent-context-notes.md` | `PENDING` | Makes the new freshness pair meaningful (which run reviewed which source revision). Fits `Seen`/`Last confirmed` in capture-lesson. |
| Redact credential shapes at the write boundary, before a lesson/memory is persisted; `<private>` regions fail closed | `skills/capture-lesson/SKILL.md`, delivery `references/second-brain-governance.md` | `APPLIED` (this consolidation) | Closes a pre-write gap; gates were detective only. Best-effort, never a full secret scrub claim. |
| Tool evidence in a note is bounded and partial: state omissions; a model summary is not a verifier | `skills/capture-lesson/SKILL.md`, behavior/coverage axes | `APPLIED` (this consolidation) | `capture-lesson` now says evidence is a sample and omissions must be stated. Complements `coincidental_reliance`. |
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
| Unreconciled command-intent ledger (`command_id`, status enum, partial index) for restart recovery | `APPLIED` (this commit) — JSONL-first | Genuinely new: after a crash we could not tell "action sent, outcome unknown" from "never sent". `scripts/command_intent.py` appends intent/status events to the existing `command-log.jsonl`, lists open commands with a fail-closed detector, and is exercised by verify-all §5e. No DB, migration or FTS. SQL remains deferred until the query is too slow. |
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

These are not from the four external sources; they are carried forward so they are not lost.

| Item | Status | Reference |
|---|---|---|
| Formal local-index benchmark with a blind agent; current state is dry-run plus guardrails | `PENDING` | `docs/reference/coedit-index-benchmark-plan.md` |
| `activated` hash plus `force_refresh` probe | `UNVERIFIED` | `docs/reference/coedit-gap-closure.md` |
| Approval card + disabled comment blocks (two axes: write mode apply/blocks/save-only, activation strategy groups/selected/defer). Comment blocks are themselves writes (fresh read + hash + read-back); only `INSERT_AFTER` is uncommentable; DDLS/BDEF `//` syntax still `UNVERIFIED`. Not wired into any agent or skill, and it is a human gate, so it conflicts with Unattended — adopting it would mean an explicit attended/deferred run, never a global ask-before-fix rule. | `IDEA` — designed 2026-11-19, not implemented | `docs/reference/coedit-gap-closure.md` §5.12, `docs/reference/coedit-comment-block-syntax.md` |
| Cross-harness ledger, graph server and T3 multi-writer | `PENDING` / not qualified | same |
| `agents/abap-developer-by-pongg.agent.md` mojibake reported by git diff | `RESOLVED` | Bytes were verified `E2 80 94` (valid UTF-8 em dash) in working tree and live profile; the mojibake was a PowerShell pipe display artifact, not file corruption. The diff is a real tools-unpin plus Fast-path addition and is safe to commit. |

## How to maintain this register

1. When an idea is implemented, change only its status cell and add the commit hash. Do not move the
   rule text here; the rule stays in its one home in an agent, skill or gate file.
2. When an idea is rejected, record the reason in one line. Do not delete it — the next reviewer
   will otherwise re-propose it.
3. When reading a new external system, add a source row with license and evidence basis before
   adding idea rows. "I heard/saw somewhere" is not an evidence basis.
4. Before proposing a change, check the `Not imported` blocks. Most bad proposals fail there.
5. Keep public-safe. If a detail needs a customer, host, user, client or transport, it belongs in a
   gitignored project file, not here.
