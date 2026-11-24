class_name V10Help
extends Control

# «Как играть» — the encyclopedia: every topic of V10TutTips as an illustrated card (art: assets/v10/tutorial/),
# a detail sheet with the full explanation and «Показать в игре» (replays the guided chapter), and the tutorial
# settings: «Пройти обучение заново», «Крупный текст», «Подсказки» on/off.
#
#   V10Help.open(main, topic = "")   full-screen overlay over anything (settings popup, a match); topic opens
#                                    its sheet at once. Also usable as a screen: main.SCREENS["v10help"] → build().
#   closes with ✕, Android back (meta v8_back) or «Понятно».

const ROUND: = "shader_type canvas_item;\nuniform float r = 0.1;\nuniform float ratio = 1.0;\nvoid fragment(){\n\tvec4 c = texture(TEXTURE, UV) * COLOR;\n\tvec2 p = (UV - 0.5) * vec2(ratio, 1.0);\n\tvec2 h = vec2(ratio, 1.0) * 0.5 - vec2(r);\n\tvec2 q = abs(p) - h;\n\tfloat d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;\n\tc.a *= 1.0 - smoothstep(-0.006, 0.0, d);\n\tCOLOR = c;\n}\n"
const PAD: = 24.0

var main
var W: = 720.0
var H: = 1280.0
var as_overlay: = false
var scroll: ScrollContainer
var grid: GridContainer
var cat: = ""
var chips: = {}
var sheet: Control
var _rows: = {}


static func open(m, topic: = "") -> V10Help:
	var h: = V10Help.new()
	h.as_overlay = true
	var host: Node = m.get("overlay") if m and m.get("overlay") is Node else m
	h.size = (m as CanvasItem).get_viewport_rect().size
	h.set_meta("v8_back", func(): h.close())
	h.set_meta("popup", true)
	h.set_meta("closable", true)
	host.add_child(h)
	h.build(m, {"topic": topic})
	return h


func build(m, args: Dictionary) -> void:
	main = m
	W = size.x if size.x > 0 else 720.0
	H = size.y if size.y > 0 else 1280.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	name = "V10Help"
	if not as_overlay and main and main.has_method("show_chrome"):
		main.show_chrome(true, true)
	var bg: = ColorRect.new()
	bg.color = Color(0.05, 0.035, 0.06, 1.0)
	bg.size = size
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	Common.backdrop(self, "menu", size, 1.4, 0.45, Color(0.95, 0.85, 0.95), Vector2(0.5, 0.4))
	Common.vignette(self, size, Color(0.05, 0.03, 0.07), 0.7)
	if V9Feel.can_fx():
		Fx.ambient(self, "petals", size)
	_build_header()
	_build_intro()
	_build_chips()
	_build_grid()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.22)
	var tp: = String(args.get("topic", ""))
	if tp != "" and not V10TutTips.topic(tp).is_empty():
		open_topic.call_deferred(tp)


func close() -> void:
	if is_instance_valid(sheet):
		_close_sheet()
		return
	if not as_overlay:
		if main and main.has_method("back"):
			main.back()
		return
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t: = create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.18)
	t.tween_callback(queue_free)


func _top() -> float:
	return 26.0 if as_overlay else 120.0


func _build_header() -> void:
	var y: = _top()
	var plate: = UI.rbox("graphite", Rect2(8, y, W - 16, 84), 42, 2, 10)
	plate.colors(Color(0.13, 0.12, 0.14, 0.86), Color(0.07, 0.065, 0.08, 0.9))
	plate.set_param("border_top", Color(0.95, 0.85, 0.6, 0.55)).set_param("border_bottom", Color(0.45, 0.32, 0.16, 0.6))
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(plate)
	var title: = UI.center_label(UI.label("Как играть", 34, Color("ffe7b0"), UI.DARK, 5, "title", 900), Rect2(0, y + 14, W, 56))
	add_child(title)
	var x: = JButton.make("", "graphite", Rect2(W - 88, y + 8, 68, 68), null, 30, 34.0)
	x.box.set_param("border", 3.0)
	x.add_child(V8Art.rect(V8Art.icon("close"), Rect2(17, 17, 34, 34)))
	x.sound = "tap"
	x.pressed.connect(close)
	x.name = "Close"
	add_child(x)


