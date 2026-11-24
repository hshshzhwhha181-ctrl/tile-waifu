#!/bin/bash
# Salon lane checks: selftest + scripted playtest with screenshots (+ "res": extra resolutions).
#   flock /tmp/tw-godot.lock bash game/scripts/v10/salon/tools/run_all.sh <out_dir> [res]
# Run from the repo root.
OUT=${1:?out dir}
G=${GODOT:-/opt/tw-tools/godot}
R=res://scripts/v10/salon/salon_runner.tscn
rm -rf "$OUT/pt720" "$OUT/res"
mkdir -p "$OUT/pt720" "$OUT/res"
: > "$OUT/res.log"
# new art / sfx need their .import files before a scene run can load them
timeout 600 "$G" --headless --path game --import > "$OUT/import.log" 2>&1
timeout 240 "$G" --headless --path game "$R" -- --salon_selftest=1 > "$OUT/selftest.log" 2>&1
echo "st_rc=$?"
timeout 300 xvfb-run -a "$G" --path game --rendering-driver opengl3 --audio-driver Dummy --resolution 720x1280 "$R" -- --pt=salon --shots="$OUT/pt720" > "$OUT/pt720.log" 2>&1
echo "pt_rc=$?"
if [ "$2" = "res" ]; then
  for res in 720x1600 1080x2400 1536x2048; do
    for v in "salon fresh" "salon z1mid" "scene:z2 all" "scene:z1 all" "hub fresh"; do
      set -- $v
      name="${res}_${1/:/_}_$2"
      timeout 60 xvfb-run -a "$G" --path game --rendering-driver opengl3 --audio-driver Dummy --resolution "$res" "$R" -- --screen="$1" --state="$2" --quit=2.5 --shots="$OUT/res/$name" >> "$OUT/res.log" 2>&1
    done
  done
  echo "res_done"
fi
