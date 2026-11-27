extends Node

# Sfx — sounds, music, heroine voices (autoload).
#   Sfx.play(name, pitch = 1, vol_db = 0)    one-shot from res://assets/sfx/<name>.wav (respects S.sound)
#   Sfx.music(name, fade = 1.2)              crossfade the music loop ("" stops)
#   Sfx.say(hero, kind) -> String            a heroine line (+ voice file when there is one)
# 0.9 Foundation (Stream A):
#   Sfx.combo_step(n, vol_db = 0) -> float   the combo pitch ladder: pair n of a combo plays the match chime
#                                            a semitone higher than pair n-1 (pair 1 = base pitch), capped at an
#                                            octave (pair 13+). Returns the pitch used. Use it for every combo pair.
#   Sfx.combo_pitch(n) -> float              the same ladder as a pure function (2^((min(n,13)-1)/12))
#   Sfx.duck(depth_db = -8, hold = 1.4)      lower the music for `hold` seconds (cut-ins, big reveals); repeated
#                                            calls extend/deepen, never stack. Attack 0.08 s, release 0.4 s.
#   Sfx.duck_hold(on, depth_db = -8)         duck for as long as on == true (e.g. while a cut-in is on screen)
#   Sfx.duck_db() -> float                   current music attenuation (0 = none), for tests / dev overlay
#   Music plays on its own "Music" bus (created at start if the project has no bus layout); ducking moves that bus.

const COMBO_BASE: = "match0"
const COMBO_MAX_STEP: = 12
const MUSIC_BUS: = "Music"
const DUCK_ATTACK: = 0.08
const DUCK_RELEASE: = 0.4


const VOICE: = {
	"greet": 2, "match": 3, "combo": 2, "fever": 1, "win": 2, "lose": 1, "gacha": 1, "ssr": 1, "outfit": 1, "aff": 1, "hint": 1, 
}


const VOICED: = {
	"mc": {"greet": ["Привет! Это Маджонг-тян! Сегодня тоже постараемся вместе!", "С возвращением! Я тебя ждала~!"], "match": ["Отлично!", "Есть пара!", "Так держать!"], "combo": ["Комбо! Не останавливайся!", "Ого-ого, как быстро!"], "fever": ["Фивер-тайм! Давай всё разом!"], "win": ["Ура! Пройдено! Ты лучший!", "Хи-хи, я так рада. И в следующий раз вместе!"], "lose": ["Ой… ходов не осталось. Ничего, ещё разок!"], "gacha": ["Что же выпадет? Сердечко стучит…!"], "ssr": ["Не может быть, SSR!? Обалдеть!"], "outfit": ["Ну как? Мне идёт…?"], "aff": ["Играть с тобой так весело!"], "hint": ["Смотри, вот эти две!"], "yaku": ["Яку собрано! Видишь, как красиво сложилось?", "Ух ты, настоящая комбинация!"], "riichi": ["Ва-банк! Теперь только мы вдвоём, без подсказок!"], "rankup": ["Новый ранг! Я так тобой горжусь!"]}, 
	"rin": {"greet": ["Добро пожаловать. Хи-хи, располагайся поудобнее.", "О, ты снова пришёл? Как приятно."], "match": ["Превосходно.", "У тебя зоркий глаз.", "Да, верно."], "combo": ["О, а ты неплох.", "Какая сноровка, залюбуешься."], "fever": ["Хм, покажи-ка, на что ты способен."], "win": ["Чудесно. В награду заварю тебе чаю.", "Как и ожидала. Я в тебе не ошиблась."], "lose": ["Ну-ну, не торопись. Ещё раз, вместе."], "gacha": ["Ну что, какой чай нальёт судьба?"], "ssr": ["Ох… это нечто особенное. Береги."], "outfit": ["Как тебе наряд? …Можешь засмотреться."], "aff": ["С тобой я забываю о времени."], "hint": ["Вот здесь. Смотри внимательно."], "yaku": ["Изящная комбинация. Запишу её в книгу чайной.", "Такое сочетание редко встретишь."], "riichi": ["Ва-банк. Что ж, покажи свою решимость."], "rankup": ["Новый ранг тебе к лицу. Поздравляю."]}, 
	"hana": {"greet": ["Йо! Это Хана! Сегодня снова на полную!", "О, пришёл! Разминку сделал?"], "match": ["Найс!", "Йе-е!", "Хороший темп!"], "combo": ["Серия голов! Держи темп!", "Мы можем ещё больше!"], "fever": ["Фивер на максимум! Финальный рывок!"], "win": ["Ура! Победа! Дай пять!", "Это была лучшая игра!"], "lose": ["Эх, обидно! Но в следующий раз победим!"], "gacha": ["Ну, понеслась!"], "ssr": ["Ого, SSR!? Джекпот!"], "outfit": ["Хе-хе, двигаться удобно! Ну как?"], "aff": ["С тобой я готова стараться ещё сильнее!"], "hint": ["Смотри, вот эта и эта!"], "yaku": ["Комбинация! Это как гол в девятку!", "Йес, яку засчитано!"], "riichi": ["Ва-банк! Дальше без подсказок!"], "rankup": ["Ранг выше! Пьедестал наш!"]}, 
	"yue": {"greet": ["Лунный свет привёл тебя… Добро пожаловать.", "Составишь мне компанию и этой ночью?"], "match": ["Недурно.", "Изящный ход.", "Хм, великолепно."], "combo": ["Так держать. Даже луна улыбается.", "Словно падающая звезда."], "fever": ["Сила полной луны, высвободись!"], "win": ["Победа твоя. Гордись.", "Это было великолепно. Похвалю тебя."], "lose": ["Луна лишь скрылась за облаком. Попробуй снова."], "gacha": ["Звёзды, явите судьбу."], "ssr": ["Какое сияние… Судьба выбрала тебя."], "outfit": ["Этот наряд… я выбрала его для тебя."], "aff": ["Рядом с тобой… мне почему-то спокойно."], "hint": ["Взгляни сюда."], "yaku": ["Узор сложился, как созвездие.", "Звёзды выстроились в ряд."], "riichi": ["Ва-банк. Луна свидетель твоей смелости."], "rankup": ["Твой ранг растёт, как луна к полнолунию."]}, 
	"nova": {"greet": ["Доступ получен. Хм, так ты мой новый напарник?", "С возвращением. Системы в норме."], "match": ["Попадание.", "Проще простого.", "Неплохо."], "combo": ["Цепочка комбо, не остановить!", "Скорость обработки растёт!"], "fever": ["Оверклок! Сноси всё!"], "win": ["Миссия выполнена. А ты хорош.", "Взлом удался. Награда наша."], "lose": ["Ошибка… перезагрузимся и ещё раз."], "gacha": ["Взламываю гачу!"], "ssr": ["Серьёзно!? Редкость на максимум!"], "outfit": ["Новый скин установлен. Ну как?"], "aff": ["С тобой я… немножко глючу."], "hint": ["Цель захвачена. Здесь."], "yaku": ["Паттерн распознан. Бонус начислен.", "Комбо-сигнатура подтверждена!"], "riichi": ["Ва-банк. Отключаю страховку!"], "rankup": ["Апгрейд ранга установлен."]}, 
}

