class_name V10LookBoard
extends Control

# V10LookBoard — a live mini board for previews (tile picker 3×2, style picker, banner «Примерить стиль», shots):
# real Tile nodes dressed by V6TileLook + V10TileTheme on a v10 table. Not a playable board.
#
#   V10LookBoard.make(theme_id, table_id, rect, opts) -> V10LookBoard
#     opts: cols (3), rows (2), faces (Array, defaults to the theme's signature first), ranked (false), scale (auto),
#           layers (1, a second layer offsets like a real stack), burst (false: one accent particle burst)

var theme_id: = "s_sakura"
var table_id: = ""
var tiles: = []
var layer: Node2D
var table_cr: ColorRect


static func make(th: String, tb: String, rect: Rect2, opts: = {}) -> V10LookBoard:
	var b: = V10LookBoard.new()
	b.theme_id = th
	b.table_id = tb
	b.position = rect.position
	b.size = rect.size
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b._build(opts)
	return b


func _build(opts: Dictionary) -> void:
	var cols: = int(opts.get("cols", 3))
	var rows: = int(opts.get("rows", 2))
	var ranked: = bool(opts.get("ranked", false))
	var pad: = float(opts.get("pad", 22.0))
	if table_id != "":
		table_cr = V10TileTheme.table_rect(table_id, Rect2(Vector2.ZERO, size), {"static": ranked, "frame_w": float(opts.get("frame_w", 16.0)), "radius": float(opts.get("radius", 18.0))})
		add_child(table_cr)
		var th: = V10TileTheme.table(table_id)
		V6TileLook.lamp_col = th.lamp_col
		V6TileLook.gloss = th.gloss
		V6TileLook.ambient = th.ambient
		V6TileLook.shadow_col = th.shadow
	else:
		var bg: = ColorRect.new()
		bg.color = Color("1c4a3b")
		bg.size = size
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bg)
	clip_contents = false
	layer = Node2D.new()
	add_child(layer)
	var tw: = Tile.TW
	var th_: = Tile.TH
	var avail: = size - Vector2(pad, pad) * 2.0
	var sc: float = opts.get("scale", minf(avail.x / (cols * tw + 6.0), avail.y / (rows * th_ * 0.92 + 10.0)))
	layer.scale = Vector2(sc, sc)
	var grid_w: = cols * tw
	var grid_h: = rows * th_ * 0.92
	layer.position = (size - Vector2(grid_w, grid_h) * sc) * 0.5
	V6TileLook.lamp = global_position + size * Vector2(0.33, 0.1)
	var lk: = V10TileTheme.look(theme_id, {"ranked": ranked})
	var faces: Array = opts.get("faces", [])
	if faces.is_empty():
		var sig: = int(lk.sig)
		faces = [sig, 7, 0, 21, sig, 24, 33, 12, 3, 25, 9, 11]
	var k: = 0
	for y in rows:
		for x in cols:
			var t: = Tile.new()
			t.face = int(faces[k % faces.size()])
			t.gx = x
			t.gy = y
			t.gz = 0
			t.position = Vector2(x * tw + tw * 0.5, y * th_ * 0.92 + th_ * 0.5)
			layer.add_child(t)
			t.build(lk)
			V10TileTheme.dress(t)
			tiles.append(t)
			k += 1
	V10TileTheme.relight()
	if bool(opts.get("burst", false)) and tiles.size() > 1:
		V10PairFx.burst(layer, tiles[0].position + Vector2(tw * 0.5, 0), lk, "full")
