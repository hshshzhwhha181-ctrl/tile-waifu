class_name V6HudStyle
extends RefCounted



static func tray(box: RBox, bg: String) -> void :
	var trim_a: = Color("f3dca0")
	var trim_b: = Color("8a6228")
	var body_a: = Color(0.16, 0.14, 0.16, 0.97)
	var body_b: = Color(0.07, 0.06, 0.07, 0.98)
	var th: = _theme(bg)
	if th.has("trim"):
		trim_a = (th.trim as Color).lightened(0.25)
		trim_b = (th.trim as Color).darkened(0.35)
	if th.has("frame_a") and th.has("frame_b"):
		body_a = (th.frame_a as Color).darkened(0.45)
		body_b = (th.frame_b as Color).darkened(0.65)
		body_a.a = 0.97
		body_b.a = 0.98
	box.colors(body_a, body_b).borders(trim_a, trim_b)
	box.set_param("gloss", 0.12)
	box.set_param("pattern", 1.0)
	box.set_param("border", 4.0)


static func slot(sl: RBox, i: int) -> void :
	sl.colors(Color(0.02, 0.015, 0.02, 0.55), Color(0.09, 0.075, 0.085, 0.45))
	sl.borders(Color(0.0, 0.0, 0.0, 0.5), Color(0.95, 0.82, 0.55, 0.35))
	sl.set_param("gloss", 0.0)
	sl.set_param("inner_line", 0.0)
	sl.set_param("grain", 0.5)
	var d: = ColorRect.new()
	d.color = Color(0.95, 0.82, 0.55, 0.13)
	d.size = Vector2(16, 16)
	d.pivot_offset = Vector2(8, 8)
	d.rotation = PI * 0.25
	d.position = sl.size * 0.5 - Vector2(8, 8)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sl.add_child(d)

static func _theme(bg: String) -> Dictionary:
	var path: = "res://scripts/v06/board/board_table.gd"
	if bg == "" or not ResourceLoader.exists(path):
		return {}
	var scr = load(path)
	if scr == null:
		return {}
	if scr.has_method("theme_for"):
		var r = scr.theme_for(bg)
		return r if r is Dictionary else {}
	var c: Dictionary = scr.get_script_constant_map()
	if c.has("THEMES") and (c.THEMES as Dictionary).has(bg):
		return c.THEMES[bg]
	return {}
