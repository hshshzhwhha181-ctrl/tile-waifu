class_name V10MailView
extends Control

# «Почта» tab (§Р8 п.4): the 0.9 letters (V9Letters — data, rules and replies unchanged) shown in the phone's style:
# rows with her face, subject, a preview line, the event tag and one marker «Ждёт ответа» (UX_RULES §9 п.20: no
# statistics line, one marker, a warm face); a letter opens as a page that slides
# in from the right: paper, her signature in handwriting, P.S., two reply pills → her answer bubble.
# The 0.7/0.8 notes («Записки и сцены») stay in the full Letters screen (main.go("letters")) behind a link row.

signal open_legacy

const P: = preload("res://scripts/v10/phone/phone.gd")
const PUI: = preload("res://scripts/v10/phone/phone_ui.gd")

const ROW_H: = 150.0
const PAPER_A: = PUI.PAPER_A
const PAPER_B: = PUI.PAPER_B
const PAPER_INK: = PUI.PAPER_INK
const PAPER_MUTED: = PUI.PAPER_MUTED
const WARM: = ["happy", "shy"]      # list faces: a surprised / sad / pouting portrait reads as a reproach in a list

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
	var lead: = -1
	for k in letters.size():
		if int(letters[k].get("reply", -1)) < 0:
			lead = k
			break
	for l in letters:
		var r: = _row(l)
		if i == maxi(lead, 0):
			PUI.role(r, "primary")      # the first letter waiting for an answer (else the newest)
		list.add_child(r)
		PUI.pop_in(r, 0.04 + 0.05 * mini(i, 6), 0.92, 0.34)
		i += 1
	if not V9Letters.legacy_entries().is_empty():
		list.add_child(_legacy_link())


func _empty() -> Control:
	var c: = Control.new()
	c.custom_minimum_size = Vector2(W, 260)
	var l: = PUI.label("Писем пока нет.\nПосле первой победы дня она обязательно напишет.", PUI.FS_BODY, PUI.MUTED, PUI.body(800))
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
	c.add_child(PUI.panel(Rect2(12, 0, W - 24, ROW_H), PUI.box(Color(PUI.TEXT, 0.075 if unread else 0.04), 24)))
	var acc: = ColorRect.new()
	acc.color = Color(hc, 0.6)
	acc.position = Vector2(12, 26)
	acc.size = Vector2(4, ROW_H - 52)
	acc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(acc)
	var emo: = str(v.emo) if str(v.emo) in WARM else "happy"
	c.add_child(V8Art.emotion_avatar(h, emo, Rect2(28, 22, 96, 96), "glass"))
	var x0: = 138.0
	var nm: = PUI.label(P.hero_name(h), PUI.fs_hand(), hc.lerp(Color.WHITE, 0.45), PUI.hand())
	nm.position = Vector2(x0, 0 if PUI.has_caveat() else 4)
	nm.size = Vector2(240, 44)
	c.add_child(nm)
	var tm: = PUI.label(V9Letters.ago(int(l.get("t", 0))), PUI.FS_CAPTION, PUI.MUTED, PUI.body(800))
	tm.position = Vector2(W - 210, 12)
	tm.size = Vector2(180, 26)
	tm.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	c.add_child(tm)
	var sj: = PUI.label(str(v.subj), PUI.FS_BODY, PUI.TEXT, PUI.body(900 if unread else 800))
	sj.position = Vector2(x0, 46)
	sj.size = Vector2(W - x0 - 36, 32)
	PUI.ellipsize(sj, W - x0 - 36)
	c.add_child(sj)
	var pv: = PUI.label(str(v.body).replace("\n", " "), PUI.FS_CAPTION, PUI.PAPER_300, PUI.body(700))
	pv.position = Vector2(x0, 80)
	pv.size = Vector2(W - x0 - 36, 26)
	PUI.ellipsize(pv, W - x0 - 36)
	c.add_child(pv)
	# one marker: «Ждёт ответа» while it waits; an answered letter keeps only its tag
	var parts: = []
	if not replied:
		parts.append("Ждёт ответа")
	if str(v.tag) != "":
		parts.append(str(v.tag))
	var sl: = PUI.label("  ·  ".join(parts), PUI.FS_CAPTION, PUI.ROSE_300 if not replied else PUI.MUTED, PUI.body(900 if not replied else 700))
	sl.position = Vector2(x0, 110)
	sl.size = Vector2(W - x0 - 36, 26)
	PUI.ellipsize(sl, W - x0 - 36)
	c.add_child(sl)
	var id: = int(l.id)
	PUI.tap(c, func(): open_letter(id), "pop")
	return c


