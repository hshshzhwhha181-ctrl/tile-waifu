extends Control



var main
var W: = 720.0
var H: = 1280.0
var h: = "mc"
var root: Control
var hero: Hero
var bubble: Control
var panel: Control
var actions: Control

const TABS_Y: = V8Header.CONTENT_Y + 6.0
const PANEL_Y: = TABS_Y + 118.0

func build(m, args: Dictionary) -> void :
	main = m
	W = size.x
	H = size.y
	main.show_chrome(true, true)
	Sfx.music("menu")
	var a: = _dev()
	if a.has("room_hero"):
		G.S.shards[a.room_hero] = G.SHARDS_NEED
	if a.has("room_aff"):
		var dh: String = a.get("room_hero", G.S.partner)
		G.S.aff[dh] = int(a.room_aff)
	h = str(args.get("hero", a.get("room_hero", G.S.partner)))
	if not G.HEROES.has(h) or not G.hero_unlocked(h):
		h = "mc"
	V7RoomData.st()
	_render(true)

static func _dev() -> Dictionary:
	var a: = {}
	for s in OS.get_cmdline_user_args():
		if s.begins_with("--") and "=" in s:
			var kv: = s.substr(2).split("=", true, 1)
			a[kv[0]] = kv[1]
	return a

func _render(greet: = false) -> void :
	if root:
		root.queue_free()
	bubble = null
	root = Control.new()
	root.size = size
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var rm: Dictionary = V7RoomData.ROOMS[h]
	V7RoomScene.backdrop(root, rm.bg, size, rm.focus, 0.92)
	Common.vignette(root, size, Color(0.1, 0.04, 0.08), 0.55)
	if rm.fx != "":
		Fx.ambient(root, rm.fx, size)

	var floor_y: = H - 140.0
	var ped: = Sprite2D.new()
	ped.texture = G.fx("glow")
	ped.material = Fx.add_mat()
	ped.position = Vector2(W * 0.6, floor_y - 10)
	ped.scale = Vector2(5.0, 1.0)
	ped.modulate = Color(G.HEROES[h].color, 0.45)
	root.add_child(ped)
	hero = Hero.new().setup(h, H * 0.6)
	hero.position = Vector2(W * 0.6, floor_y)
	root.add_child(hero)
	hero.tapped.connect(_on_hero_tap)
	UI.slide_in(hero, Vector2(40, 40), 0.05, 0.55)
	# 0.8: the fade is all but opaque by the top of the action row and stays solid under it down to the navbar,
	# so no shoe or sole shows between «Подарок» / «Свидание» / «Сцены» or under them
	Common.floor_fade(root, H - 560.0, H - 262.0, Color(0.07, 0.045, 0.07), 0.95)
	var band: = ColorRect.new()
	band.color = Color(0.07, 0.045, 0.07, 0.95)
	band.position = Vector2(0, H - 262.0)
	band.size = Vector2(W, 262.0)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(band)
	V8Header.make(root, main, "Комната", main.back)
	set_meta("v8_back", main.back)
	_tabs()
	_panel()
	_actions()
	if greet:
		await get_tree().create_timer(0.8).timeout
		if is_inside_tree() and hero:
			_say(Sfx.say(h, "greet"))


func _tabs() -> void :
	var n: = G.HERO_ORDER.size()
	var step: = 104.0
	var x0: = (W - step * n) * 0.5 + 12
	for i in n:
		var id: String = G.HERO_ORDER[i]
		var sel: = id == h
		var open: = G.hero_unlocked(id)
		var d: = 84.0 if sel else 70.0
		var c: = Control.new()
		c.position = Vector2(x0 + i * step + (84 - d) * 0.5, TABS_Y + (84 - d) * 0.5)
		c.size = Vector2(d, d + 26)
		c.pivot_offset = Vector2(d * 0.5, d * 0.5)
		c.mouse_filter = Control.MOUSE_FILTER_STOP
		root.add_child(c)
		var av: = Common.avatar(id, Rect2(0, 0, d, d), "gold" if sel else "glass")
		c.add_child(av)
		if not open:
			av.modulate = Color(0.35, 0.33, 0.38)
			c.add_child(V8Art.rect(V8Art.icon("lock"), Rect2(d * 0.26, d * 0.26, d * 0.48, d * 0.48)))
		elif V7RoomData.fresh_scenes(id).size() > 0:
			Common.badge(c, 0, Vector2(d - 22, -4))
		var nm: = UI.center_label(UI.label(G.HEROES[id].name, 16 if not sel else 17, Color("ffe7a6") if sel else UI.INK, UI.DARK, 4, "body", 900), Rect2(-20, d - 4, d + 40, 26))
		c.add_child(nm)
		UI.slide_in(c, Vector2(0, -24), 0.03 * i, 0.35)
		c.gui_input.connect( func(e):
			if e is InputEventMouseButton and e.pressed:
				_pick(id, c))

