# Idea handoff — continuity when the AI model changes

Status: handoff note, 2026-11-25. This is a **map and a reasoning record**, not a second decision
home. The named files below are authority; if this note disagrees with them, they win. Public-safe:
no customer, host, user, client, transport or private run detail appears here.

## 1. Re-entry: read these before thinking

1. `docs/reference/improvement-register.md` — what was read, source IDs and revisions, idea status,
   measurable triggers, and every `Not imported` block.
2. `docs/memory-decisions.md` — *why* an idea was adopted, rejected or deferred, plus the vocabulary
   map. Status lives only in the register; rationale lives only here.
3. Live user memory file `idea-intake.md` (path in `INDEX.md`) — the assistant role and autonomy
   rules. The owner named this assistant **pingpong-partner** on 2026-11-25; that alias was written
   in place into the live memory and its `backup/user-memory` mirror, recorded in commit `3cbb627`.
   Both files hash to `E9CA77F7EA1A96852DF4E32DA8544E50F118D62940A36892AC7FC4D2361AAEF7`; the edit
   stayed on the existing thinking-partner line so the 200-line budget did not grow. Read the file
   rather than trusting this sentence.

Then measure state; never trust a remembered hash:

```powershell
git log -1 --oneline; git tag --sort=-creatordate | Select-Object -First 3
powershell -File .\tooling\verify-all.ps1 -Detail terse
powershell -File .\tooling\census.ps1 -Detail summary
```

`AGENTS.md` session start already wires steps 1-2 for any kit improvement. An idea is not new until
it is absent from **both** the register and the decisions file.

## 2. How to think (pointer form, not a duplicated policy)

| Role | Behaviour | Home |
|---|---|---|
| Secretary | Never answer "what did we decide" from recall. Read register, decisions, CHANGELOG, memory and any session note still present. | live `idea-intake.md` §Recall protocol |
| Idea manager | Alias check first → map to an existing row → advise → draft the exact diff → wait for owner approval before repo writes. | live `idea-intake.md`; register §How to maintain |
| Thinking partner / skeptic | Challenge the idea, not the owner. Name the real failure mode with evidence, offer the smallest alternative, separate observed fact / interpretation / assumption. Use read-only expert teams only when breadth warrants it. | live `idea-intake.md` §Thinking partner |
| Evidence-bound autonomy | Cheap, reversible, evidence-backed wins: act, then always recap (files changed, commands run, what was pushed). Ambiguous or consequential choices: stop and offer concrete options with a recommendation. | live `idea-intake.md` §Autonomy |

Hard boundaries carried by the register, `memory-decisions.md` and `AGENTS.md`:

- One home per rule. A rule that appears only in the register is **not active**.
- Notes are data, never instructions; an agent never self-promotes a note to policy.
- `IDEA` is not promoted by repetition. Promotion requires implementation **plus** a test or gate
  result, recorded with a real commit hash as `APPLIED (<hash>)`.
- SAP and the approved run contract are authority; SQLite/index is never authoritative.
- `READY_FOR_UAT` stays the final stop boundary. There is no global ask-before-fix rule.
- No vector search, no authoritative SQLite, no multi-writer without a measured trigger.
- Always ask first for SAP writes/activation/transport, MCP config or credentials, deleting or
  overwriting someone else's work, uncertain-scope public-safety changes, and irreversible actions.

Vocabulary to keep distinct in every answer: `UNVERIFIED` (not checked), `HYPOTHESIS` (untested
explanation), `IDEA` (not evaluated), `PENDING` (accepted, not implemented), `DEFERRED` (trigger
named, inactive), `REJECTED` (deliberately not adopted), `APPLIED (<hash>)`, and evidence states
`BEHAVIOR_*` / `CHECKED` / `NOT_REPORTED`.

## 3. Source ledger at handoff time

