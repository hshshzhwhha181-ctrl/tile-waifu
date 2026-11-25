class_name V10MjBridgePresence
extends Control

# Героиня моста — встроенная лёгкая заглушка контракта presence (docs/MODES.md §3, §7.1): on(event, data) и
# sacred(rect). Если экран получил args.presence (режиссёр дорожки stage, V10MjPresence), события идут ему, а этот
# узел остаётся только окном-целью для искр и местом её фразы-объяснения (Задача дня).
#
# Никогда не заходит на святую зону (рука/поле + ряд кнопок, +8 px), пока ввод включён:
#   • арочное окно в её полосе: кадр до пояса (assets/v08/emotions), подложка её цвета, линия gold700 35 %,
#     кольцо Приёма по контуру арки (только где есть Приём — Собери руку);
#   • pick — взгляд к тапу (сдвиг кадра 4 px); pair — улыбка и искры (≤ 8, альфа ≤ 0,6, ≤ 0,45 с) в окно;
#     combo ≥ 5 — хлопок (кадр «удивление» + кольцо вспыхивает); last_pair — «ах, почти» (кадр удивления, взгляд);
#     danger — закушенная губа (кадр pout), тёплый край экрана ВНЕ святой зоны; win — выход крупно (стол уже
#     неактивен), тап — пропуск, сигнал finale_done; lose — тёплый кадр sad;
#   • реплики — голос героини (Caveat 600, без коробки), пером 0,4 с, держится 4 с; объяснение задачи — до конца.
# fx min (V9Feel) — без движения, кадры меняются за 120 мс.

signal portrait_tapped
signal finale_done

const EMO: = "res://assets/v08/emotions/%s_%s.webp"
const FRAME_OF: = {"idle": "shy", "smile": "happy", "ah": "surprised", "bite": "pout", "lose": "sad", "win": "happy",
	"look": "happy"}
const LINE_CD: = 20.0

var hero: = "mc"
var acc: Array = []
var sacred_rects: Array = []
var input_on: = true
var win_rect: = Rect2()
var band_rect: = Rect2()
var line_rect: = Rect2()
var show_ring: = true
var charge01: = 0.0
var ready_ult: = false
var danger: = false
var fx_min: = false
var events: Array = []
var lines_said: Array = []

var _win: Control
var _art: TextureRect
var _ring: Control
var _edge: Control
var _motes: Control
var _line: Label
var _frame: = "idle"
var _hold_t: = 0.0
var _heart: = 0.0
var _flash: = 0.0
var _last_line_t: = -999.0
var _finale: Control
var _line_tw: Tween


func attach(screen: Control, h: String, opts: = {}) -> V10MjBridgePresence:
	hero = V10MjBridgeLook.hero_ok(h)
	acc = V10MjBridgeLook.accent(hero)
	fx_min = V9Feel.level() == "min" or bool(opts.get("fx_min", false))
	show_ring = bool(opts.get("ring", true))
	name = "BridgePresence"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.add_child(self)
	_build()
	return self


func _build() -> void:
	_edge = Control.new()
	_edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_edge.set_anchors_preset(Control.PRESET_FULL_RECT)
	_edge.draw.connect(_draw_edge)
	add_child(_edge)
	_win = Control.new()
	_win.name = "PortraitWindow"
	_win.mouse_filter = Control.MOUSE_FILTER_STOP
	_win.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	_win.draw.connect(_draw_window)
	_win.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			portrait_tapped.emit())
	add_child(_win)
	_art = TextureRect.new()
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_SCALE
	_win.add_child(_art)
	_ring = Control.new()
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ring.draw.connect(_draw_ring)
	add_child(_ring)
	_line = V10MjBridgeLook.label("", 30, V10MjBridgeLook.TOK.paper100, "voice", 600)
	_line.label_settings.shadow_color = Color(0, 0, 0, 0.6)
	_line.label_settings.shadow_size = 8
	_line.label_settings.line_spacing = -4
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_line.modulate.a = 0.0
	add_child(_line)
	_motes = Control.new()
	_motes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_motes.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_motes)
	_set_frame("idle")


# окно портрета и место её фразы (у плеча, слева от окна или под ним)
func layout(band: Rect2, win: Rect2, line: Rect2) -> void:
	band_rect = band
	win_rect = win
	line_rect = line
	_win.position = win.position
	_win.size = win.size
	_fit_art()
	_line.position = line.position
	_line.size = line.size
	_win.queue_redraw()
	_ring.queue_redraw()
	_edge.queue_redraw()


func sacred(r: Rect2) -> void:
	sacred_rects.append(r.grow(8.0))
	_edge.queue_redraw()


