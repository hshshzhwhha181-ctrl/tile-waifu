extends Control

# Standalone runner of lane «meta» (touches neither main.gd nor the player's save):
#   selftest (headless):
#     flock /tmp/tw-godot.lock /opt/tw-tools/godot --headless --path game res://scripts/v10/meta/meta_runner.tscn \
#       -- --meta_selftest=1 --save=user://meta_runner.json --save_wipe=1 [--meta_grep_strict=1]
#   screenshots (xvfb, any --resolution; the store-guard check on the REAL shop screen runs here too):
#     flock /tmp/tw-godot.lock xvfb-run -a /opt/tw-tools/godot --path game --rendering-driver opengl3 \
#       --audio-driver Dummy --resolution 720x1280 res://scripts/v10/meta/meta_runner.tscn \
#       -- --meta_shots=<dir> --save=user://meta_runner.json --save_wipe=1 [--tag=720x1280]
#   Writes <dir>/<tag>_win_path.png, _win_end.png, _afisha.png, _afisha_stamp.png, _notify.png, _notify_on.png,
#   _shop_store.png, _shop_test.png; prints META_SHOTS ok and STORE_RUB_VISIBLE n. Exit 0 when all is well.

var shots: = ""
var tag: = "shot"
var W: = 720.0
var H: = 1280.0
var stage: Control
var errors: = 0


func _ready() -> void:
	var args: = OS.get_cmdline_user_args()
	var vs: = get_viewport_rect().size
	W = vs.x
	H = vs.y
	size = vs
	for a in args:
		if a.begins_with("--meta_shots="):
			shots = a.substr(13)
		elif a.begins_with("--tag="):
			tag = a.substr(6)
	if "--meta_selftest=1" in args:
		var f: = V10MetaSelftest.run("--meta_grep_strict=1" in args)
		get_tree().quit(1 if f > 0 else 0)
		return
	if shots == "":
		print("meta_runner: pass --meta_selftest=1 or --meta_shots=<dir>")
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(shots)
	_shots.call_deferred()


func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: = get_viewport().get_texture().get_image()
	var p: = "%s/%s_%s.png" % [shots, tag, name]
	img.save_png(p)
	print("SHOT ", p)


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _new_stage() -> Control:
	if stage and is_instance_valid(stage):
		stage.queue_free()
		await get_tree().process_frame
	stage = Control.new()
	stage.size = Vector2(W, H)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)
	return stage


func _shots() -> void:
	V10Meta.bind({})
	V10Afisha.bind({})
	V10Notify.log_path = "user://v10_logs/notify_runner.json"
	await _win_shot(true)
	await _win_shot(false)
	await _afisha_shot()
	await _notify_shot()
	await _shop_shot()
	print("META_SHOTS %s" % ("ok" if errors == 0 else "errors=%d" % errors))
	get_tree().quit(0 if errors == 0 else 1)


# ── victory: mock 0.9 plate + the real V10WinPanel under it ────────────────────────────────────────────────────
func _demo_bars() -> void:
	V10WinStack.clear()
	var salon: = func(_c, w):
		return V10WinBar.make(w, {"icon": "visits", "title": "Фонари у входа", "have": 4, "need": 4, "gain": 2,
			"kind": "stars", "ready_text": "Можно восстановить!"})
	var mastery: = func(_c, w):
		return V10WinBar.make(w, {"icon": "trophy", "title": "Мастерство II · Лунное платье", "have": 420, "need": 500,
			"gain": 80, "kind": "fill", "pal": "lav"})
	var pass_bar: = func(_c, w):
		return V10WinBar.make(w, {"icon": "rating", "title": "Пропуск сезона", "have": 60, "need": 100, "gain": 20,
			"kind": "fill", "pal": "pink"})
	V10WinStack.add_bar("salon", V10WinStack.PRIO_SALON, salon, {"modes": ["path"]})
	V10WinStack.add_bar("mastery", V10WinStack.PRIO_MASTERY, mastery)
	V10WinStack.add_bar("pass", V10WinStack.PRIO_PASS, pass_bar)
	V10WinStack.add_tick("streak", func(_c): return {"icon": "heart", "text": "Серия чая 4"}, {"order": 0})
	V10WinStack.add_tick("flame", func(_c): return {"icon": "gift", "text": "Огонёк 2"}, {"order": 1})
	V10WinStack.add_tick("path15", func(_c): return {"icon": "tasks", "text": "9/15"}, {"order": 2})


