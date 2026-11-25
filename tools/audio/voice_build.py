#!/usr/bin/env python3
"""Build the 0.10 Russian founder voices (docs/AUDIO_BIBLE.md §13) — everything except the Higgsfield calls.

  voice_build.py lint     <lines.json> [cast.json]             check texts against the bible rules (exit 1 on errors)
  voice_build.py requests <lines.json> <cast.json> [heroes]    -> requests.json: qwen_audio_tts params per line
  voice_build.py finish   <raw_dir> <out_dir> [ids...]         raw/<hero>_<slot>.wav -> out/<hero>/<slot>.ogg
                                                               (trim, -14 LUFS, whispers -16, peak <= -1 dBFS, mono 44.1k)
  voice_build.py gate     <qa.jsonl>                           ASR gate: prints failing ids (exit 1 if any)
  voice_build.py manifest <lines.json> <cast.json> <jobs.tsv> <qa.jsonl> <out_dir>   -> out_dir/manifest.json

lines.json  {"<hero>": [{"slot", "text", "direction", "instr"}, ...]}     24 slots per hero (V10Voice.SLOTS)
cast.json   {"<hero>": {"name", "voice_id", "voice_type", "model", "base": "<English voice brief>"}}
jobs.tsv    id<TAB>job_id<TAB>url   (one row per take that went into the game; later rows win)
qa.jsonl    tools/audio/voice_qa.py output on the RAW takes
"""
import json, math, os, re, subprocess, sys

HEROES = ["mc", "rin", "hana", "yue", "nova"]
SLOTS = ["greet", "tap_head", "tap_hair", "tap_prop", "tap_acc", "tap_spam", "combo5", "combo10", "combo20",
         "priem", "tag", "win", "lose", "summon", "birthday", "comeback", "idle", "danger", "close1", "close2", "close3",
         "tut1", "tut2", "tut3"]
CLOSE = {"close1", "close2", "close3"}
LUFS, LUFS_CLOSE, PEAK_DB = -14.0, -16.0, -1.0
# the gate the shipped takes passed (Whisper large-v3-turbo + jonatasgrosman/wav2vec2-large-xlsr-53-russian)
GATE = {"p_ru": 0.90, "cer_whisper": 0.12, "cer_w2v": 0.30, "max_dur": 9.0, "min_lid_s": 3.0}
# UX_RULES §8 + v10-meta lint: no guilt, no purchases, no pressure; HEROINES red lines
BANNED = ["скуча", "одна", "обещал", "пропал", "забыл", "почему ты", "бросил", "вернись", "₽", "скидк", "успей",
          "последн", "только сегодня", "купи", "баннер", "акци", "цена",
          "учител", "ученик", "урок", "школ", "за парт", "куда смотришь", "колен", "грудь", "бёдр", "бедр",
          "вино", "пиво", "алкогол", "раздев", "бельё", "белье"]
ALLOW = ["однажды", "ещё одна", "одна чашка", "одна партия"]
MAX_CHARS = {"tag": 25, "combo5": 25, "combo10": 25, "combo20": 25}   # others <= 75 (AUDIO_BIBLE §13.4)


def lint(lines, cast=None):
    errs = []
    for h in HEROES:
        got = {l["slot"]: l for l in lines.get(h, [])}
        for s in SLOTS:
            if s not in got:
                errs.append(f"{h}:{s} missing")
                continue
            t = got[s]["text"]
            low = t.lower()
            for a in ALLOW:
                low = low.replace(a, "")
            for b in BANNED:
                if b in low:
                    errs.append(f"{h}:{s} banned «{b}»: {t}")
            if len(t) > MAX_CHARS.get(s, 75):
                errs.append(f"{h}:{s} too long ({len(t)}): {t}")
            if re.search(r"[A-Za-z~*]", t):
                errs.append(f"{h}:{s} latin or markup in a TTS line: {t}")
            li = got[s].get("instr", "").strip()
            # the direction shares qwen's 128 chars with the voice brief (instruction()); with the cast known, check
            # the real budget so nothing is cut silently
            room = 128 - len(base_of(cast[h], s)) - 1 if cast and h in cast else 128
            if len(li) > room:
                errs.append(f"{h}:{s} instr {len(li)} chars > {room} left after the voice brief")
            if s in CLOSE and "whisper" not in li.lower():
                errs.append(f"{h}:{s} close line must be whispered (instr)")
    return errs


