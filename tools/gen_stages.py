#!/usr/bin/env python3
"""
tools/gen_stages.py (P77 / BATTLE_ULT_SPEC §1.2, §1.4, §1.7, AT-B10):
Generates and certifies all 60 launch Campaign ("Поход") stages into:
  - data/battle/stages.json
  - game/core/modes/battle/data/stages.json (byte-identical mirror for Godot res://)

Every stage has 3 deterministic certified board deals (60 x 3 = 180 boards) with:
  * Exact TWFree 3D half-cell mahjong topology (x, y, z parity matching game/core/rules/tw_free.gd)
  * Weighted suit distribution (`suit_weights`) with >= 2 distinct faces of each suit (man, pin, sou)
  * 100% certificate solvability verified by BOTH exact certificate replay on a 5-slot tray AND
    an independent blind greedy+backtracking solver (no knowledge of the certificate).

Usage:
  python tools/gen_stages.py                  # generate + verify + write stages.json (+ mirror)
  python tools/gen_stages.py --verify         # verify existing stages.json without rewriting
  python tools/gen_stages.py --selftest       # run synthetic self-tests (incl. negative unsolvable case)
"""
from __future__ import annotations

import argparse
import hashlib
import json
import pathlib
import random
import sys

REPO_ROOT = pathlib.Path(__file__).resolve().parent.parent
BALANCE_PATH = REPO_ROOT / "data" / "battle" / "balance.json"
STAGES_PATH = REPO_ROOT / "data" / "battle" / "stages.json"
CORE_STAGES_MIRROR = REPO_ROOT / "game" / "core" / "modes" / "battle" / "data" / "stages.json"

BP = 10000
SUITS = ("man", "pin", "sou")
SUIT_FACES = {
    "man": list(range(0, 9)),
    "pin": list(range(9, 18)),
    "sou": list(range(18, 27)),
    "honor": list(range(27, 36)),
}

# 6 launch chapters per BATTLE_ULT_SPEC §1.2
CHAPTERS = [
    {
        "chapter": 1,
        "name_ru": "Бумажные фонари",
        "boss_id": "paper_oni",
        "boss_name_ru": "Бумажный Они",
        "weak": "sou",
        "resist": "man",
        "mechanics": ["fog"],
        "guest_hero": "mc",
        "default_suit_weights": {"man": 20, "pin": 25, "sou": 40, "honor": 15},
        "shape": "rect",
        "boss_seals": 4,
    },
    {
        "chapter": 2,
        "name_ru": "Лунный лес",
        "boss_id": "moon_kitsune",
        "boss_name_ru": "Лунный Кицунэ",
        "weak": "man",
        "resist": "pin",
        "mechanics": ["fog", "decoy"],
        "guest_hero": "yue",
        "default_suit_weights": {"man": 40, "pin": 20, "sou": 25, "honor": 15},
        "shape": "diamond",
        "boss_seals": 5,
    },
    {
        "chapter": 3,
        "name_ru": "Нефритовые копи",
        "boss_id": "jade_golem",
        "boss_name_ru": "Нефритовый Голем",
        "weak": "man",
        "resist": "sou",
        "mechanics": ["ice", "heavy_shield"],
        "guest_hero": "rin",
        "default_suit_weights": {"man": 42, "pin": 23, "sou": 20, "honor": 15},
        "shape": "pyramid",
        "boss_seals": 6,
    },
    {
        "chapter": 4,
        "name_ru": "Снежный павильон",
        "boss_id": "frost_tengu",
        "boss_name_ru": "Ледяной Тэнгу",
        "weak": "pin",
        "resist": "man",
        "mechanics": ["ice"],
        "guest_hero": "hana",
        "default_suit_weights": {"man": 20, "pin": 42, "sou": 23, "honor": 15},
        "shape": "butterfly",
        "boss_seals": 6,
    },
    {
        "chapter": 5,
        "name_ru": "Угольная колесница",
        "boss_id": "crimson_kasha",
        "boss_name_ru": "Багровая Кася",
        "weak": "pin",
        "resist": "man",
        "mechanics": ["fog", "dark", "ember"],
        "guest_hero": "zlata",
        "default_suit_weights": {"man": 20, "pin": 42, "sou": 23, "honor": 15},
        "shape": "ring",
        "boss_seals": 7,
    },
    {
        "chapter": 6,
        "name_ru": "Забытый стол",
        "boss_id": "dragon_shadow",
        "boss_name_ru": "Тень Дракона",
        "weak": "honor",
        "resist": "",
        "mechanics": ["ice", "fog"],
        "guest_hero": "mc",
        "guest_hero_2": "kohaku",
        "default_suit_weights": {"man": 25, "pin": 25, "sou": 25, "honor": 25},
        "shape": "cross",
        "boss_seals": 8,
    },
]


