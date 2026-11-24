# PRD Delivery, Claim Classes, and Architecture Modules

This reference adapts the externally supplied TS/PRD kits to this skill's evidence discipline. It adds capability **without replacing** existing rules: canonical names, evidence classes, occurrence/canonical counts, dependency reconciliation, completion separation, and final acceptance remain authoritative.

## 1. Deliverables and opt-in PRD

| Deliverable | Status | When produced |
|---|---|---|
| `TECHNICAL_SPECIFICATION` | existing core mode | when a file mode is selected |
| `CHAT_ANALYSIS` | existing core mode | chat answer, no file |
| `BOTH` | existing core mode | spec + concise chat summary |
| `PRODUCT_REQUIREMENT_DOCUMENT` | **opt-in companion** | only when the user explicitly asks for a PRD |

A PRD uses `templates/product-requirement-document.md` (canonical default) and has its own approval of destination, filename, and overwrite handling. It never becomes a default side effect of a Technical Specification. If a PRD and TS are both requested, derive both from one analysis and one evidence model; never re-analyse SAP separately for each, and never let one rendered version change facts in the other. The workflow writes and validates each document separately (SKILL.md steps 7 and 9).

Core PRD sections have named producers from the one evidence model: §4 Actors and Access ← authorization evidence from TS §10; §6 User and System Journeys ← observed control flow from TS §6; §7 Business Rules ← `BR-[NNN]` labels attached to existing `EV-*` IDs (traceability labels, never new evidence); §11 Acceptance Criteria ← restated observed behavior, not approved business acceptance without direct business evidence; §12 Risks ← TS §16 findings mapped through the claim classes below.

The PRD reconstructed from source is **as-is capability documentation**, not a statement of what the business should want. Business intent, personas, KPIs, vision, priority, and release context require direct business evidence. Without it, mark those items `UNVERIFIED_INTENT` or omit the section; never invent them from the code.

## 2. Claim class mapping (external kit ↔ this skill)

Use this skill's labels in every deliverable. The external names below are shown only so content produced with either kit can be mapped without loss.

| External kit label | This skill's label | Rule |
|---|---|---|
| `Verified` | `OBSERVED` | directly evidenced with object + location |
| `Derived` | `INTERPRETATION` | logically derived, still a distinct label |
| `Assumed` | `ASSUMPTION` | plausible but unverified |
| `Unknown` | `NOT_COLLECTED` | serialize as `NOT_COLLECTED`; `UNRESOLVED` is a reader-facing close reason kept in the locator/provenance, never a `claim_class` value |
| — | `HYPOTHESIS` | competing explanation with falsification test — has no external equivalent, keep it |
| — | `UNVERIFIED_INTENT` | business intent without direct evidence — has no external equivalent, keep it |

Do not rename `OBSERVED` to `Verified` to satisfy an external template. If an external template has fixed cells with those words, write the external value **and** the skill label, e.g. `Verified / OBSERVED`.

## 3. Object status (adopted from the kits)

Use these values in object catalogs, in addition to the existing read/fingerprint fields:

- `Detected` — verified by authorized read.
- `Expected and Detected` — expected from architecture and found.
- `Expected but Missing` — expected from architecture but not found after a bounded search. Record the search and impact; absence is not proof of a design defect.
- `Not Applicable` — shown only when the architecture makes it genuinely irrelevant.
- `Unverified` — not checked or not resolvable; do not call it missing.

`Expected but Missing` is especially useful for DCL roles, service bindings, draft tables, metadata extensions, and handler implementations. Record where and how you searched before using it.

## 4. Multi-label architecture classes and module triggers

Assign **multiple** architecture labels when the evidence supports them. Keep this skill's archetype (see `discovery-and-interpretation.md`) as the dominant analysis lens; the classes below are additional capability tags.

