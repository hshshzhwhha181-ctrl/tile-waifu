class_name V10MjTrayFrame
extends Control

# V10MjTrayFrame — the tray (or hand) frame in the heroine's style (th_data.tray: a, b, trim, well).
# Lacquered rail, inlay line in her trim colour, recessed wells. danger = true warms the LAST free well with
# `ember` (UX §6.2) — the only warning colour; nothing flashes.
#   var tf := V10MjTrayFrame.make(parent, rect, th_data, slots = 7)
#   tf.slot_center(i) -> Vector2         where a tile sits (parent space)
#   tf.set_fill(n)                       filled wells (danger lights up when one free well is left)

const EMBER: = Color("e07a7a")

var th_data: = {}
var slots: = 7
var filled: = 0


static func make(parent: Node, r: Rect2, th: Dictionary, n: = 7) -> V10MjTrayFrame:
	var tf: = V10MjTrayFrame.new()
	tf.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tf.position = r.position
	tf.size = r.size
	tf.th_data = th
	tf.slots = n
	parent.add_child(tf)
	return tf


func well_rect(i: int) -> Rect2:
	var pad: = 14.0
	var w: = (size.x - pad * 2.0) / float(slots)
	return Rect2(Vector2(pad + w * i + 3.0, pad), Vector2(w - 6.0, size.y - pad * 2.0))


func slot_center(i: int) -> Vector2:
	return position + well_rect(i).get_center()


func set_fill(n: int) -> void:
	filled = clampi(n, 0, slots)
	queue_redraw()


func _draw() -> void:
	var tr: Dictionary = th_data.get("tray", {})
	var a: Color = tr.get("a", Color("5a3424"))
	var b: Color = tr.get("b", Color("23120c"))
	var trim: Color = tr.get("trim", Color("e2bd72"))
	var well: Color = tr.get("well", Color("140c0a"))
	var r: = Rect2(Vector2.ZERO, size)
	# soft drop shadow
	draw_style_box(_box(Color(0, 0, 0, 0.35), 14), r.grow(4).grow_individual(0, 0, 0, 6))
	# lacquer rail: two tones for a bevel
	draw_style_box(_box(b, 14), r)
	draw_style_box(_box(a, 12), r.grow(-3).grow_individual(0, 0, 0, -6))
	# inlay line
	var il: = StyleBoxFlat.new()
	il.bg_color = Color(0, 0, 0, 0)
	il.border_color = Color(trim.r, trim.g, trim.b, 0.8)
	il.set_border_width_all(2)
	il.set_corner_radius_all(10)
	draw_style_box(il, r.grow(-7))
	for i in slots:
		var wr: = well_rect(i)
		draw_style_box(_box(well, 6), wr)
		if i == slots - 1 and filled == slots - 1:
			# last free well: a warm ember rim, no fill flash
			var e: = StyleBoxFlat.new()
			e.bg_color = Color(EMBER.r, EMBER.g, EMBER.b, 0.12)
			e.border_color = Color(EMBER.r, EMBER.g, EMBER.b, 0.85)
			e.set_border_width_all(2)
			e.set_corner_radius_all(6)
			draw_style_box(e, wr.grow(-1))
		# inner shadow on the top edge of the well
		draw_rect(Rect2(wr.position + Vector2(4, 0), Vector2(wr.size.x - 8, 4)), Color(0, 0, 0, 0.35))


static func _box(c: Color, rad: int) -> StyleBoxFlat:
	var s: = StyleBoxFlat.new()
	s.bg_color = c
	s.set_corner_radius_all(rad)
	s.anti_aliasing = true
	return s
