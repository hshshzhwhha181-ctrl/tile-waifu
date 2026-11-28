extends Node

# Runner of the rules-core selftest (P16): TWRng, TWFree, TWBoardEvents, TWBoard (game/core/rules/).
#   godot --headless --path game res://scripts/v10/rules/tw_board_selftest.tscn [-- --levels_n=200 --seeds_n=1000 --fuzz_n=48]
# Prints "TWBOARD_SELFTEST ok/total"; exit code 0 when all pass.


func _ready() -> void:
	await get_tree().process_frame
	var env: = {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--levels_n="):
			env["levels_n"] = int(a.substr(11))
		elif a.begins_with("--seeds_n="):
			env["seeds_n"] = int(a.substr(10))
		elif a.begins_with("--fuzz_n="):
			env["fuzz_n"] = int(a.substr(9))
	var r: Array = TWBoardSelftest.run(env)
	get_tree().quit(0 if r[0] == r[1] else 1)
