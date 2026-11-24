class_name V10StickerTray
extends Control

# Sticker tray (§Р8 п.7): 8 common stickers and 8 of each heroine the player owns. A heroine's pack opens partly at
# once and fully from affection level 5 (locked ones are shown greyed with «Симпатия 5», never with a price).
# Tabs: «Общие» + one per owned heroine (the open chat's heroine first). Tap = the sticker jumps into the chat.

signal picked(id: String)
signal closed

const P: = preload("res://scripts/v10/phone/phone.gd")
const PUI: = preload("res://scripts/v10/phone/phone_ui.gd")
const C: = preload("res://scripts/v10/chat/chat.gd")
const D: = preload("res://scripts/v10/chat/chat_data.gd")

var W: = 600.0
var TH: = 560.0
var hero: = ""
var tab: = ""
var grid: Control
var tabs_row: Control
var shade: Control


func build(w: float, h: float, hero_id: String) -> void:
	W = w
	TH = h
	hero = hero_id
	size = Vector2(W, TH)
	name = "StickerTray"
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg: = PUI.panel(Rect2(0, 0, W, TH + 40), PUI.box(Color(0.12, 0.085, 0.11, 0.99), 34, 2.0, Color(PUI.GOLD, 0.45), 18, Color(0, 0, 0, 0.55)))
	add_child(bg)
	var grip: = PUI.panel(Rect2(W * 0.5 - 36, 10, 72, 7), PUI.box(Color(1, 1, 1, 0.25), 4))
	add_child(grip)
	tabs_row = Control.new()
	tabs_row.position = Vector2(14, 26)
	tabs_row.size = Vector2(W - 28, 64)
	add_child(tabs_row)
	grid = Control.new()
	grid.position = Vector2(0, 100)
	grid.size = Vector2(W, TH - 100)
	add_child(grid)
	var packs: = _packs()
	tab = hero if hero in packs else "common"
	_tabs(packs)
	_grid()


func _packs() -> Array:
	var out: = ["common"]
	var own: Array = P.ctx().owned
	if hero in own:
		out.append(hero)
	for h in D.HEROES:
		if h in own and not h in out:
			out.append(h)
	return out


func _tabs(packs: Array) -> void:
	for c in tabs_row.get_children():
		c.queue_free()
	var x: = 0.0
	for p in packs:
		var on: bool = p == tab
		var c: = Control.new()
		c.position = Vector2(x, 4)
		c.size = Vector2(64, 56)
		c.pivot_offset = c.size * 0.5
		c.add_child(PUI.panel(Rect2(Vector2.ZERO, c.size), PUI.box(Color(1, 1, 1, 0.13) if on else Color(1, 1, 1, 0.03), 18, 2.0 if on else 0.0, Color(PUI.GOLD, 0.8))))
		var first: Dictionary = D.stickers().get(p, [{}])[0] if not D.stickers().get(p, []).is_empty() else {}
		var t: = P.sticker_tex(str(first.get("id", "")))
		if t != null:
			var tr: = TextureRect.new()
			tr.texture = t
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.position = Vector2(4, 2)
			tr.size = Vector2(56, 52)
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			c.add_child(tr)
		else:
			var l: = PUI.label(str(first.get("glyph", "★")), 28, PUI.GOLD, PUI.body(900))
			l.size = c.size
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			c.add_child(l)
		if not on:
			c.modulate = Color(1, 1, 1, 0.6)
		tabs_row.add_child(c)
		var pid: String = p
		PUI.tap(c, func():
			tab = pid
			PUI.snd("tab")
			_tabs(packs)
			_grid(), "")
		x += 74.0
	var cap: = PUI.label("Общие" if tab == "common" else P.hero_name(tab), 22, PUI.MUTED, PUI.body(800))
	cap.position = Vector2(x + 8, 18)
	cap.size = Vector2(maxf(40.0, tabs_row.size.x - x - 60), 30)
	cap.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	cap.size = Vector2(maxf(40.0, tabs_row.size.x - x - 60), 30)
	PUI.ellipsize(cap, maxf(40.0, tabs_row.size.x - x - 60))
	tabs_row.add_child(cap)
	var close: = Control.new()
	close.position = Vector2(tabs_row.size.x - 52, 4)
	close.size = Vector2(52, 56)
	close.pivot_offset = close.size * 0.5
	var xl: = PUI.label("✕", 28, PUI.MUTED, PUI.body(900))
	xl.size = close.size
	xl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	xl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	close.add_child(xl)
	tabs_row.add_child(close)
	PUI.tap(close, dismiss, "tap")


func _grid() -> void:
	for c in grid.get_children():
		c.queue_free()
	var all: Array = D.stickers().get(tab, [])
	var ctx: = P.ctx()
	var lv: = int(ctx.levels.get(tab, 1)) if tab != "common" else 99
	var cols: = 4
	var cell: = minf((W - 28) / cols, (grid.size.y - 10) / 2.0)
	var x0: = (W - cell * cols) * 0.5
	for i in all.size():
		var s: Dictionary = all[i]
		var locked: bool = lv < int(s.get("level", 1))
		var c: = Control.new()
		c.name = "St_" + str(s.id)
		c.position = Vector2(x0 + (i % cols) * cell, (i / cols) * cell)
		c.size = Vector2(cell, cell)
		c.pivot_offset = c.size * 0.5
		var t: = P.sticker_tex(str(s.id))
		if t != null:
			var tr: = TextureRect.new()
			tr.texture = t
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.position = Vector2(6, 4)
			tr.size = Vector2(cell - 12, cell - 12)
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			c.add_child(tr)
		else:
			c.add_child(PUI.panel(Rect2(10, 10, cell - 20, cell - 20), PUI.box(Color(P.hero_color(tab) if tab != "common" else Color("e3a1b0"), 0.85), (cell - 20) * 0.5, 3.0, Color.WHITE)))
			var g: = PUI.label(str(s.get("glyph", "")), 40, Color.WHITE, PUI.body(900))
			g.size = c.size
			g.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			g.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			c.add_child(g)
		if locked:
			c.modulate = Color(0.45, 0.42, 0.48, 0.75)
			var lk: = PUI.label("Симпатия %d" % int(s.get("level", 5)), 17, Color.WHITE, PUI.body(900), 4, Color(0, 0, 0, 0.8))
			lk.size = Vector2(cell, 30)
			lk.position = Vector2(0, cell - 36)
			lk.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			c.add_child(lk)
		grid.add_child(c)
		PUI.pop_in(c, 0.02 * i, 0.7, 0.3)
		var sid: = str(s.id)
		if locked:
			PUI.tap(c, func(): V9Feel.deny(c), "")
		else:
			PUI.tap(c, func():
				picked.emit(sid)
				dismiss(), "")


func slide_in(parent_h: float) -> void:
	shade = Control.new()
	shade.size = Vector2(W, parent_h)
	shade.position = Vector2(0, -parent_h)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim: = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.35)
	dim.size = shade.size
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.add_child(dim)
	add_child(shade)
	move_child(shade, 0)
	shade.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			dismiss())
	shade.position.y = -(parent_h - TH)
	shade.size.y = parent_h - TH
	PUI.snd("tab")
	var t: = create_tween()
	t.tween_property(self, "position:y", parent_h - TH, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func dismiss() -> void:
	if has_meta("closing"):
		return
	set_meta("closing", true)
	var t: = create_tween()
	t.tween_property(self, "position:y", position.y + TH + 40, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.tween_callback(func():
		closed.emit()
		queue_free())
