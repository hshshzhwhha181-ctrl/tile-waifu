#!/usr/bin/env python3
"""Build live analytics dashboards DB-01..DB-10 (MONETIZATION_PLAN.md §7.3).

Reads NDJSON or SQLite (`analytics_events` created by `server/src/events.mjs`).
Outputs structured JSON (`dashboards.json`) and a self-contained static HTML report (`dashboards.html`).

STRICT ANONYMIZATION RULE FOR DB-10 ('Радар китов'):
  - Zero user IDs (`uid`), zero nicks, zero emails, zero individual payment rows.
  - Only aggregate concentration ratios, anonymized Circle rank bands, and aggregate churn-risk counts.
  - Explicit policy marker: `support_and_thanks_only_no_targeted_discounts`.
"""
from __future__ import annotations

import argparse
import collections
import datetime
import html
import json
import math
import sqlite3
from pathlib import Path

NET_MARGIN = 0.72  # MP §7.1: commission + tax factor
DAY_MS = 86_400_000
K_ANON_MIN = 5     # minimum cell size for DB-10 rank bands (smaller cells are merged/suppressed)


def load_events_ndjson(path: Path) -> list[dict]:
    out = []
    with path.open("r", encoding="utf-8") as f:
        for line in f:
            s = line.strip()
            if s:
                out.append(json.loads(s))
    return out


def load_events_sqlite(path: Path) -> list[dict]:
    conn = sqlite3.connect(str(path))
    try:
        rows = conn.execute(
            "SELECT event_name, ts_ms, uid_hmac, sess, app_ver, build, lang, tier, age_ok, conn, ev_ver, params_json "
            "FROM analytics_events ORDER BY ts_ms ASC, id ASC"
        ).fetchall()
    finally:
        conn.close()
    return [
        {
            "event": r[0],
            "ts": int(r[1]),
            "uid": r[2],
            "sess": r[3],
            "app_ver": r[4],
            "build": r[5],
            "lang": r[6],
            "tier": r[7],
            "age_ok": bool(r[8]),
            "conn": r[9],
            "ev_ver": int(r[10]),
            "params": json.loads(r[11]),
        }
        for r in rows
    ]


def _day_str(ts_ms: int) -> str:
    return datetime.datetime.fromtimestamp(ts_ms / 1000.0, tz=datetime.timezone.utc).strftime("%Y-%m-%d")


def _pct(num: float, den: float) -> float:
    return round((num / den) * 100.0, 2) if den > 0 else 0.0


def _segment_of(total_rub: float) -> str:
    if total_rub <= 0:
        return "f2p"
    if total_rub < 1000:
        return "minnow"
    if total_rub < 5000:
        return "dolphin"
    if total_rub < 25000:
        return "whale"
    return "kraken"


def _pctl(vals: list[float], p: float) -> float:
    if not vals:
        return 0.0
    s = sorted(vals)
    idx = min(len(s) - 1, max(0, int(math.ceil(p * len(s))) - 1))
    return float(s[idx])


