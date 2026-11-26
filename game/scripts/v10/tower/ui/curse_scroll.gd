class_name V10CurseScroll
extends Control

# «Проклятия» — the scroll of the Pagoda (spec R1/R2). A bottom sheet of dark lacquer that unrolls like a makimono
# («Лак», 600 ms EXPO IN_OUT; fx "min": a 120 ms fade). On top, large: «Жар 12 · очки ×2,2» (rolls when it
# changes, a soft flash in the heat colour, never white) and a thin heat line «из 34». Below: the 11 curses
# (V10ModsData.CURSE_ORDER), each a lacquer card with its cinnabar seal, the name, «+N Жара» and a level segment
# «— / I / II / III» (only the levels the curse has). Only the last touched curse shows its line (≤ 60 words on the
# sheet). A level that V10Mods.can_set forbids is grey; a tap on it denies and shows «Слишком жестоко даже для
# Пагоды»; a curse with every level forbidden is a grey card with that line. Bottom: «Готово» (primary) and
# «Сбросить» (secondary, only when something is chosen). A tap on the dimmed screen above works as «Готово».
#
#   var s := V10CurseScroll.open(screen, {"fog": 2}, func(curses: Dictionary) -> void: …)
#   s.set_level("narrow", 1) -> bool (false + deny when forbidden)    s.heat() -> int    s.close(apply := true)
#   s.cell(id, lvl) -> Control (the tap target, for tests)            signal changed(curses)

signal changed(curses: Dictionary)
signal closed

const ROW_H: = 80.0
const ROW_GAP: = 8.0
const DESC_H: = 52.0
const CELL: = 80.0
const ROMAN: = ["—", "I", "II", "III"]

var curses: = {}
var on_close: = Callable()
var touched: = ""  # the one row with its line open
var denied: = ""  # the row whose line is «Слишком жестоко…» after a denied tap

var _vs: = Vector2(720, 1280)
var _T: = 0.0
var _B: = 0.0
var _cx: = 0.0
var _y0: = 0.0
var _rod_y: = 0.0
var _clip: Control
var _content: _Paper
var _scroll: ScrollContainer
var _list: VBoxContainer
var _rows: = {}
var _heat_l: Label
var _of_l: Label
var _done: V10Button
var _reset: V10Button
var _shown_heat: = 0
var _line_k: = 0.0
var _closing: = false
var _rod: _Rod


static func open(parent: Control, c: Dictionary, cb: Callable = Callable()) -> V10CurseScroll:
	var s: = V10CurseScroll.new()
	s.curses = _sanitize(c)
	s.on_close = cb
	s.name = "CurseScroll"
	parent.add_child(s)
	s._build()
	s._unroll()
	return s


# a stored scroll may be invalid after a matrix update: drop the last curses until V10Mods.validate passes
static func _sanitize(c: Dictionary) -> Dictionary:
	var out: = {}
	for id in V10ModsData.CURSE_ORDER:
		var lv: = int(c.get(id, 0))
		if lv > 0:
			out[id] = mini(lv, (V10ModsData.CURSES[id].levels as Array).size())
	var order: = V10ModsData.CURSE_ORDER.duplicate()
	order.reverse()
	for id in order:
		if V10Mods.validate(out).ok:
			break
		out.erase(id)
	return out


func heat() -> int:
	return V10Mods.heat(curses)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_meta("tw_surface", true)
	set_meta("tw_sheet", true)


