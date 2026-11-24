class_name V10MjTriplesSound
extends Node

# Звук и вибрация Троек (docs/MODES.md §4.2 «Стол и звук»; UX_RULES §7.4). Всё синтезируется в памяти (без файлов):
#   place(face)        — укладка в лоток: короткий деревянный «тук» по масти + вибрация tick 15 мс
#   triple(face, n)    — тройка: аккорд из трёх нот мажорной пентатоники «щипком» пипы, тон зависит от масти,
#                        серия поднимает аккорд на ступень (до 7); на ×5 вступает гонг; вибрация double 2×12 мс
#   heartbeat()        — сердцебиение опасности 6/7 (presence.danger), мягкий низкий удар «тук-тук»
#   bless(k)           — «Благословение стола»: нота пентатоники на k-й ступени (растущий тон)
#   deny()             — «дерево», а не «бззз» (UX З-2)
# Масти = категории лиц G.CATS: цветы · небо · сладости · сокровища · звери → тоники C · D · E · G · A.
# Громкость: SFX пиком ≤ −6 dBFS; аккорд −9 дБ, тук −14 дБ. Вибрация идёт через автозагрузку V7Haptics (её
# настройки «вкл/сила» уважаются), если её нет (самотест) — тихо.

const RATE: = 22050
const PENTA: = [0, 2, 4, 7, 9]
const SUIT_ROOT: = [0, 2, 4, 7, 9]   # полутоны от C4 для пяти мастей
const C4: = 261.63

static var _cache: = {}
var _pool: Array[AudioStreamPlayer] = []
var _next: = 0
var log_haptics: Array = []          # самотест: [[kind, ms...]]
var mute: = false


func _ready() -> void:
	for i in 10:
		var p: = AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_pool.append(p)


static func suit_of(face: int) -> int:
	var c: = G.face_cat(face) if face >= 0 and face < 36 else 0
	return maxi(0, c)


# частота k-й ступени пентатоники от тоники масти (k может быть > 4 — следующая октава)
static func penta_hz(suit: int, step: int) -> float:
	var oct: = step / 5
	var semis: int = SUIT_ROOT[clampi(suit, 0, 4)] + PENTA[step % 5] + 12 * oct
	return C4 * pow(2.0, semis / 12.0)


# три ноты аккорда тройки: ступени (s, s+2, s+4) пентатоники, s = серия − 1 (до 7)
static func chord_steps(combo: int) -> Array:
	var s: = clampi(combo - 1, 0, 7)
	return [s, s + 2, s + 4]


# ── синтез ───────────────────────────────────────────────────────────────────

static func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data: = PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		var v: = int(clampf(samples[i], -1.0, 1.0) * 32000.0)
		data.encode_s16(i * 2, v)
	var w: = AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w


# щипок (Карплус — Стронг) с мягкой атакой: пипа/кото
static func pluck(hz: float, dur: = 0.9, bright: = 0.5) -> AudioStreamWAV:
	var key: = "p%.2f|%.2f|%.2f" % [hz, dur, bright]
	if _cache.has(key):
		return _cache[key]
	var n: = int(RATE * dur)
	var period: = maxi(2, int(RATE / hz))
	var buf: = PackedFloat32Array()
	buf.resize(period)
	var rng: = RandomNumberGenerator.new()
	rng.seed = int(hz * 100.0)
	for i in period:
		buf[i] = rng.randf_range(-1.0, 1.0)
	# смягчить начальный шум (менее «металлический»)
	for k in 2:
		for i in period:
			buf[i] = (buf[i] + buf[(i + 1) % period]) * 0.5
	var out: = PackedFloat32Array()
	out.resize(n)
	var idx: = 0
	var decay: = 0.4985 + 0.0013 * bright
	var peak: = 0.0001
	for i in n:
		var a: = buf[idx]
		var b: = buf[(idx + 1) % period]
		var v: = (a + b) * decay
		buf[idx] = v
		idx = (idx + 1) % period
		var env: = minf(1.0, i / (RATE * 0.004))
		out[i] = a * env
		peak = maxf(peak, absf(out[i]))
	# мягкий хвост и нормировка к −6 dBFS
	var g: = 0.5 / peak
	for i in n:
		var t: = float(i) / n
		out[i] *= g * (1.0 - t * t)
	var w: = _wav(out)
	_cache[key] = w
	return w


