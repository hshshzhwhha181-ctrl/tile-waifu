class_name V9UltCast
extends Node

# V9UltCast — the 0.9 Ultimate in a match (docs/0.9-spec.md §B, docs/HEROINES.md §2). One per play screen
# (play.ult), created in play._build_hud. Data and rules come from V9Ults; the clip is V9Cutin.
#
#   charge     play.skill_charge / play.SKILL_NEED (names kept: specials, combo rewards and modes write them).
#              +1 per pair, pairs removed by an ult (play.v9_from_ult) give nothing. need() = V9Ults.need(aff,
#              ranked), start_charge() = V9Ults.start_charge_for(outfit, ranked) (SR +2 / SSR +3 off ranked).
#   ready      play._skill_ready(): the portrait glows, a chime, «Ульта «…» готова»; tap the portrait.
#   begin()    blocked() → aim (2 s, per heroine: pair / swipe / row / tier / none; a tap on the prompt or the
#              timeout = auto-target; Ц shows the auto-target) → cut-in (V9Ults.cutin_mode: full / short / off;
#              fx_level «min» never plays the full clip) → heroine core + outfit modifier on the strong beat →
#              the board comes back with the combo window and fever shifted by the paused time; taps made during
#              a short clip are replayed.
#   ranked     duel, Блиц, Сад, турнир недели (RANKED_MODES): start 0, need 6, no modifiers, ranked cores
#              (V9Ults.core), no smart auto-cast, the clip is never full.
#   auto-cast  off ranked only, «smart»: when the tray is one tile from full and nothing on the table can pair
#              with it, and the heroine's own wait (Рин: tray ≥ 3, Юэ: a closed tile or ice) holds.
#
# Dev: play.gd --v9_ult=1 (see play._v9_dev) casts at once with auto-target; force_mode picks the clip.

const RANKED_MODES: = ["duel", "blitz", "zen", "v7tourney"]
const AIM_TEXT: = {
	"pair": "Коснись пары на столе",
	"swipe": "Проведи по столу: куда рвануть",
	"row": "Проведи лучом по ряду",
	"tier": "Коснись яруса: уйдёт самая глубокая пара",
}
const JOKER: = 300

var play
var hero: = "mc"
var id: = "o_base"
var rar: = "R"
var ranked: = false
var core: Dictionary = {}
var mod: = ""
var busy: = false
var aiming: = false
var force_mode: = ""
var force_auto: = false

var _aim_left: = 0.0
var _aim_pick: Dictionary = {}
var _aim_down: = false
var _aim_from: = Vector2.ZERO
var _aim_fx: Node2D
var _aim_vis: Array = []
var _pill: Control
var _ring: AimRing
var _frame: Line2D
var _fx: Node2D
var _last_line: = -1
var _applying: = false


class AimRing extends Control:
	var frac: = 1.0
	var col: = Color.WHITE
	var secs: = 2.0

	func _draw() -> void :
		var c: = size * 0.5
		var r: = size.x * 0.5 - 4.0
		draw_circle(c, r + 2.0, Color(0, 0, 0, 0.35))
		draw_arc(c, r - 2.0, 0, TAU, 48, Color(1, 1, 1, 0.12), 5.0, true)
		draw_arc(c, r - 2.0, - PI * 0.5, - PI * 0.5 + TAU * frac, 48, col, 5.0, true)
		var f: = UI.font("body", 900)
		var s: = str(int(ceil(secs * frac)))
		var w: = f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
		draw_string_outline(f, c + Vector2(- w * 0.5, 9), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, 6, Color(0.08, 0.04, 0.1))
		draw_string(f, c + Vector2(- w * 0.5, 9), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color("fff2d2"))


static func is_ranked(mode: String) -> bool:
	return mode in RANKED_MODES


func setup(p) -> V9UltCast:
	play = p
	name = "V9UltCast"
	hero = String(p.partner)
	ranked = is_ranked(String(p.mode))
	id = V9Ults.for_hero(hero)
	if V9Ults.get_ult(id).get("hero", hero) != hero:
		id = String(V9Ults.BASE.get(hero, "o_base"))
	rar = String(G.ITEM.get(id, {}).get("rar", "R"))
	core = V9Ults.core(hero, ranked)
	mod = V9Ults.mod(id, ranked)
	return self


func ult_name() -> String:
	return String(V9Ults.get_ult(id).get("name", "Ульта"))


# her shout for this cast: never the line used last time, and never one that only repeats the ult name in the strip
# right above it («Чистая операция» / «Чистая операция.») when she has another
func pick_line(last: int) -> int:
	var lines: Array = V9Ults.get_ult(id).get("lines", [])
	var nm: = _bare(ult_name())
	var ok: = []
	for i in lines.size():
		if i != last and _bare(String(lines[i])) != nm:
			ok.append(i)
	if ok.is_empty():
		return V9Ults.line(id, last)
	return int(ok[randi() % ok.size()])


static func _bare(s: String) -> String:
	var out: = ""
	for ch in s.to_lower():
		if ch.is_valid_identifier() or ch == "ё" or (ch >= "а" and ch <= "я") or ch.is_valid_int():
			out += ch
	return out


func need() -> int:
	return V9Ults.need(G.aff_level(hero), ranked)


