class_name V10TowerSheets
extends RefCounted

# V10TowerSheets — the result sheets of the tower (Пагода Луны, Странствие): one sheet over the screen (the board
# or the hub), never a window over a window: the card fan is the second beat of the SAME sheet (embedded).
# UX §9 P0-3 / HUD_V2 §8.3: three beats (header → ≤ 3 reward tokens cascading 80 ms with a rising pentatonic note
# → ≤ 2 plates), buttons on fixed places (primary 560×104 at H−B−216, secondary 560×80 at H−B−104) from the end
# of beat 1 to the exit, exactly one primary at any moment, no white flash, no confetti, fx «min» = 120 ms fades.
#
#   V10TowerSheets.floor_clear(parent, run, res, on_done)       res = V10Pagoda.floor_clear(run, …)
#   V10TowerSheets.board_clear(parent, run, res, on_done)       res = V10Journey.board_clear(run, …)
#   V10TowerSheets.pagoda_end(parent, end_res, new_cos, on_done) end_res = V10Pagoda.end_run(run)
#   V10TowerSheets.journey_end(parent, fin, on_done)            fin = V10Journey.finish(run)
#   V10TowerSheets.heat_flare(parent, card)                     «Пагода разгорается» (curse_card dict)
#
# Each sheet applies the player's pick itself (V10Pagoda.pick_blessing / V10Journey.pick_blessing / take_curse),
# saves (V10TowerUI.save_now, unless autosave = false in tests) and ends with on_done.call({action: …}).
# Rewards are NOT credited here: whoever opens the sheet grants res.reward before showing it.

const UI: = preload("res://scripts/v10/tower/ui/tower_ui.gd")
const FAN: = preload("res://scripts/v10/tower/ui/card_fan.gd")

static var autosave: = true  # demo / selftest: false (picks are not written to the real save)

const PENTA: = [1.0, 1.125, 1.25, 1.5, 1.667, 2.0]  # a rising pentatonic step per reward token
const ICON: = {"gems": "res://assets/v08/ui/cur/gem.png", "coins": "res://assets/v08/ui/cur/coin.png",
	"tickets": "res://assets/v08/ui/cur/ticket.png", "petals": "res://assets/fx/petal.png",
	"pass_xp": "res://assets/v09/summon/lantern_r.png"}
const COS_KIND: = {"frame": "Рамка", "title": "Титул", "tile_edge": "Окантовка"}


# ---------------------------------------------------------------- public API

static func floor_clear(parent: Control, run: Dictionary, res: Dictionary, on_done: Callable) -> Control:
	var s: = Sheet.new()
	s.kind = "floor_clear"
	s.run = run
	s.res = res
	s.on_done = on_done
	parent.add_child(s)
	return s


static func board_clear(parent: Control, run: Dictionary, res: Dictionary, on_done: Callable) -> Control:
	var s: = Sheet.new()
	s.kind = "board_clear"
	s.run = run
	s.res = res
	s.on_done = on_done
	parent.add_child(s)
	return s


static func pagoda_end(parent: Control, end_res: Dictionary, new_cos: Array, on_done: Callable) -> Control:
	var s: = Sheet.new()
	s.kind = "pagoda_end"
	s.res = end_res
	s.cos = new_cos
	s.on_done = on_done
	parent.add_child(s)
	return s


static func journey_end(parent: Control, fin: Dictionary, on_done: Callable) -> Control:
	var s: = Sheet.new()
	s.kind = "journey_end"
	s.res = fin
	s.on_done = on_done
	parent.add_child(s)
	return s


# «вспыхнул Жар»: the tower's curse card flares in the heat colour (≤ 3 flares a second, no white), the heat sound,
# then the overlay leaves by itself. Not a window: no buttons, never takes a tap.
static func heat_flare(parent: Control, card: Dictionary) -> void:
	flare_node(parent, card)


static func flare_node(parent: Control, card: Dictionary) -> Control:
	var f: = Flare.new()
	f.card = card
	parent.add_child(f)
	return f


# ---------------------------------------------------------------- text helpers

static func num(n: int) -> String:
	return V10TowerUI.num(n)


static func pl(n: int, one: String, few: String, many: String) -> String:
	return V10TowerUI.plural(n, [one, few, many])


# the text under the baseline of a bigger one on the same line («15 этажей × 2,6 =» + «3 900»)
static func baseline_dy(role_big: String, size_big: int, role_small: String, size_small: int) -> float:
	return V10Type.font(role_big).get_ascent(size_big) - V10Type.font(role_small).get_ascent(size_small)


static func cos_def(id: String) -> Dictionary:
	for c in V10Pagoda.COS:
		if String(c.id) == id:
			return c
	return {"id": id, "kind": "frame", "name": id}


static func cos_title(id: String) -> String:
	var c: = cos_def(id)
	return "%s «%s»" % [String(COS_KIND.get(String(c.kind), "Косметика")), String(c.name)]


