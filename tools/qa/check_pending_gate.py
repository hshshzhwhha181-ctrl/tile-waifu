#!/usr/bin/env python3
"""tools/qa/check_pending_gate.py — P96 CI gate enforcing:
  1. Golden / render PENDING -> FAIL after Date X parsed from docs/qa/THRESHOLDS.md
     (UNIFIED_QA_PLAN Appendix R T13).
  2. Strict rc 134 teardown rule on Godot suite logs (UNIFIED_QA_PLAN Appendix R T19):
     rc 134 / -6 is accepted ONLY when a green OK n/n marker line was printed AND
     zero SCRIPT ERROR lines appear anywhere in the log (before or after the marker).
  3. Optional check that golden capture ran inside the pinned docker/qa-render image
     (TW_QA_RENDER_IMAGE=1 and /etc/tw-qa-render/env.json present).

Usage:
  python tools/qa/check_pending_gate.py --logs LOG [LOG ...] [--thresholds docs/qa/THRESHOLDS.md]
      [--today YYYY-MM-DD] [--strict] [--require-render-image] [--json OUT]
  python tools/qa/check_pending_gate.py --check-rc-log LOG --marker MARKER --rc RC
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import re
import sys
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_THRESHOLDS = REPO_ROOT / "docs" / "qa" / "THRESHOLDS.md"

DATE_RE = re.compile(r"\b(\d{4}-\d{2}-\d{2})\b")
PENDING_LINE_RE = re.compile(r"\b(?:GOLDEN|TWSKINSOAK|AT-S24|AT-S22)\b.*\bPENDING\b|\bPENDING\b.*(?:golden|pixel|render)", re.IGNORECASE)
RATIO_RE = re.compile(r"(\d+)\s*/\s*(\d+)")
SCRIPT_ERR_RE = re.compile(r"\bSCRIPT ERROR:")
FAIL_RE = re.compile(r"\bFAIL(?:ED|URE)?\b")
KNOWN_ABORT_RCS = {134, -6}


def parse_pending_deadline(thresholds_path: Path) -> dt.date:
    """Read ISO Date X from the `golden PENDING` row of docs/qa/THRESHOLDS.md."""
    text = thresholds_path.read_text(encoding="utf-8")
    for line in text.splitlines():
        if line.strip().startswith("|") and "golden PENDING" in line:
            cols = [c.strip() for c in line.strip().strip("|").split("|")]
            if len(cols) >= 3:
                m = DATE_RE.search(cols[2])
                if m:
                    return dt.date.fromisoformat(m.group(1))
    raise ValueError(f"Could not find ISO date X in 'golden PENDING' row of {thresholds_path}")


def _expand_log_paths(log_paths: list[Path]) -> list[Path]:
    expanded: list[Path] = []
    for p in log_paths:
        if p.is_file():
            expanded.append(p)
        elif p.is_dir():
            expanded.extend(sorted(f for f in p.rglob("*") if f.is_file()))
    return expanded


def scan_pending_lines(log_paths: list[Path]) -> list[dict[str, Any]]:
    hits: list[dict[str, Any]] = []
    for p in _expand_log_paths(log_paths):
        for idx, raw in enumerate(p.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
            line = raw.strip()
            if PENDING_LINE_RE.search(line):
                hits.append({"file": str(p), "line": idx, "text": line})
    return hits


def evaluate_pending_gate(
    log_paths: list[Path],
    thresholds_path: Path,
    today: dt.date | None = None,
    strict: bool = False,
) -> dict[str, Any]:
    deadline = parse_pending_deadline(thresholds_path)
    now_date = today or dt.datetime.now(dt.timezone.utc).date()
    hits = scan_pending_lines(log_paths)
    past_deadline = now_date >= deadline
    enforce = strict or past_deadline
    if not hits:
        status = "OK"
        ok = True
    elif enforce:
        status = "FAIL"
        ok = False
    else:
        status = "WARN"
        ok = True
    return {
        "ok": ok,
        "status": status,
        "today": now_date.isoformat(),
        "deadline": deadline.isoformat(),
        "past_deadline": past_deadline,
        "strict": strict,
        "pending_count": len(hits),
        "hits": hits,
    }


def evaluate_rc134_policy(text: str, marker: str, rc: int) -> dict[str, Any]:
    """T19 strict rc 134 policy:
    rc == 0 passes if marker is green and 0 SCRIPT ERROR.
    rc in {134, -6} is accepted ONLY if:
      - marker line is present,
      - marker line indicates green OK (has 'OK' or matching n/n with n > 0 and no FAIL/FAILED),
      - 0 SCRIPT ERROR lines anywhere in output (including AFTER the marker line),
      - 0 FAIL lines in output.
    Any other non-zero rc (e.g. 1, 139/-11 SIGSEGV) fails unconditionally.
    """
    lines = [ln.rstrip("\r") for ln in text.splitlines()]
    low = marker.lower()
    marker_idx = -1
    marker_line = ""
    for i, ln in enumerate(lines):
        if low in ln.lower():
            marker_idx = i
            marker_line = ln.strip()

    script_errors = [ln.strip() for ln in lines if SCRIPT_ERR_RE.search(ln)]
    script_errors_after = [ln.strip() for ln in lines[marker_idx + 1:] if SCRIPT_ERR_RE.search(ln)] if marker_idx >= 0 else []
    fail_lines = [ln.strip() for ln in lines if FAIL_RE.search(ln) and not ln.strip().startswith("at:")]

    if marker_idx < 0:
        return {"ok": False, "reason": f"missing marker {marker!r}", "rc": rc, "script_errors": len(script_errors)}

    tail = marker_line[marker_line.lower().find(low) + len(low):]
    m_ratio = RATIO_RE.search(tail)
    ok_cnt = int(m_ratio.group(1)) if m_ratio else None
    tot_cnt = int(m_ratio.group(2)) if m_ratio else None
    ratio_ok = (ok_cnt is not None and tot_cnt is not None and tot_cnt > 0 and ok_cnt == tot_cnt)
    marker_has_ok = bool(re.search(r"\bOK\b", marker_line))
    marker_has_fail = bool(FAIL_RE.search(marker_line))
    marker_green = (ratio_ok or marker_has_ok) and not marker_has_fail

    if not marker_green:
        return {"ok": False, "reason": f"marker not green: {marker_line}", "rc": rc, "script_errors": len(script_errors)}
    if script_errors:
        after_note = f" ({len(script_errors_after)} after marker)" if script_errors_after else ""
        return {"ok": False, "reason": f"{len(script_errors)} SCRIPT ERROR(s){after_note}", "rc": rc, "script_errors": len(script_errors)}
    if fail_lines:
        return {"ok": False, "reason": f"{len(fail_lines)} FAIL line(s)", "rc": rc, "script_errors": 0}

    if rc == 0:
        return {"ok": True, "reason": "rc=0 green marker", "rc": rc, "script_errors": 0}
    if rc in KNOWN_ABORT_RCS:
        return {"ok": True, "reason": f"rc={rc} tolerated after green marker with 0 SCRIPT ERROR", "rc": rc, "script_errors": 0}
    return {"ok": False, "reason": f"unexpected rc={rc}", "rc": rc, "script_errors": 0}


def check_render_image_env() -> dict[str, Any]:
    in_image = os.environ.get("TW_QA_RENDER_IMAGE") == "1"
    manifest_path = Path(os.environ.get("TW_QA_ENV_MANIFEST", "/etc/tw-qa-render/env.json"))
    has_manifest = manifest_path.is_file()
    return {
        "ok": in_image and has_manifest,
        "in_image": in_image,
        "manifest_path": str(manifest_path),
        "has_manifest": has_manifest,
    }


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="P96 golden PENDING deadline & rc 134 policy gate")
    ap.add_argument("--logs", nargs="*", type=Path, default=[], help="Log files to scan for PENDING lines")
    ap.add_argument("--thresholds", type=Path, default=DEFAULT_THRESHOLDS, help="Path to docs/qa/THRESHOLDS.md")
    ap.add_argument("--today", type=str, default=None, help="Override UTC date YYYY-MM-DD (for testing)")
    ap.add_argument("--strict", action="store_true", help="Treat PENDING as FAIL regardless of Date X")
    ap.add_argument("--require-render-image", action="store_true", help="Fail unless running inside pinned docker/qa-render")
    ap.add_argument("--check-rc-log", type=Path, default=None, help="Verify a Godot suite log against T19 rc 134 rule")
    ap.add_argument("--marker", type=str, default="", help="Expected marker substring for --check-rc-log")
    ap.add_argument("--rc", type=int, default=0, help="Process exit code for --check-rc-log")
    ap.add_argument("--json", type=Path, default=None, help="Optional JSON report output path")
    args = ap.parse_args(argv)

    if args.check_rc_log is not None:
        text = args.check_rc_log.read_text(encoding="utf-8", errors="replace")
        res = evaluate_rc134_policy(text, args.marker, args.rc)
        print(f"RC134_GATE {'OK' if res['ok'] else 'FAIL'} ({res['reason']})")
        if args.json:
            args.json.write_text(json.dumps(res, indent=2) + "\n", encoding="utf-8")
        return 0 if res["ok"] else 1

    if args.require_render_image:
        img = check_render_image_env()
        if not img["ok"]:
            print(f"RENDER_IMAGE_GATE FAIL (in_image={img['in_image']}, manifest={img['has_manifest']} at {img['manifest_path']})")
            return 1
        print(f"RENDER_IMAGE_GATE OK ({img['manifest_path']})")

    today = dt.date.fromisoformat(args.today) if args.today else None
    rep = evaluate_pending_gate(args.logs, args.thresholds, today=today, strict=args.strict)
    if args.json:
        args.json.parent.mkdir(parents=True, exist_ok=True)
        args.json.write_text(json.dumps(rep, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    for h in rep["hits"][:10]:
        print(f"  PENDING: {h['file']}:{h['line']}: {h['text']}")
    print(
        f"PENDING_GATE {rep['status']} "
        f"(pending={rep['pending_count']}, today={rep['today']}, deadline={rep['deadline']}, strict={rep['strict']})"
    )
    return 0 if rep["ok"] else 1


if __name__ == "__main__":
    sys.exit(main())
