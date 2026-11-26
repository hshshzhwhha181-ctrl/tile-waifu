extends Control

# main.gd screen adapter for «Лавка» (0.11.0 AAA Monetization & Gacha Funnel).
# Preserves V10PassScreen / V10Purchases routing and tabs 1–2 («Наряды», «Пополнить»),
# while upgrading Tab 0 («Витрина») with BD2/NIKKE-style Hero Offer Banners
# («Подарок хозяйки», «Лунный абонемент», «Сезонный пропуск · Сакура») and the
# interactive «Чай и Подарки симпатии» shelf + header Tea HUD pill.

const HOSTESS_KEY: = "hostess_pack_done"
const HOSTESS_TEA: = 200
const HOSTESS_WISHES: = 10
const HOSTESS_OUTFIT: = "o_dragon"

var main
var _tea_pill: Control = null
var _hooked_view: Control = null
var _active_hostess_sku: = ""


func build(m, args: Dictionary) -> void:
	main = m
	position = Vector2.ZERO
	if m is Control:
		size = (m as Control).get_viewport_rect().size
	var sub_id: = String(args.get("v10", ""))
	if main.has_method("show_chrome"):
		main.show_chrome(false, not (sub_id in ["pass", "purchases"]))
	var model: = V10ShopHub.model()
	if model:
		if V10ShopPay.is_test():
			model.econ.shop.caps["server_wallet"] = true
		model.free_paths_go = V10ShopHub.go_free_cb(main)
		model.ads_stub.host = self
		if not model.econ.shop.delivered.is_connected(_on_shop_delivered):
			model.econ.shop.delivered.connect(_on_shop_delivered)
	V10ShopHub.build_into(self, main, args)
	if not (sub_id in ["pass", "purchases"]):
		_attach_vitrina_hooks.call_deferred()


func _view() -> Control:
	return get_child(0) as Control if get_child_count() > 0 else null


func _attach_vitrina_hooks() -> void:
	var v: = _view()
	if v == null or not is_instance_valid(v):
		return
	_hooked_view = v
	if v.get("seg") != null and not v.seg.changed.is_connected(_on_seg_changed):
		v.seg.changed.connect(_on_seg_changed)
	if not get_viewport().size_changed.is_connected(_on_vp_resized):
		get_viewport().size_changed.connect(_on_vp_resized)
	_inject_header_tea_pill(v)
	if int(v.get("tab")) == 0:
		_upgrade_vitrina(v)


func _on_seg_changed(_idx: int) -> void:
	var v: = _view()
	if v == null:
		return
	_inject_header_tea_pill.call_deferred(v)
	if int(v.get("tab")) == 0:
		_upgrade_vitrina.call_deferred(v)


func _on_vp_resized() -> void:
	var v: = _view()
	if v == null or not is_instance_valid(v):
		return
	_inject_header_tea_pill.call_deferred(v)
	if int(v.get("tab")) == 0:
		_upgrade_vitrina.call_deferred(v)


func _set_tab(i: int) -> void:
	var v: = _view()
	if v and v.has_method("_set_tab"):
		v.call("_set_tab", i)
	elif v and v.get("seg") != null:
		v.seg.select(i)
	if i == 0 and v != null:
		_upgrade_vitrina.call_deferred(v)


func refresh() -> void:
	var v: = _view()
	if v and v.has_method("refresh"):
		v.call("refresh")
	if v != null:
		_inject_header_tea_pill(v)
		if int(v.get("tab")) == 0:
			_upgrade_vitrina(v)
	if main and main.has_method("refresh_currency"):
		main.refresh_currency()


func currency_target(cur: String) -> Vector2:
	var v: = _view()
	if v and v.has_method("currency_target"):
		return v.call("currency_target", cur)
	return Vector2(size.x - 120, 80)


func dev_act(act: String) -> void:
	if act == "stamina" and main != null:
		V10Stamina.open_sheet(main)
	elif act == "tab2":
		_set_tab(2)


func _inject_header_tea_pill(v: Control) -> void:
	var strip: Control = v.get_node_or_null("Strip")
	if strip == null:
		return
	var old: = strip.get_node_or_null("TeaPill")
	if old != null:
		old.queue_free()
	var pill: = V10Stamina.make_pill(main)
	var col_x: = float(v.get("col_x"))
	var col_w: = float(v.get("col_w"))
	var top_y: = float(v.get("top_y"))
	pill.position = Vector2(col_x + col_w - 148.0 * 2.0 - 16.0 - pill.size.x, top_y + 28.0)
	strip.add_child(pill)
	_tea_pill = pill


