class_name V7Combo
extends Control

# V7Combo — the combo ladder and the fever of a match (docs/0.9-spec.md §D). One per play screen (play.v7combo),
# fed by play._on_match → on_match(mid, n, gain). Everything here is HUD-edge or table-frame decoration: it takes
# no taps (MOUSE_FILTER_IGNORE) and never draws over a tile.
#
#   plaque     the combo pill in the HUD row (PILL_RECT): grows with the tier (PILL_W0 → full width), turns the
#              tier colour, beads on its lower rim count the tiers, a white flash + sheen on each tier step; the
#              fill under the title is the time left in the combo window. Never scaled past 1.0.
#   frame      the table frame glows in the tier colour (layers grow outward from the tile bounds + 34 px).
#   edges      tier ≥ «Цветение» (×5): a flash at the left / right screen edges on the tier step, a soft beat on
#              each pair from ×8 on (V9Feel.can_edge_flash: «Эффекты: полные» only).
#   aura       from ×3 the heroine's portrait card glows in her signature colour (G.HEROES[h].color) and sheds
#              sparks from its rim; it swells on each pair (V9Feel.can_fx; sparks × fx_scale).
#   fever      readable without sound: the frame burns orange-gold with lights running round it, embers rise along
#              the frame sides (not across the table), the pill reads «Лихорадка · кристаллы ×2 · 6 с», and the
#              last 2 s blink. It is the only fever decor: play._fever has no full-screen vignette or embers (0.9).
#   shake / sound / haptic   V6Fx.combo_tier (light shake by tier, full only), V9Feel.tile_match in the board
#              (semitone pitch ladder + combo haptic in step with each pair).
#   «Эффекты: минимум»   the pill, a steady frame line in the tier / fever colour: information only.
#
# Dev: --v9_combo_shots=3,5,8 --shots=<dir> [--name=n] saves <dir>/<n>_c<k>.png 0.14 s after the pair that makes
# combo k (play it with --v6fx_play=1); --v9_combo_after=<s> adds one more <n>_after.png s seconds after the last;
# --v9_combo_quit=1 quits after it; --v9_fx=full|mid|min sets «Эффекты» for the run.

const TIERS: = [
	[2, "Дуэт", Color("ffd98a")],
	[3, "Трио", Color("ffc46b")],
	[4, "Каскад", Color("ff9fbf")],
	[5, "Цветение", Color("ff6f9f")],
	[8, "Небесный поток", Color("b99bff")],
	[12, "Лунная буря", Color("7fe0ff")],
	[16, "Пять ветров", Color("9fffd0")],
]

# 0.8: the pill sits in the HUD row between the gem counter (ends x 126, room for a 4–5 digit value) and the
# passive chip (x 404), above the tray frame (y ≈ 176), and takes the note slot while a combo runs (the note is
# hidden meanwhile, _hide_notes); see the layout note in play.gd. 0.9: it is PILL_W0 wide on the first tier and
# reaches the full rect on the top tier, centred; it is never scaled past 1.0, so its box stays inside this rect.
const PILL_RECT: = Rect2(134, 122, 262, 52)
const PILL_W0: = 198.0
const FEVER_COL: = Color("ff8a3c")
const FEVER_GOLD: = Color("ffd34d")
const EDGE_W: = 30.0

var play
var pill: Control
var pill_lbl: Label
var pill_sub: Label
var col: = Color("ffd98a")
var glow: = 0.0
var glow_target: = 0.0
var shown: = false
var last_n: = 0
var best: = 0
var stopped: = false
var sub_hold_until: = 0.0
var tier_i: = -1
var pill_w: = PILL_W0
var _w_tw: Tween
var flash_k: = 0.0
var sheen_t: = -1.0
var edge_k: = 0.0
var edge_col: = Color("ff6f9f")
var aura: = 0.0
var aura_kick: = 0.0
var aura_t: = 0.0
var hero_col: = Color("ff8fb8")
var fever_on: = false
var fever_k: = 0.0
var fever_left: = 0.0
var _fever_sec: = -1
var _sb_frame: = StyleBoxFlat.new()
var _sb_pill: = StyleBoxFlat.new()
var _sb_fill: = StyleBoxFlat.new()
var _sb_hi: = StyleBoxFlat.new()
var glow_layer: Node2D
var _embers: Array[CPUParticles2D] = []
var _aura_p: CPUParticles2D
var _dev: = {}

