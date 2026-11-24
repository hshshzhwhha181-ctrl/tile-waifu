class_name V10MjTileMaterial
extends RefCounted

# V10MjTileMaterial — six tile materials for every mahjong mode (docs/MODES.md §3.4, §7.1 «args.look»).
# Nothing here edits tile.gd or V6TileLook: a board either
#   (a) passes look_dict(material, hero) as args.look — it is a V6TileLook-compatible dictionary (side, rim, tint, neon)
#       with an extra "v10mj" block, so old code that only reads side/rim/tint keeps working; or
#   (b) calls V10MjTileMaterial.dress(tile, look) right after Tile.build() to swap the face/body shaders to the
#       material ones (same uniforms as V6TileLook, plus the material set); or
#   (c) uses V10MjTileView (tile_view.gd) — a self-contained tile node for new modes (Classic, Cube, Connect …).
#
# Per-tile state (all three paths):
#   set_state(mat, free, closed, hl_free, accent)  → breathing for free tiles, 18% shade for closed ones,
#                                                    accent outline when «Подсвечивать свободные» is on
#   shadow_for_z(z) -> {offset, scale, alpha}     soft shadow that grows (offset and blur) with the layer
# Settings live in G.S["v10_mj_look"] (st() below): material, hl_free, contrast, asmr, ambient.

const FACE_SHADER: = preload("res://shaders/v10/mj/look/tile_material.gdshader")
const BODY_SHADER: = preload("res://shaders/v10/mj/look/tile_body.gdshader")
const DIR: = "res://assets/v10/mj/look/tile/"
const V6DIR: = "res://assets/v06/board/"

const ORDER: = ["porcelain", "jade", "bone", "ice", "amber", "lacquer"]

# Every material: face plate tint, 3 edge layers (lip · seam · bevel), body back colour, light response, grain,
# subsurface glow, ASMR family. Colours stay light on the plate so symbol contrast never drops (tested).
const MATERIALS: = {
	"porcelain": {"name": "Фарфор", "line": "Звонкий, с кобальтовой спинкой",
		"face": Color("fdfaf5"), "lip": Color("f4efe6"), "seam": Color("d6b26a"), "bevel": Color("ece5d8"),
		"back": Color("2c5f86"), "seam_metal": 0.9, "spec_pow": 70.0, "spec_k": 0.55, "coat": 0.28,
		"sss": 0.06, "sss_col": Color("cfe3ff"), "grain": 1, "grain_amt": 0.06, "ao": 0.24, "alpha": 1.0,
		"tint": Color(1, 1, 1), "sfx": "porcelain"},
	"jade": {"name": "Нефрит", "line": "Прохладный камень с прожилками",
		"face": Color("e3f1df"), "lip": Color("c4e2cb"), "seam": Color("e9d8a6"), "bevel": Color("d9ecdc"),
		"back": Color("23704f"), "seam_metal": 0.8, "spec_pow": 42.0, "spec_k": 0.45, "coat": 0.32,
		"sss": 0.42, "sss_col": Color("7fe0a8"), "grain": 2, "grain_amt": 0.24, "ao": 0.30, "alpha": 1.0,
		"tint": Color(0.99, 1.0, 0.985), "sfx": "jade"},
	"bone": {"name": "Кость", "line": "Старинная кость и бамбук",
		"face": Color("f4e6c8"), "lip": Color("eadcbf"), "seam": Color("4a2f1c"), "bevel": Color("e6d6b6"),
		"back": Color("7a5532"), "seam_metal": 0.1, "spec_pow": 16.0, "spec_k": 0.16, "coat": 0.05,
		"sss": 0.08, "sss_col": Color("ffe2b0"), "grain": 3, "grain_amt": 0.16, "ao": 0.36, "alpha": 1.0,
		"tint": Color(1.0, 0.99, 0.96), "sfx": "bone"},
	"ice": {"name": "Лёд", "line": "Прозрачный, с инеем по краю",
		"face": Color("e7f3ff"), "lip": Color("cde8ff"), "seam": Color("ffffff"), "bevel": Color("e4f3ff"),
		"back": Color("78b4dc"), "seam_metal": 1.0, "spec_pow": 95.0, "spec_k": 0.8, "coat": 0.36,
		"sss": 0.62, "sss_col": Color("9feaff"), "grain": 4, "grain_amt": 0.22, "ao": 0.18, "alpha": 0.86,
		"tint": Color(0.985, 0.995, 1.0), "sfx": "ice"},
	"amber": {"name": "Янтарь", "line": "Тёплая смола, свет внутри",
		"face": Color("fbe8c4"), "lip": Color("f3cf8e"), "seam": Color("ffd98a"), "bevel": Color("f4e2c0"),
		"back": Color("c2741a"), "seam_metal": 0.9, "spec_pow": 50.0, "spec_k": 0.5, "coat": 0.3,
		"sss": 0.66, "sss_col": Color("ffb447"), "grain": 5, "grain_amt": 0.14, "ao": 0.26, "alpha": 1.0,
		"tint": Color(1.0, 0.99, 0.965), "sfx": "amber"},
	"lacquer": {"name": "Лак", "line": "Чёрный лак и киноварь",
		"face": Color("f8f0e3"), "lip": Color("2a1a1d"), "seam": Color("c8463c"), "bevel": Color("efe4d2"),
		"back": Color("17100f"), "seam_metal": 0.7, "spec_pow": 120.0, "spec_k": 0.9, "coat": 0.46,
		"sss": 0.0, "sss_col": Color("000000"), "grain": 6, "grain_amt": 0.0, "ao": 0.30, "alpha": 1.0,
		"tint": Color(1, 1, 1), "sfx": "lacquer"},
}

