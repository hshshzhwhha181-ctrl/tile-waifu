class_name V10MjCubePresence
extends Control

# Героиня в партии Куба, когда режиссёр дорожки stage (V10MjPresence) не передан в args.presence (docs/MODES.md §3,
# §4.4 «Героиня»). Тот же контракт: attach / on(event, data) / sacred(rect) / input_on, и то же жёсткое правило: пока
# ввод включён, ни одного пикселя её самой, её текста или эффектов нет над святой зоной (вьюпорт куба + ряд помощи,
# +8 px). Исключение — искры пары: ≤ 8, альфа ≤ 0,6, полёт ≤ 0,45 с.
#   окно      — арка в её полосе справа: поясной кадр (assets/v08/emotions), кольцо Приёма вокруг арки
#   tilt(deg) — на повороте куба она чуть наклоняет голову в ту же сторону (±4°, плавно; при fx min — нет)
#   реплика   — Playfair Italic у плеча, вне святой зоны, ≤ 1 за 20 с (финиш — вне очереди), одна и та же — ≤ 1 за 60 с
#   финал     — win: окно вырастает в арку над пустым полем (ввод уже выключен), реликвия у неё в руках, тап — пропуск
# Когда args.presence есть, экран шлёт события ему, а эта заглушка остаётся только целью искр и кольцом (скрыта).

signal portrait_tapped
signal finale_done
signal reacted(event: String, info: Dictionary)

const EMO: = "res://assets/v08/emotions/%s_%s.webp"
const FRAME_OF: = {"rest": "shy", "smile": "happy", "ah": "surprised", "win": "happy", "lose": "sad", "bite": "pout",
	"wink": "happy", "look": "shy"}
const PAD: = 8.0
const TILT_MAX: = 4.0
const LINE_GAP: = 20.0
const LINE_SAME: = 60.0

# реплики (≤ 32 знаков, без стоп-слов V10Lint и UX §4.3; голос и Caveat — у дорожки stage)
const LINES: = {
	"start": {"mc": "Покрутим его вместе?", "rin": "Не спеши. Повернём.", "hana": "Крути смелее!",
		"yue": "Посмотри и с другой стороны.", "nova": "Сканирую фигуру. Готово."},
	"combo": {"mc": "Красиво идёшь!", "rin": "Ровно, как чайная церемония.", "hana": "Темп держишь!",
		"yue": "Как лунная дорожка.", "nova": "Серия без ошибок."},
	"motif": {"mc": "Тот же узор — вдвое!", "rin": "Повтор. Изящно.", "hana": "Дубль!", "yue": "Эхо узора.",
		"nova": "Узор совпал. Вдвое!"},
	"signature": {"mc": "Мой веер!", "rin": "Моя чаша.", "hana": "Моё солнце!", "yue": "Моя луна.",
		"nova": "Мой кристалл!"},
	"idle": {"mc": "Поверни куб — там есть пара.", "rin": "Загляни на обратную сторону.",
		"hana": "Крутани ещё разок!", "yue": "Ответ на другой грани.", "nova": "Подсказка: смени угол."},
	"win": {"mc": "Моя шпилька! Спасибо.", "rin": "Чашка цела. Благодарю.", "hana": "Палочка снова у меня!",
		"yue": "Зеркало вернулось ко мне.", "nova": "Ключ у меня. Доступ открыт."},
	# the relic in the core belongs to another heroine (her partner plays another chapter)
	"win_gift": {"mc": "Нашлась! Сберегу для неё.", "rin": "Нашлась. Вернём хозяйке.", "hana": "Достали! Сама передам!",
		"yue": "Нашлась. Я сберегу её.", "nova": "Находка извлечена. Сохраню."},
}

var hero: = "mc"
var accent: = Color("ff8fb8")
var glow_col: = Color.WHITE
var input_on: = true
var fx: = "full"
var band: = Rect2(0, 0, 720, 120)
var win_rect: = Rect2()
var line_rect: = Rect2()
var sacred_rects: Array = []
var charge: = 0.0
var ready_ult: = false
var events: Array = []
var lines_said: Array = []
var _win: Control           # arch mask (clip children) with the portrait inside
var _por: TextureRect
var _ring: Control
var _line: Label
var _line_tw: Tween
var _frame: = "rest"
var _hold_until: = 0.0
var _tex: = {}
var _tilt: = 0.0
var _tilt_target: = 0.0
var _last_line_t: = -100.0
var _said_at: = {}
var _motes: Array = []
var _finale: = false
var _fin_tw: Tween
var _mote_over_s: = 0.0     # audit: longest time a mote stayed over the sacred zone


