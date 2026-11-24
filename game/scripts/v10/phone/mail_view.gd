class_name V10MailView
extends Control

# «Почта» tab (§Р8 п.4): the 0.9 letters (V9Letters — data, rules and replies unchanged) shown in the phone's style:
# rows with her face, subject, two-line preview, event tag and «Ждёт ответа»; a letter opens as a page that slides
# in from the right: paper, her signature in handwriting, P.S., two reply pills → her answer bubble.
# The 0.7/0.8 notes («Записки и сцены») stay in the full Letters screen (main.go("letters")) behind a link row.

signal open_legacy

const P: = preload("res://scripts/v10/phone/phone.gd")
const PUI: = preload("res://scripts/v10/phone/phone_ui.gd")

const ROW_H: = 150.0
const PAPER_A: = Color("f8eedc")
const PAPER_B: = Color("ecdabd")
const PAPER_INK: = Color("3a2416")
const PAPER_MUTED: = Color("7a5a44")

var W: = 600.0
var H: = 900.0
var scroll: ScrollContainer
var list: VBoxContainer
var page: Control = null


func build(w: float, h: float) -> void:
	W = w
	H = h
	size = Vector2(W, H)
	name = "MailView"
	clip_contents = true
	scroll = ScrollContainer.new()
	scroll.size = size
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	add_child(scroll)
	list = VBoxContainer.new()
	list.custom_minimum_size = Vector2(W, 0)
	list.add_theme_constant_override("separation", 12)
	scroll.add_child(list)
	refresh()


func refresh() -> void:
	for c in list.get_children():
		c.queue_free()
	var sp: = Control.new()
	sp.custom_minimum_size = Vector2(W, 6)
	list.add_child(sp)
	var letters: = V9Letters.list()
	if letters.is_empty():
		list.add_child(_empty())
	var i: = 0
	for l in letters:
		var r: = _row(l)
		list.add_child(r)
		PUI.pop_in(r, 0.04 + 0.05 * mini(i, 6), 0.92, 0.34)
		i += 1
	if not V9Letters.legacy_entries().is_empty():
		list.add_child(_legacy_link())


func _empty() -> Control:
	var c: = Control.new()
	c.custom_minimum_size = Vector2(W, 260)
	var l: = PUI.label("Писем пока нет.\nПосле первой победы дня она обязательно напишет.", 22, PUI.MUTED, PUI.body(800))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = Vector2(40, 90)
	l.size = Vector2(W - 80, 120)
	c.add_child(l)
	return c


func _row(l: Dictionary) -> Control:
	var v: = V9Letters.view(l)
	var h: = str(l.h)
	var hc: = P.hero_color(h)
	var unread: = not bool(l.get("read", false))
	var replied: = int(l.get("reply", -1)) >= 0
	var c: = Control.new()
	c.name = "Letter%d" % int(l.id)
	c.custom_minimum_size = Vector2(W, ROW_H)
	c.size = Vector2(W, ROW_H)
	c.pivot_offset = c.size * 0.5
	c.add_child(PUI.panel(Rect2(12, 0, W - 24, ROW_H), PUI.box(Color(1, 1, 1, 0.075 if unread else 0.04), 24, 1.5 if unread else 0.0, Color(PUI.GOLD, 0.6))))
	var acc: = ColorRect.new()
	acc.color = Color(hc, 0.9 if unread else 0.35)
	acc.position = Vector2(12, 26)
	acc.size = Vector2(4, ROW_H - 52)
	acc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(acc)
	c.add_child(V8Art.emotion_avatar(h, v.emo, Rect2(28, 22, 96, 96), "gold" if unread else "glass"))
	var x0: = 138.0
	var nm: = PUI.label(P.hero_name(h), 30 if PUI.has_caveat() else 24, hc.lerp(Color.WHITE, 0.45), PUI.hand())
	nm.position = Vector2(x0, 8)
	nm.size = Vector2(240, 36)
	c.add_child(nm)
	var tm: = PUI.label(V9Letters.ago(int(l.get("t", 0))), 16, PUI.MUTED, PUI.body(800))
	tm.position = Vector2(W - 200, 14)
	tm.size = Vector2(170, 24)
	tm.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	c.add_child(tm)
	var sj: = PUI.label(str(v.subj), 23, PUI.TEXT, PUI.body(900))
	sj.position = Vector2(x0, 44)
	sj.size = Vector2(W - x0 - 36, 32)
	sj.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	sj.size = Vector2(W - x0 - 36, 32)
	PUI.ellipsize(sj, W - x0 - 36)
	c.add_child(sj)
	var pv: = PUI.label(str(v.body).replace("\n", " "), 17, Color("cfc2b4"), PUI.body(700))
	pv.position = Vector2(x0, 78)
	pv.size = Vector2(W - x0 - 36, 24)
	pv.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	pv.size = Vector2(W - x0 - 36, 24)
	PUI.ellipsize(pv, W - x0 - 36)
	c.add_child(pv)
	var st_txt: = "Ответ отправлен" if replied else "Ждёт ответа"
	var sl: = PUI.label(("✓ " if replied else "● ") + st_txt + ("  ·  " + str(v.tag) if str(v.tag) != "" else ""), 16, Color("a9d9c4") if replied else Color("ffb3c6"), PUI.body(900))
	sl.position = Vector2(x0, 108)
	sl.size = Vector2(W - x0 - 36, 24)
	sl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	sl.size = Vector2(W - x0 - 36, 24)
	PUI.ellipsize(sl, W - x0 - 36)
	c.add_child(sl)
	var id: = int(l.id)
	PUI.tap(c, func(): open_letter(id), "pop")
	return c


