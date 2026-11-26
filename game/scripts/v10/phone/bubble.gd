class_name V10Bubble
extends Control

# One chat bubble = one node (plus one TextureRect for a photo): background, tail, text, sticker art, voice waveform
# and the reaction chip are drawn in _draw, so 80 bubbles stay well under the node and 12 ms budget (§Р8 selftest).
# msg = {who:"h"|"me", k:"text"|"photo"|"sticker"|"voice"|"typing"|"note", t?, img?, id?, sec?}

const P: = preload("res://scripts/v10/phone/phone.gd")
const PUI: = preload("res://scripts/v10/phone/phone_ui.gd")
const D: = preload("res://scripts/v10/chat/chat_data.gd")

const FS: = 22                 # Body (§6.3); notes, captions, transcripts and timings are Caption 18
const FS_S: = 18
const PAD: = Vector2(20, 13)
const RAD: = 24.0
const STICKER: = 196.0
const PHOTO_W: = 300.0
const PHOTO_H: = 380.0

var msg: Dictionary = {}
var mine: = false
var kind: = "text"
var text: = ""
var max_w: = 440.0
var accent: = PUI.HERO_FALLBACK
var react_glyph: = ""
var tex: Texture2D = null
var fallback: Dictionary = {}
var voice_t: = -1.0           # 0..1 while «playing»
var _tw: = 0.0                # wrapped text width
var _th: = 0.0
var _dots_t: = 0.0
var index: = -1               # position in the transcript (reactions)


static func make(m: Dictionary, width: float, hero_col: Color) -> V10Bubble:
	var b: = V10Bubble.new()
	b.setup(m, width, hero_col)
	return b


func setup(m: Dictionary, width: float, hero_col: Color) -> void:
	msg = m
	mine = str(m.get("who", "h")) == "me"
	kind = str(m.get("k", "text"))
	accent = hero_col
	max_w = width
	mouse_filter = Control.MOUSE_FILTER_PASS
	size_flags_horizontal = Control.SIZE_SHRINK_END if mine else Control.SIZE_SHRINK_BEGIN
	match kind:
		"sticker":
			tex = P.sticker_tex(str(m.get("id", "")))
			if tex == null:
				fallback = D.sticker(str(m.get("id", "")))
			text = ""
		"photo":
			text = str(m.get("t", ""))
			var pt: = P.photo_tex(str(m.get("img", "")))
			if pt != null:
				var r: = Common.card_art(pt, Rect2(6, 6, PHOTO_W - 12, PHOTO_H - 12), Vector2(0.5, 0.28), 1.0, RAD - 6.0)
				(r.material as ShaderMaterial).set_shader_parameter("bottom_shade", 0.0)
				r.name = "Photo"
				r.mouse_filter = Control.MOUSE_FILTER_IGNORE
				add_child(r)
		"voice":
			text = str(m.get("t", ""))
		_:
			text = str(m.get("t", ""))
	_measure()


func set_react(glyph: String) -> void:
	react_glyph = glyph
	_measure()
	queue_redraw()


func _font() -> Font:
	return PUI.body(700)


func _measure() -> void:
	var f: = _font()
	var sz: = Vector2.ZERO
	match kind:
		"sticker":
			sz = Vector2(STICKER, STICKER)
		"typing":
			sz = Vector2(96, 54)
		"photo":
			_th = 0.0
			if text != "":
				_tw = PHOTO_W - PAD.x * 2
				_th = f.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, _tw, FS_S).y
			sz = Vector2(PHOTO_W, PHOTO_H + (_th + 18.0 if text != "" else 0.0))
		"voice":
			var w: = minf(max_w, 330.0)
			_tw = w - PAD.x * 2
			_th = f.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, _tw, FS_S).y if text != "" else 0.0
			sz = Vector2(w, 70.0 + (_th + 8.0 if text != "" else 0.0))
		"note":
			_tw = f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FS_S).x
			sz = Vector2(_tw + 36.0, 34.0)
		_:
			var one: = f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FS).x
			_tw = minf(one + 2.0, max_w - PAD.x * 2)
			_th = f.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, _tw, FS).y
			sz = Vector2(_tw + PAD.x * 2, _th + PAD.y * 2)
	if react_glyph != "":
		sz.y += 16.0
	custom_minimum_size = sz
	size = sz
	pivot_offset = Vector2(sz.x if mine else 0.0, sz.y)


func _process(dt: float) -> void:
	if kind == "typing":
		_dots_t += dt
		queue_redraw()


func _bubble_box() -> StyleBoxFlat:
	var s: = StyleBoxFlat.new()
	s.set_corner_radius_all(int(RAD))
	s.corner_detail = 10
	s.anti_aliasing = true
	if mine:
		s.bg_color = PUI.MINE_B.lerp(PUI.MINE_A, 0.35)
		s.corner_radius_bottom_right = 8
		s.border_width_top = 2
		s.border_color = Color(1, 0.86, 0.9, 0.55)
	else:
		s.bg_color = PUI.CREAM
		s.corner_radius_bottom_left = 8
		s.border_width_bottom = 3
		s.border_color = PUI.CREAM_B.darkened(0.08)
	s.shadow_color = Color(0, 0, 0, 0.28)
	s.shadow_size = 6
	s.shadow_offset = Vector2(0, 3)
	return s


