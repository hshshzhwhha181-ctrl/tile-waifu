#!/usr/bin/env python3
"""gen_round_table.py - writes game/tests/fixtures/round/table.json, the table of the TWRound selftest (P20).

The expected values come from an independent Python model of the LEGACY play.gd award code (db112f5: _on_clear, _blitz_end, V6Duel.finish,
TowerPlay._award_win, V8PlayRules, G.add_rp), not from the GDScript under test. Regenerate only on purpose: the file is the contract.
  python3 tools/gen_round_table.py          write the table
  python3 tools/gen_round_table.py --check  exit 1 if the checked-in file differs from what the model gives
"""
import json, random, sys
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "game" / "tests" / "fixtures" / "round" / "table.json"
RANKS = [(60, 150), (100, 250), (150, 400), (220, 600), (300, 900), (400, 1200)]
YAKU = {"clean": 4, "calm": 3, "sharp": 2, "swift": 3, "riichi": 6, "dragon": 4, "goldvein": 2, "finale": 2, "set": 2}


def rank_index(rp):
    left = rp
    for t, (per, _) in enumerate(RANKS):
        subs = 3 if t < len(RANKS) - 1 else 999
        for s in range(subs):
            if left < per:
                return t * 3 + s
            left -= per
    return (len(RANKS) - 1) * 3


def rank_into(rp):
    left = rp
    for t, (per, _) in enumerate(RANKS):
        subs = 3 if t < len(RANKS) - 1 else 999
        for s in range(subs):
            if left < per:
                return left
            left -= per
    return 0


def title(rp):
    names = ["Бамбук", "Нефрит", "Жемчуг", "Золото", "Дракон", "Небожитель"]
    left = rp
    for t, (per, _) in enumerate(RANKS):
        subs = 3 if t < len(RANKS) - 1 else 999
        for s in range(subs):
            if left < per:
                return "%s %d" % (names[t], s + 1) if t == len(RANKS) - 1 else "%s %s" % (names[t], ["I", "II", "III"][s])
            left -= per
    return names[-1]


