---
name: long-task-control
description: How to run, checkpoint, and stop a task that outlives one request — the stop condition, the handoff when stopping early, and the rule that evidence expires when it leaves context. Use when a task will span multiple objects or layers, when it is about to hit a request or context limit, when asked to "continue where we left off", "write a handoff", "what is left", or when resuming work from a previous session. Do not use for a single-object change that fits in one turn.
---

# Long-task control

A task that spans more than one turn fails in three specific ways, and each has a cheap defence.

## 1. State the stop condition before the work starts

At the start of a slice that will run long, say: **"I stop when X is activated and verified, or when
the next object needs a decision I cannot make."**

An undefined stop condition means the work ends whenever the request limit arrives — which is neither
the right time nor a reason anyone chose.

## 2. Escalate planning only for real reasons

Use lightweight planning by default. Escalate to an explicit plan when the work:

- spans multiple related objects or layers
- introduces a new RAP service or data model
- changes an interface or persistence contract
- touches enhancements
- has unclear business rules
- carries meaningful regression risk

Present a short plan and the decisions needed — not a long interview. For work that exceeds one
session, split it into independently verifiable slices with dependencies and clear completion
criteria. Do not create external tickets, branches, or delegate work unless the user asks and the
environment supports it.

## 3. Stopping before completion: write a handoff, not a status report

A status report says what happened. A handoff lets the next session continue. It needs exactly:

1. the goal, in one sentence
2. what is done
3. what is not done
4. the next exact step
5. which facts must be re-verified, because their evidence is no longer in context

Point 5 is the one that gets left out and the one that causes the most damage next session.

## Evidence has a lifetime

A tool result is evidence only while it is still in context. When it falls out of context the fact
reverts to `UNVERIFIED` and must be re-read before being relied on.

Never cite an earlier result as if it were current — say it was verified earlier and re-verify before
acting. A todo entry proves a step happened; it never proves the step succeeded.
