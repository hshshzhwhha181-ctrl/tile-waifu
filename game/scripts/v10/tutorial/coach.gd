class_name V10Coach
extends Control

# V10Coach — one coach-mark on screen: a dim with a soft-edged spotlight hole on the target, a pointer that
# taps on it, Маджонг-тян's speech bubble with her portrait (emotion), a step counter and «Пропустить обучение».
# Lives in its own CanvasLayer (V10Tutorial.LAYER) above every screen, popup and the match (z 450).
#
#   var c: = V10Coach.make(layer, ctx_fn)          ctx_fn() -> {"main": main, "screen": screen}
#   c.show_step({"text": "…", "emo": "happy", "target": spec, "mode": "tap" | "do" | "tip",
#                "finger": true, "counter": [3, 9], "skippable": true, "timeout": 30, "speaker": "mc" | "guide"})
#   signals: advanced (tap / tip step read), skip_confirmed, forced_continue (timeout chip), closed
#
# Input: "tap" and "tip" steps take every touch (tap anywhere = next); "do" steps pass touches through the hole
# only, the rest of the screen answers with a soft deny (pointer wiggle) — nothing behind can be pressed by
# accident. The target is re-resolved every frame, so a resize / rotation / animated popup keeps the hole on it.

signal advanced
signal skip_confirmed
signal forced_continue
signal closed

const SPOT: = preload("res://scripts/v10/tutorial/spotlight.gdshader")
const MASK: = "shader_type canvas_item;\nuniform float soft = 0.03;\nvoid fragment(){\n\tvec4 c = texture(TEXTURE, UV) * COLOR;\n\tfloat d = length(UV - vec2(0.5));\n\tc.a *= 1.0 - smoothstep(0.5 - soft, 0.5, d);\n\tCOLOR = c;\n}\n"
const EMO_FACE: = Rect2(118, 34, 372, 372)
const NAME_MC: = "Маджонг-тян"
const SAFE_TOP: = 104.0
const SAFE_BOTTOM: = 16.0

var ctx_fn: Callable
var data: = {}
var mode: = "tap"
var target_spec = null
var hole: = Rect2()          # animated hole (what is drawn)
var goal: = Rect2()          # resolved target this frame
var has_goal: = false
var round_hole: = false
var _node_cache = null
var _search_t: = 0.0
var _t: = 0.0
var _shown_t: = 0.0
var _typing: Tween
var _closing: = false
var _confirm: Control
var _timeout_chip: Control

var dim: ColorRect
var mat: ShaderMaterial
var bubble: Control
var panel: RBox
var portrait: TextureRect
var name_lbl: Label
var text_lbl: Label
var more_lbl: Label
var counter: Control
var skip_btn: JButton
var pointer: Node2D
var touch_ring: Sprite2D


static func make(parent: Node, ctx: Callable) -> V10Coach:
	var c: = V10Coach.new()
	c.ctx_fn = ctx
	c.name = "V10Coach"
	parent.add_child(c)
	return c


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	size = get_viewport_rect().size
	dim = ColorRect.new()
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.size = size
	mat = ShaderMaterial.new()
	mat.shader = SPOT
	dim.material = mat
	add_child(dim)
	_build_pointer()
	_build_bubble()
	_build_skip()
	mat.set_shader_parameter("amount", 0.0)
	get_viewport().size_changed.connect(_on_resize)


func ts() -> float:
	return V10TutState.text_scale()


func _ctx() -> Dictionary:
	if ctx_fn.is_valid():
		var c = ctx_fn.call()
		if c is Dictionary:
			return c
	return {}


# ── building ─────────────────────────────────────────────────────────────────────────────────────────────────

