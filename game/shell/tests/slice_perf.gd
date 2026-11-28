class_name TWSlicePerf
extends RefCounted

# P37 / WP10d: frame budget of the match screen at 60+ tiles, through the screen API.
#
#   godot --path game [--headless | --rendering-driver opengl3] --resolution 720x1280 res://shell/main_v11.tscn -- --slice=perf
#   prints  SLICE_PERF {json}   and   SLICE_SELFTEST ok/total   (tools/perf_budget.py runs both profiles and writes docs/qa/PERF_BUDGET.md)
#
# What is measured, per frame of a live round (a bot taps every 7th frame, so the timeline - lift, pair flight, tray arc, settle, sparks -
# is always running):
#   cost   advance() of the view + the script time of its draw list (`last_draw_us`)   = the part of the frame this code owns
#   wall   the real frame-to-frame time of the process                                  = includes the rasteriser
# The acceptance line is p95(cost) <= 16.6 ms. `wall` on this box is the software rasteriser (llvmpipe) and says nothing about a phone: the
# device frame time is the owner's M2 check (the report says "device not verified").

const FRAME_LIMIT_MS: = 16.6
const MIN_TILES: = 60
const MAX_FRAMES: = 900
const HOME_FRAMES: = 180

var s: TWSlice


static func run(slice: TWSlice) -> void:
	var p: = TWSlicePerf.new()
	p.s = slice
	var boot_ms: = Time.get_ticks_msec()
	slice.prepare_save()
	await slice.h.get_tree().process_frame
	slice.start_dog()
	await p._measure(boot_ms)
	slice.h.get_tree().quit(0 if slice.ok == slice.total else 1)


static func pct(a: Array, q: float) -> float:
	if a.is_empty():
		return 0.0
	var b: = a.duplicate()
	b.sort()
	return float(b[mini(b.size() - 1, int(float(b.size()) * q))])


func _board_cfg() -> Dictionary:
	# 6 x 8 x 3 at fill 0.7 is a 60+ tile board with gold / ice / specials: the heaviest ordinary Path level
	return {"cols": 6, "rows": 8, "layers": 3, "fill": 0.7, "faces": 12, "seed": 60, "shape": "rect", "gold": 4, "ice": 2, "hidden": true,
		"shard": "rin", "plan": {"lock": 1, "lock_n": 1, "chain": 1, "joker": 1, "bomb": 1, "gift": 1}}


func _measure(boot_ms: int) -> void:
	var h: = s.h
	var tree: = h.get_tree()
	var headless: = DisplayServer.get_name() == "headless"
	# Home idle (the legacy screen the slice starts on): wall frame only
	s.beat("home idle")
	var hw: Array = []
	var last: = Time.get_ticks_usec()
	for i in HOME_FRAMES:
		await tree.process_frame
		s.last_beat_ms = Time.get_ticks_msec()
		var now: = Time.get_ticks_usec()
		if i > 20:
			hw.append(float(now - last) / 1000.0)
		last = now
	# the match round
	s.beat("match perf")
	s.hide_legacy(true)
	await h.tw_screens.go("match", {"cfg": _board_cfg(), "tile_size": "M", "show_result": false})
	var m: = h.tw_screens.current as TWMatchScreen
	s.check(m != null, "perf: the match screen mounts through TWScreens.go")
	if m == null:
		return
	var b: = m.board
	var v: = m.view
	s.check(b.n >= MIN_TILES, "perf: the board has %d >= %d tiles" % [b.n, MIN_TILES])
	var cost: Array = []
	var wall: Array = []
	var draws0: int = v.draws
	v.deal_in()
	last = Time.get_ticks_usec()
	var frame_no: = 0
	while frame_no < MAX_FRAMES:
		frame_no += 1
		s.beat("match perf frame %d" % frame_no)
		var t0: = Time.get_ticks_usec()
		if frame_no % 7 == 0 and not b.cleared and not b.failed:
			var id: = b.solver_move()
			if id >= 0:
				m.tap_tile(id)
		v.advance(1.0 / 60.0)
		var adv: = Time.get_ticks_usec() - t0
		await tree.process_frame
		var now2: = Time.get_ticks_usec()
		wall.append(float(now2 - last) / 1000.0)
		last = now2
		cost.append(float(adv + v.last_draw_us) / 1000.0)
		if b.cleared and v.idle_now() and frame_no > 60:
			break
	var drew: int = v.draws - draws0
	var vp: = h.get_viewport().get_visible_rect().size
	var r: = {
		"tiles": b.n, "frames": cost.size(), "headless": headless, "renderer": "dummy" if headless else RenderingServer.get_video_adapter_name(),
		"size": "%dx%d" % [int(vp.x), int(vp.y)],
		"cost_p50_ms": snappedf(pct(cost, 0.5), 0.01), "cost_p95_ms": snappedf(pct(cost, 0.95), 0.01), "cost_max_ms": snappedf(pct(cost, 1.0), 0.01),
		"wall_p50_ms": snappedf(pct(wall, 0.5), 0.1), "wall_p95_ms": snappedf(pct(wall, 0.95), 0.1),
		"home_wall_p50_ms": snappedf(pct(hw, 0.5), 0.1), "home_wall_p95_ms": snappedf(pct(hw, 0.95), 0.1),
		"draws": drew, "boot_to_ready_ms": boot_ms, "cleared": b.cleared, "limit_ms": FRAME_LIMIT_MS}
	print("SLICE_PERF ", JSON.stringify(r))
	s.check(cost.size() >= 100, "perf: %d frames measured" % cost.size())
	s.check(drew >= cost.size() / 2 or headless, "perf: the frames really drew the view (%d draws in %d frames)" % [drew, cost.size()])
	s.check(float(r.cost_p95_ms) <= FRAME_LIMIT_MS, "perf: view cost p95 %.2f ms <= %.1f ms at %d tiles (%s)" % [float(r.cost_p95_ms), FRAME_LIMIT_MS, b.n, "headless profile" if headless else "software GL; device not verified"])
	await s.leave_match()
	print("SLICE_SELFTEST %d/%d" % [s.ok, s.total])
