extends Control

# Хаб «Странствие» (spec R3, UX_RULES §3.4): недельный забег из 5 столов (4 + босс недели).
# Вход через Афишу и полку «Испытания» в Столах: main.go("journey", {}). После партии tower_play возвращает
# сюда main.go("journey", {"result": fin}) — итог показывается одним листом поверх хаба.
#
# Экран: шапка V10Header («‹» · «Странствие» · «?» → правила), пейзаж-дорога (арт journey_far или процедурный),
# свиток недели V10JourneyScroll (подписной приём: разворачивается под звук бумаги), строка попыток с датой МСК
# (отсчёт только в последние 48 ч), лучший результат недели, плашка «Честный зачёт», одна главная кнопка.
#   главное (1):        Начать забег / Продолжить · стол N из 5 / Тренировка (попыток нет) / К столам (закрыто)
#   второстепенные (≤2): Тренировка (если она не главная), Таблица
#   тихие (2):          ‹ и ? в шапке
# Логику не меняет: только V10Journey / V10TowerBoard / V10TowerUtil. Сейв — V10TowerUI.save_now() (README §8).

const J: = preload("res://scripts/v10/tower/journey.gd")
const U: = preload("res://scripts/v10/tower/tower_util.gd")
const TB: = preload("res://scripts/v10/tower/tower_board.gd")
const SCROLL: = preload("res://scripts/v10/tower/ui/journey_scroll.gd")
const SHEETS_PATH: = "res://scripts/v10/tower/ui/tower_sheets.gd"

const COL: = 720.0
const MARGIN: = 32.0  # hub margins (UX §6.1)
const SHEET_MARGIN: = 24.0
const ART_HORIZON: = 0.47  # journey_far.webp: the far ridge line as a share of the art height

var main = null
var args: = {}
var vs: = Vector2(720, 1280)
var ins: = {"top": 0.0, "bottom": 0.0}
var cx: = 0.0
var state: = ""  # "locked" | "new" | "run" | "spent" (for tests and the integrator)
var header: V10Header
var scroll: V10JourneyScroll
var layer: Control
var sheet: Control = null
var sheet_kind: = ""
var primary: V10Button
var buttons: = {}  # id -> V10Button (primary, practice, table)
var labels: = {}  # id -> Label (attempts, refresh, best, honest, caption, lock)
var _intro: Array = []
var _busy: = false
var _bg: Control


func build(m, a: Dictionary) -> void:
	main = m
	args = a if a != null else {}
	vs = get_viewport_rect().size
	position = Vector2.ZERO
	size = vs
	ins = V10TowerUI.insets(vs)
	cx = floorf(maxf(0.0, (vs.x - COL) * 0.5))
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if main and main.has_method("show_chrome"):
		main.show_chrome(false, false)
	_build_bg()
	layer = Control.new()
	layer.name = "Hub"
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.size = vs
	add_child(layer)
	header = V10Header.make(self, "Странствие", _on_back, _open_rules)
	if header.back_btn:
		V10TowerUI.role(header.back_btn, "tertiary")
	if header.help_btn:
		V10TowerUI.role(header.help_btn, "tertiary")
	_refresh(true)
	V10TowerUI.music("journey")
	var res = args.get("result", null)
	if res is Dictionary and not (res as Dictionary).is_empty():
		show_result(res)


# ---------------------------------------------------------------- state

func _partner() -> String:
	return String(J.save().get("level_partner", "mc"))


func _gate_name() -> String:
	var gi: = J.gate_index()
	return String(G.rank_title(gi / 3, gi % 3)) if G.has_method("rank_title") else "Нефрит I"


# one set of numbers for the layout and the landscape: the scroll under the header (on 9:20 a third of the extra
# height goes above it), the landscape gap, then info · secondaries · primary · caption from the bottom
func metrics() -> Dictionary:
	var T: = float(ins.get("top", 0.0))
	var B: = float(ins.get("bottom", 0.0))
	var extra: = maxf(0.0, vs.y - T - B - 1280.0)
	var sy: = T + V10Header.HEIGHT + 16.0 + floorf(extra * 0.35)
	var bottom: = vs.y - B - 24.0
	var cap_y: = bottom - 26.0
	var prim_y: = cap_y - 8.0 - 104.0
	var sec_y: = prim_y - 8.0 - 80.0
	var info_top: = sec_y - 24.0 - 48.0 - 16.0 - 34.0 - 28.0 - 28.0
	return {"scroll_y": sy, "scroll_bottom": sy + SCROLL.HEIGHT, "info_top": info_top, "sec_y": sec_y, "prim_y": prim_y,
		"cap_y": cap_y, "T": T, "B": B}


