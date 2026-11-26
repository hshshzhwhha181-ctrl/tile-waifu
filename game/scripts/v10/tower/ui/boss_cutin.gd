class_name V10BossCutin
extends Control

# V10BossCutin — the boss of the week announces her «подлость» before it lands (Странствие, стол 5; spec R3).
#
#   await V10BossCutin.play(parent, hero, trick)    trick = V10Journey.BOSS[hero] = {name, line, op}
#
# Look (UX §8.5 «кат-ин», the short form): one opaque diagonal strip of HER colour across the whole screen, her
# portrait art in it (head and shoulders — the strip frames the portrait rect, never a crop through the face), an
# overline «ПОДЛОСТЬ · <ИМЯ>» and the trick name in Display, one line (V10Type.fit). The table dims under it.
# ≤ 1.2 s in all, no white: the art goes through V9Cutin.TONE (value ≤ 0.7), no flash at all.
# fx_level «min»: no slide — fade in 120 ms, hold, fade out 120 ms. While it runs the node swallows every tap
# (mouse STOP, full rect); the caller turns the board input off and freezes its clocks (UX §6.6).
#
# The strip lives on its own CanvasLayer (above V6Fx particles), like V9Cutin.
# Dev: V10BossCutin.dev_freeze >= 0 holds the clip at that time (screenshots); V10BossCutin.last is the running clip.

signal finished

const LEN: = 1.15
const T_IN: = 0.22
const T_OUT: = 0.92
const CALM_FADE: = 0.12
const BAND_H: = 280.0
const K: = 0.13
const LAYER: = 61
const DIM_A: = 0.45
const SLANT: = 38.0

static var dev_freeze: = -1.0
static var last: V10BossCutin = null
static var played: = 0
static var _tone_shader: Shader

var hero: = "mc"
var trick: Dictionary = {}
var t: = 0.0
var calm: = false
var dir: = 1.0
var W: = 720.0
var H: = 1280.0
var cy: = 640.0
var HW: = 450.0
var accent: = Color.WHITE
var deep: = Color.BLACK
var layer: CanvasLayer
var band: Node2D
var text: Node2D
var over_l: Label
var name_l: Label
var dim: ColorRect
var _done: = false


static func play(parent: Control, h: String, tr: Dictionary) -> Signal:
	var c: = V10BossCutin.new()
	c._setup(parent, h, tr)
	parent.add_child(c)
	last = c
	played += 1
	return c.finished


static func colors_of(h: String) -> Dictionary:
	if V10DS.HEROES.has(h):
		var d: Dictionary = V10DS.hero(h)
		return {"accent": d.accent, "deep": d.deep}
	var c: Color = G.HEROES[h].color if G.HEROES.has(h) else V10DS.ROSE_500
	return {"accent": c, "deep": c.darkened(0.55)}


# her portrait: the base outfit art and its head-and-shoulders rect (V9Ults.shown: modest / alt art respected)
static func art_of(h: String) -> Dictionary:
	if not V9Ults.BASE.has(h):
		return {}
	var sh: = V9Ults.shown(String(V9Ults.BASE[h]))
	var img: = String(sh.get("img", ""))
	if img == "" or not ResourceLoader.exists(img):
		return {}
	var tex: Texture2D = load(img)
	if tex == null:
		return {}
	return {"tex": tex, "rect": V9Ults.rect_px(sh.alt_rect, tex.get_size())}


func _setup(parent: Control, h: String, tr: Dictionary) -> void:
	hero = h
	trick = tr
	calm = V10TowerUI.calm()
	W = parent.size.x if parent.size.x > 0.0 else 720.0
	H = parent.size.y if parent.size.y > 0.0 else 1280.0
	var br = parent.get("board_rect")
	cy = (br as Rect2).get_center().y if br is Rect2 and (br as Rect2).size.y > 0.0 else H * 0.5
	cy = clampf(cy, BAND_H, H - BAND_H)
	HW = W * 0.5 + 90.0
	var cs: = colors_of(h)
	accent = cs.accent
	deep = cs.deep
	position = Vector2.ZERO
	size = Vector2(W, H)
	z_index = 300
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	_apply(0.0)


func _edge(x: float, top: bool) -> float:
	return (-BAND_H * 0.5 if top else BAND_H * 0.5) - K * dir * x


