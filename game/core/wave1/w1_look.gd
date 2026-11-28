class_name V10W1Look
extends RefCounted

# V10W1Look — «Лицо богинь» волны 1: Цубамэ, Миэль, Кохаку, Ширин, Злата (docs/0.10-spec.md D1–D3, D5, D7;
# ROSTER_20 §1.3 — A: рамка + акцент · S: + тема фишек + стол · SSR: + HUD-скин, стинг, шрифт).
# Pure data in the exact schemas of the look consumers + install(), which overlays it. The release gate lives in the
# integrator's facade: call install() only when V10Wave1.released(); until then the kit_data stubs stay hidden.
#
#   KITS           -> V10KitData.KITS            rank, kit name, frame, accent, theme/table (S+), HUD/sting/font (SSR),
#                                                 signature face, `up` (SSR outfit lifts an A kit to S), Zlata palettes
#   EXTRA_OUTFITS  -> V10KitData.EXTRA_OUTFITS   18 outfits: [hero, rank, name] (resolve() works before G.ITEM has them)
#   THEMES/TABLES  -> V10TileTheme.THEMES/TABLES 4 new themes + 4 tables (Zlata keeps s_lacquer / tb_lacquer_box)
#   FRAMES         -> V10ProfileCos.register()   fr_g_<hero> (§2.7: frames live only there; fr_g_zlata is already in)
#   HUD_HEROES     -> V10DS.HEROES               hud2 accent / glow / deep + showcase element
#   COMBO_LINES    -> V10ComboShowcase.LINES     one line per showcase tier ×10 / ×20
#   combo_sprite() / combo_meta()                 showcase fallback: the wave-1 cut-out + face rect from w1_art_rig.json
#   install() -> Array      overlay everything (idempotent); problems found, [] = done
#   selfcheck(installed) -> Array   data checks for --wave1_selftest (contrast, ranks, registry schema, stop-words…)
#
# Founders' kit frames are drawn by code (V10FrameView: painted ring recoloured + a code-drawn deco), so these are
# data only. Theme emblems are procedural (tools/w1_look_emblems.py -> assets/v10/wave1/look/emblems/).

const ORDER: = ["tsubame", "miel", "kohaku", "shirin", "zlata"]
const RANK: = {"tsubame": "A", "miel": "A", "kohaku": "S", "shirin": "S", "zlata": "SSR"}
# signature tile face (G.TILE_NAMES): plum, cake, fox, sun, fire
const SIG: = {"tsubame": 1, "miel": 16, "kohaku": 31, "shirin": 9, "zlata": 12}
const EMBLEMS: = "res://assets/v10/wave1/look/emblems/"
const ART_RIG: = "res://core/wave1/data/w1_art_rig.json"
const HERO_DIR: = "res://assets/v10/wave1/hero/"
const TILE_INK: = Color("3b2a2f")   # the ink of the tile faces (look selftest contrast rule)

# ------------------------------------------------------------------------------------------------- D1 kits

const KITS: = {
	"tsubame": {"rank": "A", "name": "Ночные ласточки", "frame": "fr_g_tsubame", "hidden": true,
		"accent": {"name": "Дым", "col": "c8283c", "glow": "e6a0aa", "deep": "1d1b2e", "particles": "dust"},
		"sig": 1,
		"up": {"tb_crimson": {"tile": "s_crimson_moon", "table": "tb_rooftops"}}},
	"miel": {"rank": "A", "name": "Мёд и пар", "frame": "fr_g_miel", "hidden": true,
		"accent": {"name": "Сахар", "col": "e0566f", "glow": "f6e7cf", "deep": "c98a4b", "particles": "sparks"},
		"sig": 16,
		"up": {"me_gala": {"tile": "s_sugar_lace", "table": "tb_honeycomb"}}},
	# deep was the ivory f3efe9 in the stub (palette order main · deep · accent); every other kit's deep is the dark
	# tone of its accent, so Kohaku's is the dark vermilion of her lacquer (her mj tray colour)
	"kohaku": {"rank": "S", "name": "Тысяча врат", "frame": "fr_g_kohaku", "hidden": true,
		"accent": {"name": "Лисий огонь", "col": "d63a2a", "glow": "e2a23d", "deep": "8a1f17", "particles": "embers"},
		"tile": "s_foxfire", "table": "tb_torii", "sig": 31},
	"shirin": {"rank": "S", "name": "Семь колодцев", "frame": "fr_g_shirin", "hidden": true,
		"accent": {"name": "Песок", "col": "d9b26f", "glow": "f6e3b8", "deep": "1f8f8a", "particles": "dust"},
		"tile": "s_monisto", "table": "tb_caravan", "sig": 9},
	# identical to the look lane's full SSR kit (kept here so the five live in one place; install() merges, no change)
	"zlata": {"rank": "SSR", "name": "Лаковая сказка", "frame": "fr_g_zlata", "hidden": true,
		"accent": {"name": "Жар-перо", "col": "ff7a2a", "glow": "ffd08a", "deep": "8e1a14", "particles": "feathers"},
		"tile": "s_lacquer", "table": "tb_lacquer_box", "hud": "zlata", "sting": "zlata", "font": "zlata", "sig": 12,
		"palettes": {"zl_base": "firebird", "zl_fair": "firebird", "zl_ember": "ember", "zl_vow": "dawn"}},
}

# outfit -> [hero, rank, name] (V10KitData.EXTRA_OUTFITS schema; rank letters, ROSTER §1.1: A↔R, S↔SR, SSR↔SSR)
const EXTRA_OUTFITS: = {
	"tb_base": ["tsubame", "A", "Ночная ласточка"], "tb_post": ["tsubame", "S", "Почта сквозь миры"],
	"tb_crimson": ["tsubame", "SSR", "Алая луна клана"],
	"me_base": ["miel", "A", "Утренняя выпечка"], "me_parlor": ["miel", "S", "Салон «Мёд»"],
	"me_gala": ["miel", "SSR", "Сахарный бал"],
	"ko_base": ["kohaku", "S", "Жрица тысячи врат"], "ko_matsuri": ["kohaku", "A", "Ночной мацури"],
	"ko_kyubi": ["kohaku", "SSR", "Девятихвостая"], "ko_vow": ["kohaku", "SSR", "Обет лисьей свадьбы"],
	"sh_base": ["shirin", "S", "Танец семи колодцев"], "sh_oasis": ["shirin", "A", "Оазис"],
	"sh_sun": ["shirin", "SSR", "Дочь полуденного солнца"], "sh_night": ["shirin", "SSR", "Тысяча и одна партия"],
	"zl_base": ["zlata", "SSR", "Жар-птица"], "zl_fair": ["zlata", "S", "Масленичная ярмарка"],
	"zl_ember": ["zlata", "SSR", "Царица-пламя"], "zl_vow": ["zlata", "SSR", "Обет Жар-птицы"],
}
const BASE_OUTFIT: = {"tsubame": "tb_base", "miel": "me_base", "kohaku": "ko_base", "shirin": "sh_base", "zlata": "zl_base"}

# ------------------------------------------------------------------------------------------------- D3 themes + tables

const THEMES: = {
	# «Алая луна» — Цубамэ in tb_crimson (SSR outfit lifts her A kit to S): indigo night lacquer, crimson feathers
	# drifting over the band, a crimson kromka and a silver face rim; the flip back is deep crimson
	"s_crimson_moon": {"emblem": EMBLEMS + "crimson_moon.png", "name": "Алая луна", "owner": "tsubame", "tier": "S",
		"side": Color("2a2440"), "rim": Color("d9dce6"), "tint": Color(0.98, 0.98, 1.02),
		"back2": Color("0e0c18"), "line": Color("c8283c"), "pattern": V10TileTheme.P_PETALS, "pat_alpha": 0.8, "edge": 0.75,
		"face_rim": Color("a9b0c2"), "accent": Color("c8283c"), "particles": "dust", "sig": 1, "table": "tb_rooftops",
		"back": Color("8e1c2c")},
	# «Сахарное кружево» — Миэль in me_gala (lifted to S): raspberry glaze with a piped sugar garland, honey face rim
	"s_sugar_lace": {"emblem": EMBLEMS + "sugar_lace.png", "name": "Сахарное кружево", "owner": "miel", "tier": "S",
		"side": Color("d84a66"), "rim": Color("f6e7cf"), "tint": Color(1.02, 1.0, 0.97),
		"back2": Color("7a1f36"), "line": Color("f6e7cf"), "pattern": V10TileTheme.P_VINE, "pat_alpha": 0.9, "edge": 0.7,
		"face_rim": Color("e9c48a"), "accent": Color("e0566f"), "particles": "sparks", "sig": 16, "table": "tb_honeycomb"},
	# «Лисьи огни» — Кохаку (S): vermilion torii lacquer, amber fox-fire sparks twinkling on the band, white-fur inner side
	"s_foxfire": {"emblem": EMBLEMS + "foxfire.png", "name": "Лисьи огни", "owner": "kohaku", "tier": "S",
		"side": Color("d63a2a"), "rim": Color("f3efe9"), "tint": Color(1.02, 1.0, 0.97),
		"back2": Color("6a120b"), "line": Color("f0b84f"), "pattern": V10TileTheme.P_STARS, "pat_alpha": 0.95, "edge": 0.85,
		"face_rim": Color("e2a23d"), "accent": Color("d63a2a"), "particles": "embers", "sig": 31, "table": "tb_torii"},
	# «Монисто» — Ширин (S): oasis-teal lacquer strewn with gold coins, sand-gold kromka, warm noon tint
	"s_monisto": {"emblem": EMBLEMS + "monisto.png", "name": "Монисто", "owner": "shirin", "tier": "S",
		"side": Color("1f8f8a"), "rim": Color("f3e3bd"), "tint": Color(1.03, 1.0, 0.94),
		"back2": Color("0a3a38"), "line": Color("e0b85a"), "pattern": V10TileTheme.P_FLAKES, "pat_alpha": 0.95, "edge": 0.85,
		"face_rim": Color("d9b26f"), "accent": Color("d9b26f"), "particles": "dust", "sig": 9, "table": "tb_caravan"},
}

# V6BoardTable schema (+ v10 patterns): 0 seigaiha, 1 asanoha, 2 shippo, 3 uroko, 4 kikko, 7 frost, 8 lanes, 9 stars,
# 10 circuit, 11 petals
const TABLES: = {
	# roof tiles under the moon: night slate, silver seigaiha, crimson lacquer line, moonlight lamp
	"tb_rooftops": {"name": "Крыши под луной", "owner": "tsubame", "frame_a": Color("2a2840"), "frame_b": Color("0d0c16"), "trim": Color("c8283c"),
		"mat_a": Color("2a3050"), "mat_b": Color("0b0d1a"), "pat_col": Color("a9b0c2"), "pat_alpha": 0.12, "pattern": 0, "pat_scale": 42.0,
		"fibre": 0.25, "lamp_col": Color("c9cfe0"), "lamp_k": 0.32, "gloss": 1.2, "shadow": Color(0.02, 0.02, 0.06, 0.8), "ambient": Color("9a3045")},
	# a confectioner's counter: caramel wood, chocolate mat with honeycomb (kikko) in honey, warm oven lamp
	"tb_honeycomb": {"name": "Медовые соты", "owner": "miel", "frame_a": Color("9a6438"), "frame_b": Color("3a2210"), "trim": Color("f0cf8a"),
		"mat_a": Color("5a3424"), "mat_b": Color("1e0f08"), "pat_col": Color("e9c48a"), "pat_alpha": 0.13, "pattern": 4, "pat_scale": 38.0,
		"fibre": 0.3, "lamp_col": Color("ffe6c8"), "lamp_k": 0.36, "gloss": 1.1, "shadow": Color(0.08, 0.03, 0.02, 0.78), "ambient": Color("e0566f")},
	# the shrine of a thousand gates: vermilion torii frame, dark lacquer mat with amber asanoha, lantern light
	"tb_torii": {"name": "Тысяча врат", "owner": "kohaku", "frame_a": Color("c23a26"), "frame_b": Color("4a0c07"), "trim": Color("e2a23d"),
		"mat_a": Color("4a1a14"), "mat_b": Color("140504"), "pat_col": Color("e2a23d"), "pat_alpha": 0.11, "pattern": 1, "pat_scale": 50.0,
		"fibre": 0.35, "lamp_col": Color("ffd2a0"), "lamp_k": 0.36, "gloss": 1.15, "shadow": Color(0.08, 0.02, 0.01, 0.8), "ambient": Color("e2a23d")},
	# a caravan tent: brass frame, umber carpet with sand-gold shippo rings, desert noon lamp
	"tb_caravan": {"name": "Шатёр каравана", "owner": "shirin", "frame_a": Color("8a6a32"), "frame_b": Color("2e1f08"), "trim": Color("f0cf7a"),
		"mat_a": Color("4a3a26"), "mat_b": Color("17110a"), "pat_col": Color("d9b26f"), "pat_alpha": 0.14, "pattern": 2, "pat_scale": 44.0,
		"fibre": 0.4, "lamp_col": Color("ffe2a8"), "lamp_k": 0.4, "gloss": 1.0, "shadow": Color(0.06, 0.04, 0.02, 0.78), "ambient": Color("d9b26f")},
}

# ------------------------------------------------------------------------------------------------- D5 frames (V10ProfileCos)

# look: base ring (A/S kits, as the founders) | wing (SSR); metal / petal recolour the painted gold and sakura pink
# (frame_fx.gdshader), deco = V10FrameView code-drawn layer, glow = halo. fr_g_zlata «Жар-птица» is registered by
# V10ProfileCos itself (hidden until released) and is listed here only for the selfcheck.
const FRAMES: = {
	# silver ring, crimson inlay, a crimson crescent with sparkles — the courier's night
	"fr_g_tsubame": {"id": "fr_g_tsubame", "kind": "frame", "name": "Ночные ласточки", "tier": "A",
		"src": {"type": "goddess", "hero": "tsubame"}, "hero": "tsubame", "sim_ok": true,
		"look": {"base": "ring", "metal": "a9b0c2", "petal": "c8283c", "deco": "moon", "deco_col": "c8283c", "glow": "c8283c"}},
	# honey-gold ring with cream inlay and a garland of sugar pearls
	"fr_g_miel": {"id": "fr_g_miel", "kind": "frame", "name": "Мёд и пар", "tier": "A",
		"src": {"type": "goddess", "hero": "miel"}, "hero": "miel", "sim_ok": true,
		"look": {"base": "ring", "metal": "e9c48a", "petal": "f6e7cf", "deco": "pearls", "deco_col": "f6e7cf", "glow": "e0566f"}},
	# white-fur silver ring, vermilion inlay, fox fire rising behind it
	"fr_g_kohaku": {"id": "fr_g_kohaku", "kind": "frame", "name": "Тысяча врат", "tier": "S",
		"src": {"type": "goddess", "hero": "kohaku"}, "hero": "kohaku", "sim_ok": true,
		"look": {"base": "ring", "metal": "f3efe9", "petal": "d63a2a", "deco": "flames", "deco_col": "e2a23d", "glow": "e2a23d"}},
	# sand-gold ring with oasis-teal inlay under a crown of noon rays
	"fr_g_shirin": {"id": "fr_g_shirin", "kind": "frame", "name": "Семь колодцев", "tier": "S",
		"src": {"type": "goddess", "hero": "shirin"}, "hero": "shirin", "sim_ok": true,
		"look": {"base": "ring", "metal": "d9b26f", "petal": "1f8f8a", "deco": "sun", "deco_col": "c08a1e", "glow": "1f8f8a"}},
}
const FRAME_REGISTERED: = ["fr_g_zlata"]

# ------------------------------------------------------------------------------------------------- D2 fonts, D7 HUD, stings

# Display fonts belong to SSR goddesses only (Kohaku and Shirin are S: no font). Злата — Ruslan Display + Kurale (D2).
const FONTS: = {"zlata": {"title": "zlata_title", "text": "zlata_text", "families": ["Ruslan Display", "Kurale"]}}
const HUD: = {"zlata": {"skin": "zlata", "palettes": ["firebird", "ember", "dawn"]}}
const STINGS: = ["zlata"]

# ------------------------------------------------------------------------------------------------- hud2 accents + showcase

# V10DS.HEROES schema: name, accent / glow / deep (≤ 10 % of pixels), showcase element (petal leaf spark dust glitch)
const HUD_HEROES: = {
	# ink-dark wisps fading from rose — a flight of shadow swallows
	"tsubame": {"name": "Цубамэ", "accent": Color("#C8283C"), "glow": Color("#E6A0AA"), "deep": Color("#1D1B2E"), "element": "leaf"},
	# a burst of sugar sprinkles
	"miel": {"name": "Миэль", "accent": Color("#E0566F"), "glow": Color("#F6E7CF"), "deep": Color("#C98A4B"), "element": "spark"},
	# fox-fire orbs: amber core, vermilion halo
	"kohaku": {"name": "Кохаку", "accent": Color("#D63A2A"), "glow": Color("#E2A23D"), "deep": Color("#8A1F17"), "element": "dust"},
	# coin glints climbing like a scale of chimes
	"shirin": {"name": "Ширин", "accent": Color("#D9B26F"), "glow": Color("#F6E3B8"), "deep": Color("#1F8F8A"), "element": "spark"},
	# fire feathers, gold to flame
	"zlata": {"name": "Злата", "accent": Color("#FF7A2A"), "glow": Color("#FFD08A"), "deep": Color("#8E1A14"), "element": "petal"},
}
const SHOWCASE_ELEMENTS: = ["petal", "leaf", "spark", "dust", "glitch"]
# V10ComboShowcase.LINES schema: tier 2 (×10) and tier 3 (×20 / Азарт), short, in her voice (cards ROSTER §3)
const COMBO_LINES: = {
	"tsubame": {2: "Чисто сработано.", 3: "Доставлено."},
	"miel": {2: "Ещё щепотку сахара!", 3: "Попробуй! Это шедевр."},
	"kohaku": {2: "Огоньков всё больше~", 3: "Удача любит меня."},
	"shirin": {2: "Монеты звенят к удаче.", 3: "Звёзды не лгут."},
	"zlata": {2: "Перья множатся!", 3: "Весна пришла!"},
}

static var _installed: = false
static var _rig: = {}
static var _rig_loaded: = false


# ================================================================================================= install

# Overlays the five onto the look consumers. Needs the static-var hooks (README of the wave: kit_data.gd, tile_themes.gd,
# hud2/tokens.gd, hud2/combo_showcase.gd); a consumer still on `const` is reported and left untouched.
# Base entries win where they already exist (s_lacquer, tb_lacquer_box, zl_* outfits, fr_g_zlata).
static func install() -> Array:
	var errs: = []
	var kits: Dictionary = V10KitData.KITS
	if kits.is_read_only():
		errs.append("V10KitData.KITS is const: apply the kit_data.gd hook")
	else:
		for h in ORDER:
			var k: Dictionary = (kits.get(h, {}) as Dictionary).duplicate(true)
			k.merge(KITS[h].duplicate(true), true)
			kits[h] = k
	var ex: Dictionary = V10KitData.EXTRA_OUTFITS
	if ex.is_read_only():
		errs.append("V10KitData.EXTRA_OUTFITS is const: apply the kit_data.gd hook")
	else:
		for o in EXTRA_OUTFITS:
			if not ex.has(o):
				ex[o] = (EXTRA_OUTFITS[o] as Array).duplicate()
	errs.append_array(_merge_into(V10TileTheme.THEMES, THEMES, "V10TileTheme.THEMES", "tile_themes.gd"))
	errs.append_array(_merge_into(V10TileTheme.TABLES, TABLES, "V10TileTheme.TABLES", "tile_themes.gd"))
	errs.append_array(_merge_into(V10DS.HEROES, HUD_HEROES, "V10DS.HEROES", "hud2/tokens.gd"))
	errs.append_array(_merge_into(V10ComboShowcase.LINES, COMBO_LINES, "V10ComboShowcase.LINES", "hud2/combo_showcase.gd"))
	for id in FRAMES:
		if not V10ProfileCos.has(id, "frame"):
			var err: = V10ProfileCos.register(FRAMES[id])
			if err != "":
				errs.append(err)
	V10LookCos.reset()
	_installed = errs.is_empty()
	return errs


static func installed() -> bool:
	return _installed


static func _merge_into(target: Dictionary, src: Dictionary, what: String, file: String) -> Array:
	if target.is_read_only():
		return ["%s is const: apply the %s hook" % [what, file]]
	for id in src:
		if not target.has(id):
			var v = src[id]
			target[id] = v.duplicate(true) if v is Dictionary else v
	return []


# ================================================================================================= helpers

static func kit(hero: String) -> Dictionary:
	return KITS.get(hero, {})


static func outfits(hero: String) -> Array:
	var out: = []
	for o in EXTRA_OUTFITS:
		if String(EXTRA_OUTFITS[o][0]) == hero:
			out.append(o)
	return out


# the tile theme and table a hero shows in `outfit` (S/SSR kit, or an A kit lifted by its SSR outfit); [] for A
static func theme_of(hero: String, outfit: = "") -> Array:
	var k: = kit(hero)
	var up: Dictionary = k.get("up", {}).get(outfit, {})
	if not up.is_empty():
		return [String(up.tile), String(up.table)]
	if k.has("tile"):
		return [String(k.tile), String(k.table)]
	return []


static func rig_data() -> Dictionary:
	if not _rig_loaded:
		_rig_loaded = true
		if FileAccess.file_exists(ART_RIG):
			var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(ART_RIG))
			if d is Dictionary:
				_rig = d
	return _rig


# Showcase fallback (HUD_V2 §7.5 «never an empty show»): the wave-1 full-body cut-out for every tier and outfit until
# her own combo poses are painted. "" when the art is not there yet.
static func combo_sprite(hero: String, _outfit: = "", _tier: = 1) -> String:
	if not KITS.has(hero):
		return ""
	var p: = HERO_DIR + hero + ".png"
	var f: = String(rig_data().get(hero, {}).get("file", ""))
	if f.begins_with("res://"):
		p = f
	return p if ResourceLoader.exists(p) else ""


# combo_meta.json entry for a wave-1 sprite: face = [x, y, w, h] in sprite px from the rig (head circle), framing full
static func combo_meta(path: String) -> Dictionary:
	var hero: = path.get_file().get_basename()
	if not KITS.has(hero):
		return {}
	var r: Dictionary = rig_data().get(hero, {}).get("rig", {})
	var hc = r.get("head_c", null)
	if not (hc is Array) or (hc as Array).size() < 2:
		return {}
	var rr: = float(r.get("head_r", 100.0))
	return {"file": path.get_file(), "hero": hero, "tier": 0, "pose": "cut-out", "framing": "full", "enter": "right",
		"face": [float(hc[0]) - rr, float(hc[1]) - rr, rr * 2.0, rr * 2.0]}


# every player-visible string of this file (stop-word and language checks)
static func texts() -> Array:
	var out: = []
	for h in KITS:
		out.append(String(KITS[h].name))
		out.append(String(KITS[h].accent.name))
	for o in EXTRA_OUTFITS:
		out.append(String(EXTRA_OUTFITS[o][2]))
	for id in THEMES:
		out.append(String(THEMES[id].name))
	for id in TABLES:
		out.append(String(TABLES[id].name))
	for id in FRAMES:
		out.append(String(FRAMES[id].name))
	for h in COMBO_LINES:
		for t in COMBO_LINES[h]:
			out.append(String(COMBO_LINES[h][t]))
	return out


# ================================================================================================= selfcheck

const THEME_KEYS: = ["side", "rim", "tint", "back2", "line", "pattern", "accent", "particles", "sig", "name", "owner", "tier"]
const TABLE_KEYS: = ["frame_a", "frame_b", "trim", "mat_a", "mat_b", "pat_col", "pat_alpha", "pattern", "pat_scale", "fibre",
	"lamp_col", "lamp_k", "gloss", "shadow", "ambient", "name", "owner"]


static func face_contrast(theme_id: String) -> float:
	var th: Dictionary = THEMES.get(theme_id, V10TileTheme.theme(theme_id))
	return V10HudSkin.contrast(V10TileTheme.IVORY * Color(th.tint), TILE_INK)


# Pure data checks; with `installed` also the overlaid consumers (resolve table, registry, catalogue).
static func selfcheck(installed_too: = false) -> Array:
	var errs: = []
	# kits
	if KITS.size() != 5 or ORDER.size() != 5:
		errs.append("five kits")
	for h in ORDER:
		var k: Dictionary = KITS.get(h, {})
		var rk: = String(k.get("rank", ""))
		if rk != String(RANK[h]) or not V10ProfileCos.ROSTER.has(h) or String(V10ProfileCos.ROSTER[h][2]) != rk:
			errs.append("kit %s rank %s vs ROSTER" % [h, rk])
		if int(k.get("sig", -1)) != int(SIG[h]):
			errs.append("kit %s signature face" % h)
		if String(k.get("frame", "")) != "fr_g_" + h:
			errs.append("kit %s frame id" % h)
		if not bool(k.get("hidden", false)):
			errs.append("kit %s stays hidden until released" % h)
		var a: Dictionary = k.get("accent", {})
		if not (String(a.get("particles", "")) in V10KitData.PARTICLES):
			errs.append("kit %s accent particles" % h)
		for ck in ["col", "glow", "deep"]:
			if not Color.html_is_valid(String(a.get(ck, ""))):
				errs.append("kit %s accent %s" % [h, ck])
		if rk == "A" and (k.has("tile") or k.has("table") or k.has("hud")):
			errs.append("A kit %s carries only frame + accent" % h)
		if rk != "A":
			if not (THEMES.has(String(k.get("tile", ""))) or V10TileTheme.has(String(k.get("tile", "")))):
				errs.append("kit %s tile theme" % h)
			if not (TABLES.has(String(k.get("table", ""))) or V10TileTheme.has_table(String(k.get("table", "")))):
				errs.append("kit %s table" % h)
		if rk == "SSR":
			if not V10HudSkinData.SKINS.has(String(k.get("hud", ""))):
				errs.append("kit %s HUD skin" % h)
			if not V10KitData.STINGS.has(String(k.get("sting", ""))):
				errs.append("kit %s sting" % h)
			if not V10Fonts.SKIN_FONTS.has(String(k.get("font", ""))):
				errs.append("kit %s font" % h)
			var pals: Dictionary = V10HudSkinData.SKINS.get(String(k.get("hud", "")), {}).get("palettes", {})
			for o in outfits(h):
				if not pals.has(String(k.get("palettes", {}).get(o, ""))):
					errs.append("kit %s: outfit %s has no HUD palette" % [h, o])
		elif k.has("hud") or k.has("font") or k.has("sting"):
			errs.append("kit %s below SSR carries HUD/sting/font" % h)
		for o in k.get("up", {}):
			var ex: Array = EXTRA_OUTFITS.get(o, [])
			if rk != "A" or ex.is_empty() or String(ex[0]) != h or String(ex[1]) != "SSR":
				errs.append("kit %s: up %s must be an SSR outfit of an A goddess" % [h, o])
			var u: Dictionary = k.up[o]
			if not THEMES.has(String(u.get("tile", ""))) or not TABLES.has(String(u.get("table", ""))):
				errs.append("kit %s: up %s theme/table" % [h, o])
	for h in ["tsubame", "miel"]:
		var ssr: = outfits(h).filter(func(o): return String(EXTRA_OUTFITS[o][1]) == "SSR")
		for o in ssr:
			if not KITS[h].get("up", {}).has(o):
				errs.append("A goddess %s: SSR outfit %s lifts the kit (no up entry)" % [h, o])
	# outfits
	if EXTRA_OUTFITS.size() != 18:
		errs.append("18 outfits (%d)" % EXTRA_OUTFITS.size())
	for o in EXTRA_OUTFITS:
		var e: Array = EXTRA_OUTFITS[o]
		if not (String(e[0]) in ORDER) or not (String(e[1]) in V10KitData.RANKS) or String(e[2]) == "":
			errs.append("outfit %s entry" % o)
	for h in ORDER:
		if String(EXTRA_OUTFITS.get(BASE_OUTFIT[h], ["", ""])[1]) != String(RANK[h]):
			errs.append("base outfit of %s has the goddess's rank" % h)
	if V10KitData.EXTRA_OUTFITS.has("zl_fair"):
		for o in ["zl_base", "zl_fair", "zl_ember", "zl_vow"]:
			if (V10KitData.EXTRA_OUTFITS[o] as Array).slice(0, 3) != (EXTRA_OUTFITS[o] as Array):
				errs.append("outfit %s differs from kit_data" % o)
	# themes
	for id in THEMES:
		var th: Dictionary = THEMES[id]
		for key in THEME_KEYS:
			if not th.has(key):
				errs.append("theme %s has no %s" % [id, key])
		if not (String(th.get("owner", "")) in ORDER) or not (String(th.get("tier", "")) in V10KitData.RANKS):
			errs.append("theme %s owner/tier" % id)
		if int(th.get("sig", -1)) != int(SIG.get(String(th.get("owner", "")), -2)):
			errs.append("theme %s signature = owner's face" % id)
		if not (String(th.get("particles", "")) in V10KitData.PARTICLES):
			errs.append("theme %s particles" % id)
		var cr: = face_contrast(id)
		if cr < 4.5:
			errs.append("theme %s face contrast %.2f < 4.5" % [id, cr])
		if not TABLES.has(String(th.get("table", ""))):
			errs.append("theme %s table" % id)
		if th.has("emblem") and not ResourceLoader.exists(String(th.emblem)):
			errs.append("theme %s emblem art" % id)
		if bool(th.get("legacy", false)):
			errs.append("theme %s is new (not legacy)" % id)
		if not installed_too and V10TileTheme.has(id):
			errs.append("theme id %s already taken in V10TileTheme" % id)
	for id in TABLES:
		for key in TABLE_KEYS:
			if not TABLES[id].has(key):
				errs.append("table %s has no %s" % [id, key])
		if not installed_too and V10TileTheme.has_table(id):
			errs.append("table id %s already taken in V10TileTheme" % id)
	for id in ["s_lacquer"]:
		if not V10TileTheme.has(id) or not V10TileTheme.has_table(String(V10TileTheme.theme(id).get("table", ""))):
			errs.append("zlata theme %s / its table" % id)
	# frames: V10ProfileCos schema
	for id in FRAMES:
		var fe: Dictionary = FRAMES[id]
		var e2: Dictionary = fe.duplicate(true)
		e2.merge({"price": 0}, false)
		var bad: = V10ProfileCos.check_entry(e2)
		if bad != "":
			errs.append(bad)
		var h: = String(fe.get("hero", ""))
		if String(fe.tier) != String(RANK.get(h, "")) or String(fe.name) != String(KITS[h].name):
			errs.append("frame %s tier / name follow the kit" % id)
		if bool(fe.sim_ok) != (String(fe.tier) != "SSR"):
			errs.append("frame %s sim_ok" % id)
	for id in FRAME_REGISTERED:
		if not V10ProfileCos.has(id, "frame"):
			errs.append("frame %s registered by V10ProfileCos" % id)
	# fonts / HUD / stings of Zlata
	for h in FONTS:
		var sf: Dictionary = V10Fonts.SKIN_FONTS.get(h, {})
		if String(sf.get("title", "")) != String(FONTS[h].title) or String(sf.get("text", "")) != String(FONTS[h].text):
			errs.append("font %s roles" % h)
		elif String(V10Fonts.FAMILIES[sf.title].name) != String(FONTS[h].families[0]) \
				or String(V10Fonts.FAMILIES[sf.text].name) != String(FONTS[h].families[1]):
			errs.append("font %s families (D2: Ruslan Display + Kurale)" % h)
	# hud2 accents + showcase
	for h in ORDER:
		var hh: Dictionary = HUD_HEROES.get(h, {})
		if not (String(hh.get("element", "")) in SHOWCASE_ELEMENTS):
			errs.append("hud2 %s showcase element" % h)
		if Color(hh.get("accent", Color.BLACK)) != Color(String(KITS[h].accent.col)):
			errs.append("hud2 %s accent = kit accent" % h)
		var ln: Dictionary = COMBO_LINES.get(h, {})
		for t in [2, 3]:
			if String(ln.get(t, "")) == "" or String(ln.get(t, "")).length() > 28:
				errs.append("combo line %s tier %d" % [h, t])
	# texts: stop-words, no latin
	for bad in V10Lint.scan(texts()):
		errs.append("stop-word in «%s»: %s" % [bad.text, str(bad.bad)])
	var latin: = RegEx.create_from_string("[A-Za-z]")
	for t in texts():
		if latin.search(String(t)) != null:
			errs.append("latin letters in «%s»" % t)
	if installed_too:
		errs.append_array(_check_installed())
	return errs


static func _check_installed() -> Array:
	var errs: = []
	for h in ORDER:
		if String(V10KitData.kit(h).get("frame", "")) != "fr_g_" + h:
			errs.append("installed kit %s" % h)
		if not V10ProfileCos.has("fr_g_" + h, "frame"):
			errs.append("frame fr_g_%s in V10ProfileCos" % h)
		if V10DS.hero(h).get("name", "") != HUD_HEROES[h].name:
			errs.append("V10DS.hero(%s)" % h)
		if not V10ComboShowcase.LINES.has(h):
			errs.append("V10ComboShowcase.LINES.%s" % h)
	for id in THEMES:
		if not V10TileTheme.has(id) or not V10TileTheme.has_table(String(THEMES[id].table)):
			errs.append("installed theme %s / table" % id)
		var rl: = V10TileTheme.look(id, {"ranked": true})
		if rl.tint != Color.WHITE or rl.has("face_rim") or String(rl.v10) != id:
			errs.append("theme %s ranked: standard faces" % id)
	# resolve table (ROSTER §1.3)
	var cases: = [
		["tsubame", "tb_base", "A", "s_sakura", ""], ["tsubame", "tb_post", "A", "s_sakura", ""],
		["tsubame", "tb_crimson", "S", "s_crimson_moon", "tb_rooftops"],
		["miel", "me_base", "A", "s_sakura", ""], ["miel", "me_gala", "S", "s_sugar_lace", "tb_honeycomb"],
		["kohaku", "ko_base", "S", "s_foxfire", "tb_torii"], ["kohaku", "ko_kyubi", "S", "s_foxfire", "tb_torii"],
		["kohaku", "ko_matsuri", "S", "s_foxfire", "tb_torii"],
		["shirin", "sh_base", "S", "s_monisto", "tb_caravan"], ["shirin", "sh_sun", "S", "s_monisto", "tb_caravan"],
		["zlata", "zl_base", "SSR", "s_lacquer", "tb_lacquer_box"], ["zlata", "zl_fair", "SSR", "s_lacquer", "tb_lacquer_box"],
	]
	for c in cases:
		var r: = V10Look.resolve(String(c[0]), String(c[1]))
		if String(r.rank) != String(c[2]) or String(r.tile) != String(c[3]) or String(r.table) != String(c[4]):
			errs.append("resolve %s/%s -> %s %s %s (want %s %s %s)" % [c[0], c[1], r.rank, r.tile, r.table, c[2], c[3], c[4]])
		if String(r.frame) != "fr_g_" + String(c[0]):
			errs.append("resolve %s frame" % c[0])
		var ssr: bool = String(c[2]) == "SSR"
		if bool(r.open.hud) != ssr or (String(r.hud) == "zlata") != ssr:
			errs.append("resolve %s/%s HUD only for SSR" % [c[0], c[1]])
	var pal: = {"zl_base": "firebird", "zl_fair": "firebird", "zl_ember": "ember", "zl_vow": "dawn"}
	for o in pal:
		if String(V10Look.resolve("zlata", o).palette) != String(pal[o]):
			errs.append("zlata/%s HUD palette" % o)
	if String(V10Look.resolve("zlata", "zl_base").font) != "zlata":
		errs.append("zlata font")
	for h in ["kohaku", "shirin", "tsubame", "miel"]:
		if String(V10Look.resolve(h, "").font) != "" or String(V10Look.resolve(h, "").sting) != "":
			errs.append("%s carries no font / sting" % h)
	if V10LookCos.kit_line("kohaku") != "Набор: рамка · акцент · тема фишек · стол":
		errs.append("kit line for S: %s" % V10LookCos.kit_line("kohaku"))
	if V10LookCos.kit_line("tsubame", "tb_crimson") != "Набор: рамка · акцент · тема фишек · стол":
		errs.append("kit line for a lifted A kit")
	for e in V10LookCos.validate_all():
		errs.append("V10LookCos: %s" % e)
	return errs
