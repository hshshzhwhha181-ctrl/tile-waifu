extends Control

# V10ShowcaseFx demo (scripts/v10/hudfx/demo/showcase_fx_demo.tscn) — the live combo showcase IN CONTEXT: a real
# V10HudMatch (board, tray, help row, her scene) with the real V10ComboShowcase on top; the showcase sprite gets
# V10ShowcaseFx.material_for() and V10ShowcaseFx.drive() exactly as the integrator's hook in combo_showcase.gd
# trigger() will do it, and hud2's particle layer draws the painted element sprites through the _Fx hook (replayed
# here by _HookedFx, a copy of hud2's _Fx._draw with the hook lines applied — combo_showcase.gd is not edited).
# User args (after --):
#   --shots=<abs dir>    T1 / T2 / T3 at mid-hold for mc and nova (+ every heroine with masks), a sheen-mid and a
#                        T3 rim-mid frame; PNG per moment, then quit (the show is stepped 1/60 s per frame)
#   --fx=full|mid|min    V10Hud2Util.fx_override
#   --heroes=mc,nova     heroines to shoot / loop
#   --masks=<abs dir>    extra mask dir (preview masks before assets/v10/hudfx/masks lands)
#   --calm=1             «Без тряски и вспышек» (G.S.a11y_calm)
#   --base=1             hud2's own material, no driver (A/B against the same moments)
#   --diff=1             also save each moment without sway / rim / sheen (<shot>_no<fx>.png) to diff each effect
#   --selftest=1         run V10HudFxShowcaseFxTest, print "HUDFX SHOWCASE_FX SELFTEST passed/total", quit(failures)
#   (none)               loop T1 → T2 → T3 in real time for the heroines

const TILE_DIR: = "res://assets/v08/table/"
const N_FOR: = {1: 5, 2: 10, 3: 20}
# [tier, hold time (s from the start of «держит»), label]
const PLAN: = [[1, 0.25, "hold"], [2, 0.36, "sheen"], [3, 0.24, "rim"], [3, 0.54, "sheen"]]
const STEP: = 1.0 / 60.0

var args: = {}
var hud: V10HudMatch
var sc: V10ComboShowcase
var drv: Node
var hfx: Control
var heroes: = ["mc", "nova"]
var base_only: = false
var _loop_i: = 0
var _loop_t: = 0.0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv: = a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if args.has("fx"):
		V10Hud2Util.fx_override = str(args.fx)
	if args.has("masks"):
		V10ShowcaseFx.mask_dirs = [str(args.masks)]
	if args.has("calm"):
		var g: = get_tree().root.get_node_or_null("G")
		if g and g.get("S") is Dictionary:
			(g.get("S") as Dictionary)["a11y_calm"] = str(args.calm) == "1"
	base_only = str(args.get("base", "0")) == "1"
	if args.has("selftest"):
		var r: Dictionary = await V10HudFxShowcaseFxTest.run(self)
		for l in r.lines:
			print("FAIL  ", l)
		print("HUDFX SHOWCASE_FX SELFTEST %d/%d" % [r.passed, r.passed + r.failed])
		get_tree().quit(int(r.failed))
		return
	if args.has("heroes"):
		heroes = Array(str(args.heroes).split(",", false))
	elif args.has("shots"):
		for h in V10DS.HEROES:
			if not heroes.has(h) and _has_masks(h):
				heroes.append(h)
	if args.has("shots"):
		await _shots(str(args.shots))
		get_tree().quit(0)
		return
	_build(heroes[0])


static func _has_masks(h: String) -> bool:
	for t in [1, 2, 3]:
		for kind in ["hair", "leg"]:
			if V10ShowcaseFx.mask("%s_t%d" % [h, t], kind) != null:
				return true
	return false


# ------------------------------------------------------------------ context: the match

