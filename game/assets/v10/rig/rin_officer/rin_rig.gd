extends V10LiveRig

# Рин (officer coat, art r4_rin) on the V10 living-illustration rig. Same engine (live_rig.gd: channel springs,
# layered idle, spring chains, face patches, strain probe), her own body language from docs/POSES.md:
# vertical, still, economical; straight parallel legs; she moves about half as fast as the others; she talks with
# her hands and with the look over her glasses; embarrassment shows as one detail. Gestures (autonomous, every
# 5-9 s, never the same twice in a row): over_glasses, adjust_glasses, fan_hide, smirk, settle, ponder.
# Reactions: head -> pat, fan hand -> fan_hide, gloved hand -> adjust_glasses, braid -> braid_flick,
# coat/room -> look, 3 quick taps -> huff. See README.md in this folder.
#
#   var rig = load("res://assets/v10/rig/rin_officer/rig.tscn").instantiate()   # this script is its root
#   rig.gesture("over_glasses"); rig.react("head", p); rig.talk(2.0)            # API = V10LiveRig

const RIN_GESTURES: = ["over_glasses", "adjust_glasses", "fan_hide", "smirk", "settle", "ponder"]
const RIN_MOUTHS: = ["laugh", "smirk", "ah", "oh", "pout"]  # patches; "closed" = the painted closed smile
const RIN_FACE: = ["over_glasses", "glint"]
# Her springs: lower frequencies (she moves about half as fast), a little more damping (less bounce, more poise).
const CH_RIN: = {
	"hip_x": [1.0, 0.55, 0.5], "hip_y": [1.2, 0.55, 0.5], "hip_rot": [1.0, 0.55, 0.5],
	"spine": [0.95, 0.58, 0.4], "chest_rot": [0.9, 0.58, 0.4], "shrug": [1.5, 0.5, 0.6], "lean": [1.0, 0.6, 0.3],
	"neck": [1.0, 0.56, 0.4], "head": [1.15, 0.5, 0.5], "head_x": [1.15, 0.52, 0.5], "head_y": [1.3, 0.52, 0.5],
	"zoom": [0.9, 0.65, 0.3], "cam_x": [0.9, 0.72, 0.3], "cam_y": [1.8, 0.42, 0.6], "bg_x": [0.8, 0.8, 0.0],
	"fa_x": [1.7, 0.5, 0.4], "fa_y": [1.7, 0.5, 0.4], "fa_rot": [1.6, 0.52, 0.4], "hand_rot": [2.2, 0.45, 0.5],
	"armR": [1.2, 0.55, 0.4], "handR": [1.8, 0.5, 0.5],
	"look_x": [4.5, 0.82, 0.0], "look_y": [4.5, 0.82, 0.0],
	"tailL": [2.2, 0.62, 0.4], "tailR": [2.4, 0.62, 0.4],
}

var _glint: Sprite2D
var _glint_mat: ShaderMaterial


func _init() -> void:
	motion = 0.75
	gesture_gap = Vector2(5.0, 9.0)
	parallax = 0.3


func _ready() -> void:
	super._ready()
	# the fan hand and the epaulette tassel draw over the face patches (the fan sits in front of her chin)
	for n in ["Layer_forearm", "Layer_tassel"]:
		var l: = art.get_node_or_null(n)
		if l:
			art.move_child(l, -1)
	layers.clear()
	for c in art.get_children():
		if c is Polygon2D:
			layers.append(c)
	_blink_in = rng.randf_range(2.0, 4.0)
	_next_gesture = rng.randf_range(3.0, 4.5)


func _setup_channels() -> void:
	var i: = 0
	for k in CH_RIN:
		var p: Array = CH_RIN[k]
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
	for c in RIN_FACE:
		face[c] = 0.0


