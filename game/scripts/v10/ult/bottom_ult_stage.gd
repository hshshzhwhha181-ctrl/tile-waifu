class_name V10BottomUltStage
extends V6HeroStage

const CUTOUT_DIR: = "res://assets/v10/hud2/combo/"
const PILL_W: = 188.0
const PILL_H: = 42.0
const PILL_PAD_X: = 18.0
const PILL_PAD_Y: = 16.0

var _frac: = 0.0
var _pulse_t: = 0.0
var _breath_t: = 0.0
var _ready_t: = 0.0

var _clip: Control
var _ring_back: Control
var _hero_pivot: Control
var _hero_tex: TextureRect
var _bottom_shade: Control
var _cta_box: Control
var _ult_lbl: Label
var _badge_pill: Control
var _caption_box: Control

var _pose_tier: = 1
var _hero_transparent: = true
var _hero_face_tex: = Rect2()
var _hero_base_pos: = Vector2.ZERO
var _hero_base_sz: = Vector2.ZERO
var _ring_center: = Vector2.ZERO
var _ring_r: = 160.0
var _react_scale: = 1.0
var _react_y: = 0.0
var _react_rot: = 0.0
var _react_tw: Tween
var _charge_tw: Tween
var _last_gauge_txt: = ""

static var _meta_cache: Dictionary = {}
static var _meta_loaded: = false
static var _soft_fade_shader: Shader


func setup_bottom(id: String, rect: Rect2, opts: = {}) -> V10BottomUltStage:
	hero_id = id if G.HEROES.has(id) else "mc"
	position = rect.position
	size = rect.size
	compact = false
	col = G.HEROES[hero_id].color
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = false
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	pivot_offset = size * 0.5
	_build_bottom_widget(opts)
	emote_layer = Node2D.new()
	emote_layer.z_index = 12
	add_child(emote_layer)
	gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			pressed.emit())
	return self


func _has_point(p: Vector2) -> bool:
	# Leave the left 24 percent column open for the helper circles; accept taps on the heroine or Priem pill
	return p.x >= size.x * 0.22 and Rect2(Vector2.ZERO, size).has_point(p)


