#!/usr/bin/env python3
"""
Tile Waifu: battle layer simulator v2 (BATTLE_ULT_SPEC.md, sections 1-3 and Appendix R).

Reads ALL combat, progression, catch-up, twist, profile, and gate constants from a single
canonical JSON file: `data/battle/balance.json` (shared with `game/core/modes/battle/` and
`battle_selftest.gd`). Uses integer basis-point arithmetic (`mul_bp`, floor) matching T10.

Run:
  python3 design/specs/sim/battle_sim.py                 (full report, Variant A defaults)
  python3 design/specs/sim/battle_sim.py --quick         (faster Monte-Carlo counts)
  python3 design/specs/sim/battle_sim.py --variant-b     (simulate dormant Variant B flags)
  python3 design/specs/sim/battle_sim.py --balance PATH  (explicit balance.json path)
  python3 design/specs/sim/battle_sim.py --json out.json (dump structured metrics)
  python3 design/specs/sim/battle_sim.py --check-gates   (exit non-zero if hypothesis gates fail)

Only the Python standard library is used. Deterministic: fixed seeds.
NOTE (Appendix R, T24): Simulation numbers in section 3.4 are hypotheses and MUST NOT be
published in player-facing Rules until calibrated from closed beta telemetry logs.
"""
from __future__ import annotations

import json
import pathlib
import random
import statistics
import sys

REPO_ROOT = pathlib.Path(__file__).resolve().parents[3]
DEFAULT_BALANCE_PATH = REPO_ROOT / "data" / "battle" / "balance.json"
CORE_BALANCE_MIRROR = REPO_ROOT / "game" / "core" / "modes" / "battle" / "data" / "balance.json"


def mul_bp(value: int, bp: int, scale: int = 10000) -> int:
    """Deterministic integer basis-point multiply with floor division (matches TWBattleMath.mul_bp)."""
    return (int(value) * int(bp)) // scale


def load_balance(path: pathlib.Path, variant_b: bool = False) -> dict:
    raw_bytes = path.read_bytes()
    if path.resolve() == DEFAULT_BALANCE_PATH.resolve() and CORE_BALANCE_MIRROR.exists():
        mirror_bytes = CORE_BALANCE_MIRROR.read_bytes()
        if raw_bytes != mirror_bytes:
            raise RuntimeError(
                f"Balance mirror drift: {path} != {CORE_BALANCE_MIRROR}"
            )
    bal = json.loads(raw_bytes.decode("utf-8"))
    if variant_b:
        bal = json.loads(raw_bytes.decode("utf-8"))
        bal["flags"]["variant"] = "B"
        bal["flags"]["outfit_stats_enabled"] = True
        bal["flags"]["bond_stats_enabled"] = True
        bal["flags"]["paid_accelerators_enabled"] = True
        bal["progression"]["monetizable_cap_bp"] = bal["progression"]["monetizable_cap_bp_variant_b"]
    return bal


def effective_monetizable_cap_bp(bal: dict) -> int:
    if not bal["flags"].get("outfit_stats_enabled", False):
        return 0
    return int(bal["progression"].get("monetizable_cap_bp", 0))


def compute_hero_stats(bal: dict, name: str, prof: dict, outfit: tuple[str, int] | None,
                       collection_count: int) -> dict:
    bp = int(bal["bp_scale"])
    prog = bal["progression"]
    flags = bal["flags"]
    hero_def = bal["heroes"][name]
    role = hero_def["role"]
    aura = hero_def["aura"]
    rdef = bal["roles"][role]

    level = int(prof["level"])
    lv_bp = bp + int(prog["level_step_bp"]) * (level - 1)
    base_atk = mul_bp(int(rdef["atk1"]), lv_bp, bp)
    base_hp = mul_bp(int(rdef["hp1"]), lv_bp, bp)

    use_b_tal = bool(flags.get("paid_accelerators_enabled", False)) and "tal_bp_variant_b" in prof
    tal_atk_bp = int(prof["tal_bp_variant_b"] if use_b_tal else prof["tal_bp"])
    tal_hp_bp = mul_bp(tal_atk_bp, int(prog["talisman_hp_ratio_bp"]), bp)

    atk_after_tal = mul_bp(base_atk, bp + tal_atk_bp, bp)
    hp_after_tal = mul_bp(base_hp, bp + tal_hp_bp, bp)

    outfit_atk_bp = 0
    album_bp = 0
    cap_bp = effective_monetizable_cap_bp(bal)
    if flags.get("outfit_stats_enabled", False) and cap_bp > 0:
        if outfit is not None:
            tier, stars = outfit
            outfit_atk_bp = int(prog["outfit_base_bp"].get(tier, 0)) + int(prog["outfit_star_step_bp"].get(tier, 0)) * int(stars)
        album_bp = min(
            int(prog["collection_cap_bp"]),
            int(prog["collection_per_outfit_bp"]) * int(collection_count),
        )
    outfit_hp_bp = mul_bp(outfit_atk_bp, int(prog["outfit_hp_ratio_bp"]), bp)
    cap_hp_bp = mul_bp(cap_bp, int(prog["outfit_hp_ratio_bp"]), bp)

    mon_atk_bp = min(cap_bp, outfit_atk_bp + album_bp)
    mon_hp_bp = min(cap_hp_bp, outfit_hp_bp + album_bp)

    bond_bp = 0
    if flags.get("bond_stats_enabled", False):
        bond_lv = min(int(prog["bond_max_lv"]), max(0, int(prof.get("bond", 0))))
        bond_bp = int(prog["bond_per_lv_bp"]) * bond_lv

    final_atk = mul_bp(atk_after_tal, bp + mon_atk_bp + bond_bp, bp)
    final_hp = mul_bp(hp_after_tal, bp + mon_hp_bp + bond_bp, bp)

    return {
        "name": name,
        "role": role,
        "aura": aura,
        "atk": final_atk,
        "hp": final_hp,
        "enr_bp": int(rdef["energy_mult_bp"]),
        "ult_dmg_bp": int(rdef["ult_dmg_bp"]),
        "energy": int(bal["combat"]["energy_start_milli"]),
        "skill": int(prof["skill"]),
    }


