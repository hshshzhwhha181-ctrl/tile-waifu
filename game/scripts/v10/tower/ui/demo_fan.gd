extends Control

# Demo / shot runner / selftest of part C (V10TowerFan + V10TowerSheets).
#   godot --path game res://scripts/v10/tower/ui/demo_fan.tscn                       interactive: a fan over a table
#   … -- --shots=<abs dir> [--fx=min]     every state as PNG (run under xvfb, 720x1280 and 720x1600)
#   … --headless … -- --selftest=1        FAN_UI_SELFTEST ok/total, exit 0 only when every check passes
# Runs use the real logic on a fake save: V10Pagoda._test_S / V10Journey._test_S, V10Pagoda.new_run /
# floor_clear / end_run, V10Journey.start / board_clear / finish. Nothing touches G.S or the disk.

const FOUNDERS: = ["mc", "rin", "hana", "yue", "nova"]
const HEAT12: = {"hourglass": 2, "fog": 2, "guards": 2}
const HEAT16: = {"hourglass": 3, "fog": 2, "guards": 2, "no_hint": 1, "no_undo": 1}
# UX_RULES §4.3 (jargon) and the «было» column of §4.2 plus the lane's own list (ульта, богиня, лихорадка, ₽, %)
const BANNED_SUB: = ["ульт", "богин", "лихорад", "фивер", "₽", "%", "гарант", "pity", "50/50", "гача", "крутк", "ивент",
	"квартал", "перк", "риичи", "банер", "донат", "выгодно", "успей", "последний шанс", "осталось n штук", "топ-100",
	"лунная лестница", "гардероб", "поручени", "сесть за стол", "следующая партия", "рядом с тобой", "каскад",
	"небесный поток", "лунный камень", "чайный абонемент", "осколок портрета", "капли росы", "цель ", "обмен"]
const BANNED_WORD: = ["пити", "ролл", "яку", "хит", "best", "new", "sr", "ssr+", "id", "визиты", "режимы", "камни"]

var shot_dir: = ""
var selftest: = false
var embedded: = false
var ok: = 0
var total: = 0
var fails: = []
var host: Control
var _done: = {}


func _ready() -> void:
	if embedded:
		V10TowerUtil.fake_now = V10TowerUtil.week_start(2900) + 3600 * 50
		V10TowerSheets.autosave = false
		_fake_saves()
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		return
	var args: = {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			args[a.substr(2, a.find("=") - 2)] = a.substr(a.find("=") + 1)
	shot_dir = String(args.get("shots", ""))
	selftest = String(args.get("selftest", "")) == "1"
	var fx: = String(args.get("fx", ""))
	if fx != "":
		V10Hud2Util.fx_override = fx
		V10Juice.forced_level = fx
	V10TowerUtil.fake_now = V10TowerUtil.week_start(2900) + 3600 * 50  # a Tuesday: dates, no countdown
	V10TowerSheets.autosave = false
	_fake_saves()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if selftest:
		get_tree().create_timer(400.0, true, false, true).timeout.connect(func() -> void:
			print("FAN_UI_SELFTEST watchdog: no result")
			get_tree().quit(4))
		await _selftest()
		return
	if shot_dir != "":
		await _shots()
		return
	host = self
	_state("fan_bless", self)


func _fake_saves() -> void:
	V10Pagoda._test_S = {"rp": 0}
	V10Journey._test_S = {"rp": 0}
	V10TowerFan.hint_shown = false


# ---------------------------------------------------------------- scenery under the sheets

class Table:
	extends Control
	var hub: = false

	func _init(is_hub: = false) -> void:
		hub = is_hub
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		var vs: = get_viewport_rect().size
		if hub:
			var far: = V10TowerArt.tex("pagoda_far")
			if far:
				draw_texture_rect(far, Rect2(Vector2.ZERO, vs), false)
				return
			draw_rect(Rect2(Vector2.ZERO, vs), V10DS.NIGHT_800)
			for i in 8:
				draw_circle(Vector2(vs.x * 0.7, vs.y * 0.22), 60.0 + i * 26.0, Color(V10TowerUI.MOON, 0.035))
			draw_circle(Vector2(vs.x * 0.7, vs.y * 0.22), 56.0, Color(V10TowerUI.MOON, 0.9))
			return
		# the felt and a few tiles left on it (the table the fan can be pulled away from)
		var cols: = PackedColorArray([V10DS.FELT_LO, V10DS.FELT_LO, V10DS.FELT_HI, V10DS.FELT_HI])
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(vs.x, 0), Vector2(vs.x, vs.y * 0.5), Vector2(0, vs.y * 0.5)]), cols)
		draw_polygon(PackedVector2Array([Vector2(0, vs.y * 0.5), Vector2(vs.x, vs.y * 0.5), Vector2(vs.x, vs.y), Vector2(0, vs.y)]),
			PackedColorArray([V10DS.FELT_HI, V10DS.FELT_HI, V10DS.FELT_LO, V10DS.FELT_LO]))
		var n: = 0
		for r in 5:
			for c in 6:
				if (r * 7 + c * 3) % 4 == 0:
					continue
				var t: = G.tile_tex((r * 6 + c) % 20)
				var p: = Vector2(96 + c * 92, vs.y * 0.18 + r * 112)
				draw_texture_rect(t, Rect2(p, Vector2(84, 100)), false)
				n += 1


