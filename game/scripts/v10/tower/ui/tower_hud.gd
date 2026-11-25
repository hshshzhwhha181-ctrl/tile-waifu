class_name V10TowerHud
extends Control

# V10TowerHud — the mode line of a tower match (Пагода Луны / Странствие): one S plate, 48 px, ≤ 8 words.
#   Pagoda:   «Этаж 7» · lanterns (lit / out, up to 5) · ember «Жар 12» · [clock «1:24»]
#   Journey:  «Стол 3 из 5» · 3 hearts · [clock «1:24»]          (practice: «Тренировка · Стол 3 из 5»)
# The clock shows only with the hourglass curse; the last 10 s are ember (V10DS.EMBER).
# Motion only on events (UX §6.7): a lantern goes out with an exhale (300 ms, it drops 8 px and stays there),
# a heart cracks (shake 240 ms, then empty with the crack), the heat chip flares. fx_level «min»: every change
# is a 120 ms fade, the information stays. Two type roles only: UI 22 and Numerals 22 (UX §3.7 «партия»).
#
#   var hud := V10TowerHud.new(); screen.add_child(hud); hud.place(Rect2(10, 318, 700, 48))
#   hud.configure("pagoda", run)        # reads run.floor / lives / curses — or run.board / hearts (journey, practice)
#   hud.lose_life(index)                # lantern / heart `index` (0-based; = the new number of lives) goes out
#   hud.set_clock("1:24", danger)       # "" hides the clock
#   hud.flash_heat()                    # the tower added a curse («вспыхнул Жар»)
#   hud.compact = true                  # HUD v2: no title, V10HudMatch's status line says «Этаж 7 · Осталось 30»
#   V10TowerHud.status_text(mode, run)  # that title, for V10HudMatch.configure({"level": …})
#   V10TowerHud.preferred_width(mode, run, compact) # the plate width the content needs

const P: = preload("res://scripts/v10/tower/pagoda.gd")
const J: = preload("res://scripts/v10/tower/journey.gd")
const M: = preload("res://scripts/v10/tower/mods.gd")
const UI_T: = preload("res://scripts/v10/tower/ui/tower_ui.gd")
const ART: = preload("res://scripts/v10/tower/ui/tower_art.gd")

const PLATE_H: = 48.0
const PAD: = 16.0
const GAP: = 16.0
const LANTERN_H: = 30.0
const LANTERN_STEP: = 26.0
const HEART_S: = 24.0
const HEART_STEP: = 30.0
const ICON: = 24.0
const EXHALE: = 0.3
const DROP: = 8.0
const CALM_FADE: = 0.12
const LIVES_CAP: = 5

var mode: = "pagoda"
var run: Dictionary = {}
var compact: = false:
	set(v):
		compact = v
		if is_inside_tree():
			_layout()
var lives: = 3
var slots_n: = 3
var heat: = 0

var title_l: Label
var heat_l: Label
var clock_l: Label
var heat_box: Control
var heat_icon: Control
var life_nodes: Array = []
var _lit: Array = []
var _full: Array = []
var _broken: Array = []
var _clock: = ""
var _danger: = false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(700, PLATE_H)
	custom_minimum_size = Vector2(0, PLATE_H)
	title_l = V10Type.label("", "ui", 22, V10DS.PAPER_100)
	add_child(title_l)
	heat_box = Control.new()
	heat_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(heat_box)
	heat_l = V10Type.label("", "ui", 22, V10DS.GOLD_300)
	heat_box.add_child(heat_l)
	clock_l = V10Type.label("", "num", 22, V10DS.PAPER_100)
	clock_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	clock_l.visible = false
	add_child(clock_l)


func place(r: Rect2) -> void:
	position = r.position
	size = Vector2(r.size.x, PLATE_H)
	_layout()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and title_l:
		_layout()


# ------------------------------------------------------------------ data

static func is_pagoda(m: String) -> bool:
	return m == "pagoda"


static func status_text(m: String, r: Dictionary) -> String:
	if is_pagoda(m):
		var f: = int(r.get("floor", 1))
		return "Этаж %d%s" % [f, " · Страж" if P.is_guard(f) else ""]
	var b: = int(r.get("board", 0)) + 1
	var t: = "Стол %d из %d" % [b, J.BOARDS]
	if m == "practice" or bool(r.get("practice", false)):
		t = "Тренировка · " + t
	return t


static func lives_of(m: String, r: Dictionary) -> int:
	return int(r.get("lives", 3)) if is_pagoda(m) else int(r.get("hearts", J.HEARTS))


