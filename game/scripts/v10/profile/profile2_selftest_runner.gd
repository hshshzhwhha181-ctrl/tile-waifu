extends Node

# Standalone runner for V10Profile2Selftest (does not touch main.gd or the save):
#   flock /tmp/tw-godot.lock /opt/tw-tools/godot --headless --path game \
#     res://scripts/v10/profile/profile2_selftest.tscn -- --profile2_selftest=1
# Exit code 0 when every check passed, 1 otherwise.


func _ready() -> void:
	get_tree().create_timer(60.0).timeout.connect(func(): get_tree().quit(3))
	if not ("--profile2_selftest=1" in OS.get_cmdline_user_args()):
		print("profile2_selftest_runner: pass --profile2_selftest=1")
		get_tree().quit(2)
		return
	var host: = Control.new()
	host.size = Vector2(720, 1280)
	add_child(host)
	var r: Array = V10Profile2Selftest.run(host)
	# let closing sheets finish their fade (no leaked nodes at quit)
	await get_tree().create_timer(0.5).timeout
	get_tree().quit(0 if r[0] == r[1] else 1)