func setup(p) -> V7Combo:
	play = p
	name = "V7Combo"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 28
	size = p.size
	var hid: = str(p.get("partner")) if p.get("partner") != null else "mc"
	if G.HEROES.has(hid):
		hero_col = G.HEROES[hid].color
	_sb_frame.bg_color = Color(0, 0, 0, 0)
	_sb_frame.set_corner_radius_all(30)
	_sb_frame.anti_aliasing = true
	_sb_pill.set_corner_radius_all(26)
	_sb_pill.bg_color = Color(0.09, 0.07, 0.11, 0.93)
	_sb_pill.set_border_width_all(3)
	_sb_pill.shadow_size = 10
	_sb_fill.set_corner_radius_all(22)
	_sb_hi.corner_radius_top_left = 22
	_sb_hi.corner_radius_top_right = 22
	# additive layer: frame glow, screen edges, aura, sheen (above the pill box, under the pill text)
	glow_layer = Node2D.new()
	glow_layer.name = "Glow"
	var am: = CanvasItemMaterial.new()
	am.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow_layer.material = am
	glow_layer.draw.connect(_draw_glow)
	add_child(glow_layer)
	# 0.8: the pill lives in the HUD row under the goal plate (PILL_RECT), with its milestone line inside it,
	# so it never covers a tile row of the table
	pill = Control.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.size = Vector2(PILL_W0, PILL_RECT.size.y)
	pill.pivot_offset = pill.size * 0.5
	pill.visible = false
	add_child(pill)
	# 0.9: one family for every tier (the body face: Playfair only fits the 52 px plate at 24+ px and spilled out
	# of it, and the long tier names fell back to the body face anyway); title and sub-line both inside the rim
	pill_lbl = UI.label("", 22, Color.WHITE, Color(0.1, 0.03, 0.12), 4, "body", 900)
	pill_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill_lbl.position = Vector2(0, 3)
	pill_lbl.size = Vector2(PILL_W0, 26)
	pill_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pill_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pill.add_child(pill_lbl)
	pill_sub = UI.label("", 16, Color("ffe7a6"), Color(0.1, 0.03, 0.12), 4, "body", 900)
	pill_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill_sub.position = Vector2(0, 26)
	pill_sub.size = Vector2(PILL_W0, 20)
	pill_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pill_sub.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pill_sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	pill_sub.clip_text = true
	pill.add_child(pill_sub)
	_place_pill()
	_dev_setup()
	return self

# 0.9: the glow lives on the lacquer table frame itself (V6BoardTable.frame_rect: the art's outer edge), not on a
# rectangle that followed the tile cloud — only its intensity changes with the tier, never its size or place
func _frame_rect() -> Rect2:
	var r: Rect2 = play.board_rect
	if play.board and is_instance_valid(play.board):
		var tb = play.board.get_node_or_null("V6Table")
		if tb and tb.get("frame_rect") is Rect2 and (tb.frame_rect as Rect2).size.x > 0.0:
			r = tb.frame_rect
	return r

func _tier(n: int) -> Array:
	return TIERS[_tier_index(n)]

static func _tier_index(n: int) -> int:
	var i: = 0
	for k in TIERS.size():
		if n >= int(TIERS[k][0]):
			i = k
	return i

# the pill width of a tier: PILL_W0 on «Дуэт», the whole PILL_RECT on the top tier
static func tier_width(i: int) -> float:
	return lerpf(PILL_W0, PILL_RECT.size.x, clampf(float(i) / float(TIERS.size() - 1), 0.0, 1.0))

func _left_frac() -> float:
	var b: TrayBoard = play.board
	if b == null or b.combo < 2:
		return 0.0
	return clampf(1.0 - (b.now() - b.last_match) / maxf(0.5, b.combo_window), 0.0, 1.0)

# 0.8: the final result window hides the combo pill and the board glow at once (no «×22» over the stars).
func stop() -> void :
	stopped = true
	shown = false
	last_n = 0
	glow = 0.0
	glow_target = 0.0
	edge_k = 0.0
	aura = 0.0
	fever_k = 0.0
	fever_on = false
	tier_i = -1
	if pill:
		pill.visible = false
	_set_embers(false)
	if _aura_p:
		_aura_p.emitting = false
	visible = false
	queue_redraw()

func resume() -> void :
	stopped = false
	visible = true

func _fever_now() -> bool:
	var fu = play.get("fever_until")
	return fu != null and float(play.now()) < float(fu)

