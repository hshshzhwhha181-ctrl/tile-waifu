extends Control

# Screen "v10salon" — Салон Пяти ветров (docs/0.10-spec.md §Р1). Register in main.SCREENS (README, hooks).
# One header (back · «Салон» · star bank · «?»), a vertical map of zones from the bottom up (z1 at the bottom, the
# next one above, ONE locked teaser on top — UX §6.4), and a fixed bottom with ONE main action (UX §3.4):
# «Восстановить · 3★» (the cheapest affordable task) when the bank covers it, else «Играть · уровень N», over the
# line «ещё 4★ до „Фонари у входа“». Tags → task sheet → restore beat (stars fly, dust, reveal, glint);
# the last task → zone finale (wave, heroine, line, chest). Done zones: heroine lives there, «Сцена».
# args: {zone: zid} scroll to that zone.  Works with the real main (go/back/toast/show_chrome) and the runner stub.
# dev_act(name): "restore_first", "open_sheet", "close_sheet", "close_finale", "help", "main", "scroll:<zid>",
#   "sheet:<zid>/<tid>", "jade:<zid>/<tid>", "say:<zid>/<zone>".

var main
var W: = 720.0
var H: = 1280.0
var scroll: ScrollContainer
var list: VBoxContainer
var zones: = {}  # zid -> V10SalonZone
var bank_lbl: Label
var bank_box: Control
var goal_lbl: Label
var goal_box: HBoxContainer
var play_btn: V10SalonButton
var help_btn: V10SalonButton
var _bottom_goal: = {}  # the goal the bottom button restores ({} = it plays)
var sheet: V10SalonSheet
var finale: V10SalonFinale
var toast_box: Control
var intro_plate: Control
var busy: = false
var shown_bank: = 0
var _last_scroll: = 0.0
var _header_h: = 120.0
var _bottom_h: = 190.0
var _top_pad: = 0.0

const ZONE_GAP: = 28.0
const MUSIC: = "res://assets/music/salon.ogg"  # UX §7.1 «Салон: эрху, деревянный зал, 76»; audio lane


func build(m, args: Dictionary) -> void:
	main = m
	W = size.x
	H = size.y
	if main != null and main.has_method("show_chrome"):
		main.show_chrome(false, false)
	V10Salon.ensure()
	V10Salon.reset_cache()
	V10Salon.repair()
	# UX §7.1: the salon's own track (эрху, 76) once the audio lane lands it; until then the current track plays on
	var sfx_node: Node = get_tree().root.get_node_or_null("Sfx") if is_inside_tree() else null
	if sfx_node != null and ResourceLoader.exists(MUSIC) and main != null:
		sfx_node.call("music", "salon", 0.4)
	var bg: = ColorRect.new()
	bg.color = V10SalonUI.NIGHT_900
	var br: = V10Layout.bleed_rect(self)
	bg.position = br.position
	bg.size = br.size
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_top_pad = _safe_top()
	_header_h = _top_pad + 112.0
	_build_map()
	_build_header()
	_build_bottom()
	toast_box = Control.new()
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_box.size = size
	toast_box.z_index = 80
	add_child(toast_box)
	shown_bank = V10Salon.bank()
	bank_lbl.text = str(shown_bank)
	_refresh_bottom()
	var target: String = str(args.get("zone", V10Salon.current_zone()))
	_scroll_to.call_deferred(target, false)
	if V10Salon.intro_needed():
		_show_intro.call_deferred()
	set_meta("v8_back", _back)
	_enter()


func _safe_top() -> float:
	var sa: = DisplayServer.get_display_safe_area()
	var ws: = DisplayServer.window_get_size()
	if ws.y <= 0 or sa.size.y <= 0:
		return 16.0
	return clampf(sa.position.y * H / ws.y, 16.0, 80.0)


# ── header ───────────────────────────────────────────────────────────────────────────────────────────────────

