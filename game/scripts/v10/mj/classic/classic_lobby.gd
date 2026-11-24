class_name V10MjClassicLobby
extends Control

# «Классика» mode screen (MODES §6.3: one transition from the «Столы» shelf). Magazine cover (UX §6.8): the hostess
# stands on the right, the title on the left; one primary «Играть», the variant segment and the content of the
# variant (form shelf / form of the day / memory sizes), mastery as one thin bar. Words ≤ 60, tappables ≤ 10.
#   setup(main, args) — args: hero (hostess, default "mc"), fx, no_save
#   signal play(args)  — args for V10MjClassicScreen / V10MjClassicMemory (variant, form, diff, size, hero, seed)
#   signal back

signal play(args: Dictionary)
signal back

const SIZES: = ["4x4", "4x5", "5x6", "6x6"]
const DIFFS: = [["easy", "Лёгкая"], ["normal", "Обычная"], ["master", "Мастер"]]

var main: Node
var args: = {}
var hero: = "mc"
var variant: = "free"
var form_id: = "turtle"
var diff: = "normal"
var mem_size: = "4x4"
var no_save: = false
var content: Control
var seg: _Segment
var diff_col: Control
var play_btn: V10MjClassicStyle.Btn
var mastery: Control
var hero_art: TextureRect
var how_sheet: Control
var cards: Array = []


func setup(main_: Node, a: Dictionary) -> void:
	main = main_
	args = a
	hero = String(a.get("hero", "mc"))
	no_save = bool(a.get("no_save", false))
	var d: = V10MjClassicData.st()
	form_id = String(d.get("last_form", "turtle"))
	if not V10MjClassicLayouts.visible(V10MjClassicLayouts.get_form(form_id)):
		form_id = "turtle"
	diff = String(d.get("diff", "normal"))
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if is_inside_tree() and content == null:
		_build()


func _ready() -> void:
	if content == null and not args.is_empty():
		_build()


func _build() -> void:
	var T: = V10MjClassicStyle.TOK
	var vs: = get_viewport_rect().size
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var extra: = maxf(0.0, vs.y - 1280.0 * vs.x / 720.0)
	var bgt: = TextureRect.new()
	if ResourceLoader.exists("res://assets/bg/menu_blur.webp"):
		bgt.texture = load("res://assets/bg/menu_blur.webp")
	bgt.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bgt.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bgt.size = vs
	bgt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bgt)
	var sh: = ColorRect.new()
	sh.color = Color(T.night900, 0.66)
	sh.size = vs
	sh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sh)
	# the hostess, full height on the right (cut by the right edge), lit by her accent
	hero_art = TextureRect.new()
	var hp: = "res://assets/hero/%s.png" % hero
	if ResourceLoader.exists(hp):
		hero_art.texture = load(hp)
	hero_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hero_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	var hh: = minf(720.0 + extra, 860.0)
	hero_art.size = Vector2(hh * 848.0 / 1264.0, hh)
	hero_art.position = Vector2(maxf(vs.x - hero_art.size.x * 0.86, 300.0), 40)
	hero_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hero_art)
	var fade: = _Fade.new()
	fade.position = Vector2(0, 40 + hh - 220)
	fade.size = Vector2(vs.x, 240)
	add_child(fade)
	var back_b: = V10MjClassicStyle.Btn.new("quiet", "", "back")
	back_b.size = Vector2(80, 80)
	back_b.position = Vector2(8, 20)
	back_b.pressed.connect(func(): back.emit())
	add_child(back_b)
	var help_b: = V10MjClassicStyle.Btn.new("quiet", "", "help")
	help_b.size = Vector2(80, 80)
	help_b.position = Vector2(88, 20)
	help_b.pressed.connect(_how)
	add_child(help_b)
	var over: = V10MjClassicStyle.label("СТОЛЫ · ПАСЬЯНСЫ", 15, T.gold500, "body", 900)
	over.position = Vector2(32, 128)
	add_child(over)
	var h1: = V10MjClassicStyle.label("Классика", 44, T.paper100, "title", 700)
	V10MjClassicStyle.shadow(h1, 0.6)
	h1.position = Vector2(30, 150)
	add_child(h1)
	var cap: = V10MjClassicStyle.label("Сними пары с объёмной формы", 22, T.paper300, "body", 700)
	cap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cap.size = Vector2(300, 70)
	cap.position = Vector2(32, 212)
	V10MjClassicStyle.shadow(cap, 0.6)
	add_child(cap)
	diff_col = Control.new()
	diff_col.position = Vector2(32, 320)
	diff_col.size = Vector2(240, 3 * 84)
	add_child(diff_col)
	var y0: = 40.0 + hh + maxf(0.0, (720.0 + extra) - hh) * 0.5
	seg = _Segment.new()
	seg.items = ["Свободная", "Раскладка дня", "Память"]
	seg.size = Vector2(vs.x - 48, 80)
	seg.position = Vector2(24, y0)
	seg.changed.connect(func(i):
		variant = ["free", "daily", "memory"][i]
		_fill())
	add_child(seg)
	content = Control.new()
	content.position = Vector2(0, y0 + 92)
	content.size = Vector2(vs.x, 252)
	add_child(content)
	mastery = V10MjClassicStyle.Paint.new(_draw_mastery)
	mastery.position = Vector2(32, y0 + 352)
	mastery.size = Vector2(vs.x - 64, 40)
	add_child(mastery)
	play_btn = V10MjClassicStyle.Btn.new("play", "Играть")
	play_btn.size = Vector2(560, 104)
	play_btn.position = Vector2((vs.x - 560) * 0.5, minf(y0 + 400, vs.y - 120))
	play_btn.breathe = true
	play_btn.pressed.connect(_go)
	add_child(play_btn)
	_fill()