func _refresh(first: = false) -> void:
	for c in layer.get_children():
		layer.remove_child(c)
		c.queue_free()
	buttons.clear()
	labels.clear()
	_intro.clear()
	primary = null
	var open: = J.is_open()
	var info: = J.week_info()
	var run: Dictionary = J.current_run() if open else {}
	var left: = int(info.attempts_left)
	if not open:
		state = "locked"
	elif not run.is_empty():
		state = "run"
	elif left > 0:
		state = "new"
	else:
		state = "spent"
	var M: = metrics()
	var sc_info: = info.duplicate()
	sc_info["locked"] = not open
	scroll = SCROLL.new()
	scroll.name = "Scroll"
	scroll.position = Vector2(cx + 24.0, float(M.scroll_y))
	scroll.size = Vector2(COL - 48.0, SCROLL.HEIGHT)
	layer.add_child(scroll)
	scroll.configure(sc_info, run)
	var sec_y: float = M.sec_y
	var prim_y: float = M.prim_y
	var cap_y: float = M.cap_y
	# the info block sits with the actions, on the landscape (text on art: the one shadow rule)
	var x0: = cx + MARGIN
	var w0: = COL - MARGIN * 2.0
	var lines: = []  # [id, text, size, colour]
	if state == "locked":
		lines.append(["lock", "Откроется: на ранге %s" % _gate_name(), 22, V10DS.PAPER_100])
		lines.append(["lock_what", "Недельный забег: 4 стола и босс недели", 18, V10DS.PAPER_300])
	else:
		var att: = ("Попытки: %d из %d" % [left, int(info.attempts_max)]) if left > 0 or state == "run" else "Попытки этой недели закончились"
		lines.append(["attempts", att, 22, V10DS.PAPER_100])
		var rt: = "Обновится в %s" % String(info.refresh_text)
		if bool(info.countdown):
			rt += " · ещё %d ч" % maxi(1, int(ceil(float(info.secs_left) / 3600.0)))
		lines.append(["refresh", rt, 18, V10DS.PAPER_300])
		var best: Dictionary = info.best
		if int(best.get("score", 0)) > 0:
			var parts: = ["Лучшее за неделю: %s" % SCROLL.fmt_num(int(best.score))]
			var tn: = J.tier_name(J.tier_of(int(best.score)))
			if tn != "":
				parts.append(tn)
			parts.append("%d из %d %s" % [int(best.boards), J.BOARDS, "столов"])
			lines.append(["best", " · ".join(parts), 18, V10DS.GOLD_300])
	var info_h: = 0.0
	for ln in lines:
		info_h += (34.0 if int(ln[2]) == 22 else 28.0)
	var plate_h: = 0.0 if state == "locked" else 16.0 + 48.0
	var anchor: = sec_y - 24.0
	var y: = anchor - plate_h - info_h
	if state == "locked":
		# 0.12: the closed state shows the painted week scroll (journey_scroll_art, gilded lacquer roll until the art
		# lands); its lines sit on one plum lacquer plate under a gold rim — no blurred tone band
		var art_h: = _scroll_art(M)
		y = float(M.scroll_y) + art_h + 40.0
		var plate: = V10TowerUI.glyph(func(ci: CanvasItem, sz: Vector2) -> void:
			_draw_plum_plate(ci, Rect2(Vector2.ZERO, sz)),
			Vector2(w0 + 40.0, info_h + 36.0))
		plate.name = "LockTone"
		plate.position = Vector2(x0 - 20.0, y - 18.0)
		layer.add_child(plate)
	elif lines.size() > 0:
		# the week lines over the landscape: the same plum lacquer plate (the honest plate stays below it)
		var iplate: = V10TowerUI.glyph(func(ci: CanvasItem, sz: Vector2) -> void:
			_draw_plum_plate(ci, Rect2(Vector2.ZERO, sz)),
			Vector2(w0 + 40.0, info_h + 24.0))
		iplate.name = "InfoPlate"
		iplate.position = Vector2(x0 - 20.0, y - 12.0)
		layer.add_child(iplate)
		_intro.append(iplate)
	for ln in lines:
		_add_label(String(ln[0]), String(ln[1]), "ui", int(ln[2]), ln[3], Vector2(x0, y), w0)
		y += (34.0 if int(ln[2]) == 22 else 28.0)
	if state != "locked":
		y += 16.0
		var hp: = _honest_plate("Честный зачёт: наряды не дают силы")
		hp.position = Vector2(x0, y)
		layer.add_child(hp)
		_intro.append(hp)
	# primary
	var ptxt: = "Начать забег"
	var cap: = "Попытка спишется при старте"
	match state:
		"locked":
			ptxt = "К столам"
			cap = ""
		"run":
			ptxt = "Продолжить · стол %d из %d" % [int(run.board) + 1, J.BOARDS]
			cap = "Забег сохранён"
		"spent":
			ptxt = "Тренировка"
			cap = "Без наград и таблицы"
	primary = V10Button.make("play", ptxt, Vector2(560, 104))
	primary.name = "Primary"
	primary.position = Vector2(cx + (COL - 560.0) * 0.5, prim_y)
	V10TowerUI.role(primary, "primary")
	primary.pressed.connect(_on_primary)
	layer.add_child(primary)
	buttons["primary"] = primary
	if cap != "":
		var cl: = _add_label("caption", cap, "ui", 18, V10DS.PAPER_500, Vector2(cx + 80.0, cap_y), 560.0)
		cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# secondaries (≤ 2)
	var sec: = []
	if state in ["new", "run"]:
		sec.append(["practice", "Тренировка", _on_practice])
	if state != "locked":
		sec.append(["table", "Таблица", _open_table])
	var bw: = 280.0
	var gap: = 0.0
	var sx: = cx + (COL - (bw * sec.size() + gap * maxf(0.0, sec.size() - 1))) * 0.5
	for s in sec:
		var b: = V10Button.make("secondary", String(s[1]), Vector2(bw, 80))
		b.name = String(s[0]).capitalize()
		b.position = Vector2(sx, sec_y)
		V10TowerUI.role(b, "secondary")
		b.pressed.connect(s[2])
		layer.add_child(b)
		buttons[String(s[0])] = b
		_intro.append(b)
		sx += bw + gap
	_intro.append(primary)
	if first:
		_play_intro()
	else:
		scroll.show_now()


func _add_label(id: String, text: String, role_name: String, sz: int, col: Color, pos: Vector2, w: float) -> Label:
	var l: = V10TowerUI.label(V10TowerUI.ui_text(text), role_name, sz, col, true)
	l.name = id.capitalize()
	l.position = pos
	l.size = Vector2(w, V10Type.line_h(sz))
	layer.add_child(l)
	labels[id] = l
	_intro.append(l)
	return l


