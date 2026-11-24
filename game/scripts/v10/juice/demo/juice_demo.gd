extends Control

# V10Juice showcase. Two mock screens («Чайная» with a heroine and a premium button, «Партия» with a tile board,
# HUD strip and ult button), a coin / gem counter and a panel with a button per effect, plus the «Эффекты» level
# switch (full / mid / min). Run:
#   godot --path game res://scripts/v10/juice/demo/juice_demo.tscn
#   … -- --juice_showcase=1        scripted 30 s showcase that quits at the end (for --write-movie)
#   … -- --juice_level=mid|min     start at another «Эффекты» level
#   … -- --juice_shots=<dir>       with the showcase: save a PNG every 0.5 s into <dir>
#   … -- --juice_selftest=1        V10JuiceSelftest (headless ok), prints «JUICE SELFTEST ok/total»

const TILE: = Vector2(84, 87)
const BOARD: = Rect2(40, 330, 640, 470)
const STRIP: = Rect2(0, 190, 720, 130)

var vs: = Vector2(720, 1280)
var home: Control
var play: Control
var cur_screen: = "home"
var tiles: Array = []
var hero: TextureRect
var buy_btn: Control
var ult_btn: Control
var chest: TextureRect
var coin_l: Label
var gem_l: Label
var coin_box: Control
var gem_box: Control
var coins: = 1250
var gems: = 340
var combo: = 0
var aura: Node
var beat: Node
var idle: Node
var panel: Control
var level_l: Label
var showcase: = false
var shots_dir: = ""
var shot_t: = 0.0
var shot_i: = 0
var selftest: = false


func _ready() -> void:
	vs = get_viewport().get_visible_rect().size
	size = vs
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--juice_showcase"):
			showcase = true
		elif a.begins_with("--juice_level="):
			V10Juice.forced_level = a.get_slice("=", 1)
		elif a.begins_with("--juice_selftest"):
			selftest = true
		elif a.begins_with("--juice_shots="):
			shots_dir = a.get_slice("=", 1)
	V10Juice.warm()
	_build_home()
	_build_play()
	_build_hud()
	_build_panel()
	play.visible = false
	if selftest:
		V10JuiceSelftest.run(self)
		return
	if showcase:
		panel.visible = false
		_run_showcase()
	else:
		get_tree().create_timer(0.3).timeout.connect(func(): V10Juice.heroine_entrance(hero, "right"))


func _process(dt: float) -> void:
	if shots_dir == "":
		return
	shot_t += dt
	if shot_t >= 0.5:
		shot_t = 0.0
		var img: = get_viewport().get_texture().get_image()
		img.save_png("%s/f%03d.png" % [shots_dir, shot_i])
		shot_i += 1


# ── mock screens ─────────────────────────────────────────────────────────────────────────────────────────────

func _bg(parent: Control, path: String, dim: float) -> void:
	var t: = TextureRect.new()
	t.texture = load(path)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	t.size = vs
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(t)
	var d: = ColorRect.new()
	d.color = Color(0.05, 0.04, 0.06, dim)
	d.size = vs
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(d)


func _build_home() -> void:
	home = Control.new()
	home.size = vs
	home.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(home)
	_bg(home, "res://assets/bg/bg_teahouse.webp", 0.35)
	hero = TextureRect.new()
	hero.texture = load("res://assets/hero/hana.png")
	hero.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hero.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hero.size = Vector2(560, 835)
	hero.position = Vector2(80, 150)
	hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	home.add_child(hero)
	var cap: = UI.label("Чайная", 40, Color("f6e2b0"), Color(0.1, 0.05, 0.04), 6, "title", 900)
	cap.position = Vector2(0, 110)
	cap.size = Vector2(vs.x, 60)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	home.add_child(cap)
	buy_btn = _img_button(home, "res://assets/v08/ui/btn/primary.png", Rect2(170, 990, 380, 126), "Призыв ×10", func(): _do_chest())
	chest = TextureRect.new()
	chest.texture = load("res://assets/v08/ui/misc/chest_closed.png")
	chest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	chest.size = Vector2(150, 150)
	chest.position = Vector2(540, 820)
	chest.pivot_offset = chest.size * 0.5
	chest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	home.add_child(chest)
	idle = V10Juice.idle_sparkle(buy_btn, Color(1.0, 0.82, 0.45), 2.4, 40.0)


