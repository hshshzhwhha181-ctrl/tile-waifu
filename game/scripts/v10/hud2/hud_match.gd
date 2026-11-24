class_name V10HudMatch
extends Control

# V10HudMatch — the match HUD of v2 (docs/HUD_V2.md §8.1): EXACTLY five permanent elements
#   [1] pause · [2] status line «1-2 · Осталось 30» with a 2 px progress line · [3] tray (7 cells, M lacquer 104)
#   [4] help row (3 discs, one control) · [5] the heroine in her own scene, Приём arc behind her shoulders.
# Everything else is an event: combo number (Display 64 italic), start banner (Display 44), «Ставка ×2» before
# the first move, one voice line (Caveat). Felt runs under the board edge, no frame.
#
#   var hud := V10HudMatch.new(); add_child(hud)          # full rect; re-lays out on every resize
#   hud.configure({"hero": "mc", "level": "1-2", "total": 30, "left": 30, "helpers": {"undo": 2, "hint": 3, "shuffle": 1}, "stake_offer": true})
#   hud.board_layer  -> put the board here (local origin = board_rect().position, size 688x688 at base)
#   hud.tray_cell_rect(i) -> where tray tile i goes (global)
#   hud.set_left(n) / set_helper(kind, n) / set_ult(frac) / show_combo(n) / start_banner(text) / say(text) / first_move()
#   signals: pause_pressed, helper_pressed(kind), ult_pressed, stake_pressed, hero_tapped(zone)
#   V10HudMatch.compute(viewport_size, insets) -> Dictionary of rects (pure; used by the selftest)

signal pause_pressed
signal helper_pressed(kind: String)
signal ult_pressed
signal stake_pressed
signal hero_tapped(zone: String)

const RIG_PATHS: = {"mc": "res://assets/v10/rig/mc_gown/rig.tscn"}
const RIG_BG: = {"mc": "res://assets/v10/rig/mc_gown/bg.png"}
const RIG_FACE: = Vector2(660, 230)  # rig art px (body.png): face centre
const RIG_FACE_RECT: = Rect2(560, 140, 210, 190)
const RIG_CHEST: = Vector2(650, 470)
const HELP_KINDS: = ["undo", "hint", "shuffle"]
const HELP_ICONS: = {"undo": "undo", "hint": "hint", "shuffle": "shuffle"}

var hero_id: = "mc"
var level_text: = "1-2"
var total: = 30
var left: = 30
var stake_on: = false
var helpers: = {"undo": 2, "hint": 3, "shuffle": 1}
var ult: = 0.0
var L: = {}

var board_layer: Control
var felt: ColorRect
var scene: Control
var backdrop: TextureRect
var ring: Control
var hero_holder: Control
var rig: Node2D
var hero_art: TextureRect
var scene_shade: Control
var scene_fade: Control
var tray: Control
var help_row: Control
var discs: = {}
var topbar: Control
var pause_btn: V10Button
var status_l: Label
var status_n: Label
var combo_l: Label
var banner_l: Label
var banner_scrim: Control
var stake: V10Plate
var voice_l: Label

var _shown_left: = 30.0
var _progress: = 1.0
var _tray_fill: = 0
var _combo_tw: Tween
var _banner_tw: Tween
var _voice_tw: Tween
var _hero_alpha: = 1.0


# ------------------------------------------------------------------ layout (pure)

