class_name V10SalonHub
extends Control

# Home hub card «Салон» (spec §Р1 п.2, decision §11 п.8: a card on the home screen instead of a sixth tab).
# Left: a live miniature of the current zone (the same reveal shader, so the card shows exactly what is restored),
# right: overline «САЛОН», the zone name, the progress ring «z2 · 4/6» and the next goal; a gold dot when
# something can be restored now. Tap → on_tap (integrator: main.go("v10salon")).
#   var card: = V10SalonHub.make(Rect2(32, 900, 656, 168), func(): main.go("v10salon"))
#   home.add_child(card)   # or V10Registry.home_slot("salon", builder, priority)
# card.refresh() after stars change (V10Hooks.app_resumed / win screen).

var on_tap: Callable
var mini: ColorRect
var mini_mat: ShaderMaterial
var name_lbl: Label
var goal_lbl: Label
var info: = {}
var _t: = 0.0
var _press: = false


static func make(r: Rect2, cb: Callable) -> V10SalonHub:
	var c: = V10SalonHub.new()
	c.position = r.position
	c.size = r.size
	c.on_tap = cb
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	c.pivot_offset = r.size * 0.5
	c._build()
	return c


func _build() -> void:
	V10Salon.ensure()
	var h: = size.y
	var mw: = roundf((h - 16) * V10SalonData.ZONE_ASPECT)
	mini = ColorRect.new()
	mini.position = Vector2(8, 8)
	mini.size = Vector2(mw, h - 16)
	mini.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mini_mat = ShaderMaterial.new()
	mini_mat.shader = load("res://scripts/v10/salon/salon_zone.gdshader")
	mini.material = mini_mat
	add_child(mini)
	var x: = mw + 30
	var ov: = V10SalonUI.overline("Салон")
	ov.position = Vector2(x, 18)
	add_child(ov)
	name_lbl = V10SalonUI.label("", 26, V10SalonUI.PAPER_100, "italic", 600)
	name_lbl.position = Vector2(x, 40)
	name_lbl.size = Vector2(size.x - x - 110, 36)
	name_lbl.clip_text = true
	add_child(name_lbl)
	goal_lbl = V10SalonUI.label("", 18, V10SalonUI.PAPER_300, "body", 700)
	goal_lbl.position = Vector2(x, h - 58)
	goal_lbl.size = Vector2(size.x - x - 110, 48)
	goal_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(goal_lbl)
	refresh()


func refresh() -> void:
	V10Salon.reset_cache()
	info = V10Salon.hub_info()
	var zid: String = info.zid
	name_lbl.text = str(info.name)
	var g: = V10Salon.next_goal()
	if V10Salon.all_released_done():
		goal_lbl.text = "Все зоны арки восстановлены"
	elif g.is_empty():
		goal_lbl.text = ""
	elif int(g.need) == 0:
		goal_lbl.text = "Можно восстановить: %s" % g.name
		goal_lbl.label_settings.font_color = V10SalonUI.GOLD_300
	else:
		goal_lbl.text = "Ещё %s до «%s»" % [V10SalonUI.stars_word(int(g.need)), g.name]
		goal_lbl.label_settings.font_color = V10SalonUI.PAPER_300
	# the miniature: same rects and state as the map
	var z: = V10SalonData.zone(zid)
	var ts: Array = z.tasks.duplicate()
	ts.sort_custom(func(a, b): return int(a.layer) < int(b.layer))
	var rects: = PackedVector4Array()
	var prog: = PackedFloat32Array()
	var jade: = PackedFloat32Array()
	var pop: = PackedVector2Array()
	for t in ts:
		var v: = V10Salon.task_variant(zid, t.id)
		for r in t.rects:
			rects.append(Vector4(r[0], r[1], r[2], r[3]))
			prog.append(1.0 if v != "" else 0.0)
			jade.append(1.0 if v == "jade" else 0.0)
			pop.append(Vector2(0, 1))
	mini_mat.set_shader_parameter("broken", load(V10SalonData.ART + zid + "_broken.webp"))
	mini_mat.set_shader_parameter("done", load(V10SalonData.ART + zid + "_done.webp"))
	mini_mat.set_shader_parameter("rects", rects)
	mini_mat.set_shader_parameter("count", rects.size())
	mini_mat.set_shader_parameter("prog", prog)
	mini_mat.set_shader_parameter("jade", jade)
	mini_mat.set_shader_parameter("pop", pop)
	mini_mat.set_shader_parameter("finale", 1.0 if bool(V10Salon.zone_rec(zid).done) else 0.0)
	queue_redraw()


func _process(dt: float) -> void:
	_t += dt
	if bool(info.get("dot", false)):
		queue_redraw()


func _draw() -> void:
	draw_style_box(V10SalonUI.panel_box(V10SalonUI.NIGHT_800, 4.0, Color(V10SalonUI.GOLD_700, 0.4), 1), Rect2(Vector2.ZERO, size))
	draw_rect(Rect2(mini.position - Vector2(1, 1), mini.size + Vector2(2, 2)), Color(V10SalonUI.GOLD_700, 0.45), false, 1.0)
	# progress ring with «n/total»
	var c: = Vector2(size.x - 62, size.y * 0.5)
	var r: = 40.0
	var frac: float = info.get("frac", 0.0)
	draw_arc(c, r, 0, TAU, 64, Color(V10SalonUI.NIGHT_600, 1.0), 6.0, true)
	if frac > 0.0:
		draw_arc(c, r, -PI / 2, -PI / 2 + TAU * frac, 64, V10SalonUI.JADE_300, 6.0, true)
	var f: = V10SalonUI.font("body", 900)
	var s: = "%d/%d" % [int(info.get("n", 0)), int(info.get("total", 0))]
	var w: = f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	draw_string(f, Vector2(c.x - w * 0.5, c.y + 8), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, V10SalonUI.PAPER_100)
	var zi: = V10SalonData.zone_ids().find(str(info.get("zid", "")))
	var zl: String = str(V10SalonZone.ROMAN[maxi(0, zi)])
	var w2: = f.get_string_size(zl, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	draw_string(f, Vector2(c.x - w2 * 0.5, c.y - 14), zl, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, V10SalonUI.PAPER_500)
	if bool(info.get("dot", false)):
		# the gold «можно восстановить» dot breathes on the ring
		var a: = 0.75 + 0.25 * sin(_t * 3.0)
		draw_circle(c + Vector2(r * 0.72, -r * 0.72), 11.0, Color(V10SalonUI.GOLD_300, a))
		draw_circle(c + Vector2(r * 0.72, -r * 0.72), 6.0, V10SalonUI.GOLD_500)


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_press = true
			V9Feel.press_down(self)
			accept_event()
		elif _press:
			_press = false
			var inside: = Rect2(Vector2.ZERO, size).has_point(e.position)
			V9Feel.press_up(self, inside)
			accept_event()
			if inside and on_tap.is_valid():
				on_tap.call()
