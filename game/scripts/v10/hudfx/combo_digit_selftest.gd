class_name V10HudFxComboDigitTest
extends RefCounted

# Selftest of V10ComboDigit (scripts/v10/hudfx/combo_digit.gd). Deterministic: the digit runs with manual = true
# and its one tween is stepped by 1/60 s (custom_step), so every timing is exact to a frame. One real-time run
# checks that the unpaused path finishes too.
#   var r: Dictionary = await V10HudFxComboDigitTest.run(host)   # {passed, failed, lines}
# Covers: shader present + compiled, for_hud (one per HUD, anchor), 0.60 s total (±1 frame) at full/mid/min,
# scale 1.15→1.0 BACK_OUT, sheen once during the hold (α ≤ 0.25, crosses the ink, never at mid/min/calm),
# replacement restarts (never stacked, no «done» for the replaced one), invisible + not processing after,
# halo α caps (T2 ≤ 0.3, T3 ≤ 0.5 and larger, never at T0/T1 or min, colour value ≤ 0.8), 64 px at every tier,
# z above the showcase dim for T2/T3 only, cut(), n ≤ 0, play before entering the tree, shader-less fallback,
# parent freed mid-animation, auto_free, no colour literals.

const F: = 1.0 / 60.0
const EPS: = 0.0005

static var _p: = 0
static var _f: = 0
static var _lines: = []


static func ok(cond: bool, msg: String) -> void:
	if cond:
		_p += 1
	else:
		_f += 1
		_lines.append("FAIL combo_digit: " + msg)


static func run(host: Node) -> Dictionary:
	_p = 0
	_f = 0
	_lines = []
	var keep_fx: = V10Hud2Util.fx_override
	V10Hud2Util.fx_override = "full"
	var tree: = host.get_tree()
	var root: = Control.new()
	root.name = "ComboDigitTest"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(root)
	await tree.process_frame

	_shader()
	await _for_hud(root, tree)
	_timing_full(root)
	_replace(root)
	_halo(root)
	_levels(root)
	_calm(root, tree)
	_edges(root)
	_fallback(root)
	await _pending(root, tree)
	await _parent_freed(root, tree)
	await _realtime(root, tree)
	_code()

	root.queue_free()
	await tree.process_frame
	V10Hud2Util.fx_override = keep_fx
	return {"passed": _p, "failed": _f, "lines": _lines}


# ------------------------------------------------------------------ helpers

static func _digit(parent: Node) -> V10ComboDigit:
	var d: = V10ComboDigit.new()
	d.manual = true
	parent.add_child(d)
	d.configure(Rect2(24, 704, 320, 80))
	return d


# step until hidden (or t_max); returns samples of everything the rules care about
static func _run(d: V10ComboDigit, t_max: = 1.0) -> Dictionary:
	var r: = {"finish": -1.0, "max_sheen": 0.0, "max_halo": 0.0, "min_scale": 9.0, "max_scale": 0.0,
		"sheen_t0": -1.0, "sheen_t1": -1.0, "sheen_xmin": 1.0e9, "sheen_xmax": -1.0e9, "a_006": -1.0,
		"halo_v": 0.0, "z_mid": d.z_index, "scale_012": -1.0}
	var t: = 0.0
	while t < t_max:
		d.advance(F)
		t += F
		if not d.visible:
			r.finish = t
			break
		var sa: = d.sheen_alpha()
		r.max_sheen = maxf(r.max_sheen, sa)
		if sa > 0.0:
			if r.sheen_t0 < 0.0:
				r.sheen_t0 = t
			r.sheen_t1 = t
			r.sheen_xmin = minf(r.sheen_xmin, d.sheen_pos())
			r.sheen_xmax = maxf(r.sheen_xmax, d.sheen_pos())
		r.max_halo = maxf(r.max_halo, d.halo_alpha())
		if d.halo.visible:
			r.halo_v = maxf(r.halo_v, d.halo.modulate.v)
		r.min_scale = minf(r.min_scale, d.scale.x)
		r.max_scale = maxf(r.max_scale, d.scale.x)
		if absf(t - 0.05) < F * 0.5:
			r.a_006 = d.modulate.a
		if absf(t - 0.3) < F * 0.5:
			r.z_mid = d.z_index
		if absf(t - 0.1333) < F * 0.5:
			r.scale_012 = d.scale.x
	return r


