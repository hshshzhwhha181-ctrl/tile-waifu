class_name TWBoardViewSelftest
extends RefCounted

# P31 / WP10a selftest of TWBoardView + TWMatchScreen:  godot --path game res://shell/screens/match/board_view_selftest.tscn
# Prints "TWBOARDVIEW_SELFTEST ok/total". Needs a display for section F (tools/tw_test.py runs it under xvfb).
#   A layout     field >= 92% of the width and >= 60% of the height, tile 56 / 64 / 72 / 80 at base 720 (S/M/L/XL) and >= 64 for M on
#                3 aspects, tray under the field, pure function
#   B events     all 20 core events have an animation (EVENT_ANIM == TWBoardEvents.ALL); every event type met in 100 real games
#                scheduled clips; every type on a synthetic batch too; the six acceptance events (MATCH, DENY, ICE_CRACK, TRAY_WARN,
#                TRAY_FULL, CLEARED) were all met in real games
#   C timeline   lift 90 ms, pair flight 180 ms, tray arc 160 ms, settle 40 ms, deny shake 120 ms (read off the scheduled clips)
#   D outcome    100 games, the same moves on two identical boards, one with a view (random frame steps 0 .. 0.3 s): every move gives
#                the same events and the same state hash with and without the view, the same outcome; after finish() the view mirror
#                equals the board (tile places, tray order, faces, ice, secret, free / blocked)
#   E input      press lifts the tile in the same frame, release emits tile_tapped, a covered tile is not picked, a drag off cancels
#   F render     720 x 1280 screenshot: plate contrast against the table >= 4.5:1 (free and blocked), blocked >= 65% of the free
#                brightness (GDD 7.2), measured from the pixels
#   G perf       60+ tiles, frames with a live timeline: frame time p95 <= 16.6 ms (headless profile, includes the draw)
#   H screen     TWScreens.scan finds `match`, go("match") mounts it, taps through the screen API publish the events on ctx.bus,
#                round_ended fires once
#   I lint       board_view.gd calls no board operation that changes the board, has no res://assets literal, no raw hex, no Input

const FRAME_LIMIT_MS: = 16.6
const GAMES_DEFAULT: = 100
const REQUIRED: = ["MATCH", "DENY", "ICE_CRACK", "TRAY_WARN", "TRAY_FULL", "CLEARED"]
const SCREENS: = [
	["720x1280", Vector2(720, 1280), {"top": 0, "bottom": 0}],
	["720x1600", Vector2(720, 1600), {"top": 48, "bottom": 24}],
	["1536x2048", Vector2(1536, 2048), {"top": 24, "bottom": 16}],
]

var GAMES: = GAMES_DEFAULT                  # --games_n=N (tools/tw_test.py --fast uses 40)
var checks: = 0
var fails: = 0
var _host: Node
var _seen: Dictionary = {}             # event type -> count in the 100 games
var _min_clips: Dictionary = {}        # event type -> the fewest clips any occurrence scheduled
var _info: Array = []


func ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("TWBOARDVIEW FAIL: ", what)


func note(s: String) -> void:
	_info.append(s)
	print("TWBOARDVIEW ", s)


func run(host: Node) -> Array:
	_host = host
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--games_n="):
			GAMES = maxi(10, int(a.substr(10)))
	TWAssets.quiet = true
	TWDraw.sim_insets = {"top": 0, "bottom": 0}
	_layout()
	await _games()
	_synthetic()
	_events_summary()
	await _input()
	await _render()
	await _perf()
	await _screen()
	_lint()
	TWDraw.sim_insets = {}
	print("TWBOARDVIEW_SELFTEST %d/%d" % [checks - fails, checks])
	return [checks - fails, checks]


static func _cfg(seed_: int, extra: Dictionary = {}) -> Dictionary:
	var c: = {"cols": 6, "rows": 8, "layers": 3, "fill": 0.7, "faces": 12, "seed": seed_, "shape": "rect", "gold": 4, "ice": 2,
		"hidden": true, "shard": "rin", "plan": {"lock": 1, "lock_n": 1, "chain": 1, "joker": 1, "bomb": 1, "gift": 1}}
	for k in extra:
		c[k] = extra[k]
	return c


# ------------------------------------------------------------------ A layout

