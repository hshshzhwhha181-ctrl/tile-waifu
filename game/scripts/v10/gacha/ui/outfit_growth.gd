class_name V10OutfitGrowth
extends RefCounted

# V10OutfitGrowth — the two growth widgets of an outfit card in «Героини» (spec Г7, Г8) and the mastery ceremony.
#   V10OutfitGrowth.constellation(gacha, item, rect, on_change) -> Control
#       ✦1–✦5 in lavender, what each star gives (current one bright, next one in paper), «Добавить звезду · 60 ❀»
#   V10OutfitGrowth.mastery_ring(item, rect) -> Control       ring around the portrait + roman numeral + «ещё N пар»
#   V10OutfitGrowth.palettes(item, rect, on_pick) -> Control   4 swatches (original + 3 after Mastery I)
#   V10OutfitGrowth.palette_material(idx) -> ShaderMaterial    recolour for any TextureRect of the outfit
#   V10OutfitGrowth.mastery_up(parent, outfit, to_lv, on_try) -> Control
#       I: returns null and the caller toasts toast_text(); II–IV: the gong and a full-screen card «Примерить»

const PAL_SHADER: = preload("res://scripts/v10/gacha/ui/palette.gdshader")


static func rar10(it: Dictionary) -> String:
	return V10Gacha2.rar10(String(it.get("rar", "R")))


static func constellation(gacha: V10Gacha2, it: Dictionary, r: Rect2, on_change: = Callable()) -> Control:
	var p: = V10GUI.sheet(r, 0.9)
	var id: = String(it.id)
	var lv: = V10Stars.level(G.S, id)
	var ol: = V10GUI.overline("созвездие наряда", V10GUI.LAV)
	ol.position = Vector2(18, 14)
	p.add_child(ol)
	for i in 5:
		var on: = i < lv
		var s: = V10GUI.lbl("✦", 40, V10GUI.LAV if on else V10GUI.PAPER_700, "body", 900)
		s.position = Vector2(14 + i * 48, 34)
		p.add_child(s)
	var hero_name: = String(G.HEROES[it.hero].name) if it.has("hero") else String(it.name)
	var un: = V10Stars.unlocks({"hero_name": hero_name}, 5)
	var y: = 96.0
	for u in un:
		var have: bool = lv >= int(u.lv)
		var nxt: bool = int(u.lv) == lv + 1
		var t: = V10GUI.lbl("✦%d  %s" % [u.lv, u.text], 18, V10GUI.PAPER_100 if have else (V10GUI.PAPER_300 if nxt else V10GUI.PAPER_700), "body", 800 if have or nxt else 700)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.size = Vector2(r.size.x - 36, 10)
		t.position = Vector2(18, y)
		p.add_child(t)
		y += t.get_minimum_size().y + 6
	var petals: = V10Money.bal("petals")
	var can: = V10Stars.can_add(G.S, id, petals)
	var btn_t: = "Добавить звезду · %d ❀" % V10Stars.STAR_PETALS if lv < 5 and lv >= 1 else ("Созвездие полное" if lv >= 5 else "Сначала получи наряд")
	var b: = JButton.make(btn_t, "lav" if can else "graphite", Rect2(16, y + 8, r.size.x - 32, 80), null, 22)
	b.set_meta("ux_role", "secondary")
	b.set_gate(func(): return V10Stars.can_add(G.S, id, V10Money.bal("petals")), func(): V9Feel.deny(b))
	b.pressed.connect(func():
		if gacha.add_star(id):
			G.save()
			V9Feel.success(b, "star2")
			Fx.burst(p, Vector2(14 + V10Stars.level(G.S, id) * 48 - 24, 56), "sparkle", 24, V10GUI.LAV, 0.8)
			if on_change.is_valid():
				on_change.call())
	p.add_child(b)
	var bal: = V10GUI.lbl("Лепестки: %d — за повторные наряды" % petals, 17, V10GUI.PAPER_500, "body", 700)
	bal.position = Vector2(18, y + 96)
	p.add_child(bal)
	p.size.y = y + 132
	return p


