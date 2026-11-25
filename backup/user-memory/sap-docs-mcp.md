# sap-abap-docs MCP - public SAP documentation

Server key: `sap-abap-docs` in VS Code user `mcp.json` (HTTP, public, read-only, no login or key).
Verified 2026-11-23 with the live `tools/list`: `search`, `fetch`, `abap_lint`,
`abap_feature_matrix`, `sap_community_search`, `sap_search_objects`, `sap_get_object_details`,
`sap_discovery_center_search`, `sap_discovery_center_service`.
Call tools with the prefix this session exposes; `docs.*` in agent/skill files is a logical alias,
not a callable prefix. `ui5_version_diff` is no longer configured — use `@ui5/mcp-server` when
enabled, otherwise `web`.

Use `search` first, then `fetch(id=...)` for full text. Query in English. `includeOnline=true`
adds SAP Help, SAP Community and Software Heroes; `sources` narrows offline libraries.
Use `sap_community_search` for a specific error or workaround, `abap_feature_matrix` for release
availability, `sap_search_objects` / `sap_get_object_details` for Clean Core release state, and
Discovery Center tools for BTP services. `abap_lint` checks documentation rules, not target ATC.

This server reads public documentation, not SAP system data. It does not replace the confirmed
system/client rule or live SAP metadata checks.

Live-tested 2026-11-18 after tools-picker enable: `search(query="ABAP Cloud", k=30,
includeOnline=false, sources=["abap-docs-cloud"])` returned 30 results; `fetch(id=...)` returned
the full document with its SAP Help URL. The 30-result reference list is in
`docs/reference/sap-docs-mcp.md`. Both calls work through the VS Code Copilot harness.

Knowledge-source precedence (live SAP > public docs > web > model knowledge) and the task table
live in `docs/tool-routing.md` and the ABAP Developer agent in the public kit repo (kit root from
`$env:ABAP_KIT_ROOT` or the `~/.copilot/state/kit-root.txt` pin). Full tool
usage: `docs/reference/sap-docs-mcp.md`. Re-check `tools/list` after server upgrades.