# «Честный зачёт» — one quiet line on the plate surface (HUD v2 §2.2), an info glyph and Caption 18
func _honest_plate(text: String) -> Control:
	var tw: = V10Type.text_w(text, "ui", 18)
	var w: = ceilf(16.0 + 24.0 + 12.0 + tw + 20.0)
	var p: = V10TowerUI.glyph(func(ci: CanvasItem, sz: Vector2) -> void:
		V10Plate.draw_surface(ci, Rect2(Vector2.ZERO, sz), true), Vector2(w, 48))
	p.name = "Honest"
	var ic: = V10Icons.icon("info", 24, V10DS.PAPER_500)
	ic.position = Vector2(16, 12)
	p.add_child(ic)
	var l: = V10TowerUI.label(text, "ui", 18, V10DS.PAPER_300)
	l.position = Vector2(52, 0)
	l.size = Vector2(tw + 8.0, 48)
	p.add_child(l)
	labels["honest"] = l
	return p


# ---------------------------------------------------------------- 0.12 imperial scroll art

const SCROLL_ART: = "res://assets/v10/hf_ui/journey_scroll_art.webp"
const ROLL_H: = 190.0


# The closed week scroll: the painted Higgsfield art when it is in the build (picked up by path, no code change on
# merge), else a gilded crimson lacquer roll with gold caps, cords and a cinnabar seal. The scroll's own grey rolled
# silhouette is hidden. Returns the height it takes under scroll_y.
func _scroll_art(M: Dictionary) -> float:
	var rs = scroll.get("_roll_silhouette")
	if rs is Control:
		(rs as Control).visible = false
	var r: = Rect2(cx + 24.0, float(M.scroll_y), COL - 48.0, SCROLL.HEIGHT)
	var tex: Texture2D = null
	if ResourceLoader.exists(SCROLL_ART):
		tex = load(SCROLL_ART) as Texture2D
	if tex != null and tex.get_width() > 0:
		var h: = minf(r.size.y, r.size.x * float(tex.get_height()) / float(tex.get_width()))
		var tr: = TextureRect.new()
		tr.name = "ScrollArt"
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.position = r.position
		tr.size = Vector2(r.size.x, h)
		layer.add_child(tr)
		_intro.append(tr)
		return h
	var g: = V10TowerUI.glyph(_draw_gilded_roll, Vector2(r.size.x, ROLL_H))
	g.name = "ScrollArt"
	g.position = r.position + Vector2(0, 96.0)
	layer.add_child(g)
	_intro.append(g)
	return 96.0 + ROLL_H


func _draw_gilded_roll(ci: CanvasItem, sz: Vector2) -> void:
	var c: = sz * 0.5
	var L: = sz.x - 150.0
	var bh: = 70.0
	ci.draw_set_transform(c, deg_to_rad(-3.0), Vector2.ONE)
	# soft shadow on the landscape
	ci.draw_colored_polygon(V10Button.rr_pts(Rect2(-L * 0.5 - 20.0, bh * 0.5 + 6.0, L + 40.0, 22.0), 11.0, 6), Color(V10DS.NIGHT_900, 0.42))
	# the axis knobs: dark wood in gold rings
	for sx in [-1.0, 1.0]:
		var kp: = Vector2(sx * (L * 0.5 + 34.0), 0)
		ci.draw_line(Vector2(sx * L * 0.5, 0), kp, V10DS.GOLD_700, 8.0, true)
		ci.draw_circle(kp, 16.0, V10DS.NIGHT_800, true, -1.0, true)
		ci.draw_arc(kp, 15.0, 0.0, TAU, 28, V10DS.GOLD_500, 3.0, true)
		ci.draw_circle(kp + Vector2(-4, -5), 4.0, Color(V10DS.PLATE_SPARK, 0.8), true, -1.0, true)
	# crimson lacquer body under a double gold bezel
	V10Button.lacquer(ci, Rect2(-L * 0.5, -bh * 0.5, L, bh), 18.0, V10DS.BTN_PLAY_TOP, V10DS.BTN_PLAY_MID, V10DS.BTN_PLAY_BOT, 1.0, V10DS.BTN_PLAY_GLOW, 0.3)
	# the paper layers peeking at the seam
	for k in 3:
		var yy: = -bh * 0.5 + 14.0 + float(k) * 5.0
		ci.draw_line(Vector2(-L * 0.5 + 34.0, yy), Vector2(L * 0.5 - 34.0, yy), Color(V10DS.PAPER_100, 0.16 - 0.04 * k), 1.0, true)
	# gold end caps
	for sx2 in [-1.0, 1.0]:
		var cr: = Rect2(sx2 * L * 0.5 - 13.0, -bh * 0.5 - 9.0, 26.0, bh + 18.0)
		V10Button.lacquer(ci, cr, 6.0, V10DS.PLATE_SPARK, V10DS.GOLD_500, V10DS.GOLD_700, 1.0, V10DS.PAPER_100, 0.35)
	# two gold silk cords and the hanging cinnabar seal
	for f in [0.26, 0.66]:
		var x: float = -L * 0.5 + L * float(f)
		ci.draw_rect(Rect2(x - 4.0, -bh * 0.5 - 1.0, 8.0, bh + 2.0), V10DS.GOLD_500)
		ci.draw_line(Vector2(x - 4.0, -bh * 0.5), Vector2(x - 4.0, bh * 0.5), V10DS.GOLD_700, 1.0)
		ci.draw_line(Vector2(x + 4.0, -bh * 0.5), Vector2(x + 4.0, bh * 0.5), V10DS.PLATE_SPARK, 1.0)
	var sx3: = -L * 0.5 + L * 0.66
	var sp: = Vector2(sx3 + 6.0, bh * 0.5 + 44.0)
	ci.draw_line(Vector2(sx3, bh * 0.5), sp - Vector2(0, 16.0), V10DS.GOLD_500, 2.0, true)
	ci.draw_circle(sp, 16.0, V10DS.CINNABAR, true, -1.0, true)
	ci.draw_arc(sp, 16.0, 0.0, TAU, 28, V10DS.GOLD_500, 2.0, true)
	ci.draw_rect(Rect2(sp - Vector2(6, 6), Vector2(12, 12)), Color(V10DS.PAPER_100, 0.85), false, 1.5)
	for t in 5:
		var tx: = sp.x - 6.0 + float(t) * 3.0
		ci.draw_line(Vector2(tx, sp.y + 16.0), Vector2(tx - 1.0, sp.y + 34.0), V10DS.CINNABAR, 1.5, true)
	# champagne sparkles on the lacquer
	for p in [Vector2(-L * 0.18, -bh * 0.22), Vector2(L * 0.08, -bh * 0.28), Vector2(L * 0.36, -bh * 0.18)]:
		var pv: Vector2 = p
		ci.draw_colored_polygon(PackedVector2Array([pv + Vector2(0, -6), pv + Vector2(2, 0), pv + Vector2(0, 6), pv + Vector2(-2, 0)]), Color(V10DS.PLATE_SPARK, 0.85))
		ci.draw_colored_polygon(PackedVector2Array([pv + Vector2(-6, 0), pv + Vector2(0, -2), pv + Vector2(6, 0), pv + Vector2(0, 2)]), Color(V10DS.PLATE_SPARK, 0.85))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# the info plate: royal plum lacquer under the full antique-gold rim, champagne studs in the corners
