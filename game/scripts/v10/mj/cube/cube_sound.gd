class_name V10MjCubeSound
extends Node

# Звук и вибрация Куба (docs/MODES.md §4.4 «Стол и звук»; UX_RULES §7.4). Всё синтезируется кодом в памяти:
#   rustle(speed)    вращение — мягкий шорох дерева: зёрна полосового шума с редкими «древесными» щелчками,
#                    громкость от угловой скорости, не чаще зерна в 0,11 с
#   toktok(step)     пара — «ток-ток»: два деревянных удара (моды дерева f, 2,76f, 5,4f + щелчок атаки) через 85 мс,
#                    реверберация Шрёдера (4 гребёнки + 2 всепропускающих, хвост ≈ 0,7 с); тон — ступень пентатоники
#                    по серии, «Мотив» — на октаву выше
#   pick()           касание фишки — лёгкий «тик»
#   deny()           не та фишка — глухое дерево (не «бззз», UX З-2)
#   relic(hero)      финал — арпеджио кото (Карплус — Стронг) её тональности + тихое мерцание
#   shuffle()        перемешать — длинный шорох
# Пики ≤ −6 dBFS (нормировка буфера к 0,5). Вибрация через автозагрузку V7Haptics (её тумблер уважается); в самотесте
# пишется в log_haptics.

const RATE: = 22050
const PENTA: = [0, 2, 4, 7, 9]
const ROOT: = {"mc": 0, "rin": 2, "hana": 4, "yue": 7, "nova": 9}
const PEAK: = 0.5

static var _cache: = {}
var _pool: Array[AudioStreamPlayer] = []
var _next: = 0
var _rustle_t: = 0.0
var log_haptics: Array = []
var log_sounds: Array = []
var mute: = false


func _ready() -> void:
	for i in 8:
		var p: = AudioStreamPlayer.new()
		p.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
		add_child(p)
		_pool.append(p)


static func penta_hz(root: int, step: int) -> float:
	var semis: int = root + PENTA[posmod(step, 5)] + 12 * (step / 5)
	return 293.66 * pow(2.0, semis / 12.0)   # D4 base: dry wood sounds warmer lower


# ── synthesis ────────────────────────────────────────────────────────────────

static func _wav(x: PackedFloat32Array) -> AudioStreamWAV:
	var peak: = 0.0001
	for v in x:
		peak = maxf(peak, absf(v))
	var k: = PEAK / peak
	var data: = PackedByteArray()
	data.resize(x.size() * 2)
	for i in x.size():
		data.encode_s16(i * 2, int(clampf(x[i] * k, -1.0, 1.0) * 32767.0))
	var w: = AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w


static func peak_of(w: AudioStreamWAV) -> float:
	var p: = 0
	var d: = w.data
	for i in range(0, d.size(), 2):
		p = maxi(p, absi(d.decode_s16(i)))
	return float(p) / 32767.0


# a wooden knock: three inharmonic modes with fast decay and a short noisy attack
static func _knock(buf: PackedFloat32Array, at: int, hz: float, amp: float, rng: RandomNumberGenerator) -> void:
	var n: = int(RATE * 0.18)
	for i in n:
		var j: = at + i
		if j >= buf.size():
			break
		var t: = float(i) / RATE
		var v: = sin(TAU * hz * t) * exp(-t * 38.0) + 0.45 * sin(TAU * hz * 2.76 * t) * exp(-t * 60.0) \
			+ 0.22 * sin(TAU * hz * 5.4 * t) * exp(-t * 95.0)
		if i < int(RATE * 0.004):
			v += rng.randf_range(-1.0, 1.0) * 0.6 * (1.0 - float(i) / (RATE * 0.004))
		buf[j] += v * amp


