# Final Acceptance Review
Pass A recomputes object, occurrence, edge, path, terminal, boundary, unresolved, output-field, evidence and cleanup counts. Pass B challenges wrapper stops, naming-based inference, missing set branches, ambiguous labels, unclassified fields, conflicting completion claims, and native under-expansion. Pass C verifies presentation integrity: every behavior/calculation claim carries a locatable source position or is downgraded; the requested language rules hold (see `thai-output-rules.md` final language check); derived renditions (Word, Word-ready) carry the same sections, evidence, and counts as the Markdown source; and any Mermaid block is either rendered or explicitly labelled as unrendered.

Correct resolvable gaps and rerun both passes, maximum 3 cycles. Then return:

```yaml
final_acceptance:
  review_cycles: 0
  reopened_gaps: 0
  artifact_status: VALIDATED | PARTIAL | FAILED | NOT_APPLICABLE
  evidence_locatability: COMPLETE | PARTIAL | NOT_APPLICABLE
  language_check: PASSED | CORRECTED | MANUAL | NOT_APPLICABLE
  rendition_parity: MATCHED | DIVERGED | NOT_APPLICABLE
  scratchpad_status: NOT_USED | DELETED | DELETE_FAILED
  final_outcome: ACCEPTED | ACCEPTED_WITH_LIMITATIONS | NOT_COMPLETE
```