func _hostess_sku(model: V10ShopModel) -> String:
	for sku_id in ["newbie_499", "guest_149", "first_79"]:
		var c: = model.card(sku_id)
		if not c.is_empty() and bool(c.get("available", false)):
			return sku_id
	return "newbie_499"


func _is_hostess_claimed() -> bool:
	var st: Dictionary = G.S.get("v10_shop", {}) if G.S.get("v10_shop") is Dictionary else {}
	return bool(st.get(HOSTESS_KEY, false))


func _on_shop_delivered(r: Dictionary) -> void:
	var sku: = String(r.get("sku", ""))
	if _active_hostess_sku != "" and sku == _active_hostess_sku:
		_active_hostess_sku = ""
		if not (G.S.get("v10_shop") is Dictionary):
			G.S["v10_shop"] = V10ShopModel.defaults()
		if not bool(G.S.v10_shop.get(HOSTESS_KEY, false)):
			G.S.v10_shop[HOSTESS_KEY] = true
			G.give_new(HOSTESS_OUTFIT)
			V10Money.grant({"tickets": HOSTESS_WISHES}, "hostess_pack")
			V10Stamina.grant(HOSTESS_TEA)
			G.save()
	if is_inside_tree():
		refresh.call_deferred()


# ── BD2 / NIKKE Luxury Vitrina ──────────────────────────────────────────────────────────────────────────────────

func _upgrade_vitrina(v: Control) -> void:
	if v == null or not is_instance_valid(v):
		return
	var scroll: ScrollContainer = v.get_node_or_null("Scroll")
	var model: V10ShopModel = v.get("m")
	if scroll == null or model == null:
		return
	var old_content: Control = v.get("content")
	if is_instance_valid(old_content):
		old_content.name = "OldContent"
		old_content.queue_free()

	var content: = Control.new()
	content.name = "Content"
	content.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.add_child(content)
	v.set("content", content)

	var col_x: = float(v.get("col_x"))
	var col_w: = float(v.get("col_w"))
	var vs: Vector2 = v.get("vs")
	var cash_ok: = model.cash_visible()
	var y: = 0.0
	var anim_nodes: = []

	# 1. Hero Offer Banner: «Подарок хозяйки» (First Purchase / Первый подарок)
	var hero_banner: = _build_hostess_banner(v, model, col_x, y, col_w, cash_ok)
	content.add_child(hero_banner)
	anim_nodes.append(hero_banner)
	y += hero_banner.size.y + 14.0

	# 2. «Лунный абонемент» (30 дней)
	var month_banner: = _build_month_banner(v, model, col_x, y, col_w, cash_ok)
	content.add_child(month_banner)
	anim_nodes.append(month_banner)
	y += month_banner.size.y + 14.0

	# 3. «Сезонный пропуск · Сакура» (16+ Costume Reward)
	var pass_banner: = _build_pass_banner(v, model, col_x, y, col_w, cash_ok)
	content.add_child(pass_banner)
	anim_nodes.append(pass_banner)
	y += pass_banner.size.y + 18.0

	# 4. «Чай и Подарки симпатии» interactive shelf (Tea refills + 3 Affection Gifts)
	var shelf: = _build_tea_and_gifts_shelf(v, model, col_x, y, col_w)
	content.add_child(shelf)
	anim_nodes.append(shelf)
	y += shelf.size.y + 18.0

	# 5. Daily free crystal gift + Featured outfit + Legal/Odds footer below
	if v.has_method("_gift_plate"):
		var gp: Control = v.call("_gift_plate", y)
		if gp != null:
			y += gp.size.y + 16.0
	var fo: = model.outfits("crystal")
	var pick: = {}
	for it in fo:
		if not bool(it.owned):
			pick = it
			break
	if not pick.is_empty() and v.has_method("_featured"):
		var oc: Control = v.call("_featured", pick, y, 420.0)
		if oc != null:
			y += oc.size.y + 16.0
	if v.has_method("_footer"):
		y = float(v.call("_footer", y + 12.0))

	content.custom_minimum_size = Vector2(vs.x, y + 24.0)
	content.size = content.custom_minimum_size
	V10ShopKit.inhale(anim_nodes.slice(0, 4))


func _load_tex(paths: Array) -> Texture2D:
	for p in paths:
		if ResourceLoader.exists(String(p)):
			return load(String(p)) as Texture2D
	return null


