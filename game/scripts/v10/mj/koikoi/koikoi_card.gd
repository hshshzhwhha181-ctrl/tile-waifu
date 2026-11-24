class_name V10MjKoikoiCard
extends Control

# Одна карта ханафуды на экране. Размер узла постоянный (CW×CH), меньше/больше — через scale (pivot в центре),
# позиция задаётся центром: place(center, scale). Лицо или рубашка, подсветка совпадения, поднятие, переворот.

signal tapped(card)

const CW: = 104.0
const CH: = 189.0
const GOLD: = Color("e8c47e")
const GOLD_HI: = Color("f1d9a0")

var cid: = -1
var face_up: = true
var hl: = false          # совпадение на столе: золотая кайма
var dim: = false         # не играет сейчас
var pip: = true          # метка типа в углу (для понятности)
var skins: = {}
var skins_on: = true
var _tw: Tween
var _hl_t: = 0.0
var _face: Texture2D
var _back: Texture2D
var _center: = Vector2.ZERO
var _scale: = 1.0

func setup(c: int, up: bool, sk: Dictionary = {}, sk_on: bool = true) -> V10MjKoikoiCard:
	cid = c
	face_up = up
	skins = sk
	skins_on = sk_on
	size = Vector2(CW, CH)
	pivot_offset = size * 0.5
	mouse_filter = Control.MOUSE_FILTER_STOP
	_face = V10MjKoikoiSkins.texture(c, skins, skins_on) if c >= 0 else null
	_back = V10MjKoikoiSkins.back()
	return self

func _process(delta: float) -> void:
	if hl:
		_hl_t += delta
		queue_redraw()

func set_hl(on: bool) -> void:
	if hl != on:
		hl = on
		_hl_t = 0.0
		queue_redraw()

func set_dim(on: bool) -> void:
	if dim != on:
		dim = on
		queue_redraw()

func center() -> Vector2:
	return _center

func place(c: Vector2, s: float = 1.0, rot: float = 0.0, dur: float = 0.0, trans: = Tween.TRANS_QUINT) -> Tween:
	_center = c
	_scale = s
	if _tw and _tw.is_valid():
		_tw.kill()
	if dur <= 0.0:
		position = c - size * 0.5
		scale = Vector2(s, s)
		rotation = rot
		return null
	_tw = create_tween().set_parallel(true).set_trans(trans).set_ease(Tween.EASE_OUT)
	_tw.tween_property(self, "position", c - size * 0.5, dur)
	_tw.tween_property(self, "scale", Vector2(s, s), dur)
	_tw.tween_property(self, "rotation", rot, dur)
	return _tw

# Дуга: карта летит по кривой (подъём над столом), как брошенная рукой.
func arc_to(c: Vector2, s: float, dur: float, lift: float = 60.0, rot: float = 0.0) -> Tween:
	_center = c
	_scale = s
	if _tw and _tw.is_valid():
		_tw.kill()
	var p0: = position + size * 0.5
	var mid: = (p0 + c) * 0.5 + Vector2(0, -lift)
	var s0: = scale.x
	var r0: = rotation
	var step: = func(t: float) -> void:
		var e: = 1.0 - pow(1.0 - t, 3.0)
		var a: = p0.lerp(mid, e)
		var b: = mid.lerp(c, e)
		position = a.lerp(b, e) - size * 0.5
		var sc: = lerpf(s0, s, e) * (1.0 + 0.08 * sin(PI * t))
		scale = Vector2(sc, sc)
		rotation = lerpf(r0, rot, e)
	_tw = create_tween()
	_tw.tween_method(step, 0.0, 1.0, dur)
	return _tw

func flip_to(up: bool, dur: float = 0.24) -> Tween:
	var t: = create_tween()
	var sy: = scale.y
	t.tween_property(self, "scale:x", 0.0, dur * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.tween_callback(func():
		face_up = up
		queue_redraw())
	t.tween_property(self, "scale:x", sy, dur * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	return t

func _gui_input(e: InputEvent) -> void:
	if (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and e.pressed):
		tapped.emit(self)
		accept_event()

func _draw() -> void:
	var r: = Rect2(Vector2.ZERO, size)
	# тень-контакт: на 3 px темнее, без падающей тени (DS «Тишина и лак»)
	draw_rect(Rect2(Vector2(2, 4), size), Color(0, 0, 0, 0.35))
	var tex: Texture2D = _face if face_up else _back
	if tex:
		draw_texture_rect(tex, r, false)
	else:
		_draw_fallback(r)
	if face_up and pip and cid >= 0:
		_draw_pip()
	if dim:
		draw_rect(r.grow(-2), Color(0.04, 0.03, 0.05, 0.5))
	if hl:
		var a: = 0.55 + 0.45 * sin(_hl_t * 5.0)
		var w: = 3.0 + 2.0 * a
		_rrect_outline(r.grow(3), 10.0, Color(GOLD_HI, 0.35 + 0.5 * a), w + 4.0)
		_rrect_outline(r.grow(1), 9.0, Color(GOLD_HI, 0.95), 2.5)

func _rrect_outline(r: Rect2, rad: float, col: Color, w: float) -> void:
	var sb: = StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = col
	sb.set_border_width_all(int(ceil(w)))
	sb.set_corner_radius_all(int(rad))
	sb.anti_aliasing = true
	draw_style_box(sb, r)

# Метка типа: свет — золотой диск, животное — нефрит, лента — роза/индиго, пустая — без метки.
func _draw_pip() -> void:
	var k: = V10MjKoikoi.kind(cid)
	var col: = Color(0, 0, 0, 0)
	match k:
		"light":
			col = Color("f1d9a0")
		"animal":
			col = Color("a9d9c4")
		"ribbon":
			col = Color("7f8ee8") if V10MjKoikoi.tag(cid) == "blue" else Color("ecc0c9")
		_:
			return
	var p: = Vector2(15, 15)
	draw_circle(p, 9.0, Color(0.07, 0.055, 0.065, 0.92))
	draw_circle(p, 6.0, col)
	if k == "light":
		for i in 8:
			var ang: = TAU * i / 8.0
			draw_line(p + Vector2.from_angle(ang) * 7.0, p + Vector2.from_angle(ang) * 9.5, col, 1.5)

func _draw_fallback(r: Rect2) -> void:
	draw_rect(r, Color("1b171c"))
	draw_rect(r.grow(-4), Color(GOLD, 0.8), false, 2.0)
	if face_up and cid >= 0:
		var f: = UI.font("title", 700)
		draw_string(f, Vector2(8, 40), str(V10MjKoikoi.month(cid) + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 28, GOLD)
