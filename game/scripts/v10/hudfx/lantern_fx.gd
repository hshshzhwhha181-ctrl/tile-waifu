class_name V10LanternFx
extends Node

# V10LanternFx — «Фонари-ритуалы» of the Чайная (UX_RULES §6.8, HUD_V2 §8.2; lane: scripts/v10/hudfx/README.md).
# The three painted lanterns on threads of V10HudHome (lantern_tr). A new task: the lantern swings two periods as a
# damped pendulum around the thread point and catches light in 400 ms. Done: the light goes out on an «exhale» in
# 300 ms and the lantern lowers 8 px. A lantern at rest is STILL: no flicker, no idle sway (HUD_V2 §6: the interface
# has no infinite animation).
#
#   var fx: = V10LanternFx.attach(home)     # helper node under the V10HudHome; idempotent; before or after layout
#   fx.light(i)                             # new task → swing (+ rises back if lowered) + ignite
#   fx.extinguish(i)                        # done     → exhale + lower 8 px
#   fx.set_state(i, lit, animate := true)   # sync with the game; no-op when the lantern is already in that state
#   signal changed(i, lit)                  # V10LanternFx.of(home) → the attached helper or null; detach() restores hud2
#   fx.manual = true; fx.advance(dt)        # demo shots / tests: a fixed clock instead of _process
#
# Timings: swing PERIOD 1.10 s × 2 (first peak ≈ 5.5° ≤ 6°, second ≈ 40 % of the first, ends exactly at 0°);
# rise 300 ms QUINT_OUT; ignite at 0.5 PERIOD, 400 ms CUBIC_OUT: the lantern's tint (unlit → white), the inner light
# (lantern_glow.gdshader: additive, head-room limited so the painted core never clips; α ≤ 0.55) and the halo
# (home.glow, gold.500 α 0.22 — the sprite _Deco drew) rise together; sound lantern_ignite −8 dB. Exhale 300 ms:
# light CUBIC_OUT → 0, drop QUINT_OUT 0 → 8 px, sound lantern_exhale −10 dB (sfx/*.ogg missing → quiet juice
# gold_ripple / brush_swoosh). Caption paper.300 lit / paper.500 unlit (cross-fade through self_modulate).
# fx_level: full — all; mid — inner light × 0.6; min — every change is a 120 ms fade, no swing, no rise/lower motion
# (the lowered position still applies), no inner light. calm(): nothing to remove — the ignite is a fade, not a flash.
#
# Ownership: the tint moves from the lantern's modulate to its self_modulate (its light children stay untinted; an
# outer fade of the HUD still reaches them). Under each lantern the helper parents a halo (behind), the inner light
# (above) and a thread stub (behind: fills the gap above a lowered lantern up to the _Deco thread end). It takes over
# the static glow of V10HudHome._Deco: hook — _Deco skips it while the home has meta "v10_lantern_fx"; without the
# hook the helper swaps home.glow for a blank texture (restored on detach). Re-layout: base positions are read from
# home.L.lanterns; when layout_now() resets a lantern the offset is re-applied (item_rect_changed). _process runs
# only while a lantern animates; nothing allocates per frame.

signal changed(i: int, lit: bool)

const META: = "v10_lantern_fx"
const PERIOD: = 1.10
const SWING_T: = PERIOD * 2.0  # exactly two periods
const SWING_A: = 0.1194  # rad; with the decay the first peak is ≈ 5.5° (≤ 6°)
const SWING_K: = 0.83299  # ln(2.5) / PERIOD → each period keeps 40 % of the previous amplitude
const RISE_T: = 0.30
const IGNITE_AT: = PERIOD * 0.5
const T_IGNITE: = 0.40
const T_EXHALE: = 0.30
const DROP: = 8.0
const PIVOT_Y: = 4.0  # the thread point: the painted ring, where _Deco ends the thread (lantern rect y + 4)
const LIGHT_A: = 0.5  # inner light α of a lit lantern (cap 0.55)
const LIGHT_MID: = 0.6
const HALO_A: = 0.22  # = _Deco
const HALO_SIZE: = 128.0  # = _Deco
const SFX_FALLBACK: = {"lantern_ignite": ["gold_ripple", 1.25, -8.0], "lantern_exhale": ["brush_swoosh", 0.8, -12.0]}

