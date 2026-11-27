class_name V10MjTriplesPresence
extends Control

# Героиня на краю стола в Тройках — встроенная «лёгкая» версия контракта presence (docs/MODES.md §3, §7.1):
#   on(event, data) и sacred(rect). Когда в игру вольётся режиссёр дорожки stage (V10MjPresence), экран берёт его,
#   а этот узел остаётся запасным (самотест, демо, сборка без stage).
#
# Что она делает, никогда не заходя на святую зону (поле + лоток + ряд помощи, +8 px), пока ввод включён:
#   • арочное окно в её полосе: портрет её наряда (кадр до пояса), подложка её цвета, тонкая линия gold700 35 %,
#     кольцо Приёма по контуру арки (одна честная шкала), тап по окну = Приём, если готов;
#   • pick — портрет чуть «смотрит» в сторону тапа (параллакс 5 px); pair — кивок-отскок и вспышка кольца;
#     combo ×3 наклон, ×5 «хлопок» (искры вокруг окна), ×8 кадр-поза (окно приближает лицо на 0,6 с);
#     signature — её стинг и тёплое сияние; danger — сердцебиение окна ≈ 1 Гц, тёплый край экрана (ember) ВНЕ
#     святой зоны; idle 20 с — лёгкое покачивание;
#   • win — после «Благословения стола» полный выход: она в полный рост выезжает справа поверх притушенного стола
#     (поле уже неактивно), тап — пропуск; lose — тёплая поза в окне и одна реплика «почти»;
#   • реплики — Playfair Italic у плеча (до появления голосов stage), не чаще 1 раза в 20 с, одна и та же — раз в 60 с.
# fx_level = min: без движения, реакции — смена яркости за 120 мс.

signal portrait_tapped
signal finale_done

const SIGNATURE: = {"mc": 0, "rin": 21, "hana": 9, "yue": 7, "nova": 24}
const LINES: = {
	"start": {"mc": "Сыграем по три?", "rin": "Чай остынет — играем.", "hana": "На старт!", "yue": "Луна смотрит.", "nova": "Система готова."},
	"combo": {"mc": "Чудесно!", "rin": "Изящно.", "hana": "Темп!", "yue": "Как красиво…", "nova": "Чисто!"},
	"danger": {"mc": "Осторожно, милый…", "rin": "Не торопись.", "hana": "Дыши. Ещё чуть-чуть.", "yue": "Тише… подумай.", "nova": "Буфер почти полон."},
	"signature": {"mc": "Моя сакура!", "rin": "Мой чай.", "hana": "Моё солнце!", "yue": "Моя луна.", "nova": "Мой кристалл."},
	"win": {"mc": "Стол чист!", "rin": "Безупречно.", "hana": "Финиш!", "yue": "Прекрасная ночь.", "nova": "Доступ получен."},
	"lose": {"mc": "Почти! Ещё раз?", "rin": "Почти. Ещё чашку?", "hana": "Почти! Реванш!", "yue": "Почти… ещё раз.", "nova": "Почти. Перезапуск?"},
	"booster": {"mc": "Новая помощь — попробуй.", "rin": "Возьми, пригодится.", "hana": "Новый приём в копилку!", "yue": "Подарок луны.", "nova": "Новый модуль открыт."},
}
const LINE_CD: = 20.0
const SAME_LINE_CD: = 60.0
const MICRO_EVERY: = 3

var hero: = "mc"
var acc: Array = []
var sacred_rects: Array[Rect2] = []
var input_on: = true
var win_rect: = Rect2()         # окно портрета (в координатах экрана)
var band_rect: = Rect2()
var screen_size: = Vector2(720, 1280)
var charge01: = 0.0
var ready_ult: = false
var danger: = false
var mode: = "live"              # live | quiet | finish (настройка «Героиня в партии», MODES §3.5)
var fx_min: = false
var events: Array = []          # журнал событий (самотест)
var lines_said: Array = []
var yield_nodes: Array = []      # узлы полосы, уступающие место реплике на коротком экране (9:16)

var _win_node: Control
var _art: TextureRect
var _art_tex: Texture2D
var _face_rect: = Rect2()
var _waist_rect: = Rect2()
var _ring_flash: = 0.0
var _heart_t: = 0.0
var _edge: Control
var _line: Label
var _last_line_t: = -999.0
var _line_t: = {}
var _moves: = 0
var _idle_t: = 0.0
var _parallax: = Vector2.ZERO
var _zoom: = 0.0
var _finale: Control
var _shown_full: = false
var _sound: V10MjTriplesSound


