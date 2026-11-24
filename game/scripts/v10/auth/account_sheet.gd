class_name V10AccountSheet
extends Control

# «Аккаунт» (open from Settings and from the Profile): who you are, how you signed in, link accounts, consent,
# legal links, «Выйти», «Удалить аккаунт» (store requirement: in-app deletion with a hold-to-confirm).
#   var a: = V10AccountSheet.open(host)
#   a.logged_out.connect(...)   -> the integrator restarts the entry flow (V10AuthFlow.relogin(main))
#   a.deleted.connect(...)      -> same, the save is already wiped

signal logged_out
signal deleted
signal closed

const PH: = 1000.0

var root: Control
var panel: Control
var link_btns: = {}
var hold_fill: Panel
var _hold: = 0.0
var _holding: = false
var _del_root: Control
var _del_done: = false


static func open(host: Control) -> V10AccountSheet:
	var s: = V10AccountSheet.new()
	s.name = "V10AccountSheet"
	s.size = host.size
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(s)
	s._build()
	return s


func _build() -> void :
	var st: = V10Auth.state()
	var nids: = V10Auth.login_buttons().size()
	var ph: = 250.0 + (58.0 if V10Auth.is_guest() else 0.0) + (38.0 + 82.0 * nids if nids > 0 else 0.0) + 66.0 + 40.0 + 236.0
	ph = minf(ph, size.y - 120.0)
	var sh: = V10AuthUI.sheet(self, V10AuthText.s("acc.title"), ph)
	root = sh.root
	panel = sh.panel
	var pw: = panel.size.x
	var x: = 36.0
	var w: = pw - 72.0
	var close_b: = JButton.make("", "graphite", Rect2(pw - 54, -20, 64, 64), null, 30)
	close_b.name = "Btn_close"
	if close_b.box:
		close_b.box.borders(Color("ffe7a6"), Color("a8742a"))
	close_b.add_child(V8Art.rect(V8Art.icon("close"), Rect2(15, 15, 34, 34)))
	close_b.pressed.connect(close)
	panel.add_child(close_b)
	# who
	var hero: = V10Auth.greet_hero()
	var av: = Common.avatar(hero, Rect2(x, 56, 104, 104))
	panel.add_child(av)
	var nm: = UI.label(G.nick(), 30, UI.INK, UI.DARK, 4, "title", 900)
	nm.position = Vector2(x + 120, 60)
	nm.size = Vector2(w - 190, 40)
	Common.fit_line(nm, nm.size.x, 20)
	panel.add_child(nm)
	var prov: = str(st.provider) if str(st.provider) != "" else "guest"
	var via: = UI.label(V10AuthText.s("acc.via", V10AuthText.provider_name(prov)), 19, UI.GOLD, UI.DARK, 2, "body", 800)
	via.position = Vector2(x + 120, 100)
	panel.add_child(via)
	if int(st.created_at) > 0:
		var d: = Time.get_date_dict_from_unix_time(int(st.created_at))
		var since: = UI.label(V10AuthText.s("acc.since", "%02d.%02d.%d" % [d.day, d.month, d.year]), 17, UI.MUTED, UI.DARK, 2, "body", 800)
		since.position = Vector2(x + 120, 128)
		panel.add_child(since)
	# player id (tap = copy)
	var idbox: = UI.rbox("glass", Rect2(x, 176, w, 58), 18, 2, 8)
	idbox.name = "IdBox"
	idbox.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_child(idbox)
	var idl: = UI.label("%s:  %s" % [V10AuthText.s("acc.id"), V10Auth.player_id()], 20, UI.INK, UI.DARK, 2, "body", 900)
	UI.center_label(idl, Rect2(0, 0, w, 58))
	idbox.add_child(idl)
	idbox.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			V9Feel.press(idbox, "tap", "tap")
			DisplayServer.clipboard_set(V10Auth.player_id())
			V10AuthUI.toast(self, V10AuthText.s("acc.copied")))
	var y: = 250.0
	if V10Auth.is_guest():
		var note: = UI.label(V10AuthText.s("acc.guest_note"), 17, Color("e9d7bf"), UI.DARK, 2, "body", 800)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.position = Vector2(x, y)
		note.size = Vector2(w, 50)
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		panel.add_child(note)
		y += 58.0
	# link accounts
	var ids: Array = V10Auth.login_buttons()
	if not ids.is_empty():
		var ll: = UI.label(V10AuthText.s("acc.link"), 23, UI.INK, UI.DARK, 3, "body", 900)
		ll.position = Vector2(x, y)
		panel.add_child(ll)
		y += 38.0
		for id in ids:
			var linked: bool = st.linked.has(id)
			var b: = V10AuthUI.provider_button(id, Rect2(x, y, w, 72), V10AuthText.provider_name(id) + ("  ✓ " + V10AuthText.s("acc.linked") if linked else ""))
			if linked:
				b.set_pal("mint")
			b.pressed.connect(_on_link.bind(id))
			b.set_gate(func(): return V10Auth.has_consent() and not linked, func():
				if not V10Auth.has_consent():
					V10AuthUI.toast(self, V10AuthText.s("login.consent_need")))
			panel.add_child(b)
			link_btns[id] = b
			y += 82.0
	# consent
	var cons: = V10AuthUI.checkbox(Rect2(x + 4, y + 2, w - 8, 56), V10AuthText.s("login.consent"), V10Auth.has_consent(), func(on):
		V10Auth.set_consent(on), 17)
	cons.name = "Consent"
	panel.add_child(cons)
	y += 66.0
	# legal
	var half: = w * 0.5
	panel.add_child(V10AuthUI.link(V10AuthText.s("acc.terms"), Rect2(x, y, half, 40), func(): V10AuthUI.toast(self, V10AuthText.s("stub.legal_soon")), 18))
	panel.add_child(V10AuthUI.link(V10AuthText.s("acc.privacy"), Rect2(x + half, y, half, 40), func(): V10AuthUI.toast(self, V10AuthText.s("stub.legal_soon")), 18))
	# bottom: logout + delete
	var by: = panel.size.y - 206.0
	var out_b: = JButton.make(V10AuthText.s("acc.logout"), "graphite", Rect2(x, by, w, 84), null, 28)
	out_b.name = "Btn_logout"
	out_b.pressed.connect(_ask_logout)
	panel.add_child(out_b)
	var del: = V10AuthUI.link(V10AuthText.s("acc.delete"), Rect2(x, by + 100, w, 44), _ask_delete, 19, Color("ff9a9a"))
	del.name = "Link_delete"
	panel.add_child(del)


