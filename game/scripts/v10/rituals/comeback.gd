class_name V10Comeback
extends RefCounted

# V10Comeback — «Она ждала»: warm comeback and Отдых (docs/0.10-spec.md Р5). No guilt, no offers, every scene
# skippable by tap from the first second.
#
#   V10Comeback.tier(gap) -> ""|"warm"|"waited"|"winds"     3–6 days «Чай ещё тёплый» 4 s · 7–29 «Она ждала» 8 s ·
#                                                           30+ «Пять ветров снова дуют» 12 s (stop-frames)
#   V10Comeback.check(key = today) -> Dictionary            call BEFORE the home is built (entry queue, top priority):
#        {tier, gap, rested_add, ladder: ""|"short"|"long", letters: n}; idempotent within a day (second call → tier "")
#   V10Comeback.rested_add(gap) = min(600, (gap − 2) × 60);  pool also capped at RESTED_MAX
#   V10Comeback.consume_rested(pairs, ranked) -> int         pairs doubled for OUTFIT MASTERY (never pass XP, ×1 in
#                                                           ranked); each doubled pair spends 1
#   V10Comeback.ladder_view(key) / ladder_claim(key) -> rows  7-day (gap ≥ 14) or 3-day (7–13) ladder, at most once per
#                                                           60 days; one step per day, a skipped day never burns
#   V10Comeback.notify_plan(last_seen_unix, enabled) -> [unix]  day 3 18:30, then 7, 11 … 27; nothing after 30 days
#   V10Comeback.while_away(gap) -> [{h, ev:"while_away", subj, body}]   ≤7 letters for V9Letters.backfill (hook H5)
# State S.v10_comeback — see V10RitSave.defaults().

const RESTED_MAX: = 600
const LADDER_COOLDOWN: = 60
const NOTIFY_HOUR: = 18
const NOTIFY_MIN: = 30
const SCENE_SECS: = {"warm": 4.0, "waited": 8.0, "winds": 12.0}
const TIER_TITLE: = {"warm": "Чай ещё тёплый", "waited": "Она ждала", "winds": "Пять ветров снова дуют"}

const LADDER_LONG: = [
	{"gems": 150, "hints": 1, "shuffles": 1, "undos": 1},
	{"coins": 1000, "hints": 2},
	{"tickets": 10},
	{"shuffles": 2, "undos": 2},
	{"pick_outfit": true},
	{"gems": 150},
	{"frame": "fr_back", "aff": {"partner": 30}},
]
const LADDER_SHORT: = [
	{"gems": 100},
	{"hints": 2, "shuffles": 1},
	{"tickets": 1},
]
const NOTIFY_TEXT: = ["Чай заварен, место у окна свободно.", "В салоне новые письма.", "Фонари в Чайной горят."]
const AWAY_SUBJ: = ["Новый сорт чая", "Сад расцвёл", "Ночной рынок", "Фонари у реки", "Новая заварка", "Дождь над салоном", "Звёздная ночь"]
const AWAY_BODY: = {
	"mc": "Сегодня в салоне было тихо и уютно. Я поставила новые цветы у окна — посмотришь?",
	"rin": "Я попробовала новый сорт улуна. Оставила тебе немного в жестяной банке.",
	"hana": "Сегодня пробежала новый круг вокруг озера. Хочу показать тебе маршрут!",
	"yue": "Во дворце зажгли новые фонари. Один я велела повесить у твоего окна.",
	"nova": "Собрала новую игрушку для салона. Покажу, когда заглянешь.",
}


static func st() -> Dictionary:
	return V10RitSave.st("v10_comeback")


static func tier(gap: int) -> String:
	if gap >= 30:
		return "winds"
	if gap >= 7:
		return "waited"
	if gap >= 3:
		return "warm"
	return ""


static func rested_add(gap: int) -> int:
	return mini(RESTED_MAX, maxi(0, (gap - 2) * 60)) if gap >= 3 else 0


static func check(key: = "") -> Dictionary:
	key = key if key != "" else V10RitClock.day_key()
	var s: = st()
	var res: = {"tier": "", "gap": 0, "rested_add": 0, "ladder": "", "letters": 0}
	var last: = str(s.last_seen_key)
	if last == key:
		return res
	s.last_seen_key = key
	if last == "" or not V10RitClock.clock_ok():
		return res
	var gap: = V10RitClock.days_between(last, key)
	res.gap = gap
	var t: = tier(gap)
	if t == "":
		return res
	res.tier = t
	s.scene = t
	s.gap = gap
	s.last_tier_key = key
	res.rested_add = rested_add(gap)
	s.rested = mini(RESTED_MAX, int(s.rested) + int(res.rested_add))
	if gap >= 7:
		var since: = V10RitClock.days_between(str(s.ladder_start_key), key)
		var active: bool = not (s.ladder as Dictionary).is_empty() and int(s.ladder.claimed) < ladder_len(str(s.ladder.kind))
		if not active and (str(s.ladder_start_key) == "" or since >= LADDER_COOLDOWN):
			var kind: = "long" if gap >= 14 else "short"
			s.ladder = {"kind": kind, "start_key": key, "claimed": 0, "last_claim_key": ""}
			s.ladder_start_key = key
			res.ladder = kind
	res.letters = mini(7, maxi(0, gap / 3))
	return res


