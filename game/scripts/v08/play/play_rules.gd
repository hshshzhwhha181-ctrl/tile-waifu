class_name V8PlayRules
extends RefCounted

# 0.8 Stream E: one place for the rank points every mode gives (G.add_rp), the star rule text,
# the paid-help prices and the strings of the match / victory screens.
# Rank points (spec 5): duel win +20 / loss 0, blitz and zen 5–15 by result, etudes by stars,
# event and tourney by stars / points / place; Path and the daily table keep the 0.7 formula.

const HELP_PRICE: = 30
const RESCUE_PRICE: = 60

const DUEL_WIN: = 20
const DUEL_DRAW: = 5

const T: = {
	"hint_t": "Подсказка",
	"hint_d": "Бесплатные подсказки закончились. Подсказать пару за кристаллы?",
	"undo_t": "Вернуть ход",
	"undo_d": "Бесплатные возвраты закончились. Вернуть последнюю фишку за кристаллы?",
	"shuffle_t": "Перемешать",
	"shuffle_d": "Бесплатные перемешивания закончились. Перемешать стол за кристаллы?",
	"rescue_t": "Вернуть 3 фишки",
	"rescue_d": "Бесплатное спасение уже было. Вернуть три фишки из лотка на стол за кристаллы?",
	"hint_on": "Подсказка уже горит на столе",
	"undo_none": "Возвращать пока нечего",
	"star_rule": "3★ — без помощи и переполнений · 2★ — до двух помощей",
	"star_rule_event": "3★ — без помощи и переполнений · 2★ — до 2 помощей и 1 переполнения",
	"stats": "%d с · помощь: %d · переполнений: %d",
	"rank_gain": "+%d %s ранга",
	"rank_was": "Было: %s · %d/%d",
	"rank_now": "Стало: %s · %d/%d",
	"rank_up": "Новый ранг: %s · +%d кристаллов",
	"league": "%s · #%d из %d",
	"league_gain": " · +%d %s недели",
	"league_none": "%s · #%d из %d · сыграй стол турнира",
	"quarter": "Квартал: #%s из %s",
	"quarter_new": "Очки ранга идут в рейтинг квартала",
	"quarter_gain": " · +%d %s ранга",
	"mode_open": "Открыт режим: %s",
	"yaku_head": "ЯКУ",
	"no_yaku": "Яку не сложилось: сыграй без помощи или объяви риичи",
	"rp_line": "+%d к рангу",
	"rp_up_toast": "Новый ранг: %s · +%d кристаллов",
	"fortune_tap": "коснись, чтобы скрыть",
}


# 0.8 tuning: a Path win gives ~25–45 rank points (3★ with the usual yaku ≈ 36; G.YAKU rp were scaled down to
# 2–6 each), so the rank gates of the modes land along the Path (Блиц ≈ 4th win, Сад ≈ 6th, Дуэль ≈ 8th …)
# instead of opening after the tutorial. The victory window shows win base + yaku chips that add up to the total.
const PATH_YAKU_CAP: = 30

static func path_rp(stars: int, hard: int, yaku_rp: int) -> int:
	return 6 + stars * 4 + hard * 8 + mini(yaku_rp, PATH_YAKU_CAP)

# Russian plural: plural(1, "очко", "очка", "очков") -> "очко"
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

static func points_word(n: int) -> String:
	return plural(n, "очко", "очка", "очков")

# modes whose rank gate lies in (rp_from, rp_to]: names for «Открыт режим: …» in the victory window
static func modes_opened(rp_from: int, rp_to: int) -> Array:
	var out: = []
	var a: = G.rank_index(rp_from)
	var b: = G.rank_index(rp_to)
	if b <= a:
		return out
	for id in MODE_NAMES:
		var gi: = V6ModesData.gate_index(id)
		if gi > a and gi <= b:
			out.append(String(MODE_NAMES[id]))
	return out

const MODE_NAMES: = {"blitz": "Блиц", "zen": "Сад", "duel": "Дуэль", "etude": "Этюды", "shift": "Смена в чайной", "climb": "Лунная лестница"}

static func duel_rp(win: bool, draw: bool) -> int:
	return DUEL_WIN if win else (DUEL_DRAW if draw else 0)

static func blitz_rp(score: int) -> int:
	if score <= 0:
		return 0
	return clampi(5 + score / 200, 5, 15)

# zen has no end: every cleared board counts, the streak of boards raises the reward up to 15
static func zen_rp(boards_done: int) -> int:
	return clampi(4 + boards_done, 5, 15)

static func etude_rp(stars: int) -> int:
	return 4 + 3 * clampi(stars, 1, 3)

static func event_rp(stars: int) -> int:
	return 10 + 5 * clampi(stars, 1, 3)

static func tourney_rp(cleared: bool, total: int, places_up: int) -> int:
	var n: = clampi(5 + total / 100, 5, 25) if cleared else clampi(total / 200, 0, 5)
	return n + clampi(places_up * 2, 0, 10)

static func climb_rp(floor_n: int) -> int:
	return clampi(4 + floor_n, 5, 15)

static func shift_rp(served: int) -> int:
	return clampi(5 + served, 5, 15)

static func story_stars(fails: int, boosters: int) -> int:
	return 3 if fails == 0 and boosters == 0 else (2 if fails == 0 and boosters <= 2 else 1)


# G.add_rp + G.record_game + G.save in one call. Returns {rp, ups, gems, title}.
static func award(source: String, rp: int, won: bool) -> Dictionary:
	var ups: Array = []
	if rp != 0:
		ups = G.add_rp(rp, source)
	G.record_game(source, won)
	G.save()
	var gems: = 0
	for u in ups:
		gems += int(u.gems)
	return {"rp": rp, "ups": ups, "gems": gems, "title": String(G.rank_of(int(G.S.rp)).title)}

# short "+N к рангу" text, plus the new rank when there was one (for mode result popups)
static func award_text(a: Dictionary) -> String:
	return T.rp_line % int(a.get("rp", 0)) if int(a.get("rp", 0)) > 0 else ""

# "a · b", skipping empty parts
static func join(parts: Array) -> String:
	return " · ".join(parts.filter( func(x): return String(x) != ""))

static func rankup_text(a: Dictionary) -> String:
	if (a.get("ups", []) as Array).is_empty():
		return ""
	return T.rank_up % [String(a.title), int(a.gems)]


# ---- weekly league (Stream B, V8League). Guarded: works while that module is missing or changing.
static var _league = null
static var _league_checked: = false

static func league_script():
	return V8League

# {league_name, place, group_size, color, q_place, q_points} or {} if the league is not available
static func league_info() -> Dictionary:
	var w = V8League.my_week()
	var q = V8League.my_quarter()
	if not (w is Dictionary) or not (q is Dictionary):
		return {}
	return {"league_name": String(w.get("league_name", "")), "place": int(w.get("place", 0)), "group_size": int(w.get("group_size", 20)),
		"color": w.get("color", Color("ffd98a")), "points": int(w.get("points", 0)), "q_place": int(q.get("place", 0)),
		"q_total": int(q.get("total", 1001)), "q_points": int(q.get("points", 0))}
