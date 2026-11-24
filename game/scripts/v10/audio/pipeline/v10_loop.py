#!/usr/bin/env python3
"""v10 audio pipeline: seamless music loops + loudness-normalised SFX -> .ogg

  python3 game/scripts/v10/audio/pipeline/v10_loop.py music <in.mp3> <out.ogg> [--lufs -16] [--sting]
  python3 game/scripts/v10/audio/pipeline/v10_loop.py voice <in.mp3> <out.ogg> --lufs <match the heroine's 0.7 lines>
  python3 game/scripts/v10/audio/pipeline/v10_loop.py sfx   <in.mp3> <out.ogg> [--lufs -14] [--maxlen sec]

Music loop: find (S, E) with the most similar 3 s of audio after S and after E
(log-mel + chroma + onset features, diagonal-sum of a cosine similarity matrix),
prefer E-S a whole number of bars, refine E to the sample by waveform cross-correlation,
then render audio[S+X : E+X] where the last X samples are audio[E:E+X] faded out
mixed with audio[S:S+X] faded in (equal-power). The wrap point is then
audio[S+X-1] -> audio[S+X]: continuous by construction.
Prints a JSON line with the loop metrics (seam score, seam jump, bpm).
"""
import json
import subprocess
import sys

import numpy as np
import pyloudnorm as pyln
import soundfile as sf
from scipy import signal

SR = 44100
import os
SIM_W = float(os.environ.get('V10_SIM_W', '1.0'))  # weight of feature similarity vs seam flux
MIN_LEN = float(os.environ.get('V10_MIN_LEN', '30'))
HOP = 512


def decode(path):
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-f", "f32le", "-ac", "2", "-ar", str(SR), "-"],
                         check=True, capture_output=True).stdout
    return np.frombuffer(raw, dtype=np.float32).reshape(-1, 2).astype(np.float64)


def encode(x, path, q=5):
    tmp = path + ".wav"
    sf.write(tmp, np.clip(x, -1, 1).astype(np.float32), SR, subtype="FLOAT")
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", tmp, "-c:a", "libvorbis", "-q:a", str(q), path], check=True)
    subprocess.run(["rm", "-f", tmp])


def features(mono):
    f, t, Z = signal.stft(mono, SR, nperseg=2048, noverlap=2048 - HOP, boundary=None, padded=False)
    mag = np.abs(Z)
    # 40 log-spaced bands 60 Hz..12 kHz
    edges = np.geomspace(60, 12000, 41)
    bands = np.stack([mag[(f >= edges[i]) & (f < edges[i + 1])].sum(0) + 1e-9 for i in range(40)])
    logm = np.log(bands)
    # chroma
    pitch = np.where(f > 50, 12 * np.log2(np.maximum(f, 1) / 440.0) + 69, -1)
    chroma = np.stack([mag[(pitch >= 0) & (np.round(pitch).astype(int) % 12 == k)].sum(0) for k in range(12)])
    chroma = chroma / (chroma.sum(0, keepdims=True) + 1e-9)
    onset = np.maximum(0, np.diff(logm, axis=1, prepend=logm[:, :1])).sum(0)
    rms = np.sqrt((mag ** 2).mean(0))
    return logm, chroma, onset, rms


def tempo(onset):
    o = onset - onset.mean()
    ac = np.correlate(o, o, "full")[len(o) - 1:]
    fps = SR / HOP
    lo, hi = int(fps * 60 / 180), int(fps * 60 / 60)
    lag = lo + int(np.argmax(ac[lo:hi]))
    return 60.0 * fps / lag, lag


def znorm(m):
    m = m - m.mean(1, keepdims=True)
    return m / (m.std(1, keepdims=True) + 1e-9)