enum { IDLE, LIGHT, EXHALE, FADE }

static var force_fallback: = false  # selftest: the no-shader inner light
static var _blank: GradientTexture2D
static var _radial: GradientTexture2D

var home: V10HudHome
var sound_count: = 0  # selftest / debugging: sounds requested
var last_sound: = ""
var manual: = false  # demo shots / tests: the owner steps advance(dt) itself, _process stays off
var _set_up: = false
var _pending: = []  # calls made before the home was laid out: [i, lit, animate]
var _g: = PackedFloat32Array([0.0, 0.0, 0.0])  # lit-ness 0..1 (tint, halo, light, caption)
var _drop: = PackedFloat32Array([0.0, 0.0, 0.0])
var _rot: = PackedFloat32Array([0.0, 0.0, 0.0])
var _clock: = PackedFloat32Array([0.0, 0.0, 0.0])
var _g0: = PackedFloat32Array([0.0, 0.0, 0.0])
var _d0: = PackedFloat32Array([0.0, 0.0, 0.0])
var _r0: = PackedFloat32Array([0.0, 0.0, 0.0])
var _sign: = PackedFloat32Array([1.0, -1.0, 1.0])
var _to: = PackedFloat32Array([0.0, 0.0, 0.0])
var _kind: = PackedInt32Array([IDLE, IDLE, IDLE])
var _base: = PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
var _halo: = []
var _inner: = []
var _mats: = []
var _thread: = []
var _light_k: = 1.0
var _applying: = false
var _glow_orig: Texture2D
var _unlit: = Color.WHITE
var _cap_ratio: = Color.WHITE
var _ls_lit: LabelSettings
var _ls_unlit: LabelSettings


static func attach(h: V10HudHome) -> V10LanternFx:
	if h == null or not is_instance_valid(h):
		return null
	var cur: = of(h)
	if cur:
		return cur
	V10HudFx.register_shader("lantern_glow")
	var fx: = V10LanternFx.new()
	fx.name = "LanternFx"
	fx.home = h
	h.set_meta(META, fx)
	h.add_child(fx)
	return fx


static func of(h: Node) -> V10LanternFx:
	if h == null or not is_instance_valid(h) or not h.has_meta(META):
		return null
	var o: Object = h.get_meta(META)
	if o == null or not is_instance_valid(o) or (o as Node).is_queued_for_deletion():
		return null
	return o as V10LanternFx


# damped pendulum, radians, for a +1 first swing; 0 outside [0, SWING_T] (exactly 0 at both ends)
static func swing(t: float) -> float:
	if t <= 0.0 or t >= SWING_T:
		return 0.0
	return SWING_A * exp(-SWING_K * t) * sin(TAU * t / PERIOD)


static func _cubic_out(p: float) -> float:
	var q: = 1.0 - clampf(p, 0.0, 1.0)
	return 1.0 - q * q * q


static func _quint_out(p: float) -> float:
	var q: = 1.0 - clampf(p, 0.0, 1.0)
	return 1.0 - q * q * q * q * q


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	set_process(false)
	if home == null and get_parent() is V10HudHome:
		home = get_parent()
	if home == null:
		return
	if home.is_node_ready() and home.lantern_tr.size() >= 3:
		_setup()
	else:
		home.ready.connect(_setup, CONNECT_ONE_SHOT)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		# freed without detach(): hand the lanterns back unless the home itself is going away
		if is_instance_valid(home) and not home.is_queued_for_deletion():
			_restore()


# ------------------------------------------------------------------ public API

