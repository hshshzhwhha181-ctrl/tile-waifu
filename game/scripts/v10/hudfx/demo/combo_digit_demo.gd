extends Control

# V10ComboDigit demo (scripts/v10/hudfx/demo/combo_digit_demo.tscn): the lacquered gold «×N» IN CONTEXT — the
# real match HUD (V10HudMatch, hero "mc": felt, board, tray with two tiles, help row, her scene) and, for the
# showcase tiers, the real V10ComboShowcase with its own number handed over to the digit (the integration hook).
# Runs ×2 (T0), ×5 (T1), ×10 (T2), ×20 (T3). User args (after --):
#   --shots=<abs dir>   deterministic: digit + showcase stepped in lockstep, PNGs at the hold peak (0.14 s) and
#                       mid-sheen (0.30 s) of each number (+ ×2 scale-in 0.05 s, T3 late hold 0.44 s), then quit
#   --fx=full|mid|min   V10Hud2Util.fx_override
#   --selftest=1        V10HudFxComboDigitTest → "HUDFX COMBO_DIGIT SELFTEST passed/total", exit code = failures
#   --quit=<s>          quit after s seconds (live loop)

const TILE_DIR: = "res://assets/v08/table/"
const PLAN: = [[2, 0], [5, 1], [10, 2], [20, 3]]
const F: = 1.0 / 60.0

var args: = {}
var hud: V10HudMatch
var sc: V10ComboShowcase
var digit: V10ComboDigit
var _t: = 0.0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv: = a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if args.has("fx"):
		V10Hud2Util.fx_override = str(args.fx)
	if args.has("selftest"):
		var r: Dictionary = await V10HudFxComboDigitTest.run(self)
		for l in r.lines:
			print(l)
		print("HUDFX COMBO_DIGIT SELFTEST %d/%d" % [r.passed, r.passed + r.failed])
		get_tree().quit(int(r.failed))
		return
	_build()
	if args.has("shots"):
		await _shoot(str(args.shots))
		await get_tree().create_timer(2.0).timeout  # let the showcase's last sound end (no leak at exit)
		get_tree().quit(0)
	else:
		_live()


func _build() -> void:
	hud = V10HudMatch.new()
	add_child(hud)
	hud.configure({"hero": "mc", "level": "1-2", "total": 30, "left": 18,
			"helpers": {"undo": 2, "hint": 3, "shuffle": 1}, "stake_offer": false})
	hud.set_ult(0.6)
	_build_board()
	sc = V10ComboShowcase.new()
	add_child(sc)
	sc.hud = hud
	sc.hero = "mc"
	digit = V10ComboDigit.for_hud(hud)


func _build_board() -> void:
	# the hud2 demo's pyramid stand-in for the game's board, minus the pairs already played; two tiles in the tray
	var layers: = [[7, 5, Vector2(0, 0)], [5, 3, Vector2(76, 46)], [3, 1, Vector2(152, 138)]]
	var tw: = 76.0
	var th: = 106.0
	var step_y: = 92.0
	var x0: = (688.0 - 7 * tw) * 0.5
	var y0: = (688.0 - (4 * step_y + th)) * 0.5
	var rng: = RandomNumberGenerator.new()
	rng.seed = 11
	for li in layers.size():
		var cols: int = layers[li][0]
		var rows: int = layers[li][1]
		var off: Vector2 = layers[li][2]
		for r in rows:
			for c in cols:
				if li == 2:
					continue  # the top row is already played
				var tr: = _tile(rng.randi_range(0, 33))
				tr.position = Vector2(x0 + off.x + c * tw - li * 4.0, y0 + off.y + r * step_y - li * 7.0)
				tr.size = Vector2(tw, th)
				hud.board_layer.add_child(tr)
	for i in 2:
		var cell: = hud.tray_cell_rect(i)
		var t2: = _tile([7, 22][i])
		t2.position = cell.position
		t2.size = cell.size
		add_child(t2)
		move_child(t2, hud.get_index() + 1)
	hud.set_tray_fill(2)


func _tile(face: int) -> TextureRect:
	var tr: = TextureRect.new()
	tr.texture = load(TILE_DIR + "t%02d.png" % face)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return tr


func _start(n: int, tier: int) -> void:
	# what play.gd does after the hooks: the showcase fires with its tier and hands the number to the digit;
	# a plain combo goes through hud.show_combo (→ the digit, tier 0)
	if tier >= 1:
		sc.trigger(tier, n)
		sc._num.visible = false  # = the combo_showcase.gd hook (its own number steps aside)
	hud.combo_l.visible = false  # = the hud_match.gd hook
	digit.show_combo(n, tier, "mc")


# ------------------------------------------------------------------ deterministic shots

func _shoot(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var fx: = V10HudFx.level()
	await _frames(20)  # first draw, rig settles
	await _snap(dir, "%s_idle" % fx)
	digit.manual = true
	sc.set_process(false)
	for step in PLAN:
		var n: int = step[0]
		var tier: int = step[1]
		_start(n, tier)
		await _frames(24)  # her scene figure steps back (hud tween, real time) while digit + showcase wait at 0
		var marks: = [[0.14, "peak"], [0.30, "sheen"]]
		if tier == 0:
			marks.push_front([0.05, "in"])
		if tier == 3:
			marks.append([0.44, "late"])
		var t: = 0.0
		for m in marks:
			while t < float(m[0]) - 0.001:
				_step(F)
				t += F
			await _snap(dir, "%s_x%d_t%d_%s" % [fx, n, tier, m[1]])
		while digit.visible or sc.active:
			_step(F)
			t += F
			if t > 3.0:
				break
		await _frames(18)  # her scene figure returns
	await _snap(dir, "%s_after" % fx)


func _step(dt: float) -> void:
	digit.advance(dt)
	if sc.active:
		sc._advance(dt)


func _frames(k: int) -> void:
	for i in k:
		await get_tree().process_frame


func _snap(dir: String, name: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: = get_viewport().get_texture().get_image()
	var path: = "%s/%s.png" % [dir, name]
	img.save_png(path)
	print("shot ", path)


# ------------------------------------------------------------------ live loop

func _live() -> void:
	var i: = 0
	while is_inside_tree():
		var step: Array = PLAN[i % PLAN.size()]
		_start(int(step[0]), int(step[1]))
		var wait: = 2.2 if int(step[1]) >= 1 else 1.2
		await get_tree().create_timer(wait).timeout
		i += 1


func _process(delta: float) -> void:
	_t += delta
	if args.has("quit") and _t >= float(args.quit):
		get_tree().quit(0)
