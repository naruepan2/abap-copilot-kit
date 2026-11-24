# Completion Ledger

```yaml
coverage_counts:
  dependency_occurrences: {total_exact: 0, count_status: EXACT | PARTIAL_OR_TRUNCATED | NOT_APPLICABLE}
  canonical_unique_objects: {total_exact: 0}
  selected_source_reads: {total_exact: 0}
  selected_reporting_scope: {total_exact: 0}
queue:
  discovered: 0
  closed: 0
  pending: 0
  close_reasons: {}
boundaries: []
unresolved_items: []
dependency_reconciliation: MATCHED | PARTIAL | CONFLICTED | UNAVAILABLE | NOT_APPLICABLE
dependency_artifact: # Populate only when an artifact is supplied; do not treat a test fixture as required input.
  provenance: NOT_PROVIDED
  format: NOT_APPLICABLE
  root_included: UNKNOWN
  exported_rows_or_nodes: {total_exact: 0}
  structural_operator_nodes: {total_exact: 0}
  maximum_hierarchy_level: NOT_COLLECTED
  parser_disposition: NOT_APPLICABLE
```

A queue item closes only with a verified terminal, verified out-of-scope decision, inaccessible boundary, duplicate canonical source with preserved occurrence, or explicit user stop.
