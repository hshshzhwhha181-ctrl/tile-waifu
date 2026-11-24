class_name V10MjRiichiData
extends RefCounted

# «Стол на четверых»: save field, halls, admission, rewards, plain names (UX §4), stop words.
# Save: G.S["v10_mj_riichi"] = {hall_progress, stats, last_seed, daily_one_hand, prefs}. st() repairs junk.

const KEY: = "v10_mj_riichi"
const VER: = 1

const DEFAULTS: = {
	"ver": VER,
	"hall_progress": {"games": {}, "firsts": {}, "seen": []},
	"stats": {},
	"last_seed": 0,
	"daily_one_hand": {"day": "", "done": false, "seed": 0},
	"first_day": "",
	"prefs": {"names": "ru", "horizontal": -1, "stickers": true, "riichi_hint_seen": false},
}

# ---------------------------------------------------------------- halls (MODES §4.6, Tenhou + Mahjong Soul)
# skill → V8AI.room_skill; hints: "full" (waits + best discard + danger), "waits", ""; pace — AI pause factor.
const HALLS: = [
	{"id": "school", "name": "Учебный", "skill": 0.6, "hints": "full", "undo": 3, "rp": [0, 0, 0, 0], "protect": false,
		"cloth": "school", "back": "rose", "pace": 1.1, "line": "Подсказки и отмена хода"},
	{"id": "bamboo", "name": "Бамбуковый", "skill": 0.75, "hints": "waits", "undo": 0, "rp": [30, 15, 5, 0], "protect": false,
		"cloth": "bamboo", "back": "jade", "pace": 1.0, "line": "Видно, чего ждёшь. Четвёртое место ранг не отнимает"},
	{"id": "jade", "name": "Нефритовый", "skill": 0.85, "hints": "", "undo": 0, "rp": [60, 25, 0, -30], "protect": true,
		"cloth": "jade", "back": "jade", "pace": 1.0, "line": "Без подсказок. Защита до первой ступени"},
	{"id": "gold", "name": "Золотой", "skill": 0.95, "hints": "", "undo": 0, "rp": [90, 40, 0, -60], "protect": false,
		"cloth": "gold", "back": "rose", "pace": 0.8, "line": "Полный счёт, быстрые соперницы"},
	{"id": "sky", "name": "Небесный", "skill": 1.0, "hints": "", "undo": 0, "rp": [120, 50, 0, -90], "protect": false,
		"cloth": "sky", "back": "night", "pace": 0.8, "line": "Сильнейшие соперницы"},
]

const FORMATS: = {
	"east": {"name": "Восток", "length": "east", "one_hand": false},
	"east_south": {"name": "Восток и Юг", "length": "south", "one_hand": false},
	"one_hand": {"name": "Одна раздача", "length": "east", "one_hand": true},
}

const COINS_BY_PLACE: = [40, 25, 15, 10]
const GEMS_FIRST_TODAY: = 20
const GEMS_ONE_HAND_TODAY: = 10

# ---------------------------------------------------------------- colours («Тишина и лак», UX §6.2)
const NIGHT_900: = Color("121014")
const NIGHT_800: = Color("1b171c")
const NIGHT_700: = Color("26212a")
const NIGHT_600: = Color("332c36")
const PAPER_100: = Color("f5ead8")
const PAPER_300: = Color("ddd2c4")
const PAPER_500: = Color("b3a89c")
const PAPER_700: = Color("7e756d")
const GOLD_300: = Color("f1d9a0")
const GOLD_500: = Color("e8c47e")
const GOLD_700: = Color("a87b3a")
const ROSE_500: = Color("d796a5")
const ROSE_700: = Color("9a4f66")
const JADE_300: = Color("a9d9c4")
const JADE_500: = Color("5b9580")
const CINNABAR: = Color("c8463c")
const EMBER: = Color("e07a7a")

const HERO_COLOR: = {"mc": Color("ff8fb8"), "rin": Color("4fbf9f"), "hana": Color("ffb35c"), "yue": Color("c8b6ff"), "nova": Color("4fe3ff")}
const HERO_NAME: = {"mc": "Маджонг-тян", "rin": "Рин", "hana": "Хана", "yue": "Юэ", "nova": "Нова"}
const FOUNDERS: = ["mc", "rin", "hana", "yue", "nova"]

