# Thai Output Rules

Apply when the requested output language is Thai (`TH`) or part of a bilingual deliverable (`EN+TH`). These rules govern prose only; they never change facts, counts, evidence classes, or completion status.

## Always keep unchanged

- SAP object names, field names, table/view/service names, transaction codes, package names, program names: copy character-for-character. Never translate, shorten, re-case, or insert spaces inside a name.
- Suffixes are part of the name: `_0`, `_1`, `_TMP` are not standalone labels and must not be reworded.
- Technical identifiers and literals: `CDS`, `AMDP`, `DCL`, `BDEF`, `SRVD`, `SELECT`, `UNION ALL`, annotation names, class/method names.
- Evidence classes (`DECLARED`, `EXPOSED`, `UI_CONFIGURED`, `RUNTIME_OBSERVED`), completion statuses, quality statuses, and enum values.
- Evidence IDs, appendix letters, section numbers, dates, counts, and numeric values — keep digits, do not spell numbers out.
- Mermaid identifiers and labels; if a label must be Thai, keep the full object name intact inside it.

## Thai prose rules

- Write plain Thai meant for one reader with one subject. Prefer `คือ`, `มี`, `พบ`, `ไม่พบ` over rhetorical framing.
- Avoid stacking leading connectives (`นอกจากนี้`, `อีกทั้ง`, `ยิ่งไปกว่านั้น`, `ในขณะเดียวกัน`) at the start of consecutive sentences; Thai AI-generated text is recognized by this habit. State the next point directly.
- Avoid inflated significance (`ถือเป็นก้าวสำคัญ`, `ในยุคปัจจุบัน`, `มีบทบาทสำคัญอย่างยิ่ง`). Keep the fact; drop the elevation.
- Avoid translationese: no literal `ไม่เพียงแต่...แต่ยัง`, no forced triads, no `ซึ่ง` chains copied from English relative clauses.
- Keep technical English terms that have no settled Thai equivalent; on first use you may add a Thai gloss in parentheses. Do not invent Thai translations for SAP concepts.
- Prefer active voice and name the actor when it is known.

## Limitations must stay visibly limitations

Write gaps directly so a reader cannot mistake them for success:

- `ยังไม่ได้ตรวจสอบ`
- `ไม่พบหลักฐาน`
- `ผู้ให้บริการไม่รองรับการอ่าน source`
- `อ่านได้เพียง metadata`
- `ผลลัพธ์บางส่วน (PARTIAL)`

Keep hedge and uncertainty wording that separates `HYPOTHESIS` from `OBSERVED`. Never smooth these sentences into confident prose.

## Headings

Use bilingual headings in Thai output: Thai heading followed by the contract heading in parentheses, for example `## 2. ภาพรวมทางเทคนิค (Technical Overview)`. This keeps section numbers traceable to the contract and keeps the Word table of contents stable. In `EN` output keep the English headings as-is.

## Final language check

Before declaring the artifact accepted, check the actual rendered file, not your intention:

1. Search the Thai file for English sentences that should have been Thai prose. Object names, code, status labels, and quoted SAP text are expected; full explanatory sentences in English are a defect.
2. Search for translated identifiers: a name such as `ZI_X_1` that gained a Thai gloss, a translated suffix, or inserted spacing is corrupted. Restore it character-for-character.
3. Confirm the heading style is consistent (bilingual for `TH`, English-only for `EN`).
4. For `EN+TH`, run the same checks on the English file for stray Thai, and compare counts/evidence IDs across both files.
5. Record the check result in the acceptance section: passed, or the specific items corrected.

If a search tool is available, run it; if not, inspect the affected sections and say the check was manual. A language check that was not performed is `NOT_COLLECTED`, not passed.

## `EN+TH` deliverables

- Produce two files and validate each one separately: identical facts, counts, statuses, limitations, and evidence IDs; language differs only in prose and headings.
- A change made while polishing one language version must be reflected in the other; never let them drift.
- Report both paths and the shared template/language decision in Document Control of each file.

## Humanizer-style rewriting

Do not introduce a prose-rewriting skill as a default dependency. Those tools are designed to remove AI-sounding phrasing, and their rules conflict with this skill's contract: they may delete knowledge-limit disclaimers (which here are required evidence gaps), may add plausible detail the analysis never established, may flatten uncertainty labels, and may rewrite canonical names or table content.

If the user explicitly wants a prose pass, constrain it: narrative sections only, never tables, appendices, evidence registers, status labels, code, Mermaid, or object names; run it after the artifact is validated and then re-run canonical-name and count validation. Record that the prose was revised after validation. Any added factual claim or removed limitation is a defect that must be reverted.
