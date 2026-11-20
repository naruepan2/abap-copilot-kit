---
name: sap-mcp-upgrade
description: >-
  User-invoked only: list the currently installed MCP/skill versions beside the
  available versions with their evidence sources, then ask before upgrading any
  one of them. Read-only detect by default; no install, config edit or restart
  without explicit approval. Use when asked to check MCP updates, upgrade arc-1
  or sap-ai-dev-toolkit, refresh installed skills, or inspect a newly installed
  server's version.
disable-model-invocation: true
---

# SAP MCP upgrade

This is a user-invoked maintenance procedure, not an automatic updater. It never
selects a server, package or skill on the model's own initiative. Show the facts
first; ask second; change nothing until the user answers.

## Boundaries

- Owns: MCP servers declared in `mcp.json`, their installed npm packages, and
  skills in the two user roots.
- Does not own: VS Code extensions (a different discovery surface), SAP systems,
  credentials, hosts, users or connection names.
- Default mode is DETECT. APPLY happens only for items the user names.
- Never auto-install, auto-pin, auto-restart or edit an installer-owned `SKILL.md`.

## 1. DETECT — read-only, do not mutate

1. Read the source snapshot `docs/reference/mcp-server-sources.md`. It is a
   snapshot, not a registry — enumerate the live config again every run.
2. Enumerate `mcp.json` servers. Classify each launch shape: pinned npm package,
   unpinned `npx`/`github:` spec, hosted HTTP, or launcher script. Never guess a
   repository from a server key or a tool name; an unknown source stays
   `UNVERIFIED SOURCE`.
3. Enumerate skills from both roots (`~/.copilot/skills`, `~/.agents/skills`).
   Read only `name` and `description`; do not load whole skill bodies into
   context.
4. For each pinned npm package: read the installed version from its installed
   `package.json`, and the available version from the matching GitHub release or
   npm registry. For an unpinned `npx` spec, "available" is the registry `latest`.
   For a hosted service, report the upstream release but state that the deployed
   endpoint version was not queried.
5. Group by resolved package identity. Two server entries backed by one package
   are one candidate, not two.
6. For every candidate record: key, launch class, source repository, installed
   version, available version, upgrade method, evidence path and risk.

## 2. SHOW — mandatory before asking

Present a table first. One row per candidate, with all of these columns:

| server / skill | current version | available version | source | evidence | upgrade method | status |
|---|---|---|---|---|---|---|

Rules for the table:

- `source` is the repository or registry URL that was actually checked, not a
  guessed one. An unknown source reads `UNVERIFIED SOURCE` with the reason.
- `evidence` names where each version came from: installed `package.json` path,
  GitHub release page, npm registry metadata, or the hosted endpoint's own
  health/status response. Two versions need two evidence references.
- `status` uses `UP_TO_DATE`, `UPDATE_AVAILABLE`, `UNPINNED`, `HOSTED_ONLY`,
  `UNVERIFIED_SOURCE` or `SKIP` with a one-line reason.
- State the check date and that live `tools/list` is authoritative for the tool
  surface, not for package version.
- Do not hide a failed or missing check. `UNVERIFIED` is a result, not a blank.
- Do not recommend an order of upgrades here — that is the next step after the
  user has seen the facts.

If the user asks only to check versions, stop after this table.

## 3. SELECT — one explicit confirmation

Ask the user which rows to upgrade. The question must:

- name the exact items, not "all";
- show for each chosen item the command to run, files that will change,
  old → new version, backup path, rollback command, and whether a host restart or
  chat reload is needed;
- state clearly that nothing has been changed yet.

A "yes" to the table is not consent to apply. A blank answer means no upgrade.

## 4. APPLY — approved items only

- One item at a time. Save the old version and the relevant config backup first.
- Pinned npm package: upgrade only to the version shown in the table. If the
  available version changed since the table, stop and show the table again.
- Unpinned `npx`/`github:` spec: "upgrade" means pinning a version in `mcp.json`;
  that is a config edit and needs its own explicit approval.
- Hosted service: no local upgrade exists. Report only.
- Skills from an installer update through that installer's package, never by
  editing the installed `SKILL.md`. Kit skills update from the kit clone plus
  `install-kit.ps1`.
- Stop on the first failure. Do not continue to the next item.

## 5. VERIFY

For each applied item:

- re-read the installed `package.json` or skill folder and compare with the
  target version shown before approval;
- ask the user to reload the MCP server/host, then confirm through `tools/list`
  that the tools still resolve. The MCP host decides when a server reloads; this
  skill does not restart it.
- On mismatch: stop, show the rollback command and ask before reverting.

## 6. REPORT

`terse` by default: verdict, rows changed with versions before/after, what was
skipped, and what remains `UNVERIFIED`. Never report a failed or unrun upgrade as
success.

## Reference

- `docs/reference/mcp-server-sources.md` — source map, version identity and the
  dynamic discovery protocol this skill follows.
