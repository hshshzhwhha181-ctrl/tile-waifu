class_name V10SalonButton
extends Control

# Button classes of UX_RULES §6.5, every press through V9Feel (dip 0.94 → spring back, click, light haptic).
#   "game"   rose.500 pill, night.900 Playfair 32 — the one main action of a screen; breathes 0.985↔1.0 / 3.2 s
#            and gets one soft glint every 2.8 s while `alive` (an available action)
#   "second" night.700 glass with a gold 1 px line at 35 %, paper text
#   "quiet"  icon-sized glass circle (hit zone ≥ 80 px), for back / close / photo presets
#   "chip"   selectable pill (finish choice); `selected` draws gold
# A disabled button still takes taps: it shakes «no» (V9Feel.deny) and emits `denied`, never silently ignores.

signal pressed
signal denied

var kind: = "game"
var text: = ""
var sub: = ""
var stars: = -1  # draws «text · N★» with a drawn star when ≥ 0
var icon: = ""  # "back" | "close" | "camera" | "chat" | "home" | "play" | "scene" | ""
var disabled: = false:
	set(v):
		disabled = v
		queue_redraw()
var selected: = false:
	set(v):
		selected = v
		queue_redraw()
var alive: = false
var accent: = V10SalonUI.ROSE_500
var sound: = "pop"
var _t: = 0.0
var _down: = false
var _glint: = -1.0


static func make(kind_: String, text_: String, rect: Rect2, stars_: = -1) -> V10SalonButton:
	var b: = V10SalonButton.new()
	b.kind = kind_
	b.text = text_
	b.stars = stars_
	b.position = rect.position
	b.size = rect.size
	b.custom_minimum_size = rect.size
	b.pivot_offset = rect.size * 0.5
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.focus_mode = Control.FOCUS_NONE
	b.alive = kind_ == "game"
	return b


func _ready() -> void:
	pivot_offset = size * 0.5
	resized.connect(func(): pivot_offset = size * 0.5)


func _process(dt: float) -> void:
	if not alive or disabled or _down or not V10SalonUI.can_fx():
		return
	_t += dt
	if not has_meta(V9Feel.META_TW):
		var s: = 0.9925 + 0.0075 * cos(_t * TAU / 3.2)
		scale = Vector2(s, s)
	var g: = fmod(_t, 2.8)
	_glint = g / 0.7 if g < 0.7 else -1.0
	queue_redraw()


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_down = true
			if disabled:
				return
			V9Feel.press_down(self)
			accept_event()
		elif _down:
			_down = false
			var inside: = Rect2(Vector2.ZERO, size).has_point(e.position)
			accept_event()
			if disabled:
				if inside:
					V9Feel.deny(self)
					denied.emit()
				return
			V9Feel.press_up(self, inside, sound)
			if inside:
				V9Feel.haptic("button")
				pressed.emit()


# for scripted playtests: the same feedback as a real tap
func tap() -> void:
	if disabled:
		V9Feel.deny(self)
		denied.emit()
		return
	V9Feel.press(self, sound)
	pressed.emit()


func _draw() -> void:
	var r: = Rect2(Vector2.ZERO, size)
	match kind:
		"game":
			var col: = accent if not disabled else V10SalonUI.NIGHT_600
			draw_style_box(V10SalonUI.panel_box(col, size.y * 0.5), r)
			if _glint >= 0.0 and not disabled:
				var x: = lerpf(-size.y, size.x + size.y, _glint)
				var a: = sin(_glint * PI) * 0.13
				var pts: = PackedVector2Array([Vector2(x, 0), Vector2(x + 26, 0), Vector2(x - size.y * 0.5 + 26, size.y), Vector2(x - size.y * 0.5, size.y)])
				var clip: = []
				for p in pts:
					clip.append(Vector2(clampf(p.x, size.y * 0.35, size.x - size.y * 0.35), p.y))
				draw_colored_polygon(PackedVector2Array(clip), Color(1, 1, 1, a))
			_draw_label(V10SalonUI.NIGHT_900 if not disabled else V10SalonUI.PAPER_500, 30, "display", 700)
		"second":
			draw_style_box(V10SalonUI.panel_box(Color(V10SalonUI.NIGHT_700, 0.92), 4.0, Color(V10SalonUI.GOLD_700, 0.6), 1), r)
			_draw_label(V10SalonUI.PAPER_100 if not disabled else V10SalonUI.PAPER_700, 24, "body", 800)
		"chip":
			var bg: = Color(V10SalonUI.NIGHT_700, 0.96)
			var line: = Color(V10SalonUI.GOLD_700, 0.5)
			if selected:
				bg = Color("3a2f2a")
				line = V10SalonUI.GOLD_500
			draw_style_box(V10SalonUI.panel_box(bg, size.y * 0.5, line, 2 if selected else 1), r)
			_draw_label(V10SalonUI.GOLD_300 if selected else (V10SalonUI.PAPER_300 if not disabled else V10SalonUI.PAPER_700), 21, "body", 800)
		"quiet":
			var c: = size * 0.5
			var rad: = minf(size.x, size.y) * 0.5 - 6.0
			draw_circle(c, rad, Color(V10SalonUI.NIGHT_800, 0.62))
			draw_arc(c, rad, 0, TAU, 48, Color(V10SalonUI.GOLD_700, 0.55), 1.0, true)
			_draw_icon(c, rad * 0.5, V10SalonUI.PAPER_100)
			if text != "":
				var f: = V10SalonUI.font("body", 800)
				var tw: = f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
				draw_string(f, Vector2(c.x - tw * 0.5, size.y + 18), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, V10SalonUI.PAPER_300)


