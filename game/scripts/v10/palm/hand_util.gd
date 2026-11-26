class_name V10HandUtil
extends RefCounted

# «Чтение руки» (spec 0.10 R4) — shared helpers. Pure functions, no scene access except the soft G lookups.
#
# CLASS LOOKUP  cls(name) -> Script | null     soft lookup by class_name (cached), the tower pattern: other lanes
#                                              (V10Econ facade, V10Save, V10ProfileCos, V10Glossary) may be absent
# NUMBERS       econ(key)                      ECON below, or V10Econ.get_num(key) when the facade grows one (§2.2)
# TIME          day_key() / day_index(key) / clock_ok()   — only through V10Meta (spec §2.5: one clock)
# DETERMINISM   h32(text) FNV-1a 32 bit (stable across builds) · rng(seed, stream) · shuffle(arr, rng) · pick
# HEROINES      released() / hero_for_day(day_idx) / hero_name(h) / hero_color(h)
# REWARDS       grant(rewards, src) -> Array   THE one place that applies this module's rewards (see README «Награды»)
# LINT          lint(texts) -> Array           V10Lint.BANNED + UX §4.3 jargon + this mode's own stop words

const ECON: = {
	"hand.gems": [10, 20, 30],      # верная догадка × смелость 1 / 2 / 3 (spec §2.3)
	"hand.gems_wrong": 5,           # неверная догадка
	"hand.bond": 2,                 # симпатия героине дня, мягкий источник (§2.4)
	"hand.gate_level": 30,          # открывается с L30 (UX §3.5)
	"hand.cos_correct": 30,         # рамка «Читающая руки» и титул: 30 верных догадок
	"hand.school_days": 7,          # первые 7 сыгранных дней — с подсказкой
}

const FOUNDERS: = ["mc", "rin", "hana", "yue", "nova"]
const MONTHS: = ["января", "февраля", "марта", "апреля", "мая", "июня", "июля", "августа", "сентября", "октября",
	"ноября", "декабря"]

# UX_RULES §4.3 (visible-string jargon), §4.2 «было», HEROINES red lines (no school theme), and this mode's own rule
# (spec R4: only «догадка» — never «ставка» or «пари»). Lower-case substrings.
const OWN_BANNED: = ["ставк", "ставок", "спорим", "пари", "школ", "урок", "ученик", "учител", "академ", "богин", "ульта", "ульты", "риичи",
	"темпай", " яку", "гарант", "пити", "гача", "крутк", "фивер", "ивент", "донат", "лихорад", "режимы", "%", "₽", " кр ",
	" кр.", "сек.", "мин.", "шт."]


static var _cls_cache: = {}


static func cls(n: String) -> Script:
	if _cls_cache.has(n):
		return _cls_cache[n]
	var s: Script = null
	for c in ProjectSettings.get_global_class_list():
		if String(c.get("class", "")) == n:
			s = load(String(c.path))
			break
	_cls_cache[n] = s
	return s


static func has_fn(s: Script, fn: String) -> bool:
	if s == null:
		return false
	for m in s.get_script_method_list():
		if String(m.get("name", "")) == fn:
			return true
	return false


static func econ(key: String):
	var c: = cls("V10Econ")
	if c and has_fn(c, "get_num"):
		var v = c.call("get_num", key)
		if v != null:
			return v
	return ECON.get(key)


static func g_ok() -> bool:
	var tree: = Engine.get_main_loop() as SceneTree
	return tree != null and tree.root != null and tree.root.get_node_or_null("G") != null


# ---------------------------------------------------------------- time (V10Meta only)

static func day_key() -> String:
	return V10Meta.day_key()


static func clock_ok() -> bool:
	return V10Meta.clock_ok()


static func day_index(key: String) -> int:
	return V10Meta.day_index(key)


static func key_of_index(d: int) -> String:
	return Time.get_date_string_from_unix_time(d * 86400)


# 0 = Monday … 6 = Sunday (1970-01-01 was a Thursday)
static func weekday(d: int) -> int:
	return posmod(d + 3, 7)


# «24 ноября»
static func date_text(key: String) -> String:
	var p: = key.split("-")
	if p.size() != 3:
		return key
	return "%d %s" % [int(p[2]), MONTHS[clampi(int(p[1]) - 1, 0, 11)]]


# ---------------------------------------------------------------- determinism

# FNV-1a 32 bit over UTF-8: the same number on every build and platform (the deal must never depend on the engine's
# own String.hash, which is free to change between versions)
static func h32(text: String) -> int:
	var h: = 2166136261
	for b in text.to_utf8_buffer():
		h = ((h ^ b) * 16777619) & 0xFFFFFFFF
	return h


static func rng(seed_v: int, stream: String) -> RandomNumberGenerator:
	var r: = RandomNumberGenerator.new()
	r.seed = h32("%d|%s" % [seed_v, stream])
	return r