func _portrait_crop(tex: Texture2D, rect: Rect2, y_frac: = 0.02, h_scale: = 1.0) -> TextureRect:
	var at: = AtlasTexture.new()
	at.atlas = tex
	var ts: = tex.get_size()
	var region_h: = minf(ts.y * (1.0 - y_frac), (ts.x * rect.size.y / maxf(1.0, rect.size.x)) * h_scale)
	at.region = Rect2(0.0, ts.y * y_frac, ts.x, maxf(1.0, region_h))
	var tr: = V10ShopKit.art(at, rect, true)
	tr.clip_contents = true
	return tr


func _build_hostess_banner(v: Control, model: V10ShopModel, x: float, y: float, w: float, cash_ok: bool) -> Control:
	var h: = 324.0
	var card: = _HeroFrame.new()
	card.name = "HeroHostessBanner"
	card.accent = V10DS.GOLD_300
	card.bg_top = V10DS.BTN_PLAY_BOT
	card.bg_bot = V10DS.NIGHT_900
	card.position = Vector2(x, y)
	card.size = Vector2(w, h)
	card.clip_contents = true

	var bg_tex: = _load_tex(["res://assets/v10/hf_ui/banner_mc_tea.png", "res://assets/v10/shop/bg_shop.webp"])
	if bg_tex:
		var bg_tr: = V10ShopKit.art(bg_tex, Rect2(0, 0, w, h), true)
		bg_tr.modulate = Color(1.0, 0.88, 0.92, 0.34)
		card.add_child(bg_tr)

	var hero_tex: = _load_tex(["res://assets/outfits/mc_dragon.webp", "res://assets/outfits/mc_base.webp"])
	if hero_tex and not bool(G.S.get("modest", false)):
		var h_tr: = _portrait_crop(hero_tex, Rect2(w - 308.0, 2.0, 306.0, h - 4.0), 0.01, 1.08)
		card.add_child(h_tr)
	elif hero_tex:
		var alt_tex: = _load_tex(["res://assets/outfits/mc_cafe.webp", "res://assets/outfits/mc_base.webp"])
		if alt_tex:
			card.add_child(_portrait_crop(alt_tex, Rect2(w - 308.0, 2.0, 306.0, h - 4.0), 0.01, 1.08))

	var scrim: = _BannerScrim.new()
	scrim.size = Vector2(w, h)
	card.add_child(scrim)

	# Glowing "ВЫГОДА ×10" badge + 16+ SSR pill
	var badge: = _GlowBadge.new().setup("ВЫГОДА ×10", V10DS.GOLD_300, V10DS.BTN_PLAY_MID)
	badge.position = Vector2(18, 16)
	card.add_child(badge)

	var tag16: = _GlowBadge.new().setup("SSR · 16+", V10DS.ROSE_300, V10DS.NIGHT_700, false)
	tag16.position = Vector2(18 + badge.size.x + 10.0, 16)
	card.add_child(tag16)

	var ov: = V10ShopKit.lbl("ПЕРВЫЙ ПОДАРОК САЛОНА · ОДИН РАЗ", "overline", 15, V10DS.GOLD_500, true)
	ov.position = Vector2(20, 58)
	ov.size = Vector2(w - 220, 22)
	card.add_child(ov)

	var tl: = V10ShopKit.lbl("Подарок хозяйки", "display", 32, V10DS.PAPER_100, true)
	tl.position = Vector2(20, 80)
	tl.size = Vector2(w - 230, 44)
	card.add_child(tl)

	var rows: = [
		["item_frame", "SSR-наряд «Императрица дракона»"],
		["item_wish", "10 билетов желаний сразу"],
		["item_tea", "200 чашек чая в запас"],
	]
	var ry: = 130.0
	for r in rows:
		var itex: = V10ShopKit.tex(String(r[0]))
		if itex:
			card.add_child(V10ShopKit.art(itex, Rect2(20, ry + 1, 28, 28)))
		var rl: = V10ShopKit.lbl(String(r[1]), "ui_strong", 18, V10DS.PAPER_100, true)
		rl.position = Vector2(54, ry)
		rl.size = Vector2(w - 250, 30)
		card.add_child(rl)
		ry += 32.0

	var sku_id: = _hostess_sku(model)
	var sku_card: = model.card(sku_id)
	var claimed: = _is_hostess_claimed()

	var border_ov: = _FrameOverlay.new()
	border_ov.accent = V10DS.GOLD_300
	border_ov.double_gold = true
	border_ov.size = Vector2(w, h)
	card.add_child(border_ov)

	if claimed:
		var done_l: = V10ShopKit.lbl("Набор хозяйки уже в коллекции", "ui_strong", 18, V10DS.JADE_300, true)
		done_l.position = Vector2(20, h - 54)
		done_l.size = Vector2(w - 40, 32)
		card.add_child(done_l)
	elif cash_ok and not sku_card.is_empty():
		var vl: = V10ShopKit.lbl(V10ShopModel.value_line(sku_card), "ui", 18, V10DS.GOLD_300, true)
		vl.position = Vector2(20, h - 60)
		vl.size = Vector2(w - 248, 28)
		card.add_child(vl)
		var sub_l: = V10ShopKit.lbl("Эксклюзивный образ открывается навсегда", "ui", 18, V10DS.PAPER_300, true)
		sub_l.position = Vector2(20, h - 34)
		sub_l.size = Vector2(w - 248, 24)
		card.add_child(sub_l)

		var cash: = V10ShopW.Cash.new().setup(String(sku_card.price), "", Vector2(212, 64))
		cash.name = "HostessCash"
		cash.position = Vector2(w - 18 - 212, h - 18 - 64)
		cash.enabled = bool(sku_card.available)
		cash._lay()
		cash.pressed.connect(func():
			_active_hostess_sku = sku_id
			var sh: = V10ShopFlow.confirm(v, model, sku_id)
			if sh != null:
				sh.title_l.text = "Подарок хозяйки")
		card.add_child(cash)
	else:
		var info_btn: = V10Button.make("secondary", "Подробнее", Vector2(204, 68))
		info_btn.position = Vector2(w - 18 - 204, h - 18 - 68)
		info_btn.pressed.connect(func():
			V10ShopFlow.info(v, "Подарок хозяйки", [
				"Эксклюзивный SSR-наряд «Императрица дракона» для Маджонг-тян.",
				"Внутри набора: 10 билетов желаний и 200 чашек чая сверху лимита.",
			]))
		card.add_child(info_btn)

	return card