func _layout() -> void:
	var b: = TWBoard.from_cfg(_cfg(3, {"plan": {}}))
	for sc in SCREENS:
		var nm: String = sc[0]
		var vs: Vector2 = sc[1]
		var ins: Dictionary = sc[2]
		var g: = TWBoardView.compute(vs, ins, b.pos, b.slots, "M")
		var f: Rect2 = g.field
		var tr: Rect2 = g.tray
		ok(f.size.x >= vs.x * 0.92 - 0.01, "%s field width %.1f >= 92%% of %.0f" % [nm, f.size.x, vs.x])
		ok(f.size.y >= vs.y * 0.60 - 0.01, "%s field height %.1f >= 60%% of %.0f" % [nm, f.size.y, vs.y])
		ok(f.position.x >= 0.0 and f.end.x <= vs.x + 0.01 and f.position.y >= float(ins.top) - 0.01, "%s field inside the screen and the top inset" % nm)
		ok(tr.position.y >= f.end.y - 0.01 and tr.end.y <= vs.y - float(ins.bottom) + 0.01 and not tr.intersects(f), "%s tray under the field, on screen, not over it" % nm)
		var bp: Rect2 = g.board_px
		ok(bp.position.x >= f.position.x - 0.5 and bp.end.x <= f.end.x + 0.5 and bp.position.y >= f.position.y - 0.5 and bp.end.y <= f.end.y + 0.5, "%s all tiles inside the field at M" % nm)
		ok(g.fits, "%s a 6 x 8 board fits at M" % nm)
		var k: = vs.x / 720.0
		var last: = 0.0
		for key in TWBoardView.SIZE_KEYS:
			var gg: = TWBoardView.compute(vs, ins, b.pos, b.slots, key)
			var want: float = float(TWBoardView.SIZE_PX[key]) * k
			if gg.fits:
				ok(absf(float(gg.tile_w) - want) < 0.01, "%s %s tile %.2f == %.2f" % [nm, key, gg.tile_w, want])
			ok(float(gg.tile_w) >= last - 0.001 and (not gg.fits or float(gg.tile_w) > last), "%s sizes grow S < M < L < XL (until the board stops fitting)" % nm)
			last = float(gg.tile_w)
			ok(gg.slot_centers.size() == b.slots and gg.tile_centers.size() == b.n, "%s %s slot and tile centres" % [nm, key])
		var m: = TWBoardView.compute(vs, ins, b.pos, b.slots, "M")
		ok(float(m.tile_w) >= 64.0 * k - 0.01, "%s M tile %.1f >= 64 x %.2f" % [nm, m.tile_w, k])
	var g720: = TWBoardView.compute(Vector2(720, 1280), {}, b.pos, b.slots, "M")
	ok(absf(float(g720.tile_w) - 64.0) < 0.01 and absf(float(TWBoardView.compute(Vector2(720, 1280), {}, b.pos, b.slots, "S").tile_w) - 56.0) < 0.01, "720: S = 56, M = 64")
	ok(absf(float(TWBoardView.compute(Vector2(720, 1280), {}, b.pos, b.slots, "L").tile_w) - 72.0) < 0.01 and absf(float(TWBoardView.compute(Vector2(720, 1280), {}, b.pos, b.slots, "XL").tile_w) - 80.0) < 0.01, "720: L = 72, XL = 80")
	ok(TWBoardView.compute(Vector2(720, 1280), {}, b.pos, b.slots, "M").hash() == g720.hash(), "compute is pure (same arguments, same result)")
	# a property run: many boards, M never below 64 at 720 while it fits, 7 slots too
	var small: = 0
	for s in 40:
		var bb: = TWBoard.from_cfg(_cfg(s + 1, {"plan": {}, "slots": 4 + s % 4}))
		var gg2: = TWBoardView.compute(Vector2(720, 1280), {}, bb.pos, bb.slots, "M")
		if float(gg2.tile_w) < 64.0 - 0.01 or not gg2.fits:
			small += 1
		var tc: PackedVector2Array = gg2.slot_centers
		var inside: = true
		for c in tc:
			inside = inside and (gg2.tray as Rect2).grow(1.0).has_point(c)
		if not inside:
			ok(false, "40 boards: slot centres inside the tray (seed %d slots %d)" % [s + 1, bb.slots])
	ok(small == 0, "40 boards (6 cols, 4..7 slots): M tile >= 64 px and fits at 720 (%d too small)" % small)
	var cols11: = TWBoard.from_cfg(_cfg(2, {"cols": 11, "plan": {}}))
	var g11: = TWBoardView.compute(Vector2(720, 1280), {}, cols11.pos, cols11.slots, "XL")
	ok(float(g11.tile_w) > 0.0 and (g11.board_px as Rect2).size.x <= (g11.field as Rect2).size.x + 0.5, "a board wider than the field at XL shrinks to fit (never overflows)")


# ------------------------------------------------------------------ D (+B, C) the games