# how many lantern / heart places the line shows: the run's cap (one lantern for «Один фонарь»), at least the
# start number so a lost lantern stays visible as «out», never more than 5
static func slots_of(m: String, r: Dictionary) -> int:
	if not is_pagoda(m):
		return J.HEARTS
	var rules: = M.resolve(r)
	if bool(rules.get("lamp_one", false)):
		return 1
	return clampi(maxi(int(rules.get("lives", 3)), int(r.get("lives", 3))), 1, LIVES_CAP)


static func preferred_width(m: String, r: Dictionary, compact_line: = false) -> float:
	var w: = PAD * 2.0
	if not compact_line:
		w += V10Type.text_w(status_text(m, r), "ui", 22) + GAP
	var n: = slots_of(m, r)
	w += n * (LANTERN_STEP if is_pagoda(m) else HEART_STEP)
	if is_pagoda(m):
		w += GAP + ICON + 6.0 + V10Type.text_w("Жар %d" % P.heat_chosen(r), "ui", 22)
	return ceilf(w)


func configure(m: String, r: Dictionary) -> void:
	mode = m
	run = r
	lives = lives_of(m, r)
	slots_n = slots_of(m, r)
	heat = P.heat_chosen(r) if is_pagoda(m) else 0
	title_l.text = status_text(m, r)
	heat_l.text = "Жар %d" % heat
	heat_box.visible = is_pagoda(m)
	_build_lives()
	_build_heat_icon()
	_layout()
	queue_redraw()


func _build_lives() -> void:
	for n in life_nodes:
		if is_instance_valid(n):
			n.queue_free()
	life_nodes.clear()
	_lit.clear()
	_full.clear()
	_broken.clear()
	var pag: = is_pagoda(mode)
	for i in slots_n:
		var on: = i < lives
		_lit.append(1.0 if on else 0.0)
		_full.append(on)
		_broken.append(false)
		var g: Control
		if pag:
			g = UI_T.glyph(_lantern_painter(i), Vector2(LANTERN_STEP, PLATE_H))
		else:
			g = UI_T.glyph(_heart_painter(i), Vector2(HEART_STEP, PLATE_H))
		g.name = ("Lantern%d" if pag else "Heart%d") % i
		if pag and not on:
			g.set_meta("drop", DROP)
		add_child(g)
		life_nodes.append(g)


func _lantern_painter(k: int) -> Callable:
	return func(ci: CanvasItem, sz: Vector2) -> void:
		UI_T.draw_lantern(ci, sz * 0.5, LANTERN_H, float(_lit[k]))


func _heart_painter(k: int) -> Callable:
	return func(ci: CanvasItem, sz: Vector2) -> void:
		UI_T.draw_heart(ci, sz * 0.5, HEART_S, bool(_full[k]), bool(_broken[k]))


func _ember_painter() -> Callable:
	return func(ci: CanvasItem, sz: Vector2) -> void:
		UI_T.draw_ember(ci, sz * 0.5, sz.y)


func _build_heat_icon() -> void:
	if heat_icon and is_instance_valid(heat_icon):
		heat_icon.queue_free()
	heat_icon = UI_T.art_or("heat", Vector2(ICON, ICON), _ember_painter())
	heat_box.add_child(heat_icon)


func _layout() -> void:
	if title_l == null:
		return
	var x: = PAD
	title_l.visible = not compact
	if not compact:
		var tw: = V10Type.text_w(title_l.text, "ui", 22) + 2.0
		title_l.position = Vector2(x, 0)
		title_l.size = Vector2(tw, PLATE_H)
		x += tw + GAP * 0.5
	var step: = LANTERN_STEP if is_pagoda(mode) else HEART_STEP
	for i in life_nodes.size():
		var g: Control = life_nodes[i]
		g.position = Vector2(x + i * step, float(g.get_meta("drop", 0.0)))
	var right: = size.x - PAD
	if clock_l.visible:
		var cw: = V10Type.text_w("00:00", "num", 22)
		clock_l.position = Vector2(right - cw, 0)
		clock_l.size = Vector2(cw, PLATE_H)
		right -= cw + GAP
	if heat_box.visible:
		var hw: = V10Type.text_w(heat_l.text, "ui", 22) + 2.0
		var bw: = ICON + 6.0 + hw
		heat_box.position = Vector2(right - bw, 0)
		heat_box.size = Vector2(bw, PLATE_H)
		heat_box.pivot_offset = heat_box.size * 0.5
		if heat_icon:
			heat_icon.position = Vector2(0, (PLATE_H - ICON) * 0.5)
		heat_l.position = Vector2(ICON + 6.0, 0)
		heat_l.size = Vector2(hw, PLATE_H)


func _draw() -> void:
	V10Plate.draw_surface(self, Rect2(Vector2.ZERO, size))


