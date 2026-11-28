class_name TWDuck
extends RefCounted

# TWDuck (P30 / WP10, GDD V11 8.5): the ducking envelope of one bus. Pure maths, stepped by the caller with dt, so the envelope
# is identical in the game, in a selftest and in the rendered WAV that proves it (render_wav).
#
#   set_source(name, depth_db, hold_s = -1, attack_s = 0.08, release_s = 0.4)   a named reason to lower the bus
#       hold_s < 0 holds until clear_source(name); hold_s >= 0 expires by itself (repeated calls extend / deepen, never stack)
#   clear_source(name)
#   step(dt) -> float              advance the envelope, returns the current attenuation in dB (<= 0)
#   target_db() / cur_db / active()
#
# The bus is lowered to the DEEPEST of the active sources (two sources at -8 and -6 give -8, not -14). Down slope is
# |depth| / attack_s of the source that sets the target (-8 dB lands in 80 ms), up slope |cur| / release_s of the source that
# was released last (an 8 dB duck lifts in 400 ms): linear in dB, constant slope, which is what the old Sfx.duck did.

const ATTACK_S: = 0.08
const RELEASE_S: = 0.4
const VOICE_MUSIC_DB: = -8.0     # GDD 8.5: heroine voice -> music
const VOICE_SFX_DB: = -3.0       # GDD 8.5: heroine voice -> SFX
const COMBO_T3_MUSIC_DB: = -6.0  # GDD 8.5 / HUD 7.3
const ULT_MUSIC_DB: = -8.0
const SUMMON_DB: = -60.0         # summon reveal: music out in 150 ms, back in 0.6 s
const SUMMON_ATTACK_S: = 0.15
const SUMMON_RELEASE_S: = 0.6

var cur_db: = 0.0
var _src: Dictionary = {}       # name -> {depth, left (-1 = held), attack, release}
var _up_slope: = 8.0 / RELEASE_S


func set_source(name: String, depth_db: float, hold_s: float = -1.0, attack_s: float = ATTACK_S, release_s: float = RELEASE_S) -> void:
	depth_db = minf(depth_db, 0.0)
	if _src.has(name):
		var s: Dictionary = _src[name]
		s["depth"] = minf(float(s["depth"]), depth_db)
		if hold_s < 0.0 or float(s["left"]) < 0.0:
			s["left"] = -1.0
		else:
			s["left"] = maxf(float(s["left"]), hold_s)
		s["attack"] = attack_s
		s["release"] = release_s
	else:
		_src[name] = {"depth": depth_db, "left": hold_s, "attack": attack_s, "release": release_s}


func clear_source(name: String) -> void:
	if _src.has(name):
		_released(_src[name])
		_src.erase(name)


func has_source(name: String) -> bool:
	return _src.has(name)


func active() -> bool:
	return not _src.is_empty() or cur_db < -0.0001


func _released(s: Dictionary) -> void:
	_up_slope = absf(float(s["depth"])) / maxf(float(s["release"]), 0.001)


func _defining() -> Dictionary:
	var best: Dictionary = {}
	for n in _src:
		if best.is_empty() or float(_src[n]["depth"]) < float(best["depth"]):
			best = _src[n]
	return best


func target_db() -> float:
	var d: = _defining()
	return 0.0 if d.is_empty() else float(d["depth"])


func step(dt: float) -> float:
	for n in _src.keys():
		var s: Dictionary = _src[n]
		if float(s["left"]) >= 0.0:
			s["left"] = float(s["left"]) - dt
			if float(s["left"]) < 0.0:
				_released(s)
				_src.erase(n)
	var d: = _defining()
	var target: = 0.0 if d.is_empty() else float(d["depth"])
	if target < cur_db:
		var slope: = absf(target) / maxf(float(d["attack"]), 0.001)
		cur_db = maxf(cur_db - slope * dt, target)
	elif target > cur_db:
		cur_db = minf(cur_db + _up_slope * dt, target)
	return cur_db


