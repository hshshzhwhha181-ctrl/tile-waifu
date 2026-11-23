class_name V7Combo
extends Control








const TIERS: = [
	[2, "Дуэт", Color("ffd98a")], 
	[3, "Трио", Color("ffc46b")], 
	[4, "Каскад", Color("ff9fbf")], 
	[5, "Цветение", Color("ff6f9f")], 
	[8, "Небесный поток", Color("b99bff")], 
	[12, "Лунная буря", Color("7fe0ff")], 
	[16, "Пять ветров", Color("9fffd0")], 
]

var play
var pill: Control
var pill_lbl: Label
var pill_sub: Label
var col: = Color("ffd98a")
var glow: = 0.0
var glow_target: = 0.0
var shown: = false
var last_n: = 0
var aura_t: = 0.0
var best: = 0
var stopped: = false
var sub_hold_until: = 0.0
var _sb_frame: = StyleBoxFlat.new()
var _sb_pill: = StyleBoxFlat.new()
var _sb_fill: = StyleBoxFlat.new()

func setup(p) -> V7Combo:
	play = p
	name = "V7Combo"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 28
	size = p.size
	_sb_frame.bg_color = Color(0, 0, 0, 0)
	_sb_frame.set_corner_radius_all(30)
	_sb_pill.set_corner_radius_all(26)
	_sb_pill.bg_color = Color(0.09, 0.07, 0.11, 0.93)
	_sb_pill.set_border_width_all(3)
	_sb_pill.shadow_size = 10
	_sb_fill.set_corner_radius_all(22)
	# 0.8: the pill lives in the HUD row under the goal plate (PILL_RECT), with its milestone line inside it,
	# so it never covers a tile row of the table
	pill = Control.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.size = PILL_RECT.size
	pill.pivot_offset = pill.size * 0.5
	pill.visible = false
	add_child(pill)
	pill_lbl = UI.label("", 26, Color.WHITE, Color(0.1, 0.03, 0.12), 5, "title", 900)
	pill_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill_lbl.position = Vector2(0, -1)
	pill_lbl.size = Vector2(PILL_RECT.size.x, 32)
	pill_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pill_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pill.add_child(pill_lbl)
	pill_sub = UI.label("", 16, Color("ffe7a6"), Color(0.1, 0.03, 0.12), 4, "body", 900)
	pill_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill_sub.position = Vector2(0, 29)
	pill_sub.size = Vector2(PILL_RECT.size.x, 22)
	pill_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pill_sub.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pill.add_child(pill_sub)
	return self

func _frame_rect() -> Rect2:
	var r: Rect2 = play.board_rect
	if play.board and play.board.bounds.size.x > 0:

		var b: TrayBoard = play.board
		var tl: = b.position + b.bounds.position * b.scale.x
		var br: = tl + b.bounds.size * b.scale.x
		var fr: = Rect2(tl, br - tl).grow(34)
		r = fr.intersection(r.grow(6)) if fr.intersects(r) else r
	return r

func _tier(n: int) -> Array:
	var t: Array = TIERS[0]
	for x in TIERS:
		if n >= int(x[0]):
			t = x
	return t

func _left_frac() -> float:
	var b: TrayBoard = play.board
	if b == null or b.combo < 2:
		return 0.0
	return clampf(1.0 - (b.now() - b.last_match) / maxf(0.5, b.combo_window), 0.0, 1.0)

# 0.8: the final result window hides the combo pill and the board glow at once (no «×22» over the stars).
func stop() -> void :
	stopped = true
	shown = false
	last_n = 0
	glow = 0.0
	glow_target = 0.0
	if pill:
		pill.visible = false
	visible = false
	queue_redraw()

func resume() -> void :
	stopped = false
	visible = true

func _process(dt: float) -> void :
	if stopped:
		return
	if play == null or not is_instance_valid(play.board):
		return
	var b: TrayBoard = play.board
	var alive: = b.combo >= 2 and _left_frac() > 0.0
	if alive != shown:
		shown = alive
		if alive:
			_pill_in()
		else:
			_pill_out()
	glow_target = 0.0 if not alive else clampf(0.25 + 0.12 * (b.combo - 2), 0.25, 1.0)
	glow = move_toward(glow, glow_target, dt * (2.5 if glow_target > glow else 1.2))
	if alive and b.combo >= 4:
		aura_t -= dt
		if aura_t <= 0.0 and play.stage:
			aura_t = maxf(0.25, 0.7 - b.combo * 0.03)
			var hp: Vector2 = play.stage.head_pos()
			Fx.burst(play.fx_layer, hp + Vector2(randf_range(-60, 60), randf_range(-20, 80)), "sparkle", 4 + mini(b.combo, 10), col, 0.6)
			if b.combo >= 8:
				Fx.burst(play.fx_layer, hp + Vector2(randf_range(-50, 50), 40), "heart", 2, Color("ff9fbf"), 0.6)
	queue_redraw()

