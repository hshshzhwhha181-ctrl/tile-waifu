class_name V10VipDate
extends RefCounted

# «Приватный вечер» — branching 16+ date logic for the VIP boudoirs (0.12.0). Pure data + static helpers (testable).
# 3 steps, 3 flirt tones per step (sweet / bold / tease). Step 2 branches on step-1 result, step 3 on the spark so far.
# Daily reward limit per heroine: G.S["v10_dates"] = {day, done: {hero: level}, total}.

const SAVE_KEY: = "v10_dates"
const TONES: = ["sweet", "bold", "tease"]
const TONE_NAMES: = {"sweet": "Нежно", "bold": "Смело", "tease": "Дерзко"}
const SPARK_BY_PREF: = [34, 20, 8]
const AFF_REWARD: = 60
const RANK_NAMES: = ["Тёплый вечер", "Жаркий вечер", "Пылающая ночь"]
const RANK_MIN: = [0, 45, 75]
const HERO_IDS: = ["mc", "rin", "yue", "nova", "kohaku", "shirin", "tsubame", "zlata"]

# date level (min heroine affection level) -> title and bonus on top of +60 affection
const LEVELS: Array[Dictionary] = [
	{"lv": 1, "title": "Тизер · Первая искра", "gems": 30, "gift": ""},
	{"lv": 2, "title": "Шёпот за ширмой", "gems": 60, "gift": ""},
	{"lv": 4, "title": "Свет одной свечи", "gems": 40, "gift": "gift_silk_fan"},
	{"lv": 6, "title": "Приватная ночь", "gems": 100, "gift": "gift_silk_fan"},
]

# tone preference of each heroine, best -> worst
const PREF: = {
	"mc": ["bold", "tease", "sweet"], "rin": ["tease", "sweet", "bold"], "yue": ["sweet", "tease", "bold"],
	"nova": ["tease", "bold", "sweet"], "kohaku": ["sweet", "bold", "tease"], "shirin": ["bold", "tease", "sweet"],
	"tsubame": ["tease", "sweet", "bold"], "zlata": ["bold", "sweet", "tease"],
}

const PLACE: = {
	"mc": "в алом будуаре", "rin": "у стойки полуночного бара", "yue": "в лунной купальне", "nova": "на диване пентхауса",
	"kohaku": "в святилище белой лисы", "shirin": "среди шёлковых подушек шатра", "tsubame": "на балконе над ночным городом",
	"zlata": "у подножия огненного трона",
}

# reaction of a heroine to the choice: [liked best, so-so, off]
const REACT: = {
	"mc": ["Ох… вот это по-моему. Кажется, я начинаю краснеть~", "Хм, неплохо. Но можно было и посмелее.", "Эй, не так быстро! Хотя… ладно, прощаю."],
	"rin": ["Ах, ты читаешь меня как рецепт чая. Приятно и опасно.", "Мило. Но я люблю, когда меня дразнят.", "Слишком прямолинейно. Налью тебе остыть."],
	"yue": ["Как тёплая вода… не останавливайся.", "Лунный свет всё слышит. И улыбается.", "Громко. Шёпотом было бы лучше."],
	"nova": ["Пульс 120. Это ты сделал? Хм, сохраняю.", "Данные приняты. Продолжай эксперимент.", "Ошибка тона. Но ты забавно краснеешь."],
	"kohaku": ["Хвост сам вильнул… Не смотри, не смотри!", "Мм, тепло. Лиса запомнила.", "Фыр! Так лису не гладят."],
	"shirin": ["Браслеты зазвенели сами. Ты попал в точку.", "Приятно. Сядь ближе, караванщик.", "Пустыня любит смелых, а не торопливых."],
	"tsubame": ["Ласточка присела на твою ладонь. Редкая честь.", "Ловко. Но я ещё не сдалась.", "Мимо. Попробуй поймать ветер заново."],
	"zlata": ["Достойно трона. Продолжай, смертный.", "Терпимо. Жар-птица ждёт большего.", "Дерзость без огня — просто шум."],
}

const ENDINGS: = [
	"{n} прячет улыбку в ладонях: «Было мило. Приходи завтра».",
	"{n} не отпускает твою руку: «Этот вечер я запомню надолго».",
	"{n} шепчет на ухо: «Останься до утра. Это приказ… и просьба».",
]

# hit-test bundles for the UI: which hero voice kind to play per result
const VOICE_BY_PREF: = ["aff", "win", "greet"]

