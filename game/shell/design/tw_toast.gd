class_name TWToast
extends Control

# TWToast (P28 / WP9b): the transient message strip under the top safe inset. One toast at a time, at most 3 waiting (a 4th drops the oldest waiting
# one, an identical text already shown/queued is ignored). Lifecycle (stepped by advance(dt)): in T_IN 240 ms slide+fade, hold (default 2.4 s),
# out T_OUT 160 ms. A tap dismisses. The control only occupies the toast rect while visible, so it never blocks taps elsewhere.
#   var t := TWToast.new(); screen.add_child(t); t.show_toast("Награда получена", "ok")
#   TWToast.compute(vs, insets) -> Rect2 (inside the safe area)

signal toast_shown(text: String)
signal toast_gone(text: String)

const KINDS: = {"info": "GOLD_500", "ok": "JADE_500", "warn": "EMBER"}
const HOLD: = 2.4
const H: = 80.0
const MAX_QUEUE: = 3
enum Phase { IDLE, IN, HOLD, OUT }

var phase: int = Phase.IDLE
var queue: Array = []
var current: Dictionary = {}
var viewport_override: = Vector2.ZERO
var _t: = 0.0
var _label: Label
var _off: = 0.0
var _alpha: = 0.0


static func compute(vs: Vector2, insets: Dictionary) -> Rect2:
	var cw: = minf(vs.x, float(TWTokens.BASE_WIDTH))
	var w: = minf(cw - float(TWTokens.SAFE_MARGIN) * 2.0, 672.0)
	return Rect2(floorf((vs.x - w) * 0.5), float(insets.top) + float(TWTokens.S1), w, H)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_label = TWDraw.label("", "ui", TWTokens.TYPE_BODY, TWTokens.PAPER_100)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(_label)
	add_to_group(TWSkin.GROUP)


func _skin_changed() -> void:
	queue_redraw()


func show_toast(text: String, kind: = "info", hold: = HOLD) -> bool:
	if text == "" or (not current.is_empty() and current.text == text):
		return false
	for q in queue:
		if q.text == text:
			return false
	if queue.size() >= MAX_QUEUE:
		queue.pop_front()
	queue.append({"text": text, "kind": kind if KINDS.has(kind) else "info", "hold": hold})
	if phase == Phase.IDLE:
		_next()
	return true


func _next() -> void:
	if queue.is_empty():
		phase = Phase.IDLE
		current = {}
		visible = false
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_process(false)
		return
	current = queue.pop_front()
	phase = Phase.IN
	_t = 0.0
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_layout()
	toast_shown.emit(str(current.text))
	set_process(true)


func dismiss() -> void:
	if phase == Phase.IN or phase == Phase.HOLD:
		phase = Phase.OUT
		_t = 0.0


func is_showing() -> bool:
	return phase != Phase.IDLE


func _layout() -> void:
	var vs: = viewport_override if viewport_override != Vector2.ZERO else (get_viewport_rect().size if is_inside_tree() else Vector2(TWTokens.BASE_WIDTH, 1280))
	var r: = compute(vs, TWDraw.safe_insets(vs))
	position = r.position + Vector2(0, _off)
	size = r.size
	var pad: = float(TWTokens.S3) + 24.0
	var lh: = TWDraw.box_h("ui", TWTokens.TYPE_BODY)
	_label.position = Vector2(pad, (H - lh) * 0.5)
	_label.size = Vector2(r.size.x - pad - float(TWTokens.S3), lh)
	if not current.is_empty():
		TWDraw.fit(_label, str(current.text), "ui", [TWTokens.TYPE_BODY, TWTokens.TYPE_CAPTION], _label.size.x, TWSkin.c("PAPER_100"))
	modulate.a = _alpha
	queue_redraw()


func advance(dt: float) -> void:
	match phase:
		Phase.IN:
			_t += dt
			var k: = clampf(_t / TWTokens.T_IN, 0.0, 1.0)
			var e: = 1.0 - pow(1.0 - k, 3.0)
			_off = -(1.0 - e) * (H + float(TWTokens.S3))
			_alpha = e
			if _t >= TWTokens.T_IN:
				phase = Phase.HOLD
				_t = 0.0
				_off = 0.0
				_alpha = 1.0
		Phase.HOLD:
			_t += dt
			if _t >= float(current.get("hold", HOLD)):
				phase = Phase.OUT
				_t = 0.0
		Phase.OUT:
			_t += dt
			var k2: = clampf(_t / TWTokens.T_OUT, 0.0, 1.0)
			_alpha = 1.0 - k2
			_off = -k2 * float(TWTokens.S2)
			if _t >= TWTokens.T_OUT:
				var gone: = str(current.get("text", ""))
				toast_gone.emit(gone)
				_off = 0.0
				_alpha = 0.0
				_next()
	if phase != Phase.IDLE:
		_layout()


func _process(delta: float) -> void:
	advance(delta)


func _draw() -> void:
	if current.is_empty():
		return
	TWDraw.plate_surface(self, Rect2(Vector2.ZERO, Vector2(size.x, H)), true)
	var accent: = TWSkin.c(str(KINDS[current.kind]))
	draw_circle(Vector2(float(TWTokens.S3) + 4.0, H * 0.5), 8.0, accent, true, -1.0, true)


func _gui_input(e: InputEvent) -> void:
	if (e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and e.pressed) or (e is InputEventScreenTouch and e.pressed):
		dismiss()
		accept_event()
