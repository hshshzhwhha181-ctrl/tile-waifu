extends Control
# THROWAWAY visual harness for coach/help (deleted before hand-off).
# -- --out=<dir> [--insets=48,24] [--fx=min] [--only=a,b]

const TILE_DIR: = "res://assets/v08/table/"

var args: = {}
var out_dir: = ""
var bg: Control
var coach: V10Coach
var log_lines: = []


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv: = a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if args.has("insets"):
		var p: PackedStringArray = str(args.insets).split(",")
		V10Hud2Util.sim_insets = {"top": float(p[0]), "bottom": float(p[1])}
	if args.has("fx"):
		V10Hud2Util.fx_override = str(args.fx)
	out_dir = str(args.get("out", "/tmp"))
	DirAccess.make_dir_recursive_absolute(out_dir)
	V10TutState.test_store = {"unlocked": 4, "partner": "mc"}
	V10TutState.mark("home_first")
	await get_tree().process_frame
	var only: = str(args.get("only", "")).split(",", false)
	var cases: = ["plate_tap", "home_do", "match_do", "match_wait", "help_tea", "how_to", "how_to_topic", "toast", "lost"]
	for c in cases:
		if only.size() > 0 and not c in only:
			continue
		await call("case_" + c)
	for l in log_lines:
		print(l)
	get_tree().quit()


func _clear() -> void:
	V10TutHelp.close_all(self)
	for n in get_children():
		n.queue_free()
	var l: = V10Coach.layer(self)
	for n in l.get_children():
		n.queue_free()
	var l2: = V10TutHelp.layer(self)
	for n in l2.get_children():
		n.queue_free()
	V10TutTarget.clear_cache()
	await get_tree().process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: = get_viewport().get_texture().get_image()
	var vs: = get_viewport_rect().size
	var path: = "%s/%s_%dx%d.png" % [out_dir, name, int(vs.x), int(vs.y)]
	img.save_png(path)
	var st: = coach.debug_state() if coach != null and is_instance_valid(coach) else {}
	log_lines.append("SHOT %s %s" % [path, str(st)])


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _new_coach() -> V10Coach:
	coach = V10Coach.new()
	V10Coach.layer(self).add_child(coach)
	coach.finished.connect(func(r: String) -> void: log_lines.append("finished %s" % r))
	return coach


# --- backgrounds ----------------------------------------------------------------------------------

class Bg:
	extends Control
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), V10DS.NIGHT_900)


func _plate_screen() -> Array:
	bg = Bg.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var h: = V10Header.make(bg, "Столы", func() -> void: pass, func() -> void: pass)
	var vs: = get_viewport_rect().size
	var y: = V10Header.content_y(vs) + 16.0
	var out: = []
	var rows: = [["Путь", "Глава 1 · Чайный сад", "tab_tables"], ["Классика", "Две одинаковые открытые", "info"],
		["Сегодня", "Партия дня", "heart"], ["Турнир недели", "Топ-5 поднимаются", "arrow_r"]]
	for r in rows:
		var p: = V10Plate.make("M", 656, r[0], r[1], "", r[2])
		p.position = Vector2(32, y)
		bg.add_child(p)
		out.append(p)
		y += 96.0
	var b: = V10Button.make("play", "Играть · 1-5", Vector2(560, 104))
	b.position = Vector2(80, vs.y - V10Hud2Util.safe_insets(vs).bottom - 160.0 - 104.0)
	b.overline = "Путь · Чайный сад"
	b.set_meta("tut_id", "tables.play")
	bg.add_child(b)
	return out


func _home() -> V10HudHome:
	var h: = V10HudHome.new()
	h.configure({"hero": "mc", "nick": "Гость", "level": "1-4", "path": "Чайный сад", "affinity": 2, "lit": [false, true, false]})
	add_child(h)
	bg = h
	await get_tree().process_frame
	h.play_b.set_meta("tut_id", "home.play")
	h.lantern_tr[1].set_meta("tut_id", "lantern.salon")
	h.lantern_tr[1].set_meta("tut_radius", 12.0)
	return h


