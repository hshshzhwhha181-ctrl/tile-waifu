class_name V9UltSelftest
extends RefCounted

# Live ult checks on a real play screen (docs/0.9-spec.md §B). One heroine per run:
#   godot --headless --path . -- --screen=play --level=3 --partner=<hero> [--outfit=<id>] [--mode=blitz] --v9_ult_selftest=1
# prints «ULT SELFTEST <hero> n/m» and quits with 1 on a failure. Checks: charge rules on the screen, every core
# (auto-target, from_ult pairs, nothing charges, combo untouched, board handed back), aiming by a real touch
# (pair / tier / swipe / row), the 2 s auto-target, a skipped full clip (strong still fires), and a short clip
# buffering a tap and replaying it.

static var ok_n: = 0
static var bad_n: = 0


static func _check(name: String, cond: bool, info: = "") -> void :
	if cond:
		ok_n += 1
	else:
		bad_n += 1
		print("  FAIL ", name, (" (" + info + ")") if info != "" else "")


static func _wait(play, s: float) -> void :
	await play.get_tree().create_timer(s).timeout


static func _touch(play, at: Vector2, pressed: bool) -> void :
	var e: = InputEventScreenTouch.new()
	e.position = at
	e.pressed = pressed
	play.get_viewport().push_input(e, true)


static func _drag(play, at: Vector2, rel: Vector2) -> void :
	var e: = InputEventScreenDrag.new()
	e.position = at
	e.relative = rel
	play.get_viewport().push_input(e, true)


static func _counter(play) -> Array:
	var box: = [0, 0]
	play.board.matched.connect( func(_m, _c, _g, _s):
		if play.v9_from_ult:
			box[0] += 1
		else:
			box[1] += 1)
	return box


static func _prime(play, ult: V9UltCast) -> void :
	play.skill_charge = play.SKILL_NEED
	play._skill_ready()
	ult.force_auto = true
	ult.force_mode = "off"


