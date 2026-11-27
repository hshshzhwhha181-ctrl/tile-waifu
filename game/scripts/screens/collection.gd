extends Control


var main
var W: = 720.0
var H: = 1280.0
var cur: = "mc"
var sel_oid: = ""
var stage: Control

const ROW_Y: = 96.0
const AV: = 104.0
const NAME_PAD: = 9.0
const NAME_PAD_K: = 0.3
const NAME_FOOT: = 13.0
const NAME_MIN_FS: = 14
const BODY_Y: = ROW_Y + AV + 14.0
const BASE_BY_HERO: = {"mc": "o_base", "rin": "r_base", "hana": "h_base", "yue": "y_base", "nova": "n_base"}

var preview_root: Control

const STAGE_BG: = {"mc": "menu", "rin": "bg_teahouse", "hana": "bg_street", "yue": "bg_palace", "nova": "bg_neon"}

# 0.12 wave 1: ten goddesses in one swipeable row of 92 px gold medallions (rarity pill under each, «NEW · Волна 1» on the five new)
const MEDAL: = 92.0
const MEDAL_STEP: = 112.0
const ROW_H: = 122.0
const W1_NEW: = ["tsubame", "miel", "kohaku", "shirin", "zlata"]
var row_scroll: ScrollContainer
var row_saved_x: = -1
var row_arrows: Array = []

func build(m, args: Dictionary) -> void :
	main = m
	W = size.x
	H = size.y
	main.show_chrome(true, true)
	Sfx.music("menu")
	cur = str(args.get("hero", G.S.partner))
	if not G.HEROES.has(cur):
		cur = "mc"
	var arg_item: = str(args.get("item", args.get("preview_item", "")))
	if arg_item != "" and G.ITEM.has(arg_item) and G.ITEM[arg_item].get("cat", "") == "outfit":
		cur = str(G.ITEM[arg_item].get("hero", cur))
		sel_oid = arg_item
	else:
		sel_oid = _default_oid(cur)
	for ua in OS.get_cmdline_user_args():
		if ua.begins_with("--preview_locked="):
			var pid: = ua.substr(17)
			if pid == "1":
				for it in G.ITEMS:
					if it.get("cat", "") == "outfit" and it.get("hero", "") == cur and not G.owns(it.id):
						sel_oid = str(it.id)
						break
			elif G.ITEM.has(pid):
				cur = str(G.ITEM[pid].get("hero", cur))
				sel_oid = pid
	_build()

func _default_oid(h: String) -> String:
	var eq: = str(G.S.outfit.get(h, ""))
	if eq != "" and G.ITEM.has(eq) and G.owns(eq):
		return eq
	var b: = str(BASE_BY_HERO.get(h, V10W1Core.base_of(h)))
	if b == "":
		b = "o_base"
	if G.ITEM.has(b):
		return b
	for it in G.ITEMS:
		if it.get("hero", "") == h:
			return str(it.id)
	return ""

func _unlocked(h: String) -> bool:
	return G.hero_unlocked(h)

func _equip_outfit(it: Dictionary) -> void:
	var h: = str(it.get("hero", cur))
	var oid: = str(it.get("id", ""))
	if oid == "" or not G.owns(oid):
		return
	G.S.outfit[h] = oid
	G.S.partner = h
	if V10Look.previewing():
		V10Look.end_preview()
	V10Look.notify()
	V10HudSkin.sync(V10Look.current())
	G.save()
	Sfx.say(h, "outfit")
	main.toast(V6Txt.s("coll.wear_toast") % [G.HEROES[h].name, it.name], "wardrobe")
	_build()

func _go_to_hero_banner(h: String, it: Dictionary = {}) -> void:
	var b_idx: = 0
	var oid: = str(it.get("id", ""))
	if V10Registry.wired("gacha"):
		var g2: = V10WishScreen.make_gacha()
		var bl: = g2.banners()
		var matched: = false
		for i in bl.size():
			var b: Dictionary = bl[i]
			var ssr_arr: Array = b.get("ssr", []) if b.get("ssr") is Array else []
			var sup_arr: Array = b.get("s_up", []) if b.get("s_up") is Array else []
			if oid != "" and (oid in ssr_arr or oid in sup_arr):
				b_idx = i
				matched = true
				break
		if not matched:
			for i in bl.size():
				var b2: Dictionary = bl[i]
				if str(b2.get("hero", "")) == h:
					b_idx = i
					matched = true
					break
	main.go("summon", {"banner": b_idx, "hero": h})

