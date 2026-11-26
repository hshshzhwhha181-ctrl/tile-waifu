class_name V10BottomUltStage
extends V6HeroStage

const MEDAL_D: = 136.0
const MEDAL_POS: = Vector2(54.0, 4.0)

var _frac: = 0.0
var _pulse_t: = 0.0
var _av_holder: Control
var _av_node: Control
var _cta_box: Control
var _ult_lbl: Label


func setup_bottom(id: String, rect: Rect2, opts: = {}) -> V10BottomUltStage:
	hero_id = id if G.HEROES.has(id) else "mc"
	position = rect.position
	size = rect.size
	compact = false
	col = G.HEROES[hero_id].color
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	pivot_offset = MEDAL_POS + Vector2(MEDAL_D, MEDAL_D) * 0.5
	_build_bottom_widget(opts)
	emote_layer = Node2D.new()
	emote_layer.z_index = 12
	add_child(emote_layer)
	gui_input.connect(func(e: InputEvent):
		if (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT):
			accept_event()
			pressed.emit())
	return self


func _build_bottom_widget(_opts: Dictionary) -> void:
	halo = Sprite2D.new()
	halo.texture = G.fx("glow")
	halo.material = Fx.add_mat()
	halo.position = MEDAL_POS + Vector2(MEDAL_D, MEDAL_D) * 0.5
	halo.scale = Vector2(2.35, 2.35)
	halo.modulate = Color(col.r, col.g, col.b, 0.32)
	add_child(halo)

	_av_holder = Control.new()
	_av_holder.position = MEDAL_POS + Vector2(10, 10)
	_av_holder.size = Vector2(MEDAL_D - 20.0, MEDAL_D - 20.0)
	_av_holder.pivot_offset = _av_holder.size * 0.5
	_av_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_av_holder)
	_set_portrait_emo("happy")

	var ring_overlay: = Control.new()
	ring_overlay.name = "MedalRing"
	ring_overlay.size = size
	ring_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring_overlay.z_index = 4
	ring_overlay.draw.connect(_draw_medal_ring.bind(ring_overlay))
	add_child(ring_overlay)

	_cta_box = Control.new()
	_cta_box.name = "UltPlaque"
	_cta_box.position = Vector2(8.0, 138.0)
	_cta_box.size = Vector2(size.x - 16.0, 46.0)
	_cta_box.pivot_offset = _cta_box.size * 0.5
	_cta_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cta_box.z_index = 6
	_cta_box.draw.connect(_draw_plaque)
	add_child(_cta_box)

	_ult_lbl = UI.label("УЛЬТА · 0/8", 21, Color("fff3d6"), Color(0.18, 0.03, 0.08), 5, "body", 900)
	_ult_lbl.position = Vector2(10.0, 0.0)
	_ult_lbl.size = Vector2(_cta_box.size.x - 20.0, _cta_box.size.y)
	_ult_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ult_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_ult_lbl.clip_text = true
	_ult_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cta_box.add_child(_ult_lbl)

	# Keep gauge_lbl populated with "умение N/M" (hidden) so V9UltSelftest and tower_play._fix_stage_text stay 100% compatible
	gauge_lbl = UI.label("умение 0/8", 16, Color.WHITE)
	gauge_lbl.visible = false
	add_child(gauge_lbl)

	_sparks = Fx.particles("sparkle", 20, 1.05)
	_sparks.material = Fx.add_mat()
	_sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_sparks.emission_sphere_radius = MEDAL_D * 0.48
	_sparks.position = MEDAL_POS + Vector2(MEDAL_D, MEDAL_D) * 0.5
	_sparks.direction = Vector2(0, -1)
	_sparks.spread = 42.0
	_sparks.gravity = Vector2(0, -48)
	_sparks.initial_velocity_min = 18.0
	_sparks.initial_velocity_max = 58.0
	_sparks.scale_amount_min = 0.16
	_sparks.scale_amount_max = 0.36
	_sparks.color = Color("ffe7a6")
	_sparks.emitting = false
	add_child(_sparks)


func _set_portrait_emo(emo: String) -> void:
	if _av_holder == null:
		return
	for c in _av_holder.get_children():
		c.queue_free()
	var d: = _av_holder.size.x
	var eq: = G.equipped(hero_id)
	var img_id: = String(G.ITEM.get(eq, {}).get("img", "")) if eq != "" else ""
	if emo == "happy" and img_id != "" and not bool(G.S.get("modest", false)):
		_av_node = Common.avatar(img_id, Rect2(Vector2.ZERO, Vector2(d, d)), "gold")
	else:
		_av_node = V8Art.emotion_avatar(hero_id, emo, Rect2(Vector2.ZERO, Vector2(d, d)), "gold")
	_av_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_av_holder.add_child(_av_node)


