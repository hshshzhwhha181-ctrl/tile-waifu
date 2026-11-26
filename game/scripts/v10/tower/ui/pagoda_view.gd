class_name V10PagodaView
extends Control

# The scene of the Pagoda hub (spec R2, UX_RULES §2.3 «пустота — это роскошь»): one tall pagoda in three parallax
# layers. Swipe up / down to climb it; the far sky moves slower than the tower, the foreground branches faster.
#   Art (V10TowerArt, 720×2400): "pagoda_far" = sky, moon, misty ridges (opaque); "pagoda_mid" = the pagoda,
#   11 storeys (alpha); "pagoda_near" = pine / plum branches and lanterns on the edges (alpha, drawn ×1.3 from the
#   centre so they frame the screen and stay off the buttons). Five floors make one storey (the 5th is the Страж
#   on its roof), so the art holds floors 1–55 and the spire. Floors up to the record (at the chosen Жар) keep
#   their warm windows; everything above is dimmed to a moonlit silhouette — the tower lights up as you climb.
#   Without art the same picture is drawn here: night gradient, moon, ridges, a distant pagoda, mist, a tower
#   with one storey per floor, gold hairlines on the eaves, a paper lantern on each floor, a pine branch in front.
#
#   var v := V10PagodaView.new(); add_child(v); v.set_frame(scene_top, scene_bottom)
#   v.configure({lit_to, record_floor, run_floor, lives, lives_max, heat, locked})
#   v.scroll_to_floor(f, animate := true)    v.floor_y(f) -> screen y of the top of floor f    v.intro()
#   v.set_heat(h)  (embers on the edges from Жар 16, warm tint)    v.set_lit(n, record, animate := true)
#   v.marker_rects() -> [Rect2]  (the «Рекорд · этаж 14» / «Этаж 7» tags, for layout checks)
#
# Motion: the scene is still except the camera (swipe with inertia, the entry glide), the procedural lanterns'
# slow sway and the embers (Жар ≥ 16). fx "mid" halves the embers, fx "min" stops all motion (the embers become a
# still glow on the edges); no information is lost.

const TIER: = 116.0  # procedural: one floor of the tower
const BODY: = 100.0
const EAVE: = 188.0
const EAVE_GUARD: = 214.0
const K_FAR: = 0.14
const K_MID: = 0.42
const LANTERN_H: = 44.0
const EMBER_HEAT: = 16
# pagoda_mid.png (720×2400): the floor line of the ground storey, the 11 eave lines bottom-up, the spire tip
const ART_BASE: = 2300.0
const ART_ROOFS: = [1965.0, 1752.0, 1541.0, 1340.0, 1152.0, 971.0, 804.0, 644.0, 494.0, 350.0, 242.0]
const ART_TOP: = 5.0
const PER_STOREY: = 5
const NEAR_SCALE: = 1.3

var lit_to: = 0
var record_floor: = 0
var run_floor: = 0
var lives: = 0
var lives_max: = 3
var heat: = 0
var locked: = false
var scroll: = 0.0
var markers_on: = true  # the hub turns the tags off while a full-screen result sheet is up

var scene_top: = 88.0
var scene_bottom: = 1000.0

var _art: = false
var _vel: = 0.0
var _drag: = false
var _moved: = 0.0
var _glide: Tween
var _lit_k: = 1.0  # crossfade of the lit floors after a heat change
var _lit_from: = 0
var _t: = 0.0
var _fx: _Fx
var _rec: _Marker
var _run: _Marker
var _stars: = PackedVector3Array()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_meta("tw_surface", true)  # a swipe surface under the whole screen, not a button
	clip_contents = true
	var r: = RandomNumberGenerator.new()
	r.seed = 7151
	for i in 70:
		_stars.append(Vector3(r.randf(), r.randf(), r.randf()))


func _ready() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size
	_art = V10TowerArt.has("pagoda_mid")
	_fx = _Fx.new()
	_fx.v = self
	add_child(_fx)
	_rec = _Marker.new()
	_run = _Marker.new()
	for m in [_rec, _run]:
		m.visible = false
		add_child(m)
	get_viewport().size_changed.connect(_on_resize)
	_place_markers()


func _on_resize() -> void:
	size = get_viewport_rect().size
	_clamp()
	_changed()


# ---------------------------------------------------------------- api

func set_frame(top: float, bottom: float) -> void:
	scene_top = top
	scene_bottom = bottom
	_clamp()
	_changed()


func configure(d: Dictionary) -> void:
	lit_to = int(d.get("lit_to", lit_to))
	record_floor = int(d.get("record_floor", record_floor))
	run_floor = int(d.get("run_floor", run_floor))
	lives = int(d.get("lives", lives))
	lives_max = int(d.get("lives_max", lives_max))
	heat = int(d.get("heat", heat))
	locked = bool(d.get("locked", locked))
	_lit_k = 1.0
	_lit_from = lit_to
	_clamp()
	_changed()


func set_heat(h: int) -> void:
	heat = h
	_changed()


# relight the tower after the scroll changed the heat: the record of that heat crossfades in 420 ms
func set_lit(n: int, rec: int, animate: = true) -> void:
	_lit_from = lit_to
	lit_to = n
	record_floor = rec
	if animate and V10TowerUI.fx() != "min" and is_inside_tree() and _lit_from != n:
		_lit_k = 0.0
		var tw: = create_tween()
		tw.tween_method(func(v: float) -> void:
			_lit_k = v
			_changed(), 0.0, 1.0, 0.42).set_trans(Tween.TRANS_SINE)
	else:
		_lit_k = 1.0
	_clamp()
	_changed()


