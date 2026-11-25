class_name V10HudFxOdometerTest
extends RefCounted

# Selftest of V10Odometer (scripts/v10/hudfx/odometer.gd). Deterministic: odometers run on manual_clock and are
# stepped with advance(dt); only the «idle → not processing» check uses real frames.
#   format     grouping «1 980» (thin space when the font has it, else a space), minus, clamp, fallbacks
#   roll       320 ms EXPO_OUT, ≤ 12 steps per column, intermediate digits, direction up/down, display = format
#   cross      ±1 → 120 ms crossfade with a 4 px drift; digit-count change on ±1
#   reward     roll + 160 ms bump to 1.06 and back to exactly 1.0, gold tint only during the bump, one finished
#   quiet      never scales or tints (roll and ±1)
#   min        any change = one 120 ms fade, no rolling columns, no bump
#   width      same digit count → same width; 99→100 slides (width grows monotonically); align left/right/center
#   misc       interrupt continuity, negatives, large values, instant, prefix/suffix, attach(), in_plate(),
#              cleanup when the parent is freed mid-roll, idle → not processing, no colour literals
#   in match   the integrator hook lines on a real V10HudMatch (5 persistent nodes, status_n settings intact,
#              quiet ±1 without pulse, configure() snaps)
#   run(host) -> {"passed": int, "failed": int, "lines": Array[String]}

const DT: = 1.0 / 240.0

static var _pass: = 0
static var _fail: = 0
static var _lines: Array = []


