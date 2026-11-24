extends Control

# Screen "letters" (main.SCREENS, 0.9 «Письма», docs/0.9-spec.md §C): the heroines' letters, newest first, then the
# 0.7/0.8 notes (date notes, «открыта сцена» notices — tap opens her room). A letter opens as a popup: her portrait,
# the subject, the letter on paper, her signature and P.S., and two replies — one tap sends it, she answers and
# her affection grows (V9Letters.REPLY_AFF, once per letter).
# args: {open: letter id}. dev_act: "open" (newest letter), "reply0" / "reply1", "close", "back".

var main
var W: = 720.0
var H: = 1280.0
var scroll: ScrollContainer
var list: VBoxContainer
var cw: = 672.0
var pop: RBox
var pop_id: = -1

const CARD_H: = 182.0
const PAPER_TOP: = Color("f8eedc")
const PAPER_BOTTOM: = Color("ecdabd")
const PAPER_INK: = Color("3a2416")
const PAPER_MUTED: = Color("7a5a44")


func build(m, args: Dictionary) -> void:
	main = m
	W = size.x
	H = size.y
	main.show_chrome(true, true)
	Sfx.music("menu")
	V9Letters.install()
	V9Letters.tick()
	Common.backdrop(self, "menu", size, 1.0, 0.62, Color(1, 0.95, 0.96), Vector2(0.5, 0.4))
	Common.vignette(self, size, Color(0.06, 0.04, 0.08), 0.6)
	V8Header.make(self, main, "Письма", main.back)
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
	Common.scroll_fade(scroll, list, 90.0, 0.4)
	Common.edge_shade(self, Rect2(0, top - 6, W, 40), 1, Color(0.07, 0.05, 0.07), 0.9, 0.3)
	Common.edge_shade(self, Rect2(0, bottom - 60, W, 60), -1, Color(0.07, 0.05, 0.07), 0.95, 0.35)
	_fill()
	if args.has("open"):
		open_letter.call_deferred(int(args.open))


func _fill() -> void:
	for c in list.get_children():
		list.remove_child(c)
		c.queue_free()
	_spacer(10)
	var letters: = V9Letters.list()
	var legacy: = V9Letters.legacy_entries()
	if letters.is_empty() and legacy.is_empty():
		_empty()
		return
	if not letters.is_empty():
		_summary(letters)
	var i: = 0
	for l in letters:
		var c: = _card(l)
		list.add_child(c)
		_appear(c, 0.04 + mini(i, 6) * 0.06)
		i += 1
	if not legacy.is_empty():
		_section("Записки и сцены")
		for e in legacy:
			list.add_child(_legacy_row(e))
		# the old notes count as seen once the list has been shown (0.8 rule)
		V9Letters.mark_legacy_seen()
		G.save()
	_spacer(60)


# a row of the list fades in with a small settle (the VBox owns its position, so only alpha and scale move)
func _appear(c: Control, delay: float) -> void:
	c.modulate.a = 0.0
	c.scale = Vector2.ONE * 0.96
	var t: = c.create_tween().set_parallel()
	t.tween_property(c, "modulate:a", 1.0, 0.28).set_delay(delay)
	t.tween_property(c, "scale", Vector2.ONE, 0.42).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _spacer(h: float) -> void:
	var s: = Control.new()
	s.custom_minimum_size = Vector2(cw, h)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	list.add_child(s)


func _summary(letters: Array) -> void:
	var n_new: = letters.filter(func(l): return not bool(l.get("read", false))).size()
	var n_rep: = letters.filter(func(l): return int(l.get("reply", -1)) < 0).size()
	var parts: = []
	if n_new > 0:
		parts.append("новых: %d" % n_new)
	if n_rep > 0:
		parts.append("ждут ответа: %d" % n_rep)
	var s: = ("Писем: %d · " % letters.size()) + (" · ".join(parts) if not parts.is_empty() else "на всё ответил")
	var row: = Control.new()
	row.custom_minimum_size = Vector2(cw, 34)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l: = UI.center_label(UI.label(s, 18, Color("ffe7c4"), UI.DARK, 4, "body", 900), Rect2(0, 0, cw, 30))
	row.add_child(l)
	list.add_child(row)


