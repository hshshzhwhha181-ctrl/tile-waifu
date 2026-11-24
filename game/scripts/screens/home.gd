extends Control

# 0.8 home (Чайная): left column of 4 (Поручения, Визиты, Письма, Рейтинг), right column of cards
# (лига недели, ивент, баннер), «Режимы» + «Сесть за стол» bottom right, affection plate bottom left.

const COL_X: = 16.0
const COL_Y: = 140.0
const COL_STEP: = 124.0
const CARD_W: = 198.0
const CARD_TOP: = 136.0

var main
var hero: Hero
var bubble: Control
var play_btn: JButton
var modes_btn: JButton
var aff_root: Control
var side_btns: = {}
var league_card: Control
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
	# 0.8: her legs fade out at the knees under the button cluster (no shoes peeking between the plate and the CTA)
	Common.floor_fade(self, H - 520.0, H - 150.0)
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
	modes_btn = JButton.make("Режимы", "glass", Rect2(W - 418, H - 296 - 92, 400, 80), null, 28)
	modes_btn.set_sub("Путь, турнир и другие столы", 17)
	modes_btn.lbl.position.x += 34
	modes_btn.lbl.size.x -= 34
	modes_btn.sub.position.x += 34
	modes_btn.sub.size.x -= 34
	modes_btn.add_child(V8Art.rect(V8Art.nav("play"), Rect2(16, 8, 64, 64)))
	modes_btn.pressed.connect( func(): main.go("modes"))
	add_child(modes_btn)
	UI.pop_in(modes_btn, 0.3)
	await get_tree().create_timer(0.9).timeout
	if is_inside_tree():
		_say(Sfx.say(G.S.partner, "greet"))
	if G.has_meta("pending_offer") and not G.offer_shown:
		G.remove_meta("pending_offer")
		await get_tree().create_timer(1.4).timeout
		if is_inside_tree():
			main.maybe_offer()

# ---------------------------------------------------------------- left column

func _build_left() -> void :
	var mail_new: = V7RoomData.unread_mail() > 0 or _unseen_notices() > 0
	var items: = [
		["tasks", "tasks", V6Txt.s("home.tasks"), func(): Daily.tasks(main, self), G.tasks_ready() > 0],
		["login", "visits", V6Txt.s("home.login"), func(): Daily.login(main, self), G.login_ready()],
		["mail", "letters", V6Txt.s("home.mail"), func(): open_mail(), mail_new],
		["rating", "rating", "Рейтинг", func(): main.go("v7tourney", {"tab": "quarter"}), false],
	]
	for i in items.size():
		var it: Array = items[i]
		var b: = _side_button(it[1], it[2], Rect2(COL_X, COL_Y + i * COL_STEP, 84, 84), it[3], it[4])
		if it[0] == "rating":
			_rating_mark(b)
		side_btns[it[0]] = b
		UI.slide_in(b, Vector2(-50, 0), 0.1 + i * 0.05)

# 0.8 left-column button: the round V8Art icon (tasks / visits / letters / rating — it has its own gold-rimmed
# disc, so no drawn disc behind it), caption under it, a pulsing dot when something is ready.
func _side_button(icon: String, text: String, rect: Rect2, cb: Callable, badge: bool) -> Control:
	var c: = Control.new()
	c.position = rect.position
	c.size = rect.size
	c.pivot_offset = rect.size * 0.5
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	var art: = V8Art.rect(V8Art.icon(icon), Rect2(Vector2.ZERO, Vector2(rect.size.x, rect.size.x)))
	art.name = "Icon"
	c.add_child(art)
	c.add_child(UI.center_label(UI.label(text, 18, UI.INK, UI.DARK, 4, "body", 900), Rect2(-24, rect.size.x - 6, rect.size.x + 48, 26)))
	if badge:
		var d: = UI.rbox("gold", Rect2(rect.size.x - 20, 2, 16, 16), 8, 1, 3)
		d.colors(Color("ffe7a6"), Color("ff8fb0"))
		c.add_child(d)
		d.pivot_offset = Vector2(8, 8)
		var t: Tween = d.create_tween().set_loops()
		t.tween_property(d, "scale", Vector2(1.2, 1.2), 0.45).set_trans(Tween.TRANS_SINE)
		t.tween_property(d, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_SINE)
	c.gui_input.connect( func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			Sfx.play("pop")
			UI.punch(c, 0.15)
			cb.call())
	add_child(c)
	return c

