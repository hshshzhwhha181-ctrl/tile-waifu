extends Control



const DUEL_SCRIPT: = "res://scripts/v06/heroines/duel.gd"

var main
var W: = 720.0
var H: = 1280.0


static func build_bar(screen: Control, main, rect: Rect2) -> void :
	var items: = [
		["path", "Путь", "%d партий" % G.LEVELS.size(), 0.22], 
		["modes", "Режимы", "дуэль · лестница · этюды", 0.44], 
		["daily", "Раскладка дня", "готово" if G.daily_done_today() else "новая", 0.34], 
	]
	var x: = rect.position.x
	for i in items.size():
		var it: Array = items[i]
		var w: float = rect.size.x * float(it[3]) - 8
		var on: bool = it[0] == "path"
		var hot: bool = it[0] == "modes"
		var b: = UI.rbox("gold" if on else "plum", Rect2(x, rect.position.y, w, rect.size.y), 22, 3, 8)
		if not on:
			b.borders(Color("ffe7a6"), Color("c58a2c"))
		if hot:
			b.colors(Color(0.42, 0.18, 0.36, 0.95), Color(0.24, 0.08, 0.22, 0.96))
		b.mouse_filter = Control.MOUSE_FILTER_STOP
		b.pivot_offset = b.size * 0.5
		screen.add_child(b)
		b.add_child(UI.center_label(UI.label(it[1], 22, Color.WHITE if not on else Color("4a2a06"), UI.DARK if not on else Color(1, 1, 1, 0.6), 3, "body", 900), Rect2(0, 6, w, 32)))
		b.add_child(UI.center_label(UI.label(it[2], 15, Color("e9dcff") if not on else Color("6a4a16")), Rect2(0, 38, w, 26)))
		if hot:
			b.shine(0.6)
			if not "hub" in V6ModesData.st().seen:
				var nb: = UI.rbox("red", Rect2(w - 66, -12, 72, 26), 13, 2, 4)
				b.add_child(nb)
				nb.add_child(UI.center_label(UI.label("НОВОЕ", 13, Color.WHITE, Color("6a1020"), 2, "body", 900), Rect2(0, 0, 72, 26)))
		var id: String = it[0]
		b.gui_input.connect( func(e):
			if e is InputEventMouseButton and e.pressed:
				Sfx.play("pop")
				UI.punch(b, 0.08)
				if id == "modes":
					main.go("modes")
				elif id == "daily":
					Daily.calendar(main))
		UI.slide_in(b, Vector2(0, -30), 0.05 * i)
		x += w + 8

func build(m, args: Dictionary) -> void :
	main = m
	W = size.x
	H = size.y
	main.show_chrome(true, true)
	Sfx.music("menu")
	var s: = V6ModesData.st()
	if not "hub" in s.seen:
		s.seen.append("hub")
		G.save()
	Common.backdrop(self, "menu", size, 2.4, 0.7)
	Common.vignette(self, size, Color(0.2, 0.06, 0.18), 0.55)
	var hd: = UI.title("Режимы", 46, Color("ffe7a6"), Color("5a1a6a"))
	hd.position = Vector2(24, 122)
	hd.size = Vector2(300, 60)
	add_child(hd)
	var sub: = UI.label("Каждый стол со своей целью и наградой", 18, Color("e9dcff"))
	sub.position = Vector2(26, 178)
	add_child(sub)
	var back: = JButton.make("К карте", "glass", Rect2(W - 196, 128, 176, 64), null, 22)
	back.pressed.connect( func(): main.go("levels"))
	add_child(back)

	var dh: = clampf((H - 150.0 - 214.0) * 0.24, 206.0, 280.0)
	_duel_card(Rect2(20, 214, W - 40, dh))
	var cw: = (W - 40 - 14) * 0.5
	var y0: = 214.0 + dh + 14.0
	var ch: = clampf((H - 150.0 - y0 - 28.0) / 3.0, 200.0, 320.0)
	var cards: = [
		["climb", "Лунная лестница", "Этаж за этажом, три фонаря. После этажа героиня дарит благословение.", "bg_palace", "Рекорд: этаж %d" % int(s.climb_best), true], 
		["etude", "Этюды", "30 задач Маджонг-тян. Все пары разные, лоток на три места.", "bg_shrine", "★ %d / %d" % [V6ModesData.etude_total(), V6ModesData.ETUDES * 3], true], 
		["shift", "Смена в чайной", "Героини заказывают пары своей категории. Чаевые = кристаллы.", "bg_teahouse", "Рекорд чаевых: %d" % int(s.shift_best), true], 
		["blitz", "Блиц", "Две минуты, столы сменяют друг друга, очки растут с комбо.", "bg_festival", "Рекорд: %d" % int(G.S.get("blitz_best", 0)), false], 
		["zen", "Сад", "Бесконечные столы, шесть мест в лотке и никакого проигрыша.", "play", "+30 за стол", false], 
		["daily", "Раскладка дня", "Одна раскладка на всех. Звезда в календаре.", "bg_street", "Сегодня: готово" if G.daily_done_today() else "Сегодня: новая", false], 
	]
	for i in cards.size():
		var c: Array = cards[i]
		var r: = Rect2(20 + (i % 2) * (cw + 14), y0 + (i / 2) * (ch + 14), cw, ch)
		var card: = _card(r, c[0], c[1], c[2], c[3], c[4], c[5])
		UI.slide_in(card, Vector2(0, 40), 0.06 * i + 0.1, 0.4)
	var open: String = args.get("open", args.get("mode", ""))
	if open != "":
		await get_tree().create_timer(0.35).timeout
		if is_inside_tree():
			_open(open)