def find_loop(x, min_len_s=None, top_k=40):
    min_len_s = MIN_LEN if min_len_s is None else min_len_s
    mono = x.mean(1)
    logm, chroma, onset, rms = features(mono)
    n = logm.shape[1]
    fps = SR / HOP
    bpm, beat_lag = tempo(onset)
    F = np.vstack([znorm(logm), 2.0 * znorm(chroma), 1.5 * znorm(onset[None, :])])
    F = F / (np.linalg.norm(F, axis=0, keepdims=True) + 1e-9)
    W = int(3.0 * fps)
    lrms = 20 * np.log10(np.convolve(rms, np.ones(W) / W, "valid") + 1e-9)  # level of the W window at i
    # usable region: avoid an end fade / start silence (smoothed rms < 45% of median)
    med = np.median(rms)
    sm = np.convolve(rms, np.ones(int(fps)) / int(fps), "same")
    loud = np.where(sm > 0.45 * med)[0]
    first, last = loud[0], loud[-1]
    s_lo, s_hi = first + int(0.3 * fps), max(first + int(2 * fps), min(first + int(30 * fps), n // 2))
    e_hi = last - W - int(0.5 * fps)
    e_lo = s_lo + int(min(min_len_s, 0.4 * n / fps) * fps)
    step = 3
    S = np.arange(s_lo, s_hi, step)
    E = np.arange(e_lo, e_hi, step)
    A = F[:, S[0]:S[-1] + W]
    B = F[:, E[0]:E[-1] + W]
    M = A.T @ B
    score = np.zeros((len(S), len(E)))
    si = S - S[0]
    ei = E - E[0]
    ks = range(0, W, 3)
    for k in ks:
        score += M[np.ix_(si + k, ei + k)]
    score /= len(ks)
    L = (E[None, :] - S[:, None]).astype(float)
    bar = 4 * beat_lag
    ph = np.abs(((L / bar) + 0.5) % 1.0 - 0.5)
    lvl = np.abs(lrms[np.minimum(S, len(lrms) - 1)][:, None] - lrms[np.minimum(E, len(lrms) - 1)][None, :])
    longer = L / n  # prefer longer loops a little (less repetition)
    total = score - 0.15 * ph - 0.03 * lvl + 0.15 * longer
    total[L < e_lo - s_lo] = -9
    # top-k distinct candidates (>= 1 s apart in S or E)
    order = np.argsort(total, axis=None)[::-1]
    cands = []
    for o in order[:20000]:
        i, j = np.unravel_index(o, total.shape)
        if any(abs(S[i] - a) < fps and abs(E[j] - b) < fps for a, b, _ in cands):
            continue
        cands.append((S[i], E[j], total[i, j]))
        if len(cands) >= top_k:
            break
    best = None
    for s_f, e_f, tot in cands:
        info = _refine(x, mono, F, s_f, e_f, W, n)
        y = render_loop(x, info["start"], info["end"])
        fp = seam_flux_pct(y)
        w = int(0.25 * SR)
        rr = abs(20 * np.log10((np.sqrt((y[:w] ** 2).mean()) + 1e-9) / (np.sqrt((y[-w:] ** 2).mean()) + 1e-9)))
        cost = -SIM_W * tot + 0.03 * max(0.0, fp - 80) + 0.08 * max(0.0, rr - 1.5)
        info.update(seam_flux_pct=fp, cand_total=float(tot), cost=float(cost), rms_jump_db=float(rr))
        if best is None or cost < best["cost"]:
            best = info
    best["bpm"] = bpm
    best["candidates"] = len(cands)
    return best


def _refine(x, mono, F, s_f, e_f, W, n):
    bestf = (-9, s_f, e_f)
    for ds in range(-3, 4):
        for de in range(-3, 4):
            a, b = s_f + ds, e_f + de
            if a < 0 or b + W >= n:
                continue
            v = float((F[:, a:a + W] * F[:, b:b + W]).sum(0).mean())
            if v > bestf[0]:
                bestf = (v, a, b)
    seam_score, s_f, e_f = bestf
    s_smp, e_smp = s_f * HOP, e_f * HOP
    win = int(0.04 * SR)
    r = int(0.012 * SR)
    ref = mono[s_smp:s_smp + win]
    seg = mono[e_smp - r:e_smp + r + win]
    cc = signal.correlate(seg, ref, "valid")
    e_smp = e_smp - r + int(np.argmax(cc))
    return dict(start=int(s_smp), end=int(e_smp), seam_score=seam_score)


def render_loop(x, s, e, xf_sec=0.35):
    X = int(xf_sec * SR)
    if e + X > len(x):
        X = len(x) - e - 1
    body = x[s + X:e + X].copy()
    t = np.linspace(0, np.pi / 2, X)[:, None]
    body[-X:] = x[e:e + X] * np.cos(t) + x[s:s + X] * np.sin(t)
    return body


def seam_jump(y):
    # continuity proxy: sample step across the wrap vs typical step
    d = np.abs(np.diff(y.mean(1)))
    wrap = abs(y[0].mean() - y[-1].mean())
    # spectral continuity: rms of last/first 50 ms
    w = int(0.05 * SR)
    r1 = np.sqrt((y[-w:] ** 2).mean())
    r2 = np.sqrt((y[:w] ** 2).mean())
    return dict(wrap_step=float(wrap), p99_step=float(np.percentile(d, 99)),
                rms_ratio_db=float(20 * np.log10((r2 + 1e-9) / (r1 + 1e-9))))


def seam_flux_pct(y):
    """Listening proxy: play the loop twice, measure spectral flux + level jump at the wrap,
    report its percentile among all frames (<= ~95 means the seam is no louder a change than
    ordinary musical events)."""
    yy = np.vstack([y, y]).mean(1)
    logm, _, onset, _ = features(yy)
    seam = len(y) // HOP
    flux = np.abs(np.diff(logm, axis=1)).sum(0)
    w = flux[seam - 3:seam + 3].max()
    return float((flux < w).mean() * 100)


def normalise(x, lufs, peak_db=-1.0):
    meter = pyln.Meter(SR, block_size=min(0.4, max(0.1, len(x) / SR / 2)))
    try:
        cur = meter.integrated_loudness(x)
    except Exception:
        cur = -70
    if not np.isfinite(cur) or cur < -60:
        g = 1.0
    else:
        g = 10 ** ((lufs - cur) / 20)
    y = x * g
    pk = np.abs(y).max() + 1e-12
    lim = 10 ** (peak_db / 20)
    if pk > lim:
        # soft-knee: tanh saturate only the excess over 0.8*lim, then hard-scale
        y = soft_limit(y, lim)
    try:
        out = meter.integrated_loudness(y)
    except Exception:
        out = float("nan")
    return y, cur, out


def soft_limit(y, lim):
    # simple look-ahead-free gain-riding limiter (5 ms attack, 80 ms release)
    env = np.abs(y).max(1)
    need = np.minimum(1.0, lim / (env + 1e-12))
    a_r = np.exp(-1 / (0.08 * SR))
    g = np.empty_like(need)
    cur = 1.0
    # backward pass for attack (instant look-ahead ~ by min filter)
    k = int(0.005 * SR)
    from scipy.ndimage import minimum_filter1d
    need = minimum_filter1d(need, size=2 * k + 1)
    for i in range(len(need)):
        cur = need[i] if need[i] < cur else need[i] + (cur - need[i]) * a_r
        g[i] = cur
    return y * g[:, None]


def trim_sfx(x, on_db=-30, tail_db=-48):
    """Cut leading silence up to the first event (-30 dB re peak, 3 ms pre-roll) so the sound
    lands on the tap; cut the tail where the 10 ms envelope stays below -48 dB re peak."""
    mono = np.abs(x).max(1)
    pk = mono.max() + 1e-12
    w = int(0.01 * SR)
    env = np.convolve(mono, np.ones(w) / w, "same")
    db = 20 * np.log10(env / pk + 1e-12)
    a = max(0, int(np.argmax(db > on_db)) - int(0.003 * SR))
    b = len(db) - int(np.argmax(db[::-1] > tail_db))
    b = min(len(x), b + int(0.02 * SR))
    y = x[a:b].copy()
    fi = min(int(0.002 * SR), len(y) // 4)
    fo = min(int(0.06 * SR), len(y) // 3)
    y[:fi] *= np.linspace(0, 1, fi)[:, None]
    y[-fo:] *= (np.linspace(1, 0, fo) ** 2)[:, None]
    return y


def normalise_sfx(y, lufs, peak_db=-1.0):
    """Gain to the LUFS target, but never past -1 dBFS peak (no limiter: transients stay clean,
    noise floor is not pumped up). Short clicks therefore land below the target; the bank
    sets per-id playback gain."""
    meter = pyln.Meter(SR, block_size=min(0.4, max(0.05, len(y) / SR / 2)))
    try:
        cur = meter.integrated_loudness(y)
    except Exception:
        cur = -70.0
    pk = np.abs(y).max() + 1e-12
    g_peak = 10 ** (peak_db / 20) / pk
    g = g_peak if (not np.isfinite(cur) or cur < -65) else min(10 ** ((lufs - cur) / 20), g_peak)
    y = y * g
    try:
        out = meter.integrated_loudness(y)
    except Exception:
        out = float("nan")
    return y, cur, out


def main():
    mode, src, dst = sys.argv[1:4]
    args = sys.argv[4:]
    lufs = float(args[args.index("--lufs") + 1]) if "--lufs" in args else (-16 if mode == "music" else -14)
    x = decode(src)
    if mode == "music" and "--sting" not in args:
        info = find_loop(x)
        y = render_loop(x, info["start"], info["end"])
        y, li, lo = normalise(y, lufs)
        info.update(seam_jump(y))
        info["seam_flux_pct"] = seam_flux_pct(y)  # re-measure after loudness normalisation
        info.update(loop=True, len=len(y) / SR, lufs_in=li, lufs_out=lo,
                    start_s=info["start"] / SR, end_s=info["end"] / SR)
    elif mode == "voice":
        y = trim_sfx(x, -40, -55)
        y, li, lo = normalise_sfx(y, lufs)
        info = dict(loop=False, len=len(y) / SR, lufs_in=li, lufs_out=lo, peak=float(np.abs(y).max()))
    elif mode == "music":
        y = trim_sfx(x, -40, -60)
        y, li, lo = normalise(y, lufs)
        info = dict(loop=False, len=len(y) / SR, lufs_in=li, lufs_out=lo)
    else:
        y = trim_sfx(x)
        if "--maxlen" in args:  # tap-class sounds: keep the transient, decay the room tone fast
            m = int(float(args[args.index("--maxlen") + 1]) * SR)
            if len(y) > m:
                y = y[:m].copy()
                k = m // 2
                y[-k:] *= np.exp(-np.linspace(0, 6, k))[:, None]
        y, li, lo = normalise_sfx(y, lufs)
        info = dict(loop=False, len=len(y) / SR, lufs_in=li, lufs_out=lo, peak=float(np.abs(y).max()))
    encode(y, dst)
    print(json.dumps({k: (round(float(v), 4) if isinstance(v, (float, np.floating)) else (int(v) if isinstance(v, np.integer) else v)) for k, v in info.items()}))


if __name__ == "__main__":
    main()