func _pick(id: String, c: Control) -> void :
	if id == h:
		_on_hero_tap()
		return
	if not G.hero_unlocked(id):
		V9Feel.deny(c)
		main.toast("%s ещё не вернулась. Собери её портрет или загадай Желание." % G.HEROES[id].name, "lock")
		return
	V9Feel.press(c)
	h = id
	_render(true)


func _panel() -> void :
	var r: = Rect2(16, PANEL_Y, 356, 214)
	panel = UI.rbox("glass", r, 26, 3, 12)
	panel.borders(Color("f3dca0"), Color("8a6424"))
	root.add_child(panel)
	var col: Color = G.HEROES[h].color
	var nm: = UI.title(G.HEROES[h].name, 34, Color("fff1dc"), col.darkened(0.6))
	nm.position = Vector2(18, 8)
	nm.size = Vector2(320, 48)
	panel.add_child(nm)
	var rm: = UI.label(V7RoomData.ROOMS[h].name, 16, Color("d8c8b8"))
	rm.position = Vector2(20, 56)
	panel.add_child(rm)
	var lv: = G.aff_level(h)
	var bt: = UI.label("%s · симпатия %d" % [V7RoomData.bond_title(h), lv], 20, Color("ffd2de"), UI.DARK, 3, "body", 900)
	bt.position = Vector2(56, 84)
	bt.size = Vector2(290, 28)
	panel.add_child(bt)
	panel.add_child(V8Art.rect(V8Art.icon("heart"), Rect2(12, 80, 38, 38)))
	var aff: = int(G.S.aff.get(h, 0))
	var frac: = 1.0 if lv >= 10 else float(aff % 100) / 100.0
	Common.progress_bar(panel, Rect2(20, 120, 316, 20), frac, "pink")
	var pv: = UI.label("макс." if lv >= 10 else "%d / 100" % (aff % 100), 16, Color.WHITE, UI.DARK, 3, "body", 900)
	pv.position = Vector2(20, 120)
	pv.size = Vector2(316, 20)
	pv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pv.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(pv)
	var nx: = _fit_label(V7RoomData.next_unlock(h), 16, Color("ffe7a6"), 320.0)
	nx.position = Vector2(20, 148)
	nx.size = Vector2(320, 24)
	panel.add_child(nx)
	var bt2: = V6Heroines.bond_text(h)
	var perk: = _fit_label("За столом: " + bt2.substr(bt2.find("·") + 2) if "·" in bt2 else "Симпатия 4 / 7 / 10 ускоряет её умение", 16, Color("cfc3d8"), 320.0)
	perk.position = Vector2(20, 174)
	perk.size = Vector2(320, 24)
	panel.add_child(perk)
	UI.slide_in(panel, Vector2(-40, 0), 0.08, 0.4)


# shrinks the font (never below 16 px) instead of cutting the text; ellipsis only as a last resort.
func _fit_label(text: String, fs: int, col: Color, w: float) -> Label:
	var f: = UI.font("body", 800)
	while fs > 16 and f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > w:
		fs -= 1
	var l: = UI.label(text, fs, col)
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


