class_name V10PathState
extends RefCounted

# 0.10 · Путь (0.10-spec M2 П1–П2): progress of the 1000-level Path over V10LevelGen.
#
# Save keys (0.10-spec §2.6 — registered via V10Save when the M1 contract lands, else ensured here):
#   S.unlocked, S.stars            unchanged 0.8 keys; S.unlocked counts MAIN-path levels (Peaks are side nodes)
#   S.v10_levels = {fails:{}, adjusted:{}, daily_full:{day, n}, seen_mech:[], peaks:{}, legend:{}, summits,
#                   chests:{}, arc_end:{}, cos:[]}
#
# Rules
#   * main path = every level except Peaks; a Peak (V10LevelGen.is_peak) is a side rock to the right of its chapter
#     and opens after the chapter boss is cleared (0.10-spec П2)
#   * after ASSIST_AFTER fails in a row (not on Peaks / Legendary) the chapter hostess offers an easier deal;
#     the decision depends only on fails and the level — never on spending (selftest)
#   * Legendary: after LEGEND_BYPASS_AFTER fails «Обходная тропа» opens the way on, without the laurel
#   * Path crystals only for the FIRST clear (+ per new star), full reward for DAILY_FULL wins a day
#   * chapter chest (boss cleared) and star chest (25★/30); no shards from chests (Petals instead)

const Gen = preload("res://scripts/v10/levels/level_gen.gd")
const Rules = preload("res://scripts/v10/path/path_rules.gd")

# selftests and the standalone runner point the model at their own dictionary instead of G.S
static var root_override = null
# the runner never writes the player's real save
static var dry: = false
# test clock (day key) override
static var day_override: = ""
static var _lv_cache: = {}


# ------------------------------------------------------------------ storage

static func S() -> Dictionary:
	if root_override != null:
		return root_override
	return G.S


static func st() -> Dictionary:
	var s: = S()
	if not (s.get("v10_levels") is Dictionary):
		s["v10_levels"] = {}
	var d: Dictionary = s["v10_levels"]
	for k in ["fails", "adjusted", "peaks", "legend", "chests", "arc_end"]:
		if not (d.get(k) is Dictionary):
			d[k] = {}
	for k in ["seen_mech", "cos"]:
		if not (d.get(k) is Array):
			d[k] = []
	if not (d.get("daily_full") is Dictionary):
		d["daily_full"] = {"day": "", "n": 0}
	if not d.has("summits"):
		d["summits"] = 0
	if not (s.get("stars") is Dictionary):
		s["stars"] = {}
	if not s.has("unlocked"):
		s["unlocked"] = 1
	return d


static func save() -> void:
	if dry or root_override != null:
		return
	G.save()


static func day_key() -> String:
	if day_override != "":
		return day_override
	var meta = Rules.cls("V10Meta")
	if meta != null and meta.has_method("day_key"):
		return str(meta.day_key())
	if root_override != null:
		return "test"
	return G.today()


# ------------------------------------------------------------------ level geometry (cheap, no board build)

static func total() -> int:
	return Gen.TOTAL


static func released_total() -> int:
	return Rules.ARCS_RELEASED * Gen.PER_WORLD


static func arc_of(i: int) -> int:
	return i / Gen.PER_WORLD


static func gchapter(i: int) -> int:
	return i / Gen.CHAPTER


static func chapter_in_arc(i: int) -> int:
	return (i % Gen.PER_WORLD) / Gen.CHAPTER


static func boss_of(i: int) -> int:
	return gchapter(i) * Gen.CHAPTER + Gen.CHAPTER - 1


static func is_peak(i: int) -> bool:
	return Gen.is_peak(i)


static func is_legend(i: int) -> bool:
	return Gen.tier_of(i) == "legendary"


static func is_boss(i: int) -> bool:
	return Gen.is_boss(i)


static func arc_released(w: int) -> bool:
	return w >= 0 and w < Rules.ARCS_RELEASED


# hostess of a chapter (boss portrait) — a ready founder until the wave goddesses ship
static func host_of_chapter(gc: int) -> String:
	var w: = gc / 10
	var c: = gc % 10
	var W: Dictionary = Gen.WORLD[w]
	var guests: Array = W.guests
	var h: String = str(W.hero) if c == Gen.CHAPTER - 1 else str(guests[c % guests.size()])
	return Gen.ready_hero(h, w)


