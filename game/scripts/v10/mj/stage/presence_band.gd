class_name V10MjPresenceBand
extends Control

# V10MjPresenceBand — her place in every match (docs/MODES.md §3.1, UX_RULES §6.6): the arched portrait window
# with the one honest gauge around it — the ring of «Приём». The band itself is the 120 px strip (plus all the
# extra height of 9:20+ screens, where the window grows into a waist-up stage); the host keeps its own pause and
# «Осталось N» on the left, the band never draws over them.
#
#   band.build(hero, window_rect, opts) -> self     opts: source ("auto" | "rig" | "video" | "static"), fx ("full"|
#                                                   "mid"|"min"), quiet (bool), rig_gap (Vector2 s between gestures)
#   band.set_window(rect)                            re-layout (rotation, safe area)
#   band.set_charge(v01, animate = true)             ring fill 0..1 (≥ 1 = ready: gold, brighter)
#   band.tick()                                      a pair arrived: glint at the ring head
#   band.react(kind, hold = 0.6, at = Vector2.INF)   smile | nod | clap | wink | bite | calm | pose | ah | look_camera
#                                                    | talk | glance | lose | win | shy
#   band.source -> "rig" | "video" | "static"        what is in the window (one rig per screen: the peek never rigs)
# Only the window takes input (mouse_filter STOP): a tap is answered by her in < 100 ms (UX §8.2) and re-emitted
# as `portrait_tapped` (the host may open the Приём from it). Everything else ignores the mouse.

signal portrait_tapped

const RING_W: = 4.0
const RING_GAP: = 7.0
const RIG_DIR: = "res://assets/v10/rig/"
const VIDEO_PATH: = "res://assets/v09/video/%s_lobby.ogv"

var hero_id: = "mc"
var accent: = Color.WHITE
var fx: = "full"
var quiet: = false
var source: = "static"
var window: Control
var mask: Control
var ring: Control
var backdrop: Control
var portrait: Node = null  # rig (Node2D) | VideoStreamPlayer | null (static)
var _tex_a: TextureRect
var _tex_b: TextureRect
var _frame: = ""
var _rest: = "rest"
var _frame_until: = 0.0
var _hold_frame: = ""  # a state frame (danger) that wins over rest until cleared
var charge: = 0.0
var _shown: = 0.0
var _glint: = 0.0
var _rig_focus: = Rect2(400, 60, 660, 760)
var _rig_base: = Vector2.ZERO
var _rig_scale: = 1.0
var _bob_tw: Tween


func build(hero: String, wr: Rect2, opts: = {}) -> V10MjPresenceBand:
	hero_id = hero
	accent = V10MjStageData.accent(hero)
	fx = String(opts.get("fx", V10MjStageData.fx_level()))
	quiet = bool(opts.get("quiet", false))
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	window = Control.new()
	window.name = "PortraitWindow"
	window.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(window)
	window.gui_input.connect(_on_window_input)
	mask = _ArchMask.new()
	mask.name = "ArchMask"
	mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mask.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	window.add_child(mask)
	backdrop = _Backdrop.new()
	backdrop.name = "Backdrop"
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(backdrop as _Backdrop).top = V10MjStageData.deep(hero).lerp(V10MjStageData.TOK.night700, 0.35)
	(backdrop as _Backdrop).bottom = V10MjStageData.TOK.night900
	(backdrop as _Backdrop).glow = accent
	mask.add_child(backdrop)
	ring = _Ring.new()
	ring.name = "Ring"
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(ring as _Ring).band = self
	window.add_child(ring)
	_pick_source(String(opts.get("source", "auto")), opts)
	set_window(wr)
	return self


func _pick_source(want: String, opts: Dictionary) -> void:
	# docs/MODES.md: rig v10 (V10RigStage when that lane is merged, else live_rig.gd) → video → painted frames.
	# fx «Минимум» always uses the painted frames (static pose, frame swaps in 120 ms).
	if fx == "min":
		want = "static"
	if want in ["auto", "rig"]:
		var rig: = _make_rig(opts)
		if rig:
			portrait = rig
			source = "rig"
			mask.add_child(rig)
			return
	if want in ["auto", "video"]:
		var vp: = String(opts.get("video", VIDEO_PATH % hero_id))
		if ResourceLoader.exists(vp) and want == "video":
			var v: = VideoStreamPlayer.new()
			v.stream = load(vp)
			v.loop = true
			v.expand = true
			v.autoplay = true
			v.mouse_filter = Control.MOUSE_FILTER_IGNORE
			portrait = v
			source = "video"
			mask.add_child(v)
			return
	source = "static"
	_tex_a = _mk_tex()
	_tex_b = _mk_tex()
	_tex_b.modulate.a = 0.0
	_show_frame(_rest, false)