static func compute(vs: Vector2, ins: Dictionary) -> Dictionary:
	var W: = vs.x
	var H: = vs.y
	var T: = float(ins.get("top", 0.0))
	var B: = float(ins.get("bottom", 0.0))
	var cx: = floorf(maxf(0.0, (W - 720.0) * 0.5))
	var wide: = W >= 880.0
	var d: = {"vs": vs, "T": T, "B": B, "cx": cx, "wide": wide}
	d.top_bg = Rect2(0, 0, W, T + 104)
	d.pause = Rect2(cx + 24, T + 4, 80, 80)
	d.status = Rect2(cx + 104, T + 14, 496, 40)
	d.progress = Rect2(cx + 104, T + 63, 496, 2)
	d.board = Rect2(cx + 16, T + 96, 688, 688)
	d.tray = Rect2(cx + 16, T + 792, 688, V10DS.TRAY_H)
	d.scene = Rect2(0, T + 792, W, H - (T + 792))  # clip starts under the tray: the hair may tuck under it
	d.combo = Rect2(cx + 24, T + 704, 320, 80)
	d.stake = Rect2(cx + 488, T + 736, 192, 48)
	d.banner = Rect2(cx + 24, T + 96 + 300, 672, 88)
	var help: = []
	for i in 3:
		if wide:
			help.append(Rect2(maxf(16.0, cx - 104.0), T + 96 + 688 - 3 * 96 + i * 96, 80, 80))
		else:
			help.append(Rect2(cx + 24, T + 912 + i * 96, 80, 80))
	d.help = help
	# heroine in the scene: head under the tray edge, face clear below it, scale grows with the scene height
	var scene_h: = H - (T + 896)
	var s: = clampf((scene_h + 60.0) / 820.0, 0.62, 0.95) * maxf(1.0, W / 720.0)
	var fx: = (W - 236.0) if wide else (cx + 460.0)
	var top: = T + 896 - 60.0
	d.hero_scale = s
	d.hero_pos = Vector2(fx - RIG_FACE.x * s, top)
	d.hero_face = Rect2(d.hero_pos + RIG_FACE_RECT.position * s, RIG_FACE_RECT.size * s)
	d.hero_view = Rect2(0, T + 896, W, scene_h)  # what of her is actually visible (below the tray)
	d.ring_center = d.hero_pos + RIG_CHEST * s
	d.ring_r = 236.0 * s / 0.62
	var vx: = cx + 152.0
	# one Caveat line beside her face (left of it, over the hair), never on the face, max one line
	d.voice = Rect2(vx, d.hero_face.get_center().y - 20.0, maxf(160.0, d.hero_face.position.x - 24.0 - vx), 40)
	return d


# ------------------------------------------------------------------ build

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_build()
	get_viewport().size_changed.connect(layout_now)
	layout_now()


func configure(cfg: Dictionary) -> void:
	hero_id = str(cfg.get("hero", hero_id))
	level_text = str(cfg.get("level", level_text))
	total = int(cfg.get("total", total))
	left = int(cfg.get("left", total))
	_shown_left = left
	helpers = cfg.get("helpers", helpers).duplicate()
	stake_on = bool(cfg.get("stake", false))
	if is_inside_tree():
		_build_hero()
		_refresh_status()
		for k in HELP_KINDS:
			set_helper(k, int(helpers.get(k, 0)))
		stake.visible = bool(cfg.get("stake_offer", false))
		layout_now()
	else:
		set_meta("cfg_stake_offer", bool(cfg.get("stake_offer", false)))


