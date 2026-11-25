extends Control

# V10SilkSheet demo (scripts/v10/hudfx/demo/silk_sheet_demo.tscn): the real «Чайная» (V10HudHome, hero mc) with the
# pause sheet «Пауза» (three V10Plate M rows + a V10Button secondary) opening over it on the real snapshot.
# User args (after --):
#   --shots=<abs dir>   before, mid-open, open, closing, after → <dir>/<fx>_<name>.png, then quit
#   --fx=full|mid|min   V10Hud2Util.fx_override
#   --insets=48,24      simulated safe insets (top, bottom)
#   --selftest=1        V10HudFxSilkSheetTest → «HUDFX SILK_SHEET SELFTEST passed/total», exit code = failures
# Without --shots: the sheet opens after 1 s; tap the phone icon to open it again, outside / «Продолжить» to close.

var args: = {}
var home: V10HudHome
var sheet: V10SilkSheet
var fx: = "full"
var _shot_dir: = ""


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv: = a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if args.has("fx"):
		V10Hud2Util.fx_override = str(args.fx)
	fx = V10HudFx.level()
	if args.has("insets"):
		var p: PackedStringArray = str(args.insets).split(",")
		V10Hud2Util.sim_insets = {"top": float(p[0]), "bottom": float(p[1])}
	if args.has("selftest"):
		var r: Dictionary = await V10HudFxSilkSheetTest.run(self)
		for l in r.lines:
			print("  FAIL ", l)
		print("HUDFX SILK_SHEET SELFTEST %d/%d" % [r.passed, r.passed + r.failed])
		get_tree().quit(int(r.failed))
		return
	home = V10HudHome.new()
	home.configure({"hero": "mc", "nick": "Гость", "level": "1-4", "path": "Чайный сад", "affinity": 6})
	add_child(home)
	home.phone_pressed.connect(open_pause)
	_shot_dir = str(args.get("shots", ""))
	if _shot_dir != "":
		_run_shots()
	else:
		get_tree().create_timer(1.0).timeout.connect(open_pause)


func pause_content() -> Control:
	# 672 × 352 under the title: rows at 0 / 88 / 176, «Продолжить» at 272 (grid 8)
	var c: = Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rows: = [["sound", "Звук", "Вкл"], ["settings", "Эффекты: полные", ""], ["back", "Выйти из партии", ""]]
	for i in rows.size():
		var p: = V10Plate.make("M", 672, rows[i][1], "", "", rows[i][0])
		p.on_art = false
		p.interactive = true
		p.position = Vector2(0, i * 88)
		if rows[i][2] != "":
			var st: = V10Type.label(rows[i][2], "ui", 18, V10DS.PAPER_500)
			st.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			st.custom_minimum_size = Vector2(96, 26)
			p.right_slot = st
		if i == 2:
			p.pressed.connect(func() -> void:
				if is_instance_valid(sheet):
					sheet.close())
		c.add_child(p)
	var b: = V10Button.make("secondary", "Продолжить", Vector2(672, 80))
	b.position = Vector2(0, 272)
	b.pressed.connect(func() -> void:
		if is_instance_valid(sheet):
			sheet.close())
	c.add_child(b)
	return c


func open_pause() -> void:
	sheet = V10SilkSheet.open(self, pause_content(), 472, {"title": "Пауза", "dismiss_outside": true, "tone": 0.5})


# ------------------------------------------------------------------ shots (deterministic: the tween is stepped by hand)

func _run_shots() -> void:
	DirAccess.make_dir_recursive_absolute(_shot_dir)
	await _wait(1.0)  # the heroine rig settles, fonts and textures are uploaded
	await _shot("before")
	open_pause()
	while is_instance_valid(sheet) and sheet.state != "opening":
		await get_tree().process_frame
	var tw: = sheet.tween()
	tw.pause()
	tw.custom_step(0.06 if fx == "min" else 0.03)  # QUINT_OUT at 30 ms ≈ 52 % of the way
	await _shot("mid_open")
	tw.play()
	await sheet.opened
	await _wait(0.3)
	await _shot("open")
	sheet.close()
	var tc: = sheet.tween()
	tc.pause()
	tc.custom_step(0.06 if fx == "min" else 0.135)  # QUINT_IN at 135 ms ≈ 43 % of the way down
	await _shot("closing")
	tc.play()
	await sheet.closed
	await _wait(0.2)
	await _shot("after")
	print("silk_sheet demo: captures=%d last_ms=%s" % [V10SilkSheet.captures, V10SilkSheet.last_ms])
	get_tree().quit(0)


func _wait(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: = get_viewport().get_texture().get_image()
	var path: = "%s/%s_%s.png" % [_shot_dir, fx, name]
	img.save_png(path)
	print("shot ", path)
