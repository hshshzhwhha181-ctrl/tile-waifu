class_name V10DuelScreen
extends Control

# V10DuelScreen — экран «Дуэли 2.0» (docs/MODES.md §7.1, docs/0.10-spec.md R6, UX_RULES §3.4/§3.7/§10).
# Сегмент «Дружеская / Рейтинговая», карточка «Дуэль недели» (по сетке V10Meta.cal_key), явный показ подлости
# и её потолка ≤ 2 до боя, бейдж «ИИ · героиня», переход в «Вызов по коду», заставка V10DuelVs и сигнал finished.

signal finished(result: Dictionary)
signal challenge_opened

const U: = preload("res://scripts/v10/duels/duel_util.gd")
const F: = preload("res://scripts/v10/duels/duel_forms.gd")
const R: = preload("res://scripts/v10/duels/duel_rank.gd")
const C: = preload("res://scripts/v10/duels/duel_cfg.gd")
const D: = preload("res://scripts/v10/duels/duel_state.gd")
const RUN: = preload("res://scripts/v10/duels/duel_run.gd")
const PLAY2: = preload("res://scripts/v10/duels/duel_play.gd")
const INFO: = preload("res://scripts/v10/duels/duel_info.gd")
const VS: = preload("res://scripts/v10/duels/duel_vs.gd")
const CH_U: = preload("res://scripts/v10/duels/challenge/challenge_util.gd")

const COL_W: = 720.0
const M: = 32.0

const TITLE_DUELS: = "Дуэли"
const TAB_FRIENDLY: = "Дружеская"
const TAB_RANKED: = "Рейтинговая"
const BTN_FIGHT: = "В бой"
const BTN_TO_FRIENDLY: = "К дружеской"
const BTN_CHALLENGE: = "Вызов по коду"
const BTN_GOT_IT: = "Понятно"
const BTN_PVP: = "Онлайн PvP · Живые игроки ›"
const PVP_SOON: = "Онлайн-арена откроется с обновлением сервера"

var _floor: = 0.0

var main = null
var args: Dictionary = {}
var header: V10Header = null
var page: Control = null
var seg: Control = null
var btn_primary: V10Button = null
var btn_challenge: V10Button = null
var active_sheet: V10BottomSheet = null

var tab: = "ranked"
var sel_kind: = "ranked"     # "ranked" | "friendly" | "weekly"
var sel_ranked_idx: = 0
var sel_hero: = "rin"
var sel_form: = 3
var skip_vs_in_test: = false

var vs: = Vector2(720, 1280)
var cx: = 0.0
var safe_b: = 0.0
var _local_host: Control = null
var _t0_ms: = 0


func build(m, a: Dictionary = {}) -> void:
	setup(m, a)


func setup(m, a: Dictionary = {}) -> void:
	main = m
	args = a.duplicate(true)
	_t0_ms = U.tick_ms()
	R.register_cos()
	if main and main.has_method("show_chrome"):
		main.call("show_chrome", false, false)
	if size.x <= 0.0 or size.y <= 0.0:
		var vr: = get_viewport_rect().size if is_inside_tree() else Vector2(720, 1280)
		size = vr if vr.x > 0.0 else Vector2(720, 1280)
	_metrics()
	for c in get_children():
		c.queue_free()
	var bg: = _DuelBg.new()
	bg.name = "Bg"
	bg.size = vs
	add_child(bg)
	header = V10Header.make(self, TITLE_DUELS, _on_back, open_help)
	if header.back_btn:
		header.back_btn.set_meta("ux_role", "tertiary")
	if header.help_btn:
		header.help_btn.set_meta("ux_role", "tertiary")
	_ensure_local_host()
	var hs: = D.friendly_heroes()
	if not hs.has(sel_hero) and not hs.is_empty():
		sel_hero = String(hs[0])
	if args.has("tab"):
		tab = String(args.tab)
	else:
		tab = "ranked" if D.ranked_open() else "friendly"
	sel_kind = "weekly" if String(args.get("focus", "")) == "weekly" else tab
	refresh()
	var sr: = D.take_season_reward()
	if not sr.is_empty():
		_open_season_sheet(sr)


func _metrics() -> void:
	vs = get_viewport_rect().size if is_inside_tree() else size
	if vs.x <= 0.0 or vs.y <= 0.0:
		vs = Vector2(720, 1280)
	size = vs
	cx = floorf(maxf(0.0, (vs.x - COL_W) * 0.5))
	safe_b = float(main.safe_bottom) if (main and "safe_bottom" in main) else float(V10Hud2Util.safe_insets(vs).bottom)


func _ensure_local_host() -> void:
	if main and main.get("overlay") is Control:
		return
	_local_host = _LocalHost.new()
	_local_host.name = "LocalHost"
	_local_host.size = vs
	_local_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_local_host)


