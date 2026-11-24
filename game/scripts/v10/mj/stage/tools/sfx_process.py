#!/usr/bin/env python3
"""Lane `stage` SFX: mirelo_text_to_audio mp3 -> trimmed Ogg at a target loudness.

  python3 sfx_process.py <in.mp3> <out.ogg> <max_len_s> <lufs>
Leading silence (-40 dB) is cut, the clip is cut at max_len with a 25 % fade-out, then a plain gain to <lufs>
(integrated) and a limiter at -3 dBFS (UX §7.4: SFX peaks ≤ -6 dBFS after the -2…-8 dB playback gain).
"""
import json
import re
import subprocess
import sys


def loud(path):
    r = subprocess.run(["ffmpeg", "-hide_banner", "-nostats", "-i", path, "-af", "loudnorm=print_format=json", "-f", "null", "-"],
                       capture_output=True, text=True)
    return json.loads(re.search(r"\{[^{}]*\"input_i\"[^{}]*\}", r.stderr, re.S).group(0))


src, dst, max_len, target = sys.argv[1], sys.argv[2], float(sys.argv[3]), float(sys.argv[4])
tmp = dst + ".tmp.wav"
fade = max_len * 0.25
# peak-normalise first, so a soft clip (a porcelain «ting») is not taken for silence by the trim
vd = subprocess.run(["ffmpeg", "-hide_banner", "-nostats", "-i", src, "-af", "volumedetect", "-f", "null", "-"],
                    capture_output=True, text=True).stderr
pre = -3.0 - float(re.search(r"max_volume: (-?[\d.]+) dB", vd).group(1))
subprocess.run(["ffmpeg", "-y", "-v", "error", "-i", src, "-af",
                "volume=%.2fdB,silenceremove=" % pre + "start_periods=1:start_threshold=-40dB:start_silence=0.01,atrim=0:%.3f,afade=t=out:st=%.3f:d=%.3f"
                % (max_len, max_len - fade, fade), "-ar", "44100", "-ac", "2", tmp], check=True)
m = loud(tmp)
gain = target - float(m["input_i"])
subprocess.run(["ffmpeg", "-y", "-v", "error", "-i", tmp, "-af",
                "volume=%.2fdB,alimiter=limit=0.7:attack=1:release=30:level=false,afade=t=in:d=0.005" % gain,
                "-c:a", "libvorbis", "-q:a", "5", dst], check=True)
subprocess.run(["rm", "-f", tmp])
m2 = loud(dst)
print(dst.split("/")[-1], "lufs", m2["input_i"], "peak", m2["input_tp"])
