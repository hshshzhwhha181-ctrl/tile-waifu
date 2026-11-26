extends Node
func _ready():
	_run.call_deferred()

func _run():
	var lv = V10MjCubeGen.build(int(OS.get_environment("FIG")) if OS.get_environment("FIG") != "" else 8)
	var r = V10MjCubeRules.make(lv.cells, lv.faces)
	var bg = ColorRect.new()
	bg.color = Color("1b171c")
	bg.size = Vector2(720, 1280)
	get_tree().root.add_child(bg)
	var v = V10MjCubeView.new()
	v.position = Vector2(0, 280)
	get_tree().root.add_child(v)
	v.setup(lv, r, {"hero": "nova"})
	for k in 6:
		await get_tree().process_frame
	var img = get_viewport().get_texture().get_image()
	img.save_png("/tmp/claude-0/-home-user/0f6ceff0-d0e6-5e20-ba26-6ca740f91944/scratchpad/cube/v0.png")
	# take a few pairs from the certificate and select one
	for k in 6:
		var p = lv.order[k]
		r.take(p[0], p[1])
		v.refresh_tile(p[0]); v.refresh_tile(p[1])
	v.set_view(0.9, -0.5)
	var nx = lv.order[6]
	v.set_selected(nx[0], true)
	v.set_hint([nx[1]])
	for k in 12:
		await get_tree().process_frame
	img = get_viewport().get_texture().get_image()
	img.save_png("/tmp/claude-0/-home-user/0f6ceff0-d0e6-5e20-ba26-6ca740f91944/scratchpad/cube/v1.png")
	print("atlas ms ", V10MjCubeAtlas.bake_ms, " pick center ", v.pick(Vector2(360, 360)))
	var at = v.mat.get_shader_parameter("atlas")
	print("atlas tex ", at, " ", at.get_size() if at else null)
	at.get_image().save_png("/tmp/claude-0/-home-user/0f6ceff0-d0e6-5e20-ba26-6ca740f91944/scratchpad/cube/atlas.png")
	print(V10MjCubeAtlas.resolve_look({}, "nova"))
	get_tree().quit()
