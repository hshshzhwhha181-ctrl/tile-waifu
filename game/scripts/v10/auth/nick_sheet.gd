class_name V10NickSheet
extends Control

# Guest name picker (first sign-in): nick field + dice, «Идеи от героинь» chips (one per founder, picking a chip
# also picks her as the avatar), the avatar row, «В чайную!». Saves through G.set_profile (profile_done = true).
#   var ns: = V10NickSheet.open(host)
#   await ns.finished

signal finished

const PH: = 826.0

var panel: Control
var nick_le: LineEdit
var hint_lbl: Label
var dice: JButton
var avatars
var chips: = []
var play_btn: JButton
var avatar: = "mc"
var _done: = false


static func open(host: Control) -> V10NickSheet:
	var s: = V10NickSheet.new()
	s.name = "V10NickSheet"
	s.size = host.size
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(s)
	s._build()
	return s


func _build() -> void :
	var sh: = V10AuthUI.sheet(self, V10AuthText.s("nick.title"), PH)
	panel = sh.panel
	(sh.root as Control).gui_input.connect(_on_bg)
	panel.gui_input.connect(_on_bg)
	var pw: = panel.size.x
	var x: = 40.0
	var w: = pw - 80.0
	avatar = str(G.profile().get("avatar", "mc"))
	var why: = UI.label(V10AuthText.s("nick.why"), 19, UI.MUTED, UI.DARK, 2, "body", 800)
	why.position = Vector2(x, 58)
	why.size = Vector2(w, 28)
	why.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(why)
	nick_le = V8ProfileUI.nick_field(Rect2(x, 96, w - 104, 86), str(G.profile().get("nick", "")))
	nick_le.name = "Nick"
	nick_le.text_changed.connect(func(_t): _validate(false))
	panel.add_child(nick_le)
	dice = V8ProfileUI.dice_button(Rect2(x + w - 88, 96, 88, 86))
	dice.pressed.connect(_on_dice)
	panel.add_child(dice)
	hint_lbl = UI.label("", 17, UI.MUTED, UI.DARK, 2, "body", 800)
	hint_lbl.position = Vector2(x + 6, 186)
	hint_lbl.size = Vector2(w - 6, 26)
	panel.add_child(hint_lbl)
	var il: = UI.label(V10AuthText.s("nick.ideas"), 23, UI.INK, UI.DARK, 3, "body", 900)
	il.position = Vector2(x, 222)
	panel.add_child(il)
	_chips(V10AuthNicks.suggest(5), Rect2(x - 8, 262, w + 16, 220))
	avatars = V8ProfileUI.avatar_row(avatar, Rect2(20, 494, pw - 40, 150))
	avatars.picked.connect(_on_avatar)
	panel.add_child(avatars)
	play_btn = JButton.make(V10AuthText.s("nick.play"), "pink", Rect2(x, 676, w, 116), null, 36)
	play_btn.name = "Btn_play"
	play_btn.set_sub(V10AuthText.s("nick.play_sub"), 19)
	play_btn.shine_every = 2.6
	play_btn.pressed.connect(_on_play)
	play_btn.set_gate(func(): return _done or G.nick_error(nick_le.text) == "", func():
		nick_le.release_focus()
		_validate(true)
		V9Feel.deny(nick_le))
	panel.add_child(play_btn)
	_validate(false)


func _chips(ideas: Array, r: Rect2) -> void :
	var cols: = 2
	var cw: = (r.size.x - 12.0) / cols
	var ch: = 64.0
	for i in ideas.size():
		var it: Dictionary = ideas[i]
		var row: = i / cols
		var col: = i % cols
		var cx: = r.position.x + col * (cw + 12.0)
		var last_odd: = i == ideas.size() - 1 and ideas.size() % cols == 1
		if last_odd:
			cx = r.position.x + (r.size.x - cw) * 0.5
		var c: = _Chip.new()
		c.position = Vector2(cx, r.position.y + row * (ch + 10.0))
		c.size = Vector2(cw, ch)
		c.setup(it.nick, it.hero)
		c.picked.connect(_on_chip)
		panel.add_child(c)
		chips.append(c)
		UI.slide_in(c, Vector2(0, 16), 0.15 + i * 0.05, 0.35)
	_paint_chips()


func _on_avatar(h: String) -> void :
	avatar = h


func _paint_chips() -> void :
	for c in chips:
		c.set_on(c.nick == nick_le.text.strip_edges())


func _on_chip(nick: String, hero: String) -> void :
	nick_le.text = nick
	nick_le.caret_column = nick.length()
	avatar = hero
	if avatars and avatars.has_method("select"):
		avatars.select(hero)
	_validate(false)
	_paint_chips()


func _on_dice() -> void :
	V8ProfileUI.roll(dice)
	var idea: Dictionary = V10AuthNicks.suggest(1)[0]
	_on_chip(idea.nick, idea.hero)


func _on_bg(e: InputEvent) -> void :
	if e is InputEventMouseButton and e.pressed and nick_le and nick_le.has_focus():
		nick_le.release_focus()


func _validate(strict: bool) -> bool:
	var err: = G.nick_error(nick_le.text)
	var show: = err != "" and (strict or nick_le.text.strip_edges().length() > G.NICK_MAX)
	hint_lbl.text = err if show else "%d / %d" % [nick_le.text.strip_edges().length(), G.NICK_MAX]
	var ls: = hint_lbl.label_settings.duplicate() as LabelSettings
	ls.font_color = Color("ff9a9a") if show else UI.MUTED
	hint_lbl.label_settings = ls
	if chips.size() > 0:
		_paint_chips()
	return err == ""


func _on_play() -> void :
	if _done:
		return
	nick_le.release_focus()
	if not _validate(true) or not G.set_profile(nick_le.text, avatar, true):
		V9Feel.deny(nick_le)
		return
	_done = true
	V9Feel.success(play_btn, "reveal_sr")
	V10AuthUI.close(get_node("V10AuthSheet"), func(): finished.emit())


# dev: fill and submit (selftest / screenshots)
func dev_submit(nick: String, hero: = "mc") -> void :
	_on_chip(nick, hero)
	_on_play()


class _Chip extends Control:
	signal picked(nick: String, hero: String)
	var nick: = ""
	var hero: = ""
	var bg: RBox

	func setup(n: String, h: String) -> void :
		nick = n
		hero = h
		mouse_filter = Control.MOUSE_FILTER_STOP
		bg = UI.rbox("glass", Rect2(Vector2.ZERO, size), size.y * 0.5, 3, 8)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bg)
		var av: = Common.avatar(h, Rect2(5, 5, size.y - 10, size.y - 10))
		add_child(av)
		var l: = UI.label(n, 21, UI.INK, UI.DARK, 3, "body", 900)
		l.position = Vector2(size.y + 2, 0)
		l.size = Vector2(size.x - size.y - 12, size.y)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		Common.fit_line(l, l.size.x, 15)
		add_child(l)

	func set_on(on: bool) -> void :
		var col: Color = G.HEROES[hero].color
		if on:
			bg.colors(Color(col.darkened(0.35), 0.95), Color(col.darkened(0.65), 0.97)).borders(Color("fff0b8"), Color("c58a2c"))
		else:
			bg.colors(UI.PAL.glass[0], UI.PAL.glass[1]).borders(Color(col, 0.55), Color(col.darkened(0.4), 0.55))

	func _gui_input(e: InputEvent) -> void :
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed:
			V9Feel.press(self, "pop", "button")
			picked.emit(nick, hero)
			accept_event()
