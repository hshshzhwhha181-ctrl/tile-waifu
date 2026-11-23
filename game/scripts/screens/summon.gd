extends Control


var main
var W: = 720.0
var H: = 1280.0
var banner_i: = 0
var banner_root: Control
var pull1_btn: JButton
var pull10_btn: JButton
var circle: ColorRect
var circle_mat: ShaderMaterial
var seq: Control
var showcase: Control
var flipping: = false
var results_shown: = false
var cards: Array = []
var pity_lbl: Label
var trial_btn: JButton
var last_n: = 10

func build(m, args: Dictionary) -> void :
	main = m
	W = size.x
	H = size.y
	banner_i = int(args.get("banner", 0))
	main.show_chrome(true, true)
	Sfx.music("summon")
	Common.backdrop(self, "summon", size, 0.0, 1.0)
	Fx.ambient(self, "stars", Vector2(W, H * 0.5))
	Fx.ambient(self, "petals", size)
	circle = ColorRect.new()
	circle.size = Vector2(620, 620)
	circle.position = Vector2(W * 0.5 - 310, H - 132 - 330)
	circle.pivot_offset = Vector2(310, 310)
	circle.scale = Vector2(1.0, 0.36)
	circle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	circle_mat = ShaderMaterial.new()
	circle_mat.shader = preload("res://shaders/circle.gdshader")
	circle_mat.set_shader_parameter("color", Color(0.65, 0.85, 1.0, 0.9))
	circle_mat.set_shader_parameter("power", 0.25)
	circle.material = circle_mat
	add_child(circle)
	_build_banner()

