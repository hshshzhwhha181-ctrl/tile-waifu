#!/usr/bin/env python3
"""Tile Waifu audio loudness gate (GDD V11 s8.1 / s11.5 / N14).

Measures every audio file (ogg / mp3 / wav) and checks it against the loudness contract:

  music   integrated -16 +-1 LUFS, true peak <= -1 dBTP
  voice   integrated -14 +-1 LUFS, true peak <= -1 dBTP, leading silence <= 40 ms,
          spread inside one heroine +-1 LU (vs that heroine's median),
          spread between heroines +-1.5 LU (heroine median vs the median of all heroine medians)
  sfx/ui  sample peak <= -5 dBFS (target -6, +1 dB tolerance like the other buses), true peak <= -1 dBTP
  ambient true peak <= -1 dBTP only (beds are mixed under music, no level target in the GDD)

Dependencies: python3 + numpy (measurement) and ffmpeg/ffprobe (decoding ogg/mp3/wav only; no filters are used).
ffmpeg's `ebur128` filter is used only as an independent cross-check in --selftest when it exists.
The loudness meter is a from-scratch ITU-R BS.1770-4 implementation (K-weighting, 400 ms blocks, 75% overlap,
-70 LUFS absolute gate, -10 LU relative gate); signals shorter than 400 ms are measured as one block
(voice interjections are often 0.3-0.8 s). Mono files: the CSV has both `lufs_file` (plain BS.1770 on the file, same as
ffmpeg ebur128 / pyloudnorm / voice_build.py) and `lufs_play` (+3.01 LU: the engine sends a mono stream to both speakers).
Voice, sfx and ambient are judged by lufs_file (the voice pipeline's convention); music by lufs_play (stereo masters
that asset slimming turned into mono keep their audible level). See MONO_BASIS.

usage:
  python tools/audio/lufs_gate.py                       # scan game/assets + audio/, write tools/audio/audio_report.csv
  python tools/audio/lufs_gate.py PATH [PATH ...] --csv out.csv -j 2
  python tools/audio/lufs_gate.py --selftest            # 12 synthetic reference signals + peak/silence/classifier tests
  python tools/audio/lufs_gate.py --strict              # exit 1 if any scanned file is outside the contract
"""
from __future__ import annotations

import argparse
import concurrent.futures as cf
import csv
import json
import math
import os
import re
import subprocess
import sys
import time
import wave
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
AUDIO_EXT = {".ogg", ".mp3", ".wav"}
DEFAULT_ROOTS = ["game/assets", "audio"]

# ---------------------------------------------------------------------------------------------------------
# contract (GDD s8.1)
# ---------------------------------------------------------------------------------------------------------
TH = dict(
    music_lufs=-16.0, music_tol=1.0,
    voice_lufs=-14.0, voice_tol=1.0,
    voice_in_hero=1.0, voice_between=1.5,
    tp_max=-1.0,
    sfx_peak_max=-5.0,
    lead_ms_max=40.0,
    lead_thr_db=-50.0,          # first sample louder than this counts as the start of sound
)
# Which loudness a mono file is judged by. "file" = plain BS.1770 on the file (ffmpeg ebur128 / pyloudnorm, what
# voice_build.py targets); "play" = mono duplicated to both channels (+3.01 LU, what the player hears).
# Music masters were stereo at -16 and the asset slimming turned some into mono (stings, rin/nova motifs) without
# changing what is heard, so music is judged by "play"; voice keeps the pipeline's file convention.
MONO_BASIS = dict(music="play", voice="file", sfx="file", ambient="file", other="file")
MIN_GROUP = 3                    # files needed for a within-heroine spread check
MIN_HERO_FILES = 8               # a voice group this big counts as a "heroine" for the between-heroines check


# ---------------------------------------------------------------------------------------------------------
# decoding
# ---------------------------------------------------------------------------------------------------------
def decode(path: str) -> tuple[np.ndarray, int]:
    """Return (float64 array [n, ch], sample_rate). Native rate and channel count are kept (one ffmpeg call)."""
    if path.lower().endswith(".wav"):
        try:
            return _read_wav(path)
        except Exception:  # noqa: BLE001 - float / 24-bit wavs etc. go through ffmpeg
            pass
    p = subprocess.run(["ffmpeg", "-nostdin", "-hide_banner", "-i", path, "-map", "0:a:0", "-f", "f32le", "-acodec", "pcm_f32le", "-"],
                       capture_output=True)
    err = p.stderr.decode("utf-8", "replace")
    if p.returncode != 0:
        raise RuntimeError(err.strip()[-200:] or f"rc={p.returncode}")
    m = re.search(r"Stream #0:\d+.*?Audio:.*?,\s*(\d+) Hz,\s*([^,\n]+)", err)
    if not m:
        raise RuntimeError("cannot read stream info")
    sr = int(m.group(1))
    lay = m.group(2).strip().split("(")[0]
    ch = {"mono": 1, "stereo": 2, "2.1": 3, "3.0": 3, "quad": 4, "4.0": 4, "5.0": 5, "5.1": 6}.get(lay)
    if ch is None:
        mm = re.match(r"(\d+) channels", lay)
        ch = int(mm.group(1)) if mm else 2
    x = np.frombuffer(p.stdout, dtype="<f4").astype(np.float64)
    n = len(x) // ch
    return x[: n * ch].reshape(n, ch), sr


