class_name V10NotifyText
extends RefCounted

# Notification texts (docs/0.10-spec.md Ф1). Warm, short, never a price, never guilt: every line passes V10Lint
# (meta_selftest checks all of them). {name} = heroine name. text_id = "<cat>_<n>".
# The heroine speaks in first person only for her own birthday; the rest is a quiet third-person line.

const TITLES: = {
	"bday": "Чайная «Пять ветров»",
	"comeback": "Чайная «Пять ветров»",
	"salon": "Салон Пяти ветров",
	"feed": "Лента героинь",
}

const LINES: = {
	"bday": [
		"Сегодня мой день рождения. Заглянешь на чашку чая? — {name}",
		"У {name} сегодня праздник: в чайной зажгли фонарики.",
	],
	"comeback": [
		"{name} заварила новый сорт улуна. Чайник ещё тёплый.",
		"В саду распустилась слива. {name} оставила тебе место у окна.",
		"{name} разложила новый стол. Сыграем, когда будет минутка?",
	],
	"salon": [
		"В салоне хватает звёзд на новый уголок.",
		"Фонари у входа ждут реставрации: звёзд уже достаточно.",
	],
	"feed": [
		"{name} поделилась новым снимком в ленте.",
		"{name} написала в ленте про сегодняшний чай.",
	],
}


static func ids(cat: String) -> Array:
	var out: = []
	for i in (LINES.get(cat, []) as Array).size():
		out.append("%s_%d" % [cat, i])
	return out


static func raw(text_id: String) -> String:
	var p: = text_id.rsplit("_", true, 1)
	if p.size() != 2 or not LINES.has(p[0]):
		return ""
	var arr: Array = LINES[p[0]]
	var i: = int(p[1])
	return str(arr[i]) if i >= 0 and i < arr.size() else ""


static func hero_name(h: String) -> String:
	if h == "":
		return "Хозяйка"
	var tree: = Engine.get_main_loop() as SceneTree
	if tree and tree.root.get_node_or_null("G") != null and G.HEROES.has(h):
		return str(G.HEROES[h].name)
	return h.capitalize()


static func text(text_id: String, h: String) -> String:
	return raw(text_id).replace("{name}", hero_name(h))


# a text id for a category picked by a day seed (so the same day never repeats the same line twice in a row)
static func pick(cat: String, seed: int) -> String:
	var all: = ids(cat)
	if all.is_empty():
		return ""
	return all[posmod(seed, all.size())]


static func all_lines() -> Array:
	var out: = []
	for c in LINES:
		for l in LINES[c]:
			out.append(str(l))
	for c in TITLES:
		out.append(str(TITLES[c]))
	return out