def mul_bp(a: int, bp: int) -> int:
    return (int(a) * int(bp)) // BP


def suit_of_face(face: int) -> str:
    if 0 <= face <= 8:
        return "man"
    if 9 <= face <= 17:
        return "pin"
    if 18 <= face <= 26:
        return "sou"
    return "honor"


# ------------------------------------------------------------------ TWFree exact topology

def build_layout_positions(shape: str, target_tiles: int, seed: int) -> list[tuple[int, int, int]]:
    """Build a valid even-count 3D half-cell mahjong layout matching TWFree (x, y, z) parity."""
    rng = random.Random(seed)
    cols, rows = 6, 8
    z0: list[tuple[int, int, int]] = []
    for i in range(cols):
        for j in range(rows):
            x = (2.0 * i / max(1, cols - 1)) - 1.0
            y = (2.0 * j / max(1, rows - 1)) - 1.0
            ax, ay = abs(x), abs(y)
            keep = True
            if shape == "diamond":
                keep = (ax * 0.72 + ay * 0.68) <= 1.15
            elif shape == "pyramid":
                keep = ax <= (y + 1.15) * 0.52 + 0.30
            elif shape == "butterfly":
                keep = not (ax < 0.22 and ay > 0.55)
            elif shape == "ring":
                keep = not (ax < 0.25 and ay < 0.30)
            elif shape == "cross":
                keep = (ax < 0.55 or ay < 0.52)
            if keep:
                z0.append((2 * i, 2 * j, 0))

    occ = set(z0)
    pos = list(z0)
    # Build upper layers z=1, 2, 3 on supported half-cells
    for z in (1, 2, 3):
        cand = []
        xs = list(range(z, 2 * (cols - 1) - z + 1, 2))
        ys = list(range(z, 2 * (rows - 1) - z + 1, 2))
        for yy in ys:
            for xx in xs:
                sup = sum(1 for dx in (-1, 1) for dy in (-1, 1) if (xx + dx, yy + dy, z - 1) in occ)
                if sup >= 2:
                    cand.append((xx, yy, z))
        rng.shuffle(cand)
        for c in cand:
            if len(pos) >= target_tiles:
                break
            pos.append(c)
            occ.add(c)
        if len(pos) >= target_tiles:
            break

    # If still under target_tiles, top up on z=0 / z=1 deterministically
    if len(pos) < target_tiles:
        for i in range(cols):
            for j in range(rows):
                c = (2 * i, 2 * j, 0)
                if c not in occ and len(pos) < target_tiles:
                    pos.append(c)
                    occ.add(c)
    if len(pos) < target_tiles:
        for z in (1, 2, 3):
            for xx in range(z, 2 * (cols - 1) - z + 1, 2):
                for yy in range(z, 2 * (rows - 1) - z + 1, 2):
                    c = (xx, yy, z)
                    if c not in occ and len(pos) < target_tiles:
                        pos.append(c)
                        occ.add(c)

    # Trim to exact even target_tiles (removing highest-z / outer tiles first so support stays valid)
    pos.sort(key=lambda p: (p[2], p[1], p[0]))
    if len(pos) > target_tiles:
        pos = pos[:target_tiles]
    if len(pos) % 2 != 0:
        pos.pop()
    pos.sort(key=lambda p: (p[2], p[1], p[0]))
    return pos


