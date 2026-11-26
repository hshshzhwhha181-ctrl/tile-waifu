class_name V10HudFxShowcaseFxTest
extends RefCounted

# V10HudFxShowcaseFxTest — selftest of V10ShowcaseFx (showcase_fx.gd + shaders/v10/hudfx/showcase_live.gdshader).
#   var r: Dictionary = await V10HudFxShowcaseFxTest.run(host)   # {"passed": int, "failed": int, "lines": [failures]}
# Deterministic: each show runs on a real V10ComboShowcase whose own _process is off; the test steps it with
# _advance(dt) and the driver with sync(), exactly the order the game runs them in (driver after the showcase).
#   1 superset   — every hud2/showcase_sprite uniform exists with the same type, hint and default; the board-mask code
#                  is identical line for line; the material gets the same board uniforms as hud2's for the same show
#                  (+ a pixel comparison through a SubViewport when a renderer exists)
#   2 masks      — missing → strengths 0, null textures, no error; present → strength 1, leg box from the mask;
#                  masks are per sprite file (an outfit never borrows the base sprite's mask)
#   3 timeline   — sway only during «держит» (all tiers), peak ≤ 6 px; sheen ONCE, 0.6 s, T2/T3 only; rim T3 only,
#                  0.6 s top → bottom; mid weaker; calm: no sheen, steady rim; min: nothing; skip fades ≤ 120 ms
#   4 particles  — painted textures per element, counts per fx level (≤ 18 / ×0.55 / 0), hud2 spawn counts agree
#   5 cleanup    — driver freed after the show, after a skip, when the showcase is freed mid-show, with no host clock,
#                  and hands off a foreign material; uniforms back to 0
#   6 law        — light caps in the shader (sheen α ≤ 0.35, colour ≤ 0.8, rim ≤ 0.7, α ≤ 0.85), ≤ 16 texture
#                  samples, no hex colour literals in the module's files

const LIVE_SH: = "res://shaders/v10/hudfx/showcase_live.gdshader"
const HUD2_SH: = "res://shaders/v10/hud2/showcase_sprite.gdshader"
const OWN_FILES: = ["res://scripts/v10/hudfx/showcase_fx.gd", "res://scripts/v10/hudfx/showcase_fx_selftest.gd",
		"res://scripts/v10/hudfx/demo/showcase_fx_demo.gd", "res://shaders/v10/hudfx/showcase_live.gdshader"]
const BOARD: = Rect2(16, 96, 688, 688)
const DT: = 1.0 / 120.0
const EPS: = 0.0001

static var _p: = 0
static var _f: = 0
static var _lines: Array = []


static func ok(cond: bool, msg: String) -> void:
	if cond:
		_p += 1
	else:
		_f += 1
		_lines.append(msg)


static func run(host: Node) -> Dictionary:
	_p = 0
	_f = 0
	_lines = []
	var old_fx: = V10Hud2Util.fx_override
	var old_dirs: = V10ShowcaseFx.mask_dirs.duplicate()
	var calm_before: = _calm_get(host)
	V10Hud2Util.fx_override = "full"
	_calm_set(host, false)
	_superset()
	await _mask_params(host)
	await _render_compare(host)
	_masks()
	await _timeline(host)
	await _particles(host)
	await _cleanup(host)
	_law()
	V10ShowcaseFx.mask_dirs = old_dirs
	V10ShowcaseFx.clear_cache()
	V10Hud2Util.fx_override = old_fx
	_calm_set(host, calm_before)
	return {"passed": _p, "failed": _f, "lines": _lines}


# ------------------------------------------------------------------ helpers

static func _calm_get(host: Node) -> bool:
	var g: = host.get_tree().root.get_node_or_null("G")
	if g == null or not (g.get("S") is Dictionary):
		return false
	return bool((g.get("S") as Dictionary).get("a11y_calm", false))


static func _calm_set(host: Node, on: bool) -> bool:
	var g: = host.get_tree().root.get_node_or_null("G")
	if g == null or not (g.get("S") is Dictionary):
		return false
	(g.get("S") as Dictionary)["a11y_calm"] = on
	return true


static func _showcase(host: Node, hero: = "mc") -> V10ComboShowcase:
	var sc: = V10ComboShowcase.new()
	sc.board_override = BOARD
	sc.hero = hero
	host.add_child(sc)
	sc.set_process(false)
	return sc


