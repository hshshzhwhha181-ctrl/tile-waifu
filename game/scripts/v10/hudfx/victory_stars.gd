class_name V10VictoryStars
extends Control

# V10VictoryStars — the three level stars of victory beat 1 «Стол чист» (docs/HUD_V2.md §8.3; UX_RULES §6.7
# «награды … нота пентатоники вверх», §6.4 «звезда ★ только за уровни»). Lane: scripts/v10/hudfx/README.md.
# Painted stars `items/star` / `items/star_empty` (V10HudFx.tex); until the art lands a bevelled vector star
# (gold.300 → gold.500 facets, light from the top left, one spark) and a paper.700 outline socket. It sits exactly
# over the vector stars of V10HudVictory (`_Stars`: centres (28 + 72·i, 28), size 56 — the defaults here).
#
#   var s := V10VictoryStars.new(); stars_c.add_child(s)
#   s.configure([Vector2(28, 28), Vector2(100, 28), Vector2(172, 28)], 56.0)   # local centres, star size (px)
#   s.play(earned, delay)    # the beat (earned 0..3); signal `finished` once everything is still
#   s.show_static(earned)    # final state at once: no motion, no sound (tap-to-skip, re-configure)
#
# Timeline (seconds after play() + delay):
#   empty slots «Вдох»   slot i at 0.04·i: 240 ms QUINT_OUT, α 0→1 and y +12→0 (scale untouched)
#   earned star k lands  at 0.32 + 0.20·k: 240 ms QUINT_OUT, scale 1.25→1.0 and α 0→1 — no bounce, no shake;
#                        the slot under it fades as the star arrives. 60 ms in (the star is ¾ down) it rings
#                        V10HudFx.note(k + 2) (E, G, A — pentatonic up), lights a warm gold disc behind it
#                        (α ≤ 0.45: 40 ms in, 300 ms out; the third star's disc ×1.2) and lets out a pinch of gold
#                        dust (7 motes, 0.38–0.5 s, drag + a little gravity).
#   then nothing moves: no sheen, no twinkle, _process off, `finished` (3 stars: delay + 1.28 s).
#   3 landings in 0.4 s = 3 light discs in any second (the ≤ 3 flashes/s cap).
# fx levels: full — all; mid — dust V10HudFx.n(7) = 4 per star, disc α 0.30; min — slots and the earned stars
#   fade in together in 120 ms, one note (the highest reached), no disc, no dust. V10HudFx.calm() — no light discs
#   (dust and notes stay).
# Cost: 2·N + 2 children; the star nodes are drawn once and only moved/faded; ONE additive node draws the discs
#   (behind) and ONE node draws every mote (in front, normal blend) from arrays sized in play(); no tweens, no
#   timers, nothing outside the node — freeing the parent mid-beat just ends it. The 192 px painted art is imported
#   without mipmaps: a mipmapped copy is made once per texture (art_texture), so 56 px edges do not sparkle.

signal finished

const T_SLOT: = 0.24  # «Вдох» of each empty slot (HUD_V2 §6)
const T_SLOT_STEP: = 0.04
const T_LAND: = 0.24  # each earned star
const T_LAND_STEP: = 0.20
const T_HIT: = 0.06  # note, disc and dust fire this long after a landing starts
const T_GLOW_IN: = 0.04
const T_GLOW: = 0.30  # disc fade out
const SLOT_DY: = 12.0
const LAND_SCALE: = 1.25
const NOTE0: = 2  # star k rings V10HudFx.note(k + NOTE0)
const GLOW_A_FULL: = 0.45
const GLOW_A_MID: = 0.30
const GLOW_R: = 0.95  # disc radius / star size
const GLOW_THIRD: = 1.2  # the third star's disc is a little larger
const DUST: = 7  # motes per landing at full (≤ 8); mid V10HudFx.n(7) = 4; min 0
const DUST_MAX: = 8
const DUST_LIFE: = Vector2(0.38, 0.5)
const DUST_SPEED: = Vector2(46.0, 96.0)
const DUST_DRAG: = 2.4
const DUST_GRAV: = 64.0
const DUST_A: = 0.9
const STAR_R: = 26.0 / 56.0  # vector star outer radius / size (= V10HudVictory._Stars: r 26 in a 56 slot)
const STAR_RI: = 0.46  # inner / outer radius (= V10Icons.draw_star)
const ART_FILL: = 0.92  # painted art: the opaque box of the item spans this share of the size
const HUD2_CENTERS: = [Vector2(28, 28), Vector2(100, 28), Vector2(172, 28)]
const HUD2_SIZE: = 56.0
const TEX_STAR: = "items/star"
const TEX_EMPTY: = "items/star_empty"

