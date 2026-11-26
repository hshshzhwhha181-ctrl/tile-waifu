class_name V10ShowcaseFx
extends Node

# V10ShowcaseFx — the combo-showcase heroine ALIVE during «держит» (docs/HUD_V2.md §7.3; hudfx README «Витрина живая»;
# closes hud2 README «Известные отступления»: no sway / sheen without masks). One material
# (shaders/v10/hudfx/showcase_live.gdshader, a superset of hud2/showcase_sprite: same uniforms, same board mask) and a
# tiny driver node. The driver owns no timeline: it reads V10ComboShowcase's own clock (phase / phase_t), so skip,
# pause, fx_level and the hud2 selftest's manual _advance() stay in sync by construction. It runs after the showcase
# (process_priority), writes the live uniforms only while the show runs and frees itself when the show ends — or when
# its showcase / sprite is freed first.
#
#   sc._mat = V10ShowcaseFx.material_for(hero, outfit, tier, sprite_path)  # in trigger(), before the board uniforms
#   V10ShowcaseFx.drive(showcase, sprite, tier, hero) -> Node              # after trigger(); self-freeing driver
#   V10ShowcaseFx.particles(hero) -> Array[Texture2D]                       # painted <element>_{0..3}.png, or []
#   V10ShowcaseFx.draw_particle(ci, hero, pt, a) -> bool                    # hud2 _Fx hook; false = draw procedural
#   V10ShowcaseFx.particle_count(n) -> int                                  # ≤ 18 at full, ×0.55 mid, 0 min
#
# Timings, seconds from the start of «держит» (hold = 0.50 / 0.70 / 0.86 s for T1 / T2 / T3):
#   sway   T1–T3  envelope sin(π·u) over the hold (0 outside it), wave sin(t·2π/2.4 + uv.y·3), ≤ 6 sprite px, hair only
#   sheen  T2 0.06 → 0.66, T3 0.24 → 0.84: ONE warm band (glow, α 0.35) down the leg mask, knee → ankle, 0.6 s
#   rim    T3 0.00 → 0.60: hud2's contour light upgraded (accent ≤ 0.8, sweep top → bottom, light wrap); the driver
#          overwrites hud2's own rim writes, so there is one rim, not two
#   the slanted accent ray is hud2's (_Fx, T2/T3, accent × 0.7, α 0.22): not doubled here
# fx levels: full — all; mid — sway, sheen α 0.24, rim × 0.7; min — nothing (hud2 already fades 120 ms): uniforms 0.
# calm() «Без тряски и вспышек»: no sheen, no sweep — a steady low rim that only appears with her; sway stays.
# Masks: assets/v10/hudfx/masks/<sprite>_{hair,leg}.png (L8, ¼ res, sprite UV; <sprite> = the sprite file's base name,
# e.g. mc_t2 or mc_cafe_t2). A missing mask turns its effect off (strength 0) — no error, no fallback guess.
# Red lines: the sheen is strictly × leg mask (below the knee) and never above a face-based guard (face bottom +
# 3 heads); the rim lights hair, the leg mask, what is above the chest and (chest → waist) only her back's edge —
# never chest, crotch or thighs.

const SHADER: = "showcase_live"
const HUD2_SHADER: = "res://shaders/v10/hud2/showcase_sprite.gdshader"
const META: = "res://assets/v10/hud2/combo/combo_meta.json"
const MASKS: = "masks/"
const TIERS_FALLBACK: = {
	1: {"in": 0.20, "hold": 0.50, "out": 0.20},
	2: {"in": 0.28, "hold": 0.70, "out": 0.22},
	3: {"in": 0.30, "hold": 0.86, "out": 0.24},
}
const SWAY_PX: = 6.0
const SWAY_PERIOD: = 2.4
const SHEEN_T: = 0.6
const SHEEN_START: = {2: 0.06, 3: 0.24}
const SHEEN_A: = 0.35
const SHEEN_A_MID: = 0.24
const RIM_T: = 0.6
const RIM_BASE: = 0.25
const RIM_MID: = 0.7
const RIM_CALM: = 0.4
const RIM_SCREEN_PX: = 3.0
const GUARD_HEADS: = 3.0  # sheen guard: face bottom + 3 face heights (always above any knee)
const CHEST_HEADS: = 0.3  # rim zones, in face heights under the chin: chest top …
const WAIST_HEADS: = 1.6  # … and waist (below it only hair and the leg mask may catch the rim)
const PART_SIZE: = 3.4  # painted particle side = hud2 size s (5..10) × 3.4 → 17..34 px
const PART_MAX: = 18