func ground_y0() -> float:
	return scene_bottom + 6.0


# art: y of a floor's top inside pagoda_mid.png (5 floors per storey, the spire above floor 55)
static func art_floor_y(f: float) -> float:
	if f <= 0.0:
		return ART_BASE
	var n: = ART_ROOFS.size() * PER_STOREY
	if f >= float(n):
		return lerpf(float(ART_ROOFS[ART_ROOFS.size() - 1]), 90.0, clampf((f - float(n)) / 30.0, 0.0, 1.0))
	var st: = int(floor((f - 0.0001) / PER_STOREY))
	var frac: = (f - float(st * PER_STOREY)) / float(PER_STOREY)
	var lo: float = ART_BASE if st == 0 else float(ART_ROOFS[st - 1])
	return lerpf(lo, float(ART_ROOFS[st]), frac)


func art_top_y() -> float:
	return ground_y0() - ART_BASE + scroll


func floor_y(f: float) -> float:
	if _art:
		return art_top_y() + art_floor_y(f)
	return ground_y0() - f * TIER + scroll


func top_floor() -> int:
	return maxi(maxi(lit_to, record_floor), maxi(run_floor, 6)) + 4


func max_scroll() -> float:
	if _art:
		# the spire tip can reach the top of the scene: the whole tower is there to explore
		return maxf(0.0, scene_top + 40.0 - ground_y0() + ART_BASE - ART_TOP)
	var focus_y: = scene_top + 0.3 * (scene_bottom - scene_top)
	return maxf(0.0, float(top_floor()) * TIER - (ground_y0() - focus_y))


# the floor the hub looks at: the run's floor, else the record, else the ground
func focus_floor() -> int:
	if run_floor > 0:
		return run_floor
	return record_floor


func scroll_for(f: float) -> float:
	var want: = scene_top + 0.46 * (scene_bottom - scene_top)
	return clampf(want - (floor_y(f) - scroll), 0.0, max_scroll())


func scroll_to_floor(f: float, animate: = true, secs: = 0.6) -> void:
	var target: = scroll_for(f)
	if _glide and _glide.is_valid():
		_glide.kill()
	_vel = 0.0
	if not animate or V10TowerUI.fx() == "min" or not is_inside_tree():
		scroll = target
		_changed()
		return
	_glide = create_tween()
	_glide.tween_method(func(v: float) -> void:
		scroll = v
		_changed(), scroll, target, secs).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN_OUT)


# the entry glide: the camera rises from a little below to the focus floor (scene motion, not UI)
func intro() -> void:
	var f: = focus_floor()
	var target: = scroll_for(f)
	if V10TowerUI.fx() == "min" or locked:
		scroll = target
		_changed()
		return
	scroll = maxf(0.0, target - 280.0)
	_changed()
	scroll_to_floor(f, true, 1.1)


func lantern_pos(f: int) -> Vector2:
	var y: = floor_y(f)
	var e: = EAVE_GUARD if _guard(f) else EAVE
	return Vector2(_tx() - e + 6.0, y + 6.0 + LANTERN_H * 0.5 + 10.0)


func _guard(f: int) -> bool:
	return f > 0 and f % 5 == 0


func _cx() -> float:
	return floorf(maxf(0.0, (size.x - 720.0) * 0.5))


func _tx() -> float:
	return _cx() + 470.0


func _clamp() -> void:
	scroll = clampf(scroll, 0.0, max_scroll())


func _changed() -> void:
	_place_markers()
	queue_redraw()
	if _fx:
		_fx.queue_redraw()


# ---------------------------------------------------------------- input: swipe with inertia

func _gui_input(e: InputEvent) -> void:
	if locked:
		return
	if e is InputEventScreenTouch or (e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT):
		_drag = e.pressed
		if e.pressed:
			_moved = 0.0
			_vel = 0.0
			if _glide and _glide.is_valid():
				_glide.kill()
		accept_event()
	elif e is InputEventScreenDrag or (e is InputEventMouseMotion and _drag):
		var dy: float = e.relative.y
		_moved += absf(dy)
		scroll = clampf(scroll + dy, -24.0, max_scroll() + 24.0)
		_vel = dy / maxf(0.001, get_process_delta_time())
		_changed()
		accept_event()
	elif e is InputEventMouseButton and e.pressed and e.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		scroll = clampf(scroll + (40.0 if e.button_index == MOUSE_BUTTON_WHEEL_UP else -40.0), 0.0, max_scroll())
		_changed()
		accept_event()


func _process(delta: float) -> void:
	_t += delta
	if not _drag:
		if absf(_vel) > 20.0:
			scroll += _vel * delta
			_vel *= pow(0.04, delta)
			if scroll < 0.0 or scroll > max_scroll():
				_vel *= 0.5
			_changed()
		elif scroll < 0.0 or scroll > max_scroll():
			scroll = lerpf(scroll, clampf(scroll, 0.0, max_scroll()), minf(1.0, delta * 12.0))
			if absf(scroll - clampf(scroll, 0.0, max_scroll())) < 0.5:
				_clamp()
			_changed()
	if _fx and _fx.animating():
		_fx.queue_redraw()


# ---------------------------------------------------------------- markers: small lacquer tags on the art

