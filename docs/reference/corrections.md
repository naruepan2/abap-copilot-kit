# Corrections received — template and rules

The agent file carries a three-line pointer to this page instead of the template. The template
changes nothing until a real correction exists, and it cost about 210 tokens on every run of that
agent — a fixed cost for text that matters only at the moment of writing. The rules below are the
ones that used to sit in the agent file, unchanged.

## Rules

Empty by design. This section grows only from a correction **you** made in a real session — never
from the agent's own inference. It is the difference between following orders and knowing the work,
so an invented entry is worse than a missing one.

- **Cap 12.** When the 13th arrives, merge 2-3 entries that share a mechanism into one sharper rule,
  because growth by appending is a log, not a correction.
- **Every entry names what was wrong.** One without it is not a lesson.
- **A correction that applies to more than one agent stays in the agent file.** A domain correction
  belongs to that domain's agent, never both.

## Template

```markdown
### C-01 · <YYYY-MM-DD>
I did:       <what I actually did, in my own words>
Was wrong:   <why it was wrong and who corrected it>
Rule now:    <the rule that prevents the repeat, stated as a check>
```
