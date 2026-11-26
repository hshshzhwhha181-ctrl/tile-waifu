class_name V10RigSheen
extends Node

# Specular legwear sheen sweep for V10LiveRig (docs/LEGWEAR.md §4.2, §5.1; scripts/v10/rig/DATA.md).
# Duplicates the target skinned Polygon2D layer inside Figure/Art right above the source layer so it shares the
# exact Skeleton2D deformation and layer occlusion (e.g. dress slit over Layer_thigh), never renders above knee_y,
# and stays strictly warm (value <= 0.80, alpha <= 0.85, <= 1 active sweep).
#
#   var sheen = V10RigSheen.attach(rig, gestures.shaders.sheen)
#   sheen.sweep()                        # one pass now (1.6 = fever boost)
#   sheen.auto_period = Vector2(8, 12)   # automatic passes every 8-12 s; Vector2.ZERO = off
#   sheen.enabled = false                # FX «Минимум» or Yandex alt_rect framing

const SHADER_PATH: = "res://scripts/v10/rig/v10_sheen.gdshader"

var enabled: bool = true:
	set(v):
		enabled = v
		if not enabled:
			_phase = -1.0
			if _mesh != null and is_instance_valid(_mesh):
				_mesh.visible = false
			if _mat != null:
				_mat.set_shader_parameter("phase", -1.0)

var auto_period: Vector2 = Vector2(8.0, 12.0)
var dur: float = 0.6
var base_strength: float = 0.35
var knee_y: float = 1290.0

var _rig: Node2D
var _mesh: Polygon2D
var _mat: ShaderMaterial
var _phase: float = -1.0
var _mult: float = 1.0
var _next_auto: float = 9.0
var _rng: = RandomNumberGenerator.new()
var _legs_set: = {}


static func attach(rig: Node2D, cfg: Dictionary) -> V10RigSheen:
	if rig == null or cfg.is_empty():
		return null
	var art: Node2D = rig.get_node_or_null("Figure/Art") as Node2D
	if art == null:
		return null
	var layer_key: String = str(cfg.get("layer", "body"))
	var node_name: String = "Body" if layer_key == "body" else ("Layer_" + layer_key)
	var src: Polygon2D = art.get_node_or_null(node_name) as Polygon2D
	if src == null or src.texture == null:
		return null
	var def_p: String = str(rig.get("def_path"))
	if def_p == "":
		return null
	var rig_dir: String = def_p.get_base_dir()
	var mask_file: String = str(cfg.get("mask", "sheen_mask.png"))
	var mask_path: String = rig_dir.path_join(mask_file)
	var mask_tex: Texture2D = _load_tex(mask_path)
	if mask_tex == null:
		return null
	if mask_tex.get_size() != src.texture.get_size():
		return null
	var sh_res: Shader = load(SHADER_PATH) as Shader
	if sh_res == null:
		return null

	var origin: = Vector2.ZERO
	var meta_path: String = rig_dir.path_join("layers_meta.json")
	if FileAccess.file_exists(meta_path):
		var meta = JSON.parse_string(FileAccess.get_file_as_string(meta_path))
		if meta is Dictionary and meta.has(layer_key):
			var o: Array = meta[layer_key].get("origin", [0, 0])
			if o.size() >= 2:
				origin = Vector2(float(o[0]), float(o[1]))

	var sh: = V10RigSheen.new()
	sh.name = "V10RigSheen"
	sh._rig = rig
	sh._rng.randomize()
	sh.knee_y = float(cfg.get("knee_y", 1290.0))
	sh.dur = maxf(float(cfg.get("dur", 0.6)), 0.1)
	sh.base_strength = clampf(float(cfg.get("strength", 0.35)), 0.0, 0.85)
	var per: Array = cfg.get("period", [8.0, 12.0])
	if per.size() >= 2:
		sh.auto_period = Vector2(float(per[0]), float(per[1]))
	sh._schedule_next()

	var from_a: Array = cfg.get("from", [600.0, sh.knee_y])
	var to_a: Array = cfg.get("to", [600.0, 1396.0])
	var col_a: Array = cfg.get("color", [0.80, 0.74, 0.64])
	var col: = Vector3(
		minf(float(col_a[0]) if col_a.size() > 0 else 0.80, 0.80),
		minf(float(col_a[1]) if col_a.size() > 1 else 0.74, 0.80),
		minf(float(col_a[2]) if col_a.size() > 2 else 0.64, 0.80)
	)

	var mat: = ShaderMaterial.new()
	mat.shader = sh_res
	mat.set_shader_parameter("mask_tex", mask_tex)
	mat.set_shader_parameter("layer_origin", origin)
	mat.set_shader_parameter("knee_y", sh.knee_y)
	mat.set_shader_parameter("band_from", Vector2(float(from_a[0]), float(from_a[1])))
	mat.set_shader_parameter("band_to", Vector2(float(to_a[0]), float(to_a[1])))
	mat.set_shader_parameter("band_width", maxf(float(cfg.get("width", 18.0)), 2.0))
	mat.set_shader_parameter("strength", sh.base_strength)
	mat.set_shader_parameter("sheen_color", col)
	mat.set_shader_parameter("phase", -1.0)
	sh._mat = mat

	var mesh: = Polygon2D.new()
	mesh.name = node_name + "_Sheen"
	mesh.texture = src.texture
	mesh.texture_filter = src.texture_filter
	mesh.polygon = src.polygon
	mesh.uv = src.uv
	mesh.polygons = src.polygons
	mesh.internal_vertex_count = src.internal_vertex_count
	mesh.skeleton = NodePath("../Skeleton")
	mesh.clear_bones()
	for bi in src.get_bone_count():
		mesh.add_bone(src.get_bone_path(bi), src.get_bone_weights(bi))
	mesh.material = mat
	mesh.visible = false
	art.add_child(mesh)
	art.move_child(mesh, src.get_index() + 1)
	sh._mesh = mesh

	var g_path: String = rig_dir.path_join("gestures.json")
	if FileAccess.file_exists(g_path):
		var gd = JSON.parse_string(FileAccess.get_file_as_string(g_path))
		if gd is Dictionary:
			for g in gd.get("gestures", []):
				if g is Dictionary and bool(g.get("legs", false)):
					sh._legs_set[str(g.get("name", ""))] = true
	for gn in cfg.get("legs_gestures", []):
		sh._legs_set[str(gn)] = true
	if rig.has_signal("gesture_started"):
		rig.connect("gesture_started", sh._on_gesture_started)

	rig.add_child(sh)
	return sh


