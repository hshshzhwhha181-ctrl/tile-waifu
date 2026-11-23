extends Control


var main
var W: = 720.0
var H: = 1280.0
var cur: = "mc"
var stage: Control

const ROW_Y: = V8Header.CONTENT_Y + 6.0
const AV: = 104.0
const BODY_Y: = ROW_Y + AV + 14.0

var preview_root: Control

const STAGE_BG: = {"mc": "menu", "rin": "bg_teahouse", "hana": "bg_street", "yue": "bg_palace", "nova": "bg_neon"}

func build(m, args: Dictionary) -> void :
	main = m
	W = size.x
	H = size.y
	main.show_chrome(true, true)
	Sfx.music("menu")
	cur = args.get("hero", G.S.partner)
	_build()

func _unlocked(h: String) -> bool:
	return G.hero_unlocked(h)

func _build() -> void :
	if stage:
		stage.queue_free()
	stage = Control.new()
	stage.size = size
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)
	move_child(stage, 0)
	var bg: String = STAGE_BG[cur]
	Common.backdrop(stage, bg, size, 2.2 if bg != "menu" else 0.0, 0.82, Color(1, 0.96, 0.98), Vector2(0.5, 0.5))
	Common.vignette(stage, size, Color(0.3, 0.1, 0.25), 0.55)
	Fx.ambient(stage, "fireflies", size)
	V8Header.make(stage, main, "Гардероб", main.back)
	set_meta("v8_back", main.back)

	var x: = 24.0 + (112.0 - AV) * 0.5
	for h in G.HERO_ORDER:
		var on: bool = h == cur
		var unl: = _unlocked(h)
		var ring: = UI.rbox("pink" if on else ("gold" if unl else "plum"), Rect2(x, ROW_Y, AV, AV), AV * 0.5, 4, 10)
		stage.add_child(ring)
		var av: TextureRect = main._avatar(h, Rect2(x + 7, ROW_Y + 7, AV - 14, AV - 14))
		if not unl:
			(av.material as ShaderMaterial).set_shader_parameter("gray", 1.0)
		stage.add_child(av)
		if not unl:
			stage.add_child(UI.tex(G.fx("lock"), Rect2(x + AV * 0.5 - 16, ROW_Y + AV * 0.5 - 16, 32, 32)))
		var hh: String = h
		var hit: = Control.new()
		hit.position = Vector2(x, ROW_Y)
		hit.size = Vector2(AV, AV)
		hit.mouse_filter = Control.MOUSE_FILTER_STOP
		hit.gui_input.connect( func(e):
			if e is InputEventMouseButton and e.pressed:
				Sfx.play("tap")
				if hh != cur:
					cur = hh
					_build())
		stage.add_child(hit)
		if on:
			ring.pivot_offset = Vector2(AV, AV) * 0.5
			UI.punch(ring, 0.12)
		x += 136

	var floor_y: = H - 132 - 250
	var ped: = Sprite2D.new()
	ped.texture = G.fx("glow")
	ped.material = Fx.add_mat()
	ped.position = Vector2(W * 0.34, floor_y)
	ped.scale = Vector2(5.5, 1.2)
	ped.modulate = Color(G.HEROES[cur].color.r, G.HEROES[cur].color.g, G.HEROES[cur].color.b, 0.6)
	stage.add_child(ped)
	var unl: = _unlocked(cur)
	var hero: = Hero.new().setup(cur, min(floor_y - BODY_Y - 10.0, 860.0))
	hero.position = Vector2(W * 0.34, floor_y)
	stage.add_child(hero)
	var oid: = G.equipped(cur)
	if oid != "" and _unlocked(cur):
		var fr: = UI.rbox("gold", Rect2(14, BODY_Y, W - 334, floor_y - BODY_Y - 14), 24, 4, 10)
		stage.add_child(fr)
		Common.living_art(fr, G.art_tex(G.ITEM[oid]), Rect2(6, 6, fr.size.x - 12, fr.size.y - 12), Vector2(0.5, 0.3))
		hero.visible = false
	if not unl:
		hero.mat.set_shader_parameter("silhouette", 0.92)
		hero.interactive = false
	else:
		hero.tapped.connect( func():
			hero.react("happy")
			Fx.burst(stage, hero.head_global(), "heart", 8)
			Sfx.say(cur, "aff"))
	UI.slide_in(hero, Vector2(-60, 0), 0.0, 0.5)

	var ic: = UI.rbox("glass", Rect2(W - 300, BODY_Y, 280, 400), 28, 4, 12)
	stage.add_child(ic)
	var nm: = UI.title(G.HEROES[cur].name, 32, UI.INK, Color.WHITE)
	nm.position = Vector2(20, 14)
	ic.add_child(nm)
	var tl: = UI.label(G.HEROES[cur].title, 20, Color("b8406c"), Color.WHITE, 3, "body", 900)
	tl.position = Vector2(22, 70)
	ic.add_child(tl)
	ic.add_child(UI.tex(G.icon("heart"), Rect2(14, 110, 56, 56)))
	var al: = UI.label(V6Txt.s("coll.aff") % G.aff_level(cur), 22, UI.INK, Color.WHITE, 3, "body", 900)
	al.position = Vector2(74, 116)
	ic.add_child(al)
	Common.progress_bar(ic, Rect2(76, 148, 186, 18), float(int(G.S.aff.get(cur, 0)) % 100) / 100.0, "pink")
	var owned: = 0
	var total: = 0
	for it in G.ITEMS:
		if it.get("hero", "") == cur:
			total += 1
			if G.owns(it.id):
				owned += 1
	var ol: = UI.label(V6Txt.s("coll.outfits") % [owned, total], 20, UI.INK)
	ol.position = Vector2(22, 182)
	ic.add_child(ol)
	var perks: = UI.label(V6Txt.s("coll.bonus") % (5 * G.aff_level(cur)), 18, Color("7a4a6a"))
	perks.position = Vector2(22, 214)
	ic.add_child(perks)
	if unl:
		var pb: = JButton.make(V6Txt.s("coll.partner_on") if G.S.partner == cur else V6Txt.s("coll.partner"), "pink" if G.S.partner != cur else "mint", Rect2(18, 272, 244, 62), null, 22)
		pb.pressed.connect( func():
			G.S.partner = cur
			G.save()
			Sfx.say(cur, "outfit")
			main.toast(V6Txt.s("coll.partner_toast") % G.HEROES[cur].name, "heart")
			_build())
		ic.add_child(pb)
		var vb: = JButton.make(V6Txt.s("coll.voice"), "lav", Rect2(18, 340, 118, 50), null, 20)
		vb.pressed.connect( func(): Sfx.say(cur, "greet");hero.react("happy"))
		ic.add_child(vb)
		var tb: = JButton.make(V6Txt.s("coll.skins"), "lav", Rect2(144, 340, 118, 50), null, 20)
		tb.pressed.connect( func(): Common.skin_picker(main, func(): pass))
		ic.add_child(tb)
	else:
		var lb: = UI.label(V6Txt.s("coll.shards") % [mini(int(G.S.shards.get(cur, 0)), G.SHARDS_NEED), G.SHARDS_NEED], 22, Color("7a4a6a"), Color.WHITE, 3, "body", 900)
		lb.position = Vector2(22, 280)
		ic.add_child(lb)
		var go: = JButton.make(V6Txt.s("coll.to_wish"), "lav", Rect2(18, 336, 244, 54), null, 22)
		go.pressed.connect( func(): main.go("summon", {"banner": 1 if cur == "nova" else 0}))
		ic.add_child(go)
	UI.slide_in(ic, Vector2(60, 0), 0.1)

	var strip: = UI.rbox("cream", Rect2(14, H - 132 - 236, W - 28, 226), 28, 4, 12)
	strip.set_param("pattern", 1.0)
	stage.add_child(strip)
	# 0.8: the screen header already says «Гардероб»; the strip counts this heroine's outfits
	var n_own: = G.ITEMS.filter( func(x): return x.get("hero", "") == cur and G.owns(x.id)).size()
	var n_all: = G.ITEMS.filter( func(x): return x.get("hero", "") == cur).size()
	var st: = UI.label("Наряды · %d/%d" % [n_own, n_all], 20, UI.INK, Color.WHITE, 3, "body", 900)
	st.position = Vector2(20, 8)
	strip.add_child(st)
	V7AlbumView.collection_button(strip, main, _build)
	var cx: = 16.0
	var n_items: = G.ITEMS.filter( func(x): return x.get("hero", "") == cur).size()
	var cw: = clampf((strip.size.x - 32.0 - (n_items - 1) * 8.0) / maxf(1.0, n_items), 96.0, 118.0)
	for it in G.ITEMS:
		if it.get("hero", "") != cur:
			continue
		var own: bool = G.owns(it.id)
		var worn: bool = G.S.outfit.get(cur, "") == it.id or (G.S.outfit.get(cur, "") == "" and it.id in G.BASE_OUTFITS)
		var pal: = "gold" if it.rar == "SSR" else ("lav" if it.rar == "SR" else "sky")
		var card: = UI.rbox(pal, Rect2(cx, 44, cw, 168), 14, 3, 6)
		strip.add_child(card)
		var art: = Common.card_art(G.art_tex(it), Rect2(4, 4, cw - 8, 160), Vector2(0.5, 0.3), 1.0, 10)
		var am: ShaderMaterial = art.material
		if not own:
			am.set_shader_parameter("gray", 1.0)
			am.set_shader_parameter("bottom_shade", 0.9)
		am.set_shader_parameter("holo", 0.4 if it.rar == "SSR" and own else 0.0)
		card.add_child(art)
		var rl: = UI.label(it.rar, 20, Color.WHITE, G.rar_color(it.rar).darkened(0.5), 4, "body", 900)
		rl.position = Vector2(8, 4)
		card.add_child(rl)
		if not own:
			card.add_child(UI.tex(G.fx("lock"), Rect2(cw * 0.5 - 18, 66, 36, 36)))
		if worn and own:
			card.set_param("glow", 1.0).set_param("glow_color", Color("ffe7a6"))
			# inside the card (middle, over the art), so it never covers the strip caption or the rarity tag
			var wl: = UI.rbox("pink", Rect2(cw * 0.5 - 36, 38, 72, 26), 13, 2, 4)
			card.add_child(wl)
			wl.add_child(UI.center_label(UI.label(V6Txt.s("coll.worn"), 16, Color.WHITE, Color("7a2346"), 3, "body", 900), Rect2(0, 0, 72, 26)))
		# 0.8: name at 16 px (never smaller), up to three lines inside the card instead of an ellipsis; the label
		# is at least as wide as the longest word (it may overhang the card edge a little), and wraps on word
		# bounds only, so a long word is never cut in the middle
		var nfs: = 16
		var nwt: = 800
		var nol: = 4
		if UI.longest_word_w(it.name, nfs, "body", nwt, nol) > cw + 4.0:
			# a long word («Императрица»): a lighter weight and a thinner outline before overhanging the card
			nwt = 700
			nol = 3
		var nw: = maxf(cw + 4.0, UI.longest_word_w(it.name, nfs, "body", nwt, nol) + 4.0)
		var nl: = UI.label(it.name, nfs, Color.WHITE, Color(0.2, 0.05, 0.2), nol, "body", nwt)
		nl.autowrap_mode = TextServer.AUTOWRAP_WORD
		nl.custom_minimum_size = Vector2(nw, 0)
		nl.position = Vector2((cw - nw) * 0.5, 80)
		nl.size = Vector2(nw, 84)
		nl.max_lines_visible = 3
		nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		card.add_child(nl)
		var itc: Dictionary = it
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.gui_input.connect( func(e):
			if e is InputEventMouseButton and e.pressed:
				Sfx.play("pop")
				if own:
					_preview(itc)
				else:
					main.toast(V6Txt.s("coll.missing") % itc.name, "wardrobe"))
		UI.pop_in(card, 0.1 + cx / 2000.0, 0.8)
		cx += cw + 8