def build_squad(bal: dict, names: list[str], prof: dict, collection_count: int | None = None,
                twist: tuple[str, str] | None = None) -> list[dict]:
    coll = int(prof.get("collection", 0)) if collection_count is None else int(collection_count)
    outfits = prof.get("outfits", [])
    sq = []
    for i, n in enumerate(names):
        of = tuple(outfits[i]) if i < len(outfits) else None
        h = compute_hero_stats(bal, n, prof, of, coll)
        if twist is not None and i == 0:
            h["twist_id"] = twist[0]
            h["twist_tier"] = twist[1]
        else:
            h["twist_id"] = ""
            h["twist_tier"] = "minor"
        sq.append(h)
    return sq


def team_pair_power(bal: dict, sq: list[dict]) -> float:
    """Expected combo-1 pair damage (after pair_norm_bp) under neutral suit mix."""
    bp = int(bal["bp_scale"])
    c = bal["combat"]
    auras = bal["auras"]
    suit_p = int(bal["sim"]["suit_prob_bp"]) / float(bp)
    honor_p = 1.0 - suit_p
    tot_suit = 0.0
    for suit in auras:
        s = sum(
            mul_bp(h["atk"], int(c["res_full_bp"] if h["aura"] == suit else c["res_off_bp"]), bp)
            for h in sq
        )
        tot_suit += mul_bp(s, int(c["pair_norm_bp"]), bp)
    s_h = sum(mul_bp(h["atk"], int(c["honor_pair_bp"]), bp) for h in sq)
    s_h = mul_bp(s_h, int(c["pair_norm_bp"]), bp)
    return (tot_suit / float(len(auras))) * suit_p + s_h * honor_p


