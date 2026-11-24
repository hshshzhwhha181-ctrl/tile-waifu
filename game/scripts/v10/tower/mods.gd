class_name V10Mods
extends RefCounted

# Shared modifier engine (spec R1) for Пагода Луны and Странствие. Pure logic: no scene, no save access.
#
# A run state is a plain dict:
#   {mode: "pagoda"|"journey", curses: {id: level}, forced: {id: level}, bless: {id: count},
#    partner: "mc", owned: ["mc", ...], released: ["mc", ...]}
# owned / released default to the live game (V10TowerUtil) when missing, so tests can inject them.
#
# Hooks (spec R1: on_cfg / on_start / on_pair / on_overflow / on_floor_end):
#   rules  = V10Mods.resolve(state)                  every number a floor needs (slots, lives, helps, ult, clock…)
#   cfg    = V10Mods.on_cfg(cfg, rules)              the board cfg with the curses / blessings applied
#   ops    = V10Mods.on_start(rules, cfg, tiles)     data ops for the play adapter at the start of a floor
#   ops    = V10Mods.on_pair(rules, pairs_taken)     ops after the N-th pair (ult charge, wind, fog lift)
#   res    = V10Mods.on_overflow(rules, fl)          {lose_life, return_n} (shield / onsen)
#   time   = V10Mods.floor_time(rules, tiles)        hourglass seconds for this table, 0 = none
# Flags (spec R1): normalized (Journey: no «+», ult at base strength), personal_only (plus only in personal modes).

const D: = preload("res://scripts/v10/tower/mods_data.gd")
const U: = preload("res://scripts/v10/tower/tower_util.gd")
const MATRIX_PATH: = "res://scripts/v10/tower/data/mods_matrix.json"

const MODE_FLAGS: = {
	"pagoda": {"personal": true, "normalized": false, "lives": 3, "lives_max": 5},
	"journey": {"personal": false, "normalized": true, "lives": 3, "lives_max": 3},
	"practice": {"personal": false, "normalized": true, "lives": 3, "lives_max": 3},
}

const BASE_SLOTS: = 4

# ---------------------------------------------------------------- heat

static func curse_heat(id: String, lvl: int) -> int:
	if not D.CURSES.has(id) or lvl <= 0:
		return 0
	var lv: Array = D.CURSES[id].levels
	return int(lv[clampi(lvl, 1, lv.size()) - 1].heat)

# heat = sum of the chosen curses (a level replaces the lower one)
static func heat(curses: Dictionary) -> int:
	var h: = 0
	for id in curses:
		h += curse_heat(String(id), int(curses[id]))
	return h

static func heat_max() -> int:
	var h: = 0
	for id in D.CURSES:
		h += curse_heat(id, (D.CURSES[id].levels as Array).size())
	return h

# score multiplier of the Pagoda: 1 + 0.1 × heat («Жар 12 · очки ×2,2»)
static func mult(h: int) -> float:
	return 1.0 + 0.1 * float(h)

# merged curses of a run (chosen + forced by the tower); the higher level wins
static func all_curses(state: Dictionary) -> Dictionary:
	var out: Dictionary = (state.get("curses", {}) as Dictionary).duplicate()
	var f: Dictionary = state.get("forced", {})
	for id in f:
		out[id] = maxi(int(out.get(id, 0)), int(f[id]))
	return out

# ---------------------------------------------------------------- blessings

static func _owned(state: Dictionary) -> Array:
	return state.get("owned", U.owned())

static func _released(state: Dictionary) -> Array:
	return state.get("released", U.released())

static func flags(state: Dictionary) -> Dictionary:
	return MODE_FLAGS.get(String(state.get("mode", "pagoda")), MODE_FLAGS.pagoda)

# «+» (stronger effect, gold edge): her own goddess, and only in personal modes (spec R1)
static func bless_plus(id: String, state: Dictionary) -> bool:
	if not D.BLESS.has(id):
		return false
	if not bool(flags(state).personal):
		return false
	return String(D.BLESS[id].hero) in _owned(state)

static func bless_visible(id: String, state: Dictionary) -> bool:
	return D.BLESS.has(id) and String(D.BLESS[id].hero) in _released(state) \
		and not id in (D.BLESS_SKIP.get(String(state.get("mode", "")), []) as Array)

static func bless_cap(id: String) -> int:
	if bool(D.BLESS[id].get("once", false)):
		return 1
	return int(D.BLESS[id].get("cap", D.BLESS_CAP_DEFAULT))

