extends Control

# 0.8 «Режимы»: V8Header; two big entries (Путь, Турнир недели); «Стол риичи» closed «Скоро»;
# other modes as a compact list, opened by the single rank (V6ModesData.GATES).

const DUEL_SCRIPT: = "res://scripts/v06/heroines/duel.gd"
const Y0: = V8Header.CONTENT_Y + 12.0

const LIST: = [
	["daily", "Раскладка дня", "bg_street"], 
	["blitz", "Блиц", "bg_festival"], 
	["zen", "Сад", "play"], 
	["duel", "Дуэль", "bg_neon"], 
	["etude", "Этюды", "bg_shrine"], 
	["shift", "Смена в чайной", "bg_teahouse"], 
	["climb", "Лунная лестница", "bg_palace"], 
]

var main
var W: = 720.0
var H: = 1280.0
var path_card: Control
var tour_card: Control
var mode_tiles: = {}


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
	V8Header.make(self, main, "Режимы", main.back, _help)

	var y: = Y0
	path_card = _path_card(Rect2(20, y, W - 40, 204))
	UI.slide_in(path_card, Vector2(0, 30), 0.0, 0.4)
	y += 204 + 12
	tour_card = _tour_card(Rect2(20, y, W - 40, 160))
	UI.slide_in(tour_card, Vector2(0, 30), 0.06, 0.4)
	y += 160 + 12
	var rc: = _riichi_card(Rect2(20, y, W - 40, 70))
	UI.slide_in(rc, Vector2(0, 30), 0.1, 0.4)
	y += 70 + 12
	var hl: = UI.label("Другие режимы", 20, Color("ffe7a6"), UI.DARK, 3, "body", 900)
	hl.position = Vector2(26, y)
	add_child(hl)
	var ri: = G.rank_of(int(G.S.get("rp", 0)))
	var rl: = UI.label("твой ранг: %s" % ri.title, 17, UI.MUTED, UI.DARK, 2, "body", 800)
	rl.position = Vector2(W - 346, y + 2)
	rl.size = Vector2(320, 24)
	rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(rl)
	var rw: float = UI.font("body", 800).get_string_size(rl.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
	add_child(V8Art.rect(V8Art.rank(ri.tier), Rect2(W - 26 - rw - 34, y - 2, 30, 30)))
	y += 32
	var tw: = (W - 40 - 12) * 0.5
	var th: = 80.0
	for i in LIST.size():
		var it: Array = LIST[i]
		var r: = Rect2(20 + (i % 2) * (tw + 12), y + (i / 2) * (th + 10), tw, th)
		var t: = _tile(r, it[0], it[1], it[2])
		mode_tiles[it[0]] = t
		UI.slide_in(t, Vector2(0, 30), 0.12 + 0.03 * i, 0.35)
	var open: String = args.get("open", args.get("mode", ""))
	if open != "":
		await get_tree().create_timer(0.35).timeout
		if is_inside_tree():
			_open(open)


func _help() -> void :
	var ri: = G.rank_of(int(G.S.get("rp", 0)))
	var lines: = ["Путь — карта партий с главами и боссами. Турнир недели — твоя группа из 20 игроков, очки недели дают три стола турнира, а очки ранга идут из всех режимов.", 
		"Остальные режимы открываются по мере роста ранга. Ранг один на всю игру: очки ранга дают Путь, раскладка дня, турнир и режимы.", 
		"Сейчас твой ранг: %s." % ri.title]
	var p: = Common.popup(main, "Режимы", 616)
	var l: = UI.label("\n\n".join(lines), 21, UI.INK)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.position = Vector2(40, 64)
	l.size = Vector2(580, 300)
	l.custom_minimum_size = Vector2(580, 0)
	p.add_child(l)
	# gates: rank medallion + mode name + the rank it opens at, two columns
	var gates: = [["blitz", "Блиц"], ["zen", "Сад"], ["duel", "Дуэль"], ["etude", "Этюды"], ["shift", "Смена в чайной"], ["climb", "Лунная лестница"]]
	for i in gates.size():
		var k: Array = gates[i]
		var open: = V6ModesData.mode_open(k[0])
		var gx: = 40.0 + (i % 2) * 296.0
		var gy: = 406.0 + (i / 2) * 60.0
		var em: = V8Art.rect(V8Art.rank(V6ModesData.gate_tier(k[0])), Rect2(gx, gy, 48, 48))
		if not open:
			em.modulate = Color(0.75, 0.72, 0.72, 0.9)
		p.add_child(em)
		var gn: = UI.label(k[1], 19, Color("ffd98a") if open else UI.INK, UI.DARK, 2, "body", 900)
		gn.position = Vector2(gx + 56, gy)
		gn.size = Vector2(232, 26)
		gn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		p.add_child(gn)
		var gr: = UI.label(("открыт · " if open else "с ранга ") + V6ModesData.gate_title(k[0]), 16, UI.MUTED, UI.DARK, 2, "body", 800)
		gr.position = Vector2(gx + 56, gy + 25)
		gr.size = Vector2(232, 22)
		gr.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		p.add_child(gr)


func _art(parent: Control, bg: String, r: Rect2, focus: = Vector2(0.5, 0.5), shade_top: = 0.15, shade_bottom: = 0.92) -> TextureRect:
	var path: = "res://assets/bg/%s.webp" % bg if not bg.begins_with("res://") else bg
	if not ResourceLoader.exists(path):
		path = "res://assets/bg/menu.webp"
	var art: = Common.card_art(load(path), Rect2(Vector2(4, 4), r.size - Vector2(8, 8)), focus, 1.0, 24)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(art)
	var shade: = TextureRect.new()
	var g: = GradientTexture2D.new()
	g.gradient = Gradient.new()
	g.gradient.set_color(0, Color(0.06, 0.03, 0.08, shade_top))
	g.gradient.set_color(1, Color(0.06, 0.03, 0.08, shade_bottom))
	g.fill_from = Vector2(0, 0)
	g.fill_to = Vector2(0, 1)
	shade.texture = g
	shade.position = Vector2(4, 4)
	shade.size = r.size - Vector2(8, 8)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(shade)
	return art

func _frame(r: Rect2, radius: = 28.0) -> RBox:
	var card: = UI.rbox("plum", r, radius, 4, 10)
	card.colors(Color(0.12, 0.06, 0.16, 1.0), Color(0.08, 0.04, 0.1, 1.0)).borders(Color("ffe7a6"), Color("c58a2c"))
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.pivot_offset = r.size * 0.5
	add_child(card)
	return card

func _tap(card: Control, cb: Callable) -> void :
	card.gui_input.connect( func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			V9Feel.press(card)
			cb.call())


func _path_card(r: Rect2) -> Control:
	var card: = _frame(r)
	var cur: = clampi(int(G.S.unlocked) - 1, 0, G.LEVELS.size() - 1)
	var lv: Dictionary = G.LEVELS[cur]
	var look: Dictionary = V6Worlds.LOOK[clampi(int(lv.loc), 0, V6Worlds.LOOK.size() - 1)]
	var art_path: = "res://assets/v06/map/%s.webp" % look.art
	_art(card, art_path if ResourceLoader.exists(art_path) else "map_town", r, Vector2(0.5, 0.55), 0.05, 0.9)
	var tag: = UI.rbox("gold", Rect2(18, 18, 168, 34), 14, 3, 6)
	tag.colors(UI.PAL.gold[0], UI.PAL.gold[1])
	card.add_child(tag)
	tag.add_child(UI.center_label(UI.label("ГЛАВНЫЙ ПУТЬ", 16, Color("3a2410"), Color(1, 1, 1, 0.4), 1, "body", 900), Rect2(0, 0, 168, 34)))
	var t: = UI.title("Путь", 48, Color("fff6ea"), Color("3a1620"))
	t.position = Vector2(24, r.size.y - 140)
	t.size = Vector2(400, 62)
	card.add_child(t)
	var sub: = UI.label("Партия %s · %s" % [lv.code, G.LOCS[lv.loc].name], 21, Color("ffe7a6"), UI.DARK, 3, "body", 900)
	sub.position = Vector2(26, r.size.y - 78)
	sub.size = Vector2(r.size.x - 260, 28)
	sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	card.add_child(sub)
	var stars: = 0
	for i in cur + 1:
		stars += G.level_stars(i)
	var dl: = UI.label("Пройдено %d из %d партий · ★ %d" % [cur, G.LEVELS.size(), stars], 17, Color("ddd2c4"), UI.DARK, 2, "body", 800)
	dl.position = Vector2(26, r.size.y - 46)
	dl.size = Vector2(r.size.x - 260, 24)
	card.add_child(dl)
	var go: = JButton.make("Играть", "pink", Rect2(r.size.x - 222, r.size.y - 100, 200, 82), null, 30)
	go.shine_every = 2.6
	go.pressed.connect( func(): main.go("levels", {"select": cur}))
	card.add_child(go)
	_tap(card, func(): main.go("levels", {"select": cur}))
	return card


func _tour_card(r: Rect2) -> Control:
	var card: = _frame(r)
	_art(card, "res://assets/v07/event/cg_finale_card.webp", r, Vector2(0.5, 0.3), 0.35, 0.9)
	var w: = V6ModesData.league("my_week")
	var tier: = clampi(int(w.get("league_tier", G.rank_of(int(G.S.rp)).tier)), 0, G.RANKS.size() - 1)
	# weekly league crest (league/*), not the rank medallion
	Common.league_emblem(card, Rect2(14, 16, 104, 104), tier)
	var t: = UI.title("Турнир недели", 36, Color("fff6ea"), Color("3a1620"))
	t.position = Vector2(128, 16)
	t.size = Vector2(r.size.x - 150, 50)
	card.add_child(t)
	var lname: = str(w.get("league_name", G.RANKS[tier].name))
	var place: = int(w.get("place", 0))
	var line: = lname if lname.begins_with("Лига") else "Лига: %s" % lname
	if place > 0:
		line += " · #%d из %d" % [place, int(w.get("group_size", 20))]
	var ll: = UI.label(line, 21, Color("ffe7a6"), UI.DARK, 3, "body", 900)
	ll.position = Vector2(130, 70)
	ll.size = Vector2(r.size.x - 150, 28)
	ll.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	card.add_child(ll)
	var pts: = int(w.get("points", 0))
	var left: = float(w.get("left_secs", 0.0))
	var info: = ("%s очков недели" % UI.fmt(pts)) if pts > 0 else "Очки недели — за три стола турнира"
	if left > 0.0:
		info += " · ещё " + V7EventData.left_text(left)
	var il: = UI.label(info, 17, Color("ddd2c4"), UI.DARK, 2, "body", 800)
	il.position = Vector2(130, 102)
	il.size = Vector2(r.size.x - 150, 24)
	il.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	card.add_child(il)
	var ql: = V6ModesData.league("my_quarter")
	if ql.has("place"):
		# 0.8: the same rule as the victory window and profile (V8League.quarter_shown): no «#1 001 из 1 001»
		var qtxt: = ("Квартал: " + V8League.quarter_place_text(ql)) if V8League.quarter_shown(ql) else V8League.Q_HIDDEN
		var qt: = UI.label(qtxt, 17, Color("ddd2c4"), UI.DARK, 2, "body", 800)
		qt.position = Vector2(130, 128)
		qt.size = Vector2(r.size.x - 150, 24)
		card.add_child(qt)
	_tap(card, func(): main.go("v7tourney", {"tab": "week"}))
	return card


func _riichi_card(r: Rect2) -> Control:
	var card: = UI.rbox("graphite", r, 24, 3, 8)
	card.borders(Color(1, 1, 1, 0.18), Color(0, 0, 0, 0.35))
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.pivot_offset = r.size * 0.5
	add_child(card)
	card.add_child(V8Art.rect(V8Art.icon("lock"), Rect2(20, (r.size.y - 42) * 0.5, 42, 42)))
	var t: = UI.label("Стол риичи", 24, Color("c9bdb0"), UI.DARK, 3, "body", 900)
	t.position = Vector2(74, 0)
	t.size = Vector2(300, r.size.y)
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	card.add_child(t)
	var c: = Common.chip(card, null, "Скоро", Rect2(r.size.x - 150, (r.size.y - 40) * 0.5, 130, 40), "glass", 19)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.gui_input.connect( func(e):
		if e is InputEventMouseButton and e.pressed:
			V9Feel.deny(card)
			main.toast("Стол риичи появится в одном из следующих обновлений", "lock"))
	return card


func _status(id: String) -> String:
	var s: = V6ModesData.st()
	match id:
		"daily":
			return "Сегодня: готово" if G.daily_done_today() else "Сегодня: новая"
		"blitz":
			return "Рекорд: %d" % int(G.S.get("blitz_best", 0))
		"zen":
			return "Без проигрыша"
		"duel":
			var hs = G.S.get("v6_heroines", {})
			var n: = 0
			if hs is Dictionary:
				for k in hs.get("duel_wins", {}):
					n += int(hs.duel_wins[k])
			return "Побед: %d" % n
		"etude":
			return "★ %d / %d" % [V6ModesData.etude_total(), V6ModesData.ETUDES * 3]
		"shift":
			return "Рекорд чаевых: %d" % int(s.shift_best)
		"climb":
			return "Рекорд: этаж %d" % int(s.climb_best)
	return ""


func _tile(r: Rect2, id: String, title: String, bg: String) -> Control:
	var open: = V6ModesData.mode_open(id)
	var card: = UI.rbox("glass" if open else "graphite", r, 22, 3, 8)
	if open:
		card.borders(Color("ffe7a6"), Color("c58a2c"))
	else:
		card.borders(Color(1, 1, 1, 0.15), Color(0, 0, 0, 0.35))
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.pivot_offset = r.size * 0.5
	add_child(card)
	var path: = "res://assets/bg/%s.webp" % bg
	if not ResourceLoader.exists(path):
		path = "res://assets/bg/menu.webp"
	var th: = Common.card_art(load(path), Rect2(9, 9, r.size.y - 18, r.size.y - 18), Vector2(0.5, 0.45), 1.0, 14)
	if not open:
		(th.material as ShaderMaterial).set_shader_parameter("gray", 1.0)
	card.add_child(th)
	if not open:
		card.add_child(V8Art.rect(V8Art.icon("lock"), Rect2(r.size.y * 0.5 - 20, r.size.y * 0.5 - 20, 40, 40)))
	var tx: = 86.0
	var tw: = r.size.x - tx - 10.0
	var t: = UI.label(title, 21, UI.INK if open else Color("a39a92"), UI.DARK, 3, "body", 900)
	t.position = Vector2(tx, 10)
	t.size = Vector2(tw, 30)
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	card.add_child(t)
	var st: = _status(id) if open else V6ModesData.locked_text(id)
	var sx: = tx
	if not open:
		# the rank it opens at: small medallion, then «Откроется на ранге …»
		card.add_child(V8Art.rect(V8Art.rank(V6ModesData.gate_tier(id)), Rect2(tx - 2, 40, 30, 30)))
		sx = tx + 32.0
	var sw: = r.size.x - sx - 10.0
	var fs: = 16
	if UI.font("body", 800).get_string_size(st, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > sw and not open:
		st = "С ранга %s" % V6ModesData.gate_title(id)
	var sl: = UI.label(st, fs, Color("ffd98a") if open else Color("bfb3a8"), UI.DARK, 2, "body", 800)
	sl.position = Vector2(sx, 42)
	sl.size = Vector2(sw, 26)
	sl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	card.add_child(sl)
	card.gui_input.connect( func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			# 0.9: decide first — a gated mode denies (shake, deny sound and haptic), an open one gets the press
			if V6ModesData.GATES.has(id) and not V6ModesData.mode_open(id):
				V9Feel.deny(card)
			else:
				V9Feel.press(card)
			_open(id, false))
	return card


# feel = false: the tap handler already answered (press or deny); deep links and dev acts answer here
func _open(id: String, feel: = true) -> void :
	if V6ModesData.GATES.has(id) and not V6ModesData.mode_open(id):
		if feel:
			V9Feel.deny(mode_tiles.get(id, null))
		main.toast("%s · %s" % [_mode_name(id), V6ModesData.locked_text(id)], "lock")
		return
	if feel:
		Sfx.play("pop")
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

func _mode_name(id: String) -> String:
	for it in LIST:
		if it[0] == id:
			return it[1]
	return id

func dev_act(a: String) -> void :
	match a:
		"back":
			main.android_back()
		"help":
			_help()
		_:
			_open(a)

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
				V9Feel.press(row)
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
		b.add_child(V8Art.rect(V8Art.icon("lock"), Rect2(r.size.x * 0.5 - 22, 14, 44, 44)))
	else:
		b.add_child(UI.center_label(UI.title(str(i + 1), 36, Color.WHITE if stars < 3 else Color("fff6d8"), Color("5a1a6a") if stars < 3 else Color("9a5a0a")), Rect2(0, 6, r.size.x, 56)))
	for k in 3:
		var st: = V8Art.star_rect(k < stars, Rect2(r.size.x * 0.5 - 45 + k * 30, 66, 30, 30))
		b.add_child(st)
	b.gui_input.connect( func(e):
		if e is InputEventMouseButton and e.pressed:
			if not open:
				V9Feel.deny(b)
				main.toast("Сначала реши этюд %d" % i, "star")
				return
			V9Feel.press(b)
			main.go("arena", {"mode": "etude", "etude": i, "partner": G.S.level_partner}))