func _draw_plum_plate(ci: CanvasItem, r: Rect2) -> void:
	V10Plate.draw_surface(ci, r, false, false, true, false, false, -1.0, Color(V10DS.BTN_SEC_TOP, 0.97))
	for p in [Vector2(12, 12), Vector2(r.size.x - 12, 12), Vector2(12, r.size.y - 12), Vector2(r.size.x - 12, r.size.y - 12)]:
		var pv: Vector2 = p
		ci.draw_colored_polygon(PackedVector2Array([pv + Vector2(0, -4), pv + Vector2(4, 0), pv + Vector2(0, 4), pv + Vector2(-4, 0)]), V10DS.PLATE_SPARK)


# ---------------------------------------------------------------- motion

func _play_intro() -> void:
	scroll.unroll()
	var calm: = V10TowerUI.calm()
	var i: = 0
	for n in _intro:
		if not is_instance_valid(n):
			continue
		var c: = n as CanvasItem
		c.modulate.a = 0.0
		var tw: = c.create_tween()
		if calm:
			tw.tween_property(c, "modulate:a", 1.0, 0.12)
		else:
			# «Вдох» after the scroll has opened: 240 ms, 40 ms step (≤ 5 steps)
			tw.tween_interval(0.42 + 0.04 * mini(i, 4))
			tw.tween_property(c, "modulate:a", 1.0, 0.24).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		i += 1


# tests and shots: jump to the settled screen
func skip_intro() -> void:
	if scroll:
		scroll.show_now()
	for n in _intro:
		if is_instance_valid(n):
			(n as CanvasItem).modulate.a = 1.0


# ---------------------------------------------------------------- actions

func _on_back() -> void:
	if sheet and is_instance_valid(sheet):
		close_sheet()
		return
	if main:
		main.back()


func _on_primary() -> void:
	if _busy:
		return
	V10TowerUI.tap(primary, "pop")
	match state:
		"locked":
			if main:
				main.back()
		"run":
			var run: = J.current_run()
			if run.is_empty():
				_refresh()
				return
			_hold()
			V10TowerUI.sfx("feather", "whoosh")
			main.go("tower_play", {"mode": "journey", "run": run})
		"spent":
			_start_practice()
		_:
			var r: = J.start(_partner())
			if r.has("error"):
				V10TowerUI.deny(primary)
				_toast(String(r.error))
				_refresh()
				return
			_hold()
			state = "run"  # if the screen stays (main busy), the next tap continues this run, never spends another
			V10TowerUI.save_now()  # README §8: the attempt is spent — save at once
			V10TowerUI.sfx("feather", "whoosh")
			main.go("tower_play", {"mode": "journey", "run": r})


func _on_practice() -> void:
	if _busy:
		return
	V10TowerUI.tap(buttons.get("practice"), "tap")
	_start_practice()


func _start_practice() -> void:
	var r: = J.start(_partner(), true)
	_hold()
	V10TowerUI.sfx("feather", "whoosh")
	main.go("tower_play", {"mode": "practice", "run": r})


# one navigation per tap: further taps wait until main has switched screens (released after 1.5 s if it never does)
func _hold() -> void:
	_busy = true
	if is_inside_tree():
		var tw: = create_tween()
		tw.tween_interval(1.5)
		tw.tween_callback(_release)


func _release() -> void:
	_busy = false


func _toast(text: String) -> void:
	if main and main.has_method("toast"):
		main.toast(text, "")


# ---------------------------------------------------------------- sheets (one at a time, only over the screen)