func _build_month_banner(v: Control, model: V10ShopModel, x: float, y: float, w: float, cash_ok: bool) -> Control:
	var h: = 192.0
	var card: = _HeroFrame.new()
	card.name = "HeroMonthBanner"
	card.accent = V10DS.JADE_300
	card.bg_top = V10DS.BTN_SEC_TOP
	card.bg_bot = V10DS.NIGHT_800
	card.position = Vector2(x, y)
	card.size = Vector2(w, h)
	card.clip_contents = true

	var art_tex: = _load_tex(["res://assets/v10/wave1/outfits/sh_night.webp", "res://assets/outfits/yue_queen.webp"])
	if art_tex:
		card.add_child(_portrait_crop(art_tex, Rect2(w - 248.0, 2.0, 246.0, h - 4.0), 0.02, 1.05))

	var scrim: = _BannerScrim.new()
	scrim.size = Vector2(w, h)
	card.add_child(scrim)

	var ic_tex: = V10ShopKit.tex("item_month")
	if ic_tex:
		card.add_child(V10ShopKit.art(ic_tex, Rect2(16, 18, 68, 68)))

	var pill: = _GlowBadge.new().setup("30 ДНЕЙ", V10DS.JADE_300, V10DS.NIGHT_700, false)
	pill.position = Vector2(96, 14)
	card.add_child(pill)

	var tl: = V10ShopKit.lbl("Лунный абонемент", "ui_strong", 22, V10DS.PAPER_100, true)
	tl.position = Vector2(96 + pill.size.x + 10.0, 12)
	tl.size = Vector2(w - 280, 32)
	card.add_child(tl)

	var now_n: = V10ShopTxt.num(int(V10Catalog.MONTH_NOW.moon))
	var day_n: = V10ShopTxt.num(int(V10Catalog.MONTH_DAILY.crystal))
	var l1: = V10ShopKit.lbl("+%s камня сразу и +%s крист. в день" % [now_n, day_n], "ui_strong", 18, V10DS.GOLD_300, true)
	l1.position = Vector2(96, 50)
	l1.size = Vector2(w - 204, 28)
	card.add_child(l1)

	var l2: = V10ShopKit.lbl("+60 чашек чая в день · бонусы без роликов", "ui", 18, V10DS.PAPER_100, true)
	l2.position = Vector2(96, 80)
	l2.size = Vector2(w - 204, 28)
	card.add_child(l2)

	var mc: = model.card("month_449")
	var days_left: = model.econ.shop.month_days_left()

	var border_ov: = _FrameOverlay.new()
	border_ov.accent = V10DS.GOLD_500
	border_ov.size = Vector2(w, h)
	card.add_child(border_ov)

	if cash_ok and not mc.is_empty():
		var vline: = "Активен ещё %d дн." % days_left if days_left > 0 else V10ShopModel.value_line(mc)
		var vl: = V10ShopKit.lbl(vline, "ui", 18, V10DS.PAPER_300, true)
		vl.position = Vector2(20, h - 46)
		vl.size = Vector2(w - 236, 28)
		card.add_child(vl)

		var cash: = V10ShopW.Cash.new().setup(String(mc.price), "Продлить" if days_left > 0 else "", Vector2(228 if days_left > 0 else 192, 60))
		cash.name = "MonthCash"
		cash.position = Vector2(w - 16 - cash.size.x, h - 16 - 60)
		cash.enabled = bool(mc.available)
		cash._lay()
		cash.pressed.connect(func(): V10ShopFlow.confirm(v, model, "month_449"))
		card.add_child(cash)
	else:
		var vl2: = V10ShopKit.lbl("Не подписка · без автопродления", "ui", 18, V10DS.PAPER_300, true)
		vl2.position = Vector2(20, h - 46)
		vl2.size = Vector2(w - 236, 28)
		card.add_child(vl2)

	return card


