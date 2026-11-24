extends Control

# look_selftest — `godot --path game res://scripts/v10/mj/look/look_selftest.tscn -- --mj_look_selftest=1`
# (rendering checks need a display: run under xvfb-run with --rendering-driver opengl3).
# Prints FAIL lines and the summary «MJ_LOOK ok/total»; exit code 0 only when everything passes. Watchdog 600 s.

const LookDemo: = preload("res://scripts/v10/mj/look/look_demo.gd")

var ok: = 0
var total: = 0
var notes: Array = []
var perf_ms: = -1.0


func check(name: String, cond: bool, detail: = "") -> void:
	total += 1
	if cond:
		ok += 1
	else:
		printerr("FAIL %s %s" % [name, detail])


func _ready() -> void:
	if not ("--mj_look_selftest=1" in OS.get_cmdline_user_args()):
		print("look_selftest: pass --mj_look_selftest=1")
	get_tree().create_timer(600.0, true, false, true).timeout.connect(func():
		printerr("MJ_LOOK watchdog")
		get_tree().quit(2))
	await get_tree().process_frame
	await _run()
	for n in notes:
		print("  · ", n)
	print("MJ_LOOK %d/%d" % [ok, total])
	get_tree().quit(0 if ok == total else 1)


func _run() -> void:
	var fx_was: = G.fx_level()
	G.S.fx_level = "full"
	_data_materials()
	_data_tables()
	_audio()
	_haptics()
	_fx_min()
	_particles()
	_legacy_tile()
	if DisplayServer.get_name() != "headless":
		await _render_materials()
		await _render_contrast()
		await _render_near_mask()
		await _render_perf()
	else:
		notes.append("headless: rendering checks skipped (run under xvfb)")
	G.S.fx_level = fx_was


# ── materials ──────────────────────────────────────────────────────────────────────────────────────────────────

func _data_materials() -> void:
	check("materials.count", V10MjTileMaterial.MATERIALS.size() == 6 and V10MjTileMaterial.ORDER.size() == 6)
	for m in V10MjTileMaterial.ORDER:
		var md: Dictionary = V10MjTileMaterial.MATERIALS[m]
		var keys_ok: = true
		for k in ["name", "face", "lip", "seam", "bevel", "back", "spec_pow", "spec_k", "coat", "sss", "grain", "ao", "sfx"]:
			keys_ok = keys_ok and md.has(k)
		check("material.%s.keys" % m, keys_ok)
		var ld: = V10MjTileMaterial.look_dict(m, "rin")
		check("look_dict.%s.v6_compat" % m, ld.side is Color and ld.rim is Color and ld.tint is Color and ld.has("neon"))
		check("look_dict.%s.material" % m, ld.v10mj.material == m and ld.v10mj.params.size() >= 13)
		# the V6 body material accepts the dictionary as it is
		var bm = V6TileLook.body_mat(ld)
		check("look_dict.%s.v6_body_mat" % m, bm is ShaderMaterial)
		# plate stays light: face tint luminance ≥ 0.85 (symbol contrast is the art's, never darkened by material)
		var f: Color = md.face
		check("material.%s.light_plate" % m, f.get_luminance() >= 0.85, str(f.get_luminance()))
	check("look_dict.default_from_table", V10MjTileMaterial.look_dict("", "nova").v10mj.material == "lacquer")
	check("look_dict.invalid_falls_back", V10MjTileMaterial.look_dict("glass").v10mj.material == "porcelain")
	# shadow grows with z: offset and blur up, alpha down
	var s0: = V10MjTileMaterial.shadow_for_z(0)
	var s3: = V10MjTileMaterial.shadow_for_z(3)
	check("shadow.grows_with_z", s3.offset.length() > s0.offset.length() and s3.scale > s0.scale and s3.alpha < s0.alpha)
	# breathing curve 1.00 ↔ 1.01, 3.2 s
	var mn: = 9.0
	var mx: = 0.0
	for i in 321:
		var k: = V10MjTileMaterial.breath_scale(i * 0.01, 3)
		mn = minf(mn, k)
		mx = maxf(mx, k)
	check("breath.range", absf(mn - 1.0) < 0.0005 and absf(mx - 1.01) < 0.0005, "%f..%f" % [mn, mx])
	check("breath.phase_spread", absf(V10MjTileMaterial.phase_for(1) - V10MjTileMaterial.phase_for(2)) > 0.5)


# ── tables ─────────────────────────────────────────────────────────────────────────────────────────────────────

