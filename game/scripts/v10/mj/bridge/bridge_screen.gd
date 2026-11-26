class_name V10MjBridgeScreen
extends Control

# Единая точка входа экрана «Моста к столу» (docs/MODES.md §4.5, §7.1):
#   args.variant == "daily" | args.mode == "bridge_daily" -> V10MjBridgeDailyScreen
#   иначе -> V10MjBridgeHandScreen

signal finished(result: Dictionary)

var child_screen: Control


func build(m, a: Dictionary = {}) -> void:
	setup(m, a)


func setup(m, a: Dictionary = {}) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in get_children():
		c.queue_free()
	var v: = String(a.get("variant", a.get("mode", "hand")))
	if v == "daily" or v == "bridge_daily" or a.has("day") or a.has("item"):
		child_screen = V10MjBridgeDailyScreen.new()
	else:
		child_screen = V10MjBridgeHandScreen.new()
	add_child(child_screen)
	child_screen.finished.connect(func(r: Dictionary): finished.emit(r))
	child_screen.call("setup", m, a)
