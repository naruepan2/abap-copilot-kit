#!/usr/bin/env python3
"""PreToolUse gate for the ABAP Auto Delivery agent.

Reads the hook payload as JSON on stdin. Denies only high-confidence violations:
transport release/import/delete/reassign, service publish/unpublish, production
write, and write targets outside Z*, Y*, $TMP or TEST_DEMO*.

No SAP calls. No file writes. No secrets, host names or customer identifiers.
Fail-open on an unparseable or unexpected payload: never block ordinary work
because a hook could not understand the shape.
"""
import json
import re
import sys

ALLOWED_PREFIXES = ("Z", "Y", "$TMP", "TEST_DEMO")
FORBIDDEN_ACTIONS = {
    "release", "import", "delete", "reassign", "unlock",
    "publish", "unpublish", "publish_srvb", "unpublish_srvb",
    "production_write", "transport_release", "transport_import",
}
OBJECT_KEYS = {
    "object", "objectname", "object_name", "program", "repository",
    "name", "objectname", "source_name", "target_object", "entity",
}
TOOL_KEYS = {"tool", "toolname", "tool_name", "name"}
WRITE_HINTS = (
    "sapwrite", "sapactivate", "saptransport", "sapgit", "sapmanage",
    "create_object", "replace_string", "activate_object", "create_test_include",
    "manage_transports", "set_transport", "apply_repository_workflow_object",
    "edit", "write",
)
ABAP_DENY = (
    re.compile(r"\btr_(?:request|task)\s*->\s*(?:release|delete)\s*\(", re.I),
    re.compile(r"\bapi_state\s*->\s*release\s*\(", re.I),
    re.compile(r"\bCL_ABAP_API_STATE\b.{0,120}\brelease\s*\(", re.I | re.S),
)


def strings(value):
    if isinstance(value, str):
        yield value
    elif isinstance(value, dict):
        for v in value.values():
            yield from strings(v)
    elif isinstance(value, list):
        for v in value:
            yield from strings(v)


def deny(reason):
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": reason,
        }
    }, ensure_ascii=False))
    return 0


def main():
    raw = sys.stdin.read()
    if not raw.strip():
        return 0
    try:
        data = json.loads(raw)
    except (ValueError, TypeError):
        return 0
    if not isinstance(data, dict):
        return 0

    tool_names = set()
    for key, value in data.items():
        if key.lower() in TOOL_KEYS and isinstance(value, str):
            tool_names.add(value)
    for value in strings(data):
        if value in WRITE_HINTS or value.lower() in WRITE_HINTS:
            tool_names.add(value)
    is_write = any(any(h in name.lower() for h in WRITE_HINTS) for name in tool_names)

    # Tool inputs are nested (tool_input / parameters / input), so walk every dict.
    def pairs(node):
        if isinstance(node, dict):
            for k, v in node.items():
                yield k, v
                yield from pairs(v)
        elif isinstance(node, list):
            for v in node:
                yield from pairs(v)

    # Action fields are the reliable signal; free text alone is not enough.
    for key, value in pairs(data):
        if key.lower() in {"action", "operation", "verb"} and isinstance(value, str):
            if value.strip().lower() in FORBIDDEN_ACTIONS:
                return deny("delivery gate: forbidden action " + value.strip())

    blob = "\n".join(strings(data))
    for pattern in ABAP_DENY:
        if pattern.search(blob):
            return deny("delivery gate: prohibited transport/API release pattern in payload")

    if is_write:
        for key, value in pairs(data):
            if key.lower() not in OBJECT_KEYS or not isinstance(value, str):
                continue
            name = value.strip()
            if name in tool_names or not name or " " in name or "\\" in name:
                continue
            if not re.match(r"^(?:[A-Z][A-Z0-9_]{2,}|/[A-Za-z0-9_]+/)", name):
                continue
            if not name.startswith(ALLOWED_PREFIXES):
                return deny("delivery gate: write target outside Z*/Y*/$TMP/TEST_DEMO*: " + name)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
