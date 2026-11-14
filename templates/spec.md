# <PROGRAM> — functional spec

Use this template only when **we** author the spec (`spec_mode: authored`). When a functional
already wrote one, do not reformat it into this shape — put it in `spec/source/` untouched and
write `spec/INDEX.md` from `templates/spec-INDEX.md` instead.

Keep the whole file under ~120 lines. If a section grows past that, split it into `spec-<area>.md`
— line ranges are only useful when the file can be sliced.

## Summary

- **Purpose** — <one sentence: what problem, for whom>
- **Trigger** — <T-code, job, event, or caller>
- **Input** — <selection screen, parameters, interface payload>
- **Output** — <list, file, print, table write>
- **Must not** — <explicit exclusions; the part reviewers rely on>

## Input selection

| Field | Type | Required | Meaning | Source |
|---|---|---|---|---|

## Processing rules

Numbered, each one testable. State the rule, not the implementation.

1. <rule>
2. <rule>

## Output

| Item | Content | Format | Notes |
|---|---|---|---|

## Edge cases

| Case | Expected behaviour |
|---|---|

## Acceptance criteria

- [ ] <observable result that proves it works>

## Open questions

- <unresolved decision and who owns it>

## Change history

| Ver | Date | Change |
|---|---|---|
