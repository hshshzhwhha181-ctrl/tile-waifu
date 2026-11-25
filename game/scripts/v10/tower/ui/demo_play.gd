extends "res://scripts/main.gd"

# demo_play — the runner of part D (the tower match) on the REAL main.gd: the play screen, the overlay, the
# toasts, the confirm popups and the transitions are the game's own. Only go() is taken over for the three ids
# main.SCREENS does not know yet ("tower_play", "pagoda", "journey"); every other id goes to main.go as is.
#
#   godot --path game res://scripts/v10/tower/ui/demo_play.tscn [--resolution 720x1280] -- [flags]
#     --selftest=1      plays the tower with the solver: floor clear, lanterns, run over, Journey boards, a heart and
#                       the same table, the boss and her two tricks, practice, cursed / empty helps. Prints
#                       «TOWER_PLAY_SELFTEST ok/total», exit code 0 only when every check passed
#     --shots=<dir>     snapshots of the match states into <dir>/<name>.png, then quit
#     --mode=pagoda|journey|practice [--floor=N] [--board=N] [--curses=id:lvl,id:lvl]   just play (interactive)
#     --fx=full|mid|min fx level (V10Hud2Util.fx_override)
#
# The save is a substitute: user://dev_tower_play.json, wiped at start; the player's own save is only read by
# G._ready and never written. The clock is fixed (V10TowerUtil.fake_now), so the week, its boss and its seeds are
# stable from run to run. Rewards go through V10TowerUI.grant_hook (counted here, credited like the default).

const TP_SCRIPT: = "res://scripts/v10/tower/tower_play.gd"
const HUB_SCRIPTS: = {"pagoda": "res://scripts/v10/tower/pagoda_screen.gd", "journey": "res://scripts/v10/tower/journey_screen.gd"}
const OWN: = ["tower_play", "pagoda", "journey"]
const SAVE: = "user://dev_tower_play.json"
const FAKE_NOW: = 1795629600  # Wed 25 Nov 2026, 18:00 UTC (the same week as the hub demos)
const P: = preload("res://scripts/v10/tower/pagoda.gd")
const J: = preload("res://scripts/v10/tower/journey.gd")
const UIT: = preload("res://scripts/v10/tower/ui/tower_ui.gd")
const CUT: = preload("res://scripts/v10/tower/ui/boss_cutin.gd")
const TPS: = preload("res://scripts/v10/tower/tower_play.gd")
# visible text that must never show in a tower match (prices, paid help, the 0.9 «Ставка ×2»)
const BANNED: = ["₽", "кр.", "Ставка", "Лунн", "Купить", "купить", "Ульта", "ульта"]

var dargs: = {}
var quick: = false
var last_go: = {}
var go_log: Array = []
var toasts: Array = []
var grants: Array = []
var gem_peak: = 0
var ev_all: Array = []  # [instance id of the match, kind, data]: survives the match screen
var _ok: = 0
var _total: = 0
var _fails: Array = []


# a hub that is not in the build yet: its name and the result it was given (never reached while A and B exist)
class HubStub extends Control:
	var main = null
	var args: = {}

	func build(m, a: Dictionary) -> void:
		main = m
		args = a
		m.show_chrome(false, false)
		var bg: = ColorRect.new()
		bg.color = V10DS.NIGHT_900
		bg.size = size
		add_child(bg)
		var l: = V10Type.label("Хаб «%s»" % String(get_meta("hub", "")), "display", 44, V10DS.PAPER_100)
		l.position = Vector2(32, 160)
		l.size = Vector2(size.x - 64, 60)
		add_child(l)
		if a.has("result"):
			var r: = V10Type.label(JSON.stringify(a.result).left(120), "ui", 18, V10DS.PAPER_300)
			r.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
			r.position = Vector2(32, 240)
			r.size = Vector2(size.x - 64, 200)
			add_child(r)


# ---------------------------------------------------------------- main, taken over where it must be

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv: = a.substr(2).split("=", true, 1)
			dargs[kv[0]] = kv[1] if kv.size() > 1 else "1"
	quick = dargs.has("selftest") or dargs.has("shots")
	V10TowerUtil.fake_now = FAKE_NOW
	if dargs.has("fx"):
		V10Hud2Util.fx_override = String(dargs.fx)
	_fresh_save()
	UIT.grant_hook = _grant_hook
	if quick:
		get_tree().create_timer(float(dargs.get("watchdog", "420")), true, false, true).timeout.connect(func() -> void:
			print("TOWER_PLAY_SELFTEST watchdog: no result (runtime error above?) %d/%d" % [_ok, _total])
			get_tree().quit(4))
	super._ready()


