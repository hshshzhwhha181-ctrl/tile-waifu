class_name V8ProfileCard
extends Control

# First-launch player card (title → card → intro → first game).
#   var card: = V8ProfileCard.make(main, parent)
#   await card.finished          # profile saved (G.set_profile) or progress imported
#   card.imported -> true when a recovery code replaced the save
# Built inside `parent` (the title screen sits above main.overlay, so no Common.popup here).
# Dev flags: --card_fill=<nick|1> prefill, --card_code=1 open the code page, --card_auto=1 submit by itself.

signal finished

const PW: = 660.0
const PH: = 860.0

var main
var imported: = false
var panel: RBox
var page_main: Control
var page_code: Control
var nick_le: LineEdit
var hint_lbl: Label
var who_lbl: Label
var avatars: V8ProfileUI.AvatarRow
var dice: JButton
var play_btn: JButton
var avatar: = "mc"
var _done: = false


static func make(m, parent: Control) -> V8ProfileCard:
	var c: = V8ProfileCard.new()
	c.main = m
	c.size = parent.size
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	c.name = "V8ProfileCard"
	parent.add_child(c)
	c._build()
	return c


func _args() -> Dictionary:
	var a: = {}
	for s in OS.get_cmdline_user_args():
		if s.begins_with("--") and "=" in s:
			var kv: = s.substr(2).split("=", true, 1)
			a[kv[0]] = kv[1]
	return a


func _build() -> void :
	var p: = G.profile()
	avatar = str(p.get("avatar", "mc"))
	var dim: = ColorRect.new()
	dim.size = size
	dim.color = Color(0.03, 0.02, 0.035, 0.0)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	dim.create_tween().tween_property(dim, "color:a", 0.62, 0.3)
	dim.set_meta("no_haptic", true)
	dim.gui_input.connect(_on_bg_input)
	var y: = clampf((size.y - PH) * 0.5 + 40.0, 150.0, 400.0)
	panel = UI.rbox("cream", Rect2((size.x - PW) * 0.5, y, PW, PH), 34, 5, 16)
	panel.set_param("pattern", 1.0)
	# 0.8 art: the btn/panel nine-patch (graphite, gold rim, sakura corners), as in Common.popup
	panel.cr.visible = false
	var art: = V8Art.nine("panel", Rect2(Vector2.ZERO, Vector2(PW, PH)))
	art.name = "PanelArt"
	panel.add_child(art)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.set_meta("no_haptic", true)
	panel.gui_input.connect(_on_bg_input)
	add_child(panel)
	panel.pivot_offset = panel.size * 0.5
	UI.pop_in(panel, 0.05, 0.85)
	var rib: = Common.ribbon(panel, V8ProfileUI.s("card.title"), Rect2(PW * 0.5 - 220, -38, 440, 72), "pink", 30)
	rib.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page_main = Control.new()
	page_main.size = panel.size
	page_main.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(page_main)
	_build_main(str(p.get("nick", "")))
	var a: = _args()
	if a.has("card_fill"):
		nick_le.text = V8ProfileUI.random_nick() if a.card_fill == "1" else a.card_fill
		avatars.select("rin")
		_on_pick("rin")
		_validate(false)
	if a.has("card_code"):
		_show_code.call_deferred()
	if a.has("card_auto"):
		_auto.call_deferred()


func _build_main(nick0: String) -> void :
	var x: = 40.0
	var w: = PW - 80.0
	var ask: = UI.label(V8ProfileUI.s("card.ask"), 28, UI.INK, UI.DARK, 3, "body", 900)
	ask.position = Vector2(x, 54)
	ask.size = Vector2(w, 40)
	page_main.add_child(ask)
	var why: = UI.label(V8ProfileUI.s("card.why"), 18, UI.MUTED, UI.DARK, 2, "body", 800)
	why.position = Vector2(x, 94)
	why.size = Vector2(w, 28)
	page_main.add_child(why)
	nick_le = V8ProfileUI.nick_field(Rect2(x, 134, w - 104, 86), nick0)
	nick_le.text_changed.connect( func(_t): _validate(false))
	page_main.add_child(nick_le)
	dice = V8ProfileUI.dice_button(Rect2(x + w - 88, 134, 88, 86))
	dice.pressed.connect(_on_dice)
	page_main.add_child(dice)
	hint_lbl = UI.label(V8ProfileUI.s("card.hint"), 18, UI.MUTED, UI.DARK, 2, "body", 800)
	hint_lbl.position = Vector2(x + 6, 226)
	hint_lbl.size = Vector2(w - 6, 28)
	page_main.add_child(hint_lbl)

	var al: = UI.label(V8ProfileUI.s("card.avatar"), 24, UI.INK, UI.DARK, 3, "body", 900)
	al.position = Vector2(x, 274)
	page_main.add_child(al)
	avatars = V8ProfileUI.avatar_row(avatar, Rect2(20, 314, PW - 40, 150))
	avatars.picked.connect(_on_pick)
	page_main.add_child(avatars)
	who_lbl = UI.center_label(UI.label("", 19, UI.GOLD, UI.DARK, 2, "body", 800), Rect2(x, 468, w, 30))
	page_main.add_child(who_lbl)
	_on_pick(avatar)

	play_btn = JButton.make(V8ProfileUI.s("card.play"), "pink", Rect2(x, 520, w, 116), null, 34)
	play_btn.set_sub(V8ProfileUI.s("card.play_sub"), 19)
	play_btn.shine_every = 2.6
	play_btn.pressed.connect(_on_play)
	# 0.9: a bad nick is refused by the gate — the tap gets only the deny and the red hint says why
	play_btn.set_gate( func(): return _done or G.nick_error(nick_le.text) == "", func():
		nick_le.release_focus()
		_validate(true)
		V9Feel.deny(nick_le))
	page_main.add_child(play_btn)
	var note: = UI.label(V8ProfileUI.s("card.note"), 17, UI.MUTED, UI.DARK, 2, "body", 800)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.position = Vector2(x, 648)
	note.size = Vector2(w, 52)
	page_main.add_child(note)
	var code_btn: = JButton.make(V8ProfileUI.s("card.have_code"), "graphite", Rect2(PW * 0.5 - 170, 726, 340, 76), null, 24)
	code_btn.pressed.connect(_show_code)
	page_main.add_child(code_btn)


