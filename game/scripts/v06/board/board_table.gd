class_name V6BoardTable
extends Node2D





const SHADER: = preload("res://shaders/v06/board/table.gdshader")

const THEMES: = {

	"play": {"frame_a": Color("6b3f2a"), "frame_b": Color("2a140d"), "trim": Color("e8c06a"), 
		"mat_a": Color("3f7d68"), "mat_b": Color("173c33"), "pat_col": Color("d9f0d4"), "pat_alpha": 0.075, "pattern": 1, "pat_scale": 54.0, 
		"fibre": 0.55, "lamp_col": Color("fff0d2"), "lamp_k": 0.32, "gloss": 1.0, "shadow": Color(0.04, 0.08, 0.06, 0.78), "ambient": Color("3a7a62")}, 

	"bg_teahouse": {"frame_a": Color("d8dde6"), "frame_b": Color("6f7b8f"), "trim": Color("f4f8ff"), 
		"mat_a": Color("5d7fa3"), "mat_b": Color("243a57"), "pat_col": Color("e8f4ff"), "pat_alpha": 0.09, "pattern": 4, "pat_scale": 40.0, 
		"fibre": 0.3, "lamp_col": Color("eaf4ff"), "lamp_k": 0.36, "gloss": 1.2, "shadow": Color(0.03, 0.06, 0.12, 0.78), "ambient": Color("6f98c8")}, 

	"bg_festival": {"frame_a": Color("2c1a1c"), "frame_b": Color("0c0507"), "trim": Color("f2c65f"), 
		"mat_a": Color("9c2a37"), "mat_b": Color("3e0b16"), "pat_col": Color("ffd38a"), "pat_alpha": 0.085, "pattern": 0, "pat_scale": 58.0, 
		"fibre": 0.75, "lamp_col": Color("ffd9a6"), "lamp_k": 0.38, "gloss": 1.0, "shadow": Color(0.12, 0.02, 0.04, 0.78), "ambient": Color("c8484f")}, 

	"bg_palace": {"frame_a": Color("3b2a55"), "frame_b": Color("120b22"), "trim": Color("e9cf8a"), 
		"mat_a": Color("33366f"), "mat_b": Color("0f1230"), "pat_col": Color("d8d4ff"), "pat_alpha": 0.08, "pattern": 2, "pat_scale": 48.0, 
		"fibre": 0.6, "lamp_col": Color("dfe2ff"), "lamp_k": 0.34, "gloss": 1.1, "shadow": Color(0.03, 0.02, 0.1, 0.78), "ambient": Color("5a5cb0")}, 

	"bg_shrine": {"frame_a": Color("6e2420"), "frame_b": Color("230807"), "trim": Color("f0c560"), 
		"mat_a": Color("1f4a44"), "mat_b": Color("0a1a19"), "pat_col": Color("e6c46e"), "pat_alpha": 0.07, "pattern": 3, "pat_scale": 44.0, 
		"fibre": 0.5, "lamp_col": Color("ffe2b8"), "lamp_k": 0.34, "gloss": 1.0, "shadow": Color(0.05, 0.02, 0.02, 0.78), "ambient": Color("3c7a6c")}, 

	"bg_neon": {"frame_a": Color("262a3d"), "frame_b": Color("07080f"), "trim": Color("49e3ff"), 
		"mat_a": Color("1c1d36"), "mat_b": Color("06060e"), "pat_col": Color("ff4fd8"), "pat_alpha": 0.1, "pattern": 5, "pat_scale": 52.0, 
		"fibre": 0.1, "neon": 1.0, "lamp_col": Color("c8f6ff"), "lamp_k": 0.26, "gloss": 1.35, "shadow": Color(0.0, 0.0, 0.03, 0.82), "ambient": Color("2f8fb0")}, 

	"default": {"frame_a": Color("3a3340"), "frame_b": Color("141017"), "trim": Color("e2bd72"), 
		"mat_a": Color("8a5468"), "mat_b": Color("35192a"), "pat_col": Color("ffe0ea"), "pat_alpha": 0.07, "pattern": 0, "pat_scale": 56.0, 
		"fibre": 0.65, "lamp_col": Color("ffe9d6"), "lamp_k": 0.34, "gloss": 1.0, "shadow": Color(0.1, 0.03, 0.08, 0.78), "ambient": Color("b06a86")}, 
}
const ALIAS: = {"bg_street": "default", "bg_rooftop": "default", "bg_gym": "default", "menu": "default"}

