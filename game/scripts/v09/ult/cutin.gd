class_name V9Cutin
extends Control

# V9Cutin — 0.9 ultimate cut-in (docs/0.9-spec.md §B, docs/HEROINES.md §2 «Клип»).
#
#   var c: = V9Cutin.run(parent, outfit_id, {mode = "full" | "short", gold = false, line = 0, mirror = false})
#   await c.strong      the strong beat: the caller fires the board effect here (the strip is still up)
#   await c.finished    the clip is gone; give the board back to the player
#
# Look: the board dims to 60 %, a diagonal strip in the heroine colour slides in. One panel of it is a stop-frame of
# the equipped outfit art (V9Ults.shown: alt art in modest mode / for retired outfits) framed on face_rect, cut off
# by a gold diagonal slash; the other panel holds «УЛЬТА · <героиня>», the ult name in Playfair italic with a brush
# underline, and her shout. On the strong beat: one palette-coloured pulse (never white, ≤ 70 % value, ≤ 3 flashes
# per second across all cut-ins), a sheen over the strip, sparks and her hit sound. SSR clips open with two beats of
# an eye close-up strip. R/SR ≈ 1.33 s (Юэ in 3/4), SSR ≈ 2 s, short ≤ 0.6 s (V9Ults.clip_len).
#
# Everything is a pure function of the clip time t (_apply), so a skip, a freeze or a screenshot at an exact time is
# the same code path. A tap skips the visuals of a full clip at once (strong still fires if it has not yet); in a short
# clip taps are buffered (`buffered`, canvas positions) for the caller to replay on the board.
# Effects follow S.fx_level: «mid» = no sheen, softer pulse, fewer sparks; «min» = no streaks, sparks or pulse.
#
# Dev (screenshots): V9Cutin.dev_shots = [0.1, 0.5, …] + dev_dir / dev_name save the viewport at those clip times
# (<dir>/<name>_t<ms>.png); dev_freeze >= 0 holds the clip at that time.

signal strong
signal finished

const K: = 0.13
const BAND_H: = 300.0
const EYE_H: = 150.0
const PANEL_GAP: = 150.0
const GOLD: = Color("ffe7a6")
const GOLD_DEEP: = Color("c58a2c")
const NAME_COL: = Color("fff2d2")

static var dev_shots: Array = []
static var dev_dir: = ""
static var dev_name: = "ult"
static var dev_freeze: = -1.0
static var _flash_times: Array = []
static var _mirror_flip: = false
# the clips on screen now (covers(): board effects skip their particles where they would land on a strip)
static var _live: Array = []

var id: = ""
var u: Dictionary = {}
var pal: Dictionary = {}
var hero: = "mc"
var rar: = "R"
var mode: = "full"
var gold: = false
var dir: = 1.0
var W: = 720.0
var H: = 1280.0
var cy: = 640.0
var HW: = 440.0

var t: = 0.0
var L: = 1.33
var b: = 0.333
var eyes: = false
var T0: = 0.0
var T_in: = 0.24
var T_name: = 0.25
var T_shout: = 0.42
var Ts: = 0.67
var T_out: = 1.0
var D_out: = 0.24
var dim_a: = 0.42

var fx_ok: = true
var fx_k: = 1.0
var flash_peak: = 0.3
var buffered: Array = []

var _strong_done: = false
var _done: = false
var _skip_t: = -1.0
var _shot_i: = 0
var _shooting: = false
var _events: = {}
var _flash_on: = false
var _flash_t: = 0.0

var dim: ColorRect
var flash: ColorRect
var band: Node2D
var eye: Node2D
var art: Polygon2D
var eye_art: Polygon2D
var _art_pts: PackedVector2Array
var _eye_pts: PackedVector2Array
var _tex: Texture2D
var _eye_tex: Texture2D
var _eye_face_px: = Rect2()
var _face_px: = Rect2()
var _art_c: = Vector2.ZERO
var _art_s: = 1.0
var _eye_s: = 1.0
const EYE_MAX_ZOOM: = 1.35
var streaks: Node2D
var _streak_x0: Array = []
var _streak_v: Array = []
var sheen: Polygon2D
var _sheen_col: = Color.WHITE
var _sheen_ok: = false
var text: Node2D
var tag_l: Label
var name_clip: Control
var name_l: Label
var name_w: = 0.0
var sparks: Node2D
var slash_fx: Node2D
var underline: Polygon2D
var shout_l: Label
var _shout_y: = 0.0
var glow: Sprite2D
var medal: Node2D


static func run(parent: Control, outfit_id: String, opts: = {}) -> V9Cutin:
	var c: = V9Cutin.new()
	c._setup(parent, outfit_id, opts)
	parent.add_child(c)
	return c