func _build_pass_banner(v: Control, model: V10ShopModel, x: float, y: float, w: float, cash_ok: bool) -> Control:
	var h: = 196.0
	var card: = _HeroFrame.new()
	card.name = "HeroPassBanner"
	card.accent = V10DS.ROSE_300
	card.bg_top = V10DS.PLATE_SEL_TOP
	card.bg_bot = V10DS.NIGHT_800
	card.position = Vector2(x, y)
	card.size = Vector2(w, h)
	card.clip_contents = true

	var sakura_tex: = _load_tex(["res://assets/v10/wave1/outfits/ko_vow.webp", "res://assets/outfits/yue_ball.webp"])
	if sakura_tex:
		card.add_child(_portrait_crop(sakura_tex, Rect2(w - 252.0, 2.0, 250.0, h - 4.0), 0.02, 1.05))

	var scrim: = _BannerScrim.new()
	scrim.size = Vector2(w, h)
	card.add_child(scrim)

	var ic_tex: = V10ShopKit.tex("item_pass")
	if ic_tex:
		card.add_child(V10ShopKit.art(ic_tex, Rect2(16, 18, 68, 68)))

	var pill: = _GlowBadge.new().setup("КОСТЮМ 16+", V10DS.ROSE_300, V10DS.BTN_PLAY_MID, false)
	pill.position = Vector2(96, 14)
	card.add_child(pill)

	var tl: = V10ShopKit.lbl("Сезонный пропуск · Сакура", "ui_strong", 22, V10DS.PAPER_100, true)
	tl.position = Vector2(96 + pill.size.x + 10.0, 12)
	tl.size = Vector2(w - 290, 32)
	card.add_child(tl)

	var tot: = V10Catalog.pass_track_total(true)
	var cr_n: = V10ShopTxt.num(int(tot.get("crystal", 1000)))
	var wi_amt: = V10ShopTxt.amount("wish", int(tot.get("wish", 5)))
	var l1: = V10ShopKit.lbl("Эксклюзивный 16+ образ + %s крист." % cr_n, "ui_strong", 18, V10DS.GOLD_300, true)
	l1.position = Vector2(96, 50)
	l1.size = Vector2(w - 204, 28)
	card.add_child(l1)

	var l2: = V10ShopKit.lbl("Премиум-дорожка: +%s и чай сезона" % wi_amt, "ui", 18, V10DS.PAPER_100, true)
	l2.position = Vector2(96, 80)
	l2.size = Vector2(w - 204, 28)
	card.add_child(l2)

	var pc: = model.card("pass_899")
	var prem_owned: = bool(model.econ.pass_.st.get("prem", false))
	var vl_txt: = "Премиум открыт · забирай награды" if prem_owned else (V10ShopModel.value_line(pc) if cash_ok and not pc.is_empty() else "30 ступеней наград сезона")
	var vl: = V10ShopKit.lbl(vl_txt, "ui", 18, V10DS.PAPER_300, true)
	vl.position = Vector2(20, h - 46)
	vl.size = Vector2(w - 236, 28)
	card.add_child(vl)

	var border_ov: = _FrameOverlay.new()
	border_ov.accent = V10DS.ROSE_300
	border_ov.size = Vector2(w, h)
	card.add_child(border_ov)

	var open_btn: = V10Button.make("secondary", "Открыть", Vector2(196, 64))
	open_btn.name = "OpenSeasonPass"
	open_btn.position = Vector2(w - 16 - 196, h - 16 - 64)
	open_btn.pressed.connect(func():
		V10ShopKit.press(open_btn)
		if main and main.has_method("go"):
			main.go("shop", {"v10": "pass"}))
	card.add_child(open_btn)

	return card