func _build_intro() -> void:
	var y: = _top() + 104.0
	var k: = V10TutState.text_scale()
	var card: = UI.rbox("plum", Rect2(PAD, y, W - PAD * 2, 210), 28, 3, 12)
	card.colors(Color(0.18, 0.11, 0.2, 0.94), Color(0.1, 0.06, 0.12, 0.96)).borders(Color("fff0c4"), Color("b88432"))
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(card)
	var por: = TextureRect.new()
	por.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	por.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	por.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var at: = AtlasTexture.new()
	at.atlas = load("res://assets/v08/emotions/mc_happy.webp")
	at.region = Rect2(60, 10, 480, 560)
	por.texture = at
	por.position = Vector2(8, -18)
	por.size = Vector2(150, 175)
	por.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(por)
	var tl: = UI.label("Забыл, что к чему? Здесь всё по полочкам.\nКарточку можно открыть, урок — пройти заново.", int(18 * k), Color("fff1dc"), UI.DARK, 2, "body", 800)
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tl.position = Vector2(168, 16)
	tl.size = Vector2(card.size.x - 186, 90)
	card.add_child(tl)
	var bw: = (card.size.x - 168 - 18 - 12) * 0.5
	var again: = JButton.make("Обучение заново", "pink", Rect2(168, 112, bw, 74), null, 19)
	again.name = "Replay"
	again.pressed.connect(func():
		V10Tutorial.replay()
		if main and main.has_method("toast"):
			main.toast("Маджонг-тян снова всё покажет", "heart")
		close())
	card.add_child(again)
	var big: = JButton.make("Крупный текст", "glass", Rect2(168 + bw + 12, 112, bw, 74), null, 19, -1.0, false)
	big.name = "Large"
	var paint: = func():
		big.lbl.text = "Крупный текст: " + ("да" if V10TutState.large() else "нет")
		Common.tab_paint(big, V10TutState.large())
	paint.call()
	big.pressed.connect(func():
		V10TutState.set_large(not V10TutState.large())
		paint.call())
	card.add_child(big)
	UI.slide_in(card, Vector2(0, 30), 0.05, 0.4)


