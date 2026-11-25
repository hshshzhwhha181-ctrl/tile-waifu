extends Control

# Standalone runner of lane «meta» (touches neither main.gd nor the player's save):
#   selftest (headless):
#     flock /tmp/tw-godot.lock /opt/tw-tools/godot --headless --path game res://scripts/v10/meta/meta_runner.tscn \
#       -- --meta_selftest=1 --save=user://meta_runner.json --save_wipe=1 [--meta_grep_strict=1]
#   screenshots (xvfb, any --resolution; the store-guard check on the REAL shop screen runs here too):
#     flock /tmp/tw-godot.lock xvfb-run -a /opt/tw-tools/godot --path game --rendering-driver opengl3 \
#       --audio-driver Dummy --resolution 720x1280 res://scripts/v10/meta/meta_runner.tscn \
#       -- --meta_shots=<dir> --save=user://meta_runner.json --save_wipe=1 [--tag=720x1280] [--fx=min]
#   Writes <dir>/<tag>_win_path.png, _win_wipe.png, _win_end.png, _afisha.png, _afisha_stamp.png, _afisha_fresh.png,
#   _afisha_tables.png, _notify.png, _notify_on.png, _shop_test.png, _shop_store.png, _shop_store_gems.png;
#   prints one «UX_AUDIT <shot> …» line per lane screen (UX_RULES §10 «А» items: ux_role counts, type sizes,
#   hit zones < 80, tappables, words, jargon), «STORE_RUB_VISIBLE n» and «META_SHOTS ok». Exit 0 when all is well.
#   --fx=min runs everything with S.fx_level = "min" (UX §6.7: no motion, 120 ms fades) and tags the files «…_min».

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
	if "--fx=min" in args:
		G.set_fx_level("min")
		tag += "_min"
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


# UX_RULES §10 «А» numbers of one lane screen (the 0.9 stand-ins around it are not counted)
func _audit(name: String, root: Node, working: = true) -> void:
	var rl: = V10MetaUI.roles(root)
	var fs: = V10MetaUI.font_sizes(root)
	var small: = V10MetaUI.small_hits(root)
	var taps: = V10MetaUI.tappables(root).size()
	var words: = 0
	for t in V10MetaUI.texts(root):
		words += str(t).split(" ", false).size()
	var bad: = V10Lint.ui_scan(V10MetaUI.texts(root))
	print("UX_AUDIT %s roles=%s sizes=%s small_hits=%s taps=%d words=%d jargon=%s" % [name, str(rl), str(fs), str(small),
		taps, words, str(bad)])
	var max_fs: = 4 if working else 3
	if int(rl.primary) > 1 or int(rl.secondary) > 2 or int(rl.tertiary) > 2 or fs.size() > max_fs or \
			(not fs.is_empty() and int(fs[0]) < 15) or not small.is_empty() or taps > 10 or words > 60 or not bad.is_empty():
		push_error("UX_AUDIT %s out of budget" % name)
		errors += 1


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


# ── victory: mock 0.9 plate + the real V10WinPanel, bottom-anchored (HUD_V2 §8.3) ─────────────────────────────
func _demo_bars() -> void:
	V10WinStack.clear()
	var salon: = func(_c, w):
		return V10WinBar.make(w, {"icon": "visits", "title": "Фонари у входа", "have": 4, "need": 4, "gain": 2,
			"kind": "stars", "ready_text": "Можно восстановить!"})
	var mastery: = func(_c, w):
		return V10WinBar.make(w, {"icon": "trophy", "title": "Мастерство II · Лунное платье", "have": 420, "need": 500,
			"gain": 80, "kind": "fill", "pal": "jade", "sub": "ещё 80 пар"})
	var pass_bar: = func(_c, w):
		return V10WinBar.make(w, {"icon": "rating", "title": "Пропуск сезона", "have": 60, "need": 100, "gain": 20,
			"kind": "fill", "pal": "pink"})
	V10WinStack.add_bar("salon", V10WinStack.PRIO_SALON, salon, {"modes": ["path"]})
	V10WinStack.add_bar("mastery", V10WinStack.PRIO_MASTERY, mastery)
	V10WinStack.add_bar("pass", V10WinStack.PRIO_PASS, pass_bar)
	V10WinStack.add_tick("streak", func(_c): return {"icon": "heart", "text": "Серия чая · 4 дня"}, {"order": 0})
	V10WinStack.add_tick("flame", func(_c): return {"icon": "gift", "text": "Огонёк · 2"}, {"order": 1})
	V10WinStack.add_tick("path15", func(_c): return {"icon": "tasks", "text": "9 из 15 столов"}, {"order": 2})


