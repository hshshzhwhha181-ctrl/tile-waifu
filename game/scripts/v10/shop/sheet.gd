class_name V10ShopSheet
extends Control

# V10ShopSheet — the one bottom sheet of Лавка 2 (UX §5.3, §6.1, §6.7 «Шёлк», П-6). A sheet opens only over a
# screen: opening a new one closes the current one first (never a sheet over a sheet). Under it lies the pre-blurred
# snapshot of the shop background (no live blur on Mali). Close: «×» quiet button with an 80 px hit zone, a tap on
# the dimmed area, or the Android back button (meta "v8_back").
#
#   var sh := V10ShopSheet.make(host, "Набор первого гостя")
#   var y := sh.top()                     # first free y inside the panel
#   sh.body.add_child(...); y += ...
#   sh.finish(y + 24)                     # panel height → slides up 220 ms QUINT OUT

signal closed

static var current: V10ShopSheet = null
static var layer: Control = null     # integrator: main's overlay above the navbar (sheets cover the whole screen)

const PAD: = 32.0

var body: Control
var panel_w: = 672.0
var title_l: Label
var close_btn: V10Button
var _panel: V10ShopW.Lac
var _dim: Control
var _h: = 0.0
var _closing: = false
var kind: = ""
var busy: = false:     # a payment is in flight: tap-outside / × / back wait for the answer (nothing «где-то потом»)
	set(v):
		busy = v
		if v and is_inside_tree():
			# safety: a provider that never answers must not trap the player
			get_tree().create_timer(20.0).timeout.connect(func():
				if is_instance_valid(self):
					busy = false)


static func make(host: Control, title: String, k: = "") -> V10ShopSheet:
	if current != null and is_instance_valid(current):
		current.close(true)
	var s: = V10ShopSheet.new()
	s.kind = k
	s.name = "V10ShopSheet"
	var parent: Control = layer if layer != null and is_instance_valid(layer) and layer.is_inside_tree() else host
	parent.add_child(s)
	s._build(title)
	current = s
	return s


func _build(title: String) -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var vs: Vector2 = get_parent().size if get_parent() is Control else get_viewport_rect().size
	size = vs
	_dim = Control.new()
	_dim.size = vs
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.gui_input.connect(func(e: InputEvent):
		if (e is InputEventMouseButton or e is InputEventScreenTouch) and not e.pressed:
			close())
	add_child(_dim)
	var bt: = V10ShopKit.tex("bg_shop_blur")
	if bt:
		var b: = V10ShopKit.art(bt, Rect2(Vector2.ZERO, vs), true)
		b.modulate = Color(1, 1, 1, 0.55)
		_dim.add_child(b)
	var shade: = ColorRect.new()
	shade.color = Color(V10DS.NIGHT_900, 0.62)
	shade.size = vs
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.add_child(shade)
	panel_w = minf(vs.x, 720.0)
	_panel = V10ShopW.Lac.new()
	_panel.over_art = false
	_panel.fill = V10DS.NIGHT_700
	_panel.position = Vector2((vs.x - panel_w) * 0.5, vs.y)
	_panel.size = Vector2(panel_w, 200)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)
	body = Control.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.size = Vector2(panel_w, 2000)
	_panel.add_child(body)
	title_l = V10ShopKit.lbl(title, "display", 32, V10DS.PAPER_100)
	V10Type.fit(title_l, title, "title_l", panel_w - PAD * 2 - 88, 1, V10DS.PAPER_100)
	title_l.position = Vector2(PAD, 28)
	title_l.size = Vector2(panel_w - PAD * 2 - 88, 48)
	body.add_child(title_l)
	close_btn = V10Button.make("quiet", "", Vector2(80, 80))
	close_btn.icon = "close"
	close_btn.icon_color = V10DS.PAPER_300
	close_btn.position = Vector2(panel_w - 16 - 80, 12)
	close_btn.set_meta("ux_role", "quiet")
	close_btn.pressed.connect(func():
		V10ShopKit.press(close_btn)
		close())
	body.add_child(close_btn)
	set_meta("v8_back", close)
	V10Hud2Util.sfx("page_turn")


func top() -> float:
	return 92.0


func inner_w() -> float:
	return panel_w - PAD * 2


func finish(h: float) -> void:
	var vs: = size
	var bottom_inset: = float(V10Hud2Util.safe_insets(vs).bottom)
	_h = minf(h + bottom_inset, vs.y - 48.0)
	_panel.size = Vector2(panel_w, _h + 8)
	var target: = vs.y - _h
	if not V10ShopKit.fx_on():
		_panel.position.y = target
		_panel.modulate.a = 0.0
		_panel.create_tween().tween_property(_panel, "modulate:a", 1.0, 0.12)
		return
	_dim.modulate.a = 0.0
	var tw: = create_tween().set_parallel(true)
	tw.tween_property(_panel, "position:y", target, 0.22).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tw.tween_property(_dim, "modulate:a", 1.0, 0.18)


func close(instant: = false) -> void:
	if _closing:
		return
	if busy and not instant:
		V10ShopKit.deny(_panel)
		return
	_closing = true
	if current == self:
		current = null
	closed.emit()
	if instant or not V10ShopKit.fx_on() or not is_inside_tree():
		queue_free()
		return
	V10Hud2Util.sfx("page_turn")
	var tw: = create_tween().set_parallel(true)
	tw.tween_property(_panel, "position:y", size.y, 0.18).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
	tw.tween_property(_dim, "modulate:a", 0.0, 0.16)
	tw.chain().tween_callback(queue_free)


# helpers for sheet bodies
func text(t: String, y: float, role: = "ui", sz: = 22, col: = V10DS.PAPER_100, lines: = 1) -> Label:
	var l: = V10ShopKit.lbl(t, role, sz, col)
	l.position = Vector2(PAD, y)
	l.size = Vector2(inner_w(), V10Type.line_h(sz) * lines)
	if lines > 1:
		V10ShopKit.wrap(l, lines)
	body.add_child(l)
	return l


func rule(y: float) -> void:
	var r: = Rule.new()
	r.position = Vector2(PAD, y)
	r.size = Vector2(inner_w(), 2)
	body.add_child(r)


class Rule:
	extends Control

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		V10Plate.hairline(self, 0, size.x, 0.5, Color(V10DS.GOLD_700, V10DS.HAIR_A))