# the light node info the map draws (no layout fit): ≈ µs per level
static func node(i: int) -> Dictionary:
	var t: = Gen.tier_of(i)
	return {"i": i, "code": Gen.code(i), "num": i % Gen.PER_WORLD + 1, "tier": t, "boss": Gen.is_boss(i),
		"peak": Gen.is_peak(i), "legend": t == "legendary", "intro": str(Gen.INTRO.get(i, "")),
		"world": arc_of(i), "chapter": chapter_in_arc(i), "pos": i % Gen.CHAPTER}


# the full level dict (V10LevelGen.level), cached: the card needs name, mechanics, reward, faces …
static func level(i: int) -> Dictionary:
	if not _lv_cache.has(i):
		_lv_cache[i] = Gen.level(i)
	return _lv_cache[i]


static func next_main(i: int) -> int:
	var j: = i + 1
	while j < Gen.TOTAL and Gen.is_peak(j):
		j += 1
	return j


# ------------------------------------------------------------------ progress

static func stars(i: int) -> int:
	st()
	return int((S().stars as Dictionary).get(str(i), 0))


static func unlocked() -> int:
	st()
	return clampi(int(S().unlocked), 1, released_total())


static func legend_rec(w: int) -> Dictionary:
	var L: Dictionary = st().legend
	if not (L.get(str(w)) is Dictionary):
		L[str(w)] = {"won": false, "bypass": false, "tries": 0, "best_ms": 0}
	return L[str(w)]


static func peak_rec(i: int) -> Dictionary:
	var P: Dictionary = st().peaks
	if not (P.get(str(i)) is Dictionary):
		P[str(i)] = {"stars": 0, "best_ms": 0, "tries": 0}
	return P[str(i)]


static func bypassed(i: int) -> bool:
	return is_legend(i) and bool(legend_rec(arc_of(i)).bypass) and stars(i) == 0


# "arc_locked" | "locked" | "open" | "current" | "done" | "bypass"
static func state_of(i: int, cur: = -2) -> String:
	if not arc_released(arc_of(i)):
		return "arc_locked"
	if stars(i) > 0:
		return "done"
	if is_peak(i):
		return "open" if (stars(boss_of(i)) > 0 or bypassed(boss_of(i))) else "locked"
	if bypassed(i):
		return "bypass"
	if i < unlocked():
		if cur == -2:
			cur = current()
		return "current" if i == cur else "open"
	return "locked"


# the newest main level the player can play (the map scrolls to it, the CTA plays it)
static func current() -> int:
	var u: = unlocked()
	# the first open main level that is not cleared; else the last open one
	for i in u:
		if not Gen.is_peak(i) and stars(i) == 0 and not bypassed(i):
			return i
	var j: = u - 1
	while j > 0 and Gen.is_peak(j):
		j -= 1
	return j


static func playable(i: int) -> bool:
	return state_of(i) in ["open", "current", "done", "bypass"]


static func arc_progress(w: int) -> Array:
	var done: = 0
	for k in Gen.PER_WORLD:
		var i: = w * Gen.PER_WORLD + k
		if not Gen.is_peak(i) and (stars(i) > 0 or bypassed(i)):
			done += 1
	var mains: = 0
	for k in Gen.PER_WORLD:
		if not Gen.is_peak(w * Gen.PER_WORLD + k):
			mains += 1
	return [done, mains]


# «Чайный сад · пройдено 36/93»; the place name is left out when it repeats the arc title («Чайная во льду»)
static func arc_subtitle(w: int) -> String:
	var pr: = arc_progress(w)
	var place: = str(Gen.WORLD[w].name)
	if place == str(Rules.ARC_TITLES[w]):
		return "пройдено %d/%d" % [pr[0], pr[1]]
	return "%s · пройдено %d/%d" % [place, pr[0], pr[1]]


# UX_RULES §3.5: Peaks appear on the map at L58 (the model still opens a Peak after its chapter boss)
static func peaks_shown() -> bool:
	return unlocked() >= Rules.PEAKS_FROM


static func chapter_stars(gc: int) -> int:
	var n: = 0
	for k in Gen.CHAPTER:
		n += stars(gc * Gen.CHAPTER + k)
	return n


static func chapter_max(gc: int) -> int:
	return Gen.CHAPTER * 3


