class_name V10MjRiichiFx
extends Control

# Table inserts. Everything here is MOUSE_FILTER_IGNORE (input passes to the table) except the win cut-in, which the
# screen opens only in dead time (after ron/tsumo, the driver is held) and which a tap skips.
# Budgets (MODES §4.6): stamp 0.5 s · riichi ribbon 0.7 s · dora scene 0.5 s · win cut-in ≤ 2.2 s · yakuman ≤ 4 s.

signal cutin_done

const D = preload("res://scripts/v10/mj/riichi/riichi_data.gd")
const STAMP_T: = 0.5
const RIBBON_T: = 0.7
const DORA_T: = 0.5
const CUTIN_T: = 2.2
const YAKUMAN_T: = 4.0

var fx_min: = false
var cutin: Control = null
var live: = []           # [node, kind, t_end] for the selftest audit

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _track(n: CanvasItem, kind: String, dur: float) -> void:
	live.append([n, kind, Time.get_ticks_msec() / 1000.0 + dur])

# -------------------------------------------------------------- hanko stamp «ПОН» in her colour (code-drawn)
func stamp(center: Vector2, text: String, col: Color, rot_deg: = -8.0) -> Control:
	var s: = _Stamp.new()
	s.text = text
	s.col = col
	s.size = Vector2(150, 108)
	s.pivot_offset = s.size * 0.5
	s.position = center - s.size * 0.5
	s.rotation_degrees = rot_deg
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(s)
	_track(s, "stamp", STAMP_T)
	var tw: = s.create_tween()
	if fx_min:
		s.modulate.a = 0.0
		tw.tween_property(s, "modulate:a", 1.0, 0.12)
	else:
		s.scale = Vector2(1.6, 1.6)
		s.modulate.a = 0.0
		tw.set_parallel(true)
		tw.tween_property(s, "scale", Vector2(1.0, 1.0), 0.14).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tw.tween_property(s, "modulate:a", 1.0, 0.08)
		tw.set_parallel(false)
		tw.tween_property(s, "scale", Vector2(1.06, 0.94), 0.03)
		tw.tween_property(s, "scale", Vector2(1.0, 1.0), 0.05)
	tw.tween_interval(0.16)
	tw.tween_property(s, "modulate:a", 0.0, 0.12)
	tw.tween_callback(s.queue_free)
	return s

