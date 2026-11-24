extends Control

# «Телефон» (docs/0.10-spec.md §Р8–Р9): a lacquered game phone that slides up from the bottom with a 0.4 s spring
# over the home screen. Tabs Лента · Чаты · Почта (tap or swipe), unread badges, chats with typing / pills / stickers
# / reactions, the feed with likes and replies, the 0.9 letters. Case colours follow the HUD; an SSR partner tints the
# lacquer with her colour. Two ways to show it:
#   V10Phone.open(main, {tab = "chats"})      overlay over the current screen (recommended: home stays behind)
#   main.go("phone", {tab = "mail"})          as a screen of main.SCREENS (backdrop drawn by itself)
# args: tab ("feed" | "chats" | "mail"), hero (open her chat), letter (open a letter id).
# dev_act(a): "feed" "chats" "mail" "chat:<hero>" "close" + the active view's own actions.

const P: = preload("res://scripts/v10/phone/phone.gd")
const PUI: = preload("res://scripts/v10/phone/phone_ui.gd")
const LIST: = preload("res://scripts/v10/phone/chat_list.gd")
const VIEW: = preload("res://scripts/v10/phone/chat_view.gd")
const FEEDV: = preload("res://scripts/v10/phone/feed_view.gd")
const MAILV: = preload("res://scripts/v10/phone/mail_view.gd")
const PICK: = preload("res://scripts/v10/phone/name_picker.gd")

const TAB_NAMES: = {"feed": "Лента", "chats": "Чаты", "mail": "Почта"}
const BEZEL: = 14.0
const CASE_R: = 58.0
const SCREEN_R: = 44.0
const HEAD_H: = 92.0
const TABS_H: = 70.0

var main
var W: = 720.0
var H: = 1280.0
var overlay_mode: = false
var dim: ColorRect
var frame: Control
var screen: Control
var pager: Control
var tabs: Control
var indicator: Panel
var tab: = "chats"
var pages: = {}
var chat: Control = null
var picker: Control = null
var closing: = false
var fr: Rect2
var sr: Rect2
var _swipe: = {"on": false, "p": Vector2.ZERO, "t": 0}


class CornerMask extends Control:
	# paints the lacquer over the four corners of the inner screen so the clipped content looks rounded
	var r: = 44.0
	var top_col: = Color.BLACK
	var bot_col: = Color.BLACK

	func _draw() -> void:
		var corners: = [[Vector2(0, 0), Vector2(r, r), PI, top_col], [Vector2(size.x, 0), Vector2(size.x - r, r), PI * 1.5, top_col],
			[Vector2(size.x, size.y), Vector2(size.x - r, size.y - r), 0.0, bot_col], [Vector2(0, size.y), Vector2(r, size.y - r), PI * 0.5, bot_col]]
		for c in corners:
			var pts: = PackedVector2Array([c[0]])
			for i in 13:
				var a: float = c[2] + (PI * 0.5) * i / 12.0
				pts.append(c[1] + Vector2(cos(a), sin(a)) * r)
			draw_colored_polygon(pts, c[3])


# --- entry points ---------------------------------------------------------------------------

func build(m, args: Dictionary) -> void:
	overlay_mode = false
	_build(m, args)


func build_overlay(m, args: Dictionary) -> void:
	overlay_mode = true
	_build(m, args)


func _build(m, args: Dictionary) -> void:
	main = m
	W = size.x
	H = size.y
	name = "Phone"
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_meta("v8_back", back)
	if main != null and main.has_method("show_chrome") and not overlay_mode:
		main.show_chrome(false, false)
	P.ensure()
	P.tick()
	G.save()
	if overlay_mode:
		dim = ColorRect.new()
		dim.color = Color(0.03, 0.015, 0.03, 0.0)
		dim.size = size
		dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(dim)
		dim.create_tween().tween_property(dim, "color:a", 0.62, 0.3)
	else:
		Common.backdrop(self, "menu", size, 1.0, 0.5, Color(1, 0.95, 0.96), Vector2(0.5, 0.4))
		dim = ColorRect.new()
		dim.color = Color(0.03, 0.015, 0.03, 0.45)
		dim.size = size
		dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(dim)
	_frame()
	tab = str(args.get("tab", P.st().tab))
	if not tab in TAB_NAMES:
		tab = "chats"
	_tabs()
	_pager()
	select(tab, false)
	_slide_up()
	if args.has("hero"):
		open_chat.call_deferred(str(args.hero), "")
	elif args.has("letter"):
		(func():
			select("mail", false)
			(_page("mail") as V10MailView).open_letter(int(args.letter))).call_deferred()
	elif tab == "chats" and not bool(P.st().named):
		ask_name.call_deferred()


