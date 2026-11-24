class_name V10LiveRig
extends Node2D

# 0.10 «living illustration», v2: one finished illustration, cut into a few skinned layers (twin tails and the
# thigh behind the body, the raised arm behind the head, the hand-on-hip arm in front; each under-painted so it
# slides instead of stretching) on one Skeleton2D. Motion = layered idle (breathing, weight shift, head drift)
# + flirty autonomous gestures and tap reactions written as keyframe tracks, then every pose channel runs through
# a second-order spring (snappy attack, overshoot, soft settle) + spring chains (tails, skirt, tassels) + IK pins.
# Face: blink, winks, happy ^^ / frown eyes, 7 mouth shapes, blush, moving irises, a heart for the air kiss.
# Nothing is generated at runtime: every frame is the same painting, only warped and layered. See README.md here.
#
#   var rig: V10LiveRig = load("res://assets/v10/rig/mc_gown/rig.tscn").instantiate()
#   add_child(rig); rig.position = ...; rig.scale = Vector2.ONE * k   # local units are pixels of body.png
#   rig.appear()                     0.6 s pop with overshoot
#   rig.react("head"|"armL"|"armR"|"hair"|"outfit"|"bg", at_global)   or rig.tap(global_pos) (zone lookup)
#   rig.gesture("hip_pop")           play one idle gesture now (see GESTURES); auto_gestures plays them by itself
#   rig.look_at_global(p, hold)      eyes and head follow a point
#   rig.talk(seconds) / rig.set_talking(on) / rig.set_mouth_level(0..1)   lip-sync
#   rig.blink() / rig.wink(left)
# Signals: tapped(zone) after a tap was classified («none» = dead zone or nothing there); gesture_started(name).

signal tapped(zone: String)
signal gesture_started(name: String)

@export_file("*.json") var def_path: = ""
@export var show_background: = true
@export var handle_input: = true
@export var idle_mouth: = "closed"  # closed | small | open (open = the painted laugh)
@export var motion: = 1.0  # global amplitude of the idle body motion (FX «Минимум» -> 0.5)
@export var parallax: = 0.35  # background moves this fraction of the figure's drift (0 = glued)
@export var auto_gestures: = true
@export var gesture_gap: = Vector2(4.0, 8.0)  # seconds between autonomous gestures (start to start)
@export var gesture_seed: = 0  # 0 = random

const TAU_: = TAU
const SUBSTEP: = 1.0 / 120.0
const GESTURES: = ["hip_pop", "lean_in", "air_kiss", "tail_flick", "shoulder_roll", "knee_in", "hair_touch"]
const MOUTHS: = ["closed", "small", "ah", "oh", "pucker", "pout"]  # patches; "open" = the painted laugh

# Pose channels -> second-order dynamics [f (Hz), zeta, r]. f = speed, zeta < 1 overshoots, r > 0 answers at once
# (r < 0 would anticipate). Gesture tracks and the weight-shift beat set targets; the springs give the
# snappy-then-soft BD2 timing and the follow-through (head and arms are a little slower than the hips).
const CH: = {
	"hip_x": [1.6, 0.48, 0.7], "hip_y": [1.9, 0.45, 0.7], "hip_rot": [1.6, 0.48, 0.7],
	"spine": [1.4, 0.5, 0.5], "chest_rot": [1.3, 0.5, 0.5], "shrug": [2.2, 0.42, 0.8], "lean": [1.4, 0.55, 0.4],
	"neck": [1.5, 0.5, 0.5], "head": [1.7, 0.42, 0.6], "head_x": [1.7, 0.45, 0.6], "head_y": [1.9, 0.45, 0.6],
	"zoom": [1.3, 0.6, 0.3], "cam_x": [1.2, 0.7, 0.3], "cam_y": [2.6, 0.32, 0.8], "bg_x": [1.0, 0.8, 0.0],
	"armL": [1.8, 0.45, 0.5], "armL_lo": [2.2, 0.42, 0.5], "ikL_x": [2.8, 0.42, 0.5], "ikL_y": [2.8, 0.42, 0.5],
	"armR": [1.8, 0.45, 0.5], "ikR_x": [2.6, 0.45, 0.5], "ikR_y": [2.6, 0.45, 0.5], "handR": [3.6, 0.35, 0.6],
	"thighL": [1.8, 0.42, 0.5], "thighR": [1.8, 0.45, 0.5],
	"look_x": [5.5, 0.8, 0.0], "look_y": [5.5, 0.8, 0.0],
	"tailL": [3.0, 0.6, 0.5], "tailR": [3.0, 0.6, 0.5],
}
const FACE_CH: = ["eyes_closed", "eyes_happy", "eyes_frown", "wink_l", "wink_r", "blush"]

var def: = {}
var figure: Node2D
var art: Node2D
var skel: Skeleton2D
var body: Polygon2D
var layers: Array[Polygon2D] = []
var bg: Sprite2D
var hearts: Node2D
var bones: = {}  # name -> Bone2D
var rest: = {}  # name -> Vector2 (local rest position)
var art_pos: = {}  # name -> Vector2 (art px of the joint)
var patches: = {}  # name -> Sprite2D
var irises: = []  # [{sprite, mat}]
var iris_range: = Vector2(4.0, 1.8)
var face_pivot: = Vector2(700, 228)
var lips: = Vector2(722, 306)
var chains: = []  # [{cfg, bones: [{bone, dir, len, x, v}]}]
var jiggles: = []
var iks: = []
var bg_base: = Vector2.ZERO
var t: = 0.0
var _acc: = 0.0
var rng: = RandomNumberGenerator.new()
var _seed: = Vector4.ZERO

# channel dynamics (parallel arrays, index = _ci[name])
var _cn: = PackedStringArray()
var _ci: = {}
var _tgt: = PackedFloat32Array()
var _y: = PackedFloat32Array()
var _yd: = PackedFloat32Array()
var _xp: = PackedFloat32Array()
var _k: = []  # [k1, k2, k3]
var ch: = {}  # name -> current (sprung) value, read by the pose

# breathing
var breath_phase: = 0.0
var breath: = 0.0  # 0..1
var sigh: = 0.0
var _next_sigh: = 14.0

# idle beats: weight shifts and eye saccades are small random steps through the springs
var _beat: = 0.0
var _beat_in: = 2.0
var _sacc: = Vector2.ZERO
var _sacc_in: = 1.0

# face
var _blink_in: = 2.0
var _blink_t: = -1.0
var _blink_double: = false
var face: = {}  # FACE_CH -> 0..1 this frame
var mouth_state: = "closed"
var _mouth_a: = {}
var _talk_left: = 0.0
var _talking: = false
var _syll_in: = 0.0
var _ext_level: = -1.0

# actions (gestures and reactions): {name, kind, t, dur, tracks: {ch: PackedFloat32Array [t,v,...]}, face: {...},
# mouth: [[t0, t1, shape]], hearts: [t], auto: bool}
var actions: = []
var _next_gesture: = 3.0
var _last_gesture: = ""
var _last_reaction_t: = -10.0
var _tap_times: = []
var _figure_base_pos: = Vector2.ZERO
var _appear_tw: Tween
var _appear_scale: = 1.0
var _impulse_rot: = {}