func _quad(x0: float, x1: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x0, _edge(x0, true)), Vector2(x1, _edge(x1, true)),
		Vector2(x1, _edge(x1, false)), Vector2(x0, _edge(x0, false))])


func _build() -> void:
	dim = ColorRect.new()
	dim.size = size
	dim.color = Color(V10DS.NIGHT_900, 0.0)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	layer = CanvasLayer.new()
	layer.layer = LAYER
	layer.follow_viewport_enabled = true
	add_child(layer)
	band = Node2D.new()
	band.position = Vector2(W * 0.5, cy)
	band.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	layer.add_child(band)
	# the strip: deep at the text end -> her accent towards the art (opaque, her colour, no white)
	var c_text: = deep.darkened(0.2)
	var c_art: = deep.lerp(accent, 0.45)
	var strip: = Polygon2D.new()
	strip.polygon = _quad(-HW, HW)
	strip.vertex_colors = PackedColorArray([c_text, c_art, c_art, c_text])
	strip.antialiased = true
	band.add_child(strip)
	# the art panel: her portrait framed on its head-and-shoulders rect, the inner side a slanted cut
	var xi: = dir * 40.0
	var top_i: = Vector2(xi + dir * SLANT, _edge(xi + dir * SLANT, true))
	var bot_i: = Vector2(xi - dir * SLANT, _edge(xi - dir * SLANT, false))
	var a: = art_of(hero)
	if not a.is_empty():
		var pts: = PackedVector2Array([top_i, Vector2(dir * HW, _edge(dir * HW, true)), Vector2(dir * HW, _edge(dir * HW, false)), bot_i])
		var art: = Polygon2D.new()
		art.name = "Art"
		art.polygon = pts
		art.texture = a.tex
		art.antialiased = true
		var r: Rect2 = a.rect
		var s: = BAND_H * 0.96 / r.size.y
		var ac: = Vector2(dir * W * 0.27, -K * dir * dir * W * 0.27)
		art.uv = _uv(pts, ac, r.get_center(), s, (a.tex as Texture2D).get_size())
		art.material = _tone_mat()
		band.add_child(art)
		# depth: a soft shade inside the cut
		var sd: = Vector2(dir, 0.0) * 40.0
		var shade: = Polygon2D.new()
		shade.polygon = PackedVector2Array([top_i, bot_i, bot_i + sd, top_i + sd])
		shade.vertex_colors = PackedColorArray([Color(V10DS.NIGHT_900, 0.45), Color(V10DS.NIGHT_900, 0.45), Color(V10DS.NIGHT_900, 0.0), Color(V10DS.NIGHT_900, 0.0)])
		band.add_child(shade)
	# the cut and the rims: her accent, thin (no gold ornament in a match, UX §3.7)
	band.add_child(_line(PackedVector2Array([top_i + Vector2(0, -4), bot_i + Vector2(0, 4)]), Color(accent, 0.9), 3.0))
	for top in [true, false]:
		var o: = -2.0 if top else 2.0
		band.add_child(_line(PackedVector2Array([Vector2(-HW, _edge(-HW, top) + o), Vector2(HW, _edge(HW, top) + o)]), Color(accent, 0.85), 2.5))
	# text: overline + the trick name, along the strip
	var x0: = -W * 0.5 + 28.0
	var x1: = xi - SLANT - 20.0
	var max_w: = x1 - x0
	text = Node2D.new()
	var xt: = (x0 + x1) * 0.5
	text.position = Vector2(xt, -K * dir * xt)
	text.rotation = atan(-K * dir)
	band.add_child(text)
	var who: = String(U_name(hero)).to_upper()
	over_l = V10Type.label("ПОДЛОСТЬ · " + who, "overline", 15, V10DS.GOLD_300, true)
	over_l.position = Vector2(-max_w * 0.5, -58)
	over_l.size = Vector2(max_w, 24)
	text.add_child(over_l)
	name_l = V10Type.label("", "display", 44, V10DS.PAPER_100, true)
	var nm: = V10TowerUI.ui_text(String(trick.get("name", "")))
	if V10Type.text_w(nm, "display", 44) <= max_w:
		name_l.text = nm
		name_l.label_settings = V10Type.settings("display", 44, V10DS.PAPER_100, true)
	else:
		V10Type.fit(name_l, nm, "title_l", max_w, 1, V10DS.PAPER_100, true)
	name_l.position = Vector2(-max_w * 0.5, -34)
	name_l.size = Vector2(max_w, 60)
	text.add_child(name_l)


