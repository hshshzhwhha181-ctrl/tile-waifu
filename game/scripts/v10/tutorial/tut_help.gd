class_name V10TutHelp
extends RefCounted
# «?» and «Как играть» sheets, and the «Откроется после партии N» toast (README §2.5; UX §2 п.4, §3.7, §4.1.9, §4.4,
# §6.4; HUD_V2 §2 «Лист»: surface night.700, radius 4 on top, a stack of M plates, H1 Display 44 by the left margin).
#
#   V10TutHelp.open(host, "teahouse")       # «?» of a screen: H1 + ≤ 3 rows (icon + ≤ 2 lines) + «Понятно» + «Подробнее»
#   V10TutHelp.open_how_to(host)            # «Как играть»: open topics (+ ≤ 1 teaser), hints switch, «Первая партия»
#   V10TutHelp.help_button(parent, rect_or_pos, host, topic)   # quiet 80×80 «?» button
#   V10TutHelp.settings_hook(main, popup)   # Settings «Как играть» row (closes popup before opening sheet, П-6)
#   V10TutHelp.close_all(host)
#   V10TutHelp.locked_toast(host, rect, V10Reveal.locked_text(id))
#
# One sheet at a time (UX §3.7 «окно поверх окна запрещено»): opening a sheet closes any previous sheet or popup,
# a topic tapped in «Как играть» (or «Подробнее» on «?») swaps the SAME sheet in place, «Словарь» closes the sheet first.

const LAYER: = 93
const SCREEN_TOPIC: = {
	"home": "teahouse", "levels": "tables", "tables": "tables", "v10path": "tables", "modes": "tables",
	"summon": "wishes", "wishes": "wishes", "odds": "wishes",
	"collection": "heroines", "heroines": "heroines",
	"shop": "shop", "play": "play", "victory": "victory",
	"salon": "salon", "v10salon": "salon", "v10scene": "salon", "room": "salon",
	"phone": "phone", "v10phone": "phone", "letters": "phone",
	"afisha": "today", "today": "today", "streak": "streak",
	"triples": "triples", "mj_triples": "triples",
	"riichi": "riichi", "mj_riichi": "riichi", "sanma": "riichi", "mj_sanma": "riichi",
	"koikoi": "koikoi", "mj_koikoi": "koikoi",
	"pagoda": "pagoda", "v10pagoda": "pagoda",
	"journey": "journey", "v10journey": "journey",
	"duels": "duels", "duel": "duels", "v10duel": "duels", "arena": "duels", "v7tourney": "tables",
}
# monoline icon of each «Как играть» topic (V10Icons.NAMES)
const TOPIC_ICON: = {
	"play": "tab_tables", "help_row": "hint", "priem": "avatar_ring", "teahouse": "tab_tea",
	"tables": "arrow_r", "salon": "heart", "wishes": "tab_wishes", "heroines": "tab_heroines", "phone": "phone",
	"today": "info", "streak": "heart", "shop": "tab_shop", "victory": "info", "tabs": "tab_tea",
	"triples": "tab_tables", "riichi": "tab_tables", "koikoi": "tab_tables",
	"pagoda": "arrow_r", "journey": "arrow_r", "duels": "tab_tables",
}
const TOPIC_GLOSSARY: = {
	"play": "rules", "help_row": "rules", "priem": "rules", "salon": "salon",
	"wishes": "wish", "shop": "wish", "heroines": "hero", "today": "afisha",
}
const MARGIN: = 32.0
const ROW_W: = 656
const ROW_STEP: = 88.0  # M plate 80 + 8
const SETTINGS_EXTRA: = 84.0

static var _sheet: WeakRef = null
static var _toast: WeakRef = null


static func topic_for_screen(screen_id: String) -> String:
	if V10TutLines.HELP.has(screen_id):
		return screen_id
	return String(SCREEN_TOPIC.get(screen_id, "play"))


static func open(host: Node, topic: String = "") -> Control:
	if topic == "":
		return open_how_to(host)
	var tp: = topic if V10TutLines.HELP.has(topic) else topic_for_screen(topic)
	if not V10TutLines.HELP.has(tp):
		return open_how_to(host)
	var sh: = _new_sheet(host)
	if sh == null:
		return null
	sh.show_topic(tp, false, false)
	return sh


static func open_how_to(host: Node) -> Control:
	var sh: = _new_sheet(host)
	if sh == null:
		return null
	sh.show_list(false)
	return sh


