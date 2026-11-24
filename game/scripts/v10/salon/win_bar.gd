class_name V10SalonWinBar
extends Control

# The salon strip of the victory stack (spec §Ф5: V10WinStack.add_bar("salon", prio, builder); §Р1 п.2 «кнопка
# «В салон» на окне победы»; UX_RULES §3.4: the second button reads «В салон» when something can be restored).
#   V10WinStack.add_bar("salon", 20, func(ctx): return V10SalonWinBar.build(ctx, width))
# ctx: {stars_before: int, stars_after: int} — the bar fills from the old bank to the new one in 0.6 s.
# want_salon_button() tells the win screen to label its second button «В салон» instead of «В чайную».

var goal: = {}
var from_bank: = 0
var to_bank: = 0
var _v: = 0.0


static func want_salon_button() -> bool:
	V10Salon.reset_cache()
	return V10Salon.can_restore_any()


static func build(ctx: Dictionary, w: float) -> V10SalonWinBar:
	V10Salon.reset_cache()
	var b: = V10SalonWinBar.new()
	b.size = Vector2(w, 72)
	b.custom_minimum_size = b.size
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.goal = V10Salon.next_goal()
	b.to_bank = V10Salon.bank()
	b.from_bank = maxi(0, b.to_bank - maxi(0, int(ctx.get("stars_after", 0)) - int(ctx.get("stars_before", 0))))
	b._v = b.from_bank
	if b.goal.is_empty():
		return b
	var t: = b.create_tween()
	t.tween_interval(0.2)
	t.tween_method(func(v: float):
		b._v = v
		b.queue_redraw(), float(b.from_bank), float(b.to_bank), 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	return b


func _draw() -> void:
	if goal.is_empty():
		return
	var f: = V10SalonUI.font("body", 800)
	var cost: = float(goal.cost)
	var frac: = clampf(_v / cost, 0.0, 1.0)
	var ready: = _v >= cost
	var label: = ("Салон: можно восстановить «%s»" % goal.name) if ready else ("Салон: «%s»" % goal.name)
	draw_string(f, Vector2(0, 24), label, HORIZONTAL_ALIGNMENT_LEFT, size.x - 120, 20, V10SalonUI.GOLD_300 if ready else V10SalonUI.PAPER_300)
	var n: = "%d/%d" % [mini(int(round(_v)), int(cost)), int(cost)]
	var nw: = f.get_string_size(n, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	draw_string(f, Vector2(size.x - nw - 26, 24), n, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, V10SalonUI.PAPER_100)
	draw_colored_polygon(V10SalonUI.star_points(Vector2(size.x - 11, 17), 10.0), V10SalonUI.GOLD_300)
	var r: = Rect2(0, 42, size.x, 10)
	draw_style_box(V10SalonUI.panel_box(V10SalonUI.NIGHT_600, 5.0), r)
	if frac > 0.0:
		draw_style_box(V10SalonUI.panel_box(V10SalonUI.GOLD_500 if ready else V10SalonUI.JADE_500, 5.0), Rect2(r.position, Vector2(maxf(10.0, r.size.x * frac), r.size.y)))