func _place_markers() -> void:
	if not is_instance_valid(_rec):
		return
	var cx: = _cx()
	var show_rec: = record_floor > 0 and not locked and markers_on
	var show_run: = run_floor > 0 and not locked and markers_on
	var ry: = floor_y(float(run_floor) - 0.5)
	if show_run and show_rec and absf(ry - floor_y(record_floor)) < 60.0:
		show_rec = false
	if show_rec:
		_rec.setup("Рекорд · этаж %d" % record_floor, 1, 1, false)
		var y: = floor_y(record_floor)
		_rec.position = Vector2(cx + 24.0, y - 24.0)
		show_rec = y > scene_top + 32.0 and y < scene_bottom - 32.0
	_rec.visible = show_rec
	if show_run:
		# the three starting lanterns (one with «Один фонарь»); blessings' extra lanterns show only once earned
		_run.setup("Этаж %d" % run_floor, maxi(1, maxi(lives, mini(3, lives_max))), lives, true)
		_run.position = Vector2(cx + 24.0, ry - 24.0)
		show_run = ry > scene_top + 32.0 and ry < scene_bottom - 32.0
	_run.visible = show_run


func set_markers(on: bool) -> void:
	markers_on = on
	_place_markers()
	if is_instance_valid(_fx):
		_fx.queue_redraw()


func marker_rects() -> Array:
	var out: = []
	for m in [_rec, _run]:
		if (m as Control).visible:
			out.append(Rect2((m as Control).global_position, (m as Control).size))
	return out


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	var W: = size.x
	var H: = size.y
	var cx: = _cx()
	var far: = V10TowerArt.tex("pagoda_far")
	var mid: = V10TowerArt.tex("pagoda_mid")
	var near: = V10TowerArt.tex("pagoda_near")
	if _art and mid:
		_draw_far_art(far, W, H)
		_heat_tint(W, H)
		_draw_tower_art(mid, W, H)
		if near:
			_draw_near_art(near, W, H)
		return
	_sky(W, H)
	_stars_draw(W, H)
	_moon(cx)
	_ridges(W, H, cx)
	_mid(W, H, cx)
	_tower(W, H, cx)


func _cover(t: Texture2D, W: float, k: = 1.0) -> Vector2:
	# the layer's drawn size: at least the screen width (tablets), ×k for the foreground
	var sc: = maxf(W / float(t.get_width()), 1.0) * k
	return Vector2(float(t.get_width()), float(t.get_height())) * sc


func _t01() -> float:
	var m: = max_scroll()
	return clampf(scroll / m, 0.0, 1.0) if m > 0.0 else 0.0


# far: bottom-aligned (misty ridges) at the foot of the tower, top-aligned (the moon) at the spire — it travels
# the whole of its height while the tower travels more: the sky moves slower
func _draw_far_art(t: Texture2D, W: float, H: float) -> void:
	if t == null:
		_sky(W, H)
		return
	var sz: = _cover(t, W)
	var y: = lerpf(H - sz.y, 0.0, _t01())
	var mod: = V10DS.TINT_SCENE if locked else Color.WHITE
	draw_texture_rect(t, Rect2((W - sz.x) * 0.5, y, sz.x, sz.y), false, mod)


func _heat_tint(W: float, H: float) -> void:
	if heat <= 0 or locked:
		return
	var hc: = V10TowerUI.heat_color(heat)
	var a: = 0.05 + 0.12 * clampf(float(heat) / 34.0, 0.0, 1.0)
	draw_polygon(PackedVector2Array([Vector2(0, H * 0.4), Vector2(W, H * 0.4), Vector2(W, H), Vector2(0, H)]),
			PackedColorArray([Color(hc, 0.0), Color(hc, 0.0), Color(hc, a), Color(hc, a)]))


# the tower: rows below the lit floor as painted (warm windows), rows above dimmed to a moonlit silhouette,
# a 72 px feather between them; locked = the whole tower as a dark silhouette
func _draw_tower_art(t: Texture2D, W: float, H: float) -> void:
	var sz: = _cover(t, W)
	var sc: = sz.x / float(t.get_width())
	var x0: = (W - sz.x) * 0.5
	var top: = ground_y0() - ART_BASE * sc + scroll
	var dim: = V10DS.TINT_SCENE.darkened(0.5)
	if locked:
		draw_texture_rect(t, Rect2(x0, top, sz.x, sz.y), false, V10DS.NIGHT_600.darkened(0.2))
		return
	var lit_art: = lerpf(art_floor_y(_lit_from), art_floor_y(lit_to), _lit_k)
	var feather: = 72.0
	var a0: = clampf(-top / sc, 0.0, float(t.get_height()))
	var a1: = clampf((H - top) / sc, 0.0, float(t.get_height()))
	_rows(t, x0, top, sc, a0, minf(a1, lit_art - feather), dim)
	var steps: = 12
	for i in steps:
		var r0: = lit_art - feather + feather * float(i) / steps
		var r1: = r0 + feather / steps
		_rows(t, x0, top, sc, maxf(a0, r0), minf(a1, r1), dim.lerp(Color.WHITE, (float(i) + 0.5) / steps))
	_rows(t, x0, top, sc, maxf(a0, lit_art), a1, Color.WHITE)


func _rows(t: Texture2D, x0: float, top: float, sc: float, r0: float, r1: float, mod: Color) -> void:
	if r1 <= r0:
		return
	var w: = float(t.get_width())
	draw_texture_rect_region(t, Rect2(x0, top + r0 * sc, w * sc, (r1 - r0) * sc), Rect2(0, r0, w, r1 - r0), mod)


