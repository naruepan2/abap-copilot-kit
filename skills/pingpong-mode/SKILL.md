---
name: pingpong-mode
description: >-
  User-invoked short alias that starts an unattended SAP ABAP delivery run via
  the auto-abap-delivery skill's start-unattended token. Not a third mode and
  not a brainstorm command. Spec, plan, qualification and Autonomy Envelope
  still need approval before any SAP write; the run stops at READY_FOR_UAT.
disable-model-invocation: true
---

# Pingpong mode — delivery alias only

This is a **pure forwarder**, not a second mode, not a new enum value and not a new gate. It has the
same invocation name as an owner-authored OpenCode command, but this file is written and owned by
this kit. The OpenCode file was read read-only on 2026-11-25 and was never edited from here.

## One home for the rules

- Workflow and trigger: `auto-abap-delivery/SKILL.md`. `/pingpong-mode` is an alias of the
  `start-unattended` token, recorded as `APPLIED (0a4f6e7)` in `docs/reference/improvement-register.md`.
- Acceptance constraints from that recorded decision: workflow steps 1-5 still run; no
  `execution_mode` enum, run-state schema, validator or evidence-manifest change; `READY_FOR_UAT`
  remains the final stop boundary.

Nothing in this skill restates delivery rules. If this file disagrees with `auto-abap-delivery`,
that skill wins.

## Invocation

Use `/pingpong-mode <task>` only when the owner explicitly wants an unattended SAP ABAP delivery
run. It is equivalent to invoking the `auto-abap-delivery` skill with the `start-unattended` token
and the owner's task arguments.

Before any SAP write: discover safely, draft the assignment, resolve architecture and guardrails,
assess trust and qualification with a stored JSON verdict, and obtain approval of the Spec, plan,
Autonomy Envelope and interaction policy. SAP writes still require explicit `APPROVE AND START`.
Finish at `READY_FOR_UAT`, never `DONE`; production and irreversible actions remain prohibited.

Do not use this skill for brainstorming, ideas, issues or problem-solving; that is
`/pingpong-partner`.

## Ownership boundary

Source concept: owner-authored OpenCode command in `naruepan2/abap-ai-opencode-toolkit`, file
`config/opencode-commands/pingpong-mode.md`, read 2026-11-25. That file forwards to an agent in that
harness; do not copy its agent wiring into this kit or edit that repository from here. Edit this
skill in the kit clone, reinstall with `install-kit.ps1`, and include it in the kit-backup
allowlist.
