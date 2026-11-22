#!/usr/bin/env python3
"""Validate a client matrix before any runtime, data, dump, or UI claim."""
import json
import sys
from pathlib import Path


def load(path):
    try:
        text = Path(path).read_text(encoding="utf-8-sig")
    except OSError as e:
        raise SystemExit(f"client-matrix: cannot read file: {e}")
    try:
        data = json.loads(text)
    except json.JSONDecodeError as e:
        raise SystemExit(f"client-matrix: invalid JSON: {e}")
    if not isinstance(data, dict):
        raise SystemExit("client-matrix: expected a JSON object")
    return data


def main(path):
    d = load(path)
    errors = []
    for key in ("development_client", "runtime_client", "tool_connections", "unresolved_mismatches"):
        if key not in d:
            errors.append(f"missing {key}")
    for key in ("development_client", "runtime_client"):
        if key in d and (not isinstance(d[key], str) or not d[key].strip()):
            errors.append(f"{key} must name a real client")
    for key in ("unit_test_client", "fiori_preview_client", "data_validation_client"):
        if key in d and d[key] is not None and (not isinstance(d[key], str) or not d[key].strip()):
            errors.append(f"{key} must be a non-empty string or null")
    if "dump_clients" in d and not isinstance(d["dump_clients"], list):
        errors.append("dump_clients must be a list")
    if "unresolved_mismatches" in d:
        m = d["unresolved_mismatches"]
        if not isinstance(m, list):
            errors.append("unresolved_mismatches must be a list")
        elif m:
            errors.append(f"unresolved client mismatches present: {len(m)}")
    tools = d.get("tool_connections")
    if "tool_connections" in d:
        if not isinstance(tools, dict) or not tools:
            errors.append("tool_connections must name at least one observed tool connection")
        else:
            for name, info in tools.items():
                if not isinstance(info, dict):
                    errors.append(f"tool_connections.{name} must be an object")
                    continue
                for field in ("client", "destination", "evidence_id"):
                    if not str(info.get(field, "")).strip():
                        errors.append(f"tool_connections.{name}.{field} is required")
    if errors:
        print("\n".join(errors))
        return 1
    print("client-matrix: valid")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1] if len(sys.argv) > 1 else ""))
