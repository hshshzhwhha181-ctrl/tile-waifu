#!/usr/bin/env python3
"""
Tile Waifu: battle layer simulator (BATTLE_ULT_SPEC.md, sections 1.9 and 9).

Purpose: sanity check of TTK (time to kill), win rate, ult cadence and the power curve
between F2P-max, mid-spender and whale squads. It is a MODEL of the core formulas, not the
game: the real core must reproduce the same numbers in game/core/modes/battle (see 9.3).

Run:  python3 battle_sim.py            (prints all tables, ~20 s)
      python3 battle_sim.py --quick    (fewer runs)
      python3 battle_sim.py --json out.json
Only the Python standard library is used. Deterministic: fixed seeds.

Every constant below is mirrored in the spec tables with the same name (UPPER_CASE).
Numbers marked [ГИПОТЕЗА] in the spec are exactly the knobs the real playtest must replace.
"""
import json
import math
import random
import statistics
import sys

# --------------------------------------------------------------------------- constants (spec 1.4 .. 1.8)
LEVEL_STEP = 0.10            # stat(L) = base * (1 + LEVEL_STEP*(L-1))
LEVEL_CAP_LAUNCH = 60
COMBO_STEP = 0.25            # combo_mult = 1 + COMBO_STEP * min(c-1, COMBO_CAP)
COMBO_CAP = 6
FEVER_COMBO = 10             # combo >= 10 lights "Азарт"
FEVER_PAIRS = 6
FEVER_DMG = 1.30
FEVER_ENERGY = 1.50
RES_FULL = 1.0               # resonant heroine contributes fully to the pair strike
RES_OFF = 0.40               # non-resonant contributes 40 %
HONOR_PAIR = 0.70            # honor / flower pair: everybody contributes 70 % (wild "Дух")
ENERGY_PAIR = 2.4            # base energy per pair to every heroine
ENERGY_RES = 1.6             # resonance multiplier on energy
ENERGY_COMBO = 0.20          # + per combo step above 1 (cap COMBO_CAP)
ENERGY_START = 40            # start charge (every outfit, every mode; no rarity effect)
ULT_COST = 100
SHIELD_PAIR = 1.0            # shield damage units per pair
SHIELD_ULT = 4.0
BREAK_HITS = 3               # after break: next 3 hits (pair or ult) deal x BREAK_MULT
BREAK_MULT = 2.0
BREAK_STUN = 1               # boss skips its next cast
GESTURE_BONUS = {"one_suit": 0.20, "ladder": 0.35, "kan": 0.25, "pure": 0.80}   # spec 1.5 (gestures = "Жесты")
PAIR_RATE = {"casual": 9.0, "mid": 11.0, "expert": 13.5}   # pairs / minute [ГИПОТЕЗА]
COMBO_P = {"casual": 0.52, "mid": 0.68, "expert": 0.82}    # chance that the next pair continues the combo [ГИПОТЕЗА]
OVERFLOW_P = {"casual": 0.020, "mid": 0.010, "expert": 0.004}  # tray overflow chance per pair [ГИПОТЕЗА]
HEAL_PASSIVE = 0.003         # healer: % of team max HP per pair
HEAL_ULT = 0.25              # healer ult: % of team max HP
GUARD_ULT = 0.20             # guard ult: absorb % of team max HP
BOSS_ATK = 0.40              # one boss cast = % of team max HP (heavy x1.8)
OVERFLOW_DMG = 0.15          # of team max HP
BOSS_HEAVY_EVERY = 3         # every 3rd cast is heavy x1.8
BOSS_HEAVY = 1.8
WEAK_MULT = 1.25             # pair of the boss weak suit
RESIST_MULT = 0.85           # pair of the boss resisted suit

ROLES = {
    #        ATK  HP  energy gain mult
    "ATK":  (100, 80, 1.00),
    "BRK":  (85, 90, 1.00),
    "SUP":  (60, 100, 1.15),
    "HEAL": (50, 110, 1.00),
    "GRD":  (55, 130, 1.00),
}
AURAS = ("man", "pin", "sou")

