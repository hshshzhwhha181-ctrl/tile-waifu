extends Control

# Standalone runner of the salon lane (no main.gd, no save on disk): a tiny stub «main» swaps the salon screens.
#   godot --path game res://scripts/v10/salon/salon_runner.tscn -- <flags>
# Flags (after --):
#   --salon_selftest=1          logic + scene selftest, prints «SALON_SELFTEST ok/total», exits 0/1
#   --pt=salon --shots=<dir>    scripted playtest with a screenshot of every step (fresh → restore → finale → scene
#                               → photo → jade → hub), prints «PT OK» at the end
#   --state=fresh|old40|z1mid|z1done|z2done|all|jade   fixture (default fresh)
#   --screen=salon|scene:<zid>|hub                      just show a screen (manual look)
#   --fx=full|mid|min           effect level
#   --quit=<s>                  quit after s seconds (manual look)

var W: = 720.0
var H: = 1280.0
var screen: Control
var screen_id: = ""
var args: = {}
var history: = []
var fixture: = {}
var went_home: = false


func _ready() -> void:
	var vs: = get_viewport_rect().size
	W = vs.x
	H = vs.y
	size = vs
	for a in OS.get_cmdline_user_args():
		var kv: = a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	if args.has("salon_selftest"):
		await get_tree().process_frame
		var st = load("res://scripts/v10/salon/salon_selftest.gd").new()
		add_child(st)
		var ok: bool = await st.run()
		V10SalonUI.clear_caches()
		get_tree().quit(0 if ok else 1)
		return
	G.S["fx_level"] = str(args.get("fx", "full"))
	fixture = make_fixture(str(args.get("state", "fresh")))
	V10Salon.state_override = fixture
	V10Salon.reset_cache()
	V10Salon.level_cb = func(): return 57
	if args.get("pt", "") == "salon":
		_playtest()
		return
	var sc: String = str(args.get("screen", "salon"))
	if sc.begins_with("scene:"):
		go("v10scene", {"zone": sc.substr(6)}, false, false)
	elif sc == "hub":
		_hub_demo()
	else:
		go("v10salon", {}, false, false)
	if args.has("quit"):
		await get_tree().create_timer(float(args.quit)).timeout
		if args.has("shots"):
			await shot("manual")
		V10SalonUI.clear_caches()
		get_tree().quit()


# ── fixtures ─────────────────────────────────────────────────────────────────────────────────────────────────

static func make_fixture(kind: String) -> Dictionary:
	var S: Dictionary = G.default_state().duplicate(true)
	S.aff = {"mc": 320, "rin": 120, "hana": 30, "yue": 0, "nova": 0}
	var stars: = {}
	var n: = {"fresh": 1, "old40": 14, "z1mid": 12, "z1done": 30, "z2done": 50, "all": 66, "jade": 66}.get(kind, 4)
	for i in n:
		stars[str(i)] = 3 if i % 4 != 3 else 2
	S.stars = stars
	S.unlocked = n + 1
	V10Salon.ensure(S)
	var s: Dictionary = S[V10Salon.KEY]
	var spend: = func(zid: String, upto: int):
		var ts: = V10SalonData.tasks_by_cost(zid)
		for i in mini(upto, ts.size()):
			s.zones[zid].t[ts[i].id] = "lacquer"
			s.spent += int(ts[i].cost)
		if upto >= ts.size():
			s.zones[zid].done = true
			s.zones[zid].chest = true
			s.zones[zid].scene_seen = true
	match kind:
		"z1mid":
			spend.call("z1", 2)
			s.intro = true
		"z1done":
			spend.call("z1", 5)
			s.intro = true
		"z2done":
			spend.call("z1", 5)
			spend.call("z2", 6)
			s.intro = true
		"all", "jade":
			spend.call("z1", 5)
			spend.call("z2", 6)
			spend.call("z3", 7)
			s.intro = true
			if kind == "jade":
				for t in V10SalonData.zone("z1").tasks:
					s.zones.z1.t[t.id] = "jade"
					s.zones.z1.jp[t.id] = true
	return S


