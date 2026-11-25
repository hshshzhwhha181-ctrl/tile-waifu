class_name V10StreakSheet
extends Control

# «Календарь серии» bottom sheet (Р3, UX_RULES: main action «Понятно»; the leaf rule is on the sheet itself): 5 weeks of circles, milestones,
# the repair plate when the bowl is cold, the leaf rule. Opened by a tap on V10StreakChip / the lantern «Серия».
#   V10StreakSheet.open(parent, key = today) -> V10StreakSheet       signal closed

signal closed

const SHEET_H: = 1010.0
const MILES: = [3, 7, 14, 30, 60, 100, 365]
const MILE_ICON: = {3: "gems", 7: "gems", 14: "tickets", 30: "frame", 60: "frame", 100: "badge", 365: "title"}

var _sheet: Control
var _key: = ""


static func open(parent: Control, key: = "") -> V10StreakSheet:
	var s: = V10StreakSheet.new()
	s._key = key if key != "" else V10RitClock.day_key()
	s.size = parent.size
	parent.add_child(s)
	return s


func _ready() -> void:
	var W: = size.x
	var H: = size.y
	var sc: = V10RitUI.scrim(size, 0.0)
	sc.mouse_filter = Control.MOUSE_FILTER_STOP
	sc.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			close())
	add_child(sc)
	create_tween().tween_property(sc, "color:a", 0.62, 0.24)
	var sh_h: = minf(SHEET_H, H - 80)
	_sheet = Control.new()
	_sheet.size = Vector2(W, sh_h)
	_sheet.position = Vector2(0, H)
	_sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_sheet)
	var bgp: = V10RitUI.panel(Rect2(0, 0, W, sh_h + 40), V10RitUI.NIGHT800, 4)
	_sheet.add_child(bgp)
	_sheet.add_child(V10RitUI.panel(Rect2(W * 0.5 - 32, 12, 64, 5), V10RitUI.NIGHT600, 3))
	var v: = V10Streak.view(_key)
	var M: = 32.0
	var items: = []
	var over: = V10RitUI.label("Серия чая", 15, V10RitUI.GOLD500, "over")
	over.position = Vector2(M, 36)
	_sheet.add_child(over)
	items.append(over)
	var bowl: = V10RitUI.tex(V10RitUI.ART + "bowl.webp", Rect2(M - 6, 62, 96, 90))
	if v.state == "cold":
		bowl.modulate = V10StreakChip.COLD_TINT
	_sheet.add_child(bowl)
	items.append(bowl)
	var n: int = int(v.n)
	var h1: = V10RitUI.label("%d %s" % [n, V10RitLines.plural(n, "день", "дня", "дней")], 44, V10RitUI.PAPER100, "title", 700)
	h1.position = Vector2(M + 104, 64)
	_sheet.add_child(h1)
	var best: = V10RitUI.label("Лучшая серия: %d" % int(v.best), 18, V10RitUI.PAPER500)
	best.position = Vector2(M + 106, 122)
	_sheet.add_child(best)
	items.append(h1)
	# leaves at the right edge
	var lv_box: = Control.new()
	lv_box.position = Vector2(W - M - 132, 72)
	_sheet.add_child(lv_box)
	for i in V10Streak.LEAF_MAX:
		var lf: = V10RitUI.tex(V10RitUI.ART + "leaf.webp", Rect2(i * 52, 0, 46, 50))
		if i >= int(v.leaves):
			lf.modulate = Color(0.3, 0.3, 0.3, 0.45)
		lv_box.add_child(lf)
	var lvl: = V10RitUI.label("Листья %d/%d" % [int(v.leaves), V10Streak.LEAF_MAX], 18, V10RitUI.PAPER500)
	lvl.position = Vector2(0, 54)
	lv_box.add_child(lvl)
	var y: = 170.0
	# repair plate
	if not (v.repair as Dictionary).is_empty():
		var rp: Dictionary = v.repair
		var plate: = V10RitUI.panel(Rect2(M, y, W - 2 * M, 84), Color(V10RitUI.FROST, 0.12), 4, Color(V10RitUI.FROST, 0.45), 1)
		_sheet.add_child(plate)
		var pl: = V10RitUI.label(str(rp.text), 18, V10RitUI.PAPER100, "body", 800)
		pl.position = Vector2(20, 14)
		plate.add_child(pl)
		for i in int(rp.need):
			var pip: = V10RitUI.panel(Rect2(20 + i * 34, 50, 24, 24), V10RitUI.GOLD500 if i < int(rp.got) else Color(0, 0, 0, 0), 12, V10RitUI.FROST, 2)
			plate.add_child(pip)
		var why: = V10RitUI.label("сверх обычной победы дня", 18, V10RitUI.PAPER500)
		why.position = Vector2(20 + int(rp.need) * 34 + 8, 50)
		plate.add_child(why)
		items.append(plate)
		y += 104
	# calendar
	var cal: = V10Streak.calendar(_key)
	var cw: = (W - 2 * M) / 7.0
	for i in 7:
		var wd: = V10RitUI.label(V10RitClock.WD_SHORT[i], 18, V10RitUI.PAPER500 if i < 5 else V10RitUI.ROSE300)
		wd.position = Vector2(M + i * cw, y)
		wd.size = Vector2(cw, 24)
		wd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_sheet.add_child(wd)
	y += 34
	var grid: = Control.new()
	grid.position = Vector2(M, y)
	_sheet.add_child(grid)
	for i in cal.size():
		var c: Dictionary = cal[i]
		var cell: = _cell(c, cw)
		cell.position = Vector2((i % 7) * cw, (i / 7) * 64)
		grid.add_child(cell)
		if V9Feel.can_fx():
			cell.modulate.a = 0.0
			cell.create_tween().tween_property(cell, "modulate:a", 1.0, 0.2).set_delay(0.18 + 0.012 * i)
	y += 5 * 64 + 10
	# milestones
	var ml: = V10RitUI.label("Рубежи", 15, V10RitUI.GOLD500, "over")
	ml.position = Vector2(M, y)
	_sheet.add_child(ml)
	y += 28
	var mw: = (W - 2 * M - 6 * 10) / 7.0
	var got: Array = V10Streak.st().got
	for i in MILES.size():
		var m: int = MILES[i]
		var done: = m in got
		var nxt: = m == int(v.next)
		var card: = V10RitUI.panel(Rect2(M + i * (mw + 10), y, mw, 100), V10RitUI.NIGHT700, 12,
			V10RitUI.GOLD500 if nxt else Color(V10RitUI.GOLD700, 0.35), 2 if nxt else 1)
		_sheet.add_child(card)
		var ic: = V10RitUI.tex(str(V10RitBridge.ICONS.get(MILE_ICON[m], "")), Rect2(mw * 0.2, 10, mw * 0.6, mw * 0.6))
		if not done and not nxt:
			ic.modulate = Color(1, 1, 1, 0.45)
		card.add_child(ic)
		var ln: = V10RitUI.label(str(m), 18, V10RitUI.GOLD300 if (done or nxt) else V10RitUI.PAPER500, "num")
		ln.position = Vector2(0, 64)
		ln.size = Vector2(mw, 30)
		ln.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(ln)
		if done:
			var hk: = V10RitUI.hanko(card, Vector2(mw - 14, 18), "✓", 30)
			hk.modulate.a = 1.0
	y += 114
	# UX_RULES §9 P1-17: the promise of the removed «Визиты» screen lives on in the Серия
	var keep: = V10RitUI.wrap_w(V10RitUI.label(V10Streak.KEEP_TEXT + ".", 18, V10RitUI.GOLD300, "body", 800), W - 2 * M)
	keep.position = Vector2(M, y)
	_sheet.add_child(keep)
	y += 34
	var rule: = V10RitUI.wrap_w(V10RitUI.label(V10Streak.RULE_TEXT + ".", 18, V10RitUI.PAPER500, "body", 700), W - 2 * M)
	rule.position = Vector2(M, y)
	_sheet.add_child(rule)
	y += 84
	# the sheet is as tall as its content (the repair plate adds a row)
	sh_h = minf(y + 136, H - 40)
	_sheet.size.y = sh_h
	bgp.size.y = sh_h + 40
	var ok: = V10RitUI.button("Понятно", Rect2((W - 560) * 0.5, sh_h - 124, 560, 104), "primary", close)
	ok.breathing = false
	_sheet.add_child(ok)
	V10RitUI.inhale(items, 0.2)
	var t: = _sheet.create_tween()
	t.tween_property(_sheet, "position:y", H - sh_h, 0.24 if V9Feel.can_fx() else 0.12).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	V10RitUI.sfx("paper_fan", "whoosh", 1.2, -12.0)