const P_SWAY: = &"sway"
const P_SWAY_T: = &"sway_time"
const P_SHEEN: = &"sheen"
const P_SHEEN_PH: = &"sheen_phase"
const P_SHEEN_A: = &"sheen_alpha"
const P_RIM: = &"rim"
const P_RIM_PH: = &"rim_phase"
const P_RIM_BASE: = &"rim_base"
const P_RIM_PX: = &"rim_px"

static var mask_dirs: Array = []  # extra ABSOLUTE dirs searched after res:// (demo preview / tests)
static var _masks: = {}
static var _boxes: = {}
static var _meta: = {}
static var _meta_loaded: = false
static var _ptex: = {}

# ------------------------------------------------------------------ driver state (one per show)
var sc: Node
var spr: CanvasItem
var mat: ShaderMaterial
var tier: = 1
var hero: = "mc"
var lvl: = "full"
var calm_on: = false
var in_len: = 0.2
var hold_len: = 0.5
var out_len: = 0.2
var done: = false
# last written values (tests read them; uniforms mirror them)
var sway_k: = 0.0
var sway_t: = 0.0
var sheen_k: = 0.0
var sheen_p: = 0.0
var sheen_runs: = 0
var rim_k: = 0.0
var rim_p: = 0.0
var _own: = false  # host without a phase clock: run our own timeline from TIERS
var _t: = 0.0
var _out_seen: = false
var _from: = Vector3.ZERO  # (sway, sheen, rim) when «out» began


# ------------------------------------------------------------------ material

static func material_for(hero_id: String, outfit: String, t: int, sprite_path: String) -> ShaderMaterial:
	V10HudFx.register_shader(SHADER)
	var m: = V10HudFx.mat(SHADER)
	if m.shader == null:  # lane shader missing: hud2's own, the board mask is never lost
		m.shader = load(HUD2_SHADER)
		return m
	var key: = sprite_key(hero_id, outfit, t, sprite_path)
	var tsz: = Vector2(1360, 2048)
	if sprite_path != "" and ResourceLoader.exists(sprite_path):
		var tx: Texture2D = load(sprite_path)
		if tx:
			tsz = tx.get_size()
	var f: = face_uv(key, tsz)
	m.set_shader_parameter("face_uv", Vector4(f.position.x, f.position.y, f.size.x, f.size.y))
	m.set_shader_parameter("rim_color", V10HudFx.accent(hero_id))  # hud2 writes the same accent again
	var hair: = mask(key, "hair")
	var leg: = mask(key, "leg")
	m.set_shader_parameter("hair_mask", hair)
	m.set_shader_parameter("hair_strength", 1.0 if hair else 0.0)
	m.set_shader_parameter("leg_mask", leg)
	m.set_shader_parameter("leg_strength", 1.0 if leg else 0.0)
	var box: = Rect2(0.0, 0.7, 1.0, 0.3)
	if leg:
		box = mask_box(leg)
	m.set_shader_parameter("leg_box", Vector4(box.position.x, box.position.y, box.size.x, box.size.y))
	m.set_shader_parameter("leg_guard", clampf(f.end.y + f.size.y * GUARD_HEADS, 0.0, 1.0))
	m.set_shader_parameter("quiet_band", Vector2(clampf(f.end.y + f.size.y * CHEST_HEADS, 0.0, 1.0),
			clampf(f.end.y + f.size.y * WAIST_HEADS, 0.0, 1.0)))
	m.set_shader_parameter("back_x", -1.0 if str(_meta.get(key, {}).get("facing", "left")) == "right" else 1.0)
	m.set_shader_parameter("sheen_color", V10HudFx.warm_light(V10HudFx.glow(hero_id)))
	m.set_shader_parameter("sheen_alpha", SHEEN_A)
	m.set_shader_parameter("sway_px", SWAY_PX)
	m.set_shader_parameter("sway_period", SWAY_PERIOD)
	m.set_shader_parameter("rim_base", RIM_BASE)
	m.set_meta("v10_live_key", key)
	return m


static func is_live(m: Material) -> bool:
	return m is ShaderMaterial and (m as ShaderMaterial).shader != null and (m as ShaderMaterial).shader == V10HudFx.shader(SHADER)


static func sprite_key(hero_id: String, _outfit: String, t: int, sprite_path: String) -> String:
	# masks belong to one painted sprite: never borrow another outfit's (or tier's) mask
	if sprite_path != "":
		return sprite_path.get_file().get_basename()
	return "%s_t%d" % [hero_id, t]


static func mask(key: String, kind: String) -> Texture2D:
	var nm: = "%s_%s" % [key, kind]
	if _masks.has(nm):
		return _masks[nm]
	var t: Texture2D = V10HudFx.tex(MASKS + nm)
	if t == null:
		for d in mask_dirs:
			var p: = "%s/%s.png" % [str(d).trim_suffix("/"), nm]
			if FileAccess.file_exists(p):
				var img: = Image.load_from_file(p)
				if img and not img.is_empty():
					t = ImageTexture.create_from_image(img)
					break
	_masks[nm] = t
	return t


