#!/usr/bin/env python3
"""Validate an Object Responsibility Plan. Read-only; checks structure only."""
import argparse, json, sys
from pathlib import Path

try:
    import yaml
except ImportError:
    yaml = None

p = argparse.ArgumentParser()
p.add_argument("orp_file")
a = p.parse_args()
f = Path(a.orp_file)
errors = []
data = None
if not f.exists():
    errors.append(f"missing {f}")
elif yaml is None:
    errors.append("PyYAML/ruamel shim required to parse ORP")
else:
    try:
        data = yaml.safe_load(f.read_text(encoding="utf-8"))
    except Exception as e:
        errors.append(f"invalid ORP yaml: {e}")
if data:
    if not isinstance(data, dict):
        errors.append("ORP root must be a mapping")
    else:
        for k in ("revision", "objects"):
            if k not in data:
                errors.append(f"missing ORP field {k}")
        objects = data.get("objects", [])
        if not isinstance(objects, list) or not objects:
            errors.append("objects must be a non-empty list")
        else:
            seen = set()
            writers = set()
            for i, o in enumerate(objects):
                if not isinstance(o, dict):
                    errors.append(f"objects[{i}] must be a mapping")
                    continue
                for k in ("object", "type", "role", "verification"):
                    if not o.get(k):
                        errors.append(f"objects[{i}] missing {k}")
                name = str(o.get("object", "")).upper()
                if name and name in seen:
                    errors.append(f"duplicate object {name}")
                seen.add(name)
                if o.get("business_logic_allowed") is True and o.get("role") == "thin_shell":
                    errors.append(f"{name} thin_shell cannot own business logic")
                writer = o.get("writer_agent")
                if writer:
                    if writer in writers:
                        errors.append(f"duplicate writer {writer}")
                    writers.add(writer)
print(json.dumps({"valid": not errors, "errors": errors}, indent=2))
sys.exit(1 if errors else 0)