func _next_op(a: TWBoard, r: RandomNumberGenerator) -> Dictionary:
	if a.cleared:
		return {"op": "end"}
	if a.failed:
		return {"op": "return"} if r.randf() < 0.6 else {"op": "end"}
	var x: = r.randf()
	if x < 0.04:
		return {"op": "undo"}
	if x < 0.06:
		return {"op": "shuffle"}
	if x < 0.065:
		return {"op": "vanish"}
	if x < 0.07:
		return {"op": "moon"}
	if x < 0.14:
		var live: = []
		for i in a.n:
			if a.present[i] == 1:
				live.append(i)
		return {"op": "tap", "id": live[r.randi() % live.size()]} if not live.is_empty() else {"op": "end"}
	if x < 0.30:
		var fr: = a.free_all()
		return {"op": "tap", "id": fr[r.randi() % fr.size()]} if fr.size() > 0 else {"op": "end"}
	var m: = a.solver_move()
	if m < 0:
		var fr2: = a.free_all()
		return {"op": "tap", "id": fr2[r.randi() % fr2.size()]} if fr2.size() > 0 else {"op": "end"}
	return {"op": "tap", "id": m}


func _apply(b: TWBoard, op: Dictionary) -> Array:
	match str(op.op):
		"tap":
			return b.tap(int(op.id))
		"undo":
			return b.undo()
		"shuffle":
			return b.shuffle()
		"return":
			return b.return_tray(3)
		"vanish":
			return b.vanish_pairs(1)
		"moon":
			return b.moonlight()
	return []


func _games() -> void:
	var diverge: = 0
	var bad_mirror: = 0
	var bad_outcome: = 0
	var moves_total: = 0
	var cleared_n: = 0
	var failed_n: = 0
	var first_bad: = ""
	var no_anim: = 0
	var unknown: = 0
	var saw: = {"lift": false, "pair": false, "tray": false, "settle": false, "shake": false, "arc": false}
	var steps_dt: = [0.0, 0.016, 0.05, 0.3]
	for g in GAMES:
		var extra: = {"plan": {}} if g % 2 == 0 else {}
		extra["ice"] = g % 3
		extra["hidden"] = g % 4 != 3
		if g % 5 == 4:
			extra["slots"] = 7
		var cfg: = _cfg(1000 + g, extra)
		var a: = TWBoard.from_cfg(cfg)
		var b: = TWBoard.from_cfg(cfg)
		var v: = TWBoardView.new()
		v.manual = true
		v.bind(b, TWBoardView.SIZE_KEYS[g % 4])
		v.configure(Vector2(720, 1280), {})
		var r: = RandomNumberGenerator.new()
		r.seed = 77 + g
		var dtr: = RandomNumberGenerator.new()
		dtr.seed = 5 + g
		var stuck: = 0
		for step in 500:
			var op: = _next_op(a, r)
			if str(op.op) == "end":
				break
			a.time = float(step) * 0.8
			b.time = a.time
			var ea: = _apply(a, op)
			var eb: = _apply(b, op)
			moves_total += 1
			if str(ea) != str(eb) or a.state_hash() != b.state_hash():
				diverge += 1
				if first_bad == "":
					first_bad = "game %d step %d op %s" % [g, step, str(op)]
			if ea.is_empty():
				stuck += 1
				if stuck > 30:
					break
				continue
			stuck = 0
			v.play(eb)
			for e in eb:
				var ty: = TWBoardEvents.type_of(e)
				_seen[ty] = int(_seen.get(ty, 0)) + 1
				var cn: int = int(v.last_type_clips.get(ty, 0))
				_min_clips[ty] = mini(int(_min_clips.get(ty, 99999)), cn)
			if not v.last_unknown.is_empty():
				unknown += 1
			if v.last_clips == 0:
				no_anim += 1
			_sniff_timing(v, eb, saw)
			var dt: float = steps_dt[dtr.randi() % steps_dt.size()]
			if dt > 0.0:
				v.advance(dt)
			if a.state_hash() != b.state_hash():
				diverge += 1
		v.finish()
		if a.cleared != b.cleared or a.failed != b.failed or a.moves != b.moves or a.state_hash() != b.state_hash():
			bad_outcome += 1
		var mm: = v.mirror_matches_board()
		if not mm.is_empty():
			bad_mirror += 1
			if first_bad == "":
				first_bad = "game %d mirror: %s" % [g, str(mm.slice(0, 3))]
		if b.cleared:
			cleared_n += 1
		if b.failed:
			failed_n += 1
		if not v.idle_now():
			ok(false, "game %d: the timeline drains after finish()" % g)
		v.free()
		if g % 25 == 24:
			await _host.get_tree().process_frame
	ok(diverge == 0, "%d games / %d moves: events and state hash equal with and without a view (%d divergences) %s" % [GAMES, moves_total, diverge, first_bad])
	ok(bad_outcome == 0, "%d games: cleared / failed / moves / hash equal at the end (%d differ)" % [GAMES, bad_outcome])
	ok(bad_mirror == 0, "%d games: the view mirror equals the board after finish() (%d differ) %s" % [GAMES, bad_mirror, first_bad])
	ok(no_anim == 0, "every batch of events scheduled at least one clip (%d batches without)" % no_anim)
	ok(unknown == 0, "no event type without a handler (%d batches)" % unknown)
	ok(cleared_n >= GAMES / 20 and failed_n >= GAMES / 20, "the games end both ways (%d cleared, %d failed)" % [cleared_n, failed_n])
	ok(moves_total >= GAMES * 25, "enough moves played (%d)" % moves_total)
	for k in saw:
		ok(bool(saw[k]), "timeline: %s clip with the GDD duration was scheduled" % k)
	note("games: %d moves, %d cleared, %d failed; event types met: %s" % [moves_total, cleared_n, failed_n, JSON.stringify(_seen)])


