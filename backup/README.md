# backup — a snapshot for recovery, not a second source of truth

Nothing here is loaded by VS Code, Copilot, or any agent. It exists so that a dead disk does not
destroy work that cannot be regenerated: the user memory files, and the audit scripts.

**The live copy is authoritative.** These files are stale the moment they are committed. Restore
from here only when the live copy is gone; never edit here and expect a change in behaviour.

| Folder | What it holds | Regenerable? |
|---|---|---|
| `user-memory/` | the three user memory files that load into every request (refreshed 2026-11-16) | **No** — collected from sessions |
| `../tooling/` | `verify-all.ps1`, `measure-context.ps1`, `who-locks.ps1` | No — authored |
| `../roster.json` | the delegation allowlist | No — a human decision |

**Repo memory is not here.** It is backed up instead by `tooling/workspace-sync.ps1 -RepoMemory`,
which mirrors it into the private workspace repository beside the program contracts. That is a
better home: repo memory is project fact, and the project it belongs to is there. Keeping a second
copy here would be a third place to forget to update.

Third-party skills and agents are **not** copied here, on purpose. `~/.agents/skills`,
`~/.copilot/skills` and the SAP AI Dev Toolkit are installed and upgraded by their own commands;
a copy in this repository would drift from the installer and mislead whoever reads it. Re-run the
installer instead.

**Why the folders are named this way.** `.gitignore` excludes `state/` for hook runtime state and
`memory/` because memory may carry system identifiers. Renaming to `tooling/` and
`backup/user-memory/` keeps both rules intact rather than punching holes in them, and keeps the
intent visible: one is authored tooling, the other is a snapshot of something else.

## Restore

Set `$kit` once, so this works wherever the repository was cloned.

```powershell
$kit = if ($env:ABAP_KIT_ROOT) { $env:ABAP_KIT_ROOT } else { Split-Path $PSScriptRoot -Parent }
```

### Read the diff before you overwrite, one file at a time

A snapshot is only as good as the day it was taken, and two of these files are not literal copies
of the live machine:

- **`arc-1-mcp.md` is sanitised on purpose.** The real `NODE_EXTRA_CA_CERTS` value contains a
  customer name, so the snapshot stores `"<absolute path to your CA bundle .crt>"` instead. This
  is the only line that differs from the machine it was taken on — verified 2026-11-16 by a full
  line-for-line comparison. Copying the live file over it would put that identifier back into a
  tracked file, which is the rule both files open by forbidding.
- **`memory-setup.md` is refreshed, and it has already been wrong once.** The snapshot committed on
  2026-11-15 (`b89c6b7`) still said hooks do not fire in this harness; that was disproved on
  2026-11-15 and the live file now carries a per-event table. Restoring that snapshot would have
  reinstated a false rule with no warning, because a restore prints nothing on success.

So diff, then restore only the file you need:

```powershell
$dst = "$env:APPDATA\Code\User\globalStorage\github.copilot-chat\memory-tool\memories"
Compare-Object (Get-Content "$kit\backup\user-memory\memory-setup.md") (Get-Content "$dst\memory-setup.md")
# read the diff — '<=' only in the snapshot, '=>' only live — then copy that one file
Copy-Item "$kit\backup\user-memory\memory-setup.md" $dst -Force
```

The `*.md` glob below is the recovery path when the whole folder is gone, not the normal one.

```powershell
# memory: overwrite the live copy (this is the destructive step — check first)
$dst = "$env:APPDATA\Code\User\globalStorage\github.copilot-chat\memory-tool\memories"
Copy-Item "$kit\backup\user-memory\*.md" $dst -Force

# scripts, plus the loan of the kit root that the live copies need in order to find the clone
$dst = "$env:USERPROFILE\.copilot\state"
Copy-Item "$kit\tooling\*.ps1" $dst -Force
Copy-Item "$env:USERPROFILE\.copilot\roster.json" "$env:USERPROFILE\.copilot\roster.json.bak" -Force
Copy-Item "$kit\roster.json" "$env:USERPROFILE\.copilot\roster.json" -Force
powershell -ExecutionPolicy Bypass -File "$kit\tooling\install-kit.ps1" -Force
```

The memory snapshot is faithful to the machine it was taken on: paths inside those notes name the
old clone location. Re-read them after restoring on a different machine rather than trusting them.

Note that `install-kit.ps1` also writes `~/.copilot/state/kit-root.txt`, which is how a live copy
finds the clone. Without it, `verify-all.ps1` reports `SKIP kit repository not found` for the two
sections that read the repository.

Then run `verify-all.ps1` — it reports drift between this repository and the live copies, so a
restore that went wrong shows up as `DRIFT`.

## Repo memory is not snapshotted here either

`…\workspaceStorage\<hash>\GitHub.copilot-chat\memory-tool\memories\repo\` holds workspace notes
that carry system ids and package names. They are not copied into this repository. Before deleting
one, take a local snapshot:

```powershell
$stamp = Get-Date -Format 'yyyyMMdd-HHmm'
$src = "$env:APPDATA\Code\User\workspaceStorage\<hash>\GitHub.copilot-chat\memory-tool\memories\repo"
Copy-Item "$src\*" "$env:USERPROFILE\.copilot\backups\repo-memory-$stamp" -Recurse -Force
```

That protects against an accidental delete, **not** against disk failure: it sits on the same
volume. Off-machine copies carry the customer-identifier question, which is a decision for the
owner of the data, not for this repository.

Repo memory costs almost nothing in context: measured in `extension.js`, only the **top-level
names** are injected per request (`getLocalRepoMemoryFiles` reads one directory, non-recursively),
and contents are read on demand. So size is not a reason to prune it; staleness and orphans are.

## What is deliberately not here

`mcp.json` and `settings.json` are not snapshotted. They hold internal hostnames, a real SAP user
id, and twelve `${input:...}` prompts that change when a destination is renamed. They are also
mostly regenerated by installers. Snapshot them by hand into your own encrypted storage if you
need them; this repository stays at zero credential-shaped hits, and `verify-all.ps1` section 8
enforces it.
