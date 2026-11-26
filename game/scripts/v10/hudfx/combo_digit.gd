class_name V10ComboDigit
extends Control

# V10ComboDigit — the combo number «×N» over the tray, left (docs/HUD_V2.md §6 «Цифра комбо», §7.2; UX §6.6).
# Replaces the look of V10HudMatch.combo_l, same timing. Display 64 italic in lacquered GOLD (shader combo_gold:
# gold.300 → gold.500 → a touch of gold.700, thin warm inner edge on the top edges of the strokes, faint bevel),
# the standard on-art soft shadow (night.900 α ≤ 0.55, (0, 2), 6 px), one diagonal sheen band (48 px, 20°, warm
# paper.100 α ≤ 0.25) that crosses ONCE during «держит» (never loops). One number at a time: a new one replaces
# the old immediately (never stacked). The size never changes with the tier: «на T3 растёт только свет».
# The sign is drawn as the italic lowercase «x» (SIGN), as in the approved mockup 02_combo («x10»).
#
#   var d := V10ComboDigit.for_hud(hud)                 # one per HUD (find-or-create child), at hud.combo_anchor()
#   d.show_combo(n, tier := 0, hero := "mc")            # tier 0 = plain combo, 1/2/3 = the showcase tier that fired
#   d.configure(anchor_rect)                            # the 320×80 box left above the tray (x 24, y 704 at 9:16)
#   d.cut()                                             # leave now (120 ms fade), e.g. when the match ends
#   signal done                                         # after the number has left (not when replaced)
#   (`show(n, …)` of the spec is `show_combo`: CanvasItem.show() is a native method and cannot be overridden.)
#
# Timing (seconds): in 0.12 (α 0→1 + scale 1.15→1.0 BACK_OUT, pivot left-centre) · hold 0.36 · out 0.12 = 0.60.
# Tier light: T2 — a soft warm halo of the heroine accent (35 % toward gold.500) behind the number, α ≤ 0.3 (a tone
# laid over, warm_light-clamped to value ≤ 0.8 — additive turned grey on the green felt; a cheap shared radial
# gradient texture, not a blur); T3 — halo α ≤ 0.5, 22 % larger, swelling once 1.0→1.06 over the hold (no pulse). T2/T3 draw at z_index 1 so the number sits above the showcase dim (same canvas layer).
# fx levels: full — all of the above · mid — no sheen, halo ×0.7 · min — 120 ms fade in, hold, 120 ms fade out,
# no scale, no sheen, no halo (the gold look stays: it is information, not motion) · V10HudFx.calm() — no sheen,
# halo ×0.6 without the swell.
# Cost: 3 canvas items (halo, shadow, gold), redrawn only when the text changes; one Tween bound to this node
# drives everything (no _process); the sheen is two shader uniforms; 3 texture samples per glyph pixel.

signal done

const NODE_NAME: = "V10ComboDigit"
const SIZE: = 64
const T_IN: = 0.12
const T_HOLD: = 0.36
const T_OUT: = 0.12
const SCALE_FROM: = 1.15
const HALO_A: = {2: 0.30, 3: 0.50}  # caps (effective alpha = digit α × halo α)
const HALO_SIZE: = {2: 1.0, 3: 1.22}
const HALO_SWELL: = 1.06  # T3: the light grows once over the hold
const HALO_MID: = 0.7
const HALO_CALM: = 0.6
const SHEEN_A: = 0.22  # ≤ 0.25
const SHEEN_W: = 48.0
const TAN20: = 0.36397
const CAP_K: = 0.72  # Playfair Display cap height / size (lining figures)
const DEFAULT_ANCHOR: = Rect2(24, 704, 320, 80)
# the multiplier sign: Playfair Italic's «×» is a hairline cross that reads weak beside the 700 italic figures;
# the approved mockup 02_combo draws the italic lowercase x (thick/thin like the figures) — «x10»
const SIGN: = "x"

const P_SHEEN_X: = &"sheen_x"
const P_SHEEN_A: = &"sheen_a"

static var _halo_tex: GradientTexture2D

var text: = ""
var n: = 0
var tier: = 0
var hero: = "mc"
var font_size: = SIZE
var manual: = false  # tests / demo shots: the tween is created paused and driven by advance(dt)
var auto_free: = false  # one-shot use: queue_free() after done
var showing: = false

var gold_mat: ShaderMaterial
var halo: TextureRect
var _shadow: _Ink
var _gold: _Ink
var _tw: Tween
var _font: Font
var _baseline: = 0.0
var _text_w: = 0.0
var _sheen_x0: = 0.0
var _sheen_x1: = 0.0
var _pending: = []


static func _static_init() -> void:
	V10HudFx.register_shader("combo_gold")