func _data_tables() -> void:
	check("tables.count", V10MjTables.THEMES.size() == 20 and V10MjTables.ORDER.size() == 20)
	var fields: = ["name", "rank", "zone", "lamp", "amb", "material", "tray", "thread", "relic", "symbol", "sig", "accent", "glow", "deep"]
	for id in V10MjTables.ORDER:
		var t: Dictionary = V10MjTables.THEMES.get(id, {})
		var miss: = []
		for f in fields:
			if not t.has(f):
				miss.append(f)
		check("table.%s.fields" % id, miss.is_empty(), str(miss))
		check("table.%s.sig_face" % id, int(t.get("sig", -1)) >= 0 and int(t.get("sig", -1)) < 36)
		check("table.%s.material" % id, V10MjTileMaterial.MATERIALS.has(String(t.get("material", ""))))
		var full: = V10MjTables.get_theme(id, true)
		for p in [full.cloth.tex, full.bg.far]:
			check("table.%s.asset" % id, ResourceLoader.exists(String(p)), String(p))
	for id in V10MjTables.FOUNDERS:
		var th: = V10MjTables.get_theme(id)
		check("founder.%s.own_art" % id, String(th.bg.far).ends_with("far_%s.webp" % id) and ResourceLoader.exists(String(th.bg.near)))
	# hidden heroines never reach the available list
	var av: = V10MjTables.available()
	var leak: = []
	for id in av:
		if not G.HEROES.has(id):
			leak.append(id)
	check("tables.available_only_heroes", leak.is_empty() and av.size() == G.HEROES.size(), str(av))
	for id in V10MjTables.ORDER:
		if not G.HEROES.has(id):
			check("table.%s.hidden" % id, not (id in av) and V10MjTables.theme_for(id).id == "house")
	# rarity rule (UX §7.3)
	var y: = V10MjTables.theme_for("yue")
	check("theme.S_full", y.get("full", false) and String(y.cloth.tex).ends_with("cloth_yue.webp"))
	var r: = V10MjTables.theme_for("rin")
	check("theme.A_light_only", not r.get("full", true) and String(r.cloth.tex).ends_with("cloth_house.webp") and r.amb.fx == "tea" and r.accent == V10MjTables.THEMES.rin.accent)
	check("theme.A_with_SSR_outfit", V10MjTables.theme_for("rin", "", true).get("full", false))
	check("theme.light", V10MjTables.light(y, Rect2(0, 300, 720, 800)).lamp is Vector2)


# ── audio ──────────────────────────────────────────────────────────────────────────────────────────────────────

func _wav_peak_db(st: AudioStreamWAV) -> float:
	if st.format != AudioStreamWAV.FORMAT_16_BITS:
		return -999.0
	var d: = st.data
	var pk: = 0
	for i in range(0, d.size() - 1, 2):
		var v: = d.decode_s16(i)
		pk = maxi(pk, absi(v))
	return 20.0 * log(maxf(float(pk), 1.0) / 32768.0) / log(10.0)


