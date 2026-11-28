class_name V10EventsShotRunner
extends Control

# Screenshot wrapper for the 0.12 event screens (the real Main registers them later):
#   godot --path game res://scripts/v10/events/events_shot_runner.tscn -- --ev=welcome7|wheel --out=<png> [--day=3] [--spin=1]

func _ready() -> void:
	var a: = {}
	for s in OS.get_cmdline_user_args():
		if s.begins_with("--") and "=" in s:
			var kv: = s.substr(2).split("=", true, 1)
			a[kv[0]] = kv[1]
	G.S = G.default_state()
	V10Money.set_balance("gems", 640)
	var vp: = get_viewport().get_visible_rect().size
	size = vp
	var scr: Control
	var ev: = String(a.get("ev", "welcome7"))
	if ev == "wheel":
		scr = V10LuckyWheelScreen.new()
	else:
		var st: = V10Welcome7Screen.state()
		st["days_claimed"] = int(a.get("day", "2"))
		scr = V10Welcome7Screen.new()
	scr.size = vp
	add_child(scr)
	scr.build(null, {})
	await get_tree().create_timer(0.8).timeout
	if ev == "wheel" and a.has("spin"):
		scr._on_spin()
		await get_tree().create_timer(float(a.get("spin_t", "5.9"))).timeout
	elif ev == "welcome7" and a.has("claim"):
		scr._do_claim()
		await get_tree().create_timer(0.7).timeout
	var img: = get_viewport().get_texture().get_image()
	img.save_png(String(a.get("out", "user://shot.png")))
	get_tree().quit()