var centers: = PackedVector2Array()
var star_size: = HUD2_SIZE
var earned: = 0
var delay: = 0.0
var t: = 0.0  # seconds since play()
var playing: = false
var fx: = "full"  # fx level captured by play()
var glow_peak: = 0.0
var dust_per: = 0
var notes: = PackedInt32Array()  # pentatonic steps rung by the last play() (selftest / debug)
var note_at: = PackedFloat32Array()  # … and when (t)

var _light: _Light  # additive, behind the stars: the warm discs
var _dust: _Dust  # in front of the stars: every mote of the beat (normal blend — gold stays gold on her hair)
var _slots: Array = []  # _Item (empty socket) per centre
var _stars: Array = []  # _Item (earned star) per centre
var _fired: = 0
var _mute: = false
var _rng: = RandomNumberGenerator.new()
# dust and discs: sized in play(), never per frame
var d_pos: = PackedVector2Array()
var d_vel: = PackedVector2Array()
var d_age: = PackedFloat32Array()
var d_life: = PackedFloat32Array()
var d_rad: = PackedFloat32Array()
var d_n: = 0
var g_at: = PackedFloat32Array()  # per star: when its disc lit (−1 = not yet)

static var _geo: = {}
static var _fit: = {}
static var _art: = {}
static var _glow_tex: Texture2D
static var _add_mat: CanvasItemMaterial


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)
	configure(HUD2_CENTERS, HUD2_SIZE)


# ------------------------------------------------------------------ API

func configure(c: Array, size_px: = HUD2_SIZE) -> void:
	centers = PackedVector2Array(c)
	star_size = maxf(size_px, 1.0)
	earned = mini(earned, centers.size())
	_fired = mini(_fired, earned)
	_build()
	var hi: = Vector2.ZERO
	for p in centers:
		hi = hi.max(p + Vector2.ONE * star_size * 0.5)
	size = hi
	if playing:
		_apply()
	else:
		_hide_all()


func play(earned_n: int, delay_s: = 0.0) -> void:
	earned = clampi(earned_n, 0, centers.size())
	delay = maxf(delay_s, 0.0)
	fx = V10HudFx.level()
	glow_peak = 0.0
	if fx != "min" and not V10HudFx.calm():
		glow_peak = GLOW_A_FULL if fx == "full" else GLOW_A_MID
	dust_per = mini(V10HudFx.n(DUST), DUST_MAX)
	var cap: = earned * dust_per
	d_pos.resize(cap)
	d_vel.resize(cap)
	d_age.resize(cap)
	d_life.resize(cap)
	d_rad.resize(cap)
	d_n = 0
	g_at.resize(centers.size())
	g_at.fill(-1.0)
	notes.clear()
	note_at.clear()
	_fired = 0
	_rng.seed = 7103 + earned
	t = 0.0
	playing = true
	_light.visible = true
	_dust.visible = true
	_apply()
	set_process(true)


func show_static(earned_n: int) -> void:
	earned = clampi(earned_n, 0, centers.size())
	playing = false
	d_n = 0
	set_process(false)
	_light.visible = false
	_dust.visible = false
	for i in centers.size():
		var s: _Item = _slots[i]
		var st: _Item = _stars[i]
		s.position = centers[i]
		s.modulate.a = 0.0 if i < earned else 1.0
		s.visible = i >= earned
		st.position = centers[i]
		st.scale = Vector2.ONE
		st.modulate.a = 1.0
		st.visible = i < earned


func is_playing() -> bool:
	return playing


# demo / tests: replay silently up to `time` (s since play) in 1/120 s steps, then hold there if `hold`
func seek(time: float, hold: = true) -> void:
	play(earned, delay)
	_mute = true
	while playing and t + 1.0e-6 < time:
		advance(minf(1.0 / 120.0, time - t))
	_mute = false
	if hold:
		set_process(false)


