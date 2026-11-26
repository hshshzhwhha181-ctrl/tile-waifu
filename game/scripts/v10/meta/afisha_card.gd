class_name V10AfishaCard
extends Control

# V10AfishaCard — «Сегодня в чайной» (docs/0.10-spec.md M1 Ф6) laid out by UX_RULES §3.2–§3.4 and HUD_V2 §2:
#   · the CONTENT of the Афиша bottom sheet that the «Сегодня» lantern of the Чайная opens (UX §3.2). The home
#     screen itself gets no card (UX §3.3: 7 tappables, the old right-slot card is gone);
#   · the «Сегодня» block of Столы: the same component with only ["daily", "mode"] and no button of its own (there
#     «Играть · 58» is the primary and Партия дня / Режим дня are the two secondary actions, UX §3.4).
# Rows come from V10Afisha.visible(V10Afisha.rows()): open rows + at most one closed teaser (UX §6.4: silhouette
# and «Откроется: …», no lock icons). Each row is a HUD_V2 M plate (80 px; 128 when the daily row has the
# «Раскладка | Чтение руки» tabs, each tab an S plate 48 with an 80 px hit zone). A played row dims and gets the
# cinnabar «Сыграно» stamp (Playfair 32, low-pitched pop). In the sheet the first unplayed row is «selected»
# (gold.500 hairline, gold.300 title) and the one primary button «Играть» plays it; when everything is played the
# primary is «Понятно» (closes the sheet). Type: Display 32 · Body 22 · Caption 18 — three sizes.
#
#   var c: = V10AfishaCard.make(Vector2(w, 0), opts = {})
#       opts.only: Array of row ids (default all) · opts.play: bool (default true: the «Играть» button)
#       opts.header: bool (default true: «Сегодня в чайной» + the date line)
#   c.refresh()                       rebuild rows (call on V10Meta.bus().day_rolled, after a game)
#   c.stamp(kind)                     marks a row as played with the stamp animation, then re-picks the next row
#   c.preferred_height() -> float
#   signals: row_pressed(id: String, tab: String) · locked(id: String, text: String) · close_pressed()
#   (tab = "Раскладка" / "Чтение руки" for the daily row, "" otherwise; «Играть» emits row_pressed of the selected row)

signal row_pressed(id: String, tab: String)
signal locked(id: String, text: String)
signal close_pressed

const ROW_H: = 80.0
const ROW_TABS_H: = 128.0
const GAP: = 8.0
const HEADER_H: = 96.0
const BTN_H: = 104.0
const BTN_W_MAX: = 560.0
const TX: = 88.0

var box_size: Vector2
var opts: Dictionary = {}
var rows_root: Control
var row_nodes: = {}
var play_btn: JButton
var _rows: Array = []
var _next: Dictionary = {}


static func make(sz: Vector2, o: Dictionary = {}) -> V10AfishaCard:
	var c: = V10AfishaCard.new()
	c.box_size = sz
	c.opts = o
	c.size = sz
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c._build()
	return c


func _play_on() -> bool:
	return bool(opts.get("play", true))


func _header_on() -> bool:
	return bool(opts.get("header", true))


func _row_h(r: Dictionary) -> float:
	return ROW_TABS_H if (r.get("tabs", []) as Array).size() > 1 else ROW_H


func preferred_height() -> float:
	var h: = HEADER_H if _header_on() else 0.0
	for r in _rows:
		h += _row_h(r) + GAP
	if _play_on():
		h += 16.0 + BTN_H
	else:
		h -= GAP
	return maxf(h, 0.0)