# 10 launch heroines: role, aura (spec 1.3)
HEROES = {
    "hana":    ("ATK", "man"),
    "kohaku":  ("GRD", "man"),
    "zlata":   ("ATK", "man"),
    "yue":     ("ATK", "pin"),
    "nova":    ("BRK", "pin"),
    "shirin":  ("SUP", "pin"),
    "miel":    ("HEAL", "pin"),
    "tsubame": ("BRK", "sou"),
    "mc":      ("SUP", "sou"),
    "rin":     ("HEAL", "sou"),
}

# --------------------------------------------------------------------------- power profiles (spec 2.9)
# gear multiplier = (1 + talisman%) ; outfit and star bonuses are additive in "monetizable %" and capped
PROFILES = {
    # name: level, talisman ATK/HP %, skill level, outfit tiers on the squad (list of (tier, stars)), bond lvl
    "P0- F2P-mid":  dict(level=52, tal=0.18, skill=6,  outfits=[],                                   bond=8),
    "P0 F2P-max":   dict(level=60, tal=0.30, skill=8,  outfits=[],                                   bond=10),   # F2P at ~month 2
    "P0+ F2P-long": dict(level=60, tal=0.40, skill=10, outfits=[],                                   bond=10),   # F2P at month 6+
    "P1 small":     dict(level=60, tal=0.40, skill=10, outfits=[("S", 2), ("SSR", 1)],               bond=10),
    "P2 mid":       dict(level=60, tal=0.40, skill=10, outfits=[("SSR", 2), ("SSR", 2), ("S", 3)],   bond=10),
    "P3 whale":     dict(level=60, tal=0.43, skill=10, outfits=[("SSRP", 5), ("SSR", 5), ("SSR", 5), ("SSR", 5), ("S", 5)], bond=10),
}
OUTFIT_BASE = {"S": 0.04, "SSR": 0.08, "SSRP": 0.10}      # ATK % of the heroine who wears it (HP gets 60 % of it)
OUTFIT_STEP = {"S": 0.010, "SSR": 0.020, "SSRP": 0.025}    # per star above 0 (stars 0..5)
BOND_PER_LV = 0.005
COLLECTION_PER_OUTFIT = 0.0025  # account-wide "Альбом" bonus per owned S/SSR outfit, cap 0.06
COLLECTION_CAP = 0.06
MONETIZABLE_CAP = 0.28          # per-heroine hard cap of outfit + stars + album (ATK %), spec 2.8
SKILL_STEP = 0.06               # ult damage mult = 1 + SKILL_STEP*(skill-1)


def outfit_pct(outfits, collection_count):
    t = 0.0
    for tier, stars in outfits:
        t += OUTFIT_BASE[tier] + OUTFIT_STEP[tier] * stars
    t += min(COLLECTION_CAP, COLLECTION_PER_OUTFIT * collection_count)
    return min(t, MONETIZABLE_CAP)


def build_squad(names, prof, collection_count=0):
    sq = []
    out_total = outfit_pct(prof["outfits"], collection_count)
    # outfit % applies per heroine only if she wears one; sim: distribute the list over the squad in order
    per = [0.0] * len(names)
    for i, (tier, stars) in enumerate(prof["outfits"][:len(names)]):
        per[i] = OUTFIT_BASE[tier] + OUTFIT_STEP[tier] * stars
    coll = min(COLLECTION_CAP, COLLECTION_PER_OUTFIT * collection_count)
    for i, n in enumerate(names):
        role, aura = HEROES[n]
        atk0, hp0, enr = ROLES[role]
        lv = 1 + LEVEL_STEP * (prof["level"] - 1)
        bond = BOND_PER_LV * prof["bond"]
        mult_atk = (1 + prof["tal"]) * (1 + min(MONETIZABLE_CAP, per[i] + coll) + bond)
        mult_hp = (1 + prof["tal"] * 0.9) * (1 + min(MONETIZABLE_CAP, per[i] * 0.6 + coll) + bond)
        sq.append(dict(name=n, role=role, aura=aura, atk=atk0 * lv * mult_atk, hp=hp0 * lv * mult_hp,
                       enr=enr, energy=ENERGY_START, skill=prof["skill"]))
    return sq


