extends Node2D

# Standalone runner for Hana's rig (V10HanaRig): showcase timeline, selftest, screenshots, strain probe.
#   godot --path game res://assets/v10/rig/hana_base/hana_demo.tscn -- <args>
# Args (after --):
#   --selftest=1      checks (bones, patches, gestures, zones vs dead zones, dead-zone taps, 3-tap pout, timing,
#                     strain at every gesture peak) then quits with exit code 0/1 and a HANA_RIG_SELFTEST line
#   --reel=a|b|idle   scripted 20 s showcase: a = bounce, fist pump (tap), lunge, head pat (tap), jog, wink, hip
#                     check (tap), 3-tap pout; b = stretch, hair shake (tap), stopwatch, jacket tug (tap), look (tap),
#                     shy peek, air kiss, talk; idle = autonomous gestures only (default when no reel: interactive)
#   --flirt=N         flirt_level 0..10;  --label=1 caption overlay;  --seed=N
#   --shots=<dir> --at=1.0,2.5   save PNG frames at those seconds;  --quit=<s> quit after s seconds
#   --perf=1          print _process timing every 2 s;  --hide=Layer_sleeveA,BG  hide nodes (debug)
# Layout: the art is scaled from the viewport HEIGHT (0.705 of it), never narrower than 1.1x the width, centred
# on her torso, its bottom edge 12 px under the screen (any portrait aspect: 9:16, 9:19.5, 9:20, 3:4).

const RIG: = preload("res://assets/v10/rig/hana_base/rig.tscn")
const CENTER_X: = 715.0  # art x on the screen centre
const ART_H: = 1400.0

var rig: V10HanaRig
var t: = 0.0
var args: = {}
var _timeline: = []
var _ripples: = []
var _caption: Label
var _ov: Node2D
var _shots: = []
var _perf: = {"n": 0, "us": 0, "max": 0, "next": 2.0}


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv: = a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	RenderingServer.set_default_clear_color(Color(0.29, 0.28, 0.5))
	rig = RIG.instantiate()
	place(rig, get_viewport_rect().size)
	var reel: String = args.get("reel", "")
	if args.has("seed"):
		rig.gesture_seed = int(args.seed)
	elif reel != "":
		rig.gesture_seed = 7
	rig.flirt_level = int(args.get("flirt", "0"))
	if reel == "a" or reel == "b":
		rig.auto_gestures = false
	add_child(rig)
	_ov = Node2D.new()
	add_child(_ov)
	_ov.draw.connect(_draw_ov)
	_caption = Label.new()
	_caption.position = Vector2(24, 24)
	_caption.add_theme_font_size_override("font_size", 22)
	_caption.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	_caption.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	_caption.visible = args.get("label", "0") != "0"
	add_child(_caption)
	rig.gesture_started.connect(func(n: String) -> void: _say("gesture: " + n))
	rig.tapped.connect(func(z: String) -> void: _say("tap: " + z))
	if args.has("selftest"):
		_selftest.call_deferred()
		return
	match reel:
		"a":
			_timeline = [[0.0, "appear"], [0.9, "g", "bounce_toes"], [3.25, "tap", Vector2(1080, 420)],
				[5.6, "g", "lunge_lean"], [8.5, "tap", Vector2(700, 90)], [11.1, "g", "jog_in_place"],
				[13.7, "g", "wink_grin"], [15.5, "tap", Vector2(560, 850)],
				[17.4, "tap", Vector2(1250, 300)], [17.6, "tap", Vector2(1230, 360)], [17.8, "tap", Vector2(1270, 330)]]
		"b":
			_timeline = [[0.0, "appear"], [0.9, "g", "side_stretch"], [4.1, "tap", Vector2(470, 330)],
				[6.5, "g", "stopwatch_glance"], [9.1, "tap", Vector2(340, 1080)], [11.2, "tap", Vector2(160, -40)],
				[13.6, "g", "shy_peek"], [16.5, "g", "air_kiss"], [18.6, "talk", 1.4]]
		_:
			rig.appear()
	if args.has("hide"):
		for n in str(args.hide).split(","):
			var node: Node = rig.get_node_or_null("BG") if n == "BG" else rig.get_node_or_null("Figure/Art/" + n)
			if node:
				node.visible = false
	if args.has("shots"):
		for s in str(args.get("at", "1")).split(","):
			_shots.append(float(s))


