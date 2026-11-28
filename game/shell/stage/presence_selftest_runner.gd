extends Node

# Runner of the TWPresence selftest (P34):  godot --headless --path game res://shell/stage/presence_selftest.tscn
# Prints "TWPRESENCE_SELFTEST ok/total"; exit code 0 when all pass.


func _ready() -> void:
	await get_tree().process_frame
	var t: = TWPresenceSelftest.new()
	var r: Array = await t.run(self)
	get_tree().quit(0 if r[0] == r[1] else 1)