# «Рейтинг» gets a small quarter-place plate on top of its icon.
func _rating_mark(b: Control) -> void :
	var q: = _league_call("my_quarter")
	# 0.8: the same rule as the victory window, profile and Режимы (V8League.quarter_shown): no «#1 001»
	var txt: = "#%s" % UI.fmt(int(q.place)) if V8League.quarter_shown(q) else "топ-100"
	var fw: float = UI.font("body", 900).get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 16.0
	var pl: = UI.rbox("gold", Rect2(84 - fw + 14, -8, fw, 24), 12, 2, 3)
	pl.colors(Color("fae4a6"), Color("c38f3c"))
	pl.set_param("shadow_color", Color(0, 0, 0, 0.3))
	b.add_child(pl)
	pl.add_child(UI.center_label(UI.label(txt, 16, Color("3a2410"), Color(1, 1, 1, 0.4), 1, "body", 900), Rect2(0, 0, fw, 24)))

func refresh_badges() -> void :
	for k in side_btns:
		side_btns[k].queue_free()
	side_btns.clear()
	_build_left()

# «Письма»: what the heroines actually wrote after dates + newly opened room scenes. Toast if there is nothing.
func open_mail() -> void :
	var entries: Array = []
	var mail: Array = V7RoomData.mail()
	for i in range(mail.size() - 1, -1, -1):
		var e = mail[i]
		if e is Dictionary and G.HEROES.has(str(e.get("h", ""))):
			entries.append({"h": str(e.h), "text": "«%s»" % str(e.text), "sub": _ago(int(e.get("t", 0))), "new": not bool(e.get("read", false))})
	for h in G.HERO_ORDER:
		if not G.hero_unlocked(h):
			continue
		for id in V7RoomData.fresh_scenes(h):
			entries.push_front({"h": h, "text": "Открыта сцена «%s». Загляни ко мне в комнату." % V7RoomScenes.SCENES[id].title, "sub": "Комната", "new": not _notice_seen().has(str(id))})
	if entries.is_empty():
		main.toast("Писем пока нет. Своди героиню на свидание", "mail")
		return
	entries = entries.slice(0, 8)
	var rh: = 132.0
	var p: = Common.popup(main, V6Txt.s("home.mail"), 84 + entries.size() * (rh + 10) + 20)
	var y: = 64.0
	for e in entries:
		var row: = UI.rbox("glass", Rect2(26, y, 608, rh), 24, 3, 8)
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		row.pivot_offset = row.size * 0.5
		if e.new:
			row.borders(Color("ffe7a6"), Color("c58a2c"))
		p.add_child(row)
		row.add_child(Common.avatar(e.h, Rect2(12, 14, 92, 92), "gold" if e.new else "glass"))
		var nm: = UI.label(G.HEROES[e.h].name, 22, Color("ffd2de"), UI.DARK, 3, "body", 900)
		nm.position = Vector2(120, 10)
		row.add_child(nm)
		var sub: = UI.label(e.sub, 16, UI.MUTED, UI.DARK, 2, "body", 800)
		sub.position = Vector2(330, 14)
		sub.size = Vector2(260, 22)
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(sub)
		var tx: = UI.label(e.text, 19, UI.INK, UI.DARK, 2, "body", 800)
		tx.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tx.position = Vector2(120, 42)
		tx.size = Vector2(470, 82)
		tx.custom_minimum_size = Vector2(470, 0)
		tx.max_lines_visible = 3
		tx.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_child(tx)
		var hh: String = e.h
		row.gui_input.connect( func(ev):
			if ev is InputEventMouseButton and ev.pressed:
				Sfx.play("pop")
				UI.punch(row, 0.05)
				main.go("room", {"hero": hh}))
		y += rh + 10
	V7RoomData.mark_mail_read()
	_mark_notices_seen()
	G.save()
	if side_btns.has("mail"):
		var root: Control = p.get_meta("root")
		root.set_meta("on_close", func():
			if is_inside_tree():
				refresh_badges())

# 0.8: fresh-scene notices in «Письма» count as new only until the player has opened the letters once
# (the Комната «Сцены» badge keeps tracking unwatched scenes).
static func _notice_seen() -> Dictionary:
	var d = G.S.get("v8_mail_seen")
	if not (d is Dictionary):
		d = {}
		G.S["v8_mail_seen"] = d
	return d

static func _unseen_notices() -> int:
	var seen: = _notice_seen()
	var n: = 0
	for h in G.HERO_ORDER:
		if G.hero_unlocked(h):
			for id in V7RoomData.fresh_scenes(h):
				if not seen.has(str(id)):
					n += 1
	return n