# ---------------------------------------------------------------- the sheet

class Sheet:
	extends Control

	var kind: = ""
	var run: Dictionary = {}
	var res: Dictionary = {}
	var cos: Array = []
	var on_done: Callable
	var L: Dictionary = {}
	var backdrop: Control
	var content: Control
	var prim: V10Button
	var sec: V10Button
	var fan: V10TowerFan
	var y: = 0.0
	var tokens: Array = []
	var lives_w: = 0.0  # the lanterns / hearts on the right of the header
	var plates: Array = []
	var closing: = false
	var result: Dictionary = {}
	var _beat1: Array = []  # ≤ 5 elements «вдох»

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		set_meta("tower_sheet", true)

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var vs: = get_viewport_rect().size
		var ins: = V10TowerUI.insets(vs)
		var cx: = floorf(maxf(0.0, (vs.x - 720.0) * 0.5))
		L = {"vs": vs, "cx": cx, "T": float(ins.get("top", 0.0)), "B": float(ins.get("bottom", 0.0)),
			"play": Rect2(cx + 80, vs.y - float(ins.get("bottom", 0.0)) - 216, 560, 104),
			"second": Rect2(cx + 80, vs.y - float(ins.get("bottom", 0.0)) - 104, 560, 80)}
		set_meta("kind", kind)
		backdrop = V10TowerSheets._Backdrop.new()
		add_child(backdrop)
		content = Control.new()
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.size = vs
		add_child(content)
		_fade(backdrop, 0.0, 0.22)
		match kind:
			"floor_clear":
				_floor_clear()
			"board_clear":
				_board_clear()
			"pagoda_end":
				_pagoda_end()
			"journey_end":
				_journey_end()
		_breathe_in()

	# ------------------------------------------------------------ building blocks

	func _x() -> float:
		return float(L.cx) + 32.0

	func _label(text: String, role: String, sz: int, col: Color, at: Vector2, w: = 656.0, h: = -1.0) -> Label:
		var l: = V10TowerUI.label(text, role, sz, col)
		l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		l.position = at
		l.size = Vector2(w, h if h > 0.0 else V10TowerFan.box_h(role, sz, 1))
		content.add_child(l)
		return l

	func head(over: String, title: String, cap: String) -> void:
		y = float(L.T) + 48.0
		var o: = _label(over.to_upper(), "overline", 15, V10DS.GOLD_500, Vector2(_x(), y), 480.0)
		o.set_meta("v10_role", "overline")
		var t: = _label(title, "display", 44, V10DS.PAPER_100, Vector2(_x(), y + 22.0), 656.0)
		V10TowerFan.fit_label(t, title, "display", [44, 32], 656.0 - (lives_w + 16.0 if lives_w > 0.0 else 0.0), 1, V10DS.PAPER_100)
		_beat1.append(o)
		_beat1.append(t)
		y += 22.0 + 58.0
		if cap != "":
			var c: = _label(cap, "ui", 18, V10DS.PAPER_500, Vector2(_x(), y), 656.0)
			_beat1.append(c)
			y += 26.0
		y += 32.0

	# lanterns (Pagoda) or hearts (Journey) on the right of the title: the run's lives, information, not decor
	func side_lives(n: int, total: int, lantern: bool, gained: = 0) -> void:
		var cnt: = maxi(total, n)
		var step: = 40.0 if lantern else 40.0
		var g: = V10TowerUI.glyph(func(ci: CanvasItem, sz: Vector2) -> void:
			for i in cnt:
				var c: = Vector2(sz.x - 20.0 - (cnt - 1 - i) * step, sz.y * 0.5)
				if lantern:
					V10TowerUI.draw_lantern(ci, c, 38.0, 1.0 if i < n else 0.0)
				else:
					V10TowerUI.draw_heart(ci, c, 28.0, i < n, i >= n), Vector2(step * cnt + 8.0, 56))
		g.position = Vector2(float(L.cx) + 688.0 - g.size.x, float(L.T) + 48.0 + 22.0)
		content.add_child(g)
		_beat1.append(g)
		if gained > 0 and not V10TowerUI.calm():
			get_tree().create_timer(0.9, false).timeout.connect(func() -> void:
				if is_instance_valid(g):
					V10Juice.glow(content, g.position + Vector2(g.size.x - 24.0, 32.0), V10TowerUI.LANTERN_GLOW, 1.1, 0.5, 0.45))

	# reward tokens («карточки-фишки» 3:4): [[key, amount, caption]] or cosmetics [["cos", id, ""]], at most 3
	func add_tokens(list: Array, big: bool) -> float:
		var n: = mini(3, list.size())
		if n == 0:
			return y
		var tsz: = Vector2(160, 213) if big else Vector2(144, 192)
		for i in n:
			var c: = V10TowerSheets.Chip.new(list[i], tsz)
			c.position = Vector2(_x() + i * (tsz.x + 16.0), y)
			content.add_child(c)
			tokens.append(c)
		y += tsz.y + 24.0
		return y

	# [{t, s?, icon?}] → ≤ 2 plates: line 3 becomes the subtitle of the first plate without one, then line 4
	func add_lines(lines: Array) -> void:
		var head_n: = mini(2, lines.size())
		var subs: = []
		for k in head_n:
			subs.append(String((lines[k] as Dictionary).get("s", "")))
		for k in range(2, lines.size()):
			var free: = subs.find("")
			if free < 0:
				break
			subs[free] = String((lines[k] as Dictionary).t)
		for k in head_n:
			var d: Dictionary = lines[k]
			var p: = add_plate(String(d.t), String(subs[k]))
			if d.get("icon") is Texture2D:
				p.icon_tex = d.icon

	func add_plate(title: String, sub: = "", glyph: Control = null) -> V10Plate:
		if plates.size() >= 2:
			# ≤ 2 plates: the third line joins the second as its subtitle
			var p2: V10Plate = plates[1]
			p2.subtitle = (p2.subtitle + " · " if p2.subtitle != "" else "") + title
			return p2
		var p: = V10Plate.make("M", 656, title, sub)
		p.on_art = false
		p.position = Vector2(_x(), y)
		if glyph:
			p.right_slot = glyph
		content.add_child(p)
		plates.append(p)
		y += 80.0 + 8.0
		return p

	func buttons(p_text: String, p_cb: Callable, s_text: = "", s_cb: = Callable()) -> void:
		prim = V10Button.make("play", p_text, Vector2(560, 104))
		V10TowerUI.role(prim, "primary")
		prim.position = (L.play as Rect2).position
		prim.pressed.connect(func() -> void:
			if closing:
				return
			V10TowerUI.tap(prim)
			p_cb.call())
		add_child(prim)
		if s_text != "":
			sec = V10Button.make("secondary", s_text, Vector2(560, 80))
			V10TowerUI.role(sec, "secondary")
			sec.position = (L.second as Rect2).position
			sec.pressed.connect(func() -> void:
				if closing:
					return
				V10TowerUI.tap(sec)
				s_cb.call())
			add_child(sec)
		_fade(prim, 0.3)
		if sec:
			_fade(sec, 0.34)

	func finish(d: Dictionary) -> void:
		if closing:
			return
		closing = true
		result = d
		if on_done.is_valid():
			on_done.call(d)
		if is_instance_valid(self) and is_inside_tree():
			var tw: = create_tween()
			tw.tween_property(self, "modulate:a", 0.0, 0.16).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
			tw.tween_callback(queue_free)

	func save() -> void:
		if V10TowerSheets.autosave:
			V10TowerUI.save_now()

	# ------------------------------------------------------------ motion

	func _fade(n: CanvasItem, delay: float, dur: = 0.0) -> void:
		if dur <= 0.0:
			dur = 0.12 if V10TowerUI.calm() else V10DS.T_IN
		n.modulate.a = 0.0
		var tw: = n.create_tween()
		tw.tween_property(n, "modulate:a", 1.0, dur).set_delay(delay).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)

	# beat 1: «вдох» ≤ 5 elements (240 ms, 40 ms step, +12 px); beat 2: tokens 80 ms apart, a rising pentatonic
	# note each; beat 3: plates «вдох». fx «min»: everything is a 120 ms fade, no particles.
	func _breathe_in() -> void:
		var calm: = V10TowerUI.calm()
		var i: = 0
		for n in _beat1:
			_vdokh(n, 0.08 + mini(i, 4) * V10DS.T_IN_STEP, calm)
			i += 1
		var t0: = 0.42
		for k in tokens.size():
			var c: Control = tokens[k]
			var d: = t0 + k * 0.08
			_vdokh(c, d, calm)
			get_tree().create_timer(d, false).timeout.connect(func() -> void:
				if not is_instance_valid(c):
					return
				V10Juice.sound("gem_tick", V10TowerSheets.PENTA[k % V10TowerSheets.PENTA.size()], -6.0)
				if not calm:
					V10Juice.burst(content, c.position + c.size * Vector2(0.5, 0.34), "star4", 6, V10Juice.GOLD, 0.5))
		var t1: = t0 + tokens.size() * 0.08 + 0.12
		for k in plates.size():
			_vdokh(plates[k], t1 + k * V10DS.T_IN_STEP, calm)

	func _vdokh(n: CanvasItem, delay: float, calm: bool) -> void:
		if calm:
			_fade(n, delay, 0.12)
			return
		var c: = n as Control
		var y0: = c.position.y
		c.modulate.a = 0.0
		c.position.y = y0 + 12.0
		var tw: = c.create_tween().set_parallel(true)
		tw.tween_property(c, "modulate:a", 1.0, V10DS.T_IN).set_delay(delay).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		tw.tween_property(c, "position:y", y0, V10DS.T_IN).set_delay(delay).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)

	# the fan as the second beat of this sheet; «показать стол» fades the sheet while the finger holds
	func open_fan(cards: Array, o: Dictionary) -> V10TowerFan:
		o = o.duplicate()
		o["embedded"] = true
		fan = V10TowerFan.open(self, cards, o)
		fan.peek_changed.connect(func(k: float) -> void:
			content.modulate.a = 1.0 - 0.9 * k
			backdrop.modulate.a = 1.0 - 0.85 * k
			if sec:
				sec.modulate.a = V10TowerFan._btn_k(k))
		return fan

	func _show_prim() -> void:
		prim.visible = true
		_fade(prim, 0.0)

	# ------------------------------------------------------------ Пагода: floor cleared

	func _floor_clear() -> void:
		var f: = int(res.get("floor", int(run.get("floor", 1)) - 1))
		var h: = V10Pagoda.heat_chosen(run)
		var guard: = bool(res.get("chest", false))
		var names: Array = V10Pagoda.FLOOR_NAMES
		var cap: = "Страж повержен · сундук" if guard else String(names[(f - 1) % names.size()])
		var lives: = int(run.get("lives", 3))
		lives_w = 40.0 * maxi(3, lives) + 8.0
		head("Пагода Луны · Жар %d" % h, "Этаж %d пройден" % f, cap)
		side_lives(lives, maxi(3, lives), true, 1 if guard else 0)
		add_tokens(V10TowerUI.reward_tokens(res.get("reward", {})), false)
		# the lines of beat 3, most important first; ≤ 2 plates, a third / fourth line is a plate's subtitle
		var lines: = []
		var forced: Array = res.get("forced", [])
		var fcard: = {}
		if not forced.is_empty():
			fcard = V10Mods.curse_card(String(forced[0]), int(forced[1]), "pagoda")
			fcard["forced"] = true
			var ct: = V10TowerArt.curse_tex(String(forced[0]))
			lines.append({"t": "Пагода разгорается", "s": "%s — до конца восхождения" % V10TowerUI.ui_text(String(fcard.title)), "icon": ct})
		for m in res.get("miles", []):
			var g: = int(m[1])
			lines.append({"t": "Веха: этаж %d · +%d %s" % [int(m[0]), g, V10TowerSheets.pl(g, "кристалл", "кристалла", "кристаллов")]})
		if int(res.get("offering", 0)) > 0:
			lines.append({"t": "Подношение недели · +%d" % int(res.offering)})
		if bool(res.get("record", false)):
			lines.append({"t": "Новый рекорд при Жаре %d" % h})
		for c in res.get("cosmetics", []):
			lines.append({"t": V10TowerSheets.cos_title(String(c)), "s": "новая косметика Пагоды"})
		add_lines(lines)
		buttons("Выше · этаж %d" % int(run.get("floor", f + 1)), func() -> void: finish({"action": "next"}),
			"В Пагоду", func() -> void: finish({"action": "leave"}))
		var offer: Array = res.get("offer", [])
		var t_fan: = 0.62 + tokens.size() * 0.08 + plates.size() * 0.04
		if not fcard.is_empty():
			var t_flare: = t_fan
			get_tree().create_timer(t_flare, false).timeout.connect(func() -> void:
				if is_instance_valid(self) and not closing:
					V10TowerSheets.heat_flare(self, fcard))
			t_fan += V10TowerSheets.Flare.DURATION
		if offer.is_empty():
			return
		prim.visible = false
		var cards: = []
		for id in offer:
			cards.append(V10Mods.bless_card(String(id), run))
		var fn: = open_fan(cards, {"title": "Выбери благословение", "run": run, "mode": "pagoda", "delay": t_fan})
		fn.picked.connect(func(id: String) -> void:
			V10Pagoda.pick_blessing(run, id)
			save()
			_show_prim())

	# ------------------------------------------------------------ Странствие: board cleared

	func _board_clear() -> void:
		var b: = int(res.get("boards", int(run.get("board", 1))))
		var done: = bool(res.get("done", false))
		var boss: = b == V10Journey.BOARDS
		var wid: = int(run.get("week", V10TowerUtil.cur_week()))
		var over: = ("Тренировка · " if bool(run.get("practice", false)) else "Странствие · ") + String(V10Journey.theme(wid).name)
		var title: = ("Босс повержен" if boss else "Стол %d из %d пройден" % [b, V10Journey.BOARDS])
		lives_w = 40.0 * V10Journey.HEARTS + 8.0
		head(over, title, "")
		side_lives(int(run.get("hearts", 3)), V10Journey.HEARTS, false)
		# the score: the board (rolls up) and the run total, Display 44 (the sheet's type budget: 44 · 32 · 22 · 18)
		var sc: = int(res.get("score", 0))
		var tot: = int(res.get("total", sc))
		var top: = y - 12.0
		var a: = _label("+0", "display", 44, V10DS.GOLD_300, Vector2(_x(), top), 300.0)
		var ac: = _label("очки стола", "ui", 18, V10DS.PAPER_500, Vector2(_x(), top + 58.0), 300.0)
		var bl: = _label("0", "display", 44, V10DS.PAPER_100, Vector2(_x() + 328.0, top), 300.0)
		var bc: = _label("всего за забег", "ui", 18, V10DS.PAPER_500, Vector2(_x() + 328.0, top + 58.0), 300.0)
		for n in [a, ac, bl, bc]:
			n.set_meta("score_block", true)
			_beat1.append(n)
		y = top + 58.0 + 26.0 + 32.0
		_roll(a, 0, sc, 0.32, "+%s")
		_roll(bl, tot - sc, tot, 0.6, "%s")
		var cm: = V10Journey.curse_mult(run)
		if cm > 1.0001:
			add_plate("Проклятия: очки %s" % V10TowerUtil.fmt_mult2(cm), "на каждом следующем столе")
		var nb: = mini(V10Journey.BOARDS, b + 1)
		if done:
			buttons("К итогу забега", func() -> void: finish({"action": "finish"}))
			return
		buttons("Дальше · стол %d" % nb, func() -> void: finish({"action": "next"}))
		var offer: Array = res.get("offer", [])
		var curses: Array = res.get("curse_offer", [])
		var t_fan: = 0.7 + plates.size() * 0.04
		if offer.is_empty() and curses.is_empty():
			return
		prim.visible = false
		var mode: = String(run.get("mode", "journey"))
		var open_curses: = func() -> void:
			var cc: = []
			for id in curses:
				cc.append(V10Mods.curse_card(String(id), 1, mode))
			var fc: = open_fan(cc, {"title": "Взять проклятие?", "subtitle": "Очки %s на каждом следующем столе" % V10TowerUtil.fmt_mult2(1.0 + V10ModsData.JOURNEY_CURSE_BONUS),
				"can_skip": true, "skip_text": "Без проклятия", "run": run, "mode": mode, "delay": 0.1})
			fc.picked.connect(func(id: String) -> void:
				V10Journey.take_curse(run, id)
				save()
				_show_prim())
			fc.skipped.connect(func() -> void:
				run["curse_offer"] = []
				_show_prim())
		if offer.is_empty():
			get_tree().create_timer(t_fan, false).timeout.connect(open_curses)
			return
		var cards: = []
		for id in offer:
			cards.append(V10Mods.bless_card(String(id), run))
		var fn: = open_fan(cards, {"title": "Выбери благословение", "run": run, "mode": mode, "delay": t_fan})
		fn.picked.connect(func(id: String) -> void:
			V10Journey.pick_blessing(run, id)
			save()
			if curses.is_empty():
				_show_prim()
			else:
				open_curses.call())

	func _roll(l: Label, from: int, to: int, delay: float, fmt: String) -> void:
		l.text = fmt % V10TowerSheets.num(from)
		get_tree().create_timer(delay, false).timeout.connect(func() -> void:
			if is_instance_valid(l):
				V10Juice.roll(l, from, to, 0.9 if not V10TowerUI.calm() else 0.3, func(v: int) -> String: return fmt % V10TowerSheets.num(v)))

	# ------------------------------------------------------------ Пагода: the climb is over

	func _pagoda_end() -> void:
		var h: = int(res.get("heat", 0))
		var fl: = int(res.get("floors", 0))
		var sc: = int(res.get("score", 0))
		head("Пагода Луны · Жар %d" % h, "Восхождение окончено", "")
		var top: = y - 12.0
		var left: = "%d %s × %s =" % [fl, V10TowerSheets.pl(fl, "этаж", "этажа", "этажей"), V10TowerUtil.fmt_mult(float(res.get("mult", 1.0))).trim_prefix("×")]
		var dy: = V10TowerSheets.baseline_dy("display", 44, "ui", 22)
		var fw: = V10Type.text_w(left, "ui", 22)
		var fa: = _label(left, "ui", 22, V10DS.PAPER_300, Vector2(_x(), top + dy), fw + 4.0)
		var fb: = _label("0", "display", 44, V10DS.GOLD_300, Vector2(_x() + fw + 14.0, top), 656.0 - fw - 14.0)
		var fc: = _label("очки восхождения", "ui", 18, V10DS.PAPER_500, Vector2(_x(), top + 58.0), 400.0)
		for n in [fa, fb, fc]:
			n.set_meta("score_block", true)
			_beat1.append(n)
		_roll(fb, 0, sc, 0.3, "%s")
		y = top + 58.0 + 26.0 + 32.0
		var list: = []
		for c in cos:
			list.append(["cos", String(c), ""])
		add_tokens(list, true)
		if bool(res.get("record_heat", false)):
			add_plate("Новый рекорд при Жаре %d" % h, "%d %s" % [fl, V10TowerSheets.pl(fl, "этаж", "этажа", "этажей")])
		else:
			var best: = V10Pagoda.best_for_heat(h)
			add_plate("Рекорд при Жаре %d: %d %s" % [h, best, V10TowerSheets.pl(best, "этаж", "этажа", "этажей")])
		if bool(res.get("record_score", false)):
			add_plate("Лучший счёт Пагоды · " + V10TowerSheets.num(sc))
		buttons("Новое восхождение", func() -> void: finish({"action": "again"}), "К Пагоде", func() -> void: finish({"action": "hub"}))

	# ------------------------------------------------------------ Странствие: the run is over

	func _journey_end() -> void:
		var practice: = bool(res.get("practice", false))
		var boards: = int(res.get("boards", 0))
		var sc: = int(res.get("score", 0))
		var tier: = int(res.get("tier", -1))
		var over: = ("Тренировка · " if practice else "Странствие · ") + "столов %d из %d" % [boards, V10Journey.BOARDS]
		var title: = "Странствие пройдено" if boards >= V10Journey.BOARDS else "Забег окончен"
		head(over, title, "")
		var top: = y - 12.0
		var a: = _label("0", "display", 44, V10DS.GOLD_300, Vector2(_x(), top), 360.0)
		var ac: = _label("очки забега", "ui", 18, V10DS.PAPER_500, Vector2(_x(), top + 58.0), 360.0)
		for n in [a, ac]:
			n.set_meta("score_block", true)
			_beat1.append(n)
		_roll(a, 0, sc, 0.3, "%s")
		# the tier: a cinnabar hanko on the right of the score (the one ornament of the sheet)
		if tier >= 0:
			var st: = V10TowerSheets.Stamp.new()
			st.text = V10TowerUI.ui_text(String(res.get("tier_name", V10Journey.tier_name(tier))))
			content.add_child(st)
			st.position = Vector2(float(L.cx) + 688.0 - st.size.x - 8.0, top - 4.0)
			st.drop(1.1)
		else:
			var need: Array = V10TowerUtil.econ("journey.tier_score")
			ac.text = "очки забега · Бронза от %s" % V10TowerSheets.num(int(need[0]))
			ac.size.x = 560.0
		y = top + 58.0 + 26.0 + 32.0
		var rw: Dictionary = res.get("reward", {})
		if practice:
			add_plate("Тренировка: без наград", "попытки недели не тратятся")
		elif rw.is_empty():
			add_plate("Награда недели уже получена", "её дают один раз, за лучшую попытку")
		else:
			add_tokens(V10TowerUI.reward_tokens(rw), true)
			var nl: = _label("выдана за лучшую попытку недели", "ui", 18, V10DS.PAPER_500, Vector2(_x(), y - 14.0), 656.0)
			nl.set_meta("token_note", true)
			_beat1.append(nl)
			y += 26.0 + 4.0
		if bool(res.get("record", false)) and not practice:
			add_plate("Лучшая попытка недели", V10TowerSheets.num(sc) + " очков")
		if not practice:
			var left: = V10Journey.attempts_left()
			add_plate("Попытки недели: %d из %d" % [left, V10Journey.attempts_max()],
				"обновятся в " + V10TowerUtil.week_refresh_text(V10TowerUtil.cur_week()))
		buttons("Готово", func() -> void: finish({"action": "hub"}))


