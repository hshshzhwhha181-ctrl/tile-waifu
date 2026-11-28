class_name TWWidgetsSelftest
extends RefCounted

# P28 / WP9b selftest of the v11 widgets (TWButton, TWPlate, TWSheet, TWHeader, TWTabBar, TWToast, TWCurrencyChip, TWSkin, TWDraw).
#   godot --headless --path game res://shell/design/widgets_selftest.tscn      ->  prints "TWWIDGETS_SELFTEST ok/total"
# Section 0 CARRIES OVER the whole hud2 suite (854 checks: plates, type rules, match/home/victory layouts on 7 ratios, combo showcase, code lint).
# V10Plate / V10Button are now shims over TWPlate / TWButton, so those 854 checks now exercise the new widgets through the HUD screens.
# Sections 1..11 are new: plates on TWPlate, type scale, button feel (per-tick press curve, p95 tap response), skins, three resolutions
# (720x1280, 720x1600, 1536x2048), sheet / toast / tab bar / chip behaviour, shim parity, code lint of the widget files.

const RES: = [
	["720x1280", Vector2(720, 1280), {"top": 0, "bottom": 0}],
	["720x1600", Vector2(720, 1600), {"top": 48, "bottom": 24}],
	["1536x2048", Vector2(1536, 2048), {"top": 24, "bottom": 16}],
]
const DT: = 1.0 / 60.0

var checks: = 0
var fails: = 0
var _host: Node


func ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("TWWIDGETS FAIL: ", what)


func run(host: Node) -> Array:
	_host = host
	V10Hud2Util.fx_override = "full"
	await _carried_hud2()
	await _plates()
	await _type()
	_buttons()
	_skins()
	await _resolutions()
	_sheet()
	_toast()
	_chip()
	_tabbar()
	_shims()
	_code()
	V10Hud2Util.fx_override = ""
	TWDraw.sim_insets = {}
	TWSkin.reset()
	var total: = checks
	print("TWWIDGETS_SELFTEST %d/%d %s" % [total - fails, total, "OK" if fails == 0 else "FAILED"])
	return [total - fails, total]


# ------------------------------------------------------------------ 0 carried hud2 suite

func _carried_hud2() -> void:
	V10Hud2Util.fx_override = ""
	V10Hud2Util.sim_insets = {}
	var f: int = await V10Hud2Selftest.run(_host)
	V10Hud2Util.fx_override = "full"
	checks += V10Hud2Selftest.checks
	fails += f
	ok(V10Hud2Selftest.checks >= 854, "carried hud2 checks: %d (want >= 854)" % V10Hud2Selftest.checks)


# ------------------------------------------------------------------ 1 plates

func _rand_text(rng: RandomNumberGenerator) -> String:
	var words: = ["Подарок", "дня", "Наряд", "«Шёлковый вечер»", "навсегда", "без", "случайности", "Лунного", "камня",
			"Симпатия", "Путь", "1 000", "= 6 желаний", "Маджонг-тян", "Чайный сад", "Ставка ×2", "Ещё", "уровень",
			"Сверхдлиннаяиндустриализированнаястрокабезпробелов", "₽", "№", "—", "WWWWWWWW", "ёЁйЙ", "ыыы", "Ш"]
	var n: = rng.randi_range(0, 14)
	var out: = []
	for i in n:
		out.append(words[rng.randi_range(0, words.size() - 1)])
	return " ".join(out)


func _plates() -> void:
	var rng: = RandomNumberGenerator.new()
	rng.seed = 20261124
	var box: = VBoxContainer.new()
	box.size = Vector2(720, 4000)
	_host.add_child(box)
	var plates: = []
	for i in 200:
		var sc: String = ["S", "M", "L"][i % 3]
		var widths: Array = TWPlate.WIDTHS[sc]
		var w: int = widths[rng.randi_range(0, widths.size() - 1)]
		var p: = TWPlate.make(sc, w, _rand_text(rng), _rand_text(rng) if sc != "S" else "", str(rng.randi_range(0, 99999)) if rng.randf() < 0.5 else "", "heart" if rng.randf() < 0.5 else "")
		p.size_flags_vertical = Control.SIZE_EXPAND_FILL
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		p.custom_minimum_size = Vector2(0, 0)
		box.add_child(p)
		plates.append(p)
	for i in 3:
		await _host.get_tree().process_frame
	box.size = Vector2(900, 60000)
	for i in 3:
		await _host.get_tree().process_frame
	var bad_h: = 0
	var bad_w: = 0
	var bad_lbl: = 0
	var bad_sub: = 0
	for p in plates:
		var h: = TWPlate.height_of(p.size_class)
		if absf(p.size.y - h) > 0.01:
			bad_h += 1
		if not (int(p.size.x) in TWPlate.WIDTHS[p.size_class]):
			bad_w += 1
		for c in p.get_children():
			if c is Label and c.visible:
				var r: = Rect2(c.position, c.size)
				if r.position.y < -0.5 or r.end.y > h + 0.5 or r.end.x > p.size.x + 0.5:
					bad_lbl += 1
		# title + subtitle must not overlap vertically on M / L
		var tl: Label = p._title_l
		var sl: Label = p._sub_l
		if sl.visible and Rect2(tl.position, tl.size).intersects(Rect2(sl.position, sl.size)):
			bad_sub += 1
			if bad_sub == 1:
				print("  first overlap: ", p.size_class, " w ", p.plate_w, " title ", tl.position, tl.size, " sub ", sl.position, sl.size, " val ", p.value, " icon ", p.icon)
	ok(bad_h == 0, "TWPlate: %d of 200 changed height" % bad_h)
	ok(bad_w == 0, "TWPlate: %d of 200 left the width modules" % bad_w)
	ok(bad_lbl == 0, "TWPlate: %d labels outside their plate" % bad_lbl)
	ok(bad_sub == 0, "TWPlate: %d plates with title/subtitle overlapping" % bad_sub)
	box.queue_free()
	# real HUD strings fit without ellipsis
	TWDraw.overflow.clear()
	var real: = [["S", 192, "Ставка ×2"], ["S", 288, "Лунный камень"], ["M", 328, "Маджонг-тян"], ["M", 672, "Подарок дня"],
			["M", 672, "300 Лунного камня"], ["L", 672, "Наряд «Шёлковый вечер»"], ["M", 672, "Симпатия"]]
	for r in real:
		var p2: = TWPlate.make(r[0], r[1], r[2], "", "", "")
		_host.add_child(p2)
		p2.queue_free()
	ok(TWDraw.overflow.is_empty(), "TWPlate HUD strings overflow: %s" % [TWDraw.overflow])
	TWDraw.overflow.clear()
	# a plate is tappable on a 96 px band even when 48 tall
	var s: = TWPlate.make("S", 144, "x")
	s.interactive = true
	_host.add_child(s)
	ok(s._has_point(Vector2(10, -23)) and s._has_point(Vector2(10, 48 + 23)) and not s._has_point(Vector2(10, -30)), "TWPlate S: 96 px hit band")
	# plate tap: pressed once on release inside, never on a release far outside, never when disabled
	var got: = [0]
	s.pressed.connect(func() -> void: got[0] += 1)
	_tap(s, Vector2(20, 24))
	ok(got[0] == 1, "TWPlate tap emitted %d" % got[0])
	_tap(s, Vector2(20, 24), Vector2(400, 400))
	ok(got[0] == 1, "TWPlate release far outside must not fire")
	s.disabled = true
	_tap(s, Vector2(20, 24))
	ok(got[0] == 1, "TWPlate disabled must not fire")
	s.queue_free()