func _draw() -> void:
	var c: = MEDAL_POS + Vector2(MEDAL_D, MEDAL_D) * 0.5
	var r_outer: = MEDAL_D * 0.5
	draw_circle(c + Vector2(0, 5), r_outer + 3.0, Color(0.03, 0.01, 0.05, 0.62))
	draw_circle(c, r_outer + 2.0, Color("c58a2c"))
	draw_circle(c, r_outer - 1.5, Color(0.11, 0.05, 0.14, 0.98))


func _draw_medal_ring(ro: Control) -> void:
	var c: = MEDAL_POS + Vector2(MEDAL_D, MEDAL_D) * 0.5
	var r: = MEDAL_D * 0.5 - 4.0
	# Dark track + gold inner & outer filigree rims
	ro.draw_arc(c, r, 0.0, TAU, 64, Color(0.06, 0.02, 0.09, 0.86), 9.0, true)
	ro.draw_arc(c, r + 5.0, 0.0, TAU, 64, Color("ffe7a6") if is_ready else Color("c58a2c"), 2.2, true)
	ro.draw_arc(c, r - 5.0, 0.0, TAU, 64, Color(1.0, 0.91, 0.68, 0.55), 1.5, true)

	if _frac > 0.005:
		var pulse: = 0.82 + 0.18 * sin(_pulse_t * 6.5) if is_ready else 1.0
		var arc_col: = Color("ffe7a6").lerp(Color("ff6f9f"), 0.25 * (1.0 - pulse)) if is_ready else col.lightened(0.28).lerp(Color("ffd98a"), _frac * 0.55)
		if is_ready:
			ro.draw_arc(c, r + 8.0, 0.0, TAU, 64, Color(1.0, 0.84, 0.42, 0.42 * pulse), 6.0, true)
		ro.draw_arc(c, r, -PI * 0.5, -PI * 0.5 + TAU * _frac, 64, arc_col, 7.5, true)
		# Bright tip spark on the charging arc
		if _frac < 0.995:
			var ta: = -PI * 0.5 + TAU * _frac
			var tp: = c + Vector2(cos(ta), sin(ta)) * r
			ro.draw_circle(tp, 5.5, Color("fff8e4"))

	var segs: = clampi(need, 2, 12)
	for i in segs:
		var a: = -PI * 0.5 + TAU * float(i) / float(segs)
		var p0: = c + Vector2(cos(a), sin(a)) * (r - 4.5)
		var p1: = c + Vector2(cos(a), sin(a)) * (r + 4.5)
		ro.draw_line(p0, p1, Color(0.08, 0.03, 0.10, 0.72), 2.0, true)

	# 4 compass gold diamond jewels
	for i in 4:
		var a2: = PI * 0.5 * float(i)
		var dc: = c + Vector2(cos(a2), sin(a2)) * (r + 5.2)
		var dr: = 4.8 if is_ready else 3.8
		ro.draw_colored_polygon(PackedVector2Array([dc + Vector2(0, -dr), dc + Vector2(dr, 0), dc + Vector2(0, dr), dc + Vector2(-dr, 0)]),
			Color("fff4d2") if is_ready else Color("e8c47e"))


func _draw_plaque() -> void:
	if _cta_box == null:
		return
	var r: = Rect2(Vector2.ZERO, _cta_box.size)
	var tex: = V10Button._hf_tex(not is_ready)
	if tex != null:
		var src: = Rect2(6.0, 48.0, 668.0, 105.0) if is_ready else Rect2(5.0, 47.0, 670.0, 104.0)
		var scap: = 112.0 if is_ready else 60.0
		V10Button.draw_hf_pill(_cta_box, tex, r, src, scap, Color.WHITE)
	else:
		V10Button.lacquer(_cta_box, r, 22.0, Color("df4f74") if is_ready else Color("2f2438"),
			Color("ae284b") if is_ready else Color("221929"), Color("6d142e") if is_ready else Color("16101c"))


func _process(dt: float) -> void:
	if is_ready:
		_pulse_t += dt
		if has_node("MedalRing"):
			(get_node("MedalRing") as Control).queue_redraw()


func head_pos() -> Vector2:
	return position + MEDAL_POS + Vector2(MEDAL_D * 0.5, MEDAL_D * 0.34)


func hand_pos() -> Vector2:
	return position + MEDAL_POS + Vector2(MEDAL_D * 0.5, MEDAL_D * 0.5)