func _build_bottom_widget(_opts: Dictionary) -> void:
	_clip = Control.new()
	_clip.name = "HeroClip"
	_clip.position = Vector2.ZERO
	_clip.size = size
	_clip.clip_contents = true
	_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_clip)

	var bg_fade: = Control.new()
	bg_fade.name = "SceneVignette"
	bg_fade.position = Vector2.ZERO
	bg_fade.size = size
	bg_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_fade.draw.connect(func() -> void:
		var c0: = Color(V10DS.NIGHT_900, 0.22)
		var c1: = Color(V10DS.NIGHT_900, 0.78)
		bg_fade.draw_polygon(
			PackedVector2Array([Vector2(0, 0), Vector2(size.x, 0), Vector2(size.x, size.y), Vector2(0, size.y)]),
			PackedColorArray([c0, c0, c1, c1])
		))
	_clip.add_child(bg_fade)

	halo = Sprite2D.new()
	halo.texture = G.fx("glow")
	halo.material = Fx.add_mat()
	halo.modulate = Color(col.r, col.g, col.b, 0.26)
	_clip.add_child(halo)

	_ring_back = Control.new()
	_ring_back.name = "HaloRing"
	_ring_back.position = Vector2.ZERO
	_ring_back.size = size
	_ring_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring_back.draw.connect(_draw_halo_ring)
	_clip.add_child(_ring_back)

	_hero_pivot = Control.new()
	_hero_pivot.name = "HeroPivot"
	_hero_pivot.position = Vector2.ZERO
	_hero_pivot.size = size
	_hero_pivot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clip.add_child(_hero_pivot)

	_hero_tex = TextureRect.new()
	_hero_tex.name = "HeroArt"
	_hero_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hero_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_hero_tex.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_hero_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hero_pivot.add_child(_hero_tex)

	_bottom_shade = Control.new()
	_bottom_shade.name = "BottomShade"
	_bottom_shade.position = Vector2.ZERO
	_bottom_shade.size = size
	_bottom_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bottom_shade.draw.connect(_draw_bottom_shade)
	_clip.add_child(_bottom_shade)

	_set_hero_pose(1)

	# Sleek HUD_V2 lacquer pill in the bottom-right corner
	_cta_box = Control.new()
	_cta_box.name = "UltPlaque"
	_cta_box.position = Vector2(size.x - PILL_W - PILL_PAD_X, size.y - PILL_H - PILL_PAD_Y)
	_cta_box.size = Vector2(PILL_W, PILL_H)
	_cta_box.pivot_offset = _cta_box.size * 0.5
	_cta_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cta_box.z_index = 8
	_cta_box.draw.connect(_draw_plaque)
	add_child(_cta_box)

	_ult_lbl = Label.new()
	_ult_lbl.text = "Приём · 0/8"
	_ult_lbl.label_settings = V10Type.settings("ui", 18, V10DS.PAPER_100, false)
	_ult_lbl.position = Vector2(12.0, 0.0)
	_ult_lbl.size = Vector2(PILL_W - 24.0, PILL_H)
	_ult_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ult_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_ult_lbl.clip_text = true
	_ult_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_ult_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cta_box.add_child(_ult_lbl)

	# Keep gauge_lbl populated with "умение N/M" (hidden) so V9UltSelftest and tower_play._fix_stage_text stay compatible
	gauge_lbl = UI.label("умение 0/8", 16, Color.WHITE)
	gauge_lbl.visible = false
	add_child(gauge_lbl)

	_sparks = Fx.particles("sparkle", 14, 1.0)
	_sparks.material = Fx.add_mat()
	_sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_sparks.emission_sphere_radius = maxf(64.0, _ring_r * 0.55)
	_sparks.position = _ring_center
	_sparks.direction = Vector2(0, -1)
	_sparks.spread = 38.0
	_sparks.gravity = Vector2(0, -40)
	_sparks.initial_velocity_min = 14.0
	_sparks.initial_velocity_max = 46.0
	_sparks.scale_amount_min = 0.14
	_sparks.scale_amount_max = 0.30
	_sparks.color = V10DS.GOLD_300
	_sparks.emitting = false
	_clip.add_child(_sparks)


static func _combo_meta() -> Dictionary:
	if not _meta_loaded:
		_meta_loaded = true
		var p: = CUTOUT_DIR + "combo_meta.json"
		if FileAccess.file_exists(p):
			var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(p))
			if d is Dictionary:
				_meta_cache = d.get("sprites", {})
	return _meta_cache


static func _edge_fade_shader() -> Shader:
	if _soft_fade_shader == null:
		_soft_fade_shader = Shader.new()
		_soft_fade_shader.code = """shader_type canvas_item;
uniform float bot_fade = 0.14;
uniform float side_fade = 0.0;
void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	float a = 1.0;
	if (bot_fade > 0.0) {
		a *= smoothstep(1.0, 1.0 - bot_fade, UV.y);
	}
	if (side_fade > 0.0) {
		a *= smoothstep(0.0, side_fade, UV.x) * smoothstep(1.0, 1.0 - side_fade, UV.x);
		a *= smoothstep(0.0, side_fade * 0.6, UV.y);
	}
	COLOR = vec4(c.rgb, c.a * a);
}"""
	return _soft_fade_shader