# ---------------------------------------------------------------- plain names (UX §4.2: «Комбинация», original small)
const COMBO_RU: = {
	"riichi": "Готовность", "ippatsu": "С первого круга", "tsumo": "Сама со стены", "pinfu": "Ровная рука",
	"iipeikou": "Два одинаковых ряда", "tanyao": "Все простые", "haku": "Белые драконы", "hatsu": "Зелёные драконы",
	"chun": "Красные драконы", "seat": "Свой ветер", "round": "Ветер круга", "haitei": "Последняя со стены",
	"houtei": "Последний сброс", "rinshan": "Добор после четвёрки", "chankan": "Перехват четвёрки",
	"double_riichi": "Готовность с первого хода", "chiitoitsu": "Семь пар", "sanshoku": "Ряд в трёх мастях",
	"ittsu": "Чистый ряд 1–9", "chanta": "Края в каждом наборе", "toitoi": "Все тройки", "sanankou": "Три скрытые тройки",
	"sankantsu": "Три четвёрки", "sanshoku_doukou": "Тройки в трёх мастях", "shousangen": "Малые драконы",
	"honroutou": "Только края и знаки", "honitsu": "Масть и знаки", "junchan": "Чистые края", "ryanpeikou": "Дважды два ряда",
	"chinitsu": "Одна масть",
	"kokushi": "Тринадцать сирот", "suuankou": "Четыре скрытые тройки", "daisangen": "Большие драконы",
	"shousuushii": "Малые ветры", "daisuushii": "Большие ветры", "tsuuiisou": "Только знаки", "ryuuiisou": "Всё зелёное",
	"chinroutou": "Только края", "chuuren": "Девять врат", "suukantsu": "Четыре четвёрки", "tenhou": "Небесная рука",
	"chiihou": "Земная рука",
	"dora": "Бонус", "aka": "Красные пятёрки", "ura": "Скрытый бонус",
}
const BONUS_ORIG: = {"dora": "дора", "aka": "ака-дора", "ura": "ура-дора"}
const BONUS_HINT: = {
	"dora": "Каждая фишка, следующая за индикатором на столе, даёт +1.",
	"aka": "Красная пятёрка в руке даёт +1.",
	"ura": "После победы с объявленной готовностью открывается ещё один индикатор.",
}
const LIMIT_RU: = {"Манган": "Большая рука", "Ханеман": "Прыжок", "Байман": "Двойная", "Санбайман": "Тройная",
	"Якуман": "Легенда", "Счётный якуман": "Легенда по счёту", "Двойной якуман": "Двойная легенда"}

# Decision buttons: [big Russian word, small original] (UX §4: Russian large, original small)
const ACTIONS: = {
	"pon": ["Взять", "пон"], "chi": ["Ряд", "чи"], "kan": ["Четыре", "кан"], "riichi": ["Готов", "риичи"],
	"ron": ["Победа", "рон"], "tsumo": ["Победа", "цумо"], "pass": ["Пропустить", ""], "kita": ["Север", "кита"],
}
const RIICHI_FIRST_HINT: = "объявить готовность: +1 к комбинации, рука закрыта"
const STAMP: = {"pon": "ПОН", "chi": "ЧИ", "kan": "КАН", "minkan": "КАН", "ankan": "КАН", "kakan": "КАН", "ron": "РОН", "tsumo": "ЦУМО", "riichi": "РИИЧИ"}

# ---------------------------------------------------------------- stop words (local copy of UX §4.3 + spec §2.8)
const STOP: = ["гарант", "пити", "pity", "50/50", "SR+", "SSR+", "гача", "ролл", "крутка", "фивер", "ивент", "квартал",
	"перк", "ульта", "банер", "донат", "ХИТ", "ВЫГОДНО", "BEST", "NEW", "успей", "последний шанс", "осталось N штук",
	"топ-100", "Богиня", "богиня", "Ставка", "яку", "Яку", "Рейтинг R"]
const STOP_WORDS: = ["SR", "R", "ID"]

static func lint(text: String) -> Array:
	var bad: = []
	for w in STOP:
		if text.findn(w) >= 0 and (w != "яку" and w != "Яку" or _word_hit(text, "яку")):
			bad.append(w)
	for w in STOP_WORDS:
		if _word_hit(text, w, true):
			bad.append(w)
	# «риичи» only as the small original next to «Готов» (UX §4.3: not without explanation)
	if text.findn("риичи") >= 0 and text.findn("Готов") < 0 and text.findn("Комбинация") < 0 and text.to_lower() != "риичи":
		bad.append("риичи")
	return bad

