class_name V10MjClassicStyle
extends RefCounted

# «Тишина и лак» (UX_RULES §6) for the classic lane: tokens (1:1 with DS when v10/design/tokens.gd lands), fonts,
# and the four button classes drawn in code (Игра — rose pill, Вторичная — text/glass, Тихая — 48 icon in an 80
# hit, plus the round help buttons of the match). Every press goes through V9Feel.

const TOK: = {
	"night900": V10DS.NIGHT_900, "night800": V10DS.NIGHT_800, "night700": V10DS.NIGHT_700, "night600": V10DS.NIGHT_600,
	"paper100": V10DS.PAPER_100, "paper300": V10DS.PAPER_300, "paper500": V10DS.PAPER_500, "paper700": V10DS.PAPER_700,
	"gold300": V10DS.GOLD_300, "gold500": V10DS.GOLD_500, "gold700": V10DS.GOLD_700,
	"rose300": V10DS.ROSE_300, "rose500": V10DS.ROSE_500, "rose700": V10DS.ROSE_700,
	"jade300": V10DS.JADE_300, "jade500": V10DS.JADE_500, "cinnabar": Color("c8463c"), "ember": V10DS.EMBER,
}

const HERO_ACCENT: = {"mc": "ff8fb8", "rin": "4fbf9f", "hana": "ffb35c", "yue": "c8b6ff", "nova": "4fe3ff",
	"kohaku": "ff9b54", "zlata": "ff7a45", "minamo": "7fd3e6", "vesper": "b07cff", "sigrid": "a9d8ff"}
# the salon zone / table of each founder (MODES §4.1 «Стол — её зона Салона»)
const HERO_TABLE: = {"mc": "default", "rin": "bg_teahouse", "hana": "bg_festival", "yue": "bg_palace", "nova": "bg_neon"}
const HERO_BG: = {"mc": "menu_blur", "rin": "bg_teahouse_blur", "hana": "bg_festival_blur", "yue": "bg_palace_blur", "nova": "bg_neon_blur"}


static func c(k: String) -> Color:
	return TOK[k]


static func accent(hero: String) -> Color:
	var tree: = Engine.get_main_loop() as SceneTree
	var g = tree.root.get_node_or_null("G") if tree else null
	if g and g.get("HEROES") is Dictionary and (g.HEROES as Dictionary).has(hero):
		return g.HEROES[hero].color
	if V10DS.HEROES.has(hero):
		return V10DS.HEROES[hero].accent
	return Color(String(HERO_ACCENT.get(hero, "ff8fb8")))


static func font(kind: = "body", weight: = 800) -> Font:
	return UI.font(kind, weight)


# Playfair Italic (combo «×4», the name of her Приём)
static func italic() -> Font:
	var p: = "res://assets/fonts/playfair-i-cyr.woff2"
	return load(p) if ResourceLoader.exists(p) else UI.font("title", 700)


static func label(text: String, size: int, col: Color, kind: = "body", weight: = 800) -> Label:
	var l: = Label.new()
	l.text = text
	var ls: = LabelSettings.new()
	ls.font = UI.font_for(kind, size, weight)
	ls.font_size = size
	ls.font_color = col
	l.label_settings = ls
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func shadow(l: Label, a: = 0.55) -> Label:
	l.label_settings.shadow_color = Color(0, 0, 0, a)
	l.label_settings.shadow_offset = Vector2(0, 2)
	l.label_settings.shadow_size = 6
	return l


static func now() -> float:
	return Time.get_ticks_msec() / 1000.0


