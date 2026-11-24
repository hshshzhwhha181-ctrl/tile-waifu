class_name V7RoomScene
extends Control




const EMO: = {"happy": "happy", "big": "big", "sad": "sad", "tap": "tap", "shy": "tap"}

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
var visual_layer: Control
var photo: Control
var cg: TextureRect
var result: = {"aff": 0, "score": 0, "skipped": false}

static func run(data: Dictionary) -> Dictionary:
	var root: Node = (Engine.get_main_loop() as SceneTree).current_scene
	var sc: = V7RoomScene.new()
	root.add_child(sc)
	return await sc.play(data)


static func backdrop(parent: Control, path: String, size: Vector2, focus: = Vector2(0.5, 0.5), bright: = 1.0, blur: = 0.0) -> TextureRect:
	var tex: Texture2D = load(path)
	var r: = UI.tex(tex, Rect2(Vector2.ZERO, size), false)
	var m: = ShaderMaterial.new()
	m.shader = preload("res://shaders/blurbg.gdshader")
	m.set_shader_parameter("size", size)
	m.set_shader_parameter("tex_size", Vector2(tex.get_width(), tex.get_height()))
	m.set_shader_parameter("blur", blur)
	m.set_shader_parameter("bright", bright)
	m.set_shader_parameter("tint", Color.WHITE)
	m.set_shader_parameter("focus", focus)
	m.set_shader_parameter("zoom", 1.04)
	m.set_shader_parameter("drift", Vector2(1, 1))
	r.material = m
	parent.add_child(r)
	return r

func play(d: Dictionary) -> Dictionary:
	var vs: = get_viewport_rect().size
	W = vs.x
	H = vs.y
	size = vs
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 40
	var args: = OS.get_cmdline_user_args()
	auto = "--autotap=1" in args or "--story_auto=1" in args or "--room_auto=1" in args
	gui_input.connect(_on_input)
	_build(d)
	modulate.a = 0.0
	var tin: = create_tween()
	tin.tween_property(self, "modulate:a", 1.0, 0.35)
	await tin.finished
	for e in d.lines:
		if skipping:
			break
		if e is Dictionary:
			if e.has("photo"):
				await _photo(e.photo, e.get("cap", ""))
			elif e.has("cg"):
				await _cg(e.cg, float(e.get("focus", 0.5)))
			elif e.has("black"):
				await _black(e.black)
			elif e.has("date"):
				await _date_ask(e)
			elif e.has("ask"):
				await _ask(e)
		else:
			await _say(e[0], e[1], e[2] if e.size() > 2 else "")
	result.skipped = skipping
	var tout: = create_tween()
	tout.tween_property(self, "modulate:a", 0.0, 0.35)
	await tout.finished
	queue_free()
	return result

func _build(d: Dictionary) -> void :
	backdrop(self, d.bg_path, size, d.get("focus", Vector2(0.5, 0.5)), 0.85)
	Common.vignette(self, size, Color(0.08, 0.03, 0.12), 0.6)
	if d.get("fx", "") != "":
		Fx.ambient(self, d.fx, size)
	visual_layer = Control.new()
	visual_layer.size = size
	visual_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(visual_layer)
	var top: = ColorRect.new()
	top.color = Color(0.04, 0.02, 0.05, 0.6)
	top.size = Vector2(W, 118)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	var ttl: = UI.label(d.get("title", ""), 24, Color("ffe7a6"), UI.DARK, 4, "body", 900)
	ttl.position = Vector2(28, 52)
	ttl.size = Vector2(W - 270, 40)
	ttl.clip_text = true
	add_child(ttl)
	UI.slide_in(ttl, Vector2(-30, 0), 0.2, 0.5)
	var cast: Array = d.get("cast", [])
	for k in cast.size():
		var h: String = cast[k]
		var hero: = Hero.new().setup(h, H * 0.64)
		hero.interactive = false
		var x: = W * 0.5 if cast.size() == 1 else (W * 0.3 if k == 0 else W * 0.72)
		hero.position = Vector2(x, H + 40)
		visual_layer.add_child(hero)
		UI.slide_in(hero, Vector2(0, 60), 0.1 + k * 0.15, 0.6)
		heroes[h] = hero
	box = UI.rbox("plum", Rect2(18, H - 300, W - 36, 256), 28, 4, 12)
	box.colors(Color(0.13, 0.08, 0.11, 0.95), Color(0.06, 0.04, 0.06, 0.97)).borders(Color("f3dca0"), Color("a8782c"))
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
	more = UI.label("▼", 20, Color("ffd98a"))
	more.position = Vector2(W - 90, 212)
	box.add_child(more)
	var mt: = more.create_tween().set_loops()
	mt.tween_property(more, "position:y", 204.0, 0.45).set_trans(Tween.TRANS_SINE)
	mt.tween_property(more, "position:y", 212.0, 0.45).set_trans(Tween.TRANS_SINE)
	UI.slide_in(box, Vector2(0, 60), 0.15, 0.35)
	var sk: = JButton.make("Пропустить", "glass", Rect2(W - 214, 36, 196, 60), null, 22)
	sk.pressed.connect( func():
		skipping = true
		tapped = true)
	add_child(sk)
	choice_layer = Control.new()
	choice_layer.size = size
	choice_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(choice_layer)

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

