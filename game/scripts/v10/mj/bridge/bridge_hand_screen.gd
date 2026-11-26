class_name V10MjBridgeHandScreen
extends Control

# «Собери руку» (docs/MODES.md §4.5; общий каркас §4; UX_RULES §6.6). Контракт §7.1:
#   setup(main, args) · сигнал finished(result) · args.presence (on/sacred) · args.look · награды не начисляет.
#
# args: level (1…60, иначе из сейва), hero (иначе партнёрша G.S.partner), presence, look ({face_tint}),
#   start_sheet (true), result_sheet (true), demo (без сейва), instant (без раздачи).
#
# Зоны (720×1280; на 9:20 и длиннее лишняя высота уходит в её полосу):
#   0 … band_h          её полоса: пауза · «12 · Наборы 2 из 4» и тонкая полоса · «Цель ×2» · окно с кольцом Приёма
#   band_h … +236       рука на 14 мест: два ряда по 7, наборы слева с подписью «тройка» / «ряд»
#   … H−186             поле — пирамида фишек риичи (святая зона), внизу поля — край стола (сюда уходит «Сброс»)
#   H−186 … H−40        помощь: «Сброс» (3 за партию; сначала выбери фишку в руке)
# Бюджет партии: тапаемых ≤ 6 (пауза, окно-Приём, Сброс), слов ≤ 8, бейджей 0, валют 0.

signal finished(result: Dictionary)

const T: = V10MjBridgeLook.TOK
const HAND_H: = 236.0
const HELP_ZONE: = 186.0
const EDGE_H: = 104.0
const SLOT_W: = 60.0
const SLOT_PITCH: = 66.0
const ROW_PITCH: = 108.0
const SIGNATURE: = {"mc": 33, "rin": 32, "hana": 27, "yue": 31, "nova": 13}
const ULT_NAME: = {"mc": "Лучшая фишка", "rin": "Вернуть три", "hana": "Рывок", "yue": "Лунный свет", "nova": "Взлом"}
const NEED: = 3
const LINES: = {
	"start": "Четыре набора и пара. Поехали!",
	"reset": "Фишка ждёт на краю стола.",
	"tenpai": "Ещё одна — и готово!",
	"danger": "Мест мало. Подумай.",
	"set": "Набор!",
}

var main
var args: = {}
var level: = 1
var hero: = "hana"
var lv: = {}
var rules: V10MjBridgeHand
var presence
var lite: V10MjBridgePresence
var save_d: = {}
var demo: = false

var vw: = Vector2(720, 1280)
var band_h: = 120.0
var hand_frame: = Rect2()
var field_r: = Rect2()
var pyr_r: = Rect2()
var edge_r: = Rect2()
var help_r: = Rect2()
var tw_field: = 80.0
var lift: = Vector2(-3, -6)

var field_nodes: Array = []       # V10MjBridgeTile по месту i
var hand_nodes: Array = []        # V10MjBridgeTile в руке
var edge_nodes: Array = []        # V10MjBridgeTile на краю
var set_labels: Array = []
var hand_marks: Control
var sel_node: V10MjBridgeTile = null
var left_lbl: Label
var goal_lbl: Label
var bar: Control
var reset_btn: Button
var reset_num: Label
var sheet_layer: Control
var fx_layer: Control
var banner: Label
var orig_lbl: Label

var charge: = 0
var used_ult: = false
var ended: = false
var input_on: = false
var t0: = 0.0
var score: = 0
var result: = {}
var _danger: = false
var _tenpai_said: = false
var _hint_until: = 0.0
var _hint_ids: Array = []


func setup(m, a: Dictionary) -> void:
	main = m
	args = a
	demo = bool(a.get("demo", false))
	save_d = V10MjBridgeSave.st() if not demo else V10MjBridgeSave.fresh()
	level = clampi(int(a.get("level", save_d.get("hand_level", 1))), 1, V10MjBridgeLevels.COUNT)
	var partner: String = String(G.S.get("partner", "")) if G.S is Dictionary else ""
	hero = V10MjBridgeLook.hero_ok(String(a.get("hero", partner if partner != "" else V10MjBridgeInfo.INFO_HAND.host)))
	if a.get("look", {}) is Dictionary and (a.look as Dictionary).has("face_tint"):
		V10MjBridgeTile.look = {"face_tint": a.look.face_tint}
	if is_inside_tree():
		_build()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not args.is_empty() and rules == null:
		_build()


# ── сборка ───────────────────────────────────────────────────────────────────

func _build() -> void:
	vw = get_viewport_rect().size
	size = vw
	var extra: = maxf(0.0, vw.y - 1280.0)
	band_h = 120.0 + minf(extra, 330.0)
	var spare: = extra - minf(extra, 330.0)
	lv = V10MjBridgeLevels.build(level)
	rules = V10MjBridgeHand.make(lv)
	add_child(V10MjBridgeLook.backdrop(hero))
	var fw: = SLOT_PITCH * 7.0 + 24.0
	hand_frame = Rect2((vw.x - fw) * 0.5, band_h + 4.0, fw, HAND_H - 8.0)
	field_r = Rect2(16, band_h + HAND_H + spare * 0.5, vw.x - 32, vw.y - HELP_ZONE - spare * 0.5 - (band_h + HAND_H + spare * 0.5))
	edge_r = Rect2(field_r.position.x, field_r.end.y - EDGE_H, field_r.size.x, EDGE_H)
	pyr_r = Rect2(field_r.position.x, field_r.position.y + 8.0, field_r.size.x, field_r.size.y - EDGE_H - 16.0)
	help_r = Rect2(0, vw.y - HELP_ZONE, vw.x, HELP_ZONE - 32.0)
	add_child(V10MjBridgeLook.felt(field_r, hero))
	_build_hand_frame()
	_build_field()
	_build_band()
	_build_help()
	fx_layer = Control.new()
	fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fx_layer)
	_build_banner()
	_build_presence()
	sheet_layer = Control.new()
	sheet_layer.name = "Sheets"
	sheet_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(sheet_layer)
	_refresh()
	if bool(args.get("start_sheet", true)):
		_start_sheet()
	else:
		_start()


