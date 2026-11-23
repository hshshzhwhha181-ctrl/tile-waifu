extends Control

# 0.8 tournament screen: V8Header + tabs «Неделя» (league group of 20, three weekly tables)
# and «Квартал» (top-100 of the quarter + the player's row). Tap a row to open the player card.
# Dev flags: --league_tab=week|quarter, --league_card=<place> (opens the card of that place on the open tab).

static var last_tab: = "week"

var main
var W: = 720.0
var H: = 1280.0
var list: VBoxContainer
var scroll: ScrollContainer
var table_btns: Array = []
var page: Control
var tab: = "week"
var tab_nodes: = {}
var header: V8Header
var week_rows: Array = []
var q_data: Dictionary = {}
var _press: = {}

const Y_TABS: = V8Header.CONTENT_Y + 8.0
const Y_PAGE: = Y_TABS + 76.0


func build(m, args: Dictionary) -> void :
	main = m
	W = size.x
	H = size.y
	main.show_chrome(true, true)
	Sfx.music("menu")
	Common.backdrop(self, "bg_festival", size, 2.6, 0.55, Color(1, 0.95, 0.95))
	Fx.ambient(self, "lanterns", size)
	Common.vignette(self, size, Color(0.08, 0.04, 0.1), 0.65)
	header = V8Header.make(self, main, "Турнир", main.back, rules)
	var dev: = _dev()
	tab = String(args.get("tab", dev.get("league_tab", last_tab)))
	if tab != "quarter":
		tab = "week"
	_tabs()
	_show(tab, false)
	V7Event.show_pending(self, main)
	G.save()
	if dev.has("league_card"):
		_dev_card.call_deferred(int(dev.league_card))


func _dev() -> Dictionary:
	var a: = {}
	for s in OS.get_cmdline_user_args():
		if s.begins_with("--") and "=" in s:
			var kv: = s.substr(2).split("=", true, 1)
			a[kv[0]] = kv[1]
	return a


# ---------------------------------------------------------------- tabs

func _tabs() -> void :
	var r: = Rect2(16, Y_TABS, W - 32, 64)
	var seg: = UI.rbox("glass", r, 32, 2, 6)
	seg.borders(Color(1, 0.9, 0.7, 0.4), Color(0, 0, 0, 0.4))
	add_child(seg)
	var bw: = (r.size.x - 8) * 0.5
	for i in 2:
		var id: String = ["week", "quarter"][i]
		var c: = Control.new()
		c.position = Vector2(4 + i * bw, 4)
		c.size = Vector2(bw, 56)
		c.mouse_filter = Control.MOUSE_FILTER_STOP
		seg.add_child(c)
		var pill: = UI.rbox("gold", Rect2(0, 0, bw, 56), 28, 2, 4)
		pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pill.name = "Pill"
		c.add_child(pill)
		var l: = UI.center_label(UI.label(V8League.TXT[id], 24, UI.INK, UI.DARK, 3, "body", 900), Rect2(0, 0, bw, 56))
		l.name = "L"
		c.add_child(l)
		c.gui_input.connect(func(e):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				if tab != id:
					Sfx.play("tap")
					_show(id, true))
		tab_nodes[id] = c
	_paint_tabs()

func _paint_tabs() -> void :
	for id in tab_nodes:
		var c: Control = tab_nodes[id]
		var on: bool = id == tab
		(c.get_node("Pill") as Control).visible = on
		var l: Label = c.get_node("L")
		l.label_settings.font_color = Color("3a2410") if on else UI.INK
		l.label_settings.outline_color = Color(1, 0.95, 0.8, 0.5) if on else UI.DARK
		l.label_settings.outline_size = 2 if on else 3

func _show(id: String, animate: bool) -> void :
	tab = id
	last_tab = id
	_paint_tabs()
	if page and is_instance_valid(page):
		page.queue_free()
	page = Control.new()
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.size = size
	add_child(page)
	list = null
	scroll = null
	table_btns.clear()
	if id == "week":
		_week_page()
	else:
		_quarter_page()
	if animate:
		page.modulate.a = 0.0
		page.create_tween().tween_property(page, "modulate:a", 1.0, 0.2)


