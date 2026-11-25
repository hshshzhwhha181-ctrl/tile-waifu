class_name V10SalonSheet
extends Control

# Bottom sheet of one task (spec §Р1 п.4, п.6): slides up in 0.28 s with a spring over a dimmed screen.
#   before → after crops of the zone art, the finish row (Лак · Нефрит +N★ · Сезонная — «входит в пропуск
#   сезона», no price, no buy button), and one main action:
#     unrestored + enough ★  → «Восстановить · 3★» (game button)
#     unrestored, short of ★ → «Ещё 2 звезды» (disabled second, shakes) + «Играть · 57» (game)
#     restored               → «Готово» (game); tapping a finish switches it (Нефрит costs its ★ once)
# The finish chips are ONE segmented control (row container `Finishes`, ux_role secondary). The sheet's height
# follows its content, so the main button always keeps ≥ 32 px above the screen edge.
# Emits: restore(tid), finish(tid, variant), play(), closed().

signal restore(tid: String)
signal finish(tid: String, variant: String)
signal play
signal closed

const SHEET_H: = 600.0  # minimum; _build grows it to fit

var zid: = ""
var tid: = ""
var veil: ColorRect
var sheet: Panel
var chips: = {}
var main_btn: V10SalonButton
var play_btn: V10SalonButton
var _closing: = false
var sheet_h: = SHEET_H


static func open(parent: Control, zid_: String, tid_: String) -> V10SalonSheet:
	var s: = V10SalonSheet.new()
	s.zid = zid_
	s.tid = tid_
	s.size = parent.size
	s.mouse_filter = Control.MOUSE_FILTER_STOP
	s.z_index = 60
	parent.add_child(s)
	s._build()
	return s


