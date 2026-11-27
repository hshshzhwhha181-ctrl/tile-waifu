class_name V6StoryScene
extends Control


const EMO: = {"happy": "happy", "big": "big", "sad": "sad", "tap": "tap", "shy": "tap"}

const EMO_TAG: = {"happy": "happy", "sad": "sad", "shy": "shy", "pout": "pout", "surprised": "surprised"}
const EMO_CUES: = [
	["surprised", ["?!", "!?", "Ой!", "Ой,", "Ах!", "Неужели", "Не может быть", "Вот это да"]],
	["pout", ["Хм", "Не смотри", "Не пойми неправильно", "Опять", "Ну и ну", "Вообще-то", "Не обижусь", "заноза", "Ещё чего"]],
	["sad", ["Глупо", "Прости", "жаль", "Жаль", "грустно", "одиноко", "плакать", "Холодно"]],
	["shy", ["…Ладно", "покраснела", "Спасибо тебе", "Не уходи", "смущ", "мне нравится", "Мне нравится", "чулк", "шёлк"]],
]

static func line_emotion(text: String, tag: String) -> String:
	if EMO_TAG.has(tag):
		return EMO_TAG[tag]
	var cue: = ""
	for c in EMO_CUES:
		for w in c[1]:
			if text.find(w) >= 0:
				cue = c[0]
				break
		if cue != "":
			break
	if tag == "big":
		return "surprised" if cue == "surprised" or (text.find("?") >= 0 and text.find("!") >= 0) else "happy"
	if cue != "":
		return cue
	return "happy" if text.ends_with("!") else ""

var W: = 720.0
var H: = 1280.0
var heroes: = {}
var cg_holder: Control
var cg_rect: TextureRect
var cg_active: = false
var ui_hidden: = false
var top_bar: ColorRect
var ttl_lbl: Label
var box: RBox
var txt: Label
var plate: RBox
var plate_lbl: Label
var plate_av: Control
var more: Label
var tapped: = false
var skipping: = false
var auto: = false
var choice_layer: Control
var _st: = 0.0
var _sb: = 0.0

func play(id: String) -> void :
	var d: Dictionary = V6Scenes.SCENES[id]
	var vs: = get_viewport_rect().size
	W = vs.x
	H = vs.y
	size = vs
	var ins: = V10Layout.safe_insets(vs)
	_st = float(ins.top)
	_sb = float(ins.bottom)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 460
	auto = "--autotap=1" in OS.get_cmdline_user_args() or "--story_auto=1" in OS.get_cmdline_user_args()
	gui_input.connect(_on_input)
	_build(d, id)
	modulate.a = 0.0
	var tin: = create_tween()
	tin.tween_property(self, "modulate:a", 1.0, 0.35)
	await tin.finished
	for e in d.lines:
		if skipping:
			break
		if e is Dictionary:
			if e.has("cg") and not e.has("ask"):
				_set_cg(str(e.cg))
				continue
			if e.has("cg"):
				_set_cg(str(e.cg))
			await _ask(e)
		else:
			if e.size() > 3 and str(e[3]) != "":
				_set_cg(str(e[3]))
			await _say(e[0], e[1], e[2] if e.size() > 2 else "")
	var tout: = create_tween()
	tout.tween_property(self, "modulate:a", 0.0, 0.35)
	await tout.finished
	queue_free()

