extends Node

# Gallery of the rituals UI for the standalone runner: every component in its key states, as screenshots or as an
# interactive menu. State lives in a private bound save and a pinned clock; rewards go to a no-op sink.

var root: Control
var W: = 720.0
var H: = 1280.0
const SCENES: = ["home_tray", "chips", "forgiven", "sheet", "sheet_cold", "comeback_warm", "comeback_waited",
	"comeback_winds", "ladder", "bday_cake", "sig_tiles", "pbday_ask", "pbday_consent", "pbday_answer", "pbday_scene",
	"week_letter", "rested"]


func _setup_state() -> void:
	V10RitSave.bind({})
	V10RitClock.use_meta = false
	V10RitClock.set_now(int(Time.get_unix_time_from_datetime_string("2026-11-30T12:00:00")) - V10RitClock.tz_bias_sec())
	V10RitBridge.set_sink(func(_r, _s): pass)
	V10Bday.heroes_override = []
	V10Tray.clear()


func _make_root() -> void:
	var cl: = CanvasLayer.new()
	add_child(cl)
	root = Control.new()
	var vs: = get_viewport().get_visible_rect().size
	W = vs.x
	H = vs.y
	root.size = vs
	cl.add_child(root)


func _clear() -> void:
	for c in root.get_children():
		c.queue_free()
	await get_tree().process_frame


