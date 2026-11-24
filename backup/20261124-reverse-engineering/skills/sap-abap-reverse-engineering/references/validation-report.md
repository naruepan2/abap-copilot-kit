# Validation Report (optional companion)

When a `VALIDATION_REPORT.md` is requested, produce it as a **separate** file. It records results of checks; it never adds facts to the Technical Specification or PRD and never substitutes for their evidence sections. Keep the deliverable's own short acceptance declaration as required by `completion-and-acceptance.md`.

## Report contents

1. **Inputs** — selected template(s) and version, architecture classes, activated modules, language, output format, converter/tool status.
2. **Totals** — evidence IDs, canonical objects, occurrences, edges/paths, claims, and counts; state `EXACT` or `PARTIAL_OR_TRUNCATED`.
3. **Evidence checks** — every material claim resolves to an ID; behavior/calculation claims carry a locatable source position; no claim class was silently upgraded.
4. **Naming checks** — canonical-name lint result; suffixes preserved; no alias-only labels.
5. **Graph checks** — Mermaid syntax validated; each diagram has a caption and relationship legend where needed; Word/Markdown rendition handling stated.
6. **Presentation checks** — module triggers match activated modules; suppressed modules listed; no checklist sections added to TS/PRD.
7. **Language and rendition checks** — final language check result from `thai-output-rules.md`; parity across EN/TH and Markdown/Word/HTML renditions.
8. **Cleanup** — scratchpad status and exact path verification.
9. **Waivers and failures** — each failed check with reason and disposition; no silent pass.

## Minimal YAML summary

```yaml
validation_report:
  template: <path or USER_SUPPLIED>
  schema_version: 1.0.0
  architectures: []
  activated_modules: []
  counts:
    occurrence_count: 0
    unique_object_count: 0
    source_read_count: 0
    selected_scope_count: 0
  evidence_ids: 0
  claims: 0
  canonical_name_lint: PASS | FAIL
  evidence_locatability: COMPLETE | PARTIAL | NOT_APPLICABLE
  mermaid: VALID | INVALID | NONE
  language_check: PASSED | CORRECTED | MANUAL | NOT_APPLICABLE
  rendition_parity: MATCHED | DIVERGED | NOT_APPLICABLE
  scratchpad_status: NOT_USED | DELETED | DELETE_FAILED | RETAINED_FOR_RESUME
  failed_checks: []
  final_outcome: ACCEPTED | ACCEPTED_WITH_LIMITATIONS | NOT_COMPLETE
```

## Rule

A validation report reports findings. A check that did not run is `NOT_COLLECTED`/`NOT_APPLICABLE`, never `PASS`. A failed canonical-name or evidence check must appear in `failed_checks` and prevents `ACCEPTED` until resolved.
