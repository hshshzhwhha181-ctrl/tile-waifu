class_name V7AlbumView
extends Control




const D: = preload("res://core/v07/album/album_data.gd")
const TABS: = [["stamps", "Марки"], ["sets", "Сервизы"], ["tables", "Столы"], ["photos", "Снимки"]]
const HEAD_Y: = 24.0
const TABS_Y: = HEAD_Y + 96.0 + 46.0
const TOP: = TABS_Y + 58.0 + 14.0

var main
var W: = 720.0
var H: = 1280.0
var tab: = "stamps"
var content: Control
var clip: Control
var tab_nodes: = {}
var content_h: = 0.0
var _drag: = false
var _drag_y: = 0.0
var _moved: = 0.0
var _vel: = 0.0
var on_close: = Callable()

static func open(m, which: = "stamps", closed: = Callable()) -> V7AlbumView:
	var v: = V7AlbumView.new()
	v.main = m
	v.tab = which
	v.on_close = closed
	var vs: Vector2 = m.get_viewport_rect().size
	v.size = vs
	# 0.10 M0: the album is laid out like a screen, in main's content column (below a camera cut-out, ≤720 wide);
	# its dim and vignette bleed to the viewport edges
	if "CR" in m:
		v.position = m.CR.position
		v.size = m.CR.size
	v.set_meta("popup", true)
	v.set_meta("v8_back", v.close)
	m.overlay.add_child(v)
	v._build()
	return v

func _build() -> void :
	W = size.x
	H = size.y
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg: = ColorRect.new()
	var bbr: = V10Layout.bleed_rect(self)
	bg.position = bbr.position
	bg.size = bbr.size
	bg.color = Color(0.045, 0.038, 0.05, 0.0)
	# the album is modal: taps beside the column (tablets) stop here too
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)
	bg.create_tween().tween_property(bg, "color:a", 0.94, 0.25)
	Common.vignette(self, size, Color(0.35, 0.12, 0.2), 0.45)
	var panel: = UI.rbox("graphite", Rect2(14, HEAD_Y + 100.0, W - 28, H - HEAD_Y - 120.0), 34, 4, 14)
	panel.set_param("pattern", 1.0)
	add_child(panel)
	var hd: = V8Header.make(self, main, "Альбом", close)
	hd.position.y = HEAD_Y

	var sm: = UI.center_label(UI.label(_summary(), 18, UI.MUTED, UI.DARK, 3), Rect2(30, HEAD_Y + 106.0, W - 60, 28))
	sm.name = "Summary"
	add_child(sm)

	var tw: = (W - 60) / TABS.size()
	for i in TABS.size():
		var id: String = TABS[i][0]
		var b: = JButton.make(TABS[i][1], "pink" if id == tab else "graphite", Rect2(30 + i * tw, TABS_Y, tw - 8, 58), null, 22, -1.0, false)
		Common.tab_paint(b, id == tab)
		b.pressed.connect( func(): _switch(id))
		add_child(b)
		tab_nodes[id] = b
		var n: = _tab_badge(id)
		if n > 0:
			b.badge(str(n))
	clip = Control.new()
	clip.position = Vector2(14, TOP)
	clip.size = Vector2(W - 28, H - TOP - 24)
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(clip)
	UI.pop_in(panel, 0.0, 0.92)
	_fill()

func _summary() -> String:
	var got: = 0
	for f in 36:
		if V7Album.face_tier(f) >= 1:
			got += 1
	var on: = V7Album.active_keys().size()
	return "Марок %d/36 · столов %d/%d · бонусов наборов: %d" % [got, V7Album.tables_count(), D.TABLES.size(), on]

func _tab_badge(id: String) -> int:
	var sets: = V7Album.sets().filter( func(x): return x.ready and not x.claimed)
	match id:
		"stamps": return sets.filter( func(x): return x.id.begins_with("suit")).size()
		"sets": return sets.filter( func(x): return x.id.begins_with("skins")).size()
		"tables": return sets.filter( func(x): return x.id.begins_with("tables")).size()
	return 0

func close() -> void :
	if has_meta("closing"):
		return
	set_meta("closing", true)
	Sfx.play("tap")
	var t: = create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.18)
	t.tween_callback(queue_free)
	if on_close.is_valid():
		on_close.call()

