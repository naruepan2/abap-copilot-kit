# Technical Event Propagation

Model technical signals end to end, not as isolated flags.

Required ledger columns: event, producer, receiver, propagation path, scope key, lifetime, persistence, replay behavior, reset rule, failure mode, evidence, and test.

Validate:
- producer sets the event only after its prerequisite succeeds;
- receiver checks the same scope and does not treat stale state as current;
- retry/restart behavior is deterministic;
- parallel processing cannot race into duplicate creation;
- every path has an explicit positive, negative, repeat, restart, and concurrency test.

A global/static variable is acceptable only for same-internal-session behavior and must not be documented as cross-job or cross-LUW protection.
