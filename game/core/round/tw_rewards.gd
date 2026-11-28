class_name TWRewards
extends RefCounted

# TWRewards (P20 / WP7): the award math of a round, lifted out of play.gd (_on_match gain, _track_set, _collect_yaku, the stars rule,
# the rank-point formulas, the rank ladder, the blitz / zen / duel / tower payouts). Pure static functions: no G, no scene tree, no
# wallet. They return numbers and plain dictionaries; TWRound.resolve() puts them together, the shell applies them through TWWallet.
#
# Every constant below is the number play.gd had on 2026-11-28 (db112f5); round_selftest.gd diffs the formulas against a frozen
# transcription of that code on 300 random scenarios.

const SET_BONUS: = 15                  # three pairs of one suit in a row: +15 crystals (play.gd _track_set)
const ZEN_CLEAR_GEMS: = 30             # every cleared zen board
const BLITZ_CLEAR_SCORE: = 100         # a cleared blitz board (+10 s on the clock)
const BLITZ_CLEAR_SECS: = 10.0
const BLITZ_PAIR_SCORE: = 10           # points per pair, times the combo
const BLITZ_MAX_GEMS: = 150
const BLITZ_GEMS_DIV: = 20             # crystals = score / 20
const PATH_STAR_GEMS: = 20             # path / daily reward: cfg.reward.gems + stars * 20
const LEVEL_BOND: = 10                 # bond points of the partner per won level
const LEVEL_PASS_XP: = 100
const LEVEL_XP: = 40
const DUEL_GEMS_WIN: = 60
const DUEL_GEMS_DRAW: = 30
const DUEL_GEMS_LOSS: = 15
const DUEL_FIRST_WIN_GEMS: = 100
const DUEL_PASS_XP: = 60
const TOWER_BOND: = 4
const COMBO_MIN_FOR_RECORD: = 5        # fallback when the state does not give V9Letters.COMBO_MIN

# G.RANKS without the colours (the selftest runner compares this copy with the live table)
const RANKS: = [
	{"name": "Бамбук", "per": 60, "gems": 150},
	{"name": "Нефрит", "per": 100, "gems": 250},
	{"name": "Жемчуг", "per": 150, "gems": 400},
	{"name": "Золото", "per": 220, "gems": 600},
	{"name": "Дракон", "per": 300, "gems": 900},
	{"name": "Небожитель", "per": 400, "gems": 1200},
]
const ROMAN: = ["I", "II", "III"]

# G.YAKU rank points (the names live with the text)
const YAKU_RP: = {"clean": 4, "calm": 3, "sharp": 2, "swift": 3, "riichi": 6, "dragon": 4, "goldvein": 2, "finale": 2, "set": 2}

# G.CATS: face ranges of the five suits
const CAT_RANGES: = [[0, 6], [7, 14], [15, 22], [23, 28], [29, 35]]


# ── the pair gain (play.gd _on_match) ──────────────────────────────────────────────────────────────────────────────

# crystals for one pair. mult = 1 + (combo - 1) / 2 (integer division), doubled in fever, x gold_mult on a gold pair, x (1 + gem_bonus);
# the first N pairs of the «счастливое начало» fortune give x3; a trial table gives nothing.
# returns {"gain": int, "first_pairs_bonus": int (left)}
static func pair_gain(combo: int, fever: bool, gold: bool, gold_mult: int, gem_bonus: float, first_pairs_bonus: int, mode: String) -> Dictionary:
	var mult: = 1 + (combo - 1) / 2
	var gain: = int(round(mult * (2 if fever else 1) * (gold_mult if gold else 1) * (1.0 + gem_bonus)))
	var left: = first_pairs_bonus
	if left > 0:
		left -= 1
		gain *= 3
	if mode == "trial":
		gain = 0
	return {"gain": gain, "first_pairs_bonus": left}


# blitz points of one pair; zen counts pairs
static func pair_score(mode: String, combo: int) -> int:
	if mode == "blitz":
		return BLITZ_PAIR_SCORE * maxi(1, combo)
	if mode == "zen":
		return 1
	return 0