Allowed classes: `CLASSIC_REPORT`, `SALV_REPORT`, `MODULE_POOL`, `BACKGROUND_JOB`, `SMART_FORM_OUTPUT`, `ADOBE_FORM_OUTPUT`, `RFC_INTEGRATION`, `FILE_INTEGRATION`, `CLASSIC_ODATA`, `RAP_MANAGED`, `RAP_UNMANAGED`, `RAP_DRAFT`, `RAP_NON_DRAFT`, `RAP_SERVICE_UNVERIFIED`, `MIXED_ARCHITECTURE`, plus the existing archetype names where they describe non-overlapping scope. `RAP_SERVICE_UNVERIFIED` means service exposure was not verifiable in the analysed scope; it does not assert that no binding exists.

| Evidence trigger | Activate module | Minimum content |
|---|---|---|
| Report events, selection screen, `CL_SALV_TABLE`, `REUSE_ALV_*` | Classic Report / SALV | events, selection contract, retrieval, aggregation, columns, commands, export, output-shape evidence class |
| `CALL FUNCTION`, class/method calls, includes, dynamic calls | Callable Components | catalog; expand mutating, dynamic, authorized, transactional, public or complex components |
| `SSF_FUNCTION_MODULE_NAME` or generated Smart Form FM | Smart Forms Output | trigger, interface, context, form data, spool/print/email, language, errors |
| `FP_JOB_OPEN`, `FP_FUNCTION_MODULE_NAME`, `FP_JOB_CLOSE` | Adobe Forms Output | job lifecycle, interface/context, PDF/spool/output, errors |
| Root/interface/projection CDS, behavior artifacts | RAP Object Model | persistence, interface, behavior, consumption, semantics, exposure layers |
| Managed/unmanaged, draft, actions, validations, determinations, saver | RAP Behavior | CRUD, lifecycle, numbering, lock, ETag, save, activate, discard |
| Metadata extension, service definition/binding, OData annotations | RAP Service / UI | projection behavior, publication, UI annotations, value help, side effects, authorization |
| Job, variant, spool, application log | Background Processing | schedule, restart, commit, monitoring, recovery |
| RFC/BAPI/API/file/message/external call | Integration Boundary | contract, mapping, authentication, retry, idempotency, errors |
| Screens, PBO/PAI, GUI status | Module Pool / Dynpro | screen flow, command handling, navigation state |

Suppress modules with no evidenced trigger. Keep required core sections even when a module is suppressed. Never let a module trigger narrow the dependency graph, occurrence counting, or evidence bar.

For RAP object status use `Detected`, `Expected and Detected`, `Expected but Missing`, `Not Applicable`, `Unverified`. Draft table applies only to draft designs; metadata extension is optional when annotations are embedded; projection behavior is expected only for transactional projections; a service binding may lie outside the analyzed scope — say so instead of implying it does not exist.

## 5. PRD optional modules and evidence gates

| Module | Required direct evidence |
|---|---|
| Problem / Opportunity | ticket, BRD, interview, or approved requirement |
| Vision / Objectives | approved business or product evidence |
| Success Metrics | KPI definition + baseline + target + owner |
| Release / Priority | backlog, roadmap, release, transport, or approval evidence |

Suppress an optional module when its evidence is absent. A source comment naming a KPI is not an approved KPI. If the user asks for a business narrative but supplies no business evidence, produce the as-is capability sections and list the missing evidence rather than filling the narrative with plausible text.

## 6. Presentation selection

Use the smallest form that carries the facts:

| Facts to show | Use |
|---|---|
| 1–3 simple facts | bullets |
| 4+ records or multi-attribute facts | table |
| Flow with more than 3 meaningful steps | numbered flow |
| More than 4 interacting components | Mermaid diagram |
| Complex mutating, transactional, authorized, dynamic or public component | dedicated subsection |
| Similar components | catalog table |

This is a presentation rule only. It never converts an inference into an observation and never replaces an evidence pointer or a registry entry.

## 7. Validation report separation

Internal checks belong in a separate `VALIDATION_REPORT.md` when the user requests one; the deliverable itself carries only status declarations. Keep the short acceptance summary already required by this skill (Section 18 / final acceptance) but do not expand it into a full checklist section.

A validation report records: applied template and version, activated architecture classes and modules, evidence/object/claim/count totals, Mermaid syntax and render status, canonical-name check result, language and rendition parity checks, scratchpad status, and every failed or waived check. It reports results; it does not add facts to the analysis.
