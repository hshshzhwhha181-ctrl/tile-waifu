class_name TWPresenceSelftest
extends RefCounted

# P34 / WP10 selftest of TWPresence (shell/stage/presence.gd):  godot --headless --path game res://shell/stage/presence_selftest.tscn
# Prints "TWPRESENCE_SELFTEST ok/total".
#   A layout    strip <= 28% of the screen height on 3 aspects (+ a 600-case property test), never over the board; medallion 160 px;
#               full column leaves the board >= 50% of the width; insets; degrade to the medallion when there is no room
#   B modes     resolve_mode / default_mode_for (Classic, Connect, Garden -> minimum), fit() puts the face inside the area
#   C tracker   TWBoardEvents -> reaction ids: combo tiers by edge (5 / 10 / 20), clear, fail, tray_danger, ult_cast
#   D data      every reaction resolves to a usable gesture of each of the 3 finished rigs (gestures.json), never bold / legs / n-a
#   E live      each finished rig: 7 reactions through TWBus -> the rig plays the expected gesture, delay (usec) < 100 ms and in the
#               same frame; exactly 1 rig; touches off (rig.handle_input false, every Control ignores the mouse, injected taps do nothing);
#               clip (strip) / disc mask (medallion); mode switching keeps one rig; the head stays inside the area
#   F stub      a heroine with no rig: medallion stub, same reactions, same layout
#   G rules     priority / gap / repeat with an injected clock
#   H real      a real TWBoard (solver) played into the bus: reactions == tracker on the same events, T1..T3 + clear each once
#   I budget    draw items <= 40 and textures <= 24 MB per heroine (P41 method, structure side), 1 rig
#   J lint      no `res://assets` literal, no Input / touch handling in presence.gd

const SCREENS: = [
	["720x1280", Vector2(720, 1280), {"top": 0, "bottom": 0}],
	["720x1600", Vector2(720, 1600), {"top": 48, "bottom": 24}],
	["1536x2048", Vector2(1536, 2048), {"top": 24, "bottom": 16}],
]
const RIGS: = [["mc", "mc_gown"], ["rin", "rin_officer"], ["hana", "hana_base"]]
const LATENCY_LIMIT_US: = 100000

var checks: = 0
var fails: = 0
var lat_us: Array = []
var _host: Node
var _bus: TWBus
var budget_rows: Array = []


func ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("TWPRESENCE FAIL: ", what)


func run(host: Node) -> Array:
	_host = host
	_layout()
	_layout_property()
	_modes()
	_tracker()
	_data()
	await _live()
	await _stub()
	_rules()
	await _real_board()
	await _budget()
	_lint()
	var lat_max: = 0
	var lat_sum: = 0
	for v in lat_us:
		lat_max = maxi(lat_max, int(v))
		lat_sum += int(v)
	print("TWPRESENCE latency over %d reactions: mean %d us, max %d us (limit %d us)" % [lat_us.size(), lat_sum / maxi(lat_us.size(), 1), lat_max, LATENCY_LIMIT_US])
	for r in budget_rows:
		print("TWPRESENCE budget ", JSON.stringify(r))
	print("TWPRESENCE_SELFTEST %d/%d" % [checks - fails, checks])
	return [checks - fails, checks]


# ------------------------------------------------------------------ A layout

func _overlap(a: Rect2, b: Rect2) -> bool:
	return b.size != Vector2.ZERO and a.intersects(b)