func light(i: int) -> void:
	if i < 0 or i > 2:
		return
	if not _set_up:
		_pending.append([i, true, true])
		return
	var was: = bool(home.lit[i])
	home.lit[i] = true
	_light_k = _level_k()
	if V10HudFx.is_min():
		_start(i, FADE, 1.0)
		_drop[i] = 0.0
		_rot[i] = 0.0
		_apply(i)
		if not was:
			_sound("lantern_ignite", -8.0)
	elif _kind[i] != LIGHT:  # a lantern already swinging for a task keeps its swing (no restart, no jump)
		_start(i, LIGHT, 1.0)
	if not was:
		changed.emit(i, true)


func extinguish(i: int) -> void:
	if i < 0 or i > 2:
		return
	if not _set_up:
		_pending.append([i, false, true])
		return
	var was: = bool(home.lit[i])
	if not was and _kind[i] == IDLE:
		return
	home.lit[i] = false
	_light_k = _level_k()
	if V10HudFx.is_min():
		_start(i, FADE, 0.0)
		_drop[i] = DROP
		_rot[i] = 0.0
		_apply(i)
	elif _kind[i] != EXHALE:
		_start(i, EXHALE, 0.0)
	if was:
		_sound("lantern_exhale", -10.0)
		changed.emit(i, false)


func set_state(i: int, lit: bool, animate: = true) -> void:
	if i < 0 or i > 2:
		return
	if not _set_up:
		_pending.append([i, lit, animate])
		return
	if bool(home.lit[i]) == lit:
		return
	if animate:
		if lit:
			light(i)
		else:
			extinguish(i)
		return
	home.lit[i] = lit
	_light_k = _level_k()
	_kind[i] = IDLE
	_g[i] = 1.0 if lit else 0.0
	_drop[i] = 0.0 if lit else DROP
	_rot[i] = 0.0
	_apply(i)
	_rest(i)
	_update_process()
	changed.emit(i, lit)


func is_lit(i: int) -> bool:
	return home != null and i >= 0 and i < home.lit.size() and bool(home.lit[i])


func is_animating(i: = -1) -> bool:
	if i >= 0:
		return i < 3 and _kind[i] != IDLE
	return _kind[0] != IDLE or _kind[1] != IDLE or _kind[2] != IDLE


func glow_of(i: int) -> float:
	return _g[i]


func drop_of(i: int) -> float:
	return _drop[i]


func base_of(i: int) -> Vector2:
	return _base[i]


func halo_node(i: int) -> Sprite2D:
	return _halo[i] if i < _halo.size() else null


func light_node(i: int) -> CanvasItem:
	return _inner[i] if i < _inner.size() else null


# inner light α actually shown on lantern i (0 when hidden); ≤ LIGHT_A
func light_alpha(i: int) -> float:
	if i >= _inner.size() or not (_inner[i] as CanvasItem).visible:
		return 0.0
	if _mats[i] != null:
		return float((_mats[i] as ShaderMaterial).get_shader_parameter(&"amount"))
	return (_inner[i] as CanvasItem).self_modulate.a


# re-read the fx level (settings changed) and re-apply every lantern at rest
func refresh() -> void:
	if not _set_up:
		return
	_light_k = _level_k()
	for i in 3:
		if _kind[i] == IDLE:
			_apply(i)
			_rest(i)


# hand the lanterns back to hud2 exactly as V10HudHome built them, and free the helper
func detach() -> void:
	_restore()
	queue_free()


# advances every running lantern by dt (the selftest steps this directly; _process feeds it the frame delta)
func advance(dt: float) -> void:
	if not _set_up or not is_instance_valid(home):
		return
	for i in 3:
		var k: = _kind[i]
		if k == IDLE:
			continue
		var tp: = _clock[i]
		var t: = tp + dt
		_clock[i] = t
		var done: = false
		match k:
			LIGHT:
				var up: = _quint_out(t / RISE_T)
				_rot[i] = _sign[i] * swing(t) + _r0[i] * (1.0 - up)
				_drop[i] = _d0[i] * (1.0 - up)
				if t >= IGNITE_AT:
					if tp < IGNITE_AT and _g0[i] < 0.99:
						_sound("lantern_ignite", -8.0)
					_g[i] = lerpf(_g0[i], 1.0, _cubic_out((t - IGNITE_AT) / T_IGNITE))
				if t >= SWING_T:
					_rot[i] = 0.0
					_drop[i] = 0.0
					_g[i] = 1.0
					done = true
			EXHALE:
				var p: = clampf(t / T_EXHALE, 0.0, 1.0)
				_g[i] = _g0[i] * (1.0 - _cubic_out(p))
				_drop[i] = lerpf(_d0[i], DROP, _quint_out(p))
				_rot[i] = _r0[i] * (1.0 - _quint_out(p))
				if p >= 1.0:
					_g[i] = 0.0
					_drop[i] = DROP
					_rot[i] = 0.0
					done = true
			FADE:
				var p: = clampf(t / V10HudFx.T_MIN, 0.0, 1.0)
				_g[i] = lerpf(_g0[i], _to[i], p)
				if p >= 1.0:
					done = true
		_apply(i)
		if done:
			_kind[i] = IDLE
			_rest(i)
	_update_process()


