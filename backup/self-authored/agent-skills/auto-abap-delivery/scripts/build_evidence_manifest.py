#!/usr/bin/env python3
"""Build a minimal evidence-manifest.json from an existing run folder.

Read-only against SAP. Writes only <run_dir>/evidence/evidence-manifest.json.
"""
import argparse, hashlib, json
from datetime import datetime, timezone
from pathlib import Path

p = argparse.ArgumentParser()
p.add_argument("run_dir")
p.add_argument("--evidence-mode", choices=["specification_conformance", "observed_run"], required=True)
p.add_argument("--spec-revision", default=None)
p.add_argument("--final-state", default=None)
p.add_argument("--quality", choices=["standard", "release"], default="standard")
p.add_argument("--checks-passed", type=int, default=None)
p.add_argument("--check-count", type=int, default=None)
p.add_argument("--warnings", type=int, default=0)
a = p.parse_args()
r = Path(a.run_dir)
s = json.loads((r / "run-state.json").read_text(encoding="utf-8-sig"))
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
    "quality": a.quality,
    "validation": {
        "checksPassed": a.checks_passed,
        "checkCount": a.check_count,
        "warnings": a.warnings,
        "errors": 0 if a.quality == "standard" or a.warnings == 0 else a.warnings,
    },
    "artifacts": [
        {
            "path": str(x.relative_to(r)),
            "sha256": hashlib.sha256(x.read_bytes()).hexdigest(),
            "bytes": x.stat().st_size,
        }
        for x in sorted(r.rglob("*")) if x.is_file() and "evidence" not in x.parts
    ],
    "diagnostics": [],
    "limitations": [],
}
if a.evidence_mode == "observed_run":
    manifest["limitations"].append("No user-provided approved specification; full specification conformance cannot be confirmed.")
diag_file = r / "evidence" / "diagnostics.json"
if diag_file.exists():
    manifest["diagnostics"] = json.loads(diag_file.read_text(encoding="utf-8-sig"))
if a.checks_passed is None or a.check_count is None:
    manifest["limitations"].append("Check counts not supplied; automated verdict is incomplete.")
out_dir = r / "evidence"
out_dir.mkdir(parents=True, exist_ok=True)
out = out_dir / "evidence-manifest.json"
tmp = out.with_suffix(".json.tmp")
tmp.write_text(json.dumps(manifest, indent=2, ensure_ascii=False), encoding="utf-8")
tmp.replace(out)  # atomic: the previous manifest stays intact if writing fails
print(out)
