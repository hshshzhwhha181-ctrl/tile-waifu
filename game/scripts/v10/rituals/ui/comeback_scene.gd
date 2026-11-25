class_name V10ComebackScene
extends Control

# «Она ждала» scenes (Р5). Tap anywhere skips from the very first second. No buttons with prices, no offers.
#   warm   4 s  «Чай ещё тёплый»: the partner steps in from the door, «О, ты как раз к заварке!», chip «Отдых ×2»
#   waited 8 s  «Она ждала»: dark room, the lamp comes on, she turns from the window, a fan of letters flies into
#               the Phone badge (top right)
#   winds 12 s  «Пять ветров снова дуют»: stop-frames of the player's heroines carried by wind, then ≤3 «Что нового»
#   V10ComebackScene.play(parent, tier, {h, heroes:[…], news:[{title, text, icon}], letters:n}) -> scene
#   signal finished(skipped: bool)

signal finished(skipped: bool)

var tier: = "warm"
var opts: = {}
var _done: = false
var _t0: = 0.0
var _stage: Control
var _phone_badge: Label
var _badge_n: = 0
var _secs: = 4.0


static func play(parent: Control, tier_in: String, opts_in: = {}) -> V10ComebackScene:
	var s: = V10ComebackScene.new()
	s.tier = tier_in
	s.opts = opts_in
	s.size = parent.size
	parent.add_child(s)
	return s


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_secs = float(V10Comeback.SCENE_SECS.get(tier, 4.0))
	add_child(V10RitUI.panel(Rect2(Vector2.ZERO, size), V10RitUI.NIGHT900, 0))
	_stage = Control.new()
	_stage.size = size
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)
	match tier:
		"warm":
			_warm()
		"waited":
			_waited()
		_:
			_winds()
	var skip: = V10RitUI.label("Коснись, чтобы продолжить", 18, Color(V10RitUI.PAPER500, 0.8))
	skip.position = Vector2(0, size.y - 64)
	skip.size = Vector2(size.x, 30)
	skip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(skip)
	skip.modulate.a = 0.0
	skip.create_tween().tween_property(skip, "modulate:a", 1.0, 0.6).set_delay(1.2)
	var t: = create_tween()
	t.tween_interval(_secs)
	t.tween_callback(func(): _finish(false))


func _h() -> String:
	return str(opts.get("h", V10RitBridge.partner()))


func _gui_input(e: InputEvent) -> void:
	if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
		accept_event()
		_finish(true)


func _finish(skipped: bool) -> void:
	if _done:
		return
	_done = true
	if skipped:
		V9Feel.press(null, "pop", "button")
	var t: = create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.25 if skipped else 0.5)
	t.tween_callback(func():
		finished.emit(skipped)
		queue_free())


func _bg(path: String, dim: = 0.55) -> TextureRect:
	var bg: = TextureRect.new()
	bg.texture = load(path) if ResourceLoader.exists(path) else null
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.size = size * 1.06
	bg.position = -size * 0.03
	bg.modulate = Color(dim, dim, dim)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(bg)
	if V9Feel.can_fx():
		bg.create_tween().tween_property(bg, "position", bg.position + Vector2(-14, -6), _secs).set_trans(Tween.TRANS_SINE)
	return bg


func _portrait(h: String, height: float, x_center: float) -> TextureRect:
	var tx: = V10RitBridge.portrait(h)
	var p: = TextureRect.new()
	p.texture = tx
	p.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	p.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	var w: = height * (848.0 / 1264.0)
	p.size = Vector2(w, height)
	p.pivot_offset = Vector2(w * 0.5, height)
	p.position = Vector2(x_center - w * 0.5, size.y - height - 120)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(p)
	return p


func _breathe(p: Control) -> void:
	if not V9Feel.can_fx():
		return
	var t: = p.create_tween().set_loops()
	t.tween_property(p, "scale", Vector2(1.0, 1.008), 2.0).set_trans(Tween.TRANS_SINE)
	t.tween_property(p, "scale", Vector2.ONE, 2.0).set_trans(Tween.TRANS_SINE)


