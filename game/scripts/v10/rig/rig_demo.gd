extends Node2D

# Demo for V10LiveRig (scenes/v10/rig_demo.tscn). Shows Маджонг-тян in her evening gown, idle, with a scripted
# run of taps so a movie capture shows every reaction:
#   godot --path game res://scenes/v10/rig_demo.tscn --write-movie out.avi --fixed-fps 30 --quit-after 330
# User args (after --): --script=0 turns the scripted taps off (then tap her yourself), --perf=1 prints timings,
# --shots=<dir> --at=1.0,2.5 saves PNG frames at those seconds.

const RIG: = preload("res://assets/v10/rig/mc_gown/rig.tscn")
const ART_SCALE: = 0.645
const CENTER_X: = 581.0  # art x that sits on the screen centre
const BOTTOM: = 1292.0  # screen y of the art's bottom edge (a little under the screen)

var rig: V10LiveRig
var t: = 0.0
var args: = {}
var _timeline: = []
var _ripples: = []
var _caption: Label
var _ov: Node2D
var _perf: = {"n": 0, "rig_us": 0, "frame_ms": 0.0, "max_rig_us": 0}
var _shots: = []


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv: = a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var vs: = get_viewport_rect().size
	rig = RIG.instantiate()
	rig.scale = Vector2.ONE * ART_SCALE
	rig.position = Vector2(vs.x * 0.5 - CENTER_X * ART_SCALE, BOTTOM - 1400.0 * ART_SCALE)
	add_child(rig)
	rig.tapped.connect(func(z: String) -> void: _say("tap: " + z))
	_ov = Node2D.new()
	add_child(_ov)
	_ov.draw.connect(_draw_ov)
	_caption = Label.new()
	_caption.position = Vector2(24, 24)
	_caption.add_theme_font_size_override("font_size", 22)
	_caption.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	_caption.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	add_child(_caption)
	if args.get("script", "1") != "0":
		# seconds, action, art-space point (taps are real input events at her screen position)
		_timeline = [
			[0.0, "appear"],
			[2.6, "tap", Vector2(700, 150)],  # head -> shy happy + bob
			[5.0, "tap", Vector2(1060, 260)],  # raised arm -> hair fiddle
			[6.7, "tap", Vector2(610, 885)],  # hand on hip -> pats
			[8.2, "tap", Vector2(1180, 700)],  # background -> playful glance
			[9.6, "talk", 2.2],
			[10.3, "tap", Vector2(150, 1000)],  # hair -> flick
		]
	else:
		rig.appear()
	if args.has("shots"):
		for s in str(args.get("at", "1")).split(","):
			_shots.append(float(s))


func _process(delta: float) -> void:
	t += delta
	while _timeline.size() > 0 and t >= float(_timeline[0][0]):
		var ev: Array = _timeline.pop_front()
		match ev[1]:
			"appear":
				rig.appear()
				_say("appear")
			"talk":
				rig.talk(float(ev[2]))
				_say("talk")
			"tap":
				var gp: Vector2 = rig.get_node("Figure/Art").get_global_transform() * (ev[2] as Vector2)
				var e: = InputEventMouseButton.new()
				e.button_index = MOUSE_BUTTON_LEFT
				e.pressed = true
				e.position = gp
				e.global_position = gp
				Input.parse_input_event(e)
				var up: = e.duplicate()
				up.pressed = false
				Input.parse_input_event(up)
				_ripples.append([gp, 0.0])
	for r in _ripples:
		r[1] += delta
	_ripples = _ripples.filter(func(r: Array) -> bool: return r[1] < 0.6)
	_ov.queue_redraw()
	if args.has("perf"):
		_perf.n += 1
		_perf.rig_us += rig.last_update_usec
		_perf.max_rig_us = maxi(_perf.max_rig_us, rig.last_update_usec)
		_perf.frame_ms += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		if _perf.n % 90 == 0:
			_print_perf()
	if args.has("strain") and Engine.get_process_frames() % 6 == 0:
		var st: = rig.measure_strain()
		if st.max > float(_perf.get("strain", 0.0)):
			_perf.strain = st.max
			_perf.strain_at = st.at
			_perf.strain_t = t
		_perf.p99 = maxf(float(_perf.get("p99", 0.0)), st.p99)
		var pt: PackedFloat32Array = st.per_tri
		if not _perf.has("heat"):
			_perf.heat = pt.duplicate()
		var hm: PackedFloat32Array = _perf.heat
		for i in pt.size():
			hm[i] = maxf(hm[i], pt[i])
		_perf.heat = hm
		if args.has("heat") and t > float(args.heat) and not _perf.has("heat_saved"):
			_perf.heat_saved = true
			_save_heat()
		if Engine.get_process_frames() % 90 == 0:
			print("RIG DISP max=%.1f at %s bones=%s" % [st.disp, st.disp_at, st.bones])
			print("RIG STRAIN t=%.1f now max=%.3f p99=%.3f at %s | run worst=%.3f at %s (t=%.1f) worst p99=%.3f tris=%d" % [
				t, st.max, st.p99, st.at, _perf.strain, _perf.strain_at, _perf.strain_t, _perf.p99, st.tris])
	if _shots.size() > 0 and t >= _shots[0]:
		var at: float = _shots.pop_front()
		await RenderingServer.frame_post_draw
		var img: = get_viewport().get_texture().get_image()
		img.save_png(str(args.shots).path_join("rig_%05.2f.png" % at))
		if _shots.is_empty() and not args.has("perf"):
			get_tree().quit()


func _print_perf() -> void:
	var body: Polygon2D = rig.get_node("Figure/Art/Body")
	print("RIG PERF frames=%d verts=%d tris=%d bones=%d rig_update_avg=%.0fus max=%dus process_avg=%.2fms fps=%.1f draw_calls=%d" % [
		_perf.n, body.polygon.size(), body.polygons.size(), body.get_bone_count(), float(_perf.rig_us) / _perf.n,
		_perf.max_rig_us, _perf.frame_ms / _perf.n, Engine.get_frames_per_second(),
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])


func _save_heat() -> void:
	# worst anisotropy per triangle over the run: black 0, red 0.1, yellow 0.25, white >= 0.5 (art space, 1/2 size)
	var img: = Image.create(700, 700, false, Image.FORMAT_RGB8)
	img.fill(Color(0.15, 0.15, 0.2))
	var cs: Array = rig.strain_tris()
	var hm: PackedFloat32Array = _perf.heat
	for i in cs.size():
		var v: = hm[i]
		var c: = Color(clampf(v / 0.1, 0, 1), clampf((v - 0.1) / 0.15, 0, 1), clampf((v - 0.25) / 0.25, 0, 1))
		var p: Vector2 = cs[i] * 0.5
		img.fill_rect(Rect2i(int(p.x) - 3, int(p.y) - 3, 6, 6), c)
	img.save_png(str(args.get("shots", "user://")).path_join("strain_heat.png"))
	print("RIG HEAT saved")


func _say(s: String) -> void:
	_caption.text = s


func _draw_ov() -> void:
	for r in _ripples:
		var k: float = r[1] / 0.6
		_ov.draw_arc(r[0], 18.0 + 46.0 * k, 0, TAU, 40, Color(1, 1, 1, 0.8 * (1.0 - k)), 4.0, true)