# ── «Чай и Подарки симпатии» Shelf ──────────────────────────────────────────────────────────────────────────────

func _build_tea_and_gifts_shelf(v: Control, _model: V10ShopModel, x: float, y: float, w: float) -> Control:
	var partner: = String(G.S.get("partner", "mc"))
	if not G.HEROES.has(partner):
		partner = "mc"
	var hname: = String(G.HEROES[partner].get("name", "Маджонг-тян"))
	var pinfo: = V10AffCurve.hero_progress(partner)
	var plv: = int(pinfo.get("level", 1))
	var pinto: = int(pinfo.get("into", 0))
	var pneed: = int(pinfo.get("need", 120))

	var box: = Control.new()
	box.name = "TeaAndGiftsShelf"
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.position = Vector2(x, y)

	var hdr: = V10ShopKit.lbl("Чай и Подарки симпатии", "ui_strong", 22, V10DS.GOLD_300, true)
	hdr.position = Vector2(0, 4)
	hdr.size = Vector2(340, 32)
	box.add_child(hdr)

	var aff_badge: = V10ShopKit.lbl("♥ %s · Ур. %d (%d/%d)" % [hname, plv, pinto, pneed], "ui", 18, V10DS.ROSE_300, true)
	aff_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	aff_badge.position = Vector2(320, 6)
	aff_badge.size = Vector2(w - 320, 28)
	box.add_child(aff_badge)

	var cw: = (w - 16.0) * 0.5
	var ch: = 186.0
	var gy: = 44.0

	# Card 0: Tea Refill / Daily Kettle
	var tea_card: = _build_tea_shelf_card(v, Vector2(cw, ch))
	tea_card.position = Vector2(0, gy)
	box.add_child(tea_card)

	# Cards 1..3: Affection Gifts
	for i in V10AffCurve.GIFTS.size():
		var gdef: Dictionary = V10AffCurve.GIFTS[i]
		var slot: = i + 1
		var gc: = _build_gift_shelf_card(v, gdef, partner, hname, Vector2(cw, ch))
		gc.position = Vector2((slot % 2) * (cw + 16.0), gy + (slot / 2) * (ch + 14.0))
		box.add_child(gc)

	box.size = Vector2(w, gy + ch * 2.0 + 14.0)
	return box


func _build_tea_shelf_card(v: Control, sz: Vector2) -> Control:
	var c: = V10ShopW.Lac.new()
	c.name = "ShelfTeaCard"
	c.bevel = 10.0
	c.selected = V10Stamina.kettle_ready()
	c.size = sz

	var t: = V10ShopKit.tex("item_tea")
	if t:
		c.add_child(V10ShopKit.art(t, Rect2(14, 14, 68, 68)))

	var pill: = _GlowBadge.new().setup(
		"БЕСПЛАТНО +60" if V10Stamina.kettle_ready() else "+%d ЧАШЕК" % V10Stamina.REFILL_AMOUNT,
		V10DS.JADE_300, V10DS.NIGHT_700, false)
	pill.position = Vector2(92, 12)
	c.add_child(pill)

	var tl: = V10ShopKit.lbl("Свежая заварка", "ui_strong", 20, V10DS.PAPER_100)
	tl.position = Vector2(92, 44)
	tl.size = Vector2(sz.x - 102, 28)
	c.add_child(tl)

	var sub_txt: = "Чайник дня готов!" if V10Stamina.kettle_ready() else "Запас: %d/%d · +1 за 6 мин" % [V10Stamina.current(), V10Stamina.cap()]
	var sl: = V10ShopKit.lbl(sub_txt, "ui", 18, V10DS.PAPER_300)
	sl.position = Vector2(14, 86)
	sl.size = Vector2(sz.x - 28, 26)
	c.add_child(sl)

	if V10Stamina.kettle_ready():
		var kb: = V10Button.make("play", "Налить +60", Vector2(sz.x - 28, 56))
		kb.sheen = false
		kb.position = Vector2(14, sz.y - 68)
		kb.pressed.connect(func():
			if V10Stamina.claim_kettle():
				V10ShopKit.press(kb, true)
				V10ShopKit.toast(v, "Чайник дня: +60 чашек чая!")
				refresh())
		c.add_child(kb)
	else:
		var pr: = V10Stamina.refill_price()
		var chip: = V10ShopW.Chip.new().setup(V10ShopKit.tex("item_crystal"), "%d · Пополнить" % pr, Vector2(sz.x - 28, 56))
		chip.position = Vector2(14, sz.y - 68)
		chip.pressed.connect(func():
			if main != null:
				V10Stamina.open_sheet(main))
		c.add_child(chip)

	return c


