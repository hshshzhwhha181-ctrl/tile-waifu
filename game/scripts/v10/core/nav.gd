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
			return bool(G.S.get("free10", false))
		"shop":
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


# Настройки → «Уведомления» (meta Ф1; UX §3.2): one row under «Фишки и словарь»; the panel opens in a sheet after
# the settings window closes (never a window over a window, П-6)
static func settings_notify(main, p: Control) -> void:
	var extra: = 84.0
	var y0: = 900.0 + V10Clarity.SETTINGS_EXTRA
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
	var y0: = 900.0 + V10Clarity.SETTINGS_EXTRA + 84.0
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


class _Band:
	extends Control

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP  # the band eats taps between the tabs

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(V10DS.NIGHT_900, 0.94))
		V10Plate.hairline(self, 24.0, size.x - 24.0, 0.5, Color(V10DS.GOLD_700, V10DS.HAIR_A))


class _Dot:
	extends Control

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_circle(size * 0.5, 6.0, V10DS.ROSE_300, true, -1.0, true)
