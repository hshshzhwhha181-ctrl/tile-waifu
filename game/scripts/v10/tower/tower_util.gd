class_name V10TowerUtil
extends RefCounted

# Shared helpers of the tower track (Пагода Луны + Странствие). Pure functions, no scene access.
#
# Time. Spec §2.5: one clock (V10Meta.now_unix / cal_key / fmt_msk) with a pure arithmetic fallback when
# running standalone without V10Meta. Zero raw Time.* calls live anywhere in v10/tower.
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

# the global class list does not change while the game runs: look each name up once (econ() and now_utc() are
# called many times per screen; a full scan of the class list each time is wasted work on a mid Android phone)
static var _cls_cache: = {}

static func _class_script(n: String) -> Script:
	if _cls_cache.has(n):
		return _cls_cache[n]
	var s: Script = null
	for c in ProjectSettings.get_global_class_list():
		if String(c.get("class", "")) == n:
			s = load(String(c.path))
			break
	_cls_cache[n] = s
	return s

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
	return int(V7EventData.now_unix()) - MSK_OFFSET

static func cal_key(t_utc: int = -1) -> String:
	var u: = now_utc() if t_utc < 0 else t_utc
	var m: = _class_script("V10Meta")
	if m and _script_has(m, "cal_key"):
		return String(m.call("cal_key", u))
	var cv: = civil_from_unix(u + MSK_OFFSET - 4 * 3600)
	return "%04d-%02d-%02d" % [int(cv.year), int(cv.month), int(cv.day)]

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

# Hinnant's civil-from-days algorithm (pure integer math, zero engine clock calls)
static func civil_from_unix(t_sec: int) -> Dictionary:
	var days: = floori(float(t_sec) / 86400.0)
	var sod: = posmod(t_sec, 86400)
	var z: = days + 719468
	var era: = floori(float(z) / 146097.0)
	var doe: = z - era * 146097
	var yoe: = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365
	var y: = yoe + era * 400
	var doy: = doe - (365 * yoe + yoe / 4 - yoe / 100)
	var mp: = (5 * doy + 2) / 153
	var d: = doy - (153 * mp + 2) / 5 + 1
	var mo: = mp + (3 if mp < 10 else -9)
	if mo <= 2:
		y += 1
	# 1970-01-01 was Thursday (index 3 in 0=Mon..6=Sun)
	var wd_mon: = posmod(days + 3, 7)
	return {"year": y, "month": mo, "day": d, "hour": sod / 3600, "minute": (sod % 3600) / 60, "wd_mon": wd_mon}

# «пн, 22 марта, 04:00 МСК» — calendar text, always with the zone (spec §2.5)
static func week_refresh_text(wid: int) -> String:
	var u_end: = week_end(wid)
	var m: = _class_script("V10Meta")
	if m and _script_has(m, "fmt_msk"):
		return String(m.call("fmt_msk", u_end))
	var d: = civil_from_unix(u_end + MSK_OFFSET)
	return "%s, %d %s, %02d:%02d МСК" % [WDAYS[int(d.wd_mon)], int(d.day), MONTHS[int(d.month) - 1], int(d.hour), int(d.minute)]

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
