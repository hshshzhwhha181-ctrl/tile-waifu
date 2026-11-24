class_name V10LoginScreen
extends Control

# The login screen (first launch and after «Выйти»). Key art with the five founders, the logo plate on the sky,
# and the sign-in stack at the bottom, laid out for 9:16 … 9:21 phones and 3:4 tablets.
#   var ls: = V10LoginScreen.make(host, main)      host = a full-screen Control; main may be null (dev scene)
#   var r: Dictionary = await ls.finished          {"provider": "guest"|…, "new_player": bool, "imported": bool}
# Buttons per build flavor (V10Auth.flavor()): RuStore VK ID + Яндекс ID + guest; Google Play Google + guest;
# dev all. «У меня есть аккаунт» opens the e-mail sheet (UI only). Provider buttons need the 152-ФЗ consent tick.

signal finished(result: Dictionary)

const LOGO_SRC: = Vector2(540, 306)
const HERO_ASPECT: = 1400.0 / 1298.0

var main
var art: V10KeyArt
var logo: TextureRect
var stack: Control
var guest_btn: JButton
var prov_btns: = {}
var consent: V10AuthUI.Check
var busy: = false
var _done: = false
var panel_top: = 0.0


static func make(host: Control, m = null) -> V10LoginScreen:
	var s: = V10LoginScreen.new()
	s.name = "V10LoginScreen"
	s.main = m
	s.size = host.size
	s.mouse_filter = Control.MOUSE_FILTER_STOP
	host.add_child(s)
	s._build()
	return s


func _btn_w() -> float:
	return minf(size.x - 80.0, 560.0)


func _build() -> void :
	art = V10KeyArt.make(self, size)
	var W: = size.x
	var H: = size.y
	var bw: = _btn_w()
	var bx: = (W - bw) * 0.5
	var ids: Array = V10Auth.login_buttons()
	# ── the bottom stack, measured from the bottom up ──
	var pad_b: = maxf(18.0, H * 0.018)
	var legal_h: = 34.0
	var consent_h: = 58.0 if not ids.is_empty() else 0.0
	var have_h: = 46.0
	var prov_h: = 80.0
	var gap: = 12.0
	var guest_h: = 112.0
	var or_h: = 30.0 if not ids.is_empty() else 0.0
	var stack_h: = guest_h + gap + or_h + ids.size() * (prov_h + gap) + have_h + 6.0 + consent_h + legal_h + pad_b
	panel_top = H - stack_h
	# dark floor under the stack so the heroines' legs fade out and the buttons read
	var ff: = Common.floor_fade(self, panel_top - 230.0, panel_top + 40.0, Color(0.07, 0.04, 0.09), 0.94)
	ff.name = "StackFade"
	var fb: = ColorRect.new()
	fb.color = Color(0.07, 0.04, 0.09, 0.94)
	fb.position = Vector2(0, panel_top + 40.0)
	fb.size = Vector2(W, H - panel_top - 40.0)
	fb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fb)
	# ── logo + heroines above the stack ──
	var top_pad: = maxf(20.0, float(DisplayServer.get_display_safe_area().position.y) * size.y / maxf(1.0, float(DisplayServer.window_get_size().y)))
	var lw: = minf(W * 0.66, 476.0)
	var lh: = lw * LOGO_SRC.y / LOGO_SRC.x
	var hero_bottom: = panel_top + 120.0
	# tall phones: the group grows a little past the edges (only air and hair there), the rest of the spare height
	# goes above the logo (sky + lanterns); tablets: height-bound, the plate fills the sides
	var overlap: = 34.0
	var max_hw: = minf(W * 1.07, 860.0)
	var avail: = hero_bottom - (top_pad + lh - overlap)
	var hh: = minf(avail, max_hw / HERO_ASPECT)
	var hw: = hh * HERO_ASPECT
	var comp_h: = lh - overlap + hh
	var spare: = hero_bottom - top_pad - comp_h
	var ly: = top_pad + maxf(0.0, spare * 0.8)
	art.place_heroes(Rect2((W - hw) * 0.5, hero_bottom - hh, hw, hh))
	logo = V8Art.rect(V8Art.misc("logo"), Rect2((W - lw) * 0.5, ly, lw, lh))
	logo.name = "Logo"
	logo.pivot_offset = Vector2(lw, lh) * 0.5
	add_child(logo)
	# ── stack ──
	stack = Control.new()
	stack.name = "Stack"
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.position = Vector2(0, panel_top)
	stack.size = Vector2(W, stack_h)
	add_child(stack)
	var y: = 0.0
	guest_btn = JButton.make(V10AuthText.s("login.guest"), "pink", Rect2(bx, y, bw, guest_h), null, 34)
	guest_btn.name = "Btn_guest"
	guest_btn.set_sub(V10AuthText.s("login.guest_sub"), 19)
	guest_btn.shine_every = 3.2
	guest_btn.pressed.connect(_on_guest)
	guest_btn.set_gate(func(): return not busy)
	stack.add_child(guest_btn)
	y += guest_h + gap
	if or_h > 0.0:
		var orl: = UI.center_label(UI.label(V10AuthText.s("login.or"), 18, UI.MUTED, UI.DARK, 3, "body", 800), Rect2(bx, y - 4, bw, or_h))
		stack.add_child(orl)
		y += or_h
	for id in ids:
		var b: = V10AuthUI.provider_button(id, Rect2(bx, y, bw, prov_h))
		b.pressed.connect(_on_provider.bind(id))
		b.set_gate(func(): return not busy and V10Auth.has_consent(), func(): _need_consent())
		stack.add_child(b)
		prov_btns[id] = b
		y += prov_h + gap
	var have: = V10AuthUI.link(V10AuthText.s("login.have"), Rect2(bx, y, bw, have_h), _on_have, 22)
	have.name = "Link_have"
	stack.add_child(have)
	y += have_h + 6.0
	if consent_h > 0.0:
		consent = V10AuthUI.checkbox(Rect2(bx + 6, y, bw - 12, consent_h - 8), V10AuthText.s("login.consent"), V10Auth.has_consent(), func(on): V10Auth.set_consent(on), 17)
		consent.name = "Consent"
		stack.add_child(consent)
		y += consent_h
	_legal_row(y, legal_h)
	_intro()