# performance probe
var last_update_usec: = 0


func _ready() -> void:
	if gesture_seed != 0:
		rng.seed = gesture_seed
	else:
		rng.randomize()
	_seed = Vector4(rng.randf() * 10.0, rng.randf() * 10.0, rng.randf() * 10.0, rng.randf() * 10.0)
	def = JSON.parse_string(FileAccess.get_file_as_string(def_path))
	figure = $Figure
	art = $Figure/Art
	skel = $Figure/Art/Skeleton
	body = $Figure/Art/Body
	for c in art.get_children():
		if c is Polygon2D:
			layers.append(c)
	_figure_base_pos = figure.position
	_collect_bones(skel)
	_setup_channels()
	_setup_face()
	_setup_dynamics()
	if show_background:
		_setup_bg()
	hearts = _Hearts.new()
	hearts.name = "Hearts"
	art.add_child(hearts)
	mouth_state = idle_mouth
	_blink_in = rng.randf_range(1.2, 3.0)
	_next_gesture = rng.randf_range(2.5, 4.0)


func _collect_bones(n: Node) -> void:
	for c in n.get_children():
		if c is Bone2D:
			bones[c.name] = c
			rest[c.name] = c.position
			_collect_bones(c)
	for b in def.bones:
		art_pos[b.name] = Vector2(b.pos[0], b.pos[1])


func _setup_channels() -> void:
	var i: = 0
	for k in CH:
		var p: Array = CH[k]
		var f: float = p[0]
		var z: float = p[1]
		var r: float = p[2]
		_cn.append(k)
		_ci[k] = i
		_k.append([z / (PI * f), 1.0 / ((TAU_ * f) * (TAU_ * f)), r * z / (TAU_ * f)])
		ch[k] = 0.0
		i += 1
	_tgt.resize(i)
	_y.resize(i)
	_yd.resize(i)
	_xp.resize(i)
	for c in FACE_CH:
		face[c] = 0.0


func _tex(file: String) -> Texture2D:
	return load(def_path.get_base_dir().path_join(file))


func _setup_face() -> void:
	var f: Dictionary = def.face
	var head: Bone2D = bones[f.bone]
	if f.has("iris"):
		var ir: Dictionary = f.iris
		iris_range = Vector2(ir.range[0], ir.range[1])
		face_pivot = Vector2(ir.pivot[0], ir.pivot[1])
		var sh: Shader = load("res://scripts/v10/rig/v10_iris.gdshader")
		for side in ["L", "R"]:
			var e: Dictionary = ir[side]
			var s: = Sprite2D.new()
			s.name = "eye%s_socket" % side
			s.texture = _tex(e.socket)
			s.centered = false
			s.position = Vector2(e.pos[0], e.pos[1]) - art_pos[f.bone]
			s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			var m: = ShaderMaterial.new()
			m.shader = sh
			m.set_shader_parameter("iris_tex", _tex(e.iris))
			m.set_shader_parameter("size_px", s.texture.get_size())
			s.material = m
			head.add_child(s)
			irises.append({"sprite": s, "mat": m})
	if f.has("lips"):
		lips = Vector2(f.lips[0], f.lips[1])
	for k in f.patches:
		var p: Dictionary = f.patches[k]
		var s: = Sprite2D.new()
		s.name = k
		s.texture = _tex(p.file)
		s.centered = false
		s.position = Vector2(p.pos[0], p.pos[1]) - art_pos[f.bone]
		s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		s.modulate.a = 0.0
		s.visible = false
		head.add_child(s)
		patches[k] = s
	# draw order inside the head: irises, blush, eye states, mouths last
	for k in ["blush", "eyes_frown", "eyes_happy", "eyes_closed", "eyeL_closed", "eyeR_closed",
			"mouth_small", "mouth_closed", "mouth_ah", "mouth_oh", "mouth_pucker", "mouth_pout"]:
		if patches.has(k):
			head.move_child(patches[k], -1)
	for m in MOUTHS:
		_mouth_a[m] = 0.0


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
	# layered sines at incommensurate periods, normalised to about -1..1 (nothing ever reads as a loop)
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


static func _track(k: PackedFloat32Array, x: float) -> float:
	# keyframes [t0, v0, t1, v1, ...], smoothstep between keys, held before the first / after the last
	var n: = k.size()
	if n == 0:
		return 0.0
	if x <= k[0]:
		return k[1]
	var i: = 2
	while i < n:
		if x <= k[i]:
			var t0: = k[i - 2]
			var u: = (x - t0) / maxf(k[i] - t0, 1e-4)
			return lerpf(k[i - 1], k[i + 1], _ease(u))
		i += 2
	return k[n - 1]


# ---------------------------------------------------------------- frame

func _process(delta: float) -> void:
	var t0: = Time.get_ticks_usec()
	delta = minf(delta, 0.1)
	t += delta
	_update_breath(delta)
	_update_idle_beats(delta)
	_update_actions(delta)
	_acc += delta
	var steps: = 0
	while _acc >= SUBSTEP and steps < 12:
		_step_channels(SUBSTEP)
		_acc -= SUBSTEP
		steps += 1
	if steps == 12:
		_acc = 0.0
	for i in _cn.size():
		ch[_cn[i]] = _y[i]
	_pose_body()
	_solve_ik()
	for i in steps:
		_simulate(SUBSTEP)
	_update_face(delta)
	hearts.queue_redraw()
	last_update_usec = Time.get_ticks_usec() - t0


func _step_channels(T: float) -> void:
	for i in _tgt.size():
		var x: = _tgt[i]
		var kk: Array = _k[i]
		var k1: float = kk[0]
		var k2: float = maxf(kk[1], maxf(T * T * 0.5 + T * k1 * 0.5, T * k1))
		var xd: = (x - _xp[i]) / T
		_xp[i] = x
		_y[i] += T * _yd[i]
		_yd[i] += T * (x + float(kk[2]) * xd - _y[i] - k1 * _yd[i]) / k2


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
		actions.append({"name": "sigh", "kind": "sigh", "t": 0.0, "dur": 5.0, "tracks": {}})


func _update_idle_beats(delta: float) -> void:
	# weight shifts: a new resting side every 2.5-5.5 s; the springs make it a snappy shift with a soft settle
	_beat_in -= delta
	if _beat_in <= 0.0:
		_beat_in = rng.randf_range(2.5, 5.5)
		var nb: = rng.randf_range(0.45, 1.0) * (-signf(_beat) if absf(_beat) > 0.2 else (1.0 if rng.randf() < 0.5 else -1.0))
		_beat = nb
	# micro-saccades: the eyes re-fixate somewhere near the viewer every 0.8-3 s
	_sacc_in -= delta
	if _sacc_in <= 0.0:
		_sacc_in = rng.randf_range(0.8, 3.0)
		_sacc = Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-0.5, 0.5)) * 1.3
	# autonomous flirty gestures
	if auto_gestures:
		_next_gesture -= delta
		var busy: = false
		for a in actions:
			if a.kind != "sigh":
				busy = true
		if t - _last_reaction_t < 2.0:
			busy = true
		if _next_gesture <= 0.0 and not busy:
			var pool: = []
			for g in GESTURES:
				if g != _last_gesture:
					pool.append(g)
			gesture(pool[rng.randi() % pool.size()], true)
			_next_gesture = rng.randf_range(gesture_gap.x, gesture_gap.y)
		elif _next_gesture <= 0.0:
			_next_gesture = 0.6


