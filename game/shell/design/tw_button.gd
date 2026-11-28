class_name TWButton
extends Control

# TWButton (P28 / WP9b): THE button of v11 (one API instead of JButton / V10Button / V10HudSkin), vector "lacquer", skinned by token overrides.
#   kinds   "play" dusty-rose pill (the one primary)  "cash" obsidian slab with a gold hairline (price/currency)
#           "secondary" matte night slab with an arrow  "quiet" icon in a translucent circle
#   TWButton.make("play", "Играть", Vector2(560, 104)); b.pressed.connect(...); b.denied (tap on a disabled button)
# Feel (GDD 9.1, "единый класс кнопки"): press DOWN 90 ms to scale 0.94, release UP 160 ms with a spring back to 1.0. The animation is a pure
# function of time stepped by advance(dt) (driven by _process while it runs), so a test can measure it per tick. The visual reaction starts in
# the SAME call as the input event (reaction_ms() = time from the event to the first changed frame state, budget < 100 ms).
# Hit target: never below TWTokens.HIT_TARGET_MIN (96) around the drawn shape; "big" buttons (Undo/Hint/Shuffle) use HIT_TARGET_BIG (112).

signal pressed
signal denied

const T_DOWN: = 0.09
const T_UP: = 0.16
const S_DOWN: = 0.94
const SPRING: = 1.9          # overshoot of the release spring (back-out constant)
const KINDS: = ["play", "cash", "secondary", "quiet"]

var kind: = "play":
	set(v):
		kind = v if v in KINDS else "play"
		_relayout()
var text: = "":
	set(v):
		text = v
		_relayout()
var overline: = "":
	set(v):
		overline = v
		_relayout()
var icon: = "":
	set(v):
		icon = v
		queue_redraw()
var icon_px: = 48
var icon_color: Color = TWTokens.PAPER_500
var big: = false:
	set(v):
		big = v
		update_minimum_size()
var disabled: = false:
	set(v):
		disabled = v
		_relayout()
var btn_size: = Vector2(560, 104):
	set(v):
		btn_size = v
		_relayout()
# legacy knobs of V10Button callers (kept so those callers compile; v11 has no per-button infinite animation)
var breathing: = false
var sheen: = false

var _l: Label
var _ov: Label
var _down: = false
var _phase: = 0                # 0 idle, 1 going down, 2 springing up
var _t: = 0.0
var _from: = 1.0
var _event_usec: = 0
var _react_usec: = -1
var _skin_rev: = -1


static func make(k: String, t: String, sz: Vector2) -> TWButton:
	var b: = TWButton.new()
	b.kind = k
	b.btn_size = sz
	b.text = t
	return b


# --- the press curve, pure functions of time (tested per tick) ---------------------------------------------------------

static func down_scale(t: float) -> float:
	var k: = clampf(t / T_DOWN, 0.0, 1.0)
	return lerpf(1.0, S_DOWN, 1.0 - pow(1.0 - k, 3.0))


static func up_scale(from: float, t: float) -> float:
	var k: = clampf(t / T_UP, 0.0, 1.0)
	var c3: = SPRING + 1.0
	var e: = 1.0 + c3 * pow(k - 1.0, 3.0) + SPRING * pow(k - 1.0, 2.0)   # back-out: 0 -> 1 with a small overshoot
	return lerpf(from, 1.0, e) if k < 1.0 else 1.0


static func hit_min(is_big: bool) -> float:
	return float(TWTokens.HIT_TARGET_BIG if is_big else TWTokens.HIT_TARGET_MIN)


# --- node --------------------------------------------------------------------------------------------------------------

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_l = Label.new()
	_l.label_settings = TWDraw.settings("ui", TWTokens.TYPE_BODY, TWTokens.PAPER_100)
	_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_l.clip_text = true
	_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_l)
	_ov = Label.new()
	_ov.label_settings = TWDraw.settings("overline", TWTokens.TYPE_CAPTION, TWTokens.GOLD_500, true)
	_ov.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ov)
	add_to_group(TWSkin.GROUP)


func _ready() -> void:
	_relayout()
	set_process(false)


func _skin_changed() -> void:
	_relayout()


func _get_minimum_size() -> Vector2:
	return btn_size


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_instance_valid(_l):
		if size != btn_size:
			set_deferred("size", btn_size)
		pivot_offset = btn_size * 0.5


func _has_point(p: Vector2) -> bool:
	# the drawn shape may be smaller than the touch target: pad it to the hit minimum on each axis
	var m: = hit_min(big)
	var pad: = Vector2(maxf(0.0, (m - btn_size.x) * 0.5), maxf(0.0, (m - btn_size.y) * 0.5))
	return Rect2(-pad, btn_size + pad * 2.0).has_point(p)


