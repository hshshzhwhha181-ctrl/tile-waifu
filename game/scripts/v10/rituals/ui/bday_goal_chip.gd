class_name V10BdayGoalChip
extends Control

# «Праздник Рин: 12/24 пары её фишкой» (Р6): signature emblem in a progress ring + the goal line.
# Used in the win stack / Афиша / lobby. bump(n) is called on every counted pair (ring fills, emblem pops).
#   V10BdayGoalChip.make(V10Bday.goal_view()) -> chip

var view: = {}
var _ring: Ring
var _lbl: Label
var _icon: TextureRect


class Ring extends Control:
	var k: = 0.0
	var col: = Color("e8c47e")

	func _draw() -> void:
		var c: = size * 0.5
		var r: = size.x * 0.5 - 4
		draw_arc(c, r, 0, TAU, 48, Color(V10RitUI.PAPER700, 0.35), 5.0, true)
		if k > 0.0:
			draw_arc(c, r, -PI * 0.5, -PI * 0.5 + TAU * clampf(k, 0, 1), 48, col, 5.0, true)


static func make(v: Dictionary) -> V10BdayGoalChip:
	var c: = V10BdayGoalChip.new()
	c.view = v
	return c


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(560, 76)
	add_child(V10RitUI.panel(Rect2(Vector2.ZERO, size), Color(V10RitUI.NIGHT700, 0.92), 38, Color(V10RitUI.GOLD700, 0.45), 1))
	_ring = Ring.new()
	_ring.size = Vector2(68, 68)
	_ring.position = Vector2(4, 4)
	_ring.col = V10RitBridge.hero_color(str(view.get("h", "mc")))
	add_child(_ring)
	_icon = V10RitUI.tex(str(view.get("icon", "")), Rect2(14, 14, 48, 48))
	add_child(_icon)
	_lbl = V10RitUI.label("", 20, V10RitUI.PAPER100, "body", 800)
	_lbl.position = Vector2(84, 0)
	_lbl.size = Vector2(size.x - 100, size.y)
	_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_lbl)
	_apply(int(view.get("n", 0)))


func _apply(n: int) -> void:
	var goal: = int(view.get("goal", 24))
	_ring.k = n / float(goal)
	_ring.queue_redraw()
	var nm: = V10RitBridge.gen_name(str(view.get("h", "mc")))
	_lbl.text = "Праздник %s: %d/%d %s её фишкой" % [nm, n, goal, V10RitLines.plural(goal, "пара", "пары", "пар")]
	if n >= goal:
		_lbl.label_settings.font_color = V10RitUI.GOLD300


func bump(n: int) -> void:
	var from: = _ring.k
	var goal: = int(view.get("goal", 24))
	var t: = create_tween()
	t.tween_method(func(v: float):
		_ring.k = v
		_ring.queue_redraw(), from, n / float(goal), 0.3)
	_apply(n)
	V9Feel.success(_icon, "", 0.4)