# ------------------------------------------------------------------ chests

static func chest_bits(gc: int) -> int:
	return int(st().chests.get(str(gc), 0))


# "locked" | "ready" | "claimed"
static func chest_state(gc: int, kind: String) -> String:
	var bit: = 1 if kind == "chapter" else 2
	if chest_bits(gc) & bit:
		return "claimed"
	var b: = gc * Gen.CHAPTER + Gen.CHAPTER - 1
	if kind == "chapter":
		return "ready" if (stars(b) > 0 or bypassed(b)) else "locked"
	return "ready" if chapter_stars(gc) >= Rules.STAR_CHEST_NEED else "locked"


static func claim_chest(gc: int, kind: String) -> Dictionary:
	if chest_state(gc, kind) != "ready":
		return {}
	var bit: = 1 if kind == "chapter" else 2
	st().chests[str(gc)] = chest_bits(gc) | bit
	var r: = Rules.reward("chapter_chest" if kind == "chapter" else "star_chest")
	grant(r, "path_chest_" + kind)
	save()
	return r


# ------------------------------------------------------------------ daily full reward

static func daily() -> Dictionary:
	var d: Dictionary = st().daily_full
	if str(d.get("day", "")) != day_key():
		d["day"] = day_key()
		d["n"] = 0
	var n: = int(d.n)
	return {"n": n, "max": Rules.DAILY_FULL, "show": n >= Rules.DAILY_FULL_SHOW, "full": n < Rules.DAILY_FULL}


# ------------------------------------------------------------------ assist («Давай я переложу стол чуть удобнее?»)

# depends on the fail streak and the level only — not on gems, moon, spending or purchases (selftest checks)
static func offer_assist(i: int) -> bool:
	if is_peak(i) or is_legend(i):
		return false
	if bool(st().adjusted.get(str(i), false)):
		return false
	return int(st().fails.get(str(i), 0)) >= Rules.ASSIST_AFTER


static func accept_assist(i: int) -> void:
	st().adjusted[str(i)] = true
	save()


static func decline_assist(i: int) -> void:
	st().fails[str(i)] = 0
	save()


static func assisted(i: int) -> bool:
	return bool(st().adjusted.get(str(i), false))


# the cfg to play: the assist deal keeps the level, its mechanics and its stars (V10LevelGen.build(i, -1, null, true))
static func play_cfg(i: int) -> Dictionary:
	var cfg: = Gen.build(i, -1, null, assisted(i))
	cfg["mode"] = "legend" if is_legend(i) else ("peak" if is_peak(i) else "")
	cfg["no_paid_help"] = is_peak(i) or is_legend(i)
	return cfg


static func needs_intro(i: int) -> bool:
	var m: = str(Gen.INTRO.get(i, ""))
	return m != "" and not (m in st().seen_mech)


static func mark_intro(i: int) -> void:
	var m: = str(Gen.INTRO.get(i, ""))
	if m != "" and not (m in st().seen_mech):
		st().seen_mech.append(m)
		save()


static func legend_bypass_ready(i: int) -> bool:
	if not is_legend(i):
		return false
	var L: = legend_rec(arc_of(i))
	return not bool(L.won) and not bool(L.bypass) and int(L.tries) >= Rules.LEGEND_BYPASS_AFTER


static func bypass_legend(i: int) -> Dictionary:
	if not legend_bypass_ready(i):
		return {}
	legend_rec(arc_of(i)).bypass = true
	_unlock_after(i)
	var out: = {"arc_end": _arc_end(arc_of(i), false)}
	save()
	return out


# ------------------------------------------------------------------ results

