class_name V10MjKoikoiSave
extends RefCounted

# Сейв режима: G.S["v10_mj_koikoi"] (контракт §7.1; SAVE_VER не трогаем, регистрацию делает интегратор).
#   wins  — победы в партиях (всего)
#   book  — {yaku_id: сколько раз собрана} — страницы «Книги комбинаций»
#   skins — {light_tag: true} — открытые карты-героини альбома «Ханафуда героинь»
#   best  — лучший счёт партии
#   beat  — {hero_id: побед над ней} (для открытия её карты)
#   day_win — дата первой победы дня (yyyy-mm-dd)
#   use_skins — показывать карты-героини вместо базовых светов (косметика)
#   games — сыграно партий
const KEY: = "v10_mj_koikoi"
const DEFAULTS: = {"wins": 0, "book": {}, "skins": {}, "best": 0, "beat": {}, "day_win": "", "use_skins": true, "games": 0}

const COINS_PER_POINT: = 5
const COINS_WIN: = 20
const GEMS_FIRST_WIN: = 15

static func _store() -> Dictionary:
	var tree: = Engine.get_main_loop() as SceneTree
	var g = tree.root.get_node_or_null("G") if tree else null
	if g == null:
		return _local
	return g.S

static var _local: = {}

static func st() -> Dictionary:
	var s: = _store()
	var d: Dictionary = s.get(KEY, {})
	for k in DEFAULTS:
		if not d.has(k):
			d[k] = DEFAULTS[k].duplicate() if DEFAULTS[k] is Dictionary or DEFAULTS[k] is Array else DEFAULTS[k]
	s[KEY] = d
	return d

static func today() -> String:
	return Time.get_date_string_from_system()

# Награды за партию (экран их не начисляет — только считает; начисляет интегратор через V10Econ/V10Wallet).
static func rewards_for(my_total: int, win: bool, day: String = "") -> Dictionary:
	var d: = st()
	if day == "":
		day = today()
	var coins: = maxi(0, my_total) * COINS_PER_POINT + (COINS_WIN if win else 0)
	var gems: = GEMS_FIRST_WIN if win and String(d.day_win) != day else 0
	return {"coins": coins, "gems": gems, "petals": 0, "aff": 1 if win else 0}

# Записать итог партии. yaku_list — все комбинации, собранные игроком (для Книги). Возвращает новые открытия.
static func record(hero: String, my_total: int, win: bool, yaku_list: Array, day: String = "") -> Dictionary:
	var d: = st()
	if day == "":
		day = today()
	var fresh_pages: = []
	for y in yaku_list:
		var n: int = int(d.book.get(y, 0))
		if n == 0:
			fresh_pages.append(y)
		d.book[y] = n + 1
	d.games = int(d.games) + 1
	d.best = maxi(int(d.best), my_total)
	var skin: = ""
	if win:
		d.wins = int(d.wins) + 1
		if String(d.day_win) != day:
			d.day_win = day
		d.beat[hero] = int(d.beat.get(hero, 0)) + 1
		skin = V10MjKoikoiSkins.unlock_for_win(d, hero)
	return {"pages": fresh_pages, "skin": skin}