func _build_header() -> void:
	# one header band: solid night, then a 40 px fade over the map (tags and art never show through the title)
	var br_h: = V10Layout.bleed_rect(self)
	var band: = ColorRect.new()
	band.color = V10SalonUI.NIGHT_900
	band.position = Vector2(br_h.position.x, br_h.position.y)
	band.size = Vector2(br_h.size.x, _header_h - br_h.position.y)
	band.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(band)
	var shade: = _vgrad(Rect2(br_h.position.x, _header_h, br_h.size.x, 40), Color(V10SalonUI.NIGHT_900, 1.0), Color(V10SalonUI.NIGHT_900, 0.0), 0.5)
	add_child(shade)
	var y0: = _top_pad
	var back_b: = V10SalonButton.make("quiet", "", Rect2(12, y0 + 12, 80, 80))
	back_b.icon = "back"
	back_b.pressed.connect(_back)
	add_child(back_b)
	# H1 on the left field (HUD_V2 §8.6); no overline here — the map keeps to 4 type sizes (UX §3.7)
	var h1: = V10SalonUI.label("Салон", 44, V10SalonUI.PAPER_100, "display", 700)
	h1.position = Vector2(102, y0 + 22)
	add_child(h1)
	# «?» (quiet, UX §2.4): the salon's article; the bank next to it is a display (its meaning is in the article)
	help_btn = V10SalonButton.make("quiet", "", Rect2(W - 92, y0 + 12, 80, 80))
	help_btn.icon = "help"
	help_btn.pressed.connect(_help)
	add_child(help_btn)
	# star bank: «34» with a drawn star and the caption «звёзды Пути»
	bank_box = Control.new()
	bank_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bank_box.size = Vector2(204, 88)
	bank_box.position = Vector2(W - 92 - 8 - 204, y0 + 10)
	bank_box.draw.connect(func():
		bank_box.draw_style_box(V10SalonUI.panel_box(Color(V10SalonUI.NIGHT_700, 0.9), 4.0, Color(V10SalonUI.GOLD_700, 0.5), 1), Rect2(Vector2.ZERO, bank_box.size))
		bank_box.draw_colored_polygon(V10SalonUI.star_points(Vector2(38, 38), 20.0), V10SalonUI.GOLD_300))
	add_child(bank_box)
	bank_lbl = V10SalonUI.label("0", 32, V10SalonUI.GOLD_300, "body", 900)
	bank_lbl.position = Vector2(66, 10)
	bank_box.add_child(bank_lbl)
	var cap: = V10SalonUI.label("звёзды Пути", 18, V10SalonUI.PAPER_500, "body", 700)
	cap.position = Vector2(66, 54)
	bank_box.add_child(cap)


func _help() -> void:
	if V10Salon.help_cb.is_valid():
		V10Salon.help_cb.call("salon")
		return
	toast(V10SalonData.HELP)


func bank_center() -> Vector2:
	return bank_box.position + Vector2(38, 38)


# ── map ──────────────────────────────────────────────────────────────────────────────────────────────────────

func _build_map() -> void:
	scroll = ScrollContainer.new()
	scroll.position = Vector2(0, 0)
	scroll.size = Vector2(W, H)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	add_child(scroll)
	list = VBoxContainer.new()
	list.custom_minimum_size = Vector2(W, 0)
	list.add_theme_constant_override("separation", int(ZONE_GAP))
	scroll.add_child(list)
	_fill()
	scroll.get_v_scroll_bar().value_changed.connect(func(_v): _check_visible())


