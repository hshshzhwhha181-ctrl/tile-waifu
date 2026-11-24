class_name V10Juice
extends RefCounted

# V10Juice — 0.10 juice library (static, no autoload). One place for the «дорого и сочно» layer on top of V9Feel /
# V6Fx: tab transitions, tile-match effects, combo milestones, fever aura, ult heartbeat, reward fountains, roll-ups,
# chest and rank reveals, idle sparkles, heroine entrance and a shader set. Integration calls per screen:
# scripts/v10/juice/README.md. Showcase: scripts/v10/juice/demo/juice_demo.tscn.
#
# RULES (HEROINES §2, 0.9 review):
#   * no white flashes: every light is warm, additive layers are capped (≤ 0.85 alpha, colour ≤ 0.8 value);
#   * nothing covers the middle of the board: match effects stay ≈ 1.5 tiles wide, the fever aura is drawn
#     only outside the frame, banners go into the rect the caller gives (HUD strip);
#   * S.fx_level through V9Feel: «полные» everything; «умеренные» particles × 0.55, no shake, fewer layers;
#     «минимум» only what carries information (banner text, counters, ult-ready outline), no particles;
#   * budget for a mid Android phone (GL Compatibility): see BUDGET; CPUParticles2D only (no GPU particle
#     shader compile hitch on GLES3, and one-shots ≤ 40 particles are cheaper on CPU); shards and fountains are
#     drawn by one node each (one canvas item, one _process), not a node per piece.

const SH: = "res://shaders/v10/"
const SFX: = "res://scripts/v10/juice/sfx/%s.ogg"
const LAYER_FX: = 70
const LAYER_TOP: = 96

# live caps per level: one-shot emitters, particles alive, full-screen shader overlays
const BUDGET: = {
	"full": {"emitters": 18, "particles": 420, "overlays": 5},
	"mid": {"emitters": 9, "particles": 200, "overlays": 3},
	"min": {"emitters": 0, "particles": 0, "overlays": 1},
}

# juice sound → fallback in assets/sfx (Sfx.play) when the juice file is missing
const SOUND_FALLBACK: = {
	"jade_shatter": "match3", "ink_splash": "pop", "gold_ripple": "sparkle", "stamp_thud": "combo",
	"brush_swoosh": "whoosh", "trans_ink": "whoosh", "trans_lantern": "whoosh", "trans_petal": "whoosh",
	"fever_ignite": "fever", "ult_heartbeat": "tap", "rank_gong": "reveal_ssr", "chest_open": "reveal_sr",
	"coin_tick": "gem", "gem_tick": "gem", "rollup": "tap", "twinkle": "sparkle", "heroine_enter": "sparkle",
}

# suit colours for ink splashes (G.CATS: Букет, Небосвод, Сладкоежка, Сокровищница, Зверинец)
const SUIT_INK: = [Color(0.72, 0.18, 0.3), Color(0.2, 0.3, 0.7), Color(0.9, 0.44, 0.3), Color(0.86, 0.62, 0.16), Color(0.1, 0.55, 0.42)]
const GOLD: = Color(1.0, 0.8, 0.4)
const JADE: = Color(0.34, 0.72, 0.56)
const IVORY: = Color(0.96, 0.93, 0.85)

const MILESTONES: = {5: ["Цветение", Color(0.86, 0.36, 0.52)], 10: ["Лунная буря", Color(0.34, 0.6, 0.9)], 20: ["Пять ветров", Color(0.3, 0.75, 0.55)]}

static var live_emitters: = 0
static var live_particles: = 0
static var live_overlays: = 0
static var _layers: = {}
static var _players: Array = []
static var _streams: = {}
static var _shaders: = {}
static var forced_level: = ""   # demo / tests: override S.fx_level without touching the save


# ── level gates ──────────────────────────────────────────────────────────────────────────────────────────────

static func level() -> String:
	if forced_level != "":
		return forced_level
	return V9Feel.level()


static func can_fx() -> bool:
	return level() != "min"


# BENCHMARK MD-6: a separate «Без тряски и вспышек» switch (save key `a11y_calm`), independent of the FX level
static func calm() -> bool:
	return G.S is Dictionary and bool(G.S.get("a11y_calm", false))


static func can_shake() -> bool:
	return level() == "full" and not calm()


static func scale() -> float:
	match level():
		"mid":
			return 0.55
		"min":
			return 0.0
	return 1.0


static func n(count: int) -> int:
	var k: = scale()
	if k <= 0.0 or count <= 0:
		return 0
	return maxi(1, int(round(count * k)))


static func budget(key: String) -> int:
	return int(BUDGET.get(level(), BUDGET.full)[key])