# frame size: a phone at any aspect — tall phones use the whole height, tablets and wide screens keep a phone
# proportion (≤ 0.62 of the height) centred, never narrower than 560
func layout_rect() -> Rect2:
	var top: = clampf(H * 0.04, 26.0, 90.0)
	var bottom: = clampf(H * 0.018, 12.0, 40.0)
	var fh: = H - top - bottom
	var fw: = minf(W - 24.0, maxf(560.0, fh * 0.6))
	fw = minf(fw, W - 24.0)
	return Rect2((W - fw) * 0.5, top, fw, fh)


func case_colors() -> Array:
	var a: = PUI.LACQUER_A
	var b: = PUI.LACQUER_B
	var partner: = str(G.S.get("partner", "mc"))
	var oid: = str(G.S.get("outfit", {}).get(partner, ""))
	for it in G.ITEMS:
		if str(it.get("id", "")) == oid and str(it.get("rar", "")) == "SSR":
			var hc: = P.hero_color(partner)
			a = a.lerp(hc.darkened(0.35), 0.45)
			b = b.lerp(hc.darkened(0.7), 0.35)
	return [a, b]


func _frame() -> void:
	fr = layout_rect()
	frame = Control.new()
	frame.name = "Frame"
	frame.position = fr.position
	frame.size = fr.size
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	var cc: = case_colors()
	var case: = RBox.new()
	case.position = Vector2.ZERO
	case.size = fr.size
	case.setup(cc[0], cc[1], CASE_R, 4.0, 22.0)
	case.borders(Color("f3d99a"), PUI.GOLD_D)
	case.set_param("gloss", 0.12)
	case.name = "Case"
	frame.add_child(case)
	# side keys (physical, not an OS imitation)
	for k in [[fr.size.x - 2, 220.0, 120.0], [-4, 200.0, 70.0], [-4, 290.0, 70.0]]:
		var key: = PUI.panel(Rect2(k[0], k[1], 6, k[2]), PUI.box(PUI.GOLD_D, 3))
		frame.add_child(key)
		frame.move_child(key, 0)
	sr = Rect2(BEZEL, BEZEL + 8, fr.size.x - BEZEL * 2, fr.size.y - BEZEL * 2 - 8)
	screen = Control.new()
	screen.name = "Screen"
	screen.position = sr.position
	screen.size = sr.size
	screen.clip_contents = true
	frame.add_child(screen)
	screen.add_child(PUI.grad_rect(Rect2(Vector2.ZERO, sr.size), PUI.SCREEN_A, PUI.SCREEN_B))
	# a soft glow of the partner's colour at the top of the screen
	var glow: = PUI.grad_rect(Rect2(0, 0, sr.size.x, 260), Color(P.hero_color(str(G.S.get("partner", "mc"))), 0.16), Color(0, 0, 0, 0))
	screen.add_child(glow)
	var mask: = CornerMask.new()
	mask.name = "Corners"
	mask.size = sr.size
	mask.position = sr.position
	mask.r = SCREEN_R
	mask.top_col = (cc[0] as Color).lerp(cc[1], sr.position.y / fr.size.y)
	mask.bot_col = (cc[0] as Color).lerp(cc[1], sr.end.y / fr.size.y)
	mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(mask)
	# speaker slit in the top bezel
	frame.add_child(PUI.panel(Rect2(fr.size.x * 0.5 - 48, 9, 96, 8), PUI.box(Color(0, 0, 0, 0.55), 4, 1.0, Color(PUI.GOLD, 0.35))))
	# head: title in handwriting + close
	var title: = PUI.label("Телефон", 46 if PUI.has_caveat() else 34, PUI.GOLD, PUI.hand(), 4, Color(0.12, 0.04, 0.07, 0.85))
	title.position = Vector2(30, 18 if PUI.has_caveat() else 26)
	title.size = Vector2(300, 60)
	screen.add_child(title)
	var close_b: = Control.new()
	close_b.name = "Close"
	close_b.position = Vector2(sr.size.x - 84, 16)
	close_b.size = Vector2(64, 64)
	close_b.pivot_offset = close_b.size * 0.5
	close_b.add_child(PUI.panel(Rect2(6, 6, 52, 52), PUI.box(Color(1, 1, 1, 0.07), 26, 1.5, Color(PUI.GOLD, 0.5))))
	var xl: = PUI.label("✕", 26, PUI.TEXT, PUI.body(900))
	xl.size = close_b.size
	xl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	xl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	close_b.add_child(xl)
	screen.add_child(close_b)
	PUI.tap(close_b, back, "tap")


