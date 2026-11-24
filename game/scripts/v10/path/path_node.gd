class_name V10PathNode
extends Control

# One node of the Path map, drawn in code (cheap: no per-node textures except the boss/peak/crown art).
#   kind "level" | "boss" | "legend" | "peak"
#   state from V10PathState.state_of: "arc_locked" | "locked" | "open" | "current" | "done" | "bypass"
# Looks (0.10-spec П1): mint (easy) · cream (normal) · lilac + 1 flame (hard) · crimson + 2 flames + pulse
# (very hard) · gold crown (legendary); the chapter boss shows the hostess portrait in the crowned frame.

const Rules = preload("res://scripts/v10/path/path_rules.gd")

var i: = 0
var kind: = "level"
var tier: = "normal"
var num: = 1
var stars: = 0
var state: = "locked"
var intro: = ""
var host: = ""
var radius: = 46.0
var _t: = 0.0
var _font: Font
var _crown: TextureRect
var _peak: TextureRect
var _portrait: Control
var _frame: TextureRect
var fx_on: = true


func setup(info: Dictionary, st: String, star_n: int, host_id: = "") -> V10PathNode:
	i = int(info.i)
	tier = str(info.tier)
	num = int(info.num)
	intro = str(info.intro)
	state = st
	stars = star_n
	host = host_id
	kind = "legend" if info.legend else ("peak" if info.peak else ("boss" if info.boss else "level"))
	radius = {"level": 46.0, "boss": 66.0, "legend": 74.0, "peak": 58.0}[kind]
	var box: = radius * 2.0 + 40.0
	size = Vector2(box, box + 34.0)
	pivot_offset = Vector2(box * 0.5, box * 0.5)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = UI.font("body", 900)
	fx_on = V9Feel.can_fx()
	_build_art()
	return self


func centre() -> Vector2:
	return Vector2(size.x * 0.5, size.x * 0.5)


func locked() -> bool:
	return state in ["locked", "arc_locked"]


func _build_art() -> void:
	var c: = centre()
	if kind == "boss" and host != "":
		var r: = radius * 0.86
		_portrait = Common.avatar(host, Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), "gold")
		add_child(_portrait)
		if locked():
			# the portrait's shader ignores modulate: a dark veil and a lock on top instead
			var veil: = Polygon2D.new()
			var pts: = PackedVector2Array()
			for k in 40:
				var a: = TAU * k / 40.0
				pts.append(c + Vector2(cos(a), sin(a)) * (r - 2.0))
			veil.polygon = pts
			veil.color = Color(0.06, 0.04, 0.09, 0.62)
			add_child(veil)
			var lk: = V8Art.icon("lock")
			if lk:
				add_child(UI.tex(lk, Rect2(c - Vector2(26, 26), Vector2(52, 52))))
		var fr: Texture2D = load(Rules.OLD_MAP_DIR + "boss_frame.png") if ResourceLoader.exists(Rules.OLD_MAP_DIR + "boss_frame.png") else null
		if fr:
			var fs: = Vector2(radius * 2.5, radius * 2.5 * 236.0 / 220.0)
			_frame = UI.tex(fr, Rect2(c - Vector2(fs.x * 0.5, fs.y * 0.56), fs))
			add_child(_frame)
	elif kind == "peak":
		var t: = Rules.icon("peak")
		if t:
			var s: = radius * 2.3
			_peak = UI.tex(t, Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)))
			add_child(_peak)
			if locked():
				_peak.modulate = Color(0.5, 0.5, 0.58)
				_veil(c, radius * 0.86)
	elif kind == "legend":
		var t2: = Rules.icon("crown")
		if t2:
			var s2: = radius * 1.5
			_crown = UI.tex(t2, Rect2(c + Vector2(-s2 * 0.5, -radius - s2 * 0.62), Vector2(s2, s2)))
			_crown.pivot_offset = Vector2(s2, s2) * 0.5
			add_child(_crown)
			if state == "bypass":
				_crown.modulate = Color(0.35, 0.33, 0.4, 0.75)
			elif locked():
				_crown.modulate = Color(0.55, 0.52, 0.6)


func _veil(c: Vector2, r: float) -> void:
	var veil: = Polygon2D.new()
	var pts: = PackedVector2Array()
	for k in 40:
		var a: = TAU * k / 40.0
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	veil.polygon = pts
	veil.color = Color(0.06, 0.04, 0.09, 0.55)
	add_child(veil)
	var lk: = V8Art.icon("lock")
	if lk:
		add_child(UI.tex(lk, Rect2(c - Vector2(24, 24), Vector2(48, 48))))


