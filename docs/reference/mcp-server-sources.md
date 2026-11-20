# MCP server sources — version-check basis

Status: **verified from local `mcp.json`, installed package metadata and public repositories on
2026-11-20.** Contains no credentials, hostnames, users or connection names — only server keys,
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
| `adam` | `npx -y --allow-git=root github:ClementRingot/ADAM` | https://github.com/ClementRingot/ADAM | **not pinned locally** — resolved from the GitHub source at run time |
| `@ui5/mcp-server` | `npx -y @ui5/mcp-server` | https://github.com/UI5/mcp-server | npm registry latest `0.3.3` at check time; config has no version pin |
| `sap-docs` | streamable HTTP to a public hosted endpoint | https://github.com/marianfoo/mcp-sap-docs | upstream release `v0.3.65` latest at check time; hosted deployment version not queried here |

## Evidence per row

- `arc-1`: `package.json` `repository.url` = `https://github.com/arc-mcp/arc-1`; installed version `1.10.1`; repository releases page confirms latest `v1.10.1`.
- `sap-ai-dev-toolkit`: `package.json` `repository.url` = `git+https://github.com/grknylmz/sap-ai-dev-toolkit.git`, `homepage` points to the same repo; installed version `0.9.9928`; latest GitHub release `v0.9.9928`.
- `adam`: the `mcp.json` command names `github:ClementRingot/ADAM` directly; no installed package version exists.
- `@ui5/mcp-server`: npm registry `latest` metadata gives version `0.3.3`, `repository.url` = `git+https://github.com/UI5/mcp-server.git`, `homepage` = repo README. No global install; `npx -y` follows latest.
- `sap-docs`: repo `marianfoo/mcp-sap-docs` confirmed public, description "MCP SAP Docs (Upstream)", latest release `v0.3.65`; README documents the same hosted streamable-HTTP endpoint configured in `mcp.json`. The repo is the upstream of two variants (`sap-docs`, `abap`) selected by `MCP_VARIANT`.

## Rules for a version-check skill

1. Distinguish **pinned local package** from **unpinned launcher**. `arc-1` and `sap-ai-dev-toolkit`
   can be compared as installed version vs latest release. ADAM and `@ui5/mcp-server` use `npx -y`
   with no pin — "current" means what the source/registry resolves at start time.
2. The two `<destination-*>` entries are separate server records backed by **one installed
   package**. Check the package once; do not report two different versions.
3. `sap-docs` is **hosted HTTP**. The upstream repo version is not proof of the deployed endpoint's
   version. A version claim about the running service needs a health/status check on that service.
4. Never read or print credentials, SAP users, connection names or host details from `mcp.json` to
   derive a version. Read only the `command`, `args` shape and server key.
5. Treat GitHub release pages and npm registry as public facts; confirm the installed version from
   the installed `package.json` where one exists. Live `tools/list` remains authoritative for the
   tool surface, not for package version.

## Not included

- extension-contributed tools (ADT MCP, ABAP Remote FS);
- optional companion servers shipped inside `sap-ai-dev-toolkit` but not configured here;
- the `abap` variant of `mcp-sap-docs` (`mcp-abap.*`) — not configured in this `mcp.json`.
