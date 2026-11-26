class_name V10MjGardenSound
extends Node

# Звук Сада 2.0 (docs/MODES.md §4.9 «Стол и звук», §6.5 «Сад: дождь, колокольчики, без ритма»; UX_RULES §7.4).
# Дерево фишек и амбиент — из ASMR-банка дорожки look (V10MjAsmr: клак по материалу, укладка, гонг, петли
# дождь / ручей / бамбук). Колокольчики, пэд, перелив и чаша рекорда синтезируются здесь в памяти (без файлов).
#
#   start(night, ambient)  день: музыка Сада (пэд без ритма + редкие колокольчики, шина Music) и выбранный амбиент;
#                          ночь («Ночной стол»): музыки нет, только дерево, дождь и колокольчики ветра (шина SFX)
#   set_night(on) · set_ambient(name) · stop()
#   pick() · place(material) · pair(series, material) · overflow() · wave() · record() · deny()
# Пара: клак выше на полтона за каждую пару серии (V10MjAsmr.combo_pitch), колокольчик идёт по лестнице
# пентатоники (ре мажор, две октавы); множитель дошёл до ×5 — гонг. Перелив — «вода» (шум с уходящим вниз
# резонансом и пузырьки) и три тихих клака. Всё молчит при выключенном звуке игры (G.S.sound), музыка —
# при выключенной музыке (G.S.music). Пики синтеза нормированы к −6 dBFS и ниже.

const RATE: = 22050
const PENTA: = [0, 2, 4, 7, 9]
const D4: = 293.66
const PAD_LEN: = 12.0
const PAD_DB: = -15.0
const BELL_DB: = -17.0
const CHIME_DB: = -21.0
const BELL_BASE: = 587.33          # ре 5-й октавы: высота запечённого колокольчика
const PAD_RATE: = 11025
const DIR: = "res://assets/v10/mj/garden/sfx/"
const BAKED: = ["bell", "bowl", "spill", "pad"]

static var _cache: = {}

var night: = false
var ambient: = "rain"
var music_on: = false          # играет ли музыка Сада сейчас (день и музыка включена)
var ambient_now: = ""          # какой амбиент сейчас звучит
var chimes: = ""               # "music" (день: колокольчики в музыке) | "wind" (ночь: колокольчики ветра)
var mute: = false              # самотест / демо без звука
var log: Array = []            # [ключ, …] — что прозвучало (самотест)

var _pool: Array[AudioStreamPlayer] = []
var _next: = 0
var _pad: AudioStreamPlayer
var _chime_t: = 0.0
var _rng: = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	var sfx_bus: = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	for i in 10:
		var p: = AudioStreamPlayer.new()
		p.bus = sfx_bus
		add_child(p)
		_pool.append(p)
	_pad = AudioStreamPlayer.new()
	_pad.bus = "Music" if AudioServer.get_bus_index("Music") >= 0 else "Master"
	add_child(_pad)


static func _g():
	var tree: = Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("G") if tree and tree.root else null


static func sound_on() -> bool:
	var g = _g()
	return g == null or not (g.S is Dictionary) or bool(g.S.get("sound", true))


static func music_allowed() -> bool:
	var g = _g()
	return sound_on() and (g == null or not (g.S is Dictionary) or bool(g.S.get("music", true)))


# ── режим ────────────────────────────────────────────────────────────────────

func start(is_night: bool, amb: String) -> void:
	night = is_night
	ambient = amb if amb in V10MjGardenSave.AMBIENTS else "rain"
	# чужие петли режимов и музыка вкладки — стоп (интегратор вернёт трек вкладки на выходе)
	V10MjMusic.play("", 0.6)
	var sfx = get_tree().root.get_node_or_null("Sfx") if is_inside_tree() else null
	if sfx and sfx.has_method("music"):
		sfx.music("", 0.6)
	_apply()


func set_night(on: bool) -> void:
	night = on
	_apply()


func set_ambient(name: String) -> void:
	if name in V10MjGardenSave.AMBIENTS:
		ambient = name
	_apply()


