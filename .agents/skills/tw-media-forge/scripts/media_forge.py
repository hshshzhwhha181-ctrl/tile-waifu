#!/usr/bin/env python3
"""Tile Waifu Media Forge CLI (Pillow + FFmpeg).

Subcommands:
  video      <in> <out.ogv> --preset rustore_hq|yandex_lite [--mute] [--xfade <sec>]
  voice      <in> <out.ogg> [--lufs -16.0] [--allow-silent]
  icon-pack  <in.png> <out_dir>
  qc-sheet   <in_image_or_video> <out.png>
  budget     <game_dir> [--json <out.json>]
"""
from __future__ import annotations

import argparse
import glob
import json
import math
import os
import re
import shutil
import subprocess
import sys
import tempfile
from collections import defaultdict
from pathlib import Path
from typing import Dict, List, Optional, Tuple

from PIL import Image, ImageDraw, ImageFilter, ImageOps


IMAGE_EXTS = {".png", ".webp", ".jpg", ".jpeg", ".bmp", ".tga"}
VIDEO_EXTS = {".mp4", ".ogv", ".webm", ".mov", ".mkv", ".avi", ".m4v"}
AUDIO_EXTS = {".ogg", ".mp3", ".wav", ".flac", ".m4a", ".opus"}
FONT_EXTS = {".ttf", ".otf", ".woff", ".woff2"}
CODE_DATA_EXTS = {".gd", ".gdshader", ".tscn", ".tres", ".json", ".cfg", ".godot", ".md", ".txt"}

YANDEX_BUDGET_MB = 100.0


def _reconfigure_utf8() -> None:
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            try:
                stream.reconfigure(encoding="utf-8")
            except Exception:
                pass


def find_ffmpeg_pair() -> Tuple[str, str]:
    """Auto-discover ffmpeg.exe and ffprobe.exe on PATH or WinGet Gyan.FFmpeg location."""
    candidates: List[Path] = []
    env_ff = os.environ.get("FFMPEG_BIN", "").strip()
    if env_ff:
        candidates.append(Path(env_ff))

    which_ff = shutil.which("ffmpeg")
    if which_ff:
        candidates.append(Path(which_ff))

    local_app = os.environ.get("LOCALAPPDATA", "")
    user_prof = os.environ.get("USERPROFILE", r"C:\Users\ADMIN")
    winget_roots = [
        os.path.join(local_app, "Microsoft", "WinGet", "Packages") if local_app else "",
        os.path.join(user_prof, "AppData", "Local", "Microsoft", "WinGet", "Packages"),
    ]
    for root in winget_roots:
        if root and os.path.isdir(root):
            matches = sorted(
                glob.glob(os.path.join(root, "Gyan.FFmpeg*", "**", "bin", "ffmpeg.exe"), recursive=True),
                reverse=True,
            )
            for m in matches:
                candidates.append(Path(m))

    for fixed in (r"C:\Program Files\ffmpeg\bin\ffmpeg.exe", r"C:\ffmpeg\bin\ffmpeg.exe"):
        candidates.append(Path(fixed))

    ffmpeg_path: Optional[Path] = None
    for cand in candidates:
        if cand.is_file():
            ffmpeg_path = cand.resolve()
            break

    if ffmpeg_path is None:
        raise FileNotFoundError(
            "ffmpeg.exe not found on PATH or WinGet Gyan.FFmpeg packages. Install Gyan.FFmpeg or set FFMPEG_BIN."
        )

    probe_sibling = ffmpeg_path.with_name("ffprobe.exe" if ffmpeg_path.suffix.lower() == ".exe" else "ffprobe")
    if probe_sibling.is_file():
        ffprobe_path = str(probe_sibling)
    else:
        which_probe = shutil.which("ffprobe")
        if not which_probe:
            raise FileNotFoundError(f"ffprobe not found alongside {ffmpeg_path} or on PATH.")
        ffprobe_path = which_probe

    return str(ffmpeg_path), ffprobe_path


def probe_media(ffprobe: str, media_path: Path) -> Dict:
    proc = subprocess.run(
        [
            ffprobe,
            "-v",
            "error",
            "-show_entries",
            "stream=index,codec_type,codec_name,width,height,r_frame_rate,channels,sample_rate",
            "-show_entries",
            "format=duration,size,bit_rate",
            "-of",
            "json",
            str(media_path),
        ],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        check=True,
    )
    return json.loads(proc.stdout)


def _even(n: float) -> int:
    val = max(2, int(round(n / 2.0) * 2))
    return val


def compute_scaled_dims(src_w: int, src_h: int, short_side: int) -> Tuple[int, int]:
    if src_w <= src_h:
        out_w = _even(short_side)
        out_h = _even(src_h * (out_w / max(1, src_w)))
    else:
        out_h = _even(short_side)
        out_w = _even(src_w * (out_h / max(1, src_h)))
    return out_w, out_h


# ---------------------------------------------------------------------------
# 1. VIDEO SUBCOMMAND
# ---------------------------------------------------------------------------

