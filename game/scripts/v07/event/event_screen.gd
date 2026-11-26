extends Control


var main
var W: = 720.0
var H: = 1280.0
var def: = {}
var tab: = "map"
var body: Control
var cur_lbl: Label
var tab_btns: = {}
var node_btns: Array = []

const CARD_Y: = V8Header.CONTENT_Y + 8.0
const CARD_H: = 172.0
const TABS_Y: = CARD_Y + CARD_H + 12.0
const BODY_Y: = TABS_Y + 62.0 + 14.0

func build(m, args: Dictionary) -> void :
	main = m
	W = size.x
	H = size.y
	main.show_chrome(true, true)
	Sfx.music("menu")
	def = V7EventData.cur_def()
	var ev: = V7EventData.st()
	tab = args.get("tab", "map")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--event_tab="):
			tab = a.substr(12)
	Common.backdrop(self, def.bg, size, 2.4, 0.6, def.tint)
	Fx.ambient(self, def.fx, size)
	Common.vignette(self, size, Color(0.1, 0.04, 0.12), 0.6)
	V8Header.make(self, main, def.name, main.back, _rules)
	_header()
	_tabs()
	body = Control.new()
	body.position = Vector2(0, BODY_Y)
	body.size = Vector2(W, H - BODY_Y - 136)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(body)
	_show(tab)
	if "--event_seen=1" in OS.get_cmdline_user_args():
		ev.intro = true
	if not ev.intro and V7EventData.root().pending.is_empty():
		ev.intro = true
		G.save()
		await get_tree().create_timer(0.5).timeout
		if is_inside_tree():
			_intro_popup()
	else:
		V7Event.show_pending(self, main)

func _header() -> void :
	var r: = Rect2(16, CARD_Y, W - 32, CARD_H)
	var card: = UI.rbox("plum", r, 28, 4, 10)
	card.colors(Color(0.12, 0.06, 0.16, 1.0), Color(0.08, 0.04, 0.1, 1.0)).borders(Color("ffe7a6"), Color("c58a2c"))
	add_child(card)
	var art: = Common.card_art(V7Event.art(def, true), Rect2(4, 4, r.size.x - 8, r.size.y - 8), Vector2(0.5, 0.35), 1.0, 24)
	card.add_child(art)
	var shade: = TextureRect.new()
	var g: = GradientTexture2D.new()
	g.gradient = Gradient.new()
	g.gradient.set_color(0, Color(0.06, 0.03, 0.08, 0.92))
	g.gradient.set_color(1, Color(0.06, 0.03, 0.08, 0.15))
	g.gradient.add_point(0.45, Color(0.06, 0.03, 0.08, 0.78))
	g.fill_from = Vector2(0, 0)
	g.fill_to = Vector2(1, 0)
	shade.texture = g
	shade.position = Vector2(4, 4)
	shade.size = r.size - Vector2(8, 8)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(shade)
	var tag: = UI.rbox("pink", Rect2(18, 16, 186, 32), 14, 2, 6)
	card.add_child(tag)
	tag.add_child(UI.center_label(UI.label("ИВЕНТ · 2 НЕДЕЛИ", 16, Color.WHITE, Color("3d1624"), 3, "body", 900), Rect2(0, 0, 186, 32)))
	var left: = UI.label("До конца: " + V7EventData.left_text(V7EventData.left_secs()), 18, Color("ffd98a"), UI.DARK, 3, "body", 900)
	left.position = Vector2(216, 16)
	left.size = Vector2(240, 32)
	left.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	card.add_child(left)

	card.add_child(Common.avatar(def.hero, Rect2(18, 64, 92, 92), "gold"))
	var fl: = UI.label("Героиня ивента: %s" % G.HEROES[def.hero].name, 20, Color.WHITE, UI.DARK, 3, "body", 900)
	fl.position = Vector2(124, 82)
	card.add_child(fl)
	var fs: = UI.label("с ней в паре +50% валюты и двойная симпатия", 16, Color("ddd2c4"), UI.DARK, 2)
	fs.position = Vector2(124, 114)
	card.add_child(fs)

	var cp: = UI.rbox("plum", Rect2(r.size.x - 220, 16, 200, 58), 29, 3, 8)
	cp.borders(Color("ffe7a6"), Color("c58a2c"))
	card.add_child(cp)
	cp.add_child(UI.tex(V7Event.cur_icon(def), Rect2(-4, -6, 70, 70)))
	cur_lbl = UI.label(UI.fmt(V7EventData.cur()), 26, Color.WHITE, UI.DARK, 4, "body", 900)
	cur_lbl.position = Vector2(64, 0)
	cur_lbl.size = Vector2(122, 58)
	cur_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cur_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cp.add_child(cur_lbl)
	var cn: = UI.label(def.cur, 16, Color("ddd2c4"), UI.DARK, 2)
	cn.position = Vector2(r.size.x - 214, 78)
	cn.size = Vector2(196, 22)
	cn.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	card.add_child(cn)
	UI.slide_in(card, Vector2(0, -20), 0.0, 0.4)