func _build() -> void:
	# felt (no frame): from the top to the tray's middle; the scene backdrop fades in under it
	felt = ColorRect.new()
	felt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fm: = ShaderMaterial.new()
	fm.shader = load("res://shaders/v10/hud2/felt.gdshader")
	fm.set_shader_parameter("hi", V10DS.FELT_HI)
	fm.set_shader_parameter("lo", V10DS.FELT_LO)
	felt.material = fm
	add_child(felt)
	# [5] heroine scene
	scene = Control.new()
	scene.clip_contents = true
	scene.mouse_filter = Control.MOUSE_FILTER_STOP
	scene.gui_input.connect(_scene_input)
	scene.set_meta("hud2_persistent", "hero")
	add_child(scene)
	backdrop = TextureRect.new()
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.modulate = V10DS.TINT_SCENE
	scene.add_child(backdrop)
	scene_fade = _SceneShade.new()
	scene_fade.part = "top"
	scene.add_child(scene_fade)
	ring = _Ring.new()
	ring.hud = self
	scene.add_child(ring)
	hero_holder = Control.new()
	hero_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scene.add_child(hero_holder)
	scene_shade = _SceneShade.new()
	scene_shade.part = "bottom"
	scene.add_child(scene_shade)
	# board layer (the game's board goes here)
	board_layer = Control.new()
	board_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(board_layer)
	# [3] tray
	tray = _Tray.new()
	tray.set_meta("hud2_persistent", "tray")
	add_child(tray)
	# [4] help row
	help_row = Control.new()
	help_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	help_row.set_meta("hud2_persistent", "help")
	add_child(help_row)
	for k in HELP_KINDS:
		var dsc: = _Disc.new()
		dsc.kind = k
		dsc.count = int(helpers.get(k, 0))
		dsc.pressed.connect(func() -> void: helper_pressed.emit(k))
		help_row.add_child(dsc)
		discs[k] = dsc
	# [1] + [2] top bar
	topbar = _TopBar.new()
	topbar.hud = self
	topbar.set_meta("hud2_persistent", "status")
	add_child(topbar)
	pause_btn = V10Button.make("quiet", "", Vector2(80, 80))
	pause_btn.icon = "pause"
	pause_btn.icon_px = 32
	pause_btn.icon_color = V10DS.PAPER_300
	pause_btn.pressed.connect(func() -> void: pause_pressed.emit())
	pause_btn.set_meta("hud2_persistent", "pause")
	add_child(pause_btn)
	status_l = V10Type.label("", "ui", 22, V10DS.PAPER_100)
	add_child(status_l)
	status_n = V10Type.label("", "num", 22, V10DS.PAPER_100)
	add_child(status_n)
	# events
	stake = V10Plate.make("S", 192, "Ставка ×2", "", "", "")
	stake.selected = true
	stake.interactive = true
	stake.visible = bool(get_meta("cfg_stake_offer", false))
	stake.pressed.connect(func() -> void:
		stake_on = not stake_on
		stake.title = "Ставка ×2 · вкл" if stake_on else "Ставка ×2"
		stake_pressed.emit())
	add_child(stake)
	combo_l = V10Type.label("", "display_italic", 64, V10DS.GOLD_300, true)
	combo_l.visible = false
	combo_l.clip_text = false
	add_child(combo_l)
	banner_scrim = _Scrim.new()
	banner_scrim.hud = self
	add_child(banner_scrim)
	banner_l = V10Type.label("", "display", 44, V10DS.PAPER_100, true)
	banner_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_l.visible = false
	add_child(banner_l)
	voice_l = V10Type.label("", "hand", 30, V10DS.PAPER_100, true)
	voice_l.visible = false
	add_child(voice_l)
	_build_hero()
	_refresh_status()


func _build_hero() -> void:
	if rig:
		rig.queue_free()
		rig = null
	if hero_art:
		hero_art.queue_free()
		hero_art = null
	var rp: String = RIG_PATHS.get(hero_id, "")
	if rp != "" and ResourceLoader.exists(rp):
		var r: Node2D = load(rp).instantiate()
		r.set("show_background", false)
		r.set("handle_input", false)
		r.set("motion", 0.5 if V10Hud2Util.fx_level() == "min" else 1.0)
		hero_holder.add_child(r)
		rig = r
	else:
		# fallback: the outfit card art (no alpha) as a cover in the scene
		hero_art = TextureRect.new()
		hero_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hero_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		hero_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		var ap: = "res://assets/outfits/%s_base.webp" % hero_id
		if ResourceLoader.exists(ap):
			hero_art.texture = load(ap)
		hero_holder.add_child(hero_art)
	var bp: String = RIG_BG.get(hero_id, "res://assets/v10/rig/mc_gown/bg.png")
	if ResourceLoader.exists(bp):
		backdrop.texture = load(bp)


# ------------------------------------------------------------------ layout

