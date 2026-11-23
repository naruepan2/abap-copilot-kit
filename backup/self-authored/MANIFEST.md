# Self-authored backup — file manifest

Snapshot: **2026-11-23.** Source paths use `~` notation, not machine-specific absolute paths.
Live copies are authoritative. Restore only when the live copy is gone. Never edit the snapshot to change behaviour.

## Snapshot contents

| group | source (live) | snapshot | files |
|---|---|---|---:|
| agents | ~/.copilot/agents | backup/self-authored/agents | 5 |
| copilot-skills | ~/.copilot/skills | backup/self-authored/copilot-skills | 14 |
| agent-skills | ~/.agents/skills | backup/self-authored/agent-skills | 34 |

## Excluded on purpose

- third-party skills/agents from npx and SAP AI Dev Toolkit (reinstall with their installers);
- `mcp.json`, credentials, connections, `Projects/`, SAP data, and any config containing host/user/transport identifiers;
- extension-contributed tools.

## Integrity

Each entry is copied byte-for-byte. To verify a restore target, compare a single file hash before copying it back:

```powershell
$h1 = (Get-FileHash "~\.copilot\agents\<name>.agent.md" -Algorithm SHA256).Hash
$h2 = (Get-FileHash "<kit>\backup\self-authored\agents\<name>.agent.md" -Algorithm SHA256).Hash
$h1 -eq $h2
```