# ── tree helpers ─────────────────────────────────────────────────────────────────────────────────────────────

static func tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


static func vp_size() -> Vector2:
	var t: = tree()
	if t == null or t.root == null:
		return Vector2(720, 1280)
	return t.root.get_visible_rect().size


# the juice CanvasLayer: "fx" (70, above screens, popups and V6Fx grade) or "top" (96, transitions)
static func layer(which: = "fx") -> CanvasLayer:
	var l = _layers.get(which)
	if l != null and is_instance_valid(l) and l.is_inside_tree():
		return l
	var t: = tree()
	var cl: = CanvasLayer.new()
	cl.name = "V10Juice_" + which
	cl.layer = LAYER_TOP if which == "top" else LAYER_FX
	cl.process_mode = Node.PROCESS_MODE_ALWAYS
	t.root.add_child.call_deferred(cl)
	_layers[which] = cl
	return cl


# create the layers, the sound players and the transition curtain ahead of time (call deferred from main._ready):
# the first effect then needs no tree change, and its sound is not lost
static func warm() -> void:
	layer("fx")
	V10JuiceTransition.get_or_make()
	sound("", 1.0, -80.0)
	for s in SOUND_FALLBACK:
		_stream(s)


static func host(parent: Node) -> Node:
	if parent != null and is_instance_valid(parent):
		return parent
	return layer("fx")


static func shader(name: String) -> Shader:
	if not _shaders.has(name):
		_shaders[name] = load(SH + name + ".gdshader")
	return _shaders[name]


static func mat(name: String, params: = {}) -> ShaderMaterial:
	var m: = ShaderMaterial.new()
	m.shader = shader(name)
	for k in params:
		m.set_shader_parameter(k, params[k])
	return m


static func rect(parent: Node, r: Rect2, shader_name: String, params: = {}) -> ColorRect:
	var c: = ColorRect.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.position = r.position
	c.size = r.size
	c.color = Color.WHITE
	c.material = mat(shader_name, params)
	host(parent).add_child(c)
	return c


static func param(c: CanvasItem, key: String, v) -> void:
	if is_instance_valid(c) and c.material is ShaderMaterial:
		(c.material as ShaderMaterial).set_shader_parameter(key, v)


# tween a shader parameter of `c` from a to b; returns the tween (bound to c)
static func tween_param(c: CanvasItem, key: String, a: float, b: float, dur: float, trans: = Tween.TRANS_SINE, ease: = Tween.EASE_OUT) -> Tween:
	var t: = c.create_tween()
	t.tween_method(func(v): param(c, key, v), a, b, dur).set_trans(trans).set_ease(ease)
	return t


static func add_mat() -> CanvasItemMaterial:
	return Fx.add_mat()


static func global_center(c: CanvasItem) -> Vector2:
	if c is Control:
		return (c as Control).get_global_rect().get_center()
	if c is Node2D:
		return (c as Node2D).global_position
	return vp_size() * 0.5


# ── sound ────────────────────────────────────────────────────────────────────────────────────────────────────

static func _stream(name: String) -> AudioStream:
	if not _streams.has(name):
		var p: = SFX % name
		_streams[name] = load(p) if ResourceLoader.exists(p) else null
	return _streams[name]


static func sound(name: String, pitch: = 1.0, db: = 0.0) -> void:
	var t: = tree()
	if t == null:
		return
	if name == "":
		# warm(): only build the player pool
		if _players.is_empty():
			_make_players()
		return
	if G.S is Dictionary and not G.S.get("sound", true):
		return
	var st: = _stream(name)
	if st == null:
		V9Feel.sound(SOUND_FALLBACK.get(name, ""), pitch, db)
		return
	if _players.is_empty() or not is_instance_valid(_players[0]):
		_make_players()
	var pl: AudioStreamPlayer = null
	for q in _players:
		if q.is_inside_tree() and not q.playing:
			pl = q
			break
	if pl == null:
		pl = _players[0]
		if not pl.is_inside_tree():
			# the very first frame (players are added deferred): the stock sound instead of silence
			V9Feel.sound(SOUND_FALLBACK.get(name, ""), pitch, db)
			return
	pl.stream = st
	pl.pitch_scale = pitch
	pl.volume_db = db
	pl.play()


static func _make_players() -> void:
	_players.clear()
	var holder: = layer("fx")
	var bus: = "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"
	for i in 10:
		var p: = AudioStreamPlayer.new()
		p.bus = bus
		holder.add_child.call_deferred(p)
		_players.append(p)


