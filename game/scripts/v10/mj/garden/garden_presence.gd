class_name V10MjGardenPresence
extends Control

# Героиня в Саду — встроенная лёгкая заглушка контракта presence (docs/MODES.md §3, §4.9, §7.1): on(event, data) и
# sacred(rect). Если экрану передали args.presence (режиссёр V10MjPresence дорожки stage), работает он, а этот узел
# скрыт и остаётся только источником аудита (самотест).
#
# В Саду она почти ничего не делает — это медитация (MODES §4.9):
#   • окно-арка в её полосе: спокойный поясной кадр, тонкая линия gold700 35 %; без реакций на тапы и пары;
#   • wave — главный легальный выход: она выглядывает по пояс из-за нижней кромки полосы (клип = полоса, на стол
#     не заходит ни пикселем) и высыпает из рукава горсть маленьких фишек, которые «уходят» за кромку к столу;
#     0,25 с выход · 0,6 с держит · 0,3 с уходит (≤ 1,2 с); ввод экрана закрыт ≤ 0,3 с (сигнал wants_block),
#     ранние тапы стоят в очереди доски; окно на это время притихает (она «вышла» из него);
#   • рекорд недели — силуэт за полупрозрачным столом 1 с (рисует V10MjGardenSilhouette под сукном, поверх фишек
#     ничего нет);
#   • всё остальное (pick, pair, combo, danger…) только пишется в журнал events.
# Настройка «Героиня в партии» (MODES §3.5): live — как выше; quiet и finish_only — только окно, без выходов.
# fx_level = min: выход — проявление за 120 мс без движения, без фишек из рукава.

signal wants_block(seconds: float)

const PEEK_IN: = 0.25
const PEEK_HOLD: = 0.6
const PEEK_OUT: = 0.3
const BLOCK: = 0.3
const EMO_DIR: = "res://assets/v08/emotions/"
const TOK: = V10MjGardenLook.TOK

var hero: = "yue"
var mode: = "live"
var fx_min: = false
var input_on: = true
var sacred_rects: Array[Rect2] = []
var band_rect: = Rect2()
var win_rect: = Rect2()
var peek_clip_rect: = Rect2()
var events: Array = []
var peeks: = 0
var peek_active: = false
var yield_nodes: Array = []

var _win: Control
var _art: TextureRect
var _clip: Control
var _fig: TextureRect
var _motes: Array[Sprite2D] = []
var _tw: Tween


func attach(screen: Control, h: String, opts: = {}) -> V10MjGardenPresence:
	hero = h
	mode = String(opts.get("mode", _setting_mode()))
	fx_min = bool(opts.get("fx_min", false))
	name = "GardenPresence"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.add_child(self)
	_build()
	return self


static func _setting_mode() -> String:
	var g = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("G")
	if g and g.S is Dictionary:
		var st = g.S.get("v10_mj_stage", {})
		if st is Dictionary:
			return String(st.get("mode", "live"))
	return "live"


static func frame_path(h: String, kind: String) -> String:
	var p: = EMO_DIR + "%s_%s.webp" % [h, kind]
	if ResourceLoader.exists(p):
		return p
	return EMO_DIR + "yue_%s.webp" % kind


func sacred(r: Rect2) -> void:
	sacred_rects.append(r.grow(8.0))


func _build() -> void:
	_win = Control.new()
	_win.name = "PortraitWindow"
	_win.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_win.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	_win.draw.connect(_draw_window)
	add_child(_win)
	_art = TextureRect.new()
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_SCALE
	_win.add_child(_art)
	var ring: = Control.new()
	ring.name = "Ring"
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.draw.connect(func():
		var r: = Rect2(Vector2(6, 6), win_rect.size)
		ring.draw_polyline(V10MjGardenLook.arch_points(r, 40, false), Color(TOK.gold700, 0.35), 1.0, true))
	add_child(ring)
	_clip = Control.new()
	_clip.name = "PeekClip"
	_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clip.clip_contents = true
	_clip.visible = false
	add_child(_clip)
	_fig = TextureRect.new()
	_fig.name = "PeekFigure"
	_fig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fig.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_fig.stretch_mode = TextureRect.STRETCH_SCALE
	_clip.add_child(_fig)


# полоса героини, окно-арка, зона выхода (экран считает их по высоте экрана)
func layout(band: Rect2, window: Rect2, peek_x0: float) -> void:
	band_rect = band
	win_rect = window
	_win.position = window.position
	_win.size = window.size
	var ring: Control = get_node("Ring")
	ring.position = window.position - Vector2(6, 6)
	ring.size = window.size + Vector2(12, 12)
	ring.queue_redraw()
	_win.queue_redraw()
	var tex: Texture2D = load(frame_path(hero, "shy"))
	if tex:
		var ts: = Vector2(tex.get_width(), tex.get_height())
		# лицо и плечи: верхние ~58 % кадра, по ширине окна
		var wa: = window.size.x / window.size.y
		var rh: = ts.y * 0.58
		var rw: = rh * wa
		if rw > ts.x:
			rw = ts.x
			rh = rw / wa
		var at: = AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2((ts.x - rw) * 0.5, ts.y * 0.02, rw, rh)
		_art.texture = at
		_art.size = window.size
	# зона выхода: полоса от правого края её HUD до окна, по всей высоте полосы (клип — сама зона)
	var x1: = window.position.x - 10.0
	peek_clip_rect = Rect2(peek_x0, band.position.y, maxf(0.0, x1 - peek_x0), band.size.y)
	_clip.position = peek_clip_rect.position
	_clip.size = peek_clip_rect.size


