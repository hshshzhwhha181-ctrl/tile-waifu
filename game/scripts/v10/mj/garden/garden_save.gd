class_name V10MjGardenSave
extends RefCounted

# Сейв Сада 2.0: G.S["v10_mj_garden"]. SAVE_VER не трогаем — поле дополняется по DEFAULTS через st() (как
# V6ModesData.st()), регистрацию в recovery_selftest делает интегратор.
#   night        — «Ночной стол» (тумблер на карточке режима и в паузе)
#   ambient      — фон дня: rain | stream | bamboo (ночью всегда дождь)
#   run          — стол посреди волны: V10MjGardenRules.to_dict() (только целые и массивы — переживает JSON)
#   best_series / best_waves / best_score — лучшее за всё время (волны и очки — за один заход)
#   week         — рекорд недели для Профиля: {key (понедельник), series, waves, score}
#   day          — {key, paid}: сколько волн сегодня уже принесли монеты (не больше DAY_CAP)
#   pending      — награды и события, ещё не отданные интегратору: {coins, waves, tea}. Копятся при каждой волне
#                  и сохраняются сразу, поэтому не теряются, даже если игру закрыли без «Выйти»; экран отдаёт их в
#                  result.rewards и обнуляет (экран сам ничего не начисляет).
#   waves_total  — волн за всё время (каждые TEA_EVERY — событие «Чайный куст» для Салона)

const KEY: = "v10_mj_garden"
const DEFAULTS: = {
	"night": false, "ambient": "rain", "run": {},
	"best_series": 0, "best_waves": 0, "best_score": 0,
	"week": {"key": "", "series": 0, "waves": 0, "score": 0},
	"day": {"key": "", "paid": 0},
	"pending": {"coins": 0, "waves": 0, "tea": 0},
	"waves_total": 0, "pairs_total": 0, "plays": 0,
}
const COINS_PER_WAVE: = 5
const DAY_CAP: = 30
const TEA_EVERY: = 10
const AMBIENTS: = ["rain", "stream", "bamboo"]
const AMB_NAMES: = {"rain": "Дождь", "stream": "Ручей", "bamboo": "Бамбук"}
# рекорд недели «считается» (силуэт героини), только если на этой неделе уже было что бить
const RECORD_MIN_SERIES: = 5
const RECORD_MIN_WAVES: = 2


static func st(S = null) -> Dictionary:
	if S == null:
		S = G.S
	if not (S is Dictionary):
		return DEFAULTS.duplicate(true)
	var d = S.get(KEY)
	if not (d is Dictionary):
		d = DEFAULTS.duplicate(true)
		S[KEY] = d
	fix(d)
	return d


static func fix(d: Dictionary) -> void:
	for k in DEFAULTS:
		if not d.has(k) or typeof(d[k]) != typeof(DEFAULTS[k]) and not (DEFAULTS[k] is int and d[k] is float):
			d[k] = DEFAULTS[k].duplicate(true) if DEFAULTS[k] is Dictionary else DEFAULTS[k]
	for sub in ["week", "day", "pending"]:
		for k in DEFAULTS[sub]:
			if not (d[sub] as Dictionary).has(k):
				d[sub][k] = DEFAULTS[sub][k]
	if not (String(d.ambient) in AMBIENTS):
		d.ambient = "rain"
	d.night = bool(d.night)
	for k in ["best_series", "best_waves", "best_score", "waves_total", "pairs_total", "plays"]:
		d[k] = maxi(0, int(d[k]))


# ── день и неделя (МСК, день начинается в 04:00 — как у всей игры) ─────────────────────────────────────────────

static func day_key() -> String:
	if _has_class("V10Meta"):
		var v = _call_static("V10Meta", "day_key")
		if v is String and String(v).length() >= 10:
			return v
	var u: = int(Time.get_unix_time_from_system()) + 3 * 3600 - 4 * 3600
	return Time.get_date_string_from_unix_time(u)


static func _has_class(cls: String) -> bool:
	for c in ProjectSettings.get_global_class_list():
		if String(c.get("class", "")) == cls:
			return true
	return false


static func _call_static(cls: String, fn: String):
	for c in ProjectSettings.get_global_class_list():
		if String(c.get("class", "")) == cls:
			var sc = load(String(c.path))
			if sc and sc.has_method(fn):
				return sc.call(fn)
	return null