func _build() -> void:
	_vs = get_viewport_rect().size
	var ins: = V10TowerUI.insets(_vs)
	_T = float(ins.top)
	_B = float(ins.bottom)
	_cx = floorf(maxf(0.0, (_vs.x - 720.0) * 0.5))
	position = Vector2.ZERO
	size = _vs
	_y0 = _T + V10Header.HEIGHT + 12.0  # the rod rests just under the header, never over its title
	_shown_heat = heat()
	_line_k = float(_shown_heat) / float(V10ModsData.HEAT_MAX)
	# the paper: a clip that grows from the bottom; content stays fixed on screen (it is revealed, not slid)
	_clip = Control.new()
	_clip.clip_contents = true
	_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_clip)
	_content = _Paper.new()
	_content.s = self
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.size = Vector2(_vs.x, _vs.y - _y0)
	_clip.add_child(_content)
	var pad: = _cx + 24.0
	# heading: «Жар 12 · очки ×2,2» Display 44 + heat line + «из 34»
	_heat_l = V10TowerUI.label(V10Pagoda.heat_text(_shown_heat), "display", 44, V10DS.PAPER_100)
	_heat_l.position = Vector2(pad, 28.0)
	_heat_l.size = Vector2(672.0, 56.0)
	_content.add_child(_heat_l)
	_of_l = V10TowerUI.label("из %d" % V10ModsData.HEAT_MAX, "ui", 18, V10DS.PAPER_500)
	_of_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_of_l.position = Vector2(pad + 572.0, 92.0)
	_of_l.size = Vector2(100.0, 26.0)
	_content.add_child(_of_l)
	# the list
	var btn_y: = _vs.y - _B - 32.0 - 104.0
	var list_top: = 136.0
	var list_bottom: = btn_y - _y0 - 20.0
	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(pad, list_top)
	_scroll.size = Vector2(672.0, list_bottom - list_top)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	_content.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", int(ROW_GAP))
	_list.custom_minimum_size = Vector2(672.0, 0)
	_list.mouse_filter = Control.MOUSE_FILTER_PASS
	_scroll.add_child(_list)
	var fade: = _Fade.new()
	fade.position = Vector2(pad - 8.0, list_bottom - 40.0)
	fade.size = Vector2(688.0, 40.0)
	_content.add_child(fade)
	for id in V10ModsData.CURSE_ORDER:
		var r: = _Row.new()
		r.s = self
		r.id = id
		_list.add_child(r)
		r.build()
		_rows[id] = r
	# buttons: «Сбросить» (secondary) · «Готово» (primary)
	_done = V10Button.make("play", "Готово", Vector2(440, 104))
	_done.position = Vector2(_cx + 696.0 - 440.0, btn_y - _y0)
	V10TowerUI.role(_done, "primary")
	_done.pressed.connect(func() -> void:
		_tap(_done, "pop")
		close(true))
	_content.add_child(_done)
	_reset = V10Button.make("secondary", "Сбросить", Vector2(200, 80))
	_reset.position = Vector2(pad, btn_y - _y0 + 12.0)
	V10TowerUI.role(_reset, "secondary")
	_reset.pressed.connect(func() -> void:
		_tap(_reset, "pop")
		reset())
	_content.add_child(_reset)
	_rod = _Rod.new()
	_rod.s = self
	add_child(_rod)
	_refresh(false)


func _tap(n: CanvasItem, snd: String) -> void:
	n.scale = Vector2.ONE
	V10TowerUI.tap(n, snd)


# ---------------------------------------------------------------- unroll / roll up

func _set_rod(y: float) -> void:
	_rod_y = y
	_clip.position = Vector2(0, y)
	_clip.size = Vector2(_vs.x, maxf(0.0, _vs.y - y))
	_content.position = Vector2(0, _y0 - y)
	_rod.queue_redraw()
	queue_redraw()


func _unroll() -> void:
	V10TowerUI.sfx("feather", "pop")
	if V10TowerUI.calm():
		_set_rod(_y0)
		modulate.a = 0.0
		create_tween().tween_property(self, "modulate:a", 1.0, 0.12)
		return
	_set_rod(_vs.y - _B)
	var tw: = create_tween()
	tw.tween_method(_set_rod, _vs.y - _B, _y0, 0.6).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN_OUT)


