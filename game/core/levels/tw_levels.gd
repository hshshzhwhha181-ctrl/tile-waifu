class_name TWLevels
extends RefCounted

# TWLevels (P19): the ONE access point to the 1000-level Path table. At startup only light stubs exist (arc 0 is
# built); arcs 1..9 are materialised on first touch. Reading the table by index without going through at() (the old
# `TWLevels.at(i]`) returns a stub (generic 6x8 rect board) for every level outside the arcs built so far - that was the
# trial-mode bug (levels 499/699/799/899/999 played as empty rectangles).
#
#   TWLevels.at(n)            -> level dict (arc materialised on demand), n clamped to 0..TOTAL-1
#   TWLevels.count()          -> number of levels (cheap, never builds an arc)
#   TWLevels.trial_cfg(hero)  -> play cfg of the hero's trial table: the SAME board the Path gives for that level
#
# G.LEVELS stays as an alias of the store for size()/iteration over cheap stub fields only (tools/lint_no_direct_levels.py
# forbids indexing it). No G / scene-tree access here: the shell hands the LOCS table to reset().

static var _store: Array = []
static var _arcs: Dictionary = {}
static var _locs: Array = []


# (re)build the stub table in place; `store` is the array G.LEVELS aliases (emptied and refilled, never replaced)
static func reset(locs: Array, store: Array) -> void:
	_locs = locs
	_store = store
	_store.clear()
	_arcs.clear()
	for i in V10LevelGen.TOTAL:
		var w: = i / V10LevelGen.PER_WORLD
		var Wd: Dictionary = V10LevelGen.WORLD[w]
		var tier: = V10LevelGen.tier_of(i)
		var loc: Dictionary = _locs[mini(w, _locs.size() - 1)]
		_store.append({
			"v10_id": i, "code": V10LevelGen.code(i), "world": w, "num": i % V10LevelGen.PER_WORLD + 1,
			"name": str(Wd.name), "loc": mini(w, _locs.size() - 1), "world_loc": w, "stage": i % V10LevelGen.PER_WORLD,
			"bg": str(Wd.bg), "fx": str(Wd.fx), "tint": loc.tint,
			"hero": V10LevelGen.ready_hero(str(Wd.hero), w), "shard": V10LevelGen.ready_hero(str(Wd.shard), w),
			"tier": tier, "tier_name": str(V10LevelGen.TIER_NAMES.get(tier, "")), "hard": int(V10LevelGen.TIER_HARD.get(tier, 0)),
			"boss": V10LevelGen.is_boss(i), "peak": V10LevelGen.is_peak(i), "legend": tier == "legendary",
			"shape": "rect", "cols": 6, "rows": 8, "layers": 3, "fill": 0.7, "faces": 12, "seed": 11 + i * 11,
			"mech": "", "gold": 0, "ice": 0, "hidden": false, "reward": {"gems": 2, "per_star": 2, "first_only": true},
			"goal": "Очисти стол", "intro": str(loc.intro), "_lazy": true,
		})
	ensure_arc(0)


static func count() -> int:
	return V10LevelGen.TOTAL


static func ensure_arc(w: int) -> void:
	w = clampi(w, 0, V10LevelGen.WORLDS - 1)
	if _arcs.has(w) or _store.size() < V10LevelGen.TOTAL:
		return
	_arcs[w] = true
	var base: = w * V10LevelGen.PER_WORLD
	for k in V10LevelGen.PER_WORLD:
		var i: = base + k
		var lv: Dictionary = V10PathState._lv_cache.get(i, V10LevelGen.level(i))
		V10PathState._lv_cache[i] = lv
		var copy: = lv.duplicate(true)
		copy["world_loc"] = int(lv.get("loc", w))
		copy["loc"] = mini(int(lv.get("loc", w)), _locs.size() - 1)
		copy["tint"] = _locs[int(copy.loc)].tint
		if not copy.has("goal"):
			copy["goal"] = "Очисти стол"
		if not copy.has("intro") or str(copy.intro).length() < 12:
			var il: = str(copy.get("intro_line", ""))
			copy["intro"] = il if il != "" else str(_locs[int(copy.loc)].intro)
		_store[i] = copy


static func is_built(n: int) -> bool:
	return _arcs.has(clampi(n, 0, V10LevelGen.TOTAL - 1) / V10LevelGen.PER_WORLD)


# THE accessor: the level dict of index n (0-based), its arc materialised
static func at(n: int) -> Dictionary:
	n = clampi(n, 0, V10LevelGen.TOTAL - 1)
	ensure_arc(n / V10LevelGen.PER_WORLD)
	return _store[n]


# index of the hero's trial table: the LAST level whose world hero is `hero` (stub field, no arc needed); 0 if none
static func trial_index(hero: String) -> int:
	var idx: = 0
	for i in _store.size():
		if str((_store[i] as Dictionary).get("hero", "")) == hero:
			idx = i
	return idx


# play cfg of a trial: exactly the Path board of that level (V10PathState.play_cfg: payload, specials, assist deal),
# completed with the presentation keys of at(n); the caller overrides name/reward/goal/intro
static func trial_cfg(hero: String) -> Dictionary:
	var n: = trial_index(hero)
	var cfg: Dictionary = at(n).duplicate(true)
	var pc: Dictionary = V10PathState.play_cfg(n)
	for k in pc:
		cfg[k] = pc[k]
	cfg.erase("_lazy")
	return cfg