func _actions() -> void :
	if actions:
		actions.queue_free()
	actions = Control.new()
	actions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	actions.size = size
	root.add_child(actions)
	var bw: = (W - 32 - 24) / 3.0
	# 0.9: the row sits 16 px higher, so the centre nav star (it rises above the nav bar) clears the button rims
	var y: = H - 132 - 150.0
	var left: = V7RoomData.gifts_left(h)
	var g: = _btn("Подарок", "сегодня ещё %d" % left if left > 0 else "завтра снова", "rose", Rect2(16, y, bw, 108), "gift")
	g.pressed.connect(_gift_popup)
	actions.add_child(g)
	var inv: = V7RoomData.invites()
	# 0.9: a short sub-line («ещё 2», like the gift's «сегодня ещё 3»): «2 приглашения» ran into the sakura cap
	var d: = _btn("Свидание", "ещё %d" % inv if inv > 0 else "завтра снова", "gold", Rect2(16 + bw + 12, y, bw, 108), "heart")
	d.pressed.connect(_date_popup)
	if inv > 0:
		d.shine_every = 3.2
	actions.add_child(d)
	var ids: = V7RoomScenes.for_hero(h)
	var opened: = ids.filter( func(id): return G.aff_level(h) >= int(V7RoomScenes.SCENES[id].lv)).size()
	var s: = _btn("Сцены", "открыто %d из %d" % [opened, ids.size()], "glass", Rect2(16 + (bw + 12) * 2, y, bw, 108), "star")
	s.pressed.connect(_scenes_popup)
	var fresh: = V7RoomData.fresh_scenes(h).size()
	if fresh > 0:
		s.badge(str(fresh))
		s.pulse = true
	actions.add_child(s)
	for i in 3:
		UI.slide_in(actions.get_child(i), Vector2(0, 50), 0.1 + i * 0.05, 0.35)


func _btn(text: String, sub: String, pal: String, r: Rect2, icon: String) -> JButton:
	var b: = JButton.make(text, pal, r, null, 22)
	b.set_sub(sub, 16)
	# with the btn art the glyph sits inside the caps (clear of the gold rim and the sakura), as JButton's own icon
	var ix: = 10.0
	var isz: = 52.0
	var x1: = 8.0
	if b.art:
		# 0.8: glyph, caption and sub-line all stay inside nine_content(): clear of the sakura caps on both ends
		var cr: = V8Art.nine_content(b._art_name, r.size)
		ix = cr.position.x
		isz = 40.0
		# 0.9: a little extra air on the right so the caption and sub-line never touch the sakura cap
		x1 = r.size.x - cr.end.x + 8.0
	var x0: = ix + isz + 4.0
	b.lbl.position.x = x0
	if b.art:
		b.lbl.position.y += 3.0
	b.lbl.size.x = r.size.x - x0 - x1
	b._fit_label(b.lbl.size.x)
	UI.center_label(b.sub, Rect2(x0, b.sub.position.y, r.size.x - x0 - x1, b.sub.size.y))
	b.sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.sub.clip_text = true
	# 0.8: gift / heart / star are the gold glyphs of the 0.8 set (star = the sakura star, nav/play)
	b.add_child(V8Art.rect(Common.ui_icon(icon), Rect2(ix, (r.size.y - isz) * 0.5, isz, isz)))
	return b


func _on_hero_tap() -> void :
	hero.react("happy")
	Fx.burst(root, hero.head_global() + Vector2(0, -40), "heart", 6)
	var line: = V7RoomData.room_line(h)
	hero.talk_left = minf(0.4 + line.length() * 0.045, 4.0)
	_say(line)

func _say(text: String) -> void :
	if text == "" or not hero:
		return
	if bubble and is_instance_valid(bubble):
		bubble.queue_free()
	var head: = hero.head_global()
	bubble = Common.bubble(root, text, Vector2(16, PANEL_Y + 226), 300, false)
	var b: = bubble
	var t: Tween = b.create_tween()
	t.tween_interval(4.0)
	t.tween_property(b, "modulate:a", 0.0, 0.3)
	t.tween_callback(b.queue_free)


func _gain(n: int, at: Vector2) -> void :
	var old: = G.aff_level(h)
	G.add_aff(h, n)
	G.save()
	Fx.float_text(root, at, "+%d ♥" % n, Color("ffd0e0"), 42)
	Fx.burst(root, at, "heart", 14, Color(1, 0.75, 0.85))
	var nw: = G.aff_level(h)
	_refresh()
	if nw > old:
		await get_tree().create_timer(0.7).timeout
		_level_up(nw)