# the foreground: ×1.3 from the centre (the branches stay on the edges, off the buttons), a little darker so the
# tower stays the subject; it travels faster than the tower (it is nearer), bottom-aligned at the foot
func _draw_near_art(t: Texture2D, W: float, H: float) -> void:
	var sz: = _cover(t, W, NEAR_SCALE)
	var m: = max_scroll()
	var k: = minf(1.25, (sz.y - H) / m) if m > 0.0 else 0.0
	var y: = minf(H - sz.y + scroll * k, 0.0)
	var mod: = V10DS.TINT_SCENE if locked else Color.WHITE.darkened(0.12)
	draw_texture_rect(t, Rect2((W - sz.x) * 0.5, y, sz.x, sz.y), false, mod)


func _sky(W: float, H: float) -> void:
	var top: = V10DS.NIGHT_900
	var low: = V10DS.NIGHT_700.lerp(V10TowerUI.LACQUER_HI, 0.35)
	var mid: = V10DS.NIGHT_800
	var hy: = H * 0.55
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(W, 0), Vector2(W, hy), Vector2(0, hy)]),
			PackedColorArray([top, top, mid, mid]))
	draw_polygon(PackedVector2Array([Vector2(0, hy), Vector2(W, hy), Vector2(W, H), Vector2(0, H)]),
			PackedColorArray([mid, mid, low, low]))
	# warmth of the heat: a faint glow from below (Жар 0 = none)
	if heat > 0 and not locked:
		var hc: = V10TowerUI.heat_color(heat)
		var a: = 0.04 + 0.1 * clampf(float(heat) / 34.0, 0.0, 1.0)
		draw_polygon(PackedVector2Array([Vector2(0, H * 0.45), Vector2(W, H * 0.45), Vector2(W, H), Vector2(0, H)]),
				PackedColorArray([Color(hc, 0.0), Color(hc, 0.0), Color(hc, a), Color(hc, a)]))


func _stars_draw(W: float, H: float) -> void:
	var span: = H * 1.4
	for s in _stars:
		var y: = fposmod(s.y * span + scroll * K_FAR * 0.6, span) - H * 0.2
		if y > scene_bottom - 120.0:
			continue
		var fade: = clampf((scene_bottom - 120.0 - y) / 300.0, 0.0, 1.0)
		var a: = (0.18 + 0.45 * s.z) * fade * (0.4 if locked else 1.0)
		draw_circle(Vector2(s.x * W, y), 0.8 + s.z * 0.9, Color(V10DS.PAPER_100, a), true, -1.0, true)


func _moon(cx: float) -> void:
	var c: = Vector2(cx + 616.0, scene_top + 170.0 + scroll * K_FAR)
	var r: = 92.0
	var a: = 0.35 if locked else 1.0
	for i in 6:
		draw_circle(c, r + 18.0 + i * 26.0, Color(V10TowerUI.MOON, 0.035 * a * (1.0 - i / 7.0)), true, -1.0, true)
	draw_circle(c, r, Color(V10TowerUI.MOON, 0.92 * a), true, -1.0, true)
	# soft maria: a few darker blots, a lacquer-print moon rather than a photo
	var blot: = Color(V10DS.PAPER_300, 0.55 * a)
	draw_circle(c + Vector2(-26, -18), 22.0, blot, true, -1.0, true)
	draw_circle(c + Vector2(18, 24), 16.0, blot, true, -1.0, true)
	draw_circle(c + Vector2(34, -30), 9.0, blot, true, -1.0, true)
	# a thin cloud across the moon
	var cy: = c.y + 30.0
	_cloud(Vector2(c.x - 170.0, cy), 300.0, 10.0, Color(V10DS.NIGHT_700, 0.85))
	_cloud(Vector2(c.x - 120.0, cy + 16.0), 210.0, 6.0, Color(V10DS.NIGHT_800, 0.7))


func _cloud(p: Vector2, w: float, h: float, col: Color) -> void:
	var pts: = PackedVector2Array()
	for i in 17:
		var t: = float(i) / 16.0
		pts.append(p + Vector2(w * t, -sin(t * PI) * h))
	for i in 17:
		var t: = 1.0 - float(i) / 16.0
		pts.append(p + Vector2(w * t, sin(t * PI) * h * 0.35))
	draw_colored_polygon(pts, col)


func _ridges(W: float, H: float, cx: float) -> void:
	var base: = ground_y0() + scroll * K_FAR
	var c1: = V10DS.NIGHT_700 if not locked else V10DS.NIGHT_800
	var c2: = V10DS.NIGHT_800
	_ridge(base - 150.0, W, [[0.0, 40.0], [0.12, -30.0], [0.26, 10.0], [0.4, -60.0], [0.55, -10.0], [0.7, -80.0], [0.86, -20.0], [1.0, -50.0]], Color(c1, 0.9), H)
	# mist band between the ridges
	var my: = base - 120.0
	draw_polygon(PackedVector2Array([Vector2(0, my - 40.0), Vector2(W, my - 40.0), Vector2(W, my + 30.0), Vector2(0, my + 30.0)]),
			PackedColorArray([Color(V10DS.PAPER_300, 0.0), Color(V10DS.PAPER_300, 0.0), Color(V10DS.PAPER_300, 0.05), Color(V10DS.PAPER_300, 0.05)]))
	_ridge(base - 70.0, W, [[0.0, -20.0], [0.18, 20.0], [0.34, -40.0], [0.5, 0.0], [0.66, -30.0], [0.82, 10.0], [1.0, -10.0]], c2, H)


