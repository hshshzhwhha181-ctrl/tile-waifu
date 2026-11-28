"""Fuzz: skin_lint must NEVER raise on a hostile manifest and must stay sound (a mutation that breaks the contract is reported).
Deterministic (seed 7, 800 mutations) so a failure is reproducible: the failing mutation index is in the assertion message."""
import copy
import json
import random
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import make_skin_fixtures as mkf
import skin_lint as sl

REPO = Path(__file__).resolve().parents[2]
SCHEMA = json.loads((REPO / "design/specs/skin_manifest.schema.json").read_text(encoding="utf-8"))
KNOWN = {"SL-MAN-01", "SL-MAN-02", "SL-MAN-03", "SL-MAN-04", "SL-MAN-06", "SL-MAN-07", "SL-MAN-08", "SL-MAN-09", "SL-MAN-11", "SL-MAN-12",
         "SL-SLOT-01", "SL-SLOT-03", "SL-SLOT-04", "SL-SLOT-05", "SL-SLOT-06", "SL-PAL-01", "SL-PAL-02", "SL-PAL-03", "SL-PAL-04",
         "SL-PAL-06", "SL-FONT-01", "SL-SEC-01", "SL-SEC-02", "SL-FB-01", "SL-ULT-01", "SL-ULT-04", "SL-DUP-01", "SL-SIZE-01", "SL-TIER-02", "SL-ID-01"}
JUNK = [None, True, False, 0, -1, 7, 1e9, 0.5, "", "x", "#FF00AA", "rgb(1,2,3)", "H500", "T9", "NIGHT_700+T5@9", "https://x.y", "A" * 5000,
        "школьная форма", "\u0000", "\ud800".encode("utf-8", "surrogatepass").decode("utf-8", "replace"), [], {}, [1, 2], {"a": {"b": []}}, [[]] * 3]


def paths(node, prefix=()):
    yield prefix
    if isinstance(node, dict):
        for k, v in node.items():
            yield from paths(v, prefix + (k,))
    elif isinstance(node, list):
        for i, v in enumerate(node):
            yield from paths(v, prefix + (i,))


def get_parent(doc, p):
    for k in p[:-1]:
        doc = doc[k]
    return doc


class Fuzz(unittest.TestCase):
    def test_lint_never_raises_and_is_sound(self):
        rng = random.Random(7)
        base = mkf.build_valid()
        self.assertEqual(sl.lint_manifest(base, [], SCHEMA, Path("manifest.json"), {"dirname": False}).errors, [])
        silent = 0
        for n in range(800):
            d = copy.deepcopy(base)
            for _ in range(rng.choice([1, 1, 2, 3])):
                ps = [p for p in paths(d) if p]
                p = rng.choice(ps)
                par = get_parent(d, p)
                op = rng.choice(["set", "set", "delete", "dupkey", "swap"])
                key = p[-1]
                if op == "delete":
                    del par[key]
                elif op == "set":
                    par[key] = copy.deepcopy(rng.choice(JUNK))
                elif op == "swap" and isinstance(par, dict) and len(par) > 1:
                    other = rng.choice(list(par))
                    par[key], par[other] = par[other], par[key]
                elif op == "dupkey" and isinstance(par, dict):
                    par[str(key) + "_copy"] = copy.deepcopy(par[key])
            try:
                res = sl.lint_manifest(d, [], SCHEMA, Path("manifest.json"), {"dirname": False, "release": rng.random() < 0.3})
            except Exception as e:                                            # the whole point of the test
                self.fail(f"mutation #{n} crashed skin_lint: {type(e).__name__}: {e}")
            for e in res.errors:
                self.assertIn(e["code"], KNOWN, f"mutation #{n}: unknown code {e['code']}")
            if d == base:
                silent += 1
        self.assertLess(silent, 80, "too many no-op mutations: the fuzzer is not mutating")

    def test_non_dict_roots(self):
        for root in (None, [], "x", 5, [{"id": 1}]):
            res = sl.lint_manifest(root, [], SCHEMA, Path("manifest.json"), {})
            self.assertTrue(res.errors)
            self.assertEqual(res.codes()[0], "SL-MAN-01")


if __name__ == "__main__":
    unittest.main()
