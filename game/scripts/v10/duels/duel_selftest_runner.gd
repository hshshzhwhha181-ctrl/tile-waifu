extends Node

# Root of duel_selftest.tscn. Loads the selftest at run time, so a parse error ends the process at once (exit 3)
# instead of leaving an idle headless Godot holding /tmp/tw-godot.lock; a runtime error that stops a coroutine is
# caught by the watchdog (exit 4). Flags: --duel_selftest=1, --duel_calibrate=1, --duel_watchdog=<s>.

func _ready() -> void:
	var s = load("res://scripts/v10/duels/duel_selftest.gd")
	if s == null or not (s as GDScript).can_instantiate():
		print("DUEL_SELFTEST parse error")
		get_tree().quit(3)
		return
	var secs: = 900.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--duel_watchdog="):
			secs = float(a.substr(16))
	get_tree().create_timer(secs, true, false, true).timeout.connect(func():
		print("DUEL_SELFTEST watchdog: no result after %d s (runtime error above?)" % int(secs))
		get_tree().quit(4))
	var n: Node = s.new()
	n.name = "DuelSelftest"
	add_child(n)
