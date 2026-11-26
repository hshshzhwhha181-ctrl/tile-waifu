class_name V10DuelUtil
extends RefCounted

# V10DuelUtil — every place the duel lane touches the rest of the game goes through here (lane «Дуэли 2.0»,
# docs/0.10-spec.md R6). Static, no scene access except G (soft: the selftest runs without main.tscn too).
#
#   klass(name) -> Script            soft class lookup by class_name, cached (V10Econ, V10Save, V10ProfileCos …)
#   save() -> Dictionary             G.S, or test_S when a selftest set it, or a private dict before G exists
#   now() / day_key() / cal_key()    one clock: V10Meta (fake_now for tests); day = 04:00 phone, cal = 04:00 МСК
#   week_id(t) / week_end(wid)       calendar week from Monday 04:00 МСК (Дуэль недели)
#   season_id(t) / season_num(sid) / season_start(sid) / season_end(sid)   28-day seasons on the same grid
#   date_msk(t) «пн, 21 декабря, 04:00 МСК»; countdown(t_end) «47:12» only in the last 48 h, else ""
#   hseed(parts) -> int              stable hash (never the global RNG); rng(seed, stream)
#   lint(text) -> Array              V10Lint stop words + UX §4.3 jargon + «%», «₽», «ДР» (empty = clean)
#   released() / hero_name(h) / hero_color(h)   heroines of this build (G.HEROES); later waves stay hidden
#   apply_rewards(rewards, src) -> Array        THE one place that pays: {gems, petals, aff:{h:n}, frame, title}
#   fmt_int(n) «1 040», fmt_delta(n) «+20» / «−18», plural(n, …)

const META: = preload("res://scripts/v10/meta/meta.gd")
const LINT: = preload("res://scripts/v10/meta/lint.gd")

const MSK: = 3 * 3600
const WEEK: = 7 * 86400
# Monday 1970-01-05 04:00 МСК = 01:00 UTC: the week grid of every calendar thing (Странствие uses the same grid)
const WEEK_ORIGIN: = 4 * 86400 + 4 * 3600 - MSK
const SEASON_WEEKS: = 4
# season id 742 starts on Monday 23 November 2026, 04:00 МСК: that one is «Сезон 1» of 0.10
const SEASON_ONE: = 742

# UX_RULES §4.2/§4.3 words that must never reach the screen (the lint list is the heroine stop list §2.7)
const UI_BANNED: = ["гарант", "пити", "pity", "гача", "ролл", "крутк", "фивер", "ивент", "ульта", "донат", "богин",
	"лихорадк", "режим", "квартал", "перк", "%", "₽", "эло", "elo", "ммр", "mmr"]
const UI_BANNED_WORDS: = ["ДР", "ИИ-шка", "R", "SR", "SSR+"]

static var test_S = null          # selftests: a dict that stands in for G.S
static var fake_now: = 0          # selftests: frozen unix time (0 = V10Meta clock)
static var sink: Callable = Callable()   # selftests: replaces the payout (rewards, src)
static var no_disk: = false       # selftests: never call G.save()
static var _cls: = {}


# ---------------------------------------------------------------- classes and the save

static func klass(n: String) -> Script:
	if _cls.has(n):
		return _cls[n]
	var s: Script = null
	for c in ProjectSettings.get_global_class_list():
		if String(c.get("class", "")) == n:
			s = load(String(c.path))
			break
	_cls[n] = s
	return s


static func has_fn(s: Object, fn: String) -> bool:
	if s == null:
		return false
	if s is Script:
		for m in (s as Script).get_script_method_list():
			if String(m.get("name", "")) == fn:
				return true
		return false
	return s.has_method(fn)


static func has_g() -> bool:
	var tree: = Engine.get_main_loop() as SceneTree
	return tree != null and tree.root.get_node_or_null("G") != null


static var _mem: = {}

static func save() -> Dictionary:
	if test_S != null:
		return test_S
	if has_g() and G.S is Dictionary:
		return G.S
	return _mem


static func save_game() -> void:
	if no_disk or test_S != null or not has_g():
		return
	G.save()


# ---------------------------------------------------------------- time

static func now() -> int:
	if fake_now != 0:
		return fake_now
	return META.now_unix()


static func day_key() -> String:
	if fake_now != 0:
		return META.key_of(fake_now)
	return META.day_key()


static func cal_key(t: int = -1) -> String:
	return META.cal_key(now() if t < 0 else t)


static func week_id(t: int) -> int:
	return floori(float(t - WEEK_ORIGIN) / float(WEEK))


static func week_start(wid: int) -> int:
	return WEEK_ORIGIN + wid * WEEK