func close(apply: = true) -> void:
	if _closing:
		return
	_closing = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	var done: = func() -> void:
		if apply and on_close.is_valid():
			on_close.call(curses.duplicate())
		closed.emit()
		queue_free()
	if V10TowerUI.calm() or not is_inside_tree():
		done.call()
		return
	var tw: = create_tween()
	tw.tween_method(_set_rod, _rod_y, _vs.y - _B, 0.36).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.36).set_delay(0.12)
	tw.tween_callback(done)


func _gui_input(e: InputEvent) -> void:
	# a tap on the dimmed hub above the paper = «Готово»
	if (e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed) or (e is InputEventScreenTouch and not e.pressed):
		if e.position.y < _rod_y - 16.0:
			close(true)
	accept_event()


func _draw() -> void:
	# the scrim over the hub (the paper itself is drawn by _Paper inside the clip)
	draw_rect(Rect2(Vector2.ZERO, _vs), Color(V10DS.NIGHT_900, 0.62 * clampf((_vs.y - _rod_y) / maxf(1.0, _vs.y - _y0), 0.0, 1.0)))


# ---------------------------------------------------------------- levels

func cell(id: String, lvl: int) -> Control:
	var r: _Row = _rows.get(id)
	return r.cells[lvl] if r and lvl < r.cells.size() else null


func allowed(id: String, lvl: int) -> bool:
	return V10Mods.can_set(curses, id, lvl)


# every non-zero level forbidden: the curse is a grey card
func blocked(id: String) -> bool:
	var n: = (V10ModsData.CURSES[id].levels as Array).size()
	for lv in range(1, n + 1):
		if allowed(id, lv):
			return false
	return int(curses.get(id, 0)) == 0


func set_level(id: String, lvl: int) -> bool:
	var r: _Row = _rows.get(id)
	if lvl > 0 and not allowed(id, lvl):
		touched = id
		denied = id
		if r and lvl < r.cells.size():
			V10TowerUI.deny(r.cells[lvl])
		_refresh(true)
		return false
	if lvl <= 0:
		curses.erase(id)
	else:
		curses[id] = lvl
	touched = id
	denied = ""
	_refresh(true)
	changed.emit(curses.duplicate())
	return true


func reset() -> void:
	curses = {}
	touched = ""
	denied = ""
	_refresh(true)
	changed.emit(curses.duplicate())


func _refresh(animate: bool) -> void:
	for id in _rows:
		(_rows[id] as _Row).sync(animate)
	_reset.visible = not curses.is_empty()
	var h: = heat()
	if h != _shown_heat:
		_roll_to(h, animate)


func _roll_to(h: int, animate: bool) -> void:
	var from: = _shown_heat
	_shown_heat = h
	var k1: = float(h) / float(V10ModsData.HEAT_MAX)
	if not animate or V10TowerUI.calm():
		_heat_l.text = V10Pagoda.heat_text(h)
		_line_k = k1
		_content.queue_redraw()
		return
	if h > from:
		V10TowerUI.sfx("heat_flare", "pop", 1.0, -8.0)
	var tw: = create_tween()
	tw.tween_method(func(v: float) -> void:
		_heat_l.text = V10Pagoda.heat_text(int(round(v))), float(from), float(h), 0.32 if absi(h - from) > 1 else 0.12).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	var k0: = _line_k
	tw.parallel().tween_method(func(v: float) -> void:
		_line_k = v
		_content.queue_redraw(), k0, k1, 0.4).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_content.flash(V10TowerUI.heat_color(h))


# ---------------------------------------------------------------- the paper (heading tone, heat line, flash)

