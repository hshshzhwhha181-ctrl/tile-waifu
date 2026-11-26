extends Control

# 0.8 home (Чайная): left column of 4 (Поручения, Визиты, Письма, Рейтинг), right column of cards
# (лига недели, ивент, баннер), «Режимы» + «Сесть за стол» bottom right, affection plate bottom left.
# 0.9 (docs/0.9-spec.md §C): she is alive — V9HomeLive (scripts/v09/home) answers taps by zone with an emotion,
# a line and affection, idles, and plays the Маджонг-тян lobby video; «Письма» opens the letters screen
# (scripts/v09/letters) and its icon carries the count of unread letters.

const COL_X: = 16.0
const COL_Y: = 140.0
const COL_STEP: = 124.0
const CARD_W: = 198.0
const CARD_TOP: = 136.0

var main
var hero: Hero
var bubble: Control
var play_btn: JButton
var modes_btn: JButton
var aff_root: Control
var side_btns: = {}
var league_card: Control
var W: = 720.0
var H: = 1280.0
var live: V9HomeLive
var video: VideoStreamPlayer
var rig10_node: V10LiveRig
var outfit_art: TextureRect
var _hero_base_pos: = Vector2.ZERO
var _hero_base_sc: = Vector2.ONE
var _rig10_base_pos: = Vector2.ZERO
var _rig10_base_sc: = 1.0
var _video_base_rect: = Rect2()
var _art_full_rect: = Rect2()
var _art_fit_rect: = Rect2()
var _art_base_focus: = Vector2(0.5, 0.4)
var _crop_editing: = false
var _crop_drag: = false
var _crop_last_pt: = Vector2.ZERO
var _crop_touches: = {}
var _crop_pinch_d: = 0.0
var _frame_pill: Panel
var _frame_lbl: Label
var _frame_bar: Control
var _crop_catcher: Control
const FRAME_NAMES: = ["Полный рост", "Ближе", "Портрет"]

func build(m, _args: Dictionary) -> void :
	main = m
	W = size.x
	H = size.y
	main.show_chrome(true, true)
	Sfx.music("menu")
	if "--letters_selftest=1" in OS.get_cmdline_user_args():
		V9LettersSelftest.run.call_deferred(main)
	for a in OS.get_cmdline_user_args():
		# dev: preview home at another effects level (--fx=full|mid|min)
		if a.begins_with("--fx=") and a.substr(5) in G.FX_LEVELS:
			G.S.fx_level = a.substr(5)
		elif a.begins_with("--framing="):
			_ensure_lobby_crop()["preset"] = clampi(int(a.substr(10)), 0, 2)
	V10HudSkin.sync(V10Look.current())
	V10Voice.visit()
	V9Letters.install()
	V10Phone.ensure()
	var rit_day: = V10Rituals.day_start()
	for rl in rit_day.get("letters", []):
		if rl is Dictionary:
			V9Letters.push_ritual(rl)
	var cb_gap: = int(rit_day.get("comeback", {}).get("gap", 0)) if rit_day.get("comeback") is Dictionary else 0
	if cb_gap >= 2:
		V10Phone.event({"kind": "comeback", "days": cb_gap})
	V10Phone.tick()
	if int(G.S.get("unlocked", 1)) >= 4:
		V10Seven.visit(G.S, V10Meta.day_key())
	_offer_ritual_scenes(rit_day)
	_offer_gacha_scenes()
	_offer_look_scenes()
	var new_letters: = V9Letters.tick()
	# Salon ruins removed from lobby backdrop per tester feedback: always show warm teahouse / heroine art
	var salon_bg: = ""
	if salon_bg != "" and ResourceLoader.exists(salon_bg):
		var sbg: = TextureRect.new()
		sbg.texture = load(salon_bg)
		sbg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sbg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		var br0: = V10Layout.bleed_rect(self)
		sbg.position = br0.position
		sbg.size = br0.size
		sbg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(sbg)
	else:
		Common.backdrop(self, "menu", size, 0.0, 1.08, Color(1.03, 1.0, 0.99), Vector2(0.5, 0.48))
	# Resolve active heroine & equipped outfit (also honouring V10Look banner try-on if active)
	var eff_partner: = str(G.S.partner)
	var oid: = G.equipped(eff_partner)
	if V10Look.previewing():
		eff_partner = str(V10Look._preview.get("hero", eff_partner))
		var pv_oid: = str(V10Look._preview.get("outfit", ""))
		oid = pv_oid if (pv_oid != "" and not (pv_oid in G.BASE_OUTFITS) and G.ITEM.has(pv_oid)) else ""
	# 0.10 W3: living illustration rig ONLY when wearing base outfit (equipped non-base outfits always render their own painting!)
	var bday_partner: = V10Bday.today_hero() == eff_partner
	var want_rig10: = not bday_partner and oid == "" and V9HomeLive.rig10_wanted(eff_partner)
	var rig10: V10LiveRig = null
	if want_rig10:
		rig10 = V9HomeLive.build_rig10(self, size, false, eff_partner)
		rig10_node = rig10
		if rig10 != null:
			_rig10_base_pos = rig10.position
			_rig10_base_sc = rig10.scale.x
	elif not bday_partner and salon_bg == "" and oid == "" and V9HomeLive.video_wanted(eff_partner):
		video = V9HomeLive.build_video(self, size)
		if video != null:
			_video_base_rect = Rect2(video.position, video.size)
	if video == null:
		Common.rays(self, Vector2(W * 0.52, H * 0.28), 1100, Color(1.0, 0.94, 0.80, 0.42), 10, 0.03, 0.36)
	Fx.ambient(self, "petals", size)

	var floor_y: = H - 120.0
	var ped: = Sprite2D.new()
	ped.texture = G.fx("glow")
	ped.material = Fx.add_mat()
	ped.position = Vector2(W * 0.52, floor_y - 10)
	ped.scale = Vector2(6.0, 1.1)
	ped.modulate = Color(1, 0.85, 0.9, 0.5)
	ped.visible = video == null and rig10 == null and oid == ""
	add_child(ped)
	hero = Hero.new().setup(eff_partner, H * 0.64)
	hero.position = Vector2(W * 0.52, floor_y)
	_hero_base_pos = hero.position
	_hero_base_sc = hero.scale
	add_child(hero)
	# 0.9: every tap on her (and on the room) goes through V9HomeLive, not the rig's own tap
	hero.interactive = false
	UI.slide_in(hero, Vector2(0, 60), 0.05, 0.6)
	var live_opts: = {"hero": hero}
	var live_mode: = "rig"
	if rig10 != null:
		hero.visible = false
		live_mode = "rig10"
		live_opts["rig10"] = rig10
	elif video != null:
		hero.visible = false
		live_mode = "video"
		live_opts["video"] = video
	elif oid != "" and G.ITEM.has(oid):
		var otex: = G.art_tex(G.ITEM[oid])
		var okey: = otex.resource_path.get_file().get_basename()
		var ofc: Array = V8Population.FACES.get(okey, [0.5, 0.17, 4.6])
		var abr: = V10Layout.bleed_rect(self)
		var aw: = maxf(W, abr.size.x)
		var ax: = minf(0.0, abr.position.x)
		_art_full_rect = Rect2(ax, abr.position.y, aw, abr.size.y)
		var top_pad: = maxf(0.0, abr.position.y + 52.0)
		_art_fit_rect = Rect2(ax, top_pad, aw, maxf(H - top_pad - 116.0, H * 0.78))
		_art_base_focus = Vector2(float(ofc[0]), 0.44)
		var art: = Common.living_art(self, otex, _art_fit_rect, _art_base_focus, 40.0)
		outfit_art = art
		move_child(art, 1)
		# Light warm rose-gold edge kiss instead of heavy dark vignette so the outfit & room stay vivid
		var shade: = Common.vignette(self, size, Color(0.22, 0.08, 0.16), 0.12)
		move_child(shade, 2)
		hero.visible = false
		live_mode = "art"
		live_opts.merge({"art": art, "tex_size": Vector2(otex.get_width(), otex.get_height()), "focus": _art_base_focus,
			"face_rect": _face_rect(oid, otex, ofc), "art_key": okey})
	live = V9HomeLive.make(self, live_mode, live_opts)
	_apply_lobby_crop(false)
	if bday_partner:
		hero.visible = false
		if live:
			live.set_process(false)
			live.mouse_filter = Control.MOUSE_FILTER_IGNORE
		V10BdayCake.open(self, str(G.S.partner))
	# 0.10 W1+W2 (UX §3.3, HUD_V2 §8.2): the v2 tea house — avatar + nick, Телефон, the lanterns, the partner plate and
	# ONE «Играть · N».
	_build_v10(new_letters.size() > 0 or V10Phone.badge() > 0)
	V10Hooks.emit_home_built(self)  # 0.10 hook: V10EntryQueue.run() (one full-screen scene per launch)
	var is_shots: = false
	for ua in OS.get_cmdline_user_args():
		if ua.begins_with("--shots="):
			is_shots = true
			break
	if not is_shots and V10EntryQueue.shown_this_launch().is_empty() and _tray_allowed() and V10Tray.should_show():
		_open_morning_tray.call_deferred()
	if not new_letters.is_empty() and V10Nav.phone_open():
		_letter_arrived.call_deferred()
	await get_tree().create_timer(0.9).timeout
	if is_inside_tree():
		_say(Sfx.say(G.S.partner, "greet"))
	if G.has_meta("pending_offer") and not G.offer_shown:
		G.remove_meta("pending_offer")
		await get_tree().create_timer(1.4).timeout
		if is_inside_tree():
			main.maybe_offer()

