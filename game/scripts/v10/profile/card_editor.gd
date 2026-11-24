class_name V10CardEditor
extends Control

# V10CardEditor — «Оформить карточку» (docs/0.10-spec.md §D5): a full-screen sheet with the live preview
# «Так тебя видят другие» on top and tabs Рамка · Титул · Витрина · Фон · Значки. Locked cells are grey with their
# «откроется …» line and answer a tap with V9Feel.deny + the hint; unlocked cells press, apply and sweep the preview.
# New unlocks carry a dot until seen. Nothing is sold here (Lavka frames show their «Лавка · N кр» hint only).
#
#   var ed: = V10CardEditor.open(parent, G.S, func(changed): G.save(); ...)
#     parent  any full-screen Control (main.overlay)
#     S       the save dictionary: S.profile is edited only on «Сохранить» (V10ProfileCos.select per slot),
#             S.v10_cos_seen gets every cell the player looked at
#     on_done(changed: bool) after «Сохранить» / «Отмена»
# Dev: --card_editor_tab=<frame|title|showcase|bg|badges> opens on that tab.

signal done(changed: bool)

const TABS: = [["frame", "Рамка"], ["title", "Титул"], ["showcase", "Витрина"], ["bg", "Фон"], ["badges", "Значки"]]
const W: = 720.0

var S: Dictionary
var ctx: Dictionary
var work: Dictionary
var tab: = "frame"
var sheet: Control
var preview_host: Control
var preview: V10CardView
var tab_btns: = {}
var scroll: ScrollContainer
var grid: Control
var hint: Label
var on_done: Callable
var _closing: = false


static func open(parent: Control, save: Dictionary, cb: Callable = Callable()) -> V10CardEditor:
	var ed: = V10CardEditor.new()
	ed.S = save
	ed.on_done = cb
	ed.size = parent.size if parent.size != Vector2.ZERO else Vector2(720, 1280)
	ed.mouse_filter = Control.MOUSE_FILTER_STOP
	ed.name = "V10CardEditor"
	parent.add_child(ed)
	ed._build()
	return ed


func _build() -> void:
	ctx = V10ProfileCos.ctx_from_save(S)
	work = V10ProfileCos.defaults()
	var p = S.get("profile", {})
	if p is Dictionary:
		for k in ["nick", "avatar", "frame", "title", "badges", "card_bg", "showcase"]:
			if p.has(k):
				work[k] = (p[k] as Variant)
		work.badges = (work.get("badges", []) as Array).duplicate()
		work.showcase = (work.get("showcase", {}) as Dictionary).duplicate()
	V10ProfileCos.sanitize(work, ctx)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--card_editor_tab="):
			tab = a.get_slice("=", 1)
	var dim: = ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.035, 0.0)
	dim.size = size
	add_child(dim)
	dim.create_tween().tween_property(dim, "color:a", 0.7, 0.25)
	var x0: = (size.x - W) * 0.5
	sheet = Control.new()
	sheet.position = Vector2(x0, 0)
	sheet.size = Vector2(W, size.y)
	add_child(sheet)
	var panel: = V8Art.nine("panel", Rect2(12, 40, W - 24, size.y - 56))
	sheet.add_child(panel)
	var cap: = UI.label("Так тебя видят другие", 22, Color("f1dcae"), UI.DARK, 3, "body", 900)
	UI.center_label(cap, Rect2(0, 66, W, 30))
	sheet.add_child(cap)
	preview_host = Control.new()
	preview_host.position = Vector2((W - 343.0) * 0.5, 102)
	preview_host.size = Vector2(343, 458)
	preview_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet.add_child(preview_host)
	_rebuild_preview(false)
	var tw: = (W - 64.0 - 4 * 8.0) / 5.0
	for i in TABS.size():
		var id: String = TABS[i][0]
		var b: = JButton.make(TABS[i][1], "plum", Rect2(32 + i * (tw + 8), 576, tw, 58), null, 20, 22.0, false)
		b.pressed.connect(_set_tab.bind(id))
		sheet.add_child(b)
		tab_btns[id] = b
	scroll = ScrollContainer.new()
	scroll.position = Vector2(32, 646)
	scroll.size = Vector2(W - 64, size.y - 646 - 150)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sheet.add_child(scroll)
	hint = UI.label("", 18, UI.MUTED, UI.DARK, 2, "body", 800)
	UI.center_label(hint, Rect2(32, size.y - 146, W - 64, 30))
	sheet.add_child(hint)
	var bw: = (W - 64.0 - 16.0) * 0.5
	var cancel: = JButton.make("Отмена", "graphite", Rect2(32, size.y - 108, bw, 76), null, 26)
	cancel.pressed.connect(_finish.bind(false))
	sheet.add_child(cancel)
	var save_b: = JButton.make("Сохранить", "gold", Rect2(48 + bw, size.y - 108, bw, 76), null, 28)
	save_b.shine_every = 3.5
	save_b.pressed.connect(_finish.bind(true))
	sheet.add_child(save_b)
	_set_tab(tab if tab in TABS.map(func(t): return t[0]) else "frame")
	if V10FrameView.fx_on():
		sheet.position.y = 60.0
		sheet.modulate.a = 0.0
		var t: = sheet.create_tween().set_parallel()
		t.tween_property(sheet, "position:y", 0.0, 0.32).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		t.tween_property(sheet, "modulate:a", 1.0, 0.2)


