---
name: auto-abap-delivery
description: explicit opt-in orchestration for bounded sap abap delivery from intake and approved specification through implementation, self-testing, atc, recovery, trust-calibrated attended or unattended interaction, evidence, and uat handoff. use only when the user explicitly invokes auto-abap-delivery, asks to start/resume an autonomous abap run, or supplies an existing run id. do not trigger for ordinary abap questions, code examples, reviews, explanations, or troubleshooting unless the user explicitly activates this mode.
---
# Auto ABAP Delivery

Operate as the control plane for a bounded SAP ABAP delivery run. Treat the user as Project Owner. Stop at `READY_FOR_UAT`; never infer approval for transport release/import, production write, productive job scheduling, mass correction, authorization change, or real external side effects.

## Invocation and interaction defaults

Proceed only after explicit invocation, for example `/auto-abap-delivery start`, `start-unattended`, `start-attended --level guided`, or `resume RUN-...`.

After Spec, plan, and Autonomy Envelope approval, resolve interaction policy using [interaction-control.md](references/interaction-control.md):

- Initial default for unqualified scope: `execution_mode: attended`, `review_level: standard`.
- Qualified scope may default to `unattended`; critical scope requires at least `controlled`.
- Attended levels: `standard`, `guided`, `controlled`, `strict`, or `custom`.
- Unattended is preselected only for qualified scope. Unqualified scope preselects Attended Standard. SAP write always requires explicit `APPROVE AND START`.
- Use one delivery engine for both modes. Do not create a separate attended workflow.
- Keep Review Queue separate from Decision Inbox.

## Workflow

1. **Discover safely**: inspect the live MCP/tool surface and SAP target read-only. Never trust a remembered tool list. Load [capability-and-intake.md](references/capability-and-intake.md).
2. **Draft the assignment**: gather outcome, landscape, object/package/TR, scope, acceptance criteria, test permissions, and production boundary. Ask only what tools and SAP metadata cannot establish.
3. **Resolve architecture and guardrails**: determine ECC, S/4HANA, ABAP Cloud, Clean Core, released API, authorization, client, LUW, lock, performance, transport, and observability controls. Load [sap-guardrails.md](references/sap-guardrails.md).
4. **Assess trust and qualification**: load [trust-and-qualification.md](references/trust-and-qualification.md), classify unqualified/qualified/critical scope, and resolve the effective mode.
5. **Seek approval**: freeze Spec, implementation plan, test plan, execution contract, autonomy envelope, and resolved interaction policy. Do not write SAP source before approval.
6. **Initialize the run**: execute `scripts/init_run.py` with approved identifiers and interaction fields; validate with `scripts/validate_run.py`.
7. **Plan the team**: choose one-agent role passes, three roles, or five-to-seven specialist roles based on risk. Enforce one writer per production object. Load [team-and-testing.md](references/team-and-testing.md).
8. **Apply engineering judgment**: before create/complete decisions, load [engineering-judgment.md](references/engineering-judgment.md) and require reuse, simplicity, test-adequacy, consumer-impact, project-memory, and reviewer-competency controls as applicable.
9. **Execute by slice**: fresh-read, check preconditions, add characterization/failing test when feasible, implement minimum change, syntax-check, activate, focused-test, repair, regress, ATC/CVA/readiness-check, audit, and checkpoint.
10. **Apply interaction policy**:
   - unattended: continue silently within approved boundaries;
   - attended: create revisioned Review Queue items at configured checkpoints and enter `REVIEW_PENDING`;
   - never represent scheduled review as a technical blocker.
11. **Handle owner input**: validate Review Queue approval against source/spec/evidence snapshot; create Decision Inbox items only for human authority or judgment. Load [decision-inbox.md](references/decision-inbox.md).
12. **Switch modes safely**: apply a mode/level change only at a reconciled safe checkpoint through `RECONFIGURING`. Never stop midway through write or activation.
13. **Recover**: after restart or uncertain tool result, acquire a new fencing token, reconcile against SAP, invalidate stale evidence/reviews, and resume only from a legal state. Load [state-machine-and-recovery.md](references/state-machine-and-recovery.md).
14. **Complete**: require fresh source-linked evidence, no outstanding `REWORK` or required review, guardrail report, UAT mapping, and unreleased transport. Build handoff using [evidence-and-uat.md](references/evidence-and-uat.md) and [accountability.md](references/accountability.md).

## Non-negotiable rules

- SAP reality is authority for source, activation, locks, transport, SID/client; durable artifacts are authority for approved scope and policy.
- Persist command intent before a side effect and reconcile observed result afterward.
- Never blindly replay source write, activation, test-data creation, RFC/IDoc/API send, posting, commit, or mass update.
- Never overwrite source drift. Pause affected work, stale evidence/reviews, and decide safely.
- Never weaken expected results to make tests pass.
- Never suppress ATC/CVA findings without ID, rationale, owner, and expiry where applicable.
- Mark unavailable validation `READY_FOR_MANUAL_TEST` or `INCONCLUSIVE`; never fabricate success.
- Attended review timeout never auto-continues. Transition to `PAUSED_SAFE` when the lease expires.
- Decision Inbox items cannot be batch-approved. Batch Review Queue approvals only when reversible, same slice/snapshot, and policy-eligible.
- Production and irreversible actions remain prohibited even in `strict` review.

## Legal final states

Use only `READY_FOR_UAT`, `READY_FOR_MANUAL_TEST`, `BLOCKED_OWNER_DECISION`, `BLOCKED_TOOLING`, `PAUSED_SAFE`, `FAILED_SAFE`, or `CANCELLED`. Do not use `DONE` before UAT and a separate production workflow.

## V8 mandatory completion gates

Require reuse assessment for new global objects, simplicity verdict, independent test-adequacy audit, consumer-impact report when applicable, reviewed project-engineering-profile revision, qualified reviewer routing, accountability matrix, and updated autonomy qualification record.
