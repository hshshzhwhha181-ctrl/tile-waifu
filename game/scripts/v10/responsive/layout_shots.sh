#!/usr/bin/env bash
# 0.10 M0: screenshot every screen at every target resolution and build one contact sheet per view.
#   bash game/scripts/v10/responsive/layout_shots.sh /abs/out [WxH[@T,B] ...]
# WxH@T,B simulates a camera cut-out of T px at the top and B px at the bottom (window px) and draws a pill there.
# Default list: phones 9:16, 9:19.5–9:21 (one with a cut-out), RedMagic, QHD+, tablets 3:4 and 5:8.
set -u
OUT="${1:?out dir}"; shift || true
RES=("$@")
[ ${#RES[@]} -eq 0 ] && RES=(720x1280 1080x1920 1080x2340@110,0 1080x2400 1216x2688 1440x3200@150,60 1536x2048 1600x2560)
HERE="$(cd "$(dirname "$0")" && pwd)"
GAME="$(cd "$HERE/../../.." && pwd)"
GODOT="${GODOT:-/opt/tw-tools/godot}"
mkdir -p "$OUT"
rc=0
for spec in "${RES[@]}"; do
  r="${spec%@*}"; extra=()
  if [[ "$spec" == *@* ]]; then extra=(--safe="${spec#*@}" --notch=1); fi
  log="$OUT/$r.log"
  flock /tmp/tw-godot.lock timeout 900 xvfb-run -a "$GODOT" --path "$GAME" --rendering-driver opengl3 --audio-driver Dummy \
    --resolution "$r" -- --layout_shots="$OUT" --save=user://layout_shots_save.json --save_wipe=1 --story_off=1 \
    ${LAYOUT_ONLY:+--layout_only=$LAYOUT_ONLY} "${extra[@]}" > "$log" 2>&1
  st=$?
  line="$(grep -E '^LAYOUT (OK|FAIL)' "$log" | tail -1)"
  echo "$spec: ${line:-NO RESULT (exit $st)}"
  grep '^LAYOUT WARN' "$log" | head -20
  [ -z "$line" ] || [[ "$line" == *FAIL* ]] && rc=1
done
python3 -I "$HERE/sheet.py" "$OUT" || true
exit $rc
