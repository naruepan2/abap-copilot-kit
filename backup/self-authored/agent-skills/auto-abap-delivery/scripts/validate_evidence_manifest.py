#!/usr/bin/env python3
"""Validate a minimal evidence manifest. Read-only."""
import argparse, json, sys
from pathlib import Path

p = argparse.ArgumentParser()
p.add_argument("run_dir")
a = p.parse_args()
r = Path(a.run_dir)
f = r / "evidence" / "evidence-manifest.json"
errors = []
if not f.exists():
    errors.append("missing evidence/evidence-manifest.json")
    m = {}
else:
    try:
        m = json.loads(f.read_text(encoding="utf-8"))
    except Exception as e:
        m = {}
        errors.append(f"invalid evidence manifest: {e}")
if m:
    if m.get("manifest_version") != "1.0":
        errors.append("manifest_version must be 1.0")
    run = m.get("run", {})
    for k in ("run_id", "task_id", "state", "execution_mode"):
        if not run.get(k):
            errors.append(f"missing run.{k}")
    mode = m.get("evidence_mode")
    if mode not in ("specification_conformance", "observed_run"):
        errors.append("invalid evidence_mode")
    if mode == "observed_run" and not m.get("limitations"):
        errors.append("observed_run requires limitations")
    for rel in m.get("artifacts", []):
        if not (r / rel).exists():
            errors.append(f"artifact missing: {rel}")
print(json.dumps({"valid": not errors, "errors": errors}, indent=2))
sys.exit(1 if errors else 0)