# --------------------------------------------------------------------------- boss model (spec 1.7)
def boss_for(rp_atk_sum, pairs_budget, tail=0.82, shield_units=16, cadence=7, atk_pct=0.055):
    """boss HP so that a squad with TPP == rp reaches `tail` of the pair budget on average."""
    return dict(hp=None, shield_units=shield_units, cadence=cadence, atk_pct=atk_pct)


def team_pair_power(sq):
    """expected damage of one pair at combo 1, mid mix of suits (no gestures), used to size bosses."""
    tot = 0.0
    for suit in AURAS:
        s = sum(h["atk"] * (RES_FULL if h["aura"] == suit else RES_OFF) for h in sq)
        tot += s
    s_h = sum(h["atk"] * HONOR_PAIR for h in sq)
    # suit pairs 3 x 27 %, honor 19 %
    return (tot / 3.0) * 0.81 + s_h * 0.19


ULT_DMG = {"ATK": 9.0, "BRK": 5.5, "SUP": 3.0, "HEAL": 2.5, "GRD": 3.0}   # x ATK at skill 1


WAVES = (36, 24)             # pairs per wave (board redeal); wave 2 = "Ярость": boss ATK x(1+ENRAGE), cadence -2
ENRAGE = 0.80


def simulate(sq, boss_hp, pairs_budget, skill, rng, cadence=6, atk_pct=None, shield_units=16,
             auto_ults=True, return_log=False, suit_w=None, weak=None, resist=None, ref_hp=None):
    if atk_pct is None:
        atk_pct = BOSS_ATK
    team_max = sum(h["hp"] for h in sq)
    team_hp = team_max
    boss = boss_hp
    shield = shield_units
    broken = 0
    stun = 0
    clock = 0
    casts = 0
    combo = 0
    fever = 0
    buff_pairs = 0
    guard = 0.0
    pairs = 0
    ults = 0
    ud_tot = 0.0
    pd_tot = 0.0
    log_ults = []
    hist = []
    energy = [h["energy"] for h in sq]
    t_sec = 0.0
    rate = PAIR_RATE[skill] / 60.0
    if isinstance(pairs_budget, (tuple, list)):
        bounds = []
        acc = 0
        for w in pairs_budget:
            acc += w
            bounds.append(acc)
        total_budget = acc
    else:
        bounds = [pairs_budget]
        total_budget = pairs_budget
    wave = 0
    while pairs < total_budget and boss > 0 and team_hp > 0:
        if pairs in bounds[:-1]:
            wave = bounds.index(pairs) + 1
            combo = 0
        pairs += 1
        t_sec += 1.0 / rate
        # suit of the pair
        r = rng.random()
        if r < 0.81:
            if suit_w:
                suit = rng.choices(AURAS, weights=suit_w)[0]
            else:
                suit = rng.choice(AURAS)
        else:
            suit = "honor"
        hist.append(suit)
        # combo
        if rng.random() < COMBO_P[skill] and combo > 0:
            combo += 1
        else:
            combo = 1
        if combo >= FEVER_COMBO and fever == 0:
            fever = FEVER_PAIRS
        c = min(combo - 1, COMBO_CAP)
        cm = 1 + COMBO_STEP * c
        gest = 0.0
        if len(hist) >= 3 and hist[-1] == hist[-2] == hist[-3] and suit != "honor":
            gest = max(gest, GESTURE_BONUS["one_suit"])
        if rng.random() < 0.06:
            gest = max(gest, GESTURE_BONUS["ladder"])
        if rng.random() < 0.04:
            gest = max(gest, GESTURE_BONUS["kan"])
        if len(hist) >= 6 and len(set(hist[-6:])) == 1 and suit != "honor":
            gest = max(gest, GESTURE_BONUS["pure"])
        # strike
        if suit == "honor":
            raw = sum(h["atk"] * HONOR_PAIR for h in sq)
        else:
            raw = sum(h["atk"] * (RES_FULL if h["aura"] == suit else RES_OFF) for h in sq)
        raw *= 0.35   # normalisation: five heroines strike together; 0.35 keeps boss HP numbers readable
        dmg = raw * cm * (1 + gest)
        if weak and suit == weak:
            dmg *= WEAK_MULT
        if resist and suit == resist:
            dmg *= RESIST_MULT
        if fever > 0:
            dmg *= FEVER_DMG
        if buff_pairs > 0:
            dmg *= 1.25
            buff_pairs -= 1
        hit_mult = 1.0
        if broken > 0:
            hit_mult = BREAK_MULT
            broken -= 1
        boss -= dmg * hit_mult
        pd_tot += dmg * hit_mult
        # shield
        brk = 1.25 if any(h["role"] == "BRK" for h in sq) else 1.0
        shield -= SHIELD_PAIR * brk * (1.6 if fever > 0 else 1.0)
        if shield <= 0:
            broken = BREAK_HITS
            stun = BREAK_STUN
            shield = shield_units
        # energy
        for i, h in enumerate(sq):
            g = ENERGY_PAIR * h["enr"]
            if suit == "honor" or h["aura"] == suit:
                g *= ENERGY_RES if suit != "honor" else 1.2
            g += ENERGY_COMBO * c
            if fever > 0:
                g *= FEVER_ENERGY
            energy[i] += g
        if fever > 0:
            fever -= 1
        # ults (auto, one per pair max, highest energy first)
        if auto_ults:
            for i, h in enumerate(sq):
                if energy[i] >= ULT_COST and boss > 0:
                    energy[i] -= ULT_COST
                    ults += 1
                    sk = 1 + SKILL_STEP * (h["skill"] - 1)
                    ud = h["atk"] * ULT_DMG[h["role"]] * sk
                    hm = BREAK_MULT if broken > 0 else 1.0
                    if broken > 0:
                        broken -= 1
                    boss -= ud * hm
                    ud_tot += ud * hm
                    shield -= SHIELD_ULT * (1.5 if h["role"] == "BRK" else 1.0)
                    if shield <= 0:
                        broken = BREAK_HITS
                        stun = BREAK_STUN
                        shield = shield_units
                    if h["role"] == "SUP":
                        buff_pairs = 8
                        for j in range(len(sq)):
                            energy[j] += 20
                    elif h["role"] == "HEAL":
                        team_hp = min(team_max, team_hp + HEAL_ULT * team_max)
                    elif h["role"] == "GRD":
                        guard = GUARD_ULT * team_max
                    elif h["role"] == "BRK":
                        stun = max(stun, 1)
                    log_ults.append((pairs, h["name"]))
        # heal passives (healers: 0.6 % team max per pair x skill)
        for h in sq:
            if h["role"] == "HEAL":
                team_hp = min(team_max, team_hp + HEAL_PASSIVE * team_max)
        # boss clock
        clock += 1
        if clock >= max(3, cadence - 2 * wave) and boss > 0:
            clock = 0
            casts += 1
            if stun > 0:
                stun -= 1
            else:
                d = atk_pct * (ref_hp or team_max) * (1 + ENRAGE * wave)
                if casts % BOSS_HEAVY_EVERY == 0:
                    d *= BOSS_HEAVY
                if guard > 0:
                    ab = min(guard, d)
                    guard -= ab
                    d -= ab
                team_hp -= d
        # tray overflow
        if rng.random() < OVERFLOW_P[skill]:
            team_hp -= OVERFLOW_DMG * team_max
            combo = 0
    won = boss <= 0 and team_hp > 0
    return dict(won=won, pairs=pairs, waves=wave + 1, secs=t_sec, ult_dmg=ud_tot, pair_dmg=pd_tot, ults=ults, hp_left=max(0.0, team_hp / team_max),
                boss_left=max(0.0, boss))