static func on_help(host: Node, topic: = "") -> Callable:
	return func() -> void:
		if V10Tutorial.inst != null and is_instance_valid(V10Tutorial.inst):
			V10Tutorial.inst._yield_coach()
		if topic == "":
			var m: = _main_of(host)
			var sid: = String(m.get("screen_id")) if m != null else ""
			open(host, topic_for_screen(sid))
		else:
			open(host, topic)


# Quiet 80×80 «?» button in HUD v2 style (UX §6.5 «Тихая»). Accepts a Rect2 or Vector2 position (or null = (0,0)).
static func help_button(parent: Control, pos_or_rect = null, host: Node = null, topic: = "") -> V10Button:
	var h: Node = host if host != null else parent
	var b: = V10Button.make("quiet", "", Vector2(80, 80))
	b.icon = "help"
	b.icon_color = V10DS.PAPER_300
	b.name = "HelpBtn"
	b.set_meta("ux_role", "tertiary")
	b.set_meta("tut_id", "help." + (topic if topic != "" else "screen"))
	if pos_or_rect is Rect2:
		var r: Rect2 = pos_or_rect
		b.position = r.position + (r.size - Vector2(80, 80)) * 0.5
	elif pos_or_rect is Vector2:
		b.position = pos_or_rect
	b.pressed.connect(on_help(h, topic))
	if parent != null:
		parent.add_child(b)
	return b


# Settings → «Как играть» row on main.gd's current Common.popup: closes the popup BEFORE opening the sheet (П-6).
static func settings_hook(main: Node, p: Control) -> Control:
	if p == null or not is_instance_valid(p):
		return null
	var y0: = p.size.y - 68.0
	for c in p.get_children():
		if c is Control and (c as Control).position.y >= y0 - 4.0 and c.name != "PanelArt":
			(c as Control).position.y += SETTINGS_EXTRA
	p.size.y += SETTINGS_EXTRA
	var root = p.get_meta("root") if p.has_meta("root") else null
	if root is Control and p.position.y + p.size.y > (root as Control).size.y - 10.0:
		p.position.y = maxf(20.0, (root as Control).size.y - 10.0 - p.size.y)
	var l: = UI.label(V10TutLines.ui("how_to"), 26, UI.INK, Color.WHITE, 3, "body", 900)
	l.position = Vector2(34, y0 + 2)
	p.add_child(l)
	var d: = UI.label(V10TutLines.ui("hints_sub"), 18, V10DS.PAPER_500)
	d.position = Vector2(34, y0 + 42)
	p.add_child(d)
	var b: = JButton.make("Открыть", "lav", Rect2(470, y0 + 8, 158, 64), null, 22)
	b.name = "HowToPlay"
	b.set_meta("tut_id", "settings.how_to")
	b.pressed.connect(func() -> void:
		Common.close_popup(p)
		open_how_to(main))
	p.add_child(b)
	return b


# HUD v2 M-plate row for the v2 Settings sheet: closes any open sheet/popup before opening «Как играть» (П-6).
static func settings_plate(main: Node, w: int = ROW_W) -> V10Plate:
	var pl: = V10Plate.make("M", w, V10TutLines.ui("how_to"), V10TutLines.ui("hints_sub"), "", "help")
	pl.on_art = false
	pl.interactive = true
	pl.right_slot = V10Icons.icon("arrow_r", 24, V10DS.PAPER_500)
	pl.name = "HowToPlate"
	pl.set_meta("ux_role", "secondary")
	pl.set_meta("tut_id", "settings.how_to")
	pl.pressed.connect(func() -> void:
		_close_popups(_main_of(main))
		open_how_to(main))
	return pl


static func close_all(_host: Node = null) -> void:
	var sh: = current()
	if sh != null:
		(sh as Sheet).close()
	_sheet = null


static func current() -> Control:
	if _sheet == null:
		return null
	var s = _sheet.get_ref()
	if s is Sheet and is_instance_valid(s) and not (s as Sheet).closing:
		return s
	return null


static func layer(host: Node) -> CanvasLayer:
	var root: = host.get_tree().root if host != null and host.is_inside_tree() else null
	if root == null:
		var ml: = Engine.get_main_loop()
		if ml is SceneTree:
			root = (ml as SceneTree).root
	if root == null:
		return null
	var l: = root.get_node_or_null("V10TutSheetLayer") as CanvasLayer
	if l == null:
		l = CanvasLayer.new()
		l.name = "V10TutSheetLayer"
		l.layer = LAYER
		l.process_mode = Node.PROCESS_MODE_ALWAYS
		root.add_child(l)
	return l


