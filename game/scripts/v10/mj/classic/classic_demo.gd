extends Control

# Demo and screenshots of the classic lane (MODES §7.1): runs under xvfb at 720x1280 and 1080x2400.
#   godot --path game --rendering-driver opengl3 --audio-driver Dummy --resolution 720x1280 \
#     res://scripts/v10/mj/classic/classic_demo.tscn -- --shots=<dir> [--only=match|lobby|memory] [--fx=min]
# Without --shots it opens the lobby and stays (manual play).

var shots: = ""
var only: = ""
var tag: = ""
var fx: = "full"


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots = a.split("=")[1]
		elif a.begins_with("--only="):
			only = a.split("=")[1]
		elif a.begins_with("--fx="):
			fx = a.split("=")[1]
	var vs: = get_viewport_rect().size
	tag = "%dx%d" % [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y]
	if G.get("S") is Dictionary and G.S.is_empty() and G.has_method("load_game"):
		G.load_game()
	if shots == "":
		_lobby()
		return
	DirAccess.make_dir_recursive_absolute(shots)
	await _run()
	get_tree().quit()


func _lobby() -> void:
	var l: = V10MjClassicLobby.new()
	add_child(l)
	l.setup(null, {"hero": "mc", "fx": fx})
	l.play.connect(func(a): _open(a))


func _open(a: Dictionary) -> void:
	for c in get_children():
		c.queue_free()
	var s: Control
	if a.get("variant", "") == "memory":
		s = V10MjClassicMemory.new()
	else:
		s = V10MjClassicScreen.new()
	add_child(s)
	s.setup(null, a)
	s.finished.connect(func(_r): _lobby_again())


func _lobby_again() -> void:
	for c in get_children():
		c.queue_free()
	_lobby()


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _shot(name: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: = get_viewport().get_texture().get_image()
	var p: = "%s/%s_%s.png" % [shots, name, tag]
	img.save_png(p)
	print("SHOT ", p)


func _clear() -> void:
	for c in get_children():
		c.queue_free()
	await get_tree().process_frame


func _run() -> void:
	if only == "" or only == "lobby":
		var l: = V10MjClassicLobby.new()
		add_child(l)
		l.setup(null, {"hero": "mc", "fx": fx, "no_save": true})
		await _wait(0.9)
		await _shot("lobby")
		await _clear()
	if only == "" or only == "match":
		var cases: = [["turtle", "mc", "3d"], ["h_yue", "yue", "3d"], ["dragon", "rin", "flat"]]
		for c in cases:
			var s: = V10MjClassicScreen.new()
			add_child(s)
			s.setup(null, {"form": c[0], "hero": c[1], "seed": 7, "diff": "normal", "view": c[2], "fx": fx, "no_save": true})
			await _wait(1.5)
			print("DBG help0 ", s.help[0].get_global_rect(), " mod ", s.help[0].modulate, s.help[0].self_modulate, " sc ", s.help[0].scale, " idx ", s.help[0].get_index(), "/", s.get_child_count(), " kind ", s.help[0].kind, " canvas ", s.help[0].get_global_transform_with_canvas())
			await _shot("match_%s_start" % c[0])
			if c[0] == "turtle":
				# a few pairs, a lifted tile and a hint, then zoom
				var rng: = RandomNumberGenerator.new()
				rng.seed = 3
				for k in 14:
					var ps: = s.board.pairs_now()
					if ps.is_empty():
						break
					var p: Array = ps[rng.randi_range(0, ps.size() - 1)]
					s.board.tap(p[0])
					s.board.tap(p[1])
					await _wait(0.12)
				await _wait(0.6)
				var fr: = V10MjClassicGen.free_list(s.board.geo, s.board.alive)
				if fr.size() > 0:
					s.board.tap(fr[0])
				var hr: bool = s.board.hint()
				await _wait(0.5)
				print("DBG hint ", hr, " ", s.board._hinted, " input ", s.board.input_on, " ", [] if s.board._hinted.is_empty() else [s.board.tiles[s.board._hinted[0]].glow.modulate, s.board.tiles[s.board._hinted[0]].glow.visible, s.board.tiles[s.board._hinted[0]].glow.texture])
				await _shot("match_turtle_play")
				s.board.zoom_to(2.0, s.field.get_global_rect().get_center() + Vector2(-80, -120))
				await _wait(0.6)
				await _shot("match_turtle_zoom")
				s.board.zoom_to(1.0, s.field.get_global_rect().get_center())
				await _wait(0.4)
				s.open_pause()
				await _wait(0.5)
				await _shot("match_turtle_pause")
				s.close_pause()
				await _wait(0.3)
				# play it out (solver) to the win sheet
				var path: = V10MjClassicGen.solve(s.board.geo, s.board.alive, s.board.keys, 6000)
				for k in range(0, path.size(), 2):
					s.board.take(path[k], path[k + 1])
					await get_tree().process_frame
				await _wait(0.5)
				await _shot("match_turtle_flash")
				await _wait(2.2)
				await _shot("match_turtle_win")
			await _clear()
	if only == "" or only == "memory":
		var m: = V10MjClassicMemory.new()
		add_child(m)
		m.setup(null, {"size": "4x5", "hero": "yue", "seed": 4, "fx": fx, "no_save": true})
		await _wait(1.0)
		await _shot("memory_start")
		var b: = m.peek_pairs()
		if b.size() >= 2:
			m.flip(b[0][0])
			m.flip(b[0][1])
			await _wait(0.3)
			m.flip(b[1][0])
			await _wait(0.35)
		await _shot("memory_play")
		await _clear()
