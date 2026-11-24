class_name V10EmailSheet
extends Control

# «У меня есть аккаунт»: e-mail + one-time code (UI only until the server exists — the provider answers
# not_available_yet and the toast says so). Also the way into the 0.8 recovery-code import (V8ProfileCard).
#   V10EmailSheet.open(login_screen, main)

const PH: = 600.0

var login
var main
var root: Control
var panel: Control
var email_le: LineEdit
var code_le: LineEdit
var hint: Label
var send_btn: JButton
var busy: = false


static func open(login_screen: Control, m = null) -> V10EmailSheet:
	var s: = V10EmailSheet.new()
	s.name = "V10EmailSheet"
	s.login = login_screen
	s.main = m
	s.size = login_screen.size
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	login_screen.add_child(s)
	s._build()
	return s


func _field(r: Rect2, ph: String, kind: int) -> LineEdit:
	var le: = V8ProfileUI.nick_field(r, "")
	le.placeholder_text = ph
	le.max_length = 120
	le.virtual_keyboard_type = kind
	return le


func _build() -> void :
	var sh: = V10AuthUI.sheet(self, V10AuthText.s("email.title"), PH)
	root = sh.root
	panel = sh.panel
	root.gui_input.connect(_on_bg)
	var pw: = panel.size.x
	var x: = 40.0
	var w: = pw - 80.0
	var ask: = UI.label(V10AuthText.s("email.ask"), 23, UI.INK, UI.DARK, 3, "body", 900)
	ask.position = Vector2(x, 60)
	ask.size = Vector2(w, 34)
	panel.add_child(ask)
	email_le = _field(Rect2(x, 102, w, 80), "name@mail.ru", LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS)
	email_le.name = "Email"
	email_le.text_changed.connect(func(_t): _hint(false))
	panel.add_child(email_le)
	hint = UI.label(V10AuthText.s("email.hint"), 17, UI.MUTED, UI.DARK, 2, "body", 800)
	hint.position = Vector2(x + 6, 188)
	hint.size = Vector2(w - 6, 26)
	panel.add_child(hint)
	code_le = _field(Rect2(x, 230, w * 0.5, 72), V10AuthText.s("email.code"), LineEdit.KEYBOARD_TYPE_NUMBER)
	code_le.max_length = 6
	code_le.editable = false
	code_le.modulate = Color(1, 1, 1, 0.45)
	panel.add_child(code_le)
	send_btn = JButton.make(V10AuthText.s("email.send"), "pink", Rect2(x, 326, w, 104), null, 32)
	send_btn.name = "Btn_send"
	send_btn.set_gate(func(): return not busy and V10AuthProviders.valid_email(email_le.text), func(): _hint(true))
	send_btn.pressed.connect(_on_send)
	panel.add_child(send_btn)
	var back: = JButton.make(V10AuthText.s("email.back"), "graphite", Rect2(x, 446, w * 0.5 - 8, 76), null, 24)
	back.pressed.connect(func(): V10AuthUI.close(root, queue_free))
	panel.add_child(back)
	if main != null:
		var rc: = V10AuthUI.link(V10AuthText.s("email.restore"), Rect2(x + w * 0.5 + 8, 446, w * 0.5 - 8, 76), _on_restore, 19)
		panel.add_child(rc)


func _on_bg(e: InputEvent) -> void :
	if e is InputEventMouseButton and e.pressed:
		email_le.release_focus()


func _hint(strict: bool) -> void :
	var bad: = strict and not V10AuthProviders.valid_email(email_le.text)
	hint.text = V10AuthText.s("email.bad") if bad else V10AuthText.s("email.hint")
	var ls: = hint.label_settings.duplicate() as LabelSettings
	ls.font_color = Color("ff9a9a") if bad else UI.MUTED
	hint.label_settings = ls
	if bad:
		V9Feel.deny(email_le)


func _on_send() -> void :
	busy = true
	email_le.release_focus()
	var cap: = send_btn.lbl.text
	send_btn.lbl.text = V10AuthText.s("login.connecting")
	var p = V10Auth.provider("email")
	var r: Dictionary = await p.request_code(email_le.text.strip_edges())
	if not is_instance_valid(send_btn):
		return
	send_btn.lbl.text = cap
	busy = false
	if bool(r.get("ok", false)):
		code_le.editable = true
		code_le.modulate = Color.WHITE
		code_le.grab_focus()
		return
	if login and login.has_method("say"):
		login.say(V10AuthText.s("stub.email_soon"), "rin")
	else:
		V10AuthUI.toast(self, V10AuthText.s("stub.email_soon"), "rin")


func _on_restore() -> void :
	var card: = V8ProfileCard.make(main, login)
	card._show_code()
	V10AuthUI.close(root, queue_free)
	await card.finished
	if card.imported and login and login.has_method("on_imported"):
		login.on_imported()
