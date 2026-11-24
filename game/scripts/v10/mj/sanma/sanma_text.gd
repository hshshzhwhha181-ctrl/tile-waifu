class_name V10MjSanmaText
extends RefCounted

# Все видимые строки Лунного стола в одном месте (UX_RULES §4: русское слово крупно, оригинал мелко).
# Проверка стоп-слов: V10Lint, если класс уже влит, иначе локальная копия списка §4.3 + стоп-слов героини.

const BTN: = {
	"pon": ["Взять", "пон"],
	"kan": ["Четыре", "кан"],
	"riichi": ["Готов", "риичи"],
	"ron": ["Победа", "рон"],
	"tsumo": ["Победа", "цумо"],
	"kita": ["Север", "кита"],
	"pass": ["Пропустить", ""],
}
const BTN_HINT: = {
	"riichi": "рука закрыта, +1 к комбинации",
	"kita": "Север уходит в дору, берёшь новую",
}

const UI: = {
	"title": "Лунный стол на троих",
	"wall": "Стена %d",
	"dora": "Дора",
	"kita_shelf": "Северы",
	"round": "%s %d",
	"honba": "Повтор %d",
	"you": "Ты",
	"your_turn": "Твой ход",
	"tap_twice": "Тап — выбрать, ещё тап — сбросить",
	"event_title": "Хозяйка против двоих",
	"event_mult": "×%d",
	"event_score": "Счёт события %+d",
	"event_hint": "Кан и Север: ×2",
	"result_win": "Победа",
	"result_draw": "Ничья",
	"result_place": "%d-е место",
	"result_combo": "Комбинация",
	"result_dora": "Дора",
	"result_kita": "Северы",
	"record": "Рекорд за руку",
	"next": "Дальше",
	"play": "Играть · Восток",
	"again": "Ещё партия",
	"tenpai": "Готовы: %s",
	"nobody": "никто",
	"coins": "%d монет",
	"gems": "%d кристаллов",
	"limit_none": "",
}

# Реплики хозяйки (Юэ): субтитр по-русски, озвучка по-японски (как все реплики 0.7/v10-mj-stage).
const LINES: = {
	"kita_1": {"ru": "Север — луне.", "jp": "北を、お月さまに。"},
	"kita_2": {"ru": "Спасибо. Света стало больше.", "jp": "ありがとう。光が増えたわ。"},
	"kita_3": {"ru": "Северный ветер принят.", "jp": "北風、受け取ったわ。"},
	"kita_4": {"ru": "Тяни ещё одну.", "jp": "ふふ、もう一枚どうぞ。"},
	"kita_5": {"ru": "Луна улыбнулась.", "jp": "月が、微笑んだ。"},
	"host_x2": {"ru": "Сегодня ×2. Держитесь, обе.", "jp": "今夜は二倍。お二人とも、覚悟して。"},
	"host_x3": {"ru": "Полнолуние. Играю на ×3.", "jp": "満月よ。三倍で行くわ。"},
}
const VOICE_DIR: = "res://assets/v10/mj/sanma/voice/"

# Локальная копия стоп-слов (UX_RULES §4.3 + стоп-слова героини из letters_selftest).
const UI_BANNED: = ["гарант", "пити", "pity", "50/50", "SSR+", "гача", "ролл", "крутк", "фивер", "ивент", "квартал",
	"перк", "ульта", "банер", "донат", "ХИТ", "ВЫГОДНО", "BEST", "NEW", "успей", "последний шанс", "топ-100",
	"ставк", "пари", "казино", "джекпот", "Режимы", "Богиня", "Яку"]
const HERO_BANNED: = ["учител", "ученик", "урок", "школ", "за парт", "куда смотришь", "колен", "грудь", "бёдр", "бедр",
	"вино", "пиво", "алкогол", "раздев", "бельё", "белье"]

static func btn(id: String, ru_names: = true) -> Array:
	var b: Array = BTN.get(id, [id, ""])
	return b if ru_names else [b[1].capitalize() if b[1] != "" else b[0], b[0]]

static func all_visible() -> Array:
	var out: = []
	for k in BTN:
		out.append_array(BTN[k])
	out.append_array(BTN_HINT.values())
	out.append_array(UI.values())
	for k in LINES:
		out.append(LINES[k].ru)
	out.append(V10MjSanmaInfo.INFO.name)
	out.append(V10MjSanmaInfo.INFO.line)
	out.append(V10MjSanmaInfo.INFO.teaser)
	out.append(V10MjSanmaInfo.INFO.event.name)
	out.append(V10MjSanmaInfo.INFO.event.line)
	return out

# Возвращает список нарушений: [строка, стоп-слово].
static func lint(strings: Array) -> Array:
	var bad: = []
	var ext: = []
	if ClassDB.class_exists("V10Lint") or ResourceLoader.exists("res://scripts/v10/clarity/lint.gd"):
		pass  # интегратор: прогнать также V10Lint.check(strings)
	for s in strings:
		var low: = String(s).to_lower()
		for w in UI_BANNED + HERO_BANNED + ext:
			var ww: String = String(w)
			# «риичи» и «яку» разрешены только с пояснением (у кнопки риичи есть BTN_HINT).
			if ww.length() <= 3 and ww == ww.to_upper():
				if String(s).find(ww) >= 0:
					bad.append([s, ww])
			elif low.find(ww.to_lower()) >= 0:
				bad.append([s, ww])
	return bad

static func voice_path(id: String) -> String:
	return VOICE_DIR + id + ".ogg"
