class_name V10BdayData
extends RefCounted

# Birthdays of the 20 heroines (docs/0.10-spec.md Р6) and the calendar rules they obey.
# Only heroines present in G.HEROES celebrate (V10Bday filters); 0.10 founders: mc 04-07, rin 11-30, hana 07-18,
# yue 09-17, nova 12-12.

const DATES: = {
	"tsuru": "01-16", "sigrid": "02-06", "miel": "02-27", "zlata": "03-18", "mc": "04-07", "kohaku": "04-27",
	"tsubame": "05-20", "minamo": "06-08", "jess": "06-28", "hana": "07-18", "lian": "08-07", "shirin": "08-27",
	"yue": "09-17", "mari": "09-30", "hibana": "10-15", "nemi": "10-30", "vesper": "11-15", "rin": "11-30",
	"nova": "12-12", "kira": "12-22",
}

# public holidays and sensitive dates a birthday must never fall on (selftest)
const BLOCKED: = ["01-01", "01-02", "01-03", "01-04", "01-05", "01-06", "01-07", "01-08", "02-23", "03-08", "05-01",
	"05-09", "06-12", "06-22", "09-01", "11-04", "12-25", "12-26", "12-27", "12-28", "12-29", "12-30", "12-31"]
const MIN_GAP: = 10

# signature tile icons (until the D3 tile themes give sig_face): founders' emblems
const SIG: = {
	"mc": "res://assets/v10/rituals/sig_mc.webp", "rin": "res://assets/v10/rituals/sig_rin.webp",
	"hana": "res://assets/v10/rituals/sig_hana.webp", "yue": "res://assets/v10/rituals/sig_yue.webp",
	"nova": "res://assets/v10/rituals/sig_nova.webp",
}
const SIG_NAME: = {"mc": "сакура", "rin": "маття", "hana": "подсолнух", "yue": "луна", "nova": "бриллиант"}
const CAKE: = {"mc": "cake_tier", "rin": "cake_matcha", "hana": "cake_tier", "yue": "cake_matcha", "nova": "cake_tier"}

const GOAL_PAIRS: = 24
const WINDOW: = 3
const REWARD: = {"gems": 100, "leaves": 1}
const REWARD_AFF: = 30


static func doy(md: String) -> int:
	# day of a non-leap year, for gaps and windows (Feb 29 is never a heroine's birthday)
	var m: = int(md.substr(0, 2))
	var d: = int(md.substr(3, 2))
	var cum: = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334]
	return cum[m - 1] + d


static func date_of(h: String) -> String:
	return str(DATES.get(h, ""))


static func problems() -> Array:
	var out: = []
	var days: = []
	for h in DATES:
		var md: String = DATES[h]
		if md in BLOCKED:
			out.append("%s on blocked %s" % [h, md])
		days.append([doy(md), h])
	days.sort_custom(func(a, b): return a[0] < b[0])
	for i in days.size():
		var a: Array = days[i]
		var b: Array = days[(i + 1) % days.size()]
		var gap: int = (int(b[0]) - int(a[0]) + 365) % 365
		if gap < MIN_GAP:
			out.append("%s→%s only %d days" % [a[1], b[1], gap])
	return out
