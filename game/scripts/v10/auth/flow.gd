class_name V10AuthFlow
extends RefCounted

# Entry flow: splash → login screen (first launch / after «Выйти») or silent auto sign-in → welcome card.
#   var r: Dictionary = await V10AuthFlow.boot(main)
#     r = {"login": bool (the login screen was shown), "provider": id, "new_player": bool, "imported": bool,
#          "status": restore status when no login screen ("ok" | "migrated" | "recovered" | "fallback")}
#   V10AuthFlow.relogin(main)        after logout / account deletion: login screen over everything, then home
#   V10AuthFlow.open_account(main)   the «Аккаунт» sheet wired to relogin
# `main` is main.gd (uses main.overlay when present, else main itself). Works with any full-screen Control.

const SPLASH_SEC: = 0.9
static var title_music: = "title"      # v10-audio lane: assets/music/title.ogg; falls back to "menu"
static var skip_splash: = false


static func _layer(main: Control) -> Control:
	var host: Control = main.overlay if "overlay" in main and main.overlay != null else main
	var vs: = main.get_viewport_rect().size
	var layer: = Control.new()
	layer.name = "V10AuthLayer"
	layer.size = vs
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.z_index = 60
	host.add_child(layer)
	return layer


static func music() -> void :
	var tree: = Engine.get_main_loop() as SceneTree
	var sfx = tree.root.get_node_or_null("Sfx") if tree else null
	if sfx == null:
		return
	var name: = title_music if ResourceLoader.exists("res://assets/music/%s.ogg" % title_music) else "menu"
	sfx.music(name)


# brand splash: dark plum, the logo blooms in with a soft halo, then the caller cross-fades it away
static func _splash(layer: Control) -> Control:
	var sp: = Control.new()
	sp.name = "V10Splash"
	sp.size = layer.size
	sp.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(sp)
	var bg: = ColorRect.new()
	bg.color = Color("1b1020")
	bg.size = sp.size
	sp.add_child(bg)
	var lw: = minf(sp.size.x * 0.72, 520.0)
	var lh: = lw * 306.0 / 540.0
	var c: = Vector2(sp.size.x * 0.5, sp.size.y * 0.44)
	var halo: = TextureRect.new()
	var gt: = GradientTexture2D.new()
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(0.5, 0.0)
	var gr: = Gradient.new()
	gr.set_color(0, Color(1.0, 0.7, 0.75, 0.38))
	gr.set_color(1, Color(1.0, 0.7, 0.75, 0.0))
	gt.gradient = gr
	halo.texture = gt
	halo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	halo.size = Vector2(lw * 1.6, lw * 1.6)
	halo.position = c - halo.size * 0.5
	halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sp.add_child(halo)
	var logo: = V8Art.rect(V8Art.misc("logo"), Rect2(c.x - lw * 0.5, c.y - lh * 0.5, lw, lh))
	logo.pivot_offset = Vector2(lw, lh) * 0.5
	sp.add_child(logo)
	UI.pop_in(logo, 0.05, 0.82)
	halo.modulate.a = 0.0
	halo.create_tween().tween_property(halo, "modulate:a", 1.0, 0.6)
	return sp


static func boot(main: Control) -> Dictionary:
	V10Auth.ensure()
	var layer: = _layer(main)
	var tree: = main.get_tree()
	var sp: Control = null
	if not skip_splash:
		sp = _splash(layer)
		await tree.create_timer(SPLASH_SEC).timeout
	var res: = {"login": false, "provider": "", "new_player": false, "imported": false, "status": ""}
	if V10Auth.needs_login():
		music()
		var ls: = V10LoginScreen.make(layer, main)
		if sp:
			layer.move_child(sp, -1)
			_fade_out(sp)
		var r: Dictionary = await ls.finished
		res.login = true
		res.provider = str(r.get("provider", "guest"))
		res.new_player = bool(r.get("new_player", false))
		res.imported = bool(r.get("imported", false))
		layer.queue_free()
	else:
		var r: Dictionary = await V10Auth.restore()
		res.status = str(r.status)
		res.provider = str(r.provider)
		if sp:
			await _fade_out(sp)
		layer.queue_free()
		await V10Auth.age_gate(main)
		var host: Control = main.overlay if "overlay" in main and main.overlay != null else main
		if str(r.toast) != "":
			V10AuthUI.toast(host, str(r.toast), V10Auth.greet_hero())
			await tree.create_timer(1.2).timeout
		welcome(host, main)
	return res


static func welcome(host: Control, main: Control = null) -> Control:
	var y: = -1.0
	if main != null and "topbar" in main and main.topbar and main.topbar.visible:
		y = V8Header.CONTENT_Y + 8.0
	return V10AuthUI.welcome(host, V10Auth.greet_hero(), V10Auth.welcome_text(), y)


static func _fade_out(n: Control) -> void :
	var t: = n.create_tween()
	t.tween_property(n, "modulate:a", 0.0, 0.4)
	t.tween_callback(n.queue_free)
	await t.finished


# after «Выйти» / «Удалить аккаунт»: login screen over the game, then a fresh home (or the intro for a new player)
static func relogin(main: Control) -> Dictionary:
	skip_splash = true
	var r: Dictionary = await boot(main)
	skip_splash = false
	if main.has_method("go"):
		main.screen_id = ""
		if bool(r.get("new_player", false)) and not bool(r.get("imported", false)) and not bool(G.S.get("intro_done", false)):
			# after «Удалить аккаунт» the player starts from zero: the intro and the first game, as on a first launch
			await V6Story.play("intro")
			G.S.intro_done = true
			G.save()
			main.go("play", {"level": 0, "partner": "mc"}, false)
		else:
			main.go("home", {}, false)
	return r


static func open_account(main: Control) -> V10AccountSheet:
	var host: Control = main.overlay if "overlay" in main and main.overlay != null else main
	var a: = V10AccountSheet.open(host)
	a.logged_out.connect(func(): relogin(main))
	a.deleted.connect(func(): relogin(main))
	return a
