class_name V10Gacha2
extends RefCounted

# V10Gacha2 — gacha v2 rules for M4 (spec Г1, Г3, Г4, Г5, Г7). Pure logic over the save dict S and a V10GachaBank.
# The 0.9 three-stage lantern reveal plays the results (V10WishScreen); G.roll/G.pull become thin proxies (hooks).
#
# Counters: phase banners share S.pity / S.sr_pity / S.guar (carried between phases); «Пять ветров» and «Первый
# гость» use S.pity_std / S.s_pity_std. S.rates_ver: 1 (0.9 curve) until the first SSR after the update, then 2.
# Candles (S.candles): +1 for every wish on any banner, tickets included; never burn; 200 → «Свеча желаний».
#
#   var g: = V10Gacha2.new(S, items, bank)            items = G.ITEMS; bank = V10GachaBank (default on S)
#   g.ensure()                                        idempotent defaults + one-time 0.9 migration (newbie_left 50−(20−old))
#   g.banners() -> Array                              banners of the Wishes screen (V10Banners.shown)
#   g.cost(b, n) -> int ; g.split(b, n) -> Dictionary ; g.can_pull(b, n) -> bool
#   g.pull(b, n) -> Array[result]                     pays, rolls, grants, logs. result: {id, rar(A/S/SSR), item, new,
#                                                     star, star_up, petals, gems, featured, won, guaranteed, pity, guar,
#                                                     banner, candles}
#   g.pity_left(b) -> int ; g.guar(b) -> bool ; g.newbie_left() -> int
#   g.can_spark() ; g.spark_options() -> Array[item] ; g.spark(id) -> result
#   g.first_needed() ; g.first_options() -> Array[item] ; g.choose_first(id) -> result
#   g.add_star(id) -> bool                            60 petals → +✦
#   g.pool() -> {A,S,SSR: [items]} ; g.odds(b) -> Array (V10Rates.item_odds)
#   g.history(days, banner="") -> Array ; g.history_counts() -> {SSR,S,A}

signal guest_done          # the 50th wish on «Первый гость»: scene «Ты больше не гость», frame «Свой за столом»

const FIRST_CHOICES: = ["o_dragon", "y_queen", "n_ssr"]
const FIRST_COMP_TICKETS: = 10
const NEWBIE_PULLS: = 50
const OLD_NEWBIE: = 20
const LOG_DAYS: = 90
const LOG_MAX: = 2000

static var log_path: = "user://v10_logs/pulls.json"

var S: Dictionary
var bank: V10GachaBank
var items: Array = []
var item_by: = {}
var rng: = RandomNumberGenerator.new()
var _pool: = {}
var _log: Array = []
var _log_loaded: = false
var log_enabled: = true
var after_pull: Callable = Callable()       # e.g. func(n): G.add_pass_xp(10 * n)


func _init(state: Dictionary, all_items: Array, b: V10GachaBank = null) -> void:
	S = state
	bank = b if b != null else V10GachaBank.new(S)
	items = all_items
	for it in items:
		item_by[String(it.id)] = it
	rng.randomize()
	ensure()


static func rar10(r: String) -> String:
	return {"R": "A", "SR": "S"}.get(r, r)


static func rar09(r: String) -> String:
	return {"A": "R", "S": "SR"}.get(r, r)


func item(id: String) -> Dictionary:
	return item_by.get(id, {})


