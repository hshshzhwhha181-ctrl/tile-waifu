class_name V10Hud2Selftest
extends RefCounted

# --hud2_selftest=1 (docs/HUD_V2.md §7.6, §9.5). Returns the failure count (process exit code).
#   1 plates   — 200 random strings × S/M/L in stretching containers: height stays 48/80/160, width stays a
#                module, every label stays inside its plate; HUD strings fit without ellipsis
#   2 type     — every hud2 Label has outline 0, shadow only when on art; persistent match text ≤ 3 sizes
#   3 layouts  — match / home / victory on 9:16, 9:18, 9:19.5, 9:20, 9:21, 3:4, 10:16 (+ insets): inside the
#                safe area, no overlaps, 8-grid, heroine ≥ 18 % (9:16) / ≥ 28 % (9:20+) in the match,
#                ≥ 35 % home, ≥ 40 % victory, face clear of UI, victory hero ∩ buttons = ∅
#   4 showcase — T1 never puts heroine pixels (α > 0.5) in the centre pair zone, for all 5 founders × ratios;
#                T1 never pauses input; T2 ≤ 1.2 s and T3 ≤ 1.4 s; skip returns input ≤ 120 ms; rules
#                (first per tier, gap, ≤ 3, short/ranked/off, hold/release)
#   5 code     — no hex / Color(0.x) literals in hud2 code outside tokens.gd; exactly 5 persistent match nodes

const RATIOS: = [
	["9:16", Vector2(720, 1280), {"top": 0, "bottom": 0}],
	["9:18", Vector2(720, 1440), {"top": 40, "bottom": 24}],
	["9:19.5", Vector2(720, 1560), {"top": 48, "bottom": 24}],
	["9:20", Vector2(720, 1600), {"top": 48, "bottom": 24}],
	["9:21", Vector2(720, 1680), {"top": 56, "bottom": 24}],
	["3:4", Vector2(960, 1280), {"top": 24, "bottom": 16}],
	["10:16", Vector2(800, 1280), {"top": 24, "bottom": 16}],
]
const HEROES: = ["mc", "rin", "hana", "yue", "nova"]

static var fails: = 0
static var checks: = 0
static var _body: Image


static func ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("HUD2 FAIL: ", what)


static func run(host: Node) -> int:
	fails = 0
	checks = 0
	await _plates(host)
	await _type(host)
	_layouts()
	await _showcase(host)
	_code()
	print("HUD2 SELFTEST %d/%d %s" % [checks - fails, checks, "OK" if fails == 0 else "FAILED"])
	return fails


# ------------------------------------------------------------------ 1 plates

static func _rand_text(rng: RandomNumberGenerator) -> String:
	var words: = ["Подарок", "дня", "Наряд", "«Шёлковый вечер»", "навсегда", "без", "случайности", "Лунного", "камня",
			"Симпатия", "Путь", "1 000", "= 6 желаний", "Маджонг-тян", "Чайный сад", "Ставка ×2", "Ещё", "уровень",
			"Сверхдлиннаяиндустриализированнаястрокабезпробелов", "₽", "№", "—", "WWWWWWWW", "ёЁйЙ", "ыыы", "Ш"]
	var n: = rng.randi_range(0, 14)
	var out: = []
	for i in n:
		out.append(words[rng.randi_range(0, words.size() - 1)])
	return " ".join(out)


