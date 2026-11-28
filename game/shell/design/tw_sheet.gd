class_name TWSheet
extends Control

# TWSheet (P28 / WP9b): bottom sheet panel. Opens in T_IN (240 ms) and closes in 180 ms with QUINT OUT (GDD 9.1), stepped by advance(dt) so a test
# can measure it per tick. The panel is a plate surface; the DIMMER is NOT here: host the sheet in a TWModal/ModalStack, which owns the scrim.
#   var s := TWSheet.make("Подарок дня", 400.0)     # content height
#   s.body.add_child(...)                            # content goes into `body` (a Control placed under the title row)
#   s.open(vs); s.close(); s.closed.connect(...)
#   TWSheet.compute(vs, insets, content_h) -> {panel, close, title, body, handle, content_h}   (pure; panel stays inside the safe area)

signal opened
signal closed

const T_OPEN: = 0.24
const T_CLOSE: = 0.18
const TITLE_ROW: = 96.0
const HANDLE_H: = 24.0
enum State { HIDDEN, OPENING, OPEN, CLOSING }

var title: = "":
	set(v):
		title = v
		_layout()
var content_h: = 320.0:
	set(v):
		content_h = v
		_layout()
var body: Control
var state: int = State.HIDDEN
var viewport_override: = Vector2.ZERO
var closable: = true
var _title_l: Label
var _close_btn: TWButton
var _t: = 0.0
var _off: = 0.0
var _vs: = Vector2(720, 1280)


static func ease_quint_out(k: float) -> float:
	return 1.0 - pow(1.0 - clampf(k, 0.0, 1.0), 5.0)


static func compute(vs: Vector2, insets: Dictionary, content_h: float) -> Dictionary:
	var cw: = minf(vs.x, float(TWTokens.BASE_WIDTH))
	var cx: = floorf(maxf(0.0, (vs.x - cw) * 0.5))
	var bottom_pad: = maxf(float(TWTokens.S3), float(insets.bottom) + float(TWTokens.S3))
	var max_h: = vs.y - float(insets.top) - float(TWTokens.S12)   # always leave a strip of the screen above the sheet
	var body_h: = minf(content_h, max_h - HANDLE_H - TITLE_ROW - bottom_pad)
	var h: = HANDLE_H + TITLE_ROW + body_h + bottom_pad
	var panel: = Rect2(cx, vs.y - h, cw, h)
	return {"panel": panel,
			"handle": Rect2(cx + (cw - 64.0) * 0.5, panel.position.y + 10.0, 64.0, 6.0),
			"close": Rect2(panel.end.x - float(TWTokens.S1) - TWButton.hit_min(false), panel.position.y + HANDLE_H, TWButton.hit_min(false), TWButton.hit_min(false)),
			"title": Rect2(panel.position.x + float(TWTokens.SAFE_MARGIN), panel.position.y + HANDLE_H, cw - float(TWTokens.SAFE_MARGIN) - TWButton.hit_min(false) - float(TWTokens.S2), TITLE_ROW),
			"body": Rect2(panel.position.x + float(TWTokens.SAFE_MARGIN), panel.position.y + HANDLE_H + TITLE_ROW, cw - float(TWTokens.SAFE_MARGIN) * 2.0, body_h),
			"content_h": body_h}


static func make(t: String, content_height: float) -> TWSheet:
	var s: = TWSheet.new()
	s.title = t
	s.content_h = content_height
	return s


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = false
	visible = false
	body = Control.new()
	body.name = "Body"
	body.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(body)
	_title_l = TWDraw.label("", "display", TWTokens.TYPE_H2, TWTokens.PAPER_100)
	add_child(_title_l)
	_close_btn = TWButton.make("quiet", "", Vector2(TWButton.hit_min(false), TWButton.hit_min(false)))
	_close_btn.icon = "close"
	_close_btn.icon_color = TWTokens.PAPER_300
	_close_btn.pressed.connect(func() -> void:
		if closable:
			close())
	add_child(_close_btn)
	add_to_group(TWSkin.GROUP)


func _skin_changed() -> void:
	_layout()


func panel_rect() -> Rect2:
	return compute(_vs, TWDraw.safe_insets(_vs), content_h).panel


func _layout() -> void:
	if body == null:
		return
	var vs: = viewport_override if viewport_override != Vector2.ZERO else (get_viewport_rect().size if is_inside_tree() else _vs)
	_vs = vs
	var g: = compute(vs, TWDraw.safe_insets(vs), content_h)
	var p: Rect2 = g.panel
	position = p.position + Vector2(0, _off)
	size = p.size
	body.position = (g.body as Rect2).position - p.position
	body.size = (g.body as Rect2).size
	var tr: Rect2 = g.title
	_title_l.position = tr.position - p.position
	_title_l.size = Vector2(tr.size.x, tr.size.y)
	TWDraw.fit(_title_l, title, "display", [TWTokens.TYPE_H2, TWTokens.TYPE_BODY, TWTokens.TYPE_CAPTION], tr.size.x, TWSkin.c("PAPER_100"))
	_close_btn.visible = closable
	var cr: Rect2 = g.close
	_close_btn.position = cr.position - p.position + Vector2(0, (TITLE_ROW - cr.size.y) * 0.5)
	queue_redraw()


func open(vs: Vector2 = Vector2.ZERO) -> void:
	if vs != Vector2.ZERO:
		viewport_override = vs
	state = State.OPENING
	_t = 0.0
	visible = true
	_off = 0.0
	_layout()
	_off = (compute(_vs, TWDraw.safe_insets(_vs), content_h).panel as Rect2).size.y
	_layout()
	set_process(true)


func close() -> void:
	if state == State.HIDDEN or state == State.CLOSING:
		return
	state = State.CLOSING
	_t = 0.0
	set_process(true)


func advance(dt: float) -> void:
	var ph: float = (compute(_vs, TWDraw.safe_insets(_vs), content_h).panel as Rect2).size.y
	match state:
		State.OPENING:
			_t += dt
			_off = ph * (1.0 - ease_quint_out(_t / T_OPEN))
			if _t >= T_OPEN:
				_off = 0.0
				state = State.OPEN
				opened.emit()
		State.CLOSING:
			_t += dt
			_off = ph * ease_quint_out(_t / T_CLOSE)
			if _t >= T_CLOSE:
				_off = ph
				state = State.HIDDEN
				visible = false
				closed.emit()
	_layout()
	if state == State.OPEN or state == State.HIDDEN:
		set_process(false)


func _process(delta: float) -> void:
	advance(delta)


func _draw() -> void:
	var r: = Rect2(Vector2.ZERO, size)
	TWDraw.plate_surface(self, Rect2(r.position - Vector2(0, 0), r.size + Vector2(0, float(TWTokens.R_LG))), false)
	var cx: = size.x * 0.5
	draw_rect(Rect2(cx - 32.0, 10.0, 64.0, 6.0), Color(TWSkin.c("PAPER_700"), 0.7))
