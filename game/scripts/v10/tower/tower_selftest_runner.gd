extends Node

# Root of tower_selftest.tscn. Loads the selftest at run time so a parse error ends the process at once
# (exit 3) instead of leaving an idle headless Godot holding /tmp/tw-godot.lock until its timeout.

var _secs: = 600.0
var _elapsed: = 0.0

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tower_watchdog="):
			_secs = float(a.substr(17))
	_boot.call_deferred()

func _boot() -> void:
	var s = load("res://scripts/v10/tower/tower_selftest.gd")
	if s == null or not (s as GDScript).can_instantiate():
		print("TOWER_SELFTEST parse error")
		get_tree().quit(3)
		return
	var n: Node = s.new()
	n.name = "TowerSelftest"
	add_child(n)

func _process(delta: float) -> void:
	_elapsed += delta / maxf(0.001, Engine.time_scale)
	if _elapsed >= _secs:
		set_process(false)
		print("TOWER_SELFTEST watchdog: no result after %d s (runtime error above?)" % int(_secs))
		get_tree().quit(4)