func _process(dt: float) -> void :
	if stopped:
		return
	if play == null or not is_instance_valid(play.board):
		return
	var b: TrayBoard = play.board
	var alive: = b.combo >= 2 and _left_frac() > 0.0
	var fev: = _fever_now()
	if fev != fever_on:
		fever_on = fev
		_on_fever(fev)
	if fev:
		fever_left = float(play.fever_until) - float(play.now())
	fever_k = move_toward(fever_k, 1.0 if fev else 0.0, dt * (3.0 if fev else 1.5))
	var want: = alive or fev
	if want != shown:
		shown = want
		if want:
			_pill_in()
		else:
			_pill_out()
	if alive != (tier_i >= 0):
		if not alive:
			tier_i = -1
	if fev and not alive and shown:
		_fever_pill()
	elif fev and alive:
		_fever_sub()
	glow_target = 0.0 if not alive else clampf(0.3 + 0.1 * (b.combo - 2), 0.3, 1.0)
	glow = move_toward(glow, glow_target, dt * (2.5 if glow_target > glow else 1.2))
	flash_k = move_toward(flash_k, 0.0, dt * 4.5)
	edge_k = move_toward(edge_k, 0.0, dt * 2.2)
	aura_kick = move_toward(aura_kick, 0.0, dt * 2.5)
	if sheen_t >= 0.0:
		sheen_t += dt / 0.5
		if sheen_t > 1.0:
			sheen_t = -1.0
	# the heroine's aura: from ×3, swelling with the combo; sparks from her card rim in her colour
	var aura_target: = 0.0
	if alive and b.combo >= 3 and V9Feel.can_fx():
		aura_target = clampf(0.35 + (b.combo - 3) * 0.08, 0.35, 1.0)
	aura = move_toward(aura, aura_target, dt * (2.0 if aura_target > aura else 1.0))
	_update_aura_particles(dt)
	_set_embers(fever_k > 0.3 and V9Feel.can_fx())
	_place_pill()
	queue_redraw()
	glow_layer.queue_redraw()

# ---- drawing ----------------------------------------------------------------------------------------------------

func _draw() -> void :
	if stopped:
		return
	if pill.visible:
		var pr: = _pill_rect()
		var pc: = _pill_col()
		var a: = pill.modulate.a
		var ti: = maxi(tier_i, 0)
		_sb_pill.bg_color = Color(0.09, 0.07, 0.11, 0.97 * a)
		_sb_pill.border_color = Color(pc.r, pc.g, pc.b, a)
		_sb_pill.set_border_width_all(3 if ti < 4 else 4)
		_sb_pill.shadow_size = 8 + ti * 2 + int(8.0 * flash_k)
		_sb_pill.shadow_color = Color(pc.r, pc.g, pc.b, (0.38 + 0.05 * ti + 0.3 * flash_k) * a)
		draw_style_box(_sb_pill, pr)
		# tier tint inside: a lacquer top half in the tier colour
		var hr: = Rect2(pr.position + Vector2(4, 4), Vector2(pr.size.x - 8, pr.size.y * 0.46))
		_sb_hi.bg_color = Color(pc.r, pc.g, pc.b, (0.1 + 0.025 * ti) * a)
		draw_style_box(_sb_hi, hr)
		var f: = _left_frac()
		if f > 0.0:
			var ir: = pr.grow(-5)
			ir.size.x *= f
			_sb_fill.bg_color = Color(pc.r, pc.g, pc.b, 0.4 * a)
			draw_style_box(_sb_fill, ir)
			# 0.9: a soft leading edge in the tier colour (a 16 px gradient) — a hard white line ran through
			# the title like a rendering seam. The fill sits under the labels (they are the pill's children).
			if f < 0.995:
				var ex: = ir.end.x
				var ec: = pc.lightened(0.3)
				var x0: = maxf(ir.position.x, ex - 16.0)
				var y0: = ir.position.y + 4.0
				var y1: = ir.end.y - 4.0
				var c0: = Color(ec.r, ec.g, ec.b, 0.0)
				var c1: = Color(ec.r, ec.g, ec.b, 0.26 * a)
				draw_polygon(PackedVector2Array([Vector2(x0, y0), Vector2(ex, y0), Vector2(ex, y1), Vector2(x0, y1)]),
					PackedColorArray([c0, c1, c1, c0]))
		# beads just under the lower rim (clear of the sub-line): one per tier reached
		if tier_i >= 0:
			var nb: = tier_i + 1
			var gap: = 13.0
			var y: = pr.end.y + 5.0
			var x0: = pr.get_center().x - (nb - 1) * gap * 0.5
			for i in nb:
				var c: Color = TIERS[i][2]
				_bead(Vector2(x0 + i * gap, y), 4.6, c.lightened(0.2), a)

func _bead(p: Vector2, r: float, c: Color, a: float) -> void :
	var pts: = PackedVector2Array([p + Vector2(0, - r - 1.5), p + Vector2(r + 1.5, 0), p + Vector2(0, r + 1.5), p + Vector2( - r - 1.5, 0)])
	draw_colored_polygon(pts, Color(0.08, 0.04, 0.1, 0.95 * a))
	pts = PackedVector2Array([p + Vector2(0, - r), p + Vector2(r, 0), p + Vector2(0, r), p + Vector2( - r, 0)])
	draw_colored_polygon(pts, Color(c.r, c.g, c.b, a))
	draw_circle(p + Vector2(-1, -1.2), r * 0.32, Color(1, 1, 1, 0.75 * a))