func _tabs() -> void :
	var items: = [["map", "Карта"], ["shop", "Лавка"], ["miles", "Вехи"]]
	var bw: = (W - 32 - 20) / 3.0
	for i in items.size():
		var id: String = items[i][0]
		var b: = JButton.make(items[i][1], "glass", Rect2(16 + i * (bw + 10), TABS_Y, bw, 62), null, 24, -1.0, false)
		b.pressed.connect( func(): _show(id))
		add_child(b)
		tab_btns[id] = b
	_badges()

func _badges() -> void :
	var shop_b: JButton = tab_btns["shop"]
	for c in shop_b.get_children():
		if c.has_meta("v7b"):
			c.queue_free()
	if V7EventData.cur() >= V7EventData.OUTFIT_PRICE and not G.owns(def.outfit.id):
		var d: = Common.badge(shop_b, 0, Vector2(shop_b.size.x - 30, -8))
		d.set_meta("v7b", true)

func _show(id: String) -> void :
	tab = id
	for k in tab_btns:
		Common.tab_paint(tab_btns[k], k == id)
	for c in body.get_children():
		c.queue_free()
	node_btns.clear()
	match id:
		"map":
			_map()
		"shop":
			_shop()
		"miles":
			_miles()
	cur_lbl.text = UI.fmt(V7EventData.cur())
	_badges()


