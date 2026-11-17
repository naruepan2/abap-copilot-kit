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

## Live verification - abap-docs-cloud, 2026-11-18

Confirmed through the VS Code Copilot harness after the tools picker was enabled:

```
search(query="ABAP Cloud", k=30, includeOnline=false, sources=["abap-docs-cloud"])
```

Returned 30 results, all `library_id=/abap-docs-cloud`. Then:

```
fetch(id="/abap-docs-cloud/ABENABAP_CLOUD_GLOSRY")
```

Returned the full document (2,259 characters) with title, source URL and metadata. Tool binding
works; no API key or login was needed. This is evidence that the picker selection works, not a
permanent capability claim - recheck `tools/list` after a server upgrade.

### 30 references returned

All URLs follow `https://help.sap.com/doc/abapdocu_cp_index_htm/CLOUD/en-US/<topic>.html`, unless
shown as a full URL below. `#` is result rank and `score` is the fused retrieval score.

| # | Topic (document id suffix) | Score | What the snippet showed |
|---:|---|---:|---|
| 1 | `ABENABAP_CLOUD_GLOSRY` | 0.1115 | Definition: cloud-ready ABAP model, RAP, restrictions vs classic |
| 2 | `ABENS4_HANA_CLOUD_ABAP_ENV_GLOSRY` | 0.1097 | Restricted ABAP environment, embedded Steampunk, S/4HANA Cloud editions |
| 3 | `ABENABAP_LANGUAGE_VERSIONS` | 0.1015 | Two language versions: ABAP for Cloud and Restricted ABAP |
| 4 | `ABENABAP_VERSIONS_AND_APIS` | 0.1000 | Classic vs Cloud: language-version and released-API restrictions |
| 5 | `ABAPMESSAGE` | 0.0985 | `MESSAGE`: only `INTO` variant in ABAP for Cloud |
| 6 | `ABENDOC_OVERVIEW` | 0.0968 | Where ABAP Cloud Keyword Documentation sits relative to the ABAP Cloud Guide |
| 7 | `ABAPCOMMIT_ROLLBACK_CONNECTION` | 0.0957 | `COMMIT/ROLLBACK CONNECTION` variant available in ABAP Cloud |
| 8 | `ABENABAP_TECHNO_GLOSRY` | 0.0926 | ABAP technology supports both Cloud and classic paradigms |
| 9 | `ABAPFUNCTION` | 0.0917 | Local interface excerpt from a function module example |
| 10 | `ABENSAP_S4HANA_CPRIV_GLOSRY` | 0.0906 | S/4HANA Cloud Private Edition, ABAP Cloud or classic |
| 11 | `ABAPIF` | 0.0880 | `IF` statement syntax excerpt |
| 12 | `index` | 0.0871 | ABAP Cloud language reference index page |
| 13 | `ABAPDERIVED_TYPES_INFO` | 0.0868 | BDEF derived types related to message handling |
| 14 | `ABENABAP_DEV_ENVIR_GLOSRY` | 0.0863 | Development environment for repository objects |
| 15 | `ABENDOCCOMMENT` | 0.0859 | `doccomment` language-reference entry |
| 16 | `ABENAMDP_CS_ABEXA` | 0.0851 | AMDP SQLScript example, client-safe, ABAP for Cloud |
| 17 | `ABENABAP` | 0.0805 | Keyword documentation scope for AS ABAP |
| 18 | `ABENCDS_FUNC_CLIENT_DEP_CS_ABEXA` | 0.0788 | Client-dependent CDS table function example, ABAP for Cloud |
| 19 | `ABENCONTROLLING_SAP_LUW` | 0.0772 | Controlled SAP LUW and `CL_ABAP_TX` |
| 20 | `ABENSTANDARD_ABAP_GLOSRY` | 0.0759 | Standard ABAP glossary entry |
| 21 | `ABAPSAVER_CLASS_CLEANUP_FINALIZE` | 0.0759 | RAP saver method `cleanup_finalize`, save sequence |
| 22 | `ABENSAP_S4HANA_CPUB_GLOSRY` | 0.0753 | S/4HANA Cloud Public Edition, ABAP Cloud governed |
| 23 | `ABENDDIC_V5` | 0.0753 | DDIC data elements/structures/tables in BTP and S/4HANA Cloud ABAP |
| 24 | `ABENEMBEDDED_STEAMPUNK_GLOSRY` | 0.0744 | Embedded Steampunk glossary entry |
| 25 | `ABENBUILTIN_ABAP_TYPE_GLOSRY` | 0.0741 | Built-in ABAP type glossary entry |
| 26 | `ABENGENERIC_ABAP_TYPE_GLOSRY` | 0.0733 | Generic ABAP type glossary entry |
| 27 | `ABAPINTERFACES` | 0.0725 | `INTERFACES` statement syntax |
| 28 | `ABAPCASE` | 0.0717 | `CASE` statement syntax |
| 29 | `ABAPINTERFACE` | 0.0710 | `INTERFACE` statement syntax |
| 30 | `ABENBDL_AUTHORIZATION_ABEXA` | 0.0708 | Authorization check in an unmanaged RAP BO example |

Example full URL for rank 1:
`https://help.sap.com/doc/abapdocu_cp_index_htm/CLOUD/en-US/ABENABAP_CLOUD_GLOSRY.html`
Use `fetch(id="/abap-docs-cloud/<topic>")` for the full text of any row.

## Sources and attribution

The server indexes official SAP and community documentation plus curated tutorials. Search and
fetch results link to original documents and retain upstream licence notices. Cite the returned
URL when a documentation claim matters; do not paraphrase a result without its source.
