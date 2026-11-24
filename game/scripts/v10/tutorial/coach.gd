class_name V10Coach
extends Control
# SKELETON (API per README §2.4) — the implementation pass replaces the bodies.

signal finished(result: String)

const LAYER: = 92

var spec: = {}
var _showing: = false
var _hole: = Rect2()


static func layer(host: Node) -> CanvasLayer:
	var root: = host.get_tree().root if host != null and host.is_inside_tree() else null
	if root == null:
		return null
	var l: = root.get_node_or_null("V10TutLayer") as CanvasLayer
	if l == null:
		l = CanvasLayer.new()
		l.name = "V10TutLayer"
		l.layer = LAYER
		l.process_mode = Node.PROCESS_MODE_ALWAYS
		root.add_child(l)
	return l


func show_step(s: Dictionary) -> void:
	spec = s
	_showing = true


func complete(result: = "target") -> void:
	if not _showing:
		return
	_showing = false
	finished.emit(result)


func is_showing() -> bool:
	return _showing


func current_rect() -> Rect2:
	return _hole
