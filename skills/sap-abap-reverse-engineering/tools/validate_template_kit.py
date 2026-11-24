#!/usr/bin/env python3
"""Structural validation for the reverse-engineering template kit.

Checks the canonical template, extended evidence schema, and the paired sample
Markdown/HTML files. This is a *structural* check only: it does not judge whether
the analysis inside a document is correct or whether evidence is genuine.
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TEMPLATE = ROOT / "templates" / "technical-specification.md"
SAMPLES = ROOT / "templates" / "samples"
SAMPLE_MD = SAMPLES / "technical-specification-sample.md"
SAMPLE_HTML = SAMPLES / "technical-specification-sample.html"
SAMPLE_DOCX = SAMPLES / "technical-specification-sample.docx"
SAMPLE_MODEL = SAMPLES / "evidence-model.json"
SCHEMA = ROOT / "schemas" / "evidence-model.schema.json"
EXPORT_DOCX = ROOT / "tools" / "export_docx.py"
REFERENCE_DOCX = ROOT / "templates" / "word" / "reference.docx"
MAKE_REFERENCE = ROOT / "tools" / "make_reference_docx.py"

failures: list[str] = []
notes: list[str] = []


def check(condition: bool, message: str) -> None:
    if not condition:
        failures.append(message)


# --- canonical template ----------------------------------------------------
check(TEMPLATE.exists(), "canonical template missing")
template = TEMPLATE.read_text(encoding="utf-8") if TEMPLATE.exists() else ""

sections = [int(n) for n in re.findall(r"(?m)^## (\d+)\.", template)]
check(sections == list(range(1, 19)), f"template sections: expected 1..18, got {sections}")

appendices = re.findall(r"(?m)^## Appendix ([A-K])\.", template)
check(appendices == list("ABCDEFGHIJK"), f"template appendices: expected A..K, got {appendices}")

placeholders = set(re.findall(r"\{\{([A-Z_]+)\}\}", template))
required_ph = {
    "FULL_ROOT_OBJECT_NAME", "DOCUMENT_CONTROL", "OBJECT_IDENTIFICATION",
    "SOLUTION_BOUNDARY", "FINDINGS_RISKS", "FINAL_ACCEPTANCE_CLEANUP",
}
check(required_ph <= placeholders, f"template missing placeholders: {sorted(required_ph - placeholders)}")
check("EVIDENCE_STATUS_SUMMARY" in placeholders, "front-matter evidence status placeholder missing")
check("ARCHITECTURE_CLASSES" in placeholders, "front-matter architecture classes placeholder missing")
check("OVERALL_CONFIDENCE" in placeholders, "front-matter confidence placeholder missing")
check(template.count("```mermaid") % 2 == 0 or "```mermaid" not in template,
      "template has unbalanced mermaid fence")

# --- schema ----------------------------------------------------------------
check(SCHEMA.exists(), "evidence schema missing")
if SCHEMA.exists():
    try:
        schema = json.loads(SCHEMA.read_text(encoding="utf-8"))
        props = schema.get("properties", {})
        for key in ("evidence", "objects", "claims", "dependencies", "counts", "delivery"):
            check(key in props, f"schema missing property: {key}")
        check(schema.get("required", [])[:1] == ["schema_version"], "schema_version not required first")
    except json.JSONDecodeError as exc:
        failures.append(f"schema JSON invalid: {exc}")

# --- reference files named in the SKILL load map --------------------------
skill = (ROOT / "SKILL.md").read_text(encoding="utf-8")
for ref in sorted(set(re.findall(r"references/([a-z0-9-]+\.md)", skill))):
    check((ROOT / "references" / ref).exists(), f"load-map reference missing: {ref}")

# --- sample pair -----------------------------------------------------------
if not SAMPLE_MD.exists() or not SAMPLE_HTML.exists():
    notes.append("sample pair not present; sample checks skipped")
else:
    md = SAMPLE_MD.read_text(encoding="utf-8")
    html = SAMPLE_HTML.read_text(encoding="utf-8")

    md_sections = [int(n) for n in re.findall(r"(?m)^## (\d+)\.", md)]
    check(md_sections == list(range(1, 19)), f"sample MD sections: expected 1..18, got {md_sections}")
    check("### 3.1 Solution Boundary" in md, "sample MD missing section 3.1 Solution Boundary")
    check(bool(re.search(r"^\> \*\*Evidence status:\*\*", md, re.M)), "sample MD front-matter evidence status missing")
    check(bool(re.search(r"^\> \*\*Architecture classes:\*\*", md, re.M)), "sample MD front-matter architecture missing")
    check(bool(re.search(r"^\> \*\*Overall confidence:\*\*", md, re.M)), "sample MD front-matter confidence missing")
    check("SAMPLE" in md[:2000] and "MOCK" in md[:2000], "sample MD lacks a prominent SAMPLE/MOCK banner")

    # Four panels: TS/PRD × TH/EN, all inside one HTML file.
    panels = re.findall(r'<article class="[^"]*doc[^"]*"[^>]*data-doc="(ts|prd)"[^>]*data-lang="(th|en)"[^>]*>', html)
    check(sorted(panels) == sorted([("ts", "th"), ("prd", "th"), ("ts", "en"), ("prd", "en")]),
          f"expected four panels (TS/PRD × TH/EN), got {panels}")

    for marker in ('id="exportWord"', 'id="print"',
                   'id="navToggle"', 'id="docs"', 'id="toc"', 'shell-js',
                   'data-sidebar="closed"', 'data-sidebar="open"', 'resetSidebar',
                   'search-hint', 'syncToc'):
        check(marker in html, f"sample HTML missing UI marker: {marker}")
    for stale in ('id="search"', 'id="searchScope"', 'clearMarks', 'scopeBtn',
                  'search.addEventListener'):
        check(stale not in html, f"sample HTML still contains removed search UI: {stale}")
    # Regression: short one-line sections (9/14/15) used to lose the active TOC
    # highlight to the next heading because the scroll-spy threshold was 140px.
    for token in ('pinnedId', 'getBoundingClientRect().top <= 80', 'clearPin',
                  'setTimeout(clearPin, 900)'):
        check(token in html, f"sample HTML lost TOC highlight fix: {token}")
    check('getBoundingClientRect().top <= 140' not in html,
          "sample HTML restored the 140px scroll-spy threshold (short-section bug)")
    check('layout.classList.toggle(\'sidebarClosed\')' not in html and "classList.toggle('open')" not in html,
          "sidebar still uses split desktop/mobile classes (stale-state bug)")
    check('max-width: 1080px' not in html and 'max-width: none' in html,
          "content card still re-centers when the sidebar toggles (shrink symptom)")
    check('class="scrim"' in html or 'class="scrim ' in html, "mobile drawer scrim missing")
    check('lang="th"' in html, "sample HTML lang is not th")
    check("SAMPLE" in html[:3000], "sample HTML lacks a prominent SAMPLE banner")
    check("insertBefore(m.firstChild, m)" not in html.replace(" ", ""),
          "search highlight code still contains the insertBefore(self) freeze pattern")
    check('aria-label="Export current document as a genuine .docx file"' in html,
          "export button label does not promise a genuine .docx")
    for token in ("text, headings and tables only", "no TOC field", "page numbers",
                  "images or brand styling"):
        check(token in html, f"export tooltip does not disclose its limits: {token}")

    # Derived Word rendition: real OOXML, no images, template geometry retained.
    check(SAMPLE_DOCX.exists(), "sample Word rendition missing")
    if SAMPLE_DOCX.exists():
        check(SAMPLE_DOCX.read_bytes()[:2] == b"PK", "sample Word rendition is not a .docx zip")
        import zipfile
        with zipfile.ZipFile(SAMPLE_DOCX) as zf:
            names = zf.namelist()
            check("word/document.xml" in names, "sample Word rendition lacks document.xml")
            check(not [n for n in names if n.startswith("word/media/")],
                  "sample Word rendition contains images/logos")
    for token in ('word/document.xml', '[Content_Types].xml', 'zipStore', 'crc32',
                  '.docx', 'Leelawadee UI'):
        check(token in html, f"HTML client-side docx writer missing token: {token}")
    check("application/msword" not in html, "HTML still contains the old .doc Blob export")

# --- DOCX exporter capability gate ----------------------------------------
check(EXPORT_DOCX.exists(), "tools/export_docx.py missing")
if EXPORT_DOCX.exists():
    exporter = EXPORT_DOCX.read_text(encoding="utf-8")
    check("DOCX_NOT_AVAILABLE" in exporter, "exporter does not report missing python-docx")
    check("pip install python-docx" in exporter, "exporter lacks install instruction")
    check("sys.exit(2)" in exporter, "exporter does not fail non-zero when capability absent")
    check(".docx" in exporter and "python-docx" in exporter, "exporter does not describe its real output")
    for token in ("--reference-doc", "reference.docx", "prepare_reference_document",
                  "REFERENCE_NOT_FOUND"):
        check(token in exporter, f"exporter does not reuse/handle the Word reference template: {token}")

    # PRD numbering must be complete 1..12 in both languages (regression: 1..5 then 11,12).
    for lang in ("th", "en"):
        m = re.search(r'data-doc="prd"[^>]*data-lang="' + lang + r'"[^>]*>(.*?)</article>', html, re.S)
        check(m is not None, f"PRD {lang} panel body not found")
        if m:
            nums = [int(n) for n in re.findall(r'<span class="n">(\d+)\.</span>', m.group(1))]
            check(nums == list(range(1, 13)), f"PRD {lang} section numbers: expected 1..12, got {nums}")

    # parity: evidence IDs in MD, HTML (all panels) and evidence-model.json
    md_ev = set(re.findall(r"\bEV-\d{3}\b", md))
    html_ev = set(re.findall(r"\bEV-\d{3}\b", html))
    check(bool(md_ev), "sample MD has no evidence IDs")
    check(md_ev <= html_ev, f"evidence IDs missing from HTML: {sorted(md_ev - html_ev)}")
    for lang in ("th", "en"):
        for doc in ("ts", "prd"):
            m = re.search(r'data-doc="' + doc + r'"[^>]*data-lang="' + lang + r'"[^>]*>(.*?)</article>', html, re.S)
            if m:
                panel_ev = set(re.findall(r"\bEV-\d{3}\b", m.group(1)))
                check(panel_ev == md_ev, f"{doc}/{lang} panel evidence parity failed: {sorted(panel_ev ^ md_ev)}")

    md_obj = set(re.findall(r"\bZ[A-Z_]{4,}\b", md))
    html_obj = set(re.findall(r"\bZ[A-Z_]{4,}\b", html))
    only_md = {o for o in md_obj - html_obj if "MOCK" not in o}
    check(not only_md, f"canonical objects present only in MD: {sorted(only_md)[:8]}")

    # evidence-model.json sample
    check(SAMPLE_MODEL.exists(), "sample evidence-model.json missing")
    if SAMPLE_MODEL.exists():
        try:
            model = json.loads(SAMPLE_MODEL.read_text(encoding="utf-8"))
            check(model.get("schema_version") == "1.0.0", "sample model schema_version mismatch")
            model_ev = {e["id"] for e in model.get("evidence", [])}
            check(model_ev == md_ev, f"evidence-model IDs mismatch MD: {sorted(model_ev ^ md_ev)}")
            for key in ("solution", "architectures", "activated_modules", "evidence",
                        "objects", "claims", "dependencies", "counts", "delivery"):
                check(key in model, f"sample model missing key: {key}")
        except json.JSONDecodeError as exc:
            failures.append(f"sample evidence-model.json invalid: {exc}")

    # balanced tags for the static rendition
    for tag in ("table", "thead", "tbody", "tr", "th", "td", "div", "h2", "h3", "details", "svg", "article", "script"):
        opened = len(re.findall(rf"<{tag}[\s>]", html))
        closed = len(re.findall(rf"</{tag}>", html))
        check(opened == closed, f"sample HTML tag imbalance <{tag}>: {opened} open / {closed} close")

# --- Word design source ----------------------------------------------------
check(REFERENCE_DOCX.exists(), "central templates/word/reference.docx missing")
if REFERENCE_DOCX.exists():
    check(REFERENCE_DOCX.stat().st_size > 0, "central reference.docx is empty")
    check(REFERENCE_DOCX.read_bytes()[:2] == b"PK", "reference.docx is not a zip-based .docx")
    import zipfile
    with zipfile.ZipFile(REFERENCE_DOCX) as zf:
        images = [n for n in zf.namelist() if n.startswith("word/media/")]
        check(not images, f"reference.docx contains logos/images (remove them): {images}")
        names = zf.namelist()
        check("word/document.xml" in names and "word/styles.xml" in names,
              "reference.docx missing required OOXML parts")
    try:
        from docx import Document
        ref = Document(REFERENCE_DOCX)
        style_names = {s.name for s in ref.styles}
        for wanted in ("Normal2", "_Cover_Title", "1.1 Sub Header", "toc 1", "toc 2", "toc 3",
                       "Table Grid", "Normal Table"):
            check(wanted in style_names, f"reference.docx missing style: {wanted}")
        check(len(ref.tables) >= 3, "reference.docx lacks cover control/sign-off/data tables")
        check(len(ref.sections) >= 2, "reference.docx lacks separate cover/TOC and body sections")
        check(round(ref.sections[0].left_margin.cm, 2) == 1.27 and
              round(ref.sections[-1].left_margin.cm, 2) == 1.91,
              "reference.docx section margins do not match the project FS")
        from docx.enum.text import WD_ALIGN_PARAGRAPH
        from docx.oxml.ns import qn
        cover = [p for p in ref.paragraphs if p.style.name == "_Cover_Title"]
        check(len(cover) >= 3 and all(p.alignment == WD_ALIGN_PARAGRAPH.CENTER for p in cover),
              "reference.docx cover lines are not centered")
        widths = [round(c.width.cm, 2) for c in ref.tables[0].columns]
        check(widths == [1.44, 2.73, 5.33, 8.94],
              f"reference.docx Version Control widths wrong: {widths}")
        h2rpr = ref.styles["Heading 2"].element.find(qn("w:rPr"))
        color = h2rpr.find(qn("w:color")) if h2rpr is not None else None
        check(color is not None and str(color.get(qn("w:val"))).upper() == "00B0F0",
              "reference.docx Heading 2 lost the reference blue")
        check(all(s.footer.paragraphs[0].alignment == WD_ALIGN_PARAGRAPH.RIGHT for s in ref.sections),
              "reference.docx footer is not right-aligned")
    except ImportError:
        notes.append("python-docx not installed; deep reference.docx style checks skipped")
check(MAKE_REFERENCE.exists(), "tools/make_reference_docx.py missing")
packaging = (ROOT / "references" / "output-packaging.md").read_text(encoding="utf-8")
preflight = (ROOT / "references" / "compact-preflight.md").read_text(encoding="utf-8")
for token in ("templates/word/reference.docx", ".agents/word/brand.docx", "make_reference_docx.py",
              "export_docx.py", "--reference-doc"):
    check(token in packaging, f"output-packaging.md missing Word design token: {token}")
check(".agents/word/brand.docx" in preflight and "Q5b" in preflight,
      "preflight does not ask for the Word design source")

# --- cross-document consistency fixes --------------------------------------
skill = (ROOT / "SKILL.md").read_text(encoding="utf-8")
modules = (ROOT / "references" / "prd-and-architecture-modules.md").read_text(encoding="utf-8")
schema_text = SCHEMA.read_text(encoding="utf-8") if SCHEMA.exists() else ""
check("`TS_ONLY` — **default**" in preflight and "`TS_PRD` — **default**" not in preflight,
      "PRD default conflict: TS_ONLY must be the default, PRD opt-in")
check("per selected document" in skill and "each written artifact" in skill,
      "workflow does not produce/validate each selected document")
check("HTML" in schema_text and "`DOCX`, or `HTML`" in skill and "`HTML`" in packaging,
      "HTML format enum is inconsistent across schema, skill and packaging")
for doc_name, text in (("SKILL.md", skill), ("compact-preflight.md", preflight),
                       ("output-packaging.md", packaging)):
    check("WORD_COMPAT_DOC" not in text,
          f"{doc_name} still uses the retired WORD_COMPAT_DOC format")
check("validate_template_kit.py" in skill and "validate_template_kit.py" in packaging,
      "structural validator is not documented in skill/packaging")
check("RAP_SERVICE_UNVERIFIED" in modules and "serialize as `NOT_COLLECTED`" in modules,
      "PRD modules lack the architecture class or claim-class serialization rule")
claim_enum = re.search(r'"claim_class": \{[^}]+\}', schema_text, re.S)
check(claim_enum is not None and "UNRESOLVED" not in claim_enum.group(0),
      "schema claim_class still accepts UNRESOLVED as a class")
check("close reason" in (SAMPLE_MD.read_text(encoding="utf-8") if SAMPLE_MD.exists() else ""),
      "sample does not explain limitation close reasons")
agent_file = Path.home() / ".copilot" / "agents" / "sap-abap-reverse-engineer-by-pongg.agent.md"
if agent_file.exists():
    agent_text = agent_file.read_text(encoding="utf-8")
    for token in ("FOCUSED", "CUSTOM", "COMPREHENSIVE", "MAXIMUM"):
        check(token in agent_text, f"agent lacks discovery-mode to intensity mapping: {token}")
    for token in ("JSONL in the OS temp directory", "do not use Markdown scratch files",
                  "SQLite", "derived-index-only plan", "never an authority for evidence"):
        check(token in agent_text, f"agent lacks scratchpad/storage policy: {token}")
    scalable = (ROOT / "references" / "scalable-analysis.md").read_text(encoding="utf-8")
    check("a Markdown scratch file would be an unparseable second authored copy" in scalable and
          "deferred, derived locator-index plan" in scalable,
          "scalable-analysis.md does not record the JSONL-over-Markdown/SQLite rationale")
else:
    notes.append("custom agent file not found; mode/intensity mapping check skipped")

# --- report ----------------------------------------------------------------
if failures:
    print("FAIL")
    for item in failures:
        print(f"  - {item}")
    sys.exit(1)

print("PASS: template kit is structurally valid")
for item in notes:
    print(f"  note: {item}")
