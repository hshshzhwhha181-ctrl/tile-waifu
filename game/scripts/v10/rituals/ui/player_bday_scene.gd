class_name V10PlayerBdayScene
extends Control

# The player's birthday (Р7, through the entry queue): the partner in the centre, the other heroines peeking in
# from the edges, a lantern garland, candles to blow, «С днём рождения, Аня!» and the gift cascade
# (3 билета, рамка «Мой праздник · YYYY», +50 симпатии). One main action «Спасибо!».
#   V10PlayerBdayScene.play(parent, {name_voc, rows}) -> scene         signal finished

signal finished

var opts: = {}
var h: = "mc"


static func play(parent: Control, opts_in: = {}) -> V10PlayerBdayScene:
	var s: = V10PlayerBdayScene.new()
	s.opts = opts_in
	s.h = V10RitBridge.partner()
	s.size = parent.size
	parent.add_child(s)
	return s


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	var W: = size.x
	var bg: = TextureRect.new()
	bg.texture = load("res://assets/bg/bg_festival_blur.webp")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.size = size
	bg.modulate = Color(0.5, 0.46, 0.5)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	# the others peek in from the edges (heads and shoulders only, never covering the partner's face)
	var others: = V10RitBridge.heroes().filter(func(x): return x != h).slice(0, 4)
	var peeks: = []
	for i in others.size():
		var left: = i % 2 == 0
		var ph: = 760.0
		var p: = TextureRect.new()
		p.texture = V10RitBridge.portrait(str(others[i]))
		p.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		p.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		p.size = Vector2(ph * 848.0 / 1264.0, ph)
		p.flip_h = not left
		var y: = 180.0 + (i / 2) * 330.0
		var rest_x: = -p.size.x * 0.62 if left else W - p.size.x * 0.38
		p.position = Vector2(-p.size.x if left else W, y)
		p.rotation = deg_to_rad(8 if left else -8)
		p.modulate = Color(0.82, 0.8, 0.84)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(p)
		peeks.append(p)
		var t: = p.create_tween()
		t.tween_interval(0.7 + 0.25 * i)
		t.tween_property(p, "position:x", rest_x, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if V9Feel.can_fx():
			t.tween_property(p, "position:y", y - 10, 1.4).set_trans(Tween.TRANS_SINE)
			t.tween_property(p, "position:y", y, 1.4).set_trans(Tween.TRANS_SINE)
	var ph2: = 1040.0
	var main: = TextureRect.new()
	main.texture = V10RitBridge.portrait(h)
	main.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	main.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	main.size = Vector2(ph2 * 848.0 / 1264.0, ph2)
	main.position = Vector2((W - main.size.x) * 0.5, size.y - ph2 - 170)
	main.pivot_offset = Vector2(main.size.x * 0.5, ph2)
	main.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(main)
	main.scale = Vector2(0.94, 0.94)
	main.modulate.a = 0.0
	var mt: = main.create_tween()
	mt.tween_property(main, "modulate:a", 1.0, 0.4)
	mt.parallel().tween_property(main, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var g: = V10BdayCake.Garland.new()
	g.col = V10RitBridge.hero_color(h)
	g.size = Vector2(W, 160)
	g.position = Vector2(0, 20)
	add_child(g)
	add_child(V10RitUI.grad(Rect2(0, size.y * 0.5, W, size.y * 0.5), Color(V10RitUI.NIGHT900, 0), Color(V10RitUI.NIGHT900, 0.95)))
	var title: = V10RitUI.label("С днём рождения", 60, V10RitUI.PAPER100, "title", 700)
	title.size = Vector2(W, 80)
	title.position = Vector2(0, size.y - 520)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	var voc: = str(opts.get("name_voc", ""))
	var line: = V10RitLines.pick("player_bday", h, 0).replace("{voc}", (", " + voc) if voc != "" else "")
	var vl: = V10RitUI.wrap_w(V10RitUI.label(line, 36, V10RitUI.GOLD300, "hand"), W - 80)
	vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vl.position = Vector2(40, size.y - 436)
	vl.visible_ratio = 0.0
	add_child(vl)
	V10RitUI.inhale([title], 1.2)
	var t: = create_tween()
	t.tween_interval(1.5)
	t.tween_callback(func():
		vl.create_tween().tween_property(vl, "visible_ratio", 1.0, 0.9)
		if V9Feel.can_fx():
			V10RitUI.petals(self, Vector2(W * 0.5, size.y * 0.35), g.col, 40, 160)
		V10RitUI.sfx("bell", "sparkle", 1.0, -2.0))
	t.tween_interval(1.1)
	t.tween_callback(func():
		var rows: Array = opts.get("rows", [])
		if not rows.is_empty():
			V10RitUI.cascade(self, rows, Vector2(W * 0.5, size.y - 252)))
	var ok: = V10RitUI.button("Спасибо!", Rect2((W - 560) * 0.5, size.y - 150, 560, 104), "primary", func():
		var ft: = create_tween()
		ft.tween_property(self, "modulate:a", 0.0, 0.3)
		ft.tween_callback(func():
			finished.emit()
			queue_free()))
	add_child(ok)
	V10RitUI.inhale([ok], 2.6)
