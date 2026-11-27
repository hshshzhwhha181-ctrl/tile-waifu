class_name V10Nav
extends RefCounted

# V10Nav — the 0.10 navigation shell glue (docs/INTEGRATION_0.10.md §1, W1; UX_RULES §3.1–§3.6, HUD_V2 §8.2).
# Everything main.gd, home.gd and the «Столы» hub share, so the hot files only call one line each:
#
#   V10Nav.band(size)                  the v2 navbar band (night.900 + one gold hairline)
#   V10Nav.tab_open(id) / tab_lock_text(id) / tab_dot(id) / dot()
#                                      staged opening of the tabs (UX §3.5): Желания and Героини after L3,
#                                      Лавка after L8 (С-2: no «₽» before L8); one dot = «есть что забрать»
#   V10Nav.path_info() -> {lvl, code, loc}    the current Path table («Играть · 1-4», «Путь · Чайный сад»)
#   V10Nav.play_path(main)             ★ «Играть · N» → the match (no partner picker while one heroine is open, P1-14)
#   V10Nav.today_lit() / today_open()  the «Сегодня» lantern (UX §3.5: after L6) and whether it has something to do
#   V10Nav.today_sheet(main)           the Afisha bottom sheet: Партия дня · Задания дня · Режим дня ×2 · Неделя ·
#                                      Событие (+ «Забрать всё»), one sheet, never over another sheet (П-6)
#   V10Nav.install()                   V10Afisha providers (week = турнир недели, extra rows = tasks, event)

const SALON_AT: = 3  # after L2 (UX §3.5)
const SUMMON_AT: = 4  # G.S.unlocked: open after the 3rd Path win (G.summon_open)
const PHONE_AT: = 6  # Телефон after L5 (UX §3.5)
const TODAY_AT: = 7  # after L6
const SHOP_AT: = 9  # after L8, the boss of chapter 1 (UX §3.5, С-2)
const WEEK_AT: = 17  # Турнир недели after L16 (UX §3.5)
const T_LOCK: = "Откроется после партии %d"


static func band(sz: Vector2) -> Control:
	var b: = _Band.new()
	b.size = sz
	return b


static func tab_open(id: String) -> bool:
	var u: = int(G.S.get("unlocked", 1))
	match id:
		"summon", "collection":
			return u >= SUMMON_AT
		"shop":
			return u >= SHOP_AT
	return true


static func tab_lock_text(id: String) -> String:
	match id:
		"summon", "collection":
			return T_LOCK % (SUMMON_AT - 1)
		"shop":
			return T_LOCK % (SHOP_AT - 1)
	return ""


# UX §3.6: a dot only for «есть что забрать»; the shop's only dot is «Подарок дня»
static func tab_dot(id: String) -> bool:
	match id:
		"summon":
			return (V10Registry.wired("gacha") and String(G.S.get("first_pick", "")) == "") or bool(G.S.get("free10", false))
		"shop":
			if G.econ != null:
				var gs = G.S.get("v10_shop", {})
				var gd: int = int(gs.get("gift", {}).get("day", -1)) if gs is Dictionary and gs.get("gift") is Dictionary else -1
				return gd != (G.econ as V10Econ).clock.today()
			return str(G.S.get("gift_day", "")) != G.today()
	return false


static func dot() -> Control:
	var d: = _Dot.new()
	d.size = Vector2(12, 12)
	return d


static func salon_open() -> bool:
	return int(G.S.get("unlocked", 1)) >= SALON_AT


static func salon_lit() -> bool:
	return salon_open() and V10Salon.can_restore_any()


static func streak_shown() -> bool:
	var meta = G.S.get("v10_meta", {})
	var days: = int(meta.get("days_seen", 0)) if meta is Dictionary else 0
	return days >= 2 or int(V10Streak.st().get("n", 0)) > 0


