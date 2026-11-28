extends Control

# Runner of TWLegalSelftest:  godot --headless --path game res://tests/legal/legal_selftest.tscn
# Prints "TWLEGAL_SELFTEST ok/total OK|FAILED"; exit code 0 when all pass.


func _ready() -> void:
	await get_tree().process_frame
	var t: TWLegalSelftest = TWLegalSelftest.new()
	var r: Array = await t.run(self)
	get_tree().quit(0 if r[0] == r[1] else 1)