func _audio() -> void:
	var worst: = -999.0
	for key in V10MjAsmr.KEYS:
		var n: int = V10MjAsmr.KEYS[key].n
		check("asmr.%s.variants" % key, n >= 4)
		for i in n:
			var p: = V10MjAsmr.file_for(key, i + 1)
			var ex: = ResourceLoader.exists(p)
			check("asmr.%s.%d.exists" % [key, i + 1], ex, p)
			if ex:
				var st = load(p)
				check("asmr.%s.%d.wav" % [key, i + 1], st is AudioStreamWAV)
				if st is AudioStreamWAV:
					var pk: = _wav_peak_db(st)
					worst = maxf(worst, pk)
					check("asmr.%s.%d.peak" % [key, i + 1], pk <= -6.0 and pk > -40.0, "%.2f dBFS" % pk)
	notes.append("SFX: %d keys, loudest peak %.2f dBFS" % [V10MjAsmr.KEYS.size(), worst])
	for m in V10MjAsmr.MATS:
		check("asmr.clack.%s.six" % m, V10MjAsmr.KEYS["clack_" + m].n == 6)
	for a in V10MjAsmr.AMBIENTS:
		check("asmr.ambient.%s" % a, ResourceLoader.exists(V10MjAsmr.ambient_path(a)))
	# pitch: every play within ±3%, no immediate repeat of a variant
	var asmr: = V10MjAsmr.inst()
	asmr.log_on = true
	asmr.played.clear()
	var bad_pitch: = 0
	var repeats: = 0
	var last: = {}
	for i in 1200:
		var r: = V10MjAsmr.clack(V10MjAsmr.MATS[i % 6])
		if r.jitter < 0.97 - 1e-6 or r.jitter > 1.03 + 1e-6:
			bad_pitch += 1
		if last.get(r.key, "") == r.file:
			repeats += 1
		last[r.key] = r.file
	check("asmr.pitch_within_3pct", bad_pitch == 0, str(bad_pitch))
	check("asmr.no_immediate_repeat", repeats == 0, str(repeats))
	# series: a semitone per combo step, capped at an octave; gong on every ×5
	var ladder_ok: = true
	var gongs: = []
	for n in range(1, 17):
		var r: = V10MjAsmr.pair("jade", n)
		var want: = pow(2.0, float(mini(n - 1, 12)) / 12.0)
		if absf(r.pitch / r.jitter - want) > 0.0005:
			ladder_ok = false
		if r.get("gong", false):
			gongs.append(n)
	check("asmr.series_semitone", ladder_ok)
	check("asmr.gong_every_5", gongs == [5, 10, 15], str(gongs))
	check("asmr.felt_own_quieter", V10MjAsmr.felt(true).db < V10MjAsmr.felt(false).db)
	check("asmr.triple_suits", V10MjAsmr.triple(0).key == "triple_0" and V10MjAsmr.triple(9).key == "triple_4")
	asmr.log_on = false
	# music
	for mode in V10MjMusic.TRACKS:
		check("music.%s" % mode, ResourceLoader.exists(V10MjMusic.path_for(V10MjMusic.TRACKS[mode])))
	for l in V10MjMusic.LAYERS:
		check("music.layer.%s" % l, ResourceLoader.exists(V10MjMusic.path_for(l)))
	for mode in V10MjMusic.FALLBACK:
		check("music.fallback.%s" % mode, V10MjMusic.track_for(mode) != "")


# ── haptics ────────────────────────────────────────────────────────────────────────────────────────────────────

func _haptics() -> void:
	var H: = V10MjHaptics
	check("hap.tap_10", H.contact_ms(H.pattern_for("tap")) == 10)
	check("hap.tick_15", H.contact_ms(H.pattern_for("tick")) == 15)
	var d: = H.pattern_for("double")
	check("hap.double_2x12", d.size() == 2 and int(d[0][0]) == 12 and int(d[1][0]) == 12)
	var r3: = H.pattern_for("rumble", 3)
	var r9: = H.pattern_for("rumble", 9)
	check("hap.rumble_40", H.contact_ms(r3) == 40 and r3.size() == 4)
	check("hap.rumble_rises", float(r3[3][1]) > float(r3[0][1]) and float(r9[3][1]) > float(r3[3][1]))
	check("hap.heartbeat_2", H.pattern_for("heartbeat").size() == 2)
	var w: = H.pattern_for("win")
	var mx: = 0.0
	for s in w:
		mx = maxf(mx, float(s[1]))
	check("hap.win_soft_wave", w.size() >= 4 and mx <= 0.6)
	H.log_on = true
	H.played.clear()
	H.combo(2)
	H.combo(4)
	check("hap.combo_kinds", H.played.size() == 2 and H.played[0][0] == "tick" and H.played[1][0] == "rumble")
	G.S.fx_level = "min"
	check("hap.heartbeat_off_at_min", H.play("heartbeat") == false)
	G.S.fx_level = "full"
	H.log_on = false


# ── fx min: no breathing, no particles ─────────────────────────────────────────────────────────────────────────

func _fx_min() -> void:
	G.S.fx_level = "min"
	V10MjTileView.clear_cache()
	check("fxmin.breath_off", not V10MjTileMaterial.breath_on())
	var t: = V10MjTileView.new()
	t.setup(3, 0, "jade")
	t.set_state(true, false)
	check("fxmin.view_breathe_0", float(t.face_spr.material.get_shader_parameter("breathe")) == 0.0 and float(t.body.material.get_shader_parameter("breathe")) == 0.0)
	var tv: = V10MjTableView.new()
	tv.size = Vector2(720, 1280)
	tv.setup(V10MjTables.get_theme("yue"), Rect2(24, 300, 672, 794), Rect2(24, 300, 672, 794))
	check("fxmin.no_particles", tv.particle_budget() == 0 and tv._parts.is_empty())
	tv.free()
	t.free()
	G.S.fx_level = "mid"
	var tv2: = V10MjTableView.new()
	tv2.size = Vector2(720, 1280)
	tv2.setup(V10MjTables.get_theme("yue"), Rect2(24, 300, 672, 794), Rect2(24, 300, 672, 794))
	check("fxmid.8_particles", tv2._parts.size() == 8)
	tv2.free()
	G.S.fx_level = "full"
	V10MjTileView.clear_cache()
	var t2: = V10MjTileView.new()
	t2.setup(3, 0, "jade")
	t2.set_state(true, false)
	check("fxfull.view_breathes", float(t2.face_spr.material.get_shader_parameter("breathe")) == 1.0)
	t2.set_state(false, true)
	check("closed.shade", float(t2.face_spr.material.get_shader_parameter("closed")) == 1.0 and float(t2.face_spr.material.get_shader_parameter("breathe")) == 0.0)
	t2.free()