# the lobby video is a full scene, not a portrait: «auto» never picks it for the window (it stays available as an
# explicit source for a heroine whose only moving art is a video). Rig first, then the painted frames.
func _make_rig(opts: Dictionary) -> Node2D:
	var stage_path: = V10MjStageData.global_class_path("V10RigStage")
	if stage_path != "":
		var rs = load(stage_path).new()
		if rs and rs.has_method("make"):
			var n = rs.make(hero_id, "bust")
			if n is Node2D:
				_configure_rig(n, opts)
				return n
	var dir: = DirAccess.open(RIG_DIR)
	if dir == null:
		return null
	for d in dir.get_directories():
		if d.begins_with(hero_id + "_") and ResourceLoader.exists(RIG_DIR + d + "/rig.tscn"):
			var ps: PackedScene = load(RIG_DIR + d + "/rig.tscn")
			var rig: Node = ps.instantiate()
			if rig is Node2D:
				_rig_focus = _focus_from_def(RIG_DIR + d + "/rig_def.json")
				_configure_rig(rig, opts)
				return rig
			rig.free()
	return null


func _configure_rig(rig: Node2D, opts: Dictionary) -> void:
	for p in [["handle_input", false], ["show_background", true], ["auto_gestures", not quiet],
			["gesture_gap", opts.get("rig_gap", Vector2(10.0, 18.0))], ["motion", 0.6 if quiet or fx == "mid" else 1.0]]:
		if p[0] in rig:
			rig.set(p[0], p[1])


func _focus_from_def(path: String) -> Rect2:
	var f: = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return _rig_focus
	var d = JSON.parse_string(f.get_as_text())
	if not d is Dictionary:
		return _rig_focus
	for b in d.get("bones", []):
		if String(b.get("name", "")) == "head":
			var h: = Vector2(b.pos[0], b.pos[1])
			# bust: a bit above the hair top to just under the chest
			return Rect2(h.x - 330.0, h.y - 380.0, 660.0, 800.0)
	return _rig_focus


func _mk_tex() -> TextureRect:
	var t: = TextureRect.new()
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	mask.add_child(t)
	return t


func set_window(wr: Rect2) -> void:
	window.position = wr.position
	window.size = wr.size
	window.pivot_offset = wr.size * Vector2(0.5, 1.0)
	mask.size = wr.size
	backdrop.size = wr.size
	ring.position = - Vector2.ONE * (RING_GAP + RING_W)
	ring.size = wr.size + Vector2.ONE * 2.0 * (RING_GAP + RING_W)
	if source == "rig" and portrait is Node2D:
		var r: = _rig_focus
		var s: = maxf(wr.size.x / r.size.x, wr.size.y / r.size.y)
		_rig_scale = s
		(portrait as Node2D).scale = Vector2.ONE * s
		_rig_base = Vector2(wr.size.x * 0.5 - (r.position.x + r.size.x * 0.5) * s, - r.position.y * s)
		(portrait as Node2D).position = _rig_base
	elif source == "video" and portrait is Control:
		var c: = portrait as Control
		c.size = Vector2(wr.size.y * 9.0 / 16.0, wr.size.y) * 1.9
		c.position = Vector2((wr.size.x - c.size.x) * 0.5, - c.size.y * 0.06)
	else:
		_fit_tex(_tex_a)
		_fit_tex(_tex_b)
	queue_redraw()


func window_rect() -> Rect2:
	return Rect2(window.position, window.size)


# the ring included: what the window occupies on screen (sacred-zone audits use this)
func window_outer() -> Rect2:
	return window_rect().grow(RING_GAP + RING_W + 2.0)


# focus of a painted waist-up frame: the upper 64 % (head to chest), full width, cover-fit in the arch
func _fit_tex(t: TextureRect) -> void:
	if t == null or t.texture == null:
		return
	var ts: = t.texture.get_size()
	var focus: = Rect2(0, 0, ts.x, ts.y * 0.64)
	var wr: = window.size
	var s: = maxf(wr.x / focus.size.x, wr.y / focus.size.y)
	t.size = ts * s
	t.position = Vector2((wr.x - t.size.x) * 0.5, - focus.position.y * s + 2.0)