# ── stub main ────────────────────────────────────────────────────────────────────────────────────────────────

const SCREENS: = {
	"v10salon": "res://scripts/v10/salon/salon_screen.gd",
	"v10scene": "res://scripts/v10/salon/zone_scene.gd",
}


# same signature and history rules as main.go / main.back (so screens can pass animate / remember)
func go(id: String, a: = {}, _animate: = true, remember: = true) -> void:
	if not SCREENS.has(id):
		# the Path, home… are outside this lane: show where the button leads and come back
		toast("→ " + id)
		return
	if screen and remember and screen_id != id:
		history.append([screen_id, screen.get_meta("v8_args", {})])
	if screen:
		screen.queue_free()
	screen = Control.new()
	screen.set_script(load(SCREENS[id]))
	screen.size = Vector2(W, H)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.set_meta("v8_args", a)
	add_child(screen)
	screen_id = id
	screen.call("build", self, a)


func back() -> void:
	while not history.is_empty():
		var e: Array = history.pop_back()
		if e[0] == screen_id:
			continue
		go(e[0], e[1], false, false)
		return
	went_home = true
	toast("→ home")


func show_chrome(_top: bool, _nav: bool) -> void:
	pass


func refresh_currency(_p: = false) -> void:
	pass


func toast(text: String, _icon: = "") -> void:
	print("TOAST ", text)
	if screen and screen.has_method("toast"):
		screen.toast(text)


func _hub_demo() -> void:
	var bg: = TextureRect.new()
	bg.texture = load("res://assets/bg/bg_teahouse_blur.webp")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.size = Vector2(W, H)
	bg.modulate = Color(0.45, 0.42, 0.48)
	add_child(bg)
	var l: = V10SalonUI.label("Чайная (макет слота)", 26, V10SalonUI.PAPER_300, "display", 600)
	l.position = Vector2(32, 80)
	add_child(l)
	var y: = H * 0.5
	for st in ["fresh", "z1mid", "z1done", "all"]:
		V10Salon.state_override = make_fixture(st)
		V10Salon.reset_cache()
		var c: = V10SalonHub.make(Rect2(32, y, W - 64, 168), func(): toast("→ v10salon"))
		add_child(c)
		y += 184
		# freeze this card's state (each card read its own fixture)
	V10Salon.state_override = fixture


# ── playtest with screenshots ────────────────────────────────────────────────────────────────────────────────

