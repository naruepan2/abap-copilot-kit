---
name: sap-data-verify
description: >-
  Verify that an ABAP program/report/transaction or Fiori-OData app processes and displays data correctly by reading real rows via ARC-1, Clean-Core-first. Prefer C1/C2-released CDS views (e.g. I_SalesDocument) over raw tables (VBAK); check release state with SAPRead(type=API_STATE). Freestyle SQL (SAPQuery) needs SAP_ALLOW_FREE_SQL=true; table/CDS preview (SAPRead TABLE_CONTENTS/TABLE_QUERY) needs SAP_ALLOW_DATA_PREVIEW=true. If a gate is closed, STOP, explain both flags, and ask whether to enable one or both before reading data. Use to check data behind a program, verify ALV/report or Fiori output against the database, compare rows with the screen, or validate totals.
argument-hint: "[program/table/CDS name] [suspect value or key]"
---

# SAP Data Verification — Clean-Core-First (read-only)

Read logic → derive expected output → read actual rows → compare → report with evidence.
**Strictly read-only; never enables flags itself; Clean Core by default.** Respond in the
user's language. Client config/restart: see Appendix V.

## 0. Safety (non-negotiable)

1. SELECT only. No DML/DDL/native SQL/`CALL`/`SUBMIT`; one statement; no `INTO`/`APPENDING`/
   `PACKAGE SIZE`/`UP TO … ROWS` (ARC-1 appends the row cap).
2. Never enable flags yourself. Prepare the exact env change; apply only with explicit
   consent; restart required. Shared/BTP server → hand to admin.
3. Respect every deny layer: `SAP_BLOCKED_DATA_SOURCES`, `SAP_DENY_ACTIONS`, CDS DCL, SAP
   auth. Never suggest disabling a control to make a query run.
4. Built-in gated tools only. `Custom_*` plugins can raw-GET outside the data gates —
   never route around a closed gate through them.
5. **Clean Core:** prefer released APIs; never use `noAPI` patterns (e.g. RFC_READ_TABLE-style
   raw dumps) or unreleased objects when a released successor exists. Minimize and mask
   personal/credential data; no bulk extracts into chat.
6. PROD: prefer DEV/QA, tight WHERE + small maxRows; note SAP API Policy FAQ Q33 (a technical
   flag is not a policy allowance; integration should use published business APIs).
7. Empty result ≠ no data (client/DCL/exit/filter). Code ≠ spec: requirement/KTD first;
   without one, report "matches code", not "correct".

## 1. Gates & capability model

| Capability | Call | Server flag, default false | HTTP scope |
|---|---|---|---|
| Freestyle ABAP SQL | `SAPQuery(action="sql", sql, maxRows)` | `SAP_ALLOW_FREE_SQL=true` | sql, implies data |
| Unfiltered sample | `SAPRead(type="TABLE_CONTENTS", name, maxRows)` | `SAP_ALLOW_DATA_PREVIEW=true` | data |
| Structured table/CDS query | `SAPRead(type="TABLE_QUERY", name, columns, where, maxRows)` | `SAP_ALLOW_DATA_PREVIEW=true` | data |
| Long text or SLG1 log | `SAPQuery(action="long_text"/"application_log")` | `SAP_ALLOW_DATA_PREVIEW=true` | data |
| odata_perf or authorization_trace | `SAPDiagnose(...)` | `SAP_ALLOW_DATA_PREVIEW=true` | data |
| Source, search, deps, DCLS, API_STATE, dumps | `SAPRead`, `SAPSearch`, `SAPContext`, `SAPDiagnose` | none | read |

Permission = server flag AND user scope AND SAP auth. SAP 403 after flags on means auth
(SU53), not flags. FREE_SQL alone does not unlock TABLE_* — they are separate flags. For full
verification, both are needed.

Reads are never package-gated. SAP auth (`S_TABU_NAM`, `S_TABU_DIS`, `S_ADT_RES`) and CDS DCL
govern reads. DCL applies at the SQL entry-point entity, not inherited from base views.