# the player's save is never touched: a fresh state in user://dev_tower_play.json, at the Gold rank (the Pagoda
# and the Journey are open), tutorial, intro and profile done
func _fresh_save() -> void:
	G.demo = false
	G.save_path = SAVE
	for p in [SAVE, G._tmp_path(), G._bak_path()]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	G._main_ok = false
	var S: Dictionary = G.default_state()
	S.tut_done = true
	S.intro_done = true
	S.profile_done = true
	S.daily_day = G.today()
	G.S = S
	var need: = maxi(P.gold_rank_index(), J.gate_index())
	var rp: = 0
	while G.rank_index(rp) < need and rp < 200000:
		rp += 5
	S.rp = rp + 3
	G.sync_hidden_items()
	G.save()


func _grant_hook(reward: Dictionary, src: String) -> void:
	grants.append([reward.duplicate(), src])
	for k in ["gems", "coins", "petals", "tickets"]:
		if int(reward.get(k, 0)) > 0:
			G.S[k] = int(G.S.get(k, 0)) + int(reward[k])


func _record(kind: String, data: Dictionary, id: int) -> void:
	ev_all.append([id, kind, data])


func _ev_of(id: int, kind: String) -> Array:
	var out: = []
	for e in ev_all:
		if int(e[0]) == id and String(e[1]) == kind:
			out.append(e[2])
	return out


func _splash() -> void:
	pass


func toast(text: String, icon: = "") -> void:
	toasts.append([text, icon])
	# main routes a toast into the match strip only for PLAY_BACK ids; tower_play is not one of them yet
	if screen_id == "tower_play" and screen and is_instance_valid(screen) and screen.has_method("v8_notice"):
		if screen.v8_notice(text, art_icon(icon) if icon != "" else null):
			return
	super.toast(text, icon)


func go(id: String, args: = {}, animate: = true, remember: = true) -> void:
	# shallow copies: a hub erases args.result once it has shown it
	go_log.append({"id": id, "args": args.duplicate()})
	if not id in OWN:
		await super.go(id, args, animate, remember)
		return
	if busy or (id == screen_id and args.is_empty()):
		return
	last_go = {"id": id, "args": args.duplicate()}
	var from_id: = screen_id
	var from_args: Dictionary = screen.get_meta("v8_args", {}) if screen and is_instance_valid(screen) else {}
	for p in overlay.get_children():
		if p.has_meta("popup") or p.has_meta("v8_back"):
			p.queue_free()
	busy = true
	if remember and from_id != "" and from_id != id and from_id != "tower_play" and not from_id in NO_HISTORY:
		history.append([from_id, from_args])
		if history.size() > 12:
			history.pop_front()
	var anim: = animate and not quick
	if anim:
		Sfx.play("whoosh", 1.0, -4)
		var t: = create_tween()
		t.tween_method(func(v): trans_mat.set_shader_parameter("progress", v), 0.0, 1.0, 0.32).set_trans(Tween.TRANS_QUAD)
		await t.finished
	if screen:
		screen.queue_free()
	screen_id = id
	# like main.go for PLAY_BACK ids: popups and toasts above the tiles of the tray (z 200+)
	var match_z: = id == "tower_play"
	overlay.z_index = 400 if match_z else 0
	trans.z_index = 450 if match_z else 0
	var path: String = TP_SCRIPT if id == "tower_play" else String(HUB_SCRIPTS[id])
	if ResourceLoader.exists(path):
		screen = Control.new()
		screen.set_script(load(path))
	else:
		screen = HubStub.new()
		screen.set_meta("hub", id)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.size = Vector2(W, H)
	screen.set_meta("v8_args", args.duplicate())
	screen_root.add_child(screen)
	screen.call("build", self, args)
	if screen.has_signal("tower_event"):
		screen.tower_event.connect(_record.bind(screen.get_instance_id()))
	refresh_currency()
	refresh_nav()
	if anim:
		var t2: = create_tween()
		t2.tween_method(func(v): trans_mat.set_shader_parameter("progress", v), 1.0, 0.0, 0.4).set_trans(Tween.TRANS_QUAD)
	busy = false


func _dev_args() -> void:
	await get_tree().process_frame
	busy = false
	if dargs.has("selftest"):
		await _tower_selftest()
		return
	if dargs.has("shots"):
		await _shots(String(dargs.shots))
		get_tree().quit(0)
		return
	var m: = String(dargs.get("mode", "pagoda"))
	go("tower_play", {"mode": m, "run": _make_run(m, _curses_arg(), int(dargs.get("floor", "1")), int(dargs.get("board", "1")) - 1)}, false)


func _curses_arg() -> Dictionary:
	var c: = {}
	for part in String(dargs.get("curses", "")).split(",", false):
		var kv: = part.split(":")
		c[kv[0]] = int(kv[1]) if kv.size() > 1 else 1
	return c


func _make_run(m: String, curses: = {}, floor_n: = 1, board_i: = 0, seed_v: = 4242) -> Dictionary:
	var r: Dictionary
	if m == "pagoda":
		r = P.new_run("mc", curses, seed_v)
		r.floor = floor_n
	else:
		r = J.start("mc", m == "practice")
		if r.has("error"):
			r = J.start("mc", true)
		r.board = board_i
	G.save()
	return r


