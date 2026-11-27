class_name V10AccountScreen
extends Control

# V10AccountScreen — 0.12.0 «Аккаунт · Онлайн»: profile card + cloud save, one-tap Яндекс ID / Google / VK ID / Telegram
# linking, nick + password login / registration (a guest is upgraded in place, the server keeps the save) and the server
# address. Imperial plum-and-gold lacquer (V10OnlineUi), absolute rects in the 720 px column, text 20–28 px.
# Offline is the default case: every network call resolves (≤ 4 s) and the screen keeps working locally.

const COL_W: = 720.0
const M: = 32.0
const CARD_H: = 300.0
const BRAND_H: = 84.0
const BRAND_GAP: = 12.0
const EDIT_H: = 64.0

var main = null
var args: Dictionary = {}
var net: V10Online = null
var provider_buttons: = {}          # provider -> Panel
var status_chip: Panel = null
var body: Control = null
var scroll: ScrollContainer = null

var W: = 720.0
var H: = 1280.0
var cx: = 0.0
var iw: = 656.0
var safe_t: = 0.0
var safe_b: = 0.0
var content_h: = 0.0

var _busy: = false
var _booted: = false
var _header_b: = 0.0
var _prov_state: = {}               # provider -> Label (right side)
var _card: Panel = null
var _avatar: Control = null
var _avatar_hero: = ""
var _nick_l: Label = null
var _id_l: Label = null
var _elo_l: Label = null
var _cloud_l: Label = null
var _login_e: LineEdit = null
var _pass_e: LineEdit = null
var _url_e: LineEdit = null
var _logout_b: Panel = null


func build(m, a: Dictionary = {}) -> void:
	main = m
	args = a.duplicate(true)
	if main != null and main is Object and main.has_method("show_chrome"):
		main.call("show_chrome", false, false)
	for c in get_children():
		remove_child(c)
		c.queue_free()
	provider_buttons = {}
	_prov_state = {}
	_avatar = null
	_avatar_hero = ""
	scroll = null
	_metrics()
	V10OnlineUi.backdrop(self, "bg_palace", W, H)
	_build_header()
	_build_body()
	net = V10Online.new()
	net.name = "Net"
	add_child(net)
	net.status_changed.connect(_on_status)
	refresh()
	_busy = true
	call_deferred("_boot")


func busy() -> bool:
	return _busy


func booted() -> bool:
	return _booted


# ── layout ──────────────────────────────────────────────────────────────────────────────────────────────────────

static func _num(o, key: String) -> float:
	if o == null or not (o is Object):
		return 0.0
	var v: Variant = (o as Object).get(key)
	if v is float or v is int:
		return float(v)
	return 0.0


func _metrics() -> void:
	var s: = size
	if s.x <= 0.0 or s.y <= 0.0:
		s = get_viewport_rect().size if is_inside_tree() else Vector2(720, 1280)
		if s.x <= 0.0 or s.y <= 0.0:
			s = Vector2(720, 1280)
		size = s
	W = s.x
	H = s.y
	var cw: = minf(COL_W, W)
	cx = floorf(maxf(0.0, (W - COL_W) * 0.5))
	iw = cw - 2.0 * M
	safe_t = _num(main, "safe_top")
	safe_b = _num(main, "safe_bottom")


func _build_header() -> void:
	var top: = 20.0 + safe_t
	var back: = V10OnlineUi.button("‹", Rect2(cx + M, top, 56, 56), _on_back, V10OnlineUi.PLUM_HI, V10OnlineUi.GOLD_HI, 28)
	back.name = "Back"
	add_child(back)
	var t: = V10OnlineUi.label("Аккаунт · Онлайн", Rect2(cx + M + 72, top, iw - 72, 56), 28, V10OnlineUi.GOLD, HORIZONTAL_ALIGNMENT_LEFT, 900)
	t.name = "Title"
	add_child(t)
	_header_b = top + 56.0 + 16.0


