#!/usr/bin/env python3
"""v10/mj/look: mode music loops (docs/MODES.md §6.5) from elevenlabs_music_v2_5 45 s takes.
usage: build_music.py <raw_dir> <game_dir>
  m_<mode>.mp3 → assets/v10/mj/look/music/<mode>.ogg : a seamless loop (3 s equal-power crossfade of the tail into
  the head, cut to whole bars of the detected tempo), −16 LUFS integrated (UX §7.4), peaks ≤ −1 dBFS.
  riichi additionally gets two layers that play in sync with it (V10MjMusic.set_tension):
    riichi.ogg     base   = the take low-passed at 1.4 kHz (calm table)
    riichi_r1.ogg  layer1 = the complement (take − base): base + r1 = the full take («someone declared riichi»)
    riichi_r2.ogg  layer2 = a synthesised taiko-and-heartbeat pulse locked to the take's beat («two riichi»)"""
import sys, os, json, subprocess, wave
import numpy as np

SR = 44100
raw, game = sys.argv[1], sys.argv[2]
OUT = os.path.join(game, "assets/v10/mj/look/music")
os.makedirs(OUT, exist_ok=True)
info = {}


def load(p):
    b = subprocess.run(["ffmpeg", "-v", "error", "-i", p, "-ac", "2", "-ar", str(SR), "-f", "f32le", "-"],
                       capture_output=True, check=True).stdout
    return np.frombuffer(b, dtype=np.float32).reshape(-1, 2).astype(np.float64)


def lufs(path):
    r = subprocess.run(["ffmpeg", "-i", path, "-af", "ebur128", "-f", "null", "-"], capture_output=True, text=True).stderr
    v = [l for l in r.splitlines() if l.strip().startswith("I:")]
    return float(v[-1].split()[1]) if v else -99.0


def tempo(x):
    mono = x.mean(1)
    hop = 512
    n = len(mono) // hop
    e = np.array([np.sum(mono[i * hop:(i + 1) * hop] ** 2) for i in range(n)])
    on = np.maximum(np.diff(np.log(e + 1e-9)), 0)
    on -= on.mean()
    ac = np.correlate(on, on, "full")[len(on) - 1:]
    fps = SR / hop
    lo, hi = int(fps * 60 / 140), int(fps * 60 / 66)
    lag = lo + int(np.argmax(ac[lo:hi]))
    bpm = 60 * fps / lag
    # beat phase: offset (in hops) maximising onset energy on the beat grid
    best, ph = -1e9, 0
    for o in range(lag):
        s = on[o::lag].sum()
        if s > best:
            best, ph = s, o
    return bpm, ph * hop / SR


def onepole_lp(x, fc):
    a = np.exp(-2 * np.pi * fc / SR)
    y = np.empty_like(x)
    s = np.zeros(x.shape[1])
    for i in range(len(x)):
        s = (1 - a) * x[i] + a * s
        y[i] = s
    return y


def loopify(x, bpm, xf_s=3.0):
    beat = 60.0 / bpm
    total = len(x) / SR
    bars = int((total - xf_s) / (beat * 4))
    L = int(bars * 4 * beat * SR)
    xf = int(xf_s * SR)
    body = x[:L].copy()
    tail = x[L:L + xf]
    if len(tail) < xf:
        tail = np.pad(tail, ((0, xf - len(tail)), (0, 0)))
    w = np.linspace(0, 1, xf)[:, None]
    body[:xf] = body[:xf] * np.sqrt(w) + tail * np.sqrt(1 - w)
    return body, bars