static func can_flash() -> bool:
	var now: = Time.get_ticks_msec() / 1000.0
	_flash_times = _flash_times.filter( func(x): return now - float(x) < 1.0)
	return _flash_times.size() < V9Ults.MAX_FLASHES_PER_S


static func _note_flash() -> void :
	_flash_times.append(Time.get_ticks_msec() / 1000.0)


# a palette colour as a flash: never white, value ≤ FLASH_MAX
static func flash_color(c: Color) -> Color:
	var h: = c.h
	var s: = maxf(c.s, 0.45)
	var v: = minf(c.v, V9Ults.FLASH_MAX)
	return Color.from_hsv(h, s, v)


# true while a live clip's strip (or SSR eye strip) is over canvas point p (12 px margin): board-level effects that
# draw above the clip (V6Fx's match chips, the ult's target marks) skip their particles there, so nothing lands on
# the ult name, the tag or her face
static func covers(p: Vector2) -> bool:
	for c in _live:
		if not is_instance_valid(c) or c._done:
			continue
		for nd in [c.band, c.eye]:
			if nd == null or not (nd as Node2D).visible:
				continue
			var h: = BAND_H if nd == c.band else EYE_H
			var k: = K if nd == c.band else K * 0.55
			var lp: Vector2 = (nd as Node2D).get_global_transform_with_canvas().affine_inverse() * p
			if lp.y >= c._edge(lp.x, true, h, k) - 12.0 and lp.y <= c._edge(lp.x, false, h, k) + 12.0:
				return true
	return false


static func next_mirror() -> bool:
	_mirror_flip = not _mirror_flip
	return _mirror_flip


func _setup(parent: Control, outfit_id: String, opts: Dictionary) -> void :
	id = outfit_id
	u = V9Ults.get_ult(id)
	hero = String(u.get("hero", "mc"))
	rar = String(G.ITEM.get(id, {}).get("rar", "R"))
	mode = String(opts.get("mode", "full"))
	gold = bool(opts.get("gold", false))
	pal = V9Ults.palette(id, gold)
	dir = -1.0 if bool(opts.get("mirror", false)) else 1.0
	W = parent.size.x if parent.size.x > 0 else 720.0
	H = parent.size.y if parent.size.y > 0 else 1280.0
	cy = float(opts.get("cy", H * 0.5))
	HW = W * 0.5 + 90.0
	fx_ok = V9Feel.can_fx()
	fx_k = V9Feel.fx_scale()
	flash_peak = 0.3 if V9Feel.level() == "full" else 0.16
	b = V9Ults.beat_len(rar, hero)
	L = V9Ults.clip_len(rar, hero, mode)
	var n: = V9Ults.beats(rar, hero)
	if mode == "short":
		eyes = false
		T0 = 0.0
		T_in = 0.14
		T_name = 0.04
		T_shout = 99.0
		Ts = 0.2
		T_out = L - 0.2
		D_out = 0.16
		dim_a = 0.26
	else:
		eyes = rar == "SSR"
		T0 = 2.0 * b if eyes else 0.0
		T_in = 0.24
		T_name = T0 + 0.75 * b
		T_shout = T_name + 0.5 * b
		Ts = L - (2.0 * b if n >= 4 else b)
		T_out = L - 0.3
		D_out = 0.24
		dim_a = 1.0 - V9Ults.DIM
	var line_i: = int(opts.get("line", 0))
	var lines: Array = u.get("lines", [])
	var shout: = String(lines[clampi(line_i, 0, lines.size() - 1)]) if not lines.is_empty() else ""
	position = Vector2.ZERO
	size = Vector2(W, H)
	z_index = 300
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	gui_input.connect(_on_input)
	_live.append(self)
	tree_exiting.connect( func(): _live.erase(self))
	_build(shout)
	_apply(0.0)


# ── geometry ────────────────────────────────────────────────────────────────

func _edge(x: float, top: bool, h: = BAND_H, k: = K) -> float:
	return (- h * 0.5 if top else h * 0.5) - k * dir * x


func _quad(x0: float, x1: float, h: = BAND_H, k: = K) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x0, _edge(x0, true, h, k)), Vector2(x1, _edge(x1, true, h, k)),
		Vector2(x1, _edge(x1, false, h, k)), Vector2(x0, _edge(x0, false, h, k))])


func _poly(pts: PackedVector2Array, cols: Array) -> Polygon2D:
	var p: = Polygon2D.new()
	p.polygon = pts
	if cols.size() == 1:
		p.color = cols[0]
	else:
		p.vertex_colors = PackedColorArray(cols)
	p.antialiased = true
	return p


func _line(pts: PackedVector2Array, col: Color, w: float) -> Line2D:
	var l: = Line2D.new()
	l.points = pts
	l.default_color = col
	l.width = w
	l.antialiased = true
	l.joint_mode = Line2D.LINE_JOINT_ROUND
	return l