# durations of the clips a batch scheduled, read off the view
func _sniff_timing(v: TWBoardView, events: Array, saw: Dictionary) -> void:
	var types: = TWBoardEvents.types(events)
	for it in v._pending:
		var d: float = float(it.d)
		var k: String = str(it.k)
		if k == "move" and absf(d - TWBoardView.T_LIFT) < 1e-6 and types.has("MATCH"):
			saw.lift = true
		elif k == "pair" and absf(d - TWBoardView.T_FLY) < 1e-6:
			saw.pair = true
		elif k == "move" and absf(d - TWBoardView.T_TRAY) < 1e-6 and types.has("TO_TRAY") and float(it.get("arc", 0.0)) > 0.0:
			saw.tray = true
			saw.arc = true
		elif k == "prop" and str(it.p) == "settle" and absf(d - TWBoardView.T_SETTLE) < 1e-6:
			saw.settle = true
		elif k == "prop" and str(it.p) == "shake" and absf(d - TWBoardView.T_SHAKE) < 1e-6 and (types.has("DENY") or types.has("BLOCKED")):
			saw.shake = true


# ------------------------------------------------------------------ B synthetic + summary

func _synthetic() -> void:
	ok(TWBoardView.EVENT_ANIM.size() == TWBoardEvents.ALL.size(), "EVENT_ANIM has %d rows == %d core events" % [TWBoardView.EVENT_ANIM.size(), TWBoardEvents.ALL.size()])
	var missing: = []
	for t in TWBoardEvents.ALL:
		if not TWBoardView.EVENT_ANIM.has(t):
			missing.append(t)
	ok(missing.is_empty(), "every core event type has a described animation: missing %s" % str(missing))
	var b: = TWBoard.from_cfg(_cfg(11))
	var v: = TWBoardView.new()
	v.manual = true
	v.bind(b)
	v.configure(Vector2(720, 1280), {})
	var free_ids: = b.free_tiles()
	var i0: int = free_ids[0]
	var i1: int = free_ids[1] if free_ids.size() > 1 else 1
	var samples: = {
		"MATCH": {"a": i0, "b": i1, "face": 0, "combo": 12, "gold": true, "shard": "", "gift": false, "mid": Vector2.ZERO},
		"TO_TRAY": {"id": i0, "slot": 0, "face": 0},
		"TRAY_WARN": {"left": 1},
		"TRAY_FULL": {"tray": [i0, i1]},
		"CLEARED": {},
		"DENY": {"id": i0, "why": "covered"},
		"BLOCKED": {"id": i0, "kind": "lock"},
		"ICE_CRACK": {"id": i0, "left": 0},
		"REVEAL": {"id": i0},
		"JOKER": {"id": i0, "face": 3},
		"UNLOCK": {"group": 0, "ids": [i0, i1]},
		"UNCHAIN": {"id": i0},
		"UNSTICK": {},
		"GIFT": {"a": i0, "b": i1},
		"BLAST": {"at": [i0, i1], "pairs": [[i0, i1]], "mid": Vector2(100, 100)},
		"UNDO": {"id": i0},
		"RETURN": {"ids": [i0, i1]},
		"SHUFFLE": {"ids": [i0, i1]},
		"VANISH": {"a": i0, "b": i1, "face": 0, "mid": Vector2.ZERO},
		"MOONLIGHT": {"revealed": [i0], "thawed": [i1]},
	}
	var bad: = []
	for t in TWBoardEvents.ALL:
		if not samples.has(t):
			bad.append("no sample for " + t)
			continue
		v.bind(b)
		v.configure(Vector2(720, 1280), {})
		var d: = v.play([TWBoardEvents.make(t, samples[t])])
		if v.last_unknown.size() > 0 or int(v.last_type_clips.get(t, 0)) <= 0 or d <= 0.0:
			bad.append("%s clips=%s dur=%.3f" % [t, v.last_type_clips.get(t, 0), d])
		v.advance(0.05)
		v.finish()
		if not v.idle_now():
			bad.append("%s did not drain" % t)
	ok(bad.is_empty(), "synthetic batch of each of the 20 event types schedules clips, has a duration and drains: %s" % str(bad))
	v.free()