def write_ogg(x, name, target=-16.0):
    tmp = os.path.join(OUT, "_" + name + ".wav")
    pk = np.max(np.abs(x)) + 1e-12
    x = x * (0.5 / pk)
    with wave.open(tmp, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype(np.int16).tobytes())
    l = lufs(tmp)
    g = 10 ** ((target - l) / 20)
    if np.max(np.abs(x * g)) > 10 ** (-1 / 20):
        g = 10 ** (-1 / 20) / np.max(np.abs(x))
    x = x * g
    with wave.open(tmp, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype(np.int16).tobytes())
    out = os.path.join(OUT, name + ".ogg")
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", tmp, "-c:a", "libvorbis", "-q:a", "6", out], check=True)
    os.remove(tmp)
    return lufs(out), g


for mode in ["classic", "triples", "connect", "cube", "riichi", "raid"]:
    x = load(os.path.join(raw, "m_%s.mp3" % mode))
    bpm, phase = tempo(x)
    loop, bars = loopify(x, bpm)
    rec = {"bpm": round(bpm, 1), "bars": bars, "len_s": round(len(loop) / SR, 2)}
    if mode != "riichi":
        rec["lufs"], _ = write_ogg(loop, mode)
    else:
        base = onepole_lp(onepole_lp(loop, 1400.0), 1400.0)
        r1 = loop - base
        # one gain for both so base + r1 == the full take at the same level
        pk = np.max(np.abs(loop)) + 1e-12
        tmpn = "riichi_full_probe"
        full_l, g = write_ogg(loop, tmpn)
        os.remove(os.path.join(OUT, tmpn + ".ogg"))
        for nm, sig in [("riichi", base), ("riichi_r1", r1)]:
            y = sig * (0.5 / pk) * g
            tmp = os.path.join(OUT, "_" + nm + ".wav")
            with wave.open(tmp, "wb") as w:
                w.setnchannels(2)
                w.setsampwidth(2)
                w.setframerate(SR)
                w.writeframes((np.clip(y, -1, 1) * 32767).astype(np.int16).tobytes())
            subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", tmp, "-c:a", "libvorbis", "-q:a", "6",
                            os.path.join(OUT, nm + ".ogg")], check=True)
            os.remove(tmp)
        # layer 2: taiko on 1 and 3, heartbeat «lub-dub» on 2 and 4, locked to the detected grid
        n = len(loop)
        t = np.arange(n) / SR
        beat = 60.0 / bpm
        y = np.zeros(n)
        k = 0
        bt = phase % beat
        while bt < n / SR:
            i0 = int(bt * SR)
            m = min(n - i0, int(0.6 * SR))
            tt = np.arange(m) / SR
            if k % 2 == 0:
                hit = np.sin(2 * np.pi * 62 * tt * (1 - 0.35 * tt)) * np.exp(-tt / 0.16)
                hit += np.random.default_rng(k).standard_normal(m) * np.exp(-tt / 0.012) * 0.12
                y[i0:i0 + m] += hit * 0.9
            else:
                for dt, a in [(0.0, 0.5), (0.16, 0.35)]:
                    j0 = i0 + int(dt * SR)
                    mm = min(n - j0, int(0.25 * SR))
                    if mm <= 0:
                        continue
                    t2 = np.arange(mm) / SR
                    y[j0:j0 + mm] += np.sin(2 * np.pi * 48 * t2) * np.exp(-t2 / 0.07) * a
            bt += beat
            k += 1
        st = np.stack([y, y], 1)
        lay_pk = np.max(np.abs(st)) + 1e-12
        st = st * (10 ** (-9 / 20) / lay_pk)
        tmp = os.path.join(OUT, "_riichi_r2.wav")
        with wave.open(tmp, "wb") as w:
            w.setnchannels(2)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes((np.clip(st, -1, 1) * 32767).astype(np.int16).tobytes())
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", tmp, "-c:a", "libvorbis", "-q:a", "5",
                        os.path.join(OUT, "riichi_r2.ogg")], check=True)
        os.remove(tmp)
        rec["lufs_full"] = full_l
        rec["beat_phase_s"] = round(phase, 3)
    info[mode] = rec
    print(mode, rec)
with open(os.path.join(OUT, "music.json"), "w") as f:
    json.dump(info, f, indent=1)