func _build_pointer() -> void:
	pointer = Node2D.new()
	pointer.z_index = 5
	pointer.visible = false
	add_child(pointer)
	touch_ring = Sprite2D.new()
	touch_ring.texture = G.fx("finger")
	touch_ring.modulate = Color(1, 0.9, 0.72, 0.9)
	touch_ring.scale = Vector2(0.9, 0.9)
	pointer.add_child(touch_ring)
	# a gold arrow (outline + fill) that bobs above the touch point
	var arrow: = Node2D.new()
	arrow.name = "Arrow"
	pointer.add_child(arrow)
	var pts: = PackedVector2Array([Vector2(-20, -112), Vector2(20, -112), Vector2(20, -80), Vector2(40, -80), Vector2(0, -38), Vector2(-40, -80), Vector2(-20, -80)])
	var sh: = Polygon2D.new()
	sh.polygon = pts
	sh.color = Color(0.1, 0.03, 0.08, 0.45)
	sh.position = Vector2(0, 5)
	arrow.add_child(sh)
	var ol: = Polygon2D.new()
	ol.polygon = pts
	ol.color = Color("fff3d2")
	arrow.add_child(ol)
	var inner: = PackedVector2Array()
	for p in pts:
		inner.append(p * 0.78 + Vector2(0, -16.0))
	var fi: = Polygon2D.new()
	fi.polygon = inner
	fi.color = Color("e8b45c")
	fi.vertex_colors = PackedColorArray([Color("ffe3a0"), Color("ffe3a0"), Color("f0b860"), Color("e89a5c"), Color("d9748a"), Color("e89a5c"), Color("f0b860")])
	arrow.add_child(fi)
	var at: = arrow.create_tween().set_loops()
	at.tween_property(arrow, "position:y", -16.0, 0.38).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	at.tween_property(arrow, "position:y", 0.0, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	at.tween_callback(_tap_pulse)


func _tap_pulse() -> void:
	if not pointer.visible:
		return
	var t: = touch_ring.create_tween()
	t.tween_property(touch_ring, "scale", Vector2(0.62, 0.62), 0.07)
	t.tween_property(touch_ring, "scale", Vector2(0.9, 0.9), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if V9Feel.can_fx():
		var r: = Sprite2D.new()
		r.texture = G.fx("ring")
		r.modulate = Color(1, 0.88, 0.6, 0.8)
		r.scale = Vector2(0.4, 0.4)
		pointer.add_child(r)
		var rt: = r.create_tween().set_parallel()
		rt.tween_property(r, "scale", Vector2(1.5, 1.5), 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		rt.tween_property(r, "modulate:a", 0.0, 0.55)
		rt.chain().tween_callback(r.queue_free)


func _build_bubble() -> void:
	bubble = Control.new()
	bubble.mouse_filter = Control.MOUSE_FILTER_STOP
	bubble.z_index = 6
	bubble.visible = false
	add_child(bubble)
	bubble.gui_input.connect(_on_bubble_input)
	panel = UI.rbox("plum", Rect2(0, 0, 600, 200), 30, 4, 12)
	panel.colors(Color(0.17, 0.11, 0.2, 0.97), Color(0.09, 0.055, 0.11, 0.98)).borders(Color("fff0c4"), Color("b88432"))
	panel.set_param("gloss", 0.08)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.add_child(panel)
	portrait = TextureRect.new()
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pm: = ShaderMaterial.new()
	var sh: = Shader.new()
	sh.code = MASK
	pm.shader = sh
	portrait.material = pm
	bubble.add_child(portrait)
	name_lbl = UI.label(NAME_MC, 20, Color.WHITE, Color("7a2346"), 4, "body", 900)
	bubble.add_child(name_lbl)
	text_lbl = UI.label("", 22, Color("fff1dc"), UI.DARK, 2, "body", 800)
	text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bubble.add_child(text_lbl)
	more_lbl = UI.label("", 16, Color("ffd98a"), UI.DARK, 3, "body", 900)
	more_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bubble.add_child(more_lbl)
	counter = Control.new()
	counter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.add_child(counter)


func _build_skip() -> void:
	skip_btn = JButton.make("Пропустить обучение", "glass", Rect2(0, 0, 270, 56), null, 18, 28.0, false)
	skip_btn.z_index = 7
	skip_btn.sound = "tap"
	skip_btn.pressed.connect(_ask_skip)
	skip_btn.visible = false
	add_child(skip_btn)


# ── one step ─────────────────────────────────────────────────────────────────────────────────────────────────

var _gen: = 0

func show_step(d: Dictionary) -> void:
	_gen += 1
	data = d
	mode = String(d.get("mode", "tap"))
	target_spec = d.get("target")
	if target_spec is Array and (target_spec as Array).is_empty():
		target_spec = null
	round_hole = false
	_node_cache = null
	_search_t = 0.0
	_closing = false
	_shown_t = _t
	if is_instance_valid(_timeout_chip):
		_timeout_chip.queue_free()
	_timeout_chip = null
	visible = true
	_resolve(true)
	var first: = not bubble.visible
	if has_goal:
		hole = goal if first or hole.size == Vector2.ZERO else hole
	# the dim fades in at the first step and stays between steps (no flicker); a tip is lighter
	var a: = 0.66 if mode == "tip" else 0.8
	mat.set_shader_parameter("dim", Color(0.035, 0.02, 0.05, a))
	var tw: = create_tween()
	tw.tween_method(func(v): mat.set_shader_parameter("amount", v), float(mat.get_shader_parameter("amount")), 1.0, 0.28)
	_fill_bubble(d)
	pointer.visible = bool(d.get("finger", false)) and has_goal
	if pointer.visible:
		if first or pointer.position == Vector2.ZERO:
			pointer.position = _pointer_at()
		var pt: = pointer.create_tween()
		pt.tween_property(pointer, "position", _pointer_at(), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		pointer.scale = Vector2.ONE * 0.6
		pointer.create_tween().tween_property(pointer, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	skip_btn.visible = bool(d.get("skippable", false)) and mode != "tip"
	_layout()
	_pop_bubble()


func _fill_bubble(d: Dictionary) -> void:
	var k: = ts()
	var guide: = String(d.get("speaker", "mc")) == "guide"
	var emo: = String(d.get("emo", "happy"))
	if guide:
		portrait.texture = V8Art.icon("help")
	else:
		var path: = "res://assets/v08/emotions/mc_%s.webp" % emo
		if not ResourceLoader.exists(path):
			path = "res://assets/v08/emotions/mc_happy.webp"
		var at: = AtlasTexture.new()
		at.atlas = load(path)
		at.region = EMO_FACE
		portrait.texture = at
	name_lbl.text = "Подсказка" if guide else NAME_MC
	name_lbl.label_settings.font_size = int(round(20 * minf(k, 1.15)))
	text_lbl.label_settings.font_size = int(round(22 * k))
	text_lbl.text = String(d.get("text", ""))
	match mode:
		"do":
			more_lbl.text = ""
		"tip":
			more_lbl.text = "Понятно ▸"
		_:
			more_lbl.text = "Дальше ▸"
	more_lbl.label_settings.font_size = int(round(16 * minf(k, 1.2)))
	# step counter: «3 / 9» and a dot row
	for c in counter.get_children():
		c.queue_free()
	var cn = d.get("counter")
	counter.visible = cn is Array and mode != "tip"
	if counter.visible:
		var i: = int(cn[0])
		var n: = int(cn[1])
		var lbl: = UI.label("%d / %d" % [i, n], 15, Color("e8d6c0"), UI.DARK, 2, "body", 900)
		lbl.position = Vector2(0, -2)
		counter.add_child(lbl)
		var x0: = UI.font("body", 900).get_string_size(lbl.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 12.0
		for j in mini(n, 14):
			var dot: = UI.rbox("gold" if j < i else "plum", Rect2(x0 + j * 15.0, 4, 10, 10), 5, 1, 2)
			if j >= i:
				dot.colors(Color(1, 1, 1, 0.18), Color(1, 1, 1, 0.12)).borders(Color(1, 1, 1, 0.2), Color(1, 1, 1, 0.1))
			dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			counter.add_child(dot)


func _pop_bubble() -> void:
	bubble.visible = true
	bubble.pivot_offset = bubble.size * Vector2(0.5, 1.0 if _bubble_above() else 0.0)
	bubble.scale = Vector2(0.9, 0.9)
	bubble.modulate.a = 0.0
	var t: = bubble.create_tween().set_parallel()
	t.tween_property(bubble, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(bubble, "modulate:a", 1.0, 0.18)
	portrait.pivot_offset = portrait.size * Vector2(0.5, 1.0)
	portrait.scale = Vector2(0.86, 0.86)
	var pt: = portrait.create_tween()
	pt.tween_property(portrait, "scale", Vector2(1.06, 1.06), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	pt.tween_property(portrait, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	V9Feel.sound("pop", 1.25, -8.0)
	# typewriter
	if _typing and _typing.is_valid():
		_typing.kill()
	text_lbl.visible_ratio = 0.0
	_typing = create_tween()
	_typing.tween_property(text_lbl, "visible_ratio", 1.0, clampf(text_lbl.text.length() * 0.016, 0.25, 1.4))


func typing() -> bool:
	return _typing != null and _typing.is_valid() and _typing.is_running() and text_lbl.visible_ratio < 1.0


func finish_typing() -> void:
	if _typing and _typing.is_valid():
		_typing.kill()
	text_lbl.visible_ratio = 1.0


# ── layout ───────────────────────────────────────────────────────────────────────────────────────────────────

var _above: = false

func _bubble_above() -> bool:
	return _above


func _layout() -> void:
	var vp: = size
	var k: = ts()
	var bw: = minf(vp.x - 32.0, 640.0)
	var por: = 116.0
	var tx: = 26.0 + por + 14.0
	var tw: = bw - tx - 24.0
	var f: = UI.font("body", 800)
	var fs: = int(round(22 * k))
	var th: = f.get_multiline_string_size(text_lbl.text, HORIZONTAL_ALIGNMENT_LEFT, tw, fs).y
	var bh: = maxf(150.0, 52.0 + th + 40.0)
	panel.size = Vector2(bw, bh)
	panel.position = Vector2.ZERO
	bubble.size = Vector2(bw, bh)
	portrait.size = Vector2(por, por)
	portrait.position = Vector2(18, -26)
	name_lbl.position = Vector2(tx, 12)
	name_lbl.size = Vector2(tw, 28)
	text_lbl.position = Vector2(tx, 44)
	text_lbl.size = Vector2(tw, th + 4)
	more_lbl.position = Vector2(bw - 160, bh - 32)
	more_lbl.size = Vector2(140, 24)
	counter.position = Vector2(22, bh - 26)
	# where: away from the hole, inside the safe band
	var x: = (vp.x - bw) * 0.5
	var y: float
	var top_room: = (goal.position.y - SAFE_TOP) if has_goal else 0.0
	var bot_room: = (vp.y - SAFE_BOTTOM - goal.end.y) if has_goal else 0.0
	var gap: = 40.0 + (84.0 if pointer.visible else 0.0)
	if not has_goal:
		y = vp.y * 0.58 - bh * 0.5
		_above = false
	elif bot_room >= bh + 40.0 and (bot_room >= top_room or top_room < bh + gap):
		y = goal.end.y + 40.0
		_above = false
	elif top_room >= bh + gap:
		y = goal.position.y - gap - bh
		_above = true
	else:
		# a huge target (the board): the larger band, overlapping its edge a little
		_above = top_room > bot_room
		y = SAFE_TOP + 26.0 if _above else vp.y - SAFE_BOTTOM - bh
	y = clampf(y, SAFE_TOP + 26.0, vp.y - SAFE_BOTTOM - bh)
	bubble.position = Vector2(x, y)
	# skip pill: top right; another corner when the hole or the bubble is there
	var br: = Rect2(bubble.position, bubble.size).grow(10)
	var sw: = skip_btn.size
	var spots: = [Vector2(vp.x - sw.x - 14.0, 22.0), Vector2(14.0, 22.0), Vector2(vp.x - sw.x - 14.0, vp.y - sw.y - 22.0),
		Vector2(14.0, vp.y - sw.y - 22.0)]
	skip_btn.position = spots[0]
	for sp in spots:
		var r: = Rect2(sp, sw).grow(8)
		if not (has_goal and r.intersects(goal)) and not r.intersects(br):
			skip_btn.position = sp
			break
	if is_instance_valid(_timeout_chip):
		_timeout_chip.position = Vector2(bubble.position.x + bw - _timeout_chip.size.x - 14.0, bubble.position.y + bh + 12.0 if bubble.position.y + bh + 70.0 < vp.y else bubble.position.y - 64.0)


func _pointer_at() -> Vector2:
	# the touch point: centre of the target; for a wide target a bit left of centre so the arrow does not
	# cover its caption
	var c: = goal.get_center()
	if goal.size.x > 220.0:
		c.x -= goal.size.x * 0.18
	# a tall target (a portrait): touch its lower half, the arrow must not sit on her face
	if goal.size.y > 180.0:
		c.y = goal.position.y + goal.size.y * 0.68
	return c


func _on_resize() -> void:
	size = get_viewport_rect().size
	dim.size = size
	_resolve(true)
	if bubble.visible:
		_layout()


# ── per frame ────────────────────────────────────────────────────────────────────────────────────────────────

func _resolve(force: = false) -> void:
	has_goal = false
	if target_spec == null:
		return
	# a node found once is followed every frame (its rect moves with it); the search runs again at most 4×/s
	if _node_cache != null and V10TutTarget.usable(_node_cache) and not force:
		goal = V10TutTarget.node_rect(_node_cache).grow(_pad())
		has_goal = goal.size.x > 2.0
		if has_goal:
			return
	if not force and _t - _search_t < 0.25 and _node_cache == null and goal.size != Vector2.ZERO:
		has_goal = true
		return
	_search_t = _t
	var r: = V10TutTarget.resolve(target_spec, _ctx())
	if r.ok:
		goal = r.rect
		has_goal = true
		round_hole = bool(r.get("round", false))
		_node_cache = r.node if r.node != null and _followable(r.kind) else null
	else:
		_node_cache = null
		goal = Rect2()


func _followable(kind: String) -> bool:
	return kind in ["meta", "prop", "path", "text", "dyn"]


func _pad() -> float:
	var s = target_spec
	if s is Array and not (s as Array).is_empty():
		s = s[0]
	return float(s.get("pad", 10.0)) if s is Dictionary else 10.0


func _process(dt: float) -> void:
	_t += dt
	if not visible or _closing:
		return
	var vs: = get_viewport_rect().size
	if vs != size:
		_on_resize()
	_resolve()
	var k: = 1.0 - exp(-dt * 14.0)
	if has_goal:
		if hole.size == Vector2.ZERO:
			hole = goal
		hole = Rect2(hole.position.lerp(goal.position, k), hole.size.lerp(goal.size, k))
	var breath: = 0.5 + 0.5 * sin(_t * 3.2)
	var grow: = 3.0 * breath if V9Feel.can_fx() else 0.0
	var hr: = hole.grow(grow)
	mat.set_shader_parameter("size", size)
	mat.set_shader_parameter("has_hole", 1.0 if has_goal else 0.0)
	mat.set_shader_parameter("hole", Vector4(hr.position.x, hr.position.y, hr.size.x, hr.size.y))
	mat.set_shader_parameter("radius", minf(hr.size.x, hr.size.y) * 0.5 if round_hole else 26.0)
	mat.set_shader_parameter("rim", (0.55 + 0.45 * breath) if has_goal else 0.0)
	if pointer.visible and has_goal:
		pointer.position = pointer.position.lerp(_pointer_at(), k)
	if bubble.visible and int(_t * 10.0) % 3 == 0:
		_layout()
	# a forced step that waits too long offers «Дальше» (never a softlock)
	var to: = float(data.get("timeout", 0.0))
	if mode == "do" and to > 0.0 and _t - _shown_t > to and not is_instance_valid(_timeout_chip):
		_add_timeout_chip()


func _add_timeout_chip() -> void:
	var b: = JButton.make("Дальше", "glass", Rect2(0, 0, 160, 54), null, 20, 27.0, false)
	b.z_index = 7
	b.pressed.connect(func(): forced_continue.emit())
	add_child(b)
	_timeout_chip = b
	UI.pop_in(b, 0.0, 0.6)
	_layout()


# ── input ────────────────────────────────────────────────────────────────────────────────────────────────────

func in_hole(p: Vector2) -> bool:
	return has_goal and hole.grow(2.0).has_point(p)


func _has_point(p: Vector2) -> bool:
	if not visible or _closing:
		return false
	# a forced step lets the finger through the spotlight to the real target, and only there
	if mode == "do" and in_hole(p) and not is_instance_valid(_confirm):
		return false
	return true


func _gui_input(e: InputEvent) -> void:
	if not _press(e):
		return
	accept_event()
	_on_tap(false)


func _on_bubble_input(e: InputEvent) -> void:
	if not _press(e):
		return
	bubble.accept_event()
	_on_tap(true)


static func _press(e: InputEvent) -> bool:
	if e is InputEventMouseButton:
		return e.pressed and e.button_index == MOUSE_BUTTON_LEFT
	return e is InputEventScreenTouch and e.pressed


var _last_tap_f: = -1

func _on_tap(on_bubble: bool) -> void:
	# a real touch arrives as a touch and as an emulated mouse click: one answer per frame
	var f: = Engine.get_process_frames()
	if f == _last_tap_f:
		return
	_last_tap_f = f
	if is_instance_valid(_confirm) or _closing:
		return
	if _t - _shown_t < 0.22:
		return
	if typing():
		finish_typing()
		return
	if mode == "do":
		# the rest of the screen is closed in a forced step: the pointer wiggles toward the hole
		V9Feel.deny(bubble if on_bubble else null)
		if pointer.visible:
			var t: = pointer.create_tween()
			t.tween_property(pointer, "scale", Vector2(1.25, 1.25), 0.08)
			t.tween_property(pointer, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		return
	V9Feel.press(bubble, "pop", "tap")
	advanced.emit()


func _ask_skip() -> void:
	if is_instance_valid(_confirm):
		return
	_confirm = Control.new()
	_confirm.size = size
	_confirm.mouse_filter = Control.MOUSE_FILTER_STOP
	_confirm.z_index = 20
	add_child(_confirm)
	var sh: = ColorRect.new()
	sh.size = size
	sh.color = Color(0.02, 0.01, 0.03, 0.55)
	sh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_confirm.add_child(sh)
	var w: = minf(size.x - 48.0, 600.0)
	var h: = 300.0 * minf(ts(), 1.15)
	var p: = UI.rbox("plum", Rect2((size.x - w) * 0.5, (size.y - h) * 0.5, w, h), 32, 4, 14)
	p.colors(Color(0.17, 0.11, 0.2, 0.98), Color(0.09, 0.055, 0.11, 0.99)).borders(Color("fff0c4"), Color("b88432"))
	_confirm.add_child(p)
	var tl: = UI.center_label(UI.label("Пропустить обучение?", int(28 * minf(ts(), 1.15)), Color("ffe7b0"), UI.DARK, 4, "title", 900), Rect2(0, 24, w, 44))
	p.add_child(tl)
	var bl: = UI.label("Всё можно пересмотреть в «Как играть» —\nв настройках или по кнопке «?».", int(19 * ts()), Color("e8dccb"), UI.DARK, 2, "body", 800)
	bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bl.position = Vector2(24, 82)
	bl.size = Vector2(w - 48, 90)
	p.add_child(bl)
	var bw: = (w - 72.0) * 0.5
	var keep: = JButton.make("Продолжить", "pink", Rect2(24, h - 104, bw, 80), null, 24)
	keep.name = "No"
	keep.pressed.connect(func():
		var c: = _confirm
		_confirm = null
		if is_instance_valid(c):
			c.queue_free())
	p.add_child(keep)
	var skip: = JButton.make("Пропустить", "glass", Rect2(48 + bw, h - 104, bw, 80), null, 24, -1.0, false)
	skip.name = "Yes"
	skip.pressed.connect(func():
		var c: = _confirm
		_confirm = null
		if is_instance_valid(c):
			c.queue_free()
		skip_confirmed.emit())
	p.add_child(skip)
	p.pivot_offset = p.size * 0.5
	UI.pop_in(p, 0.0, 0.85)


func confirm_open() -> bool:
	return is_instance_valid(_confirm)


# fade everything out (end of a chapter / a tip read); the node stays for the next step unless free_after
func close(free_after: = false) -> void:
	if _closing:
		return
	_closing = true
	var g: = _gen
	pointer.visible = false
	skip_btn.visible = false
	if is_instance_valid(_timeout_chip):
		_timeout_chip.queue_free()
	var t: = create_tween().set_parallel()
	t.tween_method(func(v): mat.set_shader_parameter("amount", v), float(mat.get_shader_parameter("amount")), 0.0, 0.25)
	t.tween_property(bubble, "modulate:a", 0.0, 0.18)
	t.chain().tween_callback(func():
		if g != _gen:
			return
		bubble.visible = false
		visible = false
		hole = Rect2()
		closed.emit()
		if free_after:
			queue_free())


# a step change inside a chapter: the dim stays, the bubble swaps
func hide_bubble() -> void:
	bubble.visible = false
	pointer.visible = false


# a "wait" step: nothing on screen and nothing blocked
func idle() -> void:
	data = {}
	target_spec = null
	has_goal = false
	if visible and not _closing:
		close()
