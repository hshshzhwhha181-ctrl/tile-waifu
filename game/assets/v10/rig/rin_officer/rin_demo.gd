extends Node2D

# Standalone runner for Rin's rig (rin_demo.tscn). Shows her in the tea library: entrance, her own gestures, then
# real tap events on her zones, so a movie capture shows every action. Fits any screen (portrait phones 9:16 to
# 9:21 and 3:4 tablets): the figure scales to the height, the background always covers the screen.
#   godot --path game res://assets/v10/rig/rin_officer/rin_demo.tscn --write-movie out.avi --fixed-fps 30 --quit-after 600
# User args (after --):
#   --script=0        no timeline (tap her yourself; autonomous gestures every 5-9 s)
#   --selftest=1      play every gesture and reaction once, measure strain all the way, print RIN SELFTEST PASS/FAIL, quit
#   --label=1         debug caption;  --seed=N  gesture RNG seed
#   --perf=1          timings;  --strain=1 strain probe (--heat=<s> saves strain_heat.png into --shots)
#   --shots=<dir> --at=1.0,2.5   save PNG frames at those seconds
#   --gesture=<name>  start with this gesture at 1.2 s (QA stills)

const RIG: = preload("res://assets/v10/rig/rin_officer/rig.tscn")
const BASE_SCALE: = 0.72  # art px -> screen px on the 720x1280 base viewport (mc_gown demo: 0.645; Rin is slimmer in the frame)
const CENTER_X: = 725.0  # art x of her centre line
const ART: = 1400.0
const BG_TOP: = -615.0  # the background plate reaches this far above the art (art px)
const STRAIN_LIMIT: = 0.2

var rig: V10LiveRig
var t: = 0.0
var args: = {}
var _timeline: = []
var _ripples: = []
var _caption: Label
var _ov: Node2D
var _perf: = {"n": 0, "rig_us": 0, "frame_ms": 0.0, "max_rig_us": 0}
var _shots: = []
var _log: = []
var _end: = -1.0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv: = a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var selftest: bool = args.get("selftest", "0") != "0"
	var scripted: bool = args.get("script", "1") != "0" or selftest
	rig = RIG.instantiate()
	rig.gesture_seed = int(args.get("seed", "7"))
	add_child(rig)
	_fit()
	get_viewport().size_changed.connect(_fit)
	rig.tapped.connect(func(z: String) -> void: _say("tap: " + z))
	rig.gesture_started.connect(func(n: String) -> void:
		_say("gesture: " + n)
		_log.append("%.2f %s" % [t, n]))
	_ov = Node2D.new()
	add_child(_ov)
	_ov.draw.connect(_draw_ov)
	_caption = Label.new()
	_caption.position = Vector2(24, 24)
	_caption.add_theme_font_size_override("font_size", 22)
	_caption.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	_caption.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	_caption.visible = args.get("label", "0") != "0"
	add_child(_caption)
	if selftest:
		rig.auto_gestures = false
		var x: = 1.0
		_timeline = [[0.0, "appear"]]
		for g in ["over_glasses", "adjust_glasses", "fan_hide", "smirk", "settle", "ponder"]:
			_timeline.append([x, "gesture", g])
			x += 4.0
		for z in [["tap", Vector2(720, 110)], ["tap", Vector2(470, 700)], ["tap", Vector2(960, 1180)], ["tap", Vector2(960, 640)],
				["tap", Vector2(1250, 300)], ["tap", Vector2(780, 800)]]:
			_timeline.append([x, z[0], z[1]])
			x += 3.4
		for k in 3:
			_timeline.append([x + k * 0.2, "tap", Vector2(1220 + 20 * k, 360)])
		x += 3.6
		_timeline.append([x, "talk", 2.0])
		_end = x + 2.6
		args["strain"] = "1"
	elif scripted:
		rig.auto_gestures = false
		# the 20 s showcase: her gestures, then real taps (head pat, gloved hand, braid), talk, a 3-tap huff
		_timeline = [
			[0.0, "appear"],
			[1.2, "gesture", args.get("gesture", "over_glasses")],
			[5.0, "gesture", "fan_hide"],
			[8.6, "tap", Vector2(720, 110)],  # head -> pat
			[11.5, "tap", Vector2(960, 1180)],  # gloved hand -> adjust_glasses (glint)
			[15.0, "tap", Vector2(960, 640)],  # braid -> braid_flick
			[16.2, "talk", 1.2],
			[17.4, "tap", Vector2(1250, 330)],  # three quick taps on the room -> huff, stern look over the glasses
			[17.6, "tap", Vector2(1230, 380)],
			[17.8, "tap", Vector2(1260, 350)],
		]
	else:
		rig.appear()
	_timeline.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	if args.has("shots"):
		for s in str(args.get("at", "1")).split(","):
			_shots.append(float(s))