static func streak_lit() -> bool:
	if not streak_shown():
		return false
	var v: = V10Streak.view()
	return str(v.get("state", "")) in ["cold", "today"] or not (v.get("repair", {}) as Dictionary).is_empty()


static func phone_open() -> bool:
	return int(G.S.get("unlocked", 1)) >= PHONE_AT


static func path_info() -> Dictionary:
	var cur: = V10PathState.current()
	var nd: = V10PathState.node(cur)
	var loc: = G.loc_name(int(nd.world))
	return {"lvl": cur, "code": str(nd.code), "loc": loc, "total": V10PathState.released_total()}


static func play_path(main) -> void:
	var cur: = V10PathState.current()
	var is_auto: = false
	for ua in OS.get_cmdline_user_args():
		if ua.begins_with("--shots=") or ua.begins_with("--smoke") or ua.begins_with("--selftest") or ua.begins_with("--tut") or ua.begins_with("--contract"):
			is_auto = true
			break
	if not is_auto:
		var tea_cost: = V10Stamina.cost_for_level(cur, "path")
		if tea_cost > 0:
			if not V10Stamina.can_spend(tea_cost):
				V10Stamina.open_sheet(main)
				return
			V10Stamina.spend(tea_cost, "path")
	var hero: String = G.S.level_partner if G.hero_unlocked(G.S.level_partner) else "mc"
	main.go("play", {"level": cur, "partner": hero, "v10_cfg": V10PathState.play_cfg(cur)})


# ── «Сегодня» (Afisha) ─────────────────────────────────────────────────────────────────────────────────────────

static func today_lit() -> bool:
	return int(G.S.get("unlocked", 1)) >= TODAY_AT


static func today_open() -> bool:
	if G.tasks_ready() > 0 or G.login_ready():
		return true
	for r in V10Afisha.rows():
		if bool(r.open) and not bool(r.done):
			return true
	return false


static func install() -> void:
	V10Afisha.set_provider("week", func() -> Dictionary:
		var u: = int(G.S.get("unlocked", 1))
		if u < WEEK_AT:
			return {"open": false, "title": "Неделя", "lock": T_LOCK % (WEEK_AT - 1)}
		return {"open": true, "title": "Неделя", "sub": "Турнир недели · твоя группа", "done": false})
	V10Afisha.set_provider("daily_done", func() -> bool: return G.daily_done_today())


# rows of the sheet: the Afisha rows (closed ones folded to at most one, В-8) + Задания дня + Событие
static func today_rows() -> Array:
	var out: = []
	var t: = G.tasks()
	var got: = 0
	for i in G.TASKS.size():
		if bool(t.claimed[i]):
			got += 1
	var ready: = G.tasks_ready()
	var trow: = {"id": "tasks", "title": "Задания дня", "open": true, "icon": "tasks", "done": got >= G.TASKS.size(),
		"sub": ("можно забрать: %d" % ready) if ready > 0 else "выполнено %d из %d" % [got, G.TASKS.size()]}
	var closed: = []
	for r in V10Afisha.rows():
		if r.id == "salon":
			continue  # the salon is a lantern of its own (W2)
		if bool(r.open):
			out.append(r)
		else:
			closed.append(r)
		if r.id == "daily":
			out.append(trow)
	if V7Event.is_open():
		var def: = V7EventData.cur_def()
		out.append({"id": "event", "title": "Событие", "sub": str(def.get("name", "")), "open": true, "done": false, "icon": "event"})
	var meta_d: = int(G.S.get("v10_meta", {}).get("days_seen", 0)) if G.S.get("v10_meta") is Dictionary else 0
	if V10Nav.tab_open("shop") and (int(G.S.get("unlocked", 1)) >= 21 or meta_d >= 4) and G.econ != null:
		var ps: V10Pass = (G.econ as V10Econ).pass_
		var pcl: int = ps.claimable().size()
		out.append({"id": "pass", "title": "Сезон", "open": true, "done": pcl == 0 and ps.tier() >= V10Catalog.PASS_TIERS,
			"icon": "star", "sub": ("можно забрать: %d" % pcl) if pcl > 0 else "Ступень %d из %d" % [ps.tier(), V10Catalog.PASS_TIERS]})
	if not closed.is_empty():
		out.append(closed[0])
	return out