func attach(parent: Control, hero_id: String, opts: = {}) -> V10MjCubePresence:
	hero = hero_id
	var a: Array = V10MjCubeStyle.accent(hero)
	accent = a[0]
	glow_col = a[1]
	fx = String(opts.get("fx", G.fx_level() if G.has_method("fx_level") else "full"))
	name = "V10MjCubePresence"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(self)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_win = _Arch.new()
	_win.name = "Window"
	_win.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	(_win as _Arch).col = Color(V10MjCubeStyle.accent(hero)[2]).lerp(V10MjCubeStyle.TOK.night800, 0.35)
	_win.mouse_filter = Control.MOUSE_FILTER_STOP
	_win.gui_input.connect(_on_win_input)
	add_child(_win)
	_por = TextureRect.new()
	_por.name = "Portrait"
	_por.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_por.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_por.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_win.add_child(_por)
	_ring = _Ring.new()
	_ring.name = "Ring"
	(_ring as _Ring).owner_p = self
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ring)
	_line = V10MjCubeStyle.label("", 26, V10MjCubeStyle.TOK.paper100, "italic", 600)
	V10MjCubeStyle.shadow(_line, 0.8)
	_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.modulate.a = 0.0
	add_child(_line)
	_show("rest")
	return self


func layout(band_r: Rect2, win_r: Rect2, line_r: Rect2) -> void:
	band = band_r
	win_rect = win_r
	line_rect = line_r
	if not _finale:
		_win.position = win_r.position
		_win.size = win_r.size
		_fit_portrait()
	_ring.position = win_r.position - Vector2(8, 8)
	_ring.size = win_r.size + Vector2(16, 12)
	_line.position = line_r.position
	_line.size = line_r.size
	_ring.queue_redraw()


func _fit_portrait() -> void:
	# waist-up frame: the face sits in the upper third of the arch
	var w: = _win.size.x * 1.7
	var h: = w * 800.0 / 595.0
	_por.size = Vector2(w, h)
	_por.position = Vector2((_win.size.x - w) * 0.5, -h * 0.03)
	_por.pivot_offset = Vector2(w * 0.5, h * 0.42)


func sacred(rect: Rect2) -> void:
	sacred_rects.append(rect.grow(PAD))


func window_center() -> Vector2:
	return _win.get_global_rect().get_center()


func _tex_of(slot: String) -> Texture2D:
	var emo: String = FRAME_OF.get(slot, "shy")
	if not _tex.has(emo):
		var p: = EMO % [hero, emo]
		_tex[emo] = load(p) if ResourceLoader.exists(p) else null
	return _tex[emo]


func _show(slot: String) -> void:
	_frame = slot
	var t: = _tex_of(slot)
	if t:
		_por.texture = t


func _hold(slot: String, sec: float) -> void:
	_show(slot)
	_hold_until = Time.get_ticks_msec() / 1000.0 + sec


func set_charge(v: float, rdy: bool) -> void:
	charge = clampf(v, 0.0, 1.0)
	ready_ult = rdy
	_ring.queue_redraw()


# her head follows the cube: deg in −4…4 (sign = direction of the turn)
func tilt(deg: float) -> void:
	_tilt_target = clampf(deg, -TILT_MAX, TILT_MAX) if fx != "min" else 0.0


func on(event: String, data: = {}) -> Dictionary:
	events.append(event)
	var acts: = []
	match event:
		"start":
			_say("start", acts)
		"pick":
			acts.append("glance")
		"pair":
			_hold("smile", 0.5)
			acts.append("smile")
			if data.has("pos") and fx != "min":
				_motes_burst(data.pos)
				acts.append("motes")
		"combo":
			if int(data.get("n", 0)) >= 5:
				_hold("smile", 0.6)
				_bob()
				_say("combo", acts)
			acts.append("nod")
		"motif":
			_hold("wink", 0.5)
			_say("motif", acts)
		"signature":
			_hold("ah", 0.6)
			_say("signature", acts)
		"last_pair":
			_hold("look", 1.4)
		"idle":
			_hold("look", 1.2)
			_say("idle", acts)
		"ult":
			_hold("ah", 0.6)
			_bob()
		"win":
			input_on = false
			_finale_in()
			_say("win" if String(data.get("relic", hero)) == hero else "win_gift", acts, true)
			acts.append("finale")
		"lose":
			input_on = false
			_hold("lose", 1.2)
	var info: = {"event": event, "acts": acts}
	reacted.emit(event, info)
	return info