def topology(pos: list[tuple[int, int, int]]) -> tuple[list[list[int]], list[list[int]], list[list[int]], list[list[int]], list[list[int]], list[list[int]]]:
    """Exact mirror of TWFree.topology(pos)."""
    n = len(pos)
    cov_by = [[] for _ in range(n)]
    covers = [[] for _ in range(n)]
    lft = [[] for _ in range(n)]
    rgt = [[] for _ in range(n)]
    lft_of = [[] for _ in range(n)]
    rgt_of = [[] for _ in range(n)]
    for i in range(n):
        xi, yi, zi = pos[i]
        for j in range(n):
            if i == j:
                continue
            xj, yj, zj = pos[j]
            if zj > zi and abs(xj - xi) < 2 and abs(yj - yi) < 2:
                cov_by[i].append(j)
                covers[j].append(i)
            elif zj == zi and abs(yj - yi) < 2:
                if xj == xi - 2:
                    lft[i].append(j)
                    lft_of[j].append(i)
                elif xj == xi + 2:
                    rgt[i].append(j)
                    rgt_of[j].append(i)
    return cov_by, covers, lft, rgt, lft_of, rgt_of


def removal_order(pos: list[tuple[int, int, int]], topo, rng: random.Random) -> list[int]:
    cov_by, covers, lft, rgt, lft_of, rgt_of = topo
    n = len(pos)
    covc = [len(cov_by[i]) for i in range(n)]
    lc = [len(lft[i]) for i in range(n)]
    rc = [len(rgt[i]) for i in range(n)]
    left = list(range(n))
    order: list[int] = []
    while left:
        fr = [t for t in left if covc[t] == 0 and not (lc[t] > 0 and rc[t] > 0)]
        if not fr:
            return []  # layout deadlock (should never happen for valid half-cell layouts)
        pick = rng.choice(fr)
        order.append(pick)
        left.remove(pick)
        for c in covers[pick]:
            covc[c] -= 1
        for t in lft_of[pick]:
            lc[t] -= 1
        for t in rgt_of[pick]:
            rc[t] -= 1
    return order


def deal_weighted_faces(npairs: int, suit_weights: dict[str, int], rng: random.Random) -> list[int]:
    """
    Assign npairs face ids respecting `suit_weights` and guaranteeing >= 2 distinct faces of each suit
    (man, pin, sou) per BATTLE_ULT_SPEC §1.4.
    """
    assert npairs >= 8
    chosen: list[int] = []
    # 1. Guarantee >= 2 distinct faces per suit (man, pin, sou)
    for s in SUITS:
        pool = list(SUIT_FACES[s])
        rng.shuffle(pool)
        chosen.extend(pool[:2])

    # 2. Allocate remaining (npairs - 6) pairs deterministically by integer suit_weights quotas
    rem = npairs - len(chosen)
    keys = ["man", "pin", "sou", "honor"]
    total_w = sum(max(0, int(suit_weights.get(k, 0))) for k in keys)
    assert total_w > 0
    # Compute target total pairs per suit (minus the 2 already guaranteed for man/pin/sou)
    target_total = {}
    acc = 0
    for k in keys[:-1]:
        t = (npairs * int(suit_weights.get(k, 0))) // total_w
        if k in SUITS:
            t = max(2, t)
        target_total[k] = t
        acc += t
    target_total["honor"] = max(0, npairs - acc)
    # Fix sum mismatch if any
    diff = npairs - sum(target_total.values())
    if diff != 0:
        heaviest = max(keys, key=lambda k: int(suit_weights.get(k, 0)))
        target_total[heaviest] = max(2 if heaviest in SUITS else 0, target_total[heaviest] + diff)

    extra_needed = {
        "man": max(0, target_total["man"] - 2),
        "pin": max(0, target_total["pin"] - 2),
        "sou": max(0, target_total["sou"] - 2),
        "honor": max(0, target_total["honor"]),
    }
    # Fill using moderate face variety (2..6 faces per suit so pairs match smoothly in 5-slot tray)
    for k in keys:
        cnt = extra_needed[k]
        if cnt <= 0:
            continue
        pool = list(SUIT_FACES[k])
        rng.shuffle(pool)
        active = pool[: min(len(pool), max(2, min(6, cnt)))]
        for i in range(cnt):
            chosen.append(active[i % len(active)])

    # Ensure exact npairs count
    while len(chosen) > npairs:
        chosen.pop()
    while len(chosen) < npairs:
        chosen.append(SUIT_FACES["honor"][0])

    rng.shuffle(chosen)
    return chosen


