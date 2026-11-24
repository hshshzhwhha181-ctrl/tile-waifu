class_name V10BdayCake
extends Control

# Heroine birthday in the lobby (Р6): a paper-lantern garland in her colours, the cake with live candles in front of
# her. Tap the cake → she leans in, the candles go out one by one (bend, shrink, smoke), a petal burst of her colour
# (UX: no confetti), «Загадай за меня, ладно?» before and a thank-you after. Also used for the player's birthday
# (V10PlayerBdayScene reuses Candles and Garland).
#   V10BdayCake.open(parent, h) -> view      signal blown

signal blown

var h: = "rin"
var _cake: TextureRect
var _candles: Candles
var _portrait: TextureRect
var _blown: = false
var _goal: Control


class Candles extends Control:
	var n: = 5
	var lit: = []
	var bend: = []
	var t: = 0.0
	var col: = Color("ffcf8a")

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func setup(count: int) -> void:
		n = count
		lit = []
		bend = []
		for i in n:
			lit.append(1.0)
			bend.append(0.0)

	func _process(dt: float) -> void:
		t += dt
		queue_redraw()

	func xs() -> Array:
		var out: = []
		for i in n:
			out.append(size.x * (0.12 + 0.76 * i / maxf(1, n - 1)))
		return out

	func _draw() -> void:
		var xx: = xs()
		for i in n:
			var x: float = xx[i]
			var base: = Vector2(x, size.y)
			var hgt: = 46.0 + (i % 2) * 8.0
			# candle: ivory with a soft twist stripe
			draw_rect(Rect2(base.x - 5, base.y - hgt, 10, hgt), Color("f6eee2"))
			draw_rect(Rect2(base.x - 5, base.y - hgt, 3, hgt), Color(1, 1, 1, 0.6))
			for k in 4:
				draw_line(Vector2(base.x - 5, base.y - hgt + 6 + k * 11), Vector2(base.x + 5, base.y - hgt + 12 + k * 11), Color(V10RitUI.ROSE500, 0.75), 2.0)
			var wick: = Vector2(base.x, base.y - hgt - 6)
			draw_line(wick + Vector2(0, 6), wick, Color(0.2, 0.15, 0.12), 2.0)
			var l: float = lit[i]
			if l <= 0.01:
				continue
			var fl: = 1.0 + 0.08 * sin(t * 17.0 + i * 1.7) + 0.05 * sin(t * 29.0 + i)
			var b: float = bend[i]
			var hh: = 26.0 * l * fl
			var tip: = wick + Vector2(-b * 18.0 + sin(t * 6.0 + i) * 1.5, -hh)
			# glow
			draw_circle(wick + Vector2(0, -hh * 0.4), 26.0 * l, Color(1.0, 0.75, 0.4, 0.10 * l))
			draw_circle(wick + Vector2(0, -hh * 0.4), 14.0 * l, Color(1.0, 0.8, 0.5, 0.16 * l))
			# flame: teardrop polygon
			var pts: = PackedVector2Array()
			var w: = 7.0 * l
			for k in 13:
				var a: = PI * k / 12.0
				pts.append(wick + Vector2(cos(a + PI) * w, sin(a) * w * 0.9 - 2))
			pts.append(tip)
			draw_colored_polygon(pts, Color(1.0, 0.72, 0.3, 0.95 * l))
			var inner: = PackedVector2Array()
			for p in pts:
				inner.append(wick + (p - wick) * 0.55 + Vector2(0, -2))
			draw_colored_polygon(inner, Color(1.0, 0.96, 0.8, l))


