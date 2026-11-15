# Skills environment (VS Code + Copilot)

**Two loader roots, and both load**: `~/.agents/skills/` and `~/.copilot/skills/`. A skill must
be a TOP-LEVEL folder containing `SKILL.md` with `name` and `description` frontmatter; nested
subfolders are not loaded, and a new skill never loads in the session where it was added. Any
count drifts whenever an installer runs — regenerate it instead of quoting one.

**`~/.copilot/skills-disabled/` is deliberate, not a mistake.** On 2026-11-14 eleven non-ABAP
skills (BTP, Datasphere ×2, HANA Cloud ×3, CPI, CloudALM, Process Automation, Integration
Architect, BW migration) were moved there because their descriptions cost ~750 tokens in
**every** request while being irrelevant to ABAP work. To use one, move its folder back into
`~/.copilot/skills/` and start a new chat. A reinstall of the toolkit may recreate them in the
live root — move them out again rather than deleting.

**`~/.claude/skills/` is not a Copilot loader root.** It looks like one and holds real skills, but
Copilot ignores it. A skill that exists only there is unreachable — copy it into one of the two
roots above. Check this first whenever a skill "exists but never activates".

Most of `~/.copilot/skills/` is **not** lock-tracked, so `npx skills update` does nothing for it.
Toolkit skills are refreshed only by reinstalling `sap-ai-dev-toolkit`; edits to a lock-tracked
skill are overwritten, so customise by copying to a new folder name.

Detail — family table, update-coverage numbers, recount commands:
`D:\abap-copilot-kit\docs\reference\skills.md`
