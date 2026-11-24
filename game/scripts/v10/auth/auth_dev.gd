extends Control

# Dev scene for the auth lane (does not touch main.gd). Always run it on its own save:
#   selftest:    godot --headless --path game res://scripts/v10/auth/auth_dev.tscn -- --auth_selftest=1 \
#                  --save=user://auth_selftest_save.json --save_wipe=1          → AUTH_SELFTEST ok/total, exit 0/1
#   screenshots: xvfb-run -a godot --path game --rendering-driver opengl3 --audio-driver Dummy --resolution 720x1280 \
#                  res://scripts/v10/auth/auth_dev.tscn -- --auth_shots=<dir> --flavor=rustore \
#                  --save=user://auth_shots_save.json --save_wipe=1
#   interactive: same without --auth_shots: the real boot flow (V10AuthFlow.boot) over a plain backdrop.

var overlay: Control


func _args() -> Dictionary:
	var a: = {}
	for s in OS.get_cmdline_user_args():
		if s.begins_with("--") and "=" in s:
			var kv: = s.substr(2).split("=", true, 1)
			a[kv[0]] = kv[1]
	return a


func _ready() -> void :
	size = get_viewport_rect().size
	var a: = _args()
	if a.get("auth_selftest", "") == "1":
		get_tree().create_timer(120.0).timeout.connect(func(): get_tree().quit(3))
		await get_tree().process_frame
		var host: = Control.new()
		host.size = size
		add_child(host)
		var r: Array = await V10AuthSelftest.run(host)
		await get_tree().create_timer(0.5).timeout
		get_tree().quit(0 if r[0] == r[1] else 1)
		return
	_backdrop()
	overlay = Control.new()
	overlay.size = size
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	if a.has("auth_shots"):
		await _shots(str(a.auth_shots), a)
		get_tree().quit()
		return
	var r2: Dictionary = await V10AuthFlow.boot(self)
	print("AUTH_BOOT ", r2)


# a stand-in for the home screen behind the welcome card
func _backdrop() -> void :
	Common.backdrop(self, "bg_festival", size, 0.0, 0.85, Color(0.95, 0.9, 1.0), Vector2(0.5, 0.5))
	Common.vignette(self, size, Color(0.08, 0.03, 0.15), 0.5)


func _snap(dir: String, name: String) -> void :
	await RenderingServer.frame_post_draw
	var img: = get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [dir, name])
	print("AUTH_SHOT ", name)


func _clear() -> void :
	for c in overlay.get_children():
		c.queue_free()
	await get_tree().process_frame


func _shots(dir: String, a: Dictionary) -> void :
	DirAccess.make_dir_recursive_absolute(dir)
	var tree: = get_tree()
	var tag: = "%dx%d" % [int(size.x), int(size.y)]
	V10AuthProvider.stub_delay = 0.0
	V10Auth.set_root("user://auth_shots/")
	for f in ["v10_session.json", "v10_device.json", "v10_auth_outbox.json"]:
		V10Auth._remove(V10Auth.root + f)
	G.S = G.default_state()
	var fl: = V10Auth.flavor()
	var only: = str(a.get("only", ""))
	# 1. splash
	if only == "" or only == "splash":
		V10AuthFlow._splash(overlay)
		await tree.create_timer(0.7).timeout
		await _snap(dir, "%s_%s_01_splash" % [tag, fl])
		await _clear()
	# 2. login screen
	var ls: = V10LoginScreen.make(overlay, null)
	await tree.create_timer(1.9).timeout
	ls.art.dev_freeze()
	await _snap(dir, "%s_%s_02_login" % [tag, fl])
	if only == "login":
		return
	# 3. provider tap without consent → consent nudge + toast
	if not ls.prov_btns.is_empty():
		ls.prov_btns.values()[0].activate()
		await tree.create_timer(0.45).timeout
		await _snap(dir, "%s_%s_03_consent" % [tag, fl])
		ls.consent.set_on(true, false)
		ls.consent.toggled.emit(true)
		await tree.create_timer(2.6).timeout
		ls.prov_btns.values()[0].activate()
		await tree.create_timer(0.55).timeout
		await _snap(dir, "%s_%s_04_stub" % [tag, fl])
		await tree.create_timer(3.0).timeout
	# 5. email sheet
	var es: = V10EmailSheet.open(ls, null)
	await tree.create_timer(0.6).timeout
	es.email_le.text = "player@mail"
	es._hint(true)
	await tree.create_timer(0.3).timeout
	await _snap(dir, "%s_%s_05_email" % [tag, fl])
	es.queue_free()
	# 6. guest → name picker
	ls.guest_btn.activate()
	await tree.create_timer(0.9).timeout
	var ns: V10NickSheet = ls.find_child("V10NickSheet", true, false)
	if ns:
		ns._on_chip(ns.chips[1].nick, ns.chips[1].hero)
		await tree.create_timer(0.5).timeout
		await _snap(dir, "%s_%s_06_nick" % [tag, fl])
		ns.dev_submit(ns.chips[1].nick, ns.chips[1].hero)
	await tree.create_timer(1.2).timeout
	await _clear()
	# 7. welcome card after an auto sign-in (relaunch)
	var b: Dictionary = await V10Auth.restore()
	V10AuthFlow.welcome(overlay)
	await tree.create_timer(1.4).timeout
	await _snap(dir, "%s_%s_07_welcome" % [tag, fl])
	# 7b. session expired toast
	V10AuthUI.toast(overlay, V10AuthText.s("toast.expired", "VK ID"), V10Auth.greet_hero(), 260.0)
	await tree.create_timer(0.5).timeout
	await _snap(dir, "%s_%s_08_expired" % [tag, fl])
	await _clear()
	# 8. account sheet + logout + delete
	var acc: = V10AccountSheet.open(overlay)
	await tree.create_timer(0.6).timeout
	await _snap(dir, "%s_%s_09_account" % [tag, fl])
	acc._ask_logout()
	await tree.create_timer(0.6).timeout
	await _snap(dir, "%s_%s_10_logout" % [tag, fl])
	for c in acc.get_children():
		if c.name.begins_with("V10AuthSheet") and c != acc.root:
			c.queue_free()
	await tree.process_frame
	acc._ask_delete()
	acc._holding = true
	await tree.create_timer(0.9).timeout
	acc._holding = false
	acc.set_process(false)
	await tree.create_timer(0.1).timeout
	await _snap(dir, "%s_%s_11_delete" % [tag, fl])
	print("AUTH_SHOTS done ", b)