static func _hooked(sc: V10ComboShowcase, t: int, n: = 0) -> V10ShowcaseFx:
	# exactly the integrator's hook in V10ComboShowcase.trigger()
	var path: = sc.sprite_path(sc.hero, sc.outfit, t)
	sc._mat = V10ShowcaseFx.material_for(sc.hero, sc.outfit, t, path)
	sc._sprite.material = sc._mat
	sc.trigger(t, n)
	return V10ShowcaseFx.drive(sc, sc._sprite, t, sc.hero) as V10ShowcaseFx


static func _uniforms(code: String) -> Dictionary:
	# name -> "type|hint|default" (whitespace-normalised), parsed from the source (works headless)
	var out: = {}
	var re: = RegEx.create_from_string("(?m)^\\s*uniform\\s+(\\w+)\\s+(\\w+)\\s*(:[^=;]*)?(=\\s*([^;]+))?;")
	for m in re.search_all(code):
		var hint: = m.get_string(3).strip_edges().replace(" ", "")
		var def: = m.get_string(5).strip_edges().replace(" ", "")
		out[m.get_string(2)] = "%s|%s|%s" % [m.get_string(1), hint, def]
	return out


static func _strip(code: String) -> String:
	var out: = PackedStringArray()
	for l in code.split("\n"):
		var i: = l.find("//")
		var s: = (l.substr(0, i) if i >= 0 else l).strip_edges()
		if s != "":
			out.append(s)
	return "\n".join(out)


static func _block(code: String, from: String, to: String) -> String:
	var c: = _strip(code)
	var a: = c.find(from)
	if a < 0:
		return ""
	var b: = c.find(to, a)
	if b < 0:
		return ""
	return c.substr(a, b + to.length() - a)


static func _mat_val(m: ShaderMaterial, p: String) -> Variant:
	return m.get_shader_parameter(p)


# ------------------------------------------------------------------ 1 superset

static func _superset() -> void:
	var live_code: = FileAccess.get_file_as_string(LIVE_SH)
	var hud2_code: = FileAccess.get_file_as_string(HUD2_SH)
	ok(live_code != "" and hud2_code != "", "superset: shader sources unreadable")
	var lu: = _uniforms(live_code)
	var hu: = _uniforms(hud2_code)
	ok(hu.size() >= 9, "superset: parsed only %d hud2 uniforms" % hu.size())
	for n in hu:
		ok(lu.has(n), "superset: uniform %s missing in showcase_live" % n)
		if lu.has(n):
			ok(lu[n] == hu[n], "superset: uniform %s differs: %s vs hud2 %s" % [n, lu[n], hu[n]])
	# the board mask, the distance function and the world position: identical code
	var mask_from: = "float a = 1.0;"
	var mask_to: = "a = min(a, mix(center_alpha, 1.0, k));\n}"
	var lb: = _block(live_code, mask_from, mask_to)
	ok(lb != "" and lb == _block(hud2_code, mask_from, mask_to), "superset: board-mask code differs from hud2")
	var fn_from: = "float outside_dist(vec4 r, vec2 p) {"
	var fn_to: = "return max(d.x, d.y);\n}"
	var lf: = _block(live_code, fn_from, fn_to)
	ok(lf != "" and lf == _block(hud2_code, fn_from, fn_to), "superset: outside_dist differs from hud2")
	ok(_strip(live_code).contains("wpos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;"), "superset: wpos is not MODEL_MATRIX × VERTEX")
	ok(_strip(live_code).contains("COLOR = vec4(c.rgb, c.a * a);"), "superset: the mask does not multiply the final alpha")
	var sh: = V10HudFx.shader("showcase_live")
	ok(sh != null, "superset: V10HudFx.shader(showcase_live) is null")
	var m: = V10ShowcaseFx.material_for("mc", "base", 1, "")
	ok(V10ShowcaseFx.is_live(m), "superset: material_for did not return the live shader")
	ok(V10HudFx.shaders_list.has("showcase_live"), "superset: shader not registered for V10HudFx.warm()")