func _layout() -> void:
	for sc in SCREENS:
		var nm: String = sc[0]
		var size: Vector2 = sc[1]
		var ins: Dictionary = sc[2]
		var board: = TWPresence.standard_avoid(size)
		var st: = TWPresence.layout(size, board, TWPresence.MODE_STANDARD, ins)
		var r: Rect2 = st.rect
		ok(r.size.y <= size.y * 0.28 + 0.001, "%s strip height %.1f <= 28%% of %.0f" % [nm, r.size.y, size.y])
		ok(float(st.strip_frac) <= 0.28 + 1e-6, "%s strip_frac %.4f <= 0.28" % [nm, st.strip_frac])
		ok(r.size.y >= TWPresence.STRIP_MIN_H and st.effective == TWPresence.MODE_STANDARD, "%s strip is a strip (h %.0f)" % [nm, r.size.y])
		ok(not _overlap(r, board), "%s strip does not touch the board rect" % nm)
		ok(r.position.x == 0.0 and is_equal_approx(r.size.x, size.x), "%s strip spans the screen width" % nm)
		ok(is_equal_approx(r.end.y, size.y - float(ins.bottom)), "%s strip ends at the bottom inset" % nm)
		ok(Rect2(Vector2.ZERO, size).encloses(r), "%s strip inside the screen" % nm)
		var board_h_frac: float = board.size.y / size.y
		ok(board_h_frac >= 0.6, "%s the board left by the strip is >= 60%% of the height (%.2f)" % [nm, board_h_frac])
		# medallion
		var mn: = TWPresence.layout(size, board, TWPresence.MODE_MINIMUM, ins)
		var m: Rect2 = mn.rect
		ok(m.size == Vector2(160, 160) and not bool(mn.clamped), "%s medallion is 160x160" % nm)
		ok(bool(mn.disc) and mn.effective == TWPresence.MODE_MINIMUM, "%s medallion is a disc" % nm)
		ok(not _overlap(m, board), "%s medallion does not touch the board rect" % nm)
		ok(Rect2(Vector2.ZERO, size).encloses(m) and m.end.y <= size.y - float(ins.bottom), "%s medallion inside the screen and the safe area" % nm)
		ok(float(mn.strip_frac) <= 0.28, "%s medallion is no taller than a strip (%.3f)" % [nm, mn.strip_frac])
		# with a smaller board (Minimum frees the strip) the medallion still keeps off it
		var small: = Rect2(0, 0, size.x, size.y * 0.8)
		var mn2: = TWPresence.layout(size, small, TWPresence.MODE_MINIMUM, ins)
		ok(not _overlap(mn2.rect, small), "%s medallion keeps off a taller board (0.8 H)" % nm)
		# full column
		var fu: = TWPresence.layout(size, board, TWPresence.MODE_FULL, ins)
		var board_w: float = fu.board_max_w
		ok(board_w >= size.x * 0.5, "%s FULL leaves the board >= 50%% of the width (%.0f)" % [nm, board_w])
		ok(not _overlap(fu.rect, Rect2(0, 0, board_w, size.y)), "%s FULL column does not touch the board column" % nm)
		ok(Rect2(Vector2.ZERO, size).encloses(fu.rect), "%s FULL column inside the screen" % nm)
		# no room: a board that eats everything -> the strip degrades to the medallion, still off the board
		var tall: = Rect2(0, 0, size.x, size.y - float(ins.bottom) - 40.0)
		var dg: = TWPresence.layout(size, tall, TWPresence.MODE_STANDARD, ins)
		ok(bool(dg.degraded) and dg.effective == TWPresence.MODE_MINIMUM, "%s a strip with no room degrades to the medallion" % nm)
		ok(bool(dg.hidden) and (dg.rect as Rect2).size == Vector2.ZERO, "%s no room at all: the heroine is hidden, not drawn over the board" % nm)
		var semi: = Rect2(0, 0, size.x, size.y - float(ins.bottom) - 140.0)
		var sm: = TWPresence.layout(size, semi, TWPresence.MODE_MINIMUM, ins)
		ok(bool(sm.clamped) and not bool(sm.hidden) and (sm.rect as Rect2).size.x >= 96.0 and (sm.rect as Rect2).size.x < 160.0 and not _overlap(sm.rect, semi), "%s a little room: a smaller (clamped) medallion off the board (%.0f)" % [nm, (sm.rect as Rect2).size.x])
	# empty avoid: strip is still 28% and the board hint is not required
	var e: = TWPresence.layout(Vector2(720, 1280), Rect2(), TWPresence.MODE_STANDARD)
	ok((e.rect as Rect2).size.y == floorf(1280.0 * 0.28), "no avoid rect: strip = 28%% (%d)" % int((e.rect as Rect2).size.y))