func hit_rect() -> Rect2:
	var m: = hit_min(big)
	var pad: = Vector2(maxf(0.0, (m - btn_size.x) * 0.5), maxf(0.0, (m - btn_size.y) * 0.5))
	return Rect2(-pad, btn_size + pad * 2.0)


func _relayout() -> void:
	if not is_instance_valid(_l):
		return
	update_minimum_size()
	pivot_offset = btn_size * 0.5
	var a: = 0.5 if disabled else 1.0
	match kind:
		"play":
			TWDraw.fit(_l, text, "display", [TWTokens.TYPE_H2, TWTokens.TYPE_BODY, TWTokens.TYPE_CAPTION], btn_size.x - 64.0, Color(TWSkin.c("NIGHT_900"), a))
			_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_l.position = Vector2(32.0, 0.0)
			_l.size = Vector2(btn_size.x - 64.0, btn_size.y)
		"cash":
			TWDraw.fit(_l, text, "num", [TWTokens.TYPE_BODY, TWTokens.TYPE_CAPTION], btn_size.x - 24.0, Color(TWSkin.c("PAPER_100"), a))
			_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_l.position = Vector2(12.0, 0.0)
			_l.size = Vector2(btn_size.x - 24.0, btn_size.y)
		"secondary":
			var avail: = btn_size.x - 64.0
			var sz: = TWDraw.fit(_l, text, "ui", [TWTokens.TYPE_BODY, TWTokens.TYPE_CAPTION], avail, Color(TWSkin.c("PAPER_100"), a))
			var tw: = minf(avail, TWDraw.text_w(text, "ui", sz))
			_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			_l.size = Vector2(tw + 6.0, btn_size.y)
			_l.position = Vector2((btn_size.x - tw - 36.0) * 0.5, 0.0)
		_:
			_l.text = ""
	_ov.visible = overline != ""
	if overline != "":
		_ov.label_settings = TWDraw.settings("overline", TWTokens.TYPE_CAPTION, TWSkin.c("GOLD_500"), true)
		_ov.text = overline.to_upper()
		_ov.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var oh: = TWDraw.box_h("overline", TWTokens.TYPE_CAPTION)
		_ov.position = Vector2(0.0, -oh - 2.0)
		_ov.size = Vector2(btn_size.x, oh)
	queue_redraw()