class _Fade:
	extends TextureRect
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var g: = Gradient.new()
		var c: = V10MjClassicStyle.TOK.night900
		g.set_color(0, Color(c, 0.0))
		g.set_color(1, Color(c, 0.92))
		g.add_point(0.55, Color(c, 0.45))
		var gt: = GradientTexture2D.new()
		gt.gradient = g
		gt.fill_from = Vector2(0, 0)
		gt.fill_to = Vector2(0, 1)
		gt.width = 4
		gt.height = 128
		texture = gt
		expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		stretch_mode = TextureRect.STRETCH_SCALE


class _Segment:
	extends Control
	signal changed(i: int)
	var items: Array = []
	var idx: = 0
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
	func _gui_input(e: InputEvent) -> void:
		if (e is InputEventScreenTouch or (e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT)) and e.pressed:
			var i: = clampi(int(e.position.x / (size.x / items.size())), 0, items.size() - 1)
			accept_event()
			if i != idx:
				idx = i
				V9Feel.sound("tap", 1.05, -6.0)
				V9Feel.haptic("select")
				queue_redraw()
				changed.emit(i)
	func _draw() -> void:
		var T: = V10MjClassicStyle.TOK
		var w: = size.x / items.size()
		var sb: = StyleBoxFlat.new()
		sb.bg_color = Color(T.night800, 0.86)
		sb.set_corner_radius_all(4)
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		var on: = StyleBoxFlat.new()
		on.bg_color = T.night600
		on.set_corner_radius_all(4)
		on.border_color = Color(T.gold500, 0.7)
		on.border_width_bottom = 2
		draw_style_box(on, Rect2(Vector2(w * idx + 4, 4), Vector2(w - 8, size.y - 8)))
		var f: = UI.font("body", 800)
		for i in items.size():
			var s: String = items[i]
			var tw: = f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
			draw_string(f, Vector2(w * i + (w - tw) * 0.5, size.y * 0.5 + 8), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, T.paper100 if i == idx else T.paper500)