# ------------------------------------------------------------------ 2 type scale

func _labels(n: Node, out: Array) -> void:
	if n is Label:
		out.append(n)
	for c in n.get_children():
		_labels(c, out)


func _type() -> void:
	var gallery: = Control.new()
	gallery.size = Vector2(720, 1280)
	_host.add_child(gallery)
	TWDraw.sim_insets = {"top": 48, "bottom": 24}
	var widgets: Array = []
	widgets.append(TWPlate.make("S", 192, "Ставка ×2", "", "", ""))
	widgets.append(TWPlate.make("M", 672, "Подарок дня", "Загляни завтра", "120"))
	widgets.append(TWPlate.make("L", 672, "Наряд «Шёлковый вечер»", "Описание наряда в две строки для карточки", "999"))
	for k in TWButton.KINDS:
		var b: = TWButton.make(k, "Играть", Vector2(560, 104))
		b.overline = "Сегодня"
		widgets.append(b)
	widgets.append(TWCurrencyChip.create("moon", 1980))
	var hdr: = TWHeader.make(gallery, "Очень длинный заголовок подэкрана с переполнением", func() -> void: pass, func() -> void: pass)
	hdr.viewport_override = Vector2(720, 1280)
	hdr._layout()
	widgets.append(hdr)
	var tb: = TWTabBar.make([{"id": "a", "icon": "tab_tea", "label": "Чайная"}, {"id": "b", "icon": "tab_heroines", "label": "Героини"},
			{"id": "c", "icon": "tab_tables", "label": "Столы"}, {"id": "d", "icon": "tab_wishes", "label": "Желания"}, {"id": "e", "icon": "tab_shop", "label": "Лавка"}])
	gallery.add_child(tb)
	widgets.append(tb)
	var sh: = TWSheet.make("Подарок дня", 300.0)
	gallery.add_child(sh)
	widgets.append(sh)
	var ts: = TWToast.new()
	gallery.add_child(ts)
	ts.show_toast("Награда получена и добавлена в сумку героини")
	widgets.append(ts)
	for w in widgets:
		if w != hdr and w != tb and w != sh and w != ts:
			gallery.add_child(w)
	await _host.get_tree().process_frame
	var ls: = []
	for w in widgets:
		_labels(w, ls)
	var scale: Array = TWTokens.TYPE_SIZES.duplicate()
	scale.append(TWTokens.TYPE_SUBTITLE)
	var bad_size: = 0
	var bad_outline: = 0
	var bad_shadow: = 0
	var seen: = {}
	for l in ls:
		var st: LabelSettings = l.label_settings
		if st == null or st.outline_size != 0 or l.get_theme_constant("outline_size") != 0:
			bad_outline += 1
			continue
		seen[st.font_size] = true
		if not (st.font_size in scale):
			bad_size += 1
		if st.shadow_size > 0 and st.shadow_color.a > 0.0 and not is_equal_approx(st.shadow_color.a, TWTokens.SHADOW_A):
			bad_shadow += 1
	ok(ls.size() > 20, "type gallery has %d labels" % ls.size())
	ok(bad_outline == 0, "TW labels with outline or no LabelSettings: %d of %d" % [bad_outline, ls.size()])
	ok(bad_size == 0, "TW labels outside the closed type scale 64/44/34/30/26(+36): %d of %d, sizes %s" % [bad_size, ls.size(), seen.keys()])
	ok(bad_shadow == 0, "TW labels with a non-standard shadow: %d" % bad_shadow)
	ok(seen.size() <= 5, "gallery uses %d distinct sizes (max 5 in the scale)" % seen.size())
	var stray: = []
	for o in TWDraw.overflow:   # only the two deliberately long strings may ellipsize
		if not (str(o.text).begins_with("Очень длинный") or str(o.text).begins_with("Награда получена и добавлена")):
			stray.append(o)
	ok(stray.is_empty(), "gallery strings that overflow unexpectedly: %s" % [stray])
	TWDraw.overflow.clear()
	TWDraw.sim_insets = {}
	gallery.queue_free()