func _build_hand_frame() -> void:
	var f: = Control.new()
	f.name = "HandFrame"
	f.mouse_filter = Control.MOUSE_FILTER_STOP
	f.position = hand_frame.position
	f.size = hand_frame.size
	var deep: Color = V10MjBridgeLook.accent(hero)[2]
	f.draw.connect(func():
		var sb: = StyleBoxFlat.new()
		sb.bg_color = T.night800.lerp(deep, 0.22)
		sb.set_corner_radius_all(4)
		sb.border_color = Color(T.gold700, 0.35)
		sb.set_border_width_all(1)
		f.draw_style_box(sb, Rect2(Vector2.ZERO, f.size))
		var used: = rules.hand_count() if rules else 0
		for s in 14:
			var r: = _slot_rect(s)
			r.position -= hand_frame.position
			var hot: = s >= 12 and used >= 12 and s >= used
			f.draw_rect(r, Color(T.night900, 0.35), true)
			f.draw_rect(r, Color(T.ember, 0.55) if hot else Color(T.paper100, 0.07), false, 2.0 if hot else 1.0))
	f.gui_input.connect(_on_hand_input)
	add_child(f)
	hand_marks = Control.new()
	hand_marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hand_marks.set_anchors_preset(Control.PRESET_FULL_RECT)
	hand_marks.draw.connect(_draw_hand_marks)
	add_child(hand_marks)


# место s (0…13) в руке: ряды по 7
func _slot_rect(s: int) -> Rect2:
	var row: = s / 7
	var col: = s % 7
	var x: = hand_frame.position.x + 12.0 + col * SLOT_PITCH + (SLOT_PITCH - SLOT_W) * 0.5
	var y: = hand_frame.position.y + 8.0 + row * ROW_PITCH
	return Rect2(x, y, SLOT_W, SLOT_W * V10MjBridgeTile.ASPECT)


# раскладка руки: наборы — места 0-2, 3-5 первого ряда, 0-2, 3-5 второго; свободные — остальные по порядку
func _layout() -> Array:
	var out: = []
	var set_slots: = [[0, 1, 2], [3, 4, 5], [7, 8, 9], [10, 11, 12]]
	var used: = {}
	for si in rules.sets.size():
		var s: Dictionary = rules.sets[si]
		for j in 3:
			out.append({"k": int(s.k[j]), "slot": set_slots[si][j], "set": si})
			used[set_slots[si][j]] = true
	var free_slots: = []
	for s in 14:
		if not used.has(s):
			free_slots.append(s)
	# порядок свободных мест: справа от наборов в первом ряду, затем второй ряд
	free_slots.sort_custom(func(a, b): return a < b)
	for i in rules.loose.size():
		if i < free_slots.size():
			out.append({"k": int(rules.loose[i]), "slot": free_slots[i], "set": -1})
	return out


func _draw_hand_marks() -> void:
	if rules == null:
		return
	var acc: Color = V10MjBridgeLook.accent(hero)[0]
	var set_slots: = [[0, 1, 2], [3, 4, 5], [7, 8, 9], [10, 11, 12]]
	for si in rules.sets.size():
		var a: = _slot_rect(set_slots[si][0])
		var b: = _slot_rect(set_slots[si][2])
		var y: = a.end.y + 3.0
		hand_marks.draw_line(Vector2(a.position.x, y), Vector2(b.end.x, y), Color(acc, 0.85), 2.5, true)
	if rules.won and rules.pair.size() == 2:
		var lay: = _layout()
		for e in lay:
			if int(e.set) < 0:
				var r: = _slot_rect(int(e.slot))
				hand_marks.draw_line(Vector2(r.position.x, r.end.y + 3.0), Vector2(r.end.x, r.end.y + 3.0), T.gold500, 2.5, true)


func _field_pos(i: int) -> Vector2:
	var p: Vector3 = lv.pos[i]
	var sh: Array = lv.shape
	var c: = float(sh[0])
	var r: = float(sh[1])
	var th: = tw_field * V10MjBridgeTile.ASPECT
	var x0: = pyr_r.get_center().x - c * tw_field * 0.5
	var y0: = pyr_r.get_center().y - r * th * 0.5
	return Vector2(x0 + p.x * tw_field + lift.x * p.z, y0 + p.y * th + lift.y * p.z)


