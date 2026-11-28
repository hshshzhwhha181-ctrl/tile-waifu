#!/usr/bin/env python3
"""Generate deterministic synthetic MP §7.4 analytics events for dashboards DB-01..DB-10.

All generated events use HMAC-style pseudonymized `uid` (`u_<32hex>`), zero PII,
and realistic numbers grounded in design/specs/MONETIZATION_PLAN.md (§1.4, §7.1, §7.3, §7.4).
"""
from __future__ import annotations

import argparse
import hashlib
import json
import random
from pathlib import Path

EV_VER = 1
BASE_TS_MS = 1761955200000  # 2025-11-01T00:00:00Z
DAY_MS = 86_400_000

SOURCES = [("organic", 0.50), ("telegram", 0.22), ("vk", 0.18), ("rustore_feat", 0.10)]
BIRTH_BUCKETS = ["1980_1989", "1990_1994", "1995_1999", "2000_2005"]
TIERS = [("neutral", 0.15), ("standard", 0.65), ("full", 0.20)]
METHODS = [("sbp", 0.53), ("card", 0.31), ("sberpay", 0.16)]

SKUS = [
    {"sku_id": "jade_pass_199", "price_rub": 199, "category": "pass", "wishes_equiv": 18, "seg": "minnow"},
    {"sku_id": "pack_79_x2", "price_rub": 79, "category": "moon_pack", "wishes_equiv": 2, "seg": "minnow"},
    {"sku_id": "path_fund_990", "price_rub": 990, "category": "fund", "wishes_equiv": 26, "seg": "dolphin"},
    {"sku_id": "ssr_direct_1490", "price_rub": 1490, "category": "direct_skin", "wishes_equiv": 39, "seg": "dolphin"},
    {"sku_id": "ssr_plus_direct_2490", "price_rub": 2490, "category": "direct_skin", "wishes_equiv": 65, "seg": "whale"},
    {"sku_id": "season_bundle_5390", "price_rub": 5390, "category": "bundle", "wishes_equiv": 140, "seg": "whale"},
    {"sku_id": "pack_9990", "price_rub": 9990, "category": "moon_pack", "wishes_equiv": 260, "seg": "kraken"},
]


def _pick_weighted(rng: random.Random, items: list[tuple[str, float]]) -> str:
    r = rng.random()
    acc = 0.0
    for val, w in items:
        acc += w
        if r <= acc:
            return val
    return items[-1][0]


def _pseudo_uid(seed: int, idx: int) -> str:
    h = hashlib.sha256(f"tw_synth_{seed}_{idx}".encode("utf-8")).hexdigest()[:32]
    return f"u_{h}"


def _bucket_econ(v: int) -> str:
    if v <= 0:
        return "0"
    if v < 100:
        return "1_99"
    if v < 500:
        return "100_499"
    if v < 1500:
        return "500_1499"
    if v < 5000:
        return "1500_4999"
    if v < 15000:
        return "5000_14999"
    return "15000_plus"


