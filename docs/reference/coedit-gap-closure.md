# Co-edit gap closure — decision record

Status: **design, 2026-11-19. Not implemented.** No template, gate, agent file or SAP object was
changed for this note. It consolidates nine idea documents from the local `New folder` workspace;
those documents are idea input, not evidence. Verified statements below carry the source from
`human-ai-coedit-object-evidence-brief.md` §3, checked against installed `arc-1@1.10.1` source on
2026-11-19. Everything else is `IDEA`, `UNVERIFIED` or a decision awaiting capability preflight.

## 1. Direction

Stop trying to detect every external edit. Make the write path fail closed instead.

Existing detection (TR scan, package anchor, inactive beacon, lock polling, graph) is a **hint**:
it chooses what to read. It cannot prove that no one is writing. Correcting a missed detection is
not possible after the fact; preventing an overwrite at commit time is.

Consequence: the known blind spot — a person edits a draft, activates it into an open transport,
and no prior hash of that object was captured — stays open. If an `object_state` hash *was*
captured earlier, a later change can be detected by comparing hashes; that path is still
`UNVERIFIED` until a read-only probe confirms stability. Either way the commit window must be
guarded: detection never authorises a write.

## 2. Gap taxonomy — separate problems, separate metrics

| Gap | Can it be closed | Mechanism | Metric |
|---|---|---|---|
| Wrong write | Yes, at the commit boundary | JIT fresh read + CAS where supported + explicit human gate otherwise + read-back | silent overwrite = 0 |
| Wrong attribution | No, not fully — SAP sees one user for all harnesses | local `by` / `by_actor` stamped from what the human says; otherwise `UNVERIFIED` | inferred actor = 0 |
| Wrong understanding | Reduced, never closed | sentinel + dirty frontier; graph as navigation cache only | recall and token benchmark |

Do not spend detection calls trying to close a wrong-attribution or wrong-understanding gap with
wrong-write controls. They are different failure domains.

## 3. Conflicts in the input documents — resolved for this design

| Conflict | Decision | Basis |
|---|---|---|
| Which server owns CAS — evidence brief says ARC-1 has `expectedSourceHash`; `coedit-patch-brief.md` says ai-dev has `edit_source(expected_source_hash)`, ARC-1 `SAPWrite` not mounted | **Per-harness, not global.** The contradiction is real and must not be resolved by copying one harness's result into the other. See §3.1 | two local documents describe different harnesses; neither is transferable |
| Field named `expected_source_hash` in most idea docs | Use the installed spelling `expectedSourceHash` when the schema is confirmed | `dist/handlers/schemas.js:677,789`, evidence brief §3.1 |
| "Receipt valid until invalidation event" / `pre_write_with_atomic_cas: session` | Reject for write authorisation. SAP emits no event for a direct draft edit, so a cached receipt can stay "valid" while the source changed. Commit receipt must be read in the commit window | evidence brief §5; absence of SAP edit event |
| "anchor = UX, CAS = safety" | Narrow it: fresh read + human gate are safety; CAS is one implementation when the operation supports it. CAS covers text-source `update` and class/procedural surgery only, not metadata/create/delete | `dist/handlers/editable-source.js:14`, evidence brief §3.1 |
| `TR state` removed in design note Part 2, but gate 10b still reads `open` | Keep as a known open item. Gate 10b must learn the event format before the old state field is removed from records | `rap-state-anchor-design.md` Part 2; evidence brief §2.2 |
| `rap_anchor` carries `verified_at` but no `source` / `by` | Reject. Every state fact needs `source`, `by`, `verified_at`, or `UNVERIFIED` | evidence brief §2.4 |
| `kind: classic|rap` versus 3-axis model | Keep `kind` as reporting metadata only. Change unit / physical write-set / observation strategy govern the protocol | Q6 documents converge on this |
| Token saving 10x–50x | Treat as an unverified vendor claim. Benchmark before repeating | `test1.md`, lean v2 |

### 3.1 Harness capability boundary

A capability observed in one harness is **not** evidence in another. `coedit-gap-closure-plan.md`
reports live observations from an OpenCode session; the evidence brief in this repository reports
installed-source facts from a VS Code session. Both are INPUT to this record, and neither may be
copied across the boundary.

| Harness | Claim | Evidence status here | Consequence |
|---|---|---|---|
| OpenCode (INPUT) | ai-dev exposes `edit_source(expected_source_hash)`, `write_source`, `lock_object`, `unlock_object`, `activate`, `get_inactive_objects`, `compare_source`, `get_source(include_hash=true)` | `LIVE`/`SRC` **in that harness only**; not observed in this session | May guide an OpenCode probe; may not authorise a write in VS Code |
| OpenCode (INPUT) | ARC-1 `SAPWrite` not mounted; ai-dev binary contains `expected_source_hash` | same boundary as above | Do not conclude either way for VS Code |
| VS Code (this repository) | ARC-1 source has `expectedSourceHash`, `assertSourceHash` under lock, `object_state`, `format="editable"`; lock owner comes from a 403 conflict | `SRC` from installed `arc-1@1.10.1`, evidence brief §3 | Source presence is not tool callability; still needs a live `tools/list` observation |
| VS Code (this repository) | ai-dev `.js` scan gave 0 hits for source-level CAS | Absence of evidence in a file subset, not proof of absence in the adapter | Keep as `UNVERIFIED`, do not repeat as fact |

Rule: **one capability matrix per harness**, keyed by `harness | system/client | tool | field |
version/date | evidence | CAS? | writer?`. A field missing from that matrix means the operation is
read-only or human-gated in that harness. The matrix is built from `tools/list` and read-only
probes, never from another harness's notes. Object hashes also carry `hash_engine` and
`source_locator`; hashes from different engines are not comparable (OpenCode plan §3.3).

