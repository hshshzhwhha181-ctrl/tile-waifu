class_name V10TutMatch
extends Node
# Match driver (README §2.7). Attached by V10Tutorial when screen_id == "play" and the screen has a TrayBoard `board`.
#   L1 (lvl 0, mode "", first match not done, hints on — or a replay): after the start banner m_a → m_b (a guided pair),
#   m_left, m_free, m_tray after the 2nd pair; then free play with ≤ 3 silent rings after 20 s idle; m_danger, m_ult;
#   win → first_match_done + v_stars / v_home on the victory UI; fail → m_fail.
#   Any other match: at most ONE mechanic line per match, each once ever (match_help, match_combo, match_fever,
#   match_stake; m_danger / m_ult while unseen).
# Lines sit in the heroine zone (place "hero", anchor = hero_anchor()), never over the field; dim only for m_a / m_b.
# Nothing shows while the combo showcase runs, an ult / cut-in is busy, a modal is up or the table takes no input.
#
# Observable state (tests, bot): V10TutMatch.inst, .phase ("start" | "play" | "won" | "failed" | "over"), .step
# (key on the coach now), .l1, .pairs, .rings, .mech_done, .tile_a / .tile_b (the spotlighted tiles), V10TutMatch.trace.

const POLL: = 0.2
const START_DELAY: = 1.4      # after the table takes input (banner, deal, greet)
const TIP_WAIT: = 6.0         # the 0.9 intro card in the bottom band: wait for it at most this long
const IDLE_RING: = 20.0
const MAX_RINGS: = 3
const GAP: = 0.6              # between two lines
const VICTORY_SETTLE: = 1.8
const MATCH_DIM: = 0.45
const GUIDED: = ["m_a", "m_b", "m_left", "m_free", "m_tray"]
const TIMEOUTS: = {"m_a": 40.0, "m_b": 40.0, "m_left": 6.0, "m_tray": 6.0, "m_ult": 10.0, "v_home": 15.0,
	"match_help": 6.0, "match_stake": 6.0}

static var inst: V10TutMatch
static var replay_l1: = false         # V10Tutorial.event("replay_first_match"): the next L1 replays the guided steps
static var victory_pending: = false   # L1 won, v_stars / v_home not shown yet (the orchestrator may show them elsewhere)
static var trace: Array = []          # keys shown, in order (tests)

var tut: V10Tutorial
var screen: Node
var board: TrayBoard
var l1: = false
var lvl: = 0
var mode: = ""
var phase: = "start"
var step: = ""
var pairs: = 0
var rings: = 0
var mech_done: = false
var tile_a = null   # Tile
var tile_b = null   # Tile

var _queue: Array = []   # [{key, until}]
var _timer: Timer
var _hud: V10HudMatch
var _showcase: V10ComboShowcase
var _sc_paused: = false
var _ready_t: = -1.0
var _start_t: = 0.0
var _last_move: = 0.0
var _gap_until: = 0.0
var _end_t: = -1.0
var _ui_t: = -1.0
var _taken_n: = 0
var _taken = null        # Tile last taken into the tray
var _prev_skill: = false
var _prev_danger: = false
var _prev_fever: = false
var _prev_stake: = false


static func attach_to(t: V10Tutorial, scr: Node) -> V10TutMatch:
	if inst != null and is_instance_valid(inst):
		if inst.screen == scr:
			return inst
		inst.stop()
	var b = scr.get("board")
	if not (b is TrayBoard):
		return null
	var m: = V10TutMatch.new()
	m.name = "V10TutMatch"
	m.tut = t
	m.screen = scr
	m.board = b
	m.process_mode = Node.PROCESS_MODE_PAUSABLE
	inst = m
	t.add_child(m)
	return m


func _ready() -> void:
	_start_t = _now()
	_last_move = _start_t
	lvl = int(_sv("lvl", 0))
	mode = String(_sv("mode", ""))
	l1 = lvl == 0 and mode == "" and (replay_l1 or (V10TutState.hints_on() and not V10TutState.first_match_done()))
	if l1:
		replay_l1 = false
		V10TutState.funnel_mark("l1_start")
	_taken_n = _taken_count()
	board.matched.connect(_on_matched)
	board.tray_changed.connect(_on_tray)
	board.failed.connect(_on_failed)
	board.cleared.connect(_on_cleared)
	for k in ["hud", "hud2"]:
		var h = _sv(k, null)
		if h is V10HudMatch:
			_hud = h
	if _hud != null:
		_hud.helper_pressed.connect(func(_k: String): _last_move = _now())
		_hud.ult_pressed.connect(_on_ult_used)
	_find_showcase()
	_timer = Timer.new()
	_timer.wait_time = POLL
	_timer.autostart = true
	_timer.timeout.connect(_poll)
	add_child(_timer)