func _build_banner() -> void :
	if banner_root:
		banner_root.queue_free()
	if G.BANNERS[banner_i].get("newbie", false) and int(G.S.newbie_left) <= 0:
		banner_i = 1
	banner_root = Control.new()
	banner_root.size = size
	banner_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(banner_root)
	var b: Dictionary = G.BANNERS[banner_i]
	var newbie: bool = b.get("newbie", false)

	var shown: Array = []
	for i in G.BANNERS.size():
		if G.BANNERS[i].get("newbie", false) and int(G.S.newbie_left) <= 0:
			continue
		shown.append(i)
	var tw: = (W - 48 - (shown.size() - 1) * 10) / shown.size()
	for k in shown.size():
		var i: int = shown[k]
		var bb: Dictionary = G.BANNERS[i]
		var tb: = JButton.make(bb.name, "lav" if i == banner_i else "glass", Rect2(24 + k * (tw + 10), 124, tw, 60), null, 22)
		tb.pressed.connect( func():
			if i != banner_i:
				banner_i = i
				_build_banner())
		banner_root.add_child(tb)
		if bb.get("newbie", false):
			var sale: = UI.rbox("red", Rect2(tw - 62, -14, 70, 28), 12, 2, 4)
			tb.add_child(sale)
			sale.add_child(UI.center_label(UI.label("−20%", 15, Color.WHITE, Color("6a1020"), 3), Rect2(0, 0, 70, 28)))

	var cr: = Rect2(24, 198, W - 48, H - 132 - 198 - 196)
	var frame: = UI.rbox("gold", cr, 30, 6, 16)
	banner_root.add_child(frame)
	var it: Dictionary = G.ITEM[b.item]
	var art: = Common.card_art(G.art_tex(it), Rect2(cr.position + Vector2(8, 8), cr.size - Vector2(16, 16)), Vector2(0.5, 0.36), 1.0, 24)
	(art.material as ShaderMaterial).set_shader_parameter("holo", 0.35)
	(art.material as ShaderMaterial).set_shader_parameter("bottom_shade", 0.9)
	banner_root.add_child(art)
	Common.rays(banner_root, cr.position + Vector2(cr.size.x * 0.75, 120), 520, Color(1, 0.95, 0.8, 0.35), 8, 0.04, 0.4)
	var tag: = UI.rbox("pink" if not newbie else "red", Rect2(cr.position.x - 10, cr.position.y + 22, 230, 44), 14, 3, 10)
	banner_root.add_child(tag)
	tag.add_child(UI.center_label(UI.label(V6Txt.s("summon.rate_up") if not newbie else V6Txt.s("summon.newbie_tag"), 21, Color.WHITE, Color("7a2346"), 5, "body", 900), Rect2(0, 0, 230, 44)))
	if not newbie:
		var trial: = JButton.make(V6Txt.s("summon.trial"), "lav", Rect2(cr.end.x - 250, cr.position.y + 18, 236, 62), G.icon("star"), 21)
		trial.shine_every = 3.0
		trial.pressed.connect( func(): main.go("play", {"trial": b.hero}))
		banner_root.add_child(trial)
		trial_btn = trial

	var info_y: = cr.end.y - 192
	var t1: = UI.title(b.name, 50, Color.WHITE, Color("3f2a7a"))
	t1.position = Vector2(cr.position.x + 26, info_y - 128)
	banner_root.add_child(t1)
	var t2: = UI.label((V6Txt.s("summon.ssr_line") % [G.HEROES[it.hero].name, it.name]) if not newbie else V6Txt.s("summon.newbie_line"), 21, Color("ffe7a6"), Color("3f2a7a"), 5, "body", 900)
	t2.position = Vector2(cr.position.x + 28, info_y - 58)
	banner_root.add_child(t2)

	var ip: = UI.rbox("plum", Rect2(cr.position.x + 16, info_y, cr.size.x - 32, 178), 24, 3, 10)
	ip.set_param("border_top", Color("ffe7a6")).set_param("border_bottom", Color("c58a2c"))
	banner_root.add_child(ip)
	var pw: = ip.size.x
	var left: = 60 - int(G.S.pity)
	var pl: = UI.label(V6Txt.s("summon.pity"), 17, Color("ffe7a6"), Color(0.2, 0.05, 0.2), 3, "body", 900)
	pl.position = Vector2(18, 10)
	ip.add_child(pl)
	pity_lbl = UI.title(str(left), 44, Color.WHITE, Color("7a4a0c"))
	pity_lbl.position = Vector2(18, 30)
	ip.add_child(pity_lbl)
	var pn: = UI.label(V6Txt.s("summon.pity_unit"), 17, Color.WHITE, Color(0.2, 0.05, 0.2), 3)
	pn.position = Vector2(20 + pity_lbl.get_minimum_size().x + 6, 52)
	ip.add_child(pn)
	Common.progress_bar(ip, Rect2(18, 96, 300, 18), float(G.S.pity) / 60.0, "gold")
	var rules: = V6Txt.s("summon.rules")
	var g_text: = V6Txt.s("summon.guar_on") if G.S.guar else V6Txt.s("summon.guar_off")
	if newbie:
		g_text = V6Txt.s("summon.newbie_left") % int(G.S.newbie_left)
	var rl: = UI.label(rules + "\n" + g_text, 15, Color("f4e6ff"), Color(0.2, 0.05, 0.2), 2)
	rl.position = Vector2(18, 124)
	ip.add_child(rl)
	if not newbie:
		var ex: = int(G.S.ex)
		var el: = UI.label(V6Txt.s("summon.exchange"), 17, Color("ffe7a6"), Color(0.2, 0.05, 0.2), 3, "body", 900)
		el.position = Vector2(pw - 250, 10)
		ip.add_child(el)
		var ev: = UI.label("%d / %d" % [mini(ex, G.EXCHANGE_COST), G.EXCHANGE_COST], 24, Color.WHITE, Color(0.2, 0.05, 0.2), 4, "body", 900)
		ev.position = Vector2(pw - 250, 32)
		ip.add_child(ev)
		var xb: = JButton.make(V6Txt.s("summon.exchange_btn"), "gold" if ex >= G.EXCHANGE_COST else "glass", Rect2(pw - 250, 72, 232, 50), null, 19)
		xb.pressed.connect( func(): _exchange())
		ip.add_child(xb)
	UI.pop_in(frame, 0.0, 0.92)
	UI.pop_in(art, 0.0, 0.92)

	var by: = H - 132 - 170
	var free: bool = G.S.free10 and not newbie
	if not newbie:
		pull1_btn = JButton.make(V6Txt.s("summon.pull1"), "lav", Rect2(24, by, 320, 124), null, 30)
		pull1_btn.set_sub(V6Txt.s("common.gems_n") % UI.fmt(G.PULL_COST), 20)
		pull1_btn.pressed.connect( func(): _pull(1))
		banner_root.add_child(pull1_btn)
		UI.slide_in(pull1_btn, Vector2(0, 60), 0.1)
	var r10: = Rect2(W - 344, by, 320, 124) if not newbie else Rect2(W * 0.5 - 220, by, 440, 124)
	pull10_btn = JButton.make(V6Txt.s("summon.pull10"), "gold", r10, null, 30)
	pull10_btn.set_sub(V6Txt.s("summon.free") if free else (V6Txt.s("common.gems_n") % UI.fmt(G.NEWBIE_COST if newbie else G.PULL_COST * 10)), 20)
	pull10_btn.shine_every = 2.0
	pull10_btn.pulse = free or newbie
	pull10_btn.pressed.connect( func(): _pull(10))
	banner_root.add_child(pull10_btn)
	if free:
		Common.badge(pull10_btn, 0, Vector2(r10.size.x - 26, -10))
	elif newbie:
		var sale: = UI.rbox("red", Rect2(r10.end.x - 100, by - 16, 100, 34), 14, 3, 6)
		banner_root.add_child(sale)
		sale.add_child(UI.center_label(UI.label("−20%", 19, Color.WHITE, Color("6a1020"), 4), Rect2(0, 0, 100, 34)))
	UI.slide_in(pull10_btn, Vector2(0, 60), 0.15)


