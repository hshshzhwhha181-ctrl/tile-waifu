class_name V10HudFxVictoryStarsTest
extends RefCounted

# Selftest of V10VictoryStars (victory_stars.gd). Deterministic: the beat is stepped with advance(dt) at 1/120 s,
# no wall clock except the «runs by itself and goes still» check. Returns {passed, failed, lines (failures)}.
#   timings (3 stars) · curves · notes · fx full/mid/min · calm · particle caps · light caps and flash rate ·
#   earned 0..3 and out of range · show_static · painted art and fallback · cleanup (parent freed mid-beat) ·
#   still after `finished` · placement over V10HudVictory · no hex colours in the module

const DT: = 1.0 / 120.0
const EPS: = 0.0005


static func run(host: Node) -> Dictionary:
	var r: = {"passed": 0, "failed": 0, "lines": []}
	var fx0: = V10Hud2Util.fx_override
	var calm_had: bool = G.S is Dictionary and G.S.has("a11y_calm")
	var calm0 = G.S.get("a11y_calm") if calm_had else null
	_set_calm(false)
	V10Hud2Util.fx_override = "full"
	_timings(host, r)
	_levels(host, r)
	_earned(host, r)
	_static(host, r)
	_art(host, r)
	await _cleanup(host, r)
	await _live(host, r)
	await _context(host, r)
	_source(r)
	V10Hud2Util.fx_override = fx0
	if calm_had:
		G.S["a11y_calm"] = calm0
	elif G.S is Dictionary:
		G.S.erase("a11y_calm")
	return r


static func _ok(r: Dictionary, cond: bool, msg: String) -> void:
	if cond:
		r.passed += 1
	else:
		r.failed += 1
		(r.lines as Array).append("FAIL victory_stars: " + msg)


static func _near(a: float, b: float, eps: = EPS) -> bool:
	return absf(a - b) <= eps


static func _set_calm(on: bool) -> void:
	if G.S is Dictionary:
		G.S["a11y_calm"] = on


static func _make(host: Node) -> V10VictoryStars:
	var s: = V10VictoryStars.new()
	host.add_child(s)
	s.set_process(false)
	return s


# run the beat to `time` (s since play) in fixed steps; track caps on the way
static func _run_to(s: V10VictoryStars, time: float, track: = {}) -> void:
	while s.playing and s.t + 1.0e-6 < time:
		s.advance(minf(DT, time - s.t))
		if not track.is_empty():
			track.max_dust = maxi(int(track.max_dust), s.live_dust())
			for k in s.earned:
				var a: = s.glow_alpha(k)
				track.max_glow = maxf(float(track.max_glow), a)
				if a > 0.0:
					var c: = s.glow_color(k)
					track.max_value = maxf(float(track.max_value), c.v)
			for i in s.centers.size():
				var st: Node2D = s._stars[i]
				if st.scale.x < 1.0 - EPS or st.scale.x > V10VictoryStars.LAND_SCALE + EPS:
					track.bad_scale = int(track.bad_scale) + 1


static func _track() -> Dictionary:
	return {"max_dust": 0, "max_glow": 0.0, "max_value": 0.0, "bad_scale": 0}


static func _a(n: Node) -> float:
	var c: CanvasItem = n
	return c.modulate.a if c.visible else 0.0


# ------------------------------------------------------------------ 1 timings, curves, notes (full, 3 stars)