static func sound_later(name: String, delay: float, pitch: = 1.0, db: = 0.0) -> void:
	tree().create_timer(delay, true, false, true).timeout.connect(func(): sound(name, pitch, db))


static func shake(amount: float) -> void:
	if not can_shake():
		return
	var fx = tree().root.get_node_or_null("V6Fx")
	if fx and fx.has_method("shake"):
		fx.shake(amount)


static func haptic(kind: String) -> void:
	V9Feel.haptic(kind)


# ── particles (CPU, one-shot, budgeted) ──────────────────────────────────────────────────────────────────────
# presets: "star4" twinkles, "mote" rising soft dots, "petal" falling petals, "ember" rising sparks,
#          "spark" fast short streaks, "ink" heavy droplets with gravity, "confetti_gold" slow gold flakes

static func burst(parent: Node, pos: Vector2, preset: = "star4", count: = 12, color: = GOLD, power: = 1.0, extent: = Vector2.ZERO, dir: = Vector2.ZERO) -> CPUParticles2D:
	count = n(count)
	if count <= 0 or live_emitters >= budget("emitters") or live_particles + count > budget("particles"):
		return null
	var p: = CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 0.92
	p.amount = count
	p.local_coords = false
	p.position = pos
	p.color = color
	p.spread = 180.0
	var fade: = Fx._grad([Color(1, 1, 1, 1), Color(1, 1, 1, 0.85), Color(1, 1, 1, 0)])
	p.color_ramp = fade
	match preset:
		"star4":
			p.texture = V10JuiceTex.get_tex("star4")
			p.material = add_mat()
			p.lifetime = 0.75
			p.initial_velocity_min = 60.0 * power
			p.initial_velocity_max = 280.0 * power
			p.damping_min = 220.0
			p.damping_max = 420.0
			p.scale_amount_min = 0.25
			p.scale_amount_max = 0.65
			p.angular_velocity_min = -160.0
			p.angular_velocity_max = 160.0
			p.scale_amount_curve = Fx._curve([Vector2(0, 0.2), Vector2(0.2, 1.0), Vector2(1, 0)])
		"mote":
			p.texture = V10JuiceTex.get_tex("dot")
			p.material = add_mat()
			p.lifetime = 1.4
			p.explosiveness = 0.5
			p.direction = Vector2(0, -1)
			p.spread = 30.0
			p.gravity = Vector2(0, -40)
			p.initial_velocity_min = 40.0 * power
			p.initial_velocity_max = 170.0 * power
			p.scale_amount_min = 0.2
			p.scale_amount_max = 0.55
		"petal":
			p.texture = G.fx("petal")
			p.lifetime = 2.2
			p.explosiveness = 0.35
			p.direction = Vector2(0.3, 1)
			p.spread = 40.0
			p.gravity = Vector2(30, 140)
			p.initial_velocity_min = 60.0 * power
			p.initial_velocity_max = 200.0 * power
			p.damping_min = 20.0
			p.damping_max = 60.0
			p.angle_min = 0.0
			p.angle_max = 360.0
			p.angular_velocity_min = -200.0
			p.angular_velocity_max = 200.0
			p.scale_amount_min = 0.28
			p.scale_amount_max = 0.55
			p.color_ramp = Fx._grad([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
		"ember":
			p.texture = V10JuiceTex.get_tex("ember")
			p.material = add_mat()
			p.lifetime = 1.0
			p.explosiveness = 0.2
			p.direction = Vector2(0, -1)
			p.spread = 22.0
			p.gravity = Vector2(0, -120)
			p.particle_flag_align_y = true
			p.initial_velocity_min = 80.0 * power
			p.initial_velocity_max = 220.0 * power
			p.scale_amount_min = 0.35
			p.scale_amount_max = 0.8
		"spark":
			p.texture = V10JuiceTex.get_tex("ember")
			p.material = add_mat()
			p.lifetime = 0.45
			p.particle_flag_align_y = true
			p.initial_velocity_min = 320.0 * power
			p.initial_velocity_max = 760.0 * power
			p.damping_min = 900.0
			p.damping_max = 1400.0
			p.scale_amount_min = 0.4
			p.scale_amount_max = 0.9
		"ink":
			p.texture = V10JuiceTex.get_tex("dot")
			p.lifetime = 0.6
			p.gravity = Vector2(0, 900)
			p.initial_velocity_min = 160.0 * power
			p.initial_velocity_max = 420.0 * power
			p.damping_min = 120.0
			p.damping_max = 260.0
			p.scale_amount_min = 0.18
			p.scale_amount_max = 0.45
			p.color_ramp = Fx._grad([Color(1, 1, 1, 0.95), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0)])
		"confetti_gold":
			p.texture = V10JuiceTex.get_tex("star4")
			p.material = add_mat()
			p.lifetime = 1.8
			p.direction = Vector2(0, -1)
			p.spread = 55.0
			p.gravity = Vector2(0, 260)
			p.initial_velocity_min = 240.0 * power
			p.initial_velocity_max = 560.0 * power
			p.damping_min = 80.0
			p.damping_max = 160.0
			p.angular_velocity_min = -300.0
			p.angular_velocity_max = 300.0
			p.scale_amount_min = 0.2
			p.scale_amount_max = 0.45
	if extent != Vector2.ZERO:
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		p.emission_rect_extents = extent
	if dir != Vector2.ZERO:
		p.direction = dir
	host(parent).add_child(p)
	p.emitting = true
	live_emitters += 1
	live_particles += count
	p.finished.connect(func():
		live_emitters -= 1
		live_particles -= count
		p.queue_free())
	return p


# soft additive glow sprite that blooms and fades (warm, capped alpha)
static func glow(parent: Node, pos: Vector2, color: = GOLD, size: = 1.6, dur: = 0.35, alpha: = 0.7) -> void:
	if not can_fx():
		return
	var s: = Sprite2D.new()
	s.texture = G.fx("glow")
	s.material = add_mat()
	s.position = pos
	s.modulate = Color(color.r, color.g, color.b, alpha)
	s.scale = Vector2.ONE * size * 0.35
	host(parent).add_child(s)
	var t: = s.create_tween().set_parallel()
	t.tween_property(s, "scale", Vector2.ONE * size, dur).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	t.tween_property(s, "modulate:a", 0.0, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.chain().tween_callback(s.queue_free)


# expanding warm ripple ring (juice_ring) of `radius` px
static func ripple(parent: Node, pos: Vector2, color: = GOLD, radius: = 120.0, dur: = 0.55, thickness: = 0.06) -> void:
	if not can_fx() or live_overlays >= budget("overlays") + 4:
		return
	var r: = rect(parent, Rect2(pos - Vector2(radius, radius), Vector2(radius, radius) * 2.0), "juice_ring",
		{"color": color, "t": 0.0, "thickness": thickness})
	live_overlays += 1
	var t: = tween_param(r, "t", 0.0, 1.0, dur, Tween.TRANS_LINEAR)
	t.tween_callback(func():
		live_overlays -= 1
		r.queue_free())


# ── 1. tab transitions ───────────────────────────────────────────────────────────────────────────────────────
# await V10Juice.cover("ink")  → swap the screen →  V10Juice.reveal()
# styles: "ink" (ink-wash wipe), "lantern" (lantern-light iris, center = tapped tab), "petal" (petal sweep),
#         "auto" = style_for(tab). «минимум»: a 0.12 s dark fade.

const TAB_STYLE: = {
	"home": "lantern", "collection": "petal", "levels": "ink", "play": "ink", "summon": "lantern",
	"shop": "petal", "salon": "petal", "phone": "ink", "path": "ink", "tower": "lantern", "duels": "ink",
	"profile": "petal",
}


static func style_for(tab_id: String) -> String:
	return TAB_STYLE.get(tab_id, "ink")


static func cover(style: = "ink", dur: = 0.34, center: = Vector2(-1, -1), tab_id: = "") -> Signal:
	return V10JuiceTransition.get_or_make().cover(style, dur, center, tab_id)


static func reveal(dur: = 0.42) -> Signal:
	return V10JuiceTransition.get_or_make().reveal(dur)


# convenience: cover, run `swap` while covered, reveal
static func transition(style: String, swap: Callable, center: = Vector2(-1, -1)) -> void:
	await cover(style, 0.34, center)
	if swap.is_valid():
		swap.call()
	reveal()


# ── 2. tile match ────────────────────────────────────────────────────────────────────────────────────────────
# V10Juice.tile_match(pos, face, combo, gold): jade shards + suit ink splash + (gold / combo ≥ 3) gold ripple.
# pos in canvas coords (centre of the pair's meeting point). Everything stays within ≈ 1.5 tiles.

static func suit_of(face: int) -> int:
	if face < 0:
		return -1
	return G.face_cat(face)


static func tile_match(pos: Vector2, face: = -1, combo: = 1, gold: = false, parent: Node = null, tile_w: = 84.0) -> void:
	var c: = clampi(combo, 1, 20)
	var su: = suit_of(face)
	if can_fx():
		jade_shatter(pos, tile_w, 8 + mini(c, 6), parent)
		if su >= 0:
			ink_splash(pos, su, tile_w * (1.05 + mini(c, 8) * 0.035), parent)
		if gold or c >= 3:
			ripple(parent, pos, GOLD if gold else Color(1.0, 0.74, 0.5), tile_w * (1.2 + mini(c, 10) * 0.05), 0.5)
		burst(parent, pos, "star4", 2 + mini(c, 6) / 2, Color(1.0, 0.76, 0.48), 0.8)
		if gold:
			burst(parent, pos, "confetti_gold", 8, GOLD, 0.7)
	sound("jade_shatter", randf_range(0.96, 1.06) + mini(c, 8) * 0.012, -9.0)
	if su >= 0 and can_fx():
		sound_later("ink_splash", 0.03, randf_range(0.92, 1.08), -13.0)
	if gold:
		sound_later("gold_ripple", 0.05, 1.0, -10.0)


static func jade_shatter(pos: Vector2, size: = 84.0, count: = 10, parent: Node = null, face_col: = IVORY, edge_col: = JADE) -> void:
	count = n(count)
	if count <= 0:
		return
	var s: = V10JuiceShards.new()
	s.position = pos
	host(parent).add_child(s)
	s.start(count, size, face_col, edge_col)


static func ink_splash(pos: Vector2, suit: int, radius: = 100.0, parent: Node = null) -> void:
	if not can_fx():
		return
	var col: Color = SUIT_INK[clampi(suit, 0, SUIT_INK.size() - 1)]
	var r: = rect(parent, Rect2(pos - Vector2(radius, radius), Vector2(radius, radius) * 2.0), "juice_ink_splat",
		{"color": col, "t": 0.0, "seed": randf() * 50.0, "alpha": 0.62})
	r.rotation = randf() * TAU
	r.pivot_offset = r.size * 0.5
	var t: = tween_param(r, "t", 0.0, 1.0, 0.75, Tween.TRANS_LINEAR)
	t.tween_callback(r.queue_free)
	burst(parent, pos, "ink", 6, col, 0.8)


# ── 3. combo milestones ×5 / ×10 / ×20 ───────────────────────────────────────────────────────────────────────
# V10Juice.combo_milestone(combo, strip) — returns true when combo is a milestone and a banner was shown.
# strip: the rect (canvas coords) where the banner may live, normally the HUD strip above the board.

static func is_milestone(combo: int) -> bool:
	return MILESTONES.has(combo)


static func combo_milestone(combo: int, strip: = Rect2(), title: = "", force: = false) -> bool:
	if not force and not is_milestone(combo):
		return false
	var key: = combo
	if not MILESTONES.has(key):
		key = 20 if combo > 20 else (10 if combo > 10 else 5)
	var info: Array = MILESTONES[key]
	if strip.size == Vector2.ZERO:
		var v: = vp_size()
		strip = Rect2(0, v.y * 0.085, v.x, 130)
	V10JuiceBanner.show_banner(layer("fx"), strip, combo, title if title != "" else String(info[0]), info[1])
	return true


# ── 4. fever aura & ult heartbeat ────────────────────────────────────────────────────────────────────────────
# var aura = V10Juice.fever_aura(board_parent, board_rect_in_parent)   …   V10Juice.stop(aura)
# var beat = V10Juice.ult_ready(ult_button)                              …   V10Juice.stop(beat)

static func fever_aura(parent: Node, frame: Rect2, color_a: = Color(1.0, 0.42, 0.14), color_b: = Color(1.0, 0.78, 0.3), radius: = 26.0) -> Node:
	var a: = V10JuiceAura.new()
	parent.add_child(a)
	a.setup_fever(frame, color_a, color_b, radius)
	sound("fever_ignite", 1.0, -6.0)
	shake(0.12)
	return a


static func ult_ready(target: Control, color_a: = Color(1.0, 0.36, 0.5), color_b: = Color(1.0, 0.8, 0.45), with_sound: = false) -> Node:
	if target == null or not is_instance_valid(target) or target.get_parent() == null:
		return null
	var a: = V10JuiceAura.new()
	var p: = target.get_parent()
	p.add_child(a)
	p.move_child(a, target.get_index())
	a.setup_heartbeat(target, color_a, color_b, with_sound)
	return a


# BENCHMARK MD-2: «сердцебиение» on the last free tray slot — the same lub-dub glow in warning red.
# Off at «минимум» (it is a mood, the tray itself shows the danger).
static func danger_beat(slot: Control) -> Node:
	if not can_fx():
		return null
	return ult_ready(slot, Color(1.0, 0.22, 0.26), Color(1.0, 0.5, 0.3), true)


static func stop(node: Node, dur: = 0.35) -> void:
	if node == null or not is_instance_valid(node):
		return
	if node.has_method("stop"):
		node.call("stop", dur)
	else:
		node.queue_free()


# ── 5. rewards: fountain, roll-up, chest, rank crest ─────────────────────────────────────────────────────────

# icons spout up from `from` and home into `to` (a Control — usually the top-bar counter — or a canvas point).
# on_each(i) per arrival (bump the counter there), on_done() after the last one. «минимум»: no icons, callbacks
# fire at once.
static func fountain(from: Vector2, to, kind: = "coin", count: = 10, on_each: = Callable(), on_done: = Callable()) -> void:
	var k: = n(clampi(count, 1, 16))
	if k <= 0:
		for i in count:
			if on_each.is_valid():
				on_each.call(i)
		if on_done.is_valid():
			on_done.call()
		return
	var f: = V10JuiceFountain.new()
	layer("fx").add_child(f)
	f.start(from, to, kind, k, on_each, on_done)


static func icon_tex(kind: String) -> Texture2D:
	var t: Texture2D = null
	if kind in ["coin", "gem", "ticket"]:
		var path: = "res://assets/v08/ui/cur/%s.png" % kind
		if ResourceLoader.exists(path):
			t = load(path)
	if t == null:
		t = V10JuiceTex.get_tex("gem" if kind == "gem" else "coin")
	return t


# animated number: from → to with ease-out, soft ticks, a bounce and a warm blink at the end.
# fmt: a Callable(int) -> String, or a format string with one %d / %s.
static func roll(label: Label, from: int, to: int, dur: = 0.9, fmt = "%d", ticks: = true) -> Tween:
	if label == null or not is_instance_valid(label):
		return null
	if not can_fx():
		dur = minf(dur, 0.3)
	var f: = func(v: int) -> String:
		if fmt is Callable:
			return (fmt as Callable).call(v)
		return String(fmt) % v
	var last: = [from, 0.0]
	var t: = label.create_tween()
	t.tween_method(func(x: float):
		var v: = int(round(x))
		if v != int(last[0]):
			last[0] = v
			label.text = f.call(v)
			var now: = Time.get_ticks_msec() / 1000.0
			if ticks and can_fx() and now - float(last[1]) > 0.065:
				last[1] = now
				sound("rollup", 1.0 + clampf(float(v - from) / maxf(1.0, float(to - from)), 0.0, 1.0) * 0.35, -16.0),
		float(from), float(to), dur).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	t.tween_callback(func():
		label.text = f.call(to)
		bounce(label, 0.18)
		if can_fx():
			var m0: = label.modulate
			var t2: = label.create_tween()
			t2.tween_property(label, "modulate", Color(1.0, 0.86, 0.55, m0.a), 0.08)
			t2.tween_property(label, "modulate", m0, 0.35))
	return t


# a springy bounce of any Control / Node2D (keeps its resting scale)
static func bounce(c: CanvasItem, amount: = 0.15, dur: = 0.45) -> void:
	if c == null or not is_instance_valid(c):
		return
	if c is Control and (c as Control).pivot_offset == Vector2.ZERO:
		(c as Control).pivot_offset = (c as Control).size * 0.5
	var key: = "v10j_base"
	if not c.has_meta(key):
		c.set_meta(key, c.get("scale"))
	var b: Vector2 = c.get_meta(key)
	if c.has_meta("v10j_btw"):
		var old = c.get_meta("v10j_btw")
		if old is Tween and old.is_valid():
			old.kill()
	var t: = c.create_tween()
	c.set_meta("v10j_btw", t)
	t.tween_property(c, "scale", b * (1.0 + amount), 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(c, "scale", b, dur).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	t.tween_callback(func():
		if is_instance_valid(c):
			c.remove_meta(key)
			c.remove_meta("v10j_btw"))


# chest: anticipation rattle → burst with god-rays, ring, rising motes and gold flakes. chest = the chest node
# (Control / Node2D) or null with pos. rarity "R" / "SR" / "SSR". on_open() fires at the burst (swap the
# closed sprite for the open one there).
static func chest_open(chest: CanvasItem, rarity: = "SR", on_open: = Callable(), pos: = Vector2(-1, -1)) -> void:
	if pos.x < 0 and chest != null:
		pos = global_center(chest)
	var col: = rarity_color(rarity)
	var rattle: = 0.0 if not can_fx() else 0.55
	if chest != null and is_instance_valid(chest) and rattle > 0.0:
		var x0 = chest.get("position")
		var t: = chest.create_tween()
		for i in 3:
			var k: = 1.0 + i * 0.6
			t.tween_property(chest, "rotation", 0.05 * k, 0.05)
			t.tween_property(chest, "rotation", -0.05 * k, 0.07)
			t.tween_property(chest, "rotation", 0.0, 0.05)
			t.tween_interval(0.02)
		t.tween_callback(func(): haptic("button"))
	sound("chest_open", 1.0, -3.0)
	tree().create_timer(rattle, true, false, true).timeout.connect(func():
		if on_open.is_valid():
			on_open.call()
		if chest != null and is_instance_valid(chest):
			if chest is Control and (chest as Control).pivot_offset == Vector2.ZERO:
				(chest as Control).pivot_offset = (chest as Control).size * 0.5
			var b: Vector2 = chest.get("scale")
			var t2: = chest.create_tween()
			t2.tween_property(chest, "scale", b * Vector2(1.12, 0.9), 0.06)
			t2.tween_property(chest, "scale", b, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		chest_burst(pos, rarity, col)
		haptic("ssr" if rarity == "SSR" else "match"))


static func rarity_color(r: String) -> Color:
	match r:
		"SSR":
			return Color(1.0, 0.78, 0.34)
		"SR":
			return Color(0.78, 0.55, 1.0)
	return Color(0.5, 0.78, 1.0)


static func chest_burst(pos: Vector2, rarity: = "SR", col: = Color(-1, 0, 0), parent: Node = null) -> void:
	if col.r < 0:
		col = rarity_color(rarity)
	var big: = rarity == "SSR"
	if can_fx():
		godrays(pos + Vector2(0, -20), 760.0 if big else 560.0, col, 1.9 if big else 1.4, 0.55 if big else 0.75, parent)
		ripple(parent, pos, col, 260.0 if big else 190.0, 0.7, 0.05)
		glow(parent, pos, col, 3.0 if big else 2.2, 0.5, 0.42)
		burst(parent, pos, "spark", 20 if big else 12, col, 1.1)
		burst(parent, pos, "star4", 10 if big else 7, Color(1.0, 0.78, 0.5), 1.3)
		burst(parent, pos + Vector2(0, -10), "confetti_gold", 24 if big else 14, GOLD, 1.0)
		burst(parent, pos, "mote", 16 if big else 10, col, 1.0, Vector2(60, 10))
	shake(0.35 if big else 0.2)


# god-rays: a cone (spread < 1, aimed up) or full rays around pos; fades by itself after dur
static func godrays(pos: Vector2, size: = 640.0, color: = GOLD, dur: = 1.6, spread: = 1.0, parent: Node = null, peak: = 0.85) -> ColorRect:
	if not can_fx() or live_overlays >= budget("overlays"):
		return null
	var r: = rect(parent, Rect2(pos - Vector2(size, size) * 0.5, Vector2(size, size)), "juice_godrays",
		{"color": color, "intensity": 0.0, "spread": spread, "count": 12.0, "speed": 0.08})
	live_overlays += 1
	var t: = tween_param(r, "intensity", 0.0, peak, 0.22, Tween.TRANS_QUAD)
	t.tween_interval(maxf(0.1, dur - 0.8))
	t.tween_method(func(v): param(r, "intensity", v), peak, 0.0, 0.58).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.tween_callback(func():
		live_overlays -= 1
		r.queue_free())
	return r


# rank-up crest reveal: dims the screen (dark, not white), god-rays, the crest materialises through a warm
# dissolve edge, lands with a ring and a stamp, title + subtitle, glint. Tap or `hold` seconds closes it.
static func crest_reveal(crest: Texture2D, title: = "", subtitle: = "", color: = GOLD, hold: = 2.2, on_done: = Callable()) -> Control:
	return V10JuiceCrest.make(layer("fx"), crest, title, subtitle, color, hold, on_done)


# ── 6. ambient ───────────────────────────────────────────────────────────────────────────────────────────────

# twinkles on the corners and a periodic sheen across a premium button. Returns the node (free = stop).
# «минимум»: nothing (null). radius: the button's corner radius for the sheen mask.
static func idle_sparkle(target: Control, color: = GOLD, every: = 2.8, radius: = 22.0) -> Node:
	if not can_fx() or target == null or not is_instance_valid(target):
		return null
	var s: = V10JuiceIdle.new()
	target.add_child(s)
	s.setup(target, color, every, radius)
	return s


# heroine entrance: slide + fade + settle, a light sweep across her (masked by her own alpha when the node is a
# Sprite2D / TextureRect without a material) and petals. from: "right" | "left" | "bottom".
static func heroine_entrance(node: CanvasItem, from: = "right", petals: = true, delay: = 0.0) -> void:
	if node == null or not is_instance_valid(node):
		return
	var full: = can_fx()
	var p0 = node.get("position")
	var off: = Vector2(70, 0)
	match from:
		"left":
			off = Vector2(-70, 0)
		"bottom":
			off = Vector2(0, 60)
	var m0: = node.modulate
	node.modulate.a = 0.0
	if node is Control and (node as Control).pivot_offset == Vector2.ZERO:
		(node as Control).pivot_offset = (node as Control).size * Vector2(0.5, 0.85)
	var s0: Vector2 = node.get("scale")
	var t: = node.create_tween().set_parallel()
	if full:
		node.set("position", p0 + off)
		node.set("scale", s0 * 1.04)
		t.tween_property(node, "position", p0, 0.62).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT).set_delay(delay)
		t.tween_property(node, "scale", s0, 0.8).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT).set_delay(delay)
	t.tween_property(node, "modulate:a", m0.a, 0.45 if full else 0.25).set_delay(delay)
	if not full:
		return
	sound_later("heroine_enter", delay, 1.0, -6.0)
	var gr: = Rect2(global_center(node) - Vector2(200, 300), Vector2(400, 600))
	if node is Control:
		gr = (node as Control).get_global_rect()
	elif node is Sprite2D and (node as Sprite2D).texture:
		var sp: = node as Sprite2D
		var sz: = sp.texture.get_size() * sp.global_scale
		gr = Rect2(sp.global_position - (sz * 0.5 if sp.centered else Vector2.ZERO), sz)
	tree().create_timer(delay + 0.28, true, false, true).timeout.connect(func():
		if is_instance_valid(node):
			sheen(node, Color(1.0, 0.88, 0.7), 0.75))
	if petals:
		tree().create_timer(delay + 0.1, true, false, true).timeout.connect(func():
			burst(null, Vector2(gr.get_center().x, gr.position.y + 20), "petal", 14, Color(1, 0.85, 0.9), 1.0, Vector2(gr.size.x * 0.45, 10), Vector2(0.2, 1))
			burst(null, gr.get_center() + Vector2(0, gr.size.y * 0.2), "mote", 10, Color(1, 0.8, 0.7), 0.8, Vector2(gr.size.x * 0.35, gr.size.y * 0.3)))


# one light sweep across a textured node, masked by its alpha (juice_glint). If the node already has a material,
# a soft additive band over its rect is used instead.
static func sheen(node: CanvasItem, color: = Color(1.0, 0.9, 0.7), dur: = 0.7, amount: = 0.5) -> void:
	if not can_fx() or node == null or not is_instance_valid(node):
		return
	if (node is Sprite2D or node is TextureRect) and node.material == null:
		var m: = mat("juice_glint", {"color": color, "pos": -0.4, "amount": amount, "max_add": 0.32})
		node.material = m
		var t: = node.create_tween()
		t.tween_method(func(v): m.set_shader_parameter("pos", v), -0.4, 1.4, dur).set_trans(Tween.TRANS_SINE)
		t.tween_callback(func():
			if is_instance_valid(node) and node.material == m:
				node.material = null)
		return
	if node is Control:
		var c: = node as Control
		var r: = ColorRect.new()
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.size = c.size
		r.material = mat("juice_sweep_rr", {"color": Color(color.r, color.g, color.b, amount * 0.6), "pos": -0.4, "size": c.size, "radius": 0.0})
		c.add_child(r)
		var t2: = r.create_tween()
		t2.tween_method(func(v): param(r, "pos", v), -0.4, 1.4, dur).set_trans(Tween.TRANS_SINE)
		t2.tween_callback(r.queue_free)


# dissolve a textured node away (amount 0→1) or in (reveal = true), with a warm burning edge
static func dissolve(node: CanvasItem, dur: = 0.6, reveal_in: = false, edge: = Color(0.86, 0.32, 0.16), on_done: = Callable()) -> void:
	if node == null or not is_instance_valid(node):
		return
	if not can_fx():
		node.modulate.a = 1.0 if reveal_in else 0.0
		if on_done.is_valid():
			on_done.call()
		return
	var m0: = node.material
	var m: = mat("juice_dissolve", {"amount": 1.0 if reveal_in else 0.0, "edge_color": edge, "seed": randf() * 20.0})
	node.material = m
	var t: = node.create_tween()
	t.tween_method(func(v): m.set_shader_parameter("amount", v), 1.0 if reveal_in else 0.0, 0.0 if reveal_in else 1.0, dur).set_trans(Tween.TRANS_SINE)
	t.tween_callback(func():
		if is_instance_valid(node) and reveal_in:
			node.material = m0
		if on_done.is_valid():
			on_done.call())