func _ridge(y: float, W: float, pts: Array, col: Color, H: float) -> void:
	var poly: = PackedVector2Array()
	for i in range(pts.size() - 1):
		var a: Array = pts[i]
		var b: Array = pts[i + 1]
		for k in 8:
			var t: = float(k) / 8.0
			var tt: = t * t * (3.0 - 2.0 * t)
			poly.append(Vector2(lerpf(float(a[0]), float(b[0]), t) * W, y + lerpf(float(a[1]), float(b[1]), tt)))
	poly.append(Vector2(W, y + float(pts[pts.size() - 1][1])))
	poly.append(Vector2(W, H + 400.0))
	poly.append(Vector2(0, H + 400.0))
	draw_colored_polygon(poly, col)


func _mid(W: float, H: float, cx: float) -> void:
	var off: = scroll * K_MID
	var base: = ground_y0() + 30.0 + off
	# clouds passing as the camera climbs (every 520 px of the mid layer)
	for i in range(-1, 8):
		var y: = base - 380.0 - float(i) * 520.0
		if y < -60.0 or y > H + 60.0:
			continue
		var x: = cx + (40.0 if i % 2 == 0 else 330.0)
		_cloud(Vector2(x, y), 340.0, 12.0, Color(V10DS.PAPER_300, 0.035))
		_cloud(Vector2(x + 60.0, y + 14.0), 260.0, 6.0, Color(V10DS.PAPER_300, 0.025))
	if base - 260.0 > H:
		return
	# a distant small pagoda on the left hill + pines
	var col: = Color(V10DS.NIGHT_800, 0.96)
	var hill: = PackedVector2Array()
	for k in 25:
		var t: = float(k) / 24.0
		hill.append(Vector2(cx - 40.0 + t * 420.0, base - 40.0 - sin(t * PI) * 70.0 + t * 30.0))
	hill.append(Vector2(cx + 380.0, H + 400.0))
	hill.append(Vector2(cx - 40.0, H + 400.0))
	draw_colored_polygon(hill, col)
	var px: = cx + 128.0
	var py: = base - 104.0
	for lv in 3:
		var w: = 46.0 - lv * 9.0
		var y0: = py - lv * 34.0
		draw_rect(Rect2(px - w * 0.55, y0 - 22.0, w * 1.1, 22.0), Color(V10DS.NIGHT_700, 0.9))
		_roof(Vector2(px, y0 - 22.0), w, 12.0, Color(V10DS.NIGHT_800, 1.0), Color(V10DS.GOLD_700, 0.18), 1.0)
	draw_line(Vector2(px, py - 3 * 34.0 - 20.0), Vector2(px, py - 3 * 34.0 - 44.0), Color(V10DS.NIGHT_700, 0.9), 2.0, true)
	# a warm window far away
	draw_rect(Rect2(px - 6.0, py - 16.0, 12.0, 9.0), Color(V10TowerUI.LANTERN_GLOW, 0.0 if locked else 0.35))
	for tx in [cx + 40.0, cx + 70.0, cx + 236.0]:
		_pine(Vector2(tx, base - 46.0 - (tx - cx) * 0.06), 70.0 + fposmod(tx, 30.0), Color(V10DS.NIGHT_900, 0.85))


func _pine(foot: Vector2, h: float, col: Color) -> void:
	for i in 4:
		var y: = foot.y - h * (0.15 + 0.22 * i)
		var w: = h * (0.34 - 0.07 * i)
		draw_colored_polygon(PackedVector2Array([Vector2(foot.x - w, y + h * 0.16), Vector2(foot.x, y - h * 0.14), Vector2(foot.x + w, y + h * 0.16)]), col)
	draw_line(foot, foot + Vector2(0, -h * 0.2), col, 3.0)


# a pagoda roof: ridge centre c (the eave line), half width w, height h; underside hairline in `hair`
func _roof(c: Vector2, w: float, h: float, fill: Color, hair: Color, hair_w: = 1.5) -> PackedVector2Array:
	var top: = PackedVector2Array()
	var lo: = PackedVector2Array()
	var tip: = h * 0.5
	for i in 13:
		var t: = float(i) / 12.0
		# upper surface: tip -> ridge with a concave sweep
		top.append(Vector2(c.x - w + t * w * 0.42, c.y - tip - (h - tip) * (1.0 - pow(1.0 - t, 2.2))))
	for i in 13:
		var t: = float(i) / 12.0
		top.append(Vector2(c.x + w * 0.58 + t * w * 0.42, c.y - h + (h - tip) * pow(t, 2.2)))
	for i in 13:
		var t: = float(i) / 12.0
		# underside: tip curls up, the middle sags to the eave line
		lo.append(Vector2(c.x + w - t * w, c.y - tip * pow(1.0 - t, 2.0)))
	for i in range(1, 13):
		var t: = float(i) / 12.0
		lo.append(Vector2(c.x - t * w, c.y - tip * pow(t, 2.0)))
	var poly: = top.duplicate()
	poly.append_array(lo)
	draw_colored_polygon(poly, fill)
	if hair.a > 0.0:
		draw_polyline(lo, hair, hair_w, true)
	return lo