func _draw() -> void:
	var f: = _font()
	var body_h: = size.y - (16.0 if react_glyph != "" else 0.0)
	var r: = Rect2(Vector2.ZERO, Vector2(size.x, body_h))
	match kind:
		"sticker":
			if tex != null:
				draw_texture_rect(tex, r, false)
			else:
				var c: = accent.lerp(Color.WHITE, 0.25)
				draw_circle(r.get_center(), STICKER * 0.42, Color(c, 0.95))
				draw_arc(r.get_center(), STICKER * 0.42, 0, TAU, 48, Color.WHITE, 6.0, true)
				var g: = str(fallback.get("glyph", "♥"))
				var gs: = f.get_string_size(g, HORIZONTAL_ALIGNMENT_LEFT, -1, 64)
				draw_string(PUI.body(900), r.get_center() + Vector2(-gs.x * 0.5, 18), g, HORIZONTAL_ALIGNMENT_LEFT, -1, 64, Color.WHITE)
				var lb: = str(fallback.get("label", ""))
				var ls: = f.get_string_size(lb, HORIZONTAL_ALIGNMENT_LEFT, -1, FS_S)
				draw_string(PUI.body(900), Vector2((r.size.x - ls.x) * 0.5, r.size.y - 22), lb, HORIZONTAL_ALIGNMENT_LEFT, -1, FS_S, Color.WHITE)
		"typing":
			draw_style_box(_bubble_box(), r)
			for i in 3:
				var k: = sin((_dots_t * 7.0) - i * 0.9)
				var y: = r.size.y * 0.5 - maxf(0.0, k) * 6.0
				draw_circle(Vector2(30 + i * 18, y), 6.0, Color(accent.darkened(0.25), 0.55 + 0.45 * maxf(0.0, k)))
		"note":
			var s: = PUI.box(Color(1, 1, 1, 0.07), 17)
			draw_style_box(s, r)
			draw_string(f, Vector2(18, 24), text, HORIZONTAL_ALIGNMENT_LEFT, -1, FS_S, PUI.MUTED)
		"photo":
			draw_style_box(_bubble_box(), r)
			if text != "":
				var col: = Color.WHITE if mine else PUI.INK
				f.draw_multiline_string(get_canvas_item(), Vector2(PAD.x, PHOTO_H + 4 + f.get_ascent(FS_S)), text, HORIZONTAL_ALIGNMENT_LEFT, _tw, FS_S, -1, col)
		"voice":
			draw_style_box(_bubble_box(), r)
			var col: = Color.WHITE if mine else accent.darkened(0.35)
			var cc: = Vector2(PAD.x + 20, 36)
			draw_circle(cc, 22, col)
			var ic: = PUI.CREAM if not mine else PUI.MINE_B
			if voice_t >= 0.0 and voice_t < 1.0:
				draw_rect(Rect2(cc + Vector2(-8, -9), Vector2(6, 18)), ic)
				draw_rect(Rect2(cc + Vector2(2, -9), Vector2(6, 18)), ic)
			else:
				draw_colored_polygon(PackedVector2Array([cc + Vector2(-6, -10), cc + Vector2(11, 0), cc + Vector2(-6, 10)]), ic)
			var bars: = 22
			var x0: = cc.x + 34
			var w: = r.size.x - x0 - PAD.x - 46
			var seed: = absi(text.hash())
			for i in bars:
				var hgt: = 8.0 + float((seed >> (i % 24)) % 7 + (i * 5) % 9) * 2.2
				var on: bool = voice_t >= 0.0 and float(i) / bars <= voice_t
				var bx: = x0 + w * float(i) / bars
				draw_line(Vector2(bx, 36 - hgt * 0.5), Vector2(bx, 36 + hgt * 0.5), Color(col, 1.0 if on else 0.42), 4.0, true)
			var secs: = "0:%02d" % int(msg.get("sec", 3))
			draw_string(f, Vector2(r.size.x - PAD.x - 40, 43), secs, HORIZONTAL_ALIGNMENT_LEFT, -1, FS_S, Color(col, 0.85))
			if text != "":
				f.draw_multiline_string(get_canvas_item(), Vector2(PAD.x, 70 + f.get_ascent(FS_S)), text, HORIZONTAL_ALIGNMENT_LEFT, _tw, FS_S, -1, Color(col, 0.8) if not mine else Color(1, 1, 1, 0.85))
		_:
			draw_style_box(_bubble_box(), r)
			var col2: = Color.WHITE if mine else PUI.INK
			f.draw_multiline_string(get_canvas_item(), Vector2(PAD.x, PAD.y + f.get_ascent(FS)), text, HORIZONTAL_ALIGNMENT_LEFT, _tw + 1.0, FS, -1, col2)
	if react_glyph != "":
		var cx: = (size.x - 26.0) if not mine else 26.0
		var cp: = Vector2(cx, body_h + 2.0)
		draw_circle(cp, 19.0, PUI.INK)
		draw_circle(cp, 16.0, PUI.CREAM)
		var gs2: = PUI.body(900).get_string_size(react_glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, FS_S)
		draw_string(PUI.body(900), cp + Vector2(-gs2.x * 0.5, 7), react_glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, FS_S, PUI.HEART_DEEP)


# spring entrance: bubbles grow from their tail corner
func appear(delay: = 0.0) -> void:
	modulate.a = 0.0
	if PUI.calm():
		create_tween().tween_property(self, "modulate:a", 1.0, 0.12).set_delay(delay)
		return
	scale = Vector2(0.4, 0.4)
	var t: = create_tween().set_parallel()
	t.tween_property(self, "scale", Vector2.ONE, 0.42).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "modulate:a", 1.0, 0.16).set_delay(delay)
