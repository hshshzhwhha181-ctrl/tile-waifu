class_name V10LadderScreen
extends Control

# «Лестница возвращения» (Р5): 7 steps (gap ≥ 14 days) or 3 (7–13). One step a day, a skipped day never burns.
# Main action «Забрать · день N»; the 10-ticket day carries «Шансы» (odds disclosure, V10OddsScreen hook H9).
#   V10LadderScreen.open(parent, key) -> screen        signals closed, odds_requested

signal closed
signal odds_requested

var _key: = ""
var _list: Control
var _btn: Button
var claim_fn: Callable = Callable()


static func open(parent: Control, key: = "") -> V10LadderScreen:
	var s: = V10LadderScreen.new()
	s._key = key if key != "" else V10RitClock.day_key()
	s.size = parent.size
	parent.add_child(s)
	return s


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


func _build() -> void:
	for c in get_children():
		c.queue_free()
	var W: = size.x
	var M: = 32.0
	add_child(V10RitUI.panel(Rect2(Vector2.ZERO, size), V10RitUI.NIGHT900, 0))
	var v: = V10Comeback.ladder_view(_key)
	if v.is_empty():
		return
	var head: = []
	var over: = V10RitUI.label("Лестница возвращения · %d %s" % [v.days.size(), V10RitLines.plural(v.days.size(), "день", "дня", "дней")], 15, V10RitUI.GOLD500, "over")
	over.position = Vector2(M, 48)
	add_child(over)
	head.append(over)
	var h1: = V10RitUI.label("С возвращением", 44, V10RitUI.PAPER100, "title", 700)
	h1.position = Vector2(M, 74)
	add_child(h1)
	head.append(h1)
	var sub: = V10RitUI.label("Одна ступень в день. Пропущенный день не сгорает.", 18, V10RitUI.PAPER500)
	sub.position = Vector2(M, 136)
	add_child(sub)
	head.append(sub)
	var close_b: = V10RitUI.button("✕", Rect2(W - M - 80, 32, 80, 80), "quiet", func():
		closed.emit()
		queue_free())
	add_child(close_b)
	var y0: = 190.0
	var avail: = size.y - y0 - 170
	var rh: = minf(112.0, avail / v.days.size())
	var rows: = []
	for d in v.days:
		var row: = _row(d, Rect2(M, y0 + int(d.i) * rh, W - 2 * M, rh - 10))
		add_child(row)
		rows.append(row)
	V10RitUI.inhale(head)
	V10RitUI.inhale(rows, 0.12)
	var ready_i: = int(v.claimed)
	var label: = "Забрать · день %d" % (ready_i + 1) if v.can else ("Всё собрано" if v.done else "Завтра · день %d" % (ready_i + 1))
	_btn = V10RitUI.button(label, Rect2((W - 560) * 0.5, size.y - 150, 560, 104), "primary", _claim)
	_btn.disabled = not v.can
	add_child(_btn)


func _row(d: Dictionary, r: Rect2) -> Control:
	var st: = str(d.state)
	var c: = Control.new()
	c.position = r.position
	c.size = r.size
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var is_ready: = st == "ready"
	var bg_col: = V10RitUI.NIGHT700 if st != "later" else V10RitUI.NIGHT800
	c.add_child(V10RitUI.panel(Rect2(Vector2.ZERO, r.size), bg_col, 4, V10RitUI.GOLD500 if is_ready else Color(V10RitUI.GOLD700, 0.3), 2 if is_ready else 1))
	var num: = V10RitUI.label(str(int(d.i) + 1), 44, V10RitUI.GOLD300 if st != "later" else V10RitUI.PAPER700, "num")
	num.position = Vector2(18, 0)
	num.size = Vector2(56, r.size.y)
	num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	c.add_child(num)
	var rows: = V10RitBridge.rows(d.rewards)
	var x: = 88.0
	var ih: = minf(56.0, r.size.y - 30)
	for rw in rows:
		var ic: = V10RitUI.tex(str(rw.icon), Rect2(x, (r.size.y - ih) * 0.5 - 8, ih, ih))
		if st == "later":
			ic.modulate = Color(1, 1, 1, 0.45)
		c.add_child(ic)
		var tl: = V10RitUI.label("×%d" % int(rw.n) if not (rw.kind in ["frame", "pick_outfit", "aff"]) else ("+%d" % int(rw.n) if rw.kind == "aff" else ""), 18, V10RitUI.PAPER100 if st != "later" else V10RitUI.PAPER700, "num")
		tl.position = Vector2(x, (r.size.y + ih) * 0.5 - 10)
		tl.size = Vector2(ih, 22)
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		c.add_child(tl)
		x += ih + 14
	var desc: = _desc(d.rewards)
	var dl: = V10RitUI.label(desc, 18, V10RitUI.PAPER300 if st != "later" else V10RitUI.PAPER700)
	dl.position = Vector2(x + 6, 0)
	dl.size = Vector2(r.size.x - x - 150, r.size.y)
	dl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c.add_child(dl)
	if int(d.rewards.get("tickets", 0)) > 0:
		# hit zone 80 (UX_RULES В-6); Caption size keeps the screen at 4 type sizes
		var ob: = V10RitUI.button("Шансы", Rect2(r.size.x - 140, (r.size.y - 80) * 0.5, 128, 80), "secondary", func(): odds_requested.emit())
		ob.add_theme_font_size_override("font_size", 18)
		c.add_child(ob)
	elif st == "done":
		var hk: = V10RitUI.hanko(c, Vector2(r.size.x - 50, r.size.y * 0.5), "受", 52)
		hk.modulate.a = 1.0
	return c


func _desc(r: Dictionary) -> String:
	if r.has("pick_outfit"):
		return "Наряд на выбор из прошлых фаз"
	if r.has("frame"):
		return "Рамка «Снова за столом» и симпатия"
	if int(r.get("tickets", 0)) > 0:
		return "%d %s" % [int(r.tickets), V10RitLines.plural(int(r.tickets), "билет желания", "билета желания", "билетов желания")]
	return ""


func _claim() -> void:
	var rows: Array = claim_fn.call() if claim_fn.is_valid() else V10Comeback.ladder_claim(_key)
	if rows.is_empty():
		V9Feel.deny(_btn)
		return
	V9Feel.big(_btn, "sparkle")
	var dt: = V10RitUI.cascade(self, rows, Vector2(size.x * 0.5, size.y * 0.5), Vector2(size.x * 0.5, 30))
	var t: = create_tween()
	t.tween_interval(dt)
	t.tween_callback(_build)