func layout_now() -> void:
	if not is_instance_valid(felt):
		return
	var vs: = get_viewport_rect().size
	L = compute(vs, V10Hud2Util.safe_insets(vs))
	var tr: Rect2 = L.tray
	felt.position = Vector2.ZERO
	felt.size = Vector2(vs.x, tr.position.y + tr.size.y * 0.5)
	(felt.material as ShaderMaterial).set_shader_parameter("size_px", felt.size)
	var sc: Rect2 = L.scene
	scene.position = sc.position
	scene.size = sc.size
	backdrop.position = Vector2(0, 52)
	backdrop.size = Vector2(sc.size.x, sc.size.y - 52)
	ring.position = Vector2.ZERO
	ring.size = sc.size
	hero_holder.position = Vector2.ZERO
	hero_holder.size = sc.size
	scene_shade.position = Vector2.ZERO
	scene_shade.size = sc.size
	scene_fade.position = Vector2.ZERO
	scene_fade.size = sc.size
	scene_fade.queue_redraw()
	var hp: Vector2 = L.hero_pos - sc.position
	if rig:
		rig.position = hp
		rig.scale = Vector2.ONE * float(L.hero_scale)
	elif hero_art:
		var hv: Rect2 = L.hero_view
		hero_art.position = Vector2(hv.position.x + hv.size.x * 0.3, hv.position.y - sc.position.y)
		hero_art.size = Vector2(hv.size.x * 0.7, hv.size.y)
	var br: Rect2 = L.board
	board_layer.position = br.position
	board_layer.size = br.size
	tray.position = tr.position
	tray.size = tr.size
	help_row.position = Vector2.ZERO
	help_row.size = vs
	for i in HELP_KINDS.size():
		var dsc: Control = discs[HELP_KINDS[i]]
		var r: Rect2 = L.help[i]
		dsc.position = r.position
		dsc.size = Vector2(160, 80)
	topbar.position = Vector2.ZERO
	topbar.size = (L.top_bg as Rect2).size
	pause_btn.position = (L.pause as Rect2).position
	_place_status()
	stake.position = (L.stake as Rect2).position
	combo_l.position = (L.combo as Rect2).position
	combo_l.size = (L.combo as Rect2).size
	banner_l.position = (L.banner as Rect2).position
	banner_l.size = (L.banner as Rect2).size
	banner_scrim.position = Vector2(0, (L.banner as Rect2).position.y - 48.0)
	banner_scrim.size = Vector2(vs.x, (L.banner as Rect2).size.y + 96.0)
	voice_l.position = (L.voice as Rect2).position
	voice_l.size = (L.voice as Rect2).size
	ring.queue_redraw()
	topbar.queue_redraw()
	scene_shade.queue_redraw()


func _place_status() -> void:
	var r: Rect2 = L.get("status", Rect2(104, 14, 496, 40))
	var s1: = status_l.text
	var w1: = V10Type.text_w(s1, "ui", 22)
	status_l.position = r.position
	status_l.size = Vector2(minf(w1 + 2.0, r.size.x - 64.0), r.size.y)
	status_n.position = Vector2(r.position.x + status_l.size.x + 6.0, r.position.y)
	status_n.size = Vector2(64, r.size.y)


func _refresh_status() -> void:
	var parts: = [level_text]
	if stake_on:
		parts.append("×2")
	parts.append("Осталось")
	status_l.text = " · ".join(parts)
	status_n.text = str(int(round(_shown_left)))
	_progress = 1.0 - float(left) / maxf(1.0, float(total))
	if is_instance_valid(topbar):
		topbar.set("progress", _progress)
		topbar.queue_redraw()
	if not L.is_empty():
		_place_status()


# ------------------------------------------------------------------ API

func board_rect() -> Rect2:
	return L.get("board", Rect2(16, 96, 688, 688))


func center_zone() -> Rect2:
	var b: = board_rect()
	return Rect2(b.position + b.size * 0.2, b.size * 0.6)


