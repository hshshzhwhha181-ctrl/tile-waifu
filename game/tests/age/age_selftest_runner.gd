extends Control

# Runner of TWAgeSelftest (P22):  godot --headless --path game res://tests/age/age_selftest.tscn
# Prints "TWAGE_SELFTEST ok/total OK|FAILED"; exit code 0 when all pass.


func _ready() -> void:
	await get_tree().process_frame
	var t: TWAgeSelftest = TWAgeSelftest.new()
	var r: Array = t.run()
	get_tree().quit(0 if r[0] == r[1] else 1)