func _win_shot(path_open: bool) -> void:
	var s: = await _new_stage()
	_demo_bars()
	Common.backdrop(s, "victory", Vector2(W, H), 0.0, 0.7)
	Common.vignette(s, Vector2(W, H), Color(0.12, 0.03, 0.08), 0.6)
	var pw: = minf(W - 40.0, 660.0)
	var px: = (W - pw) * 0.5
	var top: = maxf(60.0, H * 0.06)
	var rib: = Common.ribbon(s, "Победа!", Rect2(W * 0.5 - 200, top, 400, 92), "pink", 54)
	UI.pop_in(rib, 0.0, 0.6)
	# a stand-in for the 0.9 plate (stamps, roll) — unchanged in 0.10, only for the picture
	var plate: = UI.rbox("cream", Rect2(px, top + 110, pw, 250), 30, 4, 12)
	plate.borders(Color("ffe7a6"), Color("b9802a"))
	s.add_child(plate)
	for i in 3:
		var st: = V8Art.star_rect(true, Rect2(pw * 0.5 - 150 + i * 105, 20 + (0 if i == 1 else 14), 90, 90))
		plate.add_child(st)
		UI.pop_in(st, 0.1 + 0.12 * i, 0.3)
	var rw: = UI.label("+ 240", 40, Color("ffd98a"), UI.DARK, 5, "title", 900)
	rw.position = Vector2(0, 130)
	rw.size = Vector2(pw, 50)
	rw.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plate.add_child(rw)
	plate.add_child(UI.tex(V8Art.cur("gem"), Rect2(pw * 0.5 - 120, 132, 44, 44)))
	var ln: = UI.label("Время 1:42 · без подсказок · Яку: Чистый стол", 18, UI.MUTED, UI.DARK, 3, "body", 800)
	ln.position = Vector2(0, 194)
	ln.size = Vector2(pw, 30)
	ln.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plate.add_child(ln)
	var ctx: = {"mode": "path", "level": 56 if path_open else 99, "count": 100, "stars_map": {},
		"salon_open": path_open, "first": true, "on_more": func(n): print("MORE ", n)}
	var panel: = V10WinPanel.make(ctx, pw)
	panel.position = Vector2(px, top + 110 + 250 + 22)
	s.add_child(panel)
	panel.play(0.5)
	if panel.position.y + panel.height() > H - 16:
		push_error("win panel overflows the screen: %f > %f" % [panel.position.y + panel.height(), H])
		errors += 1
	await _wait(3.6)
	await _snap("win_path" if path_open else "win_end")
	if path_open:
		# the 0.4 s wipe after «Ещё уровень», mid-sweep
		V10MoreLevel.wipe(s, func(): pass)
		await _wait(0.16)
		await _snap("win_wipe")
		await _wait(0.5)


