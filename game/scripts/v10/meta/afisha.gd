class_name V10Afisha
extends RefCounted

# V10Afisha — «Сегодня в чайной», the ONE daily checklist (docs/0.10-spec.md M1 Ф6). Logic only; the lacquer card
# is V10AfishaCard (afisha_card.gd).
#
# Rows (rows() builds them for the card):
#   daily  «Партия дня» — tabs «Раскладка» and, from M6, «Чтение руки» (provider "hand"); ✓ / «обновится в 04:00»
#   salon  «Салон» — nearest task and the ★ bank (provider "salon", M2); before that a grey «откроется …» row
#   mode   «Режим дня ×2» — Блиц, Сад, Этюды, Смена, Дружеская дуэль in turn: ×2 COINS and RANK POINTS, never crystals
#   week   Странствие or Пагода (provider "week", M6); weekends add the «правило недели» (provider "weekend_rule")
# A played row dims and gets the «Сыграно» stamp. Every closed row says why («Откроется на ранге …»).
#
#   V10Afisha.mode_of_day(key = today) -> String   deterministic by the date: each 5-day block is a shuffle of the 5
#                                                  modes (seeded by the block), never the same mode two days running
#   V10Afisha.mult(mode_id, kind) -> int           2 for kind "coins"/"rank" in today's mode, else 1 ("gems" always 1)
#   V10Afisha.mark(kind) -> bool                   daily | hand | mode | salon | week; true when newly played today
#   V10Afisha.on_game_ended(result)                V10Hooks.game_ended → marks daily / hand / mode by result.mode
#   V10Afisha.rows() -> Array                      [{id, title, sub, done, open, lock, icon, mode, tabs, x2}]
#   V10Afisha.set_provider(name, cb)               "salon": ()->{open, sub, done}; "week": ()->{open, title, sub, done,
#                                                  lock}; "hand": ()->bool; "weekend_rule": (key)->{name, desc};
#                                                  "mode_open": (id)->bool; "lock_text": (id)->String;
#                                                  "daily_done": ()->bool (defaults read V6ModesData / G)
# State: S.v10_afisha = {day, played:{daily, hand, mode, salon, week}} — reset when V10Meta.day_key() changes.

const MODES: = ["blitz", "zen", "etude", "shift", "duel"]
const MODE_NAMES: = {"blitz": "Блиц", "zen": "Сад", "etude": "Этюды", "shift": "Смена в чайной", "duel": "Дружеская дуэль"}
const MODE_SHORT: = {"blitz": "Блиц", "zen": "Сад", "etude": "Этюды", "shift": "Смена", "duel": "Дуэль"}
const MODE_BG: = {"blitz": "bg_festival", "zen": "play", "etude": "bg_shrine", "shift": "bg_teahouse", "duel": "bg_neon"}
const KINDS: = ["daily", "hand", "mode", "salon", "week"]
const X2_KINDS: = ["coins", "rank"]
const T_REFRESH: = "обновится в 04:00"
const T_PLAYED: = "Сыграно"
const T_X2: = "×2 монет и очков ранга"
const T_SOON_SALON: = "Откроется вместе с салоном"
const T_SOON_WEEK: = "Странствие и Пагода откроются позже"

static var providers: = {}
static var _st: Dictionary = {}
static var _bound: = false


static func defaults() -> Dictionary:
	return {"day": "", "played": {}}


static func bind(d: Dictionary) -> void:
	if not d.has("day"):
		d["day"] = ""
	if not (d.get("played") is Dictionary):
		d["played"] = {}
	_st = d
	_bound = true


static func unbind() -> void:
	_st = {}
	_bound = false


static func set_provider(name: String, cb: Callable) -> void:
	if cb.is_valid():
		providers[name] = cb
	else:
		providers.erase(name)


static func st() -> Dictionary:
	var s: Dictionary
	if _bound:
		s = _st
	else:
		var gs = G.S
		if gs is Dictionary and gs.get("v10_afisha") is Dictionary:
			s = gs.v10_afisha
		else:
			if _st.is_empty():
				_st = defaults()
			s = _st
	var k: = V10Meta.day_key()
	if str(s.get("day", "")) != k:
		s["day"] = k
		s["played"] = {}
	return s


# ── the mode of the day ────────────────────────────────────────────────────────────────────────────────────────

static func _raw_perm(block: int) -> Array:
	var r: = RandomNumberGenerator.new()
	r.seed = hash("afisha|%d" % block)
	var p: = MODES.duplicate()
	for i in range(p.size() - 1, 0, -1):
		var j: = r.randi_range(0, i)
		var t = p[i]
		p[i] = p[j]
		p[j] = t
	return p


static func _perm(block: int) -> Array:
	var p: = _raw_perm(block)
	# the swap below touches only positions 0 and 1, so the previous block's last mode is its raw last mode
	if p[0] == _raw_perm(block - 1)[MODES.size() - 1]:
		var t = p[0]
		p[0] = p[1]
		p[1] = t
	return p


static func mode_of_day(key: String = "") -> String:
	if key == "":
		key = V10Meta.day_key()
	var idx: = V10Meta.day_index(key)
	var n: = MODES.size()
	return _perm(int(floor(float(idx) / n)))[posmod(idx, n)]


