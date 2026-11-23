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
# Local file tools carry the target in a path field, not in an object field.
PATH_KEYS = {
    "filepath", "file_path", "path", "fullpath", "full_path",
    "file", "filename", "target_path", "targetpath", "uri",
}
TOOL_KEYS = {"tool", "toolname", "tool_name", "name"}
WRITE_HINTS = (
    "sapwrite", "sapactivate", "saptransport", "sapgit", "sapmanage",
    "create_object", "replace_string", "activate_object", "create_test_include",
    "manage_transports", "set_transport", "apply_repository_workflow_object",
    "create_file", "createfile", "write_file", "replace_string_in_file",
    "apply_patch", "edit_file", "edit", "write",
)
REPOSITORY_FILE = re.compile(r"\.(abap|ddls|bdef|dcls|asddls|asbdef|asdcls)$", re.I)
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
    # Emit both shapes: the top-level decision is the documented PreToolUse contract,
    # the nested one keeps older harness builds working. AdditionalContext stays nested.
    print(json.dumps({
        "permissionDecision": "deny",
        "permissionDecisionReason": reason,
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": reason,
        }
    }, ensure_ascii=False))
    return 0


def repository_leaf(value):
    """Return the ABAP object name from a repository path, or None for unrelated files."""
    v = value.replace("\\", "/")
    leaf = v.rsplit("/", 1)[-1]
    is_repository = (
        "adt://" in v or "/sap/bc/adt/" in v or REPOSITORY_FILE.search(leaf) is not None
    )
    if not is_repository:
        return None
    name = leaf.split(".", 1)[0]
    if not re.match(r"^(?:[A-Za-z][A-Za-z0-9_]{2,}|/[A-Za-z0-9_]+/)", name):
        return None
    # abapGit-style leaves can be lowercase; ABAP object names are not case-sensitive here.
    return name.upper()


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
        # Local file tools name the target in a path field. Only repository-object
        # paths are checked; editing a Markdown file must not trip the SAP namespace gate.
        for key, value in pairs(data):
            if key.lower() not in PATH_KEYS or not isinstance(value, str):
                continue
            leaf = repository_leaf(value)
            if leaf and not leaf.startswith(ALLOWED_PREFIXES):
                return deny("delivery gate: write target outside Z*/Y*/$TMP/TEST_DEMO*: " + value)
    return 0


def selftest():
    """Exercise the gate shapes that had no coverage; exit 1 on any wrong verdict."""
    import contextlib
    import io

    cases = [
        ("allow repository path", {"tool": "edit", "tool_input": {"filePath": "/repo/ZCL_OK.clas.abap"}}, False),
        ("deny standard-object path", {"tool": "edit", "tool_input": {"filePath": "/repo/CL_STANDARD.clas.abap"}}, True),
        ("deny lowercase standard-object path", {"tool": "edit", "tool_input": {"filePath": "/repo/cl_standard.clas.abap"}}, True),
        ("deny create_file outside namespace", {"tool": "create_file", "tool_input": {"path": "D:\\outside\\CL_STANDARD.clas.abap"}}, True),
        ("local markdown is not an SAP target", {"tool": "replace_string_in_file", "tool_input": {"filePath": "D:\\kit\\README.md"}}, False),
        ("deny transport release", {"tool": "saptransport", "tool_input": {"action": "release"}}, True),
        ("read of standard object stays free", {"tool": "sapread", "tool_input": {"object": "CL_STANDARD"}}, False),
    ]
    failed = []
    for label, payload, expect_deny in cases:
        saved = sys.stdin
        sys.stdin = io.StringIO(json.dumps(payload))
        out = io.StringIO()
        try:
            with contextlib.redirect_stdout(out):
                main()
        finally:
            sys.stdin = saved
        text = out.getvalue().strip()
        denied = bool(text)
        if denied != expect_deny:
            failed.append(label + " (expected " + str(expect_deny) + ")")
            continue
        if denied:
            try:
                parsed = json.loads(text)
            except ValueError:
                failed.append(label + " (denial was not JSON)")
                continue
            if parsed.get("permissionDecision") != "deny":
                failed.append(label + " (no top-level permissionDecision)")
    if failed:
        print("selftest FAILED: " + "; ".join(failed))
        return 1
    print("selftest OK - %d cases, paths and both deny shapes verified" % len(cases))
    return 0


if __name__ == "__main__":
    if "--selftest" in sys.argv[1:]:
        raise SystemExit(selftest())
    raise SystemExit(main())