# 1 of 3 (spec R1): at most one copy per card, the caps hold, lamp-cards only when a lantern can still be added;
# in the Pagoda one of the three is the player's own goddess when she has any card left (like V6 bless_offer)
static func offer_blessings(state: Dictionary, r: RandomNumberGenerator, n: = 3) -> Array:
	var b: Dictionary = state.get("bless", {})
	var rules: = resolve(state)
	var pool: = []
	for id in D.BLESS_ORDER:
		if not bless_visible(id, state):
			continue
		if int(b.get(id, 0)) >= bless_cap(id):
			continue
		var eff: Dictionary = D.BLESS[id].eff
		if eff.has("lamps") and (rules.lamp_one or (int(state.get(_life_key(state), 0)) >= int(rules.lives_max) and not eff.has("lamp_cap"))):
			continue
		if eff.has("slots") and int(rules.slots) + int(eff.slots) > 6:
			continue
		if id == "trail" and int(rules.fog) == 0:
			continue
		if id == "river" and float(rules.time_per_tile) <= 0.0:
			continue
		pool.append(id)
	U.shuffle(pool, r)
	var out: = pool.slice(0, n)
	if bool(flags(state).personal):
		var own: = pool.filter(func(i): return bless_plus(i, state))
		if not own.is_empty() and out.filter(func(i): return bless_plus(i, state)).is_empty() and out.size() == n:
			out[n - 1] = own[0]
	return out

static func take_blessing(state: Dictionary, id: String) -> void:
	var b: Dictionary = state.get("bless", {})
	b[id] = int(b.get(id, 0)) + 1
	state["bless"] = b
	var eff: = bless_eff(id, state)
	if eff.has("lamps"):
		var rules: = resolve(state)
		var lk: = _life_key(state)
		state[lk] = mini(int(state.get(lk, 0)) + int(eff.lamps), int(rules.lives_max))

# Pagoda counts lanterns (run.lives), the Journey counts hearts (run.hearts)
static func _life_key(state: Dictionary) -> String:
	return "lives" if String(state.get("mode", "pagoda")) == "pagoda" else "hearts"

static func bless_eff(id: String, state: Dictionary) -> Dictionary:
	var d: Dictionary = D.BLESS[id]
	return d.eff_plus if bless_plus(id, state) else d.eff

# ---------------------------------------------------------------- resolve

static func _defaults() -> Dictionary:
	return {"slots": BASE_SLOTS, "lives": 3, "lives_max": 5, "lamp_cap": 0, "hint": 0, "undo": 0, "shuffle": 0,
		"hint_off": false, "undo_off": false, "shuffle_off": false, "ult_off": false, "ult_start": 0.0, "ult_every": 0,
		"ult_need_mult": 1.0, "combo_window": 0.0, "start_pairs": 0, "open_tiles": 0, "gold_extra": 0, "gold_mult": 1.0,
		"no_hidden": false, "no_ice": false, "shroud": 0, "fog": 0, "fog_lift_mult": 1.0, "guards": 0, "greedy": 0,
		"time_per_tile": 0.0, "time_bonus": 0, "shield": 0, "return_all": false, "auto_every": 0, "peek_secs": 0.0,
		"first_hint": false, "lamp_one": false, "lamps": 0, "hearts": 0}

static func _apply(r: Dictionary, eff: Dictionary) -> void:
	for k in eff:
		var v = eff[k]
		match k:
			"ult_start", "peek_secs", "shroud", "fog", "greedy":
				r[k] = maxf(float(r[k]), float(v)) if (r[k] is float) else maxi(int(r[k]), int(v))
			"ult_every", "auto_every":
				r[k] = int(v) if int(r[k]) == 0 else mini(int(r[k]), int(v))
			"time_per_tile":
				r[k] = float(v) if float(r[k]) <= 0.0 else minf(float(r[k]), float(v))
			"ult_need_mult", "gold_mult", "fog_lift_mult":
				r[k] = float(r[k]) * float(v)
			"no_hidden", "no_ice", "hint_off", "undo_off", "shuffle_off", "ult_off", "return_all", "first_hint", "lamp_one":
				r[k] = bool(r[k]) or bool(v)
			"combo_window":
				r[k] = float(r[k]) + float(v)
			_:
				r[k] = int(r.get(k, 0)) + int(v)

