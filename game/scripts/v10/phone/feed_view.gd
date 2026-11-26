class_name V10FeedView
extends Control

# «Лента» tab (§Р9): heroine posts, newest first, two a week (V10ChatFeed). A card: her face and name, the date,
# the photo (existing sfw art only), the caption (≤280), 1–2 comments of the other heroines that appear 0.8 s after
# the card, a like (double tap on the photo = heart burst of 16, vibration, pop, +1 once) and two reply pills
# (her answer after 1 s, +2 once). No counters of strangers' likes, no prices, no «призвать».

const P: = preload("res://scripts/v10/phone/phone.gd")
const PUI: = preload("res://scripts/v10/phone/phone_ui.gd")
const FEED: = preload("res://scripts/v10/chat/chat_feed.gd")

const WD: = ["вс", "пн", "вт", "ср", "чт", "пт", "сб"]
const MON: = ["янв", "фев", "мар", "апр", "мая", "июн", "июл", "авг", "сен", "окт", "ноя", "дек"]

var W: = 600.0
var H: = 900.0
var scroll: ScrollContainer
var list: VBoxContainer
var cards: = {}


func build(w: float, h: float) -> void:
	W = w
	H = h
	size = Vector2(W, H)
	name = "FeedView"
	scroll = ScrollContainer.new()
	scroll.size = size
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	add_child(scroll)
	list = VBoxContainer.new()
	list.custom_minimum_size = Vector2(W, 0)
	list.add_theme_constant_override("separation", 22)
	scroll.add_child(list)
	refresh()


static func date_label(day: int) -> String:
	var d: = Time.get_datetime_dict_from_unix_time(day * 86400)
	return "%s, %d %s" % [WD[int(d.weekday)], int(d.day), MON[int(d.month) - 1]]


func refresh() -> void:
	for c in list.get_children():
		c.queue_free()
	cards.clear()
	var ctx: = P.ctx()
	var posts: = FEED.visible(P.feed_st(), ctx)
	var seen: = int(P.feed_st().seen_max)
	var sp: = Control.new()
	sp.custom_minimum_size = Vector2(W, 4)
	list.add_child(sp)
	if posts.is_empty():
		var e: = PUI.label("Лента пока пустая. Посты появляются два раза в неделю.", PUI.FS_BODY, PUI.MUTED, PUI.body(800))
		e.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		e.custom_minimum_size = Vector2(W - 60, 200)
		list.add_child(e)
		return
	var i: = 0
	for p in posts:
		var c: = _card(p, int(p.day) > seen, i)
		list.add_child(c)
		cards[str(p.id)] = c
		i += 1
	var end: = PUI.label("Это все посты. Новые — во вторник и пятницу.", PUI.FS_CAPTION, PUI.MUTED, PUI.body(800))
	end.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end.custom_minimum_size = Vector2(W, 80)
	list.add_child(end)
	FEED.mark_seen(P.feed_st(), ctx)


