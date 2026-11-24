class_name V10Legend
extends RefCounted

# «Фишки» — how to read the table, with tiny live demos built from real tiles (same shaders as the board):
#   1. Какую фишку можно взять — the free rule animated: a tile on top goes, then a side neighbour goes, the middle
#      one lights up («сверху пусто и открыт хотя бы один бок»).
#   2. Пары и лоток — two same pictures meet in the tray and vanish; a different one waits.
#   3. Масти — the five suits with their corner marks and every picture of each suit, small vs «крупные символы».
#   4. Особые фишки — gold, рубашка (flips in the demo), тайная, замок и ключ, цепь, джокер, хлопушка, подарок, портрет.
# Footer: «Показать на столе» (in a match: the next tap on a tile shows its card) and «Словарь».

static func open(host: Node) -> V10Sheet:
	var s: = V10Sheet.make(host, "Фишки", true)
	var cw: = s.cw
	s.section("Какую фишку можно взять")
	s.list.add_child(FreeDemo.new().setup(cw))
	s.para("Фишка свободна, если сверху на ней пусто и открыт хотя бы один бок — левый или правый. Свободные светлые, зажатые — тусклые.", 19)
	s.section("Пары и лоток")
	s.list.add_child(PairDemo.new().setup(cw))
	s.para("Взятая фишка едет в лоток. Две ОДИНАКОВЫЕ картинки в лотке исчезают. Другие масти и похожие картинки парой не считаются. Лоток заполнился — партия проиграна, если не спасти. Держи одно место свободным.", 19)
	s.section("Масти: цветной уголок")
	s.para("В правом нижнем углу — цветной уголок: цвет и значок масти. Уголок пару НЕ задаёт: пара — только одинаковая картинка. Зачем он: три пары одной масти подряд — бонус «Тройка».", 18, Color("d9cdbf"))
	for c in G.CATS.size():
		s.list.add_child(_suit_row(c, cw))
	s.list.add_child(_size_demo(cw))
	s.section("Особые фишки")
	for id in ["state.gold", "state.flip", "state.secret", "special.lock", "special.chain", "special.joker", "special.bomb", "special.gift", "state.shard"]:
		var row: = s.entry_row(V10Glossary.get_entry(id))
		if id == "state.flip":
			_animate_flip(row)
	s.para("А ещё на столах прячутся секреты — например, пара с крошечной искоркой. Найдёшь?", 18, Color("d9cdbf"))
	# footer
	var vs: = s.size
	var y: = vs.y - 112.0
	var in_match: bool = V10TileInfo.active != null and is_instance_valid(V10TileInfo.active) and V10TileInfo.active.play == host
	var bw: = (s.cw - 16.0) * 0.5
	var x0: = (vs.x - s.cw) * 0.5
	if in_match:
		var b1: = JButton.make("Показать на столе", "pink", Rect2(x0, y, bw, 88), null, 22)
		b1.pressed.connect(func():
			s.close()
			if V10TileInfo.active:
				V10TileInfo.active.set_lupa(true))
		s.add_child(b1)
		var b2: = JButton.make("Словарь", "lav", Rect2(x0 + bw + 16, y, bw, 88), null, 24)
		b2.pressed.connect(func(): V10GlossaryScreen.open(host, "state"))
		s.add_child(b2)
	else:
		var b3: = JButton.make("Открыть словарь", "pink", Rect2(x0, y, s.cw, 88), null, 24)
		b3.pressed.connect(func(): V10GlossaryScreen.open(host, "state"))
		s.add_child(b3)
	return s

static func _suit_row(c: int, cw: float) -> Control:
	var e: = V10Glossary.get_entry("suit.%d" % c)
	var h: = 92.0
	var row: = UI.rbox("plum", Rect2(0, 0, cw, h), 22, 2, 4)
	row.custom_minimum_size = Vector2(cw, h)
	row.borders(Color(V10Glossary.suit_color(c), 0.8), Color(0, 0, 0, 0.35))
	row.add_child(V10ClarityIcon.make("suit:%d" % c, 64, Vector2(8, 14)))
	var nm: = UI.label(String(e.name), 19, Color("fff2d2"), UI.DARK, 3, "body", 900)
	nm.position = Vector2(76, 12)
	row.add_child(nm)
	var sl: = UI.label(String(e.sub), 15, Color("bfb3a8"), UI.DARK, 2, "body", 800)
	sl.position = Vector2(76, 40)
	sl.size = Vector2(156, 22)
	sl.clip_text = true
	row.add_child(sl)
	var a: = int(G.CATS[c][0])
	var b: = int(G.CATS[c][1])
	var n: = b - a + 1
	var x0: = 236.0
	var step: = minf(52.0, (cw - x0 - 10.0) / n)
	var holder: = Node2D.new()
	row.add_child(holder)
	for i in n:
		var t: = V10ClarityIcon.mini_tile(a + i)
		t.scale = Vector2(0.56, 0.56)
		t.position = Vector2(x0 + step * i + 24.0, h * 0.5)
		holder.add_child(t)
	return row