func _sheet_host():
	if main and main.get("overlay") is Control:
		return main
	return _local_host


func _y0() -> float:
	return V10Header.content_y(vs)


func _lbl(txt: String, role: String, px: int, col: Color, w: float, lines: int = 1) -> Label:
	var l: = V10Type.label(txt, role, px, col)
	if lines > 1:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.max_lines_visible = lines
	else:
		l.clip_text = true
	l.size = Vector2(w, float(px) * 1.4 * float(lines))
	return l


func select_tab(new_tab: String) -> void:
	tab = "ranked" if new_tab == "ranked" else "friendly"
	if sel_kind != "weekly":
		sel_kind = tab
	else:
		sel_kind = tab
	refresh()


func select_weekly() -> void:
	var w: = D.weekly_offer()
	if bool(w.get("claimed", false)):
		return
	sel_kind = "weekly"
	refresh()


func refresh() -> void:
	btn_primary = null
	btn_challenge = null
	seg = null
	if page and is_instance_valid(page):
		page.free()
	page = Control.new()
	page.name = "Page"
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.position = Vector2(cx, 0)
	page.size = Vector2(COL_W, vs.y)
	add_child(page)
	move_child(page, header.get_index())

	var y: = _y0()
	var w_col: = COL_W - 2.0 * M

	# 1st secondary: Дружеская / Рейтинговая segmented control (80 px high)
	seg = _DuelSeg.new()
	seg.name = "ModeSegment"
	seg.position = Vector2(M, y)
	seg.size = Vector2(w_col, 80.0)
	seg.set_meta("ux_role", "secondary")
	seg.setup_tabs([TAB_FRIENDLY, TAB_RANKED], 1 if tab == "ranked" else 0, func(idx: int):
		select_tab("ranked" if idx == 1 else "friendly"))
	page.add_child(seg)
	y += 92.0

	# Bottom actions placed first so content knows its exact floor (primary >= 440x104 in bottom third)
	var yb: = vs.y - safe_b - 20.0
	btn_challenge = V10Button.make("secondary", BTN_CHALLENGE, Vector2(560, 80))
	btn_challenge.name = "BtnChallenge"
	btn_challenge.set_meta("ux_role", "secondary")
	btn_challenge.position = Vector2((COL_W - 560.0) * 0.5, yb - 80.0)
	btn_challenge.pressed.connect(open_challenge)
	page.add_child(btn_challenge)
	yb -= 88.0

	var locked_ranked: = (tab == "ranked" and not D.ranked_open() and sel_kind != "weekly")
	var p_label: = BTN_TO_FRIENDLY if locked_ranked else BTN_FIGHT
	btn_primary = V10Button.make("play", p_label, Vector2(560, 104))
	btn_primary.name = "BtnFight"
	btn_primary.set_meta("ux_role", "primary")
	btn_primary.position = Vector2((COL_W - 560.0) * 0.5, yb - 104.0)
	btn_primary.pressed.connect(func():
		if locked_ranked:
			select_tab("friendly")
		else:
			start_selected())
	page.add_child(btn_primary)

	# 0.12: «Онлайн PvP · Живые игроки ›» over the fight button: the live arena (v10pvp) beside the AI duels
	var pvp: = _PvpEntry.new()
	pvp.name = "PvpOnline"
	pvp.btn_size = Vector2(560.0, 80.0)
	pvp.size = Vector2(560.0, 80.0)
	pvp.position = Vector2((COL_W - 560.0) * 0.5, btn_primary.position.y - 12.0 - 80.0)
	var pl: = _lbl(BTN_PVP, "ui", 22, V10DS.NIGHT_900, 560.0 - 120.0, 1)
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pl.position = Vector2(60.0, 0.0)
	pl.size = Vector2(560.0 - 120.0, 80.0)
	pvp.add_child(pl)
	pvp.pressed.connect(open_pvp)
	page.add_child(pvp)
	_floor = pvp.position.y - 16.0

	# Дуэль недели card (seeded via V10Meta.cal_key / V10Duel.weekly_offer)
	var wk: = D.weekly_offer()
	var wk_card: = _DuelCard.new()
	wk_card.name = "WeeklyCard"
	wk_card.position = Vector2(M, y)
	wk_card.size = Vector2(w_col, 100.0)
	wk_card.selected = (sel_kind == "weekly")
	wk_card.accent = V10DS.JADE_500 if bool(wk.get("claimed", false)) else V10DS.GOLD_500
	var wk_rule: Dictionary = wk.get("rule", {})
	var wk_t1: = _lbl("Дуэль недели · %s · %s" % [String(wk.name), String(wk.badge)], "ui", 22, V10DS.PAPER_100, w_col - 36.0, 1)
	wk_t1.position = Vector2(18, 10)
	wk_card.add_child(wk_t1)
	var wk_sub: = "%s · %s · %s" % [String(wk_rule.get("name", "")), String(wk.trick_text), String(wk.progress_text)]
	var wk_t2: = _lbl(wk_sub, "ui", 18, V10DS.GOLD_300, w_col - 36.0, 1)
	wk_t2.position = Vector2(18, 42)
	wk_card.add_child(wk_t2)
	var wk_t3: = _lbl("%s · %s" % [String(wk.reward_text), String(wk.until_text)], "ui", 18, V10DS.PAPER_500, w_col - 36.0, 1)
	wk_t3.position = Vector2(18, 68)
	wk_card.add_child(wk_t3)
	if not bool(wk.get("claimed", false)):
		wk_card.enable_tap(select_weekly)
	page.add_child(wk_card)
	y += 112.0

	if tab == "ranked":
		_build_ranked(y, w_col)
	else:
		_build_friendly(y, w_col)

