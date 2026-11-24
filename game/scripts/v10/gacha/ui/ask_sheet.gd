class_name V10AskSheet
extends Control

# V10AskSheet — one small lacquer bottom sheet with a question, one primary and one quiet answer.
#   V10AskSheet.open(parent, "Сделать партнёром?", "Она встретит тебя в Чайной", "Сделать партнёром", "Позже", on_yes)

var on_yes: Callable
var on_no: Callable


static func open(parent: Control, title: String, text: String, yes: String, no: String, cb_yes: Callable, cb_no: = Callable(), art: Texture2D = null) -> V10AskSheet:
	var s: = V10AskSheet.new()
	s.size = parent.get_viewport_rect().size
	s.on_yes = cb_yes
	s.on_no = cb_no
	parent.add_child(s)
	s._build(title, text, yes, no, art)
	return s


func _build(title: String, text: String, yes: String, no: String, art: Texture2D) -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var W: = size.x
	var H: = size.y
	var dim: = ColorRect.new()
	dim.size = size
	dim.color = Color(0.03, 0.02, 0.04, 0.0)
	add_child(dim)
	dim.create_tween().tween_property(dim, "color:a", 0.6, 0.2)
	var h: = 380.0
	var sh: = V10GUI.sheet(Rect2(0, H - h, W, h + 8), 0.98)
	sh.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(sh)
	var tx: = 32.0
	if art:
		var a: = Common.card_art(art, Rect2(28, 32, 120, 160), Vector2(0.5, 0.25), 1.0, 8.0)
		sh.add_child(a)
		tx = 172.0
	var t: = V10GUI.h1(title, 38)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.size = Vector2(W - tx - 32, 10)
	t.position = Vector2(tx, 36)
	sh.add_child(t)
	var l: = V10GUI.lbl(text, 21, V10GUI.PAPER_300, "body", 700)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size = Vector2(W - tx - 32, 10)
	l.position = Vector2(tx, 36 + t.get_minimum_size().y + 8)
	sh.add_child(l)
	var yb: = JButton.make(yes, "pink", Rect2(24, h - 140, W * 0.62 - 30, 104), null, 28)
	yb.set_meta("ux_role", "primary")
	yb.pressed.connect(func():
		close()
		on_yes.call())
	sh.add_child(yb)
	var nb: = JButton.make(no, "glass", Rect2(W * 0.62 + 6, h - 140, W * 0.38 - 30, 104), null, 24)
	nb.set_meta("ux_role", "secondary")
	nb.sound = "tap"
	nb.pressed.connect(func():
		close()
		if on_no.is_valid():
			on_no.call())
	sh.add_child(nb)
	sh.position.y += 40
	sh.create_tween().tween_property(sh, "position:y", H - h, 0.24).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)


func close() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t: = create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.18)
	t.tween_callback(queue_free)