def simulate(bal: dict, sq: list[dict], boss_hp: int, pairs_budget, skill: str, rng: random.Random,
             cadence: int | None = None, atk_bp: int | None = None, shield_units: int | None = None,
             auto_ults: bool = True, suit_w: list[float] | None = None,
             weak: str | None = None, resist: str | None = None, ref_hp: int | None = None) -> dict:
    bp = int(bal["bp_scale"])
    c = bal["combat"]
    sb = bal["shield_and_boss"]
    re = bal["role_effects"]
    pat = bal["patterns"]
    prog = bal["progression"]
    sim_cfg = bal["sim"]
    auras = bal["auras"]

    if cadence is None:
        cadence = int(sb["boss_cadence_default"])
    if atk_bp is None:
        atk_bp = int(sb["boss_atk_bp"])
    if shield_units is None:
        shield_units = int(sb["shield_units_default"])

    shield_max = shield_units * int(bal["shield_scale"])
    team_max = max(1, sum(h["hp"] for h in sq))
    team_hp = team_max
    boss = int(boss_hp)
    shield = shield_max
    broken = 0
    stun = 0
    clock = 0
    casts = 0
    combo = 0
    fever = 0
    buff_pairs = 0
    burn_dmg = 0
    burn_pairs = 0
    mark_bp = bp
    mark_pairs = 0
    guard = 0
    pairs = 0
    ults = 0
    ud_tot = 0
    pd_tot = 0
    hist: list[str] = []
    energy = [int(h["energy"]) for h in sq]
    t_sec = 0.0
    rate = float(sim_cfg["pair_rate_milli"][skill]) / 60000.0
    combo_p = int(sim_cfg["combo_p_bp"][skill])
    overflow_p = int(sim_cfg["overflow_p_bp"][skill])
    suit_prob_bp = int(sim_cfg["suit_prob_bp"])
    ladder_p_bp = int(sim_cfg["ladder_sim_p_bp"])
    kan_p_bp = int(sim_cfg["kan_sim_p_bp"])

    if isinstance(pairs_budget, (tuple, list)):
        bounds = []
        acc = 0
        for w in pairs_budget:
            acc += int(w)
            bounds.append(acc)
        total_budget = acc
    else:
        bounds = [int(pairs_budget)]
        total_budget = int(pairs_budget)

    wave = 0
    has_brk = any(h["role"] == "BRK" for h in sq)
    ult_cost = int(c["ult_cost_milli"])

    while pairs < total_budget and boss > 0 and team_hp > 0:
        if pairs in bounds[:-1]:
            wave = bounds.index(pairs) + 1
            combo = 0
        pairs += 1
        t_sec += 1.0 / rate

        # suit roll
        if rng.randrange(bp) < suit_prob_bp:
            if suit_w:
                suit = rng.choices(auras, weights=suit_w)[0]
            else:
                suit = rng.choice(auras)
        else:
            suit = "honor"
        hist.append(suit)

        # combo & fever
        if combo > 0 and rng.randrange(bp) < combo_p:
            combo += 1
        else:
            combo = 1
        if combo >= int(c["fever_combo"]) and fever == 0:
            fever = int(c["fever_pairs"])
        c_steps = min(combo - 1, int(c["combo_cap"]))
        cm_bp = bp + int(c["combo_step_bp"]) * c_steps

        # pattern (highest bonus wins)
        gest_bp = 0
        if len(hist) >= 3 and hist[-1] == hist[-2] == hist[-3] and suit != "honor":
            gest_bp = max(gest_bp, int(pat["one_suit"]["dmg_bonus_bp"]))
        if rng.randrange(bp) < ladder_p_bp:
            gest_bp = max(gest_bp, int(pat["ladder"]["dmg_bonus_bp"]))
        if rng.randrange(bp) < kan_p_bp:
            gest_bp = max(gest_bp, int(pat["kan"]["dmg_bonus_bp"]))
        if len(hist) >= 6 and len(set(hist[-6:])) == 1 and suit != "honor":
            gest_bp = max(gest_bp, int(pat["pure"]["dmg_bonus_bp"]))
            pure_en = int(pat["pure"]["energy_bonus_milli"])
            for j in range(len(sq)):
                energy[j] = min(ult_cost, energy[j] + pure_en)

        # pair strike (exact fixed integer multiplication order)
        if suit == "honor":
            raw = sum(mul_bp(h["atk"], int(c["honor_pair_bp"]), bp) for h in sq)
        else:
            raw = sum(
                mul_bp(h["atk"], int(c["res_full_bp"] if h["aura"] == suit else c["res_off_bp"]), bp)
                for h in sq
            )
        dmg = mul_bp(raw, int(c["pair_norm_bp"]), bp)
        dmg = mul_bp(dmg, cm_bp, bp)
        dmg = mul_bp(dmg, bp + gest_bp, bp)
        if weak and suit == weak:
            dmg = mul_bp(dmg, int(c["weak_mult_bp"]), bp)
        if resist and suit == resist:
            dmg = mul_bp(dmg, int(c["resist_mult_bp"]), bp)
        if fever > 0:
            dmg = mul_bp(dmg, int(c["fever_dmg_bp"]), bp)
        if buff_pairs > 0:
            dmg = mul_bp(dmg, int(c["support_buff_bp"]), bp)
            buff_pairs -= 1
        if mark_pairs > 0:
            dmg = mul_bp(dmg, mark_bp, bp)
            mark_pairs -= 1
        if broken > 0:
            dmg = mul_bp(dmg, int(sb["break_mult_bp"]), bp)
            broken -= 1

        boss -= dmg
        pd_tot += dmg

        # active burn DoT from twist T2
        if burn_pairs > 0 and boss > 0:
            boss -= burn_dmg
            ud_tot += burn_dmg
            burn_pairs -= 1

        # shield damage
        sh_dmg = int(sb["shield_pair_milli"])
        if has_brk:
            sh_dmg = mul_bp(sh_dmg, int(sb["shield_brk_team_bp"]), bp)
        if fever > 0:
            sh_dmg = mul_bp(sh_dmg, int(c["fever_shield_bp"]), bp)
        shield -= sh_dmg
        if shield <= 0:
            broken = int(sb["break_hits"])
            stun = max(stun, int(sb["break_stun"]))
            shield = shield_max

        # energy gain (milli-energy)
        for i, h in enumerate(sq):
            g = mul_bp(int(c["energy_pair_milli"]), h["enr_bp"], bp)
            if suit == "honor":
                g = mul_bp(g, int(c["energy_honor_bp"]), bp)
            elif h["aura"] == suit:
                g = mul_bp(g, int(c["energy_res_bp"]), bp)
            g += int(c["energy_combo_milli"]) * c_steps
            if fever > 0:
                g = mul_bp(g, int(c["fever_energy_bp"]), bp)
            energy[i] = min(ult_cost, energy[i] + g)
        if fever > 0:
            fever -= 1

        # ults
        if auto_ults:
            for i, h in enumerate(sq):
                if energy[i] >= ult_cost and boss > 0:
                    energy[i] = 0
                    ults += 1
                    sk_bp = bp + int(prog["skill_ult_step_bp"]) * (h["skill"] - 1)
                    ud = mul_bp(h["atk"], h["ult_dmg_bp"], bp)
                    ud = mul_bp(ud, sk_bp, bp)
                    if broken > 0:
                        ud = mul_bp(ud, int(sb["break_mult_bp"]), bp)
                        broken -= 1
                    boss -= ud
                    ud_tot += ud

                    sh_u = int(sb["shield_ult_milli"])
                    if h["role"] == "BRK":
                        sh_u = mul_bp(sh_u, int(sb["shield_brk_ult_bp"]), bp)
                    shield -= sh_u
                    if shield <= 0:
                        broken = int(sb["break_hits"])
                        stun = max(stun, int(sb["break_stun"]))
                        shield = shield_max

                    if h["role"] == "SUP":
                        buff_pairs = int(c["support_buff_pairs"])
                        ally_e = int(c["sup_ult_ally_energy_milli"])
                        for j in range(len(sq)):
                            energy[j] = min(ult_cost, energy[j] + ally_e)
                    elif h["role"] == "HEAL":
                        team_hp = min(team_max, team_hp + mul_bp(team_max, int(re["heal_ult_bp"]), bp))
                    elif h["role"] == "GRD":
                        guard = mul_bp(team_max, int(re["guard_ult_bp"]), bp)
                    elif h["role"] == "BRK":
                        stun = max(stun, 1)

                    # optional equal-value twist (T1..T8)
                    tid = h.get("twist_id", "")
                    if tid and tid in bal["twists"] and boss > 0:
                        tw = bal["twists"][tid][h.get("twist_tier", "minor")]
                        if tid == "T1":
                            ex_n = int(tw["extra_ult_pairs"])
                            ex_raw = sum(mul_bp(x["atk"], int(c["honor_pair_bp"]), bp) for x in sq)
                            ex_dmg = mul_bp(mul_bp(ex_raw, int(c["pair_norm_bp"]), bp), int(c["ult_pair_dmg_bp"]), bp) * ex_n
                            ex_dmg += mul_bp(h["atk"], int(tw.get("bonus_atk_bp", 0)), bp)
                            boss -= ex_dmg
                            ud_tot += ex_dmg
                        elif tid == "T2":
                            burn_dmg = mul_bp(h["atk"], int(tw["atk_bp"]), bp)
                            burn_pairs = int(tw["pairs"])
                        elif tid == "T3":
                            guard += mul_bp(team_max, int(tw["barrier_bp"]), bp)
                            bd = mul_bp(h["atk"], int(tw.get("bonus_atk_bp", 0)), bp)
                            boss -= bd
                            ud_tot += bd
                        elif tid == "T4":
                            ae = int(tw["ally_energy_milli"])
                            for j in range(len(sq)):
                                energy[j] = min(ult_cost, energy[j] + ae)
                            bd = mul_bp(h["atk"], int(tw.get("bonus_atk_bp", 0)), bp)
                            boss -= bd
                            ud_tot += bd
                        elif tid == "T5":
                            team_hp = min(team_max, team_hp + mul_bp(team_max, int(tw["heal_bp"]), bp))
                            bd = mul_bp(h["atk"], int(tw.get("bonus_atk_bp", 0)), bp)
                            boss -= bd
                            ud_tot += bd
                        elif tid == "T6":
                            shield -= mul_bp(shield_max, int(tw["shield_pct_bp"]), bp)
                            if shield <= 0:
                                broken = int(sb["break_hits"])
                                stun = max(stun, int(sb["break_stun"]))
                                shield = shield_max
                            bd = mul_bp(h["atk"], int(tw.get("bonus_atk_bp", 0)), bp)
                            boss -= bd
                            ud_tot += bd
                        elif tid == "T7":
                            fever += int(tw["fever_pairs"])
                            bd = mul_bp(h["atk"], int(tw.get("bonus_atk_bp", 0)), bp)
                            boss -= bd
                            ud_tot += bd
                        elif tid == "T8":
                            mark_bp = int(tw["dmg_mult_bp"])
                            mark_pairs = int(tw["pairs"])

        # heal passives
        for h in sq:
            if h["role"] == "HEAL":
                team_hp = min(team_max, team_hp + mul_bp(team_max, int(re["heal_passive_bp"]), bp))

        # boss clock
        clock += 1
        eff_cadence = max(
            int(sb["boss_cadence_min"]),
            cadence - int(sb["boss_cadence_enrage_step"]) * wave,
        )
        if clock >= eff_cadence and boss > 0:
            clock = 0
            casts += 1
            if stun > 0:
                stun -= 1
            else:
                base_ref = ref_hp if ref_hp is not None else team_max
                d = mul_bp(base_ref, atk_bp, bp)
                d = mul_bp(d, bp + int(sb["enrage_per_wave_bp"]) * wave, bp)
                if casts % int(sb["boss_heavy_every"]) == 0:
                    d = mul_bp(d, int(sb["boss_heavy_bp"]), bp)
                if guard > 0:
                    ab = min(guard, d)
                    guard -= ab
                    d -= ab
                team_hp -= d

        # tray overflow
        if rng.randrange(bp) < overflow_p:
            team_hp -= mul_bp(team_max, int(sb["overflow_dmg_bp"]), bp)
            combo = 0

    won = boss <= 0 and team_hp > 0
    return {
        "won": won,
        "pairs": pairs,
        "waves": wave + 1,
        "secs": t_sec,
        "ult_dmg": ud_tot,
        "pair_dmg": pd_tot,
        "ults": ults,
        "hp_left": max(0.0, team_hp / float(team_max)),
        "boss_left": max(0, boss),
    }