func _build_play() -> void:
	play = Control.new()
	play.size = vs
	play.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(play)
	_bg(play, "res://assets/bg/play.webp", 0.45)
	var felt: = ColorRect.new()
	felt.color = Color(0.09, 0.16, 0.13, 0.92)
	felt.position = BOARD.position
	felt.size = BOARD.size
	play.add_child(felt)
	var hint: = UI.label("HUD: серия и баннеры живут здесь", 18, Color("b3a89c"))
	hint.position = STRIP.position + Vector2(0, STRIP.size.y - 28)
	hint.size = Vector2(vs.x, 24)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	play.add_child(hint)
	var faces: = [0, 1, 7, 9, 15, 17, 24, 25, 29, 34, 3, 12, 20, 26, 31, 5, 8, 18, 23, 33, 2, 11, 21, 30]
	var cols: = 7
	var gap: = Vector2(4, 6)
	var origin: = BOARD.position + Vector2((BOARD.size.x - cols * (TILE.x + gap.x)) * 0.5, 22)
	for i in 28:
		var f: int = faces[i % faces.size()]
		var t: = TextureRect.new()
		t.texture = load("res://assets/tiles/%02d_%s.png" % [f, _face_name(f)])
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.size = TILE
		t.pivot_offset = TILE * 0.5
		t.position = origin + Vector2((i % cols) * (TILE.x + gap.x), (i / cols) * (TILE.y + gap.y))
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		t.set_meta("face", f)
		play.add_child(t)
		tiles.append(t)
	ult_btn = _img_button(play, "res://assets/v08/ui/btn/primary_red.png", Rect2(220, 860, 280, 92), "Ульта", func(): _toggle_ult())


func _face_name(f: int) -> String:
	var names: = ["sakura", "plum", "chrysanthemum", "sunflower", "tulip", "clover", "maple", "moon", "star", "sun",
		"rainbow", "snowflake", "fire", "water", "lightning", "dango", "cake", "strawberry", "peach", "cherry", "lemon",
		"matcha", "bubbletea", "bow", "diamond", "crown", "bell", "windchime", "lantern", "cat", "rabbit", "fox",
		"panda", "dragon", "koi", "butterfly"]
	return names[f]


func _img_button(parent: Control, tex: String, r: Rect2, text: String, cb: Callable) -> Control:
	var c: = TextureRect.new()
	c.texture = load(tex)
	c.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	c.position = r.position
	c.size = r.size
	c.pivot_offset = r.size * 0.5
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(c)
	var l: = UI.label(text, 30, Color("fff4e0"), Color(0.25, 0.08, 0.06), 5, "title", 900)
	l.size = r.size
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	c.add_child(l)
	c.gui_input.connect(func(e):
		if (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and e.pressed):
			V9Feel.press(c)
			cb.call())
	return c


func _build_hud() -> void:
	var bar: = ColorRect.new()
	bar.color = Color(0.06, 0.05, 0.07, 0.75)
	bar.size = Vector2(vs.x, 96)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)
	coin_box = _counter(Rect2(20, 20, 220, 60), "coin")
	coin_l = coin_box.get_meta("label")
	coin_l.text = str(coins)
	gem_box = _counter(Rect2(vs.x - 240, 20, 220, 60), "gem")
	gem_l = gem_box.get_meta("label")
	gem_l.text = str(gems)


func _counter(r: Rect2, kind: String) -> Control:
	var c: = Control.new()
	c.position = r.position
	c.size = r.size
	c.pivot_offset = r.size * 0.5
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	var plate: = ColorRect.new()
	plate.color = Color(0.13, 0.11, 0.14, 0.95)
	plate.size = r.size
	c.add_child(plate)
	var ic: = TextureRect.new()
	ic.texture = V10Juice.icon_tex(kind)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.size = Vector2(54, 54)
	ic.position = Vector2(4, 3)
	c.add_child(ic)
	var l: = UI.label("0", 30, Color("f6e2b0"), Color(0.08, 0.05, 0.04), 4, "body", 900)
	l.position = Vector2(64, 0)
	l.size = Vector2(r.size.x - 72, r.size.y)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.pivot_offset = l.size * 0.5
	c.add_child(l)
	c.set_meta("label", l)
	return c


