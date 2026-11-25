class_name V10WinBar
extends Control

# V10WinBar — one progress bar of the victory stack (V10WinStack). Shared look for the salon (M2), mastery and pass
# (M4) bars so the window stays harmonious: a HUD_V2 M plate (80 px, radius 4, one hairline), icon 48, title Body 22,
# the counter «3/4★» in the right slot (Numerals 22, gold.300), and either star pips (kind "stars", need ≤ 8) or a
# progress line (kind "fill").
#
#   V10WinBar.make(width, opts) -> V10WinBar
#     opts: icon (Texture2D or V8Art icon name), title, have, need, gain (how many of `have` are new this win),
#           kind "stars" | "fill", unit ("★" default for stars, "" for fill), ready_text («Можно восстановить!»
#           shown when have ≥ need), pal ("gold" | "pink" | "jade" | "lav": the fill tone), sub (caption for fill
#           bars, shown in place of the line's right end), tap (true: the row is tappable and emits `pressed`)
#   bar.play(delay) — the new stars fly in one by one after the 0.9 stamps (sparkle with a rising pitch, a light
#                     haptic each), the line grows; when full, the gold plaque jumps in (sparkle pitch 1.2) and bobs
#                     twice (no endless motion: UX §6.7 allows one infinite UI animation — the primary button's)
#   signal pressed — only with opts.tap (V9Feel.press); by default a bar is information, not a button (UX §3.4:
#                    the victory screen has one primary and ≤ 2 secondary actions)
# Respects S.fx_level through V9Feel: at «min» stars and plaque appear with a 120 ms fade, no flight, no particles.

signal pressed

const H: = 80.0
const ICON: = 48.0
const TX: = 88.0

var opts: Dictionary
var w: = 0.0
var pips: Array = []
var fill: Panel
var fill_bg: Panel
var count_lbl: Label
var plaque: Control
var icon_rect: TextureRect


static func make(width: float, o: Dictionary) -> V10WinBar:
	var b: = V10WinBar.new()
	b.opts = o
	b.w = width
	b.size = Vector2(width, H)
	b.custom_minimum_size = b.size
	b._build()
	return b


func _have() -> int:
	return int(opts.get("have", 0))


func _need() -> int:
	return maxi(1, int(opts.get("need", 1)))


func _gain() -> int:
	return clampi(int(opts.get("gain", 0)), 0, _have())


func _tone() -> Color:
	match str(opts.get("pal", "gold")):
		"pink":
			return V10MetaUI.ROSE_300
		"jade", "lav":
			return V10MetaUI.JADE_300
	return V10MetaUI.GOLD_300


func _build() -> void:
	var tap: = bool(opts.get("tap", false))
	mouse_filter = Control.MOUSE_FILTER_STOP if tap else Control.MOUSE_FILTER_IGNORE
	if tap:
		V10MetaUI.role(self, "secondary")
	add_child(V10MetaUI.plate(Rect2(0, 0, w, H)))
	var ic = opts.get("icon", null)
	var tex: Texture2D = ic if ic is Texture2D else (V8Art.icon(str(ic)) if ic != null else null)
	if tex:
		icon_rect = UI.tex(tex, Rect2(24, (H - ICON) * 0.5, ICON, ICON))
		add_child(icon_rect)
	var cnt_w: = 110.0
	var title: = V10MetaUI.text(str(opts.get("title", "")), V10MetaUI.FS_BODY, V10MetaUI.PAPER_100, "body", 800)
	title.position = Vector2(TX, 6)
	V10MetaUI.trim(title, Vector2(w - TX - cnt_w - 24, 32))
	add_child(title)
	# the counter «3/4★» in the right slot: Numerals 22, no box
	count_lbl = V10MetaUI.text(_count_text(_have() - _gain()), V10MetaUI.FS_BODY, V10MetaUI.GOLD_300, "body", 900)
	count_lbl.name = "Count"
	count_lbl.position = Vector2(w - cnt_w - 24, 6)
	count_lbl.size = Vector2(cnt_w, 32)
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(count_lbl)
	if str(opts.get("kind", "stars")) == "stars" and _need() <= 8:
		_build_pips()
	else:
		_build_fill()


func _count_text(have: int) -> String:
	var unit: = str(opts.get("unit", "★" if str(opts.get("kind", "stars")) == "stars" else ""))
	return "%d/%d%s" % [mini(have, _need()), _need(), unit]


func _build_pips() -> void:
	var n: = _need()
	var sz: = 26.0
	var gap: = 8.0
	var have0: = _have() - _gain()
	for i in n:
		var p: = TextureRect.new()
		p.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		p.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		p.texture = V8Art.star(i < have0)
		p.position = Vector2(TX + i * (sz + gap), 44)
		p.size = Vector2(sz, sz)
		p.pivot_offset = p.size * 0.5
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(p)
		pips.append(p)


func _build_fill() -> void:
	var fw: = w - TX - 24.0
	var sub: = str(opts.get("sub", ""))
	var sub_w: = 0.0
	if sub != "":
		var s: = V10MetaUI.text(sub, V10MetaUI.FS_CAPTION, V10MetaUI.PAPER_500, "body", 700)
		sub_w = minf(UI.font("body", 700).get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, V10MetaUI.FS_CAPTION).x + 4.0, fw * 0.45)
		s.position = Vector2(w - 24.0 - sub_w, 44)
		V10MetaUI.trim(s, Vector2(sub_w, 26))
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		add_child(s)
		fw -= sub_w + 16.0
	fill_bg = Panel.new()
	var sb: = StyleBoxFlat.new()
	sb.bg_color = V10MetaUI.NIGHT_600
	sb.set_corner_radius_all(4)
	fill_bg.add_theme_stylebox_override("panel", sb)
	fill_bg.position = Vector2(TX, 54)
	fill_bg.size = Vector2(fw, 8)
	fill_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fill_bg)
	var f0: = float(_have() - _gain()) / float(_need())
	fill = Panel.new()
	var fb: = StyleBoxFlat.new()
	fb.bg_color = _tone()
	fb.set_corner_radius_all(4)
	fill.add_theme_stylebox_override("panel", fb)
	fill.position = Vector2(TX, 54)
	fill.size = Vector2(maxf(8.0, fw * clampf(f0, 0.0, 1.0)), 8)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fill)