func _show_frame(slot: String, fade: = true) -> void:
	if source != "static":
		return
	var path: = V10MjStageData.frame_path(hero_id, slot)
	if path == _frame:
		return
	_frame = path
	var tex: Texture2D = load(path)
	if not fade or _tex_a.texture == null:
		_tex_a.texture = tex
		_fit_tex(_tex_a)
		return
	# cross-fade: B takes the new frame and fades in over 120 ms, then becomes A (fx min: same 120 ms, no motion)
	_tex_b.texture = tex
	_fit_tex(_tex_b)
	_tex_b.modulate.a = 0.0
	var t: = create_tween()
	V10MjStageFx.step(t, _tex_b, "modulate:a", 1.0, 0.12, Tween.TRANS_SINE, Tween.EASE_OUT)
	t.tween_callback(func():
		_tex_a.texture = tex
		_fit_tex(_tex_a)
		_tex_b.modulate.a = 0.0)


func set_charge(v: float, animate: = true) -> void:
	charge = clampf(v, 0.0, 1.0)
	if not animate or fx == "min":
		_shown = charge
	set_process(true)


func tick() -> void:
	_glint = 1.0
	set_process(true)


func _process(dt: float) -> void:
	var busy: = false
	if not is_equal_approx(_shown, charge):
		_shown = move_toward(_shown, charge, dt * 1.6)
		busy = true
	if _glint > 0.0:
		_glint = maxf(0.0, _glint - dt / 0.35)
		busy = true
	if source == "static" and _frame_until > 0.0 and Time.get_ticks_msec() / 1000.0 >= _frame_until:
		_frame_until = 0.0
		_show_frame(_hold_frame if _hold_frame != "" else _rest)
	busy = busy or _frame_until > 0.0
	ring.queue_redraw()
	if not busy:
		set_process(false)


func _hold(slot: String, hold: float) -> void:
	_show_frame(slot)
	_frame_until = Time.get_ticks_msec() / 1000.0 + hold
	set_process(true)


func set_state_frame(slot: String) -> void:
	# a frame that lasts while a state does (danger); "" clears it
	_hold_frame = slot
	if _frame_until <= 0.0:
		_show_frame(slot if slot != "" else _rest)


func react(kind: String, hold: = 0.6, at: = Vector2.INF) -> void:
	if source == "rig" and is_instance_valid(portrait):
		_react_rig(kind, hold, at)
		return
	match kind:
		"smile", "clap", "wink", "win":
			_hold("smile", hold)
		"ah", "pose":
			_hold("ah", hold)
		"bite":
			set_state_frame("danger")
		"calm":
			set_state_frame("")
		"lose":
			_hold("lose", hold)
		"look_camera", "shy":
			_hold("shy", hold)
		"talk", "nod":
			pass
	if kind in ["nod", "clap", "talk"] and fx != "min":
		_bob(3.0 if kind == "nod" else 5.0, 2 if kind == "clap" else 1)


func _react_rig(kind: String, hold: float, at: Vector2) -> void:
	var rig = portrait
	var c: = window.get_global_rect().get_center()
	match kind:
		"glance":
			if at != Vector2.INF and rig.has_method("look_at_global"):
				rig.look_at_global(at, 0.8)
		"smile":
			if rig.has_method("react"):
				rig.react("outfit", c + Vector2(0, -40))
		"nod":
			if rig.has_method("gesture"):
				rig.gesture("lean_in")
		"clap", "win":
			if rig.has_method("gesture"):
				rig.gesture("hip_pop")
		"wink":
			if rig.has_method("wink"):
				rig.wink(randf() < 0.5)
		"bite":
			if rig.has_method("gesture"):
				rig.gesture("knee_in")
		"pose", "ah":
			if rig.has_method("gesture"):
				rig.gesture("air_kiss")
		"look_camera", "shy":
			if rig.has_method("look_at_global"):
				rig.look_at_global(c + Vector2(0, 30), hold)
		"lose":
			if rig.has_method("gesture"):
				rig.gesture("shoulder_roll")
		"talk":
			if rig.has_method("talk"):
				rig.talk(hold)