func _fit() -> void:
	# scale to the height (the 720x1280 layout), but never so small that the background leaves a gap at the sides
	var vs: = get_viewport_rect().size
	var k: = maxf(BASE_SCALE * vs.y / 1280.0, vs.x / ART * 1.02)
	k = maxf(k, (vs.y + 12.0) / (ART - BG_TOP))
	var x0: = clampf(vs.x * 0.5 - CENTER_X * k, vs.x - ART * k, 0.0)
	rig.scale = Vector2.ONE * k
	rig.position = Vector2(x0, vs.y + 12.0 - ART * k)


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
			"gesture":
				rig.gesture(str(ev[2]))
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
				_log.append("%.2f tap %s" % [t, ev[2]])
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
	if args.has("strain") and Engine.get_process_frames() % 3 == 0:
		_probe()
	if _end > 0.0 and t >= _end:
		_end = -1.0
		var ok: = float(_perf.get("strain", 0.0)) < STRAIN_LIMIT
		print("RIN SELFTEST %s worst=%.3f at %s in %s (t=%.1f) p99.9=%.3f p99=%.3f actions=%s" % [
			"PASS" if ok else "FAIL", float(_perf.get("strain", 0.0)), _perf.get("strain_at", Vector2.ZERO),
			_perf.get("strain_layer", ""), float(_perf.get("strain_t", 0.0)), float(_perf.get("p999", 0.0)),
			float(_perf.get("p99", 0.0)), " | ".join(PackedStringArray(_log))])
		print("RIN SELFTEST per_layer ", _fmt_layers(_perf.get("per_layer", {})))
		if args.has("heat") and not _perf.has("heat_saved"):
			_save_heat()
		get_tree().quit(0 if ok else 1)
	if _shots.size() > 0 and t >= _shots[0]:
		var at: float = _shots.pop_front()
		await RenderingServer.frame_post_draw
		var img: = get_viewport().get_texture().get_image()
		img.save_png(str(args.shots).path_join("rin_%05.2f.png" % at))
		if _shots.is_empty() and not args.has("perf") and not args.has("strain"):
			get_tree().quit()


func _probe() -> void:
	var st: = rig.measure_strain()
	if st.max > float(_perf.get("strain", 0.0)):
		_perf.strain = st.max
		_perf.strain_at = st.at
		_perf.strain_t = t
		_perf.strain_layer = st.layer
	_perf.p99 = maxf(float(_perf.get("p99", 0.0)), st.p99)
	_perf.p999 = maxf(float(_perf.get("p999", 0.0)), st.p999)
	var pl: Dictionary = _perf.get("per_layer", {})
	for k in st.per_layer:
		var cur: Array = st.per_layer[k]
		if not pl.has(k) or float(cur[0]) > float(pl[k][0]):
			pl[k] = [cur[0], cur[1], t]
	_perf.per_layer = pl
	var pt: PackedFloat32Array = st.per_tri
	if args.has("dump") and absf(t - float(args.dump)) < 0.06:
		var cs: Array = rig.strain_tris()
		var idx: = range(pt.size())
		idx.sort_custom(func(a: int, b: int) -> bool: return pt[a] > pt[b])
		var s: = PackedStringArray()
		for i in idx.slice(0, 25):
			s.append("%.2f@(%d,%d)" % [pt[i], cs[i].x, cs[i].y])
		print("RIG DUMP t=%.2f " % t, " ".join(s))
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
		print("RIG STRAIN t=%.1f now=%.3f (%s) | run worst=%.3f at %s in %s (t=%.1f) p99.9=%.3f p99=%.3f disp=%.1f" % [
			t, st.max, st.layer, _perf.strain, _perf.strain_at, _perf.strain_layer, _perf.strain_t, _perf.p999, _perf.p99, st.disp])


func _exit_tree() -> void:
	if _log.size() > 0:
		print("RIG LOG ", " | ".join(PackedStringArray(_log)))


static func _fmt_layers(pl: Dictionary) -> String:
	var parts: = PackedStringArray()
	for k in pl:
		parts.append("%s:%.3f@(%d,%d)t%.1f" % [k, pl[k][0], pl[k][1].x, pl[k][1].y, pl[k][2]])
	return " ".join(parts)


func _print_perf() -> void:
	var verts: = 0
	var tris: = 0
	for c in rig.get_node("Figure/Art").get_children():
		if c is Polygon2D:
			verts += c.polygon.size()
			tris += c.polygons.size()
	print("RIG PERF frames=%d verts=%d tris=%d rig_update_avg=%.0fus max=%dus process_avg=%.2fms fps=%.1f draw_calls=%d" % [
		_perf.n, verts, tris, float(_perf.rig_us) / _perf.n, _perf.max_rig_us, _perf.frame_ms / _perf.n,
		Engine.get_frames_per_second(), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])


func _save_heat() -> void:
	# worst anisotropy per triangle over the run: black 0, red 0.1, yellow 0.25, white >= 0.5 (art space, 1/2 size)
	var img: = Image.create(700, 700, false, Image.FORMAT_RGB8)
	img.fill(Color(0.15, 0.15, 0.2))
	var cs: Array = rig.strain_tris()
	var hm: PackedFloat32Array = _perf.heat
	var order: = range(cs.size())
	order.sort_custom(func(a: int, b: int) -> bool: return hm[a] < hm[b])
	for i in order:
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
