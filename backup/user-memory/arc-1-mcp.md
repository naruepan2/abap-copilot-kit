# ARC-1 MCP server (arc-mcp/arc-1)

Three layers, updated differently: the npm runtime self-resolves, the plugin package needs
`copilot plugin update` **with VS Code closed** (os error 32 otherwise), and the skills need
`npx skills add`. Refreshing skills matters most — they are what load into the prompt, and a new
skill loads only in a new chat session. Keep it current with `~\.agents\arc1-update.ps1`
(`-CheckOnly` to report only); monthly is plenty since ARC-1 ships every 1-3 days.

**TLS when a self-signed SAP cert breaks every call** (everything fails as "network error"): use
a CA bundle, never `SAP_INSECURE=true` — that accepts any certificate and masks a MITM.

```jsonc
"SAP_INSECURE": "false",
"NODE_EXTRA_CA_CERTS": "<absolute path to your CA bundle .crt>"
```

A working `abapfs` does not prove the ARC-1 host is fine — they can be different landscapes.

Detail — the layers as a table, the TLS diagnosis ladder, every verified gotcha, and the
PowerShell 5.1 constraints: `D:\abap-copilot-kit\docs\reference\arc-1.md`