func _preview(it: Dictionary) -> void :
	var root: = Control.new()
	root.size = size
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	preview_root = root
	var dim: = ColorRect.new()
	dim.size = size
	dim.color = Color(0.1, 0.03, 0.1, 0.85)
	root.add_child(dim)
	var aw: = W - 80.0
	var ah: = aw * 1.49
	var fr: = UI.rbox("gold", Rect2(32, (H - ah) * 0.5 - 8, aw + 16, ah + 16), 26, 5, 14)
	root.add_child(fr)
	var art: = Common.card_art(G.art_tex(it), Rect2(40, (H - ah) * 0.5, aw, ah), Vector2(0.5, 0.5), 1.0, 20)
	(art.material as ShaderMaterial).set_shader_parameter("holo", 0.3 if it.rar == "SSR" else 0.0)
	(art.material as ShaderMaterial).set_shader_parameter("bottom_shade", 0.3)
	root.add_child(art)
	Common.ribbon(root, it.name, Rect2(50, (H + ah) * 0.5 - 40, W - 100, 76), "pink", 30)
	var worn: bool = G.S.outfit.get(it.hero, "") == it.id or (G.S.outfit.get(it.hero, "") == "" and it.id in G.BASE_OUTFITS)
	var eb: = JButton.make(V6Txt.s("coll.wear_on") if worn else V6Txt.s("coll.wear"), "mint" if worn else "gold", Rect2(W * 0.5 - 160, (H + ah) * 0.5 + 50, 320, 84), null, 32)
	eb.shine_every = 0.0 if worn else 2.0
	eb.pressed.connect( func():
		G.S.outfit[it.hero] = it.id
		G.save()
		Sfx.say(it.hero, "outfit")
		main.toast(V6Txt.s("coll.wear_toast") % [G.HEROES[it.hero].name, it.name], "wardrobe")
		root.queue_free()
		_build())
	root.add_child(eb)
	UI.pop_in(fr, 0.0, 0.85)
	UI.pop_in(art, 0.0, 0.85)
	Sfx.say(it.hero, "outfit")
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect( func(e):
		if e is InputEventMouseButton and e.pressed:
			Sfx.play("tap")
			root.queue_free())

func handle_back() -> bool:
	if preview_root and is_instance_valid(preview_root) and not preview_root.is_queued_for_deletion():
		Sfx.play("tap")
		preview_root.queue_free()
		preview_root = null
		return true
	return false

func dev_act(a: String) -> void :
	if a == "album":
		V7AlbumView.open(main)
		return
	if a == "back":
		main.android_back()
		return
	if a == "preview":
		for it in G.ITEMS:
			if it.get("hero", "") == cur and G.owns(it.id):
				_preview(it)
				return