func _tabs() -> void:
	tabs = Control.new()
	tabs.name = "Tabs"
	tabs.position = Vector2(18, HEAD_H)
	tabs.size = Vector2(sr.size.x - 36, TABS_H - 12)
	screen.add_child(tabs)
	tabs.add_child(PUI.panel(Rect2(Vector2.ZERO, tabs.size), PUI.box(Color(0, 0, 0, 0.3), tabs.size.y * 0.5, 1.0, Color(1, 1, 1, 0.08))))
	var tw: = tabs.size.x / 3.0
	indicator = PUI.panel(Rect2(4, 4, tw - 8, tabs.size.y - 8), PUI.box(Color(PUI.GOLD, 0.22), (tabs.size.y - 8) * 0.5, 2.0, Color(PUI.GOLD, 0.85), 6, Color(0.6, 0.4, 0.1, 0.25)))
	indicator.name = "Indicator"
	tabs.add_child(indicator)
	var i: = 0
	for k in ["feed", "chats", "mail"]:
		var c: = Control.new()
		c.name = "Tab_" + k
		c.position = Vector2(i * tw, 0)
		c.size = Vector2(tw, tabs.size.y)
		c.pivot_offset = c.size * 0.5
		var l: = PUI.label(TAB_NAMES[k], 23, PUI.TEXT, PUI.body(900))
		l.name = "L"
		l.size = c.size
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		c.add_child(l)
		var tw_txt: = PUI.body(900).get_string_size(TAB_NAMES[k], HORIZONTAL_ALIGNMENT_LEFT, -1, 23).x
		var bd: = PUI.badge(0, Vector2(tw * 0.5 + tw_txt * 0.5 + 16, 12))
		bd.name = "Badge"
		c.add_child(bd)
		tabs.add_child(c)
		var kk: String = k
		PUI.tap(c, func(): select(kk), "")
		i += 1
	refresh_badges()


func refresh_badges() -> void:
	if tabs == null:
		return
	var b: = P.badge_parts()
	for k in ["feed", "chats", "mail"]:
		var c: = tabs.get_node_or_null("Tab_" + k)
		if c == null:
			continue
		var old: = c.get_node_or_null("Badge")
		var n: = int(b[k])
		var shown: bool = old != null and old.visible
		if old != null:
			c.remove_child(old)
			old.queue_free()
		var tw_txt: = PUI.body(900).get_string_size(TAB_NAMES[k], HORIZONTAL_ALIGNMENT_LEFT, -1, 23).x
		var bd: = PUI.badge(n, Vector2(c.size.x * 0.5 + tw_txt * 0.5 + 16, 12))
		bd.name = "Badge"
		c.add_child(bd)
		if n > 0 and not shown:
			PUI.pop_in(bd, 0.25, 0.3, 0.4)


func _pager() -> void:
	pager = Control.new()
	pager.name = "Pager"
	pager.position = Vector2(0, HEAD_H + TABS_H)
	pager.size = Vector2(sr.size.x, sr.size.y - HEAD_H - TABS_H)
	pager.clip_contents = true
	screen.add_child(pager)


func _page(k: String) -> Control:
	if pages.has(k) and is_instance_valid(pages[k]):
		return pages[k]
	var pw: = pager.size.x
	var ph: = pager.size.y
	var p: Control
	match k:
		"feed":
			p = FEEDV.new()
			pager.add_child(p)
			p.build(pw, ph)
		"chats":
			p = LIST.new()
			pager.add_child(p)
			p.build(pw, ph)
			p.open_chat.connect(open_chat)
			p.rename.connect(ask_name)
		_:
			p = MAILV.new()
			pager.add_child(p)
			p.build(pw, ph)
			p.open_legacy.connect(func():
				if main != null and main.has_method("go"):
					close_now()
					main.go("letters"))
	pages[k] = p
	return p