static func U_name(h: String) -> String:
	return V10TowerUtil.hero_name(h)


func _line(pts: PackedVector2Array, col: Color, w: float) -> Line2D:
	var l: = Line2D.new()
	l.points = pts
	l.default_color = col
	l.width = w
	l.antialiased = true
	return l


func _tone_mat() -> ShaderMaterial:
	if _tone_shader == null:
		_tone_shader = Shader.new()
		_tone_shader.code = V9Cutin.TONE
	var m: = ShaderMaterial.new()
	m.shader = _tone_shader
	m.set_shader_parameter("tint", Color.from_hsv(accent.h, clampf(accent.s * 0.75, 0.3, 0.6), 1.0))
	m.set_shader_parameter("vmax", V9Ults.FLASH_MAX)
	return m


# texture coordinates so that band point `c` shows art pixel `px_c` at `s` screen px per art px; shifted (and
# zoomed in if it must) so the polygon never samples outside the art
func _uv(pts: PackedVector2Array, c: Vector2, px_c: Vector2, s: float, ts: Vector2) -> PackedVector2Array:
	var mn: = Vector2(INF, INF)
	var mx: = Vector2(-INF, -INF)
	for p in pts:
		mn = mn.min(p)
		mx = mx.max(p)
	s = maxf(s, maxf((mx.x - mn.x) / ts.x, (mx.y - mn.y) / ts.y) * 1.001)
	var lo: = px_c + (mn - c) / s
	var hi: = px_c + (mx - c) / s
	var shift: = Vector2.ZERO
	if lo.x < 0.0:
		shift.x = -lo.x
	elif hi.x > ts.x:
		shift.x = ts.x - hi.x
	if lo.y < 0.0:
		shift.y = -lo.y
	elif hi.y > ts.y:
		shift.y = ts.y - hi.y
	var out: = PackedVector2Array()
	for p in pts:
		out.append(px_c + shift + (p - c) / s)
	return out


func _process(dt: float) -> void:
	if _done:
		return
	if dev_freeze >= 0.0:
		t = minf(dev_freeze, LEN)
		_apply(t)
		return
	t += dt
	_apply(t)
	if t >= LEN:
		_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	if last == self:
		last = null
	finished.emit()
	queue_free()


static func _ease_out(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return 1.0 - pow(1.0 - x, 5.0)


static func _ease_in(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * x


# everything is a pure function of the clip time (a freeze or a screenshot at an exact time is the same path)
func _apply(tt: float) -> void:
	if calm:
		var a: = clampf(tt / CALM_FADE, 0.0, 1.0) * clampf((LEN - tt) / CALM_FADE, 0.0, 1.0)
		band.position.x = W * 0.5
		band.modulate.a = a
		text.modulate.a = 1.0
		dim.color.a = DIM_A * a
		return
	var x: = W * 0.5
	if tt < T_IN:
		x += dir * W * 1.3 * (1.0 - _ease_out(tt / T_IN))
	elif tt > T_OUT:
		x -= dir * W * 1.3 * _ease_in((tt - T_OUT) / (LEN - T_OUT))
	band.position.x = x
	band.modulate.a = 1.0
	# the name rides in a beat after the strip, the overline first
	over_l.modulate.a = clampf((tt - 0.1) / 0.14, 0.0, 1.0)
	var k: = _ease_out((tt - 0.16) / 0.26)
	name_l.modulate.a = clampf((tt - 0.16) / 0.18, 0.0, 1.0)
	text.position.x = (-W * 0.5 + 28.0 + (dir * 40.0 - SLANT - 20.0)) * 0.5 + 36.0 * dir * (1.0 - k)
	var din: = clampf(tt / 0.18, 0.0, 1.0)
	var dout: = 1.0 - clampf((tt - T_OUT) / (LEN - T_OUT), 0.0, 1.0)
	dim.color.a = DIM_A * minf(din, dout)