class _Paper extends Control:
	var s: V10CurseScroll
	var _flash: = 0.0
	var _flash_c: = V10DS.GOLD_300

	func flash(c: Color) -> void:
		_flash_c = c
		_flash = 1.0
		var tw: = create_tween()
		tw.tween_method(func(v: float) -> void:
			_flash = v
			queue_redraw(), 1.0, 0.0, 0.5).set_trans(Tween.TRANS_SINE)

	func _draw() -> void:
		var w: = size.x
		var r: = Rect2(Vector2.ZERO, Vector2(w, size.y + 8.0))
		V10Plate.draw_surface(self, r, false, false, false, false, false, -1.0, V10TowerUI.LACQUER)
		# lacquer depth: a slightly lighter band behind the heading
		var top: = Color(V10TowerUI.LACQUER_HI, 0.9)
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, 132), Vector2(0, 132)]),
				PackedColorArray([top, top, Color(top, 0.0), Color(top, 0.0)]))
		if _flash > 0.0:
			var fc: = Color(_flash_c, 0.22 * _flash)
			draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, 132), Vector2(0, 132)]),
					PackedColorArray([fc, fc, Color(fc, 0.0), Color(fc, 0.0)]))
		# the heat line: 2 px, filled in the heat colour, «из 34» at its end
		var x0: = s._cx + 24.0
		var x1: = s._cx + 572.0
		var y: = 105.0
		draw_line(Vector2(x0, y), Vector2(x1, y), V10DS.NIGHT_600, 2.0)
		var hx: = lerpf(x0, x1, clampf(s._line_k, 0.0, 1.0))
		if hx > x0 + 1.0:
			draw_line(Vector2(x0, y), Vector2(hx, y), V10TowerUI.heat_color(s._shown_heat), 2.0)
		# a hairline over the list top
		V10Plate.hairline(self, x0, s._cx + 696.0, 128.5, Color(V10DS.GOLD_700, 0.25))


# the roll: a lacquered rod with gold knobs that rises while the paper unrolls (thicker while still rolled up)
class _Rod extends Control:
	var s: V10CurseScroll

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var y: = s._rod_y
		var k: = clampf((y - s._y0) / maxf(1.0, s._vs.y - s._y0), 0.0, 1.0)
		var h: = lerpf(14.0, 30.0, k)
		var x0: = s._cx + 12.0
		var x1: = s._cx + 708.0
		var r: = Rect2(x0, y - h * 0.5, x1 - x0, h)
		draw_rect(r, V10DS.NIGHT_900)
		draw_rect(Rect2(r.position + Vector2(0, 2), Vector2(r.size.x, h * 0.35)), V10TowerUI.LACQUER_HI)
		V10Plate.hairline(self, x0, x1, r.position.y + 1.5, Color(V10DS.GOLD_700, 0.55))
		draw_line(Vector2(x0, r.end.y - 0.5), Vector2(x1, r.end.y - 0.5), Color(V10DS.NIGHT_900, 0.9), 1.0)
		for kx in [x0, x1]:
			var c: = Vector2(kx, y)
			draw_circle(c, h * 0.5 + 4.0, V10DS.GOLD_700, true, -1.0, true)
			draw_arc(c, h * 0.5 + 1.5, PI * 1.1, PI * 1.9, 16, Color(V10DS.GOLD_300, 0.7), 1.5, true)
			draw_circle(c, h * 0.18, Color(V10DS.NIGHT_900, 0.5), true, -1.0, true)


# the list's lower edge melts into the lacquer instead of a hard cut
class _Fade extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c0: = Color(V10TowerUI.LACQUER, 0.0)
		var c1: = V10TowerUI.LACQUER
		draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]), PackedColorArray([c0, c0, c1, c1]))


# ---------------------------------------------------------------- one curse card

