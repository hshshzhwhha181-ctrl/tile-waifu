class_name V10SalonFinale
extends Control

# Zone finale ceremony (spec §Р1 п.7): after the light wave the heroine of the zone steps out (rig appear() or
# her breathing still), says her line in her voice (pen-written 0.4 s, Playfair italic — the Voice role until
# the founders' Caveat lands), the ribbon «Новая сцена: Рин за стойкой», the chest opens and its rewards land
# as tiles in an 80 ms cascade, one pentatonic note each (UX §6.7: no coin fountains, no confetti).
# The «тук-тук-туууук» vibration and salon_zone_sting land on the strong beat (heroine entrance).
# Buttons: «Смотреть сцену» (game) and «Играть · уровень N» (second). Emits scene(), play(), closed().

signal scene
signal play
signal closed

const FLOOR: = 0.58
const SHORT: = {"gems": "Кристаллы", "hint": "Подсказка", "shuffle": "Перемешать", "undo": "Отмена", "leaves": "Чайный лист", "tickets": "Билет"}

var zid: = ""
var rewards: = {}
var heroine: V10SalonHeroine
var line_lbl: Label
var _closing: = false


static func open(parent: Control, zid_: String, rewards_: Dictionary) -> V10SalonFinale:
	var f: = V10SalonFinale.new()
	f.zid = zid_
	f.rewards = rewards_
	f.size = parent.size
	f.mouse_filter = Control.MOUSE_FILTER_STOP
	f.z_index = 70
	parent.add_child(f)
	f._build()
	return f