func _build() -> void :
	if row_scroll and is_instance_valid(row_scroll):
		row_saved_x = row_scroll.scroll_horizontal
	row_arrows.clear()
	if stage:
		stage.queue_free()
	if sel_oid == "" or not G.ITEM.has(sel_oid) or str(G.ITEM[sel_oid].get("hero", "")) != cur:
		sel_oid = _default_oid(cur)
	var sel_it: Dictionary = G.ITEM.get(sel_oid, {})
	var sel_own: bool = sel_oid != "" and G.owns(sel_oid)
	var cur_worn_id: = str(G.S.outfit.get(cur, ""))
	if cur_worn_id == "":
		cur_worn_id = str(BASE_BY_HERO.get(cur, V10W1Core.base_of(cur)))
	var sel_worn: bool = sel_own and (sel_oid == cur_worn_id)

	stage = Control.new()
	stage.size = size
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)
	move_child(stage, 0)
	var bg: String = STAGE_BG[cur] if STAGE_BG.has(cur) else V10W1Core.stage_bg(cur)
	Common.backdrop(stage, bg, size, 1.4 if bg != "menu" else 0.0, 0.94, Color(1, 0.98, 0.99), Vector2(0.5, 0.5))
	Common.vignette(stage, size, Color(0.24, 0.08, 0.20), 0.28)
	Fx.ambient(stage, "fireflies", size)
	V8Header.make(stage, main, "Героини", Callable())
	set_meta("v8_back", main.back)

	_hero_row()

	var strip_y: = H - 132.0 - 236.0
	var floor_y: = H - 132.0 - 250.0
	var ped: = Sprite2D.new()
	ped.texture = G.fx("glow")
	ped.material = Fx.add_mat()
	ped.position = Vector2(W * 0.28, floor_y)
	ped.scale = Vector2(5.5, 1.2)
	ped.modulate = Color(G.HEROES[cur].color.r, G.HEROES[cur].color.g, G.HEROES[cur].color.b, 0.55)
	stage.add_child(ped)
	var unl: = _unlocked(cur)
	var hero: = Hero.new().setup(cur, min(floor_y - BODY_Y - 10.0, 860.0))
	hero.position = Vector2(W * 0.28, floor_y)
	hero.interactive = false
	stage.add_child(hero)

	# Full-color, full-size portrait showcase for ANY selected outfit (owned OR locked!)
	if not sel_it.is_empty():
		var fr_w: = W - 320.0
		var fr_h: = maxf(320.0, strip_y - 24.0 - BODY_Y)
		var fr_wrap: = Control.new()
		fr_wrap.name = "PortraitFrame"
		fr_wrap.position = Vector2(14, BODY_Y)
		fr_wrap.size = Vector2(fr_w, fr_h)
		fr_wrap.mouse_filter = Control.MOUSE_FILTER_STOP
		stage.add_child(fr_wrap)
		var fr_clip: = Control.new()
		fr_clip.position = Vector2(4, 4)
		fr_clip.size = Vector2(fr_w - 8.0, fr_h - 8.0)
		fr_clip.clip_contents = true
		fr_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fr_wrap.add_child(fr_clip)
		var atr: = TextureRect.new()
		atr.texture = G.art_tex(sel_it)
		atr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		atr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		atr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		atr.position = Vector2.ZERO
		atr.size = fr_clip.size
		atr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fr_clip.add_child(atr)
		# Subtle bottom gradient inside portrait so footer caption & zoom button pop cleanly
		var foot_sh: = Common.edge_shade(fr_clip, Rect2(0, fr_clip.size.y - 118.0, fr_clip.size.x, 118.0), -1, Color(0.06, 0.02, 0.09), 0.86)
		foot_sh.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var fr_rim: = Panel.new()
		fr_rim.position = Vector2.ZERO
		fr_rim.size = fr_wrap.size
		fr_rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var fsb: = StyleBoxFlat.new()
		fsb.bg_color = Color(0, 0, 0, 0)
		fsb.border_color = Color("ffe394") if not sel_own else Color("f6d483")
		fsb.set_border_width_all(4)
		fsb.set_corner_radius_all(16)
		fsb.shadow_color = Color(0.0, 0.0, 0.0, 0.48)
		fsb.shadow_size = 12
		fr_rim.add_theme_stylebox_override("panel", fsb)
		fr_wrap.add_child(fr_rim)

		# Locked outfit preview badge: stylish gold-rimmed obsidian pill «Предпросмотр · Закрыт»
		if not sel_own:
			var pv_badge: = Panel.new()
			pv_badge.name = "LockedPreviewBadge"
			var bsb: = StyleBoxFlat.new()
			bsb.bg_color = Color(0.11, 0.05, 0.16, 0.92)
			bsb.border_color = Color("f8df95")
			bsb.set_border_width_all(2)
			bsb.set_corner_radius_all(18)
			bsb.shadow_color = Color(0, 0, 0, 0.45)
			bsb.shadow_size = 6
			pv_badge.add_theme_stylebox_override("panel", bsb)
			pv_badge.position = Vector2(12, 12)
			pv_badge.size = Vector2(minf(fr_w - 24.0, 268.0), 38.0)
			pv_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			pv_badge.add_child(V8Art.rect(V8Art.icon("lock"), Rect2(10, 6, 26, 26)))
			var b_lbl: = UI.label("Предпросмотр · Закрыт", 17, Color("ffe8a3"), Color(0.06, 0.02, 0.09), 3, "body", 900)
			b_lbl.position = Vector2(40, 0)
			b_lbl.size = Vector2(pv_badge.size.x - 46.0, 38.0)
			b_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			pv_badge.add_child(b_lbl)
			fr_wrap.add_child(pv_badge)

		# Outfit title + rarity pill at bottom-left of portrait frame
		var rar_s: = V10Rank.label(str(sel_it.get("rar", "R")))
		var r_col: = G.rar_color(str(sel_it.get("rar", "R"))).lerp(Color.WHITE, 0.38)
		var oname_lbl: = UI.label("%s · %s" % [rar_s, str(sel_it.get("name", ""))], 19, r_col, Color(0.05, 0.02, 0.08), 4, "body", 900)
		oname_lbl.position = Vector2(16, fr_h - 50.0)
		oname_lbl.size = Vector2(fr_w - 162.0, 36.0)
		oname_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		Common.fit_line(oname_lbl, fr_w - 162.0, 14)
		fr_wrap.add_child(oname_lbl)

		# Fullscreen Inspection («Лупа / Осмотр») button on bottom-right of portrait frame
		var zoom_btn: = Panel.new()
		zoom_btn.name = "InspectBtn"
		var zsb: = StyleBoxFlat.new()
		zsb.bg_color = Color(0.14, 0.07, 0.20, 0.92)
		zsb.border_color = Color("f8df95")
		zsb.set_border_width_all(2)
		zsb.set_corner_radius_all(21)
		zoom_btn.add_theme_stylebox_override("panel", zsb)
		zoom_btn.position = Vector2(fr_w - 138.0, fr_h - 54.0)
		zoom_btn.size = Vector2(126.0, 42.0)
		zoom_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		var l_ic: = _LoupeIcon.new()
		l_ic.position = Vector2(10, 7)
		l_ic.size = Vector2(28, 28)
		zoom_btn.add_child(l_ic)
		var z_lbl: = UI.label("Осмотр", 17, Color("ffe8a3"), Color(0.06, 0.02, 0.09), 3, "body", 900)
		z_lbl.position = Vector2(40, 0)
		z_lbl.size = Vector2(80, 42)
		z_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		zoom_btn.add_child(z_lbl)
		zoom_btn.gui_input.connect(func(e: InputEvent) -> void:
			if (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and e.pressed):
				zoom_btn.accept_event()
				V9Feel.press(zoom_btn, "tap")
				_open_inspect(sel_it))
		fr_wrap.add_child(zoom_btn)

		fr_wrap.gui_input.connect(func(e: InputEvent) -> void:
			if (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and e.pressed):
				fr_wrap.accept_event()
				_open_inspect(sel_it))
		hero.visible = false
		UI.pop_in(fr_wrap, 0.0, 0.96)
	else:
		UI.slide_in(hero, Vector2(-60, 0), 0.0, 0.5)

	# Right Heroine & Outfit Action Card (0.12: V10AffCurve progress + next 16+ rubezh, «Будуар ♥», Wave-1 ready)
	var card_w: = 284.0
	var card_h: = minf(572.0, floor_y - BODY_Y - 8.0)
	var ic: = UI.rbox("glass", Rect2(W - 300, BODY_Y, card_w, card_h), 28, 4, 12)
	ic.name = "HeroCard"
	stage.add_child(ic)
	var max_nw: = card_w - 88.0
	var nm: = UI.title(G.HEROES[cur].name, 28, Color("fff6e8"), UI.DARK)
	nm.position = Vector2(18, 12)
	var nm_ls: LabelSettings = nm.label_settings
	var nm_pad: = float(nm_ls.outline_size)
	for fs in [28, 24, 22, 20]:
		var f: Font = UI.font_for("title", fs, 900)
		nm_ls.font = f
		nm_ls.font_size = fs
		if f.get_string_size(nm.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + nm_pad <= max_nw:
			break
	nm.size = Vector2(max_nw, 42.0)
	nm.clip_text = true
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	ic.add_child(nm)
	var h_rank: = _hero_rank(cur)
	var rk_col: Color = V10Rank.color(h_rank)
	var rk_w: = 54.0
	var rk_pill: = UI.rbox("graphite", Rect2(ic.size.x - rk_w - 14.0, 16, rk_w, 28), 14, 2, 3)
	rk_pill.borders(rk_col.lerp(Color.WHITE, 0.35), rk_col.darkened(0.45))
	rk_pill.name = "HeroRankPill"
	ic.add_child(rk_pill)
	rk_pill.add_child(UI.center_label(UI.label(h_rank, 18, rk_col.lerp(Color.WHITE, 0.45), UI.DARK, 3, "body", 900), Rect2(0, -1, rk_w, 28)))
	var tl: = UI.label(G.HEROES[cur].title, 18, Color("ffb3cc"), UI.DARK, 3, "body", 900)
	tl.position = Vector2(20, 58)
	Common.fit_line(tl, 246.0, 15)
	ic.add_child(tl)

	# affection on the heavy V10AffCurve (levels 1-20) with the next 16+ rubezh
	var ai: Dictionary = G.aff_info(cur)
	ic.add_child(V8Art.rect(V8Art.icon("heart"), Rect2(16, 88, 46, 46)))
	var al: = UI.label(V6Txt.s("coll.aff") % int(ai.get("level", 1)), 21, Color("fff6e8"), UI.DARK, 3, "body", 900)
	al.position = Vector2(68, 90)
	ic.add_child(al)
	var a_bar: = Common.progress_bar(ic, Rect2(70, 120, 194, 16), float(ai.get("ratio", 0.0)), "pink")
	a_bar.name = "AffBar"
	var a_txt: = "Максимум ♥" if bool(ai.get("is_max", false)) else "%s / %s" % [UI.fmt(int(ai.get("into", 0))), UI.fmt(int(ai.get("need", 1)))]
	var a_num: = UI.label(a_txt, 15, Color("e6d8ec"), UI.DARK, 3, "body", 800)
	a_num.position = Vector2(70, 140)
	ic.add_child(a_num)
	var m16: = _next_16(int(ai.get("level", 1)))
	var m16_t: = "Все рубежи 16+ открыты ♥" if m16.is_empty() else "Рубеж 16+ · Ур. %d" % int(m16.get("level", 0))
	var m16_l: = UI.label(m16_t, 17, Color("ff9fc2"), UI.DARK, 3, "body", 900)
	m16_l.name = "Next16Label"
	m16_l.position = Vector2(20, 166)
	Common.fit_line(m16_l, 246.0, 13)
	ic.add_child(m16_l)
	if not m16.is_empty():
		var m16_n: = UI.label("«%s»" % str(m16.get("title", "")), 15, Color("e6d8ec"), UI.DARK, 3, "body", 800)
		m16_n.position = Vector2(20, 188)
		Common.fit_line(m16_n, 246.0, 12)
		ic.add_child(m16_n)
	var owned: = 0
	var total: = 0
	for it in G.ITEMS:
		if it.get("hero", "") == cur:
			total += 1
			if G.owns(it.id):
				owned += 1
	var ol: = UI.label(V6Txt.s("coll.outfits") % [owned, total], 19, Color("e6d8ec"), UI.DARK, 3, "body", 800)
	ol.position = Vector2(20, 214)
	ic.add_child(ol)

	# Selected outfit status chip inside the right card
	var sel_name: = str(sel_it.get("name", ""))
	var st_txt: String = "Надет в Чайной ✓" if (sel_worn and str(G.S.partner) == cur) else ("В гардеробе" if sel_own else "Закрыт · Предпросмотр")
	var st_col: Color = Color("7ce8c2") if sel_own else Color("ffe08c")
	var onm: = UI.label("«%s»" % sel_name, 19, Color("fff6e8"), UI.DARK, 3, "body", 900)
	onm.position = Vector2(20, 242)
	Common.fit_line(onm, 244.0, 15)
	ic.add_child(onm)
	var ost: = UI.label(st_txt, 17, st_col, UI.DARK, 3, "body", 900)
	ost.position = Vector2(20, 268)
	Common.fit_line(ost, 244.0, 14)
	ic.add_child(ost)

	# Primary Action CTA: «Надеть» for owned outfits vs vivid gold «Получить в Желаниях ›» for locked outfits!
	if sel_own:
		var active_here: bool = sel_worn and str(G.S.partner) == cur
		var wear_cap: String = "Надет ✓" if active_here else V6Txt.s("coll.wear")
		var wb_cta: = JButton.make(wear_cap, "mint" if active_here else "gold", Rect2(16, 296, 252, 64), null, 24)
		wb_cta.name = "OutfitActionBtn"
		wb_cta.shine_every = 0.0 if active_here else 2.2
		wb_cta.pressed.connect(func(): _equip_outfit(sel_it))
		ic.add_child(wb_cta)
	else:
		var wish_cta: = JButton.make("Получить в Желаниях ›", "gold", Rect2(16, 296, 252, 64), null, 17)
		wish_cta.name = "WishCtaBtn"
		wish_cta.shine_every = 1.8
		wish_cta.pressed.connect(func(): _go_to_hero_banner(cur, sel_it))
		ic.add_child(wish_cta)

	var by: = 370.0
	if unl:
		var is_part: bool = (str(G.S.partner) == cur)
		var pb_txt: = "Партнёр ✓" if is_part else "Сделать партнёром"
		var pb: = JButton.make(pb_txt, "mint" if is_part else "pink", Rect2(16, by, 252, 56), null, 20)
		pb.pressed.connect( func():
			G.S.partner = cur
			V10Look.notify()
			V10HudSkin.sync(V10Look.current())
			G.save()
			Sfx.say(cur, "outfit")
			main.toast(V6Txt.s("coll.partner_toast") % G.HEROES[cur].name, "heart")
			_build())
		ic.add_child(pb)
		var vb: = JButton.make(V6Txt.s("coll.voice"), "graphite", Rect2(16, by + 66.0, 122, 54), null, 19)
		vb.pressed.connect( func(): Sfx.say(cur, "greet"))
		ic.add_child(vb)
		var tb: = JButton.make(V6Txt.s("coll.skins"), "graphite", Rect2(146, by + 66.0, 122, 54), null, 19)
		tb.pressed.connect( func(): Common.skin_picker(main, func(): pass))
		ic.add_child(tb)
		by += 130.0
	else:
		var lb: = UI.label("Частички: %d / %d" % [mini(int(G.S.shards.get(cur, 0)), G.SHARDS_NEED), G.SHARDS_NEED], 19, Color("7a4a6a"), Color.WHITE, 3, "body", 900)
		lb.position = Vector2(20, by + 4.0)
		ic.add_child(lb)
		var zoom_b: = JButton.make("Осмотр во весь экран", "graphite", Rect2(16, by + 36.0, 252, 56), null, 19)
		zoom_b.pressed.connect( func():
			if not sel_it.is_empty():
				_open_inspect(sel_it))
		ic.add_child(zoom_b)
		by += 102.0
	# «Будуар ♥» — the VIP boudoir of this heroine (screen v10boudoir, when registered)
	var bd_btn: = JButton.make("Будуар ♥", "pink" if unl else "graphite", Rect2(16, by, 252, 56), null, 22)
	bd_btn.name = "BoudoirBtn"
	if unl:
		bd_btn.shine_every = 2.6
	bd_btn.pressed.connect(func(): _open_boudoir(cur, unl))
	ic.add_child(bd_btn)
	UI.slide_in(ic, Vector2(60, 0), 0.1)

	var strip: = UI.rbox("cream", Rect2(14, strip_y, W - 28, 226), 28, 4, 12)
	strip.set_param("pattern", 1.0)
	stage.add_child(strip)
	var n_own: = G.ITEMS.filter( func(x): return x.get("hero", "") == cur and G.owns(x.id)).size()
	var n_all: = G.ITEMS.filter( func(x): return x.get("hero", "") == cur).size()
	var st: = UI.label("Наряды · %d/%d  (коснись любого для осмотра)" % [n_own, n_all], 18, UI.INK, Color.WHITE, 3, "body", 900)
	st.position = Vector2(20, 8)
	Common.fit_line(st, strip.size.x - 196.0, 14)
	strip.add_child(st)
	V7AlbumView.collection_button(strip, main, _build)
	var cx: = 10.0
	var n_items: = G.ITEMS.filter( func(x): return x.get("hero", "") == cur).size()
	var cw: = clampf((strip.size.x - 20.0 - (n_items - 1) * 5.0) / maxf(1.0, n_items), 96.0, 118.0)
	var nw: = cw - _name_pad(cw) * 2.0
	var name_fs: = 16
	for it in G.ITEMS:
		if it.get("hero", "") == cur:
			name_fs = mini(name_fs, _name_fs(String(it.name), nw))
	for it in G.ITEMS:
		if it.get("hero", "") != cur:
			continue
		var own: bool = G.owns(it.id)
		var worn: bool = G.S.outfit.get(cur, "") == it.id or (G.S.outfit.get(cur, "") == "" and it.id in G.BASE_OUTFITS)
		var is_sel: bool = (str(it.id) == sel_oid)
		var csz: = Vector2(cw, 168)
		var card: = Control.new()
		card.name = "Card_" + str(it.id)
		card.position = Vector2(cx, 44)
		card.size = csz
		card.clip_contents = true
		card.pivot_offset = csz * 0.5
		strip.add_child(card)
		if is_sel or (worn and own):
			var glow: = UI.rbox("pink" if is_sel and not own else "gold", Rect2(1, 1, cw - 2, 166), 12, 0, 10)
			glow.set_param("glow", 1.0).set_param("glow_color", Color("ffd46b") if is_sel else Color("ffe7a6"))
			card.add_child(glow)
		var inner: = Common.card_inner(it.rar, csz)
		var art: = Common.card_art(G.art_tex(it), inner, Vector2(0.5, 0.3), 1.0, Common.card_radius(it.rar, csz))
		var am: ShaderMaterial = art.material
		if not own:
			# Selected locked card lights up in full color right on the strip too; unselected locked cards keep subtle tint
			am.set_shader_parameter("gray", 0.0 if is_sel else 0.55)
			am.set_shader_parameter("bottom_shade", 0.72 if is_sel else 0.85)
		am.set_shader_parameter("holo", 0.4 if it.rar == "SSR" and (own or is_sel) else 0.0)
		card.add_child(art)
		Common.card_frame(card, it.rar, Rect2(Vector2.ZERO, csz))
		if is_sel:
			var sel_rim: = Panel.new()
			sel_rim.position = Vector2(1, 1)
			sel_rim.size = csz - Vector2(2, 2)
			sel_rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var srsb: = StyleBoxFlat.new()
			srsb.bg_color = Color(0, 0, 0, 0)
			srsb.border_color = Color("ffe699")
			srsb.set_border_width_all(3)
			srsb.set_corner_radius_all(12)
			sel_rim.add_theme_stylebox_override("panel", srsb)
			card.add_child(sel_rim)
		var rw: = UI.font("body", 900).get_string_size(V10Rank.label(it.rar), HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 12.0
		var rtag: = UI.rbox("graphite", Rect2(cw - rw - 5, inner.position.y + 2, rw, 22), 11, 2, 3)
		rtag.borders(G.rar_color(it.rar).lerp(Color.WHITE, 0.35), G.rar_color(it.rar).darkened(0.45))
		card.add_child(rtag)
		rtag.add_child(UI.center_label(UI.label(V10Rank.label(it.rar), 15, G.rar_color(it.rar).lerp(Color.WHITE, 0.45), UI.DARK, 2, "body", 900), Rect2(0, -1, rw, 22)))
		if worn and own:
			var band_h: = 62.0
			var wb: = UI.rbox("mint", Rect2(inner.position.x + 1, inner.end.y - band_h - 1, inner.size.x - 2, band_h), 10, 0, 2)
			wb.colors(Color(0.12, 0.42, 0.34, 0.0), Color(0.08, 0.34, 0.27, 0.92))
			wb.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card.add_child(wb)
			var wk: = UI.rbox("mint", Rect2(-4, -4, 24, 24), 12, 2, 2)
			wk.colors(Color("4fbf9f"), Color("1f6b55")).borders(Color("ffe7a6"), Color("c58a2c"))
			wk.mouse_filter = Control.MOUSE_FILTER_IGNORE
			wk.tooltip_text = V6Txt.s("coll.worn")
			card.add_child(wk)
			wk.add_child(UI.center_label(UI.label("✓", 16, Color.WHITE, Color(0.05, 0.2, 0.15), 3, "body", 900), Rect2(0, -1, 24, 24)))
		var nl: = UI.label(_name_text(String(it.name), nw, name_fs), name_fs, Color.WHITE, Color(0.2, 0.05, 0.2), 4 if name_fs >= 16 else 3, "body", 800)
		Common.fit_words(nl, nw, 3, name_fs)
		nl.position = Vector2((cw - nw) * 0.5, minf(72.0, csz.y - NAME_FOOT - 84.0))
		nl.size = Vector2(nw, 84)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		card.add_child(nl)
		if not own:
			card.add_child(V8Art.rect(V8Art.icon("lock"), Rect2(4, inner.position.y + 2, 24, 24)))
		var itc: Dictionary = it
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.gui_input.connect( func(e):
			if (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and e.pressed):
				card.accept_event()
				UI.tap(card, 0.06, "pop")
				if str(itc.id) == sel_oid:
					_open_inspect(itc)
				else:
					sel_oid = str(itc.id)
					if G.owns(sel_oid):
						Sfx.say(cur, "outfit")
					else:
						Sfx.play("sparkle", 1.15, -7)
					_build())
		UI.pop_in(card, 0.06 + cx / 2400.0, 0.85)
		cx += cw + 5

# 0.12: the hero's own rarity — Wave-1 goddesses from V10W1Gacha, the founders from their V10 kit
static func _hero_rank(h: String) -> String:
	if V10W1Core.is_wave1_hero(h):
		return String(V10W1Gacha.HERO_RANK.get(h, "A"))
	return V10Rank.hero_rank(h)


# the next 16+ rubezh of the V10AffCurve above this level ({} when all are open)
static func _next_16(lv: int) -> Dictionary:
	var keys: = V10AffCurve.MILESTONES.keys()
	keys.sort()
	for k in keys:
		var m: Dictionary = V10AffCurve.MILESTONES[k]
		if int(k) > lv and bool(m.get("tag_16", false)):
			return m.duplicate(true)
	return {}


func _open_boudoir(h: String, unl: bool) -> void:
	var sc = main.get("SCREENS")
	if not unl:
		main.toast("Будуар откроется, когда она придёт к тебе", "lock")
		Sfx.play("sparkle", 1.1, -8)
		return
	if sc is Dictionary and (sc as Dictionary).has("v10boudoir"):
		main.go("v10boudoir", {"hero": h})
	else:
		main.toast("Будуар скоро откроется", "heart")


# the swipeable row of ten goddesses (ScrollContainer): 92 px gold medallions, rarity pill, «NEW · Волна 1» on the five new
func _hero_row() -> void:
	var n_h: = G.HERO_ORDER.size()
	var content_w: = 16.0 + n_h * MEDAL_STEP + 8.0
	row_scroll = ScrollContainer.new()
	row_scroll.name = "HeroRow"
	row_scroll.position = Vector2(0, ROW_Y - 8.0)
	row_scroll.size = Vector2(W, ROW_H)
	row_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	row_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	row_scroll.follow_focus = false
	stage.add_child(row_scroll)
	var content: = Control.new()
	content.custom_minimum_size = Vector2(content_w, ROW_H)
	content.mouse_filter = Control.MOUSE_FILTER_PASS
	row_scroll.add_child(content)
	var cur_i: = 0
	for i in n_h:
		var h: String = G.HERO_ORDER[i]
		if h == cur:
			cur_i = i
		var on: bool = h == cur
		var unl_h: = _unlocked(h)
		var mx: = 16.0 + i * MEDAL_STEP + (MEDAL_STEP - MEDAL) * 0.5
		var my: = 16.0
		var ring_pal: = "pink" if on else ("gold" if unl_h else "plum")
		var av: Control = V8Art.emotion_avatar(h, "happy", Rect2(mx, my, MEDAL, MEDAL), ring_pal)
		av.name = "Medal_" + h
		content.add_child(av)
		var pic: Node = av.get_node_or_null("Pic")
		if pic and pic is Control and (pic as Control).material is ShaderMaterial and not unl_h:
			((pic as Control).material as ShaderMaterial).set_shader_parameter("gray", 0.65 if not on else 0.3)
		if on:
			av.pivot_offset = Vector2(MEDAL, MEDAL) * 0.5
			UI.punch(av, 0.1)
		# rarity pill under the medallion
		var rk: = _hero_rank(h)
		var rcol: Color = V10Rank.color(rk)
		var pw: = 50.0
		var pill: = UI.rbox("graphite", Rect2(mx + (MEDAL - pw) * 0.5, my + MEDAL - 14.0, pw, 24), 12, 2, 3)
		pill.borders(rcol.lerp(Color.WHITE, 0.35), rcol.darkened(0.45))
		pill.name = "Rank_" + h
		pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(pill)
		pill.add_child(UI.center_label(UI.label(rk, 16, rcol.lerp(Color.WHITE, 0.45), UI.DARK, 3, "body", 900), Rect2(0, -1, pw, 24)))
		if not unl_h:
			var lk: = V8Art.rect(V8Art.icon("lock"), Rect2(mx + 2.0, my + MEDAL - 32.0, 26, 26))
			lk.mouse_filter = Control.MOUSE_FILTER_IGNORE
			content.add_child(lk)
		# «NEW · Волна 1» on the five goddesses of wave 1
		if W1_NEW.has(h):
			var bw: = 100.0
			var nb: = UI.rbox("pink", Rect2(mx + (MEDAL - bw) * 0.5, 0.0, bw, 22), 11, 2, 3)
			nb.borders(Color("ffe7a6"), Color("c58a2c"))
			nb.name = "NewBadge_" + h
			nb.mouse_filter = Control.MOUSE_FILTER_IGNORE
			content.add_child(nb)
			var nl: = UI.label("NEW · Волна 1", 13, Color.WHITE, Color(0.35, 0.05, 0.2), 3, "body", 900)
			UI.center_label(nl, Rect2(0, -1, bw, 22))
			nb.add_child(nl)
		# tap = select; a drag scrolls the row (the select fires on release when the finger hardly moved)
		var hh: String = h
		var hit: = Control.new()
		hit.position = Vector2(mx - 6.0, 6.0)
		hit.size = Vector2(MEDAL + 12.0, MEDAL + 12.0)
		hit.mouse_filter = Control.MOUSE_FILTER_PASS
		var st: = {"down": false, "from": Vector2.ZERO, "moved": false}
		hit.gui_input.connect(func(e: InputEvent) -> void:
			if e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
				if (e as InputEventMouseButton).pressed:
					st.down = true
					st.moved = false
					st.from = hit.get_global_mouse_position()
				elif st.down:
					st.down = false
					if not st.moved and hit.get_global_mouse_position().distance_to(st.from) < 14.0 and hh != cur:
						V9Feel.press(av, "tap")
						cur = hh
						sel_oid = _default_oid(cur)
						_build()
			elif e is InputEventMouseMotion and st.down and (e as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT:
				if hit.get_global_mouse_position().distance_to(st.from) >= 14.0:
					st.moved = true
				if not DisplayServer.is_touchscreen_available() and is_instance_valid(row_scroll):
					row_scroll.scroll_horizontal -= int((e as InputEventMouseMotion).relative.x)
			elif e is InputEventScreenTouch and (e as InputEventScreenTouch).pressed and hh != cur:
				V9Feel.press(av, "tap")
				cur = hh
				sel_oid = _default_oid(cur)
				_build())
		content.add_child(hit)
	# thin gold edge chevrons tell that the row swipes (ten goddesses do not fit the width)
	var arrows: = []
	for side in [-1, 1]:
		var ax: = 2.0 if side < 0 else W - 34.0
		var chev: = UI.rbox("graphite", Rect2(ax, ROW_Y + 24.0, 32, 44), 16, 2, 3)
		chev.borders(Color("ffe7a6"), Color("a8742a"))
		chev.modulate.a = 0.0
		chev.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chev.name = "RowChevL" if side < 0 else "RowChevR"
		stage.add_child(chev)
		chev.add_child(UI.center_label(UI.label("‹" if side < 0 else "›", 28, Color("ffe8a3"), UI.DARK, 3, "body", 900), Rect2(0, -4, 32, 44)))
		arrows.append(chev)
	row_arrows = arrows
	var hb: = row_scroll.get_h_scroll_bar()
	var upd: = func() -> void:
		if not is_instance_valid(row_scroll):
			return
		var mx_s: = int(maxf(0.0, content_w - W))
		var sx: = row_scroll.scroll_horizontal
		for k in arrows.size():
			if is_instance_valid(arrows[k]):
				var show: bool = (sx > 4) if k == 0 else (sx < mx_s - 4)
				(arrows[k] as Control).modulate.a = 0.92 if show else 0.0
	hb.value_changed.connect(func(_v: float) -> void: upd.call())
	# centre on the chosen goddess on first open, keep the swipe position after a tap
	var want: int = row_saved_x if row_saved_x >= 0 else int(clampf(16.0 + cur_i * MEDAL_STEP + MEDAL_STEP * 0.5 - W * 0.5, 0.0, maxf(0.0, content_w - W)))
	var apply: = func() -> void:
		if is_instance_valid(row_scroll):
			row_scroll.scroll_horizontal = want
			upd.call()
	apply.call_deferred()
	get_tree().create_timer(0.05).timeout.connect(apply)

static func _name_pad(cw: float) -> float:
	return NAME_PAD + maxf(0.0, cw - 108.0) * NAME_PAD_K

static func _name_text(name: String, width: float, fs: int) -> String:
	var f: = UI.font("body", 800)
	var pad: = 4.0 if fs >= 16 else 3.0
	var out: = []
	for wd in name.split(" ", false):
		if wd.contains("-") and f.get_string_size(wd, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + pad > width:
			wd = wd.replace("-", "-\n")
		out.append(wd)
	return " ".join(out).replace("\n ", "\n")

static func _name_parts(name: String) -> Array:
	var parts: = []
	for wd in name.split(" ", false):
		var bits: = wd.split("-", false)
		for i in bits.size():
			parts.append(bits[i] + ("-" if i < bits.size() - 1 else ""))
	return parts

static func _name_fs(name: String, width: float) -> int:
	var f: = UI.font("body", 800)
	for fs in range(16, NAME_MIN_FS - 1, -1):
		var pad: = 4.0 if fs >= 16 else 3.0
		var fits: = true
		for wd in _name_parts(name):
			if f.get_string_size(wd, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + pad > width:
				fits = false
		var h: = f.get_multiline_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, width - pad, fs, -1, TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND).y
		if fits and h <= f.get_height(fs) * 3 + 1.0:
			return fs
	return NAME_MIN_FS

# Fullscreen Outfit Inspection («Лупа / Осмотр») with zoom & pan for BOTH owned and locked outfits!
func _preview(it: Dictionary) -> void :
	_open_inspect(it)

func _open_inspect(it: Dictionary) -> void :
	if preview_root and is_instance_valid(preview_root):
		preview_root.queue_free()
	var root: = Control.new()
	root.name = "FullscreenInspect"
	root.z_index = 90
	var vs: = get_viewport_rect().size
	root.position = Vector2.ZERO
	root.size = vs
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.set_meta("v8_back", func():
		if is_instance_valid(root):
			root.queue_free()
		preview_root = null)
	if main and main.get("overlay") != null:
		main.overlay.add_child(root)
	else:
		add_child(root)
	preview_root = root

	var bg_dim: = ColorRect.new()
	bg_dim.size = root.size
	bg_dim.color = Color(0.06, 0.02, 0.09, 1.0)
	bg_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg_dim)

	var clip: = Control.new()
	clip.size = root.size
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(clip)

	var otex: = G.art_tex(it)
	var art_tr: = TextureRect.new()
	art_tr.texture = otex
	art_tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art_tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art_tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var fit_h: = root.size.y - 36.0
	var fit_w: = fit_h * float(otex.get_width()) / maxf(1.0, float(otex.get_height()))
	if fit_w < root.size.x * 0.92:
		fit_w = root.size.x * 0.96
		fit_h = fit_w * float(otex.get_height()) / maxf(1.0, float(otex.get_width()))
	art_tr.size = Vector2(fit_w, fit_h)
	art_tr.position = (root.size - art_tr.size) * 0.5
	art_tr.pivot_offset = art_tr.size * 0.5
	art_tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.add_child(art_tr)

	var hud_layer: = Control.new()
	hud_layer.size = root.size
	hud_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hud_layer)

	var own: = G.owns(str(it.get("id", "")))
	var ins: = V10Layout.safe_insets(root.size)
	var top_y: = float(ins.get("top", 0.0)) + 18.0
	var bot_y: = root.size.y - float(ins.get("bottom", 0.0))

	if not own:
		var badge: = Panel.new()
		var bsb: = StyleBoxFlat.new()
		bsb.bg_color = Color(0.11, 0.05, 0.16, 0.92)
		bsb.border_color = Color("f8df95")
		bsb.set_border_width_all(2)
		bsb.set_corner_radius_all(20)
		badge.add_theme_stylebox_override("panel", bsb)
		badge.position = Vector2(20, top_y + 6.0)
		badge.size = Vector2(276, 44)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_child(V8Art.rect(V8Art.icon("lock"), Rect2(12, 8, 28, 28)))
		var bl: = UI.label("Предпросмотр · Закрыт", 18, Color("ffe8a3"), Color(0.06, 0.02, 0.09), 3, "body", 900)
		bl.position = Vector2(44, 0)
		bl.size = Vector2(224, 44)
		bl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.add_child(bl)
		hud_layer.add_child(badge)

	# Close button top-right
	var close_b: = JButton.make("", "graphite", Rect2(root.size.x - 84.0, top_y, 64, 64), null, 28)
	if close_b.box:
		close_b.box.borders(Color("ffe7a6"), Color("a8742a"))
	close_b.add_child(V8Art.rect(V8Art.icon("close"), Rect2(15, 15, 34, 34)))
	close_b.pressed.connect(func():
		root.queue_free()
		preview_root = null)
	hud_layer.add_child(close_b)

	# Zoom controls + bottom action bar
	var st_zoom: = [1.0]
	var st_pan: = [Vector2.ZERO]
	var apply_zv: = func():
		var z: float = st_zoom[0]
		art_tr.scale = Vector2.ONE * z
		var max_px: = maxf(0.0, (art_tr.size.x * z - root.size.x) * 0.5 + 80.0)
		var max_py: = maxf(0.0, (art_tr.size.y * z - root.size.y) * 0.5 + 120.0)
		st_pan[0] = Vector2(clampf(st_pan[0].x, -max_px, max_px), clampf(st_pan[0].y, -max_py, max_py))
		art_tr.position = (root.size - art_tr.size) * 0.5 + st_pan[0]

	var foot: = Common.edge_shade(hud_layer, Rect2(0, bot_y - 230.0, root.size.x, 230.0 + float(ins.get("bottom", 0.0))), -1, Color(0.05, 0.02, 0.08), 0.94)
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var z_row: = Control.new()
	z_row.position = Vector2((root.size.x - 316.0) * 0.5, bot_y - 208.0)
	z_row.size = Vector2(316.0, 48.0)
	hud_layer.add_child(z_row)
	var z_presets: = [["1×", 1.0], ["1.5×", 1.5], ["2.2×", 2.2]]
	for i in z_presets.size():
		var zp: Array = z_presets[i]
		var zb: = JButton.make(zp[0], "graphite", Rect2(i * 108.0, 0, 100.0, 46.0), null, 19)
		if zb.box:
			zb.box.borders(Color("ffe7a6"), Color("a8742a"))
		var target_z: float = float(zp[1])
		zb.pressed.connect(func():
			st_zoom[0] = target_z
			if target_z <= 1.01:
				st_pan[0] = Vector2.ZERO
			apply_zv.call())
		z_row.add_child(zb)

	var rar_lbl: = V10Rank.label(str(it.get("rar", "R")))
	var title_l: = UI.center_label(UI.label("%s · %s · %s" % [rar_lbl, G.HEROES[str(it.get("hero", cur))].name, str(it.get("name", ""))], 22, Color("fff6e5"), Color(0.06, 0.02, 0.1), 4, "body", 900), Rect2(20, bot_y - 148.0, root.size.x - 40.0, 36.0))
	hud_layer.add_child(title_l)

	if own:
		var h_id: = str(it.get("hero", cur))
		var worn: bool = (G.S.outfit.get(h_id, "") == it.id or (G.S.outfit.get(h_id, "") == "" and it.id in G.BASE_OUTFITS)) and G.S.partner == h_id
		var eb: = JButton.make("Надет ✓" if worn else V6Txt.s("coll.wear"), "mint" if worn else "gold", Rect2(root.size.x * 0.5 - 170.0, bot_y - 100.0, 340.0, 76.0), null, 28)
		eb.shine_every = 0.0 if worn else 2.0
		eb.pressed.connect(func():
			var d_it: = it
			root.queue_free()
			preview_root = null
			_equip_outfit(d_it))
		hud_layer.add_child(eb)
	else:
		var wb2: = JButton.make("Получить в Желаниях ›", "gold", Rect2(root.size.x * 0.5 - 190.0, bot_y - 100.0, 380.0, 76.0), null, 24)
		wb2.shine_every = 1.8
		wb2.pressed.connect(func():
			var h_id2: = str(it.get("hero", cur))
			var d_it2: = it
			root.queue_free()
			preview_root = null
			_go_to_hero_banner(h_id2, d_it2))
		hud_layer.add_child(wb2)

	# Drag to pan + wheel/pinch zoom on root
	var dragging: = [false]
	var last_p: = [Vector2.ZERO]
	var touches: = {}
	var pinch_d: = [0.0]
	root.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton:
			var mb: = e as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT:
				dragging[0] = mb.pressed
				last_p[0] = mb.position
			elif mb.pressed and mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
				st_zoom[0] = clampf(st_zoom[0] + (0.15 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else -0.15), 1.0, 2.8)
				apply_zv.call()
		elif e is InputEventMouseMotion and dragging[0]:
			var mm: = e as InputEventMouseMotion
			st_pan[0] += mm.position - last_p[0]
			last_p[0] = mm.position
			apply_zv.call()
		elif e is InputEventScreenTouch:
			var stc: = e as InputEventScreenTouch
			if stc.pressed:
				touches[stc.index] = stc.position
			else:
				touches.erase(stc.index)
			if touches.size() == 2:
				var pts: = touches.values()
				pinch_d[0] = (pts[0] as Vector2).distance_to(pts[1] as Vector2)
		elif e is InputEventScreenDrag:
			var sd: = e as InputEventScreenDrag
			var prev: Vector2 = touches.get(sd.index, sd.position)
			touches[sd.index] = sd.position
			if touches.size() >= 2:
				var pts2: = touches.values()
				var nd: = (pts2[0] as Vector2).distance_to(pts2[1] as Vector2)
				if pinch_d[0] > 8.0:
					st_zoom[0] = clampf(st_zoom[0] * (nd / pinch_d[0]), 1.0, 2.8)
					apply_zv.call()
				pinch_d[0] = nd
			else:
				st_pan[0] += sd.position - prev
				apply_zv.call())

	art_tr.scale = Vector2(0.96, 0.96)
	art_tr.create_tween().tween_property(art_tr, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if own:
		Sfx.say(str(it.get("hero", cur)), "outfit")
	else:
		Sfx.play("sparkle", 1.1, -6)

func handle_back() -> bool:
	if preview_root and is_instance_valid(preview_root) and not preview_root.is_queued_for_deletion():
		V9Feel.press(null, "tap", "tap")
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
	if a == "preview_locked":
		for it in G.ITEMS:
			if it.get("cat", "") == "outfit" and it.get("hero", "") == cur and not G.owns(it.id):
				sel_oid = str(it.id)
				_build()
				return
		return
	if a == "inspect":
		if G.ITEM.has(sel_oid):
			_open_inspect(G.ITEM[sel_oid])
		return
	if a == "preview":
		for it in G.ITEMS:
			if it.get("hero", "") == cur and G.owns(it.id):
				_open_inspect(it)
				return


class _LoupeIcon:
	extends Control

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var col: = Color("ffe8a3")
		var c: = Vector2(12, 12)
		draw_arc(c, 7.0, 0, TAU, 28, col, 2.2, true)
		draw_line(c + Vector2(5.0, 5.0), c + Vector2(11.0, 11.0), col, 2.6, true)
		draw_line(c - Vector2(3.2, 0), c + Vector2(3.2, 0), col, 1.8, true)
		draw_line(c - Vector2(0, 3.2), c + Vector2(0, 3.2), col, 1.8, true)
