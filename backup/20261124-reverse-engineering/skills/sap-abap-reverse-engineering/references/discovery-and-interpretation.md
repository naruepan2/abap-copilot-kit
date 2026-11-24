# Discovery and Interpretation Contract

Use this format- and object-agnostic contract for every root object. The Dependency Tree CSV used during skill tuning is a disposable example, not a required input, root, metric set, parser assumption, or acceptance baseline.

## 1. Resolve the request with minimal questions
- Take the exact root identifier, destination/client, scope, delivery mode, and safety limits from the prompt or already-confirmed session context when available.
- Discover object type, package, source, dependencies, and material companions with authorized safe reads where available. Do not ask the user to enumerate facts that can be discovered safely.
- Inventory explicit attachments and workspace paths before asking whether evidence exists. Treat an available dependency artifact as input evidence.
- Ask only for missing information that cannot be safely discovered and blocks the next step, such as an unconfirmed target system. Bundle necessary questions once.
- Respect `TECHNICAL_SPECIFICATION`, `CHAT_ANALYSIS`, or `BOTH`: investigation and evidence standards remain the same; chat-only creates no file.

## 2. Rank and reconcile evidence
Rank evidence per claim, not as a universal source ordering:
- For current implementation behavior and canonical identity, prefer current source/metadata read from the confirmed destination.
- For SAP-native graph/where-used coverage or counts, preserve the native provider's output and scope; confirm critical edges with source when possible.
- For requirement intent, prefer supplied requirements/acceptance criteria over implementation behavior. Source code is not a specification.
- User-supplied exports, source snapshots, logs, and documentation remain valid evidence with provenance and age stated; do not discard them merely because they are not live reads.
- Inference from names, conventions, or repeated patterns is a hypothesis until corroborated.

A supplied export is a baseline for its declared root/scope/version, not proof of current source identity or total landscape coverage. Reconcile it with current safe reads when possible. Explain mismatches; never silently overwrite one source's evidence with another.

## 3. Build two linked registries
- **Canonical-object registry:** one record per verified full object name, type, package (if known), source version/fingerprint, read status, and evidence pointer.
- **Occurrence/edge registry:** one record per dependency occurrence, including parent occurrence, child canonical object or operator, relationship type, branch/path, evidence, and close/disposition status.

Deduplicate source reads by verified canonical object/version, but never deduplicate distinct occurrences, paths, or native metrics. Keep `occurrence_count`, `unique_object_count`, `source_read_count`, and `selected_scope_count` separate. Record whether the root is included in each count.

## 4. Discover by object kind and relationship
Choose analysis based on the verified root type. Do not assume every dependency graph is a CDS SQL graph.
- **CDS/DDLS:** trace active `FROM`, joins, set operations, table functions, AMDP/USING dependencies, and materialized associations. Distinguish SQL-producing associations from navigation, text, value-help, and metadata-only associations.
- **ABAP program/class/function:** identify public entry points and relevant call chains, SQL reads/writes (describe writes as source behavior only; do not execute them), dynamic calls, enhancements/BAdIs, exceptions, and output construction. Mark dynamic or external targets that cannot be resolved.
- **RAP/service:** trace service binding/definition, projection, behavior definition, handler implementation, actions/determinations/validations, authorization, and backing entities as applicable. Separate exposure edges from implementation and data-dependency edges.
- **DDIC/configuration/other object:** follow its actual structural or usage relations and document the provider's relation semantics; do not force SQL lineage onto a non-SQL object.

For common user descriptions, consult `object-type-strategies.md` for candidate mappings and analysis focus. Verify identity/type and probe available authorized read operations before drawing conclusions; the reference describes strategies, not guaranteed provider support. If a mapping is ambiguous, absent, or unreadable, continue through the generic object-kind rules and queue/state workflow, recording evidence and any limitation rather than silently skipping the object. This guidance adds no user preflight question.

Keep edge kinds distinct (for example, SQL dependency, ABAP call, service exposure, association/navigation, enhancement, configuration, or documentation reference). A dependency edge is not proof of a runtime call or runtime execution.

## 4a. Classify the archetype before choosing sections

After the type is verified, name the archetype. The archetype decides which sections can produce real evidence, so it prevents empty sections and missing ones.

| Archetype | Sections that carry the analysis |
|---|---|
| `ALV_REPORT` / `LIST_REPORT` | selection and parameters, processing steps, output shape from the field catalog or row type, authorization, messages |
| `BATCH_JOB` | job entry, variant/selection source, processing steps, write targets, recovery/restart behavior, messages |
| `BDC` / `CALL_TRANSACTION` | source-to-screen field mapping, transaction codes, per-screen flow, error handling |
| `FM_WRAPPER` | exported/imported interface, delegated implementation, callers, BAPI/RFC exposure |
| `UTILITY_CLASS` | public methods and callers, side effects, configuration reads; usually no output or screen section |
| `CDS_SQL_GRAPH` | dependency layers, set operations, joins, filters, lineage, terminals |
| `RAP_BO` | behavior definition, handler implementation, authorization, service exposure |
| `ENHANCEMENT_IMPL` | enhancement spot/point, original versus injected behavior, affected standard flow |
| `DDIC_STRUCTURE` | fields, types, domains, value tables, usage sites |
| `CONFIG_TABLE` | key structure, maintenance transaction, consuming logic |

