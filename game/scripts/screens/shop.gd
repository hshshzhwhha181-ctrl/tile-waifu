extends Control



var main
var W: = 720.0
var H: = 1280.0
var tab: = 0
var body: Control
var tab_btns: Array = []
var pass_btn: JButton

const PACKS: = [
	{"gems": 60, "price": "79 ₽", "n": 1}, 
	{"gems": 330, "price": "379 ₽", "n": 2}, 
	{"gems": 1090, "price": "1 190 ₽", "n": 3}, 
	{"gems": 2240, "price": "2 290 ₽", "n": 4, "best": true}, 
	{"gems": 3880, "price": "3 790 ₽", "n": 5}, 
	{"gems": 8080, "price": "7 490 ₽", "n": 6}, 
]
const TABS: = ["Витрина", "Наряды", "Кристаллы"]

func build(m, args: Dictionary) -> void :
	main = m
	W = size.x
	H = size.y
	tab = int(args.get("tab", 0))
	main.show_chrome(true, true)
	Sfx.music("menu")
	Common.backdrop(self, "menu", size, 2.4, 0.9)
	Common.vignette(self, size, Color(0.4, 0.15, 0.3), 0.4)
	Fx.ambient(self, "petals", size)
	var tw: = (W - 48 - 20) / 3.0
	for i in 3:
		var b: = JButton.make(TABS[i], "pink" if i == tab else "glass", Rect2(24 + i * (tw + 10), 124, tw, 62), null, 23)
		var idx: = i
		b.pressed.connect( func(): _set_tab(idx))
		add_child(b)
		tab_btns.append(b)
	_build_body()

func _set_tab(i: int) -> void :
	if i == tab:
		return
	tab = i
	for k in 3:
		var b: JButton = tab_btns[k]
		var pal: = "pink" if k == tab else "glass"
		b.box.colors(UI.PAL[pal][0], UI.PAL[pal][1])
		b.lbl.label_settings.font_color = Color.WHITE if k == tab else UI.PAL.glass[2]
	_build_body()

func _build_body() -> void :
	if body:
		body.queue_free()
	body = Control.new()
	body.size = size
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(body)
	match tab:
		0: _recommended()
		1: _outfits()
		2: _gems()
	var note: = UI.center_label(UI.label(V6Txt.s("shop.test_note"), 15, Color.WHITE, Color(0.3, 0.1, 0.25), 3), Rect2(0, H - 132 - 66, W, 24))
	body.add_child(note)


