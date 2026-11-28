extends SceneTree

# P41 rig measurement. Usage (project = game/ or a scratch copy that holds assets/v10/rig + scripts/v10/rig):
#   godot --headless --path <proj> -s res://../tools/rigs/measure.gd -- rig=mc_gown frames=600 out=/tmp/m.json
# (copy this file into the project or pass an absolute path to -s)
# Prints one line:  RIGMEASURE {json}
# Metrics (all honest about headless limits):
#   nodes / polys / sprites / vertices / triangles  structure of the instantiated rig
#   textures_unique, tex_mem_rgba_mb, tex_mem_rgba_mips_mb   GPU memory if every referenced texture is uploaded as RGBA8 (+33% mips)
#   tex_mem_vram_*  GPU memory if VRAM-compressed (ASTC 4x4 = 1 byte/px, ETC2 RGBA = 1 byte/px) incl. mips
#   draw_items_upper  one canvas item per visible textured node = upper bound of draw calls without batching
#   draw_calls_gl     Performance RENDER_TOTAL_DRAW_CALLS_IN_FRAME, only non-zero with a real GL driver (xvfb + llvmpipe)
#   cpu_ms_rig_process  mean wall time of one V10LiveRig._process(1/60) call (script cost of the rig), this CPU

var _rig: Node
var _frames := 0
var _n := 600
var _t0 := 0
var _out := ""
var _rig_id := "mc_gown"
var _tp := 0.0
var _tp_n := 0
var _dc := 0
var _dc_max := 0
var _dc_n := 0
var _wall := 0
var _warm := 60
var _res := {}


func _args() -> Dictionary:
	var d := {}
	for a in OS.get_cmdline_user_args():
		var kv := String(a).split("=", true, 1)
		if kv.size() == 2:
			d[kv[0]] = kv[1]
	return d


func _initialize() -> void:
	var a := _args()
	_rig_id = a.get("rig", "mc_gown")
	_n = int(a.get("frames", "600"))
	_out = a.get("out", "")
	if _rig_id == "none":  # empty-scene baseline for the draw-call count
		_rig = Node2D.new()
		root.add_child(_rig)
		_t0 = Time.get_ticks_usec()
		return
	var scn := load("res://assets/v10/rig/%s/rig.tscn" % _rig_id) as PackedScene
	_rig = scn.instantiate()
	_rig.set("gesture_seed", 7)
	root.add_child(_rig)
	# same framing as the game stage: 720x1280 viewport, figure ~ 0.7 of height
	_rig.position = Vector2(360 - 581 * 0.645, 1292 - 1400 * 0.645)
	_rig.scale = Vector2.ONE * 0.645
	_t0 = Time.get_ticks_usec()


func _structure(rig: Node) -> Dictionary:
	var polys := 0
	var sprites := 0
	var verts := 0
	var tris := 0
	var nodes := 0
	var bones := 0
	var texs := {}
	var draw_items := 0
	var stack := [rig]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		nodes += 1
		for c in n.get_children():
			stack.append(c)
		if n is Bone2D:
			bones += 1
		if n is Polygon2D:
			polys += 1
			verts += (n as Polygon2D).polygon.size()
			for p in (n as Polygon2D).polygons:
				tris += 1 if (p as PackedInt32Array).size() >= 3 else 0
			var t: Texture2D = (n as Polygon2D).texture
			if t:
				texs[t.resource_path] = t
			if (n as Polygon2D).visible:
				draw_items += 1
		elif n is Sprite2D:
			sprites += 1
			var t2: Texture2D = (n as Sprite2D).texture
			if t2:
				texs[t2.resource_path] = t2
			# face patches start invisible (modulate.a 0); count them as potentially drawn (worst case)
			draw_items += 1
			var m: Material = (n as Sprite2D).material
			if m is ShaderMaterial:
				for p in ["iris_tex"]:
					var it = (m as ShaderMaterial).get_shader_parameter(p)
					if it is Texture2D:
						texs[(it as Texture2D).resource_path] = it
	var px := 0
	var rgba := 0.0
	var vram := 0.0
	var per := []
	for k in texs:
		var t3: Texture2D = texs[k]
		var w := t3.get_width()
		var h := t3.get_height()
		px += w * h
		rgba += w * h * 4.0
		vram += w * h * 1.0
		per.append({"tex": String(k).get_file(), "w": w, "h": h})
	return {
		"nodes": nodes, "bones": bones, "polys": polys, "sprites": sprites, "vertices": verts, "triangles": tris,
		"textures_unique": texs.size(), "tex_pixels": px,
		"tex_mem_rgba_mb": snappedf(rgba / 1048576.0, 0.01),
		"tex_mem_rgba_mips_mb": snappedf(rgba * 4.0 / 3.0 / 1048576.0, 0.01),
		"tex_mem_vram_mips_mb": snappedf(vram * 4.0 / 3.0 / 1048576.0, 0.01),
		"draw_items_upper": draw_items + 1,  # + hearts/bg handled below
		"textures": per,
	}


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 2 and _rig_id != "none":
		_res = _structure(_rig)  # after _ready of the rig (face sprites are created there)
		_res["rig"] = _rig_id
	if _frames == _warm:
		_wall = Time.get_ticks_usec()
	if _frames > _warm:
		_tp_n += 1
		if _rig.has_method("_process") and _rig_id != "none":
			var t := Time.get_ticks_usec()
			_rig._process(1.0 / 60.0)  # an extra step on top of the engine's own: pure script cost of the rig
			_tp += (Time.get_ticks_usec() - t) / 1000000.0
		var dc := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		_dc += dc
		_dc_max = maxi(_dc_max, dc)
		_dc_n += 1
	# fire a gesture every 120 frames so the measured frames include gesture motion
	if _frames % 120 == 30 and _rig.has_method("gesture"):
		var g: Array = ["hip_pop", "lean_in", "air_kiss", "tail_flick", "shoulder_roll", "hair_touch"]
		_rig.call("gesture", g[(_frames / 120) % g.size()])
	if _frames >= _warm + _n:
		var wall_ms := (Time.get_ticks_usec() - _wall) / 1000.0
		_res["rig"] = _rig_id
		_res["frames"] = _n
		_res["cpu_ms_rig_process"] = snappedf((_tp / maxf(_tp_n, 1)) * 1000.0, 0.001)
		_res["cpu_ms_rig_process_note"] = "wall time of one V10LiveRig._process(1/60) call on THIS machine (x86 cloud core); a Mali-class phone core is roughly 3-6x slower [NP]"
		_res["wall_ms_per_frame_headless"] = snappedf(wall_ms / _n, 0.001)
		_res["draw_calls_gl_mean"] = snappedf(float(_dc) / maxf(_dc_n, 1), 0.1)
		_res["draw_calls_gl_max"] = _dc_max
		_res["gl_texture_mem_mb"] = snappedf(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0, 0.01)
		_res["video_mem_mb"] = snappedf(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, 0.01)
		_res["rendering_driver"] = RenderingServer.get_current_rendering_driver_name()
		_res["rendering_method"] = RenderingServer.get_current_rendering_method()
		var line := "RIGMEASURE " + JSON.stringify(_res)
		print(line)
		if _out != "":
			var f := FileAccess.open(_out, FileAccess.WRITE)
			f.store_string(JSON.stringify(_res, "  "))
		quit(0)
	return false
