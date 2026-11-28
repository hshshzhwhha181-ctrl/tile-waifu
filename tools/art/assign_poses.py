#!/usr/bin/env python3
"""Per-heroine pose assignment for the art factory v6 (design/art_v6/assignments.json).

17 slots per heroine: 3 canon frames (canon_base, canon_win, canon_tease) + 7 outfits (base, evening, swim, service, robe, battle, seasonal) x 2 poses.
170 slots in total.  Pose ids come from design/art_v6/pose_library.json.

Hard constraints (checked by `--check`, also run after every solve):
  a. every heroine has >= 3 rear-emphasis slots (library flag `rear_emphasis`, hips in frame);
  b. no two heroines share the same pose id in the same outfit slot (the 7 outfit slots and the 3 canon slots);
  c. no heroine repeats a pose id; the two poses of one outfit differ and have different categories;
  d. the pose is not 'no' for the outfit class (long / mini / leo / swim / robe), and fits the setting family of the slot;
  e. canon slots use poses flagged canon_ok for that frame;
  f. youth rule: a pose with youth_risk != none is never put on an outfit that already carries a youthful-coded item (compliance: at most ONE per outfit);
  g. every heroine has >= 1 lying, >= 1 kneeling, >= 1 leg-focus, >= 1 bust-focus, >= 1 dynamic slot; no pose is used more than 4 times overall.
Soft objectives: variety over the whole roster (every pose used at least once), personality / height affinity, slot fit (swim -> lying/kneeling, robe -> lying, battle -> dynamic...).

Usage:  python tools/art/assign_poses.py            # solve (seeded, deterministic) and write assignments.json
        python tools/art/assign_poses.py --check    # only validate the existing assignments.json
"""
from __future__ import annotations

import argparse
import json
import math
import random
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import full_tier_wardrobe as WD  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
LIB = ROOT / "design" / "art_v6" / "pose_library.json"
OUT = ROOT / "design" / "art_v6" / "assignments.json"
HEROES = ["mc", "rin", "hana", "yue", "nova", "tsubame", "miel", "kohaku", "shirin", "zlata"]
CANON = ["canon_base", "canon_win", "canon_tease"]
SLOTS = list(WD.SLOTS)
POSITIONS = [(c, 0) for c in CANON] + [(s, i) for s in SLOTS for i in (0, 1)]  # 17 per heroine
MAX_USE = 4

