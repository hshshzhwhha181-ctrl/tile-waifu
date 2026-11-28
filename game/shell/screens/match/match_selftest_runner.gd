extends Node

# Runner of the victory-screen selftest (P33):  godot --path game res://shell/screens/match/match_selftest.tscn
# (needs a display for the pixel part: tools/tw_test.py runs it under xvfb). Prints "TWRESULT_SELFTEST ok/total".


func _ready() -> void:
	await get_tree().process_frame
	var t: = TWResultSelftest.new()
	var r: Array = await t.run(self)
	get_tree().quit(0 if r[0] == r[1] else 1)