func _layout_property() -> void:
	var rng: = RandomNumberGenerator.new()
	rng.seed = 3434
	var bad: = 0
	var bad_what: = ""
	for i in 600:
		var h: = float(rng.randi_range(1100, 2400))
		var w: = float(rng.randi_range(600, 1600))
		var size: = Vector2(w, h)
		var ins: = {"top": float(rng.randi_range(0, 80)), "bottom": float(rng.randi_range(0, 60))}
		var bh: = rng.randf_range(0.45, 0.95) * h
		var board: = Rect2(0, float(ins.top), w, bh - float(ins.top))
		for md in [TWPresence.MODE_STANDARD, TWPresence.MODE_MINIMUM]:
			var l: = TWPresence.layout(size, board, md, ins)
			var r: Rect2 = l.rect
			var good: = Rect2(Vector2.ZERO, size).encloses(r)
			if l.effective == TWPresence.MODE_STANDARD:
				good = good and r.size.y <= h * 0.28 + 0.001 and r.position.y >= board.end.y - 0.001
			else:
				good = good and r.position.y >= board.end.y - 0.001 and r.size.x == r.size.y
				if bool(l.hidden):
					good = good and r.size == Vector2.ZERO
				elif not bool(l.clamped):
					good = good and r.size.x == 160.0
				else:
					good = good and r.size.x >= TWPresence.MEDALLION_MIN and r.size.x < 160.0
			if not good:
				bad += 1
				bad_what = "%s %s %s ins %s board %s -> %s" % [md, size, l.effective, ins, board, r]
	ok(bad == 0, "600 random screens x 2 modes keep the invariants (%d bad, e.g. %s)" % [bad, bad_what])


# ------------------------------------------------------------------ B modes

func _modes() -> void:
	for g in ["classic", "connect", "garden"]:
		ok(TWPresence.default_mode_for(g) == TWPresence.MODE_MINIMUM, "default mode of %s is minimum" % g)
		ok(TWPresence.resolve_mode("auto", g) == TWPresence.MODE_MINIMUM, "auto in %s -> minimum" % g)
	for g in ["path", "daily", "free", "cube", ""]:
		ok(TWPresence.default_mode_for(g) == TWPresence.MODE_STANDARD, "default mode of '%s' is standard" % g)
	for m in TWPresence.MODES:
		ok(TWPresence.resolve_mode(m, "classic") == m and TWPresence.resolve_mode(m, "path") == m, "an explicit pref %s wins" % m)
	ok(TWPresence.resolve_mode("nonsense", "garden") == TWPresence.MODE_MINIMUM and TWPresence.resolve_mode("", "path") == TWPresence.MODE_STANDARD, "a bad pref falls back to auto")
	# fit(): the face lands inside the area, the figure fills it
	for sc in SCREENS:
		var size: Vector2 = sc[1]
		var st: Rect2 = TWPresence.layout(size, TWPresence.standard_avoid(size), TWPresence.MODE_STANDARD, sc[2]).rect
		var f: = TWPresence.fit(st.size, TWPresence.MODE_STANDARD, 581.0, Vector2(700, 228))
		var face: Vector2 = f.position + Vector2(700, 228) * float(f.scale)
		ok(Rect2(Vector2.ZERO, st.size).has_point(face), "%s strip: the face (%.0f, %.0f) is inside the strip" % [sc[0], face.x, face.y])
		ok(face.y < st.size.y * 0.5, "%s strip: the face is in the upper half" % sc[0])
		var md: = TWPresence.fit(Vector2(160, 160), TWPresence.MODE_MINIMUM, 581.0, Vector2(700, 228))
		var mf: Vector2 = md.position + (Vector2(700, 228) + Vector2(0, TWPresence.FACE_DROP)) * float(md.scale)
		ok(mf.distance_to(Vector2(80, 80)) < 0.01, "medallion: the face is the disc centre")


# ------------------------------------------------------------------ C tracker

func _match(combo: int) -> Dictionary:
	return TWBoardEvents.make(TWBoardEvents.MATCH, {"a": 1, "b": 2, "face": 3, "combo": combo})


