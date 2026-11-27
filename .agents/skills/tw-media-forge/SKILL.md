---
name: tw-media-forge
description: >-
  Media pipeline and asset budget toolkit for Tile Waifu using Pillow and FFmpeg. Activate
  this skill when encoding Godot Ogg Theora (.ogv) cut-ins or loops for RuStore/Yandex Games,
  converting TTS heroine voices to -16 LUFS Vorbis (.ogg), building Android adaptive launcher
  icons, rendering anatomy QC contact sheets for AI art/video, or auditing the game/ asset
  footprint against the 100 MB Yandex Games and RuStore budgets.
---

# Tile Waifu — Media Forge & Asset Budget (`tw-media-forge`)

All media conversions and asset size audits run through [media_forge.py](./scripts/media_forge.py). It auto-discovers `ffmpeg.exe` / `ffprobe.exe` on `PATH` or the WinGet `Gyan.FFmpeg` package directory (`%LOCALAPPDATA%\Microsoft\WinGet\Packages\Gyan.FFmpeg*`).

## Subcommands Overview

| Subcommand | Purpose |
| :--- | :--- |
| `video` | Encode `.mp4`/`.webm`/`.mov` into Godot-ready Ogg Theora `.ogv` (`rustore_hq` 720p ~1.8–2.5 MB or `yandex_lite` 480p ~450 KB, `--mute`, optional `--xfade`). |
| `voice` | Master TTS `.mp3`/`.wav` to `-16 LUFS` loudnorm, mono, 44.1 kHz Ogg Vorbis `.ogg` + report duration & peak dB to catch silent files. |
| `icon-pack` | Build Android launcher icons (`icon_192.png`, `icon_fg_432.png` with safe 66% center zone, `icon_bg_432.png` warm lacquer gradient). |
| `qc-sheet` | Generate dark-lacquer anatomy QC contact sheet (full frame + zoomed face + zoomed hands/legs crops for images, or 3 key timestamps for video). |
| `budget` | Calculate `game/` asset size by category and report Yandex Games ≤100 MB & RuStore 1.0 footprints. |

---

## 1. Encode Godot Video Clips (`video`)

Follow `docs/VIDEO_BIBLE.md`: Godot 4 uses `VideoStreamTheora` (`.ogv`, 24 fps, `yuv420p`). Never keep AI-generated audio on cut-ins (`--mute`).

```powershell
# RuStore 1.0 HQ preset (720p short side, ~1.8-2.5 MB for 4-5s clip, muted)
python .agents/skills/tw-media-forge/scripts/media_forge.py video raw_ult.mp4 game/assets/v10/ult_video/zlata.ogv --preset rustore_hq --mute

# Yandex Games 1.1 Lite preset (480p short side, ~450 KB for <=100 MB web budget)
python .agents/skills/tw-media-forge/scripts/media_forge.py video raw_ult.mp4 build/yandex_ult/zlata.ogv --preset yandex_lite --mute

# Seamless idle loop with 0.35s tail-to-head crossfade
python .agents/skills/tw-media-forge/scripts/media_forge.py video raw_loop.mp4 loop.ogv --preset rustore_hq --mute --xfade 0.35
```

---

## 2. Master Heroine Voice Lines (`voice`)

Follow `docs/AUDIO_BIBLE.md`: `-16 LUFS` integrated loudness (`TP=-1.5 dB`), mono, `44100 Hz` Ogg Vorbis `.ogg`. Automatically fails with a `SILENT_AUDIO` diagnostic if the output is silent or truncated.

```powershell
python .agents/skills/tw-media-forge/scripts/media_forge.py voice tts_raw.mp3 game/assets/v10/audio/voice/zlata_greet1.ogg
```

---

## 3. Generate Android Adaptive Icon Pack (`icon-pack`)

Produces the three launcher icons referenced in `game/export_presets.cfg` (`res://assets/ui/icon_192.png`, `icon_fg_432.png`, `icon_bg_432.png`):

```powershell
python .agents/skills/tw-media-forge/scripts/media_forge.py icon-pack master_icon.png game/assets/ui
```
- `icon_192.png`: `192×192` legacy/main icon over warm lacquer.
- `icon_fg_432.png`: `432×432` RGBA adaptive foreground constrained to the **66% safe center zone** (`285×285` px) so OEM circle/squircle masks never clip the heroine's face.
- `icon_bg_432.png`: `432×432` RGBA warm plum-crimson teahouse lacquer gradient.

---

## 4. Render Anatomy QC Contact Sheets (`qc-sheet`)

Every generated heroine card, pose, or video clip must pass strict anatomy inspection (`docs/HEROINES.md`: 2 arms, 2 legs, 5+5 fingers, adult face proportions, matching `LW` legwear pattern on both legs, zero garbled text):

```powershell
# Still artwork QC sheet (Full + Face + Hands/Torso + Lower/Legs crops)
python .agents/skills/tw-media-forge/scripts/media_forge.py qc-sheet candidate.webp qc_candidate.png

# Video QC sheet (3 frames at start/mid/end, each with Full + Face + Lower/Hand crops)
python .agents/skills/tw-media-forge/scripts/media_forge.py qc-sheet game/assets/v10/ult_video/kohaku.ogv qc_kohaku_video.png
```

---

## 5. Audit Asset Footprint & Yandex ≤100 MB Budget (`budget`)

Run before adding large PNG/OGV/audio batches to check category totals, RuStore 1.0 payload, Yandex Games ≤100 MB SFW budget status, and top heavy folders:

```powershell
python .agents/skills/tw-media-forge/scripts/media_forge.py budget game
```