def instruction(cast, line):
    """voice brief + line direction, <= 128 chars (qwen limit); the line direction is cut at a word if needed"""
    base, li = cast["base"].strip(), line.get("instr", "").strip()
    if line.get("slot") in CLOSE:   # a whisper must not inherit the loud brief ("bright, bouncy", "loud")
        base = "Adult woman, very close to the microphone."
    room = 128 - len(base) - 1
    if len(li) > room:   # keep whole words only: a word that ends exactly at the limit stays
        li = li[:room + 1].rsplit(" ", 1)[0].rstrip(",;")
    return (base + " " + li).strip()


def base_of(cast, slot):
    return "Adult woman, very close to the microphone." if slot in CLOSE else cast["base"].strip()


def requests(lines, cast, heroes):
    out, n = [], 0
    for h in heroes:
        c = cast[h]
        for l in lines[h]:
            out.append({"index": n, "id": f"{h}_{l['slot']}", "params": {
                "model": c.get("model", "qwen_audio_tts"), "prompt": l["text"], "voice_type": c.get("voice_type", "preset"),
                "voice_id": c["voice_id"], "language": "ru", "instruction": instruction(c, l),
                "format": "wav", "sample_rate": 44100}})
            n += 1
    return out


def ffmpeg_f32(path, sr):
    import numpy as np
    raw = subprocess.run(["ffmpeg", "-v", "quiet", "-i", path, "-f", "f32le", "-ac", "1", "-ar", str(sr), "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.float32).astype(np.float64)


def measure(path):
    import numpy as np, pyloudnorm
    sr = 44100
    y = ffmpeg_f32(path, sr)
    meter = pyloudnorm.Meter(sr, block_size=0.2 if len(y) < 0.5 * sr else 0.4)
    return {"dur": round(len(y) / sr, 2), "lufs": round(float(meter.integrated_loudness(y)), 1),
            "peak_db": round(float(20 * np.log10(np.max(np.abs(y)) + 1e-9)), 1)}


LIP_HZ = 30


def lip(path):
    """mouth-open envelope for V10Voice -> V10LiveRig.set_mouth_level: one digit 0..9 per 1/30 s"""
    import numpy as np
    sr = 16000
    y = ffmpeg_f32(path, sr)
    hop = sr // LIP_HZ
    n = len(y) // hop
    if n == 0:
        return ""
    rms = np.sqrt(np.mean(y[:n * hop].reshape(n, hop) ** 2, axis=1))
    ref = np.percentile(rms, 95) + 1e-9
    db = 20 * np.log10(rms / ref + 1e-9)
    lvl = np.clip((db + 30) / 30, 0, 1)          # -30 dB under the loud part = closed
    lvl = np.convolve(lvl, [0.25, 0.5, 0.25], mode="same")
    return "".join(str(int(round(v * 9))) for v in lvl)


def finish(raw_dir, out_dir, ids):
    import numpy as np, librosa, pyloudnorm
    sr = 44100
    files = sorted(f for f in os.listdir(raw_dir) if f.endswith((".wav", ".mp3")))
    res = {}
    for f in files:
        fid = f.rsplit(".", 1)[0]
        if ids and fid not in ids:
            continue
        hero, slot = fid.split("_", 1)
        y = ffmpeg_f32(os.path.join(raw_dir, f), sr)
        _, (a, b) = librosa.effects.trim(y, top_db=42, frame_length=1024, hop_length=128)
        a, b = max(0, a - int(0.03 * sr)), min(len(y), b + int(0.06 * sr))
        y = np.concatenate([y[a:b], np.zeros(int(0.15 * sr))])
        fade = int(0.008 * sr)
        y[:fade] *= np.linspace(0, 1, fade)
        target = LUFS_CLOSE if slot in CLOSE else LUFS
        meter = pyloudnorm.Meter(sr, block_size=0.2 if len(y) < 0.5 * sr else 0.4)
        os.makedirs(os.path.join(out_dir, hero), exist_ok=True)
        out = os.path.join(out_dir, hero, slot + ".ogg")
        y0 = y
        # Vorbis overshoots the limiter a little (up to ~1.4 dB on sharp consonants): start 0.8 dB under the ceiling,
        # and if the encoded file still peaks above it, limit harder and encode again
        for margin in (0.8, 1.6, 2.4, 3.2):
            y = y0
            lim = 10 ** ((PEAK_DB - margin) / 20)
            # gain to the target, then limit the peaks; a peaky voice (Hana, Nova) loses 1-2 LU in the limiter, so
            # repeat gain + limit until the loudness sits within 0.3 LU of the target (converges in 2-4 rounds)
            for _ in range(6):
                lufs = meter.integrated_loudness(y)
                if abs(lufs - target) <= 0.3 and float(np.max(np.abs(y))) <= lim:
                    break
                y = y * 10 ** ((target - lufs) / 20)
                if float(np.max(np.abs(y))) > lim:   # soft limiter: required gain, 10 ms min-hold, 5 ms average
                    from scipy.ndimage import minimum_filter1d, uniform_filter1d
                    need = np.minimum(1.0, lim / np.maximum(np.abs(y), 1e-9))
                    w = int(0.005 * sr)
                    y = np.clip(y * uniform_filter1d(minimum_filter1d(need, 2 * w), w), -lim, lim)
            pcm = (np.clip(y, -1, 1) * 32767).astype("<i2").tobytes()
            subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "s16le", "-ar", str(sr), "-ac", "1", "-i", "-",
                            "-c:a", "libvorbis", "-q:a", "5", out], input=pcm, check=True)
            res[fid] = measure(out)
            if res[fid].get("peak_db", 0) <= PEAK_DB + 0.05:
                break
        print(fid, res[fid], flush=True)
    return res


