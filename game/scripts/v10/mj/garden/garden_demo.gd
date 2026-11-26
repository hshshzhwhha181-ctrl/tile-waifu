extends Control

# Демо Сада 2.0 (docs/MODES.md §4.9)

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var sc: = V10MjGardenScreen.new()
	add_child(sc)
	sc.setup(null, {"hero": "yue", "demo": true})