func _exchange() -> void :
	var b: Dictionary = G.BANNERS[banner_i]
	if int(G.S.ex) < G.EXCHANGE_COST:
		main.toast(V6Txt.s("summon.ex_toast") % [int(G.S.ex), G.EXCHANGE_COST], "ticket")
		return
	if G.owns(b.item):
		main.toast(V6Txt.s("summon.have") % G.ITEM[b.item].name, "wardrobe")
		return
	G.S.ex = int(G.S.ex) - G.EXCHANGE_COST
	G.give(b.item)
	G.save()
	var r: Dictionary = G.ITEM[b.item].duplicate()
	r["new"] = true
	await _showcase(r)
	_build_banner()

func _pull(n: int) -> void :
	var b: Dictionary = G.BANNERS[banner_i]
	var newbie: bool = b.get("newbie", false)
	var free: bool = n == 10 and G.S.free10 and not newbie
	var cost: = 0 if free else (G.NEWBIE_COST if newbie else G.PULL_COST * n)
	if G.S.gems < cost:
		main.toast(V6Txt.s("summon.no_gems"), "gem")
		return
	if free:
		G.S.free10 = false
	G.S.gems -= cost
	main.refresh_currency(true)
	var res: = G.pull(n, b)
	last_n = n
	_sequence(res)


func _sequence(res: Array) -> void :
	results_shown = false
	flipping = true
	main.show_chrome(false, false)
	banner_root.visible = false
	var best: = "R"
	for r in res:
		if r.rar == "SSR":
			best = "SSR"
		elif r.rar == "SR" and best == "R":
			best = "SR"
	var col: = G.rar_color(best)
	seq = Control.new()
	seq.size = size
	seq.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(seq)
	var dim: = ColorRect.new()
	dim.size = size
	dim.color = Color(0.05, 0.02, 0.1, 0.0)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	seq.add_child(dim)
	dim.create_tween().tween_property(dim, "color:a", 0.55, 0.6)
	Sfx.music("")
	Sfx.say(G.BANNERS[banner_i].hero, "gacha")

	var t: = create_tween().set_parallel()
	t.tween_property(circle, "position:y", H * 0.5 - 310, 1.0).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(circle, "scale", Vector2(1.05, 1.05), 1.0).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN_OUT)
	t.tween_method( func(v): circle_mat.set_shader_parameter("power", v), 0.25, 1.4, 2.4)
	t.tween_method( func(v): circle_mat.set_shader_parameter("spin", v), 0.2, 2.2, 2.4)
	move_child(circle, get_child_count() - 1)
	await get_tree().create_timer(0.5).timeout
	Sfx.play("summon_charge")

	var p: = Fx.particles("glow", 90, 1.0)
	p.material = Fx.add_mat()
	p.position = Vector2(W * 0.5, H * 0.5)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE_SURFACE
	p.emission_sphere_radius = 400
	p.spread = 0
	p.initial_velocity_max = 0
	p.radial_accel_min = -900
	p.radial_accel_max = -700
	p.tangential_accel_min = 200
	p.tangential_accel_max = 300
	p.scale_amount_min = 0.12
	p.scale_amount_max = 0.3
	p.color = Color(0.7, 0.85, 1.0)
	add_child(p)
	await get_tree().create_timer(1.0).timeout

	var tc: = create_tween()
	tc.tween_method( func(c): circle_mat.set_shader_parameter("color", c);p.color = c, Color(0.65, 0.85, 1.0, 0.9), Color(col.r, col.g, col.b, 1.0), 0.6)
	Fx.shake(seq, 6, 1.0)
	await get_tree().create_timer(1.0).timeout
	p.emitting = false

	Sfx.play("summon_boom")
	var flash: = ColorRect.new()
	flash.size = size
	flash.color = Color(1, 1, 1, 1)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	var ft: Tween = flash.create_tween()
	ft.tween_property(flash, "color:a", 0.0, 0.7)
	ft.tween_callback(flash.queue_free)
	p.queue_free()
	var rays: = Common.rays(seq, Vector2(W * 0.5, H * 0.5), 1400, Color(col.r, col.g, col.b, 0.7), 16, 0.05, 0.9)
	Fx.burst(seq, Vector2(W * 0.5, H * 0.5), "sparkle", 60, col, 2.0)
	circle.visible = false
	await get_tree().create_timer(0.3).timeout
	_deal_cards(res)