func _build() -> void:
	for ch in get_children():
		remove_child(ch)
		ch.queue_free()
	row_nodes.clear()
	play_btn = null
	_rows = V10Afisha.visible(V10Afisha.rows(), opts.get("only", []))
	_next = V10Afisha.next_row(_rows) if _play_on() else {}
	size = Vector2(box_size.x, preferred_height())
	var w: = size.x
	var y: = 0.0
	if _header_on():
		# H2 by the left margin (UX §6.3: headings are left-aligned), the date as a caption under it
		var title: = V10MetaUI.text("Сегодня в чайной", V10MetaUI.FS_DISPLAY, V10MetaUI.PAPER_100, "title", 700)
		title.name = "Title"
		title.position = Vector2(0, 8)
		title.size = Vector2(w, 44)
		add_child(title)
		var sub: = V10MetaUI.text("%s · %s" % [_date_text(), V10Afisha.T_REFRESH], V10MetaUI.FS_CAPTION, V10MetaUI.PAPER_500,
			"body", 700)
		sub.position = Vector2(0, 54)
		V10MetaUI.trim(sub, Vector2(w, 26))
		add_child(sub)
		y = HEADER_H
	rows_root = Control.new()
	rows_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows_root.position = Vector2(0, y)
	rows_root.size = Vector2(w, size.y - y)
	add_child(rows_root)
	var ry: = 0.0
	for r in _rows:
		var rh: = _row_h(r)
		var rn: = _row(r, Rect2(0, ry, w, rh))
		rows_root.add_child(rn)
		row_nodes[r.id] = rn
		if bool(r.done):
			_stamp_on(rn, false)
		ry += rh + GAP
	if _play_on():
		var bw: = minf(w, BTN_W_MAX)
		var by: = y + ry - GAP + 16.0
		if _next.is_empty():
			play_btn = JButton.make("Понятно", "gold", Rect2((w - bw) * 0.5, by, bw, BTN_H), null, V10MetaUI.FS_DISPLAY)
			play_btn.name = "Close"
			play_btn.pressed.connect(func(): close_pressed.emit())
		else:
			var nx: Dictionary = _next
			play_btn = JButton.make("Играть", "gold", Rect2((w - bw) * 0.5, by, bw, BTN_H), null, V10MetaUI.FS_DISPLAY)
			play_btn.name = "Play"
			play_btn.pulse = true
			play_btn.shine_every = 2.8
			play_btn.pressed.connect(func():
				var tabs: Array = nx.get("tabs", [])
				row_pressed.emit(str(nx.id), str(tabs[0]) if not tabs.is_empty() else ""))
		V10MetaUI.role(play_btn, "primary")
		add_child(play_btn)


func _date_text() -> String:
	var key: = V10Meta.day_key()
	var d: = Time.get_datetime_dict_from_unix_time(V10Meta.day_index(key) * 86400)
	return "%s, %d %s" % [V10Meta.WD_SHORT[int(d.weekday)], int(d.day), V10Meta.MONTHS_GEN[int(d.month) - 1]]


func _row(r: Dictionary, rect: Rect2) -> Control:
	var open: = bool(r.open)
	var done: = bool(r.done)
	var selected: = not _next.is_empty() and str(_next.id) == str(r.id)
	var row: = V10MetaUI.plate(rect)
	row.name = "Row_" + str(r.id)
	if selected:
		var hair: ColorRect = row.get_node("Hair")
		hair.color = V10MetaUI.GOLD_500
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.pivot_offset = rect.size * 0.5
	if not _play_on() and open:
		V10MetaUI.role(row, "secondary")
	var isz: = 48.0
	var iy: = 16.0
	var art: Control
	if r.id == "mode" and V10Afisha.MODE_BG.has(str(r.get("mode", ""))):
		var p: = "res://assets/bg/%s.webp" % V10Afisha.MODE_BG[r.mode]
		art = Common.card_art(load(p), Rect2(24, iy, isz, isz), Vector2(0.5, 0.45), 1.0, V10MetaUI.RADIUS)
		if not open:
			(art.material as ShaderMaterial).set_shader_parameter("gray", 1.0)
	else:
		art = V8Art.rect(V8Art.icon(str(r.icon)), Rect2(24, iy, isz, isz))
	if not open:
		# closed = a silhouette in paper.700 (UX §6.4), no lock
		art.modulate = Color(V10MetaUI.PAPER_700, 0.7)
	row.add_child(art)
	var right_w: = 176.0 if done else 56.0
	var tw: = rect.size.x - TX - 24.0 - right_w
	var tcol: = V10MetaUI.GOLD_300 if selected else (V10MetaUI.PAPER_100 if open else V10MetaUI.PAPER_500)
	var t: = V10MetaUI.text(str(r.title), V10MetaUI.FS_BODY, tcol, "body", 800)
	t.name = "Title"
	t.position = Vector2(TX, 8)
	V10MetaUI.trim(t, Vector2(tw, 32))
	row.add_child(t)
	var s_txt: = str(r.sub) if open else str(r.lock)
	if r.has("rule"):
		s_txt = "%s · %s" % [s_txt, r.rule]
	var s: = V10MetaUI.text(s_txt, V10MetaUI.FS_CAPTION, V10MetaUI.PAPER_500, "body", 700)
	s.name = "Sub"
	s.position = Vector2(TX, 42)
	V10MetaUI.trim(s, Vector2(tw, 28))
	row.add_child(s)
	# daily tabs: «Раскладка» | «Чтение руки» — S plates 48 high, hit zone 80 (HUD_V2 §2.1)
	var tabs: Array = r.get("tabs", [])
	if tabs.size() > 1:
		s.visible = false
		var x: = TX
		for tb in tabs:
			var pw: = maxf(96.0, UI.font("body", 800).get_string_size(tb, HORIZONTAL_ALIGNMENT_LEFT, -1, V10MetaUI.FS_CAPTION).x + 32.0)
			var hit: = Control.new()
			hit.name = "Tab_" + str(tb)
			hit.position = Vector2(x, 48)
			hit.size = Vector2(pw, 80)
			hit.mouse_filter = Control.MOUSE_FILTER_STOP
			hit.pivot_offset = hit.size * 0.5
			var pill: = V10MetaUI.plate(Rect2(0, 16, pw, 48), V10MetaUI.NIGHT_600, 1.0, false)
			hit.add_child(pill)
			var pl: = V10MetaUI.text(tb, V10MetaUI.FS_CAPTION, V10MetaUI.PAPER_100, "body", 800)
			pl.size = pill.size
			pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			pl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			pill.add_child(pl)
			var tab_name: String = tb
			hit.gui_input.connect(func(e):
				if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed:
					V9Feel.press(hit)
					row_pressed.emit(str(r.id), tab_name)
					hit.accept_event())
			row.add_child(hit)
			x += pw + 16.0
	# right slot: the chevron of an open row still to play
	if open and not done:
		var ch: = V10MetaUI.text("›", V10MetaUI.FS_DISPLAY, V10MetaUI.GOLD_300, "body", 800)
		ch.position = Vector2(rect.size.x - 24 - 32, 0)
		ch.size = Vector2(32, ROW_H)
		ch.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
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