static func on_win(i: int, got: int, ms: int = 0) -> Dictionary:
	st()
	got = clampi(got, 1, 3)
	var prev: = stars(i)
	var lv: = node(i)
	var res: = {"i": i, "stars": got, "prev": prev, "first": prev == 0, "gems": 0, "grants": {}, "chests": [],
		"summit": false, "summits": int(st().summits), "frame_step": 0, "laurel": false, "arc_end": {}}
	S().stars[str(i)] = maxi(prev, got)
	st().fails.erase(str(i))
	st().adjusted.erase(str(i))
	var d: = daily()
	if lv.peak or lv.legend:
		var first: = prev == 0
		if lv.peak:
			var P: = peak_rec(i)
			P.stars = maxi(int(P.stars), got)
			P.best_ms = ms if int(P.best_ms) == 0 or (ms > 0 and ms < int(P.best_ms)) else int(P.best_ms)
			if first:
				st().summits = int(st().summits) + 1
				res.summit = true
				res.summits = int(st().summits)
				if int(st().summits) % Rules.SUMMIT_STEP == 0 and int(st().summits) / Rules.SUMMIT_STEP <= 10:
					res.frame_step = int(st().summits) / Rules.SUMMIT_STEP
					_cos("frame_rising_%d" % res.frame_step)
				_grant_into(res, Rules.reward("peak_first"), "path_peak")
		else:
			var L: = legend_rec(arc_of(i))
			L.best_ms = ms if int(L.best_ms) == 0 or (ms > 0 and ms < int(L.best_ms)) else int(L.best_ms)
			if not bool(L.won):
				L.won = true
				res.laurel = true
				_cos("laurel_arc%d" % (arc_of(i) + 1))
				_grant_into(res, Rules.reward("legend_first"), "path_legend")
			res.arc_end = _arc_end(arc_of(i), true)
	else:
		# 2 + 2×★ (+3 Сложный, +6 Очень сложный) on the first clear; +2 per newly earned star on a replay;
		# nothing beyond DAILY_FULL wins a day (the 400/day cap lives in V10Econ)
		var lvd: Dictionary = level(i)
		var rw: Dictionary = lvd.get("reward", {"gems": 2, "per_star": 2})
		var g: = 0
		if prev == 0:
			g = int(rw.gems) + int(rw.per_star) * got
		elif got > prev:
			g = int(rw.per_star) * (got - prev)
		if not bool(d.full):
			g = 0
		if g > 0:
			_grant_into(res, {"gems": g}, "path_first")
		st().daily_full.n = int(st().daily_full.n) + 1
	if not lv.peak:
		_unlock_after(i)
	var gc: = gchapter(i)
	for kind in ["chapter", "star"]:
		if chest_state(gc, kind) == "ready":
			res.chests.append(kind)
	res["daily"] = daily()
	save()
	return res


static func on_fail(i: int) -> Dictionary:
	st()
	var f: = int(st().fails.get(str(i), 0)) + 1
	st().fails[str(i)] = f
	if is_peak(i):
		peak_rec(i).tries = int(peak_rec(i).tries) + 1
	if is_legend(i):
		legend_rec(arc_of(i)).tries = int(legend_rec(arc_of(i)).tries) + 1
	save()
	return {"i": i, "fails": f, "offer_assist": offer_assist(i), "bypass": legend_bypass_ready(i),
		"no_paid_help": is_peak(i) or is_legend(i)}


static func summits() -> int:
	return int(st().summits)


static func rising_step() -> int:
	return mini(summits() / Rules.SUMMIT_STEP, 10)


# ------------------------------------------------------------------ internals

static func _unlock_after(i: int) -> void:
	var nx: = next_main(i)
	S().unlocked = clampi(maxi(int(S().unlocked), nx + 1), 1, released_total())


static func _arc_end(w: int, laurel: bool) -> Dictionary:
	if bool(st().arc_end.get(str(w), false)):
		return {}
	st().arc_end[str(w)] = true
	var r: = Rules.reward("arc_end")
	grant(r, "path_arc_end")
	return r


static func _grant_into(res: Dictionary, bundle: Dictionary, src: String) -> void:
	grant(bundle, src)
	for k in bundle:
		res.grants[k] = int(res.grants.get(k, 0)) + int(bundle[k])
	res.gems = int(res.grants.get("gems", 0))


# every Path reward goes through here: V10Wallet when the economy lane is merged, else a plain counter on S
static func grant(bundle: Dictionary, src: String) -> void:
	var wallet = Rules.cls("V10Wallet") if root_override == null else null
	for k in bundle:
		var n: = int(bundle[k])
		if n == 0:
			continue
		if wallet != null and wallet.has_method("add"):
			wallet.add(str(k), n, src)
		else:
			var s: = S()
			s[k] = int(s.get(k, 0)) + n


static func _cos(id: String) -> void:
	var pc = Rules.cls("V10ProfileCos") if root_override == null else null
	if pc != null and pc.has_method("unlock"):
		pc.unlock(id, "path")
	if not (id in st().cos):
		st().cos.append(id)
