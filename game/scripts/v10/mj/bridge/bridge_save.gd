class_name V10MjBridgeSave
extends RefCounted

# Сейв моста: G.S["v10_mj_bridge"] (DEFAULTS + st(), как V6ModesData.st()). SAVE_VER не трогаем — регистрацию
# поля делает интегратор. Экраны награды не начисляют: rewards() только считает, что положить в result.rewards.
#
#   days          {"2027-01-12": {"n": 12, "ok": true, "try": 1, "shown": false, "pick": 26}} — ответы задач дня
#   solved        решено задач дня (лучший сброс найден сам; «Не знаю — покажи» не в счёт) — читает дорожка riichi
#   played        задач дня с ответом (любым)
#   streak        серия: дней подряд с ответом; best_streak — лучшая серия; last_day — день последнего ответа
#   fans          {"2027-01": true} — полный месяц (веер-календарь закрыт; интегратор показывает SSR-кадр хозяйки месяца)
#   riichi_open   после 3 решённых задач — флаг «Стол открыт» для карточки «Стола на четверых» (MODES §4.5, §6.4)
#   hand_level    следующий уровень «Собери руку» (1…60), hand_stars {"<уровень>": 0…3}, hand_best, hand_wins, hand_plays

const KEY: = "v10_mj_bridge"
const DEFAULTS: = {
	"ver": 1, "days": {}, "solved": 0, "played": 0, "streak": 0, "best_streak": 0, "last_day": "", "fans": {},
	"riichi_open": false,
	"hand_level": 1, "hand_stars": {}, "hand_best": 0, "hand_wins": 0, "hand_plays": 0,
}
const RIICHI_AFTER: = 3
const DAILY_REWARD: = {"coins": 10, "gems": 0, "petals": 1, "aff": 0}
const NO_REWARD: = {"coins": 0, "gems": 0, "petals": 0, "aff": 0}
# хозяйка месяца (веер-календарь): январь — Маджонг-тян, дальше по кругу основательниц
const MONTH_HOST: = ["mc", "rin", "hana", "yue", "nova"]


static func st(S = null) -> Dictionary:
	if S == null:
		S = G.S if G.S is Dictionary else {}
	if not (S is Dictionary):
		return DEFAULTS.duplicate(true)
	var d = S.get(KEY)
	if not (d is Dictionary):
		d = DEFAULTS.duplicate(true)
		S[KEY] = d
	for k in DEFAULTS:
		if not d.has(k) or typeof(d[k]) != typeof(DEFAULTS[k]):
			d[k] = DEFAULTS[k].duplicate(true) if DEFAULTS[k] is Dictionary or DEFAULTS[k] is Array else DEFAULTS[k]
	d.hand_level = clampi(int(d.hand_level), 1, V10MjBridgeLevels.COUNT)
	return d


static func fresh() -> Dictionary:
	return st({})


# ── задача дня ───────────────────────────────────────────────────────────────

static func answered(d: Dictionary, day: String) -> bool:
	return (d.days as Dictionary).has(day)


static func school_hint(d: Dictionary, item: Dictionary) -> bool:
	return bool(item.get("school", false)) or int(d.played) < V10MjBridgeDaily.SCHOOL


static func _prev_day(day: String) -> String:
	var p: = V10MjBridgeDaily.parse_day(day)
	if p.is_empty():
		return ""
	var u: = Time.get_unix_time_from_datetime_dict({"year": p.year, "month": p.month, "day": p.day, "hour": 12})
	var dd: = Time.get_datetime_dict_from_unix_time(u - 86400)
	return V10MjBridgeDaily.day_key(dd)