# three pairs of one suit in a row. st = {"cat_streak": int, "cat_last": int, "sets_done": Array}; cat = suit of the pair (-1 none).
# Mutates st; returns the crystals of a completed set (0 otherwise).
static func set_step(st: Dictionary, cat: int) -> int:
	var streak: = int(st.get("cat_streak", 0))
	var last: = int(st.get("cat_last", -1))
	if cat == last:
		streak += 1
	else:
		streak = 1
		last = cat
	var bonus: = 0
	if streak == 3 and cat >= 0:
		streak = 0
		last = -1
		var done: Array = st.get("sets_done", [])
		done.append(cat)
		st["sets_done"] = done
		bonus = SET_BONUS
	st["cat_streak"] = streak
	st["cat_last"] = last
	return bonus


static func face_cat(face: int) -> int:
	for i in CAT_RANGES.size():
		if face >= int(CAT_RANGES[i][0]) and face <= int(CAT_RANGES[i][1]):
			return i
	return -1


# ── stars, yaku, rank points ───────────────────────────────────────────────────────────────────────────────────────

# 3 stars with no help and no overflow, 2 with no overflow and up to two helps, else 1
static func story_stars(fails: int, boosters: int) -> int:
	return 3 if fails == 0 and boosters == 0 else (2 if fails == 0 and boosters <= 2 else 1)


# the yaku of a won table (play.gd _collect_yaku). s: riichi, boosters_used, fails, max_tray, denies, secs, tiles, max_combo, gold_total, gold_got,
# last_combo, sets_done
static func collect_yaku(s: Dictionary) -> Array:
	var ys: = []
	if bool(s.get("riichi", false)):
		ys.append("riichi")
	if int(s.get("boosters_used", 0)) == 0 and int(s.get("fails", 0)) == 0:
		ys.append("clean")
	if int(s.get("max_tray", 0)) <= 2:
		ys.append("calm")
	if int(s.get("denies", 0)) == 0:
		ys.append("sharp")
	if float(s.get("secs", 0.0)) < int(s.get("tiles", 0)) * 1.1:
		ys.append("swift")
	if int(s.get("max_combo", 0)) >= 7:
		ys.append("dragon")
	if int(s.get("gold_total", 0)) > 0 and int(s.get("gold_got", 0)) >= int(s.get("gold_total", 0)):
		ys.append("goldvein")
	if int(s.get("last_combo", 0)) >= 3:
		ys.append("finale")
	for c in s.get("sets_done", []):
		ys.append("set:%d" % int(c))
	return ys


# rank points of one yaku id; table = {id: rp} (G.YAKU), TWRewards.YAKU_RP when empty
static func yaku_rp(y: String, table: Dictionary = {}) -> int:
	var t: Dictionary = table if not table.is_empty() else YAKU_RP
	if y.begins_with("set:"):
		return int(t.get("set", YAKU_RP.set))
	return int(t.get(y, 0))


static func yaku_sum(list: Array, table: Dictionary = {}) -> int:
	var n: = 0
	for y in list:
		n += yaku_rp(String(y), table)
	return n


static func path_rp(stars: int, hard: int, yaku: int) -> int:
	return V8PlayRules.path_rp(stars, hard, yaku)


# the mode multiplier of the day (V10Afisha.mult(source, "rank")) is applied to rank points only, never to crystals
static func rp_with_mult(rp: int, mult: int) -> int:
	return rp * maxi(1, mult)


# ── the rank ladder (G.rank_of / rank_index / add_rp, without the league and the wallet) ──────────────────────────────

static func rank_of(rp: int, ranks: Array = []) -> Dictionary:
	var t_: Array = ranks if not ranks.is_empty() else RANKS
	var left: = rp
	for t in t_.size():
		var per: int = int(t_[t].per)
		var subs: = 3 if t < t_.size() - 1 else 999
		for s in subs:
			if left < per:
				return {"tier": t, "sub": s, "into": left, "need": per, "title": rank_title(t, s, t_)}
			left -= per
	return {"tier": t_.size() - 1, "sub": 0, "into": 0, "need": 1, "title": String(t_[-1].name)}


static func rank_title(t: int, s: int, ranks: Array = []) -> String:
	var t_: Array = ranks if not ranks.is_empty() else RANKS
	if t == t_.size() - 1:
		return "%s %d" % [t_[t].name, s + 1]
	return "%s %s" % [t_[t].name, ROMAN[s]]


static func rank_index(rp: int, ranks: Array = []) -> int:
	var r: = rank_of(rp, ranks)
	return int(r.tier) * 3 + int(r.sub)


static func rank_floor(rp: int, ranks: Array = []) -> int:
	return maxi(0, rp - int(rank_of(rp, ranks).into))