static func _size_demo(cw: float) -> Control:
	var h: = 150.0
	var row: = UI.rbox("glass", Rect2(0, 0, cw, h), 22, 2, 4)
	row.custom_minimum_size = Vector2(cw, h)
	var holder: = Node2D.new()
	row.add_child(holder)
	var specs: = [[17, 0, "Обычный уголок"], [17, 1, "Крупные символы"]]
	for i in 2:
		var t: = V10ClarityIcon.mini_tile(int(specs[i][0]))
		t.scale = Vector2(1.18, 1.18)
		t.position = Vector2(80 + i * 300, h * 0.5)
		holder.add_child(t)
		var mk: = t.get_node_or_null("V10Marks") as V10TileMarks
		if mk:
			mk.big_override = int(specs[i][1])
			mk.queue_redraw()
		var l: = UI.label(String(specs[i][2]), 19, UI.INK, UI.DARK, 2, "body", 900)
		l.position = Vector2(146 + i * 300, h * 0.5 - 30)
		l.size = Vector2(150, 60)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(l)
	return row

static func _animate_flip(row: Control) -> void:
	var ic: V10ClarityIcon = null
	for c in row.get_children():
		if c is V10ClarityIcon:
			ic = c
	if ic == null:
		return
	var tick: = func():
		if not is_instance_valid(ic):
			return
		var h: = ic.get_node_or_null("Holder")
		if h == null or h.get_child_count() == 0:
			return
		var t: Tile = h.get_child(0)
		if t.back_spr:
			t.crack()
		else:
			t.ice = 1
			t.call("_make_back")
	var tm: = Timer.new()
	tm.wait_time = 1.8
	tm.autostart = true
	tm.timeout.connect(tick)
	row.add_child(tm)


