extends Node2D




const TEX_BODY: = preload("res://assets/v06/flip/tile_back.png")
const TEX_TRIM: = preload("res://assets/v06/flip/tile_back_trim.png")
const SHADER: = preload("res://shaders/v06/flip/tile_back.gdshader")

var body: Sprite2D
var trim: Sprite2D
var halo: Sprite2D
var mat: ShaderMaterial
var is_ready: = false
var _halo_tw: Tween

func build(look: Dictionary) -> void :
	var c: Color = look.get("back", look.get("side", Color("e8789f")))
	if c.get_luminance() < 0.22:
		c = c.lightened(0.16)
	mat = ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("phase", randf() * 10.0)
	halo = Sprite2D.new()
	halo.texture = G.fx("tile_glow")
	halo.scale = Vector2(Tile.S, Tile.S) * 1.08
	halo.material = Fx.add_mat()
	halo.modulate = Color(1.0, 0.8, 0.4, 0.0)
	add_child(halo)
	body = Sprite2D.new()
	body.texture = TEX_BODY
	body.scale = Vector2(Tile.S, Tile.S)
	body.modulate = c
	body.material = mat
	add_child(body)
	trim = Sprite2D.new()
	trim.texture = TEX_TRIM
	trim.scale = Vector2(Tile.S, Tile.S)
	trim.material = mat
	add_child(trim)

func set_ready(on: bool) -> void :
	if on == is_ready:
		return
	is_ready = on
	if _halo_tw:
		_halo_tw.kill()
	var m: = mat
	create_tween().tween_method( func(v): m.set_shader_parameter("ready", v), 0.0 if on else 1.0, 1.0 if on else 0.0, 0.3)
	if on:
		_halo_tw = create_tween().set_loops()
		_halo_tw.tween_property(halo, "modulate:a", 0.55, 0.7).set_trans(Tween.TRANS_SINE)
		_halo_tw.tween_property(halo, "modulate:a", 0.12, 0.7).set_trans(Tween.TRANS_SINE)
	else:
		_halo_tw = create_tween()
		_halo_tw.tween_property(halo, "modulate:a", 0.0, 0.2)

func set_flash(v: float) -> void :
	mat.set_shader_parameter("flash", v)
