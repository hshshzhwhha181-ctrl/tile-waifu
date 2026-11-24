class_name V10MjRiichiPortrait
extends Control

# Round seat portrait (UX §6.1: circle only for heroine portraits in play). Face crops from v08 art:
# neutral = hero/<id>.png, expressions = v08/emotions/<id>_<face>.webp. Expression changes cross-fade 120 ms.
# Expressions are driven only by V10MjRiichiMimic (public events) — never by her hidden hand.

const NEUTRAL_C: = {"mc": Vector2(408, 138), "rin": Vector2(424, 228), "hana": Vector2(403, 175), "yue": Vector2(419, 228), "nova": Vector2(419, 222)}
const EMO_C: = {"mc": Vector2(300, 150), "rin": Vector2(290, 170), "hana": Vector2(290, 175), "yue": Vector2(290, 170), "nova": Vector2(290, 182)}
const NEUTRAL_R: = 72.0
const EMO_R: = 122.0
const FACES: = ["happy", "pout", "sad", "shy", "surprised"]

const MASK_SHADER: = "shader_type canvas_item;
uniform float dim = 0.0;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	c.rgb = mix(c.rgb, vec3(dot(c.rgb, vec3(0.3, 0.59, 0.11))) * 0.55, dim);
	COLOR = c;
}"

static var _shader: Shader
static var _tex: = {}

var hero: = "mc"
var face: = "neutral"
var ring: = Color.WHITE
var ring_w: = 3.0
var active: = false
var dimmed: = false
var _a: TextureRect
var _b: TextureRect
var _mask: Control
var _ring: Control
var _bg_col: = Color("26212a")

static func make(hero_id: String, d: float, ring_col: Color) -> V10MjRiichiPortrait:
	var p: = V10MjRiichiPortrait.new()
	p.hero = hero_id
	p.ring = ring_col
	p.size = Vector2(d, d)
	p.custom_minimum_size = p.size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p._build()
	return p

static func face_tex(hero_id: String, f: String) -> Texture2D:
	var key: = hero_id + ":" + f
	if _tex.has(key):
		return _tex[key]
	var path: = "res://assets/hero/%s.png" % hero_id if f == "neutral" else "res://assets/v08/emotions/%s_%s.webp" % [hero_id, f]
	if not ResourceLoader.exists(path):
		path = "res://assets/hero/mc.png"
		f = "neutral"
		hero_id = "mc"
	var src: Texture2D = load(path)
	var at: = AtlasTexture.new()
	at.atlas = src
	var c: Vector2 = (NEUTRAL_C if f == "neutral" else EMO_C).get(hero_id, Vector2(300, 160))
	var rr: float = NEUTRAL_R if f == "neutral" else EMO_R
	at.region = Rect2(c - Vector2(rr, rr), Vector2(rr, rr) * 2.0)
	_tex[key] = at
	return at

func _build() -> void:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = MASK_SHADER
	_mask = Control.new()
	_mask.size = size
	_mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mask.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	_mask.draw.connect(func(): _mask.draw_circle(_mask.size * 0.5, _mask.size.x * 0.5, _bg_col))
	add_child(_mask)
	for i in 2:
		var t: = TextureRect.new()
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_SCALE
		t.size = size
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var m: = ShaderMaterial.new()
		m.shader = _shader
		t.material = m
		_mask.add_child(t)
		if i == 0:
			_a = t
		else:
			_b = t
	_a.texture = face_tex(hero, "neutral")
	_b.modulate.a = 0.0
	_ring = Control.new()
	_ring.size = size
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring.draw.connect(_draw_ring)
	add_child(_ring)
	resized.connect(func():
		_a.size = size
		_b.size = size
		_mask.size = size
		_ring.size = size
		_mask.queue_redraw()
		_ring.queue_redraw())

func set_face(f: String, instant: = false) -> void:
	if f == face:
		return
	face = f
	_b.texture = face_tex(hero, f)
	if instant or not is_inside_tree():
		_a.texture = _b.texture
		return
	var tw: = create_tween()
	_b.modulate.a = 0.0
	tw.tween_property(_b, "modulate:a", 1.0, 0.12)
	tw.tween_callback(func():
		_a.texture = _b.texture
		_b.modulate.a = 0.0)

func set_dim(on: bool) -> void:
	dimmed = on
	for t in [_a, _b]:
		(t.material as ShaderMaterial).set_shader_parameter("dim", 0.55 if on else 0.0)

func set_active(on: bool) -> void:
	if active == on:
		return
	active = on
	if _ring:
		_ring.queue_redraw()

# her turn: the ring brightens and thickens (no flashing)
func _draw_ring() -> void:
	var c: = size * 0.5
	var r: = size.x * 0.5
	_ring.draw_arc(c, r - ring_w * 0.5 + 1.0, 0, TAU, 64, Color(ring, 0.95 if active else 0.5), ring_w + (2.0 if active else 0.0), true)
