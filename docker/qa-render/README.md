# Tile Waifu — Pinned Rendering QA Image (`docker/qa-render/`)

Package **P96** (`design/specs/UNIFIED_QA_PLAN.md` §6.5, §7.3, §17.3, Appendix R T13/T19).

## Purpose

Godot `--headless` uses the Dummy renderer: viewports return empty frames, draw calls and `TEXTURE_MEM_USED` report zero, and shader/pixel checks silently degrade to `PENDING`.

This Docker image provides a single, reproducible software-OpenGL 3.3 (`xvfb` + Mesa `llvmpipe` + pinned LLVM + Godot `4.5.1` + deterministic `fontconfig`) environment.

**Golden capture rule:** reference golden screenshots (`AT-S24`, `TWSkinShot`, `golden_diff.py`) MUST be captured **only** inside this container (`TW_QA_RENDER_IMAGE=1`, `/etc/tw-qa-render/env.json` recorded alongside captures).

## Build & Verify

```bash
docker build -t tw-qa-render:v1-godot4.5.1-ubuntu24.04 docker/qa-render
docker run --rm tw-qa-render:v1-godot4.5.1-ubuntu24.04
```

Expected last line: `QA_RENDER_IMAGE OK`, preceded by the JSON fingerprint of Godot, Mesa, LLVM, Xvfb, fontconfig, and Python package versions.

## Run a Rendering Suite Locally

```bash
docker run --rm -v "$PWD:/workspace" tw-qa-render:v1-godot4.5.1-ubuntu24.04 \
  tw-render-godot --resolution 720x1280 --path /workspace/game \
  res://tests/skin_swap_soak/skin_swap_soak.tscn -- --require_render=1
```

## Updating Versions & Re-baselining Goldens

Any bump to `ubuntu:24.04` digest, Mesa/LLVM packages, `GODOT_VERSION`, or bundled fonts in `game/assets/**/fonts/`:

1. Update `Dockerfile` (and pin the new base digest `@sha256:...`).
2. Record the new container fingerprint (`env.json`) and re-run `.github/workflows/qa-render.yml` via `workflow_dispatch`.
3. Follow `UNIFIED_QA_PLAN.md` §7.3 for golden re-baseline (AD + QA review required).
4. Any threshold adjustment must be logged in `docs/qa/THRESHOLDS.md`.