func _draw_glow() -> void :
	if stopped:
		return
	var L: Node2D = glow_layer
	var lvl: = V9Feel.level()
	var r: = _frame_rect()
	var fk: = fever_k
	# the table frame: tier colour while a combo runs, burning orange-gold in a fever
	var amount: = maxf(glow, fk * 0.85)
	if amount > 0.01:
		var c: = col.lerp(_fever_col(), fk)
		# every stroke stays on the frame band (outer edge → V6BoardTable.FRAME inwards): it lights the lacquer
		# and never spills past the art onto the room or onto the felt
		var fw: = V6BoardTable.FRAME
		if lvl == "min":
			_sb_frame.set_border_width_all(3)
			_sb_frame.set_corner_radius_all(18)
			_sb_frame.border_color = Color(c.r, c.g, c.b, 0.7 * minf(1.0, amount * 1.6))
			L.draw_style_box(_sb_frame, r.grow(-3))
		else:
			var speed: = 4.0 + amount * 6.0
			var pulse: = 0.72 + 0.28 * sin(G.time * speed)
			if fk > 0.5 and fever_left < 2.0 and fever_left > 0.0:
				pulse *= 0.55 + 0.45 * (0.5 + 0.5 * sin(G.time * 18.0))
			var layers: = 4
			for i in layers:
				var k: = 1.0 - float(i) / layers
				_sb_frame.set_border_width_all(4)
				_sb_frame.border_color = Color(c.r, c.g, c.b, 0.6 * amount * pulse * k)
				_sb_frame.set_corner_radius_all(maxi(6, 18 - i * 3))
				L.draw_style_box(_sb_frame, r.grow(-2.0 - i * 4.0))
			# the frame's inner lip in a light tint of the tier colour (was a white line)
			var lip: = c.lightened(0.35)
			_sb_frame.set_corner_radius_all(8)
			_sb_frame.set_border_width_all(2)
			_sb_frame.border_color = Color(lip.r, lip.g, lip.b, 0.4 * amount * pulse)
			L.draw_style_box(_sb_frame, r.grow(-fw + 1.0))
			if fk > 0.05:
				_draw_fever_lights(L, r.grow(-fw * 0.5), fk)
	# the screen edges (full effects only): a flash on a tier step, a soft beat on each pair from ×8
	if edge_k > 0.01 and V9Feel.can_edge_flash():
		_draw_edges(L, edge_col, edge_k)
	# the heroine's aura round her portrait card
	if aura > 0.01 and play.stage and is_instance_valid(play.stage) and play.stage.visible:
		var sr: = _stage_rect()
		var k2: = clampf(aura + aura_kick * 0.6, 0.0, 1.3)
		var pl: = 0.75 + 0.25 * sin(G.time * (3.0 + aura * 4.0))
		var n: = 3 + int(k2 * 4)
		for i in n:
			var kk: = 1.0 - float(i) / n
			_sb_frame.set_border_width_all(3)
			_sb_frame.border_color = Color(hero_col.r, hero_col.g, hero_col.b, 0.55 * k2 * pl * kk * kk)
			_sb_frame.set_corner_radius_all(26 + i * 3)
			L.draw_style_box(_sb_frame, _grow_card(sr, 2 + i * 3))
	# the pill: a white flash and a sheen across it on a tier step
	if pill.visible:
		var pr: = _pill_rect()
		var a: = pill.modulate.a
		if flash_k > 0.01:
			_sb_fill.bg_color = Color(1, 1, 1, 0.13 * flash_k * a)
			L.draw_style_box(_sb_fill, pr.grow(-3))
		if sheen_t >= 0.0 and lvl != "min":
			_draw_sheen(L, pr.grow(-4), sheen_t, a)

func _draw_edges(L: Node2D, c: Color, k: float) -> void :
	var vh: = size.y
	var rows: = 8
	for side in 2:
		var x0: = 0.0 if side == 0 else size.x
		var x1: = EDGE_W if side == 0 else size.x - EDGE_W
		for j in rows:
			var y0: = vh * j / rows
			var y1: = vh * (j + 1) / rows
			var a0: = 0.75 * k * (0.35 + 0.65 * sin(PI * float(j) / rows))
			var a1: = 0.75 * k * (0.35 + 0.65 * sin(PI * float(j + 1) / rows))
			var pts: = PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)])
			var cols: = PackedColorArray([Color(c.r, c.g, c.b, a0), Color(c.r, c.g, c.b, 0.0), Color(c.r, c.g, c.b, 0.0), Color(c.r, c.g, c.b, a1)])
			L.draw_polygon(pts, cols)