func _build_ranked(y: float, w_col: float) -> void:
	if not D.ranked_open():
		var lbox: = _DuelCard.new()
		lbox.name = "RankedLockCard"
		lbox.position = Vector2(M, y)
		lbox.size = Vector2(w_col, 152.0)
		var l1: = _lbl(D.lock_text("ranked"), "ui", 22, V10DS.PAPER_100, w_col - 36.0, 2)
		l1.position = Vector2(18, 22)
		lbox.add_child(l1)
		var cw: = int(D.st().casual_wins)
		var l2: = _lbl("Дружеские победы: %d из %d" % [cw, R.CASUAL_FOR_RANKED], "ui", 18, V10DS.GOLD_300, w_col - 36.0, 1)
		l2.position = Vector2(18, 98)
		lbox.add_child(l2)
		page.add_child(lbox)
		return

	var si: = D.season_info()
	var cp: = D.caps()
	# 0.12: the win reward moved onto the parade card (gem + «+5»); the line keeps it only while it reads «завтра»
	var rk_gems: = String(cp.ranked_text).begins_with("Победа")
	var s_line: = _lbl(("%s · %s" % [String(si.rating_text), String(si.tier_name)]) if rk_gems else ("%s · %s · %s" % [String(si.rating_text), String(si.tier_name), String(cp.ranked_text)]), "ui", 18, V10DS.PAPER_300, w_col, 1)
	s_line.name = "RankedMeta"
	s_line.position = Vector2(M, y)
	page.add_child(s_line)
	y += 32.0

	var offs: = D.offers()
	sel_ranked_idx = clampi(sel_ranked_idx, 0, maxi(0, offs.size() - 1))
	for i in offs.size():
		var o: Dictionary = offs[i]
		var card: = _DuelCard.new()
		card.name = "Offer_%d" % i
		card.position = Vector2(M, y)
		card.size = Vector2(w_col, 88.0)
		card.selected = (sel_kind == "ranked" and sel_ranked_idx == i)
		card.accent = V10DS.hero(String(o.rival)).accent if V10DS.HEROES.has(String(o.rival)) else V10DS.GOLD_500
		var t1: = _lbl("%s · Форма %s" % [String(o.name), String(o.roman)], "ui", 22, V10DS.PAPER_100, w_col - 36.0, 1)
		t1.position = Vector2(18, 10)
		card.add_child(t1)
		var t2: = _lbl("%s · шанс: %s" % [String(o.trick_text), String(o.chance_text)], "ui", 18, V10DS.GOLD_300 if card.selected else V10DS.PAPER_300, w_col - 36.0, 1)
		t2.position = Vector2(18, 48)
		card.add_child(t2)
		var idx: = i
		card.enable_tap(func():
			sel_kind = "ranked"
			sel_ranked_idx = idx
			refresh())
		page.add_child(card)
		y += 96.0

	var cur: = current_offer()
	if not cur.is_empty():
		var tk: = F.trick(String(cur.rival))
		var det: = _lbl("Подлость: %s" % String(tk.desc), "ui", 18, V10DS.PAPER_300, w_col, 2)
		det.name = "TrickDesc"
		# 0.12: her parade card fills the arena; the «Подлость» line sits in it under her name and stars
		var rk_g: = D.WEEKLY_GEMS if sel_kind == "weekly" else (D.RANKED_WIN_GEMS if String(D.caps().ranked_text).begins_with("Победа") else 0)
		var rshow: = _rival_show(y + 8.0, w_col, String(cur.rival), int(cur.get("form", 3)), rk_g)
		if rshow:
			det.position = Vector2(24.0, rshow.star_y + 40.0)
			det.size.x = w_col * 0.5
			det.max_lines_visible = 4
			det.size.y = 18.0 * 1.4 * 4.0
			det.add_theme_constant_override("line_spacing", 2)
			rshow.add_child(det)
		else:
			det.position = Vector2(M, y + 4.0)
			page.add_child(det)