func _art(parent: Control, bg: String, r: Rect2, focus: = Vector2(0.5, 0.5)) -> void :
	var path: = "res://assets/bg/%s.webp" % bg
	if not ResourceLoader.exists(path):
		path = "res://assets/bg/menu.webp"
	var art: = Common.card_art(load(path), Rect2(Vector2(4, 4), r.size - Vector2(8, 8)), focus, 1.0, 24)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(art)
	var shade: = TextureRect.new()
	var g: = GradientTexture2D.new()
	g.gradient = Gradient.new()
	g.gradient.set_color(0, Color(0.08, 0.03, 0.12, 0.15))
	g.gradient.set_color(1, Color(0.08, 0.03, 0.12, 0.92))
	g.fill_from = Vector2(0, 0)
	g.fill_to = Vector2(0, 1)
	shade.texture = g
	shade.position = Vector2(4, 4)
	shade.size = r.size - Vector2(8, 8)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(shade)

func _frame(r: Rect2) -> RBox:
	var card: = UI.rbox("plum", r, 28, 4, 10)
	card.colors(Color(0.12, 0.06, 0.16, 1.0), Color(0.08, 0.04, 0.1, 1.0)).borders(Color("ffe7a6"), Color("c58a2c"))
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.pivot_offset = r.size * 0.5
	add_child(card)
	return card

func _card(r: Rect2, id: String, title: String, desc: String, bg: String, status: String, fresh: bool) -> Control:
	var card: = _frame(r)
	_art(card, bg, r, Vector2(0.5, 0.45))
	var t: = UI.title(title, 30, Color.WHITE, Color("5a1a6a"))
	t.position = Vector2(18, r.size.y - 154)
	t.size = Vector2(r.size.x - 30, 44)
	card.add_child(t)
	var d: = UI.label(desc, 15, Color("f1e6ff"), UI.DARK, 3)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.position = Vector2(20, r.size.y - 108)
	d.size = Vector2(r.size.x - 36, 56)
	d.custom_minimum_size = Vector2(r.size.x - 36, 0)
	card.add_child(d)
	Common.chip(card, null, status, Rect2(14, r.size.y - 44, r.size.x - 28, 34), "plum", 16)
	if fresh:
		var nb: = UI.rbox("red", Rect2(r.size.x - 86, 12, 74, 26), 13, 2, 4)
		card.add_child(nb)
		nb.add_child(UI.center_label(UI.label("НОВОЕ", 13, Color.WHITE, Color("6a1020"), 2, "body", 900), Rect2(0, 0, 74, 26)))
	card.gui_input.connect( func(e):
		if e is InputEventMouseButton and e.pressed:
			Sfx.play("pop")
			UI.punch(card, 0.06)
			_open(id))
	return card