static func _live_mask(m: ShaderMaterial, p: Vector2) -> float:
	# GDScript twin of the shader's mask, fed from the MATERIAL's uniform values
	var a: = 1.0
	var br: Vector4 = m.get_shader_parameter("board_rect")
	var cr: Vector4 = m.get_shader_parameter("center_rect")
	var bf: Variant = m.get_shader_parameter("board_feather")
	var ff: Variant = m.get_shader_parameter("feather")
	var bfe: = 64.0 if bf == null else float(bf)
	var fe: = 24.0 if ff == null else float(ff)
	if br.z > 0.0:
		var db: = V10ComboShowcase._odist(Rect2(br.x, br.y, br.z, br.w), p)
		a = lerpf(float(m.get_shader_parameter("board_alpha")), 1.0, clampf(db / maxf(bfe, 0.001), 0.0, 1.0))
	if cr.z > 0.0:
		var dc: = V10ComboShowcase._odist(Rect2(cr.x, cr.y, cr.z, cr.w), p)
		a = minf(a, lerpf(float(m.get_shader_parameter("center_alpha")), 1.0, clampf(dc / maxf(fe, 0.001), 0.0, 1.0)))
	return a


static func _mask_params(host: Node) -> void:
	for t in [1, 2, 3]:
		var a: = _showcase(host)
		var b: = _showcase(host)
		a.trigger(t, 5)
		var drv: = _hooked(b, t, 5)
		var ma: = a._mat
		var mb: = b._mat
		ok(ma != mb and V10ShowcaseFx.is_live(mb) and not V10ShowcaseFx.is_live(ma), "mask T%d: hook did not swap the material" % t)
		for p in ["board_rect", "center_rect", "board_alpha", "center_alpha", "rim_color"]:
			ok(ma.get_shader_parameter(p) == mb.get_shader_parameter(p), "mask T%d: %s %s ≠ hud2 %s" % [t, p, mb.get_shader_parameter(p), ma.get_shader_parameter(p)])
		var worst: = 0.0
		var cz: = V10ComboShowcase.center_of(BOARD)
		for gx in 13:
			for gy in 13:
				var p: = BOARD.position + BOARD.size * Vector2(gx / 12.0, gy / 12.0) + Vector2(gx - 6, gy - 6) * 3.0
				var twin: = V10ComboShowcase.mask_alpha(p, BOARD, t)
				worst = maxf(worst, absf(_live_mask(mb, p) - twin))
				if t == 1 and cz.has_point(p):
					ok(_live_mask(mb, p) <= EPS, "mask T1: live alpha %.3f inside the centre zone at %s" % [_live_mask(mb, p), p])
		ok(worst <= EPS, "mask T%d: live material mask differs from V10ComboShowcase.mask_alpha by %.4f" % [t, worst])
		a.queue_free()
		b.queue_free()
		if is_instance_valid(drv):
			drv._end()
	await host.get_tree().process_frame


static func _render_compare(host: Node) -> void:
	# pixel check (needs a renderer; headless runs skip it): an opaque white sprite across the board through both
	# materials — the board/centre mask must give the same alpha everywhere
	if DisplayServer.get_name() == "headless":
		return
	var sv: = SubViewport.new()
	sv.size = Vector2i(720, 1280)
	sv.transparent_bg = true
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	host.add_child(sv)
	var img: = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var tex: = ImageTexture.create_from_image(img)
	var mats: = [ShaderMaterial.new(), V10ShowcaseFx.material_for("mc", "base", 1, "")]
	(mats[0] as ShaderMaterial).shader = load(HUD2_SH)
	var res: = []
	for m in mats:
		var sm: ShaderMaterial = m
		var cz: = V10ComboShowcase.center_of(BOARD)
		sm.set_shader_parameter("board_rect", Vector4(BOARD.position.x, BOARD.position.y, BOARD.size.x, BOARD.size.y))
		sm.set_shader_parameter("center_rect", Vector4(cz.position.x, cz.position.y, cz.size.x, cz.size.y))
		sm.set_shader_parameter("board_alpha", 0.45)
		sm.set_shader_parameter("center_alpha", 0.0)
		sm.set_shader_parameter("rim", 0.0)
		var tr: = TextureRect.new()
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		tr.position = Vector2(0, 0)
		tr.size = Vector2(720, 1000)
		tr.material = sm
		sv.add_child(tr)
		for k in 3:
			await RenderingServer.frame_post_draw
		res.append(sv.get_texture().get_image())
		tr.queue_free()
		await host.get_tree().process_frame
	var worst: = 0.0
	var cz2: = V10ComboShowcase.center_of(BOARD)
	var inside_max: = 0.0
	for y in range(0, 1000, 16):
		for x in range(0, 720, 16):
			var a0: float = (res[0] as Image).get_pixel(x, y).a
			var a1: float = (res[1] as Image).get_pixel(x, y).a
			worst = maxf(worst, absf(a0 - a1))
			if cz2.has_point(Vector2(x, y)):
				inside_max = maxf(inside_max, a1)
	ok(worst <= 2.0 / 255.0, "render: live mask alpha differs from hud2's by %.3f" % worst)
	ok(inside_max <= 2.0 / 255.0, "render: T1 live sprite has alpha %.3f inside the centre zone" % inside_max)
	sv.queue_free()
	await host.get_tree().process_frame