class _Row extends Control:
	var s: V10CurseScroll
	var id: = ""
	var cells: Array = []
	var seal: Control
	var name_l: Label
	var tag_l: Label
	var desc_l: Label
	var _h: = V10CurseScroll.ROW_H
	var _grey: = false
	var _tw: Tween

	func build() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS
		clip_contents = true
		custom_minimum_size = Vector2(672, V10CurseScroll.ROW_H)
		size_flags_horizontal = Control.SIZE_FILL
		var n: = (V10ModsData.CURSES[id].levels as Array).size()
		seal = V10TowerUI.art_or("curse_" + id, Vector2(56, 56), func(ci: CanvasItem, sz: Vector2) -> void:
			V10CurseScroll.draw_curse_seal(ci, sz * 0.5, 26.0, id, _grey))
		seal.position = Vector2(12, 12)
		add_child(seal)
		var name_w: = 672.0 - 84.0 - (n + 1) * V10CurseScroll.CELL - 12.0
		name_l = V10TowerUI.label(V10TowerUI.ui_text(String(V10ModsData.CURSES[id].name)), "ui", 22, V10DS.PAPER_100)
		name_l.position = Vector2(84, 10)
		name_l.size = Vector2(name_w, 32)
		add_child(name_l)
		tag_l = V10TowerUI.label("", "ui", 18, V10DS.PAPER_500)
		tag_l.position = Vector2(84, 42)
		tag_l.size = Vector2(name_w, 26)
		add_child(tag_l)
		desc_l = V10TowerUI.label("", "ui", 18, V10DS.PAPER_300)
		desc_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_l.max_lines_visible = 2
		desc_l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		desc_l.position = Vector2(84, V10CurseScroll.ROW_H - 4.0)
		desc_l.size = Vector2(672.0 - 84.0 - 24.0, V10CurseScroll.DESC_H)
		add_child(desc_l)
		for lv in n + 1:
			var c: = _Cell.new()
			c.row = self
			c.lvl = lv
			c.text = V10CurseScroll.ROMAN[lv]
			c.position = Vector2(672.0 - 12.0 - (n + 1 - lv) * V10CurseScroll.CELL, 0)
			c.size = Vector2(V10CurseScroll.CELL, V10CurseScroll.CELL)
			add_child(c)
			cells.append(c)

	func sync(animate: bool) -> void:
		var lv: = int(s.curses.get(id, 0))
		_grey = s.blocked(id)
		var open: = s.touched == id and not _grey
		var a: = 0.5 if _grey else 1.0
		name_l.label_settings = V10Type.settings("ui", 22, Color(V10DS.PAPER_100, a))
		if _grey:
			tag_l.text = V10ModsData.SAFE_TEXT
			tag_l.label_settings = V10Type.settings("ui", 18, V10DS.PAPER_500)
		elif lv > 0:
			tag_l.text = "+%d Жара" % V10Mods.curse_heat(id, lv)
			tag_l.label_settings = V10Type.settings("ui", 18, V10DS.GOLD_300)
		else:
			var lvls: Array = V10ModsData.CURSES[id].levels
			var lo: = int(lvls[0].heat)
			var hi: = int(lvls[lvls.size() - 1].heat)
			tag_l.text = ("+%d Жара" % lo) if lo == hi else ("+%d…%d Жара" % [lo, hi])
			tag_l.label_settings = V10Type.settings("ui", 18, V10DS.PAPER_500)
		if open:
			if s.denied == id:
				desc_l.text = V10ModsData.SAFE_TEXT
			else:
				desc_l.text = V10TowerUI.ui_text(String(V10Mods.curse_card(id, maxi(1, lv)).line))
		desc_l.visible = open
		for c in cells:
			(c as _Cell).sync(lv)
		seal.queue_redraw()
		var want: = V10CurseScroll.ROW_H + (V10CurseScroll.DESC_H if open else 0.0)
		if absf(want - _h) > 0.5:
			if _tw and _tw.is_valid():
				_tw.kill()
			if animate and not V10TowerUI.calm():
				_tw = create_tween()
				_tw.tween_method(_set_h, _h, want, 0.2).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
			else:
				_set_h(want)
		queue_redraw()

	func _set_h(h: float) -> void:
		_h = h
		custom_minimum_size = Vector2(672, h)
		queue_redraw()

	func _draw() -> void:
		var r: = Rect2(Vector2.ZERO, Vector2(672, _h))
		var fill: = V10TowerUI.LACQUER_HI if not _grey else V10DS.NIGHT_700
		V10Plate.draw_surface(self, r, false, false, s.touched == id and not _grey, _grey, false, -1.0, fill)


