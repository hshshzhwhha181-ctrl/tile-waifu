class_name V10MjRiichiScreen
extends Control

# «Стол на четверых»: Japanese mahjong (riichi) against three heroines, Mahjong Soul-level presentation on top of the
# unchanged v08 engine (V8Round/V8Mj/V8AI) through V10MjRiichiDriver.
#
# setup(main, args) — args: format ("east"|"east_south"|"one_hand"), hall (school|bamboo|jade|gold|sky; no hall →
# hall picker first), seats (4; 3 = sanma contract: the seat across is not drawn), seed, presence (stage director:
# on(event, data), sacred(rect)), look (tile material / music keys), partner, rivals [3 ids].
# Signal finished(result) with the contract schema (MODES §7.1) plus place/hall/format/rp; rewards are not credited.
#
# Rules of «не мешает»: while the player's decision is pending no insert takes input (fx is MOUSE_FILTER_IGNORE,
# cut-ins only after ron/tsumo when the driver is held), buttons appear only on ask and vanish after the answer.

signal finished(result: Dictionary)

const D = preload("res://scripts/v10/mj/riichi/riichi_data.gd")
const STICKER_TXT: = {"surprised": "Ого!", "pout": "Хм.", "happy": "Ура!", "sad": "Эх…", "shy": "Хи-хи"}
const SEAT_ORDER: = [0, 1, 2, 3]

var main = null
var args: = {}
var fmt: = "east"
var hall: Dictionary = D.HALLS[0]
var seats: = 4
var seed: = 0
var presence = null
var look: = {}
var W: = 720.0
var H: = 1280.0
var horizontal: = false
var me: = 0
var heroes: = ["player", "mc", "rin", "hana"]
var partner: = "mc"
var names_mode: = "ru"
var auto_flow: = false       # selftest / demo: sheets advance by themselves
var started: = false

var drv: V10MjRiichiDriver
var fx: V10MjRiichiFx
var barks: V10MjRiichiBarks
var music: V10MjRiichiMusic
var mimic: = V10MjRiichiMimic.new()
var srng: = RandomNumberGenerator.new()   # stickers only (never the engine's rng)
var L: = {}

var bg: TextureRect
var table: Control
var center: Control
var hud: Control
var sheet_layer: Control
var hand_box: Control
var btn_row: Control
var hint_lbl: Label
var band: Control
var portraits: = {}
var infos: = {}
var pond_nodes: = {}
var meld_nodes: = {}
var back_nodes: = {}
var partner_portrait: V10MjRiichiPortrait
var my_info: Label
var pause_btn: Control
var quiet_btn: Control
var undo_btn: Control
var sheet: Control = null
var banner: Control = null

var sel: = -1
var mode: = ""
var auto_t: = -1.0
var ask: = {}
var turn_count: = 0
var sticker_cd: = [0, 0, 0, 0]
var stickers_on: = true
var yakuman_shown: = false
var hand_res: = {}
var shown_scores: = [25000, 25000, 25000, 25000]
var riichi_me: = false
var t_start: = 0.0
var swipe_from: = Vector2.ZERO
var swipe_tile: = -1

# selftest probes
var reactions: = []          # [said_no, seat, what, kind]
var said_no: = 0
var voice_log: = []          # [said_no, voices_before, voices_after]
var button_log: = []         # [event, visible, n]
var block_violations: = []

# ================================================================== setup
func build(main_, a: Dictionary) -> void:
	setup(main_, a)

func setup(main_, a: Dictionary) -> void:
	main = main_
	args = a
	mouse_filter = Control.MOUSE_FILTER_STOP
	var vs: = get_viewport_rect().size if is_inside_tree() else Vector2(720, 1280)
	W = size.x if size.x > 0 else vs.x
	H = size.y if size.y > 0 else vs.y
	size = Vector2(W, H)
	fmt = String(a.get("format", "east"))
	if not D.FORMATS.has(fmt):
		fmt = "east"
	seats = 3 if int(a.get("seats", 4)) == 3 else 4
	presence = a.get("presence", null)
	look = a.get("look", {}) if a.get("look") is Dictionary else {}
	V10MjRiichiTile.look = look
	auto_flow = bool(a.get("auto_flow", false))
	var Sd: Dictionary = D._S()
	partner = String(a.get("partner", Sd.get("partner", "mc")))
	if not D.HERO_COLOR.has(partner) and not V10W1Core.is_wave1_hero(partner):
		partner = "mc"
	names_mode = String(D.pref("names"))
	stickers_on = bool(D.pref("stickers"))
	var hp: int = int(D.pref("horizontal"))
	horizontal = (W / H > 0.68) if hp < 0 else hp == 1
	if a.has("horizontal"):
		horizontal = bool(a.horizontal)
	if a.has("hall"):
		_begin(String(a.hall))
	else:
		_lobby()

func _begin(hall_id: String) -> void:
	hall = D.hall(hall_id)
	var one: bool = D.FORMATS[fmt].one_hand
	seed = int(args.get("seed", D.daily_seed() if one else randi() % 1000000000))
	srng.seed = seed ^ 0x51c4e7
	var rivals: Array = args.get("rivals", [])
	if rivals.size() < 3:
		rivals = []
		var pool: = D.FOUNDERS.duplicate()
		pool.erase(partner)
		var rr: = RandomNumberGenerator.new()
		rr.seed = seed
		for i in 3:
			rivals.append(pool.pop_at(rr.randi_range(0, pool.size() - 1)))
	heroes = ["player", rivals[0], rivals[1], rivals[2]]
	if seats == 3:
		# sanma contract: seat across is not drawn (the sanma lane runs its own 3-seat engine)
		pass
	V8AI.room_skill = float(hall.skill)
	drv = V10MjRiichiDriver.new()
	drv.name = "Driver"
	drv.setup({"seed": seed, "length": D.FORMATS[fmt].length, "heroes": heroes, "me": me, "pace": float(hall.pace),
		"one_hand": one, "undo": int(hall.undo)})
	add_child(drv)
	drv.event.connect(_on_event)
	drv.asked.connect(_on_asked)
	drv.answered.connect(_on_answered)
	drv.said.connect(_on_said)
	drv.rewound.connect(_on_rewound)
	drv.finished.connect(_on_match_end)
	barks = V10MjRiichiBarks.new()
	add_child(barks)
	music = V10MjRiichiMusic.new().setup(look)
	music.enabled = not bool(args.get("mute", false))
	add_child(music)
	_layout()
	_build()
	if presence != null and presence.has_method("sacred"):
		for k in ["hand", "btns", "melds"]:
			presence.sacred(L[k])
		presence.sacred(L.seat[0].pond)
	t_start = Time.get_ticks_msec() / 1000.0
	started = true
	music.start()
	if not bool(args.get("manual", false)):
		drv.start()

# ================================================================== layout (720×1280 base; extra height split table/band)
func _layout() -> void:
	L = {"seat": {}}
	var ex: = maxf(0.0, H - 1280.0)
	var band_h: = (160.0 if horizontal else 200.0) + ex * 0.5
	var hand_y: = H - band_h - 120.0
	var btn_y: = hand_y - 120.0
	var meld_y: = btn_y - 80.0
	L.band = Rect2(0, H - band_h, W, band_h)
	L.hand = Rect2(0, hand_y, W, 120)
	L.btns = Rect2(0, btn_y, W, 120)
	L.melds = Rect2(0, meld_y, W, 80)
	var tw: = minf(64.0, floorf((W - 24.0) / 14.3))
	L.tile = Vector2(tw, roundf(tw * 66.0 / 48.0))
	if horizontal:
		_layout_square(meld_y)
	else:
		_layout_portrait(ex)

func _layout_portrait(ex: float) -> void:
	var cx: = W * 0.5
	var cy: = 425.0 + ex * 0.35
	var pt: = Vector2(40, 54)
	L.cx = cx
	L.cy = cy
	L.center = Rect2(cx - 100, cy - 100, 200, 200)
	var lw: = 6 * pt.x
	var lh: = 3 * pt.y
	var g: = lw * 0.5 + 4.0
	L.seat[0] = {"pond": Rect2(cx - lw * 0.5, cy + g, lw, lh), "pt": pt,
		"stamp": Vector2(cx, L.melds.position.y - 10), "bark": _my_bark_at()}
	L.seat[2] = {"pond": Rect2(cx - lw * 0.5, cy - g - lh, lw, lh), "pt": pt, "portrait": Rect2(cx - 48, 14 + ex * 0.1, 96, 96),
		"info": "top", "meld": Vector2(cx + 170, 14 + ex * 0.1), "mt": Vector2(24, 33),
		"stamp": Vector2(cx, cy - 170), "bark": Vector2(cx + 62, 112 + ex * 0.1), "sticker": Vector2(cx - 210, 112 + ex * 0.1)}
	L.seat[3] = {"pond": Rect2(cx - g - lh, cy - lw * 0.5, lh, lw), "pt": pt, "portrait": Rect2(10, cy - 290, 80, 80),
		"info": "left", "meld": Vector2(8, cy + 132), "mt": Vector2(24, 33),
		"stamp": Vector2(cx - 190, cy), "bark": Vector2(100, cy - 274), "sticker": Vector2(98, cy - 234)}
	L.seat[1] = {"pond": Rect2(cx + g, cy - lw * 0.5, lh, lw), "pt": pt, "portrait": Rect2(W - 90, cy - 290, 80, 80),
		"info": "right", "meld": Vector2(W - 8, cy + 132), "mt": Vector2(24, 33),
		"stamp": Vector2(cx + 190, cy), "bark": Vector2(W - 100, cy - 274), "sticker": Vector2(W - 98 - 150, cy - 234)}