func _setup_face() -> void:
	super._setup_face()
	var head: Bone2D = bones[def.face.bone]
	# order above the parent's: glasses-down look over the eyes, then her mouths
	for k in ["over_glasses", "mouth_laugh", "mouth_smirk", "mouth_ah", "mouth_oh", "mouth_pout"]:
		if patches.has(k):
			head.move_child(patches[k], -1)
	for m in RIN_MOUTHS:
		_mouth_a[m] = 0.0
	var g: Dictionary = def.face.get("glint", {})
	if not g.is_empty():
		_glint = Sprite2D.new()
		_glint.name = "Glint"
		_glint.texture = _tex(g.file)
		_glint.centered = false
		_glint.position = Vector2(g.box[0], g.box[1]) - art_pos[def.face.bone]
		var sh: = Shader.new()
		sh.code = """shader_type canvas_item;
render_mode blend_add;
uniform float phase = -1.0;
void fragment() {
	float m = texture(TEXTURE, UV).a;
	float x = UV.x * 0.85 + (1.0 - UV.y) * 0.5;
	float p = mix(-0.2, 1.55, phase);
	float d = abs(x - p);
	float band = smoothstep(0.11, 0.0, d) * 0.45 + smoothstep(0.035, 0.0, d) * 0.55;
	float d2 = abs(x - p + 0.16);
	band += smoothstep(0.025, 0.0, d2) * 0.3;
	COLOR = vec4(vec3(1.0, 0.96, 0.86) * band * m, 1.0);
}
"""
		_glint_mat = ShaderMaterial.new()
		_glint_mat.shader = sh
		_glint.material = _glint_mat
		_glint.visible = false
		head.add_child(_glint)


# ---------------------------------------------------------------- frame

func _update_idle_beats(delta: float) -> void:
	# her weight shifts are rarer and smaller; the eyes re-fixate less often (she watches, she does not scan)
	_beat_in -= delta
	if _beat_in <= 0.0:
		_beat_in = rng.randf_range(3.5, 7.0)
		var nb: = rng.randf_range(0.35, 0.8) * (-signf(_beat) if absf(_beat) > 0.2 else (1.0 if rng.randf() < 0.5 else -1.0))
		_beat = nb
	_sacc_in -= delta
	if _sacc_in <= 0.0:
		_sacc_in = rng.randf_range(1.2, 3.6)
		_sacc = Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-0.5, 0.5)) * 1.0
	if auto_gestures:
		_next_gesture -= delta
		var busy: = false
		for a in actions:
			if a.kind != "sigh":
				busy = true
		if t - _last_reaction_t < 2.5:
			busy = true
		if _next_gesture <= 0.0 and not busy:
			var pool: = []
			for g in RIN_GESTURES:
				if g != _last_gesture:
					pool.append(g)
			gesture(pool[rng.randi() % pool.size()], true)
			_next_gesture = rng.randf_range(gesture_gap.x, gesture_gap.y)
		elif _next_gesture <= 0.0:
			_next_gesture = 0.8


func _update_actions(delta: float) -> void:
	for c in RIN_FACE:
		face[c] = 0.0
	super._update_actions(delta)
	# the braid, the tassel and the earring take the impulse channels (tailL / tailR)
	_impulse_rot["braid"] = deg_to_rad(ch.tailL)
	_impulse_rot["tassel"] = deg_to_rad(ch.tailR)
	_impulse_rot["earR"] = deg_to_rad(ch.tailL * 1.6)