func _build_field() -> void:
	var sh: Array = lv.shape
	var c: = float(sh[0])
	var r: = float(sh[1])
	tw_field = minf(minf((pyr_r.size.x - 16.0) / (c + 0.1), (pyr_r.size.y - 16.0) / (r + 0.1) / V10MjBridgeTile.ASPECT), 104.0)
	var ids: = range(lv.pos.size())
	ids.sort_custom(func(a, b):
		var pa: Vector3 = lv.pos[a]
		var pb: Vector3 = lv.pos[b]
		return pa.z < pb.z or (pa.z == pb.z and (pa.y < pb.y or (pa.y == pb.y and pa.x < pb.x))))
	field_nodes.resize(lv.pos.size())
	var root: = Control.new()
	root.name = "Field"
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.position = field_r.position
	root.size = field_r.size
	root.gui_input.connect(_on_field_input)
	add_child(root)
	for i in ids:
		var t: = V10MjBridgeTile.make(int(lv.kinds[i]), tw_field - 2.0)
		t.depth = int((lv.pos[i] as Vector3).z)
		t.position = _field_pos(i)
		t.set_meta("i", i)
		add_child(t)
		field_nodes[i] = t
	# край стола: место для «Сброса»
	var e: = Control.new()
	e.name = "Edge"
	e.mouse_filter = Control.MOUSE_FILTER_IGNORE
	e.position = edge_r.position
	e.size = edge_r.size
	e.draw.connect(func():
		e.draw_line(Vector2(12, 4), Vector2(e.size.x - 12, 4), Color(T.gold700, 0.35), 1.0)
		for k in V10MjBridgeHand.RESETS:
			var rr: = _edge_rect(k)
			rr.position -= edge_r.position
			var xx: = rr.position.x
			while xx < rr.end.x:
				e.draw_line(Vector2(xx, rr.position.y), Vector2(minf(xx + 5, rr.end.x), rr.position.y), Color(T.paper100, 0.14), 1.0)
				e.draw_line(Vector2(xx, rr.end.y), Vector2(minf(xx + 5, rr.end.x), rr.end.y), Color(T.paper100, 0.14), 1.0)
				xx += 10.0)
	add_child(e)


func _edge_rect(k: int) -> Rect2:
	var w: = 58.0
	return Rect2(edge_r.position.x + 20.0 + k * (w + 10.0), edge_r.position.y + 14.0, w, w * V10MjBridgeTile.ASPECT)


func _build_band() -> void:
	var pause: = V10MjBridgeLook.icon_button("pause", Vector2(12, 18))
	pause.name = "Pause"
	pause.pressed.connect(_pause_sheet)
	add_child(pause)
	left_lbl = V10MjBridgeLook.label("", 22, T.paper100, "body", 800)
	left_lbl.position = Vector2(100, 24)
	left_lbl.size = Vector2(380, 32)
	add_child(left_lbl)
	bar = Control.new()
	bar.position = Vector2(100, 64)
	bar.size = Vector2(minf(300.0, vw.x - 100.0 - 190.0), 4)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.draw.connect(func():
		var p: = float(rules.sets.size()) / 4.0 if not rules.won else 1.0
		bar.draw_rect(Rect2(Vector2.ZERO, bar.size), Color(T.paper100, 0.12))
		bar.draw_rect(Rect2(Vector2.ZERO, Vector2(bar.size.x * p, bar.size.y)), T.jade500))
	add_child(bar)
	goal_lbl = V10MjBridgeLook.label("", 20, T.gold300, "body", 800)
	goal_lbl.position = Vector2(100, 76)
	goal_lbl.visible = int(lv.req) > 1
	goal_lbl.text = "Цель ×%d" % int(lv.req)
	add_child(goal_lbl)


func _build_help() -> void:
	var root: = Control.new()
	root.name = "Help_reset"
	root.position = Vector2(vw.x * 0.5 - 60.0, help_r.position.y + 20.0)
	root.size = Vector2(120, 140)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var b: = Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.position = Vector2(12, 0)
	b.size = Vector2(96, 96)
	b.pivot_offset = Vector2(48, 48)
	b.set_meta("ux_role", "tertiary")
	b.draw.connect(func():
		var c: = Vector2(48, 48)
		var on_: = rules.resets_left > 0 and sel_node != null
		b.draw_circle(c, 46.0, T.night700)
		b.draw_arc(c, 46.0, 0, TAU, 48, Color(T.gold500 if on_ else T.gold700, 0.7 if on_ else 0.3), 1.5 if not on_ else 2.5, true)
		var nb: = Vector2(80, 80)
		b.draw_circle(nb, 15.0, T.night900)
		b.draw_arc(nb, 15.0, 0, TAU, 24, Color(T.gold500, 0.5), 1.2, true))
	var ic: = V10MjBridgeIcon.new("reset", T.gold300)
	ic.position = Vector2(24, 24)
	ic.size = Vector2(48, 48)
	b.add_child(ic)
	reset_num = V10MjBridgeLook.label("3", 18, T.paper100, "body", 900)
	reset_num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reset_num.size = Vector2(30, 26)
	reset_num.position = Vector2(65, 66)
	b.add_child(reset_num)
	root.add_child(b)
	var cap: = V10MjBridgeLook.label("Сброс", 18, T.paper500, "body", 700)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.size = Vector2(160, 26)
	cap.position = Vector2(-20, 102)
	root.add_child(cap)
	b.button_down.connect(func(): V9Feel.press(b, "", "button"))
	b.pressed.connect(use_reset)
	reset_btn = b


func _build_banner() -> void:
	banner = V10MjBridgeLook.label("", 40, T.gold300, "italic", 700)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	banner.label_settings.shadow_color = Color(0, 0, 0, 0.7)
	banner.label_settings.shadow_size = 10
	banner.size = Vector2(vw.x - 48, 110)
	banner.position = Vector2(24, pyr_r.get_center().y - 70.0)
	banner.modulate.a = 0.0
	add_child(banner)
	orig_lbl = V10MjBridgeLook.label("", 18, T.paper300, "body", 700)
	orig_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	orig_lbl.size = Vector2(vw.x, 28)
	orig_lbl.position = Vector2(0, pyr_r.get_center().y + 44.0)
	orig_lbl.modulate.a = 0.0
	add_child(orig_lbl)


