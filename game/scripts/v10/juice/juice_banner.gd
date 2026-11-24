class_name V10JuiceBanner
extends Control

# V10JuiceBanner — combo milestone banner (×5 / ×10 / ×20): a calligraphy brush stroke paints itself across the
# HUD strip, a vermilion hanko seal with the multiplier slams down on it (thud, ink spatter, light shake), the
# tier name slides in and gets a sheen, then the stroke dries away from its tail. 1.6 s, one at a time.
# It lives inside the strip rect it is given (HUD strip above the board) and never takes taps.

static var current: V10JuiceBanner

var brush: ColorRect
var seal: ColorRect
var seal_lbl: Label
var title_lbl: Label


static func show_banner(parent: Node, strip: Rect2, combo: int, title: String, color: Color) -> V10JuiceBanner:
	if current != null and is_instance_valid(current):
		current.queue_free()
	var b: = V10JuiceBanner.new()
	b.position = strip.position
	b.size = strip.size
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(b)
	current = b
	b._build(combo, title, color)
	return b


func _build(combo: int, title: String, color: Color) -> void:
	var lvl: = V10Juice.level()
	var full: = lvl == "full"
	var anim: = lvl != "min"
	var h: = minf(size.y, 124.0)
	var y0: = (size.y - h) * 0.5
	var bw: = minf(size.x - 40.0, 600.0)
	var x0: = (size.x - bw) * 0.5
	brush = ColorRect.new()
	brush.mouse_filter = Control.MOUSE_FILTER_IGNORE
	brush.position = Vector2(x0 + 40, y0)
	brush.size = Vector2(bw - 40, h)
	brush.material = V10Juice.mat("juice_brush_band", {"reveal": 0.0 if anim else 1.0, "fade": 0.0,
		"tint": color.darkened(0.55), "seed": randf() * 30.0})
	add_child(brush)

	var ss: = h * 0.82
	seal = ColorRect.new()
	seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	seal.size = Vector2(ss, ss)
	seal.position = Vector2(x0, y0 + (h - ss) * 0.5)
	seal.pivot_offset = seal.size * 0.5
	seal.rotation = -0.08
	seal.material = V10Juice.mat("juice_seal", {"color": Color(0.8, 0.17, 0.14), "seed": randf() * 30.0, "fill": 0.92, "erosion": 0.22})
	add_child(seal)
	seal_lbl = UI.label("×%d" % combo, 40 if combo < 10 else 34, Color("f8ecd6"), Color(0.35, 0.05, 0.05), 3, "title", 900)
	seal_lbl.size = seal.size
	seal_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	seal_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	seal.add_child(seal_lbl)

	title_lbl = UI.label(title, 44 if title.length() < 12 else 38, Color("f8ecd6"), Color(0.08, 0.04, 0.06), 6, "title", 900)
	title_lbl.position = Vector2(x0 + ss + 26, y0)
	title_lbl.size = Vector2(bw - ss - 30, h)
	title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_lbl.modulate.a = 0.0
	add_child(title_lbl)

	var t: = create_tween().set_parallel()
	if anim:
		V10Juice.sound("brush_swoosh", randf_range(0.97, 1.05), -6.0)
		t.tween_method(func(v): V10Juice.param(brush, "reveal", v), 0.0, 1.0, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		var tp: = title_lbl.position
		title_lbl.position = tp + Vector2(46, 0)
		t.tween_property(title_lbl, "position", tp, 0.32).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT).set_delay(0.1)
		t.tween_property(title_lbl, "modulate:a", 1.0, 0.2).set_delay(0.1)
		# the stamp: from big and tilted, slam (own tween: the impact lands at 0.29 s)
		seal.scale = Vector2(2.4, 2.4)
		seal.modulate.a = 0.0
		seal.rotation = -0.3
		var ts: = create_tween()
		ts.tween_interval(0.16)
		ts.tween_property(seal, "scale", Vector2.ONE, 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		ts.parallel().tween_property(seal, "modulate:a", 1.0, 0.08)
		ts.parallel().tween_property(seal, "rotation", -0.08, 0.13)
		ts.tween_callback(_impact.bind(full))
		ts.tween_property(seal, "scale", Vector2(1.08, 0.93), 0.05)
		ts.tween_property(seal, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		# hold, then the stroke dries away from the tail
		var tf: = create_tween().set_parallel()
		tf.tween_method(func(v): V10Juice.param(brush, "fade", v), 0.0, 1.0, 0.32).set_trans(Tween.TRANS_SINE).set_delay(1.25)
		tf.tween_property(seal, "modulate:a", 0.0, 0.3).set_delay(1.25)
		tf.tween_property(title_lbl, "modulate:a", 0.0, 0.26).set_delay(1.25)
		tf.tween_property(self, "position:y", position.y - 10.0, 0.3).set_delay(1.25)
		tf.chain().tween_callback(queue_free)
		return
	else:
		title_lbl.modulate.a = 1.0
		modulate.a = 0.0
		t.tween_property(self, "modulate:a", 1.0, 0.1)
		V10Juice.sound("stamp_thud", 1.0, -8.0)
		t.chain().tween_interval(1.1)
		t.chain().tween_property(self, "modulate:a", 0.0, 0.2)
		t.chain().tween_callback(queue_free)


func _impact(full: bool) -> void:
	V10Juice.sound("stamp_thud", randf_range(0.97, 1.03), -3.0)
	V10Juice.haptic("match")
	var c: = seal.get_global_rect().get_center()
	V10Juice.burst(null, c, "ink", 12, Color(0.62, 0.1, 0.1), 1.0)
	V10Juice.burst(null, c, "star4", 6, Color(1.0, 0.85, 0.6), 1.0)
	if full:
		V10Juice.shake(0.16)
		V10Juice.ripple(null, c, Color(1.0, 0.5, 0.35), seal.size.x * 1.1, 0.4, 0.07)
	get_tree().create_timer(0.12, true, false, true).timeout.connect(func():
		if is_instance_valid(title_lbl):
			V10Juice.sheen(title_lbl, Color(1, 0.88, 0.6), 0.55, 0.6))
