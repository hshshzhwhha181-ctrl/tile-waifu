#!/usr/bin/env python3
"""Static pre-commit UX & integration contract linter for Tile Waifu v10 GDScript.

Scans game/scripts/v10/**/*.gd (or specified paths) for 4 P0 contract violations:
  1. PCT_DIGIT      — bare '%' next to digits in string literals (CONTRACT_SELFTEST)
  2. RUB_LITERAL    — currency symbol '₽' in string literals outside central SKU/odds catalogs
  3. SALON_ADD_AFF  — forbidden literal 'G.add_aff' inside game/scripts/v10/salon/
  4. RAW_HERO_PNG   — raw hardcoded 'res://assets/hero/%s.png' without V10W1Core.hero_art /
                      V10W1Core.hero_png / ResourceLoader.exists guard
"""
from __future__ import annotations

import argparse
import os
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, List


# Matches V10ContractSelftest.ALLOWED_GD (single sources of SKU/odds truth)
CONTRACT_ALLOWED_SUFFIXES = (
    "core/base/sku.gd",
    "core/economy/econ_catalog.gd",
    "core/economy/econ_odds.gd",
    "core/gacha/rates.gd",
)

# Legitimate single-place UI/font/odds exceptions where '₽' has no hardcoded price digits
RUB_NONDIGIT_ALLOWED_SUFFIXES = (
    "scripts/v10/fonts/fonts.gd",
    "scripts/v10/shop/shop2.gd",
    "scripts/v10/gacha/ui/odds_screen.gd",
)

# Wave-1 core resolver modules that implement the founder fallback themselves
WAVE1_RESOLVER_SUFFIXES = (
    "core/wave1/w1_core.gd",
    "core/wave1/w1_mj.gd",
)

STR_LITERAL_RE = re.compile(r'"((?:[^"\\]|\\.)*)"|\'((?:[^\'\\]|\\.)*)\'')
PRINTF_SPEC_RE = re.compile(r"%[-+0 #]*\d*(?:\.\d+)?[dsfxX]")
PCT_DIGIT_RE = re.compile(r"\d[\d\s\u00a0,\.]*\s*%|%\s*\d")
DIGIT_RE = re.compile(r"\d")
STOPWORD_CTX_RE = re.compile(
    r"\b(?:BANNED\w*|UI_BANNED\w*|OWN_BANNED\w*|PRICE_MARKS\w*|STOP_WORDS\w*)\b"
    r"|\.(?:find|contains|has|replace)\s*\("
    r"|\bfor\s+\w+\s+in\s+\["
)
HERO_PNG_RE = re.compile(r'["\']res://assets/hero/%s\.png["\']')
HERO_GUARD_RE = re.compile(
    r"(?:V10W1Core\.(?:hero_art|hero_png|hero_tex_path)|V10W1Mj\.hero_png|ResourceLoader\.exists)"
)
FUNC_DECL_RE = re.compile(r"^\s*(?:static\s+)?func\s+[A-Za-z_]\w*\s*\(")


@dataclass
class Finding:
    rule: str
    rel_path: str
    line: int
    message: str
    snippet: str


def _reconfigure_utf8() -> None:
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            try:
                stream.reconfigure(encoding="utf-8")
            except Exception:
                pass


def find_repo_root() -> Path:
    here = Path(__file__).resolve()
    # .agents/skills/tw-godot-qa/scripts/ux_lint.py -> repo root is 4 levels up
    cand = here.parents[4]
    if (cand / "game" / "project.godot").exists():
        return cand
    cwd = Path.cwd().resolve()
    for p in (cwd, *cwd.parents):
        if (p / "game" / "project.godot").exists():
            return p
    return cand


def strip_comment(line: str) -> str:
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


def is_test_or_demo_path(rel_posix: str) -> bool:
    low = rel_posix.lower()
    return any(tok in low for tok in ("selftest", "demo", "runner", "/tools/"))


def iter_gd_files(targets: Iterable[Path]) -> List[Path]:
    files: List[Path] = []
    for t in targets:
        if t.is_dir():
            for dp, _, fns in os.walk(t):
                for fn in sorted(fns):
                    if fn.endswith(".gd"):
                        files.append(Path(dp) / fn)
        elif t.is_file() and t.suffix == ".gd":
            files.append(t)
    return files


