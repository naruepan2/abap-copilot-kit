# {{CAPABILITY_NAME}} — Product Requirement Document

> **Evidence status:** {{EVIDENCE_STATUS_SUMMARY}}
> **Architecture classes:** {{ARCHITECTURE_CLASSES}}
> **Overall confidence:** {{OVERALL_CONFIDENCE}}
> **PRD framing:** {{PRD_FRAMING}}
> **Business evidence baseline:** {{BUSINESS_EVIDENCE_BASELINE_OR_NOT_PROVIDED}}

<!-- Canonical default PRD structure. A user-selected template may replace section order/headings; it never replaces evidence IDs, evidence classes, limitation reporting, count hygiene, or final acceptance. PRD framing is AS_IS_CAPABILITY by default: a PRD reconstructed from source describes what exists, not what the business should want. TO_BE_REQUIREMENT, persona, intent, KPI, vision and priority require direct business evidence; otherwise mark UNVERIFIED_INTENT or omit. -->
<!-- Claim-class mapping: Verified→OBSERVED, Derived→INTERPRETATION, Assumed→ASSUMPTION, Unknown→NOT_COLLECTED/UNRESOLVED. HYPOTHESIS and UNVERIFIED_INTENT have no external-kit equivalent and must be preserved. -->
<!-- For TH output use bilingual headings: Thai heading followed by the English heading in parentheses. No checklist sections: internal checks belong in VALIDATION_REPORT.md; this document carries only a short final-acceptance declaration. -->

## 1. Document Context and Confidence
{{DOCUMENT_CONTROL}}
<!-- Purpose, analyzed scope, one shared evidence model with the TS, business-evidence baseline (NOT_PROVIDED if absent), template identity/provenance, output language/format, claim policy, and material gaps. Never invent metadata. -->

## 2. Capability Summary
{{CAPABILITY_SUMMARY}}
<!-- As-is capability first. Business intent only with direct business evidence, otherwise UNVERIFIED_INTENT. Lead with what the capability does for an actor, then the technical anchor. -->

## 3. Product Boundary
{{PRODUCT_BOUNDARY}}
<!-- Three explicit groups: In scope / Excluded-or-inaccessible with reason / Expected-but-missing with bounded search record and impact. Never treat absence as proof of defect. -->

## 4. Actors and Access
{{ACTORS_ACCESS_REGISTER}}
<!-- Columns: Actor/Role, Access/Trigger, Observed Goal, Framing (AS_IS_CAPABILITY/TO_BE_REQUIREMENT), Evidence IDs, Claim class, Confidence. Persona inferred from code = INTERPRETATION; from business evidence = OBSERVED. -->

## 5. Business Capabilities
{{BUSINESS_CAPABILITIES_REGISTER}}
<!-- Columns: Capability, Actor/Trigger, Observed Behavior, Outcome, Framing, Evidence IDs, Claim class. Keep AS_IS_CAPABILITY and TO_BE_REQUIREMENT visibly separate; never fill the latter from code alone. -->

## 6. User and System Journeys
{{JOURNEY_PRIMARY}}
{{JOURNEY_ALTERNATIVES}}
{{JOURNEY_MERMAID}}
<!-- Evidenced behavior only. Mermaid is a summary, not evidence; use full canonical names in node labels. -->

## 7. Business Rules
{{BUSINESS_RULES_REGISTER}}
<!-- BR-[NNN] IDs with the business rule, source object, evidence IDs, claim class and confidence. A rule inferred from code is INTERPRETATION, never a business-approved rule. -->

## 8. Inputs, Outputs, and Business Data
{{DATA_CONTRACT_REGISTER}}
<!-- Business meaning derived from code stays INTERPRETATION. If an output contract is verified, use DECLARED/EXPOSED/UI_CONFIGURED/RUNTIME_OBSERVED classes; do not fabricate sample values. -->

## 9. Integrations and Dependencies
{{INTEGRATIONS_REGISTER}}
<!-- Reuse the TS dependency evidence and edge kinds. Preserve full canonical names and occurrence/canonical counting. -->

## 10. Quality Attributes and Constraints
{{QUALITY_CONSTRAINTS}}
<!-- Observed constraints only. Performance/runtime claims require runtime or test evidence; otherwise NOT_COLLECTED. -->

## 11. Acceptance Criteria
{{ACCEPTANCE_CRITERIA}}
<!-- For as-is PRDs, Given/When/Then restates observed behavior with EV-...; never present it as business-approved acceptance without business evidence. -->

## 12. Risks, Unknowns, and Traceability
{{RISKS_UNKNOWN_REGISTER}}
{{PRD_TS_TRACEABILITY}}
<!-- Include unresolved/provider-limited items and the PRD↔TS claim mapping. -->

## Final Acceptance
{{FINAL_ACCEPTANCE_SUMMARY}}
<!-- Status declaration only: structural/semantic completion, remaining gaps, final outcome (ACCEPTED/ACCEPTED_WITH_LIMITATIONS/NOT_COMPLETE), and a pointer to VALIDATION_REPORT.md when requested. No checklist rows. -->

# Appendix. Evidence Pointer Register
{{EVIDENCE_POINTER_REGISTER}}
<!-- Stable EV-... IDs with object/type, source version or endpoint, location, read date. Keep full canonical names. -->

<!-- OPTIONAL MODULES: include only with direct business evidence; otherwise omit entirely. -->
## Optional Module: Problem or Opportunity
<!-- Requires ticket, BRD, interview, approved requirement, or equivalent evidence. -->
## Optional Module: Vision and Objectives
<!-- Requires approved product or business evidence. -->
## Optional Module: Success Metrics
<!-- Requires KPI definition, baseline, target, and owner. -->
## Optional Module: Release and Priority Context
<!-- Requires backlog, roadmap, release, transport, or approved priority evidence. -->