func _say(who: String, text: String, emo: = "") -> void :
	var narr: = who == "" or not G.HEROES.has(who)
	plate.visible = not narr
	if not narr:
		plate_lbl.text = G.HEROES[who].name
		plate.colors(G.HEROES[who].color.darkened(0.25), G.HEROES[who].color.darkened(0.55))
	txt.label_settings.font_color = Color("d9cdf0") if narr else Color("fff1dc")
	txt.text = text
	txt.visible_ratio = 0.0
	more.visible = false
	if heroes.has(who) and cg == null:
		var hero: Hero = heroes[who]
		hero.react(EMO.get(emo, "happy" if emo == "" else "tap"))
		hero.talk_left = minf(0.4 + text.length() * 0.045, 5.0)
		if emo == "shy":
			Fx.burst(visual_layer, hero.head_global() + Vector2(0, -30), "heart", 5, Color(1, 0.8, 0.86), 0.6)
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

func _buttons(opts: Array) -> int:
	var picked: = [-1]
	more.visible = false
	var bh: = 96.0 if opts.size() > 2 else 104.0
	var y: = H - 300 - 30 - opts.size() * bh
	var btns: = []
	for k in opts.size():
		var b: = JButton.make(opts[k][0], "gold" if k == 0 else "rose", Rect2(40, y + k * bh, W - 80, bh - 14), null, 23)
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
	return picked[0]

func _heart_text(who: String, n: int) -> void :
	var pos: = Vector2(W * 0.5, H * 0.42)
	if heroes.has(who) and cg == null:
		pos = heroes[who].head_global() + Vector2(0, -40)
	Fx.float_text(self, pos, "+%d ♥" % n, Color("ffd0e0"), 38)
	Fx.burst(self, pos, "heart", 10, Color(1, 0.75, 0.85), 0.8)
	Sfx.play("gem", 1.2, -8)


func _ask(e: Dictionary) -> void :
	var who: String = e.get("who", "mc")
	var k: = await _buttons(e.ask)
	if skipping or k < 0:
		return
	var o: Array = e.ask[k]
	var aff: = int(o[2]) if o.size() > 2 else 0
	if aff > 0:
		result.aff += aff
		_heart_text(who, aff)
	await _say(who, o[1], "happy")


func _date_ask(e: Dictionary) -> void :
	var who: String = e.who
	await _say(who, e.q, "")
	if skipping:
		return
	var k: = await _buttons(e.date)
	if skipping or k < 0:
		return
	var o: Array = e.date[k]
	var sc: = int(o[2])
	result.score += sc
	if sc == 2:
		_heart_text(who, 2)
	elif sc == 0 and heroes.has(who):
		Fx.float_text(self, heroes[who].head_global() + Vector2(70, -60), "…", Color("c8c0d8"), 44)
	await _say(who, o[1], ["sad", "happy", "big"][sc])