func _apply() -> void:
	music_on = not night and music_allowed() and not mute
	chimes = "wind" if night else "music"
	# ночью — всегда дождь (MODES §4.9: только дерево, дождь и колокольчики)
	ambient_now = ("rain" if night else ambient) if sound_on() else ""
	if not mute:
		V10MjAsmr.ambient(ambient_now, 1.6)
	if music_on:
		if not _pad.playing:
			_pad.stream = asset("pad")
			_pad.volume_db = -50.0
			_pad.play()
		if is_inside_tree():
			create_tween().tween_property(_pad, "volume_db", PAD_DB, 2.0)
	elif _pad.playing:
		if is_inside_tree():
			var t: = create_tween()
			t.tween_property(_pad, "volume_db", -50.0, 1.2)
			t.tween_callback(_pad.stop)
		else:
			_pad.stop()
	_chime_t = _rng.randf_range(2.0, 4.0)
	log.append("mode:%s" % ("night" if night else "day"))


func stop() -> void:
	music_on = false
	if _pad:
		_pad.stop()
	if not mute:
		V10MjAsmr.ambient("", 1.0)
	ambient_now = ""


func _process(dt: float) -> void:
	if mute or not sound_on():
		return
	_chime_t -= dt
	if _chime_t > 0.0:
		return
	if night:
		# колокольчики ветра: 3–5 высоких нот вразброс, раз в 8–16 с
		var n: = _rng.randi_range(3, 5)
		for k in n:
			var step: = _rng.randi_range(8, 14)
			_bell(penta_hz(step), CHIME_DB - _rng.randf_range(0, 4), k * _rng.randf_range(0.06, 0.17))
		_chime_t = _rng.randf_range(8.0, 16.0)
		log.append("chime:wind")
	elif music_on:
		# музыка дня: редкая нота колокольчика без ритма, иногда две
		var step2: = _rng.randi_range(5, 12)
		_bell(penta_hz(step2), BELL_DB - 2.0)
		if _rng.randf() < 0.35:
			_bell(penta_hz(step2 + (2 if _rng.randf() < 0.5 else -1)), BELL_DB - 4.0, _rng.randf_range(0.4, 0.9))
		_chime_t = _rng.randf_range(2.6, 7.0)
		log.append("chime:music")


# ── события стола ────────────────────────────────────────────────────────────

func pick() -> void:
	log.append("pick")
	if not mute:
		V10MjAsmr.pick()
	V10MjHaptics.play("tap")


func place(material: String) -> void:
	log.append("place")
	if not mute:
		V10MjAsmr.place(material)
	V10MjHaptics.play("tick")


# ступень лестницы пентатоники для пары номер series (1 — первая): две октавы, потом по кругу
static func ladder_step(series: int) -> int:
	return (maxi(series, 1) - 1) % 10


static func ladder_hz(series: int) -> float:
	return penta_hz(ladder_step(series))


# гонг звучит, когда множитель серии дошёл до ×5 (один раз на серию)
static func gong_at(series: int) -> bool:
	return V10MjGardenRules.mult_for(series) == V10MjGardenRules.MULT_MAX and V10MjGardenRules.mult_for(series - 1) < V10MjGardenRules.MULT_MAX


func pair(series: int, material: String) -> void:
	log.append("pair:%d" % series)
	if not mute and sound_on():
		var a: = V10MjAsmr.inst()
		if a:
			a.play_key("pair_" + V10MjAsmr._mat(material), V10MjAsmr.combo_pitch(series))
		_bell(ladder_hz(series), BELL_DB + 3.0, 0.05)
	if gong_at(series):
		log.append("gong")
		if not mute and sound_on():
			var a2: = V10MjAsmr.inst()
			if a2:
				a2.play_key("gong", 1.0, -2.0)
	V10MjHaptics.combo(series)


func overflow() -> void:
	log.append("overflow")
	if not mute and sound_on():
		_play(asset("spill"), -9.0)
		var a: = V10MjAsmr.inst()
		if a:
			for k in 3:
				get_tree().create_timer(0.22 + k * 0.09).timeout.connect(func(): a.play_key("clack_bone", 0.9 + k * 0.04, -8.0))
	V10MjHaptics.play("double")


func wave() -> void:
	log.append("wave")
	if not mute and sound_on():
		for k in 4:
			_bell(penta_hz(13 - k * 2), BELL_DB - k, k * 0.11)
		var a: = V10MjAsmr.inst()
		if a:
			a.play_key("felt", 1.0, -6.0)


func record() -> void:
	log.append("record")
	if not mute and sound_on():
		_play(asset("bowl"), -7.0)


func deny() -> void:
	log.append("deny")
	if not mute and sound_on():
		_play(knock(170.0), -10.0)


