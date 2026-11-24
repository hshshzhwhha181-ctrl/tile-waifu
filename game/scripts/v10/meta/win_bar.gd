class_name V10WinBar
extends Control

# V10WinBar — one progress bar of the victory stack (V10WinStack). Shared look for the salon (M2), mastery and pass
# (M4) bars so the window stays harmonious: glass row, round icon, title, a counter pill with a sheen, and either
# star pips (kind "stars", need ≤ 8) or a gold fill (kind "fill").
#
#   V10WinBar.make(width, opts) -> V10WinBar
#     opts: icon (Texture2D or V8Art icon name), title, have, need, gain (how many of `have` are new this win),
#           kind "stars" | "fill", unit ("★" default for stars, "" for fill), ready_text («Можно восстановить!»
#           shown when have ≥ need), pal ("gold" | "pink" | "lav" accent), sub (small right caption for fill bars)
#   bar.play(delay) — the new stars fly in one by one after the 0.9 stamps (sparkle with a rising pitch, a light
#                     haptic each), the fill grows; when full, the gold plaque jumps in (sparkle pitch 1.2)
#   signal pressed — the row is tappable (V9Feel.press): the owner opens the salon / mastery / pass
# Respects S.fx_level through V9Feel (particles only on full/mid; presses and sounds always).

signal pressed

const H: = 84.0
const ACCENT: = {"gold": [Color("ffe7a6"), Color("e8b04a")], "pink": [Color("ffd0dc"), Color("e3819b")],
	"lav": [Color("e6e0ff"), Color("a98cf0")], "jade": [Color("c9f5df"), Color("5fc79a")]}

var opts: Dictionary
var w: = 0.0
var pips: Array = []
var fill: RBox
var fill_bg: RBox
var count_lbl: Label
var count_box: RBox
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


func _acc() -> Array:
	return ACCENT.get(str(opts.get("pal", "gold")), ACCENT.gold)


func _build() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg: = UI.rbox("glass", Rect2(0, 0, w, H), 22, 3, 8)
	bg.borders(Color(1, 0.91, 0.7, 0.55), Color(0.55, 0.36, 0.14, 0.6))
	add_child(bg)
	# round icon in a gold ring
	var ring: = UI.rbox("gold", Rect2(10, 10, 64, 64), 32, 3, 6)
	ring.colors(Color("4a2a32"), Color("26131a"))
	ring.borders(_acc()[0], _acc()[1])
	add_child(ring)
	var ic = opts.get("icon", null)
	var tex: Texture2D = ic if ic is Texture2D else (V8Art.icon(str(ic)) if ic != null else null)
	if tex:
		icon_rect = UI.tex(tex, Rect2(16, 16, 52, 52))
		add_child(icon_rect)
	var tx: = 88.0
	var cnt_w: = 96.0
	var title: = UI.label(str(opts.get("title", "")), 21, UI.INK, UI.DARK, 3, "body", 900)
	title.position = Vector2(tx, 8)
	V10MetaUI.trim(title, Vector2(w - tx - cnt_w - 18, 30))
	add_child(title)
	# counter pill «3/4★» with a sheen
	count_box = UI.rbox("glass", Rect2(w - cnt_w - 12, 8, cnt_w, 30), 15, 2, 4)
	count_box.colors(Color(0.25, 0.16, 0.12, 0.95), Color(0.13, 0.08, 0.07, 0.95))
	count_box.borders(_acc()[0], _acc()[1])
	add_child(count_box)
	count_lbl = UI.center_label(UI.label(_count_text(_have() - _gain()), 19, _acc()[0], UI.DARK, 3, "body", 900),
		Rect2(0, 0, cnt_w, 30))
	count_box.add_child(count_lbl)
	if str(opts.get("kind", "stars")) == "stars" and _need() <= 8:
		_build_pips(tx)
	else:
		_build_fill(tx)


func _count_text(have: int) -> String:
	var unit: = str(opts.get("unit", "★" if str(opts.get("kind", "stars")) == "stars" else ""))
	return "%d/%d%s" % [mini(have, _need()), _need(), unit]


func _build_pips(tx: float) -> void:
	var n: = _need()
	var sz: = 30.0
	var gap: = 8.0
	var have0: = _have() - _gain()
	for i in n:
		var p: = TextureRect.new()
		p.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		p.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		p.texture = V8Art.star(i < have0)
		p.position = Vector2(tx + i * (sz + gap), 44)
		p.size = Vector2(sz, sz)
		p.pivot_offset = p.size * 0.5
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(p)
		pips.append(p)


