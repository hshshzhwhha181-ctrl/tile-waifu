#!/usr/bin/env bash
# Tile Waifu asset slimming, stage 2: re-encode Ogg Vorbis audio in place (same file name => no code/.import change).
#   music / long stereo beds (stereo and >= 15 s)  -> stereo ~80 kbps
#   voice / sfx / stingers (everything else)       -> mono   ~48 kbps  (stereo short clips are downmixed)
# Originals stay in git history (reversible: git checkout -- game/assets). WAV files are NOT converted here: every
# .wav is addressed by its .wav path in code (Sfx / V9Ults ...), so renaming to .ogg would need code changes.
# They are slimmed through the importer instead (reimport.py: wav compress/mode=2 QOA). The wav loop report below
# documents that no .wav is a loop (edit/loop_mode=0 everywhere), so there is no loop-point risk to check.
#
# Idempotent: encoded files carry the vorbis comment TWSLIM=1 and are skipped; files already at/below target
# bitrate are skipped as well. Loop safety: for every file whose .import says loop=true (and every >= 15 s stereo
# bed) the duration before/after must differ by <= 25 ms, otherwise the original is kept.
#
# usage: audio_reencode.sh [--dry-run|--apply] [--music-k 80] [--voice-k 48] [--root game/assets] [--report out.tsv]
set -euo pipefail
MODE=dry; MUSIC_K=80; VOICE_K=48; REPORT=""
HERE=$(cd "$(dirname "$0")" && pwd); ROOT="$HERE/../../game/assets"
while [[ $# -gt 0 ]]; do case $1 in
  --dry-run) MODE=dry;; --apply) MODE=apply;;
  --music-k) MUSIC_K=$2; shift;; --voice-k) VOICE_K=$2; shift;;
  --root) ROOT=$2; shift;; --report) REPORT=$2; shift;;
  *) echo "unknown arg $1" >&2; exit 2;; esac; shift; done
command -v ffmpeg >/dev/null && ffmpeg -hide_banner -encoders 2>/dev/null | grep -q libvorbis || { echo "ffmpeg with libvorbis required" >&2; exit 1; }

tot_before=0; tot_after=0; n_done=0; n_skip=0; n_loopbad=0
[[ -n "$REPORT" ]] && printf 'file\tclass\tch\tkbps_before\tbytes_before\tbytes_after\tloop\tdur_before\tdur_after\tresult\n' > "$REPORT"
while IFS= read -r -d '' f; do
  ch=$(ffprobe -v error -select_streams a:0 -show_entries stream=channels -of csv=p=0 "$f")
  kbps=$(ffprobe -v error -show_entries format=bit_rate -of csv=p=0 "$f" | awk '{print int($1/1000)}')
  dur=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$f")
  size=$(stat -c %s "$f")
  tag=$(ffprobe -v error -show_entries stream_tags=TWSLIM:format_tags=TWSLIM -of csv=p=0 "$f" | head -1 || true)
  loopflag=$(grep -s -c '^loop=true' "$f.import" || true)
  if awk -v c="$ch" -v d="$dur" 'BEGIN{exit !(c>=2 && d>=15)}'; then cls=music; tk=$MUSIC_K; else cls=voice; tk=$VOICE_K; fi
  res=""
  if [[ "$tag" == "1" ]]; then res="skip:already"; fi
  if [[ -z "$res" ]] && awk -v k="$kbps" -v t="$tk" 'BEGIN{exit !(k<=t*1.1)}' && { [[ "$cls" == music || "$ch" == 1 ]]; }; then res="skip:low-bitrate"; fi
  after=$size; dur2=$dur
  if [[ -z "$res" ]]; then
    if [[ "$MODE" == apply ]]; then
      tmp=$(mktemp --suffix=.ogg)
      if [[ $cls == music ]]; then chopt=(); else chopt=(-ac 1); fi
      ffmpeg -nostdin -v error -y -i "$f" -vn -map_metadata 0 -c:a libvorbis -b:a ${tk}k "${chopt[@]}" -metadata TWSLIM=1 "$tmp"
      dur2=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$tmp")
      after=$(stat -c %s "$tmp")
      need_loop=0; [[ "$loopflag" -gt 0 || $cls == music ]] && need_loop=1
      dd=$(awk -v a="$dur" -v b="$dur2" 'BEGIN{d=(a-b);if(d<0)d=-d;print d*1000}')
      if [[ $need_loop == 1 ]] && awk -v d="$dd" 'BEGIN{exit !(d>25)}'; then
        res="KEPT-ORIGINAL:loop-dur-delta-${dd}ms"; n_loopbad=$((n_loopbad+1)); rm -f "$tmp"; after=$size
      elif [[ $after -ge $size ]]; then res="KEPT-ORIGINAL:not-smaller"; rm -f "$tmp"; after=$size
      else chmod --reference="$f" "$tmp"; mv "$tmp" "$f"; res="encoded"; fi
    else
      # estimate: bitrate ratio (dry-run is fast and writes nothing); exact numbers come from --apply
      after=$(awk -v s="$size" -v k="$kbps" -v t="$tk" 'BEGIN{r=t/k; if(r>1)r=1; printf "%d", s*r}'); res="would-encode"
    fi
  fi
  case "$res" in skip*) n_skip=$((n_skip+1));; *) n_done=$((n_done+1));; esac
  tot_before=$((tot_before+size)); tot_after=$((tot_after+after))
  [[ -n "$REPORT" ]] && printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "${f#$ROOT/}" "$cls" "$ch" "$kbps" "$size" "$after" "$loopflag" "$dur" "$dur2" "$res" >> "$REPORT"
  if [[ "$loopflag" -gt 0 ]]; then printf 'LOOP-CHECK %-60s %s dur %.3f -> %.3f\n' "${f#$ROOT/}" "$res" "$dur" "$dur2"; fi
done < <(find "$ROOT" -name '*.ogg' -print0 | sort -z)
printf '== audio (%s): ogg before %.2f MB, after %s %.2f MB; %d (re)encoded/planned, %d skipped, %d kept-original (loop delta)\n' \
  "$MODE" "$(echo "$tot_before/1048576" | bc -l)" "$([[ $MODE == apply ]] && echo actual || echo estimated)" "$(echo "$tot_after/1048576" | bc -l)" "$n_done" "$n_skip" "$n_loopbad"
echo "== wav loop report (wav files with edit/loop_mode != 0 would need loop-point verification):"
wl=$(grep -L '^edit/loop_mode=0' $(find "$ROOT" -name '*.wav.import') 2>/dev/null | wc -l)
echo "   wav files with loop_mode != 0: $wl of $(find "$ROOT" -name '*.wav.import' | wc -l)"