func _build(d: Dictionary, id: String) -> void :
	var bg: String = d.get("bg", "play")
	if not ResourceLoader.exists("res://assets/bg/%s.webp" % bg):
		bg = "play"
	Common.backdrop(self, bg, size, 0.0, 0.94, Color(1.0, 0.97, 1.0), Vector2(0.5, 0.45))

	cg_holder = Control.new()
	cg_holder.name = "CgHolder"
	var br: = V10Layout.bleed_rect(self)
	cg_holder.position = br.position
	cg_holder.size = br.size
	cg_holder.clip_contents = true
	cg_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cg_holder)

	var init_cg: = str(d.get("cg", ""))
	var want_cg: = init_cg != "" and not bool(G.S.get("modest", false)) and ResourceLoader.exists(init_cg)
	Common.vignette(self, size, Color(0.10, 0.03, 0.14), 0.22 if want_cg else 0.48)
	if d.get("fx", "") != "":
		Fx.ambient(self, d.fx, size)

	var cast: Array = d.get("cast", [])
	for k in cast.size():
		var h: String = cast[k]
		var hero: = Hero.new().setup(h, H * 0.68)
		hero.interactive = false
		var x: = W * 0.5 if cast.size() == 1 else (W * 0.28 if k == 0 else W * 0.73)
		hero.position = Vector2(x, H + 40)
		if cast.size() > 1:
			hero.scale = Vector2(0.94, 0.94)
		# Bigger, closer heroine portrait busts (880 single / 740 duo)
		if hero.use_bust(_first_emotion(d, h), 880.0 if cast.size() == 1 else 740.0, -268.0) and cast.size() > 1:
			hero.position.x = W * (0.25 if k == 0 else 0.76)
		add_child(hero)
		UI.slide_in(hero, Vector2(0 if cast.size() == 1 else (-80 if k == 0 else 80), 60), 0.1 + k * 0.15, 0.6)
		heroes[h] = hero

	if want_cg:
		_set_cg(init_cg, false)

	top_bar = ColorRect.new()
	top_bar.color = Color(0.05, 0.02, 0.08, 0.52)
	top_bar.size = Vector2(W, 114 + _st)
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top_bar)
	var chapter: = ""
	if id.begins_with("w") and id.substr(1, 1).is_valid_int() and int(id.substr(1, 1)) < G.LOCS.size():
		chapter = G.LOCS[int(id.substr(1, 1))].name + " · "
	elif id in ["intro", "first_win"]:
		chapter = G.LOCS[0].name + " · "
	ttl_lbl = UI.label(chapter + V6Scenes.TITLES.get(id, ""), 26, Color("ffe9a8"), Color(0.06, 0.02, 0.09, 0.95), 4, "body", 900)
	var right_btn_x: = (W - 324.0) if want_cg else (W - 212.0)
	var ttl_w: = maxf(120.0, right_btn_x - 16.0 - 24.0)
	ttl_lbl.position = Vector2(24, 34 + _st)
	ttl_lbl.size = Vector2(ttl_w, 60)
	ttl_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Common.fit_line(ttl_lbl, ttl_w, 16)
	add_child(ttl_lbl)
	UI.slide_in(ttl_lbl, Vector2(-30, 0), 0.2, 0.5)

	# High-contrast Imperial Lacquer-Gold Dialogue Box with large 27px bold typography
	var bw: = minf(W - 24.0, 840.0)
	var bh: = 268.0
	box = UI.rbox("plum", Rect2((W - bw) * 0.5, H - _sb - bh - 22.0, bw, bh), 28, 4, 14)
	box.colors(Color(0.11, 0.045, 0.16, 0.93), Color(0.05, 0.02, 0.08, 0.97)).borders(Color("ffeaa8"), Color("c88f32"))
	add_child(box)
	# Subtle inner gold hairline at top of dialogue box
	var hair: = ColorRect.new()
	hair.color = Color(1.0, 0.88, 0.58, 0.36)
	hair.position = Vector2(28, 8)
	hair.size = Vector2(bw - 56.0, 1.5)
	hair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(hair)

	plate = UI.rbox("pink", Rect2(24, -30, 292, 56), 24, 3, 10)
	plate.borders(Color("ffeaa8"), Color("c88f32"))
	box.add_child(plate)
	plate_av = Control.new()
	plate_av.position = Vector2(6, 2)
	plate_av.size = Vector2(52, 52)
	plate_av.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(plate_av)
	plate_lbl = UI.label("", 26, Color("fff8ec"), Color("4a1028"), 5, "body", 900)
	plate_lbl.position = Vector2(64, 0)
	plate_lbl.size = Vector2(218, 56)
	plate_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	plate_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	plate.add_child(plate_lbl)

	txt = UI.label("", 27, Color("fff7eb"), Color(0.05, 0.02, 0.08, 0.96), 4, "body", 800)
	txt.label_settings = txt.label_settings.duplicate()
	txt.label_settings.line_spacing = 4.0
	txt.position = Vector2(28, 38)
	txt.size = Vector2(bw - 56.0, bh - 68.0)
	txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(txt)
	more = UI.label(V6Txt.s("story.next"), 24, Color("ffe28a"), Color(0.05, 0.02, 0.08), 3, "body", 900)
	more.position = Vector2(bw - 48, bh - 44)
	box.add_child(more)
	var mt: = more.create_tween().set_loops()
	mt.tween_property(more, "position:y", bh - 52.0, 0.45).set_trans(Tween.TRANS_SINE)
	mt.tween_property(more, "position:y", bh - 44.0, 0.45).set_trans(Tween.TRANS_SINE)
	UI.slide_in(box, Vector2(0, 60), 0.15, 0.35)

	if want_cg:
		var view_b: = JButton.make("Арт", "graphite", Rect2(W - 324, 34 + _st, 102, 60), null, 22)
		if view_b.box:
			view_b.box.borders(Color("ffe7a6"), Color("a8742a"))
		view_b.pressed.connect(func():
			ui_hidden = not ui_hidden
			box.visible = not ui_hidden
			top_bar.visible = not ui_hidden
			ttl_lbl.visible = not ui_hidden)
		add_child(view_b)

	var sk: = JButton.make(V6Txt.s("story.skip"), "glass", Rect2(W - 212, 34 + _st, 194, 60), null, 24)
	sk.pressed.connect( func():
		skipping = true
		tapped = true)
	add_child(sk)
	choice_layer = Control.new()
	choice_layer.size = size
	choice_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(choice_layer)

