#!/usr/bin/env python3
"""tools/design_lint.py — CI linter verifying single-source-of-truth JSON
(data/skins.json + data/shop.json) against Markdown spec tables
(MONETIZATION_PLAN.md, SKIN_HUD_SYSTEM.md, BATTLE_ULT_SPEC.md,
ULT_CATALOGUE.md, LIVEOPS_CALENDAR.md) and design/specs/ult_catalogue.json.

Closes W17 numeric discrepancies:
  - SSR+ petals 3 600 / dupe ★5 -> 300 (and S/SSR/Gift petals)
  - Direct-sale prices (RUB), star upgrade prices, dye_3, moon packs, passes,
    monthly cards, funds, cosmetics, bundles
  - Direct-sale windows (day 29 / day 57 / headline SSR day 57)
  - Ult thresholds (Layer A: 8 pairs / start 0; Layer B: energy 100 / start 40)
  - Ult ID == skin_id (58 catalog skins <-> ult_catalogue.json & ULT_CATALOGUE.md)
  - Season S count: 4 per season = 3 catalog S + 1 season-pass S (<hero>_s_pass<N>)

Usage:
  python tools/design_lint.py [--check] [--root DIR] [--json OUT] [--selftest]
Exits 0 on pass, 1 on any mismatch or validation error.
"""
from __future__ import annotations

import argparse
import json
import re
import shutil
import sys
import tempfile
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

SKIN_ID_RE = re.compile(
    r"^(mc|rin|hana|yue|nova|zlata|tsubame|miel|kohaku|shirin)_"
    r"(base|vow|(s|ssr|ssrp)_[a-z0-9]{3,16})$"
)
VALID_THEMES = {"SAKURA", "MOON", "JADE", "TIDE", "INK", "EMBER", "NEON", "GILT"}
TIER_HUD = {"base": 0, "vow": 0, "s": 0, "ssr": 1, "ssrp": 2}
SH_TIER_TO_CODE = {"R": "base", "S·vow": "vow", "S": "s", "SSR": "ssr", "SSR+": "ssrp"}
UC_TIER_TO_CODE = {"BASE": "base", "VOW": "vow", "S": "s", "SSR": "ssr", "SSRP": "ssrp"}
UC_MD_TIER_TO_CODE = {"BASE": "base", "VOW": "vow", "S": "s", "SSR": "ssr", "SSR+": "ssrp"}
HUD_STR_TO_INT = {"L0": 0, "L1": 1, "L2": 2}


@dataclass
class LintReport:
    passed: int = 0
    errors: list[dict[str, str]] = field(default_factory=list)

    def check(self, code: str, cond: bool, detail: str) -> None:
        if cond:
            self.passed += 1
        else:
            self.errors.append({"code": code, "detail": detail})

    @property
    def total(self) -> int:
        return self.passed + len(self.errors)

    @property
    def ok(self) -> bool:
        return len(self.errors) == 0


def parse_int(text: str) -> int:
    cleaned = text.replace("\u00a0", " ").replace(" ", "")
    m = re.search(r"-?\d+", cleaned)
    if not m:
        raise ValueError(f"No integer in {text!r}")
    return int(m.group(0))


def parse_float(text: str) -> float:
    cleaned = text.replace("\u00a0", " ").replace(" ", "").replace(",", ".")
    m = re.search(r"-?\d+(?:\.\d+)?", cleaned)
    if not m:
        raise ValueError(f"No float in {text!r}")
    return float(m.group(0))


def parse_all_ints(text: str) -> list[int]:
    # Collapse thousands spaces between digits (e.g. "1 490" -> "1490", "3 600" -> "3600")
    s = re.sub(r"(?<=\d)[\s\u00a0](?=\d{3}\b)", "", text)
    return [int(x) for x in re.findall(r"\d+", s)]


def parse_all_floats(text: str) -> list[float]:
    s = re.sub(r"(?<=\d)[\s\u00a0](?=\d{3}\b)", "", text).replace(",", ".")
    return [float(x) for x in re.findall(r"-?\d+(?:\.\d+)?", s)]


def _fmt_ru_dec(val: float) -> str:
    s = f"{val:g}"
    if "." not in s and isinstance(val, float):
        s = f"{val:.1f}"
    return s.replace(".", ",")


def _fmt_ru_int(val: int) -> str:
    return f"{val:,}".replace(",", " ")


def strip_md(cell: str) -> str:
    return cell.strip().strip("*").strip("`").strip()


def extract_section(text: str, heading_pattern: str, next_heading_pattern: str = r"\n#{2,4}\s") -> str:
    m = re.search(heading_pattern, text)
    if not m:
        return ""
    rest = text[m.start():]
    m2 = re.search(next_heading_pattern, rest[1:])
    if m2:
        return rest[: 1 + m2.start()]
    return rest


def parse_md_table(block: str, table_index: int = 0) -> list[list[str]]:
    """Extract the Nth pipe-delimited Markdown table from a text block.
    Returns rows (excluding separator row; row 0 is header).
    """
    tables: list[list[list[str]]] = []
    cur: list[list[str]] = []
    for raw_line in block.splitlines():
        line = raw_line.strip()
        if line.startswith("|") and line.endswith("|"):
            cells = [c.strip() for c in line[1:-1].split("|")]
            # skip divider row like |---|---|
            if all(re.fullmatch(r":?-{2,}:?", c.replace(" ", "")) for c in cells if c):
                continue
            cur.append(cells)
        else:
            if cur:
                tables.append(cur)
                cur = []
    if cur:
        tables.append(cur)
    if table_index < len(tables):
        return tables[table_index]
    return []


def backtick_tokens(text: str) -> list[str]:
    return re.findall(r"`([a-z0-9_]+)`", text)


# ---------------------------------------------------------------------------
# 1. JSON self-consistency & cross-consistency
# ---------------------------------------------------------------------------