const BREATH_PERIOD: = 3.2
const BREATH_AMP: = 0.01           # 1.00 ↔ 1.01
const CLOSED_SHADE: = 0.18

const DEFAULTS: = {"material": "", "hl_free": false, "contrast": false, "asmr": true, "ambient": "auto", "ver": 1}

static var _tex: = {}
static var _face_cache: = {}


# ── settings (G.S["v10_mj_look"]) ────────────────────────────────────────────────────────────────────────────────

static func st() -> Dictionary:
	var g = _g()
	if g == null:
		return DEFAULTS.duplicate(true)
	if not (g.S.get("v10_mj_look") is Dictionary):
		g.S["v10_mj_look"] = DEFAULTS.duplicate(true)
	var d: Dictionary = g.S["v10_mj_look"]
	for k in DEFAULTS:
		if not d.has(k):
			d[k] = DEFAULTS[k]
	if d.material != "" and not MATERIALS.has(String(d.material)):
		d.material = ""
	return d


static func _g():
	var tree: = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("G")


static func fx_level() -> String:
	var g = _g()
	return g.fx_level() if g else "full"


# breathing is decorative motion: off at fx_level=min (UX §6.7 «при min движение заменяется проявлением»)
static func breath_on() -> bool:
	return fx_level() != "min"


static func tex(path: String) -> Texture2D:
	if not _tex.has(path):
		_tex[path] = load(path)
	return _tex[path]


static func valid(mat: String) -> String:
	return mat if MATERIALS.has(mat) else "porcelain"


static func display_name(mat: String) -> String:
	return MATERIALS[valid(mat)].name


# ── look dictionary ─────────────────────────────────────────────────────────────────────────────────────────────

# material "" → the player's chosen material, else the table's default. hero = partner id (accent colour).
static func look_dict(material: String = "", hero: = "") -> Dictionary:
	var m: = material
	if m == "":
		m = String(st().material)
	if m == "" and hero != "":
		m = String(V10MjTables.get_theme(hero).get("material", "porcelain"))
	m = valid(m)
	var md: Dictionary = MATERIALS[m]
	var acc: = accent_for(hero)
	return {
		# V6TileLook.body_mat contract
		"side": md.back, "rim": md.lip, "tint": md.tint, "neon": false,
		# v10/mj/look extension
		"v10mj": {"material": m, "accent": acc, "sfx": md.sfx, "params": shader_params(m), "body": body_params(m)},
	}


static func accent_for(hero: String) -> Color:
	var th: = V10MjTables.get_theme(hero) if hero != "" else {}
	if th.has("accent"):
		return th.accent
	return Color("ff8fb8")


static func shader_params(mat: String) -> Dictionary:
	var md: Dictionary = MATERIALS[valid(mat)]
	return {
		"mat_face": md.face, "mat_lip": md.lip, "mat_seam": md.seam, "mat_bevel": md.bevel,
		"seam_metal": md.seam_metal, "spec_pow": md.spec_pow, "spec_k": md.spec_k, "coat_k": md.coat,
		"sss_k": md.sss, "sss_col": md.sss_col, "grain_kind": md.grain, "grain_amt": md.grain_amt, "ao_k": md.ao,
	}


static func body_params(mat: String) -> Dictionary:
	var md: Dictionary = MATERIALS[valid(mat)]
	return {"slab": md.lip, "seam": md.seam, "back": md.back, "seam_metal": md.seam_metal,
		"body_alpha": md.alpha, "sss_k": md.sss, "sss_col": md.sss_col, "spec_k": md.spec_k}


# ── materials ───────────────────────────────────────────────────────────────────────────────────────────────────

static func face_material(mat: String, light: = {}) -> ShaderMaterial:
	var m: = ShaderMaterial.new()
	m.shader = FACE_SHADER
	m.set_shader_parameter("bevel", tex(V6DIR + "tile_bevel.png"))
	m.set_shader_parameter("grain_tex", tex(DIR + "grain.png"))
	var p: = shader_params(mat)
	for k in p:
		m.set_shader_parameter(k, p[k])
	apply_light(m, light)
	return m