func _recommended() -> void :
	var y: = 204.0

	var mc: = UI.rbox("sky", Rect2(18, y, W - 36, 236), 30, 5, 14)
	body.add_child(mc)
	var gl: = Sprite2D.new()
	gl.texture = G.fx("glow")
	gl.material = Fx.add_mat()
	gl.position = Vector2(110, 118)
	gl.scale = Vector2(2.6, 2.6)
	gl.modulate = Color(0.8, 0.9, 1, 0.8)
	mc.add_child(gl)
	for k in 3:
		var gi: = UI.tex(G.icon("gem"), Rect2(40 + k * 34, 60 + (k % 2) * 18, 96, 96))
		mc.add_child(gi)
	mc.add_child(UI.center_label(UI.title(V6Txt.s("shop.month_days"), 26, Color.WHITE, Color("1d4a7a")), Rect2(16, 168, 190, 40)))
	var t1: = UI.title(V6Txt.s("shop.month"), 34, Color.WHITE, Color("1d4a7a"))
	t1.position = Vector2(226, 14)
	mc.add_child(t1)
	var lines: = [V6Txt.s("shop.month_1"), V6Txt.s("shop.month_2"), V6Txt.s("shop.month_3")]
	for i in lines.size():
		var l: = UI.label(lines[i], 19, Color.WHITE, Color("1d4a7a"), 4, "body", 900)
		l.position = Vector2(228, 66 + i * 30)
		mc.add_child(l)
	var days: = G.month_card_days()
	var mb: JButton
	if days <= 0:
		mb = JButton.make("449 ₽", "gold", Rect2(228, 160, W - 36 - 250, 62), null, 28)
		mb.shine_every = 2.4
		mb.pressed.connect( func():
			G.S.month_card = {"until": Time.get_date_string_from_unix_time(int(Time.get_unix_time_from_system()) + 30 * 86400), "last": G.today()}
			G.S.gems += 300
			G.save()
			main.fly_gems(mb.get_global_rect().get_center(), 8)
			main.toast(V6Txt.s("shop.month_on"), "calendar")
			_build_body())
	else:
		var can: bool = G.S.month_card.get("last", "") != G.today()
		mb = JButton.make(V6Txt.s("shop.month_claim") if can else V6Txt.s("shop.month_active") % days, "mint" if can else "glass", Rect2(228, 160, W - 36 - 250, 62), G.icon("gem") if can else null, 26)
		mb.pressed.connect( func():
			if G.S.month_card.get("last", "") == G.today():
				main.toast(V6Txt.s("shop.month_got"), "calendar")
				return
			G.S.month_card.last = G.today()
			G.S.gems += 90
			G.save()
			main.fly_gems(mb.get_global_rect().get_center(), 5)
			_build_body())
	mc.add_child(mb)
	UI.pop_in(mc, 0.0, 0.9)

	y += 254
	var pc: = UI.rbox("lav", Rect2(18, y, W - 36, 270), 30, 5, 14)
	body.add_child(pc)
	var art: = Common.card_art(G.art_tex(G.ITEM["y_ball"]), Rect2(10, 10, 196, 250), Vector2(0.5, 0.3), 1.0, 22)
	(art.material as ShaderMaterial).set_shader_parameter("holo", 0.4)
	pc.add_child(art)
	var st: = UI.rbox("gold", Rect2(0, 222, 120, 34), 12, 2, 6)
	pc.add_child(st)
	st.add_child(UI.center_label(UI.label(V6Txt.s("shop.pass_final"), 16, Color.WHITE, Color("7a4a0c"), 3), Rect2(0, 0, 120, 34)))
	var t2: = UI.title(V6Txt.s("shop.pass"), 34, Color.WHITE, Color("3f2a7a"))
	t2.position = Vector2(226, 14)
	pc.add_child(t2)
	var pl: = UI.label(V6Txt.s("shop.pass_d"), 19, Color.WHITE, Color("3f2a7a"), 4, "body", 900)
	pl.position = Vector2(228, 64)
	pc.add_child(pl)
	var tier: = G.pass_tier()
	var tl: = UI.label(V6Txt.s("shop.pass_tier") % tier, 19, Color("fff3c4"), Color("3f2a7a"), 4, "body", 900)
	tl.position = Vector2(228, 128)
	pc.add_child(tl)
	Common.progress_bar(pc, Rect2(228, 160, W - 36 - 250, 20), float(tier) / 30.0, "gold")
	pass_btn = JButton.make(V6Txt.s("shop.pass_open") if G.S.pass.owned else V6Txt.s("shop.pass_more"), "gold" if not G.S.pass.owned else "pink", Rect2(228, 194, W - 36 - 250, 62), null, 24)
	pass_btn.shine_every = 2.8
	pass_btn.pressed.connect( func(): pass_popup())
	pc.add_child(pass_btn)
	UI.pop_in(pc, 0.08, 0.9)

	y += 288
	if not G.owns("o_dragon"):
		var fr: = UI.rbox("rose", Rect2(18, y, W - 36, 150), 28, 5, 12)
		body.add_child(fr)
		var a2: = Common.card_art(G.art_tex(G.ITEM["o_dragon"]), Rect2(8, 8, 130, 134), Vector2(0.5, 0.25), 1.0, 20)
		fr.add_child(a2)
		var sale: = UI.rbox("red", Rect2(-8, 10, 84, 34), 12, 3, 6)
		fr.add_child(sale)
		sale.add_child(UI.center_label(UI.label("−70%", 19, Color.WHITE, Color("6a1020"), 4), Rect2(0, 0, 84, 34)))
		var t3: = UI.title(V6Txt.s("shop.newbie"), 28, Color.WHITE, Color("7a2346"))
		t3.position = Vector2(156, 12)
		fr.add_child(t3)
		var l3: = UI.label(V6Txt.s("shop.newbie_d"), 17, Color.WHITE, Color("7a2346"), 4, "body", 900)
		l3.position = Vector2(158, 58)
		l3.size = Vector2(W - 36 - 176, 26)
		l3.clip_text = true
		fr.add_child(l3)
		var b3: = JButton.make("149 ₽", "gold", Rect2(158, 88, 220, 52), null, 24)
		b3.pressed.connect( func():
			G.S.gems += 1200
			G.give("o_dragon")
			G.save()
			main.fly_gems(b3.get_global_rect().get_center(), 8)
			main.toast(V6Txt.s("shop.newbie_got"), "gift")
			_build_body())
		fr.add_child(b3)
		UI.pop_in(fr, 0.16, 0.9)
		y += 168

	if not G.S.first_buy.has("first"):
		var fb: = UI.rbox("mint", Rect2(18, y, W - 36, 120), 28, 5, 12)
		body.add_child(fb)
		fb.add_child(UI.tex(G.icon("gift"), Rect2(10, 6, 108, 108)))
		var t4: = UI.title(V6Txt.s("shop.first"), 28, Color.WHITE, Color("1f5e49"))
		t4.position = Vector2(132, 10)
		fb.add_child(t4)
		var l4: = UI.label(V6Txt.s("shop.first_d"), 17, Color.WHITE, Color("1f5e49"), 4, "body", 900)
		l4.position = Vector2(134, 52)
		fb.add_child(l4)
		var b4: = JButton.make("79 ₽", "gold", Rect2(W - 36 - 186, 62, 170, 50), null, 24)
		b4.pressed.connect( func():
			G.S.first_buy["first"] = true
			_buy(300, b4))
		fb.add_child(b4)
		UI.pop_in(fb, 0.22, 0.9)