func _process(delta: float) -> void:
	if not _set_up or not is_instance_valid(home):
		set_process(false)
		return
	advance(delta)


# ------------------------------------------------------------------ internals

func _setup() -> void:
	if _set_up or not is_instance_valid(home) or home.lantern_tr.size() < 3:
		return
	_set_up = true
	home.lit = (home.lit as Array).duplicate()  # configure() may have handed us the caller's array
	_unlit = V10DS.PAPER_700.darkened(0.35)  # = V10HudHome's unlit tint
	_cap_ratio = Color(V10DS.PAPER_500.r / V10DS.PAPER_300.r, V10DS.PAPER_500.g / V10DS.PAPER_300.g,
			V10DS.PAPER_500.b / V10DS.PAPER_300.b, 1.0)
	_ls_lit = V10Type.settings("ui", 18, V10DS.PAPER_300, true)
	_ls_unlit = V10Type.settings("ui", 18, V10DS.PAPER_500, true)
	_light_k = _level_k()
	# take over the static glow: our halo uses the very texture _Deco drew; _Deco draws a blank one (or skips, hooked)
	_glow_orig = home.glow if home.glow != null and home.glow != _blank_tex() else _radial_tex()
	home.glow = _blank_tex()
	var sh: = V10HudFx.shader("lantern_glow")
	for i in 3:
		var lt: = _lantern(i)
		lt.modulate = Color(Color.WHITE, lt.modulate.a)
		lt.pivot_offset = Vector2(lt.size.x * 0.5, PIVOT_Y)
		_base[i] = _layout_pos(i, lt.position)
		# halo behind the lantern (rotates and lowers with it)
		var hs: = Sprite2D.new()
		hs.texture = _glow_orig
		hs.show_behind_parent = true
		hs.position = lt.size * 0.5
		hs.scale = Vector2.ONE * (HALO_SIZE / maxf(1.0, _glow_orig.get_size().x))
		hs.visible = false
		lt.add_child(hs)
		_halo.append(hs)
		# thread stub behind the ring: covers the gap a lowered lantern leaves under the _Deco thread
		var th: = _Thread.new()
		th.show_behind_parent = true
		th.position = Vector2(lt.size.x * 0.5, PIVOT_Y)
		lt.add_child(th)
		_thread.append(th)
		# inner light over the paper body
		var inner: CanvasItem
		var m: ShaderMaterial = null
		if sh != null and lt.texture != null and not force_fallback:
			var tr: = TextureRect.new()
			tr.texture = lt.texture
			tr.expand_mode = lt.expand_mode
			tr.stretch_mode = lt.stretch_mode
			tr.texture_filter = lt.texture_filter
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tr.size = lt.size
			m = ShaderMaterial.new()
			m.shader = sh
			m.set_shader_parameter(&"core", V10HudFx.warm_light(V10DS.GOLD_300))
			m.set_shader_parameter(&"rim", V10HudFx.warm_light(V10DS.EMBER))
			tr.material = m
			inner = tr
		else:
			# no shader / no painted lantern: a soft additive pool over the paper body
			var sp: = Sprite2D.new()
			sp.texture = _radial_tex()
			var cm: = CanvasItemMaterial.new()
			cm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			sp.material = cm
			sp.position = Vector2(lt.size.x * 0.5, lt.size.y * 0.42)
			sp.scale = Vector2(lt.size.x * 0.8, lt.size.y * 0.5) / maxf(1.0, _radial_tex().get_size().x)
			sp.modulate = V10HudFx.warm_light(V10DS.GOLD_500)
			inner = sp
		inner.visible = false
		lt.add_child(inner)
		_inner.append(inner)
		_mats.append(m)
		if not lt.item_rect_changed.is_connected(_on_rect):
			lt.item_rect_changed.connect(_on_rect.bind(i))
		var on: = bool(home.lit[i])
		_g[i] = 1.0 if on else 0.0
		_drop[i] = 0.0 if on else DROP
		_rot[i] = 0.0
		_kind[i] = IDLE
		_apply(i)
		_rest(i)
	if is_instance_valid(home.deco):
		home.deco.queue_redraw()
	var calls: = _pending.duplicate()
	_pending.clear()
	for c in calls:
		set_state(int(c[0]), bool(c[1]), bool(c[2]))


