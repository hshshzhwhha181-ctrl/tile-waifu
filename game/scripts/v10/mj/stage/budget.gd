class_name V10MjBudget
extends RefCounted

# V10MjBudget — the heroine's attention budget during a match (docs/MODES.md §3.3). Pure bookkeeping, no nodes:
# the presence asks before every reaction, so the rules live in one place and the selftest can drive it with a
# synthetic clock (1000 events in a few ms).
#
#   b.now()                      seconds (Time ticks, or the injected `clock` Callable)
#   b.note_move(n = 1)           a player move (a tap; a pair without taps counts 2)
#   b.take_micro() -> bool       a micro-reaction (smile, nod, wink, look-up): ≤ 1 per MICRO_EVERY moves
#   b.take_voice(line_id, finish = false) -> bool    a voiced line: ≤ 1 per VOICE_GAP s (win/lose bypass the
#                                gap — they end the match), the same line ≤ 1 per LINE_GAP s, always
#   b.line_free(line_id) -> bool the same-line rule alone (to pick a variant that may play)
#   b.block_for(event) -> float  input block for an event: ≤ BLOCK_MAX s, only BLOCK_EVENTS, 0 otherwise
#   b.take_peek(event) -> bool   a waist-up exit: only PEEK_EVENTS, ≤ 1 per PEEK_GAP s (win/lose always)
#   b.take_idle() -> bool        an idle call: ≤ IDLE_MAX per visit (UX §8.4: «зовёт … не больше 2 раз за визит»)
# Every refusal and grant is counted in `stats` (the selftest reads it).

const MICRO_EVERY: = 3
const VOICE_GAP: = 20.0
const LINE_GAP: = 60.0
const BLOCK_MAX: = 0.3
const BLOCK_EVENTS: = ["wave", "win", "lose"]
const PEEK_EVENTS: = ["wave", "win", "lose"]
const FINISH_EVENTS: = ["win", "lose"]
const PEEK_GAP: = 8.0
const IDLE_MAX: = 2

var clock: Callable = Callable()
var moves: = 0
var _micro_at: = -1000
var _voice_at: = -1000.0
var _line_at: = {}
var _peek_at: = -1000.0
var idle_calls: = 0
var stats: = {"micro": 0, "micro_denied": 0, "voice": 0, "voice_denied": 0, "peek": 0, "peek_denied": 0, "idle": 0}
# a log of every voice grant [time, line_id, finish] and micro grant [move] for the selftest's frequency audit
var voice_log: Array = []
var micro_log: Array = []


func now() -> float:
	if clock.is_valid():
		return float(clock.call())
	return Time.get_ticks_msec() / 1000.0


func note_move(n: = 1) -> void:
	moves += maxi(1, n)


func take_micro() -> bool:
	if moves - _micro_at < MICRO_EVERY:
		stats.micro_denied += 1
		return false
	_micro_at = moves
	stats.micro += 1
	micro_log.append(moves)
	return true


func line_free(line_id: String) -> bool:
	return now() - float(_line_at.get(line_id, -1000.0)) >= LINE_GAP


func voice_free(finish: = false) -> bool:
	return finish or now() - _voice_at >= VOICE_GAP


func take_voice(line_id: String, finish: = false) -> bool:
	if not voice_free(finish) or not line_free(line_id):
		stats.voice_denied += 1
		return false
	var t: = now()
	_voice_at = t
	_line_at[line_id] = t
	stats.voice += 1
	voice_log.append([t, line_id, finish])
	return true


func block_for(event: String) -> float:
	return BLOCK_MAX if event in BLOCK_EVENTS else 0.0


func take_peek(event: String) -> bool:
	if not event in PEEK_EVENTS:
		stats.peek_denied += 1
		return false
	var t: = now()
	if not event in FINISH_EVENTS and t - _peek_at < PEEK_GAP:
		stats.peek_denied += 1
		return false
	_peek_at = t
	stats.peek += 1
	return true


func take_idle() -> bool:
	if idle_calls >= IDLE_MAX:
		return false
	idle_calls += 1
	stats.idle += 1
	return true
