#!/usr/bin/env python3
"""JSONL-first command-intent ledger for auto-abap-delivery recovery.

Read-only against SAP. Writes only <run_dir>/command-log.jsonl, the file that
init_run.py already creates and validate_run.py already requires.

Events are append-only; the latest event for a command_id carries its status.
This is deliberately NOT a database: no schema migration, no WAL, no second
source of truth. If a SQL index is ever needed, it can be rebuilt from this log.

Subcommands:
  record        append an INTENT_RECORDED event (all intent fields required)
  mark          append a status event for an existing command_id
  unreconciled  list in-flight commands; exit 1 if any are open
  selftest      6 synthetic cases in a throwaway folder; no run is touched
"""
import argparse
import json
import sys
import tempfile
from pathlib import Path
from datetime import datetime, timezone

OPEN = {"INTENT_RECORDED", "ACTION_SENT", "POSTCONDITION_UNKNOWN"}
CLOSED = {"RECONCILED_SUCCESS", "RECONCILED_PARTIAL", "RECONCILED_FAILED", "OWNER_ACTION_REQUIRED"}
STATUSES = OPEN | CLOSED
LOG_NAME = "command-log.jsonl"
INTENT_FIELDS = ("command_id", "run_id", "object", "intended_action")


def now():
    return datetime.now(timezone.utc).isoformat()


def read_events(path):
    """Return (events, errors). A damaged line is an error, never a skipped fact."""
    events, errors = [], []
    if not path.exists():
        return events, ["missing " + LOG_NAME]
    for n, line in enumerate(path.read_text(encoding="utf-8-sig").splitlines(), 1):
        if not line.strip():
            continue
        try:
            ev = json.loads(line)
        except ValueError as exc:
            errors.append("line %d invalid JSON: %s" % (n, exc))
            continue
        if not isinstance(ev, dict):
            errors.append("line %d is not an object" % n)
            continue
        events.append((n, ev))
    return events, errors


def append_event(path, ev):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as fh:
        fh.write(json.dumps(ev, ensure_ascii=False, sort_keys=True) + "\n")


def latest_by_command(events):
    """Return {command_id: (line_no, event)} plus conflict errors."""
    latest, errors = {}, []
    for n, ev in events:
        cid = ev.get("command_id")
        if not isinstance(cid, str) or not cid:
            errors.append("line %d has no command_id" % n)
            continue
        if ev.get("event") == "intent":
            if cid in latest:
                errors.append("line %d duplicates intent %s" % (n, cid))
            latest[cid] = (n, ev)
        elif ev.get("event") == "status":
            if cid not in latest:
                errors.append("line %d status for unknown command %s" % (n, cid))
                continue
            prev_n, prev = latest[cid]
            merged = dict(prev)
            merged.update({k: v for k, v in ev.items() if k not in ("event", "command_id")})
            latest[cid] = (prev_n, merged)
        else:
            errors.append("line %d has unknown event type" % n)
    for cid, (n, ev) in latest.items():
        if ev.get("status") not in STATUSES:
            errors.append("line %d invalid status for %s: %r" % (n, cid, ev.get("status")))
    return latest, errors


def cmd_record(args):
    path = Path(args.run_dir) / LOG_NAME
    ev = {
        "event": "intent",
        "command_id": args.command_id,
        "run_id": args.run_id,
        "object": args.object,
        "object_type": args.object_type,
        "intended_action": args.intended_action,
        "before_source_hash": args.before_hash,
        "expected_postcondition": args.expected_postcondition,
        "status": "INTENT_RECORDED",
        "recorded_at": now(),
    }
    missing = [k for k in INTENT_FIELDS if not ev.get(k)]
    if missing:
        print("record: missing " + ", ".join(missing), file=sys.stderr)
        return 2
    append_event(path, ev)
    print(ev["command_id"])
    return 0


def cmd_mark(args):
    path = Path(args.run_dir) / LOG_NAME
    events, errors = read_events(path)
    if errors:
        print("mark: " + "; ".join(errors), file=sys.stderr)
        return 2
    latest, errors = latest_by_command(events)
    if errors:
        print("mark: " + "; ".join(errors), file=sys.stderr)
        return 2
    if args.command_id not in latest:
        print("mark: unknown command " + args.command_id, file=sys.stderr)
        return 2
    if args.status not in CLOSED and args.status != "POSTCONDITION_UNKNOWN":
        print("mark: use record/ACTION_SENT only for open statuses", file=sys.stderr)
        return 2
    ev = {
        "event": "status",
        "command_id": args.command_id,
        "status": args.status,
        "recorded_at": now(),
    }
    if args.observed_postcondition:
        ev["observed_postcondition"] = args.observed_postcondition
    if args.observed_hash:
        ev["observed_source_hash"] = args.observed_hash
    append_event(path, ev)
    print(args.command_id + " -> " + args.status)
    return 0