## 4. Plan — ordered by benefit per unit of complexity

### Step 0 — capability preflight, before any design becomes a rule

Inspect the **live** tool surface, not idea documents:

1. which server is actually callable for the target system/client;
2. which write operations expose a source precondition, and its exact spelling and scope
   (whole object or source locator);
3. whether lock acquisition and release are exposed, and what the 403 lock conflict returns;
4. whether `object_state` and `format="editable"` are callable, with their exact parameter sets.

If a required capability is absent, the operation stays read-only or human-gated. Do not
substitute a similar-looking tool. This step settles the conflict in §3 before anything else.

### Step 1 — commit window, the core control

Every write to every object in the write-set follows one window:

1. after the human confirms, re-read the transport **and every object in the write-set** with
   `format="editable"`; capture `sourceHash` per source locator;
2. any hash different from the plan cancels that object or the whole batch — ask again;
3. acquire lock, write with `expectedSourceHash` from step 1, release in `finally`;
4. targeted read-back after activate; store the resulting hash; if activate succeeded but the
   read-back failed, mark `committed_unverified` and block dependent writes;
5. `412` / hash mismatch — stop, replan once, never replay the same write;
6. timeout after write — `OUTCOME_UNKNOWN`, zero retries until read-after-timeout proves outcome;
7. `423` — bounded backoff then handoff; never force unlock from a local claim.

Re-reading only the transport is not enough; the TOCTOU window sits between the confirmation and
the write, not between the two transport calls.

### Step 2 — evidence discipline

- `changes.md` stays append-only; events (`activated`, `released`, `cancelled`, `published`) are
  written once, state (`draft`, anchor, `verified_at`) is derived and rebuildable.
- Every state fact carries `source`, `by`, `by_actor`, `verified_at`. Add
  `verification_basis: source_hash | transport_snapshot | user_attestation` and `confidence`:
  TTL tells the age of an observation, not whether it is still true.
- Attribution comes from the human naming the harness. SAP user identity cannot separate
  VS Code from OpenCode. Never infer it from tool surface or `CHANGEDBY`.
- Gate 10b needs updating before the old `TR state` format disappears, otherwise a wrong state
  silently skips the baseline check.

### Step 3 — recognition, two rounds

Round 1 is attribution ("which harness made this change?"); round 2 is authorisation ("write
now?"). They must not be merged into one question. Show an evidence card for the one to five
objects whose fingerprint moved: object and type, source locator, before/after short hash,
`observed_at`, observation source, and a one-line intent. Options: mine / other harness / not
this work / unsure. "Unsure" means stop and stay read-only.

Human preemption applies to the selected write-set, not the whole project. Stop at safe points:
before adding an object, before first write, before activate/publish. If preemption arrives
mid-write, finish cleanup and unlock first, then become a read-only observer.

### Step 4 — recovery

Capture a pre-image only for objects actually written, content-addressed under `.baseline/`, not
a snapshot of all 120 objects of a RAP stack. Undo is a new write under the CAS of the **current**
hash: if current equals the recorded post-image, write the pre-image; if not, three-way reconcile
(`pre-image`, AI result, current) and ask the human on conflict. Append an event; never rewrite
history.

### Step 5 — scale, after the safety core

Sentinels by concern: root DDLS for data model, BDEF + behavior pool for behavior, DDLX/projection
for UI metadata, SRVD/SRVB for exposure, draft declaration for draft. Expand only to immediate
neighbours 2 hops when a fingerprint moves. `impact` alone is insufficient; `deps`, `usages` and
`relations` answer different questions. A partial graph may not determine activation order and
may not authorise a write.

A Knowledge Graph, if built, is a navigation cache between the assistant and read tools. It is
not SAP authority and not a decision gate. Enable it only when telemetry shows repeated reads or
impact misses; the 10x–50x claim is not a business case.

## 5. Deferred — no implementation without a metric or incident

Shared cross-harness ledger, localhost broker, SAP Z ledger, Redis/etcd, ETag/304 adapter,
PROV-O, semantic/business capability graph, seven-dimension risk score, 25–35-case simulator,
full-package snapshot, auto-accepted inferred edges, RAP business ETag as a repository-source
guard, opening every MCP server at session start.

Reason is uniform: no evidence yet that the problem is frequent or expensive enough to justify
the component. Adding these controls to the default path would create the verification loop and
token cost the lean documents warn about.

## 6. What must stay UNVERIFIED until checked

- The CAS-owning server and the exact write operation that supports it, **per harness** (§3, step 0).
- Whether `object_state` returns a stable `sha256` across two reads and whether `force_refresh`
  exposes a change after activation.
- Whether lock handles are obtainable before a write and whether an owner is queryable at all;
  the installed ARC-1 parses an owner from a 403 conflict message (`dist/adt/errors.js:459`),
  not from a standby query.
- Whether any ADT repository endpoint exposes ETag / `If-Match` with source-level meaning.
- Whether activation creates a version for an open transport in the target release.
- Whether batch activation can partially succeed, and what state the remaining objects hold.
- Whether two harnesses on different hosts ever need coordination at all.

Each item needs a read-only probe, a schema check or a controlled sandbox test before it becomes
a rule. No item in this note authorises a write, activation, publication or transport change.

## 7. Related

- `docs/reference/rap-state-anchor-design.md` — four-layer anchor, event handoff, limits.
- `docs/reference/corrections.md` — where findings from verified corrections are kept.
- `AGENTS.md` — input tiers, evidence discipline, SAP target confirmation.
- `agents/abap-developer-by-pongg.agent.md` — one object, one writer, one session; tool routing.