func _resolve_hero_art(pose_tier: int) -> Dictionary:
	var eq: = G.equipped(hero_id)
	var eq_img: = ""
	if eq != "" and G.ITEM.has(eq):
		var it: Dictionary = G.ITEM[eq]
		eq_img = G.item_img(it)
		if bool(G.S.get("modest", false)) and (bool(it.get("bold", false)) or not bool(it.get("sfw", true))) and it.has("alt"):
			eq_img = String(it.alt)

	# 1. Founders (and any hero with 2K transparent combo cutouts)
	var cands: Array[String] = []
	for tt in range(pose_tier, 0, -1):
		if eq_img != "":
			cands.append("%s%s_%s_t%d.png" % [CUTOUT_DIR, hero_id, eq_img, tt])
		cands.append("%s%s_t%d.png" % [CUTOUT_DIR, hero_id, tt])
	for cand in cands:
		if ResourceLoader.exists(cand):
			var tex: = load(cand) as Texture2D
			if tex != null:
				var tsz: = tex.get_size()
				var face: = Rect2(tsz.x * 0.36, tsz.y * 0.08, tsz.x * 0.28, tsz.y * 0.16)
				var m: Dictionary = _combo_meta().get(cand.get_file().get_basename(), {})
				if m.has("face") and (m.face as Array).size() >= 4:
					face = Rect2(float(m.face[0]), float(m.face[1]), float(m.face[2]), float(m.face[3]))
				return {"tex": tex, "face": face, "transparent": true}

	# 2. Wave-1 full-body transparent PNG cutouts (or founder base hero PNG)
	var hp: = V10W1Core.hero_png(hero_id)
	if ResourceLoader.exists(hp):
		var htex: = load(hp) as Texture2D
		if htex != null:
			var hsz: = htex.get_size()
			var rdata: Dictionary = V10W1Core.rig(hero_id) if V10W1Core.is_wave1_hero(hero_id) else Hero.RIGS.get(hero_id, {})
			var hc: Vector2 = rdata.get("head_c", Vector2(hsz.x * 0.5, hsz.y * 0.16))
			var hr: float = float(rdata.get("head_r", hsz.x * 0.12))
			var face2: = Rect2(hc.x - hr, hc.y - hr, hr * 2.0, hr * 2.0)
			return {"tex": htex, "face": face2, "transparent": true}

	# 3. Pose webp or outfit webp fallback (softly feathered edges)
	var wp_cands: Array[String] = []
	if pose_tier >= 2:
		wp_cands.append("res://assets/v10/wave1/poses/%s_win.webp" % hero_id)
	wp_cands.append("res://assets/v10/wave1/poses/%s_idle.webp" % hero_id)
	if eq_img != "":
		wp_cands.append(V10W1Core.outfit_webp(eq_img))
	wp_cands.append(V10W1Core.outfit_webp("%s_base" % hero_id))
	for wp in wp_cands:
		if wp != "" and ResourceLoader.exists(wp):
			var wtex: = load(wp) as Texture2D
			if wtex != null:
				var wsz: = wtex.get_size()
				var face3: = Rect2(wsz.x * 0.36, wsz.y * 0.10, wsz.x * 0.28, wsz.y * 0.16)
				return {"tex": wtex, "face": face3, "transparent": false}

	return {}


func _set_hero_pose(pose_tier: int) -> void:
	if _hero_tex == null:
		return
	_pose_tier = pose_tier
	var info: = _resolve_hero_art(pose_tier)
	if info.is_empty():
		return
	_hero_tex.texture = info.tex
	_hero_face_tex = info.face
	_hero_transparent = bool(info.transparent)
	var sm: = ShaderMaterial.new()
	sm.shader = _edge_fade_shader()
	sm.set_shader_parameter("bot_fade", 0.10 if _hero_transparent else 0.18)
	sm.set_shader_parameter("side_fade", 0.0 if _hero_transparent else 0.14)
	_hero_tex.material = sm
	_layout_hero()