func _sheet_base(title: String, sub: = "") -> Dictionary:
	close_sheet(true)
	var root: = Control.new()
	root.name = "Sheet"
	root.size = vs
	root.mouse_filter = Control.MOUSE_FILTER_STOP  # blocks the hub; closing is the sheet's own button or «назад»
	root.set_meta("v8_back", Callable(self, "close_sheet"))
	add_child(root)
	var scrim: = ColorRect.new()
	scrim.color = Color(V10DS.NIGHT_900, 0.62)
	scrim.size = vs
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(scrim)
	var panel: = V10TowerUI.glyph(func(ci: CanvasItem, sz: Vector2) -> void:
		V10Plate.draw_surface(ci, Rect2(Vector2(0, 0), sz + Vector2(0, 8)), false, false, false, false, false, -1.0, V10DS.NIGHT_700), Vector2(vs.x, 10))
	panel.name = "Panel"
	root.add_child(panel)
	var y: = 32.0
	var t: = V10TowerUI.label(title, "display", 44, V10DS.PAPER_100)
	t.position = Vector2(cx + SHEET_MARGIN, y)
	t.size = Vector2(COL - SHEET_MARGIN * 2.0, 52)
	panel.add_child(t)
	y += 56.0
	if sub != "":
		var s: = V10TowerUI.label(sub, "ui", 18, V10DS.PAPER_500)
		s.position = Vector2(cx + SHEET_MARGIN, y)
		s.size = Vector2(COL - SHEET_MARGIN * 2.0, 26)
		panel.add_child(s)
		y += 30.0
	sheet = root
	return {"root": root, "panel": panel, "y": y + 16.0}


func _sheet_finish(d: Dictionary, btn_text: String, on_press: Callable) -> Control:
	var panel: Control = d.panel
	var y: float = d.y + 16.0
	var b: = V10Button.make("play", btn_text, Vector2(560, 104))
	b.name = "SheetPrimary"
	b.position = Vector2(cx + (COL - 560.0) * 0.5, y)
	V10TowerUI.role(b, "primary")
	b.pressed.connect(func() -> void:
		V10TowerUI.tap(b, "pop")
		on_press.call())
	panel.add_child(b)
	y += 104.0 + 24.0 + float(ins.get("bottom", 0.0))
	panel.size = Vector2(vs.x, y)
	panel.custom_minimum_size = panel.size
	var py: = vs.y - y
	var root: Control = d.root
	if V10TowerUI.calm():
		panel.position = Vector2(0, py)
		root.modulate.a = 0.0
		root.create_tween().tween_property(root, "modulate:a", 1.0, 0.12)
	else:
		# «Шёлк»: from below, 220 ms QUINT OUT
		panel.position = Vector2(0, vs.y)
		var tw: = root.create_tween()
		tw.tween_property(panel, "position:y", py, 0.22).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	return root


func _set_hub_visible(v: bool) -> void:
	if layer:
		layer.visible = v
	if header:
		header.visible = v


func close_sheet(now: = false) -> void:
	_set_hub_visible(true)
	if sheet == null or not is_instance_valid(sheet):
		sheet = null
		sheet_kind = ""
		return
	var s: = sheet
	sheet = null
	sheet_kind = ""
	if now or V10TowerUI.calm():
		remove_child(s)
		s.queue_free()
		return
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw: = s.create_tween()
	tw.tween_property(s, "modulate:a", 0.0, 0.16).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
	tw.tween_callback(s.queue_free)


