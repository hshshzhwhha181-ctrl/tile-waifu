class_name V10SalonHeroine
extends Control

# The heroine of a zone, alive (spec §Р2 п.1). One API over two bodies:
#   * a V10LiveRig when her rig exists (RIGS below; Маджонг-тян's mc_gown today, other founders when the rig lanes
#     land — add the path, nothing else changes), with tap zones, gestures and lip-sync;
#   * otherwise «стоп-кадр с дыханием»: her cutout with breath.gdshader (breathing, head drift, braid sway) and a
#     squash-and-stretch hop on taps.
# Sizes: `make(hero, height)` scales her so the figure is `height` px tall, feet (or the rig's crop) at the bottom
# edge, centred on x = size.x / 2. set_live(false) freezes her (zone scrolled away): no _process, no rig update.

signal tapped(zone: String)

const RIGS: = {
	"mc": ["res://assets/v10/rig/mc_gown/rig.tscn"],
	"rin": ["res://assets/v10/rig/rin_qipao/rig.tscn", "res://assets/v10/rig/rin_base/rig.tscn", "res://assets/v10/rig/rin/rig.tscn"],
}
const STILLS: = {
	"rin": {"tex": "res://assets/v10/salon/rin_cut.png", "chest": Vector2(0.18, 0.35), "head_y": 0.07, "hair_x": Vector2(0.68, 0.97)},
}
# the rig's figure: art x that should sit on the centre line, and the art height (body.png px)
const RIG_CENTER_X: = 581.0
const RIG_H: = 1400.0

var hero: = ""
var rig: V10LiveRig
var still: TextureRect
var mat: ShaderMaterial
var live: = true
var interactive: = true
var _t: = 0.0
var _hop: = 0.0
var _hop_v: = 0.0
var _sway: = 0.0
var _press: = false


static func has_rig(h: String) -> String:
	for p in RIGS.get(h, []):
		if ResourceLoader.exists(p):
			return p
	return ""


static func make(h: String, box: Vector2, rig_ok: = true, rig_input: = false) -> V10SalonHeroine:
	var n: = V10SalonHeroine.new()
	n.hero = h
	n.size = box
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rp: = has_rig(h) if rig_ok else ""
	if rp != "":
		n.rig = load(rp).instantiate()
		n.rig.show_background = false
		n.rig.handle_input = rig_input
		n.rig.motion = 1.0 if V10SalonUI.full_fx() else 0.5
		var k: = box.y / RIG_H
		n.rig.scale = Vector2.ONE * k
		n.rig.position = Vector2(box.x * 0.5 - RIG_CENTER_X * k, box.y - RIG_H * k)
		n.add_child(n.rig)
		n.rig.tapped.connect(func(z: String): n.tapped.emit(z))
	elif STILLS.has(h):
		var cfg: Dictionary = STILLS[h]
		var tex: Texture2D = load(cfg.tex)
		var asp: = tex.get_width() / float(tex.get_height())
		var hh: = box.y
		var ww: = hh * asp
		n.still = TextureRect.new()
		n.still.texture = tex
		n.still.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		n.still.stretch_mode = TextureRect.STRETCH_SCALE
		n.still.size = Vector2(ww, hh)
		n.still.position = Vector2(box.x * 0.5 - ww * 0.5, box.y - hh)
		n.still.pivot_offset = Vector2(ww * 0.5, hh)
		n.still.mouse_filter = Control.MOUSE_FILTER_STOP if rig_input else Control.MOUSE_FILTER_IGNORE
		n.mat = ShaderMaterial.new()
		n.mat.shader = load("res://scripts/v10/salon/breath.gdshader")
		n.mat.set_shader_parameter("chest", cfg.chest)
		n.mat.set_shader_parameter("head_y", cfg.head_y)
		n.mat.set_shader_parameter("hair_x", cfg.hair_x)
		n.mat.set_shader_parameter("px", Vector2(1.0 / tex.get_width(), 1.0 / tex.get_height()))
		n.still.material = n.mat
		n.add_child(n.still)
		n.still.gui_input.connect(n._on_still_input)
	return n


func is_rig() -> bool:
	return rig != null


func set_live(on: bool) -> void:
	live = on
	set_process(on)
	if rig:
		rig.set_process(on)
		rig.set_physics_process(on)


func _process(dt: float) -> void:
	if still == null or not live:
		return
	var m: = 1.0 if V10SalonUI.full_fx() else 0.5
	_t += dt
	var ph: = fmod(_t / 4.0, 1.0)
	var b: = 0.5 - 0.5 * cos(ph * TAU)
	# hop spring
	_hop_v += (-120.0 * _hop - 9.0 * _hop_v) * dt
	_hop += _hop_v * dt
	_sway = lerpf(_sway, 0.0, dt * 2.0)
	mat.set_shader_parameter("t", _t * m)
	mat.set_shader_parameter("breath", b * m)
	mat.set_shader_parameter("hop", clampf(_hop, -1.0, 1.0))
	mat.set_shader_parameter("sway", _sway)


func appear(delay: = 0.0) -> void:
	if rig:
		if delay > 0.0:
			await get_tree().create_timer(delay).timeout
		rig.appear()
		return
	if still == null:
		return
	still.modulate.a = 0.0
	still.scale = Vector2(0.94, 0.94)
	var t: = create_tween()
	t.tween_interval(delay)
	t.tween_property(still, "modulate:a", 1.0, 0.25)
	t.parallel().tween_property(still, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_callback(func(): hop(0.8))


# squash-and-stretch hop (still) / a happy nuzzle (rig)
func hop(strength: = 1.0) -> void:
	if rig:
		rig.react("head")
		return
	_hop = -0.6 * strength
	_hop_v = 9.0 * strength
	_sway = signf(randf() - 0.5) * 0.9 * strength


func react_at(global_p: Vector2) -> String:
	if rig:
		return rig.tap(global_p)
	if still == null:
		return "none"
	var lp: = still.get_global_transform().affine_inverse() * global_p
	if not Rect2(Vector2.ZERO, still.size).has_point(lp):
		return "none"
	var img_alpha: = _alpha_at(lp / still.size)
	if img_alpha < 0.3:
		return "none"
	var v: = lp.y / still.size.y
	# the still has head / hair / outfit; intimate areas are dead zones (HEROINES red lines), like the rig
	var zone: = "outfit"
	if v < 0.13:
		zone = "head"
	elif lp.x / still.size.x > 0.62:
		zone = "hair"
	elif v > 0.34 and v < 0.55:
		return "none"
	hop(1.0 if zone == "head" else 0.6)
	if zone == "hair":
		_sway = 1.0
	tapped.emit(zone)
	return zone


var _img: Image

func _alpha_at(uv: Vector2) -> float:
	if _img == null:
		_img = still.texture.get_image()
	if _img == null:
		return 1.0
	var p: = Vector2i(clampi(int(uv.x * _img.get_width()), 0, _img.get_width() - 1), clampi(int(uv.y * _img.get_height()), 0, _img.get_height() - 1))
	return _img.get_pixelv(p).a


func _on_still_input(e: InputEvent) -> void:
	if not interactive:
		return
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and e.pressed:
		if react_at(still.get_global_transform() * e.position) != "none":
			still.accept_event()


func talk(sec: float) -> void:
	if rig:
		rig.talk(sec)


func look_at_global(p: Vector2) -> void:
	if rig:
		rig.look_at_global(p, 1.5)
