# Dependency Tree Reconciliation
## Purpose and authority
This is a format-agnostic procedure for any supplied SAP ADT Dependency Tree/Graph, CSV, spreadsheet, or equivalent dependency artifact, and for native graph evidence obtained directly through an authorized provider. Treat it as structural occurrence/path evidence, not as a special case tied to one root object or test file. Record provenance (provider/file/URI, export date/version if available, root, destination, and scope). Do not treat a cached/exported graph as proof that names, source versions, or current SAP state are unchanged; verify high-impact nodes/branches with current authorized reads where possible.

## Reconciliation dimensions
Reconcile occurrence membership, canonical membership, root-to-leaf paths, missing/divergent branches, relation occurrences, depth, and root inclusion policy. Report separately:
- `native_occurrence_count`: rows/edges/occurrences as the provider exported them, without deduplication;
- `native_unique_object_count`: unique verified canonical objects, with the counting key stated;
- `source_read_count`: distinct source objects actually read;
- `selected_scope_count`: objects/occurrences included in this analysis scope.

Never substitute one count for another. Do not hard-code subtraction for the root or alter provider totals to match local discovery; state whether the native root is included and show the arithmetic if a derived count is useful.

## Artifact parsing and discovery
1. Inspect the artifact's format, headers/schema, root, scope, provenance, version, and explicit truncation/limit indicators before counting or interpreting it. Preserve the original rows/nodes/edges and their ordering for auditability.
2. Determine whether the representation is an adjacency list, nested tree, path-per-row export, matrix, or graph. Select the parser for the observed format; do not assume every CSV uses indented columns.
3. For a nested-column CSV with one populated object/operator cell per row, derive each row's depth from populated hierarchy-column positions, not blank/duplicated header labels. Reconstruct parents with a stack keyed by depth and row order: a deeper row attaches to the closest prior row at the nearest shallower level; same-depth rows are siblings.
4. For adjacency exports, use explicit parent/child identifiers and preserve edge IDs/relations. For path-per-row exports, retain each full path as an occurrence and derive edges without collapsing repeated paths. If identity/parentage is ambiguous, record the parser limitation rather than fabricate relationships.
5. Preserve structural operators such as `SELECT`, `UNION`, and `UNION ALL` as syntax/operator nodes, not repository objects. Also distinguish dependency relations (`FROM`, joins, association, call/use) from object identity.
6. Prefer an explicit exported canonical entity/object name, corroborated by current repository metadata when available. Preserve differing raw SQL alias/tree tokens separately as aliases; never case-normalize, uppercase, title-case, reconstruct, or shorten a name and present the transformed value as canonical.
7. Preserve every duplicate occurrence, edge, and parent-to-leaf path. Deduplicate only canonical object records and source reads. If the export lacks stable IDs for duplicate edges, assign clearly labeled local occurrence IDs and state that they are analysis-generated.
8. Discover missing root type, package, direct dependencies, or companions through authorized safe reads when possible; do not ask the user to provide information that available tools can safely discover. Do not infer unavailable information from the filename or export alone.

## Closure and divergence
Mark a discovered wrapper `UNDER_EXPANDED_AGAINST_NATIVE_TREE` when the native path continues. Classify every divergence as current-source drift, export-scope mismatch, parser ambiguity, provider limitation, user boundary, or unresolved; do not force a match. Reconcile terminal/boundary nodes, database objects, join/set-operation branch membership, maximum depth, and any truncation indication. Never repair a mismatch with a hard-coded subtraction. A fully parsed artifact proves only the artifact's declared scope, not full SAP-landscape completeness.
