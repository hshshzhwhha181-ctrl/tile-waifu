extends Control


const TABS: = [
	{"id": "home", "name": "Чайная", "icon": "home"}, 
	{"id": "collection", "name": "Гардероб", "icon": "wardrobe"}, 
	{"id": "levels", "name": "Партия", "icon": "star", "big": true}, 
	{"id": "summon", "name": "Желания", "icon": "gem"}, 
	{"id": "shop", "name": "Лавка", "icon": "shop"}, 
]
const SCREENS: = {
	"home": preload("res://scripts/screens/home.gd"), 
	"levels": preload("res://scripts/screens/levels.gd"), 
	"play": preload("res://scripts/screens/play.gd"), 
	"summon": preload("res://scripts/screens/summon.gd"), 
	"collection": preload("res://scripts/screens/collection.gd"), 
	"shop": preload("res://scripts/screens/shop.gd"), 
	"modes": preload("res://scripts/screens/modes.gd"), 
	"arena": preload("res://scripts/v06/modes/mode_play.gd"), 
	"room": preload("res://scripts/v07/room/room.gd"), 
	"v7event": preload("res://scripts/v07/event/event_screen.gd"), 
	"v7tourney": preload("res://scripts/v07/event/tourney_screen.gd"), 
	"v7play": preload("res://scripts/v07/event/event_play.gd"), 
}

var W: = 720.0
var H: = 1280.0
var screen_root: Control
var screen: Control
var screen_id: = ""
var topbar: Control
var navbar: Control
var overlay: Control
var trans: ColorRect
var trans_mat: ShaderMaterial
var gems_lbl: Label
var coins_lbl: Label
var tab_nodes: = {}
var rank_lbl: Label
var rank_bar: RBox
var rank_em: Control
var finger: Sprite2D
var busy: = false

func _ready() -> void :
	var vs: = get_viewport_rect().size
	W = vs.x
	H = vs.y
	screen_root = Control.new()
	screen_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_root.size = vs
	add_child(screen_root)
	_build_topbar()
	_build_navbar()
	overlay = Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.size = vs
	add_child(overlay)
	trans = ColorRect.new()
	trans.size = vs
	trans.mouse_filter = Control.MOUSE_FILTER_IGNORE
	trans_mat = ShaderMaterial.new()
	trans_mat.shader = preload("res://shaders/transition.gdshader")
	trans_mat.set_shader_parameter("size", vs)
	trans.material = trans_mat
	add_child(trans)
	finger = Sprite2D.new()
	finger.texture = G.fx("finger")
	finger.visible = false
	finger.z_index = 50
	add_child(finger)
	go("home", {}, false)
	_splash()
	if G.demo:
		run_demo()
	_dev_args()



func _splash() -> void :
	var args: = " ".join(OS.get_cmdline_user_args())
	if "--shots" in args and not "--splash" in args:
		return
	if "--splash" in args:
		G.S.intro_done = "--fresh" not in args
	if G.demo:
		return
	var sp: = Control.new()
	sp.size = Vector2(W, H)
	sp.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(sp)
	Common.backdrop(sp, "bg_festival", sp.size, 0.0, 0.8, Color(0.92, 0.88, 1.0), Vector2(0.5, 0.5))
	Common.vignette(sp, sp.size, Color(0.08, 0.03, 0.15), 0.75)
	Common.rays(sp, Vector2(W * 0.5, H * 0.24), 1200, Color(1, 0.85, 0.6, 0.45), 12, 0.03, 0.5)
	Fx.ambient(sp, "lanterns", sp.size)
	Fx.ambient(sp, "petals", sp.size)
	var hero: = Hero.new().setup("mc", H * 0.6)
	hero.position = Vector2(W * 0.5, H + 30)
	hero.interactive = false
	sp.add_child(hero)
	UI.slide_in(hero, Vector2(0, 120), 0.4, 0.9)
	var logo: = UI.tex(load("res://assets/ui/logo.webp"), Rect2(W * 0.5 - 280, H * 0.05, 560, 320))
	logo.pivot_offset = Vector2(280, 160)
	sp.add_child(logo)
	UI.pop_in(logo, 0.15, 0.4)
	var tag: = UI.center_label(UI.label(V6Txt.s("title.tag"), 22, Color("ffe7c4"), UI.DARK, 4, "body", 900), Rect2(0, H * 0.05 + 300, W, 34))
	sp.add_child(tag)
	UI.slide_in(tag, Vector2(0, 20), 0.5)
	var plate: = UI.rbox("plum", Rect2(W * 0.5 - 250, H - 230, 500, 76), 38, 3, 10)
	plate.colors(Color(0.15, 0.06, 0.22, 0.88), Color(0.08, 0.03, 0.14, 0.9)).borders(Color("fff0b8"), Color("c58a2c"))
	sp.add_child(plate)
	plate.add_child(UI.center_label(UI.label(V6Txt.s("title.tap"), 24, Color("fff1dc"), UI.DARK, 3, "body", 900), Rect2(0, 0, 500, 76)))
	plate.pivot_offset = Vector2(250, 38)
	var pt: = plate.create_tween().set_loops()
	pt.tween_property(plate, "modulate:a", 0.55, 0.9).set_trans(Tween.TRANS_SINE)
	pt.tween_property(plate, "modulate:a", 1.0, 0.9).set_trans(Tween.TRANS_SINE)
	var ver: = UI.center_label(UI.label(V6Txt.s("title.version"), 15, Color(1, 1, 1, 0.6)), Rect2(0, H - 52, W, 24))
	sp.add_child(ver)
	Sfx.music("menu")
	await get_tree().create_timer(0.8).timeout
	await _wait_tap(sp)
	Sfx.play("reveal_sr", 0.9)
	hero.react("big")
	if not G.S.get("intro_done", false):
		pt.kill()
		var t0: = create_tween().set_parallel()
		for n in [logo, tag, plate, ver]:
			t0.tween_property(n, "modulate:a", 0.0, 0.3)
		await t0.finished
		await V6Story.play("intro")
		G.S.intro_done = true
		G.save()
		go("play", {"level": 0, "partner": "mc"}, false)
	else:
		Sfx.say(G.S.partner, "greet")
	var t: = create_tween()
	t.tween_property(sp, "modulate:a", 0.0, 0.45)
	t.tween_callback(sp.queue_free)