func payload() -> Dictionary:
	var p: = V10CardPayload.mine({"profile": work, "rp": S.get("rp", 0), "owned": S.get("owned", {}), "shards": S.get("shards", {}),
		"aff": S.get("aff", {}), "stats": S.get("stats", {}), "skin": S.get("skin", "s_sakura"), "ostars": S.get("ostars", {}),
		"v10_cos_owned": S.get("v10_cos_owned", {}), "v10_feats": S.get("v10_feats", {}), "v10_levels": S.get("v10_levels", {}),
		"v10_streak": S.get("v10_streak", {}), "v10_seasons": S.get("v10_seasons", {}), "v10_heroes": S.get("v10_heroes", {})})
	return p


func _rebuild_preview(wave: bool) -> void:
	if preview and is_instance_valid(preview):
		preview.queue_free()
	preview = V10CardView.make(payload(), Rect2(Vector2.ZERO, preview_host.size), "other", {"interactive": false, "anim": false})
	preview_host.add_child(preview)
	if wave and V10FrameView.fx_on():
		preview.sweep(0.55, 0.24)
		var k: = preview.scale
		preview.scale = k * 0.97
		preview.create_tween().tween_property(preview, "scale", k, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _set_tab(id: String) -> void:
	tab = id
	for k in tab_btns:
		var b: JButton = tab_btns[k]
		if k == id:
			b.box.colors(Color("f6dfa0"), Color("b07a2a"))
			b.lbl.label_settings.font_color = Color("2b1a08")
		else:
			b.box.colors(UI.PAL.plum[0], UI.PAL.plum[1])
			b.lbl.label_settings.font_color = UI.INK
	_fill()


func _say(text: String, warn: = false) -> void:
	hint.text = text
	hint.label_settings.font_color = Color("ffb0a0") if warn else UI.MUTED


# ------------------------------------------------------------------------------------------------ grid

func _fill() -> void:
	if grid and is_instance_valid(grid):
		grid.queue_free()
	grid = Control.new()
	grid.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.add_child(grid)
	scroll.scroll_vertical = 0
	var items: = _items()
	var cols: = 3 if tab in ["showcase", "bg"] else (2 if tab == "title" else 4)
	var cw: = scroll.size.x / cols
	var ch: float = {"frame": 168.0, "title": 92.0, "showcase": 250.0, "bg": 190.0, "badges": 168.0}[tab]
	for i in items.size():
		var it: Dictionary = items[i]
		var r: = Rect2((i % cols) * cw, (i / cols) * ch, cw, ch)
		_cell(it, r)
	grid.custom_minimum_size = Vector2(scroll.size.x, ceil(items.size() / float(cols)) * ch + 12)
	var unl: = items.filter(func(x): return x.ok).size()
	_say("Открыто %d из %d" % [unl, items.size()] if tab != "badges" else "Выбери до трёх значков · открыто %d из %d" % [unl, items.size()])


# [{id, ok, sel, new}] — unlocked first (catalog order), then locked
func _items() -> Array:
	var out: = []
	var seen = S.get("v10_cos_seen", {})
	if tab == "showcase":
		for h in G.HERO_ORDER:
			for it in G.ITEMS:
				if String(it.get("cat", "")) != "outfit" or String(it.get("hero", "")) != h or bool(it.get("hidden", false)):
					continue
				var ok: = V10ProfileCos.outfit_ok(h, String(it.id), ctx) == ""
				out.append({"id": String(it.id), "hero": h, "ok": ok, "sel": String(work.showcase.get("outfit", "")) == String(it.id), "new": false})
	else:
		var kind: String = {"frame": "frame", "title": "title", "bg": "bg", "badges": "badge"}[tab]
		for e in V10ProfileCos.all(kind):
			var ok: = V10ProfileCos.is_unlocked(String(e.id), ctx)
			var sel: = false
			match tab:
				"frame": sel = work.frame == e.id
				"title": sel = work.title == e.id
				"bg": sel = work.card_bg == e.id
				"badges": sel = String(e.id) in work.badges
			var is_new: bool = ok and String(e.src.type) != "default" and not (seen is Dictionary and seen.has(e.id))
			out.append({"id": String(e.id), "ok": ok, "sel": sel, "new": is_new})
	var a: = out.filter(func(x): return x.ok)
	var b: = out.filter(func(x): return not x.ok)
	return a + b


func _cell(it: Dictionary, r: Rect2) -> void:
	var c: = Control.new()
	c.position = r.position + Vector2(4, 4)
	c.size = r.size - Vector2(8, 8)
	c.pivot_offset = c.size * 0.5
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	c.name = "Cell_" + String(it.id)
	grid.add_child(c)
	var bgb: = UI.rbox("glass", Rect2(Vector2.ZERO, c.size), 18, 2 if not it.sel else 3, 5)
	if it.sel:
		bgb.colors(Color(0.33, 0.25, 0.15, 0.92), Color(0.17, 0.12, 0.08, 0.94)).borders(Color("ffe7a6"), Color("b07a2a"))
		bgb.set_param("glow", 0.5)
	else:
		bgb.borders(Color(1, 0.9, 0.7, 0.22), Color(0, 0, 0, 0.3))
	c.add_child(bgb)
	var name_txt: = ""
	var e: = V10ProfileCos.entry(String(it.id))
	match tab:
		"frame":
			var f: = V10FrameView.make(String(it.id), String(work.get("avatar", "mc")), 112.0, {"anim": false, "glow": it.ok})
			f.position = Vector2((c.size.x - 112.0) * 0.5, 4)
			f.set_locked(not it.ok)
			c.add_child(f)
			name_txt = String(e.name)
		"title":
			var tc: = V10ProfileCos.tier_col(String(e.tier)) if it.ok else Color(0.6, 0.58, 0.62)
			var l: = UI.label(String(e.name), 21, tc, UI.DARK, 3, "body", 900)
			UI.center_label(l, Rect2(8, 8, c.size.x - 16, 40))
			Common.fit_line(l, c.size.x - 16, 15)
			c.add_child(l)
		"badges":
			var m: = V10CardView.medal(String(it.id), Rect2((c.size.x - 96.0) * 0.5, 8, 96, 96))
			if not it.ok:
				m.modulate = Color(0.45, 0.44, 0.48, 0.75)
			c.add_child(m)
			name_txt = String(e.name)
			if it.sel:
				var k: int = work.badges.find(String(it.id)) + 1
				var dot: = UI.rbox("gold", Rect2(c.size.x - 40, 6, 32, 32), 16, 2, 4)
				dot.add_child(UI.center_label(UI.label(str(k), 18, Color("2b1a08"), Color(0, 0, 0, 0), 0, "body", 900), Rect2(0, -1, 32, 32)))
				c.add_child(dot)
		"bg":
			var t: Texture2D = load(String(e.tex))
			var fc: Array = e.get("focus", [0.5, 0.4])
			var a: = Common.card_art(t, Rect2(8, 8, c.size.x - 16, c.size.y - 56), Vector2(fc[0], fc[1]), 1.0, 12)
			(a.material as ShaderMaterial).set_shader_parameter("gray", 0.0 if it.ok else 0.85)
			(a.material as ShaderMaterial).set_shader_parameter("bottom_shade", 0.2)
			c.add_child(a)
			name_txt = String(e.name)
		"showcase":
			var img: = V10ProfileCos.showcase_img(String(it.id), bool(S.get("modest", false)))
			var t2: Texture2D = load("res://assets/outfits/%s.webp" % img)
			var fc2: Array = V8Population.face(img)
			var a2: = Common.card_art(t2, Rect2(8, 8, c.size.x - 16, c.size.y - 56), Vector2(float(fc2[0]), float(fc2[1]) + 0.2), 1.3, 12)
			(a2.material as ShaderMaterial).set_shader_parameter("gray", 0.0 if it.ok else 0.85)
			c.add_child(a2)
			name_txt = String(G.ITEM[String(it.id)].name)
	if name_txt != "":
		var nl: = UI.label(name_txt, 15, UI.INK if it.ok else UI.MUTED, UI.DARK, 2, "body", 900)
		UI.center_label(nl, Rect2(4, c.size.y - 44, c.size.x - 8, 20))
		nl.clip_text = true
		nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		c.add_child(nl)
	var sub: = ""
	if not it.ok:
		sub = V10ProfileCos.hint(String(it.id)) if tab != "showcase" else V10ProfileCos.outfit_ok(String(it.hero), String(it.id), ctx)
	elif tab == "title":
		sub = String(V10ProfileCos.hint(String(it.id)))
	if sub != "":
		var sl: = UI.label(sub, 13, Color(0.8, 0.75, 0.7, 0.85), UI.DARK, 2, "body", 800)
		UI.center_label(sl, Rect2(4, c.size.y - 24, c.size.x - 8, 18))
		sl.clip_text = true
		sl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		c.add_child(sl)
	if not it.ok:
		var lk: = V8Art.rect(V8Art.icon("lock"), Rect2(c.size.x - 38, 6, 30, 30))
		lk.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.add_child(lk)
	if it.new:
		var nd: = UI.rbox("red", Rect2(8, 8, 16, 16), 8, 2, 3)
		nd.name = "NewDot"
		c.add_child(nd)
	c.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and not ev.pressed:
			if Rect2(Vector2.ZERO, c.size).has_point(ev.position):
				_tap(it, c))


