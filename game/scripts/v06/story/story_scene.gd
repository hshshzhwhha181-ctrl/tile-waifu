class_name V6StoryScene
extends Control



const EMO: = {"happy": "happy", "big": "big", "sad": "sad", "tap": "tap", "shy": "tap"}

# 0.8: the emotion portrait of a line (V8Art.emotion, assets/v08/emotions). A line's tag wins (happy / sad / shy;
# «big» is glad, or amazed when the line asks and exclaims); an untagged («tap» or none) line is read for simple
# cues; nothing found = the rigged base portrait (her neutral face). Only the portrait changes, never the text.
const EMO_TAG: = {"happy": "happy", "sad": "sad", "shy": "shy", "pout": "pout", "surprised": "surprised"}
const EMO_CUES: = [
	["surprised", ["?!", "!?", "Ой!", "Ой,", "Ах!", "Неужели", "Не может быть", "Вот это да"]],
	["pout", ["Хм", "Не смотри", "Не пойми неправильно", "Опять", "Ну и ну", "Вообще-то", "Не обижусь", "заноза", "Ещё чего"]],
	["sad", ["Глупо", "Прости", "жаль", "Жаль", "грустно", "одиноко", "плакать", "Холодно"]],
	["shy", ["…Ладно", "покраснела", "Спасибо тебе", "Не уходи", "смущ", "мне нравится", "Мне нравится"]],
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
var box: RBox
var txt: Label
var plate: RBox
var plate_lbl: Label
var more: Label
var tapped: = false
var skipping: = false
var auto: = false
var choice_layer: Control

func play(id: String) -> void :
	var d: Dictionary = V6Scenes.SCENES[id]
	var vs: = get_viewport_rect().size
	W = vs.x
	H = vs.y
	size = vs
	mouse_filter = Control.MOUSE_FILTER_STOP
	# above the match result window (play.gd V8Result z 300) and main.overlay (400 in a match): post-level scenes
	# play from before_go() while the victory screen is still alive
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
			await _ask(e)
		else:
			await _say(e[0], e[1], e[2] if e.size() > 2 else "")
	var tout: = create_tween()
	tout.tween_property(self, "modulate:a", 0.0, 0.35)
	await tout.finished
	queue_free()

func _build(d: Dictionary, id: String) -> void :
	var bg: String = d.get("bg", "play")
	if not ResourceLoader.exists("res://assets/bg/%s.webp" % bg):
		bg = "play"
	Common.backdrop(self, bg, size, 0.0, 0.82, Color(0.95, 0.92, 1.0), Vector2(0.5, 0.45))
	Common.vignette(self, size, Color(0.08, 0.03, 0.15), 0.7)
	if d.get("fx", "") != "":
		Fx.ambient(self, d.fx, size)

	var top: = ColorRect.new()
	top.color = Color(0.04, 0.02, 0.07, 0.55)
	top.size = Vector2(W, 118)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	var chapter: = ""
	if id.begins_with("w") and id.substr(1, 1).is_valid_int() and int(id.substr(1, 1)) < G.LOCS.size():
		chapter = G.LOCS[int(id.substr(1, 1))].name + " · "
	elif id in ["intro", "first_win"]:
		chapter = G.LOCS[0].name + " · "
	var ttl: = UI.label(chapter + V6Scenes.TITLES.get(id, ""), 24, Color("ffe7a6"), UI.DARK, 4, "body", 900)
	ttl.position = Vector2(28, 52)
	add_child(ttl)
	UI.slide_in(ttl, Vector2(-30, 0), 0.2, 0.5)

	var cast: Array = d.get("cast", [])
	for k in cast.size():
		var h: String = cast[k]
		var hero: = Hero.new().setup(h, H * 0.64)
		hero.interactive = false
		var x: = W * 0.5 if cast.size() == 1 else (W * 0.3 if k == 0 else W * 0.72)
		hero.position = Vector2(x, H + 40)
		if cast.size() > 1:
			hero.scale = Vector2(0.92, 0.92)
		# 0.8: with emotion art she stands as her waist-up emotion portrait, the waist behind the dialogue box
		# (the rigged full-length art stays when the files are missing)
		if hero.use_bust(_first_emotion(d, h), 760.0 if cast.size() == 1 else 640.0, -250.0) and cast.size() > 1:
			# two busts are wider than two full-length figures: a little further apart, overlapping only at the arms
			hero.position.x = W * (0.26 if k == 0 else 0.75)
		add_child(hero)
		UI.slide_in(hero, Vector2(0 if cast.size() == 1 else (-80 if k == 0 else 80), 60), 0.1 + k * 0.15, 0.6)
		heroes[h] = hero

	box = UI.rbox("plum", Rect2(18, H - 300, W - 36, 256), 28, 4, 12)
	box.colors(Color(0.14, 0.07, 0.2, 0.95), Color(0.07, 0.035, 0.12, 0.97)).borders(Color("fff0b8"), Color("c58a2c"))
	add_child(box)
	plate = UI.rbox("pink", Rect2(30, -26, 250, 50), 22, 3, 8)
	box.add_child(plate)
	plate_lbl = UI.center_label(UI.label("", 22, Color.WHITE, Color("5a1a36"), 4, "body", 900), Rect2(0, 0, 250, 50))
	plate.add_child(plate_lbl)
	txt = UI.label("", 25, Color("fff1dc"), UI.DARK, 2, "body", 800)
	txt.position = Vector2(30, 40)
	txt.size = Vector2(W - 100, 180)
	txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(txt)
	more = UI.label(V6Txt.s("story.next"), 20, Color("ffd98a"))
	more.position = Vector2(W - 90, 212)
	box.add_child(more)
	var mt: = more.create_tween().set_loops()
	mt.tween_property(more, "position:y", 204.0, 0.45).set_trans(Tween.TRANS_SINE)
	mt.tween_property(more, "position:y", 212.0, 0.45).set_trans(Tween.TRANS_SINE)
	UI.slide_in(box, Vector2(0, 60), 0.15, 0.35)
	var sk: = JButton.make(V6Txt.s("story.skip"), "glass", Rect2(W - 214, 36, 196, 60), null, 22)
	sk.pressed.connect( func():
		skipping = true
		tapped = true)
	add_child(sk)
	choice_layer = Control.new()
	choice_layer.size = size
	choice_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(choice_layer)

# her face when she first appears: the emotion of her first line that has one, else glad
func _first_emotion(d: Dictionary, h: String) -> String:
	for e in d.lines:
		if e is Array and e.size() > 1 and String(e[0]) == h:
			var em: = line_emotion(String(e[1]), String(e[2]) if e.size() > 2 else "")
			if em != "":
				return em
	return "happy"

func _on_input(e: InputEvent) -> void :
	if e is InputEventMouseButton and e.pressed:
		tapped = true

# keep = true: a tap that already arrived (e.g. during a line's first 0.2 s) counts, so fast tappers never tap twice
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
		hero.modulate = Color.WHITE if on else Color(0.55, 0.52, 0.65)
		if h == who:
			move_child(hero, box.get_index() - 1)

func _say(who: String, text: String, emo: = "") -> void :
	_focus(who)
	var narr: = who == "" or not G.HEROES.has(who)
	plate.visible = not narr
	if not narr:
		plate_lbl.text = G.HEROES[who].name
		plate.colors(G.HEROES[who].color.darkened(0.15), G.HEROES[who].color.darkened(0.45))
	txt.label_settings.font_color = Color("d9cdf0") if narr else Color("fff1dc")
	txt.text = text
	txt.visible_ratio = 0.0
	more.visible = false
	if heroes.has(who):
		var hero: Hero = heroes[who]
		# 0.8: crossfade (+ slight zoom) to the line's emotion portrait, face on the rig's face; neutral = the rig
		hero.set_emotion(line_emotion(text, emo), 0.34, 1.0, 0.14)
		hero.react(EMO.get(emo, "happy" if emo == "" else "tap"))
		hero.talk_left = minf(0.4 + text.length() * 0.045, 5.0)
	Sfx.play("pop", 1.3, -12)
	var tw: = create_tween()
	tw.tween_property(txt, "visible_ratio", 1.0, text.length() * 0.02)
	# 0.9: the bouncing ▼ shows while the game waits for the tap that advances, not after it
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
	var y: = H - 300 - 36 - opts.size() * 104
	var btns: = []
	for k in opts.size():
		var b: = JButton.make(opts[k][0], "gold" if k == 0 else "rose", Rect2(48, y + k * 104, W - 96, 88), null, 26)
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
		G.add_aff(who, aff)
		G.save()
		var pos: = Vector2(W * 0.5, H * 0.42)
		if heroes.has(who):
			pos = heroes[who].head_global_any() + Vector2(0, -40)
		Fx.float_text(self, pos, V6Txt.s("story.aff") % [aff, G.HEROES[who].name], Color("ffd0e0"), 34)
		Sfx.play("gem", 1.2, -8)
	await _say(who, o[1], "happy")