# a form card: tile-shaped 3:4 with a 12 px bevel (UX §6.8), the code-drawn miniature, the name, stars as a thin
# strip on the bevel, a heart bookmark in the corner
class _Card:
	extends Control
	signal picked(id: String)
	var form: = {}
	var stars: = 0
	var heart: = false
	var on: = false
	var thumb: V10MjClassicThumb
	var lbl: Label
	func build(f: Dictionary, st: int, h: bool) -> void:
		form = f
		stars = st
		heart = h
		mouse_filter = Control.MOUSE_FILTER_PASS
		thumb = V10MjClassicThumb.new()
		thumb.position = Vector2(14, 14)
		thumb.size = Vector2(size.x - 28, size.y - 74)
		thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		thumb.set_form(f)
		add_child(thumb)
		lbl = V10MjClassicStyle.label(f.name, 20, V10MjClassicStyle.TOK.paper100, "body", 800)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.position = Vector2(4, size.y - 56)
		lbl.size = Vector2(size.x - 8, 28)
		lbl.clip_text = true
		add_child(lbl)
	var _down: = Vector2(-1, -1)
	func _gui_input(e: InputEvent) -> void:
		if e is InputEventScreenTouch or (e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT):
			if e.pressed:
				_down = e.position
			elif _down.x >= 0.0 and e.position.distance_to(_down) < 16.0:
				_down = Vector2(-1, -1)
				if Rect2(size.x - 56, 0, 56, 56).has_point(e.position):
					heart = V10MjClassicData.toggle_heart(form.id)
					V9Feel.press(self, "pop", "select")
					queue_redraw()
				else:
					picked.emit(form.id)
	func _draw() -> void:
		var T: = V10MjClassicStyle.TOK
		var k: = 12.0
		var pts: = PackedVector2Array([Vector2(k, 0), Vector2(size.x, 0), Vector2(size.x, size.y - k), Vector2(size.x - k, size.y),
			Vector2(0, size.y), Vector2(0, k)])
		draw_colored_polygon(pts, Color(T.night700, 0.94) if on else Color(T.night800, 0.86))
		var line: = pts.duplicate()
		line.append(pts[0])
		draw_polyline(line, Color(T.gold500, 0.9) if on else Color(T.gold700, 0.35), 2.0 if on else 1.0, true)
		# stars: a thin strip along the bottom bevel
		for s in 3:
			var c: = Vector2(size.x * 0.5 + (s - 1) * 22, size.y - 16)
			V10MjClassicStyle.glyph(self, "star_on" if s < stars else "star", c, 8, T.gold300 if s < stars else T.paper700)
		V10MjClassicStyle.glyph(self, "heart_on" if heart else "heart", Vector2(size.x - 24, 24), 12, T.rose500 if heart else T.paper500)


