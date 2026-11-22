# PROG design methodology

Class-based design is the **first choice**, not an absolute ban on subroutines. The aim is one
clear owner per rule and testable structure; legacy and framework constraints are handled by a
recorded exception, not by silently defaulting to FORM routines.

## Allowed shapes

Decide and record one of these before writing a new executable report.

| Shape | When | Ownership |
|---|---|---|
| L1 — local-only report | Behaviour belongs only to this report; no external reuse | `lcl_app`, `lcl_provider`, `lcl_salv`, optional `lcl_event_handler` inside the PROG |
| L2 — local report plus shared global rules | A global class/FM must reuse the same rule | local orchestration and presentation; one global class owns the rule |
| G — thin report plus global classes | Multiple consumers, lifecycle, security, or independent test ownership | PROG stays a thin selection/event shell; global CLAS owns behaviour |

L1/L2/G is a design choice, not a mandate to create SE24 classes. Do not force every class-based
design into a global class, and do not create global classes only because "OO means SE24".

## Roles in an L1 report

- `lcl_provider` — bounded read-only access and normalization; no row-by-row SQL.
- `lcl_salv` — display and configuration only; no business or database logic.
- `lcl_event_handler` — delegates events; must stay alive while the ALV is displayed.
- `lcl_app` — orchestration and object lifetime; typically owns the handler and SALV wrapper.

Ordering: `REPORT` → selection declarations → local types → local class definitions →
implementations → selection-screen events → `START-OF-SELECTION`. Global declarations come before
processing blocks.

## Thresholds — trigger a design review, not an automatic reject

- `maximum_local_classes: 4`
- `maximum_report_source_lines: 800`
- `maximum_public_methods_per_local_class: 8`
- `maximum_external_consumers: 0` for a local class (L2 global rule owners are separate)

## FORM / PERFORM policy

- Default: write new logic in a local or global class (`lcl_*` for report-only, CLAS for reuse).
- A new `FORM`/`PERFORM` is allowed only with a recorded reason in the design decision, e.g. a
  framework-mandated exit/USEREXIT, a signed legacy enhancement point, a documented tool or
  release limitation, or a refactor risk explicitly accepted in scope. Record the exact reason
  and keep the routine thin.
- Never copy an existing subroutine "because the old report had one"; that is not a reason.
- Existing legacy Form routines may remain unchanged when refactoring is out of scope or risk
  exceeds value. Disclose them; do not quietly expand them.

## Evidence

Record the decision before write:

```json
{
  "program": "ZEXAMPLE",
  "strategy": "L1",
  "local_classes": ["LCL_APP"],
  "global_classes": [],
  "external_consumers": [],
  "reuse_expected": false,
  "unit_test_owner": "none",
  "form_perform_exception": null,
  "rationale": "report-specific behaviour",
  "thresholds_exceeded": [],
  "design_review": false
}
```

`form_perform_exception` is `null` for class-only designs; otherwise it names the routine and the
recorded reason. Validate with `scripts/validate_prog_design_decision.py <file.json>`.

Additional fail conditions: one local God class mixing SQL/rules/SALV/navigation/authorization;
duplicated rules across local classes and FUNC/global classes; dynamic cross-program use of a
local class; a local class used to bypass governance; inline `FOR TESTING` in PROG by default.
Where a function module is involved, prove that the FM return value is the value displayed.
