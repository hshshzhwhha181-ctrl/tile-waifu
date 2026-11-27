class_name V10SalonTag
extends Control

# A jewel-like lacquer tag hanging on a single golden silk thread over an unrestored task: «Вывеска · 3★» (spec §Р1 п.3).
# Sways from the scroll (impulse()) and settles; when the bank covers the cost it glows with champagne gold and
# hops ONCE (when it becomes affordable / the map opens). No endless hop, pulse or idle sway: the interface is
# still, the only endless UI motion on the screen is the main button's breath (UX_RULES §2.10, §6.7; HUD_V2 §6).
# `hint` draws an elegant double pulsing gold halo around the plaque and a subtle beacon at the diamond pin.

signal tapped(tid: String)

const H: = 48.0
const THREAD: = 30.0
const FS: = 18  # Caption 18 (UX §6.3)

var tid: = ""
var title: = ""
var cost: = 0
var affordable: = false:
	set(v):
		if v != affordable:
			affordable = v
			if v:
				_hop_t = 0.0
			queue_redraw()
var hint: = false
var _rot: = 0.0
var _rv: = 0.0
var _t: = 0.0
var _hop: = 0.0
var _hop_t: = -1.0  # ≥ 0 while the one-shot hop plays
var _w: = 160.0
var _press: = false
var pin: = Vector2.ZERO  # local point where the thread is pinned (the object); the plaque may be pushed aside


static func make(tid_: String, title_: String, cost_: int) -> V10SalonTag:
	var t: = V10SalonTag.new()
	t.tid = tid_
	t.title = title_
	t.cost = cost_
	t.mouse_filter = Control.MOUSE_FILTER_STOP
	var f: = V10SalonUI.font("body", 800)
	t._w = f.get_string_size("%s · %d" % [title_, cost_], HORIZONTAL_ALIGNMENT_LEFT, -1, FS).x + 56.0
	# hit zone ≥ 80 px tall (UX §6.1); the plaque itself is 48
	t.size = Vector2(maxf(t._w, 96.0), maxf(80.0, THREAD + H + 12.0))
	t.pivot_offset = Vector2(t.size.x * 0.5, 0)
	t.pin = Vector2(t.size.x * 0.5, 0)
	t._t = randf() * 3.0
	return t


# anchor = where the thread is pinned (on the object); top_left = where the control goes (after de-overlap)
func place(anchor: Vector2, top_left: = Vector2.INF) -> void:
	position = anchor - Vector2(size.x * 0.5, 0) if top_left == Vector2.INF else top_left
	pin = anchor - position
	pivot_offset = pin


func plaque_rect() -> Rect2:
	return Rect2(position + Vector2(size.x * 0.5 - _w * 0.5, THREAD), Vector2(_w, H))


func impulse(v: float) -> void:
	_rv += clampf(v, -900.0, 900.0) * 0.0009


func _process(dt: float) -> void:
	_t += dt
	# damped spring on the sway angle (scroll impulses only; at rest the tag hangs still)
	var k: = 40.0
	var c: = 4.2
	_rv += (-k * _rot - c * _rv) * dt
	_rot += _rv * dt
	if absf(_rot) < 0.0005 and absf(_rv) < 0.0005:
		_rot = 0.0
		_rv = 0.0
	rotation = clampf(_rot, -0.35, 0.35)
	var moving: = _rot != 0.0
	# the one-shot hop (0.45 s) when the tag turns affordable
	if _hop_t >= 0.0:
		_hop_t += dt
		_hop = -10.0 * sin(clampf(_hop_t / 0.45, 0.0, 1.0) * PI) if V10SalonUI.can_fx() else 0.0
		if _hop_t >= 0.45:
			_hop_t = -1.0
			_hop = 0.0
		moving = true
	if moving or hint:
		queue_redraw()


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_press = true
			V9Feel.press_down(self)
			accept_event()
		elif _press:
			_press = false
			var inside: = Rect2(Vector2.ZERO, size).has_point(e.position)
			V9Feel.press_up(self, inside, "pop")
			accept_event()
			if inside:
				tapped.emit(tid)


static func _rr_pts(r: Rect2, rad: float, segs: = 8) -> PackedVector2Array:
	var rr: = clampf(rad, 0.0, minf(r.size.x, r.size.y) * 0.5)
	var pts: = PackedVector2Array()
	var corners: = [
		[Vector2(r.end.x - rr, r.position.y + rr), -PI * 0.5, 0.0],
		[Vector2(r.end.x - rr, r.end.y - rr), 0.0, PI * 0.5],
		[Vector2(r.position.x + rr, r.end.y - rr), PI * 0.5, PI],
		[Vector2(r.position.x + rr, r.position.y + rr), PI, PI * 1.5],
	]
	for c in corners:
		var ctr: Vector2 = c[0]
		var a0: float = c[1]
		var a1: float = c[2]
		for i in segs + 1:
			var a: = lerpf(a0, a1, float(i) / float(segs))
			pts.append(ctr + Vector2(cos(a), sin(a)) * rr)
	return pts


func _draw_diamond(c: Vector2, rad: float, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(0.0, -rad), c + Vector2(rad, 0.0), c + Vector2(0.0, rad), c + Vector2(-rad, 0.0),
	]), col)


func _draw_hairline(x0: float, x1: float, y: float, col: Color) -> void:
	var f: = minf(20.0, (x1 - x0) * 0.3)
	var c0: = Color(col, 0.0)
	draw_polyline_colors(
		PackedVector2Array([Vector2(x0, y), Vector2(x0 + f, y), Vector2(x1 - f, y), Vector2(x1, y)]),
		PackedColorArray([c0, col, col, c0]), 1.0, true)