# --------------------------------------------------------------------------- experiments
SQUAD_STD = ["hana", "nova", "mc", "rin", "kohaku"]          # one of each role, mixed auras (2 man, 1 pin, 2 sou)
DIFF = {"normal": (1.00, 1.00), "hard": (1.25, 1.10), "nightmare": (1.50, 1.25)}   # (boss HP x, boss ATK x)
REF_HP = None   # team max HP of the P0 squad: boss casts are ABSOLUTE numbers (they do not shrink when your HP grows)


def ref_hp():
    return sum(h["hp"] for h in build_squad(SQUAD_STD, PROFILES["P0 F2P-max"]))


def run(n, names, prof, boss_hp, budget, skill, seed, atk_mult=1.0, scale=1.0, **kw):
    rng = random.Random(seed)
    res = []
    for _ in range(n):
        sq = build_squad(names, prof)
        for h in sq:
            h["atk"] *= scale
            h["hp"] *= scale ** 0.5
        res.append(simulate(sq, boss_hp, budget, skill, rng, ref_hp=REF_HP * atk_mult, **kw))
    return res


def summarize(res):
    w = [r for r in res if r["won"]]
    three = [r for r in w if r["hp_left"] >= 0.5 and r["pairs"] <= 32]
    return dict(win=len(w) / len(res), three=len(three) / len(res),
                pairs=statistics.mean([r["pairs"] for r in w]) if w else float("nan"),
                secs=statistics.mean([r["secs"] for r in w]) if w else float("nan"),
                ults=statistics.mean([r["ults"] for r in res]),
                hp=statistics.mean([r["hp_left"] for r in w]) if w else float("nan"))