func _layout_square(meld_y: float) -> void:
	var S: = minf(W - 8.0, meld_y - 12.0)
	var sq: = Rect2((W - S) * 0.5, (meld_y - S) * 0.5, S, S)
	var cx: = sq.get_center().x
	var cy: = sq.get_center().y
	var pt: = Vector2(roundf(S * 0.054), roundf(S * 0.054 * 54.0 / 40.0))
	L.sq = sq
	L.cx = cx
	L.cy = cy
	var c: = roundf(S * 0.27)
	L.center = Rect2(cx - c * 0.5, cy - c * 0.5, c, c)
	var lw: = 6 * pt.x
	var lh: = 3 * pt.y
	var g: = maxf(c * 0.5 + 6, lw * 0.5 + 4)
	var bt: = Vector2(roundf(S * 0.032), roundf(S * 0.032 * 66.0 / 48.0))
	var pd: = roundf(S * 0.1)
	L.seat[0] = {"pond": Rect2(cx - lw * 0.5, cy + g, lw, lh), "pt": pt,
		"stamp": Vector2(cx, cy + g + lh + 30), "bark": _my_bark_at()}
	L.seat[2] = {"pond": Rect2(cx - lw * 0.5, cy - g - lh, lw, lh), "pt": pt,
		"portrait": Rect2(sq.end.x - pd - 10, sq.position.y + 10, pd, pd), "info": "top_sq",
		"backs": Rect2(cx - bt.x * 6.5, sq.position.y + 10, bt.x * 13, bt.y), "brot": 180, "bt": bt,
		"meld": Vector2(sq.position.x + 10, sq.position.y + 10), "mt": Vector2(bt.x, bt.y),
		"stamp": Vector2(cx, cy - g - lh - 30), "bark": Vector2(sq.end.x - pd - 20, sq.position.y + pd + 24), "sticker": Vector2(sq.end.x - pd - 170, sq.position.y + 16)}
	L.seat[3] = {"pond": Rect2(cx - g - lh, cy - lw * 0.5, lh, lw), "pt": pt,
		"portrait": Rect2(sq.position.x + 10, sq.position.y + 10, pd, pd), "info": "left_sq",
		"backs": Rect2(sq.position.x + 10, cy - bt.x * 6.5, bt.y, bt.x * 13), "brot": 90, "bt": bt,
		"meld": Vector2(sq.position.x + 10, cy + bt.x * 6.5 + 10), "mt": Vector2(bt.x, bt.y),
		"stamp": Vector2(cx - g - lh - 50, cy), "bark": Vector2(sq.position.x + pd + 20, sq.position.y + 30), "sticker": Vector2(sq.position.x + pd + 20, sq.position.y + 70)}
	L.seat[1] = {"pond": Rect2(cx + g, cy - lw * 0.5, lh, lw), "pt": pt,
		"portrait": Rect2(sq.end.x - pd - 10, sq.end.y - pd - 10, pd, pd), "info": "right_sq",
		"backs": Rect2(sq.end.x - 10 - bt.y, cy - bt.x * 6.5, bt.y, bt.x * 13), "brot": 270, "bt": bt,
		"meld": Vector2(sq.end.x - 10, cy - bt.x * 6.5 - 10), "mt": Vector2(bt.x, bt.y),
		"stamp": Vector2(cx + g + lh + 50, cy), "bark": Vector2(sq.end.x - pd - 20, sq.end.y - pd - 30), "sticker": Vector2(sq.end.x - pd - 170, sq.end.y - pd - 80)}

func partner_d() -> float:
	return clampf(L.band.size.y - 56.0, 112.0, 240.0)

func _my_bark_at() -> Vector2:
	return Vector2(W - partner_d() - 32, L.band.position.y + 40)

func rel(seat: int) -> int:
	return (seat - me + 4) % 4

func seat_of_rel(rl: int) -> int:
	return (rl + me) % 4

func visible_rel(rl: int) -> bool:
	return not (seats == 3 and rl == 2)

func visible_seats() -> Array:
	var out: = []
	for s in 4:
		if visible_rel(rel(s)):
			out.append(s)
	return out

func color_of(seat: int) -> Color:
	var h: String = partner if seat == me else String(heroes[seat])
	if V10W1Core.is_wave1_hero(h):
		return V10W1Core.HEROES[h].color
	return D.HERO_COLOR.get(h, D.GOLD_500)

func name_of(seat: int) -> String:
	if seat == me:
		return "Ты"
	return String(D.HERO_NAME.get(heroes[seat], heroes[seat]))

# ================================================================== build
func _build() -> void:
	portraits = {}
	infos = {}
	for c in get_children():
		if c is CanvasItem and c != drv and c != barks and c != music:
			c.queue_free()
	bg = TextureRect.new()
	var cp: = "res://assets/v10/mj/riichi/cloth_%s.webp" % hall.cloth
	if look.has("cloth") and ResourceLoader.exists(String(look.cloth)):
		cp = String(look.cloth)
	if ResourceLoader.exists(cp):
		bg.texture = load(cp)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.size = Vector2(W, H)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	if horizontal:
		var sqv: = Control.new()
		sqv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sqv.size = Vector2(W, H)
		var sq: Rect2 = L.sq
		sqv.draw.connect(func():
			sqv.draw_rect(sq, Color(0, 0, 0, 0.12))
			sqv.draw_rect(sq, Color(D.GOLD_700, 0.35), false, 1.0))
		add_child(sqv)
	table = Control.new()
	table.mouse_filter = Control.MOUSE_FILTER_IGNORE
	table.size = Vector2(W, H)
	add_child(table)
	center = Control.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.position = L.center.position
	center.size = L.center.size
	center.draw.connect(_draw_center)
	table.add_child(center)
	for s in 4:
		var rl: = rel(s)
		pond_nodes[s] = Control.new()
		pond_nodes[s].mouse_filter = Control.MOUSE_FILTER_IGNORE
		table.add_child(pond_nodes[s])
		meld_nodes[s] = Control.new()
		meld_nodes[s].mouse_filter = Control.MOUSE_FILTER_IGNORE
		table.add_child(meld_nodes[s])
		back_nodes[s] = Control.new()
		back_nodes[s].mouse_filter = Control.MOUSE_FILTER_IGNORE
		table.add_child(back_nodes[s])
		if rl == 0 or not visible_rel(rl):
			continue
		var pr: Rect2 = L.seat[rl].portrait
		var p: = V10MjRiichiPortrait.make(String(heroes[s]), pr.size.x, color_of(s))
		p.position = pr.position
		table.add_child(p)
		portraits[s] = p
		infos[s] = _seat_info(s, rl)
	hud = Control.new()
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.size = Vector2(W, H)
	add_child(hud)
	_build_band()
	hint_lbl = UI.label("", 18, D.JADE_300, Color(0, 0, 0, 0.6), 3, "body", 800)
	hint_lbl.position = Vector2(20, L.melds.position.y + 4)
	hint_lbl.size = Vector2(W * 0.55, 60)
	hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud.add_child(hint_lbl)
	hand_box = Control.new()
	hand_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hand_box.position = L.hand.position
	hand_box.size = L.hand.size
	hud.add_child(hand_box)
	btn_row = Control.new()
	btn_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn_row.position = L.btns.position
	btn_row.size = L.btns.size
	btn_row.visible = false
	hud.add_child(btn_row)
	fx = V10MjRiichiFx.new()
	fx.size = Vector2(W, H)
	fx.fx_min = _fx_min()
	add_child(fx)
	fx.cutin_done.connect(_on_cutin_done)
	sheet_layer = Control.new()
	sheet_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet_layer.size = Vector2(W, H)
	add_child(sheet_layer)
	_refresh_all()

func _fx_min() -> bool:
	if bool(args.get("fx_min", false)):
		return true
	return String(D._S().get("fx_level", "full")) == "min"

func _seat_info(s: int, rl: int) -> Dictionary:
	var pr: Rect2 = L.seat[rl].portrait
	var kind: String = L.seat[rl].info
	var nm: = UI.label(name_of(s), 20, D.PAPER_100, Color(0, 0, 0, 0.6), 3, "body", 800)
	var sc: = UI.label("25 000", 22, D.GOLD_300, Color(0, 0, 0, 0.6), 3, "body", 900)
	var wd: = UI.label("Восток", 18, D.PAPER_300, Color(0, 0, 0, 0.6), 3, "body", 800)
	for l in [nm, sc, wd]:
		table.add_child(l)
	match kind:
		"top":
			nm.position = Vector2(pr.position.x - 150, pr.position.y + 14)
			nm.size.x = 138
			nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			wd.position = Vector2(pr.position.x - 150, pr.position.y + 44)
			wd.size.x = 138
			wd.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			sc.position = Vector2(pr.end.x + 12, pr.position.y + 28)
		"left", "right":
			var right: = kind == "right"
			for i in 3:
				var l: Label = [nm, sc, wd][i]
				l.size.x = 110
				l.position = Vector2(pr.end.x - 110 if right else pr.position.x - 2, pr.end.y + 4 + i * 26)
				l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if right else HORIZONTAL_ALIGNMENT_LEFT
		_:
			# square table: name/score/wind beside the corner portrait, toward the table centre
			var right2: = pr.position.x > W * 0.5
			for i in 3:
				var l2: Label = [nm, sc, wd][i]
				l2.size.x = 130
				l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if right2 else HORIZONTAL_ALIGNMENT_LEFT
				var bottom: = pr.position.y > H * 0.4
				l2.position = Vector2(pr.position.x - 136 if right2 else pr.end.x + 8, (pr.position.y - 4 if not bottom else pr.end.y - 80) + i * 26)
	return {"name": nm, "score": sc, "wind": wd}

func _build_band() -> void:
	band = Control.new()
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.position = L.band.position
	band.size = L.band.size
	band.draw.connect(func():
		var n: = 12
		for i in n:
			band.draw_rect(Rect2(0, band.size.y * i / n, W, band.size.y / n + 1), Color(D.NIGHT_900, 0.35 + 0.55 * float(i) / n))
		band.draw_line(Vector2(24, 0), Vector2(W - 24, 0), Color(D.GOLD_700, 0.35), 1.0))
	hud.add_child(band)
	var pd: = partner_d()
	partner_portrait = V10MjRiichiPortrait.make(partner, pd, color_of(me))
	partner_portrait.position = Vector2(W - pd - 20, (L.band.size.y - pd) * 0.5)
	band.add_child(partner_portrait)
	pause_btn = _quiet_button("Пауза", Vector2(16, 12), _open_pause)
	band.add_child(pause_btn)
	my_info = UI.label("", 22, D.PAPER_100, Color(0, 0, 0, 0.5), 3, "body", 900)
	my_info.position = Vector2(24, 104)
	band.add_child(my_info)
	quiet_btn = _quiet_button("Стикеры", Vector2(112, 12), _toggle_stickers)
	band.add_child(quiet_btn)
	_refresh_quiet()
	undo_btn = _quiet_button("Отменить", Vector2(208, 12), _undo)
	undo_btn.visible = false
	band.add_child(undo_btn)

func _quiet_button(text: String, pos: Vector2, cb: Callable) -> Control:
	var b: = Control.new()
	b.position = pos
	var bw: = 150.0 if text == "Отменить" else 88.0
	b.size = Vector2(bw, 80)
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	var l: = UI.label(text, 18, D.PAPER_300, Color(0, 0, 0, 0.5), 2, "body", 800)
	l.name = "L"
	l.position = Vector2(0, 50)
	l.size = Vector2(bw, 24)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_child(l)
	b.draw.connect(func():
		var c: = Vector2(b.size.x * 0.5, 26)
		var col: Color = b.get_meta("col", D.PAPER_300)
		b.draw_arc(c, 20, 0, TAU, 40, Color(col, 0.8), 2.5, true)
		_quiet_icon(b, text, c, col))
	b.gui_input.connect(func(e: InputEvent):
		if _is_tap(e):
			V9Feel.press(b, "tap")
			cb.call())
	return b

func _quiet_icon(b: Control, text: String, c: Vector2, col: Color) -> void:
	if text == "Пауза":
		b.draw_line(c + Vector2(-6, -8), c + Vector2(-6, 8), col, 3.0)
		b.draw_line(c + Vector2(6, -8), c + Vector2(6, 8), col, 3.0)
	elif text == "Стикеры":
		b.draw_arc(c + Vector2(0, 2), 8, 0.2, PI - 0.2, 12, col, 2.5)
		b.draw_circle(c + Vector2(-5, -4), 2.0, col)
		b.draw_circle(c + Vector2(5, -4), 2.0, col)
	else:
		b.draw_arc(c, 9, PI * 0.9, PI * 2.2, 16, col, 2.5)
		b.draw_line(c + Vector2(-9, 1), c + Vector2(-13, -5), col, 2.5)
		b.draw_line(c + Vector2(-9, 1), c + Vector2(-3, -3), col, 2.5)