const FRAME: = 20.0
const PAD: = 10.0
const OUT: = 8.0
const MARGIN: = 44.0

static var enabled: = true

var rect: = ColorRect.new()
var mat: = ShaderMaterial.new()
var theme_id: = "default"

static func theme_for(bg: String) -> Dictionary:
	var k: String = ALIAS.get(bg, bg)
	return THEMES.get(k, THEMES["default"])


static func inset(r: Rect2) -> Rect2:
	if not enabled:
		return r
	var k: = FRAME + PAD - OUT
	return r.grow_individual( - k, - k - 2.0, - k, - k - 6.0)


static func attach(board: Node2D, r: Rect2) -> void :
	if not enabled or board == null:
		return
	var old: = board.get_node_or_null("V6Table")
	if old:
		old.free()
	var bg: = "default"
	var p: = board.get_parent()
	if p and p.get("cfg") is Dictionary:
		bg = String(p.cfg.get("bg", "default"))
	if p and p.get("mode") == "blitz":
		bg = "bg_festival"
	bg = V7Album.table_for(bg)
	var tb: = V6BoardTable.new()
	tb.name = "V6Table"
	board.add_child(tb)
	board.move_child(tb, 0)
	tb.setup(board, r, bg)

func setup(board: Node2D, r: Rect2, bg: String) -> void :
	var th: = theme_for(bg)
	theme_id = bg
	var s: float = board.scale.x

	var bb: Rect2 = board.get("bounds")
	var top: = board.position.y + bb.position.y * s
	var bot: = board.position.y + bb.end.y * s
	var k: = FRAME + PAD
	var tr: = Rect2(r.position.x - k, top - k, r.size.x + 2.0 * k, (bot - top) + 2.0 * k)

	var lim: = r.grow(k)
	tr = tr.intersection(lim) if tr.intersects(lim) else tr

	scale = Vector2.ONE / s
	position = (Vector2(tr.position.x, tr.position.y) - board.position) / s - Vector2(MARGIN, MARGIN)
	rect.size = tr.size + Vector2(MARGIN, MARGIN) * 2.0
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mat.shader = SHADER
	rect.material = mat
	add_child(rect)
	mat.set_shader_parameter("size", rect.size)
	mat.set_shader_parameter("margin", MARGIN)
	mat.set_shader_parameter("frame_w", FRAME)
	mat.set_shader_parameter("noise", load("res://assets/v06/board/table_noise.png"))
	for key in ["frame_a", "frame_b", "trim", "mat_a", "mat_b", "pat_col"]:
		mat.set_shader_parameter(key, th[key])
	mat.set_shader_parameter("pat_alpha", th.pat_alpha)
	mat.set_shader_parameter("pattern", th.pattern)
	mat.set_shader_parameter("pat_scale", th.pat_scale)
	mat.set_shader_parameter("fibre", th.fibre)
	mat.set_shader_parameter("neon", th.get("neon", 0.0))
	var lc: Color = th.lamp_col
	mat.set_shader_parameter("lamp_col", Vector3(lc.r, lc.g, lc.b))
	mat.set_shader_parameter("lamp_k", th.lamp_k)

	var lamp: = tr.position + tr.size * Vector2(0.33, 0.12) + Vector2(0, -60)
	V6TileLook.lamp = lamp
	V6TileLook.lamp_col = lc
	V6TileLook.gloss = th.gloss
	V6TileLook.ambient = th.ambient
	V6TileLook.shadow_col = th.shadow
	var tiles = board.get("tiles")
	if tiles is Array:
		V6TileLook.relight(tiles)

	var fl = board.get("floor_layer")
	if fl is Node2D:
		fl.visible = false

func _process(_d: float) -> void :
	mat.set_shader_parameter("t", G.time)
