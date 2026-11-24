class_name V10JuiceShards
extends Node2D

# V10JuiceShards — jade-porcelain shatter of a matched tile pair: N angular shards (ivory face, jade edge, a
# bright bevel line) burst out, spin, fall a little and fade inside ≈ 1.5 tiles. One node, one _draw — no
# node per shard. Lifetime 0.6 s.

const LIFE: = 0.6
const GRAV: = 1300.0

var shards: Array = []   # [pos, vel, rot, spin, poly(PackedVector2Array), col_face, col_edge]
var t: = 0.0
var face: = Color.WHITE
var edge: = Color.WHITE


func start(count: int, size: float, face_col: Color, edge_col: Color) -> void:
	face = face_col
	edge = edge_col
	z_index = 5
	for i in count:
		var ang: = TAU * (float(i) + randf_range(-0.3, 0.3)) / float(count)
		var sp: = randf_range(260.0, 520.0) * size / 84.0
		var vel: = Vector2(cos(ang), sin(ang) * 0.8 - 0.35) * sp
		var r: = randf_range(0.1, 0.2) * size
		var poly: = PackedVector2Array()
		var k: = 3 + randi() % 2
		for j in k:
			var a: = TAU * float(j) / float(k) + randf_range(-0.4, 0.4)
			poly.append(Vector2(cos(a), sin(a)) * r * randf_range(0.6, 1.25))
		var p0: = Vector2(cos(ang), sin(ang)) * size * randf_range(0.05, 0.25)
		shards.append([p0, vel, randf() * TAU, randf_range(-14.0, 14.0), poly, randf() < 0.3])
	queue_redraw()


func _process(dt: float) -> void:
	t += dt
	if t >= LIFE:
		queue_free()
		return
	var damp: = exp(-dt * 3.2)
	for s in shards:
		s[1] = s[1] * damp + Vector2(0, GRAV * dt)
		s[0] = s[0] + s[1] * dt
		s[2] = s[2] + s[3] * dt
	queue_redraw()


func _draw() -> void:
	var k: = t / LIFE
	var a: = 1.0 - k * k
	var sc: = 1.0 - k * 0.35
	for s in shards:
		var poly: PackedVector2Array = s[4]
		var xf: = Transform2D(s[2], s[0]) * Transform2D().scaled(Vector2(sc, sc))
		var pts: = xf * poly
		var jade: bool = s[5]
		var cf: = (edge if jade else face)
		var cols: = PackedColorArray()
		for i in pts.size():
			var c: = cf.lerp(edge, 0.55) if i == 0 else cf
			c.a = a
			cols.append(c)
		draw_polygon(pts, cols)
		# bright bevel on one edge (warm, not white)
		if pts.size() >= 2:
			draw_line(pts[0], pts[1], Color(1.0, 0.95, 0.82, a * 0.8), 1.6, true)
