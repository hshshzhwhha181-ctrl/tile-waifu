class_name V10MjBridgeDailyScreen
extends Control

# «Задача дня» — «Какую сбросить?» (docs/MODES.md §4.5; каркас §4; UX_RULES §6.6). Контракт §7.1:
#   setup(main, args) · сигнал finished(result) · args.presence (on/sacred) · награды не начисляет (result.rewards).
#
# args: day ("2027-01-12"; иначе сегодня), item (готовая задача — демо/самотест), hero (иначе Маджонг-тян — хозяйка
#   режима), presence, look ({face_tint}), demo (без сейва), school (true/false — подсказка формы принудительно).
#
# Экран (720×1280; на 9:20 и длиннее лишняя высота уходит в её полосу):
#   0 … band_h          её полоса: назад · «Задача 12» · арочное окно Маджонг-тян
#   band_h … +96        её фраза у плеча (Caveat 30, без коробки)
#   стол (фетр)         «Ветер Восток» и «Дора» (индикатор → дора) · рука 14 × 48 px · пруд для сброса
#   низ                 «Сбросить» (после выбора фишки) · «Не знаю — покажи»
# После ответа — лист: «сколько фишек ждут» (полоса), какие фишки ждут, шаринг без спойлера, веер-календарь
# месяца, серия, награда (только показывается), «Готово».
# Бюджет до ответа: тапаемых 3 (назад, Сбросить, Не знаю), слов ≤ 8, бейджей 0, валют 0.

signal finished(result: Dictionary)

const T: = V10MjBridgeLook.TOK
const TILE_W: = 48.0
const MAX_TRIES: = 2
const FELT_H: = 360.0

var main
var args: = {}
var item: = {}
var day: = ""
var hero: = "mc"
var demo: = false
var save_d: = {}
var school: = false
var presence
var lite: V10MjBridgePresence

var vw: = Vector2(720, 1280)
var band_h: = 120.0
var felt_r: = Rect2()
var hand_r: = Rect2()
var pond_c: = Vector2.ZERO
var btn_r: = Rect2()
var tile_w: = TILE_W
var tiles: Array = []          # V10MjBridgeTile по порядку показа
var groups: Array = []         # подсказка формы: [{t, from, to}]
var sel: = -1
var tries: = 0
var tried: Array = []
var answered: = false
var shown: = false
var ok: = false
var pick: = -1
var t0: = 0.0
var result: = {}
var rec: = {}

var title_lbl: Label
var hand_root: Control
var marks: Control
var btn_drop: Button
var btn_show: Button
var sheet_layer: Control
var share_text: = ""
var toast: Label


func build(m, a: Dictionary = {}) -> void:
	setup(m, a)


func setup(m, a: Dictionary = {}) -> void:
	main = m
	args = a
	demo = bool(a.get("demo", false))
	save_d = V10MjBridgeSave.st() if not demo else V10MjBridgeSave.fresh()
	var d: = V10MjBridgeDaily.parse_day(String(a.get("day", "")))
	if d.is_empty():
		d = V10MjBridgeDaily.today()
	day = V10MjBridgeDaily.day_key(d)
	item = (a.get("item") as Dictionary).duplicate(true) if a.get("item") is Dictionary else V10MjBridgeDaily.item_for(d)
	if not item.is_empty():
		V10MjBridgeDaily.norm(item)
	hero = V10MjBridgeLook.hero_ok(String(a.get("hero", V10MjBridgeInfo.INFO.host)))
	school = bool(a.get("school", V10MjBridgeSave.school_hint(save_d, item) if not item.is_empty() else false))
	var lk_d = a.get("look", {})
	if lk_d is Dictionary and (lk_d as Dictionary).has("face_tint"):
		V10MjBridgeTile.look = {"face_tint": (lk_d as Dictionary).face_tint}
	if is_inside_tree():
		_build()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not args.is_empty() and tiles.is_empty():
		_build()


# ── сборка ───────────────────────────────────────────────────────────────────

