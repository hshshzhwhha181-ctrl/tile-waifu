class_name V10MjSanmaData
extends RefCounted

# Сейв, награды и тексты Лунного стола. Сейв: G.S["v10_mj_sanma"] (DEFAULTS + st(), как V6ModesData.st()).
# SAVE_VER не трогаем — регистрацию поля и recovery_selftest добавляет интегратор.

const KEY: = "v10_mj_sanma"
const DEFAULTS: = {
	"played": 0,
	"firsts": 0,
	"places": [0, 0, 0],
	"best_hand": {},          # рекорд «дороже всего за руку»: {pts, han, fu, name, yaku[], kita, seed, date}
	"best_score": 0,          # лучший итог партии (очки стола)
	"kita_total": 0,
	"last_day": "",           # дата первой партии дня (для +кристаллов первой партии)
	"event": {"played": 0, "best": 0, "total": 0, "best_mult": 0, "month": ""},
	"settings": {"names": "ru", "hints": true},
}

# Награды «Стола на четверых» (MODES §4.6): 1-е 40 / 2-е 25 / 3-е 15 / 4-е 10 монет; первая партия дня +20 кр.
# Лунный стол — ×0,8, мест три.
const TABLE4_COINS: = [40, 25, 15, 10]
const TABLE4_FIRST_DAY_GEMS: = 20
const RATE: = 0.8

static var _mem: = {}   # если G недоступен (самотест вне дерева)
static var force_mem: = false   # самотест и демо не пишут в настоящий сейв

static func _root() -> Dictionary:
	if force_mem:
		return _mem
	var g = Engine.get_main_loop().root.get_node_or_null("/root/G") if Engine.get_main_loop() is SceneTree else null
	if g != null and "S" in g:
		return g.S
	return _mem

static func st() -> Dictionary:
	var S: Dictionary = _root()
	var d: Dictionary = S.get(KEY, {})
	for k in DEFAULTS:
		if not d.has(k):
			d[k] = DEFAULTS[k].duplicate(true) if DEFAULTS[k] is Dictionary or DEFAULTS[k] is Array else DEFAULTS[k]
	S[KEY] = d
	return d

static func coins_for_place(place: int) -> int:
	return int(round(TABLE4_COINS[clampi(place - 1, 0, 3)] * RATE))

# Награды партии. Множитель события сюда НЕ входит (самотест это проверяет).
static func rewards(place: int, first_today: bool) -> Dictionary:
	return {"coins": coins_for_place(place), "gems": int(round(TABLE4_FIRST_DAY_GEMS * RATE)) if first_today else 0, "petals": 0, "aff": 2 if place == 1 else 1}

# Ценность руки для рекорда: очки, которые получил победитель (без палочек и повторов).
static func hand_value(res: Dictionary) -> int:
	var ev: Dictionary = res.get("eval", {})
	return int(ev.get("base", 0))

# Записать итог раздачи (рекорд «дороже всего за руку»). true — новый рекорд.
static func note_hand(res: Dictionary, me: int, seed: int, date: String) -> bool:
	if res.get("ev", "") != "win" or int(res.get("seat", -1)) != me:
		return false
	var d: = st()
	var ev: Dictionary = res.eval
	var pts: int = int(res.delta[me]) - int(res.get("sticks", 0)) * 1000
	var best: Dictionary = d.best_hand
	if pts <= int(best.get("pts", 0)):
		return false
	var names: = []
	for y in ev.get("yaku", []):
		names.append(V8Mj.yaku_name(String(y[0])))
	d.best_hand = {"pts": pts, "han": int(ev.get("han", 0)), "fu": int(ev.get("fu", 0)), "name": String(ev.get("limit", "")),
		"yaku": names, "kita": int(ev.get("kita", 0)), "seed": seed, "date": date}
	return true

static func note_match(final: Dictionary, me: int, kita_n: int, today: String) -> Dictionary:
	var d: = st()
	var place: int = int(final.place[me])
	var first_today: bool = d.last_day != today
	d.played += 1
	d.places[place - 1] += 1
	if place == 1:
		d.firsts += 1
	d.kita_total += kita_n
	d.best_score = maxi(int(d.best_score), int(final.scores[me]))
	d.last_day = today
	return rewards(place, first_today)

static func note_event(ev_score: int, best_mult: int, month: String) -> void:
	var e: Dictionary = st().event
	e.played += 1
	e.total += ev_score
	e.best = maxi(int(e.best), ev_score)
	e.best_mult = maxi(int(e.best_mult), best_mult)
	e.month = month
