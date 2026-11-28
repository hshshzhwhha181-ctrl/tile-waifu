class_name V10PathDialogs
extends RefCounted

# 0.10 Path windows:
#   assist(main, i, on_yes, on_no)          the chapter hostess after 2 fails: «Давай я переложу стол чуть удобнее?»
#   fail_window(main, i, res, jam, on_retry, on_map)   Path fail window: NO paid button on Peaks / Legendary,
#                                           the jam spot («Где лоток начал копиться» + «Показать»), the assist offer
#   arcs_sheet(main, map)                   «Арки»: the released arcs + ONE closed teaser «Откроется: с обновлением игры»
#                                           (UX_RULES §6.4: one closed item per list, a silhouette, no lock, no timer)
#   bypass(main, map, i)                    «Пройти дальше без лавра» after 5 Legendary fails (spec: «Обходная тропа»;
#                                           the crown stays empty)
#   help_sheet(main, map)                   «?» of the map: what the Path words mean (V10PathRules.GLOSSARY)
#   win_peak(main, res)                     summit stamp «Вершин: N» (+ «Восходящая» step)
# Buttons carry meta ux_role (primary / secondary / tertiary): one primary, ≤2 secondary, ≤2 tertiary per window.

const Gen = preload("res://core/levels/level_gen.gd")
const State = preload("res://core/path/path_state.gd")
const Rules = preload("res://core/path/path_rules.gd")
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
	var panel_h: = 392.0
	var bust_h: = minf(vs.y * 0.5, 640.0)
	var bust: = V8Art.bust(host, "shy", Vector2(w, bust_h), Vector2(w * 0.5, bust_h * 0.3), 150.0, 0.2)
	bust.position = Vector2(x, vs.y - bust_h - panel_h)
	bust.name = "HostBust"
	root.add_child(bust)
	UI.slide_in(bust, Vector2(0, 80), 0.05, 0.5)
	var p: = UI.rbox("graphite", Rect2(x, vs.y - panel_h - 24.0, w, panel_h), 12, 2, 12)
	p.colors(Rules.C.night700, Rules.C.night800)
	p.borders(Rules.C.gold_line, Rules.C.gold_line)
	p.name = "Panel"
	root.add_child(p)
	var nm: = UI.label(Rules.host_name(host), UI.T_H3, Color("ffd2de"), Color(0.15, 0.03, 0.08), 4, "title", 900)
	nm.position = Vector2(28, 14)
	nm.size = Vector2(w - 56, 36)
	p.add_child(nm)
	var line: String = ASSIST_LINES[i % ASSIST_LINES.size()]
	var l: = UI.label(line, UI.T_BODY, Color("fff6ea"), Color(0.08, 0.03, 0.05), 3)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.position = Vector2(28, 54)
	l.size = Vector2(w - 56, 64)
	l.name = "Line"
	p.add_child(l)
	var sub: = UI.label("Тот же уровень и те же фишки, раздача спокойнее. Звёзды сохраняются.", UI.T_SMALL, Color("d7c8b8"))
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.position = Vector2(28, 120)
	sub.size = Vector2(w - 56, 52)
	p.add_child(sub)
	# «Да, давай» — the main button at full width (≥ 440×104); «Нет, сам(а)» — a quiet glass one under it
	var yes: = JButton.make("Да, давай", "pink", Rect2(28, 184, w - 56, 104), null, UI.T_H2)
	yes.name = "Yes"
	yes.set_meta("ux_role", "primary")
	var no: = JButton.make("Нет, сам(а)", "glass", Rect2(28, 296, w - 56, 80), null, UI.T_BODY, -1.0, false)
	no.name = "No"
	no.set_meta("ux_role", "secondary")
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
	var h: = 300.0 + (138.0 if not jam.is_empty() else 0.0) + (34.0 if bool(res.get("offer_assist", false)) else 0.0) + 236.0
	# a bottom sheet: «Ещё раз» lands under the thumb, in the bottom third (UX_RULES §6.1)
	var p: = UI.rbox("graphite", Rect2((vs.x - w) * 0.5, maxf(120.0, vs.y - h - 24.0), w, h), 12, 2, 14)
	if stone:
		p.colors(Color(0.27, 0.27, 0.3, 0.97), Color(0.13, 0.13, 0.15, 0.98))
		p.borders(Color("d8d2c2"), Color("6f6a5e"))
		PFx.fog(p, Rect2(10, 10, w - 20, h * 0.45), 0.4)
	else:
		p.colors(Rules.C.night700, Rules.C.night800)
		p.borders(Rules.C.gold_line, Rules.C.gold_line)
	p.name = "Panel"
	root.add_child(p)
	UI.pop_in(p, 0.0, 0.85)
	V9Feel.fail(null, "deny")
	var title: = "Пик не сдался" if n.peak else ("Легенда устояла" if n.legend else "Не вышло")
	var t: = UI.center_label(UI.title(title, UI.T_H2, Color("fff3e6"), Color(0.2, 0.05, 0.1)), Rect2(0, 22, w, 60))
	p.add_child(t)
	var host: = State.host_of_chapter(State.gchapter(i))
	var av: = V8Art.emotion_avatar(host, "sad", Rect2(w * 0.5 - 70, 92, 140, 140), "gold")
	p.add_child(av)
	var y: = 246.0
	var cheer: = "Ещё чуть-чуть. Вершины берут упорством." if stone else "Лоток переполнился. Попробуем ещё раз?"
	var cl: = UI.center_label(UI.label(cheer, UI.T_BODY, Color("f2e6d8"), Color(0.08, 0.03, 0.05), 3), Rect2(30, y, w - 60, 40))
	p.add_child(cl)
	y += 54.0
	if not jam.is_empty():
		var jb: = UI.rbox("graphite", Rect2(28, y, w - 56, 124), 22, 2, 10)
		jb.colors(Color(0.32, 0.12, 0.16, 0.9), Color(0.16, 0.06, 0.08, 0.95))
		jb.borders(Color("ffb3c0"), Color("7a2a3a"))
		jb.name = "JamBlock"
		p.add_child(jb)
		# plain words instead of a new term («место затора», UX_RULES §4.4)
		var jt: = UI.label("Где лоток начал копиться", UI.T_BODY, Color("ffd2da"), Color(0.15, 0.03, 0.06), 3, "body", 900)
		jt.position = Vector2(18, 6)
		jt.size = Vector2(w - 230, 30)
		Common.fit_line(jt, w - 230, UI.T_SMALL)
		jb.add_child(jt)
		var jl: = UI.label(str(jam.get("text", "")), UI.T_SMALL, Color("f6e6ea"))
		jl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		jl.position = Vector2(18, 36)
		jl.size = Vector2(w - 230, 84)
		jb.add_child(jl)
		var sb: = JButton.make("Показать", "glass", Rect2(w - 56 - 176, 22, 162, 80), null, UI.T_BODY, -1.0, false)
		sb.name = "ShowJam"
		sb.set_meta("ux_role", "tertiary")
		sb.pressed.connect(func():
			_close(root)
			if on_show_jam.is_valid():
				on_show_jam.call(jam))
		jb.add_child(sb)
		y += 138.0
	if bool(res.get("offer_assist", false)):
		var al: = UI.center_label(UI.label("%s может переложить стол удобнее" % Rules.host_name(host), UI.T_SMALL, Color("b9f0d6")), Rect2(30, y, w - 60, 30))
		p.add_child(al)
		y += 34.0
	# «Ещё раз» — the main button at full width (≥ 440×104); «На карту» (+ «Пройти дальше») quiet under it
	var has_bypass: = bool(res.get("bypass", false))
	var retry: = JButton.make("Ещё раз", "pink" if not stone else "gold", Rect2(28, h - 216, w - 56, 104), null, UI.T_H2)
	retry.name = "Retry"
	retry.set_meta("ux_role", "primary")
	var bw2: = (w - 72.0) * 0.5 if has_bypass else w - 56.0
	var tomap: = JButton.make("На карту", "glass", Rect2(28, h - 100, bw2, 80), null, UI.T_BODY, -1.0, false)
	tomap.name = "ToMap"
	tomap.set_meta("ux_role", "secondary")
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
	if has_bypass:
		var bb: = JButton.make("Пройти дальше", "glass", Rect2(44 + bw2, h - 100, bw2, 80), null, UI.T_BODY, -1.0, false)
		bb.name = "BypassBtn"
		bb.set_meta("ux_role", "secondary")
		bb.pressed.connect(func():
			_close(root)
			State.bypass_legend(i)
			if main.has_method("toast"):
				main.toast("Путь открыт дальше. Лавр ждёт победы здесь")
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

static func _sheet(main, name: String, title: String, top: float) -> Array:
	var vs: = _vs(main)
	var root: = _root(main, name)
	var w: = minf(vs.x - 24.0, 700.0)
	var h: = vs.y - top - 20.0
	var p: = Control.new()
	p.position = Vector2((vs.x - w) * 0.5, top)
	p.size = Vector2(w, h)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.name = "Sheet"
	root.add_child(p)
	var bg: = UI.rbox("graphite", Rect2(Vector2.ZERO, p.size), 12, 2, 8)
	bg.colors(Rules.C.night700, Rules.C.night800)
	bg.borders(Rules.C.gold_line, Rules.C.gold_line)
	p.add_child(bg)
	# title on the left field (UX_RULES §6.3), the quiet «×» (hit 80 px)
	var tl: = UI.title(title, UI.T_H2, Color("fff3e6"), Color(0.14, 0.05, 0.08))
	tl.position = Vector2(28, 20)
	tl.size = Vector2(w - 130, 48)
	tl.name = "Title"
	p.add_child(tl)
	var xb: = JButton.make("", "glass", Rect2(w - 92, 8, 80, 80), null, UI.T_BODY, 40.0, false)
	xb.add_child(V8Art.rect(V8Art.icon("close"), Rect2(23, 23, 34, 34)))
	xb.pressed.connect(func(): _close(root))
	xb.name = "Close"
	xb.set_meta("ux_role", "tertiary")
	p.add_child(xb)
	(root.get_node("Dim") as Control).gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			_close(root))
	p.position.y = vs.y
	p.create_tween().tween_property(p, "position:y", top, 0.3).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	return [root, p, w, h]