func _build_friendly(y: float, w_col: float) -> void:
	var cp: = D.caps()
	var f_meta: = _lbl(String(cp.friendly_text), "ui", 18, V10DS.PAPER_300, w_col, 1)
	f_meta.name = "FriendlyMeta"
	f_meta.position = Vector2(M, y)
	page.add_child(f_meta)
	y += 32.0

	var hs: = D.friendly_heroes()
	if not hs.has(sel_hero) and not hs.is_empty():
		sel_hero = String(hs[0])
	var h_names: Array = []
	for h in hs:
		h_names.append(U.hero_name(String(h)))
	var h_idx: = maxi(0, hs.find(sel_hero))
	var h_bar: = _ChoiceBar.new()
	h_bar.name = "HeroPicker"
	h_bar.position = Vector2(M, y)
	h_bar.size = Vector2(w_col, 80.0)
	h_bar.setup_choices(h_names, h_idx, func(idx: int):
		sel_hero = String(hs[clampi(idx, 0, hs.size() - 1)])
		sel_kind = "friendly"
		refresh())
	page.add_child(h_bar)
	y += 90.0

	var f_forms: = F.FRIENDLY_FORMS
	if not (sel_form in f_forms):
		sel_form = 3
	var f_labels: Array = []
	for fn in f_forms:
		f_labels.append("Форма %s" % F.roman(int(fn)))
	var f_bar: = _ChoiceBar.new()
	f_bar.name = "FormPicker"
	f_bar.position = Vector2(M, y)
	f_bar.size = Vector2(w_col, 80.0)
	f_bar.setup_choices(f_labels, maxi(0, f_forms.find(sel_form)), func(idx: int):
		sel_form = int(f_forms[clampi(idx, 0, f_forms.size() - 1)])
		sel_kind = "friendly"
		refresh())
	page.add_child(f_bar)
	y += 92.0

	var fo_list: = D.friendly_offers(sel_hero)
	var fo: Dictionary = {}
	for x in fo_list:
		if int(x.form) == sel_form:
			fo = x
			break
	if fo.is_empty() and not fo_list.is_empty():
		fo = fo_list[0]
	var pcard: = _DuelCard.new()
	pcard.name = "FriendlyRivalCard"
	pcard.position = Vector2(M, y)
	pcard.size = Vector2(w_col, 136.0)
	pcard.selected = (sel_kind == "friendly")
	pcard.accent = V10DS.hero(sel_hero).accent if V10DS.HEROES.has(sel_hero) else V10DS.ROSE_500
	var p1: = _lbl("%s · Форма %s · %s" % [U.hero_name(sel_hero), F.roman(sel_form), String(fo.get("badge", "ИИ · героиня"))], "ui", 22, V10DS.PAPER_100, w_col - 36.0, 1)
	p1.position = Vector2(18, 14)
	pcard.add_child(p1)
	var p2: = _lbl("Подлость: %s" % F.trick_text(sel_hero, sel_form), "ui", 18, V10DS.GOLD_300, w_col - 36.0, 1)
	p2.position = Vector2(18, 54)
	pcard.add_child(p2)
	var p3: = _lbl(String(F.trick(sel_hero).desc), "ui", 18, V10DS.PAPER_300, w_col - 36.0, 2)
	p3.position = Vector2(18, 86)
	pcard.add_child(p3)
	pcard.enable_tap(func():
		sel_kind = "friendly"
		refresh())
	page.add_child(pcard)
	_rival_show(y + 148.0, w_col, sel_hero, sel_form, D.FRIENDLY_WIN_GEMS if String(cp.friendly_text).contains("+") else 0)

func current_offer() -> Dictionary:
	if sel_kind == "weekly":
		return D.weekly_offer()
	if tab == "ranked":
		if not D.ranked_open():
			return {}
		var offs: = D.offers()
		if offs.is_empty():
			return {}
		return offs[clampi(sel_ranked_idx, 0, offs.size() - 1)]
	var fo_list: = D.friendly_offers(sel_hero)
	for x in fo_list:
		if int(x.form) == sel_form:
			return x
	return fo_list[0] if not fo_list.is_empty() else {}


func start_selected() -> Dictionary:
	var off: = current_offer()
	if off.is_empty():
		return {"error": "Выбери соперницу"}
	var S: = U.save()
	var partner: = String(S.get("level_partner", "mc"))
	var margs: = D.start(off, partner)
	if margs.has("error"):
		refresh()
		return margs
	_launch_match(margs)
	return margs