func _build_panel() -> void:
	panel = Control.new()
	panel.position = Vector2(0, vs.y - 270)
	panel.size = Vector2(vs.x, 270)
	add_child(panel)
	var bg: = ColorRect.new()
	bg.color = Color(0.04, 0.035, 0.05, 0.88)
	bg.size = panel.size
	panel.add_child(bg)
	var items: = [
		["Тушь", func(): _go("auto_ink")], ["Фонарь", func(): _go("lantern")], ["Лепестки", func(): _go("petal")],
		["Пара", func(): _match(false)], ["Золото", func(): _match(true)], ["×5", func(): V10Juice.combo_milestone(5, STRIP)],
		["×10", func(): V10Juice.combo_milestone(10, STRIP)], ["×20", func(): V10Juice.combo_milestone(20, STRIP)], ["Лихорадка", func(): _toggle_fever()],
		["Ульта", func(): _toggle_ult()], ["Монеты", func(): _coins()], ["Кристаллы", func(): _gems()],
		["Сундук", func(): _do_chest()], ["Ранг", func(): _rank()], ["Героиня", func(): _hero()],
		["Растворить", func(): _dissolve()], ["Блум", func(): _bloom()], ["Уровень", func(): _cycle_level()],
	]
	var cols: = 6
	var w: = (vs.x - 16) / cols
	for i in items.size():
		var r: = Rect2(8 + (i % cols) * w + 3, 10 + (i / cols) * 84, w - 6, 76)
		var b: = ColorRect.new()
		b.color = Color(0.2, 0.17, 0.2, 1)
		b.position = r.position
		b.size = r.size
		b.pivot_offset = r.size * 0.5
		panel.add_child(b)
		var l: = UI.label(items[i][0], 18, Color("f5ead8"))
		l.size = r.size
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		b.add_child(l)
		var cb: Callable = items[i][1]
		b.gui_input.connect(func(e):
			if (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and e.pressed):
				V9Feel.press(b)
				cb.call())
		if items[i][0] == "Уровень":
			level_l = l
	_update_level_label()


func _update_level_label() -> void:
	if level_l:
		level_l.text = "FX: " + V10Juice.level()


# ── actions ──────────────────────────────────────────────────────────────────────────────────────────────────

func _go(style: String) -> void:
	var target: = "play" if cur_screen == "home" else "home"
	var st: = style
	if style == "auto_ink":
		st = "ink"
	var center: = Vector2(-1, -1)
	if st == "lantern":
		center = Vector2(vs.x * 0.5, vs.y * 0.62)
	await V10Juice.cover(st, 0.36, center)
	_set_screen(target)
	V10Juice.reveal(0.45)
	if target == "home":
		V10Juice.heroine_entrance(hero, "right", true, 0.15)


func _set_screen(s: String) -> void:
	cur_screen = s
	home.visible = s == "home"
	play.visible = s == "play"
	if s != "play":
		V10Juice.stop(aura)
		aura = null
		V10Juice.stop(beat)
		beat = null