def run_batch(bal: dict, n: int, names: list[str], prof: dict, boss_hp: int, budget, skill: str,
              seed: int, ref_hp_base: int, atk_mult_bp: int = 10000, scale_bp: int = 10000,
              twist: tuple[str, str] | None = None, **kw) -> list[dict]:
    bp = int(bal["bp_scale"])
    rng = random.Random(seed)
    res = []
    eff_ref_hp = mul_bp(ref_hp_base, atk_mult_bp, bp)
    hp_scale_bp = int(round((scale_bp / float(bp)) ** 0.5 * bp)) if scale_bp != bp else bp
    for _ in range(n):
        sq = build_squad(bal, names, prof, twist=twist)
        if scale_bp != bp:
            for h in sq:
                h["atk"] = max(1, mul_bp(h["atk"], scale_bp, bp))
                h["hp"] = max(1, mul_bp(h["hp"], hp_scale_bp, bp))
        res.append(simulate(bal, sq, boss_hp, budget, skill, rng, ref_hp=eff_ref_hp, **kw))
    return res


def summarize(bal: dict, res: list[dict]) -> dict:
    sb = bal["shield_and_boss"]
    min_hp = int(sb["star2_min_hp_bp"]) / float(bal["bp_scale"])
    max_p3 = int(sb["star3_max_pairs"])
    w = [r for r in res if r["won"]]
    three = [r for r in w if r["hp_left"] >= min_hp and r["pairs"] <= max_p3]
    return {
        "win": len(w) / len(res),
        "three": len(three) / len(res),
        "pairs": statistics.mean([r["pairs"] for r in w]) if w else float("nan"),
        "secs": statistics.mean([r["secs"] for r in w]) if w else float("nan"),
        "ults": statistics.mean([r["ults"] for r in res]),
        "hp": statistics.mean([r["hp_left"] for r in w]) if w else float("nan"),
    }


def calibrate(bal: dict, ref_hp_base: int, target_pairs: float = 28.0) -> int:
    squad_std = bal["sim"]["squad_std"]
    prof0 = bal["sim"]["profiles"]["P0 F2P-max"]
    waves = bal["shield_and_boss"]["waves_default"]
    lo, hi = 1000, 800000
    for _ in range(40):
        mid = (lo + hi) // 2
        rs = run_batch(bal, 150, squad_std, prof0, mid, waves, "mid", 11, ref_hp_base)
        avg = statistics.mean([r["pairs"] for r in rs if r["won"]] or [999.0])
        if avg > target_pairs:
            hi = mid
        else:
            lo = mid
    return (lo + hi) // 2