# ------------------------------------------------------------------ 2 masks

static func _masks() -> void:
	V10ShowcaseFx.mask_dirs = []
	V10ShowcaseFx.clear_cache()
	var m: = V10ShowcaseFx.material_for("zzz", "base", 2, "")
	ok(float(m.get_shader_parameter("hair_strength")) == 0.0 and float(m.get_shader_parameter("leg_strength")) == 0.0,
			"masks: missing masks did not give strength 0")
	ok(m.get_shader_parameter("hair_mask") == null and m.get_shader_parameter("leg_mask") == null, "masks: missing masks bound a texture")
	ok(V10ShowcaseFx.sprite_key("mc", "cafe", 2, "res://assets/v10/hud2/combo/mc_cafe_t2.png") == "mc_cafe_t2", "masks: outfit sprite borrows another key")
	ok(V10ShowcaseFx.sprite_key("mc", "base", 3, "") == "mc_t3", "masks: key without a sprite path")
	# real heroes: strength follows the files exactly
	for h in V10DS.HEROES:
		for t in [1, 2, 3]:
			var key: = "%s_t%d" % [h, t]
			var path: = "res://assets/v10/hud2/combo/%s.png" % key
			var mm: = V10ShowcaseFx.material_for(h, "base", t, path if ResourceLoader.exists(path) else "")
			for kind in ["hair", "leg"]:
				var has: = V10HudFx.tex("masks/%s_%s" % [key, kind]) != null
				ok(float(mm.get_shader_parameter(kind + "_strength")) == (1.0 if has else 0.0), "masks: %s %s strength does not follow the file" % [key, kind])
			var f: = V10ShowcaseFx.face_uv(key, Vector2(1360, 2048))
			var guard: = float(mm.get_shader_parameter("leg_guard"))
			var quiet: Vector2 = mm.get_shader_parameter("quiet_band")
			ok(guard >= f.end.y + f.size.y * 2.0 - EPS, "red line: %s sheen guard %.2f above face + 2 heads" % [key, guard])
			ok(quiet.x >= f.end.y - EPS and quiet.x <= f.end.y + f.size.y * 0.5 and quiet.y <= f.end.y + f.size.y * 2.0 and quiet.y > quiet.x,
					"red line: %s rim zones %s do not guard chest → feet" % [key, quiet])
	# present masks (written to user://, found through mask_dirs): strength 1, leg box from the mask
	var dir: = ProjectSettings.globalize_path("user://hudfx_selftest_masks")
	DirAccess.make_dir_recursive_absolute(dir)
	var hair: = Image.create(85, 128, false, Image.FORMAT_L8)
	hair.fill_rect(Rect2i(4, 8, 30, 80), Color.WHITE)
	hair.save_png(dir + "/selftest_t2_hair.png")
	var leg: = Image.create(85, 128, false, Image.FORMAT_L8)
	leg.fill_rect(Rect2i(30, 96, 30, 32), Color.WHITE)
	leg.save_png(dir + "/selftest_t2_leg.png")
	V10ShowcaseFx.mask_dirs = [dir]
	V10ShowcaseFx.clear_cache()
	var m2: = V10ShowcaseFx.material_for("selftest", "base", 2, "")
	ok(float(m2.get_shader_parameter("hair_strength")) == 1.0 and float(m2.get_shader_parameter("leg_strength")) == 1.0,
			"masks: present masks not picked up")
	ok(m2.get_shader_parameter("hair_mask") is Texture2D and m2.get_shader_parameter("leg_mask") is Texture2D, "masks: textures not bound")
	var box: Vector4 = m2.get_shader_parameter("leg_box")
	var want: = Vector4(30.0 / 85.0, 96.0 / 128.0, 30.0 / 85.0, 32.0 / 128.0)
	ok(absf(box.x - want.x) < 0.03 and absf(box.y - want.y) < 0.03 and absf(box.z - want.z) < 0.04 and absf(box.w - want.w) < 0.04,
			"masks: leg box %s, want ≈ %s" % [box, want])
	ok(V10ShowcaseFx.mask("selftest_t2", "hair") == V10ShowcaseFx.mask("selftest_t2", "hair"), "masks: not cached")
	ok(V10ShowcaseFx.mask("selftest_t9", "hair") == null, "masks: a missing key returned a texture")
	DirAccess.remove_absolute(dir + "/selftest_t2_hair.png")
	DirAccess.remove_absolute(dir + "/selftest_t2_leg.png")
	V10ShowcaseFx.mask_dirs = []
	V10ShowcaseFx.clear_cache()


