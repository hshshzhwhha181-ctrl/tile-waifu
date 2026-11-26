#!/usr/bin/env python3
"""Tile Waifu video QA: frame-by-frame check of an AI video clip.

usage: python3 -I video_qa.py <clip.(mp4|ogv|webm)> <out_dir> [--key keyframe.png] [--loop]

What it does (no network, only ffmpeg + numpy + PIL):
  1. extracts a frame every 0.25 s -> out/frames/t_XX.XX.png and a contact sheet (sheet.jpg)
  2. zoomed contact sheets of three bands (head / hands-torso / legs) -> sheet_band{0,1,2}.jpg,
     these are what a reviewer reads to count fingers and legs
  3. drift: per sampled frame, similarity to the keyframe (or the first frame) -> catches
     identity/outfit/style drift ("morphing")
  4. pops: frame-to-frame change at native fps; a frame whose change is > 4x the clip median
     is flagged (melting hands, popping limbs, flicker)
  6. flashes: luminance jumps >10% (<=3 per second allowed) and white frames (>40% px above 225 and brighter than frame 0)
  5. --loop: seam check, last frame vs first frame (must be visually identical for start=end loops)
Writes report.json with metrics and flagged timestamps. Anatomy itself is judged by a human/LLM
reviewer on the band sheets (fingers 5+5, two legs, two arms, eyes, outfit in place).
"""
import json, os, subprocess, sys, tempfile
import numpy as np
from PIL import Image, ImageDraw

def run(cmd):
    return subprocess.run(cmd, check=True, capture_output=True, text=True).stdout

def probe(path):
    out = run(["ffprobe", "-v", "error", "-select_streams", "v:0", "-count_frames",
               "-show_entries", "stream=width,height,r_frame_rate,nb_read_frames,codec_name",
               "-show_entries", "format=duration", "-of", "json", path])
    j = json.loads(out)
    s = j["streams"][0]
    num, den = s["r_frame_rate"].split("/")
    return dict(w=int(s["width"]), h=int(s["height"]), fps=float(num) / float(den),
                frames=int(s.get("nb_read_frames", 0)), codec=s["codec_name"],
                dur=float(j["format"]["duration"]))

def all_frames(path, w, h, scale=256):
    sh = int(round(h * scale / w / 2) * 2)
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-vf", f"scale={scale}:{sh}",
                          "-f", "rawvideo", "-pix_fmt", "gray", "-"], check=True,
                         capture_output=True).stdout
    n = len(raw) // (scale * sh)
    return np.frombuffer(raw[: n * scale * sh], np.uint8).reshape(n, sh, scale).astype(np.float32), sh

