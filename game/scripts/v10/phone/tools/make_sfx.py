"""Procedural phone sounds (0 credits): soft bell chimes and pops, 44.1 kHz mono 16-bit WAV.
usage: python3 -I game/scripts/v10/phone/tools/make_sfx.py game/assets/v10/phone/sfx"""
import sys, os, math, wave, struct, random

SR = 44100
# UX_RULES §7.4: SFX peaks ≤ −6 dBFS → every file is normalised to at most −6.5 dBFS (0.473 of full scale)
PEAK_MAX = 0.473
random.seed(7)
out = sys.argv[1] if len(sys.argv) > 1 else "game/assets/v10/phone/sfx"
os.makedirs(out, exist_ok=True)


def bell(f, t, dur, amp=1.0):
    if t < 0 or t > dur:
        return 0.0
    env = (1 - math.exp(-t * 400)) * math.exp(-t * 7.5 / dur)
    return amp * env * (math.sin(2 * math.pi * f * t) + 0.32 * math.sin(2 * math.pi * f * 2.76 * t) * math.exp(-t * 18)
                        + 0.12 * math.sin(2 * math.pi * f * 5.4 * t) * math.exp(-t * 40))


def pop(t, f0, f1, dur, amp=1.0):
    if t < 0 or t > dur:
        return 0.0
    k = t / dur
    f = f0 + (f1 - f0) * (1 - (1 - k) ** 3)
    ph = 2 * math.pi * (f0 * t + (f1 - f0) * t * 0.5)
    env = (1 - math.exp(-t * 900)) * (1 - k) ** 2.2
    return amp * env * math.sin(ph if f1 == f0 else 2 * math.pi * f * t)


def write(name, dur, fn, gain=0.55):
    n = int(SR * dur)
    data = [fn(i / SR) for i in range(n)]
    peak = max(1e-6, max(abs(x) for x in data))
    fade = int(SR * 0.01)
    with wave.open(os.path.join(out, name + ".wav"), "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        frames = bytearray()
        for i, x in enumerate(data):
            if i > n - fade:
                x *= (n - i) / fade
            frames += struct.pack("<h", int(max(-1, min(1, x / peak * min(gain, PEAK_MAX))) * 32767))
        w.writeframes(bytes(frames))
    print(name, dur)


# her message: two-note crystal «тинь» (E6 → B6)
write("msg_in", 0.62, lambda t: bell(1318.5, t, 0.5) + 0.8 * bell(1975.5, t - 0.075, 0.5))
# my message: soft upward pop
write("msg_out", 0.16, lambda t: pop(t, 520, 980, 0.14), 0.45)
# typing tick (very soft)
write("typing", 0.05, lambda t: pop(t, 2300, 1900, 0.035, 0.6) + random.uniform(-0.05, 0.05) * max(0, 1 - t / 0.01), 0.18)
# sticker lands: bouncy double pop + sparkle
write("sticker_pop", 0.45, lambda t: pop(t, 300, 700, 0.12) + 0.7 * pop(t - 0.09, 500, 900, 0.1) + 0.35 * bell(2637, t - 0.13, 0.28), 0.55)
# like: bright pluck + shimmer
write("like_pop", 0.5, lambda t: pop(t, 600, 1200, 0.09) + 0.6 * bell(1760, t - 0.03, 0.4) + 0.4 * bell(2637, t - 0.08, 0.35), 0.55)
# a comment appears: single soft bell
write("comment_in", 0.45, lambda t: bell(1567.98, t, 0.4, 0.8), 0.32)
# reaction chosen: short blip
write("react", 0.18, lambda t: pop(t, 880, 1320, 0.12), 0.4)
# tab switch: tiny wooden click
write("tab", 0.06, lambda t: pop(t, 1400, 900, 0.045), 0.35)
# phone opens: rising three-note glass arpeggio
write("phone_open", 0.9, lambda t: bell(1046.5, t, 0.6, 0.7) + bell(1318.5, t - 0.07, 0.6, 0.7) + bell(1568, t - 0.14, 0.7, 0.8), 0.5)
# phone closes: soft falling two notes
write("phone_close", 0.5, lambda t: bell(1318.5, t, 0.4, 0.6) + bell(987.8, t - 0.06, 0.4, 0.6), 0.38)
