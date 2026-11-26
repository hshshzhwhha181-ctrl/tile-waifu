extends Control

# Пагода Луны — the hub (spec R2, UX_RULES §3.4 / §3.7, HUD_V2 §8.6). One scene, one main action:
#   header «‹ Пагода» + «Рекорды» (quiet, captioned) + «?» (quiet) · the tower (V10PagodaView, swipe to climb) ·
#   the Heat chip «Жар 12 · очки ×2,2» (secondary: opens the curse scroll) · the partner plate (secondary: heroine
#   picker, only when she has a choice) · «Подняться» (primary, 560×104, overline «ЭТАЖ 1 · ЖАР 12»).
# A run in progress: «Продолжить · этаж 7», the run's lanterns on the tower, the chip frozen («Жар выбран на
# старте»), «Завершить восхождение» (secondary) instead of the partner plate. Locked: the tower as a silhouette,
# «Откроется: …», main = «К столам». args.result (from tower_play) shows the run's result over the hub at once.
#
# Contract (ui/CONTRACT.md): build(m, args); m.go(id, args), m.back(), m.toast(text, icon).
# Sheets: one at a time, never a sheet over a sheet. Colours only V10DS / V10TowerUI; text via V10Type.

const SHEETS_PATH: = "res://scripts/v10/tower/ui/tower_sheets.gd"
const LOCK_TEXT: = "Откроется: на ранге Золото I или после первого Пика"
const NBSP: = "\u00a0"

var main = null
var args: = {}
var view: V10PagodaView
var header: V10Header
var shade: Control
var rec_btn: V10Button
var chip: V10Plate
var chip_fx: Control
var partner_plate: V10Plate
var end_btn: V10Button
var play: V10Button
var lock_l: Label
var sheet: Control = null  # the one open sheet (or the curse scroll)
var curses: = {}
var partner: = "mc"
var _vs: = Vector2(720, 1280)
var _T: = 0.0
var _B: = 0.0
var _cx: = 0.0
var _shown_heat: = 0
var _flash: = 0.0
var _flash_c: = V10DS.GOLD_300
var _quiet: = false  # a full-screen result sheet is up: the hub steps back, only the scene stays


func build(m, a: Dictionary) -> void:
	main = m
	args = a
	_vs = get_viewport_rect().size
	position = Vector2.ZERO
	size = _vs
	var ins: = V10TowerUI.insets(_vs)
	_T = float(ins.top)
	_B = float(ins.bottom)
	_cx = floorf(maxf(0.0, (_vs.x - 720.0) * 0.5))
	V10TowerUI.music("pagoda")
	curses = V10CurseScroll._sanitize(V10Pagoda.st().get("scroll", {}))
	partner = _pick_partner()
	_shown_heat = _heat()
	# the scene, then the shade under the action zone, then the interface
	view = V10PagodaView.new()
	add_child(view)
	shade = V10TowerUI.glyph(_draw_shade, _vs)
	add_child(shade)
	header = V10Header.make(self, "Пагода", _on_back, _open_rules)
	V10TowerUI.role(header.help_btn, "tertiary")
	rec_btn = V10Button.make("quiet", "", Vector2(80, 80))
	rec_btn.icon_color = V10DS.PAPER_300
	rec_btn.add_child(V10TowerUI.glyph(func(ci: CanvasItem, sz: Vector2) -> void:
		_draw_podium(ci, Vector2(40, 30), V10DS.PAPER_300), Vector2(80, 80)))
	var rec_cap: = V10TowerUI.label("Рекорды", "ui", 18, V10DS.PAPER_300)
	rec_cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rec_cap.position = Vector2(-8, 50)
	rec_cap.size = Vector2(96, 26)
	rec_btn.add_child(rec_cap)
	V10TowerUI.role(rec_btn, "tertiary")
	rec_btn.pressed.connect(func() -> void:
		_tap(rec_btn)
		_open_records())
	header.add_child(rec_btn)
	# the heat chip (M 328): ember + «Жар 12 · очки ×2,2» + «Свиток проклятий»
	chip = V10Plate.make("M", 328, V10Pagoda.heat_text(_shown_heat), "Свиток проклятий", "", "tw_heat")
	chip_fx = V10TowerUI.glyph(_draw_chip_flash, Vector2(328, 80))
	chip.add_child(chip_fx)
	chip.move_child(chip_fx, 0)
	chip.add_child(V10TowerUI.art_or("heat", Vector2(48, 48), func(ci: CanvasItem, sz: Vector2) -> void:
		V10TowerUI.draw_ember(ci, sz * 0.5, 40.0, V10TowerUI.heat_color(_shown_heat))))
	chip.get_child(chip.get_child_count() - 1).position = Vector2(24, 16)
	chip.pressed.connect(func() -> void:
		_tap(chip)
		_open_scroll())
	add_child(chip)
	# the partner plate (M 328): portrait + name + «Партнёр»
	partner_plate = V10Plate.make("M", 328, V10TowerUtil.hero_name(partner), "Партнёр", "", "tw_portrait")
	partner_plate.pressed.connect(func() -> void:
		_tap(partner_plate)
		_open_partner())
	add_child(partner_plate)
	end_btn = V10Button.make("secondary", "Завершить восхождение", Vector2(328, 80))
	end_btn.pressed.connect(func() -> void:
		_tap(end_btn)
		_open_end_confirm())
	add_child(end_btn)
	play = V10Button.make("play", "Подняться", Vector2(560, 104))
	V10TowerUI.role(play, "primary")
	play.pressed.connect(_on_play)
	add_child(play)
	lock_l = V10TowerUI.label(LOCK_TEXT, "ui", 22, V10DS.PAPER_300)
	lock_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lock_l.max_lines_visible = 2
	lock_l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	add_child(lock_l)
	_layout()
	_refresh(false)
	view.intro()
	_breathe_in()
	if args.has("result"):
		_show_result.call_deferred(args.result, args.get("new_cos", []))