If the archetype is mixed or unclear, state the dominant one and list the secondary traits instead of forcing a single label. The archetype never narrows the discovered graph or the evidence bar; it only selects which sections have something real to say.

## 5. Expand the graph deterministically
- Use a work queue with explicit discovered, queued, reading, expanded, terminal, boundary, cycle, unresolved, and out-of-scope states.
- Expand in bounded waves. Prioritize the root, critical custom logic, material SQL branches, and fields that drive important outputs; read supporting/standard objects to the depth required by the chosen profile.
- Read each canonical object/version once; attach every occurrence and path to that read. Detect cycles without dropping the cycle edge.
- Close each path only with evidence for a verified terminal, a declared boundary/limitation, a justified scope exclusion, or a cycle. Empty queue alone is not a completeness claim.
- Respect provider pagination, caps, depth limits, truncation flags, authorization errors, and unavailable source. Record each limitation and its effect on completion.
- When several tools/providers are available, use authorized read providers suited to each evidence type. Do not probe for write capability or imply an unavailable read check passed.

### Provider selection when ARC-1 is available
- Start with exact root metadata/source and a source-derived dependency overview; use the system's native relation/dependency provider where available, then read the specific source needed to verify each important edge.
- For SAPContext, use `action="deps"` to understand the root and its source-derived dependency contracts/KTD; it is not a complete recursive inventory. Use `action="impact"` only for DDLS blast-radius questions such as downstream consumers or change impact, not as a substitute for tracing the root's upstream SQL dependencies.
- Use SAPNavigate `action="references"` for where-used consumers/callers and `action="relations"` for native object relationship maps when supported. Treat returned where-used rows as static references, not proof of runtime calls; honor caps and pagination.
- Read the exact root implementation and targeted dependency sources with SAPRead. For a class, inspect relevant method bodies; for CDS, inspect the full DDL and the sources of material FROM/JOIN/set-operation/table-function dependencies. Do not repeatedly fetch unchanged source.
- If one provider cannot supply source, relationships, or a metadata category, use another already-authorized read provider only when available; otherwise record the exact evidence gap. Do not guess an ARC destination, retry a denied operation through a different route, or infer write capability.

For other SAP integrations, map the same evidence needs to the available read APIs: exact metadata, source, native relationships/where-used, and targeted implementation reads. Do not invoke a tool merely because its name suggests a capability; use only documented, available read operations.

## 6. Parse supplied dependency artifacts without format assumptions
First identify the artifact's schema and representation: adjacency list, nested hierarchy columns, path-per-row, graph JSON, spreadsheet, or another format. Preserve original row/node/edge identifiers and ordering.
- For hierarchy-column exports, infer depth from populated hierarchy positions if headers are blank or duplicated; reconstruct parentage from depth and row order only when the structure supports it.
- For adjacency exports, use explicit node/edge keys. For path-per-row exports, retain every distinct path occurrence.
- Treat syntax markers such as `SELECT`, `UNION`, or `UNION ALL` as structural operators, not repository objects.
- Prefer the explicit canonical object-name field; keep different raw aliases separate and verify names against current metadata when possible.
- If parsing or edge identity is ambiguous, mark it `PARSER_LIMITATION` or `UNRESOLVED`; do not invent IDs, parentage, names, or exact counts.

See `dependency-tree-reconciliation.md` for detailed export reconciliation and `occurrence-vs-canonical-counting.md` for count semantics.

## 7. Interpret without overstating
- Separate `OBSERVED`, `INTERPRETATION`, `ASSUMPTION`, `HYPOTHESIS`, `UNVERIFIED_INTENT`, and `NOT_COLLECTED`.
- Support behavior claims with source locations or stable evidence IDs. A name, annotation label, or dependency edge alone does not establish business meaning.
- For consequential ambiguity, compare plausible hypotheses, seek discriminating and counter-evidence, state a falsification check, and keep re-analysis bounded.
- Separate static structure from runtime behavior, performance, authorization outcomes, and data results. Claim these only when the relevant runtime/test evidence was actually collected.
- Report source-observed behavior even if it appears defective; assess requirement compliance separately and call it unverified when no requirement evidence is available.

## 8. Deliver and accept
For `TECHNICAL_SPECIFICATION`, use the selected template (default: the skill's canonical template), include material evidence/registries, run the blocking canonical-name check, reopen the file, and validate counts, paths, limitations, and acceptance. For `CHAT_ANALYSIS`, provide the same findings and evidence concisely in chat, preserve full canonical names, state scope and limitations, and create no artifact. `BOTH` does both without changing the analysis.

Use structural completion statuses from `completion-and-acceptance.md`; report semantic/lineage completion separately. A parsed export or complete custom-code graph does not prove all SAP objects, external systems, or runtime paths were covered.
