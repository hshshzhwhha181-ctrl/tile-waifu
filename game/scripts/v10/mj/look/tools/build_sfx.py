#!/usr/bin/env python3
"""v10/mj/look: build the ASMR bank (assets/v10/mj/look/sfx/*.wav, amb/*.ogg, manifest.json).
usage: build_sfx.py <raw_dir> <game_dir>
Sources (Higgsfield mirelo_text_to_audio, see README): one-hit clips one_<mat>_<n>.mp3, multi-hit clips
s_clack_<mat>.mp3, s_place.mp3, s_stick.mp3, s_pluck.mp3 (a guzheng note), a_<rain|stream|bamboo>.mp3.
Everything a model could not record cleanly is synthesised here, deterministically (seeded):
pair = two clacks of the material 70–95 ms apart; triple = 3 pentatonic notes from the guzheng pluck, root by suit;
gong, thread, rotate, pick, felt = additive / filtered-noise synthesis layered with recorded hits.
Every one-shot: high-passed, noise-gated, 2 ms fade-in, tail fade, peak normalised to −7 dBFS (UX §7.4: ≤ −6)."""
import sys, os, json, subprocess, wave
import numpy as np

SR = 44100
PEAK = -7.0
raw, game = sys.argv[1], sys.argv[2]
OUT = os.path.join(game, "assets/v10/mj/look/sfx")
AMB = os.path.join(game, "assets/v10/mj/look/amb")
os.makedirs(OUT, exist_ok=True)
os.makedirs(AMB, exist_ok=True)
rng = np.random.default_rng(20261124)
manifest = {"peak_dbfs": {}, "variants": {}, "sources": {}}


def load(name):
    p = os.path.join(raw, name)
    b = subprocess.run(["ffmpeg", "-v", "error", "-i", p, "-ac", "1", "-ar", str(SR), "-f", "f32le", "-"],
                       capture_output=True, check=True).stdout
    return np.frombuffer(b, dtype=np.float32).astype(np.float64)


def onepole_lp(x, fc):
    a = np.exp(-2 * np.pi * fc / SR)
    y = np.empty_like(x)
    s = 0.0
    for i, v in enumerate(x):
        s = (1 - a) * v + a * s
        y[i] = s
    return y


def hp(x, fc=50.0):
    return x - onepole_lp(x, fc)


def bandpass(x, lo, hi):
    return onepole_lp(hp(x, lo), hi)