# ------------------------------------------------------------------ 3 buttons

func _ev(pressed: bool, pos: Vector2) -> InputEventMouseButton:
	var e: = InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = pos
	return e


func _tap(c: Control, at: Vector2, release_at: Vector2 = Vector2(-1e9, -1e9)) -> void:
	c._gui_input(_ev(true, at))
	c._gui_input(_ev(false, at if release_at.x < -1e8 else release_at))


func _buttons() -> void:
	var host_c: = Control.new()
	_host.add_child(host_c)
	for k in TWButton.KINDS:
		var sz: = Vector2(560, 104) if k != "quiet" else Vector2(96, 96)
		var b: = TWButton.make(k, "Играть", sz)
		host_c.add_child(b)
		ok(b.hit_rect().size.x >= float(TWTokens.HIT_TARGET_MIN) and b.hit_rect().size.y >= float(TWTokens.HIT_TARGET_MIN), "TWButton %s hit rect %s < 96" % [k, b.hit_rect().size])
		var small: = TWButton.make(k, "ОК", Vector2(60, 60))
		host_c.add_child(small)
		ok(small.hit_rect().size == Vector2(96, 96), "TWButton %s 60x60 hit pad -> %s" % [k, small.hit_rect().size])
		ok(small._has_point(Vector2(-17, -17)) and not small._has_point(Vector2(-19, 30)), "TWButton %s hit test pad" % k)
		small.big = true
		ok(small.hit_rect().size == Vector2(112, 112), "TWButton %s big hit %s" % [k, small.hit_rect().size])
		b.queue_free()
		small.queue_free()
	# --- press curve, per tick at 60 Hz and 30 Hz
	for dt in [DT, 1.0 / 30.0, 1.0 / 120.0]:
		var b: = TWButton.make("play", "Играть", Vector2(560, 104))
		host_c.add_child(b)
		b.set_process(false)
		b._gui_input(_ev(true, Vector2(100, 50)))
		var t: = 0.0
		var prev: = 1.0
		var mono: = true
		var t_reach: = -1.0
		var n: = 0
		while t < 0.5 and n < 400:
			b.advance(dt)
			t += dt
			n += 1
			var s: = b.scale.x
			if s > prev + 1e-6:
				mono = false
			prev = s
			if t_reach < 0.0 and s <= TWButton.S_DOWN + 1e-4:
				t_reach = t
		ok(mono, "TWButton down is monotonic (dt %.4f)" % dt)
		ok(t_reach > 0.0 and t_reach <= TWButton.T_DOWN + dt + 1e-6, "TWButton down reached 0.94 at %.3f s (budget 0.090 + tick)" % t_reach)
		ok(is_equal_approx(b.scale.x, TWButton.S_DOWN), "TWButton holds 0.94 while pressed: %.4f" % b.scale.x)
		b._gui_input(_ev(false, Vector2(100, 50)))
		t = 0.0
		var peak: = 0.0
		var done_at: = -1.0
		n = 0
		while t < 0.6 and n < 400:
			b.advance(dt)
			t += dt
			n += 1
			peak = maxf(peak, b.scale.x)
			if done_at < 0.0 and b.anim_phase() == 0:
				done_at = t
		ok(done_at > 0.0 and done_at <= TWButton.T_UP + dt + 1e-6, "TWButton up finished at %.3f s (budget 0.160 + tick)" % done_at)
		ok(is_equal_approx(b.scale.x, 1.0), "TWButton ends at exactly 1.0: %.5f" % b.scale.x)
		ok(peak <= 1.03 and peak >= 1.0, "TWButton spring overshoot %.4f (<= 1.03)" % peak)
		b.queue_free()
	ok(is_equal_approx(TWButton.down_scale(0.0), 1.0) and is_equal_approx(TWButton.down_scale(TWButton.T_DOWN), 0.94), "TWButton.down_scale endpoints")
	ok(is_equal_approx(TWButton.up_scale(0.94, 0.0), 0.94) and is_equal_approx(TWButton.up_scale(0.94, TWButton.T_UP), 1.0), "TWButton.up_scale endpoints")
	# --- response < 100 ms, p95 over 200 taps (wall clock inside the handler)
	var b2: = TWButton.make("play", "Играть", Vector2(560, 104))
	host_c.add_child(b2)
	var react: Array = []
	for i in 200:
		b2._gui_input(_ev(true, Vector2(100, 50)))
		react.append(b2.reaction_ms())
		ok(b2.visual_down(), "TWButton tap %d: no visual reaction" if false else "TWButton tap: visual state set in the event")
		b2._gui_input(_ev(false, Vector2(100, 50)))
		for k in 12:
			b2.advance(DT)
	react.sort()
	var p95: float = react[int(react.size() * 0.95)]
	ok(p95 < 100.0, "TWButton tap reaction p95 %.3f ms (budget 100)" % p95)
	ok(react[0] >= 0.0, "TWButton reaction measured")
	print("  TWButton reaction p95 %.3f ms over %d taps" % [p95, react.size()])
	b2.queue_free()
	# --- signals
	var b3: = TWButton.make("secondary", "Далее", Vector2(560, 96))
	host_c.add_child(b3)
	var cnt: = [0, 0]
	b3.pressed.connect(func() -> void: cnt[0] += 1)
	b3.denied.connect(func() -> void: cnt[1] += 1)
	_tap(b3, Vector2(50, 40))
	ok(cnt[0] == 1 and cnt[1] == 0, "TWButton tap -> pressed %d denied %d" % [cnt[0], cnt[1]])
	_tap(b3, Vector2(50, 40), Vector2(900, 900))
	ok(cnt[0] == 1, "TWButton release far away must not fire")
	b3.disabled = true
	_tap(b3, Vector2(50, 40))
	ok(cnt[0] == 1 and cnt[1] == 1, "TWButton disabled -> denied only (pressed %d denied %d)" % [cnt[0], cnt[1]])
	b3.queue_free()
	var rb: = TWButton.make("play", "ЭТОТ ТЕКСТ ОЧЕНЬ ДЛИННЫЙ ДЛЯ КНОПКИ ИГРАТЬ", Vector2(300, 104))
	host_c.add_child(rb)
	ok(rb._l.size.x <= 300.0 - 64.0 + 0.01 and rb._l.label_settings.font_size in [TWTokens.TYPE_H2, TWTokens.TYPE_BODY, TWTokens.TYPE_CAPTION], "TWButton long text stays in its box on the closed scale")
	rb.queue_free()
	TWDraw.overflow.clear()
	host_c.queue_free()


