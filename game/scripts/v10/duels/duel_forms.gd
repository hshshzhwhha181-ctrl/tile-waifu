class_name V10DuelForms
extends RefCounted

# V10DuelForms — data of «Дуэли 2.0» (spec R6): the five forms of every heroine-rival, her «подлость» (her own
# trick, at most twice a match), the special rules of «Дуэль недели», the glossary lines.
#
#   form(h, f) -> Dictionary     f = 1..5: {hero, form, roman, pace, telegraph, need, trick, trick_n, soft_steal, jitter}
#     pace        seconds between two of her pairs (her form III pace × PACE_K[f]); never depends on wins in ranked
#     telegraph   0,7–1,2 s: her two tiles shimmer in her colour this long before she takes them
#     need        her pairs per charge of her trick; trick_n = how many times she may play it (≤ 2)
#     soft_steal  0…1: how often she may aim at a face you hold in the tray (form I never does)
#     steal_recover  after you took her pair, her next aim comes at this share of her pace (0,75 … 0,35)
#   trick(h) -> {kind, name, desc}   kinds: double (two pairs at once), sprint (7 s twice as fast),
#                                    veil (faces of 4 of your free tiles hidden for 5 s), frost (3 free tiles iced),
#                                    gust (faces of 6 free tiles swapped among themselves)
#   trick_text(h, f) -> «Лунная вуаль · 2 раза»
#   heroes(all = false)              released rivals (G.HEROES) or the whole roster of 20 (data of later waves)
#   weekly_rule(h) -> {id, name, line, cfg, run}   the special rule of her «Дуэль недели»
#   weekly_rival(wid) -> String      one released heroine per МСК week, in turn
#   FRIENDLY_FORMS = [2, 3, 4], WEEKLY_FORM = 3
#
# Heroines of later waves (ROSTER_20) have their forms and tricks here already; every list and every offer only
# shows heroines present in G.HEROES, so they stay hidden until their release.

const U: = preload("res://scripts/v10/duels/duel_util.gd")

const FORMS: = 5
const ROMAN: = ["I", "II", "III", "IV", "V"]
# per form index 0..4 (form I … V). Tuned with the race model (--duel_calibrate=1, README «Калибровка»).
const PACE_K: = [1.76, 1.35, 1.0, 0.7, 0.47]
const TELEGRAPH: = [1.2, 1.07, 0.95, 0.82, 0.7]
const NEED: = [7, 6, 5, 5, 4]
const TRICK_N: = [1, 1, 1, 2, 2]
const SOFT_STEAL: = [0.0, 0.1, 0.22, 0.35, 0.5]
# after you take her shimmering pair she aims again sooner at higher forms (share of her pace)
const STEAL_RECOVER: = [0.75, 0.65, 0.55, 0.45, 0.35]
const JITTER: = 0.15  # her pace varies ±15 % pair to pair (seeded by the deal)
const TRICK_CAP: = 2

const FRIENDLY_FORMS: = [2, 3, 4]
const WEEKLY_FORM: = 3

# pace = her seconds per pair at form III (forms scale it by PACE_K) and her trick. The paces even out the tricks
# (a sprint is worth more than a gust), so every heroine's forms I–V climb the same rating ladder
# (--duel_calibrate=1 measures it). Founders keep the names of their 0.6 duel skills and their duel lines;
# later waves are data, hidden until release.
const HEROES: = {
	"mc": {"pace": 2.28, "trick": "gust", "name": "Восточный ветер"},
	"rin": {"pace": 2.04, "trick": "frost", "name": "Чайная церемония"},
	"hana": {"pace": 2.66, "trick": "sprint", "name": "Спринт"},
	"yue": {"pace": 1.88, "trick": "veil", "name": "Лунная вуаль"},
	"nova": {"pace": 2.20, "trick": "double", "name": "Перехват"},
	# later waves (docs/ROSTER_20.md): data only, never shown before the heroine is in G.HEROES
	"tsubame": {"pace": 2.15, "trick": "veil", "name": "Дымовая шашка"},
	"miel": {"pace": 1.95, "trick": "frost", "name": "Глазурь"},
	"lian": {"pace": 1.9, "trick": "gust", "name": "Водоворот"},
	"jess": {"pace": 2.05, "trick": "veil", "name": "Пыльная буря"},
	"tsuru": {"pace": 2.4, "trick": "sprint", "name": "Журавлиный взлёт"},
	"kohaku": {"pace": 2.0, "trick": "gust", "name": "Лисий морок"},
	"shirin": {"pace": 2.15, "trick": "veil", "name": "Мираж"},
	"mari": {"pace": 2.5, "trick": "sprint", "name": "Шквал"},
	"hibana": {"pace": 2.05, "trick": "frost", "name": "Гром"},
	"nemi": {"pace": 2.25, "trick": "double", "name": "Две тропы"},
	"zlata": {"pace": 2.35, "trick": "double", "name": "Жар-перо"},
	"minamo": {"pace": 1.9, "trick": "gust", "name": "Прилив"},
	"kira": {"pace": 2.0, "trick": "veil", "name": "Помехи радара"},
	"vesper": {"pace": 2.2, "trick": "double", "name": "Алая ночь"},
	"sigrid": {"pace": 1.95, "trick": "frost", "name": "Изморозь"},
}