func _section(t: String) -> void:
	var row: = Control.new()
	row.custom_minimum_size = Vector2(cw, 56)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ln: = ColorRect.new()
	ln.color = Color(0.91, 0.77, 0.49, 0.45)
	ln.position = Vector2(8, 38)
	ln.size = Vector2(cw - 16, 2)
	row.add_child(ln)
	var l: = UI.label(t, 26, Color("ffe7a6"), UI.DARK, 4, "title", 800)
	l.position = Vector2(8, 2)
	l.size = Vector2(cw - 16, 34)
	row.add_child(l)
	list.add_child(row)


# one letter in the list: emotion portrait (wax seal while unread), name + time, subject (Playfair), two lines of
# the letter, event tag and reply state
func _card(l: Dictionary) -> Control:
	var v: = V9Letters.view(l)
	var h: = str(l.h)
	var unread: = not bool(l.get("read", false))
	var replied: = int(l.get("reply", -1)) >= 0
	var c: = Control.new()
	c.custom_minimum_size = Vector2(cw, CARD_H)
	c.size = Vector2(cw, CARD_H)
	c.pivot_offset = c.size * 0.5
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	c.name = "Letter%d" % int(l.id)
	var bg: = UI.rbox("glass", Rect2(0, 0, cw, CARD_H), 26, 3, 10)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if unread:
		bg.borders(Color("ffe7a6"), Color("c58a2c"))
	c.add_child(bg)
	var hc: Color = G.HEROES[h].color
	var accent: = ColorRect.new()
	accent.color = Color(hc, 0.85 if unread else 0.35)
	accent.position = Vector2(0, 26)
	accent.size = Vector2(5, CARD_H - 52)
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(accent)
	var av: = V8Art.emotion_avatar(h, v.emo, Rect2(18, 22, 118, 118), "gold" if unread else "glass")
	c.add_child(av)
	if unread:
		var seal: = UI.rbox("red", Rect2(104, 108, 40, 40), 20, 2, 6)
		seal.colors(Color("d9566f"), Color("8e2236")).borders(Color("ffb3c2"), Color("5a1020"))
		seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
		seal.add_child(V8Art.rect(V8Art.icon("heart"), Rect2(6, 6, 28, 28)))
		c.add_child(seal)
	var x0: = 156.0
	var nm: = UI.label(G.HEROES[h].name, 21, hc.lerp(Color.WHITE, 0.4), UI.DARK, 3, "body", 900)
	nm.position = Vector2(x0, 14)
	nm.size = Vector2(300, 28)
	c.add_child(nm)
	var tm: = UI.label(V9Letters.ago(int(l.get("t", 0))), 16, UI.MUTED, UI.DARK, 2, "body", 800)
	tm.position = Vector2(cw - 196, 16)
	tm.size = Vector2(176, 24)
	tm.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	c.add_child(tm)
	var sj: = UI.label(v.subj, 26, UI.INK, UI.DARK, 3, "title", 800)
	sj.position = Vector2(x0, 40)
	sj.size = Vector2(cw - x0 - 20, 36)
	sj.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	c.add_child(sj)
	var pv: = UI.label(str(v.body).replace("\n", " "), 17, Color("d8ccbd"), UI.DARK, 2, "body", 800)
	pv.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pv.position = Vector2(x0, 80)
	pv.size = Vector2(cw - x0 - 20, 46)
	pv.max_lines_visible = 2
	pv.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	c.add_child(pv)
	var tag: String = v.tag
	var tw: = UI.font("body", 900).get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 26.0
	var tg: = UI.rbox("plum", Rect2(x0, CARD_H - 44, tw, 30), 15, 2, 4)
	tg.borders(Color("ffe7a6"), Color("a8742a"))
	tg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tg.add_child(UI.center_label(UI.label(tag, 16, Color("ffe7a6"), UI.DARK, 2, "body", 900), Rect2(0, 0, tw, 30)))
	c.add_child(tg)
	var st_txt: = "Ответ отправлен" if replied else "Ждёт ответа"
	var sw: = UI.font("body", 900).get_string_size(st_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 30.0
	var sc: = UI.rbox("mint" if replied else "pink", Rect2(cw - sw - 18, CARD_H - 44, sw, 30), 15, 2, 4)
	sc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sc.add_child(UI.center_label(UI.label(st_txt, 16, Color.WHITE, Color("163a2d") if replied else Color("5a1830"), 3, "body", 900), Rect2(0, 0, sw, 30)))
	c.add_child(sc)
	if not replied:
		sc.pivot_offset = Vector2(sw, 15) * 0.5
		var t: = sc.create_tween().set_loops()
		t.tween_interval(2.2)
		t.tween_property(sc, "scale", Vector2.ONE * 1.07, 0.18).set_trans(Tween.TRANS_SINE)
		t.tween_property(sc, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var id: = int(l.id)
	c.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			V9Feel.press(c, "pop")
			open_letter(id))
	return c


func _legacy_row(e: Dictionary) -> Control:
	var rh: = 120.0
	var c: = Control.new()
	c.custom_minimum_size = Vector2(cw, rh)
	c.size = Vector2(cw, rh)
	c.pivot_offset = c.size * 0.5
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	var bg: = UI.rbox("glass", Rect2(0, 0, cw, rh), 22, 3, 8)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if e.new:
		bg.borders(Color("ffe7a6"), Color("c58a2c"))
	c.add_child(bg)
	c.add_child(Common.avatar(e.h, Rect2(14, 16, 88, 88), "gold" if e.new else "glass"))
	var nm: = UI.label(G.HEROES[e.h].name, 20, Color("ffd2de"), UI.DARK, 3, "body", 900)
	nm.position = Vector2(120, 10)
	nm.size = Vector2(300, 26)
	c.add_child(nm)
	var sub: = UI.label(str(e.sub), 16, UI.MUTED, UI.DARK, 2, "body", 800)
	sub.position = Vector2(cw - 236, 12)
	sub.size = Vector2(216, 22)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	c.add_child(sub)
	var tx: = UI.label(str(e.text), 18, UI.INK, UI.DARK, 2, "body", 800)
	tx.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tx.position = Vector2(120, 40)
	tx.size = Vector2(cw - 140, 70)
	tx.max_lines_visible = 3
	tx.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	c.add_child(tx)
	var hh: String = e.h
	c.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			V9Feel.press(c, "pop")
			main.go("room", {"hero": hh}))
	return c