func _build_fill(tx: float) -> void:
	var fw: = w - tx - 16.0
	fill_bg = UI.rbox("glass", Rect2(tx, 48, fw, 20), 10, 2, 4)
	fill_bg.colors(Color(0.1, 0.07, 0.08, 0.95), Color(0.06, 0.04, 0.05, 0.95))
	fill_bg.borders(Color(1, 1, 1, 0.12), Color(0, 0, 0, 0.3))
	add_child(fill_bg)
	var f0: = float(_have() - _gain()) / float(_need())
	fill = UI.rbox("gold", Rect2(tx + 2, 50, maxf(16.0, (fw - 4) * clampf(f0, 0.0, 1.0)), 16), 8, 1, 3)
	fill.colors(_acc()[0], _acc()[1])
	add_child(fill)
	if opts.has("sub"):
		var s: = UI.label(str(opts.sub), 15, UI.MUTED, UI.DARK, 2, "body", 800)
		s.position = Vector2(tx, 28)
		s.size = Vector2(fw, 20)
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		s.visible = false
		add_child(s)


func _ready() -> void:
	V10MetaUI.refit(self)


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed:
		V9Feel.press(self)
		pressed.emit()
		accept_event()


# the beat after the 0.9 stamps: stars fly in one by one, the fill grows, the plaque jumps in
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
			UI.punch(count_box, 0.12, 0.3)
	elif fill:
		var fw: = fill_bg.size.x - 4.0
		var t: = create_tween()
		t.tween_property(fill, "size:x", maxf(16.0, fw * clampf(float(_have()) / _need(), 0.0, 1.0)), 0.6)\
			.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		var from: = have0
		t.parallel().tween_method(func(v: float): count_lbl.text = _count_text(int(round(v))), float(from), float(_have()), 0.6)
		if g > 0:
			V9Feel.sound("gem", 1.15, -6.0)
		await t.finished
	if not is_inside_tree():
		return
	count_box.shine(0.0, 0.8)
	if _have() >= _need() and str(opts.get("ready_text", "")) != "":
		_show_plaque()


func _fly_star(pip: TextureRect, k: int) -> void:
	var s: = TextureRect.new()
	s.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	s.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	s.texture = V8Art.star(true)
	s.size = Vector2(44, 44)
	s.pivot_offset = s.size * 0.5
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var target: = pip.position + pip.size * 0.5 - s.size * 0.5
	s.position = Vector2(w * 0.5 - 22, -150)
	s.scale = Vector2(1.4, 1.4)
	s.rotation = -0.6
	add_child(s)
	var t: = create_tween().set_parallel()
	t.tween_property(s, "position", target, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(s, "scale", Vector2(0.7, 0.7), 0.32)
	t.tween_property(s, "rotation", 0.0, 0.32)
	await t.finished
	if not is_inside_tree():
		return
	s.queue_free()
	pip.texture = V8Art.star(true)
	UI.punch(pip, 0.35, 0.35)
	V9Feel.sound("sparkle", 1.0 + 0.08 * k, -3.0)
	V9Feel.haptic("select")
	if V9Feel.can_fx():
		Fx.burst(self, pip.position + pip.size * 0.5, "sparkle", int(10 * V9Feel.fx_scale()) + 2, Color(1, 0.88, 0.5), 0.7)
	await get_tree().create_timer(0.08).timeout


func _show_plaque() -> void:
	var txt: = str(opts.ready_text)
	var fs: = 18
	var tw: = UI.font("body", 900).get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 36.0
	var base_y: = 43.0
	plaque = UI.rbox("gold", Rect2(w - tw - 12, base_y - 18.0, tw, 34), 17, 3, 6)
	plaque.colors(Color("ffe9a8"), Color("e0a53c"))
	plaque.borders(Color("fff6d6"), Color("9a6418"))
	plaque.add_child(UI.center_label(UI.label(txt, fs, Color("3a2410"), Color(1, 0.97, 0.85, 0.6), 1, "body", 900),
		Rect2(0, 0, tw, 34)))
	add_child(plaque)
	plaque.pivot_offset = Vector2(tw * 0.5, 17)
	plaque.scale = Vector2(0.3, 0.3)
	var t: = plaque.create_tween()
	t.tween_property(plaque, "scale", Vector2(1.12, 1.12), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(plaque, "position:y", base_y, 0.18).set_trans(Tween.TRANS_QUAD)
	t.tween_property(plaque, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	t.tween_callback(func(): (plaque as RBox).shine(0.0, 0.9))
	# a calm bob: «you can restore now» keeps inviting without blinking
	t.tween_callback(func():
		var bob: = plaque.create_tween().set_loops()
		bob.tween_interval(0.6)
		bob.tween_property(plaque, "position:y", base_y - 3.0, 0.7).set_trans(Tween.TRANS_SINE)
		bob.tween_property(plaque, "position:y", base_y, 0.7).set_trans(Tween.TRANS_SINE))
	V9Feel.sound("sparkle", 1.2, 0.0)
	V9Feel.haptic("match")
