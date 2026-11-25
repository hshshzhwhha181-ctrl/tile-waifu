class_name V10OddsScreen
extends Control

# V10OddsScreen — «Шансы и правила» (spec Г2, UX_RULES §5.2.5): ONE screen for every random thing.
# Tabs: Шансы · Правила · История. Numbers come only from V10Rates (and V10Sku when it lands).
# Providers (source): "gacha" (this lane: {gacha: V10Gacha2, banner}), "chest" (fixed rewards → «без случайности»,
# rows [{name, text}]), later "hanafuda" (1.0) and "domain" (1.1) register with V10OddsScreen.register(source, fn).
#   V10OddsScreen.open(parent, gacha, banner) -> V10OddsScreen
#   V10OddsScreen.open_args(parent, {source, …}) -> V10OddsScreen       entry from Лавка / Настройки / sheets
#   As a main screen: build(main, {source, id}) (screen id "odds").

const TABS: = ["Шансы", "Правила", "История"]

static var providers: = {}
# «₽» may show only after L8 (UX_RULES §3.5, С-2). The integrator points this at the Ф7 / V10Meta check (hook H10);
# until then: Path level 8 cleared (S.unlocked counts the open levels: ≥ 9 after L8).
static var rub_ok_fn: Callable = Callable()


static func rub_ok() -> bool:
	if rub_ok_fn.is_valid():
		return bool(rub_ok_fn.call())
	return int(G.S.get("unlocked", 0)) >= 9

var gacha: V10Gacha2
var banner: Dictionary = {}
var args: Dictionary = {}
var tab: = 0
var body: Control
var tab_nodes: = []
var hist_filter: = ""
var W: = 720.0
var H: = 1280.0


static func register(source: String, fn: Callable) -> void:
	providers[source] = fn


static func open(parent: Control, g: V10Gacha2, b: Dictionary) -> V10OddsScreen:
	return open_args(parent, {"source": "gacha", "gacha": g, "banner": b})


static func open_args(parent: Control, a: Dictionary) -> V10OddsScreen:
	var s: = V10OddsScreen.new()
	s.size = parent.get_viewport_rect().size
	parent.add_child(s)
	s._setup(a)
	return s


func build(_m, a: Dictionary) -> void:
	_setup(a)


func _setup(a: Dictionary) -> void:
	args = a
	W = size.x
	H = size.y
	mouse_filter = Control.MOUSE_FILTER_STOP
	gacha = a.get("gacha", null)
	if gacha == null and String(a.get("source", "gacha")) == "gacha":
		gacha = V10WishScreen.make_gacha()
	banner = a.get("banner", {})
	if banner.is_empty() and gacha != null:
		var bl: = gacha.banners()
		banner = bl[0]
		for b in bl:
			if String(b.id) == String(a.get("id", "")):
				banner = b
	var bg: = ColorRect.new()
	bg.size = size
	bg.color = V10GUI.NIGHT_900
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var ol: = V10GUI.overline("ⓘ  " + _source_name(), V10GUI.GOLD_500)
	ol.position = Vector2(32, 44)
	add_child(ol)
	var t: = V10GUI.h1("Шансы и правила", 44)
	t.position = Vector2(30, 66)
	add_child(t)
	# a quiet ✕ (UX_RULES §6.5): no medallion, a glyph in an 80 px hit zone
	add_child(V10GUI.quiet_icon("✕", Vector2(W - 104, 40), close))
	_set_tab(int(a.get("tab", 0)))
	modulate.a = 0.0
	position.y = 24
	var tn: = create_tween().set_parallel()
	tn.tween_property(self, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tn.tween_property(self, "position:y", 0.0, 0.22).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)


func _source_name() -> String:
	match String(args.get("source", "gacha")):
		"chest":
			return "сундуки"
	return "Желания · " + String(banner.get("name", ""))


func close() -> void:
	var t: = create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.18)
	t.tween_callback(queue_free)


func _set_tab(i: int) -> void:
	tab = i
	# segmented tabs: the chosen one in gold with an underline (the 0.9 art buttons drew all three alike)
	for n in tab_nodes:
		if is_instance_valid(n):
			n.queue_free()
	tab_nodes.clear()
	if String(args.get("source", "gacha")) != "chest":
		var seg: = V10GUI.segment(TABS, i, Rect2(24, 140, W - 48, 80), func(k): _set_tab(k))
		add_child(seg)
		tab_nodes.append(seg)
	if is_instance_valid(body):
		body.queue_free()
	var sc: = ScrollContainer.new()
	sc.position = Vector2(0, 232)
	sc.size = Vector2(W, H - 232)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(sc)
	body = sc
	var list: = Control.new()
	list.custom_minimum_size = Vector2(W, 10)
	sc.add_child(list)
	var y: = 0.0
	match String(args.get("source", "gacha")):
		"chest":
			y = _chest(list)
		_:
			match i:
				0: y = _odds(list)
				1: y = _rules(list)
				2: y = _history(list)
	list.custom_minimum_size = Vector2(W, y + 60)
	list.modulate.a = 0.0
	list.create_tween().tween_property(list, "modulate:a", 1.0, 0.2)


