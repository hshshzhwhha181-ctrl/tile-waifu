class_name V10NamePicker
extends Control

# «Как ей тебя звать?» (§Р8 п.8): 120 ready names as chips (with their address form), a gender toggle that picks
# the column (and the grammatical gender of her lines), and «Не называть» → «мастер стола». No free text input.

signal done

const P: = preload("res://scripts/v10/phone/phone.gd")
const PUI: = preload("res://scripts/v10/phone/phone_ui.gd")
const NAMES: = preload("res://scripts/v10/phone/names.gd")

var W: = 600.0
var H: = 900.0
var g: = "m"
var grid: VBoxContainer
var toggle: Control


func build(w: float, h: float) -> void:
	W = w
	H = h
	size = Vector2(W, H)
	name = "NamePicker"
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim: = ColorRect.new()
	dim.color = Color(0.075, 0.05, 0.07, 1.0)
	dim.size = size
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var cur: Dictionary = P.st().name
	g = str(cur.get("g", "m"))
	var t: = PUI.label("Как ей тебя звать?", 40 if PUI.has_caveat() else 32, PUI.GOLD, PUI.hand(), 4, Color(0.1, 0.03, 0.06, 0.8))
	t.position = Vector2(0, 26)
	t.size = Vector2(W, 50)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(t)
	var sub: = PUI.label("Имя и род, в котором героини говорят с тобой", 18, PUI.MUTED, PUI.body(800))
	sub.position = Vector2(20, 80)
	sub.size = Vector2(W - 40, 26)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(sub)
	toggle = Control.new()
	toggle.position = Vector2(W * 0.5 - 170, 120)
	toggle.size = Vector2(340, 56)
	add_child(toggle)
	_toggle()
	var sc: = ScrollContainer.new()
	sc.position = Vector2(0, 192)
	sc.size = Vector2(W, H - 192 - 96)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	add_child(sc)
	grid = VBoxContainer.new()
	grid.custom_minimum_size = Vector2(W, 0)
	grid.add_theme_constant_override("separation", 10)
	sc.add_child(grid)
	_fill()
	var none: = _chip(NAMES.NONE_LABEL + " · «мастер стола»", Rect2(24, H - 82, W - 48, 60), str(cur.get("nom", "")) == "" and bool(P.st().named))
	none.name = "NoName"
	add_child(none)
	PUI.tap(none, func(): _pick(""), "")
	PUI.pop_in(self, 0.0, 0.96, 0.3)


func _toggle() -> void:
	for c in toggle.get_children():
		c.queue_free()
	for i in 2:
		var gg: String = ["m", "f"][i]
		var on: bool = g == gg
		var c: = _chip(["Он", "Она"][i], Rect2(i * 174, 0, 166, 56), on)
		toggle.add_child(c)
		PUI.tap(c, func():
			g = gg
			PUI.snd("tab")
			_toggle()
			_fill(), "")


func _chip(text: String, r: Rect2, on: bool) -> Control:
	var c: = Control.new()
	c.position = r.position
	c.size = r.size
	c.pivot_offset = r.size * 0.5
	c.add_child(PUI.panel(Rect2(Vector2.ZERO, r.size), PUI.box(Color(PUI.GOLD, 0.22) if on else Color(1, 1, 1, 0.05), r.size.y * 0.5, 2.0 if on else 1.0, Color(PUI.GOLD, 0.9) if on else Color(1, 1, 1, 0.15))))
	var l: = PUI.label(text, 19, PUI.TEXT if on else PUI.MUTED, PUI.body(900 if on else 800))
	l.size = r.size
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	c.add_child(l)
	return c


func _fill() -> void:
	for c in grid.get_children():
		c.queue_free()
	var cur: = str(P.st().name.get("nom", ""))
	var names: = NAMES.by_gender(g)
	var cols: = 3
	var cw: = (W - 48 - (cols - 1) * 10) / cols
	var row: Control = null
	for i in names.size():
		if i % cols == 0:
			row = Control.new()
			row.custom_minimum_size = Vector2(W, 58)
			grid.add_child(row)
		var nm: String = names[i][0]
		var c: = _chip(nm, Rect2(24 + (i % cols) * (cw + 10), 0, cw, 54), nm == cur)
		c.name = "N_" + nm
		row.add_child(c)
		PUI.tap(c, func(): _pick(nm), "")


func _pick(nom: String) -> void:
	P.set_player_name(nom, g)
	G.save()
	V9Feel.success(null, "sparkle")
	var t: = create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.2)
	t.tween_callback(func():
		done.emit()
		queue_free())