func _tower(W: float, H: float, cx: float) -> void:
	var tx: = _tx()
	var top_f: = top_floor()
	var g: = ground_y0() + scroll
	var wall: = V10DS.NIGHT_800
	var roof: = V10DS.NIGHT_900
	var sil: = Color(V10DS.PAPER_700, 0.16)
	# the stone base and steps (floor 0)
	if g - 40.0 < H:
		var bc: = sil if locked else V10DS.NIGHT_700
		draw_rect(Rect2(tx - 232.0, g, 464.0, 28.0), bc)
		draw_rect(Rect2(tx - 262.0, g + 28.0, 524.0, 26.0), sil if locked else V10DS.NIGHT_800)
		draw_rect(Rect2(tx - 292.0, g + 54.0, 584.0, 400.0), sil if locked else V10DS.NIGHT_900)
		if not locked:
			V10Plate.hairline(self, tx - 232.0, tx + 232.0, g + 0.5, Color(V10DS.GOLD_700, 0.3))
			V10Plate.hairline(self, tx - 262.0, tx + 262.0, g + 28.5, Color(V10DS.GOLD_700, 0.18))
			# two stone lanterns at the steps
			for sx in [-252.0, 252.0]:
				var p: = Vector2(tx + sx, g + 28.0)
				draw_rect(Rect2(p.x - 7.0, p.y - 40.0, 14.0, 40.0), V10DS.NIGHT_700)
				draw_rect(Rect2(p.x - 15.0, p.y - 58.0, 30.0, 18.0), V10DS.NIGHT_700)
				draw_rect(Rect2(p.x - 7.0, p.y - 54.0, 14.0, 10.0), Color(V10TowerUI.LANTERN_GLOW, 0.5))
				draw_colored_polygon(PackedVector2Array([p + Vector2(-20, -58), p + Vector2(0, -74), p + Vector2(20, -58)]), V10DS.NIGHT_800)
	# floors from the bottom up; only the visible ones
	var f0: = maxi(1, int(floor((g - H - TIER) / TIER)))
	var f1: = mini(top_f + 2, int(ceil((g + TIER) / TIER)) + 1)
	for f in range(f0, f1 + 1):
		var ye: = g - float(f) * TIER
		if ye > H + TIER or ye < -TIER * 1.5:
			continue
		var fade: = 1.0
		if f > top_f:
			fade = clampf(1.0 - float(f - top_f) / 2.5, 0.0, 1.0)
		if fade <= 0.0:
			continue
		var guard: = _guard(f)
		var e: = EAVE_GUARD if guard else EAVE
		var lit: = _lit_amount(f)
		# wall between this roof (ye) and the roof below (ye + TIER)
		var wy0: = ye + 4.0
		var wy1: = ye + TIER - 10.0
		if locked:
			draw_rect(Rect2(tx - BODY, wy0, BODY * 2.0, wy1 - wy0), sil)
			_roof(Vector2(tx, ye), e, 34.0, sil, Color(0, 0, 0, 0))
			continue
		draw_rect(Rect2(tx - BODY, wy0, BODY * 2.0, wy1 - wy0), Color(wall, fade))
		# windows: three lattice panels, warm when the floor is lit
		var pw: = (BODY * 2.0 - 40.0) / 3.0
		for k in 3:
			var x0: = tx - BODY + 10.0 + k * (pw + 10.0)
			var r: = Rect2(x0, wy0 + 18.0, pw, wy1 - wy0 - 48.0)
			var warm: = Color(V10TowerUI.LANTERN_GLOW, (0.07 + 0.17 * lit) * fade)
			draw_rect(r, warm if lit > 0.01 else Color(V10DS.NIGHT_700, 0.7 * fade))
			var lat: = Color(V10DS.NIGHT_900, 0.75 * fade)
			for q in 3:
				var lx: = r.position.x + r.size.x * (q + 1) / 4.0
				draw_line(Vector2(lx, r.position.y), Vector2(lx, r.end.y), lat, 2.0)
			for q in 2:
				var ly: = r.position.y + r.size.y * (q + 1) / 3.0
				draw_line(Vector2(r.position.x, ly), Vector2(r.end.x, ly), lat, 2.0)
		# columns and the shadow under the roof
		for k in 4:
			var px: = tx - BODY + 4.0 + k * (BODY * 2.0 - 8.0) / 3.0
			draw_line(Vector2(px, wy0), Vector2(px, wy1), Color(V10DS.NIGHT_900, 0.9 * fade), 5.0)
		draw_rect(Rect2(tx - BODY, wy0, BODY * 2.0, 12.0), Color(V10DS.NIGHT_900, 0.55 * fade))
		# the balcony rail at the foot of the floor
		var ry: = wy1 - 22.0
		draw_rect(Rect2(tx - BODY - 16.0, ry, BODY * 2.0 + 32.0, 7.0), Color(V10DS.NIGHT_900, fade))
		V10Plate.hairline(self, tx - BODY - 16.0, tx + BODY + 16.0, ry + 0.5, Color(V10DS.GOLD_700, 0.22 * fade))
		for k in 9:
			var bx: = tx - BODY - 12.0 + k * (BODY * 2.0 + 24.0) / 8.0
			draw_line(Vector2(bx, ry + 7.0), Vector2(bx, wy1), Color(V10DS.NIGHT_900, 0.8 * fade), 2.0)
		# the guard's seal on the wall (cinnabar = only seals)
		if guard:
			V10TowerUI.draw_seal(self, Vector2(tx, wy0 + 30.0), 11.0, Color(V10TowerUI.SEAL, 0.85 * fade))
		# the roof of this floor: gold hairline on the eave (the moonlit edge)
		var hair: = Color(V10DS.GOLD_700, (0.42 + 0.25 * lit) * fade)
		if guard:
			_roof(Vector2(tx, ye + 10.0), e - 18.0, 26.0, Color(roof, fade), Color(V10DS.GOLD_700, 0.25 * fade), 1.0)
		_roof(Vector2(tx, ye), e, 34.0, Color(roof, fade), hair, 1.5)
		# a bell on the right eave tip
		var bt: = Vector2(tx + e - 4.0, ye - 14.0)
		draw_line(bt, bt + Vector2(0, 12), Color(V10DS.GOLD_700, 0.5 * fade), 1.0, true)
		draw_circle(bt + Vector2(0, 15), 3.5, Color(V10DS.GOLD_700, 0.6 * fade), true, -1.0, true)
	# the top of what is known: the tower melts into mist above the last floors
	var mist_y: = g - float(top_f) * TIER
	if mist_y > -200.0:
		var c0: = Color(V10DS.NIGHT_900, 0.0)
		var c1: = Color(V10DS.NIGHT_800, 0.0)
		draw_polygon(PackedVector2Array([Vector2(0, mist_y - 260.0), Vector2(W, mist_y - 260.0), Vector2(W, mist_y - 60.0), Vector2(0, mist_y - 60.0)]),
				PackedColorArray([Color(V10DS.PAPER_300, 0.0), Color(V10DS.PAPER_300, 0.0), Color(V10DS.PAPER_300, 0.035), Color(V10DS.PAPER_300, 0.035)]))
		draw_polygon(PackedVector2Array([Vector2(0, mist_y - 60.0), Vector2(W, mist_y - 60.0), Vector2(W, mist_y + 60.0), Vector2(0, mist_y + 60.0)]),
				PackedColorArray([Color(V10DS.PAPER_300, 0.035), Color(V10DS.PAPER_300, 0.035), c0, c1]))


