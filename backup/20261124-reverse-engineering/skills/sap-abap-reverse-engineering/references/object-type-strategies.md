# Object-Type Strategies (Advisory)

Use this reference to choose a sensible first discovery path for common user descriptions. It is **not** an allowlist, support guarantee, or substitute for evidence. Object-type names below are candidate mappings, not canonical identity: verify the requested object and its type from authorized metadata/search results before relying on the mapping.

## Operating rules

1. Resolve the user's exact object name and determine its repository type using available authorized read operations. Do not infer identity, implementation, or tool support from the label or name alone.
2. Treat `focus` as an analysis strategy, `probe` as a set of read attempts, and provider capability as a result established only by those attempts. A suggested probe is not a claim that a tool supports that object type.
3. If a candidate mapping is ambiguous, absent, or unsupported, continue with generic discovery in `discovery-and-interpretation.md` sections 4-5. Do not silently drop the root or its dependencies.
4. Record actual attempted reads, evidence, and any `PROVIDER_LIMITED`, `UNRESOLVED`, or bounded-scope outcome. A limitation may defer a branch, but must retain its close reason and effect on completeness.
5. Keep relationships distinct: calls, SQL dependencies, service exposure, authorization, configuration, structure, and documentation are not interchangeable.
6. Read table/data contents only when explicitly relevant and authorized. For `TABU`, `TDAT`, `VDAT`, and `CDAT`, prefer metadata, structure, and usage evidence; avoid bulk content reads. Analyze `XPRA` statically only; never execute it.

## Common request-to-discovery strategies

| User description | Candidate type(s) to verify | Focus after identity is verified | Read evidence to try (only where available) | Cautions |
|---|---|---|---|---|
| Program/report | `PROG` | Entry points, selection/interface, includes, relevant call chain, SQL, dynamic calls, enhancements, outputs | Metadata/source, include/source reads, where-used/references | Source writes are observations; never execute business processing |
| CDS | `DDLS` | Full DDL; active `FROM`, joins, set operations, table functions, AMDP/`USING`, and materialized associations | DDL source, metadata, dependency/impact and references | Separate SQL-producing associations from navigation, text, value-help, and metadata associations |
| Function Module | `LIMU FUNC`; related parent may be `R3TR FUGR` | Exact function interface/body, callers, relevant group includes and data dependencies | Function source/signature, parent metadata, references | Do not equate one function module with the whole function group |
| Service Definition | `SRVD` | Exposed entities and their projection/implementation relationships | Definition source/metadata, related binding and references | Exposure is not implementation or proof of runtime use |
| Service Binding | `SRVB` | Bound service definition, protocol/version and exposure metadata | Binding metadata/source where readable, related definition | Do not infer publication or runtime availability from repository identity alone |
| Class | `CLAS` | Relevant public contract, methods, callers, inheritance/interfaces, SQL and dynamic calls | Class metadata/source, targeted method bodies, references/hierarchy where available | Read relevant methods deeply; do not assume every method is in scope |
| Form | Verify subtype first; `FORM` is a candidate for SAPscript | Find the driver/caller and trace form invocation and relevant form elements | Form metadata/source if available; search source/references for form name and calls | Distinguish SAPscript, Smart Forms, Adobe Forms, and other form technologies; do not assume one type mapping |
| OData service | No single candidate type; resolve implementation/exposure first | Distinguish RAP exposure from Gateway/SEGW or another provider; trace service-to-entity and implementation edges | Service metadata/catalog or repository search, binding/definition, provider-specific source/metadata, references | Do not force every OData service into `SRVD`/`SRVB`; a service name may not be a repository object name |
| Access Control | `DCLS` is a candidate | Protected CDS entity, access conditions, role/PFCG references where available | DCL source/metadata, target entity and references | Static rules do not prove a user's effective authorization result |
| RAP Behavior | `BDEF` is a candidate; related handler class must be discovered | Entity/alias, operations, actions, determinations, validations, authorization, handler implementation and backing entities | Behavior source, linked class/methods, entity definitions, references | Keep behavior, implementation, exposure, and data edges separate |
| Database table | `TABL` is a candidate | Keys, fields, data elements/domains, technical metadata, relevant readers/writers | Table metadata/structure, field type metadata, references | A table definition is not table contents; avoid bulk data retrieval |
| View | `VIEW` is a candidate; verify whether the user means a DDIC view or CDS view | Actual definition, base relations, consumers | View metadata/source, references | Disambiguate DDIC view from CDS (`DDLS`) before selecting lineage rules |
| Search Help | `SHLP` is a candidate | Selection method, parameters, referenced table/view and binding/use sites | Search-help metadata/source where available, references | Do not infer runtime value-help behavior from the name alone |
| Domain | `DOMA` is a candidate | Data type, fixed values/ranges, value table, consuming data elements | Domain metadata and where-used | Fixed values/value table are definition evidence, not proof of application validation |
| Data Element | `DTEL` is a candidate | Underlying domain/predefined type, labels, search-help binding, consumers | Data-element metadata, domain and references | Labels do not establish business semantics |
| Other object | Verify type from evidence; no predefined candidate | Apply root-kind-appropriate generic discovery and follow observed relationships | Available authorized metadata/source/references, trying an alternate existing read provider only if allowed and available | Absence from this table never prevents discovery |

## Practical acceptance check

For each root, confirm that the report can state (a) verified identity/type or unresolved identity, (b) attempted and obtained evidence, (c) discovered relationship kinds and paths, and (d) limitations/close reasons. Test at least one unlisted type through generic discovery. A type-specific probe failure must not erase evidence already gathered or cause other branches to be skipped.