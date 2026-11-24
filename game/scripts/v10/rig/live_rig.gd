class_name V10LiveRig
extends Node2D

# 0.10 «living illustration»: one finished illustration, cut out and skinned to a Skeleton2D, moved by procedural
# layered motion (breathing, weight shift, head drift), spring chains (twin tails, skirt, tassels), two IK pins
# (hand on hip, hand behind head), face patches (blink, wink, 3 mouth shapes, blush) and tap reactions.
# Nothing is generated at runtime: every frame is the same painting, only warped by bones. See README.md here.
#
#   var rig: V10LiveRig = load("res://assets/v10/rig/mc_gown/rig.tscn").instantiate()
#   add_child(rig); rig.position = ...; rig.scale = Vector2.ONE * k   # local units are pixels of body.png
#   rig.appear()                     0.6 s pop with overshoot
#   rig.react("head"|"armL"|"armR"|"hair"|"outfit"|"bg", at_global)   or rig.tap(global_pos) (zone lookup)
#   rig.talk(seconds) / rig.set_talking(on) / rig.set_mouth_level(0..1)   lip-sync (3 mouth shapes)
#   rig.blink() / rig.wink(left)
# Signals: tapped(zone) after a tap was classified («none» = dead zone or nothing there).
# The scene (rig.tscn) is built by tools/build_rig.py from rig_def.json; this script reads the same json.

signal tapped(zone: String)

@export_file("*.json") var def_path: = ""
@export var show_background: = true
@export var handle_input: = true
@export var idle_mouth: = "closed"  # closed | small | open (open = the painted mouth)
@export var motion: = 1.0  # global amplitude of the idle body motion
@export var parallax: = 0.35  # background moves this fraction of the figure's drift (0 = glued)

const TAU_: = TAU
const SUBSTEP: = 1.0 / 120.0

var def: = {}
var figure: Node2D
var art: Node2D
var skel: Skeleton2D
var body: Polygon2D
var bg: Sprite2D
var bones: = {}  # name -> Bone2D
var rest: = {}  # name -> Vector2 (local rest position)
var art_pos: = {}  # name -> Vector2 (art px of the joint)
var patches: = {}  # name -> Sprite2D
var chains: = []  # [{cfg, bones: [{bone, dir, len, x, v}]}]
var jiggles: = []
var iks: = []
var bg_base: = Vector2.ZERO
var t: = 0.0
var _acc: = 0.0
var rng: = RandomNumberGenerator.new()
var _seed: = Vector4.ZERO

# breathing
var breath_phase: = 0.0
var breath: = 0.0  # 0..1
var sigh: = 0.0  # extra deep breath envelope
var _next_sigh: = 14.0

# face
var _blink_in: = 2.0
var _blink_t: = -1.0
var _blink_double: = false
var eye_extra: = 0.0  # held closed (happy) 0..1
var wink_l: = 0.0
var wink_r: = 0.0
var blush: = 0.0
var mouth_state: = "closed"
var _mouth_a: = {"mouth_closed": 1.0, "mouth_small": 0.0}
var _talk_left: = 0.0
var _talking: = false
var _syll_in: = 0.0
var _talk_env: = 0.0
var _ext_level: = -1.0

# reactions: each is {kind, t, dur, side, ...}
var reactions: = []
var _figure_base_pos: = Vector2.ZERO
var _appear_tw: Tween

# performance probe
var last_update_usec: = 0


func _ready() -> void:
	rng.randomize()
	_seed = Vector4(rng.randf() * 10.0, rng.randf() * 10.0, rng.randf() * 10.0, rng.randf() * 10.0)
	def = JSON.parse_string(FileAccess.get_file_as_string(def_path))
	figure = $Figure
	art = $Figure/Art
	skel = $Figure/Art/Skeleton
	body = $Figure/Art/Body
	_figure_base_pos = figure.position
	_collect_bones(skel)
	_setup_face()
	_setup_dynamics()
	if show_background:
		_setup_bg()
	mouth_state = idle_mouth
	_blink_in = rng.randf_range(1.2, 3.0)


