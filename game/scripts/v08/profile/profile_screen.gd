extends Control

# Screen "profile" (main.SCREENS): avatar + nick, rank, league/quarter, stats per mode,
# rank ladder (moved here from main.rank_ladder), recovery code, settings.
# args: {from: <screen id to go back to>}
# dev_act: "down" / "ladder" / "bottom" scroll, "code" show code, "enter" code entry, "nick", "avatar".

var main
var W: = 720.0
var H: = 1280.0
var back_to: = "home"
var scroll: ScrollContainer
var list: VBoxContainer
var cw: = 672.0
var ladder_c: Control


func build(m, args: Dictionary) -> void :
	main = m
	W = size.x
	H = size.y
	main.show_chrome(true, true)
	Sfx.music("menu")
	var f: = str(args.get("from", "home"))
	back_to = f if f in main.SCREENS and not f in ["profile", "play", "arena", "v7play"] else "home"
	# 0.8 art: the profile room (bg/profile.webp), dimmed so the gold-rimmed sections read on top
	V8ProfileUI.backdrop(self, "profile", size, 1.2, 0.62, Color(1, 0.96, 0.96), Vector2(0.5, 0.4))
	Common.vignette(self, size, Color(0.06, 0.04, 0.08), 0.6)
	V8Header.make(self, main, V8ProfileUI.s("profile.title"), main.back)
	var top: = V8Header.CONTENT_Y + 6
	var bottom: = H - 112.0
	cw = W - 48
	scroll = ScrollContainer.new()
	scroll.position = Vector2(24, top)
	scroll.size = Vector2(cw, bottom - top)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	add_child(scroll)
	list = VBoxContainer.new()
	list.custom_minimum_size = Vector2(cw, 0)
	list.add_theme_constant_override("separation", 14)
	scroll.add_child(list)
	Common.scroll_fade(scroll, list, 90.0, 0.6)
	# 0.8: the edges where the list runs under the header and into the nav bar are solid for one text line, then
	# soft: a tall section scrolled half out never shows a cut line of text. A 24 px lead spacer (and the 60 px
	# tail pad) keep the sections clear of the solid parts at rest and at the end of the scroll.
	Common.edge_shade(self, Rect2(0, top - 6, W, 62), 1, Color(0.07, 0.05, 0.07), 0.97, 0.45)
	Common.edge_shade(self, Rect2(0, bottom - 72, W, 72), -1, Color(0.07, 0.05, 0.07), 0.97, 0.4)
	var lead: = Control.new()
	lead.custom_minimum_size = Vector2(cw, 10)
	lead.mouse_filter = Control.MOUSE_FILTER_IGNORE
	list.add_child(lead)
	_identity()
	_rank()
	_league()
	_stats()
	_ladder()
	_code()
	_settings()
	var pad: = Control.new()
	pad.custom_minimum_size = Vector2(cw, 60)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	list.add_child(pad)
	var i: = 0
	for c in list.get_children():
		if i < 4 and not args.has("scroll"):
			c.modulate.a = 0.0
			c.create_tween().tween_property(c, "modulate:a", 1.0, 0.25).set_delay(0.05 * i)
		i += 1
	if args.has("scroll"):
		await get_tree().process_frame
		await get_tree().process_frame
		if is_instance_valid(scroll):
			scroll.scroll_vertical = int(args.scroll)


func _section(h: float, pal: = "glass") -> Control:
	var c: = Control.new()
	c.custom_minimum_size = Vector2(cw, h)
	c.size = Vector2(cw, h)
	c.mouse_filter = Control.MOUSE_FILTER_PASS
	list.add_child(c)
	if pal != "":
		var b: = UI.rbox(pal, Rect2(0, 0, cw, h), 28, 3, 10)
		b.set_param("border_top", Color(0.95, 0.85, 0.6, 0.5)).set_param("border_bottom", Color(0.45, 0.32, 0.16, 0.55))
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.add_child(b)
	return c


func _head(parent: Control, text: String, y: = 16.0) -> Label:
	var l: = UI.label(text, 26, UI.GOLD, UI.DARK, 3, "title", 900)
	l.position = Vector2(24, y)
	l.size = Vector2(cw - 48, 36)
	parent.add_child(l)
	return l


func _lbl(parent: Control, text: String, pos: Vector2, fsize: = 18, color: = UI.MUTED, w: = 0.0) -> Label:
	var l: = UI.label(text, fsize, color, UI.DARK, 2, "body", 800 if fsize < 22 else 900)
	l.position = pos
	if w > 0:
		l.size = Vector2(w, fsize * 1.5)
	parent.add_child(l)
	return l