func _process(dt: float) -> void:
	_t += dt
	if not fx_on:
		return
	if state == "current" or tier == "very_hard" or tier == "legendary" or (intro != "" and not locked()):
		queue_redraw()
	if _crown and not locked():
		_crown.position.y = centre().y - radius - _crown.size.y * 0.62 + sin(_t * 2.2) * 4.0
		_crown.rotation = sin(_t * 1.3) * 0.05


func _draw() -> void:
	var c: = centre()
	var lk: = locked()
	var look: = Rules.tier_look(tier)
	var top: Color = look.top
	var bot: Color = look.bot
	var rim: Color = look.rim
	if lk:
		top = Color(0.42, 0.4, 0.46)
		bot = Color(0.2, 0.19, 0.23)
		rim = Color(0.55, 0.53, 0.6)
	# soft ground shadow
	_ellipse(c + Vector2(0, radius * 0.86), Vector2(radius * 0.95, radius * 0.26), Color(0, 0, 0, 0.35))
	# current: breathing halo
	if state == "current":
		var k: = 0.5 + 0.5 * sin(_t * 3.2)
		draw_circle(c, radius * (1.28 + 0.1 * k), Color(1.0, 0.86, 0.55, 0.16 + 0.12 * k))
		draw_arc(c, radius * (1.2 + 0.12 * k), 0, TAU, 64, Color(1.0, 0.9, 0.62, 0.75 - 0.4 * k), 4.0, true)
	if tier == "very_hard" and not lk:
		var k2: = 0.5 + 0.5 * sin(_t * 4.4)
		draw_arc(c, radius * (1.14 + 0.08 * k2), 0, TAU, 64, Color(1.0, 0.35, 0.45, 0.5 * (1.0 - k2)), 5.0, true)
	if kind == "peak":
		if lk:
			_fog(c, Color(0.85, 0.86, 0.95, 0.42))
		_draw_label(c, "Пик")
		_draw_stars(c)
		return
	if kind == "boss":
		draw_arc(c, radius * 0.9, 0, TAU, 72, top if not lk else rim, 6.0, true)
		_draw_flames(c, look, lk)
		_draw_stars(c)
		_draw_num_chip(c, lk)
		return
	# orb: rim ring, gradient body, gloss
	draw_circle(c, radius + 6.0, rim.darkened(0.25))
	draw_circle(c, radius + 3.0, rim)
	var steps: = 14
	for s in steps:
		var f: = float(s) / float(steps - 1)
		var rr: = radius * (1.0 - f * 0.92)
		var col: = bot.lerp(top, pow(f, 0.7))
		draw_circle(c + Vector2(0, -radius * 0.18 * f), rr, col)
	_ellipse(c + Vector2(0, -radius * 0.48), Vector2(radius * 0.58, radius * 0.24), Color(1, 1, 1, 0.33 if not lk else 0.12))
	if state == "done":
		draw_arc(c, radius + 3.0, 0, TAU, 64, Color("ffe7a6"), 3.0, true)
	if lk:
		_draw_lock(c)
	else:
		var txt: = str(num)
		var fs: = 34 if txt.length() < 3 else 28
		if kind == "legend":
			fs = 38
		var tc: = Color("3a1d12") if tier in ["normal", "legendary", "tutorial", "easy"] else Color.WHITE
		var sz: = _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
		var p: = c + Vector2(-sz.x * 0.5, fs * 0.36)
		if tc == Color.WHITE:
			draw_string_outline(_font, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color(0.18, 0.05, 0.1, 0.85))
		draw_string(_font, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, tc)
	_draw_flames(c, look, lk)
	_draw_stars(c)
	if intro != "" and not lk and state != "done":
		_draw_new(c)


func _draw_num_chip(c: Vector2, lk: bool) -> void:
	var txt: = str(num)
	var fs: = 22
	var sz: = _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
	var r: = Rect2(c + Vector2(-sz.x * 0.5 - 14, radius * 0.9), Vector2(sz.x + 28, 30))
	draw_style_box(_pill(Color(0.12, 0.07, 0.1, 0.92) if not lk else Color(0.2, 0.2, 0.24, 0.9), Color("e8c47e")), r)
	draw_string(_font, Vector2(r.position.x + 14, r.position.y + 23), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("ffe7c4"))


func _pill(bg: Color, border: Color) -> StyleBoxFlat:
	var sb: = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(15)
	sb.anti_aliasing = true
	return sb


