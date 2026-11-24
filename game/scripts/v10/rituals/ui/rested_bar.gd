class_name V10RestedBar
extends Control

# «Отдых ×2» (Р5): a thin turquoise strip under the ult gauge, shown only while rested > 0.
# Each pair spends 1 (V10Comeback.consume_rested); the strip shrinks and «×2» pulses once per pair.
#   var bar = V10RestedBar.new(); bar.position = …; parent.add_child(bar); bar.set_value(rested)
#   bar.spend(n)

const W: = 300.0
const H: = 28.0

var _fill: Panel
var _lbl: Label
var _v: = 0


func _init() -> void:
	size = Vector2(W, H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	add_child(V10RitUI.panel(Rect2(0, 10, W, 8), Color(V10RitUI.TEAL, 0.18), 4))
	_fill = V10RitUI.panel(Rect2(0, 10, W, 8), V10RitUI.TEAL, 4)
	add_child(_fill)
	_lbl = V10RitUI.label("×2", 18, V10RitUI.TEAL, "num")
	_lbl.position = Vector2(W + 8, 0)
	_lbl.pivot_offset = Vector2(0, 14)
	add_child(_lbl)
	set_value(_v)


func set_value(v: int) -> void:
	_v = maxi(0, v)
	visible = _v > 0
	if _fill:
		_fill.size.x = W * clampf(_v / float(V10Comeback.RESTED_MAX), 0.04, 1.0)


func spend(n: int) -> void:
	set_value(_v - n)
	if _lbl and V9Feel.can_fx():
		var t: = _lbl.create_tween()
		t.tween_property(_lbl, "scale", Vector2.ONE * 1.3, 0.08)
		t.tween_property(_lbl, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)