static func clear_cache() -> void:
	_masks.clear()
	_boxes.clear()


static func mask_box(t: Texture2D) -> Rect2:
	# UV bounding box of mask > 0.25 (scanned once on a ≤ 64 px copy, cached per texture)
	var id: = t.get_rid().get_id()
	if _boxes.has(id):
		return _boxes[id]
	var out: = Rect2(0.0, 0.7, 1.0, 0.3)
	var img: = t.get_image()
	if img and not img.is_empty():
		img = img.duplicate() as Image
		if img.is_compressed():
			img.decompress()
		img.convert(Image.FORMAT_L8)
		var w: = maxi(1, mini(64, img.get_width()))
		var h: = maxi(1, int(round(float(img.get_height()) * w / img.get_width())))
		img.resize(w, h, Image.INTERPOLATE_BILINEAR)
		var data: = img.get_data()
		var x0: = w
		var y0: = h
		var x1: = -1
		var y1: = -1
		for y in h:
			for x in w:
				if data[y * w + x] > 64:
					x0 = mini(x0, x)
					y0 = mini(y0, y)
					x1 = maxi(x1, x)
					y1 = maxi(y1, y)
		if x1 >= 0:
			out = Rect2(float(x0) / w, float(y0) / h, float(x1 - x0 + 1) / w, float(y1 - y0 + 1) / h)
	_boxes[id] = out
	return out


static func face_uv(key: String, tsz: Vector2) -> Rect2:
	# face rect in UV from combo_meta.json (hud2's default when the sprite has no meta)
	if not _meta_loaded:
		_meta_loaded = true
		if FileAccess.file_exists(META):
			var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(META))
			if d is Dictionary:
				_meta = (d as Dictionary).get("sprites", {})
	var m: Dictionary = _meta.get(key, {})
	if m.has("face") and tsz.x > 0.0 and tsz.y > 0.0:
		var f: Array = m.face
		return Rect2(float(f[0]) / tsz.x, float(f[1]) / tsz.y, float(f[2]) / tsz.x, float(f[3]) / tsz.y)
	return Rect2(0.4, 0.08, 0.2, 0.12)


# ------------------------------------------------------------------ particles (hud2 _Fx draws them)

static func particles(hero_id: String) -> Array[Texture2D]:
	var el: = V10HudFx.element(hero_id)
	if _ptex.has(el):
		return _ptex[el]
	var out: Array[Texture2D] = []
	for i in 4:
		var t: = V10HudFx.tex("particles/%s_%d" % [el, i])
		if t:
			out.append(t)
	_ptex[el] = out
	return out


static func particle_count(n: int) -> int:
	return mini(V10HudFx.n(n), PART_MAX)


static func draw_particle(ci: CanvasItem, hero_id: String, pt: Dictionary, a: float) -> bool:
	# called inside hud2's _Fx._draw() with the particle's transform already set; false → hud2 draws its own
	if V10HudFx.is_min():
		return false
	var arr: = particles(hero_id)
	if arr.is_empty():
		return false
	var s: = float(pt.get("s", 7.0))
	var i: = int(pt.get("i", int(s * 131.0))) % arr.size()
	var side: = s * PART_SIZE
	ci.draw_texture_rect(arr[i], Rect2(-side * 0.5, -side * 0.5, side, side), false, Color(Color.WHITE, 0.92 * a))
	return true


# ------------------------------------------------------------------ driver