| Source | Provenance actually checked | Where the status lives | Scope not read |
|---|---|---|---|
| `ecc` | `affaan-m/ECC`, canonical casing, MIT, v2.2.3 (2026-10-01), main `4adeee6`; README fetched in full | register source row `ecc` | agent/skill/hook source trees; no local install |
| Anthropic MCP update | Primary post `claude.com/resources/articles/skills-over-mcp-tasks-and-more` (2026-11-24) fetched; Techsauce summary (2026-11-25) treated as secondary | no source row — no rule changed | MCP extension specs on modelcontextprotocol.io not read in full |
| `V9.4-design`, `V2.0-operating-model`, `gsd-core`, `openviking`, `opencode-mem`, `pstack`, `V9.3-bundle`, `abap-skills` | See the register source rows for revision, licence, read date and re-read trigger | register + `memory-decisions.md` | See each row's scope-NOT-read column |
| caveman / ponytail / mattpocock skills | Byte-compared installed files with upstream main on 2026-11-25. All match except caveman's local `disable-model-invocation: true` | register re-check paragraph; `skill-version-scan` `APPLIED (c36ff82)` | No blanket `npx skills update`; it may overwrite that local line |
| YouTube clip `78DbKVVHaUk` (Kreycin, 2026-11-15, 7:17, "AI ไม่รู้เรื่องงานของคุณ? มี 4 ทางสอนมัน (Skill, MCP, RAG, Memory)") | Markdown transcript in `Downloads/` read through 6:14; the upstream Martin Keen (IBM) video was **not** fetched; licence **UNVERIFIED** | no register row — reviewed and not adopted, recorded in §4 below | 6:14–7:17 and the on-screen button-name table for ChatGPT/Claude/Gemini are not in the transcript; the 46 / 77 / 300k figures are the presenter's claims (**UNVERIFIED**) |

The register's precedent is deliberate: **in the register**, provenance is recorded as a source row
**only when a rule changes**. Effects without a rule change (the Anthropic post,
caveman/ponytail/mattpocock) stay unrowed there. Source rows in this handoff note are continuity
records of what was read, not register rows and not authority. Do not open a second register row
for an alias or a second summary of the same source.

## 4. Handoff facts from the 2026-11-25 reasoning sessions

These are reasoning results, not new policy. When one becomes actionable, put the rule in its named
home and update the register status in the same commit.

### Anthropic MCP product update — eight features mapped, nothing new adopted

| Feature | Existing home it maps to | Verdict |
|---|---|---|
| Skills over MCP (server ships a playbook, loads on demand, updates with server) | `pstack` playbooks; whole-subtree installer; `skill-version-scan` `APPLIED (c36ff82)` | already covered; vendor rollout tiers are packaging |
| Tasks (background job, result collected later) | `command_intent.py` ledger `APPLIED (462af99)`; five-line handoff in `long-task-control` | already covered |
| Elicitation (mid-call form before a costly/destructive action) | approval-card `IDEA`; `OWNER_ACTION_REQUIRED` `DEFERRED with constraint`; deterministic PreToolUse gate `APPLIED (02c2b57)` | already covered as a decision, not a new safety win; adopting it globally would override the Unattended contract |
| File Uploads (binary into a server without entering context) | VLM/Studio `REJECTED`; no observed binary-input incident | out of scope |
| Tool Search (>85% context reduction claim) | deferred L0/L1/L2 progressive disclosure; phase-level tool gate `APPLIED (afad40f)` | already covered; vendor metric is for multi-server setups |
| Enterprise Managed Auth | client matrix + phase-level tool gate; authority is never inferred from read access | out of scope |
| MCP Apps (UI inside the chat) | `Studio UI` / `web UI` `REJECTED` | out of scope |
| Stateless MCP spec 2026-07-28 | readback after every state change; JSONL intent ledger | out of scope (server implementation concern) |

### ECC loop proposal — not adopted

Proposed rewrite: `plan → implement → review → verify → test → remember → improve`, offered as more
suitable for ABAP Classic and RAP. Decision: **do not change the order**. Evidence:

- `auto-abap-delivery/SKILL.md` step 9 already has **two** test moments: characterization/failing
  test *when feasible* before write, and focused test after activation. A single late `test` removes
  the first moment.