func _pose_body() -> void:
	var m: = motion
	# everything on longer, incommensurate periods than the default rig: she is slow and composed
	var sway: = _n([11.7, 17.9, 29.3], _seed.x) * m
	var drift: = _n([13.9, 21.1], _seed.y)
	var b: = breath + sigh * 0.8
	var lean: float = ch.lean
	var cam: = Vector2(drift * 6.0, _n([17.3, 11.9], _seed.z) * 2.5) * m + Vector2(ch.cam_x, ch.cam_y)
	var z: float = (1.0 + ch.zoom) * _appear_scale
	figure.scale = Vector2(z, z)
	var root_art: Vector2 = art_pos["root"]
	figure.position = _figure_base_pos + cam + (face_pivot - root_art) * (1.0 - z)
	if bg:
		bg.position = bg_base + cam * parallax + Vector2(ch.bg_x, 0.0)
	# still vertical: a small weight shift, parallel legs (no thigh bones), the spine counters it
	_pose("hips", Vector2(sway * 6.5 + ch.hip_x, -absf(sway) * 1.5 - b * 0.5 + ch.hip_y), deg_to_rad(-0.7 * sway + ch.hip_rot))
	_pose("spine", Vector2.ZERO, deg_to_rad(0.55 * sway + ch.spine - 0.15 * b))
	var head_drift: = _n([8.3, 13.1, 21.7], _seed.z) * m
	var nod: = _n([10.1, 15.7], _seed.w + 2.0) * m
	var hr: float = 1.8 * head_drift - 0.3 * sway + ch.head
	var hp: = Vector2(head_drift * 2.2 + ch.head_x, nod * 1.6 + ch.head_y)
	var chest: Bone2D = bones["chest"]
	chest.position = rest["chest"] + Vector2(0, -b * 3.6 - ch.shrug * 0.4 + lean * 2.0) + hp * 0.3
	chest.rotation = deg_to_rad(0.35 * sway + 0.35 * _n([9.1, 14.3], _seed.w) * m + ch.chest_rot + 0.3 * hr)
	chest.scale = Vector2(1.0 + 0.004 * b + 0.006 * lean, 1.0 + 0.010 * b + 0.006 * lean)
	_pose("neck", hp * 0.25 + Vector2(0, -0.2 * ch.shrug), deg_to_rad(0.25 * hr - 0.2 * sway + ch.neck))
	var head: Bone2D = bones["head"]
	head.rotation = deg_to_rad(0.45 * hr)
	head.position = rest["head"] + hp * 0.35 + Vector2(0.0, b * 0.5)
	head.scale = Vector2.ONE * (1.0 + 0.016 * lean)
	# the fan hand: the forearm pivots at the elbow, the hand (and the fan) at the wrist; a slow idle drift
	_pose("forearm", Vector2(ch.fa_x, ch.fa_y - 0.6 * ch.shrug), deg_to_rad(ch.fa_rot + 0.45 * _n([7.9, 12.3], _seed.y) * m - 0.2 * b))
	_pose("hand", Vector2.ZERO, deg_to_rad(ch.hand_rot + 0.7 * _n([5.9, 9.4], _seed.x) * m))
	# the hanging arm hangs from the hips bone (it moves with the skirt it touches; its shoulder is under the braid)

	_pose("armR", Vector2(0, -0.5 * ch.shrug), deg_to_rad(ch.armR + 0.2 * _n([6.3, 9.7], _seed.y) * m))
	_pose("handR", Vector2.ZERO, deg_to_rad(ch.handR + 0.9 * _n([4.3, 6.9], _seed.w) * m))
	var look: = Vector2(clampf(ch.look_x, -iris_range.x, iris_range.x), clampf(ch.look_y, -iris_range.y, iris_range.y))
	for e in irises:
		(e.mat as ShaderMaterial).set_shader_parameter("offset_px", look)


func _update_face(delta: float) -> void:
	# she blinks about half as often as the others (POSES.md)
	_blink_in -= delta
	if _blink_in <= 0.0 and _blink_t < 0.0:
		_blink_t = 0.0
		_blink_double = rng.randf() < 0.12
		_blink_in = rng.randf_range(4.5, 8.5)
	var blink_a: = 0.0
	if _blink_t >= 0.0:
		_blink_t += delta
		blink_a = _blink_curve(_blink_t)
		if _blink_double:
			blink_a = maxf(blink_a, _blink_curve(_blink_t - 0.28))
		if _blink_t > (0.56 if _blink_double else 0.28):
			_blink_t = -1.0
	var og: float = face.over_glasses
	var happy: float = face.eyes_happy * (1.0 - og)
	var frown: float = face.eyes_frown * (1.0 - happy) * (1.0 - og)
	var closed: = maxf(blink_a * (1.0 - og), face.eyes_closed) * (1.0 - happy)
	_alpha("over_glasses", og)
	_alpha("eyes_happy", happy)
	_alpha("eyes_frown", frown * (1.0 - closed))
	_alpha("eyes_closed", closed)
	var open_a: = (1.0 - closed) * (1.0 - happy) * (1.0 - og)
	_alpha("eyeL_closed", face.wink_l * open_a)
	_alpha("eyeR_closed", face.wink_r * open_a)
	_alpha("blush", face.blush * 0.7)
	if _glint:
		var gp: float = face.glint
		_glint.visible = gp > 0.001 and gp < 0.999
		_glint_mat.set_shader_parameter("phase", gp)
	_update_talk(delta)
	var shape: String = {"open": "laugh", "pucker": "oh", "small": "closed"}.get(mouth_state, mouth_state)
	var f: = 1.0 - exp(-delta / 0.035)
	for mo in RIN_MOUTHS:
		_mouth_a[mo] = lerpf(_mouth_a[mo], 1.0 if shape == mo else 0.0, f)
		_alpha("mouth_" + mo, _mouth_a[mo])


