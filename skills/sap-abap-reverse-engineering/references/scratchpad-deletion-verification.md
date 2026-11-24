# Scratchpad Deletion Verification

Follow `scalable-analysis.md` for the full optional JSONL scratchpad lifecycle. At minimum, stop writes, parse and validate every line (including the final line), merge records, rebuild ledgers, and validate the selected deliverable before cleanup. Delete only the exact unique scratchpad path created for the run, then verify that exact path is absent. Never wildcard-delete temporary files or delete a path with uncertain ownership.

If no scratchpad was used, report `NOT_USED` when cleanup status is requested and do not create one just to record its absence. If the run is intentionally paused and the user explicitly requested resumability, a scratchpad may be retained with its exact path and retained-state status reported. Otherwise delete it, including for chat-only delivery. On deletion or verification failure report `SCRATCHPAD_CLEANUP_FAILED` and do not claim clean completion.
