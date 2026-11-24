# Technical Specification: {{FULL_ROOT_OBJECT_NAME}}

> **Evidence status:** {{EVIDENCE_STATUS_SUMMARY}}  
> **Architecture classes:** {{ARCHITECTURE_CLASSES}}  
> **Overall confidence:** {{OVERALL_CONFIDENCE}}

<!-- Canonical default structure. A user-selected template may replace section order/headings; it never replaces evidence IDs, evidence classes, limitation reporting, count hygiene, or final acceptance. For TH output, use bilingual headings: Thai text followed by the English heading in parentheses. For MARKDOWN_WORD_READY or DOCX, keep one H1, ATX headings, pipe tables only, and label Mermaid blocks that must be rendered separately. -->
<!-- Claim-class mapping for kit compatibility: Verified→OBSERVED, Derived→INTERPRETATION, Assumed→ASSUMPTION, Unknown→NOT_COLLECTED/UNRESOLVED. Keep this skill's labels visible; never silently substitute the kit's labels. HYPOTHESIS and UNVERIFIED_INTENT have no kit equivalent and must be preserved. -->
<!-- Presentation selection: 1–3 simple facts → bullets; 4+ records or multi-attribute facts → table; flow over 3 meaningful steps → numbered flow; more than 4 interacting components → Mermaid; complex mutating/authorized/dynamic/public component → dedicated subsection. -->
## 1. Document Control
{{DOCUMENT_CONTROL}}
<!-- Include source system/client, extraction date, requested scope/intensity profile, evidence baseline (or NOT_PROVIDED), verified root type and dominant archetype plus additional architecture classes, template identity and provenance (path, or USER_SUPPLIED/PASTED, plus version/hash when available), output language (EN/TH/EN+TH), output format (MARKDOWN/MARKDOWN_WORD_READY/DOCX/HTML) with converter status, document version, status, and limitations. For Word output record the font family/size and reference document used. Never invent missing metadata. -->
## 2. Technical Overview
{{TECHNICAL_OVERVIEW}}
<!-- Lead with business intent, then the mechanism as a trailing annotation; never a bare event or statement list. Summarize observed entry points, major flow, outputs, and risks. Separate requirement intent from observed implementation. -->
## 3. Repository Object Identification
{{OBJECT_IDENTIFICATION}}
<!-- Identify root by full type/name/package and available version/fingerprint. Include only in-scope companions. Add object status: Detected / Expected and Detected / Expected but Missing / Not Applicable / Unverified. For Expected but Missing, record where it was searched and its impact; absence is not proof of a defect. -->
### 3.1 Solution Boundary
{{SOLUTION_BOUNDARY}}
<!-- State Included / Excluded-or-inaccessible (with reason) / Expected-but-missing. Keep this explicit so a missing DCL, service binding, draft table or handler is neither silently omitted nor reported as confirmed absent. -->
## 4. Technical Architecture
<!-- Adapt architecture and dependency-edge categories to the verified root kind. Do not force CDS/SQL layers onto ABAP, RAP, DDIC, or other roots. -->
### 4.1 Architecture / Dependency Layers
{{LAYER_HIERARCHY}}
### 4.2 Dependency / Execution Graphs
{{SQL_EXECUTION_GRAPHS}}
<!-- Split large graphs by meaningful branch/domain. Use full canonical names and edge/path IDs. Distinguish SQL dependencies from calls, associations, exposure, and inventory-only relationships. Prefer Mermaid flowchart; use sequenceDiagram for ordered interaction, erDiagram only with evidenced cardinality, classDiagram only when structure matters. Mark inferred or unresolved edges distinctly. For Word output, state that Mermaid must be rendered separately. -->
## 5. Inputs, Parameters and Selection Behavior (when applicable)
{{PARAMETERS_SELECTION}}
## 6. Processing and Dependency Design
<!-- For non-SQL roots, rename/adapt this section to the relevant call, behavior, data-access, enhancement, or configuration flow. Omit SQL-only subsections that do not apply. State business intent first per step, with the technical anchor second. Message references use CODE (text); a bare code is a defect. -->
### 6.1 UNION and Set-Operation Branches
{{SET_BRANCHES}}
### 6.2 JOIN Matrix
{{JOIN_MATRIX}}
### 6.3 Filters and Row-Exclusion Rules
{{FILTERS}}
### 6.4 Aggregation, Currency, Sign and Date Logic
{{CALCULATIONS}}
## 7. Output Shape / Exposed Fields (when applicable)
<!-- Include only when the selected root/scope has a source- or metadata-supported output contract. Label each conclusion as DECLARED, EXPOSED, UI_CONFIGURED, or RUNTIME_OBSERVED. Do not equate declared/exposed fields with fields actually rendered or with actual data values. -->
{{OUTPUT_SHAPE}}
<!-- For ALV/SALV, trace the displayed table argument to its verified local/DDIC row type and inspect field-catalog/column configuration. For CDS, report root elements; if an SRVD is in scope, report entities it exposes and their fields. Claim UI-visible fields only with UI metadata/configuration evidence. Omit this section if no applicable output contract can be established; if investigation was requested but blocked, state the exact gap rather than guessing. -->
## 8. Field-Level Lineage (when applicable)
{{FIELD_LINEAGE}}
<!-- Prioritize critical fields; provide source-to-output transformation and evidence, or state the exact lineage gap. -->
## 9. Table Functions and AMDP (if applicable)
{{TABLE_FUNCTIONS_AMDP}}
## 10. Authorization Design (when applicable)
{{AUTHORIZATION}}
## 11. RAP and Service Exposure (when applicable)
{{RAP_SERVICE}}
## 12. Configuration Dependencies (when applicable)
{{CONFIGURATION}}
## 13. Change and Transport History (when available)
{{CHANGE_HISTORY}}
<!-- Record evidence source and coverage window; distinguish unavailable history from evidence of no changes. -->
## 14. SAP-Native Complexity Metrics (when available)
{{NATIVE_METRICS}}
## 15. Dependency Reconciliation and Coverage (when applicable)
{{RECONCILIATION_COVERAGE}}
<!-- When dependency evidence exists, report provider/artifact provenance, root inclusion policy, occurrence_count, unique_object_count, source_read_count, selected_scope_count, relation/depth/path reconciliation where available, divergences, and parser/provider limitations separately. Otherwise state the exact discovery coverage and why reconciliation is unavailable. -->
## 16. Static Findings and Risks
{{FINDINGS_RISKS}}
<!-- For high-impact ambiguity only: list competing hypotheses, predicted evidence, falsification test, counter-evidence checked, and current disposition. Do not present a hypothesis as a fact. -->
## 17. Test and Runtime Handoff (when applicable)
{{TEST_RUNTIME_HANDOFF}}
<!-- Separate static observations from runtime claims. Record tests actually run separately from recommendations and list prerequisites. -->
## 18. Final Acceptance and Cleanup
{{FINAL_ACCEPTANCE_CLEANUP}}
<!-- State structural and semantic completion independently, acceptance status, remaining gaps, and scratchpad cleanup when applicable. Summary only: when a VALIDATION_REPORT.md was requested, point to it for detailed checks. Do not expand this section into a checklist; internal check results belong in the separate validation report. -->
# Appendices
## Appendix A. Canonical Object Registry
{{CANONICAL_REGISTRY}}
## Appendix B. Dependency Occurrence Registry
{{OCCURRENCE_REGISTRY}}
## Appendix C. Parent-to-Leaf Path Registry
{{PATH_REGISTRY}}
## Appendix D. Evidence Pointer Register
{{EVIDENCE_REGISTER}}
## Appendix E. Terminal and Boundary Registry
{{TERMINAL_BOUNDARY_REGISTRY}}
## Appendix F. Unresolved and Provider-Limited Items
{{UNRESOLVED_ITEMS}}
## Appendix G. Mermaid Graphs
{{MERMAID_GRAPHS}}
## Appendix H. Output Field Classification Ledger
{{OUTPUT_FIELD_LEDGER}}
## Appendix I. Change and Transport Evidence
{{CHANGE_TRANSPORT_EVIDENCE}}
## Appendix J. Final Acceptance Review
{{FINAL_ACCEPTANCE_REVIEW}}
## Appendix K. Scratchpad Cleanup Verification
{{SCRATCHPAD_CLEANUP}}
## Evidence and status conventions
<!-- Conditional modules from prd-and-architecture-modules.md: include only when the evidence trigger fires. Module names should match data-module values if an HTML rendition is produced. -->
- Cite each material claim with a stable evidence ID resolvable in Appendix D (object/type, source version or metadata endpoint, location, and read date when available).
- Distinguish `OBSERVED`, `INTERPRETATION`, `ASSUMPTION`, `UNVERIFIED_INTENT`, and `NOT_COLLECTED`. Mark provider gaps, user/standard boundaries, truncation, and unresolved items explicitly.
- Keep canonical-object, occurrence, source-read, edge/path, terminal, and reporting-scope counts separate. Preserve exact counts where evidence permits.
- For output fields, identify the evidence class (`DECLARED`, `EXPOSED`, `UI_CONFIGURED`, or `RUNTIME_OBSERVED`) and source. `DECLARED` means structure/type or CDS elements; `EXPOSED` means service-definition exposure; `UI_CONFIGURED` means UI metadata explicitly selects/configures fields; `RUNTIME_OBSERVED` means output was directly captured in an authorized test/run. These classes are not interchangeable. Do not fabricate sample values or claim actual rendered output from a row type or CDS projection alone.
- Give graph relationships explicit meanings. Preserve repeated paths without duplicating canonical object records. Copy each object name exactly as discovered/verified and preserve it character-for-character at every reader-visible mention; do not shorten, rewrite, normalize, reconstruct, or replace it with an alias. Never use `_0`, `_1`, `_TMP`, or another suffix alone as an object label. Short graph IDs are permitted only if the full unchanged name is visible in the label.
- Omit an inapplicable section or table rather than filling it with `None`/`N/A`; keep required numbering where the contract requires it.
- A completion label describes the requested scope, not the SAP landscape. Queue-empty is not proof of terminal completeness.

## Interface field semantics
<!-- Conditional: include only when interface-triggered field behavior is in scope or discovered. -->
| Field | Object | Current meaning | Proposed use | Owner | Lifetime/persistence | Downstream consumers | Risk | Evidence | Verdict |
|---|---|---|---|---|---|---|---|---|---|

## Technical event propagation ledger
<!-- Conditional: include only when event/flag propagation is relevant. -->
| Event/flag | Producer | Receiver | Scope key | Lifetime | Persistence | Replay/reset | Failure mode | Evidence | Test |
|---|---|---|---|---|---|---|---|---|---|

## Before-posting vs after-posting controls
<!-- Conditional: include only when duplicate prevention, posting, or repair behavior is relevant. -->
| Control | Timing | Prevents creation? | Scope/key | Concurrency behavior | Retry behavior | Evidence | Recommendation |
|---|---|---|---|---|---|---|---|

## Output quality status
- Status: `pass` / `pass_with_declaration` / `fail`
- Evidence gaps:
- Assumptions:
- Tests required:
