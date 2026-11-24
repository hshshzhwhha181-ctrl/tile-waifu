class_name V10TileTheme
extends RefCounted

# V10TileTheme — tile themes («рубашка», кромка, фишка-подпись, частицы пар) and tables (docs/0.10-spec.md D3).
#
#   V10TileTheme.look(id, ctx = {}) -> Dictionary     drop-in for G.skin_look(): the dict Tile.build() reads
#        (side / rim / tint / neon / back, legacy keys unchanged) + v10 keys (v10, accent, particles, sig, face_rim, ranked)
#        ctx: {ranked: bool, big_symbols: bool}. Ranked / «Крупные символы» -> standard faces (no tint, no kromka).
#   V10TileTheme.dress(tile)                          after V6TileLook.dress: the theme's SHARED body material,
#                                                     kromka sprite, signature glow. No-op for dicts without "v10".
#   V10TileTheme.body_mat(id, ranked) -> ShaderMaterial   one per theme (cached) — batching on gl_compatibility
#   V10TileTheme.relight()                            re-apply V6TileLook's lamp to every cached body material
#   V10TileTheme.table(id) -> Dictionary              V6BoardTable theme dict (+ pattern 7–11, tex)
#   V10TileTheme.apply_table(v6_table, id, opts)      re-dress a V6BoardTable with a v10 table ({static: bool})
#   V10TileTheme.thumb(id, size) -> Control           miniature «рубашка» for pickers, cards, league rows
#
# Legacy ids s_sakura … s_gold keep their 0.9 side/rim/tint values (owners lose nothing, ROSTER §1.3);
# their body gains only the v10 kromka/pattern when dressed through V10.

const BODY_SHADER: = preload("res://scripts/v10/look/tile_body_v10.gdshader")
const TABLE_SHADER: = preload("res://scripts/v10/look/table_v10.gdshader")
const BODY_TEX: = "res://assets/v06/board/tile_body.png"
const IVORY: = Color("f4ecdc")
const STANDARD_RIM: = Color("f6dfe6")

# pattern ids of tile_body_v10.gdshader
const P_PLAIN: = 0
const P_FLAKES: = 1
const P_FROST: = 2
const P_FINISH: = 3
const P_STARS: = 4
const P_CIRCUIT: = 5
const P_PETALS: = 6
const P_VINE: = 7

const THEMES: = {
	# ---- legacy 0.9 (same ids, same side/rim/tint) ----
	"s_sakura": {"emblem": "res://assets/v10/look/emblems/sakura.png", "name": "Сакура", "owner": "mc", "tier": "A", "legacy": true,
		"side": Color("e8789f"), "rim": Color("f6dfe6"), "tint": Color(1, 1, 1),
		"back2": Color("a84a6e"), "line": Color("ffe3ec"), "pattern": P_PETALS, "pat_alpha": 0.32, "edge": 0.0,
		"accent": Color("ff8fb8"), "particles": "petals", "sig": 0},
	"s_mint": {"name": "Мята", "owner": "rin", "tier": "A", "legacy": true,
		"side": Color("3f9c7c"), "rim": Color("e6d3b3"), "tint": Color(1, 1, 1),
		"back2": Color("1f5a46"), "line": Color("d7f3e6"), "pattern": P_PLAIN, "pat_alpha": 0.0, "edge": 0.0,
		"accent": Color("7fcfb0"), "particles": "leaves", "sig": 21},
	"s_lemon": {"name": "Лимон", "owner": "hana", "tier": "A", "legacy": true,
		"side": Color("e3b53a"), "rim": Color("fff1c9"), "tint": Color(1, 1, 0.97),
		"back2": Color("a87614"), "line": Color("fff6d6"), "pattern": P_PLAIN, "pat_alpha": 0.0, "edge": 0.0,
		"accent": Color("ffb25a"), "particles": "sparks", "sig": 3},
	# «Полночь» — Юэ's S theme, refreshed for 0.10: night lacquer with twinkling star flecks and a silver kromka
	"s_night": {"emblem": "res://assets/v10/look/emblems/moon.png", "name": "Полночь", "owner": "yue", "tier": "S", "legacy": true,
		"side": Color("232a52"), "rim": Color("c9a55a"), "tint": Color(0.97, 0.97, 1.03),
		"back2": Color("0e1230"), "line": Color("e6deff"), "pattern": P_STARS, "pat_alpha": 0.9, "edge": 0.75,
		"face_rim": Color("d9d2f2"), "accent": Color("c9b2f0"), "particles": "dust", "sig": 7, "table": "tb_palace"},
	# «Неон» — Нова's S theme, refreshed: violet lacquer with live circuit traces and a cyan kromka
	"s_neon": {"emblem": "res://assets/v10/look/emblems/neon.png", "name": "Неон", "owner": "nova", "tier": "S", "legacy": true,
		"side": Color("3b2a6e"), "rim": Color("49e3ff"), "tint": Color(1, 1, 1), "neon": true,
		"back2": Color("140c2e"), "line": Color("49e3ff"), "pattern": P_CIRCUIT, "pat_alpha": 0.85, "edge": 0.8,
		"face_rim": Color("6fe6f2"), "accent": Color("6fe6f2"), "particles": "glitch", "sig": 24, "table": "tb_neon"},
	# «Золото дракона» — МТ in o_dragon (SSR outfit lifts her kit to S)
	"s_gold": {"emblem": "res://assets/v10/look/emblems/dragon.png", "name": "Золото дракона", "owner": "mc", "tier": "S", "legacy": true,
		"side": Color("a8741c"), "rim": Color("ffe08a"), "tint": Color(1.04, 1.0, 0.92),
		"back2": Color("5a2e08"), "line": Color("ffe08a"), "pattern": P_FLAKES, "pat_alpha": 0.95, "edge": 0.9,
		"face_rim": Color("ffd56a"), "accent": Color("ffc93c"), "particles": "embers", "sig": 33, "table": "tb_dragon"},
	# ---- new in 0.10 ----
	"s_jade_frost": {"emblem": "res://assets/v10/look/emblems/jade.png", "name": "Нефрит и иней", "owner": "rin", "tier": "S",
		"side": Color("2f8a6c"), "rim": Color("e9f7f2"), "tint": Color(0.98, 1.0, 1.0),
		"back2": Color("123f33"), "line": Color("e6fbff"), "pattern": P_FROST, "pat_alpha": 0.85, "edge": 0.7,
		"face_rim": Color("bfeee2"), "accent": Color("9fe0c8"), "particles": "frost", "sig": 21, "table": "tb_ice_pavilion"},
	"s_finish": {"emblem": "res://assets/v10/look/emblems/finish.png", "name": "Финишная лента", "owner": "hana", "tier": "S",
		"side": Color("ff8a2a"), "rim": Color("fff1d6"), "tint": Color(1, 0.99, 0.96),
		"back2": Color("2b4a7a"), "line": Color("fff6e6"), "pattern": P_FINISH, "pat_alpha": 0.7, "edge": 0.7,
		"face_rim": Color("ffcf8a"), "accent": Color("ffb35c"), "particles": "sparks", "sig": 3, "table": "tb_stadium"},
	# «Лаковая сказка» — Злата (SSR): black lacquer with a gold vine and the firebird feather, gold kromka and face rim
	"s_lacquer": {"name": "Лаковая сказка", "owner": "zlata", "tier": "SSR",
		"side": Color("1b1513"), "rim": Color("e8b23a"), "tint": Color(1.02, 1.0, 0.96),
		"back2": Color("070504"), "line": Color("e8b23a"), "pattern": P_VINE, "pat_alpha": 0.95, "edge": 1.0,
		"face_rim": Color("e8b23a"), "accent": Color("ff7a2a"), "particles": "feathers", "sig": 12,
		"table": "tb_lacquer_box", "emblem": "res://assets/v10/look/zlata/feather_tile.png", "back": Color("8e1a14")},
}

# tables in the V6BoardTable schema; pattern 7–11 and `tex` need table_v10.gdshader (apply_table swaps it in)
const TABLES: = {
	"tb_dragon": {"name": "Драконий сад", "owner": "mc", "frame_a": Color("7a2420"), "frame_b": Color("2a0907"), "trim": Color("f0c560"),
		"mat_a": Color("2a5a4c"), "mat_b": Color("0b1f1a"), "pat_col": Color("e6c46e"), "pat_alpha": 0.11, "pattern": 3, "pat_scale": 40.0,
		"fibre": 0.5, "lamp_col": Color("ffe2b8"), "lamp_k": 0.36, "gloss": 1.1, "shadow": Color(0.05, 0.02, 0.02, 0.78), "ambient": Color("3c7a6c")},
	"tb_ice_pavilion": {"name": "Ледяной павильон", "owner": "rin", "frame_a": Color("e2e8ef"), "frame_b": Color("7c8a9c"), "trim": Color("f4fbff"),
		"mat_a": Color("5fa3a0"), "mat_b": Color("1d4a52"), "pat_col": Color("eafcff"), "pat_alpha": 0.16, "pattern": 7, "pat_scale": 64.0,
		"fibre": 0.2, "lamp_col": Color("eaf8ff"), "lamp_k": 0.4, "gloss": 1.3, "shadow": Color(0.03, 0.08, 0.12, 0.78), "ambient": Color("7cc8d0")},
	"tb_stadium": {"name": "Стадион на закате", "owner": "hana", "frame_a": Color("2b4a7a"), "frame_b": Color("0f1d36"), "trim": Color("ffb35c"),
		"mat_a": Color("c25a3a"), "mat_b": Color("3b2350"), "pat_col": Color("fff1d6"), "pat_alpha": 0.14, "pattern": 8, "pat_scale": 96.0,
		"fibre": 0.35, "lamp_col": Color("ffd6a0"), "lamp_k": 0.42, "gloss": 1.0, "shadow": Color(0.1, 0.03, 0.06, 0.78), "ambient": Color("e0884f")},
	"tb_palace": {"name": "Лунный дворец", "owner": "yue", "frame_a": Color("3b2a55"), "frame_b": Color("120b22"), "trim": Color("e9cf8a"),
		"mat_a": Color("33366f"), "mat_b": Color("0c0e28"), "pat_col": Color("efeaff"), "pat_alpha": 0.5, "pattern": 9, "pat_scale": 58.0,
		"fibre": 0.45, "lamp_col": Color("dfe2ff"), "lamp_k": 0.34, "gloss": 1.1, "shadow": Color(0.03, 0.02, 0.1, 0.78), "ambient": Color("5a5cb0")},
	"tb_neon": {"name": "Неоновый город", "owner": "nova", "frame_a": Color("262a3d"), "frame_b": Color("07080f"), "trim": Color("49e3ff"),
		"mat_a": Color("1c1d36"), "mat_b": Color("06060e"), "pat_col": Color("ff4fd8"), "pat_alpha": 0.16, "pattern": 10, "pat_scale": 44.0,
		"fibre": 0.1, "neon": 1.0, "lamp_col": Color("c8f6ff"), "lamp_k": 0.26, "gloss": 1.35, "shadow": Color(0.0, 0.0, 0.03, 0.82), "ambient": Color("2f8fb0")},
	"tb_lacquer_box": {"name": "Лаковая шкатулка", "owner": "zlata", "frame_a": Color("2a1d18"), "frame_b": Color("070504"), "trim": Color("e8b23a"),
		"mat_a": Color("1b1513"), "mat_b": Color("070504"), "pat_col": Color("e8b23a"), "pat_alpha": 0.0, "pattern": 6, "pat_scale": 50.0,
		"fibre": 0.0, "lamp_col": Color("ffd9a6"), "lamp_k": 0.3, "gloss": 1.25, "shadow": Color(0.08, 0.02, 0.01, 0.8), "ambient": Color("c3242b"),
		"tex": "res://assets/v10/look/zlata/table.webp"},
}

static var _mats: = {}
static var _tex: = {}
static var anim_on: = true   # mirrors fx level (min -> false): set by the integrator / V10Look


static func has(id: String) -> bool:
	return THEMES.has(id)


static func has_table(id: String) -> bool:
	return TABLES.has(id)


static func theme(id: String) -> Dictionary:
	return THEMES.get(id, THEMES.s_sakura)


static func ids(include_legacy: = true) -> Array:
	var out: = []
	for k in THEMES:
		if include_legacy or not THEMES[k].get("legacy", false):
			out.append(k)
	return out


# The dict Tile.build() reads. Legacy keys first so old code (tile_back, V6TileLook) keeps working.
static func look(id: String, ctx: = {}) -> Dictionary:
	var th: = theme(id)
	var std: = bool(ctx.get("ranked", false)) or bool(ctx.get("big_symbols", false))
	var lk: = {
		"side": th.side, "rim": th.rim, "tint": Color.WHITE if std else th.get("tint", Color.WHITE),
		"neon": bool(th.get("neon", false)), "back": th.get("back", th.side),
		"v10": id if THEMES.has(id) else "s_sakura", "ranked": std,
		"accent": th.get("accent", th.rim), "particles": th.get("particles", "petals"), "sig": int(th.get("sig", 0)),
	}
	if not std and th.has("face_rim"):
		lk["face_rim"] = th.face_rim
	return lk


static func _body_tex() -> Texture2D:
	if not _tex.has(BODY_TEX):
		_tex[BODY_TEX] = load(BODY_TEX)
	return _tex[BODY_TEX]


static func tex(path: String) -> Texture2D:
	if path == "" or not ResourceLoader.exists(path):
		return null
	if not _tex.has(path):
		_tex[path] = load(path)
	return _tex[path]


static func body_mat(id: String, ranked: = false) -> ShaderMaterial:
	var key: = "%s|%s|%s" % [id, ranked, anim_on]
	if _mats.has(key) and is_instance_valid(_mats[key]):
		return _mats[key]
	var th: = theme(id)
	var m: = ShaderMaterial.new()
	m.shader = BODY_SHADER
	m.set_shader_parameter("ivory", IVORY.lerp(th.rim, 0.3))
	m.set_shader_parameter("back", th.side)
	m.set_shader_parameter("back2", th.get("back2", th.side.darkened(0.4)))
	m.set_shader_parameter("line", th.get("line", th.rim))
	m.set_shader_parameter("pattern", int(th.get("pattern", 0)))
	m.set_shader_parameter("pat_alpha", float(th.get("pat_alpha", 0.0)))
	# ranked: the back keeps its colour and pattern («тема меняет только рубашку и рамку»), the kromka goes
	m.set_shader_parameter("edge", 0.0 if ranked else float(th.get("edge", 0.0)))
	m.set_shader_parameter("neon", 1.0 if th.get("neon", false) and not ranked else 0.0)
	m.set_shader_parameter("anim", 1.0 if anim_on and not ranked else 0.0)
	_light(m)
	_mats[key] = m
	return m


static func _light(m: ShaderMaterial) -> void:
	m.set_shader_parameter("lamp", V6TileLook.lamp)
	var lc: = V6TileLook.lamp_col
	m.set_shader_parameter("lamp_col", Vector3(lc.r, lc.g, lc.b))
	m.set_shader_parameter("gloss", V6TileLook.gloss)


static func relight() -> void:
	for m in _mats.values():
		if is_instance_valid(m):
			_light(m)


static func mat_count() -> int:
	return _mats.size()


# After V6TileLook.dress(t): swap the body to the theme's shared material, add kromka and signature glow.
static func dress(t: Node2D) -> void:
	var lk = t.get("look")
	if not (lk is Dictionary) or not lk.has("v10"):
		return
	var id: String = lk.v10
	var ranked: = bool(lk.get("ranked", false))
	var side_j = t.get("side_j")
	if side_j is Sprite2D:
		if V6TileLook.enabled:
			side_j.texture = _body_tex()
			side_j.position = Vector2.ZERO
			side_j.scale = Vector2(Tile.S, Tile.S)
			side_j.modulate = Color.WHITE
		side_j.material = body_mat(id, ranked)
	var face = t.get("face_spr")
	if not (face is Sprite2D):
		return
	if t.get_node_or_null("V10Rim"):
		t.get_node("V10Rim").free()
	if lk.has("face_rim") and not ranked:
		# kromka of the face: the tile mask a hair larger, behind the face, in the theme's metal
		var rim: = Sprite2D.new()
		rim.name = "V10Rim"
		rim.texture = G.fx("tile_mask")
		rim.scale = face.scale * Vector2(1.035, 1.03)
		rim.position = face.position + Vector2(0, -0.5)
		rim.modulate = lk.face_rim
		t.add_child(rim)
		t.move_child(rim, face.get_index())
	var sig_on: = not ranked and int(t.get("face")) == int(lk.get("sig", -1))
	var old: Node = t.get_node_or_null("V10Sig")
	if old:
		old.free()
	if sig_on:
		var g: = Sprite2D.new()
		g.name = "V10Sig"
		g.texture = G.fx("tile_glow")
		g.scale = face.scale * 1.06
		g.material = Fx.add_mat()
		var ac: Color = lk.get("accent", Color.WHITE)
		g.modulate = Color(ac.r, ac.g, ac.b, 0.32)
		t.add_child(g)
		t.move_child(g, face.get_index())


static func table(id: String) -> Dictionary:
	return TABLES.get(id, {})


# Re-dress a V6BoardTable (its `mat` keeps working with the v10 shader: same uniform names).
static func apply_table(tb: Node, id: String, opts: = {}) -> bool:
	var th: = table(id)
	if th.is_empty() or tb == null:
		return false
	var mat = tb.get("mat")
	if not (mat is ShaderMaterial):
		return false
	var m: ShaderMaterial = mat
	m.shader = TABLE_SHADER
	set_table_params(m, th, opts)
	V6TileLook.lamp_col = th.lamp_col
	V6TileLook.gloss = th.gloss
	V6TileLook.ambient = th.ambient
	V6TileLook.shadow_col = th.shadow
	var tiles = tb.get_parent().get("tiles") if tb.get_parent() else null
	if tiles is Array:
		V6TileLook.relight(tiles)
	relight()
	tb.set("theme_id", id)
	return true


static func set_table_params(m: ShaderMaterial, th: Dictionary, opts: = {}) -> void:
	for key in ["frame_a", "frame_b", "trim", "mat_a", "mat_b", "pat_col"]:
		m.set_shader_parameter(key, th[key])
	m.set_shader_parameter("pat_alpha", th.pat_alpha)
	m.set_shader_parameter("pattern", th.pattern)
	m.set_shader_parameter("pat_scale", th.pat_scale)
	m.set_shader_parameter("fibre", th.fibre)
	m.set_shader_parameter("neon", th.get("neon", 0.0))
	var lc: Color = th.lamp_col
	m.set_shader_parameter("lamp_col", Vector3(lc.r, lc.g, lc.b))
	m.set_shader_parameter("lamp_k", th.lamp_k)
	var still: = bool(opts.get("static", false)) or not anim_on
	m.set_shader_parameter("anim", 0.0 if still else 1.0)
	var t: = tex(String(th.get("tex", "")))
	m.set_shader_parameter("mat_tex_on", 1.0 if t else 0.0)
	if t:
		m.set_shader_parameter("mat_tex", t)
		m.set_shader_parameter("mat_tex_aspect", float(t.get_width()) / float(t.get_height()))