func _layout_hero() -> void:
	if _hero_tex == null or _hero_tex.texture == null:
		return
	var tsz: = _hero_tex.texture.get_size()
	if tsz.x <= 1.0 or tsz.y <= 1.0:
		return
	var fc: = _hero_face_tex.get_center()
	# Framing: half-body to thigh on tall 20:9 screens (~0.62 of figure height), chest-up on compact 9:16 (~0.45)
	var vis_frac: = clampf(lerpf(0.44, 0.62, clampf((size.y - 360.0) / 240.0, 0.0, 1.0)), 0.42, 0.66)
	var s: = (size.y - 10.0) / maxf(1.0, tsz.y * vis_frac)
	s = minf(s, (size.x * 0.98) / maxf(1.0, tsz.x * 0.72))
	var draw_sz: = tsz * s

	var face_target_x: = size.x * 0.65
	var face_target_y: = clampf(size.y * 0.28, 92.0, 174.0)
	var px: = face_target_x - fc.x * s
	var py: = maxf(12.0, face_target_y - fc.y * s)
	# Keep sprite face comfortably inside the right showcase side horizontally
	var face_screen_x: = px + fc.x * s
	if face_screen_x < size.x * 0.48:
		px += size.x * 0.48 - face_screen_x
	elif face_screen_x > size.x * 0.78:
		px -= face_screen_x - size.x * 0.78

	_hero_base_pos = Vector2(px, py)
	_hero_base_sz = draw_sz
	_hero_tex.position = _hero_base_pos
	_hero_tex.size = _hero_base_sz
	_hero_pivot.pivot_offset = Vector2(px + fc.x * s, size.y)

	# Shoulder-centered halo behind her upper chest & head
	var face_h: = _hero_face_tex.size.y * s
	_ring_center = Vector2(px + fc.x * s, py + fc.y * s + face_h * 0.65)
	_ring_r = clampf(size.y * 0.34, 126.0, 208.0)

	if halo:
		halo.position = _ring_center
		var hs: = (_ring_r * 2.3) / 128.0
		halo.scale = Vector2(hs, hs)
	if _sparks:
		_sparks.position = _ring_center
		_sparks.emission_sphere_radius = maxf(60.0, _ring_r * 0.55)
	if _ring_back:
		_ring_back.queue_redraw()


func _draw_halo_ring() -> void:
	if _ring_back == null:
		return
	var c: = _ring_center
	var r: = _ring_r
	var a0: = deg_to_rad(148.0)
	var a1: = deg_to_rad(392.0)

	var hero_c: Color = V10DS.hero(hero_id).accent
	var rose_gold: = hero_c.lerp(V10DS.GOLD_300, 0.45)

	# Delicate glowing track & inner ring behind her shoulders (always softly visible like 01_match.webp)
	_ring_back.draw_arc(c, r, a0, a1, 96, Color(rose_gold, 0.22), 10.0, true)
	_ring_back.draw_arc(c, r, a0, a1, 96, Color(V10DS.GOLD_300, 0.45), 2.2, true)
	_ring_back.draw_arc(c, r - 6.0, a0 + 0.12, a1 - 0.12, 72, Color(rose_gold, 0.20), 1.0, true)

	if _frac > 0.005:
		var end_a: = lerpf(a0, a1, _frac)
		var breath: = 0.86 + 0.14 * sin(_pulse_t * 3.4) if is_ready else 1.0
		var bloom_w: = 16.0 if is_ready else 11.0
		var bloom_a: = (0.44 if is_ready else 0.28) * breath
		_ring_back.draw_arc(c, r, a0, end_a, 96, Color(rose_gold, bloom_a), bloom_w, true)
		_ring_back.draw_arc(c, r, a0, end_a, 96, Color(rose_gold.lightened(0.32), 0.96 * breath), 3.2, true)

		if _frac < 0.995:
			var tip: = c + Vector2(cos(end_a), sin(end_a)) * r
			_ring_back.draw_circle(tip, 7.5, Color(rose_gold, 0.35), true, -1.0, true)
			_ring_back.draw_circle(tip, 3.2, Color(V10DS.PAPER_100, 0.95), true, -1.0, true)

	if is_ready and _ready_t < 0.7:
		var k: = sin(clampf(_ready_t / 0.7, 0.0, 1.0) * PI)
		_ring_back.draw_arc(c, r, a0, a1, 96, Color(V10DS.GOLD_300, 0.36 * k), 16.0 + 10.0 * k, true)


func _draw_bottom_shade() -> void:
	if _bottom_shade == null:
		return
	var w: = _bottom_shade.size.x
	var h: = _bottom_shade.size.y
	var y0: = maxf(0.0, h - 76.0)
	var c0: = Color(V10DS.NIGHT_900, 0.0)
	var c1: = Color(V10DS.NIGHT_900, 0.72)
	_bottom_shade.draw_polygon(
		PackedVector2Array([Vector2(0, y0), Vector2(w, y0), Vector2(w, h), Vector2(0, h)]),
		PackedColorArray([c0, c0, c1, c1])
	)