def generate_events(n_users: int = 800, days: int = 31, seed: int = 20261128) -> list[dict]:
    rng = random.Random(seed)
    events: list[dict] = []
    purchase_seq = 0

    def emit(uid: str, sess: str, ts: int, tier: str, age_ok: bool, conn: str, name: str, params: dict, source: str | None = None) -> None:
        if source is None:
            source = "server" if name in ("purchase_ok", "purchase_refund", "moon_balance_audit") else "client"
        events.append({
            "event": name,
            "source": source,
            "ts": ts,
            "uid": uid,
            "sess": sess,
            "app_ver": "0.12.0",
            "build": "rustore",
            "lang": "ru",
            "tier": tier,
            "age_ok": age_ok,
            "conn": conn,
            "ev_ver": EV_VER,
            "params": params,
        })

    # Pre-assign spend archetypes matching MP §1.4 / §7.1 (~3.5% paying)
    # Plus enough whales/krakens so DB-10 k-anonymity cohorts are populated cleanly
    for i in range(n_users):
        uid = _pseudo_uid(seed, i)
        src = _pick_weighted(rng, SOURCES)
        tier = _pick_weighted(rng, TIERS)
        conn = "wifi" if rng.random() < 0.68 else "mobile"
        cohort_day = i % 5  # installs spread across days 0..4 so D30 exists for early installs
        install_day_start = BASE_TS_MS + cohort_day * DAY_MS
        install_ts = install_day_start + rng.randint(60_000, 12 * 3600_000)

        # Spend tier assignment: ~94% f2p, ~3.5% minnow, ~1.5% dolphin, ~0.8% whale, ~0.2% kraken
        sr = rng.random()
        if sr < 0.004:
            seg = "kraken"
        elif sr < 0.014:
            seg = "whale"
        elif sr < 0.032:
            seg = "dolphin"
        elif sr < 0.065:
            seg = "minnow"
        else:
            seg = "f2p"

        sess0 = f"s_{i}_0"
        emit(uid, sess0, install_ts, tier, False, conn, "app_open", {"src": src})
        age_ok = rng.random() >= 0.04
        emit(uid, sess0, install_ts + 2000, tier, age_ok, conn, "age_gate_result", {
            "ok": age_ok,
            "birth_year_bucket": rng.choice(BIRTH_BUCKETS) if age_ok else "under_18",
            "tier_toggle": tier,
        })
        if not age_ok:
            continue

        emit(uid, sess0, install_ts + 4000, tier, True, conn, "session_start", {"src": src})
        if rng.random() < 0.91:
            emit(uid, sess0, install_ts + 45_000, tier, True, conn, "ftue_step", {"step": "first_win", "t_s": rng.randint(25, 58)})
            emit(uid, sess0, install_ts + 48_000, tier, True, conn, "level_end", {
                "mode": "path", "level": 1, "win": True, "dur_s": rng.randint(25, 58), "pairs": 12,
            })
        else:
            emit(uid, sess0, install_ts + 60_000, tier, True, conn, "session_end", {"dur_s": 56})
            continue

        # Determine active days (D0 always active; D1 ~34%, D7 ~13%, D30 ~5.5%; payers retain higher)
        ret_boost = {"f2p": 1.0, "minnow": 2.0, "dolphin": 2.6, "whale": 3.2, "kraken": 3.6}[seg]
        active_days = [0]
        for d in range(1, days - cohort_day):
            base_p = 0.34 if d == 1 else (0.20 if d <= 3 else (0.12 if d <= 7 else (0.075 if d <= 14 else 0.052)))
            p = min(0.88, base_p * ret_boost)
            if rng.random() < p:
                active_days.append(d)

        # Simulate user progression across active days
        k_pity = 0
        g_fifty = 0
        c_candle = 0
        purchases_done = 0
        total_rub = 0
        rank = 0
        limit_rub = 0
        has_linked = False
        gems = 300
        moon = 0

        for d_idx, d in enumerate(active_days):
            day_ts = (install_ts + 300_000) if d == 0 else (install_day_start + d * DAY_MS + rng.randint(60_000, 20 * 3600_000))
            sess = f"s_{i}_{d}"
            if d > 0:
                emit(uid, sess, day_ts, tier, True, conn, "app_open", {"src": src})
                emit(uid, sess, day_ts + 1000, tier, True, conn, "session_start", {"src": src})

            # Gameplay & economy earn
            emit(uid, sess, day_ts + 60_000, tier, True, conn, "level_end", {
                "mode": "path", "level": min(60, 2 + d_idx * 2), "win": rng.random() < 0.82,
                "dur_s": rng.randint(40, 110), "pairs": rng.randint(14, 28),
            })
            gems += 180

            # Banner view & pulls (L5 -> from D0/D1 onward)
            if d_idx >= 0 and (d_idx == 0 and rng.random() < 0.62 or d_idx >= 1):
                banner_id = "first_guest" if d < 7 else "season_akari"
                emit(uid, sess, day_ts + 90_000, tier, True, conn, "wish_banner_view", {
                    "banner_id": banner_id, "family": "standard", "k": k_pity, "g": g_fifty, "c": c_candle,
                })
                if rng.random() < 0.25:
                    emit(uid, sess, day_ts + 92_000, tier, True, conn, "odds_open", {
                        "banner_id": banner_id, "odds_hash": "tw_odds_v1_sha256",
                    })
                if rng.random() < 0.30:
                    emit(uid, sess, day_ts + 95_000, tier, True, conn, "preview_open", {
                        "skin_id": "akari_silk", "from": "banner",
                    })
                if d == 14 and rng.random() < 0.5:
                    emit(uid, sess, day_ts + 96_000, tier, True, conn, "direct_sale_open", {
                        "skin_id": "akari_silk", "day": 14,
                    })

                n_pulls = (
                    30 if seg == "kraken"
                    else (20 if seg == "whale"
                          else (10 if (seg in ("dolphin", "minnow") or d_idx % 2 == 0)
                                else (10 if rng.random() < 0.35 else 0)))
                )
                if n_pulls > 0:
                    emit(uid, sess, day_ts + 100_000, tier, True, conn, "wish_confirm_open", {
                        "banner_id": banner_id, "n": n_pulls, "cost": n_pulls * 150,
                        "pay_from": "moon" if moon >= n_pulls * 150 else "gems",
                        "limit_left": max(0, limit_rub - total_rub) if limit_rub > 0 else 999999,
                    })
                    ssr_in_series = 0
                    for p_idx in range(1, n_pulls + 1):
                        # Soft pity ramp matching data/shop.json / MP §3:
                        # base 0.015, soft pity from k>=60 (+0.05/pull), hard pity at 80 (first_guest hard pity at 30)
                        k_before = k_pity
                        g_before = g_fifty
                        c_before = c_candle
                        hard_cap = 30 if banner_id == "first_guest" else 80
                        if k_before + 1 >= hard_cap:
                            p_ssr = 1.0
                        elif k_before >= 60:
                            p_ssr = min(1.0, 0.015 + (k_before - 59) * 0.05)
                        else:
                            p_ssr = 0.015
                        p_s = min(1.0 - p_ssr, 0.08)
                        roll = rng.random()
                        if roll < p_ssr:
                            result = "ssr"
                            if g_before == 1 or c_before >= 1 or rng.random() < 0.5:
                                featured = True
                                candle_used = c_before >= 1
                                g_fifty = 0
                                c_candle = 0
                            else:
                                featured = False
                                candle_used = False
                                g_fifty = 1
                                c_candle = 1
                            k_pity = 0
                            ssr_in_series += 1
                            item_id = "akari_silk" if featured else "off_banner_ssr"
                        elif roll < p_ssr + p_s:
                            result = "s"
                            featured = False
                            candle_used = False
                            k_pity += 1
                            item_id = "s_charm_01"
                        else:
                            result = "gift"
                            featured = False
                            candle_used = False
                            k_pity += 1
                            item_id = "tea_gift_01"
                        cost_cur = "moon" if moon >= 150 else "gems"
                        if cost_cur == "moon":
                            moon -= 150
                        else:
                            gems = max(0, gems - 150)
                        emit(uid, sess, day_ts + 100_000 + p_idx * 500, tier, True, conn, "wish_pull", {
                            "banner_id": banner_id, "family": "standard", "idx": p_idx,
                            "k_before": k_before, "g_before": g_before, "c_before": c_before,
                            "result": result, "item_id": item_id, "featured": featured, "candle": candle_used,
                            "cost_cur": cost_cur, "cost_amt": 150,
                            "odds_hash": "tw_odds_v1_sha256", "seed_commit": f"sc_{i}_{d}_{p_idx}",
                        })
                    emit(uid, sess, day_ts + 110_000, tier, True, conn, "wish_series_end", {
                        "n": n_pulls, "ssr_count": ssr_in_series, "spent_rub_equiv": round(n_pulls * 38.0, 2),
                    })

            # Store & purchases (from D1+ or high-intent D0)
            if d_idx >= 1 or seg != "f2p":
                if rng.random() < (0.85 if seg != "f2p" else 0.28):
                    emit(uid, sess, day_ts + 130_000, tier, True, conn, "store_open", {"section": "main"})
                    # Compliance: voluntary spend limit choice shown on first store open
                    if d_idx == 1 and rng.random() < 0.6:
                        emit(uid, sess, day_ts + 131_000, tier, True, conn, "limit_choice_shown", {"type": "monthly_rub"})
                        if rng.random() < 0.35:
                            limit_rub = rng.choice([1500, 3000, 6000, 15000])
                            emit(uid, sess, day_ts + 132_000, tier, True, conn, "limit_set", {
                                "value": limit_rub, "prev": 0, "type": "monthly_rub",
                            })

                should_buy = (
                    (seg == "minnow" and purchases_done < 2 and rng.random() < 0.45)
                    or (seg == "dolphin" and purchases_done < 4 and rng.random() < 0.55)
                    or (seg == "whale" and purchases_done < 7 and rng.random() < 0.65)
                    or (seg == "kraken" and purchases_done < 10 and rng.random() < 0.78)
                )
                if should_buy:
                    if not has_linked:
                        has_linked = True
                        emit(uid, sess, day_ts + 133_000, tier, True, conn, "account_link", {
                            "provider": rng.choice(["vk", "yandex", "email"]),
                        })
                    seg_skus = [s for s in SKUS if s["seg"] == seg] or [SKUS[0]]
                    sku = rng.choice(seg_skus)
                    emit(uid, sess, day_ts + 134_000, tier, True, conn, "sku_view", {
                        "section": sku["category"], "sku_id": sku["sku_id"],
                        "price_rub": sku["price_rub"], "wishes_equiv": sku["wishes_equiv"],
                    })
                    if limit_rub > 0 and total_rub + sku["price_rub"] > limit_rub:
                        emit(uid, sess, day_ts + 135_000, tier, True, conn, "limit_hit", {
                            "value": limit_rub, "type": "monthly_rub",
                        })
                        emit(uid, sess, day_ts + 136_000, tier, True, conn, "cooldown_prompt", {"type": "limit_hit"})
                        if rng.random() < 0.65:
                            emit(uid, sess, day_ts + 137_000, tier, True, conn, "cooldown_accept", {"type": "limit_hit"})
                            if rng.random() < 0.35:
                                emit(uid, sess, day_ts + 138_000, tier, True, conn, "pause_set", {"value": 7, "type": "days"})
                    else:
                        purchase_seq += 1
                        pid = f"p_{purchase_seq:06d}"
                        method = _pick_weighted(rng, METHODS)
                        emit(uid, sess, day_ts + 135_000, tier, True, conn, "purchase_start", {
                            "sku_id": sku["sku_id"], "price_rub": sku["price_rub"], "method": method, "purchase_id": pid,
                        })
                        pr = rng.random()
                        if pr < 0.011:
                            emit(uid, sess, day_ts + 136_000, tier, True, conn, "purchase_fail", {
                                "sku_id": sku["sku_id"], "price_rub": sku["price_rub"], "method": method,
                                "purchase_id": pid, "err": "sdk_network_timeout",
                            })
                        elif pr < 0.025:
                            emit(uid, sess, day_ts + 136_000, tier, True, conn, "purchase_cancel", {
                                "sku_id": sku["sku_id"], "price_rub": sku["price_rub"], "method": method, "purchase_id": pid,
                            })
                        elif pr < 0.032:
                            emit(uid, sess, day_ts + 136_000, tier, True, conn, "purchase_pending", {
                                "sku_id": sku["sku_id"], "price_rub": sku["price_rub"], "method": method, "purchase_id": pid,
                            })
                        else:
                            purchases_done += 1
                            total_rub += sku["price_rub"]
                            moon += sku["wishes_equiv"] * 150
                            emit(uid, sess, day_ts + 136_000, tier, True, conn, "purchase_ok", {
                                "sku_id": sku["sku_id"], "price_rub": sku["price_rub"], "method": method,
                                "purchase_id": pid, "n": purchases_done, "category": sku["category"],
                            })
                            emit(uid, sess, day_ts + 137_000, tier, True, conn, "moon_balance_audit", {
                                "ok": True, "delta": 0,
                            })
                            if sku["category"] == "pass":
                                emit(uid, sess, day_ts + 138_000, tier, True, conn, "pass_buy", {"season": "s1", "line": "prem"})
                            elif sku["category"] == "fund":
                                emit(uid, sess, day_ts + 138_000, tier, True, conn, "fund_buy", {"fund_id": "path_fund_1"})
                            # Circle rank progression (MP §7.4: from/to strictly without RUB!)
                            new_rank = 4 if total_rub >= 25000 else (3 if total_rub >= 10000 else (2 if total_rub >= 3000 else (1 if total_rub >= 500 else 0)))
                            if new_rank > rank:
                                emit(uid, sess, day_ts + 139_000, tier, True, conn, "rank_up", {"from": rank, "to": new_rank})
                                rank = new_rank
                            # Rare refund (~0.9%)
                            if rng.random() < 0.009:
                                emit(uid, sess, day_ts + 2 * DAY_MS, tier, True, conn, "purchase_refund", {
                                    "sku_id": sku["sku_id"], "amount": sku["price_rub"], "debt_after": 0, "days_since": 2,
                                })

            # Rewarded ads (hard cap <= 3/day/user per MP §7.1)
            ad_watches = rng.choices([0, 1, 2, 3], weights=[0.52, 0.28, 0.14, 0.06], k=1)[0]
            for a_i in range(ad_watches):
                emit(uid, sess, day_ts + 160_000 + a_i * 5000, tier, True, conn, "ad_offer", {"placement": "daily_bonus"})
                emit(uid, sess, day_ts + 161_000 + a_i * 5000, tier, True, conn, "ad_watch", {"placement": "daily_bonus"})
                emit(uid, sess, day_ts + 162_000 + a_i * 5000, tier, True, conn, "ad_reward", {
                    "placement": "daily_bonus", "ecpm_bucket": rng.choice(["200_250", "250_300"]),
                })
                if rng.random() < 0.004:
                    emit(uid, sess, day_ts + 163_000 + a_i * 5000, tier, True, conn, "ad_complaint", {"placement": "daily_bonus"})

            # Daily econ_snapshot (buckets only)
            emit(uid, sess, day_ts + 200_000, tier, True, conn, "econ_snapshot", {
                "gems": _bucket_econ(gems),
                "tickets": _bucket_econ(rng.randint(0, 15)),
                "moon": _bucket_econ(moon),
                "petals": _bucket_econ(rng.randint(0, 120)),
                "coins": _bucket_econ(rng.randint(1000, 25000)),
            })

            emit(uid, sess, day_ts + 240_000, tier, True, conn, "session_end", {"dur_s": rng.randint(180, 900)})

    events.sort(key=lambda e: e["ts"])
    return events


def main() -> int:
    ap = argparse.ArgumentParser(description="Generate synthetic MP §7.4 analytics NDJSON")
    ap.add_argument("--users", type=int, default=800)
    ap.add_argument("--days", type=int, default=31)
    ap.add_argument("--seed", type=int, default=20261128)
    ap.add_argument("--out", type=Path, required=True)
    args = ap.parse_args()
    evs = generate_events(n_users=args.users, days=args.days, seed=args.seed)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    with args.out.open("w", encoding="utf-8") as f:
        for e in evs:
            f.write(json.dumps(e, ensure_ascii=False) + "\n")
    print(f"SYNTH_EVENTS_OK count={len(evs)} users={args.users} out={args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