# ------------------------------------------------------------------ 3 timeline

static func _run_show(host: Node, t: int, hero: = "mc", skip_at: = -1.0) -> Dictionary:
	var sc: = _showcase(host, hero)
	var drv: = _hooked(sc, t, 5 * t)
	var m: ShaderMaterial = sc._mat
	var rec: = []
	var clock: = 0.0
	var skipped: = false
	var guard: = 0
	if is_instance_valid(drv) and not drv.done:
		drv.sync()
	while sc.active and guard < 2000:
		guard += 1
		var ph_before: = sc.phase
		var hold_t: = sc.phase_t if ph_before == "hold" else -1.0
		if skip_at >= 0.0 and not skipped and ph_before == "hold" and sc.phase_t >= skip_at:
			sc.skip()
			skipped = true
		sc._advance(DT)
		clock += DT
		if is_instance_valid(drv) and not drv.done:
			drv.sync(DT)
		var alive: = is_instance_valid(drv) and not drv.done
		rec.append({"t": clock, "phase": sc.phase if sc.active else "", "hold_t": sc.phase_t if sc.phase == "hold" else -1.0,
				"sway": float(m.get_shader_parameter("sway")), "sheen": float(m.get_shader_parameter("sheen")),
				"sheen_p": float(m.get_shader_parameter("sheen_phase")), "rim": float(m.get_shader_parameter("rim")),
				"rim_p": float(m.get_shader_parameter("rim_phase")), "alive": alive, "was": hold_t})
	var out: = {"rec": rec, "drv": drv, "mat": m, "sc": sc, "runs": drv.sheen_runs if is_instance_valid(drv) else -1,
			"rim_base": float(m.get_shader_parameter("rim_base")), "sheen_a": float(m.get_shader_parameter("sheen_alpha"))}
	await host.get_tree().process_frame
	out["freed"] = not is_instance_valid(drv)
	sc.queue_free()
	return out


static func _span(rec: Array, key: String) -> Array:
	# [first t, last t, count of separate runs] where rec[key] > 0
	var first: = -1.0
	var last: = -1.0
	var runs: = 0
	var on: = false
	for r in rec:
		var v: float = r[key]
		if v > EPS:
			if not on:
				runs += 1
				on = true
			if first < 0.0:
				first = r.t
			last = r.t
		else:
			on = false
	return [first, last, runs]


