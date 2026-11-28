#!/usr/bin/env python3
"""
f2p_paths.py — за сколько дней бесплатный игрок получает SSR / избранный SSR+ (MONETIZATION_PLAN §5, §9).

Входы — только числа GDD v11 §5.3–5.5 (кумулятивная кривая желаний профиля) + точные гаранты из gacha_exact.
Профили (кумулятивные желания к дню d, включая «первую десятку», «Семь встреч», Поднос; GDD §5.4):
  active   : 30 к D7, далее +2.85/сут (159 желаний за 56 дней в устоявшемся режиме)
  light    : 22 к D7, далее +1.10/сут (≈64 + разовые)
  hardcore : 34 к D7, далее +3.30/сут
Гача «Первый гость»: шанс SSR как у всех (1.5%/желание), гарантия на 30-м. После SSR гостья — игрок переходит на «Новую луну».
Запуск: python3 f2p_paths.py
"""
import random, statistics
from gacha_exact import FEATURED, featured_dist

PROFILES = {
    "F2P лёгкий":   dict(d7=22, slope=1.10),
    "F2P активный": dict(d7=30, slope=2.85),
    "F2P хардкор":  dict(d7=34, slope=3.30),
}

def wishes_by_day(profile, d):
    p = PROFILES[profile]
    if d <= 7:
        return p["d7"] * d / 7.0 if d > 0 else 0
    return p["d7"] + p["slope"] * (d - 7)

def day_when_cum(profile, w):
    """первый день d, к которому накоплено >= w желаний"""
    d = 1
    while wishes_by_day(profile, d) < w:
        d += 1
        if d > 5000: return d
    return d

def pct(a, q):
    a = sorted(a); return a[min(len(a) - 1, int(q * len(a)))]

def guest_ssr_wish(rng):
    # желание, на котором выпадет SSR «Первого гостя»: геометрическое 1.5%, но не позже 30-го
    for n in range(1, 31):
        if n == 30 or rng.random() < 0.015:
            return n

def featured_wish(rng, pmf_cdf):
    u = rng.random()
    lo, hi = 0, len(pmf_cdf) - 1
    while lo < hi:
        mid = (lo + hi) // 2
        if pmf_cdf[mid] >= u: hi = mid
        else: lo = mid + 1
    return lo

if __name__ == "__main__":
    rng = random.Random(11)
    pm = featured_dist(FEATURED)
    cdf = []; s = 0.0
    for p in pm:
        s += p; cdf.append(s)
    N = 20000
    print("A. Первая SSR через «Первого гостя» (день, когда накоплено нужное число желаний; баннер открывается на L5 ≈ D1)")
    print("| Профиль | P(SSR к 10-му желанию) | к 29-му | день: p25 / медиана / p75 / p95 (гарант на 30-м) |")
    print("|---|---|---|---|")
    for prof in PROFILES:
        ws = [guest_ssr_wish(rng) for _ in range(N)]
        days = [day_when_cum(prof, w) for w in ws]
        p10 = sum(1 for w in ws if w <= 10) / N
        p29 = sum(1 for w in ws if w <= 29) / N
        print(f"| {prof} | {p10*100:.0f}% | {p29*100:.0f}% | {pct(days,.25)} / {pct(days,.5)} / {pct(days,.75)} / {pct(days,.95)} |")
    print()
    print("B. Первый избранный SSR+ «Новой луны» ПОСЛЕ гостя: желания копятся в одном счётчике (GDD §5.5: счётчики не сгорают).")
    print("   Игрок сначала тратит желания на гостя (до его SSR), остаток — на избранный баннер.")
    print("| Профиль | день: p25 / медиана / p75 / p90 | P(есть избранный SSR+ к 28 дню) | к 56 дню | к 112 дню (2 сезона) |")
    print("|---|---|---|---|---|")
    for prof in PROFILES:
        days_f = []
        for _ in range(N):
            g = guest_ssr_wish(rng)
            f = featured_wish(rng, cdf)
            days_f.append(day_when_cum(prof, g + f))
        def pwithin(D): return sum(1 for d in days_f if d <= D) / N
        print(f"| {prof} | {pct(days_f,.25)} / {pct(days_f,.5)} / {pct(days_f,.75)} / {pct(days_f,.9)} | {pwithin(28)*100:.0f}% | {pwithin(56)*100:.0f}% | {pwithin(112)*100:.0f}% |")
    print()
    print("C. Сколько избранных SSR/SSR+ суммарно получает F2P за N дней (в среднем), если ВСЕ желания идут в избранные баннеры (счётчик общий):")
    mean_f = sum(t * p for t, p in enumerate(pm))
    print("| Профиль | 28 дней | 56 дней | 112 дней | 336 дней |")
    print("|---|---|---|---|---|")
    for prof in PROFILES:
        row = []
        for D in (28, 56, 112, 336):
            w = wishes_by_day(prof, D)
            row.append(f"{(w/mean_f):.1f}")
        print(f"| {prof} | " + " | ".join(row) + " |")
    print(f"   (делитель: среднее желаний на избранный = {mean_f:.1f}; не учитывает дисперсию и то, что витрина сезона конечна)")
    print()
    print("D. Лепестки как «долгий путь» к SSR+ без случая (3 600 лепестков, спека скинов §6.4.1): сезонов до накопления у активного ≈ 3 600 / 1 225 ≈ %.1f; у лёгкого (≈450/сезон) ≈ %.1f" % (3600/1225, 3600/450))