func _deal_cards(res: Array) -> void :
	cards.clear()
	var n: = res.size()
	var cw: = 124.0 if n > 1 else 300.0
	var ch: = cw * 1.5
	var gap: = 12.0
	var cols: = 5 if n > 1 else 1
	var rows: = ceili(float(n) / cols)
	var total_w: = cols * cw + (cols - 1) * gap
	var x0: = (W - total_w) * 0.5
	var y0: = H * 0.5 - (rows * ch + (rows - 1) * 40) * 0.5 - 30
	for i in n:
		var r: Dictionary = res[i]
		var pos: = Vector2(x0 + (i % cols) * (cw + gap), y0 + (i / cols) * (ch + 40))
		var c: = _card(r, Vector2(cw, ch))
		c.position = Vector2(W * 0.5 - cw * 0.5, H * 0.5 - ch * 0.5)
		c.scale = Vector2(0.2, 0.2)
		c.rotation = randf_range(-1.0, 1.0)
		seq.add_child(c)
		var t: Tween = c.create_tween().set_parallel()
		t.tween_property(c, "position", pos, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(i * 0.06)
		t.tween_property(c, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(i * 0.06)
		t.tween_property(c, "rotation", 0.0, 0.45).set_delay(i * 0.06)
		get_tree().create_timer(i * 0.06).timeout.connect( func(): Sfx.play("flip", randf_range(0.9, 1.1)))
		cards.append(c)
	await get_tree().create_timer(0.6 + n * 0.06).timeout
	for i in n:
		if not is_inside_tree():
			return
		var c: Control = cards[i]
		var r: Dictionary = res[i]
		if r.rar == "SSR":

			Fx.shake(c, 6, 0.6)
			Fx.flash_glow(seq, c.position + c.size * 0.5, Color(1, 0.85, 0.4), 4.0, 0.8)
			await get_tree().create_timer(0.7).timeout
		await _flip(c, r)
		if r.rar == "SSR":
			await _showcase(r)
		else:
			await get_tree().create_timer(0.12 if r.rar == "R" else 0.25).timeout
	flipping = false
	_results(res)

func _card(r: Dictionary, sz: Vector2) -> Control:
	var c: = Control.new()
	c.size = sz
	c.pivot_offset = sz * 0.5
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col: = G.rar_color(r.rar)
	if r.rar != "R":
		var aura: = Sprite2D.new()
		aura.texture = G.fx("glow")
		aura.material = Fx.add_mat()
		aura.modulate = Color(col.r, col.g, col.b, 0.85)
		aura.position = sz * 0.5
		aura.scale = Vector2(sz.x / 50.0, sz.y / 55.0)
		c.add_child(aura)
		var at: Tween = aura.create_tween().set_loops()
		at.tween_property(aura, "modulate:a", 0.45, 0.5)
		at.tween_property(aura, "modulate:a", 0.85, 0.5)
	var back: = UI.tex(load("res://assets/ui/card_back.webp"), Rect2(Vector2.ZERO, sz), false)
	back.name = "Back"
	var bm: = ShaderMaterial.new()
	bm.shader = preload("res://shaders/card.gdshader")
	bm.set_shader_parameter("size", sz)
	bm.set_shader_parameter("radius", 12.0)
	bm.set_shader_parameter("tex_size", Vector2(424, 632))
	bm.set_shader_parameter("focus", Vector2(0.5, 0.5))
	bm.set_shader_parameter("bottom_shade", 0.0)
	back.material = bm
	c.add_child(back)
	var front: = Control.new()
	front.name = "Front"
	front.size = sz
	front.visible = false
	front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(front)
	var pal: = "gold" if r.rar == "SSR" else ("lav" if r.rar == "SR" else "sky")
	front.add_child(UI.rbox(pal, Rect2(Vector2.ZERO, sz), 14, 4, 8))
	var tex: = G.art_tex(r)
	var focus: = Vector2(0.5, 0.28) if r.cat == "outfit" else Vector2(0.5, 0.5)
	var art: = Common.card_art(tex, Rect2(5, 5, sz.x - 10, sz.y - 10), focus, 1.0 if r.cat != "skin" else 0.75, 10)
	var am: ShaderMaterial = art.material
	am.set_shader_parameter("holo", 0.6 if r.rar == "SSR" else 0.0)
	am.set_shader_parameter("bottom_shade", 0.8)
	front.add_child(art)
	var fs: = 14 if sz.x < 200 else 26
	var rl: = UI.label(r.rar, fs + 8, Color.WHITE, col.darkened(0.5), 5, "title", 900)
	rl.position = Vector2(8, 2)
	front.add_child(rl)
	var nl: = UI.label(r.name, fs, Color.WHITE, Color(0.2, 0.05, 0.2), 4, "body", 900)
	nl.position = Vector2(6, sz.y - (44 if sz.x < 200 else 80))
	nl.size = Vector2(sz.x - 12, 40 if sz.x < 200 else 70)
	nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	front.add_child(nl)
	if r.get("new", false):
		var nb: = UI.rbox("red", Rect2(sz.x - 58, -10, 64, 26), 12, 2, 4)
		front.add_child(nb)
		nb.add_child(UI.center_label(UI.label("NEW", 14, Color.WHITE), Rect2(0, 0, 64, 26)))
	return c

func _flip(c: Control, r: Dictionary) -> void :
	var t: Tween = c.create_tween()
	t.tween_property(c, "scale", Vector2(0.0, 1.08), 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback( func():
		c.get_node("Back").visible = false
		c.get_node("Front").visible = true)
	t.tween_property(c, "scale", Vector2(1.08, 1.08), 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(c, "scale", Vector2.ONE, 0.12)
	Sfx.play("flip")
	await t.finished
	var center: = c.position + c.size * 0.5
	match r.rar:
		"SSR":
			Sfx.play("reveal_ssr")
		"SR":
			Sfx.play("reveal_sr")
			Fx.burst(seq, center, "sparkle", 26, G.rar_color("SR"), 1.0)
			Fx.ring(seq, center, G.rar_color("SR"), 1.4)
		_:
			Sfx.play("reveal_r", randf_range(0.95, 1.1), -4)

func _showcase(r: Dictionary) -> void :
	showcase = Control.new()
	showcase.size = size
	showcase.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(showcase)
	var bg: = ColorRect.new()
	bg.size = size
	bg.color = Color(0.06, 0.02, 0.1, 0.92)
	showcase.add_child(bg)
	Common.rays(showcase, Vector2(W * 0.5, H * 0.42), 1500, Color(1, 0.82, 0.35, 0.8), 18, 0.05, 1.0)
	Common.rays(showcase, Vector2(W * 0.5, H * 0.42), 900, Color(1, 0.6, 0.85, 0.5), 9, -0.08, 0.7)
	var aw: = W - 110.0
	var ah: = aw * 1.45
	var frame: = UI.rbox("gold", Rect2((W - aw) * 0.5 - 8, H * 0.42 - ah * 0.5 - 8, aw + 16, ah + 16), 26, 6, 16)
	frame.set_param("glow", 1.0)
	showcase.add_child(frame)
	var art: = Common.card_art(G.art_tex(r), Rect2((W - aw) * 0.5, H * 0.42 - ah * 0.5, aw, ah), Vector2(0.5, 0.45), 1.0, 20)
	(art.material as ShaderMaterial).set_shader_parameter("holo", 0.45)
	(art.material as ShaderMaterial).set_shader_parameter("bottom_shade", 0.6)
	showcase.add_child(art)
	frame.pivot_offset = frame.size * 0.5
	art.pivot_offset = art.size * 0.5
	for n in [frame, art]:
		n.scale = Vector2(1.6, 1.6)
		n.modulate.a = 0
		var t: Tween = n.create_tween().set_parallel()
		t.tween_property(n, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		t.tween_property(n, "modulate:a", 1.0, 0.25)
	var ssr: = UI.title("SSR", 120, Color("fff1b8"), Color("c0661a"))
	ssr.position = Vector2(30, H * 0.42 - ah * 0.5 - 70)
	ssr.rotation = deg_to_rad(-8)
	showcase.add_child(ssr)
	UI.pop_in(ssr, 0.35, 3.0)
	var rib: = Common.ribbon(showcase, r.name, Rect2(40, H * 0.42 + ah * 0.5 - 30, W - 80, 86), "pink", 34)
	UI.slide_in(rib, Vector2(0, 80), 0.45)
	if r.has("hero"):
		var hl: = UI.center_label(UI.label(G.HEROES[r.hero].name + " · " + G.HEROES[r.hero].title, 24, Color("ffe7a6"), Color(0.2, 0.05, 0.2), 5, "body", 900), Rect2(0, 86, W - 80, 36))
		rib.add_child(hl)
	Fx.burst(showcase, Vector2(W * 0.5, H * 0.42), "sparkle", 90, Color(1, 0.85, 0.45), 2.2)
	Fx.burst(showcase, Vector2(W * 0.15, H), "confetti", 60)
	Fx.burst(showcase, Vector2(W * 0.85, H), "confetti", 60)
	Fx.ambient(showcase, "stars", size)
	await get_tree().create_timer(0.5).timeout
	Sfx.say(r.get("hero", "mc"), "ssr")
	var tap: = UI.center_label(UI.label(V6Txt.s("summon.tap"), 22, Color(1, 1, 1, 0.85), Color(0.2, 0.05, 0.2), 4), Rect2(0, H - 90, W, 40))
	showcase.add_child(tap)
	var tt: Tween = tap.create_tween().set_loops()
	tt.tween_property(tap, "modulate:a", 0.3, 0.6)
	tt.tween_property(tap, "modulate:a", 1.0, 0.6)
	var done: = [false]
	showcase.gui_input.connect( func(e):
		if e is InputEventMouseButton and e.pressed:
			done[0] = true)
	while not done[0] and is_inside_tree():
		await get_tree().process_frame
	var ct: Tween = showcase.create_tween()
	ct.tween_property(showcase, "modulate:a", 0.0, 0.25)
	ct.tween_callback(showcase.queue_free)
	showcase = null
	Sfx.music("summon")

func _results(res: Array) -> void :
	results_shown = true
	var by: = H - 170
	var nb: bool = G.BANNERS[banner_i].get("newbie", false)
	if nb and int(G.S.newbie_left) <= 0:
		banner_i = 1
		nb = false
	var again: = JButton.make(V6Txt.s("summon.more") % res.size(), "gold", Rect2(30, by, 320, 110), null, 32)
	again.set_sub(V6Txt.s("common.gems_n") % UI.fmt(G.NEWBIE_COST if nb and res.size() == 10 else G.PULL_COST * res.size()), 19)
	again.pressed.connect( func():
		_close_seq()
		_pull(res.size()))
	seq.add_child(again)
	var ok: = JButton.make(V6Txt.s("common.done"), "pink", Rect2(W - 350, by, 320, 110), null, 34)
	ok.pressed.connect(_close_seq)
	seq.add_child(ok)
	UI.slide_in(again, Vector2(0, 80), 0.0)
	UI.slide_in(ok, Vector2(0, 80), 0.08)
	var ttl: = Common.ribbon(seq, V6Txt.s("summon.results"), Rect2(W * 0.5 - 270, 70, 540, 84), "lav", 36)
	UI.pop_in(ttl, 0.0)

func _close_seq() -> void :
	if seq:
		seq.queue_free()
		seq = null
	circle.visible = true
	circle.position = Vector2(W * 0.5 - 310, H - 132 - 330)
	circle.scale = Vector2(1.0, 0.36)
	circle_mat.set_shader_parameter("power", 0.25)
	circle_mat.set_shader_parameter("spin", 0.2)
	circle_mat.set_shader_parameter("color", Color(0.65, 0.85, 1.0, 0.9))
	main.show_chrome(true, true)
	main.refresh_currency()
	Sfx.music("summon")
	_build_banner()

func demo_skip() -> bool:

	if showcase:
		var ev: = InputEventMouseButton.new()
		ev.pressed = true
		ev.button_index = MOUSE_BUTTON_LEFT
		showcase.gui_input.emit(ev)
		return true
	return flipping

func dev_act(a: String) -> void :
	if a == "pull10":
		G.demo_force_ssr = true
		_pull(10)
	elif a.begins_with("b"):
		banner_i = int(a.substr(1))
		_build_banner()
	elif a == "skip":
		demo_skip()
