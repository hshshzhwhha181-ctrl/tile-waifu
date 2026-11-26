class_name V10MjClassicMemory
extends Control

# «Память» — a variant of «Классика» (MODES §4.1): a flat grid 4×4 … 6×6 face down; the backs carry her crest
# (art: assets/v10/mj/classic/crest_<hero>.png on the v06 tile back). Open two: alike — they leave the table with
# her wink; not alike — they turn back. Mistakes are free; stars by the number of moves.
#   setup(main, args) — args: size ("4x4" | "4x5" | "5x6" | "6x6"), hero, seed, presence (as in the Classic screen:
#                       V10MjPresence of the stage lane, "stage", or nothing = the built-in V10MjClassicPresence), fx,
#                       no_save, result_sheet (false: the integrator shows its own result)
#   signal finished(result) — {mode: "classic", variant: "memory", size, win, stars, moves, pairs, time_s, ults, hero,
#                              seed, score, rewards, next}
# Her Приём (MODES §5.5): the ring fills with found pairs; mc / nova find 1 pair, hana 2, rin shows one pair for 1 s,
# yue turns every card up for 1 s. Pairs found by a Приём are not moves and give no charge.

signal finished(result: Dictionary)

const BACK_TEX: = preload("res://assets/v06/flip/tile_back.png")
const TRIM_TEX: = preload("res://assets/v06/flip/tile_back_trim.png")
const BAND_MIN: = 120.0
const BAND_MAX: = 380.0

var args: = {}
var size_id: = "4x4"
var cols: = 4
var rows: = 4
var hero: = "mc"
var seed_: = 1
var fx: = "full"
var no_save: = false
var faces: = PackedInt32Array()
var matched: = PackedByteArray()
var open: Array = []
var moves: = 0
var found: = 0
var time_s: = 0.0
var running: = false
var cards: Array = []
var layer: Node2D
var presence: Object
var goal: Label
var pause_btn: V10MjClassicStyle.Btn
var field: Rect2
var band_h: = BAND_MIN
var sheet: Control
var result: = {}
var lite: V10MjClassicPresence
var charge: = 0
var need: = 4
var ults: = 0
var peeking: = false
var _close_timer: SceneTreeTimer


# ---- pure rules (selftest) -------------------------------------------------------------------------------------
static func dims(sz: String) -> Vector2i:
	var p: = sz.split("x")
	return Vector2i(int(p[0]), int(p[1])) if p.size() == 2 else Vector2i(4, 4)


static func deal(sz: String, s: int) -> PackedInt32Array:
	var d: = dims(sz)
	var n: = d.x * d.y
	var rng: = RandomNumberGenerator.new()
	rng.seed = s
	var pool: Array = range(36)
	for i in range(pool.size() - 1, 0, -1):
		var j: = rng.randi_range(0, i)
		var t = pool[i]
		pool[i] = pool[j]
		pool[j] = t
	var out: Array = []
	for k in n / 2:
		out.append(pool[k])
		out.append(pool[k])
	for i in range(out.size() - 1, 0, -1):
		var j2: = rng.randi_range(0, i)
		var t2 = out[i]
		out[i] = out[j2]
		out[j2] = t2
	return PackedInt32Array(out)


static func stars_for(moves_: int, pairs: int) -> int:
	if moves_ <= int(round(pairs * 1.75)):
		return 3
	if moves_ <= int(round(pairs * 2.5)):
		return 2
	return 1


# ---- screen -----------------------------------------------------------------------------------------------------
func build(main_: Node, a: Dictionary = {}) -> void:
	setup(main_, a)


func setup(_main: Node, a: Dictionary) -> void:
	args = a
	size_id = String(a.get("size", "4x4"))
	var d: = dims(size_id)
	cols = d.x
	rows = d.y
	hero = String(a.get("hero", "mc"))
	seed_ = int(a.get("seed", randi() % 1000000 + 1))
	fx = String(a.get("fx", G.fx_level() if G.has_method("fx_level") else "full"))
	no_save = bool(a.get("no_save", false))
	faces = deal(size_id, seed_)
	matched.resize(faces.size())
	matched.fill(0)
	need = int(a.get("need", maxi(3, faces.size() / 2 / 3)))
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if is_inside_tree() and layer == null:
		_build()


func _ready() -> void:
	if layer == null and not args.is_empty():
		_build()


