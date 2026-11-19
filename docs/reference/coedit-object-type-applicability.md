# Co-edit object-type applicability — simulation and evidence map

Status: **design map, not a specification.** It classifies SAP repository object types by how the
co-edit protocol may touch them. "UNVERIFIED" means no source with a comment was observed in this
harness — it is not a claim that the form is impossible. No SAP write is authorised by this file.
Evidence behind the EVIDENCED rows is in `coedit-comment-block-syntax.md`.

## 1. Applicability matrix

| group | types | source text | comment form | status | allowed co-edit action |
|---|---|---|---|---|---|
| ABAP source | `CLAS` | yes | `*` column 1; `"` inline | **EVIDENCED** | apply source / disabled blocks |
| ABAP source | `PROG`, `INTF`, `FUGR` | yes | `*` expected | **UNVERIFIED** | STOP until one object of the type is read |
| ABAP source | `FUNC` | yes | `*` / `"` expected | **UNVERIFIED** | STOP — two reads returned ADT 500 `[SY/530]` |
| CDS | `DDLS` | yes | `//` | **EVIDENCED** | apply source / disabled blocks |
| CDS | `DCLS` | yes | `//` expected | **UNVERIFIED** | STOP until probed |
| RAP | `BDEF` | yes | `//` | **EVIDENCED** | apply source / disabled blocks; do not edit generated pool includes |
| RAP | `SRVD` | yes | `//` expected | **UNVERIFIED** | read succeeded but observed object had no comments — STOP for comment-block mode |
| RAP | `SRVB` | binding metadata | n/a | **UNKNOWN** | activation/publication approval only |
| Generated | `STOB/DO` | mirrors root DDLS | n/a | **DO NOT EDIT** | redirect the proposal to the root DDLS |
| DDIC | `TABL`, `VIEW`, `STRU`, `DTEL`, `DOMA`, `TTYP`, `SHLP`, `ENQU`, `TYPE` | metadata | n/a | — | save-only / explicit human gate |
| Application | `MSAG`, `AUTH`, `TOBJ`, `TRAN` | metadata | n/a | — | save-only |
| Transform | `XSLT` | text/XML | `<!-- -->` expected | **UNVERIFIED** | STOP |
| Gateway | `IWMO`, `IWSV`, `IWPR` | model / generated | n/a | — | save-only |
| Enhancement | `ENHO`, `ENHS`, `SXCI` | generated impl | varies | **DO NOT EDIT generated** | save-only |
| Web | `UI5B`, `WDYN`, `WAPA` | separate repository | n/a | — | outside this protocol |

Rule for every UNVERIFIED row: `STOP` and ask for a read-only probe. Do not infer a comment form
from a neighbouring type, and do not put a COEDIT block into a generated object.

## 2. Tier interpretation

From the reverse-engineering / knowledge-graph priority list supplied by the user:

| tier | types | role in co-edit |
|---|---|---|
| Tier-1 | `CLAS`, `PROG`, `FUGR`, `TRAN`, `DDLS`, `TABL`, `BDEF`, `SRVD`, `SRVB`, `DCLS` | index nodes and anchor candidates. Comment-block targets only where the matrix says EVIDENCED |
| Tier-2 | `DTEL`, `DOMA`, `STRU`, `TTYP`, `MSAG`, `SHLP`, `ENQU`, `AUTH` | metadata/dependency nodes; never block targets |
| typical RAP set | `DDLS ZI_*`, `DDLS ZC_*`, `DCLS`, `BDEF ZI_*`, `CLAS ZBP_*`, `SRVD`, `SRVB` | one activation group; read the service definition source for exposure edges |

An object being Tier-1 for navigation does not make it writable by a comment block. Navigation
evidence and mutation permission are different properties.

## 3. Typical RAP change — simulated walk

Change: add `ApprovalStatus` to a projection and a save validation to the behavior.

| object | role | op | form | result |
|---|---|---|---|---|
| `ZI_*` DDLS | root interface | none — anchor | `//` EVIDENCED | observe hash only |
| `ZC_*` DDLS | projection | `INSERT_AFTER` field | `//` EVIDENCED | eligible |
| `DCLS ZC_*` | access control | modify DCL | `//` UNVERIFIED | **STOP** until probed |
| `BDEF ZI_*` | behavior contract | `REPLACE_UNIT` validation | `//` EVIDENCED | eligible |
| `CLAS ZBP_*` | behavior pool | `REPLACE_UNIT` method | `*` EVIDENCED | eligible if not a generated skeleton |
| `SRVD ZUI_*` | service contract | expose new entity | `//` UNVERIFIED | **STOP** |
| `SRVB ZUI_*_ODATA` | binding | publish | n/a | separate approval |
| `STOB/DO` | custom entity stub | none | generated | redirect to root DDLS |

Activation group: all interdependent DDLS / DCLS / BDEF / pool / SRVD / SRVB in one call. The
batch is all-or-nothing: one object outside the package allowlist aborts the group
(`activate.js:238-240`). Publication is a later, separate approval.

## 4. Simulated trace

```text
1. confirm system/client + TR                 -> pass (human-stated)
2. fresh read every object + hash             -> pass
3. build scope_digest + manifest              -> pass
4. Axis A = INSERT_DISABLED_BLOCKS            -> Axis B locked to DEFER
5. check comment form per object type         -> STOP at DCLS and SRVD
6. if human probes DCLS/SRVD                  -> resume at step 5
7. write blocks with fresh precondition       -> only evidenced types
8. read-back + store hash/pre-image           -> pass
9. human applies in SAP                       -> 9-priority state classification
10. activation group                          -> separate approval, all-or-nothing
11. publication                               -> separate approval
```

Other stop conditions covered by the protocol: stale hash, anchor occurrence ≠ 1, marker
collision, lock/session expiry mid-write, and unknown comment syntax. All are `STOP + ask`, never
auto-repair.

## 5. What this does and does not prove

- It shows the design covers the object-type taxonomy and stops where evidence is missing.
- It does **not** prove `DCLS`, `SRVD`, `FUNC`, `PROG`, `INTF` or `FUGR` accept the proposed comment
  form — those rows stay UNVERIFIED until read-only probes succeed.
- It is not the §5.11 benchmark: that still needs a human-confirmed gold set and a read-only run.

TADIR queries were not executed. Data gates remain closed and are not needed for this map.
