#!/usr/bin/env python3
"""Validate a methodology resolution before the first SAP write."""
import json
import sys
from pathlib import Path

REQUIRED = (
    "product_edition", "release", "package", "software_component",
    "effective_language_version", "selected_profile", "dependencies_classified",
    "unknown_dependencies", "clean_core_verdict", "activation_order", "verification_plan",
)
LANGUAGES = {"standard_abap", "abap_for_cloud_development"}
PROFILES = {"A", "B", "C", "D"}


def load(path):
    try:
        data = json.loads(Path(path).read_text(encoding="utf-8-sig"))
    except OSError as e:
        raise SystemExit(f"methodology: cannot read file: {e}")
    except json.JSONDecodeError as e:
        raise SystemExit(f"methodology: invalid JSON: {e}")
    if not isinstance(data, dict):
        raise SystemExit("methodology: expected a JSON object")
    return data


def main(path):
    d = load(path)
    errors = []
    missing = [k for k in REQUIRED if k not in d]
    if missing:
        errors.append("missing: " + ", ".join(missing))
    for key in ("product_edition", "release", "package", "software_component", "clean_core_verdict"):
        if key in d and (not isinstance(d[key], str) or not d[key].strip()):
            errors.append(f"{key} must be non-empty")
    if d.get("effective_language_version") not in LANGUAGES:
        errors.append("effective_language_version must be standard_abap or abap_for_cloud_development")
    if d.get("selected_profile") not in PROFILES:
        errors.append("selected_profile must be A, B, C, or D")
    if d.get("dependencies_classified") is not True:
        errors.append("dependencies_classified must be true")
    if type(d.get("unknown_dependencies")) is not int or d["unknown_dependencies"] != 0:
        errors.append("unknown_dependencies must be integer 0 before write")
    for key in ("activation_order", "verification_plan"):
        value = d.get(key)
        if not isinstance(value, list) or not value:
            errors.append(f"{key} must be a non-empty list")
    if d.get("selected_profile") == "C" and d.get("effective_language_version") != "abap_for_cloud_development":
        errors.append("Profile C requires ABAP for Cloud Development")
    if d.get("selected_profile") == "D" and not str(d.get("bridge_decision_id", "")).strip():
        errors.append("Profile D requires an approved bridge_decision_id")
    if errors:
        print("\n".join(errors))
        return 1
    print("methodology: valid")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1] if len(sys.argv) > 1 else ""))