# ---------------------------------------------------------------- test helpers

func _check(ok: bool, name: String) -> void:
	_total += 1
	if ok:
		_ok += 1
	else:
		_fails.append(name)
		printerr("TOWER_PLAY_SELFTEST FAIL: " + name)


func _tp():
	if screen_id == "tower_play" and screen and is_instance_valid(screen) and not screen.is_queued_for_deletion():
		return screen
	return null


func _wait_until(cond: Callable, real_secs: = 20.0) -> bool:
	var t0: = Time.get_ticks_msec()
	while not bool(cond.call()):
		if Time.get_ticks_msec() - t0 > int(real_secs * 1000.0):
			return false
		await get_tree().process_frame
	return true


func _secs(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _playable(s) -> bool:
	return s != null and is_instance_valid(s) and bool(s.started) and s.board != null and bool(s.board.input_on)


func _is_new(old) -> bool:
	var s = _tp()
	return s != null and s != old


func _wait_match(old) -> Node:
	if not await _wait_until(_is_new.bind(old), 12.0):
		return null
	var s = _tp()
	await _wait_until(func() -> bool: return _playable(s), 15.0)
	return s if _playable(s) else null


func _open(m: String, r: Dictionary) -> Node:
	var old = _tp()
	go("tower_play", {"mode": m, "run": r}, false)
	return await _wait_match(old)


func _has(s, kind: String) -> bool:
	return s != null and is_instance_valid(s) and not _ev(s, kind).is_empty()


func _ev(s, kind: String) -> Array:
	var out: = []
	for e in s.events:
		if String(e[0]) == kind:
			out.append(e[1])
	return out


func _count(s, kind: String) -> int:
	return _ev(s, kind).size() if s != null and is_instance_valid(s) else 0


# the solver of the 0.9 selftest with the obvious pair first: a tray twin, a free pair, then the step order
func _pick(b) -> Tile:
	var fr: Array = b.free_tiles().filter(func(t): return not t.pending and not t.flipping)
	if fr.is_empty():
		return null
	for x in b.tray:
		for t in fr:
			if t.face == x.face and t.ice <= 0:
				return t
	if b.tray.size() < b.slots - 1:
		var by: = {}
		for t in fr:
			if t.ice > 0:
				continue
			if by.has(t.face):
				return by[t.face]
			by[t.face] = t
	return b.solver_move()


func _autoplay(s, max_taps: = 900, step: = 0.1) -> int:
	var taps: = 0
	while is_instance_valid(s) and s == _tp() and not bool(s.done) and taps < max_taps:
		if bool(s.board.input_on) and not bool(s.frozen) and not bool(s.failing):
			var t: Tile = _pick(s.board)
			if t:
				s.board.tap(t)
				taps += 1
		gem_peak = maxi(gem_peak, int(G.S.gems))
		await get_tree().create_timer(step).timeout
	return taps


# fill the tray with faces that make no pair: the tray overflows
func _force_overflow(s) -> bool:
	if not await _wait_until(func() -> bool: return _playable(s) and not bool(s.frozen) and not bool(s.failing), 10.0):
		return false
	var b = s.board
	var guard: = 0
	while is_instance_valid(s) and b.input_on and b.tray.size() < b.slots and guard < 40:
		guard += 1
		var faces: = {}
		for x in b.tray:
			faces[x.face] = true
		var fr: Array = b.free_tiles().filter(func(t): return not t.pending and not t.flipping and t.ice <= 0 and not faces.has(t.face))
		if fr.is_empty():
			return false
		b.tap(fr[0])
		await get_tree().process_frame
	return b.tray.size() >= b.slots


func _texts(n: Node, out: Array) -> Array:
	if n is CanvasItem and not (n as CanvasItem).visible:
		return out
	if n is Label:
		out.append((n as Label).text)
	elif n is RichTextLabel:
		out.append((n as RichTextLabel).get_parsed_text())
	for c in n.get_children():
		_texts(c, out)
	return out


func _banned_in(n: Node) -> Array:
	var bad: = []
	for t in _texts(n, []):
		for w in BANNED:
			if String(w) in String(t):
				bad.append(t)
	return bad


func _find_text(n: Node, text: String) -> bool:
	for t in _texts(n, []):
		if text in String(t):
			return true
	return false


func _disk() -> Dictionary:
	var d = G.read_save_file(SAVE)
	return d if d is Dictionary else {}


func _disk_run(key: String) -> Dictionary:
	var v = _disk().get(key, {})
	return v.get("run", {}) if v is Dictionary else {}


func _popups() -> int:
	var n: = 0
	for c in overlay.get_children():
		if c.has_meta("popup") and not c.is_queued_for_deletion():
			n += 1
	return n


func _close_popups() -> void:
	for c in overlay.get_children():
		if c.has_meta("popup"):
			c.queue_free()


# ---------------------------------------------------------------- the selftest

func _tower_selftest() -> void:
	Engine.time_scale = float(dargs.get("speed", "3"))
	var t_start: = Time.get_ticks_msec()
	await _t_static()
	await _t_pagoda()
	await _t_journey()
	await _t_practice()
	await _t_helps()
	Engine.time_scale = 1.0
	for f in _fails:
		print("  fail: ", f)
	print("TOWER_PLAY_SELFTEST %d/%d (%.1f s)" % [_ok, _total, (Time.get_ticks_msec() - t_start) / 1000.0])
	get_tree().quit(0 if _ok == _total and _total > 0 else 1)


func _t_static() -> void:
	_check(V10TowerHud.status_text("pagoda", {"floor": 7}) == "Этаж 7", "hud: «Этаж 7»")
	_check(V10TowerHud.status_text("pagoda", {"floor": 5}) == "Этаж 5 · Страж", "hud: the guard floor")
	_check(V10TowerHud.status_text("journey", {"board": 2}) == "Стол 3 из 5", "hud: «Стол 3 из 5»")
	_check(V10TowerHud.status_text("practice", {"board": 0, "practice": true}).begins_with("Тренировка"), "hud: practice")
	_check(V10TowerHud.slots_of("pagoda", {"lives": 3, "curses": {}, "bless": {}, "forced": {}}) == 3, "hud: 3 lantern places")
	_check(V10TowerHud.slots_of("journey", {"hearts": 3}) == 3, "hud: 3 hearts")
	_check(TPS.sheets_script() != null, "part C sheets found (V10TowerSheets.floor_clear / board_clear)")
	await get_tree().process_frame


func _t_pagoda() -> void:
	# ---- floor 1, solved
	var run: = P.new_run("mc", {}, 4242)
	G.save()
	var s = await _open("pagoda", run)
	_check(s != null, "pagoda: the match opens and deals")
	if s == null:
		return
	_check(s.tmode == "pagoda" and is_same(s.run, P.current_run()), "pagoda: the saved run itself is played")
	var snap: Dictionary = s.thud.snapshot()
	_check(String(snap.title) == "Этаж 1" and int(snap.lit) == 3 and int(snap.slots) == 3, "hud: «Этаж 1», 3 lanterns lit")
	_check(String(snap.heat) == "Жар 0", "hud: «Жар 0»")
	var words: = ("%s %s %s" % [snap.title, snap.heat, snap.clock]).split(" ", false).size()
	_check(words <= 8, "hud: ≤ 8 words (%d)" % words)
	_check(String(snap.clock) == "", "hud: no clock without the hourglass")
	_check(s.board.slots == s.tr.slot_count(V7Passives.slots(s.partner, 4)), "pagoda: tray size from the run")
	_check(s.hint_n == 1 and s.undo_n == 1 and s.shuffle_n == 1, "pagoda: helps 1/1/1 from the run")
	_check(s.gems_lbl == null or not (s.gems_lbl.get_parent() as CanvasItem).is_visible_in_tree(), "no crystal counter in the match")
	_check(s.thud.position.y + s.thud.size.y <= s.board_rect.position.y, "hud line sits above the table")
	_check(String(s.cfg.name) == "Пагода Луны", "the goal plate names the place, not the floor again")
	await _wait_until(func() -> bool: return not get_tree().get_nodes_in_group("v6_tip").is_empty(), 4.0)
	_check(not get_tree().get_nodes_in_group("v6_tip").is_empty() and not _find_text(s, "Перк"), "the intro card has no 0.9 perk line")
	var bad: = _banned_in(s)
	_check(bad.is_empty(), "no prices / paid help / «Ставка» / «ульта» on the table %s" % [bad])
	var b2: = TrayBoard.new()
	add_child(b2)
	seed(int(s.cfg.seed))
	b2.setup(s.cfg)
	randomize()
	_check(TPS.deal_signature(b2) == s.deal_sig, "the deal comes from the floor seed")
	b2.free()
	var g0: = int(G.S.gems)
	var rp0: = int(G.S.rp)
	var n_grants: = grants.size()
	gem_peak = g0
	await _autoplay(s)
	_check(_has(s, "clear"), "pagoda: floor 1 cleared by the solver")
	_check(gem_peak == g0, "crystals never tick during the match")
	var res: Dictionary = s.last_res
	var rw: Dictionary = res.get("reward", {})
	_check(grants.size() - n_grants == (0 if rw.is_empty() else 1), "the floor reward is granted once")
	_check(int(G.S.gems) - g0 == int(rw.get("gems", 0)) + int(s.last_award.get("gems", 0)), "crystals = reward + rank-up only")
	_check(int(G.S.rp) == rp0 + V8PlayRules.climb_rp(1), "rank points like the climb (+%d)" % V8PlayRules.climb_rp(1))
	var dr: = _disk_run("v10_pagoda")
	_check(int(dr.get("floor", 0)) == 2 and int(dr.get("cleared", 0)) == 1, "saved right after the clear (floor 2, cleared 1)")
	await _wait_until(func() -> bool: return s.sheet != null and _has(s, "sheet"), 6.0)
	_check(s.sheet != null and s.sheet.get_child_count() > 0, "the floor window opens")
	_check(_has(s, "sheet") and not bool(_ev(s, "sheet")[0].get("fallback", true)), "the floor window is part C's V10TowerSheets")
	var offer: Array = run.get("offer", [])
	if not offer.is_empty():
		_check(P.pick_blessing(run, String(offer[0])), "a blessing is picked into the run")
	s.sheet_cb.call({"action": "next"})
	var s2 = await _wait_match(s)
	_check(s2 != null and is_same(s2.run, run) and int(s2.run.floor) == 2, "«Выше»: the same run on floor 2")
	if s2 == null:
		return
	_check(String(s2.thud.snapshot().title) == "Этаж 2", "hud: «Этаж 2»")
	# ---- overflow: a lantern goes out, the tray comes back, the floor goes on
	_check(await _force_overflow(s2), "the tray overflows")
	await _wait_until(func() -> bool: return _has(s2, "life_lost"), 6.0)
	_check(int(run.lives) == 2, "overflow: a lantern goes out (3 → 2)")
	await _secs(0.4)
	_check(int(s2.thud.snapshot().lit) == 2, "hud: 2 lanterns lit after the exhale")
	_check(int(_disk_run("v10_pagoda").get("lives", 0)) == 2, "the lost lantern is saved at once")
	await _wait_until(func() -> bool: return _playable(s2) and s2.board.tray.size() < s2.board.slots, 6.0)
	_check(_playable(s2) and not bool(s2.done) and s2.board.tray.size() < s2.board.slots, "the tray came back, the floor goes on")
	# ---- leaving: the run is kept, the floor starts over on the same seed
	var sig2: String = s2.deal_sig
	s2._ask_leave()
	await get_tree().process_frame
	_check(_popups() > 0, "leaving asks first")
	_close_popups()
	s2._leave()
	await _wait_until(func() -> bool: return screen_id == "pagoda", 6.0)
	_check(screen_id == "pagoda" and String(last_go.get("id", "")) == "pagoda", "leaving goes to the Pagoda hub")
	var kept: = _disk_run("v10_pagoda")
	_check(int(kept.get("floor", 0)) == 2 and int(kept.get("lives", 0)) == 2, "the run is kept (floor 2, 2 lanterns)")
	await _secs(0.3)
	_close_popups()
	var s3 = await _open("pagoda", P.current_run())
	_check(s3 != null and s3.deal_sig == sig2, "the floor starts over on the same seed (the same deal)")
	if s3 == null:
		return
	# ---- the last lanterns: the run ends, the hub gets the result
	for k in 2:
		var n0: = _count(s3, "life_lost")
		await _force_overflow(s3)
		await _wait_until(func() -> bool: return _count(s3, "life_lost") > n0, 6.0)
		if k == 0:
			await _wait_until(func() -> bool: return _playable(s3), 6.0)
	_check(int(run.lives) == 0, "three lanterns out")
	await _wait_until(func() -> bool: return String(last_go.get("id", "")) == "pagoda" and (last_go.args as Dictionary).has("result"), 8.0)
	_check(String(last_go.get("id", "")) == "pagoda" and (last_go.args as Dictionary).has("result"), "run over: to the Pagoda with the result")
	if (last_go.args as Dictionary).has("result"):
		_check(int(last_go.args.result.get("floors", -1)) == 1, "result: 1 floor cleared")
	_check(P.current_run().is_empty() and _disk_run("v10_pagoda").is_empty(), "the ended run is gone from the save")
	await _secs(0.5)
	_close_popups()


func _t_journey() -> void:
	var jr: = J.start("mc")
	G.save()
	_check(not jr.has("error"), "journey: an attempt starts")
	var j1 = await _open("journey", jr)
	_check(j1 != null, "journey: board 1 opens")
	if j1 == null:
		return
	var snap: Dictionary = j1.thud.snapshot()
	_check(String(snap.title) == "Стол 1 из 5" and int(snap.lit) == 3 and String(snap.heat) == "", "hud: «Стол 1 из 5», 3 hearts")
	_check(_find_text(j1, TPS.NORMAL_TEXT), "the plaque «Честный зачёт: наряды не дают силы»")
	_check(j1.ult == null or (bool(j1.ult.ranked) and j1.SKILL_NEED == j1.ult.need()), "Приём at base strength")
	_check(j1.board.slots == int(j1.tr.rules.slots), "journey: the run's own tray size (no outfit passives)")
	var vz: = (j1.tr.veils as Dictionary).values().filter(func(v): return is_instance_valid(v) and (v as CanvasItem).z_index != 0)
	_check(vz.is_empty(), "veils stay in their tile's place in the stack (%d veils)" % (j1.tr.veils as Dictionary).size())
	var g0: = int(G.S.gems)
	var n_grants: = grants.size()
	gem_peak = g0
	await _autoplay(j1)
	_check(_has(j1, "clear"), "journey: board 1 cleared")
	_check(gem_peak == g0, "journey: no crystals during the board")
	_check(grants.size() == n_grants, "journey: no reward per board")
	_check(int(jr.board) == 1 and int(_disk_run("v10_journey").get("board", -1)) == 1, "journey: the board is saved")
	await _wait_until(func() -> bool: return j1.sheet != null, 6.0)
	_check(j1.sheet != null and _has(j1, "sheet"), "journey: board_clear window")
	if not (jr.get("offer", []) as Array).is_empty():
		J.pick_blessing(jr, String(jr.offer[0]))
	j1.sheet_cb.call({"action": "next"})
	var j2 = await _wait_match(j1)
	_check(j2 != null and String(j2.thud.snapshot().title) == "Стол 2 из 5", "«Дальше»: board 2")
	if j2 == null:
		return
	# ---- a heart breaks: the same table from the start
	var sig: String = j2.deal_sig
	var j2_id: = j2.get_instance_id()
	_check(await _force_overflow(j2), "journey: the tray overflows")
	await _wait_until(func() -> bool: return _has(j2, "life_lost"), 6.0)
	_check(int(jr.hearts) == 2, "a heart breaks (3 → 2)")
	_check(int(_disk_run("v10_journey").get("hearts", 0)) == 2, "the broken heart is saved at once")
	await _secs(0.3)
	_check(int(j2.thud.snapshot().lit) == 2, "hud: 2 hearts after the crack")
	var j3 = await _wait_match(j2)
	_check(not _ev_of(j2_id, "restart").is_empty(), "the broken heart restarts the board")
	_check(j3 != null and j3.deal_sig == sig, "the same table from the start (same deal)")
	if j3 == null:
		return
	_check(int(j3.thud.snapshot().lit) == 2, "hud: still 2 hearts")
	# ---- the boss board: two tricks, each with her cut-in first
	jr.board = 4
	jr.hearts = 3
	jr.tricks_done = 0
	G.save()
	var played0: = CUT.played
	var jb = await _open("journey", jr)
	_check(jb != null and String(jb.cfg.get("boss", "")) != "", "board 5 is the boss board")
	if jb == null:
		return
	_check(String(jb.thud.snapshot().title) == "Стол 5 из 5", "hud: «Стол 5 из 5»")
	var cut_seen: = [false]
	jb.tower_event.connect(func(kind: String, _d: Dictionary) -> void:
		if kind == "trick_cutin":
			await get_tree().process_frame
			if CUT.last and is_instance_valid(CUT.last) and not jb.board.input_on and bool(jb.frozen):
				cut_seen[0] = true)
	await _autoplay(jb, 1200)
	var seq: = []
	for e in jb.events:
		if String(e[0]) in ["trick_cutin", "trick_op"]:
			seq.append(String(e[0]))
	_check(seq == ["trick_cutin", "trick_op", "trick_cutin", "trick_op"], "two tricks, the cut-in before each op %s" % [seq])
	_check(CUT.played - played0 == 2, "two cut-ins played")
	_check(cut_seen[0], "input and clock frozen under the cut-in")
	_check(_has(jb, "clear"), "the boss board is cleared")
	await _wait_until(func() -> bool: return jb.sheet != null, 6.0)
	_check(bool(jb.last_res.get("done", false)), "5/5: the run is done")
	var n_grants2: = grants.size()
	jb.sheet_cb.call({"action": "finish"})
	await _wait_until(func() -> bool: return String(last_go.get("id", "")) == "journey" and (last_go.args as Dictionary).has("result"), 8.0)
	_check(String(last_go.get("id", "")) == "journey" and (last_go.args as Dictionary).has("result"), "finish: to the Journey with the result")
	if (last_go.args as Dictionary).has("result"):
		var fin: Dictionary = last_go.args.result
		_check(int(fin.get("boards", 0)) == 5, "result: 5 boards")
		_check(bool(fin.get("granted", false)), "result carries granted = true (the hub does not pay twice)")
		_check(grants.size() - n_grants2 == (0 if (fin.get("reward", {}) as Dictionary).is_empty() else 1), "the week reward is granted once")
	_check(J.current_run().is_empty() and _disk_run("v10_journey").is_empty(), "the finished run is gone from the save")
	await _secs(0.5)
	_close_popups()


func _t_practice() -> void:
	# a real unfinished attempt must survive any practice
	var real: = J.start("mc")
	G.save()
	var before: = JSON.stringify(G.S.get("v10_journey", {}))
	var rp0: = int(G.S.rp)
	var n_grants: = grants.size()
	var pr: = J.start("mc", true)
	var p1 = await _open("practice", pr)
	_check(p1 != null and String(p1.thud.snapshot().title).begins_with("Тренировка"), "practice: «Тренировка · Стол 1 из 5»")
	if p1 == null:
		return
	await _autoplay(p1)
	_check(_has(p1, "clear"), "practice: board 1 cleared")
	await _wait_until(func() -> bool: return p1.sheet != null, 6.0)
	p1.sheet_cb.call({"action": "next"})
	var p2 = await _wait_match(p1)
	_check(p2 != null and String(p2.tmode) == "practice", "practice: board 2")
	if p2 != null:
		await _force_overflow(p2)
		var p3 = await _wait_match(p2)
		_check(p3 != null and int(pr.hearts) == 2, "practice: a heart and the same table")
		if p3 != null:
			p3._leave()
			await _wait_until(func() -> bool: return screen_id == "journey", 6.0)
	_check(JSON.stringify(G.S.get("v10_journey", {})) == before, "practice never writes S.v10_journey (the real run is intact)")
	_check(is_same(J.current_run(), real) or JSON.stringify(J.current_run()) == JSON.stringify(real), "the real attempt is still there")
	_check(int(G.S.rp) == rp0 and grants.size() == n_grants, "practice: no rank points, no rewards")
	await _secs(0.4)
	_close_popups()


func _t_helps() -> void:
	# cursed helps: grey, the caption names the curse, the tap says why; never a price
	var hr: = P.new_run("mc", {"no_hint": 1, "no_undo": 1, "no_shuffle": 1, "no_ult": 1}, 777)
	_check(not hr.has("error"), "a run with four help curses")
	G.save()
	var h1 = await _open("pagoda", hr)
	_check(h1 != null, "cursed floor opens")
	if h1 == null:
		return
	for k in ["hint", "undo", "shuffle"]:
		var tc: Label = h1._tower_caps.get(k)
		_check(not h1._help_ok(k) and tc != null and tc.visible and "Проклятие" in tc.text, "%s: grey with «%s»" % [k, tc.text if tc else "?"])
	var t0: = toasts.size()
	h1._hint()
	_check(toasts.size() > t0 and "Проклятие" in String(toasts[-1][0]), "a cursed help says which curse")
	_check(int(h1.skill_charge) == 0 and not bool(h1.skill_ready), "«Без приёма»: no charge")
	var bad: = _banned_in(h1)
	_check(bad.is_empty(), "no prices on the cursed floor %s" % [bad])
	_close_popups()
	h1._leave()
	await _wait_until(func() -> bool: return screen_id == "pagoda", 6.0)
	await _secs(0.3)
	_close_popups()
	# an empty help: deny + «Здесь только честная игра», never _v8_pay
	var er: = P.new_run("mc", {}, 4242)
	G.save()
	var h2 = await _open("pagoda", er)
	if h2 == null:
		_check(false, "plain floor opens")
		return
	_close_popups()
	h2.hint_n = 0
	h2._refresh()
	var cap: Label = h2.btn_hint.get_node("Cap")
	_check(cap.visible and cap.text.ends_with("· 0"), "an empty help shows «· 0» («%s»)" % cap.text)
	var t1: = toasts.size()
	h2._hint()
	_check(toasts.size() > t1 and String(toasts[-1][0]) == TPS.FAIR_TEXT, "an empty help: «Здесь только честная игра»")
	var paid: = [false]
	h2._v8_pay("hint", "t", "d", 30, func() -> void: paid[0] = true)
	_check(not paid[0] and h2.pay_calls == 1, "_v8_pay never sells in a tower match")
	var bad2: = _banned_in(h2)
	_check(bad2.is_empty(), "no «кр.» badge on an empty help %s" % [bad2])
	h2.pay_calls = 0


# ---------------------------------------------------------------- shots

func _shot(dir: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: = get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [dir, name])
	print("shot ", name)


func _shots(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	Engine.time_scale = 1.0
	# 1. Pagoda floor 1: «Этаж 1», 3 lanterns, «Жар 0»
	var run: = P.new_run("mc", {}, 4242)
	G.save()
	var s = await _open("pagoda", run)
	if s == null:
		print("shots: the match did not open")
		return
	await _secs(1.0)
	await _shot(dir, "01_pagoda_floor1")
	# 2. an overflow: the lantern exhales, «Фонарь погас · осталось 2»
	await _force_overflow(s)
	await _wait_until(func() -> bool: return _has(s, "life_lost"), 6.0)
	await _secs(0.16)
	await _shot(dir, "02a_lantern_exhale")
	await _secs(0.5)
	await _shot(dir, "02b_lantern_out")
	# 3. curses Рубашка + Туман + Песочные часы: back faces, fog veils, the clock in the line
	var cr: = P.new_run("mc", {"shroud": 1, "fog": 1, "hourglass": 1}, 5150)
	G.save()
	s = await _open("pagoda", cr)
	if s:
		await _secs(1.2)
		await _shot(dir, "03_curses_shroud_fog_clock")
		s.tr.clock = 8.4
		await _secs(0.3)
		await _shot(dir, "04_clock_last_seconds")
	# 5. the guard floor 5
	var gr: = P.new_run("mc", {}, 6060)
	gr.floor = 5
	G.save()
	s = await _open("pagoda", gr)
	if s:
		await _secs(1.0)
		await _shot(dir, "05_guard_floor5")
	# 6. Journey board 1 with the fair-score plaque
	var jr: = J.start("mc")
	G.save()
	s = await _open("journey", jr)
	if s:
		await _secs(0.5)
		await _shot(dir, "06_journey_board1")
		# 7. a heart breaks
		await _force_overflow(s)
		await _wait_until(func() -> bool: return _has(s, "life_lost"), 6.0)
		await _secs(0.3)
		await _shot(dir, "07_journey_heart_break")
		await _wait_match(s)
	# 8–9. the boss board: the cut-in held at 0.55 s, then the table after the trick
	jr.board = 4
	jr.hearts = 3
	jr.tricks_done = 0
	G.save()
	s = await _open("journey", jr)
	if s:
		Engine.time_scale = 3.0
		CUT.dev_freeze = 0.55
		var n0: = CUT.played
		_autoplay(s, 1200)
		await _wait_until(func() -> bool: return CUT.played > n0 and CUT.last != null and is_instance_valid(CUT.last) and float(CUT.last.t) >= 0.55, 60.0)
		Engine.time_scale = 1.0
		await _secs(0.2)
		await _shot(dir, "08_boss_cutin")
		var bs = s
		CUT.dev_freeze = -1.0
		var n_ops: = _count(bs, "trick_op")
		await _wait_until(func() -> bool: return _count(bs, "trick_op") > n_ops, 10.0)
		await _secs(0.45)
		await _shot(dir, "09_boss_after_trick")
		Engine.time_scale = 3.0
		await _wait_until(func() -> bool: return not is_instance_valid(bs) or bool(bs.done) or _tp() != bs, 90.0)
		Engine.time_scale = 1.0
	# 10. the floor window (part C) after a solved floor
	var fr: = P.new_run("mc", {}, 4242)
	G.save()
	s = await _open("pagoda", fr)
	if s:
		Engine.time_scale = 3.0
		await _autoplay(s)
		Engine.time_scale = 1.0
		await _wait_until(func() -> bool: return s.sheet != null, 6.0)
		await _secs(2.4)
		await _shot(dir, "10_floor_window")
	# 11. the board window of the Journey (practice)
	var pr: = J.start("mc", true)
	s = await _open("practice", pr)
	if s:
		Engine.time_scale = 3.0
		await _autoplay(s)
		Engine.time_scale = 1.0
		await _wait_until(func() -> bool: return s.sheet != null, 6.0)
		await _secs(2.4)
		await _shot(dir, "11_board_window_practice")
	# 12. cursed helps: grey, with the curse named under each
	var hr: = P.new_run("mc", {"no_hint": 1, "no_undo": 1, "no_shuffle": 1, "no_ult": 1}, 777)
	G.save()
	s = await _open("pagoda", hr)
	if s:
		await _secs(3.6)
		await _shot(dir, "12_helps_cursed")
		s._hint()
		await _secs(0.3)
		await _shot(dir, "13_cursed_help_tap")
	# 14. an empty help: «Здесь только честная игра»
	var er: = P.new_run("mc", {}, 4242)
	G.save()
	s = await _open("pagoda", er)
	if s:
		s.hint_n = 0
		s._refresh()
		await _secs(3.6)
		s._hint()
		await _secs(0.3)
		await _shot(dir, "14_empty_help_fair")
	# 15. fx «min»: the cut-in is a fade
	V10Hud2Util.fx_override = "min"
	var mr: = J.start("mc", true)
	mr.board = 4
	s = await _open("practice", mr)
	if s:
		var n1: = CUT.played
		CUT.dev_freeze = 0.5
		Engine.time_scale = 3.0
		_autoplay(s, 1200)
		await _wait_until(func() -> bool: return CUT.played > n1 and CUT.last != null and is_instance_valid(CUT.last) and float(CUT.last.t) >= 0.5, 60.0)
		Engine.time_scale = 1.0
		await _secs(0.2)
		await _shot(dir, "15_boss_cutin_fx_min")
		CUT.dev_freeze = -1.0
		s.done = true
		await _secs(0.3)
	V10Hud2Util.fx_override = ""
	# 16. the line at its fullest: «Этаж 7», five lanterns, a high heat
	var hot: = P.new_run("mc", {"shroud": 2, "fog": 2, "no_hint": 1, "no_undo": 1, "no_shuffle": 1}, 8080)
	if not hot.has("error"):
		hot.floor = 7
		hot.lives = 5
		G.save()
		s = await _open("pagoda", hot)
		if s:
			await _secs(3.6)
			await _shot(dir, "16_line_floor7_5_lanterns_heat")