static func _timings(host: Node, r: Dictionary) -> void:
	var s: = _make(host)
	var fin: = [0]
	s.finished.connect(func() -> void: fin[0] += 1)
	s.play(3, 0.25)
	_ok(r, s.centers.size() == 3 and _near(s.star_size, 56.0), "default layout is not the hud2 one (3 × 56)")
	for i in 3:
		_ok(r, s.centers[i] == Vector2(28 + 72 * i, 28), "default centre %d = %s (hud2 _Stars: %s)" % [i, s.centers[i], Vector2(28 + 72 * i, 28)])
		_ok(r, _near(s.slot_time(i), 0.25 + 0.04 * i), "slot %d «Вдох» at %.3f (want %.3f)" % [i, s.slot_time(i), 0.25 + 0.04 * i])
		_ok(r, _near(s.land_time(i), 0.25 + 0.32 + 0.2 * i), "star %d lands at %.3f (want %.3f)" % [i, s.land_time(i), 0.57 + 0.2 * i])
	_ok(r, _near(s.duration(), 0.25 + 1.28), "3-star beat lasts %.3f (want 1.530)" % s.duration())
	# before anything: all hidden, slots 12 px low
	for i in 3:
		_ok(r, _a(s._slots[i]) == 0.0 and _a(s._stars[i]) == 0.0, "t=0: slot/star %d visible" % i)
		_ok(r, _near((s._slots[i] as Node2D).position.y - s.centers[i].y, 12.0), "t=0: slot %d not at y+12" % i)
	# slot 1 half way through its «Вдох»: QUINT_OUT(0.5) = 0.96875
	_run_to(s, s.slot_time(1) + 0.12)
	var q: = V10VictoryStars.quint_out(0.5)
	_ok(r, _near(q, 0.96875), "quint_out(0.5) = %.5f" % q)
	_ok(r, _near(_a(s._slots[1]), q, 0.002), "slot 1 α %.4f at half «Вдох» (want %.4f)" % [_a(s._slots[1]), q])
	_ok(r, _near((s._slots[1] as Node2D).position.y - s.centers[1].y, 12.0 * (1.0 - q), 0.02), "slot 1 y offset %.3f at half «Вдох»" % ((s._slots[1] as Node2D).position.y - s.centers[1].y))
	_ok(r, _near((s._slots[1] as Node2D).scale.x, 1.0), "slot «Вдох» touches the scale")
	_ok(r, _a(s._slots[2]) > 0.0 and _a(s._slots[2]) < _a(s._slots[1]), "slots are not stepped 40 ms")
	# star 1 mid-landing
	_run_to(s, s.land_time(1) + 0.12)
	var st1: Node2D = s._stars[1]
	_ok(r, _near(st1.scale.x, lerpf(1.25, 1.0, q), 0.002), "star 2 scale %.4f at half landing (want %.4f)" % [st1.scale.x, lerpf(1.25, 1.0, q)])
	_ok(r, _near(_a(st1), q, 0.002), "star 2 α %.4f at half landing" % _a(st1))
	_ok(r, _near(_a(s._stars[0]), 1.0) and _near((s._stars[0] as Node2D).scale.x, 1.0), "star 1 not settled while star 2 lands")
	_ok(r, _a(s._stars[2]) == 0.0, "star 3 visible before its turn")
	_ok(r, _a(s._slots[1]) < 0.1, "slot 2 still shows under its landing star (α %.2f)" % _a(s._slots[1]))
	_ok(r, _near(_a(s._slots[2]), 1.0), "slot 3 not in place while star 2 lands")
	# start of a landing: 1.25, α 0
	_run_to(s, s.land_time(2))
	_ok(r, _near((s._stars[2] as Node2D).scale.x, 1.25, 0.002) and _a(s._stars[2]) < 0.01, "star 3 does not start at 1.25 / α 0")
	_run_to(s, s.land_time(2) + 0.24)
	_ok(r, _near((s._stars[2] as Node2D).scale.x, 1.0) and _near(_a(s._stars[2]), 1.0), "star 3 not landed after 240 ms")
	# notes: E G A, 60 ms into each landing
	_ok(r, s.notes == PackedInt32Array([2, 3, 4]), "notes %s (want rising pentatonic [2, 3, 4])" % [s.notes])
	for k in mini(3, s.note_at.size()):
		_ok(r, absf(s.note_at[k] - (s.land_time(k) + 0.06)) <= DT + EPS, "note %d at %.3f (want %.3f)" % [k, s.note_at[k], s.land_time(k) + 0.06])
	# lights: ≤ 3 per second
	var hits: = s.note_at
	var worst: = 0
	for a in hits.size():
		var c: = 0
		for b in hits.size():
			if hits[b] >= hits[a] and hits[b] < hits[a] + 1.0:
				c += 1
		worst = maxi(worst, c)
	_ok(r, worst <= 3, "%d light discs within one second (cap 3)" % worst)
	_run_to(s, 10.0)
	_ok(r, fin[0] == 1, "finished emitted %d times (want 1)" % fin[0])
	_ok(r, not s.playing and not s.is_processing(), "still processing after finished")
	_ok(r, _near(s.t, s.duration(), DT), "finished at %.3f (want %.3f)" % [s.t, s.duration()])
	_ok(r, s.live_dust() == 0 and not s._light.visible and not s._dust.visible, "light/dust alive after finished")
	_ok(r, s.get_child(0) == s._light and s.get_child(s.get_child_count() - 1) == s._dust, "discs not behind / dust not in front of the stars")
	_ok(r, (s._light.material as CanvasItemMaterial).blend_mode == CanvasItemMaterial.BLEND_MODE_ADD and s._dust.material == null, "discs not additive or dust not normal blend")
	for i in 3:
		_ok(r, _near(_a(s._stars[i]), 1.0) and _near((s._stars[i] as Node2D).scale.x, 1.0) and _a(s._slots[i]) == 0.0, "final state of star %d" % i)
	# nothing moves any more
	var snap: = []
	for n in s._stars + s._slots:
		snap.append([(n as Node2D).position, (n as Node2D).scale, (n as Node2D).modulate])
	s.advance(0.5)
	var same: = true
	var j: = 0
	for n in s._stars + s._slots:
		same = same and snap[j] == [(n as Node2D).position, (n as Node2D).scale, (n as Node2D).modulate]
		j += 1
	_ok(r, same, "something moved after finished")
	_ok(r, fin[0] == 1, "finished emitted again")
	# replay resets
	s.play(3, 0.0)
	_ok(r, s.playing and _a(s._stars[0]) == 0.0 and s.notes.is_empty(), "replay does not reset")
	s.queue_free()