func _update_actions(delta: float) -> void:
	for a in actions.duplicate():
		a.t += delta
		if a.t >= a.dur:
			actions.erase(a)
	for i in _tgt.size():
		_tgt[i] = 0.0
	for c in FACE_CH:
		face[c] = 0.0
	_impulse_rot.clear()
	sigh = 0.0
	var mouth: = ""
	var mouth_t: = -1.0
	for a in actions:
		var x: float = a.t
		if a.kind == "sigh":
			sigh = sin(PI * clampf(x / a.dur, 0.0, 1.0)) ** 2
			continue
		var tr: Dictionary = a.tracks
		for c in tr:
			if _ci.has(c):
				_tgt[_ci[c]] += _track(tr[c], x)
			elif face.has(c):
				face[c] = maxf(face[c], _track(tr[c], x))
		for seg in a.get("mouth", []):
			if x >= seg[0] and x < seg[1] and a.t0 > mouth_t:
				mouth = seg[2]
				mouth_t = a.t0
		for h in a.get("hearts", []):
			if x >= float(h) and x - delta < float(h):
				_spawn_heart(a.get("side", 1.0))
	# idle beats feed the same springs
	_tgt[_ci.hip_x] += 7.0 * _beat * motion
	_tgt[_ci.hip_rot] += -0.9 * _beat * motion
	_tgt[_ci.spine] += 0.7 * _beat * motion
	_tgt[_ci.chest_rot] += 0.45 * _beat * motion
	_tgt[_ci.head] += 0.9 * _beat * motion
	_tgt[_ci.look_x] += _sacc.x
	_tgt[_ci.look_y] += _sacc.y
	_impulse_rot["tailL"] = deg_to_rad(ch.tailL)
	_impulse_rot["tailR"] = deg_to_rad(ch.tailR)
	if not _talking and _talk_left <= 0.0 and _ext_level < 0.0:
		mouth_state = mouth if mouth != "" else idle_mouth


func _pose_body() -> void:
	var m: = motion
	var sway: = _n([7.3, 11.9, 19.7], _seed.x) * m
	var drift: = _n([9.7, 14.3], _seed.y)
	var b: = breath + sigh * 0.8
	var lean: float = ch.lean
	# camera drift: the figure floats a few px, the background follows at a fraction (parallax)
	var cam: = Vector2(drift * 9.0, _n([12.1, 8.3], _seed.z) * 3.0) * m + Vector2(ch.cam_x, ch.cam_y)
	# lean-in / zoom: scale the figure about the FACE (never towards the chest)
	var z: float = (1.0 + ch.zoom) * _appear_scale
	figure.scale = Vector2(z, z)
	var root_art: Vector2 = art_pos["root"]
	figure.position = _figure_base_pos + cam + (face_pivot - root_art) * (1.0 - z)
	if bg:
		bg.position = bg_base + cam * parallax + Vector2(ch.bg_x, 0.0)
	# weight shift: hips swing out and tilt, the spine counters, shoulders tilt the other way (contrapposto)
	_pose("hips", Vector2(sway * 11.0 + ch.hip_x, -absf(sway) * 3.0 - b * 0.6 + ch.hip_y), deg_to_rad(-1.3 * sway + ch.hip_rot))
	_pose("spine", Vector2.ZERO, deg_to_rad(1.0 * sway + ch.spine - 0.2 * b))
	# head moves are shared by the whole upper body (chest 30% / neck 25% / head 45% of the turn, 40/25/35% of the
	# shift): it reads as her body leaning into the move, and the bend spreads over the wide chest and neck bands
	# instead of shearing the jaw against the collar
	var head_drift: = _n([5.3, 8.9, 13.7], _seed.z) * m
	var nod: = _n([6.7, 10.3], _seed.w + 2.0) * m
	var hr: float = 2.6 * head_drift - 0.5 * sway + ch.head
	var hp: = Vector2(head_drift * 3.0 + ch.head_x, nod * 2.2 + ch.head_y)
	var chest: Bone2D = bones["chest"]
	# shrugs lift the shoulders (arm roots, neck) more than the ribcage: the bust band does not stretch
	chest.position = rest["chest"] + Vector2(0, -b * 4.0 - ch.shrug * 0.4 + lean * 2.0) + hp * 0.3
	chest.rotation = deg_to_rad(0.5 * sway + 0.5 * _n([6.1, 9.4], _seed.w) * m + ch.chest_rot + 0.3 * hr)
	chest.scale = Vector2(1.0 + 0.005 * b + 0.006 * lean, 1.0 + 0.011 * b + 0.006 * lean)
	_pose("neck", hp * 0.25 + Vector2(0, -0.2 * ch.shrug), deg_to_rad(0.25 * hr - 0.3 * sway + ch.neck))
	var head: Bone2D = bones["head"]
	head.rotation = deg_to_rad(0.45 * hr)
	head.position = rest["head"] + hp * 0.35 + Vector2(0.0, b * 0.6)
	head.scale = Vector2.ONE * (1.0 + 0.016 * lean)
	# arms (IK keeps the hands planted; these feed the elbows), legs
	_pose("armL_up", Vector2(0, -0.6 * ch.shrug), deg_to_rad(-0.6 * b + 1.2 * _n([4.7, 7.9], _seed.y) * m + ch.armL))
	_pose("armL_lo", Vector2.ZERO, deg_to_rad(ch.armL_lo))
	_pose("armR_up", Vector2(0, -0.6 * ch.shrug), deg_to_rad(0.4 * b + ch.armR))
	_pose("armR_lo", Vector2.ZERO, 0.0)
	_pose("handR", Vector2.ZERO, deg_to_rad(0.8 * _n([3.9, 6.3], _seed.x) * m + ch.handR))
	_pose("thighL", Vector2.ZERO, deg_to_rad(0.5 * sway + ch.thighL))
	_pose("thighR", Vector2.ZERO, deg_to_rad(-0.3 * sway + ch.thighR))
	for ik in iks:
		if ik.name == "armL":
			ik.offset = Vector2(ch.ikL_x, ch.ikL_y)
		elif ik.name == "armR":
			ik.offset = Vector2(ch.ikR_x, ch.ikR_y)
	# irises: the look channels, clamped to the eye opening
	var look: = Vector2(clampf(ch.look_x, -iris_range.x, iris_range.x), clampf(ch.look_y, -iris_range.y, iris_range.y))
	for e in irises:
		(e.mat as ShaderMaterial).set_shader_parameter("offset_px", look)


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
	# Springs live in art space (body.png px): the figure's own drift, zoom and the entrance pop do not kick them,
	# only the bones' motion does (plus explicit impulses).
	var to_art: = art.get_global_transform().affine_inverse()
	var art_rot: = art.get_global_transform().get_rotation()
	for chn in chains:
		var cfg: Dictionary = chn.cfg
		var k: = float(cfg.k)
		var damp: = float(cfg.damp)
		var amount: = float(cfg.amount)
		var mx: = deg_to_rad(float(cfg.max))
		var breeze: = deg_to_rad(float(cfg.breeze)) * motion
		var root_amount: = float(cfg.get("root_amount", 1.0))
		var i: = 0
		for e in chn.bones:
			var b: Bone2D = e.bone
			var parent: Node2D = b.get_parent()
			var prot: = parent.global_rotation - art_rot
			var r0: = 0.0
			if i == 0:
				r0 = -float(cfg.gravity) * prot
			r0 += breeze * (0.6 * sin(TAU_ * t / 3.7 - i * 0.8 + _seed.x + chn.name.length()) + 0.4 * sin(TAU_ * t / 6.1 - i * 1.3 + _seed.y))
			# impulses only move the spring's target, so the bone eases into them (no snap)
			var imp: = float(_impulse_rot.get(chn.name, 0.0)) * (0.25 if i == 0 else 1.0)
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
	var happy: float = face.eyes_happy
	var frown: float = face.eyes_frown * (1.0 - happy)
	var closed: = maxf(blink_a, face.eyes_closed) * (1.0 - happy)
	_alpha("eyes_happy", happy)
	_alpha("eyes_frown", frown * (1.0 - closed))
	_alpha("eyes_closed", closed)
	var open_a: = (1.0 - closed) * (1.0 - happy)
	_alpha("eyeL_closed", face.wink_l * open_a)
	_alpha("eyeR_closed", face.wink_r * open_a)
	_alpha("blush", face.blush * 0.7)
	# mouth: crossfade the patches (35 ms); "open" = no patch, the painted laugh shows
	_update_talk(delta)
	var f: = 1.0 - exp(-delta / 0.035)
	for m in MOUTHS:
		_mouth_a[m] = lerpf(_mouth_a[m], 1.0 if mouth_state == m else 0.0, f)
		_alpha("mouth_" + m, _mouth_a[m])


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
		var l: = _ext_level
		mouth_state = "closed" if l < 0.12 else ("small" if l < 0.3 else (("ah" if fmod(t, 0.5) < 0.25 else "oh") if l < 0.6 else "open"))
		return
	var on: = _talking or _talk_left > 0.0
	_talk_left = maxf(0.0, _talk_left - delta)
	if not on:
		if _syll_in > -1.0:
			_syll_in = -1.0
		return
	_syll_in -= delta
	if _syll_in <= 0.0:
		# syllables: open vowels most, then rounded, small and closed (consonants); never the same twice
		var r: = rng.randf()
		var nxt: = "open" if r < 0.26 else ("ah" if r < 0.48 else ("oh" if r < 0.62 else ("small" if r < 0.84 else "closed")))
		if nxt == mouth_state:
			nxt = "small" if mouth_state != "small" else "ah"
		mouth_state = nxt
		_syll_in = rng.randf_range(0.075, 0.16) * (1.6 if nxt == "closed" else 1.0)


