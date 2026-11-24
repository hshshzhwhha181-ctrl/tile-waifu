class_name V10KeyArt
extends Control

# Animated key art of the login screen: the five founders over the dusk teahouse, built from simple layers.
#   var ka: = V10KeyArt.make(parent, size)
#   ka.place_heroes(Rect2(...))   where the group stands (the login screen lays it out per aspect ratio)
# Layers, back to front:
#   bg plate (key_bg.webp, cover-fit, 6 % overscan)  · lantern glows (flicker)  · warm halo behind the group
#   heroes cut-out (key_heroes.webp): idle sway + breath around the feet, one light sweep every ~6 s (shader)
#   petals (Fx.ambient) in front
# Parallax: each layer drifts with a slow Lissajous and follows the phone's tilt (accelerometer) or the mouse;
# depth factors 0.35 / 0.7 / 1.0. Everything is gated by S.fx_level: «минимум» keeps a still picture.

const BG: = "res://assets/v10/auth/key_bg.webp"
const HEROES: = "res://assets/v10/auth/key_heroes.webp"
const BG_SIZE: = Vector2(1520, 2688)
# lantern centres and radii in key_bg.webp pixels (measured on the plate)
const LANTERNS: = [
	[Vector2(116, 494), 74.0], [Vector2(276, 604), 62.0], [Vector2(1264, 624), 64.0], [Vector2(1412, 540), 70.0],
	[Vector2(96, 1944), 70.0], [Vector2(1420, 1560), 80.0],
]
const OVERSCAN: = 1.06

var bg: TextureRect
var heroes: TextureRect
var halo: TextureRect
var glows: Array = []
var petals: Node2D
var sweep_mat: ShaderMaterial
var bg_base: = Vector2.ZERO
var bg_scale: = 1.0
var hero_base: = Rect2()
var t: = 0.0
var tilt: = Vector2.ZERO
var still: = false
var _sweep_t: = 2.0
var intro_y: = 0.0


static func make(parent: Control, sz: Vector2) -> V10KeyArt:
	var k: = V10KeyArt.new()
	k.name = "V10KeyArt"
	k.size = sz
	k.mouse_filter = Control.MOUSE_FILTER_IGNORE
	k.clip_contents = true
	parent.add_child(k)
	k._build()
	return k


func _tex(path: String) -> Texture2D:
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


func _build() -> void :
	still = not V9Feel.can_fx()
	var back: = ColorRect.new()
	back.color = Color("2a1d33")
	back.size = size
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)
	bg = TextureRect.new()
	bg.texture = _tex(BG)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	# cover-fit with overscan for the drift; focus slightly above the middle (the sky carries the logo)
	bg_scale = maxf(size.x / BG_SIZE.x, size.y / BG_SIZE.y) * OVERSCAN
	bg.size = BG_SIZE * bg_scale
	bg_base = Vector2((size.x - bg.size.x) * 0.5, (size.y - bg.size.y) * 0.42)
	bg.position = bg_base
	for l in LANTERNS:
		var g: = _glow(l[1] * bg_scale * 2.6, Color(1.0, 0.72, 0.42, 0.42))
		g.set_meta("src", l[0])
		g.set_meta("ph", randf() * TAU)
		bg.add_child(g)
		g.position = l[0] * bg_scale - g.size * 0.5
		glows.append(g)
	halo = _glow(size.x * 1.25, Color(1.0, 0.78, 0.62, 0.30))
	add_child(halo)
	heroes = TextureRect.new()
	heroes.name = "Heroes"
	heroes.texture = _tex(HEROES)
	heroes.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	heroes.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	heroes.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	heroes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sweep_mat = ShaderMaterial.new()
	sweep_mat.shader = load("res://scripts/v10/auth/key_sweep.gdshader")
	heroes.material = sweep_mat
	add_child(heroes)
	place_heroes(Rect2(0, size.y * 0.2, size.x, size.x * 1298.0 / 1400.0))
	petals = Fx.ambient(self, "petals", size)
	petals.modulate = Color(1, 1, 1, 0.85)
	set_process(not still)


