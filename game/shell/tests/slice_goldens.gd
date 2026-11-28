class_name TWSliceGoldens
extends RefCounted

# P37 / WP10d: the six screens of the vertical slice as pixels.
#
#   godot --path game --rendering-driver opengl3 --resolution 720x1280 --fixed-fps 60 res://shell/main_v11.tscn -- --slice=goldens --slice_out=<dir>
#       -> <dir>/<screen>.png for home, match, result, collection, wish, shop   (+ "SLICE_SHOT <screen> WxH <bytes>" lines)
#   ... -- --slice=tour --slice_out=<dir> [--slice_every=6]
#       -> <dir>/f_00001.png ... one PNG every N frames of a whole round: Home -> Match (real time, bot) -> Result -> Collection -> Wish -> Shop
#
# The comparison against game/tests/goldens/<WxH>/<screen>.png (1.5 % of the pixels may differ) is `tools/slice_goldens.py`: it starts this
# runner once per size (the window size is fixed at launch), compares in numpy and writes the diff sheets. The runner itself only renders
# deterministically: a frozen calendar (V10Meta.set_now), a fresh save, manual timelines (view.manual, modal.advance), --fixed-fps so a
# frame is 1/60 s whatever the machine does.
#
# The match screen is shown with its board only: the HUD (P32) and the hero strip (TWPresence, P34) are not part of the integration
# yet, so these goldens move when they are merged (re-record with `python tools/slice_goldens.py --update`).

const SCREENS: = ["home", "match", "result", "collection", "wish", "shop"]
const FROZEN_UNIX: = 1781524800   # 2026-06-15 12:00:00 UTC: mid-day, not a month edge, not 04:00
const SETTLE_FRAMES: = 48         # a legacy screen's entrance tweens are done well before this (fixed 60 fps)
const MATCH_SEED: = 51

static func _cfg() -> Dictionary:
	return {"cols": 6, "rows": 8, "layers": 3, "fill": 0.7, "faces": 12, "seed": MATCH_SEED, "shape": "rect", "gold": 4, "ice": 0,
		"hidden": false, "shard": "rin", "plan": {}}


var s: TWSlice
var out_dir: = ""
var shots: Array = []


static func run(slice: TWSlice) -> void:
	var g: = TWSliceGoldens.new()
	g.s = slice
	g.out_dir = TWSlice.arg("slice_out", "/tmp/tw_slice_shots")
	DirAccess.make_dir_recursive_absolute(g.out_dir)
	slice.prepare_save(FROZEN_UNIX)
	V10TutState.skip()    # no first-visit spotlight dimming the screens
	G.set_fx_level("min")   # «Эффекты: минимум»: no ambient petals / sparkles: the goldens show the layout, not the particles
	V10Tray.claim_all()   # today's morning tray is taken: Home shows itself, not the claim popup (a fresh profile sees the popup first)
	await slice.h.get_tree().process_frame
	slice.start_dog()
	if TWSlice.arg("slice") == "tour":
		await g._tour()
	else:
		await g._shots()
	V10Meta.clear_now()
	slice.h.get_tree().quit(0 if slice.ok == slice.total else 1)


func capture(path: String) -> Image:
	await RenderingServer.frame_post_draw
	var img: = s.h.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png(path)
	return img


static func _blank(img: Image) -> bool:
	# a screen that rendered nothing is one colour: sample a 24 x 24 grid and count distinct colours
	var seen: = {}
	for yi in 24:
		for xi in 24:
			var c: = img.get_pixel(int((xi + 0.5) * img.get_width() / 24.0), int((yi + 0.5) * img.get_height() / 24.0))
			seen[c.to_html(false)] = true
	return seen.size() < 6


func shot(id: String) -> void:
	s.beat("shot " + id)
	await s.frames(3)
	var p: = out_dir.path_join(id + ".png")
	var img: = await capture(p)
	s.check(img.get_width() > 0 and not _blank(img), "%s: rendered something (%dx%d, not one colour)" % [id, img.get_width(), img.get_height()])
	s.check(Vector2i(img.get_width(), img.get_height()) == Vector2i(DisplayServer.window_get_size()), "%s: the PNG has the window size (%dx%d)" % [id, img.get_width(), img.get_height()])
	print("SLICE_SHOT %s %dx%d %d" % [id, img.get_width(), img.get_height(), FileAccess.get_file_as_bytes(p).size()])
	shots.append(id)


func _legacy(id: String, shot_id: String) -> void:
	seed(4242)   # the micro-motions of the live heroine and the petals draw from the global RNG
	var good: bool = await s.open_legacy(id, SETTLE_FRAMES)
	s.check(good, "%s opens through the host" % id)
	if id == "home":
		_hide_live_heroine()
	await shot(shot_id)