func _build() -> void:
	vw = get_viewport_rect().size
	if vw.x <= 0.0:
		vw = Vector2(720, 1280)
	if anchor_right == 0.0:
		size = vw
	var extra: = maxf(0.0, vw.y - 1280.0)
	band_h = 120.0 + minf(extra, 330.0)
	var spare: = extra - minf(extra, 330.0)
	t0 = Time.get_ticks_msec() / 1000.0
	add_child(V10MjBridgeLook.backdrop(hero))
	if item.is_empty():
		_build_empty()
		return
	felt_r = Rect2(16, band_h + 96 + spare * 0.3, vw.x - 32, FELT_H)
	add_child(V10MjBridgeLook.felt(felt_r, hero))
	_build_band()
	_build_table()
	_build_hand()
	_build_buttons()
	_build_presence()
	sheet_layer = Control.new()
	sheet_layer.name = "Sheets"
	sheet_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(sheet_layer)
	if presence == lite:
		lite.on("start", {})
	var prev = (save_d.days as Dictionary).get(day) if not demo else null
	if prev is Dictionary and not bool(args.get("replay", false)):
		# задача сегодня уже решена — сразу итог (без награды)
		_restore(prev)
	else:
		lite.say(V10MjBridgeDaily.intro_line(item, school), 5.0, true)


func _build_empty() -> void:
	var l: = V10MjBridgeLook.label("Задачи на сегодня нет", 32, T.paper100, "title", 600)
	l.position = Vector2(32, 200)
	add_child(l)
	var b: = V10MjBridgeLook.primary("Готово")
	b.position = Vector2(vw.x * 0.5 - 280, vw.y - 184)
	b.pressed.connect(func(): finished.emit({"mode": "bridge_daily", "win": false, "score": 0, "stars": 0, "time_s": 0, "pairs": 0, "hero": hero, "seed": 0, "level": 0, "rewards": V10MjBridgeSave.NO_REWARD.duplicate(), "action": "exit"}))
	add_child(b)


func _build_band() -> void:
	var back: = V10MjBridgeLook.icon_button("back", Vector2(12, 18))
	back.name = "Back"
	back.pressed.connect(_exit)
	add_child(back)
	var hb: = V10MjBridgeLook.icon_button("help", Vector2(vw.x - 206.0, 18.0))
	hb.name = "HelpBtn"
	hb.pressed.connect(open_help)
	add_child(hb)
	title_lbl = V10MjBridgeLook.label("Задача %d" % int(item.n), 32, T.paper100, "title", 700)
	title_lbl.position = Vector2(100, 34)
	add_child(title_lbl)
	if school:
		var ic: = V10MjBridgeIcon.new("school", T.gold500)
		ic.size = Vector2(36, 36)
		ic.position = Vector2(100 + title_lbl.get_minimum_size().x + 12, 40)
		add_child(ic)


func _build_table() -> void:
	var y: = felt_r.position.y + 22.0
	var tw: = 40.0
	# ветер
	var wl: = V10MjBridgeLook.label("Ветер", 18, T.paper500, "body", 700)
	wl.position = Vector2(felt_r.position.x + 24, y + 4)
	add_child(wl)
	var wind: = V10MjBridgeTile.make(int(item.get("wind", 27)), tw)
	wind.position = Vector2(felt_r.position.x + 24, y + 30)
	add_child(wind)
	var wn: = V10MjBridgeLook.label(V8Mj.WIND_RU[int(item.get("wind", 27)) - 27], 22, T.paper100, "body", 800)
	wn.position = Vector2(felt_r.position.x + 24 + tw + 12, y + 44)
	add_child(wn)
	# дора: индикатор → дора
	var dl: = V10MjBridgeLook.label("Дора", 18, T.paper500, "body", 700)
	dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	dl.size = Vector2(160, 26)
	dl.position = Vector2(felt_r.end.x - 24 - 160, y + 4)
	add_child(dl)
	var dk: = V8Mj.dora_of(int(item.dora))
	var dt: = V10MjBridgeTile.make(dk, tw)
	dt.position = Vector2(felt_r.end.x - 24 - tw, y + 30)
	add_child(dt)
	var ar: = Control.new()
	ar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ar.position = Vector2(felt_r.end.x - 24 - tw - 34, y + 30)
	ar.size = Vector2(30, tw * V10MjBridgeTile.ASPECT)
	ar.draw.connect(func():
		var cy: = ar.size.y * 0.5
		ar.draw_line(Vector2(4, cy), Vector2(24, cy), T.gold500, 2.0, true)
		ar.draw_polyline(PackedVector2Array([Vector2(18, cy - 6), Vector2(24, cy), Vector2(18, cy + 6)]), T.gold500, 2.0, true))
	add_child(ar)
	var di: = V10MjBridgeTile.make(int(item.dora), tw * 0.8)
	di.position = Vector2(felt_r.end.x - 24 - tw - 34 - tw * 0.8 - 4, y + 30 + tw * V10MjBridgeTile.ASPECT * 0.2)
	di.modulate.a = 0.85
	add_child(di)
	# пруд: место сброса
	pond_c = Vector2(vw.x * 0.5, felt_r.end.y - 58.0)
	var pond: = Control.new()
	pond.name = "Pond"
	pond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pond.position = pond_c - Vector2(60, 44)
	pond.size = Vector2(120, 88)
	pond.draw.connect(func():
		var c: = pond.size * 0.5
		pond.draw_set_transform(c, 0.0, Vector2(1.0, 0.45))
		pond.draw_circle(Vector2.ZERO, 58.0, Color(T.night900, 0.55))
		pond.draw_arc(Vector2.ZERO, 58.0, 0, TAU, 48, Color(T.gold700, 0.35), 1.0, true)
		pond.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE))
	add_child(pond)


