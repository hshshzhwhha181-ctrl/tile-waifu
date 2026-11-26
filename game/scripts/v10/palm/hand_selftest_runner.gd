extends Node

# Root of hand_selftest.tscn. Loads the selftest at run time so a parse error ends the process at once (exit 3)
# instead of leaving an idle headless Godot holding /tmp/tw-godot.lock until its timeout. A runtime error stops a
# coroutine without quitting: the watchdog ends the run (exit 4). --hand_watchdog=<s> (default 900).

func _ready() -> void:
	var s = load("res://scripts/v10/palm/hand_selftest.gd")
	if s == null or not (s as GDScript).can_instantiate():
		print("HAND_SELFTEST parse error")
		get_tree().quit(3)
		return
	var secs: = 900.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--hand_watchdog="):
			secs = float(a.substr(16))
	get_tree().create_timer(secs).timeout.connect(func():
		print("HAND_SELFTEST watchdog: no result after %d s (runtime error above?)" % int(secs))
		get_tree().quit(4))
	var n: Node = s.new()
	n.name = "HandSelftest"
	add_child(n)