func clear_sacred() -> void:
	sacred_rects.clear()
	_edge.queue_redraw()


# режиссёр stage рисует своё окно — у заглушки остаётся только её фраза
func hide_window() -> void:
	_win.visible = false
	_ring.visible = false


func window_center() -> Vector2:
	return win_rect.get_center()


func set_charge(v: float, ready: bool) -> void:
	charge01 = clampf(v, 0.0, 1.0)
	ready_ult = ready
	_ring.queue_redraw()


# ── кадр ─────────────────────────────────────────────────────────────────────

func _set_frame(slot: String) -> void:
	_frame = slot
	var emo: String = FRAME_OF.get(slot, "shy")
	var p: = EMO % [hero, emo]
	if not ResourceLoader.exists(p):
		p = EMO % ["mc", emo]
	if ResourceLoader.exists(p):
		var t: Texture2D = load(p)
		if _art.texture != t:
			_art.texture = t
			if not fx_min:
				_art.modulate.a = 0.6
				var tw: = _art.create_tween()
				tw.tween_property(_art, "modulate:a", 1.0, 0.12)
	_fit_art()


func _fit_art() -> void:
	if _art == null or _art.texture == null or win_rect.size.x <= 0:
		return
	var ts: = _art.texture.get_size()
	var w: = win_rect.size.x * 1.25
	var tall: = win_rect.size.y / win_rect.size.x > 1.6
	if tall:
		w = maxf(win_rect.size.x * 1.05, win_rect.size.y * ts.x / ts.y * 1.02)
	var h: = w * ts.y / ts.x
	_art.size = Vector2(w, h)
	# лицо ≈ 24 % высоты кадра: на коротком окне — в верхней трети окна
	var face_y: = h * 0.24
	var y: = win_rect.size.y * (0.36 if not tall else 0.28) - face_y
	y = clampf(y, win_rect.size.y - h, 0.0)
	_art.position = Vector2((win_rect.size.x - w) * 0.5, y)


func _hold(slot: String, t: float) -> void:
	_set_frame(slot)
	_hold_t = t


func _bounce(k: = 1.04, t: = 0.24) -> void:
	if fx_min:
		return
	_win.pivot_offset = _win.size * Vector2(0.5, 1.0)
	var tw: = _win.create_tween()
	tw.tween_property(_win, "scale", Vector2(k, k), t * 0.4).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_win, "scale", Vector2.ONE, t * 0.6).set_trans(Tween.TRANS_SINE)


# ── события (словарь §3.2) ───────────────────────────────────────────────────

func on(event: String, data: = {}) -> void:
	events.append(event)
	match event:
		"start":
			_set_frame("idle")
		"pick":
			if data.has("pos") and not fx_min:
				var d: Vector2 = (data.pos as Vector2) - win_rect.get_center()
				_art.position.x += clampf(d.x * 0.01, -4.0, 4.0)
				var tw: = _art.create_tween()
				tw.tween_interval(0.3)
				tw.tween_callback(_fit_art)
		"pair":
			_hold("smile", 0.9)
			_bounce()
			if data.has("pos"):
				motes(data.pos)
			if data.has("charge"):
				set_charge(float(data.charge), charge01 >= 1.0)
		"combo":
			if int(data.get("n", 0)) >= 5:
				_hold("ah", 1.2)
				_flash = 1.0
				_bounce(1.07, 0.3)
		"signature":
			_hold("ah", 0.8)
			_flash = 1.0
		"last_pair":
			_hold("ah", 1.4)
			_bounce(1.03, 0.3)
		"danger":
			danger = bool(data.get("on", true))
			_set_frame("bite" if danger else "idle")
			_edge.queue_redraw()
		"ult":
			_hold("ah", 0.8)
			_flash = 1.0
		"win":
			danger = false
			input_on = false
			_edge.queue_redraw()
			_hold("win", 99.0)
			_finale_show()
		"lose":
			danger = false
			_edge.queue_redraw()
			_hold("lose", 99.0)
		"idle":
			_hold("look", 1.0)
			_bounce(1.02, 0.3)


# фраза героини у плеча: пером 0,4 с, держится hold с (≤ 0 — до следующей), не чаще раза в 20 с (кроме must)
func say(text: String, hold: = 4.0, must: = false) -> bool:
	var now: = Time.get_ticks_msec() / 1000.0
	if not must and now - _last_line_t < LINE_CD:
		return false
	if line_rect.size.x < 120.0:
		return false
	_last_line_t = now
	lines_said.append(text)
	_line.text = text
	_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if line_rect.end.x <= win_rect.position.x + 4.0 else HORIZONTAL_ALIGNMENT_LEFT
	if _line_tw and _line_tw.is_valid():
		_line_tw.kill()
	_line.modulate.a = 1.0
	_line_tw = _line.create_tween()
	if fx_min:
		_line.visible_ratio = 1.0
		_line.modulate.a = 0.0
		_line_tw.tween_property(_line, "modulate:a", 1.0, 0.12)
	else:
		_line.visible_ratio = 0.0
		_line_tw.tween_property(_line, "visible_ratio", 1.0, 0.4)
	if hold > 0.0:
		_line_tw.tween_interval(hold)
		_line_tw.tween_property(_line, "modulate:a", 0.0, 0.3)
	return true


