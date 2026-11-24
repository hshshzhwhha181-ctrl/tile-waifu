class_name V10PathCard
extends RefCounted

# 0.10 · Карточка узла Пути (0.10-spec П1–П3): a bottom sheet — «Играть» sits under the thumb.
#   name and tier (flames), «проходят ≈N%» from Сложный, mechanics, a hostess line + mini tile animation on a new
#   mechanic, the first-clear reward, «полная награда 11/15» (from the 10th win of the day), the Огонёк пути cups and
#   the three booster circles; Peaks: fog, «Здесь не продаётся ни один бустер»; Legendary: laurel, «Обходная тропа».

const Gen = preload("res://scripts/v10/levels/level_gen.gd")
const State = preload("res://scripts/v10/path/path_state.gd")
const Rules = preload("res://scripts/v10/path/path_rules.gd")
const Boost = preload("res://scripts/v10/path/path_boosters.gd")
const PFx = preload("res://scripts/v10/path/path_fx.gd")
const Dlg = preload("res://scripts/v10/path/path_dialogs.gd")


static func title_of(i: int) -> String:
	var n: = State.node(i)
	if n.legend:
		return "Легенда · %s" % Gen.code(i)
	if n.peak:
		return "Пик · %s" % Gen.code(i)
	if n.boss:
		return "Босс главы %d" % (int(n.chapter) + 1)
	return "Уровень %s" % Gen.code(i)


static func pass_rate(i: int) -> int:
	var m: = Gen.baked_metrics(i)
	var r: float = float(m.get("reg", m.get("rate", -1.0))) if m is Dictionary else -1.0
	if r < 0.0:
		r = Gen.target_rate(i)
	return clampi(int(round(r * 20.0)) * 5, 5, 95)