func _tracker() -> void:
	var t: = TWPresence.Tracker.new()
	var got: Array = []
	for c in range(1, 26):
		var r: = t.feed(_match(c))
		if r != "":
			got.append([c, r])
	ok(got == [[5, "combo_t1"], [10, "combo_t2"], [20, "combo_t3"]], "combo 1..25 fires T1 at 5, T2 at 10, T3 at 20 exactly once each: %s" % str(got))
	ok(t.feed(_match(26)) == "" and t.feed(_match(40)) == "", "no repeat above the top tier")
	ok(t.feed(_match(1)) == "" and t.tier == 0, "a broken combo lowers the tier silently")
	var again: Array = []
	for c in range(2, 8):
		var r2: = t.feed(_match(c))
		if r2 != "":
			again.append(r2)
	ok(again == ["combo_t1"], "a new streak fires T1 again")
	t.reset()
	ok(t.feed(_match(12)) == "combo_t2", "a jump to 12 fires only T2 (the highest reached)")
	ok(t.feed(_match(13)) == "" and t.feed(_match(20)) == "combo_t3", "then T3 at 20")
	ok(TWPresence.Tracker.tier_of(4) == 0 and TWPresence.Tracker.tier_of(5) == 1 and TWPresence.Tracker.tier_of(19) == 2 and TWPresence.Tracker.tier_of(99) == 3, "tier_of boundaries")
	var t2: = TWPresence.Tracker.new()
	ok(t2.feed(TWBoardEvents.make(TWBoardEvents.CLEARED)) == "clear", "CLEARED -> clear")
	ok(t2.feed(TWBoardEvents.make(TWBoardEvents.TRAY_FULL, {"tray": []})) == "fail", "TRAY_FULL -> fail")
	ok(t2.feed(TWBoardEvents.make(TWBoardEvents.TRAY_WARN, {"left": 1})) == "tray_danger", "TRAY_WARN left 1 -> tray_danger")
	ok(t2.feed(TWBoardEvents.make(TWBoardEvents.TRAY_WARN, {"left": 2})) == "", "TRAY_WARN left 2 -> nothing")
	ok(t2.feed({"t": TWPresence.EV_ULT_CAST}) == "ult_cast", "ULT_CAST -> ult_cast")
	for ty in [TWBoardEvents.TO_TRAY, TWBoardEvents.DENY, TWBoardEvents.BLOCKED, TWBoardEvents.ICE_CRACK, TWBoardEvents.REVEAL, TWBoardEvents.SHUFFLE, TWBoardEvents.UNDO, TWBoardEvents.VANISH]:
		ok(t2.feed(TWBoardEvents.make(ty, {})) == "", "%s does not move the heroine" % ty)
	ok(t2.feed({}) == "" and t2.feed({"t": 5}) == "", "malformed events are ignored")


# ------------------------------------------------------------------ D data

func _data() -> void:
	for p in RIGS:
		var e: = V10RigCatalog.get_rig(p[1])
		ok(not e.is_empty(), "%s: gestures.json loads" % p[1])
		var usable: = TWPresence.usable_gestures(e)
		var raw: Array = []
		for g in e.get("gestures", []):
			raw.append(g)
		for r in TWPresence.REACTIONS:
			var g: = TWPresence.reaction_gesture(e, r)
			ok(g != "", "%s: reaction %s resolves (%s)" % [p[1], r, g])
			ok(usable.has(g), "%s: %s -> %s is a usable gesture" % [p[1], r, g])
			for gd in raw:
				if String(gd.get("name", "")) == g:
					ok(String(gd.get("tier", "base")) != "bold" and not bool(gd.get("legs", false)), "%s: %s is not bold and not a legs gesture" % [p[1], g])
		ok(not usable.has("leg_idle") and not usable.has("sheen_sweep"), "%s: layer/fx entries are not gestures to play" % p[1])
	ok(TWPresence.reaction_gesture({}, "clear") == "" and TWPresence.reaction_gesture({"gestures": []}, "fail") == "", "an empty rig entry plays nothing")
	ok(TWPresence.reaction_gesture(V10RigCatalog.get_rig("mc_gown"), "nonsense") == "", "an unknown reaction plays nothing")
	for r in TWPresence.REACTIONS:
		ok(TWPresence.CANDIDATES.has(r) and TWPresence.PRIORITY.has(r), "reaction %s has candidates and a priority" % r)


# ------------------------------------------------------------------ E live