# ---------------------------------------------------------------- week

func _week_page() -> void :
	var t: = V7Ladder.st()
	var L: = V7Ladder.league_def(int(t.league))
	week_rows = V7Ladder.group(t)
	var place: = V7Ladder.place_of(week_rows)
	_week_card(t, L, place)
	_tables(t)
	_board(t, week_rows)

func _week_card(t: Dictionary, L: Dictionary, place: int) -> void :
	var r: = Rect2(16, Y_PAGE, W - 32, 176)
	var card: = UI.rbox("plum", r, 28, 3, 10)
	card.colors(Color(0.12, 0.06, 0.16, 0.97), Color(0.08, 0.04, 0.1, 0.98)).borders(Color("ffe7a6"), Color("c58a2c"))
	page.add_child(card)
	var lc: Color = L.color
	var crest: = UI.rbox("gold", Rect2(18, 16, 92, 92), 46, 4, 8)
	crest.colors(lc.lightened(0.1), lc.darkened(0.45)).borders(Color(1, 1, 1, 0.7), lc.darkened(0.6))
	card.add_child(crest)
	crest.add_child(UI.tex(G.icon("trophy"), Rect2(14, 12, 64, 64)))
	var ln: = UI.label(String(L.name), 28, lc.lightened(0.25), UI.DARK, 4, "body", 900)
	ln.position = Vector2(126, 12)
	ln.size = Vector2(r.size.x - 126 - 190, 40)
	ln.clip_text = true
	card.add_child(ln)
	var left: = UI.label(V8League.TXT.left_week % V7EventData.left_text(V7Ladder.left_secs()), 18, Color("ffd98a"), UI.DARK, 3, "body", 900)
	left.position = Vector2(128, 52)
	card.add_child(left)
	var my: = V7Ladder.my_score(t)
	var z: = V7Ladder.zone(place, int(t.league))
	var zt: = "Сыграй стол недели, чтобы подняться"
	var zc: = Color("ddd2c4")
	if my > 0:
		if z == "up":
			zt = "▲ Зона повышения"
			zc = Color("a9d9c4")
		elif z == "down":
			zt = "▼ Зона понижения"
			zc = Color("e3a3b2")
		else:
			zt = "Лига сохраняется"
	var zl: = UI.label(zt, 18, zc, UI.DARK, 3, "body", 900)
	zl.position = Vector2(128, 80)
	zl.size = Vector2(r.size.x - 128 - 190, 28)
	zl.clip_text = true
	card.add_child(zl)
	var pl: = UI.title("#%d" % place, 54, Color.WHITE, UI.DARK)
	pl.position = Vector2(r.size.x - 200, 4)
	pl.size = Vector2(180, 70)
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	card.add_child(pl)
	var sc: = UI.label((V8League.TXT.pts % UI.fmt(my)) if my > 0 else V8League.TXT.no_play, 18, Color("ddd2c4"), UI.DARK, 3, "body", 900)
	sc.position = Vector2(r.size.x - 260, 76)
	sc.size = Vector2(240, 26)
	sc.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	card.add_child(sc)
	var pid: String = V7Ladder.prize_of(int(t.start))
	var it: Dictionary = G.ITEM[pid]
	var strip: = UI.rbox("glass", Rect2(12, 116, r.size.x - 24, 50), 20, 2, 4)
	strip.borders(Color(1, 0.9, 0.7, 0.3), Color(0, 0, 0, 0.3))
	card.add_child(strip)
	strip.add_child(Common.card_art(G.art_tex(it), Rect2(6, 4, 42, 42), Vector2(0.5, 0.2), 1.6, 10))
	var own: = G.owns(pid)
	var pt: = ("Приз топ-3: «%s» · уже твой, вместо него +%d" % [it.name, V7Ladder.PRIZE_OWNED_GEMS]) if own else ("Приз топ-3: «%s» · %s" % [it.name, G.HEROES[it.hero].name])
	var pll: = UI.label(pt, 17, Color("ffe7a6"), UI.DARK, 2, "body", 900)
	pll.position = Vector2(58, 0)
	pll.size = Vector2(strip.size.x - 66, 50)
	pll.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pll.clip_text = true
	pll.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	strip.add_child(pll)
	UI.slide_in(card, Vector2(0, -20), 0.0, 0.4)

