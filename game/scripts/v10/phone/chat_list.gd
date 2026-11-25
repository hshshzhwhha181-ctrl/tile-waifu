class_name V10ChatList
extends Control

# «Чаты» tab (§Р8 п.5): one row per heroine — avatar in a gold ring, her name in her handwriting, the last line,
# unread shown by tone (a lit row, a bright bold line) — the dots live on the tabs only (§3.6: ≤ 2 dots on a working
# screen, none that pulse); the partner is pinned on top. Heroines the player owns but who have not written yet stay in the list
# as quiet contacts («Скажи привет стикером»), so the phone is never empty. Header chip: how she calls you.

signal open_chat(hero: String, tid: String)
signal rename

const P: = preload("res://scripts/v10/phone/phone.gd")
const PUI: = preload("res://scripts/v10/phone/phone_ui.gd")
const D: = preload("res://scripts/v10/chat/chat_data.gd")

const ROW_H: = 118.0

var W: = 600.0
var H: = 900.0
var scroll: ScrollContainer
var list: VBoxContainer


func build(w: float, h: float) -> void:
	W = w
	H = h
	size = Vector2(W, H)
	name = "ChatList"
	scroll = ScrollContainer.new()
	scroll.size = size
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	add_child(scroll)
	list = VBoxContainer.new()
	list.custom_minimum_size = Vector2(W, 0)
	list.add_theme_constant_override("separation", 0)
	scroll.add_child(list)
	refresh()


func rows() -> Array:
	var ctx: = P.ctx()
	var out: Array = P.transport().list(ctx).get("rows", [])
	var have: = {}
	for r in out:
		have[r.hero] = true
	for h in ctx.owned:
		if not have.has(h):
			out.append({"hero": h, "tid": "", "title": "", "last": "", "dot": false, "pinned": h == ctx.partner, "day": -1})
	out.sort_custom(func(a, b):
		if a.pinned != b.pinned:
			return a.pinned
		if bool(a.dot) != bool(b.dot):
			return a.dot
		return int(a.day) > int(b.day))
	return out


func refresh() -> void:
	for c in list.get_children():
		c.queue_free()
	list.add_child(_name_chip())
	var i: = 0
	for r in rows():
		var row: = _row(r)
		if i == 0:
			PUI.role(row, "primary")      # the pinned partner / newest conversation: the one thing to tap
		list.add_child(row)
		PUI.pop_in(row, 0.04 + 0.05 * mini(i, 6), 0.92, 0.34)
		i += 1


# «Героини зовут тебя: …» — 48 px chip in an 80 px tap zone (role secondary)
func _name_chip() -> Control:
	var c: = Control.new()
	c.custom_minimum_size = Vector2(W, 88)
	var txt: = "Героини зовут тебя: %s" % P.name_label()
	var w: = minf(W - 40, PUI.body(800).get_string_size(txt + "  ✎", HORIZONTAL_ALIGNMENT_LEFT, -1, PUI.FS_CAPTION).x + 48)
	var chip: = Control.new()
	chip.name = "NameChip"
	chip.position = Vector2((W - w) * 0.5, 4)
	chip.size = Vector2(w, 80)
	chip.pivot_offset = chip.size * 0.5
	PUI.role(chip, "secondary")
	chip.add_child(PUI.panel(Rect2(0, 16, w, 48), PUI.box(Color(PUI.TEXT, 0.06), 24, 1.0, Color(PUI.GOLD, 0.35))))
	var l: = PUI.label(txt + "  ✎", PUI.FS_CAPTION, PUI.MUTED, PUI.body(800))
	l.size = chip.size
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	chip.add_child(l)
	c.add_child(chip)
	PUI.tap(chip, func(): rename.emit(), "pop")
	return c


func _row(r: Dictionary) -> Control:
	var h: String = r.hero
	var hc: = P.hero_color(h)
	var c: = Control.new()
	c.name = "Row_" + h
	c.custom_minimum_size = Vector2(W, ROW_H)
	c.size = Vector2(W, ROW_H)
	c.pivot_offset = c.size * 0.5
	var bg: = PUI.panel(Rect2(12, 6, W - 24, ROW_H - 12), PUI.box(Color(PUI.TEXT, 0.075) if r.dot else Color(PUI.TEXT, 0.035), 26, 1.0 if r.dot else 0.0, Color(hc, 0.45)))
	c.add_child(bg)
	var av: = V8Art.emotion_avatar(h, "happy" if r.dot else "shy" if int(G.aff_level(h)) >= 5 else "happy", Rect2(26, 14, 90, 90), "gold" if r.pinned else "glass")
	c.add_child(av)
	var nm: = PUI.label(P.hero_name(h), PUI.fs_hand(), hc.lerp(Color.WHITE, 0.45), PUI.hand())
	nm.position = Vector2(132, 8 if PUI.has_caveat() else 12)
	nm.size = Vector2(W - 260, 46)
	c.add_child(nm)
	var last: String = str(r.last)
	if str(r.tid) == "":
		last = "Скажи привет стикером"
	var ln: = PUI.label(last, PUI.FS_CAPTION, PUI.TEXT if r.dot else PUI.MUTED, PUI.body(900 if r.dot else 700))
	ln.position = Vector2(132, 62)
	ln.size = Vector2(W - 170, 30)
	PUI.ellipsize(ln, W - 170)
	c.add_child(ln)
	if r.pinned:
		var pin: = PUI.label("партнёр", PUI.FS_CAPTION, PUI.GOLD, PUI.body(900))
		pin.position = Vector2(W - 170, 20)
		pin.size = Vector2(140, 26)
		pin.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		c.add_child(pin)
	var tid: String = str(r.tid)
	PUI.tap(c, func(): open_chat.emit(h, tid), "pop")
	return c