func _build() -> void:
	var W: = size.x
	var H: = size.y
	var t: = V10SalonData.task(zid, tid)
	var z: = V10SalonData.zone(zid)
	var restored: = V10Salon.restored(zid, tid)
	veil = ColorRect.new()
	veil.color = Color(V10SalonUI.NIGHT_900, 0.0)
	veil.size = size
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	veil.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			close())
	add_child(veil)
	var sw: = minf(W, 760.0)
	sheet = V10SalonUI.panel(Rect2((W - sw) * 0.5, H, sw, SHEET_H + 40), V10SalonUI.NIGHT_700, 4.0, Color(V10SalonUI.GOLD_700, 0.35), 1)
	sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(sheet)
	var x0: = 32.0
	var cw: = sw - 64.0
	# grabber
	var grab: = V10SalonUI.panel(Rect2(sw * 0.5 - 28, 12, 56, 5), Color(V10SalonUI.PAPER_700, 0.6), 3.0)
	sheet.add_child(grab)
	var ov: = V10SalonUI.overline(str(z.name))
	ov.position = Vector2(x0, 34)
	sheet.add_child(ov)
	var h2: = V10SalonUI.label(str(t.name), 32, V10SalonUI.PAPER_100, "display", 700)
	h2.position = Vector2(x0, 56)
	sheet.add_child(h2)
	var close_b: = V10SalonButton.make("quiet", "", Rect2(sw - 96, 22, 80, 80))
	close_b.icon = "close"
	close_b.pressed.connect(close)
	sheet.add_child(close_b)
	# before → after
	var ty: = 124.0
	var th: = 200.0
	var tw: = (cw - 56.0) * 0.5
	sheet.add_child(_thumb("broken", Rect2(x0, ty, tw, th), "Сейчас"))
	sheet.add_child(_thumb("done", Rect2(x0 + tw + 56, ty, tw, th), "После"))
	var arrow: = Control.new()
	arrow.position = Vector2(x0 + tw, ty + th * 0.5 - 14)
	arrow.size = Vector2(56, 28)
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arrow.draw.connect(func():
		arrow.draw_line(Vector2(14, 14), Vector2(40, 14), V10SalonUI.GOLD_500, 2.5, true)
		arrow.draw_polyline(PackedVector2Array([Vector2(32, 6), Vector2(41, 14), Vector2(32, 22)]), V10SalonUI.GOLD_500, 2.5, true))
	sheet.add_child(arrow)
	# finishes
	var fy: = ty + th + 52.0
	var fl: = V10SalonUI.overline("Отделка", V10SalonUI.PAPER_500)
	fl.position = Vector2(x0, fy - 26)
	sheet.add_child(fl)
	var cur: = V10Salon.task_variant(zid, tid)
	var chip_w: = (cw - 24.0) / 3.0
	var row: = Control.new()
	row.name = "Finishes"
	row.position = Vector2(x0, fy)
	row.size = Vector2(cw, 64)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_meta("ux_role", "secondary")
	sheet.add_child(row)
	var i: = 0
	for f in V10SalonData.FINISHES:
		var label: String = V10SalonData.FINISH_NAMES[f]
		var b: = V10SalonButton.make("chip", label, Rect2(i * (chip_w + 12), -8, chip_w, 80))
		if f == "jade" and not V10Salon.jade_paid(zid, tid):
			# the price in the unit it is paid in: «Нефрит · 2★» (UX §4.1: a number always has its unit)
			b.text = "Нефрит"
			b.stars = V10SalonData.jade_cost(int(t.cost))
		b.selected = (cur == f) or (cur == "" and f == "lacquer")
		if f == "season" and not V10Salon.season_open():
			b.disabled = true
		var fv: String = f
		b.pressed.connect(func(): _on_chip(fv))
		b.denied.connect(func(): _hint(fv))
		row.add_child(b)
		chips[f] = b
		i += 1
	var note: = V10SalonUI.label("", 18, V10SalonUI.PAPER_500)
	note.name = "Note"
	note.position = Vector2(x0, fy + 74)
	note.size = Vector2(cw, 26)
	note.text = _note_text()
	sheet.add_child(note)
	# action
	var by: = fy + 124.0
	var bank: = V10Salon.bank()
	sheet_h = maxf(SHEET_H, by + 104.0 + 32.0)
	sheet.size.y = sheet_h + 40.0
	if restored:
		main_btn = V10SalonButton.make("game", "Готово", Rect2(x0 + (cw - 440) * 0.5, by, 440, 104))
		main_btn.pressed.connect(close)
	elif bank >= int(t.cost):
		main_btn = V10SalonButton.make("game", "Восстановить", Rect2(x0 + (cw - 480) * 0.5, by, 480, 104), int(t.cost))
		main_btn.pressed.connect(func():
			restore.emit(tid)
			close(true))
	else:
		var need: = int(t.cost) - bank
		main_btn = V10SalonButton.make("second", "Ещё %s" % V10SalonUI.stars_word(need), Rect2(x0, by + 4, cw * 0.42, 96))
		main_btn.disabled = true
		main_btn.stars = -1
		main_btn.denied.connect(func(): _flash_note("Звёзды дают уровни Пути: до 3 за каждый"))
		sheet.add_child(main_btn)
		play_btn = V10SalonButton.make("game", "Играть · %d" % V10Salon.next_level(), Rect2(x0 + cw * 0.42 + 16, by, cw * 0.58 - 16, 104))
		play_btn.pressed.connect(func():
			play.emit()
			close())
		sheet.add_child(play_btn)
		_slide_in()
		return
	sheet.add_child(main_btn)
	_slide_in()


func _note_text() -> String:
	var t: = V10SalonData.task(zid, tid)
	if not V10Salon.restored(zid, tid):
		return "Лак — вместе с восстановлением. Нефрит — потом, за звёзды."
	if V10Salon.jade_paid(zid, tid):
		return "Нефрит открыт: меняй отделку когда угодно."
	return "Нефрит — ещё %s. Сезонная — в пропуске сезона." % V10SalonUI.stars_word(V10SalonData.jade_cost(int(t.cost)))