func _title(text: String, at_y: float, delay: float) -> void:
	var over: = V10RitUI.label(text, 15, V10RitUI.GOLD500, "over")
	over.position = Vector2(40, at_y)
	_stage.add_child(over)
	V10RitUI.inhale([over], delay)


# ── 3–6 days ───────────────────────────────────────────────────────────────────────────────────────────────────

func _warm() -> void:
	_bg("res://assets/bg/bg_teahouse.webp", 0.5)
	var p: = _portrait(_h(), 980, size.x * 0.7)
	var end_x: = p.position.x
	p.position.x = size.x + 40
	p.modulate.a = 0.0
	var t: = p.create_tween()
	t.tween_property(p, "position:x", end_x, 0.7 if V9Feel.can_fx() else 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(p, "modulate:a", 1.0, 0.35)
	t.tween_callback(func(): _breathe(p))
	_stage.add_child(V10RitUI.grad(Rect2(0, size.y * 0.55, size.x, size.y * 0.45), Color(V10RitUI.NIGHT900, 0), Color(V10RitUI.NIGHT900, 0.92)))
	# a tea bowl in the foreground, steaming
	var bowl: = V10RitUI.tex(V10RitUI.ART + "bowl.webp", Rect2(48, size.y - 360, 150, 140))
	_stage.add_child(bowl)
	V10RitUI.steam(_stage, Vector2(123, size.y - 340), 70, 16, Color(1, 0.97, 0.92, 0.5))
	_title(V10Comeback.TIER_TITLE.warm, 120, 0.3)
	var line: = V10RitLines.pick("comeback_warm", _h(), 0)
	var tw: = create_tween()
	tw.tween_interval(0.9)
	tw.tween_callback(func():
		V10RitUI.voice(_stage, line, Vector2(36, 170), 330, 40, 0.0)
		V10RitUI.sfx("tea_pour", "sparkle", 1.0, -6.0))
	tw.tween_interval(1.0)
	tw.tween_callback(func(): _rested_chip(Vector2(232, size.y - 316)))


func _rested_chip(at: Vector2) -> void:
	var c: = Control.new()
	c.position = at
	c.size = Vector2(250, 60)
	c.pivot_offset = Vector2(0, 30)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(V10RitUI.panel(Rect2(Vector2.ZERO, c.size), Color(V10RitUI.TEAL, 0.16), 30, V10RitUI.TEAL, 2))
	var l: = V10RitUI.label("Отдых ×2", 24, V10RitUI.TEAL, "num")
	l.position = Vector2(22, 0)
	l.size = Vector2(c.size.x - 22, 60)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	c.add_child(l)
	var sub: = V10RitUI.label("удваивает мастерство нарядов", 18, V10RitUI.PAPER300)
	sub.position = Vector2(0, 64)
	c.add_child(sub)
	_stage.add_child(c)
	c.scale = Vector2.ONE * 0.4
	c.modulate.a = 0.0
	var t: = c.create_tween()
	t.tween_property(c, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(c, "modulate:a", 1.0, 0.2)
	V10RitUI.sfx("bell", "sparkle", 1.2, -8.0)


# ── 7–29 days ──────────────────────────────────────────────────────────────────────────────────────────────────

func _waited() -> void:
	var bg: = _bg("res://assets/bg/bg_teahouse.webp", 0.0)
	var glow: = TextureRect.new()
	glow.texture = V10RitUI.soft_dot()
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.size = Vector2(900, 900)
	glow.position = Vector2(size.x * 0.12 - 450, 160 - 450)
	glow.modulate = Color(V10RitUI.GOLD500, 0.0)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(glow)
	var p: = _portrait(_h(), 1000, size.x * 0.7)
	p.modulate = Color(0.0, 0.0, 0.02, 0.0)
	p.scale = Vector2(-1, 1)           # back to us: facing the window
	_stage.add_child(V10RitUI.grad(Rect2(0, size.y * 0.6, size.x, size.y * 0.4), Color(V10RitUI.NIGHT900, 0), Color(V10RitUI.NIGHT900, 0.94)))
	_phone(Vector2(size.x - 104, 40))
	var fx: = V9Feel.can_fx()
	var t: = create_tween()
	# 0.6 s: the lamp is lit
	t.tween_interval(0.6)
	t.tween_callback(func(): V10RitUI.sfx("bell", "sparkle", 0.8, -8.0))
	t.tween_property(glow, "modulate:a", 0.55, 0.9 if fx else 0.12)
	t.parallel().tween_property(bg, "modulate", Color(0.55, 0.5, 0.48), 1.2 if fx else 0.12)
	t.parallel().tween_property(p, "modulate", Color(0.25, 0.22, 0.24, 1.0), 1.0)
	_title(V10Comeback.TIER_TITLE.waited, 120, 1.0)
	# 2.2 s: she turns from the window (squash turn) into the light
	t.tween_interval(0.6)
	t.tween_property(p, "scale", Vector2(0.02, 1.01), 0.22 if fx else 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(func(): V10RitUI.sfx("paper_fan", "whoosh", 1.4, -14.0))
	t.tween_property(p, "scale", Vector2(1.0, 1.0), 0.34 if fx else 0.05).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(p, "modulate", Color.WHITE, 0.5)
	t.tween_callback(func():
		_breathe(p)
		V10RitUI.voice(_stage, V10RitLines.pick("comeback_waited", _h(), 0), Vector2(36, 170), 330, 40, 0.0))
	# 4.5 s: the stack of letters fans out and flies into the Phone badge
	t.tween_interval(1.2)
	t.tween_callback(func(): _letters(int(opts.get("letters", 5)), Vector2(size.x * 0.42, size.y * 0.62)))


func _phone(at: Vector2) -> void:
	var ph: = V10RitUI.panel(Rect2(at, Vector2(64, 64)), V10RitUI.NIGHT700, 4, Color(V10RitUI.PAPER500, 0.5), 2)
	ph.name = "phone"
	_stage.add_child(ph)
	var ic: = V10RitUI.tex("res://assets/icons/mail.png", Rect2(10, 10, 44, 44))
	ph.add_child(ic)
	var dot: = V10RitUI.panel(Rect2(40, -10, 34, 34), V10RitUI.ROSE500, 17)
	ph.add_child(dot)
	_phone_badge = V10RitUI.label("0", 18, V10RitUI.NIGHT900, "num")
	_phone_badge.size = Vector2(34, 34)
	_phone_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_phone_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dot.add_child(_phone_badge)
	dot.visible = false


func _letters(n: int, from: Vector2) -> void:
	n = clampi(n, 1, 7)
	var ph: Control = _stage.get_node_or_null("phone")
	var to: = ph.position + Vector2(32, 32) if ph else Vector2(size.x - 72, 72)
	V10RitUI.sfx("paper_fan", "whoosh", 1.0, -4.0)
	for i in n:
		var env: = V10RitUI.tex(V10RitUI.ART + "envelope.webp", Rect2(from - Vector2(60, 46), Vector2(120, 92)))
		env.rotation = deg_to_rad(-6)
		_stage.add_child(env)
		var ang: = deg_to_rad(-60 + 120.0 * i / maxf(1, n - 1))
		var fan: = from + Vector2(sin(ang), -cos(ang)) * 150 - Vector2(60, 46)
		var t: = env.create_tween()
		t.tween_interval(0.05 * i)
		t.tween_property(env, "position", fan, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(env, "rotation", ang * 0.5, 0.35)
		t.tween_interval(0.35 + 0.12 * i)
		t.tween_property(env, "position", to - Vector2(60, 46), 0.42).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
		t.parallel().tween_property(env, "scale", Vector2.ONE * 0.25, 0.42)
		t.parallel().tween_property(env, "rotation", 0.0, 0.42)
		t.tween_callback(func():
			env.queue_free()
			_badge_n += 1
			if _phone_badge:
				_phone_badge.get_parent().visible = true
				_phone_badge.text = str(_badge_n)
				V9Feel.success(_phone_badge.get_parent(), "", 0.4)
			V10RitUI.note(i, "pop", -8.0))


# ── 30+ days ───────────────────────────────────────────────────────────────────────────────────────────────────

func _winds() -> void:
	_bg("res://assets/bg/bg_festival_blur.webp", 0.42)
	var hs: Array = opts.get("heroes", V10RitBridge.heroes())
	hs = hs.slice(0, 5)
	var fx: = V9Feel.can_fx()
	var wind: = CPUParticles2D.new()
	wind.texture = V10RitUI.petal_tex()
	wind.position = Vector2(-40, size.y * 0.5)
	wind.amount = maxi(8, int(40 * V9Feel.fx_scale()))
	wind.lifetime = 3.0
	wind.preprocess = 2.0
	wind.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	wind.emission_rect_extents = Vector2(10, size.y * 0.5)
	wind.direction = Vector2(1, -0.15)
	wind.spread = 18
	wind.gravity = Vector2(0, 20)
	wind.initial_velocity_min = 260
	wind.initial_velocity_max = 420
	wind.angular_velocity_min = -200
	wind.angular_velocity_max = 200
	wind.scale_amount_min = 0.4
	wind.scale_amount_max = 0.9
	wind.color = Color(V10RitUI.ROSE300, 0.85)
	wind.emitting = fx
	_stage.add_child(wind)
	var step: = 1.5
	var frames: = []
	for i in hs.size():
		var p: = _portrait(str(hs[i]), 900, size.x * (0.4 if i % 2 == 0 else 0.6))
		p.modulate.a = 0.0
		frames.append(p)
		var from_x: = -p.size.x if i % 2 == 0 else size.x
		var rest: = p.position.x
		p.position.x = from_x
		var t: = p.create_tween()
		t.tween_interval(0.3 + i * step)
		t.tween_callback(func(): V10RitUI.sfx("paper_fan", "whoosh", 0.8 + 0.1 * i, -10.0))
		t.tween_property(p, "position:x", rest, 0.5 if fx else 0.1).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(p, "modulate:a", 1.0, 0.3)
		t.tween_interval(step - 0.5)
		if i < hs.size() - 1:
			t.tween_property(p, "modulate:a", 0.0, 0.4)
		else:
			t.tween_property(p, "modulate:a", 0.3, 0.6)
	var after: = 0.3 + hs.size() * step
	var t2: = create_tween()
	t2.tween_interval(after - 0.6)
	t2.tween_callback(func():
		_stage.add_child(V10RitUI.grad(Rect2(0, 0, size.x, size.y), Color(V10RitUI.NIGHT900, 0.2), Color(V10RitUI.NIGHT900, 0.9)))
		var title: = V10RitUI.wrap_w(V10RitUI.label(V10Comeback.TIER_TITLE.winds, 52, V10RitUI.PAPER100, "title", 700), size.x - 80)
		title.position = Vector2(40, 140)
		_stage.add_child(title)
		var line: = V10RitUI.voice(_stage, V10RitLines.pick("comeback_winds", _h(), 0), Vector2(40, 290), size.x - 80, 34, 0.0)
		V10RitUI.inhale([title])
		_news(Array(opts.get("news", [])).slice(0, 3)))


func _news(news: Array) -> void:
	var y: = size.y - 160 - news.size() * 132
	var nodes: = []
	for i in news.size():
		var n: Dictionary = news[i]
		var card: = V10RitUI.panel(Rect2(40, y + i * 132, size.x - 80, 116), Color(V10RitUI.NIGHT700, 0.92), 4, Color(V10RitUI.GOLD700, 0.35), 1)
		_stage.add_child(card)
		var ic: = V10RitUI.tex(str(n.get("icon", "")), Rect2(16, 14, 88, 88))
		card.add_child(ic)
		var tl: = V10RitUI.label(str(n.get("title", "")), 26, V10RitUI.PAPER100, "body", 800)
		tl.position = Vector2(120, 16)
		card.add_child(tl)
		var tx: = V10RitUI.wrap_w(V10RitUI.label(str(n.get("text", "")), 18, V10RitUI.PAPER500, "body", 700), size.x - 80 - 140)
		tx.position = Vector2(120, 54)
		card.add_child(tx)
		nodes.append(card)
	var over: = V10RitUI.label("Что нового", 15, V10RitUI.GOLD500, "over")
	over.position = Vector2(40, y - 32)
	_stage.add_child(over)
	nodes.push_front(over)
	V10RitUI.inhale(nodes, 0.4)