func _shot(dir: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: = get_viewport().get_texture().get_image()
	var p: = dir.path_join("rit_%s.png" % name)
	img.save_png(p)
	print("RIT_SHOT ", p)


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func shots(dir: String, only: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	_setup_state()
	_make_root()
	await get_tree().process_frame
	for sc in SCENES:
		if only != "" and only != sc:
			continue
		await _clear()
		await _run(sc, dir)
	print("RIT_SHOTS done")


func demo(which: String) -> void:
	_setup_state()
	_make_root()
	if which != "":
		_run(which, "")
		return
	_menu()


func _menu() -> void:
	for c in root.get_children():
		c.queue_free()
	root.add_child(V10RitUI.panel(Rect2(0, 0, W, H), V10RitUI.NIGHT900, 0))
	var h1: = V10RitUI.label("Ритуалы · галерея", 44, V10RitUI.PAPER100, "title", 700)
	h1.position = Vector2(32, 40)
	root.add_child(h1)
	for i in SCENES.size():
		var sc: String = SCENES[i]
		var b: = V10RitUI.button(sc, Rect2(32 + (i % 2) * 336, 120 + (i / 2) * 92, 320, 80), "secondary", func():
			for c in root.get_children():
				c.queue_free()
			_setup_state()
			_run(sc, "")
			var back: = V10RitUI.button("‹", Rect2(8, 8, 64, 64), "quiet", _menu)
			root.add_child(back))
		root.add_child(b)


func _home_bg() -> void:
	var bg: = TextureRect.new()
	bg.texture = load("res://assets/bg/bg_teahouse.webp")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.size = Vector2(W, H)
	bg.modulate = Color(0.62, 0.58, 0.6)
	root.add_child(bg)
	var p: = TextureRect.new()
	p.texture = V10RitBridge.portrait("mc")
	p.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	p.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	p.size = Vector2(1000 * 848.0 / 1264.0, 1000)
	p.position = Vector2(W - p.size.x + 90, H - 1000 - 170)
	root.add_child(p)
	root.add_child(V10RitUI.grad(Rect2(0, H * 0.7, W, H * 0.3), Color(V10RitUI.NIGHT900, 0), Color(V10RitUI.NIGHT900, 0.9)))
	var spine: = V10RitUI.label("ЧАЙНАЯ · ВЕЧЕР", 15, Color(V10RitUI.PAPER100, 0.4), "over")
	spine.rotation = deg_to_rad(-90)
	spine.position = Vector2(10, 420)
	root.add_child(spine)


func _counters() -> Dictionary:
	var out: = {}
	var x: = W - 300.0
	for k in ["gems", "tickets"]:
		var c: = V10RitUI.panel(Rect2(x, 24, 130, 52), Color(V10RitUI.NIGHT800, 0.85), 26, Color(V10RitUI.GOLD700, 0.4), 1)
		root.add_child(c)
		c.add_child(V10RitUI.tex(str(V10RitBridge.ICONS[k]), Rect2(6, 4, 44, 44)))
		var l: = V10RitUI.label("1 240" if k == "gems" else "3", 22, V10RitUI.GOLD300, "num")
		l.position = Vector2(56, 10)
		c.add_child(l)
		out[k] = c
		x += 146
	return out


func _run(sc: String, dir: String) -> void:
	var shoot: = dir != ""
	match sc:
		"home_tray":
			_home_bg()
			var ctr: = _counters()
			var chip: = V10StreakChip.new()
			chip.position = Vector2(24, 112)
			root.add_child(chip)
			var s: = V10Streak.st()
			s.n = 12
			s.best = 23
			s.leaves = 2
			s.gift = true
			s.hist[V10RitClock.day_key()] = "win"
			chip.setup(V10Streak.view())
			var cards: = [
				{"id": "seven", "icon": "res://assets/icons/ticket.png", "title": "Семь встреч", "text": "День 3", "rewards": {"tickets": 1}},
				{"id": "streak_leaf", "icon": V10RitUI.ART + "leaf.webp", "title": "Чайный лист", "text": "Листьев: 2 из 2", "rewards": {}},
				{"id": "card", "icon": "res://assets/icons/gem.png", "title": "Абонемент", "text": "+30 кристаллов", "rewards": {"gems": 30}},
			]
			var tv: = V10TrayView.open(root, cards, {"default": ctr.gems.global_position + Vector2(30, 26), "gems": ctr.gems, "tickets": ctr.tickets})
			tv.claim_fn = func():
				var res: = []
				for c in cards:
					res.append({"card": c, "rows": V10RitBridge.rows(c.rewards)})
				return res
			if shoot:
				await _wait(1.3)
				await _shot(dir, "home_tray")
				tv._claim()
				await _wait(0.75)
				await _shot(dir, "home_tray_claim")
				await _wait(1.0)
				await _shot(dir, "home_tray_fly")
		"chips":
			root.add_child(V10RitUI.panel(Rect2(0, 0, W, H), V10RitUI.NIGHT800, 0))
			var states: = [{"n": 12, "leaves": 2, "state": "warm"}, {"n": 5, "leaves": 1, "state": "waiting"},
				{"n": 9, "leaves": 0, "state": "cold"}, {"n": 0, "leaves": 1, "state": "empty"}]
			var names: = ["Тёплая", "Ждёт победы", "Остыла", "Пусто"]
			for i in states.size():
				var ch: = V10StreakChip.new()
				ch.position = Vector2(30 + (i % 2) * 340, 200 + (i / 2) * 420)
				root.add_child(ch)
				ch.setup(states[i])
				var l: = V10RitUI.label(names[i], 22, V10RitUI.PAPER300)
				l.position = ch.position + Vector2(170, 70)
				root.add_child(l)
			if shoot:
				await _wait(1.6)
				await _shot(dir, "chips")
		"forgiven":
			_home_bg()
			var ch2: = V10StreakChip.new()
			ch2.position = Vector2(24, 300)
			root.add_child(ch2)
			ch2.setup({"n": 12, "leaves": 1, "state": "waiting"})
			ch2.play_forgiven(0)
			if shoot:
				await _wait(0.6)
				await _shot(dir, "forgiven_mid")
			await _wait(0.7)
			V10RitUI.voice(root, V10RitLines.pick("forgiven", "mc", 0), Vector2(32, 520), 400, 38, 3.0)
			if shoot:
				await _wait(1.2)
				await _shot(dir, "forgiven_line")
		"sheet", "sheet_cold":
			_home_bg()
			var s2: = V10Streak.st()
			var today: = V10RitClock.day_key()
			s2.n = 12
			s2.best = 23
			s2.leaves = 1
			s2.got = [3, 7]
			for i in 30:
				var k: = V10RitClock.add_days(today, -i - (0 if sc == "sheet" else 1))
				s2.hist[k] = "win"
			s2.hist[V10RitClock.add_days(today, -9)] = "leaf"
			s2.hist[V10RitClock.add_days(today, -16)] = "warm"
			if sc == "sheet_cold":
				s2.hist[V10RitClock.add_days(today, -1)] = "miss"
				s2.repair = {"need": 2, "got": 1, "day": V10RitClock.add_days(today, -1), "until": V10RitClock.add_days(today, 2), "from": today, "n": 12}
				s2.leaves = 0
			V10StreakSheet.open(root)
			if shoot:
				await _wait(1.1)
				await _shot(dir, sc)
		"comeback_warm", "comeback_waited", "comeback_winds":
			var tier: = sc.substr(9)
			var news: = [{"title": "Новая героиня: Злата", "text": "Её фишки и свой стол уже в Желаниях.", "icon": "res://assets/icons/gift.png"},
				{"title": "Пагода", "text": "Сто этажей испытаний с наградами за вершины.", "icon": "res://assets/icons/trophy.png"},
				{"title": "Серия чая", "text": "Пропуск дня прощает чайный лист.", "icon": V10RitUI.ART + "leaf.webp"}]
			V10ComebackScene.play(root, tier, {"h": "mc", "letters": 5, "news": news})
			if shoot:
				match tier:
					"warm":
						await _wait(2.6)
						await _shot(dir, sc)
					"waited":
						await _wait(1.3)
						await _shot(dir, sc + "_dark")
						await _wait(1.9)
						await _shot(dir, sc + "_turned")
						await _wait(1.9)
						await _shot(dir, sc + "_letters")
					_:
						await _wait(2.4)
						await _shot(dir, sc + "_frames")
						await _wait(6.6)
						await _shot(dir, sc + "_news")
		"ladder":
			var cb: = V10Comeback.st()
			cb.ladder = {"kind": "long", "start_key": V10RitClock.add_days(V10RitClock.day_key(), -3), "claimed": 2, "last_claim_key": ""}
			V10LadderScreen.open(root)
			if shoot:
				await _wait(0.9)
				await _shot(dir, "ladder")
		"bday_cake":
			var cake: = V10BdayCake.open(root, "mc")
			if shoot:
				await _wait(1.2)
				await _shot(dir, "bday_cake")
				cake.blow()
				await _wait(0.55)
				await _shot(dir, "bday_blow")
				await _wait(1.0)
				await _shot(dir, "bday_blown")
		"sig_tiles":
			_sig_tiles()
			if shoot:
				await _wait(0.6)
				await _shot(dir, "sig_tiles")
		"pbday_ask", "pbday_consent", "pbday_answer":
			var step: String = {"pbday_ask": "ask", "pbday_consent": "consent", "pbday_answer": "later"}[sc]
			if step == "later":
				V10PlayerBday.set_date(12, 14, true, V10RitClock.day_key())
			var scr: = V10PlayerBdayScreen.open(root, step)
			if shoot:
				await _wait(0.9)
				if step == "consent":
					scr._m_drum.set_index(2)
					scr._d_drum.set_index(13)
					await _wait(0.4)
					await _shot(dir, sc)
					scr._consent = true
					scr._tick_mark.visible = true
					(scr._tick.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = V10RitUI.GOLD500
					scr._save.disabled = false
					await _wait(0.3)
					await _shot(dir, sc + "_ticked")
				else:
					await _wait(1.2)
					await _shot(dir, sc)
		"pbday_scene":
			V10PlayerBdayScene.play(root, {"name_voc": "Аня", "rows": V10RitBridge.rows({"tickets": 3, "frame": "my_bday_2026", "aff": {"mc": 50}})})
			if shoot:
				await _wait(3.4)
				await _shot(dir, "pbday_scene")
		"week_letter":
			var c: = {"wins": 9, "max_best_combo": 14, "pairs": 380, "stars3": 4, "day_a": 1, "day_b": 1, "day_c": 1, "day_d": 1, "touches": 6, "max_run": 5, "ults": 7}
			var l: = V10WeekLetter.compose(c, "mc", 3)
			V10WeekLetterView.open(root, l)
			if shoot:
				await _wait(1.5)
				await _shot(dir, "week_letter_ink")
				await _wait(3.4)
				await _shot(dir, "week_letter")
		"rested":
			_hud_mock()
			if shoot:
				await _wait(0.8)
				await _shot(dir, "rested")


func _sig_tiles() -> void:
	root.add_child(V10RitUI.panel(Rect2(0, 0, W, H), V10RitUI.NIGHT800, 0))
	var h1: = V10RitUI.label("Праздник: подмена фишек", 15, V10RitUI.GOLD500, "over")
	h1.position = Vector2(32, 60)
	root.add_child(h1)
	var faces: = [3, 7, 12, 20, 21, 25, 3, 7, 12, 20, 21, 25]
	var ov: = V10Bday.sig_overlay({"ranked": false, "faces": faces, "seed": 5}, "2026-11-30")
	var y: = 120.0
	for hero in ["rin", "mc", "hana", "yue", "nova"]:
		var lbl: = V10RitUI.label(V10RitBridge.short_name(hero), 22, V10RitUI.PAPER300)
		lbl.position = Vector2(32, y + 34)
		root.add_child(lbl)
		for i in 6:
			var f: int = faces[i]
			var tile: = Control.new()
			tile.position = Vector2(150 + i * 92, y)
			tile.size = Vector2(84, 104)
			root.add_child(tile)
			tile.add_child(V10RitUI.panel(Rect2(0, 6, 84, 98), Color("cdbfa8"), 10))
			tile.add_child(V10RitUI.panel(Rect2(0, 0, 84, 96), Color("f6efe2"), 10, Color("d9c9ae"), 2))
			var face: = TextureRect.new()
			face.texture = G.tile_tex(f)
			face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			face.position = Vector2(8, 8)
			face.size = Vector2(68, 80)
			tile.add_child(face)
			if f in (ov.get("faces", []) as Array):
				face.modulate.a = 0.0
				V10BdaySigDecor.apply(tile, V10Bday.sig_icon(hero), Rect2(8, 8, 68, 80))
		y += 150
	var note: = V10RitUI.wrap_w(V10RitUI.label("Две масти рисуются эмблемой именинницы. Номера фишек не меняются: раздача, боты и коды вызова те же. В рейтинге подмены нет.", 20, V10RitUI.PAPER500, "body", 700), W - 64)
	note.position = Vector2(32, y + 10)
	root.add_child(note)
	var gc: = V10BdayGoalChip.make({"h": "rin", "n": 12, "goal": 24, "icon": V10Bday.sig_icon("rin")})
	gc.position = Vector2(32, y + 130)
	root.add_child(gc)


func _hud_mock() -> void:
	root.add_child(V10RitUI.panel(Rect2(0, 0, W, H), V10RitUI.NIGHT900, 0))
	var bg: = TextureRect.new()
	bg.texture = load("res://assets/bg/play_blur.webp")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.size = Vector2(W, H)
	bg.modulate = Color(0.5, 0.5, 0.5)
	root.add_child(bg)
	root.add_child(V10RitUI.panel(Rect2(0, 0, W, 132), Color(V10RitUI.NIGHT800, 0.92), 0))
	var l: = V10RitUI.label("1-4 · Осталось 30", 22, V10RitUI.PAPER100)
	l.position = Vector2(96, 30)
	root.add_child(l)
	root.add_child(V10RitUI.panel(Rect2(96, 66, 330, 10), Color(V10RitUI.ROSE500, 0.25), 5))
	root.add_child(V10RitUI.panel(Rect2(96, 66, 210, 10), V10RitUI.ROSE500, 5))
	var bar: = V10RestedBar.new()
	bar.position = Vector2(96, 84)
	root.add_child(bar)
	bar.set_value(420)
	var cap: = V10RitUI.label("Отдых: мастерство нарядов ×2", 15, V10RitUI.TEAL)
	cap.position = Vector2(96, 150)
	root.add_child(cap)
	var por: = V10RitUI.panel(Rect2(W - 150, 8, 116, 116), V10RitUI.NIGHT700, 58, V10RitUI.ROSE500, 3)
	root.add_child(por)