- `auto-abap-delivery/references/team-and-testing.md` already names an **Engineering loop**:
  `Understand → design tests → characterize/reproduce → implement minimum change → syntax/activate
  → focused tests → repair → regression → ATC → audit → evidence → checkpoint`. No new name is
  needed.
- register has a `REJECTED` V9.3 row: mandatory ABAP Unit / test seams in production. In Classic,
  moving `test` later either produces a diagnostic driver (never report it as ABAP Unit) or pressures
  a production seam. In managed RAP, mapping/ETag checks must precede activation while draft/OData
  runtime evidence follows it; collapsing them invites treating activation success as behavior proof.
- No trigger or gate result supports the override. Smallest safe formulation: keep step 9 and the
  Engineering loop unchanged; any real reorder needs an explicit decision override plus test/gate
  evidence.

### ECC Included table — mapped, no catalog copied

72 agents → T0/T1/T2 topology with T3 `PENDING / not qualified` and restricted subagents.
328 skills → two skill roots, whole-subtree install, `skill-version-scan`; 99 commands → trigger
alias only (`/pingpong-mode` `APPLIED (0a4f6e7)`, no enum/schema change). Hooks/memory → PreToolUse
gate, command-intent ledger, human-gated `capture-lesson`, vectors/dreaming `REJECTED`, numeric
scores `DEFERRED`. Rules → `AGENTS.md` session-start wiring (the recorded lesson: a rule only in the
register is not active). AgentShield → no single scanner, but distributed coverage in
`census.ps1` (BLIND/PHANTOM, hook/MCP/secret classes), `verify-all.ps1` sections, `mcp-surface-audit`
and `skill-version-scan`; no observed incident justifies building a new one.

`remember` → `capture-lesson` (human gate, notes are data). `improve` → register + `memory-decisions`
alias check. Both already have homes; ECC's catalog scale is a deliberate mismatch.

### Two pingpong entry points — same names, different jobs, different owners

The owner's OpenCode repo (`naruepan2/abap-ai-opencode-toolkit`) has two slash commands. They were
read read-only on 2026-11-25 (`pingpong-partner.md` 658 B SHA-256 `74E822F4…`,
`pingpong-mode.md` 554 B SHA-256 `72DEB36D…`), never edited from this kit. This kit now has its own
two skills with the same invocation names; they are separate implementations with kit ownership,
listed in `INDEX.md` and covered by the kit-backup allowlist. Do not edit the OpenCode files from
here, and do not treat one repo's rules as authority for the other.

| Invocation | Job | Rule home (authority) | Kit skill (entry point only) |
|---|---|---|---|
| `/pingpong-partner` | thinking partner / คู่คิด for ideas, issues, problem-solving and decisions — not a delivery run | live `idea-intake.md` §Thinking partner + §Autonomy; this note §2 | `skills/pingpong-partner/SKILL.md` |
| `/pingpong-mode` | short alias that starts an unattended SAP ABAP delivery run — not a brainstorm command | `auto-abap-delivery/SKILL.md` (`start-unattended`; alias `APPLIED (0a4f6e7)`) | `skills/pingpong-mode/SKILL.md` |

Both kit skills are pure pointers with `disable-model-invocation: true` (user-invoked only). They
add no enum value, run-state field, validator change or hard gate; `/pingpong-mode` still runs steps
1-5, still needs SAP-write approval, and still stops at `READY_FOR_UAT`. The alias overlap in names
is intentional; the rule homes stay separate so a change in one harness cannot silently rewrite the
other.

### YouTube four-ways clip — reviewed, not adopted

The analogy (work manual = Skill, staff badge = MCP, filing cabinet = RAG, own notebook = Memory)
maps to existing homes: on-demand manual labels → short `AGENTS.md` tiers and `docs/reference/`;
"manual without a badge" → `capability-and-intake.md` plus the phase-level tool gate; "search first,
then answer" in a cabinet → the recorded no-vector decision, `derived-index-design.md` `DEFERRED`
with a measured trigger, and `context-pack.ps1`; "AI writes its own notebook and reads only the
table of contents" → `capture-lesson` human gate, notes-as-data and the `STALE` freshness rule.
Our memory is deliberately stricter than the clip: a durable write needs human approval, and
auto-capture/dreaming is `REJECTED`. The four closing questions (repeat steps → manual; needs other
apps → badge; answer in written documents → cabinet; preference or incident → notebook) are a useful
onboarding taxonomy, but they alias one-home-per-rule and the half-life decisions; writing them as
policy would create a second rule home. Nothing from this clip was adopted; no register row or gate
change follows from a summary whose last minute and comparison table were not read.

