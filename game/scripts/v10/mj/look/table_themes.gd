class_name V10MjTables
extends RefCounted

# V10MjTables — the heroines' tables (docs/MODES.md §3.4.3–4, UX_RULES §7.3, spec 0.10 D3).
# 20 records + the house table «Пять ветров». A record is active only when its heroine exists in G.HEROES
# (the five founders today); the other 15 are data waiting for their wave and never reach available().
#
#   V10MjTables.theme_for(partner, rarity = "", outfit_ssr = false) -> Dictionary
#       S / SSR partner (or an SSR outfit on an A heroine): her whole table — cloth, lamp, parallax, ambient,
#       material, tray frame, thread, relic, symbol, signature tile.
#       A partner: the house table, recoloured only in light and particles (UX §7.3 «A — частицы и свет»).
#   V10MjTables.available() -> Array[String]      table ids the player can see (heroine in G.HEROES)
#   V10MjTables.get_theme(id) -> Dictionary       raw record (hidden heroines fall back to the house table)
#   V10MjTables.light(theme, board_rect) -> {lamp, lamp_col, gloss, ambient}   for V10MjTileMaterial.apply_light
#
# Fields: name (plain table name), hero, rank, zone (Салон zone the parallax comes from), cloth {tex, tint, scale},
# lamp {uv, col, k}, bg {far, near}, amb {sfx, fx, fx_col}, material, tray {a, b, trim, well}, thread {col, glow,
# kind}, relic {name, face}, symbol {shape, name}, sig (tile face index, G.TILE_NAMES), accent/glow/deep (UX §6.2).

const A: = "res://assets/v10/mj/look/tables/"

const HOUSE: = {
	"id": "house", "name": "Стол «Пять ветров»", "hero": "", "rank": "", "zone": "Ворота и вывеска",
	"cloth": {"tex": A + "cloth_house.webp", "tint": Color(1, 1, 1), "scale": 360.0},
	"lamp": {"uv": Vector2(0.32, 0.10), "col": Color("ffe9cf"), "k": 0.30},
	"bg": {"far": A + "far_house.webp", "near": ""},
	"amb": {"sfx": "rain", "fx": "dust", "fx_col": Color("ffe2b8")},
	"material": "porcelain",
	"tray": {"a": Color("5a3424"), "b": Color("23120c"), "trim": Color("e2bd72"), "well": Color("140c0a")},
	"thread": {"col": Color("e8c47e"), "glow": Color("fff0c8"), "kind": "silk"},
	"relic": {"name": "Бронзовый колокольчик", "face": 27},
	"symbol": {"shape": "fan", "name": "Веер"},
	"sig": 27, "accent": Color("e8c47e"), "glow": Color("fff0c8"), "deep": Color("6b3f2a"),
}