func _events_summary() -> void:
	for t in REQUIRED:
		ok(int(_seen.get(t, 0)) > 0, "required event %s was met in the real games (%d times)" % [t, int(_seen.get(t, 0))])
		ok(int(_min_clips.get(t, 0)) > 0, "required event %s: every occurrence scheduled clips (fewest %d)" % [t, int(_min_clips.get(t, 0))])
	var thin: = []
	for t in _seen:
		if int(_min_clips[t]) <= 0:
			thin.append(t)
	ok(thin.is_empty(), "every event type met in the games scheduled clips each time: %s" % str(thin))
	var types_met: = _seen.size()
	ok(types_met >= 14, "the games met %d of 20 event types" % types_met)


# ------------------------------------------------------------------ E input

func _mouse(pos: Vector2, pressed: bool) -> InputEventMouseButton:
	var e: = InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = pos
	return e


func _input() -> void:
	var b: = TWBoard.from_cfg(_cfg(21, {"plan": {}}))
	var v: = TWBoardView.new()
	v.manual = true
	v.size = Vector2(720, 1280)
	_host.add_child(v)
	v.bind(b)
	v.configure(Vector2(720, 1280), {})
	var got: Array = []
	v.tile_tapped.connect(func(id: int) -> void: got.append(id))
	var fr: = b.free_tiles()
	var id: int = fr[0]
	var c: = v.tile_center(id)
	ok(v.pick(c) == id, "pick: the centre of a free top tile picks it")
	v._gui_input(_mouse(c, true))
	ok(v.p_off[id].y < -1.0, "press lifts the tile at once (same frame): %s" % v.p_off[id])
	v._gui_input(_mouse(c, false))
	ok(got == [id] and v.p_off[id] == Vector2.ZERO, "release over the same tile emits tile_tapped once and drops the lift: %s" % str(got))
	got.clear()
	v._gui_input(_mouse(c, true))
	v._gui_input(_mouse(c + Vector2(0, 400), false))
	ok(got.is_empty() and v.p_off[id] == Vector2.ZERO, "release off the tile cancels the tap")
	# a covered tile is never picked through the tile on top of it
	var covered: = -1
	for i in b.n:
		if b.present[i] == 1 and not b.is_free(i):
			covered = i
			break
	ok(covered >= 0, "the board has a covered tile")
	if covered >= 0:
		var top: = v.pick(v.tile_center(covered))
		ok(top >= 0 and top != covered or b.is_free(top), "pick at a covered tile's centre returns the tile that lies on it (%d) not the covered one (%d)" % [top, covered])
	v.input_enabled = false
	got.clear()
	v._gui_input(_mouse(c, true))
	v._gui_input(_mouse(c, false))
	ok(got.is_empty(), "input_enabled = false: no tap")
	v.input_enabled = true
	# the settle: a tile that gets free lights up after the pair leaves
	var b2: = TWBoard.from_cfg(_cfg(22, {"plan": {}, "ice": 0, "hidden": false, "gold": 0}))
	var v2: = TWBoardView.new()
	v2.manual = true
	v2.bind(b2)
	v2.configure(Vector2(720, 1280), {})
	var dark_before: = 0
	for i in b2.n:
		if not v2.is_lit(i):
			dark_before += 1
	var t_guard: = 0
	while not b2.cleared and not b2.failed and t_guard < 200:
		t_guard += 1
		var m: = b2.solver_move()
		if m < 0:
			break
		v2.play(b2.tap(m))
		v2.advance(0.5)
	v2.finish()
	var lit_n: = 0
	for i in b2.n:
		if b2.present[i] == 1 and v2.is_lit(i):
			lit_n += 1
	ok(dark_before > 0, "the start board has covered (dim) tiles (%d)" % dark_before)
	ok(b2.cleared or b2.failed or lit_n == b2.free_tiles().size(), "after the games every free tile is lit (%d lit)" % lit_n)
	ok(v2.mirror_matches_board().is_empty(), "solver game with 0.5 s frames: mirror equals the board: %s" % str(v2.mirror_matches_board().slice(0, 3)))
	v2.free()
	v.queue_free()
	await _host.get_tree().process_frame


# ------------------------------------------------------------------ F render + contrast

static func _lum(c: Color) -> float:
	var f: = func(x: float) -> float: return x / 12.92 if x <= 0.03928 else pow((x + 0.055) / 1.055, 2.4)
	return 0.2126 * float(f.call(c.r)) + 0.7152 * float(f.call(c.g)) + 0.0722 * float(f.call(c.b))