class _Stamp extends Control:
	var text: = "ПОН"
	var col: = Color.WHITE
	func _draw() -> void:
		var r: = Rect2(Vector2(6, 6), size - Vector2(12, 12))
		var sb: = StyleBoxFlat.new()
		sb.bg_color = Color(col, 0.16)
		sb.border_color = col
		sb.set_border_width_all(5)
		sb.set_corner_radius_all(14)
		draw_style_box(sb, r)
		var f: = UI.font("title", 800)
		var fs: = 46 if text.length() <= 3 else 38
		var w: = f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(f, Vector2((size.x - w) * 0.5 + 2, size.y * 0.5 + fs * 0.36 + 2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.35))
		draw_string(f, Vector2((size.x - w) * 0.5, size.y * 0.5 + fs * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col.lightened(0.15))

# -------------------------------------------------------------- riichi ribbon: her colour + portrait, 0.7 s, no block
func ribbon(y: float, w: float, hero: String, col: Color, big: String, small: String) -> Control:
	var rb: = Control.new()
	rb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rb.position = Vector2(0, y - 48)
	rb.size = Vector2(w, 96)
	rb.draw.connect(func():
		var n: = 24
		for i in n:
			var x0: = w * i / n
			var a: = sin(PI * (i + 0.5) / n)
			rb.draw_rect(Rect2(x0, 10, w / n + 1, 76), Color(col.darkened(0.2), 0.92 * a))
			rb.draw_rect(Rect2(x0, 10, w / n + 1, 22), Color(col.lightened(0.25), 0.25 * a))
		rb.draw_line(Vector2(0, 10), Vector2(w, 10), Color(col, 0.7), 2.0)
		rb.draw_line(Vector2(0, 86), Vector2(w, 86), Color(col, 0.7), 2.0))
	add_child(rb)
	var p: = V10MjRiichiPortrait.make(hero, 80, col)
	p.position = Vector2(w * 0.5 - 200, 8)
	p.set_face("shy", true)
	rb.add_child(p)
	var l: = UI.label(big, 40, Color("f5ead8"), Color(0, 0, 0, 0.5), 4, "title", 700)
	l.position = Vector2(w * 0.5 - 100, 14)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rb.add_child(l)
	var l2: = UI.label(small, 20, Color("f1d9a0"), Color(0, 0, 0, 0.5), 3, "body", 800)
	l2.position = Vector2(w * 0.5 - 98, 58)
	l2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rb.add_child(l2)
	_track(rb, "ribbon", RIBBON_T)
	var tw: = rb.create_tween()
	if fx_min:
		rb.modulate.a = 0.0
		tw.tween_property(rb, "modulate:a", 1.0, 0.12)
		tw.tween_interval(0.46)
		tw.tween_property(rb, "modulate:a", 0.0, 0.12)
	else:
		rb.position.x = -w * 0.35
		rb.modulate.a = 0.0
		tw.set_parallel(true)
		tw.tween_property(rb, "position:x", 0.0, 0.18).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		tw.tween_property(rb, "modulate:a", 1.0, 0.12)
		tw.set_parallel(false)
		tw.tween_interval(0.34)
		tw.chain().tween_property(rb, "position:x", w * 0.25, 0.18).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(rb, "modulate:a", 0.0, 0.18)
		tw.chain()
	tw.tween_callback(rb.queue_free)
	return rb

# -------------------------------------------------------------- riichi stick rolls onto the table (wood click)
func stick(from: Vector2, to: Vector2) -> Control:
	var s: = Control.new()
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.size = Vector2(64, 10)
	s.pivot_offset = s.size * 0.5
	s.position = from - s.size * 0.5
	s.draw.connect(func():
		var sb: = StyleBoxFlat.new()
		sb.bg_color = Color("f5ead8")
		sb.set_corner_radius_all(5)
		s.draw_style_box(sb, Rect2(Vector2.ZERO, s.size))
		s.draw_circle(s.size * 0.5, 3.0, Color("c8463c")))
	add_child(s)
	_track(s, "stick", 0.5)
	var tw: = s.create_tween().set_parallel(true)
	tw.tween_property(s, "position", to - s.size * 0.5, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if not fx_min:
		tw.tween_property(s, "rotation", TAU * 1.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.set_parallel(false)
	tw.tween_property(s, "modulate:a", 0.0, 0.1)
	tw.tween_callback(s.queue_free)
	return s

# -------------------------------------------------------------- new dora: her crest over the indicator, 0.5 s
func dora_scene(center: Vector2, hero: String, col: Color) -> Control:
	var path: = "res://assets/v10/mj/riichi/crest_%s.webp" % hero
	var n: = TextureRect.new()
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(path):
		n.texture = load(path)
	n.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	n.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	n.size = Vector2(150, 150)
	n.pivot_offset = n.size * 0.5
	n.position = center - n.size * 0.5
	var m: = CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	n.material = m
	n.modulate = Color(1, 1, 1, 0)
	add_child(n)
	_track(n, "dora", DORA_T)
	var tw: = n.create_tween()
	if not fx_min:
		n.scale = Vector2(0.6, 0.6)
		tw.set_parallel(true)
		tw.tween_property(n, "scale", Vector2(1.08, 1.08), DORA_T).set_trans(Tween.TRANS_SINE)
	tw.tween_property(n, "modulate:a", 1.0, 0.14)
	tw.set_parallel(false)
	tw.tween_interval(0.18)
	tw.tween_property(n, "modulate:a", 0.0, 0.18)
	tw.tween_callback(n.queue_free)
	return n

# -------------------------------------------------------------- subtitle of a rival's bark (no box, soft shadow)
func bark(at: Vector2, text: String, col: Color, align_right: = false) -> Control:
	if text == "":
		return null
	var l: = UI.label(text, 24, Color("f5ead8"), Color(0, 0, 0, 0.6), 5, "body", 800)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_color_override("font_shadow_color", Color(col.darkened(0.6), 0.7))
	l.add_theme_constant_override("shadow_offset_y", 2)
	add_child(l)
	l.reset_size()
	l.position = at - Vector2(l.size.x if align_right else 0.0, l.size.y * 0.5)
	l.position.x = clampf(l.position.x, 8, size.x - l.size.x - 8)
	_track(l, "bark", 1.8)
	l.modulate.a = 0.0
	var tw: = l.create_tween()
	tw.tween_property(l, "modulate:a", 1.0, 0.16)
	tw.tween_interval(1.4)
	tw.tween_property(l, "modulate:a", 0.0, 0.3)
	tw.tween_callback(l.queue_free)
	return l

# -------------------------------------------------------------- rival sticker (public events only, cooldown in screen)
func sticker(at: Vector2, hero: String, face: String, text: String, col: Color) -> Control:
	var c: = Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.size = Vector2(150, 64)
	c.position = at
	c.position.x = clampf(c.position.x, 8, size.x - c.size.x - 8)
	c.draw.connect(func():
		var sb: = StyleBoxFlat.new()
		sb.bg_color = Color("26212a")
		sb.border_color = Color(col, 0.6)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(4)
		c.draw_style_box(sb, Rect2(Vector2.ZERO, c.size)))
	var p: = V10MjRiichiPortrait.make(hero, 52, col)
	p.position = Vector2(6, 6)
	p.set_face(face, true)
	c.add_child(p)
	var l: = UI.label(text, 22, Color("f5ead8"), Color(0, 0, 0, 0), 0, "body", 800)
	l.position = Vector2(66, 16)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(l)
	add_child(c)
	_track(c, "sticker", 1.5)
	c.modulate.a = 0.0
	var tw: = c.create_tween()
	tw.tween_property(c, "modulate:a", 1.0, 0.15)
	tw.tween_interval(1.1)
	tw.tween_property(c, "modulate:a", 0.0, 0.25)
	tw.tween_callback(c.queue_free)
	return c

# -------------------------------------------------------------- tile flying from the hand to the pond
func fly_tile(t: int, from: Rect2, to: Rect2, rot: int, back: = "") -> void:
	var v: = V10MjRiichiTile.make(t, from.size, 0)
	v.back_path = back
	v.position = from.position
	add_child(v)
	_track(v, "fly", 0.18)
	var tw: = v.create_tween().set_parallel(true)
	tw.tween_property(v, "position", to.position, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(v, "size", to.size, 0.16)
	tw.set_parallel(false)
	tw.tween_callback(v.queue_free)

# -------------------------------------------------------------- win cut-in (dead time only; tap skips)
func win_cutin(hero: String, col: Color, title: String, small: String, who: String, line2: String, yakuman: bool, art: = "") -> Control:
	if cutin and is_instance_valid(cutin):
		cutin.queue_free()
	var dur: = YAKUMAN_T if yakuman else CUTIN_T
	var c: = Control.new()
	c.size = size
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	c.set_meta("dur", dur)
	cutin = c
	var t0: = Time.get_ticks_msec() / 1000.0
	var veil: = ColorRect.new()
	veil.color = Color(0.07, 0.06, 0.08, 0.72)
	veil.size = size
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(veil)
	var band: = Control.new()
	band.size = size
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.draw.connect(func():
		var h: = size.y
		var pts: = PackedVector2Array([Vector2(0, h * 0.5), Vector2(size.x, h * 0.36), Vector2(size.x, h * 0.58), Vector2(0, h * 0.72)])
		band.draw_colored_polygon(pts, Color(col.darkened(0.25), 0.88))
		band.draw_line(Vector2(0, h * 0.5), Vector2(size.x, h * 0.36), Color("e8c47e", 0.8), 2.0)
		band.draw_line(Vector2(0, h * 0.72), Vector2(size.x, h * 0.58), Color("e8c47e", 0.8), 2.0))
	c.add_child(band)
	var ap: = art if art != "" else V10W1Core.hero_png(hero)
	if not ResourceLoader.exists(ap):
		ap = V10W1Core.hero_png(hero)
	if not ResourceLoader.exists(ap):
		ap = "res://assets/hero/mc.png"
	if ResourceLoader.exists(ap):
		var tr: = TextureRect.new()
		tr.texture = load(ap)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		var hgt: = size.y * 0.86
		tr.size = Vector2(hgt * 0.671, hgt)
		tr.position = Vector2(size.x - tr.size.x * 0.86, size.y * 0.1)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.add_child(tr)
		if not fx_min:
			var p0: = tr.position
			tr.position.x += 220
			tr.modulate.a = 0.0
			var tw0: = tr.create_tween().set_parallel(true)
			tw0.tween_property(tr, "position", p0, 0.36).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
			tw0.tween_property(tr, "modulate:a", 1.0, 0.2)
	var y0: = size.y * 0.46
	var lt: = UI.label(title, 64, Color("f5ead8"), Color(0, 0, 0, 0.55), 6, "title", 700)
	lt.position = Vector2(40, y0)
	lt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(lt)
	var ls: = UI.label(small, 22, Color("f1d9a0"), Color(0, 0, 0, 0.5), 3, "body", 800)
	ls.position = Vector2(44, y0 + 78)
	ls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(ls)
	var lw: = UI.label(who + ("  ·  " + line2 if line2 != "" else ""), 26, Color("f5ead8"), Color(0, 0, 0, 0.5), 3, "body", 800)
	lw.position = Vector2(44, y0 + 112)
	lw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(lw)
	if yakuman and not fx_min:
		var motes: = Control.new()
		motes.size = size
		motes.mouse_filter = Control.MOUSE_FILTER_IGNORE
		motes.draw.connect(func():
			var tt: = Time.get_ticks_msec() / 1000.0 - t0
			for i in 18:
				var ph: = fposmod(tt * 0.12 + i * 0.137, 1.0)
				var x: = fposmod(i * 97.3, size.x)
				motes.draw_circle(Vector2(x + sin(tt + i) * 14.0, size.y * (1.0 - ph)), 2.0 + (i % 3), Color("f1d9a0", 0.55 * sin(PI * ph))))
		motes.set_process(true)
		c.add_child(motes)
		var tm: = Timer.new()
		tm.wait_time = 1.0 / 30.0
		tm.autostart = true
		tm.timeout.connect(motes.queue_redraw)
		c.add_child(tm)
	add_child(c)
	_track(c, "cutin_yakuman" if yakuman else "cutin", dur)
	c.modulate.a = 0.0
	var tw: = c.create_tween()
	tw.tween_property(c, "modulate:a", 1.0, 0.18)
	tw.tween_interval(dur - 0.42)
	tw.tween_property(c, "modulate:a", 0.0, 0.24)
	tw.tween_callback(_end_cutin.bind(c))
	c.gui_input.connect(func(e: InputEvent):
		if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
			_end_cutin(c))
	return c

func _end_cutin(c: Control) -> void:
	if not is_instance_valid(c) or c.has_meta("ended"):
		return
	c.set_meta("ended", true)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.queue_free()
	if cutin == c:
		cutin = null
	cutin_done.emit()

# nodes that would block input (selftest: none while a decision is pending)
func blocking() -> Array:
	var out: = []
	for n in get_children():
		if n is Control and is_instance_valid(n) and not n.is_queued_for_deletion() and (n as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE:
			out.append(n)
	return out