def verify_certificate_replay(pos: list[tuple[int, int, int]], faces: list[int], cert: list[int], slots: int = 5) -> tuple[bool, str]:
    """Exact simulation of TWBoard.verify_certificate() on a slots-size tray."""
    n = len(pos)
    if len(faces) != n or len(cert) != n or n % 2 != 0:
        return False, "size_mismatch"
    cov_by, covers, lft, rgt, lft_of, rgt_of = topology(pos)
    present = [1] * n
    covc = [len(cov_by[i]) for i in range(n)]
    lc = [len(lft[i]) for i in range(n)]
    rc = [len(rgt[i]) for i in range(n)]
    tray: list[int] = []
    alive = n

    for step_idx, t in enumerate(cert):
        if t < 0 or t >= n or present[t] == 0:
            return False, f"tile_gone@{step_idx}"
        if covc[t] != 0 or (lc[t] > 0 and rc[t] > 0):
            return False, f"tile_not_free@{step_idx}"
        present[t] = 0
        for c in covers[t]:
            covc[c] -= 1
        for u in lft_of[t]:
            lc[u] -= 1
        for u in rgt_of[t]:
            rc[u] -= 1

        f = faces[t]
        matched = -1
        for idx, tid in enumerate(tray):
            if faces[tid] == f:
                matched = idx
                break
        if matched >= 0:
            tray.pop(matched)
            alive -= 2
        else:
            tray.append(t)
            if len(tray) >= slots:
                return False, f"tray_overflow@{step_idx}"

    if alive != 0 or tray:
        return False, f"not_cleared_alive={alive}"
    return True, "ok"


def independent_blind_solve(pos: list[tuple[int, int, int]], faces: list[int], slots: int = 5, max_nodes: int = 4000) -> bool:
    """
    Independent solver bot with ZERO access to `cert`: tries to clear the board on a `slots`-slot tray
    using greedy pair-matching + bounded DFS backtracking.
    """
    n = len(pos)
    cov_by, covers, lft, rgt, lft_of, rgt_of = topology(pos)
    covc0 = [len(cov_by[i]) for i in range(n)]
    lc0 = [len(lft[i]) for i in range(n)]
    rc0 = [len(rgt[i]) for i in range(n)]
    present0 = [1] * n

    nodes = 0
    visited: set[tuple] = set()

    def dfs(present: list[int], covc: list[int], lc: list[int], rc: list[int], tray: tuple[int, ...], alive: int) -> bool:
        nonlocal nodes
        if alive == 0:
            return True
        nodes += 1
        if nodes > max_nodes:
            return False
        key = (tuple(present), tray)
        if key in visited:
            return False
        visited.add(key)

        free = [i for i in range(n) if present[i] and covc[i] == 0 and not (lc[i] > 0 and rc[i] > 0)]
        if not free:
            return False

        tray_faces = {faces[t] for t in tray}
        # Priority 1: immediately match a tile already in tray!
        match_moves = [t for t in free if faces[t] in tray_faces]
        if match_moves:
            # Prefer tile that frees the most covered tiles
            match_moves.sort(key=lambda t: -len(covers[t]))
            candidates = match_moves[:2]
        else:
            # Priority 2: pick one of two free tiles sharing a face (instant pair in 2 moves)
            by_f: dict[int, list[int]] = {}
            for t in free:
                by_f.setdefault(faces[t], []).append(t)
            pair_starts = [ts[0] for ts in by_f.values() if len(ts) >= 2]
            if pair_starts:
                pair_starts.sort(key=lambda t: -len(covers[t]))
                candidates = pair_starts[:3]
            else:
                if len(tray) >= slots - 1:
                    return False
                # Priority 3: uncover tiles
                free.sort(key=lambda t: (-len(covers[t]), -(len(lft_of[t]) + len(rgt_of[t]))))
                candidates = free[:4]

        for t in candidates:
            present[t] = 0
            for c in covers[t]:
                covc[c] -= 1
            for u in lft_of[t]:
                lc[u] -= 1
            for u in rgt_of[t]:
                rc[u] -= 1

            f = faces[t]
            m_idx = -1
            for idx, tid in enumerate(tray):
                if faces[tid] == f:
                    m_idx = idx
                    break
            if m_idx >= 0:
                new_tray = tray[:m_idx] + tray[m_idx + 1 :]
                new_alive = alive - 2
                ok = dfs(present, covc, lc, rc, new_tray, new_alive)
            else:
                if len(tray) + 1 >= slots:
                    ok = False
                else:
                    new_tray = tuple(sorted(tray + (t,)))
                    ok = dfs(present, covc, lc, rc, new_tray, alive)

            present[t] = 1
            for c in covers[t]:
                covc[c] += 1
            for u in lft_of[t]:
                lc[u] += 1
            for u in rgt_of[t]:
                rc[u] += 1
            if ok:
                return True
        return False

    return dfs(present0, covc0, lc0, rc0, (), n)