func _build_gift_shelf_card(v: Control, gdef: Dictionary, partner: String, hname: String, sz: Vector2) -> Control:
	var gid: = String(gdef.id)
	var rar: = String(gdef.rar)
	var c: = V10ShopW.Lac.new()
	c.name = "Shelf_" + gid
	c.bevel = 10.0
	c.selected = (rar == "SSR")
	c.size = sz

	var t: = V10ShopKit.tex(String(gdef.art))
	if t:
		c.add_child(V10ShopKit.art(t, Rect2(14, 14, 68, 68)))

	var pcol: = V10DS.GOLD_300 if rar == "SSR" else (V10DS.ROSE_300 if rar == "S" else V10DS.JADE_300)
	var pill: = _GlowBadge.new().setup("+%d ♥" % int(gdef.aff), pcol, V10DS.NIGHT_700, false)
	pill.position = Vector2(92, 12)
	c.add_child(pill)

	var tl: = V10ShopKit.lbl("", "ui_strong", 20, V10DS.PAPER_100)
	V10Type.fit(tl, String(gdef.name), "title_sm", sz.x - 102, 1, V10DS.PAPER_100)
	tl.position = Vector2(92, 44)
	tl.size = Vector2(sz.x - 102, 28)
	c.add_child(tl)

	var owned_cnt: = V10AffCurve.gift_count(gid)
	var sub_txt: = "В сумке: %d шт. · подарить" % owned_cnt if owned_cnt > 0 else String(gdef.desc)
	var sl: = V10ShopKit.lbl(sub_txt, "ui", 18, V10DS.PAPER_300)
	sl.position = Vector2(14, 86)
	sl.size = Vector2(sz.x - 28, 26)
	c.add_child(sl)

	var cur_key: = String(gdef.cur)
	var ic_name: = "item_coin" if cur_key == "coins" else "item_crystal"
	var btn_txt: = "Подарить" if owned_cnt > 0 else "%s · Дар" % V10ShopTxt.num(int(gdef.price))
	var chip: = V10ShopW.Chip.new().setup(V10ShopKit.tex(ic_name), btn_txt, Vector2(sz.x - 28, 56))
	chip.name = "Buy_" + gid
	chip.position = Vector2(14, sz.y - 68)
	chip.pressed.connect(func(): _on_give_gift(v, chip, gdef, partner, hname))
	c.add_child(chip)

	return c


func _on_give_gift(v: Control, btn: Control, gdef: Dictionary, partner: String, hname: String) -> void:
	var gid: = String(gdef.id)
	var res: = V10AffCurve.buy_and_give_gift(gid, partner)
	if not bool(res.get("ok", false)):
		if String(res.get("cur", "")) == "coins":
			V10ShopKit.toast(v, "Не хватает монет (нужно %d)" % int(gdef.price))
		elif main != null and main.has_method("need_gems"):
			main.need_gems(int(res.get("short", 100)))
		else:
			V10ShopKit.toast(v, "Не хватает кристаллов")
		return
	G.save()
	var src_pt: = btn.get_global_rect().get_center() - v.get_global_rect().position
	V10ShopKit.fly(v, src_pt, Vector2(v.size.x * 0.5, 96.0), V10ShopKit.tex("item_gift"), 4)
	var ms: Dictionary = res.get("milestone", {})
	if not ms.is_empty():
		V10ShopKit.hanko(v, v.size * Vector2(0.5, 0.45))
		V10ShopKit.toast(v, "%s · Ур. %d! Открыто: %s" % [hname, int(res.new_level), String(ms.get("title", ""))])
	else:
		V10ShopKit.toast(v, "%s +%d ♥ (Симпатия · Ур. %d)" % [hname, int(res.aff), int(res.new_level)])
	refresh()


