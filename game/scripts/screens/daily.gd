class_name Daily
extends RefCounted



const MONTHS: = ["Январь", "Февраль", "Март", "Апрель", "Май", "Июнь", "Июль", "Август", "Сентябрь", "Октябрь", "Ноябрь", "Декабрь"]
const MILESTONES: = {7: {"gems": 200}, 14: {"gems": 300}, 21: {"gems": 400}, 28: {"item": "o_cozy"}}

static func _reward_icon(r: Dictionary) -> Texture2D:
	if r.has("item"):
		return G.art_tex(G.ITEM[r.item])
	return V8Art.cur("gem" if r.has("gems") else "coin")

static func _give(main, r: Dictionary, from: Vector2) -> void :
	if r.has("gems"):
		G.S.gems += int(r.gems)
		main.fly_gems(from, 6)
	if r.has("coins"):
		G.S.coins += int(r.coins)
	if r.has("item"):
		G.give(r.item)
		main.toast(V6Txt.s("daily.outfit") % G.ITEM[r.item].name, "wardrobe")
	main.refresh_currency(true)

static func login(main, home) -> void :
	var p: = Common.popup(main, V6Txt.s("daily.login_t"), 640)
	var n: = int(G.S.login.n)
	var ready: = G.login_ready()
	var week_pos: = n % 7
	if not ready and week_pos == 0 and n > 0:
		week_pos = 7
	var cw: = 84.0
	for k in 7:
		var r: Dictionary = G.LOGIN_REWARDS[k]
		var x: = 22.0 + k * (cw + 4)
		var big: = k == 6
		var claimed: = k < week_pos
		var today: = ready and k == week_pos
		var c: = UI.rbox("gold" if big else ("pink" if today else ("cream" if not claimed else "mint")), Rect2(x, 64, cw, 150), 18, 3, 8)
		p.add_child(c)
		c.add_child(UI.center_label(UI.label(V6Txt.s("daily.day") % (k + 1), 16, UI.INK if not today else Color.WHITE, Color.WHITE if not today else Color("7a2346"), 3, "body", 900), Rect2(0, 4, cw, 24)))
		c.add_child(V8Art.rect(_reward_icon(r), Rect2(10, 30, cw - 20, cw - 20)))
		var amount: int = r.get("gems", r.get("coins", 0))
		c.add_child(UI.center_label(UI.label(UI.fmt(amount), 18, Color("f2799f") if r.has("gems") else Color("c58a2c"), Color.WHITE, 4, "body", 900), Rect2(0, 108, cw, 30)))
		if claimed:
			var ck: = UI.rbox("mint", Rect2(cw * 0.5 - 20, 50, 40, 40), 20, 2, 4)
			c.add_child(ck)
			ck.add_child(UI.center_label(UI.label("✓", 24, Color.WHITE, Color("1f5e49"), 3), Rect2(0, 0, 40, 40)))
		if today:
			c.pivot_offset = c.size * 0.5
			var t: Tween = c.create_tween().set_loops()
			t.tween_property(c, "scale", Vector2(1.06, 1.06), 0.5).set_trans(Tween.TRANS_SINE)
			t.tween_property(c, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_SINE)

	var tl: = UI.label(V6Txt.s("daily.month") % mini(n, 28), 22, UI.INK, Color.WHITE, 3, "body", 900)
	tl.position = Vector2(30, 236)
	p.add_child(tl)
	Common.progress_bar(p, Rect2(30, 300, 570, 26), float(mini(n, 28)) / 28.0, "gold")
	for d in MILESTONES:
		var x: = 30.0 + 560.0 * float(d) / 28.0
		var mr: Dictionary = MILESTONES[d]
		var got: = n >= int(d)
		var mb: = UI.rbox("gold" if got else "glass", Rect2(x - 40, 334, 72, 72), 16, 3, 6)
		p.add_child(mb)
		mb.add_child(V8Art.rect(_reward_icon(mr), Rect2(6, 6, 60, 60)))
		p.add_child(UI.center_label(UI.label(V6Txt.s("daily.days") % d, 16, UI.INK), Rect2(x - 44, 408, 80, 22)))
	var note: = UI.center_label(UI.label(V6Txt.s("daily.login_note"), 18, Color("8a5a7a")), Rect2(0, 448, 660, 28))
	p.add_child(note)
	var b: = JButton.make(V6Txt.s("common.claim") if ready else V6Txt.s("daily.login_wait"), "gold" if ready else "glass", Rect2(130, 500, 400, 100), null, 32)
	b.shine_every = 2.0 if ready else 0.0
	b.pressed.connect( func():
		if not G.login_ready():
			Common.close_popup(p)
			return
		var r: Dictionary = G.LOGIN_REWARDS[int(G.S.login.n) % 7]
		G.S.login.n = int(G.S.login.n) + 1
		G.S.login.last = G.today()
		_give(main, r, b.get_global_rect().get_center())
		if MILESTONES.has(int(G.S.login.n)):
			_give(main, MILESTONES[int(G.S.login.n)], b.get_global_rect().get_center())
		Sfx.play("win", 1.2, -4)
		G.save()
		Common.close_popup(p)
		if home and home.has_method("refresh_badges"):
			home.refresh_badges())
	p.add_child(b)