func _hand_order() -> Array:
	var hand: Array = V10MjBridgeTiles.sorted(item.hand)
	groups = []
	if not school:
		return hand
	var shp: Array = item.get("shape", [])
	if shp.is_empty():
		for g in V10MjBridgeDaily.shape(hand):
			shp.append([String(g.t), g.k])
	var out: = []
	for g in shp:
		var from: = out.size()
		for k in g[1]:
			out.append(int(k))
		groups.append({"t": String(g[0]), "from": from, "to": out.size() - 1})
	if out.size() != 14:
		groups = []
		return hand
	return out


func _build_hand() -> void:
	var order: = _hand_order()
	var gaps: = 0.0
	if not groups.is_empty():
		gaps = 8.0 * (groups.size() - 1)
	else:
		gaps = 10.0
	tile_w = minf(TILE_W * vw.x / 720.0, (vw.x - 32.0 - gaps) / 14.0)
	var th: = tile_w * V10MjBridgeTile.ASPECT
	var total: = tile_w * 14.0 + gaps
	var x0: = (vw.x - total) * 0.5
	var y: = felt_r.position.y + 128.0
	hand_r = Rect2(x0 - 4, y - 20, total + 8, th + 36)
	hand_root = Control.new()
	hand_root.name = "Hand"
	hand_root.position = hand_r.position
	hand_root.size = hand_r.size
	hand_root.mouse_filter = Control.MOUSE_FILTER_STOP
	hand_root.gui_input.connect(_on_hand_input)
	add_child(hand_root)
	marks = Control.new()
	marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marks.set_anchors_preset(Control.PRESET_FULL_RECT)
	marks.draw.connect(_draw_marks)
	add_child(marks)
	var x: = x0
	var gi: = 0
	for i in 14:
		if not groups.is_empty() and gi < groups.size() and i > int(groups[gi].to):
			gi += 1
			x += 8.0
		elif groups.is_empty() and i == 13:
			x += 10.0
		var t: = V10MjBridgeTile.make(order[i], tile_w)
		t.position = Vector2(x, y)
		t.set_meta("home", t.position)
		add_child(t)
		tiles.append(t)
		x += tile_w
	move_child(marks, get_child_count() - 1)


func _draw_marks() -> void:
	# «Школа стола»: линии под наборами (нефрит), парами и заготовками (золото), лишние — без линии
	if groups.is_empty() or answered:
		return
	for g in groups:
		var a: V10MjBridgeTile = tiles[int(g.from)]
		var b: V10MjBridgeTile = tiles[int(g.to)]
		var y: float = a.get_meta("home").y + a.size.y + 8.0
		var x0: float = a.get_meta("home").x + 3.0
		var x1: float = b.get_meta("home").x + b.size.x - 3.0
		match String(g.t):
			"set":
				marks.draw_line(Vector2(x0, y), Vector2(x1, y), T.jade300, 3.0, true)
			"pair":
				marks.draw_line(Vector2(x0, y), Vector2(x1, y), T.gold500, 3.0, true)
			"part":
				var xx: = x0
				while xx < x1:
					marks.draw_line(Vector2(xx, y), Vector2(minf(xx + 6.0, x1), y), Color(T.gold500, 0.8), 3.0, true)
					xx += 11.0