func _collect_bones(n: Node) -> void:
	for c in n.get_children():
		if c is Bone2D:
			bones[c.name] = c
			rest[c.name] = c.position
			_collect_bones(c)
	for b in def.bones:
		art_pos[b.name] = Vector2(b.pos[0], b.pos[1])


func _tex(file: String) -> Texture2D:
	return load(def_path.get_base_dir().path_join(file))


func _setup_face() -> void:
	var f: Dictionary = def.face
	var head: Bone2D = bones[f.bone]
	for k in f.patches:
		var p: Dictionary = f.patches[k]
		var s: = Sprite2D.new()
		s.name = k
		s.texture = _tex(p.file)
		s.centered = false
		s.position = Vector2(p.pos[0], p.pos[1]) - art_pos[f.bone]
		s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		s.modulate.a = 0.0
		head.add_child(s)
		patches[k] = s
	# draw order inside the head: blush under the eye patches, mouths last
	for k in ["blush", "eyes_closed", "eyeL_closed", "eyeR_closed", "mouth_small", "mouth_closed"]:
		if patches.has(k):
			head.move_child(patches[k], -1)


func _setup_bg() -> void:
	var l: Dictionary = def.layout
	bg = Sprite2D.new()
	bg.name = "BG"
	bg.texture = _tex("bg.png")
	bg.centered = false
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	bg_base = Vector2(l.bg_origin[0], l.bg_origin[1])
	bg.position = bg_base
	bg.scale = Vector2.ONE * float(l.bg_scale)
	add_child(bg)
	move_child(bg, 0)


func _dir_of(name: String) -> Vector2:
	# rest direction of a bone: towards its first child bone, else towards its "end"
	var b: Bone2D = bones[name]
	for c in b.get_children():
		if c is Bone2D:
			return c.position
	for d in def.bones:
		if d.name == name and d.has("end"):
			return Vector2(d.end[0], d.end[1]) - art_pos[name]
	return Vector2(0, 40)


func _setup_dynamics() -> void:
	for k in def.dynamics:
		if k.begins_with("_"):
			continue
		var cfg: Dictionary = def.dynamics[k]
		var list: = []
		for n in cfg.bones:
			var d: = _dir_of(n)
			list.append({"bone": bones[n], "dir": d.normalized(), "len": d.length(), "x": Vector2.ZERO, "v": Vector2.ZERO, "init": false})
		chains.append({"name": k, "cfg": cfg, "bones": list})
	for k in def.get("jiggle", {}):
		if k.begins_with("_"):
			continue
		jiggles.append({"bone": bones[k], "cfg": def.jiggle[k], "x": Vector2.ZERO, "v": Vector2.ZERO, "init": false})
	for k in def.get("ik", {}):
		if k.begins_with("_"):
			continue
		var c: Dictionary = def.ik[k]
		var up: Bone2D = bones[c.upper]
		var lo: Bone2D = bones[c.lower]
		var end_art: = Vector2(c.end[0], c.end[1])
		var e_local: Vector2 = end_art - art_pos[c.lower]
		var s_art: Vector2 = art_pos[c.upper]
		var el_art: Vector2 = art_pos[c.lower]
		var bend: = signf((el_art - s_art).cross(end_art - el_art))
		iks.append({"name": k, "up": up, "lo": lo, "end_local": e_local, "anchor": bones[c.anchor],
				"anchor_local": end_art - art_pos[c.anchor], "bend": bend, "w": float(c.get("weight", 1.0)), "offset": Vector2.ZERO})


# ---------------------------------------------------------------- motion helpers

func _n(periods: Array, phase: float) -> float:
	# layered sines at incommensurate periods, normalised to about -1..1
	var s: = 0.0
	var w: = 0.0
	var i: = 0
	for p in periods:
		var a: = 1.0 / (1.0 + i * 0.6)
		s += sin(TAU_ * t / float(p) + phase * (1.0 + i * 1.37)) * a
		w += a
		i += 1
	return s / w


