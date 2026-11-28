#!/usr/bin/env python3
"""run_qa_tools.py - one-line gate for the QA tool-belt (tools/qa/*) so tools/tw_test.py and CI can run it as a suite.

Runs: (1) python -m unittest discover tools/qa   (2) palette_ramps.json in sync with tokens.json   (3) skin schema + Godot fixture in sync
      (4) skin_lint on the VALID sample must be clean, on the 2 invalid samples must fail with the expected codes.
Prints  "QA_TOOLS RESULT ok/total OK"  (or FAILED) and exit 0/1. Pillow + numpy are optional: without them the palette tests are skipped
and the line says so (CI installs them; see .github/workflows/qa.yml).
"""
from __future__ import annotations

import io
import sys
import unittest
from contextlib import redirect_stdout
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))


def main() -> int:
    ok = total = 0
    notes = []
    suite = unittest.defaultTestLoader.discover(str(HERE), pattern="test_*.py")
    buf = io.StringIO()
    res = unittest.TextTestRunner(stream=buf, verbosity=0).run(suite)
    skipped = len(res.skipped)
    bad = len(res.failures) + len(res.errors)
    ran = res.testsRun - skipped
    ok, total = ran - bad, ran
    if skipped:
        notes.append(f"{skipped} skipped (numpy/Pillow/jsonschema missing?)")
    for f, tb in res.failures + res.errors:
        print("QA_TOOLS FAIL test:", f.id())
        print("\n".join(tb.splitlines()[-4:]))
    import build_palette_ramps as bpr
    import build_skin_schema as bss
    import skin_lint as sl
    fix = HERE / "fixtures" / "skins"
    sink = io.StringIO()
    with redirect_stdout(sink):
        checks = [
            ("palette_ramps in sync", bpr.main(["--check"]) == 0),
            ("skin schema + godot fixture in sync", bss.main(["--check"]) == 0),
            ("skin_lint: valid sample clean", sl.main([str(fix / "valid")]) == 0),
            ("skin_lint: invalid_hex sample rejected", sl.main([str(fix / "invalid_hex")]) == 1),
            ("skin_lint: missing_slot sample rejected", sl.main([str(fix / "missing_slot")]) == 1),
        ]
    for name, good in checks:
        total += 1
        ok += 1 if good else 0
        if not good:
            print("QA_TOOLS FAIL", name)
    print(f"QA_TOOLS RESULT {ok}/{total} {'OK' if ok == total else 'FAILED'}" + (f" ({'; '.join(notes)})" if notes else ""))
    return 0 if ok == total else 1


if __name__ == "__main__":
    sys.exit(main())