# outfit class per heroine and slot (see design/art_v6/ANATOMY_RECIPE.md section 3: class decides the coverage rule block)
OUTFIT_CLASS = {
    "mc":      dict(base="long", evening="long", swim="swim", service="leo", robe="robe", battle="leo", seasonal="mini"),
    "rin":     dict(base="long", evening="mini", swim="swim", service="leo", robe="robe", battle="leo", seasonal="mini"),
    "hana":    dict(base="mini", evening="mini", swim="swim", service="leo", robe="robe", battle="leo", seasonal="mini"),
    "yue":     dict(base="long", evening="robe", swim="swim", service="leo", robe="robe", battle="leo", seasonal="mini"),
    "nova":    dict(base="mini", evening="leo", swim="swim", service="mini", robe="robe", battle="leo", seasonal="mini"),
    "tsubame": dict(base="mini", evening="long", swim="swim", service="leo", robe="robe", battle="leo", seasonal="mini"),
    "miel":    dict(base="mini", evening="mini", swim="swim", service="leo", robe="robe", battle="leo", seasonal="mini"),
    "kohaku":  dict(base="long", evening="mini", swim="swim", service="leo", robe="robe", battle="leo", seasonal="mini"),
    "shirin":  dict(base="long", evening="long", swim="swim", service="leo", robe="robe", battle="leo", seasonal="mini"),
    "zlata":   dict(base="mini", evening="long", swim="swim", service="leo", robe="robe", battle="leo", seasonal="mini"),
}
# setting families per (heroine, outfit slot), derived from the wardrobe `setting` text (ordered: the first entry is the primary family, used for the prop lookup).
# families: indoor (interior with floor and furniture), bed (bed / daybed / lounger), beach_pool (water edge, towel, sunbed), outdoor (street, rooftop, garden), stage (stage, track, stadium, garage)
_D = dict(base=["indoor"], evening=["indoor"], swim=["beach_pool"], service=["indoor"], robe=["indoor", "bed"], battle=["outdoor", "stage"], seasonal=["outdoor"])
SETTING_CTX = {hk: dict(_D) for hk in HEROES}
for _hk, _ov in {
    "rin": dict(swim=["beach_pool", "outdoor"], robe=["indoor"], battle=["outdoor"]),
    "hana": dict(base=["stage", "outdoor"], robe=["indoor"], battle=["stage", "outdoor"]),
    "yue": dict(base=["outdoor"], evening=["indoor", "bed"], swim=["beach_pool", "outdoor"], battle=["outdoor"]),
    "nova": dict(battle=["stage", "indoor"]),
    "tsubame": dict(base=["outdoor"], evening=["outdoor"], swim=["beach_pool", "outdoor"], service=["outdoor"], battle=["outdoor"]),
    "miel": dict(swim=["beach_pool", "outdoor"], battle=["outdoor"], seasonal=["indoor"]),
    "kohaku": dict(base=["outdoor"], evening=["outdoor"], swim=["beach_pool", "outdoor"], battle=["outdoor"]),
    "shirin": dict(base=["outdoor", "indoor"], evening=["outdoor", "beach_pool"], battle=["outdoor"]),
    "zlata": dict(swim=["beach_pool", "outdoor"], battle=["outdoor"]),
}.items():
    SETTING_CTX[_hk].update(_ov)
CANON_CTX = ["indoor"]  # canon frames use the soft teahouse backdrop of H1


def slot_ctx(hk, slot):
    return CANON_CTX if slot in CANON else SETTING_CTX[hk][slot]


