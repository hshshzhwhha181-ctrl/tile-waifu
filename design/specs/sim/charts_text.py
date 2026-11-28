#!/usr/bin/env python3
"""charts_text.py — текстовые «графики» для MONETIZATION_PLAN §9 (выручка по месяцам и сегментам, распределение желаний до избранной, кривая кита)."""
from ltv_model import revenue_by_month
from gacha_exact import FEATURED, featured_dist
import whale_curve


def bar(v, vmax, width=40):
    n = int(round(width * v / vmax)) if vmax else 0
    return "█" * n


def monthly():
    print("Выручка по месяцам жизни когорты 10 000 установок, средний сценарий (тыс. ₽, валовая):")
    rev, per = revenue_by_month("средний")
    mx = max(rev)
    print("| Мес | тыс. ₽ | минноу | дельфин | кит | кракен | |")
    print("|---|---|---|---|---|---|---|")
    for m in range(12):
        print(f"| {m+1} | {rev[m]/1000:.0f} | {per['минноу'][m]/1000:.0f} | {per['дельфин'][m]/1000:.0f} | {per['кит'][m]/1000:.0f} | {per['кракен'][m]/1000:.0f} | {bar(rev[m], mx)} |")
    print(f"Итого 12 мес: {sum(rev)/1000:.0f} тыс. ₽ валовых; чистых при NET 0.72: {sum(rev)*0.72/1000:.0f} тыс. ₽")


def distribution():
    print()
    print("Распределение числа желаний до избранной SSR+ (точный DP): доля игроков, у которых она выпала в окне:")
    pm = featured_dist(FEATURED)
    bins = [(1, 20), (21, 40), (41, 60), (61, 70), (71, 79), (80, 80), (81, 100), (101, 119), (120, 120)]
    mx = max(sum(pm[a:b + 1]) for a, b in bins)
    print("| Желания | доля | |")
    print("|---|---|---|")
    for a, b in bins:
        p = sum(pm[a:b + 1])
        print(f"| {a}–{b} | {p*100:.1f}% | {bar(p, mx, 30)} |")


def whale():
    print()
    print("Кривая кита: покрытие потолка каталога от бюджета, жадная покупка:")
    T = whale_curve.total()
    order = sorted(whale_curve.CATALOG, key=lambda x: x[3])
    for B in (3000, 6000, 12000, 25000, 50000, 75000, 100000, 125000):
        left = B
        spent = 0
        for name, n, p, _ in order:
            k = min(n, left // p)
            left -= k * p
            spent += k * p
        print(f"{B:>7,} ₽ | {bar(spent, T, 40)} {spent/T*100:.0f}%".replace(",", " "))


if __name__ == "__main__":
    monthly()
    distribution()
    whale()
