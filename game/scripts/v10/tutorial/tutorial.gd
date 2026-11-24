class_name V10Tutorial
extends Node
# SKELETON (API per README §2.6) — the implementation pass replaces the bodies.

static var inst: V10Tutorial
var main: Node


static func attach(m: Node) -> V10Tutorial:
	if inst != null and is_instance_valid(inst):
		return inst
	inst = V10Tutorial.new()
	inst.name = "V10Tutorial"
	inst.main = m
	m.add_child(inst)
	return inst


static func main_node() -> Node:
	return inst.main if inst != null and is_instance_valid(inst) else null


static func owns_first_match() -> bool:
	return inst != null and is_instance_valid(inst)


static func is_open(id: String) -> bool:
	return V10Reveal.is_open(id)


static func locked_tap(id: String, at) -> void:
	pass


static func help(screen_id: = "") -> void:
	pass


static func how_to() -> void:
	pass


static func say(line: String, target_id: = "", opts: = {}) -> void:
	pass


static func event(ev_name: String, data: = {}) -> void:
	pass


static func replay(intro_id: String) -> void:
	V10TutState.unmark(intro_id)


static func skip_all() -> void:
	V10TutState.skip()


static func busy() -> bool:
	return false