func start_charge() -> int:
	return clampi(V9Ults.start_charge_for(id, ranked), 0, need() - 1)


func gold() -> bool:
	return V9Ults.gold_variant(play.now() < float(play.fever_until), G.aff_level(hero))


func palette() -> Dictionary:
	return V9Ults.palette(id, gold())


func cutin_mode() -> String:
	if force_mode != "":
		return force_mode
	var m: = V9Ults.cutin_mode(G.ult_cutin(), ranked, first_today())
	if m == "full" and V9Feel.level() == "min":
		m = "short"
	return m


func first_today() -> bool:
	var d = G.S.get("v9_ult_day", {})
	return not (d is Dictionary) or String(d.get(id, "")) != G.today()


func _mark_seen() -> void :
	var d = G.S.get("v9_ult_day", {})
	if not (d is Dictionary):
		d = {}
	d[id] = G.today()
	G.S["v9_ult_day"] = d


func _board() -> TrayBoard:
	return play.board if play and is_instance_valid(play.board) else null


func _alive() -> bool:
	return is_inside_tree() and play != null and is_instance_valid(play) and play.is_inside_tree() and _board() != null


static func pos_of(t: Tile) -> Vector2:
	return t.get_global_transform_with_canvas().origin


# ── what is on the table ────────────────────────────────────────────────────

func pairs() -> Array:
	var bd: = _board()
	if bd == null:
		return []
	return bd._pairs_on_board().filter( func(p): return p[0].face == p[1].face and p[0].face != JOKER and p[0].ice <= 0 and p[1].ice <= 0\
	and not p[0].pending and not p[1].pending and bd.on_board(p[0]) and bd.on_board(p[1]))


func closed_tiles() -> Array:
	var bd: = _board()
	if bd == null:
		return []
	return bd.tiles.filter( func(t): return bd.on_board(t) and not t.pending and (t.secret or t.ice > 0))


# tiles that become free when this pair goes (Ц: the pair that frees the most)
func free_gain(p: Array) -> int:
	var bd: = _board()
	var gone: = {p[0]: true, p[1]: true}
	var present: = func(o): return bd.on_board(o) and not gone.has(o)
	var n: = 0
	for t in bd.tiles:
		if gone.has(t) or not bd.on_board(t) or bd.is_free(t):
			continue
		if bd._free_if(t, present):
			n += 1
	return n


func best_pairs(n: int) -> Array:
	var ps: = pairs()
	var sc: = {}
	for p in ps:
		sc[p] = free_gain(p)
	ps.sort_custom( func(x, y): return int(sc[x]) > int(sc[y]) or (int(sc[x]) == int(sc[y]) and mini(x[0].step, x[1].step) < mini(y[0].step, y[1].step)))
	return ps.slice(0, n)


func blocked() -> String:
	var bd: = _board()
	if bd == null:
		return "…"
	match hero:
		"rin":
			if bd.tray.is_empty() and pairs().is_empty():
				return "Лоток пуст, и снять нечего. Чайную паузу прибережём."
		"yue":
			if closed_tiles().is_empty() and pairs().is_empty():
				return "Здесь всё и так видно. Позови меня позже."
		_:
			if pairs().is_empty():
				return "Сейчас мне нечего снять. Чуть позже!"
	return ""


# smart auto-cast (off ranked): the tray is one tile from full and the table cannot answer it
func auto_ok() -> bool:
	var bd: = _board()
	if bd == null or not V9Ults.auto_cast_allowed(ranked) or bool(play.get("tut")):
		return false
	if bd.tray.is_empty() or bd.tray.size() < bd.slots - 1:
		return false
	var faces: = {}
	for x in bd.tray:
		faces[x.face] = true
	for t in bd.free_tiles():
		if faces.has(t.face) or t.face == JOKER:
			return false
	match String(core.get("auto_wait", "")):
		"tray>=3":
			if bd.tray.size() < 3:
				return false
		"closed_or_ice":
			if closed_tiles().is_empty():
				return false
	return blocked() == ""


func _process(dt: float) -> void :
	if play == null or not is_instance_valid(play):
		return
	if aiming:
		_aim_tick(dt)
		return
	if busy:
		return
	var bd: = _board()
	if bd and play.skill_ready and bd.input_on and not bool(play.get("_v8_over")) and auto_ok():
		begin(true)


# ── cast ────────────────────────────────────────────────────────────────────