static func _contrast(a: Color, b: Color) -> float:
	var l1: = _lum(a)
	var l2: = _lum(b)
	return (maxf(l1, l2) + 0.05) / (minf(l1, l2) + 0.05)


static func _luma(c: Color) -> float:
	return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b


func _avg(img: Image, p: Vector2) -> Color:
	var x: = int(p.x)
	var y: = int(p.y)
	var acc: = Color(0, 0, 0, 0)
	var cnt: = 0
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var xx: = clampi(x + dx, 0, img.get_width() - 1)
			var yy: = clampi(y + dy, 0, img.get_height() - 1)
			var px: = img.get_pixel(xx, yy)
			acc += px
			cnt += 1
	return acc / float(cnt)


func _render() -> void:
	var vs: = Vector2i(720, 1280)
	var ctx: = TWContext.for_tests("user://tw_boardview_selftest/")
	var vp: = SubViewport.new()
	vp.size = vs
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_host.add_child(vp)
	var s: = TWMatchScreen.new()
	s.ctx = ctx
	vp.add_child(s)
	s.size = Vector2(vs)
	s.enter({"cfg": _cfg(31, {"plan": {}, "ice": 0, "hidden": false, "gold": 0}), "tile_size": "M"})
	s.view.manual = true
	s.view.configure(Vector2(vs), {})
	s.view.finish()
	await RenderingServer.frame_post_draw
	await _host.get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: = vp.get_texture().get_image()
	var drew: = img != null and img.get_width() == vs.x and img.get_height() == vs.y
	ok(drew, "the screen renders to a %dx%d image (display needed)" % [vs.x, vs.y])
	if not drew:
		vp.queue_free()
		return
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			var dir: String = a.substr(8)
			DirAccess.make_dir_recursive_absolute(dir)
			img.save_png(dir.path_join("boardview_720x1280.png"))
	var v: = s.view
	var bg: = _avg(img, Vector2(6, vs.y * 0.45))
	var free_c: Array = []
	var blocked_c: Array = []
	var free_y: Array = []
	var blocked_y: Array = []
	for i in v.n:
		if v.m_where[i] != 0 or v.vis[i] == 0:
			continue
		var r: = v.tile_rect(i)
		var p: = r.position + Vector2(r.size.x * 0.09, r.size.y * 0.5)
		var covered: = false
		for j in range(i + 1, v.n):
			if v.m_where[j] == 0 and v.vis[j] == 1:
				var rj: = v.tile_rect(j).grow_individual(r.size.x * 0.12, r.size.y * 0.14, r.size.x * 0.12, r.size.y * 0.14)
				if rj.has_point(p):
					covered = true
					break
		if covered:
			continue
		var px: = _avg(img, p)
		if v.is_lit(i):
			free_c.append(px)
		else:
			blocked_c.append(px)
	ok(free_c.size() >= 6 and blocked_c.size() >= 6, "contrast samples: %d free, %d blocked tile plates visible" % [free_c.size(), blocked_c.size()])
	if free_c.size() < 1 or blocked_c.size() < 1:
		vp.queue_free()
		return
	var f_min: = 99.0
	var b_min: = 99.0
	var f_y: = 0.0
	var b_y: = 0.0
	var f_l: = 0.0
	var b_l: = 0.0
	for c in free_c:
		f_min = minf(f_min, _contrast(c, bg))
		f_y += _luma(c)
		f_l += _lum(c)
	for c in blocked_c:
		b_min = minf(b_min, _contrast(c, bg))
		b_y += _luma(c)
		b_l += _lum(c)
	f_y /= float(free_c.size())
	b_y /= float(blocked_c.size())
	f_l /= float(free_c.size())
	b_l /= float(blocked_c.size())
	var ratio: = b_y / maxf(f_y, 0.0001)
	var wcag: = (f_l + 0.05) / (b_l + 0.05)
	note("contrast (720x1280 pixels): free plate vs table %.2f:1, blocked plate vs table %.2f:1, blocked/free brightness %.3f, free vs blocked WCAG %.2f:1" % [f_min, b_min, ratio, wcag])
	ok(f_min >= 4.5, "free tile plate vs the table >= 4.5:1 (%.2f)" % f_min)
	ok(b_min >= 4.5, "blocked tile plate vs the table >= 4.5:1 (%.2f)" % b_min)
	ok(ratio >= 0.65, "a blocked tile is not darker than 65%% of a free one (%.3f)" % ratio)
	ok(ratio <= 0.88 and wcag >= 1.25, "free and blocked are told apart: brightness ratio %.3f <= 0.88, WCAG %.2f >= 1.25" % [ratio, wcag])
	# the picture holds more than flat colour: the tile art is there (variance inside a free tile)
	var inside: = s.view.tile_rect(s.board.free_tiles()[0])
	var lo: = 1.0
	var hi_l: = 0.0
	for k in 60:
		var q: = inside.position + Vector2(inside.size.x * (0.2 + 0.6 * float(k % 10) / 9.0), inside.size.y * (0.2 + 0.6 * float(k / 10) / 5.0))
		var l: = _luma(img.get_pixel(int(q.x), int(q.y)))
		lo = minf(lo, l)
		hi_l = maxf(hi_l, l)
	ok(hi_l - lo > 0.15, "a free tile shows its face art (luma spread %.2f)" % (hi_l - lo))
	# the board does not touch the HUD zone: every tile pixel row is inside the field
	var bp: Rect2 = TWBoardView.compute(Vector2(vs), {}, v._pos, v.slots, "M").board_px
	ok(bp.position.y >= v.field.position.y - 0.5 and bp.end.y <= v.field.end.y + 0.5, "the drawn board stays inside the field")
	vp.queue_free()
	await _host.get_tree().process_frame