func _draw_label(col: Color, fs: int, fkind: String, w: int) -> void:
	var f: = V10SalonUI.font(fkind, w)
	var t: = text
	var ic: = 0.0
	if icon != "":
		ic = fs * 1.1
	var tw: = f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var sw: = 0.0
	var st: = ""
	if stars >= 0:
		st = " · %d" % stars
		sw = f.get_string_size(st, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + fs * 0.9
	var sub_h: = 0.0
	if sub != "":
		sub_h = 22.0
	var total: = ic + tw + sw
	var x: = (size.x - total) * 0.5
	var asc: = f.get_ascent(fs)
	var y: = (size.y - sub_h) * 0.5 + (asc - f.get_descent(fs)) * 0.5
	if icon != "":
		_draw_icon(Vector2(x + fs * 0.45, y - asc * 0.36), fs * 0.38, col)
		x += ic
	draw_string(f, Vector2(x, y), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	x += tw
	if stars >= 0:
		draw_string(f, Vector2(x, y), st, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
		x += sw - fs * 0.9
		var sc: = Vector2(x + fs * 0.46, y - asc * 0.36)
		var star_col: = V10SalonUI.GOLD_300 if kind != "game" else V10SalonUI.NIGHT_900
		draw_colored_polygon(V10SalonUI.star_points(sc, fs * 0.4), star_col)
	if sub != "":
		var sf: = V10SalonUI.font("body", 700)
		var sww: = sf.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		draw_string(sf, Vector2((size.x - sww) * 0.5, y + 24), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(col, 0.75))


# monoline icons, stroke 2.5, round caps (UX §6.4)
func _draw_icon(c: Vector2, s: float, col: Color) -> void:
	var w: = 2.5
	match icon:
		"back":
			draw_polyline(PackedVector2Array([c + Vector2(s * 0.35, -s * 0.8), c + Vector2(-s * 0.45, 0), c + Vector2(s * 0.35, s * 0.8)]), col, w, true)
		"close":
			draw_line(c + Vector2(-s * 0.7, -s * 0.7), c + Vector2(s * 0.7, s * 0.7), col, w, true)
			draw_line(c + Vector2(s * 0.7, -s * 0.7), c + Vector2(-s * 0.7, s * 0.7), col, w, true)
		"camera":
			draw_rect(Rect2(c + Vector2(-s, -s * 0.6), Vector2(s * 2, s * 1.4)), col, false, w)
			draw_arc(c + Vector2(0, 0.1 * s), s * 0.42, 0, TAU, 24, col, w, true)
			draw_line(c + Vector2(-s * 0.4, -s * 0.6), c + Vector2(-s * 0.2, -s * 0.85), col, w, true)
			draw_line(c + Vector2(-s * 0.2, -s * 0.85), c + Vector2(s * 0.25, -s * 0.85), col, w, true)
		"chat":
			draw_arc(c + Vector2(0, -s * 0.1), s * 0.85, 0, TAU, 32, col, w, true)
			draw_line(c + Vector2(-s * 0.45, s * 0.55), c + Vector2(-s * 0.8, s * 1.0), col, w, true)
		"home":
			draw_polyline(PackedVector2Array([c + Vector2(-s, 0), c + Vector2(0, -s * 0.9), c + Vector2(s, 0)]), col, w, true)
			draw_polyline(PackedVector2Array([c + Vector2(-s * 0.7, -s * 0.2), c + Vector2(-s * 0.7, s * 0.9), c + Vector2(s * 0.7, s * 0.9), c + Vector2(s * 0.7, -s * 0.2)]), col, w, true)
		"play":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.5, -s * 0.75), c + Vector2(s * 0.8, 0), c + Vector2(-s * 0.5, s * 0.75)]), col)
		"scene":
			draw_rect(Rect2(c + Vector2(-s, -s * 0.7), Vector2(s * 2, s * 1.4)), col, false, w)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.3, -s * 0.4), c + Vector2(s * 0.45, 0), c + Vector2(-s * 0.3, s * 0.4)]), col)
		"frame":
			for k in 4:
				var sx: = -1.0 if k % 2 == 0 else 1.0
				var sy: = -1.0 if k < 2 else 1.0
				var p: = c + Vector2(sx * s, sy * s * 0.8)
				draw_line(p, p - Vector2(sx * s * 0.5, 0), col, w, true)
				draw_line(p, p - Vector2(0, sy * s * 0.5), col, w, true)
