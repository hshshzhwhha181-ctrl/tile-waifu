class_name V10PvpOnlineScreen
extends Control

# V10PvpOnlineScreen — 0.12.0 «Онлайн-Дуэль · PvP 1×1» (registered as "v10pvp").
# Lobby tabs: Быстрый бой (ELO) · Комната по коду · Топ игроков. Search radar → live 1×1 race on one shared seed
# (TrayBoard), ТЫ vs СОПЕРНИК progress, sabotage Лёд / Туман charged by pairs, 4 sticker emotes, incoming sabotage
# VFX, result with the ELO change. Runs over the real WebSocket (V10Online) or the local sparring bot offline.

const U: = preload("res://scripts/v10/online/online_ui.gd")
const BANNER_ART: = "res://assets/v10/hf_ui/banner_pvp_online.webp"
const CHARGE_PAIRS: = 4
const SLOTS_N: = 5
const EMOTE_TEXT: = {"laugh": "Ха-ха!", "angry": "Грр!", "heart": "Обожаю!", "cool": "Круто!"}
const TAB_TITLES: = ["Быстрый бой", "Комната", "Топ игроков"]

var main = null
var W: = 720.0
var H: = 1280.0
var safe_t: = 0.0
var safe_b: = 0.0
var net: V10Online = null
var phase: = "lobby"        # lobby | search | room_wait | match | result
var tab: = 0

var lobby_root: Control
var page: Control
var tab_btns: Array = []
var status_chip: Panel
var elo_lbl: Label
var search_root: Control
var search_time_lbl: Label
var room_code_lbl: Label
var code_edit: LineEdit
var _search_t: = 0.0

var match_root: Control
var board: TrayBoard = null
var board_rect: = Rect2()
var slot_rects: Array = []
var match_info: = {}
var opp: = {}
var duration: = 180.0
var elapsed: = 0.0
var score: = 0
var charge: = 0
var tiles_total: = 0
var overflows: = 0
var opp_left: = 0
var opp_score: = 0
var my_bar: Panel
var opp_bar: Panel
var my_lbl: Label
var opp_lbl: Label
var timer_lbl: Label
var surrender_btn: Control
var charge_bar: Panel
var charge_lbl: Label
var sab_btns: = {}
var fx_layer: Control
var flash: ColorRect
var result_root: Control
var last_result: = {}
var sabotage_hits: = 0
var emotes_seen: = 0


static func _num(o, key: String) -> float:
	if o is Dictionary:
		var dv: Variant = (o as Dictionary).get(key, 0.0)
		return float(dv) if (dv is float or dv is int) else 0.0
	if o != null and o is Object:
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
	W = s.x
	H = s.y
	size = Vector2(W, H)
	var ins: = V10Layout.safe_insets(s)
	var raw_t: = maxf(_num(main, "safe_top"), float(ins.get("top", 0.0)))
	var raw_b: = maxf(_num(main, "safe_bottom"), float(ins.get("bottom", 0.0)))
	if OS.has_feature("mobile"):
		var sa: = DisplayServer.get_display_safe_area()
		var win: = DisplayServer.window_get_size()
		if sa.size.y > 0 and win.y > 0:
			var ky: = H / float(win.y)
			raw_t = maxf(raw_t, clampf(float(sa.position.y) * ky, 0.0, 110.0))
			raw_b = maxf(raw_b, clampf(maxf(0.0, float(win.y) - float(sa.end.y)) * ky, 0.0, 80.0))
	var in_cr: bool = false
	if main != null and main is Object and ("CR" in main):
		var cr: Variant = (main as Object).get("CR")
		if cr is Rect2:
			in_cr = absf(position.y - (cr as Rect2).position.y) < 1.0 and absf(H - (cr as Rect2).size.y) < 1.0
	safe_t = maxf(0.0, raw_t - (position.y if in_cr else 0.0))
	safe_b = maxf(0.0, raw_b - (maxf(0.0, _num(main, "H") - position.y - H) if in_cr else 0.0))


