extends Control

# Screen "v10scene" — a finished zone's heroine scene (docs/0.10-spec.md §Р2). args: {zone: zid}.
# Opens with a 0.35 s curtain. Full screen: her zone (lobby art) and her — Маджонг-тян as the live rig
# (V10LiveRig mc_gown: taps, gestures, lip-sync), Рин as the scene still with masked breathing until her rig
# lands (V10SalonHeroine picks the rig automatically when RIGS has a path that exists).
# Bottom: three 120 px buttons «Реплика» (affinity-tier lines, no repeats), «Фон лобби», «Фото» (photo mode).
# Hierarchy (UX §3.4 «Сцена зоны»): «Реплика» is the main action (rose disc), «Фон лобби» and «Фото» secondary,
# «назад» quiet. A tap on her head / hair / arms → a line; on her torso or outfit → a neutral glance only (§8.2).
# First view: +20 affinity (hard source) and a letter next morning — V10Salon.mark_scene_seen.
# dev_act: "line", "lobby", "photo", "tap_head", "back".

var main
var W: = 720.0
var H: = 1280.0
var zid: = ""
var z: Dictionary
var stage: Control
var heroine: V10SalonHeroine
var scene_tex: TextureRect
var scene_mat: ShaderMaterial
var ui: Control
var line_lbl: Label
var who_lbl: Label
var photo: V10SalonPhoto
var first_view: = false
var _t: = 0.0
var _line_tw: Tween
var _hop: = 0.0
var _hop_v: = 0.0

const HERO_NAMES: = {"mc": "Маджонг-тян", "rin": "Рин", "hana": "Хана", "yue": "Юэ", "nova": "Нова"}


func build(m, args: Dictionary) -> void:
	main = m
	W = size.x
	H = size.y
	zid = str(args.get("zone", "z1"))
	z = V10SalonData.zone(zid)
	if main != null and main.has_method("show_chrome"):
		main.show_chrome(false, false)
	var bg: = ColorRect.new()
	bg.color = V10SalonUI.NIGHT_900
	bg.size = size
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	stage = Control.new()
	stage.size = size
	stage.pivot_offset = Vector2(W * 0.5, H * 0.4)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)
	_build_stage()
	_build_ui()
	first_view = V10Salon.mark_scene_seen(zid)
	set_meta("v8_back", _back)
	_curtain()
	if first_view:
		_say_later(0.9, _first_line())


func _first_line() -> String:
	return str(z.finale_line)