func _launch_match(margs: Dictionary) -> void:
	if not skip_vs_in_test:
		await VS.play_over(_sheet_host(), margs)
	else:
		D.mark_vs_seen()
	if main == null or not is_instance_valid(main):
		return
	var scr_map = main.get("SCREENS")
	var play_ctrl: Control = null
	if scr_map is Dictionary and (scr_map as Dictionary).has("duel2"):
		main.call("go", "duel2", margs)
		play_ctrl = main.get("screen")
	else:
		play_ctrl = _mount_duel_play(margs)
	if play_ctrl and play_ctrl.get("duel") != null and play_ctrl.duel.has_signal("result_ready"):
		var self_ref: = self
		play_ctrl.duel.result_ready.connect(func(res: Dictionary):
			if is_instance_valid(self_ref):
				self_ref.finished.emit(_to_mode_result(res)))


func _mount_duel_play(margs: Dictionary) -> Control:
	if main.get("overlay") is Control:
		for c in main.overlay.get_children():
			c.queue_free()
	if main.get("screen") and is_instance_valid(main.screen):
		main.screen.queue_free()
	var s: = Control.new()
	s.set_script(PLAY2)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cr: Rect2 = main.CR if ("CR" in main) else Rect2(Vector2.ZERO, vs)
	s.position = cr.position
	s.size = cr.size
	s.set_meta("v8_args", margs.duplicate(true))
	main.screen_root.add_child(s)
	main.screen = s
	main.screen_id = "play"
	s.call("build", main, margs)
	return s


static func _to_mode_result(res: Dictionary) -> Dictionary:
	var win: = bool(res.get("win", false))
	var me_n: = int(res.get("me", 0))
	var her_n: = int(res.get("her", 0))
	return {
		"mode": "duel",
		"win": win,
		"score": me_n,
		"stars": 3 if (win and me_n >= her_n + 4) else (2 if win else (1 if bool(res.get("draw", false)) else 0)),
		"time_s": 0.0,
		"pairs": me_n,
		"hero": String(res.get("rival", "rin")),
		"seed": int(res.get("seed", 0)),
		"level": int(res.get("form", 3)),
		"rewards": (res.get("rewards", {}) as Dictionary).duplicate(true),
	}


func open_challenge() -> void:
	challenge_opened.emit()
	if main and is_instance_valid(main):
		CH_U.go_challenge(main, {"back": "duels"})


func open_pvp() -> void:
	if main == null or not is_instance_valid(main):
		return
	var scr_map = main.get("SCREENS")
	if scr_map is Dictionary and (scr_map as Dictionary).has("v10pvp"):
		main.call("go", "v10pvp", {})
	elif main.has_method("toast"):
		main.call("toast", PVP_SOON, "star")


# the parade card of `hero` from y down to the PvP entry (skipped when the column has no room left)
func _rival_show(y: float, w_col: float, hero: String, form: int, gems: int, badge: = "") -> _RivalShow:
	var h: = _floor - y
	if h < 220.0:
		return null
	var c: = _RivalShow.new()
	c.name = "RivalShowcase"
	c.position = Vector2(M, y)
	c.accent = V10DS.hero(hero).accent if V10DS.HEROES.has(hero) else V10DS.GOLD_500
	c.stars = clampi(form, 1, 5)
	c.gems = gems
	c.setup(hero, w_col, minf(h, 460.0))
	# her name in the display face; the form reads from the gold stars (the offer card above names it) — the screen
	# keeps its 60-word budget
	var nm: = _lbl(U.hero_name(hero), "display", 32, V10DS.PAPER_100, w_col * 0.56, 1)
	nm.name = "RivalName"
	nm.position = Vector2(24.0, 18.0)
	c.add_child(nm)
	c.star_y = 18.0 + nm.size.y + 2.0
	if badge != "":
		var bl: = _lbl(badge, "ui", 18, V10DS.GOLD_300, w_col * 0.5, 1)
		bl.name = "RivalBadge"
		bl.position = Vector2(24.0, c.star_y)
		c.add_child(bl)
		c.star_y += bl.size.y + 4.0
	if gems > 0:
		var gl: = _lbl("+%d" % gems, "ui", 22, V10DS.GOLD_300, 120.0, 1)
		gl.name = "RivalReward"
		gl.position = Vector2(54.0, c.size.y - 34.0 - gl.size.y * 0.5)
		c.add_child(gl)
	page.add_child(c)
	return c


func open_help() -> V10BottomSheet:
	var sh: = V10BottomSheet.open(_sheet_host(), TITLE_DUELS)
	sh.name = "DuelHelpSheet"
	var y: = 0.0
	for r in INFO.HOW:
		var rl: = _lbl(String(r), "ui", 22, V10DS.PAPER_100, 656.0, 2)
		sh.add_body(rl, y)
		y += 68.0
	var b: = V10Button.make("play", BTN_GOT_IT, Vector2(560, 104))
	b.name = "BtnHelpOk"
	b.set_meta("ux_role", "primary")
	b.pressed.connect(sh.close)
	sh.add_body(b, y + 12.0, true)
	sh.finish(y + 124.0)
	active_sheet = sh
	return sh