static func _ease(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


static func _env(x: float, a: float, h: float, r: float) -> float:
	# attack / hold / release envelope with smooth ends (x in seconds)
	if x < 0.0:
		return 0.0
	if x < a:
		return _ease(x / a)
	if x < a + h:
		return 1.0
	return 1.0 - _ease((x - a - h) / r)


# ---------------------------------------------------------------- frame

func _process(delta: float) -> void:
	var t0: = Time.get_ticks_usec()
	delta = minf(delta, 0.1)
	t += delta
	_update_breath(delta)
	_update_reactions(delta)
	_pose_body()
	_solve_ik()
	_acc += delta
	var steps: = 0
	while _acc >= SUBSTEP and steps < 12:
		_simulate(SUBSTEP)
		_acc -= SUBSTEP
		steps += 1
	if steps == 12:
		_acc = 0.0
	_update_face(delta)
	last_update_usec = Time.get_ticks_usec() - t0


func _update_breath(delta: float) -> void:
	var period: = 4.0 + 0.45 * sin(TAU_ * t / 17.3 + _seed.x)
	breath_phase += delta * TAU_ / period
	# inhale a little quicker than exhale: skew the phase
	var ph: = fposmod(breath_phase, TAU_)
	var sk: = ph + 0.25 * sin(ph)
	breath = 0.5 - 0.5 * cos(sk)
	_next_sigh -= delta
	if _next_sigh <= 0.0:
		_next_sigh = rng.randf_range(16.0, 26.0)
		reactions.append({"kind": "sigh", "t": 0.0, "dur": 5.0})


func _pose_body() -> void:
	var m: = motion
	var R: Dictionary = _reaction_pose()
	var sway: = _n([7.3, 11.9, 19.7], _seed.x) * m + float(R.get("sway", 0.0))
	var drift: = _n([9.7, 14.3], _seed.y)
	var b: = breath + sigh * 0.8
	# camera drift: the figure floats a few px, the background follows at a fraction (parallax)
	var cam: Vector2 = Vector2(drift * 7.0, _n([12.1, 8.3], _seed.z) * 2.5) * m + (R.get("cam", Vector2.ZERO) as Vector2)
	figure.position = _figure_base_pos + cam
	if bg:
		bg.position = bg_base + cam * parallax + (R.get("bgcam", Vector2.ZERO) as Vector2)
	_pose("hips", Vector2(sway * 5.0, -absf(sway) * 1.2 - b * 0.6), deg_to_rad(-0.55 * sway))
	_pose("spine", Vector2.ZERO, deg_to_rad(0.5 * sway + float(R.get("spine", 0.0))) + deg_to_rad(-0.2 * b))
	var chest: Bone2D = bones["chest"]
	chest.position = rest["chest"] + Vector2(0, -b * 4.2 - float(R.get("shrug", 0.0)))
	chest.rotation = deg_to_rad(0.18 * sway + 0.25 * _n([6.1, 9.4], _seed.w) * m)
	chest.scale = Vector2(1.0 + 0.005 * b, 1.0 + 0.011 * b)
	var head_drift: = _n([5.3, 8.9, 13.7], _seed.z) * m
	var nod: = _n([6.7, 10.3], _seed.w + 2.0) * m
	_pose("neck", Vector2.ZERO, deg_to_rad(-0.25 * sway + 0.3 * head_drift))
	var head: Bone2D = bones["head"]
	head.rotation = deg_to_rad(1.1 * head_drift - 0.3 * sway + float(R.get("head", 0.0)))
	head.position = rest["head"] + Vector2(head_drift * 1.2 + float(R.get("head_x", 0.0)), nod * 1.0 + b * 0.6 + float(R.get("head_y", 0.0)))
	# idle arm life (IK keeps the hands planted; these feed the elbows)
	_pose("armL_up", Vector2.ZERO, deg_to_rad(-0.6 * b + float(R.get("armL", 0.0))))
	_pose("armL_lo", Vector2.ZERO, 0.0)
	_pose("armR_up", Vector2.ZERO, deg_to_rad(0.4 * b))
	_pose("armR_lo", Vector2.ZERO, 0.0)
	_pose("handR", Vector2.ZERO, deg_to_rad(float(R.get("handR", 0.0))))
	for ik in iks:
		ik.offset = R.get("ik_" + str(ik.name), Vector2.ZERO)


func _pose(n: String, off: Vector2, rot: float) -> void:
	var b: Bone2D = bones[n]
	b.position = rest[n] + off
	b.rotation = rot


# ---------------------------------------------------------------- IK

func _solve_ik() -> void:
	for ik in iks:
		var up: Bone2D = ik.up
		var lo: Bone2D = ik.lo
		var anchor: Bone2D = ik.anchor
		var target: Vector2 = anchor.global_transform * (ik.anchor_local + ik.offset)
		var S: = up.global_position
		var E: = lo.global_position
		var H: Vector2 = lo.global_transform * ik.end_local
		var a: = (E - S).length()
		var bl: = (H - E).length()
		var ST: = target - S
		var d: = clampf(ST.length(), absf(a - bl) + 0.01, a + bl - 0.01)
		var cos_a: = clampf((a * a + d * d - bl * bl) / (2.0 * a * d), -1.0, 1.0)
		var ang: = acos(cos_a)
		var base: = ST.angle()
		var e1: = S + Vector2.from_angle(base + ang) * a
		var e2: = S + Vector2.from_angle(base - ang) * a
		var want: = e1 if signf((e1 - S).cross(target - e1)) == ik.bend else e2
		var d1: float = (E - S).angle_to(want - S) * ik.w
		up.rotation += d1
		var E2: = lo.global_position
		var H2: Vector2 = lo.global_transform * ik.end_local
		lo.rotation += (H2 - E2).angle_to(target - E2) * ik.w


# ---------------------------------------------------------------- springs

func _simulate(h: float) -> void:
	# Springs live in art space (body.png px): the figure's own drift and the entrance pop do not kick them,
	# only the bones' motion does (plus explicit impulses).
	var to_art: = art.get_global_transform().affine_inverse()
	var art_rot: = art.get_global_transform().get_rotation()
	for ch in chains:
		var cfg: Dictionary = ch.cfg
		var k: = float(cfg.k)
		var damp: = float(cfg.damp)
		var amount: = float(cfg.amount)
		var mx: = deg_to_rad(float(cfg.max))
		var breeze: = deg_to_rad(float(cfg.breeze)) * motion
		var root_amount: = float(cfg.get("root_amount", 1.0))
		var i: = 0
		for e in ch.bones:
			var b: Bone2D = e.bone
			var parent: Node2D = b.get_parent()
			var prot: = parent.global_rotation - art_rot
			var r0: = 0.0
			if i == 0:
				r0 = -float(cfg.gravity) * prot
			r0 += breeze * (0.6 * sin(TAU_ * t / 3.7 - i * 0.8 + _seed.x + ch.name.length()) + 0.4 * sin(TAU_ * t / 6.1 - i * 1.3 + _seed.y))
			# impulses only move the spring's target, so the bone eases into them (no snap)
			var imp: = float(_impulse_rot.get(ch.name, 0.0)) * (0.5 if i == 0 else 1.0)
			b.rotation = r0
			var P: = to_art * b.global_position
			var dir_g: Vector2 = e.dir.rotated(prot + r0)
			var L: float = e.len
			var T: = P + dir_g.rotated(imp) * L
			if not e.init:
				e.x = T
				e.v = Vector2.ZERO
				e.init = true
			var v: Vector2 = e.v + (k * (T - e.x) - damp * e.v) * h
			var x: Vector2 = e.x + v * h
			x = P + (x - P).normalized() * L
			e.v = v
			e.x = x
			var off: = clampf(dir_g.angle_to(x - P) * amount * (root_amount if i == 0 else 1.0), -mx, mx)
			b.rotation = r0 + off
			i += 1
	for j in jiggles:
		var b: Bone2D = j.bone
		var parent: Node2D = b.get_parent()
		var cfg: Dictionary = j.cfg
		b.position = rest[b.name]
		var pa: = to_art * parent.global_transform
		var T: Vector2 = pa * rest[b.name]
		if not j.init:
			j.x = T
			j.init = true
		var v: Vector2 = j.v + (float(cfg.k) * (T - j.x) - float(cfg.damp) * j.v) * h
		j.v = v
		j.x = j.x + v * h
		var off: Vector2 = pa.basis_xform_inv(j.x - T) * float(cfg.amount)
		b.position = rest[b.name] + off.limit_length(float(cfg.max))


var _impulse_rot: = {}


# ---------------------------------------------------------------- face

func _update_face(delta: float) -> void:
	# blink: 2.5..5 s apart, sometimes double; closes in ~90 ms, opens in ~110 ms
	_blink_in -= delta
	if _blink_in <= 0.0 and _blink_t < 0.0:
		_blink_t = 0.0
		_blink_double = rng.randf() < 0.22
		_blink_in = rng.randf_range(2.5, 5.0)
	var blink_a: = 0.0
	if _blink_t >= 0.0:
		_blink_t += delta
		blink_a = _blink_curve(_blink_t)
		if _blink_double:
			blink_a = maxf(blink_a, _blink_curve(_blink_t - 0.26))
		if _blink_t > (0.52 if _blink_double else 0.26):
			_blink_t = -1.0
	var both: = maxf(blink_a, eye_extra)
	_alpha("eyes_closed", both)
	_alpha("eyeL_closed", wink_l * (1.0 - both))
	_alpha("eyeR_closed", wink_r * (1.0 - both))
	_alpha("blush", blush * 0.6)
	# mouth
	_update_talk(delta)
	var tgt_c: = 1.0 if mouth_state == "closed" else 0.0
	var tgt_s: = 1.0 if mouth_state == "small" else 0.0
	var f: = 1.0 - exp(-delta / 0.035)
	_mouth_a.mouth_closed = lerpf(_mouth_a.mouth_closed, tgt_c, f)
	_mouth_a.mouth_small = lerpf(_mouth_a.mouth_small, tgt_s, f)
	_alpha("mouth_closed", _mouth_a.mouth_closed)
	_alpha("mouth_small", _mouth_a.mouth_small)


static func _blink_curve(x: float) -> float:
	if x < 0.0:
		return 0.0
	if x < 0.09:
		return _ease(x / 0.09)
	if x < 0.13:
		return 1.0
	return 1.0 - _ease((x - 0.13) / 0.11)


func _alpha(k: String, a: float) -> void:
	if patches.has(k):
		patches[k].modulate.a = clampf(a, 0.0, 1.0)
		patches[k].visible = a > 0.002


func _update_talk(delta: float) -> void:
	if _ext_level >= 0.0:
		mouth_state = "closed" if _ext_level < 0.15 else ("small" if _ext_level < 0.5 else "open")
		return
	var on: = _talking or _talk_left > 0.0
	_talk_left = maxf(0.0, _talk_left - delta)
	_talk_env = move_toward(_talk_env, 1.0 if on else 0.0, delta * 6.0)
	if not on:
		if _syll_in > -1.0:
			_syll_in = -1.0
			mouth_state = _rest_mouth()
		return
	_syll_in -= delta
	if _syll_in <= 0.0:
		var r: = rng.randf()
		var nxt: = "open" if r < 0.42 else ("small" if r < 0.84 else "closed")
		if nxt == mouth_state:
			nxt = "small" if mouth_state != "small" else "open"
		mouth_state = nxt
		_syll_in = rng.randf_range(0.075, 0.16) * (1.6 if nxt == "closed" else 1.0)


func _rest_mouth() -> String:
	for r in reactions:
		if r.has("mouth"):
			return r.mouth
	return idle_mouth


# ---------------------------------------------------------------- public API

func appear() -> void:
	# 0.6 s pop: scale 0.9 -> 1.04 -> 1.0 (back-out), fade in, a small rise; springs swing from the motion
	if _appear_tw:
		_appear_tw.kill()
	figure.scale = Vector2.ONE * 0.9
	figure.modulate.a = 0.0
	var lift: = Vector2(0, 26)
	_figure_base_pos += lift
	_appear_tw = create_tween().set_parallel(true)
	_appear_tw.tween_property(figure, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_appear_tw.tween_property(figure, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_appear_tw.tween_method(func(v: Vector2) -> void: _figure_base_pos = v, _figure_base_pos, _figure_base_pos - lift, 0.6) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	reactions.append({"kind": "appear", "t": 0.0, "dur": 1.4, "mouth": "small"})


func talk(seconds: float) -> void:
	_talk_left = maxf(_talk_left, seconds)
	_syll_in = 0.0


func set_talking(on: bool) -> void:
	_talking = on
	if on:
		_syll_in = 0.0


func set_mouth_level(level: float) -> void:
	# external lip-sync (e.g. voice amplitude 0..1); pass a negative value to hand the mouth back
	_ext_level = level


func blink() -> void:
	_blink_t = 0.0
	_blink_double = false


func wink(left: bool) -> void:
	reactions.append({"kind": "wink", "t": 0.0, "dur": 0.55, "left": left})


func tap(global_pos: Vector2) -> String:
	var p: = art.get_global_transform().affine_inverse() * global_pos
	var zone: = zone_at(p)
	if zone != "none":
		react(zone, global_pos)
	tapped.emit(zone)
	return zone


func zone_at(p: Vector2) -> String:
	for k in def.dead_zones:
		if not k.begins_with("_") and Geometry2D.is_point_in_polygon(p, _poly(def.dead_zones[k])):
			return "none"
	var z: Dictionary = def.zones
	for k in ["head", "armL", "armR", "hair", "collar", "outfit", "outfit2"]:
		if z.has(k) and Geometry2D.is_point_in_polygon(p, _poly(z[k])):
			return {"collar": "outfit", "outfit2": "outfit"}.get(k, k)
	return "bg"


static func _poly(a: Array) -> PackedVector2Array:
	var out: = PackedVector2Array()
	for q in a:
		out.append(Vector2(q[0], q[1]))
	return out


func react(zone: String, at_global: = Vector2.INF) -> void:
	var side: = 1.0
	if at_global != Vector2.INF:
		var p: = art.get_global_transform().affine_inverse() * at_global
		side = signf(p.x - art_pos["head"].x)
		if side == 0.0:
			side = 1.0
	# one reaction of a kind at a time: a new tap restarts it
	var kind: = {"head": "happy", "armL": "wiggleL", "armR": "wiggleR", "hair": "flick", "outfit": "glance", "bg": "glance"}.get(zone, "glance")
	for r in reactions.duplicate():
		if r.kind == kind:
			reactions.erase(r)
	match kind:
		"happy":
			reactions.append({"kind": kind, "t": 0.0, "dur": 2.6, "mouth": "open"})
		"wiggleL":
			reactions.append({"kind": kind, "t": 0.0, "dur": 1.5, "mouth": "small"})
		"wiggleR":
			reactions.append({"kind": kind, "t": 0.0, "dur": 1.3, "mouth": "small"})
		"flick":
			reactions.append({"kind": kind, "t": 0.0, "dur": 1.6, "side": side, "mouth": "small"})
		"glance":
			reactions.append({"kind": kind, "t": 0.0, "dur": 1.9, "side": side, "mouth": "small"})


func _update_reactions(delta: float) -> void:
	for r in reactions.duplicate():
		r.t += delta
		if r.t >= r.dur:
			reactions.erase(r)
	if not _talking and _talk_left <= 0.0 and _ext_level < 0.0:
		mouth_state = _rest_mouth()


func _reaction_pose() -> Dictionary:
	var o: = {}
	var eyes: = 0.0
	var bl: = 0.0
	var wl: = 0.0
	var wr: = 0.0
	sigh = 0.0
	_impulse_rot.clear()
	for r in reactions:
		var x: float = r.t
		match r.kind:
			"sigh":
				sigh = sin(PI * clampf(x / r.dur, 0.0, 1.0)) ** 2
			"appear":
				# the pop lifts her: the twin tails and tassels swing a little and settle
				var kick: = sin(PI * clampf(x / 0.35, 0.0, 1.0))
				for c in ["tailL", "tailR"]:
					_impulse_rot[c] = deg_to_rad(1.6) * kick * (1.0 if c == "tailL" else -1.0)
				for c in ["tassel", "navel", "pendant"]:
					_impulse_rot[c] = deg_to_rad(2.5) * kick
			"happy":
				# shy happy: eyes ^^, blush, a little shrug, head tilts in and bobs twice
				var e: = _env(x, 0.12, 1.25, 0.35)
				eyes = maxf(eyes, e)
				bl = maxf(bl, _env(x, 0.3, 1.5, 0.7))
				var bob: = sin(TAU_ * 2.3 * x) * exp(-x * 2.2) * _ease(x / 0.08)
				o.head = float(o.get("head", 0.0)) + 2.0 * _env(x, 0.25, 1.2, 0.8) + 0.8 * bob
				o.head_y = float(o.get("head_y", 0.0)) + 4.0 * absf(bob)
				o.shrug = float(o.get("shrug", 0.0)) + 3.5 * _env(x, 0.2, 0.8, 0.7)
				o.sway = float(o.get("sway", 0.0)) + 0.35 * _env(x, 0.4, 1.0, 0.9)
				if x > 0.75 and r.mouth == "open":
					r.mouth = "small"
				if x > 1.6:
					r.mouth = "closed"
			"wiggleL":
				# the raised hand fiddles with her hair: hand circles a little, elbow follows (IK)
				var e: = _env(x, 0.18, 0.9, 0.4)
				var ph: = TAU_ * 2.6 * x
				o.ik_armL = Vector2(cos(ph) * 7.0, sin(ph) * 5.0 - 4.0) * e
				o.armL = 1.2 * e
				o.head = float(o.get("head", 0.0)) - 1.2 * e
			"wiggleR":
				# fingers tap on the hip: three little hand pats
				var e: = _env(x, 0.1, 0.85, 0.35)
				o.handR = -4.5 * e * (0.5 + 0.5 * sin(TAU_ * 3.2 * x - PI * 0.5))
				o.ik_armR = Vector2(-3.0, -2.5) * e * (0.5 + 0.5 * sin(TAU_ * 3.2 * x - PI * 0.5))
				o.shrug = float(o.get("shrug", 0.0)) + 1.5 * e
			"flick":
				var e: = _env(x, 0.15, 0.5, 0.9)
				o.head = float(o.get("head", 0.0)) + 1.2 * r.side * e
				o.sway = float(o.get("sway", 0.0)) + 0.5 * r.side * e
				eyes = maxf(eyes, _env(x, 0.1, 0.5, 0.25))
				# a toss of the twin tails: a smooth push on the springs' targets, they swing and settle
				var push: = sin(PI * clampf(x / 0.4, 0.0, 1.0))
				_impulse_rot["tailL"] = deg_to_rad(4.0) * r.side * push
				_impulse_rot["tailR"] = deg_to_rad(2.5) * r.side * push
			"glance":
				# playful glance towards the tap: head leans that way, a wink, the room drifts the other way
				var e: = _env(x, 0.3, 0.9, 0.7)
				o.head = float(o.get("head", 0.0)) + 1.6 * r.side * e
				o.head_x = float(o.get("head_x", 0.0)) + 5.0 * r.side * e
				o.sway = float(o.get("sway", 0.0)) + 0.45 * r.side * e
				o.cam = Vector2(3.0 * r.side * e, 0.0)
				o.bgcam = Vector2(-5.0 * r.side * e, 0.0)
				var w: = _env(x - 0.35, 0.09, 0.22, 0.12)
				if r.side > 0.0:
					wr = maxf(wr, w)
				else:
					wl = maxf(wl, w)
				if x > 1.2:
					r.mouth = "closed"
			"wink":
				var w: = _env(x, 0.09, 0.25, 0.14)
				if r.left:
					wl = maxf(wl, w)
				else:
					wr = maxf(wr, w)
	eye_extra = eyes
	blush = bl
	wink_l = wl
	wink_r = wr
	return o


func _unhandled_input(event: InputEvent) -> void:
	if not handle_input:
		return
	# emulated events (touch from mouse on desktop, mouse from touch on phones) carry the emulation device id:
	# skip them so one finger is one tap
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	var pressed: = false
	var pos: = Vector2.ZERO
	if event is InputEventScreenTouch and event.pressed:
		pressed = true
		pos = event.position
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed = true
		pos = event.position
	if pressed:
		var gp: = get_canvas_transform().affine_inverse() * pos
		if tap(gp) != "none":
			get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- dev: strain probe

var _strain_cache: = {}


func strain_tris() -> Array:
	# centroids (art px) of the triangles measure_strain() reports in "per_tri", same order
	var out: = []
	for poly in _strain_cache.get("tris", []):
		out.append((body.polygon[poly[0]] + body.polygon[poly[1]] + body.polygon[poly[2]]) / 3.0)
	return out


func measure_strain() -> Dictionary:
	# CPU re-run of the skinning (same math as the GPU) to find the worst local stretch of the current pose.
	# Per triangle: singular values s1 >= s2 of the rest->posed linear map; aniso = s1/s2 - 1 (shape change),
	# area = s1*s2 - 1. Only triangles over opaque art count (alpha sampled at the centroid). Slow: dev only.
	if _strain_cache.is_empty():
		var img: = body.texture.get_image()
		if img.is_compressed():
			img.decompress()
		var tris: = []
		for poly in body.polygons:
			var c: Vector2 = (body.polygon[poly[0]] + body.polygon[poly[1]] + body.polygon[poly[2]]) / 3.0
			var px: = Vector2i(clampi(int(c.x), 0, img.get_width() - 1), clampi(int(c.y), 0, img.get_height() - 1))
			if img.get_pixelv(px).a > 0.5:
				tris.append(poly)
		var bl: = []
		for i in body.get_bone_count():
			var bn: Bone2D = skel.get_node(body.get_bone_path(i))
			bl.append({"bone": bn, "w": body.get_bone_weights(i), "rest": art_pos[str(bn.name)]})
		_strain_cache = {"tris": tris, "bones": bl}
	var inv: = art.get_global_transform().affine_inverse()
	var mats: = []
	for b in _strain_cache.bones:
		mats.append(inv * (b.bone as Bone2D).get_global_transform() * Transform2D(0.0, -(b.rest as Vector2)))
	var src: = body.polygon
	var dst: = PackedVector2Array()
	dst.resize(src.size())
	for v in src.size():
		var acc: = Vector2.ZERO
		var ws: = 0.0
		for i in mats.size():
			var w: float = _strain_cache.bones[i].w[v]
			if w > 0.0:
				acc += w * ((mats[i] as Transform2D) * src[v])
				ws += w
		dst[v] = acc / ws if ws > 0.0 else src[v]
	var worst: = 0.0
	var worst_at: = Vector2.ZERO
	var worst_area: = 0.0
	var vals: = PackedFloat32Array()
	var per_tri: = PackedFloat32Array()
	for poly in _strain_cache.tris:
		var a0: Vector2 = src[poly[0]]
		var R: = Transform2D(src[poly[1]] - a0, src[poly[2]] - a0, Vector2.ZERO)
		var D: = Transform2D(dst[poly[1]] - dst[poly[0]], dst[poly[2]] - dst[poly[0]], Vector2.ZERO)
		var A: = D * R.affine_inverse()
		var a: = A.x.x
		var b: = A.y.x
		var c: = A.x.y
		var d: = A.y.y
		var s: = a * a + b * b + c * c + d * d
		var det: = absf(a * d - b * c)
		var root: = sqrt(maxf(s * s - 4.0 * det * det, 0.0))
		var s1: = sqrt((s + root) * 0.5)
		var s2: = sqrt(maxf((s - root) * 0.5, 1e-9))
		var an: = s1 / s2 - 1.0
		vals.append(an)
		per_tri.append(an)
		if an > worst:
			worst = an
			worst_at = (src[poly[0]] + src[poly[1]] + src[poly[2]]) / 3.0
			worst_area = s1 * s2 - 1.0
	vals.sort()
	var bone_info: = {}
	for i in mats.size():
		var m: Transform2D = mats[i]
		var rp: Vector2 = _strain_cache.bones[i].rest
		bone_info[str(_strain_cache.bones[i].bone.name)] = [(m * rp - rp).length(), rad_to_deg(m.get_rotation())]
	var disp: = 0.0
	var disp_at: = Vector2.ZERO
	for v in src.size():
		var dd: = (dst[v] - src[v]).length()
		if dd > disp:
			disp = dd
			disp_at = src[v]
	return {"max": worst, "at": worst_at, "area": worst_area, "p99": vals[int(vals.size() * 0.99)], "tris": vals.size(),
			"disp": disp, "disp_at": disp_at, "per_tri": per_tri, "bones": bone_info}
