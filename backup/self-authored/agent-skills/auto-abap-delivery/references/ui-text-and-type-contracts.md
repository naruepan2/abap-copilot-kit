# UI text and type contracts

Built-in ABAP and CDS types usually carry no DDIC labels. Blank column headers and unreadable
fields are a design defect, not a cosmetic afterthought.

## SALV reports

- Set short, medium, and long texts explicitly with `SET_SHORT_TEXT`, `SET_MEDIUM_TEXT`, and
  `SET_LONG_TEXT`. Respect the parameter lengths `C10`, `C20`, `C40`; probe the installed SAP
  version if a method name or signature is uncertain.
- Selection-screen labels belong in text elements. If source references `TEXT-001` symbols, the
  text pool must contain them; verify the text pool, not just the source.
- `screen-required = '2'` is recommended display only — it does not perform mandatory
  validation. Use `OBLIGATORY` where the field is genuinely required and keep explicit checks
  for exclude-only ranges and `SUBMIT` paths.
- Check foreground SALV and a background-safe list/log path; verify event-handler lifetime.

## RAP / Fiori

- Use `@EndUserText.label` on projection elements as the canonical semantic label source.
- Put semantic annotations in the view definition and UI annotations in metadata extensions; use
  `@Metadata.allowExtensions: true` before adding a DDLX and keep positions in consistent steps
  (10, 20, 30). A UI annotation like `@UI.lineItem` takes an array, not a bare object. Annotate
  amount fields with their currency-code reference.
- Facets need descriptive IDs and meaningful labels. Do not create a line-item-reference facet
  without a real child/composition target; a facet pointing at the root only renders a misleading
  empty area.
- Value-help providers on released source views are auto-exposed; do not invent custom providers
  without evidence. Expose projection views (`ZC_*`), not root views, and include the value-help
  entities the UI needs; service-definition aliases become OData entity-set names.

## Type and fix evidence

- Before casting or widening a field, identify the actual generated/OData type and the affected
  field. Do not cast every numeric expression because an OData error omitted the field name.
- Check status/string values against their declared lengths; silent truncation is a real failure.
- Classify each fix as `proven`, `empirical`, or `unresolved`. `proven` requires an observed root
  cause and a read-only probe or reproduction. Symptom-driven casts are `empirical`, never proven.
- Record the classification in the root-cause record and in evidence; a second repair for the same
  signature requires new evidence.

## Evidence

Capture a labelled-field list, the text-pool/symbol check, a sample displayed value versus the
source/FM return value, and the fix classification in the run evidence.