# ── demo 1: the free rule ─────────────────────────────────────────────────────────────────────────────────────────
class FreeDemo extends Control:
	var tiles: = {}
	var cap: Label
	var holder: Node2D
	var cw: = 600.0
	const K: = 1.2

	func setup(w: float) -> Control:
		cw = w
		custom_minimum_size = Vector2(w, 250)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var bg: = UI.rbox("glass", Rect2(0, 0, w, 250), 22, 2, 4)
		add_child(bg)
		holder = Node2D.new()
		add_child(holder)
		cap = UI.label("", 20, Color("ffe7a6"), UI.DARK, 3, "body", 900)
		cap.position = Vector2(16, 196)
		cap.size = Vector2(w - 32, 44)
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cap.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(cap)
		return self

	func _ready() -> void:
		_reset()
		_cycle()

	func _pos(k: String) -> Vector2:
		var c: = Vector2(cw * 0.5, 108)
		var dx: = 88.0 * K
		match k:
			"A": return c + Vector2(-dx, 0)
			"B": return c
			"C": return c + Vector2(dx, 0)
			"D": return c + Vector2(-10, -40) * K
		return c

	func _reset() -> void:
		for k in tiles:
			if is_instance_valid(tiles[k]):
				tiles[k].queue_free()
		tiles.clear()
		var faces: = {"A": 7, "B": 0, "C": 29, "D": 15}
		for k in ["A", "B", "C", "D"]:
			var t: = V10ClarityIcon.mini_tile(faces[k], "")
			t.scale = Vector2(K, K)
			t.position = _pos(k)
			holder.add_child(t)
			tiles[k] = t
		(tiles.B as Tile).set_free(false, false)
		(tiles.B as Tile).mat.set_shader_parameter("dim", 1.6)
		(tiles.A as Tile).set_free(true, false)
		(tiles.C as Tile).set_free(true, false)
		(tiles.D as Tile).set_free(true, false)
		# a soft shadow under the top tile so it reads as lying ON the middle one
		var sh: = Polygon2D.new()
		var pd: Vector2 = _pos("D") + Vector2(8, 10) * K
		var hw: = 40.0 * K
		var hh: = 42.0 * K
		sh.polygon = PackedVector2Array([pd + Vector2(-hw, -hh), pd + Vector2(hw, -hh), pd + Vector2(hw, hh), pd + Vector2(-hw, hh)])
		sh.color = Color(0.05, 0.02, 0.06, 0.35)
		holder.add_child(sh)
		holder.move_child(sh, holder.get_child_count() - 2)
		tiles["shadow"] = sh

	func _say(s: String, col: = Color("ffe7a6")) -> void:
		cap.text = s
		cap.label_settings.font_color = col
		cap.modulate.a = 0.0
		create_tween().tween_property(cap, "modulate:a", 1.0, 0.2)

	func _gone(k: String, dir: Vector2) -> void:
		var t: Tile = tiles[k]
		var tw: = t.create_tween().set_parallel()
		tw.tween_property(t, "position", t.position + dir, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(t, "modulate:a", 0.0, 0.45)

	func _cycle() -> void:
		var tw: = create_tween().set_loops()
		tw.tween_callback(func():
			_reset()
			_say("Средняя (тусклая) зажата: на ней лежит другая фишка", Color("ffb0a8")))
		tw.tween_interval(1.9)
		tw.tween_callback(func():
			_gone("D", Vector2(0, -60))
			if tiles.has("shadow") and is_instance_valid(tiles.shadow):
				tiles.shadow.create_tween().tween_property(tiles.shadow, "modulate:a", 0.0, 0.3)
			_say("Сверху пусто, но оба бока закрыты — ещё нельзя", Color("ffb0a8")))
		tw.tween_interval(2.0)
		tw.tween_callback(func():
			_gone("A", Vector2(-50, -40))
			var b: Tile = tiles.B
			var m: = b.mat
			b.create_tween().tween_method(func(v): m.set_shader_parameter("dim", v), 1.6, 0.0, 0.35)
			b.shine(0.2)
			_say("Левый бок открыт — бери!", Color("9fe8b0")))
		tw.tween_interval(0.5)
		tw.tween_callback(func():
			var b: Tile = tiles.B
			b.home = b.position
			b.hint(true))
		tw.tween_interval(1.8)


# ── demo 2: pairs in the tray ───────────────────────────────────────────────────────────────────────────────────
class PairDemo extends Control:
	var cw: = 600.0
	var holder: Node2D
	var slots: = []
	var tiles: = []
	var cap: Label
	const K: = 0.9

	func setup(w: float) -> Control:
		cw = w
		custom_minimum_size = Vector2(w, 260)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(UI.rbox("glass", Rect2(0, 0, w, 260), 22, 2, 4))
		var tray: = UI.rbox("plum", Rect2(w * 0.5 - 210, 132, 420, 96), 22, 3, 6)
		tray.borders(Color("ffe7a6"), Color("c58a2c"))
		add_child(tray)
		for i in 4:
			var sl: = UI.rbox("plum", Rect2(12 + i * 101, 8, 92, 80), 14, 1, 2)
			sl.colors(Color(0, 0, 0, 0.35), Color(0, 0, 0, 0.22))
			tray.add_child(sl)
			slots.append(Vector2(w * 0.5 - 210 + 12 + i * 101 + 46, 132 + 48))
		holder = Node2D.new()
		add_child(holder)
		cap = UI.label("", 19, Color("ffe7a6"), UI.DARK, 3, "body", 900)
		cap.position = Vector2(16, 226)
		cap.size = Vector2(w - 32, 32)
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(cap)
		return self

	func _ready() -> void:
		var tw: = create_tween().set_loops()
		tw.tween_callback(_reset)
		tw.tween_interval(0.6)
		tw.tween_callback(func(): _to(0, 0, "Сакура едет в лоток"))
		tw.tween_interval(0.9)
		tw.tween_callback(func(): _to(1, 1, "Луна — другая картинка, ждёт свою пару"))
		tw.tween_interval(1.2)
		tw.tween_callback(func(): _to(2, 2, "Вторая сакура — пара!"))
		tw.tween_interval(0.5)
		tw.tween_callback(_pop)
		tw.tween_interval(1.6)

	func _reset() -> void:
		for t in tiles:
			if is_instance_valid(t):
				t.queue_free()
		tiles.clear()
		var faces: = [0, 7, 0]
		for i in 3:
			var t: = V10ClarityIcon.mini_tile(faces[i])
			t.scale = Vector2(K, K)
			t.position = Vector2(cw * 0.5 - 130 + i * 130, 62)
			holder.add_child(t)
			tiles.append(t)
		cap.text = "Тапни свободную фишку"

	func _to(i: int, slot: int, say: String) -> void:
		var t: Tile = tiles[i]
		t.press_glint()
		t.fly_to(slots[slot], 0.88, 0.32, true)
		var c: = [cap]
		get_tree().create_timer(0.34).timeout.connect(func():
			if is_instance_valid(c[0]):
				(c[0] as Label).text = say)

	func _pop() -> void:
		for i in [0, 2]:
			var t: Tile = tiles[i]
			var tw: = t.create_tween()
			tw.tween_property(t, "scale", Vector2(1.15, 1.15), 0.12)
			tw.tween_property(t, "scale", Vector2(0.2, 0.2), 0.2)
			tw.parallel().tween_property(t, "modulate:a", 0.0, 0.2)
		Fx.burst(self, (slots[0] + slots[2]) * 0.5, "sparkle", 18, Color(1, 0.88, 0.5), 0.9)
		var moon: Tile = tiles[1]
		moon.fly_to(slots[0], 0.88, 0.3, false)
		cap.text = "Пара исчезла, лоток снова свободен"