static func _load_tex(res_path: String) -> Texture2D:
	if ResourceLoader.exists(res_path):
		var t = load(res_path)
		if t is Texture2D:
			return t
	if FileAccess.file_exists(res_path):
		var img: = Image.load_from_file(ProjectSettings.globalize_path(res_path))
		if img != null and not img.is_empty():
			return ImageTexture.create_from_image(img)
	return null


func sweep(mult: float = 1.0) -> void:
	if not enabled or _mesh == null or _mat == null:
		return
	_mult = clampf(mult, 0.1, 2.2)
	_phase = 0.001
	_mat.set_shader_parameter("strength", minf(base_strength * _mult, 0.85))
	_mat.set_shader_parameter("phase", _phase)
	_mesh.visible = true
	_schedule_next()


func is_sweeping() -> bool:
	return _phase > 0.0 and _phase < 1.0


func _on_gesture_started(g_name: String) -> void:
	if enabled and _legs_set.has(g_name):
		sweep(1.0)


func _schedule_next() -> void:
	if auto_period.x > 0.0 and auto_period.y >= auto_period.x:
		_next_auto = _rng.randf_range(auto_period.x, auto_period.y)
	else:
		_next_auto = -1.0


func _process(delta: float) -> void:
	if not enabled or _mesh == null or not is_instance_valid(_mesh):
		return
	if _phase > 0.0 and _phase < 1.0:
		_phase += delta / maxf(dur, 0.1)
		if _phase >= 1.0:
			_phase = -1.0
			_mesh.visible = false
			_mat.set_shader_parameter("phase", -1.0)
		else:
			_mat.set_shader_parameter("phase", _phase)
		return
	if auto_period.x > 0.0 and auto_period.y >= auto_period.x:
		_next_auto -= delta
		if _next_auto <= 0.0:
			sweep(1.0)


func _exit_tree() -> void:
	if _mesh != null and is_instance_valid(_mesh):
		_mesh.queue_free()
		_mesh = null