func _section(title: String, y: float) -> float:
	body.add_child(V10OnlineUi.label(title, Rect2(cx + M, y, iw, 36), 24, V10OnlineUi.GOLD, HORIZONTAL_ALIGNMENT_LEFT, 900))
	var line: = ColorRect.new()
	line.color = Color(V10OnlineUi.GOLD, 0.35)
	line.position = Vector2(cx + M, y + 38)
	line.size = Vector2(iw, 2)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(line)
	return y + 50.0


func _build_body() -> void:
	body = Control.new()
	body.name = "Body"
	body.mouse_filter = Control.MOUSE_FILTER_PASS
	var y: = 0.0
	_build_card(y)
	y += CARD_H + 24.0
	y = _section("Вход и привязка", y)
	for p in V10OnlineCfg.PROVIDERS:
		_build_brand(String(p), y)
		y += BRAND_H + BRAND_GAP
	y += 24.0 - BRAND_GAP
	y = _section("Вход по нику и паролю", y)
	_login_e = V10OnlineUi.line_edit(Rect2(cx + M, y, iw, EDIT_H), "Ник или e-mail", "", false, 22)
	_login_e.name = "LoginEdit"
	body.add_child(_login_e)
	y += EDIT_H + 12.0
	_pass_e = V10OnlineUi.line_edit(Rect2(cx + M, y, iw, EDIT_H), "Пароль (от шести символов)", "", true, 22)
	_pass_e.name = "PassEdit"
	body.add_child(_pass_e)
	y += EDIT_H + 12.0
	var bw: = (iw - 16.0) * 0.5
	var b_login: = V10OnlineUi.button("Войти", Rect2(cx + M, y, bw, 68), _on_login, V10OnlineUi.GOLD, V10OnlineUi.INK, 24, V10OnlineUi.GOLD_HI)
	b_login.name = "LoginBtn"
	body.add_child(b_login)
	var b_reg: = V10OnlineUi.button("Регистрация", Rect2(cx + M + bw + 16.0, y, bw, 68), _on_register)
	b_reg.name = "RegisterBtn"
	body.add_child(b_reg)
	y += 68.0 + 24.0
	y = _section("Адрес сервера", y)
	var chk_w: = 180.0
	_url_e = V10OnlineUi.line_edit(Rect2(cx + M, y, iw - chk_w - 16.0, EDIT_H), "http://host:port", V10OnlineCfg.url(), false, 22)
	_url_e.name = "UrlEdit"
	body.add_child(_url_e)
	var b_chk: = V10OnlineUi.button("Проверить", Rect2(cx + M + iw - chk_w, y, chk_w, EDIT_H), _on_check)
	b_chk.name = "CheckBtn"
	body.add_child(b_chk)
	y += EDIT_H + 20.0
	var lw: = 320.0
	_logout_b = V10OnlineUi.button("Выйти из аккаунта", Rect2(cx + M + (iw - lw) * 0.5, y, lw, 48), _on_logout, Color(0, 0, 0, 0), V10OnlineUi.RED, 22, Color(0, 0, 0, 0))
	_logout_b.name = "LogoutBtn"
	var sb: StyleBoxFlat = (_logout_b.get_theme_stylebox("panel") as StyleBoxFlat).duplicate()
	sb.shadow_size = 0
	sb.shadow_color = Color(0, 0, 0, 0)
	_logout_b.add_theme_stylebox_override("panel", sb)
	body.add_child(_logout_b)
	y += 48.0 + 16.0
	content_h = y
	var avail: = H - _header_b - safe_b
	if content_h <= avail:
		body.position = Vector2(0, _header_b)
		body.size = Vector2(W, content_h)
		add_child(body)
	else:
		scroll = ScrollContainer.new()
		scroll.name = "Scroll"
		scroll.position = Vector2(0, _header_b)
		scroll.size = Vector2(W, maxf(120.0, avail))
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		body.custom_minimum_size = Vector2(0, content_h)
		body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(body)
		add_child(scroll)


