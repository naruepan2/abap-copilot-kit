# Trust and autonomy qualification

Resolve effective mode by scope. Unqualified defaults to Attended Standard; critical scope requires at least Controlled; qualified scope may default to Unattended.

Qualification key: Agent version, Skill version, MCP profile/hash, SID/client, package patterns, object types, guardrail profile, and operation classes.

Recommended initial evidence: 3-5 attended runs; zero wrong-target write, unauthorized action, source overwrite, accepted stale evidence/review, escaped ATC P1/P2, or transport clutter; UAT first-pass at least 80%. Treat thresholds as project defaults, not SAP standards.

Promotion to Unattended requires explicit policy approval. Demote immediately after critical guardrail failure, MCP/tool-profile change, target release change, or repeated UAT escape. Never transfer qualification across unrelated scopes automatically.