func _on_bg_input(e: InputEvent) -> void :
	if e is InputEventMouseButton and e.pressed and nick_le and nick_le.has_focus():
		nick_le.release_focus()


func _on_pick(h: String) -> void :
	avatar = h
	if who_lbl:
		who_lbl.text = "%s · %s" % [G.HEROES[h].name, G.HEROES[h].title]


func _on_dice() -> void :
	V8ProfileUI.roll(dice)
	nick_le.text = V8ProfileUI.random_nick()
	nick_le.caret_column = nick_le.text.length()
	_validate(false)


func _validate(strict: bool) -> bool:
	var err: = G.nick_error(nick_le.text)
	var show: = err != "" and (strict or nick_le.text.strip_edges().length() > G.NICK_MAX)
	hint_lbl.text = err if show else V8ProfileUI.s("card.hint")
	var ls: = hint_lbl.label_settings.duplicate() as LabelSettings
	ls.font_color = Color("ff9a9a") if show else UI.MUTED
	hint_lbl.label_settings = ls
	return err == ""


func _on_play() -> void :
	if _done:
		return
	nick_le.release_focus()
	if not _validate(true):
		V9Feel.deny(nick_le)
		return
	if not G.set_profile(nick_le.text, avatar, true):
		_validate(true)
		return
	_finish()


func _finish() -> void :
	if _done:
		return
	_done = true
	Sfx.play("reveal_sr", 1.1, -6)
	var t: = create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.3)
	await t.finished
	finished.emit()
	queue_free()


func _show_code() -> void :
	if nick_le:
		nick_le.release_focus()
	page_main.visible = false
	if page_code:
		page_code.queue_free()
	page_code = Control.new()
	page_code.size = panel.size
	page_code.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(page_code)
	var hd: = UI.label(V8ProfileUI.s("code.title"), 28, UI.INK, UI.DARK, 3, "body", 900)
	hd.position = Vector2(40, 54)
	page_code.add_child(hd)
	var ui: = {}
	var on_code: = func(code: String):
		if V8Recovery.import_code(code):
			_on_imported()
		else:
			ui.error.text = V8Recovery.last_error
			V9Feel.deny(ui.field)
	ui.merge(V8ProfileUI.code_entry(page_code, Rect2(40, 106, PW - 80, 600), on_code, _hide_code))
	UI.slide_in(page_code, Vector2(40, 0), 0.0, 0.25)


func _hide_code() -> void :
	if page_code:
		page_code.queue_free()
		page_code = null
	page_main.visible = true
	UI.slide_in(page_main, Vector2(-40, 0), 0.0, 0.25)


func _on_imported() -> void :
	imported = true
	Sfx.play("reveal_sr", 1.0, -4)
	if bool(G.S.get("profile_done", false)):
		hint_lbl.text = V8ProfileUI.s("card.imported_ok")
		_finish()
		return
	# A 0.7 code: progress is in, the player still needs a nick.
	var p: = G.profile()
	_hide_code()
	nick_le.text = str(p.get("nick", ""))
	avatars.select(str(p.get("avatar", "mc")))
	_on_pick(avatars.selected)
	hint_lbl.text = V8ProfileUI.s("card.imported")
	var ls: = hint_lbl.label_settings.duplicate() as LabelSettings
	ls.font_color = Color("a9d9c4")
	hint_lbl.label_settings = ls


func _auto() -> void :
	await get_tree().create_timer(1.6).timeout
	if not is_inside_tree() or _done:
		return
	if G.nick_error(nick_le.text) != "":
		_on_dice()
	await get_tree().create_timer(0.6).timeout
	if is_inside_tree():
		_on_play()
