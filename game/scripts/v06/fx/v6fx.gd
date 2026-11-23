extends Node










const SND: = "res://assets/v06/fx/%s.wav"
const SH: = "res://shaders/v06/fx/"
const MAX_EMITTERS: = 48

var layer: CanvasLayer
var parts: Node2D
var grade_rect: ColorRect
var grade_mat: ShaderMaterial
var bb_copy: BackBufferCopy
var shock_rect: ColorRect
var shock_mat: ShaderMaterial
var lines_rect: ColorRect
var lines_mat: ShaderMaterial
var flash_rect: ColorRect
var flash_mat: ShaderMaterial
var vp: = Vector2(720, 1280)

var players: Array[AudioStreamPlayer] = []
var cache: = {}
var mats: = {}
var texs: = {}
var emitters: = 0

var trauma: = 0.0
var shaking: = false
var noise: = FastNoiseLite.new()
var real_t: = 0.0
var hitstop_left: = 0.0
var hitstop_on: = false

var waves: Array = [Vector4.ZERO, Vector4.ZERO, Vector4.ZERO]
var wave_speed: Array = [0.0, 0.0, 0.0]
var wave_life: Array = [0.0, 0.0, 0.0]

var bus_music: = -1
var bus_sfx: = -1
var lpf: AudioEffectLowPassFilter
var lpf_hz: = 20500.0
var lpf_target: = 20500.0
var duck_db: = 0.0
var duck_left: = 0.0
var last_music: = "?"


var g_sat: = 1.0
var g_exp: = 1.0
var g_lift: = 0.0
var g_vig: = 0.0
var g_pulse: = 0.0
var g_vig_col: = Color(0.9, 0.15, 0.3)
var g_tw: Tween
var lines_amt: = 0.0
var lines_tw: Tween


var board: Node = null
var board_screen: Node = null
var seen: = {}
var ice_of: = {}
var secret_of: = {}
var danger: = false
var failed_now: = false
var hb_t: = 0.0


var counters: = {}
var counter_t: = 0.0
var tick_t: = 0.0

func _ready() -> void :
	process_mode = Node.PROCESS_MODE_ALWAYS
	noise.seed = 608
	noise.frequency = 1.0
	vp = get_viewport().get_visible_rect().size
	get_viewport().size_changed.connect( func(): vp = get_viewport().get_visible_rect().size;_fit())
	_build_layer()
	_build_audio()
	get_tree().node_added.connect(_on_node_added)
	var s: = get_node_or_null("/root/Sfx")
	if s and s.has_signal("voice_started"):
		if true:
			s.voice_started.connect( func(_h, _txt, dur): duck(-7.0, float(dur) + 0.2))
	_dev_args.call_deferred()

func opt(key: String, def: = true) -> bool:
	var d = G.S.get("v6_fx", {}) if G.S is Dictionary else {}
	return bool(d.get(key, def)) if d is Dictionary else def




func _rect(shader: String) -> Array:
	var r: = ColorRect.new()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.color = Color.WHITE
	var m: = ShaderMaterial.new()
	m.shader = load(SH + shader)
	r.material = m
	r.visible = false
	return [r, m]

func _build_layer() -> void :
	layer = CanvasLayer.new()
	layer.layer = 60
	add_child(layer)
	var a: = _rect("grade.gdshader")
	grade_rect = a[0]
	grade_mat = a[1]
	layer.add_child(grade_rect)
	bb_copy = BackBufferCopy.new()
	bb_copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	bb_copy.visible = false
	layer.add_child(bb_copy)
	a = _rect("shock.gdshader")
	shock_rect = a[0]
	shock_mat = a[1]
	layer.add_child(shock_rect)
	parts = Node2D.new()
	layer.add_child(parts)
	a = _rect("lines.gdshader")
	lines_rect = a[0]
	lines_mat = a[1]
	layer.add_child(lines_rect)
	a = _rect("flash.gdshader")
	flash_rect = a[0]
	flash_mat = a[1]
	layer.add_child(flash_rect)
	_fit()

func _fit() -> void :
	for r in [grade_rect, shock_rect, lines_rect, flash_rect]:
		if r:
			r.position = Vector2.ZERO
			r.size = vp
	if shock_mat:
		shock_mat.set_shader_parameter("size", vp)
		flash_mat.set_shader_parameter("size", vp)
		lines_mat.set_shader_parameter("aspect", vp.x / vp.y)




func _bus(name: String) -> int:
	var i: = AudioServer.get_bus_index(name)
	if i == -1:
		AudioServer.add_bus()
		i = AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, name)
		AudioServer.set_bus_send(i, "Master")
	return i

func _build_audio() -> void :
	bus_music = _bus("Music")
	lpf = AudioEffectLowPassFilter.new()
	lpf.cutoff_hz = 20500.0
	lpf.resonance = 0.6
	AudioServer.add_bus_effect(bus_music, lpf)
	bus_sfx = _bus("SFX")
	var comp: = AudioEffectCompressor.new()
	comp.threshold = -14.0
	comp.ratio = 3.0
	comp.attack_us = 2000.0
	comp.release_ms = 120.0
	AudioServer.add_bus_effect(bus_sfx, comp)
	var lim: = AudioEffectHardLimiter.new()
	lim.ceiling_db = -0.8
	AudioServer.add_bus_effect(bus_sfx, lim)
	for i in 18:
		var p: = AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		players.append(p)

	var s: = get_node_or_null("/root/Sfx")
	if s:
		for p in s.pool:
			p.bus = "SFX"
		s.music_a.bus = "Music"
		s.music_b.bus = "Music"

func _stream(name: String) -> AudioStream:
	if not cache.has(name):
		var path: = SND % name
		cache[name] = load(path) if ResourceLoader.exists(path) else null
	return cache[name]