func _switch(id: String) -> void :
	if id == tab:
		return
	tab = id
	for k in tab_nodes:
		tab_nodes[k].queue_free()
	tab_nodes.clear()
	for c in get_children():
		if c is JButton and c.position.y == TABS_Y:
			c.queue_free()
	var tw: = (W - 60) / TABS.size()
	for i in TABS.size():
		var tid: String = TABS[i][0]
		var b: = JButton.make(TABS[i][1], "pink" if tid == tab else "graphite", Rect2(30 + i * tw, TABS_Y, tw - 8, 58), null, 22, -1.0, false)
		Common.tab_paint(b, tid == tab)
		b.pressed.connect( func(): _switch(tid))
		add_child(b)
		tab_nodes[tid] = b
		var n: = _tab_badge(tid)
		if n > 0:
			b.badge(str(n))
	_fill()

func _refresh() -> void :
	var sm: Label = get_node_or_null("Summary")
	if sm:
		sm.text = _summary()
	var keep: = tab
	tab = ""
	_switch(keep)

func _fill() -> void :
	if content:
		content.queue_free()
	content = Control.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.size = Vector2(clip.size.x, 10)
	clip.add_child(content)
	_vel = 0.0
	var h: = 0.0
	match tab:
		"stamps": h = _fill_stamps()
		"sets": h = _fill_sets()
		"tables": h = _fill_tables()
		"photos": h = _fill_photos()
	content_h = h + 30.0
	content.size.y = content_h
	content.modulate.a = 0.0
	content.create_tween().tween_property(content, "modulate:a", 1.0, 0.2)


func _input(e: InputEvent) -> void :
	if not is_visible_in_tree() or has_meta("closing") or content == null:
		return
	if e is InputEventScreenTouch:
		if e.pressed and Rect2(clip.global_position, clip.size).has_point(e.position):
			_drag = true
			_drag_y = e.position.y
			_moved = 0.0
			_vel = 0.0
		elif not e.pressed:
			_drag = false
	elif e is InputEventScreenDrag and _drag:
		var dy: float = e.position.y - _drag_y
		_drag_y = e.position.y
		_moved += absf(dy)
		_vel = dy / maxf(0.001, get_process_delta_time())
		content.position.y = _clamp(content.position.y + dy)

func _process(dt: float) -> void :
	if content and not _drag and absf(_vel) > 5.0:
		content.position.y = _clamp(content.position.y + _vel * dt)
		_vel *= pow(0.03, dt)

func _clamp(y: float) -> float:
	return clampf(y, minf(0.0, clip.size.y - content_h), 0.0)

func scroll_to(y: float) -> void :
	if content:
		content.position.y = _clamp( - y)


func _on_tap(c: Control, cb: Callable) -> void :
	c.mouse_filter = Control.MOUSE_FILTER_PASS
	c.gui_input.connect( func(e):
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed and _moved < 14.0:
			UI.tap(c, 0.04, "")
			cb.call())

func _button(text: String, pal: String, r: Rect2, cb: Callable, fs: = 20) -> JButton:
	var b: = JButton.make(text, pal, r, null, fs)
	b.pressed.connect( func():
		if _moved < 14.0:
			cb.call())
	return b

func _claim_row(parent: Control, x: Dictionary, r: Rect2) -> void :

	var txt: = UI.label(x.bonus, 17, UI.INK if x.claimed else UI.MUTED, UI.DARK, 3)
	txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	txt.position = r.position
	txt.size = Vector2(r.size.x - 190, r.size.y)
	txt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	parent.add_child(txt)
	var br: = Rect2(r.end.x - 180, r.position.y + (r.size.y - 50) * 0.5, 180, 50)
	if x.claimed:
		var ok: = Common.chip(parent, V8Art.icon("star"), "Бонус активен", br, "mint", 16)
		ok.mouse_filter = Control.MOUSE_FILTER_IGNORE
	elif x.ready:
		var b: = _button("Забрать %d" % x.gems, "gold", br, func(): _claim(x.id, br, parent), 19)
		b.shine_every = 1.8
		b.pulse = true
		parent.add_child(b)
	else:
		var lk: = Common.chip(parent, V8Art.cur("gem"), "%d за набор" % x.gems, br, "plum", 16)
		lk.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _claim(id: String, r: Rect2, parent: Control) -> void :
	var g: = V7Album.claim(id)
	if g <= 0:
		return
	Sfx.play("reveal_sr")
	var p: = parent.get_global_transform_with_canvas() * r.get_center()
	Fx.burst(self, V10Layout.local_of(self, p), "sparkle", 40, Color(1, 0.85, 0.45), 1.3)
	main.fly_gems(p, 8)
	main.toast("Набор собран! +%d кристаллов, бонус уже работает" % g, "star")
	_refresh()