# Schroeder reverb: 4 parallel combs + 2 allpasses, mixed wet
static func _reverb(dry: PackedFloat32Array, wet: float, tail_s: float) -> PackedFloat32Array:
	var n: = dry.size() + int(RATE * tail_s)
	var x: = dry.duplicate()
	x.resize(n)
	var out: = PackedFloat32Array()
	out.resize(n)
	var combs: = [[1116, 0.80], [1188, 0.79], [1277, 0.78], [1356, 0.77]]
	var sum: = PackedFloat32Array()
	sum.resize(n)
	for c in combs:
		var d: int = int(c[0] * RATE / 44100.0)
		var g: float = c[1]
		var buf: = PackedFloat32Array()
		buf.resize(n)
		var lp: = 0.0
		for i in n:
			var y: = buf[i - d] if i >= d else 0.0
			lp = y * 0.6 + lp * 0.4
			buf[i] = x[i] + lp * g
			sum[i] += y
	for a in [[556, 0.5], [441, 0.5]]:
		var d: int = int(a[0] * RATE / 44100.0)
		var g: float = a[1]
		var ap: = PackedFloat32Array()
		ap.resize(n)
		for i in n:
			var xd: = sum[i - d] if i >= d else 0.0
			var yd: = ap[i - d] if i >= d else 0.0
			ap[i] = -g * sum[i] + xd + g * yd
		sum = ap
	for i in n:
		out[i] = x[i] + sum[i] * wet * 0.25
	return out


static func toktok_wav(step: int, motif: = false) -> AudioStreamWAV:
	var key: = "tt%d|%s" % [step, motif]
	if _cache.has(key):
		return _cache[key]
	var rng: = RandomNumberGenerator.new()
	rng.seed = 4101 + step
	var hz: = penta_hz(0, clampi(step, 0, 9)) * (2.0 if motif else 1.0)
	var buf: = PackedFloat32Array()
	buf.resize(int(RATE * 0.36))
	_knock(buf, 0, hz, 1.0, rng)
	_knock(buf, int(RATE * 0.085), hz * 1.122, 0.85, rng)
	var w: = _wav(_reverb(buf, 0.9, 0.7))
	_cache[key] = w
	return w


static func tick_wav() -> AudioStreamWAV:
	if _cache.has("tick"):
		return _cache.tick
	var rng: = RandomNumberGenerator.new()
	rng.seed = 77
	var buf: = PackedFloat32Array()
	buf.resize(int(RATE * 0.09))
	_knock(buf, 0, 1320.0, 0.6, rng)
	_cache.tick = _wav(buf)
	return _cache.tick


static func deny_wav() -> AudioStreamWAV:
	if _cache.has("deny"):
		return _cache.deny
	var rng: = RandomNumberGenerator.new()
	rng.seed = 78
	var buf: = PackedFloat32Array()
	buf.resize(int(RATE * 0.2))
	_knock(buf, 0, 190.0, 1.0, rng)
	_cache.deny = _wav(buf)
	return _cache.deny


# soft wooden rustle: band-passed noise grains with sparse fibre clicks, slow attack and release
static func rustle_wav(variant: int, dur: = 0.34) -> AudioStreamWAV:
	var key: = "ru%d|%.2f" % [variant, dur]
	if _cache.has(key):
		return _cache[key]
	var rng: = RandomNumberGenerator.new()
	rng.seed = 9000 + variant
	var n: = int(RATE * dur)
	var buf: = PackedFloat32Array()
	buf.resize(n)
	# biquad band-pass ≈ 2.6 kHz, Q 0.9
	var f0: = 2600.0 + variant * 180.0
	var q: = 0.9
	var w0: = TAU * f0 / RATE
	var alpha: = sin(w0) / (2.0 * q)
	var b0: = alpha
	var a0: = 1.0 + alpha
	var a1: = -2.0 * cos(w0)
	var a2: = 1.0 - alpha
	var x1: = 0.0
	var x2: = 0.0
	var y1: = 0.0
	var y2: = 0.0
	for i in n:
		var t: = float(i) / n
		var env: = minf(1.0, t / 0.25) * minf(1.0, (1.0 - t) / 0.45)
		var grain: = 0.55 + 0.45 * sin(TAU * (7.0 + variant) * t + rng.randf() * 0.3)
		var x: = rng.randf_range(-1.0, 1.0)
		if rng.randf() < 0.004:
			x *= 6.0
		var y: = (b0 * x - b0 * x2 - a1 * y1 - a2 * y2) / a0
		x2 = x1
		x1 = x
		y2 = y1
		y1 = y
		buf[i] = y * env * grain
	var w: = _wav(buf)
	_cache[key] = w
	return w