func _legacy_link() -> Control:
	var c: = Control.new()
	c.custom_minimum_size = Vector2(W, 70)
	var b: = Control.new()
	b.position = Vector2(24, 10)
	b.size = Vector2(W - 48, 52)
	b.pivot_offset = b.size * 0.5
	b.add_child(PUI.panel(Rect2(Vector2.ZERO, b.size), PUI.box(Color(1, 1, 1, 0.04), 26, 1.0, Color(1, 1, 1, 0.15))))
	var n: = V9Letters.legacy_unread()
	var l: = PUI.label("Записки и сцены" + ("  · новых: %d" % n if n > 0 else "") + "  ›", 20, PUI.MUTED, PUI.body(800))
	l.size = b.size
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	b.add_child(l)
	c.add_child(b)
	PUI.tap(b, func(): open_legacy.emit(), "pop")
	return c


# --- letter page -------------------------------------------------------------------------

func open_letter(id: int) -> void:
	var l: = V9Letters.find(id)
	if l.is_empty():
		return
	if page != null and is_instance_valid(page):
		page.queue_free()
	var first: = not bool(l.get("read", false))
	V9Letters.mark_read(id)
	G.save()
	var v: = V9Letters.view(l)
	var h: = str(l.h)
	var hc: = P.hero_color(h)
	page = Control.new()
	page.name = "LetterPage"
	page.size = size
	page.mouse_filter = Control.MOUSE_FILTER_STOP
	page.add_child(PUI.grad_rect(Rect2(Vector2.ZERO, size), PUI.SCREEN_A.lerp(hc, 0.08), PUI.SCREEN_B))
	var sc: = ScrollContainer.new()
	sc.size = size
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	page.add_child(sc)
	var body: = Control.new()
	sc.add_child(body)
	var y: = 12.0
	# back + head
	var back: = Control.new()
	back.position = Vector2(8, y)
	back.size = Vector2(64, 64)
	back.pivot_offset = back.size * 0.5
	var arrow: = PUI.label("‹", 60, PUI.GOLD, PUI.body(700))
	arrow.size = back.size
	arrow.position.y = -6
	arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	back.add_child(arrow)
	body.add_child(back)
	PUI.tap(back, close_letter, "tap")
	var av: = V8Art.emotion_avatar(h, v.emo, Rect2(80, y, 110, 110), "gold")
	body.add_child(av)
	PUI.pop_in(av, 0.1, 0.7)
	var f: = PUI.body(900)
	var subj_h: = f.get_multiline_string_size(str(v.subj), HORIZONTAL_ALIGNMENT_LEFT, W - 230, 26).y
	var sj: = PUI.label(str(v.subj), 26, PUI.TEXT, f)
	sj.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sj.position = Vector2(206, y + 8)
	sj.size = Vector2(W - 230, subj_h + 4)
	body.add_child(sj)
	var tg: = PUI.label(str(v.tag) + " · " + V9Letters.ago(int(l.get("t", 0))), 16, PUI.GOLD, PUI.body(900))
	tg.position = Vector2(206, y + 14 + subj_h)
	tg.size = Vector2(W - 230, 24)
	body.add_child(tg)
	y += maxf(126.0, subj_h + 60.0)
	# paper
	var pw: = W - 36.0
	var tw: = pw - 56.0
	var bf: = PUI.body(800)
	var body_h: = bf.get_multiline_string_size(str(v.body), HORIZONTAL_ALIGNMENT_LEFT, tw, 21).y + 8.0
	var ps_h: = bf.get_multiline_string_size(str(v.ps), HORIZONTAL_ALIGNMENT_LEFT, tw, 18).y
	var paper_h: = 34.0 + body_h + 60.0 + ps_h + 26.0
	var paper: = Control.new()
	paper.position = Vector2(18, y)
	paper.size = Vector2(pw, paper_h)
	paper.add_child(PUI.grad_rect(Rect2(0, 0, pw, paper_h), PAPER_A, PAPER_B))
	var frame: = PUI.panel(Rect2(0, 0, pw, paper_h), PUI.box(Color(0, 0, 0, 0), 4, 3.0, Color("c9a46a")))
	paper.add_child(frame)
	var rule: = ColorRect.new()
	rule.color = Color(hc.darkened(0.25), 0.55)
	rule.position = Vector2(28, 18)
	rule.size = Vector2(tw, 2)
	paper.add_child(rule)
	var bd: = PUI.label(str(v.body), 21, PAPER_INK, bf)
	bd.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bd.position = Vector2(28, 30)
	bd.size = Vector2(tw, body_h)
	paper.add_child(bd)
	var sg: = PUI.label("— " + str(v.sign), 34 if PUI.has_caveat() else 26, hc.darkened(0.45), PUI.hand())
	sg.position = Vector2(28, 30 + body_h)
	sg.size = Vector2(tw, 48)
	sg.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	paper.add_child(sg)
	var ps: = PUI.label(str(v.ps), 18, PAPER_MUTED, bf)
	ps.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ps.position = Vector2(28, 30 + body_h + 56)
	ps.size = Vector2(tw, ps_h + 4)
	paper.add_child(ps)
	body.add_child(paper)
	# ink appears: the paper fades and slides in
	paper.modulate.a = 0.0
	paper.position.y += 18
	var pt: = paper.create_tween().set_parallel()
	pt.tween_property(paper, "modulate:a", 1.0, 0.35).set_delay(0.1)
	pt.tween_property(paper, "position:y", y, 0.4).set_delay(0.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	y += paper_h + 24.0
	var reply_box: = Control.new()
	reply_box.name = "Replies"
	reply_box.position = Vector2(0, y)
	reply_box.size = Vector2(W, 260)
	body.add_child(reply_box)
	if int(l.get("reply", -1)) >= 0:
		_answer(reply_box, l, v, false)
	else:
		var cap: = PUI.label("Твой ответ", 18, PUI.GOLD, PUI.body(900))
		cap.position = Vector2(26, 0)
		cap.size = Vector2(300, 24)
		reply_box.add_child(cap)
		for i in 2:
			var txt: = str(v.replies[i])
			var ph: = maxf(62.0, bf.get_multiline_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, W - 120, 21).y + 28.0)
			var b: = Control.new()
			b.name = "Reply%d" % i
			b.position = Vector2(18, 32 + i * 86)
			b.size = Vector2(W - 36, ph)
			b.pivot_offset = b.size * 0.5
			b.add_child(PUI.panel(Rect2(Vector2.ZERO, b.size), PUI.box(Color(0.16, 0.11, 0.15, 0.96), 28, 2.0, Color(hc.lerp(PUI.GOLD, 0.5), 0.85), 8)))
			var bl: = PUI.label(txt, 21, PUI.TEXT, bf)
			bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			bl.position = Vector2(24, 0)
			bl.size = Vector2(b.size.x - 48, ph)
			bl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			b.add_child(bl)
			reply_box.add_child(b)
			PUI.pop_in(b, 0.15 + i * 0.07, 0.85)
			var ii: = i
			PUI.tap(b, func(): _send(reply_box, l, v, ii), "")
	body.custom_minimum_size = Vector2(W, y + 300)
	add_child(page)
	page.position.x = W
	var t: = page.create_tween()
	t.tween_property(page, "position:x", 0.0, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if first:
		V9Feel.sound("flip", 1.05, -4)


func close_letter() -> void:
	if page == null or not is_instance_valid(page):
		return
	var p: = page
	page = null
	PUI.snd("tab")
	var t: = p.create_tween()
	t.tween_property(p, "position:x", W, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.tween_callback(p.queue_free)
	refresh()


func _send(box: Control, l: Dictionary, v: Dictionary, i: int) -> void:
	if int(l.get("reply", -1)) >= 0:
		return
	V9Letters.reply(int(l.id), i)
	PUI.snd("msg_out")
	for c in box.get_children():
		c.queue_free()
	_answer(box, l, v, true)


func _answer(box: Control, l: Dictionary, v: Dictionary, fresh: bool) -> void:
	var h: = str(l.h)
	var i: = int(l.reply)
	var me: = V10Bubble.make({"who": "me", "k": "text", "t": str(v.replies[i])}, W * 0.74, P.hero_color(h))
	me.position = Vector2(W - 22 - me.size.x, 0)
	box.add_child(me)
	var her: = V10Bubble.make({"who": "h", "k": "text", "t": str(v.answers[i])}, W * 0.70, P.hero_color(h))
	her.position = Vector2(110, me.size.y + 16)
	box.add_child(her)
	var av: = V8Art.emotion_avatar(h, "shy" if i == 0 else "happy", Rect2(22, me.size.y + 16, 76, 76), "pink")
	box.add_child(av)
	box.size.y = me.size.y + her.size.y + 60
	if fresh:
		me.appear()
		her.appear(0.9)
		PUI.pop_in(av, 0.9, 0.6)
		get_tree().create_timer(0.9).timeout.connect(func():
			if is_instance_valid(av):
				PUI.snd("msg_in")
				V9Feel.success(av, "")
				PUI.burst(box, av.position + av.size * 0.5, Color("ff8fb8"), 10, "♥", 90))