# записать ответ дня. Возвращает {first_today, rewards, streak, solved, riichi_opened, fan_complete, month}
static func record_daily(d: Dictionary, day: String, n: int, ok: bool, tries: int, shown: bool, pick: int) -> Dictionary:
	var out: = {"first_today": false, "rewards": NO_REWARD.duplicate(), "streak": int(d.streak), "solved": int(d.solved),
		"riichi_opened": false, "fan_complete": false, "month": day.substr(0, 7)}
	if answered(d, day):
		return out
	out.first_today = true
	d.days[day] = {"n": n, "ok": ok, "try": tries, "shown": shown, "pick": pick}
	d.played = int(d.played) + 1
	if ok and not shown:
		d.solved = int(d.solved) + 1
	if String(d.last_day) == _prev_day(day):
		d.streak = int(d.streak) + 1
	else:
		d.streak = 1
	d.last_day = day
	d.best_streak = maxi(int(d.best_streak), int(d.streak))
	if not bool(d.riichi_open) and int(d.solved) >= RIICHI_AFTER:
		d.riichi_open = true
		out.riichi_opened = true
	var mk: = day.substr(0, 7)
	if not (d.fans as Dictionary).has(mk) and month_done(d, mk):
		d.fans[mk] = true
		out.fan_complete = true
	out.rewards = DAILY_REWARD.duplicate()
	out.streak = int(d.streak)
	out.solved = int(d.solved)
	return out


# дни месяца «YYYY-MM» с ответом: [день 1…31 → состояние ("ok" | "miss" | "")]
static func month_marks(d: Dictionary, month: String) -> Array:
	var p: = month.split("-")
	var y: = int(p[0])
	var m: = int(p[1])
	var dim: = V10MjBridgeDaily.days_in_month(y, m)
	var out: = []
	for day in range(1, dim + 1):
		var k: = "%s-%02d" % [month, day]
		var e = (d.days as Dictionary).get(k)
		if e is Dictionary:
			out.append("ok" if bool(e.get("ok", false)) and not bool(e.get("shown", false)) else "done")
		else:
			out.append("")
	return out


static func month_done(d: Dictionary, month: String) -> bool:
	for s in month_marks(d, month):
		if String(s) == "":
			return false
	return true


static func month_host(month: String) -> String:
	var m: = int(month.split("-")[1]) if month.length() >= 7 else 1
	return MONTH_HOST[(m - 1) % MONTH_HOST.size()]


static func daily_stars(ok: bool, tries: int, shown: bool) -> int:
	if shown or not ok:
		return 0
	return clampi(4 - tries, 1, 3)


# ── Собери руку ──────────────────────────────────────────────────────────────

static func hand_stars_of(d: Dictionary, level: int) -> int:
	return int((d.hand_stars as Dictionary).get(str(level), 0))


static func hand_total_stars(d: Dictionary) -> int:
	var n: = 0
	for k in (d.hand_stars as Dictionary):
		n += int(d.hand_stars[k])
	return n


# ★ — рука собрана; ★★ — без Приёма; ★★★ — и комбинация дороже цели уровня
static func hand_stars_for(win: bool, helped: bool, mult: int, req: int) -> int:
	if not win:
		return 0
	if helped:
		return 1
	return 3 if mult > maxi(1, req) else 2


static func hand_rewards(level: int, win: bool, first_clear: bool) -> Dictionary:
	if not win:
		return NO_REWARD.duplicate()
	var boss: = 1 if V10MjBridgeLevels.is_boss(level) else 0
	return {"coins": 20 + level + boss * 20, "gems": 0, "petals": 0, "aff": 1 + boss, "first_clear": first_clear}


static func record_hand(d: Dictionary, level: int, win: bool, stars: int, score: int) -> Dictionary:
	d.hand_plays = int(d.hand_plays) + 1
	var before: = hand_stars_of(d, level)
	var out: = {"stars_gain": 0, "first_clear": false}
	if not win:
		return out
	d.hand_wins = int(d.hand_wins) + 1
	d.hand_best = maxi(int(d.hand_best), score)
	out.first_clear = before == 0
	if stars > before:
		d.hand_stars[str(level)] = stars
		out.stars_gain = stars - before
	if level >= int(d.hand_level) and level < V10MjBridgeLevels.COUNT:
		d.hand_level = level + 1
	return out