# ------------------------------------------------------------------ G perf

func _perf() -> void:
	var cfg: = _cfg(41, {"plan": {}, "ice": 2, "hidden": true, "gold": 4, "cols": 5, "rows": 7, "layers": 3})
	var b: = TWBoard.from_cfg(cfg)
	var tries: = 0
	while b.n < 60 and tries < 20:
		tries += 1
		cfg["seed"] = 41 + tries
		b = TWBoard.from_cfg(cfg)
	ok(b.n >= 60, "perf board has %d >= 60 tiles" % b.n)
	var vp: = SubViewport.new()
	vp.size = Vector2i(720, 1280)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_host.add_child(vp)
	var v: = TWBoardView.new()
	v.manual = true
	v.size = Vector2(720, 1280)
	vp.add_child(v)
	v.bind(b)
	v.configure(Vector2(720, 1280), {})
	await _host.get_tree().process_frame
	var frames: Array = []
	var wall: Array = []
	var adv_us: Array = []
	var last: = Time.get_ticks_usec()
	var guard: = 0
	var frame_no: = 0
	var draws0: = v.draws
	v.deal_in()
	while guard < 900:
		guard += 1
		frame_no += 1
		var t0: = Time.get_ticks_usec()
		if frame_no % 7 == 0 and not b.cleared and not b.failed:
			var m: = b.solver_move()
			if m >= 0:
				v.play(b.tap(m))
		v.advance(1.0 / 60.0)
		var adv_t: = Time.get_ticks_usec() - t0
		await _host.get_tree().process_frame
		var now: = Time.get_ticks_usec()
		wall.append(float(now - last) / 1000.0)
		last = now
		adv_us.append(adv_t)
		# the frame cost this view owns: the timeline step + building the draw list (the GPU/raster is the device's, P37)
		frames.append(float(adv_t + v.last_draw_us) / 1000.0)
		if b.cleared and v.idle_now() and guard > 60:
			break
	frames.sort()
	adv_us.sort()
	var p95: float = frames[int(float(frames.size()) * 0.95)]
	var p50: float = frames[frames.size() / 2]
	var mx: float = frames[frames.size() - 1]
	var adv95: float = float(adv_us[int(float(adv_us.size()) * 0.95)]) / 1000.0
	wall.sort()
	note("perf %d tiles, %d frames: view cost (advance + draw list) p50 %.2f ms, p95 %.2f ms, max %.2f ms; advance() p95 %.3f ms; wall frame incl. software raster p50 %.2f ms p95 %.2f ms; %d draws" % [b.n, frames.size(), p50, p95, mx, adv95, wall[wall.size() / 2], wall[int(float(wall.size()) * 0.95)], v.draws - draws0])
	ok(frames.size() >= 100, "perf: %d frames measured" % frames.size())
	ok(v.draws - draws0 >= frames.size() / 2, "perf: the frames really drew the view (%d draws)" % (v.draws - draws0))
	ok(p95 <= FRAME_LIMIT_MS, "perf: view cost p95 %.2f ms <= %.1f ms at %d tiles (script side of a frame; the device is P37)" % [p95, FRAME_LIMIT_MS, b.n])
	vp.queue_free()
	await _host.get_tree().process_frame


# ------------------------------------------------------------------ H screen