static func claim_all(main) -> int:
	var n: = 0
	var t: = G.tasks()
	for i in G.TASKS.size():
		var td: Dictionary = G.TASKS[i]
		if not bool(t.claimed[i]) and int(t[td.key]) >= int(td.goal):
			t.claimed[i] = true
			V10Money.grant({"gems": int(td.gems)}, "daily")
			G.add_pass_xp(100)
			n += 1
	# the 0.9 visit reward joins «Забрать всё» (UX §3.2: Визиты are gone; the morning tray takes it in W2)
	if G.login_ready():
		var r: Dictionary = G.LOGIN_REWARDS[int(G.S.login.n) % 7]
		G.S.login.n = int(G.S.login.n) + 1
		G.S.login.last = G.today()
		V10Money.grant(r, "daily")
		n += 1
	if n > 0:
		G.save()
		main.refresh_currency(true)
	return n


static func today_sheet(main) -> Control:
	var sh: = V10BottomSheet.open(main, "Сегодня")
	var rows: = today_rows()
	var y: = 0.0
	var first_play: = ""
	for r in rows:
		var p: = V10Plate.make("M", 656, str(r.title), str(r.get("sub", "")), "✓" if bool(r.get("done", false)) else "")
		p.disabled = not bool(r.open)
		p.interactive = true
		p.name = "Row_" + str(r.id)
		var rr: Dictionary = r
		p.pressed.connect(func() -> void:
			if not bool(rr.open):
				main.toast(str(rr.get("lock", "")), "lock")
				return
			sh.close()
			_open_row(main, rr))
		sh.add_body(p, y)
		y += 88.0
		if first_play == "" and bool(r.open) and not bool(r.get("done", false)) and r.id in ["daily", "mode", "week", "event"]:
			first_play = str(r.id)
	var can_claim: = G.tasks_ready() > 0 or G.login_ready()
	if can_claim:
		var cb: = V10Button.make("secondary", "Забрать всё", Vector2(328, 80))
		cb.name = "ClaimAll"
		cb.set_meta("ux_role", "secondary")
		cb.pressed.connect(func() -> void:
			if claim_all(main) > 0:
				main.fly_gems(cb.get_global_rect().get_center(), 5)
				Sfx.play("win", 1.3, -6)
			sh.close())
		sh.add_body(cb, y + 8.0, true)
		y += 96.0
	if first_play != "":
		var row: Dictionary = {}
		for r in rows:
			if r.id == first_play:
				row = r
		var pb: = V10Button.make("play", "Играть", Vector2(440, 104))
		pb.overline = str(row.get("title", ""))
		pb.name = "PlayRow"
		pb.set_meta("ux_role", "primary")
		pb.pressed.connect(func() -> void:
			sh.close()
			_open_row(main, row))
		sh.add_body(pb, y + 40.0, true)
		y += 152.0
	sh.finish(y)
	return sh


static func _open_row(main, r: Dictionary) -> void:
	match str(r.id):
		"daily":
			Daily.calendar(main)
		"tasks":
			Daily.tasks(main, null)
		"mode":
			main.go("tables", {"open": str(r.get("mode", ""))})
		"week":
			main.go("v7tourney", {"tab": "week"})
		"event":
			main.go("v7event")
		"pass":
			main.go("shop", {"v10": "pass"})


# Настройки → «Уведомления» (meta Ф1; UX §3.2): one row under «Фишки и словарь»; the panel opens in a sheet after
# the settings window closes (never a window over a window, П-6)
const SETTINGS_TAIL_Y: = 978.0

