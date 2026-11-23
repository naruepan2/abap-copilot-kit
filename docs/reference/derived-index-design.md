# Derived index design — future option, not implemented

Status: **design constraint record, 2026-11-23.** No database file, schema, index or reader exists.
This note records the safe shape a SQLite index would have to take if a recorded decision is ever
overridden. Decision and triggers: [`../memory-decisions.md`](../memory-decisions.md) (V9.4 rows)
and [`improvement-register.md`](improvement-register.md) (§Reviewed from V9.4).

Why this note exists: V9.4 and later brainstorming proposed per-project, per-program, knowledge
and memory stores. The toolkit measured 2 program records, 0 agent-context notes, one writer and a
~540-token context pack. Storage is not the bottleneck; a second authority would be a new failure
mode. If a corpus reaches the recorded triggers, this is the shape to build — not V9.4's
authoritative `.abap-agent/memory.db` with migrations, WAL, FTS and a second adapter.

## The one rule

Canonical files stay canonical. A derived index answers **"where should I look?"** never **"what is
true?"**. Every decision-bearing value is re-read from the canonical file after hash verification.
Deleting the index is always safe; rebuilding it is always possible.

## Shape if adopted

| Property | Value |
|---|---|
| Location | `Projects/<P>/_index/derived.db`, one DB per project, gitignored by the existing `Projects/*` rule |
| Writer | one process per DB, exclusive fence, fail fast on a second writer; all other processes open read-only |
| SQLite settings | default journal only; no WAL tuning, no FTS, no virtual tables, no migration chain |
| Version | one schema-version constant in the writer; on mismatch delete and rebuild, never migrate |
| Payload | locators and tiny non-authoritative copies only; no bodies, no authority fields, no SID/client/host/user/transport, no hashes of those values |

### Common row contract

Every row, including a one-row meta record, carries:

- `source_path` — forward-slash relative to the kit root, checked against a per-domain allowlist;
  no absolute paths, `..` or Windows separators;
- `source_sha256` — SHA-256 of the canonical file bytes.

Two value classes only:

- **indexed copy** — narrowed candidates, re-read before use;
- **never stored** — authority fields stay in their one existing home.

| Domain example | Indexed copy (non-authoritative) | Never stored |
|---|---|---|
| project locator | path-derived `project_code` | system, clients, owner, any transport |
| program locator | path-derived `project_code`, `program_name` | transport, spec paths/status, overrides |
| knowledge note locator | title, type, applies-to from frontmatter | `agent_context`, `instructional_authority`, status, confidence, freshness, body |
| command ledger index | command id, run id, status, source line | object, action, hashes, postconditions, timestamps |

## Rebuild and fail-closed retrieval

1. Acquire the writer fence; a second writer gets `WRITER_BUSY`, never a queue.
2. Enumerate canonical sources by explicit allowlist; reject anything outside it.
3. Hash each source; compute a manifest hash over sorted `(relative_path, sha256)` pairs. This detects
   added, removed and changed files — a per-row hash alone does not.
4. Extract only indexed-copy fields, using the existing owner's parsing rules. The DB defines no new
   note schema, no new status enum and no new fact rule.
5. Populate a fresh temporary DB in the same directory, then atomically replace the old one.
6. Before answering any query, recompute the manifest. Missing DB, wrong version, missing or extra
   file, or any hash mismatch ⇒ return `STALE_INDEX` and **no rows**. Rebuild once, retry once; if
   still mismatched, report and stop. Never skip only the bad row — that is fail-open.

`context-pack.ps1` remains the only note-retrieval path and `command_intent.py` remains the only
in-flight command detector. The index narrows their candidates; it does not replace them.

## Promotion triggers — all prerequisites plus one per table

Prerequisites before any table exists: the V9.4 decision rows are overridden with a recorded reason;
measurements follow the register's ≥5 warmups / ≥30 iterations rule; divergence, fail-closed rebuild
and writer-busy selftests are green in `verify-all.ps1`.

| Table | Trigger |
|---|---|
| project / program locator | A measured full scan dominates task time at the real record count. Two records today: no trigger. |
| note locator | A real reviewed-note corpus exists (zero today) **and** the pack scan is measured as the bottleneck. Drafts are never indexed. FTS has its own >5,000 notes / 25,000 chunks trigger. |
| command ledger index | A real crash leaves ambiguous state **and** `command_intent.py unreconciled` is measurably too slow. Today the ledger is the canonical store by decision. |

## Gate integration and one home per rule

- `verify-all.ps1` keeps the `command-ledger` gate; if an index is ever built, extend its selftest
  with hash mismatch, missing/extra source, duplicate path, writer-busy and read-only cases in a
  throwaway folder.
- `census.ps1` must gain one explicit inventory class for `Projects/*/_index/derived.db`. A database
  appearing anywhere else stays `BLIND` and fails the census.
- The binary DB stays gitignored and is never backed up by `kit-backup`; `Projects/` remains local.
- Decision/triggers: `docs/memory-decisions.md`. Provenance and measurements:
  `docs/reference/improvement-register.md`. Note schema and promotion:
  `docs/reference/agent-context-notes.md`. SID/client/transport ownership: `Projects/README.md`.
  Ledger semantics: `scripts/command_intent.py` in the delivery skill.