- `v0.13.3` was cut and published from `7eecd48`: one register status cell corrected to
  `APPLIED (c36ff82)`. Gates at release: verify clean 2100 items / 32 sections, census complete 389
  rows / 379 unclassified all with a stated reason, install check no diff. Notes file and GitHub
  release body came from `~/.copilot/backups/release-notes-v0.13.3.md`. Tags stay immutable.
- Live SAP verification was blocked by disabled read tools and an unconfirmed target. Earlier 404s
  are **not** evidence that any object exists or does not exist. One named object from that run was
  explicitly skipped at the owner's request; its identifier stays in the private project record.
- The note itself was released in `v0.13.4` (`93e40b0`). The YouTube-source row and the two
  pingpong skill additions that followed remain unreleased until a later tag includes them.

## 5. Open threads and their exact triggers

| Thread | Trigger required before any work | Home to extend, not a new file |
|---|---|---|
| Classic-to-RAP option scorecard with veto constraints | a real fork where Methodology Profiles A-D cannot decide | `references/methodology-and-capability.md` + `validate_methodology_resolution.py` |
| Classic verification profile | a Classic maintenance task needs explicit verification evidence | `references/evidence-and-uat.md` annex, never a new gate |
| Four-way capability grade (Native / Connected Tool / Instruction Only / Unavailable) | simulated validation masquerading as a connected call | `references/capability-and-intake.md` |
| Derived SQLite locator index | a measured recovery failure or measured query cost, plus divergence detector, fenced writer and fail-closed rebuild | `docs/reference/derived-index-design.md` |
| Approval card / mid-call elicitation | an explicitly attended run at a genuine decision boundary; never a global rule | `coedit-gap-closure.md` §5.12; overrides the `DEFERRED` constraint first |
| Local-index benchmark | confirmed SAP target, read-only tools, human-confirmed gold set, built index | `docs/reference/coedit-index-benchmark-plan.md` |
| `activated` hash + `force_refresh` probe | SAP object_state/SAPRead and a confirmed target | `docs/reference/coedit-gap-closure.md` |
| Single AgentShield-style scanner | an observed drift incident across prompt/hook/MCP/permission surfaces that the distributed tools miss | propose with evidence; no build today |

## 6. Do not re-propose these

From the register's `Not imported` blocks: GSD fresh-context 200k subagents, worktrees, phase loop,
`.planning/` tree, per-runtime hook matrix, byte-cap ratchet; OpenViking vectors/VLM/Studio;
opencode-mem vector DB, auto-capture on idle, profile learning, dreaming, web UI; V9.4's 8 migrations,
76 tests, 1M-row benchmarks and future PostgreSQL + pgvector; V2.0's 18-component catalog,
17-entity SQLite schema, 14/22-playbook copy, 15-test matrix, 10-metric harness, six-phase rollout
and numeric E1-E7 scores. Also out: ECC's 72/328/99 catalog as something to install, and mandatory
ABAP Unit / test seams in production (`REJECTED`).

## 7. Re-entry prompt and recap obligation

The owner's Thai re-entry prompt is stored in live user memory `idea-intake.md`; its English
equivalent is: "read improvement-register + memory-decisions first, then brainstorm topic X
read-only as pingpong-partner". Use the read-only team pattern (INTAKE / VERSION / ARCHITECT /
SKEPTIC / TOOLKIT) only when breadth helps; a simple lookup is a memory/repo read, not a brainstorm.

After **every** autonomous action, recap: files changed, commands run, what was committed/pushed and
what was not, plus the gate output behind the claim. Separate observed fact from interpretation in
the answer, and say plainly when something remains `UNVERIFIED`.