# ------------------------------------------------------------------ 2 fx levels, calm, caps

static func _levels(host: Node, r: Dictionary) -> void:
	var want_dust: = {"full": 7, "mid": 4, "min": 0}
	for lv in ["full", "mid", "min"]:
		V10Hud2Util.fx_override = lv
		var s: = _make(host)
		s.play(3, 0.0)
		var tr: = _track()
		var per_star: = []
		var seen: = 0
		while s.playing and s.t < 5.0:
			s.advance(DT)
			if s.d_n > seen:
				per_star.append(s.d_n - seen)
				seen = s.d_n
			tr.max_dust = maxi(int(tr.max_dust), s.live_dust())
			for k in 3:
				tr.max_glow = maxf(float(tr.max_glow), s.glow_alpha(k))
				if s.glow_alpha(k) > 0.0:
					tr.max_value = maxf(float(tr.max_value), s.glow_color(k).v)
		_ok(r, s.dust_per == want_dust[lv], "%s: %d motes per star (want %d)" % [lv, s.dust_per, want_dust[lv]])
		_ok(r, s.dust_per <= 8, "%s: more than 8 motes per star" % lv)
		var spawned: = 0
		for c in per_star:
			spawned += int(c)
			_ok(r, int(c) <= want_dust[lv], "%s: a landing spawned %d motes" % [lv, c])
		_ok(r, spawned == 3 * int(want_dust[lv]), "%s: %d motes in all (want %d)" % [lv, spawned, 3 * int(want_dust[lv])])
		_ok(r, int(tr.max_dust) <= 3 * int(want_dust[lv]), "%s: %d motes alive at once" % [lv, tr.max_dust])
		var gmax: float = {"full": 0.45, "mid": 0.30, "min": 0.0}[lv]
		_ok(r, float(tr.max_glow) <= gmax + EPS, "%s: disc α %.3f (cap %.2f)" % [lv, tr.max_glow, gmax])
		if lv != "min":
			_ok(r, float(tr.max_glow) > gmax * 0.8, "%s: disc too faint (%.3f)" % [lv, tr.max_glow])
		_ok(r, float(tr.max_glow) <= V10HudFx.LIGHT_ALPHA_MAX and float(tr.max_value) <= V10HudFx.LIGHT_VALUE_MAX + EPS, "%s: light not warm-capped (α %.2f, v %.2f)" % [lv, tr.max_glow, tr.max_value])
		_ok(r, not s.playing and not s.is_processing() and s.live_dust() == 0, "%s: not still at the end" % lv)
		if lv == "min":
			_ok(r, _near(s.duration(), V10HudFx.T_MIN), "min: lasts %.3f (want 0.12)" % s.duration())
			_ok(r, s.notes.size() == 1 and s.notes[0] == 4, "min: notes %s (want one, [4])" % [s.notes])
			# mid-fade: every earned star and nothing else, no scale, no offset
			s.play(2, 0.0)
			_run_to(s, 0.06)
			var ok_fade: = true
			for i in 3:
				var st: Node2D = s._stars[i]
				var sl: Node2D = s._slots[i]
				ok_fade = ok_fade and _near(st.scale.x, 1.0) and _near(sl.position.y, s.centers[i].y)
				if i < 2:
					ok_fade = ok_fade and _a(st) > 0.2 and _a(st) < 0.8 and _a(sl) == 0.0
				else:
					ok_fade = ok_fade and _a(sl) > 0.2 and _a(sl) < 0.8 and _a(st) == 0.0
			_ok(r, ok_fade, "min: not one 120 ms fade of the whole row")
			_ok(r, _near(_a(s._stars[0]), _a(s._stars[1])), "min: earned stars do not fade together")
			_run_to(s, 1.0)
			_ok(r, s.notes.size() == 1 and s.notes[0] == 3, "min, 2 stars: notes %s (want [3])" % [s.notes])
			_ok(r, _near(_a(s._stars[1]), 1.0) and _near(_a(s._slots[2]), 1.0), "min: information lost (stars %.2f, slot %.2f)" % [_a(s._stars[1]), _a(s._slots[2])])
		else:
			_ok(r, _near(s.duration(), 1.28), "%s: lasts %.3f (want 1.28)" % [lv, s.duration()])
		s.queue_free()
	# calm: no light discs at any level, dust and notes stay
	V10Hud2Util.fx_override = "full"
	_set_calm(true)
	var c2: = _make(host)
	c2.play(3, 0.0)
	var tr2: = _track()
	_run_to(c2, 5.0, tr2)
	_ok(r, float(tr2.max_glow) == 0.0 and c2.glow_peak == 0.0, "calm: light discs α %.2f" % tr2.max_glow)
	_ok(r, c2.notes.size() == 3 and int(tr2.max_dust) > 0, "calm: lost notes or dust")
	_ok(r, int(tr2.bad_scale) == 0, "scale outside 1.0..1.25 (%d frames)" % tr2.bad_scale)
	_set_calm(false)
	c2.queue_free()
	# the third star's disc is a little larger
	var s3: = _make(host)
	s3.play(3, 0.0)
	_run_to(s3, s3.hit_time(2) + 0.2)
	var r3: = s3.glow_radius(2)
	var r1: = s3.glow_radius(1)
	_ok(r, r3 > r1 * 1.1 and r3 < r1 * 1.4, "third disc %.1f px vs %.1f (want slightly larger)" % [r3, r1])
	_ok(r, r1 <= 56.0 * 1.0 + EPS, "disc radius %.1f px too large" % r1)
	s3.queue_free()


