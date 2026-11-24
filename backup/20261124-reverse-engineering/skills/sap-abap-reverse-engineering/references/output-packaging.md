# Output Packaging and Word Conversion

Controls the *presentation* of a Technical Specification. It never relaxes canonical names, evidence classes, completion status, or the no-fabrication rule.

## One content source, many renditions

The Markdown artifact is the single authored source of the analysis. Word, Word-ready, and any future HTML rendition are **derived** from it: change the Markdown, re-derive the rest. Do not hand-author a second version of the content in another format, because two authored copies drift and the drift is invisible in review. When a rendition cannot carry some content (for example Mermaid in Word), state the degradation explicitly in the deliverable; do not delete the content and do not invent a replacement.

## Writing files

Write deliverable content with a file-writing tool, not through a shell heredoc, `cat >`, `echo >`, or an inline script. Long and non-ASCII text (Thai, CJK, box-drawing, quotes) breaks shell quoting, and every failed retry re-emits the whole document. Create the file in one write, then read it back to verify the content survived intact.

## Output format choices

| Value | Meaning | When to propose |
|---|---|---|
| `MARKDOWN` (default) | The canonical Markdown artifact, full expressiveness (nested tables, rich Mermaid). | Default; best for review, diff, and version control. |
| `MARKDOWN_WORD_READY` | Same content, restricted syntax so a Markdown→DOCX converter produces clean output. | User wants Word but no verified converter is present. |
| `DOCX` | A genuine Office Open XML `.docx` file. | Only when a converter is verified available on this machine. |
| `HTML` | One self-contained HTML rendition with switchable TS/PRD panels and a shared evidence model. | Derived from Markdown; never a second authored source and never a separate file per document. |

This is the complete format enum used by `schemas/evidence-model.schema.json` (`delivery.output_format`): `MARKDOWN`, `MARKDOWN_WORD_READY`, `DOCX`, `HTML`. Do not invent additional format values in prose or documents.

Report the chosen format, the producing tool, and the real file extension in Document Control. Never claim a `.docx` exists without verifying the produced file. Never relabel another artifact as `.docx`.

## Capability check before offering Word output

Run these checks at design time (before the preflight offers the option) and again before writing the file. Record the exact result; an absent tool is `NOT_AVAILABLE`, never `PASS`.

| Capability | Check (PowerShell) | Enables |
|---|---|---|
| pandoc | `pandoc --version` | `DOCX` via `pandoc -o .docx --reference-doc=...` |
| python-docx | `python -c "import docx; print(docx.__version__)"` | `DOCX` via `tools/export_docx.py` |
| client-side OOXML writer | present in a self-contained HTML sample | `DOCX` (genuine `.docx`: headings, tables, text — no TOC field, page numbers or brand styling) |

If neither pandoc nor python-docx is available: do not offer `DOCX`; report `DOCX_NOT_AVAILABLE` with the exact check output, offer `MARKDOWN_WORD_READY`, and give the install commands (`pip install python-docx` or install pandoc). Installing a missing library does not change an already-approved deliverable — ask again before switching formats.

- Converter found → note the version, convert, then verify the output file exists, its size is greater than zero, and its extension matches the real format.
- Converter missing or conversion fails → report the reason verbatim; never emit a `.md` renamed to `.docx`, and never describe a `.doc` as a `.docx`.

Conversion command (run only after the format decision is approved and the source file is validated):

```powershell
pandoc "<SPEC>.md" -o "<SPEC>.docx" --reference-doc="<REFERENCE>.docx" --toc --toc-depth=3
```

`--reference-doc` carries fonts, styles, and margins. Without it, pandoc's default styling usually renders Thai text poorly.

For the HTML sample's browser export, the button must promise a genuine `.docx` but its tooltip must state the limits: text, headings and tables only — no TOC field, page numbers, images or brand styles. Use the script or pandoc path when that fidelity is required. Never relabel it as `.doc`, and never claim it carries the reference template's full styling.

## Template kit structural validation

When the template kit is changed or regenerated, run `python tools/validate_template_kit.py`. It checks template section/appendix numbering, evidence parity across Markdown/HTML/JSON, the four-panel HTML markers and TOC behaviour, the Word reference/docx structure (including no images), and exporter capability gates. A pass is a **structural** gate only: it does not judge whether an analysis is correct or whether evidence is genuine, and it does not replace final acceptance.

## Word design source: central reference + project override

Word styling is carried by a `.docx` reference file, not by Markdown or HTML.

