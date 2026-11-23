class_name V6TileLook
extends RefCounted





const DIR: = "res://assets/v06/board/"
const FACE_SHADER: = preload("res://shaders/v06/board/tile_face.gdshader")
const BODY_SHADER: = preload("res://shaders/v06/board/tile_body.gdshader")
const KEEP: = ["dim", "sel", "flash", "shine", "ice", "gold", "shade", "neon"]
const IVORY: = Color("f4ecdc")

static var enabled: = true
static var _tex: = {}
static var _body_mats: = {}
static var lamp: = Vector2(250, 330)
static var lamp_col: = Color(1.0, 0.94, 0.84)
static var gloss: = 1.0
static var ambient: = Color(0, 0, 0)
static var shadow_col: = Color(0.1, 0.03, 0.09, 0.62)

static func tex(n: String) -> Texture2D:
	if not _tex.has(n):
		_tex[n] = load(DIR + n + ".png")
	return _tex[n]

static func body_mat(lk: Dictionary) -> ShaderMaterial:
	var side: Color = lk.get("side", Color("3f9c7c"))
	var rim: Color = lk.get("rim", IVORY)
	var key: = "%s|%s|%s" % [side.to_html(), rim.to_html(), lk.get("neon", false)]
	if _body_mats.has(key) and is_instance_valid(_body_mats[key]):
		return _body_mats[key]
	var m: = ShaderMaterial.new()
	m.shader = BODY_SHADER
	m.set_shader_parameter("ivory", IVORY.lerp(rim, 0.3))
	m.set_shader_parameter("back", side)
	m.set_shader_parameter("neon", 1.0 if lk.get("neon", false) else 0.0)
	_apply_light(m)
	_body_mats[key] = m
	return m

static func _apply_light(m: ShaderMaterial) -> void :
	m.set_shader_parameter("lamp", lamp)
	m.set_shader_parameter("lamp_col", Vector3(lamp_col.r, lamp_col.g, lamp_col.b))
	m.set_shader_parameter("gloss", gloss)
	if m.shader == FACE_SHADER:
		m.set_shader_parameter("ambient", Vector3(ambient.r, ambient.g, ambient.b))


static func dress(t: Tile) -> void :
	if not enabled or t.face_spr == null or t.mat == null:
		return

	t.shadow.texture = tex("tile_drop")
	t.shadow.scale = Vector2(Tile.S, Tile.S)
	t.shadow.modulate = shadow_col
	var contact: = Sprite2D.new()
	contact.name = "V6Contact"
	contact.texture = tex("tile_contact")
	contact.scale = Vector2(Tile.S, Tile.S)
	contact.modulate = Color(shadow_col.r, shadow_col.g, shadow_col.b, 0.9)
	t.add_child(contact)
	t.move_child(contact, t.shadow.get_index() + 1)
	t.shadow.visibility_changed.connect( func(): contact.visible = t.shadow.visible)

	if t.side_j:
		t.side_j.texture = tex("tile_body")
		t.side_j.position = Vector2.ZERO
		t.side_j.scale = Vector2(Tile.S, Tile.S)
		t.side_j.modulate = Color.WHITE
		t.side_j.material = body_mat(t.look)
	if t.side_i:
		t.side_i.visible = false

	var vals: = {}
	for k in KEEP:
		var v = t.mat.get_shader_parameter(k)
		if v != null:
			vals[k] = v
	t.mat.shader = FACE_SHADER
	for k in vals:
		t.mat.set_shader_parameter(k, vals[k])
	t.mat.set_shader_parameter("bevel", tex("tile_bevel"))
	_apply_light(t.mat)

	t.ready.connect( func(): _post(t), CONNECT_ONE_SHOT)

static func _post(t: Tile) -> void :
	if not is_instance_valid(t) or t.shard == "":
		return

	t.mat.set_shader_parameter("bevel_on", 0.0)
	for c in t.get_children():
		if c is Sprite2D and c != t.face_spr and c.texture == G.fx("tile_mask") and c.material == null and c.visible and c != t.side_i:
			var m: = ShaderMaterial.new()
			m.shader = FACE_SHADER
			m.set_shader_parameter("bevel", tex("tile_bevel"))
			m.set_shader_parameter("gold", 1.0)
			_apply_light(m)
			c.material = m


static func relight(tiles: Array) -> void :
	for m in _body_mats.values():
		if is_instance_valid(m):
			_apply_light(m)
	for t in tiles:
		if not is_instance_valid(t) or t.mat == null or t.mat.shader != FACE_SHADER:
			continue
		_apply_light(t.mat)
		t.shadow.modulate = shadow_col
		var c: Node = t.get_node_or_null("V6Contact")
		if c:
			(c as CanvasItem).modulate = Color(shadow_col.r, shadow_col.g, shadow_col.b, 0.9)
		for ch in t.get_children():
			if ch is Sprite2D and ch.material is ShaderMaterial and ch.material != t.mat and (ch.material as ShaderMaterial).shader == FACE_SHADER:
				_apply_light(ch.material)
