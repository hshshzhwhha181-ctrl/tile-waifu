class_name V10MjPresence
extends Control

# V10MjPresence — the director of «she is here, but never in the way» for EVERY match screen (docs/MODES.md §3,
# lane `stage`). One object per match screen: modes only report what happened (on(event, data)); the director
# decides what she does, under one budget (V10MjBudget) and one hard rule: while input is on, not one pixel of
# her, her text or her effects is over the sacred zone (board + tray/hand + help row, +8 px) — except the pair
# motes, which fly over it for ≤ 0.45 s.
#
#   var p: = V10MjPresence.new().attach(self, "mc", {...})    adds itself to `parent`, full rect, on top
#   p.sacred(rect)                    register a sacred rect (screen px; called many times = union). +8 px pad.
#   p.clear_sacred()
#   p.on(event, data = {})            the event dictionary of §3.2 (see EVENTS / TABLE_EVENTS)
#   p.set_mode("live" | "quiet" | "finish_only")      (the player's «Героиня в партии»)
#   p.input_on = bool                 the host's «board accepts taps» (or opts.board with .input_on, polled)
#   p.apply_settings()                re-read V10MjStageSettings (pause sheet changed them)
#   signals: reacted(event, info) — every outcome (selftest, logs); finale_done — the win/lose exit finished;
#            portrait_tapped — the player tapped her window (host: open the Приём sheet if it is ready)
#
# opts: band ("top" | "bottom"), band_h (120), band_rect (Rect2: explicit), avoid (Array[Rect2]: host HUD that the
#   text and the peek must not cover — pause, «Осталось N»), board (Object with input_on), charge_need (8 pairs),
#   source ("auto" | "rig" | "video" | "static"), fx ("full" | "mid" | "min", default G.fx_level()),
#   mode / inserts / voice (override the saved settings), seed (int, deterministic variants), clock (Callable,
#   synthetic time for the budget), z (z_index, default 40), idle_after (s, default 20), first_today (bool).
# data keys read (public only — PUBLIC_KEYS; anything else, e.g. data.hidden, is dropped before any decision,
#   so an AI rival's face can never leak her hand — §3.4.5 «Честный стол»):
#   pos (Vector2 screen px of a pick / pair), n (combo), on (danger), who ("me" | a seat/hero id), kind
#   (pon | chi | kan for `call`), charge (0..1, the host's real Приём gauge), need, first_today.

signal reacted(event: String, info: Dictionary)
signal finale_done
signal portrait_tapped

const PAD: = 8.0
const EVENTS: = ["pick", "pair", "combo", "motif", "danger", "signature", "wave", "ult", "last_pair", "win", "lose",
	"idle", "mech_intro"]
const TABLE_EVENTS: = ["call", "riichi", "dora", "ron", "tsumo", "tenpai", "noten", "dealin", "kita"]
const PUBLIC_KEYS: = ["pos", "n", "on", "who", "kind", "charge", "need", "first_today", "wave", "seat"]
const MODES: = ["live", "quiet", "finish_only"]
const SFX_DIR: = "res://assets/v10/mj/stage/sfx/"
const RIBBON_T: = 0.7

var hero_id: = "mc"
var mode: = "live"
var inserts: = "always"
var voice_on: = true
var fx: = "full"
var input_on: = true
var board: Object = null
var accent: = Color.WHITE
var opts: = {}
var sacred_rects: Array = []  # Array[Rect2], padded
var avoid: Array = []
var band: V10MjPresenceBand
var peek: V10MjEdgePeek
var trail: V10MjPairTrail
var barks: V10MjBarks
var budget: V10MjBudget
var queue: V10MjInputQueue
var edge: _WarmEdge
var ribbon: _Ribbon
var sfx_player: AudioStreamPlayer
var charge: = 0.0
var charge_need: = 8
var danger: = false
var band_rect: = Rect2()
var free_band: = Rect2()
var text_rect: = Rect2()
var log: Array = []  # last 200 outcomes [t, event, acts]
var counts: = {"voice": 0, "peek": 0, "micro": 0, "block": 0, "events": 0}
var _picks_since_pair: = 0
var _last_move_t: = 0.0
var _idle_armed: = true
var _inserts_seen: = {}
var _finale: = false


