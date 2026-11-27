class_name V10VipDateWindow
extends Control

# Full-screen «Приватный вечер»: 16+ CG, spark meter, 3 branching flirt steps, final reward (V10VipDate holds the rules).

signal closed(rewarded: bool)

var hero: = "mc"
var hero_name: = ""
var accent: = Color("#FF799A")
var W: = 720.0
var H: = 1280.0
var lv: = 1
var step: = 0
var spark: = 0
var first_pref: = 0
var phase: = "select"
var _busy: = false
var _t: = 0.0
var _cg: TextureRect
var _fx: Control
var _panel: Control
var _spark_fill: ColorRect
var _spark_lbl: Label
var _step_lbl: Label
var _title: Label
var _cur_step: Dictionary = {}


func open(hero_id: String, sz: Vector2, aff_lv: int) -> void:
	hero = hero_id
	hero_name = V10VipBoudoirScreen._hero_name(hero_id)
	var s: = V10VipBoudoirScreen._suite_of(hero_id)
	accent = s.accent
	W = sz.x
	H = sz.y
	size = sz
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 90
	var base: = ColorRect.new()
	base.color = Color("#0B0310")
	base.size = sz
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(base)
	_cg = TextureRect.new()
	_cg.texture = V10VipBoudoirScreen.cg_texture(hero_id)
	_cg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_cg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_cg.position = Vector2(-24, -24)
	_cg.size = sz + Vector2(48, 48)
	_cg.pivot_offset = _cg.size * 0.5
	_cg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cg)
	_shade(Rect2(0, 0, W, 260), Color(0.05, 0.01, 0.08, 0.86), Color(0.05, 0.01, 0.08, 0.0))
	_shade(Rect2(0, H - 700, W, 700), Color(0.05, 0.01, 0.08, 0.0), Color(0.05, 0.01, 0.08, 0.93))
	_fx = Control.new()
	_fx.size = sz
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.z_index = 20
	add_child(_fx)
	Fx.ambient(self, "petals", sz)
	_build_top()
	_panel = Control.new()
	_panel.size = sz
	_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	_panel.z_index = 10
	add_child(_panel)
	lv = int(V10VipDate.unlocked_levels(aff_lv).back())
	_show_select(aff_lv)
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.25)


func _process(dt: float) -> void:
	_t += dt
	if _cg != null:
		var sc: = 1.02 + sin(_t * 0.5) * 0.018
		_cg.scale = Vector2(sc, sc)


func _shade(r: Rect2, c0: Color, c1: Color) -> void:
	var g: = Gradient.new()
	g.colors = PackedColorArray([c0, c1])
	var gt: = GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 8
	gt.height = 64
	var tr: = TextureRect.new()
	tr.texture = gt
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.position = r.position
	tr.size = r.size
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tr)


func _build_top() -> void:
	var x_b: = V10VipBoudoirScreen._pill(Rect2(16, 18, 56, 52), Color(0.13, 0.06, 0.19, 0.9), Color("#E8C47E"), 16)
	x_b.mouse_filter = Control.MOUSE_FILTER_STOP
	x_b.z_index = 30
	x_b.add_child(UI.center_label(UI.label("✕", 26, Color("#FFF4DE"), Color(0.06, 0.02, 0.1), 3, "body", 900), Rect2(0, -2, 56, 52)))
	x_b.gui_input.connect(func(e: InputEvent) -> void:
		if V10VipBoudoirScreen._is_tap(e):
			x_b.accept_event()
			close(false))
	add_child(x_b)
	_title = UI.label("Приватный вечер · " + hero_name, 28, Color("#FFF7E8"), Color(0.08, 0.02, 0.12), 5, "body", 900)
	_title.position = Vector2(86, 20)
	_title.size = Vector2(W - 100, 36)
	_title.z_index = 30
	add_child(_title)
	_step_lbl = UI.label("16+ · ветвящееся свидание", 17, Color("#F4D48A"), Color(0.08, 0.02, 0.12), 3, "body", 700)
	_step_lbl.position = Vector2(86, 56)
	_step_lbl.size = Vector2(W - 100, 24)
	_step_lbl.z_index = 30
	add_child(_step_lbl)
	var cap: = UI.label("Искра вечера ♥", 20, Color("#FFABC4"), Color(0.06, 0.02, 0.1), 4, "body", 900)
	cap.position = Vector2(24, 100)
	cap.size = Vector2(260, 28)
	cap.z_index = 30
	add_child(cap)
	_spark_lbl = UI.label("0 / 100", 20, Color("#FFE49C"), Color(0.06, 0.02, 0.1), 4, "body", 900)
	_spark_lbl.position = Vector2(W - 184, 100)
	_spark_lbl.size = Vector2(160, 28)
	_spark_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_spark_lbl.z_index = 30
	add_child(_spark_lbl)
	var bg: = V10VipBoudoirScreen._pill(Rect2(24, 134, W - 48, 22), Color(0.2, 0.08, 0.26, 0.92), Color("#F6D484"), 11)
	bg.z_index = 30
	bg.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	add_child(bg)
	_spark_fill = ColorRect.new()
	_spark_fill.color = Color("#FF5C8E")
	_spark_fill.size = Vector2(0, 22)
	_spark_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(_spark_fill)