func _win_shot(path_open: bool) -> void:
	var s: = await _new_stage()
	_demo_bars()
	Common.backdrop(s, "victory", Vector2(W, H), 0.0, 0.7)
	Common.vignette(s, Vector2(W, H), Color(0.12, 0.03, 0.08), 0.6)
	var pw: = minf(W - 48.0, 672.0)
	var px: = (W - pw) * 0.5
	var top: = maxf(60.0, H * 0.06)
	var rib: = Common.ribbon(s, "Победа!", Rect2(W * 0.5 - 200, top, 400, 92), "pink", 54)
	UI.pop_in(rib, 0.0, 0.6)
	# a stand-in for the 0.9 plate (stamps, roll) — HUD v2 replaces it (HUD_V2 §8.3 такт 1–2), only for the picture
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
	var ln: = UI.label("Время 1:42 · без подсказок · Комбинация: Чистый стол", 18, UI.MUTED, UI.DARK, 3, "body", 800)
	ln.position = Vector2(0, 194)
	ln.size = Vector2(pw, 30)
	ln.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plate.add_child(ln)
	var ctx: = {"mode": "path", "level": 56 if path_open else 99, "count": 100, "stars_map": {},
		"salon_open": path_open, "first": true, "on_more": func(n): print("MORE ", n)}
	var panel: = V10WinPanel.make(ctx, pw)
	panel.position = Vector2(px, H - 24.0 - panel.height())
	s.add_child(panel)
	panel.play(0.5)
	if panel.position.y < plate.position.y + plate.size.y + 12.0:
		push_error("win panel overlaps the 0.9 plate: %f < %f" % [panel.position.y, plate.position.y + plate.size.y])
		errors += 1
	var mb: Control = panel.more_btn
	if mb == null or panel.position.y + mb.position.y < H * 2.0 / 3.0:
		push_error("the primary button is not in the bottom third")
		errors += 1
	await _wait(3.6)
	_audit("win_path" if path_open else "win_end", panel)
	await _snap("win_path" if path_open else "win_end")
	if path_open:
		# the 0.4 s wipe after «Ещё уровень», mid-sweep (fx=min: the 120 ms night cover)
		V10MoreLevel.wipe(s, func(): pass)
		await _wait(0.16 if V9Feel.can_fx() else 0.1)
		await _snap("win_wipe")
		await _wait(0.5)


# ── Афиша: the «Сегодня» sheet (full day, stamps, fresh save) and the «Сегодня» block of Столы ────────────────
func _sheet(s: Control, title_h: float, content_h: float) -> Control:
	# a stand-in for the integrator's bottom sheet (UX §3.7: night.700, radius 4 on top, over the dimmed Чайная)
	var dim: = ColorRect.new()
	dim.color = Color(V10MetaUI.NIGHT_900, 0.55)
	dim.size = Vector2(W, H)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.add_child(dim)
	var sh: = content_h + title_h + 24.0 + 32.0
	var sheet: = V10MetaUI.plate(Rect2(0, H - sh, W, sh + 8), V10MetaUI.NIGHT_700, 1.0, false)
	s.add_child(sheet)
	var grip: = V10MetaUI.plate(Rect2(W * 0.5 - 24, 10, 48, 4), V10MetaUI.NIGHT_600, 1.0, false)
	sheet.add_child(grip)
	return sheet