static func _new_sheet(host: Node) -> Sheet:
	close_all(host)
	var m: = _main_of(host)
	_close_popups(m)
	if V10Tutorial.inst != null and is_instance_valid(V10Tutorial.inst):
		V10Tutorial.inst._yield_coach()
	var l: = layer(host)
	if l == null:
		return null
	var sh: = Sheet.new()
	sh.host = host
	sh.main = m
	l.add_child(sh)
	_sheet = weakref(sh)
	return sh


# Never open a sheet over a popup or another bottom sheet (UX §3.7 / П-6).
static func _close_popups(main: Node) -> void:
	if main == null or not is_instance_valid(main):
		return
	var ov = main.get("overlay") if "overlay" in main else null
	if not (ov is Node):
		return
	for c in (ov as Node).get_children():
		if not is_instance_valid(c) or c.is_queued_for_deletion():
			continue
		if c.has_meta("closing"):
			continue
		if c.has_method("close"):
			c.call("close")
			continue
		if c.has_meta("popup"):
			var closed: = false
			for ch in c.get_children():
				if ch is Control and ch.has_meta("root"):
					Common.close_popup(ch as Control)
					closed = true
					break
			if not closed:
				c.set_meta("closing", true)
				c.visible = false
				c.queue_free()
		elif c.has_meta("v8_back") and c.get_meta("v8_back") is Callable:
			(c.get_meta("v8_back") as Callable).call()


static func _main_of(host: Node) -> Node:
	var m: = V10Tutorial.main_node()
	if m != null:
		return m
	var n: = host
	while n != null:
		if "screen_root" in n and "overlay" in n:
			return n
		n = n.get_parent()
	return null


# «Откроется после партии N» (UX §3.5): an S plate just above `at`, 160 ms in, 1.6 s, 160 ms out. No error buzz.
static func locked_toast(host: Node, at: Rect2, text: String) -> void:
	var l: = layer(host)
	if l == null or text == "":
		return
	if _toast != null:
		var old = _toast.get_ref()
		if old is Control and is_instance_valid(old):
			(old as Node).name = "_closing_toast"
			(old as Control).visible = false
			(old as Control).queue_free()
	var vs: = l.get_viewport().get_visible_rect().size
	var ins: = V10Hud2Util.safe_insets(vs)
	var cx: = floorf(maxf(0.0, (vs.x - 720.0) * 0.5))
	var need: = ceilf(V10Type.text_w(text, "ui", 22)) + 2.0 * float(V10DS.PLATE_PAD.S) + 4.0
	var p: = V10Plate.new()
	p.size_class = "S"
	if need <= 288.0:
		var w: int = 288
		for m in V10DS.PLATE_WIDTHS.S:
			if float(m) >= need:
				w = int(m)
				break
		p.plate_w = w
	else:
		p.snap_width = false  # a long locked text keeps UI 22 instead of an ellipsis (HUD_V2 §2.3 fit last resort)
		p.plate_w = int(minf(656.0, ceilf(need / 8.0) * 8.0))
	p.title = text
	p.name = "V10TutToast"
	p.set_meta("tut_id", "tut.toast")
	var sz: = Vector2(p.plate_w, V10DS.PLATE_H.S)
	var x: = clampf(at.get_center().x - sz.x * 0.5, cx + 16.0, cx + minf(720.0, vs.x) - 16.0 - sz.x)
	var y: = at.position.y - 12.0 - sz.y
	if y < float(ins.top) + 8.0:
		y = at.end.y + 12.0
	y = minf(y, vs.y - float(ins.bottom) - 8.0 - sz.y)
	p.position = Vector2(roundf(x), roundf(y))
	p.size = sz
	p.modulate.a = 0.0
	l.add_child(p)
	_toast = weakref(p)
	var t_in: = V10DS.T_OUT if V10Hud2Util.fx_level() != "min" else 0.12
	var tw: = p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, t_in)
	tw.tween_interval(1.6)
	tw.tween_property(p, "modulate:a", 0.0, t_in)
	tw.tween_callback(p.queue_free)


static func _sfx(id: String, db: float) -> void:
	var bank: = V10Hud2Util.opt_class("V10SfxBank")
	if bank != null and bank.has_method("play"):
		bank.call("play", id, {"db": db})


static func _replay_id(topic: String) -> String:
	var id: = String(V10TutLines.HELP.get(topic, {}).get("replay", ""))
	return id if id != "" and V10TutState.seen(id) else ""


static func _glossary() -> Script:
	return V10Hud2Util.opt_class("V10GlossaryScreen")


# ==================================================================================== the sheet

