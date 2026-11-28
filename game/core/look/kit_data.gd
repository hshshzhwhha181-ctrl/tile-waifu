class_name V10KitData
extends RefCounted

# V10KitData — «Набор богини» (docs/0.10-spec.md D1, ROSTER_20 §1.3). Pure data + rank rules, no state.
#
# What a rank opens (ROSTER §1.3):
#   A   — рамка + акцент (highlight colour and pair particles)
#   S   — + тема фишек + стол
#   SSR — + HUD-скин + стинг + шрифт
# An SSR outfit lifts an A goddess's kit to S (never higher): o_dragon → «Золото дракона» + «Драконий сад»,
# r_agent / r_idol → «Нефрит и иней» + «Ледяной павильон», h_gym → «Финишная лента» + «Стадион на закате».
# SSR outfits of an SSR goddess change only her HUD palette (shader presets, no new art).
#
# Ranks come from V10Rank when the economy branch is merged (README «Хуки» №1); until then RANK_OF_RAR maps the
# 0.9 `rar` 1:1 (R→A, SR→S, SSR→SSR), exactly what ROSTER §1.1 prescribes.

const ELEMENTS: = ["frame", "accent", "tile", "table", "hud", "sting", "font"]
# player-facing names (UX §3.2 «Стиль: Рамка · Фишки · Стол · Интерфейс · Стинг · Шрифт»; §4.1 — no «HUD» on screen)
const ELEMENT_NAMES: = {"frame": "Рамка", "accent": "Акцент", "tile": "Тема фишек", "table": "Стол", "hud": "Интерфейс",
	"sting": "Стинг", "font": "Шрифт"}
# the lowest kit rank that carries the element
const ELEMENT_RANK: = {"frame": "A", "accent": "A", "tile": "S", "table": "S", "hud": "SSR", "sting": "SSR", "font": "SSR"}
const RANKS: = ["A", "S", "SSR"]
const RANK_OF_RAR: = {"R": "A", "SR": "S", "SSR": "SSR", "A": "A", "S": "S"}
const BASE_HUD: = "five_winds"
const BASE_FRAME: = "fr_default"

# particles of the accent (V10PairFx presets)
const PARTICLES: = ["petals", "leaves", "sparks", "dust", "glitch", "feathers", "pearls", "frost", "embers"]

