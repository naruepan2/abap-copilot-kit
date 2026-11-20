#!/usr/bin/env python3
"""Build a minimal evidence-manifest.json from an existing V8 run folder.

Read-only against SAP. Writes only <run_dir>/evidence/evidence-manifest.json.
"""
import argparse, json
from datetime import datetime, timezone
from pathlib import Path

p = argparse.ArgumentParser()
p.add_argument("run_dir")
p.add_argument("--evidence-mode", choices=["specification_conformance", "observed_run"], required=True)
p.add_argument("--spec-revision", default=None)
p.add_argument("--final-state", default=None)
a = p.parse_args()
r = Path(a.run_dir)
s = json.loads((r / "run-state.json").read_text(encoding="utf-8"))
ip = s.get("interaction_policy", {})
manifest = {
    "manifest_version": "1.0",
    "generated_at": datetime.now(timezone.utc).isoformat(),
    "run": {
        "run_id": s.get("run_id"),
        "task_id": s.get("task_id"),
        "state": a.final_state or s.get("state"),
        "execution_mode": ip.get("execution_mode"),
        "review_level": ip.get("review_level"),
        "resolved_from": ip.get("resolved_from"),
        "qualification_state": ip.get("qualification_state"),
    },
    "target": {"system": s.get("target", {}).get("system"), "client": s.get("target", {}).get("client")},
    "evidence_mode": a.evidence_mode,
    "spec": {"available": a.evidence_mode == "specification_conformance", "revision": a.spec_revision or s.get("spec_revision")},
    "artifacts": [str(x.relative_to(r)) for x in sorted(r.rglob("*")) if x.is_file() and "evidence" not in x.parts],
    "limitations": [],
}
if a.evidence_mode == "observed_run":
    manifest["limitations"].append("No user-provided approved specification; full specification conformance cannot be confirmed.")
out_dir = r / "evidence"
out_dir.mkdir(parents=True, exist_ok=True)
out = out_dir / "evidence-manifest.json"
out.write_text(json.dumps(manifest, indent=2, ensure_ascii=False), encoding="utf-8")
print(out)