func _wait_tap(n: Control) -> void :
	var done: = [false]
	var cb: = func(e):
		if e is InputEventMouseButton and e.pressed:
			done[0] = true
	n.gui_input.connect(cb)
	var t0: = G.time
	var auto: = "--autotap=1" in OS.get_cmdline_user_args()
	while not done[0] and is_inside_tree():
		await get_tree().process_frame
		if auto and G.time - t0 > 1.3:
			break
	n.gui_input.disconnect(cb)


func _meet_scene(sp: Control, hero: Hero) -> void :
	var lines: = [
		"Ой, гость! Заходи, на улице фонари, а у нас тепло. Я Маджонг-тян, хозяйка этой маленькой чайной.", 
		"Здесь играют по-своему: фишка уходит в лоток на четыре места, две одинаковые исчезают. Держи лоток свободным.", 
		"Перед каждой партией я гадаю на омикудзи. А девушки квартала, если подружишься, помогут своими умениями.", 
		"Ну что, садись напротив. Первую партию сыграем вместе, я подскажу.", 
	]
	var box: = UI.rbox("plum", Rect2(18, H - 330, W - 36, 220), 28, 4, 12)
	box.colors(Color(0.16, 0.08, 0.26, 0.94), Color(0.08, 0.04, 0.14, 0.96)).borders(Color("fff0b8"), Color("c58a2c"))
	sp.add_child(box)
	var nameplate: = UI.rbox("pink", Rect2(30, -26, 220, 48), 22, 3, 8)
	box.add_child(nameplate)
	nameplate.add_child(UI.center_label(UI.label("Маджонг-тян", 22, Color.WHITE, Color("7a2346"), 4, "body", 900), Rect2(0, 0, 220, 48)))
	var txt: = UI.label("", 25, Color("fff1dc"), UI.DARK, 2, "body", 800)
	txt.position = Vector2(30, 40)
	txt.size = Vector2(W - 100, 150)
	txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(txt)
	var more: = UI.label("▼", 20, Color("ffd98a"))
	more.position = Vector2(W - 90, 180)
	box.add_child(more)
	UI.slide_in(box, Vector2(0, 60), 0.0, 0.35)
	for line in lines:
		txt.text = line
		txt.visible_ratio = 0.0
		hero.react("happy")
		Sfx.play("pop", 1.3, -10)
		var tw: = create_tween()
		tw.tween_property(txt, "visible_ratio", 1.0, line.length() * 0.022)
		await get_tree().create_timer(0.25).timeout
		await _wait_tap(sp)
		if txt.visible_ratio < 1.0:
			tw.kill()
			txt.visible_ratio = 1.0
			await _wait_tap(sp)
		Sfx.play("tap")