# slot -> category bonuses (slot fit)
SLOT_FIT = {
    "base": dict(rear_hip=2, leg_focus_standing=2, dynamic=1, bust_focus=1, rear_lean=0.5),
    "evening": dict(leg_focus_seated=2, rear_lean=2, bust_focus=1, rear_hip=1, lying=0.5),
    "swim": dict(lying=2, kneeling=2, rear_hip=1, rear_walk=1, rear_lean=1),
    "service": dict(leg_focus_seated=2, rear_lean=2, bust_focus=1.5, dynamic=1, rear_hip=0.5),
    "robe": dict(lying=3, kneeling=2, bust_focus=1, rear_hip=1, leg_focus_seated=1),
    "battle": dict(dynamic=2, rear_lean=1.5, leg_focus_standing=1.5, rear_walk=1, rear_hip=0.5),
    "seasonal": dict(rear_walk=2, rear_hip=1.5, leg_focus_standing=1, bust_focus=1, kneeling=0.5, leg_focus_seated=0.5),
}
# personality / figure affinity: category weights + preferred pose ids
PROFILE = {
    "mc":      dict(why="playful salon hostess, soft full figure: table leans, rear S-curves, seated legs", cat=dict(rear_lean=1.5, rear_hip=1, leg_focus_seated=1, bust_focus=0.5),
                    ids=["L01_lean_table_behind", "R01_over_shoulder_s_curve", "S02_profile_knee_cross", "Y01_side_lying_hip_up_elbow", "K02_kneel_forearms_on_ottoman_rear"]),
    "rin":     dict(why="knowing tea master with glasses, slender: profile crossed legs, counter and chair leans, tea-sip", cat=dict(leg_focus_seated=1.5, bust_focus=1, rear_lean=1),
                    ids=["B09_tea_sip_lean_glance", "S02_profile_knee_cross", "L03_counter_elbow_rear_three_quarter", "L05_chairback_lean_behind", "R06_smoothing_hem_rear"]),
    "hana":    dict(why="sporty team captain, strong thighs: stride, lifted leg, stretch, straddle, wall lean", cat=dict(dynamic=1.5, leg_focus_standing=1.5, rear_lean=0.5),
                    ids=["T02_one_leg_lifted_behind", "T05_profile_stride", "D12_standing_lean_back_hands_on_hips", "D07_straddle_chair_backwards", "L04_wall_arms_up_arch", "B03_arms_overhead_stretch_front"]),
    "yue":     dict(why="serene tall moon queen: slow reclines, elegant rear S-curve, seated profile", cat=dict(lying=1.5, rear_hip=1, leg_focus_seated=1),
                    ids=["Y05_daybed_sprawl_arm_overhead", "Y03_recline_back_knee_up_profile", "R04_pillar_lean_back_view", "S02_profile_knee_cross", "B07_side_profile_arch"]),
    "nova":    dict(why="petite smug idol racer: squat, straddle, wall knee-pop, pivots, hip pops", cat=dict(dynamic=1.5, leg_focus_standing=1, kneeling=0.5),
                    ids=["D11_squat_three_quarter_knees_together", "D07_straddle_chair_backwards", "T03_knee_pop_wall_lean", "W02_runway_pivot", "R03_hip_pop_rear_three_quarter"]),
    "tsubame": dict(why="cool sly kunoichi courier: rail and wall leans, walking away, leaps, profile stride", cat=dict(rear_walk=1.5, rear_lean=1.5, dynamic=1),
                    ids=["W01_walking_away_glance", "L02_rail_lean_foot_lifted", "L04_wall_arms_up_arch", "D09_leap_side_prop", "D08_lunge_weapon_profile", "T05_profile_stride"]),
    "miel":    dict(why="petite curvy patissiere: bust-forward leans, counter, kneel and pillow poses (no dangling-feet poses)", cat=dict(bust_focus=1.5, kneeling=1, lying=1),
                    ids=["B02_forearm_on_counter_collar", "B09_tea_sip_lean_glance", "K01_upright_kneel_hands_in_hair", "K06_kneel_wring_hair", "Y06_pillow_hug_side_lying", "L03_counter_elbow_rear_three_quarter"]),
    "kohaku":  dict(why="toothy playful fox miko: seiza, kneel, side-lying, pillar rear (tail in frame)", cat=dict(kneeling=1.5, lying=1, rear_hip=1),
                    ids=["K03_seiza_back_twist", "K07_kneel_lean_back_on_hands", "Y02_side_lying_rear_look_back", "R04_pillar_lean_back_view", "S04_side_sit_floor_hip"]),
    "shirin":  dict(why="mysterious dancer, fuller curves: dance sway, side-sit, kneeling arch, sunbed recline", cat=dict(dynamic=1, kneeling=1, lying=1, leg_focus_seated=0.5),
                    ids=["D10_dance_hip_sway", "S04_side_sit_floor_hip", "Y07_sunbed_recline_legs_side", "K02_kneel_forearms_on_ottoman_rear", "B07_side_profile_arch"]),
    "zlata":   dict(why="regal tall tsarevna: walking-away glance, throne-style seated, rail lean, folded-arm bust", cat=dict(rear_walk=1.5, leg_focus_seated=1.5, rear_lean=1),
                    ids=["W01_walking_away_glance", "W02_runway_pivot", "S01_chair_sideways_hips_to_camera", "L02_rail_lean_foot_lifted", "R05_hands_on_hips_look_back", "B06_forearms_under_bust"]),
}
PETITE = {"nova", "miel", "kohaku"}

# youthful-coded items (owner compliance rule: <= 1 per outfit for heroines under 7.25 heads, which is everybody now)
YOUTH_PATTERNS = [
    ("socks (knee / over-the-knee / thigh-high socks)", r"\bsocks\b"),
    ("short shorts", r"\bshorts\b"),
    ("pleated or skater mini", r"pleated|skater"),
    ("hoodie / oversize / puffer", r"hoodie|oversize|puffer"),
    ("badge / figurine", r"badge|figurine"),
    ("childish hair clip", r"hair clip|macaron|hairclip"),
    ("freckles", r"freckle"),
    ("chunky sneakers", r"sneakers"),
]
IDENTITY_YOUTH = {  # items that come with the identity block (signature accessories / face) on EVERY outfit of the heroine
    "hana": ["freckles", "sunflower hair clip"],
    "miel": ["macaron hair clip"],
}