func _fill_stamps() -> float:
	var y: = 8.0
	var cw: = 76.0
	var gap: = 7.0
	var cols: = 8
	var x0: = (content.size.x - (cols * cw + (cols - 1) * gap)) * 0.5
	var sets: = V7Album.sets()
	var intro: = UI.label("Каждая пара на столе — штамп в альбом. 1 пара — бронза, %d — серебро, %d — золото. Полная масть даёт постоянный бонус." % [D.TIERS[1], D.TIERS[2]], 17, UI.MUTED, UI.DARK, 3)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.position = Vector2(24, y)
	intro.size = Vector2(content.size.x - 48, 50)
	content.add_child(intro)
	y += 62
	for i in D.SUITS.size():
		var su: Dictionary = D.SUITS[i]
		var faces: = D.suit_faces(su.cat)
		var rows: = int(ceil(faces.size() / float(cols)))
		var tier: = V7Album.suit_tier(i)
		var sh: = 64.0 + rows * (cw * 1.28 + gap) + 124.0
		var box: = UI.rbox("glass", Rect2(10, y, content.size.x - 20, sh), 26, 3, 10)
		if tier >= 3:
			box.set_param("glow", 1.0).set_param("glow_color", Color("ffe7a6"))
		content.add_child(box)
		var c: Array = V7Album.suit_count(i)
		var nm: = UI.label(su.name, 26, UI.INK, UI.DARK, 3, "title", 800)
		nm.position = Vector2(20, 10)
		box.add_child(nm)
		var cnt: = UI.label("%d/%d" % [c[0], c[1]], 20, D.TIER_COLORS[maxi(0, tier - 1)] if tier > 0 else UI.MUTED, UI.DARK, 3, "body", 900)
		cnt.position = Vector2(box.size.x - 160, 16)
		cnt.size = Vector2(140, 30)
		cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		box.add_child(cnt)
		if tier > 0:
			var tb: = Common.chip(box, null, D.TIER_NAMES[tier - 1], Rect2(box.size.x - 300, 14, 120, 32), "gold" if tier == 3 else "plum", 15)
			tb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for k in faces.size():
			var f: int = faces[k]
			var r: = Rect2(x0 - 10 + (k % cols) * (cw + gap), 60 + (k / cols) * (cw * 1.28 + gap), cw, cw * 1.28)
			_stamp(box, f, r)
		var yy: = 64.0 + rows * (cw * 1.28 + gap) + 4
		var s_b: Dictionary = sets.filter( func(s): return s.id == su.id)[0]
		var s_g: Dictionary = sets.filter( func(s): return s.id == su.id + "_gold")[0]
		_claim_row(box, s_b, Rect2(20, yy, box.size.x - 40, 54))
		_claim_row(box, s_g, Rect2(20, yy + 58, box.size.x - 40, 54))
		y += sh + 16
	return y

func _stamp(parent: Control, f: int, r: Rect2) -> void :
	var n: = V7Album.face_pairs(f)
	var t: = D.tier_of(n)
	var card: = UI.rbox("plum" if t == 0 else "cream", r, 14, 2, 6)
	if t > 0:
		card.borders(D.TIER_COLORS[t - 1], D.TIER_COLORS[t - 1].darkened(0.45))
	parent.add_child(card)
	var tex: = UI.tex(G.tile_tex(f), Rect2(10, 6, r.size.x - 20, (r.size.x - 20) * 1.04))
	if t == 0:
		tex.modulate = Color(0.12, 0.1, 0.13, 0.85)
	card.add_child(tex)
	if t == 0:
		card.add_child(UI.center_label(UI.label("?", 30, Color(1, 1, 1, 0.35), UI.DARK, 2, "title"), Rect2(0, 10, r.size.x, r.size.x * 0.9)))

	for k in 3:
		var on: = t > k
		var pip: = UI.rbox("gold" if on else "plum", Rect2(r.size.x * 0.5 - 27 + k * 20, r.size.y - 22, 14, 14), 7, 1, 2)
		if on:
			pip.colors(D.TIER_COLORS[k], D.TIER_COLORS[k].darkened(0.35))
		card.add_child(pip)
	# 0.8: no 12 px caption over the tile art — the stamp's name shows on tap (toast below)
	_on_tap(card, func():
		Sfx.play("pop")
		var nxt: = 0
		for th in D.TIERS:
			if n < th:
				nxt = th
				break
		var name: String = D.FACE_NAMES[f] if t > 0 else "Неизвестная фишка"
		main.toast("%s: пар %d%s" % [name, n, (" · до следующей марки %d" % (nxt - n)) if nxt > 0 else " · золото"], "star"))