func sound(name: String, pitch: = 1.0, db: = 0.0, delay: = 0.0) -> void :
	if not G.S.get("sound", true):
		return
	if delay > 0.0:
		get_tree().create_timer(delay, true, false, true).timeout.connect(sound.bind(name, pitch, db, 0.0))
		return
	var st: = _stream(name)
	if st == null:
		return
	var p: AudioStreamPlayer = null
	for q in players:
		if not q.playing:
			p = q
			break
	if p == null:
		p = players[0]
	p.stream = st
	p.pitch_scale = pitch
	p.volume_db = db
	p.play()


func layers(list: Array) -> void :
	for l in list:
		sound(l[0], l[1] if l.size() > 1 else 1.0, l[2] if l.size() > 2 else 0.0, l[3] if l.size() > 3 else 0.0)


func duck(db: = -8.0, dur: = 1.0) -> void :
	duck_db = minf(duck_db, db)
	duck_left = maxf(duck_left, dur)


func music_filter(hz: float) -> void :
	lpf_target = clampf(hz, 300.0, 20500.0)


func music_transition() -> void :
	lpf_hz = 900.0
	lpf_target = 20500.0
	sound("swoosh", 0.9, -14.0)




func shake(amount: = 0.3) -> void :
	if not opt("shake"):
		return
	trauma = clampf(trauma + amount, 0.0, 1.0)

func hit_stop(dur: = 0.06, scale: = 0.06) -> void :
	if not opt("hitstop"):
		return
	hitstop_left = maxf(hitstop_left, dur)
	Engine.time_scale = minf(Engine.time_scale, scale)
	hitstop_on = true

