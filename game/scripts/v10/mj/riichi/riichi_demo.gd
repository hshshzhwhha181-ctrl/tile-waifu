extends Node

# Demo + screenshots for «Стол на четверых».
#   xvfb-run godot --path game --rendering-driver opengl3 --audio-driver Dummy --resolution 720x1280 \
#     res://scripts/v10/mj/riichi/riichi_demo.tscn -- --shots=<dir> [--hall=school] [--seed=1201]
# Shots: lobby, table (selected tile + hint), riichi (ribbon), call buttons, win cut-in, tally, match end, seed,
# square table. A bot plays the player's seat with the AI's choices; inserts are captured in real time.

const D = preload("res://core/modes/riichi/riichi_data.gd")

var dir: = ""
var scr: V10MjRiichiScreen
var tag: = ""
var done: = {}

func _arg(k: String, d: String) -> String:
	for s in OS.get_cmdline_user_args():
		if s.begins_with("--" + k + "="):
			return s.split("=")[1]
	return d

func _ready() -> void:
	dir = _arg("shots", "")
	var vs: = get_viewport().get_visible_rect().size
	tag = "%dx%d" % [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y]
	if has_node("/root/G"):
		get_node("/root/G").S = {"partner": "mc", "rp": 0}
	D._mem = {}
	D.st().hall_progress.games["school"] = 2
	var bgc: = ColorRect.new()
	bgc.color = D.NIGHT_900
	bgc.size = vs
	add_child(bgc)
	await get_tree().process_frame
	# 1. hall picker
	scr = _screen({}, vs)
	await _wait(0.6)
	await shot("01_lobby")
	scr.queue_free()
	# 2. table (training hall, portrait)
	scr = _screen({"hall": _arg("hall", "school"), "seed": int(_arg("seed", "1201"))}, vs)
	await _run_until(func(): return scr.drv.waiting and scr.drv.r.ask.kind == "turn" and scr.turn_count >= 14, 6000)
	var o: Dictionary = scr.drv.r.ask.opts
	var pick: = scr._coach_pick()
	scr.tap_tile(pick if pick >= 0 else scr.drv.r.drawn)
	await _wait(0.5)
	await shot("02_table")
	# 3. riichi ribbon (anyone), 4. call buttons, 5. win cut-in, 6. tally — keep playing this match and the next ones
	var seeds: = [int(_arg("seed", "1201")), 404, 515, 626, 737]
	var si: = 0
	while (not done.has("03_riichi") or not done.has("05_win") or not done.has("06_tally") or not done.has("04_call")) and si < seeds.size():
		if si > 0:
			scr.queue_free()
			scr = _screen({"hall": "school", "seed": seeds[si]}, vs)
		await _play_capture()
		si += 1
	scr.queue_free()
	# 7. match end + seed (one hand, bamboo hall)
	scr = _screen({"hall": "bamboo", "seed": 88, "format": "one_hand"}, vs)
	await _run_until(func(): return not scr.final_result.is_empty(), 20000, true)
	await _wait(0.6)
	await shot("07_end")
	scr._show_seed()
	await _wait(0.5)
	await shot("08_seed")
	scr.queue_free()
	# 9. square («горизонтальный») table, gold hall, Japanese names
	D.set_pref("names", "jp")
	scr = _screen({"hall": "gold", "seed": 2024, "horizontal": true}, vs)
	await _run_until(func(): return scr.drv.waiting and scr.turn_count >= 26, 8000)
	await _wait(0.4)
	await shot("09_square")
	await _run_until(func(): return scr.drv.waiting and scr.drv.r.ask.kind == "call", 8000)
	if scr.drv.waiting and scr.drv.r.ask.kind == "call":
		await _wait(0.3)
		await shot("10_square_call_jp")
	D.set_pref("names", "ru")
	scr.queue_free()
	# 11. three seats (sanma contract)
	scr = _screen({"hall": "jade", "seed": 77, "seats": 3}, vs)
	await _run_until(func(): return scr.drv.waiting and scr.turn_count >= 12, 6000)
	await _wait(0.3)
	await shot("11_three_seats")
	print("DEMO done ", done.keys())
	get_tree().quit()