func _glow(d: float, col: Color) -> TextureRect:
	var gt: = GradientTexture2D.new()
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(0.5, 0.0)
	gt.width = 128
	gt.height = 128
	var gr: = Gradient.new()
	gr.set_color(0, col)
	gr.set_color(1, Color(col, 0.0))
	gr.add_point(0.45, Color(col, col.a * 0.35))
	gt.gradient = gr
	var r: = TextureRect.new()
	r.texture = gt
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.size = Vector2(d, d)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m: = CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	r.material = m
	return r


# the group stands in r (keeps the art's aspect, bottom-centred); the halo sits behind the faces
func place_heroes(r: Rect2) -> void :
	hero_base = r
	heroes.position = r.position
	heroes.size = r.size
	heroes.pivot_offset = Vector2(r.size.x * 0.5, r.size.y)
	halo.size = Vector2(r.size.x * 1.25, r.size.x * 1.25)
	halo.position = Vector2(r.get_center().x - halo.size.x * 0.5, r.position.y + r.size.y * 0.42 - halo.size.y * 0.5)


func intro() -> void :
	# the group rises into place, the plate settles from a slight zoom; heroes brighten in
	heroes.modulate = Color(1, 1, 1, 0)
	intro_y = 46.0
	heroes.position.y = hero_base.position.y + intro_y
	var tw: = create_tween().set_parallel()
	tw.tween_property(heroes, "modulate:a", 1.0, 0.7).set_delay(0.15)
	tw.tween_property(self, "intro_y", 0.0, 0.9).set_delay(0.15).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	if still:
		heroes.position.y = hero_base.position.y
		tw.tween_callback(func(): heroes.position.y = hero_base.position.y).set_delay(1.1)
	bg.modulate = Color(0.6, 0.55, 0.65)
	tw.tween_property(bg, "modulate", Color.WHITE, 1.1)
	_sweep_t = 1.4


func _input(e: InputEvent) -> void :
	if e is InputEventMouseMotion and not OS.has_feature("mobile"):
		var c: = size * 0.5
		tilt = ((e as InputEventMouseMotion).position - c) / c


func _process(dt: float) -> void :
	t += dt
	var drift: = Vector2(sin(t * 0.21), cos(t * 0.17) * 0.6)
	var acc: = Input.get_accelerometer()
	if acc != Vector3.ZERO:
		tilt = tilt.lerp(Vector2(clampf(acc.x / 4.0, -1, 1), clampf((acc.y + 6.0) / 4.0, -1, 1)), minf(1.0, dt * 3.0))
	var off: = drift * 0.6 + tilt * 0.8
	var amp: = (bg.size.x - size.x) * 0.45
	bg.position = bg_base + Vector2(off.x * amp * 0.35, off.y * amp * 0.25)
	# heroes: depth 0.7 + idle sway (pivot at the feet) + breathing
	heroes.position = hero_base.position + Vector2(off.x * 9.0, off.y * 5.0 + intro_y)
	heroes.rotation = deg_to_rad(0.35 * sin(t * 0.55))
	var br: = 1.0 + 0.006 * sin(t * 1.25)
	heroes.scale = Vector2(1.0 + 0.002 * sin(t * 0.9), br)
	halo.modulate.a = 0.85 + 0.15 * sin(t * 0.7)
	if petals:
		petals.position = Vector2(off.x * 16.0, off.y * 8.0)
	for g in glows:
		var ph: float = g.get_meta("ph")
		g.modulate.a = 0.78 + 0.16 * sin(t * 2.3 + ph) + 0.06 * sin(t * 7.1 + ph * 2.0)
	_sweep_t -= dt
	if _sweep_t <= 0.0:
		_sweep_t = 6.5 + randf() * 2.0
		var tw: = create_tween()
		tw.tween_method(func(v): sweep_mat.set_shader_parameter("pos", v), -0.4, 1.9, 1.7).set_trans(Tween.TRANS_SINE)


# dev / screenshots: freeze at a pleasant frame (sweep across the centre)
func dev_freeze(sweep: = 0.75) -> void :
	set_process(false)
	sweep_mat.set_shader_parameter("pos", sweep)
	heroes.modulate.a = 1.0
	intro_y = 0.0
	heroes.position = hero_base.position
	bg.modulate = Color.WHITE
