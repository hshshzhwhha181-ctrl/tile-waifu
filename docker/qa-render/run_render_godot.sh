#!/usr/bin/env bash
# Wrapper to run Godot rendering suites inside xvfb + Mesa llvmpipe (P96 / T13).
# Replaces --headless with xvfb-run + --rendering-driver opengl3 --display-driver x11.
set -euo pipefail

GODOT="${GODOT_BIN:-/usr/local/bin/godot4}"
XVFB_RES="${TW_XVFB_RES:-1600x2700}"

export LIBGL_ALWAYS_SOFTWARE=1
export GALLIUM_DRIVER=llvmpipe
export LP_NUM_THREADS="${LP_NUM_THREADS:-1}"
export MESA_GL_VERSION_OVERRIDE="${MESA_GL_VERSION_OVERRIDE:-3.3}"
export MESA_GLSL_VERSION_OVERRIDE="${MESA_GLSL_VERSION_OVERRIDE:-330}"

exec xvfb-run -a -s "-screen 0 ${XVFB_RES}x24 -ac +extension GLX +render -noreset" \
  "$GODOT" \
  --rendering-driver opengl3 \
  --display-driver x11 \
  --audio-driver Dummy \
  "$@"
