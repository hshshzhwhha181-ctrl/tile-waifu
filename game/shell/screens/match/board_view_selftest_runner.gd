extends Node

# Runner of the TWBoardView selftest (P31):  godot --path game res://shell/screens/match/board_view_selftest.tscn
# (needs a display for the screenshot part: tools/tw_test.py runs it under xvfb). Prints "TWBOARDVIEW_SELFTEST ok/total".


func _ready() -> void:
	await get_tree().process_frame
	var t: = TWBoardViewSelftest.new()
	var r: Array = await t.run(self)
	get_tree().quit(0 if r[0] == r[1] else 1)