# ---------------------------------------------------------------- hearts (air kiss)

class _Hearts:
	extends Node2D
	var list: = []

	func spawn(at: Vector2, side: float) -> void:
		list.append({"p": at, "v": Vector2(150.0 * side, -105.0), "t": 0.0, "life": 1.7, "rot": 0.18 * side, "ph": randf() * TAU})

	func _process(delta: float) -> void:
		for h in list.duplicate():
			h.t += delta
			h.v.y += 12.0 * delta
			h.p += h.v * delta + Vector2(sin(h.t * 7.0 + h.ph) * 18.0 * delta, 0.0)
			if h.t >= h.life:
				list.erase(h)

	func _draw() -> void:
		for h in list:
			var x: float = h.t / h.life
			# pop in with overshoot, float, fade out
			var s: = (1.0 - pow(1.0 - minf(x / 0.18, 1.0), 3.0)) * (1.0 + 0.25 * sin(minf(x / 0.18, 1.0) * PI))
			s *= 1.0 + 0.35 * x
			var a: = 1.0 - smoothstep(0.55, 1.0, x)
			_heart(h.p, 24.0 * s, h.rot + 0.12 * sin(h.t * 5.0), a)

	func _heart(c: Vector2, r: float, rot: float, a: float) -> void:
		var pts: = PackedVector2Array()
		for i in 40:
			var u: = TAU * i / 40.0
			var hx: = 16.0 * pow(sin(u), 3.0)
			var hy: = -(13.0 * cos(u) - 5.0 * cos(2.0 * u) - 2.0 * cos(3.0 * u) - cos(4.0 * u))
			pts.append(c + Vector2(hx, hy).rotated(rot) * (r / 16.0))
		for g in 3:
			var k: = 1.0 + 0.22 * (3 - g)
			var gp: = PackedVector2Array()
			for p in pts:
				gp.append(c + (p - c) * k)
			draw_colored_polygon(gp, Color(1.0, 0.55, 0.72, 0.10 * a))
		draw_colored_polygon(pts, Color(1.0, 0.36, 0.56, 0.95 * a))
		var inner: = PackedVector2Array()
		for p in pts:
			inner.append(c + (p - c) * 0.72 + Vector2(0, -r * 0.08).rotated(rot))
		draw_colored_polygon(inner, Color(1.0, 0.52, 0.68, 0.9 * a))
		draw_circle(c + Vector2(-r * 0.42, -r * 0.42).rotated(rot), r * 0.17, Color(1, 1, 1, 0.85 * a))


func _spawn_heart(side: float) -> void:
	(hearts as _Hearts).spawn(lips + Vector2(10.0 * side, -2.0), side)


# ---------------------------------------------------------------- gestures

func gesture(name: String, auto: = false) -> void:
	var s: = 1.0 if rng.randf() < 0.5 else -1.0
	var g: = _build(name, s, Vector2.ZERO)
	if g.is_empty():
		return
	g.auto = auto
	_start(g)
	if auto:
		_last_gesture = name
	gesture_started.emit(name)


func _start(g: Dictionary) -> void:
	g.t = 0.0
	g.t0 = t
	g.kind = g.get("kind", g.name)
	for k in g.tracks.keys():
		g.tracks[k] = PackedFloat32Array(g.tracks[k])
	actions.append(g)