class Garland extends Control:
	var col: = Color("4fbf9f")
	var t: = 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(dt: float) -> void:
		if V9Feel.can_fx():
			t += dt
			queue_redraw()

	func _draw() -> void:
		var pts: = PackedVector2Array()
		var sag: = 70.0
		for i in 41:
			var u: = i / 40.0
			pts.append(Vector2(u * size.x, 24 + sag * 4.0 * u * (1.0 - u)))
		draw_polyline(pts, Color(V10RitUI.GOLD700, 0.9), 2.0, true)
		var n: = 7
		for i in n:
			var u: = (i + 0.5) / n
			var p: = Vector2(u * size.x, 24 + sag * 4.0 * u * (1.0 - u))
			var sw: = sin(t * 1.3 + i * 0.9) * 3.0
			var c: = p + Vector2(sw, 34)
			var cc: Color = col if i % 2 == 0 else Color(V10RitUI.PAPER100)
			draw_line(p, c + Vector2(0, -22), Color(V10RitUI.GOLD700, 0.9), 1.5)
			draw_circle(c, 40, Color(cc, 0.10))
			# paper lantern: an ellipse with ribs and gold caps
			var rect: = Rect2(c - Vector2(20, 24), Vector2(40, 48))
			draw_set_transform(c, 0.0, Vector2(1.0, 1.25))
			draw_circle(Vector2.ZERO, 20, Color(cc.lerp(Color.WHITE, 0.15), 0.95))
			draw_circle(Vector2(-5, -5), 9, Color(1, 1, 1, 0.25))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			for k in [-10, 0, 10]:
				draw_line(c + Vector2(k, -23), c + Vector2(k * 1.2, 23), Color(0, 0, 0, 0.12), 1.0)
			draw_rect(Rect2(c + Vector2(-9, -28), Vector2(18, 6)), V10RitUI.GOLD500)
			draw_rect(Rect2(c + Vector2(-9, 22), Vector2(18, 6)), V10RitUI.GOLD500)
			draw_line(c + Vector2(0, 28), c + Vector2(0, 40), Color(cc, 0.9), 3.0)


static func open(parent: Control, h_in: String) -> V10BdayCake:
	var v: = V10BdayCake.new()
	v.h = h_in
	v.size = parent.size
	parent.add_child(v)
	return v


func _ready() -> void:
	clip_contents = true
	var col: = V10RitBridge.hero_color(h)
	var bg: = TextureRect.new()
	bg.texture = load("res://assets/bg/bg_teahouse_blur.webp")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.size = size
	bg.modulate = Color(0.55, 0.5, 0.52)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var warm: = TextureRect.new()
	warm.texture = V10RitUI.soft_dot()
	warm.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	warm.size = Vector2(1000, 900)
	warm.position = Vector2(size.x * 0.5 - 500, size.y * 0.62 - 450)
	warm.modulate = Color(1.0, 0.7, 0.45, 0.28)
	warm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	warm.name = "warm"
	add_child(warm)
	# heroine (magazine cover: to the right, leaving the left for the line)
	var ph: = 1020.0
	_portrait = TextureRect.new()
	_portrait.texture = V10RitBridge.portrait(h)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	_portrait.size = Vector2(ph * 848.0 / 1264.0, ph)
	_portrait.position = Vector2(size.x - _portrait.size.x + 70, size.y - ph - 150)
	_portrait.pivot_offset = Vector2(_portrait.size.x * 0.5, ph)
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_portrait)
	if V9Feel.can_fx():
		var bt: = _portrait.create_tween().set_loops()
		bt.tween_property(_portrait, "scale", Vector2(1.0, 1.008), 2.1).set_trans(Tween.TRANS_SINE)
		bt.tween_property(_portrait, "scale", Vector2.ONE, 2.1).set_trans(Tween.TRANS_SINE)
	var g: = Garland.new()
	g.col = col
	g.size = Vector2(size.x, 160)
	g.position = Vector2(0, 70)
	add_child(g)
	add_child(V10RitUI.grad(Rect2(0, size.y * 0.62, size.x, size.y * 0.38), Color(V10RitUI.NIGHT900, 0), Color(V10RitUI.NIGHT900, 0.9)))
	# cake: front-left, on the «table»
	var cake_name: String = V10BdayData.CAKE.get(h, "cake_tier")
	var cw: = 380.0
	_cake = V10RitUI.tex(V10RitUI.ART + cake_name + ".webp", Rect2(28, size.y - 560, cw, cw * 1.08))
	_cake.mouse_filter = Control.MOUSE_FILTER_STOP
	_cake.gui_input.connect(_on_cake)
	add_child(_cake)
	_candles = Candles.new()
	_candles.setup(5)
	_candles.size = Vector2(cw * 0.5, 70)
	# candles stand on the cake's top tier (top ~10% of the art)
	_candles.position = _cake.position + Vector2(cw * 0.25, cw * 0.08 - 40)
	add_child(_candles)
	var over: = V10RitUI.label("День рождения · %s" % V10RitBridge.short_name(h), 15, V10RitUI.GOLD500, "over")
	over.position = Vector2(32, 250)
	add_child(over)
	V10RitUI.voice(self, V10RitLines.pick("bday_wish", h, 0), Vector2(32, 280), 400, 40, 0.0)
	var hint: = V10RitUI.label("Коснись торта", 18, V10RitUI.PAPER300)
	hint.name = "hint"
	hint.position = Vector2(70, size.y - 150)
	add_child(hint)
	V10RitUI.inhale([over, hint], 0.3)
	_goal_chip()


