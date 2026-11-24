class_name V10TowerUtil
extends RefCounted

# Shared helpers of the tower track (Пагода Луны + Странствие). Pure functions, no scene access.
#
# Time. Spec §2.5: one clock (V10Meta). Until V10Meta lands this module goes through the existing
# V7EventData.now_unix() (local wall time, also honours --event_now=) and converts it back to UTC; it never
# calls Time.get_unix_time_from_system itself, so the §2.5 grep selftest stays clean.
# Calendar weeks (Странствие, the weekly Pagoda table) start on Monday 04:00 MSK for everyone.
#
# Numbers. Spec §2.2: every reward comes from economy.json via V10Econ. Until it lands, ECON below is the
# single local source; econ(key) prefers V10Econ.get_num(key) when that class exists.

const MSK_OFFSET: = 3 * 3600
const WEEK: = 7 * 86400
# 1970-01-05 was a Monday; the week starts at Monday 04:00 MSK = Monday 01:00 UTC
const WEEK_ORIGIN: = 4 * 86400 + 4 * 3600 - MSK_OFFSET

const ECON: = {
	# Пагода Луны (spec R2 / §2.3)
	"pagoda.miles": [[5, 50], [10, 75], [15, 100], [20, 125], [30, 150], [50, 200]],  # floor -> gems, once ever (700)
	"pagoda.offering": [[5, 20], [10, 40], [15, 60]],  # best floor of the week -> gems, once a week (<= 60)
	"pagoda.guard_coins_base": 20,
	"pagoda.guard_coins_per_floor": 5,
	"pagoda.guard_petals": 5,  # once per run, on its first guard chest
	# Странствие (spec R3 / §2.3)
	"journey.boards_gems": [[1, 30], [3, 60], [5, 100]],  # boards cleared (best attempt) -> gems
	"journey.tier_gems": [20, 40, 60],  # Бронза / Серебро / Золото
	"journey.tier_score": [4000, 7000, 10000],
	"journey.full_tickets": 1,
	"journey.full_petals": 15,
	"journey.full_pass_xp": 100,
	"journey.attempts": 2,
}

static func econ(key: String):
	var cls: = _class_script("V10Econ")
	if cls and _script_has(cls, "get_num"):
		var v = cls.call("get_num", key)
		if v != null:
			return v
	return ECON.get(key)

static func _class_script(n: String) -> Script:
	for c in ProjectSettings.get_global_class_list():
		if String(c.get("class", "")) == n:
			return load(String(c.path))
	return null

static func _script_has(s: Script, fn: String) -> bool:
	for m in s.get_script_method_list():
		if String(m.get("name", "")) == fn:
			return true
	return false

# ---------------------------------------------------------------- time

# test override (selftests set it; 0 = real clock)
static var fake_now: = 0

static func now_utc() -> int:
	if fake_now != 0:
		return fake_now
	var m: = _class_script("V10Meta")
	if m and _script_has(m, "now_unix"):
		return int(m.call("now_unix"))
	var bias: = int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	return int(V7EventData.now_unix()) - bias

# week index since the origin; a new week starts on Monday 04:00 MSK
static func week_id(t_utc: int) -> int:
	return floori(float(t_utc - WEEK_ORIGIN) / float(WEEK))

static func cur_week() -> int:
	return week_id(now_utc())

static func week_start(wid: int) -> int:
	return WEEK_ORIGIN + wid * WEEK

static func week_end(wid: int) -> int:
	return week_start(wid + 1)

const MONTHS: = ["января", "февраля", "марта", "апреля", "мая", "июня", "июля", "августа", "сентября", "октября", "ноября", "декабря"]
const WDAYS: = ["пн", "вт", "ср", "чт", "пт", "сб", "вс"]

# «пн, 22 марта, 04:00 МСК» — calendar text, always with the zone (spec §2.5)
static func week_refresh_text(wid: int) -> String:
	var t: = week_end(wid) + MSK_OFFSET
	var d: = Time.get_datetime_dict_from_unix_time(t)
	var wd: = posmod(int(d.weekday) - 1, 7)
	return "%s, %d %s, %02d:%02d МСК" % [WDAYS[wd], int(d.day), MONTHS[int(d.month) - 1], int(d.hour), int(d.minute)]

# Spec §1.2: a calendar countdown is shown only in the last 48 h; before that only the date.
static func show_countdown(wid: int, t_utc: int) -> bool:
	return week_end(wid) - t_utc <= 48 * 3600

# ---------------------------------------------------------------- deterministic randomness

static func rng(seed_v: int, stream: String) -> RandomNumberGenerator:
	var r: = RandomNumberGenerator.new()
	r.seed = hash("%d|%s" % [seed_v, stream])
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

# ---------------------------------------------------------------- heroes

# heroines present in the build (G.HEROES); goddesses of later waves stay hidden until they are added
static func released() -> Array:
	var out: = []
	for h in G.HERO_ORDER:
		out.append(String(h))
	for h in G.HEROES:
		if not String(h) in out:
			out.append(String(h))
	return out

static func owned() -> Array:
	return released().filter(func(h): return G.hero_unlocked(h))

static func hero_name(h: String) -> String:
	if G.HEROES.has(h):
		return String(G.HEROES[h].name)
	return String(ROSTER_NAMES.get(h, h))

# docs/ROSTER_20.md: the 20 goddesses (id -> name) for NPC records; only released ones are shown in the game
const ROSTER: = ["mc", "rin", "hana", "tsubame", "miel", "lian", "jess", "tsuru", "yue", "nova", "kohaku", "shirin",
	"mari", "hibana", "nemi", "zlata", "minamo", "kira", "vesper", "sigrid"]
const ROSTER_NAMES: = {"mc": "Маджонг-тян", "rin": "Рин", "hana": "Хана", "tsubame": "Цубамэ", "miel": "Миэль",
	"lian": "Лянь", "jess": "Джесс", "tsuru": "Цуру", "yue": "Юэ", "nova": "Нова", "kohaku": "Кохаку", "shirin": "Ширин",
	"mari": "Марисоль", "hibana": "Хибана", "nemi": "Неми", "zlata": "Злата", "minamo": "Минамо", "kira": "Кира",
	"vesper": "Веспер", "sigrid": "Сигрид"}
const ROSTER_RANK: = {"mc": "A", "rin": "A", "hana": "A", "tsubame": "A", "miel": "A", "lian": "A", "jess": "A", "tsuru": "A",
	"yue": "S", "nova": "S", "kohaku": "S", "shirin": "S", "mari": "S", "hibana": "S", "nemi": "S",
	"zlata": "SSR", "minamo": "SSR", "kira": "SSR", "vesper": "SSR", "sigrid": "SSR"}

# Russian plural: plural(5, "этаж", "этажа", "этажей")
static func plural(n: int, one: String, few: String, many: String) -> String:
	var m10: = n % 10
	var m100: = n % 100
	if m10 == 1 and m100 != 11:
		return one
	if m10 >= 2 and m10 <= 4 and (m100 < 12 or m100 > 14):
		return few
	return many

static func fmt_mult(m: float) -> String:
	return ("×%.1f" % m).replace(".", ",")

static func fmt_mult2(m: float) -> String:
	return ("×%.2f" % m).replace(".", ",")

# reward dict helper: {gems, coins, petals, tickets, pass_xp}; zero fields are dropped
static func reward_add(a: Dictionary, b: Dictionary) -> Dictionary:
	var out: = a.duplicate()
	for k in b:
		out[k] = int(out.get(k, 0)) + int(b[k])
	for k in out.keys():
		if int(out[k]) == 0:
			out.erase(k)
	return out