# ---------------------------------------------------------------- scenarios (real logic on the fake save)

func _pagoda_run(curses: Dictionary, owned: Array) -> Dictionary:
	V10Pagoda._test_S = {"rp": 0}
	var run: = V10Pagoda.new_run("mc", curses, 4242)
	run["owned"] = owned
	run["released"] = FOUNDERS
	return run


# climb to `to_floor` (the floor about to be cleared), picking the first blessing each time; returns the cosmetics
func _climb(run: Dictionary, to_floor: int) -> Array:
	var got: = []
	while int(run.floor) < to_floor:
		var r: = V10Pagoda.floor_clear(run, {})
		got.append_array(r.get("cosmetics", []))
		if not (r.offer as Array).is_empty():
			V10Pagoda.pick_blessing(run, String(r.offer[0]))
	return got


# a Pagoda offer with exactly one «plus» card and one card already taken («уже ×N»)
func _bless_offer() -> Dictionary:
	var run: = _pagoda_run(HEAT12, ["yue"])
	for k in 40:
		var r: = V10Pagoda.floor_clear(run, {})
		var offer: Array = r.offer
		var plus: = offer.filter(func(i): return V10Mods.bless_plus(String(i), run))
		var have: = offer.filter(func(i): return int((run.bless as Dictionary).get(String(i), 0)) > 0)
		if plus.size() == 1 and have.size() >= 1 and offer.size() == 3:
			return {"run": run, "offer": offer}
		if not offer.is_empty():
			V10Pagoda.pick_blessing(run, String(offer[k % offer.size()]))
	return {"run": run, "offer": run.offer}


func _journey_run(practice: = false) -> Dictionary:
	var run: = V10Journey.start("mc", practice)
	run["owned"] = ["mc"]
	run["released"] = FOUNDERS
	return run


func _journey_full(secs: float, combo: int, practice: = false) -> Dictionary:
	var run: = _journey_run(practice)
	for b in V10Journey.BOARDS:
		var r: = V10Journey.board_clear(run, {"secs": secs, "max_combo": combo})
		if not (r.offer as Array).is_empty():
			V10Journey.pick_blessing(run, String(r.offer[0]))
	return V10Journey.finish(run)


