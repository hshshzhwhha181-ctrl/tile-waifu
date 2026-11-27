class_name JButton
extends Control


signal pressed
# 0.9: a tap on a disabled button (after its deny shake), so the owner can say why
signal denied
var box: RBox
var lbl: Label
var sub: Label
var icon_rect: TextureRect
# 0.8 art: call-to-action and secondary buttons draw a painted face instead of the procedural pill; `box` stays
# (hidden) so pressed/shine/colors() calls keep working.
# 0.12: the face is the imperial lacquer (Lacquer): crimson btn_lacquer_red art for the CTAs, a deep gold lacquer
# with a double rim and gold diamonds for «gold», royal plum velvet with an antique gold rim for the quiet actions.
var art: Lacquer
var sound: = "pop"
var shine_every: = 0.0
var pulse: = false
# 0.8: a disabled button looks it (dimmed, desaturated art, quieter caption) and answers a tap with a short
# «no» shake, the deny sound and the deny haptic instead of the press bounce
var disabled: = false:
	set(v):
		disabled = v
		_apply_disabled()
var _shine_t: = 0.0
var _down: = false
# 0.12: the imperial lacquer face the button draws (Lacquer below): "red" (btn_lacquer_red art), "gold", "plum",
# "jade" or "" (procedural pill only)
var _laq: = ""
# 0.9: an optional check run on release (see set_gate): false = refuse the tap with the deny feedback only
var gate: Callable

# use_art = false keeps the procedural pill for tabs (their palette is swapped via box.colors()) and toggles
static func make(text: String, pal: String, rect: Rect2, icon: Texture2D = null, font_size: = 30, radius: = -1.0, use_art: = true) -> JButton:
	var b: = JButton.new()
	b.position = rect.position
	b.size = rect.size
	b._use_art = use_art
	b.build(text, pal, icon, font_size, radius)
	return b

var _use_art: = true

# palette -> legacy btn art name. Kept as the button's `_art_name` so callers that lay out their own glyphs with
# V8Art.nine_content(b._art_name, size) (room, auth) keep their insets; the face itself is the lacquer below.
const ART_PAL: = {"pink": "primary", "gold": "primary", "red": "primary_red", "graphite": "secondary", "lav": "secondary",
	"glass": "secondary", "rose": "secondary", "plum": "secondary", "cream": "secondary", "mint": "secondary_jade",
	"play": "primary", "primary": "primary", "dark": "secondary", "teal": "secondary_jade"}
# caption colours follow the art the button actually draws, not the palette it was asked for
const ART_TEXT_PAL: = {"primary": "pink", "primary_red": "red", "secondary": "graphite", "secondary_jade": "mint"}
# 0.12 imperial lacquer: one look for the whole game (crimson lacquer × royal plum × gold)
const LAQ_PAL: = {"pink": "red", "rose": "red", "red": "red", "play": "red", "primary": "red", "gold": "gold",
	"graphite": "plum", "dark": "plum", "lav": "plum", "plum": "plum", "glass": "plum", "cream": "plum",
	"mint": "jade", "teal": "jade"}
# palettes UI.PAL does not know (0.12 aliases) fall back to their nearest procedural pill
const PAL_ALIAS: = {"play": "pink", "primary": "pink", "dark": "graphite", "teal": "mint"}
# procedural pills (tabs, toggles, round icon buttons) in the same lacquer colours: [top, bottom, rim top, rim bottom]
const LAQ_BOX: = {
	"red": [Color(0.84, 0.12, 0.16), Color(0.46, 0.02, 0.07), Color(0.98, 0.86, 0.55), Color(0.55, 0.32, 0.1)],
	"gold": [Color(1.0, 0.9, 0.58), Color(0.78, 0.52, 0.16), Color(1.0, 0.96, 0.8), Color(0.5, 0.3, 0.06)],
	"plum": [Color(0.21, 0.1, 0.28, 0.97), Color(0.1, 0.04, 0.14, 0.97), Color(0.9, 0.76, 0.47), Color(0.48, 0.32, 0.12)],
	"jade": [Color(0.12, 0.36, 0.28), Color(0.05, 0.18, 0.13), Color(0.9, 0.76, 0.47), Color(0.4, 0.28, 0.1)],
}
const ART_MIN_H: = 40.0
var _pal: = ""
var _radius: = -1.0
var _art_name: = ""

static func pal_key(pal: String) -> String:
	if UI.PAL.has(pal):
		return pal
	return String(PAL_ALIAS.get(pal, "graphite"))

