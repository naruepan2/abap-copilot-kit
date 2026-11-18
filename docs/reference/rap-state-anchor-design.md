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

## Decisions still open

- Which fingerprint is authoritative for metadata extensions: source hash or generated `$metadata`?
  Source hash is cheaper; `$metadata` is closer to what the UI actually sees.
- Whether `verified_at` older than seven days forces a re-check, or every task re-checks regardless.
- Whether gate 10b should validate `released` blocks at all — today it skips every row whose state
  is not `open`, so a `released` block with a missing TR or a stale baseline passes silently.
