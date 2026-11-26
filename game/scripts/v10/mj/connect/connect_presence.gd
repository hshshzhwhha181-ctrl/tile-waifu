class_name V10MjConnectPresence
extends Control

# Встроенное присутствие героини для «Связей» (MODES §3, §4.3, §7.1).
# Поддерживает контракт on(event, data) + sacred(rect), кольцо Приёма и проверку святой зоны sacred_hits().

signal portrait_tapped
signal finale_done

const T: = V10MjConnectLook.TOK
const EMO_DIR: = "res://assets/v08/emotions/"
const VOICE_CD: = 20.0
const SAME_CD: = 60.0

const LINES: = {
	"start": "Смотри шире — нить найдёт пару.",
	"combo": "Какая ровная нить!",
	"motif": "Два узора подряд — красиво.",
	"signature": "Мой знак в раскладе!",
	"shuffle": "Ходов нет — перемешала.",
	"win": "Чистое поле. Красивая работа.",
	"lose": "Почти успели. Попробуем ещё?",
	"idle": "Ищи пару по краю поля.",
}

var hero: = "rin"
var mode: = "live"
var fx_min: = false
var input_on: = true
var sacred_rects: Array[Rect2] = []
var band_rect: = Rect2()
var win_rect: = Rect2()
var charge: = 0.0
var ready_ult: = false
var events: Array = []

var _win_btn: Button
var _art: TextureRect
var _ring: Control
var _bark: Label
var _finale: Control
var _last_voice_t: = -100.0
var _line_at: = {}


func attach(screen: Control, h: String, opts: = {}) -> V10MjConnectPresence:
	hero = h if V10MjConnectLook.ACCENT.has(h) else "rin"
	mode = String(opts.get("mode", _setting_mode()))
	fx_min = bool(opts.get("fx_min", false))
	name = "ConnectPresence"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.add_child(self)
	_build()
	return self


static func _setting_mode() -> String:
	var tree: = Engine.get_main_loop() as SceneTree
	var g = tree.root.get_node_or_null("G") if tree and tree.root else null
	if g and g.get("S") is Dictionary:
		var st = g.S.get("v10_mj_stage", {})
		if st is Dictionary:
			return String(st.get("mode", "live"))
	return "live"


static func frame_path(h: String, emo: String) -> String:
	for k in [h, "rin", "mc"]:
		var p: = EMO_DIR + "%s_%s.webp" % [k, emo]
		if ResourceLoader.exists(p):
			return p
	return ""


func sacred(r: Rect2) -> void:
	sacred_rects.append(r.grow(8.0))


func clear_sacred() -> void:
	sacred_rects.clear()


func _build() -> void:
	_win_btn = Button.new()
	_win_btn.name = "HeroWindow"
	_win_btn.flat = true
	_win_btn.focus_mode = Control.FOCUS_NONE
	_win_btn.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	_win_btn.custom_minimum_size = Vector2(80, 80)
	_win_btn.set_meta("ux_role", "tertiary")
	_win_btn.draw.connect(_draw_win)
	_win_btn.pressed.connect(func(): portrait_tapped.emit())
	add_child(_win_btn)
	_art = TextureRect.new()
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_win_btn.add_child(_art)
	_ring = Control.new()
	_ring.name = "UltRing"
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring.draw.connect(_draw_ring)
	add_child(_ring)
	_bark = V10MjConnectLook.label("", 22, T.paper100, "italic", 600)
	V10MjConnectLook.shadow(_bark, 0.65)
	_bark.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_bark.modulate.a = 0.0
	add_child(_bark)
	_set_emo("neutral")


func layout(band: Rect2, window: Rect2) -> void:
	band_rect = band
	win_rect = window
	_win_btn.position = window.position
	_win_btn.size = Vector2(maxf(80.0, window.size.x), maxf(80.0, window.size.y))
	_win_btn.pivot_offset = _win_btn.size * 0.5
	_art.size = _win_btn.size
	_ring.position = _win_btn.position - Vector2(6, 6)
	_ring.size = _win_btn.size + Vector2(12, 12)
	_bark.position = Vector2(104, maxf(68.0, band.end.y - 38.0))
	_bark.size = Vector2(maxf(120.0, window.position.x - 118.0), 32)
	_win_btn.queue_redraw()
	_ring.queue_redraw()


func _set_emo(emo: String) -> void:
	var p: = frame_path(hero, emo)
	if p == "":
		p = frame_path(hero, "happy")
	if p != "" and ResourceLoader.exists(p):
		_art.texture = load(p)


func _arch(r: Rect2) -> PackedVector2Array:
	var pts: = PackedVector2Array()
	var rad: = r.size.x * 0.5
	var cy: = r.position.y + rad
	pts.append(Vector2(r.position.x, r.end.y))
	pts.append(Vector2(r.position.x, cy))
	for i in range(1, 20):
		var a: = PI + PI * float(i) / 20.0
		pts.append(Vector2(r.position.x + rad + cos(a) * rad, cy + sin(a) * rad))
	pts.append(Vector2(r.end.x, cy))
	pts.append(Vector2(r.end.x, r.end.y))
	return pts


