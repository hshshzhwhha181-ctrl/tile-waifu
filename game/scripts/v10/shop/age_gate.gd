class_name V10AgeGate
extends Control

# V10AgeGate — the neutral age screen (spec 0.10 Л2, UX Г-2, HANDOFF §1). Shown once at first start (after the
# splash, before login/tutorial) and before any 18+ delta (V10Age.bold_ok). Lacquer doors at night, a birth-YEAR
# drum with nothing pre-selected; the button reads «Мне есть 18 · войти» only when the picked year is adult.
# Too young for this build → a calm stop screen «Эта версия игры — для 18+», no retry loop, no hint what to pick.
#
#   var g := V10AgeGate.make(st, now_unix); g.done.connect(func(band): …)   # band: "adult" | "teen"

signal done(band: String)

var st: Dictionary
var now_unix: = 0
var drum: Drum
var btn: V10Button
var vs: = Vector2(720, 1280)


static func make(state: Dictionary, now: int) -> V10AgeGate:
	var g: = V10AgeGate.new()
	g.st = state
	g.now_unix = now
	g.name = "V10AgeGate"
	return g


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	build()


func build() -> void:
	for c in get_children():
		c.queue_free()
	vs = get_viewport_rect().size
	size = vs
	var ins: = V10Hud2Util.safe_insets(vs)
	var t: = V10ShopKit.tex("bg_age")
	if t:
		add_child(V10ShopKit.art(t, Rect2(Vector2.ZERO, vs), true))
	var sh: = V10Shop2.Shade.new()
	sh.size = vs
	add_child(sh)
	var cw: = minf(vs.x, 720.0) - 64.0
	var cx: = (vs.x - cw) * 0.5
	# text block in the lower half (the doors keep the upper half, «обложка журнала»)
	var y: = maxf(vs.y * 0.40, float(ins.top) + 380.0)
	var ov: = V10ShopKit.lbl("ЧАЙНАЯ «ПЯТЬ ВЕТРОВ» · 18+", "overline", 15, V10DS.GOLD_500, true)
	ov.position = Vector2(cx, y)
	ov.size = Vector2(cw, 20)
	add_child(ov)
	y += 28
	var h: = V10ShopKit.lbl("Год рождения", "display", 44, V10DS.PAPER_100, true)
	h.position = Vector2(cx, y)
	h.size = Vector2(cw, 56)
	add_child(h)
	y += 64
	var body: = V10ShopKit.wrap(V10ShopKit.lbl("В игре есть флирт и откровенные наряды. Укажи год рождения — от него зависят доступ и лимиты покупок. Год остаётся только на этом телефоне.", "ui", 22, V10DS.PAPER_300, true), 4)
	body.position = Vector2(cx, y)
	var lines: = V10Type.lines_needed(body.text, "ui", 22, cw)
	body.size = Vector2(cw, 32 * mini(lines, 4))
	add_child(body)
	y += body.size.y + 24
	var dh: = clampf(vs.y - y - 104 - 48 - float(ins.bottom) - 40, 200.0, 300.0)
	drum = Drum.new()
	drum.name = "Drum"
	drum.years = V10Age.years(now_unix)
	drum.position = Vector2(cx, y)
	drum.size = Vector2(cw, dh)
	drum.picked.connect(_on_pick)
	add_child(drum)
	y += dh + 24
	btn = V10Button.make("play", V10Age.confirm_text(0, now_unix), Vector2(minf(560.0, cw), 104))
	btn.name = "Confirm"
	btn.position = Vector2((vs.x - btn.btn_size.x) * 0.5, minf(y, vs.y - float(ins.bottom) - 104 - 32))
	btn.set_meta("ux_role", "primary")
	btn.modulate.a = 0.45
	btn.breathing = false
	btn.sheen = false
	btn.pressed.connect(_confirm)
	add_child(btn)


func _on_pick(year: int) -> void:
	btn.text = V10Age.confirm_text(year, now_unix)
	btn.modulate.a = 1.0 if year > 0 else 0.45
	btn.breathing = year > 0


func _confirm() -> void:
	var y: = drum.year()
	if y <= 0:
		V10ShopKit.deny(btn)
		return
	V10ShopKit.press(btn, true)
	var band: = V10Age.set_year(st, y, now_unix)
	if not V10Age.allowed(y, now_unix):
		_stop()
		return
	done.emit(band)


