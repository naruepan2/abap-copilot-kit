# RAP state anchor — design note

Status: **design, 2026-11-19. Not implemented.** No template, gate or record schema was changed.
This page exists so the next session can continue from the decision rather than re-derive it.

## Problem

A RAP business object can span 20 to 120 repository objects: interface and projection CDS views,
behavior definitions, behavior pools, metadata extensions, service definitions and bindings. Two
facts make the usual "read every object to see what changed" approach unusable:

1. Reading 120 object versions on every handoff is slower than doing the work.
2. SAP has no event or webhook for an external edit. When a person changes something directly in
   SAP, the local `changes.md` becomes stale — and no amount of checking will tell us *why* it
   changed.

The goal is therefore **not synchronisation**. The local log is a human-written intent record, not
a mirror of SAP. The goal is a seamless handoff: notice that SAP moved, ask one question, record
the answer, continue.

## What a RAP stack has that a classic program does not

The architecture has four layers, and a change in one layer is not visible in the others:

| Layer | Objects | What changes here |
|---|---|---|
| persistence | database tables, draft tables | fields, draft enablement |
| BO interface | root/interface CDS, base BDEF, behavior pool | data model, behavior logic |
| service contract | projection views, projection behavior, metadata extension | exposed fields, operations, UI annotations |
| publication | service binding | protocol, published/unpublished endpoint |

A metadata extension is an annotation source, **not a runtime hop**. It changes what Fiori Elements
sees through `$metadata` without changing the root CDS version. A service binding can be published
without any object version changing. A draft can be edited without activating anything, so
`VERSIONS` shows no new entry.

An anchor that watches only the root CDS therefore misses three of the four layers.

## Proposed anchor

Store four fingerprints per RAP program in `program.yaml`, with one `verified_at` date:

```yaml
rap_anchor:
  persistence: <table names and count>
  bo_interface: <root CDS version id>
  service_contract: <projection list plus metadata-extension annotation fingerprint>
  publication: published | unpublished | unknown
  verified_at: <YYYY-MM-DD>
```

Cost per handoff is two to four read-only calls, not one per object:

- `GetPackageContents` or `GetPackageTree` for the package — object count and last-touched date.
- `SAPRead(type="VERSIONS", name=<root entity>)` — author and date on the BO interface.
- projection and metadata-extension source — only when the service layer needs checking.
- `abap_business_service_list` or the publish result — for the publication state.

A count or fingerprint change means SAP moved. It does **not** mean the AI should guess why.

## Handoff rule

On detecting drift, stop and ask once:

```
SAP <package> changed after <verified_at>. Local changes.md has no record for:
<the 1-5 objects whose fingerprint changed>

A) include in unit <existing> — supply What, Why and TR
B) create a new unit — supply name and TR
C) ignore the drift — confirm you or someone else made this change
```

Write the answer as a new block `unit: RECONCILE`. Never edit an earlier block: it is the record of
what was believed at the time, and rewriting it destroys the trail.

## changes.md shape

Keep **one** `changes.md` per program. A second file would not be mirrored by
`workspace-sync.ps1` (its allowlist names `changes.md` only), would not be covered by census in the
same way, and would violate the one-home-per-rule principle already documented in the README.

Separate RAP from classic with a `unit:` label inside the same file:

```
## v12 · 2026-11-18 · TR 123456 · open · unit: RAP_ORDER_001 · verified: 2026-11-18

- [x] save: 20 objects under ZORDER_*
- [x] activate: interface, base BDEF, pool, projection, binding
- [ ] publish: ZSRVB_ORDER
- What: ...
- Why: ...
- Evidence: ...
- TR source: SAPTransport(get) · approved by user
- Baseline: `.baseline/ZI_ORDER_123456.abap`
```

Rules:

- `unit:` is AI-suggested by default; the user may override it.
- `Steps:` uses `[x]` / `[ ]`, and references step numbers from skill `rap-lifecycle` rather than
  copying the nine-step procedure into the log.
- publication creates a new block. It is a boundary SAP itself versions.
- `TR state` values are `open`, `released` and `cancelled`.
- TR numbers come from observation (`SAPTransport(action="get")`, or the lock ARC-1 reuses) plus
  approval. If none can be confirmed, mark human-supplied rather than guessing.
- `released` or `cancelled` means delete every baseline for that TR, but **keep the block**.
- After roughly 100 blocks, move old ones to `## Archive` in the same file.

## Relationship to SAP version management

SAP keeps a version only when a transport is released. Before then the system holds only the
current code, so `.baseline/` is the sole rollback point. After release, SAP owns rollback through
`SAPRead(type="VERSIONS")`, `VERSION_SOURCE` and `action="diff"`.

That split stays. The local block is not a replacement for SAP versions: it carries intent,
evidence and TR identity, which a code diff cannot show. The anchor only tells us when the two
have diverged.