func _fill() -> void:
	for c in content.get_children():
		c.queue_free()
	for c in diff_col.get_children():
		c.queue_free()
	cards.clear()
	var T: = V10MjClassicStyle.TOK
	var d: = V10MjClassicData.st()
	diff_col.visible = variant == "free"
	match variant:
		"free":
			for i in DIFFS.size():
				var spec: Array = DIFFS[i]
				var b: = V10MjClassicStyle.Btn.new("quiet", "", "")
				b.size = Vector2(220, 80)
				b.position = Vector2(0, i * 84)
				b.set_meta("id", spec[0])
				var pt: = V10MjClassicStyle.Paint.new(func(c: Control):
					var on: bool = diff == spec[0]
					if on:
						c.draw_rect(Rect2(0, 18, 3, 44), T.gold500)
					var f: = UI.font("body", 800)
					c.draw_string(f, Vector2(16, 50), spec[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, T.paper100 if on else T.paper500))
				pt.size = b.size
				b.add_child(pt)
				b.pressed.connect(func():
					diff = spec[0]
					if not no_save:
						V10MjClassicData.st().diff = diff
					for c2 in diff_col.get_children():
						for c3 in c2.get_children():
							c3.queue_redraw())
				diff_col.add_child(b)
			var sc: = ScrollContainer.new()
			sc.size = content.size
			sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
			content.add_child(sc)
			var row: = HBoxContainer.new()
			row.add_theme_constant_override("separation", 16)
			sc.add_child(row)
			var pad: = Control.new()
			pad.custom_minimum_size = Vector2(8, 10)
			row.add_child(pad)
			var all_f: Array = V10MjClassicLayouts.visible_forms()
			var forms: Array = all_f.filter(func(f): return f.id in d.hearts) + all_f.filter(func(f): return not f.id in d.hearts)
			for f in forms:
				var card: = _Card.new()
				card.custom_minimum_size = Vector2(176, 240)
				card.size = Vector2(176, 240)
				card.build(f, int(d.stars.get(f.id, 0)), f.id in d.hearts)
				card.on = f.id == form_id
				card.picked.connect(func(id):
					form_id = id
					V9Feel.sound("select", 1.0, -6.0)
					for c3 in cards:
						c3.on = c3.form.id == id
						c3.queue_redraw())
				row.add_child(card)
				cards.append(card)
			await get_tree().process_frame
			for c4 in cards:
				if c4.on:
					sc.scroll_horizontal = int(maxf(0.0, c4.position.x - 24.0))
		"daily":
			var date: = V10MjClassicData.msk_date()
			var f: = V10MjClassicLayouts.get_form(V10MjClassicData.daily_form(date))
			var th: = V10MjClassicThumb.new()
			th.position = Vector2(32, 0)
			th.size = Vector2(220, 240)
			th.set_form(f)
			content.add_child(th)
			var n: = V10MjClassicStyle.label(f.name, 32, T.paper100, "title", 600)
			n.position = Vector2(276, 30)
			content.add_child(n)
			var l1: = V10MjClassicStyle.label("Одна форма для всех", 22, T.paper300, "body", 700)
			l1.position = Vector2(278, 84)
			content.add_child(l1)
			var dd: Dictionary = d.daily
			var t2: = "Сыграй — сравним время"
			if dd.get("date", "") == date and dd.get("done", false):
				t2 = "Твоё время %d:%02d" % [int(dd.time) / 60, int(dd.time) % 60]
			var l2: = V10MjClassicStyle.label(t2, 22, T.gold300, "body", 800)
			l2.position = Vector2(278, 122)
			content.add_child(l2)
		"memory":
			var w: = (content.size.x - 64 - 3 * 12) / 4.0
			for i in SIZES.size():
				var sz: String = SIZES[i]
				var c5: = _MemCard.new()
				c5.size = Vector2(w, 236)
				c5.position = Vector2(32 + i * (w + 12), 0)
				c5.sz = sz
				c5.hero = hero
				c5.best = int(d.memory.get(sz, 0))
				c5.on = sz == mem_size
				c5.picked.connect(func(s):
					mem_size = s
					V9Feel.sound("select", 1.0, -6.0)
					for c6 in content.get_children():
						if c6 is _MemCard:
							c6.on = c6.sz == s
							c6.queue_redraw())
				content.add_child(c5)
	mastery.queue_redraw()


class _MemCard:
	extends Control
	signal picked(sz: String)
	var sz: = "4x4"
	var hero: = "mc"
	var best: = 0
	var on: = false
	var crest: Texture2D
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		var p: = "res://assets/v10/mj/classic/crest_%s.png" % hero
		crest = load(p) if ResourceLoader.exists(p) else null
	func _gui_input(e: InputEvent) -> void:
		if (e is InputEventScreenTouch or (e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT)) and not e.pressed:
			picked.emit(sz)
			accept_event()
	func _draw() -> void:
		var T: = V10MjClassicStyle.TOK
		var k: = 12.0
		var pts: = PackedVector2Array([Vector2(k, 0), Vector2(size.x, 0), Vector2(size.x, size.y - k), Vector2(size.x - k, size.y),
			Vector2(0, size.y), Vector2(0, k)])
		draw_colored_polygon(pts, Color(T.night700, 0.94) if on else Color(T.night800, 0.86))
		var line: = pts.duplicate()
		line.append(pts[0])
		draw_polyline(line, Color(T.gold500, 0.9) if on else Color(T.gold700, 0.35), 2.0 if on else 1.0, true)
		var cw: = minf(size.x - 28, 96.0)
		if crest:
			draw_texture_rect(crest, Rect2(Vector2((size.x - cw) * 0.5, 22), Vector2(cw, cw)), false)
		var f: = UI.font("body", 900)
		var t: = sz.replace("x", "×")
		var tw: = f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
		draw_string(f, Vector2((size.x - tw) * 0.5, 160), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, T.paper100)
		if best > 0:
			var b: = "лучшее %d" % best
			var f2: = UI.font("body", 800)
			var bw: = f2.get_string_size(b, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
			draw_string(f2, Vector2((size.x - bw) * 0.5, 196), b, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, T.paper500)


func _draw_mastery(mastery: Control) -> void:
	var T: = V10MjClassicStyle.TOK
	var pr: = V10MjClassicData.rank_progress()
	var r: = int(pr.rank)
	var txt: = "%s · %d из %d ★" % [V10MjClassicData.rank_text(r), int(pr.have), int(pr.need)]
	var f: = UI.font("body", 800)
	mastery.draw_string(f, Vector2(0, 18), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, T.paper500)
	var k: = clampf(float(pr.have) / maxf(1.0, float(pr.need)), 0.0, 1.0)
	mastery.draw_rect(Rect2(0, 30, mastery.size.x, 4), T.night600)
	mastery.draw_rect(Rect2(0, 30, mastery.size.x * k, 4), T.gold500)


func _go() -> void:
	var a: = {"variant": variant, "hero": hero, "fx": args.get("fx", "full"), "no_save": no_save}
	match variant:
		"free":
			a.form = form_id
			a.diff = diff
			if not no_save:
				V10MjClassicData.st().last_form = form_id
				V10MjClassicData.save()
		"daily":
			a.date = V10MjClassicData.msk_date()
		"memory":
			a.size = mem_size
	play.emit(a)


func _how() -> void:
	if how_sheet != null:
		return
	var T: = V10MjClassicStyle.TOK
	how_sheet = V10MjClassicStyle.sheet(self, 420)
	var p: Control = how_sheet.get_meta("panel")
	var t: = V10MjClassicStyle.label("Как играть", 32, T.paper100, "title", 600)
	t.position = Vector2(32, 26)
	p.add_child(t)
	var how: Array = load("res://scripts/v10/mj/classic/classic_info.gd").HOW
	for i in how.size():
		var gid: String = how[i][0]
		var ic: = V10MjClassicStyle.Paint.new(func(c: Control): V10MjClassicStyle.glyph(c, gid, Vector2(24, 24), 20, T.gold300))
		ic.position = Vector2(32, 96 + i * 84)
		ic.size = Vector2(48, 48)
		p.add_child(ic)
		var l: = V10MjClassicStyle.label(how[i][1], 22, T.paper100, "body", 700)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.position = Vector2(96, 92 + i * 84)
		l.size = Vector2(p.size.x - 128, 70)
		p.add_child(l)
	var ok: = V10MjClassicStyle.Btn.new("second", "Понятно")
	ok.size = Vector2(240, 80)
	ok.position = Vector2(p.size.x - 272, 336 - 20)
	ok.pressed.connect(func():
		V10MjClassicStyle.close_sheet(how_sheet)
		how_sheet = null)
	p.add_child(ok)
