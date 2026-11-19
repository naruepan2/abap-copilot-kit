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
`source_locator`. The prohibition on cross-engine hash comparison still applies across harnesses
and adapters; within one adapter it must be tested, not assumed — see §3.2.

### 3.2 Read-only probe — ARC-1 in this VS Code harness, 2026-11-19

Authorisation: the user stated the target SID and client, read-only, one server at a time, scope
limited to `object_state` plus editable hash. Those identifiers are deliberately not recorded in
this public file. No write, lock, unlock, activate, publish or transport call was made. The tool
did **not** independently confirm the SID or client:
`SAPRead(type="SYSTEM")` returned only a user field and an empty collections list — no SID and
no client. System identity therefore stays `UNVERIFIED` from the tool side; the user's statement
is the only basis here. The user value is deliberately not recorded in this public file.

Object used: `CL_ABAP_REGEX` (CLAS, package `SABP_REGEX`), a standard SAP object — no customer
identifier and no customer data involved. Calls: one `SAPSearch`, two `SAPDiagnose(action="object_state")`,
two `SAPRead(type="CLAS", format="editable")`, one `SAPRead(type="SYSTEM")`.

| Check | First read | Second read | Verdict |
|---|---|---|---|
| `object_state` main active `sha256` | `fbce064b8a4bd2ef9dbdd8a930560838569b63dc20d0a44f1d195bb505f50cf0` | identical | stable across two reads ~6 s apart |
| `object_state` inactive `sha256` | same as active | same as active | no draft divergence observed |
| `hasInactiveDivergence` | `false` | `false` | field present, true case not tested |
| `format="editable"` `sourceHash` | `fbce064b8a4bd2ef9dbdd8a930560838569b63dc20d0a44f1d195bb505f50cf0` | identical | stable across two reads |

`object_state` also returned per-section hashes: `main` 7523 bytes, `definitions` 173,
`implementations` 132, `macros` 106, `testclasses` absent (404). The `editable` source is the
combined `main` unit, so its hash equals `object_state.main.active.sha256`, **not** the include
section hashes. Record `source_locator` with every hash; `main` and `implementations` are different
values for the same object.

Consequences, stated narrowly:

- Within ARC-1, `object_state.sha256` and `format="editable"`'s `sourceHash` are the same digest
  for the `main` locator. `hash_engine` must still be recorded, and cross-harness comparison
  (ARC-1 vs ai-dev) remains forbidden until tested.
- G1: the `hasInactiveDivergence` field is callable and readable. Detecting an actual draft was
  not exercised.
- G2: capturing a hash and re-reading it stably is confirmed. Detecting a **changed** source after
  an external edit was not exercised; that needs a seeded edit in a sandbox. Do not call G2 closed
  on this evidence alone.
- G3: unchanged. With no earlier hash there is still nothing to compare.
- Nothing in this probe tested `force_refresh` after activation, lock ownership, CAS rejection,
  403/409/412/423 routing, DDLS or BDEF sections, or any second harness.

### 3.3 Read-only probe — ABAP FS and ADT MCP, same VS Code harness, 2026-11-19

Same authorisation as §3.2: read-only, one server at a time. No write, lock, activate, publish or
transport call. The abstraction here is the **MCP server selected in the picker**, not a different
hosting harness; tool availability still differs by server and must be recorded per server.

| Server | Call made | Result | Use for co-edit |
|---|---|---|---|
| ABAP FS | `abapfs_get_object_info(CL_ABAP_REGEX, CLAS)` | object type, description, package, total lines 214, main source URI — no hash, no divergence flag | object identity and source locator; **not** a hash source |
| ABAP FS | `abapfs_get_object_source(version="inactive")` | source text lines 1–5 of 214 plus the same main URI — no `sourceHash`, no active/inactive comparison | useful for targeted reads; cannot replace ARC-1 `format="editable"` for CAS pre-image |
| ADT MCP | `abap_destination_list` | empty list — no logged-on destination | **unusable at this moment.** Do not infer a destination from the SID or from another server's connection; logon is a separate, user-controlled step |

Consequences:

- The capability matrix has one row per **server in this harness**. ARC-1 currently supplies the
  hash-bearing reads; ABAP FS supplies metadata and targeted source; ADT MCP is not available
  until a destination is logged on.
