#!/usr/bin/env python3
"""
banner_fullclear.py — сколько желаний и ₽ нужно, чтобы «собрать баннер» (Монте-Карло, seed фиксирован).
Баннер «Новая луна»: 1 избранный SSR+ (или SSR) + 3 избранных S-наряда (GDD §5.5: 50% S-выпадений — один из трёх, равновероятно).
Уровни «собрать»:
  L1  избранный SSR+            (счётчики гаранта из gacha_exact.FEATURED, свеча 120)
  L2  L1 + все 3 избранных S    (желания продолжаются, пока не выпали все)
Стоимость в ₽ = желания × ₽/желание (см. RATES). Затем таблицы добавляют ★ и оттенки по прямым ценам (§4 каталога).
Запуск: python3 banner_fullclear.py [N=60000]
"""
import random, sys, statistics
from gacha_exact import FEATURED

N = int(sys.argv[1]) if len(sys.argv) > 1 else 60000
SEED = 20261128
P_S = 0.13          # доля S от остатка после SSR
S_UP = 0.5          # S-ап: половина S — из трёх избранных
TEN = 10            # гарант S+ каждые 10 желаний

# стартовые состояния: (имя, k = желаний без SSR, lost = 50/50 проигран, c = желаний с последней избранной)
STARTS = [
    ("с нуля",                         0,  False, 0),
    ("30 желаний накоплено (k=30)",    30, False, 30),
    ("проиграл 50/50, k=0 (гарант)",   0,  True,  40),
    ("k=60: в зоне мягкого гаранта",   60, False, 60),
]

# ₽ за желание: 37.4 (пакет 2 990), 39.8 (пакет 199), 32.0 (Лунный пропуск), 24.9 (Нефритовый 199 ₽: 1 050 кр + 150 = 8 желаний => 24.9),
#                19.0 (пакет 499 с бонусом ×2 первой покупки: 499/26 желаний)
RATES = [("37.4 пакет 2 990", 37.4), ("39.8 пакет 199", 39.8), ("32.0 Лунный пропуск", 32.0), ("19.2 первая покупка 499 ×2", 19.2)]

def run(start, rng):
    _, k0, lost0, c0 = start
    k, g, c, ten = k0, lost0, c0, 0
    got_f = False
    s_have = set()
    t = 0
    t_f = None
    while True:
        t += 1
        k += 1; c += 1; ten += 1
        res = None
        if c >= FEATURED.candle:
            res = "F"
        else:
            p = FEATURED.p_ssr(k)
            if rng.random() < p:
                res = "F" if (g or rng.random() < FEATURED.feat) else "X"
            else:
                if rng.random() < P_S:
                    res = "S"
                elif ten >= TEN:
                    res = "S"
                else:
                    res = "A"
        if res in ("F", "X"):
            k = 0; ten = 0
            if res == "F":
                g = False; c = 0
                if not got_f:
                    got_f = True; t_f = t
            else:
                g = True
        elif res == "S":
            ten = 0
            if rng.random() < S_UP:
                s_have.add(rng.randrange(3))
        if got_f and len(s_have) == 3:
            return t_f, t

def pct(a, q):
    a = sorted(a)
    return a[min(len(a) - 1, int(q * len(a)))]

if __name__ == "__main__":
    print(f"N={N} прогонов на строку, seed={SEED}")
    print()
    print("| Старт | L1 избранный: среднее / p50 / p90 / макс | L2 +3 S: среднее / p50 / p90 / p99 |")
    print("|---|---|---|")
    store = {}
    for st in STARTS:
        rng = random.Random(SEED)
        l1 = []; l2 = []
        for _ in range(N):
            a, b = run(st, rng)
            l1.append(a); l2.append(b)
        store[st[0]] = (l1, l2)
        print(f"| {st[0]} | {statistics.mean(l1):.1f} / {pct(l1,.5)} / {pct(l1,.9)} / {max(l1)} | {statistics.mean(l2):.1f} / {pct(l2,.5)} / {pct(l2,.9)} / {pct(l2,.99)} |")
    print()
    print("Стоимость L1 / L2 в ₽ (среднее; p90) при разном ₽/желание")
    print("| Старт | " + " | ".join(r[0] for r in RATES) + " |")
    print("|---|" + "---|" * len(RATES))
    for st in STARTS:
        l1, l2 = store[st[0]]
        row = []
        for _, r in RATES:
            row.append(f"L1 {statistics.mean(l1)*r:,.0f} (p90 {pct(l1,.9)*r:,.0f}); L2 {statistics.mean(l2)*r:,.0f} (p90 {pct(l2,.9)*r:,.0f})".replace(",", " "))
        print(f"| {st[0]} | " + " | ".join(row) + " |")
    print()
    # вероятность переплатить относительно прямой покупки (2 490 ₽ SSR+, 4 287 ₽ SSR+ + 3 S)
    l1, l2 = store["с нуля"]
    for _, r in RATES[:1]:
        over1 = sum(1 for x in l1 if x * r > 2490) / N
        over2 = sum(1 for x in l2 if x * r > 4287) / N
        print(f"P(заплатить за L1 больше прямых 2 490 ₽ при {r} ₽/желание) = {over1*100:.1f}%")
        print(f"P(заплатить за L2 больше прямых 4 287 ₽ (2 490 + 3×599) при {r} ₽/желание) = {over2*100:.1f}%")