static func _plates(host: Node) -> void:
	var rng: = RandomNumberGenerator.new()
	rng.seed = 20261124
	var box: = VBoxContainer.new()
	box.size = Vector2(720, 4000)
	host.add_child(box)
	var plates: = []
	for i in 200:
		var sc: String = ["S", "M", "L"][i % 3]
		var widths: Array = V10DS.PLATE_WIDTHS[sc]
		var w: int = widths[rng.randi_range(0, widths.size() - 1)]
		var p: = V10Plate.make(sc, w, _rand_text(rng), _rand_text(rng) if sc != "S" else "", str(rng.randi_range(0, 99999)) if rng.randf() < 0.5 else "", "heart" if rng.randf() < 0.5 else "")
		# try hard to make it sag / sprawl
		p.size_flags_vertical = Control.SIZE_EXPAND_FILL
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		p.custom_minimum_size = Vector2(0, 0)
		box.add_child(p)
		plates.append(p)
	for i in 3:
		await host.get_tree().process_frame
	box.size = Vector2(900, 60000)  # a stretch after layout
	for i in 3:
		await host.get_tree().process_frame
	var bad_h: = 0
	var bad_w: = 0
	var bad_lbl: = 0
	for p in plates:
		var h: = V10Plate.height_of(p.size_class)
		if absf(p.size.y - h) > 0.01:
			bad_h += 1
		if not (int(p.size.x) in V10DS.PLATE_WIDTHS[p.size_class]):
			bad_w += 1
		for c in p.get_children():
			if c is Label and c.visible:
				var r: Rect2 = Rect2(c.position, c.size)
				if r.position.y < -0.5 or r.end.y > h + 0.5 or r.end.x > p.size.x + 0.5:
					bad_lbl += 1
	ok(bad_h == 0, "plates: %d of 200 changed height" % bad_h)
	ok(bad_w == 0, "plates: %d of 200 left the width modules" % bad_w)
	ok(bad_lbl == 0, "plates: %d labels outside their plate" % bad_lbl)
	box.queue_free()
	# real HUD strings fit without ellipsis
	V10Type.overflow.clear()
	var real: = [["S", 192, "Ставка ×2"], ["S", 144, "ⓘ Шансы"], ["M", 200, "Маджонг-тян"], ["M", 672, "Подарок дня"],
			["M", 672, "300 Лунного камня"], ["L", 672, "Наряд «Шёлковый вечер»"], ["M", 672, "Симпатия"]]
	for r in real:
		var p2: = V10Plate.make(r[0], r[1], r[2], "", "", "")
		host.add_child(p2)
		p2.queue_free()
	ok(V10Type.overflow.is_empty(), "HUD strings overflow: %s" % [V10Type.overflow])


# ------------------------------------------------------------------ 2 type

static func _labels(n: Node, out: Array) -> void:
	if n is Label:
		out.append(n)
	for c in n.get_children():
		_labels(c, out)


static func _type(host: Node) -> void:
	var hud: = V10HudMatch.new()
	host.add_child(hud)
	hud.configure({"hero": "mc", "level": "1-2", "total": 30, "left": 30, "stake_offer": true})
	var home: = V10HudHome.new()
	host.add_child(home)
	var vic: = V10HudVictory.new()
	host.add_child(vic)
	var hdr: = V10Header.make(host as Control, "Очень длинный заголовок подэкрана с переполнением", func() -> void: pass, func() -> void: pass)
	await host.get_tree().process_frame
	var vsz: = (host as Control).get_viewport_rect().size
	ok(absf(hdr.size.y - (V10Hud2Util.safe_insets(vsz).top + V10Header.HEIGHT)) < 0.5, "header grew to %.0f px" % hdr.size.y)
	ok(hdr.title_lbl.position.x + hdr.title_lbl.size.x <= hdr.help_btn.position.x + 0.5, "header title runs under «?»")
	var ls: = []
	for n in [hud, home, vic, hdr]:
		_labels(n, ls)
	var bad: = 0
	var bad_shadow: = 0
	for l in ls:
		var s: LabelSettings = l.label_settings
		if s == null or s.outline_size != 0 or l.get_theme_constant("outline_size") != 0:
			bad += 1
		elif s.shadow_size > 0 and s.shadow_color.a > 0.0 and not is_equal_approx(s.shadow_color.a, V10DS.SHADOW_A):
			bad_shadow += 1
	ok(ls.size() > 10 and bad == 0, "labels with outline or no LabelSettings: %d of %d" % [bad, ls.size()])
	ok(bad_shadow == 0, "labels with a non-standard shadow: %d" % bad_shadow)
	var sizes: = {}
	for l in [hud.status_l, hud.status_n]:
		sizes[l.label_settings.font_size] = true
	for k in hud.discs:
		sizes[22] = true
	ok(sizes.size() <= 3, "match persistent text uses %d sizes" % sizes.size())
	ok(hud.persistent_nodes().size() == 5, "match has %d persistent HUD elements (want 5)" % hud.persistent_nodes().size())
	for n in [hud, home, vic, hdr]:
		n.queue_free()


# ------------------------------------------------------------------ 3 layouts

static func _body_img() -> Image:
	if _body == null:
		var p: = "res://assets/v10/rig/mc_gown/body.png"
		if ResourceLoader.exists(p):
			_body = (load(p) as Texture2D).get_image()
			if _body.is_compressed():
				_body.decompress()
	return _body