# builds one state on `on`; returns {node, run, res, kind}
func _state(name: String, on: Control) -> Dictionary:
	for c in on.get_children():
		if c is Table or c.has_meta("tower_sheet") or c is V10TowerFan:
			c.queue_free()
	var d: = {"name": name}
	match name:
		"fan_bless", "fan_lifted", "fan_peek", "fan_min":
			on.add_child(Table.new())
			var o: = _bless_offer()
			var cards: = []
			for id in o.offer:
				cards.append(V10Mods.bless_card(String(id), o.run))
			var f: = V10TowerFan.open(on, cards, {"title": "Выбери благословение", "run": o.run, "mode": "pagoda"})
			d.node = f
			d.run = o.run
			d.cards = cards
			if name == "fan_lifted":
				_after(0.7, func() -> void:
					for i in cards.size():
						if bool(cards[i].plus):
							f.select(i))
			if name == "fan_peek":
				_after(0.7, func() -> void: f.set_peek(250.0))
		"fan_curse":
			on.add_child(Table.new())
			V10Journey._test_S = {"rp": 0}
			var run: = _journey_run()
			var r: = V10Journey.board_clear(run, {"secs": 80, "max_combo": 6})
			var cards2: = []
			for id in r.curse_offer:
				cards2.append(V10Mods.curse_card(String(id), 1, "journey"))
			var f2: = V10TowerFan.open(on, cards2, {"title": "Взять проклятие?", "subtitle": "Очки ×1,15 на каждом следующем столе",
				"can_skip": true, "skip_text": "Без проклятия", "run": run, "mode": "journey"})
			d.node = f2
			d.run = run
			d.cards = cards2
		"floor_normal", "floor_guard", "floor_flare":
			on.add_child(Table.new())
			var run3: = _pagoda_run(HEAT12, ["yue"])
			var to: int = {"floor_normal": 7, "floor_guard": 10, "floor_flare": 9}[name]
			_climb(run3, to)
			var res3: = V10Pagoda.floor_clear(run3, {"secs": 70, "pairs": 40, "max_combo": 7})
			d.node = V10TowerSheets.floor_clear(on, run3, res3, func(r) -> void: _done[name] = r)
			d.run = run3
			d.res = res3
		"board_clear", "board_done":
			on.add_child(Table.new())
			V10Journey._test_S = {"rp": 0}
			var run4: = _journey_run()
			var res4: = {}
			var n4: = 1 if name == "board_clear" else V10Journey.BOARDS
			for b in n4:
				res4 = V10Journey.board_clear(run4, {"secs": 74, "max_combo": 9})
				if b < n4 - 1 and not (res4.offer as Array).is_empty():
					V10Journey.pick_blessing(run4, String(res4.offer[0]))
			d.node = V10TowerSheets.board_clear(on, run4, res4, func(r) -> void: _done[name] = r)
			d.run = run4
			d.res = res4
		"pagoda_end":
			on.add_child(Table.new(true))
			var run5: = _pagoda_run(HEAT16, ["yue"])
			var cos: = _climb(run5, 16)
			var end_res: = V10Pagoda.end_run(run5)
			d.node = V10TowerSheets.pagoda_end(on, end_res, cos, func(r) -> void: _done[name] = r)
			d.res = end_res
			d.cos = cos
		"journey_gold", "journey_practice", "journey_claimed":
			on.add_child(Table.new(true))
			V10Journey._test_S = {"rp": 0}
			var fin: = {}
			if name == "journey_practice":
				fin = _journey_full(90.0, 6, true)
			else:
				fin = _journey_full(0.0, 15)
				if name == "journey_claimed":
					fin = _journey_full(160.0, 4)
			d.node = V10TowerSheets.journey_end(on, fin, func(r) -> void: _done[name] = r)
			d.res = fin
	return d


func _after(t: float, f: Callable) -> void:
	get_tree().create_timer(t, false).timeout.connect(f)


# ---------------------------------------------------------------- shots

const SHOTS: = [
	["fan_bless", 1.2], ["fan_lifted", 1.4], ["fan_curse", 1.2], ["fan_peek", 1.2],
	["floor_normal", 2.2], ["floor_guard", 2.4], ["floor_flare", 1.5, "floor_flare_burn"], ["floor_flare", 4.6],
	["board_clear", 0.9, "board_score"], ["board_clear", 2.4], ["board_clear", -1.0, "board_curse"], ["board_done", 1.6],
	["pagoda_end", 2.2], ["journey_gold", 2.4], ["journey_practice", 2.0], ["journey_claimed", 2.0]]