static func tasks(main, home) -> void :
	var p: = Common.popup(main, V6Txt.s("daily.tasks_t"), 560)
	var t: = G.tasks()
	for i in G.TASKS.size():
		var td: Dictionary = G.TASKS[i]
		var y: = 64.0 + i * 140
		var row: = UI.rbox("glass", Rect2(24, y, 612, 124), 24, 3, 8)
		p.add_child(row)
		# 0.8: trophy / heart are the new gold glyphs; «star» has no 0.8 art and keeps the old icon
		var ic_name: String = ["star", "trophy", "heart"][i]
		var ic_tex: Texture2D = V8Art.icon(ic_name)
		row.add_child(V8Art.rect(ic_tex, Rect2(14, 20, 80, 80)))
		var nl: = UI.label(td.name, 24, UI.INK, Color.WHITE, 3, "body", 900)
		nl.position = Vector2(110, 14)
		row.add_child(nl)
		var v: = mini(int(t[td.key]), td.goal)
		Common.progress_bar(row, Rect2(110, 60, 250, 24), float(v) / td.goal, "mint")
		var vl: = UI.label("%d/%d" % [v, td.goal], 18, UI.INK)
		vl.position = Vector2(370, 60)
		row.add_child(vl)
		var rw: = Common.chip(row, V8Art.cur("gem"), "%d" % td.gems, Rect2(112, 90, 110, 30), "plum", 17)
		var done: bool = v >= td.goal
		var claimed: bool = t.claimed[i]
		var b: = JButton.make("✓" if claimed else (V6Txt.s("common.claim") if done else V6Txt.s("daily.in_progress")), "mint" if claimed else ("gold" if done else "glass"), Rect2(440, 26, 156, 72), null, 24)
		b.disabled = claimed or not done
		var idx: = i
		b.pressed.connect( func():
			if G.tasks().claimed[idx] or int(G.tasks()[td.key]) < td.goal:
				return
			G.tasks().claimed[idx] = true
			G.S.gems += int(td.gems)
			G.add_pass_xp(100)
			G.save()
			main.fly_gems(b.get_global_rect().get_center(), 5)
			Sfx.play("win", 1.3, -6)
			b.lbl.text = "✓"
			b.box.colors(UI.PAL.mint[0], UI.PAL.mint[1])
			if home and home.has_method("refresh_badges"):
				home.refresh_badges())
		row.add_child(b)
	var note: = UI.center_label(UI.label(V6Txt.s("daily.tasks_note"), 17, Color("8a5a7a")), Rect2(0, 492, 660, 28))
	p.add_child(note)

static func calendar(main) -> void :
	var p: = Common.popup(main, V6Txt.s("daily.cal_t"), 800)
	var dm: = G.dailymap()
	var month: String = dm.month
	var mi: = int(month.substr(5, 2))
	var year: = int(month.substr(0, 4))
	var first: = Time.get_datetime_dict_from_datetime_string(month + "-01T00:00:00", true)
	var wd: = (int(first.weekday) + 6) % 7
	var days_in: int = [31, 29 if year % 4 == 0 else 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][mi - 1]
	var today_d: = int(G.today().substr(8, 2))
	var done: Array = dm.done.map( func(x): return int(x))
	var htxt: = "%s %d" % [MONTHS[mi - 1], year]
	var hl: = UI.center_label(UI.title(htxt, 30, UI.INK, Color.WHITE), Rect2(0, 48, 660, 44))
	p.add_child(hl)
	# 0.8: the calendar glyph next to the month (icon/calendar; the art may be missing in older builds)
	if V8Art.has("icon/calendar"):
		var hw: float = UI.font_for("title", 30, 900).get_string_size(htxt, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
		p.add_child(V8Art.rect(V8Art.icon("calendar"), Rect2(330 - hw * 0.5 - 52, 50, 42, 42)))
	var names: = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]
	var cw: = 84.0
	for k in 7:
		p.add_child(UI.center_label(UI.label(names[k], 16, Color("8a5a7a")), Rect2(24 + k * (cw + 4), 96, cw, 22)))
	for d in range(1, days_in + 1):
		var cell: = wd + d - 1
		var x: = 24.0 + (cell % 7) * (cw + 4)
		var y: = 122.0 + (cell / 7) * 74
		var is_done: = d in done
		var pal: = "mint" if is_done else ("pink" if d == today_d else ("cream" if d < today_d else "glass"))
		var c: = UI.rbox(pal, Rect2(x, y, cw, 66), 14, 2, 4)
		p.add_child(c)
		c.add_child(UI.center_label(UI.label(str(d), 20, Color.WHITE if pal in ["pink", "mint"] else UI.INK, Color("7a2346") if pal == "pink" else (Color("1f5e49") if pal == "mint" else Color.WHITE), 3, "body", 900), Rect2(4, 2, 34, 28)))
		if is_done:
			c.add_child(UI.tex(G.fx("star"), Rect2(36, 22, 44, 44)))
		elif d > today_d:
			c.modulate.a = 0.6
	var solved: = done.size()
	var tr: = UI.rbox("gold", Rect2(24, 576, 612, 86), 22, 3, 8)
	p.add_child(tr)
	tr.add_child(V8Art.rect(V8Art.icon("trophy"), Rect2(8, 4, 78, 78)))
	var tt: = UI.label(V6Txt.s("daily.trophy") % mini(solved, 20), 22, Color.WHITE, Color("7a4a0c"), 4, "body", 900)
	tt.position = Vector2(96, 8)
	tr.add_child(tt)
	Common.progress_bar(tr, Rect2(98, 46, 490, 22), float(mini(solved, 20)) / 20.0, "pink")
	var ready: = not G.daily_done_today()
	var b: = JButton.make(V6Txt.s("daily.play") if ready else V6Txt.s("daily.solved"), "pink" if ready else "glass", Rect2(80, 684, 500, 96), null, 30)
	b.shine_every = 2.2 if ready else 0.0
	b.pressed.connect( func():
		if G.daily_done_today():
			Common.close_popup(p)
			return
		main.go("play", {"daily": true}))
	p.add_child(b)
