class_name TWExitConfirm
extends TWModal

# TWExitConfirm (P24): "leave the game?" - the last row of the Android back table. result = "yes" | "no" (null when it is cleared
# by a screen change or dismissed with back / a scrim tap = stay in the game). Buttons are HIT_TARGET_MIN tall.

signal answered(yes: bool)

var title_text: = "Выйти из игры?"
var yes_text: = "Выйти"
var no_text: = "Остаться"
var yes_button: Button = null
var no_button: Button = null


func _build(_opts: Dictionary) -> void:
	var panel: = PanelContainer.new()
	panel.name = "Panel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(560, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb: = StyleBoxFlat.new()
	sb.bg_color = TWTokens.PLATE_TOP
	sb.border_color = TWTokens.PLATE_RIM
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(24)
	sb.set_content_margin_all(32)
	panel.add_theme_stylebox_override("panel", sb)
	var box: = VBoxContainer.new()
	box.add_theme_constant_override("separation", 24)
	panel.add_child(box)
	var lab: = Label.new()
	lab.text = title_text
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.add_theme_font_size_override("font_size", TWTokens.font(TWTokens.TYPE_H2))
	lab.add_theme_color_override("font_color", TWTokens.PAPER_100)
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(lab)
	var row: = HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	box.add_child(row)
	no_button = _button(no_text)
	no_button.pressed.connect(func(): _answer(false))
	row.add_child(no_button)
	yes_button = _button(yes_text)
	yes_button.pressed.connect(func(): _answer(true))
	row.add_child(yes_button)
	add_child(panel)


func _button(text: String) -> Button:
	var b: = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, TWTokens.hit())
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", TWTokens.font(TWTokens.TYPE_BODY))
	return b


func _answer(yes: bool) -> void:
	answered.emit(yes)
	close("yes" if yes else "no", "answer")