# деревянный «тук»: короткий шумовой импульс через резонанс (фишка ложится в лоток)
static func knock(hz: float) -> AudioStreamWAV:
	var key: = "k%.1f" % hz
	if _cache.has(key):
		return _cache[key]
	var n: = int(RATE * 0.07)
	var out: = PackedFloat32Array()
	out.resize(n)
	var rng: = RandomNumberGenerator.new()
	rng.seed = int(hz)
	var y1: = 0.0
	var y2: = 0.0
	var w0: = TAU * hz / RATE
	var r: = 0.985
	var a1: = 2.0 * r * cos(w0)
	var a2: = -r * r
	var peak: = 0.0001
	for i in n:
		var x: = rng.randf_range(-1.0, 1.0) * exp(-i / (RATE * 0.0025))
		var y: = x + a1 * y1 + a2 * y2
		y2 = y1
		y1 = y
		out[i] = y * exp(-i / (RATE * 0.018))
		peak = maxf(peak, absf(out[i]))
	for i in n:
		out[i] *= 0.5 / peak
	var w: = _wav(out)
	_cache[key] = w
	return w


# гонг: неровные обертоны с медленным затуханием
static func gong() -> AudioStreamWAV:
	if _cache.has("gong"):
		return _cache["gong"]
	var n: = int(RATE * 2.2)
	var out: = PackedFloat32Array()
	out.resize(n)
	var parts: = [[110.0, 1.0, 1.6], [176.0, 0.6, 1.2], [233.0, 0.45, 0.9], [311.0, 0.3, 0.7], [402.0, 0.22, 0.5]]
	var peak: = 0.0001
	for i in n:
		var t: = float(i) / RATE
		var v: = 0.0
		for p in parts:
			v += sin(TAU * p[0] * t * (1.0 + 0.002 * sin(t * 5.0))) * p[1] * exp(-t / p[2])
		v *= minf(1.0, t / 0.01)
		out[i] = v
		peak = maxf(peak, absf(v))
	for i in n:
		out[i] *= 0.45 / peak
	var w: = _wav(out)
	_cache["gong"] = w
	return w


# сердце: два мягких низких удара
static func heart() -> AudioStreamWAV:
	if _cache.has("heart"):
		return _cache["heart"]
	var n: = int(RATE * 0.5)
	var out: = PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t: = float(i) / RATE
		var v: = 0.0
		for st in [0.0, 0.2]:
			var u: float = t - st
			if u >= 0.0:
				v += sin(TAU * (52.0 + 30.0 * exp(-u * 30.0)) * u) * exp(-u * 16.0) * (1.0 if st == 0.0 else 0.7)
		out[i] = v * 0.45
	var w: = _wav(out)
	_cache["heart"] = w
	return w


# ── воспроизведение ─────────────────────────────────────────────────────────

func _play(s: AudioStream, db: float, delay: = 0.0, pitch: = 1.0) -> void:
	if mute or s == null or _pool.is_empty():
		return
	if delay > 0.0:
		get_tree().create_timer(delay).timeout.connect(func(): _play(s, db, 0.0, pitch))
		return
	var p: = _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = s
	p.volume_db = db
	p.pitch_scale = pitch
	p.play()


func _haptic(kind: String, pattern: Array) -> void:
	log_haptics.append([kind] + pattern)
	var tree: = get_tree()
	var hp = tree.root.get_node_or_null("V7Haptics") if tree else null
	if hp == null:
		return
	if pattern.size() == 1:
		hp.pulse(int(pattern[0]), 0.45)
	else:
		hp.pattern([[12, 0.8, 40], [12, 0.8, 0]])


func place(face: int) -> void:
	var suit: = suit_of(face)
	_play(knock(380.0 + suit * 40.0), -14.0, 0.0, randf_range(0.97, 1.03))
	_haptic("tick", [15])


func triple(face: int, combo: int) -> void:
	var suit: = suit_of(face)
	var st: = chord_steps(combo)
	for k in 3:
		_play(pluck(penta_hz(suit, int(st[k])), 1.1, 0.6), -9.0 - k * 1.5, k * 0.035)
	if combo >= 5 and (combo == 5 or combo % 5 == 0):
		_play(gong(), -10.0, 0.06)
	_haptic("double", [12, 12])


func heartbeat() -> void:
	_play(heart(), -12.0)


func bless(k: int) -> void:
	_play(pluck(penta_hz(0, clampi(k, 0, 14)), 0.7, 0.8), -10.0)


func deny() -> void:
	_play(knock(180.0), -10.0)
	var tree: = get_tree()
	var hp = tree.root.get_node_or_null("V7Haptics") if tree else null
	if hp:
		hp.kind("deny")


func win_chord() -> void:
	for k in 4:
		_play(pluck(penta_hz(0, 5 + k * 2), 1.6, 0.7), -8.0 - k, k * 0.09)
