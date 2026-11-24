class_name V10KitStrip
extends Control

# V10KitStrip — the «Набор богини» ribbon of the wardrobe (D1): Рамка · Акцент · Тема фишек · Стол · HUD · Стинг ·
# Шрифт. What the kit rank does not open is a grey chip with «у S» / «у SSR» (no lock icons, UX §6.4). A tap shows a
# 1,2 с mini preview of the element; «Сделать партнёром» lives on the wardrobe screen and calls V10Look.wave().
#
#   V10KitStrip.make(hero, outfit, width) -> V10KitStrip     height 132
#   signal element_tapped(element, open)

signal element_tapped(element: String, open: bool)

const H: = 132.0
const CHIP_H: = 116.0
const PREVIEW_T: = 1.2

var hero: = "mc"
var outfit: = ""
var look: = {}
var chips: = {}


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
	var n: = V10KitData.ELEMENTS.size()
	var gap: = 8.0
	var cw: = (size.x - gap * (n - 1)) / n
	var i: = 0
	for el in V10KitData.ELEMENTS:
		var open: bool = look.open[el]
		var chip: = _Chip.new()
		chip.name = "Chip_" + el
		chip.position = Vector2(i * (cw + gap), 0)
		chip.size = Vector2(cw, CHIP_H)
		chip.open = open
		chip.accent = look.accent.col
		add_child(chip)
		chips[el] = chip
		var cap: = V10HudSkin.label(String(V10KitData.ELEMENT_SHORT[el]), 15, V10HudSkin.tok("paper_300") if open else V10HudSkin.tok("paper_700"))
		cap.position = Vector2(4, CHIP_H - 30)
		cap.size = Vector2(cw - 8, 22)
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		chip.add_child(cap)
		var art: = _art(el, Vector2(cw - 20, 58), open)
		if art:
			art.position = Vector2(10, 12)
			chip.add_child(art)
		if not open:
			var lk: = V10HudSkin.label(V10KitData.lock_text(el), 18, V10HudSkin.tok("paper_500"))
			lk.position = Vector2(0, 26)
			lk.size = Vector2(cw, 30)
			lk.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			chip.add_child(lk)
		chip.gui_input.connect(_on_chip.bind(el, chip))
		i += 1


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


func _on_chip(ev: InputEvent, el: String, chip: Control) -> void:
	if not (ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and not ev.pressed):
		return
	var open: bool = look.open[el]
	if get_tree().root.get_node_or_null("G"):
		if open:
			V9Feel.press(chip)
		else:
			V9Feel.deny(chip)
	element_tapped.emit(el, open)
	if open:
		_mini_preview(chip)


# 1,2 с: the chip lifts, scales ×1,35 and glows in the accent, then settles back
func _mini_preview(chip: Control) -> void:
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
