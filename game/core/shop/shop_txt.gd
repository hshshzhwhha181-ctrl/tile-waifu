class_name V10ShopTxt
extends RefCounted

# V10ShopTxt — every visible string of Лавка 2 that carries a number goes through here, so the vocabulary of
# UX_RULES §4.2/§4.3/§5 is enforced in one place: «желание» (never «крутка»), «= N желаний», «≈ N ₽ за желание»,
# «Пополнить», no «ВЫГОДНО», no «−N%», dates instead of countdowns.

# UX §4.3 jargon + the «было» names of §4.2 that could reach a shop string (substring, any case)
const BANNED_UI: = ["крутк", "гача", "ролл", "донат", "ВЫГОДНО", "ХИТ", "BEST", "NEW", "успей", "последний шанс",
	"только сегодня", "гарант", "pity", "пити", "50/50", "−%", "-%", "скидк", "Камни", "ивент", "фивер", "ульта",
	"риичи", "квартал", "перк", "банер", "топ-100", "Гардероб", "Поручени", "Визиты", "Рядом с тобой", "Лихорадк",
	"Лунная лестница", "Чайный абонемент", "Богин"]
# tokens that need word edges / numbers (case-sensitive): SR, SR+, SSR+, R as a rarity, −N%, +N%, «осталось N штук»,
# ID outside «О игре» (VK ID / Яндекс ID are product names), «ещё N … сегодня» (UX §4.1.7)
const BANNED_RE: = ["(?<![A-Za-z])SR\\+?(?![A-Za-z])", "SSR\\+", "(?<![A-Za-zА-Яа-яЁё])R(?![A-Za-zА-Яа-яЁё])",
	"[−-]\\s?\\d+\\s?%", "\\+\\s?\\d+\\s?%", "(?i)осталось\\s+\\d+\\s+шт", "(?<!VK )(?<!Яндекс )(?<![A-Za-z])ID(?![A-Za-z])",
	"(?i)ещё\\s+\\d+[^.·]*сегодня"]
static var _re: Array = []

const MONTHS_GEN: = ["января", "февраля", "марта", "апреля", "мая", "июня", "июля", "августа", "сентября", "октября",
	"ноября", "декабря"]
const MONTHS_SHORT: = ["янв", "фев", "мар", "апр", "мая", "июн", "июл", "авг", "сен", "окт", "ноя", "дек"]
const WEEKDAYS: = ["вс", "пн", "вт", "ср", "чт", "пт", "сб"]


static func plural(n: int, one: String, few: String, many: String) -> String:
	var a: = absi(n) % 100
	if a >= 11 and a <= 14:
		return many
	match a % 10:
		1:
			return one
		2, 3, 4:
			return few
	return many


# 12 345 with a no-break thin grouping space
static func num(n: int) -> String:
	var s: = str(absi(n))
	var out: = ""
	while s.length() > 3:
		out = "\u00a0" + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


static func rub(n: float) -> String:
	return V10Sku.rub(n)


# one decimal with a comma, trimmed («1,2», «6»)
static func dec(v: float) -> String:
	var r: = snappedf(v, 0.1)
	if absf(r - roundf(r)) < 0.05:
		return str(int(roundf(r)))
	return ("%.1f" % r).replace(".", ",")


static func wishes(v: float) -> String:
	var r: = snappedf(v, 0.1)
	if absf(r - roundf(r)) < 0.05:
		var n: = int(roundf(r))
		return "%d %s" % [n, plural(n, "желание", "желания", "желаний")]
	return "%s желания" % dec(r)


static func eq_wishes(v: float) -> String:
	var r: = snappedf(v, 0.1)
	return ("= " if absf(r - roundf(r)) < 0.05 else "≈ ") + wishes(v)


static func per_wish(rub_per: float) -> String:
	return V10Sku.per_wish(rub_per)


# «450 Лунного камня», «2 билета», «2 000 монет», «120 заварки», «1 рамка»
static func amount(cur: String, n: int) -> String:
	match cur:
		"moon":
			return "%s %s" % [num(n), "Лунный камень" if n == 1 else "Лунного камня"]
		"crystal":
			return "%s %s" % [num(n), plural(n, "кристалл", "кристалла", "кристаллов")]
		"coin":
			return "%s %s" % [num(n), plural(n, "монета", "монеты", "монет")]
		"wish":
			return "%s %s" % [num(n), plural(n, "билет", "билета", "билетов")]
		"petal":
			return "%s %s" % [num(n), plural(n, "лепесток", "лепестка", "лепестков")]
		"wax":
			return "%s воска" % num(n)
		"tea":
			return "%s заварки" % num(n)
	return "%s %s" % [num(n), cur]


static func cur_name(cur: String) -> String:
	return {"moon": "Лунный камень", "crystal": "Кристаллы", "wish": "Билеты", "petal": "Лепестки", "coin": "Монеты"}.get(cur, cur)


# items of a grant, collapsed by id: boosters «2 Фонарика», frames «рамка»
const ITEM_NAMES: = {
	"boost_lantern": ["Фонарик", "Фонарика", "Фонариков"],
	"boost_wind": ["Ветер", "Ветра", "Ветров"],
	"boost_scroll": ["Свиток", "Свитка", "Свитков"],
}


static func items_line(items: Array) -> Array:
	var cnt: = {}
	var order: = []
	for i in items:
		var k: = String(i)
		if not cnt.has(k):
			order.append(k)
		cnt[k] = int(cnt.get(k, 0)) + 1
	var out: = []
	for k in order:
		var f: Array = ITEM_NAMES.get(k, [])
		if f.is_empty():
			out.append(k)
		else:
			out.append("%d %s" % [cnt[k], plural(cnt[k], f[0], f[1], f[2])])
	return out


# calendar date in Moscow time: «пн, 22 марта, 04:00 МСК» (UX: dates, not countdowns)
static func date_msk(unix: int, with_time: = true) -> String:
	var d: = Time.get_datetime_dict_from_unix_time(unix + 3 * 3600)
	var s: = "%s, %d %s" % [WEEKDAYS[int(d.weekday)], int(d.day), MONTHS_GEN[int(d.month) - 1]]
	if with_time:
		s += ", %02d:%02d МСК" % [int(d.hour), int(d.minute)]
	return s


static func date_short(unix: int) -> String:
	var d: = Time.get_datetime_dict_from_unix_time(unix + 3 * 3600)
	return "%d %s" % [int(d.day), MONTHS_SHORT[int(d.month) - 1]]


# the only countdown allowed: last 48 h of a calendar event, the same for everyone (UX С-6)
static func until_msk(end_unix: int, now: int) -> String:
	var left: = end_unix - now
	if left <= 0:
		return "завершено"
	if left <= 48 * 3600:
		return "ещё %d ч %02d мин" % [left / 3600, (left % 3600) / 60]
	return "до " + date_msk(end_unix)


static func lint(s: String) -> Array:
	var bad: = []
	for w in BANNED_UI:
		if s.findn(w) >= 0:
			bad.append(w)
	if _re.is_empty():
		for p in BANNED_RE:
			var r: = RegEx.new()
			r.compile(p)
			_re.append(r)
	for i in _re.size():
		if (_re[i] as RegEx).search(s) != null:
			bad.append(BANNED_RE[i])
	return bad
