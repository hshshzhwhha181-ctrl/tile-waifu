extends Node

# Standalone runner for V10EconSelftest (does not touch main.gd or the save):
#   flock /tmp/tw-godot.lock /opt/tw-tools/godot --headless --path game \
#     res://scripts/v10/economy/econ_selftest.tscn -- --econ_selftest=1 [--econ_mc=0.25]
# Exit code 0 when every check passed, 1 otherwise.


func _ready() -> void:
	var args: = OS.get_cmdline_user_args()
	var scale: = 1.0
	for a in args:
		if a.begins_with("--econ_mc="):
			scale = maxf(0.01, float(a.substr(10)))
	if not ("--econ_selftest=1" in args):
		print("econ_selftest_runner: pass --econ_selftest=1")
		get_tree().quit(2)
		return
	V10EconSelftest.run(scale)
	get_tree().quit(0 if V10EconSelftest.ok == V10EconSelftest.total else 1)