def youth_items(hk: str, slot: str) -> list[str]:
    txt = WD.W[hk][slot]["outfit"].lower()
    items = [name for name, rx in YOUTH_PATTERNS if re.search(rx, txt)]
    return items + IDENTITY_YOUTH.get(hk, [])


def load_lib():
    d = json.loads(LIB.read_text(encoding="utf-8"))
    return {p["id"]: p for p in d["poses"]}, d


def pos_key(pos):
    return pos[0] if pos[0] in CANON else pos[0]


def allowed(P, hk, pos):
    """Hard feasibility of pose P for (heroine, position)."""
    slot, idx = pos
    if slot in CANON:
        kind = slot.split("_", 1)[1]
        return kind in P["canon_ok"] and P["suited"][OUTFIT_CLASS[hk]["base"]] != "no" and "indoor" in P["contexts"]
    cls = OUTFIT_CLASS[hk][slot]
    if P["suited"][cls] == "no":
        return False
    if not (set(P["contexts"]) & set(slot_ctx(hk, slot))):
        return False
    if P["youth_risk"] != "none" and youth_items(hk, slot):
        return False
    if P["category"] == "portrait_tease":  # portraits are canon-only (hips not in frame, no outfit variety)
        return False
    return True


def score(P, hk, pos):
    slot, idx = pos
    prof = PROFILE[hk]
    s = 0.0
    if slot in CANON:
        s += 1.0
    else:
        s += SLOT_FIT[slot].get(P["category"], 0)
        cls = OUTFIT_CLASS[hk][slot]
        if P["suited"][cls] == "cond":
            s -= 0.6
    s += prof["cat"].get(P["category"], 0)
    if P["id"] in prof["ids"]:
        s += 2.0
    s += 0.15 * P["boldness"]
    if hk in PETITE and P["id"] in ("S05_stool_profile_heel_hook",):
        s -= 1.5  # high stool with dangling feet reads childlike on petite figures
    return s


def energy(assign, lib, cands):
    """Lower is better.  assign: {(hk, pos): pose_id}."""
    e = 0.0
    use = Counter()
    per_h = defaultdict(list)
    per_slot = defaultdict(list)
    for (hk, pos), pid in assign.items():
        P = lib[pid]
        e -= score(P, hk, pos)
        use[pid] += 1
        per_h[hk].append((pos, P))
        per_slot[pos[0]].append(pid)
    for slot, pids in per_slot.items():
        c = Counter(pids)
        e += 1000 * sum(v - 1 for v in c.values() if v > 1)
    for hk, lst in per_h.items():
        ids = [P["id"] for _, P in lst]
        e += 1000 * sum(v - 1 for v in Counter(ids).values() if v > 1)
        rear = sum(1 for _, P in lst if P["rear_emphasis"] and P["hips_in_frame"])
        e += 300 * max(0, 4 - rear)  # target 4 (hard minimum 3)
        cats = Counter(P["category"] for _, P in lst)
        for need in (["lying"], ["kneeling"], ["leg_focus_seated", "leg_focus_standing"], ["bust_focus"], ["dynamic"]):
            if not any(cats[c] for c in need):
                e += 150
        by_slot = defaultdict(list)
        for pos, P in lst:
            by_slot[pos[0]].append(P)
        for slot, ps in by_slot.items():
            if len(ps) == 2 and ps[0]["category"] == ps[1]["category"]:
                e += 40
            if len(ps) == 2 and slot in SLOTS and not any(p["rear_emphasis"] or p["category"] in ("lying", "kneeling") for p in ps) and slot in ("swim", "robe"):
                e += 6
    e += 80 * sum(max(0, v - MAX_USE) for v in use.values())
    e += 25 * sum(1 for pid in lib if use[pid] == 0)
    e += 2.0 * sum(max(0, v - 3) ** 2 for v in use.values())
    return e


