class_name V10AuthNicks
extends RefCounted

# Heroine-themed nickname ideas for the guest name picker: each idea comes «from» a founder (her props, her
# words), so a chip shows her avatar and picking it also picks her as the player's avatar.
#   V10AuthNicks.suggest(5, rng) -> [{"nick": "Лунный веер", "hero": "yue"}, …]  one per heroine, shuffled
# Every nick passes G.nick_error() (3…16 chars); the selftest checks the whole table.

const IDEAS: = {
	"mc": ["Восточный ветер", "Нефритовый узел", "Фишка удачи", "Сакура за столом", "Гость чайной", "Мастер пар",
		"Розовый хвост", "Ветер с востока"],
	"rin": ["Селадон", "Тихий улун", "Чайный лист", "Струйка пара", "Ледяной павильон", "Пиала улуна",
		"Нефритовая капля", "Золотая оправа"],
	"hana": ["Подсолнух", "Рыжий спринт", "Финишная лента", "Солнечный рывок", "Фонарик эстафеты", "Второе дыхание",
		"Секундомер", "Рассветный старт"],
	"yue": ["Лунный веер", "Полумесяц", "Лунный прилив", "Гость дворца", "Лунный странник", "Тень луны",
		"Любопытно", "Звёздный шёлк"],
	"nova": ["Неоновый байт", "Голофишка", "Ночной хакер", "Пинг ноль", "Кибер-лис", "Скачано",
		"Синий неон", "Root-доступ"],
}


static func suggest(n: = 5, rng: RandomNumberGenerator = null) -> Array:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var heroes: Array = G.HERO_ORDER.filter(func(h): return not IDEAS.get(h, []).is_empty())
	# shuffle (Fisher–Yates with our rng: deterministic under a seed)
	for i in range(heroes.size() - 1, 0, -1):
		var j: = rng.randi_range(0, i)
		var t = heroes[i]
		heroes[i] = heroes[j]
		heroes[j] = t
	var out: = []
	var k: = 0
	while out.size() < n and k < n * 4:
		var h: String = heroes[k % heroes.size()]
		var arr: Array = IDEAS.get(h, [])
		var nick: String = arr[rng.randi_range(0, arr.size() - 1)]
		if out.filter(func(x): return x.nick == nick).is_empty():
			out.append({"nick": nick, "hero": h})
		k += 1
	return out