func _fill() -> void:
	for c in list.get_children():
		list.remove_child(c)
		c.queue_free()
	zones.clear()
	var zw: = minf(W, 1000.0)
	_spacer(_header_h + 8)
	# the one locked teaser on top: the next locked zone, else arc 2
	var ids: Array = V10SalonData.zone_ids()
	var shown: = []
	for zid in ids:
		if V10Salon.zone_open(zid):
			shown.append(zid)
	var teaser: = ""
	for zid in ids:
		if not V10Salon.zone_open(zid):
			teaser = zid
			break
	if teaser == "":
		list.add_child(_arc_teaser(zw))
	shown.reverse()
	if teaser != "":
		shown.push_front(teaser)
	for zid in shown:
		var row: = CenterContainer.new()
		row.custom_minimum_size = Vector2(W, V10SalonZone.height_for(zw))
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var zn: = V10SalonZone.make(zid, zw)
		zn.task_tapped.connect(_on_task)
		zn.scene_tapped.connect(_open_scene)
		zn.heroine_tapped.connect(_on_heroine)
		if zid == teaser:
			zn.add_child(_lock_plate(zid, zn.size))
		row.add_child(zn)
		list.add_child(row)
		zones[zid] = zn
	_spacer(_bottom_h + 24)


func _spacer(h: float) -> void:
	var s: = Control.new()
	s.custom_minimum_size = Vector2(W, h)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	list.add_child(s)


func _lock_plate(zid: String, sz: Vector2) -> Control:
	var c: = Control.new()
	c.size = sz
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ids: = V10SalonData.zone_ids()
	var prev: Dictionary = V10SalonData.ZONES[ids.find(zid) - 1]
	var l: = V10SalonUI.label("Откроется: после зоны «%s»" % prev.name, 18, V10SalonUI.PAPER_300, "body", 700, 0.8)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(sz.x, 32)
	l.position = Vector2(0, sz.y * 0.5 - 4)
	c.add_child(l)
	return c


func _arc_teaser(zw: float) -> Control:
	# «Следующая зона откроется с аркой 2» — a silhouette card in paper.700, no timer, no lock icons
	var c: = Control.new()
	c.custom_minimum_size = Vector2(W, 220)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var nz: Dictionary = V10SalonData.LATER[0]
	c.draw.connect(func():
		var r: = Rect2((W - zw) * 0.5 + 24, 10, zw - 48, 200)
		c.draw_style_box(V10SalonUI.panel_box(V10SalonUI.NIGHT_800, 4.0, Color(V10SalonUI.GOLD_700, 0.35), 1), r)
		# silhouette of a lantern yard: roof line and three lanterns, in the right corner clear of the H2 text
		var base: = Vector2(r.end.x - 106, 160)
		var col: = Color(V10SalonUI.PAPER_700, 0.35)
		c.draw_colored_polygon(PackedVector2Array([base + Vector2(-96, -62), base + Vector2(0, -96), base + Vector2(96, -62), base + Vector2(78, -56), base + Vector2(-78, -56)]), col)
		for k in 3:
			var lp: = base + Vector2(-54 + k * 54, -24)
			c.draw_line(lp + Vector2(0, -28), lp + Vector2(0, -14), col, 2.0)
			c.draw_circle(lp, 13.0, col))
	var ov: = V10SalonUI.label("Зона IV · %s" % nz.name, 18, V10SalonUI.PAPER_500, "body", 800)
	ov.position = Vector2((W - zw) * 0.5 + 52, 40)
	c.add_child(ov)
	var l: = V10SalonUI.label("Следующая зона откроется\nс аркой 2", 32, V10SalonUI.PAPER_300, "italic", 500)
	l.position = Vector2((W - zw) * 0.5 + 52, 76)
	c.add_child(l)
	var l2: = V10SalonUI.label("Звёзды копятся — ничего не пропадёт", 18, V10SalonUI.PAPER_500, "body", 700)
	l2.position = Vector2((W - zw) * 0.5 + 52, 166)
	c.add_child(l2)
	return c


