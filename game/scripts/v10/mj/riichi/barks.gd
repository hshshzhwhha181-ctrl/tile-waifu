class_name V10MjRiichiBarks
extends Node

# Table voices of the rivals. Source of truth is the stage lane (V10MjStageLines + its voice/*.ogg). When that
# class or a voice file is missing, the local fallback lines below are shown as a short subtitle and no sound plays.
# Contract (selftest): one said → at most one voice. Voices never overlap (a busy channel skips the new one).

const STAGE_LINES: = "res://scripts/v10/mj/stage/stage_lines.gd"
const EVENTS: = ["pon", "chi", "kan", "riichi", "ron", "tsumo", "tenpai", "dealin", "noten", "dora"]

const LINES: = {
	"mc": {"pon": "Беру!", "chi": "Ряд мой.", "kan": "Четыре!", "riichi": "Готова! Рука закрыта.", "ron": "Победа! Это моя.",
		"tsumo": "Сама взяла! Победа.", "tenpai": "Жду одну фишку~", "dealin": "Ой… отдала тебе.", "noten": "Не успела…", "dora": "Ветер переменился!"},
	"rin": {"pon": "Беру.", "chi": "Ряд.", "kan": "Четыре.", "riichi": "Готова. Рука закрыта.", "ron": "Победа. Ваша фишка.",
		"tsumo": "Сама. Победа.", "tenpai": "Я жду.", "dealin": "Моя ошибка.", "noten": "Не сложилось.", "dora": "Чай заварился."},
	"hana": {"pon": "Беру!", "chi": "Ряд — вперёд!", "kan": "Четыре! Разгон!", "riichi": "Готова! Иду до конца!", "ron": "Победа! Попался!",
		"tsumo": "Сама! Финиш!", "tenpai": "На старте!", "dealin": "Эх, споткнулась!", "noten": "Не добежала…", "dora": "Второе дыхание!"},
	"yue": {"pon": "Беру.", "chi": "Ряд.", "kan": "Четыре.", "riichi": "Готова. Рука закрыта.", "ron": "Победа. Луна видела.",
		"tsumo": "Сама. Как велит луна.", "tenpai": "Жду под луной.", "dealin": "Тень упала на меня.", "noten": "Не в этот раз.", "dora": "Луна взошла."},
	"nova": {"pon": "Беру!", "chi": "Ряд в кэш.", "kan": "Четыре! Буст!", "riichi": "Готова! Страховку выключила.", "ron": "Победа! Поймала.",
		"tsumo": "Сама! Взлом удался.", "tenpai": "Жду сигнал.", "dealin": "Баг… мой баг.", "noten": "Не скомпилилось.", "dora": "Апгрейд!"},
}

var player: AudioStreamPlayer
var voice_on: = true
var voices_played: = 0
var _stage = null
var _busy_until: = 0.0

func _ready() -> void:
	player = AudioStreamPlayer.new()
	player.volume_db = -2.0
	add_child(player)
	if ResourceLoader.exists(STAGE_LINES):
		_stage = load(STAGE_LINES)

static func key_for(what: String, data: Dictionary) -> String:
	if what == "call":
		return String(data.get("kind", "pon"))
	return what

func line(hero: String, ev: String) -> String:
	if _stage != null and ev in ["pon", "chi", "kan", "riichi", "ron", "tsumo", "tenpai", "dealin"]:
		var v: Array = _stage.variants(hero, ev)
		if not v.is_empty():
			return String(v[0][0])
	var h: String = hero if LINES.has(hero) else "mc"
	return String(LINES[h].get(ev, ""))

func voice_path(hero: String, ev: String) -> String:
	var p: = ""
	if _stage != null:
		p = _stage.voice_path(hero, ev, 1)
	else:
		p = "res://assets/v10/mj/stage/voice/%s_%s_1.ogg" % [hero, ev]
	return p if ResourceLoader.exists(p) else ""

# returns {"text", "voice": bool}; plays at most one voice
func say(hero: String, ev: String) -> Dictionary:
	var t: = line(hero, ev)
	var played: = false
	var now: = Time.get_ticks_msec() / 1000.0
	if voice_on and now >= _busy_until:
		var p: = voice_path(hero, ev)
		if p != "":
			var st: AudioStream = load(p)
			if st != null:
				player.stream = st
				player.play()
				_busy_until = now + st.get_length()
				played = true
				voices_played += 1
	return {"text": t, "voice": played}