func ensure() -> void:
	var st: = V10Banners.state(S)
	TWWallet.ensure_keys(S, ["tickets", "petals"])   # the wallet snapshot keys the 0.9 readers expect (integers)
	for k in ["candles", "pity_std", "s_pity_std", "pity", "sr_pity", "pulls"]:
		S[k] = int(S.get(k, 0))
	S["guar"] = bool(S.get("guar", false))
	for k in ["ostars", "targets", "mastery"]:
		if not (S.get(k) is Dictionary):
			S[k] = {}
	S["first_pick"] = String(S.get("first_pick", ""))
	S["first_pick_t"] = int(S.get("first_pick_t", 0))
	V10Seven.st(S)
	if not bool(st.get("mig", false)):
		st["mig"] = true
		# a 0.9 save keeps the old curve until its first SSR; a fresh one starts on v2
		S["rates_ver"] = 1 if int(S.pulls) > 0 else V10Rates.VER_NOW
		# «Первый гость» grows from 20 to 50 wishes: 50 − (20 − old_left)
		var old: = int(S.get("newbie_left", OLD_NEWBIE))
		S["newbie_left"] = clampi(NEWBIE_PULLS - (OLD_NEWBIE - old), 0, NEWBIE_PULLS)
		S["newbie_ssr"] = bool(S.get("newbie_ssr", false))
		V10Stars.migrate(S, items.filter(func(x): return String(x.get("cat", "")) == "outfit").map(func(x): return String(x.id)))
		_migrate_first_pick()
	S["rates_ver"] = int(S.get("rates_ver", V10Rates.VER_NOW))
	S["newbie_left"] = int(S.get("newbie_left", NEWBIE_PULLS))


func _migrate_first_pick() -> void:
	if S.first_pick != "":
		return
	var have: = FIRST_CHOICES.filter(func(id): return bank.owns(id))
	if have.size() == FIRST_CHOICES.size():
		S.first_pick = "comp"
		bank.add("tickets", FIRST_COMP_TICKETS)
		V10Banners.state(S)["fp_letter"] = true


# ---------------------------------------------------------------- pools
func pool() -> Dictionary:
	if not _pool.is_empty():
		return _pool
	_pool = {"A": [], "S": [], "SSR": []}
	for it in items:
		if it.get("start", false) or it.get("nogacha", false) or it.get("hidden", false) or it.get("limited", false):
			continue
		# 0.12 wave 1: a goddess of wave 1 drops only by her own rules (A/S base outfits now, Zlata banner-only until her
		# standard entry, vows never) — V10Wave1.droppable
		if V10W1Gacha.is_w1(String(it.id)) and not V10Wave1.droppable(String(it.id), func(i): return bank.owns(String(i)), V10GClock.now()):
			continue
		_pool[rar10(String(it.rar))].append(it)
	return _pool


# ---------------------------------------------------------------- banners
func newbie_left() -> int:
	return int(S.newbie_left)


func newbie_open() -> bool:
	return newbie_left() > 0


func banners() -> Array:
	var out: = V10Banners.shown(S, newbie_open())
	for b in out:
		b["target"] = V10Banners.target(S, b)
	return out


func unit_cost(b: Dictionary) -> int:
	return V10Rates.NEWBIE_COST if b.kind == "newbie" else V10Rates.PULL_COST


func cost(b: Dictionary, n: int) -> int:
	return unit_cost(b) * n


func split(b: Dictionary, n: int) -> Dictionary:
	if b.kind == "newbie" and n > newbie_left():
		return {"tickets": 0, "gems": 0, "moon": 0, "ok": false, "gems_left": bank.balance("gems")}
	return bank.split(n, unit_cost(b), b.kind != "newbie")


func can_pull(b: Dictionary, n: int) -> bool:
	return bool(split(b, n).ok)


func _ctr_keys(b: Dictionary) -> Array:
	return ["pity", "sr_pity"] if b.kind == "phase" else ["pity_std", "s_pity_std"]


func pity(b: Dictionary) -> int:
	return int(S[_ctr_keys(b)[0]])


func pity_left(b: Dictionary) -> int:
	var left: = V10Rates.HARD - pity(b)
	if b.kind == "newbie" and not bool(S.newbie_ssr):
		left = mini(left, newbie_left())
	return left


func guar(b: Dictionary) -> bool:
	return b.kind == "phase" and bool(S.guar)


