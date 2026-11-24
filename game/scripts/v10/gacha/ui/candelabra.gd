class_name V10Candelabra
extends Control

# V10Candelabra — «Свеча желаний» (spec Г5): a lacquer-and-gold candelabra of 10 candles drawn in code. Each
# 20 wishes light the next candle (flame grows, sparks, a note that rises with the candle's number); the 10th
# gets its own chord of expectation and the whole row glows. Candles never burn out.
#   var c: = V10Candelabra.new(); c.size = Vector2(w, h); c.set_count(137)      static
#   c.animate_to(157)                                     lights the candles between, one by one (≈ 0.25 s each)
# Purely visual (mouse_filter IGNORE); flames flicker only when fx allows, otherwise they stand still.

const N: = 10
const PER: = 20

var count: = 0
var shown: = 0.0            # candles lit as drawn (float while a flame grows)
var t: = 0.0
var ready_glow: = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_count(c: int) -> void:
	count = c
	shown = float(mini(N, c / PER))
	ready_glow = 1.0 if c >= PER * N else 0.0
	queue_redraw()


func lit() -> int:
	return mini(N, count / PER)


func animate_to(c: int) -> void:
	var from: = lit()
	count = c
	var to: = lit()
	if to <= from:
		set_count(c)
		return
	var tw: = create_tween()
	for i in range(from, to):
		var k: = i
		tw.tween_callback(func(): _light(k))
		tw.tween_property(self, "shown", float(k + 1), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_interval(0.06)
	if to >= N:
		tw.tween_callback(func():
			Sfx.play("summon_charge", 1.5, -6.0)
			V9Feel.haptic("success"))
		tw.tween_property(self, "ready_glow", 1.0, 0.5)


func _light(i: int) -> void:
	Sfx.play("star%d" % (i % 3), V10GUI.PENTA[i % V10GUI.PENTA.size()], -6.0)
	if V9Feel.can_fx():
		Fx.burst(self, _tip(i), "sparkle", 8, Color(1, 0.85, 0.5), 0.5)


func _process(dt: float) -> void:
	if V9Feel.can_fx():
		t += dt
		queue_redraw()


func _x(i: int) -> float:
	var m: = size.x * 0.06
	return m + (size.x - 2 * m) * (float(i) + 0.5) / N


func _tip(i: int) -> Vector2:
	var h: = _candle_h(i)
	return Vector2(_x(i), size.y * 0.78 - h)


func _candle_h(i: int) -> float:
	# the row rises to the middle like a real candelabra
	var d: = absf(float(i) - (N - 1) * 0.5) / ((N - 1) * 0.5)
	return size.y * (0.5 - 0.16 * d)


func _draw() -> void:
	var base_y: = size.y * 0.78
	var gold: = V10GUI.GOLD_500
	# the arm: a soft gold arc with a lacquer shadow
	var pts: = PackedVector2Array()
	for i in 33:
		var u: = float(i) / 32.0
		var x: = lerpf(_x(0) - 10, _x(N - 1) + 10, u)
		pts.append(Vector2(x, base_y + 6 + sin(u * PI) * size.y * 0.06))
	draw_polyline(pts, Color(0, 0, 0, 0.45), 7.0, true)
	draw_polyline(pts, Color(gold, 0.85), 3.0, true)
	draw_line(Vector2(size.x * 0.5, base_y + 6 + size.y * 0.06), Vector2(size.x * 0.5, size.y * 0.98), Color(gold, 0.7), 3.0, true)
	if ready_glow > 0.0:
		var g: = Color(1.0, 0.8, 0.45, 0.16 * ready_glow)
		draw_circle(Vector2(size.x * 0.5, base_y - size.y * 0.3), size.x * 0.32, g)
	for i in N:
		var x: = _x(i)
		var h: = _candle_h(i)
		var w: = maxf(8.0, size.x * 0.026)
		var on: = clampf(shown - float(i), 0.0, 1.0)
		# cup
		draw_rect(Rect2(x - w * 0.9, base_y - 3, w * 1.8, 6), Color(gold, 0.95))
		# wax: ivory when lit, dusk when not
		var wax: = Color("efe3cc").lerp(Color("4a4250"), 1.0 - on)
		draw_rect(Rect2(x - w * 0.5, base_y - h, w, h), wax)
		draw_rect(Rect2(x - w * 0.5, base_y - h, w * 0.3, h), Color(1, 1, 1, 0.18 * on))
		draw_line(Vector2(x, base_y - h), Vector2(x, base_y - h - 5), Color(0.2, 0.15, 0.1), 1.5)
		if on > 0.0:
			var fl: = 1.0
			if V9Feel.can_fx():
				fl = 0.86 + 0.1 * sin(t * 9.0 + i * 1.7) + 0.05 * sin(t * 15.3 + i)
			var fh: = (w * 2.6) * on * fl
			var tip: = Vector2(x + (sin(t * 3.0 + i) * 1.2 if V9Feel.can_fx() else 0.0), base_y - h - 4 - fh)
			draw_circle(Vector2(x, base_y - h - fh * 0.45), fh * 1.2, Color(1.0, 0.72, 0.35, 0.12 * on))
			var flame: = PackedVector2Array([Vector2(x - w * 0.42, base_y - h - 4), tip, Vector2(x + w * 0.42, base_y - h - 4),
				Vector2(x, base_y - h + 1)])
			draw_colored_polygon(flame, Color(1.0, 0.7, 0.3, 0.95 * on))
			var core: = PackedVector2Array([Vector2(x - w * 0.2, base_y - h - 3), tip.lerp(Vector2(x, base_y - h), 0.4), Vector2(x + w * 0.2, base_y - h - 3)])
			draw_colored_polygon(core, Color(1.0, 0.97, 0.85, on))