func _draw() -> void:
	var cx: = size.x * 0.5
	var top: = THREAD + _hop
	var r: = Rect2(cx - _w * 0.5, top, _w, H)
	var crown: = Vector2(cx, top)
	var rad: = 8.0

	# Single refined golden silk thread (1px hairline) from the pin on the object to the plaque crown
	var thread_pin_col: = Color(V10SalonUI.GOLD_500, 0.88 if affordable else 0.58)
	var thread_top_col: = Color(V10SalonUI.GOLD_300, 0.94 if affordable else 0.72)
	draw_polyline_colors(PackedVector2Array([pin, crown]), PackedColorArray([thread_pin_col, thread_top_col]), 1.0, true)

	# Crisp 5px glowing gold diamond pin on the object
	draw_circle(pin, 9.5, Color(V10SalonUI.GOLD_300, 0.28 if affordable else 0.16), true, -1.0, true)
	_draw_diamond(pin, 5.0, V10SalonUI.GOLD_300 if affordable else V10SalonUI.GOLD_500)
	_draw_diamond(pin, 2.2, V10SalonUI.PAPER_100)

	# Hint: soft double pulsing gold halo around the plaque + subtle gold beacon at the pin
	if hint:
		var pp: = fmod(_t, 1.6) / 1.6
		draw_arc(pin, 6.0 + 14.0 * pp, 0.0, TAU, 32, Color(V10SalonUI.GOLD_300, 0.85 * (1.0 - pp)), 1.6, true)
		draw_circle(pin, 12.0, Color(V10SalonUI.GOLD_300, 0.22 * (1.0 - pp)), true, -1.0, true)
		for phase in [0.0, 0.5]:
			var hp: = fmod(_t / 1.9 + phase, 1.0)
			var fade: = (1.0 - hp) * (1.0 - hp)
			var hr: = r.grow(1.5 + 13.0 * hp)
			var hpts: = _rr_pts(hr, rad + 2.0 + 4.0 * hp, 8)
			hpts.append(hpts[0])
			draw_polyline(hpts, Color(V10SalonUI.GOLD_300, 0.72 * fade), 1.6, true)

	# Soft grounding drop shadow under plaque
	draw_colored_polygon(_rr_pts(Rect2(r.position + Vector2(0.0, 3.0), r.size), rad, 8), Color(V10SalonUI.NIGHT_900, 0.52))

	# Subtle warm champagne-gold aura when affordable
	if affordable:
		draw_colored_polygon(_rr_pts(r.grow(4.5), rad + 3.5, 8), Color(V10SalonUI.GOLD_500, 0.16))
		draw_colored_polygon(_rr_pts(r.grow(2.0), rad + 1.5, 8), Color(V10SalonUI.GOLD_300, 0.14))

	# Jewel-like dark lacquer plaque body
	var bg: = Color(V10SalonUI.NIGHT_800.lerp(V10SalonUI.GOLD_700, 0.14), 0.96) if affordable else Color(V10SalonUI.NIGHT_800, 0.94)
	draw_colored_polygon(_rr_pts(r, rad, 8), bg)

	# Subtle lacquer top sheen
	var lh: = H * 0.44
	var sheen_c: = Color(V10SalonUI.GOLD_300 if affordable else V10SalonUI.PAPER_100, 0.11 if affordable else 0.06)
	var clear_c: = Color(sheen_c, 0.0)
	draw_polygon(PackedVector2Array([
		Vector2(r.position.x + rad * 0.6, r.position.y + 1.0),
		Vector2(r.end.x - rad * 0.6, r.position.y + 1.0),
		Vector2(r.end.x - 1.5, r.position.y + lh),
		Vector2(r.position.x + 1.5, r.position.y + lh),
	]), PackedColorArray([sheen_c, sheen_c, clear_c, clear_c]))

	# Crisp warm gold hairline border (champagne-gold rim when affordable)
	var bpts: = _rr_pts(r.grow(-0.6), maxf(2.0, rad - 0.6), 8)
	bpts.append(bpts[0])
	draw_polyline(bpts, V10SalonUI.GOLD_500 if affordable else Color(V10SalonUI.GOLD_700, 0.62), 1.5 if affordable else 1.0, true)

	# Top gold highlight gleam + tiny delicate crown attachment diamond
	_draw_hairline(r.position.x + 10.0, r.end.x - 10.0, r.position.y + 1.0, Color(V10SalonUI.GOLD_300, 0.92 if affordable else 0.48))
	_draw_diamond(Vector2(cx, top + 0.5), 2.6, V10SalonUI.GOLD_300 if affordable else V10SalonUI.GOLD_500)

	# Crisp editorial text + luminous star
	var f: = V10SalonUI.font("body", 800)
	var txt: = "%s · %d" % [title, cost]
	var tw: = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, FS).x
	var x: = cx - (tw + 22.0) * 0.5
	var y: = top + H * 0.5 + (f.get_ascent(FS) - f.get_descent(FS)) * 0.5
	draw_string(f, Vector2(x, y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, FS, V10SalonUI.PAPER_100)
	var sc: = Vector2(x + tw + 12.0, top + H * 0.5)
	if affordable:
		draw_circle(sc, 10.5, Color(V10SalonUI.GOLD_300, 0.24), true, -1.0, true)
	draw_colored_polygon(V10SalonUI.star_points(sc, 8.8 if affordable else 8.2), V10SalonUI.GOLD_300 if affordable else V10SalonUI.GOLD_500)