def open_commands(run_dir):
    events, errors = read_events(Path(run_dir) / LOG_NAME)
    latest, more = latest_by_command(events)
    errors += more
    return [ev for _n, ev in latest.values() if ev.get("status") in OPEN], errors


def cmd_unreconciled(args):
    open_items, errors = open_commands(args.run_dir)
    for err in errors:
        print("ERROR " + err, file=sys.stderr)
    for ev in sorted(open_items, key=lambda e: (e.get("recorded_at", ""), e.get("command_id", ""))):
        fields = (
            ev.get("command_id"), ev.get("run_id"), ev.get("object"),
            ev.get("intended_action"), ev.get("status"), ev.get("recorded_at"),
        )
        print(" | ".join("" if f is None else str(f) for f in fields))
    if errors:
        return 2
    return 1 if open_items else 0


def selftest():
    """No DB, no SAP, no real run folder. Six cases, exit 1 on any wrong verdict."""
    failed = []
    with tempfile.TemporaryDirectory(prefix="cmdintent-") as tmp:
        run = Path(tmp) / "run"
        run.mkdir(parents=True, exist_ok=True)
        (run / LOG_NAME).write_text("", encoding="utf-8")
        append_event(run / LOG_NAME, {
            "event": "intent", "command_id": "C1", "run_id": "R1",
            "object": "ZCL_OK", "intended_action": "update", "status": "INTENT_RECORDED",
            "recorded_at": "2026-01-01T00:00:00+00:00",
        })
        append_event(run / LOG_NAME, {
            "event": "intent", "command_id": "C2", "run_id": "R1",
            "object": "ZCL_MAYBE", "intended_action": "activate", "status": "INTENT_RECORDED",
            "recorded_at": "2026-01-01T00:01:00+00:00",
        })
        append_event(run / LOG_NAME, {
            "event": "status", "command_id": "C2", "status": "ACTION_SENT",
            "recorded_at": "2026-01-01T00:02:00+00:00",
        })
        append_event(run / LOG_NAME, {
            "event": "status", "command_id": "C1", "status": "RECONCILED_SUCCESS",
            "recorded_at": "2026-01-01T00:03:00+00:00",
        })
        opened, errors = open_commands(run)
        ids = [e["command_id"] for e in opened]
        checks = [
            ("intent and ACTION_SENT stay open", ids == ["C2"]),
            ("closed command is excluded", "C1" not in ids),
            ("status event wins over intent", opened and opened[0]["status"] == "ACTION_SENT"),
            ("clean log has no parse errors", not errors),
        ]
        (run / LOG_NAME).write_text("", encoding="utf-8")
        opened2, errors2 = open_commands(run)
        checks.append(("empty log has no open commands", not opened2 and not errors2))
        (run / LOG_NAME).write_text("{not json\n", encoding="utf-8")
        opened3, errors3 = open_commands(run)
        checks.append(("damaged line fails closed", bool(errors3) and not opened3))
        for label, ok in checks:
            if not ok:
                failed.append(label)
    if failed:
        print("selftest FAILED: " + "; ".join(failed))
        return 1
    print("selftest OK - %d cases, JSONL ledger and fail-closed detector" % len(checks))
    return 0


def main():
    p = argparse.ArgumentParser(description=__doc__)
    sub = p.add_subparsers(dest="cmd", required=True)
    r = sub.add_parser("record")
    r.add_argument("run_dir")
    r.add_argument("--command-id", required=True)
    r.add_argument("--run-id", required=True)
    r.add_argument("--object", required=True)
    r.add_argument("--object-type", default="")
    r.add_argument("--intended-action", required=True)
    r.add_argument("--before-hash", default=None)
    r.add_argument("--expected-postcondition", default=None)
    r.set_defaults(fn=cmd_record)
    m = sub.add_parser("mark")
    m.add_argument("run_dir")
    m.add_argument("--command-id", required=True)
    m.add_argument("--status", required=True, choices=sorted(CLOSED | {"POSTCONDITION_UNKNOWN"}))
    m.add_argument("--observed-postcondition", default=None)
    m.add_argument("--observed-hash", default=None)
    m.set_defaults(fn=cmd_mark)
    u = sub.add_parser("unreconciled")
    u.add_argument("run_dir")
    u.set_defaults(fn=cmd_unreconciled)
    t = sub.add_parser("selftest")
    t.set_defaults(fn=lambda _a: selftest())
    args = p.parse_args()
    return args.fn(args)


if __name__ == "__main__":
    raise SystemExit(main())
