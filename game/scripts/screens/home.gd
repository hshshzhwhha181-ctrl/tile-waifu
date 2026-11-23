extends Control



var main
var hero: Hero
var bubble: Control
var play_btn: JButton
var aff_root: Control
var side_btns: = {}
var W: = 720.0
var H: = 1280.0

func build(m, _args: Dictionary) -> void :
	main = m
	W = size.x
	H = size.y
	main.show_chrome(true, true)
	Sfx.music("menu")
	Common.backdrop(self, "menu", size, 0.0, 1.0, Color.WHITE, Vector2(0.5, 0.5))
	Common.rays(self, Vector2(W * 0.52, H * 0.34), 1000, Color(1, 0.93, 0.8, 0.45), 10, 0.03, 0.35)
	Fx.ambient(self, "petals", size)

	var floor_y: = H - 120.0
	var ped: = Sprite2D.new()
	ped.texture = G.fx("glow")
	ped.material = Fx.add_mat()
	ped.position = Vector2(W * 0.52, floor_y - 10)
	ped.scale = Vector2(6.0, 1.1)
	ped.modulate = Color(1, 0.85, 0.9, 0.5)
	add_child(ped)
	hero = Hero.new().setup(G.S.partner, H * 0.64)
	hero.position = Vector2(W * 0.52, floor_y)
	add_child(hero)
	hero.tapped.connect(on_hero_tap)
	UI.slide_in(hero, Vector2(0, 60), 0.05, 0.6)
	var oid: = G.equipped(G.S.partner)
	if oid != "":

		var art: = Common.living_art(self, G.art_tex(G.ITEM[oid]), Rect2(0, 0, W, H), Vector2(0.5, 0.4))
		move_child(art, 1)
		var shade: = Common.vignette(self, size, Color(0.1, 0.03, 0.15), 0.45)
		move_child(shade, 2)
		hero.visible = false
		hero.interactive = false
		var hit: = Control.new()
		hit.position = Vector2(W * 0.2, H * 0.2)
		hit.size = Vector2(W * 0.6, H * 0.5)
		hit.mouse_filter = Control.MOUSE_FILTER_STOP
		hit.gui_input.connect( func(e):
			if e is InputEventMouseButton and e.pressed:
				on_hero_tap())
		add_child(hit)
	_build_left()
	_build_right()
	_build_affection()

	var lvl: int = min(int(G.S.unlocked), G.LEVELS.size()) - 1
	play_btn = JButton.make(V6Txt.s("home.play"), "pink", Rect2(W - 418, H - 296, 400, 114), null, 36)
	play_btn.set_sub(V6Txt.s("home.play_sub") % [G.LEVELS[lvl].code, G.LEVELS[lvl].name], 19)
	play_btn.shine_every = 2.8
	play_btn.pulse = true
	play_btn.pressed.connect( func(): main.go("levels", {"select": lvl}))
	add_child(play_btn)
	UI.pop_in(play_btn, 0.35)
	await get_tree().create_timer(0.9).timeout
	if is_inside_tree():
		_say(Sfx.say(G.S.partner, "greet"))
	if G.has_meta("pending_offer") and not G.offer_shown:
		G.remove_meta("pending_offer")
		await get_tree().create_timer(1.4).timeout
		if is_inside_tree():
			main.maybe_offer()

func _build_left() -> void :
	var items: = [
		["login", "calendar", V6Txt.s("home.login"), func(): Daily.login(main, self), G.login_ready()], 
		["tasks", "trophy", V6Txt.s("home.tasks"), func(): Daily.tasks(main, self), G.tasks_ready() > 0], 
		["daily", "star", V6Txt.s("home.daily"), func(): Daily.calendar(main), not G.daily_done_today()], 
		["mail", "mail", V6Txt.s("home.mail"), func(): main.toast(V6Txt.s("home.mail_toast"), "mail"), false], 
		["settings", "settings", V6Txt.s("home.settings"), func(): main.settings(), false], 
		["room", "heart", "Комната", func(): main.go("room", {"hero": G.S.partner}), V7RoomData.any_fresh()], 
	]
	for i in items.size():
		var it: Array = items[i]
		var b: = Common.icon_button(self, it[1], it[2], Rect2(16, 138 + i * 112, 82, 82), it[3], it[4])
		side_btns[it[0]] = b
		UI.slide_in(b, Vector2(-50, 0), 0.1 + i * 0.05)

func refresh_badges() -> void :
	for k in side_btns:
		side_btns[k].queue_free()
	side_btns.clear()
	_build_left()