func _goal_chip() -> void:
	var gv: = V10Bday.goal_view()
	if gv.is_empty() or str(gv.h) != h:
		gv = {"h": h, "n": 0, "goal": V10BdayData.GOAL_PAIRS, "icon": V10Bday.sig_icon(h),
			"text": "Праздник %s: 0/%d пары её фишкой" % [V10RitBridge.gen_name(h), V10BdayData.GOAL_PAIRS]}
	_goal = V10BdayGoalChip.make(gv)
	_goal.position = Vector2(32, size.y - 104)
	add_child(_goal)


func _on_cake(e: InputEvent) -> void:
	if not ((e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed)):
		return
	blow()


func blow() -> void:
	if _blown:
		V9Feel.press(_cake, "pop", "button")
		return
	_blown = true
	V9Feel.press(_cake, "", "button")
	var hint: CanvasItem = get_node_or_null("hint")
	if hint:
		hint.create_tween().tween_property(hint, "modulate:a", 0.0, 0.2)
	# she leans in a little
	var lean: = _portrait.create_tween()
	lean.tween_property(_portrait, "rotation", deg_to_rad(-2.5), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	lean.tween_interval(0.8)
	lean.tween_property(_portrait, "rotation", 0.0, 0.6).set_trans(Tween.TRANS_SINE)
	V10RitUI.sfx("blow", "whoosh", 1.0, 0.0)
	var t: = create_tween()
	t.tween_interval(0.25)
	for i in _candles.n:
		var idx: = i
		t.tween_method(func(k: float):
			_candles.bend[idx] = k
			_candles.lit[idx] = 1.0 - k * k, 0.0, 1.0, 0.16)
		t.tween_callback(func():
			var x: float = _candles.xs()[idx]
			var smoke: = V10RitUI.steam(self, _candles.position + Vector2(x, 0), 6, 6, Color(0.85, 0.85, 0.9, 0.45))
			smoke.one_shot = true
			smoke.preprocess = 0.0
			smoke.emitting = true
			smoke.finished.connect(smoke.queue_free))
		t.tween_interval(0.06)
	t.tween_interval(0.2)
	t.tween_callback(func():
		var warm: CanvasItem = get_node_or_null("warm")
		if warm:
			warm.create_tween().tween_property(warm, "modulate:a", 0.12, 0.4)
		if V9Feel.can_fx():
			V10RitUI.petals(self, _cake.position + Vector2(_cake.size.x * 0.5, 40), V10RitBridge.hero_color(h), 36)
		V9Feel.success(_cake, "", 1.0)
		V10RitUI.sfx("bell", "sparkle", 1.0, -3.0))
	t.tween_interval(0.5)
	t.tween_callback(func():
		V10RitUI.voice(self, V10RitLines.pick("bday_blown", h, 0), Vector2(32, 380), 400, 36, 0.0)
		blown.emit())
