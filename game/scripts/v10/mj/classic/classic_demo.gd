extends Control

# Демо и снимки Классики (MODES §7.1): под xvfb в 720×1280 и 1080×2400.
#   godot --path game --rendering-driver opengl3 --audio-driver Dummy --resolution 720x1280 \
#     res://scripts/v10/mj/classic/classic_demo.tscn -- --shots=<dir> [--tag=720] [--only=lobby|match|memory|daily]
#     [--fx=min] [--plain=1]
# По умолчанию — как у интегратора: героиня — режиссёр дорожки stage (V10MjPresence), фишки — материал дорожки look,
# стол — её стол look (V10MjTableView). --plain=1 — встроенная героиня Классики и фишки V6 (запасной путь).
# Файлы: <dir>/classic_<tag>_<name>.png. Без --shots открывает экран режима и остаётся (ручная игра).
# Итог: CLASSIC_DEMO OK shots=N hits=H (H — пиксели героини над святой зоной при включённом вводе, должно быть 0).

const SHOTS: = ["lobby", "lobby_daily", "match_turtle_start", "match_h_yue_start", "match_dragon_start", "match_play",
	"match_ult", "match_zoom", "match_pause", "match_flat", "match_win", "match_result", "daily_start", "memory_start",
	"memory_play", "memory_result"]

var a: = {}
var shots: = ""
var tag: = ""
var fx: = "full"
var plain: = false
var n_shots: = 0
var hits: = 0
var audit: Array = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	for s in OS.get_cmdline_user_args():
		if s.begins_with("--") and "=" in s:
			a[s.substr(2, s.find("=") - 2)] = s.substr(s.find("=") + 1)
	shots = String(a.get("shots", ""))
	fx = String(a.get("fx", "full"))
	plain = String(a.get("plain", "")) == "1"
	tag = String(a.get("tag", str(DisplayServer.window_get_size().x)))
	if G.get("S") is Dictionary and G.S.is_empty() and G.has_method("load_game"):
		G.load_game()
	if fx == "min":
		G.S["fx_level"] = "min"
	# the demo never writes the player's save: progress lives in a sandbox (rewards are still computed)
	V10MjClassicData.persist = false
	V10MjClassicData.sandbox = {}
	if shots == "":
		_lobby()
		return
	get_tree().create_timer(170.0).timeout.connect(func():
		print("CLASSIC_DEMO watchdog")
		get_tree().quit(3))
	DirAccess.make_dir_recursive_absolute(shots)
	await get_tree().process_frame
	await _run()
	print("CLASSIC_DEMO OK shots=%d hits=%d" % [n_shots, hits])
	for line in audit:
		print("  ", line)
	get_tree().quit(0 if hits == 0 else 1)


func _match_args(extra: Dictionary) -> Dictionary:
	var m: = {"fx": fx, "no_save": false}  # progress goes to the sandbox above: rewards are real, the save is untouched
	var h: String = String(extra.get("hero", extra.get("host", "mc")))
	if not plain:
		m["presence"] = "stage"
		if ResourceLoader.exists("res://scripts/v10/mj/look/tile_material.gd"):
			m["look"] = load("res://scripts/v10/mj/look/tile_material.gd").look_dict("", h)
		if ResourceLoader.exists("res://scripts/v10/mj/look/table_themes.gd"):
			m["table"] = load("res://scripts/v10/mj/look/table_themes.gd").theme_for(h, "SSR", true)
	m.merge(extra, true)
	return m


# ---- manual play ----------------------------------------------------------------------------------------------
func _lobby() -> void:
	var l: = V10MjClassicLobby.new()
	add_child(l)
	l.setup(null, {"hero": "mc", "fx": fx})
	l.play.connect(func(args): _open(args))


func _open(args: Dictionary) -> void:
	for c in get_children():
		c.queue_free()
	var s: Control
	if args.get("variant", "") == "memory":
		s = V10MjClassicMemory.new()
	else:
		s = V10MjClassicScreen.new()
	add_child(s)
	s.setup(null, _match_args(args))
	s.finished.connect(func(_r): _lobby_again())


func _lobby_again() -> void:
	for c in get_children():
		c.queue_free()
	_lobby()


# ---- snapshots ------------------------------------------------------------------------------------------------
func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _shot(name: String, scr: Node = null) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: = get_viewport().get_texture().get_image()
	var p: = "%s/classic_%s_%s.png" % [shots, tag, name]
	img.save_png(p)
	n_shots += 1
	var line: = "SHOT %s %s" % [p, img.get_size()]
	if scr != null and "presence" in scr and scr.presence != null and scr.presence.has_method("sacred_hits"):
		var on: bool = scr.presence.is_input_on() if scr.presence.has_method("is_input_on") else bool(scr.presence.get("input_on"))
		var h: Array = scr.presence.sacred_hits()
		if on:
			hits += h.size()
		line += " input_on=%s hits=%d" % [on, h.size() if on else 0]
	if scr is V10MjClassicScreen:
		line += " taps=%d words=%d" % [(scr as V10MjClassicScreen).tappables().size(), (scr as V10MjClassicScreen).words_in_play()]
	print(line)
	audit.append(line)


