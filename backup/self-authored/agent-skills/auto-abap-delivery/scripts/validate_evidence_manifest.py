#!/usr/bin/env python3
"""Validate a minimal evidence manifest. Read-only."""
import argparse, hashlib, json, sys
from pathlib import Path

p = argparse.ArgumentParser()
p.add_argument("run_dir")
a = p.parse_args()
r = Path(a.run_dir)
f = r / "evidence" / "evidence-manifest.json"
errors = []
warnings = []
if not f.exists():
    errors.append("missing evidence/evidence-manifest.json")
    m = {}
else:
    try:
        m = json.loads(f.read_text(encoding="utf-8-sig"))
    except Exception as e:
        m = {}
        errors.append(f"invalid evidence manifest: {e}")
if m:
    # 1.0 is accepted as legacy; 1.1 adds behavior_verification, coverage and quality/receipts.
    # A legacy manifest lacking the new axes is reported, not silently blessed.
    version = str(m.get("manifest_version", ""))
    if version not in ("1.0", "1.1"):
        errors.append("manifest_version must be 1.0 (legacy) or 1.1")
    if version == "1.0":
        missing_axes = [k for k in ("behavior_verification", "coverage") if k not in m]
        if missing_axes:
            warnings.append("legacy 1.0 manifest lacks newer axes: " + ", ".join(missing_axes))
    run = m.get("run", {})
    for k in ("run_id", "task_id", "state", "execution_mode"):
        if not run.get(k):
            errors.append(f"missing run.{k}")
    mode = m.get("evidence_mode")
    if mode not in ("specification_conformance", "observed_run"):
        errors.append("invalid evidence_mode")
    if mode == "observed_run" and not m.get("limitations"):
        errors.append("observed_run requires limitations")
    for item in m.get("artifacts", []):
        # Legacy manifests stored bare path strings; new receipts store {path,sha256,bytes}.
        rel = item if isinstance(item, str) else item.get("path") if isinstance(item, dict) else None
        if not rel:
            errors.append("invalid artifact entry")
            continue
        f = r / rel
        if not f.exists():
            errors.append(f"artifact missing: {rel}")
        elif isinstance(item, dict):
            data = f.read_bytes()
            if item.get("bytes") != len(data):
                errors.append(f"artifact byte count drift: {rel}")
            if item.get("sha256") != hashlib.sha256(data).hexdigest():
                errors.append(f"artifact hash drift: {rel}")
    quality = m.get("quality", "standard")
    if quality not in ("standard", "release"):
        errors.append("quality must be standard or release")
    v = m.get("validation", {})
    if not isinstance(v, dict):
        errors.append("validation must be an object")
    else:
        for key in ("checksPassed", "checkCount", "warnings"):
            val = v.get(key)
            if val is not None and (type(val) is not int or val < 0):
                errors.append(f"validation.{key} must be a non-negative integer")
        if v.get("checkCount") is not None and (v.get("checksPassed") or 0) > v["checkCount"]:
            errors.append("checksPassed exceeds checkCount")
        if quality == "release":
            if v.get("warnings"):
                errors.append("release quality requires zero warnings")
            if v.get("errors"):
                errors.append("release quality requires zero errors")
            if v.get("checkCount") is None or v.get("checksPassed") != v.get("checkCount"):
                errors.append("release quality requires complete check counts")
    for d in m.get("diagnostics", []):
        if not isinstance(d, dict):
            errors.append("invalid diagnostic entry")
            continue
        for key in ("code", "severity", "message", "subject", "supportedFixes"):
            if key not in d:
                errors.append(f"diagnostic missing {key}")

    dispositions = {"manual_uat_item", "approved_waiver", "not_applicable_proven"}

    # Axis 1: behavior verification. Present-and-wired is not behavior proved.
    behavior_statuses = {
        "BEHAVIOR_VERIFIED", "BEHAVIOR_UNVERIFIED",
        "BEHAVIOR_FAILED", "BEHAVIOR_UNCERTAIN",
    }
    reliance_kinds = {"declared", "coincidental_reliance"}
    reliance_details = {"undeclared-precondition", "incidental-ordering", "fixture-only"}
    behavior = m.get("behavior_verification")
    if behavior is None and version == "1.0":
        pass  # legacy manifest: warned above, axis not asserted
    elif not isinstance(behavior, list) or not behavior:
        errors.append("behavior_verification requires at least one entry")
    else:
        seen_truths = set()
        for i, item in enumerate(behavior):
            if not isinstance(item, dict):
                errors.append(f"behavior_verification[{i}] must be an object")
                continue
            truth = str(item.get("truth", "")).strip()
            if not truth:
                errors.append(f"behavior_verification[{i}].truth is required")
            elif truth in seen_truths:
                errors.append(f"duplicate behavior truth: {truth}")
            seen_truths.add(truth)
            status = item.get("status")
            if status not in behavior_statuses:
                errors.append(f"behavior_verification[{i}].status invalid: {status}")
            if status == "BEHAVIOR_VERIFIED":
                if not str(item.get("evidence_id", "")).strip():
                    errors.append(f"behavior_verification[{i}].evidence_id required when verified")
                reliance = item.get("reliance")
                if reliance not in reliance_kinds:
                    errors.append(f"behavior_verification[{i}].reliance invalid: {reliance}")
                if reliance == "coincidental_reliance" and item.get("reliance_detail") not in reliance_details:
                    errors.append(f"behavior_verification[{i}].reliance_detail required (undeclared-precondition|incidental-ordering|fixture-only)")
            if status in ("BEHAVIOR_UNVERIFIED", "BEHAVIOR_UNCERTAIN") and not str(item.get("reason", "")).strip():
                errors.append(f"behavior_verification[{i}].reason required for non-verified behavior")
            if run.get("state") == "READY_FOR_UAT" and status in ("BEHAVIOR_UNVERIFIED", "BEHAVIOR_UNCERTAIN"):
                # A non-behavioral change may have no behavior to verify. Allow UAT when the
                # uncertainty is explicitly dispositioned, exactly like a coverage gap.
                if item.get("disposition") not in dispositions:
                    errors.append(f"READY_FOR_UAT requires disposition for unverified behavior: {truth or i}")
            if run.get("state") == "READY_FOR_UAT" and status == "BEHAVIOR_FAILED":
                errors.append(f"READY_FOR_UAT requires behavior not failed: {truth or i}")

    # Axis 2: verification coverage. A gap must be named, not silently omitted.
    coverage_statuses = {"CHECKED", "NOT_REPORTED", "NOT_SUPPORTED", "UNCHECKABLE"}
    coverage = m.get("coverage")
    if coverage is None and version == "1.0":
        pass  # legacy manifest: warned above, axis not asserted
    elif not isinstance(coverage, list) or not coverage:
        errors.append("coverage requires at least one entry")
    else:
        seen_checks = set()
        for i, item in enumerate(coverage):
            if not isinstance(item, dict):
                errors.append(f"coverage[{i}] must be an object")
                continue
            check = str(item.get("check", "")).strip()
            if not check:
                errors.append(f"coverage[{i}].check is required")
            elif check in seen_checks:
                errors.append(f"duplicate coverage check: {check}")
            seen_checks.add(check)
            status = item.get("status")
            if status not in coverage_statuses:
                errors.append(f"coverage[{i}].status invalid: {status}")
            if status != "CHECKED":
                if not str(item.get("reason", "")).strip():
                    errors.append(f"coverage[{i}].reason required for non-CHECKED status")
                if run.get("state") == "READY_FOR_UAT":
                    if item.get("disposition") not in dispositions:
                        errors.append(f"READY_FOR_UAT requires disposition for uncovered check: {check or i}")
            elif not str(item.get("evidence_id", "")).strip():
                errors.append(f"coverage[{i}].evidence_id required when CHECKED")
print(json.dumps({"valid": not errors, "errors": errors, "warnings": warnings}, indent=2))
sys.exit(1 if errors else 0)