func _restore() -> void:
	set_process(false)
	if not is_instance_valid(home):
		return
	if _set_up:
		for i in 3:
			_kind[i] = IDLE
			var lt: = _lantern(i)
			if lt == null:
				continue
			_applying = true
			lt.rotation = 0.0
			lt.position = _base[i]
			lt.self_modulate = Color.WHITE
			lt.modulate = Color(Color.WHITE if bool(home.lit[i]) else _unlit, lt.modulate.a)
			_applying = false
			_g[i] = 1.0 if bool(home.lit[i]) else 0.0
			_rest(i)
		if home.glow == _blank and _glow_orig != null:
			home.glow = _glow_orig as GradientTexture2D
	_set_up = false  # item_rect_changed may still reach us before the free: ignore it
	_free_sprites()
	if home.has_meta(META) and home.get_meta(META) == self:
		home.remove_meta(META)
	if is_instance_valid(home.deco):
		home.deco.queue_redraw()


func _free_sprites() -> void:
	for arr in [_halo, _inner, _thread]:
		for n in arr:
			if is_instance_valid(n) and not (n as Node).is_queued_for_deletion():
				var p: = (n as Node).get_parent()
				if p:
					p.remove_child(n)
				(n as Node).queue_free()


func _lantern(i: int) -> TextureRect:
	if not is_instance_valid(home) or i >= home.lantern_tr.size():
		return null
	var lt: Object = home.lantern_tr[i]
	if lt == null or not is_instance_valid(lt):
		return null
	return lt as TextureRect


func _layout_pos(i: int, fallback: Vector2) -> Vector2:
	var lans: Variant = home.L.get("lanterns", null)
	if lans is Array and (lans as Array).size() > i:
		return ((lans as Array)[i] as Rect2).position
	return fallback


func _level_k() -> float:
	match V10HudFx.level():
		"full":
			return 1.0
		"mid":
			return LIGHT_MID
	return 0.0


func _start(i: int, kind: int, to: float) -> void:
	_g0[i] = _g[i]
	_d0[i] = _drop[i]
	_r0[i] = _rot[i]
	_to[i] = to
	_clock[i] = 0.0
	_kind[i] = kind
	if i < home.lantern_ls.size() and is_instance_valid(home.lantern_ls[i]):
		(home.lantern_ls[i] as Label).label_settings = _ls_lit  # the caption fades through self_modulate
	_apply(i)
	set_process(not manual)