# c = [sweet, bold, tease]; {n} = heroine name, {place} = where you are
const SCRIPT: = {
	1: {
		"s1": {"p": "{n} ждёт {place}. Свет мягкий, она смотрит на тебя исподлобья. С чего начнёшь?",
			"c": ["Поправить ей выбившуюся прядь", "Взять её за руку и не отпускать", "Шепнуть: «Ты сегодня опасно красива»"]},
		"s2w": {"p": "Она придвинулась ближе, дыхание сбилось. «Продолжай… если не боишься».",
			"c": ["Тихо сказать, что рядом с ней спокойно", "Притянуть её за талию", "Усмехнуться: «Боюсь только, что ты передумаешь»"]},
		"s2c": {"p": "Она отводит взгляд, но не уходит. «Хм. Попробуй ещё раз, смелее».",
			"c": ["Извиниться и предложить чай", "Шагнуть вплотную, глядя в глаза", "Подмигнуть: «Первый блин комом, второй — поцелуем»"]},
		"s3": {"ph": "Между вами горит искра. {n} закусывает губу: «Финальный ход — за тобой».",
			"pc": "{n} вздыхает: «Вечер ещё можно спасти. Один шанс».",
			"c": ["Обнять и замереть так на минуту", "Поцеловать её руку, а потом — запястье", "Прошептать: «Закрой глаза. Сюрприз»"]},
	},
	2: {
		"s1": {"p": "За ширмой тихо шуршит шёлк. {n} зовёт тебя {place}: «Подойди. Я хочу кое-что показать».",
			"c": ["Подать ей накидку на плечи", "Сесть вплотную, плечом к плечу", "Приподнять бровь: «Только показать?»"]},
		"s2w": {"p": "{n} краснеет, но смелеет: «Ты ведь не уйдёшь до утра?»",
			"c": ["Пообещать остаться сколько нужно", "Убрать её волосы и коснуться шеи губами", "Фыркнуть: «Уйду. Если выгонишь»"]},
		"s2c": {"p": "{n} теребит край рукава: «Ты слишком… осторожный».",
			"c": ["Признаться, что боишься её спугнуть", "Взять её лицо в ладони", "Рассмеяться: «Это ловушка. И ты в неё попала»"]},
		"s3": {"ph": "Свеча дрожит, тени сплетаются. {n} тянется к тебе: «Закончи это красиво».",
			"pc": "{n} смотрит выжидающе: «Ну же. Последний шанс удивить меня».",
			"c": ["Укрыть её пледом и обнять", "Поцеловать — долго и без спешки", "Задуть свечу: «Остальное — в темноте»"]},
	},
	4: {
		"s1": {"p": "Дверь заперта. {n} сидит {place}, на ней — наряд смелее обычного. «Нравится? Только честно».",
			"c": ["Сказать, что она прекрасна в любом", "Не отрывать взгляда и медленно кивнуть", "Склонить голову: «Нужно рассмотреть ближе»"]},
		"s2w": {"p": "{n} улыбается уголками губ: «Ближе? Тогда не стой так далеко».",
			"c": ["Присесть рядом и взять за руку", "Подхватить её на руки", "Шёпотом: «Назови расстояние сама»"]},
		"s2c": {"p": "{n} скрещивает руки: «Хочешь рассматривать — заслужи».",
			"c": ["Налить ей тёплого чая", "Встать на одно колено: «Заслужу»", "Усмехнуться: «Условия озвучь, хозяйка»"]},
		"s3": {"ph": "Воздух звенит от жара. {n} шепчет: «Что ты со мной делаешь…»",
			"pc": "{n} кладёт ладонь тебе на грудь: «Сердце стучит. У тебя. И у меня».",
			"c": ["Прижаться лбом к её лбу", "Поцеловать её шею и ключицу", "Шепнуть: «Продолжим там, где светлее»"]},
	},
	6: {
		"s1": {"p": "Весь мир остался за дверью. {n} встречает тебя {place}: «Сегодня никаких правил. Только мы».",
			"c": ["Обнять её и молчать", "Подойти и поцеловать без слов", "Улыбнуться: «Правила я всё равно нарушу»"]},
		"s2w": {"p": "{n} прижимается к тебе: «Скажи, чего ты хочешь. Я слушаю».",
			"c": ["«Чтобы ты была счастлива рядом»", "«Тебя. Всю ночь»", "«Угадай. Подсказка — ты улыбаешься»"]},
		"s2c": {"p": "{n} тихо смеётся: «Ты всё ещё сдерживаешься? Не нужно».",
			"c": ["Признаться, что её присутствие кружит голову", "Притянуть её и перестать сдерживаться", "Склониться к уху: «Проверь сама, как сильно»"]},
		"s3": {"ph": "Ночь тянется медленно. {n} дрожащим голосом: «Останься. Это не просьба — это моё желание».",
			"pc": "{n} улыбается устало и тепло: «Ну… последняя попытка сделать эту ночь особенной».",
			"c": ["Остаться и держать её, пока не уснёт", "Поцеловать и не отпускать до рассвета", "Выключить свет: «Утром расскажешь, что было»"]},
	},
}


# ── logic ────────────────────────────────────────────────────────────────────────────────────────────────────────

