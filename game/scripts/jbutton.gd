class_name JButton
extends Control


signal pressed
var box: RBox
var lbl: Label
var sub: Label
var icon_rect: TextureRect
var sound: = "pop"
var shine_every: = 0.0
var pulse: = false
var disabled: = false
var _shine_t: = 0.0
var _down: = false

static func make(text: String, pal: String, rect: Rect2, icon: Texture2D = null, font_size: = 30, radius: = -1.0) -> JButton:
	var b: = JButton.new()
	b.position = rect.position
	b.size = rect.size
	b.build(text, pal, icon, font_size, radius)
	return b

func build(text: String, pal: String, icon: Texture2D, font_size: int, radius: float) -> void :
	mouse_filter = Control.MOUSE_FILTER_STOP
	pivot_offset = size * 0.5
	var p: Array = UI.PAL[pal]
	box = RBox.new()
	box.size = size
	box.setup(p[0], p[1], size.y * 0.5 if radius < 0 else radius, 4.0, 14.0)
	add_child(box)
	var x0: = 0.0
	if icon:
		var s: = size.y * 0.92
		icon_rect = UI.tex(icon, Rect2(size.y * 0.06 + 4, (size.y - s) * 0.5, s, s))
		add_child(icon_rect)
		x0 = s + 6
	if text != "":
		var outline: Color = p[2]
		var col: = Color.WHITE
		if pal in ["cream", "glass", "graphite", "plum"]:
			col = UI.INK
			outline = UI.DARK
		if pal == "gold":
			col = Color("3a2410")
			outline = Color(1.0, 0.95, 0.8, 0.55)
		lbl = UI.label(text, font_size, col, outline, 6 if col == Color.WHITE else (2 if pal == "gold" else 4), "body", 900)
		UI.center_label(lbl, Rect2(x0, 0, size.x - x0, size.y))
		add_child(lbl)

func set_sub(text: String, size_px: = 20) -> void :
	if sub == null:
		sub = UI.label(text, size_px, lbl.label_settings.font_color if lbl else Color.WHITE, lbl.label_settings.outline_color if lbl else UI.PAL["gold"][2], 2 if lbl and lbl.label_settings.outline_size <= 2 else 4)
		add_child(sub)
	sub.text = text
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	lbl.position.y = size.y * 0.1
	UI.center_label(sub, Rect2(lbl.position.x, size.y * 0.52, lbl.size.x, size.y * 0.4))

func badge(text: = "!") -> void :
	var d: = UI.rbox("red", Rect2(size.x - 26, -8, 32, 32), 16, 3, 6)
	add_child(d)
	var l: = UI.center_label(UI.label(text, 18, Color.WHITE), Rect2(0, 0, 32, 32))
	d.add_child(l)
	var t: Tween = d.create_tween().set_loops()
	d.pivot_offset = Vector2(16, 16)
	t.tween_property(d, "scale", Vector2(1.15, 1.15), 0.5).set_trans(Tween.TRANS_SINE)
	t.tween_property(d, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_SINE)

func _process(dt: float) -> void :
	if shine_every > 0.0:
		_shine_t -= dt
		if _shine_t <= 0.0:
			_shine_t = shine_every + randf() * 1.5
			box.shine()
	if pulse and not _down:
		var s: = 1.0 + 0.025 * sin(G.time * 3.2)
		scale = Vector2(s, s)

func _gui_input(e: InputEvent) -> void :
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_press_down()
		elif _down:
			_down = false
			_release(Rect2(Vector2.ZERO, size).has_point(e.position))
		accept_event()

func _press_down() -> void :
	if disabled:
		Sfx.play("deny")
		return
	_down = true
	box.set_param("pressed", 1.0)
	var t: = create_tween()
	t.tween_property(self, "scale", Vector2(0.92, 0.9), 0.07)

func _release(fire: bool) -> void :
	box.set_param("pressed", 0.0)
	var t: = create_tween()
	t.tween_property(self, "scale", Vector2(1.05, 1.06), 0.08)
	t.tween_property(self, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	if fire:
		Sfx.play(sound, randf_range(0.95, 1.08))
		box.shine(0.0, 0.5)
		pressed.emit()

func activate() -> void :

	_press_down()
	await get_tree().create_timer(0.12).timeout
	_down = false
	_release(true)