func _draw() -> void :
	if stopped:
		return
	if glow > 0.01:
		var r: = _frame_rect()
		var pulse: = 0.75 + 0.25 * sin(G.time * (4.0 + glow * 6.0))

		var layers: = 3 + int(glow * 5)
		for i in layers:
			var k: = 1.0 - float(i) / layers
			_sb_frame.set_border_width_all(4)
			_sb_frame.border_color = Color(col.r, col.g, col.b, 0.75 * glow * pulse * k * k)
			_sb_frame.set_corner_radius_all(30 + i * 4)
			draw_style_box(_sb_frame, r.grow(i * 4))
		_sb_frame.set_corner_radius_all(26)
		_sb_frame.set_border_width_all(2)
		_sb_frame.border_color = Color(1, 1, 1, 0.5 * glow * pulse)
		draw_style_box(_sb_frame, r.grow(-3))
	if pill.visible:
		var pr: = Rect2(pill.position, pill.size)

		var c: = pr.get_center()
		var sz: = pr.size * pill.scale
		pr = Rect2(c - sz * 0.5, sz)
		_sb_pill.border_color = col
		_sb_pill.shadow_color = Color(col.r, col.g, col.b, 0.45)
		_sb_pill.bg_color.a = 0.93 * pill.modulate.a
		_sb_pill.border_color.a = pill.modulate.a
		draw_style_box(_sb_pill, pr)
		var f: = _left_frac()
		if f > 0.0:
			var ir: = pr.grow(-5)
			ir.size.x *= f
			_sb_fill.bg_color = Color(col.r, col.g, col.b, 0.42 * pill.modulate.a)
			draw_style_box(_sb_fill, ir)

# 0.8: the pill sits in the HUD row between the gem counter (ends x 126, room for a 4–5 digit value) and the
# passive chip (x 404), above the tray frame (y ≈ 176), and covers the note slot while a combo runs; see the
# layout note in play.gd. It is never scaled past 1.0 (no overshoot), so its box stays inside this rect.
const PILL_RECT: = Rect2(134, 122, 262, 52)

func _place_pill() -> void :
	pill.position = PILL_RECT.position