# the scene to play (entry queue), consumed once
static func take_scene() -> Dictionary:
	var s: = st()
	var t: = str(s.scene)
	s.scene = ""
	if t == "":
		return {}
	return {"tier": t, "gap": int(s.gap), "secs": SCENE_SECS[t], "title": TIER_TITLE[t]}


# ── Отдых ×2 ───────────────────────────────────────────────────────────────────────────────────────────────────

static func rested() -> int:
	return int(st().rested)


static func consume_rested(pairs: int, ranked: = false) -> int:
	if ranked or pairs <= 0:
		return 0
	var s: = st()
	var used: = mini(int(s.rested), pairs)
	s.rested = int(s.rested) - used
	return used


# ── ladder ─────────────────────────────────────────────────────────────────────────────────────────────────────

static func ladder_len(kind: String) -> int:
	return LADDER_LONG.size() if kind == "long" else LADDER_SHORT.size()


# key fixes the year of the frame «Снова за столом · YYYY» (V10ProfileCos id fr_back_<year>)
static func ladder_rewards(kind: String, i: int, key: = "") -> Dictionary:
	var arr: Array = LADDER_LONG if kind == "long" else LADDER_SHORT
	var r: Dictionary = arr[clampi(i, 0, arr.size() - 1)].duplicate(true)
	if r.has("aff"):
		r.aff = {V10RitBridge.partner(): int(r.aff.partner)}
	if r.has("frame"):
		r.frame = "%s_%d" % [str(r.frame), V10RitClock.year(key if key != "" else V10RitClock.day_key())]
	return r


static func ladder_view(key: = "") -> Dictionary:
	key = key if key != "" else V10RitClock.day_key()
	var lad: Dictionary = st().ladder
	if lad.is_empty():
		return {}
	var kind: = str(lad.kind)
	var n: = ladder_len(kind)
	var claimed: = int(lad.claimed)
	var can: bool = claimed < n and str(lad.last_claim_key) != key
	var days: = []
	for i in n:
		days.append({"i": i, "rewards": ladder_rewards(kind, i, key), "state": "done" if i < claimed else ("ready" if i == claimed and can else ("next" if i == claimed else "later"))})
	return {"kind": kind, "days": days, "claimed": claimed, "can": can, "done": claimed >= n}


static func ladder_claim(key: = "") -> Array:
	key = key if key != "" else V10RitClock.day_key()
	var v: = ladder_view(key)
	if v.is_empty() or not v.can:
		return []
	var lad: Dictionary = st().ladder
	var r: = ladder_rewards(str(lad.kind), int(lad.claimed), key)
	if r.has("frame"):
		V10RitBridge.register_frame(str(r.frame), "Снова за столом · %d" % V10RitClock.year(key),
			{"type": "grant", "event": "comeback", "hint": "Лестница возвращения, день 7", "year": V10RitClock.year(key)})
	lad.claimed = int(lad.claimed) + 1
	lad.last_claim_key = key
	var rows: = V10RitBridge.grant(r, "comeback_ladder")
	V10RitSave.save()
	return rows


# ── notifications (category «Возвращение», off by default; V10Notify owns the delivery) ───────────────────────

static func notify_plan(last_seen_unix: int, enabled: bool) -> Array:
	if not enabled:
		return []
	var out: = []
	var base_key: = V10RitClock.day_key(last_seen_unix)
	for d in [3, 7, 11, 15, 19, 23, 27]:
		out.append(V10RitClock.unix_of(V10RitClock.add_days(base_key, d), NOTIFY_HOUR, NOTIFY_MIN))
	return out


static func notify_text(i: int) -> String:
	return NOTIFY_TEXT[i % NOTIFY_TEXT.size()]


static func while_away(gap: int) -> Array:
	var n: = mini(7, maxi(0, gap / 3))
	var hs: = V10RitBridge.heroes()
	var out: = []
	for i in n:
		var h: String = hs[i % hs.size()]
		out.append({"h": h, "ev": "while_away", "subj": AWAY_SUBJ[i % AWAY_SUBJ.size()], "body": AWAY_BODY.get(h, AWAY_BODY.mc)})
	return out