# ---------------------------------------------------------------- left column

func _build_left() -> void :
	var mail_new: = V9Letters.badge_count()
	var items: = [
		["tasks", "tasks", V6Txt.s("home.tasks"), func(): Daily.tasks(main, self), G.tasks_ready() > 0],
		["login", "visits", V6Txt.s("home.login"), func(): Daily.login(main, self), G.login_ready()],
		["mail", "letters", V6Txt.s("home.mail"), func(): open_mail(), mail_new],
		["rating", "rating", "Рейтинг", func(): main.go("v7tourney", {"tab": "quarter"}), false],
	]
	for i in items.size():
		var it: Array = items[i]
		var b: = _side_button(it[1], it[2], Rect2(COL_X, COL_Y + i * COL_STEP, 84, 84), it[3], it[4])
		if it[0] == "rating":
			_rating_mark(b)
		side_btns[it[0]] = b
		UI.slide_in(b, Vector2(-50, 0), 0.1 + i * 0.05)

# 0.8 left-column button: the round V8Art icon (tasks / visits / letters / rating — it has its own gold-rimmed
# disc, so no drawn disc behind it), caption under it, a pulsing dot when something is ready.
# 0.9: `badge` may be a count (Письма): a number badge instead of the dot.
func _side_button(icon: String, text: String, rect: Rect2, cb: Callable, badge) -> Control:
	var c: = Control.new()
	c.position = rect.position
	c.size = rect.size
	c.pivot_offset = rect.size * 0.5
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	var art: = V8Art.rect(V8Art.icon(icon), Rect2(Vector2.ZERO, Vector2(rect.size.x, rect.size.x)))
	art.name = "Icon"
	c.add_child(art)
	c.add_child(UI.center_label(UI.label(text, 18, UI.INK, UI.DARK, 4, "body", 900), Rect2(-24, rect.size.x - 6, rect.size.x + 48, 26)))
	if badge is int and int(badge) > 0:
		var nb: = Common.badge(c, int(badge), Vector2(rect.size.x - 26, -6))
		nb.name = "Badge"
		nb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		nb.pivot_offset = Vector2(15, 15)
		var bt: Tween = nb.create_tween().set_loops()
		bt.tween_interval(1.6)
		bt.tween_property(nb, "scale", Vector2(1.18, 1.18), 0.16).set_trans(Tween.TRANS_SINE)
		bt.tween_property(nb, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	elif badge is bool and badge:
		var d: = UI.rbox("gold", Rect2(rect.size.x - 20, 2, 16, 16), 8, 1, 3)
		d.colors(Color("ffe7a6"), Color("ff8fb0"))
		c.add_child(d)
		d.pivot_offset = Vector2(8, 8)
		var t: Tween = d.create_tween().set_loops()
		t.tween_property(d, "scale", Vector2(1.2, 1.2), 0.45).set_trans(Tween.TRANS_SINE)
		t.tween_property(d, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_SINE)
	c.gui_input.connect( func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			V9Feel.press(c)
			cb.call())
	add_child(c)
	return c

# «Рейтинг» gets a small quarter-place plate on top of its icon.
func _rating_mark(b: Control) -> void :
	var q: = _league_call("my_quarter")
	# 0.8: the same rule as the victory window, profile and Режимы (V8League.quarter_shown): no «#1 001»
	var txt: = "#%s" % UI.fmt(int(q.place)) if V8League.quarter_shown(q) else "топ-100"
	var fw: float = UI.font("body", 900).get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 16.0
	var pl: = UI.rbox("gold", Rect2(84 - fw + 14, -8, fw, 24), 12, 2, 3)
	pl.colors(Color("fae4a6"), Color("c38f3c"))
	pl.set_param("shadow_color", Color(0, 0, 0, 0.3))
	b.add_child(pl)
	pl.add_child(UI.center_label(UI.label(txt, 16, Color("3a2410"), Color(1, 1, 1, 0.4), 1, "body", 900), Rect2(0, 0, fw, 24)))

func refresh_badges() -> void :
	if home2:
		var pb: = V10Phone.badge()
		home2.phone_shown = V10Nav.phone_open()
		home2.phone_count = pb
		home2.phone_dot = pb > 0
		home2.shown = [V10Nav.today_lit(), V10Nav.salon_open(), V10Nav.streak_shown()]
		home2.lit = [V10Nav.today_open(), V10Nav.salon_lit(), V10Nav.streak_lit()]
		home2.layout_now()

# 0.10 W2: Телефон overlay (лента · чаты · почта), gated after L5 (UX §3.5).
func open_mail() -> void :
	if not V10Nav.phone_open():
		main.toast(V10Nav.T_LOCK % (V10Nav.PHONE_AT - 1), "lock")
		return
	var ph: = V10Phone.open(main, {})
	if ph:
		ph.tree_exited.connect(func():
			if is_inside_tree():
				refresh_badges())

# a letter was written while she was away: the Письма icon bows once with a little sparkle
func _letter_arrived() -> void :
	await get_tree().create_timer(1.1).timeout
	if not is_inside_tree() or home2 == null:
		return
	var b: Control = home2.phone_b
	V9Feel.success(b, "sparkle", 0.6)
	if V9Feel.can_fx():
		Fx.burst(self, b.position + b.size * 0.4, "sparkle", maxi(4, int(round(12 * V9Feel.fx_scale()))))

# the head-and-shoulders square of the equipped outfit painting (V9Ults rects, scaled to this texture); an outfit
# without an ult entry falls back to the 0.8 face crop (V8Population.FACES)
static func _face_rect(oid: String, tex: Texture2D, ofc: Array) -> Rect2:
	var ts: = Vector2(tex.get_width(), tex.get_height())
	var key: = tex.resource_path.get_file().get_basename()
	if V9Ults.has(oid):
		var sh: = V9Ults.shown(oid)
		if str(sh.img).get_file().get_basename() == key:
			var r: = V9Ults.rect_px(sh.face_rect, ts)
			# a square that sits low (rin_maid: the face is at its top, not at ~45 %) is pulled halfway to the 0.8
			# face crop point when the two disagree by more than a fifth of the square
			if V8Population.FACES.has(key):
				var fy: float = float(V8Population.FACES[key][1]) * ts.y
				var hy: = r.position.y + r.size.y * 0.42
				if absf(fy - hy) > r.size.x * 0.2:
					r.position.y += (fy - hy) * 0.5
			return r
	var side: = ts.x * 0.3
	var c: = Vector2(float(ofc[0]) * ts.x, float(ofc[1]) * ts.y)
	return Rect2(c - Vector2(side * 0.5, side * 0.42), Vector2(side, side))

# ---------------------------------------------------------------- right column

static func _league_call(fn: String) -> Dictionary:
	return V6ModesData.league(fn)

func _build_right() -> void :
	var x: = W - CARD_W - 16.0
	var y: = CARD_TOP
	league_card = _league_card(Rect2(x, y, CARD_W, 176))
	UI.slide_in(league_card, Vector2(60, 0), 0.2)
	y += 176 + 12
	# 0.8: the column holds two cards at most — the event and the summon banner share the second slot and take
	# turns, so nothing ever covers her raised hand with the 中 tile (y ≈ 485-520 under the column)
	var slot2: Array[Control] = []
	if V7Event.is_open():
		var def: = V7EventData.cur_def()
		var ev: = V7EventData.st()
		var c1: = _banner_card(Rect2(x, y, CARD_W, 156), V7Event.art(def), "ИВЕНТ", def.name, "ещё " + V7EventData.left_text(V7EventData.left_secs()), "rose", Vector2(0.5, 0.2))
		c1.add_child(UI.tex(V7Event.cur_icon(def), Rect2(CARD_W - 48, 4, 44, 44)))
		if ev.daily != V7EventData.today_key():
			var x2: = UI.rbox("red", Rect2(CARD_W - 66, 44, 64, 26), 13, 2, 4)
			c1.add_child(x2)
			x2.add_child(UI.center_label(UI.label("×2", 16, Color.WHITE, Color("6a1020"), 2, "body", 900), Rect2(0, 0, 64, 26)))
		c1.gui_input.connect( func(e):
			if e is InputEventMouseButton and e.pressed:
				V9Feel.press(c1)
				main.go("v7event"))
		UI.slide_in(c1, Vector2(60, 0), 0.28)
		slot2.append(c1)
	if G.summon_open():
		var nb: Control
		if int(G.S.newbie_left) > 0:
			nb = _banner_card(Rect2(x, y, CARD_W, 168), G.art_tex(G.ITEM["o_dragon"]), "−20%", V6Txt.s("home.newbie"), V6Txt.s("home.newbie_sub"), "gold", Vector2(0.5, 0.22))
			nb.gui_input.connect( func(e):
				if e is InputEventMouseButton and e.pressed:
					UI.tap(nb, 0.06)
					main.go("summon", {"banner": 0}))
			if G.S.free10:
				Common.badge(nb, 0, Vector2(CARD_W - 22, -10))
		else:
			nb = _banner_card(Rect2(x, y, CARD_W, 168), G.art_tex(G.ITEM["n_ssr"]), "БАННЕР", V6Txt.s("home.event_name"), V6Txt.s("home.event_left"), "lav", Vector2(0.5, 0.25))
			nb.gui_input.connect( func(e):
				if e is InputEventMouseButton and e.pressed:
					V9Feel.press(nb)
					main.go("summon", {"banner": 2}))
		UI.slide_in(nb, Vector2(60, 0), 0.34)
		slot2.append(nb)
	_rotate_slot(slot2)
	G.save()
	V7Event.show_pending(self, main)

# the second right-column slot: one card shows, the others wait hidden; with two or more they cross-fade every
# 5 s (a hidden card takes no taps) and two small dots under the slot say there is more than one
func _rotate_slot(cards: Array[Control]) -> void :
	if cards.size() < 2:
		return
	for i in range(1, cards.size()):
		cards[i].visible = false
	var bottom: = 0.0
	for c in cards:
		bottom = maxf(bottom, c.position.y + c.size.y)
	var dots: Array[Control] = []
	var dx0: = cards[0].position.x + CARD_W * 0.5 - (cards.size() * 16.0 - 6.0) * 0.5
	for i in cards.size():
		var d: = UI.rbox("gold", Rect2(dx0 + i * 16.0, bottom + 6.0, 10, 10), 5, 1, 2)
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		d.modulate.a = 1.0 if i == 0 else 0.4
		add_child(d)
		dots.append(d)
	var at: = [0]
	var t: = create_tween().set_loops()
	t.tween_interval(5.0)
	t.tween_callback( func():
		var a: Control = cards[at[0]]
		at[0] = (at[0] + 1) % cards.size()
		var b: Control = cards[at[0]]
		if not is_instance_valid(a) or not is_instance_valid(b):
			return
		b.modulate.a = 0.0
		b.visible = true
		var ft: = a.create_tween()
		ft.tween_property(a, "modulate:a", 0.0, 0.3)
		ft.tween_callback(a.hide)
		ft.tween_property(a, "modulate:a", 1.0, 0.0)
		b.create_tween().tween_property(b, "modulate:a", 1.0, 0.3)
		for i in dots.size():
			dots[i].modulate.a = 1.0 if i == at[0] else 0.4)

func _league_card(r: Rect2) -> Control:
	var w: = _league_call("my_week")
	var c: = Control.new()
	c.position = r.position
	c.size = r.size
	c.pivot_offset = r.size * 0.5
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(c)
	c.add_child(UI.rbox("gold", Rect2(Vector2.ZERO, r.size), 22, 4, 12))
	var art: = Common.card_art(load("res://assets/v07/event/cg_finale_card.webp"), Rect2(6, 6, r.size.x - 12, r.size.y - 12), Vector2(0.5, 0.3), 1.0, 18)
	var am: ShaderMaterial = art.material
	am.set_shader_parameter("bottom_shade", 0.95)
	c.add_child(art)
	var dim: = ColorRect.new()
	dim.color = Color(0.06, 0.04, 0.07, 0.45)
	dim.position = Vector2(6, 6)
	dim.size = r.size - Vector2(12, 12)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(dim)
	var tag: = UI.rbox("pink", Rect2(-8, 10, 150, 32), 12, 3, 8)
	c.add_child(tag)
	tag.add_child(UI.center_label(UI.label("ЛИГА НЕДЕЛИ", 16, Color.WHITE, Color("7a2346"), 4, "body", 900), Rect2(0, 0, 150, 32)))
	var tier: = clampi(int(w.get("league_tier", G.rank_of(int(G.S.rp)).tier)), 0, G.RANKS.size() - 1)
	# weekly league crest (league/*), not the rank medallion
	Common.league_emblem(c, Rect2(8, 46, 76, 76), tier)
	var place: = int(w.get("place", 0))
	var gs: = int(w.get("group_size", 20))
	var pl: = UI.title("#%d" % place if place > 0 else "—", 40, Color("fff6ea"), UI.DARK)
	pl.position = Vector2(86, 48)
	pl.size = Vector2(104, 50)
	pl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	c.add_child(pl)
	var of: = UI.label("из %d" % gs, 17, Color("ffe7a6"), UI.DARK, 3, "body", 900)
	of.position = Vector2(88, 96)
	of.size = Vector2(104, 22)
	c.add_child(of)
	var lname: = str(w.get("league_name", G.RANKS[tier].name))
	var ln: = UI.label(lname, 19, Color(G.RANKS[tier].color).lerp(Color.WHITE, 0.35), UI.DARK, 4, "body", 900)
	ln.position = Vector2(14, r.size.y - 52)
	ln.size = Vector2(r.size.x - 28, 24)
	ln.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	c.add_child(ln)
	var pts: = int(w.get("points", 0))
	var pt: = UI.label(("%s очков недели" % UI.fmt(pts)) if pts > 0 else "Сыграй стол турнира", 16, Color("fff3c4"), UI.DARK, 3, "body", 900)
	pt.position = Vector2(14, r.size.y - 30)
	pt.size = Vector2(r.size.x - 28, 22)
	pt.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	c.add_child(pt)
	c.gui_input.connect( func(e):
		if e is InputEventMouseButton and e.pressed:
			V9Feel.press(c)
			main.go("v7tourney", {"tab": "week"}))
	return c

func _banner_card(r: Rect2, tex: Texture2D, tag_text: String, name_text: String, sub_text: String, pal: String, focus: Vector2) -> Control:
	var ev: = Control.new()
	ev.position = r.position
	ev.size = r.size
	ev.mouse_filter = Control.MOUSE_FILTER_STOP
	ev.pivot_offset = ev.size * 0.5
	add_child(ev)
	ev.add_child(UI.rbox(pal, Rect2(Vector2.ZERO, ev.size), 22, 4, 12))
	var art: = Common.card_art(tex, Rect2(6, 6, ev.size.x - 12, ev.size.y - 12), focus, 1.0, 18)
	(art.material as ShaderMaterial).set_shader_parameter("bottom_shade", 0.9)
	ev.add_child(art)
	var tw: float = maxf(96.0, UI.font("body", 900).get_string_size(tag_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x + 28.0)
	var tag: = UI.rbox("pink" if pal != "gold" else "red", Rect2(-8, 10, tw, 32), 12, 3, 8)
	ev.add_child(tag)
	tag.add_child(UI.center_label(UI.label(tag_text, 17, Color.WHITE, Color("7a2346"), 4, "body", 900), Rect2(0, 0, tw, 32)))
	var fs: = 22
	while fs > 17 and UI.font("body", 900).get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > ev.size.x - 24:
		fs -= 1
	var t: = UI.label(name_text, fs, Color.WHITE, Color("3f2a7a"), 6, "body", 900)
	t.position = Vector2(12, ev.size.y - 66)
	t.size = Vector2(ev.size.x - 20, 30)
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	ev.add_child(t)
	var s: = UI.label(sub_text, 16, Color("fff3c4"), Color("3f2a7a"), 4, "body", 900)
	s.position = Vector2(14, ev.size.y - 36)
	s.size = Vector2(ev.size.x - 22, 24)
	s.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	ev.add_child(s)
	return ev

func _say(text: String) -> void :
	if live and is_instance_valid(live):
		live.say(text, "", "", false)
		return
	if bubble:
		bubble.queue_free()
	var head: = V10Layout.local_of(self, hero.head_global())
	bubble = Common.bubble(self, text, Vector2(114, maxf(head.y - 250, 186.0)), 300, false)
	var b: = bubble
	var t: Tween = b.create_tween()
	t.tween_interval(3.8)
	t.tween_property(b, "modulate:a", 0.0, 0.3)
	t.tween_callback(b.queue_free)

# 0.8 (main.toast): home toasts live in the speech-bubble band between the left icon column and the right cards,
# so they never cover the league / event cards; the bubble steps aside while a toast is up
func v8_toast_rect() -> Rect2:
	# 0.10: above the action row, under her — never over her face or the lanterns
	var py: = float((home2.L.play as Rect2).position.y) - float(main.CR.position.y) if home2 and not home2.L.is_empty() else H - 330.0
	return Rect2(32.0, py - 112.0, W - 64.0, 80.0)

func v8_toast_shown(dur: float) -> void :
	if bubble and is_instance_valid(bubble):
		var b: = bubble
		bubble = null
		var t: Tween = b.create_tween()
		t.tween_property(b, "modulate:a", 0.0, 0.12)
		t.tween_callback(b.queue_free)

# a touch on her head (main.run_demo, dev «pet»): the same reaction as a real tap there
func on_hero_tap() -> void :
	if live and is_instance_valid(live):
		live.tap_zone("head")

func dev_act(a: String) -> void :
	match a:
		"login":
			Daily.login(main, self)
		"tasks":
			Daily.tasks(main, self)
		"cal":
			Daily.calendar(main)
		"settings":
			main.settings()
		"offer":
			main.maybe_offer()
		"rank":
			main.rank_ladder()
		"mail":
			open_mail()
		"back":
			main.android_back()
		"pet":
			on_hero_tap()
		"tap_head", "tap_hand", "tap_outfit", "tap_bg", "tap_body":
			live.touch = V9Touch.new()
			live.tap_zone(a.substr(4))
		"tap_at_head", "tap_at_hand", "tap_at_outfit", "tap_at_bg":
			# a real touch at the zone's point (goes through the hit test, not the forced zone)
			live.touch = V9Touch.new()
			live._tap(live.zone_point(a.substr(7)))
		"spam":
			live.touch = V9Touch.new()
			for i in V9Touch.SPAM_N:
				live._t += 0.3
				live.tap_zone("head")
		"idle_line":
			live.idle_t = V9HomeLive.IDLE_LINE
			if bubble and is_instance_valid(bubble):
				bubble.queue_free()
				bubble = null
		"zones":
			live.zones_dbg = true
		"letters":
			open_mail()
		"toast":
			main.toast("Тайник найден: Особая минута · 2 из 10", "star")
		"cameo":
			V7Eggs._cameo(self, "yue", false)
		"blink":
			hero.set_process(false)
			hero.mat.set_shader_parameter("blink", 1.0)
		"phone":
			V10Phone.open(main, {})
		"streak":
			V10StreakSheet.open(main.overlay)
		"tray":
			_open_morning_tray()
		"frame_next":
			_cycle_lobby_preset()
		"frame_full":
			_set_lobby_preset(0)
		"frame_close":
			_set_lobby_preset(1)
		"frame_portrait":
			_set_lobby_preset(2)
		"frame_edit":
			_toggle_crop_edit(not _crop_editing)


func _tray_allowed() -> bool:
	var meta = G.S.get("v10_meta", {})
	var days: = int(meta.get("days_seen", 0)) if meta is Dictionary else 0
	return int(G.S.get("unlocked", 1)) >= 4 or days >= 2


func _open_morning_tray() -> void :
	if not is_inside_tree() or main == null or main.overlay == null or main.screen_id != "home":
		return
	var tv: = V10TrayView.open(main.overlay)
	if tv:
		tv.finished.connect(func(_r):
			if is_inside_tree():
				main.refresh_currency(true)
				refresh_badges())


func _offer_ritual_scenes(rit_day: Dictionary) -> void :
	var key: = V10Meta.day_key()
	var sc = rit_day.get("scene", {})
	if sc is Dictionary and not (sc as Dictionary).is_empty():
		var tier: = str(sc.get("tier", "warm"))
		var cb_info: Dictionary = rit_day.get("comeback", {}) if rit_day.get("comeback") is Dictionary else {}
		V10EntryQueue.offer("comeback", key, func() -> void:
			if main == null or main.overlay == null:
				return
			var cs: = V10ComebackScene.play(main.overlay, tier, {
				"h": str(G.S.partner), "heroes": V10Phone.owned(), "letters": int(cb_info.get("letters", 0)),
			})
			cs.finished.connect(func(_sk: bool):
				V10EntryQueue.done("comeback", key)
				if str(cb_info.get("ladder", "")) != "" and main and main.overlay:
					var ls: = V10LadderScreen.open(main.overlay, key)
					ls.odds_requested.connect(func():
						if main.SCREENS.has("odds"):
							ls.queue_free()
							main.go("odds", {"source": "tickets"}))))
	if bool(rit_day.get("player_bday", false)):
		V10EntryQueue.offer("player_bday", key, func() -> void:
			if main == null or main.overlay == null:
				return
			var voc: = str(V10Phone.st().get("name", {}).get("voc", ""))
			var ps: = V10PlayerBdayScene.play(main.overlay, {"name_voc": voc, "rows": V10PlayerBday.claim_gift(key)})
			ps.finished.connect(func():
				V10EntryQueue.done("player_bday", key)
				if is_inside_tree():
					main.refresh_currency(true)
					refresh_badges()))


func _offer_gacha_scenes() -> void :
	if not V10Registry.wired("gacha"):
		return
	var g2: = V10WishScreen.make_gacha()
	var gs: = V10Banners.state(G.S)
	if bool(gs.get("fp_letter", false)):
		gs["fp_letter"] = false
		V9Letters.push_ritual({"id": "fp_comp", "hero": "mc", "subject": "Все три SSR уже твои",
			"body": "В твоём гардеробе уже все три первых SSR-наряда чайной! Держи 10 билетов желания в благодарность.",
			"rewards": {}})
		G.save()
	if G.summon_open() and g2.first_needed():
		V10EntryQueue.offer("banner_phase", "first_ssr", func() -> void:
			if main == null or not is_inside_tree():
				return
			V10EntryQueue.done("banner_phase", "first_ssr")
			main.go("summon"))
	if int(G.S.get("rates_ver", 2)) == 1:
		V10EntryQueue.offer("rules_note", "v2_rates", func() -> void:
			V10EntryQueue.done("rules_note", "v2_rates")
			var sl: = V10Rates.summary_lines()
			var body_t: = "В Желаниях обновились правила: %s (%s итоговый с гарантом на 60-м), Свеча желаний не сгорает." % [
				str(sl[0].rar) + " " + V10Rates.pct(float(sl[0].base)), V10Rates.pct(float(sl[0].total))]
			V9Letters.push_ritual({"id": "v2_rates_note", "hero": "mc", "subject": "Новые правила желаний",
				"body": body_t, "rewards": {}})
			G.save()
			if is_inside_tree():
				refresh_badges())


func _offer_look_scenes() -> void :
	if not V10HudSkin.skinned() or V10Look.previewing():
		return
	if not (G.S.get("v10_skins_seen") is Dictionary):
		G.S["v10_skins_seen"] = {}
	var seen_sk: Dictionary = G.S.v10_skins_seen
	var sid: = V10HudSkin.active
	if bool(seen_sk.get(sid, false)):
		return
	V10EntryQueue.offer("table_style", sid, func() -> void:
		if main == null or main.overlay == null or not is_inside_tree():
			return
		seen_sk[sid] = true
		G.save()
		V10SkinAssemble.play(main.overlay, self, sid,
			func(): V10EntryQueue.done("table_style", sid),
			func():
				V10Look.set_choice(G.S, "hud", V10Look.BASE)
				V10HudSkin.sync(V10Look.current())
				G.save()
				V10EntryQueue.done("table_style", sid)))


# ── 0.10 W1+W2: V10HudHome over the living heroine (scripts/v10/hud2/hud_home.gd, HUD_V2 §8.2) ─────────────────────
var home2: V10HudHome
var avatar_hit: Control
var v10_bubble_x = null  # V9HomeLive.say: x of the speech bubble (right of the lit lanterns)

func _build_v10(mail_new: bool) -> void :
	var pi: = V10Nav.path_info()
	var pb: = V10Phone.badge()
	# a night.900 scrim behind the status row (avatar, nick, Телефон): paper text stays ≥ 4.5:1 on a bright room
	var scrim: = TextureRect.new()
	var gt: = GradientTexture2D.new()
	gt.gradient = Gradient.new()
	gt.gradient.set_color(0, Color(V10DS.NIGHT_900, 0.38))
	gt.gradient.set_color(1, Color(V10DS.NIGHT_900, 0.0))
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	scrim.texture = gt
	var br: = V10Layout.bleed_rect(self)
	scrim.position = br.position
	scrim.size = Vector2(br.size.x, -br.position.y + 150.0)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scrim.name = "StatusScrim"
	add_child(scrim)
	var sh_arr: = [V10Nav.today_lit(), false, V10Nav.streak_shown()]
	var lit_arr: = [V10Nav.today_open(), false, V10Nav.streak_lit()]
	home2 = V10HudHome.new()
	home2.configure({"hero": str(G.S.partner), "nick": G.nick(), "level": pi.code, "path": pi.loc,
		"affinity": G.aff_level(str(G.S.partner)),
		"own_figure": true, "own_backdrop": true, "own_nav": true,
		"phone_shown": V10Nav.phone_open(), "phone_dot": mail_new, "phone_count": pb,
		"shown": sh_arr, "lit": lit_arr})
	add_child(home2)
	var rightmost: = -1
	for i in sh_arr.size():
		if bool(sh_arr[i]):
			rightmost = i
	v10_bubble_x = 40.0 + (rightmost + 1) * 112.0 + 4.0 if rightmost >= 0 else null
	# its layout is in viewport px; the screen sits in the content column
	home2.set_anchors_preset(Control.PRESET_TOP_LEFT)
	home2.position = -main.CR.position
	home2.size = get_viewport_rect().size
	home2.name = "V10HudHome"
	play_btn = null
	aff_root = home2.partner
	home2.play_b.set_meta("ux_role", "primary")
	home2.play_b.set_meta("tut_id", "home.play")
	home2.partner.set_meta("ux_role", "secondary")
	home2.partner.set_meta("tut_id", "home.hero")
	home2.phone_b.set_meta("ux_role", "tertiary")
	home2.phone_b.set_meta("tut_id", "home.phone")
	if home2.lantern_tr.size() >= 3:
		home2.lantern_tr[0].set_meta("tut_id", "home.today")
		home2.lantern_tr[1].set_meta("tut_id", "home.salon")
		home2.lantern_tr[2].set_meta("tut_id", "home.streak")
	home2.play_pressed.connect(func(): V10Nav.play_path(main))
	home2.partner_pressed.connect(func(): main.go("collection", {"hero": str(G.S.partner)}))
	home2.phone_pressed.connect(open_mail)
	home2.lantern_pressed.connect(func(i: int):
		if i == 0:
			V10Nav.today_sheet(main)
		elif i == 1:
			main.go("v10salon")
		elif i == 2:
			var ss: = V10StreakSheet.open(main.overlay)
			ss.closed.connect(func():
				if is_inside_tree():
					refresh_badges()))
	if V10Nav.salon_open() and not bool(V10Salon.st().get("hint_seen", false)):
		V10Salon.st()["hint_seen"] = true
		G.save()
		_salon_finger_hint.call_deferred()
	# streak day-roll micro-feedback (forgiven / cooled)
	for ev in V10Streak.take_events():
		if ev is Dictionary and str(ev.get("kind", "")) == "forgiven":
			var fl: = V10RitLines.pick("forgiven", str(G.S.partner), 0)
			if fl != "":
				_say.call_deferred(fl)
	# the player's own avatar in the ring + one tap area over avatar and nick → Профиль (1)
	var L: Dictionary = home2.L
	var ar: Rect2 = L.avatar
	var av_id: = str(G.profile().get("avatar", "mc"))
	if not Hero.RIGS.has(av_id):
		av_id = "mc"
	var av: TextureRect = main._avatar(av_id, Rect2(ar.position + Vector2(4, 4), ar.size - Vector2(8, 8)))
	av.mouse_filter = Control.MOUSE_FILTER_IGNORE
	home2.add_child(av)
	avatar_hit = Control.new()
	avatar_hit.name = "AvatarHit"
	avatar_hit.position = ar.position - Vector2(8, 8)
	avatar_hit.size = Vector2((L.nick as Rect2).end.x - ar.position.x + 8.0, 80.0)
	avatar_hit.mouse_filter = Control.MOUSE_FILTER_STOP
	avatar_hit.set_meta("ux_role", "tertiary")
	avatar_hit.gui_input.connect(func(e):
		if (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and e.pressed):
			V9Feel.press(av)
			main.go("profile", {"from": "home"}))
	home2.add_child(avatar_hit)
	# 1-tap Master Mute toggle in the Tea House top-right (left of Phone)
	var mute_btn: = Panel.new()
	mute_btn.name = "MuteBtn"
	var msb: = StyleBoxFlat.new()
	msb.bg_color = Color(0.11, 0.06, 0.16, 0.82)
	msb.border_color = Color(0.92, 0.78, 0.48, 0.72)
	msb.set_border_width_all(2)
	msb.set_corner_radius_all(30)
	mute_btn.add_theme_stylebox_override("panel", msb)
	var ph_r: Rect2 = L.phone
	var mx: = ph_r.position.x - 74.0 if home2.phone_shown else ph_r.position.x + 10.0
	mute_btn.position = Vector2(mx, ph_r.position.y + 10.0)
	mute_btn.size = Vector2(60, 60)
	mute_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	mute_btn.set_meta("ux_role", "tertiary")
	var mic: = V8Art.rect(V8Art.icon("sound" if main.is_audio_on() else "sound_off"), Rect2(12, 12, 36, 36))
	mic.name = "Icon"
	mic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mute_btn.add_child(mic)
	var last_mute_ms: = [0]
	mute_btn.gui_input.connect(func(e: InputEvent) -> void:
		if (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and e.pressed):
			mute_btn.accept_event()
			var now_ms: = Time.get_ticks_msec()
			if now_ms - last_mute_ms[0] < 260:
				return
			last_mute_ms[0] = now_ms
			var on: bool = main.toggle_master_mute()
			mic.texture = V8Art.icon("sound" if on else "sound_off")
			V9Feel.press(mute_btn, "tap")
			main.toast("Звук включён" if on else "Звук выключен", "sound" if on else "sound_off"))
	home2.add_child(mute_btn)
	_build_framing_ui(L, ph_r)
	var sm_disc: = V10ShopHub.model()
	if sm_disc != null and sm_disc.econ.shop.month_days_left() > 0:
		var md: = V10MonthDisc.make(sm_disc, false)
		md.position = Vector2(W - 144.0, (L.avatar as Rect2).end.y + 68.0)
		home2.add_child(md)
	if V10Look.previewing():
		home2.shown = [false, false, false]
		home2.layout_now()
		var pv_h: = str(V10Look._preview.get("hero", "mc"))
		var pv_o: = str(V10Look._preview.get("outfit", ""))
		var pb_bar: = V10PreviewBar.open(home2, pv_h, pv_o, func(): main.go("summon"), 88.0)
		pb_bar.closed.connect(func(to_b: bool):
			if not to_b and is_inside_tree():
				refresh_badges())


# V9HomeLive calls this after a touch added affection: the partner plate shows the new number
func _build_affection() -> void :
	if home2 and home2.partner:
		home2.partner.subtitle = "Симпатия · %d" % G.aff_level(str(G.S.partner))


# UX §3.5 / INTEGRATION §4 W2: one-time gentle finger pointer on the «Салон» lantern right after L2
func _salon_finger_hint() -> void :
	if not is_inside_tree() or home2 == null or home2.lantern_tr.size() < 2:
		return
	var lt: Control = home2.lantern_tr[1]
	if not lt.visible:
		return
	var fp: = TextureRect.new()
	fp.texture = G.fx("finger")
	fp.size = Vector2(56, 56)
	fp.position = lt.position + Vector2(lt.size.x * 0.45, lt.size.y * 0.72)
	fp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fp.modulate = Color(V10DS.GOLD_300, 0.92)
	fp.name = "SalonFingerHint"
	home2.add_child(fp)
	var tw: = fp.create_tween()
	for _k in 4:
		tw.tween_property(fp, "position:y", fp.position.y - 10.0, 0.38).set_trans(Tween.TRANS_SINE)
		tw.tween_property(fp, "position:y", fp.position.y, 0.38).set_trans(Tween.TRANS_SINE)
	tw.tween_property(fp, "modulate:a", 0.0, 0.3)
	tw.tween_callback(fp.queue_free)


# ── 0.11.0 Azur Lane / BD2 Heroine Framing & Pan/Zoom Controls ─────────────────────────────────────────────

func _ensure_lobby_crop() -> Dictionary:
	if not (G.S.get("lobby_crop") is Dictionary):
		G.S["lobby_crop"] = {"preset": 0, "by_hero": {}}
	var lc: Dictionary = G.S["lobby_crop"]
	if not lc.has("preset"):
		lc["preset"] = 0
	if not (lc.get("by_hero") is Dictionary):
		lc["by_hero"] = {}
	return lc


func _hero_crop(h: String = "") -> Dictionary:
	var hid: = h if h != "" else str(G.S.get("partner", "mc"))
	var by_h: Dictionary = _ensure_lobby_crop()["by_hero"]
	if not (by_h.get(hid) is Dictionary):
		by_h[hid] = {"zoom": 1.0, "pan_x": 0.0, "pan_y": 0.0}
	var c: Dictionary = by_h[hid]
	c["zoom"] = clampf(float(c.get("zoom", 1.0)), 0.85, 2.2)
	c["pan_x"] = clampf(float(c.get("pan_x", 0.0)), -0.35, 0.35)
	c["pan_y"] = clampf(float(c.get("pan_y", 0.0)), -0.35, 0.35)
	return c


func _cycle_lobby_preset() -> void:
	var lc: = _ensure_lobby_crop()
	_set_lobby_preset((int(lc.get("preset", 0)) + 1) % 3)


func _set_lobby_preset(p: int) -> void:
	var lc: = _ensure_lobby_crop()
	lc["preset"] = clampi(p, 0, 2)
	var hc: = _hero_crop()
	hc["zoom"] = 1.0
	hc["pan_x"] = 0.0
	hc["pan_y"] = 0.0
	G.save()
	_apply_lobby_crop(true)
	if _frame_lbl and is_instance_valid(_frame_lbl):
		_frame_lbl.text = FRAME_NAMES[int(lc["preset"])]
	if main:
		main.toast("Ракурс: %s" % FRAME_NAMES[int(lc["preset"])], "star")


func _apply_lobby_crop(animate: bool) -> void:
	var lc: = _ensure_lobby_crop()
	var preset: = clampi(int(lc.get("preset", 0)), 0, 2)
	var hc: = _hero_crop()
	var zm_mul: = float(hc.get("zoom", 1.0))
	var px: = float(hc.get("pan_x", 0.0))
	var py: = float(hc.get("pan_y", 0.0))
	var dur: = 0.24 if animate else 0.0
	if outfit_art and is_instance_valid(outfit_art):
		var p_zoom: float = float([1.0, 1.34, 1.82][preset]) * zm_mul
		var p_fy: float = float([_art_base_focus.y, 0.35, 0.20][preset]) - py * 0.45
		var p_fx: float = clampf(_art_base_focus.x - px * 0.45, 0.12, 0.88)
		p_fy = clampf(p_fy, 0.10, 0.88)
		var target_r: Rect2 = _art_fit_rect if (preset == 0 and absf(zm_mul - 1.0) < 0.03 and absf(py) < 0.02) else _art_full_rect
		var sm: = outfit_art.material as ShaderMaterial
		if sm:
			sm.set_shader_parameter("top_fade", 40.0 / maxf(target_r.size.y, 1.0) if target_r == _art_fit_rect else 0.0)
			if dur > 0.0:
				var tw: = outfit_art.create_tween().set_parallel()
				tw.tween_property(outfit_art, "position", target_r.position, dur).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
				tw.tween_property(outfit_art, "size", target_r.size, dur).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
				tw.tween_method(func(v: Vector2): sm.set_shader_parameter("size", v), outfit_art.size, target_r.size, dur)
				tw.tween_method(func(v: float): sm.set_shader_parameter("zoom", v), float(sm.get_shader_parameter("zoom")), p_zoom, dur)
				tw.tween_method(func(v: Vector2): sm.set_shader_parameter("focus", v), Vector2(sm.get_shader_parameter("focus")), Vector2(p_fx, p_fy), dur)
			else:
				outfit_art.position = target_r.position
				outfit_art.size = target_r.size
				sm.set_shader_parameter("size", target_r.size)
				sm.set_shader_parameter("zoom", p_zoom)
				sm.set_shader_parameter("focus", Vector2(p_fx, p_fy))
		outfit_art.pivot_offset = target_r.size * Vector2(0.5, 0.4)
		if live and is_instance_valid(live) and live.mode == "art":
			live.art_focus = Vector2(p_fx, p_fy)
			live.art_zoom = p_zoom
		return
	var rig_k: float = float([1.0, 1.30, 1.66][preset]) * zm_mul
	var rig_dy: float = float([0.0, 160.0, 390.0][preset]) + py * 420.0
	var rig_dx: float = px * 280.0
	if rig10_node and is_instance_valid(rig10_node):
		var sc10: float = _rig10_base_sc * rig_k
		var anchor_x: float = _rig10_base_pos.x + 581.0 * _rig10_base_sc
		var anchor_y: float = _rig10_base_pos.y + 340.0 * _rig10_base_sc
		var np10: = Vector2(anchor_x - 581.0 * sc10 + rig_dx, anchor_y - 340.0 * sc10 + rig_dy * 0.25)
		if dur > 0.0:
			var tw10: = rig10_node.create_tween().set_parallel()
			tw10.tween_property(rig10_node, "scale", Vector2.ONE * sc10, dur).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
			tw10.tween_property(rig10_node, "position", np10, dur).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		else:
			rig10_node.scale = Vector2.ONE * sc10
			rig10_node.position = np10
	elif video and is_instance_valid(video) and _video_base_rect.has_area():
		var vsz: Vector2 = _video_base_rect.size * rig_k
		var vc: Vector2 = _video_base_rect.position + Vector2(_video_base_rect.size.x * 0.5, _video_base_rect.size.y * 0.28)
		var vp_pos: Vector2 = vc - Vector2(vsz.x * 0.5, vsz.y * 0.28) + Vector2(rig_dx, rig_dy * 0.3)
		video.position = vp_pos
		video.size = vsz
		var st_n: = get_node_or_null("V9LobbyStill") as Control
		if st_n:
			st_n.position = vp_pos
			st_n.size = vsz
	elif hero and is_instance_valid(hero):
		var nsc: Vector2 = _hero_base_sc * rig_k
		var npos: Vector2 = _hero_base_pos + Vector2(rig_dx, (rig_k - 1.0) * H * 0.42 + py * 360.0)
		if dur > 0.0:
			var twh: = hero.create_tween().set_parallel()
			twh.tween_property(hero, "scale", nsc, dur).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
			twh.tween_property(hero, "position", npos, dur).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		else:
			hero.scale = nsc
			hero.position = npos


func _build_framing_ui(L: Dictionary, ph_r: Rect2) -> void:
	var lc: = _ensure_lobby_crop()
	var cx: float = float(L.get("cx", 0.0))
	var pill_w: = 220.0
	var pill_h: = 48.0
	var pill: = Panel.new()
	pill.name = "FramePill"
	var psb: = StyleBoxFlat.new()
	psb.bg_color = Color(0.13, 0.07, 0.18, 0.88)
	psb.border_color = Color(0.95, 0.80, 0.46, 0.90)
	psb.set_border_width_all(2)
	psb.set_corner_radius_all(24)
	psb.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	psb.shadow_size = 6
	pill.add_theme_stylebox_override("panel", psb)
	pill.position = Vector2(cx + 720.0 - pill_w - 16.0, ph_r.position.y + 82.0)
	pill.size = Vector2(pill_w, pill_h)
	pill.mouse_filter = Control.MOUSE_FILTER_STOP
	pill.set_meta("ux_role", "tertiary")
	home2.add_child(pill)
	_frame_pill = pill
	var glyph: = _FrameGlyph.new()
	glyph.position = Vector2(10, 9)
	glyph.size = Vector2(30, 30)
	pill.add_child(glyph)
	var lbl: = UI.label(FRAME_NAMES[clampi(int(lc.get("preset", 0)), 0, 2)], 17, Color("fff3d4"), Color(0.08, 0.03, 0.12, 0.95), 3, "body", 900)
	lbl.position = Vector2(42, 0)
	lbl.size = Vector2(124, pill_h)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(lbl)
	_frame_lbl = lbl
	var sep: = ColorRect.new()
	sep.color = Color(0.95, 0.80, 0.46, 0.45)
	sep.position = Vector2(pill_w - 48.0, 9.0)
	sep.size = Vector2(1.5, pill_h - 18.0)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(sep)
	var pan_lbl: = UI.center_label(UI.label("✥", 22, Color("ffe394"), Color(0.08, 0.03, 0.12), 3, "body", 900), Rect2(pill_w - 46.0, -1.0, 44.0, pill_h))
	pan_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(pan_lbl)
	pill.gui_input.connect(func(e: InputEvent) -> void:
		if (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and e.pressed):
			var lx: float = (e as InputEventMouseButton).position.x if e is InputEventMouseButton else (e as InputEventScreenTouch).position.x
			pill.accept_event()
			V9Feel.press(pill, "tap")
			if lx >= pill_w - 50.0:
				_toggle_crop_edit(not _crop_editing)
			else:
				_cycle_lobby_preset())


func _toggle_crop_edit(on: bool) -> void:
	_crop_editing = on
	_crop_drag = false
	_crop_touches.clear()
	if _frame_bar and is_instance_valid(_frame_bar):
		_frame_bar.queue_free()
		_frame_bar = null
	if _crop_catcher and is_instance_valid(_crop_catcher):
		_crop_catcher.queue_free()
		_crop_catcher = null
	if not on or home2 == null:
		G.save()
		return
	var catcher: = Control.new()
	catcher.name = "LobbyCropCatcher"
	catcher.position = Vector2.ZERO
	catcher.size = home2.size
	catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	catcher.gui_input.connect(_on_crop_input)
	home2.add_child(catcher)
	if _frame_pill and is_instance_valid(_frame_pill):
		home2.move_child(_frame_pill, home2.get_child_count() - 1)
	_crop_catcher = catcher
	var bar: = Panel.new()
	bar.name = "LobbyCropBar"
	var bsb: = StyleBoxFlat.new()
	bsb.bg_color = Color(0.11, 0.05, 0.16, 0.94)
	bsb.border_color = Color("f8df95")
	bsb.set_border_width_all(2)
	bsb.set_corner_radius_all(20)
	bar.add_theme_stylebox_override("panel", bsb)
	bar.position = _frame_pill.position + Vector2(-44.0, 56.0)
	bar.size = Vector2(264.0, 48.0)
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	home2.add_child(bar)
	_frame_bar = bar
	var acts: = [["−", func(): _step_lobby_zoom(-0.14)], ["Сброс", func(): _reset_lobby_crop()], ["+", func(): _step_lobby_zoom(0.14)], ["Готово", func(): _toggle_crop_edit(false)]]
	var bx: = 6.0
	var widths: = [46.0, 74.0, 46.0, 80.0]
	for i in acts.size():
		var bw: float = widths[i]
		var cb: Callable = acts[i][1]
		var hit: = Control.new()
		hit.position = Vector2(bx, 4.0)
		hit.size = Vector2(bw, 40.0)
		hit.mouse_filter = Control.MOUSE_FILTER_STOP
		var col: = Color("ffe6a0") if i == 3 else Color("fff6ea")
		hit.add_child(UI.center_label(UI.label(acts[i][0], 17 if bw > 50.0 else 24, col, UI.DARK, 3, "body", 900), Rect2(0, 0, bw, 40.0)))
		hit.gui_input.connect(func(e: InputEvent) -> void:
			if (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and e.pressed):
				hit.accept_event()
				V9Feel.press(hit, "tap")
				cb.call())
		bar.add_child(hit)
		bx += bw + 2.0
	if main:
		main.toast("Тяни героиню пальцем · щипок меняет масштаб", "star")


func _step_lobby_zoom(delta: float) -> void:
	var hc: = _hero_crop()
	hc["zoom"] = clampf(float(hc.get("zoom", 1.0)) + delta, 0.85, 2.2)
	_apply_lobby_crop(false)


func _reset_lobby_crop() -> void:
	var hc: = _hero_crop()
	hc["zoom"] = 1.0
	hc["pan_x"] = 0.0
	hc["pan_y"] = 0.0
	_apply_lobby_crop(true)


func _on_crop_input(e: InputEvent) -> void:
	if e is InputEventMouseButton:
		var mb: = e as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_crop_drag = mb.pressed
			_crop_last_pt = mb.position
			_crop_catcher.accept_event()
		elif mb.pressed and mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			_step_lobby_zoom(0.08 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else -0.08)
			_crop_catcher.accept_event()
	elif e is InputEventMouseMotion and _crop_drag:
		var mm: = e as InputEventMouseMotion
		var d: = mm.position - _crop_last_pt
		_crop_last_pt = mm.position
		var hc: = _hero_crop()
		hc["pan_x"] = clampf(float(hc.get("pan_x", 0.0)) + d.x / 720.0, -0.35, 0.35)
		hc["pan_y"] = clampf(float(hc.get("pan_y", 0.0)) + d.y / 1280.0, -0.35, 0.35)
		_apply_lobby_crop(false)
		_crop_catcher.accept_event()
	elif e is InputEventMagnifyGesture:
		var mg: = e as InputEventMagnifyGesture
		var hc2: = _hero_crop()
		hc2["zoom"] = clampf(float(hc2.get("zoom", 1.0)) * mg.factor, 0.85, 2.2)
		_apply_lobby_crop(false)
		_crop_catcher.accept_event()
	elif e is InputEventScreenTouch:
		var st: = e as InputEventScreenTouch
		if st.pressed:
			_crop_touches[st.index] = st.position
		else:
			_crop_touches.erase(st.index)
		if _crop_touches.size() == 2:
			var pts: = _crop_touches.values()
			_crop_pinch_d = (pts[0] as Vector2).distance_to(pts[1] as Vector2)
		_crop_catcher.accept_event()
	elif e is InputEventScreenDrag:
		var sd: = e as InputEventScreenDrag
		var prev: Vector2 = _crop_touches.get(sd.index, sd.position)
		_crop_touches[sd.index] = sd.position
		if _crop_touches.size() >= 2:
			var pts2: = _crop_touches.values()
			var nd: = (pts2[0] as Vector2).distance_to(pts2[1] as Vector2)
			if _crop_pinch_d > 8.0:
				var hc3: = _hero_crop()
				hc3["zoom"] = clampf(float(hc3.get("zoom", 1.0)) * (nd / _crop_pinch_d), 0.85, 2.2)
				_apply_lobby_crop(false)
			_crop_pinch_d = nd
		else:
			var dp: = sd.position - prev
			var hc4: = _hero_crop()
			hc4["pan_x"] = clampf(float(hc4.get("pan_x", 0.0)) + dp.x / 720.0, -0.35, 0.35)
			hc4["pan_y"] = clampf(float(hc4.get("pan_y", 0.0)) + dp.y / 1280.0, -0.35, 0.35)
			_apply_lobby_crop(false)
		_crop_catcher.accept_event()


class _FrameGlyph:
	extends Control

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var col: = Color("ffe394")
		var c: = size * 0.5
		# Four gilded viewfinder corner brackets + inner portrait dot
		var r: = 10.0
		var l: = 5.0
		for sx in [-1.0, 1.0]:
			for sy in [-1.0, 1.0]:
				var p: = c + Vector2(sx * r, sy * r)
				draw_line(p, p + Vector2(-sx * l, 0), col, 2.2, true)
				draw_line(p, p + Vector2(0, -sy * l), col, 2.2, true)
		draw_arc(c, 4.2, 0, TAU, 24, col, 1.8, true)
