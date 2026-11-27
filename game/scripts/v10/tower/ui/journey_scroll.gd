class_name V10JourneyScroll
extends Control

# Свиток недели Странствия (spec R3, UX_RULES §6.8 «Свиток»): макимоно на двух осях, разворачивается от центра
# под звук бумаги (Лак 600 мс EXPO IN_OUT; при fx = min — проявление 120 мс, информация та же).
#
# На бумаге: тема недели каллиграфией (Playfair Display italic 44), одна строка темы, путь из 5 узлов-печатей
# (4 стола + босс): пройденные — киноварная печать, текущий — золотой свет, будущие — контур тушью; у узла босса —
# силуэт героини (её арт, затемнённый до туши, с контровым светом её акцента) и подлость недели одной строкой.
# При активном забеге — 3 сердца (разбитые серым) и счёт.
#
#   var s := V10JourneyScroll.new()
#   s.size = Vector2(672, V10JourneyScroll.HEIGHT); parent.add_child(s)
#   s.configure(V10Journey.week_info(), V10Journey.current_run())   # info.locked = true → свёрнутый силуэт
#   s.unroll()                                                       # сигнал unrolled в конце
#
# Цвета только из V10DS / V10TowerUI, текст через V10Type, кегли 44 / 22 / 18 (шкала HUD v2 §3).

signal unrolled

const J: = preload("res://scripts/v10/tower/journey.gd")
const U: = preload("res://scripts/v10/tower/tower_util.gd")

const PAD: = 14.0  # the axes stick out above and below the paper
const PAPER_H: = 480.0
const HEIGHT: = PAPER_H + PAD * 2.0
const ROLL_W: = 26.0  # visible paper roll around an axis (unrolled)
const BAND: = 12.0  # silk mounting band on the top and bottom edges of the paper
const T_UNROLL: = 0.6  # «Лак» (UX §6.7)
const T_CALM: = 0.12
const PATH_Y: = 240.0  # the road band on the paper

const SIL_SHADER: = """
shader_type canvas_item;
// The boss heroine as an ink silhouette with a back light of her accent (contour light from the upper right),
// a soft halo of the same colour around her and feet that melt into the paper like sumi-e mist.
uniform vec4 ink : source_color;
uniform vec4 rim : source_color;
uniform float rpx = 12.0;
uniform vec2 light = vec2(0.6, -0.8);
uniform float fade_from = 0.8;
void fragment() {
	vec2 ps = TEXTURE_PIXEL_SIZE * rpx;
	float a = texture(TEXTURE, UV).a;
	float t1 = texture(TEXTURE, UV + light * ps).a;
	float t2 = texture(TEXTURE, UV + light * ps * 2.0).a;
	float edge = a * clamp(1.0 - 0.5 * (t1 + t2), 0.0, 1.0);
	float halo = 0.0;
	for (int i = 0; i < 12; i++) {
		float ang = float(i) * 0.5235988;
		halo += texture(TEXTURE, UV + vec2(cos(ang), sin(ang)) * ps * 2.6).a;
	}
	halo = halo / 12.0 * (1.0 - a);
	vec3 col = mix(ink.rgb, rim.rgb, clamp(edge * 1.4, 0.0, 1.0));
	col = mix(rim.rgb, col, step(0.02, a));
	float alpha = max(a * ink.a, halo * rim.a);
	alpha *= 1.0 - smoothstep(fade_from, 1.0, UV.y);
	COLOR = vec4(col, alpha);
}
"""

var info: = {}
var run: = {}
var locked: = false
var reveal: = 1.0

var _clip: Control
var _content: Control
var _paper: Control
var _sil: TextureRect
var _marks: Control
var _rollers: Control
var _roll_silhouette: Control
var _title: Label
var _theme_line: Label
var _run_line: Label
var _trick_name: Label
var _trick_line: Label
var _tween: Tween
static var _sil_shader: Shader = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(672, HEIGHT)
	custom_minimum_size = size


func _ready() -> void:
	if _clip == null:
		_build()
		_apply()
	_set_reveal(reveal)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _clip != null:
		_layout()


# ---------------------------------------------------------------- public

# info = V10Journey.week_info() (+ "locked": true for the closed state), run = V10Journey.current_run() or {}
func configure(week: Dictionary, cur_run: Dictionary) -> void:
	info = week
	run = cur_run if cur_run != null else {}
	locked = bool(week.get("locked", false))
	if _clip == null:
		_build()
	_apply()


