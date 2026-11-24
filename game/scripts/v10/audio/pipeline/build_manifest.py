#!/usr/bin/env python3
"""Build game/assets/v10/audio/manifest.json from the pipeline reports.

  python3 game/scripts/v10/audio/pipeline/build_manifest.py <music_report.txt> <jobs_all.tsv> <assets/v10/audio dir>

music_report.txt: lines "<music_id|motif_id|sting_id> <json from v10_loop.py>"
jobs_all.tsv:     kind \t name \t higgsfield job id \t model \t generated seconds
"""
import json
import os
import subprocess
import sys

NOTE = ("Tile Waifu 0.10 audio. Generated with Higgsfield (music: elevenlabs_music_v2_5 instrumental; sfx: "
        "mirelo_text_to_audio; voice: seed_audio cloned from each heroine's 0.7 Japanese voice). Loops cut by "
        "game/scripts/v10/audio/pipeline/v10_loop.py (seam_flux_pct = percentile of the spectral change at the wrap "
        "among all frames; <= 85 means no bigger a change than ordinary musical events). Music -16 LUFS, SFX -14 LUFS "
        "(transients peak-capped at -1 dBFS), voice matched to the heroine's 0.7 lines.")


def dur(p):
    out = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "stream=duration", "-of", "csv=p=0", p],
                         capture_output=True, text=True, check=True).stdout
    return float(out.strip().split("\n")[0])


def main():
    report, jobs_tsv, adir = sys.argv[1:4]
    rep = {}
    for line in open(report, encoding="utf-8"):
        k, j = line.split(" ", 1)
        rep[k.replace("music_", "", 1) if k.startswith("music_") else k] = json.loads(j)
    jobs = {}
    for line in open(jobs_tsv, encoding="utf-8"):
        kind, name, jid, model, d = line.strip().split("\t")
        jobs[(kind, name)] = (jid, model, int(d))
    man = {"note": NOTE, "music": {}, "sfx": {}, "voice": {}}
    for key, d in rep.items():
        jid, model, gd = jobs[("music", key)]
        e = {"file": "music/%s.ogg" % key, "loop": bool(d["loop"]), "len": round(dur(os.path.join(adir, "music", key + ".ogg")), 3),
             "lufs": round(d["lufs_out"], 1), "job": jid, "model": model, "gen_s": gd}
        if d["loop"]:
            e.update(bpm=round(d["bpm"], 1), src_start_s=round(d["start_s"], 3), src_end_s=round(d["end_s"], 3),
                     seam_flux_pct=round(d["seam_flux_pct"], 1), seam_similarity=round(d["seam_score"], 3),
                     rms_jump_db=round(d.get("rms_jump_db", 0.0), 2))
        man["music"][key] = e
    for (kind, name), (jid, model, gd) in jobs.items():
        if kind == "music":
            continue
        man[kind][name] = {"file": "%s/%s.ogg" % (kind, name), "len": round(dur(os.path.join(adir, kind, name + ".ogg")), 3),
                           "job": jid, "model": model}
    with open(os.path.join(adir, "manifest.json"), "w", encoding="utf-8") as f:
        json.dump(man, f, ensure_ascii=False, indent=1)
    print(len(man["music"]), len(man["sfx"]), len(man["voice"]))


if __name__ == "__main__":
    main()
