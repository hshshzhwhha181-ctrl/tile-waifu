extends Control

# Демо и снимки Коикои (контракт §7.1):
#   xvfb-run -a godot --path game --rendering-driver opengl3 --audio-driver Dummy --resolution 720x1280 \
#     res://scripts/v10/mj/koikoi/koikoi_demo.tscn -- --shots=<dir>
# Снимки: koikoi_table / koikoi_pick / koikoi_decide / koikoi_herkoi / koikoi_tally / koikoi_result (+ _<W>x<H>.png).
# Без --shots: живая партия (ты против Рин), --hero=<id>, --auto=1 — ИИ играет и за тебя.

var shots: = ""
var hero: = "rin"

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots = a.split("=")[1]
		elif a.begins_with("--hero="):
			hero = a.split("=")[1]
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size = get_viewport_rect().size
	if shots == "":
		var s: = V10MjKoikoiScreen.new()
		s.size = size
		s.setup(null, {"hero": hero, "months": 6, "auto": "--auto=1" in OS.get_cmdline_user_args()})
		add_child(s)
		s.finished.connect(func(r): print("KOIKOI finished ", r))
		return
	DirAccess.make_dir_recursive_absolute(shots)
	await _run_shots()
	get_tree().quit(0)

func _snap(name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: = get_viewport().get_texture().get_image()
	var p: = "%s/koikoi_%s_%dx%d.png" % [shots, name, img.get_width(), img.get_height()]
	img.save_png(p)
	print("SHOT ", p)

func _screen(seed_v: int, h: String) -> V10MjKoikoiScreen:
	var s: = V10MjKoikoiScreen.new()
	s.size = size
	s.setup(null, {"hero": h, "months": 6, "seed": seed_v, "music": false, "no_start": true, "dealer": 0})
	add_child(s)
	return s

func _clear() -> void:
	for c in get_children():
		c.queue_free()
	await get_tree().process_frame

func _run_shots() -> void:
	var rng: = RandomNumberGenerator.new()
	rng.seed = 5
	# 1) стол посреди месяца, карта руки поднята, совпадения светятся
	var s: = _screen(4242, hero)
	await get_tree().process_frame
	s.k.next_month()
	s.k.take_events()
	var n: = 0
	while n < 40 and not (s.k.turn == 0 and s.k.phase == "play" and s.k.hand[0].size() <= 6):
		V10MjKoikoiAI.step(s.k, "mc" if s.k.turn == 0 else hero, rng)
		if s.k.phase == "decide":
			s.k.koikoi()
		if s.k.phase == "over":
			s.k.next_month()
		n += 1
	s.k.take_events()
	s.relayout(0.0)
	s._await_input("play")
	for c in s.k.hand[0]:
		if not s.k.matches(c).is_empty():
			s.sel = c
			break
	s.relayout(0.0)
	s._update_match_hl()
	s._say("month", true)
	await get_tree().create_timer(0.5).timeout
	await _snap("table")
	# 2) решение «Забрать / Кои-кои!»: у меня Три света, она смотрит в камеру
	await _clear()
	s = _screen(77, hero)
	await get_tree().process_frame
	var k: = s.k
	k.month_no = 3
	k.totals = [12, 7]
	k.caps = [[V10MjKoikoi.find("crane"), 2, V10MjKoikoi.find("curtain"), 10, V10MjKoikoi.find("moon"), 30, 5, 7, 13, 15], [V10MjKoikoi.find("boar"), 26, 17, 19, 33, 35]]
	k.hand = [[21, 23, 37, 46, 41], [6, 22, 38, 45, 42]]
	k.table = [11, 18, 31, 43, 27, 34, 14]
	k.deck = [0, 1, 3, 4, 8, 9, 12, 16, 20, 27, 28, 29, 32, 34, 36, 39, 40, 44, 47]
	for c in k.caps[0] + k.caps[1] + k.hand[0] + k.hand[1] + k.table:
		k.deck.erase(c)
	k.turn = 0
	k.phase = "decide"
	k.last_yaku[0] = V10MjKoikoi.yaku_of(k.caps[0])
	k.last_score[0] = V10MjKoikoi.score_of(k.last_yaku[0])
	s.relayout(0.0)
	s._show_decision()
	await get_tree().create_timer(0.75).timeout
	await _snap("decide")
	# 3) её «Кои-кои!» — наезд на лицо, мазок туши, ×2 у её счёта
	k.phase = "play"
	if s.sheet:
		s.sheet.queue_free()
		s.sheet = null
	s.awaiting = ""
	k.koi[1] = 1
	s._koikoi_fx({"t": "koikoi", "p": 1, "n": 1})
	await get_tree().create_timer(0.55).timeout
	await _snap("herkoi")
	# 4) итог месяца
	await get_tree().create_timer(1.2).timeout
	await _clear()
	s = _screen(78, hero)
	await get_tree().process_frame
	s.k.month_no = 2
	s.k.caps = [[V10MjKoikoi.find("crane"), V10MjKoikoi.find("curtain"), V10MjKoikoi.find("moon"), 1, 5, 9, 17, 25], []]
	var r: = {"winner": 0, "pts": 10, "base": 5, "yaku": {"sanko": 5}, "mult": 2, "intercept": false, "koi": [1, 0]}
	s.k.totals = [10, 0]
	s.relayout(0.0)
	s._tally(r, false)
	await get_tree().create_timer(0.6).timeout
	await _snap("tally")
	# 5) итог партии: победа, награды, новая карта альбома
	await _clear()
	var d: = V10MjKoikoiSave.st()
	d.skins.erase("crane")
	d.day_win = ""
	s = _screen(79, hero)
	await get_tree().process_frame
	s.k.month_no = 6
	s.k.totals = [38, 21]
	s.k.history = [{"winner": 0, "yaku": {"sanko": 5, "tan": 1}}, {"winner": 1, "yaku": {"tane": 1}}, {"winner": 0, "yaku": {"inoshikacho": 5}}]
	s.relayout(0.0)
	s._show_result()
	await get_tree().create_timer(2.2).timeout
	await _snap("result")
	# 6) живой ход: несколько полных ходов с анимацией (ИИ за обе стороны), проверка, что всё доигрывается
	await _clear()
	var live: = V10MjKoikoiScreen.new()
	live.size = size
	live.setup(null, {"hero": "hana", "months": 1, "seed": 9, "music": false, "auto": true, "fast": 4.0})
	add_child(live)
	var t0: = Time.get_ticks_msec()
	while live.awaiting != "result" and Time.get_ticks_msec() - t0 < 90000:
		await get_tree().create_timer(0.25).timeout
	print("LIVE month finished: ", live.awaiting == "result", " totals ", live.k.totals)
	await _snap("live_end")