func _draw_plaque() -> void:
	if _cta_box == null:
		return
	var r: = Rect2(Vector2.ZERO, _cta_box.size)
	var rad: = 4.0
	var fill_c: = Color(V10DS.PLATE_SEL_TOP, 0.94) if is_ready else Color(V10DS.NIGHT_800, 0.90)
	var pts: = V10Button.rr_pts(r, rad, 6)
	_cta_box.draw_colored_polygon(pts, fill_c)

	# Subtle top lacquer sheen on top 40 percent
	var lh: = r.size.y * 0.42
	var s0: = Color(V10DS.PAPER_100, 0.08 if is_ready else 0.05)
	var s1: = Color(V10DS.PAPER_100, 0.0)
	_cta_box.draw_polygon(
		PackedVector2Array([Vector2(2, 1), Vector2(r.size.x - 2, 1), Vector2(r.size.x - 2, lh), Vector2(2, lh)]),
		PackedColorArray([s0, s0, s1, s1])
	)

	# 1px bottom depth tone (not a border)
	_cta_box.draw_line(Vector2(rad, r.size.y - 1.0), Vector2(r.size.x - rad, r.size.y - 1.0), Color(V10DS.NIGHT_900, 0.65), 1.0)

	# ONE 1px hairline gold top line
	var hair_c: = Color(V10DS.GOLD_300, 0.95) if is_ready else Color(V10DS.GOLD_700, 0.55)
	V10Plate.hairline(_cta_box, 10.0, r.size.x - 10.0, 0.5, hair_c)


func _process(dt: float) -> void:
	_breath_t += dt
	if is_ready:
		_pulse_t += dt
		_ready_t = minf(1.0, _ready_t + dt)
		if _ring_back:
			_ring_back.queue_redraw()
	if _hero_pivot and is_instance_valid(_hero_pivot):
		var breath_scale: = 1.0 + 0.008 * sin(_breath_t * 1.8)
		var breath_y: = 2.0 * sin(_breath_t * 1.8 - 0.5)
		var sway_r: = 0.006 * sin(_breath_t * 1.05)
		_hero_pivot.scale = Vector2.ONE * (breath_scale * _react_scale)
		_hero_pivot.position = Vector2(0.0, breath_y + _react_y)
		_hero_pivot.rotation = sway_r + _react_rot
	if gauge_lbl and gauge_lbl.text != _last_gauge_txt:
		_last_gauge_txt = gauge_lbl.text
		_sync_pill_text()


func _sync_pill_text() -> void:
	if _ult_lbl == null:
		return
	if gauge_lbl and gauge_lbl.text == "без приёма":
		_ult_lbl.text = "Без приёма"
		_ult_lbl.label_settings = V10Type.settings("ui", 18, V10DS.PAPER_500, false)
	elif is_ready or charge >= need:
		_ult_lbl.text = "Приём готов ✦"
		_ult_lbl.label_settings = V10Type.settings("ui", 18, V10DS.GOLD_300, false)
	else:
		_ult_lbl.text = "Приём · %d/%d" % [charge, need]
		_ult_lbl.label_settings = V10Type.settings("ui", 18, V10DS.PAPER_100, false)


func head_pos() -> Vector2:
	if _hero_tex and _hero_tex.texture:
		return position + _hero_base_pos + _hero_face_tex.get_center() * (_hero_base_sz.x / maxf(1.0, _hero_tex.texture.get_size().x))
	return position + Vector2(size.x * 0.56, size.y * 0.25)


func hand_pos() -> Vector2:
	return position + _ring_center


func absorb(from: Vector2) -> void:
	var p: = get_parent()
	if p == null:
		return
	var s: = Sprite2D.new()
	s.texture = G.fx("sparkle")
	s.material = Fx.add_mat()
	s.modulate = col.lightened(0.4).lerp(V10DS.GOLD_300, 0.35)
	s.scale = Vector2(0.32, 0.32)
	s.z_index = 41
	s.position = from
	p.add_child(s)
	var to: = position + _ring_center
	var ctrl: = from.lerp(to, 0.5) + Vector2(54, -70)
	var t: = s.create_tween()
	t.tween_method(func(v: float) -> void:
		if is_instance_valid(s):
			s.position = from.lerp(ctrl, v).lerp(ctrl.lerp(to, v), v), 0.0, 1.0, 0.40).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(s, "rotation", 4.0, 0.40)
	t.tween_callback(s.queue_free)