static func _hero_area(pos: Vector2, s: float, clip: Rect2, step: = 4.0) -> float:
	# opaque body pixels (α > 0.5) of the rig's rest pose inside `clip`, in screen px²
	var img: = _body_img()
	if img == null:
		return 0.0
	var area: = 0.0
	var y: = clip.position.y
	while y < clip.end.y:
		var x: = clip.position.x
		while x < clip.end.x:
			var a: = (Vector2(x, y) - pos) / s
			if a.x >= 0 and a.y >= 0 and a.x < img.get_width() and a.y < img.get_height():
				if img.get_pixel(int(a.x), int(a.y)).a > 0.5:
					area += step * step
			x += step
		y += step
	return area


static func _inside(r: Rect2, area: Rect2) -> bool:
	return r.position.x >= area.position.x - 0.5 and r.position.y >= area.position.y - 0.5 and r.end.x <= area.end.x + 0.5 and r.end.y <= area.end.y + 0.5


static func _no_overlap(named: Dictionary, tag: String) -> void:
	var keys: = named.keys()
	for i in keys.size():
		for j in range(i + 1, keys.size()):
			var a: Rect2 = named[keys[i]]
			var b: Rect2 = named[keys[j]]
			ok(not a.intersects(b), "%s: %s overlaps %s" % [tag, keys[i], keys[j]])


static func _grid(named: Dictionary, tag: String, cx: float) -> void:
	for k in named:
		var r: Rect2 = named[k]
		var good: = fmod(r.position.x - cx, 8.0) == 0.0 and fmod(r.size.x, 8.0) == 0.0 and fmod(r.size.y, 8.0) == 0.0
		ok(good, "%s: %s off the 8-grid %s" % [tag, k, r])


static func _layouts() -> void:
	for rr in RATIOS:
		var tag: String = rr[0]
		var vs: Vector2 = rr[1]
		var ins: Dictionary = rr[2]
		var full: = Rect2(Vector2.ZERO, vs)
		var safe: = Rect2(0, float(ins.top), vs.x, vs.y - float(ins.top) - float(ins.bottom))
		var area_screen: = vs.x * vs.y
		# --- match
		var m: = V10HudMatch.compute(vs, ins)
		var help: Array = m.help
		var named: = {"pause": m.pause, "status": m.status, "board": m.board, "tray": m.tray,
				"help0": help[0], "help1": help[1], "help2": help[2]}
		for k in named:
			ok(_inside(named[k], safe), "match %s: %s outside the safe area" % [tag, k])
		_no_overlap(named, "match " + tag)
		_grid(named, "match " + tag, m.cx)
		ok(not (m.combo as Rect2).intersects(m.tray), "match %s: combo number on the tray" % tag)
		var face: Rect2 = m.hero_face
		ok(face.position.y >= (m.tray as Rect2).end.y, "match %s: face under the tray" % tag)
		for i in 3:
			ok(not face.grow(16).intersects(help[i]), "match %s: help disc %d on her face" % [tag, i])
		ok(not face.intersects(m.voice), "match %s: voice line on her face" % tag)
		ok(_inside(m.voice, safe), "match %s: voice line outside the safe area" % tag)
		var ha: = _hero_area(m.hero_pos, m.hero_scale, m.hero_view) / area_screen
		var need: = 0.28 if vs.y / vs.x >= 2.1 else (0.18 if vs.x <= 720.0 else 0.13)
		ok(ha >= need, "match %s: heroine %.1f %% of the screen (need %.0f %%)" % [tag, ha * 100.0, need * 100.0])
		print("  match %s heroine %.1f %%" % [tag, ha * 100.0])
		# --- home
		var h: = V10HudHome.compute(vs, ins)
		var hn: = {"avatar": h.avatar, "nick": h.nick, "phone": h.phone, "partner": h.partner, "play": h.play,
				"lan0": h.lanterns[0], "lan1": h.lanterns[1], "lan2": h.lanterns[2]}
		for k in hn:
			ok(_inside(hn[k], safe), "home %s: %s outside the safe area" % [tag, k])
		_no_overlap(hn, "home " + tag)
		ok(_inside(h.nav, Rect2(0, 0, vs.x, vs.y)), "home %s: navbar off screen" % tag)
		var hf: Rect2 = h.hero_face
		for k in hn:
			ok(not hf.grow(24).intersects(hn[k]), "home %s: %s on her face" % [tag, k])
		var hha: = _hero_area(h.hero_pos, h.hero_scale, Rect2(0, 0, vs.x, (h.under as Rect2).position.y + 64.0)) / area_screen
		ok(hha >= 0.35, "home %s: heroine %.1f %% (need 35 %%)" % [tag, hha * 100.0])
		# --- victory
		var v: = V10HudVictory.compute(vs, ins)
		var vn: = {"play": v.play, "home": v.home, "more": v.more}
		for k in vn:
			ok(_inside(vn[k], safe), "victory %s: %s outside the safe area" % [tag, k])
		_no_overlap(vn, "victory " + tag)
		ok(not (v.hero_clip as Rect2).intersects(v.play) and not (v.hero_clip as Rect2).intersects(v.home), "victory %s: hero ∩ buttons" % tag)
		var va: = _hero_area(v.hero_pos, v.hero_scale, Rect2(0, 0, vs.x, float(v.table_y) + 36.0)) / area_screen
		ok(va >= 0.40, "victory %s: heroine %.1f %% (need 40 %%)" % [tag, va * 100.0])
		ok(_inside(v.title, full) and _inside(v.caption, full), "victory %s: text off screen" % tag)