func _screen(a: Dictionary, vs: Vector2) -> V10MjRiichiScreen:
	var s: = V10MjRiichiScreen.new()
	s.size = vs
	add_child(s)
	s.setup(null, a.merged({"manual": true, "mute": true}))
	return s

func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout

func shot(name: String) -> void:
	done[name] = true
	if dir == "":
		return
	await RenderingServer.frame_post_draw
	var img: = get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(dir)
	img.save_png("%s/%s_%s.png" % [dir, name, tag])
	print("SHOT ", name)

# step the table (bot answers for the player) until cond() is true
func _run_until(cond: Callable, cap: int, tallies: = true) -> void:
	var n: = 0
	while n < cap and not cond.call():
		n += 1
		if scr.drv.over and scr.final_result.size() > 0:
			return
		if scr.sheet and is_instance_valid(scr.sheet) and scr.sheet.has_meta("tally"):
			if tallies:
				scr._tally_next()
			else:
				return
		if scr.fx.cutin != null:
			scr.fx._end_cutin(scr.fx.cutin)
		if scr.drv.waiting:
			_bot(scr.drv.ai_answer(scr.drv.r.ask))
		elif scr.drv.holds.is_empty():
			scr.drv.step()
		else:
			await get_tree().process_frame
		if n % 40 == 0:
			await get_tree().process_frame

func _bot(a: Dictionary) -> void:
	var drv: = scr.drv
	if drv.r.ask.kind == "turn":
		match String(a.get("a", "")):
			"tsumo":
				scr.press_action("tsumo")
			"ankan", "kakan":
				scr.press_action("kan", {"k": a})
			_:
				if a.get("riichi", false):
					scr.press_action("riichi")
				scr.tap_tile(int(a.t))
				if drv.waiting:
					scr.tap_tile(int(a.t))
	else:
		var k: = String(a.get("a", "pass"))
		if k == "chi":
			scr.press_action("chi", {"use": a.get("use", [])})
		else:
			scr.press_action(k)
	if drv.waiting:
		drv.answer(a)

func _play_capture() -> void:
	var seen_r: = scr.reactions.size()
	var n: = 0
	while n < 20000 and scr.final_result.is_empty():
		n += 1
		if scr.sheet and is_instance_valid(scr.sheet) and scr.sheet.has_meta("tally"):
			if not done.has("06_tally"):
				await _wait(2.4)
				await shot("06_tally")
			scr._tally_next()
			continue
		if scr.fx.cutin != null:
			await get_tree().process_frame
			continue
		if scr.drv.waiting:
			if scr.drv.r.ask.kind == "call" and not done.has("04_call") and scr.visible_buttons().size() >= 2:
				await _wait(0.35)
				await shot("04_call")
			_bot(scr.drv.ai_answer(scr.drv.r.ask))
			continue
		if not scr.drv.holds.is_empty():
			await get_tree().process_frame
			continue
		scr.drv.step()
		while seen_r < scr.reactions.size():
			var kind: String = scr.reactions[seen_r][3]
			seen_r += 1
			if kind == "ribbon" and not done.has("03_riichi"):
				await _wait(0.22)
				await shot("03_riichi")
			elif kind.begins_with("cutin") and not done.has("05_win"):
				await _wait(0.75)
				await shot("05_win")
				if scr.fx.cutin:
					scr.fx._end_cutin(scr.fx.cutin)
			elif kind == "stamp" and not done.has("03b_stamp"):
				await _wait(0.12)
				await shot("03b_stamp")
		if n % 30 == 0:
			await get_tree().process_frame
		if done.has("03_riichi") and done.has("05_win") and done.has("06_tally") and done.has("04_call"):
			return