# particles never enter the sacred zone (+8 px)
func _particles() -> void:
	for id in ["mc", "rin", "hana", "yue", "nova"]:
		var tv: = V10MjTableView.new()
		tv.size = Vector2(720, 1280)
		var br: = Rect2(24, 300, 672, 794)
		tv.setup(V10MjTables.get_theme(id), br, br)
		check("particles.%s.budget" % id, tv._parts.size() == 18)
		var inside: = 0
		for step in 3000:
			tv._t += 1.0 / 60.0
			for i in tv._parts.size():
				var p: Dictionary = tv._parts[i]
				p.age += 1.0 / 60.0
				p.pos += p.vel / 60.0
				if p.age > p.life or p.pos.y > tv.size.y + 20 or p.pos.x > tv.size.x + 20 or p.pos.x < -20 or p.pos.y < -30:
					tv._parts[i] = tv._new_particle(false)
				var q: Vector2 = tv._parts[i].pos
				if br.grow(8).has_point(q) and tv.particle_alpha(q) > 0.0:
					inside += 1
		check("particles.%s.never_on_board" % id, inside == 0, str(inside))
		tv.free()


# dress() on a legacy Tile keeps the board's uniforms and swaps in the material shaders
func _legacy_tile() -> void:
	var t: = Tile.new()
	t.face = 5
	t.build(G.SKIN_LOOK.s_mint)
	t.mat.set_shader_parameter("shade", 0.77)
	var ld: = V10MjTileMaterial.look_dict("amber", "hana")
	V10MjTileMaterial.dress(t, ld)
	check("legacy.face_shader", t.mat.shader == V10MjTileMaterial.FACE_SHADER)
	check("legacy.keeps_uniforms", absf(float(t.mat.get_shader_parameter("shade")) - 0.77) < 0.001)
	check("legacy.body_shader", t.side_j.material is ShaderMaterial and (t.side_j.material as ShaderMaterial).shader == V10MjTileMaterial.BODY_SHADER)
	V10MjTileMaterial.tile_state(t, false, true, 4)
	check("legacy.closed_state", float(t.mat.get_shader_parameter("closed")) == 1.0)
	t.queue_free()  # Tile has a «free» property (scripts/tile.gd)


# ── rendering (xvfb) ───────────────────────────────────────────────────────────────────────────────────────────

func _page(name: String, a: = {}) -> Dictionary:
	for c in get_children():
		c.queue_free()
	await get_tree().process_frame
	V10MjTileView.clear_cache()
	var root: = Control.new()
	root.size = get_viewport_rect().size
	add_child(root)
	var info: Dictionary = LookDemo.build_page(root, name, a)
	info.root = root
	for i in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	info.img = get_viewport().get_texture().get_image()
	return info


static func lin(c: float) -> float:
	return c / 12.92 if c <= 0.04045 else pow((c + 0.055) / 1.055, 2.4)


static func rel_lum(c: Color) -> float:
	return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b)


static func contrast(a: float, b: float) -> float:
	return (maxf(a, b) + 0.05) / (minf(a, b) + 0.05)


# plate luminance of a tile: the 85th percentile of the face area (the ivory plate, not the symbol)
func _plate_lum(img: Image, t: Node2D) -> float:
	var vs: = get_viewport().get_visible_rect().size
	var k: = Vector2(img.get_width(), img.get_height()) / vs
	var c: Vector2 = Vector2(t.get_meta("pos", t.global_position)) * k
	var tk: = float(t.get_meta("k", 1.0))
	var hw: = 34.0 * tk * k.x
	var hh: = 36.0 * tk * k.y
	var ls: = []
	var stepx: = maxf(1.0, hw / 10.0)
	var y: = c.y - hh
	while y < c.y + hh:
		var x: = c.x - hw
		while x < c.x + hw:
			ls.append(rel_lum(img.get_pixel(clampi(int(x), 0, img.get_width() - 1), clampi(int(y), 0, img.get_height() - 1))))
			x += stepx
		y += stepx
	ls.sort()
	return ls[int(ls.size() * 0.85)]