func _empty() -> void:
	var box: = Control.new()
	box.custom_minimum_size = Vector2(cw, 560)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	list.add_child(box)
	var p: = UI.rbox("glass", Rect2(20, 40, cw - 40, 500), 30, 3, 12)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.borders(Color("ffe7a6"), Color("a8742a"))
	box.add_child(p)
	var ic: = V8Art.rect(V8Art.icon("letters"), Rect2((cw - 40) * 0.5 - 80, 34, 160, 160))
	p.add_child(ic)
	ic.pivot_offset = Vector2(80, 80)
	var t: = ic.create_tween().set_loops()
	t.tween_property(ic, "rotation", 0.06, 1.4).set_trans(Tween.TRANS_SINE)
	t.tween_property(ic, "rotation", -0.06, 1.4).set_trans(Tween.TRANS_SINE)
	p.add_child(UI.center_label(UI.label("Писем пока нет", 32, UI.INK, UI.DARK, 4, "title", 800), Rect2(20, 210, cw - 80, 48)))
	var tx: = UI.label("Героини пишут после первой победы дня, нового рекорда комбо и нового ранга. А если ты долго не заходишь — тоже напишут.", 19, Color("ddd2c4"), UI.DARK, 2, "body", 800)
	tx.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tx.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tx.position = Vector2(40, 270)
	tx.size = Vector2(cw - 120, 110)
	p.add_child(tx)
	var b: = JButton.make("Сесть за стол", "pink", Rect2((cw - 40) * 0.5 - 170, 396, 340, 84), null, 28)
	b.pressed.connect(func(): main.go("levels", {"select": mini(int(G.S.unlocked), G.LEVELS.size()) - 1}))
	p.add_child(b)


# ------------------------------------------------------------------ one letter