func _check_visible() -> void:
	var view: = Rect2(0, scroll.scroll_vertical, W, H)
	var ids: = V10SalonData.zone_ids()
	var vis: = {}
	for zid in zones:
		var zn: V10SalonZone = zones[zid]
		var row: Control = zn.get_parent()
		var r: = Rect2(row.position, row.size)
		vis[zid] = view.intersects(r)
	# the focus zone: the one that fills most of the map between the header and the bottom — only it runs a rig
	var map_r: = Rect2(0, scroll.scroll_vertical + _header_h, W, maxf(1.0, H - _header_h - _bottom_h))
	var focus: = ""
	var best: = 0.0
	for zid in zones:
		var row2: Control = zones[zid].get_parent()
		var a: = map_r.intersection(Rect2(row2.position, row2.size)).get_area()
		if a > best:
			best = a
			focus = zid
	for zid in zones:
		var on: bool = vis[zid]
		var near: = on
		var i: = ids.find(zid)
		for j in [i - 1, i + 1]:
			if j >= 0 and j < ids.size() and vis.get(ids[j], false):
				near = true
		zones[zid].load_textures(near)
		zones[zid].set_visible_live(on, zid == focus)


func _process(dt: float) -> void:
	if scroll == null:
		return
	var v: = (scroll.scroll_vertical - _last_scroll) / maxf(dt, 0.001)
	_last_scroll = scroll.scroll_vertical
	if absf(v) > 1.0:
		for zid in zones:
			zones[zid].scroll_impulse(v)


func _scroll_to(zid: String, animate: = true) -> void:
	await get_tree().process_frame
	if not zones.has(zid):
		_check_visible()
		return
	var row: Control = zones[zid].get_parent()
	# the zone sits between the header and the bottom bar
	var free_h: = H - _header_h - _bottom_h
	var target: = row.position.y - _header_h - maxf(0.0, (free_h - row.size.y) * 0.5)
	target = clampf(target, 0.0, maxf(0.0, list.size.y - H))
	if animate:
		var t: = create_tween()
		t.tween_property(scroll, "scroll_vertical", int(target), 0.45).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		await t.finished
	else:
		scroll.scroll_vertical = int(target)
	_last_scroll = scroll.scroll_vertical
	_check_visible()


# ── bottom ───────────────────────────────────────────────────────────────────────────────────────────────────

func _build_bottom() -> void:
	var shade: = _vgrad(Rect2(0, H - _bottom_h - 50, W, 50), Color(V10SalonUI.NIGHT_900, 0.0), Color(V10SalonUI.NIGHT_900, 1.0), 0.5)
	add_child(shade)
	var band: = ColorRect.new()
	band.color = V10SalonUI.NIGHT_900
	band.position = Vector2(0, H - _bottom_h)
	band.size = Vector2(W, _bottom_h)
	band.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(band)
	var bw: = minf(560.0, W - 64)
	play_btn = V10SalonButton.make("game", "Играть · уровень %d" % V10Salon.next_level(), Rect2((W - bw) * 0.5, H - 32 - 104, bw, 104))
	play_btn.pressed.connect(_on_main)
	add_child(play_btn)
	goal_box = HBoxContainer.new()
	goal_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	goal_box.alignment = BoxContainer.ALIGNMENT_CENTER
	goal_box.position = Vector2(0, H - 32 - 104 - 44)
	goal_box.size = Vector2(W, 30)
	add_child(goal_box)


func _refresh_bottom() -> void:
	for c in goal_box.get_children():
		goal_box.remove_child(c)
		c.queue_free()
	var g: = V10Salon.next_goal()
	var col: = V10SalonUI.PAPER_300
	# ONE main action (UX §3.4 «Салон»): restore the next task when the bank covers it, else play the Path
	_bottom_goal = g if not g.is_empty() and int(g.need) == 0 else {}
	if _bottom_goal.is_empty():
		play_btn.text = "Играть · уровень %d" % V10Salon.next_level()
		play_btn.stars = -1
	else:
		play_btn.text = "Восстановить"
		play_btn.stars = int(g.cost)
	play_btn.queue_redraw()
	if g.is_empty():
		var l: = V10SalonUI.label("Все зоны арки восстановлены" if V10Salon.all_released_done() else "", 18, V10SalonUI.JADE_300, "body", 700)
		goal_box.add_child(l)
		return
	if int(g.need) == 0:
		goal_box.add_child(V10SalonUI.label("Можно восстановить: «%s»" % g.name, 18, V10SalonUI.GOLD_300, "body", 800))
		return
	var l1: = V10SalonUI.label("ещё %d" % g.need, 18, col, "body", 800)
	goal_box.add_child(l1)
	goal_box.add_child(_goal_star())
	goal_box.add_child(V10SalonUI.label(" до «%s»" % g.name, 18, col, "body", 700))