static func place(r: Node2D, vs: Vector2) -> void:
	# the layout rule integration should copy (see README «Layout»)
	var k: = maxf(vs.y * 0.705 / ART_H, vs.x * 1.1 / ART_H)
	r.scale = Vector2.ONE * k
	r.position = Vector2(vs.x * 0.5 - CENTER_X * k, vs.y + 12.0 - ART_H * k)


func _process(delta: float) -> void:
	t += delta
	while _timeline.size() > 0 and t >= float(_timeline[0][0]):
		var ev: Array = _timeline.pop_front()
		match ev[1]:
			"appear":
				rig.appear()
			"g":
				rig.gesture(ev[2])
			"talk":
				rig.talk(float(ev[2]))
				_say("talk")
			"tap":
				_tap(ev[2])
	for r in _ripples:
		r[1] += delta
	_ripples = _ripples.filter(func(r: Array) -> bool: return r[1] < 0.6)
	_ov.queue_redraw()
	if args.has("perf"):
		_perf.n += 1
		_perf.us += rig.last_update_usec
		_perf.max = maxi(_perf.max, rig.last_update_usec)
		if t >= _perf.next:
			print("perf: rig _process avg %.0f us, max %d us, fps %.0f" % [float(_perf.us) / _perf.n, _perf.max, Engine.get_frames_per_second()])
			_perf = {"n": 0, "us": 0, "max": 0, "next": t + 2.0}
	if _shots.size() > 0 and t >= _shots[0]:
		var at: float = _shots.pop_front()
		_shot.call_deferred("%s/hana_%05.2f.png" % [args.shots, at])
	if args.has("quit") and t >= float(args.quit):
		get_tree().quit()


func _tap(art_p: Vector2) -> void:
	var gp: Vector2 = rig.get_node("Figure/Art").get_global_transform() * art_p
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


func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("shot ", path)


func _say(s: String) -> void:
	_caption.text = "%.1f  %s" % [t, s]


func _draw_ov() -> void:
	for r in _ripples:
		var x: float = r[1] / 0.6
		_ov.draw_arc(r[0], 14.0 + 40.0 * x, 0.0, TAU, 40, Color(1, 1, 1, 0.75 * (1.0 - x)), 3.0)


# ---------------------------------------------------------------- selftest

