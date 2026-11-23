extends Control


func _ready() -> void :
	size = get_viewport_rect().size
	var a: = {}
	for s in OS.get_cmdline_user_args():
		if s.begins_with("--") and "=" in s:
			var kv: = s.substr(2).split("=", true, 1)
			a[kv[0]] = kv[1]
	if not a.has("story_shots"):
		return
	var t0: = 0.0
	var times: Array = Array(a.get("at", "2").split(","))
	for i in times.size():
		var t: = float(times[i])
		await get_tree().create_timer(t - t0).timeout
		t0 = t
		get_viewport().get_texture().get_image().save_png("%s/%s_%d.png" % [a.story_shots, a.get("story_scene", "scene"), i])
	get_tree().quit()