func _is_tap(e: InputEvent) -> bool:
	return (e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed) or (e is InputEventScreenTouch and not e.pressed)

# ================================================================== drawing the table from engine state
func _refresh_all() -> void:
	if drv == null:
		return
	for s in 4:
		_refresh_pond(s)
		_refresh_melds(s)
		_refresh_backs(s)
	_refresh_infos()
	_refresh_hand()
	center.queue_redraw()

func _refresh_infos() -> void:
	var r: = drv.r
	for s in infos:
		var inf: Dictionary = infos[s]
		inf.score.text = _fmt(r.scores[s])
		var w: int = (s - r.dealer + 4) % 4
		inf.wind.text = V8Mj.WIND_RU[w] + (" ●" if w == 0 else "")
		inf.wind.label_settings.font_color = D.GOLD_500 if w == 0 else D.PAPER_300
		portraits[s].set_active(r.turn == s and not r.match_over)
	var mw: = (me - r.dealer + 4) % 4
	my_info.text = "%s · %s" % [V8Mj.WIND_RU[mw], _fmt(r.scores[me])]

static func plural(n: int, one: String, few: String, many: String) -> String:
	var m10: = n % 10
	var m100: = n % 100
	if m10 == 1 and m100 != 11:
		return one
	if m10 >= 2 and m10 <= 4 and (m100 < 12 or m100 > 14):
		return few
	return many

static func _fmt(n: int) -> String:
	var s: = str(absi(n))
	var out: = ""
	while s.length() > 3:
		out = " " + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("−" if n < 0 else "") + s + out

# pond slot boxes in screen space (rows of 6 from the centre outward; the riichi tile lies sideways)
func pond_boxes(s: int) -> Array:
	var rl: = rel(s)
	var R: Rect2 = L.seat[rl].pond
	var pt: Vector2 = L.seat[rl].pt
	var LW: = 6 * pt.x
	var LH: = 3 * pt.y
	var base_rot: int = [0, 270, 180, 90][rl]
	var out: = []
	var u: = 0.0
	var v: = 0.0
	var col: = 0
	for p in drv.r.ponds[s]:
		if col >= 6:
			col = 0
			u = 0.0
			v += pt.y
		var side: bool = p.riichi
		var bw: = pt.y if side else pt.x
		var bh: = pt.x if side else pt.y
		var lb: = Rect2(u, v + (pt.y - bh), bw, bh)
		var box: Rect2
		match rl:
			0:
				box = Rect2(R.position + lb.position, lb.size)
			1:
				box = Rect2(R.position.x + lb.position.y, R.position.y + (LW - lb.position.x - lb.size.x), lb.size.y, lb.size.x)
			2:
				box = Rect2(R.position.x + (LW - lb.position.x - lb.size.x), R.position.y + (LH - lb.position.y - lb.size.y), lb.size.x, lb.size.y)
			3:
				box = Rect2(R.position.x + (LH - lb.position.y - lb.size.y), R.position.y + lb.position.x, lb.size.y, lb.size.x)
		out.append([box, (base_rot + (90 if side else 0)) % 360, p])
		u += bw
		col += 1
	return out

func _refresh_pond(s: int) -> void:
	var holder: Control = pond_nodes[s]
	for c in holder.get_children():
		c.queue_free()
	if not visible_rel(rel(s)):
		return
	var boxes: = pond_boxes(s)
	for i in boxes.size():
		var b: Array = boxes[i]
		var v: = V10MjRiichiTile.make(int(b[2].t), b[0].size, int(b[1]))
		v.position = b[0].position
		v.called = bool(b[2].called)
		v.fresh = i == boxes.size() - 1 and drv.r.last_from == s and drv.r.last_discard == int(b[2].t) and not v.called
		v.shadow = true
		holder.add_child(v)

func _meld_tiles(md: Dictionary, owner: int) -> Array:
	# [[tile, sideways, back]] in display order; the called tile lies sideways on the side it came from
	var tiles: Array = md.tiles.duplicate()
	var out: = []
	if md.type == "ankan":
		for i in tiles.size():
			out.append([tiles[i], false, i == 0 or i == 3])
		return out
	var called: int = int(md.get("called", -1))
	var rest: = []
	for t in tiles:
		if t != called:
			rest.append(t)
	var from_rel: = (int(md.from) - owner + 4) % 4
	var pos: = 0 if from_rel == 3 else (1 if from_rel == 2 else rest.size())
	for i in rest.size():
		out.append([rest[i], false, false])
	if called >= 0:
		out.insert(mini(pos, out.size()), [called, true, false])
	return out

func _refresh_melds(s: int) -> void:
	var holder: Control = meld_nodes[s]
	for c in holder.get_children():
		c.queue_free()
	var rl: = rel(s)
	if not visible_rel(rl):
		return
	var melds: Array = drv.r.melds[s]
	if melds.is_empty():
		return
	if rl == 0:
		var mt: = Vector2(roundf(L.tile.x * 0.8), roundf(L.tile.y * 0.8))
		var x: = W - 14.0
		var y: float = L.melds.position.y + (80 - mt.y) * 0.5 + 6
		for md in melds:
			var ts: = _meld_tiles(md, s)
			for i in range(ts.size() - 1, -1, -1):
				var e: Array = ts[i]
				var sz: = Vector2(mt.y, mt.x) if e[1] else mt
				x -= sz.x
				var v: = V10MjRiichiTile.make(-1 if e[2] else int(e[0]), sz, 90 if e[1] else 0)
				v.back_path = _back_path()
				v.position = Vector2(x, y + (mt.y - sz.y))
				holder.add_child(v)
			x -= 10
		return
	var mt2: Vector2 = L.seat[rl].mt
	var anchor: Vector2 = L.seat[rl].meld
	var right: bool = anchor.x > W * 0.5 and rl == 1
	var row_y: = anchor.y
	var x0: = anchor.x
	for md in melds:
		var ts2: = _meld_tiles(md, s)
		var wsum: = 0.0
		for e in ts2:
			wsum += mt2.y if e[1] else mt2.x
		var x: = x0 - wsum if right else x0
		if rl == 2 and not horizontal and x + wsum > W - 6:
			x0 = L.seat[2].meld.x
			row_y += mt2.y + 6
			x = x0
		for e in ts2:
			var sz2: = Vector2(mt2.y, mt2.x) if e[1] else mt2
			var v2: = V10MjRiichiTile.make(-1 if e[2] else int(e[0]), sz2, 90 if e[1] else 0)
			v2.back_path = _back_path()
			v2.position = Vector2(x, row_y + (mt2.y - sz2.y))
			v2.shadow = false
			holder.add_child(v2)
			x += sz2.x
		if rl == 2 and not horizontal:
			x0 = x + 6
		else:
			row_y += mt2.y + 6

func _refresh_backs(s: int) -> void:
	var holder: Control = back_nodes[s]
	for c in holder.get_children():
		c.queue_free()
	var rl: = rel(s)
	if rl == 0 or not visible_rel(rl) or not L.seat[rl].has("backs"):
		return
	var R: Rect2 = L.seat[rl].backs
	var n: int = drv.r.hands[s].size()
	var bt: Vector2 = L.seat[rl].bt
	var rot: int = L.seat[rl].brot
	for i in n:
		var sz: = bt if rot % 180 == 0 else Vector2(bt.y, bt.x)
		var p: = R.position + (Vector2(i * bt.x, 0) if rot % 180 == 0 else Vector2(0, i * bt.x))
		var v: = V10MjRiichiTile.make(-1, sz, rot)
		v.back_path = _back_path()
		v.position = p
		v.shadow = false
		holder.add_child(v)

func _back_path() -> String:
	if look.has("back") and ResourceLoader.exists(String(look.back)):
		return String(look.back)
	return "res://assets/v10/mj/riichi/back_%s.png" % hall.back

