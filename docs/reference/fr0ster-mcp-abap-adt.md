# fr0ster/mcp-abap-adt — comparison record

Status: **research only, 2026-11-18. Not installed.** Nothing here authorises adding the server.

## What was actually observed

| Source | How | Limit |
|---|---|---|
| Local `mcp.json`, `settings.json` | read files | config, not a live `tools/list` |
| `murbani.vscode-abap-remote-fs` `package.json` | read manifest | 68 contributed tools; only 13 are allowed by the agent |
| `~/.copilot/agents/abap-developer-by-pongg.agent.md` | read file | routing applies to that agent when active |
| `~/.copilot/roster.json`, kit `AGENTS.md` | read files | delegation and workspace principles |
| `fr0ster/mcp-abap-adt` README and tool docs | fetched upstream | generated docs dated 2026-11-16; not run locally |

In this chat only `adam` and `sap-docs` tools were live. `arc-1`, `gsd-120`, `ds4-900` and
the ABAP Remote FS extension were configured but not started here. Tool names below come from
configs and manifests, so treat them as declared, not as a verified live catalog.

## Local ABAP surface

| Server / source | Tools seen | Posture |
|---|---|---|
| `arc-1` (mcp.json) | `SAPRead`, `SAPSearch`, `SAPContext`, `SAPWrite`, `SAPActivate`, `SAPDiagnose`, `SAPQuery`, `SAPTransport`, `SAPGit`, `SAPLint`, `SAPManage` | writes on, transport writes on, packages `$TMP,Z*,Y*`; data preview and free SQL **off since 2026-11-18** |
| `adam` (mcp.json) | `abap_debug`, `abap_debug_session`, `abap_source`, `abap_search`, `abap_breakpoints` | external debugger, client 120 |
| `gsd-120` / `ds4-900` (mcp.json) | ADT tools via `adt-mcp-server/*` | destinations `GSD … DEV` / `LUF DS4 DEV`, clients 120 / 900 |
| ABAP Remote FS (extension) | `abapfs_get_object_source`, `abapfs_search_objects`, `abapfs_search_object_source`, `abapfs_run_atc_analysis`, `abapfs_run_sql_query`, `abapfs_analyze_dumps`, `abapfs_analyze_traces`, `abapfs_get_version_history`, debugger tools | 13 named tools allowed in the agent |
| `sap-docs` (mcp.json, HTTP) | `search`, `fetch`, `abap_feature_matrix`, `sap_search_objects`, `ui5_version_diff` | documentation only, no SAP system data |

ADT MCP reachability is a destination allowlist: `GSD`, `GSD_110…`, `GSD_120…`,
`SAPFreeTrial`, one UUID; object changes limited to `Z*`. It cannot reach every landscape from
every folder. A folder name never selects a system.

## fr0ster tool groups (upstream)

| Group | Examples from generated docs |
|---|---|
| Read-only repository | `GetClass`, `GetProgram`, `GetFunctionModule`, `GetTable`, `GetInclude`, `SearchObject`, `SearchSource`, `GetWhereUsed`, `GetPackageTree`, `GetObjectOutline`, `DescribeByList` |
| ATC | `RunATC`, `GetATCRunStatus`, `GetATCFindings`, `ListATCResults`, `GetATCResult` |
| Background runs | `GetBackgroundRun`, `ListBackgroundRuns`, `DiscardBackgroundRun` |
| Runtime diagnostics | `RuntimeGetDumpById`, `RuntimeListFeeds`, `RuntimeListSystemMessages`, `RuntimeGetGatewayErrorLog`, `RuntimeListProfilerTraceFiles`, `RuntimeGetProfilerTraceData` |
| Session (Streamable HTTP only) | `SessionOpen`, `SessionClose`, `state_handle` on every tool |
| Data tools (opt-in) | `GetSqlQuery`, `GetTableContents` — served only with `--enable-data-tools`; off by default |
| High-level write/CRUD | `CreateClass` / `UpdateClass`, `CreateProgram` / `UpdateProgram`, `ActivateObjects`, transport tools, RAP and CDS tools |