def enclosing_func_bounds(code_lines: List[str], idx: int) -> tuple[int, int]:
    start = idx
    for i in range(idx, -1, -1):
        if FUNC_DECL_RE.match(code_lines[i]):
            start = i
            break
    end = len(code_lines)
    for i in range(idx + 1, len(code_lines)):
        if FUNC_DECL_RE.match(code_lines[i]):
            end = i
            break
    return start, end


def lint_file(path: Path, repo_root: Path, include_tests: bool = False) -> List[Finding]:
    try:
        rel_posix = path.resolve().relative_to(repo_root.resolve()).as_posix()
    except ValueError:
        rel_posix = path.as_posix()

    raw_lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    code_lines = [strip_comment(ln) for ln in raw_lines]
    findings: List[Finding] = []

    skip_contract = any(rel_posix.endswith(sfx) for sfx in CONTRACT_ALLOWED_SUFFIXES) or (
        not include_tests and is_test_or_demo_path(rel_posix)
    )
    skip_nondigit_rub = any(rel_posix.endswith(sfx) for sfx in RUB_NONDIGIT_ALLOWED_SUFFIXES)
    in_salon = "/scripts/v10/salon/" in ("/" + rel_posix) or "/core/salon/" in ("/" + rel_posix)
    skip_salon_test = path.name == "salon_selftest.gd" and not include_tests
    skip_wave1_resolver = any(rel_posix.endswith(sfx) for sfx in WAVE1_RESOLVER_SUFFIXES) or (
        not include_tests and is_test_or_demo_path(rel_posix)
    )

    # Pre-check if file has a local texture-loader helper wrapping ResourceLoader.exists
    file_has_safe_loader_helper = bool(
        re.search(r"func\s+_load_tex\b[\s\S]{0,260}ResourceLoader\.exists", "\n".join(code_lines))
    )

    for idx, code in enumerate(code_lines):
        lineno = idx + 1
        trimmed = code.strip()
        if not trimmed:
            continue

        # Rules 1 & 2: String literal checks (% next to digits, and ₽ symbol)
        if not skip_contract:
            window_prev = "\n".join(code_lines[max(0, idx - 6) : idx + 1])
            is_stopword_ctx = bool(STOPWORD_CTX_RE.search(window_prev)) or rel_posix.endswith("/lint.gd")
            for m in STR_LITERAL_RE.finditer(code):
                lit = m.group(1) if m.group(1) is not None else m.group(2)
                norm = lit.replace("\\u00a0", " ").replace("%%", "%")
                norm_no_fmt = PRINTF_SPEC_RE.sub("", norm)

                if PCT_DIGIT_RE.search(norm_no_fmt):
                    findings.append(
                        Finding(
                            rule="PCT_DIGIT",
                            rel_path=rel_posix,
                            line=lineno,
                            message=f"Bare '%' next to digits in string literal: {lit!r}",
                            snippet=trimmed,
                        )
                    )

                if "\u20bd" in norm_no_fmt:
                    has_digits = bool(DIGIT_RE.search(norm_no_fmt))
                    # Ignore single-char "₽" in stop-word / guard checks (e.g. BANNED arrays, text.find("₽"))
                    if lit.strip() == "\u20bd" and is_stopword_ctx:
                        continue
                    if not has_digits and skip_nondigit_rub:
                        continue
                    findings.append(
                        Finding(
                            rule="RUB_LITERAL",
                            rel_path=rel_posix,
                            line=lineno,
                            message=f"Currency symbol '₽' in string literal: {lit!r}",
                            snippet=trimmed,
                        )
                    )

        # Rule 3: Forbidden literal G.add_aff inside game/scripts/v10/salon/
        if in_salon and not skip_salon_test and "G.add_aff" in code:
            findings.append(
                Finding(
                    rule="SALON_ADD_AFF",
                    rel_path=rel_posix,
                    line=lineno,
                    message="Forbidden direct 'G.add_aff' in salon/ (use V10Salon.bond_cb / V10Bond)",
                    snippet=trimmed,
                )
            )

        # Rule 4: Raw hardcoded res://assets/hero/%s.png without V10W1Core.hero_art / ResourceLoader.exists
        if not skip_wave1_resolver and HERO_PNG_RE.search(code):
            fn_start, fn_end = enclosing_func_bounds(code_lines, idx)
            # Check from current line through end of enclosing function (so an earlier exists() on a
            # different path does not mask an unguarded return "res://assets/hero/%s.png" % hero),
            # plus same-line ternary/if expressions and V10W1Core references anywhere in the function.
            fn_body = "\n".join(code_lines[fn_start:fn_end])
            downstream_body = "\n".join(code_lines[idx : min(fn_end, idx + 12)])

            has_w1_helper = bool(
                re.search(r"V10W1Core\.(?:hero_art|hero_png|hero_tex_path)|V10W1Mj\.hero_png", fn_body)
            )
            has_exists_guard = bool(re.search(r"ResourceLoader\.exists", downstream_body)) or (
                file_has_safe_loader_helper and "_load_tex(" in downstream_body
            )

            if not (has_w1_helper or has_exists_guard):
                findings.append(
                    Finding(
                        rule="RAW_HERO_PNG",
                        rel_path=rel_posix,
                        line=lineno,
                        message=(
                            "Raw 'res://assets/hero/%s.png' without V10W1Core.hero_art / "
                            "V10W1Core.hero_png or ResourceLoader.exists guard"
                        ),
                        snippet=trimmed,
                    )
                )

    return findings