func flash(color: = Color(1, 0.96, 0.88), amount: = 0.6, dur: = 0.3, pos: = Vector2(-1, -1), radius: = 0.0, full: = 0.0) -> void :
	if not opt("flash"):
		amount *= 0.35
	if pos.x < 0:
		pos = vp * 0.5
	flash_mat.set_shader_parameter("color", color)
	flash_mat.set_shader_parameter("center", pos)
	flash_mat.set_shader_parameter("radius", radius if radius > 0 else vp.y * 0.45)
	flash_mat.set_shader_parameter("full", full)
	flash_rect.visible = true
	var t: = flash_rect.create_tween()
	t.tween_method( func(v): flash_mat.set_shader_parameter("amount", v), amount, 0.0, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_callback( func(): flash_rect.visible = false)

func shockwave(pos: Vector2, strength: = 16.0, speed: = 1400.0, life: = 0.55) -> void :
	var slot: = 0
	for i in 3:
		if waves[i].w <= 0.0:
			slot = i
			break
		if wave_life[i] < wave_life[slot]:
			slot = i
	waves[slot] = Vector4(pos.x, pos.y, 0.0, strength)
	wave_speed[slot] = speed
	wave_life[slot] = life

func speedlines(amount: = 0.5, dur: = 0.5, color: = Color(1, 0.97, 0.9, 0.85), focus: = Vector2(-1, -1)) -> void :
	if not opt("flash"):
		amount *= 0.4
	if focus.x < 0:
		focus = vp * Vector2(0.5, 0.45)
	lines_mat.set_shader_parameter("focus", focus / vp)
	lines_mat.set_shader_parameter("color", color)
	lines_mat.set_shader_parameter("seed", randf() * 100.0)
	if lines_tw:
		lines_tw.kill()
	lines_amt = maxf(lines_amt, amount)
	lines_tw = create_tween()
	lines_tw.tween_property(self, "lines_amt", 0.0, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func grade(sat: = 1.0, expo: = 1.0, lift: = 0.0, vig: = 0.0, vig_color: = Color(0.9, 0.15, 0.3), pulse: = 0.0, dur: = 0.35) -> void :
	if g_tw:
		g_tw.kill()
	g_vig_col = vig_color
	g_tw = create_tween().set_parallel()
	g_tw.tween_property(self, "g_sat", sat, dur)
	g_tw.tween_property(self, "g_exp", expo, dur)
	g_tw.tween_property(self, "g_lift", lift, dur)
	g_tw.tween_property(self, "g_vig", vig, dur)
	g_tw.tween_property(self, "g_pulse", pulse, dur)

func grade_reset(dur: = 0.5) -> void :
	grade(1.0, 1.0, 0.0, 0.0, g_vig_col, 0.0, dur)


func glint(c: Control, delay: = 0.0, color: = Color(1, 0.95, 0.8, 0.9)) -> void :
	if not is_instance_valid(c):
		return
	var r: = ColorRect.new()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.size = c.size
	r.color = Color.WHITE
	var m: = ShaderMaterial.new()
	m.shader = load(SH + "sweep.gdshader")
	m.set_shader_parameter("color", color)
	m.set_shader_parameter("pos", -0.4)
	r.material = m
	c.add_child(r)
	var t: = r.create_tween()
	t.tween_interval(delay)
	t.tween_method( func(v): m.set_shader_parameter("pos", v), -0.4, 1.4, 0.55).set_trans(Tween.TRANS_SINE)
	t.tween_callback(r.queue_free)

func _process(dt: float) -> void :

	var rdt: = dt / maxf(Engine.time_scale, 0.0001)
	rdt = minf(rdt, 0.1)
	real_t += rdt
	if hitstop_on:
		hitstop_left -= rdt
		if hitstop_left <= 0.0:
			Engine.time_scale = 1.0
			hitstop_on = false

	var vpt: = get_viewport()
	if trauma > 0.0:
		trauma = maxf(0.0, trauma - rdt * 1.5)
		var k: = trauma * trauma
		var o: = Vector2(noise.get_noise_2d(real_t * 28.0, 0.0), noise.get_noise_2d(0.0, real_t * 28.0 + 50.0)) * 26.0 * k
		var rot: = noise.get_noise_2d(real_t * 22.0, 99.0) * 0.022 * k
		var c: = vp * 0.5
		vpt.canvas_transform = Transform2D(rot, c + o) * Transform2D(0.0, - c)
		shaking = true
	elif shaking:
		vpt.canvas_transform = Transform2D.IDENTITY
		shaking = false

	var any: = false
	var arr: = PackedVector4Array()
	for i in 3:
		var w: Vector4 = waves[i]
		if w.w > 0.0:
			wave_life[i] -= rdt
			w.z += wave_speed[i] * rdt
			if wave_life[i] <= 0.0:
				w.w = 0.0
			else:
				any = true
			waves[i] = w
		arr.append(waves[i])
	shock_rect.visible = any
	bb_copy.visible = any and grade_rect.visible
	if any:
		shock_mat.set_shader_parameter("waves", arr)

	lines_rect.visible = lines_amt > 0.01
	if lines_rect.visible:
		lines_mat.set_shader_parameter("amount", lines_amt)

	var gon: = absf(g_sat - 1.0) > 0.01 or absf(g_exp - 1.0) > 0.01 or g_lift > 0.01 or g_vig > 0.01
	grade_rect.visible = gon
	if gon:
		grade_mat.set_shader_parameter("saturation", g_sat)
		grade_mat.set_shader_parameter("exposure", g_exp)
		grade_mat.set_shader_parameter("lift", g_lift)
		grade_mat.set_shader_parameter("vig", g_vig)
		grade_mat.set_shader_parameter("pulse", g_pulse)
		grade_mat.set_shader_parameter("vig_color", g_vig_col)

	lpf_hz = lerpf(lpf_hz, lpf_target, 1.0 - exp( - rdt * 3.0))
	lpf.cutoff_hz = lpf_hz
	if duck_left > 0.0:
		duck_left -= rdt
	else:
		duck_db = lerpf(duck_db, 0.0, 1.0 - exp( - rdt * 4.0))
	var cur: = AudioServer.get_bus_volume_db(bus_music)
	AudioServer.set_bus_volume_db(bus_music, lerpf(cur, duck_db, 1.0 - exp( - rdt * 10.0)))
	var sfx: = get_node_or_null("/root/Sfx")
	if sfx and sfx.cur_music != last_music:
		if last_music != "?" and sfx.cur_music != "":
			music_transition()
		last_music = sfx.cur_music

	if danger and not failed_now:
		hb_t -= rdt
		if hb_t <= 0.0:
			hb_t = 0.95
			sound("heartbeat", 1.0, -8.0)

	counter_t -= rdt
	tick_t -= rdt
	if counter_t <= 0.0:
		counter_t = 0.1
		_watch_counters()




func _tex(name: String) -> Texture2D:
	if texs.has(name):
		return texs[name]
	var t: Texture2D
	match name:
		"streak":
			var img: = Image.create(12, 72, false, Image.FORMAT_RGBA8)
			for y in 72:
				for x in 12:
					var dx: = (x - 5.5) / 5.5
					var dy: = (y - 35.5) / 35.5
					var a: = exp( - dx * dx * 3.0) * pow(maxf(0.0, 1.0 - dy * dy), 1.5)
					img.set_pixel(x, y, Color(1, 1, 1, a))
			t = ImageTexture.create_from_image(img)
		"chip":
			var img: = Image.create(22, 28, false, Image.FORMAT_RGBA8)
			for y in 28:
				for x in 22:
					var ex: = minf(minf(x, 21 - x), minf(y, 27 - y))
					var a: = clampf(ex / 1.5, 0.0, 1.0)
					var shade: = 1.0 if y < 22 else 0.78
					img.set_pixel(x, y, Color(shade, shade * 0.98, shade * 0.93, a))
			t = ImageTexture.create_from_image(img)
		"coin", "gem", "heart_i", "star_i":
			t = Common.ui_icon(name.trim_suffix("_i"))
		_:
			t = G.fx(name)
	texs[name] = t
	return t

func _grad(cols: Array) -> GradientTexture1D:
	var g: = Gradient.new()
	var offs: = PackedFloat32Array()
	for i in cols.size():
		offs.append(float(i) / maxf(1.0, cols.size() - 1.0))
	g.offsets = offs
	g.colors = PackedColorArray(cols)
	var gt: = GradientTexture1D.new()
	gt.gradient = g
	return gt

func _curve(points: Array) -> CurveTexture:
	var c: = Curve.new()
	for p in points:
		c.add_point(p)
	var ct: = CurveTexture.new()
	ct.curve = c
	return ct


func _kind(kind: String, power: float) -> Array:
	var key: = "%s@%.2f" % [kind, snappedf(power, 0.25)]
	if mats.has(key):
		return mats[key]
	var m: = ParticleProcessMaterial.new()
	m.particle_flag_disable_z = true
	m.spread = 180.0
	m.gravity = Vector3.ZERO
	var tex: = "glow"
	var life: = 0.6
	var add: = true
	var fade: = _grad([Color(1, 1, 1, 1), Color(1, 1, 1, 0.85), Color(1, 1, 1, 0)])
	m.color_ramp = fade
	match kind:
		"spark":
			tex = "streak"
			life = 0.5
			m.particle_flag_align_y = true
			m.initial_velocity_min = 380.0 * power
			m.initial_velocity_max = 1050.0 * power
			m.damping_min = 900.0 * power
			m.damping_max = 1600.0 * power
			m.scale_min = 0.5
			m.scale_max = 1.1
			m.scale_curve = _curve([Vector2(0, 1), Vector2(0.6, 0.7), Vector2(1, 0)])
		"chip":
			tex = "chip"
			life = 0.85
			add = false
			m.direction = Vector3(0, -1, 0)
			m.spread = 75.0
			m.initial_velocity_min = 260.0 * power
			m.initial_velocity_max = 640.0 * power
			m.gravity = Vector3(0, 1500, 0)
			m.angle_min = -180.0
			m.angle_max = 180.0
			m.angular_velocity_min = -720.0
			m.angular_velocity_max = 720.0
			m.scale_min = 0.45
			m.scale_max = 0.9
			m.color_ramp = _grad([Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
		"glint":
			tex = "sparkle"
			life = 0.7
			m.initial_velocity_min = 40.0 * power
			m.initial_velocity_max = 260.0 * power
			m.damping_min = 200.0
			m.damping_max = 400.0
			m.angular_velocity_min = -220.0
			m.angular_velocity_max = 220.0
			m.scale_min = 0.25
			m.scale_max = 0.6
			m.scale_curve = _curve([Vector2(0, 0), Vector2(0.2, 1), Vector2(1, 0)])
		"dust":
			tex = "glow"
			life = 0.45
			add = false
			m.direction = Vector3(0, -1, 0)
			m.spread = 100.0
			m.initial_velocity_min = 40.0 * power
			m.initial_velocity_max = 140.0 * power
			m.damping_min = 120.0
			m.damping_max = 260.0
			m.scale_min = 0.18
			m.scale_max = 0.38
			m.scale_curve = _curve([Vector2(0, 0.5), Vector2(1, 1)])
			m.color_ramp = _grad([Color(1, 1, 1, 0.55), Color(1, 1, 1, 0)])
		"ember":
			tex = "glow"
			life = 1.3
			m.direction = Vector3(0, -1, 0)
			m.spread = 40.0
			m.initial_velocity_min = 120.0 * power
			m.initial_velocity_max = 420.0 * power
			m.gravity = Vector3(0, -120, 0)
			m.damping_min = 60.0
			m.damping_max = 140.0
			m.scale_min = 0.05
			m.scale_max = 0.14
			m.hue_variation_min = -0.04
			m.hue_variation_max = 0.04
		"confetti":
			tex = "confetti"
			life = 3.0
			add = false
			m.direction = Vector3(0, -1, 0)
			m.spread = 32.0
			m.initial_velocity_min = 900.0 * power
			m.initial_velocity_max = 1500.0 * power
			m.damping_min = 380.0
			m.damping_max = 620.0
			m.gravity = Vector3(0, 620, 0)
			m.angle_min = -180.0
			m.angle_max = 180.0
			m.angular_velocity_min = -540.0
			m.angular_velocity_max = 540.0
			m.scale_min = 0.6
			m.scale_max = 1.1
			m.hue_variation_min = -0.5
			m.hue_variation_max = 0.5
			m.color_ramp = _grad([Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
		"petal":
			tex = "petal"
			life = 1.8
			add = false
			m.initial_velocity_min = 140.0 * power
			m.initial_velocity_max = 460.0 * power
			m.damping_min = 220.0
			m.damping_max = 420.0
			m.gravity = Vector3(0, 240, 0)
			m.angle_min = -180.0
			m.angle_max = 180.0
			m.angular_velocity_min = -300.0
			m.angular_velocity_max = 300.0
			m.scale_min = 0.35
			m.scale_max = 0.7
		"firework":
			tex = "streak"
			life = 1.4
			m.particle_flag_align_y = true
			m.initial_velocity_min = 420.0 * power
			m.initial_velocity_max = 480.0 * power
			m.damping_min = 300.0
			m.damping_max = 340.0
			m.gravity = Vector3(0, 180, 0)
			m.scale_min = 0.35
			m.scale_max = 0.55
			m.scale_curve = _curve([Vector2(0, 1), Vector2(1, 0.2)])
		"coin":
			tex = "coin"
			life = 1.2
			add = false
			m.direction = Vector3(0, -1, 0)
			m.spread = 55.0
			m.initial_velocity_min = 420.0 * power
			m.initial_velocity_max = 820.0 * power
			m.gravity = Vector3(0, 1600, 0)
			m.angular_velocity_min = -400.0
			m.angular_velocity_max = 400.0
			m.scale_min = 0.28
			m.scale_max = 0.42
			m.color_ramp = _grad([Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
		"star":
			tex = "star"
			life = 1.0
			m.initial_velocity_min = 120.0 * power
			m.initial_velocity_max = 420.0 * power
			m.damping_min = 260.0
			m.damping_max = 420.0
			m.angular_velocity_min = -200.0
			m.angular_velocity_max = 200.0
			m.scale_min = 0.18
			m.scale_max = 0.4
			m.scale_curve = _curve([Vector2(0, 0.2), Vector2(0.15, 1), Vector2(1, 0)])
		"ice":
			tex = "chip"
			life = 0.7
			m.direction = Vector3(0, -1, 0)
			m.spread = 120.0
			m.initial_velocity_min = 200.0 * power
			m.initial_velocity_max = 560.0 * power
			m.gravity = Vector3(0, 1300, 0)
			m.angle_min = -180.0
			m.angle_max = 180.0
			m.angular_velocity_min = -900.0
			m.angular_velocity_max = 900.0
			m.scale_min = 0.2
			m.scale_max = 0.5
	var out: = [m, _tex(tex), life, add]
	mats[key] = out
	return out



func burst(pos: Vector2, kind: = "spark", amount: = 24, color: = Color(1, 0.9, 0.6), power: = 1.0, parent: Node = null, extent: = Vector2.ZERO, dir: = Vector2.ZERO) -> Node2D:
	if emitters >= MAX_EMITTERS or amount <= 0:
		return null
	var k: = _kind(kind, power)
	var m: ParticleProcessMaterial = k[0]
	if extent != Vector2.ZERO or dir != Vector2.ZERO:
		m = m.duplicate()
		if extent != Vector2.ZERO:
			m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
			m.emission_box_extents = Vector3(extent.x, extent.y, 1)
		if dir != Vector2.ZERO:
			m.direction = Vector3(dir.x, dir.y, 0)
	var p: = GPUParticles2D.new()
	p.process_material = m
	p.texture = k[1]
	p.lifetime = k[2]
	p.amount = amount
	p.one_shot = true
	p.explosiveness = 0.95
	p.randomness = 0.3
	p.local_coords = false
	p.fixed_fps = 0
	p.visibility_rect = Rect2(-2000, -2000, 4000, 4000)
	p.modulate = color
	if k[3]:
		p.material = Fx.add_mat()
	p.position = pos
	var node: Node2D = p
	if not opt("gpu"):
		var c: = CPUParticles2D.new()
		c.convert_from_particles(p)
		c.one_shot = true
		c.explosiveness = 0.95
		c.local_coords = false
		c.modulate = color
		c.material = p.material
		c.position = pos
		p.free()
		node = c
	(parent if parent else parts).add_child(node)
	node.set("emitting", true)
	emitters += 1
	node.connect("finished", func():
		emitters -= 1
		node.queue_free())
	return node


func glow(pos: Vector2, color: = Color(1, 0.9, 0.7), size: = 2.0, dur: = 0.35, parent: Node = null) -> void :
	var s: = Sprite2D.new()
	s.texture = G.fx("glow")
	s.material = Fx.add_mat()
	s.position = pos
	s.modulate = color
	s.scale = Vector2.ONE * size * 0.3
	(parent if parent else parts).add_child(s)
	var t: = s.create_tween().set_parallel()
	t.tween_property(s, "scale", Vector2.ONE * size, dur).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	t.tween_property(s, "modulate:a", 0.0, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.chain().tween_callback(s.queue_free)


func rays(pos: Vector2, size: = 900.0, color: = Color(1, 0.88, 0.55, 0.8), dur: = 2.0) -> void :
	var r: = ColorRect.new()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.size = Vector2(size, size)
	r.position = pos - r.size * 0.5
	var m: = ShaderMaterial.new()
	m.shader = load("res://shaders/rays.gdshader")
	m.set_shader_parameter("color", color)
	m.set_shader_parameter("count", 12.0)
	m.set_shader_parameter("speed", 0.08)
	m.set_shader_parameter("intensity", 0.0)
	r.material = m
	parts.add_child(r)
	r.z_index = -1
	var t: = r.create_tween()
	t.tween_method( func(v): m.set_shader_parameter("intensity", v), 0.0, 0.85, 0.25)
	t.tween_interval(maxf(0.1, dur - 0.9))
	t.tween_method( func(v): m.set_shader_parameter("intensity", v), 0.85, 0.0, 0.65)
	t.tween_callback(r.queue_free)





func tap(pos: Vector2) -> void :
	burst(pos, "glint", 4, Color(1, 0.95, 0.8), 0.6)


func land(pos: Vector2, slot: = 0) -> void :
	burst(pos + Vector2(0, 30), "dust", 7, Color(1, 0.96, 0.9), 1.0, null, Vector2(34, 4))
	sound("land", randf_range(0.92, 1.08) + slot * 0.03, -6.0)


func on_match(pos: Vector2, combo: = 1, gold: = false, shard: = "") -> void :
	var c: = clampi(combo, 1, 12)
	var warm: = Color(1, 0.86, 0.5) if not gold else Color(1, 0.78, 0.2)
	burst(pos, "spark", 14 + c * 3, warm, 1.0 + c * 0.06)
	burst(pos, "chip", 8 + mini(c, 6), Color(1, 0.98, 0.94), 1.0)
	burst(pos, "glint", 3 + c, Color(1, 0.95, 0.85), 1.0)
	glow(pos, warm, 1.6 + c * 0.12, 0.3)
	layers([["thump", 1.0 + c * 0.02, -9.0 + mini(c, 6) * 0.6], ["chime%d" % clampi(c - 1, 0, 7), 1.0, -13.0, 0.02]])
	if c >= 2:
		sound("shimmer", 1.0 + c * 0.02, -17.0 + mini(c, 6), 0.04)
		shockwave(pos, 6.0 + c * 2.0, 1100.0, 0.4)
	if gold:
		burst(pos, "coin", 6, Color.WHITE, 0.8)
		layers([["coin", 1.0, -8.0, 0.06], ["coin", 1.12, -11.0, 0.14]])
	combo_tier(c, pos)
	if shard != "":
		unlock(pos)



func combo_tier(combo: int, pos: = Vector2(-1, -1)) -> void :
	if pos.x < 0:
		pos = vp * 0.5
	var milestone: = combo in [3, 5, 8, 12, 16, 20] or (combo > 20 and combo % 5 == 0)
	if milestone and combo >= 5:
		hit_stop(0.075)
		shake(0.34)
		speedlines(0.7, 0.7)
		flash(Color(1, 0.92, 0.8), 0.32, 0.3, pos, vp.y * 0.35)
		shockwave(pos, 22.0, 1500.0, 0.6)
		sound("combo_big", 1.0 + mini(combo - 5, 15) * 0.02, -4.0)
		burst(pos, "star", 10, Color(1, 0.9, 0.6), 1.3)
		burst(pos, "petal", 14, Color.WHITE, 1.4)
	elif milestone:
		hit_stop(0.045)
		shake(0.18)
		speedlines(0.38, 0.4)
		sound("combo_hit", 1.0, -7.0)
	elif combo >= 3:
		shake(0.07)
		speedlines(0.15, 0.22)


func deny(pos: = Vector2(-1, -1)) -> void :
	sound("deny_tick", randf_range(0.95, 1.05), -6.0)


func ice_crack(pos: Vector2, broke: = false) -> void :
	var icy: = Color(0.75, 0.92, 1.0)
	if broke:
		burst(pos, "ice", 22, icy, 1.2)
		burst(pos, "glint", 8, Color(0.85, 0.95, 1.0), 1.2)
		glow(pos, Color(0.7, 0.9, 1.0), 2.2, 0.35)
		shockwave(pos, 10.0, 1200.0, 0.35)
		shake(0.12)
		sound("ice_shatter", randf_range(0.95, 1.05), -4.0)
	else:
		burst(pos, "ice", 9, icy, 0.8)
		sound("ice_crack", randf_range(0.95, 1.1), -5.0)


func flip(pos: Vector2) -> void :
	burst(pos, "glint", 6, Color(1, 0.96, 0.86), 0.8)
	glow(pos, Color(1, 0.95, 0.85), 1.4, 0.25)
	sound("flip", randf_range(0.95, 1.08), -6.0)


func flip_accent(pos: Vector2, k: = 1.0) -> void :
	glow(pos, Color(1, 0.93, 0.78), 1.5 * k + 0.4, 0.3)
	burst(pos, "glint", int(6 * k), Color(1, 0.95, 0.85), 0.9)
	if k >= 1.0:
		shockwave(pos, 7.0, 1000.0, 0.35)
	sound("flip", randf_range(1.0, 1.1), -13.0 if k >= 1.0 else -17.0)


func level_intro() -> void :
	sound("level_start", 1.0, -3.0)
	duck(-9.0, 1.6)
	burst(Vector2(vp.x * 0.5, -20), "petal", 26, Color.WHITE, 1.0, null, Vector2(vp.x * 0.45, 10), Vector2(0, 1))
	burst(Vector2(vp.x * 0.5, vp.y * 0.42), "glint", 16, Color(1, 0.9, 0.7), 1.4, null, Vector2(220, 30))
	flash(Color(1, 0.9, 0.8), 0.28, 0.6, Vector2(vp.x * 0.5, vp.y * 0.42), vp.x * 0.7)


func deal(r: = Rect2()) -> void :
	if r.size == Vector2.ZERO:
		r = Rect2(vp * Vector2(0.05, 0.2), vp * Vector2(0.9, 0.55))
	sound("deal", 1.0, -8.0)
	burst(r.get_center() + Vector2(0, r.size.y * 0.5), "dust", 18, Color(1, 0.95, 0.9), 1.2, null, Vector2(r.size.x * 0.45, 6))


func board_clear(pos: = Vector2(-1, -1), blitz: = false) -> void :
	if pos.x < 0:
		pos = vp * Vector2(0.5, 0.45)
	if blitz:
		hit_stop(0.06)
		shake(0.3)
		flash(Color(1, 0.95, 0.85), 0.45, 0.4, pos, vp.y * 0.5)
		shockwave(pos, 20.0, 1600.0, 0.6)
		burst(pos, "spark", 40, Color(1, 0.85, 0.5), 1.4)
		sound("combo_big", 1.1, -4.0)
		return
	hit_stop(0.13, 0.04)
	shake(0.5)
	flash(Color(1, 0.96, 0.88), 0.5, 0.5, pos, vp.y * 0.45, 0.1)
	shockwave(pos, 30.0, 1700.0, 0.8)
	speedlines(0.8, 0.9, Color(1, 0.93, 0.8, 0.9), pos)
	burst(pos, "spark", 70, Color(1, 0.85, 0.5), 1.8)
	burst(pos, "star", 18, Color(1, 0.92, 0.7), 1.6)
	rays(pos, vp.x * 1.6, Color(1, 0.88, 0.6, 0.7), 2.2)
	grade(1.12, 1.05, 0.35, 0.0, g_vig_col, 0.0, 0.15)
	get_tree().create_timer(0.6, true, false, true).timeout.connect( func(): grade_reset(1.0))
	layers([["clear_impact", 1.0, -2.0], ["victory_tail", 1.0, -6.0, 0.3]])
	music_filter(1200.0)
	get_tree().create_timer(1.2, true, false, true).timeout.connect( func(): music_filter(20500.0))
	get_tree().create_timer(0.25, true, false, true).timeout.connect( func():
		burst(Vector2(vp.x * 0.08, vp.y + 20), "confetti", 70, Color.WHITE, 1.0, null, Vector2.ZERO, Vector2(0.35, -1))
		burst(Vector2(vp.x * 0.92, vp.y + 20), "confetti", 70, Color.WHITE, 1.0, null, Vector2.ZERO, Vector2(-0.35, -1)))
	for i in 3:
		get_tree().create_timer(0.45 + i * 0.32, true, false, true).timeout.connect( func():
			var fp: = Vector2(randf_range(0.2, 0.8) * vp.x, randf_range(0.16, 0.38) * vp.y)
			burst(fp, "firework", 48, Color.from_hsv(randf(), 0.45, 1.0), 1.0)
			glow(fp, Color(1, 0.9, 0.8), 1.6, 0.3)
			sound("coin", randf_range(1.3, 1.6), -14.0))


func star(pos: Vector2, i: = 0) -> void :
	burst(pos, "glint", 10 + i * 4, Color(1, 0.9, 0.5), 1.1 + i * 0.2)
	burst(pos, "spark", 14 + i * 6, Color(1, 0.85, 0.45), 0.9 + i * 0.2)
	glow(pos, Color(1, 0.88, 0.5), 1.8 + i * 0.4, 0.35)
	shockwave(pos, 8.0 + i * 5.0, 1000.0, 0.4)
	shake(0.08 + i * 0.07)
	if i == 2:
		hit_stop(0.05)


func fail() -> void :
	failed_now = true
	shake(0.28)
	sound("fail", 1.0, -4.0)
	grade(0.35, 0.92, 0.0, 0.45, Color(0.18, 0.08, 0.2), 0.0, 0.45)
	music_filter(650.0)


func recover() -> void :
	failed_now = false
	danger = false
	grade_reset(0.4)
	music_filter(20500.0)


func set_danger(on: bool) -> void :
	if on == danger or failed_now:
		return
	danger = on
	if on:
		hb_t = 0.0
		grade(1.0, 1.0, 0.0, 0.55, Color(0.85, 0.05, 0.18), 0.7, 0.3)
		music_filter(2400.0)
	else:
		grade_reset(0.35)
		music_filter(20500.0)


func fever(on: bool, color: = Color(1.0, 0.55, 0.2)) -> void :
	if on:
		grade(1.12, 1.03, 0.25, 0.26, color, 0.5, 0.4)
		speedlines(0.45, 0.8, Color(1, 0.85, 0.6, 0.8))
		shake(0.15)
	else:
		grade_reset(0.6)


func skill(pos: Vector2, color: = Color(0.7, 0.85, 1.0)) -> void :
	hit_stop(0.05)
	flash(color, 0.4, 0.4, pos, vp.y * 0.4)
	shockwave(pos, 18.0, 1300.0, 0.6)
	speedlines(0.55, 0.6, Color(color.r, color.g, color.b, 0.8), pos)
	burst(pos, "glint", 24, color.lightened(0.3), 1.6)
	burst(pos, "spark", 30, color, 1.5)
	sound("combo_big", 1.15, -5.0)


func unlock(pos: Vector2, color: = Color(1, 0.85, 0.45)) -> void :
	hit_stop(0.08)
	flash(color, 0.5, 0.5, pos, vp.y * 0.35)
	rays(pos, 760.0, Color(color.r, color.g, color.b, 0.7), 1.6)
	burst(pos, "star", 16, color, 1.4)
	burst(pos, "glint", 20, Color(1, 0.95, 0.85), 1.5)
	sound("rare", 1.0, -4.0)
	duck(-8.0, 2.0)


func ssr(pos: Vector2) -> void :
	unlock(pos, Color(1, 0.8, 0.35))
	shake(0.45)
	shockwave(pos, 28.0, 1600.0, 0.8)
	burst(pos, "firework", 60, Color(1, 0.85, 0.5), 1.4)



func reward_fly(from: Vector2, to: Vector2, kind: = "coin", n: = 6, on_arrive: = Callable()) -> void :
	n = clampi(n, 1, 12)
	burst(from, "glint", 10, Color(1, 0.92, 0.7), 1.1)
	sound("reward_pop", 1.0, -8.0)
	for i in n:
		var s: = Sprite2D.new()
		s.texture = Common.ui_icon(kind)
		var sc: = 52.0 / maxf(1.0, s.texture.get_width())
		s.scale = Vector2.ONE * sc * 0.2
		s.position = from
		parts.add_child(s)
		var mid: = from + Vector2(randf_range(-140, 140), randf_range(-150, 30))
		var ctrl: = mid.lerp(to, 0.4) + Vector2(randf_range(-60, 60), -120)
		var t: = s.create_tween()
		t.tween_property(s, "position", mid, 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).set_delay(i * 0.05)
		t.parallel().tween_property(s, "scale", Vector2.ONE * sc, 0.2).set_delay(i * 0.05).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var along: = func(v: float) -> void :
			var a: = mid.lerp(ctrl, v)
			var b: = ctrl.lerp(to, v)
			s.position = a.lerp(b, v)
			s.rotation = sin(v * 6.0) * 0.3
		t.tween_method(along, 0.0, 1.0, 0.42 + i * 0.015).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.parallel().tween_property(s, "scale", Vector2.ONE * sc * 0.6, 0.42)
		t.tween_callback( func():
			burst(to, "glint", 3, Color(1, 0.95, 0.8), 0.6)
			sound("tick", 1.0 + i * 0.06, -8.0)
			if i == n - 1:
				glow(to, Color(1, 0.9, 0.6), 1.2, 0.3)
				sound("coin" if kind != "heart" else "reward_pop", 1.1, -6.0)
			if on_arrive.is_valid():
				on_arrive.call(i)
			s.queue_free())


func reward_pop(c: Control) -> void :
	if not is_instance_valid(c):
		return
	var pos: = c.get_global_rect().get_center()
	glow(pos, Color(1, 0.9, 0.65), 2.4, 0.4)
	burst(pos, "glint", 14, Color(1, 0.92, 0.7), 1.3)
	burst(pos, "spark", 18, Color(1, 0.85, 0.5), 1.1)
	glint(c, 0.05)
	UI.punch(c, 0.14)
	sound("reward_pop", 1.0, -4.0)


func transition() -> void :
	sound("swoosh", 1.0, -10.0)




func _on_node_added(n: Node) -> void :
	if n is TrayBoard:
		_attach_board.call_deferred(n)

func _attach_board(b: Node) -> void :
	if not is_instance_valid(b) or not b.is_inside_tree():
		return
	var scr: = b.get_parent()
	var redeal: bool = board_screen != null and is_instance_valid(board_screen) and scr == board_screen
	board = b
	board_screen = scr
	seen.clear()
	ice_of.clear()
	secret_of.clear()
	failed_now = false
	danger = false
	grade_reset(0.2)
	music_filter(20500.0)
	b.matched.connect( func(mid: Vector2, combo: int, gold: bool, shard: String):
		if is_instance_valid(b):
			on_match(_canvas(mid), combo, gold, shard))
	b.denied.connect( func(t): deny(_tile_pos(b, t)))
	b.tray_changed.connect( func(): _on_tray(b))
	b.failed.connect( func(): fail())
	b.cleared.connect( func():
		var blitz: = str(scr.get("mode")) == "blitz" if is_instance_valid(scr) else false
		board_clear(_board_center(b), blitz))
	b.tree_exiting.connect( func():
		if board == b:
			board = null
			recover())
	if not redeal:
		get_tree().create_timer(0.12).timeout.connect(level_intro)
	var shown: = [false]
	b.visibility_changed.connect( func():
		if is_instance_valid(b) and b.visible and not shown[0]:
			shown[0] = true
			deal(_board_rect(b)))
	if b.visible:
		shown[0] = true
		get_tree().create_timer(0.05).timeout.connect( func():
			if is_instance_valid(b):
				deal(_board_rect(b)))
	_snapshot(b)

func _canvas(p: Vector2) -> Vector2:

	return get_viewport().canvas_transform.affine_inverse() * p

func _tile_pos(b: Node, t: Node) -> Vector2:
	if not is_instance_valid(t):
		return vp * 0.5
	return _canvas(b.tile_layer.get_global_transform_with_canvas() * t.position)

func _board_rect(b: Node) -> Rect2:
	var r: Rect2 = b.bounds
	if r.size == Vector2.ZERO:
		return Rect2()
	var xf: Transform2D = b.tile_layer.get_global_transform_with_canvas()
	return Rect2(_canvas(xf * r.position), (xf.basis_xform(r.size)).abs())

func _board_center(b: Node) -> Vector2:
	var r: = _board_rect(b)
	return r.get_center() if r.size != Vector2.ZERO else vp * Vector2(0.5, 0.45)

func _snapshot(b: Node) -> void :
	for t in b.tiles:
		var id: int = t.get_instance_id()
		ice_of[id] = int(t.ice)
		secret_of[id] = bool(t.secret)

func _on_tray(b: Node) -> void :
	if not is_instance_valid(b):
		return

	var now_ids: = {}
	for i in b.display.size():
		var t: Node = b.display[i]
		var id: int = t.get_instance_id()
		now_ids[id] = true
		if not seen.has(id):
			var slot: int = i
			get_tree().create_timer(0.24).timeout.connect( func():
				if is_instance_valid(t) and is_instance_valid(b) and t.visible:
					land(_tile_pos(b, t), slot))
	seen = now_ids

	for t in b.tiles:
		var id: int = t.get_instance_id()
		var ice: = int(t.ice)
		var was_ice: int = ice_of.get(id, ice)
		if ice < was_ice:

			if ice == 0:
				flip_accent(_tile_pos(b, t))
			else:
				ice_crack(_tile_pos(b, t), false)
		ice_of[id] = ice
		var sec: = bool(t.secret)
		if secret_of.get(id, sec) and not sec:
			flip_accent(_tile_pos(b, t), 0.5)
		secret_of[id] = sec

	var slots: int = int(b.slots)
	var n: int = b.tray.size()
	if failed_now and n < slots:
		recover()
	set_danger(slots >= 4 and n >= slots - 1 and n < slots)

func _watch_counters() -> void :
	var main: = get_tree().current_scene
	if main == null:
		return
	for key in ["gems_lbl", "coins_lbl"]:
		var l = main.get(key)
		if not (l is Label) or not is_instance_valid(l):
			continue
		var digits: = ""
		for ch in l.text:
			if ch >= "0" and ch <= "9":
				digits += ch
		if digits == "":
			continue
		var v: = int(digits)
		if counters.has(l) and v > int(counters[l]) and l.is_visible_in_tree():
			var p: Vector2 = l.get_global_rect().get_center()
			burst(p, "glint", 5, Color(1, 0.95, 0.75), 0.7)
			if tick_t <= 0.0:
				tick_t = 0.07
				sound("tick", randf_range(1.0, 1.2), -10.0)
		counters[l] = v




func _dev_args() -> void :
	var a: = {}
	for s in OS.get_cmdline_user_args():
		if s.begins_with("--") and "=" in s:
			var kv: = s.substr(2).split("=", true, 1)
			a[kv[0]] = kv[1]
	var dir: String = a.get("v6fx_shots", "")
	if a.has("v6fx_every"):
		_dev_frames(dir, float(a.v6fx_every), float(a.get("v6fx_for", "12")))
	if a.get("v6fx_play", "") == "1":
		_dev_play()
	if a.get("v6fx_demo", "") == "":
		return
	var W: = vp.x
	var H: = vp.y
	var steps: = [
		[1.2, func(): level_intro(), "intro"], 
		[2.6, func(): deal(), ""], 
		[3.0, func(): on_match(Vector2(W * 0.3, H * 0.5), 1), "match1"], 
		[3.6, func(): on_match(Vector2(W * 0.6, H * 0.45), 3), "combo3"], 
		[4.3, func(): on_match(Vector2(W * 0.5, H * 0.55), 5, true), "combo5"], 
		[5.4, func(): ice_crack(Vector2(W * 0.3, H * 0.4), true), "ice"], 
		[5.8, func(): flip(Vector2(W * 0.7, H * 0.4)), ""], 
		[6.4, func(): set_danger(true), "danger"], 
		[7.6, func(): _demo_fail(), "fail"], 
		[8.8, func(): recover(), ""], 
		[9.2, func(): board_clear(Vector2(W * 0.5, H * 0.45)), "clear"], 
		[11.6, func(): reward_fly(Vector2(W * 0.5, H * 0.6), Vector2(W - 90, 50), "gem", 8), "reward"], 
		[12.6, func(): skill(Vector2(W * 0.15, H * 0.2)), "skill"], 
		[13.6, func(): ssr(Vector2(W * 0.5, H * 0.4)), "ssr"], 
	]
	var t0: = 0.0
	for st in steps:
		await get_tree().create_timer(st[0] - t0, true, false, true).timeout
		t0 = st[0]
		st[1].call()
		print("[v6fx] ", st[2] if st[2] != "" else "step")
		if dir != "" and st[2] != "":
			var nm: String = st[2]
			var late: float = {"clear": 0.3, "danger": 0.7, "fail": 0.8}.get(nm, 0.12)
			get_tree().create_timer(late, true, false, true).timeout.connect( func():
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_jpg("%s/fx_%s.jpg" % [dir, nm], 0.85))
	await get_tree().create_timer(2.5, true, false, true).timeout
	print("[v6fx] demo done")
	if a.get("v6fx_quit", "") == "1":
		get_tree().quit()

func _demo_fail() -> void :
	set_danger(false)
	fail()

func _dev_frames(dir: String, every: float, total: float) -> void :
	var n: = int(total / every)
	for i in n:
		await get_tree().create_timer(every, true, false, true).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_jpg("%s/f_%03d.jpg" % [dir, i], 0.8)
	get_tree().quit()


func _dev_play() -> void :
	while true:
		await get_tree().create_timer(0.33).timeout
		if board and is_instance_valid(board) and board.input_on:
			var t = board.solver_move()
			if t:
				board.tap(t)
