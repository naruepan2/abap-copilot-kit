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

## Skill routing — the same problem, one layer up

MCP servers are not the only overlapping surface. Eight pairs of installed **skills** match the same
realistic request, and the wrong pick costs the difference in body size — which for one pair is
23,289 bytes. These pairs are owned by their installers (`~/.agents/skills` from `npx skills`,
`~/.copilot/skills` from `sap-ai-dev-toolkit`), so the resolution belongs here, in the repository,
not as an edit that the next upgrade overwrites.

| Request | Two skills match | Choose | Why |
| --- | --- | --- | --- |
| "build a RAP service for Z booking" | `generate-rap-service` / `generate-rap-service-researched` | the plain one, unless the user asked for research or a production plan | the researched variant is 23,289 B larger and does a planning loop the request did not ask for |
| "create a CDS view for X" | `sap-abap-cds` / `cds-development` | `cds-development` to write or change one; `sap-abap-cds` for annotations, DCL, or a CDS error | 17,457 vs 6,294 B, and the reference skill is the one with the annotation catalogue |
| "investigate this runtime error" | `sap-st22-dump-analysis` / `abap-runtime-analysis` | `sap-st22-dump-analysis` when there is a dump ID; the other for a live debugger session | 15,553 vs 5,580 B, and the dump skill is the one with the ST22 procedure |
| "debug why this fails" | `abap-debugging` / `abap-runtime-analysis` | `abap-runtime-analysis` | 78% of the shorter description (314 of 404 chars) is byte-identical to the other, so the pair is one capability described twice |
| "build a Fiori app on my RAP service" | `convert-ui5-to-fiori-elements` / `generate-rap-service` / `sapui5` | `convert-ui5-to-fiori-elements` only when a V4 service already exists | 52,493 / 36,374 / 16,967 B; generating the service is a different task from consuming it |
| "migrate this Z program" | `migrate-custom-code` / `migrate-segw-to-rap` | `migrate-custom-code` for ATC-driven clean-core work; the SEGW one only for an OData V2 service | 14,747 vs 57,672 B |
| "modernize this UI5 app" | `modernize-ui5-app` / `sapui5` | `modernize-ui5-app` for a legacy upgrade, `sapui5` for new development | 80,252 vs 16,967 B |
| "clean core check for this package" | `sap-clean-core-atc` / `sap-migration-dossier` | `sap-clean-core-atc` for the A–D classification, the dossier for a shareable report | 10,903 vs 16,390 B |

Rules that keep this list honest:

- A row here is a **routing** decision, not a claim that either skill is wrong. Both may be correct
  and still have different costs.
- Do not edit the installed skill to disambiguate its trigger: a reinstall overwrites it. If a pair
  stays ambiguous in practice, the row belongs in this table.
- Re-measure the sizes when a skill is upgraded. `tooling/measure-context.ps1 -Detail full` prints
  every skill's injected size, and its section 6 prints each skill's body size — section 2 of
  `verify-all.ps1` checks frontmatter, not size.

### A `.md` name inside a skill usually means a sibling skill, not a file

The `arc-mcp/arc-1` skills were written as flat `.md` files in one directory and the installer turns
each into a folder with a `SKILL.md`. So `convert-ui5-to-fiori-elements` says "pick
`modernize-ui5-app.md` instead", and no such file exists — the skill is the folder
`~/.agents/skills/modernize-ui5-app/`. Measured 2026-11-16: 10 such mentions across 3 skills
(`convert-ui5-to-fiori-elements` 8, `modernize-ui5-app` 1, `migrate-segw-to-rap` 1), naming 4
distinct sibling skills, and zero files matching any of them.

Read `<name>.md` as "the skill called `<name>`" and open its `SKILL.md`. Do not treat the missing
file as a broken install: editing the skill to fix it would be overwritten on the next update, so it
is recorded here instead.
