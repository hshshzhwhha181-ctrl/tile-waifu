class_name V6LayoutPreview
extends Control



var pos: Array = []
var accent: = Color("ff9cc0")
var _box: StyleBoxFlat
var _side: StyleBoxFlat
var _t: = 0.0
# 0.8: tiles are drawn with the real tile-back art (assets/v06/flip/tile_back.png, ivory-tinted per layer) on a
# coloured side, so the preview on the level card reads as the board's tiles, not blank cream rectangles
var _back: Texture2D = preload("res://assets/v06/flip/tile_back.png")

func setup(cfg: Dictionary, acc: Color) -> void :
	pos = TWFree.gen_layout(cfg)
	accent = acc
	_box = StyleBoxFlat.new()
	_side = StyleBoxFlat.new()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func _process(dt: float) -> void :

	if _t < 2.0:
		_t += dt
		queue_redraw()

func _draw() -> void :
	if pos.is_empty():
		return
	var minx: = 999
	var miny: = 999
	var maxx: = -999
	var maxy: = -999
	var maxz: = 0
	for p in pos:
		minx = mini(minx, p.x)
		miny = mini(miny, p.y)
		maxx = maxi(maxx, p.x)
		maxy = maxi(maxy, p.y)
		maxz = maxi(maxz, p.z)
	var gw: = float(maxx - minx + 2)
	var gh: = float(maxy - miny + 2)

	var dz: = Vector2(-0.18, -0.36)
	var cw: float = min(size.x / (gw + absf(dz.x) * maxz), size.y / (gh * 1.18 + absf(dz.y) * maxz))
	var ch: = cw * 1.18
	var tw: = cw * 2.0 - 2.0
	var th: = ch * 2.0 - 2.0
	var total: = Vector2(gw * cw + absf(dz.x) * cw * maxz, gh * ch + absf(dz.y) * cw * maxz)
	var off: = (size - total) * 0.5 + Vector2(absf(dz.x) * cw * maxz, absf(dz.y) * cw * maxz)
	var sorted: = pos.duplicate()
	sorted.sort_custom( func(a, b): return a.z * 100000 + a.y * 100 + a.x < b.z * 100000 + b.y * 100 + b.x)
	for p in sorted:
		var appear: float = clampf((_t * 3.0 - p.z * 0.35), 0.0, 1.0)
		if appear <= 0.0:
			continue
		var o: Vector2 = off + Vector2((p.x - minx) * cw, (p.y - miny) * ch) + Vector2(dz.x, dz.y) * cw * p.z
		o.y -= (1.0 - appear) * 10.0
		var k: float = float(p.z) / max(1, maxz)
		var face: = Color("e6d6bd").lerp(Color("fff8ea"), 0.35 + k * 0.65)
		var side: = accent.darkened(0.45 - k * 0.2)
		side.a = appear
		face.a = appear
		_side.bg_color = side
		_side.set_corner_radius_all(int(max(2.0, tw * 0.16)))
		draw_style_box(_side, Rect2(o + Vector2(tw * 0.06, th * 0.14), Vector2(tw, th)))
		draw_texture_rect(_back, Rect2(o, Vector2(tw, th)), false, face)
