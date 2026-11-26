class_name V10HudFxLanternFxTest
extends RefCounted

# Selftest of V10LanternFx (scripts/v10/hudfx/lantern_fx.gd). Deterministic: the helper is stepped with
# advance(dt) inside one frame (no wall clock). Run: lantern_fx_demo.tscn -- --selftest=1
#   swing     ≤ 6°, first peak visible, second period ≈ 40 % of the first, exactly 2 periods (3 sign changes),
#             then rotation 0, process off, and still afterwards (no idle sway); rise 8 → 0 px in 300 ms
#   ignite    starts at 0.5 period, lasts 0.40 s; tint → white, halo gold.500 α 0.22, inner light ≤ 0.55,
#             light colours value ≤ 0.8; caption paper.300; one ignite sound
#   exhale    0.30 s, light → 0, lantern y + 8, caption paper.500, exhale sound, changed(i, false)
#   repeat    light/extinguish storms: continuous rotation and position, final state right, no tween created,
#             changed() only on real flips; set_state no-op / snap
#   levels    min: no swing, no motion, 120 ms fades, lowered position applies, no inner light; mid: light × 0.6
#   attach    before layout (calls queued and replayed), after layout, idempotent; glow hand-over
#   layout    layout_now() and new insets keep the offsets; pivot at the thread point
#   cleanup   home freed mid-animation; detach() restores hud2; freeing the helper alone restores the glow
#   fallback  no shader / no painted lantern → additive pool sprite; sounds fall back
#   code      no hex / Color(0.x) literals, no tweens or loops in the module

const DT: = 1.0 / 200.0

static var _passed: = 0
static var _failed: = 0
static var _lines: Array = []


