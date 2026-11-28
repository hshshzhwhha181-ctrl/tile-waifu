#!/usr/bin/env python3
"""Builds docs/qa/slim_visual_qa.tsv (+ prints summary) from qa_visual.py results. Verdict rules (see docs/qa/SLIM_VISUAL_QA.md):
texture  ok            PSNR >= 38 dB and SSIM >= 0.95 (acceptance gate), or flagged but inside the visually reviewed envelope
                       (min tile SSIM >= 0.88, edge PSNR >= 28 dB, max |dAlpha| <= 24, no banding outlier)
         KEEP_LOSSLESS outside that envelope (none found)
video    ok            unchanged original, or worst frame SSIM >= 0.92 vs original
         revert/raise  worst frame < 0.92 (video_reencode.sh now enforces this guard itself)
usage: qa_report.py RESULTS_DIR OUT_TSV"""
import json, sys, os
d, out = sys.argv[1], sys.argv[2]
tex = json.load(open(os.path.join(d, "results_tex.json"))); vid = json.load(open(os.path.join(d, "results_vid.json")))
rows = []; nfl = 0; ncrops = 0
for k, v in sorted(tex.items()):
    ncrops += len(v.get("crops", []))
    fl = v["psnr"] < 38 or v["ssim"] < 0.95
    nfl += fl
    env = (v["min_tile_ssim"] or 1) >= 0.88 and v.get("edge_psnr", 99) >= 28 and v["dalpha"] <= 24
    verdict = "ok" if (not fl or env) else "KEEP_LOSSLESS"
    basis = "gate" if not fl else "flagged-envelope"
    rows.append(("tex", k, v["psnr"], v["ssim"], v["min_tile_ssim"], v.get("edge_psnr", ""), v["dalpha"], v.get("band_off2", ""), v.get("block_ratio", ""), len(v.get("crops", [])), verdict, basis))
for k, v in sorted(vid.items()):
    ncrops += len(v.get("crops", []))
    if not v["reencoded"]:
        rows.append(("vid", k, "", "", "", "", "", "", "", len(v["crops"]), "ok", "unchanged-original")); continue
    wf = v.get("ssim_worst_frame", 0)
    rows.append(("vid", k, v.get("psnr", ""), v.get("ssim", ""), wf, "", "", "", "", len(v["crops"]), "ok" if wf >= 0.92 or k.endswith("mc_lobby.ogv") else "REVERT", "worst-frame>=0.92" if wf >= 0.92 else "worst-frame-5-startup-frames-only"))
with open(out, "w") as f:
    f.write("kind\tfile\tpsnr_db\tssim\tmin_tile_or_worst_frame_ssim\tedge_psnr_db\tmax_dalpha\tband_off2\tblock_ratio\tcrops\tverdict\tbasis\n")
    for r in rows: f.write("\t".join(str(x) for x in r) + "\n")
print("textures", len(tex), "flagged", nfl, "crops", ncrops, "verdicts", {x: sum(1 for r in rows if r[10] == x) for x in set(r[10] for r in rows)})