func attach(screen: Control, h: String, opts: = {}) -> V10MjTriplesPresence:
	hero = h if V10MjTriplesLook.ACCENT.has(h) else "mc"
	acc = V10MjTriplesLook.accent(hero)
	mode = String(opts.get("mode", _setting_mode()))
	fx_min = V9Feel.level() == "min" or bool(opts.get("fx_min", false))
	_sound = opts.get("sound")
	name = "TriplesPresence"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.add_child(self)
	_build()
	return self


func _setting_mode() -> String:
	var st = G.S.get("v10_mj_stage", {}) if G.S is Dictionary else {}
	if st is Dictionary:
		return String(st.get("mode", "live"))
	return "live"


func sacred(r: Rect2) -> void:
	sacred_rects.append(r.grow(8.0))
	if _edge:
		_edge.queue_redraw()


func _build() -> void:
	_edge = Control.new()
	_edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_edge.set_anchors_preset(Control.PRESET_FULL_RECT)
	_edge.draw.connect(_draw_edge)
	add_child(_edge)
	_win_node = Control.new()
	_win_node.name = "PortraitWindow"
	_win_node.mouse_filter = Control.MOUSE_FILTER_STOP
	_win_node.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	_win_node.draw.connect(_draw_window)
	_win_node.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			V9Feel.press(_win_node, "pop", "button")
			portrait_tapped.emit())
	add_child(_win_node)
	_art = TextureRect.new()
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_win_node.add_child(_art)
	var ring: = Control.new()
	ring.name = "Ring"
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.draw.connect(_draw_ring.bind(ring))
	add_child(ring)
	_line = V10MjTriplesLook.label("", 26, V10MjTriplesLook.TOK.paper100, "italic", 600)
	_line.label_settings.shadow_color = Color(0, 0, 0, 0.55)
	_line.label_settings.shadow_size = 6
	_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.modulate.a = 0.0
	add_child(_line)
	_load_art()


func _load_art() -> void:
	var id: = V9Ults.for_hero(hero)
	var sh: = V9Ults.shown(id)
	var path: String = sh.get("img", "")
	if path == "" or not ResourceLoader.exists(path):
		path = V10W1Core.hero_png(hero)
	if not ResourceLoader.exists(path):
		path = "res://assets/hero/mc.png"
	_art_tex = load(path) if ResourceLoader.exists(path) else null
	if _art_tex == null:
		return
	var ts: = Vector2(_art_tex.get_width(), _art_tex.get_height())
	_face_rect = V9Ults.rect_px(sh.get("face_rect", Rect2(Vector2.ZERO, V9Ults.ART_SIZE)), ts)
	_waist_rect = V9Ults.rect_px(sh.get("alt_rect", Rect2(Vector2.ZERO, V9Ults.ART_SIZE)), ts)


# раскладка: полоса героини и окно портрета (экран считает их по высоте экрана)
func layout(band: Rect2, window: Rect2, scr: Vector2) -> void:
	band_rect = band
	win_rect = window
	screen_size = scr
	_win_node.position = window.position
	_win_node.size = window.size
	_win_node.pivot_offset = window.size * Vector2(0.5, 1.0)
	_art.size = window.size
	_update_art()
	var ring: Control = get_node("Ring")
	ring.position = window.position - Vector2(10, 10)
	ring.size = window.size + Vector2(20, 20)
	if band.size.y <= 140.0:
		# короткая полоса (9:16): реплика встаёт на место строки «Осталось», та на 4 с притихает
		_line.size = Vector2(window.position.x - 104.0 - 12.0, 64)
		_line.position = Vector2(104.0, maxf(8.0, band.size.y * 0.5 - 40.0))
	else:
		_line.size = Vector2(maxf(160.0, window.position.x - 140.0), 80)
		_line.position = Vector2(window.position.x - _line.size.x - 12.0, window.end.y - 84.0)
	_edge.queue_redraw()
	_win_node.queue_redraw()
	ring.queue_redraw()