func _open_season_sheet(sr: Dictionary) -> void:
	var sh: = V10BottomSheet.open(_sheet_host(), "Сезон %d завершён" % int(sr.get("num", 1)))
	sh.name = "DuelSeasonSheet"
	var y: = 0.0
	var t_lbl: = _lbl("Высшая ступень: %s" % String(sr.get("tier_name", "")), "ui", 22, V10DS.GOLD_300, 656.0, 1)
	sh.add_body(t_lbl, y)
	y += 44.0
	for r in sr.get("rows", []):
		var rl: = _lbl(String((r as Dictionary).get("text", "")), "ui", 22, V10DS.PAPER_100, 656.0, 1)
		sh.add_body(rl, y)
		y += 38.0
	var b: = V10Button.make("play", BTN_GOT_IT, Vector2(560, 104))
	b.name = "BtnSeasonOk"
	b.set_meta("ux_role", "primary")
	b.pressed.connect(sh.close)
	sh.add_body(b, y + 16.0, true)
	sh.finish(y + 128.0)
	active_sheet = sh


func _on_back() -> void:
	if main and main.has_method("back"):
		main.call("back")
	elif main and main.has_method("go"):
		main.call("go", String(args.get("back", "home")))


# ================================================================== painted inner controls (V10DS only)

class _LocalHost:
	extends Control
	var overlay: Control
	var safe_bottom: = 0.0

	func _init() -> void:
		overlay = Control.new()
		overlay.name = "LocalOverlay"
		overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(overlay)


class _DuelBg:
	extends Control
	# 0.12: the imperial arena — the painted duel hall (Higgsfield art, picked up by path) or the palace / shrine
	# backdrop, under a warm candle vignette that keeps the plates readable
	const ARENA: = "res://assets/v10/hf_ui/duel_arena_bg.webp"
	const FALLBACKS: = ["res://assets/bg/bg_palace.webp", "res://assets/bg/bg_shrine.webp"]
	var tex: Texture2D = null

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		for p in [ARENA] + FALLBACKS:
			if ResourceLoader.exists(String(p)):
				tex = load(String(p)) as Texture2D
				if tex != null:
					break

	func _draw() -> void:
		var a: = V10DS.NIGHT_800
		var b: = V10DS.NIGHT_900
		draw_polygon(
			PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]),
			PackedColorArray([a, a, b, b])
		)
		if tex != null and tex.get_width() > 0:
			var ts: = Vector2(tex.get_width(), tex.get_height())
			var s: = maxf(size.x / ts.x, size.y / ts.y)
			var ds: = ts * s
			var pos: = (size - ds) * 0.5
			var vis: = Rect2(Vector2.ZERO, size).intersection(Rect2(pos, ds))
			draw_texture_rect_region(tex, vis, Rect2((vis.position - pos) / s, vis.size / s))
		# warm vignette: dark under the header and the buttons, the arena glowing in the middle
		var top: = Color(b, 0.82)
		var mid: = Color(b, 0.34)
		var low: = Color(b, 0.9)
		var y1: = size.y * 0.42
		var y2: = size.y * 0.7
		draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), Vector2(size.x, y1), Vector2(0, y1)]), PackedColorArray([top, top, mid, mid]))
		draw_polygon(PackedVector2Array([Vector2(0, y1), Vector2(size.x, y1), Vector2(size.x, y2), Vector2(0, y2)]), PackedColorArray([mid, mid, mid, mid]))
		draw_polygon(PackedVector2Array([Vector2(0, y2), Vector2(size.x, y2), size, Vector2(0, size.y)]), PackedColorArray([mid, mid, low, low]))
		for i in 6:
			draw_circle(Vector2(size.x * 0.5, size.y * 0.56), 140.0 + float(i) * 60.0, Color(V10DS.GOLD_500, 0.025))
		# side vignette
		var e: = Color(b, 0.55)
		var z: = Color(b, 0.0)
		draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(90, 0), Vector2(90, size.y), Vector2(0, size.y)]), PackedColorArray([e, z, z, e]))
		draw_polygon(PackedVector2Array([Vector2(size.x - 90, 0), Vector2(size.x, 0), size, Vector2(size.x - 90, size.y)]), PackedColorArray([z, e, e, z]))