func _build_buttons() -> void:
	btn_r = Rect2(0, vw.y - 40.0 - 80.0 - 104.0 - 12.0, vw.x, 104.0 + 12.0 + 80.0)
	btn_drop = V10MjBridgeLook.primary("Сбросить")
	btn_drop.name = "Drop"
	btn_drop.position = Vector2(vw.x * 0.5 - 280.0, btn_r.position.y)
	btn_drop.pressed.connect(drop)
	btn_drop.visible = false
	add_child(btn_drop)
	btn_show = V10MjBridgeLook.secondary("Не знаю — покажи", 400.0, false)
	btn_show.name = "Show"
	btn_show.position = Vector2(vw.x * 0.5 - 200.0, btn_r.position.y + 104.0 + 12.0)
	btn_show.pressed.connect(reveal)
	add_child(btn_show)
	toast = V10MjBridgeLook.label("", 20, T.paper100, "body", 800)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.size = Vector2(vw.x, 30)
	toast.modulate.a = 0.0
	add_child(toast)


func _window_rect() -> Rect2:
	var h: = band_h - 12.0
	var w: = clampf(h * 0.72, 96.0, 300.0)
	if band_h <= 140.0:
		w = 104.0
		h = band_h - 8.0
	return Rect2(vw.x - w - 20.0, band_h - h - 2.0, w, h)


func _build_presence() -> void:
	var ext = args.get("presence")
	lite = V10MjBridgePresence.new()
	lite.attach(self, hero, {"ring": false})
	var wr: = _window_rect()
	lite.layout(Rect2(0, 0, vw.x, band_h), wr, Rect2(24, band_h + 4.0, vw.x - 48.0, 88.0))
	presence = ext if ext != null and ext.has_method("on") else lite
	if presence != lite:
		lite.hide_window()
	for r in sacred_rects():
		presence.sacred(r)
		if presence != lite:
			lite.sacred(r)


func sacred_rects() -> Array:
	return [hand_r, btn_r]


# ── ввод ─────────────────────────────────────────────────────────────────────

func _on_hand_input(e: InputEvent) -> void:
	if answered:
		return
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		var p: Vector2 = hand_root.position + (e as InputEventMouseButton).position
		for i in tiles.size():
			var t: V10MjBridgeTile = tiles[i]
			var r: = Rect2(t.get_meta("home") - Vector2(0, 16), t.size + Vector2(0, 32))
			if r.has_point(p):
				select(i)
				return


func select(i: int) -> void:
	if answered or i < 0 or i >= tiles.size():
		return
	if sel == i:
		_lift(i, false)
		sel = -1
		btn_drop.visible = false
		return
	if sel >= 0:
		_lift(sel, false)
	sel = i
	_lift(i, true)
	V9Feel.sound("pop", 1.1, -6.0)
	presence.on("pick", {"pos": (tiles[i] as Control).get_global_rect().get_center()})
	if presence != lite:
		lite.on("pick", {"pos": (tiles[i] as Control).get_global_rect().get_center()})
	if not btn_drop.visible:
		btn_drop.visible = true
		btn_drop.modulate.a = 0.0
		var tw: = btn_drop.create_tween()
		tw.tween_property(btn_drop, "modulate:a", 1.0, 0.16)


func select_kind(k: int) -> void:
	for i in tiles.size():
		if (tiles[i] as V10MjBridgeTile).kind == k and not (tiles[i] as V10MjBridgeTile).mark:
			select(i)
			return