def ssim(a, b):
    # global SSIM on 8x8 blocks (good enough for drift ranking)
    c1, c2 = (0.01 * 255) ** 2, (0.03 * 255) ** 2
    H, W = (a.shape[0] // 8) * 8, (a.shape[1] // 8) * 8
    A = a[:H, :W].reshape(H // 8, 8, W // 8, 8).transpose(0, 2, 1, 3).reshape(-1, 64)
    B = b[:H, :W].reshape(H // 8, 8, W // 8, 8).transpose(0, 2, 1, 3).reshape(-1, 64)
    ma, mb = A.mean(1), B.mean(1)
    va, vb = A.var(1), B.var(1)
    cov = ((A - ma[:, None]) * (B - mb[:, None])).mean(1)
    s = ((2 * ma * mb + c1) * (2 * cov + c2)) / ((ma ** 2 + mb ** 2 + c1) * (va + vb + c2))
    return float(s.mean())

def sheet(imgs, labels, cols, path, tile_w):
    tw = tile_w
    th = int(imgs[0].height * tw / imgs[0].width)
    rows = (len(imgs) + cols - 1) // cols
    S = Image.new("RGB", (cols * tw, rows * (th + 18)), (20, 20, 24))
    d = ImageDraw.Draw(S)
    for i, (im, lb) in enumerate(zip(imgs, labels)):
        x, y = (i % cols) * tw, (i // cols) * (th + 18)
        S.paste(im.resize((tw, th)), (x, y + 18))
        d.text((x + 4, y + 3), lb, fill=(255, 220, 120))
    S.save(path, quality=88)

def main():
    a = sys.argv[1:]
    if len(a) < 2:
        print(__doc__); sys.exit(1)
    clip, out = a[0], a[1]
    key = a[a.index("--key") + 1] if "--key" in a else None
    loop = "--loop" in a
    os.makedirs(os.path.join(out, "frames"), exist_ok=True)
    p = probe(clip)
    # 1. sampled frames every 0.25 s
    run(["ffmpeg", "-v", "error", "-y", "-i", clip, "-vf", "fps=4",
         os.path.join(out, "frames", "s_%03d.png")])
    files = sorted(f for f in os.listdir(os.path.join(out, "frames")) if f.startswith("s_"))
    imgs = [Image.open(os.path.join(out, "frames", f)).convert("RGB") for f in files]
    labels = [f"t={i * 0.25:.2f}s" for i in range(len(imgs))]
    sheet(imgs, labels, 6, os.path.join(out, "sheet.jpg"), 220)
    # 2. band sheets (head 0-30%, torso/hands 25-60%, legs 55-100%)
    for bi, (y0, y1) in enumerate([(0.0, 0.30), (0.25, 0.60), (0.55, 1.0)]):
        crops = [im.crop((0, int(im.height * y0), im.width, int(im.height * y1))) for im in imgs]
        sheet(crops, labels, 4, os.path.join(out, f"sheet_band{bi}.jpg"), 360)
    # 3/4. metrics on all frames
    F, sh = all_frames(clip, p["w"], p["h"])
    if key:
        k = subprocess.run(["ffmpeg", "-v", "error", "-i", key, "-vf",
                            f"scale={p['w']}:{p['h']},scale=256:{sh}", "-f", "rawvideo",
                            "-pix_fmt", "gray", "-"], check=True, capture_output=True).stdout
        K = np.frombuffer(k, np.uint8).reshape(sh, 256).astype(np.float32)
    else:
        K = F[0]
    step = max(1, int(round(p["fps"] / 4)))
    drift = [(round(i / p["fps"], 2), round(ssim(F[i], K), 4)) for i in range(0, len(F), step)]
    diffs = np.array([np.abs(F[i + 1] - F[i]).mean() for i in range(len(F) - 1)])
    med = float(np.median(diffs)) if len(diffs) else 0.0
    pops = [dict(t=round((i + 1) / p["fps"], 3), diff=round(float(d), 2))
            for i, d in enumerate(diffs) if med > 0 and d > 4 * med and d > 2.0]
    rep = dict(clip=clip, probe=p, sampled_frames=len(imgs), drift_vs_key=drift,
               drift_min=min(x[1] for x in drift), frame_diff_median=round(med, 3),
               frame_diff_max=round(float(diffs.max()), 3) if len(diffs) else 0, pops=pops)
    if loop:
        rep["seam_ssim_last_vs_first"] = round(ssim(F[-1], F[0]), 4)
        rep["seam_ssim_last_vs_key"] = round(ssim(F[-1], K), 4)
        rep["seam_meanabs_last_vs_first"] = round(float(np.abs(F[-1] - F[0]).mean()), 2)
    # 6. photosensitivity (HEROINES §2 / UX §6.7): <=3 flashes per second, no white frames
    lum = F.mean(axis=(1, 2)) / 255.0
    jumps = [i for i in range(1, len(lum)) if abs(lum[i] - lum[i - 1]) > 0.10]
    fps = p["fps"]
    max_per_s = max([sum(1 for j in jumps if t <= j < t + fps) for t in range(0, max(1, len(lum)), max(1, int(fps // 4)))] or [0])
    white = [round(i / fps, 2) for i in range(len(F)) if (F[i] > 225).mean() > 0.40 and lum[i] - lum[0] > 0.12]
    rep.update(flash_jumps=len(jumps), flash_max_per_s=max_per_s, white_frames=white[:20],
               luma_peak=round(float(lum.max()), 3))
    # verdict thresholds (tuned on the 0.9 Kling loops; see VIDEO_BIBLE.md §6)
    flags = []
    if rep["drift_min"] < 0.55: flags.append("drift: frame far from keyframe (identity/outfit/camera moved)")
    if pops: flags.append(f"pops: {len(pops)} abrupt frame changes")
    if loop and rep["seam_meanabs_last_vs_first"] > 3.0: flags.append("seam: loop jump visible")
    if max_per_s > 3: flags.append("flash: more than 3 luminance flashes per second")
    if white: flags.append("flash: white frame(s)")
    rep["luma_base"] = round(float(lum[0]), 3)
    if rep["luma_peak"] > 0.70 and rep["luma_peak"] - rep["luma_base"] > 0.12:
        flags.append("brightness: light burst pushes the frame above 70% luminance")
    rep["auto_flags"] = flags
    json.dump(rep, open(os.path.join(out, "report.json"), "w"), indent=1, ensure_ascii=False)
    print(json.dumps({k: rep[k] for k in rep if k not in ("drift_vs_key",)}, ensure_ascii=False))

if __name__ == "__main__":
    main()
