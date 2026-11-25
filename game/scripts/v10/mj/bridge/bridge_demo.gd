extends Control

# Демо и снимки дорожки «Мост» (MODES §4.5, §7.1). Под xvfb в 720×1280 и 1080×2400:
#   godot --path game --rendering-driver opengl3 --audio-driver Dummy --resolution 720x1280 \
#     res://scripts/v10/mj/bridge/bridge_demo.tscn -- --shots=<dir> [--only=daily|hand] [--icons=1]
#   --icons=1   запечь иконки режимов 512×512 в assets/v10/mj/bridge/ (icon_daily.png, icon_hand.png)
# Без --shots открывает «Задачу дня» (ручная игра); «Готово» → «Собери руку».

const DAY: = "2027-01-12"
const SCHOOL_DAY: = "2027-01-03"
const HAND_LEVEL: = 21

var shots: = ""
var only: = ""
var tag: = ""
var icons: = false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots = a.split("=")[1]
		elif a.begins_with("--only="):
			only = a.split("=")[1]
		elif a == "--icons=1":
			icons = true
	tag = "%dx%d" % [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y]
	if icons:
		await _bake_icons()
		if shots == "":
			get_tree().quit()
			return
	if shots == "":
		_open_daily(DAY)
		return
	DirAccess.make_dir_recursive_absolute(shots)
	await _run()
	get_tree().quit()


func _open_daily(day: String) -> void:
	_clear_now()
	var s: = V10MjBridgeDailyScreen.new()
	add_child(s)
	s.setup(null, {"day": day, "demo": true, "replay": true})
	s.finished.connect(func(_r): _open_hand(HAND_LEVEL))


func _open_hand(level: int) -> void:
	_clear_now()
	var s: = V10MjBridgeHandScreen.new()
	add_child(s)
	s.setup(null, {"level": level, "demo": true})
	s.finished.connect(func(r):
		_open_hand(mini(level + 1, V10MjBridgeLevels.COUNT) if String(r.get("action", "")) == "next" else level))


func _clear_now() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _shot(name: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: = get_viewport().get_texture().get_image()
	var p: = "%s/%s_%s.png" % [shots, name, tag]
	img.save_png(p)
	print("SHOT ", p)


func _clear() -> void:
	_clear_now()
	await get_tree().process_frame


func _run() -> void:
	if only == "" or only == "daily":
		await _run_daily()
	if only == "" or only == "hand":
		await _run_hand()


# ── Задача дня ───────────────────────────────────────────────────────────────

func _run_daily() -> void:
	# «Школа стола»: подсказка формы
	var s0: = V10MjBridgeDailyScreen.new()
	add_child(s0)
	s0.setup(null, {"day": SCHOOL_DAY, "demo": true, "replay": true})
	await _wait(0.8)
	await _shot("daily_school")
	await _clear()
	# до ответа: выбрана фишка (не лучшая), «Сбросить» появился
	var s: = V10MjBridgeDailyScreen.new()
	add_child(s)
	s.setup(null, {"day": DAY, "demo": true, "replay": true, "demo_solved": 2, "demo_streak": 4,
		"demo_last": "2027-01-11", "demo_days": ["2027-01-03", "2027-01-05", "2027-01-08", "2027-01-09", "2027-01-10", "2027-01-11"]})
	await _wait(0.8)
	var a: = V10MjBridgeDaily.analysis_of(s.item)
	var wrong: = -1
	for t in s.tiles:
		var k: int = (t as V10MjBridgeTile).kind
		if not (a.best as Array).has(k):
			wrong = k
	s.select_kind(int(a.best[0]) if wrong < 0 else wrong)
	await _wait(0.4)
	await _shot("daily_before")
	# первая попытка мимо — отметка и подсказка; вторая — верно
	s.drop()
	await _wait(1.1)
	await _shot("daily_retry")
	s.select_kind(int(a.best[0]))
	await _wait(0.2)
	s.drop()
	await _wait(1.8)
	await _shot("daily_after")
	print("DEMO daily share=", JSON.stringify(s.result.get("share", "")), " rewards=", s.result.get("rewards"), " solved=", s.result.get("solved"), " opened=", s.result.get("riichi_opened"))
	await _clear()


# ── Собери руку ──────────────────────────────────────────────────────────────

func _run_hand() -> void:
	var s: = V10MjBridgeHandScreen.new()
	add_child(s)
	s.setup(null, {"level": HAND_LEVEL, "demo": true})
	await _wait(0.6)
	await _shot("hand_sheet")
	(s.sheet_layer.get_child(1).get_node("Play") as Button).pressed.emit()
	await _wait(1.0)
	await _shot("hand_start")
	var sv: = V10MjBridgeLevels.solve(s.lv, V10MjBridgeLevels.BOT_BUDGET)
	print("DEMO hand bot ok=", sv.ok, " moves=", (sv.path as Array).size())
	var shot_set: = false
	for m in sv.path:
		await _play_move(s, m)
		await _wait(0.32)
		if not shot_set and s.rules.sets.size() >= 2 and not s.rules.won:
			shot_set = true
			await _wait(0.2)
			# выбранная фишка руки — «Сброс» загорается
			for n in s.hand_nodes:
				if int((n as Node).get_meta("set", -1)) < 0:
					s.select_hand(n)
					break
			await _wait(0.2)
			await _shot("hand_set")
			if s.sel_node != null:
				s.select_hand(s.sel_node)
		if s.rules.won:
			break
	await _wait(0.9)
	await _shot("hand_win")
	await _wait(3.6)
	await _shot("hand_win_sheet")
	print("DEMO hand result=", JSON.stringify(s.result))
	await _clear()


func _play_move(s: V10MjBridgeHandScreen, m: Array) -> void:
	match String(m[0]):
		"take":
			s.tap(int(m[1]))
		"edge":
			s.tap_edge(int(m[1]))
		"dig":
			var k: int = s.rules.kind[int(m[1])]
			s.tap(int(m[1]))
			await _wait(0.3)
			if s.rules.won:
				return
			var si: = s.rules.where(k)
			for n in s.hand_nodes:
				var t: V10MjBridgeTile = n
				if t.kind == k and int(t.get_meta("set", -1)) == si:
					s.select_hand(t)
					break
			s.use_reset()


# ── иконки режимов ───────────────────────────────────────────────────────────

func _bake_icons() -> void:
	var dir: = ProjectSettings.globalize_path("res://assets/v10/mj/bridge")
	DirAccess.make_dir_recursive_absolute(dir)
	for k in ["mode_daily", "mode_hand"]:
		var vp: = SubViewport.new()
		vp.size = Vector2i(512, 512)
		vp.transparent_bg = true
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(vp)
		var ic: = V10MjBridgeIcon.new(k, V10MjBridgeLook.TOK.paper100)
		ic.size = Vector2(512, 512)
		vp.add_child(ic)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img: = vp.get_texture().get_image()
		var p: = dir.path_join("icon_%s.png" % k.trim_prefix("mode_"))
		img.save_png(p)
		print("ICON ", p)
		vp.queue_free()