# ------------------------------------------------------------------ 3 earned 0..3

static func _earned(host: Node, r: Dictionary) -> void:
	V10Hud2Util.fx_override = "full"
	for e in [0, 1, 2, 3, 5, -1]:
		var s: = _make(host)
		var fin: = [0]
		s.finished.connect(func() -> void: fin[0] += 1)
		s.play(e, 0.1)
		var want: = clampi(e, 0, 3)
		_ok(r, s.earned == want, "play(%d): earned %d" % [e, s.earned])
		var dur: = s.duration()
		if want == 0:
			_ok(r, _near(dur, 0.1 + 0.32), "0 stars: lasts %.3f (want 0.42: slots only)" % dur)
		else:
			_ok(r, _near(dur, 0.1 + 0.32 + 0.2 * (want - 1) + 0.06 + 0.5), "%d stars: lasts %.3f" % [want, dur])
		_run_to(s, 10.0)
		_ok(r, fin[0] == 1 and not s.is_processing(), "play(%d): finished %d, processing %s" % [e, fin[0], s.is_processing()])
		var expect: = PackedInt32Array()
		for k in want:
			expect.append(k + 2)
		_ok(r, s.notes == expect, "play(%d): notes %s (want %s)" % [e, s.notes, expect])
		for i in 3:
			if i < want:
				_ok(r, _near(_a(s._stars[i]), 1.0) and _a(s._slots[i]) == 0.0, "play(%d): star %d not lit" % [e, i])
			else:
				_ok(r, _a(s._stars[i]) == 0.0 and _near(_a(s._slots[i]), 1.0) and _near((s._slots[i] as Node2D).position.y, s.centers[i].y), "play(%d): slot %d not an empty socket in place" % [e, i])
		s.queue_free()
	# no centres at all: finishes on the next step, no crash
	var z: = _make(host)
	var zf: = [0]
	z.finished.connect(func() -> void: zf[0] += 1)
	z.configure([], 56.0)
	z.play(3, 0.0)
	z.advance(DT)
	_ok(r, z.earned == 0 and zf[0] == 1 and not z.is_processing(), "empty configure: earned %d, finished %d" % [z.earned, zf[0]])
	# re-configure while playing (5 centres, other size)
	z.configure([Vector2(10, 10), Vector2(60, 10), Vector2(110, 10), Vector2(160, 10), Vector2(210, 10)], 40.0)
	z.play(5, 0.0)
	_ok(r, z.earned == 5 and z._stars.size() == 5 and z._slots.size() == 5, "5 centres: %d stars" % z._stars.size())
	_ok(r, _near(z.land_time(0), 0.24 + 4 * 0.04), "5 centres: first landing after all slots (%.3f)" % z.land_time(0))
	z.configure(V10VictoryStars.HUD2_CENTERS, 56.0)
	_ok(r, z._stars.size() == 3 and z.get_child_count() == 8 and z.get_child(z.get_child_count() - 1) == z._dust, "back to 3 centres: %d children (want 8, dust last)" % z.get_child_count())
	z.queue_free()