func _lift(i: int, on_: bool) -> void:
	var t: V10MjBridgeTile = tiles[i]
	t.sel = on_
	var tw: = t.create_tween()
	tw.tween_property(t, "lift", 14.0 if on_ else 0.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_method(func(_v): t.queue_redraw(), 0.0, 1.0, 0.12)


# ── ответ ────────────────────────────────────────────────────────────────────

func drop() -> void:
	if answered or sel < 0:
		return
	var t: V10MjBridgeTile = tiles[sel]
	var k: = t.kind
	tries += 1
	var a: = V10MjBridgeDaily.analysis_of(item)
	var good: bool = (a.best as Array).has(k)
	pick = k
	if good:
		_finish(true, false, sel)
		return
	if tries < MAX_TRIES:
		# неверно: фишка падает в пруд, вздрагивает и возвращается с отметкой
		var idx: = sel
		sel = -1
		btn_drop.visible = false
		tried.append(k)
		t.sel = false
		var home: Vector2 = t.get_meta("home")
		var tw: = t.create_tween()
		tw.tween_property(t, "position", pond_c - t.size * 0.5, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(t, "rotation", 0.08, 0.06)
		tw.tween_property(t, "rotation", -0.08, 0.08)
		tw.tween_property(t, "rotation", 0.0, 0.06)
		tw.tween_property(t, "position", home, 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		tw.parallel().tween_property(t, "lift", 0.0, 0.2)
		tw.tween_callback(func():
			t.mark = true
			t.queue_redraw())
		V9Feel.sound("deny", 1.0, -8.0)
		lite.say(V10MjBridgeDaily.retry_line(item, k), 4.0, true)
		return
	_finish(false, false, sel)


func reveal() -> void:
	if answered:
		return
	shown = true
	_finish(false, true, -1)


func _finish(good: bool, by_show: bool, idx: int) -> void:
	answered = true
	ok = good
	btn_drop.visible = false
	btn_show.visible = false
	lite.input_on = false
	var a: = V10MjBridgeDaily.analysis_of(item)
	var best_k: int = pick if good else int(a.best[0])
	# неверный выбор остаётся в руке с отметкой; в пруд уходит лучший
	if idx >= 0 and not good:
		var wt: V10MjBridgeTile = tiles[idx]
		wt.sel = false
		wt.mark = true
		var tw0: = wt.create_tween()
		tw0.tween_property(wt, "lift", 0.0, 0.12)
	var bi: = idx if good else -1
	if bi < 0:
		for i in tiles.size():
			if (tiles[i] as V10MjBridgeTile).kind == best_k:
				bi = i
				break
	var bt: V10MjBridgeTile = tiles[bi]
	bt.best = true
	bt.sel = false
	var tw: = bt.create_tween()
	tw.tween_property(bt, "lift", 14.0, 0.12)
	tw.tween_interval(0.12 if good else 0.45)
	tw.tween_property(bt, "position", pond_c - bt.size * 0.5, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(bt, "lift", 0.0, 0.3)
	tw.parallel().tween_property(bt, "rotation", 0.05, 0.3)
	marks.queue_redraw()
	var line: = V10MjBridgeDaily.explain(item, pick if good else (pick if not by_show else -1), good)
	lite.say(line, 0.0, true)
	if good:
		V9Feel.sound("sparkle", 1.0, -4.0)
		presence.on("pair", {"pos": pond_c})
		presence.on("last_pair", {})
		if presence != lite:
			lite.on("pair", {"pos": pond_c})
	_record()
	await get_tree().create_timer(0.9 if not bool(args.get("instant", false)) else 0.05).timeout
	_result_sheet()


func _record() -> void:
	var stars: = V10MjBridgeSave.daily_stars(ok, tries, shown)
	if not demo:
		rec = V10MjBridgeSave.record_daily(save_d, day, int(item.n), ok, tries, shown, pick)
		if G.has_method("save"):
			G.save()
	else:
		var tmp: = V10MjBridgeSave.fresh()
		tmp.solved = int(args.get("demo_solved", 2))
		tmp.streak = int(args.get("demo_streak", 0))
		tmp.last_day = String(args.get("demo_last", ""))
		for dd in args.get("demo_days", []):
			tmp.days[dd] = {"n": 0, "ok": true, "try": 1, "shown": false, "pick": 0}
		rec = V10MjBridgeSave.record_daily(tmp, day, int(item.n), ok, tries, shown, pick)
		save_d = tmp
	share_text = V10MjBridgeDaily.share(item, tries if ok else 0, shown or not ok)
	var a: = V10MjBridgeDaily.analysis_of(item)
	result = {
		"mode": "bridge_daily", "win": ok, "score": int(a.n) if ok else 0, "stars": stars,
		"time_s": int(Time.get_ticks_msec() / 1000.0 - t0), "pairs": 0, "hero": hero, "seed": int(item.n), "level": int(item.n),
		"rewards": rec.get("rewards", V10MjBridgeSave.NO_REWARD.duplicate()),
		"day": day, "n": int(item.n), "tries": tries, "shown": shown, "pick": pick, "best": a.best,
		"share": share_text, "streak": int(rec.get("streak", 0)), "solved": int(rec.get("solved", 0)),
		"riichi_opened": bool(rec.get("riichi_opened", false)), "riichi_open": bool(save_d.get("riichi_open", false)),
		"fan_complete": bool(rec.get("fan_complete", false)), "month": day.substr(0, 7),
		"month_host": V10MjBridgeSave.month_host(day.substr(0, 7)), "first_today": bool(rec.get("first_today", false)),
	}


func _restore(prev: Dictionary) -> void:
	tries = int(prev.get("try", 1))
	shown = bool(prev.get("shown", false))
	pick = int(prev.get("pick", -1))
	ok = bool(prev.get("ok", false))
	answered = true
	btn_drop.visible = false
	btn_show.visible = false
	var a: = V10MjBridgeDaily.analysis_of(item)
	for t in tiles:
		if (t as V10MjBridgeTile).kind == int(a.best[0]):
			(t as V10MjBridgeTile).best = true
			(t as Control).position = pond_c - (t as Control).size * 0.5
			break
	lite.say(V10MjBridgeDaily.explain(item, pick if ok else -1, ok), 0.0, true)
	share_text = V10MjBridgeDaily.share(item, tries if ok else 0, shown or not ok)
	result = {"mode": "bridge_daily", "win": ok, "score": 0, "stars": V10MjBridgeSave.daily_stars(ok, tries, shown),
		"time_s": 0, "pairs": 0, "hero": hero, "seed": int(item.n), "level": int(item.n), "rewards": V10MjBridgeSave.NO_REWARD.duplicate(),
		"day": day, "n": int(item.n), "tries": tries, "shown": shown, "pick": pick, "best": a.best, "share": share_text,
		"streak": int(save_d.streak), "solved": int(save_d.solved), "riichi_opened": false,
		"riichi_open": bool(save_d.riichi_open), "fan_complete": false, "month": day.substr(0, 7),
		"month_host": V10MjBridgeSave.month_host(day.substr(0, 7)), "first_today": false}
	rec = {"rewards": V10MjBridgeSave.NO_REWARD.duplicate(), "streak": int(save_d.streak)}
	_result_sheet()


# ── лист итога ───────────────────────────────────────────────────────────────

func _result_sheet() -> void:
	var H: = 680.0
	var p: = V10MjBridgeLook.sheet(sheet_layer, vw, H)
	# лист не притушивает руку: ответ должен быть виден
	(sheet_layer.get_child(0) as ColorRect).color = Color(T.night900, 0.0)
	(sheet_layer.get_child(0) as ColorRect).mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var a: = V10MjBridgeDaily.analysis_of(item)
	var rows: Dictionary = a.rows
	var head: = "Верно!" if ok and tries == 1 else ("Верно" if ok else "Ответ")
	var h: = V10MjBridgeLook.label(head, 44, T.paper100, "title", 700)
	h.position = Vector2(32, 22)
	p.add_child(h)
	var sr: = V10MjBridgeLook.stars_row(V10MjBridgeSave.daily_stars(ok, tries, shown), 3, 34.0)
	sr.position = Vector2(vw.x - 32.0 - sr.size.x, 36)
	p.add_child(sr)
	# полоса «сколько фишек ждут»: лучший сброс и (если другой) твой
	var best_n: = int(a.n)
	var mx: = maxi(best_n, 1)
	var y: = 96.0
	var lb: = V10MjBridgeLook.label(_cap(V10MjBridgeDaily.wait_tiles(best_n)), 22, T.paper100, "body", 800)
	lb.position = Vector2(32, y)
	p.add_child(lb)
	p.add_child(_bar(Rect2(32, y + 38, vw.x - 64, 10), 1.0, T.jade500))
	if pick >= 0 and not ok and rows.has(pick):
		var pn: = int(rows[pick].n)
		var pl: = V10MjBridgeLook.label("Твой сброс: %d" % pn if int(rows[pick].sh) == int(a.sh) else "Твой сброс: дальше от готовой", 18, T.paper500, "body", 700)
		pl.position = Vector2(32, y + 56)
		p.add_child(pl)
		p.add_child(_bar(Rect2(32, y + 86, vw.x - 64, 6), float(pn) / mx if int(rows[pick].sh) == int(a.sh) else 0.08, T.paper500))
		y += 50.0
	# какие фишки ждут (мини-фишки)
	var waits: Array = rows[int(a.best[0])].waits
	var mw: = minf(40.0, (vw.x - 64.0) / maxf(1.0, waits.size()) - 6.0)
	for i in waits.size():
		var t: = V10MjBridgeTile.make(int(waits[i]), mw)
		t.position = Vector2(32 + i * (mw + 6.0), y + 66)
		t.shadow = false
		p.add_child(t)
	y += 66.0 + mw * V10MjBridgeTile.ASPECT + 22.0
	# шаринг без спойлера
	var card: = Panel.new()
	var sb: = StyleBoxFlat.new()
	sb.bg_color = T.night800
	sb.set_corner_radius_all(4)
	sb.border_color = Color(T.gold700, 0.35)
	sb.set_border_width_all(1)
	card.add_theme_stylebox_override("panel", sb)
	card.position = Vector2(24, y)
	card.size = Vector2(vw.x - 48, 104)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(card)
	var first_line: = share_text.split("\n")[0]
	var sl: = V10MjBridgeLook.label(first_line, 20, T.paper100, "body", 800)
	sl.position = Vector2(20, 14)
	card.add_child(sl)
	var sq: = Control.new()
	sq.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sq.position = Vector2(20, 56)
	sq.size = Vector2(14 * 22, 22)
	var hk: Array = V10MjBridgeTiles.sorted(item.hand)
	sq.draw.connect(func():
		for i in hk.size():
			sq.draw_rect(Rect2(i * 22.0, 0, 18, 18), V10MjBridgeTiles.SUIT_COL[V10MjBridgeTiles.suit(int(hk[i]))]))
	card.add_child(sq)
	var share_b: = V10MjBridgeLook.icon_button("share", Vector2(card.size.x - 92, 12), T.gold300)
	share_b.name = "Share"
	share_b.pressed.connect(_share)
	card.add_child(share_b)
	y += 104.0 + 20.0
	# веер-календарь месяца и серия
	var fan: = _fan(Vector2(32, y), 116.0)
	p.add_child(fan)
	var st_l: = V10MjBridgeLook.label("Серия %d %s" % [int(rec.get("streak", 0)), V10MjBridgeDaily.plural(int(rec.get("streak", 0)), "день", "дня", "дней")], 26, T.paper100, "body", 800)
	st_l.position = Vector2(32 + 116 * 2 + 28, y + 6)
	p.add_child(st_l)
	var ty: = y + 46.0
	var rw: Dictionary = rec.get("rewards", {})
	if int(rw.get("coins", 0)) > 0:
		var tk: = V10MjBridgeLook.label("+%d монет · +%d лепесток" % [int(rw.coins), int(rw.get("petals", 0))], 20, T.gold300, "body", 800)
		tk.position = Vector2(32 + 116 * 2 + 28, ty)
		p.add_child(tk)
		ty += 32.0
	if bool(rec.get("riichi_opened", false)):
		var ro: = V10MjBridgeLook.label("Стол на четверых открыт", 20, T.jade300, "body", 800)
		ro.position = Vector2(32 + 116 * 2 + 28, ty)
		p.add_child(ro)
	var done: = V10MjBridgeLook.primary("Готово")
	done.name = "Primary"
	done.position = Vector2(vw.x * 0.5 - 280.0, H - 136.0)
	done.pressed.connect(func():
		result["action"] = "done"
		finished.emit(result))
	V10MjBridgeLook.breathe(done)
	p.add_child(done)


func _cap(s: String) -> String:
	return s.substr(0, 1).to_upper() + s.substr(1)


func _bar(r: Rect2, v: float, c: Color) -> Control:
	var b: = Control.new()
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.position = r.position
	b.size = r.size
	b.draw.connect(func():
		b.draw_rect(Rect2(Vector2.ZERO, b.size), Color(T.paper100, 0.1))
		b.draw_rect(Rect2(Vector2.ZERO, Vector2(b.size.x * clampf(v, 0.0, 1.0), b.size.y)), c))
	b.set_meta("v", v)
	b.name = "Bar"
	return b


# веер-календарь: рёбра — дни месяца (золото — решено, нефрит — с ответом, тёмные — нет), сегодня — её цвет
func _fan(at: Vector2, r: float) -> Control:
	var f: = Control.new()
	f.name = "Fan"
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	f.position = at
	f.size = Vector2(r * 2.0, r + 10.0)
	var month: = day.substr(0, 7)
	var marks_m: = V10MjBridgeSave.month_marks(save_d, month)
	var today_i: = int(day.substr(8, 2)) - 1
	var acc_c: Color = V10MjBridgeLook.accent(hero)[0]
	f.draw.connect(func():
		var c: = Vector2(r, r + 4.0)
		var n: = marks_m.size()
		for i in n:
			var a0: = PI + PI * float(i) / n
			var a1: = PI + PI * float(i + 1) / n
			var col: Color = T.night600
			match String(marks_m[i]):
				"ok":
					col = T.gold300
				"done":
					col = T.jade500
			var pts: = PackedVector2Array([c + Vector2(cos(a0), sin(a0)) * r * 0.24, c + Vector2(cos(a0), sin(a0)) * r,
				c + Vector2(cos(a1), sin(a1)) * r, c + Vector2(cos(a1), sin(a1)) * r * 0.24])
			f.draw_colored_polygon(pts, Color(col, 0.92))
			f.draw_line(c + Vector2(cos(a0), sin(a0)) * r * 0.24, c + Vector2(cos(a0), sin(a0)) * r, T.night700, 1.5, true)
			if i == today_i:
				f.draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), acc_c, 2.0, true)
		f.draw_arc(c, r, PI, TAU, 48, Color(T.gold700, 0.6), 1.5, true)
		f.draw_circle(c, r * 0.12, T.gold700))
	return f


func _share() -> void:
	DisplayServer.clipboard_set(share_text)
	toast.text = "Скопировано"
	toast.position = Vector2(0, vw.y - 190.0)
	var tw: = toast.create_tween()
	tw.tween_property(toast, "modulate:a", 1.0, 0.12)
	tw.tween_interval(1.2)
	tw.tween_property(toast, "modulate:a", 0.0, 0.2)


func open_help() -> void:
	if answered:
		return
	var p: = V10MjBridgeLook.sheet(sheet_layer, vw, 460.0)
	var h: = V10MjBridgeLook.label("Как играть", 36, T.paper100, "title", 700)
	h.position = Vector2(32, 26)
	p.add_child(h)
	for k in V10MjBridgeInfo.HOW_DAILY.size():
		var row: Array = V10MjBridgeInfo.HOW_DAILY[k]
		var ic: = V10MjBridgeIcon.new(String(row[0]), T.gold300)
		ic.position = Vector2(32, 92 + k * 60)
		ic.size = Vector2(44, 44)
		p.add_child(ic)
		var l: = V10MjBridgeLook.label(String(row[1]), 20, T.paper300, "body", 700)
		l.position = Vector2(92, 100 + k * 60)
		p.add_child(l)
	var ok_b: = V10MjBridgeLook.primary("Понятно")
	ok_b.name = "OkBtn"
	ok_b.position = Vector2(vw.x * 0.5 - 280.0, 316)
	ok_b.pressed.connect(func(): V10MjBridgeLook.close_sheet(sheet_layer))
	p.add_child(ok_b)


func _exit() -> void:
	if answered and not result.is_empty():
		result["action"] = "exit"
		finished.emit(result)
		return
	finished.emit({"mode": "bridge_daily", "win": false, "score": 0, "stars": 0, "time_s": int(Time.get_ticks_msec() / 1000.0 - t0),
		"pairs": 0, "hero": hero, "seed": int(item.get("n", 0)), "level": int(item.get("n", 0)), "rewards": V10MjBridgeSave.NO_REWARD.duplicate(),
		"day": day, "action": "exit"})