func _refresh() -> void :
	if panel:
		panel.queue_free()
	_panel()
	_actions()

func _level_up(lv: int) -> void :
	Sfx.play("win", 1.1, -4)
	Fx.burst(root, Vector2(W * 0.5, H * 0.35), "confetti", 40)
	hero.react("big")
	var scene_id: = "%s_%d" % [h, lv]
	if not V7RoomScenes.SCENES.has(scene_id):
		main.toast("Симпатия: %d · «%s»" % [lv, V7RoomData.bond_title(h)], "heart")
		return
	var sc: Dictionary = V7RoomScenes.SCENES[scene_id]
	var p: = Common.popup(main, "Симпатия %d" % lv, 420, "cream", 600)
	var t: = UI.center_label(UI.label("%s · «%s»" % [G.HEROES[h].name, V7RoomData.bond_title(h)], 26, Color("ffd2de"), UI.DARK, 3, "body", 900), Rect2(20, 54, 560, 40))
	p.add_child(t)
	var l: = UI.center_label(UI.label("Открыта сцена «%s»" % sc.title, 24, UI.INK), Rect2(20, 110, 560, 40))
	p.add_child(l)
	var g: = UI.center_label(UI.label("За первый просмотр: %d кристаллов" % V7RoomData.SCENE_GEMS.get(lv, 0), 18, Color("ffe7a6")), Rect2(20, 152, 560, 30))
	p.add_child(g)
	var watch: = JButton.make("Смотреть", "gold", Rect2(40, 230, 300, 96), null, 28)
	watch.pressed.connect( func():
		Common.close_popup(p)
		_play_scene(scene_id))
	p.add_child(watch)
	var later: = JButton.make("Позже", "glass", Rect2(356, 230, 204, 96), null, 24)
	later.pressed.connect( func(): Common.close_popup(p))
	p.add_child(later)


func _gift_popup() -> void :
	var p: = Common.popup(main, "Подарок · %s" % G.HEROES[h].name, 890, "cream", 680)
	var left: = V7RoomData.gifts_left(h)
	var info: = UI.center_label(UI.label("Сегодня можно подарить ещё %d · монеты: %s" % [left, UI.fmt(int(G.S.coins))], 18, Color("e9dcff")), Rect2(0, 48, 680, 30))
	p.add_child(info)
	var cw: = 200.0
	var ch: = 172.0
	for i in V7RoomData.GIFTS.size():
		var gd: Dictionary = V7RoomData.GIFTS[i]
		var r: = Rect2(24 + (i % 3) * (cw + 16), 92 + (i / 3) * (ch + 12), cw, ch)
		var card: = UI.rbox("graphite", r, 20, 2, 8)
		card.borders(Color("8a7458"), Color("4a3a28"))
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.pivot_offset = r.size * 0.5
		p.add_child(card)
		card.add_child(UI.tex(G.tile_tex(gd.tile), Rect2(cw * 0.5 - 44, 8, 88, 92)))
		var nm: = UI.center_label(UI.label(gd.name, 16, UI.INK, UI.DARK, 2, "body", 900), Rect2(4, 100, cw - 8, 26))
		nm.autowrap_mode = TextServer.AUTOWRAP_OFF
		nm.clip_text = true
		card.add_child(nm)
		var price: = Common.chip(card, V8Art.cur("coin"), UI.fmt(gd.price), Rect2(cw * 0.5 - 62, 130, 124, 32), "plum", 17)
		price.mouse_filter = Control.MOUSE_FILTER_IGNORE

		if V7RoomData.known(h, gd.id):
			var tst: = V7RoomData.taste(h, gd.id)
			var nh: = 2 if tst == "love" else (1 if tst == "like" else 0)
			for k in nh:
				card.add_child(V8Art.rect(V8Art.icon("heart"), Rect2(cw - 40 - k * 24, 6, 30, 30)))
			if nh == 0:
				var okl: = UI.label("ок", 16, Color("bfb3a8"), UI.DARK, 2, "body", 900)
				okl.position = Vector2(cw - 36, 8)
				card.add_child(okl)
		else:
			var q: = UI.label("?", 24, Color("ffe7a6"), UI.DARK, 3, "body", 900)
			q.position = Vector2(cw - 30, 2)
			card.add_child(q)
		var can: bool = left > 0 and int(G.S.coins) >= int(gd.price)
		if not can:
			card.modulate = Color(0.6, 0.58, 0.62)
		var gid: String = gd.id
		card.gui_input.connect( func(e):
			if e is InputEventMouseButton and e.pressed:
				if left <= 0:
					V9Feel.deny(card)
					main.toast("На сегодня подарков хватит. Завтра она будет ждать снова.", "gift")
				elif int(G.S.coins) < int(gd.price):
					V9Feel.deny(card)
					main.toast("Не хватает монет. Их дают за партии и поручения.", "coin")
				else:
					V9Feel.press(card)
					Common.confirm(main, "Подарок", "Подарить %s «%s»?" % [G.HEROES[h].name, gd.name], "coin", int(gd.price), func():
						Common.close_popup(p)
						_give(gid), {"yes_text": "Подарить"}))
	var hint: = UI.center_label(UI.label("Два сердца — любимое, одно — нравится. Вкус узнаёшь, когда подаришь.", 16, Color("cfc3d8")), Rect2(40, 92 + 4 * (ch + 12) + 6, 600, 26))
	Common.fit_line(hint, 600)
	p.add_child(hint)