static func _near(t: float, want: float) -> bool:
	return absf(t - want) <= F + EPS


# ------------------------------------------------------------------ shader

static func _shader() -> void:
	var sh: = V10HudFx.shader("combo_gold")
	ok(sh != null, "shader res://shaders/v10/hudfx/combo_gold.gdshader missing")
	ok(V10HudFx.shaders_list.has("combo_gold"), "combo_gold not registered for V10HudFx.warm()")
	if sh == null:
		return
	var names: = []
	for u in sh.get_shader_uniform_list():
		names.append(str(u.name))
	for want in ["gold_top", "gold_mid", "gold_low", "light", "sheen_x", "sheen_a", "y_top", "y_base"]:
		ok(names.has(want), "shader did not compile / lacks uniform %s (got %s)" % [want, names])
	var code: = sh.code
	ok(code.count("texture(") <= 16, "shader samples > 16 textures")
	ok(not code.contains("for (") and not code.contains("while"), "shader has loops")


# ------------------------------------------------------------------ for_hud in the real HUD

static func _for_hud(root: Control, tree: SceneTree) -> void:
	var hud: = V10HudMatch.new()
	root.add_child(hud)
	hud.configure({"hero": "mc", "level": "1-2", "total": 30, "left": 30})
	await tree.process_frame
	var d: = V10ComboDigit.for_hud(hud)
	var d2: = V10ComboDigit.for_hud(hud)
	ok(d != null and d == d2, "for_hud made a second digit")
	var count: = 0
	for c in hud.get_children():
		if c is V10ComboDigit:
			count += 1
	ok(count == 1, "for_hud: %d digits under the HUD" % count)
	ok(d.get_rect().position == hud.combo_anchor().position and d.size == hud.combo_anchor().size,
		"digit not at hud.combo_anchor(): %s vs %s" % [d.get_rect(), hud.combo_anchor()])
	ok(d.gold_mat != null and d.gold_mat.shader != null, "digit has no combo_gold material")
	ok(not d.visible and not d.is_processing(), "fresh digit visible or processing")
	ok(not hud.persistent_nodes().has(d), "digit counted as a permanent match element")
	d.manual = true
	d.show_combo(4, 0, "mc")
	ok(d.visible and d.text == V10ComboDigit.SIGN + "4", "for_hud digit did not show ×4")
	_run(d)
	ok(not d.visible, "for_hud digit still visible after the run")
	# the integration hook path: hud2 finds the class by name and calls it untyped
	var cdc: = V10Hud2Util.opt_class("V10ComboDigit")
	ok(cdc != null, "V10Hud2Util.opt_class(\"V10ComboDigit\") is null (run --import)")
	if cdc:
		var via: Object = cdc.call("for_hud", hud)
		ok(via == d, "hook: for_hud via the Script returned another node")
		via.call("show_combo", 6, 2, "mc", 0.36)
		ok(d.visible and d.tier == 2 and d.text == V10ComboDigit.SIGN + "6", "hook: untyped show_combo did not play")
		_run(d)
		ok(not d.visible, "hook: digit still visible after the run")
	hud.queue_free()


# ------------------------------------------------------------------ timing (full)