# the drawn ★ of the goal line, centred on the text's x-height (a bare icon in an HBox sits on the top edge)
func _goal_star() -> Control:
	var c: = CenterContainer.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.custom_minimum_size = Vector2(18, 26)
	c.add_child(V10SalonUI.star_icon(15, V10SalonUI.GOLD_300))
	return c


# public: re-read the save (stars changed while the screen is open: app resumed, a debug grant)
func refresh() -> void:
	V10Salon.reset_cache()
	V10Salon.repair()
	shown_bank = V10Salon.bank()
	bank_lbl.text = str(shown_bank)
	for zid in zones:
		zones[zid].refresh()
	_refresh_bottom()


func _on_main() -> void:
	if busy:
		return
	if _bottom_goal.is_empty():
		_play()
	else:
		_do_restore(str(_bottom_goal.zid), str(_bottom_goal.tid))


func _vgrad(r: Rect2, a: Color, b: Color, mid: = 0.5) -> TextureRect:
	var g: = Gradient.new()
	g.set_color(0, a)
	g.set_color(1, b)
	g.add_point(mid, a.lerp(b, 0.75))
	var gt: = GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 4
	gt.height = 128
	var tr: = TextureRect.new()
	tr.texture = gt
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.position = r.position
	tr.size = r.size
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


# ── intro ────────────────────────────────────────────────────────────────────────────────────────────────────

func _show_intro() -> void:
	var g: = V10Salon.next_goal()
	if g.is_empty():
		V10Salon.intro_done()
		return
	if zones.has(g.zid):
		zones[g.zid].hint_tid = g.tid
		zones[g.zid].refresh(true)
	# her line as Voice text over the map (no bubble box, UX §6.3), with a soft shade behind it
	intro_plate = Control.new()
	intro_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	intro_plate.position = Vector2(0, H - _bottom_h - 150)
	intro_plate.size = Vector2(W, 150)
	intro_plate.z_index = 20
	var sh: = _vgrad(Rect2(0, 0, W, 150), Color(V10SalonUI.NIGHT_900, 0.0), Color(V10SalonUI.NIGHT_900, 0.92), 0.45)
	intro_plate.add_child(sh)
	var who: = V10SalonUI.label("Маджонг-тян", 18, V10SalonUI.ROSE_300, "body", 800, 0.6)
	who.position = Vector2(32, 36)
	intro_plate.add_child(who)
	var l: = V10SalonUI.label(V10Salon.intro_text(), 30, V10SalonUI.PAPER_100, "italic", 500, 0.8)
	l.position = Vector2(32, 62)
	l.size = Vector2(W - 64, 84)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.visible_ratio = 0.0
	intro_plate.add_child(l)
	add_child(intro_plate)
	var t: = create_tween()
	t.tween_property(l, "visible_ratio", 1.0, 0.4 + 0.01 * l.text.length())


func _hide_intro() -> void:
	if intro_plate and is_instance_valid(intro_plate):
		var p: = intro_plate
		intro_plate = null
		var t: = p.create_tween()
		t.tween_property(p, "modulate:a", 0.0, 0.3)
		t.tween_callback(p.queue_free)
	for zid in zones:
		if zones[zid].hint_tid != "":
			zones[zid].hint_tid = ""
			zones[zid].refresh()
	V10Salon.intro_done()