func _match(gold: bool) -> void:
	if cur_screen != "play":
		_set_screen("play")
	var alive: = tiles.filter(func(t): return is_instance_valid(t) and t.visible)
	if alive.size() < 2:
		for t in tiles:
			t.visible = true
			t.modulate.a = 1.0
			t.scale = Vector2.ONE
		alive = tiles.duplicate()
	var a: TextureRect = alive[randi() % alive.size()]
	var b: TextureRect = alive[randi() % alive.size()]
	while b == a:
		b = alive[randi() % alive.size()]
	var meet: = (a.position + b.position) * 0.5 + TILE * 0.5 + Vector2(0, -10)
	combo += 1
	var face: int = a.get_meta("face")
	for t in [a, b]:
		var tw: Tween = (t as Control).create_tween().set_parallel()
		tw.tween_property(t, "position", meet - TILE * 0.5, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(t, "scale", Vector2(1.1, 1.1), 0.16)
		tw.chain().tween_callback(func(): t.visible = false)
	get_tree().create_timer(0.16).timeout.connect(func():
		V9Feel.tile_match(combo, gold)
		V10Juice.tile_match(play.get_global_transform() * meet, face, combo, gold)
		if V10Juice.is_milestone(combo):
			V10Juice.combo_milestone(combo, STRIP))


func _toggle_fever() -> void:
	if cur_screen != "play":
		_set_screen("play")
	if aura and is_instance_valid(aura):
		V10Juice.stop(aura)
		aura = null
		return
	aura = V10Juice.fever_aura(play, BOARD)


func _toggle_ult() -> void:
	if beat and is_instance_valid(beat):
		V10Juice.stop(beat)
		beat = null
		return
	if cur_screen != "play":
		_set_screen("play")
	beat = V10Juice.ult_ready(ult_btn, Color(1.0, 0.35, 0.5), Color(1.0, 0.8, 0.45), true)


func _coins() -> void:
	var from: = BOARD.get_center() if cur_screen == "play" else chest.get_global_rect().get_center()
	var start: = coins
	coins += 500
	V10Juice.fountain(from, coin_box, "coin", 12, Callable(), func(): V10Juice.roll(coin_l, start, coins, 0.8))


func _gems() -> void:
	# the reward rises from its source (the chest / the board), never from over the heroine
	var from: = BOARD.get_center() if cur_screen == "play" else chest.get_global_rect().get_center()
	var start: = gems
	gems += 120
	V10Juice.fountain(from, gem_box, "gem", 8, Callable(), func(): V10Juice.roll(gem_l, start, gems, 0.7))


func _do_chest() -> void:
	if cur_screen != "home":
		_set_screen("home")
	chest.texture = load("res://assets/v08/ui/misc/chest_closed.png")
	V10Juice.chest_open(chest, "SSR", func():
		chest.texture = load("res://assets/v08/ui/misc/chest_open.png")
		var start: = coins
		coins += 300
		get_tree().create_timer(0.5).timeout.connect(func():
			V10Juice.fountain(chest.get_global_rect().get_center(), coin_box, "coin", 10, Callable(), func(): V10Juice.roll(coin_l, start, coins, 0.7))))


func _rank() -> void:
	V10Juice.crest_reveal(load("res://assets/v08/ui/rank/dragon.png"), "Ранг: Дракон", "Новый ранг лиги — награды сезона выросли", Color(1.0, 0.78, 0.4), 1.6)


func _hero() -> void:
	if cur_screen != "home":
		_set_screen("home")
	V10Juice.heroine_entrance(hero, "right")


func _dissolve() -> void:
	if cur_screen != "home":
		_set_screen("home")
	V10Juice.dissolve(hero, 0.8, false, Color(0.86, 0.32, 0.16), func():
		get_tree().create_timer(0.25).timeout.connect(func():
			hero.modulate.a = 1.0
			V10Juice.dissolve(hero, 0.8, true)))


func _bloom() -> void:
	if cur_screen != "home":
		_set_screen("home")
	var m: = V10Juice.mat("juice_bloom_fake", {"threshold": 0.62, "intensity": 0.0, "spread": 5.0, "cap": 0.16})
	hero.material = m
	var t: = hero.create_tween()
	t.tween_method(func(v): m.set_shader_parameter("intensity", v), 0.0, 0.6, 0.5)
	t.tween_interval(1.2)
	t.tween_method(func(v): m.set_shader_parameter("intensity", v), 0.6, 0.0, 0.5)
	t.tween_callback(func(): hero.material = null)


func _cycle_level() -> void:
	var order: = ["full", "mid", "min"]
	V10Juice.forced_level = order[(order.find(V10Juice.level()) + 1) % 3]
	_update_level_label()
	if idle and is_instance_valid(idle):
		idle.queue_free()
	idle = V10Juice.idle_sparkle(buy_btn, Color(1.0, 0.82, 0.45), 2.4, 40.0)


# ── 30 s scripted showcase ───────────────────────────────────────────────────────────────────────────────────

func _at(t: float, f: Callable) -> void:
	get_tree().create_timer(t).timeout.connect(f)


func _run_showcase() -> void:
	_at(0.3, func(): V10Juice.heroine_entrance(hero, "right"))
	_at(1.6, func(): _bloom())
	_at(4.2, func(): _go("lantern"))
	for i in 4:
		_at(5.6 + i * 0.45, func(): _match(false))
	_at(7.5, func(): _match(true))
	_at(8.4, func(): _toggle_fever())
	for i in 4:
		_at(9.0 + i * 0.4, func(): _match(i == 2))
	_at(10.9, func(): _toggle_ult())
	_at(11.6, func():
		combo = 9
		_match(false))
	_at(12.8, func(): _coins())
	_at(14.6, func(): _toggle_fever())
	_at(15.0, func():
		combo = 19
		_match(true))
	_at(16.6, func(): _go("auto_ink"))
	_at(18.2, func(): _do_chest())
	_at(21.0, func(): _gems())
	_at(22.6, func(): _rank())
	_at(26.6, func(): _dissolve())
	_at(28.6, func(): _go("petal"))
	_at(30.6, func(): get_tree().quit())