func _draw_win() -> void:
	var pts: = _arch(Rect2(Vector2.ZERO, _win_btn.size))
	var acc: Array = V10MjConnectLook.accent(hero)
	_win_btn.draw_colored_polygon(pts, Color(acc[2]).darkened(0.25))


func _draw_ring() -> void:
	var r: = Rect2(Vector2(6, 6), _win_btn.size)
	var pts: = _arch(r)
	_ring.draw_polyline(pts, Color(T.night600, 0.85), 4.0, true)
	if charge > 0.001:
		var cnt: = maxi(2, int(round(pts.size() * clampf(charge, 0.0, 1.0))))
		var col: Color = V10MjConnectLook.accent(hero)[1 if ready_ult else 0]
		_ring.draw_polyline(pts.slice(0, cnt), col, 4.5 if ready_ult else 3.5, true)


func set_charge(v: float, rdy: bool) -> void:
	charge = clampf(v, 0.0, 1.0)
	ready_ult = rdy
	if _ring:
		_ring.queue_redraw()


func window_center() -> Vector2:
	return _win_btn.get_global_rect().get_center() if _win_btn else win_rect.get_center()


func bounce() -> void:
	if fx_min or _win_btn == null:
		return
	var tw: = _win_btn.create_tween()
	tw.tween_property(_win_btn, "scale", Vector2(1.04, 1.04), 0.09)
	tw.tween_property(_win_btn, "scale", Vector2.ONE, 0.12)


func say(text: String, force: = false) -> void:
	if mode != "live" or _bark == null:
		return
	var now: = Time.get_ticks_msec() / 1000.0
	if not force and now - _last_voice_t < VOICE_CD:
		return
	if now - float(_line_at.get(text, -100.0)) < SAME_CD:
		return
	_last_voice_t = now
	_line_at[text] = now
	_bark.text = text
	_bark.modulate.a = 1.0 if fx_min else 0.0
	if fx_min:
		get_tree().create_timer(2.4).timeout.connect(func():
			if is_instance_valid(_bark):
				_bark.modulate.a = 0.0)
		return
	var tw: = _bark.create_tween()
	tw.tween_property(_bark, "modulate:a", 1.0, 0.25)
	tw.tween_interval(2.6)
	tw.tween_property(_bark, "modulate:a", 0.0, 0.25)


func on(event: String, data: = {}) -> void:
	events.append([event, data])
	if data.has("charge"):
		set_charge(float(data.charge), float(data.charge) >= 0.999)
	match event:
		"start":
			_set_emo("shy")
		"pair":
			if mode != "finish_only":
				_set_emo("happy")
		"combo":
			if mode == "live" and int(data.get("n", 0)) >= 5:
				say(LINES.combo)
		"motif":
			if mode == "live":
				_set_emo("wink")
		"signature":
			if mode == "live":
				say(LINES.signature)
		"idle":
			if mode == "live":
				say(LINES.idle)
		"win":
			_show_finale(true)
		"lose":
			_show_finale(false)


func _show_finale(won: bool) -> void:
	input_on = false
	_set_emo("happy" if won else "shy")
	if fx_min:
		get_tree().create_timer(0.08).timeout.connect(func(): finale_done.emit())
		return
	if _finale and is_instance_valid(_finale):
		_finale.queue_free()
	_finale = Control.new()
	_finale.name = "Finale"
	_finale.set_anchors_preset(Control.PRESET_FULL_RECT)
	_finale.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_finale)
	var acc: Array = V10MjConnectLook.accent(hero)
	var card: = Panel.new()
	var sb: = StyleBoxFlat.new()
	sb.bg_color = Color(T.night800, 0.92)
	sb.border_color = Color(acc[0], 0.65)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	card.add_theme_stylebox_override("panel", sb)
	var vw: = get_viewport_rect().size
	card.size = Vector2(300, 380)
	card.position = Vector2((vw.x - 300) * 0.5, (vw.y - 380) * 0.42)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_finale.add_child(card)
	var tr: = TextureRect.new()
	var fp: = frame_path(hero, "happy" if won else "shy")
	if fp != "":
		tr.texture = load(fp)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tr.position = Vector2(12, 12)
	tr.size = Vector2(276, 316)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(tr)
	var cap: = V10MjConnectLook.label(LINES.win if won else LINES.lose, 18, T.paper100, "body", 700)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.position = Vector2(8, 336)
	cap.size = Vector2(284, 34)
	card.add_child(cap)
	var done_emitted: = [false]
	var finish_cb: = func():
		if done_emitted[0]:
			return
		done_emitted[0] = true
		hide_finale()
		finale_done.emit()
	_finale.gui_input.connect(func(e: InputEvent):
		if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
			finish_cb.call())
	get_tree().create_timer(1.1).timeout.connect(finish_cb)


func hide_finale() -> void:
	if _finale and is_instance_valid(_finale):
		_finale.queue_free()
		_finale = null


func drawn_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	if _win_btn and _win_btn.visible:
		out.append(_win_btn.get_global_rect())
	if _bark and _bark.visible and _bark.modulate.a > 0.02:
		out.append(_bark.get_global_rect())
	return out


func sacred_hits() -> Array:
	if not input_on:
		return []
	var hits: Array = []
	for d in drawn_rects():
		for s in sacred_rects:
			if d.intersects(s):
				hits.append(d.intersection(s))
	return hits