signal voice_started(hero: String, text: String, dur: float)

var pool: Array[AudioStreamPlayer] = []
var cache: = {}
var music_a: AudioStreamPlayer
var music_b: AudioStreamPlayer
var voice: AudioStreamPlayer
var cur_music: = ""
var last_voice: = {}

func _ready() -> void :
	for i in 14:
		var p: = AudioStreamPlayer.new()
		add_child(p)
		pool.append(p)
	music_a = AudioStreamPlayer.new()
	music_b = AudioStreamPlayer.new()
	voice = AudioStreamPlayer.new()
	for p in [music_a, music_b, voice]:
		add_child(p)
	voice.volume_db = 1.0
	_ensure_music_bus()
	music_a.bus = MUSIC_BUS
	music_b.bus = MUSIC_BUS


func _ensure_music_bus() -> void :
	if AudioServer.get_bus_index(MUSIC_BUS) >= 0:
		return
	AudioServer.add_bus()
	var i: = AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, MUSIC_BUS)
	AudioServer.set_bus_send(i, "Master")


static func combo_pitch(n: int) -> float:
	return pow(2.0, float(clampi(n - 1, 0, COMBO_MAX_STEP)) / 12.0)


func combo_step(n: int, vol_db: = 0.0) -> float:
	var p: = combo_pitch(n)
	play(COMBO_BASE, p, vol_db)
	return p


var _duck_until: = 0.0
var _duck_depth: = 0.0
var _duck_held: = false
var _duck_hold_depth: = 0.0
var _duck_cur: = 0.0


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func duck(depth_db: = -8.0, hold: = 1.4) -> void :
	var t: = _now()
	_duck_depth = minf(depth_db, _duck_depth) if t < _duck_until else depth_db
	_duck_until = maxf(_duck_until, t + hold)


func duck_hold(on: bool, depth_db: = -8.0) -> void :
	_duck_held = on
	_duck_hold_depth = depth_db


func duck_db() -> float:
	return _duck_cur