# texture coordinates for screen points `pts` so that screen point `c` shows art pixel `px_c` at `s` screen px per
# art px; shifted (and zoomed in if it must) so the polygon never samples outside the art
func _uv(pts: PackedVector2Array, c: Vector2, px_c: Vector2, s: float) -> PackedVector2Array:
	var mn: = Vector2(INF, INF)
	var mx: = Vector2(- INF, - INF)
	for p in pts:
		mn = mn.min(p)
		mx = mx.max(p)
	var ts: = _tex.get_size()
	s = maxf(s, maxf((mx.x - mn.x) / ts.x, (mx.y - mn.y) / ts.y) * 1.001)
	var lo: = px_c + (mn - c) / s
	var hi: = px_c + (mx - c) / s
	var shift: = Vector2.ZERO
	if lo.x < 0.0:
		shift.x = - lo.x
	elif hi.x > ts.x:
		shift.x = ts.x - hi.x
	if lo.y < 0.0:
		shift.y = - lo.y
	elif hi.y > ts.y:
		shift.y = ts.y - hi.y
	var out: = PackedVector2Array()
	for p in pts:
		out.append(px_c + shift + (p - c) / s)
	return out


# ── build ───────────────────────────────────────────────────────────────────

func _build(shout: String) -> void :
	var main: Color = pal.main
	var accent: Color = pal.accent
	var ink: Color = pal.ink
	dim = ColorRect.new()
	dim.size = size
	dim.color = Color(ink.r * 0.15, ink.g * 0.12, ink.b * 0.2, 0.0)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	flash = ColorRect.new()
	flash.size = size
	flash.color = flash_color(main)
	flash.modulate.a = 0.0
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)

	var sh: = V9Ults.shown(id)
	_tex = load(String(sh.img)) if ResourceLoader.exists(String(sh.img)) else null
	if _tex == null:
		_tex = load("res://assets/outfits/mc_base.webp")
		sh = V9Ults.shown("o_base")
	_face_px = V9Ults.rect_px(sh.face_rect, _tex.get_size())
	# an entry whose painting is queued for an adult-face redraw (docs/ART.md «Очередь перерисовки») points the art
	# panel at another painting of her (panel_img + panel_rect, art space), so both clip beats show the same face
	var own: = String(sh.img) == String(u.get("ref_img", ""))
	var pimg: = String(u.get("panel_img", ""))
	if pimg != "" and u.has("panel_rect") and own and ResourceLoader.exists(pimg):
		var pt: Texture2D = load(pimg)
		if pt:
			_tex = pt
			_face_px = V9Ults.rect_px(u.panel_rect, pt.get_size())
	_eye_tex = _tex
	_eye_face_px = _face_px
	# an entry may point its eye close-up at another painting of her (eye_img + eye_rect, art space)
	var ei: = String(u.get("eye_img", ""))
	if ei != "" and u.has("eye_rect") and own and ResourceLoader.exists(ei):
		var et: Texture2D = load(ei)
		if et:
			_eye_tex = et
			_eye_face_px = V9Ults.rect_px(u.eye_rect, et.get_size())
	if eyes:
		_build_eyes()
	_build_band(shout, main, accent, ink)


