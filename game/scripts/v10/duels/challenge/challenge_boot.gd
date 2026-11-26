extends Node

# Root of challenge_demo.tscn and challenge_selftest.tscn: loads the module scripts one by one, so a compile error
# prints «CHALLENGE_SELFTEST parse error» and quits (exit 3) instead of leaving an idle Godot holding the lock;
# a runtime error that stops a coroutine is caught by the watchdog (exit 4). Then hands over to the selftest
# (--challenge_selftest=1) or the demo runner (everything else).

const ROOT: = "res://scripts/v10/duels/challenge/"
const PARTS: = ["challenge_util", "challenge_code", "challenge_deal", "challenge_state", "challenge_ui", "challenge_poster",
	"challenge_screen", "challenge_run", "challenge_play", "challenge_selftest", "challenge_demo"]


func _ready() -> void:
	var bad: = []
	for p in PARTS:
		var s = load(ROOT + p + ".gd")
		if s == null or not (s as GDScript).can_instantiate():
			bad.append(p)
	if not bad.is_empty():
		print("CHALLENGE_SELFTEST parse error: %s" % ", ".join(bad))
		get_tree().quit(3)
		return
	var secs: = 900.0
	var test: = false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--challenge_watchdog="):
			secs = float(a.substr(21))
		if a.begins_with("--challenge_selftest="):
			test = true
	get_tree().create_timer(secs).timeout.connect(func():
		print("CHALLENGE_SELFTEST watchdog: no result after %d s (runtime error above?)" % int(secs))
		get_tree().quit(4))
	var n: = Node.new()
	n.name = "ChallengeSelftest" if test else "ChallengeDemo"
	n.set_script(load(ROOT + ("challenge_selftest.gd" if test else "challenge_demo.gd")))
	add_child(n)
