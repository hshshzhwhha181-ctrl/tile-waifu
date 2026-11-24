class_name V10PathDialogs
extends RefCounted

# 0.10 Path windows:
#   assist(main, i, on_yes, on_no)          the chapter hostess after 2 fails: «Давай я переложу стол чуть удобнее?»
#   fail_window(main, i, res, jam, on_retry, on_map)   Path fail window: NO paid button on Peaks / Legendary,
#                                           «место затора» (jam spot) with «Показать на столе», the assist offer
#   arcs_sheet(main, map)                   «Арки»: 10 covers, unreleased as silhouettes «Арка выходит с обновлением»
#   bypass(main, map, i)                    «Обходная тропа» after 5 Legendary fails (no laurel, crown stays empty)
#   win_peak(main, res)                     summit stamp «Вершин: N» (+ «Восходящая» step)

const Gen = preload("res://scripts/v10/levels/level_gen.gd")
const State = preload("res://scripts/v10/path/path_state.gd")
const Rules = preload("res://scripts/v10/path/path_rules.gd")
const PFx = preload("res://scripts/v10/path/path_fx.gd")

const ASSIST_LINES: = ["Давай я переложу стол чуть удобнее?", "Хочешь, я переложу стол чуть удобнее? Звёзды останутся твоими."]


static func _vs(main) -> Vector2:
	return main.get_viewport_rect().size


static func _root(main, name: String) -> Control:
	var vs: = _vs(main)
	var root: = Control.new()
	root.size = vs
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.set_meta("popup", true)
	root.set_meta("v10_sheet", true)
	root.name = name
	main.overlay.add_child(root)
	var dim: = ColorRect.new()
	dim.size = vs
	dim.color = Color(0.03, 0.02, 0.035, 0.0)
	dim.name = "Dim"
	root.add_child(dim)
	dim.create_tween().tween_property(dim, "color:a", 0.74, 0.25)
	return root


static func _close(root: Control) -> void:
	if not is_instance_valid(root) or root.has_meta("closing"):
		return
	root.set_meta("closing", true)
	var t: = root.create_tween()
	t.tween_property(root, "modulate:a", 0.0, 0.18)
	t.tween_callback(root.queue_free)


# ------------------------------------------------------------------ assist

static func assist(main, i: int, on_yes: Callable, on_no: Callable) -> Control:
	var vs: = _vs(main)
	var root: = _root(main, "PathAssist")
	var host: = State.host_of_chapter(State.gchapter(i))
	var w: = minf(vs.x - 40.0, 660.0)
	var x: = (vs.x - w) * 0.5
	# her bust rises from the bottom; the emotion answers the choice (shy offer → happy on «да», pout-then-smile on «нет»)
	var bust_h: = minf(vs.y * 0.5, 640.0)
	var bust: = V8Art.bust(host, "shy", Vector2(w, bust_h), Vector2(w * 0.5, bust_h * 0.3), 150.0, 0.2)
	bust.position = Vector2(x, vs.y - bust_h - 300.0)
	bust.name = "HostBust"
	root.add_child(bust)
	UI.slide_in(bust, Vector2(0, 80), 0.05, 0.5)
	var panel_h: = 300.0
	var p: = UI.rbox("graphite", Rect2(x, vs.y - panel_h - 24.0, w, panel_h), 30, 3, 12)
	p.borders(Color("ffe7a6"), Color("a8742a"))
	p.name = "Panel"
	root.add_child(p)
	var nm: = UI.label(Rules.host_name(host), 26, Color("ffd2de"), Color(0.15, 0.03, 0.08), 4, "title", 900)
	nm.position = Vector2(28, 14)
	nm.size = Vector2(w - 56, 36)
	p.add_child(nm)
	var line: String = ASSIST_LINES[i % ASSIST_LINES.size()]
	var l: = UI.label(line, 25, Color("fff6ea"), Color(0.08, 0.03, 0.05), 3)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.position = Vector2(28, 56)
	l.size = Vector2(w - 56, 96)
	l.name = "Line"
	p.add_child(l)
	var sub: = UI.label("Тот же уровень и те же фишки, раздача спокойнее. Звёзды сохраняются.", 18, Color("d7c8b8"))
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.position = Vector2(28, 148)
	sub.size = Vector2(w - 56, 48)
	p.add_child(sub)
	var bw: = (w - 76.0) * 0.5
	var yes: = JButton.make("Да, давай", "pink", Rect2(28, panel_h - 100, bw, 80), null, 28)
	yes.name = "Yes"
	var no: = JButton.make("Нет, сам(а)", "graphite", Rect2(48 + bw, panel_h - 100, bw, 80), null, 26)
	no.name = "No"
	p.add_child(yes)
	p.add_child(no)
	UI.slide_in(p, Vector2(0, 60), 0.0, 0.4)
	yes.pressed.connect(func():
		State.accept_assist(i)
		V8Art.bust_set(bust, "happy", 0.3)
		V9Feel.success(bust, "sparkle", 0.7)
		if V9Feel.can_fx():
			Fx.burst(root, bust.position + Vector2(w * 0.5, bust_h * 0.3), "heart", 10, Color(1, 0.8, 0.86), 0.7)
		var t: = root.create_tween()
		t.tween_interval(0.55)
		t.tween_callback(func():
			_close(root)
			if on_yes.is_valid():
				on_yes.call()))
	no.pressed.connect(func():
		State.decline_assist(i)
		V8Art.bust_set(bust, "pout", 0.25)
		var t2: = root.create_tween()
		t2.tween_interval(0.35)
		t2.tween_callback(func(): V8Art.bust_set(bust, "happy", 0.3))
		t2.tween_interval(0.35)
		t2.tween_callback(func():
			_close(root)
			if on_no.is_valid():
				on_no.call()))
	return root