func _update_talk(delta: float) -> void:
	if _ext_level >= 0.0:
		var l: = _ext_level
		mouth_state = "closed" if l < 0.12 else ("oh" if l < 0.35 else ("ah" if l < 0.65 else "laugh"))
		return
	var on: = _talking or _talk_left > 0.0
	_talk_left = maxf(0.0, _talk_left - delta)
	if not on:
		if _syll_in > -1.0:
			_syll_in = -1.0
		return
	_syll_in -= delta
	if _syll_in <= 0.0:
		# she speaks evenly and does not open her mouth wide: mostly 'ah' / 'oh' / closed, a rare open vowel
		var r: = rng.randf()
		var nxt: = "ah" if r < 0.36 else ("oh" if r < 0.58 else ("laugh" if r < 0.66 else "closed"))
		if nxt == mouth_state:
			nxt = "closed" if mouth_state != "closed" else "ah"
		mouth_state = nxt
		_syll_in = rng.randf_range(0.09, 0.18) * (1.5 if nxt == "closed" else 1.0)


# ---------------------------------------------------------------- her gestures and reactions

func react(zone: String, at_global: = Vector2.INF) -> void:
	var p: = face_pivot + Vector2(300, 0)
	if at_global != Vector2.INF:
		p = art.get_global_transform().affine_inverse() * at_global
	var kind: String = {"head": "pat", "armL": "fan_hide", "armR": "adjust_glasses", "hair": "braid_flick",
			"outfit": "look", "bg": "look"}.get(zone, "look")
	_react_kind(kind, p)


