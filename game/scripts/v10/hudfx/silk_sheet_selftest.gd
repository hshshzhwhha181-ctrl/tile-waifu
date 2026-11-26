class_name V10HudFxSilkSheetTest
extends RefCounted

# V10SilkSheet self-test (headless-safe; tweens are stepped by hand, no wall clock):
#   godot --headless --path game res://scripts/v10/hudfx/demo/silk_sheet_demo.tscn -- --selftest=1
# → «HUDFX SILK_SHEET SELFTEST passed/total», exit code = failures.
# Covers: soften() pipeline (size, real blur, timings, bad images), headless fallback tone, open 0.22 / close 0.16,
# geometry (8 grid, safe inset, clamp, title, content rect), input blocking + outside tap + Android back, one readback
# per open (sim_frame), snapshot texture freed, swap instead of sheet-over-sheet, host freed mid-animation,
# close before ready, double close, fx min (120 ms fades, no slide), no _process, no hex colours.

static var _passed: = 0
static var _failed: = 0
static var _lines: Array = []


static func _ok(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		_lines.append(what)


static func _near(a: float, b: float, eps: = 0.5) -> bool:
	return absf(a - b) <= eps


static func _click(vp: Viewport, p: Vector2) -> void:
	for down in [true, false]:
		var e: = InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = down
		e.position = p
		e.global_position = p
		vp.push_input(e, true)


static func _content() -> Control:
	var c: = Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var b: = Control.new()
	b.name = "Btn"
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.position = Vector2(0, 0)
	b.size = Vector2(672, 80)
	c.add_child(b)
	return c


static func _split_image(w: int, h: int) -> Image:
	# left half night.900, right half paper.100: a hard edge the blur must soften
	var img: = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(V10DS.NIGHT_900)
	img.fill_rect(Rect2i(w / 2, 0, w - w / 2, h), V10DS.PAPER_100)
	return img


static func _counter(s: V10SilkSheet) -> Array:
	var n: = [0, 0]
	s.opened.connect(func() -> void: n[0] += 1)
	s.closed.connect(func() -> void: n[1] += 1)
	return n


static func run(host: Node) -> Dictionary:
	_passed = 0
	_failed = 0
	_lines = []
	var tree: = host.get_tree()
	var keep_fx: = V10Hud2Util.fx_override
	var keep_ins: = V10Hud2Util.sim_insets
	var keep_log: = V10SilkSheet.log_timing
	V10SilkSheet.log_timing = false
	V10SilkSheet.sim_frame = null
	V10Hud2Util.fx_override = "full"
	V10Hud2Util.sim_insets = {"top": 0.0, "bottom": 0.0}
	var stage: = Control.new()
	stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(stage)
	await tree.process_frame
	var vp: = stage.get_viewport()
	var vs: = stage.get_viewport_rect().size
	var headless: = DisplayServer.get_name() == "headless"

	# ---- 1. soften(): 1/8 by box halvings, a real blur, timings, unusable images → null
	var t720: = V10SilkSheet.soften(_split_image(720, 1280))
	_ok(t720 != null and t720.get_width() == 90 and t720.get_height() == 160, "soften 720x1280 → 90x160")
	if t720:
		var im: = t720.get_image()
		var mid: = im.get_pixel(45, 80).r
		var lo: = im.get_pixel(4, 80).r
		var hi: = im.get_pixel(86, 80).r
		_ok(_near(lo, V10DS.NIGHT_900.r, 0.03) and _near(hi, V10DS.PAPER_100.r, 0.03), "blur keeps flat areas (%.2f / %.2f)" % [lo, hi])
		_ok(mid > lo + 0.2 and mid < hi - 0.2, "blur softens the hard edge (%.2f)" % mid)
		var ramp: = im.get_pixel(42, 80).r
		_ok(ramp > lo + 0.03 and ramp < mid, "edge spreads over several px (%.2f)" % ramp)
	for k in ["read", "shrink", "blur", "upload", "total"]:
		_ok(V10SilkSheet.last_ms.has(k) and float(V10SilkSheet.last_ms[k]) >= 0.0, "last_ms has " + k)
	_ok(V10SilkSheet.last_ms.get("out", Vector2i.ZERO) == Vector2i(90, 160), "last_ms out 90x160")
	var t1080: = V10SilkSheet.soften(_split_image(1080, 2400))
	_ok(t1080 != null and t1080.get_width() == 90 and t1080.get_height() == 200, "soften 1080x2400 → 90x200")
	var t405: = V10SilkSheet.soften(_split_image(405, 877))
	_ok(t405 != null and t405.get_width() == 90, "soften 405x877 → 90 wide")
	var trgb: = Image.create(720, 1280, false, Image.FORMAT_RGB8)
	trgb.fill(V10DS.NIGHT_700)
	_ok(V10SilkSheet.soften(trgb) != null, "soften accepts RGB8")
	var tf: = Image.create(256, 256, false, Image.FORMAT_RGBAF)
	_ok(V10SilkSheet.soften(tf) != null, "soften converts a float image")
	_ok(V10SilkSheet.soften(null) == null, "soften(null) → null")
	_ok(V10SilkSheet.soften(Image.new()) == null, "soften(empty) → null")
	_ok(V10SilkSheet.soften(Image.create(4, 4, false, Image.FORMAT_RGBA8)) == null, "soften(4x4) → null")

	# ---- 2. headless fallback: flat night.900 α 0.72, no readback, open 0.22 QUINT_OUT
	var cap0: = V10SilkSheet.captures
	var content: = _content()
	var s: = V10SilkSheet.open(stage, content, 472, {"title": "Пауза", "dismiss_outside": false})
	var n: = _counter(s)
	_ok(s != null and s.is_inside_tree(), "open() returns the sheet in the tree")
	if s.state == "capturing":  # run with a renderer: the real readback happens after this frame is drawn
		await RenderingServer.frame_post_draw
	if headless:
		_ok(s.state == "opening", "headless: opens at once (%s)" % s.state)
		_ok(not s.blurred and not s.snap_rect.visible and s.snapshot == null, "headless: no snapshot")
		_ok(_near(s.tone_rect.color.a, 0.72, 0.001) and s.tone_rect.color.r == V10DS.NIGHT_900.r, "headless: night.900 α 0.72 tone")
		_ok(V10SilkSheet.captures == cap0, "headless: no readback")
	_ok(V10SilkSheet.current() == s, "current() is the sheet")
	_ok(s.mouse_filter == Control.MOUSE_FILTER_STOP and s.get_global_rect().has_point(Vector2(1, 1)) and _near(s.size.x, vs.x) and _near(s.size.y, vs.y), "blocker covers the viewport")
	_ok(not s.is_processing() and not s.is_physics_processing(), "no _process")
	_ok(s.process_mode == Node.PROCESS_MODE_ALWAYS, "works while the tree is paused")
	_ok(s.get_meta("v8_back", null) is Callable, "Android back meta")
	var y_open: = vs.y - 472.0
	_ok(_near(s.panel.size.y, 472.0) and _near(s.panel.size.x, vs.x), "panel 472 high, full width")
	_ok(_near(s.panel.position.y, vs.y), "panel starts below the edge")
	_ok(s.title_l != null and s.title_l.label_settings.font_size == 44 and s.title_l.label_settings.outline_size == 0 and s.title_l.label_settings.shadow_size == 0, "title H1 Display 44, no outline/shadow")
	var cx: = floorf((vs.x - minf(vs.x, 720.0)) * 0.5)
	_ok(s.title_l != null and s.title_l.position == Vector2(cx + 24, 24), "title at 24, 24")
	_ok(content.get_parent() == s.panel and content.position == Vector2(cx + 24, 96) and content.size == Vector2(672, 352), "content rect 24,96 672x352 (%s %s)" % [content.position, content.size])
	var tw: = s.tween()
	_ok(tw != null and tw.is_valid(), "open tween runs")
	if tw:
		tw.pause()
		tw.custom_step(0.11)
		var prog: = (vs.y - s.panel.position.y) / 472.0
		_ok(_near(prog, 1.0 - pow(0.5, 5), 0.02), "QUINT_OUT: 97 %% up at 110 ms (%.3f)" % prog)
		_ok(_near(s.backdrop.modulate.a, 1.0 - pow(0.5, 5), 0.02), "backdrop fades with it (%.3f)" % s.backdrop.modulate.a)
		tw.custom_step(0.108)
		_ok(n[0] == 0 and s.state == "opening", "not open at 218 ms")
		tw.custom_step(0.004)
		_ok(n[0] == 1 and s.state == "open", "opened at 220 ms")
		_ok(_near(s.panel.position.y, y_open) and _near(s.backdrop.modulate.a, 1.0, 0.001), "panel up, backdrop in")
		_ok(s.tween() == null, "no tween after open (nothing per frame)")
	# input: behind blocked, outside tap ignored when dismiss_outside = false, rows work
	var behind_n: = [0]
	var behind: = Control.new()
	behind.mouse_filter = Control.MOUSE_FILTER_STOP
	behind.position = Vector2.ZERO
	behind.size = vs
	behind.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton:
			behind_n[0] += 1)
	stage.add_child(behind)
	stage.move_child(behind, 0)  # under the sheet, as the screen is
	var btn_n: = [0]
	content.get_node("Btn").gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton:
			btn_n[0] += 1)
	_click(vp, Vector2(vs.x * 0.5, 200))
	_ok(behind_n[0] == 0, "tap outside does not reach the screen behind")
	_ok(s.state == "open", "dismiss_outside=false keeps it open")
	_click(vp, Vector2(vs.x - 8, y_open + 8))
	_ok(behind_n[0] == 0 and s.state == "open", "tap on the sheet surface stays on the sheet")
	_click(vp, s.panel.position + content.position + Vector2(40, 40))
	_ok(btn_n[0] == 2, "rows inside the sheet get taps (%d)" % btn_n[0])
	await tree.process_frame
	_ok(V10SilkSheet.captures == cap0 or not headless, "no readback after open")
	# close 0.16 QUINT_IN
	var wr_content: = weakref(content)
	s.close()
	s.close()
	_ok(s.state == "closing" and s.get_meta("closing", false), "close() → closing")
	_ok(s._guard.visible, "rows locked while closing")
	_click(vp, Vector2(vs.x * 0.5, 200))
	_ok(behind_n[0] == 0, "still blocked while closing")
	var tc: = s.tween()
	if tc:
		tc.pause()
		tc.custom_step(0.08)
		var down: = (s.panel.position.y - y_open) / 472.0
		_ok(_near(down, pow(0.5, 5), 0.02), "QUINT_IN: 3 %% down at 80 ms (%.3f)" % down)
		tc.custom_step(0.078)
		_ok(n[1] == 0 and s.state == "closing", "not closed at 158 ms")
		tc.custom_step(0.004)
		_ok(n[1] == 1 and s.state == "closed", "closed at 160 ms")
	_ok(s.is_queued_for_deletion(), "sheet queued for deletion")
	_ok(V10SilkSheet.current() == null, "current() cleared")
	await tree.process_frame
	_ok(not is_instance_valid(s), "sheet freed")
	_ok(wr_content.get_ref() == null, "content freed with it")
	_ok(n[1] == 1, "closed exactly once (double close)")
	_click(vp, Vector2(vs.x * 0.5, 200))
	_ok(behind_n[0] == 2, "the screen behind gets taps again")
	behind.queue_free()

	# ---- 3. one readback per open (sim_frame stands in for the viewport), tone, snapshot freed on close
	V10SilkSheet.sim_frame = _split_image(720, 1280)
	cap0 = V10SilkSheet.captures
	var s2: = V10SilkSheet.open(stage, _content(), 400, {"tone": 0.3})
	var n2: = _counter(s2)
	_ok(V10SilkSheet.captures == cap0 + 1, "one readback per open (%d)" % (V10SilkSheet.captures - cap0))
	_ok(s2.blurred and s2.snap_rect.visible and s2.snapshot != null and s2.snap_rect.texture == s2.snapshot, "blurred snapshot under the sheet")
	_ok(s2.snapshot != null and s2.snapshot.get_width() == 90, "snapshot is 1/8 (90 px wide)")
	_ok(_near(s2.tone_rect.color.a, 0.3, 0.001), "opts.tone → tone α")
	_ok(s2.snap_rect.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR and s2.snap_rect.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_COVERED, "linear filter, covered stretch")
	_ok(V10SilkSheet.sim_frame.get_width() == 720, "the source frame is not modified")
	_ok(s2.title_l == null, "no title → no H1")
	var wr_tex: = weakref(s2.snapshot)
	s2.tween().custom_step(1.0)
	_ok(s2.state == "open" and n2[0] == 1, "opened")
	for i in 3:
		await tree.process_frame
	_ok(V10SilkSheet.captures == cap0 + 1, "no readback while open")
	# outside tap closes (dismiss_outside default true)
	_click(vp, Vector2(vs.x * 0.5, 100))
	_ok(s2.state == "closing", "tap outside → close()")
	s2.tween().custom_step(1.0)
	_ok(n2[1] == 1 and s2.snap_rect.texture == null and s2.snapshot == null, "closed, texture released")
	await tree.process_frame
	_ok(not is_instance_valid(s2) and wr_tex.get_ref() == null, "snapshot ImageTexture freed")
	# a second open reads back again — exactly once more
	var s3: = V10SilkSheet.open(stage, _content(), 400)
	_ok(V10SilkSheet.captures == cap0 + 2, "second open: second readback")
	s3.tween().custom_step(1.0)
	# swap: a sheet never opens over a sheet — the new one takes the snapshot, no extra readback
	var n3: = _counter(s3)
	var tex3: = s3.snapshot
	var s4: = V10SilkSheet.open(stage, _content(), 300)
	var n4: = _counter(s4)
	_ok(n3[1] == 1 and not s3.visible and s3.is_queued_for_deletion(), "swap: the old sheet closes this frame")
	_ok(s4.snapshot == tex3 and s4.blurred and V10SilkSheet.captures == cap0 + 2, "swap: snapshot reused, no readback")
	_ok(_near(s4.backdrop.modulate.a, 1.0, 0.001), "swap: backdrop stays (no flicker)")
	_ok(V10SilkSheet.current() == s4, "swap: current() is the new sheet")
	s4.tween().custom_step(1.0)
	_ok(n4[0] == 1, "swap: new sheet opened")
	s4.close()
	s4.tween().custom_step(1.0)
	await tree.process_frame
	_ok(not is_instance_valid(s3) and not is_instance_valid(s4) and stage.get_child_count() == 0, "swap: both gone")

	# ---- 4. fx min: 120 ms fades in place, no slide; the static snapshot stays
	V10Hud2Util.fx_override = "min"
	var s5: = V10SilkSheet.open(stage, _content(), 400)
	var n5: = _counter(s5)
	var y5: = vs.y - 400.0
	_ok(_near(s5.panel.position.y, y5) and s5.panel.modulate.a == 0.0, "min: sheet in place, transparent")
	_ok(s5.blurred, "min: blurred snapshot kept")
	var t5: = s5.tween()
	t5.pause()
	t5.custom_step(0.06)
	_ok(_near(s5.panel.position.y, y5) and s5.panel.modulate.a > 0.3 and s5.panel.modulate.a < 1.0, "min: fades, does not slide")
	t5.custom_step(0.058)
	_ok(n5[0] == 0, "min: not open at 118 ms")
	t5.custom_step(0.004)
	_ok(n5[0] == 1 and s5.panel.modulate.a == 1.0, "min: open at 120 ms")
	s5.close()
	var t5c: = s5.tween()
	t5c.pause()
	t5c.custom_step(0.06)
	_ok(_near(s5.panel.position.y, y5), "min: close does not slide")
	t5c.custom_step(0.058)
	_ok(n5[1] == 0, "min: not closed at 118 ms")
	t5c.custom_step(0.004)
	_ok(n5[1] == 1, "min: closed at 120 ms")
	await tree.process_frame
	_ok(not is_instance_valid(s5), "min: freed")
	V10Hud2Util.fx_override = "mid"
	var s5m: = V10SilkSheet.open(stage, _content(), 400)
	_ok(_near(s5m.panel.position.y, vs.y), "mid: slides like full")
	s5m.tween().custom_step(1.0)
	s5m.close()
	s5m.tween().custom_step(1.0)
	await tree.process_frame
	V10Hud2Util.fx_override = "full"

	# ---- 5. edge cases
	# host freed mid-animation: no error, closed once, snapshot released
	var h6: = Control.new()
	h6.position = Vector2(100, 50)  # an offset host: the sheet still covers the viewport
	stage.add_child(h6)
	var s6: = V10SilkSheet.open(h6, _content(), 400)
	var n6: = _counter(s6)
	_ok(s6.global_position == Vector2.ZERO, "offset host: sheet at the viewport origin")
	var wr6: = weakref(s6.snapshot)
	s6.tween().custom_step(0.1)
	h6.queue_free()
	await tree.process_frame
	_ok(not is_instance_valid(s6) and n6[1] == 1, "host freed mid-open: closed once")
	_ok(wr6.get_ref() == null and V10SilkSheet.current() == null, "host freed: texture released, current() cleared")
	# close() before the sheet is in the tree (host not in the tree yet)
	var orphan: = Control.new()
	var s7: = V10SilkSheet.open(orphan, _content(), 400)
	var n7: = _counter(s7)
	_ok(s7.state == "new" and V10SilkSheet.captures == cap0 + 5, "orphan host: nothing happens yet")
	s7.close()
	_ok(n7[1] == 1 and n7[0] == 0, "close before ready: closed, never opened")
	orphan.free()
	await tree.process_frame
	_ok(not is_instance_valid(s7), "close before ready: freed")
	# a failed readback (null / empty image) → the flat tone; the capture watchdog opens on the flat tone
	V10SilkSheet.sim_frame = null
	var s11: = V10SilkSheet.open(stage, _content(), 400)
	var n11: = _counter(s11)
	if s11.state == "capturing":
		await RenderingServer.frame_post_draw
	s11._take(null, Time.get_ticks_usec())
	_ok(not s11.blurred and _near(s11.tone_rect.color.a, 0.72, 0.001) and not s11.snap_rect.visible, "failed readback (null) → flat tone")
	s11._take(Image.new(), Time.get_ticks_usec())
	_ok(not s11.blurred and s11.snapshot == null, "failed readback (empty) → flat tone")
	s11.tween().kill()
	s11.state = "capturing"  # as if frame_post_draw never came
	tree.process_frame.connect(s11._on_capture_tick)
	for i in 3:
		await tree.process_frame
	_ok(s11.state == "capturing", "watchdog waits 3 frames")
	await tree.process_frame
	_ok(s11.state == "opening" and s11.tween() != null and not s11.blurred, "capture watchdog → opens on the flat tone")
	_ok(not tree.process_frame.is_connected(s11._on_capture_tick), "watchdog disconnects (nothing per frame)")
	s11.state = "open"
	s11._on_capture_tick()
	_ok(s11.state == "open", "watchdog is a no-op once open")
	s11.close()
	s11.tween().custom_step(1.0)
	_ok(n11[1] == 1, "watchdog sheet closes")
	await tree.process_frame
	V10SilkSheet.sim_frame = _split_image(720, 1280)
	# height clamp and the 24 px minimum, safe inset under the sheet
	V10Hud2Util.sim_insets = {"top": 48.0, "bottom": 24.0}
	var s8: = V10SilkSheet.open(stage, _content(), 5000)
	s8.tween().custom_step(1.0)
	_ok(s8.panel.position.y >= 48.0 + 88.0 - 0.5, "tall sheet keeps the top band (%.0f)" % s8.panel.position.y)
	_ok(_near(s8.panel.position.y + s8.panel.size.y, vs.y), "sheet sits on the bottom edge")
	s8.close()
	s8.tween().custom_step(1.0)
	var c9: = _content()
	var other: = Control.new()
	stage.add_child(other)
	other.add_child(c9)
	var s9: = V10SilkSheet.open(stage, c9, 472)
	_ok(c9.get_parent() == s9.panel, "content is moved into the sheet")
	_ok(_near(s9.panel.size.y, 472.0 + 24.0), "bottom safe inset added under the sheet")
	_ok(_near(c9.size.y, 472.0 - 24.0 - 24.0), "content keeps the bottom padding above the inset")
	s9.tween().custom_step(1.0)
	var back: Callable = s9.get_meta("v8_back")
	back.call()
	_ok(s9.state == "closing", "Android back closes the sheet")
	s9.tween().custom_step(1.0)
	var s10: = V10SilkSheet.open(stage, null, 10)
	_ok(_near(s10.visible_h(), 56.0), "tiny height → 56 (padding)")
	s10.close()
	s10.tween().custom_step(1.0)
	other.queue_free()
	await tree.process_frame
	V10Hud2Util.sim_insets = {"top": 0.0, "bottom": 0.0}

	# ---- 6. source hygiene: colours only from V10DS
	var needles: = ["Color(" + "\"#", "Color(" + "0.", "Color(" + "1."]
	for p in ["res://scripts/v10/hudfx/silk_sheet.gd", "res://scripts/v10/hudfx/demo/silk_sheet_demo.gd", "res://scripts/v10/hudfx/silk_sheet_selftest.gd"]:
		var src: = FileAccess.get_file_as_string(p)
		var bad: = false
		for nd in needles:
			bad = bad or src.contains(nd)
		_ok(src != "" and not bad, "no colour literals in " + p.get_file())

	# restore
	V10SilkSheet.sim_frame = null
	V10SilkSheet.log_timing = keep_log
	V10Hud2Util.fx_override = keep_fx
	V10Hud2Util.sim_insets = keep_ins
	stage.queue_free()
	await tree.process_frame
	return {"passed": _passed, "failed": _failed, "lines": _lines}