func _on_back() -> void:
	if is_instance_valid(sheet):
		_close_sheet()
		return
	if main:
		main.back()


func _tap(n: CanvasItem, snd: = "pop") -> void:
	# V10Button / V10Plate run their own press spring; reset the scale so V9Feel's spring rests at 1
	n.scale = Vector2.ONE
	V10TowerUI.tap(n, snd)


func _heat() -> int:
	if V10Pagoda.has_run():
		return V10Pagoda.heat_chosen(V10Pagoda.current_run())
	return V10Mods.heat(curses)


func owned_heroines() -> Array:
	var out: = []
	for h in V10TowerUtil.owned():
		out.append(String(h))
	if out.is_empty():
		out.append("mc")
	return out


func _pick_partner() -> String:
	var own: = owned_heroines()
	var want: = String(G.S.get("level_partner", "mc"))
	return want if want in own else String(own[0])


# ---------------------------------------------------------------- layout and state

func _layout() -> void:
	var btn_y: = _vs.y - _B - 40.0 - 104.0
	var row_y: = btn_y - 26.0 - 24.0 - 80.0
	play.position = Vector2(_cx + 80.0, btn_y)
	chip.position = Vector2(_cx + 24.0, row_y)
	partner_plate.position = Vector2(_cx + 368.0, row_y)
	end_btn.position = Vector2(_cx + 368.0, row_y)
	lock_l.position = Vector2(_cx + 32.0, row_y - 4.0)
	lock_l.size = Vector2(656.0, 84.0)
	rec_btn.position = Vector2(_cx + 552.0, _T + 4.0)
	view.set_frame(_T + V10Header.HEIGHT, row_y - 24.0)


