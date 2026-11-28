class_name TWMigrate
extends RefCounted

# TWMigrate (P12 / WP4): every save migration, moved out of g.gd (_migrate + migrate_48_to_1000), as pure functions over a
# plain Dictionary. No G, no scene tree: what g.gd read from itself arrives through the `ctx` dictionary.
#
#   TWMigrate.check(d) -> {ok, reason, ver}     is `d` a save this game may apply? reason: notdict | keys | badver | badtype |
#                                               future (ver > SAVE_VER: a newer game wrote it; applying it would lose data)
#   TWMigrate.apply(d, ctx) -> {ok, reason, state, report}
#                                               d merged over fresh defaults, type-repaired, migrated ver<4 .. ver<8 (+ the
#                                               48 -> 1000 level step), module keys ensured. `d` itself is never modified.
#   TWMigrate.run(S, ctx) -> report             the same on a state that is already merged (in place)
#   TWMigrate.migrate_48_to_1000(S, released)   the one-time 0.9 -> 0.10 Path mapping (G.migrate_48_to_1000 delegates here)
#
# ctx (all optional, defaults make it work without G):
#   defaults: Callable() -> Dictionary    fresh default state (G.default_state); default {} (keys are then not merged)
#   levels_size: int                      LEVELS.size() for the ver<4 step                          (default V10LevelGen.TOTAL)
#   heroes: Array / Dictionary            ids of the released heroines (avatar / partner validation) (default ["mc","rin","hana","yue","nova"])
#   new_profile: Callable() -> Dictionary the profile factory (G.new_profile)                       (default: built from now)
#   now: int                              unix time for time-stamped steps                          (default V10Meta.now_unix())
#   released: int                         released Path levels                                      (default V10PathState.released_total())
#   modules: bool                         run V10Save + V10Registry.ensure_all                      (default true)
#   template: bool                        type-repair module keys against what a fresh game builds   (default true)

const SAVE_VER: = 8
const FX_LEVELS: = ["full", "mid", "min"]
const ULT_CUTINS: = ["full", "short", "off"]
const DEFAULT_HEROES: = ["mc", "rin", "hana", "yue", "nova"]

# a save is unusable without these (the old apply_state test) and with these of the wrong kind
const NEED_KEYS: = ["gems", "unlocked"]
const NUM_KEYS: = ["gems", "unlocked"]
const DICT_KEYS: = ["stars", "owned"]


static func _is_num(v) -> bool:
	return (v is int and absi(v) < 1000000000000000) or (v is float and is_finite(v) and absf(v) < 1.0e15)


static func check(d: Variant) -> Dictionary:
	if not (d is Dictionary):
		return {"ok": false, "reason": "notdict", "ver": -1}
	var dd: Dictionary = d
	for k in NEED_KEYS:
		if not dd.has(k):
			return {"ok": false, "reason": "keys", "ver": -1}
	var v = dd.get("ver", 0)
	if not _is_num(v):
		return {"ok": false, "reason": "badver", "ver": -1}
	var fv: = float(v)
	if fv > float(SAVE_VER):
		return {"ok": false, "reason": "future", "ver": int(minf(fv, 1.0e9))}
	for k in NUM_KEYS:
		if not _is_num(dd[k]):
			return {"ok": false, "reason": "badtype", "ver": int(fv)}
	for k in DICT_KEYS:
		if dd.has(k) and not (dd[k] is Dictionary):
			return {"ok": false, "reason": "badtype", "ver": int(fv)}
	return {"ok": true, "reason": "", "ver": maxi(0, int(fv))}


static func apply(d: Dictionary, ctx: Dictionary = {}) -> Dictionary:
	var c: = check(d)
	if not bool(c.ok):
		return {"ok": false, "reason": c.reason, "state": {}, "report": {}}
	var df: Dictionary = {}
	if ctx.get("defaults") is Callable and (ctx.defaults as Callable).is_valid():
		var dv = (ctx.defaults as Callable).call()
		if dv is Dictionary:
			df = dv
	var st: Dictionary = df.duplicate(true)
	var src: Dictionary = d.duplicate(true)
	for k in src:
		st[k] = src[k]
	st["ver"] = int(c.ver)
	var rep: = run(st, ctx, df)
	return {"ok": true, "reason": "", "state": st, "report": rep}


