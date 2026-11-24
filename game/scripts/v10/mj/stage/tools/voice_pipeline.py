#!/usr/bin/env python3
"""Lane `stage` voice pipeline: Higgsfield seed_audio mp3 -> trimmed, -14 LUFS Ogg Vorbis + manifest + QA.

  python3 voice_pipeline.py <items.json> <urls.txt> <raw_dir> <out_dir> [--asr]

items.json: [{name, hero, ru, jp}, ...] in generation order (index = position); urls.txt: lines "<index> <job|x> <url>"
(index -1/-2... = extra lines named in the 4th column). Writes <out_dir>/<name>.ogg and <out_dir>/manifest.json
({name: {file, len, lufs, peak, job, ru, jp, asr?, sim?}}). --asr: faster-whisper small (ja) transcript and a
character similarity with the script text (QA: < 0.5 = listen again / regenerate).
"""
import difflib
import json
import os
import re
import subprocess
import sys
import urllib.request

TARGET = -14.0


def run(cmd):
    return subprocess.run(cmd, capture_output=True, text=True, check=True)


def loud(path):
    r = subprocess.run(["ffmpeg", "-hide_banner", "-nostats", "-i", path, "-af", "loudnorm=I=-14:TP=-1.5:LRA=11:print_format=json",
                        "-f", "null", "-"], capture_output=True, text=True)
    m = re.search(r"\{[^{}]*\"input_i\"[^{}]*\}", r.stderr, re.S)
    return json.loads(m.group(0)) if m else None


def main():
    items_p, urls_p, raw, out = sys.argv[1:5]
    asr = "--asr" in sys.argv
    items = json.load(open(items_p, encoding="utf-8"))
    os.makedirs(raw, exist_ok=True)
    os.makedirs(out, exist_ok=True)
    jobs = {}
    for line in open(urls_p):
        p = line.split()
        if len(p) < 3:
            continue
        idx = int(p[0])
        name = p[3] if len(p) > 3 else items[idx]["name"]
        jobs[name] = (p[1], p[2])
    by_name = {i["name"]: i for i in items}
    man_p = os.path.join(out, "manifest.json")
    man = json.load(open(man_p, encoding="utf-8")) if os.path.exists(man_p) else {}
    model = None
    for name, (job, url) in sorted(jobs.items()):
        it = by_name.get(name)
        if it is None:
            continue
        mp3 = os.path.join(raw, name + ".mp3")
        if not os.path.exists(mp3):
            urllib.request.urlretrieve(url, mp3)
        ogg = os.path.join(out, name + ".ogg")
        if name not in man or not os.path.exists(ogg):
            # trim leading/trailing silence (-45 dB; a cut that leaves < 0.3 s keeps the original), then a plain gain
            # to -14 LUFS integrated and a soft limiter at -1.5 dBFS (loudnorm's dynamic mode pumps on 1-2 s lines)
            tmp = os.path.join(raw, name + ".trim.wav")
            run(["ffmpeg", "-y", "-v", "error", "-i", mp3, "-af",
                 "silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.03,areverse,"
                 "silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.08,areverse",
                 "-ar", "44100", "-ac", "1", tmp])
            m = loud(tmp)
            tdur = float(run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", tmp]).stdout or 0)
            if m is None or m["input_i"] in ("-inf", "inf") or tdur < 0.3:
                run(["ffmpeg", "-y", "-v", "error", "-i", mp3, "-ar", "44100", "-ac", "1", tmp])
                m = loud(tmp)
            gain = TARGET - float(m["input_i"])
            af = "volume=%.2fdB,alimiter=limit=0.84:attack=2:release=40:level=false,afade=t=in:d=0.02" % gain
            run(["ffmpeg", "-y", "-v", "error", "-i", tmp, "-af", af, "-ar", "44100", "-ac", "1", "-c:a", "libvorbis",
                 "-q:a", "5", ogg])
            os.remove(tmp)
        dur = float(run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", ogg]).stdout)
        m2 = loud(ogg)
        rec = {"file": name + ".ogg", "len": round(dur, 3), "lufs": float(m2["input_i"]), "peak": float(m2["input_tp"]),
               "job": job, "model": "seed_audio", "ru": it["ru"], "jp": it["jp"], "ref": "v10-audio clone of the 0.7 voice"}
        if asr:
            if model is None:
                import numpy as np
                from faster_whisper import WhisperModel
                model = WhisperModel("small", device="cpu", compute_type="int8")
            import numpy as np
            raw16 = subprocess.run(["ffmpeg", "-v", "error", "-i", ogg, "-f", "f32le", "-ac", "1", "-ar", "16000", "-"],
                                   capture_output=True, check=True).stdout
            segs, info = model.transcribe(np.frombuffer(raw16, np.float32), language="ja", beam_size=3)
            txt = "".join(s.text.strip() for s in segs)
            norm = lambda s: re.sub(r"[\s、。！？!?…〜~・]", "", s)
            rec["asr"] = txt
            rec["sim"] = round(difflib.SequenceMatcher(None, norm(txt), norm(it["jp"])).ratio(), 2)
        man[name] = rec
        print(name, rec["len"], rec["lufs"], rec.get("sim", ""), rec.get("asr", ""), flush=True)
    json.dump(man, open(man_p, "w", encoding="utf-8"), ensure_ascii=False, indent=1, sort_keys=True)


if __name__ == "__main__":
    main()
