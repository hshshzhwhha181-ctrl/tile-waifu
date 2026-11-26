class_name V10Bond
extends RefCounted

# V10Bond — the ONE entry for affection (docs/0.10-spec.md §2.4). Direct G.add_aff() outside this file is
# forbidden (grep selftest in meta_selftest).
#
#   V10Bond.gain(h, n, src) -> int     adds affection and returns what was actually given (0 at the cap)
#   V10Bond.soft_today(h) -> int       soft points given to `h` today (resets at 04:00 with V10Meta.day_key)
#   V10Bond.capped(h) -> bool          soft cap reached
#   V10Bond.chip_text(n) -> "+3"       the chip at the heart, always shown when something was given
#   V10Bond.today_text(h) -> String    "" below the cap; «На сегодня она уже счастлива» at 25 (grey, no «+0»).
#                                      No «сегодня 22/25» counter: UX_RULES §4.1 п.7 and §8.5 forbid limit counters
#                                      around the heroine (they turn affection into a duty); UX_RULES wins over spec §2.4
#   V10Bond.touch_left(h) -> int       today's touches left (sub-limit 3 of the soft cap)
#
# SOFT sources share one cap of 25 a heroine a day: touch +1 (own sub-limit 3/day, as 0.9), letter reply
# (REPLY_AFF of 0.9), finished chat branch +3, feed like +1, feed reply +2, Чтение руки +2, friendly duel +1, salon
# guest (1.1). HARD sources pass the cap: gift, date, heroine birthday, comeback, streak milestone, first view of a
# zone scene, and the 0.9 level win (+10, unchanged). An unknown source counts as SOFT (the safe side) with a warning.
#
# Storage: S.v10_meta.bond = {key: day_key, h: {hero: {soft, touch}}} (a day's counters, reset on a new key).
# Applying: sink(h, n) — by default G.add_aff (the only allowed call site); selftests swap it for a dict.

const SOFT_CAP: = 25
const TOUCH_CAP: = 3

const SOFT: = ["touch", "letter_reply", "chat_branch", "feed_like", "feed_reply", "hand", "duel_friendly", "salon_guest", "egg"]
# W1 integration: the 0.9 match/mode/story sources keep their 0.9 amounts (pair, match_gift, special, story, mode_win, duel)
const HARD: = ["gift", "date", "bday", "comeback", "streak_milestone", "zone_scene_first", "level_win", "event_win",
	"pair", "match_gift", "special", "story", "mode_win", "duel"]

const T_HAPPY: = "На сегодня она уже счастлива"

static var sink: Callable = Callable()


static func _day() -> Dictionary:
	var b: Dictionary = V10Meta.st().bond
	var k: = V10Meta.day_key()
	if str(b.get("key", "")) != k:
		b["key"] = k
		b["h"] = {}
	return b.h


static func _rec(h: String) -> Dictionary:
	var d: = _day()
	if not d.has(h):
		d[h] = {"soft": 0, "touch": 0}
	return d[h]


static func is_hard(src: String) -> bool:
	return src in HARD


static func gain(h: String, n: int, src: String) -> int:
	if n <= 0 or h == "":
		return 0
	if not (src in SOFT) and not (src in HARD):
		push_warning("V10Bond.gain: unknown source '%s' — counted as soft" % src)
	var give: = n
	if not is_hard(src):
		var r: = _rec(h)
		if src == "touch":
			if int(r.touch) >= TOUCH_CAP:
				return 0
		give = mini(n, SOFT_CAP - int(r.soft))
		if give <= 0:
			return 0
		r.soft = int(r.soft) + give
		if src == "touch":
			r.touch = int(r.touch) + 1
	_apply(h, give)
	return give


static func _apply(h: String, n: int) -> void:
	if sink.is_valid():
		sink.call(h, n)
		return
	G.add_aff(h, n)


static func soft_today(h: String) -> int:
	return int(_rec(h).soft)


static func touch_left(h: String) -> int:
	return maxi(0, TOUCH_CAP - int(_rec(h).touch))


static func capped(h: String) -> bool:
	return soft_today(h) >= SOFT_CAP


static func chip_text(n: int) -> String:
	return "+%d" % n if n > 0 else ""


static func today_text(h: String) -> String:
	return T_HAPPY if soft_today(h) >= SOFT_CAP else ""