func _fill_sets() -> float:
	var y: = 8.0
	var sets: = V7Album.sets()
	var intro: = UI.label("Наборы фишек меняют вид стола. Собери сервиз целиком — получишь постоянный бонус. Нажми на свой набор, чтобы играть им.", 17, UI.MUTED, UI.DARK, 3)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.position = Vector2(24, y)
	intro.size = Vector2(content.size.x - 48, 50)
	content.add_child(intro)
	y += 62
	for i in D.SKIN_SETS.size():
		var ss: Dictionary = D.SKIN_SETS[i]
		var box: = UI.rbox("glass", Rect2(10, y, content.size.x - 20, 400), 26, 3, 10)
		content.add_child(box)
		var c: Array = V7Album.skin_set_count(i)
		var nm: = UI.label(ss.name, 26, UI.INK, UI.DARK, 3, "title", 800)
		nm.position = Vector2(20, 10)
		box.add_child(nm)
		var cnt: = UI.label("%d/%d" % [c[0], c[1]], 20, UI.GOLD if c[0] >= c[1] else UI.MUTED, UI.DARK, 3, "body", 900)
		cnt.position = Vector2(box.size.x - 160, 16)
		cnt.size = Vector2(140, 30)
		cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		box.add_child(cnt)
		var items: Array = ss.items
		var cw: = (box.size.x - 40 - 2 * 14) / 3.0
		for k in items.size():
			var it: Dictionary = G.ITEM[items[k]]
			var own: = G.owns(it.id)
			var on: bool = G.S.get("skin", "s_sakura") == it.id
			var r: = Rect2(20 + k * (cw + 14), 60, cw, 250)
			var card: = UI.rbox("gold" if on else ("cream" if own else "plum"), r, 20, 3, 8)
			box.add_child(card)
			var tile: = Tile.new()
			tile.face = it.tile
			tile.position = Vector2(cw * 0.5, 100)
			tile.scale = Vector2(1.35, 1.35)
			card.add_child(tile)
			tile.build(G.SKIN_LOOK.get(it.id, {}))
			if not own:
				tile.modulate = Color(0.4, 0.38, 0.45)
			var rl: = UI.label(V10Rank.label(it.rar), 18, Color.WHITE, G.rar_color(it.rar).darkened(0.5), 4, "body", 900)
			rl.position = Vector2(10, 6)
			card.add_child(rl)
			card.add_child(UI.center_label(UI.label(it.name.replace("Фишки ", ""), 17, UI.INK if not on else Color("3a2410"), UI.DARK if not on else Color(1, 0.95, 0.8, 0.5), 3, "body", 900), Rect2(0, 182, cw, 26)))
			var how: = "Выбран" if on else ("Играть им" if own else G.skin_source(it.id))
			var hl: = UI.label(how, 16, Color("3a2410") if on else (UI.GOLD if own else UI.MUTED), Color(0, 0, 0, 0), 0, "body", 800)
			hl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			hl.position = Vector2(6, 208)
			hl.size = Vector2(cw - 12, 38)
			hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			card.add_child(hl)
			var itc: Dictionary = it
			_on_tap(card, func():
				if not G.owns(itc.id):
					Sfx.play("deny")
					main.toast("«%s»: %s" % [itc.name.replace("Фишки ", ""), G.skin_source(itc.id)], "gift")
					return
				Sfx.play("pop")
				G.S.skin = itc.id
				G.save()
				main.toast("Играешь набором «%s»" % itc.name.replace("Фишки ", ""), "star")
				_refresh())
		var s_x: Dictionary = sets.filter( func(s): return s.id == ss.id)[0]
		_claim_row(box, s_x, Rect2(20, 326, box.size.x - 40, 60))
		y += 400 + 16
	return y