func _say(key: String, acts: Array, force: = false) -> void:
	var now: = Time.get_ticks_msec() / 1000.0
	if not force and now - _last_line_t < LINE_GAP:
		return
	var text: String = (LINES.get(key, {}) as Dictionary).get(hero, "")
	if text == "":
		return
	if not force and now - float(_said_at.get(text, -100.0)) < LINE_SAME:
		return
	_last_line_t = now
	_said_at[text] = now
	lines_said.append(text)
	acts.append("line")
	_line.text = text
	if _line_tw and _line_tw.is_valid():
		_line_tw.kill()
	_line_tw = _line.create_tween()
	if fx == "min":
		_line.modulate.a = 1.0
		_line_tw.tween_interval(4.0)
	else:
		_line.modulate.a = 0.0
		_line.visible_ratio = 0.0
		_line_tw.tween_property(_line, "modulate:a", 1.0, 0.15)
		_line_tw.parallel().tween_property(_line, "visible_ratio", 1.0, 0.4)
		_line_tw.tween_interval(4.0)
	_line_tw.tween_property(_line, "modulate:a", 0.0, 0.3)


func _bob() -> void:
	if fx == "min":
		return
	var tw: = _win.create_tween()
	var y0: = win_rect.position.y
	tw.tween_property(_win, "position:y", y0 - 4.0, 0.1).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_win, "position:y", y0, 0.14).set_trans(Tween.TRANS_SINE)


# ≤ 8 motes of her colour, alpha ≤ 0.6, ≤ 0.45 s to her window along the short way up, never stopping
func _motes_burst(from: Vector2) -> void:
	var to: = window_center()
	var n: = 8 if fx == "full" else 4
	for k in n:
		var s: = Sprite2D.new()
		s.texture = G.fx("glow")
		s.material = Fx.add_mat()
		s.modulate = Color(glow_col if k % 2 == 0 else accent, 0.6)
		s.scale = Vector2.ONE * randf_range(0.10, 0.17)
		s.position = from + Vector2(randf_range(-24, 24), randf_range(-12, 12))
		add_child(s)
		var p0: = s.position
		var mid: = p0.lerp(to, 0.5) + Vector2(randf_range(-50, 50), -36)
		var dur: = randf_range(0.32, 0.44)
		var born: = Time.get_ticks_msec() / 1000.0
		_motes.append([s, born])
		var tw: = s.create_tween()
		tw.tween_method(func(v: float):
			var u: = 1.0 - v
			s.position = p0 * u * u + mid * 2.0 * u * v + to * v * v
			s.modulate.a = 0.6 * (1.0 - v * 0.5), 0.0, 1.0, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(s.queue_free)


func _process(dt: float) -> void:
	_tilt = lerpf(_tilt, _tilt_target, 1.0 - exp(-dt * 6.0))
	_tilt_target = lerpf(_tilt_target, 0.0, 1.0 - exp(-dt * 1.5))
	_por.rotation = deg_to_rad(_tilt)
	if _hold_until > 0.0 and Time.get_ticks_msec() / 1000.0 > _hold_until and not _finale:
		_hold_until = 0.0
		_show("rest")
	# audit the motes over the sacred zone (they may cross it for ≤ 0.45 s)
	var now: = Time.get_ticks_msec() / 1000.0
	var keep: = []
	for m in _motes:
		if not is_instance_valid(m[0]):
			continue
		keep.append(m)
		for r in sacred_rects:
			if (r as Rect2).has_point((m[0] as Sprite2D).position):
				_mote_over_s = maxf(_mote_over_s, now - float(m[1]))
	_motes = keep
	if ready_ult and fx != "min":
		_ring.queue_redraw()


func _on_win_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		if _finale:
			_finish()
		else:
			portrait_tapped.emit()
		accept_event()


# ── finale ───────────────────────────────────────────────────────────────────

func finale_rect(field: Rect2) -> Rect2:
	var w: = minf(field.size.x * 0.62, 460.0)
	var h: = minf(field.size.y * 0.92, w * 1.45)
	return Rect2(field.get_center().x - w * 0.5, field.end.y - h, w, h)


var finale_field: = Rect2()


func _finale_in() -> void:
	_finale = true
	_show("win")
	_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var r: = finale_rect(finale_field) if finale_field.size.x > 0.0 else Rect2(win_rect.position - Vector2(200, 0), win_rect.size * 2.5)
	_line.position = Vector2(r.position.x - 120, r.position.y - 64)
	_line.size = Vector2(r.size.x + 240, 56)
	if fx == "min":
		_win.position = r.position
		_win.size = r.size
		_fit_portrait()
	else:
		_fin_tw = _win.create_tween().set_parallel()
		_fin_tw.tween_property(_win, "position", r.position, 0.45).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN_OUT)
		_fin_tw.tween_property(_win, "size", r.size, 0.45).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN_OUT)
		_fin_tw.tween_method(func(_v): _fit_portrait(), 0.0, 1.0, 0.45)
	_ring.visible = false
	get_tree().create_timer(2.6).timeout.connect(_finish)


