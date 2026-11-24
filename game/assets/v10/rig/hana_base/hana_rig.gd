class_name V10HanaRig
extends V10LiveRig

# Хана (h_base) on the shared V10LiveRig engine. Same painting-only approach (one illustration, skinned layers,
# channel springs, chains, patches); this file only gives her her own body language (docs/POSES.md §3):
# runner energy — bounces on her toes, jogs in place, fist pumps, lunges at the viewer «На старт!», side
# stretches, shakes her bob and laughs, glances at the stopwatch, big grin and winks. Her idle mouth is the
# painted toothy grin; now and then she settles into a soft smile or a sly half-lidded smirk.
#
#   var rig: V10HanaRig = load("res://assets/v10/rig/hana_base/rig.tscn").instantiate()
#   (same API as V10LiveRig: appear(), gesture(name), react(zone, pos), tap(pos), look_at_global(), talk() ...)
#   rig.flirt_level = 0..10   unlocks lean_in / shy_peek (>= 6) and air_kiss (>= 9) in the autonomous pool
#
# Rig-specific channel aliases (engine channels this rig has no other use for, so the springs come for free):
#   "fist" -> ikL_x : wrist flick of the raised fist (deg)   (her raised arm has no IK pin)
# Extra face channel: eyes_half (sly half-lidded eyes, patch eyes_half.png).
# Extra track key: "sparks": [[t, "fist"|"head"|"eyeL"|"eyeR"], ...] — sun sparkles (drawn, no textures).

const HANA_GESTURES: = ["bounce_toes", "fist_pump", "hair_shake", "lunge_lean", "side_stretch", "stopwatch_glance",
		"wink_grin", "jog_in_place"]
const FLIRT_GESTURES: = ["lean_in", "shy_peek"]  # flirt_level >= 6
const KISS_GESTURES: = ["air_kiss"]  # flirt_level >= 9
const ALIAS: = {"fist": "ikL_x"}

@export var flirt_level: = 0

var _sparks: Node2D
var _micro_in: = 3.0
var _mood_in: = 9.0
var _eyes_half_a: = 0.0


func _init() -> void:
	idle_mouth = "open"  # her signature grin is the painted art itself


func _ready() -> void:
	super._ready()
	face["eyes_half"] = 0.0
	_sparks = _Sparks.new()
	_sparks.name = "Sparks"
	art.add_child(_sparks)
	_micro_in = rng.randf_range(2.0, 4.0)
	_mood_in = rng.randf_range(8.0, 14.0)


# ---------------------------------------------------------------- frame hooks

func _update_idle_beats(delta: float) -> void:
	# same as the engine's (weight-shift beats, saccades) but with Hana's gesture pool, small «ready» bounces
	# between gestures and a slow mood swap of the idle mouth (grin / soft smile)
	_beat_in -= delta
	if _beat_in <= 0.0:
		_beat_in = rng.randf_range(2.2, 4.8)
		_beat = rng.randf_range(0.5, 1.0) * (-signf(_beat) if absf(_beat) > 0.2 else (1.0 if rng.randf() < 0.5 else -1.0))
	_sacc_in -= delta
	if _sacc_in <= 0.0:
		_sacc_in = rng.randf_range(0.7, 2.6)
		_sacc = Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-0.5, 0.5)) * 1.1
	var busy: = false
	for a in actions:
		if a.kind != "sigh" and a.kind != "micro":
			busy = true
	if t - _last_reaction_t < 2.0:
		busy = true
	_mood_in -= delta
	if _mood_in <= 0.0 and not _talking and _talk_left <= 0.0:
		_mood_in = rng.randf_range(7.0, 15.0)
		idle_mouth = "open" if rng.randf() < 0.62 else "closed"
	_micro_in -= delta
	if _micro_in <= 0.0:
		_micro_in = rng.randf_range(3.5, 7.0)
		if not busy:
			_start(_micro_bounce())
	if auto_gestures:
		_next_gesture -= delta
		if _next_gesture <= 0.0 and not busy:
			var pool: = []
			for g in _pool():
				if g != _last_gesture:
					pool.append(g)
			gesture(pool[rng.randi() % pool.size()], true)
			_next_gesture = rng.randf_range(gesture_gap.x, gesture_gap.y)
		elif _next_gesture <= 0.0:
			_next_gesture = 0.6


func _pool() -> Array:
	var p: Array = HANA_GESTURES.duplicate()
	if flirt_level >= 6:
		p.append_array(FLIRT_GESTURES)
	if flirt_level >= 9:
		p.append_array(KISS_GESTURES)
	return p


