class_name V10JuiceTransition
extends CanvasLayer

# V10JuiceTransition — the tab-transition curtain (one instance, CanvasLayer 96, above everything).
#   await V10Juice.cover("ink" | "lantern" | "petal" | "auto", dur, center, tab_id)   → screen is hidden
#   V10Juice.reveal(dur)                                                               → the new screen opens
# The cover swallows taps while it is up (no double navigation); a forgotten reveal opens it after 2.5 s.
# «минимум»: a plain 0.12 s dark fade (no shader, no particles). «умеренные»: same shaders, no decor particles.

signal covered
signal revealed

static var inst: V10JuiceTransition

var rect: ColorRect
var style: = ""
var state: = "idle"
var prog: = 0.0
var tw: Tween
var covered_for: = 0.0
var size_v: = Vector2(720, 1280)

const DARK: = Color(0.06, 0.05, 0.07, 1.0)
const SOUND: = {"ink": "trans_ink", "lantern": "trans_lantern", "petal": "trans_petal", "fade": ""}


static func get_or_make() -> V10JuiceTransition:
	if inst != null and is_instance_valid(inst):
		return inst
	inst = V10JuiceTransition.new()
	inst.name = "V10JuiceTransition"
	V10Juice.tree().root.add_child.call_deferred(inst)
	return inst


func _init() -> void:
	layer = V10Juice.LAYER_TOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	rect = ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.visible = false
	add_child(rect)


func _set_p(v: float) -> void:
	prog = v
	if style == "fade":
		rect.color = Color(DARK.r, DARK.g, DARK.b, v)
	else:
		V10Juice.param(rect, "progress", v)


func _kill() -> void:
	if tw and tw.is_valid():
		tw.kill()
	tw = null


func _setup(st: String, center: Vector2) -> void:
	size_v = V10Juice.vp_size()
	rect.position = Vector2.ZERO
	rect.size = size_v
	rect.visible = true
	if st == "fade":
		rect.material = null
		rect.color = Color(DARK.r, DARK.g, DARK.b, prog)
		return
	rect.color = Color.WHITE
	var sh: = {"ink": "juice_ink_wipe", "lantern": "juice_iris", "petal": "juice_petal_wipe"}.get(st, "juice_ink_wipe") as String
	if not (rect.material is ShaderMaterial) or (rect.material as ShaderMaterial).shader != V10Juice.shader(sh):
		rect.material = V10Juice.mat(sh)
	var m: = rect.material as ShaderMaterial
	m.set_shader_parameter("size", size_v)
	match st:
		"ink":
			m.set_shader_parameter("origin", Vector2(0.5, 1.12) if center.x < 0 else center / size_v)
			m.set_shader_parameter("seed", randf() * 40.0)
		"lantern":
			m.set_shader_parameter("center", size_v * 0.5 if center.x < 0 else center)
		"petal":
			m.set_shader_parameter("dir", Vector2(0.55, 0.83))
	m.set_shader_parameter("progress", prog)


func cover(st: = "ink", dur: = 0.34, center: = Vector2(-1, -1), tab_id: = "") -> Signal:
	if st == "auto":
		st = V10Juice.style_for(tab_id)
	if not V10Juice.can_fx():
		st = "fade"
		dur = minf(dur, 0.12)
	_kill()
	if state == "idle" or state == "revealed":
		prog = 0.0
	if style != st:
		# a style change mid-way restarts from clear (only happens when a cover interrupts a running reveal)
		prog = 0.0 if state != "covered" else 1.0
	style = st
	_setup(st, center)
	rect.mouse_filter = Control.MOUSE_FILTER_STOP
	state = "covering"
	covered_for = 0.0
	var snd: String = SOUND.get(st, "")
	if snd != "":
		V10Juice.sound(snd, randf_range(0.97, 1.04), -5.0)
	_decor(st, center)
	tw = create_tween()
	tw.tween_method(_set_p, prog, 1.0, maxf(0.02, dur * (1.0 - prog))).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func():
		state = "covered"
		covered.emit())
	return tw.finished


func reveal(dur: = 0.42) -> Signal:
	_kill()
	if not V10Juice.can_fx():
		dur = minf(dur, 0.14)
	if rect.material is ShaderMaterial:
		var m: = rect.material as ShaderMaterial
		match style:
			"ink":
				# recede toward the top: the new screen washes in from below (seamless — both ends fully covered)
				m.set_shader_parameter("origin", Vector2(0.5, -0.14))
				m.set_shader_parameter("seed", randf() * 40.0)
			"petal":
				m.set_shader_parameter("dir", Vector2(-0.55, -0.83))
	state = "revealing"
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tw = create_tween()
	tw.tween_method(_set_p, prog, 0.0, maxf(0.02, dur * prog)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		state = "idle"
		rect.visible = false
		revealed.emit())
	return tw.finished


func _process(dt: float) -> void:
	if state == "covered":
		covered_for += dt
		if covered_for > 2.5:
			reveal()


# decoration over the curtain, «полные» only: petals drifting across, lantern embers, ink droplets
func _decor(st: String, center: Vector2) -> void:
	if V10Juice.level() != "full":
		return
	var c: = size_v * 0.5 if center.x < 0 else center
	match st:
		"petal":
			V10Juice.burst(self, Vector2(-30, size_v.y * 0.25), "petal", 16, Color(1, 0.82, 0.88), 2.2, Vector2(10, size_v.y * 0.25), Vector2(1, 0.45))
		"lantern":
			V10Juice.burst(self, c + Vector2(0, 40), "ember", 12, Color(1.0, 0.62, 0.3), 1.2, Vector2(90, 20))
		"ink":
			V10Juice.burst(self, Vector2(size_v.x * 0.5, size_v.y + 10), "ink", 10, Color(0.08, 0.06, 0.09), 2.2, Vector2(size_v.x * 0.4, 4), Vector2(0, -1))
