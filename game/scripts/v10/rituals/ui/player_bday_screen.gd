class_name V10PlayerBdayScreen
extends Control

# Player's birthday (Р7, 152-ФЗ). Step 1: the partner's letter with two EQUAL buttons «Рассказать» / «Не хочу
# говорить». Step 2: consent — a separate tick with the purpose text, month/day drums (no year), «Сохранить» only
# with the tick. Step 3: her answer («Записала!» or «Отпразднуем в следующем году»).
#   V10PlayerBdayScreen.open(parent, start_step = "ask", key = today) -> screen     signal closed(result)

signal closed(result: Dictionary)

var step: = "ask"
var key: = ""
var h: = "mc"
var _consent: = false
var _tick: Panel
var _tick_mark: Label
var _save: Button
var _m_drum: Drum
var _d_drum: Drum
var _body: Control


# a vertical wheel: snaps to rows, the centre row is gold, rows fade towards the edges
class Drum extends Control:
	signal changed(i: int)
	var items: = []
	var row_h: = 64.0
	var sel: = 0
	var _off: = 0.0
	var _drag: = false
	var _vel: = 0.0
	var _last_y: = 0.0
	var _labels: = []

	func setup(list: Array, start: int) -> void:
		items = list
		sel = clampi(start, 0, list.size() - 1)
		_off = sel * row_h
		for l in _labels:
			l.queue_free()
		_labels = []
		for i in items.size():
			var l: = V10RitUI.label(str(items[i]), 30, V10RitUI.PAPER100, "body", 800)
			l.size = Vector2(size.x, row_h)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			add_child(l)
			_labels.append(l)
		_layout()

	func _ready() -> void:
		clip_contents = true
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _layout() -> void:
		var mid: = size.y * 0.5 - row_h * 0.5
		for i in _labels.size():
			var l: Label = _labels[i]
			var y: = mid + i * row_h - _off
			l.position = Vector2(0, y)
			var d: = absf(y - mid) / (size.y * 0.5)
			l.modulate = Color(1, 1, 1, clampf(1.0 - d * 0.9, 0.08, 1.0))
			l.label_settings.font_color = V10RitUI.GOLD300 if i == sel else V10RitUI.PAPER300
			l.scale = Vector2.ONE

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			_drag = e.pressed
			_last_y = e.position.y
			if not e.pressed:
				_snap()
		elif e is InputEventMouseMotion and _drag:
			var dy: float = e.position.y - _last_y
			_last_y = e.position.y
			_off = clampf(_off - dy, -row_h * 0.4, (items.size() - 1 + 0.4) * row_h)
			var ns: = clampi(int(round(_off / row_h)), 0, items.size() - 1)
			if ns != sel:
				sel = ns
				V9Feel.haptic("select")
				V9Feel.sound("select", 1.0 + 0.02 * (sel % 5), -10.0)
			_layout()
		elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			set_index(sel + 1)
		elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_WHEEL_UP:
			set_index(sel - 1)

	func _snap() -> void:
		set_index(clampi(int(round(_off / row_h)), 0, items.size() - 1))

	func set_index(i: int) -> void:
		sel = clampi(i, 0, items.size() - 1)
		var t: = create_tween()
		t.tween_method(func(v: float):
			_off = v
			_layout(), _off, sel * row_h, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		changed.emit(sel)


static func open(parent: Control, start: = "ask", key_in: = "") -> V10PlayerBdayScreen:
	var s: = V10PlayerBdayScreen.new()
	s.step = start
	s.key = key_in if key_in != "" else V10RitClock.day_key()
	s.h = V10RitBridge.partner()
	s.size = parent.size
	parent.add_child(s)
	return s


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(V10RitUI.panel(Rect2(Vector2.ZERO, size), V10RitUI.NIGHT900, 0))
	_show(step)


func _clear() -> void:
	if _body:
		_body.queue_free()
	_body = Control.new()
	_body.size = size
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_body)


func _show(s: String) -> void:
	step = s
	_clear()
	match s:
		"ask":
			_ask()
		"consent":
			_consent_step()
		_:
			_answer(s)


