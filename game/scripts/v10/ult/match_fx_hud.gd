class_name V10MatchFxHud
extends Control

const BADGE_W: = 476.0
const BADGE_H: = 64.0
const SWOOP_HOLD: = 0.85
const BURST_HOLD: = 0.95

var play
var hero_id: = "mc"
var hero_col: = Color("ff7fa8")
var badge: Control
var badge_lbl: Label
var badge_sub: Label
var _frac: = 0.0
var _shown: = false
var _fever_on: = false
var _combo_n: = 0
var _pulse: = 0.0
var _burst_node: Control
var _swoop_node: Control
var _last_swoop_t: = -10.0


func setup(p, badge_y: float) -> V10MatchFxHud:
	play = p
	name = "V10MatchFxHud"
	position = Vector2.ZERO
	size = p.size
	z_index = 34
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	hero_id = String(p.partner) if G.HEROES.has(String(p.partner)) else "mc"
	hero_col = G.HEROES[hero_id].color

	badge = Control.new()
	badge.name = "ComboBadge"
	badge.position = Vector2((size.x - BADGE_W) * 0.5, badge_y)
	badge.size = Vector2(BADGE_W, BADGE_H)
	badge.pivot_offset = badge.size * 0.5
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.visible = false
	badge.draw.connect(_draw_badge)
	add_child(badge)

	badge_lbl = UI.title("КОМБО ×2", 34, Color("fff6dc"), Color("42081c"))
	badge_lbl.label_settings.outline_size = 7
	badge_lbl.position = Vector2(16, -3)
	badge_lbl.size = Vector2(BADGE_W - 32, 38)
	badge_lbl.pivot_offset = badge_lbl.size * 0.5
	badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge_lbl.set_meta("tut_id", "match.combo")
	badge.add_child(badge_lbl)

	badge_sub = UI.label("", 14, Color("ffe7a6"), Color(0.10, 0.02, 0.08), 3, "body", 900)
	badge_sub.position = Vector2(24, 32)
	badge_sub.size = Vector2(BADGE_W - 48, 18)
	badge_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_sub.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(badge_sub)
	return self


func stop() -> void:
	_shown = false
	if badge:
		badge.visible = false
	if _burst_node and is_instance_valid(_burst_node):
		_burst_node.queue_free()
	_burst_node = null
	if _swoop_node and is_instance_valid(_swoop_node):
		_swoop_node.queue_free()
	_swoop_node = null


func _combo_frac() -> float:
	if play == null or play.board == null or not is_instance_valid(play.board):
		return 0.0
	var b: TrayBoard = play.board
	if b.combo < 2:
		return 0.0
	return clampf(1.0 - (b.now() - b.last_match) / maxf(0.5, b.combo_window), 0.0, 1.0)


