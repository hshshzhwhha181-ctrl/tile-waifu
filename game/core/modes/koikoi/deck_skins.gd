class_name V10MjKoikoiSkins
extends RefCounted

# Альбом «Ханафуда героинь» (IDEAS №7): 5 светлых карт имеют вариант с героиней-основательницей.
# Чистая косметика: меняет ТОЛЬКО картинку карты. Силы не даёт, не продаётся.
# Открытие: первая победа в партии над этой героиней.

const DIR: = "res://assets/v10/mj/koikoi/"
const BASE: = DIR + "cards/c%02d.webp"
const BACK: = DIR + "cards/back.webp"

# светлая карта (tag) → героиня
const HEROINE_LIGHTS: = {
	"crane": "rin",      # январь, журавль и солнце — Рин с пиалой
	"curtain": "mc",     # март, занавес вишни — Маджонг-тян с веером
	"moon": "yue",       # август, луна над мискантом — Юэ
	"rain": "nova",      # ноябрь, дождь под ивой — Нова с зонтом
	"phoenix": "hana",   # декабрь, феникс — Хана
}
const HERO_TO_TAG: = {"rin": "crane", "mc": "curtain", "yue": "moon", "nova": "rain", "hana": "phoenix"}
const NAMES: = {"crane": "Журавль", "curtain": "Занавес вишни", "moon": "Луна", "rain": "Дождь", "phoenix": "Феникс"}

static func skin_path(tg: String) -> String:
	return DIR + "heroines/%s_%s.webp" % [tg, HEROINE_LIGHTS.get(tg, "")]

static func base_path(c: int) -> String:
	return BASE % c

# Путь картинки карты с учётом открытых скинов. skins: {tag: true}; enabled — выключатель «показывать героинь».
static func texture_path(c: int, skins: Dictionary, enabled: bool = true) -> String:
	var tg: = V10MjKoikoi.tag(c)
	if enabled and V10MjKoikoi.kind(c) == "light" and skins.get(tg, false):
		var p: = skin_path(tg)
		if ResourceLoader.exists(p):
			return p
	return base_path(c)

static var _cache: = {}

static func texture(c: int, skins: Dictionary = {}, enabled: bool = true) -> Texture2D:
	var p: = texture_path(c, skins, enabled)
	if _cache.has(p):
		return _cache[p]
	var t: Texture2D = load(p) if ResourceLoader.exists(p) else null
	_cache[p] = t
	return t

static func back() -> Texture2D:
	if _cache.has(BACK):
		return _cache[BACK]
	var t: Texture2D = load(BACK) if ResourceLoader.exists(BACK) else null
	_cache[BACK] = t
	return t

static func unlock_for_win(d: Dictionary, hero: String) -> String:
	var tg: String = HERO_TO_TAG.get(hero, "")
	if tg == "" or d.skins.get(tg, false):
		return ""
	d.skins[tg] = true
	return tg

static func album(d: Dictionary) -> Array:
	var out: = []
	for tg in HEROINE_LIGHTS:
		out.append({"tag": tg, "hero": HEROINE_LIGHTS[tg], "name": NAMES[tg], "open": d.skins.get(tg, false), "card": V10MjKoikoi.find(tg)})
	return out
