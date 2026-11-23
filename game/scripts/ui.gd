class_name UI
extends RefCounted



const PAL: = {
	"pink": [Color("e3a1b0"), Color("9a4f66"), Color("3d1624")], 
	"rose": [Color("ecc0c9"), Color("c08392"), Color("44202c")], 
	"mint": [Color("b4d8c6"), Color("5b9580"), Color("163a2d")], 
	"lav": [Color("cdbdd8"), Color("86709a"), Color("2b2138")], 
	"gold": [Color("fae4a6"), Color("c38f3c"), Color("3f2808")], 
	"cream": [Color(0.165, 0.155, 0.18, 0.96), Color(0.085, 0.08, 0.095, 0.97), Color("f5ead8")], 
	"sky": [Color("bcd0df"), Color("678aa6"), Color("1a2c3e")], 
	"plum": [Color(0.2, 0.175, 0.2, 0.93), Color(0.105, 0.095, 0.11, 0.95), Color("ffffff")], 
	"glass": [Color(0.19, 0.18, 0.205, 0.82), Color(0.08, 0.075, 0.09, 0.88), Color("f5ead8")], 
	"red": [Color("eb9aa1"), Color("b0464f"), Color("42101a")], 
	"graphite": [Color(0.215, 0.205, 0.23, 0.97), Color(0.11, 0.105, 0.12, 0.98), Color("f5ead8")], 
}
const INK: = Color("f5ead8")
const DARK: = Color(0.07, 0.055, 0.065)
const ROSE: = Color("d796a5")
const MUTED: = Color("b3a89c")

const REMAP: = {"b8406c": "e3a3b2", "9a6a8a": "bfb3a8", "7a4a6a": "ddd2c4", "8a5a7a": "bfb3a8", "8a4a6a": "ddd2c4", "9a8a9a": "a39a92", "6b3550": "f5ead8", 
	"d9c4e6": "c9bdb0", "fff1dc": "f5ead8", "f2799f": "e3a3b2", "ff8fb8": "e3a3b2", "ff7fa8": "e3a3b2", "e0457b": "d27d90", "ffd0e0": "f0d3d9", "e9dcff": "ddd2c4", "9fe8d0": "a9d9c4"}

const OUTLINE_REMAP: = {"7a2346": "2e1119", "b8406c": "3a1620", "3f2a7a": "1d1726", "5a1a6a": "251620", "3a1450": "1c1420", "1f5e49": "10261e", "1d4a7a": "121d29", "7a4a0c": "2f1f08", "6a1020": "2c0b12"}
const GOLD: = Color("e8c47e")

const T_H1: = 44
const T_H2: = 32
const T_H3: = 26
const T_BODY: = 22
const T_SMALL: = 18
const T_TINY: = 15
const TITLE_MIN: = 24

# font for a caption of `size` px: Playfair («title») only from TITLE_MIN px, Nunito below.
static func font_for(kind: String, size: int, weight: = 800) -> FontVariation:
	if kind != "body" and size < TITLE_MIN:
		return font("body", maxi(weight, 800))
	return font(kind, weight)

static var _fonts: = {}

static func font(kind: = "body", weight: = 800) -> FontVariation:
	var key: = "%s%d" % [kind, weight]
	if _fonts.has(key):
		return _fonts[key]
	var files: = ["nunito-cyr", "nunito-lat"] if kind == "body" else ["playfair-cyr", "playfair-lat"]
	var ts: = TextServerManager.get_primary_interface()
	var fv: = FontVariation.new()
	fv.base_font = load("res://assets/fonts/%s.woff2" % files[0])
	fv.variation_opentype = {ts.name_to_tag("wght"): weight}
	var fb: = FontVariation.new()
	fb.base_font = load("res://assets/fonts/%s.woff2" % files[1])
	fb.variation_opentype = {ts.name_to_tag("wght"): weight}
	fv.fallbacks = [fb]
	_fonts[key] = fv
	return fv