static func _timing_full(root: Control) -> void:
	var d: = _digit(root)
	var dones: = [0]
	d.done.connect(func() -> void: dones[0] += 1)
	ok(is_equal_approx(d.total_time(), 0.6), "total_time %.3f ≠ 0.60" % d.total_time())
	d.show_combo(3, 0, "mc")
	ok(d.visible and d.modulate.a == 0.0, "show: not visible at α 0")
	ok(is_equal_approx(d.scale.x, 1.15), "full: scale does not start at 1.15 (%.3f)" % d.scale.x)
	ok(d.font_size == 64 and d.text == V10ComboDigit.SIGN + "3", "text/size wrong: %s %d" % [d.text, d.font_size])
	var r: = _run(d)
	ok(_near(r.finish, 0.6), "full: total %.3f s ≠ 0.60 ±1 frame" % r.finish)
	ok(r.a_006 > 0.3 and r.a_006 < 0.7, "full: α at 0.05 s = %.2f (120 ms linear fade-in)" % r.a_006)
	ok(r.min_scale < 1.0 and r.min_scale > 0.95, "full: BACK_OUT should overshoot just under 1.0 (min %.3f)" % r.min_scale)
	ok(absf(r.scale_012 - 1.0) < 0.02, "full: scale not settled after the 120 ms in (%.3f)" % r.scale_012)
	ok(r.max_sheen > 0.0 and r.max_sheen <= 0.25, "full: sheen α %.2f not in (0, 0.25]" % r.max_sheen)
	ok(r.sheen_t0 >= 0.12 - EPS and r.sheen_t1 <= 0.48 + EPS, "full: sheen outside the hold (%.3f..%.3f)" % [r.sheen_t0, r.sheen_t1])
	ok(r.sheen_xmin < 0.0 and r.sheen_xmax > d.text_width(), "full: sheen does not cross the ink (%.0f..%.0f, ink %.0f)" % [r.sheen_xmin, r.sheen_xmax, d.text_width()])
	ok(r.max_halo == 0.0, "T0 has a halo")
	ok(dones[0] == 1, "done emitted %d times" % dones[0])
	ok(not d.visible and not d.is_processing() and not d.showing, "after: visible/processing")
	ok(d.sheen_alpha() == 0.0, "after: sheen left on")
	ok(d.scale == Vector2.ONE and d.z_index == 0, "after: scale/z not reset")
	d.advance(0.5)  # stepping a finished digit is harmless
	ok(not d.visible and dones[0] == 1, "advance after finish re-showed or re-emitted")
	d.queue_free()


# ------------------------------------------------------------------ replacement

static func _replace(root: Control) -> void:
	var d: = _digit(root)
	var dones: = [0]
	d.done.connect(func() -> void: dones[0] += 1)
	d.show_combo(3, 0, "mc")
	for i in 18:
		d.advance(F)
	ok(d.modulate.a > 0.99, "replace: first number not fully in at 0.3 s")
	d.show_combo(4, 0, "mc")
	ok(d.text == V10ComboDigit.SIGN + "4", "replace: text not ×4")
	ok(d.modulate.a == 0.0 and is_equal_approx(d.scale.x, 1.15), "replace: did not restart from α 0 / 1.15")
	ok(dones[0] == 0, "replace: the replaced number emitted done")
	var cnt: = 0
	for c in root.get_children():
		if c is V10ComboDigit and not c.is_queued_for_deletion():
			cnt += 1
	ok(cnt == 1, "replace: %d digits (stacked)" % cnt)
	var r: = _run(d)
	ok(_near(r.finish, 0.6), "replace: second number lasted %.3f s, not 0.60 from its own start" % r.finish)
	ok(dones[0] == 1, "replace: done count %d after the second number" % dones[0])
	# rapid fire: ten numbers 60 ms apart → still one node, last text, one done
	for k in 10:
		d.show_combo(5 + k, 0, "mc")
		for i in 4:
			d.advance(F)
	ok(d.text == V10ComboDigit.SIGN + "14" and d.visible, "rapid: last number not ×14")
	_run(d)
	ok(dones[0] == 2 and not d.visible, "rapid: done %d / visible %s" % [dones[0], d.visible])
	d.queue_free()


# ------------------------------------------------------------------ tier light

static func _halo(root: Control) -> void:
	var d: = _digit(root)
	var res: = {}
	for t in [0, 1, 2, 3]:
		d.show_combo(10, t, "mc")
		ok(d.font_size == 64, "T%d: number is not 64 px" % t)
		ok(d.z_index == (1 if t >= 2 else 0), "T%d: z_index %d" % [t, d.z_index])
		var hs: = d.halo.size
		var r: = _run(d)
		r["size"] = hs
		res[t] = r
		ok(_near(r.finish, 0.6), "T%d: total %.3f" % [t, r.finish])
		ok(r.max_scale <= 1.15 + EPS, "T%d: number grows over 1.15" % t)
	ok(res[0].max_halo == 0.0 and res[1].max_halo == 0.0, "T0/T1 must have no halo")
	ok(res[2].max_halo > 0.15 and res[2].max_halo <= 0.3 + EPS, "T2 halo α %.3f not in (0.15, 0.3]" % res[2].max_halo)
	ok(res[3].max_halo > res[2].max_halo and res[3].max_halo <= 0.5 + EPS, "T3 halo α %.3f not in (T2, 0.5]" % res[3].max_halo)
	ok((res[3].size as Vector2).x > (res[2].size as Vector2).x, "T3 halo not larger than T2")
	ok(res[2].halo_v <= 0.8 + EPS and res[3].halo_v <= 0.8 + EPS, "halo colour value > 0.8 (white light)")
	ok(res[3].z_mid == 1, "T3: z_index not 1 during the hold")
	# every heroine: warm light clamp holds
	for h in V10DS.HEROES:
		d.show_combo(20, 3, h)
		var r2: = _run(d)
		ok(r2.halo_v <= 0.8 + EPS and r2.max_halo <= 0.5 + EPS, "%s T3 halo v %.2f α %.2f" % [h, r2.halo_v, r2.max_halo])
	d.queue_free()