# ------------------------------------------------------------------ 4 show_static

static func _static(host: Node, r: Dictionary) -> void:
	V10Hud2Util.fx_override = "full"
	var s: = _make(host)
	var fin: = [0]
	s.finished.connect(func() -> void: fin[0] += 1)
	s.show_static(2)
	_ok(r, not s.is_processing() and not s.playing and s.notes.is_empty(), "show_static: processing or sound")
	for i in 3:
		var st: Node2D = s._stars[i]
		var sl: Node2D = s._slots[i]
		_ok(r, st.position == s.centers[i] and sl.position == s.centers[i] and _near(st.scale.x, 1.0), "show_static: %d not in place" % i)
		if i < 2:
			_ok(r, _near(_a(st), 1.0) and _a(sl) == 0.0, "show_static(2): star %d" % i)
		else:
			_ok(r, _a(st) == 0.0 and _near(_a(sl), 1.0), "show_static(2): slot %d" % i)
	# skip in the middle of the beat
	s.play(3, 0.0)
	_run_to(s, s.land_time(1) + 0.05)
	_ok(r, s.live_dust() > 0, "mid-beat: no dust to cut")
	s.show_static(3)
	_ok(r, not s.is_processing() and s.live_dust() == 0 and not s._light.visible and not s._dust.visible, "show_static mid-beat: light/dust left")
	_ok(r, _near(_a(s._stars[2]), 1.0) and _near((s._stars[1] as Node2D).scale.x, 1.0), "show_static mid-beat: not final")
	_ok(r, fin[0] == 0, "show_static emitted finished")
	s.show_static(9)
	_ok(r, s.earned == 3, "show_static(9) not clamped")
	s.queue_free()


