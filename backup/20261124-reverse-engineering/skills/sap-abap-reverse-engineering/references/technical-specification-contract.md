# Technical Specification Contract

Use full canonical names everywhere, unchanged and character-for-character from discovery/verification; repeat the complete name at every reader-visible mention. Embed evidence and graphs in the same document.

## Front-matter summary

Every Technical Specification begins with a three-line summary under the H1: evidence status, architecture classes, and overall confidence. These are declarations backed by Section 1 and the evidence register, not new claims. Use this skill's claim labels (`OBSERVED`, `INTERPRETATION`, `ASSUMPTION`, `HYPOTHESIS`, `UNVERIFIED_INTENT`, `NOT_COLLECTED`); if an external kit's vocabulary appears, map it explicitly (`prd-and-architecture-modules.md`) rather than replacing labels silently.

## Evidence strength

Every material claim resolves to a stable evidence ID. The pointer states what was read and where:

- **Identity/metadata claims** — object name, type, package, version or fingerprint, endpoint or table read.
- **Behavior, calculation, filter, or lineage claims** — additionally the **line range** (or the equivalent location) inside the verified source version where the claim can be checked. At `COMPREHENSIVE` and `MAXIMUM` intensity, a behavior claim without a locatable source position is recorded as `INTERPRETATION` or `NOT_COLLECTED`, not as `OBSERVED`.
- **Aggregated or provider-derived claims** — the provider, the query/scope, and any cap or truncation that shaped the result.

Never widen a locatable claim into a general statement about the object, and never cite a position that was not actually read.

Before creating a Technical Specification file, obtain explicit approval for its exact destination directory, filename, and existing-file handling unless the user already specified/approved all three for this task/session. A suggested path is not approval. Never infer a save location from the current directory, editor, or earlier outputs. For chat-only delivery, create no file and ask no path question.

## Template selection

The section list below describes the **canonical default** template, `templates/technical-specification.md`. The PRD companion uses `templates/product-requirement-document.md` and inherits the same invariants; it has its own 12-section structure. A user may select another file under `templates/`, supply their own template, or dictate sections directly. Confirm a non-default template is readable before use, and record its identity and provenance in Document Control.

A selected template governs structure: which sections exist, their titles, order, numbering, and section-level formatting. It does not govern correctness. The following remain mandatory regardless of template, and are added as clearly-labelled sections if the template has no place for them: read-only safety, canonical full-name preservation, evidence IDs with provenance, evidence classes, limitation and evidence-gap reporting, distinct structural versus semantic completion, count hygiene, and final acceptance. Never drop required content to match a template; record each deviation from the canonical structure in Document Control.

## Object status and boundary

Section 3 carries both the object catalog and an explicit solution boundary (Included / Excluded-or-inaccessible with reason / Expected-but-missing). Use the status values in `prd-and-architecture-modules.md`. `Expected but Missing` requires a bounded search record and an impact statement; never present it as proof of a design defect or omit it silently.

## Language and output format

Apply the preflight decisions for language (`EN`, `TH`, `EN+TH`) and output format (`MARKDOWN`, `MARKDOWN_WORD_READY`, `DOCX`). Thai prose follows `thai-output-rules.md`; Word-ready syntax, fonts, converter verification, and Mermaid handling follow `output-packaging.md`. Both affect presentation only. For `EN+TH`, produce two files and validate each separately; facts, counts, statuses, limitations, and evidence IDs must match.

## Canonical section outline

Use the numbered core sections as a flexible outline: retain the numbering of applicable sections, adapt their headings to the verified root kind, and omit inapplicable sections instead of inserting boilerplate. Keep document control, technical overview, object identity, architecture, findings, evidence/limitations, and final acceptance for every specification. Canonical default sections:
1. Document Control
2. Technical Overview
3. Repository Object Identification
4. Technical Architecture
5. Inputs, Parameters and Selection Behavior (when applicable)
6. Processing and Dependency Design (SQL detail when applicable)
7. Output Shape / Exposed Fields (when applicable)
8. Field-Level Lineage (when applicable)
9. Table Functions and AMDP (when applicable)
10. Authorization Design (when applicable)
11. RAP and Service Exposure (when applicable)
12. Configuration Dependencies (when applicable)
13. Change and Transport History (when available)
14. SAP-Native Complexity Metrics (when applicable/available)
15. Dependency Reconciliation and Coverage (when applicable)
16. Static Findings and Risks
17. Test and Runtime Handoff (when applicable)
18. Final Acceptance and Cleanup

Document appendices (include those applicable to the selected scope; do not fabricate unavailable registers):
A. Canonical Object Registry
B. Dependency Occurrence Registry
C. Parent-to-Leaf Path Registry
D. Evidence Pointer Register
E. Terminal and Boundary Registry
F. Unresolved and Provider-Limited Items
G. Mermaid Graphs
H. Output Field Classification Ledger
I. Change and Transport Evidence
J. Final Acceptance Review
K. Scratchpad Cleanup Verification

