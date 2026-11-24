extends Control

# HUD v2 demo (scripts/v10/hud2/hud2_demo.tscn): the match HUD with a scripted run that reaches ×5, ×10, ×20
# and fires the combo showcase at each, plus the home and victory layouts. User args (after --):
#   --view=match|home|victory|all   default match (all = idle, T1, T2, T3, home, victory one after another)
#   --hero=mc|rin|hana|yue|nova     showcase heroine (the scene rig exists only for mc; others use their card)
#   --gap=3                         showcase min gap for the scripted run (the game uses 20 s)
#   --insets=48,24                  simulate top/bottom safe insets (else: 48/24 when H/W ≥ 2, 24/16 on tablets)
#   --fx=full|mid|min               --shots=<abs dir> --at=1.0,2.5 (seconds; view=all has its own plan)
#   --quit=<s>                      quit after s seconds
#   --hud2_selftest=1               run V10Hud2Selftest and quit with the failure count
# Record:  xvfb-run -a godot --path game res://scripts/v10/hud2/hud2_demo.tscn --resolution 720x1280 \
#            --write-movie /abs/out.avi --fixed-fps 30 --quit-after 600 -- --view=match

const TILE_DIR: = "res://assets/v08/table/"

var args: = {}
var t: = 0.0
var game_t: = 0.0
var view: = ""
var hud: V10HudMatch
var sc: V10ComboShowcase
var home: V10HudHome
var vic: V10HudVictory
var tiles: = []  # board tiles in pick order
var tray_tiles: = []
var paused: = false
var combo: = 0
var left_pairs: = 30
var _actions: = []
var _shots: = []
var _shot_dir: = ""
var _log: = []


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv: = a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var vs: = get_viewport_rect().size
	if args.has("insets"):
		var p: PackedStringArray = str(args.insets).split(",")
		V10Hud2Util.sim_insets = {"top": float(p[0]), "bottom": float(p[1])}
	elif vs.y / vs.x >= 2.0:
		V10Hud2Util.sim_insets = {"top": 48.0, "bottom": 24.0}
	elif vs.x > 760.0:
		V10Hud2Util.sim_insets = {"top": 24.0, "bottom": 16.0}
	if args.has("fx"):
		V10Hud2Util.fx_override = str(args.fx)
	if args.has("hud2_selftest"):
		var fails: int = await V10Hud2Selftest.run(self)
		get_tree().quit(fails)
		return
	_shot_dir = str(args.get("shots", ""))
	var v: = str(args.get("view", "match"))
	if v == "all":
		_plan_all()
	else:
		_show(v)
		if v == "match":
			_script_match()
		for s in str(args.get("at", "")).split(",", false):
			_shots.append({"t": float(s), "name": "%s_%.1f" % [v, float(s)]})


func _show(v: String) -> void:
	for n in [hud, sc, home, vic]:
		if is_instance_valid(n):
			n.queue_free()
	hud = null
	sc = null
	home = null
	vic = null
	tiles.clear()
	tray_tiles.clear()
	view = v
	match v:
		"match":
			hud = V10HudMatch.new()
			add_child(hud)
			hud.configure({"hero": "mc", "level": "1-2", "total": 30, "left": 30,
					"helpers": {"undo": 2, "hint": 3, "shuffle": 1}, "stake_offer": true})
			hud.set_ult(0.35)
			_build_board()
			sc = V10ComboShowcase.new()
			add_child(sc)
			sc.hud = hud
			sc.hero = str(args.get("hero", "mc"))
			sc.min_gap = float(args.get("gap", "3"))
			sc.input_paused.connect(func(on: bool) -> void:
				paused = on
				_log.append("%.2f input_paused %s" % [t, on]))
			sc.started.connect(func(k: int) -> void: _log.append("%.2f showcase T%d" % [t, k]))
			sc.finished.connect(func(k: int, sk: bool) -> void: _log.append("%.2f showcase T%d done skipped=%s" % [t, k, sk]))
		"home":
			home = V10HudHome.new()
			home.configure({"hero": "mc", "nick": "Гость", "level": "1-4", "path": "Чайный сад", "affinity": 6})
			add_child(home)
		"victory":
			vic = V10HudVictory.new()
			vic.configure({"hero": "mc", "level": "1-4 · Чайный сад", "stars": 3, "next": 5})
			add_child(vic)


# ------------------------------------------------------------------ board (demo stand-in for the game's board)

func _build_board() -> void:
	var layers: = [[7, 5, Vector2(0, 0)], [5, 3, Vector2(76, 46)], [3, 1, Vector2(152, 138)]]
	var tw: = 76.0
	var th: = 106.0
	var step_y: = 92.0
	var x0: = (688.0 - 7 * tw) * 0.5
	var y0: = (688.0 - (4 * step_y + th)) * 0.5
	var all: = []
	for li in layers.size():
		var cols: int = layers[li][0]
		var rows: int = layers[li][1]
		var off: Vector2 = layers[li][2]
		for r in rows:
			for c in cols:
				var p: = Vector2(x0 + off.x + c * tw - li * 4.0, y0 + off.y + r * step_y - li * 7.0)
				all.append({"pos": p, "layer": li, "r": r, "c": c})
	# pick order: top layer first, rows top-down — that is the scripted play order
	all.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.layer != b.layer:
			return a.layer > b.layer
		if a.r != b.r:
			return a.r < b.r
		return a.c < b.c)
	var rng: = RandomNumberGenerator.new()
	rng.seed = 7
	for i in all.size():
		var face: = (i / 2) % 34 if i < 44 else rng.randi_range(0, 33)
		all[i]["face"] = face
	# draw bottom layer first
	var draw_order: = all.duplicate()
	draw_order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.layer != b.layer:
			return a.layer < b.layer
		if a.r != b.r:
			return a.r < b.r
		return a.c < b.c)
	var nodes: = {}
	for d in draw_order:
		var tr: = TextureRect.new()
		tr.texture = load(TILE_DIR + "t%02d.png" % int(d.face))
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		tr.size = Vector2(tw, th)
		tr.position = d.pos
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		hud.board_layer.add_child(tr)
		nodes[d] = tr
	for d in all:
		tiles.append(nodes[d])