Upstream docs report 73 read-only and 188 high-level tools; the compact variants are a separate
tool shape. Those are upstream figures at the doc date, not local measurements.

## Overlap and simultaneous-picking risk

Redundancy grade is the chance of picking the wrong server times the cost of a wrong result.

| Local capability | fr0ster equivalent | Grade | If called together |
|---|---|---|---|
| `SAPRead`, `abapfs_get_object_source`, ADT source read | `GetClass` / `GetProgram` / `GetTable` | high | duplicate ADT GETs; active vs inactive vs workingArea may differ |
| `SAPSearch`, `abapfs_search_objects` | `SearchObject` | high | two snapshots; a later read may use the wrong one |
| `SAPContext`, `abapfs_analyze_object_relations` | `GetWhereUsed` | high | heavy where-used run twice; sessions consumed |
| `abapfs_search_object_source` | `SearchSource` | high | whole-package scans duplicated |
| `SAPDiagnose(atc)`, `abapfs_run_atc_analysis`, ADT ATC | `RunATC` + `GetATCFindings` | high | worklist id and run id are different things; mixing them gives a wrong verdict |
| `SAPQuery`, `abapfs_run_sql_query` | `GetSqlQuery` (opt-in) | high | fr0ster deliberately off; local was on until 2026-11-18 |
| data preview | `GetTableContents` (opt-in) | high | same policy gap; SAP API Policy FAQ v1.3 Q33 cautions on ADT data access |
| dump / trace tools | `RuntimeGetDumpById`, profiler tools | medium | dump ids and trace ids are not interchangeable |
| debugger tools | fr0ster debugger set | medium | debugger listener is per user; one session at a time |
| `SAPTransport` read | `GetTransport`, `ListTransports` | medium | transport state can change between reads |
| `SAPWrite`, `SAPActivate` | high-level CRUD, `ActivateObjects` | medium | ADT lock serialises concurrent writes; sequential read-modify-write still loses updates |
| `sap-docs.*` | none | low | documentation only |
| none | background-run tools, `SessionOpen` / `SessionClose` | low | fr0ster-only; `run_handle` answers are one-shot |

No race condition was observed locally. The concrete hazards are a lost update, duplicate SAP
work, different snapshots being read as one fact, and a wider data policy than intended.

## Local compensating controls

| Mechanism | Evidence | Coverage |
|---|---|---|
| Agent `tools:` allowlist | `arc-1/*`, `sap-docs/*`, `adt-mcp-server/*`, 13 explicit extension tools | one agent, active session only |
| Routing table in agent file | first choice plus "do not use" per task | same agent |
| `one object, one writer, one session` | agent file | write path |
| `roster.json` | human-maintained allowlist | delegation |
| `mcp-surface-audit` skill | procedure to regenerate the surface from live config | on demand |
| `AGENTS.md` principle | one server per task, no silent fallback | all sessions in this workspace |
| `verify-all.ps1` | skill-name and mirror checks | names, not live tool calls |
| Server-side | ADT destinations, `Z*` package ceiling, ARC-1 `-Allow*` flags | SAP call level |

fr0ster ships `--deny-actions` and client rule examples (`.clinerules`, `.cursor/rules`) but no
agent/skill engine. None of those client rule files exist locally. The local compensation is
agent + skill + roster + gate, which only fires while that agent is active.

## Decision recorded 2026-11-18

- Do not install fr0ster now. Local tools already cover repository reads, search, ATC, dumps,
  traces, debugger, transport and SQL; adding 188 + 73 tools costs context without a new job.
- Keep `SAP_ALLOW_FREE_SQL` and `SAP_ALLOW_DATA_PREVIEW` false. The kit template already ships
  false; the local `mcp.json` had drifted to true and was set back.
- If fr0ster is ever added: use a `-ro` binary, leave `--enable-data-tools` unset, set
  `--deny-actions` for tools that duplicate the local primary, and never pair it with ARC-1 as
  writer on the same object.
- Re-derive upstream tool names from the repo before acting on this page. Generated docs can move.
