class_name V10SalonTag
extends Control

# A paper tag hanging on a thread over an unrestored task: «Вывеска · 3★» (spec §Р1 п.3).
# Sways from the scroll (impulse()) and settles; when the bank covers the cost it turns gold with a soft halo and
# hops ONCE (when it becomes affordable / the map opens). No endless hop, pulse or idle sway: the interface is
# still, the only endless UI motion on the screen is the main button's breath (UX_RULES §2.10, §6.7; HUD_V2 §6).
# `hint` draws the one obligatory tutorial finger (first task of the first visit; it lives until the first restore).

signal tapped(tid: String)

const H: = 50.0
const THREAD: = 34.0
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
	t._w = f.get_string_size("%s · %d" % [title_, cost_], HORIZONTAL_ALIGNMENT_LEFT, -1, FS).x + 52.0
	# hit zone ≥ 80 px tall (UX §6.1); the plaque itself is 50
	t.size = Vector2(maxf(t._w, 96.0), THREAD + H + 18.0)
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


func _draw() -> void:
	var cx: = size.x * 0.5
	var top: = THREAD + _hop
	var line_col: = Color(V10SalonUI.GOLD_500, 0.85) if affordable else Color(V10SalonUI.PAPER_500, 0.7)
	draw_circle(pin, 3.5, line_col)
	draw_line(pin, Vector2(cx - 14, top + 4), line_col, 1.5, true)
	draw_line(pin, Vector2(cx + 14, top + 4), line_col, 1.5, true)
	var r: = Rect2(cx - _w * 0.5, top, _w, H)
	if affordable:
		# gold halo (static) only on tags you can pay for now
		draw_style_box(V10SalonUI.panel_box(Color(V10SalonUI.GOLD_500, 0.22), 10.0), r.grow(5))
	var bg: = V10SalonUI.PAPER_100 if affordable else V10SalonUI.NIGHT_700
	var ink: = V10SalonUI.NIGHT_900 if affordable else V10SalonUI.PAPER_100
	draw_style_box(V10SalonUI.panel_box(bg, 5.0, Color(V10SalonUI.GOLD_700, 0.8), 1), r)
	# a tiny cinnabar knot where the threads meet the paper
	draw_circle(Vector2(cx, top + 3), 4.0, V10SalonUI.CINNABAR)
	var f: = V10SalonUI.font("body", 800)
	var txt: = "%s · %d" % [title, cost]
	var tw: = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, FS).x
	var x: = cx - (tw + 20) * 0.5
	var y: = top + H * 0.5 + 7
	draw_string(f, Vector2(x, y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, FS, ink)
	var sc: = Vector2(x + tw + 11, y - 7)
	draw_colored_polygon(V10SalonUI.star_points(sc, 9.0), V10SalonUI.GOLD_700 if affordable else V10SalonUI.GOLD_300)
	if hint:
		# the obligatory finger: a pulsing ring under the tag and a drawn fingertip pressing it
		var p: = fmod(_t, 1.2) / 1.2
		var rc: = Vector2(cx, top + H * 0.5)
		draw_arc(rc, 30.0 + 26.0 * p, 0, TAU, 40, Color(V10SalonUI.GOLD_300, 0.8 * (1.0 - p)), 3.0, true)
		var fp: = rc + Vector2(26, 36 + 8 * sin(_t * 5.0))
		draw_circle(fp, 15.0, Color(V10SalonUI.PAPER_100, 0.95))
		draw_rect(Rect2(fp + Vector2(-15, 0), Vector2(30, 40)), Color(V10SalonUI.PAPER_100, 0.95))
		draw_arc(fp, 15.0, PI, TAU, 16, Color(V10SalonUI.NIGHT_900, 0.6), 2.0, true)
