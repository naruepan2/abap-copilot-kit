# sap-docs MCP - usage

Read on demand. The task-to-tool table lives in `agents/abap-developer-by-pongg.agent.md`;
this file explains the tools and their limits.

Server key in `%APPDATA%\Code\User\mcp.json`:

```json
"sap-docs": {
  "type": "http",
  "url": "https://mcp-sap-docs.marianzeis.de/mcp"
}
```

Public, read-only, no API key and no login. It reaches SAP documentation sources, not an SAP
system. It never replaces a confirmed system/client or a live metadata check.

Tool names below were read from the live `tools/list` on 2026-11-18. Recheck `tools/list` after
a server upgrade; a README is not authoritative.

## Core pattern

1. `search(query, ...)` to discover document IDs.
2. `fetch(id)` to read the full document.

Query in English: the corpus and ranking are primarily English. Start broad with `search`; only
then narrow.

| Parameter | Use |
|---|---|
| `query` | English terms. Use product names, error text, or task terms. |
| `k` | Number of results. Default is usually enough; raise when the topic is broad. |
| `includeOnline` | `true` adds SAP Help, SAP Community and Software Heroes. Default is on. Set `false` for offline-only, reproducible searches. |
| `sources` | Restrict offline libraries, e.g. `abap-docs-cloud`, `sap-styleguides`, `ui5`, `cap`, `btp-cloud-platform`. Use when a cross-source result is ambiguous. |
| `abapFlavor` | `standard`, `cloud` or `auto`. Filters the official ABAP docs while keeping other sources. |
| `includeSamples` | Set `false` to remove sample-heavy sources when looking for reference text. |

`fetch` returns text plus metadata and source URL. SAP Help and Community fetches are capped
(about 75,000 characters by default); check `metadata.truncation` before claiming the document
was read whole.

## Specialized tools

| Tool | Use it for | Do not use it for |
|---|---|---|
| `sap_community_search` | A specific error message, workaround, or real-world symptom that `search` did not answer | General documentation lookup - start with `search` |
| `abap_feature_matrix` | Whether an ABAP feature exists in 7.40-LATEST | Runtime capability of the target system - verify in SAP |
| `sap_search_objects` | Released SAP objects by topic, component or Clean Core level | Documentation content or code examples |
| `sap_get_object_details` | Release state and Clean Core level of one named object | The target system's actual object state |
| `sap_discovery_center_search` | BTP service discovery by keyword, category or license | ABAP/UI5 documentation |
| `sap_discovery_center_service` | BTP service pricing, roadmap and links | A service instance in your own subaccount |
| `ui5_version_diff` | Features, fixes and deprecations between UI5 versions | General UI5 API reference - use `search` |

For Clean Core decisions, `sap_search_objects` and `sap_get_object_details` read a public release
state repository. Treat the result as authoritative public release data, but still confirm the
target release and released-API status in the connected system before writing code.

## Examples

ABAP Cloud syntax:

```
search(query="ABAP Cloud MODIFY ENTITIES draft RAP", sources=["abap-docs-cloud","abap-cheat-sheets"])
fetch(id=<id from search>)
```

A specific community error:

```
sap_community_search(query="CX_SY_DYN_CALL_ILLEGAL_METHOD RFC call", k=10)
```

Feature availability:

```
abap_feature_matrix(query="inline declaration", limit=10)
```

UI5 upgrade:

```
ui5_version_diff(from_version="1.108.0", to_version="1.130.0", library="SAPUI5")
```

## Configuration rules

- Declare `sap-docs` in the VS Code user `mcp.json` only. Do not add the same server key to
  `~/.copilot/mcp-config.json`: VS Code imports that file by default and a duplicate name is
  silently disabled (see `verify-all.ps1` section 8b).
- No credentials belong in this entry. The hosted server is public and read-only.
- The tools picker is per session. Adding the config does not prove the tools are callable; after
  a window reload, confirm `sap-docs` appears in the Chat tools picker and observe `tools/list`
  before writing a routing row that depends on it.

## Sources and attribution

The server indexes official SAP and community documentation plus curated tutorials. Search and
fetch results link to original documents and retain upstream licence notices. Cite the returned
URL when a documentation claim matters; do not paraphrase a result without its source.