static func mult(mode_id: String, kind: String, key: String = "") -> int:
	if not (kind in X2_KINDS):
		return 1
	return 2 if mode_id == mode_of_day(key) else 1


static func is_weekend(key: String = "") -> bool:
	if key == "":
		key = V10Meta.day_key()
	var wd: = int(Time.get_datetime_dict_from_unix_time(V10Meta.day_index(key) * 86400).weekday)
	return wd == 0 or wd == 6


# ── played marks ───────────────────────────────────────────────────────────────────────────────────────────────

static func played(kind: String) -> bool:
	return bool((st().played as Dictionary).get(kind, false))


static func mark(kind: String) -> bool:
	if not (kind in KINDS):
		push_warning("V10Afisha.mark: unknown kind '%s'" % kind)
		return false
	var p: Dictionary = st().played
	if bool(p.get(kind, false)):
		return false
	p[kind] = true
	return true


# result: {mode: "daily" | "hand" | "blitz" | "zen" | …, win: bool}. A finished game counts (win or not): the
# afisha is a reason to come, not a wall.
static func on_game_ended(result: Dictionary) -> Array:
	var m: = str(result.get("mode", ""))
	var got: = []
	if m == "daily" and mark("daily"):
		got.append("daily")
	if m == "hand" and mark("hand"):
		got.append("hand")
		if mark("daily"):
			got.append("daily")
	if m != "" and m == mode_of_day() and mark("mode"):
		got.append("mode")
	if (m == "journey" or m == "pagoda") and mark("week"):
		got.append("week")
	return got


# ── rows for the card ──────────────────────────────────────────────────────────────────────────────────────────

static func _call(name: String, args: Array = [], fallback = null):
	if providers.has(name):
		return (providers[name] as Callable).callv(args)
	return fallback


static func mode_open(id: String) -> bool:
	if providers.has("mode_open"):
		return bool(_call("mode_open", [id]))
	return V6ModesData.mode_open(id)


static func lock_text(id: String) -> String:
	if providers.has("lock_text"):
		return str(_call("lock_text", [id]))
	return V6ModesData.locked_text(id)


static func _daily_done() -> bool:
	if played("daily"):
		return true
	if providers.has("daily_done"):
		return bool(_call("daily_done"))
	return false


static func rows() -> Array:
	var out: = []
	var key: = V10Meta.day_key()
	# 1. Партия дня
	var tabs: = ["Раскладка"]
	if bool(_call("hand", [], false)):
		tabs.append("Чтение руки")
	var dd: = _daily_done()
	out.append({"id": "daily", "title": "Партия дня", "sub": T_PLAYED if dd else T_REFRESH, "done": dd, "open": true,
		"lock": "", "icon": "calendar", "tabs": tabs, "x2": false})
	# 2. Салон (M2)
	var sp = _call("salon")
	if sp is Dictionary and bool(sp.get("open", false)):
		var sd: = bool(sp.get("done", false)) or played("salon")
		out.append({"id": "salon", "title": "Салон", "sub": str(sp.get("sub", "")), "done": sd, "open": true,
			"lock": "", "icon": "visits", "x2": false})
	else:
		out.append({"id": "salon", "title": "Салон", "sub": T_SOON_SALON, "done": false, "open": false,
			"lock": str(sp.get("lock", T_SOON_SALON)) if sp is Dictionary else T_SOON_SALON, "icon": "visits", "x2": false})
	# 3. Режим дня ×2
	var m: = mode_of_day(key)
	var mo: = mode_open(m)
	var md: = played("mode")
	out.append({"id": "mode", "title": "Режим дня ×2", "mode": m, "mode_name": MODE_NAMES[m],
		"sub": (MODE_NAMES[m] + " · " + T_X2) if mo else (MODE_NAMES[m] + " · " + lock_text(m)), "done": md, "open": mo,
		"lock": "" if mo else lock_text(m), "icon": "trophy", "x2": true})
	# 4. неделя (M6)
	var wp = _call("week")
	if wp is Dictionary and bool(wp.get("open", false)):
		var wd: = bool(wp.get("done", false)) or played("week")
		out.append({"id": "week", "title": str(wp.get("title", "Странствие")), "sub": str(wp.get("sub", "")), "done": wd,
			"open": true, "lock": "", "icon": "rating", "x2": false})
	else:
		var lk: = str(wp.get("lock", T_SOON_WEEK)) if wp is Dictionary else T_SOON_WEEK
		out.append({"id": "week", "title": str(wp.get("title", "Неделя")) if wp is Dictionary else "Неделя",
			"sub": lk, "done": false, "open": false, "lock": lk, "icon": "rating", "x2": false})
	if is_weekend(key):
		var rule = _call("weekend_rule", [key])
		if rule is Dictionary and str(rule.get("name", "")) != "":
			out[out.size() - 1]["rule"] = "Правило недели: %s" % str(rule.name)
	return out


static func done_count() -> int:
	var n: = 0
	for r in rows():
		if bool(r.done):
			n += 1
	return n


static func open_count() -> int:
	var n: = 0
	for r in rows():
		if bool(r.open):
			n += 1
	return n