## Known limits

- An unactivated draft changes no version. Detecting it needs `GetObjectDraft` /
  `SAPRead(type="DIFF")`, which is an extra call and not part of the default two-call anchor.
- A leaf object edited without touching package structure or root entity may not move the anchor.
  A human handoff still catches it.
- One package shared by several programs can mix fingerprints. Keep the package-to-program map
  explicit in `program.yaml`.
- The design does not detect edits in real time. It detects them at the start of a task.

## Part 2 — events instead of state, and the human/AI handoff

Status: still a design. Part 1 describes the four-layer anchor. This part replaces the idea of a
`TR state` field with recorded events, and states plainly what a local log can and cannot do.

### Why drop `TR state`

A state field has to be kept current. `open` left behind after release makes the baseline look
permanent; gate 10b (`verify-all.ps1:2469-2470`) skips every row whose state is not `open`, so a
wrong state is invisible. Removing the field removes the thing that goes stale:

```markdown
## v12 · 2026-11-18 · TR 123456

- [x] activated 2026-11-18
- [x] released 2026-11-18 · verified via SAPTransport(get) → R
- [ ] baseline deleted
- What: ...
- Why: ...
```

An event either happened or it did not. It is never "in need of an update". `released` is written
once with the date and the observation that proved it. `cancelled` is a separate event with the
same treatment. The baseline-deletion event replaces the old instruction to edit a state field and
then remember to delete files.

### Events need a verification marker

A human-written event can be wrong or forgotten. Record who asserted it:

```markdown
- [x] released 2026-11-18 · source: SAPTransport(get) · by AI
- [x] released 2026-11-18 · source: user said so · by human
- [ ] released — UNVERIFIED
```

`UNVERIFIED` is not a failure to hide; it is the signal to ask at handoff. Without it the AI would
have to treat every entry as fact, which is exactly the failure this design avoids.

### The limit that cannot be designed away

No SAP event, webhook or log tells an external agent that a person edited an object directly. If a
person edits a draft, activates it into an open TR, and never mentions it, `VERSIONS` shows nothing
new and the package anchor may not move. Dropping `TR state` does not change that.

The honest design consequence:

- The log is a **human intent record**, not a mirror of SAP.
- A start-of-task **handshake** is mandatory: "Did anyone change <object/package> in SAP directly
  since <verified_at>?" Yes / no / unsure.
- "Unsure" triggers the two-to-four-call anchor; drift creates a `unit: HANDOFF` block and asks one
  question. It never guesses intent from a code diff.
- If a human answers "no" while forgetting an edit, the AI still cannot know. That is a
  communication boundary, not a code defect. Reading the live source before writing remains the
  final safeguard.

### Seamless human/AI work on one object

The practical handoff protocol, for classic and RAP alike:

1. **Read live source first.** A log entry is a claim; the object in SAP is the current truth. Use
   `SAPRead` / `GetObjectDraft` for the active and inactive versions before planning.
2. **State whose change it is.** An AI change ends with a block carrying evidence and a TR number
   from observation. A human change ends with a short note in the same file: what, why, date, and
   whether the TR is known.
3. **One writer at a time.** ADT serialises concurrent writes with a lock; sequential
   read-modify-write from two parties loses updates. The existing rule "one object, one writer,
   one session" applies to human and AI alike, not just to two MCP servers.
4. **No silent repair.** If the AI finds a conflict, it stops and asks. It does not overwrite a
   human's unactivated draft to make the plan fit.
5. **Publish as a boundary.** In RAP, publication is a visible event in SAP. A change after publish
   starts a new block, not an edit to the published one.

### What this buys and what it does not

| Goal | Result |
|---|---|
| No stale state field to maintain | Yes — events replace state |
| AI avoids acting on a stale log | Yes — handshake and live read |
| AI knows an unmentioned direct SAP edit immediately | No — no such signal exists |
| Human and AI can alternate on one object | Yes, if both write a short note and respect one writer |
| Local log equals SAP | Not the goal; intent and code diff are different records |

### Decisions now settled

- `TR state` is removed from the new block format; `released` and `cancelled` are events.
- TR numbers are stamped from observation plus approval, or labelled human-supplied.
- `unit:` is AI-suggested by default and user-overridable.
- `Steps:` uses `[x]` / `[ ]`; publication opens a new block.
- Old blocks stay until the program or project is unregistered; `## Archive` in the same file.
- Baseline files are deleted on a verified release or cancellation; the block remains.

### Decisions still open

- Which fingerprint is authoritative for metadata extensions: source hash or generated `$metadata`?
  Source hash is cheaper; `$metadata` is closer to what the UI actually sees.
- Whether `verified_at` older than seven days forces a re-check, or every task re-checks regardless.
- Whether the new event format needs a schema marker, and how to grandfather logs still using the
  old `TR state` table without forcing a migration on an untouched program.