func _draw_center() -> void:
	var r: = drv.r
	var sz: = center.size
	var sb: = StyleBoxFlat.new()
	sb.bg_color = Color(D.NIGHT_800, 0.86)
	sb.border_color = Color(D.GOLD_700, 0.5)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	center.draw_style_box(sb, Rect2(Vector2.ZERO, sz))
	# her turn: a short gold bar on the side of the seat to move
	var t_rel: = rel(r.turn)
	var bar: Rect2 = [Rect2(sz.x * 0.25, sz.y - 4, sz.x * 0.5, 3), Rect2(sz.x - 4, sz.y * 0.25, 3, sz.y * 0.5),
		Rect2(sz.x * 0.25, 1, sz.x * 0.5, 3), Rect2(1, sz.y * 0.25, 3, sz.y * 0.5)][t_rel]
	if not r.match_over:
		center.draw_rect(bar, color_of(r.turn))
	var ft: = UI.font("title", 700)
	var fb: = UI.font("body", 900)
	var k: = sz.x / 200.0
	var rn: = r.round_name()
	var fs1: = int(28 * k)
	var w1: = ft.get_string_size(rn, HORIZONTAL_ALIGNMENT_LEFT, -1, fs1).x
	center.draw_string(ft, Vector2((sz.x - w1) * 0.5, 44 * k), rn, HORIZONTAL_ALIGNMENT_LEFT, -1, fs1, D.PAPER_100)
	var wl: = "Стена %d" % r.wall_left()
	var fs2: = int(18 * maxf(k, 1.0))
	var w2: = fb.get_string_size(wl, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x
	center.draw_string(fb, Vector2((sz.x - w2) * 0.5, 72 * k), wl, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, D.PAPER_300)
	# dora indicators: 5 slots, revealed faces then backs
	var dt: = Vector2(26, 36) * k
	var x0: = (sz.x - dt.x * 5 - 8) * 0.5
	for i in 5:
		var rect: = Rect2(x0 + i * (dt.x + 2), 88 * k, dt.x, dt.y)
		var tx: Texture2D
		if i < r.dora_ind.size():
			tx = V10MjRiichiTile.face_tex(r.dora_ind[i])
		else:
			tx = V10MjRiichiTile.tex(_back_path())
		if tx:
			center.draw_texture_rect(tx, rect, false)
	# sticks: riichi deposits (white stick, red dot) and repeat counters (white stick, black dots)
	var y3: = 146 * k
	var sx: = sz.x * 0.5 - 70 * k
	_draw_stick(Vector2(sx, y3), k, D.CINNABAR)
	center.draw_string(fb, Vector2(sx + 40 * k, y3 + 7 * k), "×%d" % r.sticks, HORIZONTAL_ALIGNMENT_LEFT, -1, int(18 * maxf(k, 1.0)), D.PAPER_100)
	_draw_stick(Vector2(sx + 80 * k, y3), k, D.NIGHT_900)
	center.draw_string(fb, Vector2(sx + 120 * k, y3 + 7 * k), "×%d" % r.honba, HORIZONTAL_ALIGNMENT_LEFT, -1, int(18 * maxf(k, 1.0)), D.PAPER_100)

func _draw_stick(c: Vector2, k: float, dot: Color) -> void:
	var sb: = StyleBoxFlat.new()
	sb.bg_color = D.PAPER_100
	sb.set_corner_radius_all(int(4 * k))
	center.draw_style_box(sb, Rect2(c - Vector2(16, 4) * k, Vector2(32, 8) * k))
	center.draw_circle(c, 2.5 * k, dot)

# ================================================================== the hand
func _hand_tiles() -> Array:
	# sorted closed tiles; the drawn tile stands apart on the right
	var h: Array = drv.r.hands[me].duplicate()
	var drawn: int = drv.r.drawn if drv.r.turn == me else -1
	var out: = []
	var has_drawn: = drawn >= 0 and drawn in h and h.size() % 3 == 2
	if has_drawn:
		h.erase(drawn)
	out = V8Mj.sort_tiles(h)
	if has_drawn:
		out.append(drawn)
	return [out, has_drawn]

func hand_rects() -> Dictionary:
	var ht: = _hand_tiles()
	var tiles: Array = ht[0]
	var gap: = 12.0 if ht[1] else 0.0
	var tw: Vector2 = L.tile
	var total: = tiles.size() * tw.x + gap
	var x0: = (W - total) * 0.5
	var out: = {}
	for i in tiles.size():
		var x: = x0 + i * tw.x + (gap if ht[1] and i == tiles.size() - 1 else 0.0)
		out[tiles[i]] = Rect2(Vector2(x, L.hand.position.y + (120 - tw.y) * 0.5 + 8), tw)
	return out

func _refresh_hand() -> void:
	for c in hand_box.get_children():
		c.queue_free()
	if drv == null:
		return
	var rects: = hand_rects()
	var o: Dictionary = ask.get("opts", {}) if ask.get("kind", "") == "turn" else {}
	var forbidden: Array = o.get("forbidden", [])
	var best: = -1
	if String(hall.hints) == "full" and ask.get("kind", "") == "turn" and not drv.r.riichi[me]:
		best = _coach_pick()
	var threats: = []
	if String(hall.hints) == "full":
		for s in 4:
			if s != me and drv.r.riichi[s]:
				threats.append(s)
	for t in rects:
		var rc: Rect2 = rects[t]
		var v: = V10MjRiichiTile.make(int(t), rc.size, 0)
		v.position = rc.position - hand_box.position
		v.mouse_filter = Control.MOUSE_FILTER_STOP
		v.lift = 16.0 if t == sel else 0.0
		var k: int = int(t) >> 2
		if mode == "riichi_pick":
			v.dim = not (int(t) in o.get("riichi", []))
		elif ask.get("kind", "") == "turn" and k in forbidden:
			v.dim = true
		elif drv.r.riichi[me] and ask.get("kind", "") == "turn" and int(t) != drv.r.drawn:
			v.dim = true
		if best >= 0 and int(t) == best and mode == "":
			v.glow = Color(D.JADE_300, 0.75)
		if not threats.is_empty():
			var dmax: = 0.0
			for o2 in threats:
				dmax = maxf(dmax, V8AI.danger_of(drv.r, o2, k))
			v.danger = dmax >= 6.5
		v.gui_input.connect(_on_tile_input.bind(int(t), v))
		hand_box.add_child(v)
	_refresh_hint()

func _coach_pick() -> int:
	# V8AI.coach draws from the engine rng: keep the engine's stream untouched
	var st: int = drv.r.rng.state
	var pick: Dictionary = V8AI.coach(drv.r, me)
	drv.r.rng.state = st
	return int(pick.get("t", -1))

func _refresh_hint() -> void:
	if hint_lbl == null:
		return
	hint_lbl.text = ""
	if String(hall.hints) == "":
		return
	var r: = drv.r
	var h: Array = r.hands[me]
	var seen: Array = r.visible(me)
	if h.size() % 3 == 1:
		var c: = V8Mj.counts(h)
		var w: = V8Mj.waits(c, r.melds[me].size())
		if not w.is_empty():
			var parts: = []
			var left: = 0
			for k in w:
				parts.append(D.tile_short(k))
				left += maxi(0, 4 - int(seen[k]))
			hint_lbl.text = "Ждёшь: %s · осталось %d" % [", ".join(parts), left]
			if r.is_furiten(me):
				hint_lbl.text += " · только со стены"
			return
	if String(hall.hints) == "full" and sel >= 0 and ask.get("kind", "") == "turn":
		var c2: = V8Mj.counts(h)
		c2[sel >> 2] -= 1
		var u: = V8Mj.ukeire(c2, r.melds[me].size(), seen)
		if int(u.shanten) == 0:
			var w2: = V8Mj.waits(c2, r.melds[me].size())
			var left2: = 0
			for k in w2:
				left2 += maxi(0, 4 - int(seen[k]))
			hint_lbl.text = "Сброс %s: рука готова, ждёт %d %s" % [D.tile_short(sel >> 2), left2, plural(left2, "фишку", "фишки", "фишек")]
		else:
			hint_lbl.text = "Сброс %s: руку улучшат %d %s" % [D.tile_short(sel >> 2), int(u.n), plural(int(u.n), "фишка", "фишки", "фишек")]

func _on_tile_input(e: InputEvent, t: int, v: Control) -> void:
	var down: bool = (e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and e.pressed) or (e is InputEventScreenTouch and e.pressed)
	if down:
		swipe_from = e.position
		swipe_tile = t
		return
	if _is_tap(e) and swipe_tile == t:
		var dy: float = e.position.y - swipe_from.y
		swipe_tile = -1
		if dy < -40.0:
			tap_tile(t, true)
		else:
			tap_tile(t)

# public for the selftest bot: tap (or swipe up) a hand tile
func tap_tile(t: int, swipe: = false) -> bool:
	if ask.get("kind", "") != "turn" or not drv.waiting:
		_sfx("deny", -10)
		return false
	var o: Dictionary = ask.opts
	var k: = t >> 2
	if mode == "riichi_pick":
		if not (t in o.get("riichi", [])):
			_sfx("deny", -8)
			return false
	elif k in o.get("forbidden", []):
		_sfx("deny", -8)
		return false
	elif drv.r.riichi[me] and t != drv.r.drawn:
		_sfx("deny", -8)
		return false
	if sel == t or swipe:
		_discard(t, mode == "riichi_pick")
		return true
	sel = t
	_sfx("select", -6)
	_refresh_hand()
	return true

func _discard(t: int, riichi: bool) -> void:
	var rects: = hand_rects()
	if rects.has(t):
		var boxes: = pond_boxes(me)
		var pt: Vector2 = L.seat[0].pt
		var to: = Rect2(L.seat[0].pond.position + Vector2((boxes.size() % 6) * pt.x, floorf(boxes.size() / 6.0) * pt.y), pt)
		fx.fly_tile(t, rects[t], to, 0)
	sel = -1
	mode = ""
	if riichi:
		riichi_me = true
	_answer({"a": "discard", "t": t, "riichi": riichi})

# ================================================================== decision buttons
func _show_buttons(a: Dictionary) -> void:
	for c in btn_row.get_children():
		c.queue_free()
	var list: = []   # [key, payload]
	var o: Dictionary = a.get("opts", {})
	match String(a.kind):
		"turn":
			if o.get("tsumo", false):
				list.append(["tsumo", {}])
			if not o.get("in_riichi", false) and not o.get("riichi", []).is_empty():
				list.append(["riichi", {}])
			if not o.get("kans", []).is_empty():
				list.append(["kan", {"kans": o.kans}])
		"call", "chankan":
			if o.get("ron", false):
				list.append(["ron", {}])
			if o.get("pon", false):
				list.append(["pon", {}])
			if not o.get("chi", []).is_empty():
				list.append(["chi", {"chi": o.chi}])
			if o.get("kan", false):
				list.append(["kan", {}])
	while list.size() > 3:
		list.remove_at(list.size() - 1)
	if list.is_empty():
		btn_row.visible = false
		button_log.append(["ask_" + String(a.kind), false, 0])
		return
	list.append(["pass", {}])
	_lay_buttons(list)
	button_log.append(["ask_" + String(a.kind), true, list.size()])

func _lay_buttons(list: Array) -> void:
	for c in btn_row.get_children():
		c.queue_free()
	var bw: = minf(168.0, (W - 32.0 - (list.size() - 1) * 10.0) / list.size())
	var total: = list.size() * bw + (list.size() - 1) * 10.0
	var x: = (W - total) * 0.5
	var first_riichi: = false
	for it in list:
		var b: = _act_button(String(it[0]), it[1], bw)
		b.position = Vector2(x, 10)
		btn_row.add_child(b)
		x += bw + 10.0
		if it[0] == "riichi" and not bool(D.pref("riichi_hint_seen")):
			first_riichi = true
	if first_riichi:
		var cap: = UI.label(D.RIICHI_FIRST_HINT, 18, D.GOLD_300, Color(0, 0, 0, 0.6), 3, "body", 800)
		cap.name = "RiichiHint"
		cap.size = Vector2(W - 32, 24)
		cap.position = Vector2(16, 96)
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn_row.add_child(cap)
		D.set_pref("riichi_hint_seen", true)
	btn_row.visible = true
	if not _fx_min():
		btn_row.modulate.a = 0.0
		btn_row.create_tween().tween_property(btn_row, "modulate:a", 1.0, 0.12)

func _act_button(key: String, payload: Dictionary, bw: float) -> Control:
	var b: = Control.new()
	b.name = "Btn_" + key
	b.size = Vector2(bw, 80)
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.set_meta("key", key)
	b.set_meta("payload", payload)
	var words: Array = D.ACTIONS.get(key, [key, ""])
	var big: String = words[0]
	var small: String = words[1]
	if names_mode == "jp" and small != "":
		big = small.capitalize()
		small = words[0].to_lower()
	var main_act: = key in ["ron", "tsumo"]
	var col_bg: = D.ROSE_500 if main_act else (D.NIGHT_700 if key != "pass" else Color(D.NIGHT_800, 0.55))
	var col_tx: = D.NIGHT_900 if main_act else D.PAPER_100
	if key == "riichi" and mode == "riichi_pick":
		col_bg = D.GOLD_700
	b.draw.connect(func():
		var sb: = StyleBoxFlat.new()
		sb.bg_color = col_bg
		sb.set_corner_radius_all(40 if main_act else 4)
		if not main_act:
			sb.border_color = Color(D.GOLD_500 if key == "riichi" else D.GOLD_700, 0.9 if key == "riichi" else 0.5)
			sb.set_border_width_all(2 if key == "riichi" else 1)
		b.draw_style_box(sb, Rect2(Vector2.ZERO, b.size)))
	var l: = UI.label(big, 30 if big.length() <= 7 else 26, col_tx, Color(0, 0, 0, 0), 0, "title", 700)
	l.size = Vector2(bw, 40)
	l.position = Vector2(0, 8 if small != "" else 20)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_child(l)
	if small != "":
		var s2: = UI.label(small, 18, Color(col_tx, 0.75), Color(0, 0, 0, 0), 0, "body", 800)
		s2.size = Vector2(bw, 22)
		s2.position = Vector2(0, 50)
		s2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_child(s2)
	b.gui_input.connect(func(e: InputEvent):
		if _is_tap(e):
			press_action(key, payload))
	return b

func visible_buttons() -> Array:
	var out: = []
	if btn_row == null or not btn_row.visible:
		return out
	for c in btn_row.get_children():
		if c.has_meta("key") and not c.is_queued_for_deletion():
			out.append(String(c.get_meta("key")))
	return out

# public for the selftest bot
func press_action(key: String, payload: Dictionary = {}) -> bool:
	if not drv.waiting:
		return false
	var a: Dictionary = drv.r.ask
	var kind: String = String(a.get("kind", ""))
	_sfx("pop", -4)
	match key:
		"tsumo":
			return _answer({"a": "tsumo"})
		"ron":
			return _answer({"a": "ron"})
		"pon":
			return _answer({"a": "pon"})
		"riichi":
			mode = "" if mode == "riichi_pick" else "riichi_pick"
			sel = -1
			_show_buttons(a)
			_refresh_hand()
			return true
		"kan":
			if kind == "turn":
				var kans: Array = a.opts.get("kans", [])
				if payload.has("k"):
					return _answer(payload.k)
				if kans.size() == 1:
					return _answer(kans[0])
				var sub: = []
				for kk in kans:
					sub.append(["kan_opt", {"k": kk}])
				sub.append(["back", {}])
				_lay_sub(sub)
				return true
			return _answer({"a": "kan"})
		"kan_opt":
			return _answer(payload.k)
		"chi":
			var opts: Array = a.opts.get("chi", [])
			if payload.has("use"):
				return _answer({"a": "chi", "use": payload.use})
			if opts.size() == 1:
				return _answer({"a": "chi", "use": opts[0]})
			var sub2: = []
			for u in opts:
				sub2.append(["chi_opt", {"use": u}])
			sub2.append(["back", {}])
			_lay_sub(sub2)
			return true
		"chi_opt":
			return _answer({"a": "chi", "use": payload.use})
		"back":
			_show_buttons(a)
			return true
		"pass":
			if kind == "turn":
				# skipping a tsumo / kan: in riichi the drawn tile goes out; otherwise just hide the buttons
				if drv.r.riichi[me]:
					return _answer({"a": "discard", "t": drv.r.drawn})
				btn_row.visible = false
				mode = ""
				button_log.append(["pass_turn", false, 0])
				_refresh_hand()
				return true
			return _answer({"a": "pass"})
	return false

func _lay_sub(list: Array) -> void:
	for c in btn_row.get_children():
		c.queue_free()
	var bw: = 150.0
	var total: = list.size() * bw + (list.size() - 1) * 10.0
	var x: = (W - total) * 0.5
	for it in list:
		var b: Control
		if it[0] == "back":
			b = _act_button("back", {}, bw)
			(b.get_child(0) as Label).text = "Назад"
		else:
			b = _act_button(String(it[0]), it[1], bw)
			for c in b.get_children():
				c.queue_free()
			var ts: Array = []
			if it[0] == "chi_opt":
				ts = it[1].use
			else:
				ts = [int(it[1].k.k) * 4]
			var tsz: = Vector2(34, 46)
			var x0: = (bw - ts.size() * tsz.x) * 0.5
			for i in ts.size():
				var tv: = V10MjRiichiTile.make(int(ts[i]), tsz, 0)
				tv.position = Vector2(x0 + i * tsz.x, 17)
				b.add_child(tv)
		b.position = Vector2(x, 10)
		btn_row.add_child(b)
		x += bw + 10.0

func _answer(a: Dictionary) -> bool:
	btn_row.visible = false
	for c in btn_row.get_children():
		c.queue_free()
	mode = ""
	sel = -1
	auto_t = -1.0
	var ok: = drv.answer(a)
	button_log.append(["answered", btn_row.visible, 0])
	return ok

# ================================================================== driver callbacks
func _on_asked(a: Dictionary) -> void:
	ask = a
	mode = ""
	sel = -1
	_show_buttons(a)
	if a.kind == "turn":
		var o: Dictionary = a.opts
		if o.get("in_riichi", false) and not o.get("tsumo", false) and o.get("kans", []).is_empty():
			auto_t = 0.0 if auto_flow else 0.45
	_refresh_hand()
	undo_btn.visible = drv.can_undo()
	_set_undo_label()
	if presence != null:
		presence.set("input_on", true)

func _on_answered(_a: Dictionary) -> void:
	ask = {}
	undo_btn.visible = false
	_refresh_hand()
	if presence != null:
		presence.set("input_on", false)

func _on_rewound() -> void:
	_refresh_all()

func _set_undo_label() -> void:
	var l: Label = undo_btn.get_node_or_null("L")
	if l:
		l.text = "Отменить · %d" % drv.undo_left

func _undo() -> void:
	if drv.undo():
		_sfx("whoosh", -8)

func _on_event(e: Dictionary) -> void:
	var ev: String = e.get("ev", "")
	match ev:
		"deal":
			mimic.reset_hand()
			for s in portraits:
				portraits[s].set_face("neutral")
			partner_portrait.set_face("neutral")
			riichi_me = false
			yakuman_shown = yakuman_shown
			shown_scores = drv.r.scores.duplicate()
			music.new_hand(drv.r.is_last_hand())
			_refresh_all()
			_banner(drv.r.round_name() + (" · повтор %d" % drv.r.honba if drv.r.honba > 0 else ""))
		"draw":
			var s: = int(e.seat)
			if s == me:
				_refresh_hand()
			else:
				_refresh_backs(s)
			_refresh_infos()
			center.queue_redraw()
		"discard":
			var s2: = int(e.seat)
			turn_count += 1
			if banner and is_instance_valid(banner):
				banner.queue_free()
				banner = null
			_refresh_pond(s2)
			_refresh_backs(s2)
			if s2 == me:
				_refresh_hand()
				_sfx("clack%d" % (turn_count % 3), -10)
			else:
				_sfx("clack%d" % (turn_count % 3), -4)
			_refresh_infos()
			center.queue_redraw()
			_refresh_hint()
		"call":
			var s3: = int(e.seat)
			_refresh_pond(int(e.get("from", s3)))
			_refresh_melds(s3)
			_refresh_backs(s3)
			if s3 == me:
				_refresh_hand()
			_refresh_infos()
			center.queue_redraw()
		"riichi_stick":
			var s4: = int(e.seat)
			var from: Vector2 = _seat_anchor(s4)
			fx.stick(from, L.center.get_center() + Vector2(0, L.center.size.y * 0.23))
			_sfx("clack1", -12)
			_refresh_infos()
			center.queue_redraw()
		"win":
			hand_res = e
			drv.hold("result")
			btn_row.visible = false
			_stats_hand(e)
			_refresh_infos()
		"draw_end":
			hand_res = e
			drv.hold("result")
			btn_row.visible = false
			_stats_hand(e)
			if auto_flow:
				_show_tally()
			else:
				get_tree().create_timer(0.7).timeout.connect(_show_tally)

func _seat_anchor(s: int) -> Vector2:
	var rl: = rel(s)
	if rl == 0:
		return Vector2(W * 0.5, L.melds.position.y)
	return (L.seat[rl].portrait as Rect2).get_center()

func _stats_hand(e: Dictionary) -> void:
	var st: = V10MjRiichiStats.get_stats()
	V10MjRiichiStats.add_hand(st, e, me, riichi_me)

func _banner(text: String) -> void:
	if banner and is_instance_valid(banner):
		banner.queue_free()
	var band_: = Control.new()
	band_.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band_.size = Vector2(W, 96)
	band_.position = Vector2(0, L.cy - 48)
	band_.draw.connect(func():
		for i in 24:
			band_.draw_rect(Rect2(W * i / 24.0, 0, W / 24.0 + 1, 96), Color(D.NIGHT_900, 0.8 * sin(PI * (i + 0.5) / 24.0)))
		band_.draw_line(Vector2(W * 0.2, 0), Vector2(W * 0.8, 0), Color(D.GOLD_700, 0.6), 1.0)
		band_.draw_line(Vector2(W * 0.2, 95), Vector2(W * 0.8, 95), Color(D.GOLD_700, 0.6), 1.0))
	fx.add_child(band_)
	var l: = UI.label(text, 44, D.PAPER_100, Color(0, 0, 0, 0.6), 5, "title", 700)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band_.add_child(l)
	l.reset_size()
	l.position = Vector2((W - l.size.x) * 0.5, 48 - l.size.y * 0.5)
	banner = band_
	var tw: = band_.create_tween()
	band_.modulate.a = 0.0
	tw.tween_property(band_, "modulate:a", 1.0, 0.15)
	tw.tween_interval(0.5)
	tw.tween_property(band_, "modulate:a", 0.0, 0.15)
	tw.tween_callback(band_.queue_free)

# ================================================================== said → voice (≤1) + exactly one reaction
func _on_said(seat: int, what: String, data: Dictionary) -> void:
	said_no += 1
	var me_: = seat == me
	var col: = color_of(seat)
	var hero: String = partner if me_ else String(heroes[seat])
	var key: = V10MjRiichiBarks.key_for(what, data)
	# stage director gets the public event (partner voice on my declarations, glances on theirs)
	if presence != null and presence.has_method("on"):
		var pd: = {"who": "me" if me_ else hero, "seat": seat}
		if data.has("kind"):
			pd["kind"] = data.kind
		presence.on(what, pd)
	# voice: a rival's own line; for my declarations the partner speaks only when there is no stage director
	var v0: = barks.voices_played
	var b: = {}
	if visible_rel(rel(seat)) and (not me_ or presence == null):
		b = barks.say(hero, key)
	voice_log.append([said_no, v0, barks.voices_played])
	# the one reaction
	var kind: = _react(seat, what, data, col, hero)
	reactions.append([said_no, seat, what, kind])
	# faces (public only)
	var faces: = mimic.on_said(seat, what, data, Time.get_ticks_msec() / 1000.0, visible_seats())
	for s in faces:
		if s == me:
			partner_portrait.set_face(String(faces[s]))
		elif portraits.has(s):
			portraits[s].set_face(String(faces[s]))
	if b.get("text", "") != "" and what in ["call", "riichi", "ron", "tsumo", "dealin"]:
		var at: Vector2 = L.seat[rel(seat)].bark
		fx.bark(at, String(b.text), col, rel(seat) == 1 or rel(seat) == 0)
	_maybe_sticker(seat, what, data)

func _react(seat: int, what: String, data: Dictionary, col: Color, hero: String) -> String:
	var rl: = rel(seat)
	match what:
		"call":
			var k: String = String(data.get("kind", "pon"))
			fx.stamp(L.seat[rl].stamp, D.STAMP.get(k, "ПОН"), col)
			_sfx("pop", -2)
			return "stamp"
		"riichi":
			fx.ribbon(L.cy, W, hero, col, "Готов", "риичи")
			music.on_riichi(drv.riichi_n)
			return "ribbon"
		"dora":
			fx.dora_scene(L.center.position + Vector2(L.center.size.x * 0.5, L.center.size.y * 0.53), hero if D.HERO_COLOR.has(hero) else partner, col)
			_sfx("sparkle", -10)
			center.queue_redraw()
			return "dora"
		"ron", "tsumo":
			var yk: bool = bool(data.get("yakuman", false)) and not yakuman_shown
			if yk:
				yakuman_shown = true
			var lim: = D.limit_ru(String(data.get("limit", "")))
			var orig: = String(data.get("limit", "")).to_lower()
			var line2: = lim + (" · " + orig if orig != "" and lim != String(data.get("limit", "")) else "")
			var who: = "Ты" if seat == me else name_of(seat)
			var title: = "Победа"
			fx.win_cutin(hero, col, title, String(D.ACTIONS[what][1]), who, line2, yk)
			_sfx("win", -4)
			if auto_flow:
				fx._end_cutin(fx.cutin)
			return "cutin_yakuman" if yk else "cutin"
		_:
			# dealin / tenpai / noten: the portrait answers (mimic) with a small nod of the ring
			if portraits.has(seat):
				var p: V10MjRiichiPortrait = portraits[seat]
				if not _fx_min():
					var tw: = p.create_tween()
					p.pivot_offset = p.size * 0.5
					tw.tween_property(p, "scale", Vector2(1.06, 1.06), 0.1)
					tw.tween_property(p, "scale", Vector2.ONE, 0.16)
			return "face"

func _maybe_sticker(seat: int, what: String, data: Dictionary) -> void:
	if not stickers_on or not (what in ["riichi", "ron", "tsumo", "dealin"]) or (what == "call" and data.get("kind", "") != "kan"):
		return
	for v in visible_seats():
		if v == me or v == seat:
			continue
		if turn_count < sticker_cd[v]:
			continue
		if srng.randf() > 0.4:
			continue
		var f: = V10MjRiichiMimic.react(v, seat, what, data)
		if f == "":
			f = "surprised"
		fx.sticker(L.seat[rel(v)].sticker, String(heroes[v]), f, STICKER_TXT.get(f, "Ого!"), color_of(v))
		sticker_cd[v] = turn_count + 3
		return

func _toggle_stickers() -> void:
	stickers_on = not stickers_on
	D.set_pref("stickers", stickers_on)
	_refresh_quiet()

func _refresh_quiet() -> void:
	if quiet_btn == null:
		return
	var l: Label = quiet_btn.get_node("L")
	l.text = "Стикеры" if stickers_on else "Тихо"
	quiet_btn.set_meta("col", D.PAPER_300 if stickers_on else D.PAPER_700)
	quiet_btn.queue_redraw()

func _on_cutin_done() -> void:
	if hand_res.get("ev", "") == "win":
		_show_tally()

# ================================================================== per-frame
func _process(dt: float) -> void:
	if not started:
		return
	if auto_t >= 0.0 and drv.waiting and ask.get("kind", "") == "turn":
		auto_t -= dt
		if auto_t < 0.0:
			_answer({"a": "discard", "t": drv.r.drawn})
	var back: = mimic.tick(Time.get_ticks_msec() / 1000.0)
	for s in back:
		if s == me:
			partner_portrait.set_face(String(back[s]))
		elif portraits.has(s):
			portraits[s].set_face(String(back[s]))
	# «не мешает»: while a decision is pending nothing over the table may take input
	if drv.waiting:
		var bl: = fx.blocking()
		if not bl.is_empty():
			block_violations.append([said_no, bl.size()])
			for n in bl:
				(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE

func _sfx(name: String, db: = 0.0) -> void:
	var s: = get_node_or_null("/root/Sfx")
	if s and s.has_method("play"):
		s.play(name, 1.0, db)

# ================================================================== sheets (one layer, never a window over a window)
func _open_sheet(h: float) -> Control:
	_close_sheet()
	var veil: = ColorRect.new()
	veil.color = Color(0.05, 0.04, 0.06, 0.55)
	veil.size = Vector2(W, H)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	sheet_layer.add_child(veil)
	var s: = Control.new()
	s.size = Vector2(W, h)
	s.position = Vector2(0, H - h)
	s.mouse_filter = Control.MOUSE_FILTER_STOP
	s.draw.connect(func():
		var sb: = StyleBoxFlat.new()
		sb.bg_color = D.NIGHT_700
		sb.corner_radius_top_left = 4
		sb.corner_radius_top_right = 4
		s.draw_style_box(sb, Rect2(Vector2.ZERO, s.size))
		s.draw_line(Vector2(32, 0), Vector2(W - 32, 0), Color(D.GOLD_700, 0.35), 1.0))
	veil.add_child(s)
	sheet = veil
	if not _fx_min():
		s.position.y = H
		var tw: = s.create_tween()
		tw.tween_property(s, "position:y", H - h, 0.22).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		s.set_meta("tw", tw)
	return s

func _fit_sheet(s: Control, h: float) -> void:
	h = minf(h, H - 120.0)
	s.size.y = h
	if s.has_meta("tw"):
		var old: Tween = s.get_meta("tw")
		if old and old.is_valid():
			old.kill()
			var tw: = s.create_tween()
			tw.tween_property(s, "position:y", H - h, 0.22).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
			s.queue_redraw()
			return
	s.position.y = H - h
	s.queue_redraw()

func _close_sheet() -> void:
	if sheet and is_instance_valid(sheet):
		sheet.queue_free()
	sheet = null

func _main_button(parent: Control, text: String, y: float, cb: Callable, w: = 440.0) -> Control:
	var b: = Control.new()
	b.size = Vector2(w, 96)
	b.position = Vector2((W - w) * 0.5, y)
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.name = "Main"
	b.draw.connect(func():
		var sb: = StyleBoxFlat.new()
		sb.bg_color = D.ROSE_500
		sb.set_corner_radius_all(48)
		b.draw_style_box(sb, Rect2(Vector2.ZERO, b.size)))
	var l: = UI.label(text, 32, D.NIGHT_900, Color(0, 0, 0, 0), 0, "title", 600)
	l.size = b.size
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	b.add_child(l)
	b.gui_input.connect(func(e: InputEvent):
		if _is_tap(e):
			V9Feel.press(b)
			cb.call())
	parent.add_child(b)
	return b

func _second_button(parent: Control, text: String, pos: Vector2, cb: Callable, w: = 260.0) -> Control:
	var b: = Control.new()
	b.size = Vector2(w, 80)
	b.position = pos
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	var l: = UI.label(text + "  ›", 22, D.PAPER_100, Color(0, 0, 0, 0), 0, "body", 800)
	l.size = b.size
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	b.add_child(l)
	b.gui_input.connect(func(e: InputEvent):
		if _is_tap(e):
			V9Feel.press(b, "tap")
			cb.call())
	parent.add_child(b)
	return b

# ---------------------------------------------------------------- hand tally: combinations row by row, scores roll
func combo_rows(ev: Dictionary) -> Array:
	var rows: = []
	for y in ev.get("yaku", []):
		var id: = String(y[0])
		var v: = "+%d" % int(y[1]) if int(ev.get("yakuman", 0)) == 0 else ("Легенда" if int(y[1]) == 1 else "Легенда ×%d" % int(y[1]))
		rows.append([id, D.combo_name(id), D.combo_orig(id), v])
	for b in ["dora", "aka", "ura"]:
		if int(ev.get(b, 0)) > 0:
			rows.append([b, D.combo_name(b), D.combo_orig(b), "+%d" % int(ev[b])])
	return rows

func _show_tally() -> void:
	if sheet and is_instance_valid(sheet) and sheet.has_meta("tally"):
		return
	var e: = hand_res
	var h: = minf(H * 0.78, 980.0)
	var s: = _open_sheet(h)
	sheet.set_meta("tally", true)
	var y: = 28.0
	var r: = drv.r
	if e.get("ev", "") == "win":
		var w: = int(e.seat)
		var ev: Dictionary = e.eval
		var title: = "Победа · " + ("цумо" if e.tsumo else "рон")
		var t: = UI.label(title, 44, D.PAPER_100, Color(0, 0, 0, 0), 0, "title", 700)
		t.position = Vector2(32, y)
		s.add_child(t)
		var who_txt: = name_of(w)
		if not e.tsumo:
			who_txt += " · твой сброс" if int(e.from) == me else " · сбросила " + name_of(int(e.from))
		var who: = UI.label(who_txt, 22, D.PAPER_300, Color(0, 0, 0, 0), 0, "body", 800)
		who.position = Vector2(34, y + 58)
		s.add_child(who)
		var pp: = V10MjRiichiPortrait.make(partner if w == me else String(heroes[w]), 96, color_of(w))
		pp.position = Vector2(W - 128, y)
		pp.set_face("happy", true)
		s.add_child(pp)
		y += 116
		# the winning hand
		var tsz: = Vector2(36, 50) if W < 900 else Vector2(44, 60)
		var hand: Array = e.hand.duplicate()
		var x: = 32.0
		for t2 in hand:
			var tv: = V10MjRiichiTile.make(int(t2), tsz, 0)
			tv.position = Vector2(x, y)
			tv.shadow = false
			s.add_child(tv)
			x += tsz.x
		if not e.tsumo:
			x += 8
			var tw2: = V10MjRiichiTile.make(int(e.tile), tsz, 0)
			tw2.position = Vector2(x, y)
			tw2.fresh = true
			s.add_child(tw2)
			x += tsz.x
		for md in e.melds:
			x += 8
			for mt in _meld_tiles(md, w):
				var msz: = tsz * 0.85
				if mt[1]:
					msz = Vector2(msz.y, msz.x)
				var tv3: = V10MjRiichiTile.make(-1 if mt[2] else int(mt[0]), msz, 90 if mt[1] else 0)
				tv3.back_path = _back_path()
				tv3.position = Vector2(x, y + tsz.y - msz.y)
				tv3.shadow = false
				s.add_child(tv3)
				x += msz.x
		y += tsz.y + 18
		var rows: = combo_rows(ev)
		var i: = 0
		for row in rows:
			var rr: = _combo_row(s, row, y, i)
			y += rr
			i += 1
		y += 6
		var lim: = D.limit_ru(String(ev.get("limit", "")))
		var tot_txt: = ("%s · " % lim if lim != "" else "") + "%d хан · %d фу" % [int(ev.han), int(ev.fu)] if int(ev.get("yakuman", 0)) == 0 else lim
		var tot: = UI.label(tot_txt, 22, D.PAPER_300, Color(0, 0, 0, 0), 0, "body", 800)
		tot.position = Vector2(32, y + 8)
		s.add_child(tot)
		var pts: = UI.label("+" + _fmt(int(e.delta[w])), 40, D.GOLD_300, Color(0, 0, 0, 0), 0, "body", 900)
		pts.position = Vector2(W - 240, y)
		pts.size.x = 208
		pts.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		s.add_child(pts)
		y += 60
		# the winner reads it out (her line; the stage voice if present)
		if w != me:
			barks.say(String(heroes[w]), "tsumo" if e.tsumo else "ron")
	else:
		var t3: = UI.label("Ничья · стена кончилась", 40, D.PAPER_100, Color(0, 0, 0, 0), 0, "title", 700)
		t3.position = Vector2(32, y)
		s.add_child(t3)
		y += 72
		for st in visible_seats():
			var ten: bool = st in e.get("tenpai", [])
			var l: = UI.label("%s — %s" % [name_of(st), "готова" if ten else "не готова"], 22, D.JADE_300 if ten else D.PAPER_500, Color(0, 0, 0, 0), 0, "body", 800)
			l.position = Vector2(32, y)
			s.add_child(l)
			if ten and st != me:
				var x2: = 300.0
				for t4 in V8Mj.sort_tiles(e.hands[st]):
					var tv4: = V10MjRiichiTile.make(int(t4), Vector2(26, 36), 0)
					tv4.position = Vector2(x2, y - 4)
					tv4.shadow = false
					s.add_child(tv4)
					x2 += 26
			y += 44
		y += 8
	# scores: roll with ± arrows
	y = _score_rows(s, y, e.get("delta", [0, 0, 0, 0]))
	var nxt: = "Итог партии" if drv.r.state == "end" else "Дальше"
	_main_button(s, nxt, y + 12, _tally_next)
	_fit_sheet(s, y + 132)

func _combo_row(s: Control, row: Array, y: float, i: int) -> float:
	var holder: = Control.new()
	holder.position = Vector2(24, y)
	holder.size = Vector2(W - 48, 44)
	holder.mouse_filter = Control.MOUSE_FILTER_STOP
	holder.name = "Combo_" + String(row[0])
	s.add_child(holder)
	var nm: = UI.label(String(row[1]), 24, D.PAPER_100, Color(0, 0, 0, 0), 0, "title", 600)
	nm.position = Vector2(8, 2)
	holder.add_child(nm)
	nm.reset_size()
	var og: = UI.label("Комбинация · " + String(row[2]) if not (String(row[0]) in ["dora", "aka", "ura"]) else String(row[2]), 18, D.PAPER_500, Color(0, 0, 0, 0), 0, "body", 800)
	og.position = Vector2(nm.size.x + 22, 8)
	holder.add_child(og)
	var v: = UI.label(String(row[3]), 24, D.GOLD_300, Color(0, 0, 0, 0), 0, "body", 900)
	v.position = Vector2(holder.size.x - 140, 4)
	v.size.x = 132
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	holder.add_child(v)
	holder.gui_input.connect(func(e: InputEvent):
		if _is_tap(e):
			_open_glossary(String(row[0]), holder))
	if not _fx_min() and not auto_flow:
		holder.modulate.a = 0.0
		var tw: = holder.create_tween()
		tw.tween_interval(0.25 * i + 0.2)
		tw.tween_callback(func(): _sfx("star%d" % (i % 3), -10))
		tw.tween_property(holder, "modulate:a", 1.0, 0.18)
	return 46.0

# V10Glossary if the glossary lane is merged; otherwise the line opens in place (no window over the tally)
func _open_glossary(id: String, holder: Control) -> void:
	for c in ProjectSettings.get_global_class_list():
		if String(c.get("class", "")) == "V10Glossary":
			var g = load(String(c.path))
			if g and g.has_method("open"):
				g.open(main if main else self, id)
				return
	var ex: Label = holder.get_node_or_null("Hint")
	if ex:
		ex.queue_free()
		holder.size.y = 44
		return
	var l: = UI.label(D.combo_hint(id), 18, D.JADE_300, Color(0, 0, 0, 0), 0, "body", 800)
	l.name = "Hint"
	l.position = Vector2(8, 34)
	l.size = Vector2(holder.size.x - 16, 24)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	holder.add_child(l)
	holder.size.y = 64

func _score_rows(s: Control, y: float, delta: Array) -> float:
	var r: = drv.r
	for st in visible_seats():
		var row: = Control.new()
		row.position = Vector2(24, y)
		row.size = Vector2(W - 48, 48)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		s.add_child(row)
		var p: = V10MjRiichiPortrait.make(partner if st == me else String(heroes[st]), 40, color_of(st))
		p.position = Vector2(4, 4)
		row.add_child(p)
		var nm: = UI.label(name_of(st), 22, D.PAPER_100, Color(0, 0, 0, 0), 0, "body", 800)
		nm.position = Vector2(56, 10)
		row.add_child(nm)
		var sc: = UI.label(_fmt(shown_scores[st]), 24, D.PAPER_100, Color(0, 0, 0, 0), 0, "body", 900)
		sc.position = Vector2(row.size.x - 330, 8)
		sc.size.x = 150
		sc.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(sc)
		var d: = int(delta[st])
		if d != 0:
			var ar: = UI.label(("▲ +" if d > 0 else "▼ ") + _fmt(d), 22, D.JADE_300 if d > 0 else D.EMBER, Color(0, 0, 0, 0), 0, "body", 900)
			ar.position = Vector2(row.size.x - 170, 10)
			ar.size.x = 166
			ar.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			row.add_child(ar)
		var from_v: int = shown_scores[st]
		var to_v: int = r.scores[st]
		if auto_flow or _fx_min():
			sc.text = _fmt(to_v)
		else:
			var tw: = sc.create_tween()
			tw.tween_interval(0.6)
			tw.tween_method(func(v: float): sc.text = _fmt(int(roundf(v / 100.0)) * 100), float(from_v), float(to_v), 0.9).set_trans(Tween.TRANS_QUAD)
		y += 52
	shown_scores = r.scores.duplicate()
	return y

func _tally_next() -> void:
	_close_sheet()
	hand_res = {}
	drv.release("result")
	drv.resume()

# ---------------------------------------------------------------- match end, rewards, «Честный стол»
var final_result: = {}

func _on_match_end(res: Dictionary) -> void:
	music.stop()
	var place: int = int(res.place[me])
	var rw: = D.rewards(place, fmt)
	var hp: = -1
	var fl: = -1
	var Sd: = D._S()
	if Sd.has("rp"):
		hp = int(Sd.rp)
		var g: = get_node_or_null("/root/G")
		if g and g.has_method("rank_floor"):
			fl = int(g.rank_floor(hp))
	var rp: = D.rp_delta(String(hall.id), place, hp, fl)
	D.record_match(String(hall.id), fmt, place, seed)
	var st: = V10MjRiichiStats.get_stats()
	V10MjRiichiStats.add_match(st, place)
	final_result = {"mode": "riichi", "win": place == 1, "score": int(res.scores[me]), "stars": 0,
		"time_s": int(Time.get_ticks_msec() / 1000.0 - t_start), "pairs": 0, "hero": partner, "seed": seed,
		"rewards": {"coins": rw.coins, "gems": rw.gems, "petals": 0, "aff": rw.aff},
		"place": place, "hall": String(hall.id), "format": fmt, "rp": rp, "scores": res.scores.duplicate(),
		"first_today": rw.first_today, "one_hand_today": rw.one_hand_today}
	_show_end()

func _show_end() -> void:
	var res: = final_result
	var s: = _open_sheet(minf(H * 0.82, 1040.0))
	sheet.set_meta("end", true)
	var y: = 28.0
	var t: = UI.label("Итог партии", 44, D.PAPER_100, Color(0, 0, 0, 0), 0, "title", 700)
	t.position = Vector2(32, y)
	s.add_child(t)
	var sub: = UI.label("%s зал · %s" % [hall.name, D.FORMATS[fmt].name], 22, D.PAPER_300, Color(0, 0, 0, 0), 0, "body", 800)
	sub.position = Vector2(34, y + 58)
	s.add_child(sub)
	y += 112
	var ord: Array = drv.r.placements()
	var n: = 0
	for st in ord:
		if not visible_rel(rel(st)):
			continue
		n += 1
		var row: = Control.new()
		row.position = Vector2(24, y)
		row.size = Vector2(W - 48, 76)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.draw.connect(func():
			if st == me:
				var sb: = StyleBoxFlat.new()
				sb.bg_color = Color(D.NIGHT_600, 0.7)
				sb.set_corner_radius_all(4)
				row.draw_style_box(sb, Rect2(Vector2.ZERO, row.size)))
		s.add_child(row)
		var pl: = UI.label(str(n), 40, D.GOLD_300 if n == 1 else D.PAPER_300, Color(0, 0, 0, 0), 0, "body", 900)
		pl.position = Vector2(12, 12)
		row.add_child(pl)
		var p: = V10MjRiichiPortrait.make(partner if st == me else String(heroes[st]), 60, color_of(st))
		p.position = Vector2(56, 8)
		p.set_face("happy" if n == 1 else ("sad" if n == 4 else "neutral"), true)
		row.add_child(p)
		var nm: = UI.label(name_of(st), 24, D.PAPER_100, Color(0, 0, 0, 0), 0, "body", 800)
		nm.position = Vector2(132, 22)
		row.add_child(nm)
		var sc: = UI.label(_fmt(int(drv.r.scores[st])), 26, D.PAPER_100, Color(0, 0, 0, 0), 0, "body", 900)
		sc.position = Vector2(row.size.x - 200, 20)
		sc.size.x = 188
		sc.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(sc)
		y += 84
	y += 8
	var rw: Dictionary = res.rewards
	var parts: = ["+%d монет" % int(rw.coins)]
	if int(rw.gems) > 0:
		parts.append("+%d кристаллов" % int(rw.gems))
	var rl: = UI.label("  ·  ".join(parts), 26, D.GOLD_300, Color(0, 0, 0, 0), 0, "body", 900)
	rl.position = Vector2(32, y)
	s.add_child(rl)
	y += 40
	var why: = []
	if res.first_today:
		why.append("первая партия дня")
	if res.one_hand_today:
		why.append("раздача дня")
	if not why.is_empty():
		var wl: = UI.label(", ".join(why), 18, D.PAPER_500, Color(0, 0, 0, 0), 0, "body", 800)
		wl.position = Vector2(34, y)
		s.add_child(wl)
	y += 40
	_main_button(s, "Ещё партия", y, _again)
	y += 108
	_second_button(s, "Показать сид", Vector2(32, y), _show_seed)
	_second_button(s, "К столам", Vector2(W - 292, y), _leave)
	_fit_sheet(s, y + 104)

func _show_seed() -> void:
	var s: = _open_sheet(minf(H * 0.7, 900.0))
	sheet.set_meta("seed", true)
	var y: = 28.0
	var t: = UI.label("Честный стол", 44, D.PAPER_100, Color(0, 0, 0, 0), 0, "title", 700)
	t.position = Vector2(32, y)
	s.add_child(t)
	y += 70
	var l: = UI.label("Сид партии: %d" % seed, 26, D.GOLD_300, Color(0, 0, 0, 0), 0, "body", 900)
	l.position = Vector2(32, y)
	s.add_child(l)
	y += 44
	var ok: = seed_check()
	var l2: = UI.label("Стена первой раздачи из сида %s" % ("совпадает со сдачей партии ✓" if ok else "не совпала"), 20, D.JADE_300 if ok else D.EMBER, Color(0, 0, 0, 0), 0, "body", 800)
	l2.position = Vector2(32, y)
	l2.size.x = W - 64
	l2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	s.add_child(l2)
	y += 60
	# the wall in draw order, first 51 tiles (deal + first turns)
	var wall: = V10MjRiichiDriver.wall_for_seed(seed, heroes)
	var tsz: = Vector2(36, 50)
	var per: = int((W - 64) / tsz.x)
	for i in mini(wall.size(), per * 4):
		var tv: = V10MjRiichiTile.make(int(wall[i]), tsz, 0)
		tv.position = Vector2(32 + (i % per) * tsz.x, y + floorf(i / float(per)) * (tsz.y + 6))
		tv.shadow = false
		s.add_child(tv)
	y += 4 * (tsz.y + 6) + 12
	var l3: = UI.label("Любой может повторить эту стену: сид задаёт перемешивание до раздачи.", 18, D.PAPER_500, Color(0, 0, 0, 0), 0, "body", 800)
	l3.position = Vector2(32, y)
	l3.size.x = W - 64
	l3.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	s.add_child(l3)
	y += 60
	_main_button(s, "Назад", y, _show_end)
	_fit_sheet(s, y + 124)

func seed_check() -> bool:
	return V10MjRiichiDriver.wall_for_seed(seed, heroes) == drv.first_wall and not drv.first_wall.is_empty()

func _again() -> void:
	_close_sheet()
	var a: = args.duplicate()
	a["hall"] = String(hall.id)
	a.erase("seed")
	finished.emit(final_result.merged({"again": true}))
	_restart(a)

func _restart(a: Dictionary) -> void:
	if drv:
		drv.queue_free()
	if barks:
		barks.queue_free()
	if music:
		music.queue_free()
	drv = null
	started = false
	for c in get_children():
		c.queue_free()
	reactions.clear()
	said_no = 0
	turn_count = 0
	sticker_cd = [0, 0, 0, 0]
	yakuman_shown = false
	setup(main, a)

func _leave() -> void:
	_close_sheet()
	finished.emit(final_result)
	if main and main.has_method("back"):
		main.back()

# ---------------------------------------------------------------- pause: toggles live here (screen budget stays ≤ 6 taps)
func _open_pause() -> void:
	drv.hold("pause")
	var s: = _open_sheet(620)
	sheet.set_meta("pause", true)
	var t: = UI.label("Пауза", 44, D.PAPER_100, Color(0, 0, 0, 0), 0, "title", 700)
	t.position = Vector2(32, 28)
	s.add_child(t)
	var rows: = [
		["Горизонтальный стол", "вкл" if horizontal else "выкл", _pause_horizontal],
		["Названия", "русские" if names_mode == "ru" else "японские", _pause_names],
		["Стикеры соперниц", "вкл" if stickers_on else "тихо", _pause_stickers],
	]
	var y: = 110.0
	for rw in rows:
		var b: = _second_button(s, "%s: %s" % [rw[0], rw[1]], Vector2(32, y), rw[2], W - 64)
		(b.get_child(0) as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		y += 84
	_main_button(s, "Продолжить", y + 16, _pause_continue)
	_second_button(s, "Выйти из партии", Vector2((W - 300) * 0.5, y + 124), _pause_quit, 300)

func _pause_continue() -> void:
	_close_sheet()
	drv.release("pause")

func _pause_quit() -> void:
	_close_sheet()
	music.stop()
	final_result = {"mode": "riichi", "win": false, "score": 0, "stars": 0, "time_s": int(Time.get_ticks_msec() / 1000.0 - t_start),
		"pairs": 0, "hero": partner, "seed": seed, "rewards": {"coins": 0, "gems": 0, "petals": 0, "aff": 0}, "abandoned": true,
		"hall": String(hall.id), "format": fmt}
	_leave()

func _pause_horizontal() -> void:
	horizontal = not horizontal
	D.set_pref("horizontal", 1 if horizontal else 0)
	_close_sheet()
	drv.release("pause")
	_layout()
	_build()
	if drv.waiting:
		_on_asked(drv.r.ask)
	_open_pause()

func _pause_names() -> void:
	names_mode = "jp" if names_mode == "ru" else "ru"
	D.set_pref("names", names_mode)
	if drv.waiting:
		_show_buttons(drv.r.ask)
	_open_pause()

func _pause_stickers() -> void:
	_toggle_stickers()
	_open_pause()

# ---------------------------------------------------------------- hall picker (when the hub opens the mode without a hall)
var lobby_hall: = "school"

func _lobby() -> void:
	for c in get_children():
		c.queue_free()
	var bgl: = TextureRect.new()
	var cp: = "res://assets/v10/mj/riichi/cloth_%s.webp" % D.hall(lobby_hall).cloth
	if ResourceLoader.exists(cp):
		bgl.texture = load(cp)
	bgl.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bgl.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bgl.size = Vector2(W, H)
	bgl.modulate = Color(0.55, 0.55, 0.6)
	add_child(bgl)
	var safe_t: = maxf(0.0, float(main.safe_top) - position.y) if (main != null and "safe_top" in main) else 0.0
	var back_b: = Control.new()
	back_b.name = "LobbyBack"
	back_b.position = Vector2(24, safe_t + 14.0)
	back_b.size = Vector2(56, 56)
	back_b.mouse_filter = Control.MOUSE_FILTER_STOP
	back_b.draw.connect(func():
		var sb: = StyleBoxFlat.new()
		sb.bg_color = Color(D.NIGHT_700, 0.94)
		sb.border_color = Color(D.GOLD_500, 0.92)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(28)
		back_b.draw_style_box(sb, Rect2(Vector2.ZERO, back_b.size)))
	var back_l: = UI.label("‹", 34, D.GOLD_300, Color(0, 0, 0, 0.65), 3, "body", 900)
	back_l.position = Vector2(0, -2)
	back_l.size = back_b.size
	back_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	back_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	back_b.add_child(back_l)
	back_b.gui_input.connect(func(e: InputEvent):
		if _is_tap(e):
			back_b.accept_event()
			V9Feel.press(back_b, "tap")
			if main != null and main.has_method("back"):
				main.back())
	add_child(back_b)
	var top: = maxf(safe_t + 82.0, 82.0 + maxf(0.0, H - 1280.0) * 0.22)

	var ov: = UI.label("СТОЛЫ · ЯПОНСКИЙ МАДЖОНГ", 15, D.GOLD_500, Color(0, 0, 0, 0), 0, "body", 900)
	ov.position = Vector2(32, top)
	add_child(ov)
	var t: = UI.label(V10MjRiichiInfo.INFO.name, 44, D.PAPER_100, Color(0, 0, 0, 0.5), 3, "title", 700)
	t.position = Vector2(32, top + 24)
	add_child(t)
	var ln: = UI.label(V10MjRiichiInfo.INFO.line, 22, D.PAPER_300, Color(0, 0, 0, 0.5), 2, "body", 800)
	ln.position = Vector2(32, top + 84)
	add_child(ln)
	var y: = top + 140
	var shown_locked: = false
	for h in D.HALLS:
		var gate: = D.hall_gate(String(h.id))
		if not gate.open:
			if shown_locked:
				continue
			shown_locked = true
		var card: = Control.new()
		card.position = Vector2(32, y)
		card.size = Vector2(W - 64, 104)
		card.name = "Hall_" + String(h.id)
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		var hid: String = h.id
		var open: bool = gate.open
		card.draw.connect(func():
			var sb: = StyleBoxFlat.new()
			sb.bg_color = Color(D.NIGHT_800, 0.9) if lobby_hall != hid else Color(D.NIGHT_600, 0.95)
			sb.border_color = Color(D.GOLD_500, 0.9) if lobby_hall == hid else Color(D.GOLD_700, 0.35)
			sb.set_border_width_all(2 if lobby_hall == hid else 1)
			sb.corner_radius_top_left = 12
			sb.corner_radius_bottom_right = 12
			card.draw_style_box(sb, Rect2(Vector2.ZERO, card.size)))
		var nm: = UI.label(String(h.name) + " зал", 26, D.PAPER_100 if open else D.PAPER_700, Color(0, 0, 0, 0), 0, "body", 800)
		nm.position = Vector2(20, 14)
		card.add_child(nm)
		var l2: = UI.label(String(h.line) if open else String(gate.why), 18, D.PAPER_500 if open else D.PAPER_700, Color(0, 0, 0, 0), 0, "body", 800)
		l2.position = Vector2(20, 56)
		l2.size.x = card.size.x - 40
		l2.clip_text = true
		card.add_child(l2)
		card.gui_input.connect(func(e: InputEvent):
			if _is_tap(e):
				if not open:
					V9Feel.deny(card)
					return
				lobby_hall = hid
				V9Feel.press(card, "tap")
				_lobby())
		add_child(card)
		y += 116
	y += 8
	var fx0: = 32.0
	var fw: = (W - 64 - 16) / 3.0
	for f in ["east", "east_south", "one_hand"]:
		var fb: = Control.new()
		fb.position = Vector2(fx0, y)
		fb.size = Vector2(fw, 80)
		fb.name = "Fmt_" + f
		fb.mouse_filter = Control.MOUSE_FILTER_STOP
		var ff: String = f
		fb.draw.connect(func():
			var sb: = StyleBoxFlat.new()
			sb.bg_color = Color(D.NIGHT_600, 0.95) if fmt == ff else Color(D.NIGHT_800, 0.8)
			sb.border_color = Color(D.GOLD_500, 0.8 if fmt == ff else 0.25)
			sb.set_border_width_all(1)
			sb.set_corner_radius_all(4)
			fb.draw_style_box(sb, Rect2(Vector2.ZERO, fb.size)))
		var fl: = UI.label(D.FORMATS[f].name, 20, D.PAPER_100 if fmt == f else D.PAPER_300, Color(0, 0, 0, 0), 0, "body", 800)
		fl.size = fb.size
		fl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		fb.add_child(fl)
		fb.gui_input.connect(func(e: InputEvent):
			if _is_tap(e):
				fmt = ff
				V9Feel.press(fb, "tap")
				_lobby())
		add_child(fb)
		fx0 += fw + 8
	y += 104
	var stc: Dictionary = V10MjRiichiStats.get_stats()
	if int(stc.matches) > 0:
		var card: = V10MjRiichiStats.card(stc)
		var sl: = UI.label("%s %s · %s %s" % [card[0][0], card[0][1], card[1][0], card[1][1]], 18, D.PAPER_300, Color(0, 0, 0, 0.6), 3, "body", 800)
		sl.position = Vector2(32, y - 16)
		add_child(sl)
		y += 24
	var play_y: = minf(y, H - 140)
	# magazine cover: the partner steps out past the right edge, under the play button
	var ap: = V10W1Core.hero_png(partner)
	if ResourceLoader.exists(ap):
		var art: = TextureRect.new()
		art.texture = load(ap)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		var ah: = maxf(320.0, H - play_y - 96.0 + 40.0)
		art.size = Vector2(ah * 0.671, ah)
		art.position = Vector2(W - art.size.x * 0.82, play_y + 104)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(art)
	_main_button(self, "Играть", play_y, func():
		for c in get_children():
			c.queue_free()
		_begin(lobby_hall))