static func pluck_wav(hz: float, dur: = 1.2) -> AudioStreamWAV:
	var key: = "pl%.1f" % hz
	if _cache.has(key):
		return _cache[key]
	var n: = int(RATE * dur)
	var period: = maxi(2, int(RATE / hz))
	var rng: = RandomNumberGenerator.new()
	rng.seed = int(hz)
	var ring: = PackedFloat32Array()
	ring.resize(period)
	for i in period:
		ring[i] = rng.randf_range(-1.0, 1.0)
	var buf: = PackedFloat32Array()
	buf.resize(n)
	var idx: = 0
	for i in n:
		var a: = ring[idx]
		var b: = ring[(idx + 1) % period]
		var v: = (a + b) * 0.5 * 0.996
		ring[idx] = v
		idx = (idx + 1) % period
		var att: = minf(1.0, float(i) / (RATE * 0.003))
		buf[i] = a * att
	var w: = _wav(_reverb(buf, 0.6, 0.5))
	_cache[key] = w
	return w


# ── playback ─────────────────────────────────────────────────────────────────

func _play(s: AudioStream, db: float, delay: = 0.0, pitch: = 1.0) -> void:
	log_sounds.append(s)
	if mute or not _sound_on():
		return
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	var p: = _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = s
	p.volume_db = db
	p.pitch_scale = pitch
	p.play()


func _sound_on() -> bool:
	return not (G.S is Dictionary) or bool(G.S.get("sound", true))


func _haptic(kind: String, ms: Array) -> void:
	log_haptics.append([kind] + ms)
	var tree: = get_tree()
	var hp = tree.root.get_node_or_null("V7Haptics") if tree else null
	if hp == null:
		return
	if ms.size() == 1:
		hp.pulse(int(ms[0]), 0.4)
	else:
		hp.pattern([[int(ms[0]), 0.7, 70], [int(ms[1]), 0.7, 0]])


func pick() -> void:
	_play(tick_wav(), -16.0, 0.0, randf_range(0.97, 1.03))
	_haptic("tick", [12])


func toktok(series: int, motif: = false) -> void:
	_play(toktok_wav(clampi(series - 1, 0, 9), motif), -8.0)
	_haptic("double", [12, 12])


func deny() -> void:
	_play(deny_wav(), -12.0)
	_haptic("deny", [30])


# called every frame while the figure turns; speed in rad/s
func rustle(speed: float, dt: float) -> void:
	_rustle_t -= dt
	var sp: = absf(speed)
	if sp < 0.35 or _rustle_t > 0.0:
		return
	_rustle_t = 0.11
	var db: = lerpf(-30.0, -17.0, clampf(sp / 6.0, 0.0, 1.0))
	_play(rustle_wav(randi() % 4), db, 0.0, randf_range(0.92, 1.08))


func shuffle() -> void:
	_play(rustle_wav(5, 0.7), -14.0)
	_play(rustle_wav(6, 0.6), -16.0, 0.18)


func relic(hero: String) -> void:
	var root: int = ROOT.get(hero, 0)
	for k in 5:
		_play(pluck_wav(penta_hz(root, 5 + k)), -10.0 - k * 0.5, k * 0.11)
	_haptic("win", [20, 30])


func step_note(k: int) -> void:
	_play(pluck_wav(penta_hz(0, 4 + clampi(k, 0, 10))), -12.0)
