#!/usr/bin/env python3
"""
gacha_exact.py — точный расчёт гачи Tile Waifu (GDD v11 §5.5 + MONETIZATION_PLAN §3).

Не Монте-Карло, а точное распространение вероятностей по состояниям (DP). Единственный источник чисел
для таблиц §3 и §9 в MONETIZATION_PLAN.md. Запуск: python3 gacha_exact.py
Зависимости: только стандартная библиотека.

Модель баннера (параметры Banner):
  p0     базовый шанс SSR на желание
  soft   с какого желания (без SSR подряд) растёт шанс; на желании k>soft: p = p0 + step*(k-soft)
  hard   желание, на котором SSR гарантирована (p=1)
  feat   вероятность, что SSR избранная при "честном" броске (0.5 => 50/50); None => избранной нет
  catchup  после проигрыша 50/50 следующая SSR гарантированно избранная
  candle   на этом желании с момента последней избранной SSR игрок выбирает любую SSR баннера (0 = нет)
"""
from dataclasses import dataclass
import math

@dataclass(frozen=True)
class Banner:
    name: str
    p0: float
    soft: int
    step: float
    hard: int
    feat: float | None = 0.5
    catchup: bool = True
    candle: int = 0

    def p_ssr(self, k):          # k = номер желания с последней SSR (1-based)
        if k >= self.hard:
            return 1.0
        if k > self.soft:
            return min(1.0, self.p0 + self.step * (k - self.soft))
        return self.p0

# ---- баннеры ---------------------------------------------------------------------------------------------
STANDARD = Banner("Пять ветров (постоянный)",      0.015, 60, 0.05, 80, feat=None, catchup=False, candle=0)
FEATURED = Banner("Новая луна / Полнолуние / Гардероб (избранный наряд)", 0.015, 60, 0.05, 80, 0.5, True, 120)
# ужесточённый вариант для сравнения (критик-гачер: 75/90/200)
STRICT   = Banner("Жёсткий вариант критика (75/+5/90, свеча 200)", 0.015, 75, 0.05, 90, 0.5, True, 200)
# реквизит ульты («Шкатулка»): косметика, желание 100 кр, шанс выше, гарант короче, 75/25 + catch-up
PROPS    = Banner("Шкатулка (реквизит ульты, 100 кр/желание)", 0.020, 45, 0.06, 60, 0.75, True, 0)

def any_ssr_dist(b: Banner):
    """P(первая SSR на желании n), n=1..hard"""
    d = [0.0] * (b.hard + 1)
    surv = 1.0
    for k in range(1, b.hard + 1):
        p = b.p_ssr(k)
        d[k] = surv * p
        surv *= (1 - p)
    return d

def featured_dist(b: Banner, start_k=0, start_lost=False, start_c=0, tmax=700):
    """
    Точное распределение числа желаний до первой избранной SSR.
    Состояние: (k = счётчик с последней SSR, g = последний 50/50 проигран, c = счётчик с последней избранной).
    start_k  — сколько желаний уже без SSR; start_lost — следующая SSR гарантированно избранная;
    start_c  — сколько желаний уже с последней избранной (для свечи).
    Возвращает pmf[t], t=1..tmax (вероятность получить избранную ровно на t-м желании).
    """
    cur = {(start_k, start_lost, start_c): 1.0}
    pmf = [0.0] * (tmax + 1)
    for t in range(1, tmax + 1):
        nxt = {}
        for (k, g, c), pr in cur.items():
            k1 = k + 1
            c1 = c + 1
            if b.candle and c1 >= b.candle:
                pmf[t] += pr             # свеча: выбирает избранную
                continue
            p = b.p_ssr(k1)
            # не SSR
            if p < 1.0:
                key = (k1, g, c1)
                nxt[key] = nxt.get(key, 0.0) + pr * (1 - p)
            # SSR
            if p > 0:
                if b.feat is None:
                    pmf[t] += pr * p
                else:
                    pf = 1.0 if (g and b.catchup) else b.feat
                    pmf[t] += pr * p * pf
                    if pf < 1.0:
                        key = (0, True if b.catchup else False, c1)
                        nxt[key] = nxt.get(key, 0.0) + pr * p * (1 - pf)
        cur = nxt
        if not cur:
            break
    return pmf

def stats(pmf):
    total = sum(pmf)
    mean = sum(t * p for t, p in enumerate(pmf))
    cum = 0.0
    q = {}
    for t, p in enumerate(pmf):
        cum += p
        for lvl in (0.25, 0.5, 0.75, 0.9, 0.99):
            if lvl not in q and cum >= lvl:
                q[lvl] = t
    mx = max(t for t, p in enumerate(pmf) if p > 1e-15)
    return dict(total=total, mean=mean, q=q, max=mx)

def p_within(pmf, n):
    return sum(pmf[1:n + 1])

def consolidated_ssr_rate(b: Banner):
    d = any_ssr_dist(b)
    mean = sum(k * d[k] for k in range(1, b.hard + 1))
    return 1.0 / mean, mean

# ---- вывод ---------------------------------------------------------------------------------------------
if __name__ == "__main__":
    print("=" * 100)
    print("A. Любая SSR (счётчик гаранта)")
    for b in (STANDARD, FEATURED, STRICT, PROPS):
        r, m = consolidated_ssr_rate(b)
        print(f"  {b.name:62s} итог шанс SSR = {r*100:5.2f}%  среднее до любой SSR = {m:5.1f} желаний")

    print("=" * 100)
    print("B. Избранная (точный DP). mean / p25 / медиана / p75 / p90 / p99 / максимум; P(<=N) для N=30,60,80,120")
    for b in (FEATURED, STRICT, PROPS):
        pm = featured_dist(b)
        s = stats(pm)
        q = s["q"]
        print(f"  {b.name}")
        print(f"     среднее {s['mean']:.1f}  p25 {q[0.25]}  мед {q[0.5]}  p75 {q[0.75]}  p90 {q[0.9]}  p99 {q[0.99]}  макс {s['max']}  (сумма вероятностей {s['total']:.6f})")
        print("     P(получить за N желаний): " + "  ".join(f"N={n}: {p_within(pm,n)*100:5.1f}%" for n in (10, 20, 30, 45, 60, 80, 100, 120, 160)))
