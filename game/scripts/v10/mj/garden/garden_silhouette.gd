class_name V10MjGardenSilhouette
extends Control

# Рекорд недели в Саду (docs/MODES.md §4.9): на 1 с её силуэт проступает ЗА полупрозрачным столом.
# Узел встаёт в стол дорожки look между дальним слоем и сукном (V10MjTableView: far → силуэт → сукно → частицы),
# сукно на это время становится полупрозрачным (альфа 1 → 0,55 → 1). Фишки остаются над сукном, яркими и
# доступными — поверх свободных фишек нет ни одного её пикселя (MODES §3.1), ввод не блокируется.
# 0,2 с проявление · 0,6 с держит · 0,2 с гаснет. fx_level = min — без изменения сукна, только проявление 120 мс.

const SHADER: = """
shader_type canvas_item;
uniform vec4 tint : source_color = vec4(0.1, 0.07, 0.2, 1.0);
uniform float amount = 0.0;
void fragment() {
	float a = texture(TEXTURE, UV).a;
	COLOR = vec4(tint.rgb, a * tint.a * amount);
}
"""

const IN_T: = 0.2
const HOLD: = 0.6
const OUT_T: = 0.2
const CLOTH_A: = 0.55

var fig: TextureRect
var mat: ShaderMaterial
var active: = false
var plays: = 0
var cloth: CanvasItem
var _tw: Tween


static func make(table: Control, hero: String, board_rect: Rect2) -> V10MjGardenSilhouette:
	var s: = V10MjGardenSilhouette.new()
	s.name = "GardenSilhouette"
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.size = table.size
	table.add_child(s)
	# сразу за дальним слоем (индекс 1), перед сукном
	table.move_child(s, mini(1, table.get_child_count() - 1))
	s.cloth = table.get("cloth_rect") as CanvasItem
	s._build(hero, board_rect)
	return s


func _build(hero: String, board_rect: Rect2) -> void:
	fig = TextureRect.new()
	fig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fig.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fig.stretch_mode = TextureRect.STRETCH_SCALE
	var tex: Texture2D = load(V10MjGardenPresence.frame_path(hero, "happy"))
	fig.texture = tex
	var ts: = Vector2(tex.get_width(), tex.get_height()) if tex else Vector2(600, 765)
	var h: = board_rect.size.y * 0.92
	var w: = h * ts.x / ts.y
	fig.size = Vector2(w, h)
	fig.position = Vector2(board_rect.get_center().x - w * 0.5, board_rect.end.y - h)
	mat = ShaderMaterial.new()
	var sh: = Shader.new()
	sh.code = SHADER
	mat.shader = sh
	var deep: Color = V10MjGardenLook.accent(hero)[2]
	mat.set_shader_parameter("tint", Color(deep.darkened(0.35), 0.92))
	mat.set_shader_parameter("amount", 0.0)
	fig.material = mat
	add_child(fig)
	visible = false


func play(fx_min: = false) -> void:
	plays += 1
	active = true
	visible = true
	if _tw and _tw.is_valid():
		_tw.kill()
	_tw = create_tween()
	if fx_min:
		_tw.tween_method(_amount, 0.0, 1.0, 0.12)
		_tw.tween_interval(0.76)
		_tw.tween_method(_amount, 1.0, 0.0, 0.12)
	else:
		_tw.tween_method(_amount, 0.0, 1.0, IN_T)
		if cloth:
			_tw.parallel().tween_property(cloth, "modulate:a", CLOTH_A, IN_T)
		_tw.tween_interval(HOLD)
		_tw.tween_method(_amount, 1.0, 0.0, OUT_T)
		if cloth:
			_tw.parallel().tween_property(cloth, "modulate:a", 1.0, OUT_T)
	_tw.tween_callback(func():
		active = false
		visible = false)


func _amount(v: float) -> void:
	mat.set_shader_parameter("amount", v)


func total_time() -> float:
	return IN_T + HOLD + OUT_T