## Part 3 — refinements from a second review

These were suggested by another model and checked against this kit before being accepted. Ideas
already present under another name are not repeated here: per-write pre-images are already
`.baseline/<OBJ>_<TR>_v<n>.abap`, an explicit write-set is already `Approved: Write` in
`templates/plan.md`, one writer is already in the agent file, and attribution is already "name the
engine and tool behind every fact".

### 1. Recognition instead of recall

The original handshake asked "did anyone change this object?" — a question people answer wrongly
because they forget. Replace it with a display: list the one to five objects whose fingerprint
moved and ask "are these yours?". Seeing a concrete list produces a reliable yes/no; recalling an
action does not. Same gate, fewer wrong answers.

### 2. Anchor and CAS are different jobs

The anchor is a UX device: it notices that SAP moved so the AI can ask. It does not protect a write.
Safety at write time comes from the write contract itself: read the current source, hold a lock,
write against the version just read, release the lock in `finally`. A red light and a seat belt are
not interchangeable; an anchor that says "clean" is not permission to overwrite.

### 3. Activated is not observed

The kit already says saved ≠ activated ≠ tested. `sap-data-verify` also records that a
non-production-in-place instance may serve a draft for about 120 seconds after activation, so
`force_refresh=true` is needed. Promote that into an invariant: after activation, verify with a
different engine or force a refresh before claiming the new code was seen. A write report that
stops at "activated" is incomplete.

### 4. Undo is a forward write, not a silent restore

The earlier rule said the AI may propose a rollback diff but must not write without fresh approval.
Add the missing part: undoing a change is another write under the same read-lock-write contract,
with its own pre-image and intent. If someone else changed the object after the row being undone,
reconcile first — never restore over an unrecognised change. A rollback is a new event, not an edit
to history.

### 5. Events do not expire; states do

`released`, `cancelled` and `published` are written once and stay. `draft present`, `publish state`,
`package count` and `verified_at` can change and need a check cost. Every state fact carries
`source` (which tool), `by` (AI or human, and which harness), and `verified_at` or `UNVERIFIED`.
This is why a state is never copied into a block as a bare claim.

### Ideas intentionally not adopted yet

- A cross-harness write ledger keyed by system, client and object. It would need a shared file
  written in real time; the private mirror is committed later and cannot serve as a lock, and the
  kit repository is public. Recorded as an open problem, not implemented.
- System-mode rules for BTP versus on-premise. The current machine has GSD and DS4 destinations
  from SAP GUI local, none configured for BTP. The design must state the mode before using a
  rule such as "$TMP is allowed", but no mode-specific rule is adopted without a system to test it.

### Verified against installed source, 2026-11-19

Checked `arc-1@1.10.1` at the global npm root and `sap-ai-dev-toolkit` beside it. These are local
source facts, not claims from the second review.

- `expectedSourceHash` exists (`dist/handlers/tools.js:521`, `dist/handlers/schemas.js:677,789`,
  `dist/adt/source-precondition.js:9`). It is **optional**, not mandatory: the tool description
  says "Omitted/blank: no cross-call protection". `sourcePreconditionError` in
  `dist/handlers/editable-source.js:14` accepts it only for text-source `update` and class or
  procedural surgery; metadata, creation, deletion and server-driven objects cannot be guarded.
  `assertSourceHash` runs while the SAP lock is held (`source-precondition.js`), so this is a real
  compare-and-swap when supplied. Consequence: the rule is "pass `expectedSourceHash` on every
  supported write", not "the tool enforces it for us".
- `safeUpdateClassInclude` exists in `dist/adt/crud.js` and `dist/handlers/write/class-surgery.js`.
  The update path initialises a missing class include under the same lock before the PUT
  (`dist/handlers/write/update-delete.js:42-46`). The second review's warning about a 404 on a
  missing include is handled by the installed version.
- `force_refresh` is a declared `SAPRead` argument (`dist/handlers/tools.js:397`): "bypass cached
  source and inactive-list state before reading. Use when you know the object changed outside
  ARC-1." `INACTIVE_OBJECTS` is a declared `SAPRead` type (`tools.js:52`). The 120-second
  activation window and 60-second inactive-list TTL are in `dist/cache/caching-layer.js:27`.
  Both tool-level recommendations are therefore real, but only for ARC-1.
- No equivalent precondition was found in the installed `sap-ai-dev-toolkit` source outside its
  own documentation (zero source hits for `expectedSourceHash`, `sourceHash`, `If-Match` or
  `ifMatch`). This is absence of evidence in the installed source, not proof the server cannot do
  it. Until confirmed from live tools or source, ARC-1 remains the writer for objects needing CAS.

These facts close the three "unverified" items from the second review. They do not by themselves
change the template or the gate.
