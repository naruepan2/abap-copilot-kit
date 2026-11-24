# Analysis Intensity and Document Detail

`compact-preflight.md` Q2 selects one intensity profile. Use these exact names; do not substitute a level from another vocabulary.

## Intensity profiles (the only selectable values)

| Profile | Depth | Breadth | Source profile | Document detail |
|---|---|---|---|---|
| `FOCUSED` | `CRITICAL_PATHS_TO_TERMINAL` | critical dependency/call branches for the root kind | `DEEP` | `DETAILED` |
| `COMPREHENSIVE` (default) | `TO_DATABASE_TABLE_MAXIMUM` (translated for non-CDS roots) | all relevant custom branches | `EXTENDED` | `EXHAUSTIVE` |
| `MAXIMUM` | `TO_DATABASE_TABLE_MAXIMUM` | all reachable in-scope branches, including readable standard wrappers | `EXTENDED` | `EXHAUSTIVE` |
| `CUSTOM` | user-set per dimension | user-set | user-set | user-set |

## Document detail levels (derived, not separately selectable)

- `DETAILED`: root-appropriate dependency/call structure, joins and set operations when applicable, filters, calculations, field groups, configuration, authorization, edge cases, and tests.
- `EXHAUSTIVE`: all in-scope objects/occurrences and output fields, selected rules, critical lineage, material companions/history, evidence coverage, unresolved/provider-limited items, and native reconciliation when available.

A request for maximum detail maps to `MAXIMUM`. Do not turn `DETAILED` or `EXHAUSTIVE` into summary-only prose.

The selected delivery mode (`TECHNICAL_SPECIFICATION`, `CHAT_ANALYSIS`, or `BOTH`) changes presentation, not the agreed intensity. When a request implies a different effort level without naming a profile, choose the closest profile and state it in the plan instead of inventing a new level name.