func _shots() -> void:
	DirAccess.make_dir_recursive_absolute(shot_dir)
	var vs: = get_viewport_rect().size
	var tag: = "%dx%d" % [int(vs.x), int(vs.y)]
	if V10Hud2Util.fx_override == "min":
		tag += "_min"
	for s in SHOTS:
		_fake_saves()
		var name: String = s[0]
		var file: String = s[2] if s.size() > 2 else name
		var d: = _state(name, self)
		var t: float = s[1]
		if t < 0.0:
			# board: take the blessing, then the curse fan is the shot
			await get_tree().create_timer(2.2).timeout
			var sh: Control = d.node
			var f: V10TowerFan = sh.get("fan")
			f.select(1)
			await get_tree().create_timer(0.4).timeout
			f.confirm()
			t = 1.6
		await get_tree().create_timer(t).timeout
		await RenderingServer.frame_post_draw
		var path: = shot_dir.path_join("%s_%s.png" % [file, tag])
		get_viewport().get_texture().get_image().save_png(path)
		print("shot ", path)
	get_tree().quit(0)


# ---------------------------------------------------------------- selftest

func check(cond: bool, what: String) -> void:
	total += 1
	if cond:
		ok += 1
	else:
		fails.append(what)
		print("  FAIL ", what)


func _selftest() -> void:
	Engine.time_scale = 3.0
	for vs in [Vector2i(720, 1280), Vector2i(720, 1600)]:
		var sv: = SubViewport.new()
		sv.size = vs
		sv.disable_3d = true
		sv.render_target_update_mode = SubViewport.UPDATE_DISABLED
		add_child(sv)
		var on: = Control.new()
		on.size = Vector2(vs)
		sv.add_child(on)
		var tag: = "%dx%d" % [vs.x, vs.y]
		for st in ["fan_bless", "fan_lifted", "fan_curse", "fan_peek", "floor_normal", "floor_guard", "floor_flare",
				"board_clear", "board_done", "pagoda_end", "journey_gold", "journey_practice", "journey_claimed"]:
			_fake_saves()
			var mark: = V10Type.overflow.size()
			var d: = _state(st, on)
			await _wait(2.4 if st != "floor_flare" else 4.8)
			_audit("%s@%s" % [st, tag], on, Vector2(vs), mark)
			if st == "board_clear":
				# the second beat: blessing picked → the curse fan («Без проклятия»), audited again
				var sh: Control = d.node
				var f: V10TowerFan = sh.get("fan")
				var id: = f.card_id(0)
				var had: = int((d.run.bless as Dictionary).get(id, 0))
				f.select(0)
				f.confirm()
				await _wait(1.6)
				check(int((d.run.bless as Dictionary).get(id, 0)) == had + 1, "board_clear: V10Journey.pick_blessing applied (%s)" % id)
				_audit("board_curse@%s" % tag, on, Vector2(vs), V10Type.overflow.size())
		sv.queue_free()
		await get_tree().process_frame
	await _signals()
	Engine.time_scale = 1.0
	print("FAN_UI_SELFTEST %d/%d" % [ok, total])
	if not fails.is_empty():
		print("FAILED: ", fails)
	if not embedded:
		get_tree().quit(0 if ok == total else 1)


func run_embedded() -> Dictionary:
	await _selftest()
	V10TowerSheets.autosave = true
	V10Pagoda._test_S = null
	V10Journey._test_S = null
	V10TowerUtil.fake_now = 0
	Engine.time_scale = 1.0
	return {"ok": ok, "total": total, "fails": fails.duplicate()}


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _alpha(n: CanvasItem) -> float:
	var a: = 1.0
	var p: Node = n
	while p and p is CanvasItem:
		a *= (p as CanvasItem).modulate.a
		p = p.get_parent()
	return a * n.self_modulate.a


func _under(n: Node, meta: String) -> bool:
	var p: = n
	while p:
		if p.has_meta(meta):
			return true
		p = p.get_parent()
	return false


func _collect(n: Node, out: Dictionary) -> void:
	if n is CanvasItem and not (n as CanvasItem).visible:
		return
	if n is Label:
		(out.labels as Array).append(n)
	if n is V10Button:
		(out.buttons as Array).append(n)
	if n is V10TowerFan.CardView:
		(out.cards as Array).append(n)
	if n.has_meta("reward_token"):
		(out.tokens as Array).append(n)
	for c in n.get_children():
		_collect(c, out)