func _window_rect() -> Rect2:
	var h: = band_h - 14.0
	var w: = clampf(h * 0.72, 96.0, 300.0)
	if band_h <= 140.0:
		w = 104.0
		h = band_h - 8.0
	return Rect2(vw.x - w - 20.0, band_h - h - 2.0, w, h)


func _build_presence() -> void:
	var ext = args.get("presence")
	lite = V10MjBridgePresence.new()
	lite.attach(self, hero, {"ring": true})
	move_child(lite, fx_layer.get_index())
	var wr: = _window_rect()
	# фраза — в её полосе слева от окна (под строкой «Наборы»), на 9:20 — над столом
	var line: = Rect2(100, 96, wr.position.x - 120.0, maxf(24.0, band_h - 100.0))
	if band_h > 200.0:
		line = Rect2(24, band_h - 96.0, wr.position.x - 44.0, 88.0)
	lite.layout(Rect2(0, 0, vw.x, band_h), wr, line)
	lite.portrait_tapped.connect(_try_ult)
	lite.finale_done.connect(_after_finale)
	presence = ext if ext != null and ext.has_method("on") else lite
	if presence != lite:
		lite.hide_window()
	for r in sacred_rects():
		presence.sacred(r)
		if presence != lite:
			lite.sacred(r)
	_sync_charge()


func sacred_rects() -> Array:
	return [hand_frame, field_r, help_r]


# ── поток ────────────────────────────────────────────────────────────────────

func _start() -> void:
	t0 = Time.get_ticks_msec() / 1000.0
	presence.on("start", {})
	if bool(args.get("instant", false)) or V9Feel.level() == "min":
		input_on = true
	else:
		# раздача: фишки проявляются слоями снизу вверх (≤ 0,6 с)
		for t in field_nodes:
			var tt: V10MjBridgeTile = t
			tt.modulate.a = 0.0
			var tw: = tt.create_tween()
			tw.tween_interval(0.05 + tt.depth * 0.12 + randf() * 0.12)
			tw.tween_property(tt, "modulate:a", 1.0, 0.18)
		get_tree().create_timer(0.7).timeout.connect(func(): input_on = true)
	_banner("Уровень %d" % level, 0.8)
	lite.say(LINES.start, 3.0, true)


func _banner(text: String, hold: float, sub: = "") -> void:
	banner.text = text
	orig_lbl.text = sub
	var tw: = banner.create_tween()
	tw.tween_property(banner, "modulate:a", 1.0, 0.18)
	if sub != "":
		tw.parallel().tween_property(orig_lbl, "modulate:a", 1.0, 0.18)
	if hold > 0.0:
		tw.tween_interval(hold)
		tw.tween_property(banner, "modulate:a", 0.0, 0.2)
		tw.parallel().tween_property(orig_lbl, "modulate:a", 0.0, 0.2)


func _on_field_input(e: InputEvent) -> void:
	if not (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT):
		return
	var p: Vector2 = field_r.position + (e as InputEventMouseButton).position
	# сначала край стола
	for j in edge_nodes.size():
		var en: V10MjBridgeTile = edge_nodes[j]
		if Rect2(en.position, en.size).grow(4).has_point(p):
			tap_edge(j)
			return
	# сверху вниз
	var best: = -1
	var best_z: = -1.0
	for i in field_nodes.size():
		if rules.present[i] != 1:
			continue
		var t: V10MjBridgeTile = field_nodes[i]
		if Rect2(t.position, t.size).has_point(p):
			var z: float = (lv.pos[i] as Vector3).z
			if z > best_z:
				best_z = z
				best = i
	if best >= 0:
		tap(best)


func tap(i: int) -> void:
	if not input_on or ended:
		return
	if not rules.is_free(i):
		var t: V10MjBridgeTile = field_nodes[i]
		V9Feel.deny(t)
		return
	if rules.hand_count() >= V10MjBridgeHand.CAP:
		return
	var from: = (field_nodes[i] as Control).position
	var k: int = rules.kind[i]
	presence.on("pick", {"pos": from + (field_nodes[i] as Control).size * 0.5})
	if presence != lite:
		lite.on("pick", {"pos": from})
	var res: = rules.take(i)
	if not bool(res.get("ok", false)):
		return
	(field_nodes[i] as Control).visible = false
	_after_take(k, from, tw_field - 2.0, res)


func tap_edge(j: int) -> void:
	if not input_on or ended or j < 0 or j >= rules.edge.size():
		return
	var en: V10MjBridgeTile = edge_nodes[j]
	var from: = en.position
	var k: int = rules.edge[j]
	var res: = rules.take_edge(j)
	if not bool(res.get("ok", false)):
		return
	edge_nodes.remove_at(j)
	en.queue_free()
	_reflow_edge()
	_after_take(k, from, en.size.x, res)


func _after_take(k: int, from: Vector2, from_w: float, res: Dictionary) -> void:
	V9Feel.sound("pop", 1.0 + 0.04 * (k % 9), -8.0)
	_reflow_hand({"k": k, "from": from, "w": from_w})
	_refresh_field()
	var formed: Array = res.get("formed", [])
	for s in formed:
		_on_set(s)
	_refresh()
	if rules.won:
		_on_won()
	elif rules.lost:
		_on_lost()


func _on_set(s: Dictionary) -> void:
	var si: = rules.sets.find(s)
	var set_slots: = [[0, 1, 2], [3, 4, 5], [7, 8, 9], [10, 11, 12]]
	var center: = _slot_rect(set_slots[maxi(si, 0)][1]).get_center()
	V9Feel.sound("sparkle", 0.9 + 0.1 * rules.sets.size(), -6.0)
	var add: = 1
	if (s.k as Array).has(int(SIGNATURE.get(hero, -1))):
		add += 1
		presence.on("signature", {})
		if presence != lite:
			lite.on("signature", {})
	charge = mini(NEED, charge + add)
	presence.on("pair", {"pos": center, "charge": float(charge) / NEED})
	if presence != lite:
		lite.on("pair", {"pos": center})
	_sync_charge()


