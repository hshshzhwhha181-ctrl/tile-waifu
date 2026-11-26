extends Node

# Демо и снимки «Связей»: --shots=<dir> --tag=720 [--level=18] [--hero=rin]

var args: = {}


func _ready() -> void:
	for s in OS.get_cmdline_user_args():
		if s.begins_with("--") and "=" in s:
			args[s.substr(2, s.find("=") - 2)] = s.substr(s.find("=") + 1)
	await get_tree().process_frame
	var s: = V10MjConnectScreen.new()
	get_tree().root.add_child(s)
	s.setup(null, {
		"level": int(args.get("level", "18")),
		"hero": String(args.get("hero", "rin")),
		"start_sheet": bool(int(args.get("start_sheet", "0"))),
		"instant": true,
		"demo": true,
		"mute": true,
	})
	for i in 4:
		await get_tree().process_frame
	var dir: = String(args.get("shots", ""))
	var tag: = String(args.get("tag", "720"))
	if dir != "":
		DirAccess.make_dir_recursive_absolute(dir)
		get_viewport().get_texture().get_image().save_png("%s/connect_%s_start.png" % [dir, tag])
	get_tree().quit(0)
