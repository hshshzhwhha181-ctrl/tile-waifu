extends Node

# Демо и снимки Лунного стола: --shots=<dir> [--seed=N] [--names=jp]
# xvfb-run ... godot --path game --resolution 720x1280 res://scripts/v10/mj/sanma/sanma_demo.tscn -- --shots=/tmp/x
# Снимки: sanma_<WxH>_table.png (ход игрока, «Север · кита», табло ×12), _kita.png (Север летит к хозяйке),
#         _result.png (итог раздачи), _final.png (итог партии).

var sc: Control
var dir: = ""
var tag: = ""

func _arg(k: String, d: String) -> String:
	for s in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if s.begins_with("--" + k + "="):
			return s.split("=")[1]
	return d

func _ready() -> void:
	V10MjSanmaData.force_mem = true
	dir = _arg("shots", "")
	var ws: = DisplayServer.window_get_size()
	tag = "%dx%d" % [ws.x, ws.y]
	if dir != "":
		DirAccess.make_dir_recursive_absolute(dir)
	sc = load("res://scripts/v10/mj/sanma/sanma_screen.gd").new()
	sc.size = get_viewport().get_visible_rect().size
	add_child(sc)
	sc.setup(null, {"seed": int(_arg("seed", "20261124")), "event": true, "partner": "mc", "host": "yue", "rival": "hana",
		"fast": true, "hold": true, "names": _arg("names", "ru")})
	await _frames(4)
	# 1) дойти до хода игрока с заполненными сбросами
	var guard: = 0
	while guard < 4000:
		guard += 1
		if sc.sheet_open:
			sc._close_sheet()
		sc.pump_once()
		if sc.waiting_input():
			if sc.cur_ask.get("kind", "") == "turn" and sc.r.ponds[0].size() >= 7 and sc.r.kita[1].size() + sc.r.kita[2].size() >= 1:
				break
			sc._demo_answer()
		if guard % 50 == 0:
			await _frames(1)
	sc.debug_force_kita()
	sc.debug_set_mult(12)
	sc.debug_select(4)
	sc.subtitle.text = V10MjSanmaText.LINES.host_x3.ru
	sc.subtitle.modulate.a = 1.0
	await _frames(6)
	await _shot("table")
	# 2) кита с анимацией
	sc.subtitle.modulate.a = 0.0
	sc.fast = false
	sc.press("kita")
	sc.pump_once()
	sc.pump_once()
	await get_tree().create_timer(0.47).timeout
	await _shot("kita")
	await get_tree().create_timer(1.2).timeout
	sc.fast = true
	# 3) итог раздачи с победой
	guard = 0
	var got: = false
	while guard < 6000 and not got:
		guard += 1
		if sc.sheet_open:
			if sc.r.result.get("ev", "") == "win" and int(sc.r.result.eval.get("han", 0)) >= 2:
				got = true
				break
			if not sc.match_done:
				sc._close_sheet()
		if sc.match_done:
			break
		var ev: Dictionary = sc.pump_once()
		if ev.get("ev", "") == "deal":
			print("DEAL ", ev.round, " dealer=", ev.dealer)
		if sc.waiting_input():
			sc._demo_answer()
		if guard % 50 == 0:
			await _frames(1)
	print("RESULT loop guard=", guard, " got=", got, " done=", sc.match_done, " state=", sc.r.state)
	await _frames(4)
	await _shot("result")
	# 4) итог партии
	guard = 0
	while guard < 20000 and not sc.match_done:
		guard += 1
		if sc.sheet_open and not sc.match_done:
			sc._close_sheet()
		sc.pump_once()
		if sc.waiting_input():
			sc._demo_answer()
		if guard % 100 == 0:
			await _frames(1)
	print("FINAL loop guard=", guard, " done=", sc.match_done, " state=", sc.r.state, " round=", sc.r.round_name())
	await _frames(4)
	await _shot("final")
	print("SANMA_DEMO done ", tag)
	get_tree().quit(0)

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	if dir == "":
		return
	var img: = get_viewport().get_texture().get_image()
	var p: = dir.path_join("sanma_%s_%s.png" % [tag, name])
	img.save_png(p)
	print("SHOT ", p)
