# Detail levels — how much any output should say

Every producer we control (script, template, agent report, subagent return) takes the same
three-valued switch. The caller decides the cost, not the producer: the producer cannot know
whether this run needs a verdict or a root cause.

| Level | What it returns | When the caller wants it |
|---|---|---|
| `terse` | verdict + counts + only the items that failed | the normal case |
| `full` | every item, each with its evidence | analysing a failure |
| `raw` | the unparsed source of truth | a parse produced something wrong |

`terse` is the **default**. An opt-in short mode is never used — whoever has to remember the flag
will not remember it.

## Rules

1. **`terse` must answer the question.** If it drops the signal that something failed, the caller
   runs `full` next and pays twice.
2. **`terse` must declare what it dropped.** `suppressed: 5 (priority 3)`, `omitted: 12 rows — use
   -Detail full`. A silently shortened result is read as "nothing else exists", which is the exact
   failure the evidence discipline forbids.
3. **`raw` must differ from `full`, or it is not offered.** It exists for the case where parsing
   lost information; if parsing cannot lose information, the enum stops at `full`.
4. **The enum is closed.** One name per level, in every producer. "brief", "short", "summary" are
   rejections, not synonyms.
5. **`terse` is deterministic.** If it sometimes prints 3 lines and sometimes 20, the caller cannot
   budget for it.
6. **Never on a write, never on an error.** A save is not an activation, and a shortened error is an
   error nobody can act on. Detail levels govern *successful reads only*.

## Producers and their current state

Verified 2026-11-14.

| Producer | Before | Level offered |
|---|---|---|
| `~/.copilot/state/measure-context.ps1` | no switch, 73 lines / ~1,130 tok every run | `terse`, `full`, `raw` |
| `~/.copilot/state/verify-all.ps1` | `-Summary` opt-in, so verbose by default | `terse`, `full` |
| `~/.copilot/state/who-locks.ps1` | `-Match` filter only | not converted — output is already one line per lock |
| `templates/spec-INDEX.md` | already works this way: ~900 tok index vs ~22,500 tok spec | keep `Index → Summary → one slice` |
| Agent reports | prose, unbounded | `terse` by default — see *Report contract* in the agent |
| Delegated-agent returns | narrower than the question; no contract | briefed with `terse` + what it did not inspect |

Measured 2026-11-15: `-Summary` in `verify-all.ps1` was declared and then overwritten by the `-Detail`
default, so `-Detail full -Summary` printed the full output the caller had asked to suppress. The
default was already `terse`; only the switch was dead. It is now honoured, and the two are kept as
one thing: `-Summary` sets `-Detail terse`.

## Not the same thing as a budget

A byte budget that *refuses* a response (ARC-1's `DataResponseBudget` /
`AdtResponseLimitError`) protects a transport. It does not help the caller: a refused read returns
nothing to reason about, where a `terse` read returns the verdict. Use a budget as a backstop,
never as the answer to "this result is too big".