func _row(list: Control, y: float, cols: Array, sizes: Array, colors: Array, xs: Array, weight: = 800) -> float:
	var h: = 0.0
	for k in cols.size():
		var l: = V10GUI.lbl(String(cols[k]), int(sizes[k]), colors[k], "body", weight)
		# (a Label's position is set after autowrap + size, or it keeps its one-line width)
		if k > 0:
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			l.size = Vector2(130, 10)
			l.position = Vector2(xs[k] - 130, y)
		else:
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.size = Vector2(W * 0.5, 10)
			l.position = Vector2(xs[k], y)
		list.add_child(l)
		h = maxf(h, l.get_minimum_size().y)
	return y + h


func _odds(list: Control) -> float:
	var y: = 12.0
	var xs: = [32.0, W - 186.0, W - 32.0]
	y = _row(list, y, ["Редкость", "Базовый", "Итоговый"], [18, 18, 18], [V10GUI.PAPER_500, V10GUI.PAPER_500, V10GUI.PAPER_500], xs) + 10
	for s in V10Rates.summary_lines():
		var col: Color = V10GUI.RAR[s.rar]
		y = _row(list, y, [s.rar, V10Rates.pct(s.base), V10Rates.pct(s.total)], [26, 24, 24], [col, V10GUI.PAPER_100, V10GUI.PAPER_100], xs, 900) + 10
	var note: = V10GUI.lbl("Итоговый шанс учитывает, что SSR приходит не позже 60-го желания и S или выше — хотя бы раз в 10 желаний. Редкость — это сколько косметики у наряда, силы в рейтинге она не даёт.", 18, V10GUI.PAPER_500, "body", 700)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.size = Vector2(W - 64, 10)
	note.position = Vector2(32, y + 4)
	list.add_child(note)
	y += note.get_minimum_size().y + 28
	if gacha == null:
		return y
	var rows: = gacha.odds(banner)
	var cur_rar: = ""
	for r in rows:
		if String(r.rar) != cur_rar:
			cur_rar = String(r.rar)
			var line: = ColorRect.new()
			line.color = Color(V10GUI.GOLD_700, 0.35)
			line.position = Vector2(32, y)
			line.size = Vector2(W - 64, 1)
			list.add_child(line)
			var ol: = V10GUI.overline("редкость " + cur_rar, V10GUI.RAR[cur_rar])
			ol.position = Vector2(32, y + 12)
			list.add_child(ol)
			y += 44
		var it: Dictionary = G.ITEM.get(String(r.id), {})
		var name: = String(it.get("name", r.id))
		if it.has("hero"):
			name = "%s · %s" % [G.HEROES[it.hero].name, name]
		var f: bool = r.featured
		var col: = V10GUI.GOLD_300 if f else V10GUI.PAPER_100
		y = _row(list, y, [name + (" · баннер" if f else ""), V10Rates.pct(r.base), V10Rates.pct(r.total)], [20, 20, 20], [col, col, col], xs, 800 if not f else 900) + 10
	return y