func open_letter(id: int) -> void:
	var l: = V9Letters.find(id)
	if l.is_empty():
		return
	if pop and is_instance_valid(pop):
		Common.close_popup(pop)
	var first_open: = not bool(l.get("read", false))
	V9Letters.mark_read(id)
	G.save()
	var v: = V9Letters.view(l)
	var h: = str(l.h)
	var pw: = 660.0
	var tw: = pw - 48.0 - 56.0
	var body_font: = UI.font("body", 800)
	var flags: = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	var subj_h: = UI.font("title", 800).get_multiline_string_size(v.subj, HORIZONTAL_ALIGNMENT_LEFT, pw - 210, 30, -1, flags).y
	var body_h: = body_font.get_multiline_string_size(v.body, HORIZONTAL_ALIGNMENT_LEFT, tw, 21, -1, flags).y * 1.08
	var ps_h: = body_font.get_multiline_string_size(v.ps, HORIZONTAL_ALIGNMENT_LEFT, tw, 18, -1, flags).y
	var paper_h: = 28.0 + body_h + 16.0 + 40.0 + 10.0 + ps_h + 26.0
	var head_h: = maxf(150.0, 58.0 + subj_h + 46.0)
	var reply_h: = 236.0
	var ph: = head_h + paper_h + reply_h + 30.0
	pop = Common.popup(main, G.HEROES[h].name, ph, "cream", pw)
	pop_id = id
	var root: Control = pop.get_meta("root")
	root.set_meta("on_close", func():
		pop_id = -1
		if is_inside_tree():
			_fill())
	# head: emotion portrait, subject, event tag
	var av: = V8Art.emotion_avatar(h, v.emo, Rect2(30, 52, 132, 132), "gold")
	pop.add_child(av)
	UI.pop_in(av, 0.12, 0.7)
	var sj: = UI.label(v.subj, 30, UI.INK, UI.DARK, 4, "title", 800)
	sj.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sj.position = Vector2(184, 58)
	sj.size = Vector2(pw - 210, subj_h + 4)
	pop.add_child(sj)
	var tag: String = v.tag + " · " + V9Letters.ago(int(l.get("t", 0)))
	var tgw: = body_font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 28.0
	var tg: = UI.rbox("plum", Rect2(184, 66 + subj_h, minf(tgw, pw - 210), 30), 15, 2, 4)
	tg.borders(Color("ffe7a6"), Color("a8742a"))
	tg.add_child(UI.center_label(UI.label(tag, 16, Color("ffe7a6"), UI.DARK, 2, "body", 900), Rect2(0, 0, minf(tgw, pw - 210), 30)))
	pop.add_child(tg)
	# the letter on paper
	var py: = head_h + 26.0
	var paper: = UI.rbox("gold", Rect2(24, py, pw - 48, paper_h), 18, 3, 10)
	paper.colors(PAPER_TOP, PAPER_BOTTOM).borders(Color("f3d99a"), Color("b88a4a"))
	paper.set_param("shadow_color", Color(0, 0, 0, 0.35))
	pop.add_child(paper)
	var hc: Color = G.HEROES[h].color
	var rule: = ColorRect.new()
	rule.color = Color(hc.darkened(0.25), 0.55)
	rule.position = Vector2(28, 14)
	rule.size = Vector2(pw - 48 - 56, 2)
	paper.add_child(rule)
	var bd: = UI.label(v.body, 21, PAPER_INK, Color(0, 0, 0, 0), 0, "body", 800)
	bd.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bd.position = Vector2(28, 26)
	bd.size = Vector2(tw, body_h + 4)
	bd.add_theme_constant_override("line_spacing", 2)
	paper.add_child(bd)
	var sg: = UI.label("— " + str(v.sign), 28, hc.darkened(0.45), Color(0, 0, 0, 0), 0, "title", 800)
	sg.position = Vector2(28, 26 + body_h + 12)
	sg.size = Vector2(tw, 40)
	sg.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	paper.add_child(sg)
	var ps: = UI.label(v.ps, 18, PAPER_MUTED, Color(0, 0, 0, 0), 0, "body", 800)
	ps.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ps.position = Vector2(28, 26 + body_h + 60)
	ps.size = Vector2(tw, ps_h + 4)
	paper.add_child(ps)
	paper.modulate.a = 0.0
	paper.create_tween().tween_property(paper, "modulate:a", 1.0, 0.3).set_delay(0.08)
	# replies
	var ry: = py + paper_h + 22.0
	if int(l.get("reply", -1)) >= 0:
		_answer(pop, l, v, ry, false)
	else:
		var cap: = UI.label("Твой ответ", 18, Color("ffe7a6"), UI.DARK, 3, "body", 900)
		cap.position = Vector2(30, ry - 4)
		cap.size = Vector2(300, 24)
		cap.name = "ReplyCap"
		pop.add_child(cap)
		var btns: Array[JButton] = []
		for i in 2:
			var b: = JButton.make(str(v.replies[i]), "glass", Rect2(24, ry + 26 + i * 86, pw - 48, 76), null, 21)
			b.name = "Reply%d" % i
			pop.add_child(b)
			UI.slide_in(b, Vector2(0, 16), 0.15 + i * 0.07, 0.3)
			btns.append(b)
		for i in 2:
			var ii: = i
			btns[i].pressed.connect(func(): _send(l, v, ii, btns, ry))
	if first_open:
		V9Feel.sound("flip", 1.05, -4)