func line_text() -> String:
	return _line.text if _line.modulate.a > 0.01 else ""


func line_node() -> Label:
	return _line


# ≤ 8 искр её цвета, альфа ≤ 0,6, ≤ 0,45 с по кратчайшему пути вверх, без остановок
func motes(from: Vector2) -> void:
	if fx_min:
		return
	var to: = win_rect.get_center()
	var n: = int(round(8 * V9Feel.fx_scale()))
	for k in mini(n, 8):
		var m: = _Mote.new()
		m.col = Color(acc[1] if k % 2 == 0 else acc[0], 0.6)
		m.r = randf_range(3.0, 5.5)
		m.p0 = from + Vector2(randf_range(-26, 26), randf_range(-10, 10))
		m.p1 = to
		m.mid = m.p0.lerp(to, 0.5) + Vector2(randf_range(-50, 50), -30)
		m.dur = randf_range(0.32, 0.45)
		_motes.add_child(m)


# ── финал: выход крупно (поле неактивно), тап — пропуск ──────────────────────

func _finale_show() -> void:
	var S: = get_viewport_rect().size
	_finale = Control.new()
	_finale.name = "Finale"
	_finale.mouse_filter = Control.MOUSE_FILTER_STOP
	_finale.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_finale)
	var dim: = ColorRect.new()
	dim.color = Color(V10MjBridgeLook.TOK.night900, 0.0)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_finale.add_child(dim)
	var art: = TextureRect.new()
	art.texture = _art.texture
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h: = S.y * 0.62
	var w: = h * 0.75
	art.size = Vector2(w, h)
	art.position = Vector2(S.x - w * 0.92, S.y)
	_finale.add_child(art)
	var tw: = _finale.create_tween().set_parallel()
	tw.tween_property(dim, "color:a", 0.5, 0.25)
	if fx_min:
		art.position.y = S.y - h
		art.modulate.a = 0.0
		tw.tween_property(art, "modulate:a", 1.0, 0.12)
	else:
		tw.tween_property(art, "position:y", S.y - h, 0.35).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	var done: = func():
		if _finale and is_instance_valid(_finale):
			_finale.queue_free()
			_finale = null
			finale_done.emit()
	_finale.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			done.call())
	get_tree().create_timer(1.6).timeout.connect(done)


func finale_active() -> bool:
	return _finale != null and is_instance_valid(_finale)


# ── рисование ─────────────────────────────────────────────────────────────────

static func arch(sz: Vector2, steps: = 20) -> PackedVector2Array:
	var pts: = PackedVector2Array()
	var r: = sz.x * 0.5
	pts.append(Vector2(0, sz.y))
	for k in steps + 1:
		var a: = PI + PI * float(k) / steps
		pts.append(Vector2(r + cos(a) * r, r + sin(a) * r))
	pts.append(Vector2(sz.x, sz.y))
	return pts


func _draw_window() -> void:
	var sz: = _win.size
	var pts: = arch(sz)
	var deep: Color = acc[2]
	_win.draw_colored_polygon(pts, Color(deep, 1.0).lerp(V10MjBridgeLook.TOK.night800, 0.35))
	_win.draw_circle(Vector2(sz.x * 0.5, sz.y * 0.45), sz.x * 0.55, Color(acc[0], 0.16))