func shot(name: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var dir: String = str(args.get("shots", ""))
	if dir == "":
		return
	DirAccess.make_dir_recursive_absolute(dir)
	var img: = get_viewport().get_texture().get_image()
	var p: = "%s/%dx%d_%s.png" % [dir, int(W), int(H), name]
	img.save_png(p)
	print("SHOT ", p)


func wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _playtest() -> void:
	var fails: = []
	go("v10salon", {}, false, false)
	await wait(1.4)
	await shot("01_fresh_intro")
	screen.dev_act("help")
	await wait(0.5)
	await shot("01b_help")
	# sheet of the hinted task
	screen.dev_act("open_sheet")
	await wait(0.6)
	await shot("02_sheet")
	screen.dev_act("close_sheet")
	await wait(0.4)
	var b0: = V10Salon.bank()
	var g: = V10Salon.next_goal()
	screen._do_restore(g.zid, g.tid)
	await wait(0.42)
	await shot("03_stars_flying")
	await wait(0.5)
	await shot("04_reveal")
	while screen.busy:
		await wait(0.1)
	await wait(0.7)
	await shot("05_restored_one")
	if V10Salon.bank() != b0 - int(g.cost):
		fails.append("bank after restore")
	# a short-of-stars sheet
	var g2: = V10Salon.next_goal()
	if not g2.is_empty():
		screen._on_task(g2.zid, g2.tid)
		await wait(0.6)
		await shot("06_sheet_short")
		screen.dev_act("close_sheet")
		await wait(0.4)
	# give stars and finish zone 1 → finale
	for i in 30:
		fixture.stars[str(100 + i)] = 3
	V10Salon.notify_stars(90)
	screen.refresh()
	await wait(0.6)
	await shot("07_affordable_tags")
	if screen.play_btn.text != "Восстановить":
		fails.append("main button restores when the bank covers the next task")
	while true:
		var gg: = V10Salon.next_goal()
		if gg.is_empty() or gg.zid != "z1":
			break
		var last: = V10Salon.progress("z1").x == V10Salon.progress("z1").y - 1
		screen._do_restore(gg.zid, gg.tid)
		if last:
			await wait(1.0)
			await shot("08_finale_wave")
		while screen.busy:
			await wait(0.1)
			if screen.finale and is_instance_valid(screen.finale):
				break
	await wait(3.8)
	await shot("09_finale_ceremony")
	if not bool(V10Salon.zone_rec("z1").chest):
		fails.append("chest not claimed")
	screen.dev_act("close_finale")
	await wait(0.9)
	await shot("10_map_z2_open")
	await screen._scroll_to("z1", false)
	await wait(1.2)
	screen.dev_act("say:z1/head")
	await wait(1.0)
	await shot("11_z1_done_heroine")
	# jade finish on the sign
	screen._on_task("z1", "t1")
	await wait(0.5)
	screen.sheet._on_chip("jade")
	await wait(0.4)
	await shot("12_jade_sheet")
	screen.dev_act("close_sheet")
	await wait(0.9)
	await shot("13_jade_map")
	if V10Salon.task_variant("z1", "t1") != "jade":
		fails.append("jade not set")
	# the scene of z1 (rig) and of z2 (Rin still)
	go("v10scene", {"zone": "z1"})
	await wait(1.6)
	await shot("14_scene_z1_mc")
	screen.dev_act("line")
	await wait(1.4)
	await shot("15_scene_line")
	screen.dev_act("photo")
	await wait(0.6)
	screen.photo.set_preset(1)
	await wait(0.6)
	await shot("16_photo_mode")
	var p: String = await screen.photo.shoot()
	await wait(0.2)
	await shot("17_photo_flash")
	if p == "" or not FileAccess.file_exists(p):
		fails.append("photo not saved")
	screen.photo.close()
	await wait(0.4)
	# «назад» from the scene returns to the map (and must not remember the scene: no salon ↔ scene loop)
	screen.dev_act("back")
	await wait(0.6)
	if screen_id != "v10salon":
		fails.append("scene back → salon")
	# finish z2 for Rin, open her scene from the map
	var s: Dictionary = fixture[V10Salon.KEY]
	for t in V10SalonData.zone("z2").tasks:
		s.zones.z2.t[t.id] = "lacquer"
	s.zones.z2.done = true
	screen._open_scene("z2")
	await wait(1.4)
	await shot("18_scene_z2_rin")
	screen.dev_act("tap_head")
	await wait(0.9)
	await shot("19_scene_rin_line")
	screen.dev_act("lobby")
	await wait(0.4)
	await shot("20_lobby_toast")
	if V10Salon.lobby_texture() == "":
		fails.append("lobby not set")
	screen.dev_act("back")
	await wait(1.4)
	await shot("21_map_z2_done")
	# the map's «назад» now leaves the salon (home), never back into a scene
	screen.call("_back")
	if not went_home or screen_id != "v10salon":
		fails.append("salon back → home (history %s)" % [history])
	screen.queue_free()
	screen = null
	_hub_demo()
	await wait(0.6)
	await shot("22_hub_cards")
	if fails.is_empty():
		print("PT OK")
	else:
		print("PT FAIL ", fails)
	V10SalonUI.clear_caches()
	get_tree().quit(0 if fails.is_empty() else 1)