# ------------------------------------------------------------------ fx levels

static func _levels(root: Control) -> void:
	V10Hud2Util.fx_override = "mid"
	var d: = _digit(root)
	d.show_combo(20, 3, "mc")
	ok(is_equal_approx(d.scale.x, 1.15), "mid: lost the scale-in (starts at %.3f)" % d.scale.x)
	var r: = _run(d)
	ok(_near(r.finish, 0.6), "mid: total %.3f" % r.finish)
	ok(r.max_sheen == 0.0, "mid: sheen ran")
	ok(r.min_scale < 1.0, "mid: no BACK_OUT settle")
	ok(r.max_halo > 0.0 and r.max_halo <= 0.5 * 0.7 + EPS, "mid: T3 halo α %.3f > 0.35" % r.max_halo)
	V10Hud2Util.fx_override = "min"
	for t in [0, 3]:
		d.show_combo(20, t, "mc")
		ok(d.scale == Vector2.ONE, "min T%d: starts scaled" % t)
		var m: = _run(d)
		ok(_near(m.finish, 0.6), "min T%d: total %.3f" % [t, m.finish])
		ok(m.min_scale == 1.0 and m.max_scale == 1.0, "min T%d: scale moved" % t)
		ok(m.max_sheen == 0.0, "min T%d: sheen ran" % t)
		ok(m.max_halo == 0.0, "min T%d: halo shown" % t)
		ok(m.a_006 > 0.3 and m.a_006 < 0.7, "min T%d: not a 120 ms fade (α %.2f at 0.05 s)" % [t, m.a_006])
		ok(not d.visible and not d.is_processing(), "min T%d: visible/processing after" % t)
	ok(d.gold_mat != null, "min: the gold look (information) dropped")
	V10Hud2Util.fx_override = "full"
	d.queue_free()


static func _calm(root: Control, tree: SceneTree) -> void:
	var g: = tree.root.get_node_or_null("G")
	var s: Variant = g.get("S") if g else null
	if not (s is Dictionary):
		ok(false, "calm: G.S not available")
		return
	var had: = (s as Dictionary).has("a11y_calm")
	var was: Variant = (s as Dictionary).get("a11y_calm", false)
	s["a11y_calm"] = true
	ok(V10HudFx.calm(), "calm: V10HudFx.calm() did not follow a11y_calm")
	var d: = _digit(root)
	d.show_combo(20, 3, "mc")
	var r: = _run(d)
	ok(r.max_sheen == 0.0, "calm: sheen ran")
	ok(r.max_halo <= 0.5 * 0.6 + EPS, "calm: T3 halo α %.3f > 0.30" % r.max_halo)
	ok(_near(r.finish, 0.6), "calm: total %.3f" % r.finish)
	if had:
		s["a11y_calm"] = was
	else:
		(s as Dictionary).erase("a11y_calm")
	d.queue_free()


# ------------------------------------------------------------------ edges

