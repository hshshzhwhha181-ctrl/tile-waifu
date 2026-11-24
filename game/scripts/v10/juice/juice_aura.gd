class_name V10JuiceAura
extends Control

# V10JuiceAura — a glow drawn only OUTSIDE a rounded frame (juice_frame_aura):
#   fever      flames licking out of the board frame + embers rising off its top edge (the board stays clear)
#   heartbeat  «ульта готова»: a lub-dub glow around a button, a ripple on each beat; follows the button
# «умеренные»: fewer embers, no ripples. «минимум»: a static outline (it still says «готово» / «лихорадка»).
# Stop with V10Juice.stop(node) — fades out and frees.

const PAD_FEVER: = 46.0
const PAD_BEAT: = 30.0
const PERIOD: = 1.05

var glow: ColorRect
var embers: CPUParticles2D
var target: Control
var kind: = ""
var pad: = 30.0
var t: = 0.0
var last_beat: = -1
var with_sound: = false
var col_a: = Color.WHITE
var stopping: = false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _make_glow(inner: Vector2, radius: float, a: Color, b: Color, mode: int, intensity: float) -> void:
	glow = ColorRect.new()
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.material = V10Juice.mat("juice_frame_aura", {"size": inner, "pad": pad, "radius": radius, "color_a": a,
		"color_b": b, "mode": mode, "intensity": intensity, "seed": randf() * 20.0, "beat": 1.0})
	add_child(glow)


func setup_fever(frame: Rect2, a: Color, b: Color, radius: float) -> void:
	kind = "fever"
	pad = PAD_FEVER
	position = frame.position - Vector2(pad, pad)
	size = frame.size + Vector2(pad, pad) * 2.0
	var lvl: = V10Juice.level()
	_make_glow(frame.size, radius, a, b, 0 if lvl != "min" else 1, 0.8 if lvl == "full" else (0.62 if lvl == "mid" else 0.7))
	glow.size = size
	if lvl == "min":
		V10Juice.param(glow, "beat", 0.75)
	else:
		# ignite: the aura swells in
		modulate.a = 0.0
		var tw: = create_tween()
		tw.tween_property(self, "modulate:a", 1.0, 0.35)
		var e: = V10Juice.n(16)
		if e > 0:
			embers = CPUParticles2D.new()
			embers.texture = V10JuiceTex.get_tex("ember")
			embers.material = V10Juice.add_mat()
			embers.amount = e
			embers.lifetime = 1.3
			embers.local_coords = false
			embers.position = Vector2(size.x * 0.5, pad)
			embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
			embers.emission_rect_extents = Vector2(frame.size.x * 0.5, 4)
			embers.direction = Vector2(0, -1)
			embers.spread = 18.0
			embers.gravity = Vector2(0, -90)
			embers.initial_velocity_min = 60.0
			embers.initial_velocity_max = 160.0
			embers.particle_flag_align_y = true
			embers.scale_amount_min = 0.3
			embers.scale_amount_max = 0.7
			embers.color = b
			embers.color_ramp = Fx._grad([Color(1, 1, 1, 0), Color(1, 1, 1, 0.9), Color(1, 0.6, 0.4, 0)])
			add_child(embers)
			embers.emitting = true
		V10Juice.burst(null, get_global_rect().get_center() + Vector2(0, -frame.size.y * 0.5), "spark", 18, b, 1.1, Vector2(frame.size.x * 0.45, 4), Vector2(0, -1))


func setup_heartbeat(tgt: Control, a: Color, b: Color, snd: bool) -> void:
	kind = "beat"
	target = tgt
	pad = PAD_BEAT
	with_sound = snd
	col_a = a
	var r: = minf(tgt.size.x, tgt.size.y) * 0.32
	_make_glow(tgt.size, r, a, b, 1, 0.85 if V10Juice.level() == "full" else 0.65)
	_follow()
	if V10Juice.level() == "min":
		V10Juice.param(glow, "beat", 0.6)


func _follow() -> void:
	if target == null or not is_instance_valid(target):
		return
	var s: = target.size * target.scale
	# a pressed / bouncing button scales around its pivot: follow its visual rect
	var p: = target.position + target.pivot_offset * (Vector2.ONE - target.scale)
	position = p - Vector2(pad, pad)
	size = s + Vector2(pad, pad) * 2.0
	glow.size = size
	V10Juice.param(glow, "size", s)
	visible = target.is_visible_in_tree()


static func _g(x: float, m: float, w: float) -> float:
	return exp(-pow((x - m) / w, 2.0))


func _process(dt: float) -> void:
	if kind != "beat" or glow == null:
		return
	if target == null or not is_instance_valid(target):
		queue_free()
		return
	_follow()
	if V10Juice.level() == "min" or stopping:
		return
	t += dt
	var ph: = fmod(t, PERIOD)
	var beat: = 0.3 + 0.7 * maxf(_g(ph, 0.08, 0.07), 0.78 * _g(ph, 0.3, 0.08))
	V10Juice.param(glow, "beat", beat)
	var k: = int(t / PERIOD)
	if k != last_beat and ph > 0.06:
		last_beat = k
		if visible and V10Juice.level() == "full":
			V10Juice.ripple(get_parent(), target.position + target.size * 0.5, col_a, maxf(target.size.x, target.size.y) * 0.85, 0.6, 0.05)
		if with_sound and visible:
			V10Juice.sound("ult_heartbeat", 1.0, -12.0)


func stop(dur: = 0.35) -> void:
	if stopping:
		return
	stopping = true
	if embers:
		embers.emitting = false
	var tw: = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, dur)
	tw.tween_callback(queue_free)