func _build_card(y: float) -> void:
	_card = V10OnlineUi.panel(Rect2(cx + M, y, iw, CARD_H))
	_card.name = "ProfileCard"
	body.add_child(_card)
	var tx: = 164.0
	var tw: = iw - tx - 24.0
	_nick_l = V10OnlineUi.label("", Rect2(tx, 20, tw, 38), 28, V10OnlineUi.CREAM, HORIZONTAL_ALIGNMENT_LEFT, 900)
	_nick_l.name = "Nick"
	_card.add_child(_nick_l)
	_id_l = V10OnlineUi.label("", Rect2(tx, 60, tw, 30), 22, V10OnlineUi.MUTED)
	_id_l.name = "Id"
	_card.add_child(_id_l)
	_elo_l = V10OnlineUi.label("", Rect2(tx, 92, tw, 30), 22, V10OnlineUi.GOLD_HI)
	_elo_l.name = "Elo"
	_card.add_child(_elo_l)
	status_chip = V10OnlineUi.status_chip(Rect2(tx, 128, minf(260.0, tw), 40), false)
	_card.add_child(status_chip)
	var bw: = (iw - 48.0 - 16.0) * 0.5
	var b_push: = V10OnlineUi.button("Сохранить в облако", Rect2(24, 188, bw, 64), _on_push, V10OnlineUi.PLUM_HI, V10OnlineUi.GOLD_HI, 22)
	b_push.name = "PushBtn"
	_card.add_child(b_push)
	var b_pull: = V10OnlineUi.button("Загрузить из облака", Rect2(24 + bw + 16, 188, bw, 64), _on_pull, V10OnlineUi.PLUM_HI, V10OnlineUi.GOLD_HI, 22)
	b_pull.name = "PullBtn"
	_card.add_child(b_pull)
	_cloud_l = V10OnlineUi.label("", Rect2(24, 262, iw - 48, 26), 20, V10OnlineUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER, 800)
	_cloud_l.name = "Cloud"
	_card.add_child(_cloud_l)


func _build_brand(p: String, y: float) -> void:
	var br: Dictionary = V10OnlineUi.BRAND.get(p, {"bg": V10OnlineUi.GOLD, "fg": V10OnlineUi.INK, "mark": "?"})
	var bg: Color = br.bg
	var fg: Color = br.fg
	var b: = V10OnlineUi.button("", Rect2(cx + M, y, iw, BRAND_H), _on_provider.bind(p), V10OnlineUi.PLUM_HI, V10OnlineUi.GOLD_HI, 24, Color(bg, 0.9))
	b.name = "Brand_" + p
	var mark: = V10OnlineUi.panel(Rect2(14, 12, 60, 60), bg, Color(V10OnlineUi.GOLD, 0.9), 30, 2)
	var mk: = String(br.mark)
	mark.add_child(V10OnlineUi.label(mk, Rect2(0, 0, 60, 60), 22 if mk.length() > 1 else 26, fg, HORIZONTAL_ALIGNMENT_CENTER, 900))
	b.add_child(mark)
	var st_w: = 190.0
	b.add_child(V10OnlineUi.label(V10OnlineCfg.title_of(p), Rect2(92, 0, iw - 92 - st_w - 20, BRAND_H), 26, V10OnlineUi.CREAM, HORIZONTAL_ALIGNMENT_LEFT, 900))
	var st: = V10OnlineUi.label("Войти", Rect2(iw - st_w - 20, 0, st_w, BRAND_H), 24, V10OnlineUi.GOLD_HI, HORIZONTAL_ALIGNMENT_RIGHT, 900)
	st.name = "State"
	b.add_child(st)
	body.add_child(b)
	provider_buttons[p] = b
	_prov_state[p] = st


# ── state ───────────────────────────────────────────────────────────────────────────────────────────────────────

func _boot() -> void:
	_busy = true
	if net != null and is_instance_valid(net):
		var h: Dictionary = await net.check_health()
		if bool(h.get("ok", false)):
			await net.ensure_session()
	_busy = false
	_booted = true
	refresh()


static func _paint(l: Label, txt: String, col: Color) -> void:
	if l == null or not is_instance_valid(l):
		return
	l.text = txt
	if l.label_settings != null:
		l.label_settings = l.label_settings.duplicate()
		l.label_settings.font_color = col
	else:
		l.add_theme_color_override("font_color", col)