# ------------------------------------------------------------------ scripted match

func _script_match() -> void:
	# game time (frozen while the showcase pauses input), seconds
	_at(0.2, func() -> void: hud.start_banner("1-2 · Чайный сад"))
	var tt: = 1.3
	for k in 20:
		var i: = k
		_at(tt, func() -> void: _pick(2 * i))
		_at(tt + 0.22, func() -> void: _pick(2 * i + 1))
		_at(tt + 0.46, func() -> void: _clear_pair(i))
		tt += 0.56
	_at(tt + 0.6, func() -> void:
		hud.set_ult(1.0)
		hud.say("Приём готов~"))
	_at(tt + 2.4, func() -> void: _pick(40))
	_at(tt + 2.7, func() -> void: _pick(41))


func _at(time: float, f: Callable) -> void:
	_actions.append({"t": time, "f": f})


func _pick(i: int) -> void:
	if i >= tiles.size():
		return
	if i == 0:
		hud.first_move()
	var tr: TextureRect = tiles[i]
	var slot: = tray_tiles.size()
	var dst: = hud.tray_cell_rect(slot)
	var gp: = tr.get_global_position()
	tr.reparent(self)
	tr.global_position = gp
	tray_tiles.append(tr)
	hud.set_tray_fill(tray_tiles.size())
	var tw: = create_tween().set_parallel(true)
	tw.tween_property(tr, "global_position", dst.position, 0.18).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tw.tween_property(tr, "size", dst.size, 0.18).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)


func _clear_pair(_k: int) -> void:
	var gone: = tray_tiles.slice(tray_tiles.size() - 2)
	tray_tiles = tray_tiles.slice(0, tray_tiles.size() - 2)
	for g in gone:
		var tr: TextureRect = g
		tr.pivot_offset = tr.size * 0.5
		var tw: = create_tween().set_parallel(true)
		tw.tween_property(tr, "scale", Vector2.ONE * 1.12, 0.12)
		tw.tween_property(tr, "modulate:a", 0.0, 0.14).set_delay(0.04)
		tw.chain().tween_callback(tr.queue_free)
	hud.set_tray_fill(tray_tiles.size())
	combo += 1
	left_pairs -= 1
	hud.set_left(left_pairs)
	var shown: = sc.on_combo(combo)
	if shown == 0:
		hud.show_combo(combo)
	hud.set_ult(minf(0.95, 0.35 + combo * 0.03))


# ------------------------------------------------------------------ view=all plan

func _plan_all() -> void:
	_show("match")
	hud.set_ult(0.6)
	for i in 6:
		var k: = i
		_at(0.1, func() -> void: _pick(k))
	_at(0.45, func() -> void:
		_clear_pair(0)
		_clear_pair(1))
	_shots.append({"t": 1.0, "name": "match_idle"})
	_at(1.2, func() -> void:
		hud.show_combo(5)
		sc.trigger(1, 5))
	_shots.append({"t": 1.62, "name": "match_t1"})
	_at(2.6, func() -> void: sc.trigger(2, 10))
	_shots.append({"t": 3.15, "name": "match_t2"})
	_at(4.4, func() -> void: sc.trigger(3, 20))
	_shots.append({"t": 5.05, "name": "match_t3"})
	_at(6.0, func() -> void: _show("home"))
	_shots.append({"t": 7.4, "name": "home"})
	_at(7.6, func() -> void: _show("victory"))
	_shots.append({"t": 9.2, "name": "victory"})
	args["quit"] = "9.5"


# ------------------------------------------------------------------ clock, shots, quit

func _process(delta: float) -> void:
	t += delta
	var plan_all: = str(args.get("view", "")) == "all"
	if not paused or plan_all:
		game_t += delta
	_actions.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.t) < float(b.t))
	while not _actions.is_empty():
		var nxt: Dictionary = _actions[0]
		var clock: = t if plan_all else game_t
		if clock < float(nxt.t):
			break
		_actions.pop_front()
		(nxt.f as Callable).call()
	if _shot_dir != "" and not _shots.is_empty() and t >= float(_shots[0].t):
		var s: Dictionary = _shots.pop_front()
		var vs: = get_viewport().get_texture().get_size()
		var path: = "%s/%s_%dx%d.png" % [_shot_dir, s.name, vs.x, vs.y]
		DirAccess.make_dir_recursive_absolute(_shot_dir)
		get_viewport().get_texture().get_image().save_png(path)
		print("shot ", path)
	if args.has("quit") and t >= float(args.quit):
		for l in _log:
			print(l)
		get_tree().quit(0)