func begin(auto: = false) -> void :
	if busy or not _alive():
		return
	var bd: = _board()
	var why: = blocked()
	if why != "":
		play.stage.say_text(why)
		V9Feel.deny(play.stage)
		return
	busy = true
	play.skill_ready = false
	play.skill_charge = 0
	play.set_meta("v6_casting", true)
	var was_on: = bd.input_on
	bd.input_on = false
	var t0: = float(play.now())
	var fever_on: = t0 < float(play.fever_until)
	play._refresh()
	V9Feel.press(play.stage, "pop", "button")
	# a happy beat on the card, not the «big» bounce: that one lifts her out of the frame while the strip plays
	play.stage.react("combo")
	var bub = play.stage.bubble_node
	if bub and is_instance_valid(bub) and not bub.is_queued_for_deletion():
		bub.queue_free()
	var pick: Dictionary
	if auto or force_auto or String(core.get("target", "none")) == "none":
		pick = auto_pick()
	else:
		pick = await _aim()
	if not _alive():
		return
	var pal: = palette()
	var mode: = cutin_mode()
	_last_line = pick_line(_last_line)
	# the day's «first ult» is spent only by a clip that actually plays in full (a ranked, «коротко», «выкл» or
	# «Эффекты: минимум» cast leaves it for the next casual one — HEROINES §2)
	if mode == "full":
		_mark_seen()
	var buffered: Array = []
	_applied = false
	if mode == "off":
		_quiet_feedback(pal)
		await _apply(pick, pal)
	else:
		Sfx.duck(-8.0, V9Ults.clip_len(rar, hero, mode) + 0.35)
		var c: = V9Cutin.run(play, id, {"mode": mode, "gold": gold(), "line": _last_line, "mirror": V9Cutin.next_mirror(),
			"cy": strip_y(pick)})
		c.strong.connect( func(): _apply(pick, pal))
		c.finished.connect( func(): buffered.append_array(c.buffered))
		await c.finished
	while _applying and _alive():
		await get_tree().process_frame
	if not _alive():
		return
	var paused: = float(play.now()) - t0
	if bd == _board():
		if bd.combo > 0:
			bd.last_match += paused
		if fever_on:
			play.fever_until = float(play.fever_until) + paused
	play.set_meta("v6_casting", false)
	busy = false
	bd = _board()
	if was_on and bd.tiles.any( func(t): return t.alive) and not bool(play.get("_v8_over")):
		bd.input_on = true
		_replay(buffered)
	bd._check_clear()
	play._refresh()


# where the cut-in strip goes: the third of the board (top / middle / bottom) that hides the fewest targets, so
# the effect on the strong beat is seen beside the strip, not under it (ties: the middle)
func strip_y(pick: Dictionary) -> float:
	var br: Rect2 = play.board_rect
	var half: = V9Cutin.BAND_H * 0.5 + V9Cutin.K * (br.size.x * 0.5 + 90.0) + 8.0
	var pts: Array = []
	for pr in pick.get("pairs", []):
		for t in pr:
			if is_instance_valid(t):
				pts.append(pos_of(t).y)
	if pick.has("row_y"):
		pts.append(float(pick.row_y))
	var cands: = [br.get_center().y, br.position.y + half - 4.0, br.end.y - half + 4.0]
	var best: float = cands[0]
	var best_n: = 999
	for cy in cands:
		var n: = 0
		for y in pts:
			if absf(float(y) - cy) < half + Tile.TH * 0.3:
				n += 1
		if n < best_n:
			best_n = n
			best = cy
	return best


func _replay(taps: Array) -> void :
	for p in taps:
		var bd: = _board()
		if bd == null or not bd.input_on:
			return
		var t: = bd.tile_at(p)
		if t:
			# the touch was acknowledged when it was buffered (cutin.gd): replay it without a second click / haptic
			V9Feel.quiet_tile_tap = true
			bd.tap(t)
			V9Feel.quiet_tile_tap = false
			await get_tree().create_timer(0.06).timeout


func auto_pick() -> Dictionary:
	var bd: = _board()
	var n: = int(core.get("pairs", 1))
	var ps: = pairs()
	match hero:
		"rin":
			return {"pairs": ps.slice(0, 1)}
		"yue":
			var t: = bd.best_move()
			return {"row_y": pos_of(t).y if t else (play.board_rect as Rect2).get_center().y}
		"nova":
			if mod == "Ц":
				return {"pairs": best_pairs(1)}
			return {"pairs": ps.slice(ps.size() - 1) if not ps.is_empty() else []}
	if mod == "Ц":
		return {"pairs": best_pairs(n)}
	return {"pairs": ps.slice(0, n)}


func _quiet_feedback(pal: Dictionary) -> void :
	var st: V6HeroStage = play.stage
	Sfx.play(String(V9Ults.get_ult(id).get("sfx", "pop")), 1.06 if gold() else 1.0, -2)
	V9Feel.success(st, "")
	# inside the portrait card (HUD), never over the board
	var at: = st.position + Vector2(st.size.x * 0.5, st.size.y - 70.0)
	Fx.float_text(play.fx_layer, at, ult_name(), (pal.main as Color).lightened(0.45), 26, (pal.ink as Color))


# ── aim (2 s) ───────────────────────────────────────────────────────────────

func _aim() -> Dictionary:
	var pal: = palette()
	aiming = true
	_aim_left = V9Ults.TARGET_TIME
	_aim_pick = {}
	_aim_down = false
	_aim_vis.clear()
	if mod == "Ц":
		var bp: = best_pairs(int(core.get("pairs", 1)))
		for p in bp:
			for t in p:
				t.hint(true)
				_aim_vis.append(t)
	_show_pill(pal)
	while aiming and _alive():
		await get_tree().process_frame
	if not _alive():
		return {}
	_hide_pill()
	for t in _aim_vis:
		if is_instance_valid(t):
			t.hint(false)
	_aim_vis.clear()
	if _aim_pick.is_empty():
		_clear_aim_fx(0.0)
		return auto_pick()
	return _aim_pick