# 0.12: the parade card of the chosen rival in the middle of the arena: her full-colour art on the right, name, form
# stars, her «Подлость» and the win reward on the left; plum lacquer under a gold rim. Not a tap target.
class _RivalShow:
	extends Control
	var accent: = V10DS.GOLD_500
	var stars: = 3
	var stars_max: = 5
	var star_y: = 64.0
	var gems: = 0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip_contents = true

	func setup(hero: String, w: float, h: float) -> void:
		size = Vector2(w, h)
		var p: = V10W1Core.hero_png(hero)
		if not ResourceLoader.exists(p):
			p = "res://assets/hero/mc.png"
		if ResourceLoader.exists(p):
			var t: = load(p) as Texture2D
			if t != null:
				var tr: = TextureRect.new()
				tr.name = "Portrait"
				tr.texture = t
				tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
				tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
				tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
				var pw: = minf(w * 0.5, h * 0.78)
				var ph: = pw * float(t.get_height()) / maxf(1.0, float(t.get_width()))
				tr.size = Vector2(pw, ph)
				tr.position = Vector2(w - pw + 4.0, 8.0)
				tr.stretch_mode = TextureRect.STRETCH_SCALE
				add_child(tr)
				# soft fade of her art into the lacquer on the left, so the text column reads
				var fade: = TextureRect.new()
				var gt: = GradientTexture2D.new()
				gt.gradient = Gradient.new()
				gt.gradient.set_color(0, Color(V10DS.BTN_SEC_BOT, 0.98))
				gt.gradient.set_color(1, Color(V10DS.BTN_SEC_BOT, 0.0))
				gt.fill_from = Vector2(0, 0)
				gt.fill_to = Vector2(1, 0)
				fade.texture = gt
				fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
				fade.position = Vector2(w - pw - 2.0, 0)
				fade.size = Vector2(pw * 0.42, h)
				add_child(fade)
				var low: = TextureRect.new()
				var gt2: = GradientTexture2D.new()
				gt2.gradient = Gradient.new()
				gt2.gradient.set_color(0, Color(V10DS.BTN_SEC_BOT, 0.0))
				gt2.gradient.set_color(1, Color(V10DS.BTN_SEC_BOT, 0.92))
				gt2.fill_from = Vector2(0, 0)
				gt2.fill_to = Vector2(0, 1)
				low.texture = gt2
				low.mouse_filter = Control.MOUSE_FILTER_IGNORE
				low.position = Vector2(w - pw - 2.0, h - 70.0)
				low.size = Vector2(pw + 8.0, 70.0)
				add_child(low)

	func _star(c: Vector2, r: float, col: Color) -> void:
		var pts: = PackedVector2Array()
		for i in 10:
			var a: = -PI * 0.5 + float(i) * PI / 5.0
			pts.append(c + Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else r * 0.45))
		draw_colored_polygon(pts, col)

	func _draw() -> void:
		var r: = Rect2(Vector2.ZERO, size)
		V10Plate.draw_surface(self, r, false, false, true, false, false, -1.0, Color(V10DS.BTN_SEC_TOP, 0.94))
		# her accent: a slim lacquer stripe on the left edge
		draw_rect(Rect2(0, 18.0, 5.0, size.y - 36.0), accent)
		for i in stars_max:
			var on: = i < stars
			_star(Vector2(34.0 + float(i) * 30.0, star_y + 14.0), 11.0, V10DS.GOLD_300 if on else Color(V10DS.PAPER_500, 0.35))
		if gems > 0:
			var gc: = Vector2(34.0, size.y - 34.0)
			draw_colored_polygon(PackedVector2Array([gc + Vector2(0, -12), gc + Vector2(11, -3), gc + Vector2(0, 13), gc + Vector2(-11, -3)]), V10DS.JADE_300)
			draw_colored_polygon(PackedVector2Array([gc + Vector2(0, -12), gc + Vector2(11, -3), gc + Vector2(0, -1), gc + Vector2(-11, -3)]), Color(V10DS.PAPER_100, 0.55))
		# champagne studs
		for p in [Vector2(12, 12), Vector2(size.x - 12, 12), Vector2(12, size.y - 12), Vector2(size.x - 12, size.y - 12)]:
			var pv: Vector2 = p
			draw_colored_polygon(PackedVector2Array([pv + Vector2(0, -4), pv + Vector2(4, 0), pv + Vector2(0, 4), pv + Vector2(-4, 0)]), V10DS.PLATE_SPARK)


# 0.12: «Онлайн PvP · Живые игроки ›» — a gold lacquer entry plate (like the Дуэль недели card it is a tap, not one
# of the screen's role buttons)
class _PvpEntry:
	extends V10Button

	func _draw() -> void:
		var r: = Rect2(Vector2.ZERO, size)
		V10Button.lacquer(self, r, JButton.Lacquer.safe_rad(24.0, size), V10DS.PLATE_SPARK if not _down else V10DS.GOLD_300,
			V10DS.GOLD_500, V10DS.GOLD_700, 0.9 if _down else 1.0, V10DS.PAPER_100, 0.25 if _down else 0.45)
		var yc: = size.y * 0.5
		for x in [22.0, size.x - 22.0]:
			var c: = Vector2(float(x), yc)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -7), c + Vector2(5.5, 0), c + Vector2(0, 7), c + Vector2(-5.5, 0)]), V10DS.PAPER_100)
		# a live dot: the arena is open to real players
		draw_circle(Vector2(46.0, yc), 6.0, V10DS.JADE_500, true, -1.0, true)
		draw_arc(Vector2(46.0, yc), 6.0, 0.0, TAU, 16, V10DS.NIGHT_900, 1.5, true)


