class_name V10MjKoikoiLines
extends RefCounted

# Реплики соперниц в Коикои. Реагируют ТОЛЬКО на публичное (её ход, твой ход, взятки на виду, итог):
# никогда не выдают, что у неё в руке (MODES §3.4 п. 5, «Честный стол»).
# Голос: res://assets/v10/mj/koikoi/voice/<hero>_<key>.(ogg|mp3|wav) для ключей koikoi / take / month.

const ACCENT: = {
	"mc": Color("ff8fb8"), "rin": Color("4fbf9f"), "hana": Color("ffb35c"), "yue": Color("c8b6ff"), "nova": Color("4fe3ff"),
}
const NAME: = {"mc": "Маджонг-тян", "rin": "Рин", "hana": "Хана", "yue": "Юэ", "nova": "Нова"}

# Кадр героини в арте assets/hero/<id>.png (848×1264): центр лица и верх силуэта — для поясного кадра и наезда «в камеру».
const FRAME: = {
	"mc": {"face": Vector2(424, 165), "top": 25},
	"rin": {"face": Vector2(404, 207), "top": 97},
	"hana": {"face": Vector2(424, 154), "top": 24},
	"yue": {"face": Vector2(394, 209), "top": 79},
	"nova": {"face": Vector2(494, 196), "top": 76},
}

const LINES: = {
	# твой выбор «Забрать / Кои-кои!» — единственный момент, когда она смотрит в камеру
	"dare": {"mc": "Не жадничай", "rin": "Не жадничай", "hana": "Смелее…", "yue": "Смелее…", "nova": "Смелее…"},
	"koikoi": {"mc": "Кои-кои!", "rin": "Кои-кои!", "hana": "Кои-кои!", "yue": "Кои-кои!", "nova": "Кои-кои!"},
	"take": {"mc": "Забираю", "rin": "Забираю", "hana": "Забираю", "yue": "Забираю", "nova": "Забираю"},
	"month": {"mc": "Это мой месяц", "rin": "Это мой месяц", "hana": "Это мой месяц", "yue": "Это мой месяц", "nova": "Это мой месяц"},
	"you_koi": {"mc": "Ох, рискуешь…", "rin": "Хм. Смело.", "hana": "Вот это дух!", "yue": "Посмотрим…", "nova": "Риск принят."},
	"you_light": {"mc": "Красивая карта!", "rin": "Достойный выбор.", "hana": "Ого, свет!", "yue": "Свет к свету.", "nova": "Ценный трофей."},
	"win": {"mc": "Ещё партию?", "rin": "Чай остынет. Ещё раз?", "hana": "Реванш за мной!", "yue": "Луна уступила тебе.", "nova": "Перезапуск. Ещё?"},
	"lose": {"mc": "Почти! Ещё разок?", "rin": "Почти. Ещё чашку?", "hana": "Было близко!", "yue": "Тень была длинной.", "nova": "Почти взломал меня."},
}

# Стоп-слова: UX_RULES §4.3 (локальная копия, если нет V10Lint) + запрет MODES §9 для ханафуды.
# Каждое — начало слова; «=» в конце — слово целиком.
const BANNED: = ["ставк", "пари=", "гарант", "пити=", "pity", "50/50", "гач", "ролл=", "крутк", "фивер", "ивент", "перк", "ульт", "яку=", "донат", "хит=", "выгодно", "best", "new=", "успей", "последний шанс", "казино", "выигрыш денег"]

static func line(kind: String, hero: String) -> String:
	return String(LINES.get(kind, {}).get(hero, ""))

static func accent(hero: String) -> Color:
	return ACCENT.get(hero, Color("e8c47e"))

static func voice_path(hero: String, key: String) -> String:
	for ext in ["ogg", "mp3", "wav"]:
		var p: = "res://assets/v10/mj/koikoi/voice/%s_%s.%s" % [hero, key, ext]
		if ResourceLoader.exists(p):
			return p
	return ""

# Все видимые строки режима (для самотеста стоп-слов).
static func all_visible() -> Array:
	var out: = []
	for k in LINES:
		for h in LINES[k]:
			out.append(LINES[k][h])
	for y in V10MjKoikoi.YAKU:
		out.append(V10MjKoikoi.YAKU[y].name)
		out.append(V10MjKoikoi.YAKU[y].orig)
	for n in V10MjKoikoi.MONTH_NAMES:
		out.append(n)
	for k in V10MjKoikoi.KIND_NAMES:
		out.append(V10MjKoikoi.KIND_NAMES[k])
	out.append(V10MjKoikoiInfo.INFO.name)
	out.append(V10MjKoikoiInfo.INFO.line)
	out.append(V10MjKoikoiInfo.INFO.pt)
	for h in V10MjKoikoiInfo.HOW:
		out.append(h)
	for p in V10MjKoikoiBook.PAGES:
		out.append(p.how)
	for t in V10MjKoikoiSkins.NAMES:
		out.append(V10MjKoikoiSkins.NAMES[t])
	return out

static func banned_hits(s: String) -> Array:
	var low: = " " + s.to_lower() + " "
	var hits: = []
	for b in BANNED:
		var whole: bool = b.ends_with("=")
		var w: String = b.trim_suffix("=")
		var re: = RegEx.new()
		re.compile("[^а-яёa-z0-9]" + _esc(w) + ("[^а-яёa-z0-9]" if whole else ""))
		if re.search(low) != null:
			hits.append(w)
	return hits

static func _esc(w: String) -> String:
	var o: = ""
	for ch in w:
		o += ("\\" + ch) if ch in "./()[]+*?^$|" else ch
	return o