func settings() -> void :
	var p: = Common.popup(self, V6Txt.s("settings.title"), 900)
	var rows: = [
		["modest", V6Txt.s("settings.modest"), V6Txt.s("settings.modest_d")], 
		["cutins", V6Txt.s("settings.cutins"), V6Txt.s("settings.cutins_d")], 
		["sound", V6Txt.s("settings.sound"), ""], 
		["music", V6Txt.s("settings.music"), ""], 
		["voice", V6Txt.s("settings.voice"), ""], 
		["v6_story.on", V6Txt.s("settings.story"), V6Txt.s("settings.story_d")], 
		["v6_fx.shake", V6Txt.s("settings.shake"), V6Txt.s("settings.shake_d")], 
		["v7_haptics.on", "Вибрация", "Отклик на касания, пары и серии"], 
	]
	for i in rows.size():
		var key: String = rows[i][0]
		var y: = 56.0 + i * 82
		var l: = UI.label(rows[i][1], 26, UI.INK, Color.WHITE, 3, "body", 900)
		l.position = Vector2(34, y + (4 if rows[i][2] != "" else 18))
		p.add_child(l)
		if rows[i][2] != "":
			var d: = UI.label(rows[i][2], 17, Color("8a5a7a"))
			d.position = Vector2(34, y + 42)
			p.add_child(d)
		var on: bool = _v6_opt(key)
		var b: = JButton.make(V6Txt.s("common.on") if on else V6Txt.s("common.off"), "mint" if on else "glass", Rect2(500, y + 8, 128, 64), null, 24)
		b.pressed.connect( func():
			var v: bool = not _v6_opt(key)
			_v6_opt(key, v)
			if key == "v6_fx.shake":
				_v6_opt("v6_fx.flash", v)
			G.save()
			b.lbl.text = V6Txt.s("common.on") if v else V6Txt.s("common.off")
			b.box.colors(UI.PAL["mint" if v else "glass"][0], UI.PAL["mint" if v else "glass"][1])
			if key == "music":
				Sfx.cur_music = ""
				Sfx.music("menu" if v else "")
			if key == "modest" and screen_id in ["home", "collection", "shop", "summon"]:
				p.get_meta("root").set_meta("on_close", func():
					var sid: = screen_id
					screen_id = ""
					go(sid, {}, false)))
		p.add_child(b)

	var sl: = UI.label(V6Txt.s("settings.side"), 26, UI.INK, Color.WHITE, 3, "body", 900)
	sl.position = Vector2(34, 744)
	p.add_child(sl)
	var fb: = JButton.make(V6Txt.s("settings.side_f"), "pink" if G.S.side == "f" else "glass", Rect2(220, 732, 196, 64), null, 22)
	var mb: = JButton.make(V6Txt.s("settings.side_m"), "glass", Rect2(428, 732, 200, 64), null, 20)
	fb.pressed.connect( func():
		G.S.side = "f"
		G.save())
	mb.pressed.connect( func():
		toast(V6Txt.s("settings.side_m_toast"), "heart"))
	p.add_child(fb)
	p.add_child(mb)
	var eg: = UI.label("Тайники найдены: %d из %d" % [V7Eggs.found_count(), V7Eggs.total()], 18, Color("d9c4e6"))
	eg.position = Vector2(34, 820)
	p.add_child(eg)


func _v6_opt(key: String, v = null) -> bool:
	var parts: = key.split(".")
	if parts.size() == 1:
		if v != null:
			G.S[key] = v
		return G.S.get(key, true)
	if not (G.S.get(parts[0]) is Dictionary):
		G.S[parts[0]] = {}
	if v != null:
		G.S[parts[0]][parts[1]] = v
	return G.S[parts[0]].get(parts[1], true)


func rank_ladder() -> void :
	var p: = Common.popup(self, V6Txt.s("rank.title"), 1000)
	var ri: = G.rank_of(int(G.S.rp))
	var head: = UI.label(V6Txt.s("rank.head") % [ri.title, int(G.S.rp)], 24, UI.INK, UI.DARK, 3, "body", 900)
	head.position = Vector2(34, 58)
	p.add_child(head)
	var note: = UI.label(V6Txt.s("rank.note"), 17, Color("d9c4e6"))
	note.position = Vector2(34, 94)
	p.add_child(note)
	var y: = 160.0
	for t in G.RANKS.size():
		var rk: Dictionary = G.RANKS[t]
		var row: = UI.rbox("gold" if t == ri.tier else "glass", Rect2(26, y, 608, 108), 24, 3, 8)
		if t == ri.tier:
			row.colors(Color(0.34, 0.22, 0.5, 0.95), Color(0.18, 0.1, 0.3, 0.95))
		p.add_child(row)
		Common.rank_emblem(row, Rect2(12, 10, 88, 88), t, 0 if t > ri.tier else (ri.sub if t == ri.tier else 2))
		var nl: = UI.label(rk.name, 28, rk.color if t <= ri.tier else Color("8a7a9a"), UI.DARK, 4, "title", 900)
		nl.position = Vector2(116, 10)
		row.add_child(nl)
		var sub: = V6Txt.s("rank.sub") % rk.per if t < G.RANKS.size() - 1 else V6Txt.s("rank.sub_top") % rk.per
		var sl: = UI.label(sub, 17, Color("d9c4e6"))
		sl.position = Vector2(118, 52)
		row.add_child(sl)
		var gl: = UI.label("+%d" % rk.gems, 20, Color("ffd34d"), UI.DARK, 3, "body", 900)
		gl.position = Vector2(500, 18)
		row.add_child(gl)
		row.add_child(UI.tex(G.icon("gem"), Rect2(548, 8, 48, 48)))
		if t < ri.tier:
			var ok: = UI.label(V6Txt.s("rank.passed"), 15, Color("9fe8d0"))
			ok.position = Vector2(506, 66)
			row.add_child(ok)
		elif t == ri.tier:
			Common.progress_bar(row, Rect2(118, 78, 360, 16), float(ri.into) / ri.need, "gold")
			var pl: = UI.label("%d/%d" % [ri.into, ri.need], 15, Color("ffe7a6"))
			pl.position = Vector2(490, 72)
			row.add_child(pl)
		y += 118
	var yk: = UI.label(V6Txt.s("rank.yaku") % [G.S.yaku_seen.size(), G.YAKU.size() - 1], 18, Color("ffe7a6"), UI.DARK, 3, "body", 900)
	yk.position = Vector2(34, y + 6)
	p.add_child(yk)