func _build() -> void:
	var W: = size.x
	var H: = size.y
	var z: = V10SalonData.zone(zid)
	var veil: = ColorRect.new()
	veil.color = Color(V10SalonUI.NIGHT_900, 0.0)
	veil.size = size
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(veil)
	# her zone, restored, as the backdrop (lobby art, soft)
	var bg: = TextureRect.new()
	bg.texture = load(V10SalonData.ART + str(z.lobby))
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.size = size
	bg.modulate = Color(0.55, 0.5, 0.55, 0.0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var accent: Color = z.get("accent", V10SalonUI.ROSE_500)
	# warm halo behind her
	var halo: = TextureRect.new()
	halo.texture = V10SalonFx.soft_tex()
	halo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	halo.size = Vector2(W * 1.1, W * 1.1)
	halo.position = Vector2(W * 0.5 - halo.size.x * 0.5, H * 0.18)
	halo.modulate = Color(accent, 0.0)
	halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(halo)
	# she stands under the title (top ≥ 132 px) and is cut by the floor line like a magazine cover
	var hh: = minf(H * FLOOR - 132.0 + H * 0.16, W * 1.4)
	heroine = V10SalonHeroine.make(str(z.hero), Vector2(W, hh), true, false)
	heroine.position = Vector2(0, H * FLOOR + H * 0.16 - hh)
	heroine.modulate.a = 0.0
	add_child(heroine)
	var shade: = TextureRect.new()
	var g: = Gradient.new()
	g.set_color(0, Color(V10SalonUI.NIGHT_900, 0.0))
	g.set_color(1, Color(V10SalonUI.NIGHT_900, 0.96))
	var gt: = GradientTexture2D.new()
	gt.gradient = g
	gt.fill_to = Vector2(0, 1)
	gt.width = 4
	gt.height = 64
	shade.texture = gt
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.position = Vector2(0, H * 0.46)
	shade.size = Vector2(W, H * 0.2)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var floor_r: = ColorRect.new()
	floor_r.color = Color(V10SalonUI.NIGHT_900, 0.96)
	floor_r.position = Vector2(0, H * FLOOR)
	floor_r.size = Vector2(W, H * (1.0 - FLOOR) + 2)  # down to the screen edge: no strip of art under the buttons
	floor_r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(floor_r)
	# title: H1 «Зона восстановлена» and the zone's name under it as a Caption (four sizes on the screen:
	# 44 · 32 · 22 · 18, plus her voice — UX §3.7)
	var title: = V10SalonUI.label("Зона восстановлена", 44, V10SalonUI.PAPER_100, "display", 700, 0.7)
	title.position = Vector2(32, 44)
	title.modulate.a = 0.0
	add_child(title)
	var ov: = V10SalonUI.label(str(z.name), 18, accent.lightened(0.35), "body", 800, 0.7)
	ov.position = Vector2(34, 104)
	ov.modulate.a = 0.0
	add_child(ov)
	# her line, written with a pen (Voice 30, UX §6.3)
	line_lbl = V10SalonUI.label(str(z.finale_line), 30, V10SalonUI.PAPER_100, "italic", 500, 0.85)
	line_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line_lbl.position = Vector2(32, H * FLOOR - 118)
	line_lbl.size = Vector2(W - 64, 110)
	line_lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	line_lbl.visible_ratio = 0.0
	add_child(line_lbl)
	# ribbon «Новая сцена: …»
	var rib: = _ribbon("Новая сцена: " + str(z.scene), accent)
	rib.position = Vector2(32, H * FLOOR + 18)
	rib.modulate.a = 0.0
	add_child(rib)
	# chest rewards: tiles with a bevel, cascade 80 ms
	var tiles: = Control.new()
	tiles.position = Vector2(32, H * FLOOR + 84)
	tiles.size = Vector2(W - 64, 210)
	tiles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tiles)
	var keys: = rewards.keys()
	var n: = keys.size()
	var cols: = n if n <= 4 else 3
	var tw: = minf(150.0, (W - 64 - (cols - 1) * 12.0) / maxf(1, cols))
	var tht: = 112.0
	for i in n:
		var k: String = keys[i]
		var tile: = _reward_tile(k, int(rewards[k]), Vector2(tw, tht))
		tile.position = Vector2((i % cols) * (tw + 12), (i / cols) * (tht + 12))
		tile.modulate.a = 0.0
		tiles.add_child(tile)
	# buttons
	var bw: = minf(656.0, W - 64)
	var bx: = (W - bw) * 0.5
	var by: = H - 40 - 104
	var sb: = V10SalonButton.make("game", "Смотреть сцену", Rect2(bx, by, bw * 0.6 - 8, 104))
	sb.pressed.connect(func(): _close(func(): scene.emit()))
	sb.modulate.a = 0.0
	add_child(sb)
	var pb: = V10SalonButton.make("second", "Играть · %d" % V10Salon.next_level(), Rect2(bx + bw * 0.6 + 8, by + 8, bw * 0.4 - 8, 88))
	pb.pressed.connect(func(): _close(func(): play.emit()))
	pb.modulate.a = 0.0
	add_child(pb)
	var close_b: = V10SalonButton.make("quiet", "", Rect2(W - 96, 28, 80, 80))
	close_b.icon = "close"
	close_b.pressed.connect(func(): _close(Callable()))
	close_b.modulate.a = 0.0
	add_child(close_b)
	# ── the beat ──
	var fx: = V10SalonUI.can_fx()
	var t: = create_tween()
	t.tween_property(veil, "color:a", 0.6, 0.25)
	t.parallel().tween_property(bg, "modulate:a", 1.0, 0.45)
	t.parallel().tween_property(halo, "modulate:a", 0.35, 0.6)
	t.tween_callback(func():
		heroine.modulate.a = 1.0
		heroine.appear()
		V10SalonFx.zone_haptic()
		V10SalonUI.sound("salon_zone_sting", 1.0, -3.0)  # file peak −3.7 dBFS → ≤ −6 dBFS played (UX З-4)
		if fx:
			V10SalonFx.sparkle(self, Rect2(W * 0.2, H * 0.15, W * 0.6, H * 0.45), accent.lightened(0.3), 30))
	t.tween_property(ov, "modulate:a", 1.0, 0.24)
	t.parallel().tween_property(title, "modulate:a", 1.0, 0.24)
	t.parallel().tween_property(title, "position:y", 44.0, 0.24).from(56.0).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	t.tween_callback(func(): heroine.talk(2.4))
	t.tween_property(line_lbl, "visible_ratio", 1.0, 0.4 + 0.012 * line_lbl.text.length())
	t.tween_property(rib, "modulate:a", 1.0, 0.24)
	t.parallel().tween_property(rib, "position:x", 32.0, 0.3).from(-40.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var notes: = [1.0, 1.122, 1.26, 1.498, 1.682, 2.0]
	for i in tiles.get_child_count():
		var tile: Control = tiles.get_child(i)
		var ii: = i
		t.tween_interval(0.08)
		t.tween_callback(func():
			V10SalonUI.sound("match%d" % mini(ii, 7), notes[mini(ii, notes.size() - 1)], -4.0)
			V10SalonUI.haptic("tap"))
		t.tween_property(tile, "modulate:a", 1.0, 0.16)
		t.parallel().tween_property(tile, "position:y", 0.0, 0.22).from(26.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(sb, "modulate:a", 1.0, 0.2)
	t.parallel().tween_property(pb, "modulate:a", 1.0, 0.2)
	t.parallel().tween_property(close_b, "modulate:a", 1.0, 0.2)


func _ribbon(text: String, accent: Color) -> Control:
	var c: = Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var w: = V10SalonUI.text_w(text, 22, "body", 800) + 56
	c.size = Vector2(w, 52)
	c.draw.connect(func():
		var pts: = PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w - 16, 26), Vector2(w, 52), Vector2(0, 52)])
		c.draw_colored_polygon(pts, Color(accent.darkened(0.55), 0.95))
		c.draw_line(Vector2(0, 0), Vector2(w, 0), Color(V10SalonUI.GOLD_500, 0.6), 1.0)
		c.draw_line(Vector2(0, 52), Vector2(w, 52), Color(V10SalonUI.GOLD_500, 0.6), 1.0)
		c.draw_circle(Vector2(18, 26), 5.0, V10SalonUI.GOLD_300))
	var l: = V10SalonUI.label(text, 22, V10SalonUI.PAPER_100, "body", 800)
	l.position = Vector2(34, 11)
	c.add_child(l)
	return c


