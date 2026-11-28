extends Node

# Runner of the P17 parity selftest: the corpus replay + layouts + 1000 level certificates on TWBoard (core/rules/parity_selftest.gd)
# and the live fuzz against the real TrayBoard (parity_legacy.gd). Prints "TWPARITY_SELFTEST ok/total"; exit code 0 when all pass.
#   godot --headless --path game res://scripts/v10/rules/parity_selftest.tscn [-- --games_n=500 --levels_n=1000 --fuzz_n=5000]


func _ready() -> void:
	await get_tree().process_frame
	var env: = {"games_n": 500, "levels_n": 1000, "fuzz_n": 5000}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--games_n="):
			env["games_n"] = int(a.substr(10))
		elif a.begins_with("--levels_n="):
			env["levels_n"] = int(a.substr(11))
		elif a.begins_with("--fuzz_n="):
			env["fuzz_n"] = int(a.substr(9))
	TWParitySelftest.begin()
	TWParitySelftest.run_core(env)
	if int(env.fuzz_n) > 0:
		await TWParityLegacy.fuzz(self, int(env.fuzz_n))
	var r: Array = TWParitySelftest.finish()
	get_tree().quit(0 if r[0] == r[1] else 1)