func _build_right() -> void :

	var ev: = _banner_card(Rect2(W - 214, 132, 198, 262), G.art_tex(G.ITEM["n_ssr"]), "БАННЕР", V6Txt.s("home.event_name"), V6Txt.s("home.event_left"), "lav", Vector2(0.5, 0.25))
	ev.gui_input.connect( func(e):
		if e is InputEventMouseButton and e.pressed:
			Sfx.play("pop")
			UI.punch(ev, 0.06)
			if G.summon_open():
				main.go("summon", {"banner": 2})
			else:
				main.go("levels", {"select": 5}))
	UI.slide_in(ev, Vector2(60, 0), 0.2)

	if G.summon_open() and int(G.S.newbie_left) > 0:
		var nb: = _banner_card(Rect2(W - 214, 410, 198, 160), G.art_tex(G.ITEM["o_dragon"]), "−20%", V6Txt.s("home.newbie"), V6Txt.s("home.newbie_sub"), "gold", Vector2(0.5, 0.22))
		nb.gui_input.connect( func(e):
			if e is InputEventMouseButton and e.pressed:
				Sfx.play("pop")
				main.go("summon", {"banner": 0}))
		if G.S.free10:
			Common.badge(nb, 0, Vector2(176, -10))
		UI.slide_in(nb, Vector2(60, 0), 0.28)
	elif not G.summon_open():
		var lk: = _banner_card(Rect2(W - 214, 410, 198, 160), load("res://assets/bg/summon.webp"), V6Txt.s("home.wish_tag"), V6Txt.s("home.wish_locked"), V6Txt.s("home.wish_gift"), "plum", Vector2(0.5, 0.4))
		lk.add_child(UI.tex(G.fx("lock"), Rect2(150, 8, 40, 40)))
		lk.gui_input.connect( func(e):
			if e is InputEventMouseButton and e.pressed:
				main.go("summon"))
		UI.slide_in(lk, Vector2(60, 0), 0.28)
	V7Event.home_cards(self, main)

func _banner_card(r: Rect2, tex: Texture2D, tag_text: String, name_text: String, sub_text: String, pal: String, focus: Vector2) -> Control:
	var ev: = Control.new()
	ev.position = r.position
	ev.size = r.size
	ev.mouse_filter = Control.MOUSE_FILTER_STOP
	ev.pivot_offset = ev.size * 0.5
	add_child(ev)
	ev.add_child(UI.rbox(pal, Rect2(Vector2.ZERO, ev.size), 22, 4, 12))
	var art: = Common.card_art(tex, Rect2(6, 6, ev.size.x - 12, ev.size.y - 12), focus, 1.0, 18)
	(art.material as ShaderMaterial).set_shader_parameter("bottom_shade", 0.9)
	ev.add_child(art)
	var tag: = UI.rbox("pink" if pal != "gold" else "red", Rect2(-8, 10, 120, 32), 12, 3, 8)
	ev.add_child(tag)
	tag.add_child(UI.center_label(UI.label(tag_text, 17, Color.WHITE, Color("7a2346"), 4, "body", 900), Rect2(0, 0, 120, 32)))
	var t: = UI.label(name_text, 22, Color.WHITE, Color("3f2a7a"), 6, "body", 900)
	t.position = Vector2(12, ev.size.y - 66)
	ev.add_child(t)
	var s: = UI.label(sub_text, 16, Color("fff3c4"), Color("3f2a7a"), 4, "body", 900)
	s.position = Vector2(14, ev.size.y - 36)
	ev.add_child(s)
	return ev

func _build_affection() -> void :
	if aff_root:
		aff_root.queue_free()
	var h: String = G.S.partner
	aff_root = UI.rbox("glass", Rect2(16, H - 296, 268, 114), 26, 3, 12)
	add_child(aff_root)
	aff_root.mouse_filter = Control.MOUSE_FILTER_STOP
	aff_root.gui_input.connect( func(e):
		if e is InputEventMouseButton and e.pressed:
			main.go("room", {"hero": G.S.partner}))
	aff_root.add_child(UI.tex(G.icon("heart"), Rect2(6, 6, 66, 66)))
	var nm: = UI.label(V6Txt.s("home.hero_lv") % [G.HEROES[h].name, G.aff_level(h)], 19, UI.INK, Color.WHITE, 3, "body", 900)
	nm.position = Vector2(76, 10)
	nm.size = Vector2(186, 28)
	nm.clip_text = true
	aff_root.add_child(nm)
	Common.progress_bar(aff_root, Rect2(78, 42, 174, 20), float(int(G.S.aff.get(h, 0)) % 100) / 100.0, "pink")
	var left: = G.pet_left()
	var pl: = UI.label(V6Txt.s("home.pet_left") % left if left > 0 else V6Txt.s("home.pet_done"), 16, Color("8a4a6a"))
	pl.position = Vector2(16, 76)
	aff_root.add_child(pl)

func _say(text: String) -> void :
	if bubble:
		bubble.queue_free()
	var head: = hero.head_global()
	bubble = Common.bubble(self, text, Vector2(108, head.y - 250), 300, false)
	var b: = bubble
	var t: Tween = b.create_tween()
	t.tween_interval(3.8)
	t.tween_property(b, "modulate:a", 0.0, 0.3)
	t.tween_callback(b.queue_free)

func on_hero_tap() -> void :
	var h: String = G.S.partner
	if G.pet_left() > 0:
		G.S.pet.n = int(G.S.pet.n) + 1
		G.add_aff(h, 5)
		G.save()
		hero.react("big")
		Fx.burst(self, hero.head_global() + Vector2(0, -40), "heart", 16)
		Fx.float_text(self, hero.head_global() + Vector2(60, -90), "+5 ♥", Color("ffd0e0"), 40)
		_build_affection()
		UI.punch(aff_root, 0.12)
		_say(Sfx.say(h, "aff"))
	else:
		hero.react("happy")
		Fx.burst(self, hero.head_global() + Vector2(0, -40), "heart", 6)
		_say(Sfx.say(h, "greet"))

func dev_act(a: String) -> void :
	match a:
		"login":
			Daily.login(main, self)
		"tasks":
			Daily.tasks(main, self)
		"cal":
			Daily.calendar(main)
		"settings":
			main.settings()
		"offer":
			main.maybe_offer()
		"rank":
			main.rank_ladder()
		"pet":
			on_hero_tap()
		"blink":
			hero.set_process(false)
			hero.mat.set_shader_parameter("blink", 1.0)