# ------------------------------------------------------------------ 4 skins

func _skins() -> void:
	var base: = TWSkin.c("PLATE_RIM")
	ok(base == TWTokens.PLATE_RIM, "TWSkin.c returns the TWTokens value without a skin")
	ok(TWSkin.has_token("ROSE_500") and not TWSkin.has_token("NOPE") and not TWSkin.has_token("TYPE_BODY"), "TWSkin.has_token is colours only")
	var p: = TWPlate.make("M", 328, "x")
	_host.add_child(p)
	var rev: = TWSkin.revision
	var n: = TWSkin.apply("test", {"PLATE_RIM": Color.RED, "NOPE": Color.GREEN, "ROSE_500": "not a colour"})
	ok(n == 1 and TWSkin.rejected == 2, "TWSkin.apply accepted %d rejected %d (want 1 / 2)" % [n, TWSkin.rejected])
	ok(TWSkin.c("PLATE_RIM") == Color.RED and TWSkin.current == "test", "TWSkin override visible")
	ok(TWSkin.c("GOLD_500") == TWTokens.GOLD_500, "TWSkin leaves the other tokens alone")
	ok(TWSkin.revision == rev + 1, "TWSkin revision bumped")
	# a skinned widget actually draws with the override: render the plate into an Image and look at the rim pixel
	var img: = await _render(p, Vector2i(328, 80))
	var rim: = img.get_pixel(160, 1)
	var rim2: = img.get_pixel(160, 40)
	ok(rim.r > rim.g + 0.2 and rim.r > rim.b + 0.2, "skinned plate rim is red-ish: %s" % rim)
	ok(not (rim2.r > rim2.g + 0.2 and rim2.r > rim2.b + 0.2), "plate body unaffected by the rim override: %s" % rim2)
	TWSkin.reset()
	var img2: = await _render(p, Vector2i(328, 80))
	var rim3: = img2.get_pixel(160, 1)
	ok(not (rim3.r > rim3.g + 0.2 and rim3.r > rim3.b + 0.2), "reset restores the base rim: %s" % rim3)
	ok(TWSkin.c("PLATE_RIM") == TWTokens.PLATE_RIM and TWSkin.current == "" and TWSkin.overrides().is_empty(), "TWSkin.reset")
	# two skins in a row replace each other (no accumulation)
	TWSkin.apply("a", {"ROSE_500": Color.BLUE})
	TWSkin.apply("b", {"GOLD_500": Color.GREEN})
	ok(TWSkin.c("ROSE_500") == TWTokens.ROSE_500 and TWSkin.c("GOLD_500") == Color.GREEN, "TWSkin.apply replaces the previous skin")
	TWSkin.reset()
	p.queue_free()


func _render(c: Control, sz: Vector2i) -> Image:
	var vp: = SubViewport.new()
	vp.size = sz
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	_host.add_child(vp)
	var par: = c.get_parent()
	par.remove_child(c)
	vp.add_child(c)
	c.position = Vector2.ZERO
	await RenderingServer.frame_post_draw
	await _host.get_tree().process_frame
	var img: = vp.get_texture().get_image()
	vp.remove_child(c)
	par.add_child(c)
	vp.queue_free()
	return img


# ------------------------------------------------------------------ 5 three resolutions

func _inside(r: Rect2, area: Rect2) -> bool:
	return r.position.x >= area.position.x - 0.5 and r.position.y >= area.position.y - 0.5 and r.end.x <= area.end.x + 0.5 and r.end.y <= area.end.y + 0.5


