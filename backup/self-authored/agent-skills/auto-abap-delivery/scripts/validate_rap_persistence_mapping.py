#!/usr/bin/env python3
"""Validate explicit field-by-field persistence mapping for managed RAP."""
import json
import sys
from pathlib import Path


def load(path):
    try:
        data = json.loads(Path(path).read_text(encoding="utf-8-sig"))
    except OSError as e:
        raise SystemExit(f"rap-mapping: cannot read file: {e}")
    except json.JSONDecodeError as e:
        raise SystemExit(f"rap-mapping: invalid JSON: {e}")
    if not isinstance(data, dict):
        raise SystemExit("rap-mapping: expected a JSON object")
    return data


def main(path):
    d = load(path)
    errors = []
    for key in ("entity", "table", "fields", "unmapped_entity_fields", "unmapped_table_fields",
                "audit_fields_verified", "draft_table", "draft_field_names_match_entity"):
        if key not in d:
            errors.append(f"missing {key}")
    for key in ("entity", "table"):
        if not str(d.get(key, "")).strip():
            errors.append(f"{key} must be non-empty")
    fields = d.get("fields")
    if not isinstance(fields, list) or not fields:
        errors.append("fields must be a non-empty list of mapping entries")
    else:
        seen_entity, seen_table = set(), set()
        for i, f in enumerate(fields):
            if not isinstance(f, dict):
                errors.append(f"fields[{i}] must be an object")
                continue
            ef = str(f.get("entity_field", "")).strip()
            tf = str(f.get("table_field", "")).strip()
            src = str(f.get("source", "")).strip()
            if not ef or not tf or not src:
                errors.append(f"fields[{i}] needs entity_field, table_field and source")
            if ef and ef in seen_entity:
                errors.append(f"duplicate entity_field: {ef}")
            if tf and tf in seen_table:
                errors.append(f"duplicate table_field: {tf}")
            seen_entity.add(ef)
            seen_table.add(tf)
    for key in ("unmapped_entity_fields", "unmapped_table_fields"):
        v = d.get(key)
        if not isinstance(v, list):
            errors.append(f"{key} must be a list")
        elif v:
            errors.append(f"{key} must be empty, got: {', '.join(map(str, v))}")
    if d.get("audit_fields_verified") is not True:
        errors.append("audit_fields_verified must be true")
    draft = d.get("draft_table")
    parity = d.get("draft_field_names_match_entity")
    if draft:
        if not isinstance(draft, str) or not draft.strip():
            errors.append("draft_table must be a name or null")
        if parity is not True:
            errors.append("draft field-name parity must be proven before runtime claims")
    elif parity is not None:
        errors.append("draft_field_names_match_entity must be null when there is no draft table")
    if errors:
        print("\n".join(errors))
        return 1
    print("rap-mapping: valid")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1] if len(sys.argv) > 1 else ""))