func _give(gid: String) -> void :
	var gd: = V7RoomData.gift(gid)
	var s: = V7RoomData.st()
	G.S.coins = int(G.S.coins) - int(gd.price)
	s.gifts[h] = int(s.gifts.get(h, 0)) + 1
	var first: = not V7RoomData.known(h, gid)
	V7RoomData.mark("known", h, gid)
	main.refresh_currency()
	var tst: = V7RoomData.taste(h, gid)
	var n: int = {"love": V7RoomData.AFF_LOVE, "like": V7RoomData.AFF_LIKE, "plain": V7RoomData.AFF_PLAIN}[tst]

	var ic: = UI.tex(G.tile_tex(gd.tile), Rect2(W * 0.5 - 55, H - 300, 110, 114))
	ic.pivot_offset = Vector2(55, 57)
	root.add_child(ic)
	var to: = hero.head_global() + Vector2(-55, 60)
	var t: = ic.create_tween()
	t.tween_property(ic, "position", to, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(ic, "rotation", 0.3, 0.55)
	t.tween_property(ic, "scale", Vector2(0.2, 0.2), 0.2)
	t.parallel().tween_property(ic, "modulate:a", 0.0, 0.2)
	t.tween_callback(ic.queue_free)
	Sfx.play("sparkle", 1.1, -4)
	await t.finished
	if not is_inside_tree():
		return
	hero.react({"love": "big", "like": "happy", "plain": "tap"}[tst])
	if tst == "love":
		hero.flash(0.4)
	var lines: Array = V7RoomData.GIFT_LINES[h][tst]
	var line: String = lines[randi() % lines.size()]
	hero.talk_left = minf(0.4 + line.length() * 0.045, 4.0)
	_say(line)
	if first and tst != "plain":
		main.toast("Ты узнал: %s %s «%s»" % [G.HEROES[h].name, "обожает" if tst == "love" else "любит", gd.name], "heart")
	await _gain(n, hero.head_global() + Vector2(60, -80))


func _date_popup() -> void :
	var p: = Common.popup(main, "Свидание · %s" % G.HEROES[h].name, 940, "cream", 680)
	var inv: = V7RoomData.invites()
	var info: = UI.center_label(UI.label("Приглашений сегодня: %d · каждый день +%d" % [inv, V7RoomData.FREE_INVITES], 18, Color("e9dcff")), Rect2(0, 48, 680, 30))
	p.add_child(info)
	var cw: = 306.0
	var ch: = 168.0
	var ids: Array = V7RoomData.PLACE_ORDER
	for i in ids.size():
		var pid: String = ids[i]
		var pl: Dictionary = V7RoomData.PLACES[pid]
		var r: = Rect2(24 + (i % 2) * (cw + 20), 90 + (i / 2) * (ch + 12), cw, ch)
		if i == ids.size() - 1 and ids.size() % 2 == 1:
			r.position.x = (680 - cw) * 0.5
		var card: = Control.new()
		card.position = r.position
		card.size = r.size
		card.pivot_offset = r.size * 0.5
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		p.add_child(card)
		card.add_child(UI.rbox("gold" if V7RoomData.place_known(h, pid) and V7RoomData.FAV[h] == pid else "graphite", Rect2(Vector2.ZERO, r.size), 20, 3, 8))
		var art: = Common.card_art(load(pl.bg), Rect2(5, 5, cw - 10, ch - 10), pl.focus, 1.0, 16)
		(art.material as ShaderMaterial).set_shader_parameter("bottom_shade", 0.85)
		card.add_child(art)
		var nm: = UI.label(pl.name, 21, Color.WHITE, UI.DARK, 5, "body", 900)
		nm.position = Vector2(16, ch - 46)
		card.add_child(nm)
		if V7RoomData.place_known(h, pid) and V7RoomData.FAV[h] == pid:
			Common.chip(card, V8Art.icon("heart"), "Её любимое", Rect2(10, 10, 170, 32), "pink", 16).mouse_filter = Control.MOUSE_FILTER_IGNORE
		if V7RoomData.st().photos.get(h, {}).has(pid):
			var ph: = UI.rbox("glass", Rect2(cw - 70, 10, 58, 32), 12, 2, 4)
			card.add_child(ph)
			ph.add_child(UI.center_label(UI.label("фото", 16, Color("ffe7a6"), UI.DARK, 2, "body", 900), Rect2(0, 0, 58, 32)))
		card.gui_input.connect( func(e):
			if e is InputEventMouseButton and e.pressed:
				if V7RoomData.invites() <= 0:
					V9Feel.deny(card)
					main.toast("Приглашения закончились. Завтра будут новые.", "heart")
					return
				V9Feel.press(card)
				Common.close_popup(p)
				_go_date(pid))
	var yb: = 90 + 4 * (ch + 12) + 6.0
	var s: = V7RoomData.st()
	if inv <= 0 and int(s.get("bought", 0)) < V7RoomData.EXTRA_INVITES_MAX:
		var buy: = JButton.make("Ещё приглашение · %d" % V7RoomData.EXTRA_INVITE_GEMS, "gold", Rect2(150, yb, 380, 72), V8Art.cur("gem"), 22)
		buy.pressed.connect( func():
			Common.confirm(main, "Ещё приглашение", "Купить ещё одно приглашение на свидание на сегодня?", "gem", V7RoomData.EXTRA_INVITE_GEMS, func():
				if int(G.S.gems) < V7RoomData.EXTRA_INVITE_GEMS:
					Sfx.play("deny")
					main.toast("Не хватает кристаллов.", "gem")
					return
				G.S.gems = int(G.S.gems) - V7RoomData.EXTRA_INVITE_GEMS
				s.invites = int(s.invites) + 1
				s.bought = int(s.bought) + 1
				G.save()
				main.refresh_currency(true)
				Common.close_popup(p)
				_date_popup(), {"yes_text": "Купить"}))
		p.add_child(buy)
	else:
		p.add_child(UI.center_label(UI.label("Угадай её любимое место: там свидание теплее.", 16, Color("cfc3d8")), Rect2(0, yb + 10, 680, 26)))

func _go_date(pid: String) -> void :
	var s: = V7RoomData.st()
	s.invites = int(s.invites) - 1
	G.save()
	var data: = V7RoomData.build_date(h, pid)
	var r: Dictionary = await V7RoomScene.run(data)
	if not is_inside_tree():
		return
	var score: = int(r.score)
	var grade: = 0 if score >= 3 else (1 if score >= 2 else 2)
	var fav: bool = V7RoomData.FAV[h] == pid
	var fav_new: = fav and not V7RoomData.place_known(h, pid)
	V7RoomData.mark("places", h, pid)
	var aff: = 15 + score * 8 + (15 if fav else 0)
	var photo_new: bool = grade == 0 and not s.photos.get(h, {}).has(pid)
	if photo_new:
		V7RoomData.mark("photos", h, pid)
		G.S.gems = int(G.S.gems) + V7RoomData.PHOTO_GEMS
	G.save()
	main.refresh_currency(photo_new)
	_date_result(pid, grade, aff, fav, fav_new, photo_new)

func _date_result(pid: String, grade: int, aff: int, fav: bool, fav_new: bool, photo_new: bool) -> void :
	var titles: = ["Чудесное свидание", "Хорошее свидание", "Неловкое свидание"]
	V7RoomData.add_mail(h, V7RoomData.ENDINGS[h][grade], "date", pid)
	G.save()
	var p: = Common.popup(main, titles[grade], 560, "cream", 640)
	var av: = Common.avatar(h, Rect2(30, 60, 120, 120), "gold")
	p.add_child(av)
	var q: = UI.label("«%s»" % V7RoomData.ENDINGS[h][grade], 21, Color("fff1dc"))
	q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	q.position = Vector2(170, 56)
	q.size = Vector2(440, 140)
	p.add_child(q)
	var y: = 210.0
	var rows: = ["Симпатия +%d" % aff]
	if fav:
		rows.append("%s: её любимое место, +15" % V7RoomData.PLACES[pid].name if fav_new else "Любимое место, +15")
	if photo_new:
		rows.append("Новое фото в альбоме · +%d кристаллов" % V7RoomData.PHOTO_GEMS)
	for t in rows:
		p.add_child(UI.center_label(UI.label(t, 22, Color("ffd2de") if t == rows[0] else Color("ffe7a6"), UI.DARK, 3, "body", 900), Rect2(20, y, 600, 36)))
		y += 44
	var ok: = JButton.make("Вернуться в комнату", "gold", Rect2(120, 430, 400, 90), null, 26)
	ok.pressed.connect( func(): Common.close_popup(p))
	p.add_child(ok)
	p.get_meta("root").set_meta("on_close", func(): _after_date(aff))
	hero.react("big" if grade == 0 else ("happy" if grade == 1 else "sad"))

func _after_date(aff: int) -> void :
	if is_inside_tree():
		_gain(aff, hero.head_global() + Vector2(60, -80))


func _scenes_popup() -> void :
	var ids: = V7RoomScenes.for_hero(h)
	var p: = Common.popup(main, "Сцены · %s" % G.HEROES[h].name, 860, "cream", 680)
	var ph: = V7RoomData.photos(h)
	p.add_child(UI.center_label(UI.label("Симпатия открывает сцены · фото со свиданий: %d из %d" % [ph, V7RoomData.PLACE_ORDER.size()], 17, Color("e9dcff")), Rect2(0, 48, 680, 30)))
	var rh: = 166.0
	for i in ids.size():
		var id: String = ids[i]
		var sc: Dictionary = V7RoomScenes.SCENES[id]
		var lv: = int(sc.lv)
		var open: = G.aff_level(h) >= lv
		var seen: bool = V7RoomData.st().seen.has(id)
		var r: = Rect2(24, 92 + i * (rh + 12), 632, rh)
		var row: = Control.new()
		row.position = r.position
		row.size = r.size
		row.pivot_offset = r.size * 0.5
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		p.add_child(row)
		row.add_child(UI.rbox("gold" if open and not seen else "graphite", Rect2(Vector2.ZERO, r.size), 22, 3, 8))
		var tex: Texture2D = _scene_thumb(id)
		var th: = Common.card_art(tex, Rect2(8, 8, 230, rh - 16), Vector2(0.5, 0.3) if _scene_photo(id) != "" else Vector2(_scene_cg_focus(id), 0.45), 1.0, 16)
		(th.material as ShaderMaterial).set_shader_parameter("bottom_shade", 0.0)
		if not open:
			(th.material as ShaderMaterial).set_shader_parameter("gray", 1.0)
			th.modulate = Color(0.45, 0.42, 0.48)
		row.add_child(th)
		if not open:
			row.add_child(V8Art.rect(V8Art.icon("lock"), Rect2(98, rh * 0.5 - 28, 56, 56)))
		var tl: = UI.label(sc.title, 26, Color("fff1dc") if open else Color("a39a92"), UI.DARK, 3, "title", 800)
		tl.position = Vector2(256, 16)
		tl.size = Vector2(360, 40)
		tl.clip_text = true
		row.add_child(tl)
		var sub: = UI.label("Симпатия %d · %s" % [lv, V7RoomData.BOND[lv - 1]], 17, Color("ffd2de") if open else Color("8f8790"))
		sub.position = Vector2(258, 60)
		row.add_child(sub)
		var st_txt: = ""
		if not open:
			st_txt = "Откроется на симпатии %d" % lv
		elif not seen:
			st_txt = "Новая · +%d кристаллов" % V7RoomData.SCENE_GEMS.get(lv, 0)
		else:
			st_txt = "Пересмотреть"
		var stl: = UI.label(st_txt, 19, Color("ffe7a6") if open else Color("8f8790"), UI.DARK, 2, "body", 900)
		stl.position = Vector2(258, 100)
		row.add_child(stl)
		if open and not seen:
			var nb: = UI.rbox("red", Rect2(632 - 86, -10, 80, 28), 14, 2, 4)
			row.add_child(nb)
			nb.add_child(UI.center_label(UI.label("НОВОЕ", 16, Color.WHITE, Color("6a1020"), 2, "body", 900), Rect2(0, 0, 80, 28)))
		row.gui_input.connect( func(e):
			if e is InputEventMouseButton and e.pressed:
				if not open:
					V9Feel.deny(row)
					main.toast("Нужна симпатия %d. Подарки и свидания её поднимают." % lv, "heart")
					return
				V9Feel.press(row)
				Common.close_popup(p)
				_play_scene(id))

func _scene_photo(id: String) -> String:
	for e in V7RoomScenes.SCENES[id].lines:
		if e is Dictionary and e.has("photo"):
			return e.photo
	return ""

func _scene_cg_focus(id: String) -> float:
	for e in V7RoomScenes.SCENES[id].lines:
		if e is Dictionary and e.has("cg"):
			return float(e.get("focus", 0.5))
	return 0.5

func _scene_thumb(id: String) -> Texture2D:
	for e in V7RoomScenes.SCENES[id].lines:
		if e is Dictionary and e.has("photo") and G.ITEM.has(e.photo):
			return G.art_tex(G.ITEM[e.photo])
		if e is Dictionary and e.has("cg"):
			return load("res://assets/v07/room/%s.webp" % e.cg)
	var d: Dictionary = V7RoomScenes.to_play(id)
	return load(d.bg_path)

func _play_scene(id: String) -> void :
	var first: bool = not V7RoomData.st().seen.has(id)
	var r: Dictionary = await V7RoomScene.run(V7RoomScenes.to_play(id))
	if not is_inside_tree():
		return
	if r.skipped and first:

		_refresh()
		return
	if first:
		V7RoomData.st().seen[id] = true
		var gems: int = V7RoomData.SCENE_GEMS.get(int(V7RoomScenes.SCENES[id].lv), 0)
		G.S.gems = int(G.S.gems) + gems
		G.save()
		main.refresh_currency(true)
		main.fly_gems(Vector2(W * 0.5, H * 0.5), 8)
		main.toast("Воспоминание сохранено · +%d кристаллов" % gems, "gem")
		_render(false)
		if int(r.aff) > 0:
			_gain(int(r.aff), hero.head_global() + Vector2(60, -80))
	else:
		_refresh()

func dev_act(a: String) -> void :
	if a.begins_with("pick:"):
		h = a.substr(5)
		_render(false)
	elif a == "gift":
		_gift_popup()
	elif a.begins_with("give:"):
		_give(a.substr(5))
	elif a == "date":
		_date_popup()
	elif a.begins_with("date:"):
		_go_date(a.substr(5))
	elif a == "scenes":
		_scenes_popup()
	elif a.begins_with("scene:"):
		_play_scene(a.substr(6))
	elif a == "tap":
		_on_hero_tap()
	elif a == "close":
		for c in main.overlay.get_children():
			if c.has_meta("popup"):
				c.queue_free()