static func _word_hit(text: String, w: String, case_sens: = false) -> bool:
	var re: = RegEx.new()
	re.compile("(^|[^\\p{L}0-9])" + ("" if case_sens else "(?i)") + w + "($|[^\\p{L}0-9])")
	return re.search(text) != null

# ---------------------------------------------------------------- save
static func st() -> Dictionary:
	var S: Dictionary = _S()
	var d = S.get(KEY)
	if not (d is Dictionary):
		d = {}
		S[KEY] = d
	for k in DEFAULTS:
		if not d.has(k) or typeof(d[k]) != typeof(DEFAULTS[k]):
			d[k] = DEFAULTS[k].duplicate(true) if DEFAULTS[k] is Dictionary or DEFAULTS[k] is Array else DEFAULTS[k]
	for k in DEFAULTS.prefs:
		if not d.prefs.has(k) or typeof(d.prefs[k]) != typeof(DEFAULTS.prefs[k]):
			d.prefs[k] = DEFAULTS.prefs[k]
	for k in DEFAULTS.hall_progress:
		if not d.hall_progress.has(k) or typeof(d.hall_progress[k]) != typeof(DEFAULTS.hall_progress[k]):
			d.hall_progress[k] = DEFAULTS.hall_progress[k].duplicate(true)
	if not String(d.prefs.names) in ["ru", "jp"]:
		d.prefs.names = "ru"
	d.ver = VER
	return d

static var _mem: = {}

static func _S() -> Dictionary:
	var ml: = Engine.get_main_loop()
	if ml is SceneTree and ml.root.has_node("G"):
		var g = ml.root.get_node("G")
		if g.get("S") is Dictionary:
			return g.S
	return _mem

static func pref(k: String):
	return st().prefs.get(k, DEFAULTS.prefs.get(k))

static func set_pref(k: String, v) -> void:
	st().prefs[k] = v

static func hall(id: String) -> Dictionary:
	for h in HALLS:
		if h.id == id:
			return h
	return HALLS[0]

static func day_key() -> String:
	return Time.get_date_string_from_system()

static func daily_seed(day: String = "") -> int:
	if day == "":
		day = day_key()
	return absi(hash("tw-riichi-one-" + day)) % 1000000000

# ---------------------------------------------------------------- admission (V8League tier; own counters as fallback)
static func _tier() -> int:
	var S: = _S()
	if S.has("rp"):
		var ml: = Engine.get_main_loop()
		if ml is SceneTree and ml.root.has_node("G") and ml.root.get_node("G").has_method("rank_of"):
			return int(ml.root.get_node("G").rank_of(int(S.get("rp", 0))).get("tier", 0))
	return int(st().hall_progress.get("tier_override", 0))

static func _bridge_solved() -> int:
	var b = _S().get("v10_mj_bridge")
	if b is Dictionary:
		return int(b.get("solved", b.get("daily_solved", 0)))
	return 0

static func hall_gate(id: String) -> Dictionary:
	var hp: Dictionary = st().hall_progress
	if hp.get("all_open", false):
		return {"open": true, "why": ""}
	match id:
		"school":
			return {"open": true, "why": ""}
		"bamboo":
			var ok: bool = _bridge_solved() >= 3 or int(hp.games.get("school", 0)) >= 2
			return {"open": ok, "why": "Откроется: 3 задачи дня или 2 партии в Учебном"}
		"jade":
			return {"open": _tier() >= 1, "why": "Откроется: ранг Нефрит I"}
		"gold":
			return {"open": _tier() >= 3, "why": "Откроется: ранг Золото I"}
		"sky":
			return {"open": int(hp.firsts.get("gold", 0)) >= 5, "why": "Откроется: 5 первых мест в Золотом"}
	return {"open": false, "why": ""}

# ---------------------------------------------------------------- rewards and rank points (credited by the integrator)
static func rewards(place: int, fmt: String, day: String = "") -> Dictionary:
	if day == "":
		day = day_key()
	var d: = st()
	var coins: int = COINS_BY_PLACE[clampi(place - 1, 0, 3)]
	var gems: = 0
	var first_today: bool = d.first_day != day
	if first_today:
		gems += GEMS_FIRST_TODAY
	var one_today: = false
	if fmt == "one_hand" and not (d.daily_one_hand.day == day and d.daily_one_hand.done):
		gems += GEMS_ONE_HAND_TODAY
		one_today = true
	return {"coins": coins, "gems": gems, "petals": 0, "aff": 1 if place == 1 else 0, "first_today": first_today, "one_hand_today": one_today}