func _sync_charge() -> void:
	lite.set_charge(float(charge) / NEED, charge >= NEED and not used_ult)


func _refresh() -> void:
	if rules == null or left_lbl == null:
		return
	left_lbl.text = "%d · Наборы %d из 4" % [level, rules.sets.size() if not rules.won else 4]
	bar.queue_redraw()
	reset_num.text = str(rules.resets_left)
	reset_btn.modulate = Color(1, 1, 1, 1.0 if rules.resets_left > 0 else 0.45)
	reset_btn.queue_redraw()
	hand_marks.queue_redraw()
	get_node("HandFrame").queue_redraw()
	var d: = rules.hand_count() >= 12 and not rules.won and not rules.tenpai()
	if d != _danger:
		_danger = d
		presence.on("danger", {"on": d})
		if presence != lite:
			lite.on("danger", {"on": d})
		if d:
			lite.say(LINES.danger, 3.0)
	if rules.tenpai() and not _tenpai_said and not rules.won:
		_tenpai_said = true
		presence.on("last_pair", {})
		if presence != lite:
			lite.on("last_pair", {})
		lite.say(LINES.tenpai, 3.0, true)
	elif not rules.tenpai():
		_tenpai_said = false


func _refresh_field() -> void:
	var now: = Time.get_ticks_msec() / 1000.0
	for i in field_nodes.size():
		var t: V10MjBridgeTile = field_nodes[i]
		if rules.present[i] != 1:
			t.visible = false
			continue
		var fr: = rules.is_free(i)
		t.dim = not fr
		t.hint = 1.0 if now < _hint_until and _hint_ids.has(i) else 0.0
		t.queue_redraw()


# ── рука: переразложить узлы под текущую раскладку ───────────────────────────

