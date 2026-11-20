# Auto ABAP Delivery V8 — inspection evidence

Status: **read-only inspection record, 2026-11-20.** This file records what was checked in the
delivered V8 package before any installation. It is evidence, not a second copy of the design.
Source package path is intentionally omitted — this public file contains no host paths, user names,
customer identifiers or credentials.

Only `EVIDENCE.md` and the short English `INSTALL.md` are stored here. The Thai `IDEA-V8.md`
and `MERGE_GUIDE.md` remain in the private delivered package: section 9b's mojibake detector
currently classifies several ordinary Thai runs (for example `U+0E41 U+0E17 U+0E19`) as cp874
damage. Copying them into the public kit would fail the gate, so they are *not* copied and the
gate is not weakened. Read them from the delivered package instead.

## Package structure — measured

| Check | Result |
|---|---|
| Archive present | no `.zip` in the supplied path; already-extracted directory |
| Top level | `.github/`, `config/`, `docs/`, `scripts/`, `skills/`, `INSTALL.md`, `MERGE_GUIDE.md` |
| Markdown files | 28 |
| `.github/skills` vs `skills` | byte-identical for all 19 files under `.github/skills`; the agent exists only under `.github/agents` |
| Agent | `.github/agents/auto-abap-delivery.agent.md`, frontmatter `name: Auto ABAP Delivery Lead`, no suffix at source |

## Integrity — measured

| Check | Result |
|---|---|
| JSON Schema | `qualification-config.schema.json` parses; title `SAP ABAP Autonomous Delivery V8 Qualification Configuration`; 19 KB |
| Python scripts | 7 scripts (`compatibility_check.py`, `validate_qualification_config.py`, plus 5 under skill `scripts/`) compile with Python 3.15.2 |
| SKILL.md references | 11 `references/*.md` and `scripts/*.py` targets listed in SKILL.md all resolve |
| Internal consistency | interaction-control, trust-and-qualification, state-machine-and-recovery and sap-guardrails agree on: unqualified → Attended Standard; critical → at least Controlled; qualified may be Unattended; stop at `READY_FOR_UAT`; no transport release/import |
| Secret scan | no customer IDs or credentials found; the word `password` appears only in rules forbidding credential storage |
| Validators runtime | both validators now pass with `{ "valid": true, "errors": [] }`. Python 3.15 has no PyYAML wheel here; a temp venv outside the repo used `ruamel.yaml` + a `yaml.safe_load` shim and `jsonschema`, without modifying the V8 scripts or global Python |

## Compatibility gaps identified — not yet fixed here

1. Kit canonical layout is `agents/*.agent.md` + `skills/*/SKILL.md`, not `.github/...`.
2. The kit already has `abap-developer-by-pongg` as its coordinator; V8 defines another SAP-write
   coordinator. Two write coordinators must not run without an explicit human decision.
3. `roster.json` is a human-owned allowlist. Any new agent file must be added there before
   `verify-all.ps1` section 5b is clean; new agents are `not_delegatable`.
4. V8 qualification policy refers to MCP profile id/hash; the kit has no such field. Any adapter
   must be additive and must not edit `mcp.json`.
5. V8 is host-neutral and has no ARC-1 / ADT MCP / ABAP FS tool adapter; a project adapter is
   needed, without guessing system, client or capability.
6. MERGE_GUIDE.md contains `rm -rf` commands — do not execute them against the kit. Use additive
   copy only.

## Installation decisions recorded for this machine

- Agent file: copy as `abap-auto-delivery-by-pongg.agent.md` into `~/.copilot/agents`;
  frontmatter name `ABAP Auto Delivery by Pongg`; add matching `not_delegatable` roster entry.
- Skill: copy to `~/.agents/skills/auto-abap-delivery/` as real files (not a symlink to the
  delivery folder); keep the original skill name.
- Config example/schema: keep in the delivered package / private config location; do not copy into
  the public kit and do not overwrite existing harness config.
- PyYAML: use a temporary virtual environment outside the repository for validation; never install
  globally without a separate approval.

## Never performed during inspection

- no `tools/list` claim beyond what the session actually observed;
- no SAP write, lock, activation, transport release or import;
- no config, MCP, roster, agent or skill modification;
- no deletion of existing files.