# Every number a floor / board needs, from the mode, the curses and the blessings.
static func resolve(state: Dictionary) -> Dictionary:
	var r: = _defaults()
	var fl: = flags(state)
	r.lives = int(fl.lives)
	r.lives_max = int(fl.lives_max)
	r["mode"] = String(state.get("mode", "pagoda"))
	r["normalized"] = bool(fl.normalized)
	r["personal"] = bool(fl.personal)
	# a mode's own effects (Journey: the theme of the week) come first
	for e in state.get("extra_eff", []):
		_apply(r, e)
	var cs: = all_curses(state)
	for id in D.CURSE_ORDER:
		if cs.has(id) and int(cs[id]) > 0:
			var lv: Array = D.CURSES[id].levels
			_apply(r, lv[clampi(int(cs[id]), 1, lv.size()) - 1].eff)
	var plus: = []
	var b: Dictionary = state.get("bless", {})
	for id in D.BLESS_ORDER:
		var n: = int(b.get(id, 0))
		if n <= 0 or not D.BLESS.has(id):
			continue
		var eff: = bless_eff(id, state)
		if bless_plus(id, state):
			plus.append(id)
		for i in n:
			# lamps are a run resource (added once, on take_blessing), not a per-floor number
			var e2: = eff.duplicate()
			e2.erase("lamps")
			_apply(r, e2)
	r["plus"] = plus
	r.lives_max = r.lives_max + int(r.lamp_cap)
	if r.mode != "pagoda":
		r.lives_max = 3
	if r.lamp_one:
		r.lives = 1
		r.lives_max = 1
	if r.no_hidden:
		r.shroud = 0
	if r.no_ice:
		r.guards = 0
	r.slots = clampi(int(r.slots), 3, 6)
	r["heat"] = heat(cs)
	r["heat_chosen"] = heat(state.get("curses", {}))
	return r

# ---------------------------------------------------------------- hooks

# on_cfg: the board cfg with greed, guards, shroud, gold applied (deterministic, keeps cfg.seed)
static func on_cfg(cfg: Dictionary, rules: Dictionary) -> Dictionary:
	var c: = cfg.duplicate(true)
	var g: = int(rules.greedy)
	if g > 0:
		var gr: Array = D.GREEDY[clampi(g, 0, D.GREEDY.size() - 1)]
		c.fill = minf(0.9, float(c.get("fill", 0.65)) * float(gr[0]))
		c.faces = mini(int(c.get("faces", 10)) + int(gr[1]), 30)
		c.layers = mini(int(c.get("layers", 3)) + int(gr[2]), 6)
		if c.has("v10_target"):
			c.v10_target = int(round(float(c.v10_target) * float(gr[0])))
	if int(rules.gold_extra) > 0:
		c.gold = int(c.get("gold", 0)) + int(rules.gold_extra)
	if rules.no_ice:
		c.ice = 0
	else:
		# TrayBoard._assign deals round(cfg.ice × 1.5) ice tiles: guards N adds exactly N
		c.ice = float(c.get("ice", 0)) + float(rules.guards) / 1.5
	if rules.no_hidden:
		c.hidden = false
	elif int(rules.shroud) >= 1:
		c.hidden = true
	c["v10_mods"] = {"shroud": int(rules.shroud), "fog": int(rules.fog), "heat": int(rules.heat)}
	return c

# on_start: data ops for the adapter, in the order they must run. `tiles` is an array of
# {i, step, free, covered, secret} describing the dealt table (V10TowerRules builds it from the TrayBoard;
# the selftest builds it from V10TowerSim). Fog picks tiles deterministically from cfg.seed.
static func on_start(rules: Dictionary, cfg: Dictionary, tiles: Array) -> Array:
	var ops: = []
	if int(rules.start_pairs) > 0:
		ops.append({"op": "auto_pairs", "n": int(rules.start_pairs)})
	if int(rules.open_tiles) > 0:
		# the covered tiles needed soonest (lowest step): freeing them never breaks the step order
		var cov: = tiles.filter(func(t): return not bool(t.free))
		cov.sort_custom(func(a, b): return int(a.step) < int(b.step) or (int(a.step) == int(b.step) and int(a.i) < int(b.i)))
		var ids: = []
		for k in mini(int(rules.open_tiles), cov.size()):
			ids.append(int(cov[k].i))
		if not ids.is_empty():
			ops.append({"op": "open", "tiles": ids})
	if int(rules.shroud) >= 2:
		var ids2: = []
		for t in tiles:
			if not bool(t.free) and not bool(t.secret):
				ids2.append(int(t.i))
		ops.append({"op": "shroud", "tiles": ids2})
	if int(rules.fog) > 0:
		var fg: Array = D.FOG[clampi(int(rules.fog), 0, D.FOG.size() - 1)]
		ops.append({"op": "fog", "tiles": fog_tiles(cfg, tiles, float(fg[0])), "lift": fog_lift(rules)})
	if float(rules.peek_secs) > 0.0:
		ops.append({"op": "peek", "secs": float(rules.peek_secs)})
	if rules.first_hint:
		ops.append({"op": "hint"})
	if float(rules.ult_start) > 0.0 and not rules.ult_off:
		ops.append({"op": "ult_charge", "frac": float(rules.ult_start)})
	return ops

