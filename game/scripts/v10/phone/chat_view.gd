class_name V10ChatView
extends Control

# A dialog with one heroine (docs/0.10-spec.md §Р8 п.5): her threads one after another (title dividers), bubbles
# with a spring, «печатает…» 0.4 s + 35 ms/char ≤ 2.2 s (tap skips), «тинь» + light haptic, photos (tap = full
# view), voice notes 2–4 s with a lip-sync bounce of her avatar, reply pills or a sticker, long press on her bubble
# = 6 reactions (she answers ~30%). Outside a thread the player can still send a sticker (she answers ≤3 a day).
# The view keeps the last 60 bubbles (KEEP) — the log's limit — so the node count stays bounded.

signal closed

const P: = preload("res://scripts/v10/phone/phone.gd")
const PUI: = preload("res://scripts/v10/phone/phone_ui.gd")
const C: = preload("res://scripts/v10/chat/chat.gd")
const D: = preload("res://scripts/v10/chat/chat_data.gd")
const BUB: = preload("res://scripts/v10/phone/bubble.gd")
const TRAY: = preload("res://scripts/v10/phone/sticker_tray.gd")

const KEEP: = 60
const HEAD_H: = 104.0

var hero: = ""
var tid: = ""
var W: = 600.0
var H: = 1000.0
var hc: = Color.WHITE
var scroll: ScrollContainer
var list: VBoxContainer
var bar: Control
var status_l: Label
var avatar: Control
var typing: V10Bubble = null
var queue: Array = []
var busy: = false
var skip: = false
var tray: Control = null
var react_bar: Control = null
var viewer: Control = null
var bar_h: = 0.0


func build(w: float, h: float, hero_id: String, thread_id: = "") -> void:
	W = w
	H = h
	hero = hero_id
	hc = P.hero_color(hero)
	size = Vector2(W, H)
	clip_contents = true
	name = "ChatView"
	add_child(PUI.grad_rect(Rect2(0, 0, W, H), PUI.SCREEN_A.lerp(hc, 0.10), PUI.SCREEN_B))
	_header()
	scroll = ScrollContainer.new()
	scroll.position = Vector2(0, HEAD_H)
	scroll.size = Vector2(W, H - HEAD_H - 120)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.follow_focus = false
	add_child(scroll)
	var margin: = MarginContainer.new()
	margin.custom_minimum_size = Vector2(W, 0)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 18)
	scroll.add_child(margin)
	list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	margin.add_child(list)
	scroll.gui_input.connect(_on_scroll_input)
	bar = Control.new()
	bar.name = "Bar"
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)
	tid = thread_id if thread_id != "" else _latest_tid()
	_fill()


func _latest_tid() -> String:
	var best: = ""
	var bd: = -1
	var st: Dictionary = P.transport().state
	for t in st.chats:
		if D.hero_of(t) != hero:
			continue
		var c: Dictionary = st.chats[t]
		var k: = int(c.get("day", 0)) * 2 + (0 if bool(c.get("done", false)) else 1)
		if k > bd:
			bd = k
			best = t
	return best


func _header() -> void:
	var hb: = PUI.grad_rect(Rect2(0, 0, W, HEAD_H), Color(0.09, 0.06, 0.09, 0.98), Color(0.13, 0.09, 0.12, 0.96))
	hb.name = "Head"
	add_child(hb)
	var line: = ColorRect.new()
	line.color = Color(hc, 0.55)
	line.position = Vector2(0, HEAD_H - 2)
	line.size = Vector2(W, 2)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(line)
	var back: = PUI.icon_button("back", Rect2(0, 12, 80, 80), PUI.GOLD, 26.0, 3.5)
	back.name = "Back"
	add_child(back)
	PUI.tap(back, close, "tap")
	avatar = V8Art.emotion_avatar(hero, "happy", Rect2(80, 14, 76, 76), "gold")
	add_child(avatar)
	var nm: = PUI.label(P.hero_name(hero), PUI.fs_hand(), hc.lerp(Color.WHITE, 0.45), PUI.hand())
	nm.position = Vector2(170, 8 if PUI.has_caveat() else 12)
	nm.size = Vector2(W - 190, 50)
	add_child(nm)
	status_l = PUI.label("в сети", PUI.FS_CAPTION, PUI.JADE_300, PUI.body(800))
	status_l.position = Vector2(168, 60)
	status_l.size = Vector2(W - 190, 26)
	add_child(status_l)