# 0.8: the label draws from its LabelSettings (UI.label), which win over theme overrides — so font, size and
# colour are set on label_settings, not with add_theme_*_override
func _fit_title() -> void :
	var room: = PILL_RECT.size.x - 24.0
	var f: = UI.font("title", 900)
	var fs: = 26
	while fs > 24 and f.get_string_size(pill_lbl.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > room:
		fs -= 1
	if f.get_string_size(pill_lbl.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > room:
		# Playfair only from 24 px: a long tier name goes to Nunito instead of a smaller Playfair
		f = UI.font("body", 900)
		fs = 24
		while fs > 18 and f.get_string_size(pill_lbl.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > room:
			fs -= 1
	var ls: LabelSettings = pill_lbl.label_settings
	if ls.font != f or ls.font_size != fs:
		ls.font = f
		ls.font_size = fs
		ls.outline_size = 5 if fs >= 24 else 4

func _pill_in() -> void :
	_place_pill()
	pill.visible = true
	pill.modulate.a = 0.0
	# fade in at full size: a scale-in would overshoot the HUD row and shrink the 16 px sub-line
	pill.scale = Vector2.ONE
	var t: = pill.create_tween()
	t.tween_property(pill, "modulate:a", 1.0, 0.14)

func _pill_out() -> void :
	var n: = last_n
	if n >= 5 and n > best:
		best = n
		Fx.float_text(play.fx_layer, pill.position + pill.size * 0.5 + Vector2(0, 30), "Серия ×%d" % n, col, 30)
	var t: = pill.create_tween().set_parallel()
	t.tween_property(pill, "modulate:a", 0.0, 0.3)
	t.tween_property(pill, "scale", Vector2(0.8, 0.8), 0.3)
	t.chain().tween_callback( func():
		if not shown:
			pill.visible = false)
	last_n = 0

func on_match(mid: Vector2, n: int, gain: int) -> void :
	if n < 2 or stopped:
		return
	last_n = n
	var t: = _tier(n)
	col = t[2]
	if not shown:
		shown = true
		_pill_in()
	_place_pill()
	pill_lbl.text = "×%d · %s" % [n, t[1]]
	_fit_title()
	pill_lbl.label_settings.font_color = col.lightened(0.35)
	var mult: = 1 + (n - 1) / 2
	if G.time >= sub_hold_until:
		pill_sub.text = "кристаллы ×%d" % mult if mult > 1 else "держи темп"
		pill_sub.label_settings.font_color = Color("ffe7a6")
	# punch the title only: the pill box itself never grows past PILL_RECT
	UI.punch(pill_lbl, 0.1 + mini(n, 10) * 0.01)

	var dst: = pill.position + pill.size * 0.5
	_spark(mid, dst)
	Fx.ring(play.fx_layer, dst, col, 1.0 + mini(n, 12) * 0.08, 0.4)
	if n in [3, 5, 8, 12, 16] or (n >= 20 and n % 5 == 0):
		_milestone(n, dst)

func _spark(from: Vector2, to: Vector2) -> void :
	var s: = Sprite2D.new()
	s.texture = G.fx("sparkle")
	s.material = Fx.add_mat()
	s.modulate = col
	s.scale = Vector2(0.5, 0.5)
	s.position = from
	play.fx_layer.add_child(s)
	var mid: = from.lerp(to, 0.5) + Vector2(randf_range(-80, 80), -60)
	var tw: = s.create_tween()
	tw.tween_method( func(k: float): s.position = from.lerp(mid, k).lerp(mid.lerp(to, k), k), 0.0, 1.0, 0.32).set_ease(Tween.EASE_IN)
	tw.tween_callback(s.queue_free)

func _milestone(n: int, at: Vector2) -> void :
	var st = play.stage
	if st:
		st.react("big")
		Fx.burst(play.fx_layer, st.head_pos(), "heart", 8 + mini(n, 12), Color("ff9fbf"), 1.0)
		Fx.flash_glow(play.fx_layer, st.head_pos(), col, 3.0, 0.5)
	var what: = ""
	var icon: = ""
	var target: Control = null
	match n:
		3:
			if not play.skill_ready:
				play.skill_charge += 1
				if play.skill_charge >= play.SKILL_NEED:
					play._skill_ready()
				what = "+1 к умению"
				icon = "rating"
				target = st
		5:
			what = "Лихорадка: кристаллы ×2"
			icon = "gem"
		8:
			play.hint_n += 1
			what = "+1 подсказка"
			icon = "hint"
			target = play.btn_hint
		12:
			play.shuffle_n += 1
			what = "+1 перемешивание"
			icon = "shuffle"
			target = play.btn_shuffle
		16:
			play.undo_n += 1
			what = "+1 возврат"
			icon = "undo"
			target = play.btn_undo
		_:
			var g: = 10 + n
			if str(play.get("mode")) != "trial":
				G.S.gems += g
				play.gained += g
			what = "+%d %s" % [g, V8PlayRules.plural(g, "кристалл", "кристалла", "кристаллов")]
			icon = "gem"
			target = play.gems_lbl
	if what == "":
		return
	# 0.8: the milestone reward is said inside the pill (its second line), not as a float that would rise into
	# the yaku plaque or the luck strip
	pill_sub.text = what
	pill_sub.label_settings.font_color = Color("9fe8d0")
	sub_hold_until = G.time + 1.4
	UI.punch(pill_sub, 0.15)
	if icon != "" and target and is_instance_valid(target):
		var ic: = Sprite2D.new()
		# 0.8 art: currencies from cur/*, the rest from icon/* (V8Art caches them)
		ic.texture = V8Art.cur(icon) if icon in ["gem", "coin", "ticket"] else V8Art.icon(icon)
		ic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		ic.scale = Vector2.ONE * (56.0 / maxf(1.0, ic.texture.get_width()))
		ic.position = at
		ic.z_index = 46
		play.fx_layer.add_child(ic)
		var to: Vector2 = target.get_global_rect().get_center()
		var tw: = ic.create_tween()
		tw.tween_property(ic, "position", at + Vector2(0, -40), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(ic, "position", to, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(ic, "scale", ic.scale * 0.6, 0.45)
		tw.tween_callback( func():
			Fx.ring(play.fx_layer, to, col, 1.2, 0.35)
			Sfx.play("pop", 1.2)
			if is_instance_valid(target):
				UI.punch(target, 0.25)
			if play.has_method("_refresh"):
				play._refresh()
			ic.queue_free())
