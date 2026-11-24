# Completion and Final Acceptance

For a CDS/SQL physical-terminal scope, completeness requires zero pending, unresolved, provider-limited, standard-boundary, user-boundary, and inventory-only SQL nodes inside that scope. Otherwise qualify the status. For non-SQL object kinds, define completion against the requested call/exposure/structure scope and use object-kind-appropriate language rather than SQL terminal statuses.

Allowed structural outcomes:
- `PHYSICAL_TERMINAL_COMPLETE`
- `CUSTOM_SQL_GRAPH_COMPLETE`
- `CRITICAL_MEASURE_PATHS_COMPLETE`
- `REQUESTED_SCOPE_COMPLETE_WITH_STANDARD_BOUNDARIES`
- `PHYSICAL_TERMINAL_PARTIAL_PROVIDER_LIMITED`
- `PHYSICAL_TERMINAL_PARTIAL_UNVERIFIED_ORIGIN`
- `STRUCTURAL_PARTIAL_PENDING_QUEUE`
- `STRUCTURAL_PARTIAL_LIMIT_REACHED`

`PHYSICAL_TERMINAL_COMPLETE` applies only to a declared dependency/SQL terminal scope. For non-CDS analysis, do not apply SQL terminal labels; state the object-kind-specific scope and whether its required relationships were resolved, partial, or blocked.

Final review:
1. Recount canonical objects, occurrences, edges, paths, terminals, boundaries, unresolved items, output fields, and evidence IDs. When an input dependency artifact is supplied, verify its raw rows/nodes/edges/paths, operator-node treatment, root policy, occurrence count, unique canonical names, available depth, and parse errors against the original artifact's actual format.
2. Rebuild queue from unclosed nodes.
3. Challenge wrapper stops, inferred names/origins, missing set branches, shortened names, unclassified fields, and contradictory completion claims.
4. Verify locatable evidence (behavior and calculation claims carry a checkable source position), language rules for the requested language, rendition parity across formats, and Mermaid render/label status.
5. Correct bounded gaps and repeat, maximum three cycles.
6. Return `ACCEPTED`, `ACCEPTED_WITH_LIMITATIONS`, or `NOT_COMPLETE`.
