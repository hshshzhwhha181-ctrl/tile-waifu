class_name V10PullConfirm
extends Control

# V10PullConfirm — the confirmation sheet of a wish (UX_RULES §5.2.6–7, §5.3 «один шаблон на все покупки»).
# Asked always when Лунный камень would be spent, and for crystals from 1000 (with «Больше не спрашивать для
# кристаллов», stored in S.v10_gacha.no_ask_gems). Instead of a price it shows the split:
# «Спишется: 3 билета → 1 050 кристаллов → 150 Лунного камня · останется 0 кристаллов».
# With moonstone the confirm button is the «Касса» class (night.700, gold.500 line, «что получу» left, the spend
# right; never rose.500, V10GUI.kassa_button), without it the pink «Игра» class. «ⓘ Шансы» sits in the footer (С-5); it closes the
# sheet first, so the odds screen never opens over a sheet (П-6).
#   V10PullConfirm.needed(sp, S) -> bool
#   V10PullConfirm.open(parent, {title, banner_name, n, sp, gems_left}, on_yes, on_odds) -> V10PullConfirm

const ASK_GEMS: = 1000

var on_yes: Callable
var on_odds: Callable
var no_ask: = false
var box_tick: Label
var yes_btn: JButton
var W: = 720.0
var H: = 1280.0


static func needed(sp: Dictionary, S: Dictionary) -> bool:
	if int(sp.get("moon", 0)) > 0:
		return true
	return int(sp.get("gems", 0)) >= ASK_GEMS and not bool(V10Banners.state(S).get("no_ask_gems", false))


static func open(parent: Control, info: Dictionary, cb_yes: Callable, cb_odds: = Callable()) -> V10PullConfirm:
	var s: = V10PullConfirm.new()
	s.size = parent.get_viewport_rect().size
	s.on_yes = cb_yes
	s.on_odds = cb_odds
	parent.add_child(s)
	s._build(info)
	return s


func _build(info: Dictionary) -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	W = size.x
	H = size.y
	var sp: Dictionary = info.get("sp", {})
	var n: = int(info.get("n", 1))
	var moon: = int(sp.get("moon", 0)) > 0
	var dim: = ColorRect.new()
	dim.size = size
	dim.color = Color(V10GUI.NIGHT_900, 0.0)
	add_child(dim)
	dim.create_tween().tween_property(dim, "color:a", 0.7, 0.2)
	dim.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			close())
	var sh: = V10GUI.sheet(Rect2(0, H, W, 10), 0.98)
	sh.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(sh)
	var ol: = V10GUI.overline("желания · " + String(info.get("banner_name", "")), V10GUI.GOLD_500)
	ol.position = Vector2(32, 26)
	sh.add_child(ol)
	var t: = V10GUI.h1(String(info.get("title", "Загадать ×%d" % n)), 40)
	t.position = Vector2(30, 46)
	sh.add_child(t)
	var unit: = V10GachaBank.plural(n, "желание", "желания", "желаний")
	var got: = V10GUI.lbl("Ты получишь: %d %s — результат случайный" % [n, unit], 18, V10GUI.PAPER_300, "body", 700)
	got.position = Vector2(32, 106)
	sh.add_child(got)
	var line: = ColorRect.new()
	line.color = Color(V10GUI.GOLD_700, 0.35)
	line.position = Vector2(32, 146)
	line.size = Vector2(W - 64, 1)
	sh.add_child(line)
	var sl: = V10GUI.lbl(V10GachaBank.split_text(sp), 24, V10GUI.PAPER_100, "body", 900)
	sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sl.size = Vector2(W - 64, 10)
	sl.position = Vector2(32, 162)
	sh.add_child(sl)
	var y: = 162.0 + sl.get_minimum_size().y + 4
	var gl: = int(info.get("gems_left", sp.get("gems_left", 0)))
	var left: = V10GUI.lbl("Останется: %s %s" % [V10Rates.group(gl), V10GachaBank.plural(gl, "кристалл", "кристалла", "кристаллов")], 18, V10GUI.PAPER_500, "body", 700)
	left.position = Vector2(32, y)
	sh.add_child(left)
	y += 34
	if not moon:
		# «Больше не спрашивать для кристаллов» — the checkbox of §5.2.6 (moonstone is always asked)
		var row: = Control.new()
		row.position = Vector2(20, y)
		row.size = Vector2(W - 40, 80)
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		row.set_meta("ux_role", "secondary")
		var bx: = Panel.new()
		var sb: = StyleBoxFlat.new()
		sb.bg_color = Color(V10GUI.NIGHT_900, 0.6)
		sb.border_color = Color(V10GUI.GOLD_500, 0.8)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(4)
		bx.add_theme_stylebox_override("panel", sb)
		bx.position = Vector2(12, 24)
		bx.size = Vector2(32, 32)
		bx.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(bx)
		box_tick = V10GUI.lbl("✓", 26, V10GUI.GOLD_300, "body", 900)
		UI.center_label(box_tick, Rect2(0, -2, 32, 32))
		box_tick.visible = false
		bx.add_child(box_tick)
		var bl: = V10GUI.lbl("Больше не спрашивать для кристаллов", 24, V10GUI.PAPER_300, "body", 800)
		bl.position = Vector2(58, 40 - bl.get_minimum_size().y * 0.5)
		row.add_child(bl)
		row.gui_input.connect(func(e):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				no_ask = not no_ask
				box_tick.visible = no_ask
				V9Feel.press(bx, "tap", "button"))
		sh.add_child(row)
		y += 80
	var by: = y + 12
	var yes_t: = "Загадать ×%d" % n
	var yes: JButton
	if moon:
		yes = V10GUI.kassa_button(yes_t, "%s Лунного камня" % V10Rates.group(int(sp.moon)), Rect2(24, by, W - 48, 104))
	else:
		yes = JButton.make(yes_t, "pink", Rect2(24, by, 440, 104), null, 28)
	yes.pressed.connect(_yes)
	yes_btn = yes
	yes.set_meta("ux_role", "primary")
	sh.add_child(yes)
	y = by + 104 + 8
	var nb: JButton
	if moon:
		nb = JButton.make("Отмена", "glass", Rect2(24, y, 220, 80), null, 24)
	else:
		nb = JButton.make("Отмена", "glass", Rect2(480, by, W - 504, 104), null, 24)
	nb.set_meta("ux_role", "secondary")
	nb.sound = "tap"
	nb.pressed.connect(close)
	sh.add_child(nb)
	var to_odds: = func():
		var cb: = on_odds
		close()
		if cb.is_valid():
			cb.call()
	var odds: = V10GUI.link("ⓘ Шансы", Vector2(W - 172, y), to_odds, V10GUI.GOLD_500, 18)
	sh.add_child(odds)
	var h: = y + 80 + 12
	sh.size = Vector2(W, h + 8)
	sh.position.y = H - h + 40
	sh.create_tween().tween_property(sh, "position:y", H - h, 0.22).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)


func _yes() -> void:
	if no_ask:
		V10Banners.state(G.S)["no_ask_gems"] = true
	var cb: = on_yes
	close()
	if cb.is_valid():
		cb.call()


func close() -> void:
	if mouse_filter == Control.MOUSE_FILTER_IGNORE:
		return
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in find_children("*", "Control", true, false):
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t: = create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.18)
	t.tween_callback(queue_free)