# hero -> kit. `hidden` kits belong to goddesses not yet in G.HEROES (wave 1–3): data is complete enough for the
# selftest and the banner preview, but nothing lists them until the goddess is released.
const KITS: = {
	"mc": {"rank": "A", "name": "Пять ветров", "frame": "fr_g_mc",
		"accent": {"name": "Сакура", "col": "ff8fb8", "glow": "ffd3e0", "deep": "8e3f5c", "particles": "petals"},
		"legacy_tile": "s_sakura", "sig": 0,
		"up": {"o_dragon": {"tile": "s_gold", "table": "tb_dragon"}}},
	"rin": {"rank": "A", "name": "Ледяной павильон", "frame": "fr_g_rin",
		"accent": {"name": "Мята", "col": "7fcfb0", "glow": "cdefe0", "deep": "2e6b57", "particles": "leaves"},
		"legacy_tile": "s_mint", "sig": 21,
		"up": {"r_agent": {"tile": "s_jade_frost", "table": "tb_ice_pavilion"},
			"r_idol": {"tile": "s_jade_frost", "table": "tb_ice_pavilion"}}},
	"hana": {"rank": "A", "name": "Фонарная эстафета", "frame": "fr_g_hana",
		"accent": {"name": "Лимон", "col": "ffb25a", "glow": "ffe0b0", "deep": "a3521c", "particles": "sparks"},
		"legacy_tile": "s_lemon", "sig": 3,
		"up": {"h_gym": {"tile": "s_finish", "table": "tb_stadium"}}},
	"yue": {"rank": "S", "name": "Лунный дворец", "frame": "fr_g_yue",
		"accent": {"name": "Лунная пыль", "col": "c9b2f0", "glow": "eee6ff", "deep": "5a4690", "particles": "dust"},
		"tile": "s_night", "table": "tb_palace", "sig": 7},
	"nova": {"rank": "S", "name": "Неоновая ночь", "frame": "fr_g_nova",
		"accent": {"name": "Глитч", "col": "6fe6f2", "glow": "d2faff", "deep": "7a2e8e", "particles": "glitch"},
		"tile": "s_neon", "table": "tb_neon", "sig": 24},
	"zlata": {"rank": "SSR", "name": "Лаковая сказка", "frame": "fr_g_zlata", "hidden": true,
		"accent": {"name": "Жар-перо", "col": "ff7a2a", "glow": "ffd08a", "deep": "8e1a14", "particles": "feathers"},
		"tile": "s_lacquer", "table": "tb_lacquer_box", "hud": "zlata", "sting": "zlata", "font": "zlata", "sig": 12,
		"palettes": {"zl_base": "firebird", "zl_fair": "firebird", "zl_ember": "ember", "zl_vow": "dawn"}},
	# ---- wave 1–3 stubs (hidden until released; themes arrive with their waves, 1.0) ----
	"tsubame": {"rank": "A", "hidden": true, "frame": "fr_default", "sig": 1,
		"accent": {"name": "Дым", "col": "c8283c", "glow": "e6a0aa", "deep": "1d1b2e", "particles": "dust"}},
	"miel": {"rank": "A", "hidden": true, "frame": "fr_default", "sig": 16,
		"accent": {"name": "Сахар", "col": "e0566f", "glow": "f6e7cf", "deep": "c98a4b", "particles": "sparks"}},
	"lian": {"rank": "A", "hidden": true, "frame": "fr_default", "sig": 34,
		"accent": {"name": "Река", "col": "c9a35b", "glow": "f1d6cf", "deep": "1f4e5a", "particles": "leaves"}},
	"jess": {"rank": "A", "hidden": true, "frame": "fr_default", "sig": 5,
		"accent": {"name": "Закат", "col": "b5532f", "glow": "e8cf9a", "deep": "3d5a80", "particles": "dust"}},
	"tsuru": {"rank": "A", "hidden": true, "frame": "fr_default", "sig": 28,
		"accent": {"name": "Пар", "col": "e0703b", "glow": "f1ece4", "deep": "2e3a6b", "particles": "dust"}},
	"kohaku": {"rank": "S", "hidden": true, "frame": "fr_default", "sig": 31,
		"accent": {"name": "Лисий огонь", "col": "d63a2a", "glow": "e2a23d", "deep": "f3efe9", "particles": "embers"}},
	"shirin": {"rank": "S", "hidden": true, "frame": "fr_default", "sig": 9,
		"accent": {"name": "Песок", "col": "d9b26f", "glow": "f6e3b8", "deep": "1f8f8a", "particles": "dust"}},
	"mari": {"rank": "S", "hidden": true, "frame": "fr_default", "sig": 26,
		"accent": {"name": "Шторм", "col": "c23a3a", "glow": "d4b15a", "deep": "1f2f4a", "particles": "pearls"}},
	"hibana": {"rank": "S", "hidden": true, "frame": "fr_default", "sig": 14,
		"accent": {"name": "Гром", "col": "ffd23f", "glow": "fff1a8", "deep": "2c2650", "particles": "sparks"}},
	"nemi": {"rank": "S", "hidden": true, "frame": "fr_default", "sig": 6,
		"accent": {"name": "Лес", "col": "b8612e", "glow": "ece4cf", "deep": "4f6b35", "particles": "leaves"}},
	"minamo": {"rank": "SSR", "hidden": true, "frame": "fr_g_minamo", "font": "minamo", "sig": 13,
		"accent": {"name": "Жемчуг", "col": "7fd3d0", "glow": "f3e9f1", "deep": "3a4fa0", "particles": "pearls"}},
	"kira": {"rank": "SSR", "hidden": true, "frame": "fr_g_kira", "font": "kira", "sig": 8,
		"accent": {"name": "Тяга", "col": "e03a3e", "glow": "f2f2f5", "deep": "1c2b4a", "particles": "sparks"}},
	"vesper": {"rank": "SSR", "hidden": true, "frame": "fr_g_vesper", "font": "vesper", "sig": 25,
		"accent": {"name": "Алая ночь", "col": "c42a44", "glow": "c9c3cf", "deep": "141018", "particles": "petals"}},
	"sigrid": {"rank": "SSR", "hidden": true, "frame": "fr_g_sigrid", "font": "sigrid", "sig": 11,
		"accent": {"name": "Иней", "col": "7fc8d8", "glow": "dff1f7", "deep": "8b7fd6", "particles": "frost"}},
}

# outfits that do not exist in G.ITEMS yet (SSR goddesses): id -> [hero, rar]
const EXTRA_OUTFITS: = {
	"zl_base": ["zlata", "SSR", "Жар-птица"], "zl_fair": ["zlata", "S", "Масленичная ярмарка"],
	"zl_ember": ["zlata", "SSR", "Царица-пламя"], "zl_vow": ["zlata", "SSR", "Обет Жар-птицы"],
}
# chip captions of the kit ribbon (short)
const ELEMENT_SHORT: = {"frame": "Рамка", "accent": "Акцент", "tile": "Фишки", "table": "Стол", "hud": "Интерфейс",
	"sting": "Стинг", "font": "Шрифт"}