func _poly(c: Control) -> PackedVector2Array:
	var xf: = c.get_global_transform()
	var s: = c.size
	return PackedVector2Array([xf * Vector2.ZERO, xf * Vector2(s.x, 0), xf * s, xf * Vector2(0, s.y)])


func _aabb(p: PackedVector2Array) -> Rect2:
	var r: = Rect2(p[0], Vector2.ZERO)
	for q in p:
		r = r.expand(q)
	return r


func _text_rect(l: Label) -> Rect2:
	var ls: = l.label_settings
	var sz: = ls.font_size if ls else 22
	var role: = String(l.get_meta("v10_role", "ui"))
	var w: = minf(l.size.x, V10Type.text_w(l.text, role, sz))
	var lines: = 1 if l.autowrap_mode == TextServer.AUTOWRAP_OFF else mini(maxi(1, l.max_lines_visible), V10Type.lines_needed(l.text, role, sz, l.size.x))
	var h: = float(V10Type.line_h(sz)) * lines
	var x: = 0.0
	if l.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER:
		x = (l.size.x - w) * 0.5
	elif l.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT:
		x = l.size.x - w
	var y: = 0.0
	if l.vertical_alignment == VERTICAL_ALIGNMENT_CENTER:
		y = (l.size.y - h) * 0.5
	return Rect2(l.global_position + Vector2(x, y), Vector2(w, h)).grow(-2.0)


func _banned(text: String) -> String:
	var low: = text.to_lower()
	for b in BANNED_SUB:
		if low.contains(b):
			return b
	var word: = ""
	for ch in low + " ":
		var u: = ch.unicode_at(0)
		var letter: = (u >= 97 and u <= 122) or (u >= 0x430 and u <= 0x44F) or u == 0x451 or ch == "+" or (u >= 48 and u <= 57)
		if letter:
			word += ch
		else:
			if word in BANNED_WORD:
				return word
			word = ""
	return ""