static func fog_lift(rules: Dictionary) -> int:
	var fg: Array = D.FOG[clampi(int(rules.fog), 0, D.FOG.size() - 1)]
	return maxi(1, int(ceil(float(fg[1]) * float(rules.fog_lift_mult))))

# one contiguous bank of fog: the tiles whose x is in a band chosen by the seed (a cloud, not confetti)
static func fog_tiles(cfg: Dictionary, tiles: Array, share: float) -> Array:
	if tiles.is_empty() or share <= 0.0:
		return []
	var r: = U.rng(int(cfg.get("seed", 1)), "fog")
	var xs: = tiles.map(func(t): return Vector2(float(t.get("x", 0)), float(t.get("y", 0))))
	var c: Vector2 = xs[r.randi() % xs.size()]
	var idx: = range(tiles.size())
	idx.sort_custom(func(a, b):
		var da: float = (xs[a] - c).length_squared()
		var db: float = (xs[b] - c).length_squared()
		return da < db or (da == db and a < b))
	var n: = int(round(tiles.size() * share))
	var out: = []
	for k in n:
		out.append(int(tiles[idx[k]].i))
	out.sort()
	return out

# on_pair: after the player's N-th pair of this floor (1-based)
static func on_pair(rules: Dictionary, n: int) -> Array:
	var ops: = []
	if int(rules.ult_every) > 0 and not rules.ult_off and n % int(rules.ult_every) == 0:
		ops.append({"op": "ult_charge", "n": 1})
	if int(rules.auto_every) > 0 and n % int(rules.auto_every) == 0:
		ops.append({"op": "auto_pairs", "n": 1})
	if int(rules.fog) > 0 and n == fog_lift(rules):
		ops.append({"op": "fog_lift"})
	return ops

# on_overflow: fl = per-floor state {shield_used}; returns what the adapter does
static func on_overflow(rules: Dictionary, fl: Dictionary) -> Dictionary:
	var used: = int(fl.get("shield_used", 0))
	if used < int(rules.shield):
		fl["shield_used"] = used + 1
		return {"lose_life": false, "return_n": 99 if rules.return_all else 3, "forgiven": true}
	return {"lose_life": true, "return_n": 99 if rules.return_all else 3, "forgiven": false}

# hourglass seconds for a table of `tiles` tiles (0 = no clock)
static func floor_time(rules: Dictionary, tiles: int) -> int:
	if float(rules.time_per_tile) <= 0.0:
		return 0
	return int(ceil(float(tiles) * float(rules.time_per_tile))) + int(rules.time_bonus)

# helps for the floor: base counts (the mode's) + blessings, zero when the curse turns the help off
static func helps(rules: Dictionary, base: Dictionary) -> Dictionary:
	return {
		"hint": 0 if rules.hint_off else int(base.get("hint", 0)) + int(rules.hint),
		"undo": 0 if rules.undo_off else int(base.get("undo", 0)) + int(rules.undo),
		"shuffle": 0 if rules.shuffle_off else int(base.get("shuffle", 0)) + int(rules.shuffle),
		"ult": not rules.ult_off,
	}

# ---------------------------------------------------------------- curse offers and validation

# Journey: «1 из 2 проклятий» after a board, level I only, never a curse the run already has
static func offer_curses(state: Dictionary, r: RandomNumberGenerator, n: = 2, pool_ids: Array = D.JOURNEY_CURSES) -> Array:
	var have: = all_curses(state)
	var pool: = []
	for id in pool_ids:
		if int(have.get(id, 0)) > 0:
			continue
		var c2: = have.duplicate()
		c2[id] = 1
		if validate(c2).ok:
			pool.append(id)
	U.shuffle(pool, r)
	return pool.slice(0, n)

