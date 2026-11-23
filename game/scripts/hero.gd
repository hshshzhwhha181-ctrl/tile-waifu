class_name Hero
extends Node2D


const RIGS: = {
	"mc": {"head_c": Vector2(440, 210), "head_r": 170.0, "neck": Vector2(445, 300), "chest_c": Vector2(440, 430), "chest_r": Vector2(150, 110), 
		"waist_y": 700.0, "feet": Vector2(440, 1232), "hair_l": Vector4(255, 250, 30, 9), "hair_r": Vector4(632, 420, 25, 9), 
		"eye_l": Vector4(400, 225, 17, 13), "eye_r": Vector4(468, 228, 17, 12), "mouth": Vector4(440, 270, 20, 13), "lash": Color(0.36, 0.17, 0.2)}, 
	"rin": {"head_c": Vector2(425, 195), "head_r": 120.0, "neck": Vector2(430, 280), "chest_c": Vector2(440, 420), "chest_r": Vector2(120, 90), 
		"waist_y": 620.0, "feet": Vector2(415, 1238), "hair_l": Vector4(0, 0, 0, 0), "hair_r": Vector4(0, 0, 0, 0), 
		"eye_l": Vector4(398, 217, 13, 9), "eye_r": Vector4(450, 215, 13, 9), "mouth": Vector4(423, 255, 14, 8), "lash": Color(0.2, 0.25, 0.22)}, 
	"hana": {"head_c": Vector2(425, 230), "head_r": 125.0, "neck": Vector2(420, 305), "chest_c": Vector2(440, 430), "chest_r": Vector2(120, 90), 
		"waist_y": 620.0, "feet": Vector2(440, 1232), "hair_l": Vector4(0, 0, 0, 0), "hair_r": Vector4(0, 0, 0, 0), 
		"eye_l": Vector4(414, 225, 16, 13), "eye_r": Vector4(477, 230, 16, 13), "mouth": Vector4(439, 257, 18, 12), "lash": Color(0.35, 0.15, 0.1)}, 
	"yue": {"head_c": Vector2(425, 215), "head_r": 125.0, "neck": Vector2(425, 300), "chest_c": Vector2(425, 420), "chest_r": Vector2(120, 90), 
		"waist_y": 640.0, "feet": Vector2(420, 1212), "hair_l": Vector4(235, 360, 40, 10), "hair_r": Vector4(630, 360, 40, 10), 
		"eye_l": Vector4(397, 227, 14, 9), "eye_r": Vector4(452, 227, 14, 9), "mouth": Vector4(425, 265, 14, 8), "lash": Color(0.35, 0.22, 0.28)}, 
	"nova": {"head_c": Vector2(455, 225), "head_r": 125.0, "neck": Vector2(450, 305), "chest_c": Vector2(455, 420), "chest_r": Vector2(120, 90), 
		"waist_y": 600.0, "feet": Vector2(480, 1250), "hair_l": Vector4(0, 0, 0, 0), "hair_r": Vector4(0, 0, 0, 0), 
		"eye_l": Vector4(427, 230, 15, 11), "eye_r": Vector4(482, 219, 15, 11), "mouth": Vector4(457, 270, 15, 9), "lash": Color(0.2, 0.15, 0.3)}, 
}

var hero_id: = "mc"
var sprite: Sprite2D
var shadow: Sprite2D
var mat: ShaderMaterial
var height: = 900.0
var bounce: = 0.0
var bounce_v: = 0.0
var tilt: = 0.0
var tilt_v: = 0.0
var blink_t: = 2.0
var blink_phase: = -1.0
var talk_left: = 0.0
var talk_t: = 0.0
var interactive: = true
signal tapped