func maybe_offer() -> void :
	if G.offer_shown or G.owns("o_dragon"):
		return
	G.offer_shown = true
	var p: = Common.popup(self, V6Txt.s("offer.title"), 620, "lav")
	var art: = Common.card_art(G.art_tex(G.ITEM["o_dragon"]), Rect2(30, 60, 260, 380), Vector2(0.5, 0.3), 1.0, 20)
	(art.material as ShaderMaterial).set_shader_parameter("holo", 0.35)
	p.add_child(art)
	var t: = UI.title(V6Txt.s("offer.name"), 36, Color.WHITE, Color("3f2a7a"))
	t.position = Vector2(310, 66)
	p.add_child(t)
	var lines: = [["gem", V6Txt.s("offer.gems")], ["ticket", V6Txt.s("offer.tickets")], ["wardrobe", V6Txt.s("offer.outfit")]]
	for i in lines.size():
		var c: = Common.chip(p, G.icon(lines[i][0]), lines[i][1], Rect2(310, 140 + i * 74, 320, 56), "glass", 18)
	var info: = UI.label(V6Txt.s("offer.info"), 17, Color("3f2a7a"))
	info.position = Vector2(312, 370)
	p.add_child(info)
	var buy: = JButton.make(V6Txt.s("offer.buy"), "gold", Rect2(60, 470, 540, 96), null, 34)
	buy.shine_every = 2.0
	buy.pressed.connect( func():
		G.S.gems += 1200
		G.give("o_dragon")
		G.save()
		fly_gems(buy.get_global_rect().get_center(), 8)
		toast(V6Txt.s("offer.got"), "gift")
		Common.close_popup(p))
	p.add_child(buy)

func _dev_args() -> void :

	var a: = {}
	for s in OS.get_cmdline_user_args():
		if s.begins_with("--") and "=" in s:
			var kv: = s.substr(2).split("=", true, 1)
			a[kv[0]] = kv[1]
	if a.has("unlock"):
		G.S.unlocked = int(a.unlock)
		G.S.free10 = a.has("free")
		G.S.pity = int(a.get("pity", "0"))
		G.S.ex = int(a.get("ex", "0"))
	if a.has("modest"):
		G.S.modest = true
	if a.has("outfit"):
		var it: Dictionary = G.ITEM[a.outfit]
		G.S.owned[a.outfit] = true
		G.S.outfit[it.hero] = a.outfit
		G.S.partner = it.hero
	if a.has("fuzz"):
		V7Fuzz.run(self, int(a.fuzz))
		return
	if a.has("selftest"):
		_selftest()
		return
	if a.has("screen"):
		await get_tree().process_frame
		busy = false
		var ga: = {"level": int(a.get("level", "0")), "auto": a.has("auto")}
		if a.has("mode"):
			ga["mode"] = a.mode
		go(a.screen, ga, false)
	if a.has("shots"):
		var times: Array = Array(a.get("at", "2").split(","))
		var t0: = 0.0
		for i in times.size():
			var t: = float(times[i])
			await get_tree().create_timer(t - t0).timeout
			t0 = t
			if a.has("act") and i < a.act.split(",").size():
				_dev_act(a.act.split(",")[i])
				await get_tree().create_timer(0.05).timeout
			var img: = get_viewport().get_texture().get_image()
			img.save_png("%s/%s_%d.png" % [a.shots, a.get("name", "shot"), i])
		get_tree().quit()


