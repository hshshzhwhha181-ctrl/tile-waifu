extends Control

# Runner of the skin_swap_soak test:  godot --headless --path game res://tests/skin_swap_soak/skin_swap_soak.tscn
# Prints "TWSKINSOAK_SELFTEST ok/total OK pending=N"; exit code 0 when all pass.


func _ready() -> void:
	await get_tree().process_frame
	var t: = TWSkinSwapSoak.new()
	var r: Array = await t.run(self)
	get_tree().quit(0 if r[0] == r[1] else 1)