static func _mark_notices_seen() -> void :
	var seen: = _notice_seen()
	for h in G.HERO_ORDER:
		if G.hero_unlocked(h):
			for id in V7RoomData.fresh_scenes(h):
				seen[str(id)] = true

static func _ago(t: int) -> String:
	if t <= 0:
		return ""
	var d: = int(Time.get_unix_time_from_system()) - t
	if d < 3600:
		return "только что"
	if d < 86400:
		return "%d ч назад" % (d / 3600)
	return "%d д назад" % (d / 86400)

# ---------------------------------------------------------------- right column

static func _league_call(fn: String) -> Dictionary:
	return V6ModesData.league(fn)

func _build_right() -> void :
	var x: = W - CARD_W - 16.0
	var y: = CARD_TOP
	league_card = _league_card(Rect2(x, y, CARD_W, 176))
	UI.slide_in(league_card, Vector2(60, 0), 0.2)
	y += 176 + 12
	# 0.8: the column holds two cards at most — the event and the summon banner share the second slot and take
	# turns, so nothing ever covers her raised hand with the 中 tile (y ≈ 485-520 under the column)
	var slot2: Array[Control] = []
	if V7Event.is_open():
		var def: = V7EventData.cur_def()
		var ev: = V7EventData.st()
		var c1: = _banner_card(Rect2(x, y, CARD_W, 156), V7Event.art(def), "ИВЕНТ", def.name, "ещё " + V7EventData.left_text(V7EventData.left_secs()), "rose", Vector2(0.5, 0.2))
		c1.add_child(UI.tex(V7Event.cur_icon(def), Rect2(CARD_W - 48, 4, 44, 44)))
		if ev.daily != V7EventData.today_key():
			var x2: = UI.rbox("red", Rect2(CARD_W - 66, 44, 64, 26), 13, 2, 4)
			c1.add_child(x2)
			x2.add_child(UI.center_label(UI.label("×2", 16, Color.WHITE, Color("6a1020"), 2, "body", 900), Rect2(0, 0, 64, 26)))
		c1.gui_input.connect( func(e):
			if e is InputEventMouseButton and e.pressed:
				Sfx.play("pop")
				UI.punch(c1, 0.06)
				main.go("v7event"))
		UI.slide_in(c1, Vector2(60, 0), 0.28)
		slot2.append(c1)
	if G.summon_open():
		var nb: Control
		if int(G.S.newbie_left) > 0:
			nb = _banner_card(Rect2(x, y, CARD_W, 168), G.art_tex(G.ITEM["o_dragon"]), "−20%", V6Txt.s("home.newbie"), V6Txt.s("home.newbie_sub"), "gold", Vector2(0.5, 0.22))
			nb.gui_input.connect( func(e):
				if e is InputEventMouseButton and e.pressed:
					UI.tap(nb, 0.06)
					main.go("summon", {"banner": 0}))
			if G.S.free10:
				Common.badge(nb, 0, Vector2(CARD_W - 22, -10))
		else:
			nb = _banner_card(Rect2(x, y, CARD_W, 168), G.art_tex(G.ITEM["n_ssr"]), "БАННЕР", V6Txt.s("home.event_name"), V6Txt.s("home.event_left"), "lav", Vector2(0.5, 0.25))
			nb.gui_input.connect( func(e):
				if e is InputEventMouseButton and e.pressed:
					Sfx.play("pop")
					UI.punch(nb, 0.06)
					main.go("summon", {"banner": 2}))
		UI.slide_in(nb, Vector2(60, 0), 0.34)
		slot2.append(nb)
	_rotate_slot(slot2)
	G.save()
	V7Event.show_pending(self, main)