func _build(name: String, s: float, p: Vector2) -> Dictionary:
	# Each action: dur, tracks {channel: [t0, v0, t1, v1, ...]} (summed into the spring targets; smoothstep between
	# keys; the springs add the overshoot), face tracks (max-combined), mouth segments [t0, t1, shape], heart times.
	# Shape of most tracks: a small anticipation the other way, a quick attack, a long hold, a slower release.
	# s = side (+1 = towards the viewer's right). Amplitudes: px of body.png, degrees.
	match name:
		"hip_pop":
			# weight onto one leg, hip pushed out, shoulders counter-tilt, a small smile and a glance
			return {"name": name, "dur": 2.0, "side": s, "tracks": {
				"hip_x": [0.0, 0.0, 0.16, -5.0 * s, 0.42, 26.0 * s, 1.3, 23.0 * s, 2.0, 0.0],
				"hip_rot": [0.0, 0.0, 0.16, 0.8 * s, 0.42, -3.6 * s, 1.3, -3.2 * s, 2.0, 0.0],
				"hip_y": [0.0, 0.0, 0.42, -7.0, 1.3, -6.0, 2.0, 0.0],
				"spine": [0.0, 0.0, 0.2, -0.5 * s, 0.5, 2.6 * s, 1.3, 2.3 * s, 2.0, 0.0],
				"chest_rot": [0.0, 0.0, 0.25, 0.0, 0.55, 1.5 * s, 1.35, 1.3 * s, 2.0, 0.0],
				"head": [0.0, 0.0, 0.3, 0.0, 0.6, 3.0 * s, 1.4, 2.6 * s, 2.0, 0.0],
				"head_x": [0.0, 0.0, 0.6, -4.0 * s, 1.4, -3.0 * s, 2.0, 0.0],
				"thighL": [0.0, 0.0, 0.45, -1.2 * s, 1.3, -1.0 * s, 2.0, 0.0],
				"look_x": [0.0, 0.0, 0.5, 1.5 * s, 1.5, 1.5 * s, 2.0, 0.0],
				"tailL": [0.0, 0.0, 0.35, -3.0 * s, 0.7, 0.0],
				"tailR": [0.0, 0.0, 0.35, -2.0 * s, 0.7, 0.0],
				"blush": [0.0, 0.0, 0.5, 0.35, 1.5, 0.35, 2.0, 0.0]},
				"mouth": [[0.35, 1.6, "closed"]]}
		"lean_in":
			# she leans towards the viewer: +3% about the face, upper body forward, chin down, eyes up, blush, smile
			return {"name": name, "dur": 2.6, "side": s, "tracks": {
				"zoom": [0.0, 0.0, 0.18, -0.006, 0.7, 0.03, 1.9, 0.03, 2.6, 0.0],
				"lean": [0.0, 0.0, 0.18, -0.3, 0.7, 1.0, 1.9, 1.0, 2.6, 0.0],
				"head_y": [0.0, 0.0, 0.18, -2.0, 0.7, 5.0, 1.9, 5.0, 2.6, 0.0],
				"head": [0.0, 0.0, 0.7, 2.2 * s, 1.9, 2.0 * s, 2.6, 0.0],
				"neck": [0.0, 0.0, 0.7, 1.0 * s, 2.6, 0.0],
				"shrug": [0.0, 0.0, 0.7, 2.5, 1.9, 2.0, 2.6, 0.0],
				"cam_y": [0.0, 0.0, 0.7, -3.0, 2.6, 0.0],
				"look_y": [0.0, 0.0, 0.5, -2.2, 1.9, -2.2, 2.4, 0.0],
				"look_x": [0.0, 0.0, 0.5, -0.6 * s, 2.4, 0.0],
				"blush": [0.0, 0.0, 0.6, 0.85, 2.0, 0.85, 2.6, 0.0]},
				"mouth": [[0.3, 2.2, "closed"]]}
		"air_kiss":
			# head tilt, lips pucker, a wink, a heart floats up from her lips; then a smile
			return {"name": name, "dur": 2.4, "side": s, "hearts": [0.95], "tracks": {
				"head": [0.0, 0.0, 0.2, -1.5 * s, 0.55, 4.5 * s, 1.5, 4.0 * s, 2.4, 0.0],
				"head_x": [0.0, 0.0, 0.55, 5.0 * s, 1.5, 4.0 * s, 2.4, 0.0],
				"head_y": [0.0, 0.0, 0.2, -2.0, 0.55, 2.0, 2.4, 0.0],
				"zoom": [0.0, 0.0, 0.6, 0.012, 1.5, 0.01, 2.4, 0.0],
				"shrug": [0.0, 0.0, 0.55, 3.5, 1.4, 2.5, 2.4, 0.0],
				"chest_rot": [0.0, 0.0, 0.55, -1.0 * s, 2.4, 0.0],
				"hip_x": [0.0, 0.0, 0.6, -6.0 * s, 1.6, -5.0 * s, 2.4, 0.0],
				"tailL": [0.0, 0.0, 0.55, 2.0 * s, 0.9, 0.0],
				("wink_l" if s < 0.0 else "wink_r"): [0.0, 0.0, 0.55, 0.0, 0.65, 1.0, 1.35, 1.0, 1.47, 0.0],
				"blush": [0.0, 0.0, 0.5, 0.75, 2.0, 0.75, 2.4, 0.0]},
				"mouth": [[0.35, 1.2, "pucker"], [1.2, 2.1, "closed"]]}
		"tail_flick":
			# a head toss: dip the other way, toss, the twin tails whip and settle
			return {"name": name, "dur": 1.9, "side": s, "tracks": {
				"head": [0.0, 0.0, 0.16, -2.5 * s, 0.4, 6.5 * s, 0.75, 4.0 * s, 1.5, 0.0],
				"head_y": [0.0, 0.0, 0.16, 2.0, 0.4, -4.0, 1.4, 0.0],
				"head_x": [0.0, 0.0, 0.4, 4.0 * s, 1.4, 0.0],
				"neck": [0.0, 0.0, 0.4, 1.5 * s, 1.3, 0.0],
				"hip_x": [0.0, 0.0, 0.4, -6.0 * s, 1.5, 0.0],
				"shrug": [0.0, 0.0, 0.16, -1.5, 0.4, 3.0, 1.2, 0.0],
				"tailL": [0.0, 0.0, 0.2, 1.5 * s, 0.45, -7.5 * s, 0.8, -2.0 * s, 1.2, 0.0],
				"tailR": [0.0, 0.0, 0.2, 1.0 * s, 0.45, -5.5 * s, 0.8, -1.5 * s, 1.2, 0.0],
				"eyes_closed": [0.0, 0.0, 0.2, 0.0, 0.3, 1.0, 0.62, 1.0, 0.74, 0.0],
				"blush": [0.0, 0.0, 0.5, 0.3, 1.9, 0.0]},
				"mouth": [[0.2, 0.9, "small"], [0.9, 1.7, "closed"]]}
		"shoulder_roll":
			# slow coy shoulder roll with a sideways glance (s picks the shoulder)
			return {"name": name, "dur": 2.6, "side": s, "tracks": {
				"shrug": [0.0, 0.0, 0.7, 7.0, 1.3, 3.0, 2.0, 0.0],
				"chest_rot": [0.0, 0.0, 0.7, 2.6 * s, 1.5, -1.0 * s, 2.3, 0.0],
				"armR": [0.0, 0.0, 0.7, -3.0 if s > 0.0 else 1.0, 1.6, 0.0],
				"armL": [0.0, 0.0, 0.7, 2.0 if s < 0.0 else -0.5, 1.6, 0.0],
				"spine": [0.0, 0.0, 0.8, -0.8 * s, 2.2, 0.0],
				"head": [0.0, 0.0, 0.8, -3.0 * s, 1.8, -2.4 * s, 2.6, 0.0],
				"head_y": [0.0, 0.0, 0.8, 3.0, 2.0, 2.0, 2.6, 0.0],
				"look_x": [0.0, 0.0, 0.45, -3.8 * s, 1.6, -3.4 * s, 2.2, 0.0],
				"look_y": [0.0, 0.0, 0.45, 0.8, 1.6, 0.6, 2.2, 0.0],
				"hip_x": [0.0, 0.0, 0.9, 4.0 * s, 2.4, 0.0],
				"blush": [0.0, 0.0, 0.6, 0.55, 2.0, 0.55, 2.6, 0.0]},
				"mouth": [[0.3, 2.2, "closed"]]}
		"knee_in":
			# jealous, shy fidget: her thigh turns in (twice), the other knee bends, chin down, pout, glance away
			return {"name": name, "dur": 2.4, "side": s, "tracks": {
				"thighL": [0.0, 0.0, 0.14, 1.0, 0.4, -5.6, 0.75, -3.4, 1.05, -5.3, 1.7, -4.3, 2.4, 0.0],
				"thighR": [0.0, 0.0, 0.4, 1.0, 1.7, 0.8, 2.4, 0.0],
				"hip_y": [0.0, 0.0, 0.4, 3.0, 1.7, 2.5, 2.4, 0.0],
				"hip_rot": [0.0, 0.0, 0.4, 1.4, 1.7, 1.2, 2.4, 0.0],
				"hip_x": [0.0, 0.0, 0.4, -4.0, 1.7, -3.0, 2.4, 0.0],
				"shrug": [0.0, 0.0, 0.35, 5.0, 1.7, 4.0, 2.4, 0.0],
				"head": [0.0, 0.0, 0.5, -2.5, 1.8, -2.0, 2.4, 0.0],
				"head_y": [0.0, 0.0, 0.5, 4.0, 1.8, 3.5, 2.4, 0.0],
				"look_x": [0.0, 0.0, 0.4, 3.0, 1.0, 3.0, 1.3, -0.5, 2.2, 0.0],
				"look_y": [0.0, 0.0, 0.4, 1.2, 1.0, 1.2, 1.3, -1.2, 2.2, 0.0],
				"blush": [0.0, 0.0, 0.4, 0.9, 2.0, 0.9, 2.4, 0.0]},
				"mouth": [[0.3, 1.5, "pout"], [1.5, 2.2, "closed"]]}
		"hair_touch":
			# the raised hand plays with her hair: the hand twirls (two loops), the elbow lifts, she leans into it
			var tw: = []
			var tw2: = []
			for i in 13:
				var x: = 0.25 + i * 0.12
				var e: = _env(x - 0.25, 0.25, 0.9, 0.35)
				tw.append_array([x, cos(TAU_ * 1.4 * (x - 0.25)) * 7.5 * e - 4.0 * e])
				tw2.append_array([x, sin(TAU_ * 1.4 * (x - 0.25)) * 6.5 * e - 5.0 * e])
			tw.append_array([2.3, 0.0])
			tw2.append_array([2.3, 0.0])
			return {"name": name, "dur": 2.4, "side": 1.0, "tracks": {
				"ikL_x": tw, "ikL_y": tw2,
				"armL": [0.0, 0.0, 0.15, -1.0, 0.45, 4.0, 1.6, 3.5, 2.3, 0.0],
				"head": [0.0, 0.0, 0.5, 3.5, 1.7, 3.0, 2.4, 0.0],
				"head_x": [0.0, 0.0, 0.5, 3.0, 2.4, 0.0],
				"hip_x": [0.0, 0.0, 0.5, -6.0, 1.8, -5.0, 2.4, 0.0],
				"chest_rot": [0.0, 0.0, 0.5, 1.2, 2.4, 0.0],
				"tailR": [0.0, 0.0, 0.5, 2.5, 1.0, -1.5, 1.5, 0.0],
				"look_x": [0.0, 0.0, 0.4, 2.8, 1.6, 2.4, 2.2, 0.0],
				"look_y": [0.0, 0.0, 0.4, -0.8, 2.2, 0.0],
				"blush": [0.0, 0.0, 0.5, 0.5, 2.0, 0.5, 2.4, 0.0]},
				"mouth": [[0.2, 1.0, "small"], [1.0, 2.2, "closed"]]}
		# ---- reactions
		"nuzzle":
			# head tap: she nuzzles into the touch, eyes ^^, blush, a happy bounce, a laugh
			return {"name": name, "kind": "react", "dur": 2.6, "side": s, "tracks": {
				"head": [0.0, 0.0, 0.1, -1.0 * s, 0.35, 5.0 * s, 1.6, 4.2 * s, 2.5, 0.0],
				"head_x": [0.0, 0.0, 0.35, 6.0 * s, 1.6, 5.0 * s, 2.5, 0.0],
				"head_y": [0.0, 0.0, 0.1, -2.0, 0.35, 3.0, 1.6, 2.0, 2.5, 0.0],
				"neck": [0.0, 0.0, 0.35, 2.0 * s, 2.3, 0.0],
				"cam_y": [0.0, 0.0, 0.12, 4.0, 0.3, -14.0, 0.5, 2.0, 0.7, -9.0, 0.95, 0.0],
				"shrug": [0.0, 0.0, 0.3, 6.0, 0.55, 2.0, 0.8, 5.0, 1.6, 3.0, 2.4, 0.0],
				"hip_x": [0.0, 0.0, 0.4, -5.0 * s, 1.8, 0.0],
				"tailL": [0.0, 0.0, 0.3, 4.0 * s, 0.7, -2.0 * s, 1.1, 0.0],
				"tailR": [0.0, 0.0, 0.3, 3.0 * s, 0.7, -1.5 * s, 1.1, 0.0],
				"eyes_happy": [0.0, 0.0, 0.08, 1.0, 1.9, 1.0, 2.1, 0.0],
				"blush": [0.0, 0.0, 0.3, 1.0, 2.2, 1.0, 2.6, 0.0]},
				"mouth": [[0.08, 0.9, "open"], [0.9, 1.3, "ah"], [1.3, 2.3, "closed"]]}
		"pout":
			# 3+ quick taps: "hey!" pout with puffed cheeks and frown for ~1 s, a huff, then a giggle
			var gig: = []
			var x2: = 1.25
			var shapes: = ["open", "ah", "open", "small", "open", "ah", "closed"]
			for i in shapes.size():
				gig.append([x2, x2 + 0.13, shapes[i]])
				x2 += 0.13
			gig.append([x2, 2.7, "closed"])
			return {"name": name, "kind": "react", "dur": 2.8, "side": s, "tracks": {
				"head": [0.0, 0.0, 0.12, 4.0 * s, 0.3, -5.0 * s, 0.5, -3.0 * s, 0.7, -4.5 * s, 1.15, -4.0 * s, 1.4, 2.0 * s, 2.8, 0.0],
				"head_y": [0.0, 0.0, 0.25, -3.0, 1.1, -2.5, 1.4, 2.5, 2.8, 0.0],
				"shrug": [0.0, 0.0, 0.25, 7.0, 0.5, 4.0, 1.1, 5.0, 1.3, 2.0,
						1.45, 4.0, 1.6, 1.5, 1.75, 3.5, 1.9, 1.5, 2.05, 3.0, 2.8, 0.0],
				"hip_x": [0.0, 0.0, 0.3, -10.0 * s, 1.1, -9.0 * s, 1.6, 4.0 * s, 2.8, 0.0],
				"hip_rot": [0.0, 0.0, 0.3, 2.0 * s, 1.1, 1.8 * s, 1.6, 0.0],
				"look_x": [0.0, 0.0, 0.25, -2.5 * s, 1.1, -2.5 * s, 1.3, 0.0],
				"tailL": [0.0, 0.0, 0.3, -3.5 * s, 0.7, 0.0, 1.5, 1.5, 1.9, 0.0],
				"tailR": [0.0, 0.0, 0.3, -2.5 * s, 0.7, 0.0],
				"eyes_frown": [0.0, 0.0, 0.08, 1.0, 1.15, 1.0, 1.25, 0.0],
				"eyes_happy": [0.0, 0.0, 1.2, 0.0, 1.3, 1.0, 2.3, 1.0, 2.5, 0.0],
				"blush": [0.0, 0.0, 0.2, 1.0, 2.4, 1.0, 2.8, 0.0]},
				"mouth": [[0.05, 1.2, "pout"]] + gig}
		"look":
			# background or outfit tap: eyes and head follow the point (p = art px), then a playful smile + wink
			var d: = p - face_pivot
			var lx: = clampf(d.x / 260.0, -1.0, 1.0)
			var ly: = clampf(d.y / 420.0, -1.0, 1.0)
			var ws: = "wink_r" if lx > 0.0 else "wink_l"
			return {"name": name, "kind": "react", "dur": 2.3, "side": signf(lx), "tracks": {
				"look_x": [0.0, 0.0, 0.12, lx * 4.2, 1.5, lx * 4.0, 2.0, 0.0],
				"look_y": [0.0, 0.0, 0.12, ly * 1.8, 1.5, ly * 1.6, 2.0, 0.0],
				"head": [0.0, 0.0, 0.08, 0.0, 0.4, lx * 4.2, 1.5, lx * 3.8, 2.2, 0.0],
				"head_x": [0.0, 0.0, 0.08, 0.0, 0.4, lx * 6.5, 1.5, lx * 6.0, 2.2, 0.0],
				"head_y": [0.0, 0.0, 0.4, ly * 5.0, 1.5, ly * 4.0, 2.2, 0.0],
				"neck": [0.0, 0.0, 0.45, lx * 1.5, 2.2, 0.0],
				"hip_x": [0.0, 0.0, 0.5, lx * 6.0, 2.2, 0.0],
				"cam_x": [0.0, 0.0, 0.4, lx * 3.0, 2.2, 0.0],
				"bg_x": [0.0, 0.0, 0.4, -lx * 6.0, 2.2, 0.0],
				ws: [0.0, 0.0, 1.45, 0.0, 1.55, 1.0, 1.8, 1.0, 1.92, 0.0],
				"blush": [0.0, 0.0, 1.3, 0.0, 1.6, 0.45, 2.3, 0.0]},
				"mouth": [[0.1, 1.3, "small"], [1.3, 2.2, "closed"]]}
		"wave":
			# hand tap: the hand lifts off the hip a little and wags (a playful «no-no»), she winks
			var wag: = [0.0, 0.0, 0.2, 4.0]
			for i in 6:
				wag.append_array([0.32 + i * 0.15, (-5.0 if i % 2 == 0 else 3.5)])
			wag.append_array([1.4, 0.0])
			return {"name": name, "kind": "react", "dur": 2.0, "side": s, "tracks": {
				"ikR_x": [0.0, 0.0, 0.1, -2.0, 0.25, 12.0, 1.3, 11.0, 1.7, 0.0],  # along the arc around the shoulder: the elbow keeps its angle
				"ikR_y": [0.0, 0.0, 0.25, -5.0, 1.3, -4.0, 1.7, 0.0],
				"handR": wag,  # a -5/+3.5 deg wag about the wrist
				"armR": [0.0, 0.0, 0.25, -2.0, 1.3, -2.0, 1.7, 0.0],
				"shrug": [0.0, 0.0, 0.25, 3.0, 1.4, 0.0],
				"head": [0.0, 0.0, 0.3, -3.0, 1.5, -2.5, 2.0, 0.0],
				"head_y": [0.0, 0.0, 0.3, 2.0, 2.0, 0.0],
				"hip_x": [0.0, 0.0, 0.3, 5.0, 1.6, 0.0],
				"look_x": [0.0, 0.0, 0.2, -2.5, 0.9, -2.0, 1.1, 0.0],
				"look_y": [0.0, 0.0, 0.2, 1.2, 0.9, 1.0, 1.1, 0.0],
				"wink_l": [0.0, 0.0, 1.05, 0.0, 1.15, 1.0, 1.5, 1.0, 1.62, 0.0],
				"blush": [0.0, 0.0, 0.3, 0.4, 2.0, 0.0]},
				"mouth": [[0.15, 0.7, "ah"], [0.7, 1.1, "small"], [1.1, 1.8, "closed"]]}
	return {}


