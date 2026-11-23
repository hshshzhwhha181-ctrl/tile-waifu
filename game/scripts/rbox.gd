class_name RBox
extends Control


var cr: ColorRect
var mat: ShaderMaterial
var margin: = 14.0

func setup(top: Color, bottom: Color, radius: = 28.0, border: = 4.0, m: = 14.0) -> RBox:
	margin = m
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	cr = ColorRect.new()
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cr.color = Color.WHITE
	mat = ShaderMaterial.new()
	mat.shader = preload("res://shaders/rbox.gdshader")
	cr.material = mat
	add_child(cr)
	set_param("top_color", top)
	set_param("bottom_color", bottom)
	set_param("radius", radius)
	set_param("border", border)
	set_param("margin", m)
	resized.connect(_fit)
	_fit()
	return self

func set_param(k: String, v) -> RBox:
	mat.set_shader_parameter(k, v)
	return self

func colors(top: Color, bottom: Color) -> RBox:
	set_param("top_color", top)
	set_param("bottom_color", bottom)
	return self

func borders(top: Color, bottom: Color) -> RBox:
	set_param("border_top", top)
	set_param("border_bottom", bottom)
	return self

func _fit() -> void :
	cr.position = Vector2( - margin, - margin)
	cr.size = size + Vector2(margin, margin) * 2.0
	mat.set_shader_parameter("size", cr.size)

func shine(delay: = 0.0, dur: = 0.9) -> void :
	var t: = create_tween()
	t.tween_interval(delay)
	t.tween_method( func(v): mat.set_shader_parameter("shine_pos", v), -0.4, 1.5, dur).set_trans(Tween.TRANS_SINE)