static func open(main, map, i: int) -> Control:
	if State.offer_assist(i):
		Dlg.assist(main, i, func(): open(main, map, i), func(): open(main, map, i))
		return null
	var vs: Vector2 = main.get_viewport_rect().size if main else map.get_viewport_rect().size
	var overlay: Control = main.overlay if main and "overlay" in main else map
	var n: = State.node(i)
	var lvd: = State.level(i)
	var mode: = "peak" if n.peak else ("legend" if n.legend else "")
	var honest: = not Boost.can_use(mode, str(n.tier), bool(n.peak))
	var sel: = Boost.initial_selection(i, mode)

	var root: = Control.new()
	root.size = vs
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.set_meta("v10_sheet", true)
	root.set_meta("popup", true)
	root.name = "PathCard"
	overlay.add_child(root)
	var dim: = ColorRect.new()
	dim.size = vs
	dim.color = Color(0.03, 0.02, 0.035, 0.0)
	root.add_child(dim)
	dim.create_tween().tween_property(dim, "color:a", 0.66, 0.22)

	var pw: = minf(vs.x - 24.0, 700.0)
	var intro_on: bool = str(n.intro) != ""
	var show_daily: bool = bool(State.daily().show) and not (n.peak or n.legend)
	var ph: = 170.0 + (170.0 if intro_on else 0.0) + (120.0 if n.peak or n.legend else 0.0) + 50.0 + (26.0 if show_daily else 0.0) \
		+ (26.0 if State.assisted(i) else 0.0) + 8.0 + 172.0 + 128.0
	ph = minf(ph, vs.y - 150.0)
	var px: = (vs.x - pw) * 0.5
	var py: = vs.y - ph - 18.0
	var p: = Control.new()
	p.position = Vector2(px, py)
	p.size = Vector2(pw, ph)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.name = "Sheet"
	root.add_child(p)
	var art: = V8Art.nine("panel", Rect2(Vector2.ZERO, p.size))
	p.add_child(art)
	if n.peak:
		PFx.fog(p, Rect2(14, 14, pw - 28, ph * 0.55), 0.5, Color(0.82, 0.86, 0.98, 0.9))
	var close: = func():
		if root.has_meta("closing"):
			return
		root.set_meta("closing", true)
		V9Feel.sound("tap")
		var t: = root.create_tween().set_parallel()
		t.tween_property(p, "position:y", vs.y + 20.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.tween_property(dim, "color:a", 0.0, 0.2)
		t.chain().tween_callback(root.queue_free)
	dim.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			close.call())

	# title ribbon
	var tt: = title_of(i)
	var rw: = clampf(Common.ribbon_w(tt, 72, 30), 360.0, pw - 110.0)
	var rib: = Common.ribbon(p, tt, Rect2((pw - rw) * 0.5, -36, rw, 72), "gold" if n.legend else ("lav" if n.peak else "pink"), 30)
	rib.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var xb: = JButton.make("", "graphite", Rect2(pw - 58, -18, 64, 64), null, 30)
	if xb.box:
		xb.box.borders(Color("ffe7a6"), Color("a8742a"))
	xb.add_child(V8Art.rect(V8Art.icon("close"), Rect2(15, 15, 34, 34)))
	xb.pressed.connect(close)
	xb.name = "Close"
	p.add_child(xb)

	var y: = 54.0
	var L: = 34.0
	var cw: = pw - 2.0 * L
	# tier pill with flames + pass rate
	var look: = Rules.tier_look(str(n.tier))
	var tier_name: String = "Передышка" if str(n.tier) == "easy" else str(Gen.TIER_NAMES[n.tier])
	var tp: = UI.rbox("graphite", Rect2(L, y, 250, 46), 23, 2, 8)
	tp.colors(Color(look.bot).darkened(0.1), Color(look.bot).darkened(0.45))
	tp.borders(Color(look.rim), Color(look.bot).darkened(0.3))
	p.add_child(tp)
	var tl: = UI.label(tier_name, 22, Color.WHITE, Color(0.12, 0.04, 0.08), 4, "body", 900)
	tl.position = Vector2(18, 0)
	tl.size = Vector2(220, 46)
	tl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tp.add_child(tl)
	tp.size.x = minf(300.0, UI.font("body", 900).get_string_size(tier_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x + 44.0 + 30.0 * mini(int(look.flames), 2))
	for f in int(look.flames):
		if f >= 2:
			break
		var fi: = UI.tex(Rules.icon("flame"), Rect2(tp.size.x - 40 - f * 28, 5, 34, 34))
		tp.add_child(fi)
	if Gen.TIERS.find(str(n.tier)) >= Gen.TIERS.find("hard"):
		var pr: = UI.label("проходят ≈%d%%" % pass_rate(i), 21, Color("f0e2cf"), Color(0.06, 0.03, 0.05), 3)
		pr.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		pr.position = Vector2(pw - L - 260, y)
		pr.size = Vector2(260, 46)
		pr.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		pr.name = "PassRate"
		p.add_child(pr)
	y += 62.0

	# mechanics
	var mechs: Array = lvd.get("mechs", [])
	var mx: = L
	if mechs.is_empty():
		var l0: = UI.label("Обычный стол — только пары", 20, Color("d9cbbb"))
		l0.position = Vector2(L, y)
		l0.size = Vector2(cw, 40)
		p.add_child(l0)
	for m in mechs:
		var name: String = Rules.MECH_NAMES.get(str(m), str(m))
		var w: = UI.font("body", 900).get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x + 34.0
		if mx + w > pw - L:
			break
		var chp: = UI.rbox("graphite", Rect2(mx, y, w, 40), 20, 2, 8)
		chp.borders(Color("d9b98a"), Color("7a5a2a"))
		p.add_child(chp)
		var cl: = UI.center_label(UI.label(name, 19, Color("ffe9cf"), Color(0.1, 0.04, 0.05), 3, "body", 900), Rect2(0, 0, w, 40))
		chp.add_child(cl)
		mx += w + 10.0
	y += 54.0

	# new mechanic: hostess line + 3 tiles that show the idea
	if intro_on:
		_intro_block(p, i, Rect2(L, y, cw, 156))
		y += 170.0

	# peak / legend block
	if n.peak:
		var rec: = State.peak_rec(i)
		var txt: = "Здесь не продаётся ни один бустер. 1 бесплатная подсказка и 1 отмена."
		_info_block(p, Rules.icon("peak"), txt, "Попыток: %d · Вершин: %d" % [int(rec.tries), State.summits()], Rect2(L, y, cw, 108))
		y += 120.0
	elif n.legend:
		var L2: = State.legend_rec(State.arc_of(i))
		var txt2: = "Самый трудный стол арки. Победа даёт лавр «Легенда арки %d»." % (State.arc_of(i) + 1)
		if bool(L2.bypass):
			txt2 = "Ты прошла дальше обходной тропой. Корона ждёт: лавр — только за победу здесь."
		_info_block(p, Rules.icon("crown"), txt2, "Попыток: %d" % int(L2.tries), Rect2(L, y, cw, 108))
		y += 120.0

	# reward
	var rw2: Dictionary = lvd.get("reward", {})
	var st: = State.stars(i)
	var rtxt: = ""
	if n.peak:
		rtxt = "За первую победу: %d" % int(Rules.reward("peak_first").get("gems", 30)) if st == 0 else "Пик покорён ★%d" % st
	elif n.legend:
		rtxt = "За первую победу: %d + лавр" % int(Rules.reward("legend_first").get("gems", 150)) if st == 0 else "Легенда пройдена ★%d" % st
	elif st == 0:
		rtxt = "За первое прохождение: %d + %d за каждую ★" % [int(rw2.get("gems", 2)), int(rw2.get("per_star", 2))]
	elif st < 3:
		rtxt = "Пройдено ★%d · за новую звезду +%d" % [st, int(rw2.get("per_star", 2))]
	else:
		rtxt = "Пройдено на ★3 · переигровка за монеты"
	var rr: = Control.new()
	rr.position = Vector2(L, y)
	rr.size = Vector2(cw, 44)
	rr.name = "Reward"
	p.add_child(rr)
	rr.add_child(UI.tex(V8Art.cur("gem"), Rect2(0, 0, 44, 44)))
	var rl: = UI.label(rtxt, 21, Color("fff1dc"), Color(0.08, 0.04, 0.05), 3, "body", 900)
	rl.position = Vector2(52, 0)
	rl.size = Vector2(cw - 52, 44)
	rl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Common.fit_line(rl, cw - 52, 16)
	rr.add_child(rl)
	y += 50.0
	var d: = State.daily()
	if bool(d.show) and not (n.peak or n.legend):
		var dl: = UI.label("Полная награда сегодня: %d/%d" % [int(d.n), int(d.max)] if bool(d.full) else "Полная награда за сегодня собрана — дальше звёзды и монеты", 18, Color("e7d6c2"))
		dl.position = Vector2(L + 52, y - 6)
		dl.size = Vector2(cw - 52, 26)
		dl.name = "DailyFull"
		p.add_child(dl)
		y += 26.0
	if State.assisted(i):
		var al: = UI.label("Стол переложен удобнее · звёзды сохраняются", 18, Color("b9f0d6"))
		al.position = Vector2(L + 52, y - 4)
		al.size = Vector2(cw - 52, 26)
		p.add_child(al)
		y += 26.0
	y += 8.0

	# boosters: Огонёк пути + three circles
	var bh: = 172.0
	var by: = ph - 118.0 - bh
	if by < y:
		by = y
	_boosters(main, p, i, mode, sel, honest, Rect2(L, by, cw, bh))

	# «Играть» under the thumb
	var play_txt: = "Играть" if not n.peak else "Подняться"
	if n.legend:
		play_txt = "Бросить вызов"
	var pb: = JButton.make(play_txt, "gold" if (n.legend or n.peak) else "pink", Rect2(L + 20, ph - 112, cw - 40 - (0.0 if not State.legend_bypass_ready(i) else 230.0), 92), null, 34)
	pb.name = "PlayBtn"
	pb.pulse = true
	pb.pressed.connect(func():
		close.call()
		map.play(i, sel))
	p.add_child(pb)
	if State.legend_bypass_ready(i):
		var bb: = JButton.make("Обходная тропа", "graphite", Rect2(pw - L - 230, ph - 104, 220, 76), null, 22)
		bb.name = "BypassBtn"
		bb.pressed.connect(func():
			close.call()
			Dlg.bypass(main, map, i))
		p.add_child(bb)

	# slide up with a spring
	p.position.y = vs.y + 10.0
	var tw: = p.create_tween()
	tw.tween_property(p, "position:y", py, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	V9Feel.sound("whoosh", 1.25, -8.0)
	root.set_meta("sel", sel)
	return root


static func _info_block(p: Control, icon: Texture2D, text: String, sub: String, r: Rect2) -> void:
	var b: = UI.rbox("graphite", r, 22, 2, 10)
	b.colors(Color(0.12, 0.12, 0.17, 0.82), Color(0.06, 0.06, 0.09, 0.88))
	b.borders(Color("c9d3ef"), Color("5a6180"))
	p.add_child(b)
	if icon:
		b.add_child(UI.tex(icon, Rect2(10, 10, 88, 88)))
	var l: = UI.label(text, 19, Color("eef1ff"), Color(0.04, 0.04, 0.08), 3)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.position = Vector2(108, 8)
	l.size = Vector2(r.size.x - 120, 64)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	b.add_child(l)
	var s: = UI.label(sub, 17, Color("b9c0dc"))
	s.position = Vector2(108, 72)
	s.size = Vector2(r.size.x - 120, 28)
	b.add_child(s)


static func _intro_block(p: Control, i: int, r: Rect2) -> void:
	var gc: = State.gchapter(i)
	var host: = State.host_of_chapter(gc)
	var box: = UI.rbox("graphite", r, 22, 2, 10)
	box.colors(Color(0.2, 0.12, 0.18, 0.9), Color(0.1, 0.06, 0.09, 0.92))
	box.borders(Color("ffc7d6"), Color("8a3f57"))
	box.name = "IntroBlock"
	p.add_child(box)
	var av: = V8Art.emotion_avatar(host, "happy", Rect2(12, 14, 96, 96), "gold")
	box.add_child(av)
	var tag: = UI.center_label(UI.label("Новое!", 16, Color.WHITE, Color(0.5, 0.05, 0.2), 3, "body", 900), Rect2(14, 112, 92, 26))
	box.add_child(tag)
	var line: = str(Gen.INTRO_LINES.get(str(Gen.INTRO.get(i, "")), ""))
	var mname: String = Rules.MECH_NAMES.get(str(Gen.INTRO.get(i, "")), "")
	var l: = UI.label("%s: %s" % [Rules.host_name(host), line], 18, Color("fff1f4"), Color(0.1, 0.03, 0.06), 3)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.position = Vector2(120, 8)
	l.size = Vector2(r.size.x - 132 - 170, r.size.y - 16)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.add_child(l)
	# three tiles: two fly together and pop (a pair), the third shows the mechanic's twist (flip / glow / lock)
	var stage: = Control.new()
	stage.position = Vector2(r.size.x - 172, 14)
	stage.size = Vector2(160, r.size.y - 28)
	stage.clip_contents = true
	box.add_child(stage)
	var faces: = [3, 3, 11]
	var tiles: = []
	for k in 3:
		var t: = UI.tex(G.tile_tex(faces[k]), Rect2(8 + k * 50, 30, 46, 60))
		t.pivot_offset = Vector2(23, 30)
		stage.add_child(t)
		tiles.append(t)
	var m: = str(Gen.INTRO.get(i, ""))
	if not V9Feel.can_fx():
		return
	var tw: = stage.create_tween().set_loops()
	tw.tween_interval(0.5)
	# the twist on the third tile
	match m:
		"ice", "ice_heavy", "hidden":
			tw.tween_property(tiles[2], "scale:x", 0.0, 0.15)
			tw.tween_callback(func(): tiles[2].modulate = Color(1, 1, 1))
			tw.tween_property(tiles[2], "scale:x", 1.0, 0.15)
		"gold":
			tw.tween_property(tiles[2], "modulate", Color(1.4, 1.2, 0.6), 0.25)
			tw.tween_property(tiles[2], "modulate", Color(1, 1, 1), 0.25)
		_:
			tw.tween_property(tiles[2], "rotation", 0.18, 0.1)
			tw.tween_property(tiles[2], "rotation", -0.18, 0.1)
			tw.tween_property(tiles[2], "rotation", 0.0, 0.1)
	# the pair
	tw.tween_property(tiles[0], "position:x", 33.0, 0.25).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_property(tiles[1], "position:x", 33.0, 0.25).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(tiles[0], "scale", Vector2(0.0, 0.0), 0.18)
	tw.parallel().tween_property(tiles[1], "scale", Vector2(0.0, 0.0), 0.18)
	tw.tween_interval(0.6)
	tw.tween_callback(func():
		tiles[0].position.x = 8.0
		tiles[1].position.x = 58.0)
	tw.tween_property(tiles[0], "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK)
	tw.parallel().tween_property(tiles[1], "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK)
	if mname != "":
		box.set_meta("mech", mname)


static func _boosters(main, p: Control, i: int, mode: String, sel: Dictionary, honest: bool, r: Rect2) -> void:
	var box: = Control.new()
	box.position = r.position
	box.size = r.size
	box.name = "Boosters"
	p.add_child(box)
	var head: = UI.label("Огонёк пути", 22, Color("ffe7c4"), Color(0.1, 0.05, 0.05), 3, "body", 900)
	head.position = Vector2(0, 0)
	head.size = Vector2(200, 40)
	head.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.add_child(head)
	var fl: = Boost.flame()
	for k in 3:
		var cup: = UI.tex(Rules.icon("flame"), Rect2(150 + k * 40, -2, 44, 44))
		if k >= fl or honest:
			cup.modulate = Color(0.35, 0.32, 0.4, 0.75)
		box.add_child(cup)
	var hint: = UI.label("Здесь только честная игра" if honest else ("Победа +1 чашка, провал −1" if fl < 3 else "Огонёк горит в полную силу"), 17, Color("d7c8b8"))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.position = Vector2(290, 0)
	hint.size = Vector2(r.size.x - 290, 40)
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.name = "HonestHint" if honest else "FlameHint"
	box.add_child(hint)
	var cs: = 92.0
	var gap: = (r.size.x - 3.0 * cs) / 4.0
	for k in 3:
		var kind: String = Rules.BOOSTERS[k]
		var cx: = gap + k * (cs + gap)
		var slot: = Control.new()
		slot.position = Vector2(cx, 48)
		slot.size = Vector2(cs, cs + 34)
		slot.pivot_offset = Vector2(cs * 0.5, cs * 0.5)
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		slot.name = "Boost_" + kind
		box.add_child(slot)
		_paint_slot(slot, kind, sel, honest)
		slot.gui_input.connect(func(e): _slot_input(e, main, slot, kind, sel, honest, i, mode))


static func _slot_input(e: InputEvent, main, slot: Control, kind: String, sel: Dictionary, honest: bool, i: int, mode: String) -> void:
	if not (e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed):
		return
	var res: = Boost.toggle(sel, kind, i, mode)
	if res == "deny":
		V9Feel.deny(slot)
		if honest and main and main.has_method("toast"):
			main.toast("Здесь только честная игра")
		return
	if res == "buy":
		V9Feel.press(slot)
		Common.confirm(main, Rules.BOOSTER_NAMES[kind], Rules.BOOSTER_HELP[kind], "gem", Rules.BOOST_PRICE,
			func(): _buy_done(main, slot, kind, sel, honest, i, mode))
		return
	V9Feel.press(slot, "pop" if res != "" else "tap")
	_paint_slot(slot, kind, sel, honest)
	if res != "" and V9Feel.can_fx():
		Fx.burst(slot, slot.size * Vector2(0.5, 0.36), "sparkle", 10, Color(1, 0.9, 0.6), 0.5)


static func _buy_done(main, slot: Control, kind: String, sel: Dictionary, honest: bool, i: int, mode: String) -> void:
	if not Boost.buy(kind):
		V9Feel.deny(slot)
		return
	Boost.toggle(sel, kind, i, mode)
	if is_instance_valid(slot):
		_paint_slot(slot, kind, sel, honest)
		V9Feel.success(slot)
	if main and main.has_method("refresh_currency"):
		main.refresh_currency()


static func _paint_slot(slot: Control, kind: String, sel: Dictionary, honest: bool) -> void:
	for c in slot.get_children():
		c.queue_free()
	var cs: = slot.size.x
	var on: = sel.has(kind)
	var src: = str(sel.get(kind, ""))
	var ring: = UI.rbox("graphite", Rect2(0, 0, cs, cs), cs * 0.5, 3, 8)
	if honest:
		ring.colors(Color(0.2, 0.2, 0.24, 0.9), Color(0.12, 0.12, 0.15, 0.95))
		ring.borders(Color(0.45, 0.45, 0.5), Color(0.3, 0.3, 0.35))
	elif on:
		ring.colors(Color("6b2a45"), Color("2c0f1c"))
		ring.borders(Color("ffe7a6"), Color("c58a2c"))
	else:
		ring.borders(Color("bfae98"), Color("5a4a3a"))
	slot.add_child(ring)
	var ic: = UI.tex(Rules.icon(kind), Rect2(8, 6, cs - 16, cs - 16))
	if honest:
		ic.modulate = Color(0.4, 0.4, 0.45, 0.8)
	elif not on:
		ic.modulate = Color(0.75, 0.72, 0.78)
	slot.add_child(ic)
	if on and not honest:
		var chk: = UI.rbox("mint", Rect2(cs - 30, -4, 34, 34), 17, 2, 6)
		slot.add_child(chk)
		chk.add_child(UI.center_label(UI.label("✓", 20, Color.WHITE, Color(0.05, 0.2, 0.1), 3, "body", 900), Rect2(0, 0, 34, 34)))
	var cap: = ""
	var col: = Color("e9dccb")
	if honest:
		cap = "—"
	elif src == "free":
		cap = "даром"
		col = Color("ffd98a")
	elif Boost.stock(kind) > 0:
		cap = "%s ×%d" % ["в запасе" if not on else "взят", Boost.stock(kind)]
	else:
		cap = "%d" % Rules.BOOST_PRICE
	var l: = UI.center_label(UI.label(cap, 18, col, Color(0.08, 0.04, 0.05), 3, "body", 900), Rect2(-20, cs + 2, cs + 40, 28))
	slot.add_child(l)
	if cap == "%d" % Rules.BOOST_PRICE and not honest:
		l.position.x += 12
		slot.add_child(UI.tex(V8Art.cur("gem"), Rect2(cs * 0.5 - 40, cs + 2, 28, 28)))