func _photo(item_id: String, cap: String) -> void :
	if not G.ITEM.has(item_id):
		return
	if photo:
		photo.queue_free()
	var pw: = 380.0
	var ph: = 500.0
	photo = Control.new()
	photo.size = Vector2(pw, ph)
	photo.pivot_offset = photo.size * 0.5
	photo.position = Vector2(26, 150)
	photo.rotation = -0.06
	photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visual_layer.add_child(photo)
	var frame: = Panel.new()
	var sb: = StyleBoxFlat.new()
	sb.bg_color = Color("fbf4ea")
	sb.set_corner_radius_all(8)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 18
	sb.shadow_offset = Vector2(6, 10)
	frame.add_theme_stylebox_override("panel", sb)
	frame.size = photo.size
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	photo.add_child(frame)
	var art: = Common.card_art(G.art_tex(G.ITEM[item_id]), Rect2(18, 18, pw - 36, ph - 96), Vector2(0.5, 0.32), 1.0, 4)
	(art.material as ShaderMaterial).set_shader_parameter("bottom_shade", 0.0)
	photo.add_child(art)
	var cl: = Label.new()
	cl.text = cap
	var ls: = LabelSettings.new()
	var fv: = FontVariation.new()
	fv.base_font = load("res://assets/fonts/playfair-i-cyr.woff2")
	ls.font = fv
	ls.font_size = 28
	ls.font_color = Color("4a3040")
	cl.label_settings = ls
	cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cl.position = Vector2(0, ph - 70)
	cl.size = Vector2(pw, 50)
	cl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	photo.add_child(cl)

	var tape: = ColorRect.new()
	tape.color = Color(1, 0.93, 0.8, 0.7)
	tape.size = Vector2(120, 34)
	tape.position = Vector2(pw * 0.5 - 60, -14)
	tape.rotation = 0.05
	tape.mouse_filter = Control.MOUSE_FILTER_IGNORE
	photo.add_child(tape)
	photo.scale = Vector2(0.6, 0.6)
	photo.modulate.a = 0.0
	var t: = photo.create_tween().set_parallel()
	t.tween_property(photo, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(photo, "modulate:a", 1.0, 0.25)
	for h in heroes:
		var hero: Hero = heroes[h]
		hero.create_tween().tween_property(hero, "position:x", W * 0.72, 0.5).set_trans(Tween.TRANS_SINE)
	Sfx.play("sparkle", 1.0, -6)
	Fx.burst(self, photo.position + photo.size * 0.5, "sparkle", 18)
	await get_tree().create_timer(0.5).timeout


func _cg(id: String, focus_x: float) -> void :
	var path: = "res://assets/v07/room/%s.webp" % id
	if not ResourceLoader.exists(path):
		return
	if photo:
		photo.queue_free()
		photo = null
	var tex: Texture2D = load(path)

	var wide: = Control.new()
	wide.size = size
	wide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visual_layer.add_child(wide)
	var bl: = UI.tex(tex, Rect2(Vector2.ZERO, size), false)
	var bm: = ShaderMaterial.new()
	bm.shader = preload("res://shaders/blurbg.gdshader")
	bm.set_shader_parameter("size", size)
	bm.set_shader_parameter("tex_size", Vector2(tex.get_width(), tex.get_height()))
	bm.set_shader_parameter("blur", 3.0)
	bm.set_shader_parameter("bright", 0.6)
	bm.set_shader_parameter("tint", Color.WHITE)
	bm.set_shader_parameter("focus", Vector2(focus_x, 0.5))
	bm.set_shader_parameter("zoom", 1.1)
	bm.set_shader_parameter("drift", Vector2(1, 1))
	bl.material = bm
	wide.add_child(bl)
	var fw: = W - 24.0
	var fh: = fw * float(tex.get_height()) / float(tex.get_width())
	var fy: = maxf(130.0, (H - 300.0 - fh) * 0.5 + 40.0)
	var fr: = UI.rbox("gold", Rect2(6, fy - 6, fw + 12, fh + 12), 18, 3, 10)
	wide.add_child(fr)
	var full: = Common.card_art(tex, Rect2(12, fy, fw, fh), Vector2(0.5, 0.5), 1.0, 14)
	(full.material as ShaderMaterial).set_shader_parameter("bottom_shade", 0.0)
	wide.add_child(full)
	for h in heroes:
		heroes[h].visible = false
	var fl: = ColorRect.new()
	fl.color = Color(1, 0.97, 0.92, 1)
	fl.size = size
	fl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visual_layer.add_child(fl)
	fl.create_tween().tween_property(fl, "color:a", 0.0, 0.8)
	Sfx.play("reveal_sr", 1.0, -6)
	box.visible = false
	txt.text = ""
	plate.visible = false
	await get_tree().create_timer(0.6).timeout
	await _wait_tap()
	box.visible = true

	cg = Common.card_art(tex, Rect2(Vector2.ZERO, size), Vector2(focus_x - 0.1, 0.5), 1.0, 0.0)
	(cg.material as ShaderMaterial).set_shader_parameter("bottom_shade", 0.35)
	cg.modulate.a = 0.0
	visual_layer.add_child(cg)
	visual_layer.move_child(fl, -1)
	var xf: = create_tween()
	xf.tween_property(cg, "modulate:a", 1.0, 0.9)
	xf.tween_callback(wide.queue_free)
	var m: = cg.material as ShaderMaterial
	var pan: = cg.create_tween().set_loops()
	pan.tween_method( func(v): m.set_shader_parameter("focus", Vector2(v, 0.5)), focus_x - 0.1, focus_x + 0.1, 9.0).set_trans(Tween.TRANS_SINE)
	pan.tween_method( func(v): m.set_shader_parameter("focus", Vector2(v, 0.5)), focus_x + 0.1, focus_x - 0.1, 9.0).set_trans(Tween.TRANS_SINE)
	Fx.ambient(visual_layer, "fireflies", size)
	await get_tree().create_timer(0.9).timeout


func _black(text: String) -> void :
	var b: = ColorRect.new()
	b.color = Color(0.02, 0.01, 0.02, 0.0)
	b.size = size
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(b)
	move_child(b, choice_layer.get_index())
	var l: = Label.new()
	l.text = text
	var ls: = LabelSettings.new()
	var fv: = FontVariation.new()
	fv.base_font = load("res://assets/fonts/playfair-i-cyr.woff2")
	ls.font = fv
	ls.font_size = 30
	ls.font_color = Color("f1e2c8")
	ls.line_spacing = 8
	l.label_settings = ls
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.position = Vector2(60, H * 0.3)
	l.size = Vector2(W - 120, H * 0.3)
	l.modulate.a = 0.0
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(l)
	box.visible = false
	var t: = b.create_tween()
	t.tween_property(b, "color:a", 1.0, 0.8)
	t.tween_property(l, "modulate:a", 1.0, 0.6)
	await t.finished
	await _wait_tap()
	var t2: = b.create_tween()
	t2.tween_property(b, "modulate:a", 0.0, 0.7)
	t2.tween_callback(b.queue_free)
	box.visible = true
	await t2.finished