func _clear() -> void:
	for c in get_children():
		c.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func _want(k: String) -> bool:
	return a.get("only", "") == "" or String(a.get("only", "")) == k


func _run() -> void:
	if _want("lobby"):
		var l: = V10MjClassicLobby.new()
		add_child(l)
		l.setup(null, {"hero": "mc", "fx": fx, "no_save": true})
		await _wait(0.9)
		await _shot("lobby")
		l.seg.idx = 1
		l.seg.queue_redraw()
		l.seg.changed.emit(1)
		await _wait(0.6)
		await _shot("lobby_daily")
		await _clear()
	if _want("match"):
		for c in [["turtle", "mc", 7], ["h_yue", "yue", 7], ["dragon", "rin", 11]]:
			var s: = V10MjClassicScreen.new()
			add_child(s)
			s.setup(null, _match_args({"form": c[0], "hero": c[1], "seed": c[2], "diff": "normal", "view": "3d"}))
			await _wait(1.6)
			await _shot("match_%s_start" % c[0], s)
			if c[0] == "turtle":
				await _turtle(s)
			elif c[0] == "dragon":
				await _ult(s)
			await _clear()
	if _want("daily"):
		var d: = V10MjClassicScreen.new()
		add_child(d)
		d.setup(null, _match_args({"variant": "daily", "date": "2026-11-24", "host": V10MjClassicData.daily_host("2026-11-24")}))
		await _wait(2.2)
		await _shot("daily_start", d)
		await _clear()
	if _want("memory"):
		var m: = V10MjClassicMemory.new()
		add_child(m)
		var margs: = _match_args({"size": "4x5", "hero": "yue", "seed": 4})
		margs.erase("table")
		m.setup(null, margs)
		await _wait(1.2)
		await _shot("memory_start", m)
		var b: = m.peek_pairs()
		if b.size() >= 2:
			m.flip(b[0][0])
			m.flip(b[0][1])
			await _wait(0.9)
			m.flip(b[1][0])
			m.flip(b[2][0] if b.size() > 2 else b[1][1])
			await _wait(0.3)
		await _shot("memory_play", m)
		# play it out (a player who remembers everything)
		m.open.clear()
		for pr in m.peek_pairs():
			m.flip(pr[0])
			m.flip(pr[1])
			await _wait(0.05)
		await _wait(2.4)
		await _shot("memory_result", m)
		await _clear()


# the Turtle: a few pairs, a lifted tile and the hint (free tiles lit, closed in shade), her Приём, a zoom, the pause,
# the flat view, then the solver plays it out to the flash of the empty form and the result
func _turtle(s: V10MjClassicScreen) -> void:
	var rng: = RandomNumberGenerator.new()
	rng.seed = 3
	for k in 14:
		var path: = V10MjClassicGen.solve(s.board.geo, s.board.alive, s.board.keys, 400)
		var ps: = s.board.pairs_now()
		if ps.is_empty():
			break
		var p: Array = [path[0], path[1]] if path.size() >= 2 else ps[rng.randi_range(0, ps.size() - 1)]
		s.board.tap(p[0])
		s.board.tap(p[1])
		await _wait(0.12)
	await _wait(0.6)
	var hp: = s.board.hint_pair()
	var fr: = V10MjClassicGen.free_list(s.board.geo, s.board.alive)
	for i in fr:
		if not i in hp:
			s.board.tap(i)
			break
	s.board.hint()
	await _wait(0.5)
	await _shot("match_play", s)
	s.board._clear_hint()
	s.board._select(-1)
	s.board.zoom_to(2.0, s.field.get_global_rect().get_center() + Vector2(-80, -120))
	await _wait(0.6)
	await _shot("match_zoom", s)
	s.board.zoom_to(1.0, s.field.get_global_rect().get_center())
	await _wait(0.4)
	s.open_pause()
	await _wait(0.5)
	await _shot("match_pause", s)
	var vt: Node = s.sheet.get_meta("panel").get_node_or_null("ViewToggle")
	if vt:
		vt.pressed.emit()
	s.close_pause()
	await _wait(0.6)
	await _shot("match_flat", s)
	s.board.set_view("3d")
	await _wait(0.4)
	var path2: = V10MjClassicGen.solve(s.board.geo, s.board.alive, s.board.keys, 8000)
	for k in range(0, path2.size(), 2):
		s.board.take(path2[k], path2[k + 1])
		await get_tree().process_frame
	await _wait(0.9)
	await _shot("match_win", s)
	await _wait(2.0)
	await _shot("match_result", s)


# Rin's Приём on her table: the ring fills with pairs, a tap on her window shows a pair that is still closed and
# the tiles that keep it closed
func _ult(s: V10MjClassicScreen) -> void:
	for k in 8:
		var path: = V10MjClassicGen.solve(s.board.geo, s.board.alive, s.board.keys, 400)
		if path.size() < 2:
			break
		s.board.tap(path[0])
		s.board.tap(path[1])
		await _wait(0.1)
	s.charge = s.need
	if s.lite:
		s.lite.set_charge(1.0)
	elif "band" in s.presence:
		s.presence.band.set_charge(1.0, false)
	await _wait(0.7)
	s.try_ult()
	await _wait(0.8)
	await _shot("match_ult", s)
