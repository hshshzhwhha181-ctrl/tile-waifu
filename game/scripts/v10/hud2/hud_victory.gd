class_name V10HudVictory
extends Control

# V10HudVictory — victory, beat 1 «Стол чист» (docs/HUD_V2.md §8.3, mockup 04). No panel, no 9-patch, no
# stretched box: the heroine large (≥ 40 %), the table covers everything below her hips, the words lie on the
# art with the one shadow rule, and the two buttons stand on FIXED places from the end of beat 1 to the exit:
#   play «Ещё уровень · N» 560x104 at H−B−216 · secondary «В чайную →» 560x80 at H−B−104 · «⋯» quiet top right.
# The heroine never goes below play.y − 24 (scene clip), so hero ∩ buttons = ∅ on every aspect ratio.
#
#   var v := V10HudVictory.new(); add_child(v); v.configure({"hero": "mc", "level": "1-4 · Чайный сад", "stars": 3, "next": 5})
#   signals: next_pressed, home_pressed, more_pressed

signal next_pressed
signal home_pressed
signal more_pressed

var hero_id: = "mc"
var caption: = "1-4 · Чайный сад"
var stars: = 3
var next_n: = 5
var L: = {}

var backdrop: TextureRect
var hero_clip: Control
var rig: Node2D
var table: Control
var title_l: Label
var stars_c: Control
var caption_l: Label
var play_b: V10Button
var home_b: V10Button
var more_b: V10Button


static func compute(vs: Vector2, ins: Dictionary) -> Dictionary:
	var W: = vs.x
	var H: = vs.y
	var T: = float(ins.get("top", 0.0))
	var B: = float(ins.get("bottom", 0.0))
	var cx: = floorf(maxf(0.0, (W - 720.0) * 0.5))
	var d: = {"vs": vs, "T": T, "B": B, "cx": cx}
	d.play = Rect2(cx + 80, H - B - 216, 560, 104)
	d.home = Rect2(cx + 80, H - B - 104, 560, 80)
	d.more = Rect2(cx + 616, T + 24, 80, 80)
	d.hero_clip = Rect2(0, 0, W, d.play.position.y - 24.0)
	d.title = Rect2(cx + 32, d.play.position.y - 216, 656, 72)
	d.stars = Rect2(cx + 32, d.play.position.y - 128, 200, 56)
	d.caption = Rect2(cx + 32, d.play.position.y - 56, 480, 26)
	# heroine: head at T+96, down to the hips at the clip bottom; face right of centre
	var avail: = float(d.hero_clip.size.y) - (T + 96.0)
	var s: = clampf(avail / 1000.0, 0.7, 1.15)
	var fx: = cx + 720.0 * 0.6
	d.hero_scale = s
	d.hero_pos = Vector2(fx - V10HudMatch.RIG_FACE.x * s, T + 96.0 - 60.0 * s)
	d.table_y = float(d.hero_clip.size.y) - 72.0
	return d


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func configure(cfg: Dictionary) -> void:
	hero_id = str(cfg.get("hero", hero_id))
	caption = str(cfg.get("level", caption))
	stars = int(cfg.get("stars", stars))
	next_n = int(cfg.get("next", next_n))
	if is_inside_tree():
		_apply_text()
		layout_now()


