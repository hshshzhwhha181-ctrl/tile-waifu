class_name V6BossIntro



static func run(p: Control, cfg: Dictionary) -> void :
	if not cfg.get("boss", false):
		return
	var hid: String = cfg.get("boss_hero", "mc")
	if not G.HEROES.has(hid):
		hid = "mc"
	var W: float = p.size.x
	var H: float = p.size.y
	var root: = Control.new()
	root.size = p.size
	root.z_index = 60
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	p.add_child(root)
	var dim: = ColorRect.new()
	dim.size = p.size
	dim.color = Color(0.03, 0.02, 0.05, 0.0)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)

	var band: = Polygon2D.new()
	band.polygon = PackedVector2Array([Vector2(-40, H * 0.3), Vector2(W + 40, H * 0.18), Vector2(W + 40, H * 0.62), Vector2(-40, H * 0.74)])
	band.color = Color(0.22, 0.09, 0.16, 0.92)
	root.add_child(band)
	for e in [[H * 0.3, H * 0.18], [H * 0.74, H * 0.62]]:
		var ln: = Line2D.new()
		ln.points = PackedVector2Array([Vector2(-40, e[0]), Vector2(W + 40, e[1])])
		ln.width = 4
		ln.default_color = Color("e0b060")
		root.add_child(ln)
	var hero: = Hero.new().setup(hid, H * 0.6)
	hero.interactive = false
	hero.position = Vector2(W * 0.7, H * 0.8)
	root.add_child(hero)
	var cap: = UI.label(V6Txt.s("levels.boss"), 22, Color("ffd0dc"), UI.DARK, 4, "body", 900)
	cap.position = Vector2(28, H * 0.33)
	cap.size = Vector2(W * 0.6, 30)
	root.add_child(cap)
	var ttl: = UI.title(cfg.get("boss_title", cfg.get("name", "")), 44, Color("ffe7a6"), Color(0.2, 0.02, 0.08))
	ttl.position = Vector2(24, H * 0.33 + 30)
	ttl.size = Vector2(W * 0.56, 120)
	ttl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(ttl)
	var nm: = UI.label(G.HEROES[hid].name, 26, Color.WHITE, UI.DARK, 5, "body", 900)
	nm.position = Vector2(28, H * 0.33 + 150)
	nm.size = Vector2(W * 0.5, 34)
	root.add_child(nm)
	var line: String = cfg.get("boss_line", "")
	var box: = UI.rbox("plum", Rect2(20, H * 0.8, W - 40, 120), 26, 4, 12)
	box.colors(Color(0.14, 0.07, 0.12, 0.96), Color(0.07, 0.035, 0.07, 0.97)).borders(Color("fff0b8"), Color("c58a2c"))
	root.add_child(box)
	var l: = UI.label("«%s»" % line if line != "" else V6Txt.line(hid, "boss"), 23, Color("fff1dc"), UI.DARK, 2, "body", 800)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.position = Vector2(26, 18)
	l.size = Vector2(W - 92, 90)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.add_child(l)

	var t: = root.create_tween().set_parallel()
	t.tween_property(dim, "color:a", 0.72, 0.3)
	band.modulate.a = 0.0
	t.tween_property(band, "modulate:a", 1.0, 0.3)
	hero.modulate.a = 0.0
	hero.position.x += 160
	t.tween_property(hero, "modulate:a", 1.0, 0.35).set_delay(0.1)
	t.tween_property(hero, "position:x", W * 0.7, 0.45).set_delay(0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for n in [cap, ttl, nm, box]:
		n.modulate.a = 0.0
	t.tween_property(cap, "modulate:a", 1.0, 0.25).set_delay(0.3)
	t.tween_property(ttl, "modulate:a", 1.0, 0.3).set_delay(0.4)
	t.tween_property(nm, "modulate:a", 1.0, 0.3).set_delay(0.5)
	t.tween_property(box, "modulate:a", 1.0, 0.3).set_delay(0.7)
	Sfx.play("reveal_sr", 0.8)
	if p.get_tree():
		p.get_tree().create_timer(0.6).timeout.connect( func():
			if is_instance_valid(hero):
				hero.react("tap")
				Fx.burst(root, Vector2(W * 0.7, H * 0.45), "sparkle", 24, Color(1, 0.85, 0.5), 1.0))
	var skip: = [false]
	root.gui_input.connect( func(e):
		if (e is InputEventMouseButton or e is InputEventScreenTouch) and e.pressed:
			skip[0] = true)
	var left: = 3.0
	while left > 0.0 and not skip[0] and is_instance_valid(root) and root.is_inside_tree():
		await root.get_tree().process_frame
		left -= root.get_process_delta_time()
	if not is_instance_valid(root):
		return
	var t2: = root.create_tween()
	t2.tween_property(root, "modulate:a", 0.0, 0.3)
	await t2.finished
	root.queue_free()
