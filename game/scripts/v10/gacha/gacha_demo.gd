extends Control

# Standalone runner of the gacha lane (no main.gd, no save touched):
#   selftest:  godot --headless --path game res://scripts/v10/gacha/gacha_demo.tscn -- --gacha_selftest=1 [--mc=0.3]
#   shots:     xvfb-run -a godot --path game --rendering-driver opengl3 --audio-driver Dummy --resolution 720x1280 \
#                res://scripts/v10/gacha/gacha_demo.tscn -- --shots=<dir> [--only=name,name]
#   live:      … gacha_demo.tscn -- --screen=wish|odds|first|seven|stars|mastery|guest   (stays open)
# The demo builds its own G.S in memory (G.save is never called: G.save_path points into user://gacha_demo/).

var args: = {}


func _args() -> Dictionary:
	var a: = {}
	for s in OS.get_cmdline_user_args():
		if s.begins_with("--"):
			var kv: = s.substr(2).split("=", true, 1)
			a[kv[0]] = kv[1] if kv.size() > 1 else "1"
	return a


func _ready() -> void:
	args = _args()
	if args.has("gacha_selftest"):
		var r: = V10GachaSelftest.run(float(args.get("mc", "1")))
		get_tree().quit(0 if r[0] == r[1] else 1)
		return
	var demo: = V10GachaDemo.new()
	demo.size = get_viewport_rect().size
	add_child(demo)
	demo.start(args)