static func _timeline(host: Node) -> void:
	for lv in ["full", "mid", "min"]:
		V10Hud2Util.fx_override = lv
		for t in [1, 2, 3]:
			var r: Dictionary = await _run_show(host, t)
			var rec: Array = r.rec
			var tag: = "timeline %s T%d" % [lv, t]
			ok(r.freed, "%s: driver not freed after the show" % tag)
			var last: Dictionary = rec[rec.size() - 1]
			ok(last.sway == 0.0 and last.sheen == 0.0 and last.rim == 0.0, "%s: uniforms not back to 0 at the end" % tag)
			var sway_max: = 0.0
			var bad_sway: = 0
			for x in rec:
				sway_max = maxf(sway_max, x.sway)
				if x.sway > EPS and x.phase != "hold" and x.phase != "out":
					bad_sway += 1
				if x.phase == "in" and x.sway > EPS:
					bad_sway += 1
			ok(bad_sway == 0, "%s: sway outside «держит» (%d steps)" % [tag, bad_sway])
			if lv == "min":
				ok(sway_max == 0.0, "%s: sway at fx=min" % tag)
				ok(_span(rec, "sheen")[2] == 0 and _span(rec, "rim")[2] == 0, "%s: light at fx=min" % tag)
				continue
			ok(sway_max > 0.95 and sway_max <= 1.0, "%s: sway envelope peak %.2f" % [tag, sway_max])
			# sway returns to rest by the end of the hold (no pop when she leaves)
			var end_hold: = 1.0
			for i in range(1, rec.size()):
				if rec[i - 1].phase == "hold" and rec[i].phase == "out":
					end_hold = rec[i - 1].sway
			ok(end_hold < 0.06, "%s: sway %.2f at the end of the hold" % [tag, end_hold])
			var sh: = _span(rec, "sheen")
			if t == 1:
				ok(sh[2] == 0, "%s: sheen on T1" % tag)
			else:
				ok(sh[2] == 1 and int(r.runs) == 1, "%s: sheen ran %d times (want once)" % [tag, sh[2]])
				var dur: float = sh[1] - sh[0] + DT
				ok(absf(dur - V10ShowcaseFx.SHEEN_T) <= 2.0 * DT, "%s: sheen lasted %.3f s (want 0.6)" % [tag, dur])
				var mono: = true
				var prev: = -1.0
				var start_ht: = -1.0
				for x in rec:
					if x.sheen > EPS:
						if start_ht < 0.0:
							start_ht = x.hold_t
						mono = mono and x.sheen_p >= prev
						prev = x.sheen_p
				ok(mono, "%s: sheen band did not travel one way" % tag)
				ok(absf(start_ht - float(V10ShowcaseFx.SHEEN_START[t])) <= 2.0 * DT, "%s: sheen started at hold %.3f" % [tag, start_ht])
				ok(prev >= 0.97, "%s: sheen band stopped at %.2f" % [tag, prev])
				ok(r.sheen_a <= 0.35 and r.sheen_a == (V10ShowcaseFx.SHEEN_A_MID if lv == "mid" else V10ShowcaseFx.SHEEN_A), "%s: sheen alpha %.2f" % [tag, r.sheen_a])
			var rm: = _span(rec, "rim")
			if t < 3:
				ok(rm[2] == 0, "%s: rim light below T3" % tag)
			else:
				ok(rm[2] == 1, "%s: rim ran %d times" % [tag, rm[2]])
				var rim_max: = 0.0
				var mono2: = true
				var prev2: = -1.0
				var last_ht: = 0.0
				for x in rec:
					if x.rim > EPS:
						rim_max = maxf(rim_max, x.rim)
						mono2 = mono2 and x.rim_p >= prev2
						prev2 = x.rim_p
						last_ht = x.hold_t
				ok(mono2, "%s: rim did not sweep top → bottom" % tag)
				ok(last_ht <= V10ShowcaseFx.RIM_T + EPS, "%s: rim still on at hold %.2f (> 0.6 s)" % [tag, last_ht])
				var cap: = V10ShowcaseFx.RIM_MID if lv == "mid" else 1.0
				ok(rim_max <= cap + EPS and rim_max > cap * 0.9, "%s: rim peak %.2f (cap %.2f)" % [tag, rim_max, cap])
				ok(r.rim_base == V10ShowcaseFx.RIM_BASE, "%s: rim_base %.2f" % [tag, r.rim_base])
	V10Hud2Util.fx_override = "full"
	# skip mid-hold: the live uniforms fade with her (≤ 120 ms, no pop), the driver leaves
	var s: Dictionary = await _run_show(host, 3, "mc", 0.3)
	var outs: = 0
	var jump: = 0.0
	var prev_sway: = -1.0
	for x in s.rec:
		if x.phase == "out":
			outs += 1
			if prev_sway >= 0.0:
				jump = maxf(jump, absf(x.sway - prev_sway))
		prev_sway = x.sway
	ok(outs > 0 and outs * DT <= V10ComboShowcase.SKIP_T + 2.0 * DT, "skip: out phase %.3f s" % (outs * DT))
	ok(jump <= 0.2, "skip: sway jumped %.2f in one step" % jump)
	var lx: Dictionary = s.rec[s.rec.size() - 1]
	ok(lx.sway == 0.0 and lx.rim == 0.0 and lx.sheen == 0.0, "skip: live uniforms still on after the skip")
	ok(s.freed, "skip: driver not freed")
	# calm («Без тряски и вспышек»): sway stays, no sheen, rim steady (no sweep)
	if _calm_set(host, true):
		ok(V10HudFx.calm(), "calm: G.S.a11y_calm did not switch V10HudFx.calm()")
		for t in [2, 3]:
			var c: Dictionary = await _run_show(host, t)
			ok(_span(c.rec, "sheen")[2] == 0, "calm T%d: sheen" % t)
			var smax: = 0.0
			var rvals: = {}
			for x in c.rec:
				smax = maxf(smax, x.sway)
				if x.rim > EPS:
					rvals[snappedf(x.rim, 0.001)] = true
			ok(smax > 0.95, "calm T%d: sway lost" % t)
			if t == 3:
				ok(rvals.size() == 1 and rvals.has(snappedf(V10ShowcaseFx.RIM_CALM, 0.001)), "calm T3: rim not steady: %s" % [rvals.keys()])
				ok(c.rim_base == 1.0, "calm T3: rim still sweeps (rim_base %.2f)" % c.rim_base)
		_calm_set(host, false)