func _fill_tables() -> float:
	var y: = 8.0
	var sets: = V7Album.sets()
	var intro: = UI.label("Стол под фишками. Обычно он свой у каждой главы; здесь можно закрепить любимый. Новые столы открывает победа над боссом главы.", 17, UI.MUTED, UI.DARK, 3)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.position = Vector2(24, y)
	intro.size = Vector2(content.size.x - 48, 50)
	content.add_child(intro)
	y += 62
	var cur: = String(V7Album.st().get("table", ""))

	var auto: = UI.rbox("gold" if cur == "" else "glass", Rect2(10, y, content.size.x - 20, 70), 22, 3, 8)
	content.add_child(auto)
	auto.add_child(V8Art.rect(V8Art.nav("home"), Rect2(14, 8, 54, 54)))
	var al: = UI.label("Стол главы (как задумано)", 22, Color("3a2410") if cur == "" else UI.INK, Color(1, 0.95, 0.8, 0.4) if cur == "" else UI.DARK, 3, "body", 900)
	al.position = Vector2(80, 0)
	al.size = Vector2(auto.size.x - 100, 70)
	al.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	auto.add_child(al)
	_on_tap(auto, func():
		Sfx.play("pop")
		V7Album.set_table("")
		main.toast("Каждая глава снова со своим столом", "home")
		_refresh())
	y += 86
	var cw: = (content.size.x - 20 - 14) / 2.0
	for k in D.TABLES.size():
		var tb: Dictionary = D.TABLES[k]
		var unl: = V7Album.table_unlocked(tb.id)
		var on: bool = cur == tb.id
		var r: = Rect2(10 + (k % 2) * (cw + 14), y + (k / 2) * 274, cw, 260)
		var card: = UI.rbox("gold" if on else "glass", r, 22, 3, 8)
		content.add_child(card)
		_table_preview(card, tb.id, Rect2(12, 12, cw - 24, 150), unl)
		card.add_child(UI.center_label(UI.label(tb.name, 20, Color("3a2410") if on else UI.INK, Color(1, 0.95, 0.8, 0.4) if on else UI.DARK, 3, "body", 900), Rect2(0, 168, cw, 28)))
		var how: String = tb.desc
		if on:
			how = "Закреплён"
		elif not unl:
			how = _table_lock(tb)
		var hl: = UI.label(how, 16, Color("3a2410") if on else (UI.MUTED if unl else Color("c9a0aa")), Color(0, 0, 0, 0), 0)
		hl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hl.position = Vector2(8, 198)
		hl.size = Vector2(cw - 16, 52)
		hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(hl)
		if not unl:
			card.add_child(V8Art.rect(V8Art.icon("lock"), Rect2(cw * 0.5 - 24, 60, 48, 48)))
		var tid: String = tb.id
		var tname: String = tb.name
		var tbc: Dictionary = tb
		_on_tap(card, func():
			if not V7Album.table_unlocked(tid):
				Sfx.play("deny")
				main.toast(_table_lock(tbc), "lock")
				return
			Sfx.play("pop")
			V7Album.set_table(tid)
			main.toast("Теперь везде стол «%s»" % tname, "star")
			_refresh())
	y += int(ceil(D.TABLES.size() / 2.0)) * 274 + 6
	for ts in D.TABLE_SETS:
		var box: = UI.rbox("glass", Rect2(10, y, content.size.x - 20, 118), 22, 3, 8)
		content.add_child(box)
		var nm: = UI.label("%s · %d/%d" % [ts.name, mini(V7Album.tables_count(), int(ts.need)), int(ts.need)], 21, UI.INK, UI.DARK, 3, "body", 900)
		nm.position = Vector2(20, 10)
		box.add_child(nm)
		var s_x: Dictionary = sets.filter( func(s): return s.id == ts.id)[0]
		_claim_row(box, s_x, Rect2(20, 48, box.size.x - 40, 60))
		y += 134
	return y

func _table_lock(tb: Dictionary) -> String:
	var u: String = tb.unlock
	var s: = ""
	if u.begins_with("boss:"):
		s = "Победи босса главы %d" % (int(u.substr(5)) + 1)
	if tb.has("item"):
		s += " или получи «%s»" % G.ITEM[tb.item].name
	return s

