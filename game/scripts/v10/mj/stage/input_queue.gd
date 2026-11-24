class_name V10MjInputQueue
extends Node

# V10MjInputQueue — the only way the heroine may hold the player's input (docs/MODES.md §3.2: «wave … заблокирован
# ≤ 0,3 с, ранние тапы в очереди»). While blocked it catches every touch / click in _input (before any GUI or board
# sees it), keeps it, and when the block ends it replays them in order through the viewport, so an early tap is
# never lost — it lands 0–0.3 s late instead.
#
#   q.block(seconds)      block for min(seconds, MAX_BLOCK); a longer request is clamped, never extended past it
#   q.is_blocked() -> bool
#   q.release()           end the block now and replay the queue
# Stats for the selftest: max_block (longest block granted, s), queued, replayed.

const MAX_BLOCK: = 0.3

var _until: = 0.0
var _since: = 0.0
var _q: Array[InputEvent] = []
var _replaying: = false
var max_block: = 0.0
var queued: = 0
var replayed: = 0


func _init() -> void:
	name = "V10MjInputQueue"
	process_mode = Node.PROCESS_MODE_ALWAYS


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func block(seconds: float) -> void:
	if seconds <= 0.0:
		return
	var t: = _now()
	if not is_blocked():
		_since = t
	# never extend a block beyond MAX_BLOCK from its start
	_until = minf(maxf(_until, t + seconds), _since + MAX_BLOCK)
	max_block = maxf(max_block, _until - _since)
	set_process(true)


func is_blocked() -> bool:
	return _now() < _until


func release() -> void:
	_until = 0.0
	_flush()


func _ready() -> void:
	set_process(false)


func _process(_dt: float) -> void:
	if not is_blocked():
		set_process(false)
		_flush()


func _input(e: InputEvent) -> void:
	if _replaying or not is_blocked():
		return
	if e is InputEventScreenTouch or e is InputEventMouseButton:
		_q.append(e.duplicate())
		queued += 1
		get_viewport().set_input_as_handled()
	elif e is InputEventScreenDrag or e is InputEventMouseMotion:
		get_viewport().set_input_as_handled()


func _flush() -> void:
	if _q.is_empty() or not is_inside_tree():
		return
	var evs: = _q.duplicate()
	_q.clear()
	_replaying = true
	for e in evs:
		get_viewport().push_input(e)
		replayed += 1
	_replaying = false
