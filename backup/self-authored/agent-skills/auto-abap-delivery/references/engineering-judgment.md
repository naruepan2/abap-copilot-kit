# Engineering judgment controls

## Reuse-first discovery
Before a global object is created, search SAP standard/configuration, released APIs/extension points, approved project components, similar objects, and architecture decisions. Produce a reuse assessment and choose reuse, extend, retire, or build. Existing code is not proof of quality.

## Simplicity gate
Justify each new global object/public interface/wrapper/layer. Prefer the smallest maintainable solution. Flag speculative reuse, pass-through wrappers, duplicated patterns, unjustified classes, and excess public surface.

## Test adequacy
Independent auditor challenges scenario coverage, negative/exception/authorization/alternative/boundary/concurrency/regression cases, test-double fidelity, assertion strength, and manual-UAT gaps. Passing tests alone do not pass this gate.

## Consumer impact
For CDS/RAP/OData/RFC/BAPI/IDoc/DDIC/public interfaces/forms/events, enumerate consumers, contract deltas, semantic compatibility, regression tests, versioning and rollout.

## Project engineering memory
Load reviewed style, naming, approved patterns/components, testing, Clean Core, released API and forbidden-pattern files. AI creates lesson candidates only; human review promotes them.

## Reviewer competency
Route checkpoints to qualified roles. Architecture/Clean Core needs senior ABAP or architect; authorization needs Security plus owner; scenarios need functional owner/test engineer; source diff needs ABAP reviewer; contracts need integration owner.

## Object Responsibility Plan (V9, additive)

Before SAP write, record an approved Object Responsibility Plan: object, type, role
(`thin_shell`, `application_logic`, `data_access`, `framework_mandated`), business logic allowed or
not, and verification per object. Any added/removed object requires Object Set Delta Review with
reason and approval. Replace rigid object-count limits with this delta review.

### Activation scope (Phase 3)

The ORP and class-first rules are now **policy for new development**, not an automatic source
rejector. No parser exists in this skill to prove ABAP style, so the Delivery Lead must record the
decision in the ORP and in evidence. A human or syntax/lint tool still validates the source.

- New business logic belongs in a class. A new `PROG` is a thin selection/event/presentation shell.
  A new `FUNC`/`FUGR` is a thin compatibility boundary that delegates to a class.
- Do not create new `FORM`/`PERFORM` in new development. Keep existing Form routines unchanged only
  when the approved scope does not justify refactoring or when refactor risk exceeds change risk.
- This rule resolves the V9 §2 vs §23 tension: "no new FORM/PERFORM" applies to new development;
  legacy subroutines may remain under the recorded exception.
- An ORP is mandatory when a run creates a new global object, touches RAP/CDS objects, or plans at
  least three objects. A single-object local report may record `orp_not_required` with a reason.
- Use `scripts/validate_object_responsibility_plan.py <orp.yaml>` before treating an ORP as
  approved. The validator checks structure and duplicate object/writer names only; it does not
  judge ABAP design quality.