# ── actions ──────────────────────────────────────────────────────────────────────────────────────────────────

func _on_task(zid: String, tid: String) -> void:
	if busy or (sheet and is_instance_valid(sheet)):
		return
	# one layer at a time (П-6): a toast left from the header «?» does not hang over the sheet
	for c in toast_box.get_children():
		c.queue_free()
	sheet = V10SalonSheet.open(self, zid, tid)
	sheet.restore.connect(func(t): _do_restore(zid, t))
	sheet.finish.connect(func(t, v): _do_finish(zid, t, v))
	sheet.play.connect(_play)


func _do_restore(zid: String, tid: String) -> void:
	if busy:
		return
	var before: = V10Salon.bank()
	var res: = V10Salon.restore(zid, tid)
	if not res.ok:
		V9Feel.deny(play_btn)
		toast("Не хватает звёзд — сыграй уровень Пути")
		return
	busy = true
	_hide_intro()
	var zn: V10SalonZone = zones[zid]
	var cost: = int(V10SalonData.task(zid, tid).cost)
	await _scroll_to(zid, true)
	if not is_inside_tree():
		return
	var to: = zn.get_global_transform() * zn.task_center(tid) - get_global_transform().origin
	var done_flight: = [false]
	var after: = V10Salon.bank()
	V10SalonFx.star_flight(self, bank_center(), to, cost, func(i):
		shown_bank = before - int(round(float(i + 1) / mini(cost, 12) * cost))
		bank_lbl.text = str(maxi(after, shown_bank))
		V9Feel.press(bank_box, "", "tap"), func(): done_flight[0] = true)
	while not done_flight[0]:
		if not is_inside_tree():
			return
		await get_tree().process_frame
	shown_bank = after
	bank_lbl.text = str(after)
	await zn.play_restore(tid)
	if not is_inside_tree():
		return
	for k in zones:
		zones[k].refresh()
	_refresh_bottom()
	if res.zone_done:
		await get_tree().create_timer(0.35).timeout
		if not is_inside_tree():
			return
		await _do_finale(zid)
	busy = false


func _do_finish(zid: String, tid: String, variant: String) -> void:
	var before: = V10Salon.bank()
	var res: = V10Salon.set_finish(zid, tid, variant)
	if not res.ok:
		if res.reason == "season":
			toast("Сезонная отделка входит в пропуск сезона")
		return
	var zn: V10SalonZone = zones[zid]
	if int(res.paid) > 0:
		var to: = zn.get_global_transform() * zn.task_center(tid) - get_global_transform().origin
		V10SalonFx.star_flight(self, bank_center(), to, int(res.paid), func(_i): pass, func(): pass)
		V10SalonFx.roll(bank_lbl, before, V10Salon.bank(), 0.06 * mini(int(res.paid), 12) + 0.5)
	zn.play_finish(tid, variant)
	if V10Salon.zone_state(zid) == "jade":
		toast("«%s» — вся в нефрите" % V10SalonData.zone(zid).name)
	_refresh_bottom()


func _do_finale(zid: String) -> void:
	var zn: V10SalonZone = zones[zid]
	await zn.play_finale()
	var rewards: = V10Salon.claim_chest(zid)
	# the ceremony brings her own rig: the map under it holds still, back to stills (UX Г-4: one rig on screen);
	# closing the finale rebuilds the map (_fill) and the focus zone gets its rig again
	for k in zones:
		zones[k].set_visible_live(false)
	finale = V10SalonFinale.open(self, zid, rewards)
	finale.scene.connect(func(): _open_scene(zid))
	finale.play.connect(_play)
	finale.closed.connect(func():
		# the next zone opens above: rebuild the map and glide to it
		_fill()
		_scroll_to.call_deferred(V10Salon.current_zone(), false)
		_refresh_bottom())
	if main != null and main.has_method("refresh_currency"):
		main.refresh_currency()