static func drive(showcase: Node, sprite: CanvasItem, t: int, hero_id: String) -> Node:
	var d: = V10ShowcaseFx.new()
	d.name = "ShowcaseFx"
	d.sc = showcase
	d.spr = sprite
	d.tier = clampi(t, 1, 3)
	d.hero = hero_id
	d.lvl = V10HudFx.level()
	d.calm_on = V10HudFx.calm()
	if is_instance_valid(sprite) and is_live(sprite.material):
		d.mat = sprite.material
	var cfg: Dictionary = TIERS_FALLBACK[d.tier]
	if is_instance_valid(showcase) and "phase" in showcase and "phase_t" in showcase:
		var scr: Script = showcase.get_script()
		var tiers: Variant = scr.get_script_constant_map().get("TIERS") if scr else null
		if tiers is Dictionary and (tiers as Dictionary).has(d.tier):
			cfg = tiers[d.tier]
	else:
		d._own = true
	d.in_len = float(cfg.get("in", 0.2))
	d.hold_len = float(cfg.get("hold", 0.5))
	d.out_len = float(cfg.get("out", 0.2))
	if d.lvl == "min":
		d.in_len = V10HudFx.T_MIN
		d.out_len = V10HudFx.T_MIN
	var host: Node = showcase if is_instance_valid(showcase) else sprite
	if is_instance_valid(host):
		for c in host.get_children():
			if c is V10ShowcaseFx and c != d:
				(c as V10ShowcaseFx)._end()
		host.add_child(d)
		if host.has_signal("finished"):
			host.connect("finished", d._on_finished, CONNECT_ONE_SHOT)
	if d.mat and is_instance_valid(sprite) and sprite is TextureRect and (sprite as TextureRect).texture:
		var tr: = sprite as TextureRect
		var sc_px: = tr.size.x / maxf(1.0, tr.texture.get_size().x)
		d.mat.set_shader_parameter(P_RIM_PX, clampf(RIM_SCREEN_PX / maxf(sc_px, 0.05), 3.0, 12.0))
	if d.mat == null or d.lvl == "min" or not is_instance_valid(host):
		d._end()  # nothing extra at min (hud2 fades 120 ms); not our material: hands off
		return d
	d.mat.set_shader_parameter(P_SHEEN_A, SHEEN_A_MID if d.lvl == "mid" else SHEEN_A)
	d.mat.set_shader_parameter(P_RIM_BASE, 1.0 if d.calm_on else RIM_BASE)
	d.sync()
	return d


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 100  # after V10ComboShowcase._process (it writes hud2's rim first; ours wins)


func _process(delta: float) -> void:
	sync(delta)


func _on_finished(_t_: int = 0, _skipped: bool = false) -> void:
	_end()


func sync(dt: = 0.0) -> void:
	if done:
		return
	if mat == null or not is_instance_valid(spr):
		_end()
		return
	var ph: = ""
	var pt: = 0.0
	if _own:
		_t += dt
		if _t < in_len:
			ph = "in"
			pt = _t
		elif _t < in_len + hold_len:
			ph = "hold"
			pt = _t - in_len
		elif _t < in_len + hold_len + out_len:
			ph = "out"
			pt = _t - in_len - hold_len
		else:
			_end()
			return
	else:
		if not is_instance_valid(sc) or not bool(sc.get("active")):
			_end()
			return
		ph = str(sc.get("phase"))
		pt = float(sc.get("phase_t"))
		var ol: Variant = sc.get("_out_len")
		if ph == "out" and ol != null:
			out_len = float(ol)
	match ph:
		"in":
			sway_k = 0.0
			sway_t = 0.0
			sheen_k = 0.0
			rim_k = RIM_CALM if calm_on and tier == 3 else 0.0
		"hold":
			_hold(pt)
		"out":
			if not _out_seen:
				_out_seen = true
				_from = Vector3(sway_k, sheen_k, rim_k)
			var q: = clampf(pt / maxf(out_len, 0.001), 0.0, 1.0)
			var k: = cos(q * PI * 0.5)
			sway_k = _from.x * k
			sheen_k = _from.y * k
			rim_k = RIM_CALM if calm_on and tier == 3 else _from.z * k
		_:
			_end()
			return
	_apply()


func _hold(ht: float) -> void:
	var u: = clampf(ht / maxf(hold_len, 0.001), 0.0, 1.0)
	sway_k = sin(PI * u)
	sway_t = ht
	sheen_k = 0.0
	if tier >= 2 and not calm_on:
		var p: = (ht - float(SHEEN_START[tier])) / SHEEN_T
		if p >= 0.0 and p <= 1.0:
			if sheen_runs == 0:
				sheen_runs = 1
			if sheen_runs == 1:
				sheen_k = 1.0
				sheen_p = p
	rim_k = 0.0
	if tier == 3:
		if calm_on:
			rim_k = RIM_CALM
		else:
			var rp: = clampf(ht / RIM_T, 0.0, 1.0)
			rim_p = rp
			rim_k = smoothstep(0.0, 0.12, rp) * (1.0 - smoothstep(0.7, 1.0, rp)) * (RIM_MID if lvl == "mid" else 1.0)


func _apply() -> void:
	mat.set_shader_parameter(P_SWAY, sway_k)
	mat.set_shader_parameter(P_SWAY_T, sway_t)
	mat.set_shader_parameter(P_SHEEN, sheen_k)
	mat.set_shader_parameter(P_SHEEN_PH, sheen_p)
	mat.set_shader_parameter(P_RIM, rim_k)
	mat.set_shader_parameter(P_RIM_PH, rim_p)


func _end() -> void:
	if done:
		return
	done = true
	sway_k = 0.0
	sheen_k = 0.0
	rim_k = 0.0
	if mat:
		_apply()
	set_process(false)
	if is_instance_valid(sc) and sc.has_signal("finished") and sc.is_connected("finished", _on_finished):
		sc.disconnect("finished", _on_finished)
	if not is_queued_for_deletion():
		queue_free()