# ------------------------------------------------------------------ fail window

static func fail_window(main, i: int, res: Dictionary, jam: Dictionary, on_retry: Callable, on_map: Callable, on_show_jam: = Callable()) -> Control:
	var vs: = _vs(main)
	var root: = _root(main, "PathFail")
	var n: = State.node(i)
	var stone: bool = n.peak or n.legend
	var w: = minf(vs.x - 40.0, 660.0)
	var h: = 560.0 + (110.0 if not jam.is_empty() else 0.0) + (90.0 if res.get("bypass", false) else 0.0)
	var p: = UI.rbox("graphite", Rect2((vs.x - w) * 0.5, maxf(140.0, (vs.y - h) * 0.5), w, h), 32, 4, 14)
	if stone:
		p.colors(Color(0.27, 0.27, 0.3, 0.97), Color(0.13, 0.13, 0.15, 0.98))
		p.borders(Color("d8d2c2"), Color("6f6a5e"))
		PFx.fog(p, Rect2(10, 10, w - 20, h * 0.45), 0.4)
	else:
		p.borders(Color("ffe7a6"), Color("a8742a"))
	p.name = "Panel"
	root.add_child(p)
	UI.pop_in(p, 0.0, 0.85)
	V9Feel.fail(null, "deny")
	var title: = "Пик не сдался" if n.peak else ("Легенда устояла" if n.legend else "Не вышло")
	var t: = UI.center_label(UI.title(title, 40, Color("fff3e6"), Color(0.2, 0.05, 0.1)), Rect2(0, 22, w, 60))
	p.add_child(t)
	var host: = State.host_of_chapter(State.gchapter(i))
	var av: = V8Art.emotion_avatar(host, "sad" if not stone else "surprised", Rect2(w * 0.5 - 70, 92, 140, 140), "gold")
	p.add_child(av)
	var y: = 246.0
	var cheer: = "Ещё чуть-чуть. Вершины берут упорством." if stone else "Лоток переполнился. Попробуем ещё раз?"
	var cl: = UI.center_label(UI.label(cheer, 22, Color("f2e6d8"), Color(0.08, 0.03, 0.05), 3), Rect2(30, y, w - 60, 40))
	p.add_child(cl)
	y += 54.0
	if not jam.is_empty():
		var jb: = UI.rbox("graphite", Rect2(28, y, w - 56, 96), 22, 2, 10)
		jb.colors(Color(0.32, 0.12, 0.16, 0.9), Color(0.16, 0.06, 0.08, 0.95))
		jb.borders(Color("ffb3c0"), Color("7a2a3a"))
		jb.name = "JamBlock"
		p.add_child(jb)
		var jt: = UI.label("Место затора", 21, Color("ffd2da"), Color(0.15, 0.03, 0.06), 3, "body", 900)
		jt.position = Vector2(18, 6)
		jt.size = Vector2(w - 260, 30)
		jb.add_child(jt)
		var jl: = UI.label(str(jam.get("text", "")), 17, Color("f6e6ea"))
		jl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		jl.position = Vector2(18, 36)
		jl.size = Vector2(w - 260, 56)
		jb.add_child(jl)
		var sb: = JButton.make("Показать", "graphite", Rect2(w - 56 - 190, 16, 176, 64), null, 22)
		sb.name = "ShowJam"
		sb.pressed.connect(func():
			_close(root)
			if on_show_jam.is_valid():
				on_show_jam.call(jam))
		jb.add_child(sb)
		y += 110.0
	if bool(res.get("offer_assist", false)):
		var al: = UI.center_label(UI.label("%s может переложить стол удобнее" % Rules.host_name(host), 19, Color("b9f0d6")), Rect2(30, y, w - 60, 30))
		p.add_child(al)
		y += 34.0
	var bw: = (w - 76.0) * 0.5
	var retry: = JButton.make("Ещё раз", "pink" if not stone else "gold", Rect2(28, h - 110, bw, 86), null, 30)
	retry.name = "Retry"
	var tomap: = JButton.make("На карту", "graphite", Rect2(48 + bw, h - 110, bw, 86), null, 28)
	tomap.name = "ToMap"
	p.add_child(retry)
	p.add_child(tomap)
	retry.pressed.connect(func():
		_close(root)
		if bool(res.get("offer_assist", false)):
			assist(main, i, on_retry, on_retry)
		elif on_retry.is_valid():
			on_retry.call())
	tomap.pressed.connect(func():
		_close(root)
		if on_map.is_valid():
			on_map.call())
	if bool(res.get("bypass", false)):
		var bb: = JButton.make("Обходная тропа", "graphite", Rect2(28, h - 200, w - 56, 76), null, 24)
		bb.name = "BypassBtn"
		bb.pressed.connect(func():
			_close(root)
			var r: = State.bypass_legend(i)
			if main.has_method("toast"):
				main.toast("Тропа открыта. Корона ждёт тебя здесь")
			if on_map.is_valid():
				on_map.call())
		p.add_child(bb)
	return root