func _audit(name: String, root: Control, vs: Vector2, mark: int) -> void:
	var r: = V10TowerUI.roles_of(root)
	check(int(r.primary) == 1, "%s: exactly 1 primary (got %d)" % [name, int(r.primary)])
	check(int(r.secondary) <= 2, "%s: ≤ 2 secondary (got %d)" % [name, int(r.secondary)])
	check(int(r.tertiary) <= 2, "%s: ≤ 2 tertiary (got %d)" % [name, int(r.tertiary)])
	var got: = {"labels": [], "buttons": [], "cards": [], "tokens": []}
	_collect(root, got)
	check((got.tokens as Array).size() <= 3, "%s: ≤ 3 reward tokens (got %d)" % [name, (got.tokens as Array).size()])
	# words and sizes of every visible line
	var bad_word: = ""
	var bad_size: = ""
	var shown: = []
	for l in got.labels:
		var lb: Label = l
		if lb.text.strip_edges() == "" or _alpha(lb) < 0.05:
			continue
		var w: = _banned(lb.text)
		if w != "":
			bad_word += "«%s» (%s) " % [lb.text, w]
		var sz: = lb.label_settings.font_size if lb.label_settings else 16
		var role: = String(lb.get_meta("v10_role", ""))
		if sz < 18 and not (role == "overline" and sz == 15 and lb.text == lb.text.to_upper()):
			bad_size += "«%s» %d " % [lb.text, sz]
		shown.append(lb)
	check(bad_word == "", "%s: no banned words %s" % [name, bad_word])
	check(bad_size == "", "%s: text ≥ 18 px (Overline 15 caps only) %s" % [name, bad_size])
	# nothing cut: no ellipsis fallback in this state
	var cut: = []
	for k in range(mark, V10Type.overflow.size()):
		cut.append(String(V10Type.overflow[k].text))
	check(cut.is_empty(), "%s: no truncated text %s" % [name, cut])
	# tappable things: ≥ 80 px, inside the screen, no two overlap (cards as rotated polygons)
	var taps: = []
	for b in got.buttons:
		if _alpha(b) > 0.05:
			taps.append(b)
	for c in got.cards:
		if _alpha(c) > 0.05:
			taps.append(c)
	var screen: = Rect2(Vector2.ZERO, vs)
	var small: = ""
	var outside: = ""
	for t in taps:
		var tc: Control = t
		var bb: = _aabb(_poly(tc))
		if tc.size.x < 80.0 or tc.size.y < 80.0:
			small += "%s %s " % [tc.name, tc.size]
		if not screen.grow(0.5).encloses(bb):
			outside += "%s %s " % [tc.get_class(), bb]
	check(small == "", "%s: hit zones ≥ 80 px %s" % [name, small])
	check(outside == "", "%s: tappables inside the screen %s" % [name, outside])
	var cross: = ""
	for i in taps.size():
		for j in range(i + 1, taps.size()):
			var pa: = _poly(taps[i])
			var pb: = _poly(taps[j])
			if not Geometry2D.intersect_polygons(pa, pb).is_empty():
				cross += "%s×%s " % [(taps[i] as Node).name, (taps[j] as Node).name]
	check(cross == "", "%s: tappables do not overlap %s" % [name, cross])
	# text lines do not run into each other (straight lines of the sheet; card texts are checked in card space)
	var flat: = shown.filter(func(l): return not _under(l, "tower_card") and not _under(l, "heat_flare"))
	var hit: = ""
	for i in flat.size():
		for j in range(i + 1, flat.size()):
			if _text_rect(flat[i]).intersects(_text_rect(flat[j])):
				hit += "«%s»×«%s» " % [(flat[i] as Label).text, (flat[j] as Label).text]
	check(hit == "", "%s: no text overlaps %s" % [name, hit])
	# cards: name / title / effect stacked inside the card, the face never under the text
	var card_bad: = ""
	for c in got.cards:
		var cv: V10TowerFan.CardView = c
		var top: = cv.name_l.position.y
		var t_end: = cv.title_l.position.y + cv.title_l.size.y
		var ok_stack: = top + 18.0 <= cv.title_l.position.y and t_end <= cv.line_l.position.y + 1.0 \
			and cv.line_l.position.y + cv.line_l.size.y <= V10TowerFan.CARD.y - 8.0
		var face_bottom: = V10TowerFan.CardView.FACE_C.y + V10TowerFan.CardView.FACE_W * 0.72
		var ok_face: = cv.kind != "bless" or (top - (40.0 if cv.badge_l else 0.0) >= face_bottom - 40.0 and V10TowerFan.CardView.FACE_C.y - V10TowerFan.CardView.FACE_W * 0.7 >= 0.0)
		if not ok_stack or not ok_face:
			card_bad += "%s " % cv.data.get("id", "?")
	check(card_bad == "", "%s: card texts stacked, faces whole %s" % [name, card_bad])
	# words budget of a working screen (UX §3.7: ≤ 60)
	var words: = 0
	for l in shown:
		words += (l as Label).text.split(" ", false).size()
	check(words <= 60, "%s: words on the sheet %d (≤ 60)" % [name, words])