func _update_art() -> void:
	if _art_tex == null or win_rect.size.x <= 0:
		return
	# кадр: от лица до пояса; при приближении (×8) — к лицу
	var base: = _waist_rect
	var target: = _face_rect.grow(_face_rect.size.x * 0.25)
	var r: = Rect2(base.position.lerp(target.position, _zoom), base.size.lerp(target.size, _zoom))
	# подогнать под пропорции окна (обрезка по ширине или высоте, лицо в верхней трети)
	var wa: = win_rect.size.x / win_rect.size.y
	if r.size.x / r.size.y > wa:
		var nw: = r.size.y * wa
		r.position.x += (r.size.x - nw) * 0.5
		r.size.x = nw
	else:
		var nh: = r.size.x / wa
		r.size.y = nh
	r.position += _parallax * (r.size.x / win_rect.size.x)
	var at: = AtlasTexture.new()
	at.atlas = _art_tex
	at.region = r
	_art.texture = at


func _draw_window() -> void:
	var s: = _win_node.size
	var pts: = arch_points(Rect2(Vector2.ZERO, s), 28)
	var deep: Color = acc[2]
	_win_node.draw_colored_polygon(pts, deep.darkened(0.25))


func _draw_ring(ring: Control) -> void:
	var r: = Rect2(Vector2(10, 10), win_rect.size)
	var path: = arch_points(r, 40, false)
	# контур: тонкая линия gold700 при 35 %
	var outline: = path.duplicate()
	ring.draw_polyline(outline, Color(V10MjTriplesLook.TOK.gold700, 0.35), 1.0, true)
	# кольцо Приёма — от левой «ножки» арки через верх к правой
	var n: = int(round((path.size() - 1) * clampf(charge01, 0.0, 1.0)))
	var a: Color = acc[0]
	if danger:
		a = a.lerp(V10MjTriplesLook.TOK.ember, 0.35)
	if n >= 1:
		var seg: = path.slice(0, n + 1)
		var w: = 5.0 + 3.0 * _ring_flash
		ring.draw_polyline(seg, Color(a, 0.95), w, true)
		ring.draw_circle(seg[seg.size() - 1], w * 0.9, Color(acc[1], 0.9))
	if ready_ult:
		ring.draw_polyline(path, Color(acc[1], 0.35 + 0.35 * _ring_flash), 9.0, true)


# контур арки: прямоугольник с полукруглым верхом; open = false — без нижней кромки (кольцо от ножки до ножки)
static func arch_points(r: Rect2, seg: = 24, closed: = true) -> PackedVector2Array:
	var pts: = PackedVector2Array()
	var rad: = r.size.x * 0.5
	var cy: = r.position.y + rad
	pts.append(Vector2(r.position.x, r.end.y))
	pts.append(Vector2(r.position.x, cy))
	for k in range(1, seg):
		var an: = PI + PI * k / seg
		pts.append(Vector2(r.position.x + rad + cos(an) * rad, cy + sin(an) * rad))
	pts.append(Vector2(r.end.x, cy))
	pts.append(Vector2(r.end.x, r.end.y))
	if closed:
		pts.append(pts[0])
	return pts


func _draw_edge() -> void:
	if not danger or mode != "live":
		return
	var a: = 0.42 + (0.0 if fx_min else 0.22 * maxf(0.0, sin(_heart_t * TAU)))
	var w: = 26.0
	for side in [0, 1]:
		var x0: float = 0.0 if side == 0 else screen_size.x - w
		for r in edge_rects(x0, w):
			var c0: = Color(V10MjTriplesLook.TOK.ember, a)
			var c1: = Color(V10MjTriplesLook.TOK.ember, 0.0)
			var cols: = PackedColorArray([c0, c1, c1, c0]) if side == 0 else PackedColorArray([c1, c0, c0, c1])
			_edge.draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]), cols)


# полосы тёплого края: по высоте экрана, за вычетом святой зоны
func edge_rects(x0: float, w: float) -> Array[Rect2]:
	var spans: Array = [[0.0, screen_size.y]]
	var strip: = Rect2(x0, 0, w, screen_size.y)
	for s in sacred_rects:
		if not s.intersects(strip):
			continue
		var nxt: Array = []
		for sp in spans:
			var a: float = sp[0]
			var b: float = sp[1]
			if s.end.y <= a or s.position.y >= b:
				nxt.append(sp)
				continue
			if s.position.y > a:
				nxt.append([a, s.position.y])
			if s.end.y < b:
				nxt.append([s.end.y, b])
		spans = nxt
	var out: Array[Rect2] = []
	for sp in spans:
		if sp[1] - sp[0] > 4.0:
			out.append(Rect2(x0, sp[0], w, sp[1] - sp[0]))
	return out