# Pagoda: the tower's own curse every 10th floor — one more level of a curse still below its top, chosen by seed
static func forced_curse(state: Dictionary, r: RandomNumberGenerator) -> Array:
	var have: = all_curses(state)
	var pool: = []
	for id in D.CURSE_ORDER:
		var lv: = int(have.get(id, 0))
		if lv >= (D.CURSES[id].levels as Array).size():
			continue
		if id == "one_lamp":
			continue
		var c2: = have.duplicate()
		c2[id] = lv + 1
		if validate(c2).ok:
			pool.append([id, lv + 1])
	if pool.is_empty():
		return []
	return pool[r.randi() % pool.size()]

static var _matrix: = {}

static func matrix() -> Dictionary:
	if _matrix.is_empty():
		var f: = FileAccess.open(MATRIX_PATH, FileAccess.READ)
		if f:
			var d = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				_matrix = d
		if _matrix.is_empty():
			_matrix = {"forbid": [], "version": 0}
	return _matrix

static func set_matrix(m: Dictionary) -> void:
	_matrix = m

static func _key(id: String, lvl: int) -> String:
	return "%s:%d" % [id, lvl]

# a forbidden pair of curse levels covers every pair at or above both levels
static func validate(curses: Dictionary) -> Dictionary:
	var h: = heat(curses)
	if h > D.HEAT_MAX:
		return {"ok": false, "reason": D.SAFE_TEXT}
	for id in curses:
		if not D.CURSES.has(id) or int(curses[id]) < 0 or int(curses[id]) > (D.CURSES[id].levels as Array).size():
			return {"ok": false, "reason": "unknown curse %s" % id}
	for pr in matrix().get("forbid", []):
		var a: = String(pr[0]).split(":")
		var b: = String(pr[1]).split(":")
		if int(curses.get(a[0], 0)) >= int(a[1]) and int(curses.get(b[0], 0)) >= int(b[1]):
			return {"ok": false, "reason": D.SAFE_TEXT, "pair": [String(pr[0]), String(pr[1])]}
	return {"ok": true, "reason": ""}

# can this curse level be added to the scroll now? (grey card «Слишком жестоко даже для Пагоды» otherwise)
static func can_set(curses: Dictionary, id: String, lvl: int) -> bool:
	var c2: = curses.duplicate()
	if lvl <= 0:
		c2.erase(id)
	else:
		c2[id] = lvl
	return validate(c2).ok

# the highest heat reachable under the matrix (cosmetics at 32 must stay reachable)
static func max_valid_heat() -> int:
	var best: = [0]
	_search({}, 0, best)
	return best[0]

static func _search(cur: Dictionary, i: int, best: Array) -> void:
	if i >= D.CURSE_ORDER.size():
		best[0] = maxi(best[0], heat(cur))
		return
	var id: String = D.CURSE_ORDER[i]
	var rest: = 0
	for k in range(i, D.CURSE_ORDER.size()):
		rest += curse_heat(D.CURSE_ORDER[k], (D.CURSES[D.CURSE_ORDER[k]].levels as Array).size())
	if heat(cur) + rest <= best[0]:
		return
	for lvl in range((D.CURSES[id].levels as Array).size(), -1, -1):
		var c2: = cur.duplicate()
		if lvl > 0:
			c2[id] = lvl
		if lvl == 0 or validate(c2).ok:
			_search(c2, i + 1, best)

# ---------------------------------------------------------------- cards (UI text)

static func bless_card(id: String, state: Dictionary) -> Dictionary:
	var d: Dictionary = D.BLESS[id]
	var p: = bless_plus(id, state)
	return {"id": id, "hero": String(d.hero), "hero_name": U.hero_name(String(d.hero)), "title": String(d.name),
		"line": String(d.plus if p else d.desc), "plus": p, "kind": "bless"}

static func curse_card(id: String, lvl: int, mode: = "pagoda") -> Dictionary:
	var d: Dictionary = D.CURSES[id]
	var lv: Array = d.levels
	var L: Dictionary = lv[clampi(lvl, 1, lv.size()) - 1]
	var roman: String = ["", "I", "II", "III"][clampi(lvl, 0, 3)] if lv.size() > 1 else ""
	var line: = String(L.desc)
	if mode != "pagoda":
		line = line.replace("гаснет фонарь", "разбивается сердце").replace("один фонарь", "одно сердце").replace("фонарь", "сердце")
	return {"id": id, "lvl": lvl, "title": String(d.name) + (" " + roman if roman != "" else ""), "line": line,
		"heat": int(L.heat), "kind": "curse",
		"tag": ("+%d Жара" % int(L.heat)) if mode == "pagoda" else ("очки " + U.fmt_mult2(1.0 + D.JOURNEY_CURSE_BONUS))}