# 0..1: how lit floor f is (crossfades from the old to the new record after a heat change)
func _lit_amount(f: int) -> float:
	if locked:
		return 0.0
	var now: = 1.0 if f <= lit_to else 0.0
	var before: = 1.0 if f <= _lit_from else 0.0
	return lerpf(before, now, _lit_k)


# ---------------------------------------------------------------- the moving layer: lanterns, level lines, embers

class _Fx extends Control:
	var v: V10PagodaView
	var embers: = []  # [x, y, vy, life, max_life, size, sway_phase]
	var _rng: = RandomNumberGenerator.new()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_rng.seed = 2024

	func _ready() -> void:
		size = get_parent().size

	func ember_count() -> int:
		if v.locked or v.heat < V10PagodaView.EMBER_HEAT:
			return 0
		match V10TowerUI.fx():
			"min":
				return 0
			"mid":
				return 12
		return 24

	func animating() -> bool:
		return V10TowerUI.fx() != "min" and not v.locked and (ember_count() > 0 or not v._art)

	func _process(delta: float) -> void:
		size = v.size
		var want: = ember_count()
		while embers.size() < want:
			embers.append(_spawn(true))
		while embers.size() > want:
			embers.pop_back()
		for i in embers.size():
			var e: Array = embers[i]
			e[1] = float(e[1]) - float(e[2]) * delta
			e[3] = float(e[3]) + delta
			if float(e[3]) >= float(e[4]) or float(e[1]) < v.scene_top - 40.0:
				embers[i] = _spawn(false)

	func _spawn(anywhere: bool) -> Array:
		var W: = v.size.x
		var left: = _rng.randf() < 0.5
		var x: = _rng.randf_range(8.0, 104.0) if left else W - _rng.randf_range(8.0, 104.0)
		# born just above the bottom shade (the plates and the button sit below it), they cool off by mid-scene
		var y0: = v.scene_bottom - 8.0
		var y: = _rng.randf_range(maxf(v.scene_top + 80.0, y0 - 440.0), y0) if anywhere else y0 + _rng.randf_range(0.0, 24.0)
		var life: = _rng.randf_range(4.5, 8.0)
		return [x, y, _rng.randf_range(30.0, 58.0), _rng.randf_range(0.0, life * 0.6) if anywhere else 0.0, life,
			_rng.randf_range(2.2, 4.2), _rng.randf_range(0.0, TAU)]

	func _draw() -> void:
		var t: = v._t
		var calm: = V10TowerUI.fx() == "min"
		# procedural tower: a paper lantern on the left eave of every floor, a slow sway
		if not v.locked and not v._art:
			var g: = v.ground_y0() + v.scroll
			var top_f: = v.top_floor()
			var f0: = maxi(1, int(floor((g - v.size.y - V10PagodaView.TIER) / V10PagodaView.TIER)))
			var f1: = mini(top_f, int(ceil((g + V10PagodaView.TIER) / V10PagodaView.TIER)))
			for f in range(f0, f1 + 1):
				var p: = v.lantern_pos(f)
				if p.y < -60.0 or p.y > v.size.y + 60.0:
					continue
				var lit: = v._lit_amount(f)
				var h: = V10PagodaView.LANTERN_H * (1.18 if v._guard(f) else 1.0)
				var hook: = p - Vector2(0, h * 0.5 + 10.0)
				var ang: = 0.0 if calm else sin(t * 0.9 + f * 1.7) * 0.035
				draw_line(hook + Vector2(0, -6.0), hook + Vector2(0, 2.0), Color(V10DS.GOLD_700, 0.6), 1.0, true)
				draw_set_transform(hook, ang, Vector2.ONE)
				if f == v.run_floor:
					draw_arc(Vector2(0, h * 0.5 + 10.0), h * 0.74, 0.0, TAU, 48, Color(V10DS.GOLD_500, 0.55), 1.5, true)
				V10TowerUI.draw_lantern(self, Vector2(0, h * 0.5 + 10.0), h, lit)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# a gold level line from each tag across the tower: the height of the record / of the run
		for m in [v._rec, v._run]:
			var mk: Control = m
			if mk.visible:
				var y: = mk.position.y + mk.size.y * 0.5
				var x0: = mk.position.x + mk.size.x + 8.0
				var x1: = v._cx() + 696.0 if v._art else v.lantern_pos(v.record_floor if mk == v._rec else v.run_floor).x - 24.0
				if x1 > x0 + 24.0:
					V10Plate.hairline(self, x0, x1, y + 0.5, Color(V10DS.GOLD_500, 0.55))
		# the edges glow with the heat (still), embers rise along them (moving)
		if not v.locked and v.heat >= V10PagodaView.EMBER_HEAT:
			var k: = clampf(float(v.heat - V10PagodaView.EMBER_HEAT) / 16.0, 0.0, 1.0)
			var gc: = V10TowerUI.heat_color(v.heat)
			var a: = 0.22 + 0.16 * k
			var gw: = 120.0
			# the glow is hottest where the scene meets the bottom shade and cools upwards; below it stays warm
			var yb: = v.scene_bottom
			for side in [0, 1]:
				var x0: = 0.0 if side == 0 else v.size.x
				var x1: = gw if side == 0 else v.size.x - gw
				var ym: = lerpf(v.scene_top, yb, 0.45)
				draw_polygon(PackedVector2Array([Vector2(x0, ym), Vector2(x1, ym), Vector2(x1, yb), Vector2(x0, yb)]),
						PackedColorArray([Color(gc, 0.0), Color(gc, 0.0), Color(gc, 0.0), Color(gc, a)]))
				draw_polygon(PackedVector2Array([Vector2(x0, yb), Vector2(x1, yb), Vector2(x1, v.size.y), Vector2(x0, v.size.y)]),
						PackedColorArray([Color(gc, a), Color(gc, 0.0), Color(gc, 0.0), Color(gc, a * 0.7)]))
			for e in embers:
				var life: = float(e[3]) / float(e[4])
				var fade_a: = sin(life * PI)
				var x: = float(e[0]) + sin(t * 1.3 + float(e[6])) * 7.0
				var p: = Vector2(x, float(e[1]))
				var c: = V10TowerUI.LANTERN_LIT.lerp(V10TowerUI.EMBER_HI, minf(1.0, life * 1.6)).lerp(V10TowerUI.SEAL, maxf(0.0, life - 0.5))
				draw_circle(p, float(e[5]) * 4.0, Color(c, 0.1 * fade_a), true, -1.0, true)
				draw_circle(p, float(e[5]) * 2.0, Color(c, 0.22 * fade_a), true, -1.0, true)
				draw_circle(p, float(e[5]), Color(c, fade_a), true, -1.0, true)
		# procedural: a pine branch in front, top right under the header (the art has its own foreground)
		if not v._art:
			_branch(Vector2(v.size.x + 10.0, v.scene_top + 46.0))

	func _branch(root: Vector2) -> void:
		var col: = V10DS.NIGHT_900
		var pts: = PackedVector2Array()
		for i in 13:
			var t: = float(i) / 12.0
			pts.append(root + Vector2(-t * 210.0, t * 40.0 - sin(t * PI) * 22.0))
		draw_polyline(pts, col, 7.0, true)
		draw_polyline(pts.slice(6), col, 4.0, true)
		# needle clusters
		for i in [2, 4, 6, 8, 10, 12]:
			var p: = pts[i]
			var r: = 26.0 - float(i) * 0.8
			for k in 9:
				var a: = -PI * 0.95 + k * (PI * 0.95) / 8.0
				var d: = Vector2(cos(a), sin(a) * 0.55 + 0.25)
				draw_line(p, p + d * r, col, 2.5, true)
			for k in 7:
				var a2: = PI * 0.15 + k * (PI * 0.7) / 6.0
				draw_line(p, p + Vector2(cos(a2), sin(a2)) * r * 0.7, col, 2.5, true)