func _legacy_link() -> Control:
	var c: = Control.new()
	c.custom_minimum_size = Vector2(W, 92)
	var b: = Control.new()
	b.position = Vector2(24, 6)
	b.size = Vector2(W - 48, 80)                 # 56 px row in an 80 px tap zone
	b.pivot_offset = b.size * 0.5
	PUI.role(b, "secondary")
	b.add_child(PUI.panel(Rect2(0, 12, b.size.x, 56), PUI.box(Color(PUI.TEXT, 0.04), 28, 1.0, Color(PUI.TEXT, 0.15))))
	var n: = V9Letters.legacy_unread()
	var l: = PUI.label("Записки и сцены" + ("  · новых: %d" % n if n > 0 else "") + "  ›", PUI.FS_CAPTION, PUI.MUTED, PUI.body(800))
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
	if str(l.get("ev", "")) == "week" and l.get("custom") is Dictionary and (l.custom as Dictionary).has("week_doc"):
		var wv: = V10WeekLetterView.open(self, l.custom.week_doc)
		wv.closed.connect(func():
			if int(l.get("reply", -1)) < 0:
				V9Letters.reply(id, 0)
			refresh())
		return
	if str(l.get("ev", "")) == "ask_bday" and int(l.get("reply", -1)) < 0:
		var bs: = V10PlayerBdayScreen.open(self, "ask")
		bs.closed.connect(func(_res: Dictionary):
			V9Letters.reply(id, 0 if V10PlayerBday.has_date() else 1)
			refresh())
		return
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
	var back: = PUI.icon_button("back", Rect2(0, y, 80, 80), PUI.GOLD, 26.0, 3.5)
	body.add_child(back)
	PUI.tap(back, close_letter, "tap")
	var av: = V8Art.emotion_avatar(h, v.emo, Rect2(80, y, 110, 110), "gold")
	body.add_child(av)
	PUI.pop_in(av, 0.1, 0.7)
	var f: = PUI.body(900)
	var subj_h: = f.get_multiline_string_size(str(v.subj), HORIZONTAL_ALIGNMENT_LEFT, W - 230, PUI.FS_H3).y
	var sj: = PUI.label(str(v.subj), PUI.FS_H3, PUI.TEXT, f)
	sj.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sj.position = Vector2(206, y + 8)
	sj.size = Vector2(W - 230, subj_h + 4)
	body.add_child(sj)
	var tg: = PUI.label(" · ".join([str(v.tag), V9Letters.ago(int(l.get("t", 0)))].filter(func(x): return x != "")), PUI.FS_CAPTION, PUI.GOLD, PUI.body(900))
	tg.position = Vector2(206, y + 14 + subj_h)
	tg.size = Vector2(W - 230, 26)
	body.add_child(tg)
	y += maxf(126.0, subj_h + 60.0)
	# paper
	var pw: = W - 36.0
	var tw: = pw - 56.0
	var bf: = PUI.body(800)
	var body_h: = bf.get_multiline_string_size(str(v.body), HORIZONTAL_ALIGNMENT_LEFT, tw, PUI.FS_BODY).y + 8.0
	var ps_h: = bf.get_multiline_string_size(str(v.ps), HORIZONTAL_ALIGNMENT_LEFT, tw, PUI.FS_CAPTION).y
	var paper_h: = 34.0 + body_h + 60.0 + ps_h + 26.0
	var paper: = Control.new()
	paper.position = Vector2(18, y)
	paper.size = Vector2(pw, paper_h)
	paper.add_child(PUI.grad_rect(Rect2(0, 0, pw, paper_h), PAPER_A, PAPER_B))
	var frame: = PUI.panel(Rect2(0, 0, pw, paper_h), PUI.box(Color(0, 0, 0, 0), 4, 1.0, PUI.GOLD_700))
	paper.add_child(frame)
	var rule: = ColorRect.new()
	rule.color = Color(hc.darkened(0.25), 0.55)
	rule.position = Vector2(28, 18)
	rule.size = Vector2(tw, 2)
	paper.add_child(rule)
	var bd: = PUI.label(str(v.body), PUI.FS_BODY, PAPER_INK, bf)
	bd.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bd.position = Vector2(28, 30)
	bd.size = Vector2(tw, body_h)
	paper.add_child(bd)
	var sg: = PUI.label("— " + str(v.sign), PUI.fs_hand(), hc.darkened(0.45), PUI.hand())
	sg.position = Vector2(28, 30 + body_h)
	sg.size = Vector2(tw, 48)
	sg.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	paper.add_child(sg)
	var ps: = PUI.label(str(v.ps), PUI.FS_CAPTION, PAPER_MUTED, bf)
	ps.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ps.position = Vector2(28, 30 + body_h + 56)
	ps.size = Vector2(tw, ps_h + 4)
	paper.add_child(ps)
	body.add_child(paper)
	# ink appears: the paper fades and slides in
	paper.modulate.a = 0.0
	var pt: = paper.create_tween().set_parallel()
	if PUI.calm():
		pt.tween_property(paper, "modulate:a", 1.0, 0.12)
	else:
		paper.position.y += 18
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
		var cap: = PUI.label("Твой ответ", PUI.FS_CAPTION, PUI.GOLD, PUI.body(900))
		cap.position = Vector2(26, 0)
		cap.size = Vector2(300, 26)
		reply_box.add_child(cap)
		PUI.role(reply_box, "primary")      # «Ответить» (§3.4 «Письмо»): two pills, one action
		var ry: = 34.0
		for i in 2:
			var txt: = str(v.replies[i])
			# pills stack by their own height (a long answer wraps without covering the next one); ≥ 80 px tap rows
			var ph: = maxf(80.0, bf.get_multiline_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, W - 84, PUI.FS_BODY).y + 28.0)
			var b: = Control.new()
			b.name = "Reply%d" % i
			b.position = Vector2(18, ry)
			b.size = Vector2(W - 36, ph)
			b.pivot_offset = b.size * 0.5
			b.add_child(PUI.panel(Rect2(Vector2.ZERO, b.size), PUI.box(Color(0.16, 0.11, 0.15, 0.96), minf(ph * 0.5, 40.0), 2.0, Color(hc.lerp(PUI.GOLD, 0.5), 0.85))))
			var bl: = PUI.label(txt, PUI.FS_BODY, PUI.TEXT, bf)
			bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			bl.position = Vector2(24, 0)
			bl.size = Vector2(b.size.x - 48, ph)
			bl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			b.add_child(bl)
			reply_box.add_child(b)
			PUI.pop_in(b, 0.15 + i * 0.07, 0.85)
			var ii: = i
			PUI.tap(b, func(): _send(reply_box, l, v, ii), "")
			ry += ph + 14.0
		reply_box.size.y = ry
	body.custom_minimum_size = Vector2(W, y + maxf(300.0, reply_box.size.y + 40.0))
	add_child(page)
	page.position.x = W
	PUI.enter(page, "position:x", 0.0, 0.34)
	if first:
		V9Feel.sound("flip", 1.05, -4)


func close_letter() -> void:
	if page == null or not is_instance_valid(page):
		return
	var p: = page
	page = null
	PUI.snd("tab")
	var t: = PUI.leave(p, "position:x", W, 0.24)
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
				PUI.burst(box, av.position + av.size * 0.5, PUI.HEART, 10, "♥", 90))