func close(rewarded: bool) -> void:
	closed.emit(rewarded or _rewarded)
	var tw: = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.2)
	tw.tween_callback(queue_free)


func _clear_panel() -> void:
	for c in _panel.get_children():
		c.queue_free()


func _set_spark(v: int, animate: bool) -> void:
	spark = clampi(v, 0, 100)
	_spark_lbl.text = "%d / 100" % spark
	var w: = (W - 48.0) * float(spark) / 100.0
	if animate:
		create_tween().tween_property(_spark_fill, "size:x", w, 0.55).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	else:
		_spark_fill.size.x = w


var _rewarded: = false
var main_ref


func _py() -> float:
	return H - 560.0


func _lacquer(r: Rect2, bg: Color, border: Color, rad: int = 24) -> Panel:
	var p: = V10VipBoudoirScreen._pill(r, bg, border, rad)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	var gl: = ColorRect.new()
	gl.color = Color(1, 1, 1, 0.12)
	gl.position = Vector2(12, 5)
	gl.size = Vector2(r.size.x - 24, minf(20.0, r.size.y * 0.25))
	gl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(gl)
	return p


func _tap(p: Control, cb: Callable) -> void:
	p.gui_input.connect(func(e: InputEvent) -> void:
		if V10VipBoudoirScreen._is_tap(e):
			p.accept_event()
			V9Feel.press(p, "tap")
			cb.call())


func _show_select(aff_lv: int) -> void:
	phase = "select"
	_clear_panel()
	var y0: = _py()
	var head: = UI.label("Выбери вечер", 30, Color("#FFF7E8"), Color(0.08, 0.02, 0.12), 6, "body", 900)
	head.position = Vector2(24, y0)
	head.size = Vector2(W - 48, 40)
	_panel.add_child(head)
	var done: = not V10VipDate.reward_available(hero)
	var note: = UI.label("Награда за сегодня уже получена — можно играть ради удовольствия" if done else "Раз в день: +%d симпатии и бонус за вечер" % V10VipDate.AFF_REWARD, 17, Color("#F4D48A"), Color(0.08, 0.02, 0.12), 3, "body", 700)
	note.position = Vector2(24, y0 + 42)
	note.size = Vector2(W - 48, 26)
	V10VipBoudoirScreen.wrap_size(note, Vector2(W - 48, 26))
	_panel.add_child(note)
	var cw: = (W - 48.0 - 12.0) / 2.0
	for i in V10VipDate.LEVELS.size():
		var d: Dictionary = V10VipDate.LEVELS[i]
		var open_: = aff_lv >= int(d.lv)
		var sel: = int(d.lv) == lv and open_
		var r: = Rect2(24.0 + float(i % 2) * (cw + 12.0), y0 + 80.0 + float(i / 2) * 124.0, cw, 114)
		var c: = _lacquer(r, Color(0.5, 0.1, 0.28, 0.96) if sel else Color(0.14, 0.06, 0.2, 0.9), Color("#FFE49C") if sel else Color("#8F7048"), 22)
		c.modulate = Color.WHITE if open_ else Color(0.6, 0.6, 0.66, 0.9)
		_panel.add_child(c)
		var l1: = UI.label("Ур. %d" % int(d.lv) + (" · бесплатно" if int(d.lv) == 1 else ""), 18, Color("#FFD36E"), Color(0.08, 0.02, 0.12), 3, "body", 900)
		l1.position = Vector2(14, 12)
		l1.size = Vector2(cw - 28, 24)
		c.add_child(l1)
		var l2: = UI.label(String(d.title), 21, Color("#FFF6E4"), Color(0.08, 0.02, 0.12), 4, "body", 900)
		l2.position = Vector2(14, 38)
		l2.size = Vector2(cw - 28, 30)
		l2.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		c.add_child(l2)
		var rw: = "+%d ♥ · +%d крист." % [V10VipDate.AFF_REWARD, int(d.gems)] + (" · подарок" if String(d.gift) != "" else "")
		var l3: = UI.label(rw if open_ else "Откроется на Ур. %d близости" % int(d.lv), 16, Color("#FFABC4") if open_ else Color("#C9B8A0"), Color(0.08, 0.02, 0.12), 3, "body", 800)
		l3.position = Vector2(14, 74)
		l3.size = Vector2(cw - 28, 26)
		l3.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		c.add_child(l3)
		if open_:
			var lvl: int = int(d.lv)
			_tap(c, func() -> void:
				lv = lvl
				_show_select(aff_lv))
	var go: = V10Button.make("play", "Начать вечер ♥", Vector2(600, 100))
	go.position = Vector2((W - 600.0) * 0.5, y0 + 80.0 + 2.0 * 124.0 + 10.0)
	go.pressed.connect(_start)
	_panel.add_child(go)