# ------------------------------------------------------------------ timeline (pure functions of the play() setup)

func slot_time(i: int) -> float:
	return delay if fx == "min" else delay + i * T_SLOT_STEP


func land_time(k: int) -> float:
	if fx == "min":
		return delay
	return delay + T_SLOT + maxi(centers.size() - 1, 0) * T_SLOT_STEP + k * T_LAND_STEP


func hit_time(k: int) -> float:
	return delay if fx == "min" else land_time(k) + T_HIT


func duration() -> float:
	if centers.is_empty():
		return delay
	if fx == "min":
		return delay + V10HudFx.T_MIN
	var end: = slot_time(centers.size() - 1) + T_SLOT
	if earned > 0:
		var lk: = land_time(earned - 1)
		end = maxf(end, lk + T_LAND)
		if dust_per > 0:
			end = maxf(end, hit_time(earned - 1) + DUST_LIFE.y)
		if glow_peak > 0.0:
			end = maxf(end, hit_time(earned - 1) + T_GLOW_IN + T_GLOW)
	return end


func glow_alpha(k: int) -> float:
	if glow_peak <= 0.0 or k >= g_at.size() or g_at[k] < 0.0:
		return 0.0
	var g: = t - g_at[k]
	if g < 0.0 or g > T_GLOW_IN + T_GLOW:
		return 0.0
	var u: = clampf((g - T_GLOW_IN) / T_GLOW, 0.0, 1.0)
	return glow_peak * minf(1.0, g / T_GLOW_IN) * (1.0 - u) * (1.0 - u)


func glow_radius(k: int) -> float:
	var g: = clampf((t - g_at[k]) / 0.12, 0.0, 1.0) if k < g_at.size() else 1.0
	return star_size * GLOW_R * (GLOW_THIRD if k == 2 else 1.0) * (0.86 + 0.14 * g)


func glow_color(k: int) -> Color:
	return V10HudFx.warm_light(V10DS.GOLD_500, glow_alpha(k))


func live_dust() -> int:
	var c: = 0
	for i in d_n:
		if d_age[i] < d_life[i]:
			c += 1
	return c


static func quint_out(x: float) -> float:
	var u: = 1.0 - clampf(x, 0.0, 1.0)
	return 1.0 - u * u * u * u * u


# ------------------------------------------------------------------ frame

func _process(delta: float) -> void:
	advance(delta)


func advance(dt: float) -> void:
	if not playing:
		return
	t += dt
	_step_dust(dt)  # before _fire(): a mote born this frame is already aged t − hit
	_fire()
	_apply()
	if t >= duration():
		_settle()


func _fire() -> void:
	if fx == "min":
		if _fired == 0 and earned > 0 and t >= delay:
			_note(earned - 1 + NOTE0)  # one note: the highest the row reaches
			_fired = earned
		return
	while _fired < earned and t >= hit_time(_fired):
		_hit(_fired)
		_fired += 1


func _hit(k: int) -> void:
	_note(k + NOTE0)
	var th: = hit_time(k)
	if glow_peak > 0.0:
		g_at[k] = th
	if dust_per <= 0:
		return
	var c: = centers[k]
	var r: = star_size * STAR_R
	var a0: = _rng.randf() * TAU
	for j in dust_per:
		if d_n >= d_pos.size():
			break
		var a: = a0 + TAU * (float(j) + _rng.randf_range(-0.3, 0.3)) / float(dust_per)
		var dir: = Vector2(cos(a), sin(a))
		d_pos[d_n] = c + dir * r * _rng.randf_range(0.5, 0.9)
		d_vel[d_n] = dir * _rng.randf_range(DUST_SPEED.x, DUST_SPEED.y) + Vector2(0.0, -26.0)
		d_age[d_n] = t - th
		d_life[d_n] = _rng.randf_range(DUST_LIFE.x, DUST_LIFE.y)
		d_rad[d_n] = _rng.randf_range(1.3, 2.4)
		d_n += 1


func _step_dust(dt: float) -> void:
	if d_n == 0:
		return
	var damp: = exp(-DUST_DRAG * dt)
	var grav: = Vector2(0.0, DUST_GRAV * dt)
	for i in d_n:
		if d_age[i] >= d_life[i]:
			continue
		d_age[i] += dt
		var v: = d_vel[i] * damp + grav
		d_vel[i] = v
		d_pos[i] += v * dt