class _DuelSeg:
	extends Control
	var labels: Array = []
	var active: = 0
	var _cb: = Callable()
	var _lbl_nodes: Array = []

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		set_meta("ux_tap", true)

	func setup_tabs(ls: Array, idx: int, cb: Callable) -> void:
		labels = ls.duplicate()
		active = idx
		_cb = cb
		for c in get_children():
			c.queue_free()
		_lbl_nodes.clear()
		var n: = maxi(1, labels.size())
		var seg_w: = size.x / float(n)
		for i in labels.size():
			var l: = V10Type.label(String(labels[i]), "ui", 22, V10DS.NIGHT_900 if i == active else V10DS.PAPER_300)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			l.position = Vector2(float(i) * seg_w, 0.0)
			l.size = Vector2(seg_w, size.y)
			add_child(l)
			_lbl_nodes.append(l)
		queue_redraw()

	func _gui_input(e: InputEvent) -> void:
		if (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and e.pressed):
			if labels.is_empty():
				return
			var idx: = clampi(int(floor(e.position.x / maxf(1.0, size.x / float(labels.size())))), 0, labels.size() - 1)
			V9Feel.press(self, "tick", "tap")
			accept_event()
			if _cb.is_valid():
				_cb.call(idx)

	func _draw() -> void:
		V10Plate.draw_surface(self, Rect2(Vector2.ZERO, size), false, false, false, false, false, -1.0, Color(V10DS.NIGHT_800, 0.92))
		if labels.is_empty():
			return
		var seg_w: = size.x / float(labels.size())
		var pill: = Rect2(float(active) * seg_w + 6.0, 8.0, seg_w - 12.0, size.y - 16.0)
		draw_rect(pill, V10DS.GOLD_300)


class _ChoiceBar:
	extends Control
	var items: Array = []
	var active: = 0
	var _cb: = Callable()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		set_meta("ux_tap", true)

	func setup_choices(ls: Array, idx: int, cb: Callable) -> void:
		items = ls.duplicate()
		active = idx
		_cb = cb
		for c in get_children():
			c.queue_free()
		var n: = maxi(1, items.size())
		var cw: = size.x / float(n)
		for i in items.size():
			var l: = V10Type.label(String(items[i]), "ui", 18, V10DS.GOLD_300 if i == active else V10DS.PAPER_300)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			l.position = Vector2(float(i) * cw + 2.0, 0.0)
			l.size = Vector2(cw - 4.0, size.y)
			add_child(l)
		queue_redraw()

	func _gui_input(e: InputEvent) -> void:
		if (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and e.pressed):
			if items.is_empty():
				return
			var idx: = clampi(int(floor(e.position.x / maxf(1.0, size.x / float(items.size())))), 0, items.size() - 1)
			V9Feel.press(self, "tick", "tap")
			accept_event()
			if _cb.is_valid():
				_cb.call(idx)

	func _draw() -> void:
		V10Plate.draw_surface(self, Rect2(Vector2.ZERO, size), false, false, false, false, false, -1.0, Color(V10DS.NIGHT_800, 0.88))
		if items.is_empty():
			return
		var cw: = size.x / float(items.size())
		draw_rect(Rect2(float(active) * cw + 10.0, size.y - 6.0, cw - 20.0, 3.0), V10DS.GOLD_500)


class _DuelCard:
	extends Control
	var selected: = false
	var accent: = Color(0, 0, 0, 0)
	var _cb: = Callable()
	var _down: = false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func enable_tap(cb: Callable) -> void:
		_cb = cb
		mouse_filter = Control.MOUSE_FILTER_STOP
		set_meta("ux_tap", true)

	func _gui_input(e: InputEvent) -> void:
		if not _cb.is_valid():
			return
		if (e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT) or e is InputEventScreenTouch:
			if e.pressed:
				_down = true
				queue_redraw()
			elif _down:
				_down = false
				queue_redraw()
				if Rect2(Vector2.ZERO, size).has_point(e.position):
					V9Feel.press(self, "tick", "tap")
					_cb.call()
					accept_event()

	func _draw() -> void:
		var bg_c: = Color(V10DS.NIGHT_700, 0.96) if (selected or _down) else Color(V10DS.NIGHT_800, V10DS.ON_ART_A)
		V10Plate.draw_surface(self, Rect2(Vector2.ZERO, size), false, false, false, false, false, -1.0, bg_c)
		if accent.a > 0.0:
			draw_rect(Rect2(0, 12.0, 5.0 if selected else 3.0, size.y - 24.0), accent)
		if selected:
			draw_rect(Rect2(8.0, size.y - 3.0, size.x - 16.0, 2.0), V10DS.GOLD_500)