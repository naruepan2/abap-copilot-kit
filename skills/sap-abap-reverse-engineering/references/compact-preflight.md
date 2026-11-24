# Compact Decision Preflight

Resolve the decisions below from the request and available context first. Infer delivery mode and language from natural language when clear. Discover object type, package, dependencies, and companions with authorized safe reads; do not ask the user for discoverable facts. Treat supplied dependency artifacts as available evidence.

Ask only about decisions that remain ambiguous, cannot be safely discovered, and materially affect scope or writes. Collect every missing decision into one batch of questions; do not ask in repeated rounds, and do not ask a question the request already answered.

## Q1. What should be produced?
Ask only if the request does not make the deliverable clear.
1. `TECHNICAL_SPECIFICATION`: one approved file built from the selected template; include root-appropriate architecture/processing, full-name graphs when useful, outputs, evidence, limits, risks, tests, and applicable appendices.
2. `CHAT_ANALYSIS`: provide the analysis in chat only; create no file. Keep evidence, full canonical names, scope, limitations, and completion status visible in the response.
3. `BOTH`: produce the Technical Specification and provide a concise chat summary. Do not redo or materially shorten the analysis in the summary; point to the file for detail.

All three modes use the same discovery, evidence, and interpretation workflow. Only presentation and artifact-specific validation differ. If the user's request explicitly says “chat only” or “no file,” select `CHAT_ANALYSIS` without asking again. If it explicitly requests a specification file, select `TECHNICAL_SPECIFICATION` unless it also asks for a chat summary.

## Q1b. After the reverse engineering: which document(s)?
Ask this only when the request has not settled it, and collect it with Q1/Q3/Q5/Q6 in one batch. Offer:
1. `TS_ONLY` — **default** — Technical Specification only.
2. `PRD_ONLY` — Product Requirement Document only; an explicit PRD request is required.
3. `TS_PRD` — both documents, derived from one analysis and one evidence model; available only after an explicit PRD request, never a default.
4. `CHAT_ONLY` — no documents (equivalent to Q1 `CHAT_ANALYSIS`).

When both are selected, the PRD describes as-is capability unless direct business evidence exists for intent, persona, KPI, vision, or priority (`prd-and-architecture-modules.md`). Never author plausible business content to fill a PRD. A PRD-only request still runs the same read-only discovery; it does not relax evidence rules.

Q2 (intensity) and Q4 (language) apply to every mode. Q3 (template), Q5 (output format), and Q6 (file destination) apply only to modes that write files; for `CHAT_ONLY`/`CHAT_ANALYSIS`, skip them entirely.

## Q2. How intensive should the analysis be?
This is optional. If the user asks for broad/deep/reverse-engineer analysis without a specific depth, default to `COMPREHENSIVE` and state the profile in the plan; do not block autonomous discovery to ask.
1. `FOCUSED`: critical paths and critical fields only. Faster, smaller, and not exhaustive.
   - Depth: `CRITICAL_PATHS_TO_TERMINAL`
   - Breadth: critical dependency/call branches appropriate to the root kind
   - Source profile: `DEEP`
   - Document detail: `DETAILED`
2. `COMPREHENSIVE`, recommended for routine deep reverse engineering: every in-scope root dependency path from a supplied artifact, every relevant custom dependency/call/SQL branch, critical standard continuations, material companions, detailed history, and exhaustive selected deliverable. A supplied artifact's structural occurrences are reconciled in full at every intensity; intensity controls additional source-reading depth, not whether exported rows/paths are silently omitted.
   - Depth: `TO_DATABASE_TABLE_MAXIMUM`
   - Breadth: all relevant custom dependency/call/SQL branches
   - Source profile: `EXTENDED`
   - Document detail: `EXHAUSTIVE`
3. `MAXIMUM`: every supported active dependency path for the selected object kind, including all readable standard wrappers, to physical/valid terminals or explicit limitations; maximum source reading and native reconciliation. Highest time/context cost.
   - Depth: `TO_DATABASE_TABLE_MAXIMUM`
   - Breadth: all reachable in-scope dependency/call/SQL branches
   - Source profile: `EXTENDED`
   - Document detail: `EXHAUSTIVE`
4. `CUSTOM`: configure depth, breadth, source profile, companion scope, history, and detail separately.

For CDS roots, maximum breadth includes active FROM/JOIN/set-operation/table-function/AMDP and materialized-association paths. It excludes unused, text-only, value-help-only, and navigation-only associations from the SQL denominator. For non-CDS roots, apply the equivalent breadth to relevant calls, exposure, enhancement, and data-dependency relations without treating those as SQL edges. `TO_DATABASE_TABLE_MAXIMUM` is a CDS/SQL depth label only; translate it into the applicable terminal/boundary criterion for other object kinds and say so in the plan.

## Q3. Which template governs the document structure?
File modes only. Resolve without asking when the request names a template, supplies one, or explicitly keeps the default.
1. **Canonical default** — `templates/technical-specification.md` of this skill.
2. **Another file under `templates/`** — the file the user names.
3. **A user-supplied template** — a path, an attachment, or pasted structure.
4. **Their own section list** — the user dictates sections directly.

