#!/usr/bin/env python3
"""Create the central Word reference template (style carrier) for TS/PRD output.

Layout follows the project Functional Specification convention:
cover + Document Control (Version Control / Sign-off) + Table of Content + body.
All logos, images and company marks are intentionally omitted.

Usage:
    python tools/make_reference_docx.py [output.docx]

The file is a *style carrier*: pandoc / export scripts read fonts, sizes, margins
and styles from it, while content comes from the Markdown/HTML source. For a
project override, copy it to <project>/.agents/word/brand.docx and change only
branding (colours/fonts/header/footer) — never the section contract.
"""
from __future__ import annotations

import sys
from pathlib import Path

try:
    from docx import Document
    from docx.shared import Cm, Pt, RGBColor
    from docx.enum.text import WD_ALIGN_PARAGRAPH
    from docx.enum.table import WD_TABLE_ALIGNMENT
    from docx.enum.section import WD_SECTION
    from docx.enum.style import WD_STYLE_TYPE
    from docx.oxml.ns import qn
    from docx.oxml import OxmlElement
except ImportError:
    print("DOCX_NOT_AVAILABLE: python-docx is not installed. Run: pip install python-docx")
    sys.exit(2)

# Values measured from the project Functional Specification reference document.
THAI_FONT = "Tahoma"             # reference body/headings; Thai-capable
COVER_FONT = "Times New Roman"   # _Cover_Title style carrier only
COVER_RUN_FONT = "Tahoma"        # reference cover runs override the style font
BODY_SIZE = 10
TABLE_SIZE = 9
ACCENT = RGBColor(0x00, 0xB0, 0xF0)   # reference Heading 2 blue
TABLE_INK = RGBColor(0x40, 0x40, 0x40)  # reference table-header ink
MUTED = RGBColor(0xCC, 0xCC, 0xCC)     # reference Caption/Quote grey
FOOT_INK = RGBColor(0x59, 0x59, 0x59)


def ensure_style(doc: "Document", name: str, base: str = "Normal") -> object:
    try:
        return doc.styles[name]
    except KeyError:
        st = doc.styles.add_style(name, WD_STYLE_TYPE.PARAGRAPH)
        try:
            st.base_style = doc.styles[base]
        except KeyError:
            pass
        return st


def _apply_rfonts(element, name: str) -> None:
    rpr = element.get_or_add_rPr()
    rfonts = rpr.find(qn("w:rFonts"))
    if rfonts is None:
        rfonts = rpr.makeelement(qn("w:rFonts"), {})
        rpr.append(rfonts)
    for attr in ("w:ascii", "w:hAnsi", "w:eastAsia", "w:cs"):
        rfonts.set(qn(attr), name)


def set_font(style, name: str = THAI_FONT, size: float | None = None,
             bold: bool = False, color: RGBColor | None = None) -> None:
    style.font.name = name
    if size is not None:
        style.font.size = Pt(size)
    style.font.bold = bold
    if color is not None:
        style.font.color.rgb = color
    _apply_rfonts(style.element, name)


def set_run_font(run, name: str = THAI_FONT, size: float = BODY_SIZE,
                 bold: bool = False, color: RGBColor | None = None) -> None:
    """Direct run formatting — the reference uses it over style defaults in places."""
    run.font.name = name
    run.font.size = Pt(size)
    run.bold = bold
    if color is not None:
        run.font.color.rgb = color
    _apply_rfonts(run._r, name)


def set_indent(style, left_cm: float = 0, first_cm: float = 0) -> None:
    style.paragraph_format.left_indent = Cm(left_cm)
    style.paragraph_format.first_line_indent = Cm(first_cm)


def add_field(paragraph, instruction: str, placeholder: str = "") -> None:
    def char(kind: str):
        r = paragraph.add_run()
        node = OxmlElement("w:fldChar")
        node.set(qn("w:fldCharType"), kind)
        r._r.append(node)

    char("begin")
    r = paragraph.add_run()
    instr = OxmlElement("w:instrText")
    instr.set(qn("xml:space"), "preserve")
    instr.text = instruction
    r._r.append(instr)
    char("separate")
    if placeholder:
        paragraph.add_run(placeholder)
    char("end")