static func ok(cond: bool, msg: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		_lines.append(msg)


static func run(host: Node) -> Dictionary:
	_pass = 0
	_fail = 0
	_lines = []
	var keep: = V10Hud2Util.fx_override
	V10Hud2Util.fx_override = "full"
	_format()
	_roll(host)
	_cross(host)
	_reward(host)
	_quiet(host)
	_min(host)
	V10Hud2Util.fx_override = "full"
	_width(host)
	_interrupt(host)
	_negatives_large(host)
	await _instant_affix(host)
	_attach_plate(host)
	await _in_match(host)
	await _cleanup(host)
	await _idle(host)
	_code()
	V10Hud2Util.fx_override = keep
	return {"passed": _pass, "failed": _fail, "lines": _lines}


# ------------------------------------------------------------------ helpers

static func _mk(host: Node, v: int, sz: = 40) -> V10Odometer:
	var o: = V10Odometer.make(v, sz, V10DS.PAPER_100)
	o.manual_clock = true
	host.add_child(o)
	return o


static func _run(o: V10Odometer, cap: = 4.0) -> float:
	# advance until settled; returns the simulated time it took
	var t: = 0.0
	while o.is_animating() and t < cap:
		o.advance(DT)
		t += DT
	return t


static func _sep() -> String:
	return V10Odometer.group_sep(V10Type.font("num"))


static func _shown(o: V10Odometer) -> String:
	return o.prefix + V10Odometer.format(o.value) + o.suffix


# ------------------------------------------------------------------ format

static func _format() -> void:
	var f: = V10Type.font("num")
	var sep: = _sep()
	var want_sep: = String.chr(0x202F) if f.has_char(0x202F) else (String.chr(0x2009) if f.has_char(0x2009) else " ")
	ok(sep == want_sep, "group separator U+%04X, want U+%04X" % [sep.unicode_at(0), want_sep.unicode_at(0)])
	ok(f.has_char(sep.unicode_at(0)), "group separator glyph missing in Numerals")
	var cases: = {0: "0", 7: "7", 30: "30", 999: "999", 1980: "1%s980" % sep, 2130: "2%s130" % sep,
			1240: "1%s240" % sep, 1234567: "1%s234%s567" % [sep, sep], 100000: "100%s000" % sep}
	for v in cases:
		ok(V10Odometer.format(v) == cases[v], "format(%d) = «%s», want «%s»" % [v, V10Odometer.format(v), cases[v]])
	var mn: = V10Odometer.minus_for(f)
	ok(mn == (String.chr(0x2212) if f.has_char(0x2212) else "-"), "minus glyph choice")
	ok(V10Odometer.format(-5) == mn + "5", "format(-5) = «%s»" % V10Odometer.format(-5))
	ok(V10Odometer.format(-1980) == mn + "1%s980" % sep, "format(-1980) = «%s»" % V10Odometer.format(-1980))
	ok(V10Odometer.format(V10Odometer.MAX_ABS + 77) == V10Odometer.format(V10Odometer.MAX_ABS), "format does not clamp large values")
	ok(V10Odometer.format(-V10Odometer.MAX_ABS - 77) == V10Odometer.format(-V10Odometer.MAX_ABS), "format does not clamp large negatives")
	# fallbacks: a font without the glyphs → plain space and hyphen-minus
	var bare: = FontFile.new()
	ok(V10Odometer.group_sep(bare) == " ", "separator fallback is not a plain space")
	ok(V10Odometer.minus_for(bare) == "-", "minus fallback is not «-»")
	ok(V10Odometer.group_sep(null) == " " and V10Odometer.minus_for(null) == "-", "null font fallbacks")


# ------------------------------------------------------------------ roll

static func _roll(host: Node) -> void:
	var o: = _mk(host, 120)
	ok(not o.is_processing(), "fresh odometer is processing")
	ok(o.display_text() == V10Odometer.format(120), "make() shows «%s»" % o.display_text())
	o.set_value(1240, "roll")
	ok(o.anim_kind() == "roll", "120→1240 kind %s, want roll" % o.anim_kind())
	ok(is_equal_approx(o.anim_duration(), 0.32), "roll duration %.3f, want 0.32" % o.anim_duration())
	ok(o.max_steps() <= 12 and o.max_steps() >= 10, "120→1240 max steps %d (want 10..12)" % o.max_steps())
	# EXPO_OUT: most of the travel early, exact landing
	o.advance(0.032)
	var p_early: = o.col_pos(1) - 2.0
	ok(p_early / o.col_steps(1) > 0.45, "roll is not EXPO_OUT (10 %% time → %.2f of travel)" % (p_early / o.col_steps(1)))
	var t: = 0.032 + _run(o)
	ok(absf(t - 0.32) <= DT * 1.5, "roll took %.3f s, want 0.32" % t)
	ok(o.display_text() == V10Odometer.format(1240), "after roll shows «%s», want «%s»" % [o.display_text(), V10Odometer.format(1240)])
	ok(is_equal_approx(o.current_scale(), 1.0), "plain roll scaled")
	# busy and quiet columns land together: at 200 ms every wheel is within 1.5 px of its digit
	var q: = _mk(host, 1980, 22)
	q.set_value(2130, "roll")
	q.advance(0.2)
	var worst_px: = 0.0
	for i in 4:
		var end: = q.col_pos(i) + 0.0
		var want: = roundf(end)
		worst_px = maxf(worst_px, absf(want - end) * V10Type.line_h(22))
	ok(worst_px <= 1.5, "a wheel lingers %.1f px off its digit at 200 ms" % worst_px)
	ok(absf(q.col_steps(0)) == 10.0 and absf(q.col_steps(3)) == 1.0, "1980→2130 steps (%.0f … %.0f), want 10 … 1" % [q.col_steps(0), q.col_steps(3)])
	q.queue_free()
	# big jump: never more than 12 steps in any column, lands on every digit
	o.set_value(987654321, "roll")
	var worst: = 0.0
	for i in 9:
		worst = maxf(worst, absf(o.col_steps(i)))
	ok(worst <= 12.0 and o.max_steps() <= 12, "big jump column steps %.0f (> 12)" % worst)
	_run(o)
	ok(o.display_text() == V10Odometer.format(987654321), "big jump shows «%s»" % o.display_text())
	# intermediate digits: 0 → 5 passes 1, 2, 3, 4 (rolls up)
	o.set_value(0, "instant")
	o.set_value(5, "roll")
	ok(o.col_steps(0) == 5.0, "0→5 units steps %.1f, want +5 (up)" % o.col_steps(0))
	var seen: = {}
	while o.is_animating():
		seen[int(floor(o.col_pos(0) + 0.0001))] = true
		o.advance(DT * 0.25)
	ok(seen.has(1) and seen.has(2) and seen.has(3) and seen.has(4), "0→5 skipped intermediate digits: %s" % [seen.keys()])
	# decrease rolls down
	o.set_value(30, "instant")
	o.set_value(26, "roll")
	ok(o.col_steps(0) < 0.0 and o.col_steps(1) < 0.0, "30→26 does not roll down (%.0f, %.0f)" % [o.col_steps(0), o.col_steps(1)])
	ok(o.col_steps(0) == -4.0 and o.col_steps(1) == -1.0, "30→26 steps (%.0f, %.0f), want (-4, -1)" % [o.col_steps(0), o.col_steps(1)])
	_run(o)
	ok(o.display_text() == "26", "30→26 shows «%s»" % o.display_text())
	# unknown mode → roll; fx mid behaves as full
	V10Hud2Util.fx_override = "mid"
	o.set_value(40, "sparkle")
	ok(o.anim_kind() == "roll", "unknown mode / fx mid: kind %s" % o.anim_kind())
	_run(o)
	V10Hud2Util.fx_override = "full"
	ok(o.display_text() == "40", "mid shows «%s»" % o.display_text())
	o.queue_free()


# ------------------------------------------------------------------ ±1 crossfade

static func _cross(host: Node) -> void:
	var o: = _mk(host, 30, 22)
	o.set_value(29, "quiet")
	ok(o.anim_kind() == "cross", "30→29 kind %s, want cross" % o.anim_kind())
	ok(is_equal_approx(o.anim_duration(), 0.12), "crossfade duration %.3f" % o.anim_duration())
	ok(absf(absf(o.cross_dy()) - V10Odometer.DRIFT) < 0.01, "crossfade drift starts at %.2f px, want 4" % o.cross_dy())
	ok(o.cross_dy() < 0.0, "decrease: new digit should come from above (dy %.2f)" % o.cross_dy())
	ok(o.max_steps() == 1, "crossfade steps %d" % o.max_steps())
	var last: = absf(o.cross_dy())
	var mono: = true
	var t: = 0.0
	while o.is_animating():
		o.advance(DT)
		t += DT
		if absf(o.cross_dy()) > last + 0.0001:
			mono = false
		last = absf(o.cross_dy())
	ok(mono, "crossfade drift is not monotonic")
	ok(absf(t - 0.12) <= DT * 1.5, "crossfade took %.3f s, want 0.12" % t)
	ok(o.display_text() == "29", "30→29 shows «%s»" % o.display_text())
	o.set_value(30, "quiet")
	ok(o.anim_kind() == "cross" and o.cross_dy() > 0.0, "increase ±1: new digit should rise from below")
	_run(o)
	# ±1 that changes the digit count
	o.set_value(9, "instant")
	o.set_value(10, "roll")
	ok(o.anim_kind() == "cross", "9→10 kind %s" % o.anim_kind())
	var w0: = o.block_width()
	_run(o)
	ok(o.display_text() == "10" and o.block_width() > w0, "9→10 shows «%s», width %.0f→%.0f" % [o.display_text(), w0, o.block_width()])
	o.set_value(1000, "instant")
	o.set_value(999, "roll")
	_run(o)
	ok(o.display_text() == "999", "1000→999 shows «%s»" % o.display_text())
	o.queue_free()


# ------------------------------------------------------------------ reward / quiet

static func _reward(host: Node) -> void:
	var o: = _mk(host, 1980, 22)
	var fin: = [0]
	o.finished.connect(func() -> void: fin[0] += 1)
	o.set_value(2130, "reward")
	var smax: = 1.0
	var tint_max: = 0.0
	var tint_during_roll: = 0.0
	var t: = 0.0
	var t_peak: = 0.0
	while o.is_animating() and t < 2.0:
		o.advance(DT)
		t += DT
		if o.current_scale() > smax:
			smax = o.current_scale()
			t_peak = t
		tint_max = maxf(tint_max, o.current_tint())
		if t < 0.32 - DT:
			tint_during_roll = maxf(tint_during_roll, o.current_tint())
	ok(absf(t - 0.48) <= DT * 1.5, "reward took %.3f s, want 0.32 + 0.16" % t)
	ok(smax >= 1.059 and smax <= 1.0601, "reward bump peak %.4f, want 1.06" % smax)
	ok(absf(t_peak - 0.40) <= 0.01, "bump peak at %.3f s, want 0.40 (middle of the 160 ms bump)" % t_peak)
	ok(o.current_scale() == 1.0, "reward ends at scale %.4f" % o.current_scale())
	ok(tint_max > 0.95 and tint_during_roll == 0.0, "gold tint %.2f (roll %.2f): only during the bump" % [tint_max, tint_during_roll])
	ok(o.current_tint() == 0.0, "tint left after the bump")
	ok(fin[0] == 1, "finished emitted %d times, want 1" % fin[0])
	ok(o.display_text() == V10Odometer.format(2130), "reward shows «%s»" % o.display_text())
	# ±1 reward: crossfade then bump
	o.set_value(2131, "reward")
	ok(o.anim_kind() == "cross", "reward ±1 kind %s" % o.anim_kind())
	t = _run(o)
	ok(absf(t - 0.28) <= DT * 1.5, "reward ±1 took %.3f s, want 0.12 + 0.16" % t)
	ok(fin[0] == 2, "finished after ±1 reward: %d" % fin[0])
	o.queue_free()


static func _quiet(host: Node) -> void:
	var o: = _mk(host, 30, 22)
	o.prefix = "Осталось "
	for pair in [[25, "roll"], [24, "cross"], [26, "roll"], [27, "cross"]]:
		o.set_value(pair[0], "quiet")
		ok(o.anim_kind() == pair[1], "quiet →%d kind %s, want %s" % [pair[0], o.anim_kind(), pair[1]])
		var smax: = 1.0
		var tmax: = 0.0
		var t: = 0.0
		while o.is_animating() and t < 2.0:
			o.advance(DT)
			t += DT
			smax = maxf(smax, o.current_scale())
			tmax = maxf(tmax, o.current_tint())
		ok(smax == 1.0 and tmax == 0.0, "quiet →%d scaled %.3f / tinted %.2f (no pulse allowed)" % [pair[0], smax, tmax])
		ok(absf(t - o.anim_duration()) <= DT * 1.5, "quiet →%d took %.3f s, want %.2f" % [pair[0], t, o.anim_duration()])
		ok(o.display_text() == _shown(o), "quiet shows «%s», want «%s»" % [o.display_text(), _shown(o)])
	o.queue_free()


# ------------------------------------------------------------------ fx min

static func _min(host: Node) -> void:
	V10Hud2Util.fx_override = "min"
	var o: = _mk(host, 120, 40)
	for pair in [[1240, "reward"], [1239, "quiet"], [5, "roll"]]:
		o.set_value(pair[0], pair[1])
		ok(o.anim_kind() == "fade", "min →%d kind %s, want fade" % [pair[0], o.anim_kind()])
		var smax: = 1.0
		var t: = 0.0
		var cols: = 0
		while o.is_animating() and t < 2.0:
			o.advance(DT)
			t += DT
			smax = maxf(smax, o.current_scale())
			cols = maxi(cols, o.columns_in_use())
		ok(absf(t - 0.12) <= DT * 1.5, "min →%d took %.3f s, want 0.12" % [pair[0], t])
		ok(smax == 1.0, "min →%d scaled to %.3f" % [pair[0], smax])
		ok(cols == 0, "min →%d used %d rolling columns" % [pair[0], cols])
		ok(o.display_text() == V10Odometer.format(pair[0]), "min shows «%s»" % o.display_text())
	o.queue_free()
	V10Hud2Util.fx_override = "full"


# ------------------------------------------------------------------ width / align

static func _width(host: Node) -> void:
	var o: = _mk(host, 100, 40)
	var groups: = [[100, 111, 999, 808, 470], [1980, 2130, 1111, 9999, 1000], [7, 0, 1, 8]]
	for g in groups:
		var w0: = -1.0
		var same: = true
		for v in g:
			o.set_value(v, "instant")
			var w: = o.get_combined_minimum_size().x
			if w0 < 0.0:
				w0 = w
			elif absf(w - w0) > 0.01:
				same = false
		ok(same, "width changes inside the digit count of %s" % [g])
	ok(o.width_for(99) < o.width_for(100) and o.width_for(999) < o.width_for(1000), "more digits are not wider")
	ok(o.get_combined_minimum_size().y == float(V10Type.line_h(40)), "min height %.0f, want line 44" % o.get_combined_minimum_size().y)
	# 99 → 100 slides the new column in: width grows monotonically, min size holds the wider value
	o.set_value(99, "instant")
	o.set_value(100, "roll")
	ok(absf(o.get_combined_minimum_size().x - ceilf(o.width_for(100))) < 0.01, "min size during a slide is not the wider value")
	var last: = o.block_width()
	ok(absf(last - o.width_for(99)) < 0.01, "slide does not start at the old width")
	var mono: = true
	while o.is_animating():
		o.advance(DT)
		if o.block_width() < last - 0.001:
			mono = false
		last = o.block_width()
	ok(mono and absf(last - o.width_for(100)) < 0.01, "99→100 width not monotonic or wrong end %.1f" % last)
	o.set_value(99, "roll")
	_run(o)
	ok(absf(o.get_combined_minimum_size().x - ceilf(o.width_for(99))) < 0.01, "100→99 min width did not shrink back")
	# align
	o.set_value(1980, "instant")
	o.size = Vector2(320, 44)
	o.align = "left"
	ok(absf(o.content_x()) < 0.01, "align left x %.1f" % o.content_x())
	o.align = "right"
	ok(absf(o.content_x() + o.width_for(1980) - 320.0) < 0.01, "align right does not end at the right edge")
	o.align = "center"
	ok(absf(o.content_x() - (320.0 - o.width_for(1980)) * 0.5) < 0.01, "align center off")
	o.align = "diagonal"
	ok(o.align == "left", "bad align not reset to left")
	o.queue_free()


# ------------------------------------------------------------------ interrupt continuity

static func _interrupt(host: Node) -> void:
	var o: = _mk(host, 1980, 22)
	var fin: = [0]
	o.finished.connect(func() -> void: fin[0] += 1)
	o.set_value(2030, "reward")
	o.advance(0.08)
	var before: = [o.col_pos(0), o.col_pos(1), o.col_pos(2), o.col_pos(3)]
	o.set_value(2080, "reward")
	var jump: = 0.0
	for i in 4:
		jump = maxf(jump, absf(o.col_pos(i) - before[i]))
	ok(jump < 0.001, "re-target jumped %.3f digit" % jump)
	ok(o.max_steps() <= 12, "re-target steps %d" % o.max_steps())
	o.advance(0.06)
	o.set_value(2130, "reward")
	_run(o)
	ok(o.display_text() == V10Odometer.format(2130), "cascade lands on «%s»" % o.display_text())
	ok(fin[0] == 1, "cascade emitted finished %d times, want 1" % fin[0])
	# a bump interrupted by a new value eases out (no jump) and a quiet change does not re-bump
	o.set_value(2200, "reward")
	o.advance(0.32 + 0.06)
	var s_before: = o.current_scale()
	o.set_value(2210, "quiet")
	ok(absf(o.current_scale() - s_before) < 0.0001 and s_before > 1.0, "bump jumped on interrupt (%.4f → %.4f)" % [s_before, o.current_scale()])
	var smax_late: = 1.0
	var t: = 0.0
	while o.is_animating():
		o.advance(DT)
		t += DT
		if t > 0.12 + DT:
			smax_late = maxf(smax_late, o.current_scale())
	ok(smax_late == 1.0 and o.current_scale() == 1.0, "carried bump did not ease out in 120 ms")
	# a crossfade interrupted by a roll completes first
	o.set_value(2209, "quiet")
	o.advance(0.05)
	o.set_value(2300, "quiet")
	ok(o.anim_kind() == "roll", "cross→roll kind %s" % o.anim_kind())
	_run(o)
	ok(o.display_text() == V10Odometer.format(2300), "cross→roll shows «%s»" % o.display_text())
	# same value while animating: no restart
	o.set_value(2400, "roll")
	o.advance(0.1)
	o.set_value(2400, "roll")
	ok(absf(_run(o) - 0.22) <= DT * 1.5, "same value restarted the roll")
	o.queue_free()


# ------------------------------------------------------------------ negatives / large values

static func _negatives_large(host: Node) -> void:
	var o: = _mk(host, 3, 40)
	var mn: = V10Odometer.minus_for(V10Type.font("num"))
	o.set_value(-2, "roll")
	_run(o)
	ok(o.display_text() == mn + "2", "3→-2 shows «%s»" % o.display_text())
	ok(o.width_for(-5) > o.width_for(5), "minus takes no width")
	o.set_value(-5, "roll")
	ok(o.col_steps(0) > 0.0, "-2→-5: magnitude digits should roll up (%.0f)" % o.col_steps(0))
	_run(o)
	o.set_value(5, "roll")
	_run(o)
	ok(o.display_text() == "5", "-5→5 shows «%s»" % o.display_text())
	o.set_value(V10Odometer.MAX_ABS + 1000, "reward")
	ok(o.value == V10Odometer.MAX_ABS, "large value not clamped: %d" % o.value)
	ok(o.max_steps() <= 12, "large jump steps %d" % o.max_steps())
	_run(o)
	ok(o.display_text() == V10Odometer.format(V10Odometer.MAX_ABS), "large shows «%s»" % o.display_text())
	o.set_value(-V10Odometer.MAX_ABS - 5, "roll")
	_run(o)
	ok(o.value == -V10Odometer.MAX_ABS and o.display_text() == V10Odometer.format(-V10Odometer.MAX_ABS), "large negative «%s»" % o.display_text())
	o.queue_free()


# ------------------------------------------------------------------ instant / prefix / suffix / value property

static func _instant_affix(host: Node) -> void:
	var o: = _mk(host, 12, 22)
	var fin: = [0]
	o.finished.connect(func() -> void: fin[0] += 1)
	o.set_value(77, "instant")
	ok(not o.is_animating() and o.display_text() == "77", "instant shows «%s»" % o.display_text())
	await host.get_tree().process_frame
	ok(fin[0] == 1, "instant finished emitted %d times (deferred, want 1)" % fin[0])
	o.set_value(77, "roll")
	await host.get_tree().process_frame
	ok(fin[0] == 2 and not o.is_animating(), "same value at rest: no animation, one deferred finished")
	o.prefix = "Осталось "
	o.suffix = " ходов"
	var pw: = V10Type.font("ui").get_string_size("Осталось ", HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	var sw: = V10Type.font("ui").get_string_size(" ходов", HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	ok(absf(o.width_for(77) - (pw + sw + o.block_width())) < 0.01, "prefix/suffix not in the width")
	ok(o.get_combined_minimum_size().x >= pw + sw + o.block_width() - 0.01, "min size misses the affixes")
	ok(o.display_text() == "Осталось 77 ходов", "affix text «%s»" % o.display_text())
	o.mode_default = "quiet"
	o.value = 76
	ok(o.is_animating() and o.anim_kind() == "cross", "value property does not animate with mode_default")
	_run(o)
	ok(o.value == 76 and o.display_text() == "Осталось 76 ходов", "value property shows «%s»" % o.display_text())
	o.queue_free()


# ------------------------------------------------------------------ hooks: attach() and in_plate()

static func _attach_plate(host: Node) -> void:
	var l: = V10Type.label("30", "num", 22, V10DS.PAPER_100)
	l.size = Vector2(64, 40)
	host.add_child(l)
	var o: = V10Odometer.attach(l, 30)
	o.manual_clock = true
	ok(o.get_parent() == l and o.name == "Odometer", "attach: not a child named Odometer")
	ok(l.self_modulate.a == 0.0 and l.label_settings.font_size == 22 and l.label_settings.outline_size == 0, "attach: label not hidden or its settings changed")
	ok(o.font_size == 22 and o.color == V10DS.PAPER_100 and o.mode_default == "quiet" and not o.on_art, "attach: odometer does not mirror the label")
	ok(o.size == l.size, "attach: odometer %s does not fill the label %s" % [o.size, l.size])
	o.set_value(29, o.mode_default)
	ok(o.anim_kind() == "cross", "attach: 30→29 kind %s" % o.anim_kind())
	_run(o)
	ok(o.display_text() == "29", "attach shows «%s»" % o.display_text())
	l.queue_free()
	var p: = V10Plate.make("S", 144, "", "", "1 980", "")
	host.add_child(p)
	var po: = V10Odometer.in_plate(p, 1980)
	po.manual_clock = true
	ok(p.value == "" and po.plate == p and po.get_parent() == p, "in_plate: value slot not taken over")
	ok(po.font_size == 22 and po.align == "right", "in_plate: S → Numerals 22 right-aligned")
	ok(po.position.x >= 0.0 and po.position.x + po.size.x <= 144.0 and po.size.y == 48.0, "in_plate: outside the plate")
	ok(po.position.x + po.size.x + 16.0 == 144.0, "in_plate: right edge not on the plate padding")
	po.set_value(2130, "reward")
	ok(po.pings == 1, "in_plate: reward did not ping the plate")
	po.set_value(2180, "reward")
	ok(po.pings == 1, "in_plate: pings faster than one per 360 ms")
	po.set_value(2190, "quiet")
	ok(po.pings == 1, "in_plate: quiet pinged the plate")
	_run(po)
	ok(po.display_text() == V10Odometer.format(2190), "in_plate shows «%s»" % po.display_text())
	ok(po.get_combined_minimum_size().x <= po.size.x, "in_plate: 4 digits do not fit S 144")
	p.queue_free()


static func _in_match(host: Node) -> void:
	# the integrator hook on a real V10HudMatch: hud2 invariants hold (5 persistent nodes, status_n settings)
	var hud: = V10HudMatch.new()
	host.add_child(hud)
	hud.configure({"hero": "mc", "level": "1-2", "total": 30, "left": 30, "helpers": {"undo": 2, "hint": 3, "shuffle": 1}})
	await host.get_tree().process_frame
	# _build() hook
	var odo_s: = V10Hud2Util.opt_class("V10Odometer")
	ok(odo_s != null, "opt_class(\"V10Odometer\") not found (class cache)")
	if odo_s:
		odo_s.call("attach", hud.status_n, hud.left)
	var o: V10Odometer = hud.status_n.get_node_or_null("Odometer")
	ok(o != null, "hook: no Odometer under status_n")
	if o == null:
		hud.queue_free()
		return
	o.manual_clock = true
	ok(hud.persistent_nodes().size() == 5, "hook: match has %d persistent nodes" % hud.persistent_nodes().size())
	ok(hud.status_n.label_settings.font_size == 22 and hud.status_n.label_settings.outline_size == 0, "hook: status_n settings changed")
	ok(o.display_text() == "30" and o.size == hud.status_n.size, "hook: odometer «%s» %s vs label %s" % [o.display_text(), o.size, hud.status_n.size])
	# set_left() hook
	hud.set_left(29)
	if hud.status_n.has_node("Odometer"):
		hud.status_n.get_node("Odometer").call("set_value", 29, "quiet")
	ok(o.anim_kind() == "cross", "hook: 30→29 kind %s" % o.anim_kind())
	var smax: = 1.0
	while o.is_animating():
		o.advance(DT)
		smax = maxf(smax, o.current_scale())
	ok(smax == 1.0 and o.display_text() == "29", "hook: «Осталось» pulsed or shows «%s»" % o.display_text())
	# configure() hook (a new level: the count jumps, no roll)
	hud.configure({"level": "1-3", "total": 36, "left": 36})
	if is_instance_valid(hud.status_n) and hud.status_n.has_node("Odometer"):
		hud.status_n.get_node("Odometer").call("set_value", hud.left, "instant")
	ok(not o.is_animating() and o.display_text() == "36", "hook: configure shows «%s»" % o.display_text())
	hud.queue_free()


# ------------------------------------------------------------------ cleanup / processing

static func _cleanup(host: Node) -> void:
	var base: = V10Odometer.live_items
	var parent: = Control.new()
	parent.size = Vector2(400, 60)
	host.add_child(parent)
	var o: = V10Odometer.make(120, 40)
	parent.add_child(o)
	var ref: = weakref(o)
	o.set_value(1240, "reward")
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	ok(o.columns_in_use() > 0 or DisplayServer.get_name() == "headless", "rolling columns not drawn into clipped items")
	ok(V10Odometer.live_items > base, "no clipped column items while rolling")
	parent.queue_free()  # the parent goes away mid-roll
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	ok(ref.get_ref() == null, "odometer survived its parent")
	ok(V10Odometer.live_items == base, "column canvas items leaked: %d" % (V10Odometer.live_items - base))


static func _idle(host: Node) -> void:
	var o: = V10Odometer.make(30, 22)
	host.add_child(o)
	ok(not o.is_processing(), "idle odometer processes")
	o.set_value(26, "quiet")
	ok(o.is_processing(), "rolling odometer does not process")
	var n: = 0
	while o.is_animating() and n < 240:
		await host.get_tree().process_frame
		n += 1
	await host.get_tree().process_frame
	ok(not o.is_animating() and not o.is_processing(), "odometer keeps processing when idle")
	ok(o.display_text() == "26", "real-time roll shows «%s»" % o.display_text())
	o.queue_free()


static func _code() -> void:
	var bad: = []
	var re: = RegEx.create_from_string("Color\\(\"#|Color\\(0\\.|Color\\([0-9]")
	for p in ["res://scripts/v10/hudfx/odometer.gd", "res://scripts/v10/hudfx/demo/odometer_demo.gd"]:
		if FileAccess.file_exists(p) and re.search(FileAccess.get_file_as_string(p)):
			bad.append(p.get_file())
	ok(bad.is_empty(), "colour literals outside V10DS: %s" % [bad])