func _match() -> V10HudMatch:
	var hud: = V10HudMatch.new()
	add_child(hud)
	hud.configure({"hero": "mc", "level": "1-1", "total": 30, "left": 30, "helpers": {"undo": 2, "hint": 3, "shuffle": 1}, "stake_offer": false})
	hud.set_ult(0.2)
	bg = hud
	var tw: = 76.0
	var th: = 106.0
	var x0: = (688.0 - 7 * tw) * 0.5
	var y0: = 120.0
	var first: Control = null
	for li in 2:
		var cols: = 7 - li * 2
		var rows: = 5 - li * 2
		for r in rows:
			for c in cols:
				var tr: = TextureRect.new()
				tr.texture = load(TILE_DIR + "t%02d.png" % ((r * 7 + c + li * 3) % 34))
				tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				tr.stretch_mode = TextureRect.STRETCH_SCALE
				tr.size = Vector2(tw, th)
				tr.position = Vector2(x0 + c * tw + li * (tw - 4.0), y0 + r * 92.0 + li * 85.0)
				tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
				hud.board_layer.add_child(tr)
				if li == 1 and r == 0 and c == 1:
					first = tr
	await get_tree().process_frame
	first.set_meta("tut_id", "match.tile_a")
	hud.tray.set_meta("tut_id", "match.tray")
	hud.board_layer.set_meta("tut_id", "match.board")
	hud.status_l.set_meta("tut_id", "match.status")
	V10TutTarget.provide("match.help", func() -> Rect2:
		var r: = Rect2()
		for k in hud.discs:
			var d: Control = hud.discs[k]
			var g: = Rect2(d.get_global_rect().position, Vector2(80, 80))
			r = g if not r.has_area() else r.merge(g)
		return r)
	return hud


# --- cases ------------------------------------------------------------------------------------------

func case_plate_tap() -> void:
	await _clear()
	var plates: = _plate_screen()
	await get_tree().process_frame
	_new_coach().show_step({"line": V10TutLines.intro_line("tables_first"), "speaker": "mc", "portrait": true,
		"rect": Rect2(plates[1].get_global_rect().position, Vector2(656, 80)), "radius": 4.0, "mode": "tap", "dim": 0.72,
		"root": bg})
	await _wait(0.2)
	await _shot("a_plate_tap_mid")
	await _wait(1.0)
	await _shot("a_plate_tap")


func case_home_do() -> void:
	await _clear()
	var h: = await _home()
	_new_coach().show_step({"line": V10TutLines.intro_line("lantern_salon"), "speaker": "mc", "target": "lantern.salon",
		"mode": "do", "dim": 0.72, "root": h, "avoid": [h.L.hero_face.grow(48)], "timeout": 0})
	await _wait(0.85)
	await _shot("b_home_do_ring")
	await _wait(1.2)
	await _shot("b_home_do")


func case_match_do() -> void:
	await _clear()
	var hud: = await _match()
	var face: Rect2 = hud.hero_face_global()
	var T: = float(V10Hud2Util.safe_insets(get_viewport_rect().size).top)
	_new_coach().show_step({"line": V10TutLines.match_line("m_a"), "speaker": "mc", "target": "match.tile_a",
		"mode": "do", "dim": 0.45, "place": "hero", "anchor": Rect2(152, T + 912, 368, 120), "avoid": [face.grow(48)],
		"skippable": true, "root": hud, "timeout": 0})
	await _wait(0.9)
	await _shot("c_match_do_ring")
	await _wait(1.0)
	await _shot("c_match_do")


func case_match_wait() -> void:
	await _clear()
	var hud: = await _match()
	var face: Rect2 = hud.hero_face_global()
	var T: = float(V10Hud2Util.safe_insets(get_viewport_rect().size).top)
	_new_coach().show_step({"line": V10TutLines.match_line("m_tray", {"n": 5}), "speaker": "mc", "target": "match.tray",
		"mode": "wait", "dim": 0.45, "place": "hero", "anchor": Rect2(152, T + 912, 368, 120), "avoid": [face.grow(48)],
		"root": hud})
	await _wait(1.2)
	await _shot("d_match_wait")


func case_help_tea() -> void:
	await _clear()
	await _home()
	V10TutHelp.open(self, "teahouse")
	await _wait(0.6)
	await _shot("e_help_teahouse")


func case_how_to() -> void:
	await _clear()
	await _home()
	V10TutHelp.open_how_to(self)
	await _wait(0.6)
	await _shot("f_how_to")


func case_how_to_topic() -> void:
	await _clear()
	await _home()
	var sh: = V10TutHelp.open_how_to(self)
	await _wait(0.4)
	sh.call("show_topic", "help_row", true)
	await _wait(0.6)
	await _shot("g_how_to_topic")


func case_toast() -> void:
	await _clear()
	var h: = await _home()
	var vs: = get_viewport_rect().size
	var nav: Rect2 = h.L.nav
	var cell: = Rect2(nav.position.x + 144 * 4, nav.position.y, 144, 136)
	V10TutHelp.locked_toast(self, cell, V10Reveal.locked_text("tab.shop"))
	await _wait(0.5)
	await _shot("h_toast")


func case_lost() -> void:
	await _clear()
	var h: = await _home()
	_new_coach().show_step({"line": V10TutLines.intro_line("phone_first"), "speaker": "mc", "target": "home.nothing",
		"mode": "do", "root": h})
	await _wait(2.2)
	await _shot("i_lost")
	await _wait(4.5)
	log_lines.append("lost showing=%s" % coach.is_showing())