func _card(p: Dictionary, fresh: bool, idx: int) -> Control:
	var h: = str(p.hero)
	var hc: = P.hero_color(h)
	var cw: = W - 28.0
	var bf: = PUI.body(800)
	var cap_h: = bf.get_multiline_string_size(str(p.t), HORIZONTAL_ALIGNMENT_LEFT, cw - 44, PUI.FS_BODY).y
	var ph: = minf(cw * 1.2, 640.0)
	var y_photo: = 84.0
	var y_act: = y_photo + ph
	var y_cap: = y_act + 84.0
	var y_com: = y_cap + cap_h + 14.0
	var c: = Control.new()
	c.name = "Post_" + str(p.id)
	c.size = Vector2(W, 0)
	var card: = Control.new()
	card.position = Vector2(14, 0)
	c.add_child(card)
	# a new post is told by tone (a thin line in her colour), never by a «новое» sticker (§3.6 п.6)
	var bg: = PUI.panel(Rect2(0, 0, cw, 100), PUI.box(Color(0.15, 0.105, 0.135, 0.98), 30, 1.0 if fresh else 0.0, Color(hc, 0.5)))
	bg.name = "Bg"
	card.add_child(bg)
	card.add_child(V8Art.emotion_avatar(h, "happy", Rect2(16, 14, 58, 58), "gold"))
	var nm: = PUI.label(P.hero_name(h), PUI.fs_hand(), hc.lerp(Color.WHITE, 0.45), PUI.hand())
	nm.position = Vector2(86, 4 if PUI.has_caveat() else 8)
	nm.size = Vector2(cw - 120, 44)
	card.add_child(nm)
	var dl: = PUI.label(date_label(int(p.day)), PUI.FS_CAPTION, PUI.MUTED, PUI.body(800))
	dl.position = Vector2(88, 48)
	dl.size = Vector2(220, 26)
	card.add_child(dl)
	var photo_box: = Control.new()
	photo_box.name = "Photo"
	photo_box.position = Vector2(12, y_photo)
	photo_box.size = Vector2(cw - 24, ph)
	photo_box.pivot_offset = photo_box.size * 0.5
	var tex: = P.photo_tex(str(p.img))
	if tex != null:
		var art: = Common.card_art(tex, Rect2(Vector2.ZERO, photo_box.size), Vector2(0.5, 0.3), 1.0, 22.0)
		(art.material as ShaderMaterial).set_shader_parameter("bottom_shade", 0.0)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		photo_box.add_child(art)
	card.add_child(photo_box)
	var big: = PUI.label("♥", 170, Color(1, 1, 1, 0.95), PUI.body(900), 10, Color(0.85, 0.2, 0.4, 0.7))
	big.size = photo_box.size
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	big.pivot_offset = photo_box.size * 0.5
	big.modulate.a = 0.0
	big.name = "BigHeart"
	photo_box.add_child(big)
	# like row
	var like: = Control.new()
	like.name = "Like"
	like.position = Vector2(14, y_act)
	like.size = Vector2(230, 80)
	like.pivot_offset = Vector2(28, 40)
	var hl: = PUI.label("♥" if p.liked else "♡", PUI.fs_hand(), PUI.HEART if p.liked else PUI.TEXT, PUI.body(900))
	hl.name = "Heart"
	hl.size = Vector2(56, 80)
	hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hl.pivot_offset = Vector2(28, 40)
	like.add_child(hl)
	var lt: = PUI.label("Тебе нравится" if p.liked else "Нравится", PUI.FS_CAPTION, PUI.TEXT if p.liked else PUI.MUTED, PUI.body(800))
	lt.name = "Txt"
	lt.position = Vector2(60, 0)
	lt.size = Vector2(170, 80)
	lt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	like.add_child(lt)
	card.add_child(like)
	var pid: = str(p.id)
	PUI.tap(like, func(): do_like(pid, false), "")
	# double tap on the photo
	var last: = {"t": 0}
	PUI.tap(photo_box, func():
		var now: = Time.get_ticks_msec()
		if now - int(last.t) < 320:
			do_like(pid, true)
			last.t = 0
		else:
			last.t = now, "")
	var cap: = PUI.label(str(p.t), PUI.FS_BODY, PUI.TEXT, bf)
	cap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cap.position = Vector2(22, y_cap)
	cap.size = Vector2(cw - 44, cap_h + 4)
	card.add_child(cap)
	# comments of the other heroines
	var y: = y_com
	var coms: Array = p.get("comments", [])
	for k in coms.size():
		var cm: Dictionary = coms[k]
		var cc: = _comment(str(cm.hero), str(cm.t), cw - 40)
		cc.position = Vector2(20, y)
		card.add_child(cc)
		y += cc.size.y + 8.0
		cc.modulate.a = 0.0
		var tw: = cc.create_tween()
		tw.tween_interval(0.8 + 0.5 * k + 0.15 * mini(idx, 3))
		tw.tween_property(cc, "modulate:a", 1.0, 0.3)
		if idx == 0:
			tw.tween_callback(func(): PUI.snd("comment_in", 1.0 + 0.05 * k, -6.0))
	y += 6.0
	var rbox: = Control.new()
	rbox.name = "Replies"
	rbox.position = Vector2(0, y)
	rbox.size = Vector2(cw, 10)
	card.add_child(rbox)
	_replies(rbox, p, cw)
	if idx == 0:
		# the newest post: its reply pills are the screen's one main action, the like is secondary (§3.4)
		PUI.role(rbox, "primary")
		PUI.role(like, "secondary")
	var total: = y + rbox.size.y + 14.0
	bg.size.y = total
	c.custom_minimum_size = Vector2(W, total)
	c.size.y = total
	card.size = Vector2(cw, total)
	c.set_meta("rbox", rbox)
	c.set_meta("bg", bg)
	c.set_meta("base", y)
	return c


func _comment(h: String, t: String, w: float) -> Control:
	var c: = Control.new()
	var bf: = PUI.body(700)
	var who: = P.hero_name(h)
	var th: = bf.get_multiline_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, w - 70, PUI.FS_CAPTION).y
	c.size = Vector2(w, maxf(48.0, th + 36.0))
	c.add_child(V8Art.emotion_avatar(h, "happy", Rect2(0, 2, 42, 42), "glass"))
	var n: = PUI.label(who, PUI.FS_CAPTION, P.hero_color(h).lerp(Color.WHITE, 0.4), PUI.body(900))
	n.position = Vector2(54, 0)
	n.size = Vector2(w - 60, 24)
	c.add_child(n)
	var l: = PUI.label(t, PUI.FS_CAPTION, PUI.PAPER_300, bf)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.position = Vector2(54, 24)
	l.size = Vector2(w - 70, th + 4)
	c.add_child(l)
	return c


