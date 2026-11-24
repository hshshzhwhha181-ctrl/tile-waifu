class_name V10SparkSheet
extends Control

# V10SparkSheet — «Зажечь Свечу желаний» (spec Г5): a bottom sheet over the Wishes page. A grid of every SSR the
# Candle may give (constant pool + the current phase), the chosen one lifts in gold; an owned one shows «✦2 → ✦3».
# «Зажечь за 200 свечей» (primary) → «Выбор окончательный» → on_pick(id) (the screen plays the 0.9 showcase).

var gacha: V10Gacha2
var on_pick: Callable
var pick: = ""
var sheet: Control
var go_btn: JButton
var cards: = {}
var confirm_step: = false


static func open(parent: Control, g: V10Gacha2, cb: Callable) -> V10SparkSheet:
	var s: = V10SparkSheet.new()
	s.size = parent.get_viewport_rect().size
	s.gacha = g
	s.on_pick = cb
	parent.add_child(s)
	s._build()
	return s


func _build() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var W: = size.x
	var H: = size.y
	var dim: = ColorRect.new()
	dim.size = size
	dim.color = Color(0.03, 0.02, 0.04, 0.0)
	add_child(dim)
	dim.create_tween().tween_property(dim, "color:a", 0.7, 0.22)
	dim.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			close())
	var opts: = gacha.spark_options()
	var cols: = 3
	var cw: = (W - 48 - 2 * 16) / cols
	var ch: = cw * 1.42
	var rows: = int(ceil(opts.size() / float(cols)))
	var grid_h: = minf(rows * (ch + 46), H * 0.56)
	var sh_h: = 150 + grid_h + 150
	sheet = V10GUI.sheet(Rect2(0, H - sh_h, W, sh_h + 8), 0.98)
	sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(sheet)
	var ol: = V10GUI.overline("свеча желаний · 200 свечей", V10GUI.GOLD_500)
	ol.position = Vector2(32, 26)
	sheet.add_child(ol)
	var t: = V10GUI.h1("Кого позвать?", 40)
	t.position = Vector2(30, 48)
	sheet.add_child(t)
	var sub: = V10GUI.lbl("Любая SSR постоянных желаний или текущей фазы. Если она уже у тебя — звезда Созвездия ✦.", 18, V10GUI.PAPER_300, "body", 700)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.size = Vector2(W - 64, 10)
	sub.position = Vector2(32, 104)
	sheet.add_child(sub)
	var sc: = ScrollContainer.new()
	sc.position = Vector2(0, 150)
	sc.size = Vector2(W, grid_h)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sheet.add_child(sc)
	var list: = Control.new()
	list.custom_minimum_size = Vector2(W, rows * (ch + 46) + 10)
	sc.add_child(list)
	for i in opts.size():
		var it: Dictionary = opts[i]
		var x: = 24 + (i % cols) * (cw + 16)
		var y: = 8 + (i / cols) * (ch + 46)
		var c: = _card(it, Rect2(x, y, cw, ch))
		list.add_child(c)
		cards[String(it.id)] = c
	go_btn = JButton.make("Выбери наряд", "graphite", Rect2(24, sh_h - 132, W - 48, 104), null, 30)
	go_btn.set_meta("ux_role", "primary")
	go_btn.disabled = true
	go_btn.pressed.connect(_go)
	sheet.add_child(go_btn)
	sheet.position.y += 60
	sheet.modulate.a = 0.0
	var st: = sheet.create_tween().set_parallel()
	st.tween_property(sheet, "position:y", H - sh_h, 0.24).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	st.tween_property(sheet, "modulate:a", 1.0, 0.2)


func _card(it: Dictionary, r: Rect2) -> Control:
	var c: = Control.new()
	c.position = r.position
	c.size = Vector2(r.size.x, r.size.y + 40)
	c.pivot_offset = r.size * 0.5
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	var art: = Common.card_art(G.art_tex(it), Rect2(Vector2.ZERO, r.size), Vector2(0.5, 0.28), 1.0, 8.0)
	(art.material as ShaderMaterial).set_shader_parameter("bottom_shade", 0.5)
	c.add_child(art)
	var ring: = Panel.new()
	ring.name = "Ring"
	ring.size = r.size
	var sb: = StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = Color(V10GUI.GOLD_700, 0.5)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	ring.add_theme_stylebox_override("panel", sb)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(ring)
	var lv: = V10Stars.level(G.S, String(it.id))
	if lv > 0:
		var p: = V10GUI.chip("✦%d → ✦%d" % [lv, mini(5, lv + 1)] if lv < 5 else "✦5 · +60 ❀", null, 30, V10GUI.LAV)
		p.position = Vector2(6, 6)
		c.add_child(p)
	var nm: = V10GUI.lbl(String(it.name), 17, V10GUI.PAPER_100, "body", 800)
	nm.position = Vector2(0, r.size.y + 6)
	nm.size = Vector2(r.size.x, 10)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	c.add_child(nm)
	var id: = String(it.id)
	c.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			_select(id))
	return c


func _select(id: String) -> void:
	pick = id
	confirm_step = false
	for k in cards:
		var c: Control = cards[k]
		var on: bool = k == id
		var ring: Panel = c.get_node("Ring")
		var sb: StyleBoxFlat = ring.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		sb.border_color = V10GUI.GOLD_300 if on else Color(V10GUI.GOLD_700, 0.5)
		sb.set_border_width_all(3 if on else 1)
		ring.add_theme_stylebox_override("panel", sb)
		c.create_tween().tween_property(c, "modulate", Color.WHITE if on else Color(0.62, 0.6, 0.66), 0.16)
	V9Feel.press(cards[id], "select", "button")
	go_btn.disabled = false
	go_btn.set_pal("pink")
	if go_btn.lbl:
		go_btn.lbl.text = "Зажечь за 200 свечей"


func _go() -> void:
	if pick == "":
		return
	if not confirm_step:
		# «Выбор окончательный»: the same button asks once more (no window over the sheet, UX_RULES §3.7)
		confirm_step = true
		if go_btn.lbl:
			go_btn.lbl.text = "Точно её? Выбор окончательный"
		V9Feel.press(go_btn, "select", "button")
		return
	var id: = pick
	var cb: = on_pick
	close()
	cb.call(id)


func close() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t: = create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.18)
	t.tween_callback(queue_free)