func _map() -> void :
	var cols: = 3
	var rows: = V7EventData.NODES / cols
	var top: = 20.0
	var rh: = (body.size.y - 90.0) / rows
	var pts: = []
	for i in V7EventData.NODES:
		var r: = i / cols
		var c: = i % cols
		if r % 2 == 1:
			c = cols - 1 - c
		pts.append(Vector2(W * (0.2 + 0.3 * c), top + rh * (r + 0.5)))

	var cur_i: = -1
	for i in V7EventData.NODES:
		if V7EventData.node_open(i) and V7EventData.node_stars(i) == 0:
			cur_i = i
			break
	# 0.8: the same painted road as the Path map (dark bed + stepping stones, shaders/v06/map/path), drawn along a
	# smooth curve through the tables; the stones up to the current table glow gold
	var curve: = PackedVector2Array()
	var node_d: = []
	var total: = 0.0
	for i in pts.size():
		if i == pts.size() - 1:
			if curve.size() > 0:
				total += (pts[i] as Vector2).distance_to(curve[curve.size() - 1])
			node_d.append(total)
			curve.append(pts[i])
			break
		node_d.append(total if curve.is_empty() else total + (pts[i] as Vector2).distance_to(curve[curve.size() - 1]))
		var p0: Vector2 = pts[maxi(i - 1, 0)]
		var p1: Vector2 = pts[i]
		var p2: Vector2 = pts[i + 1]
		var p3: Vector2 = pts[mini(i + 2, pts.size() - 1)]
		for s in 16:
			var t: = s / 16.0
			var t2: = t * t
			var t3: = t2 * t
			var q: = 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)
			if curve.size() > 0:
				total += q.distance_to(curve[curve.size() - 1])
			curve.append(q)
	var road: = Line2D.new()
	road.points = curve
	road.width = 44
	road.default_color = Color(0.16, 0.04, 0.16, 0.42)
	road.joint_mode = Line2D.LINE_JOINT_ROUND
	road.begin_cap_mode = Line2D.LINE_CAP_ROUND
	road.end_cap_mode = Line2D.LINE_CAP_ROUND
	body.add_child(road)
	var stones: = Line2D.new()
	stones.points = curve
	stones.width = 28
	stones.texture = G.fx("white")
	stones.texture_mode = Line2D.LINE_TEXTURE_STRETCH
	stones.joint_mode = Line2D.LINE_JOINT_ROUND
	var pm: = ShaderMaterial.new()
	pm.shader = preload("res://shaders/v06/map/path.gdshader")
	pm.set_shader_parameter("len", total)
	pm.set_shader_parameter("width", 28.0)
	pm.set_shader_parameter("spacing", 30.0)
	pm.set_shader_parameter("done_col", Color(def.color.lerp(Color("ffdb6e"), 0.6), 1.0))
	var prog_i: int = cur_i if cur_i >= 0 else (V7EventData.NODES - 1 if V7EventData.cleared_count() >= V7EventData.NODES else 0)
	pm.set_shader_parameter("progress", float(node_d[prog_i]) + 1.0)
	stones.material = pm
	body.add_child(stones)
	for i in V7EventData.NODES:
		var n: = _node(i, pts[i], i == cur_i)
		UI.pop_in(n, 0.03 * i, 0.4)
	var ft: = UI.label("Столов: %d / %d   ★ %d / %d   повторы платят меньше, но без ограничений" % [V7EventData.cleared_count(), V7EventData.NODES, V7EventData.total_stars(), V7EventData.NODES * 3], 16, Color("ddd2c4"), UI.DARK, 3, "body", 900)
	ft.position = Vector2(20, body.size.y - 56)
	ft.size = Vector2(W - 40, 40)
	ft.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(ft)