func _build(h: String) -> void:
	for n in [hud, sc]:
		if is_instance_valid(n):
			n.free()
	hud = V10HudMatch.new()
	add_child(hud)
	hud.configure({"hero": h, "level": "1-2", "total": 30, "left": 28,
			"helpers": {"undo": 2, "hint": 3, "shuffle": 1}, "stake_offer": false})
	hud.set_ult(0.6)
	_board()
	sc = V10ComboShowcase.new()
	add_child(sc)
	sc.hud = hud
	sc.hero = h
	sc.min_gap = 0.0
	sc.max_per_match = 99
	hfx = null
	if not base_only and not V10ShowcaseFx.particles(h).is_empty():
		var f: = _HookedFx.new()
		f.sc = sc
		f.set_anchors_preset(Control.PRESET_FULL_RECT)
		sc.add_child(f)
		sc.move_child(f, sc._fx.get_index() + 1)
		sc._fx.visible = false
		hfx = f


func _board() -> void:
	# a stand-in board (as hud2_demo): 3 layers, top layer on, two tiles already in the tray
	var layers: = [[7, 5, Vector2(0, 0)], [5, 3, Vector2(76, 46)], [3, 1, Vector2(152, 138)]]
	var tw: = 76.0
	var th: = 106.0
	var step_y: = 92.0
	var x0: = (688.0 - 7 * tw) * 0.5
	var y0: = (688.0 - (4 * step_y + th)) * 0.5
	var k: = 0
	for li in layers.size():
		var cols: int = layers[li][0]
		var rows: int = layers[li][1]
		var off: Vector2 = layers[li][2]
		for r in rows:
			for c in cols:
				var tr: = TextureRect.new()
				tr.texture = load(TILE_DIR + "t%02d.png" % ((k * 7 + li * 3) % 34))
				tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				tr.stretch_mode = TextureRect.STRETCH_SCALE
				tr.size = Vector2(tw, th)
				tr.position = Vector2(x0 + off.x + c * tw - li * 4.0, y0 + off.y + r * step_y - li * 7.0)
				tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
				tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
				hud.board_layer.add_child(tr)
				k += 1
	for i in 2:
		var cell: = hud.tray_cell_rect(i)
		var t2: = TextureRect.new()
		t2.texture = load(TILE_DIR + "t%02d.png" % 9)
		t2.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t2.stretch_mode = TextureRect.STRETCH_SCALE
		t2.position = cell.position
		t2.size = cell.size
		t2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(t2)
	hud.set_tray_fill(2)


# ------------------------------------------------------------------ the hook (what combo_showcase.gd trigger() gets)

func _fire(t: int) -> void:
	if base_only:
		sc.trigger(t, N_FOR[t])
		drv = null
		return
	var path: = sc.sprite_path(sc.hero, sc.outfit, t)
	sc._mat = V10ShowcaseFx.material_for(sc.hero, sc.outfit, t, path)  # hook 1 (before the board uniforms)
	sc._sprite.material = sc._mat
	sc.trigger(t, N_FOR[t])
	drv = V10ShowcaseFx.drive(sc, sc._sprite, t, sc.hero)  # hook 2 (end of trigger)