func setup(id: String, h: float) -> Hero:
	hero_id = id
	height = h
	var rig: Dictionary = RIGS[id]
	var tex: Texture2D = load("res://assets/hero/%s.png" % id)
	var sc: = h / 1160.0
	shadow = Sprite2D.new()
	shadow.texture = G.fx("glow")
	shadow.modulate = Color(0.32, 0.12, 0.2, 0.42)
	shadow.scale = Vector2(3.2, 0.55) * sc
	add_child(shadow)
	sprite = Sprite2D.new()
	sprite.texture = tex
	sprite.centered = false
	sprite.scale = Vector2(sc, sc)
	sprite.position = - rig.feet * sc
	mat = ShaderMaterial.new()
	mat.shader = load("res://shaders/hero.gdshader")
	for k in ["head_c", "head_r", "neck", "chest_c", "chest_r", "waist_y", "feet", "hair_l", "hair_r", "eye_l", "eye_r", "mouth"]:
		mat.set_shader_parameter(k, rig[k])
	mat.set_shader_parameter("lash_color", rig.lash)
	mat.set_shader_parameter("phase", randf() * 10.0)
	sprite.material = mat
	add_child(sprite)
	Sfx.voice_started.connect(_on_voice)
	blink_t = randf_range(1.0, 3.0)
	return self

func head_global() -> Vector2:
	var rig: Dictionary = RIGS[hero_id]
	return sprite.to_global(rig.head_c)

func contains_global(pt: Vector2) -> bool:
	var l: = sprite.to_local(pt)
	var rig: Dictionary = RIGS[hero_id]
	var tex: = sprite.texture
	if l.x < 0 or l.y < 0 or l.x >= tex.get_width() or l.y >= tex.get_height():
		return false
	return abs(l.x - rig.feet.x) < 230 and l.y > rig.head_c.y - 140

func _on_voice(h: String, _text: String, dur: float) -> void :
	if h == hero_id and is_visible_in_tree():
		talk_left = dur

func react(kind: = "tap") -> void :
	match kind:
		"tap":
			bounce_v += 7.0
			tilt_v += 0.5 * (1 if randf() < 0.5 else -1)
		"happy":
			bounce_v += 10.0
			tilt_v += 0.35
		"big":
			bounce_v += 16.0
			tilt_v -= 0.6
		"sad":
			bounce_v -= 5.0
			tilt_v += 0.25
	if randf() < 0.5:
		blink_phase = 0.0

func flash(v: = 0.6) -> void :
	mat.set_shader_parameter("flash", v)
	create_tween().tween_method( func(x): mat.set_shader_parameter("flash", x), v, 0.0, 0.35)

func _process(dt: float) -> void :

	bounce_v += (-170.0 * bounce - 9.0 * bounce_v) * dt
	bounce += bounce_v * dt
	tilt_v += (-90.0 * tilt - 7.0 * tilt_v) * dt
	tilt += tilt_v * dt
	mat.set_shader_parameter("bounce", bounce)
	mat.set_shader_parameter("tilt", tilt * 0.12)
	shadow.scale.x = 3.2 * height / 1160.0 * (1.0 + bounce * 0.04)

	if blink_phase < 0.0:
		blink_t -= dt
		if blink_t <= 0.0:
			blink_phase = 0.0
			blink_t = randf_range(2.2, 4.8)
			if randf() < 0.18:
				blink_t = 0.25
	if blink_phase >= 0.0:
		blink_phase += dt / 0.16
		var b: float = 1.0 - absf(blink_phase * 2.0 - 1.0)
		mat.set_shader_parameter("blink", clamp(b * 1.15, 0.0, 1.0))
		if blink_phase >= 1.0:
			blink_phase = -1.0
			mat.set_shader_parameter("blink", 0.0)

	if talk_left > 0.0:
		talk_left -= dt
		talk_t += dt
		var v: = 0.5 + 0.5 * sin(talk_t * 21.0) * sin(talk_t * 7.3 + 1.0)
		mat.set_shader_parameter("talk", v if talk_left > 0.0 else 0.0)
	else:
		mat.set_shader_parameter("talk", 0.0)

func _unhandled_input(e: InputEvent) -> void :
	if not interactive or not is_visible_in_tree():
		return
	if e is InputEventScreenTouch and e.pressed:
		if contains_global(get_canvas_transform().affine_inverse() * e.position):
			react("tap")
			tapped.emit()
			get_viewport().set_input_as_handled()