func _send(l: Dictionary, v: Dictionary, i: int, btns: Array[JButton], ry: float) -> void:
	if int(l.get("reply", -1)) >= 0 or pop == null or not is_instance_valid(pop):
		return
	V9Letters.reply(int(l.id), i)
	for j in btns.size():
		var b: = btns[j]
		b.disabled = true
		var t: = b.create_tween()
		t.tween_property(b, "modulate:a", 0.0, 0.2).set_delay(0.0 if j != i else 0.12)
		t.tween_callback(b.queue_free)
	var cap: = pop.get_node_or_null("ReplyCap")
	if cap:
		cap.queue_free()
	_answer(pop, l, v, ry, true)


# what she answered: the player's reply in small print, then her answer in a bubble next to her shy / happy face;
# `fresh`: just sent — +affection float, hearts, success
func _answer(p: RBox, l: Dictionary, v: Dictionary, ry: float, fresh: bool) -> void:
	var h: = str(l.h)
	var i: = int(l.reply)
	var pw: = p.size.x
	var mine: = UI.label("Ты: «%s»" % str(v.replies[i]), 17, Color("ddd2c4"), UI.DARK, 2, "body", 800)
	mine.position = Vector2(30, ry - 4)
	mine.size = Vector2(pw - 60, 24)
	mine.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	p.add_child(mine)
	var emo: = "shy" if i == 0 else "happy"
	var av: = V8Art.emotion_avatar(h, emo, Rect2(24, ry + 30, 104, 104), "pink")
	p.add_child(av)
	var bw: = pw - 48 - 120.0
	var b: = UI.rbox("cream", Rect2(140, ry + 30, bw, 104), 22, 3, 8)
	b.set_param("border_top", Color("e8c9a0")).set_param("border_bottom", Color("a8697a"))
	p.add_child(b)
	var t: = UI.label(str(v.answers[i]), 20, UI.INK, UI.DARK, 2, "body", 800)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	t.position = Vector2(18, 8)
	t.size = Vector2(bw - 36, 88)
	b.add_child(t)
	var aff: = UI.label("+%d симпатии · %s" % [V9Letters.REPLY_AFF, G.HEROES[h].name], 17, Color("ffd2de"), UI.DARK, 3, "body", 900)
	aff.position = Vector2(140, ry + 140)
	aff.size = Vector2(bw, 24)
	aff.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	p.add_child(aff)
	if not fresh:
		return
	for n in [av, b]:
		n.pivot_offset = n.size * 0.5
		UI.pop_in(n, 0.18, 0.7)
	aff.modulate.a = 0.0
	aff.create_tween().tween_property(aff, "modulate:a", 1.0, 0.25).set_delay(0.45)
	V9Feel.success(av, "sparkle", 0.8)
	var at: Vector2 = p.global_position + Vector2(76, ry + 82)
	Fx.float_text(main.overlay, p.global_position + Vector2(pw - 100, ry + 120), "+%d ♥" % V9Letters.REPLY_AFF, Color("ffd0e0"), 40)
	if V9Feel.can_fx():
		Fx.burst(main.overlay, at, "heart", maxi(4, int(round(14 * V9Feel.fx_scale()))))
	Sfx.voice_started.emit(h, str(v.answers[i]), minf(0.4 + str(v.answers[i]).length() * 0.045, 3.0))


func dev_act(a: String) -> void:
	match a:
		"open":
			var ls: = V9Letters.list()
			if not ls.is_empty():
				open_letter(int(ls[0].id))
		"open_unreplied":
			for l in V9Letters.list():
				if int(l.get("reply", -1)) < 0:
					open_letter(int(l.id))
					return
		"open_replied":
			for l in V9Letters.list():
				if int(l.get("reply", -1)) >= 0:
					open_letter(int(l.id))
					return
		"reply0", "reply1":
			if pop and is_instance_valid(pop):
				var b = pop.get_node_or_null("Reply%s" % a.substr(5))
				if b is JButton:
					(b as JButton).pressed.emit()
		"close":
			if pop and is_instance_valid(pop):
				Common.close_popup(pop)
		"back":
			main.android_back()
		"down":
			scroll.scroll_vertical = 100000