func _cancel_auto() -> void:
	# a reaction replaces whatever gesture or reaction is playing (the springs blend the pose over)
	for a in actions.duplicate():
		if a.get("auto", false) or a.kind == "react":
			actions.erase(a)


# ---------------------------------------------------------------- public API

func appear() -> void:
	# 0.6 s pop: scale 0.9 -> 1.04 -> 1.0 (back-out), fade in, a small rise; springs swing from the motion
	if _appear_tw:
		_appear_tw.kill()
	_appear_scale = 0.9
	# fade the figure as ONE picture (inside a CanvasGroup for the 0.22 s fade): fading the layers one by one
	# would let the under-paintings show through each other
	var cg: CanvasGroup = figure.get_parent() as CanvasGroup
	if cg == null:
		cg = CanvasGroup.new()
		cg.name = "FadeGroup"
		add_child(cg)
		move_child(cg, figure.get_index())
		figure.reparent(cg, false)
	cg.self_modulate.a = 0.0
	var lift: = Vector2(0, 26)
	_figure_base_pos += lift
	_appear_tw = create_tween().set_parallel(true)
	_appear_tw.tween_property(self, "_appear_scale", 1.0, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_appear_tw.tween_property(cg, "self_modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_appear_tw.tween_method(func(v: Vector2) -> void: _figure_base_pos = v, _figure_base_pos, _figure_base_pos - lift, 0.6) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_appear_tw.chain().tween_callback(func() -> void:
		var i: = cg.get_index()
		figure.reparent(self, false)
		move_child(figure, i)
		cg.queue_free())
	_start({"name": "appear", "kind": "appear", "dur": 1.4, "tracks": {
		"tailL": [0.0, 0.0, 0.2, 3.0, 0.45, 0.0], "tailR": [0.0, 0.0, 0.2, -2.5, 0.45, 0.0],
		"head": [0.0, 0.0, 0.3, 2.0, 1.2, 0.0]},
		"mouth": [[0.0, 1.2, "small"]]})


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
	_start({"name": "wink", "kind": "wink", "dur": 0.5, "tracks": {("wink_l" if left else "wink_r"): [0.0, 0.0, 0.09, 1.0, 0.34, 1.0, 0.48, 0.0]}})


func look_at_global(p: Vector2, hold: = 1.5) -> void:
	var g: = _build("look", 1.0, art.get_global_transform().affine_inverse() * p)
	g.dur = hold + 0.8
	_start(g)


func tap(global_pos: Vector2) -> String:
	var p: = art.get_global_transform().affine_inverse() * global_pos
	var zone: = zone_at(p)
	if zone != "none":
		# 3 or more quick taps anywhere (not on a dead zone) -> pout
		_tap_times.append(t)
		while _tap_times.size() > 0 and t - float(_tap_times[0]) > 1.3:
			_tap_times.pop_front()
		if _tap_times.size() >= 3:
			_tap_times.clear()
			_react_kind("pout", p)
		else:
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
	var p: = face_pivot + Vector2(300, 0)
	if at_global != Vector2.INF:
		p = art.get_global_transform().affine_inverse() * at_global
	var kind: String = {"head": "nuzzle", "armL": "hair_touch", "armR": "wave", "hair": "tail_flick",
			"outfit": "look", "bg": "look"}.get(zone, "look")
	_react_kind(kind, p)


func _react_kind(kind: String, p: Vector2) -> void:
	_cancel_auto()
	var s: = signf(p.x - art_pos["head"].x)
	if s == 0.0:
		s = 1.0
	var g: = _build(kind, s, p)
	if g.is_empty():
		return
	g.kind = "react"
	_start(g)
	_last_reaction_t = t
	_next_gesture = maxf(_next_gesture, rng.randf_range(gesture_gap.x, gesture_gap.y) * 0.6)


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

var _strain_cache: = []


func strain_tris() -> Array:
	# centroids (art px) of the triangles measure_strain() reports in "per_tri", same order (all layers)
	var out: = []
	for L in _strain_cache:
		var poly: Polygon2D = L.poly
		for tri in L.tris:
			out.append((poly.polygon[tri[0]] + poly.polygon[tri[1]] + poly.polygon[tri[2]]) / 3.0)
	return out


func measure_strain() -> Dictionary:
	# CPU re-run of the skinning (same math as the GPU) to find the worst local stretch of the current pose, over
	# every mesh layer. Per triangle: singular values s1 >= s2 of the rest->posed linear map; aniso = s1/s2 - 1
	# (shape change), area = s1*s2 - 1. Only triangles over opaque art count (alpha sampled at the centroid's UV).
	# Slow: dev only.
	if _strain_cache.is_empty():
		var imgs: = []
		for poly in layers:
			var im: = poly.texture.get_image()
			if im.is_compressed():
				im.decompress()
			imgs.append([im, poly.polygon[0] - poly.uv[0]])  # [image, art offset of the texture]
		for li in layers.size():
			var poly: Polygon2D = layers[li]
			var img: Image = imgs[li][0]
			var tris: = []
			var hidden: = 0
			for tri in poly.polygons:
				# "over opaque art": at least 3 of 4 samples (centroid + edge midpoints) are opaque
				var u0: Vector2 = poly.uv[tri[0]]
				var u1: Vector2 = poly.uv[tri[1]]
				var u2: Vector2 = poly.uv[tri[2]]
				var hits: = 0
				for c in [(u0 + u1 + u2) / 3.0, (u0 + u1) * 0.5, (u1 + u2) * 0.5, (u2 + u0) * 0.5]:
					var px: = Vector2i(clampi(int(c.x), 0, img.get_width() - 1), clampi(int(c.y), 0, img.get_height() - 1))
					if img.get_pixelv(px).a > 0.5:
						hits += 1
				if hits < 3:
					continue
				# the art's cut bottom edge sits under the screen by design: not part of the picture
				if maxf(poly.polygon[tri[0]].y, maxf(poly.polygon[tri[1]].y, poly.polygon[tri[2]].y)) > float(def.size[1]) - 6.0:
					continue
				# hidden at rest under a layer drawn in front (under-painting): not seen unless a part slides far,
				# so it is left out of the visible strain
				var ca: Vector2 = (poly.polygon[tri[0]] + poly.polygon[tri[1]] + poly.polygon[tri[2]]) / 3.0
				var covered: = false
				for lj in range(li + 1, layers.size()):
					var im2: Image = imgs[lj][0]
					var q: Vector2 = ca - (imgs[lj][1] as Vector2)
					if q.x >= 0 and q.y >= 0 and q.x < im2.get_width() and q.y < im2.get_height() and im2.get_pixelv(Vector2i(q)).a > 0.9:
						covered = true
						break
				if covered:
					hidden += 1
					continue
				tris.append(tri)
			var bl: = []
			for i in poly.get_bone_count():
				var bn: Bone2D = skel.get_node(poly.get_bone_path(i))
				bl.append({"bone": bn, "w": poly.get_bone_weights(i), "rest": art_pos[str(bn.name)]})
			_strain_cache.append({"poly": poly, "name": str(poly.name), "tris": tris, "bones": bl, "hidden": hidden})
	var inv: = art.get_global_transform().affine_inverse()
	var worst: = 0.0
	var worst_at: = Vector2.ZERO
	var worst_layer: = ""
	var vals: = PackedFloat32Array()
	var per_tri: = PackedFloat32Array()
	var per_layer: = {}
	var disp: = 0.0
	for L in _strain_cache:
		var poly: Polygon2D = L.poly
		var mats: = []
		for b in L.bones:
			mats.append(inv * (b.bone as Bone2D).get_global_transform() * Transform2D(0.0, -(b.rest as Vector2)))
		var src: = poly.polygon
		var dst: = PackedVector2Array()
		dst.resize(src.size())
		for v in src.size():
			var acc: = Vector2.ZERO
			var ws: = 0.0
			for i in mats.size():
				var w: float = L.bones[i].w[v]
				if w > 0.0:
					acc += w * ((mats[i] as Transform2D) * src[v])
					ws += w
			dst[v] = acc / ws if ws > 0.0 else src[v]
			disp = maxf(disp, (dst[v] - src[v]).length())
		var lw: = 0.0
		var lw_at: = Vector2.ZERO
		for tri in L.tris:
			var a0: Vector2 = src[tri[0]]
			var R: = Transform2D(src[tri[1]] - a0, src[tri[2]] - a0, Vector2.ZERO)
			var D: = Transform2D(dst[tri[1]] - dst[tri[0]], dst[tri[2]] - dst[tri[0]], Vector2.ZERO)
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
			if an > lw:
				lw = an
				lw_at = (src[tri[0]] + src[tri[1]] + src[tri[2]]) / 3.0
			if an > worst:
				worst = an
				worst_at = (src[tri[0]] + src[tri[1]] + src[tri[2]]) / 3.0
				worst_layer = L.name
		per_layer[L.name] = [lw, lw_at]
	var sorted: = vals.duplicate()
	sorted.sort()
	return {"max": worst, "at": worst_at, "layer": worst_layer, "p99": sorted[int(sorted.size() * 0.99)],
			"p999": sorted[int(sorted.size() * 0.999)], "tris": sorted.size(), "disp": disp, "per_tri": per_tri,
			"per_layer": per_layer}