func _process(dt: float) -> void:
	if play == null or not is_instance_valid(play) or bool(play.get("_v8_over")) or bool(play.get("_v8_modal")):
		if badge and badge.visible:
			stop()
		return
	_pulse += dt
	var fev: bool = float(play.now()) < float(play.fever_until)
	var cf: float = _combo_frac()
	var alive: bool = play.board != null and is_instance_valid(play.board) and int(play.board.combo) >= 2 and cf > 0.0
	var want: bool = alive or fev
	if want != _shown:
		_shown = want
		if want:
			badge.visible = true
			badge.modulate.a = 0.0
			badge.scale = Vector2.ONE * 0.88
			var tw: = badge.create_tween().set_parallel()
			tw.tween_property(badge, "modulate:a", 1.0, 0.14)
			tw.tween_property(badge, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			var tw2: = badge.create_tween()
			tw2.tween_property(badge, "modulate:a", 0.0, 0.22)
			tw2.tween_callback(func():
				if not _shown and badge:
					badge.visible = false)
	if not _shown:
		return
	_fever_on = fev
	if fev and not alive:
		_frac = clampf((float(play.fever_until) - float(play.now())) / 8.0, 0.0, 1.0)
		badge_lbl.text = "FEVER!"
		badge_lbl.label_settings.font_size = 38
		badge_lbl.label_settings.font_color = Color("fff4c8")
		var left_s: = maxi(1, int(ceil(float(play.fever_until) - float(play.now()))))
		badge_sub.text = "ПОЛНОЛУНИЕ · КРИСТАЛЛЫ ×2 · %d С" % left_s
	else:
		_frac = cf
		if fev:
			var left_s2: = maxi(1, int(ceil(float(play.fever_until) - float(play.now()))))
			badge_sub.text = "FEVER · КРИСТАЛЛЫ ×%d · %d С" % [(1 + maxi(0, _combo_n - 1) / 2) * 2, left_s2]
	badge.queue_redraw()


func on_match(combo: int, fever: bool) -> void:
	if bool(play.get("_v8_over")) or bool(play.get("_v8_modal")):
		return
	_combo_n = combo
	_fever_on = fever
	if combo >= 2:
		_shown = true
		badge.visible = true
		badge.modulate.a = 1.0
		var fs: = clampi(32 + (combo - 2) * 2, 32, 42)
		badge_lbl.label_settings.font_size = fs
		if fever or combo >= 5:
			badge_lbl.text = "FEVER! ×%d" % combo if fever else "КОМБО ×%d" % combo
			badge_lbl.label_settings.font_color = Color("fff4c2")
			badge_lbl.label_settings.outline_color = Color("5c0818")
		else:
			badge_lbl.text = "КОМБО ×%d" % combo
			badge_lbl.label_settings.font_color = Color("fff7df")
			badge_lbl.label_settings.outline_color = Color("3e0a20")
		var tier_name: = String(V7Combo.TIERS.filter(func(x): return combo >= int(x[0])).back()[1]).to_upper()
		var mult: = 1 + (combo - 1) / 2
		if not fever:
			badge_sub.text = "%s · КРИСТАЛЛЫ ×%d" % [tier_name, mult] if mult > 1 else "%s · ДЕРЖИ ТЕМП!" % tier_name
		_frac = 1.0
		UI.punch(badge_lbl, 0.24)
		badge.queue_redraw()
		if combo >= 3 or combo == 2:
			_spawn_burst(("FEVER! ×%d" % combo) if (fever and combo >= 5) else ("КОМБО ×%d!" % combo), combo >= 5 or fever)
	if combo >= 3:
		var emo: = "surprised" if (combo == 5 or combo >= 10) else ("shy" if combo >= 7 else "happy")
		swoop_in(emo, "КОМБО ×%d" % combo)


func on_fever() -> void:
	_fever_on = true
	_shown = true
	badge.visible = true
	badge.modulate.a = 1.0
	_spawn_burst("FEVER! · КРИСТАЛЛЫ ×2", true)
	swoop_in("surprised", "FEVER!")


func on_victory() -> void:
	swoop_in(V8Art.win_emotion(hero_id), "ПОБЕДА!")


func _draw_badge() -> void:
	if badge == null:
		return
	var r: = Rect2(Vector2.ZERO, badge.size)
	var glow_a: = 0.34 + 0.16 * sin(_pulse * 6.0)
	var ac: = Color("ff7b3a") if _fever_on else Color("e8456b").lerp(Color("ffd35c"), clampf(float(_combo_n - 2) / 6.0, 0.0, 1.0))
	# Outer glowing aura
	var gp: = V10Button.rr_pts(r.grow(5.0), 30.0, 8)
	badge.draw_colored_polygon(gp, Color(ac.r, ac.g, ac.b, glow_a))
	# Luxury crimson-obsidian lacquer body
	V10Button.lacquer(badge, r, 26.0,
		Color("7c162e") if _fever_on else Color("4a1228"),
		Color("480b1c") if _fever_on else Color("2c0a1a"),
		Color("24050e") if _fever_on else Color("170510"),
		1.0, Color("ffe7a6"), 0.22)
	# Animated countdown bar along bottom inside rim
	var track: = Rect2(24.0, r.size.y - 10.5, r.size.x - 48.0, 5.5)
	badge.draw_rect(track, Color(0.05, 0.01, 0.06, 0.72), true)
	if _frac > 0.01:
		var fw: = maxf(8.0, track.size.x * _frac)
		var fc: = Color("ffd966") if _fever_on else Color("ff8fb8").lerp(Color("ffe7a6"), _frac)
		badge.draw_rect(Rect2(track.position, Vector2(fw, track.size.y)), fc, true)
		badge.draw_circle(track.position + Vector2(fw, track.size.y * 0.5), 4.2, Color("fff9e6"))


func _spawn_burst(txt: String, is_fever: bool) -> void:
	if _burst_node and is_instance_valid(_burst_node):
		_burst_node.queue_free()
	var br: Rect2 = play.board_rect
	var c: = Control.new()
	c.name = "ComboBurst"
	c.size = Vector2(430.0, 58.0)
	c.position = Vector2(16.0, br.end.y - 26.0)
	c.pivot_offset = c.size * 0.5
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.z_index = 46
	add_child(c)
	_burst_node = c

	var fs: = 40 if is_fever else 36
	var l: = UI.title(txt, fs, Color("fff8dc") if is_fever else Color("fff2d4"), Color("6e0d24") if is_fever else Color("4a0c28"))
	l.label_settings.outline_size = 8
	l.size = c.size
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(l)

	c.scale = Vector2.ONE * 1.32
	c.modulate.a = 0.0
	var tw: = c.create_tween()
	tw.tween_property(c, "modulate:a", 1.0, 0.10)
	tw.parallel().tween_property(c, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(BURST_HOLD)
	tw.tween_property(c, "modulate:a", 0.0, 0.24)
	tw.tween_callback(func():
		if _burst_node == c:
			_burst_node = null
		c.queue_free())


func swoop_in(emo_kind: String, tag_text: String = "") -> void:
	if play == null or not is_instance_valid(play) or bool(play.get("_v8_over")) or bool(play.get("_v8_modal")):
		return
	var now_t: = float(play.now())
	# If already swooping cleanly within 0.45s, upgrade expression in place instead of flickering
	if _swoop_node and is_instance_valid(_swoop_node) and now_t - _last_swoop_t < 0.45:
		var old_b = _swoop_node.get_meta("bust", null)
		if old_b is Control and is_instance_valid(old_b) and V8Art.has_emotion(hero_id, emo_kind):
			V8Art.bust_set(old_b, emo_kind, 0.18)
			V8Art.bust_bounce(old_b, 0.04)
		return
	_last_swoop_t = now_t
	if _swoop_node and is_instance_valid(_swoop_node):
		_swoop_node.queue_free()

	var box: = Control.new()
	box.name = "HeroSwoop"
	var bw: = 310.0
	var bh: = 390.0
	var target_x: = size.x - bw + 18.0
	var target_y: = clampf(play.board_rect.position.y + 36.0, 320.0, size.y - bh - 220.0)
	box.size = Vector2(bw, bh)
	box.position = Vector2(size.x + 240.0, target_y)
	box.pivot_offset = Vector2(bw * 0.5, bh * 0.65)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.z_index = 44
	add_child(box)
	_swoop_node = box

	# Glowing diagonal speed-line slash behind heroine bust
	var slash: = Control.new()
	slash.size = box.size
	slash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hc: = hero_col
	slash.draw.connect(func():
		var pts: = PackedVector2Array([
			Vector2(28, bh * 0.44), Vector2(bw + 20, bh * 0.16),
			Vector2(bw + 20, bh * 0.80), Vector2(8, bh * 0.92)
		])
		slash.draw_colored_polygon(pts, Color(hc.r * 0.35 + 0.08, hc.g * 0.2 + 0.04, hc.b * 0.32 + 0.08, 0.84))
		slash.draw_line(pts[0], pts[1], Color("ffe7a6"), 3.5, true)
		slash.draw_line(pts[3], pts[2], Color(hc.lightened(0.35), 0.9), 3.0, true)
		for i in 5:
			var ly: = lerpf(bh * 0.28, bh * 0.78, float(i) / 4.0)
			slash.draw_line(Vector2(36.0 + float(i * 14), ly + 18.0), Vector2(bw, ly - 24.0), Color(1.0, 0.92, 0.74, 0.28), 2.0, true))
	box.add_child(slash)

	if V8Art.has_emotion(hero_id, emo_kind) or Hero.RIGS.has(hero_id):
		var b: = V8Art.bust(hero_id, emo_kind, box.size, Vector2(bw * 0.54, bh * 0.36), 88.0, 0.22)
		box.add_child(b)
		box.set_meta("bust", b)
	else:
		var wp: = "res://assets/v10/wave1/poses/%s_win.webp" % hero_id
		if not ResourceLoader.exists(wp):
			wp = "res://assets/v10/wave1/poses/%s_idle.webp" % hero_id
		if ResourceLoader.exists(wp):
			var tr: = TextureRect.new()
			tr.texture = load(wp)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.size = box.size
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			box.add_child(tr)

	if tag_text != "":
		var pill: = UI.rbox("plum", Rect2(14, bh - 54, 196, 38), 19, 2, 6)
		pill.colors(Color(0.22, 0.06, 0.14, 0.95), Color(0.10, 0.03, 0.08, 0.98)).borders(Color("ffe7a6"), Color("c58a2c"))
		pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(pill)
		var tl: = UI.center_label(UI.label(tag_text, 18, Color("fff4d2"), Color(0.12, 0.02, 0.08), 4, "body", 900), Rect2(0, 0, 196, 38))
		tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pill.add_child(tl)

	Sfx.play("whoosh", 1.18, -7.0)
	if V9Feel.can_fx() and play.fx_layer:
		Fx.burst(play.fx_layer, Vector2(size.x - 110.0, target_y + 130.0), "petal", 10, Color(1.0, 0.82, 0.9), 1.0)

	var tw: = box.create_tween()
	tw.tween_property(box, "position:x", target_x, 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		var bb = box.get_meta("bust", null)
		if bb is Control and is_instance_valid(bb):
			V8Art.bust_bounce(bb, 0.04))
	tw.tween_interval(SWOOP_HOLD)
	tw.tween_property(box, "position:x", size.x + 260.0, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(box, "modulate:a", 0.0, 0.22)
	tw.tween_callback(func():
		if _swoop_node == box:
			_swoop_node = null
		box.queue_free())