# order = ROSTER_20 §2. Founders carry full art; wave heroines reuse the house art until their table is painted
# ("art": "pending"), so a heroine added to G.HEROES early still gets a coherent table.
const THEMES: = {
	"mc": {"name": "Стол Маджонг-тян", "rank": "A", "zone": "Кабинет хозяйки", "art": "ready",
		"cloth": {"tex": A + "cloth_mc.webp", "tint": Color(1, 1, 1), "scale": 340.0},
		"lamp": {"uv": Vector2(0.30, 0.08), "col": Color("ffd9e2"), "k": 0.32},
		"bg": {"far": A + "far_mc.webp", "near": A + "near_mc.webp"},
		"amb": {"sfx": "bamboo", "fx": "petals", "fx_col": Color("ffb7cf")},
		"material": "porcelain",
		"tray": {"a": Color("7a2e3e"), "b": Color("2a0f16"), "trim": Color("f1c7a0"), "well": Color("1a0a0f")},
		"thread": {"col": Color("ff8fb8"), "glow": Color("ffe1ec"), "kind": "silk"},
		"relic": {"name": "Фишка «Восток»", "face": 0},
		"symbol": {"shape": "fan", "name": "Веер"},
		"sig": 0, "accent": Color("ff8fb8"), "glow": Color("fff4ec"), "deep": Color("3fae8c")},
	"rin": {"name": "Стол Рин", "rank": "A", "zone": "Чайная стойка", "art": "ready",
		"cloth": {"tex": A + "cloth_rin.webp", "tint": Color(1, 1, 1), "scale": 320.0},
		"lamp": {"uv": Vector2(0.62, 0.08), "col": Color("e4f4ff"), "k": 0.30},
		"bg": {"far": A + "far_rin.webp", "near": A + "near_rin.webp"},
		"amb": {"sfx": "stream", "fx": "tea", "fx_col": Color("bfe8c9")},
		"material": "jade",
		"tray": {"a": Color("2e5a4e"), "b": Color("0f241f"), "trim": Color("e9d8a6"), "well": Color("0a1714")},
		"thread": {"col": Color("7fe0b8"), "glow": Color("e9fff4"), "kind": "frost"},
		"relic": {"name": "Нефритовая пиала", "face": 21},
		"symbol": {"shape": "cup", "name": "Пиала"},
		"sig": 21, "accent": Color("4fbf9f"), "glow": Color("e9d8a6"), "deep": Color("1e3b33")},
	"hana": {"name": "Стол Ханы", "rank": "A", "zone": "Фонарный двор", "art": "ready",
		"cloth": {"tex": A + "cloth_hana.webp", "tint": Color(1, 1, 1), "scale": 0.0},
		"lamp": {"uv": Vector2(0.50, 0.06), "col": Color("ffd9a6"), "k": 0.34},
		"bg": {"far": A + "far_hana.webp", "near": A + "near_hana.webp"},
		"amb": {"sfx": "rain", "fx": "sparks", "fx_col": Color("ffc56b")},
		"material": "amber",
		"tray": {"a": Color("2b4a7a"), "b": Color("0e1a30"), "trim": Color("ffb35c"), "well": Color("0a1222")},
		"thread": {"col": Color("ffb35c"), "glow": Color("fff1d6"), "kind": "spark"},
		"relic": {"name": "Эстафетная палочка", "face": 3},
		"symbol": {"shape": "sun", "name": "Солнце"},
		"sig": 3, "accent": Color("ffb35c"), "glow": Color("fff1d6"), "deep": Color("2b4a7a")},
	"tsubame": {"name": "Стол Цубамэ", "rank": "A", "zone": "Крыша почтовой башни", "art": "pending",
		"lamp": {"uv": Vector2(0.4, 0.1), "col": Color("c9cfe0"), "k": 0.26},
		"amb": {"sfx": "bamboo", "fx": "smoke", "fx_col": Color("a9b0c2")}, "material": "lacquer",
		"tray": {"a": Color("2a2840"), "b": Color("0d0c16"), "trim": Color("c8283c"), "well": Color("09080f")},
		"thread": {"col": Color("c8283c"), "glow": Color("f0c8cf"), "kind": "silk"},
		"relic": {"name": "Запечатанное письмо", "face": 1}, "symbol": {"shape": "swallow", "name": "Ласточка"},
		"sig": 1, "accent": Color("c8283c"), "glow": Color("a9b0c2"), "deep": Color("1d1b2e")},
	"miel": {"name": "Стол Миэль", "rank": "A", "zone": "Кондитерская", "art": "pending",
		"lamp": {"uv": Vector2(0.35, 0.1), "col": Color("ffe6c8"), "k": 0.32},
		"amb": {"sfx": "rain", "fx": "sugar", "fx_col": Color("f6e7cf")}, "material": "amber",
		"tray": {"a": Color("8a5a35"), "b": Color("3a2210"), "trim": Color("e0566f"), "well": Color("24150a")},
		"thread": {"col": Color("e0566f"), "glow": Color("ffe3e8"), "kind": "silk"},
		"relic": {"name": "Серебряный венчик", "face": 16}, "symbol": {"shape": "cake", "name": "Торт"},
		"sig": 16, "accent": Color("e0566f"), "glow": Color("f6e7cf"), "deep": Color("c98a4b")},
	"lian": {"name": "Стол Лянь", "rank": "A", "zone": "Чайная лодка", "art": "pending",
		"lamp": {"uv": Vector2(0.6, 0.1), "col": Color("f1d6cf"), "k": 0.28},
		"amb": {"sfx": "stream", "fx": "ripples", "fx_col": Color("c9e4e8")}, "material": "jade",
		"tray": {"a": Color("1f4e5a"), "b": Color("0a1c21"), "trim": Color("c9a35b"), "well": Color("071417")},
		"thread": {"col": Color("c9a35b"), "glow": Color("f6e8c8"), "kind": "string"},
		"relic": {"name": "Медиатор пипы", "face": 34}, "symbol": {"shape": "koi", "name": "Карп"},
		"sig": 34, "accent": Color("c9a35b"), "glow": Color("f1d6cf"), "deep": Color("1f4e5a")},
	"jess": {"name": "Стол Джесс", "rank": "A", "zone": "Веранда тракта", "art": "pending",
		"lamp": {"uv": Vector2(0.5, 0.08), "col": Color("ffd9a0"), "k": 0.34},
		"amb": {"sfx": "bamboo", "fx": "dust", "fx_col": Color("e8cf9a")}, "material": "bone",
		"tray": {"a": Color("5a3a24"), "b": Color("24140a"), "trim": Color("e8cf9a"), "well": Color("160c06")},
		"thread": {"col": Color("b5532f"), "glow": Color("f2d3b8"), "kind": "rope"},
		"relic": {"name": "Шпора", "face": 5}, "symbol": {"shape": "horseshoe", "name": "Подкова"},
		"sig": 5, "accent": Color("b5532f"), "glow": Color("e8cf9a"), "deep": Color("3d5a80")},
	"tsuru": {"name": "Стол Цуру", "rank": "A", "zone": "Онсэн", "art": "pending",
		"lamp": {"uv": Vector2(0.45, 0.1), "col": Color("ffcfa8"), "k": 0.3},
		"amb": {"sfx": "stream", "fx": "steam", "fx_col": Color("f1ece4")}, "material": "lacquer",
		"tray": {"a": Color("2e3a6b"), "b": Color("10142a"), "trim": Color("e0703b"), "well": Color("0a0d1c")},
		"thread": {"col": Color("e0703b"), "glow": Color("ffe1cc"), "kind": "silk"},
		"relic": {"name": "Бумажный журавль", "face": 28}, "symbol": {"shape": "crane", "name": "Журавль"},
		"sig": 28, "accent": Color("e0703b"), "glow": Color("f1ece4"), "deep": Color("2e3a6b")},
	"yue": {"name": "Стол Юэ", "rank": "S", "zone": "Лунная веранда", "art": "ready",
		"cloth": {"tex": A + "cloth_yue.webp", "tint": Color(1, 1, 1), "scale": 330.0},
		"lamp": {"uv": Vector2(0.68, 0.06), "col": Color("dfe2ff"), "k": 0.34},
		"bg": {"far": A + "far_yue.webp", "near": A + "near_yue.webp"},
		"amb": {"sfx": "bamboo", "fx": "fireflies", "fx_col": Color("e6e0ff")},
		"material": "ice",
		"tray": {"a": Color("3b2a55"), "b": Color("120b22"), "trim": Color("e8e4f4"), "well": Color("0b0716")},
		"thread": {"col": Color("c8b6ff"), "glow": Color("f4f0ff"), "kind": "moon"},
		"relic": {"name": "Лунный нефритовый заяц", "face": 30},
		"symbol": {"shape": "moon", "name": "Луна"},
		"sig": 7, "accent": Color("c8b6ff"), "glow": Color("e8e4f4"), "deep": Color("2a2350")},
	"nova": {"name": "Стол Новы", "rank": "S", "zone": "Мансарда Новы", "art": "ready",
		"cloth": {"tex": A + "cloth_nova.webp", "tint": Color(1, 1, 1), "scale": 300.0},
		"lamp": {"uv": Vector2(0.25, 0.08), "col": Color("c8f6ff"), "k": 0.28},
		"bg": {"far": A + "far_nova.webp", "near": A + "near_nova.webp"},
		"amb": {"sfx": "rain", "fx": "rain", "fx_col": Color("8fefff")},
		"material": "lacquer",
		"tray": {"a": Color("262a3d"), "b": Color("07080f"), "trim": Color("4fe3ff"), "well": Color("05060b")},
		"thread": {"col": Color("4fe3ff"), "glow": Color("ff6fd8"), "kind": "laser"},
		"relic": {"name": "Ключ-накопитель", "face": 24},
		"symbol": {"shape": "diamond", "name": "Кристалл"},
		"sig": 24, "accent": Color("4fe3ff"), "glow": Color("ff6fd8"), "deep": Color("1a1530")},
	"kohaku": {"name": "Стол Кохаку", "rank": "S", "zone": "Храм Тысячи врат", "art": "pending",
		"lamp": {"uv": Vector2(0.4, 0.08), "col": Color("ffd2a0"), "k": 0.34},
		"amb": {"sfx": "bamboo", "fx": "foxfire", "fx_col": Color("e2a23d")}, "material": "lacquer",
		"tray": {"a": Color("8a1f17"), "b": Color("2e0806"), "trim": Color("e2a23d"), "well": Color("1c0503")},
		"thread": {"col": Color("d63a2a"), "glow": Color("ffd8a0"), "kind": "foxfire"},
		"relic": {"name": "Колокольчик судзу", "face": 31}, "symbol": {"shape": "torii", "name": "Тории"},
		"sig": 31, "accent": Color("d63a2a"), "glow": Color("e2a23d"), "deep": Color("f3efe9")},
	"shirin": {"name": "Стол Ширин", "rank": "S", "zone": "Шатёр каравана", "art": "pending",
		"lamp": {"uv": Vector2(0.5, 0.08), "col": Color("ffe2a8"), "k": 0.36},
		"amb": {"sfx": "bamboo", "fx": "sand", "fx_col": Color("d9b26f")}, "material": "amber",
		"tray": {"a": Color("1f6f6a"), "b": Color("0a2422"), "trim": Color("c08a1e"), "well": Color("061816")},
		"thread": {"col": Color("c08a1e"), "glow": Color("ffe8b0"), "kind": "silk"},
		"relic": {"name": "Песочные часы", "face": 9}, "symbol": {"shape": "star8", "name": "Звезда пустыни"},
		"sig": 9, "accent": Color("1f8f8a"), "glow": Color("d9b26f"), "deep": Color("c08a1e")},
	"mari": {"name": "Стол Марисоль", "rank": "S", "zone": "Палуба клипера", "art": "pending",
		"lamp": {"uv": Vector2(0.55, 0.1), "col": Color("ffe6b8"), "k": 0.3},
		"amb": {"sfx": "rain", "fx": "spray", "fx_col": Color("d4e6f0")}, "material": "bone",
		"tray": {"a": Color("3a2a1c"), "b": Color("140d08"), "trim": Color("d4b15a"), "well": Color("0c0805")},
		"thread": {"col": Color("c23a3a"), "glow": Color("f6dada"), "kind": "rope"},
		"relic": {"name": "Корабельный колокол", "face": 26}, "symbol": {"shape": "anchor", "name": "Якорь"},
		"sig": 26, "accent": Color("c23a3a"), "glow": Color("d4b15a"), "deep": Color("1f2f4a")},
	"hibana": {"name": "Стол Хибаны", "rank": "S", "zone": "Гроза над садом", "art": "pending",
		"lamp": {"uv": Vector2(0.5, 0.06), "col": Color("fff2b8"), "k": 0.3},
		"amb": {"sfx": "rain", "fx": "sparks", "fx_col": Color("ffd23f")}, "material": "lacquer",
		"tray": {"a": Color("2c2650"), "b": Color("0e0b1c"), "trim": Color("ffd23f"), "well": Color("08060f")},
		"thread": {"col": Color("ffd23f"), "glow": Color("fff6c8"), "kind": "spark"},
		"relic": {"name": "Палочки тайко", "face": 14}, "symbol": {"shape": "bolt", "name": "Молния"},
		"sig": 14, "accent": Color("ffd23f"), "glow": Color("8e8fa3"), "deep": Color("2c2650")},
	"nemi": {"name": "Стол Неми", "rank": "S", "zone": "Дикий чайный лес", "art": "pending",
		"lamp": {"uv": Vector2(0.35, 0.06), "col": Color("f4f0d0"), "k": 0.3},
		"amb": {"sfx": "stream", "fx": "leaves", "fx_col": Color("b8612e")}, "material": "bone",
		"tray": {"a": Color("4f6b35"), "b": Color("18220f"), "trim": Color("ece4cf"), "well": Color("0f1609")},
		"thread": {"col": Color("b8612e"), "glow": Color("f6dcc2"), "kind": "vine"},
		"relic": {"name": "Наконечник стрелы", "face": 6}, "symbol": {"shape": "leaf", "name": "Лист"},
		"sig": 6, "accent": Color("b8612e"), "glow": Color("ece4cf"), "deep": Color("4f6b35")},
	"zlata": {"name": "Стол Златы", "rank": "SSR", "zone": "Терем Жар-птицы", "art": "pending",
		"lamp": {"uv": Vector2(0.5, 0.06), "col": Color("ffd59a"), "k": 0.36},
		"amb": {"sfx": "bamboo", "fx": "feathers", "fx_col": Color("e8b23a")}, "material": "amber",
		"tray": {"a": Color("8a1a1f"), "b": Color("2c0709"), "trim": Color("e8b23a"), "well": Color("1b0405")},
		"thread": {"col": Color("e8b23a"), "glow": Color("ffe8b0"), "kind": "feather"},
		"relic": {"name": "Перо Жар-птицы", "face": 12}, "symbol": {"shape": "firebird", "name": "Жар-птица"},
		"sig": 12, "accent": Color("c3242b"), "glow": Color("e8b23a"), "deep": Color("1b1513")},
	"minamo": {"name": "Стол Минамо", "rank": "SSR", "zone": "Жемчужный дворец", "art": "pending",
		"lamp": {"uv": Vector2(0.5, 0.04), "col": Color("d8fff8"), "k": 0.32},
		"amb": {"sfx": "stream", "fx": "bubbles", "fx_col": Color("7fd3d0")}, "material": "ice",
		"tray": {"a": Color("3a4fa0"), "b": Color("101a3a"), "trim": Color("f3e9f1"), "well": Color("0a1128")},
		"thread": {"col": Color("7fd3d0"), "glow": Color("f3e9f1"), "kind": "pearl"},
		"relic": {"name": "Чёрная жемчужина", "face": 13}, "symbol": {"shape": "shell", "name": "Раковина"},
		"sig": 13, "accent": Color("7fd3d0"), "glow": Color("f3e9f1"), "deep": Color("3a4fa0")},
	"kira": {"name": "Стол Киры", "rank": "SSR", "zone": "Ангар «Хризантема»", "art": "pending",
		"lamp": {"uv": Vector2(0.3, 0.06), "col": Color("f2f2f5"), "k": 0.3},
		"amb": {"sfx": "rain", "fx": "sparks", "fx_col": Color("e03a3e")}, "material": "lacquer",
		"tray": {"a": Color("2a3a5c"), "b": Color("0c1220"), "trim": Color("e03a3e"), "well": Color("070b14")},
		"thread": {"col": Color("e03a3e"), "glow": Color("f2f2f5"), "kind": "laser"},
		"relic": {"name": "Жетон пилота", "face": 8}, "symbol": {"shape": "chrysanthemum", "name": "Хризантема"},
		"sig": 8, "accent": Color("e03a3e"), "glow": Color("f2f2f5"), "deep": Color("1c2b4a")},
	"vesper": {"name": "Стол Веспер", "rank": "SSR", "zone": "Алая галерея", "art": "pending",
		"lamp": {"uv": Vector2(0.5, 0.06), "col": Color("ffc8c0"), "k": 0.26},
		"amb": {"sfx": "rain", "fx": "petals", "fx_col": Color("9a1a2a")}, "material": "lacquer",
		"tray": {"a": Color("4a0a14"), "b": Color("140306"), "trim": Color("c9c3cf"), "well": Color("0c0204")},
		"thread": {"col": Color("b0182a"), "glow": Color("f0d0d6"), "kind": "silk"},
		"relic": {"name": "Гранатовый кубок", "face": 25}, "symbol": {"shape": "rose", "name": "Роза"},
		"sig": 25, "accent": Color("b0182a"), "glow": Color("c9c3cf"), "deep": Color("141018")},
	"sigrid": {"name": "Стол Сигрид", "rank": "SSR", "zone": "Ледяной чертог", "art": "pending",
		"lamp": {"uv": Vector2(0.5, 0.04), "col": Color("e6f8ff"), "k": 0.32},
		"amb": {"sfx": "bamboo", "fx": "snow", "fx_col": Color("dff1f7")}, "material": "ice",
		"tray": {"a": Color("4a5a8a"), "b": Color("141a30"), "trim": Color("dff1f7"), "well": Color("0c1020")},
		"thread": {"col": Color("8b7fd6"), "glow": Color("dff1f7"), "kind": "aurora"},
		"relic": {"name": "Корона инея", "face": 11}, "symbol": {"shape": "snowflake", "name": "Снежинка"},
		"sig": 11, "accent": Color("7fc8d8"), "glow": Color("dff1f7"), "deep": Color("8b7fd6")},
}