func _start() -> void:
	step = 0
	first_pref = 0
	_busy = false
	phase = "play"
	_set_spark(0, false)
	_show_step()


func _show_step() -> void:
	_busy = false
	_cur_step = V10VipDate.build_step(lv, step, hero, hero_name, spark, first_pref)
	_clear_panel()
	_step_lbl.text = "Шаг %d из 3 · %s" % [step + 1, String(V10VipDate.level_def(lv).title)]
	var y0: = _py()
	var box: = _lacquer(Rect2(18, y0, W - 36, 150), Color(0.11, 0.04, 0.16, 0.9), Color("#F6D484"), 26)
	box.name = "Dlg"
	_panel.add_child(box)
	var tl: = UI.label(String(_cur_step.prompt), 23, Color("#FFF8EE"), Color(0.05, 0.02, 0.08), 4, "body", 800)
	tl.name = "DlgText"
	tl.position = Vector2(20, 12)
	tl.size = Vector2(box.size.x - 40, 126)
	V10VipBoudoirScreen.wrap_size(tl, Vector2(box.size.x - 40, 126))
	tl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.add_child(tl)
	Sfx.say(hero, "greet" if step == 0 else "hint")
	var chs: Array = _cur_step.choices
	for i in chs.size():
		var ch: Dictionary = chs[i]
		var b: = _lacquer(Rect2(18, y0 + 162.0 + float(i) * 128.0, W - 36, 118), Color(0.62, 0.1, 0.26, 0.96), Color("#FFE49C"), 30)
		b.name = "Choice%d" % i
		_panel.add_child(b)
		var tag: = UI.label(String(V10VipDate.TONE_NAMES[ch.tone]).to_upper(), 16, Color("#FFD36E"), Color(0.2, 0.02, 0.08), 3, "body", 900)
		tag.position = Vector2(22, 10)
		tag.size = Vector2(200, 22)
		b.add_child(tag)
		var tx: = UI.label(String(ch.text), 22, Color("#FFF8EE"), Color(0.25, 0.02, 0.1), 4, "body", 900)
		tx.position = Vector2(22, 34)
		tx.size = Vector2(b.size.x - 190, 76)
		V10VipBoudoirScreen.wrap_size(tx, Vector2(b.size.x - 190, 76))
		tx.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		b.add_child(tx)
		var chip: = V10VipBoudoirScreen._pill(Rect2(b.size.x - 150, 28, 134, 62), Color(0.2, 0.05, 0.16, 0.92), Color("#FFC4D6"), 20)
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(UI.center_label(UI.label("✦ +%d" % int(ch.spark), 26, Color("#FFD0E0"), Color(0.2, 0.0, 0.06), 4, "body", 900), Rect2(0, 0, 134, 62)))
		b.add_child(chip)
		var idx: = i
		_tap(b, func() -> void: _pick(idx))