func pass_popup() -> void :
	var p: = Common.popup(main, V6Txt.s("shop.pass"), 880, "cream")
	var tier: = G.pass_tier()
	var owned: bool = G.S.pass.owned
	var claimed: = int(G.S.pass.claimed)
	var hl: = UI.label(V6Txt.s("shop.pass_head") % tier, 19, UI.INK, Color.WHITE, 3, "body", 900)
	hl.position = Vector2(30, 52)
	p.add_child(hl)
	Common.progress_bar(p, Rect2(30, 86, 600, 22), float(int(G.S.pass.xp) % 100) / 100.0, "gold")
	var cw: = 94.0
	for k in range(1, 31):
		var i: = k - 1
		var x: = 24.0 + (i % 6) * (cw + 8)
		var y: = 126.0 + (i / 6) * 120
		var r: = _pass_reward(k)
		var reached: = k <= tier
		var got: = k <= claimed
		var pal: = "mint" if got else ("gold" if reached else "glass")
		if k == 30:
			pal = "lav"
		var c: = UI.rbox(pal, Rect2(x, y, cw, 110), 16, 3, 6)
		p.add_child(c)
		c.add_child(UI.center_label(UI.label(str(k), 15, UI.INK, Color.WHITE, 3, "body", 900), Rect2(0, 2, cw, 20)))
		if r.has("item"):
			var a: = Common.card_art(G.art_tex(G.ITEM[r.item]), Rect2(6, 22, cw - 12, 82), Vector2(0.5, 0.25), 1.0, 10)
			(a.material as ShaderMaterial).set_shader_parameter("holo", 0.5)
			c.add_child(a)
		else:
			c.add_child(UI.tex(G.icon("gem" if r.has("gems") else "coin"), Rect2(16, 22, cw - 32, cw - 32)))
			c.add_child(UI.center_label(UI.label(UI.fmt(r.get("gems", r.get("coins", 0))), 16, Color("f2799f") if r.has("gems") else Color("c58a2c"), Color.WHITE, 3, "body", 900), Rect2(0, 82, cw, 24)))
		if got:
			c.add_child(UI.center_label(UI.label("✓", 30, Color.WHITE, Color("1f5e49"), 4), Rect2(0, 20, cw, 60)))
		if not reached:
			c.modulate = Color(1, 1, 1, 0.7)
	var ready: = tier - claimed
	var b: JButton
	if not owned:
		b = JButton.make(V6Txt.s("shop.pass_buy"), "gold", Rect2(60, 760, 540, 96), null, 28)
		b.shine_every = 2.0
		b.pressed.connect( func():
			G.S.pass.owned = true
			G.save()
			main.toast(V6Txt.s("shop.pass_on"), "ticket")
			Common.close_popup(p)
			_build_body())
	else:
		b = JButton.make(V6Txt.s("shop.pass_claim") % ready if ready > 0 else V6Txt.s("shop.pass_grow"), "pink" if ready > 0 else "glass", Rect2(60, 760, 540, 96), null, 28)
		b.pressed.connect( func():
			var n: = G.pass_tier()
			for k in range(int(G.S.pass.claimed) + 1, n + 1):
				var r: = _pass_reward(k)
				if r.has("gems"):
					G.S.gems += int(r.gems)
				if r.has("coins"):
					G.S.coins += int(r.coins)
				if r.has("item"):
					G.give(r.item)
			if n > int(G.S.pass.claimed):
				main.fly_gems(b.get_global_rect().get_center(), 8)
			G.S.pass.claimed = n
			G.save()
			Common.close_popup(p)
			_build_body())
	p.add_child(b)