def generate_certified_board(shape: str, n_pairs: int, suit_weights: dict[str, int], base_seed: int, slots: int = 5) -> dict:
    n_tiles = n_pairs * 2
    for attempt in range(40):
        seed = base_seed + attempt * 997
        rng = random.Random(seed)
        pos = build_layout_positions(shape, n_tiles, seed)
        if len(pos) != n_tiles:
            continue
        topo = topology(pos)
        order = removal_order(pos, topo, rng)
        if len(order) != n_tiles:
            continue
        pair_faces = deal_weighted_faces(n_pairs, suit_weights, rng)
        faces = [0] * n_tiles
        for k in range(n_pairs):
            a = order[2 * k]
            b = order[2 * k + 1]
            faces[a] = pair_faces[k]
            faces[b] = pair_faces[k]

        cert_ok, why = verify_certificate_replay(pos, faces, order, slots)
        if not cert_ok:
            continue
        bot_ok = independent_blind_solve(pos, faces, slots)
        if not bot_ok:
            continue

        suit_counts = {"man": 0, "pin": 0, "sou": 0, "honor": 0}
        distinct_faces: dict[str, set[int]] = {"man": set(), "pin": set(), "sou": set(), "honor": set()}
        for k in range(n_pairs):
            f = pair_faces[k]
            s = suit_of_face(f)
            suit_counts[s] += 1
            distinct_faces[s].add(f)

        if any(len(distinct_faces[s]) < 2 for s in SUITS):
            continue

        flat_pos: list[int] = []
        for x, y, z in pos:
            flat_pos.extend([x, y, z])

        h = hashlib.sha256(json.dumps([flat_pos, faces, order], separators=(",", ":")).encode("utf-8")).hexdigest()[:16]
        return {
            "seed": seed,
            "shape": shape,
            "n_tiles": n_tiles,
            "pairs": n_pairs,
            "slots": slots,
            "suit_counts": suit_counts,
            "distinct_faces_per_suit": {s: len(distinct_faces[s]) for s in SUITS},
            "pos": flat_pos,
            "faces": faces,
            "cert": order,
            "cert_ok": True,
            "bot_ok": True,
            "cert_hash": h,
        }
    raise RuntimeError(f"Failed to certify board shape={shape} pairs={n_pairs} seed={base_seed}")


# ------------------------------------------------------------------ Stage curve from balance.json