# ---------------------------------------------------------------- a reward token: «карточка-фишка» 3:4

class Chip:
	extends Control
	var entry: Array
	var tex: Texture2D
	var num_l: Label
	var cap_l: Label
	var big: = false

	func _init(e: Array, sz: Vector2) -> void:
		entry = e
		size = sz
		big = sz.x >= 150.0
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_meta("reward_token", true)
		var key: = String(e[0])
		if key != "cos":
			var p: String = V10TowerSheets.ICON.get(key, "")
			if p != "" and ResourceLoader.exists(p):
				tex = load(p)
			# the amount (Display 32) and its word in the right case («+140 кристаллов»)
			num_l = V10TowerUI.label("+%s" % V10TowerSheets.num(int(e[1])), "display", 32, V10DS.GOLD_300)
			cap_l = Label.new()
			V10TowerFan.fit_label(cap_l, V10TowerUI.ui_text(String(e[2])), "ui", [18], sz.x - 16.0, 2, V10DS.PAPER_300)
			cap_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		else:
			var c: = V10TowerSheets.cos_def(String(e[1]))
			num_l = V10TowerUI.label(String(V10TowerSheets.COS_KIND.get(String(c.kind), "Косметика")), "ui", 22, V10DS.GOLD_300)
			cap_l = Label.new()
			V10TowerFan.fit_label(cap_l, "«%s»" % String(c.name), "ui", [18], sz.x - 16.0, 2, V10DS.PAPER_100)
			cap_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			set_meta("cos", String(c.id))
		for l in [num_l, cap_l]:
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
			add_child(l)
		var icon_h: = sz.y * 0.5
		var nh: = V10TowerFan.box_h("display", 32, 1) - 4.0 if key != "cos" else 32.0
		num_l.position = Vector2(4, icon_h)
		num_l.size = Vector2(sz.x - 8.0, nh)
		cap_l.position = Vector2(8, icon_h + nh)
		cap_l.size = Vector2(sz.x - 16.0, V10TowerFan.box_h("ui", 18, 2))

	func _draw() -> void:
		var sz: = size
		draw_colored_polygon(V10TowerFan.moved(V10TowerFan.shape(sz), Vector2(0, 4)), V10DS.NIGHT_900)
		var poly: = V10TowerFan.shape(sz)
		var cols: = PackedColorArray()
		for q in poly:
			cols.append(V10DS.NIGHT_700.lerp(V10DS.NIGHT_800, clampf(q.y / sz.y * 1.3, 0.0, 1.0)))
		draw_polygon(poly, cols)
		var inner: = V10TowerFan.shape(sz, 3.0)
		draw_polyline(PackedVector2Array([inner[6], inner[7], inner[0], inner[1]]), Color(V10DS.PAPER_100, 0.10), 1.0, true)
		draw_polyline(PackedVector2Array([inner[2], inner[3], inner[4], inner[5]]), Color(V10DS.NIGHT_900, 0.55), 1.0, true)
		V10Plate.hairline(self, 12.0, sz.x - 12.0, 0.5, V10DS.hair())
		var ic: = Vector2(sz.x * 0.5, sz.y * 0.27)
		var isz: = minf(sz.x * 0.56, sz.y * 0.36)
		for i in 4:
			for pl in Geometry2D.intersect_polygons(V10TowerFan.circle(ic, isz * (0.3 + 0.1 * i)), poly):
				draw_colored_polygon(pl, Color(V10DS.GOLD_500, 0.035))
		if tex:
			var ts: = tex.get_size()
			var k: = isz / maxf(ts.x, ts.y)
			draw_texture_rect(tex, Rect2(ic - ts * k * 0.5, ts * k), false)
		elif String(entry[0]) == "cos":
			_draw_cos(ic, isz)

	# cosmetics glyphs, monoline gold (frame / title / tile edge)
	func _draw_cos(c: Vector2, s: float) -> void:
		var col: = V10DS.GOLD_300
		var kind: = String(V10TowerSheets.cos_def(String(entry[1])).kind)
		match kind:
			"frame":
				var r: = Rect2(c - Vector2(s, s) * 0.36, Vector2(s, s) * 0.72)
				var p: = V10TowerFan.shape(r.size, 0.0, 8.0)
				p = V10TowerFan.moved(p, r.position)
				p.append(p[0])
				draw_polyline(p, col, 2.5, true)
				var p2: = V10TowerFan.moved(V10TowerFan.shape(r.size - Vector2(16, 16), 0.0, 5.0), r.position + Vector2(8, 8))
				p2.append(p2[0])
				draw_polyline(p2, V10TowerUI.EMBER_HI, 1.5, true)
				draw_circle(c + Vector2(0, -4), s * 0.1, Color(col, 0.9), false, 2.0, true)
				draw_arc(c + Vector2(0, s * 0.16), s * 0.16, PI, TAU, 16, Color(col, 0.9), 2.0, true)
			"title":
				var w: = s * 0.8
				var a: = c + Vector2(-w * 0.5, -6)
				draw_line(a, a + Vector2(w, 0), col, 2.5, true)
				draw_line(a + Vector2(0, 14), a + Vector2(w, 14), col, 2.5, true)
				draw_line(a + Vector2(w * 0.15, 28), a + Vector2(w * 0.85, 28), Color(col, 0.6), 2.5, true)
				draw_arc(a + Vector2(0, 7), 7.0, PI * 0.5, PI * 1.5, 12, col, 2.5, true)
				draw_arc(a + Vector2(w, 7), 7.0, -PI * 0.5, PI * 0.5, 12, col, 2.5, true)
			_:
				var r2: = Rect2(c - Vector2(s * 0.27, s * 0.36), Vector2(s * 0.54, s * 0.72))
				var t: = V10TowerFan.moved(V10TowerFan.shape(r2.size, 0.0, 6.0), r2.position)
				draw_colored_polygon(V10TowerFan.moved(t, Vector2(0, 5)), V10TowerUI.EMBER_LO)
				draw_colored_polygon(t, V10DS.PAPER_300)
				t.append(t[0])
				draw_polyline(t, V10TowerUI.EMBER_HI, 2.5, true)
				V10TowerUI.draw_ember(self, c, s * 0.3, V10TowerUI.SEAL)