static func mastery_ring(it: Dictionary, r: Rect2) -> Control:
	var ring: = MasteryRing.new()
	ring.position = r.position
	ring.size = r.size
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pts: = V10Mastery.points(G.S, String(it.id))
	var pr: = V10Mastery.progress(pts, rar10(it))
	ring.frac = float(pr.frac)
	ring.lv = int(pr.lv)
	ring.tex = G.art_tex(it)
	ring.pal = V10Mastery.palette(G.S, String(it.id))
	var cap: = V10GUI.lbl(String(pr.next_text), 17, V10GUI.PAPER_300, "body", 800)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cap.size = Vector2(r.size.x + 80, 10)
	cap.position = Vector2(-40, r.size.y + 8)
	ring.add_child(cap)
	return ring


static func palette_material(idx: int) -> ShaderMaterial:
	var m: = ShaderMaterial.new()
	m.shader = PAL_SHADER
	var v: Vector3 = V10Mastery.PAL_HSV[clampi(idx, 0, V10Mastery.PALETTES)]
	m.set_shader_parameter("hue", v.x)
	m.set_shader_parameter("sat", v.y)
	m.set_shader_parameter("val", v.z)
	return m


static func palettes(it: Dictionary, r: Rect2, on_pick: Callable) -> Control:
	var root: = Control.new()
	root.position = r.position
	root.size = r.size
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var id: = String(it.id)
	var open_: = V10Mastery.level(V10Mastery.points(G.S, id), rar10(it)) >= 1
	var cur: = V10Mastery.palette(G.S, id)
	var sw: = minf(r.size.y, (r.size.x - 3 * 12) / 4.0)
	for i in V10Mastery.PALETTES + 1:
		var b: = Control.new()
		b.position = Vector2(i * (sw + 12), 0)
		b.size = Vector2(sw, sw)
		b.mouse_filter = Control.MOUSE_FILTER_STOP
		b.clip_contents = true
		var t: = _swatch(G.art_tex(it), b.size, i)
		b.add_child(t)
		var ring: = Panel.new()
		ring.size = b.size
		var sb: = StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0)
		sb.border_color = V10GUI.GOLD_300 if i == cur else Color(V10GUI.GOLD_700, 0.45)
		sb.set_border_width_all(3 if i == cur else 1)
		sb.set_corner_radius_all(int(sw * 0.5))
		ring.add_theme_stylebox_override("panel", sb)
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(ring)
		if i > 0 and not open_:
			b.modulate = Color(0.45, 0.43, 0.48)
		var idx: = i
		b.gui_input.connect(func(e):
			if e is InputEventMouseButton and e.pressed:
				if idx > 0 and not open_:
					V9Feel.deny(b)
					return
				V9Feel.press(b, "select", "button")
				on_pick.call(idx))
		root.add_child(b)
	if not open_:
		var l: = V10GUI.lbl("Откроется: Мастерство I — 300 пар в этом наряде", 17, V10GUI.PAPER_500, "body", 700)
		l.position = Vector2(0, sw + 8)
		root.add_child(l)
	return root


# the outfit art cropped to the face/bust area of a square, recoloured by palette idx
static func _swatch(tex: Texture2D, sz: Vector2, idx: int) -> TextureRect:
	var t: = TextureRect.new()
	t.texture = tex
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var ts: = Vector2(tex.get_width(), tex.get_height()) if tex else Vector2(1, 1)
	var k: = sz.x * 2.2 / ts.x
	t.size = ts * k
	t.position = Vector2((sz.x - t.size.x) * 0.5, -t.size.y * 0.1)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.material = palette_material(idx)
	return t


static func toast_text(outfit: String, lv: int) -> String:
	var it: Dictionary = G.ITEM.get(outfit, {})
	return "Мастерство %s · «%s»: %s" % [V10Mastery.ROMAN[lv], it.get("name", outfit), V10Mastery.REWARD[lv]]


