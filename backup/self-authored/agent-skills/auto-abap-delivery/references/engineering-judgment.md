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
