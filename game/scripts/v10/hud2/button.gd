class_name V10Button
extends TWButton

# V10Button - COMPAT SHIM (P28 / WP9b). The implementation moved to shell/design/tw_button.gd (TWButton, one button API, vector lacquer,
# skins = token overrides). This class keeps the old entry points so the 56 callers render without edits:
#   V10Button.make(kind, text, size), the kinds play/primary/cash/secondary/quiet, .text/.overline/.icon/.icon_px/.icon_color/.btn_size,
#   .breathing/.sheen (no-ops), `pressed`, and the drawing statics rr_pts / grad_cols / lacquer used by plates, journey and tables.
# `primary` is the old name of `play`. Do not add features here: extend TWButton.


static func make(k: String, t: String, sz: Vector2) -> V10Button:
	var b: = V10Button.new()
	b.kind = "play" if k == "primary" else k
	b.btn_size = sz
	b.text = t
	return b


static func rr_pts(r: Rect2, rad: float, segs: = 8) -> PackedVector2Array:
	return TWDraw.rr_pts(r, rad, segs)


static func grad_cols(pts: PackedVector2Array, y0: float, y1: float, stops: Array) -> PackedColorArray:
	return TWDraw.grad_cols(pts, y0, y1, stops)


static func lacquer(ci: CanvasItem, r: Rect2, rad: float, c_top: Color, c_mid: Color, c_bot: Color, rim_a: = 1.0, sheen_col: = V10DS.PAPER_100, sheen_a: = 0.16) -> void:
	TWDraw.lacquer(ci, r, rad, c_top, c_mid, c_bot, rim_a, sheen_col, sheen_a)


# dead since HUD v2 (AI swirl pills were retired); kept only because JButton still calls them with a null texture
static func _hf_tex(_is_buy: bool) -> Texture2D:
	return null


static func draw_hf_pill(_ci: CanvasItem, _tex: Texture2D, _r: Rect2, _src: Rect2, _src_cap: float, _mod: Color) -> void:
	pass