func _draw_label(c: Vector2, txt: String) -> void:
	var fs: = 20
	var label: = "%s %d" % [txt, num]
	var sz: = _font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
	var r: = Rect2(c + Vector2(-sz.x * 0.5 - 12, radius * 0.78), Vector2(sz.x + 24, 28))
	draw_style_box(_pill(Color(0.1, 0.1, 0.16, 0.9), Color("c9d3ef")), r)
	draw_string(_font, Vector2(r.position.x + 12, r.position.y + 21), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("eef2ff"))


func _draw_stars(c: Vector2) -> void:
	if state != "done" and stars <= 0:
		return
	var y: = c.y + radius + (26.0 if kind in ["level", "legend"] else 52.0)
	if kind == "peak":
		y = c.y + radius + 46.0
	for s in 3:
		var p: = Vector2(c.x + (s - 1) * 26.0, y - (6.0 if s == 1 else 0.0))
		var on: = s < stars
		_star(p, 12.0, Color("ffd75e") if on else Color(0.2, 0.17, 0.22, 0.85), Color("8a5a12") if on else Color(0.45, 0.42, 0.5))


func _draw_flames(c: Vector2, look: Dictionary, lk: bool) -> void:
	var n: = int(look.flames)
	if n <= 0 or n >= 3 or lk:
		return
	for f in n:
		var x: = c.x + (f - (n - 1) * 0.5) * 24.0
		var base: = Vector2(x, c.y - radius - 6.0)
		var fl: = 1.0 + (0.12 * sin(_t * 9.0 + f * 1.7) if fx_on else 0.0)
		var h: = 26.0 * fl
		var outer: = PackedVector2Array([base + Vector2(-10, 0), base + Vector2(-9, -h * 0.45), base + Vector2(-3, -h * 0.7),
			base + Vector2(0, -h), base + Vector2(4, -h * 0.62), base + Vector2(9, -h * 0.42), base + Vector2(10, 0)])
		draw_colored_polygon(outer, Color("ff7a3c") if tier == "very_hard" else Color("c77dff"))
		var inner: = PackedVector2Array([base + Vector2(-5, 0), base + Vector2(-4, -h * 0.35), base + Vector2(0, -h * 0.62),
			base + Vector2(4, -h * 0.35), base + Vector2(5, 0)])
		draw_colored_polygon(inner, Color("ffe58a") if tier == "very_hard" else Color("f3dcff"))


func _draw_lock(c: Vector2) -> void:
	var body: = Rect2(c + Vector2(-15, -6), Vector2(30, 24))
	draw_arc(c + Vector2(0, -6), 10.0, PI, TAU, 16, Color(0.85, 0.83, 0.9, 0.9), 4.0, true)
	var sb: = StyleBoxFlat.new()
	sb.bg_color = Color(0.85, 0.83, 0.9, 0.9)
	sb.set_corner_radius_all(5)
	draw_style_box(sb, body)
	draw_circle(c + Vector2(0, 5), 3.5, Color(0.25, 0.23, 0.3))


func _draw_new(c: Vector2) -> void:
	var k: = 0.5 + 0.5 * sin(_t * 5.0)
	var p: = c + Vector2(radius * 0.78, -radius * 0.78)
	draw_circle(p, 15.0 + 2.0 * k, Color("ff5d8f"))
	draw_circle(p, 15.0 + 2.0 * k, Color("ffd1de"), false, 2.5, true)
	_star(p, 8.0, Color.WHITE, Color.WHITE)


func _fog(c: Vector2, col: Color) -> void:
	for k in 4:
		var off: = Vector2(sin(_t * 0.7 + k * 1.9) * 10.0, cos(_t * 0.5 + k) * 4.0)
		_ellipse(c + Vector2((k - 1.5) * radius * 0.5, radius * (0.35 + 0.1 * k)) + off, Vector2(radius * 0.7, radius * 0.22), col)


func _ellipse(c: Vector2, r: Vector2, col: Color) -> void:
	var pts: = PackedVector2Array()
	for k in 28:
		var a: = TAU * k / 28.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	draw_colored_polygon(pts, col)


func _star(c: Vector2, r: float, fill: Color, edge: Color) -> void:
	var pts: = PackedVector2Array()
	for k in 10:
		var a: = -PI * 0.5 + PI * k / 5.0
		var rr: = r if k % 2 == 0 else r * 0.45
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	draw_colored_polygon(pts, fill)
	pts.append(pts[0])
	draw_polyline(pts, edge, 1.6, true)
