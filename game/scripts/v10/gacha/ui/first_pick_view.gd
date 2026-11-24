class_name V10FirstPickView
extends Control

# V10FirstPickView — «Первая SSR на выбор» (spec Г3, UX_RULES §3.4 «Первая SSR»: Выбрать её · Примерить стиль).
# A dark lacquer table, three ivory tiles lie face down in candle light. They wake one after another and
# from each rises an SSR outfit card (o_dragon, y_queen, n_ssr) that keeps breathing like a living portrait.
# Tap a card → it comes forward: her name, her Приём, «Примерить стиль», «Выбрать её». «Выбрать её» asks once more
# on the same button («Выбор окончательный») → the hanko «ТВОЯ» → on_done(result) (the screen plays the 0.9 SSR
# showcase) → «Сделать партнёром?». No purchase offer in this session and for 24 h (V10Gacha2.offer_quiet).

var gacha: V10Gacha2
var on_done: Callable
var W: = 720.0
var H: = 1280.0
var cards: = []
var opts: = []
var focus_i: = -1
var detail: Control
var pick_btn: JButton
var confirm: = false
var title_l: Label
var sub_l: Label
var tiles: = []
var bg: Control
# the three face-down tiles painted in first_pick_table.webp (uv of their centres in the art)
const TILE_UV: = [Vector2(0.233, 0.48), Vector2(0.502, 0.48), Vector2(0.767, 0.48)]


static func open(parent: Control, g: V10Gacha2, cb: Callable) -> V10FirstPickView:
	var v: = V10FirstPickView.new()
	v.size = parent.get_viewport_rect().size
	v.gacha = g
	v.on_done = cb
	parent.add_child(v)
	v._build()
	return v


func _build() -> void:
	W = size.x
	H = size.y
	mouse_filter = Control.MOUSE_FILTER_STOP
	var base: = ColorRect.new()
	base.size = size
	base.color = V10GUI.NIGHT_900
	add_child(base)
	bg = V10GUI.cover(V10GUI.tex_or_null("res://assets/v10/gacha/first_pick_table.webp"), Rect2(Vector2.ZERO, size), Vector2(0.5, 0.62))
	bg.modulate.a = 0.0
	add_child(bg)
	bg.create_tween().tween_property(bg, "modulate:a", 1.0, 0.9).set_trans(Tween.TRANS_SINE)
	add_child(V10GUI.shade(Rect2(0, 0, W, 420), Color(V10GUI.NIGHT_900, 0.92), Color(V10GUI.NIGHT_900, 0.0), true))
	add_child(V10GUI.shade(Rect2(0, H - 360, W, 360), Color(V10GUI.NIGHT_900, 0.0), Color(V10GUI.NIGHT_900, 0.95), true))
	Fx.ambient(self, "stars", Vector2(W, H * 0.4))
	title_l = V10GUI.h1("Кто будет хозяйкой\nтвоего стола?", 44)
	title_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI.center_label(title_l, Rect2(0, 92, W, 120))
	title_l.modulate.a = 0.0
	add_child(title_l)
	sub_l = V10GUI.lbl("Выбор бесплатный. Остальные будут ждать тебя в Желаниях.", 20, V10GUI.PAPER_300, "body", 700)
	UI.center_label(sub_l, Rect2(40, 214, W - 80, 30))
	sub_l.modulate.a = 0.0
	add_child(sub_l)
	opts = gacha.first_options()
	var tt: = create_tween()
	tt.tween_interval(0.5)
	tt.tween_property(title_l, "modulate:a", 1.0, 0.6)
	tt.tween_property(sub_l, "modulate:a", 1.0, 0.4)
	Sfx.play("summon_charge", 0.7, -12.0)
	_tiles_and_cards()


func _slot(i: int, n: int) -> Rect2:
	var cw: = minf(208.0, (W - 64 - (n - 1) * 16) / n)
	var ch: = cw * 1.5
	var x0: = (W - (n * cw + (n - 1) * 16)) * 0.5
	return Rect2(x0 + i * (cw + 16), 262.0 + maxf(0.0, H - 1280.0) * 0.3, cw, ch)


func _tile_pos(i: int) -> Vector2:
	var img: Control = bg.get_node_or_null("Img")
	var uv: Vector2 = TILE_UV[clampi(i, 0, 2)]
	if img == null:
		return Vector2(W * uv.x, H * 0.62)
	return bg.position + img.position + uv * img.size


