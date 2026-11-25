---
name: pingpong-partner
description: >-
  User-invoked thinking-partner entry point (คู่คิด) for brainstorm, ideas,
  issues, problem-solving and decisions. Restate disk facts first, name the
  real decision, argue both sides, and offer 2-3 options with cost,
  reversibility and stop condition. The rules live elsewhere; this is a pointer.
disable-model-invocation: true
---

# Pingpong partner (คู่คิด) — kit entry point

This is a **user-invoked entry point**, not a second rule surface and not a hard gate. It has the
same invocation name as an owner-authored OpenCode command, but this file is written and owned by
this kit. The OpenCode file was read read-only on 2026-11-25 and was never edited from here.

## One home for the rules

- Behaviour and autonomy: live user memory `idea-intake.md`, sections Thinking partner, Autonomy
  and Recall protocol. It is always loaded; read it before acting, never from recall.
- Continuity map and vocabulary: `docs/reference/idea-handoff.md` section 2.
- Idea status and provenance for any kit brainstorm: `docs/reference/improvement-register.md`
  followed by `docs/memory-decisions.md`.

Nothing in this skill restates or overrides those rules. If this file disagrees with any of them,
they win. A remembered claim stays `UNVERIFIED` or `HYPOTHESIS` until it is re-read from disk or a
tool result.

## Invocation

Use `/pingpong-partner <topic>` when the owner wants a second opinion on an idea, issue, problem or
decision. It is a brainstorm mode, not a delivery run; for an unattended SAP ABAP run the owner uses
`/pingpong-mode` instead.

Before answering, read the named homes above and apply their steps exactly as written there:
observed fact / interpretation / assumption are separated, the real decision is named, the
counter-case is made against both the owner's leaning and our own recommendation, and 2-3 options
carry cost, reversibility and a stop condition. Offer the smallest safe alternative, not just
agreement. Call read-only expert teams only when breadth warrants it.

Record the outcome where the homes require it. Do not create a second ledger here. If the owner
approves a repo change, update the register or memory status in the same commit under the one-home
rule.

## Ownership boundary

Source concept: owner-authored OpenCode command in `naruepan2/abap-ai-opencode-toolkit`, file
`config/opencode-commands/pingpong-partner.md`, commit `b6527e3`, read 2026-11-25. That file points
to its own `docs/idea-ledger.md` thinking-partner section; do not copy that ledger into this kit or
edit that repository from here. Edit this skill in the kit clone, reinstall with `install-kit.ps1`,
and include it in the kit-backup allowlist.