func unroll() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	if locked:
		_set_reveal(0.0)
		unrolled.emit()
		return
	V10TowerUI.sfx("feather", "whoosh", 1.0, -6.0)
	if V10TowerUI.calm():
		_set_reveal(1.0)
		modulate.a = 0.0
		_tween = create_tween()
		_tween.tween_property(self, "modulate:a", 1.0, T_CALM)
		_tween.tween_callback(func() -> void: unrolled.emit())
		return
	_set_reveal(0.0)
	_tween = create_tween()
	_tween.tween_method(_set_reveal, 0.0, 1.0, T_UNROLL).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_callback(func() -> void: unrolled.emit())


# finish at once (tests, a second build of the screen)
func show_now() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	modulate.a = 1.0
	_set_reveal(0.0 if locked else 1.0)


# node states for the path: [done, done, current, future, future] (a test hook too)
func node_states() -> Array:
	var out: = []
	var cur: = -1
	var done: = 0
	if not run.is_empty():
		done = clampi(int(run.get("board", 0)), 0, J.BOARDS)
		cur = done if done < J.BOARDS else -1
	elif int(info.get("attempts_left", 0)) > 0:
		cur = 0
	else:
		done = clampi(int((info.get("best", {}) as Dictionary).get("boards", 0)), 0, J.BOARDS)
	for i in J.BOARDS:
		out.append("done" if i < done else ("current" if i == cur else "future"))
	return out


# ---------------------------------------------------------------- build

func _build() -> void:
	_clip = Control.new()
	_clip.name = "Paper"
	_clip.clip_contents = true
	_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_clip)
	_content = Control.new()
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clip.add_child(_content)
	_paper = V10TowerUI.glyph(_draw_paper, Vector2(10, 10))
	_paper.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_content.add_child(_paper)
	_sil = TextureRect.new()
	_sil.name = "BossSilhouette"
	_sil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sil.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sil.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if _sil_shader == null:
		_sil_shader = Shader.new()
		_sil_shader.code = SIL_SHADER
	var mat: = ShaderMaterial.new()
	mat.shader = _sil_shader
	_sil.material = mat
	_content.add_child(_sil)
	_marks = V10TowerUI.glyph(_draw_marks, Vector2(10, 10))
	_content.add_child(_marks)
	var ink: = V10TowerUI.PAPER_INK
	_title = V10TowerUI.label("", "display_italic", 44, ink)
	_title.name = "Theme"
	_theme_line = V10TowerUI.label("", "ui", 22, Color(ink, 0.8))
	_theme_line.name = "ThemeLine"
	_theme_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_theme_line.max_lines_visible = 2
	_theme_line.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_run_line = V10TowerUI.label("", "ui", 22, ink)
	_run_line.name = "RunLine"
	_trick_name = V10TowerUI.label("", "ui_strong", 22, V10TowerUI.SEAL_DEEP)
	_trick_name.name = "TrickName"
	_trick_line = V10TowerUI.label("", "ui", 18, Color(ink, 0.78))
	_trick_line.name = "TrickLine"
	for l in [_title, _theme_line, _run_line, _trick_name, _trick_line]:
		_content.add_child(l)
	_rollers = V10TowerUI.glyph(_draw_rollers, Vector2(10, 10))
	add_child(_rollers)
	_roll_silhouette = V10TowerUI.glyph(_draw_rolled, Vector2(10, 10))
	add_child(_roll_silhouette)


