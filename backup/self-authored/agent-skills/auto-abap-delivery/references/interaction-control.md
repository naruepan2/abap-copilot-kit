# V7 interaction control

## Model

```yaml
interaction_policy:
  execution_mode: unattended | attended
  review_level: not_applicable | standard | guided | controlled | strict | custom
```

Initial default for unqualified scope is Attended Standard. Qualified scope may default to Unattended; critical scope requires at least Controlled. Attended changes only pause points and never weakens guardrails, testing, evidence, recovery, or UAT boundary.

## Resolution priority

`mandatory organization/project policy > valid task selection > repository default > user default > system default (attended standard for unqualified scope)`.

Record selected, recommended, minimum, effective level, resolution source, policy version, and owner override. Agent recommendations require concrete SAP risk triggers and are not mandatory unless policy says so.

## Levels

- **Standard** (`milestone_review`): pause after plan baseline, implementation completion, final verification/UAT pack.
- **Guided** (`development_cycle_review`): pause after impact analysis, test design, each vertical slice, full regression, UAT pack.
- **Controlled** (`engineering_gate_review`): pause before first production-object write, material activation, integration test with SAP-side test data; pause after architecture/guardrails, test plan, ATC/CVA/audit.
- **Strict** (`state_change_controlled_review`): pause before source-write batch, activation batch, SAP test-data creation, integration side effect, design-changing repair, source-drift rebase, uncertain replay, or exemption proposal.
- **Custom** (`policy_based_review`): load organization/repository/task pause and continue rules.

Strict does not pause read/search/where-used. Production and irreversible actions remain prohibited, not reviewable.

## Review Queue

Scheduled checkpoints create `REV-*` items, not `DEC-*`. Bind approval to review revision, spec revision, target, source/dependency hashes, guardrail profile, and evidence IDs.

Actions: `approve_and_continue`, `request_changes`, `inspect_diff`, `take_over`, `switch_to_unattended`.

Lifecycle: `OPEN -> VIEWED -> ANSWERED -> VALIDATING -> APPLIED`; alternate: `SUPERSEDED`, `WITHDRAWN`, `REJECTED_STALE`.

A review becomes stale after relevant source, dependency, spec, target, profile, or evidence changes.

## States

Add `REVIEW_PENDING`, `REVIEWING`, and `RECONFIGURING` to the shared V6 state machine. Scheduled review wait time is not blocker time.

## Switching

- Unattended to attended: finish atomic operation, reconcile SAP, checkpoint, reconfigure, create current-state review.
- Attended to unattended: require approved current review, no blocking decision, valid lease/envelope, no mandatory review gate, explicit `READY_FOR_UAT` boundary.
- Increase intensity at next safe checkpoint. Decrease only if minimum policy allows; record override.

## Timeout and fatigue

Never auto-continue an unattended review timeout. Notify once, optional reminder after four business hours and then daily, stop renewing write lease, and enter `PAUSED_SAFE` on expiry.

Batch approval maximum default is five reversible Review Queue items from one slice and snapshot. Never batch decisions, exceptions, DDIC persistent/security/authorization/integration-contract/Clean Core exception/source-drift/external-side-effect items.
