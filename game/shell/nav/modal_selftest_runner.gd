extends Node

# Runner of the ModalStack selftest (P24):
#   godot --headless --path game res://shell/nav/modal_selftest.tscn
# Prints "TWMODAL_SELFTEST ok/total"; exit code 0 when all pass.


func _ready() -> void:
	await get_tree().process_frame
	var t: = TWModalSelftest.new()
	var r: Array = await t.run(self)
	get_tree().quit(0 if r[0] == r[1] else 1)