func _process(dt: float) -> void :
	var target: = 0.0
	if _now() < _duck_until:
		target = _duck_depth
	if _duck_held:
		target = minf(target, _duck_hold_depth)
	if is_equal_approx(target, _duck_cur):
		return
	# constant slopes: an 8 dB duck lands in DUCK_ATTACK and lifts in DUCK_RELEASE
	var rate: = 8.0 / (DUCK_ATTACK if target < _duck_cur else DUCK_RELEASE)
	_duck_cur = move_toward(_duck_cur, target, rate * dt)
	var bi: = AudioServer.get_bus_index(MUSIC_BUS)
	if bi >= 0:
		AudioServer.set_bus_volume_db(bi, _duck_cur)

func _stream(path: String) -> AudioStream:
	if not cache.has(path):
		cache[path] = load(path)
	return cache[path]

func play(name: String, pitch: = 1.0, vol_db: = 0.0) -> void :
	if not G.S.get("sound", true):
		return
	var p: AudioStreamPlayer = null
	for q in pool:
		if not q.playing:
			p = q
			break
	if p == null:
		p = pool[0]
	p.stream = _stream("res://assets/sfx/%s.wav" % name)
	p.pitch_scale = pitch
	p.volume_db = vol_db
	p.play()

func _stop_legacy_music(fade: float) -> void :
	cur_music = ""
	for p in [music_a, music_b]:
		if p != null and p.playing:
			var t: = create_tween()
			t.tween_property(p, "volume_db", -40.0, fade)
			t.tween_callback(p.stop)

func music(name: String, fade: = 1.2) -> void :
	if name == "":
		_stop_legacy_music(fade)
		return
	if V10Registry.wired("audio"):
		_stop_legacy_music(minf(fade, 0.4))
		if V10Music.current() == "" and G.S.get("music", true):
			V10Music.play_screen(name, fade)
		return
	name = V7DayNight.music_name(name)
	if name == cur_music:
		return
	cur_music = name
	var old: = music_a if music_a.playing else music_b
	var nw: = music_b if old == music_a else music_a
	if name != "" and G.S.get("music", true):
		var st: AudioStream = _stream(V7DayNight.music_path(name)).duplicate()
		if st is AudioStreamOggVorbis:
			st.loop = true
		nw.stream = st
		nw.volume_db = -40
		nw.play()
		create_tween().tween_property(nw, "volume_db", -9.0, fade)
	if old.playing:
		var t: = create_tween()
		t.tween_property(old, "volume_db", -40.0, fade)
		t.tween_callback(old.stop)

# 0.8: «С возвращением» / «Опять пришёл?» only to a player whose last session was on an earlier day; on the
# first visit and for the rest of the same day the greeting is a plain one.
const RETURN_MARKS: = ["возвращ", "Опять", "снова", "Я тебя ждала", "каждый день", "и этой ночью"]
var _greet_ok = null

func _is_return_line(t: String) -> bool:
	for m in RETURN_MARKS:
		if t.contains(m):
			return true
	return false

func _greet_returning() -> bool:
	if _greet_ok == null:
		var prev: = String(G.S.get("v8_last_day", ""))
		_greet_ok = prev != "" and prev != G.today()
		G.S["v8_last_day"] = G.today()
		G.save()
	return bool(_greet_ok)

