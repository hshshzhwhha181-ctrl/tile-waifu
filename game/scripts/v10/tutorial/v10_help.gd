class_name V10Help
extends RefCounted
# Public facade matching INTEGRATION_0.10.md §2.21:
#   V10Help.open(main, topic = "")                 # "" -> «Как играть» sheet; topic -> contextual «?» sheet
#   V10Help.open_how_to(main)                      # «Как играть» sheet
#   V10Help.help_button(parent, rect, main, topic) # HUD v2 quiet «?» button (80×80 hit zone, ux_role = tertiary)
#   V10Help.on_help(main, topic = "")              # Callable for V10Header.make(..., V10Help.on_help(main, "tables"))
#   V10Help.settings_hook(main, popup)             # Settings «Как играть» row (closes popup first, П-6)
#   V10Help.settings_plate(main, w = 656)          # HUD v2 M-plate row for v2 Settings sheet
#   V10Help.close_all(main)


static func open(host: Node, topic: String = "") -> Control:
	return V10TutHelp.open(host, topic)


static func open_how_to(host: Node) -> Control:
	return V10TutHelp.open_how_to(host)


static func help_button(parent: Control, pos_or_rect = null, host: Node = null, topic: String = "") -> V10Button:
	return V10TutHelp.help_button(parent, pos_or_rect, host, topic)


static func on_help(host: Node, topic: String = "") -> Callable:
	return V10TutHelp.on_help(host, topic)


static func settings_hook(main: Node, p: Control) -> Control:
	return V10TutHelp.settings_hook(main, p)


static func settings_plate(main: Node, w: int = V10TutHelp.ROW_W) -> V10Plate:
	return V10TutHelp.settings_plate(main, w)


static func close_all(host: Node = null) -> void:
	V10TutHelp.close_all(host)


static func locked_toast(host: Node, at: Rect2, text: String) -> void:
	V10TutHelp.locked_toast(host, at, text)


static func topic_for_screen(screen_id: String) -> String:
	return V10TutHelp.topic_for_screen(screen_id)
