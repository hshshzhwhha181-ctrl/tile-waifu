class_name V10MjPairTrail
extends Node2D

# V10MjPairTrail — «every pair feeds her» (docs/MODES.md §3.4.2). From the point where a pair vanished, ≤ 8 soft
# motes of her accent fly the shortest way up to her window and the ring ticks +1 when the first one lands.
# Budget (§3.1 exception to the sacred zone): ≤ 8 per pair, alpha ≤ 0.6, the whole flight ≤ 0.45 s, no stops,
# ≤ 18 on screen at fx full (UX §8.5). fx mid: ×0.55; fx min: no motes, the ring ticks at once.
#
#   trail.burst(from_global, to_global, color) -> int    motes spawned (0 at fx min)
#   signal arrived          the first mote of a burst reached the window (presence: ring +1)
# Audit for the selftest: max_over_sacred (longest time any mote spent over the sacred zone, s), max_alive.

signal arrived

const PER_PAIR: = 8
const MAX_ALIVE: = 18
const FLIGHT: = 0.36
const STAGGER: = 0.01
const ALPHA: = 0.6

var fx: = "full"
var sacred: Array = []  # Array[Rect2] in global px, set by the presence
var max_over_sacred: = 0.0
var max_alive: = 0
var spawned: = 0
var _motes: Array = []  # {p0, p1, ctl, t, dur, delay, col, r, over, first, burst}
var _burst_id: = 0
var _burst_landed: = {}


func _init() -> void:
	name = "PairTrail"
	z_index = 50
	set_process(false)


func burst(from_g: Vector2, to_g: Vector2, col: Color) -> int:
	if fx == "min":
		arrived.emit()
		return 0
	var n: = PER_PAIR if fx == "full" else maxi(3, int(round(PER_PAIR * 0.55)))
	n = mini(n, MAX_ALIVE - _motes.size())
	if n <= 0:
		arrived.emit()
		return 0
	_burst_id += 1
	var inv: = get_global_transform().affine_inverse()
	var p0: = inv * from_g
	var p1: = inv * to_g
	for i in n:
		var a: = TAU * float(i) / n + randf_range(-0.3, 0.3)
		var spread: = Vector2(cos(a), sin(a)) * randf_range(8.0, 22.0)
		var start: = p0 + spread
		# the shortest way up: a straight run with a slight outward bow that never turns back down
		var mid: = start.lerp(p1, 0.5) + Vector2(spread.x * 1.6, -absf(spread.y) * 0.4)
		_motes.append({"p0": start, "p1": p1 + spread * 0.15, "ctl": mid, "t": 0.0,
			"dur": FLIGHT - randf_range(0.0, 0.05), "delay": STAGGER * i, "col": col, "r": randf_range(3.0, 5.5),
			"over": 0.0, "burst": _burst_id, "pos": start, "prev": start})
	spawned += n
	max_alive = maxi(max_alive, _motes.size())
	set_process(true)
	return n


func _bez(m: Dictionary, k: float) -> Vector2:
	var a: Vector2 = (m.p0 as Vector2).lerp(m.ctl, k)
	var b: Vector2 = (m.ctl as Vector2).lerp(m.p1, k)
	return a.lerp(b, k)


func _process(dt: float) -> void:
	var gt: = get_global_transform()
	for i in range(_motes.size() - 1, -1, -1):
		var m: Dictionary = _motes[i]
		m.t += dt
		var lt: float = m.t - m.delay
		if lt < 0.0:
			continue
		var k: = clampf(lt / m.dur, 0.0, 1.0)
		var e: = 1.0 - pow(1.0 - k, 2.2)  # ease-out, never stops before the end
		m.prev = m.pos
		m.pos = _bez(m, e)
		var gp: Vector2 = gt * (m.pos as Vector2)
		for r in sacred:
			if (r as Rect2).has_point(gp):
				m.over += dt
				break
		max_over_sacred = maxf(max_over_sacred, m.over)
		if k >= 1.0:
			if not _burst_landed.has(m.burst):
				_burst_landed[m.burst] = true
				arrived.emit()
			_motes.remove_at(i)
	if _motes.is_empty():
		set_process(false)
	queue_redraw()


func _draw() -> void:
	for m in _motes:
		if m.t < m.delay:
			continue
		var c: Color = m.col
		var k: = clampf((m.t - m.delay) / m.dur, 0.0, 1.0)
		var a: = ALPHA * (1.0 - 0.5 * k)
		draw_line(m.prev, m.pos, Color(c.r, c.g, c.b, a * 0.5), m.r * 1.2, true)
		draw_circle(m.pos, m.r * 1.8, Color(c.r, c.g, c.b, a * 0.25))
		draw_circle(m.pos, m.r, Color(c.r, c.g, c.b, a))
		draw_circle(m.pos, m.r * 0.45, Color(1, 1, 1, a))


func alive() -> int:
	return _motes.size()
