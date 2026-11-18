# Changelog — release index

One row per annotated tag. This is a **timeline**, not a copy of the release notes: the full notes
are in the tag annotation, the GitHub release body, and `~/.copilot/backups/release-notes-<tag>.md`
on the author's machine. Do not paste release bodies here — that would create a second home for
text that has to stay identical in three places already.

| Version | Date | Theme (from the tag subject) | Commit |
|---|---|---|---|
| v0.9.0 | 2026-11-15 | First tagged state | `890a56f` |
| v0.9.1 | 2026-11-15 | Repository stops carrying what it must not carry | `dedec6f` |
| v0.9.2 | 2026-11-15 | The contract has a backup, and the backup has a check | `d88f6e5` |
| v0.9.3 | 2026-11-15 | A check that remembers, and four that cannot be fooled | `5684ad6` |
| v0.9.4 | 2026-11-16 | Deep audit: 18 defects fixed, six gates negative-tested | `4022288` |
| v0.9.4.1 | 2026-11-16 | Nine defects, three new gates, two domain blocks parked | `d456d69` |
| v0.9.4.2 | 2026-11-16 | Eleven defects, two gates, a context figure off by 4,952 characters | `c5a6493` |
| v0.9.4.3 | 2026-11-16 | Round 4: eleven gates that could pass examining nothing | `caa9dfe` |
| v0.9.4.4 | 2026-11-16 | Round 5: say less, read less; three coverage holes closed | `290e0d3` |
| v0.9.4.5 | 2026-11-16 | Round 6: a gate for silently mis-decoded text | `cde952e` |
| v0.9.4.6 | 2026-11-16 | Round 7: gates that could not fire, a contradicted README claim | `5252443` |
| v0.9.4.7 | 2026-11-16 | Round 8: inventory what exists before fixing what looks wrong | `0d239a0` |
| v0.9.4.8 | 2026-11-16 | Deep audit v4: documentation and comments, not logic | `f5158a1` |
| v0.9.4.9 | 2026-11-16 | Deep audit v5: three atomic commits, two fixes, one residual | `5303f46` |
| v0.9.5 | 2026-11-17 | Toolkit review and pre-release rollback design | `1b2e09e` |

`verify-all.ps1` section 9f checks that every tag has a row and every row names a real tag.
Add the new row in the same commit as the release notes, before creating the tag. Do not rewrite
a published row: if the theme was imprecise, put the correction in the release notes instead.
