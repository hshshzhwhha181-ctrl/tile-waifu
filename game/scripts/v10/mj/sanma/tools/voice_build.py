#!/usr/bin/env python3
"""Лунный стол: реплики хозяйки (seed_audio, клон голоса Юэ из 0.7) -> выбор лучшего дубля по распознаванию,
обрезка тишины, -14 LUFS, лимитер -1.5 dBFS, Ogg Vorbis + manifest.json.

  python3 voice_build.py <raw_dir> <out_dir> <jobs.txt>

raw_dir: <line>.mp3 и дубли <line>b.mp3; jobs.txt: строки "<idx> <name> <job_id>".
Тексты берутся из LINES ниже (совпадают с V10MjSanmaText.LINES).
"""
import difflib
import json
import os
import re
import subprocess
import sys

LINES = {
    "kita_1": ("Север — луне.", "北を、お月さまに。"),
    "kita_2": ("Спасибо. Света стало больше.", "ありがとう。光が増えたわ。"),
    "kita_3": ("Северный ветер принят.", "北風、受け取ったわ。"),
    "kita_4": ("Тяни ещё одну.", "ふふ、もう一枚どうぞ。"),
    "kita_5": ("Луна улыбнулась.", "月が、微笑んだ。"),
    "host_x2": ("Сегодня ×2. Держитесь, обе.", "今夜は二倍。お二人とも、覚悟して。"),
    "host_x3": ("Полнолуние. Играю на ×3.", "満月よ。三倍で行くわ。"),
}
TARGET = -14.0


def run(cmd):
    return subprocess.run(cmd, capture_output=True, text=True, check=True)


def loud(path):
    r = subprocess.run(["ffmpeg", "-hide_banner", "-nostats", "-i", path, "-af",
                        "loudnorm=I=-14:TP=-1.5:LRA=11:print_format=json", "-f", "null", "-"], capture_output=True, text=True)
    m = re.search(r"\{[^{}]*\"input_i\"[^{}]*\}", r.stderr, re.S)
    return json.loads(m.group(0)) if m else None


def norm(s):
    return re.sub(r"[、。…！？!?\s・]", "", s)


def main():
    raw, out, jobs_p = sys.argv[1:4]
    os.makedirs(out, exist_ok=True)
    jobs = {}
    for ln in open(jobs_p):
        p = ln.split()
        if len(p) >= 3:
            jobs[p[1]] = p[2]
    from faster_whisper import WhisperModel
    model = WhisperModel("small", device="cpu", compute_type="int8")
    man = {}
    for name, (ru, jp) in LINES.items():
        best = None
        for take in [name, name + "b"]:
            mp3 = os.path.join(raw, take + ".mp3")
            if not os.path.exists(mp3):
                continue
            pcm = subprocess.run(["ffmpeg", "-v", "error", "-i", mp3, "-ar", "16000", "-ac", "1", "-f", "f32le", "-"],
                                 capture_output=True, check=True).stdout
            import numpy as np
            segs, _ = model.transcribe(np.frombuffer(pcm, dtype=np.float32), language="ja", beam_size=5)
            txt = "".join(s.text for s in segs).strip()
            sim = difflib.SequenceMatcher(None, norm(txt), norm(jp)).ratio()
            dur = float(run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", mp3]).stdout)
            print(f"{take:10s} sim={sim:.2f} dur={dur:.2f} asr={txt}")
            score = sim - 0.02 * max(0.0, dur - 3.5)
            if best is None or score > best[0]:
                best = (score, take, txt, sim)
        _, take, txt, sim = best
        mp3 = os.path.join(raw, take + ".mp3")
        tmp = os.path.join(raw, name + ".trim.wav")
        run(["ffmpeg", "-y", "-v", "error", "-i", mp3, "-af",
             "silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.03,areverse,"
             "silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.08,areverse",
             "-ar", "44100", "-ac", "1", tmp])
        m = loud(tmp)
        gain = TARGET - float(m["input_i"])
        ogg = os.path.join(out, name + ".ogg")
        run(["ffmpeg", "-y", "-v", "error", "-i", tmp, "-af",
             "volume=%.2fdB,alimiter=limit=0.84:attack=2:release=40:level=false,afade=t=in:d=0.02" % gain,
             "-ar", "44100", "-ac", "1", "-c:a", "libvorbis", "-q:a", "5", ogg])
        os.remove(tmp)
        m2 = loud(ogg)
        dur = float(run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", ogg]).stdout)
        man[name] = {"file": name + ".ogg", "take": take, "job": jobs.get(take, "?"), "model": "seed_audio",
                     "ref": "клон голоса Юэ из 0.7 (assets/voice/yue_*.mp3)", "ru": ru, "jp": jp, "asr": txt,
                     "sim": round(sim, 2), "len": round(dur, 3), "lufs": float(m2["input_i"]), "peak": float(m2["input_tp"])}
        print("->", name, take, round(sim, 2))
    json.dump(man, open(os.path.join(out, "manifest.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main()