func close() -> void :
	V10AuthUI.close(root, func():
		closed.emit()
		queue_free())


func _on_link(id: String) -> void :
	var b: JButton = link_btns[id]
	var cap: = b.lbl.text
	b.lbl.text = V10AuthText.s("login.connecting")
	var r: Dictionary = await V10Auth.link(id)
	if not is_instance_valid(b):
		return
	b.lbl.text = cap
	if bool(r.get("ok", false)):
		V9Feel.success(b)
		V10AuthUI.toast(self, V10AuthText.s("toast.linked", V10AuthText.provider_name(id)))
		b.set_pal("mint")
	else:
		V10AuthUI.toast(self, V10AuthText.s("stub.not_available_yet", V10AuthText.provider_name(id)), "nova")


# ── logout ─────────────────────────────────────────────────────────────────────────────────────────────────

func _confirm(title: String, text: String, h: float) -> Dictionary:
	var sh: = V10AuthUI.sheet(self, title, h, 600.0)
	var p: Control = sh.panel
	var l: = UI.label(text, 21, UI.INK, UI.DARK, 3, "body", 800)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = Vector2(36, 62)
	l.size = Vector2(p.size.x - 72, h - 240)
	p.add_child(l)
	return sh


func _ask_logout() -> void :
	var st: = V10Auth.state()
	var txt: = V10AuthText.s("acc.logout_guest") if V10Auth.is_guest() else V10AuthText.s("acc.logout_prov", V10AuthText.provider_name(str(st.provider)))
	var sh: = _confirm(V10AuthText.s("acc.logout_q"), txt, 420.0)
	var p: Control = sh.panel
	var w: = p.size.x - 72.0
	var stay: = JButton.make(V10AuthText.s("acc.cancel"), "pink", Rect2(36, 420 - 130, w * 0.5 - 8, 92), null, 28)
	stay.pressed.connect(func(): V10AuthUI.close(sh.root))
	p.add_child(stay)
	var go: = JButton.make(V10AuthText.s("acc.logout_yes"), "graphite", Rect2(36 + w * 0.5 + 8, 420 - 130, w * 0.5 - 8, 92), null, 28)
	go.name = "Btn_logout_yes"
	go.pressed.connect(func():
		V10Auth.sign_out()
		V10AuthUI.close(sh.root)
		V10AuthUI.close(root, func():
			logged_out.emit()
			queue_free()))
	p.add_child(go)