class _Cell extends Control:
	var row: _Row
	var lvl: = 0
	var text: = ""
	var _sel: = false
	var _ok: = true
	var _down: = false
	var _l: Label

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		set_meta("tw_tap", true)
		_l = Label.new()
		_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(_l)

	func sync(cur: int) -> void:
		_sel = cur == lvl
		_ok = lvl == 0 or row.s.allowed(row.id, lvl) or _sel
		_l.text = text
		var col: = V10DS.GOLD_300 if _sel else (V10DS.PAPER_300 if _ok else Color(V10DS.PAPER_700, 0.7))
		_l.label_settings = V10Type.settings("ui", 22, col)
		_l.position = Vector2.ZERO
		_l.size = Vector2(V10CurseScroll.CELL, V10CurseScroll.CELL)
		queue_redraw()

	func _draw() -> void:
		var c: = size * 0.5
		var r: = Rect2(c - Vector2(30, 22), Vector2(60, 44))
		if _down:
			draw_rect(r, Color(V10DS.NIGHT_600, 0.7))
		if _sel:
			var sb: = StyleBoxFlat.new()
			sb.bg_color = Color(V10DS.NIGHT_900, 0.55)
			sb.set_corner_radius_all(V10DS.RADIUS)
			draw_style_box(sb, r)
			draw_line(Vector2(r.position.x + 12.0, r.end.y - 1.0), Vector2(r.end.x - 12.0, r.end.y - 1.0), V10DS.GOLD_500, 2.0)
		elif not _ok:
			draw_line(c + Vector2(-14, 10), c + Vector2(14, -10), Color(V10DS.PAPER_700, 0.6), 1.5, true)

	func _gui_input(e: InputEvent) -> void:
		if (e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT) or e is InputEventScreenTouch:
			if e.pressed:
				_down = true
				queue_redraw()
			elif _down:
				_down = false
				queue_redraw()
				if Rect2(Vector2.ZERO, size).grow(8).has_point(e.position):
					press()
			accept_event()

	func press() -> void:
		var s: = row.s
		var cur: = int(s.curses.get(row.id, 0))
		if lvl == cur:
			s.touched = row.id
			s.denied = ""
			s._refresh(true)
			return
		if s.set_level(row.id, lvl):
			scale = Vector2.ONE
			V10TowerUI.tap(self, "pop")


# ---------------------------------------------------------------- the seals: cinnabar stamp + a monoline sign