const TRICKS: = {
	"double": {"desc": "забирает две пары подряд", "pairs": 2},
	"sprint": {"desc": "семь секунд играет вдвое быстрее", "secs": 7.0, "speed": 2.2},
	"veil": {"desc": "прячет лица четырёх твоих свободных фишек на пять секунд", "n": 4, "secs": 5.0},
	"frost": {"desc": "сковывает льдом три свободные фишки", "n": 3},
	"gust": {"desc": "меняет местами лица шести свободных фишек", "n": 6},
}

# «Дуэль недели»: one rule per heroine. cfg = changes of the table, run = changes of her play.
const WEEKLY_RULES: = {
	"gold": {"name": "Золотой стол", "line": "Восемь золотых пар на столе", "cfg": {"gold": 16}},
	"ice": {"name": "Лёд", "line": "Шесть фишек скованы льдом с начала", "cfg": {"ice": 4}},
	"sprint_start": {"name": "Фальстарт", "line": "Она начинает партию спринтом", "run": {"start_sprint": 6.0}},
	"mist": {"name": "Туман", "line": "Фишки под другими лежат рубашкой вверх", "cfg": {"hidden": true}},
	"quick": {"name": "Быстрый глаз", "line": "Её цель мерцает всего 0,7 секунды", "run": {"telegraph": 0.7}},
	"twice": {"name": "Двойная подлость", "line": "Её подлость заряжается вдвое быстрее", "run": {"need_k": 0.5, "trick_n": 2}},
	"wide": {"name": "Большой стол", "line": "Стол выше, видов фишек больше", "cfg": {"faces": 14, "layers": 4}},
	"head_start": {"name": "Фора", "line": "Она начинает с двумя парами", "run": {"her_start": 2}},
}
const WEEKLY_OF: = {
	"mc": "gold", "rin": "ice", "hana": "sprint_start", "yue": "mist", "nova": "quick",
	"tsubame": "mist", "miel": "gold", "lian": "wide", "jess": "head_start", "tsuru": "sprint_start",
	"kohaku": "twice", "shirin": "mist", "mari": "quick", "hibana": "twice", "nemi": "wide",
	"zlata": "gold", "minamo": "ice", "kira": "quick", "vesper": "twice", "sigrid": "ice",
}

# lines for V10Glossary (integrator adds them to clarity/glossary.gd ENTRIES, cat "modes")
const GLOSSARY: = [
	{"id": "duel.rating", "cat": "modes", "name": "Рейтинг дуэлей",
		"why": "Показывает, насколько сильно ты играешь против героинь. Старт с 1 000",
		"how": "Побеждай в рейтинговых дуэлях: за сильную соперницу дают больше", "reward": "ступень сезона и награда в конце сезона"},
	{"id": "duel.tier", "cat": "modes", "name": "Ступень сезона",
		"why": "Шесть ступеней от Бронзового до Небесного веера",
		"how": "Сезон длится 28 дней; награда — по самой высокой ступени сезона", "reward": "кристаллы, рамки и титул"},
	{"id": "duel.form", "cat": "modes", "name": "Форма соперницы",
		"why": "Форма от I до V — насколько быстро и хитро она играет",
		"how": "Форма видна на карточке соперницы", "reward": "чем выше форма, тем больше рейтинга за победу"},
	{"id": "duel.trick", "cat": "modes", "name": "Подлость",
		"why": "Особый ход соперницы. Сколько раз она его сыграет, написано на карточке, не больше двух",
		"how": "Забирай её мерцающие пары первым: подлость копится от её пар", "reward": ""},
	{"id": "duel.weekly", "cat": "modes", "name": "Дуэль недели",
		"why": "Соперница недели с особым правилом стола",
		"how": "Три победы за неделю, неделя начинается в понедельник в 04:00 МСК", "reward": "100 кристаллов и 30 Лепестков"},
]


