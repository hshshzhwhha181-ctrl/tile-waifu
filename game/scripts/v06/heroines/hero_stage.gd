class_name V6HeroStage
extends Control






signal pressed

const POP: = 64.0
const COUNTER_H: = 58.0

var hero_id: = "mc"
var hero: Hero
var compact: = false
var col: = Color.WHITE
var halo: Sprite2D
var back: RBox
var counter: RBox
var gauge: RBox
var gauge_w: = 100.0
var gauge_lbl: Label
var emote_layer: Node2D
var bubble_node: Control
var charge: = 0
var need: = 8
var is_ready: = false
var _ready_tw: Tween
var _ring: = 0.0
var _sparks: CPUParticles2D
var cast_fx: Node
static var _shared_bubble: Control

func setup(id: String, rect: Rect2, opts: = {}) -> V6HeroStage:
	hero_id = id
	position = rect.position
	size = rect.size
	compact = opts.get("compact", false)
	col = G.HEROES[id].color
	mouse_filter = Control.MOUSE_FILTER_STOP
	pivot_offset = size * Vector2(0.5, 0.7)
	if compact:
		_build_compact(opts)
	else:
		_build_full(opts)
	emote_layer = Node2D.new()
	emote_layer.z_index = 5
	add_child(emote_layer)
	gui_input.connect( func(e):
		# left press only: with touch↔mouse emulation one tap also arrives as a ScreenTouch, which fired twice (0.9 fix)
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			pressed.emit())
	return self

func _build_full(opts: Dictionary) -> void :
	back = UI.rbox("glass", Rect2(Vector2.ZERO, size), 26, 3, 10)
	back.colors(Color(col.r * 0.42 + 0.05, col.g * 0.3 + 0.04, col.b * 0.45 + 0.08, 0.92), Color(0.07, 0.04, 0.14, 0.96))
	back.borders(col.lightened(0.45), Color("c58a2c"))
	add_child(back)
	var rig: Dictionary = Hero.RIGS[hero_id]
	var head_top: float = rig.head_c.y - rig.head_r * 1.05
	var waist: float = rig.waist_y
	var vis_h: = size.y - COUNTER_H * 0.45 + 40.0
	var s: float = vis_h / (waist - head_top)
	var clip: = Control.new()
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.position = Vector2(3, - POP)
	clip.size = Vector2(size.x - 6, size.y + POP - 3)
	add_child(clip)
	halo = Sprite2D.new()
	halo.texture = G.fx("glow")
	halo.material = Fx.add_mat()
	halo.modulate = Color(col.r, col.g, col.b, 0.5)
	clip.add_child(halo)
	hero = Hero.new().setup(hero_id, s * 1160.0)
	hero.interactive = false
	var cx: float = (rig.head_c.x * 0.6 + rig.chest_c.x * 0.4)
	hero.position = Vector2(clip.size.x * 0.5 - (cx - rig.feet.x) * s, POP - 40.0 + (rig.feet.y - head_top) * s)
	clip.add_child(hero)
	halo.position = hero.position + (rig.head_c - rig.feet) * s
	halo.scale = Vector2(3.0, 3.0) * s / 0.42

	counter = UI.rbox("plum", Rect2(-2, size.y - COUNTER_H, size.x + 4, COUNTER_H + 4), 20, 3, 8)
	counter.colors(Color(0.2, 0.1, 0.24, 0.97), Color(0.1, 0.05, 0.14, 0.98)).borders(Color("ffe7a6"), Color("c58a2c"))
	add_child(counter)
	var nm: = UI.label(G.HEROES[hero_id].name, 17, Color.WHITE, Color(0.2, 0.05, 0.2), 3, "body", 900)
	nm.position = Vector2(12, 2)
	nm.size = Vector2(size.x - 24, 24)
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nm.clip_text = true
	counter.add_child(nm)
	# 0.8: the bond tag («Симпатия N · …») gets its own pill above the name plate, never on the name's line
	var tag: String = opts.get("tag", "")
	if tag != "":
		var f: = UI.font("body", 900)
		# 0.8: 16 px (never smaller); the pill may grow to the full card width, longer tags trim with «…»
		var fs: = 16
		var maxw: = size.x - 4.0
		var pw: = minf(maxw, f.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 20.0)
		var pill: = UI.rbox("plum", Rect2(size.x - pw - 2, size.y - COUNTER_H - 30, pw, 26), 13, 2, 4)
		tag_pill = pill
		pill.colors(Color(0.2, 0.1, 0.24, 0.94), Color(0.1, 0.05, 0.14, 0.96)).borders(Color("ffe7a6"), Color("c58a2c"))
		add_child(pill)
		var tl: = UI.label(tag, fs, Color("ffd98a"), Color(0.1, 0.05, 0.2), 2, "body", 900)
		tl.position = Vector2(8, 0)
		tl.size = Vector2(pw - 16, 26)
		tl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		tl.clip_text = true
		pill.add_child(tl)
	var gb: = UI.rbox("plum", Rect2(12, 29, size.x - 24, 22), 11, 1, 2)
	gb.colors(Color(0, 0, 0, 0.5), Color(0, 0, 0, 0.35)).set_param("shadow_color", Color(0, 0, 0, 0))
	counter.add_child(gb)
	gauge_w = gb.size.x - 4
	gauge = UI.rbox("gold", Rect2(2, 2, 8, 18), 9, 0, 2)
	gauge.colors(Color("fff0b8"), col).set_param("shadow_color", Color(0, 0, 0, 0))
	gb.add_child(gauge)
	# 0.8: 16 px (was 12), readable at arm's length
	gauge_lbl = UI.label("", 16, Color.WHITE, Color(0.1, 0.03, 0.12), 4, "body", 900)
	gauge_lbl.size = gb.size
	gauge_lbl.position = Vector2(0, -1)
	gauge_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	gauge_lbl.clip_text = true
	gauge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gb.add_child(gauge_lbl)
	_sparks = Fx.particles("sparkle", 14, 1.0)
	_sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_sparks.emission_rect_extents = Vector2(size.x * 0.45, size.y * 0.4)
	_sparks.position = size * Vector2(0.5, 0.45)
	_sparks.direction = Vector2(0, -1)
	_sparks.spread = 30
	_sparks.gravity = Vector2(0, -40)
	_sparks.initial_velocity_min = 10
	_sparks.initial_velocity_max = 40
	_sparks.scale_amount_min = 0.15
	_sparks.scale_amount_max = 0.35
	_sparks.color = col.lightened(0.5)
	_sparks.emitting = false
	_sparks.one_shot = false
	_sparks.explosiveness = 0.0
	add_child(_sparks)