def _read_wav(path: str) -> tuple[np.ndarray, int]:
    with wave.open(path, "rb") as w:
        ch, sw, sr, n = w.getnchannels(), w.getsampwidth(), w.getframerate(), w.getnframes()
        raw = w.readframes(n)
    if sw == 2:
        x = np.frombuffer(raw, dtype="<i2").astype(np.float64) / 32768.0
    elif sw == 1:
        x = (np.frombuffer(raw, dtype=np.uint8).astype(np.float64) - 128.0) / 128.0
    else:
        raise ValueError("unsupported wav width")
    return x[: (len(x) // ch) * ch].reshape(-1, ch), sr


# ---------------------------------------------------------------------------------------------------------
# BS.1770-4 meter
# ---------------------------------------------------------------------------------------------------------
def k_weight_biquads(fs: float):
    """Pre-filter (high shelf) and RLB (high pass) as ((b0,b1,b2),(1,a1,a2)); same design as libebur128 / pyloudnorm."""
    # stage 1: high shelf, +4 dB around 1.68 kHz
    f0, G, Q = 1681.974450955533, 3.999843853973347, 0.7071752369554196
    K = math.tan(math.pi * f0 / fs)
    Vh = 10 ** (G / 20)
    Vb = Vh ** 0.4996667741545416
    a0 = 1 + K / Q + K * K
    s1 = ((Vh + Vb * K / Q + K * K) / a0, 2 * (K * K - Vh) / a0, (Vh - Vb * K / Q + K * K) / a0)
    s1a = (1.0, 2 * (K * K - 1) / a0, (1 - K / Q + K * K) / a0)
    # stage 2: RLB high pass at 38 Hz
    f0, Q = 38.13547087602444, 0.5003270373238773
    K = math.tan(math.pi * f0 / fs)
    a0 = 1 + K / Q + K * K
    s2 = (1.0, -2.0, 1.0)
    s2a = (1.0, 2 * (K * K - 1) / a0, (1 - K / Q + K * K) / a0)
    return (s1, s1a), (s2, s2a)


def k_response(freqs: np.ndarray, fs: float) -> np.ndarray:
    """Squared magnitude |H(f)|^2 of the cascaded K-weighting at the given frequencies (Hz)."""
    w = 2 * np.pi * np.asarray(freqs, dtype=np.float64) / fs
    z1, z2 = np.exp(-1j * w), np.exp(-2j * w)
    h = np.ones_like(w, dtype=np.complex128)
    for b, a in k_weight_biquads(fs):
        h = h * (b[0] + b[1] * z1 + b[2] * z2) / (a[0] + a[1] * z1 + a[2] * z2)
    return np.abs(h) ** 2


def _fast_len(n: int) -> int:
    """Smallest 2^a 3^b 5^c >= n (fast FFT sizes; numpy has no next_fast_len)."""
    best = 1 << (n - 1).bit_length()
    p5 = 1
    while p5 < best:
        p35 = p5
        while p35 < best:
            m = p35 * (1 << max(0, (n - 1) // p35).bit_length()) if p35 < n else p35
            if m >= n:
                best = min(best, m)
            p35 *= 3
        p5 *= 5
    return best


def k_filter(x: np.ndarray, fs: float) -> np.ndarray:
    """Apply the K-weighting to a 1-D signal by FFT (zero-padded, so it equals the zero-state IIR response)."""
    n = len(x)
    tail = int(fs * 2)  # impulse response of the 38 Hz high pass is gone well before 2 s
    m = _fast_len(n + tail)
    X = np.fft.rfft(x, m)
    f = np.arange(len(X)) * (fs / m)
    w = 2 * np.pi * f / fs
    z1, z2 = np.exp(-1j * w), np.exp(-2j * w)
    H = np.ones(len(X), dtype=np.complex128)
    for b, a in k_weight_biquads(fs):
        H *= (b[0] + b[1] * z1 + b[2] * z2) / (a[0] + a[1] * z1 + a[2] * z2)
    return np.fft.irfft(X * H, m)[:n]


def channel_weights(ch: int) -> list[float]:
    # L R C = 1.0, Ls Rs = 1.41 (BS.1770), LFE (index 3 of 5.1) excluded
    if ch <= 3:
        return [1.0] * ch
    w = [1.0, 1.0, 1.0, 0.0, 1.41, 1.41]
    return (w + [1.0] * ch)[:ch]


def loudness(x: np.ndarray, fs: int) -> float:
    """Gated integrated loudness in LUFS (-inf if nothing is above the absolute gate)."""
    n, ch = x.shape
    if n == 0:
        return -math.inf
    cw = channel_weights(ch)
    blk = int(round(0.4 * fs))
    step = int(round(0.1 * fs))
    if n < blk:
        starts = np.array([0])
        blk = n
    else:
        starts = np.arange(0, n - blk + 1, step)
    z = np.zeros(len(starts))
    for c in range(ch):
        if cw[c] == 0:
            continue
        y = k_filter(x[:, c], fs)
        cs = np.concatenate([[0.0], np.cumsum(y * y)])
        z += cw[c] * (cs[starts + blk] - cs[starts]) / blk
    with np.errstate(divide="ignore"):
        lk = -0.691 + 10 * np.log10(z)
    keep = lk > -70.0
    if not keep.any():
        return -math.inf
    rel = -0.691 + 10 * math.log10(z[keep].mean()) - 10.0
    keep &= lk > rel
    if not keep.any():
        return -math.inf
    return -0.691 + 10 * math.log10(z[keep].mean())


_TP_OS = 4
_TP_PER_PHASE = 24
_TP_TAPS = None


def _tp_taps() -> np.ndarray:
    """Windowed-sinc 4x interpolator (cutoff = original Nyquist), 2*24 taps per polyphase branch."""
    global _TP_TAPS
    if _TP_TAPS is None:
        n = _TP_OS * _TP_PER_PHASE * 2 + 1          # odd length: integer group delay
        t = (np.arange(n) - (n - 1) // 2) / _TP_OS
        _TP_TAPS = np.sinc(t) * np.kaiser(n, 9.0)
    return _TP_TAPS


def true_peak_db(x: np.ndarray) -> float:
    """4x oversampled peak in dBTP (BS.1770 Annex 2 idea). Only neighbourhoods of samples within 6 dB of the
    sample peak are interpolated; nothing else can hold the maximum."""
    h = _tp_taps()
    M = _TP_PER_PHASE + 6
    best = 0.0
    for c in range(x.shape[1]):
        v = x[:, c]
        if not len(v):
            continue
        sp = float(np.max(np.abs(v)))
        if sp == 0.0:
            continue
        best = max(best, sp)
        cand = np.flatnonzero(np.abs(v) >= sp * 0.5)
        cuts = np.flatnonzero(np.diff(cand) > 2 * M) + 1
        for grp in np.split(cand, cuts):
            lo, hi = max(0, int(grp[0]) - 1), min(len(v) - 1, int(grp[-1]) + 1)      # orig range to evaluate
            a, b = max(0, lo - M), min(len(v), hi + M + 1)                            # orig range fed to the filter
            seg = v[a:b]
            up = np.zeros(len(seg) * _TP_OS)
            up[:: _TP_OS] = seg
            y = np.convolve(up, h, mode="full")[(len(h) - 1) // 2:][: len(up)]
            best = max(best, float(np.max(np.abs(y[(lo - a) * _TP_OS: (hi - a) * _TP_OS + 1]))))
    return -math.inf if best <= 0 else 20 * math.log10(best)


def sample_peak_db(x: np.ndarray) -> float:
    p = float(np.max(np.abs(x))) if x.size else 0.0
    return -math.inf if p <= 0 else 20 * math.log10(p)


def leading_silence_ms(x: np.ndarray, fs: int, thr_db: float) -> float:
    a = np.max(np.abs(x), axis=1) if x.ndim == 2 else np.abs(x)
    idx = np.flatnonzero(a > 10 ** (thr_db / 20))
    if len(idx) == 0:
        return 1000.0 * len(a) / fs
    return 1000.0 * idx[0] / fs


def measure_array(x: np.ndarray, fs: int) -> dict:
    lu = loudness(x, fs)
    # what the engine plays: a mono stream goes to both speakers at full gain (power x2 = +3.01 LU)
    play = lu + 10 * math.log10(2) if x.shape[1] == 1 else lu
    return dict(dur=len(x) / fs, sr=fs, ch=x.shape[1], lufs=lu, lufs_play=play, sample_peak=sample_peak_db(x),
                true_peak=true_peak_db(x), lead_ms=leading_silence_ms(x, fs, TH["lead_thr_db"]))


def measure_file(path: str) -> dict:
    x, fs = decode(path)
    return measure_array(x, fs)


# ---------------------------------------------------------------------------------------------------------
# classification + verdicts
# ---------------------------------------------------------------------------------------------------------
def classify(rel: str) -> tuple[str, str]:
    """(kind, group) for a repo-relative posix path. kind: music | voice | sfx | ambient | other."""
    p = "/" + rel.lower()
    name = p.rsplit("/", 1)[-1]
    stem = name.rsplit(".", 1)[0]
    if "/amb/" in p:
        return "ambient", "amb"
    if "/music/" in p or "/daynight/" in p or "koikoi/audio/" in p:
        return "music", "music"
    if "/voice/" in p or p.startswith("/audio/"):
        hero = stem.split("_", 1)[0]
        m = re.search(r"/voice/([a-z0-9]+)/", p)
        if m:
            hero = m.group(1)
        return "voice", hero
    if "/sfx/" in p or "/fx/" in p:
        return "sfx", "sfx"
    return "other", ""


def judge(rows: list[dict]) -> None:
    """Fill row['fails'] / row['status'] in place (needs all rows for the spread checks)."""
    for r in rows:
        f = []
        k = r["kind"]
        if not r.get("error"):
            r["lufs_j"] = r["lufs_play"] if MONO_BASIS.get(k, "file") == "play" else r["lufs"]
        if r.get("error"):
            f.append("decode error")
        else:
            if k == "music" and abs(r["lufs_j"] - TH["music_lufs"]) > TH["music_tol"]:
                f.append(f"lufs {r['lufs_j']:.1f} vs -16+-1")
            if k == "voice":
                if abs(r["lufs_j"] - TH["voice_lufs"]) > TH["voice_tol"]:
                    f.append(f"lufs {r['lufs_j']:.1f} vs -14+-1")
                if r["lead_ms"] > TH["lead_ms_max"]:
                    f.append(f"lead {r['lead_ms']:.0f}ms > 40")
            if k == "sfx" and r["sample_peak"] > TH["sfx_peak_max"]:
                f.append(f"peak {r['sample_peak']:.1f} > -5 dBFS")
            if k in ("music", "voice", "sfx", "ambient") and r["true_peak"] > TH["tp_max"]:
                f.append(f"tp {r['true_peak']:.1f} > -1 dBTP")
        r["fails"] = f
    # voice spread: inside a heroine, and between heroines
    good = [r for r in rows if r["kind"] == "voice" and not r.get("error") and math.isfinite(r["lufs_j"])]
    groups: dict[str, list[dict]] = {}
    for r in good:
        groups.setdefault(r["group"], []).append(r)
    med = {}
    for g, rs in groups.items():
        med[g] = float(np.median([r["lufs_j"] for r in rs]))
        r_in = TH["voice_in_hero"]
        if len(rs) >= MIN_GROUP:
            for r in rs:
                d = r["lufs_j"] - med[g]
                r["dev_hero"] = d
                if abs(d) > r_in:
                    r["fails"].append(f"spread {d:+.1f} LU vs {g} median {med[g]:.1f} (+-1)")
    heroes = [g for g, rs in groups.items() if len(rs) >= MIN_HERO_FILES]
    if len(heroes) >= 2:
        gm = float(np.median([med[g] for g in heroes]))
        for g in heroes:
            d = med[g] - gm
            if abs(d) > TH["voice_between"]:
                for r in groups[g]:
                    r["fails"].append(f"heroine {g} median {med[g]:.1f} is {d:+.1f} LU from all-heroine median {gm:.1f} (+-1.5)")
    for r in rows:
        r["status"] = "FAIL" if r["fails"] else ("n/a" if r["kind"] == "other" else "PASS")


def scan(paths: list[str], jobs: int) -> list[dict]:
    files = []
    for p in paths:
        pp = Path(p)
        if not pp.is_absolute():
            pp = (REPO / pp) if (REPO / pp).exists() else Path.cwd() / pp
        if pp.is_file():
            files.append(pp)
        elif pp.is_dir():
            files += [f for f in sorted(pp.rglob("*")) if f.suffix.lower() in AUDIO_EXT and f.is_file()]
    seen, uniq = set(), []
    for f in files:
        if f not in seen:
            seen.add(f)
            uniq.append(f)

    def one(f: Path) -> dict:
        try:
            rel = f.resolve().relative_to(REPO).as_posix()
        except ValueError:
            rel = f.as_posix()
        kind, group = classify(rel)
        row = dict(file=rel, kind=kind, group=group)
        try:
            row.update(measure_file(str(f)))
        except Exception as e:  # noqa: BLE001 - report, never abort the scan
            row.update(error=str(e)[:120], dur=0, sr=0, ch=0, lufs=-math.inf, lufs_play=-math.inf, sample_peak=-math.inf, true_peak=-math.inf, lead_ms=0)
        return row

    with cf.ThreadPoolExecutor(max_workers=max(1, jobs)) as ex:
        rows = list(ex.map(one, uniq))
    judge(rows)
    return rows


CSV_COLS = ["file", "kind", "group", "status", "lufs_file", "lufs_play", "true_peak_dbtp", "sample_peak_dbfs", "lead_ms", "dur_s", "sr", "ch", "dev_hero_lu", "fails"]


def write_csv(rows: list[dict], path: Path, only_fail: bool = False) -> None:
    def f1(v):
        return "" if v is None or not math.isfinite(v) else f"{v:.2f}"

    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", newline="", encoding="utf-8") as fh:
        w = csv.writer(fh)
        w.writerow(CSV_COLS)
        for r in rows:
            if only_fail and r["status"] != "FAIL":
                continue
            w.writerow([r["file"], r["kind"], r["group"], r["status"], f1(r["lufs"]), f1(r["lufs_play"]), f1(r["true_peak"]), f1(r["sample_peak"]),
                        f"{r['lead_ms']:.1f}", f"{r['dur']:.2f}", r["sr"], r["ch"], f1(r.get("dev_hero")),
                        "; ".join(r["fails"])])


def summary(rows: list[dict]) -> str:
    out = []
    for k in ("music", "voice", "sfx", "ambient", "other"):
        rs = [r for r in rows if r["kind"] == k]
        if not rs:
            continue
        nf = sum(1 for r in rs if r["status"] == "FAIL")
        out.append(f"  {k:8s} {len(rs):4d} files  {nf:4d} outside the contract")
    return "\n".join(out)


# ---------------------------------------------------------------------------------------------------------
# synthetic reference signals + selftest
# ---------------------------------------------------------------------------------------------------------
TESTS_DIR = HERE / "tests"
ANCHOR_LUFS = -0.691  # offset in the BS.1770 definition


def _sine(f, amp_db, dur, fs, phase=0.0):
    t = np.arange(int(dur * fs)) / fs
    return 10 ** (amp_db / 20) * np.sin(2 * np.pi * f * t + phase)


def expected_sines(chs: list[list[tuple[float, float]]], fs: int) -> float:
    """Analytic loudness of channels made of stationary sines [(freq, peak_dbfs)...]: sum_c sum_i A^2/2 |H(f)|^2."""
    z = 0.0
    for tones in chs:
        for f, db in tones:
            a = 10 ** (db / 20)
            z += a * a / 2 * float(k_response(np.array([f]), fs)[0])
    return ANCHOR_LUFS + 10 * math.log10(z)


def expected_gated(segments: list[tuple[float, float]]) -> float:
    """Idealised gated loudness of back-to-back stationary segments [(seconds, segment LUFS or None for silence)].
    Models each 400 ms block as the time-average of the segment powers (ignores filter transients at the joins) and
    applies the -70 LUFS absolute and -10 LU relative gates. Independent of the K-filter / FFT path above."""
    ms = []
    for dur, lu in segments:
        ms += [0.0 if lu is None else 10 ** ((lu + 0.691) / 10)] * int(round(dur * 1000))
    cs = np.concatenate([[0.0], np.cumsum(ms)])
    starts = np.arange(0, len(ms) - 400 + 1, 100)
    z = (cs[starts + 400] - cs[starts]) / 400
    with np.errstate(divide="ignore"):
        lk = -0.691 + 10 * np.log10(z)
    keep = lk > -70
    rel = -0.691 + 10 * math.log10(z[keep].mean()) - 10
    keep &= lk > rel
    return -0.691 + 10 * math.log10(z[keep].mean())


def expected_fft(x: np.ndarray, fs: int) -> float:
    """Reference for noise: Parseval with the K-weight magnitude applied per FFT bin (no time-domain filtering, no gating)."""
    z = 0.0
    for c in range(x.shape[1]):
        v = x[:, c]
        X = np.fft.rfft(v)
        f = np.arange(len(X)) * fs / len(v)
        p = (np.abs(X) ** 2) * k_response(f, fs)
        w = np.full(len(X), 2.0)
        w[0] = 1.0
        if len(v) % 2 == 0:
            w[-1] = 1.0
        z += float(np.sum(p * w)) / (len(v) ** 2)
    return ANCHOR_LUFS + 10 * math.log10(z)


def _level_for(target_lufs: float, f: float, fs: int, nch: int = 1) -> float:
    """peak dBFS of a sine at f (same on nch channels) that has loudness target_lufs."""
    unit = expected_sines([[(f, 0.0)]] * nch, fs)
    return target_lufs - unit


def synth_set() -> list[dict]:
    """12 synthetic signals with a known loudness. Each: name, fs, x [n,ch], expected LUFS, expected source."""
    rng = np.random.default_rng(1770)
    S: list[dict] = []

    def add(name, fs, x, exp, note):
        S.append(dict(name=name, fs=fs, x=x.reshape(len(x), -1), expected=exp, note=note))

    fs = 48000
    # 1-4: 997 Hz anchors (0 dBFS mono sine = -3.01 LUFS by definition)
    x = _sine(997, -20, 2.0, fs)
    add("01_sine997_mono_-20dBFS", fs, x, expected_sines([[(997, -20)]], fs), "anchor, mono")
    x = np.stack([_sine(997, -20, 2.0, fs)] * 2, 1)
    add("02_sine997_stereo_-20dBFS", fs, x, expected_sines([[(997, -20)]] * 2, fs), "anchor, dual channel (+3.01)")
    db = _level_for(-14.0, 997, 44100)
    add("03_sine997_44k_-14LUFS", 44100, _sine(997, db, 2.0, 44100), -14.0, "voice target level, 44.1 kHz")
    db = _level_for(-16.0, 997, 48000)
    add("04_sine997_-16LUFS", 48000, _sine(997, db, 2.0, 48000), -16.0, "music target level")
    # 5-7: K-weighting at other frequencies
    add("05_sine100_mono_-18dBFS", 44100, _sine(100, -18, 2.0, 44100), expected_sines([[(100, -18)]], 44100), "low freq, RLB high pass bites")
    add("06_sine3k_mono_-20dBFS", 48000, _sine(3000, -20, 2.0, 48000), expected_sines([[(3000, -20)]], 48000), "pre-filter shelf boost")
    add("07_sine8k_mono_-24dBFS", 44100, _sine(8000, -24, 2.0, 44100), expected_sines([[(8000, -24)]], 44100), "top of the shelf")
    # 8: two different tones per channel
    xl = _sine(440, -22, 2.0, fs) + _sine(2200, -26, 2.0, fs)
    xr = _sine(660, -24, 2.0, fs) + _sine(5000, -28, 2.0, fs)
    add("08_two_tones_per_channel", fs, np.stack([xl, xr], 1),
        expected_sines([[(440, -22), (2200, -26)], [(660, -24), (5000, -28)]], fs), "uncorrelated tones, channel sum")
    # 9: tone + digital silence (absolute gate must drop the silence)
    x = np.concatenate([_sine(997, -20, 2.0, fs), np.zeros(2 * fs)])
    add("09_tone_then_silence", fs, x, expected_gated([(2, expected_sines([[(997, -20)]], fs)), (2, None)]),
        "gating: silence ignored, partial blocks at the join counted per BS.1770")
    # 10: loud half + quiet half 20 LU lower (relative gate must drop the quiet half)
    x = np.concatenate([_sine(997, -20, 2.0, fs), _sine(997, -40, 2.0, fs)])
    add("10_loud_then_quiet_-20LU", fs, x,
        expected_gated([(2, expected_sines([[(997, -20)]], fs)), (2, expected_sines([[(997, -40)]], fs))]),
        "relative gate: quiet half ignored")
    # 11: stereo white noise, reference by per-bin K-weighting
    n = rng.standard_normal((3 * fs, 2)) * 0.05
    add("11_white_noise_stereo", fs, n, expected_fft(n, fs), "broadband, independent FFT reference")
    # 12: 300 ms burst (shorter than one 400 ms gating block)
    add("12_burst_300ms", fs, _sine(997, -20, 0.3, fs), expected_sines([[(997, -20)]], fs), "sub-block signal")
    return S


def write_wav(path: Path, x: np.ndarray, fs: int) -> None:
    pcm = np.clip(np.round(x * 32767), -32768, 32767).astype("<i2")
    with wave.open(str(path), "wb") as w:
        w.setnchannels(x.shape[1])
        w.setsampwidth(2)
        w.setframerate(fs)
        w.writeframes(pcm.tobytes())


def ffmpeg_ebur128(path: str):
    """Independent cross-check: (integrated LUFS, true peak dBTP) from ffmpeg's ebur128 filter, or None."""
    try:
        p = subprocess.run(["ffmpeg", "-nostdin", "-hide_banner", "-i", path, "-af", "ebur128=peak=true:framelog=quiet",
                            "-f", "null", "-"], capture_output=True, text=True)
    except FileNotFoundError:
        return None
    t = p.stderr.rsplit("Summary:", 1)[-1]
    m = re.search(r"I:\s+(-?[\d.]+|-inf)\s+LUFS", t)
    pk = re.search(r"Peak:\s+(-?[\d.]+|-inf)\s+dBFS", t)
    if not m:
        return None
    return float(m.group(1)), (float(pk.group(1)) if pk else None)


class Checks:
    def __init__(self):
        self.ok = 0
        self.total = 0

    def check(self, cond: bool, msg: str):
        self.total += 1
        if cond:
            self.ok += 1
            print(f"  ok   {msg}")
        else:
            print(f"FAIL   {msg}")


def selftest(write_files: bool = True) -> int:
    C = Checks()
    TESTS_DIR.mkdir(exist_ok=True)
    have_ff = bool(subprocess.run(["which", "ffmpeg"], capture_output=True).stdout.strip())
    tol = 0.3
    print("[1] 12 synthetic loudness references (wav -> ffmpeg decode -> meter), tolerance 0.3 LU")
    manifest = {}
    for s in synth_set():
        p = TESTS_DIR / f"{s['name']}.wav"
        if write_files or not p.exists():
            write_wav(p, s["x"], s["fs"])
        got = measure_file(str(p))["lufs"]
        err = got - s["expected"]
        C.check(abs(err) <= tol, f"{s['name']}: expected {s['expected']:.2f} got {got:.2f} err {err:+.3f} LU ({s['note']})")
        manifest[p.name] = dict(sr=s["fs"], ch=int(s["x"].shape[1]), expected_lufs=round(s["expected"], 3), note=s["note"])
        if have_ff and len(s["x"]) / s["fs"] >= 1.0:      # ffmpeg ebur128 returns -70 for signals shorter than one block
            ff = ffmpeg_ebur128(str(p))
            if ff is not None:
                C.check(abs(got - ff[0]) <= tol, f"{s['name']}: own {got:.2f} vs ffmpeg ebur128 {ff[0]:.2f} (diff {got - ff[0]:+.3f})")
    if write_files:
        (TESTS_DIR / "manifest.json").write_text(json.dumps(manifest, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")

    print("[2] true peak")
    fs = 48000
    # sine at fs/4 with 45 deg phase: all samples at +-0.7071, true peak is 1.0 (+3.01 dB over sample peak)
    x = _sine(fs / 4, 0.0, 0.5, fs, math.pi / 4).reshape(-1, 1)
    sp, tp = sample_peak_db(x), true_peak_db(x)
    C.check(abs(sp + 3.01) < 0.05 and abs(tp) < 0.15, f"fs/4 sine @45deg: sample peak {sp:.2f} dBFS (expect -3.01), true peak {tp:.2f} dBTP (expect 0.00)")
    x = _sine(997, -6.0, 0.5, fs).reshape(-1, 1)
    tp = true_peak_db(x)
    C.check(abs(tp + 6.0) < 0.1, f"997 Hz -6 dBFS: true peak {tp:.2f} (expect -6.00)")
    x = np.zeros((fs // 2, 1))
    x[1000, 0], x[1001, 0] = 0.5, 0.5   # inter-sample peak between two equal samples is above both
    C.check(true_peak_db(x) > sample_peak_db(x) + 0.5, f"two equal adjacent samples: true peak {true_peak_db(x):.2f} > sample peak {sample_peak_db(x):.2f}")
    # independent truth: ideal band-limited 8x upsampling by FFT of a signal that starts and ends at zero (periodic-safe)
    n = int(0.6 * fs)
    env = np.minimum(1, np.arange(n) / 4800) * np.minimum(1, (n - np.arange(n)) / 4800)
    for f, ph in ((fs / 4, math.pi / 4), (11000, 1.0), (fs / 6, 0.3)):
        x = 10 ** (-1.5 / 20) * np.sin(2 * np.pi * f * np.arange(n) / fs + ph) * env
        X = np.fft.rfft(x)
        Y = np.zeros(8 * n // 2 + 1, complex)
        Y[: len(X)] = X
        truth = 20 * math.log10(np.max(np.abs(np.fft.irfft(Y, 8 * n))) * 8)
        got = true_peak_db(x.reshape(-1, 1))
        C.check(abs(got - truth) <= 0.1, f"true peak {f:.0f} Hz faded tone: own {got:.2f}, FFT 8x truth {truth:.2f}")
        if have_ff and f == fs / 4:
            p = TESTS_DIR / "13_tp_fs4_faded_-1.5dBFS.wav"
            if write_files or not p.exists():
                write_wav(p, x.reshape(-1, 1), fs)
            ff = ffmpeg_ebur128(str(p))
            C.check(ff is not None and ff[1] is not None and abs(got - ff[1]) <= 0.2, f"true peak vs ffmpeg ebur128: own {got:.2f}, ffmpeg {ff[1] if ff else None}")

    print("[3] leading silence")
    for sil_ms, want_fail in ((10, False), (30, False), (60, True), (200, True)):
        x = np.concatenate([np.zeros(int(fs * sil_ms / 1000)), _sine(997, -20, 0.5, fs)]).reshape(-1, 1)
        lead = leading_silence_ms(x, fs, TH["lead_thr_db"])
        C.check(abs(lead - sil_ms) <= 1.0 and ((lead > TH["lead_ms_max"]) == want_fail),
                f"{sil_ms} ms of silence measured {lead:.1f} ms -> {'reject' if want_fail else 'accept'}")
    p = TESTS_DIR / "14_lead_60ms.wav"
    x = np.concatenate([np.zeros(int(fs * 0.06)), _sine(997, -20, 0.5, fs)]).reshape(-1, 1)
    if write_files or not p.exists():
        write_wav(p, x, fs)
    C.check(abs(measure_file(str(p))["lead_ms"] - 60.0) <= 2.0, "60 ms leading silence survives wav -> ffmpeg decode")

    print("[4] classifier and verdicts")
    cases = [("game/assets/v10/audio/music/lobby.ogg", "music"), ("game/assets/voice/rin_win1.mp3", "voice"),
             ("audio/rin_win1.mp3", "voice"), ("game/assets/v10/mj/stage/voice/hana_chi_1.ogg", "voice"),
             ("game/assets/sfx/pop.wav", "sfx"), ("game/assets/v06/fx/chime0.wav", "sfx"),
             ("game/assets/v10/mj/look/amb/rain.ogg", "ambient"), ("game/assets/v10/voice/yue/greet1.ogg", "voice")]
    for rel, kind in cases:
        C.check(classify(rel)[0] == kind, f"classify {rel} -> {kind}")
    C.check(classify("game/assets/v10/voice/yue/greet1.ogg")[1] == "yue" and classify("audio/rin_win1.mp3")[1] == "rin",
            "heroine group from directory / file prefix")

    def row(kind, group, lufs, tp=-3.0, sp=-8.0, lead=5.0, mono=False):
        return dict(file=f"{group}_{lufs}", kind=kind, group=group, lufs=lufs, lufs_play=lufs + (3.0103 if mono else 0.0), ch=1 if mono else 2, true_peak=tp, sample_peak=sp, lead_ms=lead, dur=1, sr=48000)

    rows = [row("music", "music", -16.4), row("music", "music", -17.4), row("music", "music", -16.0, tp=-0.2),
            row("voice", "rin", -14.3), row("voice", "rin", -15.6), row("voice", "rin", -14.0, lead=55),
            row("sfx", "sfx", -20.0, sp=-4.0), row("sfx", "sfx", -20.0, sp=-6.0)]
    rows += [row("music", "music", -19.0, mono=True), row("music", "music", -19.0, mono=False), row("voice", "rin", -17.0, mono=True)]
    judge(rows)
    st = [r["status"] for r in rows]
    C.check(st[:8] == ["PASS", "FAIL", "FAIL", "PASS", "FAIL", "FAIL", "FAIL", "PASS"],
            f"verdicts music -16.4 accepted / -17.4 rejected / tp -0.2 rejected; voice -14.3 accepted / -15.6 rejected / lead 55 rejected; sfx peak -4 rejected / -6 accepted ({[x.lower() for x in st]})")
    C.check(st[8:] == ["PASS", "FAIL", "FAIL"], f"mono basis: mono music -19.0 file (= -16.0 played) accepted, stereo -19.0 rejected, mono voice -17.0 rejected ({[x.lower() for x in st[8:]]})")
    # within-heroine spread: median -14.0, one line 1.3 LU away fails the spread rule even though it is still inside -14+-1.5 ... use -14.9 (inside +-1) vs median -13.4
    rows = [row("voice", "yue", v) for v in (-13.2, -13.4, -13.5, -13.6, -14.7)]
    judge(rows)
    C.check([r["status"] for r in rows] == ["PASS", "PASS", "PASS", "PASS", "FAIL"],
            f"in-heroine spread: -14.7 is 1.1 LU from median -13.5 -> rejected ({[r['status'].lower() for r in rows]})")
    rows = []
    for g, v in (("a", -14.0), ("b", -14.2), ("c", -13.8), ("d", -15.6)):
        rows += [row("voice", g, v + d) for d in (-0.1, 0.0, 0.1, 0.0, 0.1, 0.0, -0.1, 0.0)]
    judge(rows)
    bad = {r["group"] for r in rows if r["status"] == "FAIL"}
    C.check(bad == {"d"}, f"between-heroines +-1.5: only heroine d (-15.6 vs median ~-14.1) rejected (got {sorted(bad)})")
    C.check(all(r["status"] == "PASS" for r in judged_ok()), "all-good set passes")

    print("[5] normalize.py (same meter, gain + true-peak ceiling + lead trim + re-encode)")
    r = subprocess.run([sys.executable, str(HERE / "normalize.py"), "--selftest"], capture_output=True, text=True)
    m = re.search(r"NORMALIZE SELFTEST (\d+)/(\d+)", r.stdout)
    C.check(bool(m) and m.group(1) == m.group(2), f"normalize.py selftest {m.group(0) if m else r.stdout[-200:] + r.stderr[-200:]}")

    print(f"AUDIO_GATE SELFTEST {C.ok}/{C.total}")
    return 0 if C.ok == C.total else 1


def judged_ok():
    def r(kind, g, l, **k):
        d = dict(file="x", kind=kind, group=g, lufs=l, lufs_play=l, true_peak=-3.0, sample_peak=-8.0, lead_ms=3.0, dur=1, sr=1, ch=1)
        d.update(k)
        return d
    rows = [r("music", "music", -16.0), r("voice", "rin", -14.0), r("voice", "rin", -14.4), r("voice", "rin", -13.7), r("sfx", "sfx", -22.0)]
    judge(rows)
    return rows


# ---------------------------------------------------------------------------------------------------------
def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("paths", nargs="*", help=f"files or folders (default: {' '.join(DEFAULT_ROOTS)})")
    ap.add_argument("--csv", default=str(HERE / "audio_report.csv"), help="full report (all files)")
    ap.add_argument("--fail-csv", default=str(HERE / "audio_outside_contract.csv"), help="only the files outside the contract")
    ap.add_argument("-j", "--jobs", type=int, default=min(4, os.cpu_count() or 1))
    ap.add_argument("--strict", action="store_true", help="exit 1 when any file is outside the contract")
    ap.add_argument("--selftest", action="store_true", help="synthetic-signal tests (also (re)writes tools/audio/tests/*.wav)")
    ap.add_argument("--no-write", action="store_true", help="selftest: do not rewrite the wav files")
    a = ap.parse_args()
    if a.selftest:
        return selftest(write_files=not a.no_write)
    t0 = time.time()
    rows = scan(a.paths or DEFAULT_ROOTS, a.jobs)
    write_csv(rows, Path(a.csv))
    write_csv(rows, Path(a.fail_csv), only_fail=True)
    nf = sum(1 for r in rows if r["status"] == "FAIL")
    print(f"AUDIO_GATE SCAN {len(rows)} files in {time.time() - t0:.1f}s, {nf} outside the contract")
    print(summary(rows))
    print(f"report: {a.csv}\noutside contract: {a.fail_csv}")
    return 1 if (a.strict and nf) else 0


if __name__ == "__main__":
    sys.exit(main())
