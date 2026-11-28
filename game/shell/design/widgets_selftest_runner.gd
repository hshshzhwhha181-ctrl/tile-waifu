extends Control

# Runner of the widgets selftest (P28):  godot --headless --path game res://shell/design/widgets_selftest.tscn
# Prints "TWWIDGETS_SELFTEST ok/total"; exit code 0 when all pass.


func _ready() -> void:
	await get_tree().process_frame
	var t: = TWWidgetsSelftest.new()
	var r: Array = await t.run(self)
	get_tree().quit(0 if r[0] == r[1] else 1)