def cmd_video(args: argparse.Namespace) -> int:
    ffmpeg, ffprobe = find_ffmpeg_pair()
    in_path = Path(args.input).resolve()
    out_path = Path(args.output).resolve()
    if not in_path.is_file():
        print(f"ERROR: Input video not found: {in_path}", file=sys.stderr)
        return 2
    out_path.parent.mkdir(parents=True, exist_ok=True)

    info = probe_media(ffprobe, in_path)
    streams = info.get("streams", [])
    v_stream = next((s for s in streams if s.get("codec_type") == "video"), None)
    has_audio = any(s.get("codec_type") == "audio" for s in streams)
    if v_stream is None:
        print(f"ERROR: No video stream found in {in_path}", file=sys.stderr)
        return 2

    src_w = int(v_stream.get("width", 720))
    src_h = int(v_stream.get("height", 1280))
    src_dur = float(info.get("format", {}).get("duration", 4.5) or 4.5)
    xfade = max(0.0, float(args.xfade or 0.0))
    eff_dur = max(0.5, src_dur - xfade) if xfade > 0 else max(0.5, src_dur)

    if args.preset == "rustore_hq":
        target_w, target_h = compute_scaled_dims(src_w, src_h, 720)
        # Aim ~2.05 MB for a standard 4-5s clip (clamped 2200k..4200k for shorter/longer clips)
        target_bytes = 2.05 * 1024 * 1024 if 3.0 <= eff_dur <= 6.5 else eff_dur * 420 * 1024
        kbps = int(max(2200, min(4200, round((target_bytes * 8.0 / eff_dur) / 1000.0))))
        q_fallback = "8"
    else:  # yandex_lite
        target_w, target_h = compute_scaled_dims(src_w, src_h, 480)
        # Aim ~450 KB for a standard 4-5s clip (clamped 480k..950k for shorter/longer clips)
        target_bytes = 450 * 1024 if 2.8 <= eff_dur <= 6.5 else eff_dur * 95 * 1024
        kbps = int(max(420, min(950, round((target_bytes * 8.0 / eff_dur) / 1000.0))))
        q_fallback = "5"

    vf_core = (
        f"scale={target_w}:{target_h}:force_original_aspect_ratio=increase:flags=lanczos,"
        f"crop={target_w}:{target_h},fps=24,format=yuv420p"
    )

    mute = bool(args.mute) or (not has_audio) or (xfade > 0.0)
    audio_args = ["-an"] if mute else ["-c:a", "libvorbis", "-q:a", "3", "-ac", "2", "-ar", "44100"]

    with tempfile.TemporaryDirectory(prefix="tw_ogv_") as tmpdir:
        passlog = os.path.join(tmpdir, "theora_2pass")
        null_sink = "NUL" if os.name == "nt" else "/dev/null"

        if xfade > 0.0:
            if src_dur <= 2.2 * xfade:
                print(f"ERROR: Clip duration ({src_dur:.2f}s) too short for --xfade {xfade}s.", file=sys.stderr)
                return 2
            offset = round(src_dur - 2.0 * xfade, 3)
            fc = (
                f"[0:v]{vf_core},split[a][b];"
                f"[a]trim=start={xfade},setpts=PTS-STARTPTS[body];"
                f"[b]trim=0:{xfade},setpts=PTS-STARTPTS[head];"
                f"[body][head]xfade=transition=fade:duration={xfade}:offset={offset}[v]"
            )
            filter_spec = ["-filter_complex", fc, "-map", "[v]"]
        else:
            filter_spec = ["-vf", vf_core]

        # Two-pass libtheora encode for predictable RuStore / Yandex file budgets
        cmd_p1 = [
            ffmpeg, "-v", "error", "-y", "-i", str(in_path),
            *filter_spec,
            "-c:v", "libtheora", "-b:v", f"{kbps}k", "-g", "24",
            "-pass", "1", "-passlogfile", passlog,
            "-an", "-f", "ogv", null_sink,
        ]
        cmd_p2 = [
            ffmpeg, "-v", "error", "-y", "-i", str(in_path),
            *filter_spec,
            "-c:v", "libtheora", "-b:v", f"{kbps}k", "-g", "24",
            "-pass", "2", "-passlogfile", passlog,
            *audio_args, str(out_path),
        ]

        p1 = subprocess.run(cmd_p1, capture_output=True, text=True)
        p2 = subprocess.run(cmd_p2, capture_output=True, text=True) if p1.returncode == 0 else p1
        if p2.returncode != 0:
            # Fallback to single-pass quality mode if 2-pass fails on ultra-short input
            cmd_fb = [
                ffmpeg, "-v", "error", "-y", "-i", str(in_path),
                *filter_spec,
                "-c:v", "libtheora", "-q:v", q_fallback, "-g", "24",
                *audio_args, str(out_path),
            ]
            subprocess.run(cmd_fb, check=True)

    out_info = probe_media(ffprobe, out_path)
    out_vs = next((s for s in out_info.get("streams", []) if s.get("codec_type") == "video"), {})
    out_has_aud = any(s.get("codec_type") == "audio" for s in out_info.get("streams", []))
    out_dur = float(out_info.get("format", {}).get("duration", eff_dur) or eff_dur)
    out_bytes = out_path.stat().st_size
    size_str = f"{out_bytes / (1024 * 1024):.2f} MB ({out_bytes / 1024:.1f} KB)"

    print(
        f"[media_forge:video] OK  preset={args.preset}  "
        f"{out_vs.get('width', target_w)}x{out_vs.get('height', target_h)} @ 24fps  "
        f"dur={out_dur:.2f}s  audio={'muted' if not out_has_aud else 'vorbis'}  size={size_str}"
    )
    print(f"  -> {out_path}")
    return 0