# ------------------------------------------------------------------ shots

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shots(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var fx: = V10HudFx.level() + ("_calm" if V10HudFx.calm() else "") + ("_base" if base_only else "")
	for h in heroes:
		_build(h)
		await _frames(40)  # HUD entry settles
		sc.set_process(false)
		for p in PLAN:
			var t: int = p[0]
			var target: float = p[1]
			var label: String = p[2]
			_fire(t)
			var shot: = false
			var guard: = 0
			while sc.active and guard < 600:
				guard += 1
				var dt: = STEP
				if not shot and sc.phase == "hold" and sc.phase_t + dt >= target:
					dt = maxf(0.0, target - sc.phase_t)
				sc._advance(dt)
				await get_tree().process_frame
				if not shot and sc.phase == "hold" and absf(sc.phase_t - target) < 0.0005:
					await _frames(2)
					await RenderingServer.frame_post_draw
					var path: = "%s/%s_t%d_%s_%s.png" % [dir, h, t, label, fx]
					get_viewport().get_texture().get_image().save_png(path)
					var d: = drv as V10ShowcaseFx
					print("shot %s  hold %.2f  sway %.2f  sheen %.2f@%.2f  rim %.2f@%.2f" % [path.get_file(), sc.phase_t,
							d.sway_k if d else 0.0, d.sheen_k if d else 0.0, d.sheen_p if d else 0.0,
							d.rim_k if d else 0.0, d.rim_p if d else 0.0])
					shot = true
					if args.has("diff") and d and d.mat:  # debug: the same frame without each effect (diff it outside)
						d.set_process(false)
						for fxp in ["sway", "rim", "sheen"]:
							var keep: Variant = d.mat.get_shader_parameter(fxp)
							d.mat.set_shader_parameter(fxp, 0.0)
							await _frames(1)
							await RenderingServer.frame_post_draw
							get_viewport().get_texture().get_image().save_png(path.get_basename() + "_no" + fxp + ".png")
							d.mat.set_shader_parameter(fxp, keep)
						d.set_process(true)
			await _frames(12)
		print("driver freed after the shows: %s" % (not is_instance_valid(drv)))


# ------------------------------------------------------------------ loop (no args)

func _process(delta: float) -> void:
	if args.has("shots") or args.has("selftest") or not is_instance_valid(sc):
		return
	_loop_t += delta
	if not sc.active and _loop_t > 1.2:
		_loop_t = 0.0
		var t: = _loop_i % 3 + 1
		if t == 1 and _loop_i > 0:
			_build(heroes[(_loop_i / 3) % heroes.size()])
		_fire(t)
		_loop_i += 1


# ------------------------------------------------------------------ hud2 _Fx with the hudfx particle hook applied

class _HookedFx:
	extends Control
	var sc: V10ComboShowcase
	var _was: = false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_d: float) -> void:
		var on: = sc != null and sc.active
		if on or _was:
			queue_redraw()
		_was = on

	func _draw() -> void:
		if sc == null or not sc.active or sc._fxl == "min":
			return
		var hc: Dictionary = V10DS.hero(sc.hero)
		var acc: Color = hc.accent
		var r: Rect2 = sc._place.rect
		var vs: = size
		var a: float = sc._fx.get("alpha")
		var halo: = Color(acc.r * 0.7, acc.g * 0.7, acc.b * 0.7, 0.30 * a)
		var fr: Rect2 = sc._place.face
		var hc_pos: = fr.position + fr.size * 0.5 + Vector2(0, fr.size.y * 1.4)
		var hr: = r.size.x * (0.65 if sc.tier == 3 else 0.5)
		draw_texture_rect(sc._glow_tex, Rect2(hc_pos - Vector2(hr, hr), Vector2(hr, hr) * 2.0), false, halo)
		if sc.tier >= 2:
			var c0: = Color(acc, 0.0)
			var c1: = Color(acc.r * 0.7, acc.g * 0.7, acc.b * 0.7, 0.22 * a)
			var x0: = vs.x + 40.0
			var sk: = vs.y * 0.55
			var wband: = 150.0 if sc.tier == 3 else 110.0
			var p: = PackedVector2Array([Vector2(x0 - wband, -20), Vector2(x0, -20), Vector2(x0 - sk, vs.y + 20), Vector2(x0 - sk - wband, vs.y + 20)])
			var mid0: = (p[0] + p[1]) * 0.5
			var mid1: = (p[2] + p[3]) * 0.5
			draw_polygon(PackedVector2Array([p[0], mid0, mid1, p[3]]), PackedColorArray([c0, c1, c1, c0]))
			draw_polygon(PackedVector2Array([mid0, p[1], p[2], mid1]), PackedColorArray([c1, c0, c0, c1]))
		var fxs: = V10Hud2Util.opt_class("V10ShowcaseFx")  # hudfx hook (line 1 of 3)
		for pt in sc._parts:
			if sc.elapsed < float(pt.d):
				continue
			draw_set_transform(pt.p, float(pt.rot), Vector2.ONE)
			if fxs and fxs.call("draw_particle", self, sc.hero, pt, a):  # hudfx hook (lines 2-3 of 3)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				continue
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