func _duel_card(r: Rect2) -> void :
	var card: = _frame(r)
	_art(card, "bg_neon", r, Vector2(0.5, 0.4))
	var t: = UI.title("Дуэль", 40, Color("ffe7a6"), Color("5a1a6a"))
	t.position = Vector2(22, 20)
	t.size = Vector2(300, 56)
	card.add_child(t)
	var d: = UI.label("Героиня садится напротив и берёт пары с того же стола. Кто соберёт больше, тот и выиграл.", 16, Color("f1e6ff"), UI.DARK, 3)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.position = Vector2(24, 78)
	d.size = Vector2(320, 80)
	d.custom_minimum_size = Vector2(320, 0)
	card.add_child(d)
	var ready: = ResourceLoader.exists(DUEL_SCRIPT)
	Common.chip(card, null, "Выбрать соперницу" if ready else "Скоро", Rect2(20, r.size.y - 48, 300, 36), "pink" if ready else "plum", 17)
	var x: = r.size.x - 20.0
	var order: Array = G.HERO_ORDER.duplicate()
	order.reverse()
	for i in order.size():
		var h: String = order[i]
		x -= 58
		var av: = Common.avatar(h, Rect2(x - 12, r.size.y * 0.5 - 70 + (i % 2) * 60, 76, 76), "gold" if G.hero_unlocked(h) else "plum")
		card.add_child(av)
	card.gui_input.connect( func(e):
		if e is InputEventMouseButton and e.pressed:
			Sfx.play("pop")
			UI.punch(card, 0.05)
			_open("duel"))


func _open(id: String) -> void :
	match id:
		"duel":
			_duel_pick()
		"climb":
			var s: = V6ModesData.st()
			var next: = ""
			for m in V6ModesData.CLIMB_MILES:
				if not int(m[0]) in s.climb_miles.map( func(x): return int(x)):
					next = "Ближайшая веха: этаж %d · +%d кристаллов" % [int(m[0]), int(m[1])]
					break
			_info("Лунная лестница", "Этажи растут: больше слоёв, золото, лёд и тайные фишки. Переполненный лоток гасит один из трёх фонарей, но этаж продолжается. После каждого этажа выбери благословение одной из героинь. Если героиня уже твоя, её дар сильнее. Каждый пятый этаж охраняет страж с сундуком.", 
				"Рекорд: этаж %d · %s" % [int(s.climb_best), next if next != "" else "все вехи взяты"], "Начать восхождение", 
				func(): main.go("arena", {"mode": "climb", "partner": G.S.level_partner}))
		"etude":
			_etude_pick()
		"shift":
			_info("Смена в чайной", "Три стола подряд. За стойкой три гостьи, у каждой заказ: две пары сладостей, пара зверей… Собери пару нужной категории, и чай уйдёт к ней. Чем быстрее, тем больше чаевые. Твои героини платят в полтора раза щедрее.", 
				"Рекорд чаевых: %d · обслужено всего: %d" % [int(V6ModesData.st().shift_best), int(V6ModesData.st().shift_served)], "Открыть смену", 
				func(): main.go("arena", {"mode": "shift", "partner": G.S.level_partner}))
		"blitz":
			_info("Блиц", "Две минуты, столы сменяют друг друга. Чистый стол даёт +10 секунд, переполненный лоток отнимает 10. Очки растут с комбо.", 
				"Рекорд: %d" % int(G.S.get("blitz_best", 0)), "Начать", func(): main.go("play", {"mode": "blitz", "partner": G.S.level_partner}))
		"zen":
			_info("Сад без спешки", "Бесконечные столы, шесть мест в лотке и никакого проигрыша: если лоток заполнится, три фишки тихо вернутся. +30 кристаллов за каждый стол.", 
				"Для вечера после работы", "Начать", func(): main.go("play", {"mode": "zen", "partner": G.S.level_partner}))
		"daily":
			Daily.calendar(main)

func _info(title: String, text: String, sub: String, go_text: String, go_cb: Callable) -> void :
	var p: = Common.popup(main, title, 500)
	var l: = UI.label(text, 20, UI.INK)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.position = Vector2(40, 62)
	l.size = Vector2(580, 230)
	l.custom_minimum_size = Vector2(580, 0)
	p.add_child(l)
	var sl: = UI.label(sub, 18, Color("ffd98a"), UI.DARK, 3, "body", 900)
	sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sl.position = Vector2(40, 300)
	sl.size = Vector2(580, 60)
	sl.custom_minimum_size = Vector2(580, 0)
	p.add_child(sl)
	var b: = JButton.make(go_text, "pink", Rect2(110, 372, 440, 96), null, 30)
	b.shine_every = 2.0
	b.pressed.connect(go_cb)
	p.add_child(b)

