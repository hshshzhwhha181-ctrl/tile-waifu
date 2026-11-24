class_name JButton
extends Control


signal pressed
# 0.9: a tap on a disabled button (after its deny shake), so the owner can say why
signal denied
var box: RBox
var lbl: Label
var sub: Label
var icon_rect: TextureRect
# 0.8 art: call-to-action and secondary buttons draw btn/primary or btn/secondary (NinePatchRect) instead of the
# procedural pill; `box` stays (hidden) so pressed/shine/colors() calls keep working
var art: NinePatchRect
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

# use_art = false keeps the procedural pill for tabs (their palette is swapped via box.colors()) and toggles
static func make(text: String, pal: String, rect: Rect2, icon: Texture2D = null, font_size: = 30, radius: = -1.0, use_art: = true) -> JButton:
	var b: = JButton.new()
	b.position = rect.position
	b.size = rect.size
	b._use_art = use_art
	b.build(text, pal, icon, font_size, radius)
	return b

var _use_art: = true

# palette -> btn art. Every call-to-action palette draws the btn art: pink/gold CTAs the primary (pink lacquer,
# sakura caps), boss/danger the crimson recolour, quiet/secondary actions the graphite secondary, and «on» / done
# states its jade recolour. Small toggles, tags, tabs (use_art = false) and round icon buttons keep the procedural pills.
const ART_PAL: = {"pink": "primary", "gold": "primary", "red": "primary_red", "graphite": "secondary", "lav": "secondary",
	"glass": "secondary", "rose": "secondary", "plum": "secondary", "cream": "secondary", "mint": "secondary_jade"}
# caption colours follow the art the button actually draws, not the palette it was asked for
const ART_TEXT_PAL: = {"primary": "pink", "primary_red": "red", "secondary": "graphite", "secondary_jade": "mint"}
const ART_MIN_H: = 60.0
var _pal: = ""
var _radius: = -1.0
var _art_name: = ""

static func art_for(pal: String, sz: Vector2, text: String, radius: float) -> String:
	if text == "" or radius >= 0.0 or not ART_PAL.has(pal):
		return ""
	if sz.y < ART_MIN_H or sz.x < sz.y * 1.8:
		return ""
	return ART_PAL[pal]

func build(text: String, pal: String, icon: Texture2D, font_size: int, radius: float) -> void :
	mouse_filter = Control.MOUSE_FILTER_STOP
	pivot_offset = size * 0.5
	var p: Array = UI.PAL[pal]
	box = RBox.new()
	box.size = size
	box.setup(p[0], p[1], size.y * 0.5 if radius < 0 else radius, 4.0, 14.0)
	add_child(box)
	var art_name: = art_for(pal, size, text, radius) if _use_art else ""
	_pal = pal
	_radius = radius
	_art_name = art_name
	var x0: = 0.0
	var x1: = 0.0
	if art_name != "":
		art = V8Art.nine(art_name, Rect2(Vector2.ZERO, size))
		add_child(art)
		box.visible = false
		var cr: = V8Art.nine_content(art_name, size)
		x0 = cr.position.x
		x1 = size.x - cr.end.x
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
		var ts: = _text_style(ART_TEXT_PAL.get(art_name, pal))
		lbl = UI.label(text, font_size, ts[0], ts[1], ts[2], "body", 900)
		UI.center_label(lbl, Rect2(x0, 0, size.x - x0 - x1, size.y))
		if art and not "\n" in text:
			_fit_label(size.x - x0 - x1)
		add_child(lbl)
	_apply_disabled()

# [colour, outline colour, outline size] of the caption on a palette
static func _text_style(pal: String) -> Array:
	var p: Array = UI.PAL[pal]
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
	box.colors(UI.PAL[pal][0], UI.PAL[pal][1])
	if an != "" and art:
		if an != _art_name:
			var n: = V8Art.nine(an, Rect2(Vector2.ZERO, size))
			art.texture = n.texture
			art.patch_margin_left = n.patch_margin_left
			art.patch_margin_top = n.patch_margin_top
			art.patch_margin_right = n.patch_margin_right
			art.patch_margin_bottom = n.patch_margin_bottom
			n.free()
		art.visible = true
		box.visible = false
	elif art:
		art.visible = false
		box.visible = true
	_art_name = an if art else ""
	if lbl:
		var ts: = _text_style(ART_TEXT_PAL.get(_art_name, pal))
		var ls: LabelSettings = lbl.label_settings.duplicate()
		ls.font_color = ts[0]
		ls.outline_color = ts[1]
		ls.outline_size = ts[2]
		lbl.label_settings = ls

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
	if disabled:
		_deny_shake()
		denied.emit()
		return
	_down = true
	box.set_param("pressed", 1.0)
	V9Feel.press_down(self)

func _release(fire: bool) -> void :
	box.set_param("pressed", 0.0)
	V9Feel.press_up(self, fire, sound)
	if fire:
		box.shine(0.0, 0.5)
		pressed.emit()

func activate() -> void :

	_press_down()
	await get_tree().create_timer(0.12).timeout
	_down = false
	_release(true)