func _apply() -> void:
	for i in centers.size():
		var s: _Item = _slots[i]
		var st: _Item = _stars[i]
		var a_star: = 0.0
		var sc: = 1.0
		var a_slot: = 0.0
		var dy: = 0.0
		if fx == "min":
			var f: = smoothstep(0.0, 1.0, (t - delay) / V10HudFx.T_MIN)
			if i < earned:
				a_star = f
			else:
				a_slot = f
		else:
			if i < earned:
				a_star = quint_out((t - land_time(i)) / T_LAND)
				sc = lerpf(LAND_SCALE, 1.0, a_star)
			var v: = quint_out((t - slot_time(i)) / T_SLOT)
			a_slot = v * (1.0 - a_star)
			dy = SLOT_DY * (1.0 - v)
		s.position = centers[i] + Vector2(0.0, dy)
		s.modulate.a = a_slot
		s.visible = a_slot > 0.002
		st.position = centers[i]
		st.scale = Vector2(sc, sc)
		st.modulate.a = a_star
		st.visible = a_star > 0.002
	_light.queue_redraw()
	if d_n > 0:
		_dust.queue_redraw()


func _settle() -> void:
	playing = false
	t = maxf(t, duration())
	d_n = 0
	_apply()
	_light.visible = false
	_dust.visible = false
	set_process(false)
	finished.emit()


func _note(step: int) -> void:
	notes.append(step)
	note_at.append(t)
	if not _mute:
		V10HudFx.note(step)


func _hide_all() -> void:
	for n in _slots + _stars:
		(n as _Item).visible = false
	if _light:
		_light.visible = false
		_dust.visible = false


func _build() -> void:
	if _light == null:
		_light = _Light.new()
		_light.o = self
		_light.material = add_material()
		add_child(_light)
		_dust = _Dust.new()
		_dust.o = self
		add_child(_dust)
	var st_tex: = art_texture(V10HudFx.tex(TEX_STAR))
	var em_tex: = art_texture(V10HudFx.tex(TEX_EMPTY))
	while _slots.size() > centers.size():
		(_slots.pop_back() as Node).free()
		(_stars.pop_back() as Node).free()
	while _slots.size() < centers.size():
		var s: = _Item.new()
		s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		add_child(s)
		_slots.append(s)
	while _stars.size() < centers.size():
		var st: = _Item.new()
		st.lit = true
		st.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		add_child(st)
		_stars.append(st)
	for i in centers.size():
		for it in [_slots[i], _stars[i]]:
			var n: _Item = it
			n.size = star_size
			n.tex = st_tex if n.lit else em_tex
			n.position = centers[i]
			n.queue_redraw()
	move_child(_dust, -1)
	glow_texture()


func uses_art() -> bool:
	return not _stars.is_empty() and (_stars[0] as _Item).tex != null


# ------------------------------------------------------------------ shared art (static, built once)

static func add_material() -> CanvasItemMaterial:
	if _add_mat == null:
		_add_mat = CanvasItemMaterial.new()
		_add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _add_mat


static func glow_texture() -> Texture2D:
	if _glow_tex == null:
		var g: = Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.4, 0.65, 0.85, 1.0])
		g.colors = PackedColorArray([Color.WHITE, Color(Color.WHITE, 0.78), Color(Color.WHITE, 0.38), Color(Color.WHITE, 0.1), Color(Color.WHITE, 0.0)])
		var gt: = GradientTexture2D.new()
		gt.gradient = g
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(1.0, 0.5)
		gt.width = 128
		gt.height = 128
		_glow_tex = gt
	return _glow_tex


# painted item, prepared once per texture: the 192 px art is imported without mipmaps, so at 56 px (×0.29) plain
# linear sampling sparkles on the edges — a mipmapped copy (alpha edges bled first, no dark fringe) samples clean
# at any canvas scale. Returns null for null.
static func art_texture(src: Texture2D) -> Texture2D:
	if src == null:
		return null
	if _art.has(src):
		return _art[src]
	var out: = src
	var img: = src.get_image()
	if img != null and not img.is_empty():
		img = img.duplicate()
		if img.is_compressed():
			img.decompress()
		if img.get_format() != Image.FORMAT_RGBA8:
			img.convert(Image.FORMAT_RGBA8)
		var used: = img.get_used_rect()
		img.fix_alpha_edges()
		img.generate_mipmaps()
		out = ImageTexture.create_from_image(img)
		if used.size.x > 0 and used.size.y > 0:
			_fit[out] = Rect2(used)
	_art[src] = out
	return out