static func label(text: String, size: = 28, color: = INK, outline: = Color(0, 0, 0, 0), outline_size: = 0, kind: = "body", weight: = 800) -> Label:
	var l: = Label.new()
	l.text = text
	var hx: = color.to_html(false)
	if REMAP.has(hx) and REMAP[hx] != "":
		color = Color(REMAP[hx])
		if outline == Color.WHITE or outline == Color(1, 1, 1, 0.9):
			outline = DARK
	elif color == INK and outline == Color.WHITE:
		outline = DARK

	var ox: = outline.to_html(false)
	if OUTLINE_REMAP.has(ox):
		outline = Color(OUTLINE_REMAP[ox], outline.a)
	elif outline.a > 0.0 and outline.s > 0.35 and outline.v > 0.25 and (outline.h > 0.7 or outline.h < 0.05):
		outline = Color(0.16, 0.06, 0.1, outline.a)

	# 0.8: the Playfair display face is only for captions of TITLE_MIN px and up; smaller text is Nunito.
	if kind != "body" and size < TITLE_MIN:
		kind = "body"
		weight = maxi(weight, 800)
	var ls: = LabelSettings.new()
	ls.font = font(kind, weight)
	ls.font_size = size
	ls.font_color = color
	if outline_size > 0:
		ls.outline_color = outline
		ls.outline_size = outline_size
		ls.shadow_color = Color(outline.r, outline.g, outline.b, 0.45)
		ls.shadow_offset = Vector2(0, 3)
		ls.shadow_size = 2
	l.label_settings = ls
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

static func title(text: String, size: = 44, color: = Color.WHITE, outline: = Color("b8406c")) -> Label:
	return label(text, size, color, outline, max(6, size / 5), "title", 900)

static func rbox(pal: String, rect: Rect2, radius: = 28.0, border: = 4.0, margin: = 14.0) -> RBox:
	var b: = RBox.new()
	b.position = rect.position
	b.size = rect.size


	if TINT.has(pal) and rect.size.x >= 260.0 and rect.size.y >= 96.0:
		var acc: Color = PAL[pal][1]
		var g0: Color = PAL["graphite"][0]
		var g1: Color = PAL["graphite"][1]
		b.setup(g0.lerp(acc, TINT[pal]), g1.lerp(acc, TINT[pal] * 0.35), radius, border, margin)
		b.set_param("gloss", 0.08)
		b.set_param("pattern", 1.0)
		return b
	b.setup(PAL[pal][0], PAL[pal][1], radius, border, margin)
	return b

const TINT: = {"sky": 0.32, "lav": 0.32, "rose": 0.3, "pink": 0.3, "mint": 0.3, "red": 0.32, "gold": 0.26}

static func tex(t: Texture2D, rect: Rect2, keep: = true) -> TextureRect:
	var r: = TextureRect.new()
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED if keep else TextureRect.STRETCH_SCALE
	r.texture = t
	r.position = rect.position
	r.size = rect.size
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

static func center_label(l: Label, rect: Rect2) -> Label:
	l.position = rect.position
	l.size = rect.size
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l

static func pop_in(n, delay: = 0.0, from: = 0.6) -> void :
	if n is Control:
		n.pivot_offset = n.size * 0.5
	n.scale = Vector2(from, from)
	n.modulate.a = 0.0
	var t: Tween = n.create_tween().set_parallel()
	t.tween_property(n, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(delay)
	t.tween_property(n, "modulate:a", 1.0, 0.2).set_delay(delay)

static func slide_in(n, offset: Vector2, delay: = 0.0, dur: = 0.5) -> void :
	var target: Vector2 = n.position
	n.position = target + offset
	n.modulate.a = 0.0
	var t: Tween = n.create_tween().set_parallel()
	t.tween_property(n, "position", target, dur).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT).set_delay(delay)
	t.tween_property(n, "modulate:a", 1.0, dur * 0.5).set_delay(delay)

static func punch(n, amount: = 0.18, dur: = 0.35) -> void :
	if n is Control:
		n.pivot_offset = n.size * 0.5
	var t: Tween = n.create_tween()
	t.tween_property(n, "scale", Vector2.ONE * (1.0 + amount), dur * 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(n, "scale", Vector2.ONE, dur * 0.7).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

static func fmt(n: int) -> String:
	var s: = str(n)
	var out: = ""
	while s.length() > 3:
		out = " " + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out