# lights running round the frame in a fever (decor: not at «минимум»)
func _draw_fever_lights(L: Node2D, r: Rect2, k: float) -> void :
	var per: = 2.0 * (r.size.x + r.size.y)
	var n: = 26
	var tex: = G.fx("glow")
	var ph: = fmod(G.time * 150.0, per / n)
	for i in n:
		var d: = fmod(ph + i * per / n, per)
		var p: = _perimeter(r, d)
		var c: = FEVER_GOLD if i % 2 == 0 else FEVER_COL
		var s: = 18.0 + 4.0 * sin(G.time * 7.0 + i)
		L.draw_texture_rect(tex, Rect2(p - Vector2(s, s) * 0.5, Vector2(s, s)), false, Color(c.r, c.g, c.b, 0.85 * k))

func _perimeter(r: Rect2, d: float) -> Vector2:
	if d < r.size.x:
		return Vector2(r.position.x + d, r.position.y)
	d -= r.size.x
	if d < r.size.y:
		return Vector2(r.end.x, r.position.y + d)
	d -= r.size.y
	if d < r.size.x:
		return Vector2(r.end.x - d, r.end.y)
	d -= r.size.x
	return Vector2(r.position.x, r.end.y - d)

func _draw_sheen(L: Node2D, pr: Rect2, t: float, a: float) -> void :
	var bw: = 30.0
	var sl: = 16.0
	var x: = lerpf(pr.position.x - bw, pr.end.x + sl, t)
	var lo: = pr.position.x
	var hi: = pr.end.x
	var pts: = PackedVector2Array([
		Vector2(clampf(x, lo, hi), pr.position.y), Vector2(clampf(x + bw, lo, hi), pr.position.y),
		Vector2(clampf(x + bw - sl, lo, hi), pr.end.y), Vector2(clampf(x - sl, lo, hi), pr.end.y)])
	if pts[1].x - pts[0].x < 1.0 and pts[2].x - pts[3].x < 1.0:
		return
	L.draw_colored_polygon(pts, Color(1, 1, 1, 0.3 * a * sin(PI * t)))

func _stage_rect() -> Rect2:
	var st: Control = play.stage
	var xf: = get_global_transform_with_canvas().affine_inverse() * st.get_global_transform_with_canvas()
	return Rect2(xf * Vector2.ZERO, xf.basis_xform(st.size))

# the aura grows out of the card more to the sides and the top than downwards (the table frame starts under it)
func _grow_card(r: Rect2, g: float) -> Rect2:
	return r.grow_individual(g, g, g, g * 0.45)

func _pill_rect() -> Rect2:
	var pr: = Rect2(pill.position, pill.size)
	var c: = pr.get_center()
	var sz: = pr.size * pill.scale
	return Rect2(c - sz * 0.5, sz)

func _fever_col() -> Color:
	return FEVER_COL.lerp(FEVER_GOLD, 0.5 + 0.5 * sin(G.time * 5.0))

func _pill_col() -> Color:
	if fever_on and tier_i < 0:
		return _fever_col()
	return col

# ---- particles: heroine aura sparks, fever embers on the frame sides -------------------------------------------