class Sheet:
	extends Control

	var host: Node
	var main: Node
	var topic: = ""
	var page_kind: = ""  # "topic" | "list"
	var closing: = false
	var scrim: ColorRect
	var surf: Control
	var page: Control
	var proxy: Control
	var sheet_h: = 0.0
	var _opened: = false
	var _tw: Tween
	var _tw_page: Tween
	# «Как играть» list scrolling (only when it is taller than the screen allows)
	var _clip: Control
	var _list: Control
	var _scroll: = 0.0
	var _scroll_max: = 0.0
	var _press_y: = 0.0
	var _press_scroll: = 0.0
	var _pressing: = false
	var _dragged: = false

	func _init() -> void:
		name = "V10TutSheet"
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		process_mode = Node.PROCESS_MODE_ALWAYS
		scrim = ColorRect.new()
		scrim.color = Color(V10DS.NIGHT_900, 0.6)
		scrim.modulate.a = 0.0
		scrim.mouse_filter = Control.MOUSE_FILTER_STOP
		scrim.gui_input.connect(_scrim_input)
		add_child(scrim)
		surf = Control.new()
		surf.mouse_filter = Control.MOUSE_FILTER_STOP
		surf.draw.connect(_draw_surf)
		add_child(surf)

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		get_viewport().size_changed.connect(_on_resize)
		if main != null and is_instance_valid(main) and main is Node:
			proxy = Control.new()
			proxy.name = "V10TutBackProxy"
			proxy.mouse_filter = Control.MOUSE_FILTER_IGNORE
			proxy.size = Vector2.ZERO
			proxy.set_meta("v8_back", close)
			main.add_child(proxy)

	func _vs() -> Vector2:
		return get_viewport_rect().size

	func _cx() -> float:
		return floorf(maxf(0.0, (_vs().x - 720.0) * 0.5))

	func _ins() -> Dictionary:
		return V10Hud2Util.safe_insets(_vs())

	func _fx() -> bool:
		return V10Hud2Util.fx_level() != "min"

	func _draw_surf() -> void:
		V10Plate.draw_surface(surf, Rect2(Vector2.ZERO, surf.size + Vector2(0, 8)), false, false, false, false, false,
				-1.0, V10DS.NIGHT_700)

	# ---------------------------------------------------------------- pages

	func show_topic(t: String, back: bool, animate: = true) -> void:
		topic = t
		page_kind = "topic"
		_set_page(_build_topic(t, back), animate)

	func show_list(animate: = true) -> void:
		topic = ""
		page_kind = "list"
		_set_page(_build_list(), animate)

	func _set_page(p: Control, animate: bool) -> void:
		var old: = page
		page = p
		surf.add_child(p)
		var vs: = _vs()
		var ins: = _ins()
		var h: = float(p.get_meta("h", 400.0))
		sheet_h = h + float(ins.bottom) + 16.0
		surf.size = Vector2(vs.x, sheet_h)
		p.position = Vector2(_cx(), 0)
		var y_to: = vs.y - sheet_h
		if not _opened:
			_opened = true
			_open_anim(y_to)
			return
		_kill(_tw_page)
		_tw_page = create_tween()
		if old != null:
			p.modulate.a = 0.0
			_tw_page.tween_property(old, "modulate:a", 0.0, 0.12)
			_tw_page.tween_callback(old.queue_free)
			_tw_page.tween_property(p, "modulate:a", 1.0, V10DS.T_OUT)
		if animate and _fx():
			var tw2: = create_tween()
			tw2.tween_property(surf, "position:y", y_to, 0.22).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		else:
			surf.position.y = y_to
		surf.queue_redraw()

	func _open_anim(y_to: float) -> void:
		var vs: = _vs()
		_kill(_tw)
		_tw = create_tween()
		if _fx():  # «Шёлк»: 220 ms QUINT_OUT from the bottom
			surf.position = Vector2(0, vs.y)
			_tw.tween_property(surf, "position:y", y_to, 0.22).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
			_tw.parallel().tween_property(scrim, "modulate:a", 1.0, 0.22)
		else:
			surf.position = Vector2(0, y_to)
			surf.modulate.a = 0.0
			_tw.tween_property(surf, "modulate:a", 1.0, 0.12)
			_tw.parallel().tween_property(scrim, "modulate:a", 1.0, 0.12)
		V10TutHelp._sfx("page_turn", -12.0)

	func close() -> void:
		if closing:
			return
		closing = true
		if proxy != null and is_instance_valid(proxy):
			proxy.queue_free()
		proxy = null
		scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		surf.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_mouse_off(surf)
		_kill(_tw)
		_tw = create_tween()
		if _fx():
			_tw.tween_property(surf, "position:y", _vs().y, V10DS.T_OUT).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
			_tw.parallel().tween_property(scrim, "modulate:a", 0.0, V10DS.T_OUT)
		else:
			_tw.tween_property(surf, "modulate:a", 0.0, 0.12)
			_tw.parallel().tween_property(scrim, "modulate:a", 0.0, 0.12)
		_tw.tween_callback(queue_free)

	func _set_mouse_off(n: Node) -> void:
		for c in n.get_children():
			if c is Control:
				(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
			_set_mouse_off(c)

	func _on_resize() -> void:
		if closing or page == null:
			return
		var kind: = page_kind
		if kind == "list":
			show_list(false)
		else:
			show_topic(topic, bool(page.get_meta("back", false)), false)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_WM_GO_BACK_REQUEST and proxy == null and not closing:
			close()

	func _unhandled_key_input(e: InputEvent) -> void:
		if e is InputEventKey and (e as InputEventKey).pressed and (e as InputEventKey).keycode == KEY_ESCAPE and not closing:
			close()
			get_viewport().set_input_as_handled()

	func _scrim_input(e: InputEvent) -> void:
		if V10TutHelp._release(e):
			scrim.accept_event()
			close()
		elif V10TutHelp._press(e):
			scrim.accept_event()

	# ---------------------------------------------------------------- «?» of one topic (UX §4.1.9)

	func _build_topic(t: String, back: bool) -> Control:
		var d: Dictionary = V10TutLines.HELP.get(t, {})
		var p: = Control.new()
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.set_meta("back", back)
		var y: = 32.0
		var x: = MARGIN
		if back:
			var bb: = V10Button.make("quiet", "", Vector2(80, 80))
			bb.icon = "back"
			bb.icon_color = V10DS.PAPER_300
			bb.position = Vector2(8, y - 14.0)
			bb.set_meta("ux_role", "tertiary")
			bb.set_meta("tut_id", "help.back")
			bb.pressed.connect(func() -> void: show_list())
			p.add_child(bb)
			x = 88.0
		var links: = _links(p, y)
		var h1: = V10Type.label(V10TutLines.t(String(d.get("title", ""))), "display", 44, V10DS.PAPER_100)
		h1.position = Vector2(x, y)
		h1.size = Vector2(links - 16.0 - x, 52)
		p.add_child(h1)
		y += 52.0 + 24.0
		var rows: Array = d.get("rows", [])
		for i in mini(3, rows.size()):
			var r: Array = rows[i]
			var pl: = _row(String(r[0]), V10TutLines.t(String(r[1])))
			pl.position = Vector2(MARGIN, y)
			p.add_child(pl)
			y += ROW_STEP
		y += 16.0
		var ok_b: = V10Button.make("play", V10TutLines.ui("understood"), Vector2(560, 104))
		ok_b.breathing = false  # the screen's one infinite animation stays its own «Играть» (UX §6.7)
		ok_b.sheen = false
		ok_b.position = Vector2(80, y)
		ok_b.set_meta("ux_role", "primary")
		ok_b.set_meta("tut_id", "help.understood")
		ok_b.pressed.connect(close)
		p.add_child(ok_b)
		y += 104.0 + 8.0
		# UX §4.1.9: 3 icon-lines + «Подробнее» (swaps to «Как играть» in the same sheet, or opens Glossary after close);
		# when the intro was already seen, «Показать в игре» sits beside it (≤ 2 secondary actions, П-1).
		var rid: = V10TutHelp._replay_id(t)
		var gl: = V10TutHelp._glossary()
		var want_more: = (not back) or gl != null
		if rid != "" and want_more:
			var sb: = V10Button.make("secondary", V10TutLines.ui("show_in_game"), Vector2(272, 80))
			sb.position = Vector2(80, y)
			sb.set_meta("ux_role", "secondary")
			sb.set_meta("tut_id", "help.replay")
			sb.pressed.connect(func() -> void:
				close()
				V10Tutorial.replay(rid))
			p.add_child(sb)
			var mb: = V10Button.make("secondary", V10TutLines.ui("more"), Vector2(272, 80))
			mb.position = Vector2(80 + 272 + 16, y)
			mb.set_meta("ux_role", "secondary")
			mb.set_meta("tut_id", "help.more")
			mb.pressed.connect(func() -> void: _on_more(t, back))
			p.add_child(mb)
			y += 80.0
		elif rid != "":
			var sb2: = V10Button.make("secondary", V10TutLines.ui("show_in_game"), Vector2(560, 80))
			sb2.position = Vector2(80, y)
			sb2.set_meta("ux_role", "secondary")
			sb2.set_meta("tut_id", "help.replay")
			sb2.pressed.connect(func() -> void:
				close()
				V10Tutorial.replay(rid))
			p.add_child(sb2)
			y += 80.0
		elif want_more:
			var mb2: = V10Button.make("secondary", V10TutLines.ui("more"), Vector2(560, 80))
			mb2.position = Vector2(80, y)
			mb2.set_meta("ux_role", "secondary")
			mb2.set_meta("tut_id", "help.more")
			mb2.pressed.connect(func() -> void: _on_more(t, back))
			p.add_child(mb2)
			y += 80.0
		p.set_meta("h", y + 16.0)
		p.size = Vector2(720, y + 16.0)
		return p

	func _on_more(t: String, back: bool) -> void:
		if not back:
			show_list()
			return
		var cat: = String(V10TutHelp.TOPIC_GLOSSARY.get(t, ""))
		_open_glossary(cat)

	# quiet text links in the H1 row, right-aligned; returns the x where they start
	func _links(p: Control, y: float) -> float:
		var right: = 720.0 - 8.0
		var gl: = V10TutHelp._glossary()
		if page_kind == "list":
			var cb: = V10Button.make("quiet", "", Vector2(80, 80))
			cb.icon = "close"
			cb.icon_color = V10DS.PAPER_300
			cb.position = Vector2(right - 80.0, y - 14.0)
			cb.set_meta("ux_role", "tertiary")
			cb.set_meta("tut_id", "help.close")
			cb.pressed.connect(close)
			p.add_child(cb)
			right -= 80.0
		if gl != null:
			var g: = QuietText.make(V10TutLines.ui("glossary"))
			g.position = Vector2(right - g.size.x, y - 14.0)
			g.set_meta("tut_id", "help.glossary")
			g.pressed.connect(func() -> void: _open_glossary(""))
			p.add_child(g)
			right -= g.size.x
		return right

	func _open_glossary(cat: String = "") -> void:
		var gl: = V10TutHelp._glossary()
		var h: Node = main if main != null and is_instance_valid(main) else host
		close()
		if gl != null and h != null and is_instance_valid(h):
			gl.call("open", h, cat)

	# one help row: M plate, monoline icon, one concise sentence (UI 22→18, ≤ 2 lines, UX §4.1.9)
	func _row(icon_name: String, text: String) -> V10Plate:
		var pl: = V10Plate.make("M", ROW_W, "", "", "", icon_name)
		pl.on_art = false
		var l: = Label.new()
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var tx: = 24.0 + 48.0 + 16.0
		var tw: = float(ROW_W) - tx - 24.0
		V10Type.fit(l, text, "text_l", tw, 2, V10DS.PAPER_100)
		l.position = Vector2(tx, 0)
		l.size = Vector2(tw, 80)
		pl.add_child(l)
		pl.size = Vector2(ROW_W, 80)
		return pl

	# ---------------------------------------------------------------- «Как играть»

	func _build_list() -> Control:
		var p: = Control.new()
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var y: = 32.0
		var links: = _links(p, y)
		var h1: = V10Type.label(V10TutLines.ui("how_to"), "display", 44, V10DS.PAPER_100)
		h1.position = Vector2(MARGIN, y)
		h1.size = Vector2(links - 16.0 - MARGIN, 52)
		p.add_child(h1)
		y += 52.0 + 24.0
		# rows: open topics, then ≤ 1 teaser, then the hints switch
		_list = Control.new()
		_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ly: = 0.0
		var teaser: = {}
		for e in V10TutLines.HOW_TO:
			var gate: = String(e.get("gate", ""))
			if gate == "" or V10Reveal.is_open(gate):
				var pl: = V10Plate.make("M", ROW_W, V10TutLines.t(String(e.title)), V10TutLines.t(String(e.sub)), "",
						String(V10TutHelp.TOPIC_ICON.get(String(e.topic), "info")))
				pl.on_art = false
				pl.interactive = true
				pl.right_slot = V10Icons.icon("arrow_r", 24, V10DS.PAPER_500)
				pl.set_meta("tut_id", "help.row." + String(e.topic))
				pl.pressed.connect(_on_topic.bind(String(e.topic)))
				pl.position = Vector2(MARGIN, ly)
				pl.size = Vector2(ROW_W, 80)
				_list.add_child(pl)
				ly += ROW_STEP
			elif teaser.is_empty():
				teaser = e
		if not teaser.is_empty():
			var tz: = _teaser(teaser)
			tz.position = Vector2(MARGIN, ly)
			_list.add_child(tz)
			ly += ROW_STEP
		ly += 16.0
		var hp: = V10Plate.make("M", ROW_W, V10TutLines.ui("hints"), V10TutLines.ui("hints_sub"), "", "help")
		hp.on_art = false
		hp.interactive = true
		var sw: = Switch.new()
		sw.on = V10TutState.hints_on()
		hp.right_slot = sw
		hp.set_meta("tut_id", "help.hints")
		hp.pressed.connect(func() -> void:
			if _dragged:
				return
			sw.set_on(not sw.on)
			V10TutState.set_hints(sw.on))
		hp.position = Vector2(MARGIN, ly)
		hp.size = Vector2(ROW_W, 80)
		_list.add_child(hp)
		ly += 80.0
		# the list may scroll if the screen is short; the button row stays put under it
		var vs: = _vs()
		var ins: = _ins()
		var fixed: = y + 24.0 + 104.0 + 8.0 + 80.0 + 16.0
		var avail: = vs.y - float(ins.top) - 48.0 - float(ins.bottom) - 16.0 - fixed
		var list_h: = minf(ly, maxf(ROW_STEP * 3.0, avail))
		_clip = Control.new()
		_clip.clip_contents = true
		_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_clip.position = Vector2(0, y)
		_clip.size = Vector2(720, list_h)
		_clip.add_child(_list)
		_list.size = Vector2(720, ly)
		_scroll = 0.0
		_scroll_max = maxf(0.0, ly - list_h)
		p.add_child(_clip)
		y += list_h + 24.0
		var ok_b: = V10Button.make("play", V10TutLines.ui("understood"), Vector2(560, 104))
		ok_b.breathing = false
		ok_b.sheen = false
		ok_b.position = Vector2(80, y)
		ok_b.set_meta("ux_role", "primary")
		ok_b.set_meta("tut_id", "help.understood")
		ok_b.pressed.connect(close)
		p.add_child(ok_b)
		y += 104.0 + 8.0
		var fb: = V10Button.make("secondary", V10TutLines.ui("replay_first"), Vector2(560, 80))
		fb.position = Vector2(80, y)
		fb.set_meta("ux_role", "secondary")
		fb.set_meta("tut_id", "help.first_match")
		fb.pressed.connect(func() -> void:
			close()
			V10Tutorial.event("replay_first_match"))
		p.add_child(fb)
		y += 80.0
		p.set_meta("h", y + 16.0)
		p.size = Vector2(720, y + 16.0)
		return p

	func _teaser(e: Dictionary) -> V10Plate:
		# the one closed item: a paper.700 silhouette with «Откроется: …», no lock (UX §6.4)
		var pl: = V10Plate.make("M", ROW_W, "", "", "", "")
		pl.on_art = false
		pl.disabled = true
		pl.set_meta("tut_id", "help.teaser")
		var ic: = V10Icons.icon(String(V10TutHelp.TOPIC_ICON.get(String(e.topic), "info")), 48, V10DS.PAPER_700)
		ic.position = Vector2(24, 16)
		pl.add_child(ic)
		var tx: = 24.0 + 48.0 + 16.0
		var tw: = float(ROW_W) - tx - 24.0
		var gate: = String(e.get("gate", ""))
		var lt: = V10Reveal.locked_text(gate)
		var word: = V10TutLines.ui("teaser").get_slice(":", 0)
		var when: = lt
		if word != "" and lt.begins_with(word):
			when = lt.substr(word.length()).strip_edges()
		var t1: = Label.new()
		V10Type.fit(t1, V10TutLines.ui("teaser", {"what": V10TutLines.t(String(e.title))}), "title_sm", tw, 1, V10DS.PAPER_700)
		t1.position = Vector2(tx, 11)
		t1.size = Vector2(tw, 32)
		t1.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pl.add_child(t1)
		var t2: = Label.new()
		V10Type.fit(t2, when, "caption_m", tw, 1, V10DS.PAPER_700)
		t2.position = Vector2(tx, 43)
		t2.size = Vector2(tw, 26)
		t2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pl.add_child(t2)
		pl.size = Vector2(ROW_W, 80)
		return pl

	func _on_topic(t: String) -> void:
		if _dragged or closing:
			return
		show_topic(t, true)

	# drag-to-scroll for the list (plates stay STOP so a tap is a tap; a drag > 12 px is not)
	func _input(e: InputEvent) -> void:
		if closing or page_kind != "list" or _clip == null or not is_instance_valid(_clip) or _scroll_max <= 0.0:
			return
		var r: = Rect2(_clip.get_global_rect().position, _clip.size)
		if e is InputEventMouseButton:
			var mb: = e as InputEventMouseButton
			if mb.pressed and mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and r.has_point(mb.position):
				_set_scroll(_scroll + (-48.0 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 48.0))
				return
		var pos: = Vector2.ZERO
		var pressed: = false
		var released: = false
		var moved: = false
		if e is InputEventScreenTouch:
			pos = (e as InputEventScreenTouch).position
			pressed = (e as InputEventScreenTouch).pressed
			released = not pressed
		elif e is InputEventScreenDrag:
			pos = (e as InputEventScreenDrag).position
			moved = true
		else:
			return
		if pressed and r.has_point(pos):
			_pressing = true
			_dragged = false
			_press_y = pos.y
			_press_scroll = _scroll
		elif moved and _pressing:
			if absf(pos.y - _press_y) > 12.0:
				_dragged = true
			if _dragged:
				_set_scroll(_press_scroll - (pos.y - _press_y))
		elif released:
			_pressing = false
			if _dragged:
				_clear_drag.call_deferred()

	func _clear_drag() -> void:
		_dragged = false

	func _set_scroll(v: float) -> void:
		_scroll = clampf(v, 0.0, _scroll_max)
		if _list != null and is_instance_valid(_list):
			_list.position.y = -_scroll

	func _kill(t: Tween) -> void:
		if t != null and t.is_valid():
			t.kill()


static func _press(e: InputEvent) -> bool:
	if e is InputEventMouseButton:
		return (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and (e as InputEventMouseButton).pressed
	if e is InputEventScreenTouch:
		return (e as InputEventScreenTouch).pressed
	return false


static func _release(e: InputEvent) -> bool:
	if e is InputEventMouseButton:
		return (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and not (e as InputEventMouseButton).pressed
	if e is InputEventScreenTouch:
		return not (e as InputEventScreenTouch).pressed
	return false


# ==================================================================================== small controls

# Quiet text link (UX §6.5 «Тихая» with a word): UI 18 paper.500, 80 px hit zone, no fill.
class QuietText:
	extends Control
	signal pressed
	var label: Label
	var _down: = false

	static func make(t: String) -> QuietText:
		var q: = QuietText.new()
		q.label = V10Type.label(t, "ui", 18, V10DS.PAPER_500)
		q.label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		q.add_child(q.label)
		var w: = maxf(80.0, ceilf(V10Type.text_w(t, "ui", 18)) + 32.0)
		q.size = Vector2(w, 80)
		q.custom_minimum_size = q.size
		q.label.size = q.size
		q.mouse_filter = Control.MOUSE_FILTER_STOP
		q.set_meta("ux_role", "tertiary")
		return q

	func _gui_input(e: InputEvent) -> void:
		if V10TutHelp._press(e):
			_down = true
			label.label_settings = V10Type.settings("ui", 18, V10DS.PAPER_300)
			accept_event()
		elif V10TutHelp._release(e) and _down:
			_down = false
			label.label_settings = V10Type.settings("ui", 18, V10DS.PAPER_500)
			accept_event()
			if Rect2(Vector2.ZERO, size).grow(16).has_point((e as InputEventMouseButton).position if e is InputEventMouseButton
					else (e as InputEventScreenTouch).position):
				pressed.emit()


# On/off switch for the right slot of an M plate (the plate takes the tap): track 56×32, knob 24.
class Switch:
	extends Control
	var on: = true
	var _k: = 1.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(72, 80)
		size = custom_minimum_size

	func _ready() -> void:
		_k = 1.0 if on else 0.0
		queue_redraw()

	func set_on(v: bool) -> void:
		on = v
		var tw: = create_tween()
		var d: = V10DS.T_OUT if V10Hud2Util.fx_level() != "min" else 0.0
		tw.tween_method(func(k: float) -> void:
			_k = k
			queue_redraw(), _k, 1.0 if on else 0.0, maxf(0.01, d)).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)

	func _draw() -> void:
		var c: = size * 0.5
		var tr: = Rect2(c - Vector2(28, 16), Vector2(56, 32))
		var sb: = StyleBoxFlat.new()
		sb.bg_color = V10DS.NIGHT_600.lerp(V10DS.GOLD_700, _k)
		sb.set_corner_radius_all(16)
		sb.anti_aliasing = true
		draw_style_box(sb, tr)
		var kx: = lerpf(tr.position.x + 16.0, tr.end.x - 16.0, _k)
		draw_circle(Vector2(kx, c.y), 12.0, V10DS.PAPER_500.lerp(V10DS.PAPER_100, _k), true, -1.0, true)