# ------------------------------------------------------------------ 5 painted art / fallback

static func _art(host: Node, r: Dictionary) -> void:
	var keys: = [V10VictoryStars.TEX_STAR, V10VictoryStars.TEX_EMPTY]
	var saved: = {}
	for k in keys:
		if V10HudFx._tex.has(k):
			saved[k] = V10HudFx._tex[k]
	# real files, if they landed, are used
	for k in keys:
		V10HudFx._tex.erase(k)
	var real: = _make(host)
	var have: = ResourceLoader.exists(V10HudFx.ASSETS + V10VictoryStars.TEX_STAR + ".png")
	_ok(r, real.uses_art() == have, "painted star exists=%s but uses_art=%s" % [have, real.uses_art()])
	if have:
		var tx: Texture2D = (real._stars[0] as Node).get("tex")
		_ok(r, tx.get_image().has_mipmaps() and (real._stars[0] as CanvasItem).texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS, "painted star drawn without mipmaps (edges sparkle at 56 px)")
		_ok(r, V10VictoryStars.art_texture(V10HudFx.tex(V10VictoryStars.TEX_STAR)) == tx, "painted star prepared twice")
	real.queue_free()
	# missing files → vector fallback, still drawn
	for k in keys:
		V10HudFx._tex[k] = null
	var fb: = _make(host)
	_ok(r, not fb.uses_art(), "fallback: still holds a texture")
	_ok(r, (fb._stars[0] as Node).get("tex") == null and (fb._slots[0] as Node).get("tex") == null, "fallback: textures on items")
	var g: = V10VictoryStars._geometry()
	_ok(r, (g.polys as Array).size() == 10 and (g.contour as PackedVector2Array).size() == 30, "fallback geometry: %d facets" % (g.polys as Array).size())
	var lit_ok: = true
	for pc in g.cols:
		for c in (pc as PackedColorArray):
			var col: Color = c
			lit_ok = lit_ok and col.v <= V10DS.GOLD_300.v + EPS and col.v >= V10DS.GOLD_700.v - EPS
	_ok(r, lit_ok, "fallback star colours leave the gold.700..gold.300 range")
	fb.show_static(2)
	fb.queue_free()
	# an injected painted texture is fitted: its opaque box centred on the slot, ART_FILL × size
	var img: = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(Color.WHITE, 0.0))
	img.fill_rect(Rect2i(8, 16, 40, 32), Color.WHITE)
	var it: = ImageTexture.create_from_image(img)
	V10HudFx._tex[V10VictoryStars.TEX_STAR] = it
	var pa: = _make(host)
	_ok(r, pa.uses_art() and (pa._slots[0] as Node).get("tex") == null, "injected art: star %s, slot fallback %s" % [pa.uses_art(), (pa._slots[0] as Node).get("tex") == null])
	var rr: = V10VictoryStars.art_rect(it, 56.0)
	var k: = 56.0 * V10VictoryStars.ART_FILL / 40.0
	_ok(r, _near(rr.size.x, 64.0 * k, 0.01) and _near(rr.position.x, -(8.0 + 20.0) * k, 0.01) and _near(rr.position.y, -(16.0 + 16.0) * k, 0.01), "art_rect %s" % rr)
	pa.show_static(3)
	pa.queue_free()
	for kk in keys:
		if saved.has(kk):
			V10HudFx._tex[kk] = saved[kk]
		else:
			V10HudFx._tex.erase(kk)
	V10VictoryStars._fit.erase(it)


