extends SceneTree

# Parse/compile check of every script in v10/phone (fast loop while editing):
#   godot --headless --path game -s res://scripts/v10/phone/tools/check_parse.gd

func _initialize() -> void:
	var bad: = 0
	for dir in ["res://scripts/v10/phone/", "res://core/phone/"]:  # WP3: UI-free phone files live in core
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".gd"):
				var s: = load(dir + f)
				if s == null or not (s as GDScript).can_instantiate():
					print("PARSE FAIL ", f)
					bad += 1
	print("PARSE CHECK bad=%d" % bad)
	quit(1 if bad > 0 else 0)