# ---------------------------------------------------------------- the pull
func pull(b: Dictionary, n: int) -> Array:
	if n <= 0:
		return []
	var sp: = split(b, n)
	if not bank.pay(sp):
		return []
	var keys: = _ctr_keys(b)
	var c: = {"p": int(S[keys[0]]), "s": int(S[keys[1]])}
	var res: = []
	var drawn: = {}
	for i in n:
		var ver: = int(S.rates_ver)
		var hard: = V10Rates.HARD
		if b.kind == "newbie" and not bool(S.newbie_ssr):
			hard = mini(hard, int(c.p) + newbie_left())
		var rar: = V10Rates.roll(c, ver, rng.randf(), hard)
		if rar == "SSR" and ver != V10Rates.VER_NOW:
			S.rates_ver = V10Rates.VER_NOW
		var r: = {"rar": rar, "banner": String(b.id), "featured": false, "won": false, "guaranteed": false}
		var it: = _pick(b, rar, r, drawn)
		if b.kind == "newbie":
			S.newbie_left = newbie_left() - 1
			if rar == "SSR":
				S.newbie_ssr = true
			if newbie_left() == 0:
				V10Banners.state(S)["guest_done"] = true
				guest_done.emit()
		drawn[String(it.id)] = true
		_grant(it, r)
		S.candles = int(S.candles) + 1
		r["candles"] = int(S.candles)
		r["pity"] = int(c.p)
		r["guar"] = bool(S.guar)
		_log_add(String(b.id), rar, String(it.id), false)
		res.append(r)
	S[keys[0]] = int(c.p)
	S[keys[1]] = int(c.s)
	S.pulls = int(S.pulls) + n
	if after_pull.is_valid():
		after_pull.call(n)
	_log_save()
	return res


func _pick(b: Dictionary, rar: String, r: Dictionary, drawn: Dictionary) -> Dictionary:
	var p: Array = pool()[rar]
	if rar == "SSR":
		match String(b.kind):
			"phase":
				var tgt: = V10Banners.target(S, b)
				var g: = bool(S.guar)
				var win: = g or rng.randf() < V10Rates.FEATURED_SHARE
				r.guaranteed = g
				r.won = win and not g
				if win:
					S.guar = false
					r.featured = true
					return item(tgt)
				S.guar = true
				return _any(p.filter(func(x): return String(x.id) != tgt), drawn)
			"newbie":
				var fp: = String(S.first_pick)
				var outfits: = p.filter(func(x): return String(x.get("cat", "")) == "outfit" and String(x.id) != fp)
				var fresh: = outfits.filter(func(x): return not bank.owns(String(x.id)))
				r.featured = true
				return _any(fresh if not fresh.is_empty() else outfits, {})
	if rar == "S" and String(b.kind) == "phase" and not b.get("s_up", []).is_empty():
		if rng.randf() < V10Rates.S_UP_SHARE:
			r.featured = true
			return item(String(b.s_up[rng.randi() % b.s_up.size()]))
		return _any(p.filter(func(x): return not (String(x.id) in b.s_up)), drawn)
	return _any(p, drawn)


# uniform pick; inside one pull an item is not repeated until its rarity pool ran dry (as in 0.8)
func _any(p: Array, drawn: Dictionary) -> Dictionary:
	if p.is_empty():
		return {}
	var left: = p.filter(func(x): return not drawn.has(String(x.id)))
	if left.is_empty():
		left = p
	return left[rng.randi() % left.size()]


func _grant(it: Dictionary, r: Dictionary) -> void:
	var id: = String(it.get("id", ""))
	r["id"] = id
	r["item"] = it
	r["star"] = 0
	r["star_up"] = false
	r["petals"] = 0
	r["gems"] = 0
	var is_new: = bank.give(id)
	r["new"] = is_new
	if is_new:
		if V10Stars.is_outfit(it):
			V10Stars.on_new(S, id)
			r.star = 1
		return
	var d: = V10Stars.on_dup(S, it)
	r.star = int(d.star)
	r.star_up = bool(d.up)
	r.petals = int(d.petals)
	r.gems = int(d.gems)
	bank.add("petals", int(d.petals))
	bank.add("gems", int(d.gems))


# ---------------------------------------------------------------- Свеча желаний
func can_spark() -> bool:
	return int(S.candles) >= V10Rates.SPARK


func spark_options() -> Array:
	var ids: = []
	for it in pool().SSR:
		ids.append(String(it.id))
	for id in V10Banners.current(S).get("ssr", []):
		if not (id in ids):
			ids.append(String(id))
	return ids.map(func(id): return item(id)).filter(func(x): return not x.is_empty())