static func rp_delta(hall_id: String, place: int, rp: int = -1, floor_rp: int = -1) -> int:
	var h: = hall(hall_id)
	var v: int = h.rp[clampi(place - 1, 0, 3)]
	if v < 0 and h.protect and rp >= 0 and floor_rp >= 0:
		v = maxi(v, floor_rp - rp)
		v = mini(v, 0)
	return v

static func record_match(hall_id: String, fmt: String, place: int, seed: int, day: String = "") -> void:
	if day == "":
		day = day_key()
	var d: = st()
	var hp: Dictionary = d.hall_progress
	hp.games[hall_id] = int(hp.games.get(hall_id, 0)) + 1
	if place == 1:
		hp.firsts[hall_id] = int(hp.firsts.get(hall_id, 0)) + 1
	d.first_day = day
	d.last_seed = seed
	if fmt == "one_hand":
		d.daily_one_hand = {"day": day, "done": true, "seed": daily_seed(day)}

# ---------------------------------------------------------------- names
static func combo_name(id: String) -> String:
	return COMBO_RU.get(id, V8Mj.yaku_name(id))

static func combo_orig(id: String) -> String:
	if BONUS_ORIG.has(id):
		return BONUS_ORIG[id]
	return V8Mj.yaku_name(id).to_lower()

const HINT: = {
	"riichi": "Рука закрыта и ждёт одну фишку — объяви готовность и поставь 1000 очков.",
	"ippatsu": "Победа в первый же круг после объявления готовности.",
	"tsumo": "Закрытая рука, победная фишка взята со стены самой.",
	"pinfu": "Только ряды, пара без бонуса, ожидание с двух сторон.",
	"iipeikou": "Два одинаковых ряда в закрытой руке.",
	"tanyao": "Только фишки 2–8: без единиц, девяток и знаков.",
	"haku": "Тройка белых драконов.", "hatsu": "Тройка зелёных драконов.", "chun": "Тройка красных драконов.",
	"seat": "Тройка своего ветра.", "round": "Тройка ветра круга.",
	"haitei": "Победа последней фишкой стены.", "houtei": "Победа на последний сброс партии.",
	"rinshan": "Победа фишкой, добранной после четвёрки.", "chankan": "Победа на фишку, которой соперница добирает четвёрку.",
	"double_riichi": "Готовность объявлена первым же сбросом.", "chiitoitsu": "Семь разных пар.",
	"sanshoku": "Один и тот же ряд в трёх мастях.", "ittsu": "1-2-3, 4-5-6, 7-8-9 одной масти.",
	"chanta": "В каждом наборе и паре есть 1, 9 или знак.", "toitoi": "Все наборы — тройки.",
	"sanankou": "Три тройки собраны без взятия.", "sankantsu": "Три четвёрки.",
	"sanshoku_doukou": "Тройки одного числа в трёх мастях.", "shousangen": "Две тройки драконов и пара третьего.",
	"honroutou": "Только единицы, девятки и знаки.", "honitsu": "Одна масть и знаки.",
	"junchan": "В каждом наборе и паре есть 1 или 9, без знаков.", "ryanpeikou": "Дважды по два одинаковых ряда.",
	"chinitsu": "Вся рука одной масти.",
	"kokushi": "Все 13 разных единиц, девяток и знаков плюс пара.", "suuankou": "Четыре тройки без взятия.",
	"daisangen": "Тройки всех трёх драконов.", "shousuushii": "Три тройки ветров и пара четвёртого.",
	"daisuushii": "Тройки всех четырёх ветров.", "tsuuiisou": "Только знаки.", "ryuuiisou": "Только зелёные фишки.",
	"chinroutou": "Только единицы и девятки.", "chuuren": "1112345678999 одной масти и любая фишка той же масти.",
	"suukantsu": "Четыре четвёрки.", "tenhou": "Победа сразу после раздачи у ведущей.", "chiihou": "Победа первым же добором.",
}

static func combo_hint(id: String) -> String:
	if BONUS_HINT.has(id):
		return BONUS_HINT[id]
	return HINT.get(id, "")

static func limit_ru(lim: String) -> String:
	return LIMIT_RU.get(lim, lim)

static func tile_short(k: int) -> String:
	return V8Mj.short_ru(k)