def fill_table(table, headers: list[str], rows: list[list[str]], style: str,
               widths: list[float] | None = None) -> None:
    table.style = style
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    if widths:
        for i, width in enumerate(widths):
            table.columns[i].width = Cm(width)
            for row in table.rows:
                row.cells[i].width = Cm(width)
    for i, header in enumerate(headers):
        cell = table.cell(0, i)
        cell.text = header
        for p in cell.paragraphs:
            if style == "Table Grid":
                p.alignment = WD_ALIGN_PARAGRAPH.CENTER
            for r in p.runs:
                set_run_font(r, THAI_FONT, TABLE_SIZE, bold=True, color=TABLE_INK)
    for ri, row in enumerate(rows, start=1):
        for ci, value in enumerate(row):
            cell = table.cell(ri, ci)
            cell.text = value
            for p in cell.paragraphs:
                for r in p.runs:
                    set_run_font(r, THAI_FONT, TABLE_SIZE)


def add_cover(doc: "Document") -> None:
    """Centered 3-line cover — reference style carrier with 10pt Tahoma runs."""
    for text in ("SAP ABAP Documentation", "Technical Specification / PRD",
                 "<Capability / Object Name>"):
        p = doc.add_paragraph(style="_Cover_Title")
        p.alignment = WD_ALIGN_PARAGRAPH.CENTER
        set_run_font(p.add_run(text), COVER_RUN_FONT, BODY_SIZE)


def add_label(doc: "Document", text: str, size: float) -> None:
    p = doc.add_paragraph()
    set_run_font(p.add_run(text), THAI_FONT, size, bold=True)


def add_document_control(doc: "Document") -> None:
    add_label(doc, "Document Control", 20)
    add_label(doc, "Purpose", 12)
    doc.add_paragraph(
        "This document is generated from SAP evidence. Canonical names, evidence "
        "classes and limitation states are preserved verbatim.",
        style="Normal2",
    )
    add_label(doc, "Version Control", 12)
    vt = doc.add_table(rows=6, cols=4)
    fill_table(vt, ["Version", "Date modified", "Description of change", "Modified by"],
               [[str(i), "", "", ""] for i in range(1, 6)], "Normal Table",
               [1.44, 2.73, 5.33, 8.94])
    add_label(doc, "Sign-off", 12)
    sg = doc.add_table(rows=4, cols=4)
    fill_table(sg, ["Version", "Date", "Title and role", "Approver"],
               [["1.0", "", "Author", ""], ["1.0", "", "Reviewer", ""],
                ["1.0", "", "Approver", ""]], "Normal Table",
               [3.44, 3.52, 5.30, 6.18])