func attach(parent: Node, hero: String, o: = {}) -> V10MjPresence:
	hero_id = hero
	opts = o
	name = "V10MjPresence"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = int(o.get("z", 40))
	var st: = V10MjStageSettings.st()
	mode = String(o.get("mode", st.get("mode", "live")))
	if not mode in MODES:
		mode = "live"
	inserts = String(o.get("inserts", st.get("inserts", "always")))
	voice_on = bool(o.get("voice", st.get("voice", true)))
	fx = String(o.get("fx", V10MjStageData.fx_level()))
	board = o.get("board", null)
	avoid = o.get("avoid", [])
	charge_need = int(o.get("charge_need", 8))
	accent = V10MjStageData.accent(hero)
	budget = V10MjBudget.new()
	if o.get("clock", null) is Callable:
		budget.clock = o.clock
	parent.add_child(self)
	if parent is Control:
		set_anchors_preset(Control.PRESET_FULL_RECT)
	else:
		position = Vector2.ZERO
		size = get_viewport_rect().size
	queue = V10MjInputQueue.new()
	add_child(queue)
	edge = _WarmEdge.new()
	edge.director = self
	add_child(edge)
	band = V10MjPresenceBand.new()
	add_child(band)
	band.build(hero, Rect2(0, 0, 80, 100), {"fx": fx, "quiet": mode != "live", "source": o.get("source", "auto")})
	band.portrait_tapped.connect(func(): portrait_tapped.emit())
	ribbon = _Ribbon.new()
	ribbon.col = accent
	add_child(ribbon)
	peek = V10MjEdgePeek.new()
	peek.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(peek)
	peek.finished.connect(_on_peek_done)
	barks = V10MjBarks.new()
	barks.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(barks)
	barks.setup(hero, budget, {"voice": voice_on, "quiet": mode == "quiet", "fx": fx, "seed": int(o.get("seed", 0))})
	trail = V10MjPairTrail.new()
	trail.fx = fx
	add_child(trail)
	trail.arrived.connect(_on_mote_arrived)
	sfx_player = AudioStreamPlayer.new()
	sfx_player.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	add_child(sfx_player)
	for c in get_children():
		if c is Control:
			(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	_last_move_t = budget.now()
	get_viewport().size_changed.connect(_layout)
	_layout()
	band.set_charge(0.0, false)
	return self


func set_mode(m: String) -> void:
	if not m in MODES:
		return
	mode = m
	barks.quiet = m == "quiet"
	band.quiet = m != "live"
	if m != "live":
		_set_danger(false)
		barks.hide_now()
		if not _finale:
			peek.skip(true)


func apply_settings() -> void:
	var st: = V10MjStageSettings.st()
	set_mode(String(st.get("mode", mode)))
	inserts = String(st.get("inserts", inserts))
	voice_on = bool(st.get("voice", voice_on))
	barks.voice_on = voice_on


func sacred(rect: Rect2) -> void:
	sacred_rects.append(rect.grow(PAD))
	trail.sacred = sacred_rects
	_layout()


func clear_sacred() -> void:
	sacred_rects.clear()
	trail.sacred = sacred_rects
	_layout()


func is_input_on() -> bool:
	if board != null and is_instance_valid(board) and "input_on" in board:
		return bool(board.get("input_on")) and input_on
	return input_on


# ── layout: her band, the window, the text place, the peek zones ─────────────────────────────────────────────

func screen() -> Vector2:
	if opts.get("screen", null) is Vector2:
		return opts.screen
	return get_viewport_rect().size


func sacred_bounds() -> Rect2:
	if sacred_rects.is_empty():
		return Rect2()
	var b: Rect2 = sacred_rects[0]
	for r in sacred_rects:
		b = b.merge(r)
	return b


func _layout() -> void:
	if band == null:
		return
	var S: = screen()
	var top: = String(opts.get("band", "top")) != "bottom"
	var bh: = float(opts.get("band_h", 120.0 if top else 200.0))
	var extra: = maxf(0.0, S.y - S.x * 16.0 / 9.0)
	if opts.get("band_rect", null) is Rect2:
		band_rect = opts.band_rect
	elif top:
		band_rect = Rect2(0, 0, S.x, bh + extra)
	else:
		band_rect = Rect2(0, S.y - bh - extra, S.x, bh + extra)
	# the part of the band no sacred rect touches
	free_band = band_rect
	for r in sacred_rects:
		var rr: Rect2 = r
		if not rr.intersects(free_band):
			continue
		if top:
			free_band.size.y = maxf(0.0, rr.position.y - free_band.position.y)
		else:
			var e: = free_band.end.y
			free_band.position.y = minf(e, rr.end.y)
			free_band.size.y = e - free_band.position.y
	var ring: = V10MjPresenceBand.RING_GAP + V10MjPresenceBand.RING_W + 2.0
	var avail_h: = free_band.size.y - 2.0 * ring - 4.0
	var h: = clampf(avail_h, 56.0, 140.0 + extra * 0.85)
	var w: = minf(h * 0.8, S.x * 0.42)
	if h * 0.8 > S.x * 0.42:
		h = minf(h, w * 1.6)
	var x: = S.x - 24.0 - ring - w
	var y: float
	if extra > 60.0:
		# 9:20+: the window is a stage standing on the table's edge
		y = free_band.end.y - ring - h
	else:
		y = free_band.position.y + (free_band.size.y - h) * 0.5
	band.set_window(Rect2(x, y, w, h))
	# her line: at her shoulder, left of the window, inside the free band, away from the host HUD
	var tw: = minf(330.0, x - ring - 16.0 - 24.0)
	var th: = minf(80.0, free_band.size.y - 8.0)
	var ty: = clampf(y + h * 0.5 - th * 0.5, free_band.position.y + 4.0, free_band.end.y - th - 4.0)
	text_rect = Rect2(x - ring - 12.0 - tw, ty, tw, th)
	for a in avoid:
		var ar: Rect2 = a
		if ar.intersects(text_rect):
			var nx: = ar.end.x + 12.0
			text_rect.size.x = text_rect.end.x - nx
			text_rect.position.x = nx
	if text_rect.size.x < 140.0 or _hits_sacred(text_rect):
		text_rect = Rect2()
	edge.queue_redraw()


func _hits_sacred(r: Rect2) -> bool:
	for s in sacred_rects:
		if (s as Rect2).intersects(r):
			return true
	return false


# where she may step out now: the band left of the window (behind the table's top edge), or a side margin
func peek_zone(finale: = false) -> Dictionary:
	var S: = screen()
	if finale:
		return {"rect": Rect2(0, S.y * 0.22, S.x, S.y * 0.78), "edge": "bottom", "big": true, "x": 0.5}
	var sb: = sacred_bounds()
	var best: = {}
	var best_area: = 0.0
	if sb.size.x > 0.0:
		var left_w: = sb.position.x
		var right_w: = S.x - sb.end.x
		var y0: = free_band.end.y
		var hh: = sb.end.y - y0
		if left_w > 48.0 and hh > 200.0:
			var r: = Rect2(0, y0, left_w, minf(hh, 640.0))
			if r.get_area() > best_area:
				best = {"rect": r, "edge": "left"}
				best_area = r.get_area()
		if right_w > 48.0 and hh > 200.0:
			var r2: = Rect2(sb.end.x, y0, right_w, minf(hh, 640.0))
			if r2.get_area() > best_area:
				best = {"rect": r2, "edge": "right"}
				best_area = r2.get_area()
	# the band span left of the window, clear of the host HUD (pause, «Осталось N»): on a tall band she rises from
	# behind the HUD row; on a 120 px band the span starts right of it
	var wl: = band.window_outer().position.x - 8.0
	var br: = Rect2(16.0, free_band.position.y, wl - 16.0, free_band.size.y)
	for a in avoid:
		var ar: Rect2 = a
		if not ar.intersects(br):
			continue
		if ar.position.y - br.position.y >= 180.0:
			br.size.y = ar.position.y - 4.0 - br.position.y
		elif wl - (ar.end.x + 8.0) >= 120.0:
			br.size.x = br.end.x - (ar.end.x + 8.0)
			br.position.x = ar.end.x + 8.0
		else:
			br = Rect2()
			break
	if br.size.x >= 120.0 and br.size.y >= 64.0 and (best.is_empty() or br.get_area() * 1.6 >= best_area):
		best = {"rect": br, "edge": "bottom", "x": 1.0}
	return best


# ── events ────────────────────────────────────────────────────────────────────────────────────────────────────

func _public(data: Dictionary) -> Dictionary:
	var d: = {}
	for k in PUBLIC_KEYS:
		if data.has(k):
			d[k] = data[k]
	return d


func on(event: String, data: = {}) -> Dictionary:
	var d: = _public(data)
	var acts: Array = []
	counts.events += 1
	if d.has("charge"):
		charge = clampf(float(d.charge), 0.0, 1.0)
		band.set_charge(charge)
	if d.has("need"):
		charge_need = maxi(1, int(d.need))
	var live: = mode == "live"
	var shows: = mode != "finish_only"  # quiet still lives in her window
	match event:
		"pick":
			budget.note_move()
			_moved()
			_picks_since_pair += 1
			if shows and d.has("pos"):
				band.react("glance", 0.8, d.pos)
				acts.append("glance")
		"pair":
			if _picks_since_pair == 0:
				budget.note_move(2)
			_picks_since_pair = 0
			_moved()
			var from: Vector2 = d.get("pos", sacred_bounds().get_center())
			var n: = trail.burst(from, band.window.get_global_rect().get_center(), accent)
			acts.append("motes:%d" % n)
			if shows and budget.take_micro():
				band.react("smile", 0.4)
				acts.append("smile")
		"combo":
			var n: = int(d.get("n", 0))
			if shows and n >= 8 and budget.take_micro():
				band.react("pose", 0.6)
				acts.append("pose")
			elif shows and n >= 5 and budget.take_micro():
				band.react("clap", 0.6)
				acts.append("clap")
			elif shows and n >= 3 and budget.take_micro():
				band.react("nod", 0.4)
				acts.append("nod")
			if live and n in [5, 8, 12]:
				_bark("pair_combo", acts)
		"motif":
			if shows and budget.take_micro():
				band.react("wink", 0.4)
				acts.append("wink")
		"danger":
			var on_: = bool(d.get("on", true))
			if shows:
				band.react("bite" if on_ else "calm")
				acts.append("bite" if on_ else "calm")
			_set_danger(on_ and live)
			if on_ and live:
				_bark("danger", acts)
		"signature":
			charge = minf(1.0, charge + 0.25)
			band.set_charge(charge)
			band.tick()
			_sfx("sting_%s" % V10MjStageLines.hero_key(hero_id), -2.0)
			acts.append("sting")
			if shows and budget.take_micro():
				band.react("ah", 0.6)
				acts.append("ah")
			if live:
				_bark("signature", acts)
		"wave":
			if live:
				_peek("wave", "select", acts)
				_bark("wave", acts)
			elif shows:
				band.react("smile", 0.6)
				acts.append("smile")
		"ult":
			charge = 0.0
			band.set_charge(0.0)
			if shows:
				band.react("pose", 0.6)
				acts.append("pose")
		"last_pair":
			if shows and budget.take_micro():
				band.react("look_camera", 1.4)
				acts.append("look_camera")
		"win", "lose":
			input_on = false
			_set_danger(false)
			band.react(event, 1.6)
			acts.append(event)
			_finale = true
			_peek(event, event, acts, true)
			_bark(event, acts, true)
		"idle":
			if shows and budget.take_idle():
				band.react("look_camera", 1.2)
				acts.append("look_camera")
				if live:
					_bark("idle", acts)
		"mech_intro":
			if shows:
				band.react("ah", 0.8)
				acts.append("ah")
			if live:
				_bark("mech_intro", acts)
		_:
			if event in TABLE_EVENTS:
				_table(event, d, acts)
			else:
				push_warning("V10MjPresence: unknown event '%s'" % event)
	var info: = {"event": event, "acts": acts}
	log.append([budget.now(), event, acts])
	if log.size() > 200:
		log.pop_front()
	reacted.emit(event, info)
	return info


func _table(event: String, d: Dictionary, acts: Array) -> void:
	# the player's partner voices the PLAYER's own calls (like a table character does), and only looks up at the
	# rivals' public actions. Nothing here reads a rival's hand: only who / kind / public flags.
	var mine: = String(d.get("who", "me")) == "me"
	var shows: = mode != "finish_only"
	var live: = mode == "live"
	var line: = event
	if event == "call":
		line = String(d.get("kind", "pon"))
		if not line in ["pon", "chi", "kan"]:
			line = "pon"
	if shows:
		match event:
			"dora", "kita":
				band.react("ah", 0.5)
				acts.append("ah")
			"noten":
				band.react("lose", 0.8)
				acts.append("lose")
			"dealin":
				band.react("lose" if mine else "ah", 0.8)
				acts.append("lose" if mine else "ah")
			"ron", "tsumo":
				band.react("win" if mine else "ah", 1.0)
				acts.append("win" if mine else "ah")
			_:
				band.react("glance" if not mine else "nod", 0.6, band.window.get_global_rect().get_center())
				acts.append("nod" if mine else "glance")
	if live and event in ["riichi", "ron", "tsumo"] and _insert_ok(event, mine):
		ribbon.play(band_rect, fx)
		acts.append("ribbon")
	if live and mine and line in V10MjStageLines.TABLE_EVENTS:
		_bark(line, acts, event in ["ron", "tsumo"])


func _insert_ok(kind: String, mine: bool) -> bool:
	match inserts:
		"off":
			return false
		"mine":
			return mine
		"first_day":
			var key: = kind + Time.get_date_string_from_system()
			if _inserts_seen.has(key) or bool(opts.get("first_today_seen_%s" % kind, false)):
				return false
			_inserts_seen[key] = true
			return true
	return true


func _bark(ev: String, acts: Array, finish: = false) -> void:
	if mode == "quiet":
		return
	if mode == "finish_only" and not ev in ["win", "lose"]:
		return
	# her line never sits on her own peek: beside the figure if there is room, else after she has gone back
	var place: = text_rect
	var later: = false
	if peek.active and place.size.x > 0.0 and peek.final_rect.intersects(place):
		var f: = peek.final_rect
		var lft: = Rect2(place.position, Vector2(f.position.x - 8.0 - place.position.x, place.size.y))
		var rgt: = Rect2(Vector2(f.end.x + 8.0, place.position.y), Vector2(place.end.x - f.end.x - 8.0, place.size.y))
		place = lft if lft.size.x >= rgt.size.x else rgt
		if place.size.x < 140.0:
			place = Rect2()
			later = true
	var r: = barks.say(ev, place, finish)
	if r.is_empty():
		return
	if later:
		var txt: = String(r.text)
		peek.finished.connect(func(): barks.show_line(txt, text_rect), CONNECT_ONE_SHOT)
		acts.append("text_after_peek")
	acts.append("line:" + String(r.line))
	if r.voice:
		counts.voice += 1
		acts.append("voice")
		if band.source == "rig":
			band.react("talk", 1.6)


func _peek(ev: String, slot: String, acts: Array, finale: = false) -> void:
	if mode == "quiet":
		return
	if mode == "finish_only" and not finale:
		return
	if not budget.take_peek(ev):
		return
	var blk: = budget.block_for(ev)
	if blk > 0.0:
		queue.block(blk)
		counts.block += 1
		acts.append("block")
	var z: = peek_zone(finale)
	if z.is_empty():
		return
	if peek.play(hero_id, slot, z, {"fx": fx, "hold": 1.6 if finale else 1.0}):
		# a line still on screen never sits under her: it goes (the new line finds its own place)
		if barks.is_showing() and barks.label.get_global_rect().intersects(peek.final_rect):
			barks.hide_now()
		counts.peek += 1
		acts.append("peek:" + String(z.edge))
		_sfx("peek_in", -8.0)
		V9Feel.haptic("tap")


func _on_peek_done() -> void:
	if _finale:
		_finale = false
		finale_done.emit()


func _on_mote_arrived() -> void:
	if not opts.has("charge_from_host"):
		charge = minf(1.0, charge + 1.0 / float(charge_need))
	band.set_charge(charge)
	band.tick()


func _moved() -> void:
	_last_move_t = budget.now()
	_idle_armed = true


func _set_danger(on_: bool) -> void:
	if danger == on_:
		return
	danger = on_
	edge.set_on(on_ and fx != "min", fx)
	if on_:
		_sfx("heartbeat", -6.0)


func _sfx(id: String, db: = 0.0) -> void:
	var p: = SFX_DIR + id + ".ogg"
	if not ResourceLoader.exists(p):
		return
	var g = get_tree().root.get_node_or_null("G") if get_tree() else null
	if g and g.get("S") is Dictionary and not bool((g.S as Dictionary).get("sound", true)):
		return
	sfx_player.stream = load(p)
	sfx_player.volume_db = db
	sfx_player.play()


func _input(e: InputEvent) -> void:
	# a tap during the win / lose exit skips it (the queue may also be holding it: skipping is harmless)
	if _finale and peek.active and e is InputEventScreenTouch and e.pressed:
		peek.skip()


func _process(_dt: float) -> void:
	if not is_input_on() or mode == "finish_only" or not _idle_armed:
		return
	if budget.now() - _last_move_t >= float(opts.get("idle_after", 20.0)):
		_idle_armed = false
		on("idle")


# every on-screen rect of hers that is not a pair mote (sacred-zone audit, selftest 1)
func audit_rects() -> Array:
	var out: = [band.window_outer()]
	if peek.active:
		out.append(peek.visible_rect())
	if barks.is_showing():
		out.append(barks.label.get_global_rect())
	if ribbon.visible:
		out.append(ribbon.get_global_rect())
	out.append_array(edge.segments())
	return out


func sacred_hits() -> Array:
	var bad: = []
	for r in audit_rects():
		var rr: Rect2 = r
		if rr.size.x <= 0.0 or rr.size.y <= 0.0:
			continue
		for s in sacred_rects:
			if (s as Rect2).intersects(rr):
				bad.append([rr, s])
	return bad


# ── the warm edge (danger) and the table ribbon ─────────────────────────────────────────────────────────────

class _WarmEdge extends Control:
	var director: V10MjPresence
	var on: = false
	var _t: = 0.0
	var _a: = 0.0
	const W: = 22.0

	func _init() -> void:
		name = "WarmEdge"
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)
		set_process(false)

	func set_on(v: bool, fx_level: String) -> void:
		on = v
		if fx_level == "min" and v:
			_a = 0.32
		set_process(true)
		queue_redraw()

	func _process(dt: float) -> void:
		_t += dt
		var target: = 0.0
		if on:
			# a slow heartbeat (≈ 1 Hz, two beats), no flashes (UX §6.7)
			var ph: = fmod(_t, 1.05)
			target = 0.26 + 0.12 * (exp(-pow((ph - 0.08) / 0.07, 2.0)) + 0.6 * exp(-pow((ph - 0.3) / 0.07, 2.0)))
		_a = move_toward(_a, target, dt * 1.6)
		if not on and _a <= 0.001:
			set_process(false)
		queue_redraw()

	func segments() -> Array:
		if director == null or _a <= 0.001:
			return []
		var S: = director.screen()
		var strips: = [Rect2(0, 0, W, S.y), Rect2(S.x - W, 0, W, S.y), Rect2(0, 0, S.x, W), Rect2(0, S.y - W, S.x, W)]
		var out: = []
		for s in strips:
			out.append_array(V10MjPresence.rect_minus(s, director.sacred_rects))
		return out

	func _draw() -> void:
		if _a <= 0.001:
			return
		var c: Color = V10MjStageData.TOK.ember
		var S: = director.screen()
		for r in segments():
			var rr: Rect2 = r
			# gradient towards the inside of the screen
			var inner: = Color(c.r, c.g, c.b, 0.0)
			var outer: = Color(c.r, c.g, c.b, _a)
			var p: = PackedVector2Array([rr.position, Vector2(rr.end.x, rr.position.y), rr.end, Vector2(rr.position.x, rr.end.y)])
			var cols: PackedColorArray
			if rr.size.x <= W + 0.5 and rr.position.x <= 0.5:
				cols = PackedColorArray([outer, inner, inner, outer])
			elif rr.size.x <= W + 0.5 and rr.end.x >= S.x - 0.5:
				cols = PackedColorArray([inner, outer, outer, inner])
			elif rr.position.y <= 0.5:
				cols = PackedColorArray([outer, outer, inner, inner])
			else:
				cols = PackedColorArray([inner, inner, outer, outer])
			draw_polygon(p, cols)