func _selftest() -> void :
	var bad: = 0
	var total: = 0
	for li in G.LEVELS.size():
		for rep in 5:
			var cfg: Dictionary = G.LEVELS[li].duplicate(true)
			cfg.seed = int(cfg.seed) + rep * 7919
			var b: = TrayBoard.new()
			add_child(b)
			b.setup(cfg)
			var ok: = true
			var guard: = 0
			while b.board_count() > 0 and guard < 2000:
				guard += 1
				var t: Tile = b.solver_move()
				if t == null:
					ok = false
					break
				if t.ice > 0:
					t.ice -= 1
					continue
				var twin: Tile = null
				for x in b.tray:
					if x.face == t.face:
						twin = x
				if twin:
					b.tray.erase(twin)
					twin.alive = false
					t.alive = false
				else:
					b.tray.append(t)
					if b.tray.size() >= TrayBoard.SLOTS:
						ok = false
						break
			total += 1
			if not ok or b.board_count() > 0:
				bad += 1
				printerr("FAIL level %s rep %d left %d" % [cfg.code, rep, b.board_count()])
			if rep == 0:
				printerr("level %s %s tiles=%d" % [cfg.code, cfg.shape, b.tiles.size()])
			b.free()
	printerr("SELFTEST %d/%d boards solved" % [total - bad, total])
	get_tree().quit()

func _dev_act(act: String) -> void :
	if act == "" or act == "-":
		return
	if screen.has_method("dev_act"):
		screen.dev_act(act)


func _build_topbar() -> void :
	topbar = Control.new()
	topbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(topbar)

	var plate: = UI.rbox("glass", Rect2(96, 22, 250, 78), 26, 3, 10)
	topbar.add_child(plate)
	var ri: = G.rank_of(int(G.S.rp))
	rank_lbl = UI.label(ri.title, 21, UI.INK, UI.DARK, 3, "body", 900)
	rank_lbl.position = Vector2(176, 28)
	rank_lbl.size = Vector2(160, 28)
	rank_lbl.clip_text = true
	topbar.add_child(rank_lbl)
	var xpbg: = UI.rbox("cream", Rect2(178, 62, 150, 16), 8, 2, 4)
	xpbg.set_param("shadow_color", Color(0, 0, 0, 0))
	topbar.add_child(xpbg)
	rank_bar = UI.rbox("gold", Rect2(180, 64, 146 * clampf(float(ri.into) / ri.need, 0.06, 1.0), 12), 6, 0, 3)
	rank_bar.set_param("shadow_color", Color(0, 0, 0, 0))
	topbar.add_child(rank_bar)
	var ring: = UI.rbox("gold", Rect2(16, 14, 96, 96), 48, 4, 10)
	topbar.add_child(ring)
	var av: = _avatar(G.S.partner, Rect2(22, 20, 84, 84))
	topbar.add_child(av)
	rank_em = Common.rank_emblem(topbar, Rect2(104, 26, 66, 66), ri.tier, ri.sub)
	var lv: = UI.rbox("pink", Rect2(12, 86, 52, 30), 15, 3, 6)
	topbar.add_child(lv)
	lv.add_child(UI.center_label(UI.label(str(int(G.S.player_lv)), 19, Color.WHITE, Color("7a2346"), 4), Rect2(0, 0, 52, 30)))
	var hit: = Control.new()
	hit.position = Vector2(10, 10)
	hit.size = Vector2(340, 100)
	hit.mouse_filter = Control.MOUSE_FILTER_STOP
	hit.gui_input.connect( func(e):
		if e is InputEventMouseButton and e.pressed:
			Sfx.play("pop")
			rank_ladder())
	topbar.add_child(hit)

	var gp: = _currency(Rect2(W - 338, 32, 160, 54), "gem", G.S.gems)
	gems_lbl = gp
	var cp: = _currency(Rect2(W - 166, 32, 150, 54), "coin", G.S.coins)
	coins_lbl = cp

func _avatar(hero: String, r: Rect2) -> TextureRect:
	var t: = UI.tex(load("res://assets/hero/%s.png" % hero), r, false)
	var m: = ShaderMaterial.new()
	m.shader = preload("res://shaders/card.gdshader")
	var rig: Dictionary = Hero.RIGS[hero]
	m.set_shader_parameter("size", r.size)
	m.set_shader_parameter("radius", r.size.x * 0.5)
	m.set_shader_parameter("tex_size", Vector2(848, 1264))
	m.set_shader_parameter("focus", Vector2(rig.head_c.x / 848.0, (rig.head_c.y + 15) / 1264.0))
	m.set_shader_parameter("zoom", 4.6)
	m.set_shader_parameter("bottom_shade", 0.0)
	t.material = m
	return t

func _currency(r: Rect2, icon: String, val: int) -> Label:
	var p: = UI.rbox("plum", r, r.size.y * 0.5, 3, 10)
	p.set_param("border_top", Color("ffe7a6")).set_param("border_bottom", Color("c58a2c"))
	topbar.add_child(p)
	topbar.add_child(UI.tex(G.icon(icon), Rect2(r.position.x + 4, r.position.y + 5, 44, 44)))
	var l: = UI.label(UI.fmt(val), 23, Color.WHITE, Color(0.2, 0.05, 0.2), 4)
	l.position = r.position + Vector2(48, 0)
	l.size = Vector2(r.size.x - 88, r.size.y)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	topbar.add_child(l)
	var plus: = JButton.make("+", "gold", Rect2(r.end.x - 38, r.position.y + 12, 30, 30), null, 22)
	plus.pressed.connect( func(): go("shop"))
	topbar.add_child(plus)
	return l

