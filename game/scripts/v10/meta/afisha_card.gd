class_name V10AfishaCard
extends Control

# V10AfishaCard — «Сегодня в чайной», the lacquer board on the home screen's right slot (compact, 198 px wide) and
# at the top of «Режимы» (wide). Rows come from V10Afisha.rows(); a played row dims and gets the red «Сыграно»
# stamp (Playfair, low-pitched pop). Every row presses through V9Feel; a closed row denies and says why.
#
#   var c: = V10AfishaCard.make(Vector2(w, h_max))   compact layout when w < 360
#   c.refresh()                                       rebuild rows (call on V10Meta.bus().day_rolled, after a game)
#   c.stamp(kind)                                     marks a row as played with the stamp animation
#   c.preferred_height() -> float
#   signals: row_pressed(id: String, tab: String) · locked(id: String, text: String)
#   (tab = "Раскладка" / "Чтение руки" for the daily row, "" otherwise)

signal row_pressed(id: String, tab: String)
signal locked(id: String, text: String)

const LACQ_TOP: = Color("4a141e")
const LACQ_BOT: = Color("1e080d")
const GOLD_HI: = Color("ffe7a6")
const GOLD_LO: = Color("b9802a")
const INK_RED: = Color("d8343f")

var box_size: Vector2
var compact: = false
var rows_root: Control
var row_nodes: = {}
var _rows: Array = []
var header_h: = 0.0
var row_h: = 0.0


static func make(sz: Vector2) -> V10AfishaCard:
	var c: = V10AfishaCard.new()
	c.box_size = sz
	c.compact = sz.x < 360.0
	c.size = sz
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c._build()
	return c


func preferred_height() -> float:
	return header_h + _rows.size() * (row_h + 8.0) + (10.0 if compact else 16.0)


func _build() -> void:
	for ch in get_children():
		ch.queue_free()
	row_nodes.clear()
	_rows = V10Afisha.rows()
	header_h = 74.0 if compact else 92.0
	row_h = 56.0 if compact else 78.0
	size = Vector2(box_size.x, minf(box_size.y, preferred_height())) if box_size.y > 0.0 else Vector2(box_size.x, preferred_height())
	# the lacquer board: deep red-black lacquer, gold rim, a soft inner glow at the top
	var board: = UI.rbox("plum", Rect2(Vector2.ZERO, size), 24.0 if compact else 30.0, 4, 12)
	board.colors(LACQ_TOP, LACQ_BOT)
	board.borders(GOLD_HI, GOLD_LO)
	board.set_param("gloss", 0.12)
	add_child(board)
	# two cords and the hanging pin: the card reads as a board hung on the tea-house wall
	if not compact:
		for x in [size.x * 0.22, size.x * 0.78]:
			var pin: = UI.rbox("gold", Rect2(x - 7, -7, 14, 14), 7, 2, 2)
			add_child(pin)
	var title_fs: = 22 if compact else 32
	var title: = UI.label("Сегодня в чайной", title_fs, GOLD_HI, Color("2a0a10"), 4, "title", 800)
	title.position = Vector2(0, 8 if compact else 12)
	title.size = Vector2(size.x, title_fs + 12)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if compact:
		Common.fit_line(title, size.x - 20, 16)
	add_child(title)
	var sub_txt: = _date_text() if compact else "%s · %s" % [_date_text(), V10Afisha.T_REFRESH]
	var sub: = UI.label(sub_txt, 13 if compact else 16, Color(1, 0.88, 0.78, 0.7), UI.DARK, 2, "body", 800)
	sub.position = Vector2(8, (8 if compact else 12) + title_fs + 10)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	V10MetaUI.trim(sub, Vector2(size.x - 16, 20))
	add_child(sub)
	# thin gold rule with a dot in the middle
	var rule_y: = header_h - 8.0
	for seg in [[16.0, size.x * 0.5 - 12.0], [size.x * 0.5 + 12.0, size.x - 16.0]]:
		var ln: = ColorRect.new()
		ln.color = Color(GOLD_HI, 0.45)
		ln.position = Vector2(seg[0], rule_y)
		ln.size = Vector2(seg[1] - seg[0], 2)
		ln.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(ln)
	var dot: = UI.rbox("gold", Rect2(size.x * 0.5 - 5, rule_y - 4, 10, 10), 5, 1, 2)
	add_child(dot)
	rows_root = Control.new()
	rows_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows_root.position = Vector2(0, header_h)
	rows_root.size = Vector2(size.x, size.y - header_h)
	add_child(rows_root)
	var y: = 0.0
	for r in _rows:
		var rn: = _row(r, Rect2(10 if compact else 16, y, size.x - (20 if compact else 32), row_h))
		rows_root.add_child(rn)
		row_nodes[r.id] = rn
		if bool(r.done):
			_stamp_on(rn, false)
		y += row_h + 8.0