func _identity() -> void :
	var c: = _section(206, "plum")
	var p: = G.profile()
	var av: String = str(p.get("avatar", "mc"))
	# 0.8 art: the round portrait in the gold avatar frame (V8Art.avatar; the ornate frame from Дракон up)
	var a: = V8ProfileUI.my_avatar(c, Rect2(8, 6, 184, 184), av)
	a.name = "Avatar"
	var hit: = Control.new()
	hit.position = Vector2(20, 10)
	hit.size = Vector2(160, 160)
	hit.mouse_filter = Control.MOUSE_FILTER_STOP
	hit.gui_input.connect( func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			UI.punch(a, 0.06)
			_avatar_popup())
	c.add_child(hit)
	var x: = 204.0
	var nk: = UI.label(G.nick(), 36, Color.WHITE, UI.DARK, 5, "title", 900)
	nk.position = Vector2(x, 18)
	nk.size = Vector2(cw - x - 20, 50)
	nk.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_fit(nk, "title", 36, 26)
	c.add_child(nk)
	var hero: Dictionary = G.HEROES.get(av, G.HEROES.mc)
	_lbl(c, "Аватар: %s" % hero.name, Vector2(x + 2, 70), 18, UI.MUTED, cw - x - 24)
	var bw: = (cw - x - 20 - 12) * 0.5
	var nb: = JButton.make(V8ProfileUI.s("profile.nick_edit"), "glass", Rect2(x, 104, bw, 58), null, 20)
	nb.pressed.connect(_nick_popup)
	c.add_child(nb)
	var ab: = JButton.make(V8ProfileUI.s("profile.avatar_edit"), "glass", Rect2(x + bw + 12, 104, bw, 58), null, 20)
	ab.pressed.connect(_avatar_popup)
	c.add_child(ab)
	var since: = Time.get_date_string_from_unix_time(int(p.get("created", 0)))
	var dp: = since.split("-")
	if dp.size() == 3:
		since = "%s.%s.%s" % [dp[2], dp[1], dp[0]]
	var sl: = _lbl(c, V8ProfileUI.s("profile.since") % [str(p.get("id", "")), since], Vector2(x + 2, 172), 16, Color(0.75, 0.7, 0.65, 0.8), cw - x - 24)
	sl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS


func _fit(l: Label, kind: String, big: int, small: int) -> void :
	var f: = UI.font(kind, 900)
	var fs: = big
	while fs > small and f.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > l.size.x:
		fs -= 2
	var ls: = l.label_settings.duplicate() as LabelSettings
	ls.font_size = fs
	l.label_settings = ls