static func settings_notify(main, p: Control) -> void:
	var extra: = 84.0
	var y0: = SETTINGS_TAIL_Y + V10Clarity.SETTINGS_EXTRA
	for c in p.get_children():
		if c is Control and (c as Control).position.y >= y0 - 2.0 and c.name != "PanelArt":
			(c as Control).position.y += extra
	p.size.y += extra
	var root = p.get_meta("root") if p.has_meta("root") else null
	if root is Control and p.position.y + p.size.y > (root as Control).size.y - 10.0:
		p.position.y = maxf(20.0, (root as Control).size.y - 10.0 - p.size.y)
	var l: = UI.label("Уведомления", 26, UI.INK, Color.WHITE, 3, "body", 900)
	l.position = Vector2(34, y0 + 2)
	p.add_child(l)
	var d: = UI.label("Письма героинь: когда и о чём", 17, Color("8a5a7a"))
	d.position = Vector2(34, y0 + 42)
	p.add_child(d)
	var b: = JButton.make("Открыть", "lav", Rect2(470, y0 + 8, 158, 64), null, 22)
	b.name = "Notify"
	b.pressed.connect(func() -> void:
		Common.close_popup(p)
		var sh: = V10BottomSheet.open(main, "Уведомления")
		var np: = V10NotifyPanel.make(656.0)
		sh.add_body(np, 0.0)
		sh.finish(np.preferred_height()))
	p.add_child(b)


# Настройки → «Мой день рождения» (rituals Р7, 152-ФЗ): set with explicit consent or delete in one tap
static func settings_bday(main, p: Control) -> void:
	var extra: = 84.0
	var y0: = SETTINGS_TAIL_Y + V10Clarity.SETTINGS_EXTRA + 84.0
	for c in p.get_children():
		if c is Control and (c as Control).position.y >= y0 - 2.0 and c.name != "PanelArt":
			(c as Control).position.y += extra
	p.size.y += extra
	var root = p.get_meta("root") if p.has_meta("root") else null
	if root is Control and p.position.y + p.size.y > (root as Control).size.y - 10.0:
		p.position.y = maxf(20.0, (root as Control).size.y - 10.0 - p.size.y)
	var l: = UI.label("Мой день рождения", 26, UI.INK, Color.WHITE, 3, "body", 900)
	l.position = Vector2(34, y0 + 2)
	p.add_child(l)
	var d: = UI.label(V10PlayerBday.settings_text(), 17, Color("8a5a7a"))
	d.position = Vector2(34, y0 + 42)
	p.add_child(d)
	var has_bday: = V10PlayerBday.has_date()
	var b: = JButton.make("Удалить" if has_bday else "Указать", "glass" if has_bday else "lav", Rect2(470, y0 + 8, 158, 64), null, 22)
	b.name = "PlayerBday"
	b.pressed.connect(func() -> void:
		if V10PlayerBday.has_date():
			V10PlayerBday.delete()
			G.save()
			d.text = V10PlayerBday.settings_text()
			b.lbl.text = "Указать"
			b.set_pal("lav")
			return
		Common.close_popup(p)
		V10PlayerBdayScreen.open(main.overlay, "consent"))
	p.add_child(b)