func _set_cg(path: String, fade: bool = true) -> void:
	if bool(G.S.get("modest", false)):
		return
	if path == "" or not ResourceLoader.exists(path):
		cg_active = false
		for h in heroes:
			(heroes[h] as Hero).visible = true
		if cg_rect and is_instance_valid(cg_rect):
			cg_rect.queue_free()
			cg_rect = null
		return
	var tex: = load(path) as Texture2D
	if tex == null:
		return
	cg_active = true
	for h in heroes:
		(heroes[h] as Hero).visible = false
	var tr: = TextureRect.new()
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	tr.position = Vector2.ZERO
	tr.size = cg_holder.size
	tr.pivot_offset = Vector2(cg_holder.size.x * 0.5, cg_holder.size.y * 0.34)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cg_holder.add_child(tr)
	var old: = cg_rect
	cg_rect = tr
	if fade and old and is_instance_valid(old):
		tr.modulate.a = 0.0
		var ftw: = tr.create_tween()
		ftw.tween_property(tr, "modulate:a", 1.0, 0.38)
		ftw.tween_callback(func():
			if is_instance_valid(old):
				old.queue_free())
	elif old and is_instance_valid(old):
		old.queue_free()
	var ktw: = tr.create_tween().set_loops()
	ktw.tween_property(tr, "scale", Vector2(1.042, 1.042), 6.5).set_trans(Tween.TRANS_SINE)
	ktw.tween_property(tr, "scale", Vector2.ONE, 6.5).set_trans(Tween.TRANS_SINE)

func _first_emotion(d: Dictionary, h: String) -> String:
	for e in d.lines:
		if e is Array and e.size() > 1 and String(e[0]) == h:
			var em: = line_emotion(String(e[1]), String(e[2]) if e.size() > 2 else "")
			if em != "":
				return em
	return "happy"

func _on_input(e: InputEvent) -> void :
	if (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and e.pressed):
		if ui_hidden:
			ui_hidden = false
			box.visible = true
			top_bar.visible = true
			ttl_lbl.visible = true
			return
		tapped = true

func _wait_tap(keep: = false) -> void :
	if not keep:
		tapped = false
	var t0: = G.time
	while not tapped and is_inside_tree():
		await get_tree().process_frame
		if auto and G.time - t0 > 1.4:
			break
	tapped = false

func _focus(who: String) -> void :
	for h in heroes:
		var on: bool = h == who or who == ""
		var hero: Hero = heroes[h]
		hero.visible = not cg_active
		hero.modulate = Color.WHITE if on else Color(0.55, 0.52, 0.65)
		if not cg_active and h == who:
			move_child(hero, box.get_index() - 1)