func _apply() -> void:
	if _clip == null:
		return
	var th: Dictionary = info.get("theme", {})
	_title.text = V10TowerUI.ui_text(String(th.get("name", "")))
	_theme_line.text = V10TowerUI.ui_text(String(th.get("line", "")))
	var boss: = String(info.get("boss", "mc"))
	var trick: Dictionary = info.get("trick", {})
	_trick_name.text = V10TowerUI.ui_text("%s · %s" % [U.hero_name(boss), String(trick.get("name", ""))])
	_trick_line.text = V10TowerUI.ui_text(String(trick.get("line", "")))
	_run_line.visible = not run.is_empty()
	if not run.is_empty():
		var parts: = ["%s %s" % [fmt_num(J.total(run)), U.plural(J.total(run), "очко", "очка", "очков")]]
		var nb: = 0
		for k in (run.get("bless", {}) as Dictionary):
			nb += int(run.bless[k])
		if nb > 0:
			parts.append("%d %s" % [nb, U.plural(nb, "благословение", "благословения", "благословений")])
		if J.curse_mult(run) > 1.0:
			parts.append("очки " + U.fmt_mult2(J.curse_mult(run)))
		_run_line.text = " · ".join(parts)
	# the boss silhouette: her art, inked, with the back light of her accent
	var tex: Texture2D = null
	var p: = V10W1Core.hero_png(boss)
	if not ResourceLoader.exists(p):
		p = "res://assets/hero/mc.png"
	if ResourceLoader.exists(p):
		tex = load(p) as Texture2D
	_sil.texture = tex
	_sil.visible = tex != null and not locked
	var mat: = _sil.material as ShaderMaterial
	mat.set_shader_parameter("ink", Color(V10TowerUI.PAPER_INK, 0.92))
	mat.set_shader_parameter("rim", Color(accent_of(boss), 0.55))
	_clip.visible = not locked
	_rollers.visible = not locked
	_roll_silhouette.visible = locked
	_layout()
	for g in [_paper, _marks, _rollers, _roll_silhouette]:
		g.queue_redraw()


static func accent_of(h: String) -> Color:
	if V10DS.HEROES.has(h):
		return V10DS.hero(h).accent
	if G.HEROES.has(h):
		return G.HEROES[h].color
	return V10DS.GOLD_500


# thin-space grouping: 10 400
static func fmt_num(n: int) -> String:
	var s: = str(absi(n))
	var out: = ""
	while s.length() > 3:
		out = " " + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


# ---------------------------------------------------------------- layout

func paper_w() -> float:
	return size.x - ROLL_W


# path nodes in paper coordinates: 4 tables and the boss (the boss stands at the right, the road keeps clear of her)
func node_points() -> Array:
	var w: = paper_w()
	var bx: = w - 128.0
	var x_first: = 64.0
	var x_last: = bx - 128.0
	var step: = (x_last - x_first) / 3.0
	var ys: = [PATH_Y + 18.0, PATH_Y - 16.0, PATH_Y + 22.0, PATH_Y - 10.0]
	var pts: = []
	for i in 4:
		pts.append(Vector2(x_first + step * i, ys[i]))
	pts.append(Vector2(bx, PATH_Y + 30.0))
	return pts


func _layout() -> void:
	var w: = paper_w()
	_content.size = Vector2(w, PAPER_H)
	_paper.size = _content.size
	_marks.size = _content.size
	_rollers.size = size
	_roll_silhouette.size = size
	var x0: = 40.0
	var bp: Vector2 = node_points()[4]
	var sil_h: = 268.0
	var sil_w: = sil_h * 0.671
	_sil.size = Vector2(sil_w, sil_h)
	_sil.position = Vector2(bp.x - sil_w * 0.5, bp.y + 16.0 - sil_h)
	var text_w: = bp.x - 92.0 - x0
	_title.position = Vector2(x0, BAND + 18.0)
	_title.size = Vector2(text_w + 24.0, 56)
	_theme_line.position = Vector2(x0, BAND + 78.0)
	_theme_line.size = Vector2(minf(text_w, 380.0), 64)
	_run_line.position = Vector2(x0 + 132.0, bp.y + 46.0)
	_run_line.size = Vector2(w - x0 - _run_line.position.x, 32)
	_trick_name.position = Vector2(x0, _run_line.position.y + (54.0 if not run.is_empty() else 30.0))
	_trick_name.size = Vector2(w - x0 * 2.0, 32)
	_trick_line.position = Vector2(x0, _trick_name.position.y + 32.0)
	_trick_line.size = Vector2(w - x0 * 2.0, 26)
	_set_reveal(reveal)


func hearts_center() -> Vector2:
	return Vector2(40.0 + 18.0, _run_line.position.y + 16.0)


func _set_reveal(v: float) -> void:
	reveal = clampf(v, 0.0, 1.0)
	if _clip == null:
		return
	var W: = size.x
	var cx: = W * 0.5
	var xl1: = ROLL_W * 0.5
	var xr1: = W - ROLL_W * 0.5
	var xl: = lerpf(cx - ROLL_W * 0.6, xl1, reveal)
	var xr: = lerpf(cx + ROLL_W * 0.6, xr1, reveal)
	_clip.position = Vector2(xl, PAD)
	_clip.size = Vector2(maxf(0.0, xr - xl), PAPER_H)
	_content.position = Vector2(xl1 - xl, 0)
	_rollers.queue_redraw()


# ---------------------------------------------------------------- drawing