static func _table_preview(parent: Control, id: String, r: Rect2, unl: = true) -> void :
	var th: Dictionary = V6BoardTable.THEMES.get(id, V6BoardTable.THEMES["default"])
	var m: = 10.0
	var cr: = ColorRect.new()
	cr.position = r.position - Vector2(m, m)
	cr.size = r.size + Vector2(m, m) * 2.0
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat: = ShaderMaterial.new()
	mat.shader = V6BoardTable.SHADER
	cr.material = mat
	mat.set_shader_parameter("size", cr.size)
	mat.set_shader_parameter("margin", m)
	mat.set_shader_parameter("frame_w", 12.0)
	mat.set_shader_parameter("radius", 16.0)
	mat.set_shader_parameter("noise", load("res://assets/v06/board/table_noise.png"))
	for key in ["frame_a", "frame_b", "trim", "mat_a", "mat_b", "pat_col"]:
		mat.set_shader_parameter(key, th[key])
	mat.set_shader_parameter("pat_alpha", th.pat_alpha)
	mat.set_shader_parameter("pattern", th.pattern)
	mat.set_shader_parameter("pat_scale", th.pat_scale * 0.6)
	mat.set_shader_parameter("fibre", th.fibre)
	mat.set_shader_parameter("neon", th.get("neon", 0.0))
	var lc: Color = th.lamp_col
	mat.set_shader_parameter("lamp_col", Vector3(lc.r, lc.g, lc.b))
	mat.set_shader_parameter("lamp_k", th.lamp_k)
	mat.set_shader_parameter("t", G.time)
	parent.add_child(cr)

	for k in 2:
		var t: = Tile.new()
		t.face = [0, 25][k]
		t.position = r.position + Vector2(r.size.x * (0.4 + 0.2 * k), r.size.y * 0.5)
		t.scale = Vector2(0.62, 0.62)
		parent.add_child(t)
		t.build(G.skin_look())
	if not unl:
		cr.modulate = Color(0.35, 0.33, 0.38)
		for c in parent.get_children():
			if c is Tile:
				c.modulate = Color(0.35, 0.33, 0.38)


func _fill_photos() -> float:
	var y: = 8.0
	var ph: = V7Album.photos()
	var intro: = UI.label("Снимки побед из фоторежима (кнопка «Фото» после партии). Нажми на снимок, чтобы открыть его в галерее и отправить.", 17, UI.MUTED, UI.DARK, 3)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.position = Vector2(24, y)
	intro.size = Vector2(content.size.x - 48, 50)
	content.add_child(intro)
	y += 62
	if ph.is_empty():
		var box: = UI.rbox("glass", Rect2(10, y, content.size.x - 20, 220), 26, 3, 10)
		content.add_child(box)
		box.add_child(V8Art.rect(V8Art.icon("trophy"), Rect2(box.size.x * 0.5 - 50, 24, 100, 100)))
		box.add_child(UI.center_label(UI.label("Пока пусто. Выиграй партию и нажми «Фото».", 20, UI.INK, UI.DARK, 3), Rect2(0, 140, box.size.x, 40)))
		return y + 240
	var cols: = 3
	var cw: = (content.size.x - 20 - (cols - 1) * 12) / cols
	var chh: = cw * 16.0 / 9.0
	for k in ph.size():
		var p: String = ph[k]
		var r: = Rect2(10 + (k % cols) * (cw + 12), y + (k / cols) * (chh + 12), cw, chh)
		var card: = UI.rbox("gold", r, 14, 3, 6)
		content.add_child(card)
		var img: = Image.load_from_file(p)
		if img:
			if img.get_width() > 360:
				img.resize(360, int(360.0 * img.get_height() / img.get_width()), Image.INTERPOLATE_BILINEAR)
			var tr: = TextureRect.new()
			tr.texture = ImageTexture.create_from_image(img)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			tr.position = Vector2(4, 4)
			tr.size = r.size - Vector2(8, 8)
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tr.clip_contents = true
			card.add_child(tr)
		var pp: = p
		_on_tap(card, func():
			Sfx.play("pop")
			V7Photo.open_file(main, pp))
	return y + int(ceil(ph.size() / float(cols))) * (chh + 12)


static func collection_button(strip: Control, m, rebuild: Callable) -> void :
	var b: = JButton.make("Альбом", "gold", Rect2(strip.size.x - 236, 2, 222, 40), V8Art.icon("star"), 19)
	b.shine_every = 3.0
	b.pressed.connect( func(): V7AlbumView.open(m, "stamps", rebuild))
	strip.add_child(b)
	var n: = V7Album.claimable()
	if n > 0:
		b.badge(str(n))