func _update_plate_av(who: String, em: String) -> void:
	for ch in plate_av.get_children():
		ch.queue_free()
	var en: = V8Art.emo_name(em) if em != "" else "happy"
	if not V8Art.has_emotion(who, en):
		en = "happy"
	if V8Art.has_emotion(who, en):
		var av: = V8Art.emotion_avatar(who, en, Rect2(0, 0, 52, 52), "gold")
		av.mouse_filter = Control.MOUSE_FILTER_IGNORE
		plate_av.add_child(av)

func _say(who: String, text: String, emo: = "") -> void :
	_focus(who)
	var narr: = who == "" or not G.HEROES.has(who)
	plate.visible = not narr
	var em: = line_emotion(text, emo)
	if not narr:
		plate_lbl.text = G.HEROES[who].name
		Common.fit_line(plate_lbl, 214.0, 20)
		plate.colors(G.HEROES[who].color.darkened(0.22), G.HEROES[who].color.darkened(0.52))
		_update_plate_av(who, em)
	txt.label_settings.font_color = Color("eadff8") if narr else Color("fff7eb")
	# Fit 27px bold down to 24px only for unusually long paragraphs so zero lines ever clip
	var fs: = 27
	var avail_w: = txt.size.x - 8.0
	var avail_h: = txt.size.y
	var fnt: = UI.font("body", 800)
	while fs > 24:
		var mh: = fnt.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, avail_w, fs, -1, TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND).y
		if mh <= avail_h:
			break
		fs -= 1
	txt.label_settings.font_size = fs
	txt.text = text
	txt.visible_ratio = 0.0
	more.visible = false
	if heroes.has(who) and not cg_active:
		var hero: Hero = heroes[who]
		hero.set_emotion(em, 0.34, 1.0, 0.14)
		hero.react(EMO.get(emo, "happy" if emo == "" else "tap"))
		hero.talk_left = minf(0.4 + text.length() * 0.045, 5.0)
	Sfx.play("pop", 1.3, -12)
	var tw: = create_tween()
	tw.tween_property(txt, "visible_ratio", 1.0, text.length() * 0.02)
	tw.tween_callback( func():
		if is_instance_valid(more):
			more.visible = true)
	tapped = false
	await get_tree().create_timer(0.2).timeout
	await _wait_tap(true)
	if skipping:
		return
	if txt.visible_ratio < 1.0:
		tw.kill()
		txt.visible_ratio = 1.0
		more.visible = true
		if heroes.has(who):
			heroes[who].talk_left = 0.0
		Sfx.play("tap", 1.15, -12)
		await _wait_tap()
	Sfx.play("tap", 1.0, -8)

func _ask(e: Dictionary) -> void :
	var who: String = e.get("who", "mc")
	var opts: Array = e.ask
	var picked: = [-1]
	more.visible = false
	var y: = box.position.y - 24.0 - opts.size() * 104
	var btns: = []
	var cw: = minf(W - 72.0, 820.0)
	for k in opts.size():
		var b: = JButton.make(opts[k][0], "gold" if k == 0 else "pink", Rect2((W - cw) * 0.5, y + k * 104, cw, 92), null, 27)
		b.pressed.connect( func(): picked[0] = k)
		choice_layer.add_child(b)
		UI.slide_in(b, Vector2(40, 0), k * 0.08, 0.3)
		btns.append(b)
	var t0: = G.time
	while picked[0] < 0 and not skipping and is_inside_tree():
		await get_tree().process_frame
		if auto and G.time - t0 > 1.4:
			picked[0] = 0
	for b in btns:
		b.queue_free()
	if skipping or picked[0] < 0:
		return
	var o: Array = opts[picked[0]]
	var aff: = int(o[2]) if o.size() > 2 else 0
	if aff > 0 and G.HEROES.has(who):
		V10Bond.gain(who, aff, "story")
		G.save()
		var pos: = Vector2(W * 0.5, H * 0.42)
		if heroes.has(who) and not cg_active:
			pos = heroes[who].head_global_any() + Vector2(0, -40)
		Fx.float_text(self, pos, V6Txt.s("story.aff") % [aff, G.HEROES[who].name], Color("ffd0e0"), 36)
		Sfx.play("gem", 1.2, -8)
	await _say(who, o[1], "happy")