func _ask() -> void:
	var W: = size.x
	var M: = 32.0
	var p: = TextureRect.new()
	p.texture = V10RitBridge.portrait(h)
	p.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	p.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	p.size = Vector2(720 * 848.0 / 1264.0, 720)
	# 9:20 and taller: the letter and its buttons move down with the extra height (buttons in the lower third)
	var ex: = maxf(0.0, size.y - 1280.0) * 0.5
	p.position = Vector2(W - p.size.x + 60, 90 + ex)
	p.modulate = Color(0.85, 0.82, 0.84)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_child(p)
	_body.add_child(V10RitUI.grad(Rect2(0, 420 + ex, W, size.y - 420 - ex), Color(V10RitUI.NIGHT900, 0), V10RitUI.NIGHT900))
	var over: = V10RitUI.label("Письмо · %s" % V10RitBridge.short_name(h), 15, V10RitUI.GOLD500, "over")
	over.position = Vector2(M, 120)
	_body.add_child(over)
	var paper: = V10RitUI.panel(Rect2(M, 640 + ex, W - 2 * M, 250), V10RitUI.WASHI, 4)
	_body.add_child(paper)
	var txt: = V10RitUI.wrap_w(V10RitUI.label(V10RitLines.pick("ask_bday", h, 0), 38, V10RitUI.INK, "hand"), W - 2 * M - 56)
	txt.label_settings.shadow_color = Color(0, 0, 0, 0)
	txt.position = Vector2(28, 26)
	paper.add_child(txt)
	var sign: = V10RitUI.label("— " + V10RitBridge.short_name(h), 32, V10RitUI.INK_SIGN, "hand")
	sign.label_settings.shadow_color = Color(0, 0, 0, 0)
	sign.position = Vector2(28, 186)
	sign.size.x = W - 2 * M - 56
	sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	paper.add_child(sign)
	# two buttons of EQUAL weight (152-ФЗ: refusing is as easy as agreeing)
	var bw: = (W - 2 * M - 16) * 0.5
	var b1: = V10RitUI.button("Рассказать", Rect2(M, 930 + ex, bw, 96), "secondary", func(): _show("consent"))
	var b2: = V10RitUI.button("Не хочу говорить", Rect2(M + bw + 16, 930 + ex, bw, 96), "secondary", func():
		V10PlayerBday.decline()
		_show("declined"))
	for b in [b1, b2]:
		b.set_meta("ux_role", "equal_choice")
		_body.add_child(b)
	V10RitUI.inhale([over, paper, b1, b2], 0.1)