# stings: short fanfare at «Сделать партнёром» (1,5 с) and the full one once a session on entering Чайная (4–6 с).
# Files land with the v10-audio merge; the path is checked lazily and the call is silent while it is missing.
const STINGS: = {
	"zlata": {"name": "Гусли и хор «ой»", "short": "res://assets/v10/audio/sting/zlata_short.ogg",
		"full": "res://assets/v10/audio/sting/zlata_full.ogg", "len": 5.0},
}


static func kit(hero: String) -> Dictionary:
	return KITS.get(hero, {})


static func heroes(include_hidden: = false) -> Array:
	var out: = []
	for h in KITS:
		if include_hidden or not bool(KITS[h].get("hidden", false)):
			out.append(h)
	return out


static func rank_index(r: String) -> int:
	return maxi(0, RANKS.find(r))


static func hero_rank(hero: String) -> String:
	# V10Rank (economy branch) wins when present
	if _has_class("V10Rank"):
		var rk = _call_static("V10Rank", "hero_rank", [hero])
		if rk is String and rk in RANKS:
			return rk
	return String(KITS.get(hero, {}).get("rank", "A"))


static func outfit_name(outfit: String) -> String:
	if EXTRA_OUTFITS.has(outfit):
		return String(EXTRA_OUTFITS[outfit][2])
	return String(_item(outfit).get("name", outfit))


static func outfit_hero(outfit: String) -> String:
	if EXTRA_OUTFITS.has(outfit):
		return EXTRA_OUTFITS[outfit][0]
	var it: = _item(outfit)
	return String(it.get("hero", ""))


static func outfit_rank(outfit: String) -> String:
	if outfit == "":
		return ""
	if _has_class("V10Rank"):
		var rk = _call_static("V10Rank", "outfit_rank", [outfit])
		if rk is String and rk in RANKS:
			return rk
	if EXTRA_OUTFITS.has(outfit):
		return String(EXTRA_OUTFITS[outfit][1])
	var it: = _item(outfit)
	return String(RANK_OF_RAR.get(String(it.get("rar", "")), ""))


# kit rank for a hero wearing `outfit`: the hero's rank, lifted one step (max S) by an SSR outfit on an A goddess
static func kit_rank(hero: String, outfit: String) -> String:
	var r: = hero_rank(hero)
	if r == "A" and outfit_rank(outfit) == "SSR" and kit(hero).get("up", {}).has(outfit):
		return "S"
	return r


static func element_open(element: String, rank: String) -> bool:
	return rank_index(rank) >= rank_index(String(ELEMENT_RANK.get(element, "SSR")))


static func lock_text(element: String) -> String:
	return "у %s" % ELEMENT_RANK.get(element, "SSR")


# The ONE closed teaser of the kit ribbon (UX §6.4, §10 В-8): what the next kit rank adds, and how it opens.
# {rank, elements: [..], title: «Фишки и стол», how: «Откроется: наряд «…»» | «Есть у набора S»}; {} for a full kit.
static func next_teaser(hero: String, outfit: String) -> Dictionary:
	var r: = kit_rank(hero, outfit)
	var i: = rank_index(r)
	if i >= RANKS.size() - 1:
		return {}
	var nxt: String = RANKS[i + 1]
	var els: = []
	for e in ELEMENTS:
		if ELEMENT_RANK[e] == nxt:
			els.append(e)
	var names: = []
	for e in els:
		names.append(String(ELEMENT_SHORT[e]) if names.is_empty() else String(ELEMENT_SHORT[e]).to_lower())
	var title: = " · ".join(names) if names.size() > 2 else " и ".join(names)
	var how: = "Есть у набора %s" % nxt
	if nxt == "S":
		for o in kit(hero).get("up", {}):
			if o != outfit:
				how = "Откроется: наряд «%s»" % outfit_name(o)
				break
	return {"rank": nxt, "elements": els, "title": title, "how": how}


static func _item(id: String) -> Dictionary:
	var g: = _g()
	if g == null:
		return {}
	var m = g.get("ITEM")
	return m.get(id, {}) if m is Dictionary else {}


static func _g() -> Node:
	var tree: = Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("G") if tree else null


# class lookups are cached: the global class list is fixed at run time, and resolve() runs per board / per kit
static var _class_path: = {}


static func _class(cn: String) -> String:
	if not _class_path.has(cn):
		_class_path[cn] = ""
		for c in ProjectSettings.get_global_class_list():
			if String(c.get("class", "")) == cn:
				_class_path[cn] = String(c.path)
				break
	return _class_path[cn]


static func _has_class(cn: String) -> bool:
	return _class(cn) != ""


static func _call_static(cn: String, fn: String, args: Array):
	var path: = _class(cn)
	if path == "":
		return null
	var scr: Script = load(path)
	if scr == null:
		return null
	for m in scr.get_script_method_list():
		if String(m.name) == fn:
			return scr.callv(fn, args)
	return null
