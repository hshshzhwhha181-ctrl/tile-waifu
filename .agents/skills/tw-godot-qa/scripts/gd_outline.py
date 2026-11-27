#!/usr/bin/env python3
"""Fast GDScript symbol indexer for large Tile Waifu .gd files.

Outputs class_name, extends, inner class, signal, enum, const, and func
signatures with exact 1-based line numbers, plus optional --search filtering.
"""
from __future__ import annotations

import argparse
import os
import re
import sys
from pathlib import Path
from typing import Iterable, List, Tuple


RE_CLASS_NAME = re.compile(r"^class_name\s+([A-Za-z_]\w*(?:\s+extends\s+[A-Za-z_][\w\.]*)?)")
RE_EXTENDS = re.compile(r"^extends\s+([A-Za-z_][\w\.\"]*)")
RE_INNER_CLASS = re.compile(r"^class\s+([A-Za-z_]\w*(?:\s+extends\s+[A-Za-z_][\w\.]*)?)\s*:")
RE_SIGNAL = re.compile(r"^signal\s+([A-Za-z_]\w*(?:\s*\([^)]*\))?)")
RE_ENUM = re.compile(r"^enum\s+([A-Za-z_]\w*)?\s*\{")
RE_CONST = re.compile(r"^const\s+([A-Za-z_]\w*)\s*(:[^=]*)?=\s*(.+)$")
RE_FUNC_START = re.compile(r"^((?:static\s+)?func\s+[A-Za-z_]\w*)\s*\(")


def _reconfigure_utf8() -> None:
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            try:
                stream.reconfigure(encoding="utf-8")
            except Exception:
                pass


def strip_inline_comment(line: str) -> str:
    in_quote: str | None = None
    escaped = False
    for idx, ch in enumerate(line):
        if escaped:
            escaped = False
            continue
        if ch == "\\":
            escaped = True
            continue
        if in_quote is None:
            if ch in ('"', "'"):
                in_quote = ch
            elif ch == "#":
                return line[:idx]
        elif ch == in_quote:
            in_quote = None
    return line


def indent_depth(raw_line: str) -> int:
    depth = 0
    for ch in raw_line:
        if ch == "\t":
            depth += 1
        elif ch == " ":
            depth += 1
        else:
            break
    return depth


def compact_const_rhs(rhs: str, max_len: int = 60) -> str:
    val = " ".join(rhs.strip().split())
    if val in ("{", "["):
        closer = "}" if val == "{" else "]"
        return f"{val} ... {closer}"
    if val.endswith("{") and "}" not in val:
        return val + " ... }"
    if val.endswith("[") and "]" not in val:
        return val + " ... ]"
    if len(val) > max_len:
        return val[: max_len - 3].rstrip() + "..."
    return val


def extract_func_signature(lines: List[str], start_idx: int) -> str:
    """Join multi-line GDScript function headers cleanly up to the body colon."""
    chunks: List[str] = []
    paren_depth = 0
    seen_open = False
    for idx in range(start_idx, min(len(lines), start_idx + 16)):
        clean = strip_inline_comment(lines[idx]).strip()
        if not clean:
            continue
        chunks.append(clean)
        in_q: str | None = None
        esc = False
        for pos, ch in enumerate(clean):
            if esc:
                esc = False
                continue
            if ch == "\\":
                esc = True
                continue
            if in_q is None:
                if ch in ('"', "'"):
                    in_q = ch
                elif ch == "(":
                    paren_depth += 1
                    seen_open = True
                elif ch == ")":
                    paren_depth = max(0, paren_depth - 1)
                elif ch == ":" and seen_open and paren_depth == 0:
                    after = clean[pos + 1 :].strip()
                    # Distinguish '-> void:' body colon from ':= ' default value inside signature
                    if not after.startswith("="):
                        joined = " ".join(chunks)
                        # Trim from the body-introducing colon onwards
                        return _trim_func_body(joined)
            elif ch == in_q:
                in_q = None
    return _trim_func_body(" ".join(chunks))


def _trim_func_body(joined: str) -> str:
    in_q: str | None = None
    esc = False
    paren_depth = 0
    seen_open = False
    for idx, ch in enumerate(joined):
        if esc:
            esc = False
            continue
        if ch == "\\":
            esc = True
            continue
        if in_q is None:
            if ch in ('"', "'"):
                in_q = ch
            elif ch == "(":
                paren_depth += 1
                seen_open = True
            elif ch == ")":
                paren_depth = max(0, paren_depth - 1)
            elif ch == ":" and seen_open and paren_depth == 0:
                rest = joined[idx + 1 :].lstrip()
                if not rest.startswith("="):
                    sig = joined[:idx].rstrip()
                    return re.sub(r"\s+", " ", sig)
        elif ch == in_q:
            in_q = None
    return re.sub(r"\s+", " ", joined.rstrip(": "))