func _rules(list: Control) -> float:
	var y: = 12.0
	var items: = [
		["SSR — не позже 60-го желания", "С 46-го желания без SSR шанс растёт на 6 % за каждое. Счётчик общий для всех фаз Луны и переходит из фазы в фазу; у «Пяти ветров» и «Первого гостя» свой."],
		["Половина шансов, что SSR — героиня баннера", "Если выпала другая SSR, следующая SSR на баннере фазы — точно героиня баннера. В «Полнолунии» героиню выбираешь сам: «Цель желания» меняется бесплатно и обещание не сбрасывает."],
		["S или выше — хотя бы раз в 10 желаний", "Три S баннера фазы получают половину всех выпадений S."],
		["Свеча желаний", "Каждое желание на любом баннере, и за билет тоже, зажигает свечу. Свечи не сгорают. 200 свечей — любая SSR постоянных желаний или текущей фазы на выбор."],
		["Повторы", "Повторный наряд добавляет звезду Созвездия ✦ (до ✦5, это только косметика). Сверх ✦5 и повторы фишек и фонов дают Лепестки: за 60 Лепестков — звезда Созвездия."],
		["Первый гость", "50 желаний по 120 кристаллов вместо 150, SSR-наряд, которого у тебя нет, — не позже 50-го. Без срока."],
	]
	for it in items:
		var t: = V10GUI.lbl(it[0], 24, V10GUI.PAPER_100, "body", 900)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.size = Vector2(W - 64, 10)
		t.position = Vector2(32, y)
		list.add_child(t)
		y += t.get_minimum_size().y + 4
		var d: = V10GUI.lbl(it[1], 19, V10GUI.PAPER_300, "body", 700)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.size = Vector2(W - 64, 10)
		d.position = Vector2(32, y)
		list.add_child(d)
		y += d.get_minimum_size().y + 22
	var box: = V10GUI.sheet(Rect2(24, y, W - 48, 10), 0.9)
	list.add_child(box)
	var by: = 16.0
	var hl: = V10GUI.overline("худший случай", V10GUI.GOLD_500)
	hl.position = Vector2(18, by)
	box.add_child(hl)
	by += 30
	var rub: = rub_ok()
	for line in V10Rates.worst_lines(rub):
		var l: = V10GUI.lbl(line, 21, V10GUI.GOLD_300, "body", 900)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size = Vector2(W - 84, 10)
		l.position = Vector2(18, by)
		box.add_child(l)
		by += l.get_minimum_size().y + 8
	if rub:
		var pl: = V10GUI.lbl("Расчёт: ≈ %d ₽ за желание по пакету Лунного камня за %s ₽" % [int(round(V10Rates.ref_rub_per_pull())), V10Rates.group(int(V10Rates.REF_PACK_RUB))], 18, V10GUI.PAPER_500, "body", 700)
		pl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		pl.size = Vector2(W - 84, 10)
		pl.position = Vector2(18, by)
		box.add_child(pl)
		by += pl.get_minimum_size().y
	by += 16
	box.size.y = by
	y += by + 24
	var cl: = V10GUI.lbl("Сундуки салона, глав и лестницы возврата — без случайности: что написано, то и внутри.", 18, V10GUI.PAPER_500, "body", 700)
	cl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cl.size = Vector2(W - 64, 10)
	cl.position = Vector2(32, y)
	list.add_child(cl)
	return y + cl.get_minimum_size().y


func _history(list: Control) -> float:
	var y: = 12.0
	if gacha == null:
		return y
	var c: = gacha.history_counts()
	var t: = V10GUI.lbl("SSR: %d · S: %d · A: %d" % [c.SSR, c.S, c.A], 28, V10GUI.PAPER_100, "body", 900)
	t.position = Vector2(32, y)
	list.add_child(t)
	y += 44
	var sub: = V10GUI.lbl("Все желания за 90 дней", 18, V10GUI.PAPER_500, "body", 700)
	sub.position = Vector2(32, y)
	list.add_child(sub)
	y += 40
	var filters: = ["", "SSR", "S", "A"]
	var seg: = V10GUI.segment(["Все", "SSR", "S", "A"], filters.find(hist_filter), Rect2(24, y - 8, 4 * 110, 80), func(k):
		hist_filter = filters[k]
		_set_tab(2))
	list.add_child(seg)
	y += 88
	var h: = gacha.history()
	h.reverse()
	var shown: = 0
	for e in h:
		if hist_filter != "" and String(e.r) != hist_filter:
			continue
		if shown >= 200:
			break
		shown += 1
		var it: Dictionary = G.ITEM.get(String(e.i), {})
		var d: = Time.get_datetime_dict_from_unix_time(int(e.t) + V10GClock.MSK)
		var when: = "%02d.%02d %02d:%02d" % [d.day, d.month, d.hour, d.minute]
		var how: String = {"first": "первая SSR", "candle": "Свеча"}.get(String(e.b), "")
		var name: = String(it.get("name", e.i)) + ("" if how == "" else " · " + how)
		var col: Color = V10GUI.RAR.get(String(e.r), V10GUI.PAPER_100)
		y = _row(list, y, [name, String(e.r), when], [20, 20, 18], [V10GUI.PAPER_100, col, V10GUI.PAPER_500], [32.0, W - 220.0, W - 32.0]) + 12
	if shown == 0:
		var em: = V10GUI.lbl("Пока пусто — загадай первое желание.", 20, V10GUI.PAPER_500, "body", 700)
		em.position = Vector2(32, y)
		list.add_child(em)
		y += 40
	return y


func _chest(list: Control) -> float:
	var y: = 12.0
	var t: = V10GUI.lbl("Без случайности", 28, V10GUI.JADE_300, "body", 900)
	t.position = Vector2(32, y)
	list.add_child(t)
	y += 48
	for r in args.get("rows", []):
		y = _row(list, y, [String(r.get("name", "")), "", String(r.get("text", ""))], [20, 20, 20], [V10GUI.PAPER_100, V10GUI.PAPER_100, V10GUI.GOLD_300], [32.0, W - 200.0, W - 32.0]) + 10
	return y