def simulate_squad_progression_days(bal: dict, daily_xp: int, target_level: int,
                                    squad_size: int = 5, use_catchup: bool = True,
                                    pre_cap_gift: int = 0) -> float:
    """Deterministic day-by-day squad XP leveling model with Appendix R W15 catch-up."""
    bp = int(bal["bp_scale"])
    xp_cum = bal["progression"]["xp_cum"]
    cu = bal["catchup"]
    lag_thr = int(cu["lag_levels_threshold"])
    cu_mult_bp = int(cu["xp_mult_bp"]) if use_catchup and cu.get("enabled", True) else bp
    sync_new = bool(cu.get("sync_new_hero_to_squad_avg", True)) and use_catchup

    # Start with 3 slots (BU 1.6.0); slot 4 unlocks at lead Lv24 (Ch2 boss), slot 5 at lead Lv38 (Ch4 boss)
    levels = [1, 1, 1]
    xp_pool = [0, 0, 0]
    unlocked = 3
    days = 0
    bonus_xp_left = pre_cap_gift

    def level_for_xp(x: int) -> int:
        lv = 1
        while lv < len(xp_cum) and x >= xp_cum[lv]:
            lv += 1
        return lv

    while days < 365:
        if unlocked >= squad_size and all(lv >= target_level for lv in levels):
            break
        days += 1
        budget = daily_xp + bonus_xp_left
        bonus_xp_left = 0

        # Unlock slot 4 after Ch2 (avg/lead Lv24), slot 5 after Ch4 (lead Lv38)
        lead_lv = max(levels)
        if unlocked < 4 and squad_size >= 4 and lead_lv >= 24:
            unlocked = 4
            sync_lv = (sum(levels) // len(levels)) if sync_new else 1
            levels.append(sync_lv)
            xp_pool.append(xp_cum[sync_lv - 1])
        if unlocked < 5 and squad_size >= 5 and lead_lv >= 38:
            unlocked = 5
            sync_lv = (sum(levels) // len(levels)) if sync_new else 1
            levels.append(sync_lv)
            xp_pool.append(xp_cum[sync_lv - 1])

        # Spend daily XP in 500-XP chunks: advance lead 10 levels ahead to activate catch-up, then feed laggers
        chunk = 500
        rem = budget
        while rem > 0:
            step = min(chunk, rem)
            rem -= step
            max_lv = max(levels)
            # Pick target: if anyone lags >= lag_thr behind max_lv and < target_level, feed lowest lagger (x2 XP)
            laggers = [i for i, lv in enumerate(levels) if lv < target_level and (max_lv - lv) >= lag_thr]
            if laggers and use_catchup:
                idx = min(laggers, key=lambda i: (levels[i], xp_pool[i]))
                eff = mul_bp(step, cu_mult_bp, bp)
            else:
                # If max_lv < target_level, push lead up to trigger catch-up on lagging allies
                under = [i for i, lv in enumerate(levels) if lv < target_level]
                if not under:
                    break
                if use_catchup and max_lv < target_level:
                    idx = max(under, key=lambda i: (levels[i], xp_pool[i]))
                else:
                    idx = min(under, key=lambda i: (levels[i], xp_pool[i]))
                eff = step
            xp_pool[idx] += eff
            levels[idx] = level_for_xp(xp_pool[idx])
    return float(days)


def simulate_f2p_mid_ch4_d30(bal: dict, n_players: int = 1000, seed: int = 101) -> dict:
    """Appendix R W15 Beta P1 metric: share of F2P-mid players reaching Chapter 4 (stage 40 readiness, Lv38 squad of 4) by D30."""
    rng = random.Random(seed)
    base_mid = int(bal["sim"]["daily_xp_income"]["mid"])
    att_lo, att_hi, att_mode = bal["sim"].get("f2p_mid_attendance_days_per_week", [3.5, 6.0, 4.8])
    ch4_enter_lv = 31   # Chapter 3 boss recommended level = 31 -> enters Chapter 4 (stage 31)
    ch4_clear_lv = 38   # Chapter 4 boss recommended level = 38 -> clears Chapter 4 (stage 40)
    entered_cu = 0
    cleared_cu = 0
    entered_no_cu = 0
    cleared_no_cu = 0
    days_enter_cu = []
    days_clear_cu = []
    days_clear_no_cu = []
    for _ in range(n_players):
        # Realistic F2P-mid: plays att_days/7 days per week, plus vault-efficiency variance 0.70..1.15
        att_ratio = rng.triangular(att_lo, att_hi, att_mode) / 7.0
        eff = rng.triangular(0.70, 1.15, 0.92)
        daily = max(3500, int(round(base_mid * att_ratio * eff)))
        d_ent_cu = simulate_squad_progression_days(bal, daily, ch4_enter_lv, squad_size=4, use_catchup=True)
        d_clr_cu = simulate_squad_progression_days(bal, daily, ch4_clear_lv, squad_size=4, use_catchup=True)
        d_ent_no = simulate_squad_progression_days(bal, daily, ch4_enter_lv, squad_size=4, use_catchup=False)
        d_clr_no = simulate_squad_progression_days(bal, daily, ch4_clear_lv, squad_size=4, use_catchup=False)
        days_enter_cu.append(d_ent_cu)
        days_clear_cu.append(d_clr_cu)
        days_clear_no_cu.append(d_clr_no)
        if d_ent_cu <= 30:
            entered_cu += 1
        if d_clr_cu <= 30:
            cleared_cu += 1
        if d_ent_no <= 30:
            entered_no_cu += 1
        if d_clr_no <= 30:
            cleared_no_cu += 1
    return {
        "n_players": n_players,
        "reached_ch4_d30_with_catchup": entered_cu / n_players,
        "cleared_ch4_d30_with_catchup": cleared_cu / n_players,
        "reached_ch4_d30_without_catchup": entered_no_cu / n_players,
        "cleared_ch4_d30_without_catchup": cleared_no_cu / n_players,
        "median_days_enter_ch4_with_catchup": statistics.median(days_enter_cu),
        "median_days_clear_ch4_with_catchup": statistics.median(days_clear_cu),
        "median_days_clear_ch4_without_catchup": statistics.median(days_clear_no_cu),
    }


def main() -> int:
    quick = "--quick" in sys.argv
    variant_b = "--variant-b" in sys.argv
    check_gates = "--check-gates" in sys.argv
    bal_path = DEFAULT_BALANCE_PATH
    if "--balance" in sys.argv:
        bal_path = pathlib.Path(sys.argv[sys.argv.index("--balance") + 1])

    bal = load_balance(bal_path, variant_b=variant_b)
    bp = int(bal["bp_scale"])
    N = 300 if quick else 1500
    squad_std = bal["sim"]["squad_std"]
    profiles = bal["sim"]["profiles"]
    waves = bal["shield_and_boss"]["waves_default"]
    diffs = bal["shield_and_boss"]["difficulties"]
    flags = bal["flags"]
    out: dict = {
        "balance_path": str(bal_path.relative_to(REPO_ROOT).as_posix()) if REPO_ROOT in bal_path.resolve().parents else str(bal_path),
        "flags": flags,
        "publish_warning": "HYPOTHESIS ONLY (Appendix R T24): do not publish section 3.4 numbers in Rules until calibrated by beta logs.",
    }

    print(
        f"[META] balance={out['balance_path']} variant={flags['variant']} "
        f"outfit_stats={flags['outfit_stats_enabled']} bond_stats={flags['bond_stats_enabled']} "
        f"paid_accel={flags['paid_accelerators_enabled']} publish_in_rules={flags['publish_sim_numbers_in_rules']} "
        f"gates_calibrated={flags['selftest_gates_calibrated']}"
    )

    prof0 = profiles["P0 F2P-max"]
    sq0 = build_squad(bal, squad_std, prof0)
    ref_hp_base = sum(h["hp"] for h in sq0)
    hp28 = calibrate(bal, ref_hp_base, 28.0)
    tpp0 = team_pair_power(bal, sq0)
    k_normal = hp28 / tpp0
    out["constants"] = {
        "ref_team_hp": ref_hp_base,
        "boss_hp_normal": hp28,
        "tpp_p0": round(tpp0, 1),
        "K_normal": round(k_normal, 2),
        "k_normal_bp": int(round(k_normal * bp)),
    }
    print(
        "[CAL] P0 squad: team HP %d, pair power (combo 1) %.1f. Boss HP %d gives 28 pairs (mid skill).  K_normal = HP / TPP = %.1f"
        % (ref_hp_base, tpp0, hp28, k_normal)
    )

    print("\n[T1] profile x skill on the calibrated NORMAL stage (waves 36+24 pairs): win / 3-star / pairs / sec / ults / HP left")
    t1 = {}
    for pn, prof in profiles.items():
        row = {}
        for sk in ("casual", "mid", "expert"):
            row[sk] = summarize(bal, run_batch(bal, N, squad_std, prof, hp28, waves, sk, 21, ref_hp_base))
        t1[pn] = row
        print(
            "  %-12s" % pn
            + " | ".join(
                "%s win %3.0f%% 3* %3.0f%% %4.1fp %3.0fs u%.1f hp%3.0f%%"
                % (sk[:3], row[sk]["win"] * 100, row[sk]["three"] * 100, row[sk]["pairs"],
                   row[sk]["secs"], row[sk]["ults"], row[sk]["hp"] * 100)
                for sk in row
            )
        )
    out["t1"] = t1

    print("\n[T1b] Variant A power parity: F2P tiers (mid / month-2 / month-6+) vs whale outfits (SSRP*5 + 3xSSR*5 + S*5, album 12)")
    whale_outfits = profiles["P3 whale"]["outfits"]
    t1b = {}
    for tier_name in ("P0- F2P-mid", "P0 F2P-max", "P0+ F2P-long"):
        p_f2p = profiles[tier_name]
        p_wh = dict(p_f2p, outfits=whale_outfits, collection=12)
        sq_f = build_squad(bal, squad_std, p_f2p)
        sq_w = build_squad(bal, squad_std, p_wh)
        atk_f = sum(h["atk"] for h in sq_f)
        atk_w = sum(h["atk"] for h in sq_w)
        hp_f = sum(h["hp"] for h in sq_f)
        hp_w = sum(h["hp"] for h in sq_w)
        sm_f = summarize(bal, run_batch(bal, N // 3, squad_std, p_f2p, hp28, waves, "mid", 27, ref_hp_base))
        sm_w = summarize(bal, run_batch(bal, N // 3, squad_std, p_wh, hp28, waves, "mid", 27, ref_hp_base))
        delta_atk_pct = (atk_w - atk_f) / float(atk_f) * 100.0
        delta_hp_pct = (hp_w - hp_f) / float(hp_f) * 100.0
        delta_win_pp = (sm_w["win"] - sm_f["win"]) * 100.0
        t1b[tier_name] = {
            "f2p_atk": atk_f, "whale_atk": atk_w, "delta_atk_pct": round(delta_atk_pct, 4),
            "f2p_hp": hp_f, "whale_hp": hp_w, "delta_hp_pct": round(delta_hp_pct, 4),
            "delta_win_pp": round(delta_win_pp, 4),
        }
        print(
            "  %-13s ATK %4d vs %4d (%+5.2f%%) | HP %4d vs %4d (%+5.2f%%) | mid win %5.1f%% vs %5.1f%% (%+5.2f pp)"
            % (tier_name, atk_f, atk_w, delta_atk_pct, hp_f, hp_w, delta_hp_pct,
               sm_f["win"] * 100, sm_w["win"] * 100, delta_win_pp)
        )
    out["t1b"] = t1b

    print("\n[T2] campaign curve (60 launch stages): level cap per chapter, recommended pair power RP, boss HP = RP * K_normal * stage factor")
    t2 = []
    prog = bal["progression"]
    sf = bal["shield_and_boss"]["stage_factors_bp"]
    boss_atk_bp = int(bal["shield_and_boss"]["boss_atk_bp"])
    for stage in range(1, 61):
        ch = (stage - 1) // 10 + 1
        k = (stage - 1) % 10 + 1
        lvl_cap = min(int(prog["level_cap_launch"]), int(prog["chapter_cap_base"]) + int(prog["chapter_cap_step"]) * ch)
        lv = lvl_cap if k >= 3 else lvl_cap - 3
        tal_bp = min(3000, 400 * ch + (200 * k) // 10)
        sk = min(8, 1 + ch + (1 if k >= 6 else 0))
        prof = {"level": lv, "tal_bp": tal_bp, "skill": sk, "outfits": [], "bond": min(10, 2 + ch), "collection": 0}
        sq = build_squad(bal, squad_std, prof)
        rp = team_pair_power(bal, sq)
        ftype = "boss" if k == 10 else ("elite" if k == 5 else "normal")
        factor_bp = int(sf[ftype])
        rhp = sum(h["hp"] for h in sq)
        t2.append({
            "stage": stage, "chapter": ch, "level_cap": lvl_cap, "level": lv,
            "rp": round(rp, 1), "boss_hp": round(rp * k_normal * (factor_bp / float(bp))),
            "factor": factor_bp / float(bp), "ref_team_hp": rhp,
            "boss_cast": mul_bp(rhp, boss_atk_bp, bp),
        })
    for r in t2:
        if r["stage"] in (1, 5, 10, 11, 20, 30, 40, 50, 60):
            print(
                "  stage %2d ch %d L%2d (cap L%2d)  RP %6.1f  boss HP %7d (x%.2f)  ref team HP %5d  boss cast %5d"
                % (r["stage"], r["chapter"], r["level"], r["level_cap"], r["rp"],
                   r["boss_hp"], r["factor"], r["ref_team_hp"], r["boss_cast"])
            )
    out["t2"] = t2

    print("\n[T3] win / 3-star vs power ratio (own pair power / recommended), mid skill, normal stage")
    t3 = []
    for ratio_bp in (6000, 7000, 8000, 9000, 10000, 11000, 12000, 13000, 14000):
        s_ = summarize(bal, run_batch(bal, N, squad_std, prof0, hp28, waves, "mid", 31, ref_hp_base, scale_bp=ratio_bp))
        t3.append({"ratio": ratio_bp / float(bp), **s_})
        print(
            "  ratio %.2f  win %5.1f%%  3* %5.1f%%  TTK %4.1f pairs (%3.0f s)  ults %.1f  HP left %3.0f%%"
            % (ratio_bp / float(bp), s_["win"] * 100, s_["three"] * 100,
               s_["pairs"], s_["secs"], s_["ults"], s_["hp"] * 100)
        )
    out["t3"] = t3

    print("\n[T4] raid score = damage dealt in a fixed 60-pair run (boss HP infinite), mid skill; relative to F2P-max / F2P-long")
    t4 = {}
    for pn, prof in profiles.items():
        rng = random.Random(41)
        dm = []
        for _ in range(N // 3):
            sq = build_squad(bal, squad_std, prof)
            r = simulate(bal, sq, 10**12, waves, "mid", rng, ref_hp=ref_hp_base)
            dm.append(10**12 - r["boss_left"])
        t4[pn] = statistics.mean(dm)
    base = t4["P0 F2P-max"]
    base2 = t4["P0+ F2P-long"]
    for pn, v in t4.items():
        print("  %-13s score %9.0f  (x%.2f of P0, x%.2f of P0+)" % (pn, v, v / base, v / base2))
    out["t4"] = {k: [round(v / base, 4), round(v / base2, 4)] for k, v in t4.items()}

    print("\n[T5] skill vs wallet: win rate by difficulty (boss HP/ATK multipliers from balance.json)")
    t5 = {}
    for label, dcfg in diffs.items():
        hm_bp = int(dcfg["hp_bp"])
        am_bp = int(dcfg["atk_bp"])
        boss_d = mul_bp(hp28, hm_bp, bp)
        for pn in ("P0- F2P-mid", "P0 F2P-max", "P3 whale"):
            for sk in ("casual", "mid", "expert"):
                sm = summarize(
                    bal,
                    run_batch(bal, N // 2, squad_std, profiles[pn], boss_d, waves, sk, 51, ref_hp_base, atk_mult_bp=am_bp),
                )
                t5[f"{label}|{pn}|{sk}"] = sm["win"]
        print(
            "  %-9s " % label
            + " | ".join(
                "%s %s %3.0f%%" % (pn.split()[0], sk[:3], t5[f"{label}|{pn}|{sk}"] * 100)
                for pn in ("P0- F2P-mid", "P0 F2P-max", "P3 whale")
                for sk in ("casual", "mid", "expert")
            )
        )
    out["t5"] = t5

    print("\n[T6] aura: stage suit tilt 50/25/25 (man heavy), boss weak = man x1.25, resists = pin x0.85")
    def with_auras(names, auras):
        sq = build_squad(bal, names, prof0)
        for h, a_ in zip(sq, auras):
            h["aura"] = a_
        return sq
    cases = {
        "all 5 = man (stack the weak suit)": ["man"] * 5,
        "3 man + 1 pin + 1 sou":             ["man", "man", "man", "pin", "sou"],
        "balanced 2/2/1":                    ["man", "man", "pin", "pin", "sou"],
        "all 5 = pin (the resisted suit)":   ["pin"] * 5,
    }
    out["t6"] = {}
    for nm, auras in cases.items():
        rng = random.Random(61)
        rs = [
            simulate(bal, with_auras(squad_std, auras), hp28, waves, "mid", rng,
                     ref_hp=ref_hp_base, suit_w=[0.5, 0.25, 0.25], weak="man", resist="pin")
            for _ in range(N)
        ]
        sm = summarize(bal, rs)
        out["t6"][nm] = sm
        print("  %-36s TTK %.1f pairs  win %.0f%%  3* %.0f%%" % (nm, sm["pairs"], sm["win"] * 100, sm["three"] * 100))
    rng = random.Random(61)
    sm_ref = summarize(bal, [simulate(bal, build_squad(bal, squad_std, prof0), hp28, waves, "mid", rng, ref_hp=ref_hp_base) for _ in range(N)])
    print("  %-36s TTK %.1f pairs  (reference: neutral stage, no tilt)" % ("neutral stage", sm_ref["pairs"]))

    print("\n[T7] ult cadence and share of ult damage (P0, mid skill, 5 heroines)")
    t7_shares = {}
    for bud in ((36,), (36, 24), (36, 36, 36)):
        rs = [
            simulate(bal, build_squad(bal, squad_std, prof0), 10**12, bud, "mid",
                     random.Random(71 + i), ref_hp=ref_hp_base, atk_bp=0)
            for i in range(N // 3)
        ]
        u = statistics.mean([r["ults"] for r in rs])
        tot = sum(bud)
        share = statistics.mean([r["ult_dmg"] / max(1.0, float(r["ult_dmg"] + r["pair_dmg"])) for r in rs])
        rate_mid = float(bal["sim"]["pair_rate_milli"]["mid"]) / 1000.0
        print(
            "  %3d pairs: %.1f ults per fight -> one ult every %.1f pairs (%.0f s); ult share of damage %.0f%%"
            % (tot, u, tot / max(u, 0.01), tot / max(u, 0.01) / rate_mid * 60.0, share * 100)
        )
        out[f"t7_{tot}"] = {"ults": round(u, 2), "ult_share": round(share, 4)}
        t7_shares[tot] = share

    cap_bp = effective_monetizable_cap_bp(bal)
    print(
        "\n[T8] spend ladder: per-heroine ATK bonus and team effect (variant=%s, MONETIZABLE_CAP=%d bp = %.0f%%)"
        % (flags["variant"], cap_bp, cap_bp / 100.0)
    )
    ladder = (
        ("nothing",                              [],                                               0,  0),
        ("1 S *2 on Hana",                       [("hana", "S", 2)],                               2,  599 + 49),
        ("1 SSR *1 on Hana",                     [("hana", "SSR", 1)],                             2,  1490),
        ("1 SSR *5 on Hana",                     [("hana", "SSR", 5)],                             2,  1490 + 446),
        ("SSR *5 on Hana + Nova + Mc",           [("hana", "SSR", 5), ("nova", "SSR", 5), ("mc", "SSR", 5)], 6, 3 * (1490 + 446)),
        ("1 SSR+ + 4 SSR *5 on the whole squad", [("hana", "SSRP", 5), ("nova", "SSR", 5), ("mc", "SSR", 5), ("rin", "SSR", 5), ("kohaku", "SSR", 5)], 12, (2490 + 446) + 4 * (1490 + 446)),
    )
    sq_ref = build_squad(bal, squad_std, profiles["P0+ F2P-long"])
    tot_atk = sum(h["atk"] for h in sq_ref)
    t8_out = []
    for nm, lst, coll, rub in ladder:
        gain = 0
        shown = []
        album_bp = 0
        if flags["outfit_stats_enabled"] and cap_bp > 0:
            album_bp = min(int(prog["collection_cap_bp"]), int(prog["collection_per_outfit_bp"]) * coll)
        for h in sq_ref:
            pct_bp = 0
            if flags["outfit_stats_enabled"] and cap_bp > 0:
                for who, tier, st in lst:
                    if who == h["name"]:
                        pct_bp = int(prog["outfit_base_bp"][tier]) + int(prog["outfit_star_step_bp"][tier]) * st
            eff_bp = min(cap_bp, pct_bp + album_bp)
            gain += mul_bp(h["atk"], eff_bp, bp)
            if eff_bp > album_bp:
                shown.append("%s +%.0f%%" % (h["name"], eff_bp / 100.0))
        team_pct = gain / float(tot_atk) * 100.0
        t8_out.append({"label": nm, "team_atk_pct": round(team_pct, 2), "rub": rub})
        print(
            "  %-38s album +%.1f%%  %-34s team ATK +%4.1f%%  direct price ~%6d RUB"
            % (nm, album_bp / 100.0, ", ".join(shown) or "-", team_pct, rub)
        )
    out["t8"] = t8_out

    print("\n[T9] progression time (integer xp_cum table from balance.json) + W15 catch-up (no paid accelerators in Variant A)")
    xp_cum = prog["xp_cum"]
    for cap in (20, 40, 60, 70, 80, 90):
        print("  Lv1 -> Lv%-2d  cumulative XP %9d" % (cap, xp_cum[cap - 1]))
    inc = bal["sim"]["daily_xp_income"]
    gift_xp = int(bal["catchup"]["pre_cap_raise_gift_xp"])
    t9_rows = {}
    for nm, per_day in (("active (6 vault runs + drops)", int(inc["active"])),
                        ("mid F2P (4-5 runs + drops)", int(inc["mid"])),
                        ("light (3 runs)", int(inc["light"]))):
        one_days = xp_cum[59] / float(per_day)
        sq_no_cu = simulate_squad_progression_days(bal, per_day, 60, squad_size=5, use_catchup=False)
        sq_cu = simulate_squad_progression_days(bal, per_day, 60, squad_size=5, use_catchup=True)
        sq_cu_gift = simulate_squad_progression_days(bal, per_day, 70, squad_size=5, use_catchup=True, pre_cap_gift=gift_xp)
        t9_rows[nm] = {
            "one_lv60_days": round(one_days, 1),
            "squad5_lv60_no_catchup": round(sq_no_cu, 1),
            "squad5_lv60_with_catchup": round(sq_cu, 1),
            "squad5_lv70_with_catchup_and_gift": round(sq_cu_gift, 1),
        }
        print(
            "  %-32s 1xLv60: %4.1fd | 5xLv60 no-cu: %5.1fd | 5xLv60 W15 catch-up: %5.1fd | 5xLv70 (+%dk gift): %5.1fd"
            % (nm, one_days, sq_no_cu, sq_cu, gift_xp // 1000, sq_cu_gift)
        )
    out["t9"] = {"xp_to_60": xp_cum[59], "xp_to_90": xp_cum[89], "profiles": t9_rows}

    print("\n[T10] Appendix R W15 catch-up Beta P1 gate (F2P-mid -> Ch4 by D30 >= 60%) & twist spread (AT-B08 <= 3%)")
    cu_res = simulate_f2p_mid_ch4_d30(bal, n_players=300 if quick else 1000, seed=101)
    print(
        "  W15 cohort (n=%d): enter Ch4 by D30 WITH catch-up = %5.1f%% (median %.0fd) | clear Ch4 by D30 WITH catch-up = %5.1f%% (median %.0fd) | WITHOUT catch-up: enter %5.1f%%, clear %5.1f%% (median %.0fd)"
        % (
            cu_res["n_players"],
            cu_res["reached_ch4_d30_with_catchup"] * 100,
            cu_res["median_days_enter_ch4_with_catchup"],
            cu_res["cleared_ch4_d30_with_catchup"] * 100,
            cu_res["median_days_clear_ch4_with_catchup"],
            cu_res["reached_ch4_d30_without_catchup"] * 100,
            cu_res["cleared_ch4_d30_without_catchup"] * 100,
            cu_res["median_days_clear_ch4_without_catchup"],
        )
    )
    twist_ttks = {}
    for tier in ("minor", "major"):
        vals = {}
        for tid in sorted(bal["twists"].keys()):
            sm_tw = summarize(bal, run_batch(bal, N // 2, squad_std, prof0, hp28, waves, "mid", 81, ref_hp_base, twist=(tid, tier)))
            vals[tid] = sm_tw["pairs"]
        lo_t, hi_t = min(vals.values()), max(vals.values())
        spread_pct = (hi_t - lo_t) / statistics.mean(vals.values()) * 100.0
        twist_ttks[tier] = {"ttks": {k: round(v, 2) for k, v in vals.items()}, "spread_pct": round(spread_pct, 2)}
        print(
            "  twists (%-5s) TTK min=%.2f max=%.2f spread=%.2f%% (gate <=3.00%%) | %s"
            % (tier, lo_t, hi_t, spread_pct, " ".join(f"{k}:{v:.2f}" for k, v in vals.items()))
        )
    out["t10"] = {"catchup": cu_res, "twists": twist_ttks}

    # Hypothesis gates check (T24: active only after beta calibration)
    gates = bal["gates"]
    win_p0 = t1["P0 F2P-max"]["mid"]["win"] * bp
    ttk_p0 = t1["P0 F2P-max"]["mid"]["pairs"]
    ult_sh = t7_shares[36] * bp
    gate_checks = {
        "win_p0_mid_normal": gates["win_p0_mid_normal_bp"][0] <= win_p0 <= gates["win_p0_mid_normal_bp"][1],
        "ttk_p0_mid_normal": gates["ttk_p0_mid_normal_pairs"][0] <= ttk_p0 <= gates["ttk_p0_mid_normal_pairs"][1],
        "ult_share_36": gates["ult_share_bp"][0] <= ult_sh <= gates["ult_share_bp"][1],
        "variant_a_parity": all(v["delta_atk_pct"] == 0.0 and v["delta_hp_pct"] == 0.0 for v in t1b.values()) if flags["variant"] == "A" else True,
        "w15_ch4_d30_ge_60": cu_res["reached_ch4_d30_with_catchup"] * bp >= int(bal["catchup"]["beta_p1_f2p_mid_ch4_d30_target_bp"]),
        "twist_spread_minor_le_3": twist_ttks["minor"]["spread_pct"] <= gates["twist_spread_max_bp"] / 100.0,
        "twist_spread_major_le_3": twist_ttks["major"]["spread_pct"] <= gates["twist_spread_max_bp"] / 100.0,
        "rules_publication_blocked": not bool(flags["publish_sim_numbers_in_rules"]),
    }
    out["gate_checks"] = gate_checks
    ok_n = sum(1 for v in gate_checks.values() if v)
    print(
        "\n[GATES] (HYPOTHESIS, calibrated=%s, publish_in_rules=%s) %d/%d PASS: %s"
        % (gates["calibrated"], gates["publish_in_rules"], ok_n, len(gate_checks),
           ", ".join(f"{k}={'OK' if v else 'FAIL'}" for k, v in gate_checks.items()))
    )

    if "--json" in sys.argv:
        path = sys.argv[sys.argv.index("--json") + 1]
        with open(path, "w", encoding="utf-8") as f:
            json.dump(out, f, ensure_ascii=False, indent=1, default=str)

    if check_gates and ok_n != len(gate_checks):
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