func refresh() -> void:
	if _nick_l == null or not is_instance_valid(_nick_l):
		return
	var u: = V10OnlineCfg.user()
	var on: = net != null and is_instance_valid(net) and net.online
	V10OnlineUi.set_text(_nick_l, V10OnlineCfg.nick())
	var uid: = int(u.get("id", 0))
	if uid > 0:
		V10OnlineUi.set_text(_id_l, "ID %d · %s" % [uid, "Гость" if V10OnlineCfg.is_guest() else "Аккаунт"])
	else:
		V10OnlineUi.set_text(_id_l, "Гость · без сервера")
	V10OnlineUi.set_text(_elo_l, "ELO %d · В/П %d / %d" % [V10OnlineCfg.elo(), V10OnlineCfg.wins(), V10OnlineCfg.losses()])
	V10OnlineUi.set_status(status_chip, on)
	V10OnlineUi.set_text(_cloud_l, _cloud_text())
	var hero: = V10OnlineCfg.avatar()
	if hero != _avatar_hero or _avatar == null or not is_instance_valid(_avatar):
		if _avatar != null and is_instance_valid(_avatar):
			_avatar.queue_free()
		_avatar = Common.avatar(hero, Rect2(24, 24, 120, 120))
		_avatar.name = "Avatar"
		_card.add_child(_avatar)
		_avatar_hero = hero
	for p in V10OnlineCfg.PROVIDERS:
		var linked: = V10OnlineCfg.is_linked(String(p))
		var b: Panel = provider_buttons.get(p)
		if b != null and is_instance_valid(b):
			b.set_meta("linked", linked)
		_paint(_prov_state.get(p), "Привязан ✓" if linked else "Войти", V10OnlineUi.GREEN if linked else V10OnlineUi.GOLD_HI)
	if _logout_b != null and is_instance_valid(_logout_b):
		_logout_b.visible = V10OnlineCfg.has_session()


func _cloud_text() -> String:
	var st: = V10OnlineCfg.st()
	var ver: = int(st.get("save_version", 0))
	var ts: = int(st.get("last_sync", 0))
	if ts <= 0:
		return "Облако: версия %d" % [ver] if ver > 0 else "Облако: ещё не синхронизировано"
	return "Облако: версия %d · %s" % [ver, _hhmm(ts)]


static func _hhmm(ts: int) -> String:
	var bias: = int(Time.get_time_zone_from_system().get("bias", 0))
	var d: = Time.get_datetime_dict_from_unix_time(ts + bias * 60)
	return str(int(d.get("hour", 0))).pad_zeros(2) + ":" + str(int(d.get("minute", 0))).pad_zeros(2)


static func err_text(r: Dictionary) -> String:
	var e: = String(r.get("error", ""))
	if bool(r.get("offline", false)) or e == "offline":
		return "Нет связи с сервером"
	match e:
		"bad_credentials":
			return "Неверный ник или пароль"
		"weak_password":
			return "Пароль — минимум шесть символов"
		"nick_taken":
			return "Этот ник уже занят"
		"email_taken":
			return "Этот e-mail уже занят"
		"provider_not_configured":
			return "Вход через этот сервис пока не настроен"
		"sandbox_disabled":
			return "Тестовый вход отключён на сервере"
		"timeout":
			return "Время ожидания истекло"
		"conflict":
			return "В облаке более новая версия — загрузите её"
		"unauthorized":
			return "Сессия истекла — войдите снова"
	var msg: = String(r.get("msg", ""))
	if msg != "":
		return msg
	return "Ошибка сервера: %s" % [e] if e != "" else "Что-то пошло не так"


func _toast(txt: String, col: = V10OnlineUi.GOLD_HI) -> void:
	V10OnlineUi.toast(self, txt, W, H - safe_b - 150.0, col)


func _on_status(is_online: bool) -> void:
	V10OnlineUi.set_status(status_chip, is_online)


func _on_back() -> void:
	if main != null and main is Object and main.has_method("back"):
		main.call("back")