# painted item: its opaque box (alpha-used rect, measured once per texture) spans ART_FILL·size, centred on 0
static func art_rect(tex: Texture2D, size_px: float) -> Rect2:
	var u: Rect2
	if _fit.has(tex):
		u = _fit[tex]
	else:
		u = Rect2(Vector2.ZERO, tex.get_size())
		var img: = tex.get_image()
		if img != null and not img.is_empty():
			if img.is_compressed():
				img.decompress()
			var r: = img.get_used_rect()
			if r.size.x > 0 and r.size.y > 0:
				u = Rect2(r)
		_fit[tex] = u
	var k: = size_px * ART_FILL / maxf(maxf(u.size.x, u.size.y), 1.0)
	return Rect2(-(u.position + u.size * 0.5) * k, tex.get_size() * k)


static func _geometry() -> Dictionary:
	# unit star (outer radius 1): rounded tips, 10 facets of a low pyramid lit from the top left
	if not _geo.is_empty():
		return _geo
	var tips: = PackedVector2Array()
	var inner: = PackedVector2Array()
	for j in 5:
		var a: = -PI * 0.5 + TAU * j / 5.0
		tips.append(Vector2(cos(a), sin(a)))
		inner.append(Vector2(cos(a + PI / 5.0), sin(a + PI / 5.0)) * STAR_RI)
	var light: = Vector3(-0.5, -0.72, 0.9).normalized()
	var apex: = Vector3(0.0, 0.0, 0.36)
	var rho: = 0.16
	var contour: = PackedVector2Array()
	var polys: = []
	var lams: = []
	for j in 5:
		var tp: = tips[j]
		var ip: = inner[(j + 4) % 5]
		var inx: = inner[j]
		var p0: = tp + (ip - tp).normalized() * rho
		var p1: = tp + (inx - tp).normalized() * rho
		var arc: = PackedVector2Array()
		for s in 5:
			var u: = s / 4.0
			arc.append(p0 * (1.0 - u) * (1.0 - u) + tp * 2.0 * (1.0 - u) * u + p1 * u * u)
		polys.append(PackedVector2Array([Vector2.ZERO, ip, arc[0], arc[1], arc[2]]))
		lams.append(_lambert(Vector3(ip.x, ip.y, 0.0), Vector3(tp.x, tp.y, 0.0), apex, light))
		polys.append(PackedVector2Array([Vector2.ZERO, arc[2], arc[3], arc[4], inx]))
		lams.append(_lambert(Vector3(tp.x, tp.y, 0.0), Vector3(inx.x, inx.y, 0.0), apex, light))
		contour.append_array(arc)
		contour.append(inx)
	var lo: float = lams.min()
	var hi: float = lams.max()
	var cols: = []
	for f in polys.size():
		var s: = (float(lams[f]) - lo) / maxf(hi - lo, 0.001)
		var c: = _ramp(s)
		var pc: = PackedColorArray()
		var poly: PackedVector2Array = polys[f]
		for v in poly.size():
			var p: = poly[v]
			if v == 0:
				pc.append(c.lerp(V10DS.GOLD_300, 0.35))  # the apex catches the light
			elif p.length() < STAR_RI + 0.01:
				pc.append(c.lerp(V10DS.GOLD_700, 0.16))  # valleys between the points
			else:
				pc.append(c)
		cols.append(pc)
	var closed: = contour.duplicate()
	closed.append(contour[0])
	_geo = {"contour": contour, "closed": closed, "polys": polys, "cols": cols}
	return _geo


static func _lambert(a: Vector3, b: Vector3, apex: Vector3, light: Vector3) -> float:
	var nrm: = (a - apex).cross(b - apex).normalized()
	if nrm.z < 0.0:
		nrm = -nrm
	return nrm.dot(light)