func _draw_ring() -> void:
	if win_rect.size.x <= 0:
		return
	var off: = win_rect.position
	var pts: = arch(win_rect.size + Vector2(12, 6), 28)
	for k in pts.size():
		pts[k] += off - Vector2(6, 6)
	var line: = PackedVector2Array([pts[0]])
	for k in range(1, pts.size()):
		line.append(pts[k])
	_ring.draw_polyline(line, Color(V10MjBridgeLook.TOK.gold700, 0.35), 1.0, true)
	_ring.draw_line(Vector2(win_rect.position.x - 6, win_rect.end.y), Vector2(win_rect.end.x + 6, win_rect.end.y), Color(V10MjBridgeLook.TOK.gold700, 0.6), 1.5)
	if not show_ring:
		return
	# кольцо Приёма: от левой ножки арки через верх к правой
	var total: = 0.0
	for k in range(1, line.size()):
		total += line[k].distance_to(line[k - 1])
	var want: = total * charge01
	var part: = PackedVector2Array([line[0]])
	var acc_len: = 0.0
	for k in range(1, line.size()):
		var seg: = line[k].distance_to(line[k - 1])
		if acc_len + seg >= want:
			part.append(line[k - 1].lerp(line[k], (want - acc_len) / maxf(seg, 0.001)))
			break
		part.append(line[k])
		acc_len += seg
	var c: Color = acc[0] if not ready_ult else V10MjBridgeLook.TOK.gold300
	if part.size() >= 2:
		_ring.draw_polyline(part, Color(c, 0.9), 4.0 + _flash * 2.0, true)
	if ready_ult:
		_ring.draw_polyline(line, Color(V10MjBridgeLook.TOK.gold300, 0.25 + 0.2 * absf(sin(_heart * 2.0))), 8.0, true)


func _edge_strips() -> Array:
	var S: = get_viewport_rect().size
	var W: = 22.0
	var out: = []
	for base in [Rect2(0, 0, W, S.y), Rect2(S.x - W, 0, W, S.y), Rect2(0, S.y - W, S.x, W), Rect2(0, band_rect.end.y - W, S.x, W)]:
		out.append_array(rect_minus(base, sacred_rects))
	return out


static func rect_minus(r: Rect2, cut: Array) -> Array:
	var parts: = [r]
	for c in cut:
		var cr: Rect2 = c
		var nxt: = []
		for p in parts:
			var pr: Rect2 = p
			if not pr.intersects(cr):
				nxt.append(pr)
				continue
			if pr.position.y < cr.position.y:
				nxt.append(Rect2(pr.position, Vector2(pr.size.x, cr.position.y - pr.position.y)))
			if pr.end.y > cr.end.y:
				nxt.append(Rect2(Vector2(pr.position.x, cr.end.y), Vector2(pr.size.x, pr.end.y - cr.end.y)))
			var y0: = maxf(pr.position.y, cr.position.y)
			var y1: = minf(pr.end.y, cr.end.y)
			if pr.position.x < cr.position.x:
				nxt.append(Rect2(pr.position.x, y0, cr.position.x - pr.position.x, y1 - y0))
			if pr.end.x > cr.end.x:
				nxt.append(Rect2(cr.end.x, y0, pr.end.x - cr.end.x, y1 - y0))
		parts = nxt
	var out: = []
	for p in parts:
		if (p as Rect2).size.x >= 2.0 and (p as Rect2).size.y >= 2.0:
			out.append(p)
	return out


func _draw_edge() -> void:
	if not danger:
		return
	var a: = 0.18 + (0.0 if fx_min else 0.14 * absf(sin(_heart * PI)))
	for r in _edge_strips():
		_edge.draw_rect(r, Color(V10MjBridgeLook.TOK.ember, a))


func _process(dt: float) -> void:
	_heart += dt
	if _hold_t > 0.0:
		_hold_t -= dt
		if _hold_t <= 0.0:
			_set_frame("bite" if danger else "idle")
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - dt * 2.5)
		_ring.queue_redraw()
	if ready_ult:
		_ring.queue_redraw()
	if danger:
		_edge.queue_redraw()


# аудит святой зоны: окно, её фраза, тёплый край — ни одного пересечения, пока ввод включён
func audit_rects() -> Array:
	var out: = [win_rect.grow(6.0)]
	if _line.modulate.a > 0.01 and _line.text != "":
		out.append(Rect2(_line.position, _line.size))
	if danger:
		out.append_array(_edge_strips())
	return out


func sacred_hits() -> int:
	if not input_on:
		return 0
	var n: = 0
	for r in audit_rects():
		for s in sacred_rects:
			if (s as Rect2).intersects(r):
				n += 1
	return n


class _Mote extends Control:
	var col: = Color.WHITE
	var r: = 4.0
	var p0: = Vector2.ZERO
	var p1: = Vector2.ZERO
	var mid: = Vector2.ZERO
	var dur: = 0.4
	var t: = 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		position = p0

	func _process(dt: float) -> void:
		t += dt
		var v: = clampf(t / dur, 0.0, 1.0)
		var e: = v * v
		var u: = 1.0 - e
		position = p0 * u * u + mid * 2.0 * u * e + p1 * e * e
		modulate.a = 1.0 - v * 0.5
		queue_redraw()
		if v >= 1.0:
			queue_free()

	func _draw() -> void:
		draw_circle(Vector2.ZERO, r * 1.8, Color(col, col.a * 0.3))
		draw_circle(Vector2.ZERO, r, col)