func _consent_step() -> void:
	var W: = size.x
	var M: = 32.0
	var over: = V10RitUI.label("Мой день рождения", 15, V10RitUI.GOLD500, "over")
	over.position = Vector2(M, 64)
	_body.add_child(over)
	var h1: = V10RitUI.label("Когда тебя поздравить?", 44, V10RitUI.PAPER100, "title", 700)
	h1.position = Vector2(M, 90)
	_body.add_child(h1)
	var purpose: = V10RitUI.wrap_w(V10RitUI.label(V10PlayerBday.PURPOSE, 22, V10RitUI.PAPER300, "body", 700), W - 2 * M)
	purpose.position = Vector2(M, 160)
	_body.add_child(purpose)
	# drums: day | month (no year)
	# 9:20 and taller: the drums move down a little, the consent row and the buttons sit in the lower third
	var ex: = maxf(0.0, size.y - 1280.0)
	var dy: = 270.0 + ex * 0.3
	var band: = V10RitUI.panel(Rect2(M, dy + 160 - 34, W - 2 * M, 68), Color(V10RitUI.GOLD500, 0.08), 4, Color(V10RitUI.GOLD700, 0.5), 1)
	_body.add_child(band)
	_d_drum = Drum.new()
	_d_drum.size = Vector2(200, 320)
	_d_drum.position = Vector2(M + 40, dy)
	_body.add_child(_d_drum)
	_m_drum = Drum.new()
	_m_drum.size = Vector2(330, 320)
	_m_drum.position = Vector2(W - M - 370, dy)
	_body.add_child(_m_drum)
	var months: = []
	for i in 12:
		months.append(V10RitClock.MONTHS_GEN[i])
	var md: = V10RitClock.md(key)
	_m_drum.setup(months, int(md[0]) - 1)
	_fill_days(int(md[0]), int(md[1]))
	_m_drum.changed.connect(func(i): _fill_days(i + 1, _d_drum.sel + 1))
	var dl: = V10RitUI.label("день", 15, V10RitUI.PAPER500, "over")
	dl.position = Vector2(M + 40, dy + 326)
	dl.size = Vector2(200, 20)
	dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.add_child(dl)
	var ml: = V10RitUI.label("месяц", 15, V10RitUI.PAPER500, "over")
	ml.position = Vector2(W - M - 370, dy + 326)
	ml.size = Vector2(330, 20)
	ml.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.add_child(ml)
	var noyear: = V10RitUI.label("Год не нужен — мы его не храним.", 18, V10RitUI.PAPER500)
	noyear.position = Vector2(M, dy + 362)
	_body.add_child(noyear)
	# separate consent tick
	var row: = Button.new()
	row.flat = true
	row.focus_mode = Control.FOCUS_NONE
	row.position = Vector2(M, 690 + ex * 0.6)
	row.size = Vector2(W - 2 * M, 110)
	row.add_theme_stylebox_override("normal", V10RitUI.box(Color(V10RitUI.PAPER100, 0.05), 4))
	row.add_theme_stylebox_override("hover", V10RitUI.box(Color(V10RitUI.PAPER100, 0.05), 4))
	row.add_theme_stylebox_override("pressed", V10RitUI.box(Color(V10RitUI.PAPER100, 0.1), 4))
	row.set_meta("ux_role", "consent")
	_body.add_child(row)
	_tick = V10RitUI.panel(Rect2(20, 31, 48, 48), Color(0, 0, 0, 0), 6, V10RitUI.GOLD500, 3)
	row.add_child(_tick)
	_tick_mark = V10RitUI.label("✓", 34, V10RitUI.NIGHT900, "num")
	_tick_mark.size = Vector2(48, 48)
	_tick_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tick_mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tick_mark.visible = false
	_tick.add_child(_tick_mark)
	var ct: = V10RitUI.wrap_w(V10RitUI.label("Разрешаю хранить день и месяц рождения, чтобы меня поздравили", 22, V10RitUI.PAPER100, "body", 700), row.size.x - 110)
	ct.position = Vector2(90, 20)
	row.add_child(ct)
	row.pressed.connect(func():
		_consent = not _consent
		V9Feel.press(_tick, "select", "select")
		_tick_mark.visible = _consent
		(_tick.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = V10RitUI.GOLD500 if _consent else Color(0, 0, 0, 0)
		_save.disabled = not _consent)
	_save = V10RitUI.button("Сохранить", Rect2((W - 560) * 0.5, 850 + ex, 560, 104), "primary", _do_save)
	_save.disabled = true
	_body.add_child(_save)
	var no: = V10RitUI.button("Не хочу говорить", Rect2((W - 560) * 0.5, 970 + ex, 560, 88), "secondary", func():
		V10PlayerBday.decline()
		_show("declined"))
	_body.add_child(no)
	V10RitUI.inhale([over, h1, purpose, row, _save], 0.0)


func _fill_days(m: int, want: int) -> void:
	var n: int = V10PlayerBday.MONTH_DAYS[clampi(m - 1, 0, 11)]
	var days: = []
	for i in n:
		days.append(str(i + 1))
	_d_drum.setup(days, mini(want, n) - 1)


func _do_save() -> void:
	if not _consent:
		V9Feel.deny(_save)
		return
	var r: = V10PlayerBday.set_date(_m_drum.sel + 1, _d_drum.sel + 1, _consent, key)
	if not r.ok:
		V9Feel.deny(_save)
		return
	V9Feel.success(_save, "sparkle")
	V10RitUI.hanko(_body, _save.position + Vector2(_save.size.x - 40, 10), "記", 64)
	var t: = create_tween()
	t.tween_interval(0.5)
	t.tween_callback(func(): _show("later" if r.later else "saved"))


func _answer(kind: String) -> void:
	var W: = size.x
	var group: String = {"saved": "bday_saved", "later": "bday_later", "declined": "bday_declined"}.get(kind, "bday_saved")
	var p: = TextureRect.new()
	p.texture = V10RitBridge.portrait(h)
	p.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	p.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	p.size = Vector2(980 * 848.0 / 1264.0, 980)
	p.position = Vector2(W - p.size.x + 170, size.y - 980 - 140)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_child(p)
	_body.add_child(V10RitUI.grad(Rect2(0, size.y * 0.6, W, size.y * 0.4), Color(V10RitUI.NIGHT900, 0), V10RitUI.NIGHT900))
	var vl: = V10RitUI.voice(_body, V10RitLines.pick(group, h, 0), Vector2(32, 130), 330, 40, 0.0)
	if kind != "declined" and V10PlayerBday.has_date():
		var d: = V10RitUI.label(V10RitClock.fmt_date(int(V10PlayerBday.st().m), int(V10PlayerBday.st().d)), 52, V10RitUI.GOLD300, "title", 700)
		d.position = Vector2(32, 410)
		_body.add_child(d)
		V10RitUI.inhale([d], 0.6)
	var ok: = V10RitUI.button("Хорошо", Rect2((W - 560) * 0.5, size.y - 150, 560, 104), "primary", func():
		closed.emit({"step": kind})
		queue_free())
	_body.add_child(ok)