def compute_dashboards(events: list[dict]) -> dict:
    if not events:
        raise ValueError("Cannot build dashboards from empty event stream")

    events_sorted = sorted(events, key=lambda e: int(e["ts"]))
    max_ts = int(events_sorted[-1]["ts"])
    min_ts = int(events_sorted[0]["ts"])

    # Per-user rollups (internal only — NEVER leaked into DB-10!)
    first_ts: dict[str, int] = {}
    last_ts: dict[str, int] = {}
    user_src: dict[str, str] = {}
    user_active_days: dict[str, set[int]] = collections.defaultdict(set)
    dau_by_day: dict[str, set[str]] = collections.defaultdict(set)

    # DB-01 Funnel sets
    s_installed: set[str] = set()
    s_ftue: set[str] = set()
    s_banner: set[str] = set()
    s_ssr: set[str] = set()
    s_store: set[str] = set()
    user_purchases: dict[str, list[dict]] = collections.defaultdict(list)

    # DB-02 Revenue
    rev_by_sku: dict[str, float] = collections.defaultdict(float)
    rev_by_cat: dict[str, float] = collections.defaultdict(float)
    user_spend: dict[str, float] = collections.defaultdict(float)

    # DB-03 Gacha Health
    banner_stats: dict[str, dict] = collections.defaultdict(lambda: {
        "pulls": 0, "ssr": 0, "s": 0, "gift": 0, "featured_ssr": 0,
        "pity_ssr": 0, "candle_ssr": 0, "odds_hashes": set(),
    })
    pulls_since_featured: dict[tuple[str, str], int] = collections.defaultdict(int)
    pulls_to_featured_samples: list[int] = []
    pulls_to_ssr_samples: list[int] = []
    pulls_since_ssr: dict[tuple[str, str], int] = collections.defaultdict(int)

    # DB-04 Economy
    econ_sinks: dict[str, int] = collections.defaultdict(int)
    econ_snapshot_buckets: dict[str, collections.Counter] = collections.defaultdict(collections.Counter)
    pass_buys = 0
    fund_buys = 0
    event_shop_buys = 0

    # DB-06 Payment Ops
    pay_counts = collections.Counter()
    pay_methods = collections.Counter()
    refund_rub = 0.0
    refund_count = 0
    audit_ok = 0
    audit_fail = 0
    audit_max_abs_delta = 0
    debt_users: set[str] = set()

    # DB-07 LiveOps
    banner_viewers: set[str] = set()
    confirm_openers: set[str] = set()
    pullers: set[str] = set()
    preview_viewers: set[str] = set()
    preview_buyers: set[str] = set()
    direct_sale_opens: collections.Counter = collections.Counter()

    # DB-08 Compliance
    age_pass = 0
    age_fail = 0
    birth_buckets = collections.Counter()
    limit_shown_users: set[str] = set()
    limit_set_users: set[str] = set()
    limit_hit_count = 0
    pause_set_count = 0
    cooldown_prompt_count = 0
    cooldown_accept_count = 0

    # DB-09 Ads
    ad_offers = 0
    ad_watches = 0
    ad_rewards = 0
    ad_complaints = 0
    ad_ecpm_buckets = collections.Counter()
    ad_per_user_day: dict[tuple[str, str], int] = collections.defaultdict(int)

    # DB-10 Circle rank (internal map -> strictly aggregated before output!)
    user_max_rank: dict[str, int] = collections.defaultdict(int)

    for ev in events_sorted:
        name = ev["event"]
        ts = int(ev["ts"])
        uid = str(ev["uid"])
        p = ev.get("params") or {}
        day_s = _day_str(ts)

        if uid not in first_ts:
            first_ts[uid] = ts
        last_ts[uid] = max(last_ts.get(uid, ts), ts)
        rel_day = max(0, (ts - first_ts[uid]) // DAY_MS)

        if name == "app_open":
            s_installed.add(uid)
            if uid not in user_src:
                user_src[uid] = str(p.get("src", "unknown"))
        elif name == "session_start":
            s_installed.add(uid)
            user_active_days[uid].add(rel_day)
            dau_by_day[day_s].add(uid)
            if uid not in user_src:
                user_src[uid] = str(p.get("src", "unknown"))
        elif name == "age_gate_result":
            if bool(p.get("ok")):
                age_pass += 1
            else:
                age_fail += 1
            birth_buckets[str(p.get("birth_year_bucket", "unknown"))] += 1
        elif name == "ftue_step":
            s_ftue.add(uid)
        elif name == "wish_banner_view":
            s_banner.add(uid)
            banner_viewers.add(uid)
        elif name == "preview_open":
            preview_viewers.add(uid)
        elif name == "direct_sale_open":
            direct_sale_opens[str(p.get("skin_id", "unknown"))] += 1
        elif name == "wish_confirm_open":
            confirm_openers.add(uid)
        elif name == "wish_pull":
            pullers.add(uid)
            bid = str(p.get("banner_id", "unknown"))
            bs = banner_stats[bid]
            bs["pulls"] += 1
            bs["odds_hashes"].add(str(p.get("odds_hash", "")))
            res = str(p.get("result", "gift"))
            bs[res] = bs.get(res, 0) + 1
            key = (uid, str(p.get("family", bid)))
            pulls_since_featured[key] += 1
            pulls_since_ssr[key] += 1
            if res == "ssr":
                s_ssr.add(uid)
                pulls_to_ssr_samples.append(pulls_since_ssr[key])
                pulls_since_ssr[key] = 0
                if int(p.get("k_before", 0)) >= 69:
                    bs["pity_ssr"] += 1
                if bool(p.get("candle")):
                    bs["candle_ssr"] += 1
                if bool(p.get("featured")):
                    bs["featured_ssr"] += 1
                    pulls_to_featured_samples.append(pulls_since_featured[key])
                    pulls_since_featured[key] = 0
            cur = str(p.get("cost_cur", "gems"))
            econ_sinks[cur] += int(p.get("cost_amt", 0))
        elif name == "store_open":
            s_store.add(uid)
        elif name in ("purchase_start", "purchase_fail", "purchase_cancel", "purchase_pending"):
            pay_counts[name] += 1
            pay_methods[str(p.get("method", "unknown"))] += 1
        elif name == "purchase_ok":
            pay_counts[name] += 1
            pay_methods[str(p.get("method", "unknown"))] += 1
            price = float(p.get("price_rub", 0.0))
            sku = str(p.get("sku_id", "unknown"))
            cat = str(p.get("category", "other"))
            rev_by_sku[sku] += price
            rev_by_cat[cat] += price
            user_spend[uid] += price
            user_purchases[uid].append({"ts": ts, "price_rub": price, "sku_id": sku, "rel_day": rel_day})
            if uid in preview_viewers:
                preview_buyers.add(uid)
        elif name == "purchase_refund":
            refund_count += 1
            refund_rub += float(p.get("amount", 0.0))
            if float(p.get("debt_after", 0.0)) > 0:
                debt_users.add(uid)
        elif name == "moon_balance_audit":
            if bool(p.get("ok")):
                audit_ok += 1
            else:
                audit_fail += 1
            audit_max_abs_delta = max(audit_max_abs_delta, abs(int(p.get("delta", 0))))
        elif name == "limit_choice_shown":
            limit_shown_users.add(uid)
        elif name == "limit_set":
            limit_set_users.add(uid)
        elif name == "limit_hit":
            limit_hit_count += 1
        elif name == "pause_set":
            pause_set_count += 1
        elif name == "cooldown_prompt":
            cooldown_prompt_count += 1
        elif name == "cooldown_accept":
            cooldown_accept_count += 1
        elif name == "rank_up":
            user_max_rank[uid] = max(user_max_rank[uid], int(p.get("to", 0)))
        elif name == "pass_buy":
            pass_buys += 1
        elif name == "fund_buy":
            fund_buys += 1
        elif name == "event_shop_buy":
            event_shop_buys += 1
        elif name == "ad_offer":
            ad_offers += 1
        elif name == "ad_watch":
            ad_watches += 1
        elif name == "ad_reward":
            ad_rewards += 1
            ad_ecpm_buckets[str(p.get("ecpm_bucket", "unknown"))] += 1
            ad_per_user_day[(uid, day_s)] += 1
        elif name == "ad_complaint":
            ad_complaints += 1
        elif name == "econ_snapshot":
            for cur_k in ("gems", "tickets", "moon", "petals", "coins"):
                if cur_k in p:
                    econ_snapshot_buckets[cur_k][str(p[cur_k])] += 1

    # ── DB-01 Funnel ──
    n_inst = len(s_installed)
    n_payers = len(user_purchases)
    n_repeat = sum(1 for plist in user_purchases.values() if len(plist) >= 2)
    by_source: dict[str, dict] = {}
    for src_name in sorted(set(user_src.values())):
        su = {u for u, s in user_src.items() if s == src_name}
        by_source[src_name] = {
            "installs": len(su),
            "ftue_pct": _pct(len(su & s_ftue), len(su)),
            "payers": len(su & set(user_purchases.keys())),
            "payer_conv_pct": _pct(len(su & set(user_purchases.keys())), len(su)),
        }
    db01 = {
        "id": "DB-01",
        "title": "Воронка конверсии",
        "owner": "продукт",
        "installs": n_inst,
        "steps": {
            "install": {"users": n_inst, "pct_of_installs": 100.0},
            "ftue_first_win": {"users": len(s_ftue), "pct_of_installs": _pct(len(s_ftue), n_inst)},
            "wish_banner_view": {"users": len(s_banner), "pct_of_installs": _pct(len(s_banner), n_inst)},
            "ssr_obtained": {"users": len(s_ssr), "pct_of_installs": _pct(len(s_ssr), n_inst)},
            "store_open": {"users": len(s_store), "pct_of_installs": _pct(len(s_store), n_inst)},
            "first_purchase": {"users": n_payers, "pct_of_installs": _pct(n_payers, n_inst)},
            "repeat_purchase": {"users": n_repeat, "pct_of_payers": _pct(n_repeat, n_payers)},
        },
        "by_source": by_source,
    }

    # ── DB-02 Revenue ──
    gross_rub = round(sum(user_spend.values()), 2)
    net_rub = round(gross_rub * NET_MARGIN, 2)
    avg_dau = (sum(len(s) for s in dau_by_day.values()) / max(1, len(dau_by_day)))
    mau = len(user_active_days)
    rev_by_segment: dict[str, float] = collections.defaultdict(float)
    users_by_segment: collections.Counter = collections.Counter()
    for uid in s_installed:
        seg = _segment_of(user_spend.get(uid, 0.0))
        users_by_segment[seg] += 1
        rev_by_segment[seg] += user_spend.get(uid, 0.0)
    ltv_by_day = {}
    for horizon in (1, 7, 30):
        h_rev = sum(
            item["price_rub"]
            for plist in user_purchases.values()
            for item in plist
            if item["rel_day"] <= horizon
        )
        ltv_by_day[f"D{horizon}"] = round(h_rev / max(1, n_inst), 2)
    db02 = {
        "id": "DB-02",
        "title": "Выручка",
        "owner": "продукт, финансы",
        "gross_rub": gross_rub,
        "net_rub": net_rub,
        "net_factor": NET_MARGIN,
        "payers": n_payers,
        "arpdau_rub": round(gross_rub / max(1.0, avg_dau * max(1, len(dau_by_day))), 2),
        "arppu_rub": round(gross_rub / max(1, n_payers), 2),
        "arpu_mau_rub": round(gross_rub / max(1, mau), 2),
        "cohort_ltv_gross_rub": ltv_by_day,
        "by_sku_rub": {k: round(v, 2) for k, v in sorted(rev_by_sku.items())},
        "by_category_rub": {k: round(v, 2) for k, v in sorted(rev_by_cat.items())},
        "by_segment": {
            seg: {
                "users": users_by_segment[seg],
                "gross_rub": round(rev_by_segment[seg], 2),
                "rev_share_pct": _pct(rev_by_segment[seg], gross_rub),
            }
            for seg in ("f2p", "minnow", "dolphin", "whale", "kraken")
        },
    }

    # ── DB-03 Gacha Health (with Pearson chi-square vs expected SSR/S rates) ──
    # Expected effective rates from soft-pity model: SSR ~2.25%, S ~8.0%, gift ~89.75%
    exp_rates = {"ssr": 0.0225, "s": 0.080, "gift": 0.8975}
    banners_out = {}
    for bid, bs in sorted(banner_stats.items()):
        n_p = bs["pulls"]
        chi2 = 0.0
        for cls, rate in exp_rates.items():
            exp_c = max(1e-9, n_p * rate)
            obs_c = bs.get(cls, 0)
            chi2 += ((obs_c - exp_c) ** 2) / exp_c
        banners_out[bid] = {
            "pulls": n_p,
            "ssr_count": bs["ssr"],
            "ssr_rate_pct": _pct(bs["ssr"], n_p),
            "s_rate_pct": _pct(bs["s"], n_p),
            "featured_ssr_count": bs["featured_ssr"],
            "hard_pity_share_pct": _pct(bs["pity_ssr"], bs["ssr"]),
            "candle_share_pct": _pct(bs["candle_ssr"], bs["ssr"]),
            "chi2_stat": round(chi2, 3),
            "chi2_df": 2,
            "odds_hashes": sorted(bs["odds_hashes"]),
            "odds_consistent": len(bs["odds_hashes"]) <= 1,
        }
    mean_to_featured = round(sum(pulls_to_featured_samples) / len(pulls_to_featured_samples), 2) if pulls_to_featured_samples else 0.0
    db03 = {
        "id": "DB-03",
        "title": "Здоровье гачи",
        "owner": "экономика, юрист (аудит)",
        "banners": banners_out,
        "mean_pulls_to_featured": mean_to_featured,
        "target_mean_pulls_to_featured": 61.8,
        "p50_pulls_to_ssr": _pctl(pulls_to_ssr_samples, 0.50),
        "p90_pulls_to_ssr": _pctl(pulls_to_ssr_samples, 0.90),
    }

    # ── DB-04 Economy ──
    # Approximate stock index I-6 from gems snapshot buckets (weeks of ~1260 gems/week F2P income)
    bucket_mid = {"0": 0, "1_99": 50, "100_499": 300, "500_1499": 1000, "1500_4999": 3000, "5000_14999": 9000, "15000_plus": 20000}
    gems_hist = econ_snapshot_buckets["gems"]
    total_snaps = sum(gems_hist.values())
    avg_gems_stock = sum(bucket_mid.get(b, 0) * c for b, c in gems_hist.items()) / max(1, total_snaps)
    stock_index_weeks = round(avg_gems_stock / 1260.0, 2)
    db04 = {
        "id": "DB-04",
        "title": "Экономика",
        "owner": "экономика",
        "sinks_by_currency": dict(sorted(econ_sinks.items())),
        "stock_index_i6_weeks": stock_index_weeks,
        "stock_index_alert": stock_index_weeks > 8.0,
        "snapshot_buckets": {k: dict(v) for k, v in sorted(econ_snapshot_buckets.items())},
        "pass_buys": pass_buys,
        "fund_buys": fund_buys,
        "event_shop_buys": event_shop_buys,
    }

    # ── DB-05 Retention ──
    retention_days = {}
    for d in (1, 3, 7, 14, 30):
        eligible = [u for u in user_active_days if (max_ts - first_ts[u]) >= d * DAY_MS]
        retained = [u for u in eligible if d in user_active_days[u]]
        retention_days[f"D{d}"] = {
            "eligible": len(eligible),
            "retained": len(retained),
            "pct": _pct(len(retained), len(eligible)),
        }
    db05 = {
        "id": "DB-05",
        "title": "Удержание",
        "owner": "продукт",
        "retention": retention_days,
        "avg_dau": round(avg_dau, 1),
        "mau": mau,
        "dau_mau_stickiness_pct": _pct(avg_dau, mau),
    }

    # ── DB-06 Payment Ops ──
    attempts = pay_counts["purchase_start"]
    fail_rate = _pct(pay_counts["purchase_fail"], attempts)
    refund_rate_rub = _pct(refund_rub, gross_rub)
    db06 = {
        "id": "DB-06",
        "title": "Платёжные операции",
        "owner": "саппорт, финансы",
        "attempts": attempts,
        "ok": pay_counts["purchase_ok"],
        "fail": pay_counts["purchase_fail"],
        "cancel": pay_counts["purchase_cancel"],
        "pending": pay_counts["purchase_pending"],
        "fail_rate_pct": fail_rate,
        "fail_rate_alert": fail_rate > 3.0,
        "refund_count": refund_count,
        "refund_rub": round(refund_rub, 2),
        "refund_rate_rub_pct": refund_rate_rub,
        "refund_alert": refund_rate_rub > 2.0,
        "refund_stop": refund_rate_rub > 4.0,
        "reconcile_ok": audit_ok,
        "reconcile_fail": audit_fail,
        "reconcile_max_abs_delta": audit_max_abs_delta,
        "users_with_debt": len(debt_users),
        "methods": dict(sorted(pay_methods.items())),
    }

    # ── DB-07 LiveOps ──
    db07 = {
        "id": "DB-07",
        "title": "Лайвопс",
        "owner": "лайвопс",
        "banner_viewers": len(banner_viewers),
        "confirm_openers": len(confirm_openers),
        "pullers": len(pullers),
        "banner_to_pull_pct": _pct(len(pullers), len(banner_viewers)),
        "preview_10s_viewers": len(preview_viewers),
        "preview_10s_to_buyer_pct": _pct(len(preview_buyers), len(preview_viewers)),
        "direct_sale_opens": dict(sorted(direct_sale_opens.items())),
    }

    # ── DB-08 Compliance ──
    age_total = age_pass + age_fail
    db08 = {
        "id": "DB-08",
        "title": "Комплаенс",
        "owner": "юрист",
        "age_gate_total": age_total,
        "age_gate_pass_pct": _pct(age_pass, age_total),
        "age_gate_fail_count": age_fail,
        "birth_year_buckets": dict(sorted(birth_buckets.items())),
        "limit_choice_shown_users": len(limit_shown_users),
        "limit_set_users": len(limit_set_users),
        "limit_adoption_pct": _pct(len(limit_set_users), len(limit_shown_users)),
        "limit_hit_count": limit_hit_count,
        "pause_set_count": pause_set_count,
        "cooldown_prompt_count": cooldown_prompt_count,
        "cooldown_accept_count": cooldown_accept_count,
        "cooldown_accept_pct": _pct(cooldown_accept_count, cooldown_prompt_count),
    }

    # ── DB-09 Ads ──
    max_ads_user_day = max(ad_per_user_day.values()) if ad_per_user_day else 0
    total_dau_sum = sum(len(s) for s in dau_by_day.values())
    db09 = {
        "id": "DB-09",
        "title": "Реклама",
        "owner": "продукт",
        "offers": ad_offers,
        "watches": ad_watches,
        "rewards": ad_rewards,
        "rewards_per_dau": round(ad_rewards / max(1, total_dau_sum), 3),
        "max_rewards_per_user_day": max_ads_user_day,
        "daily_cap_respected": max_ads_user_day <= 3,
        "complaints": ad_complaints,
        "complaint_rate_pct": _pct(ad_complaints, ad_watches),
        "ecpm_buckets": dict(sorted(ad_ecpm_buckets.items())),
    }

    # ── DB-10 Whale Radar (STRICTLY ANONYMIZED — support & thanks only, zero individual IDs) ──
    payer_spends = sorted((v for v in user_spend.values() if v > 0), reverse=True)
    n_p = len(payer_spends)
    def top_share(frac: float) -> float:
        if n_p == 0 or gross_rub <= 0:
            return 0.0
        k = max(1, int(math.ceil(n_p * frac)))
        return _pct(sum(payer_spends[:k]), gross_rub)

    whale_kraken_rev = rev_by_segment["whale"] + rev_by_segment["kraken"]
    whale_kraken_share = _pct(whale_kraken_rev, gross_rub)

    # Aggregate Circle rank bands & churn risk (inactive >= 7 days before max_ts) — NO uids, k-anonymized
    rank_counts: collections.Counter = collections.Counter()
    rank_churn_risk: collections.Counter = collections.Counter()
    for uid, r_lv in user_max_rank.items():
        if r_lv <= 0:
            continue
        band = "rank_3_plus" if r_lv >= 3 else f"rank_{r_lv}"
        rank_counts[band] += 1
        if (max_ts - last_ts.get(uid, max_ts)) >= 7 * DAY_MS:
            rank_churn_risk[band] += 1

    # Enforce k-anonymity cell suppression (never output small identifiable cells < K_ANON_MIN)
    rank_bands_anon = {}
    for band in ("rank_1", "rank_2", "rank_3_plus"):
        cnt = rank_counts.get(band, 0)
        risk = rank_churn_risk.get(band, 0)
        if cnt == 0:
            rank_bands_anon[band] = {"cohort_size_band": "0", "churn_risk_band": "0"}
        elif cnt < K_ANON_MIN:
            rank_bands_anon[band] = {"cohort_size_band": f"<{K_ANON_MIN}_suppressed", "churn_risk_band": f"<{K_ANON_MIN}_suppressed"}
        else:
            rank_bands_anon[band] = {
                "cohort_size": cnt,
                "churn_risk_count": risk if risk >= K_ANON_MIN else (0 if risk == 0 else f"<{K_ANON_MIN}_suppressed"),
                "churn_risk_pct": _pct(risk, cnt),
            }

    db10 = {
        "id": "DB-10",
        "title": "Радар китов (обезличенный)",
        "owner": "продукт/саппорт",
        "policy": "support_and_thanks_only_no_targeted_discounts",
        "anonymized": True,
        "individual_ids_present": False,
        "pii_present": False,
        "k_anonymity_min": K_ANON_MIN,
        "concentration_pct": {
            "top_1_pct_payers": top_share(0.01),
            "top_5_pct_payers": top_share(0.05),
            "top_10_pct_payers": top_share(0.10),
            "top_25_pct_payers": top_share(0.25),
            "whale_plus_kraken_share": whale_kraken_share,
            "concentration_alert_gt_70pct": whale_kraken_share > 70.0,
        },
        "circle_rank_cohorts": rank_bands_anon,
    }

    return {
        "schema_ver": 1,
        "region": "RU",
        "events_processed": len(events_sorted),
        "window_utc": {"from": _day_str(min_ts), "to": _day_str(max_ts)},
        "dashboards": {
            "DB-01": db01,
            "DB-02": db02,
            "DB-03": db03,
            "DB-04": db04,
            "DB-05": db05,
            "DB-06": db06,
            "DB-07": db07,
            "DB-08": db08,
            "DB-09": db09,
            "DB-10": db10,
        },
    }


def render_html(report: dict) -> str:
    cards = []
    for db_id, db in report["dashboards"].items():
        pretty = html.escape(json.dumps(db, ensure_ascii=False, indent=2))
        badge = "ANONYMIZED / SUPPORT ONLY" if db_id == "DB-10" else html.escape(db.get("owner", ""))
        cards.append(
            f'<section class="card" id="{html.escape(db_id)}">'
            f'<h2>{html.escape(db_id)} — {html.escape(db["title"])} <span class="badge">{badge}</span></h2>'
            f'<pre>{pretty}</pre></section>'
        )
    return (
        "<!doctype html><html lang='ru'><head><meta charset='utf-8'>"
        "<title>Tile Waifu Analytics Dashboards DB-01..DB-10</title>"
        "<style>body{font-family:system-ui,sans-serif;background:#11141a;color:#e8ecf2;margin:24px;}"
        "h1{margin-bottom:6px;} .meta{color:#9aa4b2;margin-bottom:20px;}"
        ".grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(420px,1fr));gap:16px;}"
        ".card{background:#1a1f29;border:1px solid #2b3342;border-radius:10px;padding:14px;}"
        ".badge{font-size:12px;background:#263248;color:#a8c7fa;padding:2px 8px;border-radius:999px;margin-left:8px;}"
        "pre{background:#0d1016;padding:10px;border-radius:6px;overflow:auto;font-size:12px;max-height:360px;}</style>"
        "</head><body>"
        f"<h1>Tile Waifu — Дашборды аналитики (DB-01…DB-10)</h1>"
        f"<div class='meta'>Region: {html.escape(report['region'])} | Events: {report['events_processed']} | "
        f"Window UTC: {html.escape(report['window_utc']['from'])} .. {html.escape(report['window_utc']['to'])}</div>"
        f"<div class='grid'>{''.join(cards)}</div></body></html>"
    )


def main() -> int:
    ap = argparse.ArgumentParser(description="Build live dashboards DB-01..DB-10")
    ap.add_argument("--input", type=Path, help="Input .ndjson or .db (sqlite) file")
    ap.add_argument("--synthetic", action="store_true", help="Generate synthetic data in memory if no --input")
    ap.add_argument("--users", type=int, default=800)
    ap.add_argument("--seed", type=int, default=20261128)
    ap.add_argument("--out-dir", type=Path, default=Path("out_dashboards"))
    args = ap.parse_args()

    if args.input:
        if args.input.suffix == ".db" or args.input.suffix == ".sqlite":
            evs = load_events_sqlite(args.input)
        else:
            evs = load_events_ndjson(args.input)
    else:
        from gen_synthetic_events import generate_events
        evs = generate_events(n_users=args.users, seed=args.seed)

    report = compute_dashboards(evs)
    args.out_dir.mkdir(parents=True, exist_ok=True)
    json_path = args.out_dir / "dashboards.json"
    html_path = args.out_dir / "dashboards.html"
    json_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    html_path.write_text(render_html(report), encoding="utf-8")
    print(f"DASHBOARDS_BUILT 10/10 events={report['events_processed']} json={json_path} html={html_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