func _new_presence(hero: String, mode: String, size: Vector2, ins: Dictionary, bus: TWBus = null) -> TWPresence:
	var p: = TWPresence.new()
	p.configure(hero, "", mode)
	p.set_screen(size, TWPresence.standard_avoid(size), ins)
	_host.add_child(p)
	if bus != null:
		p.bind(bus)
	return p


func _rigs_in(n: Node) -> Array:
	var out: Array = []
	var stack: Array = [n]
	while not stack.is_empty():
		var x: Node = stack.pop_back()
		if x is V10LiveRig:
			out.append(x)
		for c in x.get_children():
			stack.append(c)
	return out


func _controls_ignore(n: Node) -> bool:
	var stack: Array = [n]
	while not stack.is_empty():
		var x: Node = stack.pop_back()
		if x is Control and (x as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE:
			return false
		for c in x.get_children():
			stack.append(c)
	return true


func _live() -> void:
	for pr in RIGS:
		var hero: String = pr[0]
		var rid: String = pr[1]
		var entry: = V10RigCatalog.get_rig(rid)
		for sc in SCREENS:
			var size: Vector2 = sc[1]
			var bus: = TWBus.new()
			var p: = _new_presence(hero, TWPresence.MODE_STANDARD, size, sc[2], bus)
			await _host.get_tree().process_frame
			var tag: = "%s@%s" % [rid, sc[0]]
			ok(not p.stub and p.rig != null, "%s: a real rig is mounted" % tag)
			if p.rig == null:
				p.queue_free()
				continue
			ok(_rigs_in(p).size() == 1, "%s: exactly one rig on screen" % tag)
			ok(not p.rig.handle_input, "%s: rig handle_input is off (touches disabled in a round)" % tag)
			ok(_controls_ignore(p), "%s: every Control of the presence ignores the mouse" % tag)
			ok(p.mouse_filter == Control.MOUSE_FILTER_IGNORE, "%s: the presence itself ignores the mouse" % tag)
			ok(p._view.clip_contents and p._view.clip_children == CanvasItem.CLIP_CHILDREN_DISABLED, "%s: the strip clips its rig to its own rect" % tag)
			ok(p.size.y <= size.y * 0.28 + 0.001, "%s: the node is a strip <= 28%% (%.0f of %.0f)" % [tag, p.size.y, size.y])
			var area: = Rect2(p.global_position, p.size)
			var head: Vector2 = p.rig.to_global(p.rig.face_pivot)
			ok(area.has_point(head), "%s: the head (%.0f, %.0f) is inside the strip %s" % [tag, head.x, head.y, str(area)])
			# every reaction through the bus
			var played: Array = []
			var cb: = func(name: String) -> void:
				played.append([name, Time.get_ticks_usec(), Engine.get_process_frames()])
			p.rig.gesture_started.connect(cb)
			var clk: = [100.0]
			p.set_clock(func() -> float: return clk[0])
			var evs: = {
				"combo_t1": _match(5), "combo_t2": _match(10), "combo_t3": _match(20),
				"clear": TWBoardEvents.make(TWBoardEvents.CLEARED), "fail": TWBoardEvents.make(TWBoardEvents.TRAY_FULL, {"tray": []}),
				"tray_danger": TWBoardEvents.make(TWBoardEvents.TRAY_WARN, {"left": 1}), "ult_cast": {"t": TWPresence.EV_ULT_CAST},
			}
			for r in TWPresence.REACTIONS:
				p.new_round()
				p.tracker.tier = 0
				if r == "combo_t3":
					p.tracker.tier = 2
				elif r == "combo_t2":
					p.tracker.tier = 1
				played.clear()
				clk[0] += 10.0
				var f0: = Engine.get_process_frames()
				var t0: = Time.get_ticks_usec()
				bus.publish(evs[r])
				var want: = TWPresence.reaction_gesture(entry, r)
				ok(played.size() == 1 and played[0][0] == want, "%s: %s -> gesture %s (got %s)" % [tag, r, want, str(played)])
				if played.size() == 1:
					var d: int = int(played[0][1]) - t0
					lat_us.append(d)
					ok(d < LATENCY_LIMIT_US, "%s: %s reaction delay %d us < 100 ms" % [tag, r, d])
					ok(int(played[0][2]) == f0, "%s: %s starts in the same frame as the event" % [tag, r])
				ok(p.history.size() > 0 and p.history[-1].reaction == r, "%s: history records %s" % [tag, r])
			# touches: inject a tap on her face through the viewport
			var taps: Array = []
			p.rig.tapped.connect(func(z: String) -> void: taps.append(z))
			var n0: int = p.rig.actions.size()
			var tp: = Vector2(head)
			var te: = InputEventScreenTouch.new()
			te.position = tp
			te.pressed = true
			te.index = 0
			_host.get_viewport().push_input(te, false)
			var me: = InputEventMouseButton.new()
			me.position = tp
			me.global_position = tp
			me.button_index = MOUSE_BUTTON_LEFT
			me.pressed = true
			_host.get_viewport().push_input(me, false)
			await _host.get_tree().process_frame
			ok(taps.is_empty(), "%s: a tap on the heroine does nothing (rig.tapped never fires)" % tag)
			p.queue_free()
			await _host.get_tree().process_frame
		# the medallion of the same rig + mode switching keeps ONE rig and the same instance
		var size2: = Vector2(720, 1280)
		var p2: = _new_presence(hero, TWPresence.MODE_MINIMUM, size2, {})
		await _host.get_tree().process_frame
		var rig0: = p2.rig
		ok(rig0 != null and p2.size == Vector2(160, 160), "%s: minimum mode is a 160 px node" % rid)
		ok(p2._view.clip_children == CanvasItem.CLIP_CHILDREN_ONLY and not p2._view.clip_contents, "%s: the medallion masks its rig with a disc" % rid)
		var disc: = Rect2(p2.global_position, p2.size)
		ok(disc.has_point(p2.rig.to_global(p2.rig.face_pivot)), "%s: the face is inside the medallion" % rid)
		ok(p2.rig.to_global(p2.rig.face_pivot).distance_to(disc.get_center()) < 40.0, "%s: the face is near the disc centre" % rid)
		for m in [TWPresence.MODE_STANDARD, TWPresence.MODE_FULL, TWPresence.MODE_MINIMUM, TWPresence.MODE_STANDARD]:
			p2.set_mode(m)
			ok(p2.rig == rig0 and _rigs_in(p2).size() == 1, "%s: switching to %s keeps the one rig" % [rid, m])
			ok(p2.effective_mode == m, "%s: effective mode %s" % [rid, m])
			ok(p2.rig.scale.x > 0.0 and is_finite(p2.rig.position.x) and is_finite(p2.rig.position.y), "%s/%s: rig transform sane" % [rid, m])
		# re-configure to another heroine keeps one rig
		p2.configure("rin" if hero != "rin" else "hana", "", TWPresence.MODE_STANDARD)
		await _host.get_tree().process_frame
		await _host.get_tree().process_frame
		ok(_rigs_in(p2).size() == 1, "%s: re-configure to another heroine leaves one rig (%d)" % [rid, _rigs_in(p2).size()])
		p2.queue_free()
		await _host.get_tree().process_frame


# ------------------------------------------------------------------ F stub

func _stub() -> void:
	for hero in ["yue", "tsubame", "nobody"]:
		var bus: = TWBus.new()
		var p: = _new_presence(hero, TWPresence.MODE_STANDARD, Vector2(720, 1280), {}, bus)
		await _host.get_tree().process_frame
		ok(p.stub and p.rig == null, "%s: no finished rig -> the medallion stub" % hero)
		ok(_rigs_in(p).is_empty(), "%s: the stub holds no rig" % hero)
		ok(p.effective_mode == TWPresence.MODE_STANDARD and p.size.y <= 1280 * 0.28 + 0.001, "%s: the stub keeps the strip layout (<= 28%%)" % hero)
		var got: Array = []
		p.reaction_started.connect(func(r: String, g: String) -> void: got.append([r, g]))
		var clk: = [10.0]
		p.set_clock(func() -> float: return clk[0])
		var evs: Array = [_match(5), _match(10), _match(20), TWBoardEvents.make(TWBoardEvents.CLEARED), TWBoardEvents.make(TWBoardEvents.TRAY_FULL, {"tray": []}),
				TWBoardEvents.make(TWBoardEvents.TRAY_WARN, {"left": 1}), {"t": TWPresence.EV_ULT_CAST}]
		for ev in evs:
			clk[0] += 10.0
			var t0: = Time.get_ticks_usec()
			bus.publish(ev)
			lat_us.append(Time.get_ticks_usec() - t0)
		var names: Array = []
		for g in got:
			names.append(g[0])
		ok(names == TWPresence.REACTIONS, "%s: the stub plays all 7 reactions in order: %s" % [hero, str(names)])
		ok(not got.is_empty() and got[0][1] == "pulse", "%s: the stub answers with a pulse" % hero)
		ok(_controls_ignore(p), "%s: the stub ignores the mouse" % hero)
		p.set_mode(TWPresence.MODE_MINIMUM)
		ok(p.size == Vector2(160, 160) and p._view.clip_children == CanvasItem.CLIP_CHILDREN_ONLY, "%s: the stub in minimum mode is the 160 px disc" % hero)
		ok(p.measure().rigs == 0, "%s: stub measure has no rig" % hero)
		p.queue_free()
		await _host.get_tree().process_frame


# ------------------------------------------------------------------ G rules

func _rules() -> void:
	var p: = TWPresence.new()      # not in the tree: stub heroine, play() is pure bookkeeping here
	p.configure("nobody", "", TWPresence.MODE_STANDARD)
	var clk: = [0.0]
	p.set_clock(func() -> float: return clk[0])
	ok(p.play("clear") == "pulse", "first reaction plays")
	clk[0] = 0.3
	ok(p.play("combo_t1") == "" and p.dropped == 1, "a weaker reaction 0.3 s after a stronger one is dropped")
	ok(p.play("fail") == "pulse", "a stronger reaction (fail) cuts in at once")
	clk[0] = 0.5
	ok(p.play("clear") == "", "clear right after fail (weaker) is dropped")
	clk[0] = 1.0
	ok(p.play("clear") == "pulse", "after the 0.6 s gap it plays again")
	clk[0] = 2.0
	ok(p.play("tray_danger") == "pulse", "tray_danger plays")
	clk[0] = 4.0
	ok(p.play("tray_danger") == "", "tray_danger repeats no sooner than 4 s")
	clk[0] = 6.5
	ok(p.play("tray_danger") == "pulse", "tray_danger plays again after 4 s")
	ok(p.play("nonsense") == "", "an unknown reaction is ignored")
	var n: = p.history.size()
	for i in 100:
		clk[0] += 1.0
		p.play("clear")
	ok(p.history.size() <= TWPresence.KEEP_LOG and p.history.size() >= n, "the history is bounded (%d)" % p.history.size())
	p.new_round()
	clk[0] += 0.0
	ok(p.tracker.tier == 0, "new_round resets the combo tier")
	p.free()


# ------------------------------------------------------------------ H real board

func _real_board() -> void:
	var bus: = TWBus.new()
	var p: = _new_presence("mc", TWPresence.MODE_STANDARD, Vector2(720, 1280), {}, bus)
	await _host.get_tree().process_frame
	var cfg: = {"cols": 6, "rows": 8, "layers": 3, "fill": 0.7, "faces": 12, "seed": 77, "shape": "rect"}
	var b: = TWBoard.from_cfg(cfg)
	var t: = [0.0]
	b.clock = func() -> float: return t[0]
	b.combo_window = 1.0e9
	var clk: = [0.0]
	p.set_clock(func() -> float: return clk[0])
	var ref: = TWPresence.Tracker.new()
	var expect: Array = []
	var guard: = 0
	var matches: = 0
	while not b.cleared and not b.failed and guard < 500:
		guard += 1
		var i: = b.solver_move()
		if i < 0:
			break
		t[0] += 1.0
		clk[0] += 2.0           # past the gap and the repeat limits: nothing is dropped
		var ev: Array = b.tap(i)
		for e in ev:
			if TWBoardEvents.type_of(e) == TWBoardEvents.MATCH:
				matches += 1
			var r: = ref.feed(e)
			expect.append(r)
		bus.publish_all(ev)
	var got: Array = []
	for h in p.history:
		got.append(h.reaction)
	expect = expect.filter(func(x) -> bool: return x != "")
	ok(b.cleared, "the real board was cleared by the solver (%d pairs)" % matches)
	ok(got == expect, "the heroine reacted exactly as the tracker says on the real event stream: %s vs %s" % [str(got), str(expect)])
	ok(got.count("combo_t1") == 1 and got.count("combo_t2") == 1 and got.count("combo_t3") == 1 and got.count("clear") == 1, "T1, T2, T3 and clear once each in a %d-pair game (%s)" % [matches, str(got)])
	ok(got.size() > 0 and got[-1] == "clear", "the last reaction of a cleared board is clear")
	# a lost game: the fail reaction
	var bus2: = TWBus.new()
	var p2: = _new_presence("hana", TWPresence.MODE_MINIMUM, Vector2(720, 1280), {}, bus2)
	await _host.get_tree().process_frame
	var c2: = {"cols": 6, "rows": 8, "layers": 3, "fill": 0.7, "faces": 12, "seed": 5, "shape": "rect"}
	var lb: = TWBoard.from_cfg(c2)
	var clk2: = [0.0]
	p2.set_clock(func() -> float: return clk2[0])
	var seen_danger: = false
	var g2: = 0
	while not lb.failed and not lb.cleared and g2 < 300:
		g2 += 1
		# always tap a free tile whose face is not in the tray: the tray fills up
		var pick: = -1
		var tf: = lb.tray_faces()
		for f in lb.free_tiles():
			if lb.takeable(f) and not tf.has(lb.face[f]):
				pick = f
				break
		if pick < 0:
			break
		clk2[0] += 5.0
		bus2.publish_all(lb.tap(pick))
	var got2: Array = []
	for h in p2.history:
		got2.append(h.reaction)
	seen_danger = got2.has("tray_danger")
	ok(lb.failed, "the losing script filled the tray")
	ok(seen_danger and got2.has("fail") and got2[-1] == "fail", "tray_danger then fail: %s" % str(got2))
	p.queue_free()
	p2.queue_free()
	await _host.get_tree().process_frame


# ------------------------------------------------------------------ I budget

func _budget() -> void:
	for pr in RIGS:
		var p: = _new_presence(pr[0], TWPresence.MODE_STANDARD, Vector2(720, 1280), {})
		await _host.get_tree().process_frame
		var m: = p.measure()
		budget_rows.append({"rig": pr[1], "draw_items_upper": m.draw_items, "textures": m.textures,
			"tex_mem_rgba_mb": snappedf(float(m.tex_mem_rgba_mb), 0.01), "tex_mem_rgba_mips_mb": snappedf(float(m.tex_mem_rgba_mips_mb), 0.01), "rigs": m.rigs})
		ok(int(m.rigs) == 1, "%s: one rig in the budget walk" % pr[1])
		ok(int(m.draw_items) <= 40, "%s: draw items (upper bound, no batching) %d <= 40" % [pr[1], m.draw_items])
		ok(float(m.tex_mem_rgba_mips_mb) <= 24.0, "%s: textures %.2f MB (RGBA8 + mips, no bg plate) <= 24 MB" % [pr[1], m.tex_mem_rgba_mips_mb])
		ok(int(m.textures) > 0, "%s: textures counted" % pr[1])
		p.queue_free()
		await _host.get_tree().process_frame


# ------------------------------------------------------------------ J lint

func _lint() -> void:
	var src: = FileAccess.get_file_as_string("res://shell/stage/presence.gd")
	ok(src.length() > 1000, "presence.gd readable")
	ok(not src.contains("res://assets"), "presence.gd has no res://assets literal (asset ids only)")
	ok(not src.contains("_unhandled_input") and not src.contains("_input(") and not src.contains("gui_input") and not src.contains("InputEventScreenTouch"), "presence.gd handles no input")
	ok(not src.contains("handle_input\": true") and src.contains("\"handle_input\": false"), "the rig is mounted with handle_input false")
	ok(not src.contains("await "), "presence.gd has no await (the reaction path is synchronous)")
	var rig_src: = FileAccess.get_file_as_string("res://scripts/v10/rig/live_rig.gd")
	ok(rig_src.length() > 10000 and not rig_src.contains("TWPresence"), "live_rig.gd is untouched by the presence layer")
