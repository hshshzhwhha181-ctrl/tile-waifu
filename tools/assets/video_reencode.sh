#!/usr/bin/env bash
# Tile Waifu asset slimming, stage 3: re-encode the .ogv (Ogg Theora) clips in place to ~1000 kbps.
# Same file name, same resolution / fps / aspect => no code change. Originals stay in git history.
# Only clips whose average bitrate is above THRESH_K (default 1500) are touched; the small ~0.5 MB ult clips stay.
# Idempotent: re-encoded clips carry TWSLIM=1 and are skipped. A re-encode that is not at least 10% smaller than
# the original, or whose SSIM against the original is below MIN_SSIM (default 0.90), is discarded; the script then
# tries the next rung of the bitrate ladder (default 1000 -> 1500 -> 2000 -> 2500 -> 3000 kbps). P03 visual QA showed that the clip-average
# SSIM hides blocking in the worst frames (zlata/shirin/tsubame @1000k: clip 0.90 but worst frame 0.84-0.88, macroblocks visible),
# so a rung must ALSO keep the worst single frame at SSIM >= MIN_FRAME_SSIM (default 0.92, --min-frame-ssim).
#
# usage: video_reencode.sh [--dry-run|--apply] [--bitrate-k 1000] [--ladder 1000,1500,2000,2500,3000] [--min-frame-ssim 0.92] [--thresh-k 1100] [--root game/assets] [--report out.tsv]
set -euo pipefail
MODE=dry; BR=1000; LADDER=""; THRESH=1500; MIN_SSIM=0.90; MIN_FRAME_SSIM=0.92; REPORT=""
HERE=$(cd "$(dirname "$0")" && pwd); ROOT="$HERE/../../game/assets"
while [[ $# -gt 0 ]]; do case $1 in
  --dry-run) MODE=dry;; --apply) MODE=apply;;
  --bitrate-k) BR=$2; shift;; --ladder) LADDER=${2//,/ }; shift;; --thresh-k) THRESH=$2; shift;; --min-frame-ssim) MIN_FRAME_SSIM=$2; shift;;
  --root) ROOT=$2; shift;; --report) REPORT=$2; shift;;
  *) echo "unknown arg $1" >&2; exit 2;; esac; shift; done
[[ -z "$LADDER" ]] && LADDER="$BR 1500 2000 2500 3000"
enc=$(ffmpeg -hide_banner -encoders 2>/dev/null || true); [[ "$enc" == *libtheora* ]] || { echo "ffmpeg with libtheora required" >&2; exit 1; }

tb=0; ta=0
[[ -n "$REPORT" ]] && printf 'file\twxh\tfps\tdur\tkbps_before\tbytes_before\tbytes_after\tssim\tresult\n' > "$REPORT"
while IFS= read -r -d '' f; do
  size=$(stat -c %s "$f")
  IFS=, read -r w h fps < <(ffprobe -v error -select_streams v:0 -show_entries stream=width,height,r_frame_rate -of csv=p=0 "$f")
  dur=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$f")
  kbps=$(awk -v s="$size" -v d="$dur" 'BEGIN{printf "%d", s*8/d/1000}')
  tag=$(ffprobe -v error -show_entries stream_tags=TWSLIM:format_tags=TWSLIM -of csv=p=0 "$f" || true)
  nstreams=$(ffprobe -v error -show_entries stream=codec_type -of csv=p=0 "$f" | tr '\n' ' ')
  after=$size; ssim="-"
  if [[ "$tag" == "1" ]]; then res="skip:already"
  elif [[ $kbps -le $THRESH ]]; then res="skip:low-bitrate"
  elif [[ "$MODE" == dry ]]; then after=$(awk -v d="$dur" -v b="$BR" 'BEGIN{printf "%d", d*b*1000/8}'); res="would-encode"
  else
    # bitrate ladder: first rung that reaches MIN_SSIM wins (heavy-motion clips need more than 1000k to look the same)
    res="KEPT-ORIGINAL:no-rung-passed"; after=$size
    for rung in $LADDER; do
      tmp=$(mktemp --suffix=.ogv)
      ffmpeg -nostdin -v error -y -i "$f" -map 0:v:0 -c:v libtheora -b:v ${rung}k -g 24 -pix_fmt yuv420p -an -metadata TWSLIM=1 "$tmp"
      a2=$(stat -c %s "$tmp")
      st=$(mktemp)
      ssim=$(ffmpeg -nostdin -v info -i "$tmp" -i "$f" -lavfi "[0:v][1:v]ssim=stats_file=$st" -f null - 2>&1 | grep -o 'All:[0-9.]*' | tail -1 | cut -d: -f2)
      fmin=$(grep -o 'All:[0-9.]*' "$st" | cut -d: -f2 | sort -n | head -1); rm -f "$st"
      if awk -v a="$a2" -v s="$size" 'BEGIN{exit !(a>s*0.9)}'; then res="KEPT-ORIGINAL:not-smaller"; rm -f "$tmp"; break
      elif awk -v q="${ssim:-0}" -v m="$MIN_SSIM" -v fq="${fmin:-0}" -v fm="$MIN_FRAME_SSIM" 'BEGIN{exit !(q<m || fq<fm)}'; then res="KEPT-ORIGINAL:ssim-${ssim}/worst-frame-${fmin}@${rung}k"; rm -f "$tmp"
      else chmod --reference="$f" "$tmp"; mv "$tmp" "$f"; after=$a2; res="encoded@${rung}k worst-frame-ssim=${fmin}"; break; fi
    done
  fi
  tb=$((tb+size)); ta=$((ta+after))
  printf '%-48s %sx%s %5ss %5s kbps %8d -> %8d  ssim=%s  %s\n' "${f#$ROOT/}" "$w" "$h" "$(printf %.1f "$dur")" "$kbps" "$size" "$after" "$ssim" "$res"
  [[ -n "$REPORT" ]] && printf '%s\t%sx%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "${f#$ROOT/}" "$w" "$h" "$fps" "$dur" "$kbps" "$size" "$after" "$ssim" "$res" >> "$REPORT"
done < <(find "$ROOT" -name '*.ogv' -print0 | sort -z)
printf '== video (%s): %.2f MB -> %s %.2f MB\n' "$MODE" "$(echo "$tb/1048576" | bc -l)" "$([[ $MODE == apply ]] && echo actual || echo estimated)" "$(echo "$ta/1048576" | bc -l)"