def read_qa(path):
    qa = {}
    for l in open(path, encoding="utf-8"):
        if l.strip():
            d = json.loads(l)
            qa[d["id"]] = d
    return qa


def cer_limits(text):
    # one wrong letter is always allowed: on a 7-letter shout («Скачано.», «На старт!») a single reduced vowel or an extra
    # soft sign is CER 0.14, which says nothing about the take; a dropped word (6 letters) still fails
    n = len(re.sub(r"[^а-яa-z0-9]", "", text.lower().replace("ё", "е"))) or 1
    one = math.ceil(1000.0 / n) / 1000.0      # voice_qa.py rounds CER to 3 decimals
    return max(GATE["cer_whisper"], one), max(GATE["cer_w2v"], one)


def gate_fail(d):
    why = []
    if d.get("error"):
        return [d["error"]]
    # a row without the script text (voice_qa.py --files) or without both CER values (--no-w2v) proves nothing:
    # the gate needs both transcripts scored against the script
    if not d.get("text", "").strip():
        return ["no script text in the QA row"]
    if d.get("cer_whisper") is None or d.get("cer_w2v") is None:
        return ["QA row lacks cer_whisper or cer_w2v (run voice_qa.py with the script text and the CTC model)"]
    # Whisper language ID is unreliable on 1-2 word shouts ("Двадцать! Ты — тайфун!" -> 0.12): when it is not sure,
    # a short line passes only if both transcripts match the script (both CER <= the Whisper limit).
    # Same rule as the V10VOICE selftest: (p_ru >= gate or both CER <= cer_whisper) and each CER under its own limit.
    short = d.get("active", d.get("dur", 9)) < GATE["min_lid_s"]
    lim_w, lim_v = cer_limits(d.get("text", ""))
    lid_ok = d.get("p_ru", 0) >= GATE["p_ru"]
    both_ok = max(d.get("cer_whisper", 1), d.get("cer_w2v", 1)) <= lim_w
    if short and not lid_ok and not both_ok:
        why.append(f"short line, p_ru {d.get('p_ru')}, CER {d.get('cer_whisper')}/{d.get('cer_w2v')}")
    if not short and not lid_ok:
        why.append(f"p_ru {d.get('p_ru')}")
    if d.get("cer_whisper", 1) > lim_w:
        why.append(f"cer_whisper {d.get('cer_whisper')}")
    if d.get("cer_w2v", 0) > lim_v:
        why.append(f"cer_w2v {d.get('cer_w2v')}")
    if d.get("dur", 0) > GATE["max_dur"]:
        why.append(f"dur {d.get('dur')}")
    return why


