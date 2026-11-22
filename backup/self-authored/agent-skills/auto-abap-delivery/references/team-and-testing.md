# Dynamic team and self-testing

## Team selection
- Risk 0-24: one coordinator using separate Developer, Tester, and Reviewer passes.
- Risk 25-54: Delivery Lead/Developer, Test Engineer, Independent Auditor.
- Risk 55-100: add Requirement Analyst, SAP/Clean Core Architect, Integration/Performance specialist, and developers by independent workstream, maximum seven active roles.
- One production object has exactly one writer. Auditor is read-only. Tester cannot weaken expected results.
- A test agent may write only an approved class test include. It never writes production objects or other includes.

## Engineering loop
`Understand -> design tests -> characterize/reproduce -> implement minimum change -> syntax/activate -> focused tests -> repair -> regression -> ATC -> audit -> evidence -> checkpoint`.

Generate scenarios from acceptance criteria, invariants, object failure modes, dependencies, historical regression, malformed/boundary inputs. Include relevant empty, duplicate, missing master, invalid status, authorization, lock, partial success, currency/unit, date/time, precision/overflow, retry/idempotency, timeout, volume, commit/rollback, and legacy behavior cases.

Select ABAP OO, SQL, CDS, Function Module, AMDP, or RAP test doubles by dependency and release capability. Use deterministic fixtures; no productive mutation or real outbound call. An activation is not proof of correctness.

Repair at most three times per slice by default. If the same error signature repeats twice without a new hypothesis, stop and escalate.

## Test artifact policy

`DIAGNOSTIC_DRIVER` is a distinct result type. A temporary program used because AUnit did not
execute a class test include is a diagnostic driver, never `ABAP_UNIT`. It requires owner
approval, a local/non-transportable package and cleanup; its result does not replace class unit
evidence. A permanent test-driver report is prohibited.

Select test doubles by dependency type and release capability: `CL_ABAP_TESTDOUBLE` for OO
dependencies, `CL_OSQL_TEST_ENVIRONMENT` and `CL_CDS_TEST_ENVIRONMENT` for data sources, and the
RAP BO test environments for handler/consumer-level tests. Prefer constructor injection; a test
seam is a temporary, recorded workaround for legacy code. Do not build a test framework, do not
mock what is not needed, and use no productive mutation or real outbound call in tests.

ABAP Unit is optional and value-based. `CLAS` with material business logic is the preferred owner,
placed in the class test include. A `PROG` may own report-specific behaviour through local
classes (L1/L2); verify it through selection/foreground/background checks. Do not add inline
`FOR TESTING` classes to a PROG by default. Never label a test `NOT_APPLICABLE` solely because the
object type is PROG or FUNC; record the real reason and compensating evidence.

AUnit `no tests` is `NOT_RUN_BY_AUNIT_TOOL`, not PASS and not a reason to create a permanent
driver. ATC `processed=0` is `NOT_REPORTED`, never a solution-wide PASS. Where a report calls a
function module, prove the FM return value is the value actually displayed.
