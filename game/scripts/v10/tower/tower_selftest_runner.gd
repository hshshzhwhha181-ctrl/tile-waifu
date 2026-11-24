extends Node

# Root of tower_selftest.tscn. Loads the selftest at run time so a parse error ends the process at once
# (exit 3) instead of leaving an idle headless Godot holding /tmp/tw-godot.lock until its timeout.

func _ready() -> void:
	var s = load("res://scripts/v10/tower/tower_selftest.gd")
	if s == null or not (s as GDScript).can_instantiate():
		print("TOWER_SELFTEST parse error")
		get_tree().quit(3)
		return
	# a runtime error stops a coroutine without quitting: the watchdog ends the run (exit 4)
	var secs: = 600.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tower_watchdog="):
			secs = float(a.substr(17))
	get_tree().create_timer(secs).timeout.connect(func():
		print("TOWER_SELFTEST watchdog: no result after %d s (runtime error above?)" % int(secs))
		get_tree().quit(4))
	var n: Node = s.new()
	n.name = "TowerSelftest"
	add_child(n)