static func _ramp(s: float) -> Color:
	# gold.300 (lit) → gold.500 → a little gold.700 in the shade
	var shade: = V10DS.GOLD_500.lerp(V10DS.GOLD_700, 0.5)
	if s < 0.5:
		return shade.lerp(V10DS.GOLD_500, s * 2.0)
	return V10DS.GOLD_500.lerp(V10DS.GOLD_300, (s - 0.5) * 2.0)


static func _scaled(src: PackedVector2Array, r: float) -> PackedVector2Array:
	var out: = PackedVector2Array()
	out.resize(src.size())
	for i in src.size():
		out[i] = src[i] * r
	return out


# vector fallback of `items/star` (drawn once per node, not per frame)
static func draw_star_lit(ci: CanvasItem, r: float) -> void:
	var g: = _geometry()
	var polys: Array = g.polys
	var cols: Array = g.cols
	for f in polys.size():
		ci.draw_polygon(_scaled(polys[f], r), cols[f])
	ci.draw_polyline(_scaled(g.closed, r), Color(V10DS.GOLD_700, 0.75), 1.0, true)
	# one spark, top left (HUD_V2 §4)
	var sp: = Vector2(-0.24, -0.3) * r
	var arm: = r * 0.3
	var w: = r * 0.05
	var c1: = Color(V10DS.PAPER_100, 0.92)
	var c0: = Color(V10DS.PAPER_100, 0.0)
	ci.draw_polygon(PackedVector2Array([sp + Vector2(-arm, 0), sp + Vector2(0, -w), sp + Vector2(arm, 0), sp + Vector2(0, w)]), PackedColorArray([c0, c1, c0, c1]))
	ci.draw_polygon(PackedVector2Array([sp + Vector2(0, -arm * 1.2), sp + Vector2(w, 0), sp + Vector2(0, arm * 1.2), sp + Vector2(-w, 0)]), PackedColorArray([c0, c1, c0, c1]))
	ci.draw_circle(sp, r * 0.06, c1, true, -1.0, true)


# vector fallback of `items/star_empty`: the socket of a star not earned (paper.700 silhouette, UX §6.4)
static func draw_star_empty(ci: CanvasItem, r: float) -> void:
	var g: = _geometry()
	ci.draw_colored_polygon(_scaled(g.contour, r), Color(V10DS.NIGHT_900, 0.42))
	ci.draw_polyline(_scaled(g.closed, r), V10DS.PAPER_700, 2.0, true)


class _Item:
	extends Node2D
	var tex: Texture2D
	var lit: = false
	var size: = 56.0

	func _draw() -> void:
		if tex:
			draw_texture_rect(tex, V10VictoryStars.art_rect(tex, size), false)
		elif lit:
			V10VictoryStars.draw_star_lit(self, size * V10VictoryStars.STAR_R)
		else:
			V10VictoryStars.draw_star_empty(self, size * V10VictoryStars.STAR_R)


class _Light:
	# every warm disc of the beat, additive, behind the stars; reads the owner's arrays (no allocation)
	extends Node2D
	var o: V10VictoryStars

	func _draw() -> void:
		var gt: = V10VictoryStars.glow_texture()
		for k in o.earned:
			var a: = o.glow_alpha(k)
			if a <= 0.0:
				continue
			var r: = o.glow_radius(k)
			draw_texture_rect(gt, Rect2(o.centers[k] - Vector2(r, r), Vector2(r, r) * 2.0), false, o.glow_color(k))


class _Dust:
	# every mote of the beat in one node, in front of the stars: a gold.300 grain in a soft gold.500 halo.
	# Normal blend on purpose: additive gold over her pink hair turns white.
	extends Node2D
	var o: V10VictoryStars

	func _draw() -> void:
		var gt: = V10VictoryStars.glow_texture()
		for i in o.d_n:
			var age: = o.d_age[i]
			var life: = o.d_life[i]
			if age >= life or age < 0.0:
				continue
			var k: = age / life
			var a: = minf(1.0, age / 0.05) * (1.0 - k) * (1.0 - k) * V10VictoryStars.DUST_A
			var p: = o.d_pos[i]
			var r: = o.d_rad[i] * (1.0 - 0.35 * k)
			draw_texture_rect(gt, Rect2(p - Vector2(r, r) * 2.5, Vector2(r, r) * 5.0), false, Color(V10DS.GOLD_500, a * 0.35))
			draw_circle(p, r, Color(V10DS.GOLD_300, a), true, -1.0, true)