static func run(play) -> void :
	ok_n = 0
	bad_n = 0
	while play.is_inside_tree() and not play.board.input_on:
		await _wait(play, 0.05)
	await _wait(play, 0.3)
	var ult: V9UltCast = play.ult
	var hero: String = play.partner
	var bd: TrayBoard = play.board
	var ranked: = V9UltCast.is_ranked(String(play.mode))
	print("ULT SELFTEST start hero=%s outfit=%s mod=%s ranked=%s" % [hero, ult.id, ult.mod, ranked])
	_check("need on screen", play.SKILL_NEED == V9Ults.need(G.aff_level(hero), ranked), "%d" % play.SKILL_NEED)
	_check("start charge", play.skill_charge == clampi(V9Ults.start_charge_for(ult.id, ranked), 0, play.SKILL_NEED - 1), "%d" % play.skill_charge)
	_check("ranked: no modifier", not ranked or ult.mod == "")
	_check("stage reads ульта", play.stage.gauge_lbl == null or play.stage.gauge_lbl.text.begins_with("ульта") or play.stage.gauge_lbl.text.begins_with("УЛЬТА"), play.stage.gauge_lbl.text if play.stage.gauge_lbl else "")

	# ── 1. core with the auto-target, no clip ──
	if hero == "rin":
		var fr: = bd.free_tiles()
		var used: = {}
		for t in fr:
			if not used.has(t.face) and bd.tray.size() < 2:
				used[t.face] = true
				bd.tap(t)
		await _wait(play, 0.5)
	var box: = _counter(play)
	var count0: = bd.board_count()
	var tray0: = bd.tray.size()
	var closed0: = ult.closed_tiles().size()
	var combo0: = bd.combo
	_prime(play, ult)
	_check("ready", play.skill_ready)
	await play._use_skill()
	await _wait(play, 0.7)
	var want_pairs: = 0
	match hero:
		"mc", "nova":
			want_pairs = 1
		"hana":
			want_pairs = 1 if ranked else 2
		"rin":
			want_pairs = 0 if tray0 > 0 else 1
	_check("from_ult pairs = core", box[0] == want_pairs, "got %d want %d" % [box[0], want_pairs])
	_check("no plain pairs", box[1] == 0, "%d" % box[1])
	_check("ult pairs do not charge", play.skill_charge == 0 and not play.skill_ready, "%d" % play.skill_charge)
	_check("combo untouched", bd.combo == combo0, "%d -> %d" % [combo0, bd.combo])
	_check("board handed back", bd.input_on and not ult.busy and not play.get_meta("v6_casting", false))
	match hero:
		"rin":
			_check("rin: tray back on the table", bd.tray.is_empty(), "tray %d" % bd.tray.size())
			if tray0 > 0:
				_check("rin: tiles returned", bd.board_count() == count0 + tray0, "%d -> %d (+%d)" % [count0, bd.board_count(), tray0])
		"yue":
			_check("yue: nothing closed", ult.closed_tiles().is_empty(), "%d -> %d" % [closed0, ult.closed_tiles().size()])
		_:
			var gone: = count0 - bd.board_count()
			# В returns a tray tile to the table (+1)
			_check("tiles removed", gone == want_pairs * 2 or (ult.mod == "В" and gone == want_pairs * 2 - 1), "%d" % gone)

	# ── 2. aim with a real touch ──
	box[0] = 0
	_prime(play, ult)
	ult.force_auto = false
	var target: = String(ult.core.get("target", "none"))
	var expect: Array = []
	play._use_skill()
	await _wait(play, 0.15)
	_check("aiming (%s)" % target, ult.aiming == (target != "none"))
	match target:
		"pair":
			# a pair whose tile is the topmost at its spot (a touch hits what is on top)
			var ps: = ult.pairs().filter( func(pr): return bd.tile_at(V9UltCast.pos_of(pr[0])) == pr[0])
			if not ps.is_empty():
				expect = ps.back()
				var at: = V9UltCast.pos_of(expect[0])
				_touch(play, at, true)
				_touch(play, at, false)
		"tier":
			var ps: = ult.pairs()
			var top: = ps.filter( func(pr): return bd.tile_at(V9UltCast.pos_of(pr[0])) == pr[0])
			if not top.is_empty():
				var t: Tile = top[0][0]
				var gz: = t.gz
				var cand: = ps.filter( func(pr): return pr[0].gz == gz or pr[1].gz == gz)
				expect = cand.back()
				_touch(play, V9UltCast.pos_of(t), true)
				_touch(play, V9UltCast.pos_of(t), false)
		"swipe":
			var br: Rect2 = play.board_rect
			var a: = Vector2(br.position.x + 30, br.get_center().y)
			var b: = Vector2(br.end.x - 30, br.get_center().y)
			_touch(play, a, true)
			_drag(play, (a + b) * 0.5, (b - a) * 0.5)
			_drag(play, b, (b - a) * 0.5)
			_touch(play, b, false)
		"row":
			var y: = (play.board_rect as Rect2).get_center().y
			_touch(play, Vector2(play.board_rect.position.x + 40, y), true)
			_drag(play, Vector2(play.board_rect.end.x - 40, y), Vector2(300, 0))
			_touch(play, Vector2(play.board_rect.end.x - 40, y), false)
	var t0: = Time.get_ticks_msec()
	while ult.busy and Time.get_ticks_msec() - t0 < 6000:
		await _wait(play, 0.05)
	await _wait(play, 0.6)
	var aim_ms: = Time.get_ticks_msec() - t0
	_check("aim answered by the touch (< 1.5 s)", target == "none" or aim_ms < 1500 + 700, "%d ms" % aim_ms)
	if not expect.is_empty():
		_check("aimed pair removed", not expect[0].alive and not expect[1].alive)
	_check("cast done after aim", not ult.busy and bd.input_on)

	# ── 3. no touch: the 2 s auto-target ──
	if target != "none" and not ult.pairs().is_empty():
		_prime(play, ult)
		ult.force_auto = false
		t0 = Time.get_ticks_msec()
		play._use_skill()
		while ult.busy and Time.get_ticks_msec() - t0 < 6000:
			await _wait(play, 0.05)
		var ms: = Time.get_ticks_msec() - t0
		_check("auto-target after %.1f s" % V9Ults.TARGET_TIME, ms >= int(V9Ults.TARGET_TIME * 1000) - 100 and ms < 4000, "%d ms" % ms)
		await _wait(play, 0.5)

	# ── 4. full clip, skipped at once: strong still fires, control back quickly ──
	if ult.blocked() == "":
		_prime(play, ult)
		ult.force_mode = "full"
		box[0] = 0
		play._use_skill()
		await play.get_tree().process_frame
		await play.get_tree().process_frame
		var cut: V9Cutin = null
		for c in play.get_children():
			if c is V9Cutin:
				cut = c
		_check("full clip shown", cut != null)
		t0 = Time.get_ticks_msec()
		if cut:
			_check("clip length", absf(cut.L - V9Ults.clip_len(cut.rar, cut.hero, "full")) < 0.01, "%.2f" % cut.L)
			cut.skip()
		while ult.busy and Time.get_ticks_msec() - t0 < 4000:
			await _wait(play, 0.02)
		var ms2: = Time.get_ticks_msec() - t0
		_check("skip returns control fast", ms2 < 700, "%d ms" % ms2)
		await _wait(play, 0.6)
		_check("skip: effect still applied", hero in ["rin", "yue"] or box[0] > 0, "%d" % box[0])

	# ── 5. short clip: ≤ 0.6 s and a tap during it is replayed on the board ──
	if ult.blocked() == "":
		_prime(play, ult)
		ult.force_mode = "short"
		t0 = Time.get_ticks_msec()
		play._use_skill()
		await play.get_tree().process_frame
		await play.get_tree().process_frame
		var fr2: = bd.free_tiles().filter( func(t): return not bd.tray.any( func(x): return x.face == t.face))
		var tapped: Tile = fr2[0] if not fr2.is_empty() else null
		var cut2: V9Cutin = null
		for c in play.get_children():
			if c is V9Cutin:
				cut2 = c
		if cut2 and tapped:
			cut2.buffered.append(V9UltCast.pos_of(tapped))
		while ult.busy and Time.get_ticks_msec() - t0 < 4000:
			await _wait(play, 0.02)
		var ms3: = Time.get_ticks_msec() - t0
		_check("short clip ≤ 0.6 s (+frame slack)", ms3 <= 600 + 250, "%d ms" % ms3)
		await _wait(play, 0.4)
		if tapped:
			_check("buffered tap replayed", bd.tray.has(tapped) or not tapped.alive or tapped.pending)

	print("ULT SELFTEST %s %d/%d" % [hero, ok_n, ok_n + bad_n])
	play.get_tree().quit(1 if bad_n > 0 else 0)