static func week_end(wid: int) -> int:
	return week_start(wid + 1)


static func season_id(t: int) -> int:
	return floori(float(week_id(t)) / float(SEASON_WEEKS))


static func season_num(sid: int) -> int:
	return sid - SEASON_ONE + 1


static func season_start(sid: int) -> int:
	return week_start(sid * SEASON_WEEKS)


static func season_end(sid: int) -> int:
	return season_start(sid + 1)


static func date_msk(t: int) -> String:
	return META.fmt_msk(t)


# «до пн, 21 декабря, 04:00 МСК»
static func until_text(t_end: int) -> String:
	return "до " + date_msk(t_end)


# spec §1.2 / UX §4.1.7: a countdown «чч:мм» only in the last 48 h; before that the date alone
static func countdown(t_end: int, t_now: int = -1) -> String:
	if t_now < 0:
		t_now = now()
	var left: = t_end - t_now
	if left <= 0 or left > 48 * 3600:
		return ""
	return "%02d:%02d" % [left / 3600, (left % 3600) / 60]


# ---------------------------------------------------------------- deterministic randomness

static func hseed(parts: Array) -> int:
	var s: = "|".join(parts.map(func(x): return str(x)))
	return absi(s.hash()) & 0x3fffffff


static func rng(seed_v: int, stream: String) -> RandomNumberGenerator:
	var r: = RandomNumberGenerator.new()
	r.seed = hseed([seed_v, stream])
	return r