func set_charge(cur: int, total: int) -> void:
	charge = cur
	need = maxi(1, total)
	var f: = clampf(float(cur) / float(need), 0.0, 1.0)
	if _charge_tw and _charge_tw.is_valid():
		_charge_tw.kill()
	_charge_tw = create_tween()
	_charge_tw.tween_method(func(v: float) -> void:
		_frac = v
		if _ring_back:
			_ring_back.queue_redraw(), _frac, f, 0.28).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	if gauge_lbl:
		gauge_lbl.text = "УМЕНИЕ!" if cur >= need else "умение %d/%d" % [cur, need]
		_last_gauge_txt = gauge_lbl.text
	if cur >= need and not is_ready:
		_set_ready(true)
	elif cur < need and is_ready:
		_set_ready(false)
	_sync_pill_text()
	if _cta_box:
		_cta_box.queue_redraw()


func _set_ready(on: bool) -> void:
	is_ready = on
	_ready_t = 0.0
	if _ready_tw:
		_ready_tw.kill()
		_ready_tw = null
	if _sparks:
		_sparks.emitting = on and V9Feel.can_fx()
	if on:
		if halo:
			halo.modulate = Color(col.r * 0.6 + 0.4, col.g * 0.5 + 0.35, col.b * 0.5 + 0.2, 0.42)
		_set_hero_pose(2)
		_bounce_hero(1.045, -8.0, 0.0)
		emote("star")
	else:
		if halo:
			halo.modulate = Color(col.r, col.g, col.b, 0.22)
		_set_hero_pose(1)
	if _ring_back:
		_ring_back.queue_redraw()
	if _cta_box:
		_cta_box.queue_redraw()