func _refresh(animate: bool) -> void:
	var open: = V10Pagoda.is_open()
	var has_run: = open and V10Pagoda.has_run()
	var run: Dictionary = V10Pagoda.current_run() if has_run else {}
	var h: = _heat()
	var own: = owned_heroines()
	chip.visible = open
	rec_btn.visible = open
	lock_l.visible = not open
	partner_plate.visible = open and not has_run
	end_btn.visible = has_run
	# roles: only what can be tapped carries one
	chip.interactive = open and not has_run
	V10TowerUI.role(chip, "secondary" if chip.interactive else "info")
	partner_plate.interactive = partner_plate.visible and own.size() > 1
	V10TowerUI.role(partner_plate, "secondary" if partner_plate.interactive else "info")
	V10TowerUI.role(end_btn, "secondary")
	chip.subtitle = "Жар выбран на старте" if has_run else "Свиток проклятий"
	partner_plate.title = V10TowerUtil.hero_name(partner)
	_set_portrait(partner_plate, partner)
	if not open:
		play.text = "К столам"
		play.overline = ""
	elif has_run:
		play.text = "Продолжить · этаж %d" % int(run.floor)
		play.overline = "Восхождение · Жар %d" % h
	else:
		play.text = "Подняться"
		play.overline = "Этаж 1 · Жар %d" % h
	_roll_chip(h, animate)
	# the scene
	if not open:
		view.configure({"locked": true, "lit_to": 0, "record_floor": 0, "run_floor": 0, "heat": 0})
	elif has_run:
		var lv: = V10Mods.resolve(run)
		view.configure({"locked": false, "lit_to": int(run.get("cleared", 0)), "record_floor": V10Pagoda.best_for_heat(h),
			"run_floor": int(run.floor), "lives": int(run.lives), "lives_max": int(lv.lives_max), "heat": h})
	elif animate:
		view.set_heat(h)
		view.configure({"locked": false, "run_floor": 0})
		view.set_lit(V10Pagoda.best_for_heat(h), V10Pagoda.best_for_heat(h), true)
		view.scroll_to_floor(view.focus_floor(), true)
	else:
		var best: = V10Pagoda.best_for_heat(h)
		view.configure({"locked": false, "lit_to": best, "record_floor": best, "run_floor": 0, "heat": h})
	if _quiet:
		for n in _hub_nodes():
			(n as CanvasItem).visible = false


func _hub_nodes() -> Array:
	return [header, shade, chip, partner_plate, end_btn, play, lock_l]


# part C's result sheet is a full-screen overlay with a see-through backdrop: while it is up the hub hides its
# interface (nothing ghosts through, nothing is tappable under it); on «К Пагоде» the hub breathes back in
func _set_quiet(on: bool, animate: = true) -> void:
	_quiet = on
	view.set_markers(not on)
	if on:
		for n in _hub_nodes():
			(n as CanvasItem).visible = false
		return
	header.visible = true
	shade.visible = true
	play.visible = true
	_refresh(animate)
	if animate:
		_breathe_in()


# the chip rolls its number (320 ms EXPO OUT, ±1 = 120 ms) and flashes softly in the heat colour (never white)
func _roll_chip(h: int, animate: bool) -> void:
	var from: = _shown_heat
	_shown_heat = h
	if from == h or not animate or V10TowerUI.calm():
		chip.title = V10Pagoda.heat_text(h)
		chip_fx.queue_redraw()
		_redraw_chip_icon()
		return
	var tw: = create_tween()
	tw.tween_method(func(v: float) -> void:
		chip.title = V10Pagoda.heat_text(int(round(v))), float(from), float(h), 0.32 if absi(h - from) > 1 else 0.12).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_flash_c = V10TowerUI.heat_color(h)
	_flash = 1.0
	var tf: = create_tween()
	tf.tween_method(func(v: float) -> void:
		_flash = v
		chip_fx.queue_redraw(), 1.0, 0.0, 0.6).set_trans(Tween.TRANS_SINE)
	_redraw_chip_icon()
	chip.ping()


func _redraw_chip_icon() -> void:
	for c in chip.get_children():
		if c is Control:
			(c as Control).queue_redraw()


func _draw_chip_flash(ci: CanvasItem, sz: Vector2) -> void:
	if _flash <= 0.0:
		return
	var sb: = StyleBoxFlat.new()
	sb.bg_color = Color(_flash_c, 0.24 * _flash)
	sb.set_corner_radius_all(V10DS.RADIUS)
	ci.draw_style_box(sb, Rect2(Vector2.ZERO, sz))


func _draw_shade(ci: CanvasItem, sz: Vector2) -> void:
	# night.900 under the action zone only (0 → 85 %), the scene stays clear above it
	var y0: = chip.position.y - 120.0
	var y1: = chip.position.y + 24.0
	var c0: = Color(V10DS.NIGHT_900, 0.0)
	var c1: = Color(V10DS.NIGHT_900, 0.85)
	ci.draw_polygon(PackedVector2Array([Vector2(0, y0), Vector2(sz.x, y0), Vector2(sz.x, y1), Vector2(0, y1)]),
			PackedColorArray([c0, c0, c1, c1]))
	ci.draw_rect(Rect2(0, y1, sz.x, sz.y - y1), c1)


