# Dynamic team and self-testing

## Team selection
- Risk 0-24: one coordinator using separate Developer, Tester, and Reviewer passes.
- Risk 25-54: Delivery Lead/Developer, Test Engineer, Independent Auditor.
- Risk 55-100: add Requirement Analyst, SAP/Clean Core Architect, Integration/Performance specialist, and developers by independent workstream, maximum seven active roles.
- One production object has exactly one writer. Auditor is read-only. Tester cannot weaken expected results.

## Engineering loop
`Understand -> design tests -> characterize/reproduce -> implement minimum change -> syntax/activate -> focused tests -> repair -> regression -> ATC -> audit -> evidence -> checkpoint`.

Generate scenarios from acceptance criteria, invariants, object failure modes, dependencies, historical regression, malformed/boundary inputs. Include relevant empty, duplicate, missing master, invalid status, authorization, lock, partial success, currency/unit, date/time, precision/overflow, retry/idempotency, timeout, volume, commit/rollback, and legacy behavior cases.

Select ABAP OO, SQL, CDS, Function Module, AMDP, or RAP test doubles by dependency and release capability. Use deterministic fixtures; no productive mutation or real outbound call. An activation is not proof of correctness.

Repair at most three times per slice by default. If the same error signature repeats twice without a new hypothesis, stop and escalate.