# in place; `df` = the defaults used for type repair (apply passes the ones it merged over)
static func run(S: Dictionary, ctx: Dictionary = {}, df: Dictionary = {}) -> Dictionary:
	var rep: = {"from": int(S.get("ver", 0)), "to": SAVE_VER, "steps": [], "repaired": []}
	var now: int = int(ctx.get("now", -1))
	if now < 0:
		now = V10Meta.now_unix()
	var use_modules: bool = bool(ctx.get("modules", true))
	if use_modules:
		V10Registry.load_all()
	# 1. every top-level key (and every key of a default sub-dictionary) has the kind the code reads
	var want: = df.duplicate(true)
	if use_modules:
		var md: = V10Save.all_defaults()
		for k in md:
			if not want.has(k):
				want[k] = md[k]
		if not df.is_empty() and bool(ctx.get("template", true)):
			_add_module_template(want, now)
	_repair(S, want, "", rep.repaired)
	if S.has("econ") and not (S.econ is Dictionary):
		S.erase("econ")                       # the wallet attach rebuilds it from the gems / coins mirrors
	for k in DICT_KEYS:
		if not (S.get(k) is Dictionary):
			S[k] = {}
	_clean_stars(S)
	# 2. the ladder of version steps, moved verbatim from g.gd _migrate()
	var levels_size: int = int(ctx.get("levels_size", V10LevelGen.TOTAL))
	var heroes: Array = _hero_ids(ctx.get("heroes", DEFAULT_HEROES))
	if int(S.get("ver", 0)) < 4:
		var old_unl: = int(S.unlocked)
		var ns: = {}
		for k in S.stars:
			ns[str(int(k) * 4)] = S.stars[k]
		S.stars = ns
		S.unlocked = mini(1 + (old_unl - 1) * 4, levels_size)
		S.ver = 4
		rep.steps.append(4)
	if int(S.ver) < 5:
		var ns5: = {}
		for k in S.stars:
			ns5[str(V6Worlds.migrate_index(int(k)))] = S.stars[k]
		S.stars = ns5
		S.unlocked = mini(V6Worlds.migrate_index(maxi(0, int(S.unlocked) - 1)) + 1, levels_size)
		S["v6_map"] = {"chests": {}, "seen": int(S.unlocked)}
		S.ver = 5
		rep.steps.append(5)
	if int(S.ver) < 6:
		S.profile = _new_profile(ctx, now)
		S.profile.avatar = str(S.get("partner", "mc"))
		S.profile_done = false
		S.stats = {}
		S.ver = 6
		rep.steps.append(6)
	if int(S.ver) < 7:
		# 0.9: the old «Тряска и вспышки» switch becomes the 3-step effects level
		var v6fx = S.get("v6_fx", {})
		var calm: bool = v6fx is Dictionary and not bool(v6fx.get("shake", true))
		S.fx_level = "mid" if calm else "full"
		S.ult_cutin = "full"
		S.ver = 7
		rep.steps.append(7)
	if not (str(S.get("fx_level", "")) in FX_LEVELS):
		S.fx_level = "full"
	if not (str(S.get("ult_cutin", "")) in ULT_CUTINS):
		S.ult_cutin = "full"
	_sync_v6_fx(S)
	var hd: = {}
	for h in heroes:
		hd[h] = true
	V10W1Core.sanitize_save(S, hd)
	_ensure_profile(S, ctx, now, heroes)
	S.profile_done = bool(S.get("profile_done", false))
	if not (S.get("stats") is Dictionary):
		S.stats = {}
	# 3. 0.10: SAVE_VER 7 -> 8, once (v10_meta, v10_afisha, module migrators incl. the 48 -> 1000 Path step), then ensure
	if use_modules:
		var mr: = V10Save.migrate(S, now)
		if int(mr.get("from", 8)) < SAVE_VER:
			rep.steps.append(8)
		V10Registry.ensure_all(S)
	S["ver"] = SAVE_VER
	return rep


# What a fresh game looks like once every module has run its ensure: the kind map for the keys the modules own (the manifests
# carry no schema, so the schema IS "what ensure builds on the defaults"). Only the kind of a value is ever taken from it.
static func _add_module_template(want: Dictionary, now: int) -> void:
	var t: Dictionary = want.duplicate(true)
	V10Save.ensure(t)
	V10Registry.ensure_all(t)
	_merge_missing(want, t)


# adds to dst every key (at any depth, through dictionaries) that only src has; never replaces a value
static func _merge_missing(dst: Dictionary, src: Dictionary) -> void:
	for k in src:
		if not dst.has(k):
			dst[k] = src[k].duplicate(true) if (src[k] is Dictionary or src[k] is Array) else src[k]
		elif dst[k] is Dictionary and src[k] is Dictionary:
			_merge_missing(dst[k], src[k])


static func _hero_ids(h) -> Array:
	if h is Dictionary:
		return (h as Dictionary).keys()
	if h is Array:
		return h
	return DEFAULT_HEROES


static func _new_profile(ctx: Dictionary, now: int) -> Dictionary:
	if ctx.get("new_profile") is Callable and (ctx.new_profile as Callable).is_valid():
		var p = (ctx.new_profile as Callable).call()
		if p is Dictionary:
			return (p as Dictionary).duplicate(true)
	var pid: int = (ctx.rng as TWRng).next_u32() if ctx.get("rng") is TWRng else TWRng.make(now, 0x70726f66).next_u32()
	return {"nick": "", "avatar": "mc", "frame": "", "created": now, "id": "%08x" % pid}


static func _ensure_profile(S: Dictionary, ctx: Dictionary, now: int, heroes: Array) -> void:
	var d: = _new_profile(ctx, now)
	if not (S.get("profile") is Dictionary):
		S.profile = d
		return
	for k in d:
		if not S.profile.has(k):
			S.profile[k] = d[k]
	S.profile.created = int(S.profile.created) if _is_num(S.profile.created) else now
	if not (str(S.profile.get("avatar", "")) in heroes):
		S.profile.avatar = "mc"