# «Вдох»: ≤ 5 elements, 240 ms, 40 ms step, +12 px and fade (fx min: a 120 ms fade)
func _breathe_in() -> void:
	var items: = [chip, partner_plate if partner_plate.visible else end_btn, lock_l, play]
	var i: = 0
	for n in items:
		if not (n as CanvasItem).visible:
			continue
		var c: = n as Control
		c.modulate.a = 0.0
		var tw: = c.create_tween()
		if V10TowerUI.calm():
			tw.tween_property(c, "modulate:a", 1.0, 0.12)
		else:
			var y: = c.position.y
			c.position.y = y + 12.0
			tw.tween_interval(0.04 * i)
			tw.tween_property(c, "position:y", y, 0.24).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(c, "modulate:a", 1.0, 0.24)
		i += 1


# ---------------------------------------------------------------- portraits and glyphs

func _set_portrait(p: V10Plate, h: String) -> void:
	for c in p.get_children():
		if c.has_meta("tw_portrait"):
			if String(c.get_meta("tw_portrait")) == h:
				return
			c.queue_free()
	var pic: = portrait(h, 48.0)
	pic.position = Vector2(24, 16)
	pic.set_meta("tw_portrait", h)
	p.add_child(pic)


# a round heroine portrait (the base art, focus on her face), 1 px gold.700 ring; falls back to the ring icon
static func portrait(h: String, d: float) -> Control:
	var path: = "res://assets/hero/%s.png" % h
	var root: = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.size = Vector2(d, d)
	if ResourceLoader.exists(path):
		var t: Texture2D = load(path)
		var art: = Common.card_art(t, Rect2(Vector2.ZERO, Vector2(d, d)), Hero.av_focus(h), Hero.av_zoom(h), d * 0.5)
		(art.material as ShaderMaterial).set_shader_parameter("bottom_shade", 0.0)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(art)
	else:
		root.add_child(V10Icons.icon("avatar_ring", int(d), V10DS.PAPER_500))
	root.add_child(V10TowerUI.glyph(func(ci: CanvasItem, sz: Vector2) -> void:
		ci.draw_arc(sz * 0.5, sz.x * 0.5 - 0.5, 0.0, TAU, 48, Color(V10DS.GOLD_700, 0.7), 1.0, true), Vector2(d, d)))
	return root


# the «Рекорды» sign: a three-step podium, monoline 2.5 (HUD_V2 §4), with a caption under it (UX §6.4)
static func _draw_podium(ci: CanvasItem, c: Vector2, col: Color) -> void:
	var w: = 2.5
	var base: = c.y + 13.0
	var pts: = PackedVector2Array([Vector2(c.x - 18, base), Vector2(c.x - 18, c.y + 1), Vector2(c.x - 6, c.y + 1),
		Vector2(c.x - 6, c.y - 9), Vector2(c.x + 6, c.y - 9), Vector2(c.x + 6, c.y + 5), Vector2(c.x + 18, c.y + 5),
		Vector2(c.x + 18, base), Vector2(c.x - 18, base)])
	ci.draw_polyline(pts, col, w, true)
	ci.draw_line(Vector2(c.x - 6, c.y + 1), Vector2(c.x - 6, base), col, w, true)
	ci.draw_line(Vector2(c.x + 6, c.y + 5), Vector2(c.x + 6, base), col, w, true)


# ---------------------------------------------------------------- the main action

func _on_play() -> void:
	if not V10Pagoda.is_open():
		_tap(play)
		if main:
			main.back()
		return
	if V10Pagoda.has_run():
		_tap(play, "pop")
		V10TowerUI.sfx("gong")
		main.go("tower_play", {"mode": "pagoda", "run": V10Pagoda.current_run()})
		return
	start_run()


func start_run() -> void:
	var run: = V10Pagoda.new_run(partner, curses)
	if run.has("error"):
		V10TowerUI.deny(play)
		if main:
			main.toast(V10TowerUI.ui_text(String(run.error)), "")
		return
	V10Pagoda.st()["scroll"] = curses.duplicate()
	V10TowerUI.save_now()
	_tap(play, "")
	V10TowerUI.sfx("gong")
	main.go("tower_play", {"mode": "pagoda", "run": run})


# ---------------------------------------------------------------- the curse scroll

func _open_scroll() -> void:
	if not chip.interactive:
		return
	_close_sheet(true)
	var s: = V10CurseScroll.open(self, curses, func(c: Dictionary) -> void:
		curses = c
		V10Pagoda.st()["scroll"] = c.duplicate()
		V10TowerUI.save_now()
		_refresh(true))
	sheet = s