func _draw_paper(ci: CanvasItem, sz: Vector2) -> void:
	var r: = Rect2(Vector2.ZERO, sz)
	var tex: = V10TowerArt.tex("paper")
	if tex:
		ci.draw_texture_rect(tex, r, true)
	else:
		ci.draw_rect(r, V10TowerUI.PAPER_BG)
		var rng: = RandomNumberGenerator.new()
		rng.seed = 7151
		# washi clouds, then fibres (mostly along the sheet)
		for i in 26:
			var c: = Vector2(rng.randf() * sz.x, rng.randf() * sz.y)
			ci.draw_circle(c, rng.randf_range(30.0, 90.0), Color(V10DS.PAPER_100, rng.randf_range(0.04, 0.09)))
		for i in 34:
			var c2: = Vector2(rng.randf() * sz.x, rng.randf() * sz.y)
			ci.draw_circle(c2, rng.randf_range(20.0, 60.0), Color(V10TowerUI.PAPER_INK, rng.randf_range(0.012, 0.025)))
		for i in 340:
			var p: = Vector2(rng.randf() * sz.x, rng.randf() * sz.y)
			var a: = rng.randf_range(-0.5, 0.5) + (PI if rng.randf() < 0.5 else 0.0)
			var l: = rng.randf_range(5.0, 22.0)
			var bend: = rng.randf_range(-3.0, 3.0)
			var d: = Vector2(cos(a), sin(a)) * l
			var col: = Color(V10TowerUI.PAPER_INK, rng.randf_range(0.04, 0.09)) if i % 3 != 0 else Color(V10DS.PAPER_100, rng.randf_range(0.35, 0.6))
			ci.draw_polyline(PackedVector2Array([p, p + d * 0.5 + Vector2(0, bend), p + d]), col, 1.0, true)
	# a soft vignette into the edges
	var e: = Color(V10TowerUI.PAPER_INK, 0.10)
	var z: = Color(V10TowerUI.PAPER_INK, 0.0)
	var k: = 28.0
	ci.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(k, 0), Vector2(k, sz.y), Vector2(0, sz.y)]), PackedColorArray([e, z, z, e]))
	ci.draw_polygon(PackedVector2Array([Vector2(sz.x - k, 0), Vector2(sz.x, 0), Vector2(sz.x, sz.y), Vector2(sz.x - k, sz.y)]), PackedColorArray([z, e, e, z]))
	# the silk mounting bands (hyōgu) with one gold hairline each — the screen's only ornament
	var band: = V10TowerUI.LACQUER_HI
	ci.draw_rect(Rect2(0, 0, sz.x, BAND), band)
	ci.draw_rect(Rect2(0, sz.y - BAND, sz.x, BAND), band)
	ci.draw_line(Vector2(0, BAND + 0.5), Vector2(sz.x, BAND + 0.5), Color(V10DS.GOLD_700, 0.7), 1.0)
	ci.draw_line(Vector2(0, sz.y - BAND - 0.5), Vector2(sz.x, sz.y - BAND - 0.5), Color(V10DS.GOLD_700, 0.7), 1.0)
	ci.draw_line(Vector2(0, BAND + 3.5), Vector2(sz.x, BAND + 3.5), Color(V10TowerUI.PAPER_INK, 0.08), 1.0)


func _bez(a: Vector2, b: Vector2, n: = 18) -> PackedVector2Array:
	var out: = PackedVector2Array()
	var dx: = (b.x - a.x) * 0.5
	var c1: = a + Vector2(dx, 0)
	var c2: = b - Vector2(dx, 0)
	for i in n + 1:
		var t: = float(i) / float(n)
		var u: = 1.0 - t
		out.append(a * u * u * u + c1 * 3.0 * u * u * t + c2 * 3.0 * u * t * t + b * t * t * t)
	return out


