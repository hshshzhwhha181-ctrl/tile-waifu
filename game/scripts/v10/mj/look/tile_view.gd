class_name V10MjTileView
extends Node2D

# V10MjTileView — a self-contained material tile for the new mahjong modes (Classic, Cube, Connect, Garden …).
# Layers (back → front): soft drop shadow (grows with z) · contact AO · accent glow · 3-layer body · face · badge.
# Materials are shared through a cache keyed by (material, state, light): a 144-tile stack is a handful of shader
# materials, and breathing gets its phase from the node's world origin (auto_phase), so it stays desynchronised.
#
#   var t := V10MjTileView.new()
#   t.setup(face, z, "jade", light, accent)      # light from V10MjTables.light(theme, board_rect)
#   t.set_state(free, closed)                    # breathing / 18% shade / «Подсвечивать свободные» outline
#   t.set_selected(on)                           # lift + warm glaze (own material while selected)
#   t.set_contrast(on, specials)                 # suit index badge + special-tile shape markers (colour-blind)
# Size: the node is drawn at TW = 84 px per tile; scale the node for other sizes.

const TEXW: = 185.0
const TEXH: = 192.0
const TW: = 84.0
const S: = TW / TEXW
const SUIT_SHAPES: = ["circle", "triangle", "square", "diamond", "hexagon"]
# special kinds (v06/special + flip/secret + heroine signature) → marker shape
const SPECIAL_SHAPES: = {"gold": "star", "ice": "hexring", "lock": "lock", "chain": "chain", "joker": "ring",
	"bomb": "burst", "gift": "bow", "secret": "eye", "sig": "heart"}

static var _cache: = {}
static var _cache_light_key: = ""

var face: = 0
var z: = 0
var material_id: = "porcelain"
var light: = {}
var accent: = Color("ff8fb8")
var is_open: = true      # a free tile (named so it never shadows Object.free())
var closed: = false
var selected: = false
var contrast: = false
var specials: Array = []
var shadow_col: = Color(0.06, 0.02, 0.05, 1.0)

var shadow: Sprite2D
var contact: Sprite2D
var glow: Sprite2D
var body: Sprite2D
var face_spr: Sprite2D
var badge: V10MjTileBadge
var _own_face: ShaderMaterial


func setup(f: int, layer: int, mat: String, lt: Dictionary = {}, acc: = Color("ff8fb8"), shade_col: = Color(0.06, 0.02, 0.05, 1.0)) -> V10MjTileView:
	face = f
	z = layer
	material_id = V10MjTileMaterial.valid(mat)
	light = lt
	accent = acc
	shadow_col = shade_col
	_build()
	_apply()
	return self


func _build() -> void:
	if face_spr:
		return
	var sh: = V10MjTileMaterial.shadow_for_z(z)
	shadow = Sprite2D.new()
	shadow.texture = V10MjTileMaterial.tex("res://assets/v06/board/tile_drop.png")
	shadow.position = sh.offset
	shadow.scale = Vector2.ONE * S * sh.scale
	shadow.modulate = Color(shadow_col.r, shadow_col.g, shadow_col.b, sh.alpha)
	add_child(shadow)
	contact = Sprite2D.new()
	contact.texture = V10MjTileMaterial.tex("res://assets/v06/board/tile_contact.png")
	contact.scale = Vector2.ONE * S
	contact.position = Vector2(2, 5)
	contact.modulate = Color(shadow_col.r, shadow_col.g, shadow_col.b, 0.85)
	add_child(contact)
	glow = Sprite2D.new()
	glow.texture = V10MjTileMaterial.tex("res://assets/fx/tile_glow.png")
	glow.scale = Vector2.ONE * S * 1.08
	var add: = CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = add
	glow.visible = false
	add_child(glow)
	body = Sprite2D.new()
	body.texture = V10MjTileMaterial.tex("res://assets/v10/mj/look/tile/body3.png")
	body.scale = Vector2.ONE * S
	add_child(body)
	face_spr = Sprite2D.new()
	face_spr.texture = _face_tex(face)
	face_spr.scale = Vector2.ONE * S
	face_spr.self_modulate = V10MjTileMaterial.MATERIALS[material_id].tint
	add_child(face_spr)
	badge = V10MjTileBadge.new()
	badge.scale = Vector2.ONE * S
	badge.visible = false
	add_child(badge)