func _pick(i: int) -> void:
	if _busy or phase != "play":
		return
	_busy = true
	var ch: Dictionary = _cur_step.choices[i]
	var gain: = int(ch.spark)
	var y0: = _py()
	for k in 3:
		var n: = _panel.get_node_or_null("Choice%d" % k) as Control
		if n == null:
			continue
		if k == i:
			var tw: = create_tween()
			tw.tween_property(n, "position:y", y0 + 162.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(n, "modulate:a", 0.0, 0.5).set_delay(0.5)
		else:
			create_tween().tween_property(n, "modulate:a", 0.0, 0.2)
	var dl: = _panel.get_node_or_null("Dlg/DlgText") as Label
	if dl != null:
		dl.text = "«%s»\n— %s" % [V10VipDate.reaction(hero, String(ch.tone)), hero_name]
		V10VipBoudoirScreen.wrap_size(dl, Vector2(W - 76.0, 126))
	if step == 0:
		first_pref = int(ch.pref)
	_set_spark(spark + gain, true)
	var pref: = int(ch.pref)
	Sfx.play("win" if pref == 0 else "sparkle", 1.0 + 0.05 * float(step), -6.0)
	Sfx.say(hero, String(V10VipDate.VOICE_BY_PREF[pref]))
	var at: = Vector2(W * 0.5, H * 0.42)
	Fx.burst(_fx, at, "heart", 18 if pref == 0 else 8)
	Fx.float_text(_fx, at + Vector2(0, -40), "✦ +%d" % gain, Color("#FFE49C"), 44, Color("#B8406C"))
	if pref == 0:
		Fx.flash_glow(_fx, at, Color(1, 0.6, 0.75), 3.0, 0.5)
	step += 1
	get_tree().create_timer(1.9).timeout.connect(_after_react)


func _after_react() -> void:
	if not is_inside_tree() or phase != "play":
		return
	if step < 3:
		_show_step()
	else:
		_finish()


func _finish() -> void:
	phase = "end"
	_clear_panel()
	var y0: = _py()
	var rank: = V10VipDate.rank_for(spark)
	_step_lbl.text = "Вечер завершён"
	var box: = _lacquer(Rect2(18, y0 - 20, W - 36, 560), Color(0.11, 0.04, 0.16, 0.93), Color("#F6D484"), 30)
	_panel.add_child(box)
	var rk: = UI.center_label(UI.label(String(V10VipDate.RANK_NAMES[rank]), 40, Color("#FFD36E"), Color(0.2, 0.03, 0.1), 7, "body", 900), Rect2(10, 18, box.size.x - 20, 56))
	box.add_child(rk)
	var sp: = UI.center_label(UI.label("Искра вечера: %d / 100  ♥" % spark, 26, Color("#FFABC4"), Color(0.06, 0.02, 0.1), 4, "body", 900), Rect2(10, 78, box.size.x - 20, 36))
	box.add_child(sp)
	var en: = UI.label(V10VipDate.ending(hero_name, rank), 22, Color("#FFF8EE"), Color(0.05, 0.02, 0.08), 4, "body", 800)
	en.position = Vector2(30, 124)
	en.size = Vector2(box.size.x - 60, 96)
	V10VipBoudoirScreen.wrap_size(en, Vector2(box.size.x - 60, 96))
	en.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	en.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.add_child(en)
	var avail: = V10VipDate.reward_available(hero)
	var d: = V10VipDate.level_def(lv)
	var lines: Array = ["+%d симпатии" % V10VipDate.AFF_REWARD, "+%d кристаллов" % int(d.gems)]
	if String(d.gift) != "":
		lines.append("Подарок «%s»" % String(V10AffCurve.gift_def(String(d.gift)).get("name", "")))
	elif rank >= 2:
		lines.append("Подарок «Чайный набор»")
	var rl: = UI.label("Награда: " + " · ".join(PackedStringArray(lines)) if avail else "Награда за сегодня уже получена — возвращайся завтра", 21, Color("#FFE49C"), Color(0.06, 0.02, 0.1), 4, "body", 900)
	rl.position = Vector2(30, 232)
	rl.size = Vector2(box.size.x - 60, 90)
	V10VipBoudoirScreen.wrap_size(rl, Vector2(box.size.x - 60, 90))
	rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.add_child(rl)
	Sfx.say(hero, "aff")
	Fx.burst(_fx, Vector2(W * 0.5, y0 + 40.0), "heart", 22)
	var main_b: = V10Button.make("play", "Забрать награду ♥" if avail else "Готово", Vector2(560, 100))
	main_b.position = Vector2((box.size.x - 560.0) * 0.5, 350)
	main_b.pressed.connect(func() -> void:
		if avail and not _rewarded:
			_claim(rl)
			main_b.text = "Готово"
		else:
			close(_rewarded))
	box.add_child(main_b)
	var again: = UI.center_label(UI.label("Сыграть ещё раз", 20, Color("#F6D68B"), Color(0.06, 0.02, 0.1), 3, "body", 800), Rect2(0, 468, box.size.x, 40))
	again.mouse_filter = Control.MOUSE_FILTER_STOP
	_tap(again, func() -> void: _show_select(int(G.aff_level(hero))))
	box.add_child(again)


func _claim(rl: Label) -> void:
	var res: = V10VipDate.claim(hero, lv, spark)
	if not bool(res.get("ok", false)):
		return
	_rewarded = true
	rl.text = "Получено: " + " · ".join(PackedStringArray(res.lines))
	Sfx.play("reveal_ssr", 1.0, -4.0)
	Fx.burst(_fx, Vector2(W * 0.5, H * 0.6), "sparkle", 36)
	Fx.burst(_fx, Vector2(W * 0.5, H * 0.6), "heart", 24)
	Fx.float_text(_fx, Vector2(W * 0.5, H * 0.55), "+%d ♥" % int(res.aff), Color("#FFE49C"), 52, Color("#B8406C"))