# ---------------------------------------------------------------------------
# 2. VOICE SUBCOMMAND
# ---------------------------------------------------------------------------

def measure_volume_db(ffmpeg: str, audio_path: Path) -> Tuple[float, float]:
    null_sink = "NUL" if os.name == "nt" else "/dev/null"
    proc = subprocess.run(
        [ffmpeg, "-hide_banner", "-i", str(audio_path), "-af", "volumedetect", "-f", "null", null_sink],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    log = (proc.stdout or "") + "\n" + (proc.stderr or "")
    m_mean = re.search(r"mean_volume:\s*([-\d\.]+)\s*dB", log)
    m_max = re.search(r"max_volume:\s*([-\d\.]+)\s*dB", log)
    mean_db = float(m_mean.group(1)) if m_mean else -91.0
    max_db = float(m_max.group(1)) if m_max else -91.0
    return mean_db, max_db


def cmd_voice(args: argparse.Namespace) -> int:
    ffmpeg, ffprobe = find_ffmpeg_pair()
    in_path = Path(args.input).resolve()
    out_path = Path(args.output).resolve()
    if not in_path.is_file():
        print(f"ERROR: Input audio not found: {in_path}", file=sys.stderr)
        return 2
    out_path.parent.mkdir(parents=True, exist_ok=True)

    target_lufs = float(args.lufs)
    af_chain = f"loudnorm=I={target_lufs:.1f}:TP=-1.5:LRA=11"
    subprocess.run(
        [
            ffmpeg,
            "-v",
            "error",
            "-y",
            "-i",
            str(in_path),
            "-vn",
            "-af",
            af_chain,
            "-ac",
            "1",
            "-ar",
            "44100",
            "-c:a",
            "libvorbis",
            "-q:a",
            "5",
            str(out_path),
        ],
        check=True,
    )

    info = probe_media(ffprobe, out_path)
    dur = float(info.get("format", {}).get("duration", 0.0) or 0.0)
    mean_db, peak_db = measure_volume_db(ffmpeg, out_path)
    kb = out_path.stat().st_size / 1024.0

    is_silent = (dur < 0.12) or (peak_db <= -42.0) or (mean_db <= -55.0)
    status = "SILENT_WARNING" if is_silent else "OK"

    print(
        f"[media_forge:voice] {status}  dur={dur:.2f}s  peak={peak_db:+.1f} dB  "
        f"mean={mean_db:+.1f} dB  target={target_lufs:+.1f} LUFS  44.1kHz mono  size={kb:.1f} KB"
    )
    print(f"  -> {out_path}")

    if is_silent and not args.allow_silent:
        print(
            "ERROR: Output voice clip appears silent or truncated (peak <= -42 dB or dur < 0.12s).",
            file=sys.stderr,
        )
        return 1
    return 0


# ---------------------------------------------------------------------------
# 3. ICON-PACK SUBCOMMAND
# ---------------------------------------------------------------------------

def render_warm_lacquer_bg(size: int) -> Image.Image:
    """Generate Tile Waifu 'Silence & Lacquer' warm plum-crimson-gold gradient."""
    img = Image.new("RGBA", (size, size))
    px = img.load()
    cx, cy = size * 0.5, size * 0.44
    max_r = size * 0.74
    for y in range(size):
        vy = y / max(1, size - 1)
        # Base vertical lacquer blend: deep plum (#260d1a) -> rich burgundy (#481729) -> dark mahogany (#1d0913)
        base_r = 38.0 + 34.0 * math.sin(vy * math.pi)
        base_g = 13.0 + 11.0 * math.sin(vy * math.pi)
        base_b = 26.0 + 16.0 * math.sin(vy * math.pi)
        for x in range(size):
            dist = math.hypot(x - cx, y - cy) / max_r
            glow = max(0.0, 1.0 - dist * dist)
            # Warm lantern amber-crimson core glow
            r = int(min(255, round(base_r + 88.0 * glow)))
            g = int(min(255, round(base_g + 42.0 * (glow ** 1.25))))
            b = int(min(255, round(base_b + 28.0 * glow)))
            px[x, y] = (r, g, b, 255)
    return img


def has_meaningful_alpha(im: Image.Image) -> bool:
    if im.mode != "RGBA":
        return False
    alpha = im.getchannel("A")
    lo, _hi = alpha.getextrema()
    return lo < 245


def center_square_crop(im: Image.Image) -> Image.Image:
    w, h = im.size
    side = min(w, h)
    left = (w - side) // 2
    top = int((h - side) * 0.35) if h > w else (h - side) // 2
    return im.crop((left, top, left + side, top + side))


def cmd_icon_pack(args: argparse.Namespace) -> int:
    in_path = Path(args.input).resolve()
    out_dir = Path(args.out_dir).resolve()
    if not in_path.is_file():
        print(f"ERROR: Input icon image not found: {in_path}", file=sys.stderr)
        return 2
    out_dir.mkdir(parents=True, exist_ok=True)

    src = Image.open(in_path).convert("RGBA")
    src_sq = center_square_crop(src)
    cutout_mode = has_meaningful_alpha(src_sq)

    # 1. icon_bg_432.png — warm lacquer gradient (432x432)
    bg_432 = render_warm_lacquer_bg(432)
    bg_path = out_dir / "icon_bg_432.png"
    bg_432.save(bg_path, format="PNG", optimize=True)

    # 2. icon_fg_432.png — safe 66% center zone (285x285 centered inside 432x432)
    fg_canvas = Image.new("RGBA", (432, 432), (0, 0, 0, 0))
    safe_px = int(round(432 * 0.66))  # 285 px (66% safe zone)
    pad = (432 - safe_px) // 2        # 73 px margin on each side

    fitted_safe = src_sq.resize((safe_px, safe_px), Image.Resampling.LANCZOS)
    if cutout_mode:
        fg_canvas.alpha_composite(fitted_safe, (pad, pad))
    else:
        # Mask opaque square art into an anti-aliased medallion with a warm gold rim inside the 66% safe zone
        ss = safe_px * 4
        mask_hi = Image.new("L", (ss, ss), 0)
        md = ImageDraw.Draw(mask_hi)
        md.ellipse((8, 8, ss - 9, ss - 9), fill=255)
        mask = mask_hi.resize((safe_px, safe_px), Image.Resampling.LANCZOS)

        medallion = Image.new("RGBA", (safe_px, safe_px), (0, 0, 0, 0))
        medallion.paste(fitted_safe, (0, 0), mask)

        ring_hi = Image.new("RGBA", (ss, ss), (0, 0, 0, 0))
        rd = ImageDraw.Draw(ring_hi)
        rd.ellipse((10, 10, ss - 11, ss - 11), outline=(232, 196, 126, 235), width=12)
        ring = ring_hi.resize((safe_px, safe_px), Image.Resampling.LANCZOS)
        medallion.alpha_composite(ring, (0, 0))
        fg_canvas.alpha_composite(medallion, (pad, pad))

    fg_path = out_dir / "icon_fg_432.png"
    fg_canvas.save(fg_path, format="PNG", optimize=True)

    # 3. icon_192.png — 192x192 main launcher icon
    icon_192 = render_warm_lacquer_bg(192)
    if cutout_mode:
        art_192 = src_sq.resize((172, 172), Image.Resampling.LANCZOS)
        icon_192.alpha_composite(art_192, (10, 10))
    else:
        art_192 = src_sq.resize((192, 192), Image.Resampling.LANCZOS)
        icon_192.alpha_composite(art_192, (0, 0))
        border = ImageDraw.Draw(icon_192)
        border.rounded_rectangle((1, 1, 190, 190), radius=36, outline=(232, 196, 126, 180), width=2)

    i192_path = out_dir / "icon_192.png"
    icon_192.save(i192_path, format="PNG", optimize=True)

    print(f"[media_forge:icon-pack] Generated 3 Android launcher icons in {out_dir}:")
    for p, note in (
        (i192_path, "192x192 RGBA main launcher icon"),
        (fg_path, f"432x432 RGBA adaptive foreground (safe 66% zone: {safe_px}x{safe_px} @ +{pad},+{pad})"),
        (bg_path, "432x432 RGBA warm lacquer gradient background"),
    ):
        print(f"  - {p.name:<16s} {p.stat().st_size / 1024:6.1f} KB  ({note})")
    return 0


# ---------------------------------------------------------------------------
# 4. QC-SHEET SUBCOMMAND
# ---------------------------------------------------------------------------

def _fit_into_box(im: Image.Image, box_w: int, box_h: int) -> Image.Image:
    scale = min(box_w / max(1, im.width), box_h / max(1, im.height))
    nw = max(1, int(round(im.width * scale)))
    nh = max(1, int(round(im.height * scale)))
    resized = im.resize((nw, nh), Image.Resampling.LANCZOS)
    canvas = Image.new("RGB", (box_w, box_h), (28, 22, 33))
    canvas.paste(resized, ((box_w - nw) // 2, (box_h - nh) // 2))
    return canvas


def _cover_box(im: Image.Image, box_w: int, box_h: int) -> Image.Image:
    return ImageOps.fit(im.convert("RGB"), (box_w, box_h), method=Image.Resampling.LANCZOS)


def _composite_on_dark(im: Image.Image) -> Image.Image:
    rgba = im.convert("RGBA")
    bg = Image.new("RGBA", rgba.size, (32, 24, 38, 255))
    bg.alpha_composite(rgba)
    return bg.convert("RGB")


def build_image_qc_sheet(src_im: Image.Image, title: str, out_path: Path) -> None:
    rgb = _composite_on_dark(src_im)
    w, h = rgb.size

    # Crop regions tailored for portrait/character anatomy inspection
    face_box = (int(w * 0.16), int(h * 0.02), int(w * 0.84), int(h * 0.32))
    hands_box = (int(w * 0.06), int(h * 0.25), int(w * 0.94), int(h * 0.62))
    lower_box = (int(w * 0.10), int(h * 0.54), int(w * 0.90), int(h * 0.99))

    sheet_w, sheet_h = 1680, 1120
    sheet = Image.new("RGB", (sheet_w, sheet_h), (20, 16, 24))
    draw = ImageDraw.Draw(sheet)

    # Header bar
    draw.rectangle((0, 0, sheet_w, 52), fill=(36, 22, 34))
    draw.line((0, 52, sheet_w, 52), fill=(214, 174, 102), width=2)
    draw.text(
        (20, 18),
        f"TILE WAIFU ANATOMY QC  |  {title} ({w}x{h})  |  CHECK: 2 arms, 2 legs, 5+5 fingers, adult face, LW match, 0 text",
        fill=(255, 234, 190),
    )

    # Left panel: Full frame with crop zone markers
    full_guide = rgb.copy()
    gd = ImageDraw.Draw(full_guide)
    for bx, col in ((face_box, (120, 220, 255)), (hands_box, (255, 214, 110)), (lower_box, (255, 140, 175))):
        gd.rectangle(bx, outline=col, width=max(2, w // 320))

    left_panel = _fit_into_box(full_guide, 580, 1016)
    sheet.paste(left_panel, (20, 80))
    draw.rectangle((20, 80, 600, 1096), outline=(120, 96, 74), width=2)
    draw.text((26, 62), "1. FULL FRAME (crop zones overlaid)", fill=(236, 212, 164))

    # Top-right: Zoomed Face Crop
    face_crop = _cover_box(rgb.crop(face_box), 1040, 476)
    sheet.paste(face_crop, (620, 80))
    draw.rectangle((620, 80, 1660, 556), outline=(120, 220, 255), width=2)
    draw.text((626, 62), "2. ZOOMED FACE / HEAD CROP (eyes, adult proportions, hair)", fill=(160, 232, 255))

    # Bottom-right left half: Zoomed Hands / Prop Crop
    hands_crop = _cover_box(rgb.crop(hands_box), 510, 504)
    sheet.paste(hands_crop, (620, 592))
    draw.rectangle((620, 592, 1130, 1096), outline=(255, 214, 110), width=2)
    draw.text((626, 572), "3. ZOOMED HANDS / TORSO (5+5 fingers, grip)", fill=(255, 224, 140))

    # Bottom-right right half: Zoomed Lower / Legwear Crop
    lower_crop = _cover_box(rgb.crop(lower_box), 510, 504)
    sheet.paste(lower_crop, (1150, 592))
    draw.rectangle((1150, 592, 1660, 1096), outline=(255, 140, 175), width=2)
    draw.text((1156, 572), "4. ZOOMED LOWER / LEGS (2 legs, LW symmetry)", fill=(255, 175, 200))

    out_path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(out_path, format="PNG", optimize=True)


def build_video_qc_sheet(
    ffmpeg: str, ffprobe: str, video_path: Path, out_path: Path
) -> Tuple[int, int, float]:
    info = probe_media(ffprobe, video_path)
    vs = next((s for s in info.get("streams", []) if s.get("codec_type") == "video"), {})
    vw = int(vs.get("width", 720))
    vh = int(vs.get("height", 1280))
    dur = float(info.get("format", {}).get("duration", 3.0) or 3.0)
    codec = vs.get("codec_name", "video")

    ratios = (0.08, 0.50, 0.92)
    timestamps = [max(0.0, min(max(0.0, dur - 0.05), dur * r)) for r in ratios]

    frames: List[Tuple[float, Image.Image]] = []
    with tempfile.TemporaryDirectory(prefix="tw_qc_") as tmpdir:
        for idx, ts in enumerate(timestamps):
            frame_png = Path(tmpdir) / f"f_{idx}.png"
            subprocess.run(
                [
                    ffmpeg,
                    "-v",
                    "error",
                    "-y",
                    "-ss",
                    f"{ts:.3f}",
                    "-i",
                    str(video_path),
                    "-frames:v",
                    "1",
                    str(frame_png),
                ],
                check=True,
            )
            if not frame_png.is_file():
                # Fallback near t=0 if end seek overshot container packets
                subprocess.run(
                    [ffmpeg, "-v", "error", "-y", "-i", str(video_path), "-frames:v", "1", str(frame_png)],
                    check=True,
                )
            frames.append((ts, Image.open(frame_png).convert("RGB")))

    sheet_w, sheet_h = 1680, 1260
    sheet = Image.new("RGB", (sheet_w, sheet_h), (20, 16, 24))
    draw = ImageDraw.Draw(sheet)

    draw.rectangle((0, 0, sheet_w, 52), fill=(36, 22, 34))
    draw.line((0, 52, sheet_w, 52), fill=(214, 174, 102), width=2)
    draw.text(
        (20, 18),
        f"TILE WAIFU VIDEO QC (3 FRAMES)  |  {video_path.name} ({vw}x{vh}, {codec}, {dur:.2f}s)  |  Full + Face + Lower/Hand Crops",
        fill=(255, 234, 190),
    )

    row_h = 388
    for r_idx, (ts, fim) in enumerate(frames):
        y0 = 66 + r_idx * row_h
        fw, fh = fim.size
        face_box = (int(fw * 0.14), int(fh * 0.02), int(fw * 0.86), int(fh * 0.36))
        lower_hand_box = (int(fw * 0.06), int(fh * 0.32), int(fw * 0.94), int(fh * 0.96))

        label_tag = ("START", "MID", "END")[r_idx]
        draw.text((22, y0 + 2), f"FRAME {r_idx + 1}/3 [{label_tag} @ t={ts:.2f}s] — Full Frame", fill=(236, 212, 164))
        full_tile = _fit_into_box(fim, 500, row_h - 34)
        sheet.paste(full_tile, (20, y0 + 22))
        draw.rectangle((20, y0 + 22, 520, y0 + row_h - 12), outline=(120, 96, 74), width=2)

        draw.text((542, y0 + 2), f"t={ts:.2f}s — Zoomed Face Crop", fill=(160, 232, 255))
        face_tile = _cover_box(fim.crop(face_box), 550, row_h - 34)
        sheet.paste(face_tile, (540, y0 + 22))
        draw.rectangle((540, y0 + 22, 1090, y0 + row_h - 12), outline=(120, 220, 255), width=2)

        draw.text((1112, y0 + 2), f"t={ts:.2f}s — Zoomed Lower / Hand Crop", fill=(255, 198, 150))
        lh_tile = _cover_box(fim.crop(lower_hand_box), 550, row_h - 34)
        sheet.paste(lh_tile, (1110, y0 + 22))
        draw.rectangle((1110, y0 + 22, 1660, y0 + row_h - 12), outline=(255, 180, 140), width=2)

    out_path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(out_path, format="PNG", optimize=True)
    return vw, vh, dur


def cmd_qc_sheet(args: argparse.Namespace) -> int:
    in_path = Path(args.input).resolve()
    out_path = Path(args.output).resolve()
    if not in_path.is_file():
        print(f"ERROR: Input file not found: {in_path}", file=sys.stderr)
        return 2

    ext = in_path.suffix.lower()
    if ext in VIDEO_EXTS:
        ffmpeg, ffprobe = find_ffmpeg_pair()
        vw, vh, dur = build_video_qc_sheet(ffmpeg, ffprobe, in_path, out_path)
        sz_kb = out_path.stat().st_size / 1024.0
        print(
            f"[media_forge:qc-sheet] OK (video 3-frame sheet: {vw}x{vh}, {dur:.2f}s) -> {out_path} ({sz_kb:.1f} KB)"
        )
        return 0

    if ext in IMAGE_EXTS:
        with Image.open(in_path) as im:
            w, h = im.size
            build_image_qc_sheet(im, in_path.name, out_path)
        sz_kb = out_path.stat().st_size / 1024.0
        print(
            f"[media_forge:qc-sheet] OK (image anatomy sheet: {w}x{h}) -> {out_path} ({sz_kb:.1f} KB)"
        )
        return 0

    print(f"ERROR: Unsupported media extension '{ext}' for qc-sheet.", file=sys.stderr)
    return 2


# ---------------------------------------------------------------------------
# 5. BUDGET SUBCOMMAND
# ---------------------------------------------------------------------------

CATEGORY_ORDER = [
    "UI, HUD & Table Art",
    "Heroines, Outfits & Rigs",
    "Backgrounds & Scenes",
    "Video Clips (.ogv/.mp4)",
    "Music & Stings",
    "Voice-Over",
    "Sound Effects (SFX)",
    "Code, Scenes & Data",
    "16+ / Boudoir Art (RuStore)",
    "Fonts",
    "Other Assets",
]


def classify_game_file(rel_posix: str, ext: str) -> Tuple[str, bool]:
    """Return (category_name, included_in_yandex_sfw)."""
    low = rel_posix.lower()

    # RuStore-only 16+/bold/boudoir content excluded from Yandex Games SFW <=100 MB preset
    if (
        "/cg_16/" in low
        or "/salon_vip/" in low
        or "legwear_apk" in low
        or re.search(r"(?:^|[/_])bold[/_.]", low)
    ):
        return "16+ / Boudoir Art (RuStore)", False

    if ext in VIDEO_EXTS or "/video/" in low or "/ult_video/" in low:
        return "Video Clips (.ogv/.mp4)", True

    if ext in FONT_EXTS or "/fonts/" in low:
        if ext in (".txt", ".md"):
            return "Fonts", True
        return "Fonts", True

    if ext in AUDIO_EXTS:
        if "/voice/" in low or "voice" in Path(low).parts:
            return "Voice-Over", True
        if "/music/" in low or "sting" in Path(low).name or "motif_" in Path(low).name:
            return "Music & Stings", True
        return "Sound Effects (SFX)", True

    if low.startswith(("scripts/", "scenes/", "shaders/", "data/")) or ext in CODE_DATA_EXTS:
        return "Code, Scenes & Data", True

    if any(
        seg in low
        for seg in (
            "assets/hero/",
            "assets/outfits/",
            "assets/v08/emotions/",
            "assets/v09/summon/",
            "assets/v10/rig/",
            "assets/v10/wave1/",
        )
    ):
        return "Heroines, Outfits & Rigs", True

    if any(
        seg in low
        for seg in (
            "assets/bg/",
            "assets/v07/",
            "assets/v10/salon/",
            "assets/v10/tower/",
            "assets/v10/adventure/",
        )
    ):
        return "Backgrounds & Scenes", True

    if ext in IMAGE_EXTS or low.startswith("assets/"):
        return "UI, HUD & Table Art", True

    return "Other Assets", True


def cmd_budget(args: argparse.Namespace) -> int:
    game_dir = Path(args.game_dir).resolve()
    if not game_dir.is_dir():
        print(f"ERROR: Game directory not found: {game_dir}", file=sys.stderr)
        return 2

    cat_stats: Dict[str, List[int]] = {c: [0, 0, 0] for c in CATEGORY_ORDER}  # [files, rustore_bytes, yandex_raw_bytes]
    folder_bytes: Dict[str, int] = defaultdict(int)
    godot_cache_files = 0
    godot_cache_bytes = 0
    meta_files = 0
    meta_bytes = 0
    video_count = 0
    video_bytes = 0

    for dp, dirs, files in os.walk(game_dir):
        rel_dp = os.path.relpath(dp, game_dir).replace("\\", "/")
        if rel_dp == ".godot" or rel_dp.startswith(".godot/"):
            for fn in files:
                fp = os.path.join(dp, fn)
                try:
                    godot_cache_bytes += os.path.getsize(fp)
                    godot_cache_files += 1
                except OSError:
                    pass
            continue

        for fn in files:
            fp = os.path.join(dp, fn)
            try:
                sz = os.path.getsize(fp)
            except OSError:
                continue

            if fn.endswith(".import") or fn.endswith(".uid"):
                meta_files += 1
                meta_bytes += sz
                continue

            rel_file = fn if rel_dp == "." else f"{rel_dp}/{fn}"
            ext = os.path.splitext(fn)[1].lower()
            cat, in_yandex = classify_game_file(rel_file, ext)
            if cat not in cat_stats:
                cat_stats[cat] = [0, 0, 0]
            cat_stats[cat][0] += 1
            cat_stats[cat][1] += sz
            if in_yandex:
                cat_stats[cat][2] += sz

            if cat == "Video Clips (.ogv/.mp4)":
                video_count += 1
                video_bytes += sz

            parts = rel_file.split("/")
            if parts[0] == "assets":
                bucket = "/".join(parts[:3]) if parts[1:2] == ["v10"] and len(parts) >= 3 else "/".join(parts[:2])
            else:
                bucket = parts[0]
            folder_bytes[bucket] += sz

    total_files = sum(v[0] for v in cat_stats.values())
    rustore_bytes = sum(v[1] for v in cat_stats.values())
    yandex_raw_bytes = sum(v[2] for v in cat_stats.values())

    rustore_mb = rustore_bytes / (1024 * 1024)
    yandex_raw_mb = yandex_raw_bytes / (1024 * 1024)

    # Estimate Yandex Lite video savings (~450 KB per OGV clip when downscaled via --preset yandex_lite)
    est_lite_video_bytes = min(video_bytes, video_count * 450 * 1024)
    yandex_lite_proj_mb = (yandex_raw_bytes - video_bytes + est_lite_video_bytes) / (1024 * 1024)

    print(f"TILE WAIFU ASSET BUDGET REPORT — {game_dir.as_posix()}")
    print("+-----------------------------+--------+--------------+---------+------------------+")
    print("| Category                    |  Files | RuStore (MB) |  Share  | Yandex SFW (MB)  |")
    print("+-----------------------------+--------+--------------+---------+------------------+")

    ordered_cats = [c for c in CATEGORY_ORDER if cat_stats.get(c, [0, 0, 0])[0] > 0]
    for cat in ordered_cats:
        cnt, rs_b, yn_b = cat_stats[cat]
        rs_m = rs_b / (1024 * 1024)
        yn_m = yn_b / (1024 * 1024)
        share = (100.0 * rs_b / rustore_bytes) if rustore_bytes > 0 else 0.0
        print(f"| {cat:<27s} | {cnt:>6d} | {rs_m:>12.2f} | {share:>6.1f}% | {yn_m:>16.2f} |")

    print("+-----------------------------+--------+--------------+---------+------------------+")
    print(f"| {'TOTAL SHIPPED SOURCE':<27s} | {total_files:>6d} | {rustore_mb:>12.2f} | {'100.0%':>7s} | {yandex_raw_mb:>16.2f} |")
    print("+-----------------------------+--------+--------------+---------+------------------+")
    print(
        f"  Editor-only (excluded above): .import/.uid metadata = {meta_bytes / (1024 * 1024):.2f} MB ({meta_files} files), "
        f".godot/ cache = {godot_cache_bytes / (1024 * 1024):.2f} MB ({godot_cache_files} files)"
    )

    print("\nPLATFORM TARGETS:")
    print(f"  1. RuStore 1.0 (Full 16+/18+ APK):   {rustore_mb:6.2f} MB source payload  [OK — no 100 MB cap]")

    delta_raw = yandex_raw_mb - YANDEX_BUDGET_MB
    delta_lite = yandex_lite_proj_mb - YANDEX_BUDGET_MB
    y_status = (
        f"PASS ({abs(delta_raw):.2f} MB headroom)"
        if delta_raw <= 0
        else f"OVER BUDGET (+{delta_raw:.2f} MB raw / +{delta_lite:.2f} MB after yandex_lite OGV)"
    )
    print(f"  2. Yandex Games 1.1 (<= {YANDEX_BUDGET_MB:.0f} MB SFW): {yandex_raw_mb:6.2f} MB raw SFW ({yandex_lite_proj_mb:.2f} MB w/ yandex_lite video)  [{y_status}]")

    top_folders = sorted(folder_bytes.items(), key=lambda kv: kv[1], reverse=True)[:6]
    print("\nTOP HEAVIEST ASSET DIRECTORIES:")
    for rank, (folder, b_sz) in enumerate(top_folders, 1):
        print(f"  {rank}. {folder:<26s} {b_sz / (1024 * 1024):6.2f} MB")

    if args.json_out:
        out_j = Path(args.json_out).resolve()
        out_j.parent.mkdir(parents=True, exist_ok=True)
        payload = {
            "game_dir": game_dir.as_posix(),
            "rustore_mb": round(rustore_mb, 2),
            "yandex_sfw_raw_mb": round(yandex_raw_mb, 2),
            "yandex_sfw_lite_video_mb": round(yandex_lite_proj_mb, 2),
            "yandex_budget_mb": YANDEX_BUDGET_MB,
            "yandex_within_budget": yandex_raw_mb <= YANDEX_BUDGET_MB,
            "categories": {
                c: {
                    "files": cat_stats[c][0],
                    "rustore_mb": round(cat_stats[c][1] / (1024 * 1024), 2),
                    "yandex_sfw_mb": round(cat_stats[c][2] / (1024 * 1024), 2),
                }
                for c in ordered_cats
            },
            "top_directories": [
                {"dir": k, "mb": round(v / (1024 * 1024), 2)} for k, v in top_folders
            ],
        }
        out_j.write_text(json.dumps(payload, indent=2, ensure_ascii=False), encoding="utf-8")
    return 0


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="media_forge.py",
        description="Tile Waifu media pipeline & asset budget CLI (Pillow + FFmpeg).",
    )
    sub = p.add_subparsers(dest="subcommand", required=True)

    # video
    pv = sub.add_parser("video", help="Encode Godot-ready Ogg Theora (.ogv) video.")
    pv.add_argument("input", help="Input video file (.mp4, .webm, .mov, .ogv).")
    pv.add_argument("output", help="Output .ogv file path.")
    pv.add_argument(
        "--preset",
        choices=["rustore_hq", "yandex_lite"],
        default="rustore_hq",
        help="Target quality preset: rustore_hq (720p ~1.8-2.5MB) or yandex_lite (480p ~450KB).",
    )
    pv.add_argument("--mute", action="store_true", help="Strip audio track (-an).")
    pv.add_argument("--xfade", type=float, default=0.0, help="Optional loop crossfade seconds (e.g. 0.35).")
    pv.set_defaults(func=cmd_video)

    # voice
    pvo = sub.add_parser("voice", help="Convert TTS mp3/wav to -16 LUFS mono 44.1kHz Vorbis .ogg.")
    pvo.add_argument("input", help="Input TTS audio (.mp3, .wav, .ogg, .m4a).")
    pvo.add_argument("output", help="Output .ogg file path.")
    pvo.add_argument("--lufs", type=float, default=-16.0, help="Integrated loudness target (default: -16.0 LUFS).")
    pvo.add_argument("--allow-silent", action="store_true", help="Do not fail exit code on silent audio.")
    pvo.set_defaults(func=cmd_voice)

    # icon-pack
    pi = sub.add_parser("icon-pack", help="Generate Android icon_192.png, icon_fg_432.png, icon_bg_432.png.")
    pi.add_argument("input", help="Source square/portrait icon PNG.")
    pi.add_argument("out_dir", help="Output directory for generated PNG icons.")
    pi.set_defaults(func=cmd_icon_pack)

    # qc-sheet
    pq = sub.add_parser("qc-sheet", help="Generate anatomy QC contact sheet for an image or video.")
    pq.add_argument("input", help="Input image (.png/.webp/.jpg) or video (.mp4/.ogv/.webm).")
    pq.add_argument("output", help="Output QC contact sheet .png path.")
    pq.set_defaults(func=cmd_qc_sheet)

    # budget
    pb = sub.add_parser("budget", help="Calculate game/ asset sizes by category vs Yandex <=100 MB & RuStore.")
    pb.add_argument("game_dir", help="Path to Godot game directory (e.g. 'game').")
    pb.add_argument("--json", dest="json_out", default="", help="Optional path to write JSON summary.")
    pb.set_defaults(func=cmd_budget)

    return p


def main() -> int:
    _reconfigure_utf8()
    parser = build_parser()
    args = parser.parse_args()
    return int(args.func(args))


if __name__ == "__main__":
    raise SystemExit(main())