func _thumb(which: String, r: Rect2, cap: String) -> Control:
	var c: = Control.new()
	c.position = r.position
	c.size = r.size
	c.clip_contents = true
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tex: Texture2D = load(V10SalonData.ART + zid + "_" + which + ".webp")
	var t: = V10SalonData.task(zid, tid)
	var r0: Array = t.rects[0]
	var rr: = Rect2(r0[0], r0[1], r0[2], r0[3])
	for q in t.rects:
		rr = rr.merge(Rect2(q[0], q[1], q[2], q[3]))
	# fit the task's bounding rect (plus air) into the thumb, keeping the aspect
	var tw: = float(tex.get_width())
	var thh: = float(tex.get_height())
	var px: = Rect2(rr.position * Vector2(tw, thh), rr.size * Vector2(tw, thh)).grow(24)
	var want: = r.size.x / r.size.y
	if px.size.x / px.size.y > want:
		var nh: = px.size.x / want
		px = Rect2(px.position.x, px.get_center().y - nh * 0.5, px.size.x, nh)
	else:
		var nw: = px.size.y * want
		px = Rect2(px.get_center().x - nw * 0.5, px.position.y, nw, px.size.y)
	px.position = px.position.clamp(Vector2.ZERO, Vector2(maxf(0.0, tw - px.size.x), maxf(0.0, thh - px.size.y)))
	var at: = AtlasTexture.new()
	at.atlas = tex
	at.region = px
	var tr: = TextureRect.new()
	tr.texture = at
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tr.size = r.size
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(tr)
	var line: = V10SalonUI.panel(Rect2(Vector2.ZERO, r.size), Color(0, 0, 0, 0), 4.0, Color(V10SalonUI.GOLD_700, 0.5), 1)
	c.add_child(line)
	var cl: = V10SalonUI.label(cap, 18, V10SalonUI.PAPER_100, "body", 800, 0.8)
	cl.position = Vector2(12, r.size.y - 34)
	c.add_child(cl)
	return c


func _on_chip(f: String) -> void:
	if not V10Salon.restored(zid, tid):
		# before the restore only lacquer applies; jade is chosen after — say so instead of doing nothing
		if f != "lacquer":
			V9Feel.deny(chips[f])
			_flash_note("Сначала восстанови — отделку можно сменить потом.")
		return
	var cur: = V10Salon.task_variant(zid, tid)
	if f == cur:
		return
	if f == "jade" and not V10Salon.jade_paid(zid, tid) and V10Salon.bank() < V10SalonData.jade_cost(int(V10SalonData.task(zid, tid).cost)):
		V9Feel.deny(chips[f])
		_flash_note("Для нефрита нужно %s — их дают уровни Пути." % V10SalonUI.stars_word(V10SalonData.jade_cost(int(V10SalonData.task(zid, tid).cost))))
		return
	finish.emit(tid, f)
	for k in chips:
		chips[k].selected = k == f
	if f == "jade":
		chips[f].text = "Нефрит"
		chips[f].stars = -1
	(sheet.get_node("Note") as Label).text = _note_text()


func _hint(f: String) -> void:
	if f == "season":
		_flash_note("Сезонная отделка входит в пропуск сезона.")


func _flash_note(text: String) -> void:
	var n: Label = sheet.get_node("Note")
	n.text = text
	n.label_settings.font_color = V10SalonUI.GOLD_300
	var t: = n.create_tween()
	t.tween_interval(2.2)
	t.tween_callback(func():
		n.label_settings.font_color = V10SalonUI.PAPER_500
		n.text = _note_text())


func _slide_in() -> void:
	V10SalonUI.sound("salon_sheet", 1.1, -6.0)
	var t: = create_tween()
	t.tween_property(veil, "color:a", 0.55, 0.2)
	t.parallel().tween_property(sheet, "position:y", size.y - sheet_h, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func close(quick: = false) -> void:
	if _closing:
		return
	_closing = true
	var t: = create_tween()
	t.tween_property(veil, "color:a", 0.0, 0.18)
	t.parallel().tween_property(sheet, "position:y", size.y + 10, 0.16 if quick else 0.22).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
	t.tween_callback(func():
		closed.emit()
		queue_free())
