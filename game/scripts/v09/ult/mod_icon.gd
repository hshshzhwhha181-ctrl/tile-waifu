class_name V9ModIcon
extends Control

# V9ModIcon — the gold glyph of an outfit modifier (V9Ults.MODS: П/О/Л/В/Ц/С), drawn in code in the art-bible glyph
# style (gold stroke, dark lacquer outline), so the badge on the portrait card, the ult chip and the levels row read as
# one icon family instead of a bare Cyrillic letter in a box.
#
#   var ic: = V9ModIcon.make("П", 26.0)     a size×size Control, mouse_filter ignore
#   П hint → light bulb · О open → eye · Л ice → snowflake · В return → curved arrow back · Ц target → target rings
#   С oldest → a tile with a clock face (the oldest tile in the tray)

const GOLD: = Color("ffe7a6")
const GOLD_DEEP: = Color("c58a2c")
const INK: = Color(0.09, 0.03, 0.1, 0.95)

var letter: = ""


static func make(l: String, s: = 26.0) -> V9ModIcon:
	var ic: = V9ModIcon.new()
	ic.letter = l
	ic.size = Vector2(s, s)
	ic.custom_minimum_size = ic.size
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return ic


func _ready() -> void :
	resized.connect(queue_redraw)


func _stroke(pts: PackedVector2Array, w: float, closed: = false) -> void :
	if closed and pts.size() > 2:
		pts.append(pts[0])
	draw_polyline(pts, INK, w + 2.6, true)
	draw_polyline(pts, GOLD, w, true)


func _arc(c: Vector2, r: float, a0: float, a1: float, n: = 24) -> PackedVector2Array:
	var pts: = PackedVector2Array()
	for i in n + 1:
		var a: = lerpf(a0, a1, float(i) / n)
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts


func _dot(c: Vector2, r: float) -> void :
	draw_circle(c, r + 1.3, INK)
	draw_circle(c, r, GOLD)


func _draw() -> void :
	var c: = size * 0.5
	var r: = minf(size.x, size.y) * 0.5 * 0.78
	var w: = maxf(1.6, r * 0.17)
	match letter:
		"П":
			# light bulb: glass, neck, two base bands, three short rays
			var gc: = c + Vector2(0, - r * 0.18)
			_stroke(_arc(gc, r * 0.52, deg_to_rad(135), deg_to_rad(405)), w)
			_stroke(PackedVector2Array([gc + Vector2(- r * 0.36, r * 0.38), gc + Vector2(- r * 0.24, r * 0.72)]), w)
			_stroke(PackedVector2Array([gc + Vector2(r * 0.36, r * 0.38), gc + Vector2(r * 0.24, r * 0.72)]), w)
			_stroke(PackedVector2Array([gc + Vector2(- r * 0.26, r * 0.78), gc + Vector2(r * 0.26, r * 0.78)]), w)
			_stroke(PackedVector2Array([gc + Vector2(- r * 0.16, r * 1.0), gc + Vector2(r * 0.16, r * 1.0)]), w)
			for a in [-150.0, -90.0, -30.0]:
				var d: = Vector2(cos(deg_to_rad(a)), sin(deg_to_rad(a)))
				_stroke(PackedVector2Array([gc + d * r * 0.72, gc + d * r * 0.92]), w * 0.8)
		"О":
			# an open eye: almond lids and a filled iris
			var top: = PackedVector2Array()
			var bot: = PackedVector2Array()
			for i in 17:
				var x: = lerpf(-1.0, 1.0, float(i) / 16.0)
				var y: = (1.0 - x * x) * 0.55
				top.append(c + Vector2(x * r, - y * r))
				bot.append(c + Vector2(x * r, y * r))
			_stroke(top, w)
			_stroke(bot, w)
			_dot(c, r * 0.3)
			draw_circle(c + Vector2(r * 0.1, - r * 0.1), r * 0.09, INK)
		"Л":
			# snowflake: three crossing strokes with small chevrons at each tip
			for k in 3:
				var a: = deg_to_rad(90.0 + k * 60.0)
				var d: = Vector2(cos(a), sin(a))
				_stroke(PackedVector2Array([c - d * r, c + d * r]), w)
				for sgn in [-1.0, 1.0]:
					var tip: Vector2 = c + d * r * 0.62 * sgn
					var n: = d.orthogonal()
					_stroke(PackedVector2Array([tip + n * r * 0.24 + d * r * 0.2 * sgn, tip, tip - n * r * 0.24 + d * r * 0.2 * sgn]), w * 0.75)
		"В":
			# return: an arc that curls back with an arrow head (the tile comes home)
			var ac: = c + Vector2(r * 0.12, r * 0.08)
			var arc: = _arc(ac, r * 0.66, deg_to_rad(-200), deg_to_rad(60))
			_stroke(arc, w)
			var tip: = arc[0]
			_stroke(PackedVector2Array([tip + Vector2(- r * 0.05, - r * 0.42), tip, tip + Vector2(r * 0.4, - r * 0.12)]), w)
		"Ц":
			# target: two rings and a centre dot
			_stroke(_arc(c, r * 0.92, 0.0, TAU, 36), w * 0.85)
			_stroke(_arc(c, r * 0.55, 0.0, TAU, 28), w * 0.85)
			_dot(c, r * 0.18)
		"С":
			# the oldest tile: a tile outline with a small clock face on it
			var tr: = Rect2(c - Vector2(r * 0.7, r * 0.92), Vector2(r * 1.4, r * 1.84))
			_stroke(PackedVector2Array([tr.position, Vector2(tr.end.x, tr.position.y), tr.end, Vector2(tr.position.x, tr.end.y)]), w, true)
			var cc: = c + Vector2(0, r * 0.05)
			_stroke(_arc(cc, r * 0.42, 0.0, TAU, 24), w * 0.8)
			_stroke(PackedVector2Array([cc + Vector2(0, - r * 0.28), cc, cc + Vector2(r * 0.22, r * 0.1)]), w * 0.8)
		_:
			_dot(c, r * 0.3)