func _legal_row(y: float, h: float) -> void :
	var W: = size.x
	var row: = Control.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.position = Vector2(0, y)
	row.size = Vector2(W, h)
	stack.add_child(row)
	var t1: = V10AuthText.s("login.terms")
	var t2: = V10AuthText.s("login.privacy")
	var f: = UI.font("body", 800)
	var w1: = f.get_string_size(t1, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 16.0
	var w2: = f.get_string_size(t2, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 16.0
	var age_w: = 52.0
	var total: = w1 + 24.0 + w2 + 24.0 + age_w
	var x: = (W - total) * 0.5
	row.add_child(V10AuthUI.link(t1, Rect2(x, 0, w1, h), func(): open_doc("terms"), 16, Color("d9c6a8")))
	x += w1
	row.add_child(UI.center_label(UI.label("·", 16, UI.MUTED), Rect2(x, 0, 24, h)))
	x += 24.0
	row.add_child(V10AuthUI.link(t2, Rect2(x, 0, w2, h), func(): open_doc("privacy"), 16, Color("d9c6a8")))
	x += w2 + 24.0
	var age: = UI.rbox("red", Rect2(x, (h - 28) * 0.5, age_w, 28), 14, 2, 4)
	age.mouse_filter = Control.MOUSE_FILTER_IGNORE
	age.add_child(UI.center_label(UI.label(V10AuthText.s("login.age"), 15, Color.WHITE, Color("42101a"), 3, "body", 900), Rect2(0, 0, age_w, 28)))
	row.add_child(age)


# terms / privacy: real URLs arrive with 1.0 (CEO_PLAN «Юр. документы»); until then a polite toast
const DOC_URLS: = {"terms": "", "privacy": ""}

func open_doc(which: String) -> void :
	var url: = str(DOC_URLS.get(which, ""))
	if url != "":
		OS.shell_open(url)
	else:
		say(V10AuthText.s("stub.legal_soon"))


func _intro() -> void :
	art.intro()
	UI.pop_in(logo, 0.35, 0.6)
	var i: = 0
	for c in stack.get_children():
		UI.slide_in(c, Vector2(0, 40), 0.5 + i * 0.06, 0.4)
		i += 1


# toasts on this screen sit just above the stack: never over the logo or the faces
func say(text: String, hero: = "") -> Control:
	return V10AuthUI.toast(self, text, hero, panel_top - 96.0)


func _need_consent() -> void :
	if consent:
		consent.nudge()
	say(V10AuthText.s("login.consent_need"))


func _on_guest() -> void :
	if busy or _done:
		return
	busy = true
	V10Auth.sign_in_guest()
	await _after_sign_in("guest")


func _on_provider(id: String) -> void :
	if busy or _done:
		return
	busy = true
	var b: JButton = prov_btns[id]
	var cap: = b.lbl.text
	b.lbl.text = V10AuthText.s("login.connecting")
	var r: Dictionary = await V10Auth.sign_in(id)
	if not is_instance_valid(b):
		return
	b.lbl.text = cap
	busy = false
	if bool(r.get("ok", false)):
		busy = true
		V9Feel.success(b)
		await _after_sign_in(id)
		return
	match str(r.code):
		"consent_required":
			_need_consent()
		"cancelled":
			say(V10AuthText.s("stub.cancelled"))
		"network":
			say(V10AuthText.s("stub.network"))
			_point_guest()
		_:
			say(V10AuthText.s("stub.not_available_yet", V10AuthText.provider_name(id)), "mc")
			_point_guest()


# after a stub refusal the guest button invites the tap: a soft pulse and a shine
func _point_guest() -> void :
	V9Feel.success(guest_btn, "", 0.5)
	guest_btn.box.shine(0.2, 0.8)


func _on_have() -> void :
	if busy:
		return
	V10EmailSheet.open(self, main)


func _after_sign_in(prov: String, imported: = false) -> void :
	var new_player: = not bool(G.S.get("profile_done", false))
	if new_player and not imported:
		var ns: = V10NickSheet.open(self)
		await ns.finished
	await V10Auth.age_gate(self)
	finish({"provider": prov, "new_player": new_player, "imported": imported})


func on_imported() -> void :
	# the e-mail sheet's «код восстановления» path replaced the save (V8ProfileCard): sign in as that player
	busy = true
	V10Auth.sign_in_guest()
	await _after_sign_in("guest", true)


func finish(r: Dictionary) -> void :
	if _done:
		return
	_done = true
	Sfx.play("reveal_sr", 0.95, -4)
	var t: = create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.45)
	await t.finished
	finished.emit(r)
	queue_free()


func dev_freeze() -> void :
	art.dev_freeze()
	for c in stack.get_children():
		c.modulate.a = 1.0
	logo.scale = Vector2.ONE
	logo.modulate.a = 1.0