func _build(name: String, s: float, p: Vector2) -> Dictionary:
	# Units: px of body.png, degrees, zoom = fraction. s = side (+1 = viewer's right). Shape of every track:
	# anticipation -> attack -> long hold -> slower release; her springs (CH_RIN) are slower and damped.
	match name:
		"over_glasses":
			# chin dips, the glasses slide down her nose and she looks at you over the rims, a knowing smirk
			return {"name": name, "dur": 3.6, "side": s, "tracks": {
				"head_y": [0.0, 0.0, 0.3, -1.0, 0.9, 4.0, 2.7, 3.6, 3.6, 0.0],
				"head": [0.0, 0.0, 0.9, -2.0 * s, 2.7, -1.8 * s, 3.6, 0.0],
				"neck": [0.0, 0.0, 0.9, 1.0, 3.6, 0.0],
				"zoom": [0.0, 0.0, 1.0, 0.012, 2.7, 0.012, 3.6, 0.0],
				"shrug": [0.0, 0.0, 0.9, 1.5, 2.8, 1.0, 3.6, 0.0],
				"fa_y": [0.0, 0.0, 0.9, -2.0, 2.8, -2.0, 3.6, 0.0],
				"over_glasses": [0.0, 0.0, 0.62, 0.0, 0.74, 1.0, 2.78, 1.0, 2.9, 0.0],
				"blush": [0.0, 0.0, 0.9, 0.35, 3.0, 0.35, 3.6, 0.0]},
				"mouth": [[0.9, 3.0, "smirk"]]}
		"adjust_glasses":
			# a glance over the slipped glasses, then the fan pushes them back up: glint across the lenses
			return {"name": name, "dur": 3.4, "side": s, "tracks": {
				"over_glasses": [0.0, 0.0, 0.25, 0.0, 0.35, 1.0, 1.12, 1.0, 1.24, 0.0],
				"fa_y": [0.0, 0.0, 0.7, 2.0, 1.05, -11.0, 1.5, -10.0, 2.5, 0.0],
				"fa_rot": [0.0, 0.0, 1.05, 1.2, 1.5, 1.0, 2.5, 0.0],
				"hand_rot": [0.0, 0.0, 0.7, 1.0, 1.05, -3.0, 1.5, -2.5, 2.5, 0.0],
				"head_y": [0.0, 0.0, 0.3, 3.0, 1.1, 3.0, 1.35, -1.5, 2.4, 0.0],
				"head": [0.0, 0.0, 0.4, -1.5, 1.2, -1.2, 1.5, 1.0, 3.0, 0.0],
				"shrug": [0.0, 0.0, 1.05, 1.5, 2.2, 0.0],
				"glint": [0.0, 0.0, 1.2, 0.0, 1.7, 1.0],
				"tailL": [0.0, 0.0, 1.3, 1.5, 1.9, 0.0],
				"blush": [0.0, 0.0, 0.6, 0.25, 3.0, 0.25, 3.4, 0.0]},
				"mouth": [[0.35, 1.15, "smirk"], [1.5, 3.0, "smirk"]]}
		"fan_hide":
			# the fan rises over her lips; she laughs quietly behind it, eyes ^^, shoulders shake a little
			return {"name": name, "dur": 3.4, "side": s, "tracks": {
				"fa_y": [0.0, 0.0, 0.3, 2.0, 0.75, -12.0, 2.4, -11.0, 3.3, 0.0],
				"fa_rot": [0.0, 0.0, 0.75, 1.6, 2.4, 1.4, 3.3, 0.0],
				"hand_rot": [0.0, 0.0, 0.75, -2.0, 2.4, -1.8, 3.3, 0.0],
				"head": [0.0, 0.0, 0.8, -2.5, 2.4, -2.2, 3.4, 0.0],
				"head_x": [0.0, 0.0, 0.8, -3.0, 2.4, -2.5, 3.4, 0.0],
				"shrug": [0.0, 0.0, 0.75, 3.0, 1.0, 1.5, 1.25, 3.0, 1.5, 1.5, 2.4, 1.0, 3.4, 0.0],
				"eyes_happy": [0.0, 0.0, 0.7, 0.0, 0.82, 1.0, 2.3, 1.0, 2.45, 0.0],
				"blush": [0.0, 0.0, 0.7, 0.9, 2.8, 0.9, 3.4, 0.0]},
				"mouth": [[0.6, 2.4, "laugh"], [2.4, 3.2, "smirk"]]}
		"smirk":
			# the head turns a touch away, the eyes stay on you, the corner of the mouth lifts, a slow wink
			return {"name": name, "dur": 3.2, "side": s, "tracks": {
				"head": [0.0, 0.0, 0.2, 1.0 * s, 0.9, -3.0 * s, 2.6, -2.6 * s, 3.2, 0.0],
				"head_x": [0.0, 0.0, 0.9, -3.0 * s, 3.2, 0.0],
				"look_x": [0.0, 0.0, 0.6, 2.2 * s, 2.6, 2.0 * s, 3.1, 0.0],
				"hip_x": [0.0, 0.0, 1.0, 3.0 * s, 3.2, 0.0],
				("wink_r" if s > 0.0 else "wink_l"): [0.0, 0.0, 1.9, 0.0, 2.02, 1.0, 2.35, 1.0, 2.48, 0.0],
				"blush": [0.0, 0.0, 0.8, 0.4, 2.8, 0.4, 3.2, 0.0]},
				"mouth": [[0.6, 2.9, "smirk"]]}
		"settle":
			# posture: a slow breath with the eyes closed, the shoulders drop, the spine lengthens
			return {"name": name, "dur": 3.6, "side": s, "tracks": {
				"hip_y": [0.0, 0.0, 0.6, 2.0, 1.4, -3.0, 2.8, -2.0, 3.6, 0.0],
				"shrug": [0.0, 0.0, 0.6, 3.0, 1.4, -2.5, 2.8, -2.0, 3.6, 0.0],
				"head_y": [0.0, 0.0, 0.6, 1.5, 1.4, -2.5, 2.8, -2.0, 3.6, 0.0],
				"chest_rot": [0.0, 0.0, 1.2, 0.8 * s, 3.6, 0.0],
				"eyes_closed": [0.0, 0.0, 0.9, 0.0, 1.12, 1.0, 1.9, 1.0, 2.12, 0.0],
				"tailL": [0.0, 0.0, 1.2, 1.8 * s, 1.8, -0.8 * s, 2.4, 0.0],
				"tailR": [0.0, 0.0, 1.2, 1.5 * s, 2.0, 0.0]},
				"mouth": [[1.4, 2.0, "oh"]]}
		"ponder":
			# thinking: the fan taps her chin twice, eyes up and to the side, 'hm', then a decided smirk
			return {"name": name, "dur": 3.6, "side": s, "tracks": {
				"hand_rot": [0.0, 0.0, 0.4, -1.6, 0.7, 0.8, 1.0, -1.6, 1.3, 0.8, 1.6, -0.5, 2.2, 0.0],
				"fa_y": [0.0, 0.0, 0.4, -3.0, 1.6, -3.0, 2.2, 0.0],
				"look_x": [0.0, 0.0, 0.4, 2.4, 2.0, 2.2, 2.6, 0.0],
				"look_y": [0.0, 0.0, 0.4, -1.1, 2.0, -1.0, 2.6, 0.0],
				"head": [0.0, 0.0, 0.5, 1.8, 2.2, 1.5, 3.0, 0.0],
				"head_y": [0.0, 0.0, 0.5, -1.5, 2.2, -1.2, 3.0, 0.0],
				"tailR": [0.0, 0.0, 0.7, 1.5, 1.3, -1.0, 1.9, 0.0],
				"blush": [0.0, 0.0, 2.2, 0.0, 2.6, 0.25, 3.6, 0.0]},
				"mouth": [[0.3, 1.7, "oh"], [2.2, 3.4, "smirk"]]}
		# ---- reactions
		"look":
			# coat or room tap: her eyes go first, the head follows only a little (she is still), then a smirk
			var d: = p - face_pivot
			var lx: = clampf(d.x / 260.0, -1.0, 1.0)
			var ly: = clampf(d.y / 420.0, -1.0, 1.0)
			return {"name": name, "kind": "react", "dur": 2.6, "side": signf(lx), "tracks": {
				"look_x": [0.0, 0.0, 0.12, lx * 2.6, 1.7, lx * 2.4, 2.2, 0.0],
				"look_y": [0.0, 0.0, 0.12, ly * 1.2, 1.7, ly * 1.1, 2.2, 0.0],
				"head": [0.0, 0.0, 0.15, 0.0, 0.55, lx * 2.4, 1.7, lx * 2.2, 2.5, 0.0],
				"head_x": [0.0, 0.0, 0.15, 0.0, 0.55, lx * 3.5, 1.7, lx * 3.2, 2.5, 0.0],
				"head_y": [0.0, 0.0, 0.55, ly * 2.5, 1.7, ly * 2.0, 2.5, 0.0],
				"neck": [0.0, 0.0, 0.6, lx * 0.8, 2.5, 0.0],
				"hip_x": [0.0, 0.0, 0.6, lx * 3.0, 2.5, 0.0],
				"cam_x": [0.0, 0.0, 0.5, lx * 2.0, 2.5, 0.0],
				"bg_x": [0.0, 0.0, 0.5, -lx * 4.0, 2.5, 0.0],
				("wink_r" if lx > 0.0 else "wink_l"): [0.0, 0.0, 1.6, 0.0, 1.72, 1.0, 2.0, 1.0, 2.12, 0.0],
				"blush": [0.0, 0.0, 1.4, 0.0, 1.7, 0.35, 2.6, 0.0]},
				"mouth": [[0.2, 1.4, "closed"], [1.4, 2.4, "smirk"]]}
		"pat":
			# head tap: eyes close into it, then ^^, a quiet laugh, she leans into the hand; restrained bounce
			return {"name": name, "kind": "react", "dur": 2.9, "side": s, "tracks": {
				"head": [0.0, 0.0, 0.12, -1.0 * s, 0.45, 3.0 * s, 1.8, 2.6 * s, 2.8, 0.0],
				"head_x": [0.0, 0.0, 0.45, 3.2 * s, 1.8, 2.8 * s, 2.8, 0.0],
				"head_y": [0.0, 0.0, 0.12, -1.0, 0.45, 2.5, 1.8, 2.0, 2.8, 0.0],
				"neck": [0.0, 0.0, 0.45, 1.2 * s, 2.4, 0.0],
				"cam_y": [0.0, 0.0, 0.15, 2.0, 0.4, -6.0, 0.7, 0.0],
				"shrug": [0.0, 0.0, 0.3, 3.5, 0.8, 1.5, 1.8, 1.0, 2.6, 0.0],
				"tailL": [0.0, 0.0, 0.35, 2.0 * s, 0.9, -0.8 * s, 1.4, 0.0],
				"eyes_closed": [0.0, 0.0, 0.08, 1.0, 0.86, 1.0, 0.96, 0.0],
				"eyes_happy": [0.0, 0.0, 0.88, 0.0, 0.98, 1.0, 2.2, 1.0, 2.36, 0.0],
				"blush": [0.0, 0.0, 0.3, 1.0, 2.4, 1.0, 2.9, 0.0]},
				"mouth": [[0.1, 0.9, "oh"], [0.9, 1.6, "laugh"], [1.6, 2.7, "smirk"]]}
		"pout", "huff":
			# 3+ quick taps: annoyed frown and pout with a small head shake, then a stern look over the glasses
			return {"name": "huff", "kind": "react", "dur": 3.0, "side": s, "tracks": {
				"head": [0.0, 0.0, 0.12, 3.0 * s, 0.3, -3.5 * s, 0.5, -2.0 * s, 0.7, -3.0 * s, 1.2, -2.5 * s, 1.5, 0.5 * s, 3.0, 0.0],
				"head_y": [0.0, 0.0, 0.25, -2.0, 1.2, -2.0, 1.5, 3.0, 2.6, 2.5, 3.0, 0.0],
				"shrug": [0.0, 0.0, 0.25, 5.0, 0.5, 3.0, 1.2, 3.0, 1.5, 0.0, 3.0, 0.0],
				"hip_x": [0.0, 0.0, 0.3, -6.0 * s, 1.2, -5.0 * s, 1.6, 0.0],
				"tailL": [0.0, 0.0, 0.3, -2.0 * s, 0.8, 0.0],
				"eyes_frown": [0.0, 0.0, 0.08, 1.0, 1.25, 1.0, 1.35, 0.0],
				"over_glasses": [0.0, 0.0, 1.38, 0.0, 1.5, 1.0, 2.6, 1.0, 2.72, 0.0],
				"blush": [0.0, 0.0, 0.2, 0.8, 2.6, 0.8, 3.0, 0.0]},
				"mouth": [[0.05, 1.3, "pout"], [1.5, 2.8, "smirk"]]}
		"braid_flick":
			# braid tap: a small proud head toss, the braid swings and settles, eyes closed, then a sideways smirk
			return {"name": name, "kind": "react", "dur": 2.6, "side": s, "tracks": {
				"head": [0.0, 0.0, 0.2, -2.0 * s, 0.5, 4.0 * s, 1.0, 2.5 * s, 2.0, 0.0],
				"head_y": [0.0, 0.0, 0.2, 1.5, 0.5, -2.5, 1.8, 0.0],
				"head_x": [0.0, 0.0, 0.5, 2.5 * s, 1.8, 0.0],
				"tailL": [0.0, 0.0, 0.25, 1.0 * s, 0.55, -3.5 * s, 1.0, -1.0 * s, 1.5, 0.0],
				"tailR": [0.0, 0.0, 0.5, -2.0 * s, 1.0, 0.0],
				"eyes_closed": [0.0, 0.0, 0.3, 0.0, 0.38, 1.0, 0.7, 1.0, 0.8, 0.0],
				"look_x": [0.0, 0.0, 0.8, -2.0 * s, 2.2, 0.0],
				"blush": [0.0, 0.0, 0.5, 0.3, 2.6, 0.0]},
				"mouth": [[0.8, 2.4, "smirk"]]}
	return super._build(name, s, p)


func _react_kind(kind: String, p: Vector2) -> void:
	super._react_kind("huff" if kind == "pout" else kind, p)
