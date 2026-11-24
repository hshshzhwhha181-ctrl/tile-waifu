extends Node

# Loads the levels scripts at runtime so a compile error prints a FAIL line and quits instead of hanging headless.

const PARTS: = ["res://scripts/v10/levels/level_sim.gd", "res://scripts/v10/levels/level_gen.gd",
	"res://scripts/v10/levels/level_board.gd", "res://scripts/v10/levels/levels_selftest.gd"]


func _ready() -> void :
	var s: Script = null
	for p in PARTS:
		s = load(p)
		if s == null or not s.can_instantiate():
			print("LEVELS SELFTEST FAIL: %s does not compile" % p)
			get_tree().quit(1)
			return
	var n: = Node.new()
	n.set_script(s)
	add_child(n)