func refresh_currency(punch: = false) -> void :
	gems_lbl.text = UI.fmt(G.S.gems)
	var ri: = G.rank_of(int(G.S.rp))
	if rank_lbl and rank_lbl.text != ri.title:
		rank_lbl.text = ri.title
		var p: = rank_em.position
		rank_em.queue_free()
		rank_em = Common.rank_emblem(topbar, Rect2(p, Vector2(66, 66)), ri.tier, ri.sub)
		topbar.move_child(rank_em, rank_bar.get_index() + 2)
	if rank_bar:
		rank_bar.size.x = 146 * clampf(float(ri.into) / ri.need, 0.06, 1.0)
	coins_lbl.text = UI.fmt(G.S.coins)
	if punch:
		UI.punch(gems_lbl, 0.25)

func gem_target() -> Vector2:
	return Vector2(W - 340, 58)

func _build_navbar() -> void :

	navbar = Control.new()
	navbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	navbar.position = Vector2(0, H - 132)
	add_child(navbar)
	var fade: = TextureRect.new()
	var fg: = GradientTexture2D.new()
	fg.gradient = Gradient.new()
	fg.gradient.set_color(0, Color(0.05, 0.04, 0.05, 0.0))
	fg.gradient.set_color(1, Color(0.05, 0.04, 0.05, 0.75))
	fg.fill_from = Vector2(0, 0)
	fg.fill_to = Vector2(0, 1)
	fade.texture = fg
	fade.position = Vector2(0, -40)
	fade.size = Vector2(W, 172)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	navbar.add_child(fade)
	var plate: = UI.rbox("graphite", Rect2(8, 26, W - 16, 100), 30, 2, 14)
	plate.set_param("pattern", 1.0)
	navbar.add_child(plate)
	var tw: = (W - 40) / TABS.size()
	for i in TABS.size():
		var tab: Dictionary = TABS[i]
		var c: = Control.new()
		c.position = Vector2(20 + i * tw, 0)
		c.size = Vector2(tw, 126)
		c.mouse_filter = Control.MOUSE_FILTER_STOP
		c.pivot_offset = Vector2(tw * 0.5, 70)
		var big: bool = tab.get("big", false)
		var hl: = Sprite2D.new()
		hl.texture = G.fx("glow")
		hl.material = Fx.add_mat()
		hl.position = Vector2(tw * 0.5, 62)
		hl.scale = Vector2(1.5, 1.1)
		hl.modulate = Color(UI.ROSE, 0.55)
		hl.name = "HL"
		hl.visible = false
		c.add_child(hl)
		var bar: = UI.rbox("gold", Rect2(tw * 0.5 - 22, 112, 44, 6), 3, 0, 4)
		bar.set_param("shadow_color", Color(0, 0, 0, 0))
		bar.name = "BAR"
		bar.visible = false
		c.add_child(bar)
		if big:
			var halo: = Sprite2D.new()
			halo.texture = G.fx("glow")
			halo.material = Fx.add_mat()
			halo.position = Vector2(tw * 0.5, 28)
			halo.scale = Vector2(2.4, 2.4)
			halo.modulate = Color(0.95, 0.75, 0.45, 0.35)
			c.add_child(halo)
			var medal: = UI.rbox("gold", Rect2(tw * 0.5 - 60, -32, 120, 120), 60, 4, 12)
			medal.name = "Medal"
			c.add_child(medal)
			var inner: = UI.rbox("pink", Rect2(tw * 0.5 - 49, -21, 98, 98), 49, 2, 6)
			inner.colors(Color("4a3038"), Color("1e1519")).borders(Color("f3dca0"), Color("8a6228"))
			inner.set_param("shadow_color", Color(0, 0, 0, 0))
			inner.set_param("gloss", 0.08)
			inner.name = "Inner"
			c.add_child(inner)
			var ring: = Common.rays(c, Vector2(tw * 0.5, 28), 150, Color(1, 0.85, 0.55, 1), 10, 0.03, 0.18)
			ring.name = "Rays"
			c.move_child(ring, inner.get_index())
		var ic: = UI.tex(G.icon(tab.icon + "_flat") if not big else G.icon(tab.icon), Rect2(tw * 0.5 - 27, 40, 54, 54) if not big else Rect2(tw * 0.5 - 36, -8, 72, 72))
		ic.name = "IC"
		ic.pivot_offset = ic.size * 0.5
		if not big:
			ic.modulate = Color(0.78, 0.73, 0.68, 0.8)
		c.add_child(ic)
		var l: = UI.center_label(UI.label(tab.name, 17 if not big else 19, UI.MUTED if not big else UI.GOLD, UI.DARK, 4, "body", 900), Rect2(0, 90, tw, 26))
		l.name = "L"
		c.add_child(l)
		c.gui_input.connect( func(e):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				Sfx.play("tap")
				go(tab.id))
		navbar.add_child(c)
		tab_nodes[tab.id] = c
	refresh_nav()