func _date_text() -> String:
	var key: = V10Meta.day_key()
	var d: = Time.get_datetime_dict_from_unix_time(V10Meta.day_index(key) * 86400)
	return "%s, %d %s" % [V10Meta.WD_SHORT[int(d.weekday)], int(d.day), V10Meta.MONTHS_GEN[int(d.month) - 1]]


func _row(r: Dictionary, rect: Rect2) -> Control:
	var open: = bool(r.open)
	var row: = UI.rbox("glass", rect, 16.0 if compact else 20.0, 2, 6)
	if open:
		row.colors(Color(0.27, 0.13, 0.15, 0.92), Color(0.15, 0.06, 0.08, 0.94))
		row.borders(Color(1, 0.86, 0.6, 0.45), Color(0.3, 0.1, 0.1, 0.6))
	else:
		row.colors(Color(0.17, 0.14, 0.15, 0.9), Color(0.1, 0.08, 0.09, 0.92))
		row.borders(Color(1, 1, 1, 0.1), Color(0, 0, 0, 0.3))
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.pivot_offset = rect.size * 0.5
	var h: = rect.size.y
	var isz: = h - (20.0 if compact else 20.0)
	var icon_x: = 8.0 if compact else 10.0
	var art: Control
	if r.id == "mode" and V10Afisha.MODE_BG.has(str(r.get("mode", ""))) and not compact:
		var p: = "res://assets/bg/%s.webp" % V10Afisha.MODE_BG[r.mode]
		art = Common.card_art(load(p), Rect2(icon_x, (h - isz) * 0.5, isz, isz), Vector2(0.5, 0.45), 1.0, 12)
		if not open:
			(art.material as ShaderMaterial).set_shader_parameter("gray", 1.0)
	else:
		art = V8Art.rect(V8Art.icon(str(r.icon)), Rect2(icon_x, (h - isz) * 0.5, isz, isz))
		if not open:
			art.modulate = Color(0.6, 0.58, 0.58, 0.8)
	row.add_child(art)
	if not open:
		var lk: = V8Art.rect(V8Art.icon("lock"), Rect2(icon_x + isz - (18 if compact else 24), h - (24 if compact else 30), 20 if compact else 26, 20 if compact else 26))
		row.add_child(lk)
	var tx: = icon_x + isz + (8.0 if compact else 14.0)
	var right_w: = 20.0 if compact else 92.0
	var tw: = rect.size.x - tx - right_w
	var tfs: = 16 if compact else 21
	var title_txt: = str(r.title)
	if compact and r.id == "mode":
		title_txt = "%s ×2" % str(V10Afisha.MODE_SHORT.get(str(r.get("mode", "")), "Режим"))
	var t: = UI.label(title_txt, tfs, UI.INK if open else Color("a39a92"), UI.DARK, 3, "body", 900)
	t.position = Vector2(tx, 6 if compact else 10)
	V10MetaUI.trim(t, Vector2(tw, tfs + 6))
	row.add_child(t)
	var sfs: = 12 if compact else 16
	var s_txt: = str(r.sub)
	if compact:
		s_txt = _short_sub(r)
	var s: = UI.label(s_txt, sfs, Color("e9c9a8") if open else Color("8f8580"), UI.DARK, 2, "body", 800)
	s.position = Vector2(tx, (6 if compact else 10) + tfs + 4)
	V10MetaUI.trim(s, Vector2(tw, sfs + 6))
	row.add_child(s)
	if r.has("rule") and not compact:
		s.text = "%s · %s" % [s.text, r.rule]
	# daily tabs (wide only): «Раскладка» | «Чтение руки»
	var tabs: Array = r.get("tabs", [])
	if not compact and tabs.size() > 1:
		s.visible = false
		var x: = tx
		for tb in tabs:
			var fw: = UI.font("body", 900).get_string_size(tb, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 22.0
			var pill: = UI.rbox("glass", Rect2(x, h - 32, fw, 24), 12, 2, 3)
			pill.colors(Color(0.35, 0.16, 0.18, 0.95), Color(0.2, 0.08, 0.1, 0.95))
			pill.borders(Color(1, 0.85, 0.6, 0.5), Color(0, 0, 0, 0.3))
			pill.mouse_filter = Control.MOUSE_FILTER_STOP
			pill.add_child(UI.center_label(UI.label(tb, 15, Color("ffe7c4"), UI.DARK, 2, "body", 900), Rect2(0, 0, fw, 24)))
			var tab_name: String = tb
			pill.gui_input.connect(func(e):
				if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed:
					V9Feel.press(pill)
					row_pressed.emit(str(r.id), tab_name)
					pill.accept_event())
			row.add_child(pill)
			x += fw + 6.0
	# right side: ×2 seal, «Играть» chevron or the lock text
	if bool(r.get("x2", false)) and open and not compact:
		var x2: = UI.rbox("red", Rect2(rect.size.x - (40 if compact else 86), (6 if compact else 10), 34 if compact else 44, 22 if compact else 26), 11, 2, 3)
		x2.add_child(UI.center_label(UI.label("×2", 14 if compact else 17, Color.WHITE, Color("6a1020"), 2, "body", 900), Rect2(Vector2.ZERO, x2.size)))
		row.add_child(x2)
		if compact:
			t.size.x -= 14.0
	if open and not bool(r.done):
		var ch: = UI.label("›", 30 if compact else 38, GOLD_HI, UI.DARK, 3, "body", 900)
		ch.position = Vector2(rect.size.x - (18 if compact else 34), 0)
		ch.size = Vector2(20 if compact else 26, h)
		ch.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(ch)
	row.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed:
			if not open:
				V9Feel.deny(row)
				locked.emit(str(r.id), str(r.lock))
			else:
				V9Feel.press(row)
				row_pressed.emit(str(r.id), str(tabs[0]) if not tabs.is_empty() else ""))
	return row