def compute_stage_stats(bal: dict, stage_num: int) -> dict:
    prog = bal["progression"]
    sb = bal["shield_and_boss"]
    c = bal["combat"]
    squad_std = bal["sim"]["squad_std"]

    ch = (stage_num - 1) // 10 + 1
    k = (stage_num - 1) % 10 + 1
    lvl_cap = min(int(prog["level_cap_launch"]), int(prog["chapter_cap_base"]) + int(prog["chapter_cap_step"]) * ch)
    rec_lv = lvl_cap if k >= 3 else lvl_cap - 3
    tal_bp = min(3000, 400 * ch + (200 * k) // 10)
    tal_hp_bp = mul_bp(tal_bp, int(prog["talisman_hp_ratio_bp"]))

    sq = []
    for hid in squad_std:
        hdef = bal["heroes"][hid]
        rdef = bal["roles"][hdef["role"]]
        lv_bp = BP + int(prog["level_step_bp"]) * (rec_lv - 1)
        base_atk = mul_bp(int(rdef["atk1"]), lv_bp)
        base_hp = mul_bp(int(rdef["hp1"]), lv_bp)
        sq.append({
            "aura": hdef["aura"],
            "atk": mul_bp(base_atk, BP + tal_bp),
            "hp": mul_bp(base_hp, BP + tal_hp_bp),
        })

    # Integer team_pair_power_x10 matching TWBattleMath.team_pair_power_x10
    suit_prob_bp = int(bal["sim"]["suit_prob_bp"])
    honor_prob_bp = BP - suit_prob_bp
    norm_bp = int(c["pair_norm_bp"])
    suit_sum = 0
    for s in SUITS:
        r_s = sum(mul_bp(h["atk"], int(c["res_full_bp"] if h["aura"] == s else c["res_off_bp"])) for h in sq)
        suit_sum += mul_bp(r_s, norm_bp)
    avg_suit_x10 = (suit_sum * 10) // 3
    r_h = sum(mul_bp(h["atk"], int(c["honor_pair_bp"])) for h in sq)
    honor_x10 = mul_bp(r_h, norm_bp) * 10
    rp_x10 = mul_bp(avg_suit_x10, suit_prob_bp) + mul_bp(honor_x10, honor_prob_bp)

    stype = "boss" if k == 10 else ("elite" if k == 5 else "normal")
    factor_bp = int(sb["stage_factors_bp"][stype])
    k_normal_bp = int(sb["k_normal_bp"])
    boss_hp = mul_bp(mul_bp(rp_x10, k_normal_bp) // 10, factor_bp)
    ref_team_hp = sum(h["hp"] for h in sq)
    boss_cast = mul_bp(ref_team_hp, int(sb["boss_atk_bp"]))
    waves = [36] if (stype == "normal" and k <= 3) else [36, 24]

    return {
        "chapter": ch,
        "stage_in_chapter": k,
        "type": stype,
        "level_cap": lvl_cap,
        "rec_level": rec_lv,
        "rp_x10": rp_x10,
        "factor_bp": factor_bp,
        "boss_hp": boss_hp,
        "ref_team_hp": ref_team_hp,
        "boss_cast": boss_cast,
        "waves": waves,
    }


def build_all_stages(bal: dict) -> dict:
    stages = []
    shapes_cycle = ["rect", "diamond", "pyramid", "butterfly", "ring", "cross"]
    total_gems = 0

    for stage_num in range(1, 61):
        st = compute_stage_stats(bal, stage_num)
        ch_cfg = CHAPTERS[st["chapter"] - 1]
        k = st["stage_in_chapter"]

        # Vary suit_weights slightly per stage while keeping chapter theme prominent
        sw = dict(ch_cfg["default_suit_weights"])
        if k in (2, 7) and ch_cfg["chapter"] < 6:
            # Neutral stage for variety
            sw = {"man": 28, "pin": 28, "sou": 28, "honor": 16}

        shape = ch_cfg["shape"] if k in (5, 10) else shapes_cycle[(stage_num - 1) % len(shapes_cycle)]
        shield_units = 20 if ("heavy_shield" in ch_cfg["mechanics"] and k >= 5) else int(bal["shield_and_boss"]["shield_units_default"])
        cadence = int(bal["shield_and_boss"]["boss_cadence_default"])

        rewards = {
            "first_clear_gems": [5, 3, 2],
            "repeat_coins": 30,
            "ascension_seals": ch_cfg["boss_seals"] if k == 10 else (2 if k == 5 else 0),
            "star3_wish_tickets": 1 if k == 10 else 0,
        }
        total_gems += sum(rewards["first_clear_gems"])

        # AT-B10: 3 certified seeds per stage (wave 1 = 36 pairs)
        seeds = []
        for s_idx in range(3):
            bseed = stage_num * 1000 + s_idx * 17 + 77
            board = generate_certified_board(shape, 36, sw, bseed, slots=5)
            seeds.append(board)

        stages.append({
            "stage": stage_num,
            "chapter": st["chapter"],
            "chapter_name_ru": ch_cfg["name_ru"],
            "stage_in_chapter": k,
            "type": st["type"],
            "boss_id": ch_cfg["boss_id"],
            "boss_name_ru": ch_cfg["boss_name_ru"],
            "weak": ch_cfg["weak"],
            "resist": ch_cfg["resist"],
            "mechanics": list(ch_cfg["mechanics"]),
            "guest_hero": ch_cfg["guest_hero"],
            "level_cap": st["level_cap"],
            "rec_level": st["rec_level"],
            "rp_x10": st["rp_x10"],
            "factor_bp": st["factor_bp"],
            "boss_hp": st["boss_hp"],
            "ref_team_hp": st["ref_team_hp"],
            "boss_cast": st["boss_cast"],
            "shield_units": shield_units,
            "cadence": cadence,
            "waves": st["waves"],
            "suit_weights": sw,
            "rewards": rewards,
            "seeds": seeds,
        })

    assert total_gems == 600, f"Expected 600 first-clear gems, got {total_gems}"
    return {
        "schema": 1,
        "version": "1.0",
        "spec_ref": "design/specs/BATTLE_ULT_SPEC.md#1.2,1.4,1.7",
        "balance_k_normal_bp": int(bal["shield_and_boss"]["k_normal_bp"]),
        "chapters_count": 6,
        "stages_count": len(stages),
        "seeds_per_stage": 3,
        "certified_boards_total": len(stages) * 3,
        "first_clear_gems_total": total_gems,
        "stages": stages,
    }


def verify_stages_doc(doc: dict) -> tuple[int, int, list[str]]:
    errors: list[str] = []
    stages = doc.get("stages", [])
    if len(stages) != 60:
        errors.append(f"expected 60 stages, got {len(stages)}")
    total_boards = 0
    ok_boards = 0
    gems_sum = 0

    for idx, st in enumerate(stages, 1):
        if int(st.get("stage", 0)) != idx:
            errors.append(f"stage index mismatch at {idx}")
        gems_sum += sum(int(x) for x in st.get("rewards", {}).get("first_clear_gems", []))
        seeds = st.get("seeds", [])
        if len(seeds) != 3:
            errors.append(f"stage {idx}: expected 3 seeds, got {len(seeds)}")
        sw = st.get("suit_weights", {})
        for s_i, b in enumerate(seeds):
            total_boards += 1
            flat = b["pos"]
            pos = [(flat[j], flat[j + 1], flat[j + 2]) for j in range(0, len(flat), 3)]
            faces = b["faces"]
            cert = b["cert"]
            slots = int(b.get("slots", 5))
            c_ok, why = verify_certificate_replay(pos, faces, cert, slots)
            if not c_ok:
                errors.append(f"stage {idx} seed {s_i}: cert_replay failed ({why})")
                continue
            b_ok = independent_blind_solve(pos, faces, slots)
            if not b_ok:
                errors.append(f"stage {idx} seed {s_i}: blind_solver failed")
                continue
            # Check >= 2 distinct faces per suit (man, pin, sou)
            df = {s: set() for s in SUITS}
            sc = {"man": 0, "pin": 0, "sou": 0, "honor": 0}
            for f in faces:
                s = suit_of_face(f)
                sc[s] += 1
                if s in df:
                    df[s].add(f)
            if any(len(df[s]) < 2 for s in SUITS):
                errors.append(f"stage {idx} seed {s_i}: <2 distinct faces in a suit ({ {s: len(df[s]) for s in SUITS} })")
                continue
            # Check heaviest suit_weight matches highest pair count among man/pin/sou when tilted
            max_w = max(int(sw.get(s, 0)) for s in SUITS)
            min_w = min(int(sw.get(s, 0)) for s in SUITS)
            if max_w - min_w >= 15:
                heavy_s = max(SUITS, key=lambda s: int(sw.get(s, 0)))
                light_s = min(SUITS, key=lambda s: int(sw.get(s, 0)))
                if sc[heavy_s] <= sc[light_s]:
                    errors.append(f"stage {idx} seed {s_i}: suit_weights tilt not reflected ({sc} vs {sw})")
                    continue
            ok_boards += 1

    if gems_sum != 600:
        errors.append(f"first_clear_gems sum={gems_sum}, want 600")
    return ok_boards, total_boards, errors


def selftest() -> int:
    checks = 0
    ok = 0

    def chk(cond: bool, msg: str) -> None:
        nonlocal checks, ok
        checks += 1
        if cond:
            ok += 1
        else:
            print("  FAIL:", msg)

    # 1. Weighted tilted board certification
    b = generate_certified_board("diamond", 36, {"man": 50, "pin": 20, "sou": 20, "honor": 10}, 12345, slots=5)
    chk(b["cert_ok"] and b["bot_ok"], "synthetic tilted board certified by cert + blind solver")
    chk(b["suit_counts"]["man"] > b["suit_counts"]["pin"], "suit_weights man=50 > pin=20 reflected")
    chk(all(b["distinct_faces_per_suit"][s] >= 2 for s in SUITS), ">= 2 distinct faces per suit")

    # 2. Negative test: intentionally broken certificate must fail verification
    pos = [(b["pos"][j], b["pos"][j + 1], b["pos"][j + 2]) for j in range(0, len(b["pos"]), 3)]
    bad_cert = list(reversed(b["cert"]))
    c_ok, _ = verify_certificate_replay(pos, b["faces"], bad_cert, 5)
    chk(not c_ok, "negative test: reversed cert rejected")

    # 3. Negative test: intentionally odd/corrupt faces must fail verification
    bad_faces = list(b["faces"])
    bad_faces[b["cert"][0]] = (bad_faces[b["cert"][0]] + 1) % 27
    c_ok2, _ = verify_certificate_replay(pos, bad_faces, b["cert"], 5)
    chk(not c_ok2, "negative test: mismatched pair face rejected")

    print(f"GEN_STAGES SELFTEST: {ok}/{checks} {'PASS' if ok == checks else 'FAIL'}")
    return 0 if ok == checks else 1


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--verify", action="store_true", help="verify existing stages.json without rewriting")
    ap.add_argument("--selftest", action="store_true", help="run generator & verifier self-tests")
    args = ap.parse_args()

    if args.selftest:
        rc = selftest()
        if not args.verify:
            return rc

    if args.verify:
        b1 = STAGES_PATH.read_bytes()
        b2 = CORE_STAGES_MIRROR.read_bytes()
        if b1 != b2:
            print("VERIFY FAIL: data/battle/stages.json != game/core/modes/battle/data/stages.json")
            return 1
        doc = json.loads(b1.decode("utf-8"))
        ok_b, tot_b, errs = verify_stages_doc(doc)
        for e in errs[:10]:
            print("  ERR:", e)
        passed = len(errs) == 0 and ok_b == tot_b and tot_b == 180
        print(f"GEN_STAGES VERIFY: {ok_b}/{tot_b} boards certified ({'PASS' if passed else 'FAIL'}, errors={len(errs)})")
        return 0 if passed else 1

    bal = json.loads(BALANCE_PATH.read_text(encoding="utf-8"))
    doc = build_all_stages(bal)
    ok_b, tot_b, errs = verify_stages_doc(doc)
    if errs or ok_b != 180:
        for e in errs[:10]:
            print("  ERR:", e)
        print(f"GEN_STAGES FAIL: {ok_b}/{tot_b}, errors={len(errs)}")
        return 1

    out_text = json.dumps(doc, ensure_ascii=False, separators=(",", ":")) + "\n"
    assert "%" not in out_text and "\u20bd" not in out_text, "Forbidden symbol in stages.json"
    STAGES_PATH.parent.mkdir(parents=True, exist_ok=True)
    CORE_STAGES_MIRROR.parent.mkdir(parents=True, exist_ok=True)
    STAGES_PATH.write_text(out_text, encoding="utf-8")
    CORE_STAGES_MIRROR.write_text(out_text, encoding="utf-8")
    sha = hashlib.sha256(out_text.encode("utf-8")).hexdigest()
    print(f"GEN_STAGES OK: 60 stages, {ok_b}/{tot_b} boards 100% certified (SHA256={sha[:16]}, bytes={len(out_text)})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