func _resolutions() -> void:
	for rr in RES:
		var tag: String = rr[0]
		var vs: Vector2 = rr[1]
		var ins: Dictionary = rr[2]
		var safe: = Rect2(0, float(ins.top), vs.x, vs.y - float(ins.top) - float(ins.bottom))
		var full: = Rect2(Vector2.ZERO, vs)
		TWDraw.sim_insets = ins
		# --- header
		for variant in ["both", "back", "plate"]:
			var g: = TWHeader.compute(vs, ins, variant != "plate", variant == "both", 144 if variant == "plate" else 0)
			ok(absf((g.bar as Rect2).size.y - (float(ins.top) + TWHeader.HEIGHT)) < 0.5, "header %s %s: bar height" % [tag, variant])
			var parts: Dictionary = {}
			if variant != "plate":
				parts["back"] = g.back
			if variant == "both":
				parts["help"] = g.help
			if variant == "plate":
				parts["plate"] = g.plate
			var title: = Rect2(g.title_x, float(ins.top), maxf(0.0, float(g.title_right) - float(g.title_x)), TWHeader.HEIGHT)
			parts["title"] = title
			for k in parts:
				ok(_inside(parts[k], safe), "header %s %s: %s outside the safe area" % [tag, variant, k])
			var keys: = parts.keys()
			for i in keys.size():
				for j in range(i + 1, keys.size()):
					ok(not (parts[keys[i]] as Rect2).intersects(parts[keys[j]]), "header %s %s: %s overlaps %s" % [tag, variant, keys[i], keys[j]])
			for k in ["back", "help"]:
				if parts.has(k):
					ok((parts[k] as Rect2).size.x >= 96.0 and (parts[k] as Rect2).size.y >= 96.0, "header %s: %s hit < 96" % [tag, k])
			ok(title.size.x >= 200.0, "header %s %s: title column only %.0f px" % [tag, variant, title.size.x])
		# the live header agrees with compute()
		var scr: = Control.new()
		scr.size = vs
		_host.add_child(scr)
		var h: = TWHeader.make(scr, "Режимы", func() -> void: pass, func() -> void: pass)
		h.viewport_override = vs
		h._layout()
		var g2: = TWHeader.compute(vs, ins, true, true)
		ok(h.back_btn.position.is_equal_approx((g2.back as Rect2).position) and h.help_btn.position.is_equal_approx((g2.help as Rect2).position), "header %s: live layout == compute" % tag)
		ok(h.title_lbl.position.x + h.title_lbl.size.x <= h.help_btn.position.x + 0.5, "header %s: title runs under «?»" % tag)
		ok(absf(h.size.y - (float(ins.top) + TWHeader.HEIGHT)) < 0.5, "header %s: live height %.0f" % [tag, h.size.y])
		ok(TWHeader.content_y(vs, ins) >= float(ins.top) + TWHeader.HEIGHT, "header %s: content_y" % tag)
		scr.queue_free()
		# --- tab bar, 3..6 tabs
		for n in [3, 4, 5, 6]:
			var gt: = TWTabBar.compute(vs, ins, n)
			var items: Array = gt.items
			var bar: Rect2 = gt.bar
			ok(_inside(bar, full) and absf(bar.end.y - vs.y) < 0.5, "tabbar %s n=%d: bar on screen / flush with the bottom" % [tag, n])
			var all_ok: = true
			for i in n:
				var r: Rect2 = items[i]
				if not _inside(r, safe) or r.size.x < 96.0 or r.size.y < 96.0:
					all_ok = false
				if i > 0 and (items[i - 1] as Rect2).end.x > r.position.x + 0.5:
					all_ok = false
			ok(all_ok, "tabbar %s n=%d: items inside the safe area, >= 96, no overlap" % [tag, n])
			ok(float((items[n - 1] as Rect2).end.x) <= float(gt.cx) + float(gt.cw) + 0.5, "tabbar %s n=%d: last item inside the column" % [tag, n])
		var tb: = TWTabBar.make([{"id": "a", "icon": "tab_tea", "label": "Чайная"}, {"id": "b", "icon": "tab_heroines", "label": "Героини"},
				{"id": "c", "icon": "tab_tables", "label": "Столы"}, {"id": "d", "icon": "tab_wishes", "label": "Желания"}, {"id": "e", "icon": "tab_shop", "label": "Лавка"}])
		tb.viewport_override = vs
		_host.add_child(tb)
		tb._layout()
		var tbad: = 0
		for l in tb._labels:
			var lr: = Rect2(l.position + tb.position, l.size)
			if not _inside(lr, safe):
				tbad += 1
		ok(tbad == 0, "tabbar %s: %d labels outside the safe area" % [tag, tbad])
		ok(tb.position.is_equal_approx((TWTabBar.compute(vs, ins, 5).bar as Rect2).position), "tabbar %s: live position == compute" % tag)
		tb.queue_free()
		# --- sheet
		for ch in [80.0, 400.0, 3000.0]:
			var gs: = TWSheet.compute(vs, ins, ch)
			var pnl: Rect2 = gs.panel
			ok(_inside(pnl, full) and absf(pnl.end.y - vs.y) < 0.5, "sheet %s ch=%.0f: panel on screen, flush with the bottom" % [tag, ch])
			ok(pnl.position.y >= float(ins.top) + 96.0 - 0.5, "sheet %s ch=%.0f: leaves a strip above (top %.0f)" % [tag, ch, pnl.position.y])
			ok(_inside(gs.body, pnl) and (gs.body as Rect2).end.y <= vs.y - float(ins.bottom) + 0.5, "sheet %s ch=%.0f: body inside the panel and above the bottom inset" % [tag, ch])
			ok(_inside(gs.close, pnl) and (gs.close as Rect2).size.x >= 96.0 and (gs.close as Rect2).size.y >= 96.0, "sheet %s ch=%.0f: close button >= 96 inside the panel" % [tag, ch])
			ok(not (gs.close as Rect2).intersects(gs.title), "sheet %s ch=%.0f: close overlaps the title" % [tag, ch])
			ok(_inside(gs.title, pnl) and _inside(gs.handle, pnl), "sheet %s ch=%.0f: title/handle inside" % [tag, ch])
			ok(pnl.size.x <= 720.0 + 0.5 and pnl.size.x <= vs.x, "sheet %s: panel width %.0f" % [tag, pnl.size.x])
		var sh: = TWSheet.make("Подарок дня", 400.0)
		sh.viewport_override = vs
		_host.add_child(sh)
		sh.open(vs)
		for i in 30:
			sh.advance(DT)
		var live: = Rect2(sh.position, sh.size)
		ok(live.is_equal_approx(TWSheet.compute(vs, ins, 400.0).panel), "sheet %s: open pose == compute" % tag)
		ok(_inside(Rect2(sh.body.global_position, sh.body.size), safe), "sheet %s: live body inside the safe area" % tag)
		sh.queue_free()
		# --- toast
		var tr: = TWToast.compute(vs, ins)
		ok(_inside(tr, safe) and tr.size.x <= vs.x - 48.0 + 0.5 and tr.size.x <= 672.0, "toast %s: inside the safe area, width %.0f" % [tag, tr.size.x])
		# --- chip + plates widths
		for amt in [0, 999, 1980, 123456, 99999999]:
			var chip: = TWCurrencyChip.create("moon", amt)
			chip.size = Vector2(chip.plate_w, 48)
			ok(chip.plate_w in TWPlate.WIDTHS["S"] and float(chip.plate_w) <= vs.x - 48.0, "chip %s amt=%d: width %d" % [tag, amt, chip.plate_w])
			var val: Label = chip._val_l
			ok(val.position.x >= float(TWPlate.PAD["S"]) + TWCurrencyChip.GLYPH_W - 0.5 and val.position.x + val.size.x <= chip.plate_w - float(TWPlate.PAD["S"]) + 2.5, "chip %s amt=%d: number between glyph and edge (%.0f..%.0f of %d)" % [tag, amt, val.position.x, val.position.x + val.size.x, chip.plate_w])
			chip.free()
		TWDraw.sim_insets = {}
		await _host.get_tree().process_frame


