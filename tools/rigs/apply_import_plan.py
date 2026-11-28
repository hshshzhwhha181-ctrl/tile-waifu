#!/usr/bin/env python3
"""P41: turn the 'hybrid_gate' choice of docs/rigs/pilot_yue_data.json into .import edits for game/assets/v10/rig/<rig>/*.png.import.

  python3 tools/rigs/apply_import_plan.py                 # dry run: prints the plan and the expected bytes
  python3 tools/rigs/apply_import_plan.py --write         # rewrites compress/mode + lossy_quality in the .import files
Re-run tools/rigs/pilot.py first after any art change. A newly authored rig (e.g. Yue) is covered by running
pilot.py --rigs <id> and applying its plan; default quality ladder is the VARIANTS list in pilot.py.
NOTE: this edits game/ (.import files only); P41 itself does NOT run it - it is for the owner/WP after review."""
import argparse, json, os, re
REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
VAR = {"lossless": (0, 0.7), "webp_q95": (1, 0.95), "webp_q90": (1, 0.9), "webp_q80": (1, 0.8), "webp_q70": (1, 0.7),
       "webp_q60": (1, 0.6), "vram": (2, 0.7)}
ap = argparse.ArgumentParser()
ap.add_argument("--data", default=os.path.join(REPO, "docs/rigs/pilot_yue_data.json"))
ap.add_argument("--write", action="store_true")
a = ap.parse_args()
d = json.load(open(a.data))
n = 0
for rig, s in d["summary"].items():
    for fn, ch in sorted(s["variants"]["hybrid_gate"]["choice"].items()):
        p = os.path.join(REPO, "game/assets/v10/rig", rig, fn + ".import")
        if not os.path.exists(p):
            print("missing", p); continue
        mode, q = VAR[ch]
        print("%-12s %-22s -> %s" % (rig, fn, ch))
        if a.write:
            t = open(p).read()
            t = re.sub(r"compress/mode=\d", "compress/mode=%d" % mode, t)
            t = re.sub(r"compress/lossy_quality=[\d.]+", "compress/lossy_quality=%s" % q, t)
            open(p, "w").write(t); n += 1
    print("%s: expected runtime ctex bytes %d (lossless %d)" % (rig, s["variants"]["hybrid_gate"]["runtime_bytes"], s["variants"]["lossless"]["runtime_bytes"]))
print("wrote %d .import files" % n if a.write else "dry run (no files changed)")
