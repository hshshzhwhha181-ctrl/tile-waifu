class_name V7Passives
extends RefCounted






const DATA: = {
	"mc": {
		"name": "Пятый ветер", 
		"desc": "В лотке пять мест вместо четырёх.", 
		"long": "Хозяйка «Пяти ветров» держит для тебя пятое место в лотке. Ошибиться можно на одну фишку больше.", 
		"good": "сложные столы", 
		"col": Color("ff8fb8"), 
	}, 
	"rin": {
		"name": "Чайная церемония", 
		"desc": "Тапни фишку в лотке, и она вернётся на стол. Чашка за каждые 4 пары.", 
		"long": "Рин не торопится: фишку из лотка можно вернуть на её место, пока есть чашка чая. Одна чашка с начала, ещё одна за каждые 4 пары, не больше двух.", 
		"good": "много разных фишек", 
		"col": Color("b48cff"), 
	}, 
	"hana": {
		"name": "Эстафета", 
		"desc": "Пока горит комбо ×2, каждая вторая фишка сама зовёт свою свободную пару.", 
		"long": "Хана передаёт палочку: пока держится комбо ×2 и выше, каждая вторая фишка, ушедшая в лоток, сама приводит свою свободную пару со стола.", 
		"good": "открытые столы, Блиц, дуэль", 
		"col": Color("ffb35c"), 
	}, 
	"yue": {
		"name": "Лунный взгляд", 
		"desc": "Видит пару фишки из лотка сквозь стол и открывает закрытую фишку каждые 3 пары.", 
		"long": "Юэ видит сквозь фишки: пара того, что лежит в лотке, светится даже под завалом. Одну закрытую фишку она открывает сразу, ещё одну за каждые 3 пары.", 
		"good": "закрытые и тайные фишки", 
		"col": Color("8fb4ff"), 
	}, 
	"nova": {
		"name": "Бэкдор", 
		"desc": "Каждые 5 пар одна заваленная фишка становится доступной.", 
		"long": "Нова взламывает стол: каждые 5 пар одна фишка из-под завала получает доступ, её можно взять, хотя сверху лежат другие.", 
		"good": "высокие башни и боссы", 
		"col": Color("4fe3ff"), 
	}, 
}

const RIN_EVERY: = 4
const RIN_MAX: = 2
const YUE_EVERY: = 3
const NOVA_EVERY: = 5
const HANA_COMBO: = 2

static func info(h: String) -> Dictionary:
	return DATA.get(h, DATA.mc)


static func slots(h: String, base: int) -> int:
	if h == "mc" and base < 6:
		return base + 1
	return base


static func fit(h: String, lv: Dictionary) -> int:
	var layers: = int(lv.get("layers", 3))
	var hidden: bool = lv.get("hidden", false)
	var ice: = int(lv.get("ice", 0))
	var hard: = int(lv.get("hard", 0))
	var faces: = int(lv.get("faces", 10))
	match h:
		"mc":
			return 2 + hard * 2
		"rin":
			return 1 + (2 if faces >= 15 else 0) + (1 if faces >= 17 else 0)
		"hana":
			return (3 if layers <= 3 else 1) + (1 if int(lv.get("gold", 0)) > 0 else 0) - (2 if hidden or ice > 0 else 0)
		"yue":
			return (3 if hidden else 0) + (2 if ice > 0 else 0)
		"nova":
			return (3 if layers >= 5 else (1 if layers >= 4 else 0)) + (2 if lv.get("boss", false) else 0)
	return 0


static func best_for(lv: Dictionary) -> String:
	var best: = ""
	var best_s: = 2
	for h in G.HERO_ORDER:
		if not G.hero_unlocked(h):
			continue
		var s: = fit(h, lv)
		if s > best_s:
			best_s = s
			best = h
	return best


static func partner_row(row: Control, h: String, lv: Dictionary) -> void :
	var d: = info(h)
	var c: Color = d.col
	var l: = UI.label("Стиль «%s»: %s" % [d.name, d.desc], 15, c.lightened(0.35), UI.DARK, 3, "body", 900)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.label_settings.line_spacing = -3
	l.position = Vector2(132, 104)
	l.size = Vector2(466, 42)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(l)
	if best_for(lv) == h:
		var tag: = UI.rbox("gold", Rect2(296, 16, 146, 30), 15, 2, 6)
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(tag)
		tag.add_child(UI.center_label(UI.label("★ для стола", 15, Color("4a2a06"), Color(1, 1, 1, 0.5), 2, "body", 900), Rect2(0, 0, 146, 30)))
		var tw: = tag.create_tween().set_loops()
		tw.tween_property(tag, "modulate", Color(1.15, 1.1, 0.9), 0.6).set_trans(Tween.TRANS_SINE)
		tw.tween_property(tag, "modulate", Color.WHITE, 0.6).set_trans(Tween.TRANS_SINE)


static func attach(play) -> void :
	if play.has_node("V7PassiveRun"):
		return
	var r: = V7PassiveRun.new()
	r.name = "V7PassiveRun"
	play.add_child(r)
	r.setup(play)