func _draw_marks(ci: CanvasItem, _sz: Vector2) -> void:
	var pts: = node_points()
	var st: = node_states()
	var ink: = V10TowerUI.PAPER_INK
	var seal: = V10TowerUI.SEAL
	# the road: walked part in cinnabar, the rest as a dotted ink line
	for i in pts.size() - 1:
		var seg: = _bez(pts[i], pts[i + 1])
		var walked: bool = st[i] == "done" and (st[i + 1] == "done" or st[i + 1] == "current")
		if walked:
			ci.draw_polyline(seg, Color(seal, 0.25), 6.0, true)
			ci.draw_polyline(seg, Color(seal, 0.85), 2.5, true)
		else:
			for j in range(0, seg.size() - 1, 2):
				ci.draw_line(seg[j], seg[j + 1], Color(ink, 0.42), 2.5, true)
	for i in pts.size():
		var c: Vector2 = pts[i]
		var boss: = i == pts.size() - 1
		var r: = 30.0 if boss else 20.0
		match st[i]:
			"done":
				ci.draw_set_transform(c, deg_to_rad(-7.0 + 5.0 * float(i % 3)), Vector2.ONE)
				V10TowerUI.draw_seal(ci, Vector2.ZERO, r, V10TowerUI.SEAL_DEEP if boss else seal)
				ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"current":
				for k in 6:
					ci.draw_circle(c, r + 26.0 - k * 4.0, Color(V10DS.GOLD_300, 0.07 + 0.03 * k))
				ci.draw_circle(c, r * 0.95, Color(V10DS.PAPER_100, 0.85))
				ci.draw_arc(c, r, 0.0, TAU, 48, V10DS.GOLD_500, 3.0, true)
				ci.draw_circle(c, r * 0.3, V10DS.GOLD_700)
			_:
				if boss:
					ci.draw_circle(c, r, Color(V10TowerUI.PAPER_BG, 0.9))
					ci.draw_arc(c, r, 0.0, TAU, 48, Color(V10TowerUI.SEAL_DEEP, 0.75), 2.5, true)
					ci.draw_arc(c, r - 7.0, 0.0, TAU, 40, Color(V10TowerUI.SEAL_DEEP, 0.45), 1.5, true)
				else:
					var rc: = Rect2(c - Vector2(r, r) * 0.85, Vector2(r, r) * 1.7)
					ci.draw_rect(rc, Color(V10TowerUI.PAPER_BG, 0.9))
					ci.draw_rect(rc, Color(ink, 0.45), false, 2.0)
	# hearts of the run (3; lost ones are grey and cracked)
	if not run.is_empty():
		var h: = int(run.get("hearts", J.HEARTS))
		var hc: = hearts_center()
		for i in J.HEARTS:
			V10TowerUI.draw_heart(ci, hc + Vector2(i * 40.0, 0), 30.0, i < h, i >= h)


func _draw_rollers(ci: CanvasItem, sz: Vector2) -> void:
	var W: = sz.x
	var cx: = W * 0.5
	var xl: = lerpf(cx - ROLL_W * 0.6, ROLL_W * 0.5, reveal)
	var xr: = lerpf(cx + ROLL_W * 0.6, W - ROLL_W * 0.5, reveal)
	var roll: = lerpf(ROLL_W * 1.25, ROLL_W, reveal)
	for x in [xl, xr]:
		_draw_axis(ci, float(x), roll, sz.y)


func _draw_axis(ci: CanvasItem, x: float, roll: float, h: float) -> void:
	# the axis (lacquer) with gold knobs, then the paper rolled around it
	var aw: = 12.0
	ci.draw_rect(Rect2(x - aw * 0.5, 2.0, aw, h - 4.0), V10TowerUI.LACQUER)
	for y in [0.0, h - 10.0]:
		var kr: = Rect2(x - 10.0, float(y), 20.0, 10.0)
		ci.draw_rect(kr, V10DS.GOLD_700)
		ci.draw_rect(Rect2(kr.position.x + 2.0, kr.position.y + 1.0, kr.size.x - 4.0, 3.0), Color(V10DS.GOLD_300, 0.7))
	var top: = PAD - 2.0
	var bh: = PAPER_H + 4.0
	var x0: = x - roll * 0.5
	var lo: = V10TowerUI.PAPER_BG.darkened(0.42)
	var mid: = V10TowerUI.PAPER_BG.lightened(0.08)
	var hi: = V10TowerUI.PAPER_BG.darkened(0.12)
	ci.draw_polygon(PackedVector2Array([Vector2(x0, top), Vector2(x, top), Vector2(x, top + bh), Vector2(x0, top + bh)]),
		PackedColorArray([lo, mid, mid, lo]))
	ci.draw_polygon(PackedVector2Array([Vector2(x, top), Vector2(x0 + roll, top), Vector2(x0 + roll, top + bh), Vector2(x, top + bh)]),
		PackedColorArray([mid, hi.darkened(0.25), hi.darkened(0.25), mid]))
	for k in [0.3, 0.62]:
		var lx: = x0 + roll * float(k)
		ci.draw_line(Vector2(lx, top + 2.0), Vector2(lx, top + bh - 2.0), Color(V10TowerUI.PAPER_INK, 0.10), 1.0)
	# the silk bands continue on the roll
	ci.draw_rect(Rect2(x0, top, roll, BAND + 2.0), V10TowerUI.LACQUER_HI.darkened(0.15))
	ci.draw_rect(Rect2(x0, top + bh - BAND - 2.0, roll, BAND + 2.0), V10TowerUI.LACQUER_HI.darkened(0.15))