class _Ribbon extends Control:
	var col: = Color.WHITE
	var _tw: Tween

	func _init() -> void:
		name = "Ribbon"
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		visible = false

	func play(r: Rect2, fx_level: String) -> void:
		# a band of her colour sweeps her band for 0.7 s (riichi / win at the table), input stays free
		position = Vector2(r.position.x, r.position.y + r.size.y * 0.5 - 18.0)
		size = Vector2(r.size.x, 36.0)
		visible = true
		modulate.a = 0.0
		if _tw and _tw.is_valid():
			_tw.kill()
		_tw = create_tween()
		V10MjStageFx.step(_tw, self, "modulate:a", 0.85, 0.12, Tween.TRANS_SINE, Tween.EASE_OUT)
		_tw.tween_interval(V10MjPresence.RIBBON_T - 0.32)
		V10MjStageFx.step(_tw, self, "modulate:a", 0.0, 0.2, Tween.TRANS_SINE, Tween.EASE_IN)
		_tw.tween_callback(func(): visible = false)
		queue_redraw()

	func _draw() -> void:
		var a: = Color(col.r, col.g, col.b, 0.0)
		var b: = Color(col.r, col.g, col.b, 0.55)
		var p: = PackedVector2Array([Vector2(0, 6), Vector2(size.x, 0), Vector2(size.x, size.y - 6), Vector2(0, size.y)])
		draw_polygon(p, PackedColorArray([a, b, b, a]))


# r minus every rect of `cut` (axis-aligned difference, up to 4 pieces per cut)
static func rect_minus(r: Rect2, cut: Array) -> Array:
	var pieces: = [r]
	for c in cut:
		var cr: Rect2 = c
		var next: = []
		for p in pieces:
			var pr: Rect2 = p
			if not pr.intersects(cr):
				next.append(pr)
				continue
			var i: = pr.intersection(cr)
			if i.position.y > pr.position.y:
				next.append(Rect2(pr.position.x, pr.position.y, pr.size.x, i.position.y - pr.position.y))
			if i.end.y < pr.end.y:
				next.append(Rect2(pr.position.x, i.end.y, pr.size.x, pr.end.y - i.end.y))
			if i.position.x > pr.position.x:
				next.append(Rect2(pr.position.x, i.position.y, i.position.x - pr.position.x, i.size.y))
			if i.end.x < pr.end.x:
				next.append(Rect2(i.end.x, i.position.y, pr.end.x - i.end.x, i.size.y))
		pieces = next
	return pieces.filter(func(p): return (p as Rect2).size.x > 0.5 and (p as Rect2).size.y > 0.5)
