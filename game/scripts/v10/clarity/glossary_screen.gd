class_name V10GlossaryScreen
extends RefCounted

# «Словарь»: every name of the game in three tabs — «Награды» (партия, бонусы, комбо, события, гадание),
# «Фишки» (масти, особые, как читать, все картинки), «Ранги и секреты» (ранги, лиги, умение, секреты).
# A row = icon · clear name · flavour · «за что»; bonuses show how many times they were earned (×N).
# A tap opens the card «За что / Как получить снова». Reached from the victory card («Весь словарь»), the tile
# bubble legend, settings («Фишки и словарь») and — for the tutorial lane — V10GlossaryScreen.open(host, cat).

const TABS: = [
	["Награды", ["win", "bonus", "combo", "event", "fortune"]],
	["Фишки", ["state", "suit", "special", "face"]],
	["Ранги и секреты", ["rank", "league", "ult", "egg"]],
]

static func open(host: Node, cat: = "") -> V10Sheet:
	var s: = V10Sheet.make(host, "Словарь")
	var cur: = 0
	for i in TABS.size():
		if cat in TABS[i][1]:
			cur = i
	var names: = []
	for t in TABS:
		names.append(t[0])
	s.add_tabs(names, cur, func(i): _fill(s, i, ""))
	_fill(s, cur, cat)
	return s

static func _fill(s: V10Sheet, tab: int, focus: String) -> void:
	s.clear_list()
	var focus_node: Control = null
	if tab == 0:
		s.para("Здесь всё, что ты видишь после партии. Нажми на строку — расскажу, за что это дают и как получить снова.", 18, Color("d9cdbf"))
	elif tab == 1:
		s.para("Пара — две ОДИНАКОВЫЕ картинки. Цветной уголок — масть: она нужна для бонуса «Тройка» и коллекции.", 18, Color("d9cdbf"))
	for cat in TABS[tab][1]:
		var sec: = s.section(V10Glossary.cat_title(cat))
		if cat == focus:
			focus_node = sec
		for e in V10Glossary.entries(cat):
			var cnt: = -1
			if cat == "bonus":
				var yk: String = String(e.get("yaku", ""))
				cnt = V10Breakdown.count_for(String(e.id), yk)
			s.entry_row(e, cnt)
	if focus_node:
		var fn: = focus_node
		s.get_tree().process_frame.connect(func():
			if is_instance_valid(fn) and is_instance_valid(s):
				s.scroll.scroll_vertical = int(fn.position.y), CONNECT_ONE_SHOT)