func _reflow_hand(spawn: = {}) -> void:
	var lay: = _layout()
	var free: = hand_nodes.duplicate()
	var next: = []
	for e in lay:
		var target: = _slot_rect(int(e.slot))
		var pick_n: V10MjBridgeTile = null
		var best_d: = INF
		for n in free:
			var nn: V10MjBridgeTile = n
			if nn.kind == int(e.k):
				var dd: = nn.position.distance_to(target.position)
				if dd < best_d:
					best_d = dd
					pick_n = nn
		if pick_n == null:
			pick_n = V10MjBridgeTile.make(int(e.k), SLOT_W)
			if not spawn.is_empty() and int(spawn.k) == int(e.k):
				pick_n.position = spawn.from
				pick_n.set_w(float(spawn.w))
				spawn = {}
			else:
				pick_n.position = target.position
			add_child(pick_n)
			move_child(pick_n, hand_marks.get_index())
		else:
			free.erase(pick_n)
		next.append(pick_n)
		pick_n.set_meta("set", int(e.set))
		var tw: = pick_n.create_tween().set_parallel()
		tw.tween_property(pick_n, "position", target.position, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		if absf(pick_n.size.x - SLOT_W) > 0.5:
			var n2: = pick_n
			tw.tween_method(func(w: float): n2.set_w(w), pick_n.size.x, SLOT_W, 0.24)
	for n in free:
		if n == sel_node:
			sel_node = null
		(n as Node).queue_free()
	hand_nodes = next
	_rebuild_labels()


func _rebuild_labels() -> void:
	for l in set_labels:
		(l as Node).queue_free()
	set_labels = []
	var set_slots: = [[0, 1, 2], [3, 4, 5], [7, 8, 9], [10, 11, 12]]
	for si in rules.sets.size():
		var a: = _slot_rect(set_slots[si][0])
		var b: = _slot_rect(set_slots[si][2])
		var l: = V10MjBridgeLook.label(V10MjBridgeHand.SET_NAME[String(rules.sets[si].t)], 18, T.paper300, "body", 800)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.position = Vector2(a.position.x, a.end.y + 4.0)
		l.size = Vector2(b.end.x - a.position.x, 22)
		add_child(l)
		set_labels.append(l)
	if rules.won and rules.pair.size() == 2:
		for e in _layout():
			if int(e.set) < 0:
				var r: = _slot_rect(int(e.slot))
				var l2: = V10MjBridgeLook.label("пара", 18, T.gold300, "body", 800)
				l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				l2.position = Vector2(r.position.x - 10, r.end.y + 4.0)
				l2.size = Vector2(r.size.x + 20, 22)
				add_child(l2)
				set_labels.append(l2)
				break
	hand_marks.queue_redraw()


func _reflow_edge(spawn: = {}) -> void:
	var free: = edge_nodes.duplicate()
	var next: = []
	for j in rules.edge.size():
		var k: int = rules.edge[j]
		var r: = _edge_rect(j)
		var n: V10MjBridgeTile = null
		for m in free:
			if (m as V10MjBridgeTile).kind == k:
				n = m
				break
		if n == null:
			n = V10MjBridgeTile.make(k, r.size.x)
			n.position = spawn.get("from", r.position) if not spawn.is_empty() and int(spawn.k) == k else r.position
			add_child(n)
			move_child(n, hand_marks.get_index())
		else:
			free.erase(n)
		next.append(n)
		var tw: = n.create_tween()
		tw.tween_property(n, "position", r.position, 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		var n2: = n
		tw.parallel().tween_method(func(w: float): n2.set_w(w), n.size.x, r.size.x, 0.26)
	for m in free:
		(m as Node).queue_free()
	edge_nodes = next


func _on_hand_input(e: InputEvent) -> void:
	if not (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT):
		return
	if ended:
		return
	var p: Vector2 = hand_frame.position + (e as InputEventMouseButton).position
	for n in hand_nodes:
		var t: V10MjBridgeTile = n
		if Rect2(t.position, t.size).grow(3).has_point(p):
			select_hand(t)
			return


func select_hand(t: V10MjBridgeTile) -> void:
	if sel_node != null and is_instance_valid(sel_node):
		sel_node.sel = false
		sel_node.lift = 0.0
		sel_node.queue_redraw()
	if sel_node == t:
		sel_node = null
	else:
		sel_node = t
		t.sel = true
		t.lift = 8.0
		t.queue_redraw()
		V9Feel.sound("pop", 1.2, -10.0)
	reset_btn.queue_redraw()


func select_kind(k: int) -> void:
	for n in hand_nodes:
		if (n as V10MjBridgeTile).kind == k:
			select_hand(n)
			return


func use_reset() -> void:
	if ended and not rules.lost:
		return
	if rules.resets_left <= 0 or sel_node == null or not is_instance_valid(sel_node):
		V9Feel.deny(reset_btn)
		return
	_reset_node(sel_node, false)


func _reset_node(n: V10MjBridgeTile, free_reset: bool) -> bool:
	var k: = n.kind
	var si: int = int(n.get_meta("set", -1))
	if not rules.reset_kind(k, si, free_reset):
		return false
	var from: = n.position
	hand_nodes.erase(n)
	if sel_node == n:
		sel_node = null
	n.queue_free()
	_reflow_edge({"k": k, "from": from})
	_reflow_hand()
	_refresh_field()
	_refresh()
	if not free_reset and rules.resets_used == 1:
		lite.say(LINES.reset, 3.0, true)
	return true


# ── Приём (MODES §5.5, колонка «Собери руку») ────────────────────────────────

func _try_ult() -> void:
	if ended or not input_on or charge < NEED or used_ult:
		lite._bounce(1.02, 0.2)
		return
	used_ult = true
	charge = 0
	_sync_charge()
	presence.on("ult", {})
	if presence != lite:
		lite.on("ult", {})
	_banner(String(ULT_NAME.get(hero, "Приём")), 0.7)
	input_on = false
	await get_tree().create_timer(0.35).timeout
	match hero:
		"mc":
			_ult_take(1)
		"hana":
			_ult_take(2)
		"rin":
			for k in 3:
				var w: = rules.worst_in_hand()
				if w < 0 or rules.edge.size() >= V10MjBridgeHand.EDGE_MAX:
					break
				for n in hand_nodes:
					if (n as V10MjBridgeTile).kind == w:
						_reset_node(n, true)
						break
		"yue":
			_hint_ids = []
			for i in rules.frees():
				if rules.rate(int(rules.kind[i])) < 1000:
					_hint_ids.append(i)
			_hint_until = Time.get_ticks_msec() / 1000.0 + 4.0
			_refresh_field()
			get_tree().create_timer(4.1).timeout.connect(_refresh_field)
		"nova":
			_ult_morph()
	input_on = not ended


func _ult_take(n: int) -> void:
	for k in n:
		if rules.is_over() or rules.hand_count() >= V10MjBridgeHand.CAP:
			break
		var b: = rules.best_take()
		if b.is_empty():
			break
		input_on = true
		if String(b.src) == "table":
			tap(int(b.i))
		else:
			tap_edge(int(b.i))
		input_on = false
		await get_tree().create_timer(0.3).timeout


# «Взлом»: самая бесполезная фишка руки становится самой нужной (копий вида не больше 4)
func _ult_morph() -> void:
	var w: = rules.worst_in_hand()
	if w < 0:
		return
	var all: = rules.hand_kinds()
	var A: = rules.avail()
	var best_k: = -1
	var best_sc: = 99999
	for k in 34:
		if k == w:
			continue
		var total_k: = int(V10MjBridgeTiles.counts(all)[k]) + int(A[k])
		if total_k >= 4:
			continue
		var H: = V10MjBridgeTiles.counts(all)
		H[w] -= 1
		H[k] += 1
		var sc: = (0 if V10MjBridgeHand.completable_req(H, A, rules.req) else 1000) + V8Mj.shanten_regular(H, 0) * 10
		if sc < best_sc:
			best_sc = sc
			best_k = k
	if best_k < 0:
		return
	var si: = rules.where(w)
	if si >= 0:
		var s: Array = (rules.sets[si].k as Array).duplicate()
		rules.sets.remove_at(si)
		s.erase(w)
		rules.loose.append_array(s)
	else:
		rules.loose.erase(w)
	rules.loose.append(best_k)
	rules.loose.sort()
	var formed: = rules.form()
	_reflow_hand()
	for s2 in formed:
		_on_set(s2)
	_refresh()


# ── финал ────────────────────────────────────────────────────────────────────

func _on_won() -> void:
	ended = true
	input_on = false
	lite.input_on = false
	_danger = false
	var cb: = V10MjBridgeHand.combos(rules.hand_kinds())
	var mult: = int(cb.mult)
	score = 1000 * mult + 100 * rules.resets_left
	_reflow_hand()
	_refresh()
	var ids: Array = cb.ids
	if not ids.is_empty():
		_banner(V10MjBridgeHand.combo_line(ids, mult), 0.0, V10MjBridgeHand.combo_orig(ids))
		presence.on("combo", {"n": 5})
		if presence != lite:
			lite.on("combo", {"n": 5})
		lite.say(String(V10MjBridgeHand.COMBOS[ids[0]].name) + "! Красиво.", 3.0, true)
	else:
		_banner("Рука собрана", 0.0)
	V9Feel.sound("sparkle", 1.2, -2.0)
	await get_tree().create_timer(1.3 if not bool(args.get("instant", false)) else 0.1).timeout
	presence.on("win", {})
	if presence != lite:
		lite.on("win", {})
	# режиссёр stage сам выходит в финале; у заглушки — сигнал finale_done
	if presence != lite:
		await get_tree().create_timer(1.6).timeout
		_after_finale()


func _after_finale() -> void:
	if result.has("action"):
		return
	_finish_result(true)
	banner.modulate.a = 0.0
	orig_lbl.modulate.a = 0.0
	if bool(args.get("result_sheet", true)):
		_win_sheet()
	else:
		finished.emit(result)


func _on_lost() -> void:
	input_on = false
	presence.on("lose", {})
	if presence != lite:
		lite.on("lose", {})
	await get_tree().create_timer(0.8 if not bool(args.get("instant", false)) else 0.05).timeout
	_lose_sheet()


func _finish_result(win: bool) -> void:
	var cb: = V10MjBridgeHand.combos(rules.hand_kinds()) if win else {"ids": [], "mult": 0}
	var stars: = V10MjBridgeSave.hand_stars_for(win, used_ult, int(cb.mult), int(lv.req))
	var rec: = {"stars_gain": 0, "first_clear": V10MjBridgeSave.hand_stars_of(save_d, level) == 0}
	if not demo:
		rec = V10MjBridgeSave.record_hand(save_d, level, win, stars, score)
		if G.has_method("save"):
			G.save()
	result = {
		"mode": "bridge_hand", "win": win, "score": score if win else 0, "stars": stars,
		"time_s": int(Time.get_ticks_msec() / 1000.0 - t0), "pairs": rules.sets.size(), "hero": hero,
		"seed": int(lv.get("seed", 0)), "level": level, "req": int(lv.req), "mult": int(cb.mult), "combos": cb.ids,
		"resets_used": rules.resets_used, "helped": used_ult, "stars_gain": int(rec.get("stars_gain", 0)),
		"rewards": V10MjBridgeSave.hand_rewards(level, win, bool(rec.get("first_clear", false))),
	}


# ── листы ────────────────────────────────────────────────────────────────────

func _start_sheet() -> void:
	input_on = false
	var p: = V10MjBridgeLook.sheet(sheet_layer, vw, 470.0)
	var over: = V10MjBridgeLook.label("СОБЕРИ РУКУ · ГЛАВА %d" % (V10MjBridgeLevels.chapter_of(level) + 1), 15, T.gold500, "body", 900)
	over.position = Vector2(32, 32)
	p.add_child(over)
	var h1: = V10MjBridgeLook.label("Уровень %d" % level, 44, T.paper100, "title", 700)
	h1.position = Vector2(32, 58)
	p.add_child(h1)
	var dn: = V10MjBridgeLook.label(V10MjBridgeLevels.difficulty_name(level), 20, T.gold300 if int(lv.req) > 1 else T.paper500, "body", 800)
	dn.position = Vector2(34, 122)
	p.add_child(dn)
	var sr: = V10MjBridgeLook.stars_row(V10MjBridgeSave.hand_stars_of(save_d, level), 3, 34.0)
	sr.position = Vector2(vw.x - 32.0 - sr.size.x, 72)
	p.add_child(sr)
	for k in V10MjBridgeInfo.HOW_HAND.size():
		var row: Array = V10MjBridgeInfo.HOW_HAND[k]
		var ic: = V10MjBridgeIcon.new(row[0], T.gold300)
		ic.position = Vector2(32, 170 + k * 46)
		ic.size = Vector2(36, 36)
		p.add_child(ic)
		var l: = V10MjBridgeLook.label(row[1], 20, T.paper300, "body", 700)
		l.position = Vector2(84, 174 + k * 46)
		p.add_child(l)
	var play: = V10MjBridgeLook.primary("Играть")
	play.name = "Play"
	play.position = Vector2(vw.x * 0.5 - 280.0, 470.0 - 136.0)
	play.pressed.connect(func():
		V10MjBridgeLook.close_sheet(sheet_layer)
		_start())
	V10MjBridgeLook.breathe(play)
	p.add_child(play)


func _pause_sheet() -> void:
	if ended:
		return
	var was: = input_on
	input_on = false
	var p: = V10MjBridgeLook.sheet(sheet_layer, vw, 560.0)
	var h: = V10MjBridgeLook.label("Пауза", 32, T.paper100, "title", 600)
	h.position = Vector2(32, 32)
	p.add_child(h)
	for k in V10MjBridgeInfo.HOW_HAND.size():
		var row: Array = V10MjBridgeInfo.HOW_HAND[k]
		var ic: = V10MjBridgeIcon.new(row[0], T.gold300)
		ic.position = Vector2(32, 96 + k * 64)
		ic.size = Vector2(44, 44)
		p.add_child(ic)
		var l: = V10MjBridgeLook.label(row[1], 20, T.paper300, "body", 700)
		l.position = Vector2(92, 104 + k * 64)
		p.add_child(l)
	var go_on: = V10MjBridgeLook.primary("Продолжить")
	go_on.position = Vector2(vw.x * 0.5 - 280.0, 320)
	go_on.pressed.connect(func():
		V10MjBridgeLook.close_sheet(sheet_layer)
		input_on = was)
	p.add_child(go_on)
	var quit: = V10MjBridgeLook.secondary("Выйти")
	quit.position = Vector2(vw.x * 0.5 - 180.0, 444)
	quit.pressed.connect(func():
		V10MjBridgeLook.close_sheet(sheet_layer)
		_finish_result(false)
		result["action"] = "exit"
		finished.emit(result))
	p.add_child(quit)


func _lose_sheet() -> void:
	var p: = V10MjBridgeLook.sheet(sheet_layer, vw, 440.0)
	var h: = V10MjBridgeLook.label("Почти!", 44, T.paper100, "title", 700)
	h.position = Vector2(32, 36)
	p.add_child(h)
	var why: = "Рука полна, а формы нет" if rules.lost_why != "combo" else "Рука собрана, но нужна комбинация от ×%d" % int(lv.req)
	var c: = V10MjBridgeLook.label(why, 22, T.paper300, "body", 700)
	c.position = Vector2(34, 104)
	c.size = Vector2(vw.x - 68, 60)
	c.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p.add_child(c)
	var prim: Button
	if rules.resets_left > 0:
		prim = V10MjBridgeLook.primary("Сброс и играть")
		prim.pressed.connect(func():
			V10MjBridgeLook.close_sheet(sheet_layer)
			var w: = rules.worst_in_hand()
			for n in hand_nodes:
				if (n as V10MjBridgeTile).kind == w:
					_reset_node(n, false)
					break
			presence.on("start", {})
			input_on = true)
	else:
		prim = V10MjBridgeLook.primary("Ещё раз")
		prim.pressed.connect(func():
			V10MjBridgeLook.close_sheet(sheet_layer)
			ended = true
			_finish_result(false)
			result["action"] = "retry"
			finished.emit(result))
	prim.name = "Primary"
	prim.position = Vector2(vw.x * 0.5 - 280.0, 190)
	p.add_child(prim)
	var sec: = V10MjBridgeLook.secondary("В Столы")
	sec.position = Vector2(vw.x * 0.5 - 180.0, 320)
	sec.pressed.connect(func():
		V10MjBridgeLook.close_sheet(sheet_layer)
		ended = true
		_finish_result(false)
		result["action"] = "exit"
		finished.emit(result))
	p.add_child(sec)


func _win_sheet() -> void:
	var p: = V10MjBridgeLook.sheet(sheet_layer, vw, 600.0)
	var h: = V10MjBridgeLook.label("Рука собрана", 56, T.paper100, "title", 700)
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.size = Vector2(vw.x, 72)
	h.position = Vector2(0, 26)
	p.add_child(h)
	var sr: = V10MjBridgeLook.stars_row(int(result.stars), 3, 52.0)
	sr.position = Vector2(vw.x * 0.5 - sr.size.x * 0.5, 112)
	p.add_child(sr)
	for k in sr.get_child_count():
		var st: Control = sr.get_child(k)
		st.pivot_offset = st.size * 0.5
		st.scale = Vector2.ZERO
		var tw: = st.create_tween()
		tw.tween_interval(0.15 + k * 0.14)
		tw.tween_property(st, "scale", Vector2(1.15, 0.9), 0.1)
		tw.tween_property(st, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var ids: Array = result.combos
	var y: = 186.0
	if not ids.is_empty():
		var cl: = V10MjBridgeLook.label(V10MjBridgeHand.combo_line(ids, int(result.mult)), 24, T.gold300, "body", 800)
		cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cl.size = Vector2(vw.x - 48, 34)
		cl.position = Vector2(24, y)
		p.add_child(cl)
		var ol: = V10MjBridgeLook.label(V10MjBridgeHand.combo_orig(ids), 18, T.paper500, "body", 700)
		ol.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ol.size = Vector2(vw.x, 26)
		ol.position = Vector2(0, y + 36)
		p.add_child(ol)
		y += 70.0
	var sc: = V10MjBridgeLook.label("%d очков" % score, 22, T.paper300, "body", 800)
	sc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sc.size = Vector2(vw.x, 32)
	sc.position = Vector2(0, y)
	p.add_child(sc)
	var rw: Dictionary = result.rewards
	var tokens: = []
	if int(rw.get("coins", 0)) > 0:
		tokens.append("+%d монет" % int(rw.coins))
	if int(rw.get("aff", 0)) > 0:
		tokens.append("+%d симпатии" % int(rw.aff))
	var tx: = vw.x * 0.5 - tokens.size() * 100.0
	for k in tokens.size():
		var t: = V10MjBridgeLook.label(tokens[k], 18, T.gold300, "body", 800)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		t.size = Vector2(196, 30)
		t.position = Vector2(tx + k * 200.0, y + 44)
		t.modulate.a = 0.0
		p.add_child(t)
		var tw2: = t.create_tween()
		tw2.tween_interval(0.6 + k * 0.08)
		tw2.tween_property(t, "modulate:a", 1.0, 0.12)
	var nxt: = mini(level + 1, V10MjBridgeLevels.COUNT)
	var prim: = V10MjBridgeLook.primary("Ещё уровень · %d" % nxt)
	prim.name = "Primary"
	prim.position = Vector2(vw.x * 0.5 - 280.0, 600.0 - 136.0 - 96.0)
	prim.pressed.connect(func():
		result["action"] = "next"
		finished.emit(result))
	V10MjBridgeLook.breathe(prim)
	p.add_child(prim)
	var sec: = V10MjBridgeLook.secondary("В Столы")
	sec.position = Vector2(vw.x * 0.5 - 180.0, 600.0 - 120.0)
	sec.pressed.connect(func():
		result["action"] = "exit"
		finished.emit(result))
	p.add_child(sec)
