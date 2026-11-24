# Risk-Based Output Governance

## Delivery principle
Quality checks improve output; they must not silently suppress useful results.

Final status:
- `pass`: all mandatory semantic and evidence gates satisfied.
- `pass_with_declaration`: useful deliverable completed with explicit evidence gaps, assumptions, or tests required.
- `fail`: output cannot be safely produced because identity, scope, destination, or read-only constraints are unresolved.

## Hard gates
- root identity and requested scope;
- read-only boundary;
- output path/overwrite agreement when creating a file;
- no fabricated evidence;
- business-vs-technical field semantics when making interface field-use/change recommendations;
- before-posting vs after-posting classification when making posting/control recommendations.

Heuristic scores are advisory. Never convert a low score alone into a hard failure.