func tray_cell_rect(i: int) -> Rect2:
	var t: Rect2 = L.get("tray", Rect2(16, 792, 688, 104))
	return Rect2(t.position + Vector2(8 + i * 96 + 8, 4), Vector2(80, 96))


func combo_anchor() -> Rect2:
	return L.get("combo", Rect2(24, 704, 320, 80))


func hero_face_global() -> Rect2:
	return L.get("hero_face", Rect2())


func set_tray_fill(n: int) -> void:
	_tray_fill = n
	tray.set("fill", n)
	tray.queue_redraw()


func set_left(n: int) -> void:
	var from: = _shown_left
	left = n
	var tw: = create_tween().set_parallel(true)
	var dur: = 0.12 if absi(int(from) - n) <= 1 else V10DS.T_ROLL
	tw.tween_method(func(v: float) -> void:
		_shown_left = v
		status_n.text = str(int(round(v))), from, float(n), dur).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	var p_to: = 1.0 - float(n) / maxf(1.0, float(total))
	var back: = p_to < _progress
	tw.tween_method(func(v: float) -> void:
		_progress = v
		topbar.set("progress", v)
		topbar.queue_redraw(), _progress, p_to, 0.2 if back else V10DS.T_PROGRESS).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)


func set_helper(kind: String, n: int) -> void:
	helpers[kind] = n
	if discs.has(kind):
		discs[kind].set("count", n)
		discs[kind].queue_redraw()


func set_ult(frac: float) -> void:
	var was: = ult >= 1.0
	ult = clampf(frac, 0.0, 1.0)
	ring.set("ready_t", 0.0 if (ult >= 1.0 and not was) else ring.get("ready_t"))
	ring.queue_redraw()