Backend: preview 7.40 SP05; SQL console 7.40 SP08; TABLE_QUERY on CDS 752+. TABLE_CONTENTS
uses the DDIC endpoint; SAPQuery and TABLE_QUERY use the freestyle endpoint. Flags are read at
startup. maxRows defaults to 100 and clamps at 10,000; 2 MiB cumulative per call
(`DATA_RESPONSE_TOO_LARGE`); about two concurrent data calls per process — run data queries
sequentially.

## 2. Phase 0 — gate check, always first

Probe. Do not ask the user for flag values you can test.

0a. Preflight `SAPRead(type="SYSTEM")`. It returns the user whose auth applies. On failure,
    stop; startup auth preflight 401/403 blocks all tools, so fix credentials and restart.
    Optional: `SAPRead(type="COMPONENTS")` for the release.
0b. Schema signal: SAPQuery absent, or TABLE_* absent from the SAPRead enum, means gate closed.
0c. Clean-Core probes on a released CDS view, tiny:

```
SAPRead(type="TABLE_QUERY", name="I_Currency", maxRows=1)
SAPQuery(action="sql", sql="SELECT COUNT(*) AS CNT FROM I_Currency", maxRows=1)
```

Fallback only if the backend lacks CDS preview (404/unsupported): `TABLE_CONTENTS T000
maxRows=1`. Label it a technical connectivity probe, not a data-access pattern; T000 is not
released for direct use. If the probe source is blocklisted, ask the admin which released
sources are permitted.

| Result fragment | Layer | Action |
|---|---|---|
| success | open | proceed |
| `allowDataPreview=false` / `allowFreeSQL=false` | flag OFF | §3 ask |
| Insufficient scope for data or sql | scope missing | admin grants viewer-data, viewer-sql, developer-sql, or the BTP Data Viewer role |
| SAP 403 or no authorization | SAP role | SU53 then PFCG; try a released alternative |
| `DATA_SOURCE_BLOCKED`, `DATA_LINEAGE_UNRESOLVED`, `DATA_SQL_UNSUPPORTED`, `DATA_POLICY_UNAVAILABLE` | blocklist, gate open | respect; provable/permitted source or stop |
| 404 on datapreview path | backend too old | fallback or report prerequisite |

Matrix: both open → full. Preview only → per-table reads; ask to add SQL for joins/totals.
SQL only → SAPQuery; TABLE_* stays closed. Both closed → **STOP, §3**. Source-only analysis
may run, labeled "code-only". Re-probe each task and after any config change.

## 3. Gate closed — inform and ask, do not proceed

State what was detected. Offer:

- **A** — preview only; enables TABLE_CONTENTS and TABLE_QUERY.
- **B** — free SQL only; enables SAPQuery.
- **C** — both; recommended for full verification.

Explain that both stay read-only, and that SAP auth and DCL still apply. Give the exact env
edit and restart from Appendix V. Wait for the choice. If declined, offer code-only analysis
and state what cannot be verified. After change and restart, re-probe.

## 4. Clean Core source selection

Levels: **A** released APIs only; **B** Classic API from the Cloudification Repository;
**C** unclassified, conditional; **D** noAPI or modification — never.

Ladder for every data source:

1. **Released CDS view or API first, Level A.** Find candidates with `SAPSearch` on I_* or
   C_*, the program's own CDS stack, or `SAPContext(action="impact", type="DDLS")`. Confirm
   with `SAPRead(type="API_STATE", name="<view>")` → contract C1/C2 means released. If a
   successor is reported, use it. Read fields with
   `SAPRead(type="DDLS", include="elements")` and row security with `SAPRead(type="DCLS")`.
2. **Classic table only as a flagged exception** when no released view covers the need, or a
   like-for-like comparison against a classic program requires it. Record the justification.
3. Never noAPI or modification patterns; never raw dumps.