func _update_actions(delta: float) -> void:
	face["eyes_half"] = 0.0  # the engine resets only its own face channels
	super._update_actions(delta)
	for a in actions:
		for sp in a.get("sparks", []):
			var at: float = sp[0]
			if a.t >= at and a.t - delta < at:
				_spawn_sparks(str(sp[1]))


func _pose_body() -> void:
	super._pose_body()
	# the raised fist: wrist flick channel + a small idle wobble (a runner's loose wrist)
	var wob: = 1.4 * _n([3.1, 5.3], _seed.w + 1.0) * motion
	var fist: Bone2D = bones["fistL"]
	fist.rotation = deg_to_rad(ch.ikL_x + wob)
	# her raised arm breathes a little on its own (it has no IK pin to keep it still)
	var arm: Bone2D = bones["armL_up"]
	arm.rotation += deg_to_rad(0.9 * _n([4.3, 7.1], _seed.x + 3.0) * motion)


func _update_face(delta: float) -> void:
	super._update_face(delta)
	var happy: float = face.eyes_happy
	var closed: = maxf(face.eyes_closed, 1.0 if _blink_t >= 0.0 and _blink_curve(_blink_t) > 0.5 else 0.0)
	var target: float = face.eyes_half * (1.0 - happy) * (1.0 - closed) * (1.0 - face.eyes_frown)
	_eyes_half_a = lerpf(_eyes_half_a, target, 1.0 - exp(-delta / 0.05))
	_alpha("eyes_half", _eyes_half_a)


# ---------------------------------------------------------------- actions

func _start(g: Dictionary) -> void:
	# rename rig-specific aliases to engine channels before the engine packs the tracks
	for k in ALIAS:
		if g.has("tracks") and g.tracks.has(k):
			g.tracks[ALIAS[k]] = g.tracks[k]
			g.tracks.erase(k)
	super._start(g)


func react(zone: String, at_global: = Vector2.INF) -> void:
	var p: = face_pivot + Vector2(300, 0)
	if at_global != Vector2.INF:
		p = art.get_global_transform().affine_inverse() * at_global
	var kind: String = {"head": "head_pat", "armL": "fist_pump", "armR": "hip_check", "hair": "hair_shake",
			"outfit": "jacket_tug", "bg": "look"}.get(zone, "look")
	_react_kind(kind, p)


func _micro_bounce() -> Dictionary:
	# two small springs on the balls of her feet between gestures (the signature «пружинит на носках»)
	return {"name": "micro_bounce", "kind": "micro", "dur": 1.3, "tracks": {
		"hip_y": [0.0, 0.0, 0.12, 2.5, 0.3, -6.0, 0.46, 2.0, 0.64, -5.0, 0.82, 1.0, 1.1, 0.0],
		"cam_y": [0.0, 0.0, 0.3, -2.0, 0.46, 0.5, 0.64, -2.0, 0.9, 0.0],
		"shrug": [0.0, 0.0, 0.3, 1.5, 0.46, -0.5, 0.64, 1.5, 1.0, 0.0]}}