# ------------------------------------------------------------------ 6 sheet behaviour

func _sheet() -> void:
	var vs: = Vector2(720, 1280)
	TWDraw.sim_insets = {"top": 0, "bottom": 0}
	var sh: = TWSheet.make("Тест", 400.0)
	sh.viewport_override = vs
	_host.add_child(sh)
	var ev: = [0, 0]
	sh.opened.connect(func() -> void: ev[0] += 1)
	sh.closed.connect(func() -> void: ev[1] += 1)
	ok(sh.state == TWSheet.State.HIDDEN and not sh.visible, "sheet starts hidden")
	sh.set_process(false)
	sh.open(vs)
	var ph: float = (TWSheet.compute(vs, {"top": 0, "bottom": 0}, 400.0).panel as Rect2).size.y
	ok(sh.state == TWSheet.State.OPENING and sh.visible and absf(sh.position.y - vs.y) < 0.5, "sheet opens from below the screen: y %.1f" % sh.position.y)
	var prev: = sh.position.y
	var mono: = true
	var t: = 0.0
	var steps: = 0
	while sh.state == TWSheet.State.OPENING and steps < 100:
		sh.advance(DT)
		t += DT
		steps += 1
		if sh.position.y > prev + 1e-4:
			mono = false
		prev = sh.position.y
	ok(mono, "sheet open is monotonic")
	ok(t <= TWSheet.T_OPEN + DT + 1e-6 and t >= TWSheet.T_OPEN - DT - 1e-6, "sheet open took %.3f s (want 0.24)" % t)
	ok(sh.state == TWSheet.State.OPEN and ev[0] == 1 and absf(sh.position.y - (vs.y - ph)) < 0.5, "sheet open pose, opened emitted %d" % ev[0])
	# QUINT OUT: it covers most of the distance early (>= 80 % in the first 40 % of the time)
	ok(TWSheet.ease_quint_out(0.4) >= 0.92 and TWSheet.ease_quint_out(0.0) == 0.0 and TWSheet.ease_quint_out(1.0) == 1.0, "ease_quint_out shape")
	sh.close()
	sh.close()
	t = 0.0
	steps = 0
	while sh.state == TWSheet.State.CLOSING and steps < 100:
		sh.advance(DT)
		t += DT
		steps += 1
	ok(t <= TWSheet.T_CLOSE + DT + 1e-6 and t >= TWSheet.T_CLOSE - DT - 1e-6, "sheet close took %.3f s (want 0.18)" % t)
	ok(sh.state == TWSheet.State.HIDDEN and not sh.visible and ev[1] == 1, "sheet hidden after close, closed emitted exactly once (%d)" % ev[1])
	sh.close()
	ok(ev[1] == 1, "close() on a hidden sheet is a no-op")
	# close button closes
	sh.open(vs)
	for i in 30:
		sh.advance(DT)
	sh._close_btn.pressed.emit()
	for i in 30:
		sh.advance(DT)
	ok(sh.state == TWSheet.State.HIDDEN and ev[1] == 2, "close button closes the sheet")
	sh.closable = false
	sh.open(vs)
	ok(not sh._close_btn.visible, "non-closable sheet hides the close button")
	sh.queue_free()
	TWDraw.sim_insets = {}


# ------------------------------------------------------------------ 7 toast

