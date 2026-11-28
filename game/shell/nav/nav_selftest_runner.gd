extends Node

# Runner of the shell navigation selftest (P23):
#   godot --headless --path game res://shell/nav/nav_selftest.tscn
# Prints "TWNAV_SELFTEST ok/total"; exit code 0 when all pass. Takes about 4 s (one real 3 s watchdog wait).


func _ready() -> void:
	await get_tree().process_frame
	var t: = TWNavSelftest.new()
	var r: Array = await t.run(self)
	get_tree().quit(0 if r[0] == r[1] else 1)
