class_name V10KitStrip
extends Control

# V10KitStrip — the «Набор героини» ribbon of the wardrobe (D1): Рамка · Акцент · Фишки · Стол · Интерфейс · Стинг ·
# Шрифт. Only what the kit opens is a chip; everything it does not open folds into ONE silhouette teaser of the next
# rank («Фишки и стол · Откроется: наряд «…»», UX §6.4 / §10 В-8: no lock walls, ≤ 1 closed teaser). Captions are
# Caption 18 (UX §6.3); chip widths follow their captions so «Интерфейс» never clips. A tap on a chip shows a 1,2 с
# mini preview; «Сделать партнёром» lives on the wardrobe screen and calls V10Look.wave().
#
#   V10KitStrip.make(hero, outfit, width) -> V10KitStrip     height 132
#   signal element_tapped(element, open)                     the teaser emits ("next", false)

signal element_tapped(element: String, open: bool)

const H: = 132.0
const CHIP_H: = 116.0
const PREVIEW_T: = 1.2
const CAPTION: = 18
const GAP: = 6.0
const PAD: = 6.0

var hero: = "mc"
var outfit: = ""
var look: = {}
var chips: = {}
var teaser: Control


static func make(h: String, o: String, w: float) -> V10KitStrip:
	var s: = V10KitStrip.new()
	s.hero = h
	s.outfit = o
	s.size = Vector2(w, H)
	s.custom_minimum_size = s.size
	s._build()
	return s


func _build() -> void:
	look = V10Look.resolve(hero, outfit)
	var open_els: = []
	for el in V10KitData.ELEMENTS:
		if look.open[el]:
			open_els.append(el)
	var nxt: = V10KitData.next_teaser(hero, outfit)
	var closed_n: = V10KitData.ELEMENTS.size() - open_els.size()
	# widths: every chip at least its caption + padding, the rest of the ribbon shared evenly; the teaser takes the
	# slots of the elements it stands for
	var f: = V10Fonts.font("ui_body", 800)
	var slots: = V10KitData.ELEMENTS.size()
	var base_w: = (size.x - GAP * (slots - 1)) / slots
	var widths: = []
	var need: = 0.0
	for el in open_els:
		var wv: = maxf(base_w, V10Fonts.width(f, String(V10KitData.ELEMENT_SHORT[el]), CAPTION) + PAD * 2.0 + 4.0)
		widths.append(wv)
		need += wv
	var teaser_w: = 0.0
	if closed_n > 0 and not nxt.is_empty():
		teaser_w = base_w * closed_n + GAP * (closed_n - 1)
		need += teaser_w
	var n_items: = open_els.size() + (1 if teaser_w > 0.0 else 0)
	var spare: = size.x - GAP * (n_items - 1) - need
	if spare < 0.0:
		# shrink every chip and the teaser in proportion (the selftest checks that no caption clips)
		var k: = (need + spare) / need
		for i in widths.size():
			widths[i] = float(widths[i]) * k
		teaser_w *= k
	elif spare > 0.0 and teaser_w == 0.0:
		for i in widths.size():
			widths[i] = float(widths[i]) + spare / widths.size()
	else:
		teaser_w += spare
	var x: = 0.0
	for i in open_els.size():
		var el: String = open_els[i]
		var cw: float = widths[i]
		var chip: = _Chip.new()
		chip.name = "Chip_" + el
		chip.position = Vector2(x, 0)
		chip.size = Vector2(cw, CHIP_H)
		chip.open = true
		chip.accent = look.accent.col
		add_child(chip)
		chips[el] = chip
		var cap: = V10HudSkin.label(String(V10KitData.ELEMENT_SHORT[el]), CAPTION, V10HudSkin.tok("paper_300"))
		cap.position = Vector2(PAD * 0.5, CHIP_H - 34)
		cap.size = Vector2(cw - PAD, 26)
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		chip.add_child(cap)
		var art: = _art(el, Vector2(cw - 20, 58), true)
		if art:
			art.position = Vector2(10, 12)
			chip.add_child(art)
		chip.set_meta("ux_role", "option")
		V10HudSkin.tappable(chip, _on_chip.bind(el, chip))
		x += cw + GAP
	if teaser_w > 0.0:
		teaser = _teaser(nxt, Rect2(x, 0, teaser_w, CHIP_H))


# the one closed teaser: a silhouette in paper.700, the next rank's elements and how they open (UX §6.4)
func _teaser(nxt: Dictionary, r: Rect2) -> Control:
	var t: = _Chip.new()
	t.name = "Teaser_" + String(nxt.rank)
	t.position = r.position
	t.size = r.size
	t.open = false
	add_child(t)
	var title: = V10HudSkin.label(String(nxt.title), CAPTION, V10HudSkin.tok("paper_300"))
	title.position = Vector2(14, 26)
	title.size = Vector2(r.size.x - 28, 28)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.max_lines_visible = 2
	t.add_child(title)
	var how: = V10HudSkin.label(String(nxt.how), CAPTION, V10HudSkin.tok("paper_500"))
	how.position = Vector2(14, CHIP_H - 40)
	how.size = Vector2(r.size.x - 28, 28)
	t.add_child(how)
	if r.size.x < 240.0:
		# narrow (an S kit on a small strip): the title wraps to two lines above the condition
		title.position.y = 10
		title.size.y = 56
	t.set_meta("ux_role", "option")
	V10HudSkin.tappable(t, func(): element_tapped.emit("next", false), false)
	return t