func _ready() -> void:
	V10MetaUI.refit(self)


func _gui_input(e: InputEvent) -> void:
	if not bool(opts.get("tap", false)):
		return
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed:
		V9Feel.press(self)
		pressed.emit()
		accept_event()


# the beat after the 0.9 stamps: stars fly in one by one, the line grows, the plaque jumps in
func play(delay: float = 0.0) -> void:
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	if not is_inside_tree():
		return
	var g: = _gain()
	var have0: = _have() - g
	if not pips.is_empty():
		for k in g:
			var i: = have0 + k
			if i >= pips.size():
				break
			await _fly_star(pips[i], k)
			if not is_inside_tree():
				return
			count_lbl.text = _count_text(i + 1)
	elif fill:
		var fw: = fill_bg.size.x
		var to: = maxf(8.0, fw * clampf(float(_have()) / _need(), 0.0, 1.0))
		var dur: = 0.4 if V9Feel.can_fx() else 0.12
		var t: = create_tween()
		t.tween_property(fill, "size:x", to, dur).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		var from: = have0
		t.parallel().tween_method(func(v: float): count_lbl.text = _count_text(int(round(v))), float(from), float(_have()), dur)
		if g > 0:
			V9Feel.sound("gem", 1.15, -6.0)
		await t.finished
	if not is_inside_tree():
		return
	if _have() >= _need() and str(opts.get("ready_text", "")) != "":
		_show_plaque()


func _fly_star(pip: TextureRect, k: int) -> void:
	if not V9Feel.can_fx():
		# fx_level=min: no flight — the star simply appears (120 ms)
		pip.texture = V8Art.star(true)
		pip.modulate.a = 0.0
		var ft: = create_tween()
		ft.tween_property(pip, "modulate:a", 1.0, 0.12)
		V9Feel.sound("sparkle", 1.0 + 0.08 * k, -3.0)
		await ft.finished
		return
	var s: = TextureRect.new()
	s.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	s.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	s.texture = V8Art.star(true)
	s.size = Vector2(40, 40)
	s.pivot_offset = s.size * 0.5
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var target: = pip.position + pip.size * 0.5 - s.size * 0.5
	s.position = Vector2(w * 0.5 - 20, -150)
	s.scale = Vector2(1.4, 1.4)
	s.rotation = -0.6
	add_child(s)
	var t: = create_tween().set_parallel()
	t.tween_property(s, "position", target, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(s, "scale", Vector2(0.65, 0.65), 0.32)
	t.tween_property(s, "rotation", 0.0, 0.32)
	await t.finished
	if not is_inside_tree():
		return
	s.queue_free()
	pip.texture = V8Art.star(true)
	UI.punch(pip, 0.35, 0.35)
	V9Feel.sound("sparkle", 1.0 + 0.08 * k, -3.0)
	V9Feel.haptic("select")
	Fx.burst(self, pip.position + pip.size * 0.5, "sparkle", int(10 * V9Feel.fx_scale()) + 2, V10MetaUI.GOLD_300, 0.7)
	await get_tree().create_timer(0.08).timeout


func _show_plaque() -> void:
	var txt: = str(opts.ready_text)
	var fs: = V10MetaUI.FS_CAPTION
	var tw: = UI.font("body", 900).get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 32.0
	var ph: = 30.0
	var base_y: = 42.0
	# the one gold accent of the window: gold.300 plate, night.900 text, radius 4
	var pl: = Panel.new()
	pl.name = "Plaque"
	var sb: = StyleBoxFlat.new()
	sb.bg_color = V10MetaUI.GOLD_300
	sb.set_corner_radius_all(V10MetaUI.RADIUS)
	pl.add_theme_stylebox_override("panel", sb)
	pl.position = Vector2(w - tw - 24, base_y)
	pl.size = Vector2(tw, ph)
	pl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l: = V10MetaUI.text(txt, fs, V10MetaUI.NIGHT_900, "body", 900)
	l.size = pl.size
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pl.add_child(l)
	add_child(pl)
	plaque = pl
	V9Feel.sound("sparkle", 1.2, 0.0)
	V9Feel.haptic("match")
	if not V9Feel.can_fx():
		pl.modulate.a = 0.0
		pl.create_tween().tween_property(pl, "modulate:a", 1.0, 0.12)
		return
	pl.pivot_offset = Vector2(tw * 0.5, ph * 0.5)
	pl.scale = Vector2(0.3, 0.3)
	pl.position.y = base_y - 14.0
	var t: = pl.create_tween()
	t.tween_property(pl, "scale", Vector2(1.08, 1.08), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(pl, "position:y", base_y, 0.18).set_trans(Tween.TRANS_QUAD)
	t.tween_property(pl, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	# «подпрыгивает»: two calm bobs, then it rests (no endless UI motion besides the primary button)
	for i in 2:
		t.tween_property(pl, "position:y", base_y - 3.0, 0.35).set_trans(Tween.TRANS_SINE)
		t.tween_property(pl, "position:y", base_y, 0.35).set_trans(Tween.TRANS_SINE)
