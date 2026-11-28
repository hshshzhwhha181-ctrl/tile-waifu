extends Node

# Boot of path_demo.tscn: loads the Path scripts one by one so a compile error prints «PATH SELFTEST FAIL» and quits
# instead of hanging a headless run; then hands over to path_runner.gd.

const CORE_PARTS: = ["path_rules", "path_state", "path_jam"]  # UI-free parts live in res://core/path (WP3)
const PARTS: = ["path_rules", "path_state", "path_boosters", "path_jam", "path_node", "path_fx", "path_dialogs",
	"path_card", "path_map", "path_selftest", "path_runner"]


func _ready() -> void:
	var s: Script = null
	var bad: = []
	for p in PARTS:
		s = load(("res://core/path/%s.gd" if p in CORE_PARTS else "res://scripts/v10/path/%s.gd") % p)
		if s == null or not s.can_instantiate():
			bad.append(p)
	if not bad.is_empty():
		print("PATH SELFTEST FAIL: does not compile: %s" % ", ".join(bad))
		get_tree().quit(1)
		return
	var n: = Node.new()
	n.set_script(s)
	add_child(n)