func _finish() -> void:
	if not _finale:
		return
	_finale = false
	finale_done.emit()


func hide_finale() -> void:
	_finale = false
	var tw: = _win.create_tween().set_parallel()
	tw.tween_property(_win, "modulate:a", 0.0, 0.25)
	tw.tween_property(_line, "modulate:a", 0.0, 0.2)


# ── audit ────────────────────────────────────────────────────────────────────

# own visible pixels over the sacred zone while input is on (motes are audited by time: mote_over_s ≤ 0.45)
func sacred_hits() -> int:
	if not input_on:
		return 0
	var n: = 0
	var rects: = [_win.get_global_rect(), _ring.get_global_rect()]
	if _line.modulate.a > 0.01 and _line.text != "":
		rects.append(_text_rect())
	for r in rects:
		for s in sacred_rects:
			if (r as Rect2).intersects(s):
				n += 1
	return n


func _text_rect() -> Rect2:
	var f: = _line.label_settings.font
	var w: = f.get_string_size(_line.text, HORIZONTAL_ALIGNMENT_LEFT, -1, _line.label_settings.font_size).x
	w = minf(w, _line.size.x)
	var x: = _line.position.x + (_line.size.x - w if _line.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT else 0.0)
	return Rect2(Vector2(x, _line.position.y), Vector2(w, _line.size.y))


func mote_over_s() -> float:
	return _mote_over_s


# ── drawing helpers ──────────────────────────────────────────────────────────

class _Arch:
	extends Control
	var col: = Color(0.1, 0.08, 0.1)

	func _draw() -> void:
		draw_colored_polygon(V10MjCubePresence.arch_points(size), col)


class _Ring:
	extends Control
	var owner_p: V10MjCubePresence

	func _draw() -> void:
		if owner_p == null:
			return
		var inner: = Rect2(Vector2(8, 8), owner_p.win_rect.size)
		var pts: = V10MjCubePresence.arch_points(inner.size, 28)
		for k in pts.size():
			pts[k] += inner.position
		# arch outline: thin gold hairline
		var open: = PackedVector2Array()
		for k in range(1, pts.size() - 1):
			open.append(pts[k] + (pts[k] - (inner.position + inner.size * Vector2(0.5, 0.62))).normalized() * 5.0)
		draw_polyline(open, Color(V10MjCubeStyle.TOK.gold700, 0.5), 1.5, true)
		var n: = int(round(open.size() * owner_p.charge))
		if n >= 2:
			var c: = owner_p.accent
			if owner_p.ready_ult:
				var p: = 0.75 + 0.25 * sin(Time.get_ticks_msec() / 1000.0 * 4.0)
				c = owner_p.accent.lerp(owner_p.glow_col, p * 0.5)
			draw_polyline(open.slice(0, n), c, 4.0, true)


# arch: straight sides, semicircular top
static func arch_points(sz: Vector2, steps: = 24) -> PackedVector2Array:
	var r: = sz.x * 0.5
	var pts: = PackedVector2Array()
	pts.append(Vector2(0, sz.y))
	for k in steps + 1:
		var a: = PI + PI * k / steps
		pts.append(Vector2(r + cos(a) * r, r + sin(a) * r))
	pts.append(Vector2(sz.x, sz.y))
	return pts
