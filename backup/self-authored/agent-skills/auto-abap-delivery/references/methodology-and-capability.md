# Methodology and capability resolution

## Route before intake

Choose the route first: `consultation`, `lightweight`, `standard`, `controlled`, or
`full long-run`. The route sets which gates are mandatory; it does not relax SAP, evidence, or
production-boundary rules. Keep routes distinct from interaction levels (`standard`, `guided`,
`controlled`, `strict`, `custom`) and from team topologies (T0–T2).

## Methodology profiles

| Profile | Meaning |
|---|---|
| A | Classic Standard ABAP — class-first, Clean Core debt disclosed |
| B | Cloud-ready Classic — released APIs and migration seams preferred |
| C | RAP / ABAP Cloud — ABAP for Cloud Development and C1 or verified same-component dependencies |
| D | Approved Classic bridge — only when no released successor exists |

### Pre-write gate

No create command until the following are verified or explicitly approved:

- product and edition; release and software component;
- package and its lifecycle/transport behaviour;
- effective language version (Standard ABAP vs ABAP for Cloud Development);
- permitted object types for that package and language version;
- dependency classification with `unknown_dependencies: 0`;
- Clean Core verdict for each dependency;
- approved Object Responsibility Plan, activation order, and verification plan.

Unknown is not allowed. A C2 remote release is not automatically a system-internal ABAP API.
A `Z*` name is not evidence. Changing package/language version or introducing a bridge needs an
owner decision, recorded as a Decision item, never a silent relabel.

Profile C requires ABAP for Cloud Development; if the target package cannot support it, stop for
an approved Profile D decision instead of claiming Profile C. Verify target-client runtime for
function modules — development-client activation does not prove execution in the runtime client.

Methodology profiles are **not** the same as Clean Core levels A–D. Profile C is a language and
object-type choice; a Level C dependency inside a Profile C extension still demotes that extension
to Clean Core Level C. See [sap-guardrails.md](sap-guardrails.md) for the level matrix and for the
read-only release-state channels. A RAP application that calls a classic API is only acceptable
when that API is marked `transactional-consistent` in the live Cloudification Repository; other
classic APIs can break the RAP transactional model.

## Capability ladder (Standard first)

1. SAP standard / built-in configuration.
2. Released SAP API, CDS view, BAdI, or extension point.
3. Supported SAP framework or tool.
4. Approved customer component.
5. Reviewable customer component.
6. New custom component.
7. External open-source installation — reference only by default.

Inspect a customer candidate before reuse: package, component, language version, API semantics,
dependencies, side effects, authorization, client handling, ATC/CVA, tests/runtime use, consumers,
owner, lifecycle, deprecation, and profile A–D suitability.

Allowed outcomes: `REUSE_DIRECTLY`, `REUSE_BEHIND_ADAPTER`, `REFERENCE_PATTERN_ONLY`,
`WRAP_AND_RELEASE_C1`, `REJECT`, `BUILD_NEW`, `BLOCKED_PENDING_EVIDENCE`.

External repositories default to `REFERENCE_ONLY`. Installation needs a separate approved
governance decision covering licence, security, compatibility, namespace, Clean Core, object
inventory, operational owner, and removal/upgrade review.

## Evidence

Record the resolution in the run folder and validate it with
`scripts/validate_methodology_resolution.py <file.json>` before the first SAP write.