# One digit per HUD: find-or-create the child under `hud` and anchor it at hud.combo_anchor().
static func for_hud(hud: Control) -> V10ComboDigit:
	var d: = hud.get_node_or_null(NODE_NAME) as V10ComboDigit
	if d == null or d.is_queued_for_deletion():
		d = V10ComboDigit.new()
		d.name = NODE_NAME
		hud.add_child(d)
	var a: Rect2 = hud.call("combo_anchor") if hud.has_method("combo_anchor") else DEFAULT_ANCHOR
	d.configure(a)
	return d


static func halo_texture() -> GradientTexture2D:
	# soft radial falloff, built once and shared (white × alpha; the node's modulate gives the warm accent)
	if _halo_tex == null:
		var g: = Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.3, 0.6, 0.82, 1.0])
		g.colors = PackedColorArray([Color.WHITE, Color(Color.WHITE, 0.72), Color(Color.WHITE, 0.3), Color(Color.WHITE, 0.08), Color(Color.WHITE, 0.0)])
		var t: = GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 128
		t.height = 128
		_halo_tex = t
	return _halo_tex


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	position = DEFAULT_ANCHOR.position
	size = DEFAULT_ANCHOR.size
	_font = V10Type.font("display_italic")
	halo = TextureRect.new()
	halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	halo.texture = halo_texture()
	halo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	halo.stretch_mode = TextureRect.STRETCH_SCALE
	halo.visible = false
	add_child(halo)
	_shadow = _Ink.new()
	_shadow.digit = self
	_shadow.shadow = true
	add_child(_shadow)
	_gold = _Ink.new()
	_gold.digit = self
	add_child(_gold)
	var sh: = V10HudFx.shader("combo_gold")
	if sh != null:
		gold_mat = ShaderMaterial.new()
		gold_mat.shader = sh
		gold_mat.set_shader_parameter("gold_top", V10DS.GOLD_300)
		gold_mat.set_shader_parameter("gold_mid", V10DS.GOLD_500)
		gold_mat.set_shader_parameter("gold_low", V10DS.GOLD_700)
		gold_mat.set_shader_parameter("light", V10DS.PAPER_100)
		gold_mat.set_shader_parameter("sheen_w", SHEEN_W)
		gold_mat.set_shader_parameter(P_SHEEN_A, 0.0)
		_gold.material = gold_mat
	# without the shader the number is plain gold.300 (hud2's look): the module still works


func _ready() -> void:
	if not _pending.is_empty():
		var p: Array = _pending
		_pending = []
		show_combo(p[0], p[1], p[2], p[3])


func configure(anchor_rect: Rect2) -> void:
	position = anchor_rect.position
	size = anchor_rect.size
	_layout()


func total_time() -> float:
	return T_IN + T_HOLD + T_OUT


func show_combo(num: int, tier_: = 0, hero_: = "mc", hold: = T_HOLD) -> void:
	if num <= 0:
		cut()
		return
	if not is_inside_tree():
		_pending = [num, tier_, hero_, hold]
		return
	if _tw and _tw.is_valid():
		_tw.kill()  # replace, never stack (no «done» for the replaced number)
	n = num
	tier = clampi(tier_, 0, 3)
	hero = hero_
	text = SIGN + str(num)
	showing = true
	_layout()
	hold = maxf(0.0, hold)
	var lvl: = V10HudFx.level()
	var motion: = lvl != "min"
	var calm: = V10HudFx.calm()
	var sheen: = lvl == "full" and not calm
	# light: T2/T3 only, never at min
	var cap: = 0.0
	if tier >= 2 and motion:
		cap = float(HALO_A[tier]) * (HALO_MID if lvl == "mid" else 1.0) * (HALO_CALM if calm else 1.0)
	z_index = 1 if tier >= 2 else 0
	halo.visible = cap > 0.0
	if cap > 0.0:
		var warm: = V10HudFx.accent(hero).lerp(V10DS.GOLD_500, 0.35)
		halo.modulate = V10HudFx.warm_light(warm, cap * (0.7 if tier == 3 and not calm else 1.0))
		halo.scale = Vector2.ONE * (0.9 if tier == 3 and not calm else 1.0)
	if gold_mat:
		gold_mat.set_shader_parameter(P_SHEEN_A, 0.0)
		gold_mat.set_shader_parameter(P_SHEEN_X, _sheen_x0)
	_shadow.queue_redraw()
	_gold.queue_redraw()
	visible = true
	modulate = Color(Color.WHITE, 0.0)
	scale = Vector2.ONE * (SCALE_FROM if motion else 1.0)
	set_process(false)
	_tw = V10HudFx.tw(self)
	_tw.set_parallel(true)
	_tw.tween_property(self, "modulate:a", 1.0, T_IN)
	if motion:
		_tw.tween_property(self, "scale", Vector2.ONE, T_IN).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if cap > 0.0 and tier == 3 and not calm:
		_tw.tween_property(halo, "scale", Vector2.ONE, T_IN).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tw.chain().tween_interval(hold)
	if sheen and gold_mat:
		_tw.tween_method(_sheen_step, 0.0, 1.0, hold).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if cap > 0.0 and tier == 3 and not calm:
		_tw.tween_property(halo, "scale", Vector2.ONE * HALO_SWELL, hold).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_tw.tween_property(halo, "modulate:a", cap, hold).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tw.chain().tween_property(self, "modulate:a", 0.0, T_OUT)
	_tw.chain().tween_callback(_finish)
	if manual:
		_tw.pause()