func _duel_pick() -> void :
	if not ResourceLoader.exists(DUEL_SCRIPT):
		main.toast("Дуэль появится в этом обновлении", "star")
		return
	var hs: Dictionary = G.S.get("v6_heroines", {})
	var wins: Dictionary = hs.get("duel_wins", {})
	var p: = Common.popup(main, "Выбери соперницу", 760)
	var y: = 60.0
	for h in G.HERO_ORDER:
		var row: = UI.rbox("glass", Rect2(30, y, 600, 124), 26, 3, 8)
		row.borders(Color("ffe7a6"), Color("c58a2c"))
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		row.pivot_offset = row.size * 0.5
		p.add_child(row)
		var own: = G.hero_unlocked(h)
		row.add_child(Common.avatar(h, Rect2(12, 10, 104, 104), "gold" if own else "plum"))
		var nm: = UI.label(G.HEROES[h].name, 26, Color.WHITE, UI.DARK, 3, "title", 800)
		nm.position = Vector2(132, 14)
		row.add_child(nm)
		var tl: = UI.label(G.HEROES[h].title, 17, Color("e9dcff"))
		tl.position = Vector2(134, 52)
		row.add_child(tl)
		var wl: = UI.label("Побед: %d" % int(wins.get(h, 0)) + ("" if own else " · победа = осколок"), 17, Color("ffd98a"), UI.DARK, 2, "body", 900)
		wl.position = Vector2(134, 80)
		row.add_child(wl)
		row.add_child(UI.center_label(UI.label("›", 54, Color("ffe7a6")), Rect2(530, 20, 60, 80)))
		row.gui_input.connect( func(e):
			if e is InputEventMouseButton and e.pressed:
				Sfx.play("pop")
				UI.punch(row, 0.06)
				main.go("play", {"mode": "duel", "rival": h, "partner": G.S.level_partner}))
		y += 136

func _etude_pick() -> void :
	var p: = Common.popup(main, "Этюды Маджонг-тян", 900)
	var intro: = UI.label("Все пары разные, лоток на три места. Отмена бесплатна, без отмен будет ★★★.", 18, UI.INK)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.position = Vector2(36, 50)
	intro.size = Vector2(590, 50)
	intro.custom_minimum_size = Vector2(590, 0)
	p.add_child(intro)
	var y: = 110.0
	var bw: = 108.0
	var bh: = 104.0
	for ch in 3:
		var hl: = UI.label("%s · этюды %d–%d" % [V6ModesData.ETUDE_CHAPTERS[ch], ch * 10 + 1, ch * 10 + 10], 19, Color("ffd98a"), UI.DARK, 3, "body", 900)
		hl.position = Vector2(36, y)
		p.add_child(hl)
		y += 32
		for k in 10:
			var i: = ch * 10 + k
			var r: = Rect2(36 + (k % 5) * (bw + 9), y + (k / 5) * (bh + 8), bw, bh)
			_etude_btn(p, i, r)
		y += 2 * (bh + 8) + 14

func _etude_btn(p: Control, i: int, r: Rect2) -> void :
	var open: = V6ModesData.etude_open(i)
	var stars: = V6ModesData.etude_stars(i)
	var b: = UI.rbox("gold" if stars == 3 else ("glass" if open else "plum"), r, 20, 3, 6)
	if stars < 3:
		b.borders(Color("ffe7a6") if open else Color(1, 1, 1, 0.15), Color("c58a2c") if open else Color(0, 0, 0, 0.3))
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.pivot_offset = r.size * 0.5
	p.add_child(b)
	if not open:
		b.modulate = Color(0.7, 0.65, 0.75, 0.8)
		b.add_child(UI.tex(G.fx("lock"), Rect2(r.size.x * 0.5 - 22, 18, 44, 44)))
	else:
		b.add_child(UI.center_label(UI.title(str(i + 1), 36, Color.WHITE if stars < 3 else Color("fff6d8"), Color("5a1a6a") if stars < 3 else Color("9a5a0a")), Rect2(0, 6, r.size.x, 56)))
	for k in 3:
		var st: = UI.tex(G.fx("star" if k < stars else "star_empty"), Rect2(r.size.x * 0.5 - 45 + k * 30, 66, 30, 30))
		b.add_child(st)
	b.gui_input.connect( func(e):
		if e is InputEventMouseButton and e.pressed:
			if not open:
				Sfx.play("deny")
				main.toast("Сначала реши этюд %d" % i, "star")
				return
			Sfx.play("pop")
			UI.punch(b, 0.1)
			main.go("arena", {"mode": "etude", "etude": i, "partner": G.S.level_partner}))