# ── Афиша: wide on top of «Режимы» + compact in the home right slot ────────────────────────────────────────────
func _afisha_shot() -> void:
	var s: = await _new_stage()
	Common.backdrop(s, "menu", Vector2(W, H), 0.0, 0.85)
	Common.vignette(s, Vector2(W, H), Color(0.08, 0.03, 0.06), 0.55)
	V10Meta.set_now(int(Time.get_unix_time_from_datetime_string("2026-11-24T12:00:00")) - V10Meta.tz_bias_min() * 60)
	V10Afisha.set_provider("salon", func(): return {"open": true, "sub": "Фонари у входа · ★ 12 в банке"})
	V10Afisha.set_provider("hand", func(): return true)
	V10Afisha.set_provider("mode_open", func(_id): return true)
	var wide_w: = minf(W - 32.0, 688.0)
	var wide: = V10AfishaCard.make(Vector2(wide_w, 0))
	wide.position = Vector2((W - wide_w) * 0.5, 40)
	s.add_child(wide)
	UI.slide_in(wide, Vector2(0, 30), 0.0, 0.4)
	V10Afisha.set_provider("mode_open", Callable())
	V10Afisha.set_provider("salon", Callable())
	V10Afisha.set_provider("hand", Callable())
	var compact: = V10AfishaCard.make(Vector2(198, 0))
	compact.position = Vector2(W - 198 - 16, wide.position.y + wide.size.y + 40)
	s.add_child(compact)
	UI.slide_in(compact, Vector2(60, 0), 0.2)
	var cap: = UI.label("← слот главной (198 px), свежий сейв:\nзакрытые строки с подписью «откроется …»", 18, UI.INK, UI.DARK, 3, "body", 800)
	cap.position = Vector2(16, compact.position.y + 20)
	cap.size = Vector2(W - 198 - 48, 120)
	cap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	s.add_child(cap)
	wide.locked.connect(func(id, t): print("LOCKED ", id, " ", t))
	if compact.position.y + compact.size.y > H:
		push_error("afisha compact card overflows")
		errors += 1
	await _wait(1.0)
	await _snap("afisha")
	wide.stamp("daily")
	await _wait(0.1)
	wide.stamp("mode")
	await _wait(0.8)
	await _snap("afisha_stamp")


# ── Настройки → Уведомления ────────────────────────────────────────────────────────────────────────────────────
func _notify_shot() -> void:
	var s: = await _new_stage()
	V10Meta.bind({})
	V10Meta.set_now(int(Time.get_unix_time_from_datetime_string("2026-11-24T16:30:00")) - V10Meta.tz_bias_min() * 60)
	Common.backdrop(s, "bg_teahouse", Vector2(W, H), 6.0, 0.55)
	var pw: = minf(W - 40.0, 660.0)
	var box: = UI.rbox("cream", Rect2((W - pw) * 0.5, 80, pw, 900), 30, 4, 12)
	s.add_child(box)
	var t: = UI.title("Уведомления", 40, Color("ffe7c4"))
	t.position = Vector2(0, 20)
	t.size = Vector2(pw, 56)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	var p: = V10NotifyPanel.make(pw - 48)
	p.position = Vector2(24, 96)
	box.add_child(p)
	box.size.y = 96 + p.preferred_height() + 24
	await _wait(0.6)
	await _snap("notify")
	V10Notify.set_consent(true)
	V10Notify.request("salon", V10Meta.now_unix())
	p._build()
	box.size.y = 96 + p.preferred_height() + 24
	await _wait(0.4)
	await _snap("notify_on")


# ── Ф7 on the REAL shop screen ─────────────────────────────────────────────────────────────────────────────────
func _shop_shot() -> void:
	var s: = await _new_stage()
	G.S.tut_done = true
	G.S.intro_done = true
	G.S.profile_done = true
	var main: Control = load("res://main.tscn").instantiate()
	s.add_child(main)
	await get_tree().process_frame
	# drop the title splash main.gd adds after its first screen
	var past: = false
	for c in main.get_children():
		if past and c is Control and c.mouse_filter == Control.MOUSE_FILTER_STOP:
			c.queue_free()
		if c == main.get("finger"):
			past = true
	await _wait(0.3)
	main.busy = false
	await main.go("shop", {}, false)
	await _wait(1.2)
	var before: int = V10ShopGuard.visible_rub(main.screen).size()
	print("SHOP_RUB_BUTTONS_0.9 ", before)
	V10ShopGuard.force("test")
	V10ShopGuard.guard(main.screen)
	await _wait(0.3)
	await _snap("shop_test")
	main.busy = false
	main.screen_id = ""
	await main.go("shop", {}, false)
	await _wait(1.0)
	V10ShopGuard.force("store")
	V10ShopGuard.guard(main.screen)
	await _wait(0.3)
	var vis: = V10ShopGuard.visible_rub(main.screen).size()
	print("STORE_RUB_VISIBLE ", vis)
	if before == 0 or vis != 0:
		push_error("store guard: %d ₽ buttons before, %d visible after" % [before, vis])
		errors += 1
	await _snap("shop_store")
	V10ShopGuard.unforce()
