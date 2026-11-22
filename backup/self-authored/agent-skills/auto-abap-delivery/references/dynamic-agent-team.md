# Dynamic agent team — T0 to T2

Status: **policy, not an automatic dispatcher.** The Delivery Lead remains the only SAP-write
coordinator. This reference defines when bounded read-only specialists may be used and when the
work must stay in one agent. No agent is spawned automatically by this skill.

## Topologies

| Topology | Shape | Status |
|---|---|---|
| T0 | one agent, sequential role passes | default |
| T1 | lead plus read-only sub-agents | allowed inside approved scope |
| T2 | one SAP writer plus zero to three read-only specialists plus one read-only auditor | allowed after gates below |
| T3 | multiple non-overlapping writers | **not supported** — requires lease, fencing, restart recovery and per-object evidence qualification |

## Baseline rules

- Single agent is the baseline. A sub-agent is an optimization, never the default.
- Parallelism is earned by separability; specialization by capability difference.
- Every handoff must reduce uncertainty. If it increases coordination or stale-output risk, keep the work local.
- One production object has exactly one writer lease. Analyst, architect, auditor and recovery roles are read-only.
- Existing read-only specialists stay read-only. A test agent may write only an approved class test include; it never writes production objects. Do not add a new write-capable coordinator agent to the roster.

## Agent registry for this kit

| role | agent file | mode |
|---|---|---|
| delivery_lead | `abap-auto-delivery-by-pongg` | coordinator / bounded write |
| repository_analyst | `sap-abap-reverse-engineer-by-pongg` | read-only |
| test_verification | `sap-se38-report-tester-by-pongg` | read-only, controlled execution |
| dump_analysis | `sap-st22-dump-analysis-by-pongg` | read-only |

An unknown role has no agent. Use a local role pass, or `BLOCKED_TOOLING` when independence is mandatory. Never guess an agent from a name.

## Recruitment Value Gate

Value = context isolation + specialization + parallel speedup + permission isolation
- context replication - coordination cost - result merge cost - stale-output risk - debugging cost.

| Score | Decision |
|---:|---|
| >= 6 | recruit |
| 2-5 | recruit only with one bounded workstream |
| -1 to 1 | local role pass |
| < -1 | main agent |

## Dependency Gate

Parallel allowed: released API discovery, authorization review, performance review, test scenario design, documentation/evidence audit.

Parallel only with frozen inputs: cardinality review plus test design, consumer impact plus repository discovery, completed-slice audit plus next-slice planning.

Keep sequential: two agents modifying one class, implementation and tests changing a method contract, CDS source changing during cardinality review, repair loops depending on activation results, uncertain recovery and source drift.

## Bounded packet

`maximum_files: 12`, `maximum_source_objects: 8`, `maximum_estimated_tokens: 30000`,
`include_full_conversation: false`. Required outputs: verdict, findings, evidence IDs, assumptions,
limitations, recommended actions. Raw output location: `artifacts/subagents/<delegation-id>/`.

Sub-agent output is accepted only against the current spec/source snapshot. Stale output is rejected
or reissued. A completed run does not qualify its team plan; record team effectiveness separately.

## Do-not-recruit codes

`TASK_TOO_SMALL`, `TIGHT_DEPENDENCY`, `NO_SEPARABLE_WORKSTREAM`, `DUPLICATE_CAPABILITY`,
`CONTEXT_REPLICATION_TOO_HIGH`, `COORDINATION_COST_TOO_HIGH`, `INSUFFICIENT_TOOLING`,
`PERMISSION_CONFLICT`, `BUDGET_LIMIT`, `ROLE_COMPLETED`.