func show_combo(n: int, hold: = 0.36) -> void:
	# §6: Display 64 italic gold.300, 120 in (scale 1.15→1, BACK_OUT) + hold + 120 out; a new number replaces the old
	if _combo_tw:
		_combo_tw.kill()
	combo_l.text = "×%d" % n
	combo_l.visible = true
	combo_l.pivot_offset = Vector2(0, 40)
	var minfx: = V10Hud2Util.fx_level() == "min"
	combo_l.scale = Vector2.ONE if minfx else Vector2.ONE * 1.15
	combo_l.modulate.a = 0.0
	_combo_tw = create_tween()
	_combo_tw.set_parallel(true)
	_combo_tw.tween_property(combo_l, "modulate:a", 1.0, 0.12)
	if not minfx:
		_combo_tw.tween_property(combo_l, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_combo_tw.chain().tween_interval(hold)
	_combo_tw.chain().tween_property(combo_l, "modulate:a", 0.0, 0.12)
	_combo_tw.chain().tween_callback(func() -> void: combo_l.visible = false)


func start_banner(text: String) -> void:
	if _banner_tw:
		_banner_tw.kill()
	banner_l.text = text
	V10Type.fit(banner_l, text, "title_l", 672.0, 1, V10DS.PAPER_100, true)
	banner_l.label_settings = V10Type.settings("display", 44, V10DS.PAPER_100, true)
	banner_l.visible = true
	banner_l.modulate.a = 0.0
	banner_l.position.y = (L.banner as Rect2).position.y + 12
	_banner_tw = create_tween()
	_banner_tw.set_parallel(true)
	_banner_tw.tween_property(banner_l, "modulate:a", 1.0, 0.16).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	_banner_tw.tween_property(banner_l, "position:y", (L.banner as Rect2).position.y, 0.16).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	_banner_tw.chain().tween_interval(0.48)
	_banner_tw.chain().tween_property(banner_l, "modulate:a", 0.0, 0.16).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
	_banner_tw.chain().tween_callback(func() -> void: banner_l.visible = false)


func say(text: String, secs: = 4.0) -> void:
	if _voice_tw:
		_voice_tw.kill()
	voice_l.text = text
	voice_l.visible = true
	voice_l.modulate.a = 0.0
	_voice_tw = create_tween()
	_voice_tw.tween_property(voice_l, "modulate:a", 1.0, 0.24)
	_voice_tw.tween_interval(secs)
	_voice_tw.tween_property(voice_l, "modulate:a", 0.0, 0.24)
	_voice_tw.tween_callback(func() -> void: voice_l.visible = false)
	if rig and rig.has_method("talk"):
		rig.call("talk", minf(secs, 1.6))


func first_move() -> void:
	if stake.visible:
		var tw: = create_tween()
		tw.tween_property(stake, "modulate:a", 0.0, V10DS.T_OUT)
		tw.tween_callback(func() -> void: stake.visible = false)
	_refresh_status()


func hero_show(on: bool, t: = 0.2) -> void:
	# the combo showcase «grows her out of her scene»: the scene figure steps back while the big one is on
	var tw: = create_tween().set_parallel(true)
	tw.tween_property(hero_holder, "modulate:a", 1.0 if on else 0.0, t)
	tw.tween_property(ring, "modulate:a", 1.0 if on else 0.0, t)


func persistent_nodes() -> Array:
	var out: = []
	for c in get_children():
		if c.has_meta("hud2_persistent"):
			out.append(c)
	return out


func _scene_input(e: InputEvent) -> void:
	var p: = false
	var pos: = Vector2.ZERO
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		p = true
		pos = e.position
	elif e is InputEventScreenTouch and e.pressed:
		p = true
		pos = e.position
	if not p:
		return
	if ult >= 1.0:
		ult_pressed.emit()
		return
	var gp: = scene.get_global_transform() * pos
	var zone: = "none"
	if rig and rig.has_method("tap"):
		zone = str(rig.call("tap", gp))
	hero_tapped.emit(zone)


# ------------------------------------------------------------------ parts

class _TopBar:
	extends Control
	var hud: V10HudMatch
	var progress: = 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		# night.900 α 0.85 → 0 downwards, no plate, no line
		var h: = size.y
		var c0: = Color(V10DS.NIGHT_900, 0.85)
		var c1: = Color(V10DS.NIGHT_900, 0.0)
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(size.x, 0), Vector2(size.x, h), Vector2(0, h)]),
				PackedColorArray([c0, c0, c1, c1]))
		var r: Rect2 = hud.L.get("progress", Rect2(104, 63, 496, 2))
		draw_rect(r, V10DS.NIGHT_600)
		draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(progress, 0.0, 1.0), r.size.y)), V10DS.JADE_300)


class _Tray:
	extends Control
	var fill: = 0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		V10Plate.draw_surface(self, Rect2(Vector2.ZERO, size), true)
		for i in range(1, 7):
			var x: = 8.0 + i * 96.0
			draw_line(Vector2(x, 14), Vector2(x, size.y - 14), V10DS.NIGHT_600, 1.0)
		if fill == 6:  # the last free cell: ember tone on the bottom
			var x0: = 8.0 + 6 * 96.0
			var c0: = Color(V10DS.EMBER, 0.0)
			var c1: = Color(V10DS.EMBER, 0.32)
			draw_polygon(PackedVector2Array([Vector2(x0 + 2, size.y * 0.45), Vector2(x0 + 94, size.y * 0.45), Vector2(x0 + 94, size.y - 3), Vector2(x0 + 2, size.y - 3)]),
					PackedColorArray([c0, c0, c1, c1]))