func _build_band(shout: String, main: Color, accent: Color, ink: Color) -> void :
	band = Node2D.new()
	band.position = Vector2(W * 0.5, cy)
	add_child(band)
	# backing: deep ink at the text end → her colour towards the art
	var c_out: = ink.darkened(0.45)
	var c_in: = main.darkened(0.18).lerp(ink, 0.25)
	var c_l: = c_out if dir > 0 else c_in
	var c_r: = c_in if dir > 0 else c_out
	band.add_child(_poly(_quad(- HW, HW), [c_l, c_r, c_r, c_l]))
	# a lighter wash along the top of the text panel (lacquer highlight)
	var wash: = _poly(_quad(- HW, HW, BAND_H * 0.5, K), [Color(main, 0.0), Color(main, 0.0), Color(main, 0.0), Color(main, 0.0)])
	var top_a: = Color(main.lightened(0.25), 0.28)
	wash.vertex_colors = PackedColorArray([top_a, top_a, Color(main, 0.0), Color(main, 0.0)])
	wash.position = Vector2(0, - BAND_H * 0.25)
	band.add_child(wash)

	streaks = Node2D.new()
	band.add_child(streaks)
	if fx_ok:
		var rng: = RandomNumberGenerator.new()
		rng.seed = hash(id)
		for i in 9:
			var y: = rng.randf_range(- BAND_H * 0.42, BAND_H * 0.42)
			var len: = rng.randf_range(110.0, 320.0)
			var th: = rng.randf_range(2.0, 5.0)
			var p: = Polygon2D.new()
			p.polygon = PackedVector2Array([Vector2(0, y), Vector2(len, y - K * dir * len), Vector2(len, y - K * dir * len + th), Vector2(0, y + th)])
			p.color = Color(main.lightened(0.55), rng.randf_range(0.14, 0.3))
			p.antialiased = true
			streaks.add_child(p)
			_streak_x0.append(rng.randf_range(- HW, HW))
			_streak_v.append(rng.randf_range(500.0, 1100.0))

	# art panel: the outfit art as a textured polygon, its inner side a diagonal slash
	var xa: = dir * W * 0.3
	var xi: = xa - dir * PANEL_GAP
	var slant: = 40.0
	var top_i: = Vector2(xi + dir * slant, _edge(xi + dir * slant, true))
	var bot_i: = Vector2(xi - dir * slant, _edge(xi - dir * slant, false))
	_art_pts = PackedVector2Array([top_i, Vector2(dir * HW, _edge(dir * HW, true)), Vector2(dir * HW, _edge(dir * HW, false)), bot_i])
	art = Polygon2D.new()
	art.polygon = _art_pts
	art.texture = _tex
	art.antialiased = true
	_art_s = BAND_H * 0.98 / _face_px.size.y
	_art_c = Vector2(xa, - K * dir * xa)
	art.uv = _uv(_art_pts, _art_c, _face_px.get_center(), _art_s)
	band.add_child(art)
	# depth: a soft shadow just inside the slash, then her colour as a rim light on the far edge
	var sd: = (bot_i - top_i).orthogonal().normalized() * (- dir)
	if sd.x * dir < 0.0:
		sd = - sd
	var shade: = _poly(PackedVector2Array([top_i, bot_i, bot_i + sd * 46.0, top_i + sd * 46.0]),
		[Color(0, 0, 0, 0.42), Color(0, 0, 0, 0.42), Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.0)])
	band.add_child(shade)
	var rim_x: = dir * HW
	var rim: = _poly(PackedVector2Array([Vector2(rim_x - dir * 120.0, _edge(rim_x - dir * 120.0, true)), Vector2(rim_x, _edge(rim_x, true)),
		Vector2(rim_x, _edge(rim_x, false)), Vector2(rim_x - dir * 120.0, _edge(rim_x - dir * 120.0, false))]),
		[Color(main, 0.0), Color(main, 0.35), Color(main, 0.35), Color(main, 0.0)])
	band.add_child(rim)
	# the slash: gold line with her colour beside it
	band.add_child(_line(PackedVector2Array([top_i + Vector2(0, -6), bot_i + Vector2(0, 6)]), Color(main.lightened(0.35), 0.9), 7.0))
	band.add_child(_line(PackedVector2Array([top_i + Vector2(0, -6), bot_i + Vector2(0, 6)]), GOLD, 3.0))

	# sheen across the strip on the strong beat (additive, palette tinted)
	# (re-shaped every frame by _sheen_at so it always sits inside the strip: never a bar across the HUD)
	sheen = Polygon2D.new()
	_sheen_col = accent.lightened(0.45).lerp(GOLD, 0.4)
	_sheen_at(- dir * HW, 0.0)
	var am: = CanvasItemMaterial.new()
	am.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	sheen.material = am
	_sheen_ok = fx_ok and V9Feel.level() == "full"
	band.add_child(sheen)

	# rims: gold edge + her colour outside it
	for top in [true, false]:
		var o: = -7.0 if top else 7.0
		band.add_child(_line(PackedVector2Array([Vector2(- HW, _edge(- HW, top) + o), Vector2(HW, _edge(HW, top) + o)]), Color(main.lightened(0.3), 0.85), 3.0))
		band.add_child(_line(PackedVector2Array([Vector2(- HW, _edge(- HW, top)), Vector2(HW, _edge(HW, top))]), GOLD, 3.5))

	# the slash's strong-beat sparks: a layer below the text panel, so they can never sit on the name or the tag
	slash_fx = Node2D.new()
	band.add_child(slash_fx)
	_build_text(shout, main, accent, ink)