def add_toc(doc: "Document") -> None:
    doc.add_page_break()
    p = doc.add_paragraph(style="TOC")
    set_run_font(p.add_run("Table of Content"), THAI_FONT, 20)
    field_p = doc.add_paragraph()
    add_field(field_p, ' TOC \\o "1-3" \\h \\z \\u ',
              "Update field in Word (F9) to build the table of contents.")


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else root / "templates" / "word" / "reference.docx"

    doc = Document()

    # Section 0 — cover / Document Control / TOC: A4, top 1", others 0.5".
    for section in doc.sections:
        section.page_width = Cm(21.0)
        section.page_height = Cm(29.7)
        section.top_margin = Cm(2.54)
        section.bottom_margin = Cm(1.27)
        section.left_margin = Cm(1.27)
        section.right_margin = Cm(1.27)
        section.header_distance = Cm(1.27)
        section.footer_distance = Cm(1.27)

    # Styles: sizes, colours, indents and spacing measured from the reference FS.
    set_font(doc.styles["Normal"], name=THAI_FONT, size=BODY_SIZE)
    set_font(ensure_style(doc, "Normal2"), name=THAI_FONT, size=BODY_SIZE)
    for level, size, color, bold in ((1, 12, None, True), (2, 9, ACCENT, False),
                                     (3, 12, None, False), (4, 10, None, False)):
        st = doc.styles[f"Heading {level}"]
        set_font(st, name=THAI_FONT, size=size, bold=bold, color=color)
        st.paragraph_format.space_before = Pt(12 if level <= 2 else 18)
        st.paragraph_format.space_after = Pt(3 if level == 1 else 6 if level <= 3 else 12)
    set_indent(doc.styles["Heading 3"], left_cm=1.25, first_cm=-1.25)
    set_font(ensure_style(doc, "_Cover_Title"), name=COVER_FONT, size=20, bold=True)
    set_font(ensure_style(doc, "TOC"), name=THAI_FONT, size=20)
    set_font(ensure_style(doc, "1.1 Sub Header"), name=THAI_FONT, size=12, bold=True)
    set_indent(doc.styles["1.1 Sub Header"], left_cm=1.0, first_cm=-1.02)
    for name, bold, left_cm, first_cm, before, after in (
        ("toc 1", True, 0, 0, 6, 3),
        ("toc 2", True, 2.39, -0.69, 3, 3),
        ("toc 3", False, 2.50, -0.75, 3, 3),
    ):
        st = ensure_style(doc, name)
        set_font(st, name=THAI_FONT, size=12, bold=bold)
        set_indent(st, left_cm=left_cm, first_cm=first_cm)
        st.paragraph_format.space_before = Pt(before)
        st.paragraph_format.space_after = Pt(after)
    set_font(doc.styles["Title"], name=COVER_FONT, size=14, bold=True)
    doc.styles["Title"].paragraph_format.space_before = Pt(12)
    doc.styles["Title"].paragraph_format.space_after = Pt(3)
    set_font(doc.styles["List Bullet"], size=8.5)
    set_indent(doc.styles["List Bullet"], left_cm=0.4, first_cm=-0.4)
    set_font(doc.styles["Caption"], size=9, color=MUTED)
    doc.styles["Caption"].paragraph_format.space_after = Pt(10)
    set_font(doc.styles["Quote"], size=12, color=MUTED)
    doc.styles["Quote"].paragraph_format.left_indent = Cm(1.27)
    for style_name in ("Table Grid", "Normal Table"):
        try:
            set_font(doc.styles[style_name], size=TABLE_SIZE)
        except KeyError:
            pass

    # --- cover + Document Control + TOC (section 0) -----------------------
    add_cover(doc)
    add_document_control(doc)
    add_toc(doc)

    # Section 1 — body: reference uses 1" top/bottom and 0.75" left/right.
    body = doc.add_section(WD_SECTION.NEW_PAGE)
    body.page_width = Cm(21.0)
    body.page_height = Cm(29.7)
    body.top_margin = Cm(2.54)
    body.bottom_margin = Cm(2.54)
    body.left_margin = Cm(1.91)
    body.right_margin = Cm(1.91)
    body.header_distance = Cm(1.25)
    body.footer_distance = Cm(1.25)

    # --- body style carrier ------------------------------------------------
    doc.add_paragraph("General Information", style="Heading 1")
    doc.add_paragraph("Purpose of this document and analyzed scope.", style="Normal2")
    doc.add_paragraph("Program Overview", style="Heading 1")
    doc.add_paragraph("Overview of requirements", style="1.1 Sub Header")
    doc.add_paragraph("Business intent first, technical mechanism second.", style="Normal2")
    doc.add_paragraph("Detailed logic", style="1.1 Sub Header")
    doc.add_paragraph("Evidenced steps with EV-... references.", style="Normal2")
    doc.add_paragraph("Validation", style="Heading 2")
    doc.add_paragraph("Observed vs interpretation vs unresolved.", style="Normal2")
    doc.add_paragraph("Table example", style="Heading 3")
    dt = doc.add_table(rows=2, cols=3)
    fill_table(dt, ["Field", "Evidence", "Class"],
               [["MarginAmount", "EV-001", "OBSERVED"]], "Table Grid",
               [6.0, 6.0, 6.46])
    doc.add_paragraph("Caption: tables carry evidence IDs; diagrams are summaries.", style="Caption")

    # --- text-only right-aligned header/footer: no logos -------------------
    hp = doc.sections[0].header.paragraphs[0]
    hp.text = ""
    hp.alignment = WD_ALIGN_PARAGRAPH.RIGHT
    set_run_font(hp.add_run("SAP ABAP Documentation — SAMPLE (no logo; override in brand.docx)"),
                 THAI_FONT, 8, color=FOOT_INK)
    fp = doc.sections[0].footer.paragraphs[0]
    fp.text = ""
    fp.alignment = WD_ALIGN_PARAGRAPH.RIGHT
    set_run_font(fp.add_run("Evidence-based document · page "), THAI_FONT, 8, color=FOOT_INK)
    add_field(fp, " PAGE ", "1")

    out.parent.mkdir(parents=True, exist_ok=True)
    doc.save(out)
    print(f"OK: {out} ({out.stat().st_size} bytes)")
    print(f"Layout: centered cover (Tahoma {BODY_SIZE}pt), 20pt Document Control, "
          "12pt sub-labels, control-table widths 1.44/2.73/5.33/8.94 cm, "
          "2 sections, TOC + PAGE fields")
    print(f"Styles: {THAI_FONT} {BODY_SIZE}pt body, Heading 1 12pt bold, "
          f"Heading 2 9pt blue {ACCENT}, Normal Table + Table Grid")
    print("Logos/images: none. Project override: <project>/.agents/word/brand.docx")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