# Настройки → «Аккаунт» (auth W4)
static func settings_account(main, p: Control) -> void:
	var extra: = 84.0
	var y0: = SETTINGS_TAIL_Y + V10Clarity.SETTINGS_EXTRA + 168.0
	for c in p.get_children():
		if c is Control and (c as Control).position.y >= y0 - 2.0 and c.name != "PanelArt":
			(c as Control).position.y += extra
	p.size.y += extra
	var root = p.get_meta("root") if p.has_meta("root") else null
	if root is Control and p.position.y + p.size.y > (root as Control).size.y - 10.0:
		p.position.y = maxf(20.0, (root as Control).size.y - 10.0 - p.size.y)
	var l: = UI.label("Аккаунт", 26, UI.INK, Color.WHITE, 3, "body", 900)
	l.position = Vector2(34, y0 + 2)
	p.add_child(l)
	var d: = UI.label("Вход, привязка и перенос профиля", 17, Color("8a5a7a"))
	d.position = Vector2(34, y0 + 42)
	p.add_child(d)
	var b: = JButton.make("Открыть", "glass", Rect2(470, y0 + 8, 158, 64), null, 22)
	b.name = "AccountBtn"
	b.pressed.connect(func() -> void:
		Common.close_popup(p)
		if main.SCREENS.has("v10account"):
			main.go("v10account", {"from": main.screen_id})
		else:
			V10AuthFlow.open_account(main))
	p.add_child(b)


# Настройки → «Как играть» (tutorial/help W4)
static func settings_help(main, p: Control) -> void:
	var extra: = 84.0
	var y0: = SETTINGS_TAIL_Y + V10Clarity.SETTINGS_EXTRA + 252.0
	for c in p.get_children():
		if c is Control and (c as Control).position.y >= y0 - 2.0 and c.name != "PanelArt":
			(c as Control).position.y += extra
	p.size.y += extra
	var root = p.get_meta("root") if p.has_meta("root") else null
	if root is Control and p.position.y + p.size.y > (root as Control).size.y - 10.0:
		p.position.y = maxf(20.0, (root as Control).size.y - 10.0 - p.size.y)
	var l: = UI.label("Как играть", 26, UI.INK, Color.WHITE, 3, "body", 900)
	l.position = Vector2(34, y0 + 2)
	p.add_child(l)
	var d: = UI.label("Правила стола, подсказки и режимы", 17, Color("8a5a7a"))
	d.position = Vector2(34, y0 + 42)
	p.add_child(d)
	var b: = JButton.make("Открыть", "glass", Rect2(470, y0 + 8, 158, 64), null, 22)
	b.name = "HowToBtn"
	b.pressed.connect(func() -> void:
		Common.close_popup(p)
		V10Help.open_how_to(main))
	p.add_child(b)


# Настройки → «О игре · шрифты и лицензии» (fonts D2): lists all OFL families + tap for full OFL text
static func settings_fonts(main, p: Control) -> void:
	var extra: = 84.0
	var y0: = SETTINGS_TAIL_Y + V10Clarity.SETTINGS_EXTRA + 336.0
	for c in p.get_children():
		if c is Control and (c as Control).position.y >= y0 - 2.0 and c.name != "PanelArt":
			(c as Control).position.y += extra
	p.size.y += extra
	var root = p.get_meta("root") if p.has_meta("root") else null
	if root is Control and p.position.y + p.size.y > (root as Control).size.y - 10.0:
		p.position.y = maxf(20.0, (root as Control).size.y - 10.0 - p.size.y)
	var l: = UI.label("Шрифты и лицензии", 26, UI.INK, Color.WHITE, 3, "body", 900)
	l.position = Vector2(34, y0 + 2)
	p.add_child(l)
	var d: = UI.label("Открытые шрифты OFL в игре", 17, Color("8a5a7a"))
	d.position = Vector2(34, y0 + 42)
	p.add_child(d)
	var b: = JButton.make("Открыть", "glass", Rect2(470, y0 + 8, 158, 64), null, 22)
	b.name = "FontsLic"
	b.pressed.connect(func() -> void:
		Common.close_popup(p)
		_open_fonts_sheet(main))
	p.add_child(b)
	if root is Control and p.size.y > (root as Control).size.y - 96.0:
		var full_h: = p.size.y
		var max_h: = (root as Control).size.y - 96.0
		var sc_body: = ScrollContainer.new()
		sc_body.name = "SettingsScroll"
		sc_body.position = Vector2(0, 44)
		sc_body.size = Vector2(p.size.x, max_h - 58.0)
		sc_body.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		sc_body.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
		var holder: = Control.new()
		holder.custom_minimum_size = Vector2(p.size.x, full_h - 44.0)
		holder.mouse_filter = Control.MOUSE_FILTER_PASS
		sc_body.add_child(holder)
		var move_list: = []
		for ch in p.get_children():
			if ch is Control and (ch as Control).position.y >= 45.0 and ch.name != "PanelArt":
				move_list.append(ch)
		p.add_child(sc_body)
		for ch in move_list:
			var ctrl: Control = ch
			ctrl.reparent(holder, false)
			ctrl.position.y -= 44.0
		p.size.y = max_h
		p.pivot_offset = p.size * 0.5
		p.position.y = maxf(54.0, ((root as Control).size.y - max_h) * 0.5 + 12.0)