# the arcs shown in the list: every released arc + the first closed one as the single teaser
static func arcs_listed() -> Array:
	var out: = []
	for a in Gen.WORLDS:
		out.append(a)
		if not State.arc_released(a):
			break
	return out


static func arcs_sheet(main, map) -> Control:
	var arcs: = arcs_listed()
	var ch: = 196.0
	var vs: = _vs(main)
	var top: = maxf(120.0, vs.y - 20.0 - (100.0 + arcs.size() * (ch + 16.0) + 10.0))
	var sh: Array = _sheet(main, "PathArcs", "Арки Пути", top)
	var root: Control = sh[0]
	var p: Control = sh[1]
	var w: float = sh[2]
	var h: float = sh[3]
	var sc: = ScrollContainer.new()
	sc.position = Vector2(20, 96)
	sc.size = Vector2(w - 40, h - 106)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	p.add_child(sc)
	var list: = Control.new()
	var cw: = w - 40.0
	list.custom_minimum_size = Vector2(cw, arcs.size() * (ch + 16.0))
	sc.add_child(list)
	var cur_arc: = State.arc_of(State.current())
	for k in arcs.size():
		var a: int = arcs[k]
		var rel: = State.arc_released(a)
		var card: = Control.new()
		card.position = Vector2(0, k * (ch + 16.0))
		card.size = Vector2(cw, ch)
		card.pivot_offset = card.size * 0.5
		card.mouse_filter = Control.MOUSE_FILTER_PASS
		card.name = "Arc%d" % (a + 1)
		# the arc with the current level is the one to go to; the closed teaser is content, not an action
		card.set_meta("ux_role", ("primary" if a == cur_arc else "secondary") if rel else "content")
		list.add_child(card)
		var cov: = Rules.cover(a)
		if cov:
			var art: = Common.card_art(cov, Rect2(0, 0, cw, ch), Vector2(0.5, 0.5), 1.0, 12.0)
			if not rel:
				# silhouette: the cover as a dark shape, no detail, no lock and no timer
				art.modulate = Color(0.09, 0.08, 0.12)
			card.add_child(art)
		else:
			var ph: = UI.rbox("graphite", Rect2(0, 0, cw, ch), 12, 2, 10)
			ph.colors(Rules.C.night800, Rules.C.night900)
			card.add_child(ph)
		var fr: = UI.rbox("graphite", Rect2(0, 0, cw, ch), 12, 2, 10)
		fr.colors(Color(0, 0, 0, 0), Color(0, 0, 0, 0))
		fr.borders(Rules.C.gold500 if a == map.arc else Rules.C.gold_line, Rules.C.gold_line)
		card.add_child(fr)
		var ff: = Common.floor_fade(card, 60, ch, Color(0.05, 0.03, 0.06), 0.9)
		ff.size.x = cw
		var t1: = UI.label("Арка %d · %s" % [a + 1, Rules.ARC_TITLES[a]], UI.T_H3, Color("fff3e6") if rel else Rules.C.paper300, Color(0.12, 0.04, 0.07), 4, "title", 900)
		t1.position = Vector2(20, ch - 80)
		t1.size = Vector2(cw - 40, 38)
		Common.fit_line(t1, cw - 40, UI.T_BODY)
		card.add_child(t1)
		var sub: = ""
		if rel:
			sub = State.arc_subtitle(a)
			if State.legend_rec(a).won:
				sub += " · лавр"
		else:
			sub = "Откроется: с обновлением игры"
		var sl: = UI.label(sub, UI.T_SMALL, Color("eadccb") if rel else Rules.C.paper500, Color(0.06, 0.03, 0.05), 3)
		sl.position = Vector2(22, ch - 42)
		sl.size = Vector2(cw - 44, 28)
		card.add_child(sl)
		if a == map.arc:
			var tag: = Common.chip(card, null, "Ты здесь", Rect2(cw - 150, 14, 136, 38), "plum", UI.T_SMALL)
			tag.name = "Here"
		card.gui_input.connect(func(e):
			if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed:
				if not rel:
					V9Feel.deny(card)
					if main.has_method("toast"):
						main.toast("Откроется: с обновлением игры")
					return
				V9Feel.press(card)
				_close(root)
				map.switch_arc(a))
	return root