# rank points after adding n (never below the floor of the current rank when n < 0)
static func rp_after(old_rp: int, n: int, ranks: Array = []) -> int:
	var new_rp: = old_rp + n
	if n < 0:
		new_rp = maxi(new_rp, rank_floor(old_rp, ranks))
	return maxi(0, new_rp)


# the rank-ups an addition causes: [{tier, sub, gems}]. A new tier pays the table's gems, a new sub-rank 50 x (tier + 1).
static func rank_ups(old_rp: int, n: int, ranks: Array = []) -> Array:
	var t_: Array = ranks if not ranks.is_empty() else RANKS
	var before: = rank_index(old_rp, t_)
	var after: = rank_index(rp_after(old_rp, n, t_), t_)
	var ups: = []
	for k in range(before + 1, after + 1):
		var t: = mini(k / 3, t_.size() - 1)
		var s: = k - t * 3
		var g: int = int(t_[t].gems) if s == 0 else 50 * (t + 1)
		ups.append({"tier": t, "sub": s, "gems": g})
	return ups


static func ups_gems(ups: Array) -> int:
	var g: = 0
	for u in ups:
		g += int(u.gems)
	return g


# ── whole-round payouts ───────────────────────────────────────────────────────────────────────────────────────────

# a Path / daily win: base crystals of the table
static func level_reward(cfg: Dictionary, stars: int) -> int:
	var rw: Dictionary = cfg.get("reward", {}) if cfg.get("reward") is Dictionary else {}
	return int(rw.get("gems", 0)) + stars * PATH_STAR_GEMS


# «Ва-банк»: the table's reward is doubled and the pair crystals earned so far are paid again.
# returns {"reward": int, "extra": int} (extra = what is added on top of the crystals already paid)
static func riichi_reward(reward: int, gained: int) -> Dictionary:
	return {"reward": reward * 2 + gained, "extra": reward + gained}


# the end of a blitz run: {gems, rp, record}
static func blitz_end(score: int, best: int) -> Dictionary:
	return {"gems": mini(BLITZ_MAX_GEMS, score / BLITZ_GEMS_DIV), "rp": V8PlayRules.blitz_rp(score), "record": score > best}


# a duel (play.gd's V6Duel.finish): crystals, bond with the rival, rank points
static func duel_result(me: int, her: int, rival_first_win: bool) -> Dictionary:
	var win: = me > her
	var draw: = me == her
	var gems: = DUEL_GEMS_WIN if win else (DUEL_GEMS_DRAW if draw else DUEL_GEMS_LOSS)
	if win and rival_first_win:
		gems += DUEL_FIRST_WIN_GEMS
	return {"win": win, "draw": draw, "gems": gems, "rival_bond": 20 if win else (10 if draw else 5), "partner_bond": 10,
		"pass_xp": DUEL_PASS_XP, "rp": V8PlayRules.duel_rp(win, draw)}


# tower rank points of a cleared table: pagoda = climb_rp(floor), journey = 6 + 2 x (board - 1) in 5..15, practice gives nothing
static func tower_rp(kind: String, floor_n: int, board_n: int) -> int:
	match kind:
		"pagoda":
			return V8PlayRules.climb_rp(floor_n)
		"journey":
			return clampi(6 + 2 * (board_n - 1), 5, 15)
	return 0


# the crystals / coins / tickets / petals the shell must grant when a mode screen reports a finished game
# (V10Hooks.handle_mode_finished, reward half). res: {mode, rewards{}, rewards_paid, hero}; gems_allowed = what the daily cap lets through.
# returns {"grants": {cur: n}, "reason": String, "aff": int, "hero": String}
static func mode_finish_plan(res: Dictionary, gems_allowed: int) -> Dictionary:
	var mode: = String(res.get("mode", ""))
	var rw: Dictionary = res.get("rewards", {}) if res.get("rewards") is Dictionary else {}
	var plan: = {"grants": {}, "reason": "mj_" + (mode if mode != "" else "mode"), "aff": 0, "hero": String(res.get("hero", ""))}
	if bool(res.get("rewards_paid", false)):
		return plan
	for k in ["coins", "petals", "tickets"]:
		if int(rw.get(k, 0)) > 0:
			plan.grants[k] = int(rw[k])
	if gems_allowed > 0:
		plan.grants["gems"] = gems_allowed
	plan["aff"] = int(rw.get("aff", 0))
	return plan