func _selftest() -> void:
	var fails: = []
	var checks: = 0
	# 1. skeleton, layers, face
	for b in ["root", "hips", "spine", "chest", "neck", "head", "crown", "hairL1", "hairR1", "armR_up", "armR_lo", "handR",
			"armL_up", "armL_lo", "fistL", "thighL", "thighR", "flapL1", "sleeveA1", "sleeveB1", "pendant", "bust"]:
		checks += 1
		if not rig.bones.has(b):
			fails.append("bone missing " + b)
	for pch in ["eyes_closed", "eyeL_closed", "eyeR_closed", "eyes_happy", "eyes_frown", "eyes_half", "blush", "mouth_closed",
			"mouth_small", "mouth_ah", "mouth_oh", "mouth_pucker", "mouth_pout"]:
		checks += 1
		if not rig.patches.has(pch) or rig.patches[pch].texture == null:
			fails.append("patch missing " + pch)
	checks += 1
	if rig.irises.size() != 2:
		fails.append("irises %d" % rig.irises.size())
	checks += 1
	if rig.layers.size() != 5:
		fails.append("layers %d" % rig.layers.size())
	# 2. every gesture / reaction builds, with known channels only
	var all: Array = rig.HANA_GESTURES + rig.FLIRT_GESTURES + rig.KISS_GESTURES + ["head_pat", "hip_check", "jacket_tug", "look", "pout"]
	for g in all:
		checks += 1
		var d: Dictionary = rig._build(g, 1.0, Vector2(900, 200))
		if d.is_empty() or float(d.get("dur", 0.0)) <= 0.0:
			fails.append("gesture empty " + g)
			continue
		for k in d.tracks:
			var kk: String = rig.ALIAS.get(k, k)
			if not (rig._ci.has(kk) or rig.face.has(kk)):
				fails.append("%s: unknown track %s" % [g, k])
			var tr: Array = d.tracks[k]
			if tr.size() % 2 != 0 or float(tr[tr.size() - 1]) != 0.0 and not k.begins_with("eyes") and k != "blush":
				fails.append("%s: track %s does not end at rest" % [g, k])
		for m in d.get("mouth", []):
			if m[2] != "open" and not rig.MOUTHS.has(m[2]):
				fails.append("%s: mouth %s" % [g, m[2]])
	# 3. tap zones never overlap dead zones
	for z in rig.def.zones:
		if z.begins_with("_"):
			continue
		for dz in rig.def.dead_zones:
			if dz.begins_with("_"):
				continue
			checks += 1
			var inter: = Geometry2D.intersect_polygons(rig._poly(rig.def.zones[z]), rig._poly(rig.def.dead_zones[dz]))
			if inter.size() > 0:
				fails.append("zone %s overlaps dead zone %s" % [z, dz])
	await get_tree().process_frame
	await get_tree().create_timer(0.8).timeout
	# 4. 400 taps inside dead zones: no reaction, nothing started
	var rng: = RandomNumberGenerator.new()
	rng.seed = 5
	var n_before: int = rig.actions.size()
	var dz_hits: = 0
	for i in 400:
		var keys: = ["bust", "hips"]
		var poly: = rig._poly(rig.def.dead_zones[keys[i % 2]])
		var r: = Rect2(poly[0], Vector2.ZERO)
		for q in poly:
			r = r.expand(q)
		var p: = Vector2(rng.randf_range(r.position.x, r.end.x), rng.randf_range(r.position.y, r.end.y))
		if not Geometry2D.is_point_in_polygon(p, poly):
			continue
		dz_hits += 1
		var z: String = rig.tap(rig.art.get_global_transform() * p)
		if z != "none":
			fails.append("dead-zone tap reacted: %s at %s" % [z, p])
			break
	checks += 1
	var reacts: = 0
	for a in rig.actions:
		if a.kind == "react":
			reacts += 1
	if reacts > 0:
		fails.append("dead-zone taps started %d reactions" % reacts)
	# 5. zone taps map to Hana's reactions; 3 quick taps -> pout
	for pair in [["head", Vector2(700, 230), "head_pat"], ["armL", Vector2(1080, 420), "fist_pump"],
			["armR", Vector2(330, 660), "hip_check"], ["hair", Vector2(470, 330), "hair_shake"],
			["outfit", Vector2(330, 1050), "jacket_tug"], ["bg", Vector2(1250, 300), "look"]]:
		checks += 1
		rig._tap_times.clear()
		rig.actions.clear()
		var z2: String = rig.tap(rig.art.get_global_transform() * (pair[1] as Vector2))
		var got: = ""
		for a in rig.actions:
			if a.kind == "react":
				got = a.name
		if z2 != pair[0] or got != pair[2]:
			fails.append("tap %s -> zone %s, reaction %s (want %s)" % [pair[0], z2, got, pair[2]])
	checks += 1
	rig._tap_times.clear()
	rig.actions.clear()
	for i in 3:
		rig.tap(rig.art.get_global_transform() * Vector2(1250, 300 + i * 20))
	var pout: = false
	for a in rig.actions:
		if a.name == "pout":
			pout = true
	if not pout:
		fails.append("3 taps did not pout")
	rig.actions.clear()
	# 6. strain at every gesture's busiest moments (worst over 8 samples per gesture), idle timing
	var worst: = 0.0
	var worst_at: = ""
	rig.auto_gestures = false
	for g in all:
		if g == "look" or g == "pout":
			continue
		rig.actions.clear()
		if rig._build(g, 1.0, Vector2.ZERO).get("kind", "") == "react":
			rig._react_kind(g, Vector2(900, 200))
		else:
			rig.gesture(g)
		var dur: float = rig.actions[rig.actions.size() - 1].dur
		var tt: = 0.0
		var step: = dur / 8.0
		while tt < dur:
			await get_tree().create_timer(step).timeout
			tt += step
			var m: Dictionary = rig.measure_strain()
			if m.max > worst:
				worst = m.max
				worst_at = "%s @%.2f s (%s, art %s)" % [g, tt, m.layer, m.at]
	checks += 1
	if worst > 0.6:
		fails.append("strain %.2f at %s" % [worst, worst_at])
	var us: = 0
	var n: = 0
	for i in 60:
		await get_tree().process_frame
		us += rig.last_update_usec
		n += 1
	print("HANA_RIG strain worst %.3f at %s" % [worst, worst_at])
	print("HANA_RIG _process avg %.0f us over %d frames (software GL box)" % [float(us) / n, n])
	print("HANA_RIG dead-zone taps tested %d" % dz_hits)
	for f in fails:
		print("FAIL ", f)
	print("HANA_RIG_SELFTEST %s %d/%d" % ["PASS" if fails.is_empty() else "FAIL", checks - fails.size(), checks])
	get_tree().quit(0 if fails.is_empty() else 1)
