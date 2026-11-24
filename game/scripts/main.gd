extends Control


const TABS: = [
	{"id": "home", "name": "Чайная", "icon": "home"}, 
	{"id": "collection", "name": "Гардероб", "icon": "wardrobe"}, 
	{"id": "levels", "name": "Партия", "icon": "play", "big": true}, 
	{"id": "summon", "name": "Желания", "icon": "wishes"}, 
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
	"profile": preload("res://scripts/v08/profile/profile_screen.gd"),
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
	if "--profile_selftest=1" in args:
		await get_tree().process_frame
		var f: = V8ProfileSelftest.run(self)
		get_tree().quit(1 if f > 0 else 0)
		return
	if "--shots" in args and not "--splash" in args and not "--pt=" in args:
		return
	if "--splash" in args:
		# --fresh: clean install (no profile, intro not seen); --v07: a 0.7 player (intro seen, no profile yet)
		G.S.intro_done = "--fresh" not in args
		if "--fresh" in args or "--v07" in args:
			G.S.profile = G.new_profile()
			G.S.profile_done = false
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
	# 0.8: she is cropped at the knee by a soft dark fade that is solid under the «Играть» plate and the version
	# line, so no legs or shoes show below the CTA (or below the profile-card modal over this screen)
	var ff: = Common.floor_fade(sp, H - 470.0, H - 290.0, Color(0.08, 0.03, 0.12), 0.96)
	ff.name = "TitleFade"
	var fb: = ColorRect.new()
	fb.color = Color(0.08, 0.03, 0.12, 0.96)
	fb.position = Vector2(0, H - 290.0)
	fb.size = Vector2(W, 290.0)
	fb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sp.add_child(fb)
	var logo: = V8Art.rect(V8Art.misc("logo"), Rect2(W * 0.5 - 270, H * 0.04, 540, 306))
	logo.pivot_offset = Vector2(270, 153)
	sp.add_child(logo)
	UI.pop_in(logo, 0.15, 0.4)
	var tag: = UI.center_label(UI.label(V6Txt.s("title.tag"), 22, Color("ffe7c4"), UI.DARK, 4, "body", 900), Rect2(0, H * 0.05 + 300, W, 34))
	sp.add_child(tag)
	UI.slide_in(tag, Vector2(0, 20), 0.5)
	var fades: Array = [logo, tag]
	var has_profile: = bool(G.S.get("profile_done", false))
	if has_profile:
		var chip: = V8ProfileUI.title_chip(Rect2(0, H * 0.05 + 346, W, 64))
		sp.add_child(chip)
		UI.slide_in(chip, Vector2(0, 16), 0.6)
		fades.append(chip)
	# 0.8: the «Играть» plate is art (btn/play_title, the word is part of the picture); 560×196 drawn at 0.82
	var plate: = V8Art.rect(V8Art.btn("play_title"), Rect2(W * 0.5 - 230, H - 286, 460, 161))
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sp.add_child(plate)
	# the word as text too (invisible, under the art): screen readers and the playtest look the button up by it
	var ptl: = UI.center_label(UI.label(V6Txt.s("title.tap"), 40, Color("3a2410"), Color(1.0, 0.95, 0.8, 0.55), 2, "body", 900), Rect2(0, 0, 460, 161))
	ptl.self_modulate = Color(1, 1, 1, 0)
	ptl.name = "PlayText"
	plate.add_child(ptl)
	plate.pivot_offset = Vector2(230, 80)
	UI.pop_in(plate, 0.7, 0.7)
	var pt: = plate.create_tween().set_loops()
	pt.tween_property(plate, "scale", Vector2(1.04, 1.04), 0.8).set_trans(Tween.TRANS_SINE)
	pt.tween_property(plate, "scale", Vector2.ONE, 0.8).set_trans(Tween.TRANS_SINE)
	var ver: = UI.center_label(UI.label(V6Txt.s("title.version") % G.version(), 16, Color(1, 1, 1, 0.65), UI.DARK, 2, "body", 800), Rect2(0, H - 56, W, 26))
	sp.add_child(ver)
	fades.append_array([plate, ver])
	Sfx.music("menu")
	await get_tree().create_timer(0.8).timeout
	await _wait_tap(sp)
	Sfx.play("reveal_sr", 0.9)
	hero.react("big")
	var need_card: = not has_profile
	var need_intro: bool = not G.S.get("intro_done", false)
	if need_card or need_intro:
		pt.kill()
		var t0: = create_tween().set_parallel()
		for n in fades:
			t0.tween_property(n, "modulate:a", 0.0, 0.3)
		await t0.finished
	var imported: = false
	if need_card:
		var card: = V8ProfileCard.make(self, sp)
		await card.finished
		imported = card.imported
		need_intro = not G.S.get("intro_done", false)
	if need_intro:
		await V6Story.play("intro")
		G.S.intro_done = true
		G.save()
		go("play", {"level": 0, "partner": "mc"}, false)
	else:
		if imported or need_card:
			screen_id = ""
			go("home", {}, false)
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
		"Здесь играют по-своему: фишка уходит в лоток, две одинаковые исчезают. Держи лоток свободным.", 
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


# 0.9: two 3-way rows on top — «Эффекты» (S.fx_level) and «Вставки ульт» (S.ult_cutin) — then the on/off rows.
# «Тряска и вспышки» folded into «Эффекты» (only "full" shakes and flashes; G keeps S.v6_fx in step).
const SETTINGS_SEG: = [
	["fx_level", "Эффекты", [["full", "Полные"], ["mid", "Умеренные"], ["min", "Минимум"]],
		{"full": "Вспышки, тряска, частицы и ауры", "mid": "Без тряски и вспышек по краям экрана", "min": "Только отклик на нажатия"}],
	["ult_cutin", "Вставки ульт", [["full", "Полностью"], ["short", "Коротко"], ["off", "Выкл"]],
		{"full": "Полная сцена при первой ульте дня в наряде", "short": "Короткая вставка, меньше секунды", "off": "Только эффект на поле"}],
]

func settings() -> void :
	var p: = Common.popup(self, V6Txt.s("settings.title"), 990)
	var y: = 50.0
	for seg in SETTINGS_SEG:
		_settings_seg(p, seg, y)
		y += 132.0
	var rows: = [
		["cutins", V6Txt.s("settings.cutins"), V6Txt.s("settings.cutins_d")], 
		["modest", V6Txt.s("settings.modest"), V6Txt.s("settings.modest_d")], 
		["v7_haptics.on", "Вибрация", "Отклик на касания, пары и серии"], 
		["v6_story.on", V6Txt.s("settings.story"), V6Txt.s("settings.story_d")], 
		["sound", V6Txt.s("settings.sound"), ""], 
		["music", V6Txt.s("settings.music"), ""], 
		["voice", V6Txt.s("settings.voice"), ""], 
	]
	for i in rows.size():
		var key: String = rows[i][0]
		var rh: = 78.0 if rows[i][2] != "" else 66.0
		var l: = UI.label(rows[i][1], 26, UI.INK, Color.WHITE, 3, "body", 900)
		l.position = Vector2(34, y + (4 if rows[i][2] != "" else 12))
		p.add_child(l)
		if rows[i][2] != "":
			var d: = UI.label(rows[i][2], 17, Color("8a5a7a"))
			d.position = Vector2(34, y + 42)
			p.add_child(d)
		var on: bool = _v6_opt(key)
		var b: = JButton.make(V6Txt.s("common.on") if on else V6Txt.s("common.off"), "mint" if on else "glass", Rect2(500, y + (8 if rows[i][2] != "" else 2), 128, 64), null, 24)
		b.pressed.connect( func():
			var v: bool = not _v6_opt(key)
			_v6_opt(key, v)
			G.save()
			b.lbl.text = V6Txt.s("common.on") if v else V6Txt.s("common.off")
			b.set_pal("mint" if v else "glass")
			if key == "music":
				Sfx.cur_music = ""
				Sfx.music("menu" if v else "")
			if key == "modest" and screen_id in ["home", "collection", "shop", "summon"]:
				p.get_meta("root").set_meta("on_close", func():
					var sid: = screen_id
					screen_id = ""
					go(sid, {}, false)))
		p.add_child(b)
		y += rh

	var sl: = UI.label(V6Txt.s("settings.side"), 26, UI.INK, Color.WHITE, 3, "body", 900)
	sl.position = Vector2(34, 848)
	p.add_child(sl)
	var fb: = JButton.make(V6Txt.s("settings.side_f"), "pink" if G.S.side == "f" else "glass", Rect2(220, 836, 196, 64), null, 22, -1.0, false)
	var mb: = JButton.make(V6Txt.s("settings.side_m"), "glass", Rect2(428, 836, 200, 64), null, 20, -1.0, false)
	Common.tab_paint(fb, G.S.side == "f")
	Common.tab_paint(mb, false)
	fb.pressed.connect( func():
		G.S.side = "f"
		G.save())
	mb.pressed.connect( func():
		toast(V6Txt.s("settings.side_m_toast"), "heart"))
	p.add_child(fb)
	p.add_child(mb)
	var eg: = UI.label("Тайники найдены: %d из %d" % [V7Eggs.found_count(), V7Eggs.total()], 18, Color("d9c4e6"))
	eg.position = Vector2(34, 916)
	p.add_child(eg)
	var vl: = UI.label(V6Txt.s("title.version") % G.version(), 16, Color(1, 1, 1, 0.45))
	vl.position = Vector2(34, 946)
	vl.size = Vector2(592, 24)
	vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	p.add_child(vl)


# one 3-way setting: caption, three segments (the chosen one painted like a selected tab) and a hint line
func _settings_seg(p: Control, seg: Array, y: float) -> void :
	var key: String = seg[0]
	var l: = UI.label(seg[1], 26, UI.INK, Color.WHITE, 3, "body", 900)
	l.position = Vector2(34, y)
	p.add_child(l)
	var hint: = UI.label("", 17, Color("8a5a7a"))
	hint.position = Vector2(34, y + 100)
	p.add_child(hint)
	var cur: = func() -> String: return G.fx_level() if key == "fx_level" else G.ult_cutin()
	var btns: = []
	var opts: Array = seg[2]
	var paint: = func():
		var c: String = cur.call()
		for j in btns.size():
			Common.tab_paint(btns[j], opts[j][0] == c)
		hint.text = String(seg[3].get(c, ""))
	var w: = (592.0 - 16.0) / opts.size()
	for j in opts.size():
		var val: String = opts[j][0]
		var b: = JButton.make(opts[j][1], "glass", Rect2(34 + j * (w + 8.0), y + 40, w, 56), null, 22, -1.0, false)
		b.pressed.connect( func():
			if key == "fx_level":
				G.set_fx_level(val)
			else:
				G.set_ult_cutin(val)
			G.save()
			paint.call())
		p.add_child(b)
		btns.append(b)
	paint.call()


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
	# 0.8: the rank ladder lives in the profile screen.
	go("profile", {"from": screen_id if screen_id != "" else "home"})


func maybe_offer() -> void :
	# 0.8 (Stream E): «Набор первого гостя» — once, after the 3rd Path win, valid 72 h (scripts/v08/play/starter.gd).
	V8Starter.maybe_show(self)

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
	if a.has("rp"):
		# dev: preview the top bar / screens at another rank (not saved unless the screen saves)
		G.S.rp = int(a.rp)
		_refresh_profile_chip()
	if a.has("outfit"):
		var it: Dictionary = G.ITEM[a.outfit]
		G.S.owned[a.outfit] = true
		G.S.outfit[it.hero] = a.outfit
		G.S.partner = it.hero
	if a.has("fuzz"):
		V7Fuzz.run(self, int(a.fuzz))
		return
	if a.has("pt"):
		# 0.8 playtest runner (scripts/v08/devtools/playtest.gd): plays from the title with touch input
		V8Playtest.start(self, a)
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


# ---- 0.8 top bar (Stream D): player avatar + nick + rank on the left (tap -> profile), two currencies right.
var prof_root: Control
var _prof_key: = ""
var history: Array = []
const NAV_OFF: = Color(0.66, 0.62, 0.6, 0.88)
const NAV_LOCKED: = Color(0.42, 0.4, 0.4, 0.75)
const NO_HISTORY: = ["play", "arena", "v7play"]
const PLAY_BACK: = {"play": "home", "arena": "modes", "v7play": "v7event"}

func _build_topbar() -> void :
	topbar = Control.new()
	topbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(topbar)
	prof_root = Control.new()
	prof_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	topbar.add_child(prof_root)
	_build_profile_chip()
	var gp: = _currency(Rect2(W - 344, 32, 160, 54), "gem", G.S.gems)
	gems_lbl = gp
	var cp: = _currency(Rect2(W - 176, 32, 160, 54), "coin", G.S.coins)
	coins_lbl = cp
	for sig in [G.profile_changed, G.rank_changed, G.rp_changed]:
		if not (sig as Signal).is_connected(_on_profile_signal):
			(sig as Signal).connect(_on_profile_signal)

func _on_profile_signal(_a = null, _b = null) -> void :
	_refresh_profile_chip()

func _profile_key() -> String:
	var ri: = G.rank_of(int(G.S.rp))
	return "%s|%s|%s|%d" % [G.nick(), str(G.profile().get("avatar", "mc")), ri.title, int(ri.into)]

func _refresh_profile_chip() -> void :
	if prof_root and is_instance_valid(prof_root) and _profile_key() != _prof_key:
		_build_profile_chip()

func _build_profile_chip() -> void :
	for c in prof_root.get_children():
		prof_root.remove_child(c)
		c.queue_free()
	_prof_key = _profile_key()
	var ri: = G.rank_of(int(G.S.rp))
	var plate: = UI.rbox("glass", Rect2(96, 22, 270, 82), 26, 3, 10)
	prof_root.add_child(plate)
	var av_id: = str(G.profile().get("avatar", "mc"))
	if not Hero.RIGS.has(av_id):
		av_id = "mc"
	# 0.8 avatar frame (V8Art): the ornate one from Dragon up. Both boxes put the portrait centre at ≈(64, 60).
	var top: = V8Art.top_tier(int(ri.tier))
	var ring: = V8Art.avatar(prof_root, av_id, Rect2(2, 8, 124, 124) if top else Rect2(10, 13, 108, 108), top)
	var nick: = G.nick()
	var nx: = 122.0
	var nw: = 366.0 - nx - 14.0
	var fs: = 24
	var f: = UI.font("body", 900)
	while fs > 18 and f.get_string_size(nick, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > nw:
		fs -= 1
	var nl: = UI.label(nick, fs, Color("fff6ea"), UI.DARK, 3, "body", 900)
	nl.position = Vector2(nx, 24)
	nl.size = Vector2(nw, 32)
	nl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nl.clip_text = true
	prof_root.add_child(nl)
	rank_em = Common.rank_emblem(prof_root, Rect2(nx - 6, 54, 46, 46), ri.tier, ri.sub)
	rank_lbl = UI.label(ri.title, 18, Color(G.RANKS[ri.tier].color).lerp(Color("fff6ea"), 0.45), UI.DARK, 3, "body", 900)
	rank_lbl.position = Vector2(nx + 44, 58)
	rank_lbl.size = Vector2(nw - 44, 22)
	rank_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rank_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	rank_lbl.clip_text = true
	prof_root.add_child(rank_lbl)
	var bw: = nw - 48.0
	var xpbg: = UI.rbox("cream", Rect2(nx + 46, 84, bw, 10), 5, 1, 3)
	xpbg.set_param("shadow_color", Color(0, 0, 0, 0))
	prof_root.add_child(xpbg)
	rank_bar = UI.rbox("gold", Rect2(nx + 47, 85, (bw - 2) * clampf(float(ri.into) / ri.need, 0.06, 1.0), 8), 4, 0, 2)
	rank_bar.set_param("shadow_color", Color(0, 0, 0, 0))
	prof_root.add_child(rank_bar)
	var hit: = Control.new()
	hit.position = Vector2(10, 10)
	hit.size = Vector2(360, 104)
	hit.mouse_filter = Control.MOUSE_FILTER_STOP
	hit.gui_input.connect( func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			Sfx.play("pop")
			UI.punch(ring, 0.08)
			if screen_id != "profile":
				go("profile", {"from": screen_id if screen_id != "" else "home"}))
	prof_root.add_child(hit)

# Round heroine portrait without a frame (collection.gd heroine row). The player's own avatar uses V8Art.avatar.
func _avatar(hero: String, r: Rect2) -> TextureRect:
	var t: = UI.tex(load("res://assets/hero/%s.png" % hero), r, false)
	var m: = ShaderMaterial.new()
	m.shader = preload("res://shaders/card.gdshader")
	m.set_shader_parameter("size", r.size)
	m.set_shader_parameter("radius", r.size.x * 0.5)
	m.set_shader_parameter("tex_size", Vector2(848, 1264))
	m.set_shader_parameter("focus", Hero.av_focus(hero))
	m.set_shader_parameter("zoom", Hero.av_zoom(hero))
	m.set_shader_parameter("bottom_shade", 0.0)
	t.material = m
	return t

func _currency(r: Rect2, icon: String, val: int) -> Label:
	var p: = UI.rbox("plum", r, r.size.y * 0.5, 3, 10)
	p.set_param("border_top", Color("ffe7a6")).set_param("border_bottom", Color("c58a2c"))
	topbar.add_child(p)
	topbar.add_child(V8Art.rect(V8Art.cur(icon), Rect2(r.position.x - 1, r.position.y + 1, 52, 52)))
	var l: = UI.label(UI.fmt(val), 22, Color.WHITE, Color(0.2, 0.05, 0.2), 4)
	l.position = r.position + Vector2(50, 0)
	l.size = Vector2(r.size.x - 50 - 44, r.size.y)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	topbar.add_child(l)
	_fit_currency(l)
	# 0.8: the whole currency pill (64 px high hit rect) is the tap target; the 36 px «+» art sits at its right end
	var hr: = Rect2(r.position.x, r.get_center().y - 32.0, r.size.x, 64.0)
	var plus: = JButton.make("", "graphite", hr, null, 22)
	plus.box.visible = false
	plus.add_child(V8Art.rect(V8Art.icon("plus"), Rect2(hr.size.x - 40.0, 14.0, 36, 36)))
	plus.pressed.connect( func(): go("shop", {"tab": 2} if icon == "gem" else {}))
	topbar.add_child(plus)
	return l

# Icon for toast(..., icon) and other callers that pass an old icon name: currencies -> cur/*, nav names -> nav/*,
# glyphs -> icon/* (V8Art aliases, star -> the sakura star); names with no 0.8 art keep their old texture.
func art_icon(name: String) -> Texture2D:
	if name == "":
		return null
	return Common.ui_icon(name)

# currency amount between the coin art and the «+»: shrink the font for big numbers instead of running under the «+»
func _fit_currency(l: Label) -> void :
	var fs: = 22
	var f: = UI.font("body", 800)
	while fs > 16 and f.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > l.size.x:
		fs -= 1
	if l.label_settings.font_size != fs:
		l.label_settings = l.label_settings.duplicate()
		l.label_settings.font_size = fs

func refresh_currency(punch: = false) -> void :
	gems_lbl.text = UI.fmt(G.S.gems)
	_refresh_profile_chip()
	coins_lbl.text = UI.fmt(G.S.coins)
	_fit_currency(gems_lbl)
	_fit_currency(coins_lbl)
	if punch:
		UI.punch(gems_lbl, 0.25)

func gem_target() -> Vector2:
	return Vector2(W - 320, 58)

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
		var ic: = V8Art.rect(V8Art.nav(tab.icon), Rect2(tw * 0.5 - 27, 40, 54, 54) if not big else Rect2(tw * 0.5 - 38, -10, 76, 76))
		ic.name = "IC"
		ic.pivot_offset = ic.size * 0.5
		if not big:
			ic.modulate = NAV_OFF
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
		var lk: = UI.rbox("graphite", Rect2(tw * 0.5 + 2, 50, 38, 38), 19, 2, 6)
		lk.set_meta("navmark", true)
		lk.add_child(V8Art.rect(V8Art.icon("lock"), Rect2(6, 5, 26, 26)))
		c.add_child(lk)
		(c.get_node("IC") as CanvasItem).modulate = NAV_LOCKED
	else:
		if screen_id != "summon":
			(c.get_node("IC") as CanvasItem).modulate = NAV_OFF
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
		l.label_settings = l.label_settings.duplicate()
		l.label_settings.font_color = UI.GOLD if on else UI.MUTED
		var t: Tween = ic.create_tween().set_parallel()
		t.tween_property(ic, "scale", Vector2(1.18, 1.18) if on else Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(ic, "position:y", 30.0 if on else 40.0, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(ic, "modulate", Color.WHITE if on else (NAV_LOCKED if k == "summon" and not G.summon_open() else NAV_OFF), 0.2)
		if on and not G.demo:
			Fx.ring(c, Vector2(c.size.x * 0.5, 64), Color(1, 0.85, 0.6, 0.6), 0.6, 0.3)

func show_chrome(top: bool, nav: bool) -> void :
	topbar.visible = top
	navbar.visible = nav


func go(id: String, args: = {}, animate: = true, remember: = true) -> void :
	if busy or (id == screen_id and args.is_empty()):
		return
	if id == "summon" and not G.summon_open():
		toast(V6Txt.s("summon.locked"), "gem")
		UI.punch(tab_nodes["summon"], 0.12)
		return
	var from_id: = screen_id
	var from_args: Dictionary = screen.get_meta("v8_args", {}) if screen and is_instance_valid(screen) else {}
	await V6Story.before_go(self, id, args)
	for p in overlay.get_children():
		if p.has_meta("popup") or p.has_meta("v8_back"):
			p.queue_free()
	busy = true
	if id == "home":
		history.clear()
	elif remember and from_id != "" and from_id != id and not from_id in NO_HISTORY:
		history.append([from_id, from_args])
		if history.size() > 12:
			history.pop_front()
	if animate:
		Sfx.play("whoosh", 1.0, -4)
		var t: = create_tween()
		t.tween_method( func(v): trans_mat.set_shader_parameter("progress", v), 0.0, 1.0, 0.32).set_trans(Tween.TRANS_QUAD)
		await t.finished
	if screen:
		screen.queue_free()
	screen_id = id
	# 0.8: in a match, popups and toasts draw above everything of the table, also above tiles lifted into the
	# tray (z 200+) or flying specials (z 160), so nothing from the match shows through a window. Elsewhere the
	# overlay stays at z 0 under views added straight to main (title, story scenes).
	var match_z: = PLAY_BACK.has(id)
	overlay.z_index = 400 if match_z else 0
	trans.z_index = 450 if match_z else 0
	screen = Control.new()
	screen.set_script(SCREENS[id])
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.size = Vector2(W, H)
	screen.set_meta("v8_args", args.duplicate())
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

# «назад» of a V8Header: previous screen from the history (play screens are never returned to), else home.
func back() -> void :
	if busy:
		return
	while not history.is_empty():
		var e: Array = history.pop_back()
		var id: String = e[0]
		if id == screen_id or not SCREENS.has(id):
			continue
		go(id, e[1], true, false)
		return
	if screen_id != "home":
		go("home")

# Android «назад» (and Esc on desktop): close the top popup, else the screen's own back, else the previous screen.
func android_back() -> void :
	if busy:
		return
	# full-screen views added straight to main (title, story and date scenes, profile card): only their own back
	for i in range(get_child_count() - 1, -1, -1):
		var v: Node = get_child(i)
		if v in [screen_root, topbar, navbar, overlay, trans, finger] or not (v is CanvasItem and (v as CanvasItem).visible):
			continue
		if v.has_meta("v8_back"):
			var cbv = v.get_meta("v8_back")
			if cbv is Callable and (cbv as Callable).is_valid():
				(cbv as Callable).call()
		return
	for i in range(overlay.get_child_count() - 1, -1, -1):
		var r: Node = overlay.get_child(i)
		if r.has_meta("closing") or not (r is CanvasItem and (r as CanvasItem).visible):
			continue
		if r.has_meta("v8_back"):
			var cb = r.get_meta("v8_back")
			if cb is Callable and (cb as Callable).is_valid():
				(cb as Callable).call()
			return
		if r.has_meta("popup"):
			if not r.get_meta("closable", true):
				return
			for c in r.get_children():
				if c is RBox and c.has_meta("root"):
					Common.close_popup(c)
					return
			r.queue_free()
			return
	if screen == null or not is_instance_valid(screen):
		return
	if screen.has_method("handle_back") and screen.call("handle_back"):
		return
	if screen.has_meta("v8_back"):
		var cb2 = screen.get_meta("v8_back")
		if cb2 is Callable and (cb2 as Callable).is_valid():
			(cb2 as Callable).call()
			return
	if screen_id == "home":
		return
	if PLAY_BACK.has(screen_id):
		leave_match()
		return
	back()

# 0.8: leaving a running match (Android back or the house button of the match HUD): ask first, count the
# table as a game without a win, then go to the screen the match came from. With the result window up
# (the game is already saved) leave at once.
func leave_match() -> void :
	if busy or screen == null or not is_instance_valid(screen):
		return
	var to: String = PLAY_BACK.get(screen_id, "home")
	var pm = screen.get("mode")
	if screen_id == "v7play" and pm is String and pm == "v7tourney":
		to = "v7tourney"
	var over = screen.get("_v8_over")
	var saved = screen.get("_v8_saved")
	if (over is bool and over) or (saved is bool and saved):
		go(to)
		return
	var sc: = screen
	Common.confirm(self, "Выйти из партии?", "Прогресс этой партии не сохранится.", "", 0, func():
		if is_instance_valid(sc) and sc.has_method("_v8_record_loss"):
			sc.call("_v8_record_loss")
		go(to), {"yes_text": "Выйти", "no_text": "Играть"})

func _notification(what: int) -> void :
	if what == NOTIFICATION_READY:
		get_tree().quit_on_go_back = false
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		android_back()

func _unhandled_key_input(e: InputEvent) -> void :
	if e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_ESCAPE:
		android_back()
		get_viewport().set_input_as_handled()

func toast(text: String, icon: = "") -> void :
	var w: = 560.0
	var y: = V8Header.CONTENT_Y + 12.0 if topbar and topbar.visible else 130.0
	# 0.8: during a match the top of the screen is the HUD (goal, gems, tray) and the table reaches down to the
	# action buttons, so a toast sits at the very bottom, over the buttons' captions (it takes no tap), and there
	# is one slot only: a new toast replaces the one before instead of stacking up into the tiles
	var in_match: = PLAY_BACK.has(screen_id) and not (topbar and topbar.visible)
	# 0.8: in a match the notice is a slim one-line plaque in the strip between the table and the action buttons
	# (play.v8_notice): it covers neither tiles nor the buttons' captions and counters
	if in_match and screen and is_instance_valid(screen) and screen.has_method("v8_notice"):
		if screen.v8_notice(text, art_icon(icon) if icon != "" else null):
			return
	if in_match:
		y = get_viewport_rect().size.y - 74.0
	for c in overlay.get_children():
		if c.has_meta("v8_toast") and not c.is_queued_for_deletion() and not c.has_meta("fading"):
			if in_match:
				c.set_meta("fading", true)
				var ft: Tween = c.create_tween()
				ft.tween_property(c, "modulate:a", 0.0, 0.12)
				ft.tween_callback(c.queue_free)
			else:
				y = maxf(y, float(c.get_meta("v8_toast")) + 82.0)
	var x: = (W - w) * 0.5
	var th: = 70.0
	# 0.8: a toast never covers a modal's ribbon or body: with a popup open it goes into the free band under the
	# panel (or above the ribbon when the panel reaches the bottom). Without one, a screen may give its own slot
	# (home: the speech-bubble band left of the cards; the bubble steps aside while the toast is up).
	var pop_r: = _open_popup_rect()
	if not in_match and pop_r.size != Vector2.ZERO:
		var vh: = get_viewport_rect().size.y
		var nav_top: = vh - 150.0 if navbar and navbar.visible else vh - 24.0
		if pop_r.end.y + 16.0 + th <= nav_top:
			y = pop_r.end.y + 16.0
		else:
			y = maxf(V8Header.CONTENT_Y * 0.5, pop_r.position.y - 46.0 - th - 10.0)
		for c in overlay.get_children():
			if c.has_meta("v8_toast") and not c.is_queued_for_deletion() and not c.has_meta("fading"):
				c.set_meta("fading", true)
				var ft2: Tween = c.create_tween()
				ft2.tween_property(c, "modulate:a", 0.0, 0.12)
				ft2.tween_callback(c.queue_free)
	elif not in_match and screen and is_instance_valid(screen) and screen.has_method("v8_toast_rect"):
		var sr: Rect2 = screen.v8_toast_rect()
		if sr.size != Vector2.ZERO:
			x = sr.position.x
			w = sr.size.x
			th = sr.size.y
			y = sr.position.y
			for c in overlay.get_children():
				if c.has_meta("v8_toast") and not c.is_queued_for_deletion() and not c.has_meta("fading"):
					y = maxf(y, float(c.get_meta("v8_toast")) + th + 10.0)
			if screen.has_method("v8_toast_shown"):
				screen.v8_toast_shown(2.6)
	var p: = UI.rbox("plum", Rect2(x, y, w, th), 35, 3, 12)
	p.set_param("border_top", Color("ffe7a6")).set_param("border_bottom", Color("c58a2c"))
	p.set_meta("v8_toast", y)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(p)
	var x0: = 20.0
	if icon != "":
		p.add_child(V8Art.rect(art_icon(icon), Rect2(10, 6, 58, 58)))
		x0 = 72
	var fs: = 22
	if UI.font("body", 800).get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > (w - x0 - 16) * 2.0:
		fs = 19
	if w < 480.0:
		fs = mini(fs, 19)
	var l: = UI.label(text, fs, Color.WHITE, Color(0.2, 0.05, 0.2), 3)
	# wrap mode first: a Label sized before autowrap is on keeps the one-line width and runs past the pill
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.position = Vector2(x0, 0)
	l.size = Vector2(w - x0 - 16, th)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	UI.slide_in(p, Vector2(0, -60), 0.0, 0.35)
	var t: Tween = p.create_tween()
	t.tween_interval(2.0)
	t.tween_callback(func(): p.set_meta("fading", true))
	t.tween_property(p, "modulate:a", 0.0, 0.3)
	t.tween_callback(p.queue_free)


# the panel of the topmost open Common.popup (its ribbon pokes ~40 px above), or an empty rect
func _open_popup_rect() -> Rect2:
	for i in range(overlay.get_child_count() - 1, -1, -1):
		var c: = overlay.get_child(i)
		if c.has_meta("popup") and not c.is_queued_for_deletion() and c is Control and (c as Control).visible:
			for k in c.get_children():
				if k is RBox and k.has_meta("root"):
					return Rect2((k as Control).position, (k as Control).size)
	return Rect2()

func fly_gems(from: Vector2, n: int) -> void :
	for i in min(n, 8):
		var s: = TextureRect.new()
		s.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		s.texture = V8Art.cur("gem")
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