# Standalone table (pickers, previews): a ColorRect with the v10 table material covering `r` (+ margin).
static func table_rect(id: String, r: Rect2, opts: = {}) -> ColorRect:
	var th: = table(id)
	var margin: = 40.0
	var cr: = ColorRect.new()
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cr.position = r.position - Vector2(margin, margin)
	cr.size = r.size + Vector2(margin, margin) * 2.0
	var m: = ShaderMaterial.new()
	m.shader = TABLE_SHADER
	m.set_shader_parameter("size", cr.size)
	m.set_shader_parameter("margin", margin)
	m.set_shader_parameter("frame_w", float(opts.get("frame_w", 20.0)))
	m.set_shader_parameter("radius", float(opts.get("radius", 26.0)))
	m.set_shader_parameter("noise", load("res://assets/v06/board/table_noise.png"))
	if not th.is_empty():
		set_table_params(m, th, opts)
	cr.material = m
	return cr


static func thumb(id: String, sz: Vector2) -> Control:
	var c: = Thumb.new()
	c.theme_id = id
	c.custom_minimum_size = sz
	c.size = sz
	return c


# miniature «рубашка»: slab, lacquered back in the theme colours, kromka, emblem (or signature dot)
class Thumb extends Control:
	var theme_id: = "s_sakura"
	var ranked: = false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var th: = V10TileTheme.theme(theme_id)
		var r: = Rect2(Vector2.ZERO, size)
		var rad: = int(size.x * 0.16)
		var slab: = StyleBoxFlat.new()
		slab.bg_color = Color(th.get("back2", th.side)).darkened(0.25)
		slab.set_corner_radius_all(rad)
		slab.anti_aliasing = true
		draw_style_box(slab, Rect2(r.position + Vector2(0, size.y * 0.07), r.size - Vector2(0, size.y * 0.07)))
		var face: = StyleBoxFlat.new()
		face.bg_color = th.side
		face.border_color = th.get("line", th.rim) if float(th.get("edge", 0.0)) > 0.0 and not ranked else Color(th.rim, 0.9)
		face.set_border_width_all(maxi(1, int(size.x * 0.055)))
		face.set_corner_radius_all(rad)
		face.anti_aliasing = true
		draw_style_box(face, Rect2(r.position, r.size - Vector2(0, size.y * 0.08)))
		# depth gradient
		var h: = size.y * 0.92
		for i in 6:
			var y0: = h * (0.45 + i * 0.09)
			draw_rect(Rect2(size.x * 0.1, y0, size.x * 0.8, h * 0.09), Color(th.get("back2", th.side), 0.12 * i / 6.0))
		var em: Texture2D = V10TileTheme.tex(String(th.get("emblem", "")))
		var c: = Vector2(size.x * 0.5, size.y * 0.44)
		if em:
			var eh: = size.y * 0.62
			var ew: = eh * em.get_width() / em.get_height()
			draw_texture_rect(em, Rect2(c - Vector2(ew, eh) * 0.5, Vector2(ew, eh)), false)
		else:
			var d: = size.x * 0.2
			var ln: Color = th.get("line", th.rim)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -d), c + Vector2(d * 0.8, 0), c + Vector2(0, d), c + Vector2(-d * 0.8, 0)]), Color(ln, 0.9))
			draw_circle(c, d * 0.3, th.get("accent", Color.WHITE), true, -1.0, true)
		draw_line(Vector2(size.x * 0.22, size.y * 0.1), Vector2(size.x * 0.78, size.y * 0.1), Color(1, 1, 1, 0.3), 1.5, true)
