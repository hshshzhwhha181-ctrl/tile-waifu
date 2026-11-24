class_name V10BdaySigDecor
extends RefCounted

# Visual tile swap for heroine birthdays (Р6). The board keeps every face id; the integrator calls apply() for
# tiles whose face is in V10Bday.sig_overlay(cfg).faces (unranked only). The emblem is drawn ON TOP of the tile's
# face art (a child node), so taps, matching, hashes, bots and challenge codes are untouched.
#   V10BdaySigDecor.apply(tile: CanvasItem, icon_path, face_rect: Rect2) -> TextureRect
#   V10BdaySigDecor.remove(tile)
# face_rect is the face area in the tile's local coordinates (tile.gd draws its face there).
# The two overlaid kinds use ov.icons[0] (her emblem) and ov.icons[1] (her cake) so they never look alike:
#   V10BdaySigDecor.icon_for(ov, face) -> path

const META: = "v10_bday_sig"


static func apply(tile: CanvasItem, icon_path: String, face_rect: Rect2) -> TextureRect:
	remove(tile)
	var t: = TextureRect.new()
	t.texture = load(icon_path) if ResourceLoader.exists(icon_path) else null
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var inset: = face_rect.size * 0.06
	t.position = face_rect.position + inset
	t.size = face_rect.size - inset * 2
	t.pivot_offset = t.size * 0.5
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.name = "BdaySig"
	tile.add_child(t)
	tile.set_meta(META, t)
	return t


static func icon_for(ov: Dictionary, face: int) -> String:
	var i: = (ov.get("faces", []) as Array).find(face)
	if i < 0:
		return ""
	var icons: Array = ov.get("icons", [ov.get("icon", "")])
	return str(icons[mini(i, icons.size() - 1)])


static func remove(tile: CanvasItem) -> void:
	if tile.has_meta(META):
		var n = tile.get_meta(META)
		if is_instance_valid(n):
			n.queue_free()
		tile.remove_meta(META)