static func shuffle(arr: Array, r: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j: = r.randi() % (i + 1)
		var x = arr[i]
		arr[i] = arr[j]
		arr[j] = x


# ---------------------------------------------------------------- text

static func lint(text: String) -> Array:
	var bad: Array = LINT.check(text)
	var low: = text.to_lower()
	for w in UI_BANNED:
		if low.find(w) >= 0:
			bad.append(w)
	var words: = text.replace("·", " ").replace(",", " ").replace(".", " ").replace("«", " ").replace("»", " ").split(" ", false)
	for w in words:
		if w in UI_BANNED_WORDS:
			bad.append(w)
	return bad


static func fmt_int(n: int) -> String:
	var neg: = n < 0
	var s: = str(absi(n))
	var out: = ""
	while s.length() > 3:
		out = " " + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("−" if neg else "") + s + out


static func fmt_delta(n: int) -> String:
	if n > 0:
		return "+" + fmt_int(n)
	if n < 0:
		return "−" + fmt_int(-n)
	return "±0"


# milliseconds of the process clock, for benchmarks and test timeouts only (never for game logic: that is V10Meta)
static func tick_ms() -> int:
	return int(Engine.get_singleton("Time").call("get_ticks_msec"))


static func plural(n: int, one: String, few: String, many: String) -> String:
	var m10: = absi(n) % 10
	var m100: = absi(n) % 100
	if m10 == 1 and m100 != 11:
		return one
	if m10 >= 2 and m10 <= 4 and (m100 < 12 or m100 > 14):
		return few
	return many


static func times_text(n: int) -> String:
	return "%d %s" % [n, plural(n, "раз", "раза", "раз")]


# ---------------------------------------------------------------- heroines

# the heroines of this build, in the game's order (G.HERO_ORDER first); anyone not in G.HEROES is hidden
static func released() -> Array:
	if not has_g():
		return ["mc", "rin", "hana", "yue", "nova"]
	var out: = []
	for h in G.HERO_ORDER:
		out.append(String(h))
	for h in G.HEROES:
		if not String(h) in out:
			out.append(String(h))
	return out


static func is_released(h: String) -> bool:
	return h in released()


const NAMES: = {"mc": "Маджонг-тян", "rin": "Рин", "hana": "Хана", "tsubame": "Цубамэ", "miel": "Миэль",
	"lian": "Лянь", "jess": "Джесс", "tsuru": "Цуру", "yue": "Юэ", "nova": "Нова", "kohaku": "Кохаку", "shirin": "Ширин",
	"mari": "Марисоль", "hibana": "Хибана", "nemi": "Неми", "zlata": "Злата", "minamo": "Минамо", "kira": "Кира",
	"vesper": "Веспер", "sigrid": "Сигрид"}
# genitive for «больше пар, чем …» is the nominative in Russian; «у Ханы» needs the genitive
const GEN: = {"mc": "Маджонг-тян", "rin": "Рин", "hana": "Ханы", "yue": "Юэ", "nova": "Новы", "tsubame": "Цубамэ",
	"miel": "Миэль", "lian": "Лянь", "jess": "Джесс", "tsuru": "Цуру", "kohaku": "Кохаку", "shirin": "Ширин",
	"mari": "Марисоль", "hibana": "Хибаны", "nemi": "Неми", "zlata": "Златы", "minamo": "Минамо", "kira": "Киры",
	"vesper": "Веспер", "sigrid": "Сигрид"}


static func hero_name(h: String) -> String:
	if has_g() and G.HEROES.has(h):
		return String(G.HEROES[h].name)
	return String(NAMES.get(h, h))


static func hero_gen(h: String) -> String:
	return String(GEN.get(h, hero_name(h)))


static func hero_color(h: String) -> Color:
	if has_g() and G.HEROES.has(h):
		return G.HEROES[h].color
	var cos: = klass("V10ProfileCos")
	if cos:
		var row = cos.get("ROSTER").get(h) if cos.get("ROSTER") is Dictionary else null
		if row is Array and row.size() > 1:
			return Color(String(row[1]))
	return Color(0.91, 0.77, 0.49)


# ---------------------------------------------------------------- the payout (ONE function)

# rewards: {gems, petals, aff: {hero: n}, frame: id, title: id}. Returns the cascade rows for the UI:
# [{kind, n, text, hero?, id?}]. Crystals and Лепестки go through the economy facade when it is wired
# (G.econ.grant({"crystal": n, "petal": m}, src)); before that through the 0.10 glossary keys of G.S.
# Affection only through V10Bond.gain(h, n, "duel_friendly"); frames and titles only through V10ProfileCos.grant.
static func apply_rewards(rewards: Dictionary, src: String) -> Array:
	var rows: = reward_rows(rewards)
	if rewards.is_empty():
		return rows
	if sink.is_valid():
		sink.call(rewards.duplicate(true), src)
		return rows
	var gems: = int(rewards.get("gems", 0))
	var petals: = int(rewards.get("petals", 0))
	if (gems > 0 or petals > 0) and has_g():
		var g: = {}
		if gems > 0:
			g["gems"] = gems
		if petals > 0:
			g["petals"] = petals
		V10Money.grant(g, src)
	var aff: Dictionary = rewards.get("aff", {})
	for h in aff:
		bond(String(h), int(aff[h]))
	for k in ["frame", "title"]:
		var id: = String(rewards.get(k, ""))
		if id != "":
			cos_grant(id)
	return rows


static func reward_rows(rewards: Dictionary) -> Array:
	var out: = []
	if int(rewards.get("gems", 0)) > 0:
		var n: = int(rewards.gems)
		out.append({"kind": "gems", "n": n, "text": "%s %s" % [fmt_int(n), plural(n, "кристалл", "кристалла", "кристаллов")]})
	if int(rewards.get("petals", 0)) > 0:
		var n: = int(rewards.petals)
		out.append({"kind": "petals", "n": n, "text": "%s %s" % [fmt_int(n), plural(n, "Лепесток", "Лепестка", "Лепестков")]})
	var aff: Dictionary = rewards.get("aff", {})
	for h in aff:
		out.append({"kind": "aff", "n": int(aff[h]), "hero": String(h), "text": "+%d симпатии · %s" % [int(aff[h]), hero_name(String(h))]})
	for k in ["frame", "title"]:
		var id: = String(rewards.get(k, ""))
		if id != "":
			out.append({"kind": k, "n": 1, "id": id, "text": ("Рамка «%s»" if k == "frame" else "Титул «%s»") % cos_name(id)})
	return out


# the soft source of spec §2.4 «дружеская дуэль +1» (registered in V10Bond.SOFT as "duel_friendly")
const BOND_SRC: = "duel_friendly"

static func bond(h: String, n: int) -> int:
	var b: = klass("V10Bond")
	if b == null:
		b = load("res://scripts/v10/meta/bond.gd")
	if b:
		return int(b.call("gain", h, n, BOND_SRC))
	return 0


static func cos_grant(id: String) -> bool:
	var cos: = klass("V10ProfileCos")
	if cos and has_g():
		return bool(cos.call("grant", save(), id))
	var own = save().get("v10_cos_owned", {})
	if not (own is Dictionary):
		own = {}
	var fresh: bool = not (own as Dictionary).has(id)
	own[id] = true
	save()["v10_cos_owned"] = own
	return fresh


static func cos_name(id: String) -> String:
	var R: Script = load("res://scripts/v10/duels/duel_rank.gd")
	for e in R.call("cos_defs"):
		if String(e.id) == id:
			return String(e.name)
	return id


static func record_game(won: bool) -> void:
	if test_S != null or not has_g():
		return
	if G.has_method("record_game"):
		G.record_game("duel", won)