static func draw_curse_seal(ci: CanvasItem, c: Vector2, r: float, id: String, grey: = false) -> void:
	V10TowerUI.draw_seal(ci, c, r, V10DS.PAPER_700 if grey else V10TowerUI.SEAL)
	var ink: = Color(V10DS.PAPER_100, 0.6 if grey else 0.95)
	var w: = 2.5
	var s: = r * 0.62
	match id:
		"shroud":
			var rc: = Rect2(c - Vector2(s * 0.6, s * 0.8), Vector2(s * 1.2, s * 1.6))
			ci.draw_rect(rc, ink, false, w)
			for k in 3:
				var o: = -s * 0.5 + k * s * 0.5
				ci.draw_line(Vector2(rc.position.x, c.y + o - s * 0.3), Vector2(rc.end.x, c.y + o + s * 0.3), Color(ink, 0.7), 1.5, true)
		"hourglass":
			ci.draw_line(c + Vector2(-s * 0.7, -s), c + Vector2(s * 0.7, -s), ink, w, true)
			ci.draw_line(c + Vector2(-s * 0.7, s), c + Vector2(s * 0.7, s), ink, w, true)
			ci.draw_polyline(PackedVector2Array([c + Vector2(-s * 0.5, -s), c + Vector2(s * 0.5, s), c + Vector2(-s * 0.5, s), c + Vector2(s * 0.5, -s)]), ink, w, true)
		"greedy":
			for k in 3:
				var o: = Vector2(-s * 0.35 + k * s * 0.35, -s * 0.35 + k * s * 0.35)
				ci.draw_rect(Rect2(c + o - Vector2(s * 0.45, s * 0.55), Vector2(s * 0.9, s * 1.1)), ink, false, w)
		"narrow":
			var tr: = Rect2(c - Vector2(s, s * 0.45), Vector2(s * 2.0, s * 0.9))
			ci.draw_rect(tr, ink, false, w)
			for k in [1, 2]:
				var x: float = tr.position.x + tr.size.x * float(k) / 3.0
				ci.draw_line(Vector2(x, tr.position.y), Vector2(x, tr.end.y), ink, 1.5)
			ci.draw_line(Vector2(tr.end.x - s * 0.55, tr.position.y + 4.0), Vector2(tr.end.x - 4.0, tr.end.y - 4.0), ink, w, true)
		"one_lamp":
			var pts: = PackedVector2Array()
			for i in 25:
				var a: = TAU * float(i) / 24.0
				pts.append(c + Vector2(cos(a) * s * 0.55, sin(a) * s * 0.7))
			ci.draw_polyline(pts, ink, w, true)
			ci.draw_line(c + Vector2(-s * 0.3, -s * 0.85), c + Vector2(s * 0.3, -s * 0.85), ink, w, true)
			ci.draw_line(c + Vector2(-s * 0.3, s * 0.85), c + Vector2(s * 0.3, s * 0.85), ink, w, true)
			ci.draw_line(c + Vector2(0, -s * 0.7), c + Vector2(0, s * 0.7), Color(ink, 0.6), 1.5, true)
		"no_ult":
			var st: = PackedVector2Array()
			for i in 9:
				var a2: = -PI * 0.5 + TAU * float(i) / 8.0
				var rr: = s * (0.9 if i % 2 == 0 else 0.32)
				st.append(c + Vector2(cos(a2), sin(a2)) * rr)
			ci.draw_polyline(st, ink, w, true)
			_slash(ci, c, s, ink, w)
		"no_undo":
			V10Icons.draw(ci, "undo", c, s * 2.0, ink, w)
			_slash(ci, c, s, ink, w)
		"no_hint":
			V10Icons.draw(ci, "hint", c, s * 2.0, ink, w)
			_slash(ci, c, s, ink, w)
		"no_shuffle":
			V10Icons.draw(ci, "shuffle", c, s * 2.0, ink, w)
			_slash(ci, c, s, ink, w)
		"fog":
			for k in 3:
				var pts2: = PackedVector2Array()
				for i in 13:
					var t: = float(i) / 12.0
					pts2.append(c + Vector2(-s + t * s * 2.0, -s * 0.55 + k * s * 0.55 + sin(t * TAU) * s * 0.14))
				ci.draw_polyline(pts2, ink, w, true)
		"guards":
			for k in 3:
				var a3: = PI * float(k) / 3.0
				var d: = Vector2(cos(a3), sin(a3)) * s
				ci.draw_line(c - d, c + d, ink, w, true)
				for sgn in [-1.0, 1.0]:
					var tip: Vector2 = c + d * 0.62 * sgn
					var nrm: = Vector2(-d.y, d.x).normalized() * s * 0.22
					ci.draw_line(tip, tip + d.normalized() * s * 0.2 * sgn + nrm, ink, 1.5, true)
					ci.draw_line(tip, tip + d.normalized() * s * 0.2 * sgn - nrm, ink, 1.5, true)


static func _slash(ci: CanvasItem, c: Vector2, s: float, ink: Color, w: float) -> void:
	ci.draw_line(c + Vector2(-s, -s), c + Vector2(s, s), V10TowerUI.SEAL, w + 3.0, true)
	ci.draw_line(c + Vector2(-s, -s), c + Vector2(s, s), ink, w, true)