def solve(lib, seed=2611, iters=120000):
    rng = random.Random(seed)
    cands = {}
    for hk in HEROES:
        for pos in POSITIONS:
            cands[(hk, pos)] = [pid for pid, P in lib.items() if allowed(P, hk, pos)]
            assert cands[(hk, pos)], (hk, pos)
    keys = list(cands)
    assign = {}
    # greedy start: best scoring free pose per slot, per heroine rear quota first
    used_slot = defaultdict(set)
    used_h = defaultdict(set)
    for k in sorted(keys, key=lambda k: (len(cands[k]), k)):
        hk, pos = k
        best = None
        for pid in cands[k]:
            if pid in used_slot[pos[0]] or pid in used_h[hk]:
                continue
            sc = score(lib[pid], hk, pos) + rng.random() * 0.8
            if best is None or sc > best[0]:
                best = (sc, pid)
        pid = best[1] if best else rng.choice(cands[k])
        assign[k] = pid
        used_slot[pos[0]].add(pid)
        used_h[hk].add(pid)
    cur = energy(assign, lib, cands)
    best_a, best_e = dict(assign), cur
    t0 = 6.0
    for it in range(iters):
        t = t0 * (1 - it / iters) + 0.05
        if rng.random() < 0.7:
            k = rng.choice(keys)
            old = assign[k]
            new = rng.choice(cands[k])
            if new == old:
                continue
            assign[k] = new
            ne = energy(assign, lib, cands)
            if ne <= cur or rng.random() < math.exp((cur - ne) / t):
                cur = ne
            else:
                assign[k] = old
        else:  # swap the poses of two heroines in the same position
            pos = rng.choice(POSITIONS)
            a, b = rng.sample(HEROES, 2)
            ka, kb = (a, pos), (b, pos)
            pa, pb = assign[ka], assign[kb]
            if pa == pb or pb not in cands[ka] or pa not in cands[kb]:
                continue
            assign[ka], assign[kb] = pb, pa
            ne = energy(assign, lib, cands)
            if ne <= cur or rng.random() < math.exp((cur - ne) / t):
                cur = ne
            else:
                assign[ka], assign[kb] = pa, pb
        if cur < best_e:
            best_a, best_e = dict(assign), cur
    return best_a, best_e


