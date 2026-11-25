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
"NODE_EXTRA_CA_CERTS": "<path from the active connection config>"
```

Do not put a real CA path, host or user in memory or any tracked file. The path is read from the
active ARC-1 connection config; kit setup owns that detail. A working `abapfs` does not prove the
ARC-1 host is fine — they can be different landscapes.

**VS Code profiles:** `mcp.json` is profile-scoped. `Code\User\mcp.json` belongs to the default
profile; a profile with no own `mcp.json` inherits it only when `useDefaultFlags.mcp` is `true` for
that profile (both current profiles have `mcp=true`, verified 2026-11-23). Check that flag before
adding a duplicate entry. Reload + new chat — picker state can stay stale in an open chat.

**Launcher pattern (verified OK):** use the `sap-arc1-launcher.ps1` wrapper with `-Connection`,
not the docs' plaintext `SAP_USER`/`SAP_PASSWORD` form. Launcher reads `arc1-connections.json` +
Windows Credential Manager and exports the same `SAP_*` vars before `npx -y arc-1@latest serve`.
Check without starting: `-Check -NoProbe`.

Detail — the layers as a table, the TLS diagnosis ladder, every verified gotcha, and the
PowerShell 5.1 constraints: `<kit-root>/docs/reference/arc-1.md` (kit root: `$env:ABAP_KIT_ROOT`
or `~/.copilot/state/kit-root.txt`)