# ---------------------------------------------------------------------------------------------------------------
# a drawn button. kind: "play" (rose pill, Playfair 32), "second" (text paper100 + arrow, glass), "quiet" (icon 48
# in an 80 hit, caption under it), "help" (the round help buttons of the match: icon, caption, count «∞»)
class Btn:
	extends Control
	signal pressed
	var kind: = "second"
	var text: = ""
	var icon: = ""          # drawn glyph id: hint, undo, shuffle, pause, view3d, viewflat, heart, back, close, play
	var count: = ""
	var accent: = V10DS.ROSE_500
	var enabled: = true
	var on: = false
	var _down: = false
	var _breath: = 0.0
	var breathe: = false
	var backdrop: = false   # quiet: a soft dark disc under the glyph (over a busy band picture)

	func _init(k: = "second", t: = "", ic: = "") -> void:
		kind = k
		text = t
		icon = ic
		mouse_filter = Control.MOUSE_FILTER_STOP
		focus_mode = Control.FOCUS_NONE
		custom_minimum_size = Vector2(V10DS.HIT_MIN, V10DS.HIT_MIN)
		set_meta("ux_role", "primary" if k == "play" else ("secondary" if k == "second" else "tertiary"))

	func _ready() -> void:
		pivot_offset = size * 0.5
		resized.connect(func(): pivot_offset = size * 0.5)

	func _process(dt: float) -> void:
		if breathe and enabled and kind == "play":
			_breath += dt
			var k: = 0.9925 + 0.0075 * cos(_breath * TAU / 3.2)
			if not _down:
				scale = Vector2(k, k)

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventScreenTouch or (e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT):
			if e.pressed:
				_down = true
				if enabled:
					V9Feel.press_down(self)
				accept_event()
			elif _down:
				_down = false
				var inside: = Rect2(Vector2.ZERO, size).has_point(e.position)
				if enabled:
					V9Feel.press_up(self, inside, "pop" if kind != "play" else "select")
					if inside:
						pressed.emit()
				else:
					V9Feel.deny(self)
				accept_event()

	func _draw() -> void:
		var T: = V10MjClassicStyle.TOK
		var r: = Rect2(Vector2.ZERO, size)
		match kind:
			"play":
				var col: Color = T.rose500 if enabled else T.night600
				draw_style_box(_pill(col), r)
				var f: = UI.font("title", 600)
				var fs: = 32
				var w: = f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				draw_string(f, Vector2((size.x - w) * 0.5, size.y * 0.5 + fs * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, T.night900 if enabled else T.paper700)
			"second":
				var sb: = StyleBoxFlat.new()
				sb.bg_color = Color(T.night700, 0.72)
				sb.set_corner_radius_all(4)
				sb.border_color = Color(T.gold700, 0.35)
				sb.set_border_width_all(1)
				draw_style_box(sb, r)
				var f2: = UI.font("body", 800)
				var fs2: = 24
				var w2: = f2.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x
				var x0: = (size.x - w2) * 0.5 - (10 if icon != "" else 0)
				draw_string(f2, Vector2(x0, size.y * 0.5 + fs2 * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, T.paper100 if enabled else T.paper700)
				if icon != "":
					V10MjClassicStyle.glyph(self, icon, Vector2(x0 + w2 + 20, size.y * 0.5), 18, T.gold500)
			"quiet":
				var col2: Color = T.gold300 if on else T.paper300
				if backdrop:
					draw_circle(Vector2(size.x * 0.5, size.y * 0.5 - (10 if text != "" else 0)), 30, Color(T.night900, 0.55))
				V10MjClassicStyle.glyph(self, icon, Vector2(size.x * 0.5, size.y * 0.5 - (10 if text != "" else 0)), 24, col2)
				if text != "":
					var f3: = UI.font("body", 800)
					var fs3: = 18
					var w3: = f3.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs3).x
					draw_string(f3, Vector2((size.x - w3) * 0.5, size.y - 8), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs3, T.paper500)
			"help":
				var d: = minf(size.x, size.y - 30)
				var cc: = Vector2(size.x * 0.5, d * 0.5 + 2)
				draw_circle(cc, d * 0.5, Color(T.night700, 0.92))
				draw_arc(cc, d * 0.5 - 1, 0, TAU, 48, Color(T.gold700, 0.55), 1.5, true)
				V10MjClassicStyle.glyph(self, icon, cc, d * 0.27, T.paper100 if enabled else T.paper700)
				if count != "":
					var bc: = cc + Vector2(d * 0.34, -d * 0.34)
					draw_circle(bc, 15, T.night800)
					draw_arc(bc, 15, 0, TAU, 24, Color(T.gold500, 0.8), 1.5, true)
					var f4: = UI.font("body", 900)
					var w4: = f4.get_string_size(count, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
					draw_string(f4, bc + Vector2(-w4 * 0.5, 7), count, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, T.gold300)
				if text != "":
					var f5: = UI.font("body", 800)
					var w5: = f5.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
					draw_string(f5, Vector2((size.x - w5) * 0.5, size.y - 4), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, T.paper300)

	func _pill(col: Color) -> StyleBoxFlat:
		var sb: = StyleBoxFlat.new()
		sb.bg_color = col
		sb.set_corner_radius_all(int(size.y * 0.5))
		sb.anti_aliasing = true
		return sb


# a control painted by a callable (drawing happens inside its own _draw)
class Paint:
	extends Control
	var painter: Callable
	func _init(f: Callable = Callable()) -> void:
		painter = f
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		if painter.is_valid():
			painter.call(self)


# monoline icons (UX §6.4: grid 48, stroke 2.5, round caps), drawn so the lane needs no icon files
static func glyph(ci: CanvasItem, id: String, c: Vector2, r: float, col: Color) -> void:
	var w: = maxf(2.0, r * 0.13)
	match id:
		"hint":  # a lamp: bulb + rays
			ci.draw_arc(c + Vector2(0, -r * 0.15), r * 0.55, PI * 0.8, PI * 2.2, 24, col, w, true)
			ci.draw_line(c + Vector2(-r * 0.32, r * 0.35), c + Vector2(r * 0.32, r * 0.35), col, w, true)
			ci.draw_line(c + Vector2(-r * 0.22, r * 0.62), c + Vector2(r * 0.22, r * 0.62), col, w, true)
			ci.draw_line(c + Vector2(-r * 0.36, r * 0.18), c + Vector2(-r * 0.32, r * 0.35), col, w, true)
			ci.draw_line(c + Vector2(r * 0.36, r * 0.18), c + Vector2(r * 0.32, r * 0.35), col, w, true)
		"undo":
			ci.draw_arc(c + Vector2(r * 0.1, r * 0.1), r * 0.55, -PI * 0.95, PI * 0.55, 24, col, w, true)
			var tip: = c + Vector2(r * 0.1, r * 0.1) + Vector2(cos(-PI * 0.95), sin(-PI * 0.95)) * r * 0.55
			ci.draw_line(tip, tip + Vector2(0.0, -r * 0.38), col, w, true)
			ci.draw_line(tip, tip + Vector2(r * 0.38, 0.0), col, w, true)
		"shuffle":
			var a: = c + Vector2(-r * 0.7, -r * 0.35)
			var b: = c + Vector2(r * 0.7, r * 0.35)
			ci.draw_polyline(_curve(a, b), col, w, true)
			var a2: = c + Vector2(-r * 0.7, r * 0.35)
			var b2: = c + Vector2(r * 0.7, -r * 0.35)
			ci.draw_polyline(_curve(a2, b2), col, w, true)
			for e in [b, b2]:
				ci.draw_line(e, e + Vector2(-r * 0.25, -r * 0.12 if e == b2 else r * 0.12) + Vector2(0, -r * 0.18 if e == b else r * 0.18), col, w, true)
		"pause":
			ci.draw_line(c + Vector2(-r * 0.28, -r * 0.45), c + Vector2(-r * 0.28, r * 0.45), col, w * 1.3, true)
			ci.draw_line(c + Vector2(r * 0.28, -r * 0.45), c + Vector2(r * 0.28, r * 0.45), col, w * 1.3, true)
		"view3d":  # a stacked tile
			ci.draw_rect(Rect2(c + Vector2(-r * 0.55, -r * 0.35), Vector2(r * 0.8, r * 0.9)), col, false, w)
			ci.draw_rect(Rect2(c + Vector2(-r * 0.3, -r * 0.6), Vector2(r * 0.8, r * 0.9)), col, false, w)
		"viewflat":
			ci.draw_rect(Rect2(c + Vector2(-r * 0.45, -r * 0.5), Vector2(r * 0.9, r * 1.0)), col, false, w)
		"heart", "heart_on":
			var pts: = PackedVector2Array()
			for i in 33:
				var t: = TAU * i / 32.0
				var x: = 16.0 * pow(sin(t), 3)
				var y: = -(13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t))
				pts.append(c + Vector2(x, y) * r / 17.0)
			if id == "heart_on":
				ci.draw_colored_polygon(pts, col)
			else:
				ci.draw_polyline(pts, col, w, true)
		"back":
			ci.draw_line(c + Vector2(r * 0.25, -r * 0.5), c + Vector2(-r * 0.25, 0), col, w, true)
			ci.draw_line(c + Vector2(-r * 0.25, 0), c + Vector2(r * 0.25, r * 0.5), col, w, true)
		"next":
			ci.draw_line(c + Vector2(-r * 0.25, -r * 0.5), c + Vector2(r * 0.25, 0), col, w, true)
			ci.draw_line(c + Vector2(r * 0.25, 0), c + Vector2(-r * 0.25, r * 0.5), col, w, true)
		"close":
			ci.draw_line(c + Vector2(-r * 0.4, -r * 0.4), c + Vector2(r * 0.4, r * 0.4), col, w, true)
			ci.draw_line(c + Vector2(r * 0.4, -r * 0.4), c + Vector2(-r * 0.4, r * 0.4), col, w, true)
		"help":
			ci.draw_arc(c, r * 0.7, 0, TAU, 32, col, w, true)
			ci.draw_arc(c + Vector2(0, -r * 0.15), r * 0.22, PI, TAU + PI * 0.4, 16, col, w, true)
			ci.draw_line(c + Vector2(0, r * 0.08), c + Vector2(0, r * 0.2), col, w, true)
			ci.draw_circle(c + Vector2(0, r * 0.42), w * 0.6, col)
		"tap":  # a fingertip on a tile
			ci.draw_rect(Rect2(c + Vector2(-r * 0.62, -r * 0.7), Vector2(r * 0.86, r * 1.06)), col, false, w)
			ci.draw_arc(c + Vector2(r * 0.42, r * 0.3), r * 0.3, PI * 1.0, PI * 2.0, 12, col, w, true)
			ci.draw_line(c + Vector2(r * 0.12, r * 0.3), c + Vector2(r * 0.12, r * 0.78), col, w, true)
			ci.draw_line(c + Vector2(r * 0.72, r * 0.3), c + Vector2(r * 0.72, r * 0.78), col, w, true)
		"flower":  # five petals around a dot
			for k in 5:
				var fa: = -PI / 2 + TAU * k / 5.0
				ci.draw_arc(c + Vector2(cos(fa), sin(fa)) * r * 0.42, r * 0.26, 0, TAU, 16, col, w, true)
			ci.draw_circle(c, r * 0.12, col)
		"spark":  # her Приём: a four-point star
			var sp2: = PackedVector2Array()
			for i in 8:
				var a3: = -PI / 2 + PI * i / 4.0
				var rr2: = r if i % 2 == 0 else r * 0.3
				sp2.append(c + Vector2(cos(a3), sin(a3)) * rr2)
			sp2.append(sp2[0])
			ci.draw_polyline(sp2, col, w, true)
		"star", "star_on":
			var sp: = PackedVector2Array()
			for i in 10:
				var aa: = -PI / 2 + PI * i / 5.0
				var rr: = r if i % 2 == 0 else r * 0.45
				sp.append(c + Vector2(cos(aa), sin(aa)) * rr)
			if id == "star_on":
				ci.draw_colored_polygon(sp, col)
			else:
				sp.append(sp[0])
				ci.draw_polyline(sp, col, w * 0.8, true)


static func _curve(a: Vector2, b: Vector2) -> PackedVector2Array:
	var pts: = PackedVector2Array()
	for i in 13:
		var t: = i / 12.0
		var s: = t * t * (3.0 - 2.0 * t)
		pts.append(Vector2(lerpf(a.x, b.x, t), lerpf(a.y, b.y, s)))
	return pts


# the bottom sheet (UX §3.7: one sheet, never over another): night.700, 4 px radius, «Шёлк» in 220 ms
static func sheet(parent: Control, h: float) -> Control:
	var veil: = ColorRect.new()
	veil.color = Color(TOK.night900, 0.0)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	veil.z_index = 1000
	parent.add_child(veil)
	var p: = Panel.new()
	var sb: = StyleBoxFlat.new()
	sb.bg_color = TOK.night700
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.border_color = Color(TOK.gold700, 0.35)
	sb.border_width_top = 1
	p.add_theme_stylebox_override("panel", sb)
	var vs: = parent.get_viewport_rect().size
	veil.size = vs
	p.position = Vector2(0, vs.y)
	p.size = Vector2(vs.x, h)
	veil.add_child(p)
	var tw: = veil.create_tween().set_parallel()
	tw.tween_property(veil, "color:a", 0.55, 0.22)
	tw.tween_property(p, "position:y", vs.y - h, 0.22).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	veil.set_meta("panel", p)
	return veil


static func close_sheet(veil: Control) -> void:
	if veil == null or not is_instance_valid(veil):
		return
	var p: Control = veil.get_meta("panel")
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw: = veil.create_tween().set_parallel()
	tw.tween_property(veil, "color:a", 0.0, 0.18)
	tw.tween_property(p, "position:y", veil.get_viewport_rect().size.y, 0.18).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(veil.queue_free)