# ------------------------------------------------------------------ 4 particles

class _Probe:
	extends Control
	var hero: = "mc"
	var drew: = -1

	func _draw() -> void:
		drew = 1 if V10ShowcaseFx.draw_particle(self, hero, {"s": 7.0, "p": Vector2.ZERO}, 1.0) else 0


static func _particles(host: Node) -> void:
	for h in V10DS.HEROES:
		var el: = V10HudFx.element(h)
		var want: = 0
		for i in 4:
			if V10HudFx.tex("particles/%s_%d" % [el, i]) != null:
				want += 1
		var arr: = V10ShowcaseFx.particles(h)
		ok(arr.size() == want, "particles %s: %d painted textures, files say %d" % [h, arr.size(), want])
		ok(V10ShowcaseFx.particles(h) == arr, "particles %s: not cached" % h)
	var counts: = {"full": 18, "mid": 10, "min": 0}
	for lv in counts:
		V10Hud2Util.fx_override = lv
		ok(V10ShowcaseFx.particle_count(18) == counts[lv], "particles %s: count(18) = %d" % [lv, V10ShowcaseFx.particle_count(18)])
		ok(V10ShowcaseFx.particle_count(40) <= 18, "particles %s: count above 18" % lv)
		var sc: = _showcase(host)
		var drv: = _hooked(sc, 3, 20)
		var n: int = sc._parts.size()
		ok(n <= V10ShowcaseFx.particle_count(18) and (n > 0) == (lv != "min"), "particles %s: hud2 spawned %d for T3" % [lv, n])
		var pr: = _Probe.new()
		pr.size = Vector2(8, 8)
		host.add_child(pr)
		pr.queue_redraw()
		await host.get_tree().process_frame
		await host.get_tree().process_frame
		var expect: = 1 if lv != "min" and not V10ShowcaseFx.particles("mc").is_empty() else 0
		ok(pr.drew == expect, "particles %s: draw_particle returned %d (want %d)" % [lv, pr.drew, expect])
		pr.queue_free()
		sc.queue_free()
		if is_instance_valid(drv):
			drv._end()
	V10Hud2Util.fx_override = "full"
	await host.get_tree().process_frame


# ------------------------------------------------------------------ 5 cleanup