# the second right-column slot: one card shows, the others wait hidden; with two or more they cross-fade every
# 5 s (a hidden card takes no taps) and two small dots under the slot say there is more than one
func _rotate_slot(cards: Array[Control]) -> void :
	if cards.size() < 2:
		return
	for i in range(1, cards.size()):
		cards[i].visible = false
	var bottom: = 0.0
	for c in cards:
		bottom = maxf(bottom, c.position.y + c.size.y)
	var dots: Array[Control] = []
	var dx0: = cards[0].position.x + CARD_W * 0.5 - (cards.size() * 16.0 - 6.0) * 0.5
	for i in cards.size():
		var d: = UI.rbox("gold", Rect2(dx0 + i * 16.0, bottom + 6.0, 10, 10), 5, 1, 2)
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		d.modulate.a = 1.0 if i == 0 else 0.4
		add_child(d)
		dots.append(d)
	var at: = [0]
	var t: = create_tween().set_loops()
	t.tween_interval(5.0)
	t.tween_callback( func():
		var a: Control = cards[at[0]]
		at[0] = (at[0] + 1) % cards.size()
		var b: Control = cards[at[0]]
		if not is_instance_valid(a) or not is_instance_valid(b):
			return
		b.modulate.a = 0.0
		b.visible = true
		var ft: = a.create_tween()
		ft.tween_property(a, "modulate:a", 0.0, 0.3)
		ft.tween_callback(a.hide)
		ft.tween_property(a, "modulate:a", 1.0, 0.0)
		b.create_tween().tween_property(b, "modulate:a", 1.0, 0.3)
		for i in dots.size():
			dots[i].modulate.a = 1.0 if i == at[0] else 0.4)