func _cell(c: Dictionary, cw: float) -> Control:
	var box: = Control.new()
	box.size = Vector2(cw, 62)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var r: = 25.0
	var ctr: = Vector2(cw * 0.5, 28)
	var stt: = str(c.state)
	var fill: = Color(0, 0, 0, 0)
	var ring: = Color(V10RitUI.PAPER700, 0.5)
	var bw: = 2
	var txt_col: = V10RitUI.PAPER500
	match stt:
		"win":
			fill = V10RitUI.JADE500
			ring = V10RitUI.JADE300
			txt_col = V10RitUI.NIGHT900
		"warm":
			fill = Color(V10RitUI.GOLD500, 0.85)
			ring = V10RitUI.GOLD300
			txt_col = V10RitUI.NIGHT900
		"leaf":
			fill = Color(V10RitUI.JADE500, 0.25)
			ring = V10RitUI.JADE300
		"miss":
			ring = Color(V10RitUI.FROST, 0.55)
			txt_col = V10RitUI.FROST
		"today":
			ring = V10RitUI.ROSE500
			bw = 3
			txt_col = V10RitUI.PAPER100
		"future":
			ring = Color(V10RitUI.PAPER700, 0.18)
			txt_col = Color(V10RitUI.PAPER700, 0.6)
	var circ: = V10RitUI.panel(Rect2(ctr - Vector2(r, r), Vector2(r, r) * 2), fill, int(r), ring, bw)
	box.add_child(circ)
	if stt == "leaf":
		box.add_child(V10RitUI.tex(V10RitUI.ART + "leaf.webp", Rect2(ctr - Vector2(18, 20), Vector2(36, 40))))
	else:
		var d: = V10RitUI.label(str(c.day), 18, txt_col, "num")
		d.size = Vector2(r, r) * 2
		d.position = ctr - Vector2(r, r)
		d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		d.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		box.add_child(d)
	return box


func close() -> void:
	var t: = create_tween()
	t.tween_property(_sheet, "position:y", size.y, 0.2).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(self, "modulate:a", 0.0, 0.22)
	t.tween_callback(func():
		closed.emit()
		queue_free())