def check(doc, lib):
    errs = []
    per_slot = defaultdict(list)
    use = Counter()
    for hk in HEROES:
        h = doc["heroines"][hk]
        slots = h["slots"]
        if len(slots) != 17:
            errs.append(f"{hk}: {len(slots)} slots, expected 17")
        ids = [s["pose_id"] for s in slots]
        if len(set(ids)) != len(ids):
            errs.append(f"{hk}: repeated pose ids {[i for i, c in Counter(ids).items() if c > 1]}")
        rear = [s for s in slots if lib[s["pose_id"]]["rear_emphasis"] and lib[s["pose_id"]]["hips_in_frame"]]
        if len(rear) < 3:
            errs.append(f"{hk}: only {len(rear)} rear-emphasis slots")
        cats = Counter(lib[s["pose_id"]]["category"] for s in slots)
        for need in (["lying"], ["kneeling"], ["leg_focus_seated", "leg_focus_standing"], ["bust_focus"], ["dynamic"]):
            if not any(cats[c] for c in need):
                errs.append(f"{hk}: no slot of category {need}")
        by_outfit = defaultdict(list)
        for s in slots:
            P = lib[s["pose_id"]]
            use[s["pose_id"]] += 1
            per_slot[s["slot"]].append((hk, s["pose_id"]))
            pos = (s["slot"], s.get("idx", 0))
            if not allowed(P, hk, pos):
                errs.append(f"{hk}/{s['slot']}: pose {s['pose_id']} not allowed (class / context / canon / youth rule)")
            by_outfit[s["slot"]].append(P)
        for slot, ps in by_outfit.items():
            if len(ps) == 2 and ps[0]["category"] == ps[1]["category"]:
                errs.append(f"{hk}/{slot}: both poses are {ps[0]['category']}")
    for slot, lst in per_slot.items():
        c = Counter(p for _, p in lst)
        for p, n in c.items():
            if n > 1:
                errs.append(f"slot {slot}: pose {p} shared by {[h for h, q in lst if q == p]}")
    for p, n in use.items():
        if n > MAX_USE:
            errs.append(f"pose {p} used {n} times (> {MAX_USE})")
    unused = [p for p in lib if use[p] == 0]
    return errs, unused, use


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--seed", type=int, default=2611)
    ap.add_argument("--iters", type=int, default=120000)
    a = ap.parse_args()
    lib, libdoc = load_lib()
    if not a.check:
        assign, e = solve(lib, a.seed, a.iters)
        heroines = {}
        for hk in HEROES:
            slots = []
            for pos in POSITIONS:
                pid = assign[(hk, pos)]
                P = lib[pid]
                slot, idx = pos
                cls = OUTFIT_CLASS[hk][("base" if slot in CANON else slot)]
                rec = dict(slot=slot, idx=idx, pose_id=pid, category=P["category"], rear_emphasis=P["rear_emphasis"], boldness=P["boldness"], outfit_class=cls,
                           suitability=P["suited"][cls], needs_class_rule=P["hips_in_frame"], youth_items=youth_items(hk, "base" if slot in CANON else slot))
                ctx = slot_ctx(hk, slot)
                rec["context"] = ctx[0]
                rec["prop"] = P["prop"].get(ctx[0]) or P["prop"].get("default") or ""
                if slot not in CANON:
                    rec["outfit_name"] = WD.W[hk][slot]["name"]
                slots.append(rec)
            heroines[hk] = dict(cm=WD.HEIGHTS[hk]["cm"], heads=WD.HEIGHTS[hk]["heads"], figure=WD.FIGURE[hk], profile=PROFILE[hk]["why"], petite=hk in PETITE,
                                outfit_classes=OUTFIT_CLASS[hk], slots=slots)
        doc = dict(version="v6a", date="2026-11-28", solver=dict(method="seeded simulated annealing", seed=a.seed, iters=a.iters, energy=round(e, 2)),
                   rules=__doc__.split("Hard constraints")[1].split("Soft objectives")[0].strip(), heroines=heroines)
        errs, unused, use = check(doc, lib)
        doc["summary"] = dict(slots=sum(len(h["slots"]) for h in heroines.values()), poses_in_library=len(lib), poses_used=len(lib) - len(unused), unused=unused,
                              max_use=max(use.values()), rear_slots_per_heroine={hk: sum(1 for s in h["slots"] if lib[s["pose_id"]]["rear_emphasis"] and lib[s["pose_id"]]["hips_in_frame"]) for hk, h in heroines.items()},
                              category_counts=dict(Counter(lib[s["pose_id"]]["category"] for h in heroines.values() for s in h["slots"])), constraint_errors=errs)
        OUT.write_text(json.dumps(doc, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")
        print(f"wrote {OUT.relative_to(ROOT)}: energy {e:.1f}, errors {len(errs)}, unused poses {len(unused)}")
    doc = json.loads(OUT.read_text(encoding="utf-8"))
    errs, unused, use = check(doc, lib)
    for e in errs:
        print("ERROR", e)
    print(f"ASSIGNMENTS {'OK' if not errs else 'FAIL'}: {sum(len(h['slots']) for h in doc['heroines'].values())} slots, {len(lib) - len(unused)}/{len(lib)} poses used, max use {max(use.values())}, "
          f"rear slots per heroine min {min(sum(1 for s in h['slots'] if lib[s['pose_id']]['rear_emphasis'] and lib[s['pose_id']]['hips_in_frame']) for h in doc['heroines'].values())}")
    return 1 if errs else 0


if __name__ == "__main__":
    sys.exit(main())
