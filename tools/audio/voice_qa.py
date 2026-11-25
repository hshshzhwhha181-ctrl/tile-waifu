#!/usr/bin/env python3
"""Voice QA for Russian TTS lines (Tile Waifu AUDIO_BIBLE §13).

usage: voice_qa.py [--no-w2v] [--model large-v3-turbo] (<tsv with id,text,file> | --files f1 f2 ...) > out.jsonl
For each file: Whisper language detection (p of ru), Whisper transcript (forced ru) and its CER against the script,
an independent Russian-only CTC model (wav2vec2 xlsr-53 ru) transcript and CER (more sensitive to accent),
duration, active speech time, speech rate (chars/s), F0 median / p10 / p90 (YIN), integrated LUFS, sample peak.
"""
import json, re, subprocess, sys, unicodedata
import numpy as np

def load(p, sr=16000):
    raw = subprocess.run(["ffmpeg", "-v", "quiet", "-i", p, "-f", "f32le", "-ac", "1", "-ar", str(sr), "-"],
                         capture_output=True).stdout
    return np.frombuffer(raw, np.float32).astype(np.float32)

def spell_numbers(t):
    # Whisper writes "Триста" as "300"; spell digits back in Russian before scoring
    try:
        from num2words import num2words
    except ImportError:
        return t
    return re.sub(r"\d+", lambda m: " " + num2words(int(m.group()), lang="ru") + " ", t)

def norm(t):
    t = spell_numbers(t).lower().replace("ё", "е")
    t = unicodedata.normalize("NFC", t)
    t = re.sub(r"[^а-яa-z0-9 ]+", " ", t)
    return re.sub(r"\s+", " ", t).strip()

def cer(ref, hyp):
    r, h = norm(ref).replace(" ", ""), norm(hyp).replace(" ", "")
    if not r:
        return 1.0
    d = list(range(len(h) + 1))
    for i in range(1, len(r) + 1):
        prev, d[0] = d[0], i
        for j in range(1, len(h) + 1):
            cur = d[j]
            d[j] = min(d[j] + 1, d[j - 1] + 1, prev + (r[i - 1] != h[j - 1]))
            prev = cur
    return d[len(h)] / len(r)

def main():
    a = sys.argv[1:]
    use_w2v = "--no-w2v" not in a
    a = [x for x in a if x != "--no-w2v"]
    model = "large-v3-turbo"
    if a and a[0] == "--model":
        model, a = a[1], a[2:]
    items = []
    if a and a[0] == "--files":
        items = [{"id": f.split("/")[-1].rsplit(".", 1)[0], "text": "", "file": f} for f in a[1:]]
    else:
        import csv
        for row in csv.DictReader(open(a[0], encoding="utf-8"), delimiter="\t"):
            items.append(row)
    from faster_whisper import WhisperModel
    wm = WhisperModel(model, device="cpu", compute_type="int8", cpu_threads=4)
    if use_w2v:
        import torch
        from transformers import Wav2Vec2ForCTC, Wav2Vec2Processor
        torch.set_num_threads(4)
        name = "jonatasgrosman/wav2vec2-large-xlsr-53-russian"
        proc, w2v = Wav2Vec2Processor.from_pretrained(name), Wav2Vec2ForCTC.from_pretrained(name).eval()
    import librosa, pyloudnorm
    for it in items:
        p = it["file"]
        y = load(p)
        if len(y) < 1600:
            print(json.dumps({"id": it["id"], "file": p, "error": "empty"}, ensure_ascii=False), flush=True)
            continue
        lang, lp, allp = wm.detect_language(y)
        p_ru = dict(allp).get("ru", 0.0)
        segs, _ = wm.transcribe(y, beam_size=5, language="ru", condition_on_previous_text=False)
        wt = " ".join(s.text.strip() for s in segs)
        out = {"id": it["id"], "file": p, "text": it.get("text", ""), "lang": lang, "p_ru": round(float(p_ru), 3),
               "whisper": wt}
        if use_w2v:
            import torch
            with torch.no_grad():
                iv = proc(y, sampling_rate=16000, return_tensors="pt").input_values
                ids = torch.argmax(w2v(iv).logits, dim=-1)
            out["w2v"] = proc.batch_decode(ids)[0]
        if it.get("text"):
            out["cer_whisper"] = round(cer(it["text"], wt), 3)
            if use_w2v:
                out["cer_w2v"] = round(cer(it["text"], out["w2v"]), 3)
        dur = len(y) / 16000
        iv = librosa.effects.split(y, top_db=35)
        act = float(sum(e - s for s, e in iv)) / 16000
        f0 = librosa.yin(y, fmin=120, fmax=600, sr=16000, frame_length=1024)
        rms = librosa.feature.rms(y=y, frame_length=1024, hop_length=256)[0]
        n = min(len(f0), len(rms))
        voiced = f0[:n][rms[:n] > 0.25 * np.percentile(rms[:n], 95)]
        out.update({"dur": round(dur, 2), "active": round(act, 2)})
        if len(voiced):
            out.update({"f0_med": round(float(np.median(voiced)), 1), "f0_p10": round(float(np.percentile(voiced, 10)), 1),
                        "f0_p90": round(float(np.percentile(voiced, 90)), 1)})
        if it.get("text"):
            out["rate"] = round(len(norm(it["text"]).replace(" ", "")) / max(act, 0.1), 1)
        y44 = load(p, 44100)
        try:
            out["lufs"] = round(float(pyloudnorm.Meter(44100).integrated_loudness(y44.astype(np.float64))), 1)
        except Exception:
            pass
        out["peak_db"] = round(float(20 * np.log10(np.max(np.abs(y44)) + 1e-9)), 1)
        print(json.dumps(out, ensure_ascii=False), flush=True)

if __name__ == "__main__":
    main()