def calibrate(target_pairs=28):
    prof0 = PROFILES["P0 F2P-max"]
    lo, hi = 1000.0, 800000.0
    for _ in range(40):
        mid = (lo + hi) / 2
        rs = run(150, SQUAD_STD, prof0, mid, WAVES, "mid", 11)
        avg = statistics.mean([r["pairs"] for r in rs if r["won"]] or [999])
        if avg > target_pairs:
            hi = mid
        else:
            lo = mid
    return (lo + hi) / 2


def main():
    global REF_HP
    quick = "--quick" in sys.argv
    N = 300 if quick else 1500
    out = {}
    REF_HP = ref_hp()
    prof0 = PROFILES["P0 F2P-max"]
    hp28 = calibrate()
    tpp0 = team_pair_power(build_squad(SQUAD_STD, prof0)) * 0.35
    out["constants"] = dict(ref_team_hp=round(REF_HP), boss_hp_normal=round(hp28), tpp_p0=round(tpp0, 1),
                            K_normal=round(hp28 / tpp0, 2))
    print("[CAL] P0 squad: team HP %.0f, pair power (combo 1) %.1f. Boss HP %.0f gives 28 pairs (mid skill).  K_normal = HP / TPP = %.1f"
          % (REF_HP, tpp0, hp28, hp28 / tpp0))

    print("\n[T1] profile x skill on the calibrated NORMAL stage (waves 36+24 pairs): win / 3-star / pairs / sec / ults / HP left")
    t1 = {}
    for pn, prof in PROFILES.items():
        row = {}
        for sk in ("casual", "mid", "expert"):
            row[sk] = summarize(run(N, SQUAD_STD, prof, hp28, WAVES, sk, 21))
        t1[pn] = row
        print("  %-12s" % pn + " | ".join("%s win %3.0f%% 3* %3.0f%% %4.1fp %3.0fs u%.1f hp%3.0f%%" % (
            sk[:3], row[sk]["win"] * 100, row[sk]["three"] * 100, row[sk]["pairs"], row[sk]["secs"], row[sk]["ults"], row[sk]["hp"] * 100) for sk in row))
    out["t1"] = t1

    print("\n[T2] campaign curve (60 launch stages): level cap per chapter, recommended pair power RP, boss HP = RP * K_normal * stage factor")
    t2 = []
    for stage in range(1, 61):
        ch = (stage - 1) // 10 + 1
        k = (stage - 1) % 10 + 1
        lvl_cap = min(60, 10 + 7 * ch)
        lv = lvl_cap if k >= 3 else lvl_cap - 3
        tal = min(0.30, 0.04 * ch + 0.02 * k / 10)
        sk = min(8, 1 + ch + (1 if k >= 6 else 0))
        prof = dict(level=lv, tal=tal, skill=sk, outfits=[], bond=min(10, 2 + ch))
        sq = build_squad(SQUAD_STD, prof)
        rp = team_pair_power(sq) * 0.35
        factor = {10: 1.35, 5: 1.12}.get(k, 1.0)
        rhp = sum(h["hp"] for h in sq)
        t2.append(dict(stage=stage, chapter=ch, level_cap=lvl_cap, level=lv, rp=round(rp, 1), boss_hp=round(rp * (hp28 / tpp0) * factor), factor=factor,
                       ref_team_hp=round(rhp), boss_cast=round(BOSS_ATK * rhp)))
    for r in t2:
        if r["stage"] in (1, 5, 10, 11, 20, 30, 40, 50, 60):
            print("  stage %2d ch %d L%2d (cap L%2d)  RP %6.1f  boss HP %7d (x%.2f)  ref team HP %5d  boss cast %5d" % (r["stage"], r["chapter"], r["level"], r["level_cap"], r["rp"], r["boss_hp"], r["factor"], r["ref_team_hp"], r["boss_cast"]))
    out["t2"] = t2

    print("\n[T3] win / 3-star vs power ratio (own pair power / recommended), mid skill, normal stage")
    t3 = []
    for ratio in (0.60, 0.70, 0.80, 0.90, 1.00, 1.10, 1.20, 1.30, 1.40):
        s_ = summarize(run(N, SQUAD_STD, prof0, hp28, WAVES, "mid", 31, scale=ratio))
        t3.append(dict(ratio=ratio, **s_))
        print("  ratio %.2f  win %5.1f%%  3* %5.1f%%  TTK %4.1f pairs (%3.0f s)  ults %.1f  HP left %3.0f%%" % (ratio, s_["win"] * 100, s_["three"] * 100, s_["pairs"], s_["secs"], s_["ults"], s_["hp"] * 100))
    out["t3"] = t3

    print("\n[T4] raid score = damage dealt in a fixed 60-pair run (boss HP infinite), mid skill; relative to F2P-max")
    t4 = {}
    for pn, prof in PROFILES.items():
        rng = random.Random(41)
        dm = []
        for _ in range(N // 3):
            sq = build_squad(SQUAD_STD, prof, collection_count=12 if "whale" in pn else (6 if "mid" in pn.lower() else 3))
            r = simulate(sq, 1e12, (36, 24), "mid", rng, ref_hp=REF_HP)
            dm.append(1e12 - r["boss_left"])
        t4[pn] = statistics.mean(dm)
    base = t4["P0 F2P-max"]
    base2 = t4["P0+ F2P-long"]
    for pn, v in t4.items():
        print("  %-13s score %9.0f  (x%.2f of P0, x%.2f of P0+)" % (pn, v, v / base, v / base2))
    out["t4"] = {k: [round(v / base, 3), round(v / base2, 3)] for k, v in t4.items()}

    print("\n[T5] skill vs wallet: win rate by difficulty (boss HP/ATK multipliers %s)" % DIFF)
    t5 = {}
    for label, (hm, am) in DIFF.items():
        for pn in ("P0- F2P-mid", "P0 F2P-max", "P3 whale"):
            for sk in ("casual", "mid", "expert"):
                sm = summarize(run(N // 2, SQUAD_STD, PROFILES[pn], hp28 * hm, WAVES, sk, 51, atk_mult=am))
                t5["%s|%s|%s" % (label, pn, sk)] = sm["win"]
        print("  %-9s " % label + " | ".join("%s %s %3.0f%%" % (pn.split()[0], sk[:3], t5["%s|%s|%s" % (label, pn, sk)] * 100)
              for pn in ("P0- F2P-mid", "P0 F2P-max", "P3 whale") for sk in ("casual", "mid", "expert")))
    out["t5"] = t5

    print("\n[T6] aura: stage suit tilt 50/25/25 (man heavy), boss weak = man x1.25, resists = pin x0.85; same roles/stats, auras re-assigned")
    def with_auras(names, auras):
        sq = build_squad(names, prof0)
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
        rs = [simulate(with_auras(SQUAD_STD, auras), hp28, WAVES, "mid", rng, ref_hp=REF_HP, suit_w=[0.5, 0.25, 0.25], weak="man", resist="pin") for _ in range(N)]
        sm = summarize(rs)
        out["t6"][nm] = sm
        print("  %-36s TTK %.1f pairs  win %.0f%%  3* %.0f%%" % (nm, sm["pairs"], sm["win"] * 100, sm["three"] * 100))
    rng = random.Random(61)
    sm = summarize([simulate(build_squad(SQUAD_STD, prof0), hp28, WAVES, "mid", rng, ref_hp=REF_HP) for _ in range(N)])
    print("  %-36s TTK %.1f pairs  (reference: neutral stage, no tilt)" % ("neutral stage", sm["pairs"]))

    print("\n[T7] ult cadence and share of ult damage (P0, mid skill, 5 heroines)")
    for bud in ((36,), (36, 24), (36, 36, 36)):
        rs = [simulate(build_squad(SQUAD_STD, prof0), 1e12, bud, "mid", random.Random(71 + i), ref_hp=REF_HP, atk_pct=0.0) for i in range(N // 3)]
        u = statistics.mean([r["ults"] for r in rs])
        tot = sum(bud)
        share = statistics.mean([r["ult_dmg"] / max(1.0, r["ult_dmg"] + r["pair_dmg"]) for r in rs])
        print("  %3d pairs: %.1f ults per fight -> one ult every %.1f pairs (%.0f s); ult share of damage %.0f%%" % (tot, u, tot / max(u, 0.01), tot / max(u, 0.01) / PAIR_RATE["mid"] * 60, share * 100))
        out["t7_%d" % tot] = round(u, 2)

    print("\n[T8] spend ladder: per-heroine ATK bonus and effect on the team (squad = std, bonus on the heroines listed), capped by MONETIZABLE_CAP = %.0f percent" % (MONETIZABLE_CAP * 100))
    ladder = (
        ("nothing",                                   [],                                               0,  0),
        ("1 S *2 on Hana",                            [("hana", "S", 2)],                               2,  599 + 49),
        ("1 SSR *1 on Hana",                          [("hana", "SSR", 1)],                             2,  1490),
        ("1 SSR *5 on Hana",                          [("hana", "SSR", 5)],                             2,  1490 + 446),
        ("SSR *5 on Hana + Nova + Mc",                [("hana", "SSR", 5), ("nova", "SSR", 5), ("mc", "SSR", 5)], 6, 3 * (1490 + 446)),
        ("1 SSR+ + 4 SSR *5 on the whole squad",          [("hana", "SSRP", 5), ("nova", "SSR", 5), ("mc", "SSR", 5), ("rin", "SSR", 5), ("kohaku", "SSR", 5)], 12, (2490 + 446) + 4 * (1490 + 446)),
    )
    sq_ref = build_squad(SQUAD_STD, PROFILES["P0+ F2P-long"])
    tot_atk = sum(h["atk"] for h in sq_ref)
    for nm, lst, coll, rub in ladder:
        gain = 0.0
        shown = []
        album = min(COLLECTION_CAP, COLLECTION_PER_OUTFIT * coll)
        for h in sq_ref:
            pct = 0.0
            for who, tier, st in lst:
                if who == h["name"]:
                    pct = OUTFIT_BASE[tier] + OUTFIT_STEP[tier] * st
            pct = min(MONETIZABLE_CAP, pct + album)
            gain += h["atk"] * pct
            if pct > album:
                shown.append("%s +%.0f%%" % (h["name"], pct * 100))
        print("  %-38s album +%.1f%%  %-34s team ATK +%4.1f%%  direct price ~%6d RUB" % (nm, album * 100, ", ".join(shown) or "-", gain / tot_atk * 100, rub))

    print("\n[T9] progression time: XP to level, days to cap by income profile (spec 2.2 / 2.10)")
    xp = lambda L: round(18 * L ** 1.5)
    cum = {}
    acc = 0
    for L in range(1, 91):
        acc += xp(L)
        cum[L + 1] = acc
    for cap in (20, 40, 60, 70, 80, 90):
        print("  Lv1 -> Lv%-2d  cumulative XP %9d" % (cap, cum[cap]))
    for nm, per_day in (("active (6 vault runs + drops)", 22000), ("light (3 runs)", 9000), ("whale (active + 3 packs/week)", 22000 + 3 * 40000 / 7)):
        print("  %-32s one heroine Lv60: %5.1f days;  squad of 5: %5.1f days" % (nm, cum[60] / per_day, 5 * cum[60] / per_day))
    out["t9"] = {"xp_to_60": cum[60], "xp_to_90": cum[90]}

    if "--json" in sys.argv:
        path = sys.argv[sys.argv.index("--json") + 1]
        with open(path, "w", encoding="utf-8") as f:
            json.dump(out, f, ensure_ascii=False, indent=1, default=str)


if __name__ == "__main__":
    main()
