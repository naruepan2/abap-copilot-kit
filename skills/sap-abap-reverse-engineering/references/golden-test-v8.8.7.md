# Optional Historical Test Fixture: ZC_FIXTURE_ROOT
Fixture only. It is not a workflow requirement. Never hard-code these values into runtime behavior. General discovery guidance is in `discovery-and-interpretation.md`.

```yaml
expected_native_metrics:
  database_tables_or_table_entities: 1785
  database_views: 2728
  parameterized_cds_views: 94
  cds_table_functions: 51
  join_operations: 1795
  set_operations: 40
  group_by_clauses: 214
  function_calls: 2475
  explicit_cast_operations: 30402
  case_expressions: 4002
```

Acceptance: namespace labels present, occurrences preserved, unique/source/scope counts separate, unsupported values not guessed, root policy explicit, no hard-coded adjustment, and static/runtime conclusions separated.

## Historical local test fixture (optional; test-only)
The values below were measured from a user-provided Dependency Tree CSV during a one-time parser test. This is a disposable fixture tied to one root and export; it is not required for future reverse-engineering tasks, not a universal SAP fact, and must never be hard-coded as runtime analysis output. Use the generic parsing/reconciliation contract in `dependency-tree-reconciliation.md` for arbitrary objects and artifacts.

```yaml
dependency_tree_csv:
  root_entity_name: ZC_FIXTURE_ROOT
  total_rows_including_root_and_operator_nodes: 4645
  repository_object_occurrences_including_root: 4565
  unique_canonical_object_names: 172
  structural_operator_nodes:
    SELECT: 40
    UNION: 24
    UNION_ALL: 16
  relation_occurrences:
    From: 2769
    Inner_Join: 506
    Left_Outer_Join: 1289
  maximum_hierarchy_level_zero_based: 26
  root_included_in_occurrence_count: true
```

Fixture-specific parser regression checks (run only when explicitly testing this fixture):
- Identify the root as `ZC_FIXTURE_ROOT` using the exported entity/object-name field, not a case-adjusted reconstruction from the SQL tree token.
- Preserve the four direct root-family names exactly as exported when present: `ZI_FIXTURE_ROOT`, `ZI_FIXTURE_ROOT_1`, `ZI_FIXTURE_ROOT_0`, and `ZI_FIXTURE_ROOT_Tmp`.
- Recover nesting from the populated hierarchy-column position and row order despite blank hierarchy headers; deepest rows must remain nested through level 26.
- Keep `SELECT`, `UNION`, and `UNION ALL` as structural operators, not repository objects. Preserve all 4,565 object occurrences while separately reporting 172 distinct canonical object names.
- Do not claim the file proves current-source identity or absolute SAP-landscape completeness; reconcile its provenance/scope with live safe reads and report any mismatch.
