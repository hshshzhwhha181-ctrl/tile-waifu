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
	V9Letters.install()
	var new_letters: = V9Letters.tick()
	Common.backdrop(self, "menu", size, 0.0, 1.0, Color.WHITE, Vector2(0.5, 0.5))
	# 0.9 video pilot: Маджонг-тян's lobby loop (her room and her in one clip) instead of the room art + rig
	if V9HomeLive.video_wanted(str(G.S.partner)):
		video = V9HomeLive.build_video(self, size)
	if video == null:
		Common.rays(self, Vector2(W * 0.52, H * 0.34), 1000, Color(1, 0.93, 0.8, 0.45), 10, 0.03, 0.35)
	Fx.ambient(self, "petals", size)

	var floor_y: = H - 120.0
	var ped: = Sprite2D.new()
	ped.texture = G.fx("glow")
	ped.material = Fx.add_mat()
	ped.position = Vector2(W * 0.52, floor_y - 10)
	ped.scale = Vector2(6.0, 1.1)
	ped.modulate = Color(1, 0.85, 0.9, 0.5)
	ped.visible = video == null
	add_child(ped)
	hero = Hero.new().setup(G.S.partner, H * 0.64)
	hero.position = Vector2(W * 0.52, floor_y)
	add_child(hero)
	# 0.9: every tap on her (and on the room) goes through V9HomeLive, not the rig's own tap
	hero.interactive = false
	UI.slide_in(hero, Vector2(0, 60), 0.05, 0.6)
	# 0.8: her legs fade out under the button cluster (no shoes peeking between the plate and the CTA). 0.9: the fade
	# starts at the top of the cluster (Режимы, y ≈ 900), not right under the hem — her legs stay skin and colour
	var oid: = G.equipped(G.S.partner)
	var live_opts: = {"hero": hero}
	var live_mode: = "rig"
	if video != null:
		hero.visible = false
		live_mode = "video"
		live_opts["video"] = video
	elif oid != "":

		# the outfit art is a full-height painting with the face near its top (y ≈ 0.11…0.19): drawn edge to edge it
		# sits under the top bar and the greeting bubble. Push it down so her face lands where the rigged hero's face
		# is (the bubble is placed from that head), centre the face horizontally, and fade the art's top edge in.
		var otex: = G.art_tex(G.ITEM[oid])
		var okey: = otex.resource_path.get_file().get_basename()
		var ofc: Array = V8Population.FACES.get(okey, [0.5, 0.17, 4.6])
		# 0.10 M0: on tablets the painting bleeds past the column to the viewport edges (cover, aspect kept)
		var abr: = V10Layout.bleed_rect(self)
		var aw: = maxf(W, abr.size.x)
		var ax: = minf(0.0, abr.position.x)
		var osc: = maxf(aw / float(otex.get_width()), H / float(otex.get_height()))
		var rig: Dictionary = Hero.RIGS.get(G.S.partner, Hero.RIGS.mc)
		var face_y: float = floor_y - (rig.feet.y - V8Art.rig_face(G.S.partner).y) * (H * 0.64 / 1160.0) - 10.0
		var dy: = clampf(face_y - float(ofc[1]) * otex.get_height() * osc, 0.0, 280.0)
		var art: = Common.living_art(self, otex, Rect2(ax, dy, aw, H), Vector2(float(ofc[0]), 0.4), 110.0 if dy > 0.0 else 0.0)
		move_child(art, 1)
		var shade: = Common.vignette(self, size, Color(0.1, 0.03, 0.15), 0.45)
		move_child(shade, 2)
		hero.visible = false
		live_mode = "art"
		live_opts.merge({"art": art, "tex_size": Vector2(otex.get_width(), otex.get_height()), "focus": Vector2(float(ofc[0]), 0.4),
			"face_rect": _face_rect(oid, otex, ofc), "art_key": okey})
	live = V9HomeLive.make(self, live_mode, live_opts)
	# 0.10 W1 (UX §3.3, HUD_V2 §8.2): the v2 tea house — avatar + nick, Телефон, the lanterns, the partner plate and
	# ONE «Играть · N». The 0.9 left column, the league / event / offer cards, «Режимы», «Сесть за стол», the currencies
	# and the affection plate with «ещё N сегодня» are gone (their rows live in «Сегодня» and on «Столы»).
	_build_v10(new_letters.size() > 0 or V9Letters.badge_count() > 0)
	V10Hooks.emit_home_built(self)  # 0.10 hook: V10EntryQueue.run() (one full-screen scene per launch)
	if not new_letters.is_empty():
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
		home2.phone_dot = V9Letters.badge_count() > 0
		home2.lit = [V10Nav.today_open(), false, false]
		home2.deco.queue_redraw()

# «Письма» (0.9): the letters screen — heroines' letters with replies, plus the 0.7/0.8 date notes and scene notices.
func open_mail() -> void :
	main.go("letters")

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


# ── 0.10 W1: V10HudHome over the living heroine (scripts/v10/hud2/hud_home.gd, HUD_V2 §8.2) ─────────────────────
var home2: V10HudHome
var avatar_hit: Control
var v10_bubble_x = null  # V9HomeLive.say: x of the speech bubble (right of the lit lanterns)

func _build_v10(mail_new: bool) -> void :
	var pi: = V10Nav.path_info()
	# a night.900 scrim behind the status row (avatar, nick, Телефон): paper text stays ≥ 4.5:1 on a bright room
	var scrim: = TextureRect.new()
	var gt: = GradientTexture2D.new()
	gt.gradient = Gradient.new()
	gt.gradient.set_color(0, Color(V10DS.NIGHT_900, 0.72))
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
	home2 = V10HudHome.new()
	home2.configure({"hero": str(G.S.partner), "nick": G.nick(), "level": pi.code, "path": pi.loc,
		"affinity": G.aff_level(str(G.S.partner)),
		"own_figure": true, "own_backdrop": true, "own_nav": true, "phone_dot": mail_new,
		# Сегодня from L6 (UX §3.5); Салон and Серия arrive with W2
		"shown": [V10Nav.today_lit(), false, false], "lit": [V10Nav.today_open(), false, false]})
	add_child(home2)
	var shown_n: = 1 if V10Nav.today_lit() else 0
	v10_bubble_x = 40.0 + shown_n * 112.0 + 4.0 if shown_n > 0 else null
	# its layout is in viewport px; the screen sits in the content column
	home2.set_anchors_preset(Control.PRESET_TOP_LEFT)
	home2.position = -main.CR.position
	home2.size = get_viewport_rect().size
	home2.name = "V10HudHome"
	play_btn = null
	aff_root = home2.partner
	home2.play_b.set_meta("ux_role", "primary")
	home2.partner.set_meta("ux_role", "secondary")
	home2.phone_b.set_meta("ux_role", "tertiary")
	home2.play_pressed.connect(func(): V10Nav.play_path(main))
	home2.partner_pressed.connect(func(): main.go("collection", {"hero": str(G.S.partner)}))
	home2.phone_pressed.connect(open_mail)
	home2.lantern_pressed.connect(func(i: int):
		if i == 0:
			V10Nav.today_sheet(main))
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


# V9HomeLive calls this after a touch added affection: the partner plate shows the new number
func _build_affection() -> void :
	if home2 and home2.partner:
		home2.partner.subtitle = "Симпатия · %d" % G.aff_level(str(G.S.partner))