# compact (198 px) captions: a few words that fit, the full text is in the toast on tap
func _short_sub(r: Dictionary) -> String:
	var lock: = str(r.get("lock", ""))
	if not bool(r.open):
		if lock.begins_with("Откроется на ранге "):
			return "с ранга " + lock.substr(19)
		return "скоро"
	if bool(r.done):
		return V10Afisha.T_PLAYED
	match str(r.id):
		"daily":
			return "до 04:00"
		"mode":
			return "монеты и ранг"
	return str(r.sub)


# the «Сыграно» stamp: red ink frame, Playfair, rotated; animated = slams in with a low pop
func _stamp_on(row: Control, animated: bool) -> void:
	if row.get_node_or_null("Stamp") != null:
		return
	for c in row.get_children():
		if c is CanvasItem and c.name != "Stamp":
			(c as CanvasItem).modulate = Color(0.75, 0.7, 0.7, 0.55)
	var fs: = 15 if compact else 22
	var f: = UI.font("title", 900)
	var txt: = "Сыграно"
	var tw: = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x * 1.15 + (14.0 if compact else 22.0)
	var th: = fs + (10.0 if compact else 14.0)
	var st: = Control.new()
	st.name = "Stamp"
	st.mouse_filter = Control.MOUSE_FILTER_IGNORE
	st.size = Vector2(tw, th)
	st.position = Vector2(row.size.x - tw - (6.0 if compact else 14.0), (row.size.y - th) * 0.5)
	st.pivot_offset = st.size * 0.5
	st.rotation = deg_to_rad(-11.0)
	var frame: = Panel.new()
	var sb: = StyleBoxFlat.new()
	sb.bg_color = Color(INK_RED, 0.12)
	sb.border_color = Color(INK_RED, 0.9)
	sb.set_border_width_all(2 if compact else 3)
	sb.set_corner_radius_all(6)
	frame.add_theme_stylebox_override("panel", sb)
	frame.size = st.size
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	st.add_child(frame)
	var l: = Label.new()
	var ls: = LabelSettings.new()
	ls.font = f
	ls.font_size = fs
	ls.font_color = Color(INK_RED, 0.95)
	l.label_settings = ls
	l.text = txt
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size = st.size
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	st.add_child(l)
	row.add_child(st)
	if animated:
		st.scale = Vector2(2.4, 2.4)
		st.modulate.a = 0.0
		var t: = st.create_tween().set_parallel()
		t.tween_property(st, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		t.tween_property(st, "modulate:a", 1.0, 0.12)
		t.chain().tween_callback(func():
			V9Feel.sound("pop", 0.62, 2.0)
			V9Feel.haptic("match")
			UI.punch(row, 0.04, 0.25)
			if V9Feel.can_fx():
				Fx.burst(row, st.position + st.size * 0.5, "sparkle", int(8 * V9Feel.fx_scale()) + 2, Color(1, 0.55, 0.5), 0.5))


func _ready() -> void:
	V10MetaUI.refit(self)


func refresh() -> void:
	_build()
	V10MetaUI.refit.call_deferred(self)


func stamp(kind: String) -> void:
	V10Afisha.mark(kind)
	var rn: Control = row_nodes.get(kind)
	if rn != null and is_instance_valid(rn):
		_stamp_on(rn, true)
