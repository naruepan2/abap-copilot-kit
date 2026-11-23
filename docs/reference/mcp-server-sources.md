# MCP server sources — version-check basis

Status: **verified from local `mcp.json`, installed package metadata and public repositories on
2026-11-20; documentation-server rows updated 2026-11-23.** Contains no credentials, hostnames, users or connection names — only server keys,
launch shapes, source URLs and version identity. Use as the input for a skill that checks and
updates versions. Extension-owned MCP tools are deliberately excluded.

## Scope

VS Code's chat tools picker shows both MCP servers and extension-contributed tools. This list
covers **MCP servers declared in `mcp.json` only**. The following are extension-owned and out of
scope: ADT MCP (`adt-mcp-server/*`) and ABAP Remote FS (`murbani.vscode-abap-remote-fs/*`).

## Server list

| `mcp.json` key | launch shape | source repository | version identity |
|---|---|---|---|
| `arc-1` | stdio via the local ARC-1 launcher script | https://github.com/arc-mcp/arc-1 | installed `1.10.1`; GitHub release `v1.10.1` latest at check time |
| `<destination-A>` | stdio via `sap-ai-dev` (one destination) | https://github.com/grknylmz/sap-ai-dev-toolkit | installed `0.9.9928`; GitHub release `v0.9.9928` latest at check time |
| `<destination-B>` | stdio via `sap-ai-dev` (one destination) | same as above | same installed package `0.9.9928` — two entries, one version |
| `adam` | `npx -y --allow-git=root github:ClementRingot/ADAM` | https://github.com/ClementRingot/ADAM | **not pinned locally** — GitHub latest release `v0.0.3` (published 2026-11-02) at check time; `npx` still resolves at run time |
| `@ui5/mcp-server` | `npx -y @ui5/mcp-server` | https://github.com/UI5/mcp-server | npm registry latest `0.3.3` at check time; config has no version pin |
| `sap-abap-docs` | streamable HTTP, `abap` variant, public hosted endpoint | https://github.com/marianfoo/mcp-sap-docs | upstream release `v0.3.65` at check time; hosted deployment `0.3.67` verified 2026-11-23 |

## Evidence per row

- `arc-1`: `package.json` `repository.url` = `https://github.com/arc-mcp/arc-1`; installed version `1.10.1`; repository releases page confirms latest `v1.10.1`.
- `sap-ai-dev-toolkit`: `package.json` `repository.url` = `git+https://github.com/grknylmz/sap-ai-dev-toolkit.git`, `homepage` points to the same repo; installed version `0.9.9928`; latest GitHub release `v0.9.9928`.
- `adam`: the `mcp.json` command names `github:ClementRingot/ADAM` directly; no installed package version exists.
- `@ui5/mcp-server`: npm registry `latest` metadata gives version `0.3.3`, `repository.url` = `git+https://github.com/UI5/mcp-server.git`, `homepage` = repo README. No global install; `npx -y` follows latest.
- `sap-abap-docs`: repo `marianfoo/mcp-sap-docs` confirmed public, description "MCP SAP Docs (Upstream)", latest release `v0.3.65`; README documents the same hosted streamable-HTTP endpoint and the two variants selected by `MCP_VARIANT`. The configured key selects the `abap` variant; `tools/list` returned 9 tools on 2026-11-23.

## Rules for a version-check skill

1. Distinguish **pinned local package** from **unpinned launcher**. `arc-1` and `sap-ai-dev-toolkit`
   can be compared as installed version vs latest release. ADAM and `@ui5/mcp-server` use `npx -y`
   with no pin — "current" means what the source/registry resolves at start time.
2. The two `<destination-*>` entries are separate server records backed by **one installed
   package**. Check the package once; do not report two different versions.
3. `sap-abap-docs` is **hosted HTTP**. The upstream repo version is not proof of the deployed endpoint's
   version. A version claim about the running service needs a health/status check on that service.
4. Never read or print credentials, SAP users, connection names or host details from `mcp.json` to
   derive a version. Read only the `command`, `args` shape and server key.
5. Treat GitHub release pages and npm registry as public facts; confirm the installed version from
   the installed `package.json` where one exists. Live `tools/list` remains authoritative for the
   tool surface, not for package version.

## Discovery protocol — for future servers and skills

The table above is **a snapshot, not a registry**. A version-check skill must discover the current
server list each run; a newly installed MCP server must not require an edit to this file before it
can be reported.

```text
1. READ mcp.json (VS Code and, where relevant, the Copilot CLI config).
2. ENUMERATE every entry under `servers` — key, type, command/args or url.
3. CLASSIFY each entry by launch shape:
     local npm package   -> installed package.json under the global npm root
     npx / github: spec  -> unpinned; resolve version from registry or repo at check time
     http / streamable   -> no local package; version needs a health/status endpoint
     launcher script     -> follow the script only to identify the package; never read secrets
4. MATCH against known source map in this file. Known -> reuse row. Unknown -> mark UNVERIFIED
   SOURCE and ask; never guess a repository from the server key or tool names.
5. COMPARE installed version with the upstream release/registry version for that source.
6. REPORT per server: key, launch class, source (or UNVERIFIED), installed/current version,
   evidence path, and a stale/unknown verdict.
7. When a new source is confirmed by a human, append it to the table with its evidence line;
   that becomes the known row for the next run.
```

### Expansion rules

- Do not hardcode a count of servers or skills. A count in prose goes stale the moment a server is
  installed; derive counts from the enumeration each run.
- Extension-contributed tools are a different discovery surface: enumerate extension manifests when
  the skill's scope includes them, and label them separately from MCP servers. Never mix their tool
  names into the server table.
- One package may back several server entries. Group by resolved package identity before reporting
  a version, not by server key.
- An unrecognised npm package may still have a `repository` field in its installed `package.json`.
  That is evidence for the source; if there is no installed package, ask rather than infer.
- A version check is read-only. Do not run install, update or restart commands as part of discovery;
  an upgrade is a separate, user-approved action.
- Skill inventory (`SKILL.md` name/description) is also dynamic. If the task covers installed
  skills, enumerate from the skill roots rather than from a memorised list, and report only the
  fields the harness actually sends.

## Not included

- extension-contributed tools (ADT MCP, ABAP Remote FS);
- optional companion servers shipped inside `sap-ai-dev-toolkit` but not configured here;
- the `sap-docs` variant of `mcp-sap-docs` (`mcp-sap-docs.marianzeis.de`) — removed from `mcp.json` on 2026-11-23. It was the only configured variant exposing `ui5_version_diff`.