func close() -> void:
	PUI.snd("tab")
	var t: = PUI.leave(self, "position:x", W, 0.26)
	t.tween_callback(func():
		closed.emit()
		queue_free())


func slide_in() -> void:
	position.x = W
	PUI.enter(self, "position:x", 0.0, 0.34)


# --- content ------------------------------------------------------------------------------

func _hero_tids() -> Array:
	var st: Dictionary = P.transport().state
	var out: = []
	for t in st.chats:
		if D.hero_of(t) == hero:
			out.append(t)
	out.sort_custom(func(a, b): return int(st.chats[a].get("day", 0)) < int(st.chats[b].get("day", 0)))
	if tid != "" and tid in out:
		out.erase(tid)
		out.append(tid)
	return out


func _fill() -> void:
	for c in list.get_children():
		c.queue_free()
	var ctx: = P.ctx()
	var st: Dictionary = P.transport().state
	var fresh_msgs: = []
	var all: = []
	for t in _hero_tids():
		var c: Dictionary = st.chats[t]
		var tr_msgs: = C.transcript(st, t, ctx)
		all.append({"k": "note", "t": C.format(str(D.thread(t).get("title", "")), c.get("vars", {}), ctx), "tid": t, "i": -1})
		var fresh: bool = t == tid and int(c.get("unread", 0)) > 0 and c.get("picks", []).is_empty()
		for i in tr_msgs.size():
			var m: Dictionary = tr_msgs[i].duplicate()
			m.tid = t
			m.i = i
			if fresh:
				fresh_msgs.append(m)
			else:
				all.append(m)
	if tid != "":
		P.transport().open(tid, ctx)
	if all.size() > KEEP:
		all = all.slice(all.size() - KEEP)
	for m in all:
		_add(m, false)
	_scroll_end(false)
	if not fresh_msgs.is_empty():
		_play(fresh_msgs, func(): _build_bar())
	else:
		_build_bar()


func _add(m: Dictionary, animate: = true) -> V10Bubble:
	var b: = BUB.make(m, W * 0.74, hc)
	b.index = int(m.get("i", -1))
	b.set_meta("tid", str(m.get("tid", tid)))
	if b.kind == "note":
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var rk: = "%s#%d" % [str(m.get("tid", "")), b.index]
	var rr: Dictionary = P.transport().state.get("react", {})
	if not b.mine and rr.has(rk):
		b.set_react(_glyph(str(rr[rk])))
	list.add_child(b)
	_wire(b)
	while list.get_child_count() > KEEP + 2:
		var old: = list.get_child(0)
		list.remove_child(old)
		old.queue_free()
	if animate:
		b.appear()
	return b


func _wire(b: V10Bubble) -> void:
	if b.kind == "note" or b.kind == "typing":
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return
	var cb: = Callable()
	if b.kind == "photo":
		cb = func(): _view_photo(str(b.msg.get("img", "")))
	elif b.kind == "voice":
		cb = func(): _play_voice(b)
	elif b.kind == "sticker":
		cb = func(): V9Feel.success(b, "")
	else:
		cb = func(): pass
	var hold: = Callable()
	if not b.mine and b.index >= 0:
		hold = func(): _show_reactions(b)
	PUI.tap(b, cb, "" if b.kind == "text" else "pop", hold)