static func laq_for(pal: String) -> String:
	return String(LAQ_PAL.get(pal, ""))

static func art_for(pal: String, sz: Vector2, text: String, radius: float) -> String:
	if text == "" or radius >= 0.0 or not ART_PAL.has(pal):
		return ""
	if sz.y < ART_MIN_H or sz.x < sz.y * 1.8:
		return ""
	return ART_PAL[pal]

func build(text: String, pal: String, icon: Texture2D, font_size: int, radius: float) -> void :
	mouse_filter = Control.MOUSE_FILTER_STOP
	pivot_offset = size * 0.5
	var p: Array = UI.PAL[pal_key(pal)]
	box = RBox.new()
	box.size = size
	box.setup(p[0], p[1], size.y * 0.5 if radius < 0 else radius, 4.0, 14.0)
	_box_lacquer(pal)
	add_child(box)
	var art_name: = art_for(pal, size, text, radius) if _use_art else ""
	_pal = pal
	_radius = radius
	_art_name = art_name
	var x0: = 0.0
	var x1: = 0.0
	if art_name != "":
		_laq = laq_for(pal)
		art = Lacquer.new()
		art.name = "Lacquer"
		art.style = _laq
		art.size = size
		art.pivot_offset = size * 0.5
		add_child(art)
		box.visible = false
		x0 = Lacquer.inset(_laq, size)
		x1 = x0
	if icon:
		var s: = size.y * 0.92
		var ix: = size.y * 0.06 + 4
		if art:
			s = size.y * 0.6
			ix = maxf(x0, size.y * 0.16)
		icon_rect = UI.tex(icon, Rect2(ix, (size.y - s) * 0.5, s, s))
		if art:
			icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		add_child(icon_rect)
		x0 = ix + s + 6
	if text != "":
		var ts: = _caption_style(pal)
		lbl = UI.label(text, font_size, ts[0], ts[1], ts[2], "body", 900)
		UI.center_label(lbl, Rect2(x0, 0, size.x - x0 - x1, size.y))
		if art and not "\n" in text:
			_fit_label(size.x - x0 - x1)
		add_child(lbl)
	_apply_disabled()

# the procedural pill of a lacquer palette wears the same crimson / gold / plum / jade with a gold rim
func _box_lacquer(pal: String) -> void:
	var lq: = laq_for(pal)
	if lq == "" or box == null:
		return
	var c: Array = LAQ_BOX[lq]
	box.colors(c[0], c[1])
	box.borders(c[2], c[3])

# caption [colour, outline colour, outline size] on the face this button draws
func _caption_style(pal: String) -> Array:
	var lq: = _laq if art else laq_for(pal)
	if lq != "":
		return Lacquer.text_style(lq)
	return _text_style(ART_TEXT_PAL.get(_art_name, pal_key(pal)))

# [colour, outline colour, outline size] of the caption on a palette
static func _text_style(pal: String) -> Array:
	if LAQ_PAL.has(pal):
		return Lacquer.text_style(laq_for(pal))
	var p: Array = UI.PAL[pal_key(pal)]
	if pal in ["cream", "glass", "graphite", "plum"]:
		return [UI.INK, UI.DARK, 4]
	if pal == "gold":
		return [Color("3a2410"), Color(1.0, 0.95, 0.8, 0.55), 2]
	return [Color.WHITE, p[2], 6]

# Switch the look to another palette (toggles: on/off, claim → done). Use this instead of box.colors(): an art
# button hides its box, so recolouring the box alone would change nothing on screen.
func set_pal(pal: String) -> void :
	if pal == _pal:
		return
	_pal = pal
	var an: = art_for(pal, size, lbl.text if lbl else "", _radius) if _use_art else ""
	var pk: = pal_key(pal)
	box.colors(UI.PAL[pk][0], UI.PAL[pk][1])
	_box_lacquer(pal)
	var lq: = laq_for(pal) if an != "" else ""
	if lq != "":
		if art == null:
			art = Lacquer.new()
			art.name = "Lacquer"
			art.size = size
			art.pivot_offset = size * 0.5
			add_child(art)
			move_child(art, box.get_index() + 1)
		art.style = lq
		art.queue_redraw()
		art.visible = true
		box.visible = false
		_laq = lq
	elif art:
		art.visible = false
		box.visible = true
		_laq = ""
	_art_name = an if (art and art.visible) else ""
	if lbl:
		var ts: = _caption_style(pal)
		var ls: LabelSettings = lbl.label_settings.duplicate()
		ls.font_color = ts[0]
		ls.outline_color = ts[1]
		ls.outline_size = ts[2]
		lbl.label_settings = ls
	_apply_disabled()