# ── proof: render the envelope applied to a test "music" signal into a WAV and measure it from the samples ─────────────────
# The engine applies the duck by writing the bus volume once per frame, so the render does the same: the envelope is stepped at
# `fps` and the gain is held between frames (zero-order hold). Signal: 440 Hz sine at -20 dBFS, 16-bit mono.
# schedule: [[t_on, t_off], ...] voice windows of source "voice". Returns {"path", "rate", "secs"}.
static func render_wav(path: String, schedule: Array, secs: float, depth_db: float = VOICE_MUSIC_DB, fps: float = 60.0, rate: int = 48000) -> Dictionary:
	var duck: = TWDuck.new()
	var n: = int(secs * rate)
	var buf: = PackedByteArray()
	buf.resize(n * 2)
	var dt: = 1.0 / fps
	var next_frame: = 0.0
	var gain: = 1.0
	var amp: = pow(10.0, -20.0 / 20.0)
	var on: = false
	for i in n:
		var t: = float(i) / rate
		if t >= next_frame:
			next_frame += dt
			var want: = false
			for w in schedule:
				if t >= float(w[0]) and t < float(w[1]):
					want = true
			if want and not on:
				duck.set_source("voice", depth_db)
			elif not want and on:
				duck.clear_source("voice")
			on = want
			gain = pow(10.0, duck.step(dt) / 20.0)
		var v: = int(roundf(sin(TAU * 440.0 * t) * amp * gain * 32767.0))
		buf.encode_s16(i * 2, v)
	var f: = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return {}
	f.store_buffer("RIFF".to_ascii_buffer())
	f.store_32(36 + buf.size())
	f.store_buffer("WAVEfmt ".to_ascii_buffer())
	f.store_32(16)
	f.store_16(1)
	f.store_16(1)
	f.store_32(rate)
	f.store_32(rate * 2)
	f.store_16(2)
	f.store_16(16)
	f.store_buffer("data".to_ascii_buffer())
	f.store_32(buf.size())
	f.store_buffer(buf)
	f.close()
	return {"path": path, "rate": rate, "secs": secs}


# read a 16-bit mono WAV back (what a player of the file would hear) and measure the one duck window [t_on, t_off]:
#   {"depth_db": plateau level, "attack_ms": time to 95% of the depth, "release_ms": time back to within 5% of 0 dB, "base_db": level before}
# levels are RMS over 5 ms windows relative to the level before t_on (or to base_override when the file has an earlier duck).
static func measure_wav(path: String, t_on: float, t_off: float, base_override: float = NAN) -> Dictionary:
	var f: = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var raw: = f.get_buffer(f.get_length())
	f.close()
	var rate: = int(raw.decode_u32(24))
	var off: = 44
	var n: = (raw.size() - off) / 2
	var win: = int(rate * 0.005)
	var nw: = n / win
	var lv: = PackedFloat32Array()
	lv.resize(nw)
	for w in nw:
		var s: = 0.0
		for j in win:
			var x: = float(raw.decode_s16(off + (w * win + j) * 2)) / 32768.0
			s += x * x
		lv[w] = 10.0 * log(maxf(s / win, 1e-12)) / log(10.0)
	var wsec: = float(win) / rate
	var base: = 0.0
	var bc: = 0
	for w in nw:
		if (w + 1) * wsec <= t_on - 0.02:
			base += lv[w]
			bc += 1
	base /= maxf(bc, 1)
	if not is_nan(base_override):
		base = base_override
	var plateau: = 0.0
	var pc: = 0
	for w in nw:
		var tw: = float(w) * wsec
		if tw >= t_on + 0.2 and (w + 1) * wsec <= t_off - 0.02:
			plateau += lv[w]
			pc += 1
	plateau = plateau / maxf(pc, 1) - base
	var attack: = -1.0
	for w in nw:
		var tw: = float(w) * wsec
		if tw >= t_on - 0.01 and lv[w] - base <= plateau * 0.95:
			attack = (tw + wsec * 0.5 - t_on) * 1000.0
			break
	var release: = -1.0
	for w in nw:
		var tw: = float(w) * wsec
		if tw >= t_off and lv[w] - base >= plateau * 0.05:
			release = (tw + wsec * 0.5 - t_off) * 1000.0
			break
	return {"depth_db": plateau, "attack_ms": attack, "release_ms": release, "base_db": base}