func _pass_reward(k: int) -> Dictionary:
	if k == 30:
		return {"item": "y_ball"}
	if k % 10 == 0:
		return {"gems": 300}
	if k % 5 == 0:
		return {"coins": 1000}
	return {"gems": 60}


func _outfits() -> void :
	var list: Array = G.ITEMS.filter( func(x): return x.has("shop"))
	var cw: = (W - 36 - 16) / 2.0
	var ch: = (H - 132 - 40 - 210) / 2.0 - 8
	for i in list.size():
		var it: Dictionary = list[i]
		var r: = Rect2(18 + (i % 2) * (cw + 16), 206 + (i / 2) * (ch + 14), cw, ch)
		var own: bool = G.owns(it.id)
		var c: = UI.rbox("gold" if it.rar == "SSR" else "lav", r, 26, 5, 12)
		c.mouse_filter = Control.MOUSE_FILTER_STOP
		body.add_child(c)
		var art: = Common.card_art(G.art_tex(it), Rect2(8, 8, cw - 16, ch - 16), Vector2(0.5, 0.3), 1.0, 20)
		(art.material as ShaderMaterial).set_shader_parameter("holo", 0.35 if it.rar == "SSR" else 0.0)
		(art.material as ShaderMaterial).set_shader_parameter("bottom_shade", 0.95)
		c.add_child(art)
		var rl: = UI.label(it.rar, 26, Color.WHITE, G.rar_color(it.rar).darkened(0.5), 5, "title", 900)
		rl.position = Vector2(16, 10)
		c.add_child(rl)
		var nl: = UI.label(it.name, 22, Color.WHITE, Color(0.2, 0.05, 0.2), 5, "body", 900)
		nl.position = Vector2(16, ch - 128)
		c.add_child(nl)
		var hl: = UI.label(G.HEROES[it.hero].name + (V6Txt.s("shop.animated") if it.rar == "SSR" else ""), 17, Color("ffe7a6"), Color(0.2, 0.05, 0.2), 4, "body", 900)
		hl.position = Vector2(16, ch - 96)
		c.add_child(hl)
		var b: = JButton.make(V6Txt.s("shop.owned") if own else UI.fmt(it.shop), "mint" if own else "pink", Rect2(14, ch - 66, cw - 28, 54), null if own else G.icon("gem"), 24)
		b.pressed.connect( func(): _buy_outfit(it, b))
		c.add_child(b)
		UI.pop_in(c, 0.05 * i, 0.85)

func _buy_outfit(it: Dictionary, b: JButton) -> void :
	if G.owns(it.id):
		main.toast(V6Txt.s("shop.owned_toast"), "wardrobe")
		return
	if int(G.S.gems) < int(it.shop):
		main.toast(V6Txt.s("common.need_gems") % UI.fmt(it.shop), "gem")
		_set_tab(2)
		return
	G.S.gems -= int(it.shop)
	G.give(it.id)
	G.save()
	main.refresh_currency(true)
	Sfx.play("reveal_sr")
	Fx.burst(self, b.get_global_rect().get_center(), "sparkle", 40, Color(1, 0.85, 0.6), 1.4)
	Sfx.say(it.hero, "outfit")
	main.toast(V6Txt.s("shop.bought") % it.name, "wardrobe")
	_build_body()