# ------------------------------------------------------------------ 4 showcase

static func _showcase(host: Node) -> void:
	var sc: = V10ComboShowcase.new()
	host.add_child(sc)
	await host.get_tree().process_frame
	# (a) T1 centre-zone: sample the real sprite alpha × the shader mask on a 6 px grid
	for hero in HEROES:
		var path: = sc.sprite_path(hero, "base", 1)
		ok(path != "", "showcase: no T1 sprite for %s" % hero)
		if path == "":
			continue
		var tex: Texture2D = load(path)
		var img: = tex.get_image()
		if img.is_compressed():
			img.decompress()
		var m: = sc.sprite_meta(path)
		var face: = Rect2(m.face[0], m.face[1], m.face[2], m.face[3])
		for rr in RATIOS:
			var vs: Vector2 = rr[1]
			var lay: = V10HudMatch.compute(vs, rr[2])
			var board: Rect2 = lay.board
			var pl: = V10ComboShowcase.placement(1, vs, board, (lay.tray as Rect2).position.y, tex.get_size(), face)
			var r: Rect2 = pl.rect
			var s: float = pl.scale
			var cz: = V10ComboShowcase.center_of(board)
			var worst: = 0.0
			var raw: = 0.0
			# the entrance slides in from +160 px: check the rest pose and the whole slide
			for dx in [0.0, 40.0, 80.0, 160.0]:
				var y: = cz.position.y
				while y < cz.end.y:
					var x: = cz.position.x
					while x < cz.end.x:
						var lp: = (Vector2(x, y) - r.position - Vector2(dx, 0)) / s
						if lp.x >= 0 and lp.y >= 0 and lp.x < img.get_width() and lp.y < img.get_height():
							var a: = img.get_pixel(int(lp.x), int(lp.y)).a
							raw = maxf(raw, a)
							worst = maxf(worst, a * V10ComboShowcase.mask_alpha(Vector2(x, y), board, 1))
						x += 6.0
					y += 6.0
			ok(worst <= 0.5, "showcase T1 %s %s: heroine α %.2f in the centre zone" % [hero, rr[0], worst])
			# her face is never under the board mask and stays on screen
			var fr: Rect2 = pl.face
			ok(not fr.intersects(cz), "showcase T1 %s %s: face in the centre zone" % [hero, rr[0]])
			ok(fr.end.x <= vs.x and fr.position.x >= 0.0, "showcase T1 %s %s: face off screen" % [hero, rr[0]])
		# T2 / T3: face in the upper third (§7.2) on 9:16
		for t in [2, 3]:
			var p2: = sc.sprite_path(hero, "base", t)
			var tex2: Texture2D = load(p2)
			var m2: = sc.sprite_meta(p2)
			var f2: = Rect2(m2.face[0], m2.face[1], m2.face[2], m2.face[3])
			var pl2: = V10ComboShowcase.placement(t, Vector2(720, 1280), Rect2(16, 96, 688, 688), 792.0, tex2.get_size(), f2)
			ok((pl2.face as Rect2).get_center().y <= 1280.0 / 3.0 + 40.0, "showcase T%d %s: face not in the upper third" % [t, hero])
			ok(not (pl2.face as Rect2).intersects(Rect2(24, 704, 160, 80)), "showcase T%d %s: face under the combo number" % [t, hero])
	# (b) timing and input, stepped deterministically
	sc.board_override = Rect2(16, 96, 688, 688)
	var log: = []
	sc.input_paused.connect(func(on: bool) -> void: log.append(on))
	var dt: = 1.0 / 60.0
	sc.trigger(1, 5)
	var paused_t1: = log.has(true)
	var mf_t1: = sc.mouse_filter
	var t: = 0.0
	while sc.active and t < 5.0:
		sc._advance(dt)
		t += dt
	ok(not paused_t1 and mf_t1 == Control.MOUSE_FILTER_IGNORE, "showcase T1 paused input or caught taps")
	ok(t <= 0.9 + 2.0 * dt, "showcase T1 lasted %.2f s" % t)
	for tier in [2, 3]:
		log.clear()
		sc.trigger(tier, 10 * (tier - 1))
		ok(log == [true] and sc.mouse_filter == Control.MOUSE_FILTER_STOP, "showcase T%d did not pause input" % tier)
		t = 0.0
		while sc.active and t < 5.0:
			sc._advance(dt)
			t += dt
		var lim: = 1.2 if tier == 2 else 1.4
		ok(t <= lim + 2.0 * dt, "showcase T%d lasted %.2f s (≤ %.1f)" % [tier, t, lim])
		ok(log.size() == 2 and log[1] == false, "showcase T%d did not give input back" % tier)
		# skip
		log.clear()
		sc.trigger(tier, 10)
		for i in 18:
			sc._advance(dt)
		sc.skip()
		var back_at: = 0.0 if (log.size() >= 2 and log[1] == false) else 99.0
		t = 0.0
		while sc.active and t < 2.0:
			sc._advance(dt)
			t += dt
		ok(back_at <= 0.12, "showcase T%d skip: input back after %.2f s" % [tier, back_at])
		ok(t <= 0.12 + 2.0 * dt, "showcase T%d skip: picture left after %.2f s" % [tier, t])
	# fx min: no particles
	V10Hud2Util.fx_override = "min"
	sc.trigger(3, 20)
	ok(sc._parts.is_empty(), "showcase fx=min still spawns particles")
	while sc.active:
		sc._advance(dt)
	V10Hud2Util.fx_override = ""
	# (c) rules
	sc.new_match()
	sc.min_gap = 20.0
	sc._clock = 100.0
	ok(sc.on_combo(4) == 0, "rules: ×4 showed something")
	ok(sc.on_combo(5) == 1, "rules: ×5 is not T1")
	_drain(sc)
	ok(sc.on_combo(10) == 0, "rules: the 20 s gap was ignored")
	sc._clock += 21.0
	ok(sc.on_combo(12) == 2, "rules: ×12 after the gap is not T2")
	_drain(sc)
	sc._clock += 21.0
	ok(sc.on_combo(5) == 0, "rules: T1 twice in one match")
	ok(sc.on_combo(25) == 3, "rules: ×25 is not T3")
	_drain(sc)
	sc._clock += 21.0
	ok(sc.fever_start() == 0, "rules: a 4th show in one match")
	sc.new_match()
	sc._clock += 21.0
	ok(sc.on_combo(22) == 3, "rules: a jump to ×22 must show the higher tier")
	_drain(sc)
	sc._clock += 21.0
	ok(sc.on_combo(11) == 0, "rules: lower tiers are spent after a higher one")
	sc.new_match()
	sc._clock += 21.0
	sc.ranked = true
	ok(sc.on_combo(10) == 1, "rules: ranked must play T1 only")
	ok(sc.mouse_filter == Control.MOUSE_FILTER_IGNORE, "rules: ranked paused input")
	_drain(sc)
	sc.ranked = false
	sc.new_match()
	sc._clock += 21.0
	sc.mode = "off"
	ok(sc.on_combo(10) == 0, "rules: «Выкл» still shows")
	sc.mode = "full"
	sc.hold()
	ok(sc.on_combo(10) == 2 and not sc.active, "rules: hold() did not defer behind the cut-in")
	sc.release()
	ok(sc.active and sc.tier == 2, "rules: release() did not play the deferred show")
	_drain(sc)
	sc.queue_free()


static func _drain(sc: V10ComboShowcase) -> void:
	var n: = 0
	while sc.active and n < 600:
		sc._advance(1.0 / 60.0)
		n += 1


# ------------------------------------------------------------------ 5 code

static func _code() -> void:
	var dir: = "res://scripts/v10/hud2/"
	var bad: = []
	for f in DirAccess.get_files_at(dir):
		if not f.ends_with(".gd") or f == "tokens.gd" or f == "hud2_selftest.gd":
			continue
		var src: = FileAccess.get_file_as_string(dir + f)
		var re: = RegEx.create_from_string("Color\\(\"#|Color\\(0\\.")
		if re.search(src):
			bad.append(f)
	ok(bad.is_empty(), "colour literals outside tokens.gd: %s" % [bad])