# ---------------------------------------------------------------- sheets (one at a time, over the screen only)

func _close_sheet(instant: = false) -> void:
	if not is_instance_valid(sheet):
		sheet = null
		return
	var s: = sheet
	sheet = null
	if s is V10CurseScroll:
		if instant:
			s.queue_free()
		else:
			(s as V10CurseScroll).close(true)
	elif s.has_method("close"):
		s.call("close", instant)
	elif s.has_method("finish") and not instant:
		# part C's sheet (no close()): back = «К Пагоде», it calls on_done, fades and frees itself
		sheet = s
		s.call("finish", {"action": "hub"})
		if sheet == s:
			sheet = null
	else:
		s.queue_free()
		if _quiet:
			_set_quiet(false, false)


func _new_sheet(h: float) -> _Sheet:
	_close_sheet(true)
	var s: = _Sheet.new()
	s.setup(_vs, minf(h, _vs.y - _T - V10Header.HEIGHT), _B)
	add_child(s)
	sheet = s
	return s


func _sheet_title(s: _Sheet, text: String) -> float:
	var t: = V10TowerUI.label(text, "display", 44, V10DS.PAPER_100)
	t.position = Vector2(_cx + 24.0, 28.0)
	t.size = Vector2(672.0, 56.0)
	s.panel.add_child(t)
	return 96.0


func _sheet_button(s: _Sheet, kind: String, text: String, w: float, x: float, y: float, cb: Callable, r: String) -> V10Button:
	var b: = V10Button.make(kind, text, Vector2(w, 104.0 if kind == "play" else 80.0))
	b.position = Vector2(x, y)
	V10TowerUI.role(b, r)
	b.pressed.connect(func() -> void:
		_tap(b)
		cb.call())
	s.panel.add_child(b)
	return b


# «?»: three lines with icons (UX §4.1 p.9), no «Подробнее»
func _open_rules() -> void:
	_tap(header.help_btn)
	var lines: = [
		["lantern", "Три фонаря. Переполненный лоток гасит один, этаж продолжается."],
		["seal", "Каждый пятый этаж стережёт Страж. Победа — сундук и фонарь."],
		["ember", "Проклятия дают Жар, Жар умножает очки: Жар 10 — очки ×2."],
	]
	var row_h: = 88.0
	var h: = 96.0 + lines.size() * row_h + 24.0 + 104.0 + 40.0
	var s: = _new_sheet(h)
	var y: = _sheet_title(s, "Правила")
	for ln in lines:
		var g: = V10TowerUI.glyph(_draw_rule_icon.bind(String(ln[0])), Vector2(48, 48))
		g.position = Vector2(_cx + 24.0, y + (row_h - 48.0) * 0.5)
		s.panel.add_child(g)
		var l: = V10TowerUI.label(String(ln[1]), "ui", 22, V10DS.PAPER_100)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.max_lines_visible = 2
		l.position = Vector2(_cx + 88.0, y)
		l.size = Vector2(608.0, row_h)
		s.panel.add_child(l)
		y += row_h
	_sheet_button(s, "play", "Понятно", 560.0, _cx + 80.0, s.panel_h - _B - 40.0 - 104.0, func() -> void: _close_sheet(), "primary")
	s.open()


# the partner: owned heroines only; a tap makes her the partner (saved to G.S.level_partner)
func _open_partner() -> void:
	if not partner_plate.interactive:
		return
	var own: = owned_heroines()
	var h: = 96.0 + 40.0 + own.size() * 88.0 + 24.0 + 104.0 + 40.0
	var s: = _new_sheet(h)
	var y: = _sheet_title(s, "Партнёр")
	var cap: = V10TowerUI.label("Её Приём с тобой на каждом этаже", "ui", 18, V10DS.PAPER_500)
	cap.position = Vector2(_cx + 24.0, y - 6.0)
	cap.size = Vector2(672.0, 26.0)
	s.panel.add_child(cap)
	y += 40.0
	var plates: = []
	for hid in own:
		var p: = V10Plate.make("M", 672, V10TowerUtil.hero_name(hid), _hero_line(hid), "", "tw_portrait")
		p.on_art = false
		p.interactive = true
		p.selected = hid == partner
		p.position = Vector2(_cx + 24.0, y)
		_set_portrait(p, hid)
		s.panel.add_child(p)
		plates.append(p)
		p.pressed.connect(func() -> void:
			_tap(p)
			partner = hid
			G.S["level_partner"] = hid
			V10TowerUI.save_now()
			for q in plates:
				(q as V10Plate).selected = q == p
			_refresh(false))
		y += 88.0
	_sheet_button(s, "play", "Готово", 560.0, _cx + 80.0, s.panel_h - _B - 40.0 - 104.0, func() -> void: _close_sheet(), "primary")
	s.open()