Before using any non-default template, confirm the artifact exists and can be read. If it is unreadable, missing, or only partially supplied, say what failed and ask; never reconstruct the missing structure from memory or from a similar earlier document.

A template controls section order, headings, numbering, and section-level formatting. It cannot remove or override: read-only safety, canonical full-name preservation, evidence IDs and provenance, evidence classes, limitation/evidence-gap reporting, structural versus semantic completion, count hygiene, or final acceptance. If the supplied template has no place for required content, keep that content in an added, clearly-labelled section and record the deviation in Document Control. Never drop required content to match a template.

Record the template identity and provenance (path, or `USER_SUPPLIED`/`PASTED`, plus a version or hash when available) in Document Control.

## Q4. Which output language?
Infer from the request language when clear. Ask only when it is genuinely ambiguous, or when a bilingual deliverable was requested without saying which language leads.
1. `EN` — English prose.
2. `TH` — Thai prose, following `thai-output-rules.md`.
3. `EN+TH` — two files, validated separately, carrying identical facts, counts, evidence, and statuses.

SAP identifiers, code, status labels, and evidence classes keep their original form in every language. For `EN+TH`, confirm filenames that distinguish each language.

## Q5. Which output format and how many files?
File modes only. Default to `MARKDOWN` with one file per selected document when the user expresses no preference. State the resulting file count explicitly in the question so the user is not surprised.

| Choice | Documents selected | Files produced |
|---|---|---|
| `MARKDOWN` | `TS_ONLY` or `PRD_ONLY` | one `.md` |
| `MARKDOWN` | `TS_PRD` | two `.md` files (TS + PRD), validated separately |
| `MARKDOWN_WORD_READY` | as above | same count, Word-safe syntax in each |
| `DOCX` | as above | same count, only after converter verification |
| `HTML` | `TS_ONLY`, `PRD_ONLY`, or `TS_PRD` | **one** `.html` containing both selected documents as switchable panels (`data-doc="ts|prd"`), plus one shared evidence model; never one HTML per document |

Apply `output-packaging.md` for syntax constraints, font choice, converter verification, and Mermaid handling. `HTML` is a derived rendition of the same analysis; it never becomes a second authored source and never changes evidence classification. Never promise `DOCX` before verifying the converter. If it is unavailable, report that plainly and offer `MARKDOWN_WORD_READY` plus the conversion command instead of substituting silently.

## Q5b. Word design source (ask only when a Word format was selected)
1. **Central default** — `templates/word/reference.docx` — recommended; Thai-capable styles, no project branding.
2. **Project override** — `<project>/.agents/word/brand.docx` or an explicit path the user supplies. Confirm the file exists and is readable before using it. If absent, ask; never silently fall back to a project file that does not exist.
3. **No preference** → central default.

The choice controls styles/branding only. It must not change section order, evidence classes, counts, or source content. Record the chosen path in Document Control. Markdown→Word conversion uses `tools/export_docx.py` (python-docx) or `pandoc --reference-doc=<chosen .docx>`; both read the same Markdown source.

## Internal step. Inventory dependency evidence
This is an internal evidence inventory, not a question for the user. Check current authorized native providers and supplied/attached artifacts. If available, reconcile them; if not, proceed with discoverable safe reads and record provider limits. Never ask the user to select an evidence category or delay discovery to provide a baseline.

## Q6. Confirm file destination and existing-file handling
File modes only. Do not create or save a file until the user has either specified or explicitly approved **all three**: (a) destination directory, (b) exact filename, and (c) what to do if that exact file already exists. A suggested name/path is only a proposal; it is not consent. Do not infer the destination from the current working directory, editor file, previous deliverables, desktop, or a remembered path unless the user explicitly established that location as the default for this task or session.

If any of the three decisions is missing or ambiguous, ask one concise preflight question before writing. Present the exact proposed directory, filename(s), full path(s), and resulting file count, plus one of: create only if absent / overwrite / create versioned copy / choose another path / switch to chat-only. If existence cannot be safely checked, say so and do not claim that the path is new or safe to overwrite. Ask nothing about file paths in `CHAT_ONLY`/`CHAT_ANALYSIS` mode. For `EN+TH`, confirm all paths; for `HTML`, list the single combined path.

Suggested filenames, only when useful and clearly labelled as proposals: `<ROOT>_Technical_Specification.md`, `<ROOT>_Product_Requirement_Document.md`, `<ROOT>_Documentation.html` (single combined HTML). For bilingual Markdown add `_EN`/`_TH`. A suggestion does not set or imply a directory, overwrite policy, or approval. Adjust the extension to the chosen format.

## Advanced Overrides
Ask only when requested or materially necessary:
1. Use recommended companions and root/critical history.
2. Include all readable companions and all readable custom-object history.
3. Dependency/call graph only.
4. Configure manually.