# V6Fx.shake()/flash() read S.v6_fx.shake/flash (missing = on): only the "full" level keeps them on. Writes only
# what differs, so a save that never touched the keys round-trips unchanged.
static func _sync_v6_fx(S: Dictionary) -> void:
	var on: = str(S.get("fx_level", "full")) == "full"
	var d = S.get("v6_fx")
	if not (d is Dictionary):
		if on:
			return
		d = {}
		S.v6_fx = d
	for k in ["shake", "flash"]:
		var cur = d.get(k, true)
		if not (cur is bool) or cur != on:
			d[k] = on


# ── repair ─────────────────────────────────────────────────────────────────────────────────────────────────────

static func _kind_ok(v, dv) -> bool:
	if dv is Dictionary:
		return v is Dictionary
	if dv is Array:
		return v is Array
	if dv is String:
		return v is String
	if dv is bool:
		return v is bool
	if dv is int or dv is float:
		return _is_num(v)
	return true


# a value of the wrong kind is replaced by the default; a default sub-dictionary is walked key by key (extra keys stay)
static func _repair(S: Dictionary, df: Dictionary, path: String, out: Array) -> void:
	for k in df:
		if k == "ver" or not S.has(k):
			continue
		var dv = df[k]
		if not _kind_ok(S[k], dv):
			S[k] = dv.duplicate(true) if (dv is Dictionary or dv is Array) else dv
			out.append(path + str(k))
		elif dv is Dictionary and not (dv as Dictionary).is_empty():
			_repair(S[k], dv, path + str(k) + ".", out)


# star entries are {level index: 0..3}; anything else would make the readers' int() casts throw or lie
static func _clean_stars(S: Dictionary) -> void:
	var stars: Dictionary = S.stars
	var bad: = []
	for k in stars:
		var v = stars[k]
		if not _is_num(v) or not str(k).is_valid_int() or int(str(k)) < 0:
			bad.append(k)
	for k in bad:
		stars.erase(k)
	for k in stars:
		stars[k] = clampi(int(stars[k]), 0, 3)


# ── 0.10 W2: the one-time 48 -> 1000 migration for legacy saves (moved from G.migrate_48_to_1000) ──────────────
#   passed = clamp(old_unlocked - 1, 0, 48), raised to k + 1 if stars[k] > 0 (48 passed when index 47 has stars).
#   new_unlocked = 1 if passed == 0 else clamp(round(passed * 100 / 48) + 1, 1, released_total).
#   Each old star at 0..47 moves to the nearest unused non-Peak main-path level around round(old_i * 99 / 47) in Arc 1,
#   preserving 100 % of earned stars (Salon bank == sum of legacy stars).
static func migrate_48_to_1000(st_dict: Dictionary, released: int = -1) -> void:
	if not (st_dict.get("v10_levels") is Dictionary):
		st_dict["v10_levels"] = {}
	var lv10: Dictionary = st_dict["v10_levels"]
	if bool(lv10.get("mig48", false)):
		return
	if released < 0:
		released = V10PathState.released_total()
	var old_stars: Dictionary = st_dict.get("stars", {}) if st_dict.get("stars") is Dictionary else {}
	var old_unl: = maxi(1, int(st_dict.get("unlocked", 1)))
	var has_hi: = old_unl > 48
	for k in old_stars:
		if int(k) >= 48:
			has_hi = true
			break
	if has_hi:
		lv10["mig48"] = true
		return
	var passed: = clampi(old_unl - 1, 0, 48)
	var max_idx: = -1
	for k in old_stars:
		var idx: = int(k)
		if idx >= 0 and idx < 48 and int(old_stars[k]) > 0:
			passed = maxi(passed, idx + 1)
			max_idx = maxi(max_idx, idx)
	if old_unl <= 6 and max_idx < 6:
		lv10["mig48"] = true
		return
	var new_stars: = {}
	var used: = {}
	var keys: = old_stars.keys()
	keys.sort_custom(func(a, b): return int(a) < int(b))
	for k in keys:
		var sv: = clampi(int(old_stars[k]), 0, 3)
		if sv <= 0:
			continue
		var oi: = clampi(int(k), 0, 47)
		var target: = clampi(int(round(oi * 99.0 / 47.0)), 0, 99)
		var pick: = -1
		for d in 100:
			for cand in ([target] if d == 0 else [target - d, target + d]):
				if cand >= 0 and cand < 100 and not V10LevelGen.is_peak(cand) and not used.has(cand):
					pick = cand
					break
			if pick >= 0:
				break
		if pick < 0:
			pick = target
		used[pick] = true
		new_stars[str(pick)] = sv
	st_dict["stars"] = new_stars
	if passed <= 0:
		st_dict["unlocked"] = 1
	else:
		st_dict["unlocked"] = clampi(int(round(passed * 100.0 / 48.0)) + 1, 1, released)
	lv10["mig48"] = true