func _tiles_and_cards() -> void:
	var n: = opts.size()
	for i in n:
		var r: = _slot(i, n)
		# the painted tile wakes up: a warm pool of light swells on it, a clack, a haptic tick
		var tp: = _tile_pos(i if n == 3 else i + 1)
		var tile: = Sprite2D.new()
		tile.texture = G.fx("glow")
		tile.material = Fx.add_mat()
		tile.position = tp
		tile.scale = Vector2(r.size.x / 52.0, r.size.x / 80.0)
		tile.modulate = Color(1.0, 0.82, 0.5, 0.0)
		add_child(tile)
		tiles.append(tile)
		var d: = 0.9 + i * 0.35
		var t: = tile.create_tween()
		t.tween_interval(d)
		t.tween_property(tile, "modulate:a", 0.9, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_callback(func():
			Sfx.play("clack%d" % (i % 3), 0.9 + i * 0.05, -4.0)
			V9Feel.haptic("tap"))
		t.tween_property(tile, "modulate:a", 0.45, 0.6)
		var card: = _card(opts[i], r)
		card.modulate.a = 0.0
		card.position.y = tp.y - r.size.y * 0.5
		card.scale = Vector2(0.4, 0.4)
		var ct: = card.create_tween()
		ct.tween_interval(d + 0.55)
		ct.tween_callback(func():
			Sfx.play("reveal_ssr", 0.9 + i * 0.06, -10.0)
			if V9Feel.can_fx():
				Fx.burst(self, tp, "sparkle", 26, V9Summon.COL.SSR, 1.1))
		ct.tween_property(card, "modulate:a", 1.0, 0.3)
		ct.parallel().tween_property(card, "position:y", r.position.y, 0.7).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		ct.parallel().tween_property(card, "scale", Vector2.ONE, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		ct.tween_callback(func(): _breathe(card, i))
		cards.append(card)


# a living portrait: a slow breath and a sway, out of phase between the three
func _breathe(c: Control, i: int) -> void:
	if not V9Feel.can_fx() or not is_instance_valid(c):
		return
	var t: = c.create_tween().set_loops()
	t.tween_interval(i * 0.4)
	t.tween_property(c, "scale", Vector2(1.018, 1.018), 1.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.parallel().tween_property(c, "rotation", deg_to_rad(0.6 * (1 if i % 2 == 0 else -1)), 1.7).set_trans(Tween.TRANS_SINE)
	t.tween_property(c, "scale", Vector2.ONE, 1.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.parallel().tween_property(c, "rotation", 0.0, 1.7).set_trans(Tween.TRANS_SINE)


func _card(it: Dictionary, r: Rect2) -> Control:
	var c: = Control.new()
	c.position = r.position
	c.size = r.size
	c.pivot_offset = r.size * 0.5
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(c)
	var glow: = Sprite2D.new()
	glow.texture = G.fx("glow")
	glow.material = Fx.add_mat()
	glow.position = r.size * 0.5
	glow.scale = Vector2(r.size.x / 50.0, r.size.y / 56.0)
	glow.modulate = Color(V9Summon.COL.SSR, 0.45)
	c.add_child(glow)
	var art: = Common.card_art(G.art_tex(it), Rect2(Vector2.ZERO, r.size), Vector2(0.5, 0.3), 1.0, Common.card_radius("SSR", r.size))
	(art.material as ShaderMaterial).set_shader_parameter("holo", 0.35)
	(art.material as ShaderMaterial).set_shader_parameter("bottom_shade", 0.7)
	c.add_child(art)
	Common.card_frame(c, "SSR", Rect2(Vector2.ZERO, r.size))
	var nm: = V10GUI.lbl(String(G.HEROES[it.hero].name), 20, V10GUI.PAPER_100, "body", 900, Color(0.1, 0.05, 0.1, 0.9), 4)
	nm.position = Vector2(0, r.size.y - 52)
	nm.size = Vector2(r.size.x, 10)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(nm)
	var idx: = cards.size()
	c.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and focus_i < 0:
			_focus(idx))
	return c


func _focus(i: int) -> void:
	focus_i = i
	confirm = false
	var c: Control = cards[i]
	V9Feel.press(c, "select", "button")
	Sfx.play("whoosh", 1.1, -6.0)
	for k in cards.size():
		var o: Control = cards[k]
		if k != i:
			o.create_tween().tween_property(o, "modulate:a", 0.0, 0.2)
			o.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for t in tiles:
		t.create_tween().tween_property(t, "modulate:a", 0.25, 0.3)
	title_l.create_tween().tween_property(title_l, "modulate:a", 0.0, 0.2)
	sub_l.create_tween().tween_property(sub_l, "modulate:a", 0.0, 0.2)
	c.set_meta("home", c.position)
	var k2: = minf(1.9, (H * 0.5) / c.size.y)
	var target: = Vector2(W * 0.5, H * 0.36) - c.size * 0.5
	var t: = c.create_tween().set_parallel()
	t.tween_property(c, "position", target, 0.42).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	t.tween_property(c, "scale", Vector2(k2, k2), 0.42).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	if V9Feel.can_fx():
		var ry: = Common.rays(self, Vector2(W * 0.5, H * 0.36), H * 0.9, Color(1, 0.84, 0.45, 0.4), 12, 0.04, 0.6)
		move_child(ry, c.get_index())
		ry.modulate.a = 0.0
		ry.create_tween().tween_property(ry, "modulate:a", 1.0, 0.4)
		ry.set_meta("fp_rays", true)
	_detail(opts[i])


func _detail(it: Dictionary) -> void:
	if is_instance_valid(detail):
		detail.queue_free()
	detail = Control.new()
	detail.size = size
	detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(detail)
	var y: = H * 0.36 + H * 0.25 + 24
	var ol: = V10GUI.overline("SSR · " + String(G.HEROES[it.hero].title), V10GUI.GOLD_500)
	UI.center_label(ol, Rect2(0, y, W, 24))
	detail.add_child(ol)
	var t: = V10GUI.h1(String(it.name), 40)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI.center_label(t, Rect2(0, y + 24, W, 56))
	detail.add_child(t)
	var ult: = ""
	if V9Ults.has(String(it.id)):
		ult = String(V9Ults.get_ult(String(it.id)).get("name", ""))
	var ul: = V10GUI.lbl("Приём «%s» — особый ход героини" % ult if ult != "" else "", 20, V10GUI.PAPER_300, "body", 700)
	UI.center_label(ul, Rect2(0, y + 84, W, 30))
	detail.add_child(ul)
	var by: = H - 150.0
	pick_btn = JButton.make("Выбрать её", "pink", Rect2(24, by, W - 48, 104), null, 32)
	pick_btn.set_meta("ux_role", "primary")
	pick_btn.pulse = true
	pick_btn.pressed.connect(_choose)
	detail.add_child(pick_btn)
	var tryb: = JButton.make("Примерить стиль", "glass", Rect2(W * 0.5 + 6, by - 92, W * 0.5 - 30, 80), null, 22)
	tryb.set_meta("ux_role", "secondary")
	tryb.pressed.connect(func(): _try_style(it))
	detail.add_child(tryb)
	var back: = JButton.make("‹ Ко всем трём", "glass", Rect2(24, by - 92, W * 0.5 - 30, 80), null, 22)
	back.set_meta("ux_role", "secondary")
	back.sound = "tap"
	back.pressed.connect(_unfocus)
	detail.add_child(back)
	for n in [ol, t, ul, back, tryb, pick_btn]:
		UI.slide_in(n, Vector2(0, 16), 0.04 * [ol, t, ul, back, tryb, pick_btn].find(n), 0.24)


# style preview: until the kits land (M5) the tile theme of the outfit flashes over the table, nothing is given
func _try_style(it: Dictionary) -> void:
	var c: Control = cards[focus_i]
	V9Feel.press(c, "select", "button")
	var tint: = Color(G.HEROES[it.hero].color)
	# the table takes her colours: the three tiles glow in her accent, petals of her colour rise from them
	for tile in tiles:
		var tl: Sprite2D = tile
		tl.create_tween().tween_property(tl, "modulate", Color(tint.r, tint.g, tint.b, 1.0), 0.3)
		Fx.burst(self, tl.position, "petal", 8, tint.lerp(Color.WHITE, 0.4), 0.8)
	Sfx.play("sparkle", 1.2, -6.0)


func _unfocus() -> void:
	if focus_i < 0:
		return
	var c: Control = cards[focus_i]
	var t: = c.create_tween().set_parallel()
	t.tween_property(c, "position", c.get_meta("home"), 0.3).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	t.tween_property(c, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	for k in cards.size():
		var o: Control = cards[k]
		o.mouse_filter = Control.MOUSE_FILTER_STOP
		o.create_tween().tween_property(o, "modulate:a", 1.0, 0.25)
	for tl in tiles:
		tl.create_tween().tween_property(tl, "modulate:a", 0.45, 0.25)
	title_l.create_tween().tween_property(title_l, "modulate:a", 1.0, 0.25)
	sub_l.create_tween().tween_property(sub_l, "modulate:a", 1.0, 0.25)
	for n in get_children():
		if n.has_meta("fp_rays"):
			n.queue_free()
	if is_instance_valid(detail):
		detail.queue_free()
	focus_i = -1


func _choose() -> void:
	if focus_i < 0:
		return
	if not confirm:
		confirm = true
		pick_btn.lbl.text = "Выбор окончательный — её?"
		V9Feel.press(pick_btn, "select", "button")
		return
	var it: Dictionary = opts[focus_i]
	var r: = gacha.choose_first(String(it.id))
	if r.is_empty():
		return
	V9Feel.big(pick_btn)
	V10GUI.hanko(self, Vector2(W * 0.5 + 150, H * 0.36 + 200), "ТВОЯ", 140, -8.0)
	var cb: = on_done
	var t: = create_tween()
	t.tween_interval(0.9)
	t.tween_property(self, "modulate:a", 0.0, 0.3)
	t.tween_callback(func():
		cb.call(r)
		queue_free())
