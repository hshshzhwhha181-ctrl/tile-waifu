class_name Common
extends RefCounted


static func backdrop(parent: Control, bg: String, size: Vector2, blur: = 0.0, bright: = 1.0, tint: = Color.WHITE, focus: = Vector2(0.5, 0.5)) -> TextureRect:
	var path: = "res://assets/bg/%s.webp" % bg
	if blur > 0.0 and ResourceLoader.exists("res://assets/bg/%s_blur.webp" % bg):
		path = "res://assets/bg/%s_blur.webp" % bg
		blur = 0.0
	var tex: Texture2D = load(path)
	var r: = UI.tex(tex, Rect2(Vector2.ZERO, size), false)
	var m: = ShaderMaterial.new()
	m.shader = preload("res://shaders/blurbg.gdshader")
	m.set_shader_parameter("size", size)
	m.set_shader_parameter("tex_size", Vector2(tex.get_width(), tex.get_height()))
	m.set_shader_parameter("blur", blur)
	m.set_shader_parameter("bright", bright)
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("focus", focus)
	m.set_shader_parameter("zoom", 1.04)
	m.set_shader_parameter("drift", Vector2(1, 1))
	r.material = m
	parent.add_child(r)
	return r

static func vignette(parent: Control, size: Vector2, color: = Color(0.55, 0.2, 0.35, 1.0), amount: = 0.35) -> ColorRect:
	var c: = ColorRect.new()
	c.size = size
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m: = ShaderMaterial.new()
	m.shader = preload("res://shaders/overlay.gdshader")
	m.set_shader_parameter("tint", color)
	m.set_shader_parameter("vignette", amount)
	c.material = m
	parent.add_child(c)
	return c

static func rays(parent: Node, pos: Vector2, size: float, color: Color, count: = 12.0, speed: = 0.05, intensity: = 0.5) -> ColorRect:
	var c: = ColorRect.new()
	c.size = Vector2(size, size)
	c.position = pos - c.size * 0.5
	c.pivot_offset = c.size * 0.5
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m: = ShaderMaterial.new()
	m.shader = preload("res://shaders/rays.gdshader")
	m.set_shader_parameter("color", color)
	m.set_shader_parameter("count", count)
	m.set_shader_parameter("speed", speed)
	m.set_shader_parameter("intensity", intensity)
	c.material = m
	parent.add_child(c)
	return c

static func card_art(tex: Texture2D, r: Rect2, focus: = Vector2(0.5, 0.3), zoom: = 1.0, radius: = 16.0) -> TextureRect:
	var t: = UI.tex(tex, r, false)
	var m: = ShaderMaterial.new()
	m.shader = preload("res://shaders/card.gdshader")
	m.set_shader_parameter("size", r.size)
	m.set_shader_parameter("radius", radius)
	m.set_shader_parameter("tex_size", Vector2(tex.get_width(), tex.get_height()))
	m.set_shader_parameter("focus", focus)
	m.set_shader_parameter("zoom", zoom)
	t.material = m
	return t