static func _edges(root: Control) -> void:
	var d: = _digit(root)
	var dones: = [0]
	d.done.connect(func() -> void: dones[0] += 1)
	d.cut()
	ok(not d.visible and dones[0] == 0, "cut() while hidden did something")
	d.show_combo(0, 0, "mc")
	ok(not d.visible, "×0 shown")
	d.show_combo(-3, 2, "mc")
	ok(not d.visible and d.z_index == 0, "negative number shown")
	d.show_combo(7, 2, "mc")
	for i in 12:
		d.advance(F)
	d.show_combo(0, 0, "mc")  # n ≤ 0 while showing = leave now
	var r: = _run(d, 0.3)
	ok(r.finish > 0.0 and r.finish <= 0.12 + F + EPS, "n=0 while showing: left in %.3f s (≤ 0.12)" % r.finish)
	ok(dones[0] == 1 and not d.visible and d.z_index == 0 and not d.halo.visible, "cut: not cleaned up")
	d.show_combo(9999, 3, "nobody")  # unknown heroine → mc accent, long number still one line
	ok(d.visible and d.text == V10ComboDigit.SIGN + "9999" and d.text_width() < 320.0, "×9999 / unknown heroine")
	_run(d)
	ok(not d.visible, "×9999 did not finish")
	var d2: = _digit(root)
	ok(d2.halo.texture == d.halo.texture, "halo gradient texture not shared")
	d2.auto_free = true
	d2.show_combo(2, 0, "mc")
	_run(d2)
	ok(d2.is_queued_for_deletion(), "auto_free digit not freed after done")
	d.queue_free()


static func _fallback(root: Control) -> void:
	var real: = V10HudFx.shader("combo_gold")
	V10HudFx._shaders["combo_gold"] = null
	var d: = _digit(root)
	V10HudFx._shaders["combo_gold"] = real
	ok(d.gold_mat == null and d._gold.material == null, "fallback: material without a shader")
	d.show_combo(6, 3, "mc")
	var r: = _run(d)
	ok(_near(r.finish, 0.6) and r.max_sheen == 0.0, "fallback: run %.3f, sheen %.2f" % [r.finish, r.max_sheen])
	ok(r.max_halo > 0.0, "fallback: T3 light lost with the shader")
	d.queue_free()


static func _pending(root: Control, tree: SceneTree) -> void:
	var d: = V10ComboDigit.new()
	d.manual = true
	d.show_combo(7, 0, "mc")  # not in the tree yet: plays on _ready
	ok(not d.visible, "pending: visible before entering the tree")
	root.add_child(d)
	await tree.process_frame
	ok(d.visible and d.text == V10ComboDigit.SIGN + "7", "pending: did not play after entering the tree")
	var r: = _run(d)
	ok(_near(r.finish, 0.6), "pending: total %.3f" % r.finish)
	d.queue_free()


static func _parent_freed(root: Control, tree: SceneTree) -> void:
	var p: = Control.new()
	root.add_child(p)
	var d: = V10ComboDigit.for_hud(p)  # not a HUD: default anchor
	ok(d.position == V10ComboDigit.DEFAULT_ANCHOR.position, "for_hud on a plain Control: anchor %s" % d.position)
	d.show_combo(12, 3, "mc")
	await tree.process_frame
	await tree.process_frame
	var tw: Tween = d._tw
	p.queue_free()
	for i in 4:
		await tree.process_frame
	ok(not is_instance_valid(d), "parent freed: digit survived")
	ok(tw == null or not tw.is_valid(), "parent freed: tween still running")


static func _realtime(root: Control, tree: SceneTree) -> void:
	var d: = V10ComboDigit.new()
	root.add_child(d)
	d.configure(Rect2(24, 704, 320, 80))
	var fin: = [false]
	d.done.connect(func() -> void: fin[0] = true)
	var t0: = Time.get_ticks_msec()
	d.show_combo(8, 2, "mc")
	var guard: = 0
	while not fin[0] and guard < 600:
		await tree.process_frame
		guard += 1
	var el: = (Time.get_ticks_msec() - t0) / 1000.0
	ok(fin[0], "real time: never finished")
	ok(el >= 0.55 and el < 2.5, "real time: %.2f s" % el)
	ok(not d.visible and not d.is_processing(), "real time: visible/processing after")
	d.queue_free()


static func _code() -> void:
	var re: = RegEx.create_from_string("Color\\(\"#|Color\\(0\\.")
	for f in ["res://scripts/v10/hudfx/combo_digit.gd", "res://scripts/v10/hudfx/demo/combo_digit_demo.gd"]:
		if FileAccess.file_exists(f):
			ok(re.search(FileAccess.get_file_as_string(f)) == null, "colour literal in %s" % f)