func _build() -> void:
	var T: = V10MjClassicStyle.TOK
	var vs: = get_viewport_rect().size
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var extra: = maxf(0.0, vs.y - 1280.0 * vs.x / 720.0)
	band_h = clampf(BAND_MIN + extra, BAND_MIN, BAND_MAX)
	var bg: = TextureRect.new()
	var bgp: = "res://assets/bg/%s.webp" % V10MjClassicStyle.HERO_BG.get(hero, "menu_blur")
	if ResourceLoader.exists(bgp):
		bg.texture = load(bgp)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.size = vs
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var sh: = ColorRect.new()
	sh.color = Color(T.night900, 0.6)
	sh.size = vs
	sh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sh)
	field = Rect2(20, band_h + 24, vs.x - 40, vs.y - band_h - 24 - 80)
	var cloth: = _Cloth.new()
	cloth.position = field.position - Vector2(12, 12)
	cloth.size = field.size + Vector2(24, 24)
	cloth.col = V10MjClassicStyle.accent(hero)
	add_child(cloth)
	layer = Node2D.new()
	add_child(layer)
	var cell: = minf(field.size.x / cols, field.size.y / rows)
	var s: = minf(1.6, cell * 0.88 / Tile.TW)
	var deep: = V10MjClassicStyle.accent(hero).darkened(0.55)
	var crest: = crest_tex(hero)
	var grid_sz: = Vector2(cols, rows) * cell
	var origin: = field.position + (field.size - grid_sz) * 0.5 + Vector2(cell, cell) * 0.5
	for i in faces.size():
		var c: = _MemCard.new()
		c.idx = i
		c.position = origin + Vector2(i % cols, i / cols) * cell
		c.home = c.position
		c.base = s
		c.scale = Vector2(s, s)
		layer.add_child(c)
		var lk = args.get("look", {})
		c.build(faces[i], deep, crest, lk if lk is Dictionary else {})
		cards.append(c)
	pause_btn = V10MjClassicStyle.Btn.new("quiet", "", "pause")
	pause_btn.backdrop = true
	pause_btn.size = Vector2(80, 80)
	pause_btn.position = Vector2(14, (band_h - 80) * 0.5 if band_h <= 140 else 20)
	pause_btn.pressed.connect(_pause)
	add_child(pause_btn)
	goal = V10MjClassicStyle.label("", 24, T.paper100, "body", 800)
	V10MjClassicStyle.shadow(goal, 0.5)
	goal.position = Vector2(104, pause_btn.position.y + 22)
	add_child(goal)
	var r: = V10MjClassicPresence.resolve(args.get("presence", null), self, hero, {"band_rect": Rect2(0, 0, vs.x, band_h),
		"z": 400, "fx": fx, "charge_need": need, "seed": seed_, "avoid": [pause_btn.get_global_rect(),
		Rect2(goal.global_position, Vector2(320, 50))]})
	presence = r[0]
	lite = r[1]
	if presence.has_signal("portrait_tapped"):
		presence.connect("portrait_tapped", try_ult)
	presence.sacred(field)
	_refresh()
	running = true
	# the deal: the cards land face down from her side, row by row
	if fx != "min":
		for c in cards:
			var d: float = 0.03 * c.idx
			c.position = c.home + Vector2(0, -40)
			c.modulate.a = 0.0
			var tw: Tween = c.create_tween()
			tw.tween_interval(d)
			tw.tween_property(c, "modulate:a", 1.0, 0.12)
			tw.parallel().tween_property(c, "position", c.home, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


class _Cloth:
	extends Control
	var col: = Color.WHITE
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var T: = V10MjClassicStyle.TOK
		var sb: = StyleBoxFlat.new()
		sb.bg_color = Color(T.night800, 0.78)
		sb.set_corner_radius_all(4)
		sb.border_color = Color(T.gold700, 0.35)
		sb.set_border_width_all(1)
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		draw_circle(size * Vector2(0.5, 0.42), minf(size.x, size.y) * 0.45, Color(col, 0.06))


class _MemCard:
	extends Node2D
	var idx: = 0
	var home: = Vector2.ZERO
	var base: = 1.0
	var face_up: = false
	var tile: Tile
	var back: Node2D
	var _tw: Tween
	func build(f: int, deep: Color, crest: Texture2D, look: = {}) -> void:
		tile = Tile.new()
		tile.face = f
		add_child(tile)
		var lk: Dictionary = look
		if lk.is_empty():
			lk = G.skin_look() if G.has_method("skin_look") else {"side": Color("e8789f"), "rim": Color("f6dfe6"), "tint": Color.WHITE}
		tile.build(lk)
		if lk.has("v10mj") and ResourceLoader.exists(V10MjClassicBoard.LOOK_LIB):
			load(V10MjClassicBoard.LOOK_LIB).dress(tile, lk, {})
		tile.visible = false
		back = Node2D.new()
		add_child(back)
		var sh: = Sprite2D.new()
		sh.texture = G.fx("tile_shadow")
		sh.scale = Vector2(Tile.S, Tile.S) * 1.04
		sh.position = Vector2(6, 10)
		sh.modulate = Color(0, 0, 0, 0.45)
		back.add_child(sh)
		var body: = Sprite2D.new()
		body.texture = BACK_TEX
		body.scale = Vector2(Tile.S, Tile.S)
		body.modulate = deep.lerp(Color("2a1f2c"), 0.25)
		back.add_child(body)
		var trim: = Sprite2D.new()
		trim.texture = TRIM_TEX
		trim.scale = Vector2(Tile.S, Tile.S)
		trim.modulate = Color("e8c47e")
		back.add_child(trim)
		if crest:
			var cr: = Sprite2D.new()
			cr.texture = crest
			var k: = Tile.TW * 0.66 / crest.get_width()
			cr.scale = Vector2(k, k)
			cr.position = Vector2(-1, -3)
			back.add_child(cr)
	func turn(up: bool, fast: = false) -> void:
		face_up = up
		if _tw and _tw.is_valid():
			_tw.kill()
		if fast:
			tile.visible = up
			back.visible = not up
			scale = Vector2(base, base)
			return
		_tw = create_tween()
		_tw.tween_property(self, "scale", Vector2(0.0, base * 1.06), 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_tw.tween_callback(func():
			tile.visible = up
			back.visible = not up)
		_tw.tween_property(self, "scale", Vector2(base, base), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	func hit(gp: Vector2) -> bool:
		var lp: = (gp - global_position) / base
		return absf(lp.x) <= Tile.TW * 0.5 + 4 and absf(lp.y) <= Tile.TH * 0.5 + 4


# her crest on the backs (founders have one; anyone else wears the house crest of Маджонг-тян)
static func crest_tex(h: String) -> Texture2D:
	for k in [h, "mc"]:
		var p: = "res://assets/v10/mj/classic/crest_%s.png" % k
		if ResourceLoader.exists(p):
			return load(p)
	return null


func goal_text() -> String:
	return "Пар %d из %d · ходов %d" % [found, faces.size() / 2, moves]


func _refresh() -> void:
	goal.text = goal_text()


func _process(dt: float) -> void:
	if running and sheet == null:
		time_s += dt
	if presence and "input_on" in presence:
		presence.input_on = running and sheet == null and not peeking


func _unhandled_input(e: InputEvent) -> void:
	if not running or sheet != null or peeking:
		return
	if e is InputEventScreenTouch and e.pressed:
		for c in cards:
			if matched[c.idx] == 0 and c.visible and c.hit(e.position):
				get_viewport().set_input_as_handled()
				flip(c.idx)
				return


# open one card (the selftest and demo call it directly)
func flip(i: int) -> void:
	if not running or peeking or matched[i] or i in open:
		return
	var c: _MemCard = cards[i]
	if open.size() >= 2:
		# a third card while two mismatched still show: they turn back at once, play goes on
		for j in open:
			(cards[j] as _MemCard).turn(false, fx == "min")
		open.clear()
	open.append(i)
	c.turn(true, fx == "min")
	V9Feel.tile_tap(true)
	if presence:
		presence.on("pick", {"pos": c.global_position})
	if open.size() == 2:
		moves += 1
		var a: int = open[0]
		var b: int = open[1]
		if faces[a] == faces[b]:
			matched[a] = 1
			matched[b] = 1
			found += 1
			open.clear()
			charge = mini(need, charge + 1)
			_take(a, b)
		else:
			V9Feel.sound("tap", 0.8, -6.0)
			var snap: = [a, b]
			get_tree().create_timer(0.8).timeout.connect(func():
				if open == snap:
					for j in snap:
						(cards[j] as _MemCard).turn(false, fx == "min")
					open.clear())
		_refresh()


func _take(a: int, b: int) -> void:
	var ca: _MemCard = cards[a]
	var cb: _MemCard = cards[b]
	var mid: = (ca.position + cb.position) * 0.5
	V9Feel.tile_match(found)
	if presence:
		presence.on("pair", {"pos": layer.get_global_transform_with_canvas() * mid, "charge": float(charge) / float(need)})
		presence.on("motif", {})  # her wink on every match
		if found == faces.size() / 2 - 1:
			presence.on("last_pair", {})
	for c in [ca, cb]:
		c.z_index = 20
		if fx == "min":
			c.visible = false
			continue
		var tw: Tween = c.create_tween()
		tw.tween_interval(0.25)
		tw.tween_property(c, "position", mid + (c.position - mid) * 0.35 + Vector2(0, -24), 0.16).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		tw.tween_property(c, "scale", Vector2(0.2, 0.2) * c.base, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(c, "modulate:a", 0.0, 0.2)
		tw.tween_callback(func(): c.visible = false)
	if fx != "min" and V9Feel.can_fx():
		get_tree().create_timer(0.42).timeout.connect(func():
			Fx.burst(layer, mid, "sparkle", 10, V10MjClassicStyle.accent(hero).lightened(0.3), 0.8))
	if found == faces.size() / 2:
		running = false
		_win()


# ---- Приём ---------------------------------------------------------------------------------------------------
func try_ult() -> bool:
	if not running or sheet != null or peeking:
		return false
	if charge < need:
		if lite:
			lite.bounce()
		return false
	charge = 0
	ults += 1
	presence.on("ult", {"charge": 0.0})
	if lite:
		lite.set_charge(0.0)
	V9Feel.sound("summon_charge", 1.2, -6.0)
	for j in open:
		(cards[j] as _MemCard).turn(false, true)
	open.clear()
	var e: = V10MjClassicUlts.memory_effect(hero)
	match String(e.kind):
		"find":
			for k in int(e.n):
				var ps: = peek_pairs()
				if ps.is_empty() or not running:
					break
				var pr: Array = ps[0]
				for i in pr:
					(cards[i] as _MemCard).turn(true, fx == "min")
				matched[pr[0]] = 1
				matched[pr[1]] = 1
				found += 1
				_take(pr[0], pr[1])
			_refresh()
		"peek_pair":
			var ps2: = peek_pairs()
			if not ps2.is_empty():
				_peek(ps2[0], float(e.t))
		"peek_all":
			var all: = []
			for pr2 in peek_pairs():
				all.append_array(pr2)
			_peek(all, float(e.t))
	return true


# turn cards face up for t seconds, then back; taps wait
func _peek(ids: Array, t: float) -> void:
	peeking = true
	for i in ids:
		(cards[i] as _MemCard).turn(true, fx == "min")
	get_tree().create_timer(t).timeout.connect(func():
		for i in ids:
			if not matched[i]:
				(cards[i] as _MemCard).turn(false, fx == "min")
		peeking = false)


func peek_pairs() -> Array:
	var by: = {}
	for i in faces.size():
		if not matched[i]:
			by[faces[i]] = by.get(faces[i], []) + [i]
	return by.values()


func _win() -> void:
	var stars: = stars_for(moves, faces.size() / 2)
	result = _result(true)
	result.stars = stars
	result.score = stars * 100
	if not no_save:
		var rec: = V10MjClassicData.record(result)
		result.rewards = rec.rewards
		result["new_best"] = rec.new_best
	if presence:
		presence.on("win", {"text": "Все нашлись. У тебя хорошая память."})
	if not bool(args.get("result_sheet", true)):
		get_tree().create_timer(0.3 if fx == "min" else 1.4).timeout.connect(func(): finished.emit(result))
		return
	get_tree().create_timer(0.3 if fx == "min" else 1.4).timeout.connect(_result_sheet)


func _result(win: bool) -> Dictionary:
	var lvl: = maxi(1, ["4x4", "4x5", "5x6", "6x6"].find(size_id) + 1)
	return {"mode": "classic", "variant": "memory", "size": size_id, "level": lvl, "win": win, "stars": 0, "moves": moves,
		"pairs": faces.size() / 2, "time_s": int(round(time_s)), "ults": ults, "hero": hero, "seed": seed_, "score": 0,
		"rewards": {"coins": 0, "gems": 0, "petals": 0, "aff": 0}}


func _result_sheet() -> void:
	if lite:
		lite.hide_finale()
	var T: = V10MjClassicStyle.TOK
	sheet = V10MjClassicStyle.sheet(self, 520)
	var p: Control = sheet.get_meta("panel")
	var t: = V10MjClassicStyle.label("Все пары найдены", 40, T.paper100, "title", 700)
	t.position = Vector2(32, 26)
	p.add_child(t)
	var stars: = int(result.stars)
	var srow: = V10MjClassicStyle.Paint.new(func(c: Control):
		for k in 3:
			var lit: bool = k < int(c.get_meta("lit", 0))
			V10MjClassicStyle.glyph(c, "star_on" if lit else "star", Vector2(32 + k * 64, 32), 26, T.gold300 if lit else T.paper700))
	srow.position = Vector2(32, 92)
	srow.size = Vector2(3 * 64, 64)
	srow.set_meta("lit", stars if fx == "min" else 0)
	srow.name = "Stars"
	p.add_child(srow)
	if fx != "min":
		for k in stars:
			get_tree().create_timer(0.3 + 0.08 * k).timeout.connect(func():
				srow.set_meta("lit", k + 1)
				srow.queue_redraw()
				V9Feel.sound("star%d" % mini(k, 2), 1.0, -4.0))
	var best: = int(V10MjClassicData.st().memory.get(size_id, moves)) if not no_save else moves
	var l: = V10MjClassicStyle.label("Ходов %d · лучшее %d" % [moves, best], 22, T.paper300, "body", 700)
	l.position = Vector2(34, 172)
	p.add_child(l)
	var nxt: = "★★★ — не больше %d ходов" % int(round(faces.size() / 2 * 1.75))
	var l2: = V10MjClassicStyle.label(nxt, 18, T.paper500, "body", 800)
	l2.position = Vector2(34, 208)
	p.add_child(l2)
	var rw: Dictionary = result.rewards
	if int(rw.get("coins", 0)) > 0:
		var rl: = V10MjClassicStyle.label("+%d монет · +%d симпатия" % [int(rw.coins), int(rw.aff)], 26, T.gold300, "body", 900)
		rl.position = Vector2(34, 244)
		p.add_child(rl)
	var play: = V10MjClassicStyle.Btn.new("play", "Играть ещё")
	play.size = Vector2(560, 104)
	play.position = Vector2((p.size.x - 560) * 0.5, p.size.y - 210)
	play.breathe = true
	play.pressed.connect(func(): _leave("again"))
	p.add_child(play)
	var out: = V10MjClassicStyle.Btn.new("second", "Выбрать размер", "next")
	out.size = Vector2(300, 80)
	out.position = Vector2((p.size.x - 300) * 0.5, p.size.y - 96)
	out.pressed.connect(func(): _leave("exit"))
	p.add_child(out)


func _pause() -> void:
	if sheet != null:
		return
	var T: = V10MjClassicStyle.TOK
	sheet = V10MjClassicStyle.sheet(self, 520)
	var p: Control = sheet.get_meta("panel")
	var t: = V10MjClassicStyle.label("Пауза", 32, T.paper100, "title", 600)
	t.position = Vector2(32, 28)
	p.add_child(t)
	for i in V10MjClassicInfo.HOW_MEMORY.size():
		var row: Array = V10MjClassicInfo.HOW_MEMORY[i]
		var gid: String = row[0]
		var ic: = V10MjClassicStyle.Paint.new(func(c: Control): V10MjClassicStyle.glyph(c, gid, Vector2(20, 20), 16, T.gold300))
		ic.position = Vector2(32, 88 + i * 58)
		ic.size = Vector2(40, 40)
		p.add_child(ic)
		var l: = V10MjClassicStyle.label(row[1], 18, T.paper300, "body", 700)
		l.position = Vector2(88, 94 + i * 58)
		l.size = Vector2(p.size.x - 120, 36)
		p.add_child(l)
	var play: = V10MjClassicStyle.Btn.new("play", "Продолжить")
	play.size = Vector2(560, 104)
	play.position = Vector2((p.size.x - 560) * 0.5, 280)
	play.pressed.connect(func():
		V10MjClassicStyle.close_sheet(sheet)
		sheet = null)
	p.add_child(play)
	var out: = V10MjClassicStyle.Btn.new("second", "Выйти")
	out.size = Vector2(272, 84)
	out.position = Vector2((p.size.x - 272) * 0.5, 404)
	out.pressed.connect(func():
		result = _result(false)
		if not no_save:
			V10MjClassicData.record(result)
		_leave("exit"))
	p.add_child(out)


func _leave(next: String) -> void:
	result["next"] = next
	if sheet:
		V10MjClassicStyle.close_sheet(sheet)
		sheet = null
	finished.emit(result)