func _build(name: String, s: float, p: Vector2) -> Dictionary:
	# Units as in the engine: px of body.png, degrees; s = side (+1 = towards the viewer's right).
	# Shape: anticipation -> quick attack -> hold -> slower release; the springs add the overshoot.
	match name:
		"bounce_toes":
			# ha.bounce_toes: three springs on her toes, hair flops, sleeves swing, fist bobs, a wink at the end
			var hy: = [0.0, 0.0]
			var cy: = [0.0, 0.0]
			var sh: = [0.0, 0.0]
			var arm: = [0.0, 0.0]
			var tl: = [0.0, 0.0]
			for i in 3:
				var b: = 0.12 + i * 0.42
				var amp: = 1.0 - i * 0.12
				hy.append_array([b, 5.0 * amp, b + 0.18, -14.0 * amp, b + 0.36, 3.0])
				cy.append_array([b + 0.18, -5.0 * amp, b + 0.36, 1.0])
				sh.append_array([b + 0.18, 3.5 * amp, b + 0.36, -1.0])
				arm.append_array([b + 0.18, -2.0 * amp, b + 0.36, 1.5])
				tl.append_array([b + 0.2, 3.5 * amp * (1.0 if i % 2 == 0 else -1.0), b + 0.38, 0.0])
			hy.append_array([1.75, 0.0])
			cy.append_array([1.7, 0.0])
			sh.append_array([1.7, 0.0])
			arm.append_array([1.7, 0.0])
			return {"name": name, "dur": 2.3, "side": s, "tracks": {
				"hip_y": hy, "cam_y": cy, "shrug": sh, "armL": arm, "tailL": tl, "tailR": tl.duplicate(),
				"thighL": [0.0, 0.0, 0.3, -0.8, 0.72, 0.8, 1.14, -0.6, 1.6, 0.0],
				"thighR": [0.0, 0.0, 0.3, 0.8, 0.72, -0.8, 1.14, 0.6, 1.6, 0.0],
				"fist": [0.0, 0.0, 0.3, -4.0, 0.5, 3.0, 0.72, -4.0, 0.92, 3.0, 1.14, -3.0, 1.6, 0.0],
				"head": [0.0, 0.0, 0.5, 1.5 * s, 1.5, 2.5 * s, 2.3, 0.0],
				("wink_l" if s < 0.0 else "wink_r"): [0.0, 0.0, 1.55, 0.0, 1.65, 1.0, 1.95, 1.0, 2.07, 0.0],
				"blush": [0.0, 0.0, 0.6, 0.25, 2.3, 0.0]},
				"sparks": [[1.66, "eyeL" if s < 0.0 else "eyeR"]]}
		"fist_pump":
			# «Йош!»: anticipation, two snappy pumps of the raised fist (elbow drives it), a hop, a shout, ^^ eyes
			return {"name": name, "dur": 2.3, "side": 1.0, "tracks": {
				"armL": [0.0, 0.0, 0.16, -1.8, 0.33, 6.5, 0.47, -3.0, 0.64, 6.0, 0.8, -4.5, 1.45, -3.0, 2.2, 0.0],
				"armL_lo": [0.0, 0.0, 0.33, -2.5, 0.47, 2.0, 0.64, -2.5, 0.8, 3.0, 1.45, 2.0, 2.2, 0.0],
				"fist": [0.0, 0.0, 0.33, 5.0, 0.47, -7.0, 0.64, 5.0, 0.8, -8.0, 1.45, -4.0, 2.2, 0.0],
				"hip_y": [0.0, 0.0, 0.33, 5.0, 0.47, -9.0, 0.64, 4.0, 0.8, -12.0, 1.2, -3.0, 2.2, 0.0],
				"cam_y": [0.0, 0.0, 0.47, -4.0, 0.64, 1.0, 0.8, -5.0, 1.4, 0.0],
				"chest_rot": [0.0, 0.0, 0.47, 1.6, 0.8, 2.2, 1.6, 1.0, 2.3, 0.0],
				"spine": [0.0, 0.0, 0.47, 0.8, 0.8, 1.2, 2.0, 0.0],
				"head": [0.0, 0.0, 0.3, -1.5, 0.5, 3.0, 0.82, 3.8, 1.6, 2.0, 2.3, 0.0],
				"head_y": [0.0, 0.0, 0.33, 2.0, 0.5, -2.5, 0.85, -3.0, 1.6, 0.0],
				"shrug": [0.0, 0.0, 0.33, -2.0, 0.47, 4.5, 0.64, -1.0, 0.8, 5.5, 1.5, 2.0, 2.3, 0.0],
				"tailL": [0.0, 0.0, 0.47, -3.0, 0.64, 1.0, 0.8, -4.0, 1.1, 0.0],
				"tailR": [0.0, 0.0, 0.47, -3.5, 0.64, 1.0, 0.8, -4.5, 1.1, 0.0],
				"eyes_happy": [0.0, 0.0, 0.4, 0.0, 0.48, 1.0, 1.3, 1.0, 1.42, 0.0],
				"blush": [0.0, 0.0, 0.5, 0.35, 2.3, 0.0]},
				"mouth": [[0.28, 0.42, "small"], [0.42, 1.32, "ah"], [1.32, 2.2, "open"]],
				"sparks": [[0.5, "fist"], [0.83, "fist"]]}
		"hair_shake":
			# shakes her bob and laughs: quick head shake, the bob whips side to side, giggle bounces, ^^ eyes
			var hd: = [0.0, 0.0]
			var hx: = [0.0, 0.0]
			var tl: = [0.0, 0.0]
			var tr: = [0.0, 0.0]
			for i in 6:
				var x: = 0.1 + i * 0.12
				var a: = (1.0 - i * 0.14) * (1.0 if i % 2 == 0 else -1.0) * s
				hd.append_array([x, 5.0 * a])
				hx.append_array([x, 3.0 * a])
				tl.append_array([x + 0.05, -6.5 * a])
				tr.append_array([x + 0.05, -6.0 * a])
			hd.append_array([1.0, 0.0, 1.4, 2.0 * s, 2.2, 0.0])
			hx.append_array([1.0, 0.0])
			tl.append_array([1.1, 0.0])
			tr.append_array([1.1, 0.0])
			return {"name": name, "dur": 2.3, "side": s, "tracks": {
				"head": hd, "head_x": hx, "tailL": tl, "tailR": tr,
				"neck": [0.0, 0.0, 0.2, 1.0 * s, 0.5, -1.0 * s, 0.9, 0.0],
				"shrug": [0.0, 0.0, 0.3, 2.0, 1.0, 3.0, 1.13, 0.5, 1.26, 3.0, 1.39, 0.5, 1.52, 2.5, 2.2, 0.0],
				"hip_y": [0.0, 0.0, 1.0, -2.0, 1.13, 1.0, 1.26, -3.0, 1.39, 1.0, 1.7, 0.0],
				"hip_x": [0.0, 0.0, 0.4, -4.0 * s, 1.6, 0.0],
				"eyes_happy": [0.0, 0.0, 0.1, 1.0, 1.75, 1.0, 1.9, 0.0],
				"blush": [0.0, 0.0, 0.3, 0.6, 2.0, 0.6, 2.3, 0.0]},
				"mouth": [[0.12, 1.0, "ah"], [1.0, 1.65, "open"], [1.65, 2.2, "open"]],
				"sparks": [[0.95, "head"]]}
		"lunge_lean":
			# «На старт!»: a runner's lunge towards the viewer — hips drop, she leans in (+4.5 % about the face),
			# chin down, eyes up, sly half-lidded smirk; then she springs back with a wink and her grin
			return {"name": name, "dur": 2.9, "side": s, "tracks": {
				"zoom": [0.0, 0.0, 0.2, -0.008, 0.62, 0.045, 1.6, 0.042, 2.2, 0.0],
				"lean": [0.0, 0.0, 0.2, -0.4, 0.62, 1.2, 1.6, 1.1, 2.2, 0.0],
				"hip_y": [0.0, 0.0, 0.2, -3.0, 0.62, 9.0, 1.6, 8.0, 1.9, -6.0, 2.2, 0.0],
				"hip_x": [0.0, 0.0, 0.2, 3.0 * s, 0.62, -10.0 * s, 1.6, -9.0 * s, 2.2, 0.0],
				"hip_rot": [0.0, 0.0, 0.62, 1.4 * s, 1.6, 1.2 * s, 2.2, 0.0],
				"chest_rot": [0.0, 0.0, 0.62, -1.6 * s, 1.6, -1.4 * s, 2.2, 0.0],
				"head_y": [0.0, 0.0, 0.2, -2.0, 0.62, 4.5, 1.6, 4.0, 2.0, -1.0, 2.4, 0.0],
				"head": [0.0, 0.0, 0.62, -2.5 * s, 1.6, -2.0 * s, 2.0, 2.5 * s, 2.9, 0.0],
				"shrug": [0.0, 0.0, 0.62, 3.0, 1.6, 2.5, 2.0, -1.0, 2.4, 0.0],
				"armL": [0.0, 0.0, 0.62, 3.0, 1.6, 2.5, 2.2, 0.0],
				"cam_y": [0.0, 0.0, 0.62, 5.0, 1.6, 4.0, 1.95, -4.0, 2.3, 0.0],
				"look_y": [0.0, 0.0, 0.5, -1.2, 1.6, -1.2, 1.9, 0.0],
				"eyes_half": [0.0, 0.0, 0.45, 0.0, 0.6, 0.95, 1.6, 0.95, 1.72, 0.0],
				("wink_l" if s < 0.0 else "wink_r"): [0.0, 0.0, 1.85, 0.0, 1.95, 1.0, 2.3, 1.0, 2.42, 0.0],
				"blush": [0.0, 0.0, 0.6, 0.55, 2.0, 0.55, 2.9, 0.0]},
				"mouth": [[0.35, 1.7, "small"], [1.7, 2.8, "open"]],
				"sparks": [[1.98, "eyeL" if s < 0.0 else "eyeR"]]}
		"side_stretch":
			# side stretch over the raised arm: the fist goes up, her body bends away, eyes close «нн~», then
			# a loose shake-out and a bounce
			return {"name": name, "dur": 3.1, "side": 1.0, "tracks": {
				"armL": [0.0, 0.0, 0.2, 1.5, 0.75, -6.0, 1.8, -6.5, 2.35, 1.0, 2.6, 0.0],
				"armL_lo": [0.0, 0.0, 0.75, 6.5, 1.8, 7.0, 2.35, -1.0, 2.6, 0.0],
				"fist": [0.0, 0.0, 0.75, 6.0, 1.8, 7.0, 2.3, -4.0, 2.6, 2.0, 2.9, 0.0],
				"spine": [0.0, 0.0, 0.2, 0.6, 0.85, -2.6, 1.8, -2.8, 2.35, 0.5, 2.8, 0.0],
				"chest_rot": [0.0, 0.0, 0.85, -2.2, 1.8, -2.4, 2.35, 0.6, 2.8, 0.0],
				"hip_x": [0.0, 0.0, 0.2, -3.0, 0.85, 13.0, 1.8, 12.0, 2.4, -3.0, 2.9, 0.0],
				"hip_rot": [0.0, 0.0, 0.85, 1.6, 1.8, 1.5, 2.4, 0.0],
				"hip_y": [0.0, 0.0, 0.85, -4.0, 1.8, -5.0, 2.35, 3.0, 2.5, -6.0, 2.7, 1.0, 3.0, 0.0],
				"head": [0.0, 0.0, 0.85, -3.5, 1.8, -3.8, 2.35, 1.5, 3.0, 0.0],
				"head_y": [0.0, 0.0, 0.85, -2.0, 1.8, -2.5, 2.4, 0.0],
				"shrug": [0.0, 0.0, 0.85, 4.0, 1.8, 4.5, 2.35, -1.5, 2.5, 2.5, 2.7, 0.0, 3.0, 0.0],
				"tailL": [0.0, 0.0, 0.9, 2.5, 1.6, 0.0, 2.4, -3.0, 2.7, 0.0],
				"tailR": [0.0, 0.0, 0.9, 2.0, 1.6, 0.0, 2.4, -3.0, 2.7, 0.0],
				"eyes_closed": [0.0, 0.0, 0.55, 0.0, 0.7, 1.0, 1.9, 1.0, 2.02, 0.0],
				"blush": [0.0, 0.0, 0.8, 0.45, 2.4, 0.45, 3.1, 0.0]},
				"mouth": [[0.45, 1.25, "oh"], [1.25, 2.1, "closed"], [2.1, 3.0, "open"]]}
		"stopwatch_glance":
			# a glance down at the stopwatch on her chest: «ой, время!», then back up to you with a wink
			return {"name": name, "dur": 2.5, "side": s, "tracks": {
				"head_y": [0.0, 0.0, 0.35, 5.5, 0.95, 5.0, 1.3, -1.0, 1.8, 0.0],
				"head": [0.0, 0.0, 0.35, 1.8, 0.95, 1.5, 1.4, 3.0 * s, 2.5, 0.0],
				"neck": [0.0, 0.0, 0.35, 0.8, 1.2, 0.0],
				"look_y": [0.0, 0.0, 0.25, 1.4, 0.95, 1.4, 1.15, -0.4, 1.6, 0.0],
				"look_x": [0.0, 0.0, 0.25, 0.8, 0.95, 0.8, 1.15, 0.0],
				"shrug": [0.0, 0.0, 0.35, 1.5, 0.95, 1.0, 1.05, 4.5, 1.25, 0.5, 2.0, 0.0],
				"hip_y": [0.0, 0.0, 1.05, -6.0, 1.25, 1.0, 1.5, 0.0],
				"eyes_half": [0.0, 0.0, 0.25, 0.0, 0.35, 0.55, 0.95, 0.55, 1.05, 0.0],
				("wink_l" if s < 0.0 else "wink_r"): [0.0, 0.0, 1.45, 0.0, 1.55, 1.0, 1.9, 1.0, 2.02, 0.0],
				"blush": [0.0, 0.0, 1.2, 0.0, 1.5, 0.4, 2.5, 0.0]},
				"mouth": [[0.3, 1.0, "oh"], [1.0, 1.25, "small"], [1.25, 2.4, "open"]],
				"sparks": [[1.56, "eyeL" if s < 0.0 else "eyeR"]]}
		"wink_grin":
			# the quick one: head tilt, shoulder up, wink with a sparkle, grin
			return {"name": name, "dur": 1.9, "side": s, "tracks": {
				"head": [0.0, 0.0, 0.12, -1.0 * s, 0.35, 4.2 * s, 1.2, 3.5 * s, 1.9, 0.0],
				"head_x": [0.0, 0.0, 0.35, 4.0 * s, 1.2, 3.0 * s, 1.9, 0.0],
				"head_y": [0.0, 0.0, 0.35, 1.5, 1.9, 0.0],
				"shrug": [0.0, 0.0, 0.35, 3.5, 1.1, 2.0, 1.8, 0.0],
				"hip_x": [0.0, 0.0, 0.4, -6.0 * s, 1.4, -4.0 * s, 1.9, 0.0],
				"chest_rot": [0.0, 0.0, 0.4, 1.0 * s, 1.9, 0.0],
				("wink_l" if s < 0.0 else "wink_r"): [0.0, 0.0, 0.3, 0.0, 0.4, 1.0, 0.95, 1.0, 1.07, 0.0],
				"tailL": [0.0, 0.0, 0.35, 2.5 * s, 0.7, 0.0],
				"tailR": [0.0, 0.0, 0.35, 2.0 * s, 0.7, 0.0],
				"blush": [0.0, 0.0, 0.4, 0.5, 1.4, 0.5, 1.9, 0.0]},
				"mouth": [[0.0, 1.8, "open"]],
				"sparks": [[0.42, "eyeL" if s < 0.0 else "eyeR"]]}
		"jog_in_place":
			# light jog on the spot: weight steps side to side with a hop on each, thighs alternate, the fist swings
			var hy: = [0.0, 0.0]
			var hx: = [0.0, 0.0]
			var hr: = [0.0, 0.0]
			var tL: = [0.0, 0.0]
			var tR: = [0.0, 0.0]
			var aL: = [0.0, 0.0]
			var sp: = [0.0, 0.0]
			var hd: = [0.0, 0.0]
			var tl: = [0.0, 0.0]
			for i in 6:
				var x: = 0.15 + i * 0.3
				var d: = 1.0 if i % 2 == 0 else -1.0
				hy.append_array([x, 3.5, x + 0.14, -8.0])
				hx.append_array([x + 0.07, 7.0 * d])
				hr.append_array([x + 0.07, -1.6 * d])
				tL.append_array([x + 0.07, 2.4 * d])
				tR.append_array([x + 0.07, 2.4 * d])
				aL.append_array([x + 0.07, -2.5 * d])
				sp.append_array([x + 0.07, 1.0 * d])
				hd.append_array([x + 0.1, -1.2 * d])
				tl.append_array([x + 0.12, 2.5 * d])
			for arr in [hy, hx, hr, tL, tR, aL, sp, hd, tl]:
				arr.append_array([2.25, 0.0])
			return {"name": name, "dur": 2.6, "side": s, "tracks": {
				"hip_y": hy, "hip_x": hx, "hip_rot": hr, "thighL": tL, "thighR": tR, "armL": aL, "spine": sp, "head": hd,
				"tailL": tl, "tailR": tl.duplicate(),
				"shrug": [0.0, 0.0, 0.3, 2.0, 2.0, 2.0, 2.5, 0.0],
				"blush": [0.0, 0.0, 0.5, 0.3, 2.6, 0.0]},
				"mouth": [[0.0, 2.5, "open"]]}
		"shy_peek":
			# flirt_level >= 6: caught looking — she turns her face away, eyes slide back to you, blush, pout -> smile
			return {"name": name, "dur": 2.8, "side": s, "tracks": {
				"head": [0.0, 0.0, 0.4, -5.0 * s, 1.9, -4.5 * s, 2.8, 0.0],
				"head_x": [0.0, 0.0, 0.4, -5.0 * s, 1.9, -4.0 * s, 2.8, 0.0],
				"head_y": [0.0, 0.0, 0.4, 4.0, 1.9, 3.5, 2.8, 0.0],
				"shrug": [0.0, 0.0, 0.35, 6.0, 1.9, 5.0, 2.8, 0.0],
				"hip_x": [0.0, 0.0, 0.4, 5.0 * s, 2.0, 0.0],
				"thighL": [0.0, 0.0, 0.4, -1.2, 1.9, -1.0, 2.6, 0.0],
				"look_x": [0.0, 0.0, 0.3, -3.0 * s, 0.9, -3.0 * s, 1.2, 2.2 * s, 2.2, 0.0],
				"look_y": [0.0, 0.0, 0.3, 1.0, 0.9, 1.0, 1.2, -0.6, 2.2, 0.0],
				"eyes_half": [0.0, 0.0, 1.1, 0.0, 1.25, 0.6, 2.2, 0.6, 2.4, 0.0],
				"blush": [0.0, 0.0, 0.3, 1.0, 2.4, 1.0, 2.8, 0.0]},
				"mouth": [[0.25, 1.2, "pout"], [1.2, 2.6, "closed"]]}
		# ---- reactions
		"head_pat":
			# head tap: she leans into it laughing, ^^ eyes, a happy double hop, sparkles, blush
			return {"name": name, "kind": "react", "dur": 2.6, "side": s, "tracks": {
				"head": [0.0, 0.0, 0.1, -1.0 * s, 0.35, 5.0 * s, 1.6, 4.0 * s, 2.5, 0.0],
				"head_x": [0.0, 0.0, 0.35, 5.0 * s, 1.6, 4.0 * s, 2.5, 0.0],
				"head_y": [0.0, 0.0, 0.1, -2.0, 0.35, 3.0, 1.6, 2.0, 2.5, 0.0],
				"neck": [0.0, 0.0, 0.35, 1.5 * s, 2.3, 0.0],
				"hip_y": [0.0, 0.0, 0.12, 4.0, 0.3, -12.0, 0.5, 3.0, 0.7, -9.0, 0.95, 0.0],
				"cam_y": [0.0, 0.0, 0.3, -5.0, 0.5, 1.0, 0.7, -4.0, 0.95, 0.0],
				"shrug": [0.0, 0.0, 0.3, 6.0, 0.55, 2.0, 0.8, 5.0, 1.6, 3.0, 2.4, 0.0],
				"tailL": [0.0, 0.0, 0.3, 4.0 * s, 0.7, -2.0 * s, 1.1, 0.0],
				"tailR": [0.0, 0.0, 0.3, 3.0 * s, 0.7, -1.5 * s, 1.1, 0.0],
				"fist": [0.0, 0.0, 0.3, -5.0, 0.7, 4.0, 1.1, 0.0],
				"eyes_happy": [0.0, 0.0, 0.08, 1.0, 1.9, 1.0, 2.1, 0.0],
				"blush": [0.0, 0.0, 0.3, 1.0, 2.2, 1.0, 2.6, 0.0]},
				"mouth": [[0.08, 0.9, "ah"], [0.9, 1.3, "open"], [1.3, 2.4, "closed"]],
				"sparks": [[0.32, "head"]]}
		"hip_check":
			# tap on the hand on her hip: she pops that hip out, a sly look, then a wink and her grin
			return {"name": name, "kind": "react", "dur": 2.3, "side": -1.0, "tracks": {
				"hip_x": [0.0, 0.0, 0.14, 5.0, 0.42, -22.0, 1.3, -19.0, 2.1, 0.0],
				"hip_rot": [0.0, 0.0, 0.14, -0.8, 0.42, 3.4, 1.3, 3.0, 2.1, 0.0],
				"hip_y": [0.0, 0.0, 0.42, -6.0, 1.3, -5.0, 2.1, 0.0],
				"spine": [0.0, 0.0, 0.2, 0.5, 0.5, -2.4, 1.3, -2.2, 2.1, 0.0],
				"chest_rot": [0.0, 0.0, 0.55, -1.4, 1.35, -1.2, 2.1, 0.0],
				"head": [0.0, 0.0, 0.3, 0.0, 0.6, -3.0, 1.4, -2.6, 2.2, 0.0],
				"head_x": [0.0, 0.0, 0.6, 3.0, 1.4, 2.0, 2.2, 0.0],
				"thighL": [0.0, 0.0, 0.45, 1.0, 1.3, 0.8, 2.1, 0.0],
				"look_x": [0.0, 0.0, 0.3, -1.6, 1.0, -1.4, 1.3, 0.0],
				"eyes_half": [0.0, 0.0, 0.3, 0.0, 0.45, 0.8, 1.15, 0.8, 1.25, 0.0],
				"wink_l": [0.0, 0.0, 1.25, 0.0, 1.35, 1.0, 1.7, 1.0, 1.82, 0.0],
				"tailL": [0.0, 0.0, 0.42, 3.0, 0.8, 0.0],
				"tailR": [0.0, 0.0, 0.42, 2.0, 0.8, 0.0],
				"blush": [0.0, 0.0, 0.5, 0.45, 1.8, 0.45, 2.3, 0.0]},
				"mouth": [[0.3, 1.25, "small"], [1.25, 2.2, "open"]],
				"sparks": [[1.36, "eyeL"]]}
		"jacket_tug":
			# tap on the jacket tied at her waist: a quick hip twist so the sleeves and flap swing, a look down, «о!»
			return {"name": name, "kind": "react", "dur": 2.0, "side": s, "tracks": {
				"hip_x": [0.0, 0.0, 0.12, -8.0, 0.3, 10.0, 0.5, -6.0, 0.7, 3.0, 1.0, 0.0],
				"hip_rot": [0.0, 0.0, 0.12, 1.5, 0.3, -2.0, 0.5, 1.2, 0.8, 0.0],
				"hip_y": [0.0, 0.0, 0.3, -4.0, 0.6, 0.0],
				"head_y": [0.0, 0.0, 0.3, 4.0, 0.9, 3.5, 1.4, 0.0],
				"head": [0.0, 0.0, 0.3, -2.0, 0.9, -1.5, 1.6, 0.0],
				"look_y": [0.0, 0.0, 0.2, 1.4, 0.9, 1.4, 1.15, 0.0],
				"look_x": [0.0, 0.0, 0.2, -1.6, 0.9, -1.6, 1.15, 0.0],
				"blush": [0.0, 0.0, 0.5, 0.3, 2.0, 0.0]},
				"mouth": [[0.15, 0.95, "oh"], [0.95, 1.9, "open"]]}
	return super._build(name, s, p)