# skip_all(): no more lines from this match
func halt() -> void:
	l1 = false
	_queue.clear()
	phase = "over"
	victory_pending = false


func stop() -> void:
	if is_instance_valid(board):
		for pair in [[board.matched, _on_matched], [board.tray_changed, _on_tray], [board.failed, _on_failed],
				[board.cleared, _on_cleared]]:
			if (pair[0] as Signal).is_connected(pair[1]):
				(pair[0] as Signal).disconnect(pair[1])
	if tut != null and is_instance_valid(tut):
		tut.release("match")
	step = ""
	if inst == self:
		inst = null
	queue_free()


# ---------------------------------------------------------------- tile targets --------------------------------------

# Provider for match.tile_a (i = 0) / match.tile_b (i = 1): the tile while it lies on the table, else null.
static func tile_rect(i: int):
	if inst == null or not is_instance_valid(inst) or not is_instance_valid(inst.board):
		return null
	var t = inst.tile_a if i == 0 else inst.tile_b
	if not (t is Tile) or not is_instance_valid(t) or not (t as Tile).is_inside_tree() or not (t as Tile).visible:
		return null
	var tl: = t as Tile
	if not inst.board.on_board(tl) or tl.pending:
		return null
	var xf: = tl.get_global_transform_with_canvas()
	var r: = xf * Rect2(Vector2(-Tile.TW * 0.5, -Tile.TH * 0.5), Vector2(Tile.TW, Tile.TH))
	return {"rect": r, "radius": 6.0 * xf.get_scale().x, "node": tl}


# A: board.best_move() with a free twin B (B can complete the pair). If best_move's twin is covered, any free pair.
func _pick_pair() -> void:
	tile_a = null
	tile_b = null
	var fr: Array = board.free_tiles().filter(func(t): return not t.pending and t.ice <= 0)
	var a = board.best_move()
	if a is Tile:
		for t in fr:
			if t != a and t.face == a.face:
				tile_a = a
				tile_b = t
				return
	var by: = {}
	for t in fr:
		if by.has(t.face):
			tile_a = by[t.face]
			tile_b = t
			return
		by[t.face] = t
	tile_a = a


# B after a tile went into the tray: a free tile on the table with the same face (the planned twin first).
func _pick_twin() -> bool:
	var x = _taken if _taken is Tile and board.tray.has(_taken) else (board.tray.back() if not board.tray.is_empty() else null)
	if not (x is Tile):
		return false
	var face: int = (x as Tile).face
	for c in [tile_b, tile_a]:
		if c is Tile and c != x and board.on_board(c) and board.is_free(c) and not c.pending and c.face == face:
			tile_b = c
			return true
	for t in board.free_tiles():
		if not t.pending and t.face == face:
			tile_b = t
			return true
	tile_b = null
	return false


# ---------------------------------------------------------------- board events --------------------------------------

func _taken_count() -> int:
	var dead: = 0
	for t in board.tiles:
		if not t.alive:
			dead += 1
	return board.history.size() + dead


func _on_tray() -> void:
	var n: = _taken_count()
	if n > _taken_n:
		_last_move = _now()
		if not board.history.is_empty():
			_taken = board.history.back()
		if step == "m_a" or step == "ring":
			tut.complete_step("target", "match")
	_taken_n = n


func _on_matched(_mid: Vector2, combo: int, _gold: bool, _shard: String) -> void:
	_last_move = _now()
	if bool(_sv("v9_from_ult", false)):
		return
	pairs += 1
	if pairs == 1:
		V10TutState.funnel_mark("first_pair")
	if step == "m_b" or step == "ring":
		tut.complete_step("target", "match")
	if l1:
		_enqueue_once("m_left")
		_enqueue_once("m_free")
		if pairs >= 2:
			_enqueue_once("m_tray")
	elif combo >= 2 and (lvl >= 1 or mode != ""):
		_mech("match_combo", 4.0)


func _on_failed() -> void:
	_queue.clear()
	if step != "":
		tut.complete_step("lost", "match")
	if l1 and V10TutState.hints_on() and not V10TutState.seen("m_fail"):
		phase = "failed"
		_end_t = _now()


func _on_cleared() -> void:
	_queue.clear()
	if step != "":
		tut.complete_step("lost", "match")
	if not l1:
		phase = "over"
		return
	V10TutState.set_first_match_done()
	V10TutState.funnel_mark("l1_win")
	V10TutState.save()
	phase = "won"
	_end_t = _now()
	victory_pending = V10TutState.hints_on() and not V10TutState.seen("v_home")