func _draw() -> void:
	var r: = Rect2(Vector2.ZERO, btn_size)
	var dim: = 0.5 if disabled else 1.0
	match kind:
		"play":
			var rad: = btn_size.y * 0.5
			draw_colored_polygon(TWDraw.rr_pts(Rect2(r.position + Vector2(0.0, 3.0), r.size), rad, 12), Color(TWSkin.c("NIGHT_900"), 0.34 * dim))
			var r5: = TWSkin.c("ROSE_500")
			var r7: = TWSkin.c("ROSE_700")
			var ct: = r7.lightened(0.06) if _down else r5.lightened(0.06)
			var cm: = r7 if _down else r5
			var cb: = r7.darkened(0.08) if _down else r5.lerp(r7, 0.22)
			if disabled:
				ct = ct.lerp(TWSkin.c("NIGHT_600"), 0.6)
				cm = cm.lerp(TWSkin.c("NIGHT_600"), 0.6)
				cb = cb.lerp(TWSkin.c("NIGHT_600"), 0.6)
			var body: = TWDraw.rr_pts(r, rad, 14)
			draw_polygon(body, TWDraw.grad_cols(body, r.position.y, r.end.y, [[0.0, ct], [0.52, cm], [1.0, cb]]))
			var sr: = Rect2(r.position.x + 2.0, r.position.y + 1.5, r.size.x - 4.0, r.size.y * 0.44)
			if sr.size.x > 8.0 and sr.size.y > 4.0:
				var sp: = TWDraw.rr_pts(sr, minf(rad - 2.0, sr.size.y * 0.48), 10)
				draw_polygon(sp, TWDraw.grad_cols(sp, sr.position.y, sr.end.y, [
					[0.0, Color(TWSkin.c("PAPER_100"), 0.06 if _down else 0.13)], [1.0, Color(TWSkin.c("PAPER_100"), 0.0)]]))
			var inset: = minf(rad * 0.72, btn_size.x * 0.25)
			TWDraw.hairline(self, inset, btn_size.x - inset, 1.0, Color(TWSkin.c("PLATE_SPARK"), (0.42 if _down else 0.76) * dim))
			TWDraw.hairline(self, inset, btn_size.x - inset, btn_size.y - 1.2, Color(r7, 0.45 * dim))
		"cash":
			var rad2: = float(TWTokens.R_SM) * 0.75
			var bg: = TWSkin.c("NIGHT_600") if _down else TWSkin.c("NIGHT_700")
			var pts2: = TWDraw.rr_pts(r, rad2, 8)
			draw_polygon(pts2, TWDraw.grad_cols(pts2, r.position.y, r.end.y, [[0.0, Color(bg.lightened(0.03), dim)], [1.0, Color(bg, dim)]]))
			var lh2: = r.size.y * 0.42
			var lac2: = Color(TWSkin.c("PAPER_100"), 0.05)
			var clr2: = Color(TWSkin.c("PAPER_100"), 0.0)
			draw_polygon(PackedVector2Array([Vector2(rad2 * 0.5, 1.5), Vector2(r.size.x - rad2 * 0.5, 1.5), Vector2(r.size.x - 2.0, lh2), Vector2(2.0, lh2)]),
					PackedColorArray([lac2, lac2, clr2, clr2]))
			var bp: = TWDraw.rr_pts(r.grow(-0.75), maxf(2.0, rad2 - 0.75), 8)
			bp.append(bp[0])
			draw_polyline(bp, Color(TWSkin.c("GOLD_300") if _down else TWSkin.c("GOLD_500"), dim), 1.5, true)
		"secondary":
			var rad3: = float(TWTokens.R_SM) * 0.75
			var bg3: = Color(TWSkin.c("NIGHT_600"), 0.96) if _down else Color(TWSkin.c("NIGHT_800"), 0.92)
			bg3.a *= dim
			draw_colored_polygon(TWDraw.rr_pts(r, rad3, 8), bg3)
			var lh3: = r.size.y * 0.40
			var lac3: = Color(TWSkin.c("PAPER_100"), 0.05)
			var clr3: = Color(TWSkin.c("PAPER_100"), 0.0)
			draw_polygon(PackedVector2Array([Vector2(rad3 * 0.5, 1.0), Vector2(r.size.x - rad3 * 0.5, 1.0), Vector2(r.size.x - 1.5, lh3), Vector2(1.5, lh3)]),
					PackedColorArray([lac3, lac3, clr3, clr3]))
			draw_line(Vector2(rad3, r.size.y - 1.0), Vector2(r.size.x - rad3, r.size.y - 1.0), Color(TWSkin.c("NIGHT_900"), 0.65), 1.0)
			TWDraw.hairline(self, 12.0, btn_size.x - 12.0, 0.8, Color(TWSkin.c("GOLD_500") if _down else TWSkin.c("GOLD_700"), (0.65 if _down else 0.45) * dim))
			if text != "":
				V10Icons.draw(self, "arrow_r", Vector2(_l.position.x + _l.size.x + 18.0, btn_size.y * 0.5), 24, Color(TWSkin.c("GOLD_300"), dim))
		"quiet":
			var ctr: = btn_size * 0.5
			var dr: = minf(btn_size.x, btn_size.y) * 0.36
			draw_circle(ctr, dr, Color(TWSkin.c("NIGHT_600"), 0.72) if _down else Color(TWSkin.c("NIGHT_800"), 0.44), true, -1.0, true)
			draw_arc(ctr, dr, 0.0, TAU, 48, Color(TWSkin.c("GOLD_500"), 0.60) if _down else Color(TWSkin.c("GOLD_700"), 0.34), 1.0, true)
			if icon != "":
				V10Icons.draw(self, icon, ctr, icon_px, Color(icon_color, dim))


# --- press animation (stepped, testable) ----------------------------------------------------------------------------

func visual_down() -> bool:
	return _down


func anim_phase() -> int:
	return _phase


func reaction_ms() -> float:
	return -1.0 if _react_usec < 0 else float(_react_usec - _event_usec) / 1000.0


func _start_down() -> void:
	_event_usec = Time.get_ticks_usec()
	_down = true
	_phase = 1
	_t = 0.0
	pivot_offset = btn_size * 0.5
	queue_redraw()
	_react_usec = Time.get_ticks_usec()   # the changed state (_down + redraw requested) exists before this handler returns
	set_process(true)


func _start_up() -> void:
	_down = false
	_phase = 2
	_t = 0.0
	_from = scale.x
	queue_redraw()
	set_process(true)


func advance(dt: float) -> void:
	if _phase == 0:
		return
	_t += dt
	if _phase == 1:
		var s: = down_scale(_t)
		scale = Vector2.ONE * s
		if _t >= T_DOWN:
			_phase = 3   # held down at 0.94 until release
			set_process(false)
	elif _phase == 2:
		scale = Vector2.ONE * up_scale(_from, _t)
		if _t >= T_UP:
			scale = Vector2.ONE
			_phase = 0
			set_process(false)


func _process(delta: float) -> void:
	advance(delta)


func _gui_input(e: InputEvent) -> void:
	if (e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT) or e is InputEventScreenTouch:
		if disabled:
			if e.pressed:
				TWDraw.feedback(self, true)
				denied.emit()
			accept_event()
			return
		if e.pressed:
			_start_down()
		elif _down:
			_start_up()
			if hit_rect().grow(16).has_point(e.position):
				TWDraw.feedback(self, false)
				pressed.emit()
		accept_event()
