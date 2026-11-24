#!/usr/bin/env python3
"""Generate a genuine .docx from a Technical Specification or PRD Markdown file.

Capability-gated: this script NEVER creates a fake .docx. If python-docx is not
installed it prints an exact install instruction and exits non-zero.

Usage:
    python tools/export_docx.py <input.md> <output.docx> [--reference-doc PATH]
                                [--font "Tahoma"] [--size 10]

By default the central templates/word/reference.docx is used as the layout base:
centered cover, Document Control tables, TOC field, two section geometries and
the reference font sizes/indents are preserved, and only the carrier's mock body
is replaced with the Markdown content. Use --reference-doc for a project override.

Fidelity notes (see references/output-packaging.md):
- Mermaid blocks are kept as labelled source text, not rendered images.
- Canonical SAP names are written verbatim; no auto-correction or translation.
- Thai font must be set with eastAsia/cs script properties; --font/--size override
  only the Normal style. For a fully typeset document use pandoc --reference-doc.
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

try:
    import docx
    from docx import Document
    from docx.shared import Pt
    from docx.oxml.ns import qn
    from docx.text.paragraph import Paragraph
except ImportError:
    print("DOCX_NOT_AVAILABLE: python-docx is not installed.")
    print("Install with:  pip install python-docx")
    print("After installing, re-run this script. No placeholder file was created.")
    sys.exit(2)


def set_style_font(document: "Document", name: str, size_pt: int) -> None:
    style = document.styles["Normal"]
    style.font.name = name
    style.font.size = Pt(size_pt)
    rpr = style.element.get_or_add_rPr()
    rfonts = rpr.find(qn("w:rFonts"))
    if rfonts is None:
        rfonts = rpr.makeelement(qn("w:rFonts"), {})
        rpr.append(rfonts)
    for attr in ("w:ascii", "w:hAnsi", "w:eastAsia", "w:cs"):
        rfonts.set(qn(attr), name)


def reference_title(text: str, fallback: str) -> str:
    m = re.search(r"(?m)^#\s+(.+)$", text)
    return m.group(1).strip() if m else fallback


def prepare_reference_document(document: "Document", title: str) -> None:
    """Keep cover/control/TOC and styles; drop only the reference's mock body."""
    body = document.element.body
    marker = None
    for child in list(body):
        if child.tag != qn("w:p"):
            continue
        try:
            if Paragraph(child, document).style.name == "Heading 1":
                marker = child
                break
        except (AttributeError, KeyError):
            continue
    if marker is not None:
        node = marker
        while node is not None:
            following = node.getnext()
            if node.tag != qn("w:sectPr"):
                body.remove(node)
            node = following

    cover = [p for p in document.paragraphs if p.style.name == "_Cover_Title"]
    if cover:
        cover[0].runs[0].text = "SAP ABAP Documentation"
        cover[1].runs[0].text = "Technical Specification / PRD"
        cover[2].runs[0].text = title
        for p in cover[1:3]:
            for r in p.runs[1:]:
                r.text = ""

    if document.tables:
        vc = document.tables[0]
        if len(vc.rows) > 1 and len(vc.columns) >= 3:
            vc.cell(1, 0).text = "1.0"
            vc.cell(1, 2).text = "Initial evidence-based draft"


def add_table(document: "Document", rows: list[list[str]]) -> None:
    if not rows:
        return
    width = max(len(r) for r in rows)
    table = document.add_table(rows=1, cols=width)
    table.style = "Table Grid"
    for i, cell in enumerate(rows[0]):
        table.rows[0].cells[i].text = cell
    for row in rows[1:]:
        cells = table.add_row().cells
        for i, cell in enumerate(row):
            cells[i].text = cell
    document.add_paragraph()