static func body_material(mat: String, light: = {}) -> ShaderMaterial:
	var m: = ShaderMaterial.new()
	m.shader = BODY_SHADER
	var p: = body_params(mat)
	for k in p:
		m.set_shader_parameter(k, p[k])
	apply_light(m, light)
	return m


# light = {lamp: Vector2 canvas px, lamp_col: Color, gloss: float, ambient: Color} — from V10MjTables.light()
static func apply_light(m: ShaderMaterial, light: Dictionary) -> void:
	if light.is_empty():
		return
	if light.has("lamp"):
		m.set_shader_parameter("lamp", light.lamp)
	if light.has("lamp_col"):
		var c: Color = light.lamp_col
		m.set_shader_parameter("lamp_col", Vector3(c.r, c.g, c.b))
	if light.has("gloss"):
		m.set_shader_parameter("gloss", float(light.gloss))
	if light.has("ambient") and m.shader == FACE_SHADER:
		var a: Color = light.ambient
		m.set_shader_parameter("ambient", Vector3(a.r, a.g, a.b))


# state on a face or body material. phase comes from the tile index so neighbours never breathe in sync.
static func set_state(m: ShaderMaterial, is_free: bool, closed: bool, hl_free: = false, accent: = Color("ff8fb8"), index: = 0) -> void:
	if m == null:
		return
	m.set_shader_parameter("breathe", 1.0 if (is_free and breath_on()) else 0.0)
	m.set_shader_parameter("phase", phase_for(index))
	m.set_shader_parameter("closed", 1.0 if closed else 0.0)
	if m.shader == FACE_SHADER:
		m.set_shader_parameter("outline", 1.0 if (is_free and hl_free) else 0.0)
		m.set_shader_parameter("accent", accent)


static func phase_for(index: int) -> float:
	# golden-ratio spread: any two neighbouring indices differ by ≈ 0.62 of a period
	return fposmod(float(index) * 0.6180339 * TAU, TAU)


# the scale the shader applies at time t (selftests and the CPU-side contrast badge use the same curve)
static func breath_scale(t: float, index: int, on: = true) -> float:
	if not on:
		return 1.0
	return 1.0 + BREATH_AMP * 0.5 * (1.0 - cos(t * TAU / BREATH_PERIOD + phase_for(index)))


# soft shadow: offset and blur (scale) grow with the layer, alpha fades a little so high tiles float
static func shadow_for_z(z: int) -> Dictionary:
	var zf: = float(clampi(z, 0, 8))
	return {"offset": Vector2(4.0 + 2.6 * zf, 8.0 + 3.6 * zf), "scale": 1.0 + 0.045 * zf, "alpha": clampf(0.62 - 0.05 * zf, 0.3, 0.62)}


# ── (b) dress a legacy Tile (scripts/tile.gd) without editing it ───────────────────────────────────────────────

static func dress(t: Node2D, look: Dictionary, light: = {}) -> void:
	if t == null or not look.has("v10mj"):
		return
	var info: Dictionary = look.v10mj
	var mat_id: String = info.material
	var face_spr = t.get("face_spr")
	var tmat = t.get("mat")
	if face_spr == null or not (tmat is ShaderMaterial):
		return
	# keep the board-driven state uniforms (dim, sel, flash, shine, ice, gold, shade, neon)
	var keep: = {}
	for k in ["dim", "sel", "flash", "shine", "ice", "gold", "shade", "neon"]:
		var v = tmat.get_shader_parameter(k)
		if v != null:
			keep[k] = v
	tmat.shader = FACE_SHADER
	for k in keep:
		tmat.set_shader_parameter(k, keep[k])
	tmat.set_shader_parameter("bevel", tex(V6DIR + "tile_bevel.png"))
	tmat.set_shader_parameter("grain_tex", tex(DIR + "grain.png"))
	var p: Dictionary = info.params
	for k in p:
		tmat.set_shader_parameter(k, p[k])
	apply_light(tmat, light)
	var side = t.get("side_j")
	if side is Sprite2D:
		side.texture = tex(DIR + "body3.png")
		side.position = Vector2.ZERO
		side.modulate = Color.WHITE
		side.material = body_material(mat_id, light)
	var sh = t.get("shadow")
	if sh is Sprite2D:
		var z: = int(t.get("gz")) if t.get("gz") != null else 0
		var s: = shadow_for_z(z)
		sh.position = s.offset
		sh.scale = Vector2.ONE * (84.0 / 185.0) * s.scale
		sh.modulate.a = s.alpha


# free/closed for a dressed legacy Tile (call when the board recomputes freedom)
static func tile_state(t: Node2D, is_free: bool, closed: bool, index: = 0, accent: = Color("ff8fb8")) -> void:
	var hl: = bool(st().hl_free)
	var tmat = t.get("mat")
	if tmat is ShaderMaterial:
		set_state(tmat, is_free, closed, hl, accent, index)
	var side = t.get("side_j")
	if side is Sprite2D and side.material is ShaderMaterial:
		set_state(side.material, is_free, closed, hl, accent, index)