static func bubble(parent: Control, text: String, pos: Vector2, width: = 300.0, tail_left: = true) -> Control:
	var root: = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.position = pos
	var l: = UI.label(text, 22, UI.INK)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size = Vector2(width - 36, 0)
	l.custom_minimum_size = Vector2(width - 36, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var lines: float = max(1.0, ceil(UI.font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x / (width - 40)))
	var h: float = 26.0 + lines * 30.0
	var tail: = Polygon2D.new()
	tail.color = Color(0.12, 0.11, 0.13, 0.97)
	tail.polygon = PackedVector2Array([Vector2(40, h - 6), Vector2(80, h - 6), Vector2(30, h + 22)]) if tail_left else PackedVector2Array([Vector2(width - 80, h - 6), Vector2(width - 40, h - 6), Vector2(width - 30, h + 22)])
	root.add_child(tail)
	var b: = UI.rbox("cream", Rect2(0, 0, width, h), 24, 3, 12)
	b.set_param("border_top", Color("e8c9a0")).set_param("border_bottom", Color("a8697a"))
	root.add_child(b)
	l.position = Vector2(18, 12)
	l.size = Vector2(width - 36, h - 24)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	root.add_child(l)
	root.size = Vector2(width, h)
	root.pivot_offset = Vector2(width * 0.3, h)
	parent.add_child(root)
	root.scale = Vector2(0.4, 0.4)
	root.modulate.a = 0
	var t: Tween = root.create_tween().set_parallel()
	t.tween_property(root, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(root, "modulate:a", 1.0, 0.15)
	return root

static func ribbon(parent: Control, text: String, rect: Rect2, pal: = "pink", size: = 34) -> RBox:
	var b: = UI.rbox(pal, rect, 18, 4, 12)
	if pal == "pink":
		b.colors(Color("c48292"), Color("743548"))
	parent.add_child(b)
	var l: = UI.center_label(UI.title(text, size, Color("fff6ea"), UI.PAL[pal][2]), Rect2(Vector2.ZERO, rect.size))
	b.add_child(l)
	return b

static func icon_button(parent: Control, icon: String, text: String, rect: Rect2, cb: Callable, badge: = false) -> Control:
	var c: = Control.new()
	c.position = rect.position
	c.size = rect.size
	c.pivot_offset = rect.size * 0.5
	c.mouse_filter = Control.MOUSE_FILTER_STOP

	var d0: = rect.size.x * 0.86
	var disc: = UI.rbox("graphite", Rect2((rect.size.x - d0) * 0.5, (rect.size.x - d0) * 0.5, d0, d0), d0 * 0.5, 2, 8)
	disc.set_param("gloss", 0.1)
	c.add_child(disc)
	c.add_child(UI.tex(G.icon(icon), Rect2(rect.size.x * 0.21, rect.size.x * 0.2, rect.size.x * 0.58, rect.size.x * 0.58)))
	if text != "":
		c.add_child(UI.center_label(UI.label(text, 16, UI.INK, UI.DARK, 4), Rect2(-20, rect.size.x - 10, rect.size.x + 40, 24)))
	if badge:
		var d: = UI.rbox("gold", Rect2(rect.size.x - 18, 2, 14, 14), 7, 1, 3)
		d.colors(Color("ffe7a6"), Color("ff8fb0"))
		c.add_child(d)
		var t: Tween = d.create_tween().set_loops()
		d.pivot_offset = Vector2(7, 7)
		t.tween_property(d, "scale", Vector2(1.2, 1.2), 0.45).set_trans(Tween.TRANS_SINE)
		t.tween_property(d, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_SINE)
	c.gui_input.connect( func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			Sfx.play("pop")
			UI.punch(c, 0.15)
			cb.call())
	parent.add_child(c)
	return c

static func progress_bar(parent: Control, rect: Rect2, frac: float, pal: = "mint") -> RBox:
	var bg: = UI.rbox("cream", rect, rect.size.y * 0.5, 2, 6)
	bg.colors(Color(0.04, 0.035, 0.045, 0.55), Color(0.1, 0.09, 0.11, 0.65))
	bg.set_param("shadow_color", Color(0, 0, 0, 0))
	parent.add_child(bg)
	var w: float = max(rect.size.y, (rect.size.x - 6) * clamp(frac, 0.0, 1.0))
	var fg: = UI.rbox(pal, Rect2(3, 3, w, rect.size.y - 6), (rect.size.y - 6) * 0.5, 0, 4)
	fg.set_param("shadow_color", Color(0, 0, 0, 0))
	bg.add_child(fg)
	return fg


static func popup(main, title: String, h: float, pal: = "cream", w: = 660.0, closable: = true) -> RBox:
	var vs: Vector2 = main.get_viewport_rect().size
	var root: = Control.new()
	root.size = vs
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.set_meta("popup", true)
	main.overlay.add_child(root)
	var dim: = ColorRect.new()
	dim.size = vs
	dim.color = Color(0.03, 0.02, 0.035, 0.0)
	root.add_child(dim)
	dim.create_tween().tween_property(dim, "color:a", 0.72, 0.25)
	var y: float = max(150.0, (vs.y - h) * 0.5)
	var p: = UI.rbox(pal, Rect2((vs.x - w) * 0.5, y, w, h), 34, 5, 16)
	p.set_param("pattern", 1.0)
	root.add_child(p)
	p.set_meta("root", root)
	p.pivot_offset = p.size * 0.5
	UI.pop_in(p, 0.0, 0.85)
	if title != "":

		var rib: = ribbon(p, title, Rect2(w * 0.5 - 220, -38, 440, 72), "pink", 30)
		rib.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for sx in [-1, 1]:
			var dmd: = UI.rbox("gold", Rect2(w * 0.5 + sx * 236 - 9, -11, 18, 18), 3, 2, 4)
			dmd.pivot_offset = Vector2(9, 9)
			dmd.rotation = PI * 0.25
			p.add_child(dmd)
	if not closable:
		return p
	var x: = JButton.make("", "graphite", Rect2(w - 54, -20, 64, 64), null, 30)
	x.add_child(UI.tex(G.icon("close"), Rect2(15, 15, 34, 34)))
	x.pressed.connect( func(): close_popup(p))
	p.add_child(x)
	dim.gui_input.connect( func(e):
		if e is InputEventMouseButton and e.pressed:
			close_popup(p))
	return p

static func close_popup(p: Control) -> void :
	if not is_instance_valid(p) or not p.has_meta("root"):
		return
	var root: Control = p.get_meta("root")
	if root.has_meta("closing"):
		return
	root.set_meta("closing", true)
	Sfx.play("tap")
	var t: Tween = root.create_tween()
	t.tween_property(root, "modulate:a", 0.0, 0.18)
	t.tween_callback(root.queue_free)
	if root.has_meta("on_close"):
		(root.get_meta("on_close") as Callable).call()

static func chip(parent: Control, icon: Texture2D, text: String, rect: Rect2, pal: = "plum", fsize: = 20) -> RBox:
	var b: = UI.rbox(pal, rect, rect.size.y * 0.5, 3, 8)
	if pal == "plum":
		b.set_param("border_top", Color("ffe7a6")).set_param("border_bottom", Color("c58a2c"))
	parent.add_child(b)
	var x0: = 14.0
	if icon:
		b.add_child(UI.tex(icon, Rect2(-6, -8, rect.size.y + 16, rect.size.y + 16)))
		x0 = rect.size.y + 8
	var l: = UI.label(text, fsize, Color.WHITE if pal in ["plum", "pink", "lav", "red"] else UI.INK, Color(0.2, 0.05, 0.2, 0.9) if pal in ["plum", "pink", "lav", "red"] else Color.WHITE, 3, "body", 900)
	l.position = Vector2(x0, 0)
	l.size = Vector2(rect.size.x - x0 - 10, rect.size.y)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.name = "L"
	b.add_child(l)
	return b

static func badge(parent: Control, n: int, pos: Vector2) -> Control:
	var d: = UI.rbox("red", Rect2(pos, Vector2(30, 30)), 15, 2, 4)
	parent.add_child(d)
	if n > 0:
		d.add_child(UI.center_label(UI.label(str(n), 17, Color.WHITE, Color("6a1020"), 3, "body", 900), Rect2(0, 0, 30, 30)))
	d.pivot_offset = Vector2(15, 15)
	var t: Tween = d.create_tween().set_loops()
	t.tween_property(d, "scale", Vector2(1.18, 1.18), 0.45).set_trans(Tween.TRANS_SINE)
	t.tween_property(d, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_SINE)
	return d

static func avatar(hero: String, r: Rect2, ring_pal: = "gold") -> Control:
	var c: = Control.new()
	c.position = r.position
	c.size = r.size
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(UI.rbox(ring_pal, Rect2(Vector2.ZERO, r.size), r.size.x * 0.5, 3, 8))
	var t: = UI.tex(load("res://assets/hero/%s.png" % hero), Rect2(Vector2(5, 5), r.size - Vector2(10, 10)), false)
	var m: = ShaderMaterial.new()
	m.shader = preload("res://shaders/card.gdshader")
	var rig: Dictionary = Hero.RIGS[hero]
	m.set_shader_parameter("size", t.size)
	m.set_shader_parameter("radius", t.size.x * 0.5)
	m.set_shader_parameter("tex_size", Vector2(848, 1264))
	m.set_shader_parameter("focus", Vector2(rig.head_c.x / 848.0, (rig.head_c.y + 15) / 1264.0))
	m.set_shader_parameter("zoom", 4.6)
	m.set_shader_parameter("bottom_shade", 0.0)
	t.material = m
	t.name = "Pic"
	c.add_child(t)
	return c


static func rank_emblem(parent: Control, r: Rect2, tier: int, sub: int) -> Control:
	var c: = Control.new()
	c.position = r.position
	c.size = r.size
	c.pivot_offset = r.size * 0.5
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(c)
	var rk: Dictionary = G.RANKS[tier]
	var glow: = Sprite2D.new()
	glow.texture = G.fx("glow")
	glow.material = Fx.add_mat()
	glow.position = r.size * 0.5
	glow.scale = Vector2.ONE * r.size.x / 70.0
	glow.modulate = Color(rk.color.r, rk.color.g, rk.color.b, 0.5)
	c.add_child(glow)
	var outer: = UI.rbox("gold", Rect2(Vector2.ZERO, r.size), r.size.x * 0.5, 4, 8)
	c.add_child(outer)
	var inner: = UI.rbox("gold", Rect2(r.size * 0.12, r.size * 0.76), r.size.x * 0.38, 2, 4)
	inner.colors(rk.color.lightened(0.15), rk.color.darkened(0.35)).borders(Color(1, 1, 1, 0.6), rk.dark)
	inner.set_param("shadow_color", Color(0, 0, 0, 0))
	c.add_child(inner)
	var gem: = Sprite2D.new()
	gem.texture = G.fx("sparkle")
	gem.position = r.size * Vector2(0.5, 0.42)
	gem.scale = Vector2.ONE * r.size.x / 150.0
	gem.modulate = Color(1, 1, 1, 0.9)
	c.add_child(gem)
	var txt: String = G.ROMAN[sub] if tier < G.RANKS.size() - 1 else str(sub + 1)
	var l: = UI.center_label(UI.label(txt, int(r.size.x * 0.3), Color.WHITE, rk.dark, 4, "title", 900), Rect2(0, r.size.y * 0.36, r.size.x, r.size.y * 0.5))
	c.add_child(l)
	return c


static func skin_picker(main, on_done: Callable) -> void :
	var skins: = G.ITEMS.filter( func(x): return x.cat == "skin")
	var p: = popup(main, V6Txt.s("skins.title"), 120 + ((skins.size() + 2) / 3) * 230 + 40)
	for k in skins.size():
		var it: Dictionary = skins[k]
		var own: = G.owns(it.id)
		var on: bool = G.S.get("skin", "s_sakura") == it.id
		var r: = Rect2(30 + (k % 3) * 204, 64 + (k / 3) * 230, 190, 214)
		var card: = UI.rbox("gold" if on else "plum", r, 22, 3, 8)
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		p.add_child(card)
		var tile: = Tile.new()
		tile.face = it.tile
		tile.position = Vector2(95, 86)
		tile.scale = Vector2(1.25, 1.25)
		card.add_child(tile)
		tile.build(G.SKIN_LOOK.get(it.id, {}))
		if not own:
			tile.modulate = Color(0.45, 0.42, 0.5)
		var nm: = UI.center_label(UI.label(it.name.replace("Фишки ", ""), 17, Color.WHITE, Color(0.1, 0.05, 0.2), 3, "body", 900), Rect2(0, 158, 190, 26))
		card.add_child(nm)
		var how: = V6Txt.s("skins.on") if on else (V6Txt.s("skins.pick") if own else G.skin_source(it.id))
		var st: = UI.center_label(UI.label(how, 14, Color("ffd34d") if on else Color("d9c4e6")), Rect2(0, 184, 190, 22))
		card.add_child(st)
		card.gui_input.connect( func(e):
			if e is InputEventMouseButton and e.pressed:
				if not own:
					main.toast(V6Txt.s("skins.where") % [it.name.replace("Фишки ", ""), G.skin_source(it.id)], "gift")
					return
				Sfx.play("pop")
				G.S.skin = it.id
				G.save()
				main.toast(V6Txt.s("skins.set") % it.name.replace("Фишки ", ""), "star")
				close_popup(p)
				on_done.call())



# 0.8: confirmation before spending currency (spec: no spend without Common.confirm).
#   Common.confirm(main, title, text, price_icon, price, on_yes, opts) -> RBox (null if skipped via skip_key)
#   price_icon: G.icon name ("gem", "coin", "ticket"…) or "" for no price row; price: amount shown.
#   opts: skip_key: String  — shows «Не спрашивать в этой партии»; when ticked and confirmed, later calls with
#                             the same key call on_yes at once. Make the key per match, e.g. "hint_%d" % get_instance_id().
#         on_no: Callable   — called on «Отмена», ×, or tap outside.
#         yes_text / no_text: String — button captions (default «Да» / «Отмена»).
#         balance_check: bool (default true) — for gem/coin prices: if the player cannot pay, «Да» is disabled.
# The callback never spends anything itself: on_yes does the spending.
static var confirm_skips: = {}

static func confirm_skip_reset(prefix: = "") -> void :
	if prefix == "":
		confirm_skips.clear()
		return
	for k in confirm_skips.keys():
		if str(k).begins_with(prefix):
			confirm_skips.erase(k)


static func confirm(main, title: String, text: String, price_icon: String, price: int, on_yes: Callable, opts: = {}) -> RBox:
	var skip_key: String = str(opts.get("skip_key", ""))
	if skip_key != "" and confirm_skips.get(skip_key, false):
		on_yes.call()
		return null
	var w: = 600.0
	var tw: = w - 80.0
	var tsize: = 24
	var text_h: float = UI.font("body", 800).get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, tw, tsize).y + 8.0
	var has_price: = price_icon != "" and price > 0
	var balance: = -1
	if has_price and opts.get("balance_check", true):
		if price_icon == "gem":
			balance = int(G.S.gems)
		elif price_icon == "coin":
			balance = int(G.S.coins)
	var short: = balance >= 0 and balance < price
	var h: = 64.0 + text_h + 24.0
	if has_price:
		h += 70.0 + (34.0 if balance >= 0 else 0.0) + 14.0
	if skip_key != "":
		h += 62.0
	h += 92.0 + 34.0
	var p: = popup(main, title, h, "cream", w)
	var root: Control = p.get_meta("root")
	var done: = [false]
	var y: = 64.0
	var tl: = UI.label(text, tsize, UI.INK, UI.DARK, 3, "body", 800)
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tl.position = Vector2(40, y)
	tl.size = Vector2(tw, text_h)
	p.add_child(tl)
	y += text_h + 24.0
	if has_price:
		var num: = UI.fmt(price)
		var nw: float = UI.font("body", 900).get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x
		var pw: = clampf(nw + 112.0, 170.0, 360.0)
		var pill: = UI.rbox("plum", Rect2((w - pw) * 0.5, y, pw, 64), 32, 3, 8)
		pill.set_param("border_top", Color("ffe7a6")).set_param("border_bottom", Color("c58a2c"))
		p.add_child(pill)
		pill.add_child(UI.tex(G.icon(price_icon), Rect2(10, 2, 60, 60)))
		var pl: = UI.label(num, 34, Color("ff9a9a") if short else Color.WHITE, Color(0.2, 0.05, 0.2), 4, "body", 900)
		pl.position = Vector2(76, 0)
		pl.size = Vector2(pw - 92, 64)
		pl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pill.add_child(pl)
		y += 70.0
		if balance >= 0:
			var bt: String = ("Не хватает: у тебя %s" if short else "У тебя: %s") % UI.fmt(balance)
			p.add_child(UI.center_label(UI.label(bt, 19, Color("ff9a9a") if short else UI.MUTED, UI.DARK, 2, "body", 800), Rect2(0, y, w, 30)))
			y += 34.0
		y += 14.0
	var skip: = [false]
	if skip_key != "":
		var row: = Control.new()
		row.position = Vector2(0, y)
		row.size = Vector2(w, 52)
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		p.add_child(row)
		var cap: = "Не спрашивать в этой партии"
		var cw: float = UI.font("body", 800).get_string_size(cap, HORIZONTAL_ALIGNMENT_LEFT, -1, 21).x
		var x0: = (w - (44.0 + 14.0 + cw)) * 0.5
		var box: = UI.rbox("glass", Rect2(x0, 4, 44, 44), 12, 3, 6)
		box.set_param("border_top", Color("ffe7a6")).set_param("border_bottom", Color("c58a2c"))
		row.add_child(box)
		var mark: = UI.center_label(UI.label("✓", 30, Color("ffd34d"), UI.DARK, 3, "body", 900), Rect2(0, 0, 44, 44))
		mark.visible = false
		box.add_child(mark)
		var cl: = UI.label(cap, 21, UI.INK, UI.DARK, 2, "body", 800)
		cl.position = Vector2(x0 + 58, 0)
		cl.size = Vector2(cw + 8, 52)
		cl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(cl)
		row.gui_input.connect( func(e):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				skip[0] = not skip[0]
				mark.visible = skip[0]
				Sfx.play("tap")
				UI.punch(box, 0.15))
		y += 62.0
	var bw: = (w - 60.0 - 20.0) * 0.5
	var no: = JButton.make(str(opts.get("no_text", "Отмена")), "glass", Rect2(30, y + 4, bw, 84), null, 28)
	p.add_child(no)
	var yes: = JButton.make(str(opts.get("yes_text", "Да")), "glass" if short else "gold", Rect2(50 + bw, y + 4, bw, 84), null, 30)
	if short:
		yes.modulate = Color(1, 1, 1, 0.55)
	else:
		yes.shine_every = 2.6
	p.add_child(yes)
	root.set_meta("on_close", func():
		if not done[0]:
			done[0] = true
			var cb_no = opts.get("on_no")
			if cb_no is Callable and (cb_no as Callable).is_valid():
				(cb_no as Callable).call())
	no.pressed.connect( func(): close_popup(p))
	yes.pressed.connect( func():
		if done[0]:
			return
		if short:
			UI.punch(yes, 0.12)
			if main.has_method("toast"):
				main.toast("Не хватает %s" % ("кристаллов" if price_icon == "gem" else "монет"), price_icon)
			return
		done[0] = true
		if skip[0] and skip_key != "":
			confirm_skips[skip_key] = true
		close_popup(p)
		on_yes.call())
	return p


static func living_art(parent: Control, tex: Texture2D, r: Rect2, focus: = Vector2(0.5, 0.35)) -> TextureRect:
	var art: = card_art(tex, r, focus, 1.0, 0.0)
	(art.material as ShaderMaterial).set_shader_parameter("bottom_shade", 0.0)
	art.pivot_offset = r.size * Vector2(0.5, 0.4)
	parent.add_child(art)
	var t: = art.create_tween().set_loops()
	t.tween_property(art, "scale", Vector2(1.035, 1.035), 3.2).set_trans(Tween.TRANS_SINE)
	t.tween_property(art, "scale", Vector2.ONE, 3.2).set_trans(Tween.TRANS_SINE)
	return art