func _play(s: AudioStream, db: float, delay: = 0.0, pitch: = 1.0) -> void:
	if mute or s == null or _pool.is_empty() or not sound_on():
		return
	if delay > 0.0:
		if is_inside_tree():
			get_tree().create_timer(delay).timeout.connect(func(): _play(s, db, 0.0, pitch))
		return
	var p: = _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = s
	p.volume_db = db
	p.pitch_scale = clampf(pitch, 0.25, 4.0)
	p.play()


# колокольчик нужной высоты: один запечённый звук (ре 5-й октавы), высота — pitch_scale (как у сэмплера)
func _bell(hz: float, db: float, delay: = 0.0) -> void:
	_play(asset("bell"), db, delay, hz / BELL_BASE)


# ── синтез и запечённые звуки ────────────────────────────────────────────────

# запечённый звук (assets/v10/mj/garden/sfx/<имя>.wav, `--garden_bake_audio=1`), если файла нет — синтез на лету
static func asset(name: String) -> AudioStream:
	var key: = "asset:" + name
	if _cache.has(key):
		return _cache[key]
	var p: = DIR + name + ".wav"
	var st: AudioStream = null
	if ResourceLoader.exists(p):
		st = load(p)
	if st == null:
		match name:
			"bell":
				st = bell(BELL_BASE, 2.6)
			"bowl":
				st = bowl(D4 * 0.5)
			"spill":
				st = spill()
			"pad":
				st = pad_loop()
	if name == "pad" and st is AudioStreamWAV:
		var w: = (st as AudioStreamWAV).duplicate() as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = int(round(w.get_length() * w.mix_rate))
		st = w
	_cache[key] = st
	return st


# запечь синтез в WAV (16 бит, моно) — делается один раз инструментом, в игре только загрузка
static func bake(dir_abs: String) -> Dictionary:
	DirAccess.make_dir_recursive_absolute(dir_abs)
	var out: = {}
	var gen: = {"bell": bell(BELL_BASE, 2.6), "bowl": bowl(D4 * 0.5), "spill": spill(), "pad": pad_loop()}
	for k in gen:
		var w: AudioStreamWAV = gen[k]
		var path: = dir_abs.path_join(k + ".wav")
		var err: = w.save_to_wav(path)
		out[k] = {"err": err, "bytes": w.data.size(), "rate": w.mix_rate, "sec": float(w.data.size() / 2) / w.mix_rate}
	return out


static func penta_hz(step: int) -> float:
	var oct: = step / 5
	return D4 * pow(2.0, (PENTA[step % 5] + 12 * oct) / 12.0)


static func _wav(samples: PackedFloat32Array, loop: = false, rate: = RATE) -> AudioStreamWAV:
	var data: = PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w: = AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w


static func _norm(out: PackedFloat32Array, peak_to: float) -> void:
	var peak: = 0.0001
	for v in out:
		peak = maxf(peak, absf(v))
	var g: = peak_to / peak
	for i in out.size():
		out[i] *= g


# колокольчик: неровные обертоны (1 · 2 · 2,76 · 4,07 · 5,4), мягкая атака 3 мс
static func bell(hz: float, dur: = 2.4) -> AudioStreamWAV:
	var key: = "b%.2f|%.1f" % [hz, dur]
	if _cache.has(key):
		return _cache[key]
	var n: = int(RATE * dur)
	var out: = PackedFloat32Array()
	out.resize(n)
	var parts: = [[1.0, 1.0, 1.0], [2.0, 0.42, 0.55], [2.76, 0.3, 0.4], [4.07, 0.16, 0.26], [5.4, 0.09, 0.16]]
	for i in n:
		var t: = float(i) / RATE
		var v: = 0.0
		for p in parts:
			v += sin(TAU * hz * p[0] * t) * p[1] * exp(-t / (dur * 0.28 * p[2]))
		out[i] = v * minf(1.0, t / 0.003)
	_norm(out, 0.5)
	var w: = _wav(out)
	_cache[key] = w
	return w