func _build_stage() -> void:
	var hero: String = z.hero
	var has_rig: = V10SalonHeroine.has_rig(hero) != ""
	if has_rig or not str(z.scene_bg).contains("scene"):
		# her room + her live body
		var room: = TextureRect.new()
		room.texture = load(V10SalonData.ART + str(z.scene_bg if not str(z.scene_bg).contains("scene") else z.lobby))
		room.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		room.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		room.size = size
		room.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stage.add_child(room)
		# the rig demo's approved framing: art scale 0.645 at 720×1280 (≈ 903 px), bottom just under the screen
		var hh: = minf(H * 0.705, W * 1.254)
		heroine = V10SalonHeroine.make(hero, Vector2(W, hh), true, true)
		heroine.position = Vector2(0, H + 12 - hh)
		heroine.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stage.add_child(heroine)
		heroine.tapped.connect(_on_tap)
		if heroine.rig:
			heroine.rig.motion = 1.0 if V10SalonUI.full_fx() else 0.5
	else:
		# the scene still: the whole painting (her in her room) breathes where her cutout mask says she is
		scene_tex = TextureRect.new()
		scene_tex.texture = load(V10SalonData.ART + str(z.scene_bg))
		scene_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		scene_tex.stretch_mode = TextureRect.STRETCH_SCALE
		# cover the screen, but crop mostly from the bottom: on wide screens (tablets) her head stays in frame
		var tsz: = Vector2(scene_tex.texture.get_width(), scene_tex.texture.get_height())
		var kk: = maxf(W / tsz.x, H / tsz.y)
		scene_tex.size = tsz * kk
		scene_tex.position = Vector2((W - scene_tex.size.x) * 0.5, -(scene_tex.size.y - H) * 0.12)
		scene_tex.mouse_filter = Control.MOUSE_FILTER_STOP
		scene_mat = ShaderMaterial.new()
		scene_mat.shader = load("res://scripts/v10/salon/breath.gdshader")
		var cfg: Dictionary = SCENE_MASKS.get(zid, {})
		if not cfg.is_empty():
			scene_mat.set_shader_parameter("use_mask", 1.0)
			scene_mat.set_shader_parameter("mask", load(cfg.mask))
			scene_mat.set_shader_parameter("mask_rect", cfg.rect)
			scene_mat.set_shader_parameter("chest", cfg.chest)
			scene_mat.set_shader_parameter("head_y", cfg.head_y)
			scene_mat.set_shader_parameter("hair_x", cfg.hair_x)
		var tex: = scene_tex.texture
		scene_mat.set_shader_parameter("px", Vector2(1.0 / tex.get_width(), 1.0 / tex.get_height()))
		scene_tex.material = scene_mat
		stage.add_child(scene_tex)
		scene_tex.gui_input.connect(_on_scene_input)
	# soft floor shade for the buttons
	var g: = Gradient.new()
	g.set_color(0, Color(V10SalonUI.NIGHT_900, 0.0))
	g.set_color(1, Color(V10SalonUI.NIGHT_900, 0.9))
	var gt: = GradientTexture2D.new()
	gt.gradient = g
	gt.fill_to = Vector2(0, 1)
	gt.width = 4
	gt.height = 64
	var sh: = TextureRect.new()
	sh.texture = gt
	sh.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sh.stretch_mode = TextureRect.STRETCH_SCALE
	sh.position = Vector2(0, H - 330)
	sh.size = Vector2(W, 330)
	sh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sh.name = "FloorShade"
	add_child(sh)
	# a corner shade under the title only (radial from the top-left): it never reaches her face, which in the
	# scene stills sits high and right of centre (face_rect + 48 is hers, UX §2.2)
	var g2: = Gradient.new()
	g2.set_color(0, Color(V10SalonUI.NIGHT_900, 0.82))
	g2.set_color(1, Color(V10SalonUI.NIGHT_900, 0.0))
	var gt2: = GradientTexture2D.new()
	gt2.gradient = g2
	gt2.fill = GradientTexture2D.FILL_RADIAL
	gt2.fill_from = Vector2(0, 0)
	gt2.fill_to = Vector2(1, 0)
	gt2.width = 64
	gt2.height = 64
	var top_sh: = TextureRect.new()
	top_sh.texture = gt2
	top_sh.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	top_sh.stretch_mode = TextureRect.STRETCH_SCALE
	top_sh.size = Vector2(minf(W * 0.5, 360.0), 200)
	top_sh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_sh.name = "TopShade"
	add_child(top_sh)


# Where she is inside the scene still (uv of the scene texture) — her cutout as the mask: rin_cut.png was cut
# from the same painting at 760×1344 with bbox (231, 34)–(597, 1324).
const SCENE_MASKS: = {
	"z2": {"mask": "res://assets/v10/salon/rin_cut.png", "rect": Vector4(231.0 / 760.0, 34.0 / 1344.0, 366.0 / 760.0, 1290.0 / 1344.0),
		"chest": Vector2(0.20, 0.36), "head_y": 0.10, "hair_x": Vector2(0.64, 0.77)},
}