# ------------------------------------------------------------------ 6 cleanup: parent freed mid-beat

static func _cleanup(host: Node, r: Dictionary) -> void:
	V10Hud2Util.fx_override = "full"
	var parent: = Control.new()
	host.add_child(parent)
	var s: = V10VictoryStars.new()
	parent.add_child(s)
	s.play(3, 0.0)
	s.advance(0.5)
	_ok(r, s.is_processing() and s.live_dust() > 0, "cleanup: beat not running before the free")
	var children: = s.get_children()
	parent.queue_free()
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	_ok(r, not is_instance_valid(s), "cleanup: module outlived its parent")
	var leaked: = 0
	for c in children:
		if is_instance_valid(c):
			leaked += 1
	_ok(r, leaked == 0, "cleanup: %d children leaked" % leaked)


# ------------------------------------------------------------------ 7 live: runs by itself, then goes still

static func _live(host: Node, r: Dictionary) -> void:
	V10Hud2Util.fx_override = "full"
	var s: = V10VictoryStars.new()
	host.add_child(s)
	var fin: = [0]
	s.finished.connect(func() -> void: fin[0] += 1)
	s.play(3, 0.0)
	var frames: = 0
	var t0: = Time.get_ticks_msec()
	while fin[0] == 0 and frames < 3000 and Time.get_ticks_msec() - t0 < 8000:
		await host.get_tree().process_frame
		frames += 1
	_ok(r, fin[0] == 1, "live: finished not emitted (%d frames)" % frames)
	await host.get_tree().process_frame
	_ok(r, not s.is_processing() and not s._light.visible, "live: still processing after finished")
	var processing: = 0
	for c in s.get_children():
		if (c as Node).is_processing():
			processing += 1
	_ok(r, processing == 0, "live: %d children process" % processing)
	s.queue_free()


# ------------------------------------------------------------------ 8 in context: exactly over V10HudVictory's stars

static func _context(host: Node, r: Dictionary) -> void:
	var vic: = V10HudVictory.new()
	vic.configure({"hero": "mc", "level": "1-4 · Чайный сад", "stars": 2, "next": 5})
	host.add_child(vic)
	var s: = V10VictoryStars.new()
	vic.stars_c.add_child(s)  # as the hud_victory.gd hook does
	s.configure([Vector2(28, 28), Vector2(100, 28), Vector2(172, 28)], 56.0)
	s.show_static(2)
	await host.get_tree().process_frame
	var sr: Rect2 = vic.L.stars
	var inside: = true
	for i in 3:
		var gp: = (s._stars[i] as Node2D).global_position
		var want: = vic.stars_c.global_position + Vector2(28 + 72 * i, 28)
		inside = inside and gp.distance_to(want) < 0.5
	_ok(r, inside, "stars not over the hud2 star slots")
	_ok(r, _near(s.size.x, sr.size.x) and _near(s.size.y, sr.size.y), "module box %s ≠ hud2 stars box %s" % [s.size, sr.size])
	_ok(r, s.mouse_filter == Control.MOUSE_FILTER_IGNORE, "module eats taps (hud2 opens the star criteria by tap)")
	vic.queue_free()
	await host.get_tree().process_frame


# ------------------------------------------------------------------ 9 style law in the source

static func _source(r: Dictionary) -> void:
	var src: = FileAccess.get_file_as_string("res://scripts/v10/hudfx/victory_stars.gd")
	_ok(r, src.length() > 1000, "module source not readable")
	var re: = RegEx.create_from_string("Color\\(\\s*(\"#|0\\.|1\\.|0,|1,)")
	_ok(r, re.search(src) == null, "colour literal outside V10DS in victory_stars.gd")
	for bad in ["GPUParticles2D", "create_tween", "Timer.new", "outline_size"]:
		_ok(r, src.find(bad) == -1, "victory_stars.gd uses %s" % bad)