func build(m, args: = {}) -> void:
	main = m
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_metrics()
	if main != null and main is Object and main.has_method("show_chrome"):
		main.call("show_chrome", false, false)
	U.backdrop(self, "bg_palace", W, H)
	net = V10Online.new()
	net.name = "Net"
	add_child(net)
	net.status_changed.connect(_on_status)
	net.queued.connect(func(_d: Dictionary) -> void: pass)
	net.room_created.connect(_on_room_created)
	net.match_found.connect(_on_match_found)
	net.opponent_progress.connect(_on_opp_progress)
	net.sabotage_received.connect(apply_sabotage)
	net.emote_received.connect(_on_emote)
	net.match_ended.connect(show_result)
	net.net_error.connect(_on_net_error)
	net.disconnected.connect(_on_disconnected)
	_build_lobby()
	fx_layer = Control.new()
	fx_layer.size = Vector2(W, H)
	fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_layer.z_index = 260
	add_child(fx_layer)
	var br: = V10Layout.bleed_rect(self)
	flash = ColorRect.new()
	flash.position = br.position
	flash.size = br.size
	flash.color = Color(0.4, 0.8, 1.0, 0.0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.z_index = 250
	add_child(flash)
	tab = clampi(int(args.get("tab", 0)), 0, 2)
	select_tab(tab)
	if not bool(args.get("no_net", false)):
		_boot_net.call_deferred()


func _boot_net() -> void:
	var h: = await net.check_health()
	if bool(h.get("ok", false)):
		await net.ensure_session()
	_refresh_profile()


func _exit_tree() -> void:
	if net != null and is_instance_valid(net):
		net.pvp_close()


func _go_back() -> void:
	if phase == "match":
		surrender()
		return
	if phase in ["search", "room_wait"]:
		cancel_search()
		return
	if net != null:
		net.pvp_close()
	if main != null and main is Object and main.has_method("back"):
		main.call("back")


# ── lobby ─────────────────────────────────────────────────────────────────────────────────────────────────────────

func _build_lobby() -> void:
	lobby_root = Control.new()
	lobby_root.size = Vector2(W, H)
	lobby_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lobby_root)
	var top: = 14.0 + safe_t
	var back_b: = U.button("‹", Rect2(16, top, 64, 64), _go_back, U.PLUM_HI, U.GOLD_HI, 30)
	back_b.name = "Back"
	lobby_root.add_child(back_b)
	lobby_root.add_child(U.label("Онлайн-Дуэль · PvP 1×1", Rect2(92, top, W - 110, 64), 28, U.GOLD_HI, HORIZONTAL_ALIGNMENT_LEFT, 900))
	# profile strip
	var py: = top + 76.0
	var pr: = Rect2(16, py, W - 32, 128)
	lobby_root.add_child(U.panel(pr, U.PLUM, U.GOLD, 20))
	lobby_root.add_child(Common.avatar(V10OnlineCfg.avatar(), Rect2(30, py + 12, 104, 104)))
	var nick_l: = U.label(V10OnlineCfg.nick(), Rect2(150, py + 14, 300, 40), 28, U.CREAM)
	nick_l.name = "Nick"
	lobby_root.add_child(nick_l)
	elo_lbl = U.label("", Rect2(150, py + 60, W - 190, 40), 22, U.GOLD)
	lobby_root.add_child(elo_lbl)
	status_chip = U.status_chip(Rect2(W - 262, py + 16, 230, 40), net.online)
	lobby_root.add_child(status_chip)
	# tabs
	var tabs_y: = py + 144.0
	tab_btns.clear()
	var tw: = (W - 32.0 - 24.0) / 3.0
	for i in 3:
		var idx: = i
		var b: = U.button(TAB_TITLES[i], Rect2(16 + i * (tw + 12.0), tabs_y, tw, 64), func() -> void: select_tab(idx), U.PLUM_LO, U.CREAM, 23)
		lobby_root.add_child(b)
		tab_btns.append(b)
	var page_y: = tabs_y + 80.0
	page = Control.new()
	page.position = Vector2(0, page_y)
	page.size = Vector2(W, maxf(320.0, H - page_y - safe_b))
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lobby_root.add_child(page)
	_refresh_profile()


func _refresh_profile() -> void:
	if elo_lbl == null or not is_instance_valid(elo_lbl):
		return
	elo_lbl.text = "ELO %d · Победы %d · Поражения %d" % [V10OnlineCfg.elo(), V10OnlineCfg.wins(), V10OnlineCfg.losses()]
	var n: = lobby_root.get_node_or_null("Nick") as Label
	if n:
		n.text = V10OnlineCfg.nick()
	U.set_status(status_chip, net.online)


func _on_status(is_online: bool) -> void:
	U.set_status(status_chip, is_online)


func select_tab(i: int) -> void:
	tab = i
	for k in tab_btns.size():
		var b: Panel = tab_btns[k]
		var sb: StyleBoxFlat = (b.get_theme_stylebox("panel") as StyleBoxFlat).duplicate()
		sb.bg_color = Color("#6B2A4E") if k == i else U.PLUM_LO
		sb.border_color = U.GOLD_HI if k == i else Color(U.GOLD, 0.5)
		sb.set_border_width_all(3 if k == i else 2)
		b.add_theme_stylebox_override("panel", sb)
	for c in page.get_children():
		c.queue_free()
	room_code_lbl = null
	code_edit = null
	match i:
		0:
			_page_quick()
		1:
			_page_room()
		2:
			_page_top()