func set_charge(cur: int, total: int) -> void:
	charge = cur
	need = maxi(1, total)
	var f: = clampf(float(cur) / float(need), 0.0, 1.0)
	var tw: = create_tween()
	tw.tween_method(func(v: float):
		_frac = v
		if has_node("MedalRing"):
			(get_node("MedalRing") as Control).queue_redraw(), _frac, f, 0.22).set_trans(Tween.TRANS_QUAD)
	if gauge_lbl:
		gauge_lbl.text = "УМЕНИЕ!" if cur >= need else "умение %d/%d" % [cur, need]
	if _ult_lbl:
		if gauge_lbl and gauge_lbl.text == "без приёма":
			_ult_lbl.text = "БЕЗ ПРИЁМА"
			_ult_lbl.label_settings.font_size = 18
			_ult_lbl.label_settings.font_color = Color("b3a89c")
		elif cur >= need:
			_ult_lbl.text = "УЛЬТА!"
			_ult_lbl.label_settings.font_size = 25
			_ult_lbl.label_settings.font_color = Color("fff8ec")
		else:
			_ult_lbl.text = "УЛЬТА · %d/%d" % [cur, need]
			_ult_lbl.label_settings.font_size = 20
			_ult_lbl.label_settings.font_color = Color("f1d9a0")
	if cur >= need and not is_ready:
		_set_ready(true)
	elif cur < need and is_ready:
		_set_ready(false)
	if _cta_box:
		_cta_box.queue_redraw()


func _set_ready(on: bool) -> void:
	is_ready = on
	if _ready_tw:
		_ready_tw.kill()
		_ready_tw = null
	if _sparks:
		_sparks.emitting = on and V9Feel.can_fx()
	if on:
		_ready_tw = create_tween().set_loops()
		if halo:
			halo.modulate = Color(1.0, 0.84, 0.42, 0.85)
		if _cta_box:
			_ready_tw.tween_property(_cta_box, "scale", Vector2(1.06, 1.06), 0.42).set_trans(Tween.TRANS_SINE)
			_ready_tw.tween_property(_cta_box, "scale", Vector2.ONE, 0.42).set_trans(Tween.TRANS_SINE)
		emote("star")
	else:
		if halo:
			halo.modulate = Color(col.r, col.g, col.b, 0.32)
		if _cta_box:
			_cta_box.scale = Vector2.ONE
	if has_node("MedalRing"):
		(get_node("MedalRing") as Control).queue_redraw()
	if _cta_box:
		_cta_box.queue_redraw()


func flash_emotion(kind: String, hold: = 0.75) -> void:
	var e: = V8Art.emo_name(kind)
	if e == "" or not is_visible_in_tree():
		return
	var p: = get_parent()
	if p and (p.get("_v8_modal") == true or p.get("_v8_over") == true):
		return
	_emo_pop += 1
	var my: = _emo_pop
	_set_portrait_emo(e)
	if _av_holder:
		UI.punch(_av_holder, 0.16)
	await get_tree().create_timer(clampf(hold, 0.35, 1.1)).timeout
	if my != _emo_pop or not is_inside_tree():
		return
	_set_portrait_emo("happy")


func set_ult_badge(letter: String, c: Color, hint: = "") -> void:
	if ult_badge and is_instance_valid(ult_badge):
		ult_badge.queue_free()
	ult_badge = null
	if letter == "":
		return
	var d: = 36.0
	var b: = UI.rbox("plum", Rect2(MEDAL_POS.x + MEDAL_D - d + 2.0, MEDAL_POS.y + 2.0, d, d), d * 0.5, 2, 4)
	b.colors(Color(c.r * 0.45 + 0.08, c.g * 0.35 + 0.05, c.b * 0.5 + 0.1, 0.98), Color(0.08, 0.04, 0.12, 0.99))
	b.borders(Color("ffe7a6"), Color("c58a2c"))
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.tooltip_text = hint
	b.z_index = 10
	add_child(b)
	var ic: = V9ModIcon.make(letter, d - 10.0)
	ic.position = Vector2(5, 5)
	b.add_child(ic)
	ult_badge = b


func say_text(text: String, dur: = 2.6, talk: = true) -> void:
	if text == "":
		return
	var p: Control = get_parent()
	if p == null or p.get("_v8_modal") == true or p.get("_v8_over") == true:
		return
	if _shared_bubble and is_instance_valid(_shared_bubble):
		_shared_bubble.queue_free()
	var w: = 296.0
	bubble_node = Common.bubble(p, text, Vector2.ZERO, w, false)
	bubble_node.z_index = 48
	_ignore_rec(bubble_node)
	var bx: = clampf(position.x + size.x - w - 4.0, 12.0, p.size.x - w - 12.0)
	var by: = maxf(60.0, position.y - bubble_node.size.y - 14.0)
	bubble_node.position = Vector2(bx, by)
	_shared_bubble = bubble_node
	var b: = bubble_node
	var t: Tween = b.create_tween()
	t.tween_interval(dur)
	t.tween_property(b, "modulate:a", 0.0, 0.3)
	t.tween_callback(b.queue_free)
	if talk:
		Sfx.voice_started.emit(hero_id, text, minf(dur * 0.6, 0.35 + text.length() * 0.05))


static func _ignore_rec(n: Node) -> void:
	if n is Control:
		(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in n.get_children():
		_ignore_rec(c)
