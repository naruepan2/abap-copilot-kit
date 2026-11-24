# Scalable Analysis for Large SAP Objects

Use this playbook only when reconnaissance shows a large/multi-branch graph, repeated reads/context pressure, or a meaningful timeout risk. It changes task organization, **not** the requested scope, evidence bar, safety boundary, or acceptance criteria. Small analyses should stay in the normal workflow without worker orchestration or scratch files.

## Core invariants

- The confirmed target, allowed read operations, root, and requested scope remain fixed. Never infer a destination or assume a worker has SAP access.
- The coordinating agent owns the authoritative run manifest, object/occurrence registries, queue, evidence index, count totals, and final acceptance. Workers provide proposals/evidence; they do not independently declare global completeness.
- Deduplicate source reads by verified canonical object/version while preserving every distinct occurrence, edge, path, and provider metric.
- A speed or context limit may stop expansion at a checkpoint and produce a declared partial result. It never authorizes dropping branches, fabricating facts/counts, or upgrading partial work to complete.
- Use only authorized read operations. Static source analysis does not execute a report, service, XPRA, or business process.

## Wave-based execution

1. **Reconnaissance:** resolve the root and target, read the root's metadata/source and a bounded dependency overview, and estimate branch independence, read volume, and context/timeout risk. Use qualitative evidence (branch count/shape, source volume, provider limits, remaining execution budget); do not invent a universal object-count threshold. Do not create workers before there is a concrete partition plan.
2. **Freeze the partition:** split only on evidenced, mostly independent branches (for example, separate service exposure, authorization, or dependency branches). Define exact root/branch scope, excluded areas, requested reads, and expected hand-back fields for each worker. Keep shared ancestors and cross-branch reconciliation with the coordinator.
3. **Run a bounded wave:** process a small batch of independent branches. Parallelize only where the current tools actually support independent operations and the system/provider limits are understood. Keep the single-threaded path when parallel access is unavailable, unsafe, or adds coordination cost.
4. **Checkpoint:** at the end of each wave, reconcile accepted evidence, update exact counts and queue states, list unresolved/blocked work, and persist a recovery point if a scratchpad is in use. Continue only when time/context budget and evidence quality permit.
5. **Close or pause:** after all in-scope work closes, perform normal final acceptance. If execution must stop earlier, preserve the residual queue and return `PARTIAL_OR_TRUNCATED`/the applicable non-SQL partial status, with the last verified checkpoint and a concrete resume point. Queue-empty is not a substitute for reconciliation.

Do not promise that sub-agents will reduce elapsed time. Their use is optional and conditional on actual availability, shared target authorization, and branch independence. Avoid duplicate reads by assigning each canonical object/version a single read owner per run; workers may cite an existing evidence record instead of rereading it.

## Worker hand-back contract

Ask each worker to return only structured, verifiable findings for its assigned branch:

- assigned root and exact branch/scope;
- confirmed target context or explicit statement that no backend read was performed;
- canonical object name/type as returned by evidence, source version/location/read result;
- each occurrence/edge/path with relation type and evidence pointer;
- source-read status, close reason, unresolved/provider-limited items, and any counts with denominator/root-inclusion policy;
- explicit distinction among `OBSERVED`, `INTERPRETATION`, `ASSUMPTION`, and `NOT_COLLECTED`;
- no overall completion claim beyond the assigned branch.

The coordinator verifies identifiers and names, checks for duplicate/inconsistent object-version records, reconciles overlapping edges, merges counts using the occurrence/canonical rules, and retains conflicts as unresolved until evidence resolves them. A worker conclusion without resolvable evidence is not accepted as a fact.

## Optional JSONL scratchpad

Use a scratchpad only when cross-wave state is too large or fragile to keep in working context. It is a local, temporary checkpoint—not source-of-truth SAP data, a deliverable, or a replacement for evidence references. Keep it as JSONL in OS temp: a Markdown scratch file would be an unparseable second authored copy, and a SQLite store would add a second authority plus writer/version governance for a run-scoped artifact. SQLite in this kit remains a deferred, derived locator-index plan only, never an authority for evidence. If the execution environment cannot safely create, inspect, or remove a local file, do not simulate the scratchpad in chat or use an unapproved storage route; continue without it or return a checkpointed partial result.

- Prefer a unique run-specific file under the OS temporary directory, never inside the project/workspace. Record the exact path in the run manifest. Do not overwrite or delete a pre-existing file; on a collision, choose another unique path.
- Append UTF-8 JSON Lines: exactly one complete JSON object per line. Keep records small, versioned, and independently parseable. Do not put credentials, secrets, or unnecessary business data/source dumps in it.
- Suggested record types: `run`, `object`, `occurrence`, `path`, `evidence`, `checkpoint`, `close_reason`, and `worker_result`. Include `schema_version` and a unique `run_id` on every record. Store exact verified names, identifiers, statuses, counts and evidence pointers; distinguish null/unknown from empty values.
- Make each append atomic at the record level where practical. After a write batch, parse the file and validate required fields/JSON syntax before considering that checkpoint durable. Track counts from the records rather than handwritten approximations.
- A minimal record shape (illustrative only; values must come from actual evidence):

```json
{"schema_version":1,"run_id":"<unique-run-id>","record_type":"object","object_id":"<stable-id>","name":"<verified-full-name>","type":"<verified-type>","read_status":"read|not_read|failed","evidence_refs":[]}
{"schema_version":1,"run_id":"<unique-run-id>","record_type":"occurrence","occurrence_id":"<unique-id>","parent_id":"<object-id>","child_id":"<object-id-or-operator-id>","relation":"<observed-relation>","path_id":"<path-id>","evidence_refs":[],"disposition":"<status>"}
{"schema_version":1,"run_id":"<unique-run-id>","record_type":"checkpoint","wave":1,"completed_ids":[],"pending_ids":[],"blocked_ids":[],"counts":{"occurrence_count":0,"unique_object_count":0,"source_read_count":0,"selected_scope_count":0}}
```

Do not copy the illustrative placeholders literally into a report or treat them as SAP names. JSONL is append-friendly and recoverable but not a database: validate encoding, schema version, unique IDs, referential integrity, duplicate records, and partial trailing lines before merging.

## Cleanup and recovery

1. Stop scratchpad writes and parse/validate every line, including the final line. If the last append is incomplete, preserve/recover valid prior records and explicitly account for the lost record; do not silently ignore it.
2. Rebuild object, occurrence, path, evidence, and queue ledgers from validated records; reconcile with the live run state and produce/validate the selected deliverable (or chat response).
3. Delete only the exact unique scratchpad path created by this run. Verify that exact path is absent. Never wildcard-delete temp files or delete a path whose ownership is uncertain.
4. If cleanup or absence verification fails, report `SCRATCHPAD_CLEANUP_FAILED`, exact path/status, and do not claim clean completion. If a run is intentionally paused for resumption, keep the scratchpad only when the user has explicitly asked for resumability; report it as retained temporary state and its exact path. Otherwise delete it even for chat-only delivery.
5. If no scratchpad was used, state cleanup as `NOT_USED` where the acceptance format asks for cleanup; do not create one just to record that none was used.

## Completion criteria

Scalable execution is successful only when the normal requested-scope acceptance checks pass, or a truthful partial status is returned with a validated checkpoint and resumable residual queue. Confirm: (a) no in-scope branch was silently dropped, (b) all counts are labeled and reconciled, (c) each closed item has evidence and a close reason, (d) worker findings are source/evidence-resolvable, and (e) scratchpad lifecycle is reported accurately.