func _build_ui() -> void:
	ui = Control.new()
	ui.size = size
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)
	var top: = 24.0
	var back_b: = V10SalonButton.make("quiet", "", Rect2(12, top + 8, 80, 80))
	back_b.icon = "back"
	back_b.pressed.connect(_back)
	ui.add_child(back_b)
	var ov: = V10SalonUI.overline(str(z.name), V10SalonUI.GOLD_500)
	ov.position = Vector2(104, top + 18)
	ui.add_child(ov)
	who_lbl = V10SalonUI.label(str(z.scene), 32, V10SalonUI.PAPER_100, "italic", 600, 0.7)
	who_lbl.position = Vector2(104, top + 38)
	ui.add_child(who_lbl)
	# her line: Voice 30, no bubble, soft shadow, pen 0.4 s / hold 4 s / fade 0.3 s (UX §6.3)
	line_lbl = V10SalonUI.label("", 30, V10SalonUI.PAPER_100, "italic", 500, 0.9)
	line_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line_lbl.position = Vector2(40, H - 330)
	line_lbl.size = Vector2(W - 80, 120)
	line_lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	line_lbl.modulate.a = 0.0
	ui.add_child(line_lbl)
	var bw: = 120.0
	var gap: = (W - 3 * bw) / 4.0
	var y: = H - 48 - bw
	var defs: = [["Реплика", "chat", _line], ["Фон лобби", "home", _lobby], ["Фото", "camera", _photo]]
	for i in 3:
		var b: = V10SalonButton.make("quiet", defs[i][0], Rect2(gap + i * (bw + gap), y - 22, bw, bw))
		b.icon = defs[i][1]
		b.pressed.connect(defs[i][2])
		b.name = "Btn%d" % i
		b.set_meta("ux_role", "primary" if i == 0 else "secondary")
		b.fill = i == 0
		ui.add_child(b)
	if V10Salon.st().lobby_bg == zid:
		(ui.get_node("Btn1") as V10SalonButton).selected = true


func _curtain() -> void:
	# two lacquer panels part from the centre in 0.35 s
	var l: = ColorRect.new()
	var r: = ColorRect.new()
	for p in [l, r]:
		p.color = V10SalonUI.NIGHT_800
		p.size = Vector2(W * 0.5 + 2, H)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.z_index = 90
		add_child(p)
	r.position.x = W * 0.5 - 2
	var t: = create_tween()
	t.tween_property(l, "position:x", -W * 0.5 - 4, 0.35).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN_OUT)
	t.parallel().tween_property(r, "position:x", W + 4, 0.35).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN_OUT)
	t.tween_callback(func():
		l.queue_free()
		r.queue_free())
	V10SalonUI.sound("salon_open", 0.9, -6.0)
	if heroine:
		heroine.appear(0.2)


func _process(dt: float) -> void:
	_t += dt
	if scene_mat == null:
		return
	var m: = 1.0 if V10SalonUI.full_fx() else 0.5
	var ph: = fmod(_t / 4.1, 1.0)
	_hop_v += (-120.0 * _hop - 9.0 * _hop_v) * dt
	_hop += _hop_v * dt
	scene_mat.set_shader_parameter("t", _t * m)
	scene_mat.set_shader_parameter("breath", (0.5 - 0.5 * cos(ph * TAU)) * m)
	scene_mat.set_shader_parameter("hop", clampf(_hop, -1.0, 1.0) * 0.6)


func _on_scene_input(e: InputEvent) -> void:
	if not (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT):
		return
	if photo and is_instance_valid(photo):
		return
	var cfg: Dictionary = SCENE_MASKS.get(zid, {})
	var uv: = _scene_uv(e.position)
	var zone: = "bg"
	if not cfg.is_empty():
		var r: Vector4 = cfg.rect
		var mu: = Vector2((uv.x - r.x) / r.z, (uv.y - r.y) / r.w)
		if mu.x >= 0 and mu.y >= 0 and mu.x <= 1 and mu.y <= 1:
			var img: Image = (load(cfg.mask) as Texture2D).get_image()
			var a: = img.get_pixel(clampi(int(mu.x * img.get_width()), 0, img.get_width() - 1), clampi(int(mu.y * img.get_height()), 0, img.get_height() - 1)).a
			if a > 0.3:
				zone = "head" if mu.y < 0.13 else ("hair" if mu.x > 0.6 else "outfit")
				# intimate areas are dead zones (red lines): hips band does nothing
				if zone == "outfit" and mu.y > 0.34 and mu.y < 0.56:
					zone = "none"
	_on_tap(zone)


func _scene_uv(p: Vector2) -> Vector2:
	# map a tap on the scene picture to texture uv
	# p is local to scene_tex (gui_input), which is exactly the texture rect
	return p / scene_tex.size


