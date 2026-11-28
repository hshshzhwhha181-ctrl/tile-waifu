extends Control

# Runner for P75 --battle_selftest (AT-B07..AT-B09, AT-B16, single-source balance.json contract).
# Run via godot_lock.ps1:
#   & $env:GODOT_BIN --headless --audio-driver Dummy --path game res://tests/battle/battle_selftest.tscn [-- --runs=400]


func _ready() -> void:
	await get_tree().process_frame
	var runs: int = 400
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--runs="):
			runs = maxi(50, int(arg.substr(7)))
	var r: Dictionary = TWBattleSelftest.run(runs)
	var ok_n: int = int(r.ok)
	var tot_n: int = int(r.total)
	var tag: String = "OK" if ok_n == tot_n else "FAIL"
	print("BATTLE_SELFTEST %d/%d %s" % [ok_n, tot_n, tag])
	get_tree().quit(0 if ok_n == tot_n else 1)
