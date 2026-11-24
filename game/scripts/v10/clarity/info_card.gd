class_name V10InfoCard
extends Control

# The small card «За что / Как получить снова» for one glossary entry (victory rows, glossary rows, legend, tile bubble).
#   V10InfoCard.open(host, "bonus.clean", {"count": 3, "points": "+4", "new": true})
# host: any node in the tree; the card goes to main.overlay when there is one (above the result window), else to the
# viewport root. A tap outside or «Понятно» closes it. «Весь словарь» opens V10GlossaryScreen at the entry's section.
# Also: open_text(host, title, icon, lines) for the summary card («Почему такие награды?»).

const W: = 600.0

var card: Control
var _closing: = false

static func layer_for(host: Node) -> Node:
	var m = host.get("main") if host else null
	if m == null and host and host.get_tree() and host.get_tree().current_scene:
		var cs: = host.get_tree().current_scene
		if cs.get("overlay") != null:
			m = cs
	if m != null and m.get("overlay") != null and is_instance_valid(m.overlay):
		return m.overlay
	return host.get_tree().root if host else null

static func open(host: Node, id: String, extra: = {}) -> V10InfoCard:
	var e: = V10Glossary.get_entry(id)
	if e.is_empty():
		return null
	var lines: = []
	# «За что» only for things you EARN; a tile, a suit, a rank or a league is described («Что это»)
	lines.append(["За что" if e.cat in ["bonus", "win", "combo", "event", "egg"] else "Что это", String(e.why)])
	if String(e.how) != "":
		lines.append(["Как получить снова" if e.cat in ["bonus", "win", "combo", "event", "egg", "fortune"] else "Как это работает", String(e.how)])
	var rw: String = extra.get("points", "") if extra.get("points", "") != "" else String(e.reward)
	if rw != "":
		lines.append(["Награда", rw])
	var foot: = ""
	if extra.has("count") and int(extra.count) > 0:
		foot = "Получено уже %d %s" % [int(extra.count), V8PlayRules.plural(int(extra.count), "раз", "раза", "раз")]
	return open_text(host, String(e.name), String(e.get("sub", "")), String(e.icon), lines, foot, bool(extra.get("new", false)), String(e.cat), bool(extra.get("no_more", false)))

static func open_text(host: Node, title: String, sub: String, icon: String, lines: Array, foot: = "", is_new: = false, cat: = "", no_more: = false) -> V10InfoCard:
	var layer: = layer_for(host)
	if layer == null:
		return null
	var vs: Vector2 = host.get_viewport().get_visible_rect().size
	var ic: = V10InfoCard.new()
	ic.name = "V10InfoCard"
	ic.size = vs
	ic.mouse_filter = Control.MOUSE_FILTER_STOP
	ic.z_index = 50
	layer.add_child(ic)
	ic._build(vs, title, sub, icon, lines, foot, is_new, cat, host, no_more)
	return ic

func _build(vs: Vector2, title: String, sub: String, icon: String, lines: Array, foot: String, is_new: bool, cat: String, host: Node, no_more: bool) -> void:
	var dim: = ColorRect.new()
	dim.size = vs
	dim.color = Color(0.03, 0.02, 0.035, 0.0)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	dim.create_tween().tween_property(dim, "color:a", 0.6, 0.2)
	var w: = minf(W, vs.x - 40.0)
	var tx: = 24.0
	var tw: = w - 48.0
	# measure
	var bf: = UI.font("body", 800)
	var h: = 30.0 + 104.0
	var blocks: = []
	for ln in lines:
		var th: float = bf.get_multiline_string_size(String(ln[1]), HORIZONTAL_ALIGNMENT_LEFT, tw, 21).y
		blocks.append(th)
		h += 28.0 + th + 12.0
	if foot != "":
		h += 34.0
	h += 96.0
	card = UI.rbox("cream", Rect2((vs.x - w) * 0.5, maxf(90.0, (vs.y - h) * 0.5), w, h), 30, 4, 12)
	card.borders(Color("ffe7a6"), Color("c58a2c"))
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(card)
	var art: = V8Art.nine("panel", Rect2(Vector2.ZERO, Vector2(w, minf(h, 300.0))))
	art.size = Vector2(w, h)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(art)
	card.cr.visible = false
	# head: icon + name + flavour
	var ico: = V10ClarityIcon.make(icon, 92, Vector2(tx - 4, 24))
	card.add_child(ico)
	var nl: = UI.title(title, 32, Color("ffe7a6"), Color("5a1a6a"))
	nl.position = Vector2(tx + 104, 28 if sub != "" else 42)
	nl.size = Vector2(w - tx - 124, 44)
	nl.clip_text = true
	nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	card.add_child(nl)
	var f: = UI.font_for("title", 32, 900)
	while nl.label_settings.font_size > 22 and f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, nl.label_settings.font_size).x > nl.size.x:
		nl.label_settings.font_size -= 1
	if sub != "":
		var sl: = UI.label(sub, 17, Color("c9bdb0"), UI.DARK, 2, "body", 800)
		sl.position = Vector2(tx + 106, 74)
		sl.size = Vector2(w - tx - 126, 26)
		sl.clip_text = true
		card.add_child(sl)
	if is_new:
		var nb: = UI.rbox("red", Rect2(w - 120, -14, 104, 30), 15, 2, 4)
		card.add_child(nb)
		nb.add_child(UI.center_label(UI.label("НОВОЕ", 16, Color.WHITE, UI.DARK, 2, "body", 900), Rect2(0, 0, 104, 30)))
	var y: = 30.0 + 104.0
	for i in lines.size():
		var cap: = UI.label(String(lines[i][0]) + ":", 18, Color("ffd98a"), UI.DARK, 2, "body", 900)
		cap.position = Vector2(tx, y)
		card.add_child(cap)
		y += 28.0
		var body: = UI.label(String(lines[i][1]), 21, UI.INK, UI.DARK, 2, "body", 800)
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.position = Vector2(tx, y)
		body.size = Vector2(tw, blocks[i] + 4.0)
		card.add_child(body)
		y += blocks[i] + 12.0
	if foot != "":
		var fl: = UI.label(foot, 17, Color("bfb3a8"), UI.DARK, 2, "body", 800)
		fl.position = Vector2(tx, y + 2)
		card.add_child(fl)
		y += 34.0
	var bw: = 200.0
	var ok: = JButton.make("Понятно", "pink", Rect2(w - tx - bw, h - 84, bw, 68), null, 24)
	ok.pressed.connect(close)
	card.add_child(ok)
	if not no_more:
		var more: = JButton.make("Весь словарь", "glass", Rect2(tx, h - 84, 220, 68), null, 21)
		more.pressed.connect(func():
			var c2: = cat
			var hh: = host
			close()
			if is_instance_valid(hh):
				V10GlossaryScreen.open(hh, c2))
		card.add_child(more)
	card.pivot_offset = card.size * 0.5
	UI.pop_in(card, 0.0, 0.8)
	Sfx.play("pop", 1.12, -4)

func _gui_input(e: InputEvent) -> void:
	if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
		if card and not Rect2(card.position, card.size).has_point(e.position):
			close()
			accept_event()

func close() -> void:
	if _closing:
		return
	_closing = true
	Sfx.play("tap")
	var t: = create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.15)
	t.tween_callback(queue_free)