static func heroes(all: = false) -> Array:
	if all:
		return HEROES.keys()
	return U.released().filter(func(h): return HEROES.has(h))


static func valid_form(f: int) -> bool:
	return f >= 1 and f <= FORMS


static func roman(f: int) -> String:
	return ROMAN[clampi(f, 1, FORMS) - 1]


static func base(h: String) -> Dictionary:
	return HEROES.get(h, HEROES.mc)


static func form(h: String, f: int) -> Dictionary:
	var i: = clampi(f, 1, FORMS) - 1
	var b: = base(h)
	var tk: = String(b.trick)
	return {
		"hero": h, "form": i + 1, "roman": ROMAN[i],
		"pace": snappedf(float(b.pace) * float(PACE_K[i]), 0.01),
		"telegraph": float(TELEGRAPH[i]),
		"need": int(NEED[i]),
		"trick": tk, "trick_name": String(b.name), "trick_n": mini(int(TRICK_N[i]), TRICK_CAP),
		"soft_steal": float(SOFT_STEAL[i]),
		"steal_recover": float(STEAL_RECOVER[i]),
		"jitter": JITTER,
	}


static func trick(h: String) -> Dictionary:
	var b: = base(h)
	var t: Dictionary = TRICKS[String(b.trick)].duplicate()
	t["kind"] = String(b.trick)
	t["name"] = String(b.name)
	return t


static func trick_text(h: String, f: int) -> String:
	var fm: = form(h, f)
	return "%s · %s" % [fm.trick_name, U.times_text(int(fm.trick_n))]


# her play of one match: the form, then the weekly rule (if any). Ranked never reads wins: the pace is the form's.
static func run_params(h: String, f: int, kind: String, wins_vs_her: int = 0) -> Dictionary:
	var p: = form(h, f)
	if kind == "friendly":
		# the 0.6 rubber band stays only in friendly duels (V6Heroines.rival_pace): she speeds up as you win
		p.pace = snappedf(float(p.pace) * maxf(0.7, 1.0 - 0.04 * wins_vs_her), 0.01)
	if kind == "weekly":
		var rule: = weekly_rule(h)
		var run: Dictionary = rule.get("run", {})
		if run.has("telegraph"):
			p.telegraph = float(run.telegraph)
		if run.has("need_k"):
			p.need = maxi(2, int(round(float(p.need) * float(run.need_k))))
		if run.has("trick_n"):
			p.trick_n = mini(int(run.trick_n), TRICK_CAP)
		p["start_sprint"] = float(run.get("start_sprint", 0.0))
		p["her_start"] = int(run.get("her_start", 0))
	p.telegraph = clampf(float(p.telegraph), 0.7, 1.2)
	p.trick_n = clampi(int(p.trick_n), 0, TRICK_CAP)
	return p


static func weekly_rule(h: String) -> Dictionary:
	var id: = String(WEEKLY_OF.get(h, "gold"))
	var r: Dictionary = WEEKLY_RULES[id].duplicate(true)
	r["id"] = id
	return r


static func weekly_rival(wid: int) -> String:
	var hs: = heroes()
	if hs.is_empty():
		return "mc"
	return String(hs[posmod(wid, hs.size())])


# every visible line of the data (selftest lint)
static func all_texts() -> Array:
	var out: = []
	for h in HEROES:
		out.append(String(HEROES[h].name))
		for f in range(1, FORMS + 1):
			out.append(trick_text(h, f))
	for k in TRICKS:
		out.append(String(TRICKS[k].desc))
	for k in WEEKLY_RULES:
		out.append(String(WEEKLY_RULES[k].name))
		out.append(String(WEEKLY_RULES[k].line))
	for g in GLOSSARY:
		for k in ["name", "why", "how", "reward"]:
			out.append(String(g[k]))
	return out
