class_name V10MjClassicThumb
extends Control

# A form miniature drawn in code from its coordinates (no art files): ivory tiles with a lacquer edge, upper layers
# lighter and offset like the 3D table, the form's colour as a soft light underneath.

var form: = {}
var col: = Color("e8c47e")
var dim: = false


func set_form(f: Dictionary) -> void:
	form = f
	col = f.get("color", col)
	queue_redraw()


func _draw() -> void:
	if form.is_empty():
		return
	var pos: Array = form.pos
	var mn: = Vector2(INF, INF)
	var mx: = Vector2(-INF, -INF)
	var dz: = Vector2(-0.35, -0.6)
	for p in pos:
		var v: Vector2 = Vector2(p.x, p.y) + dz * p.z
		mn = Vector2(minf(mn.x, v.x), minf(mn.y, v.y))
		mx = Vector2(maxf(mx.x, v.x), maxf(mx.y, v.y))
	var span: = (mx - mn) + Vector2(2, 2)
	var s: = minf(size.x / span.x, size.y / span.y) * 0.92
	var off: = (size - span * s) * 0.5 - mn * s
	var glow: = Color(col, 0.16 if not dim else 0.06)
	draw_circle(size * 0.5, minf(size.x, size.y) * 0.46, glow)
	var sorted: Array = pos.duplicate()
	sorted.sort_custom(func(a, b): return a.z * 100000 + a.y * 100 + a.x < b.z * 100000 + b.y * 100 + b.x)
	var cell: = 2.0 * s
	for p in sorted:
		var v: Vector2 = (Vector2(p.x, p.y) + dz * p.z) * s + off
		var r: = Rect2(v + Vector2(0.06, 0.06) * cell, Vector2(cell, cell) * 0.9)
		var edge: = col.darkened(0.45)
		var face: = Color("efe4cf").lerp(Color.WHITE, 0.07 * p.z)
		if dim:
			face = face.darkened(0.55)
			edge = edge.darkened(0.4)
		draw_rect(Rect2(r.position + Vector2(cell * 0.08, cell * 0.12), r.size), edge)
		draw_rect(r, face)