func _tables(t: Dictionary) -> void :
	var bw: = (W - 32 - 20) / 3.0
	var y: = Y_PAGE + 188.0
	for k in V7Ladder.TABLES:
		var cfg: = V7Ladder.table_cfg(k, int(t.start))
		var r: = Rect2(16 + k * (bw + 10), y, bw, 132)
		var c: = UI.rbox("plum", r, 24, 3, 8)
		c.colors(Color(0.14, 0.08, 0.16, 0.96), Color(0.08, 0.04, 0.1, 0.97)).borders(Color("ffe7a6"), Color("c58a2c"))
		c.mouse_filter = Control.MOUSE_FILTER_STOP
		c.pivot_offset = r.size * 0.5
		page.add_child(c)
		var art: = Common.card_art(load("res://assets/bg/%s.webp" % cfg.bg), Rect2(4, 4, bw - 8, 56), Vector2(0.5, 0.5), 1.0, 18)
		c.add_child(art)
		c.add_child(UI.center_label(UI.label(["Стол I", "Стол II", "Стол III"][k], 22, Color.WHITE, UI.DARK, 4, "body", 900), Rect2(0, 10, bw, 34)))
		var feat: = UI.label(V6Layouts.shape_name(cfg.shape) + (" · ★" if k == 2 else ""), 15, Color("ddd2c4"), UI.DARK, 2)
		feat.position = Vector2(0, 40)
		feat.size = Vector2(bw, 22)
		feat.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		c.add_child(feat)
		var best: = int(t.best[k])
		var bl: = UI.label(("Лучший: %s" % UI.fmt(best)) if best > 0 else "Не сыгран", 18, Color("ffe7a6") if best > 0 else Color("bfb3a8"), UI.DARK, 3, "body", 900)
		bl.position = Vector2(0, 64)
		bl.size = Vector2(bw, 26)
		bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		c.add_child(bl)
		var go: = UI.rbox("pink" if best == 0 else "gold", Rect2(12, 94, bw - 24, 30), 15, 2, 4)
		c.add_child(go)
		go.add_child(UI.center_label(UI.label("ИГРАТЬ" if best == 0 else "УЛУЧШИТЬ", 16, Color.WHITE if best == 0 else Color("3a2410"), UI.DARK if best == 0 else Color(1, 1, 1, 0.4), 2, "body", 900), Rect2(0, 0, bw - 24, 30)))
		var kk: = k
		c.gui_input.connect(func(e):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				Sfx.play("pop")
				UI.punch(c, 0.08)
				main.go("v7play", {"mode": "v7tourney", "table": kk, "partner": G.S.level_partner if G.hero_unlocked(G.S.level_partner) else "mc"}))
		UI.slide_in(c, Vector2(0, 30), 0.12 + k * 0.05, 0.4)
		table_btns.append(c)

func _frame(top: float, bottom: float, title: String) -> void :
	var frame: = UI.rbox("glass", Rect2(16, top, W - 32, bottom - top), 26, 3, 8)
	frame.borders(Color("ffe7a6"), Color("c58a2c"))
	page.add_child(frame)
	var hd: = UI.label(title, 17, Color("bfb3a8"), UI.DARK, 2, "body", 900)
	hd.position = Vector2(36, top + 10)
	page.add_child(hd)

func _make_scroll(top: float, h: float) -> void :
	scroll = ScrollContainer.new()
	scroll.position = Vector2(24, top)
	scroll.size = Vector2(W - 48, h)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	page.add_child(scroll)
	list = VBoxContainer.new()
	list.custom_minimum_size = Vector2(W - 48, 0)
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)