func _replies(box: Control, p: Dictionary, cw: float) -> void:
	for ch in box.get_children():
		ch.queue_free()
	var reps: Array = p.get("replies", [])
	var r: = int(p.get("replied", -1))
	var h: = str(p.hero)
	var hc: = P.hero_color(h)
	if r >= 0 and r < reps.size():
		var me: = V10Bubble.make({"who": "me", "k": "text", "t": str(reps[r].t)}, cw * 0.72, hc)
		me.position = Vector2(cw - 18 - me.size.x, 0)
		box.add_child(me)
		var her: = V10Bubble.make({"who": "h", "k": "text", "t": str(reps[r].a)}, cw * 0.72, hc)
		her.position = Vector2(18, me.size.y + 10)
		box.add_child(her)
		box.size.y = me.size.y + her.size.y + 16
		box.set_meta("me", me)
		box.set_meta("her", her)
		return
	var y: = 0.0
	var bf: = PUI.body(800)
	for i in reps.size():
		var txt: = str(reps[i].t)
		var w: = minf(cw - 36, bf.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, PUI.FS_CAPTION).x + 48)
		var b: = Control.new()
		b.name = "Reply%d" % i
		b.position = Vector2(18, y)
		b.size = Vector2(w, 80)                 # 56 px pill in an 80 px tap zone
		b.pivot_offset = b.size * 0.5
		b.add_child(PUI.panel(Rect2(0, 12, w, 56), PUI.box(Color(PUI.TEXT, 0.05), 28, 1.5, Color(hc.lerp(PUI.GOLD, 0.5), 0.75))))
		var l: = PUI.label(txt, PUI.FS_CAPTION, PUI.TEXT, bf)
		l.size = b.size
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.add_child(l)
		box.add_child(b)
		var pid: = str(p.id)
		var ii: = i
		PUI.tap(b, func(): do_reply(pid, ii), "")
		y += 80.0
	box.size.y = y


func _relayout(c: Control) -> void:
	var rbox: Control = c.get_meta("rbox")
	var total: = float(c.get_meta("base")) + rbox.size.y + 14.0
	(c.get_meta("bg") as Control).size.y = total
	c.custom_minimum_size.y = total


# --- actions -------------------------------------------------------------------------------

func do_like(id: String, burst: bool) -> void:
	var c: Control = cards.get(id)
	if c == null:
		return
	var photo: Control = c.get_node("Control/Photo") if c.has_node("Control/Photo") else c.find_child("Photo", true, false)
	var like: Control = c.find_child("Like", true, false)
	if burst and photo != null:
		var big: Label = photo.get_node("BigHeart")
		big.scale = Vector2.ONE if PUI.calm() else Vector2(0.3, 0.3)
		var t: = big.create_tween().set_parallel()
		t.tween_property(big, "modulate:a", 1.0, 0.1)
		if not PUI.calm():
			t.tween_property(big, "scale", Vector2(1.15, 1.15), 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.chain().tween_property(big, "modulate:a", 0.0, 0.3).set_delay(0.25)
		PUI.burst(photo, photo.size * 0.5, PUI.HEART, 16, "♥", 210)
	var r: = FEED.like(P.feed_st(), id, P.ctx())
	if not r.ok:
		if not burst:
			V9Feel.press(like, "")
		return
	P.gain(r.effects)
	G.save()
	PUI.snd("like_pop")
	V9Feel.haptic("match")
	if like != null:
		var hl: Label = like.get_node("Heart")
		hl.text = "♥"
		hl.label_settings.font_color = PUI.HEART
		(like.get_node("Txt") as Label).text = "Тебе нравится"
		(like.get_node("Txt") as Label).label_settings.font_color = PUI.TEXT
		V9Feel.success(hl, "")
		if not burst:
			PUI.burst(like, Vector2(28, 40), PUI.HEART, 8, "♥", 70)


func do_reply(id: String, i: int) -> void:
	var c: Control = cards.get(id)
	if c == null:
		return
	var r: = FEED.reply(P.feed_st(), id, i, P.ctx())
	if not r.ok:
		return
	P.gain(r.effects)
	G.save()
	PUI.snd("msg_out")
	var post: Dictionary = {}
	for p in FEED.visible(P.feed_st(), P.ctx()):
		if str(p.id) == id:
			post = p
	var rbox: Control = c.get_meta("rbox")
	_replies(rbox, post, rbox.size.x)
	_relayout(c)
	var me: V10Bubble = rbox.get_meta("me")
	var her: V10Bubble = rbox.get_meta("her")
	me.appear()
	her.modulate.a = 0.0
	get_tree().create_timer(1.0).timeout.connect(func():
		if is_instance_valid(her):
			her.appear()
			PUI.snd("msg_in")
			V9Feel.haptic("select"))


func dev_act(a: String) -> void:
	if cards.is_empty():
		return
	var first: String = cards.keys()[0]
	match a:
		"like":
			do_like(first, true)
		"reply":
			do_reply(first, 0)
