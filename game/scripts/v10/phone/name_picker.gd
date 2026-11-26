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
	# headings on the left field (§6.3); every chip is a ≥ 80 px tap row (§6.1)
	var t: = PUI.label("Как ей тебя звать?", PUI.fs_hand(), PUI.GOLD, PUI.hand())
	t.position = Vector2(28, 18)
	t.size = Vector2(W - 56, 54)
	add_child(t)
	var sub: = PUI.label("Имя и род, в котором героини говорят с тобой", PUI.FS_CAPTION, PUI.MUTED, PUI.body(800))
	sub.position = Vector2(28, 74)
	sub.size = Vector2(W - 56, 26)
	add_child(sub)
	toggle = Control.new()
	toggle.position = Vector2(24, 104)
	toggle.size = Vector2(340, 80)
	PUI.role(toggle, "secondary")
	add_child(toggle)
	_toggle()
	var sc: = ScrollContainer.new()
	sc.position = Vector2(0, 196)
	sc.size = Vector2(W, H - 196 - 104)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	add_child(sc)
	grid = VBoxContainer.new()
	grid.custom_minimum_size = Vector2(W, 0)
	grid.add_theme_constant_override("separation", 8)
	PUI.role(grid, "primary")       # the names are one control: a single choice
	sc.add_child(grid)
	_fill()
	var none: = _chip(NAMES.NONE_LABEL + " · «мастер стола»", Rect2(24, H - 96, W - 48, 80), str(cur.get("nom", "")) == "" and bool(P.st().named))
	none.name = "NoName"
	PUI.role(none, "secondary")
	add_child(none)
	PUI.tap(none, func(): _pick(""), "")
	PUI.pop_in(self, 0.0, 0.96, 0.3)


func _toggle() -> void:
	for c in toggle.get_children():
		c.queue_free()
	for i in 2:
		var gg: String = ["m", "f"][i]
		var on: bool = g == gg
		var c: = _chip(["Он", "Она"][i], Rect2(i * 174, 0, 166, 80), on)
		toggle.add_child(c)
		PUI.tap(c, func():
			g = gg
			PUI.snd("tab")
			_toggle()
			_fill(), "")


# a 56 px chip centred in its tap zone r (≥ 80 px high)
func _chip(text: String, r: Rect2, on: bool) -> Control:
	var c: = Control.new()
	c.position = r.position
	c.size = r.size
	c.pivot_offset = r.size * 0.5
	var vy: = (r.size.y - 56.0) * 0.5
	c.add_child(PUI.panel(Rect2(0, vy, r.size.x, 56), PUI.box(Color(PUI.GOLD, 0.22) if on else Color(PUI.TEXT, 0.05), 28, 2.0 if on else 1.0, Color(PUI.GOLD, 0.9) if on else Color(PUI.TEXT, 0.15))))
	var l: = PUI.label(text, PUI.FS_BODY, PUI.TEXT if on else PUI.MUTED, PUI.body(900 if on else 800))
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
			row.custom_minimum_size = Vector2(W, 80)
			grid.add_child(row)
		var nm: String = names[i][0]
		var c: = _chip(nm, Rect2(24 + (i % cols) * (cw + 10), 0, cw, 80), nm == cur)
		c.name = "N_" + nm
		row.add_child(c)
		PUI.tap(c, func(): _pick(nm), "")


func _pick(nom: String) -> void:
	P.set_player_name(nom, g)
	G.save()
	V9Feel.success(null, "sparkle")
	var t: = create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.12 if PUI.calm() else 0.2)
	t.tween_callback(func():
		done.emit()
		queue_free())
