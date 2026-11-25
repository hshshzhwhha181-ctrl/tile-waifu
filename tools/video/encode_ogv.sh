#!/usr/bin/env bash
# Tile Waifu: clip -> Godot-ready Ogg Theora.
# usage: encode_ogv.sh <in> <out.ogv> <W> <H> [xfade_seconds]
#   W H: 720 1280 (full-screen 9:16), 540 960 (lite / Yandex), 1080 1920 (banner master, not shipped)
#   xfade_seconds (optional, loops only): crossfades the clip tail into its head so the seam is invisible;
#   output gets shorter by xfade_seconds. Use 0.25-0.5 s; never on cut-ins (they are one-shot).
set -euo pipefail
in=$1; out=$2; W=$3; H=$4; xf=${5:-0}
vf="scale=${W}:${H}:force_original_aspect_ratio=increase:flags=lanczos,crop=${W}:${H},fps=24,format=yuv420p"
if [[ "$xf" != "0" ]]; then
  dur=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$in")
  off=$(python3 -c "print(round($dur-2*$xf,3))")
  # head = first xf seconds, body = rest; output = body with its last xf seconds crossfaded into head
  ffmpeg -v error -y -i "$in" -filter_complex \
    "[0]${vf},split[a][b];[a]trim=start=${xf},setpts=PTS-STARTPTS[body];[b]trim=0:${xf},setpts=PTS-STARTPTS[head];[body][head]xfade=transition=fade:duration=${xf}:offset=${off}[v]" \
    -map "[v]" -c:v libtheora -q:v 8 -g 24 -an "$out"
else
  ffmpeg -v error -y -i "$in" -vf "$vf" -c:v libtheora -q:v 8 -g 24 -an "$out"
fi
ffprobe -v error -show_entries stream=width,height,r_frame_rate -show_entries format=duration,size -of compact=p=0 "$out"