func _stop() -> void:
	for c in get_children():
		c.queue_free()
	var t: = V10ShopKit.tex("bg_age")
	if t:
		add_child(V10ShopKit.art(t, Rect2(Vector2.ZERO, vs), true))
	var sh: = V10Shop2.Shade.new()
	sh.size = vs
	add_child(sh)
	var cw: = minf(vs.x, 720.0) - 64.0
	var cx: = (vs.x - cw) * 0.5
	var h: = V10ShopKit.lbl("Эта версия игры — для %d+" % V10Age.min_age(), "display", 44, V10DS.PAPER_100, true)
	V10Type.fit(h, h.text, "title_l", cw, 1, V10DS.PAPER_100, true)
	h.position = Vector2(cx, vs.y * 0.5)
	h.size = Vector2(cw, 56)
	h.name = "Stop"
	add_child(h)
	var b: = V10ShopKit.wrap(V10ShopKit.lbl("Спасибо, что честно. Возвращайся, когда исполнится %d." % V10Age.min_age(), "ui", 22, V10DS.PAPER_300, true), 2)
	b.position = Vector2(cx, vs.y * 0.5 + 72)
	b.size = Vector2(cw, 64)
	add_child(b)
	done.emit("child")


# a birth-year drum: nothing selected until the finger moves it; snaps to rows; 5 rows visible
class Drum:
	extends Control
	signal picked(year: int)
	var years: Array = []
	var off: = -1.0          # row index under the centre line; -1 = untouched (placeholder)
	var _drag: = false
	var _y0: = 0.0
	var _o0: = 0.0
	var row_h: = 56.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		clip_contents = true
		set_meta("v10_tap", true)
		set_meta("ux_role", "input")

	func year() -> int:
		if off < 0.0 or years.is_empty():
			return 0
		return int(years[clampi(roundi(off), 0, years.size() - 1)])

	func set_year(y: int) -> void:
		var i: = years.find(y)
		if i >= 0:
			off = float(i)
			queue_redraw()
			picked.emit(year())

	func _gui_input(e: InputEvent) -> void:
		if (e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT) or e is InputEventScreenTouch:
			if e.pressed:
				_drag = true
				_y0 = e.position.y
				if off < 0.0:
					off = 12.0      # first touch wakes the drum on a CHILD year: an adult year is never pre-selected (neutral gate)
				_o0 = off
			else:
				_drag = false
				_snap()
			accept_event()
		elif e is InputEventMouseButton and e.pressed and e.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			if off < 0.0:
				off = 12.0
			off = clampf(off + (1.0 if e.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1.0), 0, years.size() - 1)
			_snap()
			accept_event()
		elif (e is InputEventMouseMotion and _drag) or e is InputEventScreenDrag:
			off = clampf(_o0 - (e.position.y - _y0) / row_h, 0.0, float(years.size() - 1))
			queue_redraw()
			accept_event()

	func _snap() -> void:
		var target: = roundf(off)
		var tw: = create_tween()
		tw.tween_method(func(v: float):
			off = v
			queue_redraw(), off, target, 0.16).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		tw.tween_callback(func():
			V9Feel.haptic("select")
			picked.emit(year()))

	func _draw() -> void:
		var c: = size.y * 0.5
		V10Plate.draw_surface(self, Rect2(0, c - row_h * 0.5, size.x, row_h), false, false, true, false, false, -1.0, V10DS.NIGHT_700)
		var f: = V10Type.font("num")
		if off < 0.0:
			var ph: = "— — — —"
			var w0: = f.get_string_size(ph, HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x
			draw_string(f, Vector2((size.x - w0) * 0.5, c + 11), ph, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, V10DS.PAPER_500)
			var hint: = "листай вверх или вниз"
			var hf: = V10Type.font("ui")
			var wh: = hf.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
			draw_string(hf, Vector2((size.x - wh) * 0.5, c + row_h + 8), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, V10DS.PAPER_500)
			return
		var first: = int(floor(off - c / row_h)) - 1
		var last: = int(ceil(off + c / row_h)) + 1
		for i in range(maxi(0, first), mini(years.size(), last + 1)):
			var dy: = (float(i) - off) * row_h
			var k: = clampf(1.0 - absf(dy) / (c + 1.0), 0.0, 1.0)
			var sz: = int(lerpf(22.0, 40.0, k * k))
			var s: = str(years[i])
			var w: = f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
			var col: = V10DS.GOLD_300.lerp(V10DS.PAPER_500, clampf(absf(dy) / row_h, 0.0, 1.0))
			col.a = 0.25 + 0.75 * k
			draw_string(f, Vector2((size.x - w) * 0.5, c + dy + sz * 0.36), s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)
