# V9 gap notes from two live runs — 2026-11-21

Status: **read-only analysis, not an implementation.** Source: two run summaries and two V9 design
documents supplied by the user. No Thai source text is copied into this public file: verify-all
section 9b currently classifies several ordinary Thai runs as cp874 damage, and the gate is not
weakened for this note.

## Evidence examined

| Source | Role |
|---|---|
| `SUMMARY_EX-S4-OPEN-PO-001.md` | run 1 summary; report build, `READY_FOR_UAT` |
| `SUMMARY_EX-S4-FULFILL-RISK-002.md` | run 2 summary; RAP service build, `READY_FOR_MANUAL_TEST` |
| `3.md` | V9 post-run evidence / continuous improvement idea |
| `1 (2).md` | V9 completed patch; class-first, evidence, team, state and qualification changes |

Absolute paths and user names are intentionally omitted.

## Verified gaps in the installed V8 skill

Search across installed `~/.agents/skills/auto-abap-delivery/*.md` returned zero hits for:
`DIAGNOSTIC_DRIVER`, `ghost`, `owner_confirmation`, `NOT_REPORTED`, `post-run`, and
`Object Responsibility`. Current V8 therefore has no explicit guardrail for the failure modes
observed in the runs.

Run folders contain `command-log.jsonl`, `decision-log.jsonl`, `review-log.jsonl`,
`transition-log.jsonl`, `run-state.json`, `decisions/` and `uat/UAT_PACK.md`. They contain no
`RUN_EVIDENCE.md` and no `evidence-manifest.yaml`.

## Mode override issue

Both run states record:

- `qualification_state: unqualified`
- `execution_mode: unattended`
- `review_level: not_applicable`
- `resolved_from: owner_explicit_policy_override_one_scope`

V8 `init_run.py` and `validate_run.py` check only mode/review consistency. They do not require an
approval artifact for an owner override. No such artifact was found in either run folder. This is a
validator gap, not proof that the owner did not approve it in chat; the chat is outside the run
artifact.

## Run-specific findings

### Run 1 — `READY_FOR_UAT`

Owner confirmed that the report worked. V9 §8 requires scoped owner confirmation: general
confirmation may close named checks only, and must not override authorization-negative, data
reconciliation or performance evidence. Under V9, this run's terminal state needs reclassification
or a scoped confirmation artifact.

### Run 2 — `READY_FOR_MANUAL_TEST`

This state is consistent with V9: service binding active but unpublished, no OData runtime
evidence, data preview closed, no authorization-negative tool, no performance measurement.

Additional gaps:
- 16/16 tests came from a diagnostic driver because the ABAP Unit runner did not execute the class
  test include. V9 §5.2 requires result type `DIAGNOSTIC_DRIVER`, not `ABAP_UNIT`.
- ghost object `ZCL_SDFRISK_QUERY` remains in TADIR. V9 requires a repository hygiene ledger and
  blocks `READY_FOR_UAT` while unapproved ghosts remain.
- four objects had ATC `notReported`; V9 requires disclosure via per-object states such as
  `NOT_REPORTED`, not solution-wide ATC success.
- the summary references `DEC-002`, but the decisions folder contains `DEC-003` to `DEC-006`; check
  `decision-log.jsonl` before treating that reference as evidence.

## Approved Phase 0–1 direction

Additive changes only. Do not overwrite V8 files. Do not change SAP/MCP config. Do not activate
new V9 capabilities in full: class-first, Object Responsibility Plan and dynamic team planner
stay in a later approval.

Phase 1 targets:
- `references/evidence-and-uat.md`: scoped owner confirmation, diagnostic result taxonomy,
  per-object verification matrix, unpublished service rule, minimal post-run evidence package.
- `references/sap-guardrails.md`: repository reconciliation and ghost-object ledger.
- `references/state-machine-and-recovery.md`: reconciliation and evidence-repair states.
- `references/interaction-control.md`: owner override requires durable approval evidence.
- `scripts/validate_run.py`: fail unqualified + unattended when approval evidence is missing.
- `SKILL.md`: workflow order and non-negotiable rules, without copying full section text.

After patch: refresh `kit-backup` snapshot, verify, commit and push.