# ---------------------------------------------------------------- the hanko of the Journey tier

class Stamp:
	extends Control
	var text: = ""
	var seal: ColorRect
	var lbl: Label

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_meta("tier_seal", true)

	func _enter_tree() -> void:
		if seal:
			return
		# a red hanko as wide as its word (H2 32 on cinnabar), a little turned
		var tw: = V10Type.text_w(text, "display", 32)
		size = Vector2(maxf(120.0, tw + 48.0), 88)
		pivot_offset = size * 0.5
		rotation = -0.08
		seal = ColorRect.new()
		seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
		seal.color = Color.WHITE
		seal.size = size
		seal.material = V10Juice.mat("juice_seal", {"color": V10TowerUI.SEAL, "seed": 11.0, "fill": 0.92, "erosion": 0.9})
		add_child(seal)
		lbl = V10TowerUI.label(text, "display", 32, V10DS.PAPER_100)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.size = Vector2(size.x, V10TowerFan.box_h("display", 32, 1))
		lbl.position = Vector2(0, (size.y - lbl.size.y) * 0.5 + 1.0)
		add_child(lbl)
		modulate.a = 0.0

	# falls in 140 ms, one squashed frame, a dull «тук»; the cinnabar shows in 300 ms
	func drop(delay: float) -> void:
		var tw: = create_tween()
		tw.tween_interval(delay)
		if V10TowerUI.calm():
			tw.tween_callback(func() -> void:
				V10Juice.param(seal, "erosion", 0.22)
				V10Juice.sound("stamp_thud", 1.0, -2.0))
			tw.tween_property(self, "modulate:a", 1.0, 0.12)
			return
		tw.tween_callback(func() -> void: scale = Vector2.ONE * 1.7)
		tw.tween_property(self, "modulate:a", 1.0, 0.08)
		tw.parallel().tween_property(self, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(func() -> void:
			scale = Vector2(1.08, 0.9)
			V10Juice.sound("stamp_thud", 1.0, -2.0)
			V10TowerUI.haptic("match")
			V10Juice.ripple(get_parent(), position + size * 0.5, V10TowerUI.SEAL, 110.0, 0.5, 0.05))
		tw.tween_interval(1.0 / 60.0)
		tw.tween_property(self, "scale", Vector2.ONE, 0.06)
		tw.parallel().tween_method(func(v: float) -> void: V10Juice.param(seal, "erosion", v), 0.9, 0.22, 0.3)


# ---------------------------------------------------------------- «Пагода разгорается»

class Flare:
	extends Control
	const DURATION: = 2.1
	var card: Dictionary
	var view: Control
	var dim: ColorRect

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_meta("heat_flare", true)

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		z_index = 20
		var vs: = get_viewport_rect().size
		var calm: = V10TowerUI.calm()
		var heat: = int(card.get("heat", 2))
		var col: = V10TowerUI.heat_color(maxi(8, heat * 4))
		dim = ColorRect.new()
		dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dim.color = Color(V10DS.NIGHT_900, 0.72)
		dim.size = vs
		add_child(dim)
		var t: = V10TowerUI.label("Пагода разгорается", "display", 44, col)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		t.position = Vector2(0, vs.y * 0.5 - 300.0)
		t.size = Vector2(vs.x, 52)
		add_child(t)
		var c2: = V10TowerUI.label("ещё одно проклятие до конца восхождения", "ui", 18, V10DS.PAPER_300)
		c2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		c2.position = Vector2(0, vs.y * 0.5 - 240.0)
		c2.size = Vector2(vs.x, 26)
		add_child(c2)
		view = V10TowerFan.card_node(card, {"mode": "pagoda"})
		view.position = vs * 0.5 - V10TowerFan.CARD * 0.5 + Vector2(0, 40)
		view.scale = Vector2.ONE * 1.15
		add_child(view)
		V10TowerUI.sfx("heat_flare", "fever")
		var tw: = create_tween()
		modulate.a = 0.0
		tw.tween_property(self, "modulate:a", 1.0, 0.12 if calm else 0.22)
		if calm:
			view.set("flare", 0.8)
		else:
			# three flares in 1,2 s (≤ 3 a second), the colour of the heat, never white
			for i in 3:
				tw.tween_property(view, "flare", 1.0, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
				tw.tween_property(view, "flare", 0.35, 0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			tw.parallel().tween_callback(func() -> void:
				V10Juice.burst(self, view.position + V10TowerFan.CARD * 0.5, "ember", 16, col, 0.8, V10TowerFan.CARD * 0.4)).set_delay(0.0)
		tw.tween_interval(0.5 if not calm else 1.4)
		tw.tween_property(self, "modulate:a", 0.0, 0.3 if not calm else 0.12)
		tw.tween_callback(queue_free)


class _Backdrop:
	extends Control

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		# the sheet: night.900 over the screen (no pre-blurred snapshot yet), a lacquer tone on the top
		var r: = Rect2(Vector2.ZERO, get_viewport_rect().size)
		draw_rect(r, Color(V10DS.NIGHT_900, 0.94))
		var c0: = Color(V10DS.NIGHT_700, 0.35)
		var c1: = Color(V10DS.NIGHT_700, 0.0)
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(r.size.x, 0), Vector2(r.size.x, 420), Vector2(0, 420)]), PackedColorArray([c0, c0, c1, c1]))
