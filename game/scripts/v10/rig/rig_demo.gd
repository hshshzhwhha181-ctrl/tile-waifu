extends Node2D

# Demo for V10LiveRig (scenes/v10/rig_demo.tscn). Shows Маджонг-тян in her evening gown: idle with autonomous
# flirty gestures, then a scripted run of taps so a movie capture shows every reaction:
#   godot --path game res://scenes/v10/rig_demo.tscn --write-movie out.avi --fixed-fps 30 --quit-after 700
# User args (after --):
#   --script=0        no scripted taps (tap her yourself; gestures at the normal 4-8 s cadence)
#   --label=1         debug caption overlay (off by default, so recordings are clean)
#   --gap=2.4,2.9     autonomous gesture cadence for the scripted idle part (default 2.5,2.9 so ~4 show in 11 s)
#   --seed=N          gesture RNG seed (default 13 when scripted: hip pop, hair touch, air kiss, knee-in, lean-in)
#   --perf=1          print timings;  --strain=1 strain probe (--heat=<s> saves strain_heat.png at that time)
#   --shots=<dir> --at=1.0,2.5   save PNG frames at those seconds

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
var _log: = []


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv: = a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var scripted: bool = args.get("script", "1") != "0"
	var vs: = get_viewport_rect().size
	rig = RIG.instantiate()
	rig.scale = Vector2.ONE * ART_SCALE
	rig.position = Vector2(vs.x * 0.5 - CENTER_X * ART_SCALE, BOTTOM - 1400.0 * ART_SCALE)
	if scripted:
		rig.gesture_seed = int(args.get("seed", "13"))
		var g: PackedStringArray = str(args.get("gap", "2.4,2.7")).split(",")
		rig.gesture_gap = Vector2(float(g[0]), float(g[1]))
	elif args.has("seed"):
		rig.gesture_seed = int(args.seed)
	add_child(rig)
	if scripted:
		rig._next_gesture = float(args.get("first", "1.5"))  # first autonomous gesture soon after the entrance
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
	if scripted:
		# seconds, action, art-space point (taps are real input events at her screen position)
		_timeline = [
			[0.0, "appear"],
			[12.9, "tap", Vector2(700, 120)],  # head -> nuzzle, ^^, bounce
			[15.6, "tap", Vector2(1250, 330)],  # 3 quick taps on the room -> pout, then giggle
			[15.8, "tap", Vector2(1230, 380)],
			[16.0, "tap", Vector2(1260, 350)],
			[19.0, "tap", Vector2(140, -60)],  # room, upper left -> eyes and head follow
			[21.0, "tap", Vector2(620, 880)],  # hand on hip -> wag
			[22.8, "talk", 2.4],
			[12.8, "gestures_off"],
		]
		_timeline.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	else:
		rig.appear()
	if args.has("hide"):
		# dev: --hide=Layer_tailL,BG hides rig layers to find where an artefact lives
		for n in str(args.hide).split(","):
			var node: Node = rig.get_node_or_null("Figure/Art/" + n) if n != "BG" else rig.get_node_or_null("BG")
			if node:
				node.visible = false
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
			"gestures_off":
				rig.auto_gestures = false
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
		var st: = rig.measure_strain()
		if st.max > float(_perf.get("strain", 0.0)):
			_perf.strain = st.max
			_perf.strain_at = st.at
			_perf.strain_t = t
			_perf.strain_layer = st.layer
		# split by phase: idle gestures before the first scripted tap, reactions after it
		var ph: = "react" if t >= float(args.get("react_from", "12.9")) else "idle"
		if st.max > float(_perf.get(ph + "_max", 0.0)):
			_perf[ph + "_max"] = st.max
			_perf[ph + "_at"] = "%s@(%d,%d)t%.1f" % [st.layer, st.at.x, st.at.y, t]
		_perf[ph + "_p999"] = maxf(float(_perf.get(ph + "_p999", 0.0)), st.p999)
		_perf[ph + "_p99"] = maxf(float(_perf.get(ph + "_p99", 0.0)), st.p99)
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
			# the 25 worst triangles right now (dev: find what tears)
			var cs: Array = rig.strain_tris()
			var idx: = range(pt.size())
			idx.sort_custom(func(a: int, b: int) -> bool: return pt[a] > pt[b])
			var s: = PackedStringArray()
			for i in idx.slice(0, 25):
				s.append("%.2f@(%d,%d)" % [pt[i], cs[i].x, cs[i].y])
			print("RIG DUMP t=%.2f " % t, " ".join(s))
			for bn in ["hips", "spine", "chest", "bust", "neck", "head"]:
				var b: Bone2D = rig.bones[bn]
				print("  bone %s pos=%s rot=%.2f scale=%s" % [bn, b.position - rig.rest[bn], rad_to_deg(b.rotation), b.scale])
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
			print("RIG STRAIN t=%.1f now max=%.3f (%s) p99=%.3f p99.9=%.3f | run worst=%.3f at %s in %s (t=%.1f) worst p99=%.3f p99.9=%.3f disp=%.1f tris=%d per_layer=%s" % [
				t, st.max, st.layer, st.p99, st.p999, _perf.strain, _perf.strain_at, _perf.strain_layer, _perf.strain_t,
				_perf.p99, _perf.p999, st.disp, st.tris, _fmt_layers(pl)])
			print("RIG PHASE idle: max=%.3f %s p99.9=%.3f p99=%.3f | reactions: max=%.3f %s p99.9=%.3f p99=%.3f" % [
				float(_perf.get("idle_max", 0.0)), _perf.get("idle_at", ""), float(_perf.get("idle_p999", 0.0)), float(_perf.get("idle_p99", 0.0)),
				float(_perf.get("react_max", 0.0)), _perf.get("react_at", ""), float(_perf.get("react_p999", 0.0)), float(_perf.get("react_p99", 0.0))])
	if _shots.size() > 0 and t >= _shots[0]:
		var at: float = _shots.pop_front()
		await RenderingServer.frame_post_draw
		var img: = get_viewport().get_texture().get_image()
		img.save_png(str(args.shots).path_join("rig_%05.2f.png" % at))
		if _shots.is_empty() and not args.has("perf") and not args.has("strain"):
			get_tree().quit()


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
		_perf.n, verts, tris, float(_perf.rig_us) / _perf.n,
		_perf.max_rig_us, _perf.frame_ms / _perf.n, Engine.get_frames_per_second(),
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])


func _save_heat() -> void:
	# worst anisotropy per triangle over the run: black 0, red 0.1, yellow 0.25, white >= 0.5 (art space, 1/2 size)
	var img: = Image.create(700, 700, false, Image.FORMAT_RGB8)
	img.fill(Color(0.15, 0.15, 0.2))
	var cs: Array = rig.strain_tris()
	var hm: PackedFloat32Array = _perf.heat
	var order: = range(cs.size())
	order.sort_custom(func(a: int, b: int) -> bool: return hm[a] < hm[b])  # overlapping layers: worst on top
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