func _build_chips() -> void:
	var y: = _top() + 330.0
	var all: = [["", "Все"]] + V10TutTips.CATS
	var x: = PAD
	var row: = Control.new()
	row.position = Vector2(0, y)
	row.size = Vector2(W, 58)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	var f: = UI.font("body", 900)
	for c in all:
		var w: = f.get_string_size(String(c[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 34.0
		if x + w > W - PAD:
			break
		var b: = JButton.make(String(c[1]), "glass", Rect2(x, 0, w, 52), null, 18, 26.0, false)
		var id: String = c[0]
		b.pressed.connect(func(): _set_cat(id))
		row.add_child(b)
		chips[id] = b
		x += w + 8.0
	_paint_chips()
	# the tip toggle sits under the chips on the right: «Подсказки: вкл»
	var tg: = JButton.make("Подсказки", "glass", Rect2(W - PAD - 300, y + 64, 300, 48), null, 16, 24.0, false)
	tg.name = "Tips"
	var paint: = func():
		tg.lbl.text = "Подсказки на экранах: " + ("нет" if V10TutState.tips_off() else "да")
	paint.call()
	tg.pressed.connect(func():
		V10TutState.set_tips_off(not V10TutState.tips_off())
		paint.call())
	add_child(tg)
	var rs: = JButton.make("Показать снова", "glass", Rect2(PAD, y + 64, 200, 48), null, 16, 24.0, false)
	rs.name = "ResetTips"
	rs.pressed.connect(func():
		V10TutState.reset_tips()
		paint.call()
		_fill()
		if main and main.has_method("toast"):
			main.toast("Подсказки покажутся снова", "heart"))
	add_child(rs)


func _set_cat(id: String) -> void:
	cat = id
	_paint_chips()
	_fill()


func _paint_chips() -> void:
	for k in chips:
		Common.tab_paint(chips[k], k == cat)


func _cols() -> int:
	return clampi(int((W - PAD * 2 + 16) / 230.0), 2, 4)


func _build_grid() -> void:
	var top: = _top() + 456.0
	scroll = ScrollContainer.new()
	scroll.position = Vector2(PAD, top)
	scroll.size = Vector2(W - PAD * 2, H - top - 16.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	add_child(scroll)
	grid = GridContainer.new()
	grid.columns = _cols()
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	scroll.add_child(grid)
	Common.edge_shade(self, Rect2(0, top - 4, W, 26), 1, Color(0.05, 0.035, 0.06), 0.85, 0.2)
	_fill()


func _card_w() -> float:
	var n: = _cols()
	return floor((W - PAD * 2 - 16.0 * (n - 1)) / n)


func _fill() -> void:
	for c in grid.get_children():
		grid.remove_child(c)
		c.queue_free()
	_rows.clear()
	var i: = 0
	for tp in V10TutTips.TOPICS:
		if cat != "" and tp.cat != cat:
			continue
		var c: = _card(tp)
		grid.add_child(c)
		_rows[tp.id] = c
		UI.pop_in(c, 0.03 * mini(i, 10), 0.85)
		i += 1


static func tex_for(tp: Dictionary) -> Texture2D:
	var p: = V10TutTips.icon_path(tp)
	if ResourceLoader.exists(p):
		return load(p)
	return V8Art.icon("help")


static func rounded(tr: TextureRect, r: = 0.09, ratio: = 1.0) -> void:
	var m: = ShaderMaterial.new()
	var sh: = Shader.new()
	sh.code = ROUND
	m.shader = sh
	m.set_shader_parameter("r", r)
	m.set_shader_parameter("ratio", ratio)
	tr.material = m


func _card(tp: Dictionary) -> Control:
	var cw: = _card_w()
	var k: = V10TutState.text_scale()
	var tfs: = int(round(18 * minf(k, 1.15)))
	var f: = UI.font("body", 900)
	var th: = f.get_multiline_string_size(String(tp.title), HORIZONTAL_ALIGNMENT_CENTER, cw - 20, tfs).y
	var ch: = cw + th + 26.0
	var c: = Control.new()
	c.custom_minimum_size = Vector2(cw, ch)
	c.size = Vector2(cw, ch)
	c.pivot_offset = c.size * 0.5
	c.set_meta("tut_id", "help.card." + String(tp.id))
	var bg: = UI.rbox("plum", Rect2(0, 0, cw, ch), 24, 3, 8)
	bg.colors(Color(0.16, 0.1, 0.18, 0.95), Color(0.08, 0.05, 0.1, 0.97)).borders(Color(1.0, 0.9, 0.7, 0.55), Color(0.6, 0.42, 0.18, 0.7))
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(bg)
	var img: = TextureRect.new()
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	img.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	img.texture = tex_for(tp)
	img.position = Vector2(8, 8)
	img.size = Vector2(cw - 16, cw - 16)
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rounded(img, 0.08)
	c.add_child(img)
	var tl: = UI.label(String(tp.title), tfs, Color("ffe9c8"), UI.DARK, 3, "body", 900)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tl.position = Vector2(10, cw - 2)
	tl.size = Vector2(cw - 20, th + 8)
	c.add_child(tl)
	# a soft «new» dot until the topic was seen as a tip (or opened here)
	if not V10TutState.tip_seen(String(tp.id)) and String(tp.get("tip", "")) != "":
		var d: = UI.rbox("gold", Rect2(cw - 30, 12, 18, 18), 9, 1, 3)
		d.colors(Color("ffe7a6"), Color("ff8fb0"))
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.add_child(d)
	var id: = String(tp.id)
	_tap(c, func(): open_topic(id))
	return c


func _tap(c: Control, cb: Callable) -> void:
	c.mouse_filter = Control.MOUSE_FILTER_PASS
	var st: = {"down": false, "at": Vector2.ZERO, "sv": 0}
	c.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				st.down = true
				st.at = e.global_position
				st.sv = scroll.scroll_vertical
				V9Feel.press_down(c)
			elif st.down:
				st.down = false
				var fire: bool = e.global_position.distance_to(st.at) < 14.0 and absi(scroll.scroll_vertical - int(st.sv)) < 14
				V9Feel.press_up(c, fire)
				if fire:
					cb.call()
		elif e is InputEventMouseMotion and st.down and e.global_position.distance_to(st.at) >= 14.0:
			st.down = false
			V9Feel.press_up(c, false))


# ── detail sheet ─────────────────────────────────────────────────────────────────────────────────────────────

func open_topic(id: String) -> void:
	var tp: = V10TutTips.topic(id)
	if tp.is_empty():
		return
	if is_instance_valid(sheet):
		sheet.queue_free()
	if not V10TutState.tip_seen(id) and String(tp.get("tip", "")) != "":
		V10TutState.mark_tip(id)
	var k: = V10TutState.text_scale()
	sheet = Control.new()
	sheet.size = size
	sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	sheet.name = "Sheet"
	add_child(sheet)
	var sh: = ColorRect.new()
	sh.size = size
	sh.color = Color(0.02, 0.01, 0.03, 0.0)
	sh.mouse_filter = Control.MOUSE_FILTER_STOP
	sh.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			_close_sheet())
	sheet.add_child(sh)
	sh.create_tween().tween_property(sh, "color:a", 0.72, 0.2)
	var w: = minf(W - 40.0, 640.0)
	var iw: = w - 48.0
	var ih: = minf(iw, H * 0.34)
	var fs: = int(round(21 * k))
	var f: = UI.font("body", 800)
	var bth: = f.get_multiline_string_size(String(tp.help), HORIZONTAL_ALIGNMENT_LEFT, w - 56, fs).y
	var has_replay: = String(tp.get("replay", "")) != ""
	var h: = 24.0 + ih + 20.0 + 48.0 + bth + 30.0 + 96.0
	h = minf(h, H - 60.0)
	var p: = UI.rbox("plum", Rect2((W - w) * 0.5, maxf(30.0, (H - h) * 0.5), w, h), 34, 4, 14)
	p.colors(Color(0.17, 0.11, 0.2, 0.98), Color(0.09, 0.055, 0.11, 0.99)).borders(Color("fff0c4"), Color("b88432"))
	sheet.add_child(p)
	var img: = TextureRect.new()
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	img.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	img.texture = tex_for(tp)
	img.position = Vector2(24, 24)
	img.size = Vector2(iw, ih)
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rounded(img, 0.06, iw / ih)
	p.add_child(img)
	var tl: = UI.label(String(tp.title), int(28 * minf(k, 1.15)), Color("ffe7b0"), UI.DARK, 4, "title", 900)
	tl.position = Vector2(28, 24 + ih + 14)
	tl.size = Vector2(w - 56, 44)
	tl.clip_text = true
	p.add_child(tl)
	var bl: = UI.label(String(tp.help), fs, Color("f3e6d4"), UI.DARK, 2, "body", 800)
	bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bl.position = Vector2(28, 24 + ih + 62)
	bl.size = Vector2(w - 56, bth + 6)
	p.add_child(bl)
	var by: = h - 100.0
	if has_replay:
		var bw: = (w - 72.0) * 0.5
		var rp: = JButton.make("Показать в игре", "pink", Rect2(24, by, bw, 80), null, 21)
		rp.name = "Show"
		var ch_id: = String(tp.replay)
		rp.pressed.connect(func():
			V10Tutorial.replay(ch_id)
			if main and main.has_method("toast"):
				main.toast("Покажу, когда дойдём до этого места", "heart")
			_close_sheet()
			close())
		p.add_child(rp)
		var ok: = JButton.make("Понятно", "glass", Rect2(48 + bw, by, bw, 80), null, 22, -1.0, false)
		ok.name = "Ok"
		ok.pressed.connect(_close_sheet)
		p.add_child(ok)
	else:
		var ok2: = JButton.make("Понятно", "pink", Rect2(w * 0.5 - 150, by, 300, 80), null, 22)
		ok2.name = "Ok"
		ok2.pressed.connect(_close_sheet)
		p.add_child(ok2)
	p.pivot_offset = p.size * 0.5
	UI.pop_in(p, 0.0, 0.85)
	V9Feel.sound("pop", 1.1, -6.0)


func _close_sheet() -> void:
	if not is_instance_valid(sheet):
		return
	var s: = sheet
	sheet = null
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t: = s.create_tween()
	t.tween_property(s, "modulate:a", 0.0, 0.16)
	t.tween_callback(s.queue_free)
	if is_instance_valid(grid):
		_fill()


# for the «?» buttons of other screens: a round help button that opens this book at `topic`
static func help_button(parent: Control, rect: Rect2, m, topic: String) -> JButton:
	var b: = JButton.make("", "graphite", rect, null, 26, rect.size.y * 0.5)
	b.box.set_param("border", 3.0)
	b.add_child(V8Art.rect(V8Art.icon("help"), Rect2(rect.size * 0.18, rect.size * 0.64)))
	b.sound = "tap"
	b.pressed.connect(func(): V10Help.open(m, topic))
	b.set_meta("tut_id", "help." + topic)
	parent.add_child(b)
	return b