func _on_ult_used() -> void:
	V10TutState.funnel_mark("first_ult")
	_queue = _queue.filter(func(q): return String(q.key) != "m_ult")
	if step == "m_ult":
		tut.complete_step("target", "match")


# ---------------------------------------------------------------- poll ----------------------------------------------

func _alive() -> bool:
	return screen != null and is_instance_valid(screen) and screen.is_inside_tree() and board != null \
		and is_instance_valid(board) and board.is_inside_tree() and tut != null and is_instance_valid(tut)


func _poll() -> void:
	if not _alive():
		stop()
		return
	var t: = _now()
	_read_state()
	match phase:
		"start":
			_try_start(t)
		"won":
			_victory_tick(t)
		"failed":
			_fail_tick(t)
	if phase == "play":
		_idle_ring(t)
	_pump(t)


func _read_state() -> void:
	var skill: = bool(_sv("skill_ready", false))
	if skill and not _prev_skill:
		_special("m_ult")
	elif not skill and _prev_skill:
		_on_ult_used()
	_prev_skill = skill
	if step == "m_ult" and _ult_busy():
		_on_ult_used()
	var danger: = bool(_sv("_v6_danger", false)) or board.tray.size() >= maxi(3, board.slots - 1)
	if danger and not _prev_danger and phase == "play":
		_special("m_danger")
	_prev_danger = danger
	var fever: = _fever_on()
	if fever and not _prev_fever:
		_mech("match_fever", 6.0)
	_prev_fever = fever
	var stake: = _stake_visible()
	if stake and not _prev_stake:
		_mech("match_stake", 10.0)
	_prev_stake = stake


func _try_start(t: float) -> void:
	if not board.input_on:
		return
	if _ready_t < 0.0:
		_ready_t = t
		return
	if t - _ready_t < START_DELAY or bool(_sv("_v8_modal", false)):
		return
	if _tip_visible() and t - _ready_t < TIP_WAIT:
		return
	phase = "play"
	_last_move = t
	if l1:
		# a quick player may have started already: guide only what is still ahead
		if pairs == 0 and board.tray.is_empty():
			if not V10TutState.seen("m_a"):
				_queue.push_front({"key": "m_a", "until": 0.0})
		elif pairs == 0:
			V10TutState.mark("m_a")
			if not V10TutState.seen("m_b"):
				_queue.push_front({"key": "m_b", "until": 0.0})
		else:
			V10TutState.mark("m_a")
			V10TutState.mark("m_b")
	elif V10Reveal.is_open("match.help"):
		_mech("match_help", 20.0)


func _idle_ring(t: float) -> void:
	if not l1 or rings >= MAX_RINGS or t - _last_move < IDLE_RING:
		return
	if tut._showing() or not _queue.is_empty() or not board.input_on or _quiet():
		return
	var a = board.best_move()
	if not (a is Tile):
		return
	tile_a = a
	var spec: = {"id": "ring", "line": "", "mode": "ring", "target": "match.tile_a", "dim": 0.0, "place": "hero", "ctx": "match",
		"anchor": hero_anchor(), "avoid": avoid_rects(), "hold": 0.0, "timeout": 6.0, "skippable": false,
		"speaker": speaker(), "portrait": false, "root": tut.main}
	if tut.show_spec(spec, "match", func(_r: String): _done("ring", _r)):
		step = "ring"
		rings += 1
		_last_move = t
		trace.append("ring")


func _victory_tick(t: float) -> void:
	if tut._showing() or t < _gap_until:
		return
	var ui: bool = V10TutTarget.find(tut.main, "win.next").ok or V10TutTarget.find(tut.main, "win.home").ok
	if not ui:
		if t - _end_t > 15.0:
			phase = "over"   # victory_pending stays: the orchestrator may find the victory on another screen
		return
	if _ui_t < 0.0:
		_ui_t = t
		return
	if t - _ui_t < VICTORY_SETTLE:
		return
	if not V10TutState.hints_on():
		phase = "over"
		victory_pending = false
	elif not V10TutState.seen("v_stars"):
		_show_now("v_stars")
	elif not V10TutState.seen("v_home") and V10TutTarget.find(tut.main, "win.home").ok:
		_show_now("v_home")
	else:
		phase = "over"   # no «В чайную» on this victory: v_home is skipped silently
		victory_pending = false