func say(hero: String, kind: String) -> String:
	# Japanese voice-over (res://assets/voice/<hero>_<kind><n>.mp3 or V10SfxBank OGG) with Russian subtitles;
	# Wave-1 heroines keep their own Russian lines (never fall back to "mc").
	if V10W1Core.is_wave1_hero(hero):
		var wsrc: Dictionary = V10W1HomeLines.BARKS
		if not wsrc.has(hero):
			return ""
		var mapped_kind: String = kind
		match kind:
			"match", "fever", "yaku", "riichi", "hint":
				mapped_kind = "combo"
			"gacha", "rankup":
				mapped_kind = "ssr"
			"lose":
				mapped_kind = "greet"
			"greet", "combo", "win", "aff", "ssr", "outfit":
				mapped_kind = kind
			_:
				mapped_kind = "greet"
		var warr: Array = wsrc[hero].get(kind, [])
		if warr.is_empty():
			warr = wsrc[hero].get(mapped_kind, [])
		if warr.is_empty():
			warr = wsrc[hero].get("greet", [])
		if warr.is_empty():
			return ""
		if kind == "greet" and not _greet_returning():
			var wfresh: = warr.filter(func(x): return not _is_return_line(String(x)))
			if not wfresh.is_empty():
				warr = wfresh
		var wi: = randi() % warr.size()
		var wkey: String = hero + kind
		if warr.size() > 1 and last_voice.get(wkey, -1) == wi:
			wi = (wi + 1) % warr.size()
		last_voice[wkey] = wi
		var wdur: = 1.2
		if G.S.get("sound", true) and G.S.get("voice", true):
			var wpath: = ""
			var candidates: Array[String] = [
				"res://assets/voice/%s_%s%d.mp3" % [hero, kind, wi + 1],
				V10W1Audio.voice_path(hero, kind, wi),
				V10W1Audio.voice_path(hero, kind, 0),
			]
			if mapped_kind != kind:
				candidates.append(V10W1Audio.voice_path(hero, mapped_kind, 0))
			for cp in candidates:
				if ResourceLoader.exists(cp):
					wpath = cp
					break
			if wpath != "":
				var wst: AudioStream = _stream(wpath)
				if wst != null:
					voice.stream = wst
					voice.play()
					wdur = wst.get_length()
					duck(-8.0, clampf(wdur + 0.25, 1.2, 4.0))
			elif V10SfxBank.has("silk_open"):
				V10SfxBank.play("silk_open")
			else:
				play("pop", 1.15, -10.0)
		voice_started.emit(hero, warr[wi], wdur)
		return warr[wi]

	var src: Dictionary = V6Txt.LINES
	if not src.has(hero) or not src[hero].has(kind):
		hero = "mc"
	if not src[hero].has(kind):
		return ""
	# Route 0.10 founder barks (riichi / rankup) to V10SfxBank OGG voice files when present
	if kind in V10SfxBank.VOICE_KINDS and hero in V10SfxBank.HEROES:
		var vpath: = V10SfxBank.voice_path(hero, kind)
		if ResourceLoader.exists(vpath):
			var bank: = V10SfxBank.inst()
			if bank != null and bank.is_inside_tree():
				voice.stop()
				if G.S.get("sound", true) and G.S.get("voice", true):
					var vst: AudioStream = _stream(vpath)
					var vdur: = vst.get_length() if vst != null else 1.2
					duck(-8.0, clampf(vdur + 0.25, 1.2, 4.0))
				var vtxt: String = V10SfxBank.voice(hero, kind)
				if vtxt != "":
					return vtxt
			else:
				var fallback_txt: String = String(VOICED[hero][kind][0]) if VOICED.has(hero) and VOICED[hero].has(kind) and not VOICED[hero][kind].is_empty() else String(src[hero][kind][0])
				var vdur2: = 1.2
				if G.S.get("sound", true) and G.S.get("voice", true):
					var vst2: AudioStream = _stream(vpath)
					if vst2 != null:
						voice.stream = vst2
						voice.play()
						vdur2 = vst2.get_length()
						duck(-8.0, clampf(vdur2 + 0.25, 1.2, 4.0))
				voice_started.emit(hero, fallback_txt, vdur2)
				return fallback_txt
	var arr: Array = src[hero][kind]
	if kind in ["match", "combo", "fever", "win", "lose", "hint"] and VOICED.has(hero) and VOICED[hero].has(kind):
		arr = VOICED[hero][kind]
	if kind == "greet" and not _greet_returning():
		var fresh: = arr.filter( func(x): return not _is_return_line(String(x)))
		if not fresh.is_empty():
			arr = fresh
	var i: = randi() % arr.size()
	var key: String = hero + kind
	if arr.size() > 1 and last_voice.get(key, -1) == i:
		i = (i + 1) % arr.size()
	last_voice[key] = i
	var v_cnt: int = int(VOICE.get(kind, 0))
	var v_idx: int = i + 1
	if kind == "greet":
		v_idx = 1 if not _greet_returning() else ((i % maxi(v_cnt, 1)) + 1)
	elif v_cnt > 0:
		v_idx = (i % v_cnt) + 1
	var path: = "res://assets/voice/%s_%s%d.mp3" % [hero, kind, v_idx]
	var dur: = 1.2
	var relax_match: bool = kind in ["greet", "gacha", "rankup", "riichi"]
	var voiced_ok: bool = VOICED.has(hero) and VOICED[hero].has(kind) and (relax_match or (i < VOICED[hero][kind].size() and VOICED[hero][kind][i] == arr[i]))
	if voiced_ok and G.S.get("sound", true) and G.S.get("voice", true) and ResourceLoader.exists(path):
		var st: AudioStream = _stream(path)
		if st != null:
			voice.stream = st
			voice.play()
			dur = st.get_length()
			duck(-8.0, clampf(dur + 0.25, 1.2, 4.0))
	voice_started.emit(hero, arr[i], dur)
	return arr[i]