def main() -> int:
    _reconfigure_utf8()
    parser = argparse.ArgumentParser(
        description="Static UX & integration contract linter for game/scripts/v10/**/*.gd."
    )
    parser.add_argument(
        "paths",
        nargs="*",
        help="Optional paths to check (defaults to <repo>/game/scripts/v10 and the v10 modules in <repo>/game/core).",
    )
    parser.add_argument(
        "--include-tests",
        action="store_true",
        help="Also lint *selftest*, *demo*, and *runner* scripts.",
    )
    parser.add_argument(
        "--report-only",
        action="store_true",
        help="Always exit 0 even when violations are found.",
    )
    args = parser.parse_args()

    repo_root = find_repo_root()
    if args.paths:
        targets = [Path(p) for p in args.paths]
    else:
        # WP3: v10 logic moved to game/core (core/v06..v09 are legacy generations, never linted by this contract)
        core = repo_root / "game" / "core"
        targets = [repo_root / "game" / "scripts" / "v10"] + sorted(
            d for d in core.iterdir() if d.is_dir() and not re.fullmatch(r"v0\d", d.name)
        )

    gd_files = iter_gd_files(targets)
    if not gd_files:
        print("ERROR: No .gd files found to lint.", file=sys.stderr)
        return 2

    all_findings: List[Finding] = []
    for fp in gd_files:
        all_findings.extend(lint_file(fp, repo_root, include_tests=args.include_tests))

    counts = {
        "PCT_DIGIT": 0,
        "RUB_LITERAL": 0,
        "SALON_ADD_AFF": 0,
        "RAW_HERO_PNG": 0,
    }
    for f in all_findings:
        counts[f.rule] = counts.get(f.rule, 0) + 1

    print(f"UX_LINT scanned {len(gd_files)} .gd files under {', '.join(t.as_posix() for t in targets)}")
    print("+----------------+-------+--------------------------------------------------------------+")
    print("| Rule           | Hits  | Check Description                                            |")
    print("+----------------+-------+--------------------------------------------------------------+")
    print(f"| PCT_DIGIT      | {counts['PCT_DIGIT']:>5d} | Bare '%' next to digits in string literals                   |")
    print(f"| RUB_LITERAL    | {counts['RUB_LITERAL']:>5d} | Currency symbol '₽' in string literals                       |")
    print(f"| SALON_ADD_AFF  | {counts['SALON_ADD_AFF']:>5d} | Forbidden 'G.add_aff' inside game/scripts/v10/salon/         |")
    print(f"| RAW_HERO_PNG   | {counts['RAW_HERO_PNG']:>5d} | Raw 'res://assets/hero/%s.png' without guard / V10W1Core     |")
    print("+----------------+-------+--------------------------------------------------------------+")

    if all_findings:
        print(f"\nFINDINGS ({len(all_findings)} violation(s)):")
        for f in all_findings:
            print(f"  [{f.rule}] {f.rel_path}:{f.line} — {f.message}")
            print(f"      > {f.snippet}")
        print(f"\nUX_LINT RESULT: FAIL ({len(all_findings)} violation(s))")
        return 0 if args.report_only else 1

    print("\nUX_LINT RESULT: OK (0 violations)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