const ORDER: = ["mc", "rin", "hana", "tsubame", "miel", "lian", "jess", "tsuru", "yue", "nova", "kohaku", "shirin",
	"mari", "hibana", "nemi", "zlata", "minamo", "kira", "vesper", "sigrid"]
const FOUNDERS: = ["mc", "rin", "hana", "yue", "nova"]


static func _heroes() -> Dictionary:
	var tree: = Engine.get_main_loop() as SceneTree
	var g = tree.root.get_node_or_null("G") if tree and tree.root else null
	if g == null:
		return {}
	return g.HEROES


static func is_active(id: String) -> bool:
	return THEMES.has(id) and _heroes().has(id)


# every table the player can see: heroines that exist in the game, in roster order
static func available() -> Array:
	var out: = []
	var hs: = _heroes()
	for id in ORDER:
		if hs.has(id):
			out.append(id)
	return out


# raw record merged over the house table (missing fields come from the house). A hidden heroine → house.
static func get_theme(id: String, allow_hidden: = false) -> Dictionary:
	if id == "" or id == "house" or not THEMES.has(id) or (not allow_hidden and not is_active(id)):
		var h: = HOUSE.duplicate(true)
		return h
	var out: = HOUSE.duplicate(true)
	var t: Dictionary = THEMES[id]
	for k in t:
		out[k] = t[k].duplicate(true) if (t[k] is Dictionary) else t[k]
	out.id = id
	out.hero = id
	if String(t.get("art", "")) != "ready":
		# no painting yet: keep the house cloth and parallax, her colours tint them
		out.cloth = HOUSE.cloth.duplicate(true)
		out.cloth.tint = Color(1, 1, 1).lerp(t.get("deep", Color.WHITE), 0.18)
		out.bg = HOUSE.bg.duplicate(true)
	return out