static func level_def(lv: int) -> Dictionary:
	for d in LEVELS:
		if int(d.lv) == lv:
			return d
	return LEVELS[0]


# date levels the heroine (affection level `aff_lv`) has unlocked
static func unlocked_levels(aff_lv: int) -> Array:
	var out: Array = []
	for d in LEVELS:
		if aff_lv >= int(d.lv):
			out.append(int(d.lv))
	return out


static func pref_index(hero: String, tone: String) -> int:
	var p: Array = PREF.get(hero, PREF["mc"])
	return maxi(0, p.find(tone))


static func choice_spark(hero: String, tone: String) -> int:
	return int(SPARK_BY_PREF[pref_index(hero, tone)])


static func rank_for(spark: int) -> int:
	var r: = 0
	for i in RANK_MIN.size():
		if spark >= int(RANK_MIN[i]):
			r = i
	return r


static func node_key(step: int, spark: int, first_pref: int) -> String:
	if step <= 0:
		return "s1"
	if step == 1:
		return "s2w" if first_pref <= 1 else "s2c"
	return "s3"


# prompt + 3 choices of step `step` (0..2) for a heroine; branching: step 2 depends on the first reaction, step 3 on the spark
static func build_step(lv: int, step: int, hero: String, hero_name: String, spark: int, first_pref: int) -> Dictionary:
	var sc: Dictionary = SCRIPT.get(lv, SCRIPT[1])
	var key: = node_key(step, spark, first_pref)
	var node: Dictionary = sc[key]
	var prompt: = ""
	if key == "s3":
		prompt = String(node.ph if spark >= 40 else node.pc)
	else:
		prompt = String(node.p)
	prompt = prompt.replace("{n}", hero_name).replace("{place}", String(PLACE.get(hero, "наедине")))
	var choices: Array = []
	var texts: Array = node.c
	for i in TONES.size():
		var tone: String = TONES[i]
		choices.append({"tone": tone, "text": String(texts[i]), "spark": choice_spark(hero, tone), "pref": pref_index(hero, tone)})
	return {"node": key, "prompt": prompt, "choices": choices}


static func reaction(hero: String, tone: String) -> String:
	var arr: Array = REACT.get(hero, REACT["mc"])
	return String(arr[pref_index(hero, tone)])


static func ending(hero_name: String, rank: int) -> String:
	return String(ENDINGS[clampi(rank, 0, 2)]).replace("{n}", hero_name)


# plays a whole date for tests/tools: tones = 3 tone ids -> {spark, rank, nodes}
static func simulate(hero: String, lv: int, tones: Array) -> Dictionary:
	var spark: = 0
	var first_pref: = 0
	var nodes: Array = []
	for step in 3:
		var st: = build_step(lv, step, hero, hero, spark, first_pref)
		nodes.append(String(st.node) + (":hot" if step == 2 and spark >= 40 else ""))
		var tone: = String(tones[step])
		if step == 0:
			first_pref = pref_index(hero, tone)
		spark += choice_spark(hero, tone)
	spark = mini(100, spark)
	return {"spark": spark, "rank": rank_for(spark), "nodes": nodes}


# ── daily limit + reward (G.S["v10_dates"]) ──────────────────────────────────────────────────────────────────────

static func state() -> Dictionary:
	var root: Dictionary = G.S
	if not (root.get(SAVE_KEY) is Dictionary):
		root[SAVE_KEY] = {}
	var st: Dictionary = root[SAVE_KEY]
	var today: = V10Meta.day_key()
	if str(st.get("day", "")) != today:
		st["day"] = today
		st["done"] = {}
	if not (st.get("done") is Dictionary):
		st["done"] = {}
	st["total"] = int(st.get("total", 0))
	return st


static func reward_available(hero: String) -> bool:
	return not bool(state().done.get(hero, false))


static func claim(hero: String, lv: int, spark: int) -> Dictionary:
	if not reward_available(hero):
		return {"ok": false, "reason": "daily"}
	var st: = state()
	st.done[hero] = true
	st["total"] = int(st.total) + 1
	var d: = level_def(lv)
	var lines: Array = []
	G.add_aff(hero, AFF_REWARD)
	lines.append("+%d симпатии" % AFF_REWARD)
	if int(d.gems) > 0:
		V10Money.grant({"gems": int(d.gems)}, "boudoir_date")
		lines.append("+%d кристаллов" % int(d.gems))
	var gift: = String(d.gift)
	if gift == "" and rank_for(spark) >= 2:
		gift = "gift_tea_set"
	if gift != "":
		V10AffCurve.grant_gift(gift, 1)
		lines.append("Подарок «%s»" % String(V10AffCurve.gift_def(gift).get("name", gift)))
	G.save()
	return {"ok": true, "aff": AFF_REWARD, "gems": int(d.gems), "gift": gift, "lines": lines, "rank": rank_for(spark)}
