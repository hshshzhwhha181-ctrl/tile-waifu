#!/usr/bin/env python3
"""Voice QA: transcribe each generated line (faster-whisper small, ru) and compare with the script text,
and compare its median pitch with the heroine's existing 0.7 voice files (clone consistency).

  python3 game/scripts/v10/audio/pipeline/voice_check.py <voice_dir_with_mp3s> <game/assets/voice>
Prints one line per file: name | char-similarity | f0 new vs ref | transcript.
"""
import difflib
import glob
import os
import re
import subprocess
import sys

import numpy as np

TEXT = {
    "riichi": {"mc": "Риичи! Теперь только мы вдвоём, без подсказок!", "rin": "Риичи. Что ж, покажи свою решимость.",
               "hana": "Риичи! Идём ва-банк!", "yue": "Риичи. Луна свидетель твоей смелости.",
               "nova": "Риичи. Отключаю страховку!"},
    "rankup": {"mc": "Новый ранг! Я так тобой горжусь!", "rin": "Новый ранг тебе к лицу. Поздравляю.",
               "hana": "Ранг выше! Пьедестал наш!", "yue": "Твой ранг растёт, как луна к полнолунию.",
               "nova": "Апгрейд ранга установлен."},
    "yaku": {"mc": "Яку собрано! Видишь, как красиво сложилось?", "rin": "Изящная комбинация. Запишу её в книгу чайной.",
             "hana": "Комбинация! Это как гол в девятку!", "yue": "Узор сложился, как созвездие.",
             "nova": "Паттерн распознан. Бонус начислен."},
}


def mono16(p):
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", p, "-f", "f32le", "-ac", "1", "-ar", "16000", "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.float32).astype(float)


def f0(p):
    y = mono16(p)
    fr, hop, out = 640, 160, []
    for i in range(0, len(y) - fr, hop):
        s = y[i:i + fr] * np.hanning(fr)
        if np.sqrt((s ** 2).mean()) < 0.01:
            continue
        ac = np.correlate(s, s, "full")[fr - 1:]
        lo, hi = 16000 // 500, 16000 // 110
        lag = lo + int(np.argmax(ac[lo:hi]))
        if ac[lag] > 0.4 * ac[0]:
            out.append(16000 / lag)
    return float(np.median(out)) if out else 0.0


def norm(t):
    return re.sub(r"[^а-яё ]", "", t.lower().replace("ё", "е")).split()


def main():
    from faster_whisper import WhisperModel
    vdir, refdir = sys.argv[1], sys.argv[2]
    model = WhisperModel("small", device="cpu", compute_type="int8")
    ref_f0 = {}
    for f in sorted(glob.glob(os.path.join(vdir, "*.mp3"))):
        name = os.path.splitext(os.path.basename(f))[0]
        hero, kind = name.split("_")[0], re.sub(r"\d+$", "", name.split("_")[1])
        if hero not in ref_f0:
            ref_f0[hero] = float(np.median([f0(p) for p in glob.glob(os.path.join(refdir, hero + "_*.mp3"))[:6]]))
        segs, _ = model.transcribe(mono16(f).astype(np.float32), language="ru", beam_size=5)
        got = " ".join(s.text for s in segs).strip()
        want = TEXT.get(kind, {}).get(hero, "")
        sim = difflib.SequenceMatcher(None, " ".join(norm(got)), " ".join(norm(want))).ratio()
        print(f"{name:16s} | sim {sim:.2f} | f0 {f0(f):5.0f} vs {ref_f0[hero]:5.0f} | {got}")


if __name__ == "__main__":
    main()