# signals, on_done and the logic calls (720×1280)
func _signals() -> void:
	var sv: = SubViewport.new()
	sv.size = Vector2i(720, 1280)
	sv.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(sv)
	var on: = Control.new()
	on.size = Vector2(720, 1280)
	sv.add_child(on)
	# 1. the fan: tap lifts, a second tap on the lifted card confirms → picked(id)
	_fake_saves()
	var d: = _state("fan_bless", on)
	var f: V10TowerFan = d.node
	var got: = []
	f.picked.connect(func(id: String) -> void: got.append(id))
	await _wait(0.8)
	var c1: Vector2 = (f.slots[1] as Control).get_global_transform() * (V10TowerFan.CARD * 0.5)
	f.tap_at(c1)
	await _wait(0.4)
	check(f.sel == 1, "fan: a tap lifts the card under the finger")
	check(bool(f.take_b.get_meta("ux_ready", false)), "fan: «Взять» is ready after a lift")
	var c1b: Vector2 = (f.slots[1] as Control).get_global_transform() * (V10TowerFan.CARD * 0.5)
	f.tap_at(c1b)
	await _wait(1.0)
	check(got == [f.card_id(1)] if is_instance_valid(f) else got.size() == 1 and got[0] == String(d.cards[1].id), "fan: second tap → picked(%s) %s" % [String(d.cards[1].id), got])
	# «Взять» before a lift: a «no», nothing picked
	_fake_saves()
	d = _state("fan_bless", on)
	f = d.node
	var got2: = []
	f.picked.connect(func(id: String) -> void: got2.append(id))
	await _wait(0.8)
	f.take_b.pressed.emit()
	await _wait(0.6)
	check(got2.is_empty() and not f.done, "fan: «Взять» without a card does nothing")
	f.select(2)
	f.take_b.pressed.emit()
	await _wait(1.0)
	check(got2 == [String(d.cards[2].id)], "fan: «Взять» confirms the lifted card %s" % [got2])
	# a swipe down: «показать стол» and back
	_fake_saves()
	d = _state("fan_bless", on)
	f = d.node
	var peeks: = []
	f.peek_changed.connect(func(k: float) -> void: peeks.append(k))
	await _wait(0.8)
	var p0: Vector2 = (f.slots[0] as Control).get_global_transform() * (V10TowerFan.CARD * 0.5)
	var ev: = InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.global_position = p0
	f._zone_input(ev)
	var mv: = InputEventMouseMotion.new()
	mv.global_position = p0 + Vector2(0, 220)
	f._zone_input(mv)
	check(f.peek > 150.0 and f.deck.position.y > 150.0, "fan: a drag down moves the fan away (peek %d)" % int(f.peek))
	var up: = InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.global_position = p0 + Vector2(0, 220)
	f._zone_input(up)
	await _wait(0.5)
	check(f.peek < 1.0 and f.sel == -1, "fan: release brings it back, nothing lifted")
	check(not peeks.is_empty() and peeks.max() > 0.3, "fan: peek_changed emitted")
	# skip
	_fake_saves()
	d = _state("fan_curse", on)
	f = d.node
	var sk: = [0]
	f.skipped.connect(func() -> void: sk[0] += 1)
	await _wait(0.8)
	f.skip_b.pressed.emit()
	await _wait(0.5)
	check(sk[0] == 1, "fan: «Без проклятия» → skipped")
	# 2. floor_clear: pick → V10Pagoda.pick_blessing on the run, then «Выше» → next; «В Пагоду» → leave
	_fake_saves()
	_done.clear()
	d = _state("floor_normal", on)
	var sh: Control = d.node
	await _wait(1.6)
	var fan: V10TowerFan = sh.get("fan")
	var id: = fan.card_id(1)
	var before: = int((d.run.bless as Dictionary).get(id, 0))
	fan.select(1)
	fan.confirm()
	await _wait(1.2)
	check(int((d.run.bless as Dictionary).get(id, 0)) == before + 1 and (d.run.offer as Array).is_empty(), "floor_clear: V10Pagoda.pick_blessing applied (%s)" % id)
	var prim: V10Button = sh.get("prim")
	check(prim.visible and V10TowerUI.roles_of(sh).primary == 1, "floor_clear: «Выше» is the one primary after the pick")
	check(prim.text == "Выше · этаж %d" % int(d.run.floor), "floor_clear: «%s»" % prim.text)
	prim.pressed.emit()
	await _wait(0.1)
	check(_done.get("floor_normal", {}) == {"action": "next"}, "floor_clear: on_done(next) %s" % [_done.get("floor_normal")])
	_fake_saves()
	_done.clear()
	d = _state("floor_guard", on)
	sh = d.node
	await _wait(1.0)
	(sh.get("sec") as V10Button).pressed.emit()
	await _wait(0.1)
	check(_done.get("floor_guard", {}) == {"action": "leave"}, "floor_clear: «В Пагоду» → on_done(leave)")
	check(not (d.run.offer as Array).is_empty(), "floor_clear: leaving keeps the offer in the run")
	# 3. board_clear: blessing, curse (take), next; curse skipped; 5/5 → finish
	for take in [true, false]:
		_fake_saves()
		_done.clear()
		d = _state("board_clear", on)
		sh = d.node
		await _wait(1.6)
		fan = sh.get("fan")
		fan.select(0)
		fan.confirm()
		await _wait(1.4)
		fan = sh.get("fan")
		var cid: = fan.card_id(1)
		check(fan.cards.size() == 2 and String(fan.cards[0].kind) == "curse", "board_clear: then 1 of 2 curses")
		if take:
			fan.select(1)
			fan.confirm()
		else:
			fan.skip_b.pressed.emit()
		await _wait(1.2)
		if take:
			check((d.run.curses as Dictionary).has(cid), "board_clear: V10Journey.take_curse applied (%s)" % cid)
		else:
			check((d.run.curses as Dictionary).is_empty() and (d.run.curse_offer as Array).is_empty(), "board_clear: «Без проклятия» keeps the run clean")
		prim = sh.get("prim")
		check(prim.visible and V10TowerUI.roles_of(sh).primary == 1, "board_clear: «Дальше» is the one primary")
		prim.pressed.emit()
		await _wait(0.1)
		check(_done.get("board_clear", {}) == {"action": "next"}, "board_clear: on_done(next)")
	_fake_saves()
	_done.clear()
	d = _state("board_done", on)
	sh = d.node
	await _wait(1.0)
	(sh.get("prim") as V10Button).pressed.emit()
	await _wait(0.1)
	check(_done.get("board_done", {}) == {"action": "finish"}, "board_clear 5/5: on_done(finish)")
	# 4. the end sheets
	_fake_saves()
	_done.clear()
	d = _state("pagoda_end", on)
	sh = d.node
	check((d.cos as Array).size() == 2, "pagoda_end: two cosmetics earned on the real climb %s" % [d.cos])
	await _wait(1.0)
	var cos_tokens: = 0
	for c in _all(sh):
		if c.has_meta("cos"):
			cos_tokens += 1
	check(cos_tokens == 2, "pagoda_end: cosmetics shown as tokens")
	(sh.get("prim") as V10Button).pressed.emit()
	await _wait(0.1)
	check(_done.get("pagoda_end", {}) == {"action": "again"}, "pagoda_end: «Новое восхождение» → again")
	_fake_saves()
	_done.clear()
	d = _state("pagoda_end", on)
	sh = d.node
	await _wait(1.0)
	(sh.get("sec") as V10Button).pressed.emit()
	await _wait(0.1)
	check(_done.get("pagoda_end", {}) == {"action": "hub"}, "pagoda_end: «К Пагоде» → hub")
	for st in ["journey_gold", "journey_practice", "journey_claimed"]:
		_fake_saves()
		_done.clear()
		d = _state(st, on)
		sh = d.node
		await _wait(1.0)
		var texts: = _texts(sh)
		match st:
			"journey_gold":
				check(int(d.res.tier) == 2 and _has_meta(sh, "tier_seal"), "journey_end: Золото stamped (tier %d)" % int(d.res.tier))
				check(texts.has("выдана за лучшую попытку недели"), "journey_end: reward note")
			"journey_practice":
				check(texts.has("Тренировка: без наград") and (d.res.reward as Dictionary).is_empty(), "journey_end: practice has no rewards")
			"journey_claimed":
				check(texts.has("Награда недели уже получена") and (d.res.reward as Dictionary).is_empty(), "journey_end: reward once a week")
		(sh.get("prim") as V10Button).pressed.emit()
		await _wait(0.1)
		check(_done.get(st, {}) == {"action": "hub"}, "%s: «Готово» → hub" % st)
	# 5. the heat flare leaves by itself and takes no taps
	var fl: = V10TowerSheets.flare_node(on, V10Mods.curse_card("fog", 2, "pagoda"))
	check(fl.mouse_filter == Control.MOUSE_FILTER_IGNORE, "heat_flare: never takes a tap")
	await _wait(V10TowerSheets.Flare.DURATION + 0.6)
	check(not is_instance_valid(fl), "heat_flare: gone after %.1f s" % V10TowerSheets.Flare.DURATION)
	sv.queue_free()


func _all(n: Node) -> Array:
	var out: = [n]
	for c in n.get_children():
		out.append_array(_all(c))
	return out


func _has_meta(n: Node, m: String) -> bool:
	for c in _all(n):
		if c.has_meta(m):
			return true
	return false


func _texts(n: Node) -> Array:
	var out: = []
	for c in _all(n):
		if c is Label:
			out.append((c as Label).text)
	return out