func _board(t: Dictionary, rows: Array) -> void :
	var top: = Y_PAGE + 332.0
	var bottom: = H - 140.0
	var league: = int(t.league)
	var can_down: = V8League.can_demote(league, String(t.week))
	var ht: = V8League.TXT.group % V7Ladder.GROUP
	if league < V7Ladder.LEAGUES.size() - 1:
		ht += " · ▲%d" % V7Ladder.UP
	if can_down:
		ht += " · ▼%d" % V7Ladder.DOWN
	_frame(top, bottom, ht)
	_make_scroll(top + 40, bottom - top - 50)
	var me_i: = 0
	for i in rows.size():
		var place: = i + 1
		if place == V7Ladder.UP + 1 and league < V7Ladder.LEAGUES.size() - 1:
			list.add_child(_divider(V8League.TXT.up_zone, Color("a9d9c4")))
		if place == V7Ladder.GROUP - V7Ladder.DOWN + 1 and can_down:
			list.add_child(_divider(V8League.TXT.down_zone, Color("e3a3b2")))
		list.add_child(_row(rows[i], place, V7Ladder.zone(place, league), str(UI.fmt(int(rows[i].score))), -1, {"league": league}))
		if rows[i].me:
			me_i = i
	_scroll_to.call_deferred(me_i)

func _scroll_to(i: int) -> void :
	await get_tree().process_frame
	if is_inside_tree() and scroll and is_instance_valid(scroll):
		scroll.scroll_vertical = maxi(0, int((i - 3) * 70.0))

func _divider(text: String, col: Color) -> Control:
	var c: = Control.new()
	c.custom_minimum_size = Vector2(W - 48, 26)
	c.mouse_filter = Control.MOUSE_FILTER_PASS
	var l: = UI.label(text, 15, col, UI.DARK, 2, "body", 900)
	l.position = Vector2(0, 2)
	l.size = Vector2(W - 48, 22)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(l)
	return c

# one row: place, avatar, nick, optional rank crest, value; tap opens the player card
func _row(r: Dictionary, place: int, z: String, value: String, tier: int, ctx: Dictionary) -> Control:
	var c: = Control.new()
	var rw: = W - 48
	c.custom_minimum_size = Vector2(rw, 64)
	c.size = Vector2(rw, 64)
	c.mouse_filter = Control.MOUSE_FILTER_PASS
	var me: bool = r.me
	var bg: = UI.rbox("pink" if me else "plum", Rect2(0, 0, rw, 64), 20, 2 if me else 1, 4)
	if not me:
		bg.colors(Color(0.16, 0.14, 0.17, 0.85), Color(0.1, 0.09, 0.11, 0.9))
		bg.borders(Color("a9d9c4") if z == "up" else (Color("e3a3b2") if z == "down" else Color(1, 1, 1, 0.08)), Color(0, 0, 0, 0.3))
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(bg)
	var pc: = Color("ffd34d") if place == 1 else (Color("e9e4ff") if place == 2 else (Color("d99a6c") if place == 3 else Color("ddd2c4")))
	var ps: = str(place) if place < 1000 else UI.fmt(place)
	# Playfair only from 24 px up (spec): places 100+ are set in Nunito
	var pl: = UI.label(ps, 26 if place < 100 else (22 if place < 1000 else 18), pc, UI.DARK, 3, "title" if place < 100 else "body", 900)
	pl.position = Vector2(4, 0)
	pl.size = Vector2(60, 64)
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	c.add_child(pl)
	c.add_child(V8Population.avatar_view(String(r.get("avatar", "mc_base")), String(r.get("hero", "mc")), Rect2(68, 6, 52, 52)))
	var x_end: = rw - 140.0
	if tier >= 0:
		Common.rank_emblem(c, Rect2(rw - 186, 12, 40, 40), tier, 0).get_child(-1).visible = false
		x_end = rw - 190.0
	elif place <= 3 and int(r.get("score", 0)) > 0:
		c.add_child(UI.tex(G.icon("trophy"), Rect2(rw - 186, 10, 44, 44)))
		x_end = rw - 190.0
	var nm: = UI.label(String(r.name), 21, Color.WHITE, UI.DARK, 3, "body", 900)
	nm.position = Vector2(132, 0)
	nm.size = Vector2(x_end - 132, 64)
	nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nm.clip_text = true
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	c.add_child(nm)
	var sc: = UI.label(value, 22, Color("ffe7a6"), UI.DARK, 3, "body", 900)
	sc.position = Vector2(rw - 140, 0)
	sc.size = Vector2(124, 64)
	sc.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sc.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	c.add_child(sc)
	var pid: = int(r.get("pid", -1 if me else -2))
	if pid >= -1:
		c.gui_input.connect(func(e): _row_input(e, c, pid, ctx))
	return c