def env_db(x, hop=220):
    n = max(1, len(x) // hop)
    e = np.array([np.sqrt(np.mean(x[i * hop:(i + 1) * hop] ** 2) + 1e-14) for i in range(n)])
    return 20 * np.log10(e)


def gate(x, depth=42.0):
    """soft noise gate relative to the clip's own peak envelope"""
    hop = 110
    e = env_db(x, hop)
    pk = e.max()
    g = np.clip((e - (pk - depth)) / 12.0, 0, 1)
    # smooth and hold
    g = np.maximum.accumulate(g[::-1])[::-1] * 0 + g
    gi = np.interp(np.arange(len(x)), np.arange(len(g)) * hop + hop / 2, g)
    gi = onepole_lp(gi, 40.0)
    return x * np.clip(gi * 1.15, 0, 1)


def hit_at(x, onset_thr=30.0, length=0.35, skip=0.0):
    """the first transient after `skip` seconds: from 3 ms before it, `length` seconds long"""
    hop = 110
    e = env_db(x, hop)
    pk = e.max()
    start = int(skip * SR / hop)
    idx = np.where(e[start:] > pk - onset_thr)[0]
    i = (idx[0] + start) if len(idx) else 0
    a = max(0, i * hop - int(0.003 * SR))
    return x[a:a + int(length * SR)].copy()


def level(y, target=-31.0, peak=PEAK):
    """even out loudness across variants: soft-saturate spiky hits until their RMS nears the target"""
    for drive in [1.0, 1.6, 2.5, 4.0, 6.0]:
        z = np.tanh(drive * y / (np.max(np.abs(y)) + 1e-12))
        z = z * (10 ** (peak / 20) / (np.max(np.abs(z)) + 1e-12))
        r = 20 * np.log10(np.sqrt(np.mean(z[:int(0.12 * SR)] ** 2)) + 1e-12)
        if r >= target - 2.5:
            break
    if r > target + 2.5:
        # too loud for its family: pull it down (its peak only gets further below −6 dBFS)
        z = z * 10 ** ((target + 1.5 - r) / 20)
    return z


def finish(y, fade=0.04, peak=PEAK, lv=None):
    y = hp(y, 45.0)
    n = len(y)
    fi = int(0.002 * SR)
    y[:fi] *= np.linspace(0, 1, fi)
    fo = min(int(fade * SR), n // 2)
    y[-fo:] *= np.linspace(1, 0, fo) ** 2
    m = np.max(np.abs(y)) + 1e-12
    y = y * (10 ** (peak / 20) / m)
    if lv is not None:
        y = level(y, lv, peak)
        y[-fo:] *= np.linspace(1, 0, fo) ** 2
    return y


def resample(x, ratio):
    """pitch * ratio (duration / ratio)"""
    n = int(len(x) / ratio)
    return np.interp(np.arange(n) * ratio, np.arange(len(x)), x)


def save(key, n, y, src):
    y = np.clip(y, -1, 1)
    p = os.path.join(OUT, "%s_%d.wav" % (key, n))
    with wave.open(p, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((y * 32767).astype(np.int16).tobytes())
    manifest["peak_dbfs"]["%s_%d" % (key, n)] = round(float(20 * np.log10(np.max(np.abs(y)) + 1e-12)), 2)
    manifest["variants"][key] = max(manifest["variants"].get(key, 0), n)
    manifest["sources"]["%s_%d" % (key, n)] = src


def segments(x, thr=30.0, gap=0.08, min_len=0.025):
    hop = 110
    e = env_db(x, hop)
    pk = e.max()
    on = e > pk - thr
    out = []
    i = 0
    g = int(gap * SR / hop)
    while i < len(on):
        if on[i]:
            last = i
            j = i
            while j < len(on) and j - last < g:
                if on[j]:
                    last = j
                j += 1
            if (last - i) * hop / SR >= min_len or e[i:last + 1].max() > pk - 12:
                out.append((i * hop, last * hop, float(e[i:last + 1].max())))
            i = j
        else:
            i += 1
    return out


def multi_hits(name, length, want, thr=30.0):
    x = load(name)
    segs = segments(x, thr)
    segs = sorted(segs, key=lambda s: -s[2])[:want]
    segs = sorted(segs, key=lambda s: s[0])
    return [x[max(0, a - int(0.003 * SR)):a + int(length * SR)].copy() for a, b, pk in segs]


# ── clacks: six per material ───────────────────────────────────────────────────────────────────────────────────
clacks = {}
SRC = {
    "porcelain": [("one_porcelain_1.mp3", 0), ("one_porcelain_3.mp3", 0), ("one_porcelain_4.mp3", 0),
                  ("one_porcelain_5.mp3", 0), ("multi:s_clack_porcelain.mp3", 2)],
    "jade": [("one_jade_1.mp3", 0), ("one_jade_2.mp3", 0), ("multi:one_jade_3.mp3", 3)],
    "bone": [("multi:s_clack_bone.mp3", 6)],
    "ice": [("multi:s_clack_ice.mp3", 6)],
    "amber": [("one_amber_1.mp3", 0), ("one_amber_3.mp3", 0), ("one_amber_4.mp3", 0), ("one_amber_5.mp3", 0)],
    "lacquer": [("one_lacquer_1.mp3", 0), ("one_lacquer_2.mp3", 0), ("multi:s_clack_lacquer.mp3", 4)],
}
LEN = {"porcelain": 0.32, "jade": 0.3, "bone": 0.22, "ice": 0.34, "amber": 0.26, "lacquer": 0.3}
for mat, srcs in SRC.items():
    hits = []
    for name, k in srcs:
        if name.startswith("multi:"):
            for h in multi_hits(name[6:], LEN[mat], k):
                hits.append((h, name[6:]))
        else:
            hits.append((hit_at(load(name), length=LEN[mat]), name))
    hits = [(finish(gate(h), lv=-30.0), s) for h, s in hits if len(h) > 0.05 * SR]
    # fewer than 6 recordings: derive the rest (±4–6% pitch + a slightly darker or brighter body)
    base = list(hits)
    k = 0
    while len(hits) < 6:
        h, s = base[k % len(base)]
        r = [0.95, 1.05, 0.93, 1.06][k % 4]
        y = resample(h, r)
        y = y * 0.7 + (onepole_lp(y, 2500) if r < 1 else hp(y, 900)) * 0.3
        hits.append((finish(y, lv=-30.0), s + " (derived %.2f)" % r))
        k += 1
    hits = hits[:6]
    clacks[mat] = [h for h, s in hits]
    for i, (h, s) in enumerate(hits):
        save("clack_" + mat, i + 1, h, s)

# ── pair: two clacks of the same material, 70–95 ms apart (the «клак-клак») ─────────────────────────────────────
for mat, cs in clacks.items():
    for i in range(4):
        a = cs[i % len(cs)]
        b = cs[(i + 2) % len(cs)]
        d = int((0.07 + 0.008 * i) * SR)
        y = np.zeros(max(len(a), d + len(b)))
        y[:len(a)] += a
        y[d:d + len(b)] += resample(b, 0.985)[:len(y) - d] * 0.85
        save("pair_" + mat, i + 1, finish(y, lv=-29.0), "clack %d + clack %d" % (i % 6 + 1, (i + 2) % 6 + 1))

# ── place: recorded seats into a tray slot ─────────────────────────────────────────────────────────────────────
pl = multi_hits("s_place.mp3", 0.3, 6)
pl = [finish(gate(h), lv=-28.0) for h in pl if len(h) > 0.05 * SR]
k = 0
while len(pl) < 6:
    pl.append(finish(resample(pl[k], [0.96, 1.04][k % 2])))
    k += 1
for i, h in enumerate(pl[:6]):
    save("place", i + 1, h, "s_place.mp3")

# ── stick: riichi stick on the cloth ───────────────────────────────────────────────────────────────────────────
st = [finish(gate(h), lv=-30.0) for h in multi_hits("s_stick.mp3", 0.22, 6) if len(h) > 0.04 * SR]
k = 0
while len(st) < 4:
    st.append(finish(resample(st[k], 1.04)))
    k += 1
for i, h in enumerate(st[:4]):
    save("stick", i + 1, h, "s_stick.mp3")


def noise(n):
    return rng.standard_normal(n)


def adsr(n, a, d_tau):
    t = np.arange(n) / SR
    e = np.minimum(t / max(a, 1e-4), 1.0) * np.exp(-np.maximum(t - a, 0) / d_tau)
    return e


# ── pick: soft lift — a short felt brush and a tiny tick ───────────────────────────────────────────────────────
for i in range(6):
    n = int(0.16 * SR)
    sw = bandpass(noise(n), 1200 + 300 * i, 5200) * adsr(n, 0.018 + 0.003 * i, 0.035)
    tick = pl[i % len(pl)][:n] if len(pl[i % len(pl)]) >= n else np.pad(pl[i % len(pl)], (0, n - len(pl[i % len(pl)])))
    y = sw * 0.6 + onepole_lp(tick, 3000) * 0.18
    save("pick", i + 1, finish(y, 0.05), "synth brush + place tick")

# ── felt: tile on the cloth — low thump + damped place hit ─────────────────────────────────────────────────────
for i in range(6):
    n = int(0.28 * SR)
    t = np.arange(n) / SR
    f0 = 92 + 9 * i
    thump = np.sin(2 * np.pi * f0 * t * (1 - 0.25 * t)) * adsr(n, 0.003, 0.045)
    h = pl[(i + 1) % len(pl)]
    h = np.pad(h, (0, max(0, n - len(h))))[:n]
    y = thump * 0.8 + onepole_lp(h, 1500) * 0.7 + bandpass(noise(n), 300, 2000) * adsr(n, 0.002, 0.02) * 0.15
    save("felt", i + 1, finish(y, 0.06), "synth thump + damped place")

# ── rotate: quarter-turn rustle and a woody settle ─────────────────────────────────────────────────────────────
for i in range(6):
    n = int(0.34 * SR)
    t = np.arange(n) / SR
    nz = noise(n)
    sweep_lo = 600 + 400 * (i % 3)
    sw = np.zeros(n)
    # rising band: three overlapping filtered slices
    for k, (lo, hi) in enumerate([(sweep_lo, 2200), (sweep_lo * 1.6, 3600), (sweep_lo * 2.4, 6000)]):
        seg = bandpass(nz, lo, hi) * np.exp(-((t - (0.05 + 0.05 * k)) / 0.05) ** 2)
        sw += seg
    settle = clacks["bone"][i % 6]
    settle = onepole_lp(settle, 2400) * 0.45
    y = sw * 0.5
    off = int((0.19 + 0.01 * i) * SR)
    y[off:off + len(settle)] += settle[:n - off]
    save("rotate", i + 1, finish(y, 0.05), "synth rustle + bone settle")

# ── thread: five tuned silk «zings» (G4 A4 C5 D5 E5) ──────────────────────────────────────────────────────────
for i, f in enumerate([392.0, 440.0, 523.25, 587.33, 659.25]):
    n = int(0.6 * SR)
    t = np.arange(n) / SR
    glide = f * (1 + 0.03 * np.exp(-t / 0.03) * -1)        # starts 3% flat, settles
    ph = 2 * np.pi * np.cumsum(glide) / SR
    vib = 1 + 0.004 * np.sin(2 * np.pi * 5.5 * t)
    tone = (np.sin(ph * vib) + 0.35 * np.sin(2 * ph) + 0.12 * np.sin(3 * ph + 0.3)) * adsr(n, 0.025, 0.22)
    silk = bandpass(noise(n), 3000, 9000) * adsr(n, 0.01, 0.06) * 0.25
    save("thread", i + 1, finish(tone + silk, 0.12), "synth %.0f Hz" % f)

# ── triple: 3-note pentatonic chord from the guzheng pluck, root by suit ───────────────────────────────────────
pl_note = load("s_pluck.mp3")
pl_note = hit_at(pl_note, 30.0, 2.2)
# estimate the pluck's pitch (autocorrelation on the sustained part)
seg = pl_note[int(0.15 * SR):int(0.55 * SR)]
seg = seg - seg.mean()
ac = np.correlate(seg, seg, "full")[len(seg) - 1:]
lo, hi = int(SR / 1000), int(SR / 70)
f_src = SR / (lo + int(np.argmax(ac[lo:hi])))
manifest["sources"]["pluck_f0"] = round(float(f_src), 2)
PENTA = [261.63, 293.66, 329.63, 392.00, 440.00, 523.25, 587.33, 659.25, 783.99, 880.00, 1046.5]
for suit in range(5):
    for v in range(4):
        # root = pentatonic degree `suit`; chord = degrees root, root+2, root+4 (an open «Пять ветров» voicing)
        root = suit + (5 if v == 3 else 0)
        degs = [root, root + 2, root + 4]
        degs = [min(d, len(PENTA) - 1) for d in degs]
        notes = [resample(pl_note, PENTA[d] / f_src) for d in degs]
        strum = [0.0, 0.045, 0.09] if v in (0, 3) else ([0.09, 0.045, 0.0] if v == 1 else [0.0, 0.012, 0.024])
        n = int(max(len(nn) + s * SR for nn, s in zip(notes, strum)))
        y = np.zeros(n)
        for nn, s in zip(notes, strum):
            o = int(s * SR)
            y[o:o + len(nn)] += nn * (0.9 if o else 1.0)
        y = y[:int(1.6 * SR)]
        save("triple_%d" % suit, v + 1, finish(y, 0.35), "pluck→%s" % ",".join("%.0f" % PENTA[d] for d in degs))

# ── gong: soft temple gong (×5 combo) ─────────────────────────────────────────────────────────────────────────
for i, f0 in enumerate([110.0, 123.47, 98.0, 130.81]):
    n = int(2.6 * SR)
    t = np.arange(n) / SR
    y = np.zeros(n)
    for k, (r, a, tau) in enumerate([(1.0, 1.0, 1.4), (1.47, 0.55, 1.0), (1.98, 0.42, 0.8), (2.52, 0.3, 0.6),
                                     (3.03, 0.22, 0.45), (4.1, 0.12, 0.3), (5.4, 0.06, 0.2)]):
        beat = 1 + 0.08 * np.sin(2 * np.pi * (0.7 + 0.3 * k) * t)
        y += a * np.sin(2 * np.pi * f0 * r * t * (1 + 0.002 * np.exp(-t / 0.2))) * np.exp(-t / tau) * beat
    y *= np.minimum(t / 0.012, 1)
    mallet = onepole_lp(noise(n), 400) * adsr(n, 0.002, 0.03) * 0.6
    save("gong", i + 1, finish(y + mallet, 0.4, -9.0), "synth gong %.0f Hz" % f0)

# ── ambients: 12 s seamless loops ──────────────────────────────────────────────────────────────────────────────
for name in ["rain", "stream", "bamboo"]:
    x = load("a_%s.mp3" % name)
    x = hp(x, 60.0)
    L = len(x)
    xf = int(2.0 * SR)
    body = x[:L - xf].copy()
    tail = x[L - xf:]
    w = np.linspace(0, 1, xf)
    body[:xf] = body[:xf] * np.sqrt(w) + tail * np.sqrt(1 - w)
    rms = np.sqrt(np.mean(body ** 2))
    body *= 10 ** (-26 / 20) / (rms + 1e-12)
    pk = np.max(np.abs(body))
    if pk > 10 ** (-6.5 / 20):
        body *= 10 ** (-6.5 / 20) / pk
    tmp = os.path.join(AMB, "_%s.wav" % name)
    with wave.open(tmp, "wb") as wv:
        wv.setnchannels(1)
        wv.setsampwidth(2)
        wv.setframerate(SR)
        wv.writeframes((np.clip(body, -1, 1) * 32767).astype(np.int16).tobytes())
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", tmp, "-c:a", "libvorbis", "-q:a", "5",
                    os.path.join(AMB, "%s.ogg" % name)], check=True)
    os.remove(tmp)
    manifest["peak_dbfs"]["amb_" + name] = round(float(20 * np.log10(np.max(np.abs(body)))), 2)

with open(os.path.join(OUT, "manifest.json"), "w") as f:
    json.dump(manifest, f, ensure_ascii=False, indent=1, sort_keys=True)
print(json.dumps(manifest["variants"]))
print("max peak", max(v for k, v in manifest["peak_dbfs"].items()))
