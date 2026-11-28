class_name TWSfxPool
extends RefCounted

# TWSfxPool (P30 / WP10, GDD 8.1 / 8.5): the voice budget of the SFX + UI buses as pure logic (virtual slots, caller's clock).
# "<= 8 simultaneous SFX voices on a weak Mali": max_voices is the hard ceiling, acquire() never hands out more.
#
#   acquire(id, dur, prio, now, per_id_max = 99, gap = 0.0) -> int    a free slot index, or -1 when the sound is not played
#       a retrigger inside `gap` is merged (-1); an id at its own polyphony limit steals its oldest voice; a full pool steals the
#       lowest-priority voice, the oldest of those, but ONLY for a sound of equal or higher priority (a hover never kills a
#       finale), otherwise the new sound is dropped.
#   active(now) / active_of(id, now) / peak / stolen / dropped

var max_voices: int
var peak: = 0
var stolen: = 0
var dropped: = 0
var _id: Array = []
var _end: Array = []
var _start: Array = []
var _prio: Array = []
var _last_at: Dictionary = {}


func _init(p_max: int = 16) -> void:
	max_voices = maxi(p_max, 1)
	for i in max_voices:
		_id.append("")
		_end.append(-1.0)
		_start.append(-1.0)
		_prio.append(0)


func active(now: float) -> int:
	var n: = 0
	for i in max_voices:
		if now < float(_end[i]):
			n += 1
	return n


func active_of(id: String, now: float) -> int:
	var n: = 0
	for i in max_voices:
		if _id[i] == id and now < float(_end[i]):
			n += 1
	return n


func slot_id(i: int) -> String:
	return String(_id[i])


func acquire(id: String, dur: float, prio: int, now: float, per_id_max: int = 99, gap: float = 0.0) -> int:
	if now - float(_last_at.get(id, -1000.0)) < gap:
		dropped += 1
		return -1
	var slot: = -1
	if active_of(id, now) >= per_id_max:
		slot = _oldest(func(i: int) -> bool: return _id[i] == id and now < float(_end[i]))
		stolen += 1
	if slot < 0:
		for i in max_voices:
			if now >= float(_end[i]):
				slot = i
				break
	if slot < 0:
		var victim: = _lowest(now)
		if victim < 0 or int(_prio[victim]) > prio:
			dropped += 1
			return -1
		slot = victim
		stolen += 1
	_id[slot] = id
	_start[slot] = now
	_end[slot] = now + maxf(dur, 0.02)
	_prio[slot] = prio
	_last_at[id] = now
	peak = maxi(peak, active(now))
	return slot


func release(slot: int, now: float) -> void:
	if slot >= 0 and slot < max_voices:
		_end[slot] = now


func release_id(id: String, now: float) -> void:
	for i in max_voices:
		if _id[i] == id:
			_end[i] = minf(float(_end[i]), now)


func _oldest(pred: Callable) -> int:
	var best: = -1
	var t: = INF
	for i in max_voices:
		if pred.call(i) and float(_start[i]) < t:
			t = float(_start[i])
			best = i
	return best


func _lowest(now: float) -> int:
	var best: = -1
	for i in max_voices:
		if now >= float(_end[i]):
			continue
		if best < 0 or int(_prio[i]) < int(_prio[best]) or (int(_prio[i]) == int(_prio[best]) and float(_start[i]) < float(_start[best])):
			best = i
	return best