func _bounce_hero(to_scale: float, dy: float, rot: float) -> void:
	if _react_tw and _react_tw.is_valid():
		_react_tw.kill()
	_react_tw = create_tween().set_parallel(true)
	_react_tw.tween_method(func(v: float) -> void: _react_scale = v, _react_scale, to_scale, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_react_tw.tween_method(func(v: float) -> void: _react_y = v, _react_y, dy, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_react_tw.tween_method(func(v: float) -> void: _react_rot = v, _react_rot, rot, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var ch: = _react_tw.chain().set_parallel(true)
	ch.tween_method(func(v: float) -> void: _react_scale = v, to_scale, 1.0, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	ch.tween_method(func(v: float) -> void: _react_y = v, dy, 0.0, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	ch.tween_method(func(v: float) -> void: _react_rot = v, rot, 0.0, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func react(kind: String) -> void:
	match kind:
		"match":
			_bounce_hero(1.022, -4.0, -0.01)
		"combo":
			_bounce_hero(1.04, -8.0, -0.015)
			if randf() < 0.45:
				emote("star")
		"big":
			_bounce_hero(1.06, -12.0, 0.015)
			emote("heart")
		"deny", "fail":
			_bounce_hero(0.98, 4.0, 0.025)
			emote("sweat" if kind == "deny" else "dots")
		"danger":
			_bounce_hero(0.99, 3.0, -0.02)
			emote("bang")
		"smug":
			_bounce_hero(1.035, -6.0, -0.015)
			emote("star")
		"win":
			_bounce_hero(1.05, -10.0, 0.0)
			emote("heart")


func flash_emotion(kind: String, hold: = 0.75) -> void:
	var e: = V8Art.emo_name(kind)
	if e == "" or not is_visible_in_tree():
		return
	var p: = get_parent()
	if p and (p.get("_v8_modal") == true or p.get("_v8_over") == true):
		return
	_emo_pop += 1
	var my: = _emo_pop
	var excited: = e in ["happy", "surprised", "shy"]
	if excited:
		if _pose_tier != 2:
			_set_hero_pose(2)
		_bounce_hero(1.045, -8.0, -0.015)
	else:
		_bounce_hero(0.985, 4.0, 0.022)
	await get_tree().create_timer(clampf(hold, 0.35, 1.2)).timeout
	if my != _emo_pop or not is_inside_tree():
		return
	if not is_ready and _pose_tier != 1:
		_set_hero_pose(1)


func set_ult_badge(letter: String, c: Color, hint: = "") -> void:
	if _badge_pill and is_instance_valid(_badge_pill):
		_badge_pill.queue_free()
	_badge_pill = null
	ult_badge = null
	if letter == "" or _cta_box == null:
		return
	var d: = 30.0
	var b: = Control.new()
	b.name = "UltModBadge"
	b.position = Vector2(_cta_box.position.x - d - 8.0, _cta_box.position.y + (PILL_H - d) * 0.5)
	b.size = Vector2(d, d)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.tooltip_text = hint
	b.z_index = 9
	b.draw.connect(func() -> void:
		var ctr: = Vector2(d * 0.5, d * 0.5)
		b.draw_circle(ctr, d * 0.5, Color(V10DS.NIGHT_800, 0.90), true, -1.0, true)
		b.draw_arc(ctr, d * 0.5 - 0.5, 0, TAU, 32, Color(V10DS.GOLD_700, 0.65), 1.0, true))
	add_child(b)
	var ic: = V9ModIcon.make(letter, d - 10.0)
	ic.position = Vector2(5.0, 5.0)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(ic)
	_badge_pill = b
	ult_badge = b


func say_text(text: String, dur: = 2.6, talk: = true) -> void:
	if text == "":
		return
	var p: Control = get_parent()
	if p == null or p.get("_v8_modal") == true or p.get("_v8_over") == true:
		return
	if _caption_box and is_instance_valid(_caption_box):
		_caption_box.queue_free()
		_caption_box = null
	if _shared_bubble and is_instance_valid(_shared_bubble):
		_shared_bubble.queue_free()

	var w: = clampf(size.x * 0.56, 220.0, 290.0)
	var f: = V10Type.font("ui")
	var th: = f.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, w - 28.0, 18).y
	var h: = clampf(th + 18.0, 40.0, 108.0)

	var cap: = Control.new()
	cap.name = "HeroCaption"
	cap.size = Vector2(w, h)
	var bx: = clampf(position.x + 12.0, 18.0, p.size.x - w - 18.0)
	var by: = clampf(position.y + 18.0, 96.0, position.y + size.y - h - 76.0)
	cap.position = Vector2(bx, by)
	cap.z_index = 48
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap.draw.connect(func() -> void:
		var cr: = Rect2(Vector2.ZERO, cap.size)
		cap.draw_colored_polygon(V10Button.rr_pts(cr, 4.0, 6), Color(V10DS.NIGHT_800, 0.90))
		cap.draw_line(Vector2(4.0, cr.size.y - 1.0), Vector2(cr.size.x - 4.0, cr.size.y - 1.0), Color(V10DS.NIGHT_900, 0.65), 1.0)
		V10Plate.hairline(cap, 10.0, cr.size.x - 10.0, 0.5, Color(V10DS.GOLD_700, 0.5)))
	p.add_child(cap)

	var lbl: = Label.new()
	lbl.text = text
	lbl.label_settings = V10Type.settings("ui", 18, V10DS.PAPER_100, false)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.clip_text = true
	lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	lbl.position = Vector2(14.0, 8.0)
	lbl.size = Vector2(w - 28.0, h - 16.0)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap.add_child(lbl)

	_caption_box = cap
	bubble_node = cap
	_shared_bubble = cap
	cap.modulate.a = 0.0
	var tw: = cap.create_tween()
	tw.tween_property(cap, "modulate:a", 1.0, 0.18)
	tw.tween_interval(dur)
	tw.tween_property(cap, "modulate:a", 0.0, 0.28)
	tw.tween_callback(cap.queue_free)
	if talk:
		Sfx.voice_started.emit(hero_id, text, minf(dur * 0.6, 0.35 + text.length() * 0.05))