# The live heroine of Home (V10LiveRig: breathing, weight shift, blinks) is not a still: two renders of the same build differ in the phase
# of her idle by a few frames. The golden shows Home without her (the room, the chrome, the plate, the button); her motion is tested by the
# rig suites (`rig10`, `v10live`).
func _hide_live_heroine() -> void:
	var scr: Node = s.h.screen
	if scr == null:
		return
	var hidden: = 0
	for n in scr.find_children("*", "V10LiveRig", true, false):
		(n as CanvasItem).visible = false
		hidden += 1
	var hero: Variant = scr.get("hero")
	if hero is CanvasItem and (hero as CanvasItem).visible:
		(hero as CanvasItem).visible = false
		hidden += 1
	s.check(hidden > 0, "home: the live heroine node was found and hidden for the golden (%d)" % hidden)


func _won_match(wins_before: int) -> TWMatchScreen:
	var facts: = {"wins_before": wins_before, "partner": "rin", "chapter_has_3star": true}
	return await s.go_match({"cfg": _cfg(), "tile_size": "L",
		"result_facts": facts, "round_state": {"partner": "rin"}})


func _shots() -> void:
	# 1. Home
	await _legacy("home", "home")
	# 2. a round half way: the same 14 solver taps every time
	var m: = await _won_match(5)
	s.check(m != null, "the match screen mounts")
	if m != null:
		for i in 14:
			var id: = m.board.solver_move()
			if id < 0:
				break
			m.tap_tile(id)
			m.view.advance(0.05)
		m.view.finish()
		await shot("match")
		await s.leave_match()
	# 3. a won round: the fast shape of the victory modal 1.6 s in (the button is up)
	m = await _won_match(5)
	if m != null:
		var guard: = 0
		while not m.ended and guard < 400:
			guard += 1
			var id2: = m.board.solver_move()
			if id2 < 0:
				break
			m.tap_tile(id2)
			m.view.advance(0.05)
		m.view.finish()
		s.check(m.result_modal != null, "the round was won and the modal is open")
		if m.result_modal != null:
			m.result_modal.advance(1.6)
		await shot("result")
		m.result_modal.cta.pressed.emit()   # the way on, like a finger: the modal leaves the stack before Collection opens
		await s.frames(2)
		await s.leave_match()
		s.check(s.h.modals.depth() == 0, "result: the modal layer is empty after the button")
	# 4-6. Collection, Wish, Shop
	await _legacy("collection", "collection")
	await _legacy("summon", "wish")
	await _legacy("shop", "shop")
	s.check(shots.size() == SCREENS.size(), "all %d screens were shot (%s)" % [SCREENS.size(), str(shots)])
	print("SLICE_SELFTEST %d/%d" % [s.ok, s.total])


# ---- the tour: every N-th frame of one whole round, for the contact sheet / video ------------------------------------------------

var _n: = 0
var _every: = 6


func _tick() -> void:
	_n += 1
	s.last_beat_ms = Time.get_ticks_msec()   # a drawn frame is an event for the watchdog
	if _n % _every == 0:
		var img: = s.h.get_viewport().get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		img.save_png(out_dir.path_join("f_%05d.png" % (_n / _every)))


func _tour_frames(n: int) -> void:
	for i in n:
		await s.h.get_tree().process_frame
		await RenderingServer.frame_post_draw
		_tick()


func _tour() -> void:
	_every = maxi(1, int(TWSlice.arg("slice_every", "6")))
	await _tour_frames(30)
	await s.h.open("home", {})
	await _tour_frames(70)
	var facts: = {"wins_before": 5, "partner": "rin", "chapter_has_3star": true}
	s.hide_legacy(true)
	await s.h.tw_screens.go("match", {"cfg": _cfg(), "tile_size": "L",
		"result_facts": facts, "round_state": {"partner": "rin"}})
	var m: = s.h.tw_screens.current as TWMatchScreen
	if m == null:
		s.check(false, "tour: the match screen mounts")
		return
	await _tour_frames(40)
	var guard: = 0
	while not m.ended and guard < 300:
		guard += 1
		var id: = m.board.solver_move()
		if id < 0:
			break
		m.tap_tile(id)
		await _tour_frames(7)   # the real timeline (lift, flight, tray arc) plays between the taps
	await _tour_frames(150)
	if m.result_modal != null:
		await _tour_frames(20)
		m.result_modal.cta.pressed.emit()
	await _tour_frames(10)
	await s.leave_match()
	for id in ["collection", "summon", "shop"]:
		await s.h.open(id, {})
		await _tour_frames(60)
	s.check(_n > 100, "tour: %d frames recorded" % _n)
	print("SLICE_TOUR frames=%d every=%d" % [_n / _every, _every])
	print("SLICE_SELFTEST %d/%d" % [s.ok, s.total])
