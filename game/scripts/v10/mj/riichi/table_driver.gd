class_name V10MjRiichiDriver
extends Node

# Adapter over the unchanged v08 engine (V8Round.advance()/answer()).
# - Paces AI turns 0.35–0.9 s by style (Эстафета fast, Лунная тень slow), ×hall pace.
# - While the player's decision is pending the driver never blocks input: it only waits for answer().
# - Dead-time holds (cut-ins, the hand tally) pause the engine; hold() refuses while a decision is pending.
# - Derives the public «said» stream (call / riichi / dora / ron / tsumo / dealin / tenpai / noten) from engine
#   events, because V8Round declares `said` but does not emit it. If a future engine emits it, the driver forwards
#   the engine's own stream and stops deriving (no doubles).
# - Undo for the training hall: snapshots of the whole engine state at each of the player's turn decisions.

signal event(e: Dictionary)
signal asked(a: Dictionary)
signal answered(a: Dictionary)
signal said(seat: int, what: String, data: Dictionary)
signal rewound()
signal finished(result: Dictionary)

const PUBLIC_KEYS: = ["kind", "tsumo", "yakuman", "limit", "seat", "from", "han", "riichi_n", "last"]
const PAUSE_MIN: = 0.35
const PAUSE_MAX: = 0.9

var r: V8Round
var me: = 0
var hero_of: = ["player", "mc", "rin", "hana"]
var pace: = 1.0
var one_hand: = false
var running: = false
var waiting: = false
var auto_human: = false
var over: = false
var final: = {}
var timer: = 0.0
var holds: = {}
var rng: = RandomNumberGenerator.new()
var snaps: = []
var undo_left: = 0
var first_wall: = []
var said_log: = []
var engine_said: = false
var riichi_n: = 0
var hands_done: = 0
var last_event: = {}
var _dora_n: = 0
var _kan_seat: = -1

# opts: {seed, length ("east"|"south"), heroes: [4 ids, "player" for the human], me: seat (-1 = all AI), pace, one_hand, undo}
func setup(opts: Dictionary) -> V10MjRiichiDriver:
	r = V8Round.new()
	me = int(opts.get("me", 0))
	hero_of = opts.get("heroes", hero_of).duplicate()
	pace = float(opts.get("pace", 1.0))
	one_hand = bool(opts.get("one_hand", false))
	undo_left = int(opts.get("undo", 0))
	var pl: = []
	for s in 4:
		var h: String = hero_of[s]
		pl.append({"id": h if V8AI.STYLES.has(h) else "mc", "ctl": "human" if s == me else "ai", "hero": h})
	var o: = {"seed": int(opts.get("seed", 1)), "length": String(opts.get("length", "east")), "players": pl}
	if opts.has("dealer"):
		o["dealer"] = int(opts.dealer)
	r.setup(o)
	rng.seed = int(opts.get("seed", 1)) ^ 0x5eed
	r.said.connect(_on_engine_said)
	return self

func start() -> void:
	running = true
	timer = 0.2

# ------------------------------------------------------------------ stepping
func _process(dt: float) -> void:
	if not running or over or waiting or not holds.is_empty():
		return
	timer -= dt
	var guard: = 0
	while timer <= 0.0 and guard < 12 and not waiting and holds.is_empty() and not over:
		guard += 1
		var e: = step()
		timer += delay_after(e)

func step() -> Dictionary:
	if over or waiting:
		return {}
	var e: Dictionary = r.advance()
	_handle(e)
	return e

func _handle(e: Dictionary) -> void:
	var ev: String = e.get("ev", "")
	last_event = e
	match ev:
		"deal":
			snaps.clear()
			_dora_n = r.dora_ind.size()
			riichi_n = 0
			if first_wall.is_empty():
				first_wall = r.wall.duplicate()
			event.emit(e)
		"ask":
			if int(e.get("seat", -1)) != me:
				return
			waiting = true
			if e.get("kind", "") == "turn":
				snaps.append(_snap())
				if snaps.size() > 6:
					snaps.pop_front()
			asked.emit(e)
			if auto_human:
				answer(ai_answer(e))
		"discard":
			event.emit(e)
			if e.get("riichi", false):
				riichi_n += 1
				_say(int(e.seat), "riichi", {"riichi_n": riichi_n})
		"call":
			event.emit(e)
			var kind: String = String(e.get("type", "pon"))
			if kind in ["minkan", "ankan", "kakan"]:
				_kan_seat = int(e.seat)
			_say(int(e.seat), "call", {"kind": "kan" if kind.ends_with("kan") else kind})
			_check_dora()
		"riichi_stick":
			event.emit(e)
		"draw":
			event.emit(e)
			_check_dora()
		"win":
			hands_done += 1
			event.emit(e)
			var w: = int(e.seat)
			var evl: Dictionary = e.get("eval", {})
			var data: = {"yakuman": int(evl.get("yakuman", 0)) > 0, "limit": String(evl.get("limit", "")), "han": int(evl.get("han", 0))}
			if e.get("tsumo", false):
				_say(w, "tsumo", data)
			else:
				_say(w, "ron", data.merged({"from": int(e.from)}))
				_say(int(e.from), "dealin", {"seat": w})
			_maybe_one_hand_end()
		"draw_end":
			hands_done += 1
			event.emit(e)
			for s in 4:
				_say(s, "tenpai" if s in e.get("tenpai", []) else "noten", {})
			_maybe_one_hand_end()
		"match_end":
			over = true
			running = false
			final = e.get("result", {})
			event.emit(e)
			finished.emit(final)
		"noop", "idle":
			pass
		_:
			event.emit(e)