# own Fisher–Yates (Array.shuffle uses the global generator, which is not seeded)
static func shuffle(arr: Array, r: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j: = r.randi() % (i + 1)
		var x = arr[i]
		arr[i] = arr[j]
		arr[j] = x


static func pick(arr: Array, r: RandomNumberGenerator):
	return arr[r.randi() % arr.size()] if not arr.is_empty() else null


# ---------------------------------------------------------------- heroines

# the founders first (fixed order), then every later heroine present in G.HEROES in its release order
static func released() -> Array:
	var out: = FOUNDERS.duplicate()
	if g_ok():
		for h in G.HERO_ORDER:
			if not String(h) in out:
				out.append(String(h))
		for h in G.HEROES:
			if not String(h) in out:
				out.append(String(h))
	return out


# heroine of the day: deterministic by the day index; a released heroine joins the rotation from her release on
static func hero_for_day(d: int, pool: Array = []) -> String:
	var hs: = pool if not pool.is_empty() else released()
	return String(hs[posmod(d, hs.size())])


static func hero_name(h: String) -> String:
	if g_ok() and G.HEROES.has(h):
		return String(G.HEROES[h].name)
	return {"mc": "Маджонг-тян", "rin": "Рин", "hana": "Хана", "yue": "Юэ", "nova": "Нова"}.get(h, h)


static func hero_color(h: String) -> Color:
	if g_ok() and G.HEROES.has(h):
		return G.HEROES[h].color
	return Color(1.0, 0.56, 0.72)


# ---------------------------------------------------------------- text helpers

static func plural(n: int, one: String, few: String, many: String) -> String:
	var m10: = absi(n) % 10
	var m100: = absi(n) % 100
	if m10 == 1 and m100 != 11:
		return one
	if m10 >= 2 and m10 <= 4 and (m100 < 12 or m100 > 14):
		return few
	return many


static func gems_text(n: int) -> String:
	return "+%d %s" % [n, plural(n, "кристалл", "кристалла", "кристаллов")]


# ---------------------------------------------------------------- rewards

# Tests set sink: Callable(kind: String, value, src: String) and nothing reaches G.
static var sink: Callable = Callable()


# rewards: {gems: int, aff: {hero: n}, cos: [ids]}. Applies through the economy facade when the integrator wired it
# (G.econ.grant({"crystal": n}, src), economy README «g.gd»), else the 0.9 counter S.gems; affection only through
# V10Bond.gain (soft source "palm" if V10Bond knows it, else the registered "hand"); cosmetics through
# V10ProfileCos.grant. Returns rows [{kind, n|id|hero}] of what was applied.
static func grant(rewards: Dictionary, src: String = "hand") -> Array:
	var rows: = []
	var gems: = int(rewards.get("gems", 0))
	if gems > 0:
		rows.append({"kind": "gems", "n": gems})
		if sink.is_valid():
			sink.call("gems", gems, src)
		elif g_ok():
			var e = G.get("econ")
			if e != null and e is Object and (e as Object).has_method("grant"):
				(e as Object).call("grant", {"crystal": gems}, src)
			elif G.S is Dictionary:
				G.S["gems"] = int(G.S.get("gems", 0)) + gems
	var aff = rewards.get("aff", {})
	if aff is Dictionary:
		for h in aff:
			var n: = int(aff[h])
			if n <= 0:
				continue
			if sink.is_valid():
				sink.call("aff", {String(h): n}, bond_src())
				rows.append({"kind": "aff", "hero": String(h), "n": n})
			else:
				rows.append({"kind": "aff", "hero": String(h), "n": V10Bond.gain(String(h), n, bond_src())})
	var cos = rewards.get("cos", [])
	if cos is Array:
		for id in cos:
			rows.append({"kind": "cos", "id": String(id)})
			if sink.is_valid():
				sink.call("cos", String(id), src)
			elif g_ok() and G.S is Dictionary:
				var pc: = cls("V10ProfileCos")
				if pc:
					pc.call("grant", G.S, String(id))
				else:
					var own: Dictionary = G.S.get("v10_cos_owned", {})
					own[String(id)] = true
					G.S["v10_cos_owned"] = own
	return rows


# the soft affection source of this mode: the brief names it "palm"; the meta lane registered "hand" (V10Bond.SOFT)
static func bond_src() -> String:
	return "palm" if "palm" in V10Bond.SOFT else "hand"


# ---------------------------------------------------------------- lint

static func lint_one(text: String) -> Array:
	var bad: Array = V10Lint.check(text)
	var low: = (" " + text.to_lower() + " ")
	for w in OWN_BANNED:
		if low.find(w) >= 0 and not (w in bad):
			bad.append(w)
	return bad


# [{text, bad}] for every dirty string
static func lint(texts: Array) -> Array:
	var out: = []
	for t in texts:
		var b: = lint_one(str(t))
		if not b.is_empty():
			out.append({"text": str(t), "bad": b})
	return out