func _aim_tick(dt: float) -> void :
	if _aim_down:
		dt *= 0.5
	_aim_left -= dt
	if _ring:
		_ring.frac = clampf(_aim_left / V9Ults.TARGET_TIME, 0.0, 1.0)
		_ring.queue_redraw()
	if _frame:
		_frame.modulate.a = 0.55 + 0.35 * sin(float(play.now()) * 9.0)
	if _aim_left <= 0.0:
		aiming = false


func _show_pill(pal: Dictionary) -> void :
	var br: Rect2 = play.board_rect
	var col: Color = pal.main
	_frame = Line2D.new()
	var r: = br.grow(5.0)
	_frame.points = PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position])
	_frame.width = 3.0
	_frame.default_color = col.lightened(0.25)
	_frame.joint_mode = Line2D.LINE_JOINT_ROUND
	_frame.z_index = 120
	play.add_child(_frame)
	var W: float = play.size.x
	var H: float = play.size.y
	var top: = br.end.y + 10.0
	var h: = 96.0
	_pill = Control.new()
	_pill.position = Vector2(20, top + maxf(0.0, (H - 10.0 - top - h) * 0.5))
	_pill.size = Vector2(W - 40, h)
	_pill.z_index = 220
	_pill.mouse_filter = Control.MOUSE_FILTER_STOP
	play.add_child(_pill)
	var bg: = UI.rbox("plum", Rect2(Vector2.ZERO, _pill.size), 30, 3, 10)
	bg.colors(Color(col.r * 0.3 + 0.06, col.g * 0.22 + 0.04, col.b * 0.32 + 0.08, 0.97), Color(0.07, 0.04, 0.11, 0.98))
	bg.borders(col.lightened(0.45), Color("c58a2c"))
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pill.add_child(bg)
	_ring = AimRing.new()
	_ring.col = col.lightened(0.3)
	_ring.secs = V9Ults.TARGET_TIME
	_ring.position = Vector2(14, 14)
	_ring.size = Vector2(68, 68)
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pill.add_child(_ring)
	var tl: = UI.label("Ульта «%s»" % ult_name(), 17, Color("ffd98a"), Color(0.1, 0.05, 0.2), 3, "body", 900)
	tl.position = Vector2(96, 10)
	tl.size = Vector2(_pill.size.x - 110, 24)
	tl.clip_text = true
	tl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_pill.add_child(tl)
	var il: = UI.label(String(AIM_TEXT.get(String(core.get("target", "pair")), "")), 21, Color.WHITE, Color(0.1, 0.03, 0.12), 4, "body", 900)
	il.position = Vector2(96, 34)
	il.size = Vector2(_pill.size.x - 110, 30)
	il.clip_text = true
	il.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_pill.add_child(il)
	var al: = UI.label("или коснись здесь: сама выберу" if mod != "Ц" else "подсвечена лучшая цель · коснись здесь", 16, Color(1, 1, 1, 0.7), Color(0.1, 0.03, 0.12), 3, "body", 800)
	al.position = Vector2(96, 64)
	al.size = Vector2(_pill.size.x - 110, 22)
	al.clip_text = true
	_pill.add_child(al)
	_pill.gui_input.connect( func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_pill.accept_event()
			V9Feel.press(_pill, "pop")
			aiming = false)
	_pill.pivot_offset = _pill.size * 0.5
	_pill.modulate.a = 0.0
	_pill.scale = Vector2(0.94, 0.94)
	var tw: = _pill.create_tween().set_parallel()
	tw.tween_property(_pill, "modulate:a", 1.0, 0.12)
	tw.tween_property(_pill, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.play("summon_charge", 1.6, -12)
	# the action buttons under the prompt step back while she aims
	# (and stop taking taps: a faded button must not pop, buzz or flip the sound unseen)
	for b in _bottom_btns():
		b.create_tween().tween_property(b, "modulate:a", 0.0, 0.12)
		if b is Control:
			if not (b as Control).has_meta("v9_aim_mf"):
				(b as Control).set_meta("v9_aim_mf", (b as Control).mouse_filter)
			(b as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE


func _bottom_btns() -> Array:
	var out: = []
	for k in ["btn_undo", "btn_hint", "btn_shuffle", "btn_sound"]:
		var b = play.get(k)
		if b is CanvasItem and is_instance_valid(b):
			out.append(b)
	return out


func _hide_pill() -> void :
	for b in _bottom_btns():
		var a: = 0.6 if b is JButton and (b as JButton).disabled else 1.0
		b.create_tween().tween_property(b, "modulate:a", a, 0.18)
		if b is Control and (b as Control).has_meta("v9_aim_mf"):
			(b as Control).mouse_filter = int((b as Control).get_meta("v9_aim_mf"))
			(b as Control).remove_meta("v9_aim_mf")
	for n in [_pill, _frame]:
		if n and is_instance_valid(n):
			var tw: = (n as CanvasItem).create_tween()
			tw.tween_property(n, "modulate:a", 0.0, 0.12)
			tw.tween_callback(n.queue_free)
	_pill = null
	_frame = null
	_ring = null


func _input(e: InputEvent) -> void :
	if not aiming:
		return
	var bd: = _board()
	if bd == null:
		return
	var br: Rect2 = (play.board_rect as Rect2).grow(12.0)
	if e is InputEventScreenTouch:
		var p: Vector2 = e.position
		if e.pressed:
			if not br.has_point(p):
				return
			get_viewport().set_input_as_handled()
			_aim_down = true
			_aim_from = p
			match String(core.target):
				"pair":
					_aim_down = false
					_pick_pair_at(p)
				"tier":
					_aim_down = false
					_pick_tier_at(p)
				"row":
					_beam_preview(p.y)
				"swipe":
					_arrow_preview(p, p)
		elif _aim_down:
			_aim_down = false
			get_viewport().set_input_as_handled()
			match String(core.target):
				"row":
					_aim_pick = {"row_y": snap_row(p.y)}
					# the same confirm click as the pair / tier picks
					V9Feel.press(null, "select", "button")
					aiming = false
				"swipe":
					_aim_pick = swipe_pick(_aim_from, p)
					V9Feel.press(null, "select", "button")
					aiming = false
	elif e is InputEventScreenDrag and _aim_down:
		get_viewport().set_input_as_handled()
		match String(core.target):
			"row":
				_beam_preview(e.position.y)
			"swipe":
				_arrow_preview(_aim_from, e.position)


func _pick_pair_at(p: Vector2) -> void :
	var bd: = _board()
	var t: = bd.tile_at(p)
	if t == null:
		_aim_miss()
		return
	for pr in pairs():
		if t in pr:
			_aim_pick = {"pairs": [pr]}
			V9Feel.haptic("button")
			Sfx.play("select", 1.2, -4)
			aiming = false
			return
	t.deny()
	V9Feel.deny(null)


func _pick_tier_at(p: Vector2) -> void :
	var bd: = _board()
	var t: = bd.tile_at(p)
	if t == null:
		_aim_miss()
		return
	var gz: = t.gz
	var cand: = pairs().filter( func(pr): return pr[0].gz == gz or pr[1].gz == gz)
	if cand.is_empty():
		t.deny()
		V9Feel.deny(null)
		return
	_aim_pick = {"pairs": [cand.back()], "gz": gz}
	V9Feel.haptic("button")
	Sfx.play("select", 1.3, -4)
	aiming = false


# a tap on a gap inside the board while aiming: a deny and a short pulse of the aim frame (never silence)
func _aim_miss() -> void :
	V9Feel.deny(null)
	if _frame and is_instance_valid(_frame):
		var tw: = _frame.create_tween()
		tw.tween_property(_frame, "width", 7.0, 0.07)
		tw.tween_property(_frame, "width", 3.0, 0.18)


# the y of the tile row nearest to y (canvas)
func snap_row(y: float) -> float:
	var bd: = _board()
	var best: = y
	var bd_y: = INF
	for t in bd.tiles:
		if not bd.on_board(t):
			continue
		var ty: = pos_of(t).y
		if absf(ty - y) < bd_y:
			bd_y = absf(ty - y)
			best = ty
	return best


# Хана: the pairs along the dash (a tap = the pairs nearest to it)
func swipe_pick(a: Vector2, b: Vector2) -> Dictionary:
	var n: = int(core.get("pairs", 1))
	var ps: = pairs()
	var d: = b - a
	var mid_of: = func(pr): return (pos_of(pr[0]) + pos_of(pr[1])) * 0.5
	if d.length() < 24.0:
		ps.sort_custom( func(x, y): return (mid_of.call(x) - a).length() < (mid_of.call(y) - a).length())
		return {"pairs": ps.slice(0, n), "from": a, "to": b}
	var u: = d.normalized()
	var score: = func(pr):
		var m: Vector2 = mid_of.call(pr) - a
		var along: = m.dot(u)
		var off: = absf(m.dot(u.orthogonal()))
		return off + (0.0 if along >= -40.0 else 600.0 - along)
	ps.sort_custom( func(x, y): return score.call(x) < score.call(y))
	var take: = ps.slice(0, n)
	take.sort_custom( func(x, y): return (mid_of.call(x) - a).dot(u) < (mid_of.call(y) - a).dot(u))
	return {"pairs": take, "from": a, "to": b}


func _aim_layer() -> Node2D:
	if _aim_fx == null or not is_instance_valid(_aim_fx):
		_aim_fx = Node2D.new()
		_aim_fx.z_index = 130
		play.add_child(_aim_fx)
	return _aim_fx


func _beam_preview(y: float, l: Node2D = null) -> void :
	if l == null:
		l = _aim_layer()
	for c in l.get_children():
		c.queue_free()
	var br: Rect2 = play.board_rect
	# 0.9 (HEROINES §2: no white, ≤70 % value): the palette's flash colour in normal blend — an additive glow under an
	# additive line clipped the whole row to pure white on bright tiles
	var col: Color = V9Cutin.flash_color(palette().main)
	var g: = Sprite2D.new()
	g.texture = G.fx("glow")
	g.modulate = Color(col, 0.42)
	var gs: Vector2 = g.texture.get_size()
	g.scale = Vector2(br.size.x * 1.1 / gs.x, 70.0 / gs.y)
	g.position = Vector2(br.get_center().x, snap_row(y))
	l.add_child(g)
	var ln: = Line2D.new()
	ln.points = PackedVector2Array([Vector2(br.position.x + 10, g.position.y), Vector2(br.end.x - 10, g.position.y)])
	ln.width = 3.0
	ln.default_color = Color(col, 0.9)
	l.add_child(ln)


func _arrow_preview(a: Vector2, b: Vector2) -> void :
	var l: = _aim_layer()
	for c in l.get_children():
		c.queue_free()
	if (b - a).length() < 8.0:
		var dot: = Sprite2D.new()
		dot.texture = G.fx("ring")
		dot.material = Fx.add_mat()
		dot.modulate = palette().main
		dot.scale = Vector2(0.5, 0.5)
		dot.position = a
		l.add_child(dot)
		return
	_arrow(l, a, b, palette().main, 1.0)


func _arrow(l: Node, a: Vector2, b: Vector2, col: Color, alpha: float) -> void :
	var ln: = Line2D.new()
	ln.points = PackedVector2Array([a, b])
	ln.width = 16.0
	var gr: = Gradient.new()
	gr.colors = PackedColorArray([Color(col, 0.0), Color(col.lightened(0.3), 0.85 * alpha)])
	ln.gradient = gr
	ln.begin_cap_mode = Line2D.LINE_CAP_ROUND
	l.add_child(ln)
	var u: = (b - a).normalized()
	var head: = Polygon2D.new()
	head.polygon = PackedVector2Array([b + u * 26.0, b + u.orthogonal() * 18.0, b - u.orthogonal() * 18.0])
	head.color = Color(col.lightened(0.45), alpha)
	head.antialiased = true
	l.add_child(head)


func _clear_aim_fx(delay: float) -> void :
	var l: = _aim_fx
	_aim_fx = null
	if l == null or not is_instance_valid(l):
		return
	var tw: = l.create_tween()
	tw.tween_interval(delay)
	tw.tween_property(l, "modulate:a", 0.0, 0.25)
	tw.tween_callback(l.queue_free)


# ── effect (on the strong beat) ─────────────────────────────────────────────

var _applied: = false

func _fx_layer() -> Node2D:
	if _fx == null or not is_instance_valid(_fx):
		_fx = Node2D.new()
		_fx.z_index = 320
		play.add_child(_fx)
	return _fx


func _apply(pick: Dictionary, pal: Dictionary) -> void :
	if _applied or not _alive():
		return
	_applied = true
	_applying = true
	var bd: = _board()
	var col: Color = pal.main
	var lay: = _fx_layer()
	match hero:
		"rin":
			if not bd.tray.is_empty():
				for t in bd.tray:
					_mark(lay, pos_of(t), col, 1.0)
				bd.return_tray(bd.tray.size())
				bd.input_on = false
				Sfx.play("whoosh", 1.2, -4)
			else:
				for pr in pick.get("pairs", []):
					_take(pr, col)
			if core.get("highlight_pair", false):
				_hint_pair(3.0)
		"yue":
			var y: float = pick.get("row_y", (play.board_rect as Rect2).get_center().y)
			_clear_aim_fx(0.0)
			var beam: = Node2D.new()
			lay.add_child(beam)
			_beam_preview(y, beam)
			var btw: = beam.create_tween()
			btw.tween_interval(0.25)
			btw.tween_property(beam, "modulate:a", 0.0, 0.35)
			btw.tween_callback(beam.queue_free)
			for t in bd.tiles:
				if bd.on_board(t) and absf(pos_of(t).y - y) < Tile.TH * 0.5 * bd.scale.y:
					_mark(lay, pos_of(t), col, 0.8)
			if bool(core.get("reveal_all", true)):
				for t in bd.tiles:
					if not t.alive:
						continue
					if t.secret:
						t.reveal()
					if t.ice > 0:
						t.ice = 0
						t._update_ice()
				bd.reveal_free()
				_show_pair_near(y)
			else:
				# ranked (V9Ults.RANKED_CORES.yue): 1 pair-equivalent like the others — the pair nearest the beam,
				# then at most one closed tile (or one ice when nothing is closed)
				var pr: Array = []
				var pr_d: = INF
				for q in pairs():
					var d: = absf(pos_of(q[0]).y - y) + absf(pos_of(q[1]).y - y)
					if d < pr_d:
						pr_d = d
						pr = q
				if not pr.is_empty():
					_take(pr, col)
				if int(core.get("reveal", 0)) > 0 and _alive() and not _open_one(col):
					_melt_one(col)
		_:
			if pick.has("from") and pick.has("to") and (pick["to"] - pick["from"]).length() >= 24.0:
				_clear_aim_fx(0.0)
				var arr: = Node2D.new()
				lay.add_child(arr)
				_arrow(arr, pick["from"], pick["to"], col, 1.0)
				var atw: = arr.create_tween()
				atw.tween_interval(0.2)
				atw.tween_property(arr, "modulate:a", 0.0, 0.3)
				atw.tween_callback(arr.queue_free)
			else:
				_clear_aim_fx(0.0)
			if pick.has("gz"):
				var k: = 0
				for t in bd.tiles:
					if bd.on_board(t) and t.gz == int(pick.gz) and k < 14:
						k += 1
						Fx.ring(lay, pos_of(t), Color(col, 0.7), 0.9, 0.35)
			var prs: Array = pick.get("pairs", [])
			for i in prs.size():
				_take(prs[i], col)
				if i < prs.size() - 1 and _alive():
					await get_tree().create_timer(0.16).timeout
			if int(core.get("reveal", 0)) > 0 and _alive():
				_open_one(col)
	if _alive():
		_modifier(col)
	_applying = false


# a target mark: ring + soft glow in the palette's flash colour, normal blend (additive rings over bright tile faces
# clipped to white — HEROINES §2: no white flashes, ≤70 % value)
func _mark(lay: Node, at: Vector2, col: Color, k: float) -> void :
	if not V9Feel.can_fx() or lay == null or not is_instance_valid(lay):
		return
	# the fx layer sits above the cut-in: no rings on the strip (the ult name / her face)
	if V9Cutin.covers(at):
		return
	var fc: = V9Cutin.flash_color(col)
	var r: = Sprite2D.new()
	r.texture = G.fx("ring")
	r.position = at
	r.modulate = Color(fc, 0.85)
	r.scale = Vector2(0.15, 0.15)
	lay.add_child(r)
	var rt: Tween = r.create_tween().set_parallel()
	rt.tween_property(r, "scale", Vector2(0.8 * k, 0.8 * k), 0.36).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	rt.tween_property(r, "modulate:a", 0.0, 0.36).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	rt.chain().tween_callback(r.queue_free)
	var g: = Sprite2D.new()
	g.texture = G.fx("glow")
	g.position = at
	g.modulate = Color(fc, 0.38)
	g.scale = Vector2(0.48 * k, 0.48 * k)
	lay.add_child(g)
	var gt: Tween = g.create_tween().set_parallel()
	gt.tween_property(g, "scale", Vector2(1.2 * k, 1.2 * k), 0.3).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	gt.tween_property(g, "modulate:a", 0.0, 0.3)
	gt.chain().tween_callback(g.queue_free)


func _take(pr: Array, col: Color) -> void :
	var bd: = _board()
	if bd == null:
		return
	var a: Tile = pr[0]
	var b: Tile = pr[1]
	if not (is_instance_valid(a) and is_instance_valid(b) and bd.on_board(a) and bd.on_board(b)) or a.pending or b.pending:
		var alt: = pairs()
		if alt.is_empty():
			return
		a = alt[0][0]
		b = alt[0][1]
	var lay: = _fx_layer()
	var pa: = pos_of(a)
	var pb: = pos_of(b)
	_mark(lay, pa, col, 1.0)
	_mark(lay, pb, col, 1.0)
	if V9Feel.can_fx() and not V9Cutin.covers((pa + pb) * 0.5):
		var n: = int(14 * V9Feel.fx_scale())
		if n > 0:
			Fx.burst(lay, (pa + pb) * 0.5, "sparkle", n, col.lightened(0.4), 1.0)
	Sfx.play("pop", 1.25, -6)
	play.v9_from_ult = true
	var keep_tint: Color = bd.vanish_tint
	bd.vanish_tint = V9Cutin.flash_color(col)
	bd._vanish_pair(a, b)
	bd.vanish_tint = keep_tint
	play.v9_from_ult = false


func _show_pair_near(y: float) -> void :
	for t in _pair_near(y):
		t.hint(true)


# the free pair closest to the row at `y` (else the board's best move and its twin); [] when there is none
func _pair_near(y: float) -> Array:
	var bd: = _board()
	var free: = bd.free_tiles()
	var best: Array = []
	var best_d: = INF
	for t in free:
		var d: = absf(pos_of(t).y - y)
		if d >= best_d:
			continue
		for o in free:
			if o != t and o.face == t.face and o.face != JOKER:
				best = [t, o]
				best_d = d
				break
	if best.is_empty():
		var t: = bd.best_move()
		if t == null:
			return []
		for o in free:
			if o != t and o.face == t.face:
				best = [t, o]
				break
	return best


# a pair to look at: the board's best free move and its twin; `secs` > 0 clears it again
func _hint_pair(secs: float, pr: Array = []) -> void :
	var bd: = _board()
	if pr.is_empty():
		var t: = bd.best_move()
		if t == null:
			return
		for o in bd.free_tiles():
			if o != t and o.face == t.face:
				pr = [t, o]
				break
		if pr.is_empty():
			return
	for t in pr:
		t.hint(true)
	if secs > 0.0:
		get_tree().create_timer(secs).timeout.connect( func():
			for t in pr:
				if is_instance_valid(t) and t.alive and not t.pending:
					t.hint(false))


func _open_one(col: Color) -> bool:
	var bd: = _board()
	var want: = {}
	for x in bd.tray:
		want[x.face] = true
	var best: Tile = null
	for t in bd.tiles:
		if not bd.on_board(t) or t.pending or not t.secret:
			continue
		if best == null or (want.has(t.face) and not want.has(best.face)) or (want.has(t.face) == want.has(best.face) and t.step < best.step):
			best = t
	if best == null:
		return false
	best.reveal()
	_mark(_fx_layer(), pos_of(best), col, 0.9)
	return true


func _melt_one(col: Color) -> bool:
	var bd: = _board()
	for t in bd.tiles:
		if bd.on_board(t) and not t.pending and t.ice > 0:
			t.ice = 0
			t._update_ice()
			bd.reveal_free()
			_mark(_fx_layer(), pos_of(t), col, 0.9)
			return true
	var spec = bd.get("spec")
	if spec is Dictionary:
		for t in spec:
			var s: Dictionary = spec[t]
			if String(s.get("kind", "")) == "lock" and not bool(s.get("open", true)) and is_instance_valid(t) and t.alive:
				s.open = true
				if bd.has_method("_release"):
					bd._release(t)
				_mark(_fx_layer(), pos_of(t), col, 0.9)
				return true
	return false


func _return_one(col: Color) -> bool:
	var bd: = _board()
	if bd.tray.is_empty():
		return false
	var t: Tile = bd.tray.back()
	if t.pending:
		return false
	_mark(_fx_layer(), pos_of(t), col, 0.8)
	bd.tray.erase(t)
	bd.history.erase(t)
	bd.display.erase(t)
	bd._return(t)
	bd._layout_tray()
	bd.reveal_free()
	bd.tray_changed.emit()
	return true


func _oldest_twin(col: Color) -> bool:
	var bd: = _board()
	if bd.tray.is_empty():
		return false
	var o: Tile = bd.tray[0]
	var twin: Tile = null
	for t in bd.tiles:
		if t != o and bd.on_board(t) and not t.pending and t.face == o.face:
			if twin == null or (bd.is_free(t) and not bd.is_free(twin)):
				twin = t
	if twin == null:
		return false
	_hint_pair(3.0, [twin])
	_mark(_fx_layer(), pos_of(twin), col, 0.8)
	return true


func _rin_cup() -> bool:
	var pr = play.get_node_or_null("V7PassiveRun")
	if pr == null or String(pr.get("h")) != "rin":
		return false
	pr.cups = int(pr.cups) + 1
	pr._refresh_chip()
	pr._pulse("+1 чашка")
	return true


func _modifier(col: Color) -> void :
	if mod == "":
		return
	var done: = false
	var m: Dictionary = V9Ults.MODS.get(mod, {})
	var chip: = String(m.get("chip", m.get("name", "")))
	var chip_l: = mod
	match mod:
		"П":
			_hint_pair(3.0)
			done = true
		"О":
			done = _open_one(col)
		"Л":
			done = _melt_one(col)
			if not done:
				done = _open_one(col)
				chip = String(V9Ults.MODS["О"].chip)
				chip_l = "О"
		"В":
			done = _rin_cup() if hero == "rin" else _return_one(col)
			if hero == "rin":
				chip = "+1 чашка"
		"Ц":
			if hero in ["rin", "yue"]:
				var bp: = best_pairs(1)
				if not bp.is_empty():
					_hint_pair(3.0, bp[0])
			done = true
		"С":
			done = _oldest_twin(col)
	if not done:
		_hint_pair(3.0)
		chip = String(V9Ults.MODS["П"].chip)
		chip_l = "П"
	_mod_chip(chip, chip_l)


# the modifier's result as a small lacquer chip (gold glyph + player-facing line) that slides out to the LEFT of the
# portrait card, level with its ult bar: never on her portrait or its plates, never over the board
func _mod_chip(txt: String, letter: = "") -> void :
	var st: V6HeroStage = play.stage
	if txt == "" or st == null or not is_instance_valid(st):
		return
	var fs: = 18
	var f: = UI.font("body", 800)
	while fs > 16 and f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > 250.0:
		fs -= 1
	var tw: = minf(250.0, f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
	var h: = 40.0
	var w: = 14.0 + 26.0 + 8.0 + tw + 16.0
	var right: = st.position.x - 6.0
	# level with the bottom of the card, below the fortune panel's text, still clear of the board's frame
	var y: = minf(st.position.y + st.size.y - h + 8.0, (play.board_rect as Rect2).position.y - h - 4.0)
	if st.compact:
		right = st.position.x + st.size.x + 6.0 + w
		y = st.position.y + (st.size.y - h) * 0.5
	var c: = UI.rbox("plum", Rect2(right - w, y, w, h), h * 0.5, 2, 6)
	c.set_param("border_top", Color("ffe7a6")).set_param("border_bottom", Color("c58a2c"))
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.z_index = 230
	var ic: = V9ModIcon.make(letter if letter != "" else mod, 26.0)
	ic.position = Vector2(14.0, (h - 26.0) * 0.5)
	c.add_child(ic)
	var l: = UI.label(txt, fs, Color("fff2d2"), Color(0.08, 0.03, 0.1), 3, "body", 800)
	l.position = Vector2(14.0 + 26.0 + 8.0, 0)
	l.size = Vector2(tw + 4.0, h)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(l)
	play.add_child(c)
	c.pivot_offset = Vector2(w, h * 0.5)
	c.modulate.a = 0.0
	c.position.x += 18.0
	var tw2: = c.create_tween()
	tw2.tween_property(c, "modulate:a", 1.0, 0.16)
	tw2.parallel().tween_property(c, "position:x", c.position.x - 18.0, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw2.tween_interval(1.5)
	tw2.tween_property(c, "modulate:a", 0.0, 0.3)
	tw2.tween_callback(c.queue_free)