# the 2 s highlight of the jam tile on a board (play.gd passes its board; any node with tiles[] works)
static func show_jam_on_board(board, jam: Dictionary, parent: Node = null) -> void:
	if board == null or jam.is_empty():
		return
	var idx: = int(jam.get("tile", -1))
	if idx < 0 or idx >= board.tiles.size():
		return
	var t = board.tiles[idx]
	var ring: = Sprite2D.new()
	ring.texture = G.fx("ring")
	ring.modulate = Color(1.0, 0.35, 0.45, 0.95)
	ring.z_index = 300
	ring.scale = Vector2(0.6, 0.6)
	t.add_child(ring)
	var tw: = ring.create_tween()
	for k in 4:
		tw.tween_property(ring, "scale", Vector2(0.9, 0.9), 0.25)
		tw.tween_property(ring, "scale", Vector2(0.6, 0.6), 0.25)
	tw.tween_callback(ring.queue_free)


# ------------------------------------------------------------------ arcs sheet

static func arcs_sheet(main, map) -> Control:
	var vs: = _vs(main)
	var root: = _root(main, "PathArcs")
	var w: = minf(vs.x - 24.0, 700.0)
	var top: = 120.0
	var h: = vs.y - top - 20.0
	var p: = Control.new()
	p.position = Vector2((vs.x - w) * 0.5, top)
	p.size = Vector2(w, h)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.name = "Sheet"
	root.add_child(p)
	p.add_child(V8Art.nine("panel", Rect2(Vector2.ZERO, p.size)))
	var rw: = 320.0
	Common.ribbon(p, "Арки Пути", Rect2((w - rw) * 0.5, -36, rw, 72), "pink", 30).mouse_filter = Control.MOUSE_FILTER_IGNORE
	var xb: = JButton.make("", "graphite", Rect2(w - 58, -18, 64, 64), null, 30)
	xb.add_child(V8Art.rect(V8Art.icon("close"), Rect2(15, 15, 34, 34)))
	xb.pressed.connect(func(): _close(root))
	xb.name = "Close"
	p.add_child(xb)
	var sc: = ScrollContainer.new()
	sc.position = Vector2(20, 50)
	sc.size = Vector2(w - 40, h - 70)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	p.add_child(sc)
	var list: = Control.new()
	var cw: = w - 40.0
	var ch: = 196.0
	list.custom_minimum_size = Vector2(cw, Gen.WORLDS * (ch + 16.0))
	sc.add_child(list)
	for a in Gen.WORLDS:
		var rel: = State.arc_released(a)
		var card: = Control.new()
		card.position = Vector2(0, a * (ch + 16.0))
		card.size = Vector2(cw, ch)
		card.pivot_offset = card.size * 0.5
		card.mouse_filter = Control.MOUSE_FILTER_PASS
		card.name = "Arc%d" % (a + 1)
		list.add_child(card)
		var cov: = Rules.cover(a)
		if cov:
			var art: = Common.card_art(cov, Rect2(0, 0, cw, ch), Vector2(0.5, 0.5), 1.0, 22.0)
			if not rel:
				# silhouette: the cover as a dark shape, no detail and no timer
				art.modulate = Color(0.09, 0.08, 0.12)
			card.add_child(art)
		else:
			var ph: = UI.rbox("graphite", Rect2(0, 0, cw, ch), 22, 2, 10)
			ph.colors(Color(0.12, 0.1, 0.15), Color(0.06, 0.05, 0.08))
			card.add_child(ph)
		var fr: = UI.rbox("graphite", Rect2(0, 0, cw, ch), 22, 3, 10)
		fr.colors(Color(0, 0, 0, 0), Color(0, 0, 0, 0))
		fr.borders(Color("ffe7a6") if a == map.arc else (Color("c9b99a") if rel else Color("5a5260")), Color("a8742a") if rel else Color("3a3340"))
		card.add_child(fr)
		var ff: = Common.floor_fade(card, 60, ch, Color(0.05, 0.03, 0.06), 0.9)
		ff.size.x = cw
		var t1: = UI.label("Арка %d · %s" % [a + 1, Rules.ARC_TITLES[a]], 26, Color("fff3e6") if rel else Color("cfc6d6"), Color(0.12, 0.04, 0.07), 4, "title", 900)
		t1.position = Vector2(20, ch - 80)
		t1.size = Vector2(cw - 40, 38)
		Common.fit_line(t1, cw - 40, 20)
		card.add_child(t1)
		var sub: = ""
		if rel:
			var pr: = State.arc_progress(a)
			sub = "%s · пройдено %d/%d" % [str(Gen.WORLD[a].name), pr[0], pr[1]]
			if State.legend_rec(a).won:
				sub += " · лавр"
		else:
			sub = "Арка выходит с обновлением"
		var sl: = UI.label(sub, 18, Color("eadccb") if rel else Color("a89eb2"), Color(0.06, 0.03, 0.05), 3)
		sl.position = Vector2(22, ch - 42)
		sl.size = Vector2(cw - 44, 28)
		card.add_child(sl)
		if not rel:
			var lk: = V8Art.icon("lock")
			if lk:
				card.add_child(UI.tex(lk, Rect2(cw * 0.5 - 30, 30, 60, 60)))
		if a == map.arc:
			var tag: = Common.chip(card, null, "Ты здесь", Rect2(cw - 150, 14, 136, 38), "pink", 18)
			tag.name = "Here"
		card.gui_input.connect(func(e):
			if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed:
				if not rel:
					V9Feel.deny(card)
					if main.has_method("toast"):
						main.toast("Арка выходит с обновлением")
					return
				V9Feel.press(card)
				_close(root)
				map.switch_arc(a))
	p.position.y = vs.y
	p.create_tween().tween_property(p, "position:y", top, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return root


# ------------------------------------------------------------------ legend bypass

static func bypass(main, map, i: int) -> void:
	Common.confirm(main, "Обходная тропа", "Тропа ведёт дальше, мимо Легенды. Лавр «Легенда арки %d» можно получить только победой здесь — корона подождёт." % (State.arc_of(i) + 1),
		"", 0, func():
			State.bypass_legend(i)
			V9Feel.success(null, "sparkle")
			if map and map.has_method("switch_arc"):
				var nx: = State.next_main(i)
				if State.arc_released(State.arc_of(nx)):
					map.switch_arc(State.arc_of(nx)))


# ------------------------------------------------------------------ peak win

static func win_peak(main, res: Dictionary) -> Control:
	if not bool(res.get("summit", false)):
		return null
	return PFx.summit_stamp(main.overlay, _vs(main), int(res.summits), int(res.frame_step))
