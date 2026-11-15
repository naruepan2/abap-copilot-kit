# Tool routing

Several SAP MCP servers are installed and they overlap heavily. This document explains the
decision procedure; the concrete task → tool table lives in the agent file, because it changes
when the servers change.

**Single source of truth:**
`agents/abap-developer-by-pongg.agent.md` → section `## MCP tool routing`.

Do not copy that table here or into memory. A duplicated routing table becomes a second,
silently stale source of truth; an earlier copy of this one rotted within two months and was
wrong on seven points.

## Why routing is needed at all

A capable server is not the same as a reachable one, and a reachable one is not the same as one
that implements the operation you need. In practice those three properties diverge:

- An official server can be feature-richer in one area and structurally unable to reach a
  system you use daily.
- A server with 68 tools can lack the one write operation another server provides with 12.
- A generator that derives its schema from the target system beats a hardcoded template even
  when the template has more knobs.

## Decision order

Stop at the first step that decides.

| # | Question | If it fails |
| --- | --- | --- |
| 1 | Can this server reach the target system? | exclude it entirely |
| 2 | Does it implement that operation? Check `tools/list`, not a capability essay | exclude it |
| 3 | Is the write path guarded? Source hash, dry-run, dependency-ordered activation | prefer the guarded one |
| 4 | Is the guidance authoritative? System-derived schema over hardcoded template; real ATC over local heuristics | prefer the authoritative one |
| 5 | Lower token cost? Fewer advertised tools, method-level reads | — |
| 6 | Still tied | **ask.** A tie is never broken by guessing |

## Three hard rules

1. **One server per task.** Do not run the same operation through two servers to compare.
2. **Report a denial.** If the first-choice tool is unavailable or denied, say so. Do not
   silently fall back to a weaker tool.
3. **A wildcard is availability, not guidance.** `tools:` decides what the agent *may* call. It
   says nothing about *when*. A newly installed tool is unrouted until a routing row exists.

## On ties involving ARC-1

When two tools satisfy a task equally, the order is:

1. ARC-1, **when its tools are callable in this session**.
2. Otherwise, the server exposing fewer tools.
3. Otherwise, ask.

Whether ARC-1 is callable is a fact to observe, not to assume — but observe it only after the target
system and client are confirmed, with a call that reads no data. If the tool is absent from the
session, report that and move to step 2. The reason for the preference is cost and guardrails: the
fewest advertised tools, and the tightest default-deny configuration.

## Keeping it correct

Load the `mcp-surface-audit` skill when a server, extension, or agent is installed or removed.
It regenerates the live tool surface from `mcp.json`, the extension manifests, and
`tools/list`, then patches the agent file. Do not hand-maintain a tool list from memory.