# всё, что героиня сейчас рисует (для аудита святой зоны)
func drawn_rects() -> Array[Rect2]:
	var out: Array[Rect2] = [win_rect.grow(10.0)]
	if _line.modulate.a > 0.01:
		out.append(Rect2(_line.position, _line.size))
	if danger and mode == "live":
		for side in [0, 1]:
			out.append_array(edge_rects(0.0 if side == 0 else screen_size.x - 26.0, 26.0))
	if _finale and is_instance_valid(_finale):
		out.append(Rect2(Vector2.ZERO, screen_size))
	return out


func sacred_hits() -> int:
	if not input_on:
		return 0
	var n: = 0
	for d in drawn_rects():
		for s in sacred_rects:
			if d.intersects(s):
				n += 1
	return n


func set_charge(v: float, rdy: bool) -> void:
	charge01 = v
	ready_ult = rdy
	get_node("Ring").queue_redraw()


func window_center() -> Vector2:
	return win_rect.get_center()


# ── события ──────────────────────────────────────────────────────────────────

func on(event: String, data: = {}) -> void:
	events.append(event)
	_idle_t = 0.0
	match event:
		"pick":
			_moves += 1
			if data.has("pos") and not fx_min:
				var p: Vector2 = data.pos
				var d: = (p - win_rect.get_center())
				_parallax = Vector2(clampf(d.x / 120.0, -1, 1), clampf(d.y / 300.0, -1, 1)) * -5.0
				_update_art()
		"pair":
			_bounce(1.035, 0.38)
			_flash_ring()
		"combo":
			var n: = int(data.get("n", 0))
			if n >= 8:
				_pose_zoom()
			elif n >= 5:
				_bounce(1.07, 0.5)
				_say("combo")
			elif n >= 3:
				_tilt()
		"signature":
			_bounce(1.06, 0.5)
			_flash_ring()
			_say("signature")
		"danger":
			var on_: = bool(data.get("on", false))
			if on_ != danger:
				danger = on_
				var tw: = _art.create_tween()
				tw.tween_property(_art, "modulate", Color(1.0, 0.86, 0.82) if danger else Color.WHITE, 0.3)
				if danger:
					_say("danger")
				_edge.queue_redraw()
				get_node("Ring").queue_redraw()
		"start":
			_say("start")
		"booster":
			_say("booster")
		"ult":
			_bounce(1.08, 0.6)
			_flash_ring()
		"win":
			danger = false
			_edge.queue_redraw()
			_say("win", true)
			_finale_win()
		"lose":
			danger = false
			_edge.queue_redraw()
			_say("lose", true)
			_tilt()
		"last_pair", "motif", "wave", "idle":
			pass


func _process(dt: float) -> void:
	if danger:
		var prev: = _heart_t
		_heart_t += dt * 1.0
		if int(prev) != int(_heart_t):
			if _sound and mode == "live":
				_sound.heartbeat()
			if not fx_min:
				_bounce(1.02, 0.25)
		if mode == "live":
			_edge.queue_redraw()
	if input_on:
		_idle_t += dt
		if _idle_t > 20.0:
			_idle_t = 0.0
			on("idle")
			_tilt()


func _bounce(k: float, t: float) -> void:
	if mode == "finish":
		return
	if fx_min:
		_dim_flash()
		return
	var tw: = _win_node.create_tween()
	tw.tween_property(_win_node, "scale", Vector2(k, k), t * 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_win_node, "scale", Vector2.ONE, t * 0.65).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _tilt() -> void:
	if fx_min or mode == "finish":
		return
	var tw: = _win_node.create_tween()
	tw.tween_property(_win_node, "rotation", 0.045, 0.14).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_win_node, "rotation", -0.02, 0.16).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_win_node, "rotation", 0.0, 0.14).set_trans(Tween.TRANS_SINE)


func _dim_flash() -> void:
	var tw: = _art.create_tween()
	tw.tween_property(_art, "modulate", Color(1.15, 1.1, 1.05), 0.06)
	tw.tween_property(_art, "modulate", Color.WHITE, 0.12)


func _flash_ring() -> void:
	var ring: Control = get_node("Ring")
	var tw: = ring.create_tween()
	tw.tween_method(func(v): _ring_flash = v; ring.queue_redraw(), 1.0, 0.0, 0.45)


func _pose_zoom() -> void:
	if fx_min or mode == "finish":
		_dim_flash()
		return
	var tw: = create_tween()
	tw.tween_method(func(v): _zoom = v; _update_art(), 0.0, 1.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.6)
	tw.tween_method(func(v): _zoom = v; _update_art(), 1.0, 0.0, 0.3).set_trans(Tween.TRANS_SINE)


