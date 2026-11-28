#!/usr/bin/env python3
"""
ltv_model.py — когортная модель выручки и LTV (MONETIZATION_PLAN §1, §7). ВСЕ входы — [ГИПОТЕЗА] (см. таблицу источников в плане).
Вход: 10 000 установок. Выход: DAU/MAU по месяцам, платящие по сегментам, валовая выручка, LTV на установку (D30/D90/D180/D365),
предел CPI для окупаемости ≤ 12 мес. при чистой доле выручки NET (комиссия RuStore + НДС/налоги: [НП], принято 0.72).
Запуск: python3 ltv_model.py
"""
NET = 0.72           # [НП] чистая доля от валового чека (комиссия стора + налоги). Уточнить у владельца Q-05.
INSTALLS = 10_000

# retention от установок (доля «активен в этот день»): D1, D7, D30, D90, D180, D365
RET = {
    "низкий":  dict(D1=0.25, D7=0.08, D30=0.030, D90=0.015, D180=0.009, D365=0.005),
    "средний": dict(D1=0.32, D7=0.11, D30=0.045, D90=0.024, D180=0.015, D365=0.009),
    "высокий": dict(D1=0.40, D7=0.14, D30=0.065, D90=0.036, D180=0.024, D365=0.015),
}
# доля установок, ставших платящими за 365 дней; доля сегментов среди платящих
PAYER_CONV = {"низкий": 0.020, "средний": 0.035, "высокий": 0.055}
SEG_SHARE = {"минноу": 0.62, "дельфин": 0.30, "кит": 0.076, "кракен": 0.004}
# средний чек в месяц (₽) в месяцы «активного платежа» и месячный шанс остаться платящим [ГИП]
SEG_SPEND = {"минноу": 190, "дельфин": 1200, "кит": 6500, "кракен": 40000}
SEG_STAY = {"минноу": 0.78, "дельфин": 0.84, "кит": 0.90, "кракен": 0.60}
# множитель масштаба чека по сценарию (RU-рынок: платёжеспособность и конкуренция)
SPEND_SCALE = {"низкий": 0.75, "средний": 1.0, "высокий": 1.25}
# распределение времени первого платежа по месяцам жизни когорты (сумма=1): 1-й месяц основной всплеск
FIRST_PAY_MONTH = [0.55, 0.15, 0.08, 0.06, 0.05, 0.04, 0.03, 0.02, 0.01, 0.005, 0.003, 0.002]

def retention_at(ret, day):
    pts = [(0, 1.0), (1, ret["D1"]), (7, ret["D7"]), (30, ret["D30"]), (90, ret["D90"]), (180, ret["D180"]), (365, ret["D365"])]
    for (d0, r0), (d1, r1) in zip(pts, pts[1:]):
        if d0 <= day <= d1:
            return r0 + (r1 - r0) * (day - d0) / (d1 - d0)
    return pts[-1][1]

def revenue_by_month(scn):
    payers_total = INSTALLS * PAYER_CONV[scn]
    rev = [0.0] * 12
    per_seg = {k: [0.0] * 12 for k in SEG_SHARE}
    for seg, share in SEG_SHARE.items():
        n_seg = payers_total * share
        for m0, w in enumerate(FIRST_PAY_MONTH):
            n0 = n_seg * w
            for m in range(m0, 12):
                alive = n0 * (SEG_STAY[seg] ** (m - m0))
                # первый месяц платежа чуть ниже среднего (идёт онбординг); дальше — полный
                k = 0.7 if m == m0 else 1.0
                r = alive * SEG_SPEND[seg] * SPEND_SCALE[scn] * k
                rev[m] += r; per_seg[seg][m] += r
    return rev, per_seg

def main():
    print("| Сценарий | Платящие/365д | DAU D30 | Выручка M1 | M3 | M6 | M12 | LTV D30/уст. | D90 | D180 | D365 | чистый LTV365 | макс. CPI (окуп. 12 мес) |")
    print("|---|---|---|---|---|---|---|---|---|---|---|---|---|")
    detail = {}
    for scn in ("низкий", "средний", "высокий"):
        rev, per = revenue_by_month(scn)
        cum = lambda m: sum(rev[:m])
        dau30 = INSTALLS * RET[scn]["D30"]
        ltv = lambda m: cum(m) / INSTALLS
        net365 = ltv(12) * NET
        print(f"| {scn} | {INSTALLS*PAYER_CONV[scn]:.0f} | {dau30:.0f} | {rev[0]:,.0f} | {rev[2]:,.0f} | {rev[5]:,.0f} | {rev[11]:,.0f} | {ltv(1):.1f} | {ltv(3):.1f} | {ltv(6):.1f} | {ltv(12):.1f} | {net365:.1f} | {net365:.0f} ₽ |".replace(",", " "))
        detail[scn] = (rev, per)
    print()
    for scn in ("низкий", "средний", "высокий"):
        rev, per = detail[scn]
        tot = sum(rev)
        print(f"Сценарий «{scn}»: доля выручки за 12 мес по сегментам: " + ", ".join(f"{k} {sum(v)/tot*100:.0f}%" for k, v in per.items()) +
              f"; ARPPU/мес (M6, платящие живые): {rev[5] / sum(INSTALLS*PAYER_CONV[scn]*SEG_SHARE[s]*sum(FIRST_PAY_MONTH[m0]*SEG_STAY[s]**(5-m0) for m0 in range(6)) for s in SEG_SHARE):.0f} ₽")
    print()
    # ARPDAU на 30-й день жизни когорты (выручка M1/30 / DAU D30) — индикатор, не KPI
    for scn in ("низкий", "средний", "высокий"):
        rev, _ = detail[scn]
        dau_mid = INSTALLS * (RET[scn]["D7"] + RET[scn]["D30"]) / 2
        print(f"ARPDAU когорты в 1-й месяц ({scn}): {rev[0]/30/dau_mid:.1f} ₽ (выручка M1 / 30 / средний DAU {dau_mid:.0f})")

if __name__ == "__main__":
    main()
