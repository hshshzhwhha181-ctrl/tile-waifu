extends Node

# Standalone runner of the rituals lane (no hot files touched):
#   godot --headless --path game res://scripts/v10/rituals/rituals_runner.tscn -- --rit=selftest [--rit_only=<module>]
#   xvfb-run … -- --rit=shots --shots=<dir> [--rit_only=<scene>]   every component in its states → PNG
#   xvfb-run … -- --rit=demo [--rit_only=<scene>]                   interactive gallery (tap through)
# G is an autoload, so always pass --save=user://rit_runner.json --save_wipe=1 (the runner never uses the real save).

const GalleryScript: = preload("res://scripts/v10/rituals/ui/rit_gallery.gd")


func _ready() -> void:
	var mode: = "demo"
	var only: = ""
	var shots: = ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--rit="):
			mode = a.substr(6)
		elif a.begins_with("--rit_only="):
			only = a.substr(11)
		elif a.begins_with("--shots="):
			shots = a.substr(8)
	if mode == "selftest":
		var fails: = V10RitualsSelftest.run(only)
		get_tree().quit(1 if fails > 0 else 0)
		return
	var gal: = GalleryScript.new()
	add_child(gal)
	if mode == "shots":
		await gal.shots(shots if shots != "" else "user://rit_shots", only)
		get_tree().quit()
	else:
		gal.demo(only)
