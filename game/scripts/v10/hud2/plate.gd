class_name V10Plate
extends TWPlate

# V10Plate - COMPAT SHIM (P28 / WP9b). The implementation moved to shell/design/tw_plate.gd (TWPlate). Same constructor, same properties
# (size_class, plate_w, title, subtitle, value, icon, icon_tex, on_art, selected, disabled, focused, interactive, right_slot, ping()),
# same statics (height_of, draw_surface, hairline). Do not add features here: extend TWPlate.


static func make(sc: String, w: int, t: = "", sub: = "", val: = "", icon_name: = "") -> V10Plate:
	var p: = V10Plate.new()
	p.size_class = sc
	p.plate_w = w
	p.title = t
	p.subtitle = sub
	p.value = val
	p.icon = icon_name
	return p


static func draw_surface(ci: CanvasItem, r: Rect2, over_art: = true, down: = false, sel: = false, dis: = false, foc: = false, flash: = -1.0, fill_override: = Color.TRANSPARENT) -> void:
	TWDraw.plate_surface(ci, r, over_art, down, sel, dis, foc, flash, fill_override)


static func hairline(ci: CanvasItem, x0: float, x1: float, y: float, col: Color) -> void:
	TWDraw.hairline(ci, x0, x1, y, col)