func _afisha_shot() -> void:
	var s: = await _new_stage()
	Common.backdrop(s, "menu", Vector2(W, H), 0.0, 0.85)
	V10Meta.set_now(int(Time.get_unix_time_from_datetime_string("2026-11-24T12:00:00")) - V10Meta.tz_bias_min() * 60)
	V10Afisha.set_provider("salon", func(): return {"open": true, "sub": "Фонари у входа · ★ 12 в банке"})
	V10Afisha.set_provider("week", func(): return {"open": true, "title": "Пагода Луны", "sub": "этаж 7 из 30"})
	V10Afisha.set_provider("hand", func(): return true)
	V10Afisha.set_provider("mode_open", func(_id): return true)
	var cw: = W - 48.0
	var probe: = V10AfishaCard.make(Vector2(cw, 0))
	var sheet: = _sheet(s, 0.0, probe.preferred_height())
	probe.free()
	var card: = V10AfishaCard.make(Vector2(cw, 0))
	card.position = Vector2(24, 32)
	sheet.add_child(card)
	V10MetaUI.enter(card, Vector2(0, 30), 0.0, 0.24)
	card.locked.connect(func(id, t): print("LOCKED ", id, " ", t))
	await _wait(1.0)
	_audit("afisha", card)
	await _snap("afisha")
	card.stamp("daily")
	await _wait(0.1)
	card.stamp("mode")
	await _wait(0.9)
	_audit("afisha_stamp", card)
	await _snap("afisha_stamp")
	# fresh save: only Партия дня is open → it + ONE closed teaser
	for pv in ["salon", "week", "hand"]:
		V10Afisha.set_provider(pv, Callable())
	V10Afisha.set_provider("mode_open", func(_id): return false)
	V10Afisha.bind({})
	s = await _new_stage()
	Common.backdrop(s, "menu", Vector2(W, H), 0.0, 0.85)
	var fresh: = V10AfishaCard.make(Vector2(cw, 0))
	sheet = _sheet(s, 0.0, fresh.preferred_height())
	fresh.position = Vector2(24, 32)
	sheet.add_child(fresh)
	await _wait(0.6)
	_audit("afisha_fresh", fresh)
	await _snap("afisha_fresh")
	# Столы: the «Сегодня» block (Партия дня · Режим дня ×2) under a stand-in «Играть · 58»
	V10Afisha.set_provider("mode_open", func(_id): return true)
	s = await _new_stage()
	Common.backdrop(s, "play", Vector2(W, H), 4.0, 0.7)
	var cap: = V10MetaUI.text("Столы", 44, V10MetaUI.PAPER_100, "title", 700)
	cap.position = Vector2(32, 40)
	cap.size = Vector2(W - 64, 56)
	s.add_child(cap)
	var tables: = V10AfishaCard.make(Vector2(W - 64, 0), {"only": ["daily", "mode"], "play": false, "header": false})
	tables.position = Vector2(32, H - 24 - 104 - 32 - tables.preferred_height())
	s.add_child(tables)
	var play: = JButton.make("Играть · 58", "gold", Rect2((W - 560) * 0.5, H - 24 - 104, 560, 104), null, 32)
	V10MetaUI.role(play, "primary")
	s.add_child(play)
	await _wait(0.6)
	_audit("afisha_tables", tables, false)
	await _snap("afisha_tables")
	V10Afisha.set_provider("mode_open", Callable())


# ── Настройки → Уведомления: the group inside the settings sheet ───────────────────────────────────────────────
func _notify_shot() -> void:
	var s: = await _new_stage()
	V10Meta.bind({})
	V10Meta.set_now(int(Time.get_unix_time_from_datetime_string("2026-11-24T16:30:00")) - V10Meta.tz_bias_min() * 60)
	Common.backdrop(s, "bg_teahouse", Vector2(W, H), 6.0, 0.55)
	var pw: = W - 48.0
	var p: = V10NotifyPanel.make(pw)
	var sheet: = _sheet(s, 44.0 + 40.0, p.preferred_height())
	var t: = V10MetaUI.text("Настройки", 44, V10MetaUI.PAPER_100, "title", 700)
	t.position = Vector2(24, 28)
	t.size = Vector2(pw, 52)
	sheet.add_child(t)
	var g: = V10MetaUI.text("УВЕДОМЛЕНИЯ", 15, V10MetaUI.GOLD_500, "body", 900)
	g.position = Vector2(24, 88)
	g.size = Vector2(pw, 22)
	sheet.add_child(g)
	p.position = Vector2(24, 120)
	sheet.add_child(p)
	await _wait(0.6)
	_audit("notify", p)
	await _snap("notify")
	V10Notify.set_consent(true)
	V10Notify.request("salon", V10Meta.now_unix())
	p._build()
	V10MetaUI.refit(p)
	sheet.position.y = H - (p.preferred_height() + 84.0 + 56.0)
	sheet.size.y = p.preferred_height() + 84.0 + 64.0
	await _wait(0.4)
	_audit("notify_on", p)
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
	# dismiss the title splash main.gd adds after its first screen with a tap (as a player would)
	var past: = false
	var tap: = InputEventMouseButton.new()
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.pressed = true
	for c in main.get_children():
		if past and c is Control and c.mouse_filter == Control.MOUSE_FILTER_STOP:
			(c as Control).gui_input.emit(tap)
		if c == main.get("finger"):
			past = true
	await _wait(1.0)
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
	var notes: = V10ShopGuard.test_notes(main.screen).size()
	print("STORE_RUB_VISIBLE ", vis, " TEST_NOTES ", notes)
	if before == 0 or vis != 0 or notes != 0:
		push_error("store guard: %d ₽ buttons before, %d visible after, %d test captions" % [before, vis, notes])
		errors += 1
	await _snap("shop_store")
	# the ₽ packs tab: shop.gd calls guard() after every _build_body() (README hook 8)
	main.screen._set_tab(2)
	V10ShopGuard.guard(main.screen)
	await _wait(0.8)
	var vis2: = V10ShopGuard.visible_rub(main.screen).size()
	print("STORE_RUB_VISIBLE_GEMS ", vis2)
	if vis2 != 0:
		push_error("store guard (packs tab): %d ₽ buttons visible" % vis2)
		errors += 1
	await _snap("shop_store_gems")
	V10ShopGuard.unforce()