func _row(panel: Control, y: float, icon: Callable, text: String, col: = V10DS.PAPER_100) -> float:
	var iw: = 48.0
	var g: = V10TowerUI.glyph(icon, Vector2(iw, iw))
	var tw: = COL - SHEET_MARGIN * 2.0 - iw - 16.0
	var n: = V10Type.lines_needed(text, "ui", 22, tw)
	var h: = maxf(iw, 32.0 * n)
	g.position = Vector2(cx + SHEET_MARGIN, y + (h - iw) * 0.5)
	panel.add_child(g)
	var l: = V10TowerUI.label(V10TowerUI.ui_text(text), "ui", 22, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.max_lines_visible = 2
	l.position = Vector2(cx + SHEET_MARGIN + iw + 16.0, y + (h - 32.0 * n) * 0.5)
	l.size = Vector2(tw, 32.0 * n)
	panel.add_child(l)
	return y + h + 16.0


func _text(panel: Control, y: float, text: String, sz: int, col: Color) -> float:
	var w: = COL - SHEET_MARGIN * 2.0
	var n: = V10Type.lines_needed(text, "ui", sz, w)
	var lh: = float(V10Type.line_h(sz))
	var l: = V10TowerUI.label(V10TowerUI.ui_text(text), "ui", sz, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.max_lines_visible = 2
	l.position = Vector2(cx + SHEET_MARGIN, y)
	l.size = Vector2(w, lh * n)
	panel.add_child(l)
	return y + lh * n + 6.0


# «?» — the rules in 3 lines with icons, and what the best attempt of the week brings (UX §4.1 p.9)
func _open_rules() -> void:
	if header and header.help_btn:
		V10TowerUI.tap(header.help_btn, "tap")
	var d: = _sheet_base("Как идёт забег")
	sheet_kind = "rules"
	var panel: Control = d.panel
	var y: float = d.y
	y = _row(panel, y, _icon_path, "%d стола и босс недели, каждую неделю новые" % (J.BOARDS - 1))
	y = _row(panel, y, _icon_heart, "%d сердца: лоток переполнен — минус сердце и тот же стол заново" % J.HEARTS)
	y = _row(panel, y, _icon_seal, "Попытка списывается при старте забега")
	y += 8.0
	y = _text(panel, y, "За лучшую попытку недели", 18, V10DS.GOLD_300)
	var bg: Array = U.econ("journey.boards_gems")
	var bn: = []
	var bv: = []
	for e in bg:
		bn.append(str(int(e[0])))
		bv.append(str(int(e[1])))
	y = _text(panel, y, "%s %s — %s кристаллов" % [" · ".join(bn), "столов", " · ".join(bv)], 22, V10DS.PAPER_100)
	var ts: Array = U.econ("journey.tier_score")
	var tg: Array = U.econ("journey.tier_gems")
	var tparts: = []
	for i in mini(ts.size(), J.TIERS.size()):
		tparts.append("%s %s" % [J.TIERS[i], SCROLL.fmt_num(int(ts[i]))])
	y = _text(panel, y, " · ".join(tparts), 22, V10DS.PAPER_100)
	var tgs: = []
	for v in tg:
		tgs.append(str(int(v)))
	y = _text(panel, y, "За ступень ещё %s кристаллов" % " · ".join(tgs), 18, V10DS.PAPER_300)
	var nt: = int(U.econ("journey.full_tickets"))
	y = _text(panel, y, "%d из %d — %s" % [J.BOARDS, J.BOARDS, "билет желания" if nt == 1 else "%d билета желания" % nt], 22, V10DS.PAPER_100)
	d.y = y
	_sheet_finish(d, "Понятно", close_sheet)


# «Таблица» — the week table: goddesses as AI rivals (always labelled) and the player; rewards never depend on it
func _open_table() -> void:
	if _busy:
		return
	V10TowerUI.tap(buttons.get("table"), "tap")
	var info: = J.week_info()
	var best: Dictionary = info.best
	var my_best: = int(best.get("score", 0))
	var d: = _sheet_base("Таблица недели", "Награды не зависят от места")
	sheet_kind = "table"
	var panel: Control = d.panel
	var y: float = d.y
	var rows: = TB.journey_week(int(info.week), my_best, U.now_utc())
	var ranked: = my_best > 0
	var place: = 0
	var me_row: = {}
	var shown: = 0
	for r in rows:
		if bool(r.me):
			me_row = r
			if not ranked:
				continue
		place += 1
		if shown >= 6:
			continue
		y = _table_row(panel, y, r, place)
		shown += 1
	if not ranked:
		var run: = J.current_run()
		var sub: = "Не в рейтинге — пройди 1 стол"
		if not run.is_empty() and int(run.get("board", 0)) > 0:
			sub = "Счёт попадёт в таблицу в конце забега"
		var mine: = me_row.duplicate()
		mine["sub"] = sub
		y = _table_row(panel, y, mine, 0)
	d.y = y - 8.0
	_sheet_finish(d, "Готово", close_sheet)


func _table_row(panel: Control, y: float, r: Dictionary, place: int) -> float:
	var me: = bool(r.get("me", false))
	var name_t: = "Ты" if me else V10TowerUI.ui_text(String(r.get("name", "")))
	var title: = ("%d · %s" % [place, name_t]) if place > 0 else name_t
	var sub: = String(r.get("sub", "")) if r.has("sub") else ("" if me else V10TowerUI.ui_text(String(r.get("ai_label", ""))))
	var p: = V10Plate.make("M", 672, title, sub)
	p.on_art = false
	p.selected = me
	if place > 0:
		var v: = V10TowerUI.label(SCROLL.fmt_num(int(r.get("score", 0))), "num", 22, V10DS.GOLD_300 if me else V10DS.PAPER_100)
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		v.custom_minimum_size = Vector2(120, 32)
		v.size = Vector2(120, 32)
		p.right_slot = v
	p.position = Vector2(cx + SHEET_MARGIN, y)
	panel.add_child(p)
	return y + 80.0 + 8.0


# ---------------------------------------------------------------- the result of a run (args.result)

func show_result(fin: Dictionary) -> void:
	# rewards are granted by the one who opens the window, once (CONTRACT: V10TowerUI.grant, then save_now)
	if not bool(fin.get("granted", false)) and not bool(fin.get("practice", false)):
		V10TowerUI.grant(fin.get("reward", {}), "journey")
		V10TowerUI.save_now()
	fin["granted"] = true
	# main keeps the args of this screen for «назад»: never show the same result twice
	set_meta("v8_args", {})
	args.erase("result")
	var S: = _sheets_script()
	if S != null:
		close_sheet(true)
		var w = S.call("journey_end", self, fin, _on_result_done)
		if w is Control:
			sheet = w
			sheet_kind = "result"
			# the result window is a full page of its own: the hub under it would only show through as noise
			_set_hub_visible(false)
			return
	_result_fallback(fin)


static func _script_has(s: Script, fn: String) -> bool:
	for m in s.get_script_method_list():
		if String(m.get("name", "")) == fn:
			return true
	return false


func _sheets_script() -> Script:
	if not ResourceLoader.exists(SHEETS_PATH):
		return null
	var s: = load(SHEETS_PATH) as Script
	if s == null or not s.can_instantiate() or not _script_has(s, "journey_end"):
		return null
	return s


func _on_result_done(_d = null) -> void:
	if sheet and is_instance_valid(sheet) and not sheet.is_queued_for_deletion():
		close_sheet()
	sheet = null
	sheet_kind = ""
	_set_hub_visible(true)
	_refresh()


# a plain result sheet while V10TowerSheets.journey_end (part C) is not in the build
func _result_fallback(fin: Dictionary) -> void:
	var boards: = int(fin.get("boards", 0))
	var practice: = bool(fin.get("practice", false))
	var title: = "Тренировка окончена" if practice else ("Странствие пройдено" if boards >= J.BOARDS else "Забег окончен")
	var d: = _sheet_base(title)
	sheet_kind = "result"
	var panel: Control = d.panel
	var y: float = d.y
	var sc: = int(fin.get("score", 0))
	y = _text(panel, y, "%d из %d столов · %s %s" % [boards, J.BOARDS, SCROLL.fmt_num(sc), U.plural(sc, "очко", "очка", "очков")], 22, V10DS.PAPER_100)
	var tn: = String(fin.get("tier_name", ""))
	if tn != "":
		y = _row(panel, y, _icon_seal, "Ступень: %s" % tn, V10DS.GOLD_300)
	if practice:
		y = _text(panel, y, "Тренировка без наград", 18, V10DS.PAPER_500)
	else:
		var toks: = V10TowerUI.reward_tokens(fin.get("reward", {}))
		if toks.is_empty():
			y = _text(panel, y, "Награда недели уже у тебя", 18, V10DS.PAPER_500)
		else:
			var parts: = []
			for t in toks:
				parts.append(_reward_text(String(t[0]), int(t[1])))
			y = _text(panel, y, "Награда недели: " + ", ".join(parts), 22, V10DS.GOLD_300)
		y = _text(panel, y, "Попыток осталось: %d из %d" % [J.attempts_left(), J.attempts_max()], 18, V10DS.PAPER_300)
	d.y = y
	_sheet_finish(d, "Готово", _on_result_done)


static func _reward_text(k: String, n: int) -> String:
	match k:
		"gems":
			return "+%d %s" % [n, U.plural(n, "кристалл", "кристалла", "кристаллов")]
		"coins":
			return "+%d %s" % [n, U.plural(n, "монета", "монеты", "монет")]
		"petals":
			return "+%d %s" % [n, U.plural(n, "лепесток", "лепестка", "лепестков")]
		"tickets":
			return "+%d %s" % [n, U.plural(n, "билет желания", "билета желания", "билетов желания")]
		"pass_xp":
			return "+%d опыта сезона" % n
	return "+%d" % n


# ---------------------------------------------------------------- sheet icons (48 px glyphs)

func _icon_path(ci: CanvasItem, sz: Vector2) -> void:
	var y: = sz.y * 0.5
	for i in 4:
		var c: = Vector2(5.0 + i * 9.0, y + (3.0 if i % 2 == 0 else -3.0))
		var rc: = Rect2(c - Vector2(3.5, 3.5), Vector2(7, 7))
		if i < 2:
			ci.draw_rect(rc, V10TowerUI.SEAL)
		else:
			ci.draw_rect(rc, Color(V10DS.PAPER_500, 0.9), false, 1.5)
	ci.draw_arc(Vector2(sz.x - 6.0, y), 6.0, 0.0, TAU, 20, V10DS.GOLD_500, 2.0, true)


func _icon_heart(ci: CanvasItem, sz: Vector2) -> void:
	V10TowerUI.draw_heart(ci, sz * 0.5, 34.0, true)


func _icon_seal(ci: CanvasItem, sz: Vector2) -> void:
	ci.draw_set_transform(sz * 0.5, deg_to_rad(-6.0), Vector2.ONE)
	V10TowerUI.draw_seal(ci, Vector2.ZERO, 15.0)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ---------------------------------------------------------------- the landscape (art or procedural)

func _build_bg() -> void:
	var tex: = V10TowerArt.tex("journey_far")
	if tex:
		# the painted road (720×1600): fit the width, put its horizon just under the scroll, never leave a gap
		var tr: = TextureRect.new()
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		var k: = maxf(vs.x / float(tex.get_width()), vs.y / float(tex.get_height()))
		var ts: = Vector2(tex.get_width(), tex.get_height()) * k
		var want: = float(metrics().scroll_bottom) + 36.0 - ART_HORIZON * ts.y
		tr.size = ts
		tr.position = Vector2((vs.x - ts.x) * 0.5, clampf(want, vs.y - ts.y, 0.0))
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.modulate = V10DS.TINT_HOME
		add_child(tr)
		_bg = tr
	else:
		_bg = V10TowerUI.glyph(_draw_land, vs)
		_bg.name = "Land"
		add_child(_bg)
	# a calm night tone under the bottom block (buttons read on any art)
	var M: = metrics()
	var sc: = V10TowerUI.glyph(func(ci: CanvasItem, sz: Vector2) -> void:
		var h0: float = float(M.info_top) - 110.0
		var hm: float = float(M.info_top) + 10.0
		var h1: float = float(M.sec_y) + 40.0
		var c0: = Color(V10DS.NIGHT_900, 0.0)
		var cm: = Color(V10DS.NIGHT_900, 0.55)
		var c1: = Color(V10DS.NIGHT_900, 0.8)
		var c2: = Color(V10DS.NIGHT_900, 0.92)
		ci.draw_polygon(PackedVector2Array([Vector2(0, h0), Vector2(sz.x, h0), Vector2(sz.x, hm), Vector2(0, hm)]),
			PackedColorArray([c0, c0, cm, cm]))
		ci.draw_polygon(PackedVector2Array([Vector2(0, hm), Vector2(sz.x, hm), Vector2(sz.x, h1), Vector2(0, h1)]),
			PackedColorArray([cm, cm, c1, c1]))
		ci.draw_polygon(PackedVector2Array([Vector2(0, h1), Vector2(sz.x, h1), Vector2(sz.x, sz.y), Vector2(0, sz.y)]),
			PackedColorArray([c1, c1, c2, c2])), vs)
	sc.name = "Scrim"
	add_child(sc)


func _ridge(ci: CanvasItem, sz: Vector2, base: float, amp: float, seed_v: int, col: Color, freq: = 1.0) -> PackedVector2Array:
	var r: = RandomNumberGenerator.new()
	r.seed = seed_v
	var ph: = [r.randf() * TAU, r.randf() * TAU, r.randf() * TAU]
	var pts: = PackedVector2Array()
	var n: = 48
	for i in n + 1:
		var x: = sz.x * float(i) / float(n)
		var u: = x / sz.x * TAU * freq
		var h: = sin(u * 1.0 + ph[0]) * 0.55 + sin(u * 2.3 + ph[1]) * 0.3 + absf(sin(u * 4.1 + ph[2])) * 0.25
		pts.append(Vector2(x, base - amp * h))
	var poly: = pts.duplicate()
	poly.append(Vector2(sz.x, sz.y))
	poly.append(Vector2(0, sz.y))
	ci.draw_colored_polygon(poly, col)
	return pts


func _band(ci: CanvasItem, sz: Vector2, y: float, h: float, col: Color) -> void:
	var c0: = Color(col, 0.0)
	ci.draw_polygon(PackedVector2Array([Vector2(0, y - h), Vector2(sz.x, y - h), Vector2(sz.x, y), Vector2(0, y)]), PackedColorArray([c0, c0, col, col]))
	ci.draw_polygon(PackedVector2Array([Vector2(0, y), Vector2(sz.x, y), Vector2(sz.x, y + h), Vector2(0, y + h)]), PackedColorArray([col, col, c0, c0]))


func _draw_land(ci: CanvasItem, sz: Vector2) -> void:
	var M: = metrics()
	var g0: float = M.scroll_bottom
	var g1: float = M.info_top
	var gap: = maxf(160.0, g1 - g0)
	var hz: = g0 + gap * 0.62  # the far ridge stands in the gap under the scroll
	# sky: night above, a dusk glow over the horizon (accents only as tints of DS tokens)
	var top: = V10DS.NIGHT_900
	var mid: = V10DS.NIGHT_700.lerp(V10DS.ROSE_700, 0.2)
	var low: = V10DS.NIGHT_600.lerp(V10DS.GOLD_700, 0.32)
	var y1: = hz - gap * 0.9
	ci.draw_rect(Rect2(0, 0, sz.x, maxf(0.0, y1)), top)
	ci.draw_polygon(PackedVector2Array([Vector2(0, y1), Vector2(sz.x, y1), Vector2(sz.x, hz - 40.0), Vector2(0, hz - 40.0)]), PackedColorArray([top, top, mid, mid]))
	ci.draw_polygon(PackedVector2Array([Vector2(0, hz - 40.0), Vector2(sz.x, hz - 40.0), Vector2(sz.x, hz + 30.0), Vector2(0, hz + 30.0)]), PackedColorArray([mid, mid, low, low]))
	ci.draw_rect(Rect2(0, hz + 30.0, sz.x, sz.y - hz - 30.0), low)
	# stars (sparse) and the moon, low over the hills
	var r: = RandomNumberGenerator.new()
	r.seed = 84
	for i in 60:
		var p: = Vector2(r.randf() * sz.x, r.randf() * (hz - 60.0))
		ci.draw_circle(p, r.randf_range(0.8, 1.7), Color(V10DS.PAPER_100, r.randf_range(0.10, 0.36)))
	var mc: = Vector2(sz.x * 0.78, g0 + gap * 0.3)
	for k in 7:
		ci.draw_circle(mc, 36.0 + k * 14.0, Color(V10TowerUI.MOON, 0.03))
	ci.draw_circle(mc, 30.0, Color(V10TowerUI.MOON, 0.92))
	ci.draw_circle(mc + Vector2(-8, -5), 22.0, Color(V10DS.PAPER_100, 0.18))
	# ridges from far to near with mist between them (aerial perspective)
	var far: = V10DS.NIGHT_600.lerp(V10DS.ROSE_700, 0.2)
	_ridge(ci, sz, hz, gap * 0.42, 11, far, 0.8)
	_band(ci, sz, hz + 8.0, 40.0, Color(V10DS.PAPER_300, 0.08))
	_ridge(ci, sz, hz + gap * 0.3, gap * 0.36, 23, V10DS.NIGHT_700.lerp(V10DS.ROSE_700, 0.1), 1.1)
	_band(ci, sz, hz + gap * 0.3 + 14.0, 34.0, Color(V10DS.PAPER_300, 0.06))
	_ridge(ci, sz, hz + gap * 0.62, gap * 0.26, 37, V10DS.NIGHT_800, 0.7)
	_band(ci, sz, hz + gap * 0.62 + 12.0, 30.0, Color(V10DS.PAPER_300, 0.04))
	_ridge(ci, sz, hz + gap * 1.05, gap * 0.2, 51, V10DS.NIGHT_900, 0.5)
	# the road: winding up from the foreground into the hills, fading with distance
	var road: = PackedVector2Array()
	var widths: = []
	var n: = 48
	for i in n + 1:
		var t: = float(i) / float(n)
		var y: = lerpf(sz.y + 10.0, hz + 18.0, pow(t, 0.75))
		var x: = sz.x * (0.56 + 0.2 * sin(t * 5.6 + 0.4) * (1.0 - t * 0.55))
		road.append(Vector2(x, y))
		widths.append(lerpf(110.0, 3.0, pow(t, 0.6)))
	for i in n:
		var a: Vector2 = road[i]
		var b: Vector2 = road[i + 1]
		var wa: float = widths[i] * 0.5
		var wb: float = widths[i + 1] * 0.5
		var al: = 0.13 * (1.0 - float(i) / float(n)) + 0.05
		ci.draw_colored_polygon(PackedVector2Array([a - Vector2(wa, 0), a + Vector2(wa, 0), b + Vector2(wb, 0), b - Vector2(wb, 0)]), Color(V10DS.PAPER_300, al))