static func _face_tex(f: int) -> Texture2D:
	var names = null
	var tree: = Engine.get_main_loop() as SceneTree
	var g = tree.root.get_node_or_null("G") if tree and tree.root else null
	if g:
		return g.tile_tex(f)
	return null


static func _light_key(lt: Dictionary) -> String:
	if lt.is_empty():
		return "-"
	return "%s|%s|%s" % [lt.get("lamp", Vector2.ZERO), lt.get("lamp_col", Color.WHITE).to_html(), lt.get("gloss", 1.0)]


static func clear_cache() -> void:
	_cache.clear()


static func shared_material(kind: String, mat: String, lt: Dictionary, is_free: bool, closed: bool, hl: bool, acc: Color) -> ShaderMaterial:
	var breathe: = is_free and V10MjTileMaterial.breath_on()
	var key: = "%s|%s|%s|%d%d%d|%s" % [kind, mat, _light_key(lt), int(breathe), int(closed), int(hl and is_free), acc.to_html()]
	if _cache.has(key) and is_instance_valid(_cache[key]):
		return _cache[key]
	var m: ShaderMaterial = V10MjTileMaterial.face_material(mat, lt) if kind == "face" else V10MjTileMaterial.body_material(mat, lt)
	V10MjTileMaterial.set_state(m, is_free, closed, hl, acc, 0)
	m.set_shader_parameter("auto_phase", 1.0)
	_cache[key] = m
	return m


func _apply() -> void:
	if face_spr == null:
		return
	var hl: = bool(V10MjTileMaterial.st().get("hl_free", false))
	body.material = shared_material("body", material_id, light, is_open, closed, hl, accent)
	if selected:
		if _own_face == null:
			_own_face = V10MjTileMaterial.face_material(material_id, light)
			_own_face.set_shader_parameter("auto_phase", 1.0)
		V10MjTileMaterial.set_state(_own_face, is_open, closed, hl, accent, 0)
		_own_face.set_shader_parameter("sel", 1.0)
		face_spr.material = _own_face
	else:
		face_spr.material = shared_material("face", material_id, light, is_open, closed, hl, accent)
	glow.visible = (hl and is_open and not closed) or selected
	glow.modulate = Color(accent.r, accent.g, accent.b, 0.55 if selected else 0.32)
	badge.visible = contrast
	if contrast:
		badge.set_face(face, specials)


func set_state(is_free: bool, is_closed: bool) -> void:
	is_open = is_free
	closed = is_closed
	_apply()


func set_selected(on: bool) -> void:
	selected = on
	_apply()


func set_contrast(on: bool, sp: Array = []) -> void:
	contrast = on
	specials = sp
	_apply()


func set_light(lt: Dictionary) -> void:
	light = lt
	_apply()


func set_material_id(mat: String) -> void:
	material_id = V10MjTileMaterial.valid(mat)
	if face_spr:
		face_spr.self_modulate = V10MjTileMaterial.MATERIALS[material_id].tint
	_own_face = null
	_apply()


# ── contrast badge ─────────────────────────────────────────────────────────────────────────────────────────────