func _gems() -> void :
	var gy: = 206.0
	var cw: = (W - 36 - 24) / 3.0
	var chh: = 250.0
	for i in PACKS.size():
		var p: Dictionary = PACKS[i]
		var r: = Rect2(18 + (i % 3) * (cw + 12), gy + (i / 3) * (chh + 16), cw, chh)
		var c: = UI.rbox("cream" if not p.get("best", false) else "rose", r, 24, 4, 12)
		c.set_param("pattern", 1.0)
		body.add_child(c)
		var glow: = Sprite2D.new()
		glow.texture = G.fx("glow")
		glow.material = Fx.add_mat()
		glow.position = Vector2(cw * 0.5, 80)
		glow.scale = Vector2(2.0, 1.6)
		glow.modulate = Color(1, 0.7, 0.85, 0.7)
		c.add_child(glow)
		var n: int = p.n
		for k in n:
			var ang: = (float(k) - (n - 1) * 0.5) * 0.32
			var gs: = 72.0 - n * 3.0
			var gx: = cw * 0.5 - gs * 0.5 + sin(ang) * 46.0
			var gyy: = 60.0 - cos(ang) * 22.0 + (k % 2) * 10.0
			var gi: = UI.tex(G.icon("gem"), Rect2(gx, gyy, gs, gs))
			gi.pivot_offset = Vector2(gs, gs) * 0.5
			gi.rotation = ang * 0.5
			c.add_child(gi)
		var first: bool = not G.S.first_buy.has(str(i))
		var gl: = UI.center_label(UI.title(UI.fmt(p.gems), 32, Color("f2799f"), Color.WHITE), Rect2(0, 128, cw, 40))
		c.add_child(gl)
		if first:
			var b: = UI.rbox("mint", Rect2(cw - 92, -10, 100, 30), 12, 2, 6)
			c.add_child(b)
			b.add_child(UI.center_label(UI.label(V6Txt.s("shop.x2"), 15, Color.WHITE, Color("1f5e49"), 3, "body", 900), Rect2(0, 0, 100, 30)))
			var bl: = UI.center_label(UI.label(V6Txt.s("shop.bonus") % UI.fmt(p.gems), 16, Color("1f8a62"), Color.WHITE, 3, "body", 900), Rect2(0, 166, cw, 24))
			c.add_child(bl)
		if p.get("best", false):
			var bb: = UI.rbox("pink", Rect2(-6, -12, 90, 30), 12, 2, 6)
			c.add_child(bb)
			bb.add_child(UI.center_label(UI.label(V6Txt.s("shop.hit"), 16, Color.WHITE, Color("7a2346"), 3, "body", 900), Rect2(0, 0, 90, 30)))
		var pb: = JButton.make(p.price, "pink", Rect2(10, chh - 60, cw - 20, 50), null, 22)
		var gems: int = p.gems
		var idx: = i
		pb.pressed.connect( func():
			var bonus: bool = not G.S.first_buy.has(str(idx))
			G.S.first_buy[str(idx)] = true
			_buy(gems * (2 if bonus else 1), pb))
		c.add_child(pb)
		UI.pop_in(c, 0.04 + i * 0.05, 0.8)

	var dy: = gy + 2 * (chh + 16)
	var d: = UI.rbox("mint", Rect2(18, dy, W - 36, 96), 26, 4, 12)
	body.add_child(d)
	d.add_child(UI.tex(G.icon("gift"), Rect2(10, 4, 88, 88)))
	var dl: = UI.label(V6Txt.s("shop.gift"), 22, Color.WHITE, Color("1f5e49"), 5, "body", 900)
	dl.position = Vector2(108, 16)
	d.add_child(dl)
	var ds: = UI.label(V6Txt.s("shop.gift_d"), 17, Color("eafff6"), Color("1f5e49"), 3)
	ds.position = Vector2(108, 52)
	d.add_child(ds)
	var claimed: bool = G.S.get("gift_day", "") == G.today()
	var cb: = JButton.make(V6Txt.s("common.claim") if not claimed else V6Txt.s("common.tomorrow"), "gold" if not claimed else "glass", Rect2(W - 36 - 176, 18, 160, 60), null, 24)
	cb.pressed.connect( func():
		if G.S.get("gift_day", "") == G.today():
			main.toast(V6Txt.s("shop.gift_got"), "gift")
			return
		G.S.gift_day = G.today()
		G.S.gems += 50
		G.save()
		main.fly_gems(cb.get_global_rect().get_center(), 5))
	d.add_child(cb)
	UI.slide_in(d, Vector2(0, 40), 0.4)

func _buy(gems: int, from: Control) -> void :
	G.S.gems += gems
	G.save()
	Sfx.play("win", 1.2, -6)
	Fx.burst(self, from.get_global_rect().get_center(), "sparkle", 30, Color(1, 0.8, 0.9), 1.2)
	main.fly_gems(from.get_global_rect().get_center(), 8)
	main.toast(V6Txt.s("shop.gems_got") % UI.fmt(gems), "gem")
	_build_body()

func dev_act(a: String) -> void :
	match a:
		"t1": _set_tab(1)
		"t2": _set_tab(2)
		"pass": pass_popup()