func _row_input(e: InputEvent, c: Control, pid: int, ctx: Dictionary) -> void :
	if not (e is InputEventMouseButton) or e.button_index != MOUSE_BUTTON_LEFT:
		return
	if e.pressed:
		_press[c.get_instance_id()] = e.global_position
		return
	var k: = c.get_instance_id()
	if _press.has(k):
		var p0: Vector2 = _press[k]
		_press.erase(k)
		if p0.distance_to(e.global_position) < 16.0:
			Sfx.play("pop")
			UI.punch(c, 0.03)
			V8League.open_card(main, pid, ctx)


# ---------------------------------------------------------------- quarter

func _quarter_page() -> void :
	# the home «Рейтинг» button shows the quarter place only once the player has seen this table
	if not G.S.get("v8_q_seen", false):
		G.S["v8_q_seen"] = true
		G.save()
	q_data = V8League.quarter_table()
	var me: Dictionary = q_data.me
	var q: Dictionary = q_data.q
	var r: = Rect2(16, Y_PAGE, W - 32, 150)
	var card: = UI.rbox("plum", r, 28, 3, 10)
	card.colors(Color(0.12, 0.06, 0.16, 0.97), Color(0.08, 0.04, 0.1, 0.98)).borders(Color("ffe7a6"), Color("c58a2c"))
	page.add_child(card)
	var tt: = UI.title(V8League.quarter_title(q), 32, Color("fff3dc"), UI.DARK)
	tt.position = Vector2(22, 10)
	tt.size = Vector2(r.size.x - 240, 46)
	card.add_child(tt)
	var left: = UI.label(V8League.TXT.left % V7EventData.left_text(float(q.end) - V8League.now()), 18, Color("ffd98a"), UI.DARK, 3, "body", 900)
	left.position = Vector2(24, 62)
	card.add_child(left)
	var note: = UI.label(V8League.TXT.q_note, 17, Color("ddd2c4"), UI.DARK, 2, "body", 800)
	note.position = Vector2(24, 92)
	note.size = Vector2(r.size.x - 260, 48)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(note)
	var pl: = UI.title("#%s" % UI.fmt(int(me.place)), 50 if int(me.place) < 1000 else 42, Color.WHITE, UI.DARK)
	pl.position = Vector2(r.size.x - 230, 4)
	pl.size = Vector2(210, 70)
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	card.add_child(pl)
	var sub: = UI.label(V8League.TXT.of_total % UI.fmt(int(q_data.total)), 18, Color("ddd2c4"), UI.DARK, 3, "body", 900)
	sub.position = Vector2(r.size.x - 260, 74)
	sub.size = Vector2(240, 26)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	card.add_child(sub)
	var pts: = UI.label(V8League.TXT.rp_pts % UI.fmt(int(me.points)), 18, Color("ffe7a6"), UI.DARK, 3, "body", 900)
	pts.position = Vector2(r.size.x - 260, 102)
	pts.size = Vector2(240, 26)
	pts.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	card.add_child(pts)
	UI.slide_in(card, Vector2(0, -20), 0.0, 0.4)
	var top: = Y_PAGE + 162.0
	var bottom: = H - 140.0
	var rows: Array = q_data.rows
	var in_top: = int(me.place) <= rows.size()
	_frame(top, bottom, V8League.TXT.top)
	var list_h: = bottom - top - 50 - (0.0 if in_top else 86.0)
	_make_scroll(top + 40, list_h)
	var me_i: = 0
	for i in rows.size():
		var row: Dictionary = rows[i]
		row["score"] = row.points
		list.add_child(_row(row, int(row.place), "", UI.fmt(int(row.points)), int(row.tier), {}))
		if row.me:
			me_i = i
	if in_top:
		_scroll_to.call_deferred(me_i)
	else:
		var dots: = UI.label("· · ·", 18, Color("bfb3a8"), UI.DARK, 2, "body", 900)
		dots.position = Vector2(16, top + 40 + list_h)
		dots.size = Vector2(W - 32, 22)
		dots.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		page.add_child(dots)
		var mr: = _row(me, int(me.place), "", UI.fmt(int(me.points)), int(me.tier), {})
		mr.position = Vector2(24, bottom - 74)
		page.add_child(mr)