func _cloth_lum(img: Image, br: Rect2, tiles: Array) -> float:
	var vs: = get_viewport().get_visible_rect().size
	var k: = Vector2(img.get_width(), img.get_height()) / vs
	var top: = 99999.0
	for t in tiles:
		top = minf(top, Vector2(t.get_meta("pos", t.global_position)).y - 60.0)
	var ls: = []
	var y: = br.position.y + 24.0
	while y < top:
		var x: = br.position.x + 24.0
		while x < br.end.x - 24.0:
			ls.append(rel_lum(img.get_pixel(int(x * k.x), int(y * k.y))))
			x += 9.0
		y += 9.0
	if ls.is_empty():
		return 1.0
	ls.sort()
	# the brightest cloth (under the lamp) is the worst case
	return ls[int(ls.size() * 0.95)]


func _render_materials() -> void:
	for m in V10MjTileMaterial.ORDER:
		var info: = await _page("materials_probe", {"material": m})
		var tiles: Array = info.tiles
		var free_t = null
		for t in tiles:
			if t.is_open:
				free_t = t
				break
		var pl: = _plate_lum(info.img, free_t)
		check("render.%s.compiles" % m, pl > 0.45, "plate lum %.3f" % pl)
		# not the error magenta and not blank: the plate is near-neutral
		var fp: Vector2 = free_t.get_meta("pos", free_t.global_position)
		var c: Color = info.img.get_pixel(int(fp.x * info.img.get_width() / get_viewport_rect().size.x) + 26, int(fp.y * info.img.get_height() / get_viewport_rect().size.y) - 30)
		check("render.%s.not_magenta" % m, not (c.r > 0.8 and c.b > 0.8 and c.g < 0.3), str(c))


func _render_contrast() -> void:
	for id in ["house", "mc", "rin", "hana", "yue", "nova"]:
		var info: = await _page(id if id != "house" else "materials_probe", {})
		var tiles: Array = info.tiles
		var cl: = _cloth_lum(info.img, info.board_rect, tiles)
		var worst: = 99.0
		for t in tiles:
			if not t.is_open:
				continue
			worst = minf(worst, contrast(_plate_lum(info.img, t), cl))
		# closed tiles: the 18% shade must still hold the line
		var worst_closed: = 99.0
		var n: = 0
		for t in tiles:
			if t.closed and t.z == 0 and n < 6:
				n += 1
				worst_closed = minf(worst_closed, contrast(_plate_lum(info.img, t), cl))
		notes.append("contrast %s: free %.2f:1, closed %.2f:1 (cloth L %.3f)" % [id, worst, worst_closed, cl])
		check("contrast.%s.free" % id, worst >= 4.5, "%.2f" % worst)
		check("contrast.%s.closed" % id, worst_closed >= 4.5, "%.2f" % worst_closed)


# the near layer never paints the sacred zone: render with it on and off, the board rect is pixel-identical
func _render_near_mask() -> void:
	# fx min: nothing breathes or flickers, so the two renders differ only by the near layer
	G.S.fx_level = "min"
	for id in ["mc", "yue", "nova"]:
		var info: = await _page(id, {})
		var tv: V10MjTableView = info.table
		var a: Image = info.img
		tv.front.visible = false
		for i in 3:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var b: = get_viewport().get_texture().get_image()
		var br: Rect2 = info.board_rect.grow(8)
		var k: = a.get_width() / get_viewport_rect().size.x
		var diff: = 0
		var y: = br.position.y
		while y < br.end.y:
			var x: = br.position.x
			while x < br.end.x:
				var ca: = a.get_pixel(int(x * k), int(y * k))
				var cb: = b.get_pixel(int(x * k), int(y * k))
				if absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b) > 0.06:
					diff += 1
				x += 7.0
			y += 7.0
		check("near.%s.off_sacred" % id, diff == 0, "%d px differ" % diff)
	G.S.fx_level = "full"


func _render_perf() -> void:
	var info: = await _page("stack144", {})
	check("perf.144_tiles", info.tiles.size() == 144)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	for i in 20:
		await get_tree().process_frame
	var t0: = Time.get_ticks_usec()
	var frames: = 120
	for i in frames:
		await RenderingServer.frame_post_draw
	perf_ms = float(Time.get_ticks_usec() - t0) / 1000.0 / frames
	notes.append("144-tile stack: %.2f ms/frame on this renderer (%s)" % [perf_ms, RenderingServer.get_video_adapter_name()])
	check("perf.144_le_16ms", perf_ms <= 16.0, "%.2f ms" % perf_ms)