# ── Luxury Decorative Inner Controls ────────────────────────────────────────────────────────────────────────────

class _HeroFrame:
	extends Control
	var accent: = V10DS.GOLD_300
	var bg_top: = V10DS.PLATE_TOP
	var bg_bot: = V10DS.NIGHT_900

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS

	func _draw() -> void:
		draw_polygon(
			PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]),
			PackedColorArray([bg_top, bg_top.darkened(0.22), bg_bot, bg_bot])
		)


class _BannerScrim:
	extends Control

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var w: = size.x
		var h: = size.y
		var c_left: = Color(V10DS.NIGHT_900, 0.95)
		var c_mid: = Color(V10DS.NIGHT_900, 0.78)
		var c_right: = Color(V10DS.NIGHT_900, 0.10)
		draw_polygon(
			PackedVector2Array([Vector2(0, 0), Vector2(w * 0.58, 0), Vector2(w * 0.58, h), Vector2(0, h)]),
			PackedColorArray([c_left, c_mid, c_mid, c_left])
		)
		draw_polygon(
			PackedVector2Array([Vector2(w * 0.58, 0), Vector2(w, 0), Vector2(w, h), Vector2(w * 0.58, h)]),
			PackedColorArray([c_mid, c_right, c_right, c_mid])
		)
		var c_bot0: = Color(V10DS.NIGHT_900, 0.0)
		var c_bot1: = Color(V10DS.NIGHT_900, 0.88)
		draw_polygon(
			PackedVector2Array([Vector2(0, h * 0.62), Vector2(w, h * 0.62), Vector2(w, h), Vector2(0, h)]),
			PackedColorArray([c_bot0, c_bot0, c_bot1, c_bot1])
		)


class _FrameOverlay:
	extends Control
	var accent: = V10DS.GOLD_300
	var double_gold: = false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var sb: = StyleBoxFlat.new()
		sb.bg_color = Color.TRANSPARENT
		sb.set_border_width_all(2)
		sb.border_color = accent
		sb.set_corner_radius_all(8)
		sb.anti_aliasing = true
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		var inn: = StyleBoxFlat.new()
		inn.bg_color = Color.TRANSPARENT
		inn.set_border_width_all(1)
		inn.border_color = Color(V10DS.PLATE_SPARK if double_gold else accent, 0.42 if double_gold else 0.26)
		inn.set_corner_radius_all(6)
		draw_style_box(inn, Rect2(Vector2(5, 5), size - Vector2(10, 10)))
		if double_gold:
			for corner in [Vector2(10, 10), Vector2(size.x - 10, 10), Vector2(10, size.y - 10), Vector2(size.x - 10, size.y - 10)]:
				draw_colored_polygon(PackedVector2Array([
					corner + Vector2(0, -4), corner + Vector2(4, 0),
					corner + Vector2(0, 4), corner + Vector2(-4, 0)]), V10DS.PLATE_SPARK)


class _GlowBadge:
	extends Control
	var border_col: = V10DS.GOLD_300
	var fill_col: = V10DS.BTN_PLAY_MID
	var glow_on: = true

	func setup(txt: String, border: Color, fill: Color, glow: bool = true) -> _GlowBadge:
		border_col = border
		fill_col = fill
		glow_on = glow
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tw: = V10Type.text_w(txt, "overline", 15)
		size = Vector2(tw + 28.0, 30.0)
		var l: = V10Type.label(txt, "overline", 15, V10DS.BTN_PLAY_TEXT if glow else border)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.size = size
		add_child(l)
		return self

	func _draw() -> void:
		if glow_on:
			var gsb: = StyleBoxFlat.new()
			gsb.bg_color = Color(border_col, 0.22)
			gsb.set_corner_radius_all(16)
			draw_style_box(gsb, Rect2(Vector2(-3, -3), size + Vector2(6, 6)))
		var sb: = StyleBoxFlat.new()
		sb.bg_color = fill_col
		sb.set_border_width_all(2 if glow_on else 1)
		sb.border_color = border_col
		sb.set_corner_radius_all(14)
		sb.anti_aliasing = true
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
