class_name V10Sheet
extends Control

# A full-screen sheet over anything (match, victory, settings): dark backdrop, the pink title ribbon, a close button,
# optional tabs, a vertical scroll list with soft edges and an optional footer row of buttons.
# Used by V10Legend («Фишки») and V10GlossaryScreen («Словарь»).

var scroll: ScrollContainer
var list: VBoxContainer
var cw: = 664.0
var host: Node
var top: = 150.0
var bottom: = 0.0
var tabs: = []
var _closing: = false

static func make(h: Node, title: String, footer: = false) -> V10Sheet:
	var layer: = V10InfoCard.layer_for(h)
	var s: = V10Sheet.new()
	s.host = h
	s.name = "V10Sheet"
	var vs: Vector2 = h.get_viewport().get_visible_rect().size
	s.size = vs
	s.mouse_filter = Control.MOUSE_FILTER_STOP
	s.z_index = 40
	layer.add_child(s)
	s._build(vs, title, footer)
	return s

func _build(vs: Vector2, title: String, footer: bool) -> void:
	var dim: = ColorRect.new()
	dim.size = vs
	dim.color = Color(0.05, 0.035, 0.055, 0.0)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	dim.create_tween().tween_property(dim, "color:a", 0.94, 0.22)
	var rays: = Common.rays(self, Vector2(vs.x * 0.5, 70), 900, Color(1, 0.86, 0.6, 0.18), 12, 0.03, 0.5)
	rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rib: = Common.ribbon(self, title, Rect2(vs.x * 0.5 - 240, 24, 480, 92), "pink", 40)
	rib.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.pop_in(rib, 0.0, 0.6)
	var x: = JButton.make("", "graphite", Rect2(vs.x - 92, 36, 72, 72), null, 30)
	if x.box:
		x.box.borders(Color("ffe7a6"), Color("a8742a"))
	x.add_child(V8Art.rect(V8Art.icon("close"), Rect2(18, 18, 36, 36)))
	x.pressed.connect(close)
	add_child(x)
	cw = minf(672.0, vs.x - 40.0)
	top = 136.0
	bottom = vs.y - (128.0 if footer else 24.0)
	scroll = ScrollContainer.new()
	scroll.position = Vector2((vs.x - cw) * 0.5, top)
	scroll.size = Vector2(cw, bottom - top)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	add_child(scroll)
	list = VBoxContainer.new()
	list.custom_minimum_size = Vector2(cw, 0)
	list.add_theme_constant_override("separation", 12)
	scroll.add_child(list)
	Common.scroll_fade(scroll, list, 90.0, 0.3)
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.18)
	Sfx.play("pop", 1.0, -4)

# a tab row under the ribbon; pressing one calls cb(i). Returns the buttons.
func add_tabs(names: Array, cur: int, cb: Callable) -> Array:
	var vs: = size
	var n: = names.size()
	var gap: = 10.0
	var tw: = (cw - gap * (n - 1)) / n
	var x0: = (vs.x - cw) * 0.5
	tabs.clear()
	for i in n:
		var b: = JButton.make(String(names[i]), "pink" if i == cur else "glass", Rect2(x0 + i * (tw + gap), 130, tw, 60), null, 21, -1.0, false)
		Common.tab_paint(b, i == cur)
		var k: = i
		b.pressed.connect(func():
			for j in tabs.size():
				Common.tab_paint(tabs[j], j == k)
			cb.call(k))
		add_child(b)
		tabs.append(b)
	top = 202.0
	scroll.position.y = top
	scroll.size.y = bottom - top
	Common.edge_shade(self, Rect2(0, top - 4, vs.x, 30), 1, Color(0.05, 0.035, 0.055), 0.9, 0.2)
	return tabs

func clear_list() -> void:
	for c in list.get_children():
		c.queue_free()
	scroll.scroll_vertical = 0