# the closed state: the scroll lies rolled and tied, as a silhouette in paper.700 (UX §6.4 «Закрытое»)
func _draw_rolled(ci: CanvasItem, sz: Vector2) -> void:
	var c: = Vector2(sz.x * 0.5, sz.y * 0.5)
	var L: = minf(sz.x - 150.0, 500.0)
	var th: = 84.0
	var body: = V10DS.PAPER_700
	var dark: = V10DS.PAPER_700.darkened(0.42)
	ci.draw_set_transform(c, deg_to_rad(-4.0), Vector2.ONE)
	# the axis with its knobs
	ci.draw_rect(Rect2(-L * 0.5 - 46.0, -8.0, L + 92.0, 16.0), V10DS.NIGHT_600)
	for sx in [-1.0, 1.0]:
		ci.draw_rect(Rect2(float(sx) * (L * 0.5 + 46.0) - 10.0, -15.0, 20.0, 30.0), V10DS.NIGHT_600)
	# the roll: a flat silhouette with a soft lower shade, a lit rim and the paper's own layers
	var top: = -th * 0.5
	ci.draw_rect(Rect2(-L * 0.5, top, L, th), body)
	ci.draw_polygon(PackedVector2Array([Vector2(-L * 0.5, th * 0.1), Vector2(L * 0.5, th * 0.1), Vector2(L * 0.5, th * 0.5), Vector2(-L * 0.5, th * 0.5)]),
		PackedColorArray([Color(dark, 0.0), Color(dark, 0.0), Color(dark, 0.8), Color(dark, 0.8)]))
	ci.draw_line(Vector2(-L * 0.5, top + 2.0), Vector2(L * 0.5, top + 2.0), Color(V10DS.PAPER_500, 0.5), 2.0)
	for k in 3:
		var ly: = top + th * (0.3 + 0.2 * k)
		ci.draw_line(Vector2(-L * 0.5 + 24.0, ly), Vector2(L * 0.5 - 24.0, ly), Color(dark, 0.25), 1.0)
	# the silk mounting at both ends of the roll
	for sx2 in [-1.0, 1.0]:
		var bx: = float(sx2) * L * 0.5 - (22.0 if sx2 > 0 else 0.0)
		ci.draw_rect(Rect2(bx, top, 22.0, th), V10DS.NIGHT_700)
	# the round end: the spiral of the rolled paper
	var ec: = Vector2(L * 0.5 + 2.0, 0.0)
	ci.draw_set_transform(c + ec.rotated(deg_to_rad(-4.0)), deg_to_rad(-4.0), Vector2(0.34, 1.0))
	ci.draw_circle(Vector2.ZERO, th * 0.5, body.darkened(0.2))
	for k in 4:
		ci.draw_arc(Vector2.ZERO, th * 0.5 - 7.0 - k * 8.0, 0.0, TAU, 32, Color(dark, 0.7), 2.0, true)
	ci.draw_set_transform(c, deg_to_rad(-4.0), Vector2.ONE)
	# the cord, tied, with its tag
	var cx2: = L * 0.16
	for dx in [0.0, 14.0]:
		ci.draw_line(Vector2(cx2 + float(dx) - 10.0, top - 2.0), Vector2(cx2 + float(dx) + 10.0, th * 0.5 + 2.0), V10DS.NIGHT_800, 5.0, true)
	ci.draw_line(Vector2(cx2 + 14.0, th * 0.5), Vector2(cx2 + 34.0, th * 0.5 + 40.0), Color(V10DS.NIGHT_800, 0.9), 2.0, true)
	ci.draw_rect(Rect2(cx2 + 22.0, th * 0.5 + 38.0, 26.0, 40.0), Color(V10DS.PAPER_700, 0.75))
	V10Icons.draw(ci, "lock_silhouette", Vector2(cx2 + 35.0, th * 0.5 + 58.0), 20.0, V10DS.NIGHT_800)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
