# Ownership

Which files you may change, and how to prove it rather than guess.

## Three classes

| Class | How to recognise it | Editing |
| --- | --- | --- |
| **User-owned** | filename ends `-by-pongg.agent.md`; or the skill lives in this kit's `skills/` folder | freely |
| **Lock-tracked** | listed in `~/.agents/.skill-lock.json` | allowed, but the next `skills update` overwrites it |
| **Installer-owned** | listed in `~/.copilot/.sap-ai-dev-toolkit-assets.json` | do not; a reinstall replaces the file and stops updating it once modified |

## Why the filename suffix exists

Installed agent files and hand-written ones live in the same folder. Adding `-by-pongg` to the
ones you own makes the boundary visible at a glance and in a file listing, without needing to
open anything.

It has a second effect: the installer's reconciliation matches by filename, so a suffixed file
is a *new* file to it, not a modified one. Your file is left alone on reinstall instead of being
reported as needing manual review.

## Prove ownership by hash, not by name

Names can be copied. The installer's manifest records a SHA-256 per file it installed, so the
hash is the fact and the name is a hint.

```powershell
$j   = Get-Content "$env:USERPROFILE\.copilot\.sap-ai-dev-toolkit-assets.json" -Raw | ConvertFrom-Json
$rel = 'agents\abap-developer.agent.md'
$f   = Join-Path "$env:USERPROFILE\.copilot" $rel

if (-not $j.files.$rel) { 'not installer-tracked' }
elseif ($j.files.$rel -eq (Get-FileHash $f -Algorithm SHA256).Hash.ToLower()) { 'installer-owned, unmodified' }
else { 'installer-owned, modified — this file no longer receives updates' }
```

## Skills are a separate problem

A skill's folder name must match the `name` in its frontmatter, and the skills CLI keys its
lock file by folder name. Renaming a skill folder to mark ownership therefore breaks both skill
loading and updating.

**So do not rename skills.** Record ownership in a registry instead, and when you want to
customise a lock-tracked skill, copy it to a new folder name and treat the copy as user-owned.

| Group | Edit |
| --- | --- |
| Skills in this kit's `skills/` folder | yes — the folder is the list, so a new skill needs no registry edit |
| Skills with no upstream source | yes — nothing overwrites them |
| Lock-tracked skills | editable, overwritten on update |
| Installer-owned skills (SAP AI Dev Toolkit) | no — a reinstall replaces them |

## What an edit to an installer-owned file costs

Say this out loud before doing it:

1. The file is reported as "needs manual review" on every future install.
2. The installer stops overwriting it, so you no longer receive upstream changes to that file.
3. You become responsible for merging upstream changes by hand, forever.

If the user still wants it, do it — and record the decision next to the file.

## Before changing any agent or skill

Ask in one message:

1. Which agent is active in this session?
2. Confirm the exact file path to change.

Do not infer either. The agent's own display name is not reliably in its context, and an open
editor tab is not a statement of intent.
