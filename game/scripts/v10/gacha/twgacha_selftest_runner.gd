extends Node

# Runner of TWGACHA_SELFTEST (P09): parity of TWGacha.pull with the pre-P09 engine (fixed seeds), the exact Markov numbers,
# the 1000-pull journal property test.
#   godot --headless --path game res://scripts/v10/gacha/twgacha_selftest.tscn [-- --mc=0.3]
#   godot --headless --path game res://scripts/v10/gacha/twgacha_selftest.tscn -- --gen_golden=1     prints the pinned fingerprints
# Prints "TWGACHA_SELFTEST ok/total"; exit code 0 when all pass. Never touches G.S or user://.


func _ready() -> void:
	await get_tree().process_frame
	var scale: = 1.0
	var env: = {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--mc="):
			scale = float(a.substr(5))
		elif a == "--gen_golden=1":
			env["gen"] = true
	var r: Array = TWGachaSelftest.run(scale, env)
	get_tree().quit(0 if r[0] == r[1] else 1)