func _build_compact(_opts: Dictionary) -> void :
	add_child(Common.avatar(hero_id, Rect2(Vector2(6, 6), size - Vector2(12, 12)), "pink"))

func _draw() -> void :
	if not compact:
		return
	var c: = size * 0.5
	var r: = size.x * 0.5 - 2.0
	draw_arc(c, r, 0, TAU, 48, Color(0, 0, 0, 0.55), 6.0, true)
	if _ring > 0.0:
		draw_arc(c, r, - PI * 0.5, - PI * 0.5 + TAU * _ring, 48, Color("ffe7a6") if is_ready else col.lightened(0.2), 6.0, true)


func head_pos() -> Vector2:

	if hero:
		return get_parent().get_global_transform_with_canvas().affine_inverse() * hero.get_global_transform_with_canvas() * (hero.sprite.position + Hero.RIGS[hero_id].head_c * hero.sprite.scale.x)
	return position + Vector2(size.x * 0.5, 8)

func hand_pos() -> Vector2:
	return position + Vector2(size.x * 0.3, size.y * 0.55) if not compact else position + size * 0.5


func set_charge(cur: int, total: int) -> void :
	charge = cur
	need = maxi(1, total)
	var f: = clampf(float(cur) / need, 0.0, 1.0)
	if compact:
		_ring = f
		queue_redraw()
	elif gauge:
		gauge.create_tween().tween_property(gauge, "size:x", maxf(8.0, gauge_w * f), 0.25).set_trans(Tween.TRANS_QUAD)
		# 0.9: the skill meter is the Ultimate («ульта N/M», ready: tap the portrait)
		gauge_lbl.text = ("УЛЬТА · КОСНИСЬ" if size.x > 220.0 else "УЛЬТА!") if cur >= need else "ульта %d/%d" % [cur, need]
	if cur >= need and not is_ready:
		_set_ready(true)
	elif cur < need and is_ready:
		_set_ready(false)