# a short gold glint across the lacquer (on a fired tap and on the shine_every timer)
func glint() -> void:
	if art and art.visible and art is Lacquer:
		(art as Lacquer).glint()
	elif box:
		box.shine(0.0, 0.5)

# the art's caps leave less room than the pill: shrink the caption (never below 16 px) until it fits on one line
func _fit_label(w: float) -> void :
	var ls: LabelSettings = lbl.label_settings
	var f: Font = ls.font if ls.font else UI.font("body", 900)
	var fs: = ls.font_size
	while fs > 16 and f.get_string_size(lbl.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > w:
		fs -= 1
	if fs != ls.font_size:
		ls = ls.duplicate()
		ls.font_size = fs
		lbl.label_settings = ls

# a cost line «◆ 1 500»: the currency glyph and the number as one centred group under the caption
var sub_icon: TextureRect

func set_cost(icon: Texture2D, n: int, size_px: = 22) -> void :
	set_sub(UI.fmt(n), size_px)
	var ls: LabelSettings = sub.label_settings
	var f: Font = ls.font if ls.font else UI.font("body", 900)
	var tw: = f.get_string_size(sub.text, HORIZONTAL_ALIGNMENT_LEFT, -1, ls.font_size).x
	var isz: = minf(sub.size.y * 1.15, float(size_px) * 1.5)
	if sub_icon == null:
		sub_icon = TextureRect.new()
		sub_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sub_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sub_icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		sub_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(sub_icon)
	sub_icon.texture = icon
	var gw: = isz + 4.0 + tw
	var cx: = sub.position.x + sub.size.x * 0.5
	sub_icon.position = Vector2(cx - gw * 0.5, sub.position.y + (sub.size.y - isz) * 0.5)
	sub_icon.size = Vector2(isz, isz)
	sub.position.x += (isz + 4.0) * 0.5

func set_sub(text: String, size_px: = 20) -> void :
	if sub == null:
		sub = UI.label(text, size_px, lbl.label_settings.font_color if lbl else Color.WHITE, lbl.label_settings.outline_color if lbl else UI.PAL["gold"][2], 2 if lbl and lbl.label_settings.outline_size <= 2 else 4)
		add_child(sub)
	sub.text = text
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	# on the btn art both lines keep clear of the gold rim (top ~12 %, bottom ~14 % of the height)
	lbl.position.y = size.y * (0.15 if art else 0.1)
	UI.center_label(sub, Rect2(lbl.position.x, size.y * (0.5 if art else 0.52), lbl.size.x, size.y * (0.34 if art else 0.4)))
	# never past the caps: shrink to 16 px, then trim
	var ls: LabelSettings = sub.label_settings
	var f: Font = ls.font if ls.font else UI.font("body", 800)
	var fs: = ls.font_size
	while fs > 16 and f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > lbl.size.x:
		fs -= 1
	if fs != ls.font_size:
		ls = ls.duplicate()
		ls.font_size = fs
		sub.label_settings = ls
	sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

func badge(text: = "!") -> void :
	var d: = UI.rbox("red", Rect2(size.x - 26, -8, 32, 32), 16, 3, 6)
	add_child(d)
	var l: = UI.center_label(UI.label(text, 18, Color.WHITE), Rect2(0, 0, 32, 32))
	d.add_child(l)
	var t: Tween = d.create_tween().set_loops()
	d.pivot_offset = Vector2(16, 16)
	t.tween_property(d, "scale", Vector2(1.15, 1.15), 0.5).set_trans(Tween.TRANS_SINE)
	t.tween_property(d, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_SINE)

func _process(dt: float) -> void :
	if shine_every > 0.0:
		_shine_t -= dt
		if _shine_t <= 0.0:
			_shine_t = shine_every + randf() * 1.5
			if art and art.visible:
				art.glint()
			else:
				box.shine()
	if pulse and not _down:
		var s: = 1.0 + 0.025 * sin(G.time * 3.2)
		scale = Vector2(s, s)

# 0.8: a touch target is never smaller than MIN_HIT × MIN_HIT, even when the art is (price tags, tabs, the
# currency «+»): the hit rect grows evenly around the drawn box, the box itself keeps its size
const MIN_HIT: = 64.0

func hit_rect() -> Rect2:
	var gx: = maxf(0.0, (MIN_HIT - size.x) * 0.5)
	var gy: = maxf(0.0, (MIN_HIT - size.y) * 0.5)
	return Rect2(Vector2.ZERO, size).grow_individual(gx, gy, gx, gy)

func _has_point(p: Vector2) -> bool:
	return hit_rect().has_point(p)

func _gui_input(e: InputEvent) -> void :
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_press_down()
		elif _down:
			_down = false
			_release(hit_rect().has_point(e.position))
		accept_event()

const DESAT_SHADER: = "shader_type canvas_item;\nvoid fragment() {\n\tvec4 c = texture(TEXTURE, UV) * COLOR;\n\tfloat g = dot(c.rgb, vec3(0.299, 0.587, 0.114));\n\tCOLOR = vec4(mix(c.rgb, vec3(g) * vec3(0.86, 0.84, 0.9), 0.82), c.a);\n}\n"
static var _desat_mat: ShaderMaterial

static func desat_material() -> ShaderMaterial:
	if _desat_mat == null:
		var sh: = Shader.new()
		sh.code = DESAT_SHADER
		_desat_mat = ShaderMaterial.new()
		_desat_mat.shader = sh
	return _desat_mat

func _apply_disabled() -> void :
	if box == null or (not disabled and not _dimmed):
		return
	_dimmed = disabled
	modulate = Color(0.86, 0.84, 0.9, 0.6) if disabled else Color.WHITE
	if art:
		art.material = desat_material() if disabled else null
	if icon_rect:
		icon_rect.material = desat_material() if disabled else null
	if disabled:
		shine_every = 0.0
		pulse = false
		scale = Vector2.ONE

var _dimmed: = false

# 0.9: press / release / deny feedback (scale spring, click, haptic) lives in V9Feel — one place for every tap
func _deny_shake() -> void :
	V9Feel.deny(self)

func _press_down() -> void :
	if disabled or (gate.is_valid() and not bool(gate.call())):
		_deny_shake()
		denied.emit()
		return
	_down = true
	box.set_param("pressed", 1.0)
	if art:
		art.press(true)
	V9Feel.press_down(self)

func _release(fire: bool) -> void :
	box.set_param("pressed", 0.0)
	if art:
		art.press(false)
	# 0.9: the owner's gate decides before any success feedback — a refused tap gets only the deny (shake, deny
	# sound and haptic) and `denied`, never the pop + overshoot followed by a deny in the same frame
	if fire and gate.is_valid() and not bool(gate.call()):
		V9Feel.press_up(self, false, sound)
		_deny_shake()
		denied.emit()
		return
	V9Feel.press_up(self, fire, sound)
	if fire:
		glint()
		pressed.emit()

# gate the button: `ok` returns false when a tap will be refused (not enough currency, board busy…); `on_deny` runs
# on such a tap (and on a tap while `disabled`) so the owner can say why (toast). Its own V9Feel.deny is a no-op.
func set_gate(ok: Callable, on_deny: Callable = Callable()) -> void :
	gate = ok
	if on_deny.is_valid():
		denied.connect(on_deny)

func activate() -> void :

	_press_down()
	if not _down:
		return
	await get_tree().create_timer(0.12).timeout
	_down = false
	_release(true)


# ================================================================== 0.12 imperial lacquer face
# One look for every JButton: «red» the crimson btn_lacquer_red art (gold vines in the caps; procedural crimson
# lacquer while the art is missing), «gold» a deep gold lacquer with a double rim and gold diamonds, «plum» royal plum
# velvet with an antique gold rim, «jade» the «on» / done state. Drawn with V10Button's lacquer helpers so the JButton
# and the HUD v2 buttons are one family. A press squashes the face (0.94 → 1.03 → 1.0, TRANS_BACK) and a fired tap
# sweeps a short gold glint across it, clipped to the lacquer.
class Lacquer extends Control:
	const RED_SRC: = Rect2(6.0, 48.0, 668.0, 105.0)
	const RED_CAP: = 112.0
	const GOLD_RIM: = Color(0.902, 0.765, 0.471)   # antique gold #E6C378
	var style: = "red"
	var down: = false
	var _glint: = -1.0
	var _gtw: Tween
	var _sq: Tween

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

	# horizontal room the caps / diamonds take on each side (the caption stays inside)
	static func inset(st: String, sz: Vector2) -> float:
		if st == "red":
			return minf(sz.x * 0.2, maxf(18.0, sz.y * 0.5))
		return minf(sz.x * 0.16, maxf(16.0, sz.y * 0.34))

	static func text_style(st: String) -> Array:
		match st:
			"gold":
				return [Color(1.0, 0.98, 0.92), Color(0.36, 0.17, 0.02), 5]
			"plum":
				return [Color(1.0, 0.94, 0.82), Color(0.08, 0.02, 0.11), 4]
			"jade":
				return [Color(0.96, 1.0, 0.95), Color(0.03, 0.14, 0.09), 4]
		return [Color(1.0, 0.97, 0.9), Color(0.3, 0.02, 0.06), 5]

	func press(on: bool) -> void:
		down = on
		queue_redraw()
		if _sq and _sq.is_valid():
			_sq.kill()
		if not is_inside_tree():
			return
		pivot_offset = size * 0.5
		_sq = create_tween()
		if on:
			_sq.tween_property(self, "scale", Vector2(1.015, 0.94), 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		else:
			_sq.tween_property(self, "scale", Vector2(0.99, 1.03), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			_sq.tween_property(self, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	func glint() -> void:
		if not is_inside_tree():
			return
		if _gtw and _gtw.is_valid():
			_gtw.kill()
		_gtw = create_tween()
		_gtw.tween_method(func(v: float):
			_glint = v
			queue_redraw(), 0.0, 1.0, 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_gtw.tween_callback(func():
			_glint = -1.0
			queue_redraw())

	func _diamond(c: Vector2, r: float, col: Color, edge: Color) -> void:
		var pts: = PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.8, 0), c + Vector2(0, r), c + Vector2(-r * 0.8, 0)])
		draw_colored_polygon(pts, col)
		pts.append(pts[0])
		draw_polyline(pts, edge, 1.2, true)

	func _rad() -> float:
		return safe_rad(minf(size.y * 0.5, 30.0) if style == "red" else minf(size.y * 0.42, 24.0), size)

	# V10Button.lacquer's top sheen is a rounded rect 44 % of the inner height: its corner radius (rad − 5.5) must stay
	# under half of it, or the outline folds onto itself and the polygon cannot be triangulated
	static func safe_rad(want: float, sz: Vector2) -> float:
		return maxf(4.0, minf(want, minf(5.5 + (sz.y - 7.6) * 0.22 - 1.0, 5.5 + (sz.x - 15.6) * 0.5 - 1.0)))

	func _draw() -> void:
		var r: = Rect2(Vector2.ZERO, size)
		if r.size.x < 4.0 or r.size.y < 4.0:
			return
		var rad: = _rad()
		var yc: = size.y * 0.5
		var dr: = clampf(size.y * 0.075, 3.5, 7.0)
		match style:
			"red":
				var tex: = V10Button._hf_tex(false)
				if tex != null:
					V10Button.draw_hf_pill(self, tex, r, RED_SRC, RED_CAP, Color(0.8, 0.76, 0.8) if down else Color.WHITE)
				else:
					V10Button.lacquer(self, r, rad, Color(0.93, 0.2, 0.22) if not down else Color(0.7, 0.1, 0.14),
						Color(0.74, 0.05, 0.1) if not down else Color(0.55, 0.03, 0.07), Color(0.42, 0.01, 0.05),
						0.85 if down else 1.0, Color(1.0, 0.85, 0.8), 0.18 if down else 0.3)
					_diamond(Vector2(maxf(14.0, size.y * 0.26), yc), dr, V10DS.PLATE_SPARK, Color(0.5, 0.3, 0.08, 0.8))
					_diamond(Vector2(size.x - maxf(14.0, size.y * 0.26), yc), dr, V10DS.PLATE_SPARK, Color(0.5, 0.3, 0.08, 0.8))
			"gold":
				V10Button.lacquer(self, r, rad, Color(1.0, 0.92, 0.62) if not down else Color(0.9, 0.76, 0.42),
					Color(0.9, 0.66, 0.24) if not down else Color(0.78, 0.55, 0.18), Color(0.6, 0.36, 0.08),
					0.9 if down else 1.0, Color(1.0, 1.0, 0.94), 0.22 if down else 0.42)
				# the double rim: a dark bronze groove inside the outer bezel
				var r5: = r.grow(-4.6)
				var p5: = V10Button.rr_pts(r5, maxf(2.0, rad - 4.6), 10)
				p5.append(p5[0])
				draw_polyline(p5, Color(0.45, 0.25, 0.04, 0.55), 1.2, true)
				var dx: = maxf(13.0, size.y * 0.22)
				_diamond(Vector2(dx, yc), dr, Color(1.0, 0.98, 0.88), Color(0.45, 0.24, 0.03, 0.9))
				_diamond(Vector2(size.x - dx, yc), dr, Color(1.0, 0.98, 0.88), Color(0.45, 0.24, 0.03, 0.9))
			"jade":
				V10Button.lacquer(self, r, rad, Color(0.17, 0.46, 0.36) if not down else Color(0.12, 0.34, 0.27),
					Color(0.09, 0.3, 0.22), Color(0.04, 0.16, 0.11), 0.9 if down else 1.0, Color(0.85, 1.0, 0.92), 0.16)
				var dxj: = maxf(13.0, size.y * 0.22)
				_diamond(Vector2(dxj, yc), dr * 0.85, GOLD_RIM, Color(0.3, 0.2, 0.05, 0.8))
				_diamond(Vector2(size.x - dxj, yc), dr * 0.85, GOLD_RIM, Color(0.3, 0.2, 0.05, 0.8))
			_:
				# royal plum velvet Color(0.14, 0.06, 0.20, 0.96) under a thin antique gold rim
				var top: = Color(0.22, 0.1, 0.3, 0.97) if not down else Color(0.16, 0.07, 0.22, 0.97)
				V10Button.lacquer(self, r, rad, top, Color(0.14, 0.06, 0.2, 0.96), Color(0.08, 0.03, 0.12, 0.97),
					0.8 if down else 0.9, Color(1.0, 0.9, 0.95), 0.1 if down else 0.16)
				var dxp: = maxf(12.0, size.y * 0.2)
				if size.x > size.y * 2.4:
					_diamond(Vector2(dxp, yc), dr * 0.8, Color(GOLD_RIM, 0.95), Color(0.2, 0.08, 0.02, 0.8))
					_diamond(Vector2(size.x - dxp, yc), dr * 0.8, Color(GOLD_RIM, 0.95), Color(0.2, 0.08, 0.02, 0.8))
		if _glint >= 0.0:
			_draw_glint(r.grow(-5.0), maxf(2.0, rad - 5.0))

	func _safe_poly(poly: PackedVector2Array, col: Color) -> void:
		if poly.size() < 3 or col.a <= 0.004:
			return
		var clean: = PackedVector2Array()
		for pt in poly:
			if clean.is_empty() or clean[clean.size() - 1].distance_squared_to(pt) > 0.25:
				clean.append(pt)
		if clean.size() >= 2 and clean[0].distance_squared_to(clean[clean.size() - 1]) <= 0.25:
			clean.resize(clean.size() - 1)
		if clean.size() < 3:
			return
		var area2: = 0.0
		for i in clean.size():
			var p0: = clean[i]
			var p1: = clean[(i + 1) % clean.size()]
			area2 += p0.x * p1.y - p1.x * p0.y
		if absf(area2) < 1.0:
			return
		if Geometry2D.triangulate_polygon(clean).is_empty():
			return
		draw_colored_polygon(clean, col)

	# a slanted band of warm light swept left → right, clipped to the inner lacquer
	func _draw_glint(inner: Rect2, rad: float) -> void:
		if inner.size.x < 4.0 or inner.size.y < 4.0:
			return
		var safe_r: = clampf(rad, 1.0, minf(inner.size.x, inner.size.y) * 0.45)
		var bw: = maxf(26.0, inner.size.y * 0.55)
		var x: = lerpf(inner.position.x - bw * 2.0, inner.end.x + bw, _glint)
		var sl: = inner.size.y * 0.55
		var band: = PackedVector2Array([Vector2(x + sl, inner.position.y), Vector2(x + sl + bw, inner.position.y),
			Vector2(x + bw, inner.end.y), Vector2(x, inner.end.y)])
		var shape: = V10Button.rr_pts(inner, safe_r, 8)
		if shape.size() < 3:
			return
		var a: = sin(_glint * PI)
		for poly in Geometry2D.intersect_polygons(band, shape):
			_safe_poly(poly, Color(1.0, 0.93, 0.66, 0.42 * a))
		var core: = PackedVector2Array([Vector2(x + sl + bw * 0.4, inner.position.y), Vector2(x + sl + bw * 0.6, inner.position.y),
			Vector2(x + bw * 0.6, inner.end.y), Vector2(x + bw * 0.4, inner.end.y)])
		for poly in Geometry2D.intersect_polygons(core, shape):
			_safe_poly(poly, Color(1.0, 1.0, 0.92, 0.5 * a))