# понедельник недели этого дня
static func week_key(day: String) -> String:
	if day.length() < 10:
		return ""
	var u: = int(Time.get_unix_time_from_datetime_string(day.substr(0, 10) + "T00:00:00"))
	var di: = u / 86400
	var wd: = (di + 3) % 7      # 0 = понедельник (1970-01-01 — четверг)
	return Time.get_date_string_from_unix_time((di - wd) * 86400)


static func roll(d: Dictionary, day: String) -> void:
	if String(d.day.key) != day:
		d.day = {"key": day, "paid": 0}
	var wk: = week_key(day)
	if String(d.week.key) != wk:
		d.week = {"key": wk, "series": 0, "waves": 0, "score": 0}


# ── волны, серия, награды ───────────────────────────────────────────────────────────────────────────────────────

# волна пройдена (на стол налили следующую): монеты в пределах дня, событие «Чайный куст» каждые 10 волн
static func wave_done(d: Dictionary, day: String) -> Dictionary:
	roll(d, day)
	d.waves_total = int(d.waves_total) + 1
	var out: = {"coins": 0, "tea": false, "paid": int(d.day.paid)}
	if int(d.day.paid) < DAY_CAP:
		d.day.paid = int(d.day.paid) + 1
		d.pending.coins = int(d.pending.coins) + COINS_PER_WAVE
		out.coins = COINS_PER_WAVE
	d.pending.waves = int(d.pending.waves) + 1
	if int(d.waves_total) % TEA_EVERY == 0:
		d.pending.tea = int(d.pending.tea) + 1
		out.tea = true
	out.paid = int(d.day.paid)
	return out


# рекорды на старте захода: что нужно побить, чтобы она вышла силуэтом (0 — на этой неделе бить ещё нечего)
static func record_bar(d: Dictionary, day: String) -> Dictionary:
	roll(d, day)
	var s: = int(d.week.series)
	var w: = int(d.week.waves)
	return {"series": s if s >= RECORD_MIN_SERIES else 0, "waves": w if w >= RECORD_MIN_WAVES else 0}


# серия выросла: лучшая за неделю и за всё время
static func note_series(d: Dictionary, s: int, day: String) -> void:
	roll(d, day)
	d.week.series = maxi(int(d.week.series), s)
	d.best_series = maxi(int(d.best_series), s)


# заход закончился (выход или пауза → «Выйти»): лучшие волны и очки за один заход
static func record_visit(d: Dictionary, waves: int, pairs: int, score: int, day: String) -> void:
	roll(d, day)
	d.plays = int(d.plays) + 1
	d.pairs_total = int(d.pairs_total) + pairs
	d.best_waves = maxi(int(d.best_waves), waves)
	d.best_score = maxi(int(d.best_score), score)
	d.week.waves = maxi(int(d.week.waves), waves)
	d.week.score = maxi(int(d.week.score), score)


# отдать накопленное интегратору: rewards по схеме §7.1 + события Салона; pending обнуляется
static func take_pending(d: Dictionary) -> Dictionary:
	var p: Dictionary = d.pending
	var rw: = {"coins": int(p.coins), "gems": 0, "petals": 0, "aff": 0}
	var ev: = []
	for k in int(p.tea):
		ev.append({"id": "tea_bush", "what": "water", "zone": "tea"})
	var out: = {"rewards": rw, "events": ev, "waves": int(p.waves)}
	d.pending = {"coins": 0, "waves": 0, "tea": 0}
	return out


# сколько волн сегодня ещё принесут монеты
static func paid_left(d: Dictionary, day: String) -> int:
	roll(d, day)
	return maxi(0, DAY_CAP - int(d.day.paid))


# ── стол посреди волны ──────────────────────────────────────────────────────────────────────────────────────────

static func save_run(d: Dictionary, r: V10MjGardenRules) -> void:
	d.run = r.to_dict()


static func has_run(d: Dictionary) -> bool:
	var run = d.get("run", {})
	return run is Dictionary and run.get("tiles") is Array and not (run.tiles as Array).is_empty()


static func load_run(d: Dictionary) -> V10MjGardenRules:
	if not has_run(d):
		return null
	var r: = V10MjGardenRules.from_dict(d.run)
	if r.board_count() == 0 and r.tray.is_empty():
		return null
	return r


static func clear_run(d: Dictionary) -> void:
	d.run = {}
