# Anti-hallucination

A behaviour rule, not a prompt trick. The goal is that a claim about the environment is
either backed by something the session observed, or clearly marked as unverified.

## The rule

> Every statement about the environment needs a source from this session. Name the source: a
> file path, a command, or a tool result. If you have not checked, say so.

## What counts as guessing

| Statement | Guess? | What to do instead |
| --- | --- | --- |
| "Tool X is not available on this system" | yes | try the call, or read `tools/list` |
| "This file is the user's" | yes | hash it against the installer manifest |
| "Skill `foo` exists" | yes | `Test-Path` the folder and read its frontmatter |
| "This agent is the active one" | yes | ask the user; the agent cannot read its own name reliably |
| "This error is caused by ..." before any evidence | yes | label it `HYPOTHESIS` and name the check that would confirm it |
| "I read that file" | yes | only if a read tool ran this session |
| "The version is probably ..." | yes | run the version command |

## The three labels

- `HYPOTHESIS` — a plausible explanation, paired with the check that would confirm or refute it.
- `UNVERIFIED` — a claim that could not be checked here, with the check that would settle it.
- *(unlabelled)* — a fact, and only when a tool result, file read, or command output from this
  session supports it.

Mislabelling is the failure mode. A labelled guess is useful. An unlabelled guess is a defect,
because the reader cannot tell it from evidence.

## Applying it in practice

**Before asserting, ask which source would prove it.** If the answer is "a command I could
run", run it. A check you could run is never the user's job to answer.

**Report the gap, do not fill it.** A truncated tool result, an empty search, a `200` with no
body — each is information. Inventing a plausible value destroys the one signal that would
have prompted a retry.

**Absence of evidence is not evidence of absence.** An empty search result does not prove an
object does not exist. A passing lint does not prove activation. An activation does not prove
correct behaviour. Say which of these you actually observed.

**Do not chain guesses.** Two unverified premises make an unverifiable conclusion. If step 1
is `UNVERIFIED`, everything downstream inherits that.

## Where the stronger domain rules already live

Several agents in this workspace enforce a stricter version, and they should be preferred
inside their own scope:

| Agent | Its stronger rule |
| --- | --- |
| `sap-abap-reverse-engineer-by-pongg` | separates observations, assumptions, hypotheses, evidence, findings, and facts |
| `sap-se38-report-tester-by-pongg` | default-deny tool matrix; `UNKNOWN` plus what was tried |
| `sap-st22-dump-analysis-by-pongg` | keeps dump facts, source facts, derived findings, inferences, and unknowns visibly distinct |

Do not restate those rules in another file. Point at them.

## Why this rule is structural

An instruction can be ignored. Two things make it harder to ignore:

1. **Ownership is decided by hash**, not by reading the filename. A wrong guess fails loudly.
2. **A wrong write is expensive.** Activating the wrong object, or editing an installer-owned
   file, has a durable cost. The gate exists because the cost is not recoverable by retrying.