static func mastery_up(parent: Control, outfit: String, lv: int, on_try: = Callable()) -> Control:
	if lv < 2:
		return null
	var it: Dictionary = G.ITEM.get(outfit, {})
	var s: = Control.new()
	s.size = parent.get_viewport_rect().size
	s.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(s)
	var W: = s.size.x
	var H: = s.size.y
	var bg: = ColorRect.new()
	bg.size = s.size
	bg.color = Color(V10GUI.NIGHT_900, 0.0)
	s.add_child(bg)
	bg.create_tween().tween_property(bg, "color:a", 0.96, 0.3)
	# the gong: a low boom, a slow gold ring and a shake-free swell
	Sfx.play("summon_boom", 0.62, -2.0)
	Sfx.duck(-8, 2.0)
	V9Feel.haptic("gold")
	Fx.ring(s, Vector2(W * 0.5, H * 0.4), V10GUI.GOLD_500, 4.0, 1.2)
	if V9Feel.can_fx():
		Common.rays(s, Vector2(W * 0.5, H * 0.4), H, Color(1, 0.84, 0.45, 0.5), 14, 0.03, 0.7)
	var cw: = W * 0.56
	var ch: = cw * 1.42
	var card: = Control.new()
	card.position = Vector2((W - cw) * 0.5, H * 0.4 - ch * 0.5)
	card.size = Vector2(cw, ch)
	card.pivot_offset = card.size * 0.5
	s.add_child(card)
	if not it.is_empty():
		var a: = Common.card_art(G.art_tex(it), Rect2(Vector2.ZERO, card.size), Vector2(0.5, 0.3), 1.0, 10.0)
		(a.material as ShaderMaterial).set_shader_parameter("holo", 0.4)
		card.add_child(a)
	var fr: = V10GUI.icon(V10GUI.tex_or_null("res://assets/v10/gacha/banner_frame.png"), Rect2(Vector2.ZERO, card.size))
	fr.stretch_mode = TextureRect.STRETCH_SCALE
	card.add_child(fr)
	card.scale = Vector2(1.4, 1.4)
	card.modulate.a = 0.0
	var ct: = card.create_tween().set_parallel()
	ct.tween_property(card, "scale", Vector2.ONE, 0.7).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	ct.tween_property(card, "modulate:a", 1.0, 0.3)
	var rn: = V10GUI.h1(V10Mastery.ROMAN[lv], 96, V10GUI.GOLD_300)
	UI.center_label(rn, Rect2(0, H * 0.4 - ch * 0.5 - 130, W, 110))
	s.add_child(rn)
	UI.pop_in(rn, 0.35, 2.0)
	var ol: = V10GUI.overline("мастерство наряда", V10GUI.GOLD_500)
	UI.center_label(ol, Rect2(0, H * 0.4 + ch * 0.5 + 24, W, 24))
	s.add_child(ol)
	var tl: = V10GUI.h1(String(V10Mastery.REWARD[lv]), 36)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI.center_label(tl, Rect2(0, H * 0.4 + ch * 0.5 + 50, W, 50))
	s.add_child(tl)
	var close: = func():
		var t: = s.create_tween()
		t.tween_property(s, "modulate:a", 0.0, 0.25)
		t.tween_callback(s.queue_free)
	var tb: = JButton.make("Примерить", "pink", Rect2(24, H - 160, W * 0.62 - 30, 104), null, 30)
	tb.set_meta("ux_role", "primary")
	tb.pressed.connect(func():
		close.call()
		if on_try.is_valid():
			on_try.call())
	s.add_child(tb)
	var lb: = JButton.make("Позже", "glass", Rect2(W * 0.62 + 6, H - 160, W * 0.38 - 30, 104), null, 24)
	lb.set_meta("ux_role", "secondary")
	lb.sound = "tap"
	lb.pressed.connect(close)
	s.add_child(lb)
	return s


class MasteryRing extends Control:
	var frac: = 0.0
	var lv: = 0
	var tex: Texture2D
	var pal: = 0

	func _ready() -> void:
		if tex:
			var r: = size.x * 0.4
			var holder: = Control.new()
			holder.position = size * 0.5 - Vector2(r, r)
			holder.size = Vector2(r, r) * 2
			holder.clip_contents = true
			holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
			holder.add_child(V10OutfitGrowth._swatch(tex, holder.size, pal))
			add_child(holder)
			move_child(holder, 0)
		var l: = V10GUI.lbl(V10Mastery.ROMAN[lv] if lv > 0 else "—", 26, V10GUI.GOLD_300, "title", 700, Color(0.1, 0.05, 0.1), 5)
		UI.center_label(l, Rect2(size.x * 0.5 - 30, size.y - 40, 60, 40))
		add_child(l)

	func _draw() -> void:
		var c: = size * 0.5
		var r: = size.x * 0.46
		draw_arc(c, r, 0, TAU, 64, Color(V10GUI.PAPER_700, 0.5), 5.0, true)
		if frac > 0.0:
			draw_arc(c, r, -PI * 0.5, -PI * 0.5 + TAU * frac, 64, V10GUI.GOLD_500, 6.0, true)