func _page_quick() -> void:
	var ban_r: = Rect2(26, 12, W - 52, 176)
	var vy: = ban_r.end.y + 18.0
	var av_sz: = 164.0
	var lines: = [
		"Одна доска на двоих — кто первым разберёт её, тот победил.",
		"Каждые 4 пары заряжают саботаж: Лёд или Туман на доску соперника.",
		"Нет живого игрока за 6 секунд — выйдет умный спарринг-соперник.",
	]
	var rules_y: = vy + av_sz + 48.0
	var btn_sz: = Vector2(460, 92)
	var by: = rules_y + float(lines.size()) * 68.0 + 18.0
	var card: = Rect2(16, 0, W - 32, by + btn_sz.y + 28.0)
	page.add_child(U.panel(card, U.PLUM, U.GOLD, 22))
	# gold-trimmed top banner strip with Higgsfield artwork + subtle bottom shade
	var ban_clip: = Panel.new()
	ban_clip.name = "QuickBanner"
	ban_clip.position = ban_r.position
	ban_clip.size = ban_r.size
	ban_clip.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	ban_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bsb: = StyleBoxFlat.new()
	bsb.bg_color = U.PLUM_HI
	bsb.set_corner_radius_all(16)
	ban_clip.add_theme_stylebox_override("panel", bsb)
	if ResourceLoader.exists(BANNER_ART):
		var btex: = load(BANNER_ART) as Texture2D
		if btex != null:
			var tr: = TextureRect.new()
			tr.texture = btex
			var tw: = maxf(1.0, float(btex.get_width()))
			var th: = maxf(1.0, float(btex.get_height()))
			var sc: = maxf(ban_r.size.x / tw, ban_r.size.y / th)
			var dw: = tw * sc
			var dh: = th * sc
			tr.position = Vector2((ban_r.size.x - dw) * 0.5, -(dh - ban_r.size.y) * 0.46)
			tr.size = Vector2(dw, dh)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_SCALE
			tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ban_clip.add_child(tr)
	var shade: = _BannerShade.new()
	shade.size = ban_r.size
	ban_clip.add_child(shade)
	page.add_child(ban_clip)
	var ban_trim: = Panel.new()
	ban_trim.position = ban_r.position
	ban_trim.size = ban_r.size
	ban_trim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tsb: = StyleBoxFlat.new()
	tsb.bg_color = Color(0, 0, 0, 0)
	tsb.border_color = U.GOLD
	tsb.set_border_width_all(2)
	tsb.set_corner_radius_all(16)
	ban_trim.add_theme_stylebox_override("panel", tsb)
	page.add_child(ban_trim)
	page.add_child(U.label("Быстрый бой · подбор по ELO", Rect2(36, ban_r.end.y - 48.0, W - 72, 42), 26, U.GOLD_HI, HORIZONTAL_ALIGNMENT_CENTER, 900))
	# VS showcase
	page.add_child(Common.avatar(V10OnlineCfg.avatar(), Rect2(74, vy, av_sz, av_sz)))
	page.add_child(Common.avatar("rin", Rect2(W - 74 - av_sz, vy, av_sz, av_sz), "pink"))
	var vs_l: = U.label("VS", Rect2(W * 0.5 - 70, vy + 36, 140, 90), 28, U.GOLD_HI, HORIZONTAL_ALIGNMENT_CENTER, 900)
	vs_l.label_settings = vs_l.label_settings.duplicate()
	vs_l.label_settings.font_size = 62
	page.add_child(vs_l)
	page.add_child(U.label("Ты", Rect2(74, vy + av_sz + 6.0, av_sz, 32), 22, U.CREAM, HORIZONTAL_ALIGNMENT_CENTER))
	page.add_child(U.label("Соперник", Rect2(W - 74 - av_sz, vy + av_sz + 6.0, av_sz, 32), 22, U.CREAM, HORIZONTAL_ALIGNMENT_CENTER))
	var y: = rules_y
	for s in lines:
		page.add_child(U.para("◆  " + s, Rect2(44, y, W - 88, 62), 22, U.CREAM))
		y += 68.0
	var cta: = V10Button.make("play", "Найти соперника", btn_sz)
	cta.name = "FindMatchBtn"
	cta.position = Vector2((W - btn_sz.x) * 0.5, by)
	cta.size = btn_sz
	cta.set_meta("ux_role", "primary")
	cta.pressed.connect(func() -> void:
		U.haptic("tap")
		Sfx.play("tap", 1.0, -6)
		start_matchmaking())
	page.add_child(cta)


class _BannerShade extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var w: = size.x
		var h: = size.y
		var y0: = h * 0.36
		var ym: = h * 0.72
		var c0: = Color(0.08, 0.02, 0.12, 0.0)
		var cm: = Color(0.08, 0.02, 0.12, 0.54)
		var c1: = Color(0.08, 0.02, 0.12, 0.90)
		draw_polygon(PackedVector2Array([Vector2(0, y0), Vector2(w, y0), Vector2(w, ym), Vector2(0, ym)]),
			PackedColorArray([c0, c0, cm, cm]))
		draw_polygon(PackedVector2Array([Vector2(0, ym), Vector2(w, ym), Vector2(w, h), Vector2(0, h)]),
			PackedColorArray([cm, cm, c1, c1]))