func _on_tap(zone: String) -> void:
	match zone:
		"none":
			return
		"bg":
			_say(V10SalonData.NEUTRAL.get(z.hero, "М?"))
		"head":
			_hop = -0.7
			_hop_v = 9.0
			V10SalonUI.haptic("pet")
			_say(V10Salon.tap_line(z.hero, zone))
		"outfit":
			# torso / outfit: only a neutral glance, no hop, no line of her tier (UX §8.2)
			V10SalonUI.haptic("tap")
			_say(V10Salon.tap_line(z.hero, zone))
		_:
			_hop = -0.35
			_hop_v = 6.0
			V10SalonUI.haptic("tap")
			_say(V10Salon.tap_line(z.hero, zone))


func _line() -> void:
	_say(V10Salon.next_line(z.hero))
	if heroine:
		heroine.hop(0.6)
	else:
		_hop = -0.4
		_hop_v = 7.0


func _lobby() -> void:
	if V10Salon.set_lobby(zid):
		(ui.get_node("Btn1") as V10SalonButton).selected = true
		V9Feel.success(ui.get_node("Btn1"))
		_toast("Теперь она встречает тебя здесь")


func _photo() -> void:
	if photo and is_instance_valid(photo):
		return
	photo = V10SalonPhoto.open(self, stage, ui, zid)


func _say(text: String) -> void:
	if text == "":
		return
	if _line_tw and _line_tw.is_valid():
		_line_tw.kill()
	line_lbl.text = text
	line_lbl.visible_ratio = 0.0
	line_lbl.modulate.a = 1.0
	if heroine:
		heroine.talk(minf(3.0, 0.6 + text.length() * 0.045))
	_line_tw = create_tween()
	_line_tw.tween_property(line_lbl, "visible_ratio", 1.0, 0.4 + 0.01 * text.length())
	_line_tw.tween_interval(4.0)
	_line_tw.tween_property(line_lbl, "modulate:a", 0.0, 0.3)


func _say_later(delay: float, text: String) -> void:
	await get_tree().create_timer(delay).timeout
	if is_inside_tree():
		_say(text)


func _toast(text: String) -> void:
	var w: = minf(W - 64, V10SalonUI.text_w(text, 18) + 56)
	# low, over her line's band — never at the top, where her face is (UX §2.2 / Г-1: face_rect + 48 is hers)
	var p: = V10SalonUI.panel(Rect2((W - w) * 0.5, H - 420, w, 64), Color(V10SalonUI.NIGHT_700, 0.97), 4.0, Color(V10SalonUI.GOLD_700, 0.5), 1)
	var l: = V10SalonUI.label(text, 18, V10SalonUI.PAPER_100, "body", 700)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size = Vector2(w, 64)
	p.add_child(l)
	p.z_index = 85
	add_child(p)
	var t: = p.create_tween()
	t.tween_property(p, "modulate:a", 1.0, 0.18).from(0.0)
	t.tween_interval(2.4)
	t.tween_property(p, "modulate:a", 0.0, 0.3)
	t.tween_callback(p.queue_free)


func _back() -> void:
	if photo and is_instance_valid(photo):
		photo.close()
		return
	if main == null:
		return
	# Came from somewhere else (not the salon map): the normal «назад».
	var h = main.get("history")
	if h is Array and not h.is_empty() and str(h[h.size() - 1][0]) != "v10salon" and main.has_method("back"):
		main.back()
		return
	# Back to the map at this zone WITHOUT remembering the scene (remember = false): otherwise «назад» on the map
	# pops the scene again and the player loops salon ↔ scene and never gets home.
	if main.has_method("go"):
		main.go("v10salon", {"zone": zid}, true, false)


# selftest helper: live players / rigs under this screen
func live_counts() -> Dictionary:
	var n: = {"video": 0, "rig": 0}
	var stack: = [self]
	while not stack.is_empty():
		var c: Node = stack.pop_back()
		if c is VideoStreamPlayer:
			n.video += 1
		if c is V10LiveRig:
			n.rig += 1
		stack.append_array(c.get_children())
	return n


func dev_act(name: String) -> void:
	match name:
		"line":
			_line()
		"lobby":
			_lobby()
		"photo":
			_photo()
		"tap_head":
			_on_tap("head")
		"back":
			_back()
		"shoot":
			if photo:
				await photo.shoot()
		"preset":
			if photo:
				photo.next_preset()