func _tap(it: Dictionary, c: Control) -> void:
	if not it.ok:
		V9Feel.deny(c)
		_say(V10ProfileCos.hint(String(it.id)) if tab != "showcase" else V10ProfileCos.outfit_ok(String(it.hero), String(it.id), ctx), true)
		return
	V9Feel.press(c, "pop", "button")
	if tab != "showcase":
		V10ProfileCos.mark_seen(S, String(it.id))
	var err: = ""
	match tab:
		"frame":
			err = V10ProfileCos.select(work, "frame", it.id, ctx)
		"title":
			err = V10ProfileCos.select(work, "title", it.id, ctx)
			if err == "" and V10FrameView.fx_on():
				Fx.burst(self, c.global_position - global_position + c.size * 0.5, "sparkle", 10, V10ProfileCos.tier_col(String(V10ProfileCos.entry(String(it.id)).tier)), 0.4)
		"bg":
			err = V10ProfileCos.select(work, "card_bg", it.id, ctx)
		"showcase":
			err = V10ProfileCos.select(work, "showcase", {"hero": it.hero, "outfit": it.id, "pose": "base"}, ctx)
			if err == "":
				work.avatar = String(it.hero)
		"badges":
			var list: Array = work.badges.duplicate()
			if String(it.id) in list:
				list.erase(String(it.id))
			elif list.size() >= V10ProfileCos.BADGE_SLOTS:
				V9Feel.deny(c)
				_say("Уже выбрано три значка: сними один", true)
				return
			else:
				list.append(String(it.id))
			err = V10ProfileCos.select(work, "badges", list, ctx)
	if err != "":
		V9Feel.deny(c)
		_say(err, true)
		return
	_rebuild_preview(true)
	var sv: = scroll.scroll_vertical
	_fill()
	scroll.set_deferred("scroll_vertical", sv)


func _finish(save: bool) -> void:
	if _closing:
		return
	_closing = true
	var changed: = false
	if save:
		if not (S.get("profile") is Dictionary):
			S["profile"] = {}
		var p: Dictionary = S.profile
		for k in ["frame", "title", "badges", "card_bg", "showcase", "avatar"]:
			if JSON.stringify(p.get(k)) != JSON.stringify(work.get(k)):
				changed = true
			p[k] = work[k]
		V10ProfileCos.sanitize(p, ctx)
		if changed:
			V9Feel.success(null, "sparkle")
	var t: = create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.2)
	await t.finished
	done.emit(changed)
	if on_done.is_valid():
		on_done.call(changed)
	queue_free()