func spark(id: String) -> Dictionary:
	if not can_spark():
		return {}
	var ok: = false
	for it in spark_options():
		if String(it.id) == id:
			ok = true
	if not ok:
		return {}
	S.candles = int(S.candles) - V10Rates.SPARK
	var r: = {"rar": "SSR", "banner": "candle", "featured": true, "won": false, "guaranteed": true, "spark": true}
	_grant(item(id), r)
	r["candles"] = int(S.candles)
	_log_add("candle", "SSR", id, true)
	_log_save()
	return r


# ---------------------------------------------------------------- Первая SSR на выбор
func first_options() -> Array:
	if String(S.first_pick) != "":
		return []
	return FIRST_CHOICES.filter(func(id): return not bank.owns(id)).map(func(id): return item(id))


func first_needed() -> bool:
	return not first_options().is_empty()


func choose_first(id: String) -> Dictionary:
	var ok: = false
	for it in first_options():
		if String(it.id) == id:
			ok = true
	if not ok:
		return {}
	S.first_pick = id
	S.first_pick_t = V10GClock.now()
	var r: = {"rar": "SSR", "banner": "first", "featured": true, "won": false, "guaranteed": true, "first": true}
	_grant(item(id), r)
	_log_add("first", "SSR", id, true)
	_log_save()
	return r


# no full-screen purchase offer in the session of the first pick and for 24 h after it (spec Г3)
func offer_quiet() -> bool:
	return int(S.first_pick_t) > 0 and V10GClock.now() - int(S.first_pick_t) < V10GClock.DAY


# ---------------------------------------------------------------- Созвездие
func add_star(id: String) -> bool:
	if not V10Stars.can_add(S, id, bank.balance("petals")):
		return false
	bank.spend("petals", V10Stars.STAR_PETALS)
	V10Stars.ostars(S)[id] = V10Stars.level(S, id) + 1
	return true


# ---------------------------------------------------------------- odds and history
func odds(b: Dictionary) -> Array:
	var bb: = b.duplicate()
	bb["target"] = V10Banners.target(S, b) if b.kind == "phase" else ""
	if b.kind == "newbie":
		# «Первый гость» draws its SSR only among outfits (the promised one); same rarity numbers
		var p: = pool().duplicate()
		p["SSR"] = p.SSR.filter(func(x): return String(x.get("cat", "")) == "outfit")
		return V10Rates.item_odds(bb, p, V10Rates.VER_NOW)
	return V10Rates.item_odds(bb, pool(), V10Rates.VER_NOW)


func _log_load() -> void:
	if _log_loaded:
		return
	_log_loaded = true
	_log = []
	if not log_enabled or not FileAccess.file_exists(log_path):
		return
	var f: = FileAccess.open(log_path, FileAccess.READ)
	if f:
		var d = JSON.parse_string(f.get_as_text())
		if d is Array:
			_log = d


func _log_add(bid: String, rar: String, id: String, special: bool) -> void:
	_log_load()
	var e: = {"t": V10GClock.now(), "b": bid, "r": rar, "i": id}
	if special:
		e["x"] = 1
	_log.append(e)


func _log_save() -> void:
	var lim: = V10GClock.now() - LOG_DAYS * V10GClock.DAY
	var k: = 0
	while k < _log.size() and (int(_log[k].t) < lim or _log.size() - k > LOG_MAX):
		k += 1
	if k > 0:
		_log = _log.slice(k)
	if not log_enabled:
		return
	DirAccess.make_dir_recursive_absolute(log_path.get_base_dir())
	var f: = FileAccess.open(log_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(_log))


func history(bid: String = "") -> Array:
	_log_load()
	var lim: = V10GClock.now() - LOG_DAYS * V10GClock.DAY
	return _log.filter(func(e): return int(e.t) >= lim and (bid == "" or String(e.b) == bid))


func history_counts(bid: String = "") -> Dictionary:
	var c: = {"SSR": 0, "S": 0, "A": 0}
	for e in history(bid):
		c[String(e.r)] = int(c.get(String(e.r), 0)) + 1
	return c