static func _open_fonts_sheet(main) -> void:
	var sh: = V10BottomSheet.open(main, "Шрифты и лицензии")
	var sc: = ScrollContainer.new()
	var bw: = 656.0
	var bh: = 680.0
	sc.size = Vector2(bw, bh)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var vb: = VBoxContainer.new()
	vb.custom_minimum_size = Vector2(bw, 0)
	vb.add_theme_constant_override("separation", 10)
	sc.add_child(vb)
	for row in V10Fonts.credits():
		var fid: = str(row.get("id", ""))
		var fam: = str(row.get("family", ""))
		var copy_t: = str(row.get("copyright", ""))
		var sub_t: = copy_t if copy_t.length() <= 68 else copy_t.substr(0, 65) + "…"
		var pl: = V10Plate.make("M", int(bw - 8.0), fam, sub_t, "›")
		pl.interactive = true
		pl.set_meta("ux_role", "option")
		pl.pressed.connect(func() -> void:
			sh.close()
			var lsh: = V10BottomSheet.open(main, fam)
			var lsc: = ScrollContainer.new()
			lsc.size = Vector2(bw, bh)
			lsc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			var lbl: = V10Type.label(V10Fonts.licence_text(fid), "body", 18, V10DS.PAPER_300)
			lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			lbl.custom_minimum_size = Vector2(bw - 24.0, 0)
			lsc.add_child(lbl)
			lsh.add_body(lsc, 0.0)
			lsh.finish(bh + 16.0))
		vb.add_child(pl)
	sh.add_body(sc, 0.0)
	sh.finish(bh + 16.0)


class _Band:
	extends Control

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP  # the band eats taps between the tabs

	func _draw() -> void:
		# AAA lacquer dock: deep burgundy-night vertical gradient + double gold filigree border (100% opaque)
		var top_col: = Color(0.14, 0.08, 0.19, 1.0)
		var bot_col: = Color(0.06, 0.03, 0.10, 1.0)
		draw_polygon(
			PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), Vector2(size.x, size.y), Vector2(0, size.y)]),
			PackedColorArray([top_col, top_col, bot_col, bot_col])
		)
		# subtle warm sheen near the top edge
		var sheen0: = Color(0.95, 0.78, 0.45, 0.12)
		var sheen1: = Color(0.95, 0.78, 0.45, 0.0)
		draw_polygon(
			PackedVector2Array([Vector2(0, 2), Vector2(size.x, 2), Vector2(size.x, 22), Vector2(0, 22)]),
			PackedColorArray([sheen0, sheen0, sheen1, sheen1])
		)
		# bright primary gold rim + fine inner gold hairline
		draw_line(Vector2(0, 1.5), Vector2(size.x, 1.5), Color(0.95, 0.80, 0.48, 0.88), 2.5, true)
		V10Plate.hairline(self, 18.0, size.x - 18.0, 5.5, Color(V10DS.GOLD_500, 0.35))


class _Dot:
	extends Control

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_circle(size * 0.5, 6.0, V10DS.ROSE_300, true, -1.0, true)