# ---------------------------------------------------------------- rules / dev

func rules() -> void :
	var p: = Common.popup(main, "Правила турнира", 760)
	var txt: = "• Неделя идёт с понедельника по воскресенье. Три стола недели одинаковые у всех игроков.\n• Очки за пару: %d, серия добавляет +%d за каждую пару подряд, золото +%d. Очищенный стол +%d, скорость до +%d, партия без помощи и переполнений +%d.\n• Помощь только бесплатная и стоит %d очков. Переполнение лотка −%d, третье заканчивает партию.\n• В зачёт идёт лучший результат на каждом столе: переигрывать можно сколько угодно, хуже не станет.\n• Лиги идут по ступеням ранга: от Бамбука до Небожителей. В группе 20 игроков с близким рангом. Топ-%d поднимаются, последние %d опускаются, но не в первую неделю и не ниже твоего ранга минус одна ступень. Пропустишь неделю — лига сохранится.\n• Квартал: рейтинг по очкам ранга, заработанным с начала квартала во всех режимах." % [V7Ladder.PAIR, V7Ladder.COMBO, V7Ladder.GOLD, V7Ladder.CLEAR, V7Ladder.TIME, V7Ladder.CLEAN, V7Ladder.BOOSTER, V7Ladder.OVERFLOW, V7Ladder.UP, V7Ladder.DOWN]
	var l: = UI.label(txt, 18, UI.INK)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.position = Vector2(40, 60)
	l.size = Vector2(580, 520)
	l.custom_minimum_size = Vector2(580, 0)
	p.add_child(l)
	var y: = 590.0
	var L: = V7Ladder.league_def(int(V7Ladder.st().league))
	var hl: = UI.label("Награды «%s»: 1 место %d · 2–3 %d · 4–5 %d · 6–10 %d · остальные %d кристаллов" % ([L.name] + L.gems), 17, Color("ffd98a"), UI.DARK, 2, "body", 900)
	hl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hl.position = Vector2(40, y)
	hl.size = Vector2(580, 60)
	hl.custom_minimum_size = Vector2(580, 0)
	p.add_child(hl)
	var hist: Array = V7Ladder.st().get("history", [])
	if not hist.is_empty():
		var last: Dictionary = hist[hist.size() - 1]
		var ll: = UI.label("Прошлая неделя: #%d, %s, %d очков" % [int(last.place), V7Ladder.league_def(int(last.league)).short, int(last.score)], 17, Color("a9d9c4"))
		ll.position = Vector2(40, y + 70)
		p.add_child(ll)

func _dev_card(place: int) -> void :
	await get_tree().create_timer(0.6).timeout
	if not is_inside_tree():
		return
	if tab == "week":
		var i: = clampi(place - 1, 0, week_rows.size() - 1)
		var r: Dictionary = week_rows[i]
		V8League.open_card(main, -1 if r.me else int(r.get("pid", -1)), {"league": int(V7Ladder.st().league)})
		return
	var rows: Array = q_data.get("rows", [])
	if place == int(q_data.me.place) or rows.is_empty():
		V8League.open_card(main, -1)
		return
	var row: Dictionary = rows[clampi(place - 1, 0, rows.size() - 1)]
	V8League.open_card(main, -1 if row.me else int(row.pid))

func dev_act(a: String) -> void :
	match a:
		"rules":
			rules()
		"scroll":
			if scroll:
				scroll.scroll_vertical = 600
		"week":
			_show("week", false)
		"quarter":
			_show("quarter", false)
		"card":
			_dev_card(1)
		"me":
			V8League.open_card(main, -1)