func _node(i: int, p: Vector2, current: bool) -> Control:
	var boss: bool = i in V7EventData.BOSS_NODES
	var open: = V7EventData.node_open(i)
	var stars: = V7EventData.node_stars(i)
	var s: = 112.0 if boss else 96.0
	var c: = Control.new()
	c.position = p - Vector2(s, s) * 0.5
	c.size = Vector2(s, s)
	c.pivot_offset = c.size * 0.5
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	body.add_child(c)
	if current:
		var g: = Sprite2D.new()
		g.texture = G.fx("glow")
		g.material = Fx.add_mat()
		g.position = c.size * 0.5
		g.scale = Vector2(2.2, 2.2)
		g.modulate = Color(def.color, 0.7)
		c.add_child(g)
		var gt: = g.create_tween().set_loops()
		gt.tween_property(g, "modulate:a", 0.25, 0.8).set_trans(Tween.TRANS_SINE)
		gt.tween_property(g, "modulate:a", 0.7, 0.8).set_trans(Tween.TRANS_SINE)
	# 0.8: the same misc/node_* art as the Path map — pink orb for the table to play, gold sakura coin for a
	# played one, dark lock for a closed one
	var key: = "node_lock"
	if open:
		key = "node_done" if stars > 0 and not current else "node_cur"
	var art: = V8Art.rect(V8Art.misc(key), Rect2(Vector2.ZERO, c.size))
	art.name = "Node"
	c.add_child(art)
	var num_txt: = str(i + 1)
	if key == "node_cur":
		var num: = UI.center_label(UI.title(num_txt, 40 if boss else 34, Color("fff6ea"), Color("4a1428")), Rect2(0, -4, s, s))
		num.label_settings.outline_size = 8
		c.add_child(num)
	else:
		# the sakura / lock stay visible: the number goes on a small graphite badge at the top-left
		var plq: = UI.rbox("graphite", Rect2(-8, 4, 38, 38), 19, 2, 4)
		plq.borders(Color("ffe7a6") if open else Color("9a8a7a"), Color("8a5a1a") if open else Color("3a3236"))
		c.add_child(plq)
		plq.add_child(UI.center_label(UI.title(num_txt, 24, Color("fff1c2") if open else Color("cfc6bd"), UI.DARK), Rect2(0, -1, 38, 38)))
	if boss:
		var cr: = UI.rbox("red", Rect2(s * 0.5 - 52, -24, 104, 28), 14, 2, 4)
		c.add_child(cr)
		cr.add_child(UI.center_label(UI.label("СЛОЖНЫЙ" if i < V7EventData.NODES - 1 else "ФИНАЛ", 16, Color.WHITE, Color("42101a"), 2, "body", 900), Rect2(0, 0, 104, 28)))
	if boss:
		# hard and final tables get their own frame: a crimson-and-gold halo ring behind the node
		var halo: = UI.rbox("red", Rect2(-10, -10, s + 20, s + 20), (s + 20) * 0.5, 4, 4)
		halo.borders(Color("ffe7a6"), Color("c58a2c"))
		halo.modulate.a = 0.85 if open else 0.55
		c.add_child(halo)
		c.move_child(halo, 0)
	# a played table shows its stars; one not played yet shows what its first clear pays instead (same slot)
	if open and stars > 0:
		for k in 3:
			c.add_child(V8Art.star_rect(k < stars, Rect2(s * 0.5 - 39 + k * 26, s - 18, 26, 26)))
	if stars == 0:
		# what the first clear pays: event currency glyph + amount, under the node
		var rw: int = int((V7EventData.clear_reward(i, 0, true, "", def).parts[0] as Array)[1])
		var rt: = "+%d" % rw
		var tw: = UI.font("body", 900).get_string_size(rt, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x + 40.0
		var chip: = UI.rbox("graphite", Rect2((s - tw) * 0.5, s - 16, tw, 28), 14, 2, 4)
		chip.borders(Color("ffe7a6"), Color("c58a2c"))
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.add_child(chip)
		chip.add_child(V8Art.rect(V7Event.cur_icon(def), Rect2(2, -2, 32, 32)))
		chip.add_child(UI.center_label(UI.label(rt, 17, Color("ffe7a6"), UI.DARK, 3, "body", 900), Rect2(32, 0, tw - 36, 28)))
		if not open:
			chip.modulate.a = 0.75
	if current:
		var av: = Common.avatar(def.hero, Rect2(s - 34, -18, 50, 50), "pink")
		c.add_child(av)
	c.gui_input.connect( func(e):
		if e is InputEventMouseButton and e.pressed:
			if not open:
				V9Feel.deny(c)
				main.toast("Сначала пройди стол %d" % i, "star")
				return
			V9Feel.press(c)
			table_popup(i))
	node_btns.append(c)
	return c

func table_popup(i: int) -> void :
	var cfg: = V7EventData.node_cfg(i, def, G.S.level_partner)
	var stars: = V7EventData.node_stars(i)
	var p: = Common.popup(main, "Стол %d" % (i + 1), 640)
	var feat: = G.level_feature(cfg)
	var fl: = UI.label(feat, 20, UI.INK, UI.DARK, 2, "body", 900)
	fl.position = Vector2(40, 60)
	p.add_child(fl)
	for k in 3:
		p.add_child(V8Art.star_rect(k < stars, Rect2(500 + k * 40, 52, 40, 40)))
	var est: = V7EventData.clear_reward(i, 3, stars == 0, "", def)
	var rl: = UI.label(("Первая победа: до %d" if stars == 0 else "Повтор: до %d") % int(est.total), 20, Color("ffd98a"), UI.DARK, 3, "body", 900)
	rl.position = Vector2(92, 106)
	p.add_child(rl)
	p.add_child(UI.tex(V7Event.cur_icon(def), Rect2(36, 96, 48, 48)))
	var hl: = UI.label("Кто садится за стол", 18, Color("bfb3a8"))
	hl.position = Vector2(40, 164)
	p.add_child(hl)
	var pick: = [G.S.level_partner if G.hero_unlocked(G.S.level_partner) else "mc"]
	if G.hero_unlocked(def.hero):
		pick[0] = def.hero
	var avs: = {}
	var x: = 40.0
	for h in G.HERO_ORDER:
		var own: = G.hero_unlocked(h)
		var a: = Common.avatar(h, Rect2(x, 196, 100, 100), "pink" if h == pick[0] else ("gold" if own else "plum"))
		a.mouse_filter = Control.MOUSE_FILTER_STOP
		if not own:
			a.modulate = Color(0.5, 0.48, 0.52, 0.8)
		p.add_child(a)
		avs[h] = a
		if h == def.hero:
			var tg: = UI.rbox("mint", Rect2(x + 8, 286, 84, 26), 13, 2, 4)
			p.add_child(tg)
			tg.add_child(UI.center_label(UI.label("+50%", 16, Color.WHITE, Color("163a2d"), 2, "body", 900), Rect2(0, 0, 84, 26)))
		var hh: String = h
		a.gui_input.connect( func(e):
			if e is InputEventMouseButton and e.pressed:
				if not G.hero_unlocked(hh):
					V9Feel.deny(a)
					main.toast("%s ещё не с тобой. Осколки есть в лавке ивента" % G.HEROES[hh].name if hh == def.hero else "%s ещё не с тобой" % G.HEROES[hh].name, "heart")
					return
				V9Feel.press(a, "tap")
				pick[0] = hh
				for k in avs:
					var ring: RBox = avs[k].get_child(0)
					ring.colors(UI.PAL["pink" if k == hh else ("gold" if G.hero_unlocked(k) else "plum")][0], UI.PAL["pink" if k == hh else ("gold" if G.hero_unlocked(k) else "plum")][1]))
		x += 116
	var line: = UI.label(def.lines[0] if i == 0 else cfg.intro, 18, UI.INK)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.position = Vector2(40, 326)
	line.size = Vector2(580, 100)
	line.custom_minimum_size = Vector2(580, 0)
	p.add_child(line)
	var go: = JButton.make("Играть" if stars == 0 else "Сыграть ещё", "pink", Rect2(110, 520, 440, 92), null, 32)
	go.shine_every = 2.0
	go.pressed.connect( func():
		G.S.level_partner = pick[0]
		G.save()
		main.go("v7play", {"mode": "v7event", "node": i, "partner": pick[0]}))
	p.add_child(go)


func _shop() -> void :
	var it: Dictionary = G.ITEM[def.outfit.id]
	var big: = UI.rbox("plum", Rect2(16, 0, W - 32, 330), 28, 4, 10)
	big.colors(Color(0.14, 0.08, 0.16, 0.96), Color(0.08, 0.04, 0.1, 0.97)).borders(Color("ffe7a6"), Color("c58a2c"))
	body.add_child(big)
	var art: = Common.card_art(G.art_tex(it), Rect2(12, 12, 220, 306), Vector2(0.5, 0.3), 1.0, 20)
	(art.material as ShaderMaterial).set_shader_parameter("holo", 0.3)
	big.add_child(art)
	var lim: = UI.rbox("red", Rect2(0, 18, 120, 30), 13, 2, 4)
	big.add_child(lim)
	lim.add_child(UI.center_label(UI.label("ЛИМИТ", 16, Color.WHITE, Color("42101a"), 2, "body", 900), Rect2(0, 0, 120, 30)))
	var nm: = UI.title(it.name, 30, Color.WHITE, UI.DARK)
	nm.position = Vector2(250, 20)
	nm.size = Vector2(W - 32 - 270, 44)
	big.add_child(nm)
	var rr: = UI.label("%s · %s" % [V10Rank.label(it.rar), G.HEROES[it.hero].name], 19, G.rar_color(it.rar), UI.DARK, 3, "body", 900)
	rr.position = Vector2(252, 70)
	big.add_child(rr)
	var ds: = UI.label("Наряд только этого ивента. Его можно надеть в Гардеробе, и он оживает в Чайной.", 17, Color("ddd2c4"))
	ds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ds.position = Vector2(252, 104)
	ds.size = Vector2(W - 32 - 272, 90)
	ds.custom_minimum_size = Vector2(W - 32 - 272, 0)
	big.add_child(ds)
	var own: = G.owns(it.id)
	var bb: = JButton.make("Уже твой" if own else UI.fmt(V7EventData.OUTFIT_PRICE), "glass" if own else "gold", Rect2(252, 226, W - 32 - 272, 84), null if own else V7Event.cur_icon(def), 30)
	if own:
		bb.disabled = true
	else:
		bb.shine_every = 2.4
		bb.pressed.connect( func(): _ask_buy(V7EventData.SHOP[0], bb, "наряд «%s»" % it.name))
	big.add_child(bb)
	var y: = 346.0
	for k in range(1, V7EventData.SHOP.size()):
		var s: Dictionary = V7EventData.SHOP[k]
		var row: = UI.rbox("glass", Rect2(16, y, W - 32, 88), 24, 3, 8)
		row.borders(Color("ffe7a6"), Color("c58a2c"))
		body.add_child(row)
		var icon: Control
		if s.kind == "shard":
			icon = Common.avatar(def.hero, Rect2(12, 8, 72, 72), "gold")
			row.add_child(icon)
		else:
			row.add_child(V8Art.rect(V8Art.cur("gem" if s.kind == "gems" else "coin"), Rect2(12, 8, 72, 72)))
		var t: = ("Осколок портрета: %s" % G.HEROES[def.hero].name) if s.kind == "shard" else String(s.name)
		var tl: = UI.label(t, 21, Color.WHITE, UI.DARK, 3, "body", 900)
		tl.position = Vector2(100, 12)
		row.add_child(tl)
		var left: = int(s.lim) - V7EventData.bought(s.id)
		var sub: = "осталось %d" % left
		if s.kind == "shard":
			sub += " · у тебя %d/%d" % [int(G.S.shards.get(def.hero, 0)), G.SHARDS_NEED]
		var sl: = UI.label(sub, 16, Color("bfb3a8"))
		sl.position = Vector2(102, 48)
		row.add_child(sl)
		var b: = JButton.make(str(int(s.price)), "gold" if left > 0 else "glass", Rect2(W - 32 - 190, 12, 176, 64), V7Event.cur_icon(def), 24)
		if left <= 0:
			b.disabled = true
		else:
			b.pressed.connect( func(): _ask_buy(s, b, t))
		row.add_child(b)
		y += 98

# 0.8: no spending of the event currency on one tap: every row of the event shop asks first (spec: Common.confirm)
func _ask_buy(s: Dictionary, b: Control, what: String) -> void :
	var price: = int(s.get("price", V7EventData.OUTFIT_PRICE if s.get("kind", "") == "outfit" else 0))
	Common.confirm(main, "Лавка ивента", "Купить %s?" % what, "event", price, func():
		if is_instance_valid(b):
			_buy(s, b), {"price_tex": V7Event.cur_icon(def), "balance": V7EventData.cur(), "yes_text": "Купить"})

func _buy(s: Dictionary, b: Control) -> void :
	var why: = V7EventData.buy(s)
	if why != "":
		V9Feel.deny(b)
		main.toast(why, "gift")
		return
	Sfx.play("reveal_sr", 1.0, -4)
	Fx.burst(self, V10Layout.local_of(self, b.get_global_rect().get_center()), "sparkle", 30, Color(1, 0.9, 0.6), 1.0)
	if s.kind == "outfit":
		main.toast("«%s» теперь твой! Надень его в Гардеробе" % def.outfit.name, "wardrobe")
		Sfx.play("reveal_ssr", 1.0, -2)
	else:
		main.toast("Куплено", "gift")
	main.refresh_currency(true)
	_show("shop")


func _miles() -> void :
	var ev: = V7EventData.st()
	var earned: = int(ev.earned)
	var hl: = UI.label("Всего собрано за ивент: %d" % earned, 22, Color("ffe7a6"), UI.DARK, 3, "body", 900)
	hl.position = Vector2(24, 0)
	body.add_child(hl)
	var y: = 44.0
	var prev: = 0
	var rh: = minf(96.0, (body.size.y - 60.0) / V7EventData.MILES.size() - 8)
	for k in V7EventData.MILES.size():
		var m: Dictionary = V7EventData.MILES[k]
		var got: bool = k in ev.miles.map( func(x): return int(x))
		var row: = UI.rbox("gold" if got else "glass", Rect2(16, y, W - 32, rh), 22, 3, 8)
		if got:
			row.colors(Color(0.34, 0.26, 0.16, 0.95), Color(0.18, 0.12, 0.08, 0.95))
		else:
			row.borders(Color("ffe7a6"), Color("c58a2c"))
		body.add_child(row)
		row.add_child(UI.tex(V7Event.cur_icon(def), Rect2(8, rh * 0.5 - 28, 56, 56)))
		var al: = UI.label(str(int(m.at)), 24, Color.WHITE, UI.DARK, 3, "body", 900)
		al.position = Vector2(70, rh * 0.5 - 18)
		row.add_child(al)
		var tl: = UI.label(V7EventData.mile_text(m, def), 20, Color("ffe7a6") if not got else Color("fff3dc"), UI.DARK, 3, "body", 900)
		tl.position = Vector2(170, 10)
		row.add_child(tl)
		var frac: = clampf(float(earned - prev) / float(int(m.at) - prev), 0.0, 1.0)
		Common.progress_bar(row, Rect2(170, rh - 32, W - 32 - 300, 18), frac, "gold" if not got else "mint")
		if got:
			row.add_child(UI.center_label(UI.label("✓", 40, Color("a9d9c4"), UI.DARK, 3, "body", 900), Rect2(W - 32 - 90, 0, 80, rh)))
		else:
			var gl: = UI.label("%d/%d" % [mini(earned, int(m.at)), int(m.at)], 16, Color("bfb3a8"))
			gl.position = Vector2(W - 32 - 118, rh - 36)
			row.add_child(gl)
		prev = int(m.at)
		y += rh + 8


func _intro_popup() -> void :
	var p: = Common.popup(main, def.name, 560)
	var art: = Common.card_art(V7Event.art(def, true), Rect2(24, 50, 612, 220), Vector2(0.5, 0.35), 1.0, 20)
	p.add_child(art)
	p.add_child(Common.avatar(def.hero, Rect2(30, 286, 100, 100), "gold"))
	var l: = UI.label(def.lines[0], 20, UI.INK)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.position = Vector2(146, 290)
	l.size = Vector2(480, 100)
	l.custom_minimum_size = Vector2(480, 0)
	p.add_child(l)
	var s: = UI.label(def.pitch, 16, Color("bfb3a8"))
	s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	s.position = Vector2(36, 396)
	s.size = Vector2(590, 70)
	s.custom_minimum_size = Vector2(590, 0)
	p.add_child(s)
	var b: = JButton.make("К столам", "pink", Rect2(130, 470, 400, 76), null, 28)
	b.pressed.connect( func(): Common.close_popup(p))
	p.add_child(b)

func _rules() -> void :
	var p: = Common.popup(main, "Как устроен ивент", 640)
	var txt: = "• Ивент идёт две недели, потом приходит новый со своей героиней, картой и нарядом.\n• Двенадцать столов по порядку. Победа даёт %s, звёзды добавляют к награде. Пройденный стол можно играть снова: он раскладывается заново и платит меньше.\n• Первая партия дня в ивенте платит вдвое.\n• С героиней ивента в паре +50%% валюты и двойная симпатия.\n• Валюту тратишь в лавке: лимитный наряд, осколки, кристаллы. Вехи дают награды сами.\n• Переполненный лоток не заканчивает партию: три фишки возвращаются, но звёзд будет меньше.\n• Когда ивент закончится, неистраченная валюта обменяется на кристаллы." % def.cur.to_lower()
	var l: = UI.label(txt, 18, UI.INK)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.position = Vector2(40, 60)
	l.size = Vector2(580, 560)
	l.custom_minimum_size = Vector2(580, 0)
	p.add_child(l)

func dev_act(a: String) -> void :
	match a:
		"map", "shop", "miles":
			_show(a)
		"node":
			table_popup(0)
		"rules":
			_rules()
		"intro":
			_intro_popup()
		"rich":
			V7EventData.add_cur(2000)
			_show(tab)
		"buyask":
			_ask_buy(V7EventData.SHOP[0], self, "наряд «%s»" % G.ITEM[def.outfit.id].name)