func _toast() -> void:
	TWDraw.sim_insets = {"top": 48, "bottom": 24}
	var t: = TWToast.new()
	t.viewport_override = Vector2(720, 1600)
	_host.add_child(t)
	t.set_process(false)
	var ev: = [0, 0]
	t.toast_shown.connect(func(_s: String) -> void: ev[0] += 1)
	t.toast_gone.connect(func(_s: String) -> void: ev[1] += 1)
	ok(not t.visible and t.mouse_filter == Control.MOUSE_FILTER_IGNORE and not t.is_showing(), "toast idle: invisible, ignores the mouse")
	ok(t.show_toast("Первое", "ok", 1.0), "toast accepted")
	ok(t.visible and t.mouse_filter == Control.MOUSE_FILTER_STOP and t.phase == TWToast.Phase.IN, "toast showing: visible, in phase")
	ok(not t.show_toast("Первое"), "duplicate of the shown toast is ignored")
	ok(t.show_toast("Второе") and not t.show_toast("Второе"), "duplicate of a queued toast is ignored")
	ok(t.show_toast("Третье") and t.show_toast("Четвёртое"), "queue accepts 3 waiting")
	ok(t.show_toast("Пятое") and t.queue.size() == 3 and t.queue[0].text == "Третье", "a 4th waiting toast drops the oldest waiting one")
	# timing of the first: IN 0.24 + hold 1.0 + OUT 0.16
	var tt: = 0.0
	var phases: = []
	var shown_first: = true
	while ev[1] < 1 and tt < 5.0:
		t.advance(DT)
		tt += DT
		if phases.is_empty() or phases[-1] != t.phase:
			phases.append(t.phase)
	var want: = TWTokens.T_IN + 1.0 + TWTokens.T_OUT
	ok(absf(tt - want) <= 2.0 * DT, "toast lifetime %.3f s (want %.3f)" % [tt, want])
	ok(phases.size() >= 3 and phases.slice(0, 3) == [TWToast.Phase.IN, TWToast.Phase.HOLD, TWToast.Phase.OUT], "toast phases in order IN -> HOLD -> OUT: %s" % [phases])
	ok(ev[0] == 2 and t.current.text == "Третье", "next toast starts after the first is gone (shown %d)" % ev[0])
	var r: = TWToast.compute(Vector2(720, 1600), {"top": 48, "bottom": 24})
	for i in 40:
		t.advance(DT)
	ok(absf(t.position.y - r.position.y) < 0.5 and t.size.is_equal_approx(r.size), "toast rests on the compute() rect")
	ok(absf(t.modulate.a - 1.0) < 0.01, "toast fully opaque while held")
	# tap dismisses
	var before: int = ev[1]
	t._gui_input(_ev(true, Vector2(10, 10)))
	ok(t.phase == TWToast.Phase.OUT, "tap dismisses the toast")
	for i in 20:
		t.advance(DT)
	ok(ev[1] == before + 1, "dismissed toast reported gone once")
	while t.is_showing() and tt < 60.0:
		t.advance(DT)
		tt += DT
	ok(not t.is_showing() and not t.visible and t.mouse_filter == Control.MOUSE_FILTER_IGNORE and ev[1] == ev[0], "queue drained: toast idle again (shown %d gone %d)" % [ev[0], ev[1]])
	t.queue_free()
	TWDraw.sim_insets = {}


# ------------------------------------------------------------------ 8 currency chip

func _chip() -> void:
	ok(TWCurrencyChip.format_amount(0) == "0" and TWCurrencyChip.format_amount(999) == "999" and TWCurrencyChip.format_amount(1980) == "1 980"
			and TWCurrencyChip.format_amount(1234567) == "1 234 567" and TWCurrencyChip.format_amount(-4500) == "-4 500", "chip number format")
	var c: = TWCurrencyChip.create("coin", 1980)
	_host.add_child(c)
	c.set_process(false)
	ok(c.size_class == "S" and c.interactive and c.value == "1 980" and c.amount == 1980, "chip initial state")
	ok(c.plate_w in TWPlate.WIDTHS["S"], "chip width is an S module: %d" % c.plate_w)
	var w_small: = c.plate_w
	c.set_amount(12345678, true)
	ok(c.is_rolling(), "chip rolls to a new value")
	var t: = 0.0
	var mono: = true
	var last: = 1980
	while c.is_rolling() and t < 2.0:
		c.advance(DT)
		t += DT
		var shown: = int(c.value.replace(" ", ""))
		if shown < last:
			mono = false
		last = shown
	ok(mono, "chip number rolls monotonically")
	ok(t <= TWTokens.T_ROLL + DT + 1e-6 and t >= TWTokens.T_ROLL - DT - 1e-6, "chip roll took %.3f s (want 0.32)" % t)
	ok(c.value == "12 345 678" and c.amount == 12345678, "chip ends on the exact value: %s" % c.value)
	ok(c.plate_w >= w_small and c.plate_w in TWPlate.WIDTHS["S"], "chip widens to fit: %d -> %d" % [w_small, c.plate_w])
	c.set_amount(5, false)
	ok(not c.is_rolling() and c.value == "5", "chip set without animation")
	V10Hud2Util.fx_override = "min"
	c.set_amount(777, true)
	ok(not c.is_rolling() and c.value == "777", "chip skips the roll at fx_level min")
	V10Hud2Util.fx_override = "full"
	var got: = [0]
	c.pressed.connect(func() -> void: got[0] += 1)
	_tap(c, Vector2(20, 24))
	ok(got[0] == 1, "chip tap -> pressed")
	ok(c._has_point(Vector2(10, -20)), "chip 96 px hit band")
	for k in TWCurrencyChip.KINDS:
		c.chip_kind = k
		ok(c.chip_kind == k, "chip kind %s" % k)
	c.chip_kind = "bogus"
	ok(c.chip_kind == "moon", "unknown chip kind falls back")
	c.queue_free()


