# RAP persistence and draft

## Explicit persistence mapping

For managed RAP with table persistence, the behavior definition mapping must name **every** entity
field expected to persist. Implicit mapping for business fields is not acceptable: a create may
succeed while determined business values never reach the active table.

Compare entity fields, table columns, and the mapping one-to-one before activation and before any
runtime UAT claim.

```yaml
persistence_mapping:
  entity: ZI_EXAMPLE
  table: ZEXAMPLE
  fields: []                       # each entry names entity field, table field, and source
  unmapped_entity_fields: []
  unmapped_table_fields: []
  audit_fields_verified: false
  draft_table: null
  draft_field_names_match_entity: null
```

Gate: `unmapped_entity_fields` and `unmapped_table_fields` are empty, `audit_fields_verified` is
true, and every business field has a named source (determination, action, or client input).
Validate with `scripts/validate_rap_persistence_mapping.py <file.json>`; the script is strict about
list contents, not just key presence. A `mapping for … corresponding { … }` block in a tutorial
is syntax illustration, never a mapping template: copy only the syntax, then list every persisted
field explicitly. A persistent table may also be a CDS table entity — map it the same way.

Admin/audit fields must be distinct elements: `LocalLastChangedAt` is the ETag
(`etag master`), `LastChangedAt` is the total ETag for draft (`total etag`); the standard `%admin`
include (`sych_bdl_draft_admin_inc`) supplies draft admin fields. Do not alias one source field to
two semantic roles.

## Draft is a scope decision

Adding draft requires an independent Decision approval and a revised artifact plan. Check all of:

1. draft table and its name;
2. admin/draft fields (`%admin`, draft UUID, draft entity state);
3. draft field names match entity field names exactly;
4. `with draft` in the base behavior definition;
5. draft exposure in the projection behavior definition;
6. total ETag / etag master;
7. managed numbering;
8. reserved action handling;
9. `draft determine action Prepare`;
10. active versus draft state in the runtime client.

Never add draft, side effects, unmanaged save, events, workflow, or cross-BO composition without
an approved Decision item. A single Decision covers one expansion; do not batch unrelated ones.

## Activation and runtime discipline

- Treat compiler/activation errors as the specification. Correct one proven issue at a time and
  record the hypothesis; do not batch speculative syntax changes.
- Understand the save sequence: early-save failures (`sy-subrc = 4`) return to the interaction
  phase, while late save is the point of no return. After an uncertain late-save result, reconcile
  the persisted state read-only; never replay the create.
- Read back source and activation state after each material step; reconcile partial persistence
  instead of replaying create.
- Test create/update/delete/actions and feature control, then read persisted active-table rows in
  the **runtime client**. Draft rows living in the draft table are not active data.
- An active but unpublished binding is `READY_FOR_MANUAL_TEST`. No OData/Fiori runtime success may
  be claimed before publication and observed runtime evidence.
