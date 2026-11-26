extends Control

# V10VictoryStars demo (scripts/v10/hudfx/demo/victory_stars_demo.tscn): the real victory beat 1 (V10HudVictory,
# hero "mc") with the hudfx stars placed exactly over hud2's vector stars — hud2's own stars are hidden here
# (demo only; in the game the hud_victory.gd hook does it). User args (after --):
#   --stars=0..3          earned stars of the interactive run (default 3; tap anywhere to replay)
#   --fx=full|mid|min     V10Hud2Util.fx_override
#   --calm=1              «Без тряски и вспышек» (G.S.a11y_calm)
#   --zoom=1              art review: the row again at 3.5× (static 2/3) on night.900 and over the art
#   --shots=<abs dir>     PNGs of the key moments (3/3 star 2 landing, finals 3/3 · 2/3 · 0/3), then quit
#   --selftest=1          V10HudFxVictoryStarsTest → "HUDFX VICTORY_STARS SELFTEST passed/total", exit = failures

var args: = {}
var vic: V10HudVictory
var stars: V10VictoryStars
var earned: = 3


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv: = a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if args.has("fx"):
		V10Hud2Util.fx_override = str(args.fx)
	if args.has("calm") and G.S is Dictionary:
		G.S["a11y_calm"] = str(args.calm) == "1"
	if args.has("selftest"):
		var r: Dictionary = await V10HudFxVictoryStarsTest.run(self)
		for l in r.lines:
			print(l)
		print("HUDFX VICTORY_STARS SELFTEST %d/%d" % [r.passed, int(r.passed) + int(r.failed)])
		get_tree().quit(int(r.failed))
		return
	earned = clampi(int(args.get("stars", "3")), 0, 3)
	_scene(earned)
	if args.has("zoom"):
		_zoom()
	if args.has("shots"):
		_shots(str(args.shots))


func _zoom() -> void:
	var plate: = ColorRect.new()
	plate.color = V10DS.NIGHT_900
	plate.position = Vector2(0, 96)
	plate.size = Vector2(720, 240)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(plate)
	for y in [116.0, 356.0]:
		var big: = V10VictoryStars.new()
		big.position = Vector2(8, y)
		add_child(big)
		big.configure([Vector2(100, 100), Vector2(352, 100), Vector2(604, 100)], 196.0)
		big.show_static(2)


func _scene(n: int) -> void:
	if is_instance_valid(vic):
		vic.free()
	vic = V10HudVictory.new()
	vic.configure({"hero": "mc", "level": "1-4 · Чайный сад", "stars": n, "next": 5})
	add_child(vic)
	# stand-in for the hud_victory.gd hook: hud2's vector stars off, ours exactly over their slots, played in the
	# «Вдох» slot of the stars row (index 1 of V10HudVictory._enter: 0.3 + 1 · 40 ms)
	vic.stars_c.visible = false
	stars = V10VictoryStars.new()
	stars.position = (vic.L.stars as Rect2).position
	vic.add_child(stars)
	vic.move_child(stars, vic.stars_c.get_index() + 1)
	stars.configure([Vector2(28, 28), Vector2(100, 28), Vector2(172, 28)], 56.0)
	stars.play(n, 0.3 + 1 * V10DS.T_IN_STEP)


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and not args.has("shots"):
		_scene(earned)


# ------------------------------------------------------------------ shots

func _shots(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var lv: = V10HudFx.level()
	var tag: = lv + ("_calm" if V10HudFx.calm() else "")
	if lv == "min":
		await _freeze(stars.delay + V10HudFx.T_MIN * 0.5, dir, tag + "_3of3_fade")
	else:
		await _freeze(stars.land_time(1) + 0.035, dir, tag + "_3of3_land2_a")
		await _freeze(stars.land_time(1) + 0.11, dir, tag + "_3of3_land2_b")
		await _freeze(stars.land_time(2) + 0.16, dir, tag + "_3of3_land3")
	await _done()
	await _shot(dir, tag + "_3of3_final")
	for n in [2, 0]:
		_scene(n)
		await _done()
		await _shot(dir, "%s_%dof3_final" % [tag, n])
	get_tree().quit(0)


# hold the beat at an exact moment (deterministic frame), shoot, then let it run on
func _freeze(at: float, dir: String, name: String) -> void:
	while stars.playing and stars.t < at - 0.1:
		await get_tree().process_frame
	stars.seek(at, true)
	await _shot(dir, name)
	stars.set_process(true)


func _done() -> void:
	if stars.playing:
		await stars.finished
	for i in 3:
		await get_tree().process_frame


func _shot(dir: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var path: = "%s/%s.png" % [dir, name]
	get_viewport().get_texture().get_image().save_png(path)
	print("shot ", path)