func _draw_window() -> void:
	var s: = _win.size
	_win.draw_colored_polygon(V10MjGardenLook.arch_points(Rect2(Vector2.ZERO, s), 28), V10MjGardenLook.accent(hero)[2].darkened(0.25))


func window_center() -> Vector2:
	return win_rect.get_center()


# ── события ──────────────────────────────────────────────────────────────────

func on(event: String, data: = {}) -> void:
	events.append(event)
	match event:
		"wave":
			if mode == "live":
				_peek()


func _peek() -> void:
	if peek_clip_rect.size.x < 80.0 or peek_clip_rect.size.y < 64.0:
		return
	wants_block.emit(BLOCK)
	peeks += 1
	peek_active = true
	var tex: Texture2D = load(frame_path(hero, "happy"))
	_fig.texture = tex
	var ts: = Vector2(tex.get_width(), tex.get_height()) if tex else Vector2(600, 765)
	var fh: = clampf(peek_clip_rect.size.y * 1.08, 90.0, 470.0)
	# в узкой зоне (высокий экран, широкое окно) — не шире 92 % зоны: её не режут боковые края клипа
	fh = minf(fh, peek_clip_rect.size.x * 0.92 * ts.y / ts.x)
	var fw: = fh * ts.x / ts.y
	_fig.size = Vector2(fw, fh)
	# она стоит у окна (ближе к правому краю зоны), пояс — на нижней кромке полосы
	var x: = clampf(peek_clip_rect.size.x - fw * 1.05, 0.0, maxf(0.0, peek_clip_rect.size.x - fw))
	var shown: = Vector2(x, peek_clip_rect.size.y - fh * 0.9)
	var hidden: = Vector2(x, peek_clip_rect.size.y + 4.0)
	_clip.visible = true
	for y in yield_nodes:
		if is_instance_valid(y):
			(y as CanvasItem).create_tween().tween_property(y, "modulate:a", 0.0, 0.15)
	if _tw and _tw.is_valid():
		_tw.kill()
	_win.modulate.a = 1.0
	_tw = create_tween()
	if fx_min:
		_fig.position = shown
		_fig.modulate.a = 0.0
		_tw.tween_property(_fig, "modulate:a", 1.0, 0.12)
		_tw.tween_interval(0.8)
		_tw.tween_property(_fig, "modulate:a", 0.0, 0.12)
	else:
		_fig.modulate.a = 1.0
		_fig.position = hidden
		_tw.tween_property(_fig, "position", shown, PEEK_IN).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		_tw.parallel().tween_property(_win, "modulate:a", 0.35, PEEK_IN)
		_tw.tween_callback(_sleeve.bind(Vector2(x + fw * 0.16, shown.y + fh * 0.78)))
		_tw.tween_interval(PEEK_HOLD)
		_tw.tween_property(_fig, "position", hidden, PEEK_OUT).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_tw.parallel().tween_property(_win, "modulate:a", 1.0, PEEK_OUT)
	_tw.tween_callback(func():
		_clip.visible = false
		peek_active = false
		for y in yield_nodes:
			if is_instance_valid(y):
				(y as CanvasItem).create_tween().tween_property(y, "modulate:a", 1.0, 0.2))


# горсть маленьких фишек из рукава: дугой вниз, за нижнюю кромку полосы (к столу); всё внутри клипа
func _sleeve(from: Vector2) -> void:
	var n: = 6
	for k in n:
		var s: = Sprite2D.new()
		var f: = (k * 7 + 3) % 36
		s.texture = G.tile_tex(f)
		var sc: = clampf(peek_clip_rect.size.y / 120.0, 0.8, 1.6) * 0.13
		s.scale = Vector2(sc, sc)
		s.position = from
		s.rotation = randf_range(-0.6, 0.6)
		_clip.add_child(s)
		_motes.append(s)
		var to: = Vector2(from.x - 30.0 - k * 22.0 + randf_range(-8, 8), peek_clip_rect.size.y + 30.0)
		var mid: = Vector2(lerpf(from.x, to.x, 0.5), from.y - 26.0 - randf_range(0, 18))
		var dur: = randf_range(0.42, 0.58)
		var p0: = from
		var tw: = s.create_tween()
		tw.tween_interval(k * 0.045)
		tw.tween_method(func(v: float):
			var u: = 1.0 - v
			s.position = p0 * u * u + mid * 2.0 * u * v + to * v * v
			s.rotation += 0.08, 0.0, 1.0, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(func():
			_motes.erase(s)
			s.queue_free())


# всё, что она сейчас рисует (экранные прямоугольники) — для аудита святой зоны
func drawn_rects() -> Array[Rect2]:
	var out: Array[Rect2] = [win_rect.grow(6.0)]
	if _clip.visible:
		var fr: = Rect2(peek_clip_rect.position + _fig.position, _fig.size).intersection(peek_clip_rect)
		if fr.size.x > 0.0 and fr.size.y > 0.0:
			out.append(fr)
		for s in _motes:
			if is_instance_valid(s):
				var p: = peek_clip_rect.position + s.position
				var r: = Rect2(p - Vector2(14, 16), Vector2(28, 32)).intersection(peek_clip_rect)
				if r.size.x > 0.0 and r.size.y > 0.0:
					out.append(r)
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