func _on_heroine(zid: String, zone: String) -> void:
	var hero: String = V10SalonData.zone(zid).hero
	# her voice in her zone, no box (UX §6.3); torso / outfit → a neutral glance only (§8.2)
	zones[zid].say(V10Salon.tap_line(hero, zone))


func _open_scene(zid: String) -> void:
	if main != null and main.has_method("go"):
		main.go("v10scene", {"zone": zid})


func _play() -> void:
	if main != null and main.has_method("go"):
		var nav: = V10Salon.global_class("V10Nav")
		if nav != null and nav.has_method("play_path") and "screen_id" in main:
			nav.call("play_path", main)
			return
		main.go("levels")


func _back() -> void:
	if sheet and is_instance_valid(sheet):
		sheet.close()
		return
	if finale and is_instance_valid(finale):
		finale._close(Callable())
		return
	if main != null and main.has_method("back"):
		main.back()


func toast(text: String) -> void:
	for c in toast_box.get_children():
		c.queue_free()
	var w: = minf(W - 64, V10SalonUI.text_w(text, 18, "body", 700) + 56)
	var lines: = 1 if V10SalonUI.text_w(text, 18, "body", 700) + 56 <= W - 64 else 2
	var h: = 64.0 if lines == 1 else 92.0
	var p: = V10SalonUI.panel(Rect2((W - w) * 0.5, _header_h + 12, w, h), Color(V10SalonUI.NIGHT_700, 0.97), 4.0, Color(V10SalonUI.GOLD_700, 0.5), 1)
	var l: = V10SalonUI.label(text, 18, V10SalonUI.PAPER_100, "body", 700)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size = Vector2(w - 32, h)
	l.position = Vector2(16, 0)
	p.add_child(l)
	p.modulate.a = 0.0
	toast_box.add_child(p)
	var t: = p.create_tween()
	t.tween_property(p, "modulate:a", 1.0, 0.18)
	t.parallel().tween_property(p, "position:y", p.position.y, 0.24).from(p.position.y - 12).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	# long enough to read: ≈ 15 characters a second, 2.6…5 s
	t.tween_interval(clampf(0.8 + text.length() / 15.0, 2.6, 5.0))
	t.tween_property(p, "modulate:a", 0.0, 0.3)
	t.tween_callback(p.queue_free)


# «Вдох»: header and bottom breathe in (240 ms, +12 px, step 40 ms) — UX §6.7
func _enter() -> void:
	var items: = [bank_box, help_btn, play_btn, goal_box]
	var i: = 0
	for n in items:
		var c: Control = n
		var y: = c.position.y
		c.modulate.a = 0.0
		var t: = c.create_tween()
		t.tween_interval(0.04 * i)
		t.tween_property(c, "modulate:a", 1.0, 0.24)
		t.parallel().tween_property(c, "position:y", y, 0.24).from(y + 12).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		i += 1


# ── dev hooks for the runner / playtests ─────────────────────────────────────────────────────────────────────

func dev_act(name: String) -> void:
	var g: = V10Salon.next_goal()
	match name:
		"open_sheet":
			if not g.is_empty():
				_on_task(g.zid, g.tid)
		"restore_first":
			if not g.is_empty():
				await _do_restore(g.zid, g.tid)
		"close_sheet":
			if sheet and is_instance_valid(sheet):
				sheet.close()
		"close_finale":
			if finale and is_instance_valid(finale):
				finale._close(Callable())
		"help":
			_help()
		"main":
			_on_main()
		_:
			if name.begins_with("scroll:"):
				await _scroll_to(name.substr(7), true)
			elif name.begins_with("sheet:"):
				var p: = name.substr(6).split("/")
				_on_task(p[0], p[1])
			elif name.begins_with("say:"):
				var r: = name.substr(4).split("/")
				_on_heroine(r[0], r[1] if r.size() > 1 else "head")
			elif name.begins_with("jade:"):
				var q: = name.substr(5).split("/")
				_do_finish(q[0], q[1], "jade")
