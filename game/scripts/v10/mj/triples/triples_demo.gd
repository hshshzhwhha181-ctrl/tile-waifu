extends Node

# Демо и снимки Троек: старт · 6/7 (опасность) · победа (финал героини) · итог.
#   godot --path game --resolution 720x1280 res://scripts/v10/mj/triples/triples_demo.tscn -- --shots=<dir>
#     [--level=14] [--hero=hana] [--tray=lacquer|tea|track|moon|neon] [--tag=720] [--fx=min] [--start_sheet=1]
# Файлы: <dir>/triples_<tag>_{start,danger,win,result}.png (+ sheet, если --start_sheet=1). Выход: TRIPLES_DEMO OK.

var a: = {}
var dir: = ""
var tag: = ""
var scr: V10MjTriplesScreen


func _ready() -> void:
	for s in OS.get_cmdline_user_args():
		if s.begins_with("--") and "=" in s:
			a[s.substr(2, s.find("=") - 2)] = s.substr(s.find("=") + 1)
	dir = String(a.get("shots", ""))
	var vs: = get_viewport().get_visible_rect().size
	tag = String(a.get("tag", "%dx%d" % [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y]))
	if dir != "":
		DirAccess.make_dir_recursive_absolute(dir)
	if a.get("fx", "") == "min":
		G.S["fx_level"] = "min"
	get_tree().create_timer(120.0).timeout.connect(func(): get_tree().quit(3))
	await get_tree().process_frame
	await _run()
	print("TRIPLES_DEMO OK")
	get_tree().quit(0)


func _make(extra: = {}) -> V10MjTriplesScreen:
	var s: = V10MjTriplesScreen.new()
	var args: = {"level": int(a.get("level", "14")), "hero": String(a.get("hero", "hana")), "demo": true,
		"start_sheet": false, "instant": true}
	if a.has("tray"):
		args["look"] = {"tray": String(a.tray)}
	args.merge(extra, true)
	s.setup(null, args)
	add_child(s)
	return s


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	if dir == "":
		return
	var img: = get_viewport().get_texture().get_image()
	var p: = "%s/triples_%s_%s.png" % [dir, tag, name]
	img.save_png(p)
	print("SHOT ", p, " ", img.get_size())


func _run() -> void:
	if a.get("start_sheet", "") == "1":
		scr = _make({"start_sheet": true, "level": 22})
		await _wait(0.8)
		await _shot("sheet")
		scr.queue_free()
		await get_tree().process_frame
	# 1) старт
	scr = _make()
	await _wait(1.4)
	await _shot("start")
	# 2) 6/7: шесть разных лиц в лотке, без тройки
	var r: = scr.board.rules
	var guard: = 0
	while r.tray.size() < 6 and guard < 40:
		guard += 1
		var tc: = {}
		for t in r.tray:
			tc[r.face[t]] = int(tc.get(r.face[t], 0)) + 1
		var pick: = -1
		for i in r.frees:
			if not tc.has(r.face[i]):
				pick = i
				break
		if pick < 0:
			for i in r.frees:
				if int(tc.get(r.face[i], 0)) == 1:
					pick = i
					break
		if pick < 0:
			break
		scr.board.tap(pick)
		await _wait(0.12)
	await _wait(1.3)
	await _shot("danger")
	scr.queue_free()
	await get_tree().process_frame
	# 3) победа: сертификат проигрывается вживую (Благословение стола доигрывает конец)
	scr = _make({"level": int(a.get("win_level", a.get("level", "14")))})
	await _wait(0.6)
	var order: Array = scr.lv.order
	for i in order:
		if scr.blessing or scr.ended:
			break
		if scr.board.rules.present[int(i)] == 1:
			while scr.board.busy() and not scr.blessing:
				await _wait(0.03)
			if scr.blessing:
				break
			scr.board.tap(int(i))
			await _wait(0.09)
	var t0: = Time.get_ticks_msec()
	while not scr.ended and Time.get_ticks_msec() - t0 < 15000:
		await _wait(0.05)
	await _wait(1.1)
	await _shot("win")
	t0 = Time.get_ticks_msec()
	while scr.result.is_empty() and Time.get_ticks_msec() - t0 < 8000:
		await _wait(0.05)
	await _wait(1.4)
	await _shot("result")
	print("DEMO_RESULT ", JSON.stringify(scr.result))