func _fail_tick(t: float) -> void:
	if tut._showing():
		return
	if V10TutTarget.find(tut.main, "fail.retry").ok:
		_show_now("m_fail")
		phase = "play"
	elif t - _end_t > 4.0:
		phase = "play"   # the tray came back without a window (omikuji rescue)


# ---------------------------------------------------------------- queue ---------------------------------------------

func _enqueue_once(key: String) -> void:
	if V10TutState.seen(key) or step == key:
		return
	for q in _queue:
		if String(q.key) == key:
			return
	_queue.append({"key": key, "until": 0.0})


# m_danger / m_ult: once ever; on L1 always allowed, elsewhere they are this match's one mechanic line
func _special(key: String) -> void:
	if not V10TutState.hints_on() or V10TutState.seen(key) or (not l1 and mech_done):
		return
	_enqueue_once(key)
	if key == "m_danger":
		_queue[_queue.size() - 1]["until"] = _now() + 3.0
		# a warning is now or never: in front of the queue
		var q: Dictionary = _queue.pop_back()
		_queue.push_front(q)


func _mech(key: String, ttl: float) -> void:
	if l1 or mech_done or not V10TutState.hints_on() or V10TutState.seen(key):
		return
	_enqueue_once(key)
	for q in _queue:
		if String(q.key) == key:
			q["until"] = _now() + ttl


func _valid(q: Dictionary) -> bool:
	var key: = String(q.key)
	if float(q.until) > 0.0 and _now() > float(q.until):
		return false
	if V10TutState.seen(key):
		return false
	match key:
		"m_ult":
			return bool(_sv("skill_ready", false)) and not _ult_busy()
		"match_fever":
			return _fever_on()
		"match_stake":
			return _stake_visible()
	if not l1 and key.begins_with("match_") and mech_done:
		return false
	return true


func _pump(t: float) -> void:
	if _queue.is_empty() or t < _gap_until or tut._showing():
		return
	_queue = _queue.filter(func(q): return _valid(q))
	if _queue.is_empty():
		return
	if phase != "play" or not board.input_on or _quiet():
		return
	var key: = String(_queue[0].key)
	var r: = _show_key(key)
	if r != 0:
		_queue.pop_front()


# 1 shown, 0 not now (stays queued), -1 dropped
func _show_key(key: String) -> int:
	match key:
		"m_a":
			_pick_pair()
			if not (tile_a is Tile):
				return -1
		"m_b":
			if not _pick_twin():
				return -1
		"m_free":
			var a = board.best_move()
			if not (a is Tile):
				return -1
			tile_a = a
	var spec: = _spec(key)
	var e: Dictionary = V10TutLines.MATCH[key]
	if String(e.mode) != "wait" and String(spec.target) != "" and not V10TutTarget.find(tut.main, String(spec.target)).ok:
		return -1   # a spotlight with nothing to show: drop it, the line is not marked seen
	if not tut.show_spec(spec, "match", func(res: String): _done(key, res)):
		return 0
	step = key
	trace.append(key)
	if not l1 and (key.begins_with("match_") or key == "m_danger" or key == "m_ult"):
		mech_done = true
	return 1


func _show_now(key: String) -> void:
	var spec: = _spec(key)
	if tut.show_spec(spec, "match", func(res: String): _done(key, res)):
		step = key
		trace.append(key)


func _spec(key: String) -> Dictionary:
	var e: Dictionary = V10TutLines.MATCH[key]
	var m: = String(e.mode)
	var post: = key.begins_with("v_") or key == "m_fail"
	var tg: = String(e.target)
	if tg != "" and m == "wait" and not V10TutTarget.find(tut.main, tg).ok:
		tg = ""   # a line without a window rather than no line
	return {
		"id": key,
		"line": V10TutLines.match_line(key, {"n": board.slots}),
		"speaker": speaker(),
		"portrait": false if post else not V10TutTarget.find(tut.main, "match.hero").ok,
		"target": tg,
		"mode": m,
		"dim": MATCH_DIM if key == "m_a" or key == "m_b" else 0.0,
		"place": "auto" if post else "hero",
		"ctx": "work" if post else "match",
		"anchor": hero_anchor(),
		"avoid": [] if post else avoid_rects(),
		"hold": 4.0,
		"timeout": float(TIMEOUTS.get(key, 6.0 if m == "tap" else 4.0)),
		"skippable": l1 and key in GUIDED,
		"root": tut.main,
	}


func _done(key: String, res: String) -> void:
	if step == key:
		step = ""
	_gap_until = _now() + GAP
	if res == "skip":
		return
	if key == "ring":
		return
	V10TutState.mark(key)
	V10TutState.save()
	match key:
		"m_a":
			if _taken is Tile and board.tray.has(_taken):
				_queue.push_front({"key": "m_b", "until": 0.0})
		"v_home":
			victory_pending = false
			phase = "over"