def lint_json_sources(
    skins_doc: dict[str, Any],
    shop_doc: dict[str, Any],
    ult_doc: dict[str, Any],
    rep: LintReport,
) -> None:
    rep.check("JSON-SCHEMA-SKINS", skins_doc.get("schema") == 1, f"skins.json schema={skins_doc.get('schema')} != 1")
    rep.check("JSON-SCHEMA-SHOP", shop_doc.get("schema") == 2, f"shop.json schema={shop_doc.get('schema')} != 2")

    heroes = skins_doc.get("heroes", {})
    rep.check("JSON-HERO-COUNT", len(heroes) == 10, f"expected 10 heroes, got {len(heroes)}")

    skins = skins_doc.get("skins", [])
    main_skins = [s for s in skins if s.get("catalog_source") == "main"]
    pass_skins = [s for s in skins if s.get("catalog_source") == "pass"]
    policy = skins_doc.get("season_s_policy", {})
    rep.check(
        "JSON-SKIN-COUNTS",
        len(main_skins) == 58 and len(pass_skins) == 6 and len(skins) == 64
        and policy.get("catalog_main_count") == 58
        and policy.get("pass_skins_count") == 6
        and policy.get("total_12m_count") == 64
        and policy.get("total_s_per_season") == 4,
        f"counts mismatch: main={len(main_skins)} pass={len(pass_skins)} total={len(skins)} policy={policy}",
    )

    launch_main = [s for s in main_skins if s.get("season") == "S1"]
    rep.check("JSON-LAUNCH-COUNT", len(launch_main) == 38, f"expected 38 launch S1 skins, got {len(launch_main)}")

    # Forbidden words list (SL-TXT / SL-RL-03)
    forbidden = [w.lower() for w in shop_doc.get("forbidden_words", [])]
    tiers = skins_doc.get("tiers", {})
    outfit_pricing = shop_doc.get("outfit_pricing", {})

    # Verify tiers <-> shop.outfit_pricing exact match
    for tcode in ("base", "vow", "s_static", "s", "ssr", "ssrp"):
        st = tiers.get(tcode, {})
        op = outfit_pricing.get(tcode, {})
        rep.check(
            f"JSON-SYNC-TIER-{tcode.upper()}",
            st.get("rub") == op.get("rub")
            and st.get("petals") == op.get("petals")
            and st.get("dupe_petals_after_star5") == op.get("dupe_petals_after_star5")
            and st.get("direct_from_day") == op.get("direct_from_day")
            and st.get("direct_after_days") == op.get("direct_after_days")
            and (st.get("stars") or {}).get("rub") == op.get("stars_rub")
            and (st.get("stars") or {}).get("petals") == op.get("stars_petals"),
            f"skins.tiers[{tcode}] diverges from shop.outfit_pricing[{tcode}]: {st} vs {op}",
        )
        if op.get("stars_rub"):
            rep.check(
                f"JSON-STARS-SUM-{tcode.upper()}",
                sum(op["stars_rub"]) == op.get("stars_rub_total")
                and sum(op["stars_petals"]) == op.get("stars_petals_total"),
                f"star sum mismatch for {tcode}: rub={op.get('stars_rub')} total={op.get('stars_rub_total')}",
            )

    # Verify gacha integer basis-point convention (no float RNG rates) & dupes/gift petals
    gacha = shop_doc.get("gacha", {})
    gacha_int_errs: list[str] = []
    req_bp_keys = ("ssr_base_rate_bp", "soft_pity_step_bp", "props_base_rate_bp", "props_soft_pity_step_bp")
    req_int_keys = ("soft_pity", "hard_pity", "candle_pity", "first_guest_hard_pity", "props_soft_pity", "props_hard_pity", "gift_petals")
    for k in req_bp_keys:
        v = gacha.get(k)
        if not isinstance(v, int) or isinstance(v, bool) or not (0 < v <= 10000):
            gacha_int_errs.append(f"gacha.{k} must be int in (0, 10000], got {v!r}")
    for k in req_int_keys:
        v = gacha.get(k)
        if not isinstance(v, int) or isinstance(v, bool) or v <= 0:
            gacha_int_errs.append(f"gacha.{k} must be positive int, got {v!r}")
    for k, v in gacha.items():
        if isinstance(v, float) or k in ("ssr_base_rate", "soft_pity_step", "props_base_rate", "props_soft_pity_step"):
            gacha_int_errs.append(f"gacha.{k}={v!r} uses forbidden float rate (must use integer *_bp)")
    rep.check("JSON-GACHA-INT-BP", not gacha_int_errs, "; ".join(gacha_int_errs[:5]))

    dupes = gacha.get("dupe_petals_after_star5", {})
    rep.check(
        "JSON-SYNC-DUPES",
        dupes.get("s") == tiers["s"]["dupe_petals_after_star5"] == 60
        and dupes.get("ssr") == tiers["ssr"]["dupe_petals_after_star5"] == 150
        and dupes.get("ssrp") == tiers["ssrp"]["dupe_petals_after_star5"] == 300
        and gacha.get("gift_petals") == tiers["gift"]["petals"] == 5,
        f"dupe/gift petals mismatch: gacha={gacha}",
    )

    # Per-skin validation
    seen_ids: set[str] = set()
    id_errors: list[str] = []
    skin_pricing_errors: list[str] = []
    forbidden_hits: list[str] = []
    for s in skins:
        sid = s.get("id", "")
        if sid in seen_ids or not SKIN_ID_RE.match(sid):
            id_errors.append(f"invalid/dup id={sid!r}")
        seen_ids.add(sid)
        hero = s.get("hero")
        tier = s.get("tier")
        if hero not in heroes or not sid.startswith(f"{hero}_"):
            id_errors.append(f"hero mismatch on {sid}: hero={hero}")
        if s.get("hud") != TIER_HUD.get(tier):
            id_errors.append(f"hud mismatch on {sid}: hud={s.get('hud')} tier={tier}")
        theme = s.get("theme")
        if s.get("hud") == 0 and theme is not None:
            id_errors.append(f"L0 skin {sid} must have theme=null, got {theme}")
        if s.get("hud", 0) > 0 and theme not in VALID_THEMES:
            id_errors.append(f"invalid theme on {sid}: {theme}")
        if theme == "GILT" and tier != "ssrp":
            id_errors.append(f"GILT theme only allowed on ssrp: {sid}")
        name_ru = s.get("name_ru", "")
        if not name_ru or len(name_ru) > 24:
            id_errors.append(f"name_ru length invalid on {sid}: {name_ru!r}")
        for fw in forbidden:
            if fw in sid.lower() or fw in name_ru.lower():
                forbidden_hits.append(f"skin {sid} ({name_ru}) matches {fw!r}")

        # Check pricing & stars on each skin against tier table
        tdef = tiers[tier]
        src = s.get("sources", {})
        if src.get("rub") != tdef["rub"] or src.get("petals") != tdef["petals"]:
            skin_pricing_errors.append(f"{sid}: rub/petals {src.get('rub')}/{src.get('petals')} != {tdef['rub']}/{tdef['petals']}")
        if src.get("dupe_petals_after_star5") != tdef["dupe_petals_after_star5"]:
            skin_pricing_errors.append(f"{sid}: dupe petals mismatch")
        if s.get("stars") != tdef["stars"]:
            skin_pricing_errors.append(f"{sid}: stars mismatch")
        if s.get("catalog_source") == "main":
            expected_day = 57 if src.get("headline_day57") else tdef["direct_from_day"]
            expected_after = 56 if src.get("headline_day57") else tdef["direct_after_days"]
            if src.get("direct_from_day") != expected_day or src.get("direct_after_days") != expected_after:
                skin_pricing_errors.append(f"{sid}: window {src.get('direct_from_day')}/{src.get('direct_after_days')} != {expected_day}/{expected_after}")
        if s.get("ult", {}).get("id") != sid:
            id_errors.append(f"{sid}: ult.id != skin_id")

    rep.check("JSON-SKIN-IDS-RULES", not id_errors, "; ".join(id_errors[:5]))
    rep.check("JSON-SKIN-PRICING", not skin_pricing_errors, "; ".join(skin_pricing_errors[:5]))

    # Shop SL-NUM & SL-TXT checks
    sl_num_errors: list[str] = []
    first_buy_bonus = 0
    rules = shop_doc.get("rules", {})
    for p in shop_doc.get("moon_packs", []):
        sku = p["sku_id"]
        if p["moon"] % rules["moon_pack_multiple"] != 0:
            sl_num_errors.append(f"{sku}: moon {p['moon']} not multiple of 150")
        if p["wishes"] != p["moon"] // rules["wish_cost_gems"]:
            sl_num_errors.append(f"{sku}: wishes mismatch")
        calc_rpw = round(p["rub"] / p["wishes"], 1)
        if abs(calc_rpw - p["rub_per_wish"]) > 0.05:
            sl_num_errors.append(f"{sku}: rub_per_wish {p['rub_per_wish']} != {calc_rpw}")
        if not (rules["rub_per_wish_min"] <= p["rub_per_wish"] <= rules["rub_per_wish_max"]):
            sl_num_errors.append(f"{sku}: rub_per_wish {p['rub_per_wish']} out of [37.0, 39.8]")
        if p["first_buy_x2"]:
            if p["first_buy_moon"] != p["moon"] * 2 or p["first_buy_wishes"] != p["wishes"] * 2:
                sl_num_errors.append(f"{sku}: first_buy_x2 math mismatch")
            first_buy_bonus += p["moon"]
        if p["second_confirm"] != (p["rub"] >= rules["second_confirm_min_rub"]):
            sl_num_errors.append(f"{sku}: second_confirm flag wrong")
    if first_buy_bonus != rules["first_buy_bonus_max_moon"]:
        sl_num_errors.append(f"first_buy_bonus_max_moon {first_buy_bonus} != {rules['first_buy_bonus_max_moon']}")

    for c in shop_doc.get("monthly_cards", []):
        if c["auto_renew"] is not False:
            sl_num_errors.append(f"{c['sku_id']}: auto_renew must be false")
        if c["instant_moon"] + c["daily_gems"] * c["duration_days"] != c["total_gems"]:
            sl_num_errors.append(f"{c['sku_id']}: total_gems mismatch")
        if c["total_gems"] // rules["wish_cost_gems"] != c["wishes"]:
            sl_num_errors.append(f"{c['sku_id']}: wishes mismatch")
        for fw in forbidden:
            if fw in c["name_ru"].lower() or fw in c["sku_id"].lower():
                forbidden_hits.append(f"card {c['sku_id']} matches {fw!r}")

    sp = shop_doc.get("season_pass", {})
    if sp["premium"]["rub"] + sp["lux"]["upgrade_from_premium_rub"] != sp["lux"]["rub"]:
        sl_num_errors.append("season_pass: prem + upgrade != lux")
    if sp.get("buy_levels_allowed") is not False:
        sl_num_errors.append("season_pass: buy_levels_allowed must be false")
    for tier_key in ("premium", "lux"):
        sp_tier = sp.get(tier_key, {})
        sp_name = sp_tier.get("name_ru", "")
        sp_sku = sp_tier.get("sku_pattern", "")
        for fw in forbidden:
            if fw in sp_name.lower() or fw in sp_sku.lower():
                forbidden_hits.append(f"season_pass.{tier_key} ({sp_name}) matches {fw!r}")

    for fund in shop_doc.get("funds", []):
        for fw in forbidden:
            if fw in fund.get("name_ru", "").lower() or fw in fund.get("sku_id", "").lower():
                forbidden_hits.append(f"fund {fund.get('sku_id')} ({fund.get('name_ru')}) matches {fw!r}")

    for p in shop_doc.get("moon_packs", []):
        for fw in forbidden:
            if fw in p.get("sku_id", "").lower():
                forbidden_hits.append(f"moon_pack {p.get('sku_id')} matches {fw!r}")

    for b in shop_doc.get("bundles", []):
        calc_ratio = round(b["list_value_rub"] / b["rub"], 2)
        if abs(calc_ratio - b["value_ratio"]) > 0.015:
            sl_num_errors.append(f"{b['sku_id']}: ratio {b['value_ratio']} != {calc_ratio}")
        if not b["is_event_pass"] and b["value_ratio"] > rules["max_bundle_value_ratio"] + 1e-6:
            sl_num_errors.append(f"{b['sku_id']}: ratio {b['value_ratio']} > {rules['max_bundle_value_ratio']}")
        for fw in forbidden:
            if fw in b["name_ru"].lower() or fw in b["sku_id"].lower():
                forbidden_hits.append(f"bundle {b['sku_id']} matches {fw!r}")

    for cos in shop_doc.get("cosmetics", []):
        label = cos.get("sku_id") or cos.get("sku_pattern", "")
        for fw in forbidden:
            if fw in cos["name_ru"].lower() or fw in label.lower():
                forbidden_hits.append(f"cosmetic {label} matches {fw!r}")

    rep.check("SHOP-SL-NUM", not sl_num_errors, "; ".join(sl_num_errors[:5]))
    rep.check("SHOP-SL-TXT", not forbidden_hits, "; ".join(forbidden_hits[:5]))

    # Cross-check ult_catalogue.json <-> data/skins.json (W17: ult_id == skin_id)
    ults = ult_doc.get("ults", [])
    ult_by_id = {u["id"]: u for u in ults}
    main_by_id = {s["id"]: s for s in main_skins}
    rep.check(
        "ULT-JSON-ID-SET",
        set(ult_by_id.keys()) == set(main_by_id.keys()) and len(ults) == 58,
        f"ult_catalogue ids ({len(ults)}) != main skins ({len(main_by_id)}); "
        f"only_ult={sorted(set(ult_by_id) - set(main_by_id))}, "
        f"only_skin={sorted(set(main_by_id) - set(ult_by_id))}",
    )
    ult_diffs: list[str] = []
    for sid, s in main_by_id.items():
        u = ult_by_id.get(sid)
        if not u:
            continue
        if u["hero"] != s["hero"]:
            ult_diffs.append(f"{sid}: hero {u['hero']} != {s['hero']}")
        if UC_TIER_TO_CODE.get(u["tier"]) != s["tier"]:
            ult_diffs.append(f"{sid}: tier {u['tier']} != {s['tier']}")
        if u["season"] != s["season"]:
            ult_diffs.append(f"{sid}: season {u['season']} != {s['season']}")
        if u["theme"] != s["theme"]:
            ult_diffs.append(f"{sid}: theme {u['theme']} != {s['theme']}")
        if u["ult_key"] != s["ult"]["ult_key"]:
            ult_diffs.append(f"{sid}: ult_key {u['ult_key']} != {s['ult']['ult_key']}")
    rep.check("ULT-JSON-FIELDS", not ult_diffs, "; ".join(ult_diffs[:5]))


