class_name V6Heroines
extends RefCounted



static func skill_need(h: String) -> int:
	var lv: = G.aff_level(h)
	return 8 - mini(3, (lv - 1) / 3)


static func start_charge(h: String) -> int:
	var id: = G.equipped(h)
	if id == "" or not G.ITEM.has(id):
		return 0
	match String(G.ITEM[id].get("rar", "R")):
		"SSR": return 3
		"SR": return 2
	return 0

static func bond_text(h: String) -> String:
	var parts: = ["Симпатия %d" % G.aff_level(h)]
	var need: = skill_need(h)
	if need < 8:
		parts.append("умение за %d %s" % [need, V8PlayRules.plural(need, "пару", "пары", "пар")])
	var sc: = start_charge(h)
	if sc > 0:
		parts.append("наряд +%d" % sc)
	return " · ".join(parts)


const RIVALS: = {
	"mc": {"pace": 5.6, "bg": "play", "fx": "petals", "skill": "double", "skill_name": "Восточный ветер", 
		"skill_desc": "забирает две пары подряд"}, 
	"rin": {"pace": 5.0, "bg": "bg_teahouse", "fx": "petals", "skill": "double", "skill_name": "Чайная церемония", 
		"skill_desc": "забирает две пары подряд"}, 
	"hana": {"pace": 4.0, "bg": "bg_street", "fx": "lanterns", "skill": "sprint", "skill_name": "Спринт", 
		"skill_desc": "семь секунд играет вдвое быстрее"}, 
	"yue": {"pace": 4.5, "bg": "bg_palace", "fx": "petals", "skill": "veil", "skill_name": "Лунная вуаль", 
		"skill_desc": "прячет лица четырёх твоих свободных фишек на пять секунд"}, 
	"nova": {"pace": 3.7, "bg": "bg_neon", "fx": "lanterns", "skill": "double", "skill_name": "Перехват", 
		"skill_desc": "забирает две пары подряд"}, 
}
const RIVAL_SKILL_NEED: = 4
const TELEGRAPH: = 1.3


const DUEL_LINES: = {
	"mc": {"start": ["Сегодня я не поддаюсь. Честно-честно!"], "take": ["Моя!", "Эту я заберу~", "Хи-хи, успела!"], 
		"steal": ["Эй! Я на неё смотрела!", "Ну вот, увёл из-под носа…"], "skill": ["Восточный ветер! Смотри внимательно!"], 
		"lead": ["Я впереди! Догоняй!"], "behind": ["Ты слишком быстрый…"], "win": ["Победа моя! Но было близко."], 
		"lose": ["Ты выиграл… Я горжусь, правда!"], "draw": ["Ничья! Значит, ещё одну партию, да?"]}, 
	"rin": {"start": ["Партия без поддавков. Чай подождёт."], "take": ["Эту возьму я.", "Благодарю.", "Позволь."], 
		"steal": ["Хм. Дерзко.", "Отнять у хозяйки чайной… смело."], "skill": ["Чайная церемония. Не торопись, учись."], 
		"lead": ["Спешка редко побеждает."], "behind": ["Неплохо. Очень неплохо."], "win": ["Партия моя. Налить утешительного?"], 
		"lose": ["Ты победил. Запишу это в книгу чайной."], "draw": ["Ничья. Чай остыл, а спор не решён."]}, 
	"hana": {"start": ["На старт! Кто больше пар, тот и чемпион!"], "take": ["Моя!", "Хоп!", "Обгоняю!"], 
		"steal": ["Эй, нечестно! Ну ладно, честно…", "Перехват! Хорош!"], "skill": ["Спринт! Догоняй, если сможешь!"], 
		"lead": ["Я впереди на круг!"], "behind": ["Ничего, финишный рывок ещё будет!"], "win": ["Первое место моё! Дай пять!"], 
		"lose": ["Ты меня сделал! Реванш, срочно!"], "draw": ["Ноздря в ноздрю! Требую переигровку!"]}, 
	"yue": {"start": ["Посмотрим, кому сегодня улыбнётся луна."], "take": ["Моя.", "Как и задумано.", "Луна на моей стороне."], 
		"steal": ["Ты осмелился?", "Любопытно…"], "skill": ["Лунная вуаль. Играй на ощупь."], 
		"lead": ["Звёзды на моей стороне."], "behind": ["Ты удивляешь меня."], "win": ["Партия за мной. Возвращайся сильнее."], 
		"lose": ["Я проиграла… и мне это даже нравится."], "draw": ["Луна не выбрала никого. Сыграем ещё."]}, 
	"nova": {"start": ["Запускаю протокол дуэли. Не тормози."], "take": ["Захват.", "Моя.", "Скачано."], 
		"steal": ["Эй, это был мой таргет!", "Перехват засчитан… тебе."], "skill": ["Перехват! Две цели разом!"], 
		"lead": ["Отрыв растёт."], "behind": ["Ты быстрее моего алгоритма?"], "win": ["Матч мой. Записываю в логи."], 
		"lose": ["Поражение… Сохраняю твой паттерн."], "draw": ["Ничья. Нужен ещё один прогон."]}, 
}

static func line(h: String, kind: String) -> String:
	var d: Dictionary = DUEL_LINES.get(h, DUEL_LINES.mc)
	var arr: Array = d.get(kind, [""])
	return arr[randi() % arr.size()]


static func duel_cfg(rival: String, partner: String) -> Dictionary:
	var rv: Dictionary = RIVALS.get(rival, RIVALS.rin)
	var shapes: = ["rect", "heart", "diamond", "butterfly", "ring", "pyramid"]
	var r: = RandomNumberGenerator.new()
	r.randomize()
	return {
		"name": "Дуэль · " + G.HEROES[rival].name, "code": "", "bg": rv.bg, "fx": rv.fx, "tint": Color(1, 1, 1), 
		"hero": partner, "shape": shapes[r.randi() % shapes.size()], "cols": 6, "rows": 7, "layers": 3, "fill": 0.8, 
		"faces": 11, "mech": "", "hard": 0, "seed": r.randi(), "gold": 2, "ice": 0, "hidden": false, 
		"reward": {"gems": 0}, "goal": "Собери больше пар, чем %s" % G.HEROES[rival].name, 
		"intro": "%s снимает пары с того же стола. Её цель светится заранее: забери одну из этих фишек первым, и ход сорвётся." % G.HEROES[rival].name, 
	}

static func save_data() -> Dictionary:
	if not G.S.has("v6_heroines") or not (G.S.v6_heroines is Dictionary):
		G.S["v6_heroines"] = {"duel_wins": {}, "duel_day": {}}
	var d: Dictionary = G.S.v6_heroines
	if not d.has("duel_wins"):
		d["duel_wins"] = {}
	if not d.has("duel_day"):
		d["duel_day"] = {}
	return d

static func duel_wins(h: String) -> int:
	return int(save_data().duel_wins.get(h, 0))


static func rival_pace(h: String) -> float:
	var rv: Dictionary = RIVALS.get(h, RIVALS.rin)
	return float(rv.pace) * maxf(0.7, 1.0 - 0.04 * duel_wins(h))
