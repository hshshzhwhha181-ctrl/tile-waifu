extends Control


var main
var W: = 720.0
var H: = 1280.0
var cur: = "mc"
var sel_oid: = ""
var stage: Control

const ROW_Y: = 86.0
const MEDAL: = 84.0
const MEDAL_STEP: = 104.0
const ROW_H: = 114.0
const BODY_Y: = ROW_Y + ROW_H + 8.0
const BASE_BY_HERO: = {"mc": "o_base", "rin": "r_base", "hana": "h_base", "yue": "y_base", "nova": "n_base"}
const STAGE_BG: = {"mc": "menu", "rin": "bg_teahouse", "hana": "bg_street", "yue": "bg_palace", "nova": "bg_neon"}
const W1_NEW: = ["tsubame", "miel", "kohaku", "shirin", "zlata"]
const WINE_LACQUER: = Color("#2A1723")

var preview_root: Control
var row_scroll: ScrollContainer
var row_saved_x: = -1
var row_arrows: Array = []
var _motif_hero: = ""
static var _medal_tex_cache: Dictionary = {}


func build(m, args: Dictionary) -> void:
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


func _build() -> void:
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
	var unl: = _unlocked(cur)

	stage = Control.new()
	stage.size = size
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)
	move_child(stage, 0)
	_play_hero_motif(cur)

	# Calm, dimmed BD2 / "Тишина и лак" atmospheric backdrop so heroine art and lacquer plates own the stage
	var bg: String = STAGE_BG[cur] if STAGE_BG.has(cur) else V10W1Core.stage_bg(cur)
	Common.backdrop(stage, bg, size, 1.8 if bg != "menu" else 1.0, 0.52, V10DS.TINT_HOME, Vector2(0.5, 0.5))
	Common.vignette(stage, size, V10DS.NIGHT_900, 0.50)
	Fx.ambient(stage, "fireflies", size)
	V8Header.make(stage, main, "Героини", Callable())
	set_meta("v8_back", main.back)

	_hero_row()

	var strip_h: = 208.0
	var strip_y: = H - 146.0 - strip_h
	var left_x: = 16.0
	var card_w: = 280.0
	var right_x: = W - 16.0 - card_w
	var left_w: = right_x - left_x - 12.0
	var mid_h: = maxf(460.0, strip_y - 12.0 - BODY_Y)
	var foot_h: = 46.0
	var fr_h: = maxf(300.0, mid_h - foot_h - 8.0)

	# ── Left High-Res v4 Outfit Showcase + Neat Single-Row Lacquer Footer Bar ──
	var fr_wrap: = Control.new()
	fr_wrap.name = "PortraitFrame"
	fr_wrap.position = Vector2(left_x, BODY_Y)
	fr_wrap.size = Vector2(left_w, fr_h)
	fr_wrap.clip_contents = true
	fr_wrap.mouse_filter = Control.MOUSE_FILTER_STOP
	stage.add_child(fr_wrap)

	var bg_plate: = _LacquerSurface.new(Vector2(left_w, fr_h), 10.0, Color(V10DS.NIGHT_900, 0.86), Color(V10DS.GOLD_500, 0.42), true)
	fr_wrap.add_child(bg_plate)

	if not sel_it.is_empty():
		var otex: Texture2D = G.art_tex(sel_it)
		if otex != null:
			var art: = Common.card_art(otex, Rect2(1.0, 1.0, left_w - 2.0, fr_h - 2.0), Vector2(0.5, 0.22), 1.0, 9.5)
			var am: ShaderMaterial = art.material
			if am != null:
				am.set_shader_parameter("gray", 0.0)
				am.set_shader_parameter("bottom_shade", 0.48)
				am.set_shader_parameter("holo", 0.16 if str(sel_it.get("rar", "")) == "SSR" else 0.0)
			art.mouse_filter = Control.MOUSE_FILTER_IGNORE
			fr_wrap.add_child(art)
	else:
		var cut_p: = "res://assets/v10/hud2/combo/%s_t1.png" % cur
		if ResourceLoader.exists(cut_p):
			var ctex: Texture2D = load(cut_p)
			if ctex != null:
				var ctr: = TextureRect.new()
				ctr.texture = ctex
				ctr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				ctr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
				ctr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
				ctr.position = Vector2(1.0, 1.0)
				ctr.size = Vector2(left_w - 2.0, fr_h - 2.0)
				ctr.mouse_filter = Control.MOUSE_FILTER_IGNORE
				fr_wrap.add_child(ctr)

	# Smooth bottom dark-lacquer vignette for editorial outfit caption (zero floating buttons over art!)
	var foot_sh: = Common.edge_shade(fr_wrap, Rect2(1.0, fr_h - 86.0, left_w - 2.0, 85.0), -1, V10DS.NIGHT_900, 0.88)
	foot_sh.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var rim_ol: = _HairlineRim.new(Vector2(left_w, fr_h), 10.0, Color(V10DS.GOLD_500, 0.52 if sel_own else 0.38))
	fr_wrap.add_child(rim_ol)

	if not sel_it.is_empty():
		if not sel_own:
			var pv_badge: = Control.new()
			pv_badge.name = "LockedPreviewBadge"
			pv_badge.position = Vector2(10.0, 10.0)
			pv_badge.size = Vector2(158.0, 30.0)
			pv_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			pv_badge.add_child(_LacquerSurface.new(pv_badge.size, 8.0, Color(V10DS.NIGHT_900, 0.86), Color(V10DS.GOLD_700, 0.55), true))
			var lk_ic: = V8Art.rect(V8Art.icon("lock"), Rect2(8.0, 6.0, 18.0, 18.0))
			lk_ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
			pv_badge.add_child(lk_ic)
			var b_lbl: = _lbl("Предпросмотр", "ui", 14, V10DS.GOLD_300, false)
			b_lbl.position = Vector2(30.0, 0.0)
			b_lbl.size = Vector2(122.0, 30.0)
			pv_badge.add_child(b_lbl)
			fr_wrap.add_child(pv_badge)

		var rar_s: = V10Rank.label(str(sel_it.get("rar", "R")))
		var r_col: = G.rar_color(str(sel_it.get("rar", "R"))).lerp(V10DS.GOLD_300, 0.35)
		var oname_lbl: = _lbl("%s · %s" % [rar_s, str(sel_it.get("name", ""))], "ui_strong", 18, r_col.lerp(V10DS.PAPER_100, 0.45), true)
		oname_lbl.position = Vector2(14.0, fr_h - 38.0)
		oname_lbl.size = Vector2(left_w - 28.0, 28.0)
		_fit_one(oname_lbl, left_w - 28.0, [18, 16, 15, 14])
		fr_wrap.add_child(oname_lbl)

		fr_wrap.gui_input.connect(func(e: InputEvent) -> void:
			if _is_tap(e):
				fr_wrap.accept_event()
				_open_inspect(sel_it))

	# Clean single-row translucent lacquer footer bar UNDER the preview (Приём 16+ ▶ + Осмотр)
	var foot_y: = BODY_Y + fr_h + 8.0
	var ult_w: = roundf((left_w - 8.0) * 0.55)
	var insp_w: = left_w - 8.0 - ult_w

	var ult_btn: = _LacquerBtn.new("Приём 16+ ▶", Vector2(ult_w, foot_h), "gold")
	ult_btn.name = "UltCinemaBtn"
	ult_btn.position = Vector2(left_x, foot_y)
	ult_btn.pressed.connect(func() -> void:
		V10UltVideo.play(self, cur, sel_oid, V10VipBoudoirScreen.ult_name_of(cur, sel_oid)))
	stage.add_child(ult_btn)

	var zoom_btn: = _LacquerBtn.new("Осмотр", Vector2(insp_w, foot_h), "secondary")
	zoom_btn.name = "InspectBtn"
	zoom_btn.position = Vector2(left_x + ult_w + 8.0, foot_y)
	zoom_btn.set_loupe(true)
	zoom_btn.pressed.connect(func() -> void:
		if not sel_it.is_empty():
			_open_inspect(sel_it))
	stage.add_child(zoom_btn)

	# ── Right Heroine & Wardrobe Lacquer Action Sheet ──
	var card_h: = minf(516.0 if unl else 492.0, mid_h)
	var ic: = Control.new()
	ic.name = "HeroCard"
	ic.position = Vector2(right_x, BODY_Y)
	ic.size = Vector2(card_w, card_h)
	ic.clip_contents = true
	ic.mouse_filter = Control.MOUSE_FILTER_STOP
	stage.add_child(ic)
	ic.add_child(_LacquerSurface.new(ic.size, 10.0, Color(V10DS.NIGHT_800, 0.92), Color(V10DS.GOLD_700, 0.44), true))

	var oathed: = V10VipBoudoirScreen.is_oath(cur)
	var h_rank: = _hero_rank(cur)
	var rk_col: Color = V10Rank.color(h_rank)
	var rk_w: = 46.0
	var max_nw: = card_w - 32.0 - rk_w - (30.0 if oathed else 6.0)

	var nm: = _lbl(str(G.HEROES[cur].name), "display", 26, V10DS.PAPER_100, false)
	nm.position = Vector2(16.0, 12.0)
	nm.size = Vector2(max_nw, 34.0)
	var chosen_fs: = _fit_one(nm, max_nw, [26, 24, 22, 20, 18], "display")
	var nm_txt_w: = minf(max_nw, V10Type.text_w(nm.text, "display", chosen_fs))
	ic.add_child(nm)

	if oathed:
		var crest: = V10VipBoudoirScreen.make_oath_crest(24.0)
		crest.position = Vector2(minf(16.0 + nm_txt_w + 6.0, card_w - rk_w - 44.0), 17.0)
		ic.add_child(crest)

	var rk_pill: = Control.new()
	rk_pill.name = "HeroRankPill"
	rk_pill.position = Vector2(card_w - rk_w - 16.0, 17.0)
	rk_pill.size = Vector2(rk_w, 24.0)
	rk_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rk_pill.add_child(_LacquerSurface.new(rk_pill.size, 6.0, Color(V10DS.NIGHT_700, 0.96), rk_col.lerp(V10DS.GOLD_500, 0.45), false))
	var rk_l: = _lbl(h_rank, "ui_strong", 15, rk_col.lerp(V10DS.PAPER_100, 0.45), false)
	rk_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rk_l.size = rk_pill.size
	rk_pill.add_child(rk_l)
	ic.add_child(rk_pill)

	var tl: = _lbl(str(G.HEROES[cur].title), "ui", 16, V10DS.PAPER_300, false)
	tl.position = Vector2(16.0, 48.0)
	tl.size = Vector2(card_w - 32.0, 22.0)
	_fit_one(tl, card_w - 32.0, [16, 15, 14])
	ic.add_child(tl)

	_add_divider(ic, 78.0, card_w)

	# Affection progress + next 16+ milestone
	var ai: Dictionary = G.aff_info(cur)
	var h_ic: = V10Icons.icon("heart", 18, V10DS.ROSE_500)
	h_ic.position = Vector2(16.0, 90.0)
	ic.add_child(h_ic)

	var al: = _lbl("Симпатия · Ур. %d" % int(ai.get("level", 1)), "ui_strong", 17, V10DS.PAPER_100, false)
	al.position = Vector2(38.0, 86.0)
	al.size = Vector2(148.0, 24.0)
	_fit_one(al, 148.0, [17, 16, 15])
	ic.add_child(al)

	var a_txt: = "Макс." if bool(ai.get("is_max", false)) else "%s/%s" % [UI.fmt(int(ai.get("into", 0))), UI.fmt(int(ai.get("need", 1)))]
	var a_num: = _lbl(a_txt, "num", 14, V10DS.PAPER_500, false)
	a_num.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	a_num.position = Vector2(card_w - 96.0, 86.0)
	a_num.size = Vector2(80.0, 24.0)
	ic.add_child(a_num)

	var bar_w: = card_w - 32.0
	var a_bar: = Control.new()
	a_bar.name = "AffBar"
	a_bar.position = Vector2(16.0, 116.0)
	a_bar.size = Vector2(bar_w, 6.0)
	a_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var trk: = ColorRect.new()
	trk.color = V10DS.NIGHT_600
	trk.size = a_bar.size
	trk.mouse_filter = Control.MOUSE_FILTER_IGNORE
	a_bar.add_child(trk)
	var fl: = ColorRect.new()
	fl.color = V10DS.ROSE_500
	fl.size = Vector2(bar_w * clampf(float(ai.get("ratio", 0.0)), 0.0, 1.0), 6.0)
	fl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	a_bar.add_child(fl)
	ic.add_child(a_bar)

	var m16: = _next_16(int(ai.get("level", 1)))
	var m16_t: = "Все рубежи 16+ открыты ♥" if m16.is_empty() else "Рубеж 16+ · Ур. %d" % int(m16.get("level", 0))
	var m16_l: = _lbl(m16_t, "ui_strong", 15, V10DS.GOLD_300, false)
	m16_l.name = "Next16Label"
	m16_l.position = Vector2(16.0, 128.0)
	m16_l.size = Vector2(bar_w, 22.0)
	_fit_one(m16_l, bar_w, [15, 14])
	ic.add_child(m16_l)
	if not m16.is_empty():
		var m16_n: = _lbl("«%s»" % str(m16.get("title", "")), "ui", 14, V10DS.PAPER_300, false)
		m16_n.position = Vector2(16.0, 148.0)
		m16_n.size = Vector2(bar_w, 20.0)
		_fit_one(m16_n, bar_w, [14, 13])
		ic.add_child(m16_n)

	_add_divider(ic, 176.0, card_w)

	# Selected outfit status
	var owned_cnt: = 0
	var total_cnt: = 0
	for it in G.ITEMS:
		if it.get("hero", "") == cur:
			total_cnt += 1
			if G.owns(it.id):
				owned_cnt += 1
	var ol: = _lbl(V6Txt.s("coll.outfits") % [owned_cnt, total_cnt], "ui", 15, V10DS.PAPER_500, false)
	ol.position = Vector2(16.0, 184.0)
	ol.size = Vector2(bar_w, 20.0)
	ic.add_child(ol)

	var sel_name: = str(sel_it.get("name", ""))
	var st_txt: String = "Надет в Чайной ✓" if (sel_worn and str(G.S.partner) == cur) else ("В гардеробе" if sel_own else "Закрыт · Предпросмотр")
	var st_col: Color = V10DS.JADE_300 if (sel_worn and str(G.S.partner) == cur) else (V10DS.GOLD_300 if sel_own else V10DS.PAPER_500)

	var onm: = _lbl("«%s»" % sel_name, "ui_strong", 18, V10DS.PAPER_100, false)
	onm.position = Vector2(16.0, 206.0)
	onm.size = Vector2(bar_w, 24.0)
	_fit_one(onm, bar_w, [18, 16, 15, 14])
	ic.add_child(onm)

	var ost: = _lbl(st_txt, "ui", 15, st_col, false)
	ost.position = Vector2(16.0, 230.0)
	ost.size = Vector2(bar_w, 20.0)
	_fit_one(ost, bar_w, [15, 14])
	ic.add_child(ost)

	# Unified HUD_V2 Lacquer Action Stack (zero mismatched greens/purples/AI swirls!)
	var btn_w: = card_w - 32.0
	var y_cur: = 262.0
	if sel_own:
		var active_here: bool = sel_worn and str(G.S.partner) == cur
		var wear_cap: String = "Надет ✓" if active_here else V6Txt.s("coll.wear")
		var wb_cta: = _LacquerBtn.new(wear_cap, Vector2(btn_w, 50.0), "selected" if active_here else "primary")
		wb_cta.name = "OutfitActionBtn"
		wb_cta.position = Vector2(16.0, y_cur)
		wb_cta.pressed.connect(func() -> void: _equip_outfit(sel_it))
		ic.add_child(wb_cta)
	else:
		var wish_cta: = _LacquerBtn.new("Получить в Желаниях ›", Vector2(btn_w, 50.0), "primary")
		wish_cta.name = "WishCtaBtn"
		wish_cta.position = Vector2(16.0, y_cur)
		wish_cta.pressed.connect(func() -> void: _go_to_hero_banner(cur, sel_it))
		ic.add_child(wish_cta)
	y_cur += 60.0

	if unl:
		var is_part: bool = (str(G.S.partner) == cur)
		var pb_txt: = "Партнёр ✓" if is_part else "Сделать партнёром"
		var pb: = V10Button.make("secondary", pb_txt, Vector2(btn_w, 46.0))
		pb.position = Vector2(16.0, y_cur)
		if not is_part:
			pb.set_meta("ux_role", "primary")
		pb.pressed.connect(func() -> void:
			G.S.partner = cur
			V10Look.notify()
			V10HudSkin.sync(V10Look.current())
			G.save()
			Sfx.say(cur, "outfit")
			main.toast(V6Txt.s("coll.partner_toast") % G.HEROES[cur].name, "heart")
			_build())
		# Override V10Button secondary arrow layout into centered crisp lacquer pill
		var pb_vis: = _LacquerBtn.new(pb_txt, Vector2(btn_w, 46.0), "selected" if is_part else "secondary")
		pb_vis.position = Vector2.ZERO
		pb_vis.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pb._l.visible = false
		pb.self_modulate = Color(1, 1, 1, 0)
		pb.add_child(pb_vis)
		ic.add_child(pb)
		y_cur += 54.0

		var half_w: = (btn_w - 8.0) * 0.5
		var vb: = _LacquerBtn.new(V6Txt.s("coll.voice"), Vector2(half_w, 44.0), "secondary")
		vb.position = Vector2(16.0, y_cur)
		vb.pressed.connect(func() -> void: Sfx.say(cur, "greet"))
		ic.add_child(vb)

		var tb: = _LacquerBtn.new(V6Txt.s("coll.skins"), Vector2(half_w, 44.0), "secondary")
		tb.position = Vector2(16.0 + half_w + 8.0, y_cur)
		tb.pressed.connect(func() -> void: Common.skin_picker(main, func() -> void: pass))
		ic.add_child(tb)
		y_cur += 52.0
	else:
		var lb: = _lbl("Частички: %d / %d" % [mini(int(G.S.shards.get(cur, 0)), G.SHARDS_NEED), G.SHARDS_NEED], "ui_strong", 16, V10DS.GOLD_300, false)
		lb.position = Vector2(16.0, y_cur + 2.0)
		lb.size = Vector2(btn_w, 24.0)
		ic.add_child(lb)
		var zoom_b: = _LacquerBtn.new("Осмотр во весь экран", Vector2(btn_w, 46.0), "secondary")
		zoom_b.position = Vector2(16.0, y_cur + 32.0)
		zoom_b.pressed.connect(func() -> void:
			if not sel_it.is_empty():
				_open_inspect(sel_it))
		ic.add_child(zoom_b)
		y_cur += 86.0

	# VIP Boudoir button in harmonious dark wine-gold lacquer (zero AI swirl!)
	var bd_btn: = _LacquerBtn.new("Будуар ♥", Vector2(btn_w, 48.0), "wine" if unl else "secondary")
	bd_btn.name = "BoudoirBtn"
	bd_btn.position = Vector2(16.0, minf(y_cur, card_h - 56.0))
	bd_btn.pressed.connect(func() -> void: _open_boudoir(cur, unl))
	ic.add_child(bd_btn)

	# ── Bottom Wardrobe Strip (Dark Lacquer + Full-Color Outfit Cards) ──
	var strip: = Control.new()
	strip.name = "OutfitStrip"
	strip.position = Vector2(16.0, strip_y)
	strip.size = Vector2(W - 32.0, strip_h)
	strip.clip_contents = true
	strip.mouse_filter = Control.MOUSE_FILTER_STOP
	stage.add_child(strip)
	strip.add_child(_LacquerSurface.new(strip.size, 10.0, Color(V10DS.NIGHT_800, 0.92), Color(V10DS.GOLD_700, 0.44), true))

	var hero_items: Array = G.ITEMS.filter(func(x): return x.get("hero", "") == cur)
	var n_own: = hero_items.filter(func(x): return G.owns(x.id)).size()
	var n_all: = hero_items.size()

	var st: = _lbl("Наряды · %d из %d" % [n_own, n_all], "ui_strong", 18, V10DS.PAPER_100, false)
	st.position = Vector2(16.0, 8.0)
	st.size = Vector2(strip.size.x - 168.0, 28.0)
	_fit_one(st, strip.size.x - 168.0, [18, 16, 15])
	strip.add_child(st)

	var alb_btn: = _LacquerBtn.new("✦ Альбом", Vector2(128.0, 30.0), "gold")
	alb_btn.position = Vector2(strip.size.x - 140.0, 7.0)
	alb_btn.pressed.connect(func() -> void: V7AlbumView.open(main, "stamps", _build))
	if V7Album.claimable() > 0:
		alb_btn.set_dot(true)
	strip.add_child(alb_btn)

	var strip_scroll: = ScrollContainer.new()
	strip_scroll.position = Vector2(12.0, 42.0)
	strip_scroll.size = Vector2(strip.size.x - 24.0, 160.0)
	strip_scroll.clip_contents = true
	strip_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	strip_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	strip_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	strip.add_child(strip_scroll)

	var gap_c: = 8.0
	var avail_w: = strip_scroll.size.x
	var cw: = clampf((avail_w - maxf(0.0, float(n_all - 1)) * gap_c) / maxf(1.0, float(n_all)), 108.0, 128.0)
	var cards_holder: = Control.new()
	cards_holder.custom_minimum_size = Vector2(float(n_all) * cw + maxf(0.0, float(n_all - 1)) * gap_c, 160.0)
	cards_holder.mouse_filter = Control.MOUSE_FILTER_PASS
	strip_scroll.add_child(cards_holder)

	var cx: = 0.0
	for it in hero_items:
		var own: bool = G.owns(it.id)
		var worn: bool = G.S.outfit.get(cur, "") == it.id or (G.S.outfit.get(cur, "") == "" and it.id in G.BASE_OUTFITS)
		var is_sel: bool = (str(it.id) == sel_oid)
		var csz: = Vector2(cw, 158.0)
		var card: = Control.new()
		card.name = "Card_" + str(it.id)
		card.position = Vector2(cx, 1.0)
		card.size = csz
		card.clip_contents = true
		card.pivot_offset = csz * 0.5
		cards_holder.add_child(card)

		var ctex: Texture2D = G.art_tex(it)
		if ctex != null:
			var art_c: = Common.card_art(ctex, Rect2(Vector2.ZERO, csz), Vector2(0.5, 0.22), 1.0, 8.0)
			var am_c: ShaderMaterial = art_c.material
			if am_c != null:
				# Locked outfits remain 100% full-color (zero muddy grey overlay!)
				am_c.set_shader_parameter("gray", 0.0)
				am_c.set_shader_parameter("bottom_shade", 0.78)
				am_c.set_shader_parameter("holo", 0.28 if str(it.rar) == "SSR" else 0.0)
			art_c.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card.add_child(art_c)

		# Clean bottom caption shade + refined gold/jade hairline frame
		var c_sh: = Common.edge_shade(card, Rect2(0.0, csz.y - 54.0, csz.x, 54.0), -1, V10DS.NIGHT_900, 0.86)
		c_sh.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var rim_col: Color = V10DS.GOLD_500 if is_sel else (V10DS.JADE_300 if (worn and own) else Color(V10DS.GOLD_700, 0.42))
		var rim_w: float = 2.0 if is_sel else (1.5 if (worn and own) else 1.0)
		card.add_child(_HairlineRim.new(csz, 8.0, rim_col, rim_w))

		# Compact rarity chip top-right
		var r_lbl_s: = V10Rank.label(str(it.rar))
		var rc: = G.rar_color(str(it.rar))
		var rw: = maxf(28.0, V10Type.text_w(r_lbl_s, "ui_strong", 13) + 12.0)
		var rtag: = Control.new()
		rtag.position = Vector2(cw - rw - 5.0, 5.0)
		rtag.size = Vector2(rw, 18.0)
		rtag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rtag.add_child(_LacquerSurface.new(rtag.size, 5.0, Color(V10DS.NIGHT_900, 0.86), rc.lerp(V10DS.GOLD_500, 0.4), false))
		var rtl: = _lbl(r_lbl_s, "ui_strong", 12, rc.lerp(V10DS.PAPER_100, 0.45), false)
		rtl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rtl.size = rtag.size
		rtag.add_child(rtl)
		card.add_child(rtag)

		# Delicate corner status emblem: subtle lock when locked, crisp check when worn
		if not own:
			var lk_bg: = Control.new()
			lk_bg.position = Vector2(5.0, 5.0)
			lk_bg.size = Vector2(22.0, 22.0)
			lk_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
			lk_bg.add_child(_LacquerSurface.new(lk_bg.size, 11.0, Color(V10DS.NIGHT_900, 0.84), Color(V10DS.GOLD_700, 0.55), false))
			var lk_r: = V8Art.rect(V8Art.icon("lock"), Rect2(4.0, 4.0, 14.0, 14.0))
			lk_r.mouse_filter = Control.MOUSE_FILTER_IGNORE
			lk_bg.add_child(lk_r)
			card.add_child(lk_bg)
		elif worn:
			var wk: = Control.new()
			wk.position = Vector2(5.0, 5.0)
			wk.size = Vector2(22.0, 22.0)
			wk.mouse_filter = Control.MOUSE_FILTER_IGNORE
			wk.tooltip_text = V6Txt.s("coll.worn")
			wk.add_child(_LacquerSurface.new(wk.size, 11.0, Color(V10DS.NIGHT_900, 0.88), V10DS.JADE_300, false))
			var wkl: = _lbl("✓", "ui_strong", 13, V10DS.JADE_300, false)
			wkl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			wkl.size = wk.size
			wk.add_child(wkl)
			card.add_child(wk)

		var nl: = _lbl(String(it.name), "ui_strong", 13, V10DS.PAPER_100, true)
		nl.position = Vector2(4.0, csz.y - 44.0)
		nl.size = Vector2(cw - 8.0, 40.0)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		_fit_wrap(nl, cw - 8.0, 2, [13, 12, 11])
		card.add_child(nl)

		var itc: Dictionary = it
		card.mouse_filter = Control.MOUSE_FILTER_PASS
		var cst: = {"down": false, "from": Vector2.ZERO}
		card.gui_input.connect(func(e: InputEvent) -> void:
			if e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
				if (e as InputEventMouseButton).pressed:
					cst.down = true
					cst.from = card.get_global_mouse_position()
				elif cst.down:
					cst.down = false
					if card.get_global_mouse_position().distance_to(cst.from) < 14.0:
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
							_build()
			elif e is InputEventScreenTouch and (e as InputEventScreenTouch).pressed:
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
		cx += cw + gap_c


static func _hero_rank(h: String) -> String:
	if V10W1Core.is_wave1_hero(h):
		return String(V10W1Gacha.HERO_RANK.get(h, "A"))
	return V10Rank.hero_rank(h)


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


# Swipeable row of ten goddesses: clipped cleanly inside safe margins, crisp gold ✦ star pip inside medallion border (zero overflow!)
func _hero_row() -> void:
	var n_h: = G.HERO_ORDER.size()
	var view_w: = W - 32.0
	var content_w: = 8.0 + float(n_h) * MEDAL_STEP + 8.0
	row_scroll = ScrollContainer.new()
	row_scroll.name = "HeroRow"
	row_scroll.position = Vector2(16.0, ROW_Y)
	row_scroll.size = Vector2(view_w, ROW_H)
	row_scroll.clip_contents = true
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
		var on: bool = (h == cur)
		var unl_h: = _unlocked(h)
		var mx: = 8.0 + float(i) * MEDAL_STEP + (MEDAL_STEP - MEDAL) * 0.5
		var my: = 8.0
		var av: = _make_medallion(h, Rect2(mx, my, MEDAL, MEDAL), on, unl_h)
		av.name = "Medal_" + h
		content.add_child(av)

		# Sleek HUD_V2 lacquer rarity pill under medallion
		var rk: = _hero_rank(h)
		var rcol: Color = V10Rank.color(rk)
		var pw: = 44.0
		var pill: = Control.new()
		pill.name = "Rank_" + h
		pill.position = Vector2(mx + (MEDAL - pw) * 0.5, my + MEDAL - 12.0)
		pill.size = Vector2(pw, 20.0)
		pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pill.add_child(_LacquerSurface.new(pill.size, 10.0, Color(V10DS.NIGHT_800, 0.96), rcol.lerp(V10DS.GOLD_500, 0.4), false))
		var rkl: = _lbl(rk, "ui_strong", 13, rcol.lerp(V10DS.PAPER_100, 0.45), false)
		rkl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rkl.size = pill.size
		pill.add_child(rkl)
		content.add_child(pill)

		if not unl_h:
			var lk: = V8Art.rect(V8Art.icon("lock"), Rect2(mx + 2.0, my + MEDAL - 26.0, 22.0, 22.0))
			lk.mouse_filter = Control.MOUSE_FILTER_IGNORE
			content.add_child(lk)

		# Wave-1 goddess indicator: tiny crisp gold ✦ star pip cleanly INSIDE medallion border (never clips!)
		if W1_NEW.has(h):
			var nb: = Control.new()
			nb.name = "NewBadge_" + h
			nb.position = Vector2(mx + MEDAL - 22.0, my + 2.0)
			nb.size = Vector2(20.0, 20.0)
			nb.mouse_filter = Control.MOUSE_FILTER_IGNORE
			nb.add_child(_LacquerSurface.new(nb.size, 10.0, Color(V10DS.NIGHT_900, 0.92), V10DS.GOLD_500, false))
			var sp_l: = _lbl("✦", "ui_strong", 12, V10DS.GOLD_300, false)
			sp_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			sp_l.size = nb.size
			nb.add_child(sp_l)
			content.add_child(nb)

		var hh: String = h
		var hit: = Control.new()
		hit.position = Vector2(mx - 6.0, 4.0)
		hit.size = Vector2(MEDAL + 12.0, MEDAL + 20.0)
		hit.mouse_filter = Control.MOUSE_FILTER_PASS
		var st_d: = {"down": false, "from": Vector2.ZERO, "moved": false}
		hit.gui_input.connect(func(e: InputEvent) -> void:
			if e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
				if (e as InputEventMouseButton).pressed:
					st_d.down = true
					st_d.moved = false
					st_d.from = hit.get_global_mouse_position()
				elif st_d.down:
					st_d.down = false
					if not st_d.moved and hit.get_global_mouse_position().distance_to(st_d.from) < 14.0 and hh != cur:
						V9Feel.press(av, "tap")
						cur = hh
						sel_oid = _default_oid(cur)
						_build()
			elif e is InputEventMouseMotion and st_d.down and (e as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT:
				if hit.get_global_mouse_position().distance_to(st_d.from) >= 14.0:
					st_d.moved = true
				if not DisplayServer.is_touchscreen_available() and is_instance_valid(row_scroll):
					row_scroll.scroll_horizontal -= int((e as InputEventMouseMotion).relative.x)
			elif e is InputEventScreenTouch and (e as InputEventScreenTouch).pressed and hh != cur:
				V9Feel.press(av, "tap")
				cur = hh
				sel_oid = _default_oid(cur)
				_build())
		content.add_child(hit)

	var arrows: = []
	for side in [-1, 1]:
		var ax: = 6.0 if side < 0 else W - 30.0
		var chev: = Control.new()
		chev.name = "RowChevL" if side < 0 else "RowChevR"
		chev.position = Vector2(ax, ROW_Y + 30.0)
		chev.size = Vector2(24.0, 38.0)
		chev.modulate.a = 0.0
		chev.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chev.add_child(_LacquerSurface.new(chev.size, 8.0, Color(V10DS.NIGHT_900, 0.88), Color(V10DS.GOLD_700, 0.55), false))
		var cl: = _lbl("‹" if side < 0 else "›", "ui_strong", 22, V10DS.GOLD_300, false)
		cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cl.size = chev.size
		chev.add_child(cl)
		stage.add_child(chev)
		arrows.append(chev)
	row_arrows = arrows

	var hb: = row_scroll.get_h_scroll_bar()
	var upd: = func() -> void:
		if not is_instance_valid(row_scroll):
			return
		var mx_s: = int(maxf(0.0, content_w - view_w))
		var sx: = row_scroll.scroll_horizontal
		for k in arrows.size():
			if is_instance_valid(arrows[k]):
				var show: bool = (sx > 4) if k == 0 else (sx < mx_s - 4)
				(arrows[k] as Control).modulate.a = 0.92 if show else 0.0
	hb.value_changed.connect(func(_v: float) -> void: upd.call())
	var want: int = row_saved_x if row_saved_x >= 0 else int(clampf(8.0 + float(cur_i) * MEDAL_STEP + MEDAL_STEP * 0.5 - view_w * 0.5, 0.0, maxf(0.0, content_w - view_w)))
	var apply: = func() -> void:
		if is_instance_valid(row_scroll):
			row_scroll.scroll_horizontal = want
			upd.call()
	apply.call_deferred()
	get_tree().create_timer(0.05).timeout.connect(apply)


# Fullscreen Outfit Inspection («Осмотр») in matching HUD_V2 lacquer
func _preview(it: Dictionary) -> void:
	_open_inspect(it)


func _open_inspect(it: Dictionary) -> void:
	if preview_root and is_instance_valid(preview_root):
		preview_root.queue_free()
	var root: = Control.new()
	root.name = "FullscreenInspect"
	root.z_index = 90
	var vs: = get_viewport_rect().size
	root.position = Vector2.ZERO
	root.size = vs
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.set_meta("v8_back", func() -> void:
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
	bg_dim.color = V10DS.NIGHT_900
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
	var top_y: = float(ins.get("top", 0.0)) + 16.0
	var bot_y: = root.size.y - float(ins.get("bottom", 0.0))

	if not own:
		var badge: = Control.new()
		badge.position = Vector2(20.0, top_y + 8.0)
		badge.size = Vector2(236.0, 40.0)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_child(_LacquerSurface.new(badge.size, 8.0, Color(V10DS.NIGHT_800, 0.92), Color(V10DS.GOLD_700, 0.55), true))
		badge.add_child(V8Art.rect(V8Art.icon("lock"), Rect2(12.0, 9.0, 22.0, 22.0)))
		var bl: = _lbl("Предпросмотр · Закрыт", "ui_strong", 16, V10DS.GOLD_300, false)
		bl.position = Vector2(40.0, 0.0)
		bl.size = Vector2(188.0, 40.0)
		badge.add_child(bl)
		hud_layer.add_child(badge)

	var close_b: = V10Button.make("quiet", "", Vector2(64.0, 64.0))
	close_b.icon = "close"
	close_b.icon_px = 32
	close_b.icon_color = V10DS.PAPER_100
	close_b.position = Vector2(root.size.x - 80.0, top_y - 4.0)
	close_b.pressed.connect(func() -> void:
		root.queue_free()
		preview_root = null)
	hud_layer.add_child(close_b)

	var st_zoom: = [1.0]
	var st_pan: = [Vector2.ZERO]
	var apply_zv: = func() -> void:
		var z: float = st_zoom[0]
		art_tr.scale = Vector2.ONE * z
		var max_px: = maxf(0.0, (art_tr.size.x * z - root.size.x) * 0.5 + 80.0)
		var max_py: = maxf(0.0, (art_tr.size.y * z - root.size.y) * 0.5 + 120.0)
		st_pan[0] = Vector2(clampf(st_pan[0].x, -max_px, max_px), clampf(st_pan[0].y, -max_py, max_py))
		art_tr.position = (root.size - art_tr.size) * 0.5 + st_pan[0]

	var foot: = Common.edge_shade(hud_layer, Rect2(0.0, bot_y - 216.0, root.size.x, 216.0 + float(ins.get("bottom", 0.0))), -1, V10DS.NIGHT_900, 0.92)
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var z_row: = Control.new()
	z_row.position = Vector2((root.size.x - 296.0) * 0.5, bot_y - 196.0)
	z_row.size = Vector2(296.0, 44.0)
	hud_layer.add_child(z_row)
	var z_presets: = [["1×", 1.0], ["1.5×", 1.5], ["2.2×", 2.2]]
	for i in z_presets.size():
		var zp: Array = z_presets[i]
		var zb: = _LacquerBtn.new(str(zp[0]), Vector2(92.0, 42.0), "secondary")
		zb.position = Vector2(float(i) * 102.0, 0.0)
		var target_z: float = float(zp[1])
		zb.pressed.connect(func() -> void:
			st_zoom[0] = target_z
			if target_z <= 1.01:
				st_pan[0] = Vector2.ZERO
			apply_zv.call())
		z_row.add_child(zb)

	var rar_lbl: = V10Rank.label(str(it.get("rar", "R")))
	var title_l: = _lbl("%s · %s · %s" % [rar_lbl, G.HEROES[str(it.get("hero", cur))].name, str(it.get("name", ""))], "ui_strong", 20, V10DS.PAPER_100, true)
	title_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_l.position = Vector2(24.0, bot_y - 138.0)
	title_l.size = Vector2(root.size.x - 48.0, 32.0)
	_fit_one(title_l, root.size.x - 48.0, [20, 18, 16])
	hud_layer.add_child(title_l)

	if own:
		var h_id: = str(it.get("hero", cur))
		var worn: bool = (G.S.outfit.get(h_id, "") == it.id or (G.S.outfit.get(h_id, "") == "" and it.id in G.BASE_OUTFITS)) and G.S.partner == h_id
		var eb: = _LacquerBtn.new("Надет ✓" if worn else V6Txt.s("coll.wear"), Vector2(320.0, 62.0), "selected" if worn else "primary")
		eb.position = Vector2(root.size.x * 0.5 - 160.0, bot_y - 92.0)
		eb.pressed.connect(func() -> void:
			var d_it: = it
			root.queue_free()
			preview_root = null
			_equip_outfit(d_it))
		hud_layer.add_child(eb)
	else:
		var wb2: = _LacquerBtn.new("Получить в Желаниях ›", Vector2(340.0, 62.0), "primary")
		wb2.position = Vector2(root.size.x * 0.5 - 170.0, bot_y - 92.0)
		wb2.pressed.connect(func() -> void:
			var h_id2: = str(it.get("hero", cur))
			var d_it2: = it
			root.queue_free()
			preview_root = null
			_go_to_hero_banner(h_id2, d_it2))
		hud_layer.add_child(wb2)

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
	art_tr.create_tween().tween_property(art_tr, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	if own:
		Sfx.say(str(it.get("hero", cur)), "outfit")
	else:
		Sfx.play("sparkle", 1.1, -6)


func _play_hero_motif(h: String) -> void:
	if _motif_hero == h:
		return
	_motif_hero = h
	if V10Registry.wired("audio") and bool(G.S.get("music", true)):
		if h in V10Music.HEROES:
			V10Music.motif(h)
		elif V10Music.current().begins_with("motif_"):
			V10Music.play_screen("collection")


func handle_back() -> bool:
	if has_node("V10UltVideo"):
		var uv: = get_node("V10UltVideo")
		if uv.has_method("skip"):
			uv.skip()
		return true
	if preview_root and is_instance_valid(preview_root) and not preview_root.is_queued_for_deletion():
		V9Feel.press(null, "tap", "tap")
		preview_root.queue_free()
		preview_root = null
		return true
	return false


func dev_act(a: String) -> void:
	if a == "ult":
		V10UltVideo.play(self, cur, sel_oid, V10VipBoudoirScreen.ult_name_of(cur, sel_oid))
		return
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


# ── HUD_V2 "Тишина и лак" Typography & Lacquer Helpers ──

static func _is_tap(e: InputEvent) -> bool:
	return (e is InputEventMouseButton and (e as InputEventMouseButton).pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and (e as InputEventScreenTouch).pressed)


static func _lbl(txt: String, role: String, sz: int, col: Color, on_art: bool) -> Label:
	var l: = Label.new()
	l.text = txt
	l.label_settings = V10Type.settings(role, sz, col, on_art)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


static func _fit_one(l: Label, max_w: float, sizes: Array, role: = "") -> int:
	var ls: LabelSettings = l.label_settings
	var r: = role if role != "" else "ui_strong"
	if ls != null and role == "":
		if ls.font == V10Type.font("display"):
			r = "display"
		elif ls.font == V10Type.font("ui"):
			r = "ui"
		elif ls.font == V10Type.font("num"):
			r = "num"
	var chosen: int = int(sizes[sizes.size() - 1])
	for s in sizes:
		if V10Type.text_w(l.text, r, int(s)) <= max_w:
			chosen = int(s)
			break
	if ls != null:
		l.label_settings = V10Type.settings(r, chosen, ls.font_color, ls.shadow_size > 0)
	return chosen


static func _fit_wrap(l: Label, max_w: float, max_lines: int, sizes: Array) -> void:
	var raw: = l.text.replace("\n", " ").strip_edges()
	var ls: LabelSettings = l.label_settings
	var chosen: int = int(sizes[sizes.size() - 1])
	var best_lines: Array = [raw]
	for s in sizes:
		var fs: = int(s)
		var words: = raw.split(" ", false)
		var lines: Array = []
		var cur_ln: = ""
		var word_over: = false
		for w in words:
			if V10Type.text_w(w, "ui_strong", fs) > max_w:
				word_over = true
			var cand: = w if cur_ln == "" else cur_ln + " " + w
			if cur_ln != "" and V10Type.text_w(cand, "ui_strong", fs) > max_w:
				lines.append(cur_ln)
				cur_ln = w
			else:
				cur_ln = cand
		if cur_ln != "":
			lines.append(cur_ln)
		best_lines = lines
		chosen = fs
		if not word_over and lines.size() <= max_lines:
			break
	if best_lines.size() > max_lines:
		var trimmed: Array = []
		for i in max_lines - 1:
			trimmed.append(best_lines[i])
		var tail_parts: Array = []
		for j in range(max_lines - 1, best_lines.size()):
			tail_parts.append(best_lines[j])
		trimmed.append(" ".join(PackedStringArray(tail_parts)))
		best_lines = trimmed
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.text = "\n".join(PackedStringArray(best_lines))
	if ls != null:
		var s_new: = V10Type.settings("ui_strong", chosen, ls.font_color, ls.shadow_size > 0).duplicate() as LabelSettings
		s_new.line_spacing = -2.0
		l.label_settings = s_new


static func _medal_tex(h: String) -> Texture2D:
	if _medal_tex_cache.has(h):
		return _medal_tex_cache[h]
	var p: = ""
	if V8Art.has_emotion(h, "happy"):
		p = V8Art.emotion_path(h, "happy")
	elif ResourceLoader.exists("res://assets/v10/wave1/emotions/%s_happy.webp" % h):
		p = "res://assets/v10/wave1/emotions/%s_happy.webp" % h
	else:
		p = V10W1Core.hero_png(h)
	var src: Texture2D = load(p) if ResourceLoader.exists(p) else null
	if src == null:
		return null
	var im: = src.get_image()
	if im == null or im.is_empty():
		return src
	if im.is_compressed():
		im.decompress()
	im.convert(Image.FORMAT_RGBA8)
	var iw: = im.get_width()
	var ih: = im.get_height()
	var top_y: = 0
	var found_top: = false
	for y in range(0, ih, 4):
		for x in range(0, iw, 8):
			if im.get_pixel(x, y).a > 0.25:
				top_y = maxi(0, y - 8)
				found_top = true
				break
		if found_top:
			break
	var side: = mini(iw, int(roundf(float(ih - top_y) * 0.56)))
	side = clampi(side, 64, mini(iw, ih - top_y))
	var cx_i: = clampi((iw - side) / 2, 0, maxi(0, iw - side))
	var cy_i: = clampi(top_y, 0, maxi(0, ih - side))
	var sub: = im.get_region(Rect2i(cx_i, cy_i, side, side))
	sub.resize(176, 176, Image.INTERPOLATE_LANCZOS)
	sub.generate_mipmaps()
	var out_tex: = ImageTexture.create_from_image(sub)
	_medal_tex_cache[h] = out_tex
	return out_tex


static func _make_medallion(h: String, r: Rect2, on: bool, unl_h: bool) -> Control:
	var wrap: = Control.new()
	wrap.position = r.position
	wrap.size = r.size
	wrap.pivot_offset = r.size * 0.5
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var disc: = Panel.new()
	disc.size = r.size
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	disc.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	var dsb: = StyleBoxFlat.new()
	dsb.bg_color = V10DS.NIGHT_700 if on else V10DS.NIGHT_800
	dsb.set_corner_radius_all(int(roundf(r.size.x * 0.5)))
	disc.add_theme_stylebox_override("panel", dsb)
	wrap.add_child(disc)

	var t: = _medal_tex(h)
	if t != null:
		var tr: = TextureRect.new()
		tr.name = "Pic"
		tr.texture = t
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		tr.position = Vector2(2.0, 2.0)
		tr.size = r.size - Vector2(4.0, 4.0)
		tr.modulate = Color.WHITE if (unl_h or on) else Color(0.72, 0.70, 0.76, 0.92)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		disc.add_child(tr)

	var rim_c: = V10DS.GOLD_300 if on else (Color(V10DS.GOLD_500, 0.78) if unl_h else Color(V10DS.GOLD_700, 0.42))
	var ring: = _MedalRing.new(r.size.x, rim_c, 2.4 if on else 1.4)
	wrap.add_child(ring)
	return wrap


static func _add_divider(parent: Control, y: float, w: float) -> void:
	var d: = ColorRect.new()
	d.color = Color(V10DS.GOLD_700, 0.24)
	d.position = Vector2(16.0, y)
	d.size = Vector2(w - 32.0, 1.0)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(d)


class _LacquerSurface:
	extends Control

	var _rad: float
	var _fill: Color
	var _rim: Color
	var _top_hair: bool

	func _init(sz: Vector2, rad: float, fill: Color, rim: Color, top_hair: bool) -> void:
		size = sz
		_rad = rad
		_fill = fill
		_rim = rim
		_top_hair = top_hair
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r: = Rect2(Vector2.ZERO, size)
		var pts: = V10Button.rr_pts(r, _rad, 8)
		draw_colored_polygon(pts, _fill)
		var lh: = r.size.y * 0.42
		if lh > 4.0 and r.size.x > 12.0:
			var lac: = Color(V10DS.PAPER_100, 0.05)
			var clr: = Color(V10DS.PAPER_100, 0.0)
			draw_polygon(PackedVector2Array([
				Vector2(_rad * 0.5, 1.0), Vector2(r.size.x - _rad * 0.5, 1.0),
				Vector2(r.size.x - 1.5, lh), Vector2(1.5, lh),
			]), PackedColorArray([lac, lac, clr, clr]))
		if _rim.a > 0.01:
			var bp: = V10Button.rr_pts(r.grow(-0.5), maxf(2.0, _rad - 0.5), 8)
			bp.append(bp[0])
			draw_polyline(bp, _rim, 1.0, true)
		if _top_hair and r.size.x > 28.0:
			V10Plate.hairline(self, 10.0, r.size.x - 10.0, 0.8, Color(V10DS.PLATE_SPARK, 0.48))


class _HairlineRim:
	extends Control

	var _rad: float
	var _col: Color
	var _w: float

	func _init(sz: Vector2, rad: float, col: Color, w: = 1.0) -> void:
		size = sz
		_rad = rad
		_col = col
		_w = w
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r: = Rect2(Vector2.ZERO, size).grow(-_w * 0.5)
		var bp: = V10Button.rr_pts(r, maxf(2.0, _rad - _w * 0.5), 8)
		bp.append(bp[0])
		draw_polyline(bp, _col, _w, true)
		if size.x > 32.0:
			V10Plate.hairline(self, 12.0, size.x - 12.0, 1.0, Color(V10DS.PLATE_SPARK, 0.55))


class _MedalRing:
	extends Control

	var _d: float
	var _col: Color
	var _w: float

	func _init(d: float, col: Color, w: = 2.0) -> void:
		_d = d
		_col = col
		_w = w
		size = Vector2(d, d)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_arc(Vector2(_d * 0.5, _d * 0.5), _d * 0.5 - _w * 0.5, 0.0, TAU, 56, _col, _w, true)


class _LacquerBtn:
	extends Control

	signal pressed

	var style: = "secondary"
	var lbl: Label
	var _down: = false
	var _has_loupe: = false
	var _has_dot: = false
	var _loupe: _LoupeIcon

	func _init(txt: String, sz: Vector2, st: String) -> void:
		size = sz
		pivot_offset = sz * 0.5
		style = st
		mouse_filter = Control.MOUSE_FILTER_STOP
		lbl = Label.new()
		lbl.text = txt
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.clip_text = true
		lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(lbl)
		_sync_label()

	func set_loupe(on: bool) -> void:
		_has_loupe = on
		if on and _loupe == null:
			_loupe = _LoupeIcon.new()
			_loupe.position = Vector2(14.0, (size.y - 20.0) * 0.5)
			_loupe.size = Vector2(20.0, 20.0)
			add_child(_loupe)
		_sync_label()
		queue_redraw()

	func set_dot(on: bool) -> void:
		_has_dot = on
		queue_redraw()

	func _sync_label() -> void:
		var pad_l: = 38.0 if _has_loupe else 12.0
		var pad_r: = 18.0 if _has_dot else 12.0
		var max_w: = maxf(24.0, size.x - pad_l - pad_r)
		lbl.position = Vector2(pad_l, 0.0)
		lbl.size = Vector2(max_w, size.y)
		var tcol: Color = V10DS.PAPER_100
		var role: = "ui_strong"
		var steps: = [19, 18, 17, 16, 15, 14]
		match style:
			"primary":
				tcol = V10DS.NIGHT_900
				role = "display" if size.y >= 50.0 and V10Type.text_w(lbl.text, "display", 22) <= max_w else "ui_strong"
				steps = [22, 20, 18, 17, 16, 15]
			"selected", "gold", "wine":
				tcol = V10DS.GOLD_300
				steps = [18, 17, 16, 15, 14]
		var chosen: int = int(steps[steps.size() - 1])
		for s in steps:
			if V10Type.text_w(lbl.text, role, int(s)) <= max_w:
				chosen = int(s)
				break
		lbl.label_settings = V10Type.settings(role, chosen, tcol, false)

	func _draw() -> void:
		var r: = Rect2(Vector2.ZERO, size)
		match style:
			"primary":
				var rad: = size.y * 0.5
				draw_colored_polygon(V10Button.rr_pts(Rect2(Vector2(0.0, 2.5), size), rad, 12), Color(V10DS.NIGHT_900, 0.34))
				var ct: = V10DS.ROSE_700.lightened(0.06) if _down else V10DS.ROSE_500.lightened(0.06)
				var cm: = V10DS.ROSE_700 if _down else V10DS.ROSE_500
				var cb: = V10DS.ROSE_700.darkened(0.08) if _down else V10DS.ROSE_500.lerp(V10DS.ROSE_700, 0.22)
				var pts: = V10Button.rr_pts(r, rad, 12)
				draw_polygon(pts, V10Button.grad_cols(pts, 0.0, size.y, [[0.0, ct], [0.52, cm], [1.0, cb]]))
				var sr: = Rect2(2.0, 1.5, size.x - 4.0, size.y * 0.44)
				if sr.size.x > 8.0:
					var sp: = V10Button.rr_pts(sr, minf(rad - 2.0, sr.size.y * 0.48), 8)
					draw_polygon(sp, V10Button.grad_cols(sp, sr.position.y, sr.end.y, [[0.0, Color(V10DS.PAPER_100, 0.13)], [1.0, Color(V10DS.PAPER_100, 0.0)]]))
				var ins: = minf(rad * 0.72, size.x * 0.25)
				V10Plate.hairline(self, ins, size.x - ins, 1.0, Color(V10DS.PLATE_SPARK, 0.76))
			"selected":
				var rad2: = 8.0
				var bg2: = Color(V10DS.NIGHT_600, 0.96) if _down else Color(V10DS.NIGHT_700, 0.96)
				draw_colored_polygon(V10Button.rr_pts(r, rad2, 8), bg2)
				var bp2: = V10Button.rr_pts(r.grow(-0.75), rad2 - 0.75, 8)
				bp2.append(bp2[0])
				draw_polyline(bp2, V10DS.GOLD_500, 1.5, true)
				V10Plate.hairline(self, 10.0, size.x - 10.0, 1.0, Color(V10DS.PLATE_SPARK, 0.60))
			"gold":
				var rad3: = 8.0
				var bg3: = Color(V10DS.NIGHT_600, 0.96) if _down else Color(V10DS.NIGHT_800, 0.92)
				draw_colored_polygon(V10Button.rr_pts(r, rad3, 8), bg3)
				var bp3: = V10Button.rr_pts(r.grow(-0.5), rad3 - 0.5, 8)
				bp3.append(bp3[0])
				draw_polyline(bp3, Color(V10DS.GOLD_500, 0.68), 1.0, true)
				V10Plate.hairline(self, 10.0, size.x - 10.0, 0.8, Color(V10DS.PLATE_SPARK, 0.55))
			"wine":
				var rad4: = 8.0
				var bg4: = WINE_LACQUER.lightened(0.08) if _down else Color(WINE_LACQUER, 0.95)
				draw_colored_polygon(V10Button.rr_pts(r, rad4, 8), bg4)
				var lh4: = size.y * 0.42
				draw_polygon(PackedVector2Array([Vector2(4.0, 1.0), Vector2(size.x - 4.0, 1.0), Vector2(size.x - 2.0, lh4), Vector2(2.0, lh4)]),
					PackedColorArray([Color(V10DS.PAPER_100, 0.06), Color(V10DS.PAPER_100, 0.06), Color(V10DS.PAPER_100, 0.0), Color(V10DS.PAPER_100, 0.0)]))
				var bp4: = V10Button.rr_pts(r.grow(-0.5), rad4 - 0.5, 8)
				bp4.append(bp4[0])
				draw_polyline(bp4, Color(V10DS.GOLD_500, 0.72), 1.0, true)
				V10Plate.hairline(self, 12.0, size.x - 12.0, 1.0, Color(V10DS.PLATE_SPARK, 0.62))
			_:
				var rad5: = 8.0
				var bg5: = Color(V10DS.NIGHT_600, 0.96) if _down else Color(V10DS.NIGHT_800, 0.92)
				draw_colored_polygon(V10Button.rr_pts(r, rad5, 8), bg5)
				var lh5: = size.y * 0.40
				draw_polygon(PackedVector2Array([Vector2(4.0, 1.0), Vector2(size.x - 4.0, 1.0), Vector2(size.x - 2.0, lh5), Vector2(2.0, lh5)]),
					PackedColorArray([Color(V10DS.PAPER_100, 0.05), Color(V10DS.PAPER_100, 0.05), Color(V10DS.PAPER_100, 0.0), Color(V10DS.PAPER_100, 0.0)]))
				var bp5: = V10Button.rr_pts(r.grow(-0.5), rad5 - 0.5, 8)
				bp5.append(bp5[0])
				draw_polyline(bp5, Color(V10DS.GOLD_700, 0.42), 1.0, true)
				V10Plate.hairline(self, 10.0, size.x - 10.0, 0.8, Color(V10DS.GOLD_500, 0.48))
		if _has_dot:
			draw_circle(Vector2(size.x - 11.0, size.y * 0.5), 3.5, V10DS.ROSE_300, true, -1.0, true)

	func _gui_input(e: InputEvent) -> void:
		if (e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT) or e is InputEventScreenTouch:
			if e.pressed:
				_down = true
				scale = Vector2.ONE * 0.96
				queue_redraw()
			elif _down:
				_down = false
				var tw: = create_tween()
				tw.tween_property(self, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
				queue_redraw()
				if Rect2(Vector2.ZERO, size).grow(14.0).has_point(e.position):
					Sfx.play("tap", randf_range(0.96, 1.04), -4.0)
					V9Feel.haptic("button")
					pressed.emit()
			accept_event()


class _LoupeIcon:
	extends Control

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var col: = V10DS.GOLD_300
		var c: = Vector2(8.5, 8.5)
		draw_arc(c, 5.5, 0.0, TAU, 24, col, 1.8, true)
		draw_line(c + Vector2(4.0, 4.0), c + Vector2(9.0, 9.0), col, 2.0, true)