def index_gd_file(path: Path) -> Tuple[int, List[Tuple[int, str, str]]]:
    text = path.read_text(encoding="utf-8", errors="replace")
    lines = text.splitlines()
    entries: List[Tuple[int, str, str]] = []
    inner_class_indent: List[int] = []

    for idx, raw in enumerate(lines):
        lineno = idx + 1
        code = strip_inline_comment(raw)
        stripped = code.strip()
        if not stripped:
            continue

        cur_indent = indent_depth(raw)
        while inner_class_indent and cur_indent <= inner_class_indent[-1]:
            inner_class_indent.pop()

        scope_prefix = "  " * len(inner_class_indent)
        is_top_or_class_scope = (cur_indent == 0) or (
            bool(inner_class_indent) and cur_indent == inner_class_indent[-1] + 1
        )

        m = RE_CLASS_NAME.match(stripped)
        if m and cur_indent == 0:
            entries.append((lineno, "class_name", f"class_name {m.group(1)}"))
            continue

        m = RE_EXTENDS.match(stripped)
        if m and is_top_or_class_scope:
            entries.append((lineno, "extends", f"{scope_prefix}extends {m.group(1)}"))
            continue

        m = RE_INNER_CLASS.match(stripped)
        if m:
            entries.append((lineno, "class", f"{scope_prefix}class {m.group(1)}:"))
            inner_class_indent.append(cur_indent)
            continue

        if not is_top_or_class_scope:
            continue

        m = RE_SIGNAL.match(stripped)
        if m:
            entries.append((lineno, "signal", f"{scope_prefix}signal {m.group(1)}"))
            continue

        m = RE_ENUM.match(stripped)
        if m:
            ename = m.group(1) or "<anonymous>"
            entries.append((lineno, "enum", f"{scope_prefix}enum {ename}"))
            continue

        m = RE_CONST.match(stripped)
        if m:
            cname = m.group(1)
            ctype = (m.group(2) or "").strip()
            crhs = compact_const_rhs(m.group(3))
            type_part = f"{ctype} " if ctype else " "
            entries.append((lineno, "const", f"{scope_prefix}const {cname}{type_part}= {crhs}"))
            continue

        m = RE_FUNC_START.match(stripped)
        if m:
            sig = extract_func_signature(lines, idx)
            entries.append((lineno, "func", f"{scope_prefix}{sig}"))
            continue

    return len(lines), entries


def iter_gd_paths(targets: Iterable[str]) -> List[Path]:
    found: List[Path] = []
    for raw in targets:
        p = Path(raw)
        if p.is_dir():
            for root, _, files in os.walk(p):
                for fn in sorted(files):
                    if fn.endswith(".gd"):
                        found.append(Path(root) / fn)
        elif p.is_file():
            found.append(p)
        else:
            raise FileNotFoundError(f"Path not found: {raw}")
    return found


def main() -> int:
    _reconfigure_utf8()
    parser = argparse.ArgumentParser(
        description="Fast GDScript symbol indexer for large .gd files."
    )
    parser.add_argument("paths", nargs="+", help="One or more .gd files or directories.")
    parser.add_argument(
        "-s",
        "--search",
        default="",
        help="Optional case-insensitive regex/substring filter applied to symbol signatures.",
    )
    parser.add_argument(
        "--kind",
        default="",
        help="Optional comma-separated kind filter (e.g. func,const,signal).",
    )
    args = parser.parse_args()

    try:
        files = iter_gd_paths(args.paths)
    except FileNotFoundError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2

    pattern = re.compile(args.search, re.IGNORECASE) if args.search else None
    kinds = {k.strip().lower() for k in args.kind.split(",") if k.strip()} if args.kind else set()

    total_matches = 0
    for idx, fp in enumerate(files):
        line_count, entries = index_gd_file(fp)
        filtered = [
            (ln, kind, sig)
            for ln, kind, sig in entries
            if (not kinds or kind in kinds) and (pattern is None or pattern.search(sig))
        ]
        if pattern is not None and not filtered and len(files) > 1:
            continue
        if idx > 0:
            print()
        disp = fp.as_posix()
        print(f"=== {disp} ({line_count} lines, {len(filtered)}/{len(entries)} symbols) ===")
        width = max(4, len(str(line_count)))
        for ln, _kind, sig in filtered:
            print(f"  {ln:>{width}d}: {sig}")
        total_matches += len(filtered)

    if pattern is not None and total_matches == 0:
        print(f"No symbols matched --search {args.search!r}.")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
