class_name V10PairFx
extends Node2D

# V10PairFx — the kit accent's pair particles (D3): petals (МТ), tea leaves (Рин), sparks (Хана), moon dust (Юэ),
# glitch (Нова), firebird feathers (Злата), pearls, frost, embers. Procedural (no per-particle nodes, one _draw),
# capped by fx level: full 18, mid 8, min 0 (spec D3). Never white: every colour is the accent or its glow.
#
#   V10PairFx.burst(parent, pos, look_dict)   -> V10PairFx or null (fx «минимум»)
#   V10PairFx.cap(level) -> int

const CAP: = {"full": 18, "mid": 8, "min": 0}
const LIFE: = 0.9
const FEATHER: = "res://assets/v10/look/zlata/feather_tile.png"

var kind: = "petals"
var col: = Color.WHITE
var glow: = Color.WHITE
var parts: = []
var t: = 0.0
var _feather: Texture2D

static var live_count: = 0


static func cap(level: String) -> int:
	return int(CAP.get(level, 18))


static func burst(parent: Node, pos: Vector2, lk: Dictionary, level: = "") -> V10PairFx:
	if level == "":
		level = V9Feel.level() if Engine.get_main_loop() and (Engine.get_main_loop() as SceneTree).root.get_node_or_null("G") else "full"
	var n: = cap(level)
	if n <= 0 or parent == null:
		return null
	var fx: = V10PairFx.new()
	fx.kind = String(lk.get("particles", "petals"))
	var ac: Color = lk.get("accent", Color("ff8fb8"))
	fx.col = ac
	fx.glow = ac.lightened(0.35)
	fx.position = pos
	fx.z_index = 20
	fx._seed(n)
	parent.add_child(fx)
	return fx


func _seed(n: int) -> void:
	var rng: = RandomNumberGenerator.new()
	rng.randomize()
	if kind == "feathers":
		_feather = load(FEATHER) if ResourceLoader.exists(FEATHER) else null
	for i in n:
		var a: = rng.randf() * TAU
		var sp: = rng.randf_range(80.0, 240.0)
		var v: = Vector2(cos(a), sin(a)) * sp
		match kind:
			"embers", "sparks":
				v.y -= 90.0
			"petals", "leaves", "feathers":
				v *= 0.7
			"dust", "pearls":
				v *= 0.5
		parts.append({"p": Vector2.ZERO, "v": v, "r": rng.randf() * TAU, "w": rng.randf_range(-6.0, 6.0),
			"s": rng.randf_range(0.6, 1.25), "d": rng.randf_range(0.0, 0.12)})


func _ready() -> void:
	live_count += 1


func _exit_tree() -> void:
	live_count -= 1


func _process(dt: float) -> void:
	t += dt
	if t >= LIFE + 0.15:
		queue_free()
		return
	for q in parts:
		if t < q.d:
			continue
		var drag: = 2.2 if kind in ["petals", "leaves", "feathers", "dust"] else 1.4
		q.v *= exp(-drag * dt)
		match kind:
			"petals", "leaves", "feathers":
				q.v.y += 140.0 * dt
				q.v.x += sin(t * 6.0 + q.r) * 40.0 * dt
			"embers":
				q.v.y -= 60.0 * dt
			"pearls", "frost":
				q.v.y += 60.0 * dt
		q.p += q.v * dt
		q.r += q.w * dt
	queue_redraw()


func _draw() -> void:
	for q in parts:
		if t < q.d:
			continue
		var k: float = clampf((t - q.d) / LIFE, 0.0, 1.0)
		var a: = (1.0 - k) * (1.0 - k) * 0.95
		var s: float = q.s * (1.0 - 0.3 * k)
		draw_set_transform(q.p, q.r, Vector2(s, s))
		match kind:
			"petals":
				draw_colored_polygon(_ellipse(7.0, 4.0), Color(col, a))
				draw_colored_polygon(_ellipse(3.0, 1.6), Color(glow, a * 0.8))
			"leaves":
				draw_colored_polygon(PackedVector2Array([Vector2(-8, 0), Vector2(0, -3.5), Vector2(8, 0), Vector2(0, 3.5)]), Color(col, a))
				draw_line(Vector2(-7, 0), Vector2(7, 0), Color(col.darkened(0.35), a), 1.0, true)
			"sparks", "embers":
				draw_colored_polygon(PackedVector2Array([Vector2(0, -6), Vector2(1.6, 0), Vector2(0, 6), Vector2(-1.6, 0)]), Color(glow, a))
				draw_circle(Vector2.ZERO, 2.0, Color(col, a), true, -1.0, true)
			"dust":
				draw_circle(Vector2.ZERO, 4.0, Color(col, a * 0.35), true, -1.0, true)
				draw_circle(Vector2.ZERO, 1.6, Color(glow, a), true, -1.0, true)
			"glitch":
				var w: = 10.0 if int(q.r * 10.0) % 2 == 0 else 5.0
				draw_rect(Rect2(-w * 0.5, -1.5, w, 3.0), Color(col if int(q.r * 7.0) % 2 == 0 else Color("ff6fd8"), a))
			"feathers":
				if _feather:
					var fh: = 26.0
					var fw: = fh * _feather.get_width() / _feather.get_height()
					draw_texture_rect(_feather, Rect2(-fw * 0.5, -fh * 0.5, fw, fh), false, Color(1, 1, 1, a))
				else:
					draw_colored_polygon(_ellipse(9.0, 3.0), Color(col, a))
			"pearls":
				draw_circle(Vector2.ZERO, 4.0, Color(glow, a), true, -1.0, true)
				draw_circle(Vector2(-1.2, -1.2), 1.3, Color(1, 1, 1, a * 0.7), true, -1.0, true)
			"frost":
				for i in 3:
					var d: = Vector2.from_angle(i * PI / 3.0) * 6.0
					draw_line(-d, d, Color(glow, a), 1.2, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _ellipse(rx: float, ry: float) -> PackedVector2Array:
	var pts: = PackedVector2Array()
	for i in 10:
		var a: = TAU * i / 10.0
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	return pts