static func _cleanup(host: Node) -> void:
	# the showcase is freed mid-show: the driver goes with it, no error
	var sc: = _showcase(host)
	var drv: = _hooked(sc, 3, 20)
	for i in 50:
		sc._advance(DT)
		drv.sync(DT)
	ok(drv.sway_k > 0.0, "cleanup: driver idle mid-hold")
	sc.queue_free()
	await host.get_tree().process_frame
	ok(not is_instance_valid(drv), "cleanup: driver outlived its showcase")
	# a re-trigger replaces the old driver (never two writers)
	var sc2: = _showcase(host)
	var d1: = _hooked(sc2, 2, 10)
	var d2: = _hooked(sc2, 3, 20)
	ok(d1.done and not d2.done, "cleanup: re-trigger kept two drivers")
	sc2.queue_free()
	await host.get_tree().process_frame
	ok(not is_instance_valid(d1) and not is_instance_valid(d2), "cleanup: drivers not freed with the showcase")
	# no host clock (a plain sprite): own timeline from TIERS, frees itself after in + hold + out
	var tr: = TextureRect.new()
	tr.texture = load("res://assets/v10/hud2/combo/mc_t2.png")
	tr.material = V10ShowcaseFx.material_for("mc", "base", 2, "res://assets/v10/hud2/combo/mc_t2.png")
	host.add_child(tr)
	var own: = V10ShowcaseFx.drive(null, tr, 2, "mc") as V10ShowcaseFx
	tr.set_process(false)
	own.set_process(false)
	var peak: = 0.0
	var steps: = 0
	while not own.done and steps < 1000:
		own.sync(DT)
		peak = maxf(peak, own.sway_k)
		steps += 1
	var total: = 0.28 + 0.70 + 0.22
	ok(absf(steps * DT - total) <= 2.0 * DT, "cleanup: own-clock show lasted %.2f s (want %.2f)" % [steps * DT, total])
	ok(peak > 0.95, "cleanup: own-clock show had no sway")
	await host.get_tree().process_frame
	ok(not is_instance_valid(own), "cleanup: own-clock driver not freed")
	# sprite freed first: the driver notices and leaves
	var own2: = V10ShowcaseFx.drive(null, tr, 2, "mc") as V10ShowcaseFx
	tr.queue_free()
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	ok(not is_instance_valid(own2), "cleanup: driver outlived its sprite")
	# a foreign material (hud2's) is never touched
	var sc3: = _showcase(host)
	sc3.trigger(3, 20)
	var d3: = V10ShowcaseFx.drive(sc3, sc3._sprite, 3, "mc") as V10ShowcaseFx
	ok(d3.done and d3.mat == null, "cleanup: driver took a foreign material")
	sc3.queue_free()
	# null everything: no crash, a freed no-op
	var d4: = V10ShowcaseFx.drive(null, null, 2, "mc") as V10ShowcaseFx
	ok(d4 != null and d4.done, "cleanup: null drive() not a no-op")
	await host.get_tree().process_frame
	ok(not is_instance_valid(d4), "cleanup: null drive() leaked a node")


# ------------------------------------------------------------------ 6 law

static func _law() -> void:
	var code: = _strip(FileAccess.get_file_as_string(LIVE_SH))
	ok(code.count("texture(") <= 16, "law: %d texture samples (≤ 16)" % code.count("texture("))
	ok(code.contains("min(sheen_alpha, 0.35)"), "law: sheen alpha not capped at 0.35")
	ok(code.contains("cap_value(sheen_color.rgb, 0.8)"), "law: sheen colour value not capped at 0.8")
	ok(code.contains("cap_value(rim_color.rgb, 0.8)"), "law: rim colour value not capped at 0.8")
	ok(code.contains("float allow = max(max(hmi, lmi), zone);") and code.contains("mix(back, 0.0, below_waist)"), "law: rim zones (chest/crotch/thigh guard) missing")
	ok(code.contains("min(edge * lvl, 0.85)"), "law: rim light alpha not capped at 0.85")
	ok(code.contains("min(sway_px, 6.0)"), "law: sway not capped at 6 px")
	ok(code.contains("* lm * guard *"), "law: sheen not multiplied by the leg mask and the knee guard")
	ok(not code.contains("TIME"), "law: shader animates on its own (TIME) — must be driven, still at rest")
	ok(V10ShowcaseFx.SHEEN_A <= 0.35 and V10ShowcaseFx.SWAY_PX <= 6.0 and V10ShowcaseFx.SHEEN_T == 0.6 and V10ShowcaseFx.RIM_T == 0.6,
			"law: module constants out of spec")
	var m: = V10ShowcaseFx.material_for("hana", "base", 3, "")
	var sc: Color = m.get_shader_parameter("sheen_color")
	ok(sc.v <= V10HudFx.LIGHT_VALUE_MAX + 0.01, "law: sheen colour value %.2f" % sc.v)
	var hexre: = RegEx.create_from_string("Color\\(\\s*\"#|Color\\(\\s*0\\.")
	for p in OWN_FILES:
		if not FileAccess.file_exists(p):
			continue
		var src: = FileAccess.get_file_as_string(p)
		var hits: = 0
		for line in src.split("\n"):
			if line.strip_edges().begins_with("#") or line.contains("hexre"):
				continue
			if hexre.search(line) != null:
				hits += 1
		ok(hits == 0, "law: %d hex/raw colour literals in %s" % [hits, p.get_file()])