# ------------------------------------------------------------------ 9 tab bar behaviour

func _tabbar() -> void:
	TWDraw.sim_insets = {"top": 0, "bottom": 0}
	var tb: = TWTabBar.make([{"id": "tea", "icon": "tab_tea", "label": "Чайная"}, {"id": "hero", "icon": "tab_heroines", "label": "Героини"},
			{"id": "shop", "icon": "tab_shop", "label": "Лавка"}])
	tb.viewport_override = Vector2(720, 1280)
	_host.add_child(tb)
	tb._layout()
	var got: Array = []
	tb.tab_selected.connect(func(id: String) -> void: got.append(id))
	ok(tb.current == "tea", "tabbar starts on the first tab")
	var g: = TWTabBar.compute(Vector2(720, 1280), {"top": 0, "bottom": 0}, 3)
	var c1: = (g.items[1] as Rect2).get_center() - tb.position
	_tap(tb, c1)
	ok(got == ["hero"] and tb.current == "hero", "tap on tab 2 selects it once: %s" % [got])
	_tap(tb, c1)
	ok(got == ["hero"], "tap on the current tab does not re-emit")
	tb.select("shop", false)
	ok(tb.current == "shop" and got == ["hero"], "programmatic select is silent")
	tb._gui_input(_ev(true, (g.items[0] as Rect2).get_center() - tb.position))
	tb._gui_input(_ev(false, (g.items[2] as Rect2).get_center() - tb.position))
	ok(got == ["hero"] and tb.current == "shop", "press on one tab, release on another selects nothing")
	tb.set_badge("hero", true)
	ok(tb._badges.get("hero", false), "badge flag")
	tb.queue_free()
	TWDraw.sim_insets = {}


# ------------------------------------------------------------------ 10 compat shims

func _shims() -> void:
	var vb: = V10Button.make("primary", "Играть", Vector2(560, 104))
	ok(vb is TWButton and vb.kind == "play", "V10Button is a TWButton, 'primary' -> play")
	var vq: = V10Button.make("quiet", "", Vector2(80, 80))
	ok(vq is TWButton and vq.kind == "quiet" and vq.hit_rect().size.x >= 96.0, "V10Button quiet 80x80 gets the 96 px hit rect")
	vb.breathing = true
	vb.sheen = true
	ok(vb.breathing and vb.sheen, "legacy V10Button knobs still assignable")
	var vp: = V10Plate.make("M", 328, "Подарок дня", "Загляни завтра", "120", "heart")
	ok(vp is TWPlate and vp.size_class == "M" and vp.plate_w == 328 and vp.value == "120" and V10Plate.height_of("L") == 160, "V10Plate is a TWPlate with the same API")
	var r: = Rect2(10, 10, 200, 100)
	ok(V10Button.rr_pts(r, 12.0, 6) == TWDraw.rr_pts(r, 12.0, 6) and V10Button.grad_cols(V10Button.rr_pts(r, 12.0), 0, 100, [[0.0, Color.RED], [1.0, Color.BLUE]]).size() == V10Button.rr_pts(r, 12.0).size(), "V10Button statics forward to TWDraw")
	ok(V10Button._hf_tex(true) == null, "dead hf_pill texture stays null")
	# the legacy V10DS and TWTokens agree on the colours both still define
	var drift: = []
	var consts: Dictionary = (TWTokens.new().get_script() as Script).get_script_constant_map()
	var legacy: Dictionary = (V10DS.new().get_script() as Script).get_script_constant_map()
	for k in legacy:
		if legacy[k] is Color and consts.has(k) and consts[k] != legacy[k]:
			drift.append(k)
	ok(drift.is_empty(), "V10DS vs TWTokens colour drift: %s" % [drift])
	var home: = V10HudHome.new()
	_host.add_child(home)
	var plates: = home.find_children("*", "TWPlate", true, false)
	ok(home.is_inside_tree(), "legacy HUD screen still builds on the shims (%d TWPlate children)" % plates.size())
	home.queue_free()
	vb.free()
	vq.free()
	vp.free()


# ------------------------------------------------------------------ 11 code lint of the widget files

func _code() -> void:
	var dir: = "res://shell/design/"
	var re: = RegEx.create_from_string("Color\\(\"#|Color\\(0\\.|Color8\\(|font_size\\s*=\\s*[0-9]|add_theme_font_size_override")
	var hit: = RegEx.create_from_string("V10DS\\.")
	var bad_raw: = []
	var bad_dep: = []
	var files: = 0
	for f in DirAccess.get_files_at(dir):
		if not f.ends_with(".gd") or f == "tw_tokens.gd" or f == "widgets_selftest.gd" or not f.begins_with("tw_"):
			continue
		files += 1
		var src: = FileAccess.get_file_as_string(dir + f)
		if re.search(src):
			bad_raw.append(f)
		if hit.search(src):
			bad_dep.append(f)
	ok(files >= 9, "widget source files found: %d" % files)
	ok(bad_raw.is_empty(), "raw colour / font size literals in widget code: %s" % [bad_raw])
	ok(bad_dep.is_empty(), "widget code reaching into V10DS: %s" % [bad_dep])