static func _draw_rule_icon(ci: CanvasItem, sz: Vector2, kind: String) -> void:
	var c: = sz * 0.5
	match kind:
		"lantern":
			V10TowerUI.draw_lantern(ci, c + Vector2(0, 4), 40.0, 1.0)
		"seal":
			V10TowerUI.draw_seal(ci, c, 17.0)
		_:
			V10TowerUI.draw_ember(ci, c, 38.0)


func _hero_line(h: String) -> String:
	if G.HEROES.has(h):
		return String(G.HEROES[h].get("title", "")).split(",")[0]
	return ""


# «Завершить восхождение» → one sentence + «Завершить» / «Отмена»
func _open_end_confirm() -> void:
	var h: = 96.0 + 72.0 + 24.0 + 104.0 + 40.0
	var s: = _new_sheet(h)
	var y: = _sheet_title(s, "Завершить восхождение?")
	var l: = V10TowerUI.label("Этажи этого забега уйдут в рекорд, а фонари погаснут.", "ui", 22, V10DS.PAPER_300)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.max_lines_visible = 2
	l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	l.position = Vector2(_cx + 24.0, y)
	l.size = Vector2(672.0, 64.0)
	s.panel.add_child(l)
	var by: = s.panel_h - _B - 40.0 - 104.0
	_sheet_button(s, "secondary", "Отмена", 200.0, _cx + 24.0, by + 12.0, func() -> void: _close_sheet(), "secondary")
	_sheet_button(s, "play", "Завершить", 440.0, _cx + 256.0, by, func() -> void:
		_close_sheet(true)
		end_run_now(), "primary")
	s.open()


func end_run_now() -> void:
	if not V10Pagoda.has_run():
		return
	var res: = V10Pagoda.end_run(V10Pagoda.current_run())
	V10TowerUI.save_now()
	_refresh(true)
	_show_result(res, [])


# ---------------------------------------------------------------- the result of a run (part C's sheet, else ours)

func _sheets_script() -> GDScript:
	if not ResourceLoader.exists(SHEETS_PATH):
		return null
	var s = load(SHEETS_PATH)
	if not (s is GDScript) or not (s as GDScript).can_instantiate():
		return null
	for mm in (s as GDScript).get_script_method_list():
		if String(mm.get("name", "")) == "pagoda_end":
			return s
	return null


func _show_result(res: Dictionary, new_cos: Array) -> void:
	_close_sheet(true)
	_refresh(false)
	var on_done: = func(d: Dictionary) -> void:
		match String(d.get("action", "hub")):
			"again":
				_close_sheet(true)
				if _quiet:
					_set_quiet(false, false)
				start_run()
			_:
				var was_quiet: = _quiet
				_quiet = false
				_close_sheet()
				if was_quiet:
					_set_quiet(false)
				else:
					_refresh(true)
	var S: = _sheets_script()
	if S:
		var n = S.call("pagoda_end", self, res, new_cos, on_done)
		if n is Control:
			sheet = n
			_set_quiet(true)
		return
	_result_fallback(res, on_done)