# ------------------------------------------------------------------ events

func lose_life(index: int) -> void:
	lives = maxi(0, lives - 1)
	if index < 0 or index >= life_nodes.size():
		return
	var g: Control = life_nodes[index]
	if is_pagoda(mode):
		_exhale(index, g)
	else:
		_crack(index, g)


func _exhale(i: int, g: Control) -> void:
	g.set_meta("drop", DROP)
	if UI_T.calm():
		_lit[i] = 0.0
		g.position.y = DROP
		g.modulate.a = 0.0
		g.queue_redraw()
		g.create_tween().tween_property(g, "modulate:a", 1.0, CALM_FADE)
		return
	var tw: = g.create_tween().set_parallel(true)
	tw.tween_method(func(v: float) -> void:
		_lit[i] = v
		g.queue_redraw(), float(_lit[i]), 0.0, EXHALE).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tw.tween_property(g, "position:y", DROP, EXHALE).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	# the exhale: three small wisps leave the lantern's top and fade upward (paper colour, never white)
	var paint: = func(ci: CanvasItem, sz: Vector2) -> void:
		for k in 3:
			ci.draw_circle(Vector2(sz.x * 0.5 + (k - 1) * 4.0, sz.y - 6.0 - k * 7.0), 3.0 - k * 0.6, Color(V10DS.PAPER_300, 0.55))
	var wisp: = UI_T.glyph(paint, Vector2(LANTERN_STEP, 28))
	wisp.position = g.position + Vector2(0, -16)
	add_child(wisp)
	var wt: = wisp.create_tween().set_parallel(true)
	wt.tween_property(wisp, "position:y", wisp.position.y - 14.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	wt.tween_property(wisp, "modulate:a", 0.0, 0.5).set_delay(0.1)
	wt.chain().tween_callback(wisp.queue_free)


func _crack(i: int, g: Control) -> void:
	_broken[i] = true
	g.queue_redraw()
	if UI_T.calm():
		_full[i] = false
		g.modulate.a = 0.0
		g.create_tween().tween_property(g, "modulate:a", 1.0, CALM_FADE)
		return
	var x0: = g.position.x
	var tw: = g.create_tween()
	for k in 3:
		tw.tween_property(g, "position:x", x0 + (3.0 if k % 2 == 0 else -3.0), 0.04)
	tw.tween_property(g, "position:x", x0, 0.04)
	tw.tween_callback(func() -> void:
		_full[i] = false
		g.queue_redraw())
	tw.tween_property(g, "scale", Vector2(1.08, 1.08), 0.08)
	tw.tween_property(g, "scale", Vector2.ONE, 0.12)
	g.pivot_offset = g.size * 0.5


# a lantern / heart comes back (guard chest, «Тёплое слово» in the next floor is a reconfigure)
func set_lives(n: int) -> void:
	lives = n
	for i in life_nodes.size():
		_lit[i] = 1.0 if i < n else 0.0
		_full[i] = i < n
		if i < n:
			_broken[i] = false
			life_nodes[i].set_meta("drop", 0.0)
		life_nodes[i].queue_redraw()
	_layout()


func set_clock(text: String, danger: = false) -> void:
	if text == _clock and danger == _danger:
		return
	var vis_changed: = (text == "") != (_clock == "")
	_clock = text
	_danger = danger
	clock_l.visible = text != ""
	clock_l.text = text
	clock_l.label_settings = V10Type.settings("num", 22, V10DS.EMBER if danger else V10DS.PAPER_100)
	if vis_changed:
		_layout()


func flash_heat() -> void:
	if not heat_box.visible:
		return
	if UI_T.calm():
		heat_box.modulate.a = 0.0
		heat_box.create_tween().tween_property(heat_box, "modulate:a", 1.0, CALM_FADE)
		return
	heat_l.label_settings = V10Type.settings("ui", 22, UI_T.EMBER_HI)
	var tw: = heat_box.create_tween()
	tw.tween_property(heat_box, "scale", Vector2(1.12, 1.12), 0.14).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tw.tween_property(heat_box, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void:
		heat_l.label_settings = V10Type.settings("ui", 22, V10DS.GOLD_300))


# for selftests and shot audits: what the line says now
func snapshot() -> Dictionary:
	var lit: = 0
	for v in _lit:
		if float(v) > 0.5:
			lit += 1
	var full: = 0
	for v in _full:
		if bool(v):
			full += 1
	return {"title": title_l.text if title_l.visible else "", "lit": lit if is_pagoda(mode) else full, "slots": slots_n,
		"heat": heat_l.text if heat_box.visible else "", "clock": _clock, "danger": _danger}