func _art(el: String, sz: Vector2, open: bool) -> Control:
	if not open:
		return null
	match el:
		"frame":
			if V10ProfileCos.has(String(look.frame), "frame"):
				var f: = V10FrameView.make(String(look.frame), hero if V10ProfileCos.released(hero) else "mc", sz.y, {"anim": false})
				f.position = Vector2((sz.x - sz.y) * 0.5, 0)
				var c: = Control.new()
				c.size = sz
				c.mouse_filter = Control.MOUSE_FILTER_IGNORE
				c.add_child(f)
				return c
		"accent":
			var a: = _Swatch.new()
			a.cols = [look.accent.col, look.accent.glow, look.accent.deep]
			a.size = sz
			return a
		"tile":
			var th: = V10TileTheme.thumb(String(look.tile), Vector2(sz.y * 0.76, sz.y))
			th.position = Vector2((sz.x - sz.y * 0.76) * 0.5, 0)
			var c2: = Control.new()
			c2.size = sz
			c2.mouse_filter = Control.MOUSE_FILTER_IGNORE
			c2.add_child(th)
			return c2
		"table":
			var holder: = Control.new()
			holder.size = sz
			holder.clip_contents = true
			holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var tr: = V10TileTheme.table_rect(String(look.table), Rect2(Vector2(6, 6), sz - Vector2(12, 12)), {"frame_w": 6.0, "radius": 8.0, "static": true})
			holder.add_child(tr)
			return holder
		"hud":
			var sw: = _Swatch.new()
			var tk: = V10HudSkinData.tokens(String(look.hud), String(look.palette))
			sw.cols = [tk.night_800, tk.gold_500, tk.rose_500]
			sw.size = sz
			return sw
		"sting":
			var l: = V10HudSkin.label("♪", 40, look.accent.glow)
			l.size = sz
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			return l
		"font":
			var fl: = Label.new()
			fl.text = "Аа"
			var ls: = LabelSettings.new()
			ls.font = V10Fonts.skin(String(look.font), "title", 44)
			ls.font_size = 40
			ls.font_color = look.accent.glow
			fl.label_settings = ls
			fl.size = sz
			fl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			fl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			fl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			return fl
	return null


func _on_chip(el: String, chip: Control) -> void:
	element_tapped.emit(el, true)
	_mini_preview(chip)


# 1,2 с: the chip lifts, scales ×1,35 and glows in the accent, then settles back
func _mini_preview(chip: Control) -> void:
	# the preview owns the scale from here: stop the V9Feel release spring so two tweens never fight
	var spring = chip.get_meta("v9_feel_tw", null)
	if spring is Tween and (spring as Tween).is_valid():
		(spring as Tween).kill()
	chip.pivot_offset = chip.size * 0.5
	chip.z_index = 5
	var tw: = create_tween()
	tw.tween_property(chip, "scale", Vector2(1.35, 1.35), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(PREVIEW_T - 0.36)
	tw.tween_property(chip, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_QUINT)
	tw.tween_callback(func(): chip.z_index = 0)


class _Chip extends Control:
	var open: = true
	var accent: = Color.WHITE

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _draw() -> void:
		var sb: = StyleBoxFlat.new()
		sb.bg_color = V10HudSkin.tok("night_800") if open else Color(V10HudSkin.tok("night_800"), 0.55)
		if not open:
			# silhouette of what is not in this kit: a thin paper.700 edge, no lock icon
			sb.border_color = Color(V10HudSkin.tok("paper_700"), 0.6)
			sb.set_border_width_all(1)
		sb.set_corner_radius_all(4)
		sb.anti_aliasing = true
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		var g7: = V10HudSkin.tok("gold_700")
		draw_line(Vector2(12, 0.5), Vector2(size.x - 12, 0.5), Color(g7, 0.35 if open else 0.15), 1.0)
		if open:
			draw_line(Vector2(size.x * 0.3, size.y - 2), Vector2(size.x * 0.7, size.y - 2), Color(accent, 0.6), 2.0)


class _Swatch extends Control:
	var cols: = []

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r: = minf(size.x, size.y) * 0.34
		var c: = size * 0.5
		for i in cols.size():
			draw_circle(c + Vector2((i - 1) * r * 0.9, 0), r, cols[i], true, -1.0, true)
			draw_arc(c + Vector2((i - 1) * r * 0.9, 0), r, 0.0, TAU, 32, Color(0, 0, 0, 0.35), 1.5, true)
