# Dumps what Godot actually loads for a list of textures to PNG, for before/after visual QA.
# usage: godot --headless --path game --script res://../tools/assets/qa_dump.gd -- OUT_DIR res://a.webp res://b.png ...
# (run it twice, once on the baseline worktree and once on the slim one, then diff with qa_compare.py)
extends SceneTree

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() < 2:
		push_error("usage: -- OUT_DIR res://tex ...")
		quit(2)
		return
	var out: String = a[0]
	DirAccess.make_dir_recursive_absolute(out)
	for i in range(1, a.size()):
		var t := load(a[i]) as Texture2D
		if t == null:
			print("QA_MISSING ", a[i])
			continue
		var img := t.get_image()
		if img.is_compressed():
			img.decompress()
		var name := String(a[i]).trim_prefix("res://").replace("/", "__")
		img.save_png(out.path_join(name + ".png"))
		print("QA_DUMP ", a[i], " ", img.get_width(), "x", img.get_height())
	quit(0)