# a section caption in the list
func section(text: String) -> Control:
	var c: = Control.new()
	c.custom_minimum_size = Vector2(cw, 44)
	var l: = UI.label(text.to_upper(), 19, Color("ffd98a"), UI.DARK, 3, "body", 900)
	l.position = Vector2(8, 12)
	c.add_child(l)
	var line: = ColorRect.new()
	line.color = Color(1.0, 0.85, 0.55, 0.25)
	line.position = Vector2(8, 41)
	line.size = Vector2(cw - 16, 2)
	c.add_child(line)
	list.add_child(c)
	return c

# a plain wrapped paragraph
func para(text: String, fs: = 19, col: = UI.INK) -> Label:
	var f: = UI.font("body", 800)
	var h: float = f.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, cw - 24, fs).y + 8.0
	var l: = UI.label(text, fs, col, UI.DARK, 2, "body", 800)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(cw - 24, h)
	var wrap: = MarginContainer.new()
	wrap.add_theme_constant_override("margin_left", 12)
	wrap.add_child(l)
	list.add_child(wrap)
	return l

# one entry row: icon · name (+ sub) · why; right: an optional count. Tap → the info card.
func entry_row(e: Dictionary, count: = -1) -> RBox:
	var f: = UI.font("body", 800)
	var tw: = cw - 104.0 - (64.0 if count >= 0 else 16.0)
	var wh: float = f.get_multiline_string_size(String(e.why), HORIZONTAL_ALIGNMENT_LEFT, tw, 17).y
	var h: = maxf(84.0, 44.0 + wh + 12.0)
	var row: = UI.rbox("plum", Rect2(0, 0, cw, h), 22, 2, 4)
	row.custom_minimum_size = Vector2(cw, h)
	row.borders(Color(1.0, 0.9, 0.7, 0.4), Color(0, 0, 0, 0.35))
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(V10ClarityIcon.make(String(e.icon), 72, Vector2(12, (h - 72) * 0.5)))
	var nm: = UI.label(String(e.name), 22, Color("fff2d2"), UI.DARK, 3, "body", 900)
	nm.position = Vector2(96, 8)
	row.add_child(nm)
	if String(e.get("sub", "")) != "":
		var nw: = UI.font("body", 900).get_string_size(String(e.name), HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		var sl: = UI.label("· " + String(e.sub), 15, Color("bfb3a8"), UI.DARK, 2, "body", 800)
		sl.position = Vector2(96 + nw + 10, 14)
		sl.size = Vector2(maxf(20.0, cw - 96 - nw - 20 - (64.0 if count >= 0 else 0.0)), 24)
		sl.clip_text = true
		sl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_child(sl)
	var wl: = UI.label(String(e.why), 17, Color("d9cdbf"), UI.DARK, 2, "body", 800)
	wl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	wl.position = Vector2(96, 40)
	wl.size = Vector2(tw, wh + 4)
	row.add_child(wl)
	if count >= 0:
		var cl: = UI.label("×%d" % count if count > 0 else "—", 22, Color("ffd98a") if count > 0 else Color(1, 1, 1, 0.3), UI.DARK, 3, "body", 900)
		cl.position = Vector2(cw - 70, 0)
		cl.size = Vector2(56, h)
		cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		cl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(cl)
	var id: String = e.id
	var st: = {"at": Vector2.ZERO, "sv": 0, "down": false}
	row.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
			if ev.pressed:
				st.down = true
				st.at = ev.global_position
				st.sv = scroll.scroll_vertical
			elif st.down:
				st.down = false
				if ev.global_position.distance_to(st.at) < 20.0 and absi(scroll.scroll_vertical - int(st.sv)) < 12:
					V9Feel.press(row, "tap", "tap")
					var ex: = {"no_more": true}
					if count > 0:
						ex["count"] = count
					V10InfoCard.open(self, id, ex))
	list.add_child(row)
	return row

func close() -> void:
	if _closing:
		return
	_closing = true
	Sfx.play("tap")
	var t: = create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.16)
	t.tween_callback(queue_free)
	if has_meta("on_close"):
		(get_meta("on_close") as Callable).call()