When a dependency artifact of any supported format is supplied for a Technical Specification, Appendix B must preserve every in-scope object occurrence (and identify structural operators separately), and Appendix C must preserve the corresponding in-scope paths. Section 15 and Appendix J must state artifact provenance/format, root inclusion policy, exact source occurrence and canonical-object counts, local source-read/scope counts, reconciliation status, available depth/path metrics, divergences, and parser/provider limitations. Never claim the entire SAP landscape is covered solely because one artifact was fully parsed. These appendix requirements do not apply to `CHAT_ANALYSIS`; use `references/chat-summary-validation.md` for concise chat evidence instead.

Section 7 reports output shape only when supported by source/metadata, and must label each claim as `DECLARED`, `EXPOSED`, `UI_CONFIGURED`, or `RUNTIME_OBSERVED`. For ALV/SALV, trace the actual output table argument to its verified row type; use an explicit field catalog or column configuration when present, otherwise report the type-derived fields as `DECLARED`, not as proven rendered columns. For CDS, report fields declared by the root entity as `DECLARED`; when a service definition is in scope, report the entities it exposes and their fields as `EXPOSED`. Claim UI-visible fields only from explicit UI metadata/configuration. Actual values or runtime rendering require direct authorized runtime/test evidence. If type, exposure, or output path cannot be resolved, state the precise gap and leave it unresolved; never infer fields from names, SELECT sources alone, or a lower CDS layer. Omit Section 7 when no applicable output contract is in scope.

Graph groups are selected from the actual root and domain structure (for example, root/set-operation branches, major functional domains, table functions/AMDP, authorization/service exposure, and physical terminals). Do not assume Lease, DFI, AP-CP, or FX groups apply to every analysis. Never create one unreadable all-node graph. For `CHAT_ANALYSIS`, a graph is optional and must not be emitted when it adds little value; if included, follow the same canonical-name rules.

## Presenting the analysis

Choose the smallest presentation that carries the facts: 1–3 simple facts → bullets; 4+ records or multi-attribute facts → table; a flow with more than 3 meaningful steps → numbered flow; more than 4 interacting components → Mermaid; a complex mutating, transactional, authorized, dynamic or public component → a dedicated subsection; similar components → a catalog table. Presentation never converts an inference into an observation and never replaces an evidence pointer or registry entry.

## Writing the narrative sections

Sections 2 (Technical Overview) and 6 (Processing) must be readable by someone who knows the business but not the code. Lead each statement with what the program achieves, then attach the mechanism as a trailing annotation:

- Weak (mechanism only): `Single SELECT with 4-way JOIN: VBAK INNER VBAP, LEFT KNA1, LEFT MAKT INTO gt_result.`
- Strong: `Reads the order header and items together with customer and material data in one pass (VBAK×VBAP INNER + KNA1·MAKT LEFT JOIN → gt_result).`

For each step, state the business intent, then the technical anchor (event block, FORM, method, statement). Never reduce a step to an event or statement name. Keep `OBSERVED`, `INTERPRETATION`, and `HYPOTHESIS` distinguishable inside this narrative; a readable sentence is not a licence to merge them.

## Final acceptance and validation report

Section 18 and Appendix J carry a short acceptance declaration only. When the user requested a `VALIDATION_REPORT.md`, point to it for detailed checks; do not expand the specification into a checklist. The validation report records results and never adds facts to the analysis. Unrun checks are `NOT_COLLECTED`/`NOT_APPLICABLE`, never `PASS`.

## Message and exception references

Every message the analysis mentions carries its code plus its text: `E015 (Order & is locked)`, `M07 (Already FD Done)`, `ZSD01/015 (Customer blocked)`. Never present a bare code.

- Read the text from the message class or text pool when an authorized read is available; record the source and language.
- If the text cannot be read, write the code with the exact reason instead of a guess: `E015 (message text not readable on this release)` or `E015 (text not maintained)`, and add the item to the unresolved/provider-limited registry.
- Keep placeholders as placeholders (`E015 (Order & is locked)`); do not invent a value for `&`.
- The same rule applies in prose, tables, Mermaid node labels, and any process-flow description.

## Diagram format and type

Mermaid is the standard diagram notation because it is plain text, diffable, and renders in most Markdown viewers. Choose the diagram type from what it needs to show, not by habit:

| Purpose | Mermaid type |
|---|---|
| Dependency, architecture, or data-flow between objects (default) | `flowchart` |
| Ordered interaction or call sequence between participants | `sequenceDiagram` |
| Class/interface structure and inheritance, only when it adds meaning | `classDiagram` |
| Table relationship with evidenced cardinality | `erDiagram` |

Diagram rules:
- The diagram is a **summary view**; the object, occurrence, and path registries remain the authoritative record. Never let a diagram replace a registry entry or a count.
- Label edges with their relationship kind (SQL dependency, ABAP call, service exposure, association, enhancement, configuration, documentation) so different relations are not visually flattened. Mixing kinds in one graph requires a legend.
- Mark inferred or unresolved relations distinctly (dashed line plus a note) instead of drawing them as confirmed.
- Keep full verified object names in node labels; a short node ID is acceptable only when the full name is visible in the same label.
- Split by branch or domain rather than emitting one all-node graph. If the structure is too large to read, use a table or a path registry instead of a diagram.
- Validate Mermaid syntax before delivering. For Word output, follow `output-packaging.md` because Word does not render Mermaid.
- Omit diagrams when they add no value; an inaccurate or decorative diagram is worse than none.
