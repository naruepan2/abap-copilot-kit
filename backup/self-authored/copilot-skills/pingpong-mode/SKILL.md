---
name: pingpong-mode
description: >-
  User-invoked short alias that forwards to the auto-abap-delivery skill's
  start-unattended token. Not a third mode and not a brainstorm command.
  Pointer only: qualification, approval and the UAT stop live in that skill.
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

Use `/pingpong-mode` with the task as arguments only when the owner explicitly wants an unattended
SAP ABAP delivery run. It is equivalent to invoking the `auto-abap-delivery` skill with the
`start-unattended` token and the owner's task arguments. The token only preselects unattended after qualification:
unqualified scope resolves to Attended Standard and critical scope requires at least Controlled.
The invocation alone is not override evidence.

Before any SAP write, follow `auto-abap-delivery` exactly: its workflow steps 1-5 freeze the Spec,
implementation plan, test plan, execution contract, Autonomy Envelope and resolved interaction
policy. SAP writes require that skill's explicit approval; the run stops where that skill says it
stops.

Do not use this skill for brainstorming, ideas, issues or problem-solving; that is
`/pingpong-partner`.

## Ownership boundary

Source concept: owner-authored OpenCode command in `naruepan2/abap-ai-opencode-toolkit`, file
`config/opencode-commands/pingpong-mode.md`, read 2026-11-25. That file forwards to an agent in that
harness; do not copy its agent wiring into this kit or edit that repository from here. Edit this
skill in the kit clone, reinstall with `install-kit.ps1`, and include it in the kit-backup
allowlist.