func _bob(px: float, n: int) -> void:
	if _bob_tw and _bob_tw.is_valid():
		_bob_tw.kill()
	var base: = Vector2.ZERO if source != "rig" else _rig_base
	var target: CanvasItem = mask
	mask.position = Vector2.ZERO
	_bob_tw = create_tween()
	for i in n:
		V10MjStageFx.step(_bob_tw, target, "position:y", base.y + px, 0.08, Tween.TRANS_QUAD, Tween.EASE_OUT)
		V10MjStageFx.step(_bob_tw, target, "position:y", 0.0, 0.16, Tween.TRANS_BACK, Tween.EASE_OUT)


func _on_window_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		var gp: Vector2 = window.get_global_transform() * e.position
		if source == "rig" and is_instance_valid(portrait) and portrait.has_method("react"):
			portrait.react("head", gp)
		else:
			_hold("smile", 0.8)
		portrait_tapped.emit()


# ── drawing ──────────────────────────────────────────────────────────────────────────────────────────────────

static func arch_points(sz: Vector2, steps: = 24) -> PackedVector2Array:
	var r: = sz.x * 0.5
	var pts: = PackedVector2Array()
	pts.append(Vector2(0, sz.y))
	for i in steps + 1:
		var a: = PI + PI * float(i) / steps
		pts.append(Vector2(r + cos(a) * r, minf(r, sz.y) + sin(a) * r))
	pts.append(Vector2(sz.x, sz.y))
	return pts


class _ArchMask extends Control:
	func _draw() -> void:
		draw_colored_polygon(V10MjPresenceBand.arch_points(size), Color.WHITE)


class _Backdrop extends Control:
	var top: = Color.BLACK
	var bottom: = Color.BLACK
	var glow: = Color.WHITE

	func _draw() -> void:
		var pts: = PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)])
		draw_polygon(pts, PackedColorArray([top, top, bottom, bottom]))
		# her contre-jour: a soft accent glow behind the shoulders (≤ 10 % of the band's pixels, UX §6.2)
		var c: = Vector2(size.x * 0.5, size.y * 0.55)
		for i in 6:
			var k: = 1.0 - i / 6.0
			draw_circle(c, size.x * (0.2 + 0.08 * i), Color(glow.r, glow.g, glow.b, 0.05 * k))


class _Ring extends Control:
	var band: V10MjPresenceBand

	func _draw() -> void:
		if band == null:
			return
		var off: = Vector2.ONE * (V10MjPresenceBand.RING_GAP + V10MjPresenceBand.RING_W)
		var sz: = band.window.size + Vector2.ONE * 2.0 * V10MjPresenceBand.RING_GAP
		var pts: = V10MjPresenceBand.arch_points(sz, 40)
		for i in pts.size():
			pts[i] += off - Vector2.ONE * V10MjPresenceBand.RING_GAP
		# the ring runs from the bottom-left foot, over the arch, to the bottom-right foot
		var track: Color = V10MjStageData.TOK.paper700
		track.a = 0.45
		draw_polyline(pts, track, 2.0, true)
		# the window's base: one 1 px line gold.700 at 35 % (UX §6.8)
		var base: Color = V10MjStageData.TOK.gold700
		base.a = 0.35
		draw_line(pts[0], pts[pts.size() - 1], base, 1.0, true)
		var v: = band._shown
		if v <= 0.001:
			return
		var ready: = v >= 0.999
		var col: Color = V10MjStageData.TOK.gold300 if ready else band.accent
		var part: = _partial(pts, v)
		if ready:
			draw_polyline(part, Color(col.r, col.g, col.b, 0.22), V10MjPresenceBand.RING_W + 6.0, true)
		draw_polyline(part, col, V10MjPresenceBand.RING_W, true)
		if band._glint > 0.0 and part.size() > 0:
			var head: = part[part.size() - 1]
			var g: = band._glint
			draw_circle(head, 4.0 + 6.0 * g, Color(1, 1, 1, 0.55 * g))
			draw_circle(head, 2.5, Color(col.r, col.g, col.b, 0.9))

	func _partial(pts: PackedVector2Array, v: float) -> PackedVector2Array:
		var total: = 0.0
		for i in range(1, pts.size()):
			total += pts[i].distance_to(pts[i - 1])
		var want: = total * v
		var out: = PackedVector2Array([pts[0]])
		var acc: = 0.0
		for i in range(1, pts.size()):
			var d: = pts[i].distance_to(pts[i - 1])
			if acc + d >= want:
				out.append(pts[i - 1].lerp(pts[i], (want - acc) / maxf(d, 0.001)))
				return out
			acc += d
			out.append(pts[i])
		return out