# the «Сыграно» stamp: cinnabar ink frame (UX §6.2: cinnabar = the hanko only), Playfair 32, rotated; animated =
# slams in with a low pop (fx_level=min: a 120 ms fade)
func _stamp_on(row: Control, animated: bool) -> void:
	if row.get_node_or_null("Stamp") != null:
		return
	for c in row.get_children():
		if c is CanvasItem and c.name != "Stamp" and c.name != "Hair":
			# dimmed, but its captions keep ≥ 4.5:1 on the plate (paper.500 at 0.75 ≈ 4.9:1, В-2)
			(c as CanvasItem).modulate.a = 0.75
	var fs: = V10MetaUI.FS_DISPLAY
	var f: = UI.font("title", 700)
	var txt: = "Сыграно"
	var tw: = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 28.0
	var th: = fs + 14.0
	var st: = Control.new()
	st.name = "Stamp"
	st.mouse_filter = Control.MOUSE_FILTER_IGNORE
	st.size = Vector2(tw, th)
	st.position = Vector2(row.size.x - tw - 24.0, (minf(row.size.y, ROW_H) - th) * 0.5)
	st.pivot_offset = st.size * 0.5
	st.rotation = deg_to_rad(-9.0)
	var frame: = Panel.new()
	var sb: = StyleBoxFlat.new()
	sb.bg_color = Color(V10MetaUI.CINNABAR, 0.1)
	sb.border_color = Color(V10MetaUI.CINNABAR, 0.9)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(V10MetaUI.RADIUS)
	frame.add_theme_stylebox_override("panel", sb)
	frame.size = st.size
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	st.add_child(frame)
	var l: = Label.new()
	var ls: = LabelSettings.new()
	ls.font = f
	ls.font_size = fs
	ls.font_color = Color(V10MetaUI.CINNABAR, 0.95)
	l.label_settings = ls
	l.text = txt
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size = st.size
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	st.add_child(l)
	row.add_child(st)
	if not animated:
		return
	if not V9Feel.can_fx():
		st.modulate.a = 0.0
		st.create_tween().tween_property(st, "modulate:a", 1.0, 0.12)
		V9Feel.sound("pop", 0.62, 2.0)
		return
	st.scale = Vector2(2.4, 2.4)
	st.modulate.a = 0.0
	var t: = st.create_tween().set_parallel()
	t.tween_property(st, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.tween_property(st, "modulate:a", 1.0, 0.1)
	t.chain().tween_callback(func():
		V9Feel.sound("pop", 0.62, 2.0)
		V9Feel.haptic("match")
		Fx.burst(row, st.position + st.size * 0.5, "sparkle", int(8 * V9Feel.fx_scale()) + 2, V10MetaUI.CINNABAR, 0.5))


func _ready() -> void:
	V10MetaUI.refit(self)


func refresh() -> void:
	_build()
	V10MetaUI.refit.call_deferred(self)


# a row played: the stamp slams in, then the card re-picks the next row for «Играть» (0.5 s later)
func stamp(kind: String) -> void:
	V10Afisha.mark(kind)
	var rn: Control = row_nodes.get(kind)
	if rn != null and is_instance_valid(rn):
		_stamp_on(rn, true)
	if is_inside_tree():
		await get_tree().create_timer(0.5).timeout
		if is_inside_tree():
			refresh()