- `abapfs_get_object_source` returning source without a hash does not prove the server has no hash
  capability anywhere. It proves only that this call does not return one. Do not build a rule that
  depends on an untested ABAP FS hash.
- Because ADT MCP had no destination at the first check, the ATC/validation column was blank. A
  blank matrix cell means the operation is unavailable, not failed and not passed.
- No claim from the OpenCode plan about ai-dev tool names was tested here; it remains INPUT only.

### 3.4 ADT MCP after user logon, same VS Code harness, 2026-11-19

The user logged on a destination themselves; `abap_destination_list` then returned one entry. The
destination ID, the package name and object names are deliberately **not** recorded in this public
file — they belong in the local record. No write, lock, activate, publish or transport call made.

| Call | Result | Use for co-edit |
|---|---|---|
| `abap_destination_list` | one destination | logon is user-controlled; never infer the ID from a SID or another server's connection |
| `abap_repository_search_object` with `objectTypes=[CLAS,DDLS]` and a package filter | 11 objects returned, CLAS/OC and DDLS/DF | package discovery and candidate enumeration work |
| `abap_object_read_file` on one DDLS | source text, `totalLines`, `lineRange`, `truncated` — **no `sourceHash`, no ETag** | targeted source read; cannot supply a CAS pre-image or an outcome hash |

Consequences: ADT MCP fills the *discovery and source-read* column of the capability matrix, not
the hash column. Like ABAP FS, this call returned no hash; that proves only what this call returns,
not that the server has no hash capability anywhere. ARC-1 remains the sole verified hash source
in this harness. ATC tools were not run — no check, test or activation was requested.

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

## 5. Sandbox scratch area — design (IDEA, not implemented)

This section is an IDEA. It creates no record, no SAP object and no write permission.

### Why reuse the existing `_sandbox`

`Projects/README.md` already defines `Projects/<PROJECT>/_sandbox/` as scratch space, safe to
delete. `tooling/workspace-sync.ps1:186-201` excludes folders starting with `_` from program
discovery, and `.gitignore` excludes all of `Projects/*` except the conventions file. A nested
`Projects/<PROJECT>/<PROGRAM>/<SANDBOX>` would add a second, deeper convention that the same rule
does not exclude, and would blur the program folder's role as the intent record. Use the existing
project-level scratch area, keyed by `<SANDBOX_ID>`.

### Layout

```text
Projects/<PROJECT>/_sandbox/<SANDBOX_ID>/
  sandbox.yaml        # what may be touched, by whom, until when
  observations.jsonl  # append-only probe and seed events; NOT changes.md
  baseline/           # content-addressed pre-images, only for objects actually seeded
  notes.md            # disposable scratch reasoning
```

Do **not** create `program.yaml`, `project.yaml`, `spec/`, or `changes.md` here. Gate 10b recurses
all files named `changes.md` under `Projects/` (`tooling/verify-all.ps1:2424`) and requires a
Baseline column with `.abap` paths; a sandbox log with content-addressed blobs would fail that gate
by design. The underscore prefix keeps the folder out of the program census and the private mirror.

### Manifest — `sandbox.yaml`

Copy `templates/sandbox.yaml.template`; it carries the same fields with inline instructions.

```yaml
sandbox: <SANDBOX_ID>
project: <PROJECT>          # pointer only; system/client inherited from project.yaml
purpose: G2 changed-hash detection | G1 draft detection | G6 timeout route | ...
owner: <human who authorised the test>
created: <YYYY-MM-DD>
expires: <YYYY-MM-DD>
target_confirmation: user-stated | sap-confirmed   # how, never the value
allowed_ops: [observe, seed_write]
forbidden_ops: [activate, publish, release, transport_release]
objects:
  - object: <TYPE/NAME>     # a real, writable SAP object in a sandbox package
    locator: main | definitions | implementations
    hash_engine: arc-1.object_state | arc-1.editable
    role: seed_target
link:
  program: none | <PROGRAM>
  change_unit: none | <CU>
```

`system` and `client` stay in `project.yaml`, one fact in one file. They must be confirmed at
session start; a blank field is a pending question, never a reason to guess. The manifest records
only *how* the target was confirmed, not the identifier itself. A manifest alone never authorises
a write — that needs a separate, explicit approval.