# ---------------------------------------------------------------- placement -----------------------------------------

func speaker() -> String:
	if l1:
		return "mc"
	var p: = String(_sv("partner", "mc"))
	return p if p != "" else "mc"


# The line's zone next to the heroine. HUD v2: x 232–520 under the tray (HUD_V2 §8.1, y ≈ 912).
# 0.9 play.gd: the band under the field (the help-button row; the 0.9 intro card uses the same band) — the field,
# the tray and the portrait are never covered.
func hero_anchor() -> Rect2:
	if _hud != null and is_instance_valid(_hud):
		var tr: Rect2 = _hud.L.get("tray", Rect2(16, 792, 688, 104))
		return Rect2(tr.position.x + 216.0, tr.end.y + 4.0, 288.0, 112.0)
	var sr: = _screen_rect()
	var f: = _field_rect()
	var bottom: = sr.end.y - 8.0
	var top: = minf(f.end.y + 8.0, bottom - 104.0)
	return Rect2(sr.position.x + 24.0, top, sr.size.x - 48.0, bottom - top)


func avoid_rects() -> Array:
	if _hud != null and is_instance_valid(_hud):
		return [_hud.hero_face_global().grow(48.0), _hud.board_rect()]
	var f: = _field_rect()
	return [f] if f.size.x > 2.0 else []


func _screen_rect() -> Rect2:
	if screen is Control:
		return (screen as Control).get_global_rect()
	return get_viewport().get_visible_rect()


# The field in viewport px: HUD v2 board_rect(), the 0.9 board_rect (what the coach also avoids as match.board),
# grown to every tile still on the table.
func _field_rect() -> Rect2:
	var r: = Rect2()
	if _hud != null and is_instance_valid(_hud):
		r = _hud.board_rect()
	elif screen is Control and "board_rect" in screen:
		var br: Rect2 = screen.get("board_rect")
		r = (screen as Control).get_global_transform_with_canvas() * br
	for t in board.tiles:
		if not board.on_board(t) or not t.visible:
			continue
		var tr: = t.get_global_transform_with_canvas() * Rect2(Vector2(-Tile.TW * 0.5, -Tile.TH * 0.5), Vector2(Tile.TW, Tile.TH))
		r = tr if r.size.x < 2.0 else r.merge(tr)
	return r


# ---------------------------------------------------------------- state readers -------------------------------------

func _sv(key: String, def):
	if screen == null or not is_instance_valid(screen) or not (key in screen):
		return def
	var v = screen.get(key)
	return def if v == null else v


func _ult_busy() -> bool:
	var u = _sv("ult", null)
	return u is Object and is_instance_valid(u) and "busy" in u and bool(u.get("busy"))


func _fever_on() -> bool:
	var fu = _sv("fever_until", -1.0)
	if not (fu is float or fu is int):
		return false
	var nw: float = float(screen.call("now")) if screen.has_method("now") else (G.time if G != null else 0.0)
	return nw < float(fu)


func _stake_visible() -> bool:
	var b = _sv("riichi_btn", null)
	if b is CanvasItem and is_instance_valid(b) and (b as CanvasItem).is_visible_in_tree():
		return true
	if _hud != null and is_instance_valid(_hud) and _hud.stake != null and _hud.stake.is_visible_in_tree() \
			and _hud.stake.modulate.a > 0.5:
		return true
	return false


func _find_showcase() -> void:
	var sc = _sv("showcase", null)
	if not (sc is V10ComboShowcase) and screen != null:
		for c in screen.get_children():
			if c is V10ComboShowcase:
				sc = c
				break
	if sc is V10ComboShowcase:
		_showcase = sc
		_showcase.input_paused.connect(func(on: bool): _sc_paused = on)


func _tip_visible() -> bool:
	for n in get_tree().get_nodes_in_group("v6_tip"):
		if n is CanvasItem and (n as CanvasItem).is_visible_in_tree() and not n.is_queued_for_deletion() \
				and (n as CanvasItem).modulate.a > 0.1:
			return true
	return false


# The table is busy with something that must not get a line on top of it.
func _quiet() -> bool:
	if tut._hard_blocked() or tut._popup_open():
		return true
	if bool(_sv("_v8_modal", false)) or _ult_busy() or _sc_paused:
		return true
	if _showcase != null and is_instance_valid(_showcase) and _showcase.active:
		return true
	return false


static func _now() -> float:
	return Time.get_ticks_msec() * 0.001