func select(k: String, anim: = true) -> void:
	if not k in TAB_NAMES:
		return
	var order: = ["feed", "chats", "mail"]
	var from: = order.find(tab)
	var to: = order.find(k)
	var changed: = k != tab
	tab = k
	P.st().tab = k
	var pg: = _page(k)
	var pw: = pager.size.x
	for key in pages:
		var p: Control = pages[key]
		if not is_instance_valid(p):
			continue
		if p == pg:
			p.visible = true
			if anim and changed:
				p.position.x = pw * 0.35 * signf(to - from)
				p.modulate.a = 0.0
				var t: = p.create_tween().set_parallel()
				t.tween_property(p, "position:x", 0.0, 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
				t.tween_property(p, "modulate:a", 1.0, 0.2)
			else:
				p.position.x = 0.0
				p.modulate.a = 1.0
		else:
			p.visible = false
	var tw: = tabs.size.x / 3.0
	if anim:
		var it: = indicator.create_tween()
		it.tween_property(indicator, "position:x", to * tw + 4, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		indicator.position.x = to * tw + 4
	for key in order:
		var l: Label = tabs.get_node("Tab_%s/L" % key)
		l.label_settings.font_color = PUI.GOLD if key == k else PUI.MUTED
	if anim and changed:
		PUI.snd("tab")
		V9Feel.haptic("select")
	if k == "feed" and pg.has_method("refresh") and changed:
		pass
	refresh_badges.call_deferred()


# --- chats ---------------------------------------------------------------------------------

func open_chat(hero: String, tid: String) -> void:
	if chat != null and is_instance_valid(chat):
		chat.queue_free()
	chat = VIEW.new()
	screen.add_child(chat)
	chat.build(sr.size.x, sr.size.y, hero, tid)
	chat.slide_in()
	chat.closed.connect(func():
		chat = null
		var l: Variant = pages.get("chats")
		if l != null and is_instance_valid(l):
			l.refresh()
		refresh_badges())
	refresh_badges.call_deferred()


func ask_name() -> void:
	if picker != null and is_instance_valid(picker):
		return
	picker = PICK.new()
	screen.add_child(picker)
	picker.build(sr.size.x, sr.size.y)
	picker.done.connect(func():
		picker = null
		var l: Variant = pages.get("chats")
		if l != null and is_instance_valid(l):
			l.refresh())


# --- swipe between tabs ----------------------------------------------------------------------

func _input(e: InputEvent) -> void:
	if closing or chat != null or picker != null or not is_visible_in_tree():
		return
	var mail: Variant = pages.get("mail")
	if mail != null and is_instance_valid(mail) and (mail as V10MailView).page != null:
		return
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		var pr: = pager.get_global_rect()
		if e.pressed and pr.has_point(e.global_position):
			_swipe = {"on": true, "p": e.global_position, "t": Time.get_ticks_msec()}
		elif not e.pressed and _swipe.on:
			_swipe.on = false
			var d: Vector2 = e.global_position - _swipe.p
			if absf(d.x) > 110.0 and absf(d.y) < absf(d.x) * 0.5 and Time.get_ticks_msec() - int(_swipe.t) < 600:
				var order: = ["feed", "chats", "mail"]
				var i: = clampi(order.find(tab) + (-1 if d.x < 0 else 1) * -1, 0, 2)
				if order[i] != tab:
					select(order[i])


# --- open / close ---------------------------------------------------------------------------

func _slide_up() -> void:
	frame.position.y = H + 20
	PUI.snd("phone_open")
	V9Feel.haptic("button")
	var t: = frame.create_tween()
	t.tween_property(frame, "position:y", fr.position.y, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# Android «назад»: the innermost layer first (reactions/tray/photo → chat → letter → name picker → phone)
func back() -> void:
	if closing:
		return
	if chat != null and is_instance_valid(chat):
		for n in ["PhotoView", "Reactions", "StickerTray"]:
			var x: = chat.get_node_or_null(n)
			if x != null:
				if x.has_method("dismiss"):
					x.dismiss()
				else:
					x.queue_free()
				return
		chat.close()
		return
	var mail: Variant = pages.get("mail")
	if mail != null and is_instance_valid(mail) and (mail as V10MailView).page != null:
		mail.close_letter()
		return
	if picker != null and is_instance_valid(picker):
		picker.queue_free()
		picker = null
		return
	close()


func close() -> void:
	if closing:
		return
	closing = true
	G.save()
	PUI.snd("phone_close")
	var t: = create_tween().set_parallel()
	t.tween_property(frame, "position:y", H + 40, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.tween_property(dim, "color:a", 0.0, 0.3)
	t.chain().tween_callback(func():
		if overlay_mode:
			queue_free()
		elif main != null and main.has_method("back"):
			main.back()
		else:
			queue_free())


func close_now() -> void:
	closing = true
	queue_free()


func dev_act(a: String) -> void:
	if a in TAB_NAMES:
		select(a)
	elif a.begins_with("chat:"):
		open_chat(a.substr(5), "")
	elif a == "close":
		back()
	elif a == "name":
		ask_name()
	elif a.begins_with("pick:") and picker != null:
		picker._pick(a.substr(5))
	elif chat != null and is_instance_valid(chat):
		chat.dev_act(a)
	elif pages.has(tab) and pages[tab].has_method("dev_act"):
		pages[tab].dev_act(a)
	elif a.begins_with("letter") and pages.has("mail"):
		var ls: = V9Letters.list()
		if not ls.is_empty():
			pages.mail.open_letter(int(ls[0].id))