# ------------------------------------------------------------------ help («?» of the map)

# the Path words the player has met so far (UX_RULES §3.5 order), at most 4 lines — the sheet stays under 60 words
static func help_entries() -> Array:
	var ids: = []
	if State.unlocked() >= Rules.BOOST_FROM:
		ids.append("path.flame")
	ids.append("path.chests")
	if State.unlocked() >= Rules.PEAKS_FROM:
		ids.append("path.peak")
	ids.append("path.legend")
	if ids.size() < 4:
		ids.append("path.jam")
	var out: = []
	for e in Rules.GLOSSARY:
		if str(e.id) in ids:
			out.append(e)
	return out


static func help_sheet(main, map) -> Control:
	var entries: = help_entries()
	var vs: = _vs(main)
	var rows_h: = 0.0
	var w0: = minf(vs.x - 24.0, 700.0) - 56.0 - 64.0
	for e in entries:
		rows_h += 30.0 + UI.font("body", 800).get_multiline_string_size(str(e.why), HORIZONTAL_ALIGNMENT_LEFT, w0, UI.T_SMALL).y + 18.0
	var top: = maxf(120.0, vs.y - 20.0 - (104.0 + rows_h + 24.0))
	var sh: Array = _sheet(main, "PathHelp", "Как устроен Путь", top)
	var p: Control = sh[1]
	var w: float = sh[2]
	var y: = 100.0
	var ic: = {"path.flame": "flame", "path.chests": "star_chest", "path.peak": "peak", "path.legend": "crown", "path.jam": ""}
	for e in entries:
		var row: = Control.new()
		row.position = Vector2(28, y)
		row.size = Vector2(w - 56, 40)
		row.name = "Help_" + str(e.id).get_slice(".", 1)
		p.add_child(row)
		var t: = Rules.icon(str(ic.get(str(e.id), "")))
		if t:
			row.add_child(UI.tex(t, Rect2(0, 0, 52, 52)))
		var nm: = UI.label(str(e.name), UI.T_BODY, Rules.C.gold300, Color(0.08, 0.04, 0.05), 3, "body", 900)
		nm.position = Vector2(64, 0)
		nm.size = Vector2(w - 56 - 64, 30)
		row.add_child(nm)
		var why: = UI.label(str(e.why), UI.T_SMALL, Rules.C.paper100)
		why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		why.position = Vector2(64, 30)
		why.size = Vector2(w0, 10)
		row.add_child(why)
		y += 30.0 + UI.font("body", 800).get_multiline_string_size(str(e.why), HORIZONTAL_ALIGNMENT_LEFT, w0, UI.T_SMALL).y + 18.0
	return sh[0]


# ------------------------------------------------------------------ legend bypass

static func bypass(main, map, i: int) -> void:
	Common.confirm(main, "Пройти дальше без лавра?", "Путь откроется дальше, мимо Легенды. Лавр «Легенда арки %d» даётся только за победу здесь — корона подождёт." % (State.arc_of(i) + 1),
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