func _ready() -> void:
	backdrop = TextureRect.new()
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.modulate = V10DS.TINT_VICTORY
	var bp: String = V10HudMatch.RIG_BG.get(hero_id, "res://assets/v10/rig/mc_gown/bg.png")
	if ResourceLoader.exists(bp):
		backdrop.texture = load(bp)
	add_child(backdrop)
	hero_clip = Control.new()
	hero_clip.clip_contents = true
	hero_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hero_clip)
	var rp: String = V10HudMatch.RIG_PATHS.get(hero_id, "")
	if rp != "" and ResourceLoader.exists(rp):
		rig = load(rp).instantiate()
		rig.set("show_background", false)
		rig.set("handle_input", false)
		hero_clip.add_child(rig)
	table = _Table.new()
	table.v = self
	add_child(table)
	title_l = V10Type.label("Стол чист", "display", 64, V10DS.PAPER_100, true)
	title_l.clip_text = false
	add_child(title_l)
	stars_c = _Stars.new()
	stars_c.v = self
	add_child(stars_c)
	caption_l = V10Type.label("", "ui", 18, V10DS.PAPER_300, true)
	add_child(caption_l)
	play_b = V10Button.make("play", "", Vector2(560, 104))
	play_b.pressed.connect(func() -> void: next_pressed.emit())
	add_child(play_b)
	home_b = V10Button.make("secondary", "В чайную", Vector2(560, 80))
	home_b.pressed.connect(func() -> void: home_pressed.emit())
	add_child(home_b)
	more_b = V10Button.make("quiet", "", Vector2(80, 80))
	more_b.icon = "more"
	more_b.icon_color = V10DS.PAPER_300
	more_b.pressed.connect(func() -> void: more_pressed.emit())
	add_child(more_b)
	_apply_text()
	get_viewport().size_changed.connect(layout_now)
	layout_now()
	_enter()


func _apply_text() -> void:
	play_b.text = "Ещё уровень · %d" % next_n
	caption_l.text = caption
	stars_c.queue_redraw()


func layout_now() -> void:
	var vs: = get_viewport_rect().size
	L = compute(vs, V10Hud2Util.safe_insets(vs))
	backdrop.position = Vector2.ZERO
	backdrop.size = vs
	var hc: Rect2 = L.hero_clip
	hero_clip.position = hc.position
	hero_clip.size = hc.size
	if rig:
		rig.position = L.hero_pos
		rig.scale = Vector2.ONE * float(L.hero_scale)
	table.position = Vector2(0, L.table_y)
	table.size = Vector2(vs.x, vs.y - float(L.table_y))
	title_l.position = (L.title as Rect2).position
	title_l.size = (L.title as Rect2).size
	stars_c.position = (L.stars as Rect2).position
	stars_c.size = (L.stars as Rect2).size
	caption_l.position = (L.caption as Rect2).position
	caption_l.size = (L.caption as Rect2).size
	play_b.position = (L.play as Rect2).position
	home_b.position = (L.home as Rect2).position
	more_b.position = (L.more as Rect2).position
	table.queue_redraw()


func _enter() -> void:
	# «Вдох»: ≤ 5 elements, 240 ms each, 40 ms steps, α 0→1 and y +12→0 (no scale)
	var i: = 0
	for n in [title_l, stars_c, caption_l, play_b, home_b]:
		var c: Control = n
		var y0: = c.position.y
		c.modulate.a = 0.0
		c.position.y = y0 + 12.0
		var tw: = create_tween().set_parallel(true)
		tw.tween_property(c, "modulate:a", 1.0, V10DS.T_IN).set_delay(0.3 + i * V10DS.T_IN_STEP).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		tw.tween_property(c, "position:y", y0, V10DS.T_IN).set_delay(0.3 + i * V10DS.T_IN_STEP).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		i += 1
	if rig and rig.has_method("appear"):
		rig.call("appear")


func hero_rect() -> Rect2:
	return L.get("hero_clip", Rect2())


func button_rects() -> Array:
	return [L.get("play", Rect2()), L.get("home", Rect2())]


class _Table:
	extends Control
	var v: V10HudVictory

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		# the lacquered table edge that covers everything below her hips: 72 px fade, then solid night.900
		var w: = size.x
		var c0: = Color(V10DS.NIGHT_900, 0.0)
		var c1: = Color(V10DS.NIGHT_900, 0.96)
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, 72), Vector2(0, 72)]), PackedColorArray([c0, c0, c1, c1]))
		draw_rect(Rect2(0, 72, w, size.y - 72), c1)
		V10Plate.hairline(self, 24.0, w - 24.0, 72.5, Color(V10DS.GOLD_700, V10DS.HAIR_A))


class _Stars:
	extends Control
	var v: V10HudVictory

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		for i in 3:
			V10Icons.draw_star(self, Vector2(28 + i * 72, 28), 26.0, i < v.stars)