func cut() -> void:
	# leave now: 120 ms fade from wherever it is (used on match end / pause; no-op when hidden)
	if not showing:
		return
	if _tw and _tw.is_valid():
		_tw.kill()
	if gold_mat:
		gold_mat.set_shader_parameter(P_SHEEN_A, 0.0)
	_tw = V10HudFx.tw(self)
	_tw.tween_property(self, "modulate:a", 0.0, T_OUT * modulate.a)
	_tw.tween_callback(_finish)
	if manual:
		_tw.pause()


func advance(dt: float) -> void:
	# deterministic step for tests and demo shots (manual = true)
	if _tw and _tw.is_valid():
		_tw.custom_step(dt)


func sheen_alpha() -> float:
	return float(gold_mat.get_shader_parameter(P_SHEEN_A)) if gold_mat else 0.0


func sheen_pos() -> float:
	return float(gold_mat.get_shader_parameter(P_SHEEN_X)) if gold_mat else 0.0


func text_width() -> float:
	return _text_w


func halo_alpha() -> float:
	# effective light alpha on screen (halo × digit fade)
	return halo.modulate.a * modulate.a if halo.visible and visible else 0.0


func _sheen_step(p: float) -> void:
	if not gold_mat:
		return
	gold_mat.set_shader_parameter(P_SHEEN_X, lerpf(_sheen_x0, _sheen_x1, p))
	gold_mat.set_shader_parameter(P_SHEEN_A, SHEEN_A if p > 0.0 and p < 1.0 else 0.0)


func _finish() -> void:
	showing = false
	visible = false
	modulate = Color(Color.WHITE, 0.0)
	scale = Vector2.ONE
	z_index = 0
	halo.visible = false
	if gold_mat:
		gold_mat.set_shader_parameter(P_SHEEN_A, 0.0)
	set_process(false)
	_tw = null
	done.emit()
	if auto_free:
		queue_free()


func _layout() -> void:
	if _font == null:
		return
	var asc: = _font.get_ascent(font_size)
	var desc: = _font.get_descent(font_size)
	_baseline = roundf((size.y - (asc + desc)) * 0.5 + asc)
	_text_w = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x if text != "" else 0.0
	var cap: = font_size * CAP_K
	var y_top: = _baseline - cap
	pivot_offset = Vector2(0.0, _baseline - cap * 0.5)
	_shadow.position = Vector2.ZERO
	_shadow.size = size
	_gold.position = Vector2.ZERO
	_gold.size = size
	_sheen_x0 = -(cap * TAN20 + SHEEN_W * 0.5 + 6.0)
	_sheen_x1 = _text_w + SHEEN_W * 0.5 + 6.0
	if gold_mat:
		gold_mat.set_shader_parameter("y_top", y_top)
		gold_mat.set_shader_parameter("y_base", _baseline + font_size * 0.03)
		gold_mat.set_shader_parameter("x_left", 0.0)
		gold_mat.set_shader_parameter("x_right", maxf(1.0, _text_w))
	# halo: an ellipse behind the ink, wider than tall; T3 a little larger
	var k: float = HALO_SIZE.get(tier, 1.0)
	var hs: = Vector2(_text_w + 176.0, 168.0) * k
	halo.size = hs
	halo.position = Vector2(_text_w * 0.5, _baseline - cap * 0.5) - hs * 0.5
	halo.pivot_offset = hs * 0.5


# The ink: one canvas item for the shadow (no material), one for the gold (combo_gold material).
class _Ink extends Control:
	var digit: V10ComboDigit
	var shadow: = false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if digit == null or digit.text == "":
			return
		var f: = digit._font
		var p: = Vector2(0.0, digit._baseline)
		var fs: = digit.font_size
		if shadow:
			# the standard on-art shadow (V10Type on_art: night.900 α 0.55, offset (0, 2), 6 px), stepped soft:
			# three layers of 0.22 → ≈ 0.53 at the glyph, fading over 6 px
			var c: = Color(V10DS.SHADOW, V10DS.SHADOW_A * 0.4)
			var o: = p + Vector2(0, 2)
			draw_string_outline(f, o, digit.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, c)
			draw_string_outline(f, o, digit.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, c)
			draw_string(f, o, digit.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c)
		else:
			draw_string(f, p, digit.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE if digit.gold_mat else V10DS.GOLD_300)
