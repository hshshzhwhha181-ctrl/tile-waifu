class_name V10MjKoikoiBook
extends RefCounted

# «Книга комбинаций Коикои»: 12 страниц = 12 комбинаций. На странице — кадр-поза героини (ключи POSES.md §0.5),
# название (простое) + оригинал мелко, очки, «как собрать» и пример карт. Страница открывается первой сборкой.
# Кадры: res://assets/v10/mj/koikoi/book/<yaku>.webp (если есть), иначе арт героини из assets/hero/<id>.png.

const PAGES: = [
	{"id": "goko", "hero": "mc", "pose": "mc.win", "key": "table-slam-flourish", "how": "Все 5 светлых карт", "cards": ["crane", "curtain", "moon", "rain", "phoenix"]},
	{"id": "shiko", "hero": "rin", "pose": "rin.win", "key": "formal-half-bow-parallel", "how": "4 светлые карты без Дождя", "cards": ["crane", "curtain", "moon", "phoenix"]},
	{"id": "ameshiko", "hero": "nova", "pose": "nova.tease", "key": "cable-hang-heart-lure", "how": "4 светлые карты вместе с Дождём", "cards": ["crane", "curtain", "moon", "rain"]},
	{"id": "sanko", "hero": "yue", "pose": "yue.idle", "key": "fan-at-lips-s-curve", "how": "3 светлые карты без Дождя", "cards": ["crane", "curtain", "moon"]},
	{"id": "inoshikacho", "hero": "hana", "pose": "hana.select", "key": "lunge-high-five", "how": "Кабан, олень и бабочки", "cards": ["boar", "deer", "butterfly"]},
	{"id": "akatan", "hero": "mc", "pose": "mc.select", "key": "wide-side-stance-tile-flick", "how": "3 красные ленты с узором", "cards": ["poem"]},
	{"id": "aotan", "hero": "nova", "pose": "nova.select", "key": "bike-sidesaddle-knees-together", "how": "3 синие ленты", "cards": ["blue"]},
	{"id": "tan", "hero": "rin", "pose": "rin.tease", "key": "slide-bowl-over-glasses", "how": "5 лент любых; каждая следующая +1", "cards": []},
	{"id": "tane", "hero": "hana", "pose": "hana.idle", "key": "one-leg-quad-stretch", "how": "5 животных; каждое следующее +1", "cards": []},
	{"id": "kasu", "hero": "nova", "pose": "nova.idle", "key": "air-typing-slouch", "how": "10 пустых; каждая следующая +1", "cards": []},
	{"id": "hanami", "hero": "mc", "pose": "mc.tease", "key": "armrest-perch-tile-shh", "how": "Занавес вишни и чаша", "cards": ["curtain", "cup"]},
	{"id": "tsukimi", "hero": "yue", "pose": "yue.select", "key": "water-sleeve-spiral", "how": "Луна и чаша", "cards": ["moon", "cup"]},
]

static func page(id: String) -> Dictionary:
	for p in PAGES:
		if p.id == id:
			return p
	return {}

static func pages(d: Dictionary) -> Array:
	var out: = []
	for p in PAGES:
		var e: Dictionary = p.duplicate()
		e["name"] = V10MjKoikoi.YAKU[p.id].name
		e["orig"] = V10MjKoikoi.YAKU[p.id].orig
		e["pts"] = V10MjKoikoi.YAKU[p.id].pts
		e["count"] = int(d.book.get(p.id, 0))
		e["open"] = e.count > 0
		e["art"] = art_path(p)
		out.append(e)
	return out

static func art_path(p: Dictionary) -> String:
	var own: = "res://assets/v10/mj/koikoi/book/%s.webp" % p.id
	if ResourceLoader.exists(own):
		return own
	return "res://assets/hero/%s.png" % p.hero

static func filled(d: Dictionary) -> int:
	var n: = 0
	for p in PAGES:
		if int(d.book.get(p.id, 0)) > 0:
			n += 1
	return n