func _scroll_end(anim: = true) -> void:
	await get_tree().process_frame
	if not is_instance_valid(scroll):
		return
	await get_tree().process_frame
	if not is_instance_valid(scroll):
		return
	var to: = int(scroll.get_v_scroll_bar().max_value)
	if anim:
		var t: = create_tween()
		t.tween_property(scroll, "scroll_vertical", to, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		scroll.scroll_vertical = to


func _on_scroll_input(e: InputEvent) -> void:
	if busy and e is InputEventMouseButton and e.pressed:
		skip = true


# her messages arrive one by one: «печатает…» then the bubble with «тинь»
func _play(msgs: Array, done: Callable) -> void:
	busy = true
	skip = false
	for m in msgs:
		if not is_inside_tree():
			return
		var wait_ms: = 900
		match str(m.get("k", "text")):
			"text":
				wait_ms = C.typing_ms(str(m.get("t", "")))
			"voice":
				wait_ms = 1400
			"sticker":
				wait_ms = 650
		_set_typing(true, str(m.get("k", "text")) == "voice")
		var waited: = 0
		while waited < wait_ms and not skip:
			await get_tree().create_timer(0.05).timeout
			if not is_inside_tree():
				return
			waited += 50
			if waited % 150 == 0:
				PUI.snd("typing", randf_range(0.9, 1.15), -10.0)
		skip = false
		_set_typing(false)
		_add(m)
		PUI.snd("msg_in" if str(m.get("k", "")) != "sticker" else "sticker_pop", randf_range(0.98, 1.04))
		V9Feel.haptic("select")
		_bounce_avatar()
		_scroll_end()
		await get_tree().create_timer(0.18).timeout
	busy = false
	if done.is_valid():
		done.call()


func _set_typing(on: bool, voice: = false) -> void:
	status_l.text = ("записывает голосовое…" if voice else "печатает…") if on else "в сети"
	status_l.label_settings.font_color = hc.lerp(Color.WHITE, 0.4) if on else PUI.JADE_300
	if on and typing == null:
		typing = BUB.make({"who": "h", "k": "typing"}, W * 0.74, hc)
		typing.mouse_filter = Control.MOUSE_FILTER_IGNORE
		list.add_child(typing)
		typing.appear()
		_scroll_end()
	elif not on and typing != null:
		typing.queue_free()
		typing = null


func _bounce_avatar(amt: = 0.08) -> void:
	if not is_instance_valid(avatar) or PUI.calm():
		return
	var t: = avatar.create_tween()
	t.tween_property(avatar, "scale", Vector2.ONE * (1.0 + amt), 0.09).set_trans(Tween.TRANS_QUAD)
	t.tween_property(avatar, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# --- bottom bar: pills / sticker ---------------------------------------------------------

func _build_bar() -> void:
	for c in bar.get_children():
		c.queue_free()
	var ctx: = P.ctx()
	var v: = C.view(P.transport().state, tid, ctx) if tid != "" else {}
	var choices: Array = v.get("choices", [])
	var pills: = []
	var y: = 0.0
	var gap: = 12.0
	var pw: = W - 44.0
	var hs: = []
	for i in choices.size():
		var ch: Dictionary = choices[i]
		var ph: = 80.0
		if ch.has("t"):
			var th: = PUI.body(800).get_multiline_string_size(str(ch.t), HORIZONTAL_ALIGNMENT_LEFT, pw - 84, PUI.FS_BODY).y
			ph = maxf(80.0, th + 30.0)
		else:
			ph = 96.0
		hs.append(ph)
	var total: = 0.0
	for ph in hs:
		total += ph + gap
	var sticker_btn_h: = 0.0 if not choices.is_empty() else 92.0
	bar_h = total + sticker_btn_h + 34.0
	bar.position = Vector2(0, H - bar_h)
	bar.size = Vector2(W, bar_h)
	var bg: = PUI.grad_rect(Rect2(0, 0, W, bar_h), Color(0.07, 0.05, 0.07, 0.0), Color(0.07, 0.05, 0.07, 0.96))
	bar.add_child(bg)
	scroll.size.y = H - HEAD_H - bar_h + 18.0
	y = 18.0
	# 2–3 reply pills are one action: the screen's primary (§3.4 «Телефон / чат»)
	var group: = Control.new()
	group.name = "Pills"
	group.size = bar.size
	group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(group)
	if not choices.is_empty():
		PUI.role(group, "primary")
	for i in choices.size():
		var ch: Dictionary = choices[i]
		var p: = _pill(ch, Rect2(22, y, pw, hs[i]), i)
		group.add_child(p)
		PUI.pop_in(p, 0.06 * i, 0.85, 0.36)
		pills.append(p)
		y += hs[i] + gap
	if choices.is_empty():
		var sb: = _sticker_button(Rect2(22, y, pw, 80))
		PUI.role(sb, "primary")      # the conversation is over: a sticker is the one thing left to do
		bar.add_child(sb)
		PUI.pop_in(sb, 0.0, 0.9)
	_scroll_end(false)


func _pill(ch: Dictionary, r: Rect2, i: int) -> Control:
	var c: = Control.new()
	c.name = "Pill%d" % i
	c.position = r.position
	c.size = r.size
	c.pivot_offset = r.size * 0.5
	var sb: = PUI.box(Color(0.16, 0.11, 0.15, 0.96), minf(r.size.y * 0.5, 40.0), 2.0, Color(hc.lerp(PUI.GOLD, 0.5), 0.85))
	c.add_child(PUI.panel(Rect2(Vector2.ZERO, r.size), sb))
	var num: = PUI.label(["①", "②", "③"][mini(i, 2)], PUI.FS_BODY, PUI.GOLD, PUI.body(900))
	num.position = Vector2(18, (r.size.y - 36) * 0.5)
	num.size = Vector2(36, 36)
	num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	c.add_child(num)
	if ch.has("sticker"):
		var t: = P.sticker_tex(str(ch.sticker))
		if t != null:
			var tr: = TextureRect.new()
			tr.texture = t
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.position = Vector2(64, 6)
			tr.size = Vector2(84, 84)
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			c.add_child(tr)
		var lb: = PUI.label("Стикер «%s»" % str(D.sticker(str(ch.sticker)).get("label", "")), PUI.FS_BODY, PUI.TEXT, PUI.body(800))
		lb.position = Vector2(160, 0)
		lb.size = Vector2(r.size.x - 180, r.size.y)
		lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		c.add_child(lb)
	else:
		var l: = PUI.label(str(ch.get("t", "")), PUI.FS_BODY, PUI.TEXT, PUI.body(800))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.position = Vector2(62, 0)
		l.size = Vector2(r.size.x - 84, r.size.y)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		c.add_child(l)
	PUI.tap(c, func(): choose(i), "")
	return c


func _sticker_button(r: Rect2) -> Control:
	var c: = Control.new()
	c.name = "StickerBtn"
	c.position = r.position
	c.size = r.size
	c.pivot_offset = r.size * 0.5
	c.add_child(PUI.panel(Rect2(Vector2.ZERO, r.size), PUI.box(Color(0.2, 0.13, 0.17, 0.96), r.size.y * 0.5, 2.0, Color(PUI.GOLD, 0.7))))
	var l: = PUI.label("✿  Отправить стикер", PUI.FS_BODY, PUI.GOLD, PUI.body(900))
	l.size = r.size
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	c.add_child(l)
	PUI.tap(c, open_tray, "pop")
	return c


func choose(i: int) -> void:
	if busy or tid == "":
		return
	var ctx: = P.ctx()
	var r: Dictionary = P.transport().choose(tid, i, ctx)
	if not r.get("ok", false):
		return
	for c in bar.get_children():
		c.queue_free()
	var me: Dictionary = r.me.duplicate()
	me.tid = tid
	me.i = -1
	var b: = _add(me)
	PUI.snd("msg_out" if me.k == "text" else "sticker_pop")
	V9Feel.haptic("button")
	_scroll_end()
	var given: = P.gain(r.get("effects", []))
	G.save()
	var tr_n: = C.transcript(P.transport().state, tid, ctx).size()
	var msgs: = []
	var base: = tr_n - (r.msgs as Array).size()
	for k in (r.msgs as Array).size():
		var m: Dictionary = r.msgs[k].duplicate()
		m.tid = tid
		m.i = base + k
		msgs.append(m)
	await get_tree().create_timer(0.35).timeout
	if not is_inside_tree():
		return
	_play(msgs, func():
		if r.get("done", false):
			_finished(given)
		_build_bar())


func _finished(given: int) -> void:
	var n: Dictionary = {"who": "h", "k": "note", "t": "Разговор окончен", "tid": tid, "i": -1}
	_add(n)
	if given > 0:
		_aff_chip(given)
	V9Feel.success(avatar, "sparkle")


func _aff_chip(n: int) -> void:
	var chip: = Control.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.position = Vector2(W * 0.5 - 70, HEAD_H + 30)
	chip.size = Vector2(140, 52)
	chip.pivot_offset = chip.size * 0.5
	chip.add_child(PUI.panel(Rect2(Vector2.ZERO, chip.size), PUI.box(PUI.HEART_DEEP, 26)))
	var l: = PUI.label("♥ +%d" % n, PUI.FS_BODY, Color.WHITE, PUI.body(900))
	l.size = chip.size
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chip.add_child(l)
	add_child(chip)
	PUI.pop_in(chip, 0.0, 0.4, 0.5)
	PUI.burst(self, chip.position + chip.size * 0.5, PUI.HEART, 10, "♥", 110)
	var t: = chip.create_tween()
	t.tween_interval(1.4)
	if not PUI.calm():
		t.tween_property(chip, "position:y", chip.position.y - 40, 0.4)
	t.parallel().tween_property(chip, "modulate:a", 0.0, 0.4 if not PUI.calm() else 0.12)
	t.tween_callback(chip.queue_free)


# --- reactions ---------------------------------------------------------------------------

func _glyph(rid: String) -> String:
	for r in D.meta().get("reactions", []):
		if str(r.id) == rid:
			return str(r.glyph)
	return "♥"


func _show_reactions(b: V10Bubble) -> void:
	if react_bar != null and is_instance_valid(react_bar):
		react_bar.queue_free()
	var rs: Array = D.meta().get("reactions", [])
	var w: = 80.0 * rs.size() + 16.0
	var c: = Control.new()
	c.name = "Reactions"
	PUI.role(c, "primary")
	var gp: = b.get_global_rect().position - get_global_rect().position
	c.position = Vector2(clampf(gp.x, 12, maxf(12.0, W - w - 12)), clampf(gp.y - 100, HEAD_H + 6, H - 220))
	c.size = Vector2(w, 92)
	c.pivot_offset = Vector2(40, 92)
	c.add_child(PUI.panel(Rect2(Vector2.ZERO, c.size), PUI.box(Color(0.15, 0.1, 0.13, 0.98), 46, 2.0, Color(PUI.GOLD, 0.6))))
	for i in rs.size():
		var r: Dictionary = rs[i]
		var it: = Control.new()
		it.position = Vector2(8 + i * 80, 6)
		it.size = Vector2(80, 80)
		it.pivot_offset = it.size * 0.5
		var gl: = PUI.label(str(r.glyph), PUI.FS_H3, PUI.ROSE_300 if r.id != "tea" else PUI.JADE_300, PUI.body(900))
		gl.size = it.size
		gl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		gl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		it.add_child(gl)
		c.add_child(it)
		PUI.pop_in(it, 0.03 * i, 0.3, 0.32)
		var rid: = str(r.id)
		PUI.tap(it, func(): _react(b, rid, str(r.glyph)), "")
	add_child(c)
	react_bar = c
	PUI.pop_in(c, 0.0, 0.7, 0.3)
	var shade: = Control.new()
	shade.name = "ReactShade"
	shade.size = size
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	move_child(shade, c.get_index())
	shade.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			shade.queue_free()
			if is_instance_valid(c):
				c.queue_free())
	c.tree_exiting.connect(func():
		if is_instance_valid(shade):
			shade.queue_free())


func _react(b: V10Bubble, rid: String, glyph: String) -> void:
	if react_bar != null and is_instance_valid(react_bar):
		react_bar.queue_free()
	var t: = str(b.get_meta("tid", tid))
	var r: Dictionary = P.transport().react(t, b.index, rid, P.ctx())
	if not r.get("ok", false):
		return
	b.set_react(glyph)
	PUI.snd("react")
	V9Feel.success(b, "")
	G.save()
	var reply: = str(r.get("reply", ""))
	if reply != "" and not busy:
		await get_tree().create_timer(0.5).timeout
		if is_inside_tree():
			_play([{"who": "h", "k": "text", "t": reply, "tid": t, "i": -1}], Callable())


# --- stickers ----------------------------------------------------------------------------

func open_tray() -> void:
	if busy or (tray != null and is_instance_valid(tray)):
		return
	tray = TRAY.new()
	add_child(tray)
	tray.build(W, minf(H * 0.62, 104.0 + 2.0 * (W - 28.0) / 4.0 + 44.0), hero)
	tray.position = Vector2(0, H)
	tray.picked.connect(_send_sticker)
	tray.closed.connect(func(): tray = null)
	tray.slide_in(H)


func _send_sticker(sid: String) -> void:
	if busy:
		return
	var r: Dictionary = P.transport().sticker(hero, sid, P.ctx())
	if not r.get("ok", false):
		V9Feel.haptic("deny")      # the interface never shakes (§6.7)
		return
	var b: = _add({"who": "me", "k": "sticker", "id": sid, "tid": tid, "i": -1})
	PUI.snd("sticker_pop")
	V9Feel.haptic("select")        # secondary action: lighter than the reply pill («button», §7.4)
	if not PUI.calm():
		b.scale = Vector2(0.2, 0.2)
		var t: = b.create_tween()
		t.tween_property(b, "scale", Vector2.ONE * 1.12, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(b, "scale", Vector2.ONE, 0.18)
	_scroll_end()
	G.save()
	var reply: = str(r.get("reply", ""))
	if reply != "":
		await get_tree().create_timer(0.45).timeout
		if is_inside_tree():
			_play([{"who": "h", "k": "text", "t": reply, "tid": tid, "i": -1}], Callable())


# --- photo & voice -----------------------------------------------------------------------

func _view_photo(img: String) -> void:
	var t: = P.photo_tex(img)
	if t == null:
		return
	var v: = Control.new()
	v.name = "PhotoView"
	v.size = size
	v.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim: = ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.02, 0.92)
	dim.size = size
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(dim)
	var r: = Rect2(18, 70, W - 36, H - 140)
	var art: = Common.card_art(t, r, Vector2(0.5, 0.35), 1.0, 26.0)
	(art.material as ShaderMaterial).set_shader_parameter("bottom_shade", 0.0)
	art.pivot_offset = r.size * 0.5
	v.add_child(art)
	add_child(v)
	PUI.pop_in(art, 0.0, 0.85, 0.36)
	PUI.snd("tab")
	v.gui_input.connect(func(e):
		if e is InputEventMouseButton and not e.pressed:
			var tw: = v.create_tween()
			tw.tween_property(v, "modulate:a", 0.0, 0.18)
			tw.tween_callback(v.queue_free))
	viewer = v


func _play_voice(b: V10Bubble) -> void:
	if b.voice_t >= 0.0 and b.voice_t < 1.0:
		return
	var sec: = float(b.msg.get("sec", 3))
	b.voice_t = 0.0
	var t: = b.create_tween()
	t.tween_method(func(v):
		b.voice_t = v
		b.queue_redraw()
		# lip-sync: the avatar «speaks» with small bounces on the waveform beats
		if is_instance_valid(avatar) and not PUI.calm():
			avatar.scale = Vector2.ONE * (1.0 + 0.035 * absf(sin(v * sec * 11.0)))
		, 0.0, 1.0, sec)
	t.tween_callback(func():
		b.voice_t = -1.0
		b.queue_redraw()
		if is_instance_valid(avatar):
			avatar.scale = Vector2.ONE)
	PUI.snd("tab")


# dev / runner automation
func dev_act(a: String) -> void:
	match a:
		"skip":
			skip = true
		"pick0":
			choose(0)
		"pick1":
			choose(1)
		"tray":
			open_tray()
		"react":
			for c in list.get_children():
				if c is V10Bubble and not c.mine and c.index >= 0:
					_show_reactions(c)
					return
		"photo":
			for c in list.get_children():
				if c is V10Bubble and c.kind == "photo":
					_view_photo(str(c.msg.get("img", "")))
					return
