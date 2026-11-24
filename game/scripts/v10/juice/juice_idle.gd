class_name V10JuiceIdle
extends Control

# V10JuiceIdle — «дорогая» idle life on a premium button (buy / summon / pass): a sheen crosses it every
# `every` × 2 s (juice_sweep_rr, clipped to the button's rounded corners) and 1–2 four-point twinkles pop on its
# corners in between. Sleeps while the button is hidden. «умеренные»: twinkles only half as often, no sheen.
# Added as the button's child (covers its rect, ignores the mouse). Free it to stop.

var target: Control
var color: = Color(1, 0.8, 0.4)
var every: = 2.8
var t_star: = 0.6
var t_sheen: = 1.2
var sheen: ColorRect
var sheen_t: = -1.0
var stars: Array = []   # [sprite, age, life]


func setup(tgt: Control, c: Color, e: float, radius: float) -> void:
	target = tgt
	color = c
	every = e
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = tgt.size
	t_star = randf_range(0.3, e)
	t_sheen = randf_range(0.6, 1.4)
	sheen = ColorRect.new()
	sheen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheen.size = tgt.size
	sheen.material = V10Juice.mat("juice_sweep_rr", {"color": Color(1.0, 0.9, 0.7, 0.42), "pos": -0.4, "size": tgt.size, "radius": radius})
	sheen.visible = false
	add_child(sheen)


func _process(dt: float) -> void:
	if target == null or not is_instance_valid(target):
		queue_free()
		return
	if not V10Juice.can_fx() or not target.is_visible_in_tree():
		return
	size = target.size
	var full: = V10Juice.level() == "full"
	t_star -= dt
	if t_star <= 0.0:
		t_star = every * randf_range(0.5, 0.9) * (1.0 if full else 2.0)
		_spawn_star()
		if full and randf() < 0.5:
			_spawn_star()
	if full:
		t_sheen -= dt
		if t_sheen <= 0.0 and sheen_t < 0.0:
			t_sheen = every * 2.0
			sheen_t = 0.0
			sheen.visible = true
			sheen.size = size
			V10Juice.param(sheen, "size", size)
	if sheen_t >= 0.0:
		sheen_t += dt
		var u: = sheen_t / 0.75
		V10Juice.param(sheen, "pos", lerpf(-0.4, 1.4, u * u * (3.0 - 2.0 * u)))
		if u >= 1.0:
			sheen_t = -1.0
			sheen.visible = false
	for i in range(stars.size() - 1, -1, -1):
		var s: Array = stars[i]
		var spr: Sprite2D = s[0]
		s[1] += dt
		var k: float = s[1] / s[2]
		if k >= 1.0:
			spr.queue_free()
			stars.remove_at(i)
			continue
		var sc: float = sin(k * PI) * s[3]
		spr.scale = Vector2(sc, sc)
		spr.rotation += dt * 1.6


func _spawn_star() -> void:
	if stars.size() >= 4:
		return
	var spr: = Sprite2D.new()
	spr.texture = V10JuiceTex.get_tex("star4")
	spr.material = V10Juice.add_mat()
	spr.modulate = Color(color.r, color.g, color.b, 0.9)
	# on a corner or along the top edge, slightly inside
	var corners: = [Vector2(0.08, 0.15), Vector2(0.92, 0.15), Vector2(0.9, 0.85), Vector2(0.1, 0.82), Vector2(randf_range(0.2, 0.8), 0.08)]
	var c: Vector2 = corners[randi() % corners.size()]
	spr.position = size * c + Vector2(randf_range(-6, 6), randf_range(-6, 6))
	spr.scale = Vector2.ZERO
	add_child(spr)
	stars.append([spr, 0.0, randf_range(0.55, 0.85), randf_range(0.35, 0.6)])