### Journal — `observations.jsonl`

One append-only event per observation or seed step. Minimum fields: `event_id`, `sandbox`,
`intent_id`, `object`, `locator`, `hash_engine`, `before_hash`, `after_hash`, `observed_at`,
`tool` + `version`, `by`, `by_actor`, `verification_basis`, `outcome`, `evidence_ref`. A derived
Current View may be rebuilt from these events; do not edit an earlier event.

### Rules

1. A local folder cannot change a SAP hash. The seed target must be a real object in a writable
   sandbox package; an empty `<SANDBOX_ID>` directory proves nothing.
2. Capture a pre-image only after a fresh read of the object actually being seeded, store it as a
   content-addressed blob under `baseline/`, and name the locator and hash engine.
3. Seed writes use the commit-window rule from §4 Step 1. If no writer with a confirmed CAS is
   available for this server, the seed is human-gated, not autonomous.
4. After a seed, re-observe with `object_state` and `format="editable"`. A changed hash or
   `hasInactiveDivergence=true` is the signal under test; an unchanged hash is a result, not a
   failure to hide.
5. Restore by a **forward write** under the current hash. If current differs from the recorded
   post-image, reconcile and ask; never restore a blob blindly.
6. On success or at `expires`, delete the whole `<SANDBOX_ID>` folder unless an incident pins it.
   If the result changes a decision, add one `SANDBOX` / `HANDOFF` event to the program's
   `changes.md` — intent only, no source and no baseline blob reference.
7. Verify with `git check-ignore` that the sandbox path is ignored before writing anything. Never
   copy an object name, SID, client, user, TR or source snippet from it into a tracked document.

### What it can and cannot prove

- Can exercise G1 draft detection, G2 changed-hash detection, G6 timeout routing and G9 forward
  undo, provided a real seed object exists and the ops are explicitly approved.
- Cannot create a SAP-side event feed, close G3 (no earlier hash), validate another harness, or
  prove CAS on a writer until that writer's precondition is confirmed in this harness.

## 6. Deferred — no implementation without a metric or incident

Shared cross-harness ledger, localhost broker, SAP Z ledger, Redis/etcd, ETag/304 adapter,
PROV-O, semantic/business capability graph, seven-dimension risk score, 25–35-case simulator,
full-package snapshot, auto-accepted inferred edges, RAP business ETag as a repository-source
guard, opening every MCP server at session start.

Reason is uniform: no evidence yet that the problem is frequent or expensive enough to justify
the component. Adding these controls to the default path would create the verification loop and
token cost the lean documents warn about.

## 7. What must stay UNVERIFIED until checked

- The CAS-owning server and the exact write operation that supports it, **per harness and per MCP
  server** (§3, step 0).
- Whether ADT MCP's destination is still logged on at the next session; the destination list was
  empty before the user logged on and is not guaranteed to persist (§3.3, §3.4).
- Whether `force_refresh` exposes a change after activation. Stability of `object_state.sha256`
  and editable `sourceHash` is now verified in this harness (§3.2); change detection is not.
- Whether the SID/client behind this ARC-1 connection is the one the user stated — the tool did
  not report either value.
- Whether lock handles are obtainable before a write and whether an owner is queryable at all;
  the installed ARC-1 parses an owner from a 403 conflict message (`dist/adt/errors.js:459`),
  not from a standby query.
- Whether any ADT repository endpoint exposes ETag / `If-Match` with source-level meaning.
- Whether activation creates a version for an open transport in the target release.
- Whether batch activation can partially succeed, and what state the remaining objects hold.
- Whether two harnesses on different hosts ever need coordination at all.

Each item needs a read-only probe, a schema check or a controlled sandbox test before it becomes
a rule. No item in this note authorises a write, activation, publication or transport change.

## 8. Related

- `docs/reference/rap-state-anchor-design.md` — four-layer anchor, event handoff, limits.
- `docs/reference/corrections.md` — where findings from verified corrections are kept.
- `AGENTS.md` — input tiers, evidence discipline, SAP target confirmation.
- `agents/abap-developer-by-pongg.agent.md` — one object, one writer, one session; tool routing.