static func rank_of(hero: String) -> String:
	return String(THEMES.get(hero, {}).get("rank", "A"))


# the table a match uses for this partner (UX §7.3)
static func theme_for(partner: String, rarity: = "", outfit_ssr: = false) -> Dictionary:
	if partner == "" or not is_active(partner):
		return get_theme("house")
	var r: = rarity if rarity != "" else rank_of(partner)
	var th: = get_theme(partner)
	if r in ["S", "SSR"] or outfit_ssr:
		th.full = true
		return th
	# A: the house table; only the light and the particles are hers
	var h: = get_theme("house")
	h.id = "house:" + partner
	h.hero = partner
	h.full = false
	h.lamp = h.lamp.duplicate(true)
	h.lamp.col = Color(h.lamp.col).lerp(th.lamp.col, 0.6)
	h.amb = h.amb.duplicate(true)
	h.amb.fx = th.amb.fx
	h.amb.fx_col = th.amb.fx_col
	h.accent = th.accent
	h.glow = th.glow
	h.sig = th.sig
	h.thread = th.thread
	return h


# lamp in canvas px over the board rect (the light the tiles see)
static func light(th: Dictionary, board_rect: Rect2) -> Dictionary:
	var uv: Vector2 = th.lamp.uv
	var pos: = board_rect.position + board_rect.size * uv
	var amb: Color = th.get("deep", Color(0.2, 0.2, 0.2))
	return {"lamp": pos, "lamp_col": th.lamp.col, "gloss": 1.0, "ambient": Color(amb.r * 0.35, amb.g * 0.35, amb.b * 0.35)}