class V10MjTileBadge extends Node2D:
	var suit: = 0
	var idx: = 1
	var marks: Array = []
	const INK: = Color(0.07, 0.06, 0.08, 0.9)
	const PAPER: = Color(0.96, 0.92, 0.85, 1.0)

	func set_face(f: int, sp: Array) -> void:
		var tree: = Engine.get_main_loop() as SceneTree
		var g = tree.root.get_node_or_null("G") if tree and tree.root else null
		suit = 0
		idx = 1
		if g:
			for i in g.CATS.size():
				if f >= g.CATS[i][0] and f <= g.CATS[i][1]:
					suit = i
					idx = f - int(g.CATS[i][0]) + 1
		marks = sp
		queue_redraw()

	func _draw() -> void:
		# top-left: suit shape + number in a dark pill (≥ 4.5:1 on any plate)
		var r: = Rect2(Vector2(-TEXW * 0.5 + 10, -TEXH * 0.5 + 10), Vector2(84, 50))
		draw_style(r, INK)
		V10MjTileBadge.shape(self, SUIT_SHAPES[clampi(suit, 0, 4)], r.position + Vector2(25, 25), 15.0, PAPER)
		var font: = ThemeDB.fallback_font
		draw_string(font, r.position + Vector2(46, 39), str(idx), HORIZONTAL_ALIGNMENT_LEFT, -1, 38, PAPER)
		# top-right: one marker per special kind, stacked downward
		var y: = -TEXH * 0.5 + 35.0
		for k in marks:
			var nm: String = SPECIAL_SHAPES.get(String(k), "")
			if nm == "":
				continue
			var c: = Vector2(TEXW * 0.5 - 35, y)
			draw_circle(c, 25, INK)
			V10MjTileBadge.shape(self, nm, c, 15.0, PAPER)
			y += 54.0

	func draw_style(r: Rect2, col: Color) -> void:
		var rad: = r.size.y * 0.5
		draw_rect(Rect2(r.position + Vector2(rad, 0), Vector2(r.size.x - 2 * rad, r.size.y)), col)
		draw_circle(r.position + Vector2(rad, rad), rad, col)
		draw_circle(r.position + Vector2(r.size.x - rad, rad), rad, col)

	static func poly(n: int, c: Vector2, rad: float, rot: = 0.0) -> PackedVector2Array:
		var pts: = PackedVector2Array()
		for i in n:
			var a: = rot + TAU * float(i) / float(n)
			pts.append(c + Vector2(cos(a), sin(a)) * rad)
		return pts

	static func shape(ci: CanvasItem, nm: String, c: Vector2, rad: float, col: Color) -> void:
		match nm:
			"circle":
				ci.draw_circle(c, rad, col)
			"triangle":
				ci.draw_colored_polygon(poly(3, c + Vector2(0, 2), rad * 1.2, -PI / 2), col)
			"square":
				ci.draw_rect(Rect2(c - Vector2.ONE * rad * 0.85, Vector2.ONE * rad * 1.7), col)
			"diamond":
				ci.draw_colored_polygon(poly(4, c, rad * 1.15, -PI / 2), col)
			"hexagon":
				ci.draw_colored_polygon(poly(6, c, rad * 1.05, 0.0), col)
			"star":
				var pts: = PackedVector2Array()
				for i in 10:
					var a: = -PI / 2 + TAU * float(i) / 10.0
					pts.append(c + Vector2(cos(a), sin(a)) * (rad * 1.15 if i % 2 == 0 else rad * 0.5))
				ci.draw_colored_polygon(pts, col)
			"hexring":
				var h: = poly(6, c, rad, 0.0)
				h.append(h[0])
				ci.draw_polyline(h, col, 4.0, true)
			"lock":
				ci.draw_rect(Rect2(c + Vector2(-rad * 0.8, -rad * 0.1), Vector2(rad * 1.6, rad * 1.1)), col)
				ci.draw_arc(c + Vector2(0, -rad * 0.15), rad * 0.55, PI, TAU, 12, col, 4.0, true)
			"chain":
				ci.draw_arc(c + Vector2(-rad * 0.45, 0), rad * 0.55, 0, TAU, 16, col, 4.0, true)
				ci.draw_arc(c + Vector2(rad * 0.45, 0), rad * 0.55, 0, TAU, 16, col, 4.0, true)
			"ring":
				ci.draw_arc(c, rad * 0.85, 0, TAU, 20, col, 5.0, true)
			"burst":
				var b: = PackedVector2Array()
				for i in 16:
					var a: = TAU * float(i) / 16.0
					b.append(c + Vector2(cos(a), sin(a)) * (rad * 1.15 if i % 2 == 0 else rad * 0.6))
				ci.draw_colored_polygon(b, col)
			"bow":
				ci.draw_colored_polygon(PackedVector2Array([c, c + Vector2(-rad, -rad * 0.7), c + Vector2(-rad, rad * 0.7)]), col)
				ci.draw_colored_polygon(PackedVector2Array([c, c + Vector2(rad, -rad * 0.7), c + Vector2(rad, rad * 0.7)]), col)
			"eye":
				var e: = PackedVector2Array()
				for i in 16:
					var a: = TAU * float(i) / 16.0
					e.append(c + Vector2(cos(a) * rad * 1.15, sin(a) * rad * 0.6))
				ci.draw_colored_polygon(e, col)
				ci.draw_circle(c, rad * 0.32, INK)
			"heart":
				ci.draw_circle(c + Vector2(-rad * 0.45, -rad * 0.2), rad * 0.5, col)
				ci.draw_circle(c + Vector2(rad * 0.45, -rad * 0.2), rad * 0.5, col)
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-rad * 0.92, -rad * 0.05), c + Vector2(rad * 0.92, -rad * 0.05), c + Vector2(0, rad * 0.95)]), col)