def manifest(lines, cast, jobs_tsv, qa_path, out_dir):
    jobs = {}
    for row in open(jobs_tsv, encoding="utf-8"):
        p = row.rstrip("\n").split("\t")
        if len(p) >= 2 and p[0] != "id":
            jobs[p[0]] = p[1]
    qa = read_qa(qa_path)
    m = {"version": 1, "lip_hz": LIP_HZ, "lufs": LUFS, "lufs_close": LUFS_CLOSE, "peak_db": PEAK_DB, "gate": dict(GATE, one_letter=True),
         "asr": "faster-whisper large-v3-turbo (language + forced-ru CER) + wav2vec2-large-xlsr-53-russian (CER)",
         "heroes": {}}
    for h in HEROES:
        c = cast[h]
        hl = {}
        for l in lines[h]:
            fid = f"{h}_{l['slot']}"
            q, f = qa.get(fid, {}), measure(os.path.join(out_dir, h, l["slot"] + ".ogg"))
            hl[l["slot"]] = {"text": l["text"], "file": f"{h}/{l['slot']}.ogg", "dur": f.get("dur", 0.0),
                             "lufs": f.get("lufs"), "peak_db": f.get("peak_db"), "job": jobs.get(fid, ""),
                             "instr": instruction(c, l), "lip": lip(os.path.join(out_dir, h, l["slot"] + ".ogg")), "p_ru": q.get("p_ru"), "cer_whisper": q.get("cer_whisper"),
                             "cer_w2v": q.get("cer_w2v"), "asr": q.get("whisper", "")}
        m["heroes"][h] = {"voice": c["name"], "voice_id": c["voice_id"], "voice_type": c.get("voice_type", "preset"),
                          "model": c.get("model", "qwen_audio_tts"), "language": "ru", "brief": c["base"], "lines": hl}
    with open(os.path.join(out_dir, "manifest.json"), "w", encoding="utf-8") as fh:
        json.dump(m, fh, ensure_ascii=False, indent=1)
        fh.write("\n")


def main():
    a = sys.argv[1:]
    if not a:
        sys.exit(__doc__)
    cmd = a[0]
    if cmd == "lint":
        errs = lint(json.load(open(a[1], encoding="utf-8")), json.load(open(a[2], encoding="utf-8")) if len(a) > 2 else None)
        print("\n".join(errs) or "LINT OK")
        sys.exit(1 if errs else 0)
    if cmd == "requests":
        lines, cast = json.load(open(a[1], encoding="utf-8")), json.load(open(a[2], encoding="utf-8"))
        heroes = a[3].split(",") if len(a) > 3 else HEROES
        json.dump(requests(lines, cast, heroes), sys.stdout, ensure_ascii=False, indent=1)
        return
    if cmd == "finish":
        finish(a[1], a[2], set(a[3:]))
        return
    if cmd == "gate":
        bad = {k: gate_fail(v) for k, v in read_qa(a[1]).items()}
        bad = {k: v for k, v in bad.items() if v}
        for k, v in sorted(bad.items()):
            print(k, "; ".join(v))
        print(f"GATE {'FAIL' if bad else 'OK'} {len(bad)} failing")
        sys.exit(1 if bad else 0)
    if cmd == "manifest":
        manifest(json.load(open(a[1], encoding="utf-8")), json.load(open(a[2], encoding="utf-8")), a[3], a[4], a[5])
        return
    sys.exit(__doc__)


if __name__ == "__main__":
    main()