class _Disc:
	extends Control
	signal pressed
	var kind: = "undo"
	var count: = 0
	var _down: = false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _draw() -> void:
		var c: = Vector2(40, 40)
		var a: = 0.5 if count <= 0 else 1.0
		draw_circle(c, 32, Color(V10DS.NIGHT_600 if _down else V10DS.NIGHT_800, 0.9 * a), true, -1.0, true)
		V10Icons.draw(self, V10HudMatch.HELP_ICONS[kind], c, 32, Color(V10DS.PAPER_300, a))
		var f: = V10Type.font("num")
		var t: = str(count) if count > 0 else "+"
		var asc: = f.get_ascent(22)
		var desc: = f.get_descent(22)
		draw_string(f, Vector2(84, c.y + (asc - desc) * 0.5), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, V10DS.PAPER_100)

	func _gui_input(e: InputEvent) -> void:
		if not ((e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT) or e is InputEventScreenTouch):
			return
		if not Rect2(0, 0, 80, 80).has_point(e.position) and e.pressed:
			return
		if e.pressed:
			_down = true
			pivot_offset = Vector2(40, 40)
			scale = Vector2.ONE * 0.94
		elif _down:
			_down = false
			create_tween().tween_property(self, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			pressed.emit()
		queue_redraw()
		accept_event()


class _Ring:
	extends Control
	var hud: V10HudMatch
	var ready_t: = 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		if hud and float(hud.get("ult")) >= 1.0 and ready_t < 0.6:
			ready_t += delta
			queue_redraw()

	func _draw() -> void:
		if hud == null or hud.L.is_empty():
			return
		var col: Color = V10DS.hero(hud.hero_id).accent
		var c: Vector2 = hud.L.ring_center - hud.L.scene.position
		var r: float = hud.L.ring_r
		var a0: = deg_to_rad(170.0)
		var a1: = deg_to_rad(370.0)
		draw_arc(c, r, a0, a1, 96, Color(V10DS.NIGHT_600, 0.55), 2.0, true)
		var u: float = hud.ult
		if u > 0.0:
			draw_arc(c, r, a0, lerpf(a0, a1, u), 96, Color(col, 0.9), 2.0, true)
		if u >= 1.0:
			# one 600 ms breath of light, then a quiet glow without pulse
			var k: = sin(clampf(ready_t / 0.6, 0.0, 1.0) * PI)
			draw_arc(c, r, a0, a1, 96, Color(col, 0.18 + 0.3 * k), 8.0 + 10.0 * k, true)


class _SceneShade:
	extends Control
	# top (under the heroine): felt fades into the scene under the tray;
	# bottom (over her): lacquer edge night.900 α 0 → 0.7 over the last 80 px
	var part: = "bottom"

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var w: = size.x
		var h: = size.y
		if part == "top":
			var f0: = Color(V10DS.FELT_LO, 1.0)
			var f1: = Color(V10DS.FELT_LO, 0.0)
			draw_polygon(PackedVector2Array([Vector2(0, 52), Vector2(w, 52), Vector2(w, 172), Vector2(0, 172)]), PackedColorArray([f0, f0, f1, f1]))
			return
		var b0: = Color(V10DS.NIGHT_900, 0.0)
		var b1: = Color(V10DS.NIGHT_900, 0.7)
		draw_polygon(PackedVector2Array([Vector2(0, h - 80), Vector2(w, h - 80), Vector2(w, h), Vector2(0, h)]), PackedColorArray([b0, b0, b1, b1]))


class _Scrim:
	extends Control
	# a soft night band behind the start banner so Display 44 reads over the tiles (a tone, not a plate)
	var hud: V10HudMatch

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_d: float) -> void:
		var a: = hud.banner_l.modulate.a if hud.banner_l.visible else 0.0
		if not is_equal_approx(modulate.a, a):
			modulate.a = a
			queue_redraw()

	func _draw() -> void:
		var w: = size.x
		var h: = size.y
		var c0: = Color(V10DS.NIGHT_900, 0.0)
		var c1: = Color(V10DS.NIGHT_900, 0.72)
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h * 0.5), Vector2(0, h * 0.5)]), PackedColorArray([c0, c0, c1, c1]))
		draw_polygon(PackedVector2Array([Vector2(0, h * 0.5), Vector2(w, h * 0.5), Vector2(w, h), Vector2(0, h)]), PackedColorArray([c1, c1, c0, c0]))
