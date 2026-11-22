#!/usr/bin/env python3
"""Validate the L1/L2/G design decision for a new executable report."""
import json
import sys
from pathlib import Path

SHAPES = {"L1", "L2", "G"}


def load(path):
    try:
        data = json.loads(Path(path).read_text(encoding="utf-8-sig"))
    except OSError as e:
        raise SystemExit(f"prog-design: cannot read file: {e}")
    except json.JSONDecodeError as e:
        raise SystemExit(f"prog-design: invalid JSON: {e}")
    if not isinstance(data, dict):
        raise SystemExit("prog-design: expected a JSON object")
    return data


def strings(value):
    return isinstance(value, list) and all(isinstance(x, str) and x.strip() for x in value)


def main(path):
    d = load(path)
    errors = []
    for key in ("program", "strategy", "local_classes", "global_classes", "external_consumers",
                "reuse_expected", "unit_test_owner", "rationale", "thresholds_exceeded",
                "form_perform_exception", "design_review"):
        if key not in d:
            errors.append(f"missing {key}")
    if not str(d.get("program", "")).strip():
        errors.append("program must be non-empty")
    shape = d.get("strategy")
    if shape not in SHAPES:
        errors.append("strategy must be L1, L2, or G")
    for key in ("local_classes", "global_classes", "external_consumers", "thresholds_exceeded"):
        if key in d and not strings(d[key]):
            errors.append(f"{key} must be a list of non-empty strings")
    if not isinstance(d.get("reuse_expected"), bool):
        errors.append("reuse_expected must be a boolean")
    if not str(d.get("unit_test_owner", "")).strip():
        errors.append("unit_test_owner is required (use 'none' with a reason in rationale)")
    if not str(d.get("rationale", "")).strip():
        errors.append("rationale must explain the choice")
    if shape == "L1" and d.get("global_classes"):
        errors.append("L1 is local-only; move shared rules to L2 or G")
    if shape in {"L2", "G"} and not d.get("global_classes"):
        errors.append(f"{shape} requires a named global rule owner")
    if d.get("thresholds_exceeded") and d.get("design_review") is not True:
        errors.append("exceeded thresholds require design_review: true")
    exc = d.get("form_perform_exception")
    if exc is not None:
        if not isinstance(exc, dict):
            errors.append("form_perform_exception must be null or an object")
        else:
            if not str(exc.get("routine", "")).strip():
                errors.append("form_perform_exception.routine is required")
            if not str(exc.get("reason", "")).strip():
                errors.append("form_perform_exception.reason is required — class-based is the default")
    if errors:
        print("\n".join(errors))
        return 1
    print("prog-design: valid")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1] if len(sys.argv) > 1 else ""))