| Source | Path | Use |
|---|---|---|
| Central default | `templates/word/reference.docx` | All projects unless overridden. Project-FS layout: centered cover (Tahoma 10 pt runs), 20 pt Document Control heading, 12 pt sub-labels, Version Control / Sign-off tables with fixed column widths (1.44/2.73/5.33/8.94 cm and 3.44/3.52/5.30/6.18 cm), TOC field, two A4 sections (cover margins 2.54/1.27/1.27/1.27 cm; body 2.54/2.54/1.91/1.91 cm), Heading 1–4, `Normal2`, `1.1 Sub Header`, `toc 1/2/3`, Table Grid, right-aligned text-only header/footer with PAGE field. No logos or images. |
| Project override | `<project>/.agents/word/brand.docx` (or an explicit approved path) | Branding only: logo, colour, company font, header/footer. Do not change the section contract. |

Generate or regenerate the central default with `python tools/make_reference_docx.py` (requires python-docx). Before using a project override, confirm the file exists and is readable; report a missing override instead of guessing. Record which file and version/path was used in Document Control.

Markdown→genuine docx is supported by `python tools/export_docx.py <input.md> <output.docx> [--reference-doc PATH] [--font ...] [--size ...]`. By default it opens `templates/word/reference.docx` as the layout carrier: it keeps the cover, Document Control tables, TOC and styles/section geometry, replaces only the carrier's mock body with the Markdown content, and promotes the first H1 to the cover title. `--font`/`--size` override the Normal style only; `--reference-doc` selects a project override. Canonical names stay verbatim and Mermaid remains labelled source text. For the best layout fidelity use `pandoc -o out.docx --reference-doc=<reference.docx>` when pandoc is installed.

## `MARKDOWN_WORD_READY` constraints

- One `#` H1 only, then `##`/`###` ATX headings; no setext headings, no HTML-in-Markdown, no custom anchors or badges.
- Pipe tables only; no nested tables, no tables inside cells, no merged cells. Keep to about six columns; move wider registries to an appendix as one-line-per-item lists or attach a separate CSV.
- List nesting no deeper than three levels. No emoji, box-drawing characters, or decorative arrows in headings.
- Keep code fences with an explicit language. Keep evidence IDs, object names, and status labels as plain text in table cells.
- Prefer short paragraphs. Long unbroken prose converts acceptably but reads poorly in Word.

These constraints change formatting only. Every required section, evidence pointer, count, and limitation must still be present — never drop content to satisfy a layout rule.

## Mermaid in Word

Word does not render Mermaid. Choose one and state which was used:

1. Render each diagram to an image with a verified Mermaid CLI and embed the image, keeping the diagram source in a labelled appendix.
2. Keep the Mermaid block as a labelled source block and tell the reader it must be rendered separately.

Always keep a short caption naming the branch/domain the diagram covers and its relationship kinds. A diagram that cannot be rendered still belongs in the dependency/path registries; the picture is never the evidence.

## Fonts for Thai output

Markdown carries no font information, so font selection belongs to conversion (`--reference-doc`, a Word template, or the export step). Apply these rules when producing DOCX/PDF or a Word-ready reference document.

- Prefer a Thai-capable font that is present on the machine; check before naming one.
- Recommended default for new designs: **Leelawadee UI**, about 11pt. The central reference uses **Tahoma** 10pt because the project Functional Specification template does; keep it unless a project override specifies another Thai-capable font.
- Use **TH Sarabun New** only when the user or organization specifies it; the usual pairing is 16pt because that family is narrow.
- Never assign Calibri, Arial, or Segoe UI to Thai text. They lack Thai glyphs and Word substitutes silently, producing unpredictable output.
- Always set font *and* size together. A font name without a matching size changes the page count and readability.
- Set the Thai font for the complex-script (`cs`) portion of the style, not only the Latin portion.
- Record the font family, size, and reference document used in Document Control so the layout can be reproduced.

Confirm availability instead of assuming:

```powershell
Get-ChildItem C:\Windows\Fonts -Include *.ttf,*.ttc -Recurse |
  Where-Object Name -match 'leelawui|leelawad|tahoma|sarabun|notosansthai'
```

If the preferred font is absent, choose from what the check returned and state the substitution. When exact appearance matters, also produce a PDF: embedding fonts is reliable there, while pandoc cannot embed fonts in docx.

## Word-ready template versus separate template file

Keep one canonical content template and derive the Word-ready variant by applying the constraints above during authoring, so both outputs carry identical content. If a separate template file is genuinely required, validate that the two deliverables contain the same sections, evidence, and counts — divergence between them is a defect, not a formatting choice.