func _page_room() -> void:
	var card: = Rect2(16, 0, W - 32, 640)
	page.add_child(U.panel(card, U.PLUM, U.GOLD, 22))
	page.add_child(U.label("Комната по коду", Rect2(36, 16, W - 72, 44), 27, U.GOLD_HI, HORIZONTAL_ALIGNMENT_CENTER, 900))
	page.add_child(U.para("Создай комнату и отправь другу 6-значный код — или введи код друга.", Rect2(44, 66, W - 88, 64), 22, U.CREAM, HORIZONTAL_ALIGNMENT_CENTER))
	page.add_child(U.button("Создать комнату", Rect2(56, 148, W - 112, 84), create_room, Color("#6B2A4E"), U.GOLD_HI, 26))
	page.add_child(U.panel(Rect2(56, 248, W - 112, 112), U.PLUM_LO, Color(U.GOLD, 0.6), 18))
	room_code_lbl = U.label("Код появится здесь", Rect2(56, 248, W - 112, 112), 24, U.MUTED, HORIZONTAL_ALIGNMENT_CENTER, 900)
	page.add_child(room_code_lbl)
	page.add_child(U.label("— или войти по коду —", Rect2(36, 378, W - 72, 40), 22, U.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	code_edit = U.line_edit(Rect2(56, 432, W - 112, 72), "Введи 6 цифр", "", false, 28)
	code_edit.max_length = 6
	code_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(code_edit)
	page.add_child(U.button("Войти в комнату", Rect2(56, 524, W - 112, 84), func() -> void: join_room(code_edit.text), Color("#8E3B2E"), U.GOLD_HI, 26, U.GOLD_HI))


func _page_top() -> void:
	var card: = Rect2(16, 0, W - 32, maxf(300.0, page.size.y - 20.0))
	page.add_child(U.panel(card, U.PLUM, U.GOLD, 22))
	page.add_child(U.label("Топ игроков · рейтинг ELO", Rect2(36, 14, W - 72, 44), 27, U.GOLD_HI, HORIZONTAL_ALIGNMENT_CENTER, 900))
	var info: = U.label("Загрузка рейтинга…", Rect2(36, 64, W - 72, 40), 22, U.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	info.name = "TopInfo"
	page.add_child(info)
	var list: = Control.new()
	list.name = "TopList"
	list.position = Vector2(28, 112)
	list.size = Vector2(W - 56, card.size.y - 124.0)
	list.clip_contents = true
	list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(list)
	_load_top.call_deferred(list, info)


func _load_top(list: Control, info: Label) -> void:
	var rows: Array = []
	var r: Dictionary = {}
	if net != null and is_inside_tree():
		r = await net.leaderboard("pvp", 50)
	if not is_instance_valid(list):
		return
	if bool(r.get("ok", false)) and r.get("rows") is Array:
		rows = r.rows
		info.text = "Глобальный рейтинг · игроков: %d" % rows.size()
	else:
		info.text = "Офлайн: глобальный рейтинг недоступен"
		rows = [{"rank": 1, "nick": V10OnlineCfg.nick(), "avatar": V10OnlineCfg.avatar(), "value": V10OnlineCfg.elo(),
			"wins": V10OnlineCfg.wins(), "losses": V10OnlineCfg.losses()}]
	fill_top(list, rows)


func fill_top(list: Control, rows: Array) -> void:
	for c in list.get_children():
		c.queue_free()
	var me_id: = int(V10OnlineCfg.user().get("id", -999))
	var rh: = 76.0
	var n: = mini(rows.size(), int(list.size.y / rh))
	for i in n:
		var row: Dictionary = rows[i]
		var y: = float(i) * rh
		var mine: = int(row.get("user_id", -1)) == me_id
		var rk: = int(row.get("rank", i + 1))
		list.add_child(U.panel(Rect2(0, y, list.size.x, rh - 10.0), Color("#3A1838") if mine else U.PLUM_LO, U.GOLD_HI if mine else Color(U.GOLD, 0.35), 16))
		var medal: = [Color("#FFD34D"), Color("#D9DEE8"), Color("#E09A5A")]
		var rc: Color = medal[rk - 1] if rk >= 1 and rk <= 3 else U.MUTED
		list.add_child(U.label("%d" % rk, Rect2(8, y, 56, rh - 10.0), 26, rc, HORIZONTAL_ALIGNMENT_CENTER, 900))
		var av: = V10OnlineCfg.valid_avatar(String(row.get("avatar", "mc")), "mc")
		list.add_child(Common.avatar(av, Rect2(66, y + 5, 56, 56)))
		list.add_child(U.label(String(row.get("nick", "?")), Rect2(134, y, list.size.x - 360, rh - 10.0), 23, U.CREAM))
		list.add_child(U.label("%d / %d" % [int(row.get("wins", 0)), int(row.get("losses", 0))], Rect2(list.size.x - 226, y, 100, rh - 10.0), 20, U.MUTED, HORIZONTAL_ALIGNMENT_RIGHT))
		list.add_child(U.label("%d" % int(row.get("value", 1000)), Rect2(list.size.x - 116, y, 100, rh - 10.0), 26, U.GOLD_HI, HORIZONTAL_ALIGNMENT_RIGHT, 900))


# ── search / rooms ───────────────────────────────────────────────────────────────────────────────────────────────

func _ensure_conn() -> void:
	if net.mode == "":
		net.pvp_connect()


func start_matchmaking() -> void:
	if phase != "lobby":
		return
	_ensure_conn()
	phase = "search"
	_show_search("Ищем соперника…", "Твой рейтинг %d · подбор по ELO" % V10OnlineCfg.elo())
	net.matchmake_join()


func create_room() -> void:
	if phase != "lobby":
		return
	_ensure_conn()
	phase = "room_wait"
	if room_code_lbl:
		room_code_lbl.text = "Создаём комнату…"
	net.room_create()


func join_room(code: String) -> void:
	if phase != "lobby":
		return
	if not V10Online.valid_room_code(code):
		U.toast(self, "Код комнаты — 6 цифр", W, H * 0.5)
		return
	_ensure_conn()
	phase = "search"
	_show_search("Входим в комнату…", "Код %s" % code.strip_edges())
	net.room_join(code)


func _on_room_created(code: String) -> void:
	if room_code_lbl != null and is_instance_valid(room_code_lbl):
		room_code_lbl.text = "%s %s" % [code.substr(0, 3), code.substr(3, 3)]
		room_code_lbl.label_settings = room_code_lbl.label_settings.duplicate()
		room_code_lbl.label_settings.font_size = 56
		room_code_lbl.label_settings.font_color = U.GOLD_HI
	_show_search("Ждём друга…", "Код комнаты %s %s" % [code.substr(0, 3), code.substr(3, 3)])


func _show_search(title: String, sub: String) -> void:
	if search_root != null and is_instance_valid(search_root):
		search_root.queue_free()
	_search_t = 0.0
	search_root = Control.new()
	search_root.size = Vector2(W, H)
	search_root.z_index = 200
	search_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(search_root)
	var br: = V10Layout.bleed_rect(self)
	var dim: = ColorRect.new()
	dim.position = br.position
	dim.size = br.size
	dim.color = Color(0.05, 0.01, 0.08, 0.86)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	search_root.add_child(dim)
	var cy: = safe_t + (H - safe_t - safe_b) * 0.5
	var rad: = Radar.new()
	rad.size = Vector2(440, 440)
	rad.position = Vector2(W * 0.5 - 220, cy - 330)
	search_root.add_child(rad)
	search_root.add_child(Common.avatar(V10OnlineCfg.avatar(), Rect2(W * 0.5 - 60, cy - 170, 120, 120)))
	search_root.add_child(U.label(title, Rect2(40, cy + 130, W - 80, 50), 28, U.GOLD_HI, HORIZONTAL_ALIGNMENT_CENTER, 900))
	search_root.add_child(U.label(sub, Rect2(40, cy + 184, W - 80, 40), 22, U.CREAM, HORIZONTAL_ALIGNMENT_CENTER))
	search_time_lbl = U.label("0:00", Rect2(40, cy + 230, W - 80, 40), 24, U.GOLD, HORIZONTAL_ALIGNMENT_CENTER, 900)
	search_root.add_child(search_time_lbl)
	search_root.add_child(U.button("Отмена", Rect2(W * 0.5 - 150, minf(cy + 300, H - safe_b - 92), 300, 80), cancel_search, U.PLUM_HI, U.CREAM, 26))


func cancel_search() -> void:
	if net != null and net.mode != "":
		net.leave()
		net.pvp_close()
	if search_root != null and is_instance_valid(search_root):
		search_root.queue_free()
	search_root = null
	phase = "lobby"
	if room_code_lbl != null and is_instance_valid(room_code_lbl):
		select_tab(tab)


func _on_net_error(code: String, msg: String) -> void:
	var txt: = msg if msg != "" else code
	if code == "room_not_found":
		txt = "Комната не найдена"
	U.toast(self, txt, W, maxf(H * 0.12, safe_t + 24.0))
	if phase == "search" and code in ["room_not_found", "own_room"]:
		cancel_search()


func _on_disconnected() -> void:
	if phase == "match":
		U.toast(self, "Связь с сервером потеряна", W, maxf(H * 0.12, safe_t + 24.0), U.RED)
		_back_to_lobby()
	elif phase in ["search", "room_wait"]:
		cancel_search()


class Radar extends Control:
	var t: = 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(dt: float) -> void:
		t += dt
		queue_redraw()

	func _draw() -> void:
		var c: = size * 0.5
		var r: = minf(size.x, size.y) * 0.5
		draw_circle(c, r, Color(0.20, 0.08, 0.22, 0.55))
		for i in 4:
			draw_arc(c, r * (0.25 + 0.25 * i), 0.0, TAU, 96, Color(0.91, 0.77, 0.49, 0.55), 2.0, true)
		draw_line(c - Vector2(r, 0), c + Vector2(r, 0), Color(0.91, 0.77, 0.49, 0.3), 2.0)
		draw_line(c - Vector2(0, r), c + Vector2(0, r), Color(0.91, 0.77, 0.49, 0.3), 2.0)
		var a: = fmod(t * 2.2, TAU)
		for k in 24:
			var a0: = a - float(k) * 0.045
			var pts: = PackedVector2Array([c, c + Vector2.from_angle(a0) * r, c + Vector2.from_angle(a0 - 0.045) * r])
			draw_colored_polygon(pts, Color(1.0, 0.85, 0.45, 0.32 * (1.0 - float(k) / 24.0)))
		draw_line(c, c + Vector2.from_angle(a) * r, Color(1.0, 0.92, 0.6, 0.95), 3.0, true)
		var pulse: = fmod(t, 1.6) / 1.6
		draw_arc(c, r * pulse, 0.0, TAU, 96, Color(1.0, 0.85, 0.45, 0.6 * (1.0 - pulse)), 3.0, true)
		for b in 3:
			var ba: = float(b) * 2.1 + 0.6
			var bd: = r * (0.45 + 0.15 * b)
			var lit: = 1.0 - clampf(fposmod(a - ba, TAU) / 2.5, 0.0, 1.0)
			draw_circle(c + Vector2.from_angle(ba) * bd, 7.0, Color(1.0, 0.5, 0.6, 0.25 + 0.75 * lit))


# ── live match ───────────────────────────────────────────────────────────────────────────────────────────────────

func _on_match_found(d: Dictionary) -> void:
	if search_root != null and is_instance_valid(search_root):
		search_root.queue_free()
	search_root = null
	match_info = d.duplicate(true)
	opp = d.get("opponent", {}) if d.get("opponent") is Dictionary else {}
	duration = float(d.get("duration_s", 180))
	elapsed = 0.0
	score = 0
	charge = 0
	overflows = 0
	opp_score = 0
	sabotage_hits = 0
	phase = "match"
	lobby_root.visible = false
	_build_match()
	var cfg: Dictionary = d.get("board_cfg", {}) if d.get("board_cfg") is Dictionary else {}
	if cfg.is_empty():
		cfg = V10Online.board_cfg(int(d.get("seed", 1)))
	cfg["seed"] = int(d.get("seed", cfg.get("seed", 1)))
	_spawn_board(cfg)
	tiles_total = tiles_left()
	opp_left = tiles_total
	_refresh_match_hud()
	net.send_progress(tiles_total, tiles_total, 0, 0)
	Sfx.play("whoosh", 1.0, -4)


func _build_match() -> void:
	if match_root != null and is_instance_valid(match_root):
		match_root.queue_free()
	match_root = Control.new()
	match_root.size = Vector2(W, H)
	match_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(match_root)
	move_child(match_root, lobby_root.get_index() + 1)
	# ТЫ vs СОПЕРНИК
	var mtop: = 12.0 + safe_t
	var top_p: = U.panel(Rect2(12, mtop, W - 24, 188), U.PLUM, U.GOLD, 22)
	top_p.name = "MatchHeader"
	match_root.add_child(top_p)
	match_root.add_child(Common.avatar(V10OnlineCfg.avatar(), Rect2(26, mtop + 12, 88, 88)))
	var oav: = V10OnlineCfg.valid_avatar(String(opp.get("avatar", "rin")), "rin")
	match_root.add_child(Common.avatar(oav, Rect2(W - 114, mtop + 12, 88, 88), "pink"))
	match_root.add_child(U.label("ТЫ", Rect2(124, mtop + 14, 162, 34), 24, U.GOLD_HI, HORIZONTAL_ALIGNMENT_LEFT, 900))
	match_root.add_child(U.label("ELO %d" % V10OnlineCfg.elo(), Rect2(124, mtop + 50, 162, 30), 20, U.CREAM))
	var on: = String(opp.get("nick", "Соперник"))
	match_root.add_child(U.label(on, Rect2(W - 286, mtop + 14, 162, 34), 24, Color("#FFB3C7"), HORIZONTAL_ALIGNMENT_RIGHT, 900))
	var tag: = " · бот" if bool(opp.get("bot", false)) else ""
	match_root.add_child(U.label("ELO %d%s" % [int(opp.get("pvp_elo", 1000)), tag], Rect2(W - 286, mtop + 50, 162, 30), 20, U.CREAM, HORIZONTAL_ALIGNMENT_RIGHT))
	timer_lbl = U.label("3:00", Rect2(W * 0.5 - 60, mtop + 6, 120, 38), 28, U.GOLD_HI, HORIZONTAL_ALIGNMENT_CENTER, 900)
	match_root.add_child(timer_lbl)
	# 136×52 visual pill centered inside a 148×64 (>= 64px) mobile hit target
	surrender_btn = Control.new()
	surrender_btn.name = "SurrenderBtn"
	surrender_btn.position = Vector2(W * 0.5 - 74, mtop + 42)
	surrender_btn.size = Vector2(148, 64)
	surrender_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	surrender_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	surrender_btn.set_meta("no_haptic", true)
	var sur_pill: = U.panel(Rect2(6, 6, 136, 52), U.PLUM_LO, Color(U.GOLD, 0.55), 26, 2)
	sur_pill.name = "Pill"
	var sur_lbl: = U.label("Сдаться", Rect2(8, 0, 120, 52), 21, U.CREAM, HORIZONTAL_ALIGNMENT_CENTER, 900)
	sur_pill.add_child(sur_lbl)
	surrender_btn.add_child(sur_pill)
	surrender_btn.set_meta("label", sur_lbl)
	surrender_btn.gui_input.connect(func(e: InputEvent) -> void:
		var tap: bool = (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and e.pressed)
		if tap:
			surrender_btn.accept_event()
			var tw: = sur_pill.create_tween()
			sur_pill.pivot_offset = sur_pill.size * 0.5
			tw.tween_property(sur_pill, "scale", Vector2(0.95, 0.95), 0.06)
			tw.tween_property(sur_pill, "scale", Vector2.ONE, 0.10)
			U.haptic("tap")
			Sfx.play("tap", 1.0, -6)
			surrender())
	match_root.add_child(surrender_btn)
	my_bar = U.bar(Rect2(26, mtop + 112, W * 0.5 - 40, 28), 1.0, Color("#F2C14E"))
	opp_bar = U.bar(Rect2(W * 0.5 + 14, mtop + 112, W * 0.5 - 40, 28), 1.0, Color("#E0648C"))
	match_root.add_child(my_bar)
	match_root.add_child(opp_bar)
	my_lbl = U.label("", Rect2(26, mtop + 144, W * 0.5 - 40, 34), 20, U.CREAM)
	opp_lbl = U.label("", Rect2(W * 0.5 + 14, mtop + 144, W * 0.5 - 40, 34), 20, U.CREAM, HORIZONTAL_ALIGNMENT_RIGHT)
	match_root.add_child(my_lbl)
	match_root.add_child(opp_lbl)
	# tray
	slot_rects.clear()
	var sw: = 100.0
	var gap: = 12.0
	var tot: = sw * SLOTS_N + gap * (SLOTS_N - 1)
	var x0: = (W - tot) * 0.5
	var ty: = mtop + 202.0
	match_root.add_child(U.panel(Rect2(x0 - 14, ty - 8, tot + 28, sw * 1.12 + 16), Color(0.08, 0.05, 0.12, 0.9), U.GOLD, 16))
	for i in SLOTS_N:
		var r: = Rect2(x0 + i * (sw + gap), ty, sw, sw * 1.12)
		slot_rects.append(r)
		match_root.add_child(U.panel(r, Color(0.05, 0.03, 0.08, 0.92), Color(0.75, 0.62, 0.38, 0.55), 10))
	# dock
	var dh: = 176.0
	var dy: = H - dh - 12.0 - safe_b
	var by: = ty + sw * 1.12 + 22.0
	board_rect = Rect2(18, by, W - 36, maxf(240.0, dy - by - 12.0))
	match_root.add_child(U.panel(board_rect.grow(5.0), Color(0.06, 0.14, 0.11, 0.85), Color("#D4AC5E"), 18))
	var dock_p: = U.panel(Rect2(12, dy, W - 24, dh), U.PLUM, U.GOLD, 22)
	dock_p.name = "MatchDock"
	match_root.add_child(dock_p)
	charge_lbl = U.label("", Rect2(28, dy + 10, 320, 32), 21, U.GOLD_HI, HORIZONTAL_ALIGNMENT_LEFT, 900)
	match_root.add_child(charge_lbl)
	charge_bar = U.bar(Rect2(28, dy + 46, 316, 22), 0.0, Color("#8FD8FF"))
	match_root.add_child(charge_bar)
	sab_btns["ice"] = U.button("Лёд", Rect2(28, dy + 82, 150, 72), func() -> void: use_sabotage("ice"), Color("#1F5E8C"), Color("#E6F7FF"), 26, Color("#8FD8FF"))
	sab_btns["fog"] = U.button("Туман", Rect2(194, dy + 82, 150, 72), func() -> void: use_sabotage("fog"), Color("#5B2E86"), Color("#F1E4FF"), 26, Color("#C9A2FF"))
	match_root.add_child(sab_btns.ice)
	match_root.add_child(sab_btns.fog)
	var ex: = 366.0
	var ew: = (W - 28.0 - ex - 12.0) * 0.5
	var i2: = 0
	for id in V10Online.EMOTES:
		var eid: String = id
		var r2: = Rect2(ex + float(i2 % 2) * (ew + 12.0), dy + 14 + float(i2 / 2) * 80.0, ew, 68)
		match_root.add_child(U.button(EMOTE_TEXT[eid], r2, func() -> void: send_emote(eid), U.PLUM_LO, U.CREAM, 22, Color(U.GOLD, 0.6)))
		i2 += 1


func _spawn_board(cfg: Dictionary) -> void:
	if board != null and is_instance_valid(board):
		board.queue_free()
	seed(int(cfg.get("seed", 1)))
	board = TrayBoard.new()
	board.slots = SLOTS_N
	match_root.add_child(board)
	board.setup(cfg)
	board.fit_into(board_rect)
	board.slot_pos.clear()
	for r in slot_rects:
		board.slot_pos.append(get_global_transform_with_canvas() * (r as Rect2).get_center())
	board.slot_size = (slot_rects[0] as Rect2).size.x * 0.88
	board.reveal_free()
	board.input_on = true
	board.matched.connect(_on_pair)
	board.failed.connect(_on_overflow)
	board.cleared.connect(_on_cleared)


func tiles_left() -> int:
	if board == null or not is_instance_valid(board):
		return 0
	var n: = 0
	for t in board.tiles:
		if is_instance_valid(t) and t.alive:
			n += 1
	return n


func _on_pair(mid: Vector2, combo: int, gold: bool, _shard: String) -> void:
	if phase != "match":
		return
	V10AdventureVfx.tick_board_fog(board)
	var gain: = 100 * maxi(1, combo) + (50 if gold else 0)
	score += gain
	charge = mini(CHARGE_PAIRS, charge + 1)
	var p: = V10Layout.local_of(fx_layer, mid)
	V10AdventureVfx.spawn_float_text(fx_layer, p, "+%d" % gain, U.GOLD_HI, 26, 0.5)
	_refresh_match_hud()
	net.send_progress(tiles_left(), tiles_total, score, combo)


func _on_overflow() -> void:
	if phase != "match":
		return
	overflows += 1
	if overflows == 1:
		board.return_tray(3)
		score = maxi(0, score - 300)
		V10AdventureVfx.spawn_float_text(fx_layer, Vector2(W * 0.5, board_rect.position.y + 60), "Лоток сброшен · −300", U.RED, 26, 0.9)
		board.input_on = true
		_refresh_match_hud()
		return
	board.input_on = false
	net.send_finish(false, tiles_left(), score)


func _on_cleared() -> void:
	if phase != "match":
		return
	net.send_progress(0, tiles_total, score, board.combo)
	net.send_finish(true, 0, score)


func _on_opp_progress(d: Dictionary) -> void:
	if phase != "match":
		return
	opp_left = int(d.get("tiles_left", opp_left))
	opp_score = int(d.get("score", opp_score))
	var c: = int(d.get("combo", 0))
	if c >= 3:
		V10AdventureVfx.spawn_float_text(fx_layer, Vector2(W - 170, 210), "Комбо x%d" % c, Color("#FFB3C7"), 24, 0.6)
	_refresh_match_hud()


func _refresh_match_hud() -> void:
	if my_bar == null or not is_instance_valid(my_bar):
		return
	var tl: = tiles_left()
	var tot: = float(maxi(1, tiles_total))
	U.set_bar(my_bar, 1.0 - float(tl) / tot)
	U.set_bar(opp_bar, 1.0 - float(opp_left) / tot)
	my_lbl.text = "Осталось %d · %d очк." % [tl, score]
	opp_lbl.text = "Осталось %d · %d очк." % [opp_left, opp_score]
	charge_lbl.text = "Саботаж готов!" if charge >= CHARGE_PAIRS else "Саботаж: %d/%d пары" % [charge, CHARGE_PAIRS]
	U.set_bar(charge_bar, float(charge) / float(CHARGE_PAIRS))
	for k in sab_btns:
		var b: Panel = sab_btns[k]
		b.set_meta("disabled", charge < CHARGE_PAIRS)
		b.modulate = Color.WHITE if charge >= CHARGE_PAIRS else Color(1, 1, 1, 0.55)


func use_sabotage(kind: String) -> bool:
	if phase != "match" or charge < CHARGE_PAIRS:
		return false
	charge = 0
	net.send_sabotage(kind)
	var col: = Color("#8FD8FF") if kind == "ice" else Color("#C9A2FF")
	V10AdventureVfx.spawn_float_text(fx_layer, Vector2(W - 200, 230), ("Лёд" if kind == "ice" else "Туман") + " → сопернику!", col, 26, 0.8)
	_refresh_match_hud()
	return true


func apply_sabotage(kind: String) -> void:
	if phase != "match":
		return
	sabotage_hits += 1
	var ice: = kind == "ice"
	V10AdventureVfx.apply_board_debuff(board, "freeze" if ice else "fog", 3 if ice else 4)
	flash.color = Color(0.45, 0.85, 1.0, 0.0) if ice else Color(0.62, 0.35, 0.95, 0.0)
	var tw: = flash.create_tween()
	tw.tween_property(flash, "color:a", 0.45, 0.08)
	tw.tween_property(flash, "color:a", 0.0, 0.5)
	V10AdventureVfx.spawn_float_text(fx_layer, board_rect.get_center(), "ЛЁД!" if ice else "ТУМАН!", Color("#BFEFFF") if ice else Color("#E2C8FF"), 28, 0.9)
	Sfx.play("deny", 1.0, -4)


func send_emote(id: String) -> void:
	if phase != "match":
		return
	net.send_emote(id)
	var my_y: = (my_bar.position.y + my_bar.size.y + 10.0) if (my_bar != null and is_instance_valid(my_bar)) else (162.0 + safe_t)
	_bubble(Vector2(26, my_y), EMOTE_TEXT.get(id, "!"), false)


func _on_emote(id: String) -> void:
	emotes_seen += 1
	if phase == "match":
		var opp_y: = (opp_bar.position.y + opp_bar.size.y + 10.0) if (opp_bar != null and is_instance_valid(opp_bar)) else (162.0 + safe_t)
		var opp_x: = (opp_bar.position.x + opp_bar.size.x - 200.0) if (opp_bar != null and is_instance_valid(opp_bar)) else (W - 226.0)
		_bubble(Vector2(opp_x, opp_y), EMOTE_TEXT.get(id, "!"), true)


func _bubble(pos: Vector2, txt: String, theirs: bool) -> void:
	var p: = U.panel(Rect2(pos, Vector2(200, 56)), Color("#FFF4E0"), Color("#E0648C") if theirs else U.GOLD, 24, 3)
	p.name = "EmoteBubble"
	p.z_index = 240
	var l: = U.label(txt, Rect2(8, 0, 184, 56), 24, Color("#3A1838"), HORIZONTAL_ALIGNMENT_CENTER, 900)
	l.label_settings = l.label_settings.duplicate()
	l.label_settings.outline_size = 0
	p.add_child(l)
	fx_layer.add_child(p)
	p.pivot_offset = Vector2(100, 28)
	p.scale = Vector2(0.4, 0.4)
	var tw: = p.create_tween()
	tw.tween_property(p, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.6)
	tw.tween_property(p, "modulate:a", 0.0, 0.3)
	tw.tween_callback(p.queue_free)


func surrender() -> void:
	if phase != "match":
		return
	if board:
		board.input_on = false
	net.send("match_finish", {"cleared": false, "tiles_left": tiles_left(), "score": score, "reason": "surrender"})


func start_local_match() -> void:
	net.pvp_close()
	net.start_local()
	phase = "lobby"
	net.room_join("424242")


func _process(dt: float) -> void:
	if phase in ["search", "room_wait"] and search_time_lbl != null and is_instance_valid(search_time_lbl):
		_search_t += dt
		search_time_lbl.text = "%d:%02d" % [int(_search_t) / 60, int(_search_t) % 60]
	elif phase == "match" and timer_lbl != null and is_instance_valid(timer_lbl):
		elapsed += dt
		var left: = maxi(0, int(ceil(duration - elapsed)))
		timer_lbl.text = "%d:%02d" % [left / 60, left % 60]


# ── result ───────────────────────────────────────────────────────────────────────────────────────────────────────

func show_result(d: Dictionary) -> void:
	last_result = d.duplicate(true)
	phase = "result"
	if board != null and is_instance_valid(board):
		board.input_on = false
	if result_root != null and is_instance_valid(result_root):
		result_root.queue_free()
	result_root = Control.new()
	result_root.size = Vector2(W, H)
	result_root.z_index = 300
	result_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(result_root)
	var br: = V10Layout.bleed_rect(self)
	var dim: = ColorRect.new()
	dim.position = br.position
	dim.size = br.size
	dim.color = Color(0.04, 0.01, 0.07, 0.78)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result_root.add_child(dim)
	var won: = bool(d.get("you_won", false))
	var cy: = safe_t + (H - safe_t - safe_b) * 0.5
	var pr: = Rect2(48, cy - 300, W - 96, 600)
	result_root.add_child(U.panel(pr, U.PLUM, U.GOLD_HI if won else Color("#B9879B"), 28, 3))
	var t: = U.label("ПОБЕДА!" if won else "ПОРАЖЕНИЕ", Rect2(pr.position.x, pr.position.y + 26, pr.size.x, 90), 28, U.GOLD_HI if won else Color("#FFB3C7"), HORIZONTAL_ALIGNMENT_CENTER, 900)
	t.label_settings = t.label_settings.duplicate()
	t.label_settings.font_size = 64
	result_root.add_child(t)
	var reasons: = {"cleared": "Доска разобрана первой", "overflow": "Лоток переполнен", "timeout": "Время вышло", "forfeit": "Сдача / выход"}
	var rs: String = reasons.get(String(d.get("reason", "")), "Матч завершён")
	result_root.add_child(U.label(rs, Rect2(pr.position.x, pr.position.y + 124, pr.size.x, 40), 24, U.CREAM, HORIZONTAL_ALIGNMENT_CENTER))
	result_root.add_child(Common.avatar(V10OnlineCfg.avatar(), Rect2(W * 0.5 - 70, pr.position.y + 176, 140, 140)))
	var dl: = int(d.get("elo_delta", 0))
	var sign_s: = "+" if dl >= 0 else "−"
	var elo_s: = "ELO %d → %d  (%s%d)" % [int(d.get("elo_before", 1000)), int(d.get("elo_after", 1000)), sign_s, absi(dl)]
	result_root.add_child(U.label(elo_s, Rect2(pr.position.x, pr.position.y + 334, pr.size.x, 46), 28, U.GREEN if dl >= 0 else U.RED, HORIZONTAL_ALIGNMENT_CENTER, 900))
	result_root.add_child(U.label("Ты %d · Соперник %d" % [int(d.get("your_score", score)), int(d.get("opp_score", opp_score))], Rect2(pr.position.x, pr.position.y + 386, pr.size.x, 40), 22, U.CREAM, HORIZONTAL_ALIGNMENT_CENTER))
	var bw: = (pr.size.x - 72.0) * 0.5
	result_root.add_child(U.button("Ещё бой", Rect2(pr.position.x + 24, pr.end.y - 120, bw, 88), rematch, Color("#8E3B2E"), U.GOLD_HI, 26, U.GOLD_HI))
	result_root.add_child(U.button("В лобби", Rect2(pr.position.x + 48 + bw, pr.end.y - 120, bw, 88), _back_to_lobby, U.PLUM_HI, U.CREAM, 26))
	Sfx.play("win" if won else "deny", 1.0, -3)


func _back_to_lobby() -> void:
	if result_root != null and is_instance_valid(result_root):
		result_root.queue_free()
	result_root = null
	if match_root != null and is_instance_valid(match_root):
		match_root.queue_free()
	match_root = null
	board = null
	if net != null:
		net.pvp_close()
	phase = "lobby"
	lobby_root.visible = true
	_refresh_profile()
	select_tab(tab)


func rematch() -> void:
	_back_to_lobby()
	start_matchmaking()