# ---------------------------------------------------------------- sparkles

func _spawn_sparks(where: String) -> void:
	var at: = Vector2(1060, 240)
	var n: = 5
	var spread: = 70.0
	match where:
		"fist":
			at = art.get_global_transform().affine_inverse() * (bones["fistL"] as Bone2D).get_global_transform() * Vector2(-58, -102)
		"head":
			at = art.get_global_transform().affine_inverse() * (bones["head"] as Bone2D).get_global_transform() * Vector2(-40, -290)
			n = 6
			spread = 150.0
		"eyeL", "eyeR":
			var off: = Vector2(-80, -150) if where == "eyeL" else Vector2(90, -165)
			at = art.get_global_transform().affine_inverse() * (bones["head"] as Bone2D).get_global_transform() * off
			n = 2
			spread = 26.0
	(_sparks as _Sparks).burst(at, n, spread, rng)


class _Sparks:
	extends Node2D
	# four-point sun sparkles (warm gold), pop with overshoot, drift up and twinkle out; drawn, no textures
	var list: = []

	func burst(at: Vector2, n: int, spread: float, r: RandomNumberGenerator) -> void:
		for i in n:
			var a: = r.randf_range(-PI, PI)
			var d: = r.randf_range(0.25, 1.0) * spread
			list.append({"p": at + Vector2.from_angle(a) * d * 0.4, "v": Vector2.from_angle(a) * d * 1.2 + Vector2(0, -40),
					"t": -i * 0.035, "life": r.randf_range(0.55, 0.85), "size": r.randf_range(14.0, 26.0) * (1.4 if n <= 2 else 1.0),
					"rot": r.randf_range(-0.3, 0.3)})

	func _process(delta: float) -> void:
		if list.is_empty():
			return
		for s in list.duplicate():
			s.t += delta
			if s.t > 0.0:
				s.v *= exp(-delta * 3.0)
				s.p += s.v * delta
			if s.t >= s.life:
				list.erase(s)
		queue_redraw()

	func _draw() -> void:
		for s in list:
			if s.t < 0.0:
				continue
			var x: float = s.t / s.life
			var pop: = minf(x / 0.16, 1.0)
			var k: = (1.0 - pow(1.0 - pop, 3.0)) * (1.0 + 0.35 * sin(pop * PI)) * (1.0 - 0.5 * x)
			var a: = 1.0 - smoothstep(0.5, 1.0, x)
			_star(s.p, s.size * k, s.rot + x * 1.2, a)

	func _star(c: Vector2, r: float, rot: float, a: float) -> void:
		draw_circle(c, r * 0.55, Color(1.0, 0.78, 0.4, 0.16 * a))
		for layer in 2:
			var rr: = r * (1.0 if layer == 0 else 0.55)
			var w: = rr * 0.2
			var col: = Color(1.0, 0.8, 0.38, 0.9 * a) if layer == 0 else Color(1.0, 0.98, 0.9, a)
			var pts: = PackedVector2Array()
			for i in 8:
				var ang: = rot + i * PI / 4.0
				pts.append(c + Vector2.from_angle(ang) * (rr if i % 2 == 0 else w))
			draw_colored_polygon(pts, col)
