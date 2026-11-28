extends SceneTree

# P41: decode every rig PNG exactly as the engine loads it (imported .ctex -> Image) and save it as a lossless PNG,
# so tools/rigs/pilot.py can compute PSNR against the source. Also prints the loaded format.
#   godot --headless --path <proj> -s dump_decoded.gd -- out=/tmp/dec rigs=mc_gown,rin_officer,hana_base


func _initialize() -> void:
	var out := ""
	var rigs := PackedStringArray(["mc_gown", "rin_officer", "hana_base"])
	for a in OS.get_cmdline_user_args():
		var kv := String(a).split("=", true, 1)
		if kv.size() == 2 and kv[0] == "out":
			out = kv[1]
		if kv.size() == 2 and kv[0] == "rigs":
			rigs = kv[1].split(",")
	DirAccess.make_dir_recursive_absolute(out)
	var n := 0
	for r in rigs:
		var dir := "res://assets/v10/rig/%s" % r
		for f in DirAccess.get_files_at(dir):
			if not f.ends_with(".png"):
				continue
			var tex := load("%s/%s" % [dir, f]) as Texture2D
			if tex == null:
				print("DUMP_FAIL ", dir, "/", f)
				continue
			var im := tex.get_image()
			var fmt_before := im.get_format()
			if im.is_compressed():
				im.decompress()
			im.convert(Image.FORMAT_RGBA8)
			im.save_png("%s/%s__%s" % [out, r, f])
			n += 1
			print("DUMP ", r, "/", f, " ", tex.get_width(), "x", tex.get_height(), " fmt=", fmt_before)
	print("DUMP_DONE ", n)
	quit(0)