func _maybe_one_hand_end() -> void:
	if one_hand and not over:
		# one-hand format: the match ends after the first hand; the tally still shows first (hold → resume)
		r.state = "end"
		r.match_over = true

func _check_dora() -> void:
	if r.dora_ind.size() > _dora_n:
		_dora_n = r.dora_ind.size()
		_say(_kan_seat if _kan_seat >= 0 else r.turn, "dora", {})

func _on_engine_said(seat: int, what: String) -> void:
	engine_said = true
	_emit_said(seat, what, {})

func _say(seat: int, what: String, data: Dictionary) -> void:
	if engine_said:
		return
	_emit_said(seat, what, data)

func _emit_said(seat: int, what: String, data: Dictionary) -> void:
	var pub: = {}
	for k in data:
		if k in PUBLIC_KEYS:
			pub[k] = data[k]
	pub["seat"] = seat
	pub["last"] = r.is_last_hand()
	said_log.append([seat, what])
	said.emit(seat, what, pub)

# pause after an event, seconds (real time). AI thinking pause sits between her draw and her discard.
func delay_after(e: Dictionary) -> float:
	var ev: String = e.get("ev", "")
	match ev:
		"deal":
			return 1.0
		"draw":
			var s: = int(e.get("seat", 0))
			if s == me:
				return 0.0
			return ai_pause(s)
		"discard":
			return 0.12 if int(e.get("seat", 0)) == me else 0.18
		"call":
			return 0.55
		"riichi_stick":
			return 0.3
		"win", "draw_end":
			return 0.4
		"noop", "idle", "":
			return 0.0
	return 0.1

func ai_pause(s: int) -> float:
	var st: Dictionary = V8AI.STYLES.get(hero_of[s], V8AI.STYLES.mc)
	var sp: float = float(st.get("speed", 1.0))
	var t: float = PAUSE_MAX - clampf((sp - 0.85) / (1.2 - 0.85), 0.0, 1.0) * (PAUSE_MAX - PAUSE_MIN)
	t += rng.randf_range(-0.06, 0.06)
	return clampf(t * pace, PAUSE_MIN, PAUSE_MAX)

# ------------------------------------------------------------------ holds (dead time only)
func hold(reason: String) -> bool:
	if waiting:
		return false
	holds[reason] = true
	return true

func release(reason: String) -> void:
	holds.erase(reason)

func is_dead_time() -> bool:
	return not waiting

# ------------------------------------------------------------------ the player's answer
func current_ask() -> Dictionary:
	return r.ask if waiting else {}

func answer(a: Dictionary) -> bool:
	if not waiting or r.state != "ask":
		return false
	var ask: Dictionary = r.ask
	a = a.duplicate()
	a["seat"] = me
	waiting = false
	r.answer(a)
	answered.emit(a)
	timer = 0.05
	if not auto_human:
		return true
	return true

# AI choice for any ask (selftest bot, demo autoplay, «Пропустить» defaults)
func ai_answer(ask: Dictionary) -> Dictionary:
	var s: int = int(ask.get("seat", me))
	match String(ask.get("kind", "")):
		"turn":
			return V8AI.turn(r, s, ask.opts)
		"call":
			var a: Dictionary = V8AI.decide_call(r, s, ask.opts)
			a["seat"] = s
			return a
		"chankan":
			return {"a": "ron", "seat": s}
	return {"a": "pass", "seat": s}

# ------------------------------------------------------------------ undo (training hall)
func can_undo() -> bool:
	return waiting and undo_left > 0 and snaps.size() >= 2 and String(r.ask.get("kind", "")) == "turn"

func undo() -> bool:
	if not can_undo():
		return false
	snaps.pop_back()
	_restore(snaps.back())
	undo_left -= 1
	waiting = true
	rewound.emit()
	asked.emit(r.ask)
	return true

func _snap() -> Dictionary:
	var d: = {}
	for p in r.get_property_list():
		if not (p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var v = r.get(p.name)
		if v is Object:
			continue
		d[p.name] = v.duplicate(true) if (v is Array or v is Dictionary) else v
	d["__rng_seed"] = r.rng.seed
	d["__rng_state"] = r.rng.state
	d["__drv"] = {"riichi_n": riichi_n, "dora_n": _dora_n, "said": said_log.size()}
	return d

func _restore(d: Dictionary) -> void:
	for k in d:
		if k.begins_with("__"):
			continue
		var v = d[k]
		r.set(k, v.duplicate(true) if (v is Array or v is Dictionary) else v)
	r.rng.seed = d["__rng_seed"]
	r.rng.state = d["__rng_state"]
	riichi_n = d.__drv.riichi_n
	_dora_n = d.__drv.dora_n

# ------------------------------------------------------------------ «Честный стол»: the wall from the seed
static func wall_for_seed(seed: int, heroes: Array = ["player", "mc", "rin", "hana"]) -> Array:
	var d: = V10MjRiichiDriver.new()
	d.setup({"seed": seed, "heroes": heroes, "me": -1})
	var e: = d.r.advance()
	var w: Array = d.r.wall.duplicate()
	d.free()
	return w if e.get("ev", "") == "deal" else []

# run without timers (selftest / headless sims). Returns the number of steps; on_ask answers the player's asks.
func run_sync(max_steps: int = 30000) -> int:
	var n: = 0
	running = false
	while not over and n < max_steps:
		n += 1
		if waiting:
			if not auto_human:
				break
			answer(ai_answer(r.ask))
			continue
		step()
		if not holds.is_empty():
			break
	return n

func resume() -> void:
	holds.clear()
	timer = minf(timer, 0.1)
