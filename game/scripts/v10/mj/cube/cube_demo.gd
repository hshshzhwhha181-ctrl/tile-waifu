extends Control

# Демо и витрина Куба (docs/MODES.md §4.4)

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var sc: = V10MjCubeScreen.new()
	add_child(sc)
	sc.setup(null, {"level": 8, "hero": "nova", "demo": true})