func refresh_nav() -> void :
	var c: Control = tab_nodes["summon"]
	for n in c.get_children():
		if n.has_meta("navmark"):
			c.remove_child(n)
			n.queue_free()
	var tw: float = c.size.x
	if not G.summon_open():
		var lk: = UI.rbox("plum", Rect2(tw * 0.5 - 2, 46, 40, 40), 20, 2, 6)
		lk.set_meta("navmark", true)
		lk.add_child(UI.tex(G.fx("lock"), Rect2(7, 6, 26, 26)))
		c.add_child(lk)
		(c.get_node("IC") as CanvasItem).modulate = Color(0.5, 0.47, 0.45, 0.6)
	else:
		if G.S.free10 or int(G.S.ex) >= G.EXCHANGE_COST:
			var d: = Common.badge(c, 0, Vector2(tw - 38, 20))
			d.set_meta("navmark", true)

func _select_tab(id: String) -> void :

	for k in tab_nodes:
		var c: Control = tab_nodes[k]
		var on: bool = k == id
		var ic: TextureRect = c.get_node("IC")
		var l: Label = c.get_node("L")
		var tab: Dictionary = {}
		for t in TABS:
			if t.id == k:
				tab = t
		if c.has_node("Medal"):
			var mt: Tween = ic.create_tween()
			mt.tween_property(ic, "scale", Vector2(1.1, 1.1) if on else Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			(c.get_node("Inner") as RBox).colors(Color("8e5464") if on else Color("4a3038"), Color("3a1a24") if on else Color("1e1519"))
			continue
		c.get_node("HL").visible = on
		c.get_node("BAR").visible = on
		ic.texture = G.icon(tab.icon if on else tab.icon + "_flat")
		l.label_settings = l.label_settings.duplicate()
		l.label_settings.font_color = UI.GOLD if on else UI.MUTED
		var t: Tween = ic.create_tween().set_parallel()
		t.tween_property(ic, "scale", Vector2(1.18, 1.18) if on else Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(ic, "position:y", 30.0 if on else 40.0, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(ic, "modulate", Color.WHITE if on else Color(0.78, 0.73, 0.68, 0.8), 0.2)
		if on and not G.demo:
			Fx.ring(c, Vector2(c.size.x * 0.5, 64), Color(1, 0.85, 0.6, 0.6), 0.6, 0.3)

func show_chrome(top: bool, nav: bool) -> void :
	topbar.visible = top
	navbar.visible = nav


func go(id: String, args: = {}, animate: = true) -> void :
	if busy or (id == screen_id and args.is_empty()):
		return
	if id == "summon" and not G.summon_open():
		toast(V6Txt.s("summon.locked"), "gem")
		UI.punch(tab_nodes["summon"], 0.12)
		return
	await V6Story.before_go(self, id, args)
	for p in overlay.get_children():
		if p.has_meta("popup"):
			p.queue_free()
	busy = true
	if animate:
		Sfx.play("whoosh", 1.0, -4)
		var t: = create_tween()
		t.tween_method( func(v): trans_mat.set_shader_parameter("progress", v), 0.0, 1.0, 0.32).set_trans(Tween.TRANS_QUAD)
		await t.finished
	if screen:
		screen.queue_free()
	screen_id = id
	screen = Control.new()
	screen.set_script(SCREENS[id])
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.size = Vector2(W, H)
	screen_root.add_child(screen)
	screen.call("build", self, args)
	if tab_nodes.has(id):
		_select_tab(id)
	refresh_currency()
	refresh_nav()
	if animate:
		var t2: = create_tween()
		t2.tween_method( func(v): trans_mat.set_shader_parameter("progress", v), 1.0, 0.0, 0.4).set_trans(Tween.TRANS_QUAD)
	busy = false

func toast(text: String, icon: = "") -> void :
	var w: = 560.0
	var p: = UI.rbox("plum", Rect2((W - w) * 0.5, 130, w, 70), 35, 3, 12)
	p.set_param("border_top", Color("ffe7a6")).set_param("border_bottom", Color("c58a2c"))
	overlay.add_child(p)
	var x0: = 20.0
	if icon != "":
		p.add_child(UI.tex(G.icon(icon), Rect2(8, 4, 62, 62)))
		x0 = 72
	var l: = UI.label(text, 22, Color.WHITE, Color(0.2, 0.05, 0.2), 3)
	l.position = Vector2(x0, 0)
	l.size = Vector2(w - x0 - 16, 70)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p.add_child(l)
	UI.slide_in(p, Vector2(0, -60), 0.0, 0.35)
	var t: Tween = p.create_tween()
	t.tween_interval(2.0)
	t.tween_property(p, "modulate:a", 0.0, 0.3)
	t.tween_callback(p.queue_free)


func fly_gems(from: Vector2, n: int) -> void :
	for i in min(n, 8):
		var s: = TextureRect.new()
		s.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		s.texture = G.icon("gem")
		s.size = Vector2(54, 54)
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		s.position = from - Vector2(27, 27)
		overlay.add_child(s)
		var mid: = from + Vector2(randf_range(-110, 110), randf_range(-120, 20))
		var t: Tween = s.create_tween()
		t.tween_property(s, "position", mid - Vector2(27, 27), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).set_delay(i * 0.04)
		t.tween_property(s, "position", gem_target() - Vector2(27, 27), 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.parallel().tween_property(s, "scale", Vector2(0.6, 0.6), 0.4)
		t.tween_callback( func():
			Sfx.play("gem", randf_range(0.95, 1.2), -6)
			refresh_currency(true)
			s.queue_free())


func tap_at(p: Vector2, dur: = 0.35) -> void :
	finger.visible = true
	var t: = create_tween()
	t.tween_property(finger, "position", p, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await t.finished
	var t2: = create_tween()
	t2.tween_property(finger, "scale", Vector2(0.75, 0.75), 0.06)
	t2.tween_property(finger, "scale", Vector2.ONE, 0.12)
	Fx.ring(overlay, p, Color(1, 1, 1, 0.8), 0.5, 0.35)

func press(btn: Control) -> void :
	if btn == null:
		return
	await tap_at(btn.get_global_rect().get_center())
	if btn is JButton:
		await btn.activate()
	else:
		var ev: = InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = true
		btn.gui_input.emit(ev)

func wait(s: float) -> void :
	await get_tree().create_timer(s).timeout

func run_demo() -> void :
	finger.position = Vector2(W * 0.5, H * 0.7)
	await wait(3.6)
	var home = screen

	await tap_at(home.hero.head_global() + Vector2(0, 80))
	home.on_hero_tap()
	await wait(2.4)
	await press(home.side_btns["login"])
	await wait(2.0)
	var pop: = _top_popup()
	if pop:
		var claim: = pop.get_children().filter( func(c): return c is JButton and c.size.x > 300)
		if claim.size() > 0:
			await press(claim[0])
	await wait(1.6)
	await press(home.play_btn)
	await wait(2.2)

	var lv = screen
	await press(lv.play_btn)
	await wait(1.6)
	var cpop: = _top_popup()
	if cpop:
		var gos: = cpop.get_children().filter( func(c): return c is JButton and c.size.x > 380)
		if gos.size() > 0:
			await press(gos[0])
	await wait(1.4)
	if lv.partner_go_btn == null or not is_instance_valid(lv.partner_go_btn):
		lv.pick_partner(lv.cur)
		await wait(1.0)
	await press(lv.partner_go_btn)
	await wait(4.4)
	var play = screen
	var k: = 0
	var guard: = 0.0
	while play.board.board_count() > 0 and guard < 240.0:
		guard += 0.2
		if play.fail_retry_btn and is_instance_valid(play.fail_retry_btn):
			var fp: = _top_popup()
			if fp:
				Common.close_popup(fp)
			play.fail_retry_btn = null
			play.board.return_tray(3)
			await wait(0.4)
			continue
		var t: Tile = play.board.solver_move()
		if t == null or not play.board.input_on or play.board.busy > 0:
			await wait(0.2)
			continue
		var spd: = 0.32 if k < 6 else 0.2
		await tap_at(t.get_global_transform_with_canvas().origin, spd)
		if t.alive and play.board.on_board(t):
			play.board.tap(t)
		k += 1
		await wait(0.3 if k < 6 else 0.1)
		if play.board.combo == 5 and play.board.tray.is_empty():
			await wait(1.4)
	await wait(7.5)

	G.demo_force_ssr = true
	if play.unlock_go_btn:
		await press(play.unlock_go_btn)
	await wait(3.0)
	await press(screen.pull10_btn)
	await wait(6.5)
	while screen.has_method("demo_skip") and screen.demo_skip():
		await tap_at(Vector2(W * 0.5, H * 0.55))
		await wait(1.8)
	await wait(3.0)
	var ok: Array = screen.seq.get_children().filter( func(c): return c is JButton)
	if ok.size() > 1:
		await press(ok[1])
	await wait(3.0)
	await press(tab_nodes["collection"])
	await wait(3.0)
	await press(tab_nodes["shop"])
	await wait(3.0)
	await press(screen.tab_btns[1])
	await wait(3.0)
	await press(screen.tab_btns[0])
	await wait(1.5)
	await press(screen.pass_btn)
	await wait(3.0)
	await press(tab_nodes["home"])
	await wait(4.0)
	get_tree().quit()

func _top_popup() -> RBox:
	for i in range(overlay.get_child_count() - 1, -1, -1):
		var r: Node = overlay.get_child(i)
		if r.has_meta("popup") and not r.has_meta("closing"):
			for c in r.get_children():
				if c is RBox:
					return c
	return null