# поющая чаша рекорда: низкий тон с биением и долгим хвостом
static func bowl(hz: float) -> AudioStreamWAV:
	var key: = "bowl%.1f" % hz
	if _cache.has(key):
		return _cache[key]
	var dur: = 3.2
	var n: = int(RATE * dur)
	var out: = PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t: = float(i) / RATE
		var v: = sin(TAU * hz * t) + sin(TAU * (hz + 1.7) * t) * 0.8 + sin(TAU * hz * 2.71 * t) * 0.35 * exp(-t / 0.9) + sin(TAU * hz * 5.1 * t) * 0.12 * exp(-t / 0.4)
		out[i] = v * exp(-t / 1.4) * minf(1.0, t / 0.02)
	_norm(out, 0.5)
	var w: = _wav(out)
	_cache[key] = w
	return w


# перелив: шум через резонанс, уходящий вниз (1400 → 450 Гц), и пузырьки
static func spill() -> AudioStreamWAV:
	if _cache.has("spill"):
		return _cache["spill"]
	var dur: = 0.75
	var n: = int(RATE * dur)
	var out: = PackedFloat32Array()
	out.resize(n)
	var rng: = RandomNumberGenerator.new()
	rng.seed = 4242
	var y1: = 0.0
	var y2: = 0.0
	for i in n:
		var t: = float(i) / RATE
		var f: = lerpf(1400.0, 450.0, minf(1.0, t / 0.55))
		var w0: = TAU * f / RATE
		var r: = 0.96
		var x: = rng.randf_range(-1.0, 1.0)
		var y: = x * 0.08 + 2.0 * r * cos(w0) * y1 - r * r * y2
		y2 = y1
		y1 = y
		var env: = minf(1.0, t / 0.05) * exp(-maxf(0.0, t - 0.15) / 0.22)
		out[i] = y * env
	# пузырьки: короткие свисты вверх
	for b in 6:
		var st: = 0.08 + b * 0.085 + rng.randf_range(0, 0.03)
		var f0: = rng.randf_range(420.0, 700.0)
		var bl: = int(RATE * 0.035)
		for k in bl:
			var i2: = int(st * RATE) + k
			if i2 >= n:
				break
			var tt: = float(k) / RATE
			out[i2] += sin(TAU * (f0 + 9000.0 * tt) * tt) * 0.35 * sin(PI * k / bl)
	_norm(out, 0.45)
	var w: = _wav(out)
	_cache["spill"] = w
	return w


# деревянный «тук» (отказ — дерево, а не «бззз», UX З-2)
static func knock(hz: float) -> AudioStreamWAV:
	var key: = "k%.1f" % hz
	if _cache.has(key):
		return _cache[key]
	var n: = int(RATE * 0.08)
	var out: = PackedFloat32Array()
	out.resize(n)
	var rng: = RandomNumberGenerator.new()
	rng.seed = int(hz)
	var y1: = 0.0
	var y2: = 0.0
	var w0: = TAU * hz / RATE
	var r: = 0.985
	for i in n:
		var x: = rng.randf_range(-1.0, 1.0) * exp(-i / (RATE * 0.0025))
		var y: = x + 2.0 * r * cos(w0) * y1 - r * r * y2
		y2 = y1
		y1 = y
		out[i] = y * exp(-i / (RATE * 0.02))
	_norm(out, 0.5)
	var w: = _wav(out)
	_cache[key] = w
	return w


# пэд дня: 12 с, бесшовная петля (все частоты — целое число периодов за 12 с), дыхание громкости без ритма
static func pad_loop() -> AudioStreamWAV:
	if _cache.has("pad"):
		return _cache["pad"]
	var n: = int(PAD_RATE * PAD_LEN)
	var out: = PackedFloat32Array()
	out.resize(n)
	# ре мажор пентатоника, мягко: D3 A3 D4 E4 F#4 (+ октавные призвуки)
	var notes: = [146.83, 220.0, 293.66, 329.63, 369.99]
	var amps: = [0.9, 0.55, 0.42, 0.26, 0.2]
	var hz: = []
	for f in notes:
		hz.append(round(f * PAD_LEN) / PAD_LEN)
	for i in n:
		var t: = float(i) / PAD_RATE
		var v: = 0.0
		for k in hz.size():
			# у каждой ноты своё медленное «дыхание» (1, 2 или 3 периода на петлю)
			var br: = 0.55 + 0.45 * sin(TAU * t * float(1 + k % 3) / PAD_LEN + k * 1.3)
			var f: float = hz[k]
			v += (sin(TAU * f * t) + 0.12 * sin(TAU * f * 2.0 * t)) * amps[k] * br
		out[i] = v
	_norm(out, 0.4)
	var w: = _wav(out, true, PAD_RATE)
	_cache["pad"] = w
	return w