Semantics: released CDS uses camelCase aliases (SalesDocument, not VBAK's VBELN), carries
currency/quantity semantics, derivations and DCL. Rows may legitimately differ from the raw
table. When verifying a classic program that reads VBAK directly, prefer the released view;
if semantics diverge, do the classic read as a justified exception and say so. Optional
governance: `SAPDiagnose(action="atc", type, name, variant="<cloud-readiness variant>")`.

## 5. Phase 1 — expectation from code, no flags needed

Collect object, output to verify, keys, system and client. TCODE → `SAPRead(TRAN)`;
`SAPContext(action="deps")` → KTD and contracts. Find sources with
`SAPRead(PROG, grep="SELECT|FROM|JOIN|SUM|COUNT")`, class methods, function groups with
includes, or `SAPSearch(source_code)` on 751+. Prefer `SAPSearch(tadir_lookup)` over long
TADIR IN-lists. Fiori: SRVB → SRVD → DDLS.

Freshness: `[cached:revalidated]`; non-PP instances may serve a draft about 120 s after
activation, so use `force_refresh=true`. Check INACTIVE_OBJECTS and object_state for
impossible results. Output an expectation table: key → expected → requirement or code →
source plus filter plus aggregation.

## 6. Phase 2 — read data, cheapest first

| Need | Call | Gate |
|---|---|---|
| sample | TABLE_CONTENTS maxRows=20 | preview |
| filtered rows and columns | TABLE_QUERY, preferred single-source | preview |
| JOIN, COUNT, SUM, GROUP BY, subquery | SAPQuery sql | free SQL |
| count before fetch | SAPQuery SELECT COUNT(*) | free SQL |
| program log or long text | SAPQuery application_log or long_text | preview |

TABLE_QUERY on a released view:

```
SAPRead(type="TABLE_QUERY", name="I_SalesDocument",
  columns=["SalesDocument","CreatedByUser","SalesDocumentType","TotalNetAmount","TransactionCurrency"],
  where=[{"field":"SalesDocument","op":"=","value":"0000012345"},
         {"field":"CreationDate","op":">=","value":"20260101"}], maxRows=100)
```

Classic exception, only if §4 allows: same call with name VBAK and columns VBELN, ERDAT,
AUART, NETWR, WAERK.

Operators: =, !=, <>, <, <=, >, >=, LIKE, NOT LIKE, IN, NOT IN, IS NULL, IS NOT NULL,
STARTS_WITH with literal prefix. Conditions are ANDed. IN takes bare comma-separated values.
columns and where are TABLE_QUERY-only; never use legacy sqlFilter. CDS needs 752+ and DCL
applies.

SAPQuery uses the ABAP SQL dialect with a released entity as source:

```
SAPQuery(action="sql",
  sql="SELECT h~SalesDocument, h~TotalNetAmount, SUM( i~NetAmount ) AS items_total
       FROM I_SalesDocument AS h INNER JOIN I_SalesDocumentItem AS i
         ON i~SalesDocument = h~SalesDocument
       WHERE h~SalesDocument = '0000012345'
       GROUP BY h~SalesDocument, h~TotalNetAmount", maxRows=100)
```

Works: ORDER BY f ASCENDING or DESCENDING; maxRows; alias~field; one SELECT; aggregates with
full GROUP BY. Fails: ASC or DESC; LIMIT; alias.field; multiple statements, semicolon, INTO,
APPENDING, PACKAGE SIZE, UP TO … ROWS; missing non-aggregated field in GROUP BY. Avoid host
variables, comments, dynamic FROM, CLIENT SPECIFIED, WITH PRIVILEGED ACCESS and native-DB
functions. The connected client applies implicit MANDT; IN is auto-chunked.

Response fields: rows, rowsReturned, rowLimitReached, sapReportedTotalRows (diagnostic only —
confirm with COUNT(*)), queryExecutionTimeMs, executedQueryString (quote as evidence). On
DATA_RESPONSE_TOO_LARGE, use fewer columns/rows or key-range paging. On timeout, narrow WHERE
instead of looping lower maxRows. Sequential calls only.

## 7. Phase 3 — verify before blaming the program

Check, in order: client mismatch; ALPHA, date, currency, unit and language exits; DCL or
S_TABU filtering, comparing via the same CDS entity the program uses; INNER versus LEFT OUTER
or empty FOR ALL ENTRIES driver; active versus inactive version; aggregation window;
released-view versus raw-table semantics. Only then call the data wrong. Helpers:
`SAPDiagnose` for dumps, gateway_errors, odata_perf, cds_sql, unittest and authorization_trace;
SU53; `SAPRead(MSAG)`; application_log. Items needing preview are marked below.

## 8. Errors

| Symptom | Action |
|---|---|
| allowDataPreview or allowFreeSQL false | §3 ask |
| Insufficient scope | admin grants scope, profile or role; do not edit server env for one user |
| SAP 403 | SU53 then PFCG; released alternative |
| `DATA_SOURCE_BLOCKED` | respect; permitted source or stop |
| `DATA_SQL_UNSUPPORTED` | one static SELECT or WITH, or TABLE_QUERY where/columns |
| `DATA_LINEAGE_UNRESOLVED`, `DATA_POLICY_UNAVAILABLE` | report reason and path; provable source, no blind retry |
| `DATA_RESPONSE_TOO_LARGE` | fewer columns/rows; key-range paging |
| legacy sqlFilter, or `!=` on 758 | TABLE_QUERY where; use `<>` |
| ASC, DESC, LIMIT | ASCENDING, DESCENDING, maxRows |
| 404 datapreview; TABLE_QUERY fails but TABLE_CONTENTS works | backend prerequisite; fallback or report |
| bare 403 only on SQL-bearing calls | possible WAF; admin; SAP_GZIP_DATAPREVIEW_BODY only when admin approves |
| empty ADT HTML | error, never zero rows |
| startup auth preflight 401 or 403 | fix credentials and restart |
| 0 rows but data must exist | §7 checklist |

Blocklist active: TABLE_CONTENTS unfiltered only; TABLE_QUERY catalog checks need the
freestyle endpoint and fail closed. Never ask to remove entries to run a query.

## 9. Report, in the user's language

Verdict with evidence table: expected vs actual, exact call or executedQueryString, rows.
Then root cause from §7, Clean Core compliance (released C1/C2 sources vs classic exception
with justification; any Level D avoided), coverage and limits (rowLimitReached, filters,
client, DCL, sapReportedTotalRows caveat, not verified), and next steps. Never auto-execute
next steps. Mask sensitive values; summarize, do not paste large row sets.

---

## Appendix V — VS Code / GitHub Copilot on this machine

Observed 2026-11-18: the live VS Code MCP config is
`%APPDATA%\Code\User\mcp.json`, under `servers.sap.env` when the server is named `sap`.
On this machine the ARC-1 server is named `arc-1`, so the same flags live under
`servers.arc-1.env`. That is the file to read; a workspace `.vscode/mcp.json` is not the
current source of truth here.

The kit template `config-templates/mcp.json.template` already ships both data flags as
`false`. The live config was set back to `false` on 2026-11-18. A data-verification task must
probe §2 first and STOP at §3 if closed. This skill never flips the flags.

To enable, with explicit user consent only:

1. In `%APPDATA%\Code\User\mcp.json`, set `SAP_ALLOW_DATA_PREVIEW` and/or
   `SAP_ALLOW_FREE_SQL` to `true` under the relevant server's `env`.
2. Restart via **MCP: List Servers → sap → Restart**, or reload the window and start a new
   session. Flags are read at startup only.
3. Re-run the §2 probes. Do not trust the old result.

Editor-format example using an input prompt:

```json
{
  "servers": {
    "sap": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "arc-1@latest"],
      "env": {
        "SAP_URL": "https://<host>:44300",
        "SAP_USER": "<user>",
        "SAP_PASSWORD": "${input:sap-password}",
        "SAP_CLIENT": "<client>",
        "SAP_ALLOW_DATA_PREVIEW": "false",
        "SAP_ALLOW_FREE_SQL": "false"
      }
    }
  },
  "inputs": [
    { "type": "promptString", "id": "sap-password", "description": "SAP Password", "password": true }
  ]
}
```

A `.vscode/mcp.json` entry using `${input:…}` is not forwarded to Copilot-harness sessions;
there prefer a workspace-root `.mcp.json` with `${SAP_*}` host-env references and no inputs,
and enable `chat.mcp.workspaceRootConfig.enabled`.

Verify with `/sap-data-verify` in Agent chat. Admin checks: `arc1 config show` and
`arc1 tools SAPQuery`.
