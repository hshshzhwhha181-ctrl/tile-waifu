extends Control


# 0.10 W1 (UX_RULES §3.1, HUD_V2 §8.2): five EQUAL tabs, no star. Ids stay where the screen is the same (playtest,
# tutorial, V10Music); the centre tab is the new «Столы» hub (scripts/v10/core/tables_hub.gd).
const TABS: = [
	{"id": "home", "name": "Чайная", "icon": "tab_tea"}, 
	{"id": "collection", "name": "Героини", "icon": "tab_heroines"}, 
	{"id": "tables", "name": "Столы", "icon": "tab_tables"}, 
	{"id": "summon", "name": "Желания", "icon": "tab_wishes"}, 
	{"id": "shop", "name": "Лавка", "icon": "tab_shop"}, 
]
var SCREENS: = {
	"home": preload("res://scripts/screens/home.gd"), 
	"levels": preload("res://scripts/screens/levels.gd"), 
	"play": preload("res://scripts/screens/play.gd"), 
	"summon": preload("res://scripts/v10/gacha/ui/wish_screen.gd"), 
	"collection": preload("res://scripts/screens/collection.gd"), 
	"shop": preload("res://scripts/v10/shop/shop2_screen.gd"), 
	"modes": preload("res://scripts/screens/modes.gd"), 
	"arena": preload("res://scripts/v06/modes/mode_play.gd"), 
	"room": preload("res://scripts/v07/room/room.gd"), 
	"v7event": preload("res://scripts/v07/event/event_screen.gd"), 
	"v7tourney": preload("res://scripts/v07/event/tourney_screen.gd"), 
	"v7play": preload("res://scripts/v07/event/event_play.gd"),
	"profile": preload("res://scripts/v08/profile/profile_screen.gd"),
	"letters": preload("res://scripts/v09/letters/letters_screen.gd"),
	"tables": preload("res://scripts/v10/core/tables_hub.gd"),
	"v10boudoir": preload("res://scripts/v10/salon/vip_boudoir_screen.gd"),
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
# 0.10 M0 (V10Layout): the column screens are built in (≤720 wide, centred, below a camera cut-out) and the
# safe insets in viewport px. Chrome plates and backgrounds bleed to the real edges.
var CR: = Rect2(0, 0, 720, 1280)
var safe_top: = 0.0
var safe_bottom: = 0.0

const V11_SCENE: = "res://shell/main_v11.tscn"

# 0.11 (P25): `--shell=v11` (user arg) or ProjectSettings tw/shell = "v11" boots the v11 shell, whose root is a LegacyHost
# extending this very script, instead. Default OFF: without the flag nothing below the first `if` of _ready changes.
# LegacyHost overrides this to false.
func _shell_redirect() -> bool:
	if "--shell=v11" in OS.get_cmdline_user_args() or str(ProjectSettings.get_setting("tw/shell", "v10")) == "v11":
		if ResourceLoader.exists(V11_SCENE):
			get_tree().change_scene_to_file.call_deferred(V11_SCENE)
			return true
	return false

func _ready() -> void :
	if _shell_redirect():
		return
	# 0.10: screens of the wired modules (V10Registry) join the table (a const dict cannot grow)
	SCREENS.merge(V10Registry.screens())
	var vs: = get_viewport_rect().size
	W = vs.x
	H = vs.y
	CR = V10Layout.content_rect(vs)
	var ins: = V10Layout.safe_insets(vs)
	safe_top = float(ins.top)
	safe_bottom = float(ins.bottom)
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
	V10ShopSheet.layer = overlay
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
	AudioServer.set_bus_mute(0, not (bool(G.S.get("sound", true)) or bool(G.S.get("music", true)) or bool(G.S.get("voice", true))))
	go("home", {}, false)
	_splash()
	if G.demo:
		run_demo()
	_dev_args()
	V10Juice.warm.call_deferred()
	var uargs: = " ".join(OS.get_cmdline_user_args())
	var skip_tut: = "--pt=" in uargs or "--shots" in uargs or "--layout_shots=" in uargs or "--layout_selftest=" in uargs or "--meta_shots=" in uargs or "--selftest" in uargs or "--fuzz=" in uargs or "--v10_selftest=" in uargs or G.demo
	if not skip_tut:
		V10Tutorial.attach(self)



func _splash() -> void :
	var args: = " ".join(OS.get_cmdline_user_args())
	if "--profile_selftest=1" in args:
		await get_tree().process_frame
		var f: = V8ProfileSelftest.run(self)
		get_tree().quit(1 if f > 0 else 0)
		return
	if "--shots" in args and not "--splash" in args and not "--pt=" in args:
		return
	# 0.10 M0: the layout runner (V10LayoutShots) opens the title itself when it wants it
	if ("--layout_shots=" in args or "--layout_selftest=" in args) and not has_node("V10LayoutShots"):
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
	var cg_path: = "res://assets/v10/cg_16/intro_mc_table.webp"
	var use_cg: = not bool(G.S.get("modest", false)) and ResourceLoader.exists(cg_path)
	var hero: Hero = null
	if use_cg:
		var cg_tex: = load(cg_path) as Texture2D
		if cg_tex != null:
			var cg_clip: = Control.new()
			cg_clip.name = "SplashCgClip"
			cg_clip.size = sp.size
			cg_clip.clip_contents = true
			cg_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			sp.add_child(cg_clip)
			var splash_cg: = TextureRect.new()
			splash_cg.name = "SplashCg"
			splash_cg.texture = cg_tex
			splash_cg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			splash_cg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			splash_cg.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			splash_cg.position = Vector2.ZERO
			splash_cg.size = sp.size
			splash_cg.pivot_offset = Vector2(sp.size.x * 0.5, sp.size.y * 0.34)
			splash_cg.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cg_clip.add_child(splash_cg)
			var ktw: = splash_cg.create_tween().set_loops()
			ktw.tween_property(splash_cg, "scale", Vector2(1.042, 1.042), 6.0).set_trans(Tween.TRANS_SINE)
			ktw.tween_property(splash_cg, "scale", Vector2.ONE, 6.0).set_trans(Tween.TRANS_SINE)
			Common.vignette(sp, sp.size, Color(0.08, 0.03, 0.15), 0.38)
			Fx.ambient(sp, "lanterns", sp.size)
			Fx.ambient(sp, "petals", sp.size)
		else:
			use_cg = false
	if not use_cg:
		Common.backdrop(sp, "bg_festival", sp.size, 0.0, 0.8, Color(0.92, 0.88, 1.0), Vector2(0.5, 0.5))
		Common.vignette(sp, sp.size, Color(0.08, 0.03, 0.15), 0.75)
		Common.rays(sp, Vector2(W * 0.5, H * 0.24), 1200, Color(1, 0.85, 0.6, 0.45), 12, 0.03, 0.5)
		Fx.ambient(sp, "lanterns", sp.size)
		Fx.ambient(sp, "petals", sp.size)
		hero = Hero.new().setup("mc", H * 0.6)
		hero.position = Vector2(W * 0.5, H + 30)
		hero.interactive = false
		sp.add_child(hero)
		UI.slide_in(hero, Vector2(0, 120), 0.4, 0.9)
	# HUD_V2 lower-third lacquer fade: keeps intro_mc_table.webp vivid while framing the logo & dusty-rose CTA pill
	var fade_top: = (H - safe_bottom - 448.0) if use_cg else (H - 470.0)
	var fade_bot: = (H - safe_bottom - 156.0) if use_cg else (H - 290.0)
	var fade_a: = 0.90 if use_cg else 0.95
	var ff: = Common.floor_fade(sp, fade_top, fade_bot, V10DS.NIGHT_900, fade_a)
	ff.name = "TitleFade"
	var fb: = ColorRect.new()
	fb.color = Color(V10DS.NIGHT_900, fade_a)
	fb.position = Vector2(0, fade_bot)
	fb.size = Vector2(W, H - fade_bot)
	fb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sp.add_child(fb)
	# 0.10 M0: the logo block starts below a camera cut-out; on 16+ full-bleed CG splash it sits compactly in the
	# lower-third above «Играть» so Маджонг-тян's face and table pose stay unobstructed.
	var lw: = 380.0 if use_cg else 540.0
	var lh: = 216.0 if use_cg else 306.0
	var ly: = (H - safe_bottom - 418.0) if use_cg else (safe_top + H * 0.04 + maxf(0.0, H - 1280.0) * 0.12)
	var logo: = V8Art.rect(V8Art.misc("logo"), Rect2(W * 0.5 - lw * 0.5, ly, lw, lh))
	logo.pivot_offset = Vector2(lw * 0.5, lh * 0.5)
	sp.add_child(logo)
	UI.pop_in(logo, 0.15, 0.4)
	var tag_y: = (ly + lh - 8.0) if use_cg else (ly + H * 0.01 + 300.0)
	var tag: = V10Type.label(V6Txt.s("title.tag"), "ui", 18 if use_cg else 22, V10DS.PAPER_300, true)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tag.position = Vector2(0, tag_y)
	tag.size = Vector2(W, 30)
	sp.add_child(tag)
	UI.slide_in(tag, Vector2(0, 20), 0.5)
	var fades: Array = [logo, tag]
	var has_profile: = bool(G.S.get("profile_done", false))
	if has_profile:
		var chip_y: = (safe_top + 18.0) if use_cg else (ly + H * 0.01 + 346.0)
		var chip: = V8ProfileUI.title_chip(Rect2(0, chip_y, W, 64))
		sp.add_child(chip)
		UI.slide_in(chip, Vector2(0, 16), 0.6)
		fades.append(chip)
	# HUD_V2 §2.5 dusty-rose stadium pill («Играть», matching 03_home & 04_victory) with thin champagne-gold rim
	var pill_w: = 440.0
	var pill_h: = 100.0
	var plate: = Panel.new()
	plate.name = "PlayPill"
	plate.position = Vector2((W - pill_w) * 0.5, H - safe_bottom - 168.0)
	plate.size = Vector2(pill_w, pill_h)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var psb: = StyleBoxFlat.new()
	psb.bg_color = V10DS.ROSE_500
	psb.border_color = Color(V10DS.GOLD_300, 0.72)
	psb.set_border_width_all(1)
	psb.set_corner_radius_all(int(pill_h * 0.5))
	psb.shadow_color = Color(V10DS.NIGHT_900, 0.52)
	psb.shadow_size = 12
	psb.shadow_offset = Vector2(0, 4)
	plate.add_theme_stylebox_override("panel", psb)
	sp.add_child(plate)
	var gleam: = ColorRect.new()
	gleam.color = Color(V10DS.PAPER_100, 0.28)
	gleam.position = Vector2(52.0, 2.0)
	gleam.size = Vector2(pill_w - 104.0, 1.0)
	gleam.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(gleam)
	var ptl: = Label.new()
	ptl.name = "PlayText"
	ptl.text = V6Txt.s("title.tap")
	ptl.label_settings = V10Type.settings("display", 32, V10DS.NIGHT_900)
	ptl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ptl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ptl.position = Vector2.ZERO
	ptl.size = Vector2(pill_w, pill_h)
	ptl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(ptl)
	plate.pivot_offset = Vector2(pill_w * 0.5, pill_h * 0.5)
	UI.pop_in(plate, 0.65, 0.92)
	var pt: = plate.create_tween().set_loops()
	pt.tween_property(plate, "scale", Vector2(1.015, 1.015), 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pt.tween_property(plate, "scale", Vector2(0.99, 0.99), 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var ver: = V10Type.label(V6Txt.s("title.version") % G.version(), "ui", 18, Color(V10DS.PAPER_500, 0.72))
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ver.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ver.position = Vector2(0, H - safe_bottom - 44.0)
	ver.size = Vector2(W, 26)
	sp.add_child(ver)
	fades.append_array([plate, ver])
	Sfx.music("menu")
	await get_tree().create_timer(0.8).timeout
	await _wait_tap(sp)
	Sfx.play("reveal_sr", 0.9)
	if hero != null and is_instance_valid(hero):
		hero.react("big")
	var need_card: = not has_profile
	var need_intro: bool = not G.S.get("intro_done", false)
	if not (G.S.get("v10_shop") is Dictionary):
		G.S["v10_shop"] = V10ShopModel.defaults()
	var need_age: = V10Age.needs_gate(G.S.v10_shop, V10Meta.now_unix()) and not ("--meta_shots=" in args)
	if need_age or need_card or need_intro:
		pt.kill()
		var t0: = create_tween().set_parallel()
		for n in fades:
			t0.tween_property(n, "modulate:a", 0.0, 0.3)
		await t0.finished
	if need_age:
		var gate: = V10AgeGate.make(G.S.v10_shop, V10Meta.now_unix())
		sp.add_child(gate)
		var band: String = await gate.done
		G.save()
		if band == "child":
			return
		gate.queue_free()
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
	var box: = UI.rbox("plum", Rect2(CR.position.x + 14, H - safe_bottom - 344, CR.size.x - 28, 252), 28, 4, 12)
	box.colors(Color(0.11, 0.045, 0.16, 0.94), Color(0.05, 0.02, 0.08, 0.97)).borders(Color("ffeaa8"), Color("c88f32"))
	sp.add_child(box)
	var nameplate: = UI.rbox("pink", Rect2(26, -28, 256, 54), 24, 3, 8)
	nameplate.borders(Color("ffeaa8"), Color("c88f32"))
	box.add_child(nameplate)
	nameplate.add_child(UI.center_label(UI.label("Маджонг-тян", 26, Color("fff8ec"), Color("4a1028"), 5, "body", 900), Rect2(0, 0, 256, 54)))
	var txt: = UI.label("", 27, Color("fff7eb"), Color(0.05, 0.02, 0.08, 0.96), 4, "body", 800)
	txt.position = Vector2(28, 38)
	txt.size = Vector2(CR.size.x - 84, 174)
	txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(txt)
	var more: = UI.label("▼", 24, Color("ffe28a"))
	more.position = Vector2(CR.size.x - 78, 206)
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
		# 0.9: the advancing tap answers through V9Feel (the ▼ dips, click + tap haptic)
		V9Feel.press(more, "tap", "tap")


# 0.9: two 3-way rows on top — «Эффекты» (S.fx_level) and «Вставки ульт» (S.ult_cutin) — then the on/off rows.
# «Тряска и вспышки» folded into «Эффекты» (only "full" shakes and flashes; G keeps S.v6_fx in step).
const SETTINGS_SEG: = [
	["fx_level", "Эффекты", [["full", "Полные"], ["mid", "Умеренные"], ["min", "Минимум"]],
		{"full": "Вспышки, тряска, частицы и ауры", "mid": "Без тряски и вспышек по краям экрана", "min": "Только отклик на нажатия"}],
	["ult_cutin", "Вставки приёмов", [["full", "Полностью"], ["short", "Коротко"], ["off", "Выкл"]],
		{"full": "Полная сцена при первом приёме дня в наряде", "short": "Короткая вставка, меньше секунды", "off": "Только эффект на поле"}],
]

func settings() -> void :
	var p: = Common.popup(self, V6Txt.s("settings.title"), 1068)
	var y: = 50.0
	for seg in SETTINGS_SEG:
		_settings_seg(p, seg, y)
		y += 132.0
	var rows: = [
		["cutins", V6Txt.s("settings.cutins"), V6Txt.s("settings.cutins_d")], 
		["modest", V6Txt.s("settings.modest"), V6Txt.s("settings.modest_d")], 
		["deco_fonts", "Декоративные шрифты", "Особые шрифты заголовков героинь"], 
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
			AudioServer.set_bus_mute(0, not (bool(G.S.get("sound", true)) or bool(G.S.get("music", true)) or bool(G.S.get("voice", true))))
			if key == "voice" and not v and Sfx.voice:
				Sfx.voice.stop()
			b.lbl.text = V6Txt.s("common.on") if v else V6Txt.s("common.off")
			b.set_pal("mint" if v else "glass")
			if key == "deco_fonts":
				V10Fonts.deco = v
			if key == "music":
				Sfx.cur_music = ""
				if V10Registry.wired("audio"):
					if v:
						V10Music.play_screen(screen_id)
					else:
						V10Music.stop(0.25)
				else:
					Sfx.music("menu" if v else "")
			if key in ["modest", "deco_fonts"] and screen_id in ["home", "collection", "shop", "summon"]:
				p.get_meta("root").set_meta("on_close", func():
					var sid: = screen_id
					screen_id = ""
					go(sid, {}, false)))
		p.add_child(b)
		y += rh

	var sl: = UI.label(V6Txt.s("settings.side"), 26, UI.INK, Color.WHITE, 3, "body", 900)
	sl.position = Vector2(34, 926)
	p.add_child(sl)
	var fb: = JButton.make(V6Txt.s("settings.side_f"), "pink" if G.S.side == "f" else "glass", Rect2(220, 914, 196, 64), null, 22, -1.0, false)
	var mb: = JButton.make(V6Txt.s("settings.side_m"), "glass", Rect2(428, 914, 200, 64), null, 20, -1.0, false)
	Common.tab_paint(fb, G.S.side == "f")
	Common.tab_paint(mb, false)
	fb.pressed.connect( func():
		G.S.side = "f"
		G.save())
	# 0.9: «мужская сторона» is not available yet: a closed gate, so a tap gets only the deny (no dip-and-overshoot
	# press first) and the toast says why; dimmed like a locked option
	mb.set_gate( func(): return false, func(): toast(V6Txt.s("settings.side_m_toast"), "heart"))
	mb.modulate = Color(1, 1, 1, 0.72)
	p.add_child(fb)
	p.add_child(mb)
	var eg: = UI.label("Тайники найдены: %d из %d" % [V7Eggs.found_count(), V7Eggs.total()], 18, Color("d9c4e6"))
	eg.position = Vector2(34, 994)
	p.add_child(eg)
	var vl: = UI.label(V6Txt.s("title.version") % G.version(), 16, Color(1, 1, 1, 0.45))
	vl.position = Vector2(34, 1024)
	vl.size = Vector2(592, 24)
	vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	p.add_child(vl)
	V10Clarity.settings_hook(self, p)  # v10-clarity hook: «Фишки и словарь»
	V10Nav.settings_notify(self, p)  # 0.10 W1 (meta Ф1): «Уведомления»
	V10Nav.settings_bday(self, p)  # 0.10 W2 (rituals Р7): «Мой день рождения»
	V10Nav.settings_account(self, p)  # 0.10 W4 (auth): «Аккаунт»
	V10Nav.settings_help(self, p)  # 0.10 W4 (tutorial/help): «Как играть»
	V10Nav.settings_fonts(self, p)  # 0.10 W3 (fonts D2): «Шрифты и лицензии» (wraps SettingsScroll)


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


func need_gems(deficit: int) -> void :
	var sm: = V10ShopHub.model()
	if sm != null:
		var top_cb: = func() -> void:
			if V10Nav.tab_open("shop"):
				go("shop", {"tab": 2})
			else:
				toast(V10Nav.tab_lock_text("shop"), "lock")
		V10ShopFlow.need(screen if screen != null else self, sm, maxi(1, deficit), top_cb, V10ShopHub.go_free_cb(self))
	else:
		toast("Не хватает кристаллов", "gem")


func maybe_offer() -> void :
	if "--v8_offer=1" in OS.get_cmdline_user_args():
		V8Starter.maybe_show(self)
		return
	var sm: = V10ShopHub.model()
	if sm == null or not sm.cash_visible():
		return
	var cur: Dictionary = sm.ladder().get("current", {})
	if cur.is_empty():
		return
	var now_u: = V10Meta.now_unix()
	var day_i: int = sm.econ.clock.today()
	var octx: = {
		"now": now_u,
		"install": int(sm.econ.shop.st.get("install", now_u)),
		"level": sm.level(),
		"result": "win",
		"first_ssr_session": bool(G.has_meta("first_ssr_session") and G.get_meta("first_ssr_session")),
		"first_ssr_t": int(G.S.get("first_pick_t", 0)),
		"day": day_i,
	}
	if V10Offers.can_popup(G.S.v10_shop, octx).get("ok", false):
		V10Offers.mark_shown(G.S.v10_shop, day_i)
		G.save()
		V10ShopFlow.confirm(screen if screen != null else self, sm, String(cur.id))

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
	if a.has("skin"):
		V10Look.dev_reveal[String(a.skin)] = true
	if a.has("outfit"):
		var it: Dictionary = G.ITEM[a.outfit]
		G.S.owned[a.outfit] = true
		G.S.outfit[it.hero] = a.outfit
		G.S.partner = it.hero
	if a.has("fuzz"):
		V7Fuzz.run(self, int(a.fuzz))
		return
	if a.get("contract_selftest", "") == "1":
		await get_tree().process_frame
		get_tree().quit(1 if V10ContractSelftest.run() > 0 else 0)
		return
	if a.has("v10_selftest"):
		# 0.10: every module selftest as a child process (scripts/v10/core/registry_runner.gd)
		V10RegistryRunner.start(self, a)
		return
	if a.get("hud2_selftest", "") == "1":
		get_tree().quit(await V10Hud2Selftest.run(self))
		return
	if a.has("layout_shots") or a.has("layout_selftest"):
		# 0.10 M0 layout runner: every screen at this resolution (scripts/v10/responsive/README.md)
		V10LayoutShots.start(self, a)
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
	for li in mini(48, G.LEVELS.size()):
		for rep in 5:
			var cfg: Dictionary = TWLevels.at(li).duplicate(true)
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
	topbar.position = Vector2(0, safe_top)
	add_child(topbar)
	prof_root = Control.new()
	prof_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	topbar.add_child(prof_root)
	_build_profile_chip()
	var gp: = _currency(Rect2(W - 344, 32, 160, 54), "gem", V10Money.bal("gems"))
	gems_lbl = gp
	var cp: = _currency(Rect2(W - 176, 32, 160, 54), "coin", V10Money.bal("coins"))
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
			V9Feel.press(ring)
			if screen_id != "profile":
				go("profile", {"from": screen_id if screen_id != "" else "home"}))
	prof_root.add_child(hit)

# Round heroine portrait without a frame (collection.gd heroine row). The player's own avatar uses V8Art.avatar.
func _avatar(hero: String, r: Rect2) -> TextureRect:
	var hp: = V10W1Core.hero_png(hero)
	if not ResourceLoader.exists(hp):
		hp = "res://assets/hero/mc.png"
	var t: = UI.tex(load(hp), r, false)
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
	if is_inside_tree():
		get_tree().call_group("v10_money", "refresh_money")  # 0.10: the header S-plates (V8Header.show_money)
	gems_lbl.text = UI.fmt(V10Money.bal("gems"))
	_refresh_profile_chip()
	coins_lbl.text = UI.fmt(V10Money.bal("coins"))
	_fit_currency(gems_lbl)
	_fit_currency(coins_lbl)
	if punch:
		UI.punch(gems_lbl, 0.25)

func gem_target() -> Vector2:
	return Vector2(W - 320, 58 + safe_top)

func is_audio_on() -> bool:
	return not AudioServer.is_bus_mute(0) and (bool(G.S.get("sound", true)) or bool(G.S.get("music", true)) or bool(G.S.get("voice", true)))


func toggle_master_mute() -> bool:
	var on: = not is_audio_on()
	G.S.sound = on
	G.S.music = on
	G.S.voice = on
	AudioServer.set_bus_mute(0, not on)
	G.save()
	if on:
		Sfx.cur_music = ""
		if V10Registry.wired("audio"):
			V10Music.play_screen(screen_id)
		else:
			Sfx.music("play" if screen_id == "play" else "menu")
	else:
		Sfx.music("")
		if V10Registry.wired("audio"):
			V10Music.stop(0.15)
	return on


const NAV_ART: = {"home": "home", "collection": "wardrobe", "tables": "play", "summon": "wishes", "shop": "shop"}

func _build_navbar() -> void :
	navbar = Control.new()
	navbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	navbar.position = Vector2(0, H - 132 - safe_bottom)
	navbar.size = Vector2(W, 132 + safe_bottom + 120.0)
	add_child(navbar)
	navbar.add_child(V10Nav.band(Vector2(W, 132 + safe_bottom + 120.0)))
	var tabs_w: = minf(W, 720.0)
	var tw: = tabs_w / TABS.size()
	var tx0: = (W - tabs_w) * 0.5
	for i in TABS.size():
		var tab: Dictionary = TABS[i]
		var is_center: bool = (tab.id == "tables")
		var c: = Control.new()
		c.position = Vector2(tx0 + i * tw, 0)
		c.size = Vector2(tw, 132)
		c.mouse_filter = Control.MOUSE_FILTER_STOP
		c.pivot_offset = Vector2(tw * 0.5, 66)
		# Active golden aura behind icon
		var aura: = Panel.new()
		aura.name = "Aura"
		var asb: = StyleBoxFlat.new()
		asb.bg_color = Color(0.95, 0.72, 0.32, 0.24)
		asb.border_color = Color(0.98, 0.84, 0.52, 0.72)
		asb.set_border_width_all(2)
		asb.set_corner_radius_all(34 if is_center else 22)
		aura.add_theme_stylebox_override("panel", asb)
		aura.position = Vector2(tw * 0.5 - 38, -14) if is_center else Vector2(tw * 0.5 - 40, 12)
		aura.size = Vector2(76, 76) if is_center else Vector2(80, 68)
		aura.mouse_filter = Control.MOUSE_FILTER_IGNORE
		aura.visible = false
		c.add_child(aura)
		# Center elevated medallion plate for "Столы"
		if is_center:
			var med: = Panel.new()
			med.name = "Medallion"
			var msb: = StyleBoxFlat.new()
			msb.bg_color = Color(0.32, 0.11, 0.22, 0.98)
			msb.border_color = Color(0.96, 0.80, 0.45, 0.95)
			msb.set_border_width_all(3)
			msb.set_corner_radius_all(38)
			msb.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
			msb.shadow_size = 8
			med.add_theme_stylebox_override("panel", msb)
			med.position = Vector2(tw * 0.5 - 38, -14)
			med.size = Vector2(76, 76)
			med.mouse_filter = Control.MOUSE_FILTER_IGNORE
			c.add_child(med)
		var ic_sz: = 56.0 if is_center else 54.0
		var ic_y: = -4.0 if is_center else 16.0
		var ic_tex: = V8Art.nav(String(NAV_ART.get(tab.id, "home")))
		var ic: = V8Art.rect(ic_tex, Rect2(tw * 0.5 - ic_sz * 0.5, ic_y, ic_sz, ic_sz))
		ic.name = "IC"
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.add_child(ic)
		var lck: = V8Art.rect(V8Art.icon("lock"), Rect2(tw * 0.5 + 10, 44, 24, 24))
		lck.name = "Lock"
		lck.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lck.visible = false
		c.add_child(lck)
		var l: = UI.label(tab.name, 20, Color("f6e7d2"), Color(0.08, 0.03, 0.12, 0.95), 4, "body", 900)
		l.name = "L"
		l.position = Vector2(0, 76)
		l.size = Vector2(tw, 30)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.add_child(l)
		var bar: = ColorRect.new()
		bar.name = "Bar"
		bar.color = Color("f6d483")
		bar.position = Vector2(tw * 0.5 - 22, 110)
		bar.size = Vector2(44, 4)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.visible = false
		c.add_child(bar)
		c.set_meta("ux_role", "nav")
		var tut_map: = {"home": "nav.teahouse", "collection": "nav.heroines", "tables": "nav.tables", "summon": "nav.wishes", "shop": "nav.shop"}
		if tut_map.has(tab.id):
			c.set_meta("tut_id", tut_map[tab.id])
		c.gui_input.connect( func(e):
			if (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and e.pressed):
				c.accept_event()
				if not V10Nav.tab_open(tab.id):
					V9Feel.deny(c)
					toast(V10Nav.tab_lock_text(tab.id), "lock")
					return
				V9Feel.press(c, "tap")
				go(tab.id))
		navbar.add_child(c)
		tab_nodes[tab.id] = c
	refresh_nav()


func refresh_nav() -> void :
	for k in tab_nodes:
		var c: Control = tab_nodes[k]
		for n in c.get_children():
			if n.has_meta("navmark"):
				c.remove_child(n)
				n.queue_free()
		var open: = V10Nav.tab_open(k)
		var on: bool = k == screen_id or (k == "tables" and (screen_id in ["levels", "modes", "v10path", "pagoda", "journey", "duels", "challenge", "hand", "v7tourney"] or screen_id.begins_with("mj_")))
		var is_center: bool = (k == "tables")
		var ic: Control = c.get_node("IC")
		ic.modulate = Color.WHITE if on else (Color(0.90, 0.86, 0.94, 0.92) if open else Color(0.45, 0.42, 0.48, 0.55))
		ic.position.y = (-7.0 if on else -4.0) if is_center else (12.0 if on else 16.0)
		var aura: Control = c.get_node_or_null("Aura")
		if aura:
			aura.visible = on
		var lck: Control = c.get_node_or_null("Lock")
		if lck:
			lck.visible = not open
		var bar: Control = c.get_node_or_null("Bar")
		if bar:
			bar.visible = on
		var l: Label = c.get_node("L")
		l.visible = true
		if l.label_settings:
			l.label_settings = l.label_settings.duplicate()
			l.label_settings.font_color = Color("ffe6a3") if on else (Color("e8d9c8") if open else Color(0.58, 0.54, 0.62, 0.65))
		if open and not on and V10Nav.tab_dot(k):
			var d: = V10Nav.dot()
			d.position = Vector2(c.size.x * 0.5 + 22, 14)
			d.set_meta("navmark", true)
			c.add_child(d)

func _select_tab(_id: String) -> void :
	refresh_nav()

func show_chrome(_top: bool, nav: bool) -> void :
	# 0.10 W1 (HUD_V2 §8.6, UX §3.3): no status ribbon anywhere — the home screen has its own avatar + nick,
	# currency is an S-plate in the header only where it is spent (Желания, Лавка)
	topbar.visible = false
	navbar.visible = nav


func go(id: String, args: = {}, animate: = true, remember: = true) -> void :
	if busy or (id == screen_id and args.is_empty()):
		return
	if id == "summon" and not G.summon_open():
		V9Feel.deny(tab_nodes.get("summon"))
		toast(V10Nav.tab_lock_text("summon"), "lock")
		return
	var from_id: = screen_id
	var from_args: Dictionary = screen.get_meta("v8_args", {}) if screen and is_instance_valid(screen) else {}
	await V6Story.before_go(self, id, args)
	for p in overlay.get_children():
		if p.has_meta("v8_toast"):
			continue
		if p.has_meta("popup") or p.has_meta("v8_back") or p.has_meta("v10_sheet") or p is V10FirstPickView or p is V10PullConfirm or p is V10OddsScreen or p is V10SparkSheet or p is V10AskSheet or p is V10GuestScene or (p is Control and (p as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE):
			if p is Control:
				(p as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
			overlay.remove_child(p)
			p.queue_free()
	busy = true
	if id == "home":
		history.clear()
	elif remember and from_id != "" and from_id != id and not from_id in NO_HISTORY:
		history.append([from_id, from_args])
		if history.size() > 12:
			history.pop_front()
	var use_juice_trans: = animate and V10Registry.wired("juice")
	if animate:
		if use_juice_trans:
			var center: Vector2 = (tab_nodes[id] as Control).get_global_rect().get_center() if tab_nodes.has(id) else Vector2(-1, -1)
			await V10Juice.cover("auto", 0.34, center, id)
		else:
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
	var match_z: = PLAY_BACK.has(id) or id in ["tower_play", "duel2", "challenge_play"]
	overlay.z_index = 400 if match_z else 0
	trans.z_index = 450 if match_z else 0
	screen = Control.new()
	screen.set_script(SCREENS[id])
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.position = CR.position
	screen.size = CR.size
	screen.set_meta("v8_args", args.duplicate())
	screen_root.add_child(screen)
	if id in ["pagoda", "journey", "tower_play", "duels", "duel2", "challenge", "challenge_play", "hand", "adventure"] or id.begins_with("mj_"):
		show_chrome(false, false)
	if screen.has_method("build"):
		screen.call("build", self, args)
	elif screen.has_method("setup"):
		screen.call("setup", self, args)
	if id == "mj_classic_lobby":
		if screen.has_signal("play"):
			screen.play.connect(func(a: Dictionary) -> void:
				var target: = "mj_memory" if String(a.get("variant", "")) == "memory" else "mj_classic"
				go(target, a))
		if screen.has_signal("back"):
			screen.back.connect(func() -> void: go("tables"))
	elif id.begins_with("mj_") and screen.has_signal("finished"):
		screen.finished.connect(func(res: Dictionary) -> void: V10Hooks.handle_mode_finished(self, res))
	V10Hooks.emit_screen_shown(id, screen)  # 0.10 hook
	refresh_currency()
	refresh_nav()
	if animate:
		if use_juice_trans:
			V10Juice.reveal(0.42)
		else:
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
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		V10Hooks.emit_app_resumed()  # 0.10 hook
	elif what == NOTIFICATION_APPLICATION_PAUSED:
		V10Hooks.emit_app_paused()  # 0.10 hook
	elif what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		V10Phone.shutdown()

func _unhandled_key_input(e: InputEvent) -> void :
	if e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_ESCAPE:
		android_back()
		get_viewport().set_input_as_handled()

func toast(text: String, icon: = "") -> void :
	var w: = 560.0
	var y: = (V8Header.CONTENT_Y + 12.0 if topbar and topbar.visible else 130.0) + CR.position.y
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
		y = get_viewport_rect().size.y - safe_bottom - 74.0
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
		var nav_top: = vh - safe_bottom - (150.0 if navbar and navbar.visible else 24.0)
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
		sr.position += screen.position
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
	# 0.10 W1: «Сегодня» → «Забрать всё», then the one «Играть · N» goes straight to the table
	V10Nav.claim_all(self)
	await wait(1.6)
	await press(home.home2.play_b)
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