# a reward as a «фишка» card: 3:4-ish, 12 px bevel, painted-ish glyph, the number in Numeric
func _reward_tile(k: String, n: int, sz: Vector2) -> Control:
	var c: = Control.new()
	c.size = sz
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col: Color = V10SalonUI.ITEM_COL.get(k, V10SalonUI.PAPER_300)
	c.draw.connect(func():
		var b: = 12.0
		var pts: = PackedVector2Array([Vector2(b, 0), Vector2(sz.x - b, 0), Vector2(sz.x, b), Vector2(sz.x, sz.y - b), Vector2(sz.x - b, sz.y), Vector2(b, sz.y), Vector2(0, sz.y - b), Vector2(0, b)])
		c.draw_colored_polygon(pts, V10SalonUI.PAPER_100)
		var inner: = PackedVector2Array()
		for p in pts:
			inner.append(sz * 0.5 + (p - sz * 0.5) * 0.9)
		c.draw_colored_polygon(inner, V10SalonUI.NIGHT_700)
		c.draw_polyline(inner + PackedVector2Array([inner[0]]), Color(V10SalonUI.GOLD_700, 0.7), 1.0, true)
		var ic: = Vector2(sz.x * 0.5, sz.y * 0.27)
		match k:
			"gems":
				c.draw_colored_polygon(PackedVector2Array([ic + Vector2(0, -18), ic + Vector2(16, -4), ic + Vector2(0, 18), ic + Vector2(-16, -4)]), col)
				c.draw_line(ic + Vector2(-16, -4), ic + Vector2(16, -4), Color(1, 1, 1, 0.6), 1.5)
			"hint":
				c.draw_circle(ic + Vector2(0, -4), 12, col)
				c.draw_rect(Rect2(ic + Vector2(-6, 8), Vector2(12, 8)), col)
			"shuffle":
				c.draw_arc(ic, 15, 0.3, PI - 0.3, 20, col, 3.0, true)
				c.draw_arc(ic, 15, PI + 0.3, TAU - 0.3, 20, col, 3.0, true)
			"undo":
				c.draw_arc(ic, 14, -PI * 0.2, PI * 1.2, 24, col, 3.0, true)
				c.draw_colored_polygon(PackedVector2Array([ic + Vector2(-20, -2), ic + Vector2(-8, -2), ic + Vector2(-14, 8)]), col)
			"leaves":
				c.draw_colored_polygon(PackedVector2Array([ic + Vector2(-14, 12), ic + Vector2(-4, -14), ic + Vector2(14, -16), ic + Vector2(6, 8)]), col)
			"tickets":
				c.draw_rect(Rect2(ic - Vector2(20, 12), Vector2(40, 24)), col)
				c.draw_circle(ic + Vector2(-20, 0), 5, V10SalonUI.NIGHT_700)
				c.draw_circle(ic + Vector2(20, 0), 5, V10SalonUI.NIGHT_700)
		var f: = V10SalonUI.font("body", 900)
		var s: = "+%d" % n
		var nw: = f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		c.draw_string(f, Vector2((sz.x - nw) * 0.5, sz.y * 0.64), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, V10SalonUI.GOLD_300)
		var nm: String = SHORT.get(k, k)
		var w2: = f.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		c.draw_string(f, Vector2((sz.x - w2) * 0.5, sz.y * 0.87), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, V10SalonUI.PAPER_300))
	return c


func _close(after: Callable) -> void:
	if _closing:
		return
	_closing = true
	var t: = create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.25)
	t.tween_callback(func():
		closed.emit()
		if after.is_valid():
			after.call()
		queue_free())