func _result_fallback(res: Dictionary, on_done: Callable) -> void:
	var h: = 96.0 + 56.0 + 40.0 + 24.0 + 104.0 + 24.0 + 80.0 + 24.0
	var s: = _new_sheet(h)
	var y: = _sheet_title(s, "Восхождение окончено")
	var floors: = int(res.get("floors", 0))
	var line: = "%d %s × %s = %s" % [floors, V10TowerUtil.plural(floors, "этаж", "этажа", "этажей"),
		V10TowerUtil.fmt_mult(float(res.get("mult", 1.0))).trim_prefix("×"), fmt_int(int(res.get("score", 0)))]
	var big: = V10TowerUI.label(line, "num", 40, V10DS.GOLD_300)
	big.position = Vector2(_cx + 24.0, y)
	big.size = Vector2(672.0, 48.0)
	s.panel.add_child(big)
	y += 52.0
	var note: = ""
	if bool(res.get("record_score", false)):
		note = "Новый рекорд Пагоды"
	elif bool(res.get("record_heat", false)):
		note = "Рекорд при Жаре %d" % int(res.get("heat", 0))
	if note != "":
		var nl: = V10TowerUI.label(note, "ui", 22, V10DS.PAPER_300)
		nl.position = Vector2(_cx + 24.0, y)
		nl.size = Vector2(672.0, 32.0)
		s.panel.add_child(nl)
	var by: = s.panel_h - _B - 32.0 - 80.0 - 16.0 - 104.0
	_sheet_button(s, "play", "Новое восхождение", 560.0, _cx + 80.0, by, func() -> void: on_done.call({"action": "again"}), "primary")
	_sheet_button(s, "secondary", "К Пагоде", 240.0, _cx + 240.0, by + 104.0 + 16.0, func() -> void: on_done.call({"action": "hub"}), "secondary")
	s.open()


static func fmt_int(n: int) -> String:
	var s: = str(absi(n))
	var out: = ""
	while s.length() > 3:
		out = NBSP + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


# ---------------------------------------------------------------- «Рекорды»: Неделя / Героини

var _rec_tab: = "week"


func _open_records(tab: = "") -> void:
	if tab != "":
		_rec_tab = tab
	var s: = _new_sheet(_vs.y - _T - V10Header.HEIGHT)
	var y: = _sheet_title(s, "Рекорды")
	var seg: = _Seg.new()
	seg.items = [["week", "Неделя"], ["heroines", "Героини"]]
	seg.current = _rec_tab
	seg.position = Vector2(_cx + 24.0, y)
	seg.size = Vector2(336.0, 80.0)
	seg.picked.connect(func(id: String) -> void:
		_rec_tab = id
		_fill_records(s))
	s.panel.add_child(seg)
	s.set_meta("seg", seg)
	_fill_records(s)
	_sheet_button(s, "play", "Готово", 560.0, _cx + 80.0, s.panel_h - _B - 40.0 - 104.0, func() -> void: _close_sheet(), "primary")
	s.open()


func _fill_records(s: _Sheet) -> void:
	if s.has_meta("body"):
		var old = s.get_meta("body")
		if old is Node and is_instance_valid(old):
			(old as Node).queue_free()
	var body: = Control.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.position = Vector2(_cx + 24.0, 96.0 + 88.0)
	var bottom: = s.panel_h - _B - 40.0 - 104.0 - 24.0
	body.size = Vector2(672.0, bottom - body.position.y)
	s.panel.add_child(body)
	s.set_meta("body", body)
	var cap: = V10TowerUI.label("", "ui", 18, V10DS.PAPER_500)
	cap.position = Vector2(0, 0)
	cap.size = Vector2(672.0, 26.0)
	body.add_child(cap)
	var sc: = ScrollContainer.new()
	sc.position = Vector2(0, 40)
	sc.size = Vector2(672.0, body.size.y - 40.0)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	body.add_child(sc)
	var box: = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.custom_minimum_size = Vector2(672.0, 0)
	sc.add_child(box)
	if _rec_tab == "heroines":
		cap.text = V10TowerBoard.HEROINE_LABEL
		var rank: = 0
		for r in V10TowerBoard.heroine_records():
			rank += 1
			var p: = V10Plate.make("M", 672, String(r.name), "этаж %d · Жар %d" % [int(r.floors_heat), int(r.heat)],
				fmt_int(int(r.score)), "tw_portrait")
			p.on_art = false
			_set_portrait(p, String(r.hero))
			box.add_child(p)
		return
	var rows: = V10TowerBoard.pagoda_week()
	var me: Dictionary = {}
	for r in rows:
		if bool(r.me):
			me = r
	var ranked: = int(me.get("floors", 0)) > 0
	if ranked:
		cap.text = "Твоё место — %d из %d · обновится %s" % [V10TowerBoard.place_of(rows), rows.size(),
			V10TowerUtil.week_refresh_text(V10TowerUtil.cur_week())]
	else:
		cap.text = "Не в рейтинге — пройди 1 этаж"
	var place: = 0
	for r in rows:
		if bool(r.me) and not ranked:
			continue
		place += 1
		var p: = V10Plate.make("M", 672, String(r.name), "этаж %d · Жар %d" % [int(r.floors), int(r.heat)],
			fmt_int(int(r.score)), "tw_rank")
		p.on_art = false
		p.selected = bool(r.me)
		var n: = V10TowerUI.label(str(place), "ui", 22, V10DS.GOLD_300 if bool(r.me) else V10DS.PAPER_500)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		n.position = Vector2(24, 24)
		n.size = Vector2(48, 32)
		p.add_child(n)
		box.add_child(p)


