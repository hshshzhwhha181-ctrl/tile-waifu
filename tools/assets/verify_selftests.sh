#!/usr/bin/env bash
# Runs the asset-sensitive headless selftests from the project dir (needs a prior `godot --headless --import`).
# usage: GODOT=/path/to/godot verify_selftests.sh [name ...]      (default: the list below)
# Each line printed is the pass-marker line of that suite; Godot exits 134 at teardown AFTER printing, so we judge by marker.
set -uo pipefail
GODOT=${GODOT:?set GODOT to the Godot 4.5.1 binary}
GAME=$(cd "$(dirname "$0")/../../game" && pwd)
export HOME=${HOME_DIR:-/tmp/twhome-verify}; mkdir -p "$HOME"
declare -A SCENE ARGS MARK
add(){ SCENE[$1]=$2; ARGS[$1]=$3; MARK[$1]=$4; }
add contract ""                                                        "--contract_selftest=1"              CONTRACT_SELFTEST
add selftest ""                                                        "--selftest=1"                       SELFTEST
add ults     ""                                                        "--ults_selftest=1"                  ULTS
add recovery ""                                                        "--recovery_selftest=1"              RECOVERY
add voice    res://scripts/v10/voice/v10_voice_selftest.tscn           ""                                   "V10VOICE OK"
add audio    res://scripts/v10/audio/v10_audio_selftest.tscn           ""                                   V10AUDIO
add hud2     res://scripts/v10/hud2/hud2_demo.tscn                     "--hud2_selftest=1"                  "HUD2 SELFTEST"
add wave1    res://scripts/v10/wave1/wave1_selftest.tscn               "--wave1_selftest=1"                 WAVE1_SELFTEST
add rig      res://scripts/v10/rig/rig_selftest.tscn                   ""                                   RIG_SELFTEST
add look     res://scripts/v10/look/look_runner.tscn                   "--look_selftest=1"                  LOOK_SELFTEST
add fonts    res://scripts/v10/fonts/fonts_runner.tscn                 "--fonts_selftest=1"                 "FONTS SELFTEST"
add mj_stage res://scripts/v10/mj/stage/stage_selftest.tscn            "--mj_stage_selftest=1"              MJ_STAGE
add salon    res://scripts/v10/salon/salon_runner.tscn                 "--salon_selftest=1"                 SALON_SELFTEST
add gacha    res://scripts/v10/gacha/gacha_demo.tscn                   "--gacha_selftest=1 --mc=0.5"        GACHA_SELFTEST
names=("$@"); [[ ${#names[@]} -eq 0 ]] && names=(contract selftest ults recovery voice audio hud2 wave1 rig look fonts mj_stage salon gacha)
rc=0
for n in "${names[@]}"; do
  a=(--headless --audio-driver Dummy --path "$GAME"); [[ -n "${SCENE[$n]}" ]] && a+=("${SCENE[$n]}")
  [[ -n "${ARGS[$n]}" ]] && a+=(-- ${ARGS[$n]})
  out=$(timeout 900 "$GODOT" "${a[@]}" 2>&1 </dev/null)
  line=$(echo "$out" | grep -a -i -F "${MARK[$n]}" | tail -1)
  serr=$(echo "$out" | grep -a -c "SCRIPT ERROR")
  st=PASS; [[ -z "$line" || "$line" == *FAIL* || $serr -gt 0 ]] && { st=FAIL; rc=1; }
  printf '%-9s %s  script_errors=%s  | %s\n' "$n" "$st" "$serr" "${line:0:110}"
done
exit $rc