func _build_text(shout: String, main: Color, accent: Color, ink: Color) -> void :
	var xt: = - dir * W * 0.235
	text = Node2D.new()
	text.position = Vector2(xt, - K * dir * xt)
	text.rotation = atan(- K * dir)
	band.add_child(text)
	var tw: = 336.0
	glow = Sprite2D.new()
	glow.texture = G.fx("glow")
	glow.material = Fx.add_mat()
	glow.modulate = Color(main, 0.32)
	glow.scale = Vector2(3.4, 1.5)
	text.add_child(glow)
	# a faint lacquer medallion behind the name: two thin rings in her colour, turning slowly
	medal = Node2D.new()
	text.add_child(medal)
	for r in [118.0, 98.0]:
		var ring: = Line2D.new()
		var rp: = PackedVector2Array()
		for i in 73:
			var a: = TAU * i / 72.0
			rp.append(Vector2(cos(a), sin(a)) * r)
		ring.points = rp
		ring.width = 2.0 if r > 100.0 else 1.2
		ring.default_color = Color(main.lightened(0.45), 0.16 if r > 100.0 else 0.1)
		ring.antialiased = true
		medal.add_child(ring)
	for i in 8:
		var a: = TAU * i / 8.0
		var tick: = Line2D.new()
		tick.points = PackedVector2Array([Vector2(cos(a), sin(a)) * 100.0, Vector2(cos(a), sin(a)) * 116.0])
		tick.width = 1.5
		tick.default_color = Color(GOLD, 0.14)
		medal.add_child(tick)

	var hero_name: String = String(G.HEROES.get(hero, {}).get("name", "")).to_upper()
	tag_l = UI.label("УЛЬТА · %s" % hero_name, 17, GOLD, ink.darkened(0.5), 4, "body", 900)
	var tf: FontVariation = (tag_l.label_settings.font as FontVariation).duplicate()
	tf.spacing_glyph = 3
	tag_l.label_settings.font = tf
	tag_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag_l.size = Vector2(tw, 24)

	var nm: String = String(u.get("name", ""))
	var f: = _name_font()
	var fs: = 56
	var nh: = 0.0
	while fs > 32:
		var longest: = 0.0
		for w in nm.split(" ", false):
			longest = maxf(longest, f.get_string_size(w, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
		nh = f.get_multiline_string_size(nm, HORIZONTAL_ALIGNMENT_CENTER, tw, fs).y
		# a name that only just fits one line touches the screen edge once the italic, outline and shadow are on
		var full: = f.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var tight: = full > tw - 36.0 and full <= tw
		if longest + 20.0 <= tw and nh <= fs * 1.25 * 2.0 and not tight:
			break
		fs -= 2
	nh = f.get_multiline_string_size(nm, HORIZONTAL_ALIGNMENT_CENTER, tw, fs).y
	var one_line: = nh <= fs * 1.4
	name_w = minf(tw, f.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 24.0) if one_line else tw
	name_l = Label.new()
	name_l.text = nm
	var ls: = LabelSettings.new()
	ls.font = f
	ls.font_size = fs
	ls.font_color = NAME_COL
	ls.outline_color = ink.darkened(0.35)
	ls.outline_size = 9
	ls.shadow_color = Color(main.darkened(0.55), 0.7)
	ls.shadow_offset = Vector2(2, 4)
	ls.shadow_size = 3
	ls.line_spacing = -fs * 0.18
	name_l.label_settings = ls
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lh: = (nh + 14.0) if not one_line else fs * 1.3
	name_l.size = Vector2(tw, lh)
	name_clip = Control.new()
	name_clip.clip_contents = true
	name_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_clip.size = Vector2(tw, lh)
	name_clip.add_child(name_l)

	shout_l = UI.label("«%s»" % shout if shout != "" else "", 23, Color.WHITE, ink.darkened(0.4), 6, "body", 800)
	shout_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shout_l.size = Vector2(tw, 32)
	shout_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	shout_l.clip_text = true

	var gap: = 6.0
	# the brush underline sits below the italic descenders (~0.2 em), not through the bottom of the letters
	var ul_drop: = maxf(4.0, fs * 0.2)
	var total: = 24.0 + gap + lh + ul_drop + 16.0 + (32.0 if mode != "short" else 0.0)
	var y: = - total * 0.5
	tag_l.position = Vector2(- tw * 0.5, y)
	y += 24.0 + gap
	name_clip.position = Vector2(- tw * 0.5, y)
	y += lh
	# brush underline: thick in the middle, tapering to both ends
	underline = Polygon2D.new()
	var uw: = minf(tw - 40.0, name_w * 0.9)
	var pts: = PackedVector2Array()
	var steps: = 18
	for i in steps + 1:
		var a: = float(i) / steps
		pts.append(Vector2(uw * a, - sin(a * PI) * 3.4 - a * 2.0))
	for i in range(steps, -1, -1):
		var a: = float(i) / steps
		pts.append(Vector2(uw * a, sin(a * PI) * 3.4 - a * 2.0))
	underline.polygon = pts
	underline.color = GOLD
	underline.antialiased = true
	underline.position = Vector2(- uw * 0.5, y + ul_drop + 4.0)
	# gold diamonds at the brush ends
	for e in [Vector2(-10.0, 0.0), Vector2(uw + 10.0, -2.0)]:
		var dm: = Polygon2D.new()
		dm.polygon = PackedVector2Array([e + Vector2(0, -5), e + Vector2(5, 0), e + Vector2(0, 5), e + Vector2(-5, 0)])
		dm.color = GOLD
		dm.antialiased = true
		underline.add_child(dm)
	y += 16.0 + ul_drop
	_shout_y = y
	shout_l.position = Vector2(- tw * 0.5, y)
	shout_l.visible = mode != "short"
	# the strong beat's sparks live here: under the name, the tag and the underline, never over the letters
	sparks = Node2D.new()
	text.add_child(sparks)
	text.add_child(tag_l)
	text.add_child(underline)
	text.add_child(name_clip)
	text.add_child(shout_l)


# the sheen: a soft leaning band centred on x, its top and bottom on the strip edges, bright only in the middle
func _sheen_at(x: float, a: float) -> void :
	var sw: = 44.0
	var lean: = 34.0 * dir
	var pts: = PackedVector2Array()
	var cols: = PackedColorArray()
	for i in 3:
		var xt: = x - lean + (i - 1) * sw
		pts.append(Vector2(xt, _edge(xt, true)))
		cols.append(Color(_sheen_col, a if i == 1 else 0.0))
	for i in range(2, -1, -1):
		var xb: = x + lean + (i - 1) * sw
		pts.append(Vector2(xb, _edge(xb, false)))
		cols.append(Color(_sheen_col, a if i == 1 else 0.0))
	sheen.polygon = pts
	sheen.vertex_colors = cols
	sheen.visible = a > 0.002 and _sheen_ok


func _name_font() -> FontVariation:
	var ts: = TextServerManager.get_primary_interface()
	var fv: = FontVariation.new()
	fv.base_font = load("res://assets/fonts/playfair-i-cyr.woff2")
	fv.variation_opentype = {ts.name_to_tag("wght"): 700}
	var fb: = FontVariation.new()
	fb.base_font = load("res://assets/fonts/playfair-i-lat.woff2")
	fb.variation_opentype = {ts.name_to_tag("wght"): 700}
	fv.fallbacks = [fb]
	return fv


func _build_eyes() -> void :
	eye = Node2D.new()
	eye.position = Vector2(W * 0.5, cy)
	add_child(eye)
	var k: = K * 0.55
	_eye_pts = _quad(- HW, HW, EYE_H, k)
	eye.add_child(_poly(_eye_pts, [Color(pal.ink.darkened(0.5))]))
	eye_art = Polygon2D.new()
	eye_art.polygon = _eye_pts
	eye_art.texture = _eye_tex
	eye_art.antialiased = true
	# 0.9 fix: the close-up was ~2.3× the 859 px painting and went soft; cap the magnification (the push adds 8 %)
	# and widen the crop instead, so the eye line stays as crisp as the tiles beside it
	_eye_s = minf(W * 0.82 / _eye_face_px.size.x, EYE_MAX_ZOOM)
	eye_art.uv = _uv(_eye_pts, Vector2.ZERO, _eye_px(), _eye_s)
	# 0.9: the paintings have light backdrops (mc_base is cream): toned to the clip palette and closed off by ink at
	# both ends, so the strip never reads as a white bar across the board (value ≤ FLASH_MAX away from the face)
	var ink: Color = pal.ink
	eye_art.color = Color(1, 1, 1).lerp((pal.main as Color).lightened(0.2), 0.16) * Color(0.9, 0.9, 0.9, 1.0)
	eye.add_child(eye_art)
	var ink_a: = Color(ink.darkened(0.55), 0.94)
	var ink_0: = Color(ink.darkened(0.55), 0.0)
	var ink_m: = Color(ink.darkened(0.4), 0.5)
	for sx in [-1.0, 1.0]:
		var pts: = PackedVector2Array()
		var cols: = PackedColorArray()
		# solid ink at the far end, a soft fade towards the face (the face spans about ±150 px)
		for seg in [[HW, 300.0, ink_a, ink_a], [300.0, 220.0, ink_a, ink_m], [220.0, 160.0, ink_m, ink_0]]:
			var x0: float = sx * float(seg[0])
			var x1: float = sx * float(seg[1])
			var q: = _quad(minf(x0, x1), maxf(x0, x1), EYE_H, k)
			var c_lo: Color = seg[2] if x0 < x1 else seg[3]
			var c_hi: Color = seg[3] if x0 < x1 else seg[2]
			eye.add_child(_poly(q, [c_lo, c_hi, c_hi, c_lo]))
	for top in [true, false]:
		var o: = -6.0 if top else 6.0
		eye.add_child(_line(PackedVector2Array([Vector2(- HW, _edge(- HW, top, EYE_H, k) + o), Vector2(HW, _edge(HW, top, EYE_H, k) + o)]), Color(pal.main.lightened(0.3), 0.85), 3.0))
		eye.add_child(_line(PackedVector2Array([Vector2(- HW, _edge(- HW, top, EYE_H, k)), Vector2(HW, _edge(HW, top, EYE_H, k))]), GOLD, 3.0))


# the eye line: a little above the face centre of face_rect (face at ~45 % of it)
func _eye_px() -> Vector2:
	return _eye_face_px.position + _eye_face_px.size * Vector2(0.5, 0.4)


# ── time line ───────────────────────────────────────────────────────────────

static func _seg(x: float, a: float, d: float) -> float:
	return clampf((x - a) / maxf(d, 0.0001), 0.0, 1.0)


static func _out_expo(x: float) -> float:
	return 1.0 if x >= 1.0 else 1.0 - pow(2.0, -10.0 * x)


static func _out_cubic(x: float) -> float:
	return 1.0 - pow(1.0 - x, 3.0)


static func _in_cubic(x: float) -> float:
	return x * x * x


func _apply(tt: float) -> void :
	# dim: in fast, eases off after the strong beat so the board effect reads, gone at the end
	var da: = dim_a * _out_cubic(_seg(tt, 0.0, 0.14))
	da *= 1.0 - 0.45 * _seg(tt, Ts, 0.25)
	da *= 1.0 - _seg(tt, T_out, L - T_out)
	dim.color.a = da
	# eye close-up (SSR): enters from the far side, slow push, collapses as the main strip arrives
	if eye:
		var ein: = _out_expo(_seg(tt, 0.0, 0.2))
		eye.position.x = W * 0.5 - dir * (1.0 - ein) * (W + 260.0)
		var col: = _seg(tt, T0 - 0.06, 0.14)
		eye.scale.y = maxf(0.0, 1.0 - _in_cubic(col))
		eye.visible = eye.scale.y > 0.01
		var z: = 1.0 + 0.08 * _seg(tt, 0.0, T0)
		eye_art.uv = _uv(_eye_pts, Vector2(dir * 10.0 * _seg(tt, 0.0, T0), 0), _eye_px(), _eye_s * z)
	# main strip
	var bin: = _out_expo(_seg(tt, T0, T_in))
	var bout: = _in_cubic(_seg(tt, T_out, D_out))
	band.position.x = W * 0.5 + dir * (1.0 - bin) * (W + 520.0) - dir * bout * (W + 520.0)
	band.visible = tt >= T0 - 0.001
	var punch: = sin(_seg(tt, Ts, 0.2) * PI) * 0.03
	band.scale = Vector2.ONE * (1.0 + punch)
	var life: = _seg(tt, T0, L - T0)
	var z2: = 1.0 + 0.05 * life
	art.uv = _uv(_art_pts, _art_c + Vector2(- dir * 16.0 * life, 0), _face_px.get_center(), _art_s * z2)
	# streaks race in the direction of travel
	for i in streaks.get_child_count():
		var s: Polygon2D = streaks.get_child(i)
		var span: = HW * 2.0 + 320.0
		var x: = fposmod(float(_streak_x0[i]) - dir * float(_streak_v[i]) * (tt - T0) + HW + 320.0, span) - HW - 320.0
		s.position = Vector2(x, - K * dir * x)
	# text
	tag_l.modulate.a = _seg(tt, T0 + 0.06, 0.16)
	var wipe: = _out_cubic(_seg(tt, T_name, 0.24))
	name_clip.size.x = name_l.size.x * wipe
	name_l.modulate.a = minf(1.0, wipe * 1.6)
	underline.scale.x = _out_cubic(_seg(tt, T_name + 0.1, 0.24))
	var sa: = _seg(tt, T_shout, 0.18)
	shout_l.modulate.a = sa
	shout_l.position.y = _shout_y + (1.0 - _out_cubic(sa)) * 10.0
	glow.modulate.a = 0.28 + 0.3 * sin(_seg(tt, Ts, 0.4) * PI)
	text.scale = Vector2.ONE * (1.0 + sin(_seg(tt, Ts, 0.22) * PI) * 0.045)
	medal.rotation = (tt - T0) * 0.5 * -dir
	medal.scale = Vector2.ONE * (0.9 + 0.1 * _out_cubic(_seg(tt, T0, 0.4)))
	medal.visible = fx_ok
	# sheen sweeps over the strip on the strong beat
	if _sheen_ok:
		var sp: = _seg(tt, Ts, 0.32)
		_sheen_at(lerpf(- dir * HW, dir * HW, sp), sin(sp * PI) * 0.4 if tt >= Ts else 0.0)
	# palette pulse
	if _flash_on:
		var fp: = _seg(tt, _flash_t, 0.28)
		flash.modulate.a = flash_peak * pow(1.0 - fp, 2.0)
	# a skip fades everything out quickly
	if _skip_t >= 0.0:
		modulate.a = 1.0 - _seg(tt, _skip_t, 0.14)


func _events_at(tt: float) -> void :
	if eyes and _once("eyes"):
		Sfx.play("summon_charge", 1.12 if gold else 1.0, -6)
	if tt >= T0 and _once("in"):
		Sfx.play("whoosh", 1.08, -2)
		V9Feel.haptic("button")
	if tt >= T_name and _once("name"):
		Sfx.play("sparkle", 1.35 if not gold else 1.5, -9)
	if tt >= Ts and _once("strong"):
		_strong()


func _once(k: String) -> bool:
	if _events.has(k):
		return false
	_events[k] = true
	return true


func _strong() -> void :
	_strong_done = true
	Sfx.play(String(u.get("sfx", "pop")), 1.06 if gold else 1.0, 0.0)
	V9Feel.big(null, "")
	if fx_ok and _skip_t < 0.0 and can_flash():
		_note_flash()
		_flash_on = true
		_flash_t = t
	if fx_ok and _skip_t < 0.0 and fx_k > 0.0:
		# 0.9: the accent sparks fly from both ends of the name, on a layer under the letters — the ult name is
		# the cleanest thing on the strong beat (it used to burst right on top of it)
		# (sparkle glyphs only, short reach, on a layer under the letters)
		var half_w: = name_w * 0.5 + 26.0
		for sx in [-1.0, 1.0]:
			Fx.burst(sparks, Vector2(sx * half_w, 0.0), "sparkle", int(11 * fx_k), (pal.accent as Color).lightened(0.35), 0.55)
		# gold sparks fly off the slash on the art side (never a blob over her face or the name): their layer sits
		# under the text panel, and they start a little into the art panel
		var sl: Vector2 = (_art_pts[0] + _art_pts[3]) * 0.5 + Vector2(dir * 22.0, 0.0)
		Fx.burst(slash_fx, sl, "sparkle", int(16 * fx_k), GOLD, 0.5)
	strong.emit()


# ── run ─────────────────────────────────────────────────────────────────────

func _process(dt: float) -> void :
	if _done or _shooting:
		return
	if dev_freeze >= 0.0 and t >= dev_freeze:
		return
	var nt: = t + dt
	if dev_freeze >= 0.0:
		nt = minf(nt, dev_freeze)
	var shot: = _shot_i < dev_shots.size() and dev_dir != "" and float(dev_shots[_shot_i]) <= nt
	if shot:
		nt = float(dev_shots[_shot_i])
	t = nt
	_events_at(t)
	_apply(t)
	if shot:
		_take_shot()
		return
	_check_end()


func _check_end() -> void :
	var end_t: = L if _skip_t < 0.0 else minf(L, _skip_t + 0.14)
	if t >= end_t and (_shot_i >= dev_shots.size() or dev_dir == ""):
		_finish()


func _take_shot() -> void :
	_shooting = true
	var k: = _shot_i
	_shot_i += 1
	await RenderingServer.frame_post_draw
	if not is_inside_tree():
		return
	var img: = get_viewport().get_texture().get_image()
	img.save_png("%s/%s_t%04d.png" % [dev_dir, dev_name, int(round(float(dev_shots[k]) * 1000.0))])
	_shooting = false
	_check_end()


func _finish() -> void :
	if _done:
		return
	_done = true
	if not _strong_done:
		_strong()
	finished.emit()
	queue_free()


func skip() -> void :
	if _skip_t >= 0.0 or _done:
		return
	_skip_t = t
	if not _strong_done:
		_events["strong"] = true
		_strong()


func _on_input(e: InputEvent) -> void :
	# GUI input: a touch arrives as an emulated left mouse button (emulate_mouse_from_touch)
	if not (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT):
		return
	accept_event()
	if mode == "short":
		var gp: Vector2 = get_global_transform_with_canvas() * (e as InputEventMouseButton).position
		# 0.9: answer the touch now by what is under the finger. A free tile: soft click, select haptic, glint, and the
		# tap is replayed on the board after the clip. A blocked tile: its deny now (not an OK click and a late deny).
		# A gap: a light tap haptic only, nothing is buffered.
		var pp: = get_parent()
		var pb = pp.get("board") if pp else null
		var tt = null
		if pb is Node and is_instance_valid(pb) and pb.has_method("tile_at"):
			tt = pb.tile_at(gp)
		if tt == null:
			V9Feel.haptic("tap")
			return
		if pb.has_method("is_free") and not pb.is_free(tt):
			if tt.has_method("deny"):
				tt.deny()
			V9Feel.tile_tap(false)
			return
		buffered.append(gp)
		V9Feel.haptic("select")
		V9Feel.sound("select", randf_range(0.96, 1.06), -6.0)
		if tt.has_method("press_glint"):
			tt.press_glint()
		return
	skip()