# ---------------------------------------------------------------- a bottom sheet («Шёлк» 220 ms QUINT OUT)

class _Sheet extends Control:
	signal closed
	var panel: Control
	var panel_h: = 600.0
	var _vs: = Vector2(720, 1280)
	var _closing: = false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		set_meta("tw_surface", true)
		set_meta("tw_sheet", true)

	func setup(vs: Vector2, h: float, _b: float) -> void:
		_vs = vs
		panel_h = h
		size = vs
		panel = _Panel.new()
		panel.size = Vector2(vs.x, h)
		panel.position = Vector2(0, vs.y - h)
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(panel)

	func open() -> void:
		if V10TowerUI.calm():
			modulate.a = 0.0
			create_tween().tween_property(self, "modulate:a", 1.0, 0.12)
			return
		panel.position.y = _vs.y
		var tw: = create_tween()
		tw.tween_property(panel, "position:y", _vs.y - panel_h, 0.22).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		modulate.a = 0.0
		tw.parallel().tween_property(self, "modulate:a", 1.0, 0.16)

	func close(instant: = false) -> void:
		if _closing:
			return
		_closing = true
		if instant or V10TowerUI.calm() or not is_inside_tree():
			closed.emit()
			queue_free()
			return
		var tw: = create_tween()
		tw.tween_property(panel, "position:y", _vs.y, 0.16).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(self, "modulate:a", 0.0, 0.16)
		tw.tween_callback(func() -> void:
			closed.emit()
			queue_free())

	func _gui_input(e: InputEvent) -> void:
		accept_event()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, _vs), Color(V10DS.NIGHT_900, 0.62))


class _Panel extends Control:
	func _draw() -> void:
		V10Plate.draw_surface(self, Rect2(Vector2.ZERO, size + Vector2(0, 8)), false, false, false, false, false, -1.0, V10DS.NIGHT_700)


# a two-cell segment (one control, UX §3.4): the chosen cell in gold.300 with a gold underline
class _Seg extends Control:
	signal picked(id: String)
	var items: Array = []
	var current: = ""
	var _cells: = []

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var w: = size.x / float(items.size())
		for i in items.size():
			var c: = Control.new()
			c.position = Vector2(w * i, 0)
			c.size = Vector2(w, size.y)
			c.mouse_filter = Control.MOUSE_FILTER_STOP
			c.set_meta("tw_tap", true)
			var l: = V10TowerUI.label(String(items[i][1]), "ui", 22, V10DS.PAPER_300)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.size = c.size
			c.add_child(l)
			var id: String = items[i][0]
			c.gui_input.connect(func(e: InputEvent) -> void:
				if ((e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT) or e is InputEventScreenTouch) and not e.pressed:
					press(id))
			add_child(c)
			_cells.append([id, c, l])
		_sync()

	func press(id: String) -> void:
		if id == current:
			return
		current = id
		for it in _cells:
			if it[0] == id:
				var n: Control = it[1]
				n.scale = Vector2.ONE
				V10TowerUI.tap(n, "pop")
		_sync()
		picked.emit(id)

	func _sync() -> void:
		for it in _cells:
			var on: bool = it[0] == current
			(it[2] as Label).label_settings = V10Type.settings("ui", 22, V10DS.GOLD_300 if on else V10DS.PAPER_500)
		queue_redraw()

	func _draw() -> void:
		var w: = size.x / float(maxi(1, items.size()))
		for i in items.size():
			var on: bool = items[i][0] == current
			var x0: = w * i + 24.0
			var x1: = w * (i + 1) - 24.0
			draw_line(Vector2(x0, size.y - 14.0), Vector2(x1, size.y - 14.0), V10DS.GOLD_500 if on else Color(V10DS.GOLD_700, 0.35), 2.0 if on else 1.0)