func _update_aura_particles(dt: float) -> void :
	if aura <= 0.05 or not play.stage or not is_instance_valid(play.stage):
		if _aura_p:
			_aura_p.emitting = false
		return
	if _aura_p == null:
		_aura_p = Fx.particles("sparkle", 24, 1.1)
		_aura_p.material = Fx.add_mat()
		_aura_p.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINTS
		_aura_p.direction = Vector2(0, -1)
		_aura_p.spread = 35
		_aura_p.gravity = Vector2(0, -50)
		_aura_p.initial_velocity_min = 20
		_aura_p.initial_velocity_max = 70
		_aura_p.scale_amount_min = 0.08
		_aura_p.scale_amount_max = 0.22
		_aura_p.angular_velocity_min = -120
		_aura_p.angular_velocity_max = 120
		_aura_p.color_ramp = Fx._grad([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
		glow_layer.add_child(_aura_p)
	var sr: = _grow_card(_stage_rect(), 4)
	# points on the top edge and the upper two thirds of the sides (sparks rise away from the table)
	var pts: = PackedVector2Array()
	for i in 12:
		pts.append(Vector2(lerpf(sr.position.x + 16, sr.end.x - 16, i / 11.0), sr.position.y))
	for i in 8:
		var y: = lerpf(sr.position.y + 10, sr.position.y + sr.size.y * 0.66, i / 7.0)
		pts.append(Vector2(sr.position.x, y))
		pts.append(Vector2(sr.end.x, y))
	_aura_p.emission_points = pts
	_aura_p.color = hero_col.lightened(0.25)
	var amt: = Fx.scaled(int(10 + 22 * aura))
	if amt <= 0:
		_aura_p.emitting = false
		return
	if _aura_p.amount != amt:
		_aura_p.amount = amt
	_aura_p.emitting = true

func _set_embers(on: bool) -> void :
	if on and _embers.is_empty():
		for side in 2:
			var p: = Fx.particles("glow", 18, 1.5)
			p.material = Fx.add_mat()
			p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
			p.direction = Vector2(0, -1)
			p.spread = 12
			p.gravity = Vector2(0, -60)
			p.initial_velocity_min = 50
			p.initial_velocity_max = 140
			p.scale_amount_min = 0.05
			p.scale_amount_max = 0.13
			p.color = FEVER_COL
			p.color_ramp = Fx._grad([Color(1, 0.85, 0.4, 0), Color(1, 0.9, 0.5, 1), Color(1, 0.55, 0.2, 0.8), Color(1, 0.4, 0.1, 0)])
			p.emitting = false
			glow_layer.add_child(p)
			_embers.append(p)
	if _embers.is_empty():
		return
	var r: = _frame_rect()
	for i in _embers.size():
		var p: CPUParticles2D = _embers[i]
		p.position = Vector2(r.position.x + 6.0 if i == 0 else r.end.x - 6.0, r.get_center().y + 30.0)
		p.emission_rect_extents = Vector2(5, r.size.y * 0.46)
		var amt: = Fx.scaled(18)
		if on and amt > 0 and p.amount != amt:
			p.amount = amt
		p.emitting = on and amt > 0

# ---- pill -------------------------------------------------------------------------------------------------------

func _place_pill() -> void :
	var w: = clampf(pill_w, PILL_W0 * 0.9, PILL_RECT.size.x)
	pill.size = Vector2(w, PILL_RECT.size.y)
	pill.pivot_offset = pill.size * 0.5
	pill.position = Vector2(PILL_RECT.position.x + (PILL_RECT.size.x - w) * 0.5, PILL_RECT.position.y)
	pill_lbl.size.x = w
	pill_sub.size.x = w

func _set_width(w: float, animate: bool) -> void :
	if _w_tw and _w_tw.is_valid():
		_w_tw.kill()
	if not animate:
		pill_w = w
		return
	_w_tw = create_tween()
	# a little overshoot reads as «grew»; _place_pill clamps it to PILL_RECT
	_w_tw.tween_property(self, "pill_w", w, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# 0.8: the label draws from its LabelSettings (UI.label), which win over theme overrides — so font, size and
# colour are set on label_settings, not with add_theme_*_override
func _fit_title(room: = -1.0) -> void :
	if room < 0.0:
		room = tier_width(maxi(tier_i, 0)) - 24.0
	# one family on every tier (0.9): only the size steps down for a long tier name
	var f: = UI.font("body", 900)
	var fs: = 22
	while fs > 17 and f.get_string_size(pill_lbl.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > room:
		fs -= 1
	var ls: LabelSettings = pill_lbl.label_settings
	if ls.font != f or ls.font_size != fs:
		ls.font = f
		ls.font_size = fs
		ls.outline_size = 4

# The pill takes the note slot (V8_NOTE_RECT in play.gd) while a combo runs: the luck / style note under it is
# hidden, not drawn through the pill, and comes back when the pill has gone (play.v8_note hides a new note too).
func _hide_notes(h: bool) -> void :
	if not is_inside_tree():
		return
	for n in get_tree().get_nodes_in_group("v8_note"):
		if is_instance_valid(n) and n is CanvasItem:
			(n as CanvasItem).visible = not h

func _pill_in() -> void :
	_hide_notes(true)
	pill.visible = true
	pill.modulate.a = 0.0
	# fade in at full size: a scale-in would overshoot the HUD row and shrink the 16 px sub-line
	pill.scale = Vector2.ONE
	var t: = pill.create_tween()
	t.tween_property(pill, "modulate:a", 1.0, 0.14)

func _pill_out() -> void :
	var n: = last_n
	if n >= 5 and n > best:
		best = n
		Fx.float_text(play.fx_layer, pill.position + pill.size * 0.5 + Vector2(0, 30), "Серия ×%d" % n, col, 30)
	var t: = pill.create_tween().set_parallel()
	t.tween_property(pill, "modulate:a", 0.0, 0.3)
	t.tween_property(pill, "scale", Vector2(0.8, 0.8), 0.3)
	t.chain().tween_callback( func():
		if not shown:
			pill.visible = false
			pill.scale = Vector2.ONE
			if not stopped:
				_hide_notes(false))
	last_n = 0
	tier_i = -1

# the pill while only the fever runs (the combo broke): «Лихорадка» and the seconds left
func _fever_pill() -> void :
	if pill_lbl.text != "Лихорадка":
		pill_lbl.text = "Лихорадка"
		_set_width(tier_width(3), true)
		_fit_title(tier_width(3) - 24.0)
	pill_lbl.label_settings.font_color = _fever_col().lightened(0.3)
	var s: = maxi(1, int(ceil(fever_left)))
	if s != _fever_sec or not pill_sub.text.begins_with("кристаллы"):
		_fever_sec = s
		pill_sub.text = "кристаллы ×2 · %d с" % s
		pill_sub.label_settings.font_color = FEVER_GOLD

# fever on top of a running combo: the sub-line says it (unless a milestone line holds the slot)
func _fever_sub() -> void :
	if G.time < sub_hold_until:
		return
	var s: = maxi(1, int(ceil(fever_left)))
	var mult: = (1 + (last_n - 1) / 2) * 2
	var t: = "лихорадка · ×%d · %d с" % [mult, s]
	if pill_sub.text != t:
		pill_sub.text = t
		pill_sub.label_settings.font_color = FEVER_GOLD

func _on_fever(on: bool) -> void :
	_fever_sec = -1
	if on:
		edge_col = FEVER_COL
		edge_k = maxf(edge_k, 1.0)
		flash_k = 1.0
		sheen_t = 0.0
		if V9Feel.can_fx() and pill.visible:
			Fx.ring(play.fx_layer, pill.position + pill.size * 0.5, Color(FEVER_GOLD.r, FEVER_GOLD.g, FEVER_GOLD.b, 0.8), 1.1, 0.45)

func on_match(mid: Vector2, n: int, gain: int) -> void :
	if n < 2 or stopped:
		return
	last_n = n
	var ti: = _tier_index(n)
	var t: Array = TIERS[ti]
	col = t[2]
	var up: = ti > tier_i
	if not shown:
		shown = true
		_pill_in()
	if up:
		_set_width(tier_width(ti), tier_i >= 0)
		tier_i = ti
		_tier_up(ti, n)
	pill_lbl.text = "×%d · %s" % [n, t[1]]
	_fit_title()
	pill_lbl.label_settings.font_color = col.lightened(0.35)
	var mult: = 1 + (n - 1) / 2
	if G.time >= sub_hold_until:
		if fever_on:
			_fever_sub()
		else:
			pill_sub.text = "кристаллы ×%d" % mult if mult > 1 else "держи темп"
			pill_sub.label_settings.font_color = Color("ffe7a6")
	# punch the title only: the pill box itself never grows past PILL_RECT
	UI.punch(pill_lbl, 0.1 + mini(n, 10) * 0.01)
	aura_kick = 1.0
	if ti >= 4:
		edge_col = col
		edge_k = maxf(edge_k, 0.42)

	var dst: = pill.position + pill.size * 0.5
	if V9Feel.can_fx():
		_spark(mid, dst)
	# a ring the size of the pill (not a halo over the HUD row and the tray)
	Fx.ring(play.fx_layer, dst, Color(col.r, col.g, col.b, 0.7), 0.7 + mini(n, 12) * 0.04, 0.35)
	if n in [3, 5, 8, 12, 16] or (n >= 20 and n % 5 == 0):
		_milestone(n, dst)
	_dev_shot(n)

# a new tier: the pill flashes, a sheen runs across it, it grows; from «Цветение» the screen edges flash
func _tier_up(ti: int, n: int) -> void :
	flash_k = 1.0
	sheen_t = 0.0
	if ti >= 3:
		edge_col = col
		edge_k = 1.0
	if ti >= 2 and play.stage and is_instance_valid(play.stage) and V9Feel.can_fx():
		var sr: = _stage_rect()
		Fx.burst(play.fx_layer, Vector2(sr.get_center().x, sr.position.y + 8), "sparkle", 10 + ti * 3, hero_col.lightened(0.3), 0.7)

func _spark(from: Vector2, to: Vector2) -> void :
	var s: = Sprite2D.new()
	s.texture = G.fx("sparkle")
	s.material = Fx.add_mat()
	s.modulate = col
	s.scale = Vector2(0.5, 0.5)
	s.position = from
	play.fx_layer.add_child(s)
	var mid: = from.lerp(to, 0.5) + Vector2(randf_range(-80, 80), -60)
	var tw: = s.create_tween()
	tw.tween_method( func(k: float): s.position = from.lerp(mid, k).lerp(mid.lerp(to, k), k), 0.0, 1.0, 0.32).set_ease(Tween.EASE_IN)
	tw.tween_callback(s.queue_free)

func _milestone(n: int, at: Vector2) -> void :
	var st = play.stage
	if st:
		st.react("big")
		# 0.9: a compact milestone at the portrait (the HUD corner was filling up with rings, confetti and halos)
		Fx.burst(play.fx_layer, st.head_pos(), "heart", 5 + mini(n, 8) / 2, hero_col.lightened(0.2), 0.9)
		if V9Feel.can_fx():
			Fx.flash_glow(play.fx_layer, st.head_pos(), Color(V9Cutin.flash_color(hero_col), 0.8), 1.6, 0.4)
	var what: = ""
	var icon: = ""
	var target: Control = null
	var trial: = str(play.get("mode")) == "trial"
	match n:
		# 0.9 (HEROINES.md §2): the Ultimate charges +1 per pair, with no link to the combo — so ×3 no longer adds
		# to it; it pays a few crystals instead
		3:
			if not trial:
				G.S.gems += 5
				play.gained += 5
			what = "+5 кристаллов"
			icon = "gem"
			target = play.gems_lbl
		5:
			what = "Лихорадка: кристаллы ×2"
			icon = "gem"
		8:
			play.hint_n += 1
			what = "+1 подсказка"
			icon = "hint"
			target = play.btn_hint
		12:
			play.shuffle_n += 1
			what = "+1 перемешивание"
			icon = "shuffle"
			target = play.btn_shuffle
		16:
			play.undo_n += 1
			what = "+1 возврат"
			icon = "undo"
			target = play.btn_undo
		_:
			var g: = 10 + n
			if not trial:
				G.S.gems += g
				play.gained += g
			what = "+%d %s" % [g, V8PlayRules.plural(g, "кристалл", "кристалла", "кристаллов")]
			icon = "gem"
			target = play.gems_lbl
	if what == "":
		return
	# 0.8: the milestone reward is said inside the pill (its second line), not as a float that would rise into
	# the yaku plaque or the luck strip
	_set_sub(what, "Лихорадка ×2" if n == 5 else "")
	pill_sub.label_settings.font_color = Color("9fe8d0")
	sub_hold_until = G.time + 1.4
	UI.punch(pill_sub, 0.15)
	if icon != "" and target and is_instance_valid(target):
		var ic: = Sprite2D.new()
		# 0.8 art: currencies from cur/*, the rest from icon/* (V8Art caches them)
		ic.texture = V8Art.cur(icon) if icon in ["gem", "coin", "ticket"] else V8Art.icon(icon)
		ic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		ic.scale = Vector2.ONE * (56.0 / maxf(1.0, ic.texture.get_width()))
		ic.position = at
		ic.z_index = 46
		play.fx_layer.add_child(ic)
		# 0.10 M0: the HUD target's viewport point in the fx layer's coordinates (the screen sits in the content column)
		var to: Vector2 = V10Layout.local_of(play.fx_layer, target.get_global_rect().get_center())
		var tw: = ic.create_tween()
		tw.tween_property(ic, "position", at + Vector2(0, -40), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(ic, "position", to, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(ic, "scale", ic.scale * 0.6, 0.45)
		tw.tween_callback( func():
			Fx.ring(play.fx_layer, to, col, 1.2, 0.35)
			Sfx.play("pop", 1.2)
			if is_instance_valid(target):
				UI.punch(target, 0.25)
			if play.has_method("_refresh"):
				play._refresh()
			ic.queue_free())

# the sub-line is 16 px (the floor for Russian text) and never trims: a line that does not fit the pill takes its
# short form (or loses its tail after « · »)
func _set_sub(t: String, short: = "") -> void :
	var f: = UI.font("body", 900)
	var room: = pill.size.x - 20.0
	if f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x > room:
		if short != "":
			t = short
		elif " · " in t:
			t = t.substr(0, t.rfind(" · "))
	pill_sub.text = t

# ---- dev screenshots ----------------------------------------------------------------------------------------------

func _dev_setup() -> void :
	for s in OS.get_cmdline_user_args():
		if s.begins_with("--") and "=" in s:
			var kv: = s.substr(2).split("=", true, 1)
			_dev[kv[0]] = kv[1]
	# --v9_fx=full|mid|min: «Эффекты» for this dev run (screenshots of each level)
	if _dev.has("v9_fx") and String(_dev.v9_fx) in G.FX_LEVELS:
		# a dev run never writes its effect level into the player's save
		if not String(G.save_path).begins_with("user://dev_"):
			G.save_path = "user://dev_v9_fx.json"
		G.set_fx_level(String(_dev.v9_fx))
	if not (_dev.has("v9_combo_shots") and _dev.has("shots")):
		_dev = {}
		return
	_dev["want"] = Array(String(_dev.v9_combo_shots).split(",")).map( func(x): return int(x))
	_dev["done"] = {}

func _dev_shot(n: int) -> void :
	if _dev.is_empty() or not (n in _dev.want) or _dev.done.has(n):
		return
	_dev.done[n] = true
	var last: bool = (_dev.done as Dictionary).size() == (_dev.want as Array).size()
	await get_tree().create_timer(0.14).timeout
	await RenderingServer.frame_post_draw
	var nm: = String(_dev.get("name", "combo"))
	get_viewport().get_texture().get_image().save_png("%s/%s_c%d.png" % [_dev.shots, nm, n])
	print("V9COMBO shot c%d" % n)
	if not last:
		return
	if _dev.has("v9_combo_after"):
		await get_tree().create_timer(float(_dev.v9_combo_after)).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%s_after.png" % [_dev.shots, nm])
		print("V9COMBO shot after")
	if _dev.get("v9_combo_quit", "") == "1":
		get_tree().quit()