# ---------------------------------------------------------------------------
# 2. MONETIZATION_PLAN.md <-> JSON
# ---------------------------------------------------------------------------

def lint_monetization_plan(
    mp_text: str,
    skins_doc: dict[str, Any],
    shop_doc: dict[str, Any],
    rep: LintReport,
) -> None:
    # Red line 6: Layer A ult threshold 8 / charge 0, Layer B energy 0-100
    ur = skins_doc["ult_rules"]
    rl_sec = extract_section(mp_text, r"## Красные линии")
    rep.check(
        "MP-ULT-THRESHOLDS",
        f"порог ульты {ur['layer_a_threshold_pairs']}, заряд {ur['layer_a_initial_charge']}" in rl_sec
        and f"энергия 0–{ur['layer_b_energy_max']}" in rl_sec,
        "MP Red Line 6 ult thresholds do not match skins.json ult_rules",
    )

    # §3.2 banner odds & pity table <-> shop.json gacha + rules
    gacha = shop_doc["gacha"]
    rules = shop_doc["rules"]
    s31 = extract_section(mp_text, r"### 3\.1 ")
    s32 = extract_section(mp_text, r"### 3\.2 ")
    s33 = extract_section(mp_text, r"### 3\.3 ")
    t32 = parse_md_table(s32, 0)
    md32 = {strip_md(r[0]): r for r in t32[1:]}
    g_errs: list[str] = []
    if not md32:
        g_errs.append("missing §3.2 banner table")
    else:
        bf = md32.get("b_first")
        if not bf:
            g_errs.append("missing b_first row")
        else:
            if round(parse_float(bf[5]) * 100) != gacha.get("ssr_base_rate_bp"):
                g_errs.append(f"b_first base_rate {bf[5]} != {gacha.get('ssr_base_rate_bp')} bp")
            if parse_int(bf[6]) != gacha.get("first_guest_hard_pity"):
                g_errs.append(f"b_first hard_pity {bf[6]} != {gacha.get('first_guest_hard_pity')}")
            if rules.get("wish_cost_gems") not in parse_all_ints(bf[9]):
                g_errs.append(f"b_first wish_cost {bf[9]} missing {rules.get('wish_cost_gems')}")

        for bid in ("b_std", "b_moon_a", "b_moon_b", "b_ward", "b_rot"):
            r = md32.get(bid)
            if not r:
                g_errs.append(f"missing {bid} row")
                continue
            if round(parse_float(r[5]) * 100) != gacha.get("ssr_base_rate_bp"):
                g_errs.append(f"{bid} base_rate {r[5]} != {gacha.get('ssr_base_rate_bp')} bp")
            want_pity = [gacha.get("soft_pity"), (gacha.get("soft_pity_step_bp") or 0) // 100, gacha.get("hard_pity")]
            got_pity = parse_all_ints(r[6])
            if got_pity != want_pity:
                g_errs.append(f"{bid} pity {got_pity} != {want_pity}")
            if bid != "b_std" and parse_int(r[8]) != gacha.get("candle_pity"):
                g_errs.append(f"{bid} candle_pity {r[8]} != {gacha.get('candle_pity')}")
            if parse_int(r[9]) != rules.get("wish_cost_gems"):
                g_errs.append(f"{bid} wish_cost {r[9]} != {rules.get('wish_cost_gems')}")

        bp = md32.get("b_props")
        if not bp:
            g_errs.append("missing b_props row")
        else:
            if round(parse_float(bp[5]) * 100) != gacha.get("props_base_rate_bp"):
                g_errs.append(f"b_props base_rate {bp[5]} != {gacha.get('props_base_rate_bp')} bp")
            want_ppity = [gacha.get("props_soft_pity"), (gacha.get("props_soft_pity_step_bp") or 0) // 100, gacha.get("props_hard_pity")]
            got_ppity = parse_all_ints(bp[6])
            if got_ppity != want_ppity:
                g_errs.append(f"b_props pity {got_ppity} != {want_ppity}")
            if parse_int(bp[9]) != rules.get("props_wish_cost_gems"):
                g_errs.append(f"b_props wish_cost {bp[9]} != {rules.get('props_wish_cost_gems')}")

        if f"+ {gacha.get('gift_petals')} лепестков" not in s33:
            g_errs.append(f"§3.3 gift_petals missing '+ {gacha.get('gift_petals')} лепестков'")
    rep.check("MP-3.2-GACHA-ODDS", not g_errs, "; ".join(g_errs[:6]))

    # §3.5 dupe petals after star 5
    s35 = extract_section(mp_text, r"### 3\.5 ")
    dupes = shop_doc["gacha"]["dupe_petals_after_star5"]
    rep.check(
        "MP-3.5-DUPES",
        bool(re.search(
            rf"S\s+{dupes['s']}\s*/\s*SSR\s+{dupes['ssr']}\s*/\s*\*?\*?SSR\+\s+{dupes['ssrp']}\*?\*?",
            s35,
        )),
        f"MP §3.5 dupe petals do not match {dupes}",
    )

    # Cross-check shop.json rules <-> MONETIZATION_PLAN.md (§1.3, §3.1, §3.5, §4.1, §4.3, §4.7, Red Line 6)
    s13 = extract_section(mp_text, r"### 1\.3 ")
    s41_txt = extract_section(mp_text, r"### 4\.1 ")
    s43_txt = extract_section(mp_text, r"### 4\.3 ")
    s47_txt = extract_section(mp_text, r"### 4\.7 ")
    r_errs: list[str] = []
    if f"**{rules['wish_cost_gems']} кр**" not in s31:
        r_errs.append(f"§3.1 missing wish_cost_gems={rules['wish_cost_gems']}")
    if f"({rules['props_wish_cost_gems']} кр" not in s31:
        r_errs.append(f"§3.1 missing props_wish_cost_gems={rules['props_wish_cost_gems']}")
    t35 = parse_md_table(s35, 0)
    x10_row = next((r for r in t35[1:] if "×10" in r[0]), None)
    if not x10_row or [rules["wish_cost_gems"], 10, rules["wish_10_cost_gems"]] != parse_all_ints(x10_row[1])[:3]:
        r_errs.append(f"§3.5 x10 cost mismatch for wish_10_cost_gems={rules['wish_10_cost_gems']}")
    if rules["moon_pack_multiple"] != rules["wish_cost_gems"]:
        r_errs.append(f"moon_pack_multiple {rules['moon_pack_multiple']} != wish_cost_gems {rules['wish_cost_gems']}")
    rpw_span = f"{_fmt_ru_dec(rules['rub_per_wish_min'])}–{_fmt_ru_dec(rules['rub_per_wish_max'])}"
    if rpw_span not in s13 or rpw_span not in s47_txt:
        r_errs.append(f"rub_per_wish range {rpw_span} missing in §1.3 / §4.7")
    if f"≤{_fmt_ru_dec(rules['max_bundle_value_ratio'])}" not in s47_txt:
        r_errs.append(f"§4.7 missing max_bundle_value_ratio ≤{_fmt_ru_dec(rules['max_bundle_value_ratio'])}")
    if f"Потолок ratio для дорожек — **{_fmt_ru_dec(rules['max_pass_value_ratio'])}**" not in s43_txt:
        r_errs.append(f"§4.3 missing max_pass_value_ratio {_fmt_ru_dec(rules['max_pass_value_ratio'])}")
    if f"≥{_fmt_ru_int(rules['second_confirm_min_rub'])} ₽" not in s41_txt:
        r_errs.append(f"§4.1 missing second_confirm_min_rub ≥{_fmt_ru_int(rules['second_confirm_min_rub'])}")
    if f"{_fmt_ru_int(rules['first_buy_bonus_max_moon'])} камня" not in s41_txt:
        r_errs.append(f"§4.1 missing first_buy_bonus_max_moon {_fmt_ru_int(rules['first_buy_bonus_max_moon'])}")
    if f"outfit_stats_enabled={str(rules['outfit_stats_enabled_default']).lower()}" not in rl_sec:
        r_errs.append("Red Line 6 outfit_stats_enabled_default mismatch")
    if f"bond_stats_enabled={str(rules['bond_stats_enabled_default']).lower()}" not in rl_sec:
        r_errs.append("Red Line 6 bond_stats_enabled_default mismatch")
    rep.check("MP-RULES-SYNC", not r_errs, "; ".join(r_errs[:6]))

    # §3.6 direct sale windows & prices
    s36 = extract_section(mp_text, r"### 3\.6 ")
    t36 = parse_md_table(s36, 0)
    op = shop_doc["outfit_pricing"]
    rows36 = {strip_md(r[0]): r for r in t36[1:]}
    s36_errs: list[str] = []
    for label, key in [("S", "s"), ("SSR (в т.ч. гостевой)", "ssr"), ("SSR+", "ssrp")]:
        row = rows36.get(label)
        if not row:
            s36_errs.append(f"missing row {label}")
            continue
        day = parse_int(row[2])
        prices = parse_all_ints(row[3])
        if day != op[key]["direct_from_day"]:
            s36_errs.append(f"{label}: day {day} != {op[key]['direct_from_day']}")
        if op[key]["rub"] not in prices:
            s36_errs.append(f"{label}: price {op[key]['rub']} not in {prices}")
        if key == "s" and op["s_static"]["rub"] not in prices:
            s36_errs.append(f"{label}: static price {op['s_static']['rub']} not in {prices}")
    rep.check("MP-3.6-WINDOWS", not s36_errs, "; ".join(s36_errs))

    # §4.1 moon packs table
    s41 = extract_section(mp_text, r"### 4\.1 ")
    t41 = parse_md_table(s41, 0)
    md_packs = {strip_md(r[0]): r for r in t41[1:]}
    p_errs: list[str] = []
    expected_packs = {p["sku_id"]: p for p in shop_doc["moon_packs"]}
    if set(md_packs.keys()) != set(expected_packs.keys()):
        p_errs.append(f"SKU set mismatch: md={sorted(md_packs)} json={sorted(expected_packs)}")
    for sku, p in expected_packs.items():
        r = md_packs.get(sku)
        if not r:
            continue
        if parse_int(r[1]) != p["rub"]:
            p_errs.append(f"{sku}: rub {r[1]} != {p['rub']}")
        if parse_int(r[2]) != p["moon"]:
            p_errs.append(f"{sku}: moon {r[2]} != {p['moon']}")
        if parse_int(r[3]) != p["wishes"]:
            p_errs.append(f"{sku}: wishes {r[3]} != {p['wishes']}")
        if abs(parse_float(r[4]) - p["rub_per_wish"]) > 0.05:
            p_errs.append(f"{sku}: rpw {r[4]} != {p['rub_per_wish']}")
        if p["first_buy_x2"]:
            nums = parse_all_ints(r[5])
            if p["first_buy_moon"] not in nums or p["first_buy_wishes"] not in nums:
                p_errs.append(f"{sku}: first_buy_x2 {r[5]} != {p['first_buy_moon']}/{p['first_buy_wishes']}")
        else:
            if "—" not in r[5]:
                p_errs.append(f"{sku}: expected '—' for non-x2 pack, got {r[5]}")
    rep.check("MP-4.1-MOON-PACKS", not p_errs, "; ".join(p_errs[:5]))

    # §4.2 monthly cards
    s42 = extract_section(mp_text, r"### 4\.2 ")
    t42 = parse_md_table(s42, 0)
    md_cards = {strip_md(r[0]): r for r in t42[1:]}
    c_errs: list[str] = []
    for c in shop_doc["monthly_cards"]:
        r = md_cards.get(c["sku_id"])
        if not r:
            c_errs.append(f"missing {c['sku_id']}")
            continue
        if parse_int(r[2]) != c["rub"]:
            c_errs.append(f"{c['sku_id']}: rub {r[2]} != {c['rub']}")
        comp_nums = parse_all_ints(r[3])
        for need in (c["instant_moon"], c["daily_gems"], c["duration_days"], c["total_gems"]):
            if need not in comp_nums:
                c_errs.append(f"{c['sku_id']}: {need} missing in {r[3]}")
        if parse_int(r[4]) != c["wishes"]:
            c_errs.append(f"{c['sku_id']}: wishes {r[4]} != {c['wishes']}")
        if abs(parse_float(r[5]) - c["rub_per_wish"]) > 0.05:
            c_errs.append(f"{c['sku_id']}: rpw {r[5]} != {c['rub_per_wish']}")
    rep.check("MP-4.2-CARDS", not c_errs, "; ".join(c_errs[:5]))

    # §4.3 season pass
    s43 = extract_section(mp_text, r"### 4\.3 ")
    t43 = parse_md_table(s43, 0)
    sp = shop_doc["season_pass"]
    sp_errs: list[str] = []
    if not t43:
        sp_errs.append("missing §4.3 table")
    else:
        hdr = t43[0]
        free_nums = parse_all_ints(hdr[1])
        for need in (sp["free"]["gems"], sp["free"]["tickets"], sp["free"]["coins"], sp["free"]["petals"]):
            if need not in free_nums:
                sp_errs.append(f"free header missing {need}: {hdr[1]}")
        if parse_int(hdr[2]) != sp["premium"]["rub"]:
            sp_errs.append(f"prem header {hdr[2]} != {sp['premium']['rub']}")
        lux_nums = parse_all_ints(hdr[3])
        if sp["lux"]["upgrade_from_premium_rub"] not in lux_nums or sp["lux"]["rub"] not in lux_nums:
            sp_errs.append(f"lux header {hdr[3]} missing {sp['lux']['upgrade_from_premium_rub']}/{sp['lux']['rub']}")
        lvl30 = next((r for r in t43[1:] if parse_int(r[0]) == sp["premium"]["pass_s_skin_level"]), None)
        if not lvl30 or "_s_pass" not in lvl30[2]:
            sp_errs.append("level 30 premium row missing _s_pass")
    rep.check("MP-4.3-PASS", not sp_errs, "; ".join(sp_errs[:5]))

    # §4.4 funds
    s44 = extract_section(mp_text, r"### 4\.4 ")
    t44 = parse_md_table(s44, 0)
    md_funds = {strip_md(r[0]): r for r in t44[1:]}
    f_errs: list[str] = []
    for f in shop_doc["funds"]:
        r = md_funds.get(f["sku_id"])
        if not r:
            f_errs.append(f"missing {f['sku_id']}")
            continue
        if parse_int(r[2]) != f["rub"]:
            f_errs.append(f"{f['sku_id']}: rub {r[2]} != {f['rub']}")
        nums = parse_all_ints(r[3])
        if f["total_gems"] not in nums or f["wishes"] not in nums:
            f_errs.append(f"{f['sku_id']}: gems/wishes missing in {r[3]}")
        if abs(parse_float(r[4]) - f["value_ratio"]) > 0.02:
            f_errs.append(f"{f['sku_id']}: ratio {r[4]} != {f['value_ratio']}")
    rep.check("MP-4.4-FUNDS", not f_errs, "; ".join(f_errs[:5]))

    # §4.5 outfit pricing ladder (prices, petals, windows, stars, dye_3)
    s45 = extract_section(mp_text, r"### 4\.5 ")
    t45 = parse_md_table(s45, 0)
    md_45 = {strip_md(r[0]): r for r in t45[1:]}
    o_errs: list[str] = []
    map_45 = [
        ("S «Статика»", "s_static"),
        ("S", "s"),
        ("SSR", "ssr"),
        ("SSR+", "ssrp"),
    ]
    for label, key in map_45:
        r = md_45.get(label)
        if not r:
            o_errs.append(f"missing row {label}")
            continue
        spec = op[key]
        if parse_int(r[1]) != spec["rub"]:
            o_errs.append(f"{label}: rub {r[1]} != {spec['rub']}")
        if parse_int(r[2]) != spec["petals"]:
            o_errs.append(f"{label}: petals {r[2]} != {spec['petals']}")
        if parse_int(r[3]) != spec["direct_from_day"]:
            o_errs.append(f"{label}: day {r[3]} != {spec['direct_from_day']}")
        star_rub_nums = parse_all_ints(r[4])
        expected_star_rub = list(spec["stars_rub"]) + [spec["stars_rub_total"]]
        if star_rub_nums != expected_star_rub:
            o_errs.append(f"{label}: stars_rub {star_rub_nums} != {expected_star_rub}")
        star_pet_nums = parse_all_ints(r[5])
        if star_pet_nums != spec["stars_petals"]:
            o_errs.append(f"{label}: stars_petals {star_pet_nums} != {spec['stars_petals']}")
        if spec["dye_3_rub"] is not None:
            dye_nums = parse_all_ints(r[6])
            if dye_nums != [spec["dye_3_rub"], spec["dye_3_petals"]]:
                o_errs.append(f"{label}: dye_3 {dye_nums} != {[spec['dye_3_rub'], spec['dye_3_petals']]}")
    rep.check("MP-4.5-OUTFIT-LADDER", not o_errs, "; ".join(o_errs[:6]))

    # §4.6 cosmetics
    s46 = extract_section(mp_text, r"### 4\.6 ")
    t46 = parse_md_table(s46, 0)
    md_46 = {strip_md(r[0]): r for r in t46[1:]}
    cos_errs: list[str] = []
    for cos in shop_doc["cosmetics"]:
        key = cos.get("sku_id") or cos.get("sku_pattern")
        if key in ("tw_table_cloth", "tw_table_tiles", "tw_table_fx"):
            continue
        r = md_46.get(key)
        if not r:
            cos_errs.append(f"missing {key}")
            continue
        if "rub" in cos and parse_int(r[2]) != cos["rub"]:
            cos_errs.append(f"{key}: rub {r[2]} != {cos['rub']}")
        if "rub_min" in cos and parse_all_ints(r[2]) != [cos["rub_min"], cos["rub_max"]]:
            cos_errs.append(f"{key}: rub range {r[2]} != {cos['rub_min']}-{cos['rub_max']}")
        if "rub_tiers" in cos and parse_all_ints(r[2]) != cos["rub_tiers"]:
            cos_errs.append(f"{key}: rub tiers {r[2]} != {cos['rub_tiers']}")
        if cos.get("petals") is not None and parse_int(r[3]) != cos["petals"]:
            cos_errs.append(f"{key}: petals {r[3]} != {cos['petals']}")
        if "petals_min" in cos and parse_all_ints(r[3]) != [cos["petals_min"], cos["petals_max"]]:
            cos_errs.append(f"{key}: petals range {r[3]} != {cos['petals_min']}-{cos['petals_max']}")
    # Check grouped table_cloth/tiles/fx row
    tbl_row = md_46.get("tw_table_cloth/tiles/fx")
    if not tbl_row:
        cos_errs.append("missing tw_table_cloth/tiles/fx")
    else:
        by_id = {c.get("sku_id"): c for c in shop_doc["cosmetics"] if c.get("sku_id")}
        exp_rub = [by_id["tw_table_cloth"]["rub"], by_id["tw_table_tiles"]["rub"], by_id["tw_table_fx"]["rub"]]
        exp_pet = [by_id["tw_table_cloth"]["petals"], by_id["tw_table_tiles"]["petals"], by_id["tw_table_fx"]["petals"]]
        if parse_all_ints(tbl_row[2]) != exp_rub or parse_all_ints(tbl_row[3]) != exp_pet:
            cos_errs.append(f"tw_table_cloth/tiles/fx mismatch: {tbl_row[2]} / {tbl_row[3]}")
    rep.check("MP-4.6-COSMETICS", not cos_errs, "; ".join(cos_errs[:5]))

    # §4.7 bundles
    s47 = extract_section(mp_text, r"### 4\.7 ")
    t47 = parse_md_table(s47, 0)
    md_47 = {strip_md(r[0]): r for r in t47[1:]}
    b_errs: list[str] = []
    b_by_id = {b["sku_id"]: b for b in shop_doc["bundles"]}
    for sku in ("tw_bundle_season", "tw_bundle_hero", "tw_bundle_prop"):
        r = md_47.get(sku)
        b = b_by_id[sku]
        if not r:
            b_errs.append(f"missing {sku}")
            continue
        if parse_int(r[2]) != b["rub"]:
            b_errs.append(f"{sku}: rub {r[2]} != {b['rub']}")
        if parse_int(r[4]) != b["list_value_rub"]:
            b_errs.append(f"{sku}: list {r[4]} != {b['list_value_rub']}")
        if abs(parse_float(r[5]) - b["value_ratio"]) > 0.02:
            b_errs.append(f"{sku}: ratio {r[5]} != {b['value_ratio']}")
    ev_row = md_47.get("tw_event_pass_mini/mega")
    if not ev_row:
        b_errs.append("missing tw_event_pass_mini/mega")
    else:
        mini, mega = b_by_id["tw_event_pass_mini"], b_by_id["tw_event_pass_mega"]
        if parse_all_ints(ev_row[2]) != [mini["rub"], mega["rub"]]:
            b_errs.append(f"event pass rub {ev_row[2]} != {[mini['rub'], mega['rub']]}")
        if parse_all_ints(ev_row[4]) != [mini["list_value_rub"], mega["list_value_rub"]]:
            b_errs.append(f"event pass list {ev_row[4]} != {[mini['list_value_rub'], mega['list_value_rub']]}")
        ev_ratios = parse_all_floats(ev_row[5])
        if len(ev_ratios) != 2 or abs(ev_ratios[0] - mini["value_ratio"]) > 0.02 or abs(ev_ratios[1] - mega["value_ratio"]) > 0.02:
            b_errs.append(f"event pass ratio {ev_row[5]} != {[mini['value_ratio'], mega['value_ratio']]}")
    rep.check("MP-4.7-BUNDLES", not b_errs, "; ".join(b_errs[:5]))

    # Appendix R W17 consistency line
    app_r = extract_section(mp_text, r"## Приложение R\.", r"\n## ")
    rep.check(
        "MP-APP-R-W17",
        "3 600" in app_r and "300" in app_r
        and f"слой A {ur['layer_a_threshold_pairs']}" in app_r
        and f"энергия {ur['layer_b_energy_max']}" in app_r
        and "S сезона — 4" in app_r,
        "MP Appendix R W17 line diverged from JSON rules",
    )


# ---------------------------------------------------------------------------
# 3. SKIN_HUD_SYSTEM.md <-> JSON
# ---------------------------------------------------------------------------

def lint_skin_hud_system(
    sh_text: str,
    skins_doc: dict[str, Any],
    shop_doc: dict[str, Any],
    rep: LintReport,
) -> None:
    tiers = skins_doc["tiers"]
    ur = skins_doc["ult_rules"]
    op = shop_doc["outfit_pricing"]

    # §0.2 & §1.5 ult threshold 8, initial charge 0
    s02 = extract_section(sh_text, r"### 0\.2 ")
    s15 = extract_section(sh_text, r"### 1\.5 ")
    rep.check(
        "SH-ULT-THRESHOLD",
        f"порог ульты {ur['layer_a_threshold_pairs']}, заряд {ur['layer_a_initial_charge']}" in s02
        and f"порог ульты ({ur['layer_a_threshold_pairs']} пар)" in s15,
        "SH §0.2 / §1.5 ult threshold mismatch",
    )

    # §1.1 tiers table
    s11 = extract_section(sh_text, r"### 1\.1 ")
    t11 = parse_md_table(s11, 0)
    md11 = {strip_md(r[1]): r for r in t11[1:]}
    e11: list[str] = []
    for code, need_nums in [
        ("s", [tiers["s"]["rub"], tiers["s_static"]["rub"], tiers["s"]["petals"]]),
        ("ssr", [tiers["ssr"]["rub"], tiers["ssr"]["petals"]]),
        ("ssrp", [tiers["ssrp"]["rub"], tiers["ssrp"]["petals"]]),
    ]:
        r = md11.get(code)
        if not r:
            e11.append(f"missing tier {code}")
            continue
        nums = parse_all_ints(r[3])
        for n in need_nums:
            if n not in nums:
                e11.append(f"tier {code}: {n} not in {r[3]}")
    rep.check("SH-1.1-TIERS", not e11, "; ".join(e11[:5]))

    # §1.4 tier matrix (prices & voice mins)
    s14 = extract_section(sh_text, r"### 1\.4 ")
    t14 = parse_md_table(s14, 0)
    rows14 = {strip_md(r[0]): r for r in t14[1:]}
    e14: list[str] = []
    price_row = rows14.get("Цена прямой покупки")
    if not price_row:
        e14.append("missing price row in §1.4")
    else:
        if parse_all_ints(price_row[2]) != [tiers["s"]["rub"], tiers["s_static"]["rub"]]:
            e14.append(f"S price {price_row[2]}")
        if parse_int(price_row[3]) != tiers["ssr"]["rub"]:
            e14.append(f"SSR price {price_row[3]}")
        if parse_int(price_row[4]) != tiers["ssrp"]["rub"]:
            e14.append(f"SSR+ price {price_row[4]}")
    voice_row = rows14.get("Голос (строк наряда)")
    if not voice_row:
        e14.append("missing voice row in §1.4")
    else:
        if parse_int(voice_row[2]) != tiers["s"]["voice_min"]:
            e14.append(f"S voice {voice_row[2]}")
        if parse_int(voice_row[3]) != tiers["ssr"]["voice_min"]:
            e14.append(f"SSR voice {voice_row[3]}")
        if parse_int(voice_row[4]) != tiers["ssrp"]["voice_min"]:
            e14.append(f"SSR+ voice {voice_row[4]}")
    rep.check("SH-1.4-MATRIX", not e14, "; ".join(e14[:5]))

    # §6.2 58-skin catalog table & hero x tier matrix
    s62 = extract_section(sh_text, r"### 6\.2 ")
    t62_cat = parse_md_table(s62, 0)
    t62_mat = parse_md_table(s62, 1)

    short_to_hero = {v["short_ru"]: k for k, v in skins_doc["heroes"].items()}
    main_by_id = {s["id"]: s for s in skins_doc["skins"] if s["catalog_source"] == "main"}

    e62: list[str] = []
    md_ids: list[str] = []
    for r in t62_cat[1:]:
        sid = strip_md(r[1])
        md_ids.append(sid)
        s = main_by_id.get(sid)
        if not s:
            e62.append(f"MD skin {sid} missing in skins.json")
            continue
        hero = short_to_hero.get(strip_md(r[2]))
        tier = SH_TIER_TO_CODE.get(strip_md(r[3]))
        theme_raw = strip_md(r[4])
        theme = None if theme_raw == "—" else theme_raw
        season = strip_md(r[5])
        hud = HUD_STR_TO_INT.get(strip_md(r[6]))
        name_ru = strip_md(r[7])
        if hero != s["hero"]:
            e62.append(f"{sid}: hero {hero} != {s['hero']}")
        if tier != s["tier"]:
            e62.append(f"{sid}: tier {tier} != {s['tier']}")
        if theme != s["theme"]:
            e62.append(f"{sid}: theme {theme} != {s['theme']}")
        if season != s["season"]:
            e62.append(f"{sid}: season {season} != {s['season']}")
        if hud != s["hud"]:
            e62.append(f"{sid}: hud {hud} != {s['hud']}")
        if name_ru != s["name_ru"]:
            e62.append(f"{sid}: name_ru {name_ru!r} != {s['name_ru']!r}")
    if set(md_ids) != set(main_by_id.keys()):
        e62.append(f"catalog set mismatch: md={len(md_ids)} json={len(main_by_id)}")
    rep.check("SH-6.2-CATALOG", not e62, "; ".join(e62[:5]))

    # Hero x tier matrix check
    e62m: list[str] = []
    for r in t62_mat[1:]:
        label = strip_md(r[0])
        nums = [parse_int(c) for c in r[1:8]]
        if label == "Итого":
            actual = [
                sum(1 for s in main_by_id.values() if s["tier"] == "base"),
                sum(1 for s in main_by_id.values() if s["tier"] == "vow"),
                sum(1 for s in main_by_id.values() if s["tier"] == "s"),
                sum(1 for s in main_by_id.values() if s["tier"] == "ssr"),
                sum(1 for s in main_by_id.values() if s["tier"] == "ssrp"),
                len(main_by_id),
                sum(1 for s in main_by_id.values() if s["season"] == "S1"),
            ]
        else:
            hero = short_to_hero.get(label)
            if not hero:
                e62m.append(f"unknown hero {label}")
                continue
            hs = [s for s in main_by_id.values() if s["hero"] == hero]
            actual = [
                sum(1 for s in hs if s["tier"] == "base"),
                sum(1 for s in hs if s["tier"] == "vow"),
                sum(1 for s in hs if s["tier"] == "s"),
                sum(1 for s in hs if s["tier"] == "ssr"),
                sum(1 for s in hs if s["tier"] == "ssrp"),
                len(hs),
                sum(1 for s in hs if s["season"] == "S1"),
            ]
        if nums != actual:
            e62m.append(f"{label}: md={nums} != json={actual}")
    rep.check("SH-6.2-MATRIX", not e62m, "; ".join(e62m[:5]))

    # §6.3 HUD-theme skins (11)
    s63 = extract_section(sh_text, r"### 6\.3 ")
    t63 = parse_md_table(s63, 0)
    themed_json = {s["id"]: s for s in main_by_id.values() if s["theme"] is not None}
    e63: list[str] = []
    md_63_ids: set[str] = set()
    for r in t63[1:]:
        sid = strip_md(r[0])
        md_63_ids.add(sid)
        s = themed_json.get(sid)
        if not s:
            e63.append(f"{sid} missing in themed skins")
            continue
        theme = strip_md(r[2])
        if theme != s["theme"]:
            e63.append(f"{sid}: theme {theme} != {s['theme']}")
        if f"L{s['hud']}" not in r[1]:
            e63.append(f"{sid}: hud L{s['hud']} not in {r[1]}")
    if md_63_ids != set(themed_json.keys()):
        e63.append(f"themed set mismatch: md={len(md_63_ids)} json={len(themed_json)}")
    rep.check("SH-6.3-HUD-THEMES", not e63, "; ".join(e63[:5]))

    # §6.4.1 Acquisition paths (petals, direct prices, windows, dye_3)
    s641 = extract_section(sh_text, r"#### 6\.4\.1 ")
    t641 = parse_md_table(s641, 0)
    md641 = {strip_md(r[0]): r for r in t641[1:]}
    e641: list[str] = []
    for label, key in [("S", "s"), ("SSR", "ssr"), ("SSR+", "ssrp")]:
        r = md641.get(label)
        if not r:
            e641.append(f"missing {label}")
            continue
        spec = op[key]
        pet_nums = parse_all_ints(r[2])
        if spec["petals"] not in pet_nums:
            e641.append(f"{label}: petals {spec['petals']} not in {r[2]}")
        if key == "s" and op["s_static"]["petals"] not in pet_nums:
            e641.append(f"S: static petals {op['s_static']['petals']} not in {r[2]}")
        buy_nums = parse_all_ints(r[3])
        if spec["rub"] not in buy_nums or spec["direct_from_day"] not in buy_nums:
            e641.append(f"{label}: rub/day {spec['rub']}/{spec['direct_from_day']} not in {r[3]}")
        if key == "s" and op["s_static"]["rub"] not in buy_nums:
            e641.append(f"S: static rub {op['s_static']['rub']} not in {r[3]}")
        if key == "s":
            # S stars row lists canonical S/SSR stars
            star_nums = parse_all_ints(r[4])
            for n in list(spec["stars_petals"]) + list(spec["stars_rub"]):
                if n not in star_nums:
                    e641.append(f"S stars missing {n} in {r[4]}")
        if key == "ssr":
            dye_nums = parse_all_ints(r[5])
            if spec["dye_3_rub"] not in dye_nums or spec["dye_3_petals"] not in dye_nums:
                e641.append(f"SSR dye_3 {spec['dye_3_rub']}/{spec['dye_3_petals']} not in {r[5]}")
    rep.check("SH-6.4.1-PATHS", not e641, "; ".join(e641[:5]))

    # §6.5 Season calendar (including W17 S pass note in header)
    s65 = extract_section(sh_text, r"### 6\.5 ")
    t65 = parse_md_table(s65, 0)
    e65: list[str] = []
    if not t65:
        e65.append("missing §6.5 table")
    else:
        hdr = t65[0]
        if "3 по каталогу + 1 S дорожки" not in hdr[3]:
            e65.append(f"§6.5 header missing W17 '3 по каталогу + 1 S дорожки': {hdr[3]}")
        seasons_by_id = {sn["id"]: sn for sn in skins_doc["seasons"]}
        for r in t65[1:]:
            sid_m = re.match(r"(S\d)", strip_md(r[0]))
            if not sid_m:
                continue
            sn = seasons_by_id.get(sid_m.group(1))
            if not sn:
                e65.append(f"unknown season {sid_m.group(1)}")
                continue
            ba = backtick_tokens(r[1])
            if ba != [sn["banner_a_featured"]]:
                e65.append(f"{sn['id']} banner A {ba} != {[sn['banner_a_featured']]}")
            bb = backtick_tokens(r[2])
            if sn["banner_b_featured"] and bb != sn["banner_b_featured"]:
                e65.append(f"{sn['id']} banner B {bb} != {sn['banner_b_featured']}")
            ns = backtick_tokens(r[3])
            if sn["id"] == "S1":
                if ns != sn["first_guest_ssrs"]:
                    e65.append(f"S1 first guest SSRs {ns} != {sn['first_guest_ssrs']}")
            else:
                if ns != sn["catalog_new_s"]:
                    e65.append(f"{sn['id']} new S {ns} != {sn['catalog_new_s']}")
    rep.check("SH-6.5-CALENDAR", not e65, "; ".join(e65[:5]))

    # Appendix R W17
    app_r = extract_section(sh_text, r"## Приложение R\.", r"\n## ")
    rep.check(
        "SH-APP-R-W17",
        "3 по каталогу + 1 S дорожки" in app_r and "3 600 / 300" in app_r,
        "SH Appendix R W17 line diverged from JSON rules",
    )


# ---------------------------------------------------------------------------
# 4. BATTLE_ULT_SPEC.md <-> JSON
# ---------------------------------------------------------------------------

def lint_battle_ult_spec(
    bu_text: str,
    skins_doc: dict[str, Any],
    shop_doc: dict[str, Any],
    rep: LintReport,
) -> None:
    ur = skins_doc["ult_rules"]
    op = shop_doc["outfit_pricing"]
    gacha = shop_doc["gacha"]

    # §0.2 CR-5 & §2.2 ult thresholds
    s02 = extract_section(bu_text, r"### 0\.2 ")
    t02 = parse_md_table(s02, 0)
    cr_rows = {strip_md(r[0]): r for r in t02[1:]}
    cr5 = cr_rows.get("CR-5")
    rep.check(
        "BU-CR5-ULT-THRESHOLDS",
        bool(cr5)
        and f"порог {ur['layer_a_threshold_pairs']} пар, старт {ur['layer_a_initial_charge']}" in cr5[1]
        and f"энергия 0–{ur['layer_b_energy_max']}" in cr5[3]
        and f"старт {ur['layer_b_energy_initial']}" in cr5[3]
        and f"Цена ульты {ur['layer_b_energy_max']}" in bu_text,
        "BU CR-5 / §2.2 ult thresholds diverged from skins.json ult_rules",
    )

    # §0.2 CR-13 ult id == skin_id
    cr13 = cr_rows.get("CR-13")
    pol = skins_doc["season_s_policy"]
    rep.check(
        "BU-CR13-ULT-ID",
        bool(cr13)
        and "Ульта-id = skin_id" in cr13[3]
        and str(pol["catalog_main_count"]) in cr13[1]
        and str(pol["launch_s1_main_count"]) in cr13[1],
        "BU CR-13 ult_id = skin_id / counts diverged from skins.json",
    )

    # §2.6 tier table (prices & SSR+ day 57)
    s26 = extract_section(bu_text, r"### 2\.6 ")
    t26 = parse_md_table(s26, 0)
    e26: list[str] = []
    if len(t26) < 4:
        e26.append("missing §2.6 table")
    else:
        rows26 = {strip_md(r[0]).split()[0]: r for r in t26[1:]}
        for label, key in [("S", "s"), ("SSR", "ssr"), ("SSR+", "ssrp")]:
            r = rows26.get(label)
            if not r:
                e26.append(f"missing row {label}")
                continue
            p_nums = parse_all_ints(r[7])
            if op[key]["rub"] not in p_nums:
                e26.append(f"{label}: rub {op[key]['rub']} not in {r[7]}")
            if key == "s" and op["s_static"]["rub"] not in p_nums:
                e26.append(f"S: static rub {op['s_static']['rub']} not in {r[7]}")
            if key == "ssrp" and op["ssrp"]["direct_from_day"] not in p_nums:
                e26.append(f"SSR+: day {op['ssrp']['direct_from_day']} not in {r[7]}")
            if key == "s":
                star_nums = parse_all_ints(r[8])
                exp_s = list(op["s"]["stars_rub"]) + [op["s"]["stars_rub_total"]]
                if star_nums != exp_s:
                    e26.append(f"S stars {star_nums} != {exp_s}")
    rep.check("BU-2.6-PRICES", not e26, "; ".join(e26[:5]))

    # §2.7 rarity numbers summary (prices + W17 petals unlock/dupe!)
    s27 = extract_section(bu_text, r"### 2\.7 ")
    t27 = parse_md_table(s27, 0)
    rows27 = {strip_md(r[0]): r for r in t27[1:]}
    e27: list[str] = []
    pr = rows27.get("Прямая цена")
    if not pr:
        e27.append("missing 'Прямая цена' row in §2.7")
    else:
        if parse_all_ints(pr[3]) != [op["s"]["rub"], op["s_static"]["rub"]]:
            e27.append(f"S direct price {pr[3]}")
        if parse_int(pr[4]) != op["ssr"]["rub"]:
            e27.append(f"SSR direct price {pr[4]}")
        if parse_int(pr[5]) != op["ssrp"]["rub"]:
            e27.append(f"SSR+ direct price {pr[5]}")
    pet = rows27.get("Лепестки (разблокировка / дубль после ★5)")
    if not pet:
        e27.append("missing petals row in §2.7")
    else:
        exp_s_pet = [op["s"]["petals"], op["s_static"]["petals"], op["s"]["dupe_petals_after_star5"]]
        exp_ssr_pet = [op["ssr"]["petals"], op["ssr"]["dupe_petals_after_star5"]]
        exp_ssrp_pet = [op["ssrp"]["petals"], op["ssrp"]["dupe_petals_after_star5"]]
        if parse_all_ints(pet[3]) != exp_s_pet:
            e27.append(f"S petals {pet[3]} != {exp_s_pet}")
        if parse_all_ints(pet[4]) != exp_ssr_pet:
            e27.append(f"SSR petals {pet[4]} != {exp_ssr_pet}")
        if parse_all_ints(pet[5]) != exp_ssrp_pet:
            e27.append(f"SSR+ petals {pet[5]} != {exp_ssrp_pet}")
        if parse_int(pet[6]) != gacha["gift_petals"]:
            e27.append(f"Gift petals {pet[6]} != {gacha['gift_petals']}")
    rep.check("BU-2.7-PETALS-PRICES", not e27, "; ".join(e27[:6]))

    # Appendix R W17
    app_r = extract_section(bu_text, r"## Приложение R\.", r"\n## ")
    rep.check(
        "BU-APP-R-W17",
        "3 600 / дубль ★5 → 300" in app_r,
        "BU Appendix R W17 SSR+ petals line diverged",
    )


# ---------------------------------------------------------------------------
# 5. ULT_CATALOGUE.md & LIVEOPS_CALENDAR.md <-> JSON
# ---------------------------------------------------------------------------

def lint_ult_catalogue_md(uc_md_text: str, skins_doc: dict[str, Any], rep: LintReport) -> None:
    main_by_id = {s["id"]: s for s in skins_doc["skins"] if s["catalog_source"] == "main"}
    md_entries: dict[str, tuple[str, str]] = {}
    errs: list[str] = []

    for sec_pat in (r"## Релиз 1\.0", r"## Сезоны S2–S3", r"## Сезоны S4–S6"):
        sec = extract_section(uc_md_text, sec_pat, r"\n## ")
        tbl = parse_md_table(sec, 0)
        for r in tbl[1:]:
            uid = strip_md(r[0])
            tier = UC_MD_TIER_TO_CODE.get(strip_md(r[1]))
            season = strip_md(r[2])
            if uid in md_entries:
                errs.append(f"dup uid {uid}")
            md_entries[uid] = (tier or "", season)
            s = main_by_id.get(uid)
            if not s:
                errs.append(f"ult {uid} missing in skins.json")
            else:
                if tier != s["tier"]:
                    errs.append(f"{uid}: tier {tier} != {s['tier']}")
                if season != s["season"]:
                    errs.append(f"{uid}: season {season} != {s['season']}")

    if set(md_entries.keys()) != set(main_by_id.keys()):
        errs.append(f"ULT_CATALOGUE.md count {len(md_entries)} != {len(main_by_id)}")
    rep.check("ULT-MD-SYNC", not errs, "; ".join(errs[:5]))


def lint_liveops_calendar(lc_text: str, skins_doc: dict[str, Any], rep: LintReport) -> None:
    all_by_id = {s["id"]: s for s in skins_doc["skins"]}
    seasons_by_id = {sn["id"]: sn for sn in skins_doc["seasons"]}
    s11 = extract_section(lc_text, r"### 1\.1 ")
    t11 = parse_md_table(s11, 0)
    errs: list[str] = []
    if len(t11) < 7:
        errs.append("missing LIVEOPS_CALENDAR §1.1 6-season table")
    else:
        for r in t11[1:]:
            season_id = strip_md(r[0])
            sn = seasons_by_id.get(season_id)
            if not sn:
                errs.append(f"unknown season {season_id}")
                continue
            ba = backtick_tokens(r[1])
            ba_s = backtick_tokens(r[2])
            bb = backtick_tokens(r[3])
            bb_s = backtick_tokens(r[4])
            mega = backtick_tokens(r[5])
            pass_s = backtick_tokens(r[6])

            if ba != [sn["banner_a_featured"]]:
                errs.append(f"{season_id}: banner_a {ba} != {[sn['banner_a_featured']]}")
            if ba_s != sn["banner_a_s"]:
                errs.append(f"{season_id}: banner_a_s {ba_s} != {sn['banner_a_s']}")
            if sn["banner_b_featured"] and bb != sn["banner_b_featured"]:
                errs.append(f"{season_id}: banner_b {bb} != {sn['banner_b_featured']}")
            if sn["banner_b_s"] and bb_s != sn["banner_b_s"]:
                errs.append(f"{season_id}: banner_b_s {bb_s} != {sn['banner_b_s']}")
            if mega != [sn["mega_prize_s"]]:
                errs.append(f"{season_id}: mega_prize_s {mega} != {[sn['mega_prize_s']]}")
            if pass_s != [sn["pass_s"]]:
                errs.append(f"{season_id}: pass_s {pass_s} != {[sn['pass_s']]}")
            # Verify pass_s exists in skins.json with catalog_source == "pass"
            ps_obj = all_by_id.get(sn["pass_s"])
            if not ps_obj or ps_obj.get("catalog_source") != "pass" or ps_obj.get("season") != season_id:
                errs.append(f"{season_id}: pass_s {sn['pass_s']} invalid in skins.json")
            # Verify all referenced IDs exist in skins.json
            for ref in ba + ba_s + bb + bb_s + mega + pass_s:
                if ref not in all_by_id:
                    errs.append(f"{season_id}: referenced skin {ref} missing in skins.json")
    rep.check("LC-1.1-CALENDAR-PASS-S", not errs, "; ".join(errs[:6]))


# ---------------------------------------------------------------------------
# Entry point & selftest
# ---------------------------------------------------------------------------

def run_lint(root: Path) -> LintReport:
    rep = LintReport()
    req_files = [
        "data/skins.json",
        "data/shop.json",
        "design/specs/ult_catalogue.json",
        "design/specs/MONETIZATION_PLAN.md",
        "design/specs/SKIN_HUD_SYSTEM.md",
        "design/specs/BATTLE_ULT_SPEC.md",
        "design/specs/ULT_CATALOGUE.md",
        "design/specs/LIVEOPS_CALENDAR.md",
    ]
    missing = [rel for rel in req_files if not (root / rel).is_file()]
    rep.check("FILES-EXIST", not missing, f"missing files: {missing}")
    if missing:
        return rep

    skins_doc = json.loads((root / "data/skins.json").read_text(encoding="utf-8"))
    shop_doc = json.loads((root / "data/shop.json").read_text(encoding="utf-8"))
    ult_doc = json.loads((root / "design/specs/ult_catalogue.json").read_text(encoding="utf-8"))
    mp_text = (root / "design/specs/MONETIZATION_PLAN.md").read_text(encoding="utf-8")
    sh_text = (root / "design/specs/SKIN_HUD_SYSTEM.md").read_text(encoding="utf-8")
    bu_text = (root / "design/specs/BATTLE_ULT_SPEC.md").read_text(encoding="utf-8")
    uc_md_text = (root / "design/specs/ULT_CATALOGUE.md").read_text(encoding="utf-8")
    lc_text = (root / "design/specs/LIVEOPS_CALENDAR.md").read_text(encoding="utf-8")

    lint_json_sources(skins_doc, shop_doc, ult_doc, rep)
    lint_monetization_plan(mp_text, skins_doc, shop_doc, rep)
    lint_skin_hud_system(sh_text, skins_doc, shop_doc, rep)
    lint_battle_ult_spec(bu_text, skins_doc, shop_doc, rep)
    lint_ult_catalogue_md(uc_md_text, skins_doc, rep)
    lint_liveops_calendar(lc_text, skins_doc, rep)
    return rep


def run_selftest(repo_root: Path) -> tuple[int, int, list[str]]:
    """Verify positive pass on repo + 8 negative mutations all fail with expected codes."""
    rel_files = [
        "data/skins.json",
        "data/shop.json",
        "design/specs/ult_catalogue.json",
        "design/specs/MONETIZATION_PLAN.md",
        "design/specs/SKIN_HUD_SYSTEM.md",
        "design/specs/BATTLE_ULT_SPEC.md",
        "design/specs/ULT_CATALOGUE.md",
        "design/specs/LIVEOPS_CALENDAR.md",
    ]
    failures: list[str] = []
    ok = 0
    total = 0

    def copy_tree(dst: Path) -> None:
        for rel in rel_files:
            target = dst / rel
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(repo_root / rel, target)

    # 1. Clean baseline must pass
    total += 1
    rep_clean = run_lint(repo_root)
    if rep_clean.ok:
        ok += 1
    else:
        failures.append(f"clean repo failed: {rep_clean.errors}")

    # 2. Negative mutation cases
    mutations = [
        ("bu_ssrp_petals_w17", "design/specs/BATTLE_ULT_SPEC.md", "| 3 600 / 300 |", "| 1 800 / 150 |", "BU-2.7-PETALS-PRICES"),
        ("mp_ssrp_price", "design/specs/MONETIZATION_PLAN.md", "**2 490** (тест", "**2 790** (тест", "MP-4.5-OUTFIT-LADDER"),
        ("sh_ssrp_window", "design/specs/SKIN_HUD_SYSTEM.md", "с **57-го** дня", "с **29-го** дня", "SH-6.4.1-PATHS"),
        ("bu_ult_threshold", "design/specs/BATTLE_ULT_SPEC.md", "порог 8 пар, старт 0", "порог 10 пар, старт 0", "BU-CR5-ULT-THRESHOLDS"),
        ("sh_skin_id_drift", "design/specs/SKIN_HUD_SYSTEM.md", "`mc_ssrp_dragonnight` | МТ", "`mc_ssrp_wrongid` | МТ", "SH-6.2-CATALOG"),
        ("lc_pass_s_drift", "design/specs/LIVEOPS_CALENDAR.md", "`miel_s_pass1`", "`miel_s_pass9`", "LC-1.1-CALENDAR-PASS-S"),
        ("mp_moon_pack_drift", "design/specs/MONETIZATION_PLAN.md", "| `tw_moon_499` | 499 | 1 950 |", "| `tw_moon_499` | 549 | 1 950 |", "MP-4.1-MOON-PACKS"),
        ("shop_sl_num", "data/shop.json", '"moon": 300,', '"moon": 310,', "SHOP-SL-NUM"),
        ("gacha_soft_pity_drift", "data/shop.json", '"soft_pity": 60,', '"soft_pity": 50,', "MP-3.2-GACHA-ODDS"),
        ("gacha_float_rate", "data/shop.json", '"ssr_base_rate_bp": 150,', '"ssr_base_rate": 0.015,', "JSON-GACHA-INT-BP"),
        ("rules_max_pass_ratio", "data/shop.json", '"max_pass_value_ratio": 2.2,', '"max_pass_value_ratio": 2.5,', "MP-RULES-SYNC"),
        ("fund_forbidden_word", "data/shop.json", '"name_ru": "Фонд Пути",', '"name_ru": "Успей Фонд Пути",', "SHOP-SL-TXT"),
        ("mega_event_pass_ratio", "design/specs/MONETIZATION_PLAN.md", "| 447 / 640 | 1,5 / 1,6 |", "| 447 / 640 | 1,5 |", "MP-4.7-BUNDLES"),
    ]
    for name, rel, old, new, expected_code in mutations:
        total += 1
        with tempfile.TemporaryDirectory(prefix="tw_design_lint_") as tmp:
            troot = Path(tmp)
            copy_tree(troot)
            p = troot / rel
            txt = p.read_text(encoding="utf-8")
            if old not in txt:
                failures.append(f"selftest setup {name}: target {old!r} not found in {rel}")
                continue
            p.write_text(txt.replace(old, new, 1), encoding="utf-8")
            rep_mut = run_lint(troot)
            codes = {e["code"] for e in rep_mut.errors}
            if not rep_mut.ok and expected_code in codes:
                ok += 1
            else:
                failures.append(f"mutation {name}: expected {expected_code}, got ok={rep_mut.ok} codes={sorted(codes)}")
    return ok, total, failures


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="Tile Waifu MD <-> JSON design linter (P93 / W17)")
    ap.add_argument("--root", type=Path, default=Path(__file__).resolve().parent.parent, help="Repository root")
    ap.add_argument("--check", action="store_true", help="Run MD <-> JSON checks (default)")
    ap.add_argument("--selftest", action="store_true", help="Run built-in positive/negative mutation selftest")
    ap.add_argument("--json", type=Path, default=None, help="Write JSON report to path")
    ap.add_argument("--quiet", action="store_true", help="Only print summary line and failures")
    args = ap.parse_args(argv)

    run_check = args.check or not args.selftest
    exit_code = 0

    if args.selftest:
        st_ok, st_total, st_fails = run_selftest(args.root)
        for f in st_fails:
            print(f"DESIGN_LINT SELFTEST FAIL: {f}")
        print(f"DESIGN_LINT SELFTEST {st_ok}/{st_total} {'OK' if st_ok == st_total else 'FAILED'}")
        if st_ok != st_total:
            exit_code = 1

    if run_check:
        rep = run_lint(args.root)
        if args.json:
            args.json.parent.mkdir(parents=True, exist_ok=True)
            args.json.write_text(
                json.dumps({"ok": rep.ok, "passed": rep.passed, "total": rep.total, "errors": rep.errors},
                           ensure_ascii=False, indent=2) + "\n",
                encoding="utf-8",
            )
        for err in rep.errors:
            print(f"DESIGN_LINT FAIL [{err['code']}]: {err['detail']}")
        print(f"DESIGN_LINT RESULT {rep.passed}/{rep.total} {'OK' if rep.ok else 'FAILED'}")
        if not rep.ok:
            exit_code = 1

    return exit_code


if __name__ == "__main__":
    sys.exit(main())