def add_rp(old, n):
    new = old + n
    if n < 0:
        new = max(new, old - rank_into(old))
    new = max(0, new)
    ups = []
    for k in range(rank_index(old) + 1, rank_index(new) + 1):
        t = min(k // 3, len(RANKS) - 1)
        s = k - t * 3
        ups.append(RANKS[t][1] if s == 0 else 50 * (t + 1))
    return new, ups


def path_rp(stars, hard, yrp):
    return 6 + stars * 4 + hard * 8 + min(yrp, 30)


def blitz_rp(score):
    return 0 if score <= 0 else max(5, min(15, 5 + score // 200))


def zen_rp(n):
    return max(5, min(15, 4 + n))


def climb_rp(f):
    return max(5, min(15, 4 + f))


def duel_rp(win, draw):
    return 20 if win else (5 if draw else 0)


def story_stars(fails, boosters):
    return 3 if fails == 0 and boosters == 0 else (2 if fails == 0 and boosters <= 2 else 1)


def yaku_list(s):
    ys = []
    if s.get("riichi"): ys.append("riichi")
    if s["boosters_used"] == 0 and s["fails"] == 0: ys.append("clean")
    if s["max_tray"] <= 2: ys.append("calm")
    if s["denies"] == 0: ys.append("sharp")
    if s["secs"] < s["tiles"] * 1.1: ys.append("swift")
    if s["max_combo"] >= 7: ys.append("dragon")
    if s["gold_total"] > 0 and s["gold_got"] >= s["gold_total"]: ys.append("goldvein")
    if s["last_combo"] >= 3: ys.append("finale")
    for c in s["sets_done"]: ys.append("set:%d" % c)
    return ys


def hook(mode, win, stars, reward, score, secs, s, first, level):
    return {"mode": "path" if mode == "" else mode, "win": win, "score": score, "stars": stars, "time_s": secs, "pairs": s["tiles"] // 2,
            "level": level if mode == "" else -1, "first": first, "rewards": {"gems": reward}, "max_combo": s["max_combo"],
            "clean": win and s["boosters_used"] == 0 and s["fails"] == 0, "dragons": 1 if win and s["max_combo"] >= 7 else 0}


def model(mode, st, cfg, s):
    """returns the expected result fields for resolve(st, mode, cfg, s)"""
    w = {"grants": [], "bond": [], "tasks": [], "pass_xp": 0, "xp": 0, "writes": {}, "record": {}, "ups": [], "yaku": [], "rp_gain": 0,
         "first": False, "stars": 0, "reward": 0, "win": False, "outcome": "lose"}
    rp0 = st["rp"]
    mult = st.get("afisha_mult", 1)
    src = {"": "path", "daily": "daily", "blitz": "blitz", "zen": "zen", "duel": "duel"}.get(mode, "other")
    ev = s["event"]
    if mode in ("pagoda", "journey", "practice"):
        t = s["tower"]
        w["win"] = t["win"]
        w["outcome"] = "win" if t["win"] else "lose"
        if mode != "practice":
            if t["win"]:
                w["bond"].append([st["partner"], 4, "mode_win"])
                w["tasks"].append(["levels", 1])
                rp = climb_rp(t["floor"]) if mode == "pagoda" else max(5, min(15, 6 + 2 * (t["board"] - 1)))
                rp *= mult
                w["rp_gain"] = rp
                new, ups = add_rp(rp0, rp)
                w["ups"] = ups
                w["rp_after"] = new
                w["record"] = {"source": "other", "won": True}
            elif t.get("run_over"):
                w["record"] = {"source": "other", "won": False}
        w.setdefault("rp_after", rp0 if not w["rp_gain"] else w["rp_after"])
        return w
    if ev == "leave":
        w["rp_after"] = rp0
        if src in ("path", "daily", "duel", "blitz"):
            w["record"] = {"source": src, "won": False}
        return w
    if mode == "blitz" and ev == "end":
        score = s["blitz_score"]
        gems = min(150, score // 20)
        w["win"] = True; w["outcome"] = "end"; w["reward"] = gems
        if gems: w["grants"].append(["gems", gems, "play"])
        if score > st.get("blitz_best", 0): w["writes"]["blitz_best"] = score
        rp = blitz_rp(score) * mult
        w["rp_gain"] = rp
        new, ups = add_rp(rp0, rp) if rp else (rp0, [])
        w["ups"] = ups; w["rp_after"] = new
        w["record"] = {"source": "blitz", "won": s["boards_done"] > 0}
        return w
    if mode == "zen" and ev == "board":
        w["win"] = True; w["outcome"] = "board"; w["reward"] = 30
        w["grants"].append(["gems", 30, "play"])
        rp = zen_rp(s["boards_done"]) * mult
        w["rp_gain"] = rp
        new, ups = add_rp(rp0, rp)
        w["ups"] = ups; w["rp_after"] = new
        w["record"] = {"source": "zen", "won": True}
        return w
    if mode == "duel" and ev == "finish":
        me, her = s["me"], s["her"]
        win, draw = me > her, me == her
        gems = 60 if win else (30 if draw else 15)
        if win and st.get("rival_first_win"): gems += 100
        w["win"] = win; w["outcome"] = "win" if win else ("draw" if draw else "lose"); w["reward"] = gems
        w["grants"].append(["gems", gems, "duel"])
        w["bond"] = [[s["rival"], 20 if win else (10 if draw else 5), "duel"], [st["partner"], 10, "duel"]]
        w["pass_xp"] = 60
        rp = duel_rp(win, draw) * mult
        w["rp_gain"] = rp
        new, ups = add_rp(rp0, rp) if rp else (rp0, [])
        w["ups"] = ups; w["rp_after"] = new
        w["record"] = {"source": "duel", "won": win}
        return w
    # a cleared Path / daily / trial table
    stars = 3 if st.get("demo") else story_stars(s["fails"], s["boosters_used"])
    w["win"] = True; w["outcome"] = "win"; w["stars"] = stars
    ys = yaku_list(s)
    w["yaku"] = ys
    path_paid = False
    reward = 0
    lvl = s["level"]
    if mode == "":
        first = st["level_stars"] == 0
        w["first"] = first
        if cfg.get("v10_id"):
            reward = st["path_gems"]; path_paid = True
        else:
            w["writes"]["stars"] = {"level": lvl, "stars": max(st["level_stars"], stars)}
            w["writes"]["unlocked"] = max(st["unlocked"], min(lvl + 2, st["levels_size"]))
            reward = cfg["reward"]["gems"] + stars * 20
        if first and "item" in cfg["reward"]:
            w["writes"]["item"] = cfg["reward"]["item"]
        if first and lvl == 2:
            w["grants"].append(["tickets", 10, "unlock_summon"])
    elif mode == "daily":
        reward = cfg["reward"]["gems"] + stars * 20
        if st["day"] not in st["daily_done"]:
            w["writes"]["daily_done_day"] = st["day"]
    extra = 0
    if s["riichi"]:
        extra = reward + s["gained"]
        reward = reward * 2 + s["gained"]
    w["reward"] = reward
    if mode != "trial":
        yrp = sum(YAKU["set" if y.startswith("set:") else y] for y in ys)
        w["yaku_seen"] = [y for y in ys if not y.startswith("set:")]
        rp = path_rp(stars, cfg.get("hard", 0) if mode == "" else 0, yrp)
        w["rp_gain"] = rp
        new, ups = add_rp(rp0, rp)
        w["ups"] = ups; w["rp_after"] = new
        w["record"] = {"source": src, "won": True}
        if ups: w["rank_title"] = title(new)
        w["bond"] = [[st["partner"], 10, "level_win"]]
        w["tasks"] = [["levels", 1]]
        w["pass_xp"] = 100; w["xp"] = 40
    else:
        w["rp_after"] = rp0
    n = extra if path_paid else reward
    if n > 0: w["grants"].append(["gems", n, "play"])
    w["writes"]["tut_done"] = True
    w["hook"] = hook(mode, True, stars, reward, 0, s["secs"], s, w["first"], lvl)
    w["hook"].update({"rank_up": bool(w["ups"]), "rank_title": w.get("rank_title", ""),
                      "combo_rec": s["max_combo"] >= st["combo_min"] and s["max_combo"] > st["best_combo_prev"]})
    return w


def base_state(**kw):
    st = {"rp": 0, "partner": "mc", "level_stars": 0, "levels_size": 1000, "unlocked": 3, "day": 17, "daily_done": [3, 4], "afisha_mult": 1,
          "blitz_best": 0, "combo_min": 5, "best_combo_prev": 0, "rival_first_win": False, "path_gems": 0, "demo": False}
    st.update(kw)
    return st


def base_stats(**kw):
    s = {"event": "clear", "level": 5, "secs": 100.0, "tiles": 40, "fails": 0, "boosters_used": 0, "max_combo": 4, "last_combo": 1, "denies": 0,
         "max_tray": 2, "gold_total": 0, "gold_got": 0, "sets_done": [], "riichi": False, "gained": 0, "blitz_score": 0, "boards_done": 1,
         "hero": "mc", "seed": 1234}
    s.update(kw)
    return s


def main():
    rows = []
    rnd = random.Random(20261128)

    def add(name, mode, st, cfg, s):
        rows.append({"name": name, "mode": mode, "state": st, "cfg": cfg, "stats": s, "want": model(mode, st, cfg, s)})

    pcfg = {"reward": {"gems": 50}, "hard": 0}
    # --- Path: wins by stars
    for fails, boosters, label in [(0, 0, "3 stars"), (0, 1, "2 stars one help"), (0, 2, "2 stars two helps"), (0, 3, "1 star three helps"), (1, 0, "1 star one overflow"), (2, 4, "1 star bad")]:
        add("path win %s" % label, "", base_state(), pcfg, base_stats(fails=fails, boosters_used=boosters))
    add("path win hard level", "", base_state(), {"reward": {"gems": 80}, "hard": 2}, base_stats())
    add("path win first clear", "", base_state(level_stars=0), pcfg, base_stats(level=9))
    add("path win replay keeps best stars", "", base_state(level_stars=3), pcfg, base_stats(fails=1))
    add("path win replay better stars", "", base_state(level_stars=1), pcfg, base_stats())
    add("path win unlocks next", "", base_state(unlocked=6), pcfg, base_stats(level=5))
    add("path win level 2 opens the summon", "", base_state(), pcfg, base_stats(level=2))
    add("path win level 2 replay no summon", "", base_state(level_stars=2), pcfg, base_stats(level=2))
    add("path win item reward", "", base_state(), {"reward": {"gems": 30, "item": "o_fan"}, "hard": 0}, base_stats(level=11))
    add("path win item reward replay", "", base_state(level_stars=1), {"reward": {"gems": 30, "item": "o_fan"}, "hard": 0}, base_stats(level=11))
    add("path win last level", "", base_state(unlocked=999), pcfg, base_stats(level=999))
    add("path win demo", "", base_state(demo=True), pcfg, base_stats(fails=2, boosters_used=5))
    add("path win certified level pays through the path state", "", base_state(path_gems=120), {"reward": {"gems": 0}, "v10_id": "p5", "hard": 1}, base_stats())
    add("path win certified level riichi", "", base_state(path_gems=120), {"reward": {"gems": 0}, "v10_id": "p5"}, base_stats(riichi=True, gained=44))
    add("path win riichi", "", base_state(), pcfg, base_stats(riichi=True, gained=44))
    add("path win riichi no pair gems", "", base_state(), pcfg, base_stats(riichi=True, gained=0))
    add("path win yaku swift dragon", "", base_state(), pcfg, base_stats(secs=20.0, max_combo=8, last_combo=4))
    add("path win yaku goldvein sets", "", base_state(), pcfg, base_stats(gold_total=3, gold_got=3, sets_done=[1, 4]))
    add("path win no yaku", "", base_state(), pcfg, base_stats(boosters_used=3, fails=1, denies=4, max_tray=3, secs=500.0))
    add("path win yaku cap 30", "", base_state(), pcfg, base_stats(riichi=True, max_combo=9, last_combo=5, secs=10.0, gold_total=2, gold_got=2, sets_done=[0, 1, 2, 3, 4, 0]))
    add("path win combo record", "", base_state(best_combo_prev=6), pcfg, base_stats(max_combo=9))
    add("path win combo not a record", "", base_state(best_combo_prev=9), pcfg, base_stats(max_combo=9))
    add("path win combo below minimum", "", base_state(combo_min=5), pcfg, base_stats(max_combo=4))
    for rp0 in [0, 30, 40, 55, 59, 100, 159, 160, 180, 219, 679, 1000, 1500, 2900, 3400, 6000]:
        add("path win rank ladder from %d" % rp0, "", base_state(rp=rp0), pcfg, base_stats())
    add("path win rank-up over two steps", "", base_state(rp=57), pcfg, base_stats(riichi=True, max_combo=9, last_combo=4, secs=20.0))
    add("path win afisha mode of the day does not touch path rp", "", base_state(afisha_mult=1), pcfg, base_stats())
    # --- Path: lose / leave
    add("path leave a lost table", "", base_state(), pcfg, base_stats(event="leave", fails=1))
    add("path leave certified level", "", base_state(), {"reward": {"gems": 0}, "v10_id": "p5"}, base_stats(event="leave", fails=2))
    # --- daily
    dcfg = {"reward": {"gems": 100}, "hard": 3}
    add("daily win 3 stars", "daily", base_state(), dcfg, base_stats())
    add("daily win 2 stars", "daily", base_state(), dcfg, base_stats(boosters_used=2))
    add("daily win 1 star", "daily", base_state(), dcfg, base_stats(fails=1))
    add("daily win day already done", "daily", base_state(day=3), dcfg, base_stats())
    add("daily win new day", "daily", base_state(day=28, daily_done=[]), dcfg, base_stats())
    add("daily win riichi", "daily", base_state(), dcfg, base_stats(riichi=True, gained=20))
    add("daily win ignores hard in rp", "daily", base_state(), dcfg, base_stats())
    add("daily win rank-up", "daily", base_state(rp=50), dcfg, base_stats())
    add("daily leave", "daily", base_state(), dcfg, base_stats(event="leave"))
    # --- trial
    tcfg = {"reward": {"gems": 0}}
    add("trial win pays nothing", "trial", base_state(), tcfg, base_stats(level=499))
    add("trial win with helps", "trial", base_state(), tcfg, base_stats(level=799, boosters_used=3, fails=1))
    add("trial win riichi", "trial", base_state(), tcfg, base_stats(level=999, riichi=True, gained=10))
    add("trial leave counts no game", "trial", base_state(), tcfg, base_stats(level=699, event="leave"))
    # --- blitz
    for score in [0, 50, 190, 200, 399, 1000, 2000, 2990, 3000, 4000, 9999]:
        add("blitz end score %d" % score, "blitz", base_state(blitz_best=1500), {}, base_stats(event="end", blitz_score=score))
    add("blitz end with no board cleared is a lost game", "blitz", base_state(), {}, base_stats(event="end", blitz_score=120, boards_done=0))
    add("blitz end with two boards cleared", "blitz", base_state(), {}, base_stats(event="end", blitz_score=1300, boards_done=2))
    add("blitz end record", "blitz", base_state(blitz_best=100), {}, base_stats(event="end", blitz_score=400))
    add("blitz end equal to the record is none", "blitz", base_state(blitz_best=400), {}, base_stats(event="end", blitz_score=400))
    add("blitz end mode of the day x2 ranks only", "blitz", base_state(afisha_mult=2), {}, base_stats(event="end", blitz_score=1000))
    add("blitz end rank-up", "blitz", base_state(rp=58), {}, base_stats(event="end", blitz_score=600))
    add("blitz leave", "blitz", base_state(), {}, base_stats(event="leave"))
    # --- zen
    for n in [1, 2, 5, 9, 11, 14]:
        add("zen board %d" % n, "zen", base_state(), {}, base_stats(event="board", boards_done=n))
    add("zen board mode of the day x2", "zen", base_state(afisha_mult=2), {}, base_stats(event="board", boards_done=4))
    add("zen board rank-up", "zen", base_state(rp=55), {}, base_stats(event="board", boards_done=3))
    add("zen leave counts no game", "zen", base_state(), {}, base_stats(event="leave"))
    # --- duel
    for me, her, fw, label in [(12, 5, False, "win"), (12, 5, True, "first win"), (7, 7, False, "draw"), (7, 7, True, "draw first"), (3, 9, False, "loss"), (3, 9, True, "loss first")]:
        add("duel %s" % label, "duel", base_state(rival_first_win=fw), {}, base_stats(event="finish", me=me, her=her, rival="rin"))
    add("duel win mode of the day x2", "duel", base_state(afisha_mult=2), {}, base_stats(event="finish", me=9, her=1, rival="yue"))
    add("duel win rank-up", "duel", base_state(rp=45), {}, base_stats(event="finish", me=9, her=1, rival="hana"))
    add("duel leave", "duel", base_state(), {}, base_stats(event="leave"))
    # --- tower
    for floor_n in [1, 3, 6, 11, 20]:
        add("pagoda win floor %d" % floor_n, "pagoda", base_state(), {}, base_stats(tower={"kind": "pagoda", "win": True, "floor": floor_n, "board": 1}))
    add("pagoda lost run", "pagoda", base_state(), {}, base_stats(tower={"kind": "pagoda", "win": False, "run_over": True}))
    add("pagoda lantern lost, run goes on", "pagoda", base_state(), {}, base_stats(tower={"kind": "pagoda", "win": False, "run_over": False}))
    for b in [1, 2, 3, 5, 6, 9]:
        add("journey win board %d" % b, "journey", base_state(), {}, base_stats(tower={"kind": "journey", "win": True, "floor": 1, "board": b}))
    add("journey lost run", "journey", base_state(), {}, base_stats(tower={"kind": "journey", "win": False, "run_over": True}))
    add("journey win rank-up", "journey", base_state(rp=57), {}, base_stats(tower={"kind": "journey", "win": True, "board": 4}))
    add("tower win mode of the day x2", "pagoda", base_state(afisha_mult=2), {}, base_stats(tower={"kind": "pagoda", "win": True, "floor": 5, "board": 1}))
    add("practice win gives nothing", "practice", base_state(), {}, base_stats(tower={"kind": "practice", "win": True, "floor": 1, "board": 1}))
    add("practice lost run gives nothing", "practice", base_state(), {}, base_stats(tower={"kind": "practice", "win": False, "run_over": True}))
    # --- random Path scenarios (seeded) so the table has the awkward corners too
    for i in range(24):
        fails = rnd.choice([0, 0, 0, 1, 2])
        boosters = rnd.choice([0, 0, 1, 2, 3, 5])
        st = base_state(rp=rnd.randint(0, 4000), level_stars=rnd.choice([0, 0, 1, 2, 3]), unlocked=rnd.randint(1, 200), best_combo_prev=rnd.randint(0, 12),
                        partner=rnd.choice(["mc", "rin", "hana", "yue", "nova"]), day=rnd.randint(1, 28), daily_done=rnd.sample(range(1, 29), rnd.randint(0, 5)))
        s = base_stats(level=rnd.randint(0, 999), fails=fails, boosters_used=boosters, secs=round(rnd.uniform(15, 300), 1), tiles=rnd.choice([24, 36, 48, 60]),
                       max_combo=rnd.randint(1, 14), last_combo=rnd.randint(1, 6), denies=rnd.choice([0, 0, 3]), max_tray=rnd.randint(1, 3),
                       gold_total=rnd.choice([0, 2, 4]), riichi=rnd.random() < 0.2, gained=rnd.randint(0, 120), sets_done=[rnd.randint(0, 4) for _ in range(rnd.randint(0, 2))])
        s["gold_got"] = rnd.randint(0, s["gold_total"])
        mode = rnd.choice(["", "", "daily"])
        c = {"reward": {"gems": rnd.choice([0, 30, 50, 80, 100])}, "hard": rnd.randint(0, 3)}
        add("random %s #%d" % ("path" if mode == "" else mode, i), mode, st, c, s)
    text = json.dumps({"ranks": RANKS, "rows": rows}, ensure_ascii=False, indent=1, sort_keys=True) + "\n"
    if "--check" in sys.argv:
        sys.exit(0 if OUT.exists() and OUT.read_text() == text else 1)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(text)
    print("rows:", len(rows), "->", OUT)


if __name__ == "__main__":
    main()