static func _ok(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		_lines.append(what)


static func _near(a: float, b: float, eps: = 0.001) -> bool:
	return absf(a - b) <= eps


static func run(host: Node) -> Dictionary:
	_passed = 0
	_failed = 0
	_lines = []
	var keep_fx: = V10Hud2Util.fx_override
	var keep_ins: = V10Hud2Util.sim_insets
	V10Hud2Util.fx_override = "full"
	V10Hud2Util.sim_insets = {}
	await _swing_ignite(host)
	await _exhale(host)
	await _repeat(host)
	await _min(host)
	await _mid(host)
	await _attach_order(host)
	await _relayout(host)
	await _cleanup(host)
	await _fallback(host)
	_code()
	V10LanternFx.force_fallback = false
	V10Hud2Util.fx_override = keep_fx
	V10Hud2Util.sim_insets = keep_ins
	return {"passed": _passed, "failed": _failed, "lines": _lines}


static func _home(host: Node, lit: Array, attach: = true) -> V10HudHome:
	var h: = V10HudHome.new()
	h.configure({"hero": "mc", "nick": "Гость", "level": "1-4", "path": "Чайный сад", "affinity": 6, "lit": lit.duplicate()})
	host.add_child(h)
	if attach:
		V10LanternFx.attach(h)
	await host.get_tree().process_frame
	return h


static func _free(host: Node, h: Node) -> void:
	if is_instance_valid(h):
		h.queue_free()
	await host.get_tree().process_frame


static func _run_for(fx: V10LanternFx, secs: float) -> void:
	var n: = int(ceil(secs / DT))
	for s in n:
		fx.advance(DT)


static func _lan_pos(h: V10HudHome, i: int) -> Vector2:
	return (h.L.lanterns[i] as Rect2).position


# ------------------------------------------------------------------ swing + ignite

static func _swing_ignite(host: Node) -> void:
	var h: = await _home(host, [true, false, false])
	var fx: = V10LanternFx.of(h)
	_ok(fx != null and fx.get_parent() == h, "attach: helper is a child of the home")
	if fx == null:
		await _free(host, h)
		return
	var lt: TextureRect = h.lantern_tr[1]
	var base: = _lan_pos(h, 1)
	_ok(fx.base_of(1) == base, "attach: base = layout rect")
	_ok(_near(lt.position.y, base.y + V10LanternFx.DROP), "attach: an unlit lantern hangs 8 px lower")
	_ok(_near(h.lantern_tr[0].position.y, _lan_pos(h, 0).y), "attach: a lit lantern hangs at its layout rect")
	_ok(lt.pivot_offset == Vector2(lt.size.x * 0.5, V10LanternFx.PIVOT_Y), "pivot: top centre (thread point)")
	_ok(not fx.is_processing(), "attach: _process off at rest")
	_ok(lt.self_modulate.is_equal_approx(V10DS.PAPER_700.darkened(0.35)), "attach: unlit tint as hud_home")
	_ok(lt.modulate.is_equal_approx(Color.WHITE), "attach: tint moved off modulate (light children untinted)")
	var flips: = []
	fx.changed.connect(func(i: int, on: bool) -> void: flips.append([i, on]))
	var tweens0: = host.get_tree().get_processed_tweens().size()
	var snd0: = fx.sound_count
	fx.light(1)
	_ok(fx.is_processing() and fx.is_animating(1), "light: animating with _process on")
	_ok(flips.size() == 1 and flips[0] == [1, true], "light: changed(1, true)")
	_ok(bool(h.lit[1]), "light: home.lit follows")
	var t: = 0.0
	var max_a: = 0.0
	var p1: = 0.0
	var p2: = 0.0
	var prev: = 0.0
	var signs: = 0
	var g_start: = -1.0
	var g_half: = -1.0
	var g_end: = -1.0
	var max_light: = 0.0
	var max_jump: = 0.0
	var drop_at_rise: = -1.0
	var mid_ignite_rot: = 0.0
	var anim_before_end: = false
	var n: = int(ceil((V10LanternFx.SWING_T + 0.05) / DT))
	for s in n:
		fx.advance(DT)
		t += DT
		var r: = lt.rotation
		max_a = maxf(max_a, absf(r))
		if t < V10LanternFx.PERIOD:
			p1 = maxf(p1, absf(r))
		else:
			p2 = maxf(p2, absf(r))
		if r != 0.0 and prev != 0.0 and signf(r) != signf(prev):
			signs += 1
		max_jump = maxf(max_jump, absf(r - prev))
		prev = r
		if g_start < 0.0 and fx.glow_of(1) > 0.0005:
			g_start = t
		if g_half < 0.0 and t >= V10LanternFx.IGNITE_AT + V10LanternFx.T_IGNITE * 0.5:
			g_half = fx.glow_of(1)
		if g_end < 0.0 and t >= V10LanternFx.IGNITE_AT + V10LanternFx.T_IGNITE + DT * 0.5:
			g_end = fx.glow_of(1)
		max_light = maxf(max_light, fx.light_alpha(1))
		if drop_at_rise < 0.0 and t >= V10LanternFx.RISE_T + DT * 0.5:
			drop_at_rise = fx.drop_of(1)
		if absf(t - (V10LanternFx.IGNITE_AT + 0.2)) < DT * 0.5:
			mid_ignite_rot = r
		if absf(t - (V10LanternFx.SWING_T - 0.02)) < DT * 0.5:
			anim_before_end = fx.is_animating(1)
	_ok(max_a <= deg_to_rad(6.0), "swing: amplitude %.2f° ≤ 6°" % rad_to_deg(max_a))
	_ok(max_a >= deg_to_rad(4.5), "swing: visible first peak (%.2f°)" % rad_to_deg(max_a))
	_ok(p1 > 0.0 and p2 / p1 > 0.3 and p2 / p1 < 0.5, "swing: second swing %.0f %% of the first (≈ 40 %%)" % (p2 / maxf(p1, 0.0001) * 100.0))
	_ok(signs == 3, "swing: exactly two periods (%d sign changes, want 3)" % signs)
	_ok(max_jump < 0.01, "swing: continuous (max step %.4f rad)" % max_jump)
	_ok(anim_before_end, "swing: still running just before 2 periods")
	_ok(lt.rotation == 0.0, "swing: ends exactly at 0°")
	_ok(not fx.is_animating(1) and not fx.is_processing(), "swing: process off after 2 periods")
	_ok(absf(mid_ignite_rot) > deg_to_rad(1.0), "ignite: happens mid-swing")
	_ok(drop_at_rise >= 0.0 and drop_at_rise < 0.05, "light: rises 8 → 0 px in 300 ms (%.2f)" % drop_at_rise)
	_ok(_near(g_start, V10LanternFx.IGNITE_AT, DT * 1.5), "ignite: starts at 0.5 period (%.3f s)" % g_start)
	_ok(V10LanternFx.T_IGNITE == 0.40 and _near(g_half, 0.875, 0.02) and g_end == 1.0,
			"ignite: 0.40 s CUBIC_OUT (half-way %.3f, want 0.875; end %.4f)" % [g_half, g_end])
	_ok(max_light <= 0.55 and max_light > 0.3, "ignite: inner light α %.2f ≤ 0.55" % max_light)
	_ok(lt.self_modulate.is_equal_approx(Color.WHITE), "ignite: lantern tint → white")
	_ok(_near(lt.position.y, base.y) and _near(fx.drop_of(1), 0.0), "lit: back at its layout rect")
	var hs: = fx.halo_node(1)
	_ok(hs != null and hs.visible and hs.self_modulate.is_equal_approx(Color(V10DS.GOLD_500, 0.22)), "halo: gold.500 α 0.22 (= _Deco)")
	_ok(hs != null and hs.show_behind_parent and _near(hs.scale.x * hs.texture.get_size().x, 128.0, 0.5), "halo: 128 px behind the lantern")
	var m: = (fx.light_node(1) as CanvasItem).material as ShaderMaterial
	_ok(m != null, "inner light: shader material")
	if m:
		var core: Color = m.get_shader_parameter(&"core")
		var rim: Color = m.get_shader_parameter(&"rim")
		_ok(core.v <= 0.8 + 0.002 and rim.v <= 0.8 + 0.002, "light colours: value ≤ 0.8 (warm, never white)")
	var lab: Label = h.lantern_ls[1]
	_ok(lab.label_settings == V10Type.settings("ui", 18, V10DS.PAPER_300, true) and lab.self_modulate == Color.WHITE,
			"caption: paper.300 when lit (hud_home settings)")
	_ok(fx.sound_count == snd0 + 1 and fx.last_sound == "lantern_ignite", "ignite: one ignite sound")
	# a lit lantern is STILL afterwards
	var still: = true
	for s in 200:
		fx.advance(DT)
		still = still and lt.rotation == 0.0 and _near(fx.glow_of(1), 1.0) and fx.drop_of(1) == 0.0
	_ok(still and not fx.is_processing(), "lit at rest: no sway, no flicker, no processing")
	_ok(host.get_tree().get_processed_tweens().size() == tweens0, "no tween created (no infinite tweens)")
	# light() on a lit lantern: a new task → swing again, no second ignite sound
	var snd1: = fx.sound_count
	fx.light(1)
	_ok(fx.is_animating(1) and flips.size() == 1, "light on lit: swings, no changed()")
	_run_for(fx, V10LanternFx.SWING_T + 0.05)
	_ok(fx.sound_count == snd1 and lt.rotation == 0.0 and not fx.is_processing(), "light on lit: no ignite sound, settles")
	# manual clock (demo shots): _process never turns on, advance() drives it
	fx.manual = true
	fx.extinguish(1)
	_ok(fx.is_animating(1) and not fx.is_processing(), "manual: animating without _process")
	_run_for(fx, 0.35)
	_ok(not fx.is_animating(1) and _near(fx.drop_of(1), 8.0) and not fx.is_processing(), "manual: advance() finishes it")
	fx.manual = false
	await _free(host, h)


# ------------------------------------------------------------------ exhale

static func _exhale(host: Node) -> void:
	var h: = await _home(host, [true, false, false])
	var fx: = V10LanternFx.of(h)
	var lt: TextureRect = h.lantern_tr[0]
	var base: = _lan_pos(h, 0)
	var flips: = []
	fx.changed.connect(func(i: int, on: bool) -> void: flips.append([i, on]))
	fx.extinguish(0)
	_ok(fx.last_sound == "lantern_exhale", "exhale: sound")
	_ok(flips == [[0, false]] and not bool(h.lit[0]), "exhale: changed(0, false), home.lit follows")
	var t: = 0.0
	var t_done: = -1.0
	var mid_g: = -1.0
	var mid_d: = -1.0
	var max_dy: = 0.0
	var prev_y: = lt.position.y
	for s in int(0.4 / DT):
		fx.advance(DT)
		t += DT
		max_dy = maxf(max_dy, absf(lt.position.y - prev_y))
		prev_y = lt.position.y
		if absf(t - 0.15) < DT * 0.5:
			mid_g = fx.glow_of(0)
			mid_d = fx.drop_of(0)
		if t_done < 0.0 and not fx.is_animating(0):
			t_done = t
	_ok(mid_g > 0.0 and mid_g < 0.5 and mid_d > 4.0 and mid_d < 8.0, "exhale: mid-way at 0.15 s (g %.2f, drop %.1f)" % [mid_g, mid_d])
	_ok(_near(t_done, V10LanternFx.T_EXHALE, DT * 1.5) and V10LanternFx.T_EXHALE == 0.30, "exhale: 0.30 s (%.3f)" % t_done)
	_ok(_near(lt.position.y, base.y + 8.0) and lt.rotation == 0.0, "exhale: lowered y + 8")
	_ok(max_dy < 1.5, "exhale: lowering is continuous (max %.2f px/step)" % max_dy)
	_ok(fx.glow_of(0) == 0.0 and not fx.halo_node(0).visible and fx.light_alpha(0) == 0.0, "exhale: light and halo out")
	_ok(lt.self_modulate.is_equal_approx(V10DS.PAPER_700.darkened(0.35)), "exhale: unlit tint")
	var lab: Label = h.lantern_ls[0]
	_ok(lab.label_settings == V10Type.settings("ui", 18, V10DS.PAPER_500, true) and lab.self_modulate == Color.WHITE,
			"caption: paper.500 when unlit")
	_ok(not fx.is_processing(), "exhale: process off")
	var snd: = fx.sound_count
	fx.extinguish(0)
	_ok(fx.sound_count == snd and not fx.is_animating(0) and flips.size() == 1, "extinguish on unlit: no-op")
	await _free(host, h)


# ------------------------------------------------------------------ storms, set_state

static func _repeat(host: Node) -> void:
	var h: = await _home(host, [true, false, false])
	var fx: = V10LanternFx.of(h)
	var lt: TextureRect = h.lantern_tr[2]
	var flips: = []
	fx.changed.connect(func(i: int, on: bool) -> void: flips.append([i, on]))
	var tweens0: = host.get_tree().get_processed_tweens().size()
	var rng: = RandomNumberGenerator.new()
	rng.seed = 42
	var max_rot: = 0.0
	var max_jump_r: = 0.0
	var max_jump_y: = 0.0
	var max_light: = 0.0
	var prev_r: = lt.rotation
	var prev_y: = lt.position.y
	for k in 12:
		if k % 2 == 0:
			fx.light(2)
		else:
			fx.extinguish(2)
		for s in rng.randi_range(4, 140):
			fx.advance(DT)
			max_rot = maxf(max_rot, absf(lt.rotation))
			max_jump_r = maxf(max_jump_r, absf(lt.rotation - prev_r))
			max_jump_y = maxf(max_jump_y, absf(lt.position.y - prev_y))
			max_light = maxf(max_light, fx.light_alpha(2))
			prev_r = lt.rotation
			prev_y = lt.position.y
	_ok(max_rot <= deg_to_rad(6.0), "storm: rotation ≤ 6° (%.2f°)" % rad_to_deg(max_rot))
	_ok(max_jump_r < 0.012, "storm: rotation continuous (%.4f rad/step)" % max_jump_r)
	_ok(max_jump_y < 1.5, "storm: position continuous (%.2f px/step)" % max_jump_y)
	_ok(max_light <= 0.55, "storm: light α ≤ 0.55")
	_ok(flips.size() == 12, "storm: changed() on every real flip (%d)" % flips.size())
	fx.extinguish(2)
	_run_for(fx, 0.5)
	_ok(not bool(h.lit[2]) and fx.glow_of(2) == 0.0 and _near(fx.drop_of(2), 8.0) and lt.rotation == 0.0 and not fx.is_processing(),
			"storm: settles unlit")
	fx.light(2)
	_run_for(fx, V10LanternFx.SWING_T + 0.05)
	_ok(bool(h.lit[2]) and _near(fx.glow_of(2), 1.0) and fx.drop_of(2) == 0.0 and lt.rotation == 0.0 and not fx.is_processing(),
			"storm: settles lit")
	_ok(host.get_tree().get_processed_tweens().size() == tweens0, "storm: no tweens created")
	# set_state
	var nf: = flips.size()
	fx.set_state(1, false)
	_ok(flips.size() == nf and not fx.is_animating(1), "set_state: same state is a no-op")
	fx.set_state(1, true, false)
	_ok(flips.size() == nf + 1 and fx.glow_of(1) == 1.0 and fx.drop_of(1) == 0.0 and not fx.is_animating(1) and not fx.is_processing(),
			"set_state(animate=false): snaps lit, no processing")
	_ok(_near(h.lantern_tr[1].position.y, _lan_pos(h, 1).y), "set_state(animate=false): lit position")
	fx.set_state(1, false, true)
	_ok(fx.is_animating(1) and flips.size() == nf + 2, "set_state(animate): exhales")
	_run_for(fx, 0.4)
	_ok(_near(h.lantern_tr[1].position.y, _lan_pos(h, 1).y + 8.0), "set_state(animate): lowered")
	fx.light(-1)
	fx.extinguish(3)
	fx.set_state(7, true)
	_ok(not fx.is_processing(), "out-of-range index ignored")
	await _free(host, h)


# ------------------------------------------------------------------ fx levels

static func _min(host: Node) -> void:
	V10Hud2Util.fx_override = "min"
	var h: = await _home(host, [true, false, false])
	var fx: = V10LanternFx.of(h)
	var lt: TextureRect = h.lantern_tr[1]
	var base: = _lan_pos(h, 1)
	_ok(_near(lt.position.y, base.y + 8.0), "min: the lowered position applies at attach")
	var snd: = fx.sound_count
	fx.light(1)
	_ok(_near(lt.position.y, base.y) and lt.rotation == 0.0, "min light: no rise motion (final position at once)")
	_ok(fx.sound_count == snd + 1, "min light: sound at once")
	var rot_seen: = false
	for s in int(0.06 / DT):
		fx.advance(DT)
		rot_seen = rot_seen or lt.rotation != 0.0
	_ok(fx.glow_of(1) > 0.3 and fx.glow_of(1) < 0.7, "min light: 120 ms fade mid-way (%.2f)" % fx.glow_of(1))
	for s in int(0.08 / DT):
		fx.advance(DT)
		rot_seen = rot_seen or lt.rotation != 0.0
	_ok(not rot_seen, "min: no swing")
	_ok(fx.glow_of(1) == 1.0 and not fx.is_processing(), "min light: done in 120 ms, process off")
	_ok(fx.light_alpha(1) == 0.0 and fx.halo_node(1).visible, "min: no inner light, halo stays (information)")
	fx.extinguish(0)
	_ok(_near(h.lantern_tr[0].position.y, _lan_pos(h, 0).y + 8.0), "min extinguish: lowered at once (no motion)")
	_run_for(fx, 0.13)
	_ok(fx.glow_of(0) == 0.0 and not fx.is_processing(), "min extinguish: 120 ms fade")
	await _free(host, h)
	V10Hud2Util.fx_override = "full"


static func _mid(host: Node) -> void:
	V10Hud2Util.fx_override = "mid"
	var h: = await _home(host, [true, false, false])
	var fx: = V10LanternFx.of(h)
	_ok(_near(fx.light_alpha(0), V10LanternFx.LIGHT_A * V10LanternFx.LIGHT_MID), "mid: less light (×0.6) at attach")
	fx.light(1)
	var rot_seen: = false
	for s in int((V10LanternFx.SWING_T + 0.05) / DT):
		fx.advance(DT)
		rot_seen = rot_seen or absf(h.lantern_tr[1].rotation) > 0.01
	_ok(rot_seen, "mid: still swings")
	_ok(_near(fx.light_alpha(1), V10LanternFx.LIGHT_A * V10LanternFx.LIGHT_MID), "mid: inner light × 0.6 after ignite")
	await _free(host, h)
	V10Hud2Util.fx_override = "full"


# ------------------------------------------------------------------ attach before / after layout, glow hand-over

static func _attach_order(host: Node) -> void:
	# before: the home is not in the tree yet (no lanterns, no layout)
	var h: = V10HudHome.new()
	var fx: = V10LanternFx.attach(h)
	_ok(fx != null and V10LanternFx.of(h) == fx, "attach before layout: helper created")
	h.configure({"hero": "mc", "lit": [true, false, false]})
	fx.light(1)  # queued until the home is laid out
	fx.set_state(2, false, false)
	host.add_child(h)
	await host.get_tree().process_frame
	_ok(fx.halo_node(0) != null and fx.halo_node(0).get_parent() == h.lantern_tr[0], "attach before layout: set up on ready")
	_ok(bool(h.lit[1]) and fx.is_animating(1), "attach before layout: queued light() replayed")
	_ok(_near(h.lantern_tr[2].position.y, _lan_pos(h, 2).y + 8.0), "attach before layout: unlit lowered")
	_ok(V10LanternFx.attach(h) == fx, "attach: idempotent")
	var cnt: = 0
	for c in h.get_children():
		if c is V10LanternFx:
			cnt += 1
	_ok(cnt == 1, "attach: one helper per home")
	# glow hand-over: _Deco now draws a blank texture (or skips it, hooked); our halo uses the original
	_ok(h.has_meta(V10LanternFx.META), "glow: home carries the hand-over meta for _Deco")
	var blank: = h.glow
	var ok_blank: = blank != null and blank.gradient != null
	if ok_blank:
		for k in blank.gradient.get_point_count():
			ok_blank = ok_blank and blank.gradient.get_color(k).a == 0.0
	_ok(ok_blank, "glow: _Deco's static glow is blank")
	_ok(fx.halo_node(0).texture != blank and fx.halo_node(0).texture is GradientTexture2D, "glow: halo uses the original sprite")
	_ok(not fx.halo_node(1).visible or bool(h.lit[1]), "glow: halo only on lit lanterns")
	await _free(host, h)
	# after: attached to a laid-out home (default lit [true, false, true])
	var h2: = await _home(host, [true, false, true], false)
	var fx2: = V10LanternFx.attach(h2)
	_ok(fx2 != null and fx2.halo_node(2) != null and fx2.halo_node(2).visible, "attach after layout: set up at once")
	_ok(_near(h2.lantern_tr[1].position.y, _lan_pos(h2, 1).y + 8.0), "attach after layout: unlit lowered")
	await _free(host, h2)


# ------------------------------------------------------------------ re-layout

static func _relayout(host: Node) -> void:
	var h: = await _home(host, [true, false, false])
	var fx: = V10LanternFx.of(h)
	h.layout_now()
	_ok(_near(h.lantern_tr[1].position.y, _lan_pos(h, 1).y + 8.0) and _near(h.lantern_tr[0].position.y, _lan_pos(h, 0).y),
			"layout_now: offsets survive")
	var y0: = _lan_pos(h, 1).y
	V10Hud2Util.sim_insets = {"top": 48.0, "bottom": 24.0}
	h.layout_now()
	_ok(_near(_lan_pos(h, 1).y, y0 + 48.0), "relayout: layout moved (insets)")
	_ok(fx.base_of(1) == _lan_pos(h, 1), "relayout: new base stored")
	_ok(_near(h.lantern_tr[1].position.y, y0 + 48.0 + 8.0) and _near(h.lantern_tr[2].position.y, _lan_pos(h, 2).y + 8.0),
			"relayout: lowered lanterns keep +8 on the new base")
	fx.light(1)
	_run_for(fx, 0.1)
	V10Hud2Util.sim_insets = {}
	h.layout_now()
	_ok(_near(h.lantern_tr[1].position.y, _lan_pos(h, 1).y + fx.drop_of(1)), "relayout mid-animation: base + current drop")
	_run_for(fx, V10LanternFx.SWING_T)
	_ok(_near(h.lantern_tr[1].position.y, _lan_pos(h, 1).y) and h.lantern_tr[1].rotation == 0.0, "relayout: settles on the new base")
	_ok(h.lantern_tr[1].pivot_offset == Vector2(h.lantern_tr[1].size.x * 0.5, V10LanternFx.PIVOT_Y), "relayout: pivot kept")
	await _free(host, h)


# ------------------------------------------------------------------ cleanup

static func _cleanup(host: Node) -> void:
	# the home freed mid-animation
	var h: = await _home(host, [true, false, false])
	var fx: = V10LanternFx.of(h)
	fx.light(1)
	fx.extinguish(0)
	_run_for(fx, 0.2)
	_ok(fx.is_processing(), "cleanup: animating before the free")
	h.queue_free()
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	_ok(not is_instance_valid(fx), "cleanup: helper freed with the home mid-animation")
	# detach(): lanterns handed back exactly as V10HudHome built them
	var h2: = await _home(host, [true, false, false])
	var fx2: = V10LanternFx.of(h2)
	var orig: = fx2.halo_node(0).texture
	fx2.light(1)
	_run_for(fx2, 0.3)
	fx2.detach()
	await host.get_tree().process_frame
	_ok(not is_instance_valid(fx2) and not h2.has_meta(V10LanternFx.META), "detach: helper and meta gone")
	_ok(h2.glow == orig, "detach: _Deco's glow restored")
	var clean: = true
	for i in 3:
		var lt: TextureRect = h2.lantern_tr[i]
		clean = clean and lt.get_child_count() == 0 and lt.rotation == 0.0 and lt.position == _lan_pos(h2, i)
		clean = clean and lt.self_modulate == Color.WHITE
		var want: = Color.WHITE if bool(h2.lit[i]) else V10DS.PAPER_700.darkened(0.35)
		clean = clean and lt.modulate.is_equal_approx(want)
	_ok(clean, "detach: lanterns as hud2 builds them (no children, no offsets, modulate tint)")
	# the helper freed alone (no detach): its sprites go, the glow comes back
	var fx3: = V10LanternFx.attach(h2)
	_ok(fx3 != null and h2.glow != orig, "re-attach after detach")
	fx3.queue_free()
	await host.get_tree().process_frame
	var kids: = 0
	for i in 3:
		kids += (h2.lantern_tr[i] as Node).get_child_count()
	_ok(kids == 0 and h2.glow == orig and not h2.has_meta(V10LanternFx.META), "free alone: sprites freed, glow and meta restored")
	await _free(host, h2)


# ------------------------------------------------------------------ fallbacks

static func _fallback(host: Node) -> void:
	V10LanternFx.force_fallback = true
	var h: = await _home(host, [true, false, false])
	var fx: = V10LanternFx.of(h)
	var n: = fx.light_node(0)
	_ok(n is Sprite2D and (n.material as CanvasItemMaterial).blend_mode == CanvasItemMaterial.BLEND_MODE_ADD,
			"fallback: additive pool sprite without the shader")
	_ok(n.visible and fx.light_alpha(0) > 0.0 and fx.light_alpha(0) * n.modulate.a <= 0.55, "fallback: lit, α ≤ 0.55")
	_ok((n.modulate as Color).v <= 0.8 + 0.002, "fallback: warm, value ≤ 0.8")
	fx.light(1)
	_run_for(fx, V10LanternFx.SWING_T + 0.05)
	_ok((fx.light_node(1) as CanvasItem).visible and h.lantern_tr[1].rotation == 0.0, "fallback: light works")
	await _free(host, h)
	V10LanternFx.force_fallback = false
	# no painted lantern texture → fallback pool for that lantern only
	var h2: = await _home(host, [true, false, false], false)
	h2.lantern_tr[0].texture = null
	var fx2: = V10LanternFx.attach(h2)
	_ok(fx2.light_node(0) is Sprite2D and fx2.light_node(1) is TextureRect, "fallback: missing lantern art → pool sprite")
	# sounds: a missing hudfx ogg falls back to a quiet juice sound (never an error)
	fx2.light(1)
	_run_for(fx2, V10LanternFx.SWING_T + 0.05)
	_ok(fx2.last_sound == "lantern_ignite", "fallback: ignite sound requested")
	await _free(host, h2)


# ------------------------------------------------------------------ code rules

static func _code() -> void:
	var files: = ["res://scripts/v10/hudfx/lantern_fx.gd", "res://scripts/v10/hudfx/demo/lantern_fx_demo.gd",
			"res://shaders/v10/hudfx/lantern_glow.gdshader"]
	var hex: = "Color(" + "\"#"
	var num: = "Color(" + "0."
	for p in files:
		var src: = FileAccess.get_file_as_string(p)
		_ok(src != "", "code: %s readable" % p)
		_ok(src.find(hex) < 0 and src.find(num) < 0, "code: no hex / Color(0.x) literal in %s" % p)
	var mod: = FileAccess.get_file_as_string("res://scripts/v10/hudfx/lantern_fx.gd")
	_ok(mod.find("create_tween") < 0 and mod.find("set_loops") < 0, "code: the module runs no tweens / loops")
	var sh: = FileAccess.get_file_as_string("res://shaders/v10/hudfx/lantern_glow.gdshader")
	_ok(sh.count("texture(") <= 16, "code: shader ≤ 16 texture samples")