func _screen() -> void:
	var ctx: = TWContext.for_tests("user://tw_boardview_selftest2/")
	_host.add_child(ctx.screens)
	var rep: = ctx.screens.scan()
	ok((rep.registered as Array).has("match") and ctx.screens.has_screen("match"), "TWScreens.scan registers `match`: %s" % str(rep))
	var spec: ScreenSpec = ctx.screens.registry.get("match")
	ok(spec != null and spec.validate() == "" and spec.tut_ids.size() >= 2, "match spec is valid and names its tutorial targets")
	var seen: Array = []
	ctx.bus.subscribe("MATCH", func(e: Dictionary) -> void: seen.append("MATCH"))
	ctx.bus.subscribe("TO_TRAY", func(e: Dictionary) -> void: seen.append("TO_TRAY"))
	ctx.bus.subscribe("CLEARED", func(e: Dictionary) -> void: seen.append("CLEARED"))
	var res: Variant = await ctx.screens.go("match", {"cfg": _cfg(51, {"plan": {}, "ice": 0, "hidden": false}), "tile_size": "L"})
	var m: = ctx.screens.current as TWMatchScreen
	ok(m != null and m.view != null and m.board != null and m.view.size_key == "L", "go(match) mounted a TWMatchScreen with a view (L)")
	if m == null:
		return
	m.view.manual = true
	var ended: Array = []
	m.round_ended.connect(func(r: Dictionary) -> void: ended.append(r))
	var guard: = 0
	var tray_max: = 0
	while not m.ended and guard < 400:
		guard += 1
		var id: = m.board.solver_move()
		if id < 0:
			break
		m.tap_tile(id)
		tray_max = maxi(tray_max, m.board.tray.size())
		m.view.advance(0.05)
	m.view.finish()
	ok(m.board.cleared and ended.size() == 1 and ended[0].state == "cleared", "a solver game through the screen API ends once, cleared: %s" % str(ended))
	ok(seen.count("MATCH") == m.board.pairs_done and seen.has("CLEARED") and seen.has("TO_TRAY"), "the events reached ctx.bus (%d MATCH for %d pairs)" % [seen.count("MATCH"), m.board.pairs_done])
	ok(m.view.mirror_matches_board().is_empty(), "the screen view mirrors the finished board")
	ok(m.tap_tile(0).is_empty(), "a finished round takes no more taps")
	ok(m.tut_rect("match_field") == m.view.field and m.tut_rect("match_tray") == m.view.tray_rect, "tut_rect resolves the stable ids")
	ok(m.on_back() == false, "back with nobody listening is not consumed (the manager navigates away)")
	var lost: Variant = await ctx.screens.go("match", {"cfg": _cfg(52, {"plan": {}})})
	var m2: = ctx.screens.current as TWMatchScreen
	m2.view.manual = true
	var tries: = 0
	while not m2.ended and tries < 200:
		tries += 1
		var fr: = m2.board.free_tiles()
		var pick: = -1
		for t in fr:
			if m2.board.tray_twin(t) < 0:
				pick = t
				break
		if pick < 0:
			break
		m2.tap_tile(pick)
		m2.view.advance(0.02)
	ok(m2.board.failed and m2.result().state == "failed", "a game of unmatched taps fills the tray: failed (%d taps)" % tries)
	ok(m2.view.last_type_clips.has("TRAY_FULL") or m2.view._dim > 0.0 or m2.view.stats.plays > 0, "the loss was animated")
	var connected: Array = []
	m2.back_requested.connect(func() -> void: connected.append(1))
	ok(m2.on_back() == false, "back after the round ended is not consumed")
	ctx.screens.queue_free()
	await _host.get_tree().process_frame


# ------------------------------------------------------------------ I lint

func _lint() -> void:
	var path: = "res://shell/screens/match/board_view.gd"
	var f: = FileAccess.open(path, FileAccess.READ)
	ok(f != null, "board_view.gd is readable")
	if f == null:
		return
	var src: = f.get_as_text()
	var re: = RegEx.new()
	re.compile("board\\.(tap|undo|shuffle|return_tray|vanish_pairs|hack_deepest|moonlight|open_tile|reassign|reset|restore|deal|load_view|play_replay|play_solver)\\(")
	ok(re.search(src) == null, "board_view.gd calls no board operation that changes the board")
	ok(not src.contains("res://assets"), "board_view.gd has no res://assets literal (TWAssets ids only)")
	var hex: = RegEx.new()
	hex.compile("\"#[0-9a-fA-F]{6}")
	ok(hex.search(src) == null and not src.contains("Color.html") and not src.contains("Color" + "8("), "board_view.gd has no raw hex colour")
	ok(not src.contains("Input.") and not src.contains("randf(") and not src.contains("randi("), "board_view.gd reads no Input singleton and draws no randomness (the timeline is deterministic)")
	var sc: = FileAccess.open("res://shell/screens/match/match_screen.gd", FileAccess.READ)
	if sc != null:
		var s2: = sc.get_as_text()
		ok(not s2.contains("res://assets") and not s2.contains("Input."), "match_screen.gd has no res://assets literal and no Input")