func _apply(i: int) -> void:
	var lt: = _lantern(i)
	if lt == null:
		return
	var g: = _g[i]
	_applying = true
	lt.self_modulate = _unlit.lerp(Color.WHITE, g)
	lt.pivot_offset = Vector2(lt.size.x * 0.5, PIVOT_Y)
	lt.rotation = _rot[i]
	lt.position = _base[i] + Vector2(0.0, _drop[i])
	_applying = false
	var on: = g > 0.001
	var hs: Sprite2D = _halo[i]
	hs.visible = on
	hs.self_modulate = Color(V10DS.GOLD_500, HALO_A * g)
	var a: = LIGHT_A * _light_k * g
	var inner: CanvasItem = _inner[i]
	inner.visible = on and a > 0.001
	if _mats[i] != null:
		var m: ShaderMaterial = _mats[i]
		m.set_shader_parameter(&"amount", a)
		m.set_shader_parameter(&"spread", lerpf(0.55, 1.0, g))
		m.set_shader_parameter(&"under", lt.self_modulate)
	else:
		inner.self_modulate = Color(Color.WHITE, a)
	var th: _Thread = _thread[i]
	if absf(th.length - _drop[i]) > 0.01:
		th.length = _drop[i]
		th.queue_redraw()
	if i < home.lantern_ls.size() and is_instance_valid(home.lantern_ls[i]) and _kind[i] != IDLE:
		(home.lantern_ls[i] as Label).self_modulate = _cap_ratio.lerp(Color.WHITE, g)


# a lantern at rest: canonical hud2 caption (same LabelSettings V10HudHome builds), no leftovers
func _rest(i: int) -> void:
	if i < home.lantern_ls.size() and is_instance_valid(home.lantern_ls[i]):
		var l: Label = home.lantern_ls[i]
		l.label_settings = _ls_lit if _g[i] > 0.5 else _ls_unlit
		l.self_modulate = Color.WHITE


func _update_process() -> void:
	set_process(not manual and (_kind[0] != IDLE or _kind[1] != IDLE or _kind[2] != IDLE))


# V10HudHome.layout_now() puts the lantern back on its layout rect: take that as the new base, re-apply the offset
func _on_rect(i: int) -> void:
	if _applying or not _set_up:
		return
	var lt: = _lantern(i)
	if lt == null:
		return
	var b: = _layout_pos(i, _base[i])
	if lt.position.is_equal_approx(b):
		_base[i] = b
		if _drop[i] != 0.0:
			_applying = true
			lt.position = b + Vector2(0.0, _drop[i])
			_applying = false
	lt.pivot_offset = Vector2(lt.size.x * 0.5, PIVOT_Y)
	(_halo[i] as Node2D).position = lt.size * 0.5
	(_thread[i] as Node2D).position = Vector2(lt.size.x * 0.5, PIVOT_Y)
	if _mats[i] != null:
		(_inner[i] as Control).size = lt.size


func _sound(id: String, db: float) -> void:
	sound_count += 1
	last_sound = id
	if ResourceLoader.exists(V10HudFx.SFX % id) or not SFX_FALLBACK.has(id):
		V10HudFx.sound(id, 1.0, db)
		return
	var fb: Array = SFX_FALLBACK[id]
	V10HudFx.sound(str(fb[0]), float(fb[1]), db + float(fb[2]))


static func _blank_tex() -> GradientTexture2D:
	if _blank == null:
		_blank = GradientTexture2D.new()
		_blank.width = 4
		_blank.height = 4
		var g: = Gradient.new()
		g.set_color(0, Color.TRANSPARENT)
		g.set_color(1, Color.TRANSPARENT)
		_blank.gradient = g
	return _blank


# the same soft radial V10HudHome builds for _Deco (fallback when the home has none)
static func _radial_tex() -> GradientTexture2D:
	if _radial == null:
		_radial = GradientTexture2D.new()
		_radial.fill = GradientTexture2D.FILL_RADIAL
		_radial.fill_from = Vector2(0.5, 0.5)
		_radial.fill_to = Vector2(1.0, 0.5)
		var g: = Gradient.new()
		g.set_color(0, Color.WHITE)
		g.set_color(1, Color(Color.WHITE, 0.0))
		_radial.gradient = g
	return _radial


class _Thread:
	extends Node2D
	var length: = 0.0

	func _draw() -> void:
		if length > 0.25:
			# continues the _Deco thread (paper.700 α 0.5 at its end) down to the lowered ring
			draw_line(Vector2(0.0, -length), Vector2.ZERO, Color(V10DS.PAPER_700, 0.5), 1.0, true)