def parse_markdown(text: str, document: "Document", font: str, size: int) -> None:
    lines = text.splitlines()
    paragraph: list[str] = []
    in_fence = False
    fence: list[str] = []
    fence_lang = ""

    def flush() -> None:
        if paragraph:
            document.add_paragraph(" ".join(p.strip() for p in paragraph if p.strip()))
            paragraph.clear()

    for line in lines:
        if line.startswith("```"):
            if in_fence:
                p = document.add_paragraph()
                label = f"[diagram source: {fence_lang or 'code'}]" if fence_lang == "mermaid" else "[code]"
                r = p.add_run(label + "\n")
                r.bold = True
                p.add_run("\n".join(fence))
                fence, fence_lang, in_fence = [], "", False
            else:
                flush()
                in_fence = True
                fence_lang = line[3:].strip()
            continue
        if in_fence:
            fence.append(line)
            continue

        m = re.match(r"^(#{1,6})\s+(.*)$", line)
        if m:
            flush()
            level = min(len(m.group(1)), 4)
            document.add_heading(m.group(2).strip(), level=level)
            continue
        if line.startswith(">"):
            flush()
            p = document.add_paragraph(line.lstrip("> ").strip())
            p.style = document.styles["Quote"]
            continue
        if line.lstrip().startswith("|") and line.lstrip().endswith("|"):
            flush()
            continue  # table handled as a block below
        if re.match(r"^\s*[-*]\s+", line):
            flush()
            document.add_paragraph(line.strip()[2:].strip(), style="List Bullet")
            continue
        if re.match(r"^\s*\d+\.\s+", line):
            flush()
            document.add_paragraph(re.sub(r"^\s*\d+\.\s+", "", line).strip(), style="List Number")
            continue
        if not line.strip():
            flush()
            continue
        paragraph.append(line)

    flush()

    # Pipe tables (simple, no nested tables or merged cells).
    table_rows: list[list[str]] = []
    for line in lines:
        s = line.strip()
        if s.startswith("|") and s.endswith("|"):
            cells = [c.strip() for c in s.strip("|").split("|")]
            if all(re.fullmatch(r":?-{2,}:?", c or "") for c in cells):
                continue
            table_rows.append(cells)
        elif table_rows:
            add_table(document, table_rows)
            table_rows = []
    if table_rows:
        add_table(document, table_rows)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("input", type=Path)
    ap.add_argument("output", type=Path)
    ap.add_argument("--reference-doc", type=Path, default=None,
                    help="Word style carrier (default: templates/word/reference.docx)")
    ap.add_argument("--font", default=None, help="override Normal-style font")
    ap.add_argument("--size", type=int, default=None, help="override Normal-style size (pt)")
    args = ap.parse_args()

    if not args.input.exists():
        print(f"INPUT_NOT_FOUND: {args.input}")
        return 1
    if args.output.suffix.lower() != ".docx":
        print(f"OUTPUT_EXTENSION_INVALID: expected .docx, got {args.output.suffix}")
        return 1

    text = args.input.read_text(encoding="utf-8")
    explicit_ref = args.reference_doc is not None
    ref = args.reference_doc or (Path(__file__).resolve().parents[1] /
                                 "templates" / "word" / "reference.docx")
    if explicit_ref and not ref.exists():
        print(f"REFERENCE_NOT_FOUND: {ref} — an explicit override must exist; no file was written")
        return 1
    if not ref.exists():
        print(f"REFERENCE_NOT_FOUND: {ref} — using built-in styles")
    used = "none (built-in styles)"
    try:
        document = Document(ref) if ref.exists() else Document()
        if ref.exists():
            prepare_reference_document(document, reference_title(text, args.input.stem))
            used = str(ref)
    except Exception as exc:
        print(f"REFERENCE_UNUSABLE: {ref} ({exc}); using built-in styles")
        document = Document()

    font = args.font or "Tahoma"
    size = args.size or 10
    if used.startswith("none") or args.font or args.size:
        set_style_font(document, font, size)

    # The H1 became the cover title; keep the body sections from the Markdown.
    body_text = re.sub(r"(?m)^#\s+.+$", "", text, count=1)
    parse_markdown(body_text, document, font, size)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    document.save(args.output)

    if not args.output.exists() or args.output.stat().st_size == 0:
        print(f"EXPORT_FAILED: {args.output} was not written")
        return 1
    print(f"OK: {args.output} ({args.output.stat().st_size} bytes, python-docx {docx.__version__})")
    print(f"Reference: {used}")
    print(f"Font: {font} {size}pt (Normal style); reference styles/geometry kept otherwise")
    print("Note: Mermaid is source text only. Verify Thai layout in Word; for full fidelity use pandoc --reference-doc.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
