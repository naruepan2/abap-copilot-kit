# Output Shape and Field Evidence

Use this reference only when an output contract is in the requested scope. Report **what the evidence establishes**, not what the user may see or what data values may occur.

## Evidence classes

- `DECLARED`: fields in a verified program row type/DDIC structure or CDS root entity. This establishes a declared shape, not that every field is rendered.
- `EXPOSED`: entity/fields exposed by a verified service definition or equivalent service metadata. Exposure does not prove UI visibility or runtime availability.
- `UI_CONFIGURED`: fields explicitly selected/configured by relevant UI annotations, metadata extensions, or ALV field-catalog/column settings.
- `RUNTIME_OBSERVED`: output/values directly captured from an authorized runtime or test. State the test/source and scope. Never synthesize example values.

Keep the class attached to each field/list/table. Do not promote evidence from one class to another without additional evidence.

## Program ALV/SALV discovery

1. Locate the actual display call and identify the internal table supplied to it. Do not treat a SELECT list or an unrelated internal table as the displayed output.
2. For classic ALV with an explicit field catalog, inspect catalog construction and subsequent changes (including hidden/no-output columns, labels, order, and formatting) to report `UI_CONFIGURED` fields.
3. For SALV, follow the actual table passed to `CL_SALV_TABLE=>FACTORY` (or the verified equivalent) and resolve its row type:
	- local structured/table type or inline declaration: inspect the source declaration and assignments;
	- DDIC structure/table type: inspect verified DDIC metadata;
	- `LIKE`/`TYPE` aliases: follow the declared referenced type;
	- generic, dynamic, or unresolved type: report the fields as partial/unresolved.
4. Inspect SALV column configuration after factory creation for explicit visibility/selection or presentation changes. If none is found, report type-derived fields as `DECLARED`; do not claim every field was rendered. If source flow or dynamic behavior prevents confirmation, say so.
5. A helper that derives a field catalog from SALV metadata may be used as evidence only when the program actually calls it or when its interface/source is independently verified for the relevant system. Do not execute the report or helper merely to manufacture a catalog during static analysis.

## CDS and service discovery

- For a CDS root, report the elements declared by that exact root entity as `DECLARED`. Do not substitute a lower layer or choose a presumed “top” layer based on naming conventions.
- If a service definition is in scope and verified, list its direct exposed entities and aliases as `EXPOSED`, then inspect the exact exposed CDS entities to enumerate their fields. Preserve the distinction between exposed entity and its lower dependencies.
- Only claim `UI_CONFIGURED`/visible fields when relevant UI annotations or metadata extensions explicitly support the claim. Projection or service exposure alone is insufficient.
- If there is no service or downstream consumer evidence, state that the root's declared fields are known but its consumer-visible result is not established. If a lower CDS entity is the requested root, do not infer an upper consumer that was not discovered.

## Report format and stop conditions

For each output group, record: full canonical object/type, evidence class, fields (or exact count plus attached full list where appropriate), relevant configuration, evidence pointer, and unresolved caveat. Mark inaccessible or dynamic pieces as `PARTIAL`/`UNRESOLVED`; do not fill them by guessing from field names, source tables, or conventional UI behavior. If no output contract is applicable to the root/scope, omit this section. If it was requested but cannot be resolved, state the evidence gap rather than implying there is no output.

Projection alone does not prove visibility. For accepted field catalogs, require every in-scope field to be classified or explicitly unresolved; never use an empty unclassified list to conceal missing evidence.