# a tag on the art: a lacquer S plate (48) with paper lanterns and one line — «Рекорд · этаж 14» (a lit lantern
# before the text) or «Этаж 7» (the run's lanterns after it: lit = left, dark = gone). Readable over any art.
class _Marker extends Control:
	var _l: Label
	var _n: = 1
	var _lit: = 1
	var _after: = false
	var _key: = ""
	var _lx: = 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_l = V10TowerUI.label("", "ui", 22, V10DS.PAPER_100)
		add_child(_l)

	func setup(text: String, n: int, lit: int, after: bool) -> void:
		var key: = "%s|%d|%d|%s" % [text, n, lit, after]
		if key == _key:
			return
		_key = key
		_n = n
		_lit = lit
		_after = after
		_l.text = text
		var tw: = ceilf(V10Type.text_w(text, "ui", 22))
		var lw: = float(n) * 28.0
		if after:
			_l.position = Vector2(16, 0)
			_lx = 16.0 + tw + 14.0
		else:
			_lx = 14.0
			_l.position = Vector2(14.0 + lw + 6.0, 0)
		_l.size = Vector2(tw + 4.0, 48.0)
		size = Vector2(16.0 + tw + 14.0 + lw + 12.0, 48.0)
		queue_redraw()

	func _draw() -> void:
		V10Plate.draw_surface(self, Rect2(Vector2.ZERO, size), true)
		for i in _n:
			var c: = Vector2(_lx + 13.0 + i * 28.0, 23.0)
			var on: = i < _lit
			V10TowerUI.draw_lantern(self, c, 30.0, 1.0 if on else 0.0)
			if not on:
				# a spent lantern keeps its outline, so it reads as a lantern, not a bar
				var pts: = PackedVector2Array()
				for k in 33:
					var a: = TAU * float(k) / 32.0
					pts.append(c + Vector2(cos(a) * 30.0 * 0.31, sin(a) * 30.0 * 0.36))
				draw_polyline(pts, Color(V10DS.GOLD_700, 0.8), 1.5, true)
