# PowerShell 5.1 + generated HTML with Thai

When a generated HTML renders Thai mojibake (`เธเนเธญ...`) in the shell/banner but the body derived from `.md` is correct, the generator `.ps1` is being read as ANSI because it lacks a UTF-8 BOM. PS 5.1 `Get-Content`/here-strings do this. Fix: save the `.ps1` with a UTF-8 BOM; read `.md` sources with `[IO.File]::ReadAllText(path, UTF8)` and write the output with `UTF8Encoding($false)`.

Other shell bugs found in the same renderer (verify with a localhost HTTP preview, not `file://` — the integrated browser blocks file URLs as "not in a trusted folder"):
- Duplicate heading IDs across `data-lang` panels break TOC anchors — prefix IDs per language (`th-sN` / `en-sN`).
- `scroll` listener added inside `render()` duplicates on every language switch — register once outside.
- Sticky header hides anchor targets — add `scroll-margin-top`; reset scroll on panel switch.

Verified 2026-11-26 on `D:\abap-copilot-kit\Projects\GSD\WS91100001\_build\render.ps1`.