func _league_card(r: Rect2) -> Control:
	var w: = _league_call("my_week")
	var c: = Control.new()
	c.position = r.position
	c.size = r.size
	c.pivot_offset = r.size * 0.5
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(c)
	c.add_child(UI.rbox("gold", Rect2(Vector2.ZERO, r.size), 22, 4, 12))
	var art: = Common.card_art(load("res://assets/v07/event/cg_finale_card.webp"), Rect2(6, 6, r.size.x - 12, r.size.y - 12), Vector2(0.5, 0.3), 1.0, 18)
	var am: ShaderMaterial = art.material
	am.set_shader_parameter("bottom_shade", 0.95)
	c.add_child(art)
	var dim: = ColorRect.new()
	dim.color = Color(0.06, 0.04, 0.07, 0.45)
	dim.position = Vector2(6, 6)
	dim.size = r.size - Vector2(12, 12)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(dim)
	var tag: = UI.rbox("pink", Rect2(-8, 10, 150, 32), 12, 3, 8)
	c.add_child(tag)
	tag.add_child(UI.center_label(UI.label("ЛИГА НЕДЕЛИ", 16, Color.WHITE, Color("7a2346"), 4, "body", 900), Rect2(0, 0, 150, 32)))
	var tier: = clampi(int(w.get("league_tier", G.rank_of(int(G.S.rp)).tier)), 0, G.RANKS.size() - 1)
	# weekly league crest (league/*), not the rank medallion
	Common.league_emblem(c, Rect2(8, 46, 76, 76), tier)
	var place: = int(w.get("place", 0))
	var gs: = int(w.get("group_size", 20))
	var pl: = UI.title("#%d" % place if place > 0 else "—", 40, Color("fff6ea"), UI.DARK)
	pl.position = Vector2(86, 48)
	pl.size = Vector2(104, 50)
	pl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	c.add_child(pl)
	var of: = UI.label("из %d" % gs, 17, Color("ffe7a6"), UI.DARK, 3, "body", 900)
	of.position = Vector2(88, 96)
	of.size = Vector2(104, 22)
	c.add_child(of)
	var lname: = str(w.get("league_name", G.RANKS[tier].name))
	var ln: = UI.label(lname, 19, Color(G.RANKS[tier].color).lerp(Color.WHITE, 0.35), UI.DARK, 4, "body", 900)
	ln.position = Vector2(14, r.size.y - 52)
	ln.size = Vector2(r.size.x - 28, 24)
	ln.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	c.add_child(ln)
	var pts: = int(w.get("points", 0))
	var pt: = UI.label(("%s очков недели" % UI.fmt(pts)) if pts > 0 else "Сыграй стол турнира", 16, Color("fff3c4"), UI.DARK, 3, "body", 900)
	pt.position = Vector2(14, r.size.y - 30)
	pt.size = Vector2(r.size.x - 28, 22)
	pt.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	c.add_child(pt)
	c.gui_input.connect( func(e):
		if e is InputEventMouseButton and e.pressed:
			Sfx.play("pop")
			UI.punch(c, 0.06)
			main.go("v7tourney", {"tab": "week"}))
	return c

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
	var tw: float = maxf(96.0, UI.font("body", 900).get_string_size(tag_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x + 28.0)
	var tag: = UI.rbox("pink" if pal != "gold" else "red", Rect2(-8, 10, tw, 32), 12, 3, 8)
	ev.add_child(tag)
	tag.add_child(UI.center_label(UI.label(tag_text, 17, Color.WHITE, Color("7a2346"), 4, "body", 900), Rect2(0, 0, tw, 32)))
	var fs: = 22
	while fs > 17 and UI.font("body", 900).get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > ev.size.x - 24:
		fs -= 1
	var t: = UI.label(name_text, fs, Color.WHITE, Color("3f2a7a"), 6, "body", 900)
	t.position = Vector2(12, ev.size.y - 66)
	t.size = Vector2(ev.size.x - 20, 30)
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	ev.add_child(t)
	var s: = UI.label(sub_text, 16, Color("fff3c4"), Color("3f2a7a"), 4, "body", 900)
	s.position = Vector2(14, ev.size.y - 36)
	s.size = Vector2(ev.size.x - 22, 24)
	s.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	ev.add_child(s)
	return ev

# ---------------------------------------------------------------- affection plate

func _build_affection() -> void :
	if aff_root:
		aff_root.queue_free()
	var h: String = G.S.partner
	var r: = Rect2(16, H - 296, 270, 114)
	aff_root = UI.rbox("glass", r, 26, 3, 12)
	add_child(aff_root)
	aff_root.mouse_filter = Control.MOUSE_FILTER_STOP
	aff_root.gui_input.connect( func(e):
		if e is InputEventMouseButton and e.pressed:
			UI.tap(aff_root, 0.06)
			main.go("room", {"hero": G.S.partner}))
	aff_root.add_child(V8Art.rect(V8Art.icon("heart"), Rect2(8, 8, 56, 56)))
	var tw: = r.size.x - 70.0 - 12.0
	var name_s: String = G.HEROES[h].name
	var fs: = 22
	while fs > 16 and UI.font("body", 900).get_string_size(name_s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > tw:
		fs -= 1
	var nm: = UI.label(name_s, fs, UI.INK, UI.DARK, 3, "body", 900)
	nm.position = Vector2(70, 8)
	nm.size = Vector2(tw, 28)
	nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	aff_root.add_child(nm)
	var lv: = UI.label("Симпатия %d" % G.aff_level(h), 17, Color("ffd2de"), UI.DARK, 3, "body", 900)
	lv.position = Vector2(70, 36)
	lv.size = Vector2(tw, 24)
	lv.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	aff_root.add_child(lv)
	Common.progress_bar(aff_root, Rect2(14, 66, r.size.x - 28, 14), float(int(G.S.aff.get(h, 0)) % 100) / 100.0, "pink")
	var left: = G.pet_left()
	var pet_s: String = V6Txt.s("home.pet_left") % left if left > 0 else V6Txt.s("home.pet_done")
	var ps: = 16
	while ps > 13 and UI.font("body", 800).get_string_size(pet_s, HORIZONTAL_ALIGNMENT_LEFT, -1, ps).x > r.size.x - 28:
		ps -= 1
	var pl: = UI.label(pet_s, ps, Color("8a4a6a"))
	pl.position = Vector2(14, 84)
	pl.size = Vector2(r.size.x - 28, 24)
	pl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	aff_root.add_child(pl)

func _say(text: String) -> void :
	if bubble:
		bubble.queue_free()
	var head: = hero.head_global()
	bubble = Common.bubble(self, text, Vector2(114, maxf(head.y - 250, 140.0)), 300, false)
	var b: = bubble
	var t: Tween = b.create_tween()
	t.tween_interval(3.8)
	t.tween_property(b, "modulate:a", 0.0, 0.3)
	t.tween_callback(b.queue_free)

# 0.8 (main.toast): home toasts live in the speech-bubble band between the left icon column and the right cards,
# so they never cover the league / event cards; the bubble steps aside while a toast is up
func v8_toast_rect() -> Rect2:
	var x0: = 112.0
	var x1: = W - CARD_W - 16.0 - 10.0
	return Rect2(x0, 186.0, x1 - x0, 80.0)

func v8_toast_shown(dur: float) -> void :
	if bubble and is_instance_valid(bubble):
		var b: = bubble
		bubble = null
		var t: Tween = b.create_tween()
		t.tween_property(b, "modulate:a", 0.0, 0.12)
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
		"mail":
			open_mail()
		"back":
			main.android_back()
		"pet":
			on_hero_tap()
		"toast":
			main.toast("Тайник найден: Особая минута · 2 из 10", "star")
		"cameo":
			V7Eggs._cameo(self, "yue", false)
		"blink":
			hero.set_process(false)
			hero.mat.set_shader_parameter("blink", 1.0)