# ── deletion: hold the red button for 2 s ──────────────────────────────────────────────────────────────────

const HOLD_SEC: = 2.0
const DEL_H: = 490.0

func _ask_delete() -> void :
	var sh: = _confirm(V10AuthText.s("acc.del_q"), V10AuthText.s("acc.del_text"), DEL_H)
	_del_root = sh.root
	var p: Control = sh.panel
	var w: = p.size.x - 72.0
	var stay: = JButton.make(V10AuthText.s("acc.cancel"), "pink", Rect2(36, DEL_H - 236, w, 88), null, 28)
	stay.pressed.connect(func(): V10AuthUI.close(sh.root))
	p.add_child(stay)
	var hb: = Control.new()
	hb.name = "HoldDelete"
	hb.position = Vector2(36, DEL_H - 132)
	hb.size = Vector2(w, 86)
	hb.mouse_filter = Control.MOUSE_FILTER_STOP
	p.add_child(hb)
	var box: = UI.rbox("red", Rect2(Vector2.ZERO, hb.size), 43, 3, 10)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(box)
	hold_fill = Panel.new()
	var fsb: = StyleBoxFlat.new()
	fsb.bg_color = Color(1.0, 0.86, 0.86, 0.36)
	fsb.set_corner_radius_all(int((hb.size.y - 20.0) * 0.5))
	fsb.anti_aliasing = true
	hold_fill.add_theme_stylebox_override("panel", fsb)
	hold_fill.position = Vector2(10, 10)
	hold_fill.size = Vector2(0, hb.size.y - 20)
	hold_fill.visible = false
	hold_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(hold_fill)
	hb.add_child(UI.center_label(UI.label(V10AuthText.s("acc.del_hold"), 24, Color.WHITE, Color("42101a"), 5, "body", 900), Rect2(Vector2.ZERO, hb.size)))
	hb.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			_holding = e.pressed
			if e.pressed:
				V9Feel.press_down(hb)
			else:
				V9Feel.press_up(hb, false))
	set_process(true)


func _process(dt: float) -> void :
	if hold_fill == null or not is_instance_valid(hold_fill) or _del_done:
		return
	var full: float = hold_fill.get_parent().size.x - 20.0
	_hold = clampf(_hold + (dt if _holding else -dt * 2.5), 0.0, HOLD_SEC)
	var hw: = full * _hold / HOLD_SEC
	hold_fill.visible = hw > 2.0
	hold_fill.size.x = maxf(hw, hold_fill.size.y)
	hold_fill.modulate.a = clampf(hw / hold_fill.size.y, 0.0, 1.0)
	if _holding and int(_hold * 6.0) != int((_hold - dt) * 6.0):
		V9Feel.haptic("tap")
	if _hold >= HOLD_SEC:
		do_delete()


func do_delete() -> void :
	if _del_done:
		return
	_del_done = true
	_holding = false
	V10Auth.request_deletion()
	V9Feel.big(null, "deny")
	var host: = get_parent() as Control
	if host:
		V10AuthUI.toast(host, V10AuthText.s("acc.del_done"))
	if _del_root and is_instance_valid(_del_root):
		V10AuthUI.close(_del_root)
	V10AuthUI.close(root, func():
		deleted.emit()
		queue_free())