func _rank() -> void :
	var c: = _section(206)
	var rp: = int(G.S.get("rp", 0))
	var ri: = G.rank_of(rp)
	var rk: Dictionary = G.RANKS[ri.tier]
	# 0.8 art: the rank medallion large (256 px art drawn at 150)
	Common.rank_emblem(c, Rect2(12, 6, 150, 150), ri.tier, ri.sub)
	var t: = UI.label(ri.title, 36, rk.color, UI.DARK, 5, "title", 900)
	t.position = Vector2(176, 20)
	t.size = Vector2(cw - 200, 50)
	c.add_child(t)
	var last: bool = int(ri.tier) == G.RANKS.size() - 1
	Common.progress_bar(c, Rect2(178, 82, cw - 206, 24), 1.0 if last else float(ri.into) / maxf(1.0, ri.need), "gold")
	var nxt: = ""
	if last:
		nxt = V8ProfileUI.s("profile.rank_top")
	else:
		var k: int = int(ri.tier) * 3 + int(ri.sub) + 1
		nxt = V8ProfileUI.s("profile.rank_next") % [ri.into, ri.need, G.rank_title(k / 3, k % 3)]
	_lbl(c, nxt, Vector2(180, 112), 18, Color("ffe7a6"), cw - 206)
	_lbl(c, V8ProfileUI.s("profile.rank_total") % rp, Vector2(180, 138), 17, UI.MUTED, cw - 206)
	var note: = _lbl(c, V8ProfileUI.s("profile.rank_note"), Vector2(24, 166), 16, Color(0.75, 0.7, 0.65, 0.75), cw - 48)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _league() -> void :
	var info: = V8ProfileUI.league_info()
	var c: = _section(176)
	_head(c, V8ProfileUI.s("profile.league"))
	var tw: = (cw - 48 - 14) * 0.5
	var tiles: = []
	if info.has("week"):
		var w: Dictionary = info.week
		var lt: = clampi(int(w.get("league_tier", 0)), 0, G.RANKS.size() - 1)
		if int(w.get("points", 0)) > 0:
			tiles.append([V8ProfileUI.s("profile.week") + " · " + G.RANKS[lt].name, V8ProfileUI.s("profile.place") % [UI.fmt(int(w.get("place", 0))), UI.fmt(int(w.get("group_size", 20)))], _pts(int(w.get("points", 0))), lt])
		else:
			# no tournament table played this week: the same «#19 из 20» as the home league card, with where
			# week points come from
			tiles.append([V8ProfileUI.s("profile.week") + " · " + G.RANKS[lt].name, V8ProfileUI.s("profile.place") % [UI.fmt(int(w.get("place", 0))), UI.fmt(int(w.get("group_size", 20)))], V8ProfileUI.s("profile.league_none"), lt])
	else:
		tiles.append([V8ProfileUI.s("profile.week"), V8ProfileUI.s("profile.league_open"), V8ProfileUI.s("profile.league_none"), -1])
	if info.has("quarter"):
		var q: Dictionary = info.quarter
		# 0.8: below the 80% cut (a new player) the tile shows the points and what they are for, as the victory
		# window does, never «#1 001 из 1 001» (V8League.quarter_shown)
		if V8League.quarter_shown(q):
			tiles.append([V8ProfileUI.s("profile.quarter"), V8ProfileUI.s("profile.place") % [UI.fmt(int(q.get("place", 0))), UI.fmt(int(q.get("total", 1001)))], _pts(int(q.get("points", 0))), -2])
		else:
			tiles.append([V8ProfileUI.s("profile.quarter"), _pts(int(q.get("points", 0))), V8League.Q_HIDDEN_SHORT, -2])
	for i in tiles.size():
		var tl: Array = tiles[i]
		var wdt: = tw if tiles.size() > 1 else cw - 48
		var tab: = "week" if i == 0 else "quarter"
		var b: = UI.rbox("plum", Rect2(24 + i * (tw + 14), 60, wdt, 98), 22, 3, 8)
		b.set_param("border_top", Color("ffe7a6")).set_param("border_bottom", Color("c58a2c"))
		b.mouse_filter = Control.MOUSE_FILTER_STOP
		b.pivot_offset = b.size * 0.5
		c.add_child(b)
		var x0: = 18.0
		if int(tl[3]) >= 0:
			# 0.8 art: the weekly league crest (not the rank medallion)
			Common.league_emblem(b, Rect2(6, 8, 82, 82), int(tl[3]))
			x0 = 92.0
		elif int(tl[3]) == -2:
			# quarter rating: the round «Рейтинг» icon, as on the home column
			b.add_child(V8Art.rect(V8Art.icon("rating"), Rect2(10, 13, 72, 72)))
			x0 = 92.0
		_lbl(b, tl[0], Vector2(x0, 8), 16, UI.MUTED, wdt - x0 - 10).text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		# 0.8: the big value shrinks to the tile instead of running into its border
		var fs1: = 26
		while fs1 > 18 and UI.font("body", 900).get_string_size(String(tl[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs1).x > wdt - x0 - 12:
			fs1 -= 1
		_lbl(b, tl[1], Vector2(x0, 30 + (26 - fs1) * 0.5), fs1, Color.WHITE, wdt - x0 - 10)
		var fs2: = 16
		var l2: = _lbl(b, tl[2], Vector2(x0, 66), fs2, Color("ffe7a6"), wdt - x0 - 10)
		l2.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l2.clip_text = true
		b.gui_input.connect( func(e):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				Sfx.play("pop")
				UI.punch(b, 0.06)
				main.go("v7tourney", {"tab": tab}))


func _stats() -> void :
	var rows: = []
	var total: = {"games": 0, "wins": 0, "rp": 0}
	for md in V8ProfileUI.MODES:
		var st: = G.stats_of(md[0])
		for k in total:
			total[k] += int(st[k])
		if md[0] in V8ProfileUI.ALWAYS_SHOWN or int(st.games) > 0 or int(st.rp) != 0:
			rows.append([md[1], st])
	var rh: = 44.0
	var h: = 64.0 + 34.0 + 34.0 + rows.size() * rh + 8.0 + rh + 20.0
	var empty: bool = total.games == 0
	if empty:
		h += 30.0
	var c: = _section(h)
	_head(c, V8ProfileUI.s("profile.stats"))
	var stars: = 0
	for k in G.S.get("stars", {}):
		stars += int(G.S.stars[k])
	var passed: = maxi(0, int(G.S.get("unlocked", 1)) - 1)
	var sm: = _lbl(c, V8ProfileUI.s("profile.stats_sum") % [passed, stars, G.S.get("yaku_seen", {}).size(), G.YAKU.size() - 1], Vector2(24, 60), 17, Color("ffe7a6"), cw - 48)
	sm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var y: = 98.0
	var cols: = [cw - 360, cw - 246, cw - 136]
	_lbl(c, V8ProfileUI.s("profile.col_mode"), Vector2(24, y), 16, UI.MUTED)
	var heads: = [V8ProfileUI.s("profile.col_games"), V8ProfileUI.s("profile.col_wins"), V8ProfileUI.s("profile.col_rp")]
	for j in 3:
		var l: = _lbl(c, heads[j], Vector2(cols[j], y), 16, UI.MUTED, 90)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	y += 34.0
	for i in rows.size():
		_stat_row(c, y, rows[i][0], rows[i][1], cols, i % 2 == 0, false)
		y += rh
	y += 8.0
	_stat_row(c, y, "Всего", total, cols, false, true)
	y += rh
	if empty:
		_lbl(c, V8ProfileUI.s("profile.stats_new"), Vector2(24, y + 4), 16, Color(0.75, 0.7, 0.65, 0.75), cw - 48)


func _stat_row(c: Control, y: float, name: String, st: Dictionary, cols: Array, zebra: bool, bold: bool) -> void :
	if zebra or bold:
		var z: = UI.rbox("graphite" if not bold else "plum", Rect2(14, y, cw - 28, 40), 14, 0 if not bold else 2, 4)
		z.set_param("shadow_color", Color(0, 0, 0, 0))
		if not bold:
			z.modulate = Color(1, 1, 1, 0.45)
		z.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.add_child(z)
	var fs: = 19
	var col: = Color.WHITE if bold else UI.INK
	var nl: = _lbl(c, name, Vector2(28, y + 6), fs, col, cols[0] - 40)
	nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var vals: = [str(int(st.games)), str(int(st.wins)), ("%+d" % int(st.rp)) if int(st.rp) != 0 else "0"]
	for j in 3:
		var l: = _lbl(c, vals[j], Vector2(cols[j], y + 6), fs, col if j < 2 else Color("ffe7a6"), 90)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


func _ladder() -> void :
	var ri: = G.rank_of(int(G.S.get("rp", 0)))
	var rowh: = 100.0
	var h: = 64.0 + G.RANKS.size() * (rowh + 8) + 10
	var c: = _section(h)
	_head(c, V8ProfileUI.s("profile.ladder"))
	var y: = 62.0
	for t in G.RANKS.size():
		var rk: Dictionary = G.RANKS[t]
		var row: = UI.rbox("gold" if t == ri.tier else "graphite", Rect2(14, y, cw - 28, rowh), 22, 3, 6)
		if t == ri.tier:
			row.colors(Color(0.34, 0.27, 0.2, 0.95), Color(0.18, 0.14, 0.1, 0.95))
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.add_child(row)
		Common.rank_emblem(row, Rect2(10, 8, 84, 84), t, 0 if t > ri.tier else (ri.sub if t == ri.tier else 2))
		var nl: = UI.label(rk.name, 28, rk.color if t <= ri.tier else Color("8a7a9a"), UI.DARK, 4, "title", 900)
		nl.position = Vector2(110, 8)
		row.add_child(nl)
		var sub: String = V6Txt.s("rank.sub") % rk.per if t < G.RANKS.size() - 1 else V6Txt.s("rank.sub_top") % rk.per
		_lbl(row, sub, Vector2(112, 50), 16, UI.MUTED, cw - 300)
		var gl: = UI.label("+%d" % rk.gems, 20, Color("ffd34d"), UI.DARK, 3, "body", 900)
		gl.position = Vector2(cw - 150, 14)
		gl.size = Vector2(70, 30)
		gl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(gl)
		row.add_child(V8Art.rect(V8Art.cur("gem"), Rect2(cw - 82, 6, 44, 44)))
		if t < ri.tier:
			var ok: = _lbl(row, V6Txt.s("rank.passed"), Vector2(cw - 190, 60), 16, Color("9fe8d0"), 150)
			ok.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		elif t == ri.tier:
			Common.progress_bar(row, Rect2(112, 74, cw - 330, 16), float(ri.into) / maxf(1.0, ri.need), "gold")
			var pl: = _lbl(row, "%d/%d" % [ri.into, ri.need], Vector2(cw - 210, 68), 16, Color("ffe7a6"), 120)
			pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		y += rowh + 8
	ladder_c = c


func _code() -> void :
	var c: = _section(206)
	_head(c, V8ProfileUI.s("profile.code"))
	var d: = _lbl(c, V8ProfileUI.s("profile.code_d"), Vector2(24, 58), 18, UI.INK, cw - 48)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.size.y = 52
	var bw: = (cw - 48 - 14) * 0.5
	var sb: = JButton.make(V8ProfileUI.s("profile.code_show"), "gold", Rect2(24, 118, bw, 70), null, 24)
	sb.pressed.connect( func(): V8ProfileUI.show_code_popup(main))
	c.add_child(sb)
	var eb: = JButton.make(V8ProfileUI.s("profile.code_enter"), "glass", Rect2(38 + bw, 118, bw, 70), null, 24)
	eb.pressed.connect( func(): V8ProfileUI.enter_code_popup(main))
	c.add_child(eb)


func _settings() -> void :
	var c: = _section(92, "")
	var b: = JButton.make(V8ProfileUI.s("profile.settings"), "graphite", Rect2(0, 4, cw, 84), null, 28)
	# 0.8 art: round settings icon (192 px), drawn with mipmaps instead of JButton's plain icon rect
	b.add_child(V8Art.rect(V8Art.icon("settings"), Rect2(8, 4, 76, 76)))
	b.pressed.connect( func(): main.settings())
	c.add_child(b)


func _avatar_popup() -> void :
	var p: = Common.popup(main, V8ProfileUI.s("profile.avatar_t"), 330)
	var row: = V8ProfileUI.avatar_row(str(G.profile().get("avatar", "mc")), Rect2(20, 70, p.size.x - 40, 150))
	p.add_child(row)
	var who: = UI.center_label(UI.label("", 20, UI.GOLD, UI.DARK, 2, "body", 800), Rect2(20, 236, p.size.x - 40, 30))
	p.add_child(who)
	var upd: = func(h: String): who.text = "%s · %s" % [G.HEROES[h].name, G.HEROES[h].title]
	upd.call(row.selected)
	row.picked.connect( func(h: String):
		upd.call(h)
		G.set_avatar(h)
		p.get_meta("root").set_meta("on_close", _rebuild))


func _nick_popup() -> void :
	var p: = Common.popup(main, V8ProfileUI.s("profile.nick_t"), 380)
	var w: = p.size.x
	var le: = V8ProfileUI.nick_field(Rect2(36, 70, w - 72 - 104, 86), str(G.profile().get("nick", "")))
	p.add_child(le)
	var dice: = V8ProfileUI.dice_button(Rect2(w - 36 - 88, 70, 88, 86))
	p.add_child(dice)
	var hint: = _lbl(p, V8ProfileUI.s("card.hint"), Vector2(42, 164), 18, UI.MUTED, w - 84)
	dice.pressed.connect( func():
		V8ProfileUI.roll(dice)
		le.text = V8ProfileUI.random_nick()
		le.caret_column = le.text.length())
	var save: = JButton.make(V8ProfileUI.s("profile.save"), "gold", Rect2(60, 222, w - 120, 96), null, 30)
	save.pressed.connect( func():
		var err: = G.nick_error(le.text)
		if err != "":
			hint.text = err
			var ls: = hint.label_settings.duplicate() as LabelSettings
			ls.font_color = Color("ff9a9a")
			hint.label_settings = ls
			UI.punch(le, 0.06)
			return
		G.set_profile(le.text, "", true)
		main.toast(V8ProfileUI.s("profile.saved"), "heart")
		Common.close_popup(p)
		_rebuild())
	p.add_child(save)


func _rebuild() -> void :
	if not is_inside_tree():
		return
	var y: = scroll.scroll_vertical if scroll else 0
	main.screen_id = ""
	await main.go("profile", {"from": back_to, "scroll": y}, false)


func dev_act(act: String) -> void :
	match act:
		"down":
			scroll.scroll_vertical = 560
		"ladder":
			scroll.scroll_vertical = int(ladder_c.position.y) if ladder_c else 0
		"bottom":
			scroll.scroll_vertical = 100000
		"code":
			V8ProfileUI.show_code_popup(main)
		"enter":
			V8ProfileUI.enter_code_popup(main)
		"nick":
			_nick_popup()
		"avatar":
			_avatar_popup()


static func _pts(n: int) -> String:
	return "%s %s" % [UI.fmt(n), V8PlayRules.points_word(n)]
