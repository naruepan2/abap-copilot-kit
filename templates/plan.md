# Plan — <task>

Copy to `Projects/<PROJECT>/<PROGRAM>/plan-<task>.md` and approve once. After approval this
file is the checkpoint, not a new contract. The stop condition and handoff rules live in skill
`long-task-control`; this file is where they are written down for one run.

Four rules:
1. One todo = one verifiable unit, about 15–45 minutes, at most one artifact. "Read the spec"
   is not a todo; "map all 12 FS rules to a method" is.
2. Approve once. Only leaving the approved scope needs another approval.
3. The plan is a hypothesis. When a todo proves it wrong, revise it — do not push through.
4. At most 12 todos. More means split into phases, one plan per phase.

Goal:        <one measurable outcome>
Acceptance:  <what is tested, and when it counts as done>   ← stop condition

Contract:
- FS:          <path / "none, proposed <date>">
- Spec:        <program folder>/spec.md — REQ ids in scope: <REQ-01, REQ-02>
- ADT path:    <writer>, <verify>, <analyse> — one writer per object
- Change type: <bug fix / extension / change request>
- Production:  <not live / live, dev in sync / unknown>
- Target:      <system, client, transport>

Approved:
- Write:      <objects that may change> — locator + hash engine per object
- Activate:   <yes / no>
- Transport:  <TR / none>
- By:         <user + date>

## Todo

- [ ] 1. <verifiable unit> — ~30 min — owner: lead
- [ ] 2. <verifiable unit> — read-only, delegated — evidence: <what comes back>
- [ ] 3. <verifiable unit> — owner: lead — brief: contract and scope above

Legend: `[ ]` todo · `[x]` done with evidence · `[~]` blocked with a question.

## Log

One line per tick. This is what survives a context reset; a tick without evidence proves
nothing.

- <date> 1. <what was verified> — evidence: <file path, table read, test output>
- <date> 2. BLOCKED: <the one question a human must answer>
