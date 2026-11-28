extends Control

# Runner for P87 TWUltRegistry / TWUltPolicy selftest:
#   godot --headless --audio-driver Dummy --path game res://tests/ult/ult_selftest.tscn
# Prints "ULT COVERAGE ids=58 covered=58" and "TWULT_SELFTEST ok/total"; exit code 0 when all pass.

const UltSuite = preload("res://core/ult/ult_selftest.gd")


func _ready() -> void:
	await get_tree().process_frame
	var r: Array = UltSuite.run()
	get_tree().quit(0 if r[0] == r[1] else 1)