func _ensure() -> Dictionary:
	if V10OnlineCfg.has_session():
		return {"ok": true}
	return await net.ensure_session()


# ── actions (each one is a coroutine, guarded by busy) ──────────────────────────────────────────────────────────

func _on_provider(p: String) -> void:
	if _busy or net == null:
		return
	_busy = true
	_paint(_prov_state.get(p), "…", V10OnlineUi.MUTED)
	var r: Dictionary = await net.link_provider(p)
	_busy = false
	refresh()
	if bool(r.get("ok", false)):
		_toast("%s привязан ✓" % [V10OnlineCfg.title_of(p)], V10OnlineUi.GREEN)
	else:
		_toast(err_text(r), V10OnlineUi.RED)


func _on_push() -> void:
	if _busy or net == null:
		return
	_busy = true
	var r: Dictionary = await _ensure()
	if bool(r.get("ok", false)):
		r = await net.cloud_push()
	_busy = false
	refresh()
	if bool(r.get("ok", false)):
		_toast("Сохранено в облако ✓", V10OnlineUi.GREEN)
	else:
		_toast(err_text(r), V10OnlineUi.RED)


func _on_pull() -> void:
	if _busy or net == null:
		return
	_busy = true
	var r: Dictionary = await _ensure()
	if bool(r.get("ok", false)):
		r = await net.cloud_pull()
	_busy = false
	refresh()
	if bool(r.get("ok", false)):
		if bool(r.get("applied", false)):
			_toast("Сохранение загружено из облака ✓", V10OnlineUi.GREEN)
		else:
			_toast("В облаке пока нет сохранения")
	else:
		_toast(err_text(r), V10OnlineUi.RED)


func _on_login() -> void:
	if _busy or net == null:
		return
	var l: = _login_e.text.strip_edges()
	var pw: = _pass_e.text
	if l == "" or pw == "":
		_toast("Введите ник и пароль", V10OnlineUi.RED)
		return
	_busy = true
	var r: Dictionary = await net.login(l, pw)
	_busy = false
	refresh()
	if bool(r.get("ok", false)):
		_pass_e.text = ""
		_toast("Вход выполнен ✓ · %s" % [V10OnlineCfg.nick()], V10OnlineUi.GREEN)
	else:
		_toast(err_text(r), V10OnlineUi.RED)


func _on_register() -> void:
	if _busy or net == null:
		return
	var l: = _login_e.text.strip_edges()
	var pw: = _pass_e.text
	if l == "" or pw == "":
		_toast("Введите ник и пароль", V10OnlineUi.RED)
		return
	if pw.length() < 6:
		_toast(err_text({"error": "weak_password"}), V10OnlineUi.RED)
		return
	var nick: = l
	var email: = ""
	if "@" in l:
		email = l
		nick = V10OnlineCfg.nick()
	var was_guest: = V10OnlineCfg.has_session() and V10OnlineCfg.is_guest()
	_busy = true
	var r: Dictionary = await net.register(nick, email, pw)
	_busy = false
	refresh()
	if bool(r.get("ok", false)):
		_pass_e.text = ""
		_toast("Аккаунт создан ✓ · прогресс сохранён" if was_guest else "Аккаунт создан ✓", V10OnlineUi.GREEN)
	else:
		_toast(err_text(r), V10OnlineUi.RED)


func _on_check() -> void:
	if _busy or net == null:
		return
	_busy = true
	V10OnlineCfg.set_url(_url_e.text)
	_url_e.text = V10OnlineCfg.url()
	net.health = {}
	var h: Dictionary = await net.check_health()
	var ok: = bool(h.get("ok", false))
	if ok:
		await net.ensure_session()
	_busy = false
	refresh()
	if ok:
		_toast("Сервер на связи ✓ · версия %s" % [String(h.get("version", "?"))], V10OnlineUi.GREEN)
	else:
		_toast("Нет связи с сервером", V10OnlineUi.RED)


func _on_logout() -> void:
	if _busy or net == null:
		return
	_busy = true
	await net.logout()
	_busy = false
	refresh()
	_toast("Вы вышли из аккаунта")