func _set_ready(on: bool) -> void :
	is_ready = on
	if _ready_tw:
		_ready_tw.kill()
		_ready_tw = null
	if _sparks:
		_sparks.emitting = on and V9Feel.can_fx()
	if back:
		back.set_param("glow", 1.0 if on else 0.0).set_param("glow_color", col.lightened(0.3))
	if on:
		_ready_tw = create_tween().set_loops()
		if halo:
			_ready_tw.tween_property(halo, "modulate:a", 0.95, 0.45).set_trans(Tween.TRANS_SINE)
			_ready_tw.tween_property(halo, "modulate:a", 0.45, 0.45).set_trans(Tween.TRANS_SINE)
		else:
			_ready_tw.tween_property(self, "scale", Vector2(1.08, 1.08), 0.4).set_trans(Tween.TRANS_SINE)
			_ready_tw.tween_property(self, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_SINE)
		if gauge:
			gauge.set_param("glow", 1.0)
		emote("star")
	else:
		scale = Vector2.ONE
		if halo:
			halo.modulate.a = 0.5
		if gauge:
			gauge.set_param("glow", 0.0)
	queue_redraw()


func absorb(from: Vector2) -> void :
	var p: = get_parent()
	if p == null:
		return
	var s: = Sprite2D.new()
	s.texture = G.fx("sparkle")
	s.material = Fx.add_mat()
	s.modulate = col.lightened(0.4)
	s.scale = Vector2(0.35, 0.35)
	s.z_index = 41
	s.position = from
	p.add_child(s)
	var to: = position + (Vector2(size.x * 0.5, size.y - COUNTER_H * 0.45) if not compact else size * 0.5)
	var ctrl: = from.lerp(to, 0.5) + Vector2(60, -80)
	var t: = s.create_tween()
	t.tween_method( func(v: float): s.position = from.lerp(ctrl, v).lerp(ctrl.lerp(to, v), v), 0.0, 1.0, 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(s, "rotation", 4.0, 0.42)
	t.tween_callback(s.queue_free)


func react(kind: String) -> void :
	match kind:
		"match":
			if hero:
				hero.react("tap")
		"combo":
			if hero:
				hero.react("happy")
			if randf() < 0.5:
				emote("star")
		"big":
			if hero:
				hero.react("big")
				hero.flash(0.35)
			emote("heart")
		"deny":
			if hero:
				hero.react("sad")
			emote("sweat")
		"danger":
			emote("bang")
			Fx.shake(self, 4, 0.25)
		"fail":
			if hero:
				hero.react("sad")
			emote("dots")
		"anger":
			if hero:
				hero.react("tap")
			emote("anger")
			Fx.shake(self, 6, 0.3)
		"smug":
			if hero:
				hero.react("happy")
			emote("star")
		"win":
			if hero:
				hero.react("big")
			emote("heart")
	if compact or hero == null:
		UI.punch(self, 0.12 if kind == "match" else 0.25)

# 0.8: a short emotion pop on the portrait card (HUD edge, never over the board, takes no taps): the rig crossfades
# into her emotion bust with a subtle bounce, holds, and crossfades back — ≤ 1.2 s in all. A pop while one is up
# crossfades the bust to the new emotion and restarts the hold. Missing art: the rig just reacts (base art).
const EMO_IN: = 0.2
const EMO_OUT: = 0.26
var _emo_pop: = 0
var _emo_av: Control = null

func flash_emotion(kind: String, hold: = 0.6) -> void :
	var e: = V8Art.emo_name(kind)
	if e == "" or not is_visible_in_tree():
		return
	var p: = get_parent()
	if p and (p.get("_v8_modal") == true or p.get("_v8_over") == true):
		return
	if not V8Art.has_emotion(hero_id, e):
		return
	hold = clampf(hold, 0.2, 1.2 - EMO_IN - EMO_OUT * 1.3)
	_emo_pop += 1
	var my: = _emo_pop
	if compact:
		_emo_compact(e, hold, my)
		return
	if hero == null:
		return
	var was_up: = hero.emo != ""
	# 0.8: the bust is drawn at the rig's own face size (was 1.3×), so the pop keeps her hair and ribbons inside the
	# card frame exactly where the resting portrait is; the expression change carries the beat, not a zoom
	hero.set_emotion(e, EMO_IN, 1.0, 0.12)
	if not was_up and hero.emo_bust:
		V8Art.bust_bounce(hero.emo_bust, 0.045)
	await get_tree().create_timer(EMO_IN + hold).timeout
	if my != _emo_pop or not is_instance_valid(hero):
		return
	hero.set_emotion("", EMO_OUT)

func _emo_compact(e: String, hold: float, my: int) -> void :
	if _emo_av and is_instance_valid(_emo_av):
		_emo_av.queue_free()
	var av: = V8Art.emotion_avatar(hero_id, e, Rect2(Vector2(6, 6), size - Vector2(12, 12)), "pink")
	_emo_av = av
	add_child(av)
	move_child(av, mini(1, get_child_count() - 1))
	av.modulate.a = 0.0
	av.scale = Vector2.ONE * 0.92
	var t: = av.create_tween()
	t.tween_property(av, "modulate:a", 1.0, EMO_IN).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(av, "scale", Vector2.ONE * 1.06, EMO_IN).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(av, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_interval(maxf(0.0, hold - 0.3))
	t.tween_property(av, "modulate:a", 0.0, EMO_OUT).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.tween_callback( func():
		if my == _emo_pop:
			_emo_av = null
		av.queue_free())

func emote(kind: String) -> void :
	var hp: = head_pos() - position
	var at: = hp + Vector2( - size.x * 0.28, -40) if not compact else Vector2(size.x * 0.85, 0)
	var n: = Node2D.new()
	n.position = at
	emote_layer.add_child(n)
	match kind:
		"heart":
			for i in 3:
				var h: = Sprite2D.new()
				h.texture = G.fx("heart")
				h.scale = Vector2(0.28, 0.28) * (1.0 - i * 0.2)
				h.position = Vector2(i * 22 - 10, i * 10)
				h.modulate = Color("ff7fa8")
				n.add_child(h)
		"star":
			for i in 3:
				var h: = Sprite2D.new()
				h.texture = G.fx("sparkle")
				h.material = Fx.add_mat()
				h.scale = Vector2(0.4, 0.4) * (1.0 - i * 0.25)
				h.position = Vector2(i * 24 - 12, - i * 14)
				h.modulate = Color("fff0b8")
				n.add_child(h)
		"sweat":
			var d: = Polygon2D.new()
			var pts: = PackedVector2Array()
			pts.append(Vector2(0, -22))
			for i in range(1, 16):
				var a: = TAU * i / 16.0
				pts.append(Vector2(sin(a) * 9.0, - cos(a) * 9.0))
			d.polygon = pts
			d.color = Color("9fd8ff")
			n.add_child(d)
			var hl: = Polygon2D.new()
			hl.polygon = PackedVector2Array([Vector2(-3, -4), Vector2(0, -10), Vector2(2, -3)])
			hl.color = Color(1, 1, 1, 0.9)
			n.add_child(hl)
			n.position += Vector2(size.x * 0.4 if not compact else 0, 20)
		"bang":
			var l: = UI.label("!", 46, Color("ffd34d"), Color(0.35, 0.05, 0.1), 6, "title", 900)
			l.position = Vector2(-12, -40)
			n.add_child(l)
		"dots":
			var l: = UI.label("...", 34, Color.WHITE, Color(0.2, 0.05, 0.2), 5, "body", 900)
			l.position = Vector2(-20, -36)
			n.add_child(l)
		"anger":
			for i in 4:
				var ln: = Line2D.new()
				ln.width = 5
				ln.default_color = Color("ff4d6a")
				var a: = PI * 0.5 * i + PI * 0.25
				var d2: = Vector2(cos(a), sin(a))
				ln.points = PackedVector2Array([d2 * 6, d2 * 16 + d2.orthogonal() * 4])
				n.add_child(ln)
	n.scale = Vector2(0.3, 0.3)
	var t: = n.create_tween()
	t.tween_property(n, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(n, "position:y", n.position.y - 16, 0.9)
	t.tween_interval(0.3)
	t.tween_property(n, "modulate:a", 0.0, 0.3)
	t.tween_callback(n.queue_free)


func say_text(text: String, dur: = 2.6, talk: = true) -> void :
	if text == "":
		return
	var p: Control = get_parent()
	# 0.8: no speech over a window (overflow / result) of the match
	if p and (p.get("_v8_modal") == true or p.get("_v8_over") == true):
		return
	if _shared_bubble and is_instance_valid(_shared_bubble):
		_shared_bubble.queue_free()
	var w: = 300.0
	var left_side: = position.x > p.size.x * 0.5
	if not compact and left_side and p.get("board_rect") is Rect2:
		# 0.8: in a match the line is said inside the portrait card, over the name plate and skill gauge
		# (tail up to her face): never over the HUD plates and never over a tile row of the table
		bubble_node = _card_bubble(text)
		_shared_bubble = bubble_node
		var cb: = bubble_node
		# the opaque bubble hides the bond tag for its lifetime (a two-line bubble and its tail would cut the
		# «Симпатия N» pill in half); the tag comes back when the bubble is gone
		_tag_hide(cb)
		var ct: Tween = cb.create_tween()
		ct.tween_interval(dur)
		ct.tween_property(cb, "modulate:a", 0.0, 0.3)
		ct.tween_callback(cb.queue_free)
		if talk:
			Sfx.voice_started.emit(hero_id, text, minf(dur * 0.6, 0.35 + text.length() * 0.05))
		return
	bubble_node = Common.bubble(p, text, Vector2.ZERO, w, not left_side)
	bubble_node.z_index = 42
	var hp: = head_pos()
	var bx: = position.x - w + 36.0 if left_side else position.x + size.x - 30.0
	bubble_node.position = Vector2(clampf(bx, 6.0, p.size.x - w - 6.0), clampf(hp.y - bubble_node.size.y - 4.0, 4.0, 400.0))
	if compact:
		bubble_node.position = Vector2(position.x + size.x * 0.6, position.y + 2.0)
	elif left_side:
		# 0.8: in a match the bubble hangs under the portrait card (tail up), never over the goal / shard plate
		# at HUD height; the combo pill keeps the left side of that band.
		var top: = position.y + size.y + 16.0
		var br = p.get("board_rect")
		if br is Rect2:
			top = maxf(top, (br as Rect2).position.y + 6.0)
		bubble_node.position = Vector2(clampf(position.x + size.x - w, 6.0, p.size.x - w - 6.0), top)
		bubble_node.pivot_offset = Vector2(w * 0.8, 0)
		for c in bubble_node.get_children():
			if c is Polygon2D:
				(c as Polygon2D).polygon = PackedVector2Array([Vector2(w - 84, 6), Vector2(w - 44, 6), Vector2(w - 40, -22)])
	_shared_bubble = bubble_node
	var b: = bubble_node
	var t: Tween = b.create_tween()
	t.tween_interval(dur)
	t.tween_property(b, "modulate:a", 0.0, 0.3)
	t.tween_callback(b.queue_free)
	if talk:
		Sfx.voice_started.emit(hero_id, text, minf(dur * 0.6, 0.35 + text.length() * 0.05))


var tag_pill: Control = null

func _tag_hide(b: Control) -> void :
	if tag_pill == null or not is_instance_valid(tag_pill):
		return
	tag_pill.visible = false
	b.tree_exited.connect( func():
		if not is_instance_valid(tag_pill):
			return
		var nb: = _shared_bubble
		# keep it hidden only while a newer bubble of THIS card is up
		if nb == null or not is_instance_valid(nb) or nb == b or nb.is_queued_for_deletion() or nb.get_parent() != self:
			tag_pill.visible = true)


func _card_bubble(text: String) -> Control:
	var w: = size.x + 4.0
	var f: = UI.font("body", 800)
	var fs: = 18
	var th: float = f.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, w - 24.0, fs).y
	while fs > 16 and th > 3.0 * fs * 1.4:
		fs -= 1
		th = f.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, w - 24.0, fs).y
	var h: = maxf(COUNTER_H + 4.0, th + 18.0)
	var root: = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.position = Vector2(-2, size.y - h)
	root.size = Vector2(w, h)
	root.z_index = 6
	var tail: = Polygon2D.new()
	tail.color = Color(0.12, 0.11, 0.13, 0.97)
	tail.polygon = PackedVector2Array([Vector2(w * 0.5 - 18, 6), Vector2(w * 0.5 + 18, 6), Vector2(w * 0.5 + 6, -18)])
	root.add_child(tail)
	var b: = UI.rbox("cream", Rect2(0, 0, w, h), 20, 3, 8)
	b.set_param("border_top", Color("e8c9a0")).set_param("border_bottom", Color("a8697a"))
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(b)
	var l: = UI.label(text, fs, UI.INK)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.position = Vector2(12, 6)
	l.size = Vector2(w - 24, h - 12)
	root.add_child(l)
	add_child(root)
	root.pivot_offset = Vector2(w * 0.5, 0)
	root.scale = Vector2(0.6, 0.6)
	root.modulate.a = 0.0
	var t: = root.create_tween().set_parallel()
	t.tween_property(root, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(root, "modulate:a", 1.0, 0.12)
	return root


func say(kind: String) -> String:
	var line: = Sfx.say(hero_id, kind)
	say_text(line, 2.6, false)
	return line




func cast(title: String, targets: Array, sub: = "") -> void :
	var p: Control = get_parent()
	var layer: Node = cast_fx if cast_fx else p
	if hero:
		hero.react("big")
		hero.flash(0.8)
	UI.punch(self, 0.3)
	Sfx.play("fever", 1.3)
	# 0.9: no band here any more — the player's ult has its own cut-in (V9Cutin) and a duel rival's skill is
	# «one line and the target highlighted» (HEROINES.md §2); title / sub stay for callers' logs
	await get_tree().create_timer(0.35).timeout
	if not is_inside_tree():
		return
	var from: = hand_pos()
	var last: = 0.0
	for i in targets.size():
		var d: = 0.07 * i
		last = d
		# 0.10 M0: targets are viewport points (tiles); the orbs fly in the layer's own coordinates (the screen sits in
		# the content column, not at the viewport origin)
		var to: Vector2 = V10Layout.local_of(layer as CanvasItem, targets[i]) if layer is CanvasItem else targets[i]
		_orb(layer, from, to, d)
	await get_tree().create_timer(last + 0.48).timeout

func _orb(layer: Node, from: Vector2, to: Vector2, delay: float) -> void :
	var o: = Node2D.new()
	o.z_index = 160
	o.position = from
	layer.add_child(o)
	var g: = Sprite2D.new()
	g.texture = G.fx("glow")
	g.material = Fx.add_mat()
	g.modulate = Color(col.r, col.g, col.b, 0.95)
	g.scale = Vector2(0.9, 0.9)
	o.add_child(g)
	var c: = Sprite2D.new()
	c.texture = G.fx("sparkle")
	c.material = Fx.add_mat()
	c.scale = Vector2(0.45, 0.45)
	o.add_child(c)
	var tr: = Fx.particles("sparkle", 24, 0.4)
	tr.local_coords = false
	tr.initial_velocity_min = 0
	tr.initial_velocity_max = 20
	tr.scale_amount_min = 0.1
	tr.scale_amount_max = 0.25
	tr.color = col.lightened(0.5)
	tr.emitting = true
	o.add_child(tr)
	o.modulate.a = 0.0
	var ctrl: = from.lerp(to, 0.5) + Vector2(-140 if to.x < from.x else 140, -160)
	var t: = o.create_tween()
	t.tween_interval(delay)
	t.tween_property(o, "modulate:a", 1.0, 0.05)
	t.tween_method( func(v: float):
		o.position = from.lerp(ctrl, v).lerp(ctrl.lerp(to, v), v)
		c.rotation = v * 8.0, 0.0, 1.0, 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.tween_callback( func():
		Fx.flash_glow(layer, to, col.lightened(0.4), 2.2, 0.3)
		Fx.burst(layer, to, "sparkle", 18, col.lightened(0.3), 1.1)
		Sfx.play("pop", 1.3, -6)
		tr.emitting = false
		g.visible = false
		c.visible = false)
	t.tween_interval(0.45)
	t.tween_callback(o.queue_free)


# 0.9: the outfit's ult modifier (П/О/Л/В/Ц/С, HEROINES.md §2) as a small lacquer medallion on the card's top-left
# corner (HUD, never over the board, takes no taps). "" removes it.
var ult_badge: Control = null

func set_ult_badge(letter: String, c: Color, hint: = "") -> void :
	if ult_badge and is_instance_valid(ult_badge):
		ult_badge.queue_free()
	ult_badge = null
	if letter == "" or compact:
		return
	var d: = 34.0
	var b: = UI.rbox("plum", Rect2(8, 8, d, d), d * 0.5, 2, 2)
	b.colors(Color(c.r * 0.45 + 0.08, c.g * 0.35 + 0.05, c.b * 0.5 + 0.1, 0.96), Color(0.08, 0.04, 0.12, 0.98))
	b.borders(Color("ffe7a6"), Color("c58a2c"))
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.tooltip_text = hint
	b.z_index = 4
	add_child(b)
	# 0.9: the modifier's gold glyph (V9ModIcon), not a bare Cyrillic letter
	var ic: = V9ModIcon.make(letter, d - 10.0)
	ic.position = Vector2(5, 5)
	b.add_child(ic)
	ult_badge = b