func _say(kind: String, force: = false) -> void:
	if mode != "live" and not (force and mode != "quiet"):
		return
	var now: = Time.get_ticks_msec() / 1000.0
	if not force and now - _last_line_t < LINE_CD:
		return
	var key: = kind
	if not force and now - float(_line_t.get(key, -999.0)) < SAME_LINE_CD:
		return
	var txt: String = LINES.get(kind, {}).get(hero, "")
	if txt == "":
		return
	_last_line_t = now
	_line_t[key] = now
	lines_said.append(txt)
	_line.text = txt
	var tw: = _line.create_tween()
	_line.modulate.a = 0.0
	tw.tween_property(_line, "modulate:a", 1.0, 0.4 if not fx_min else 0.12)
	tw.tween_interval(3.6)
	tw.tween_property(_line, "modulate:a", 0.0, 0.3)
	if band_rect.size.y <= 140.0:
		for n in yield_nodes:
			if is_instance_valid(n):
				var t2: = (n as CanvasItem).create_tween()
				t2.tween_property(n, "modulate:a", 0.0, 0.2)
				t2.tween_interval(3.9)
				t2.tween_property(n, "modulate:a", 1.0, 0.3)


# победа: она выходит в полный рост справа поверх притушенного (уже неактивного) стола; тап — пропуск
func _finale_win() -> void:
	if _art_tex == null:
		finale_done.emit.call_deferred()
		return
	input_on = false
	_finale = Control.new()
	_finale.set_anchors_preset(Control.PRESET_FULL_RECT)
	_finale.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_finale)
	var dim: = ColorRect.new()
	dim.color = Color(V10MjTriplesLook.TOK.night900, 0.0)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_finale.add_child(dim)
	# «обложка»: она в полный рост в высокой арке (рамка — тонкая линия gold700, как окно в полосе)
	var h: = screen_size.y * 0.74
	var w: = minf(screen_size.x * 0.8, h * 0.62)
	var card: = Control.new()
	card.name = "FinaleCard"
	card.size = Vector2(w, h)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	var deep: Color = acc[2]
	card.draw.connect(func():
		card.draw_colored_polygon(arch_points(Rect2(Vector2.ZERO, card.size), 40), deep.darkened(0.3)))
	var tr: = TextureRect.new()
	tr.texture = _art_tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.size = card.size
	card.add_child(tr)
	var line: = Control.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.size = card.size
	line.draw.connect(func():
		line.draw_polyline(arch_points(Rect2(Vector2(1, 1), card.size - Vector2(2, 2)), 40), Color(V10MjTriplesLook.TOK.gold500, 0.55), 2.0, true))
	var holder: = Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.size = card.size
	holder.add_child(card)
	holder.add_child(line)
	var glow: = TextureRect.new()
	glow.texture = G.fx("glow")
	glow.modulate = Color(acc[0], 0.35)
	glow.material = Fx.add_mat()
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.size = card.size * 1.5
	glow.position = -card.size * 0.25
	_finale.add_child(glow)
	_finale.add_child(holder)
	var end_x: = screen_size.x - w - 24.0
	var y: = band_rect.end.y + (screen_size.y - band_rect.end.y - h) * 0.42
	holder.position = Vector2(screen_size.x + 30.0, y)
	glow.position = holder.position - card.size * 0.25
	var tr2: = holder
	var done: = func():
		if _finale and is_instance_valid(_finale) and not _shown_full:
			_shown_full = true
			finale_done.emit()
	_finale.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			done.call())
	var tw: = _finale.create_tween()
	tw.tween_property(dim, "color:a", 0.62, 0.3)
	if fx_min:
		tr2.position.x = end_x
		tr2.modulate.a = 0.0
		tw.parallel().tween_property(tr2, "modulate:a", 1.0, 0.12)
		glow.position.x = end_x - card.size.x * 0.25
	else:
		tr2.rotation = 0.06
		tw.parallel().tween_property(tr2, "position:x", end_x, 0.6).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(tr2, "rotation", -0.015, 0.6).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(glow, "position:x", end_x - card.size.x * 0.25, 0.6).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.8)
	tw.tween_callback(done)


func hide_finale() -> void:
	if _finale and is_instance_valid(_finale):
		var f: = _finale
		_finale = null
		var tw: = f.create_tween()
		tw.tween_property(f, "modulate:a", 0.0, 0.25)
		tw.tween_callback(f.queue_free)
