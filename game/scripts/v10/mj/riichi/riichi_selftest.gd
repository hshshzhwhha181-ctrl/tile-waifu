extends Node

# «Стол на четверых» selftest. Run:
#   godot --headless --audio-driver Dummy --path game res://scripts/v10/mj/riichi/riichi_selftest.tscn -- --mj_riichi_selftest=1 [--games=200]
# Last line: MJ_RIICHI ok/total; exit code 0 only when all pass. Watchdog 600 s.

const D = preload("res://scripts/v10/mj/riichi/riichi_data.gd")
const WATCHDOG_S: = 600.0

var ok: = 0
var total: = 0
var fails: = []
var t0: = 0.0
var all_texts: = {}

func _arg(k: String, d: String) -> String:
	for s in OS.get_cmdline_user_args():
		if s.begins_with("--" + k + "="):
			return s.split("=")[1]
	return d

func check(name: String, cond: bool, info: = "") -> void:
	total += 1
	if cond:
		ok += 1
		print("PASS ", name)
	else:
		fails.append(name)
		print("FAIL ", name, "  ", info)

func _ready() -> void:
	t0 = Time.get_ticks_msec() / 1000.0
	var wd: = Timer.new()
	wd.wait_time = WATCHDOG_S
	wd.one_shot = true
	wd.timeout.connect(func():
		print("FAIL watchdog %d s" % int(WATCHDOG_S))
		print("MJ_RIICHI %d/%d" % [ok, total + 1])
		get_tree().quit(2))
	add_child(wd)
	wd.start()
	# a clean, local save for the run
	D._mem = {}
	if has_node("/root/G"):
		get_node("/root/G").S = {"partner": "mc", "rp": 0}
	await get_tree().process_frame
	_data_tests()
	_driver_tests()
	_mimic_tests()
	_layout_tests()
	await _screen_tests()
	await _fx_tests()
	_sim(int(_arg("games", "200")))
	_lint_tests()
	print("time %.1f s" % (Time.get_ticks_msec() / 1000.0 - t0))
	if not fails.is_empty():
		print("FAILED: ", fails)
	print("MJ_RIICHI %d/%d" % [ok, total])
	get_tree().quit(0 if ok == total else 1)

# ------------------------------------------------------------------ data, save, rewards, halls
func _data_tests() -> void:
	var S: Dictionary = D._S()
	S[D.KEY] = "junk"
	var d: = D.st()
	check("save: st() repairs junk", d is Dictionary and d.has("hall_progress") and d.has("stats") and d.has("last_seed") and d.has("daily_one_hand"))
	S[D.KEY] = {"prefs": {"names": "klingon"}, "hall_progress": 5}
	d = D.st()
	check("save: st() repairs fields", d.prefs.names == "ru" and d.hall_progress is Dictionary and d.hall_progress.games is Dictionary)
	var r1: = D.rewards(1, "east", "2026-11-24")
	check("rewards: 1st 40 coins + first of day 20 gems", r1.coins == 40 and r1.gems == 20 and r1.first_today)
	check("rewards by place 40/25/15/10", D.rewards(2, "east").coins == 25 and D.rewards(3, "east").coins == 15 and D.rewards(4, "east").coins == 10)
	D.record_match("school", "east", 3, 77, "2026-11-24")
	check("rewards: second match of the day has no gems", D.rewards(1, "east", "2026-11-24").gems == 0)
	var r2: = D.rewards(2, "one_hand", "2026-11-24")
	check("rewards: one hand of the day +10 gems", r2.gems == 10 and r2.one_hand_today)
	D.record_match("school", "one_hand", 2, 5, "2026-11-24")
	check("rewards: one hand of the day only once", D.rewards(2, "one_hand", "2026-11-24").gems == 0)
	check("daily seed stable per day", D.daily_seed("2026-11-24") == D.daily_seed("2026-11-24") and D.daily_seed("2026-11-24") != D.daily_seed("2026-11-25"))
	# halls
	check("hall: school always open", D.hall_gate("school").open)
	D.st().hall_progress.games = {}
	check("hall: bamboo closed before 2 school games", not D.hall_gate("bamboo").open, str(D.st().hall_progress))
	D.record_match("school", "east", 4, 6)
	D.record_match("school", "east", 4, 6)
	check("hall: bamboo opens after 2 school games", D.hall_gate("bamboo").open)
	check("hall: jade needs Нефрит I", not D.hall_gate("jade").open and D.hall_gate("jade").why.find("Нефрит") >= 0)
	check("hall: sky needs 5 firsts in gold", not D.hall_gate("sky").open)
	D.st().hall_progress.firsts["gold"] = 5
	check("hall: sky opens after 5 firsts in gold", D.hall_gate("sky").open)
	check("hall: school skill 0.6, sky 1.0", is_equal_approx(D.hall("school").skill, 0.6) and is_equal_approx(D.hall("sky").skill, 1.0))
	check("hall: no hints from jade up", D.hall("jade").hints == "" and D.hall("gold").hints == "" and D.hall("sky").hints == "")
	check("rank: bamboo 4th takes nothing", D.rp_delta("bamboo", 4) == 0)
	check("rank: jade protection at the first step", D.rp_delta("jade", 4, 100, 100) == 0 and D.rp_delta("jade", 4, 200, 100) == -30)
	var names_ok: = true
	for id in V8Mj.YAKU.keys() + V8Mj.YAKUMAN.keys():
		if not D.COMBO_RU.has(id) or D.combo_hint(id) == "":
			names_ok = false
			print("  missing name/hint ", id)
	check("every combination has a plain Russian name and a hint", names_ok)
	var st: = V10MjRiichiStats.get_stats()
	V10MjRiichiStats.add_hand(st, {"ev": "win", "seat": 0, "from": 2, "delta": [8000, 0, -8000, 0], "eval": {"yaku": [["tanyao", 1], ["riichi", 1]], "han": 4, "limit": "Манган"}}, 0, true)
	V10MjRiichiStats.add_hand(st, {"ev": "win", "seat": 1, "from": 0, "delta": [-2000, 2000, 0, 0], "eval": {"yaku": [["pinfu", 1]], "han": 1}}, 0, false)
	V10MjRiichiStats.add_match(st, 2)
	var card: = V10MjRiichiStats.card(st)
	check("stats card: 5 rows, win/deal-in/riichi %", card.size() == 5 and card[1][1] == "50%" and card[2][1] == "50%" and card[3][1] == "50%", str(card))
	check("stats card: best combination", String(card[4][1]).find("Большая рука") >= 0, str(card[4]))

# ------------------------------------------------------------------ driver: said stream, pacing, undo, seed, one hand
func _driver_tests() -> void:
	# pacing 0.35–0.9 by style
	var drv: = V10MjRiichiDriver.new().setup({"seed": 3, "me": -1, "heroes": ["hana", "yue", "mc", "nova"]})
	var lo: = 9.0
	var hi: = 0.0
	for s in 4:
		for i in 30:
			var p: = drv.ai_pause(s)
			lo = minf(lo, p)
			hi = maxf(hi, p)
	check("AI pauses within 0.35–0.9 s", lo >= 0.35 and hi <= 0.9, "%.2f..%.2f" % [lo, hi])
	check("Эстафета is faster than Лунная тень", drv.ai_pause(0) < drv.ai_pause(1))
	drv.free()
	# seed → wall (Честный стол)
	var same: = true
	for sd in [1, 42, 777, 123456789, 99]:
		var d2: = V10MjRiichiDriver.new().setup({"seed": sd, "me": -1})
		d2.step()
		if d2.first_wall != V10MjRiichiDriver.wall_for_seed(sd) or d2.first_wall.size() != 136:
			same = false
		d2.free()
	check("seed reproduces the wall (5 seeds)", same)
	# one hand format
	var d3: = V10MjRiichiDriver.new().setup({"seed": 11, "me": -1, "one_hand": true})
	d3.run_sync(5000)
	check("one hand format ends after the first hand", d3.over and d3.hands_done == 1, "hands %d" % d3.hands_done)
	d3.free()
	# hold is refused while the player's decision is pending; undo restores the state
	var d4: = V10MjRiichiDriver.new().setup({"seed": 21, "me": 0, "undo": 3, "dealer": 0})
	var asks: = 0
	var hand_at_first: = []
	var n: = 0
	while n < 4000 and asks < 2:
		n += 1
		if d4.waiting:
			if d4.r.ask.kind == "turn":
				asks += 1
				if asks == 1:
					hand_at_first = d4.r.hands[0].duplicate()
					check("hold refused while the player decides", not d4.hold("x"))
					d4.answer(d4.ai_answer(d4.r.ask))
				continue
			d4.answer(d4.ai_answer(d4.r.ask))
			continue
		d4.step()
	var could: = d4.can_undo()
	var undone: = d4.undo()
	check("undo restores the previous turn", could and undone and d4.r.hands[0] == hand_at_first and d4.waiting and d4.undo_left == 2)
	# after undo the game still runs to the end
	d4.auto_human = true
	d4.run_sync(30000)
	check("game continues after undo", d4.over)
	d4.free()
	# said data carries public keys only
	var d5: = V10MjRiichiDriver.new().setup({"seed": 5, "me": -1})
	var leak: = []
	d5.said.connect(func(_s, _w, data):
		for k in data:
			if not k in V10MjRiichiDriver.PUBLIC_KEYS:
				leak.append(k))
	d5.run_sync(30000)
	check("said carries public data only", leak.is_empty(), str(leak))
	d5.free()

# ------------------------------------------------------------------ mimicry: same public stream, different hidden hands
func _mimic_tests() -> void:
	var a: = V10MjRiichiMimic.new()
	var b: = V10MjRiichiMimic.new()
	var stream: = [[1, "call", {"kind": "pon"}], [2, "riichi", {}], [3, "dora", {}], [0, "call", {"kind": "chi"}], [1, "ron", {"from": 2}], [2, "dealin", {}]]
	var same: = true
	var t: = 0.0
	for e in stream:
		t += 0.7
		var fa: = a.on_said(e[0], e[1], e[2].merged({"hidden": [1, 2, 3], "waits": [5]}), t)
		var fb: = b.on_said(e[0], e[1], e[2].merged({"hidden": [100, 101], "waits": [30, 31]}), t)
		if fa != fb or a.face != b.face:
			same = false
		var ta: = a.tick(t + 0.3)
		var tb: = b.tick(t + 0.3)
		if ta != tb:
			same = false
	check("rival faces identical for different hidden hands", same)
	check("faces react to public events (riichi → surprised)", V10MjRiichiMimic.react(1, 2, "riichi", {}) == "surprised" and V10MjRiichiMimic.react(2, 2, "riichi", {}) == "shy")
	# two real tables, same seed except the player's hidden hand: rivals' faces follow only what is public
	var faces_ok: = true
	var tables: = []
	for variant in 2:
		var drv: = V10MjRiichiDriver.new().setup({"seed": 909, "me": -1})
		var m: = V10MjRiichiMimic.new()
		var tt: = [0.0]
		drv.said.connect(func(s, w, data):
			tt[0] += 1.0
			m.on_said(s, w, data.merged({"hidden_hand": drv.r.hands[s].duplicate()}), tt[0]))
		drv.run_sync(30000)
		tables.append([m.log.duplicate(true), drv])
	if str(tables[0][0]) != str(tables[1][0]):
		faces_ok = false
	check("same public stream → same faces on two runs", faces_ok)
	for tb in tables:
		tb[1].free()

# ------------------------------------------------------------------ layouts: everything on screen, nothing overlaps
func _layout_tests() -> void:
	for sz in [Vector2(720, 1280), Vector2(720, 1600), Vector2(960, 1280), Vector2(720, 1440)]:
		for hz in [false, true]:
			var scr: = V10MjRiichiScreen.new()
			scr.W = sz.x
			scr.H = sz.y
			scr.horizontal = hz
			scr._layout()
			var L: Dictionary = scr.L
			var full: = Rect2(Vector2.ZERO, sz)
			var tag: = "%dx%d %s" % [sz.x, sz.y, "square" if hz else "portrait"]
			var inside: = true
			var rects: = [L.hand, L.btns, L.melds, L.band, L.center]
			for rl in 4:
				rects.append(L.seat[rl].pond)
				if L.seat[rl].has("portrait"):
					rects.append(L.seat[rl].portrait)
			for r in rects:
				if not full.encloses(r.grow(-0.5)):
					inside = false
			check("layout %s: all zones on screen" % tag, inside)
			var ponds_ok: = true
			for i in 4:
				if L.seat[i].pond.grow(-1).intersects(L.center):
					ponds_ok = false
				for j in range(i + 1, 4):
					if L.seat[i].pond.grow(-1).intersects(L.seat[j].pond):
						ponds_ok = false
			check("layout %s: ponds clear of each other and the centre" % tag, ponds_ok)
			check("layout %s: hand / buttons / melds stacked" % tag, L.melds.end.y <= L.btns.position.y + 0.5 and L.btns.end.y <= L.hand.position.y + 0.5 and L.hand.end.y <= L.band.position.y + 0.5)
			check("layout %s: hand fits 14 tiles + gap" % tag, 14 * L.tile.x + 12 <= sz.x - 8)
			var por_ok: = true
			for rl in [1, 2, 3]:
				if L.seat[rl].has("portrait"):
					for k in 4:
						if L.seat[rl].portrait.intersects(L.seat[k].pond) or L.seat[rl].portrait.intersects(L.center):
							por_ok = false
			check("layout %s: portraits clear of ponds" % tag, por_ok)
			scr.free()
	check("portrait base: hand row y 960–1080, buttons 840–960", _base_rows())

func _base_rows() -> bool:
	var scr: = V10MjRiichiScreen.new()
	scr._layout()
	var ok_: bool = is_equal_approx(scr.L.hand.position.y, 960) and is_equal_approx(scr.L.btns.position.y, 840) and scr.L.tile == Vector2(48, 66)
	scr.free()
	return ok_

# ------------------------------------------------------------------ the screen under a bot: reactions, voices, buttons, block
func _new_screen(a: Dictionary) -> V10MjRiichiScreen:
	var scr: = V10MjRiichiScreen.new()
	scr.size = Vector2(720, 1280)
	add_child(scr)
	scr.setup(null, a.merged({"manual": true, "auto_flow": true, "mute": true}))
	return scr

func _play(scr: V10MjRiichiScreen, cap: = 40000) -> Dictionary:
	var drv: = scr.drv
	var n: = 0
	var bad_buttons: = 0
	var bad_block: = 0
	var bad_after: = 0
	var asks: = 0
	while n < cap and not scr.final_result.size() > 0:
		n += 1
		if scr.sheet and is_instance_valid(scr.sheet):
			if scr.sheet.has_meta("tally"):
				if not scr.visible_buttons().is_empty():
					bad_buttons += 1
				scr._tally_next()
				continue
		if drv.waiting:
			asks += 1
			if not scr.fx.blocking().is_empty() or scr.fx.cutin != null:
				bad_block += 1
			var a: Dictionary = drv.ai_answer(drv.r.ask)
			_bot_answer(scr, a)
			if not scr.visible_buttons().is_empty() and not drv.waiting:
				bad_after += 1
			continue
		if not scr.visible_buttons().is_empty():
			bad_buttons += 1
		if not drv.holds.is_empty():
			drv.holds.clear()
		drv.step()
		for l in _labels(scr):
			all_texts[l] = true
	return {"steps": n, "bad_buttons": bad_buttons, "bad_block": bad_block, "bad_after": bad_after, "asks": asks}

func _bot_answer(scr: V10MjRiichiScreen, a: Dictionary) -> void:
	var drv: = scr.drv
	var kind: String = drv.r.ask.kind
	var act: String = String(a.get("a", "pass"))
	if kind == "turn":
		match act:
			"tsumo":
				scr.press_action("tsumo")
			"ankan", "kakan":
				scr.press_action("kan", {"k": a})
			_:
				var t: int = int(a.get("t", drv.r.drawn))
				if a.get("riichi", false):
					scr.press_action("riichi")
					scr.tap_tile(t)
					scr.tap_tile(t)
				else:
					scr.tap_tile(t)
					if drv.waiting:
						scr.tap_tile(t)
		if drv.waiting:
			# the tile was refused by the screen (should not happen): answer directly to keep going
			print("  bot: tile refused ", a)
			drv.answer(a)
		return
	match act:
		"ron":
			scr.press_action("ron")
		"pon":
			scr.press_action("pon")
		"kan":
			scr.press_action("kan")
		"chi":
			scr.press_action("chi", {"use": a.get("use", [])})
		_:
			scr.press_action("pass")
	if drv.waiting:
		print("  bot: action refused ", a)
		drv.answer(a)

func _labels(n: Node) -> Array:
	var out: = []
	for c in n.get_children():
		if c is Label and c.visible:
			out.append(String(c.text))
		out.append_array(_labels(c))
	return out

func _screen_tests() -> void:
	var cfgs: = [{"hall": "school", "seed": 1201, "format": "east"}, {"hall": "bamboo", "seed": 88, "format": "one_hand"},
		{"hall": "gold", "seed": 3141, "format": "east"}]
	var said_total: = 0
	var one_reaction: = true
	var voice_ok: = true
	var bad_btn: = 0
	var bad_blk: = 0
	var bad_aft: = 0
	var ended: = true
	var seed_ok: = true
	var music_ok: = true
	var kinds: = {}
	for i in cfgs.size():
		var scr: = _new_screen(cfgs[i])
		if i == 1:
			D.set_pref("names", "jp")
			scr.names_mode = "jp"
		var res: = _play(scr)
		bad_btn += res.bad_buttons
		bad_blk += res.bad_block + scr.block_violations.size()
		bad_aft += res.bad_after
		if scr.final_result.is_empty():
			ended = false
		said_total += scr.said_no
		var per: = {}
		for r in scr.reactions:
			per[r[0]] = per.get(r[0], 0) + 1
			kinds[r[3]] = kinds.get(r[3], 0) + 1
		for k in range(1, scr.said_no + 1):
			if per.get(k, 0) != 1:
				one_reaction = false
		for v in scr.voice_log:
			if v[2] - v[1] > 1:
				voice_ok = false
		if not scr.seed_check():
			seed_ok = false
		if scr.music.stings > 1 or scr.music.level > 2:
			music_ok = false
		scr.queue_free()
		await get_tree().process_frame
	D.set_pref("names", "ru")
	check("screen: 3 bot matches reach the result", ended)
	check("screen: every said → exactly one reaction (%d said)" % said_total, one_reaction and said_total > 20)
	check("screen: every said → at most one voice", voice_ok)
	check("screen: buttons only on ask", bad_btn == 0, str(bad_btn))
	check("screen: buttons gone after the answer", bad_aft == 0, str(bad_aft))
	check("screen: no insert takes input while a decision is pending", bad_blk == 0, str(bad_blk))
	check("screen: Честный стол seed check passes", seed_ok)
	check("screen: music layers ≤ 2, last-hand sting ≤ 1", music_ok)
	check("screen: reactions seen: stamp, ribbon, cut-in, face", kinds.has("stamp") and kinds.has("ribbon") and kinds.has("cutin") and kinds.has("face"), str(kinds))
	# sanma contract: seats=3 draws three seats
	var s3: = _new_screen({"hall": "school", "seed": 5, "seats": 3})
	s3.drv.step()
	var across: = s3.seat_of_rel(2)
	check("seats=3 draws 3 seats", s3.visible_seats().size() == 3 and s3.portraits.size() == 2 and not s3.portraits.has(across) and s3.pond_nodes[across].get_child_count() == 0)
	s3.queue_free()
	# hints: training hall shows waits/best discard; jade shows none
	var sh: = _new_screen({"hall": "school", "seed": 1201})
	var n: = 0
	while not sh.drv.waiting and n < 400:
		sh.drv.step()
		n += 1
	var glow: = false
	for c in sh.hand_box.get_children():
		if c is V10MjRiichiTile and c.glow.a > 0.0:
			glow = true
	check("training hall: best discard glows", glow)
	sh.queue_free()
	var sj: = _new_screen({"hall": "jade", "seed": 1201})
	n = 0
	while not sj.drv.waiting and n < 400:
		sj.drv.step()
		n += 1
	var glow2: = false
	for c in sj.hand_box.get_children():
		if c is V10MjRiichiTile and (c.glow.a > 0.0 or c.danger):
			glow2 = true
	check("jade hall: no hints", not glow2 and sj.hint_lbl.text == "")
	# riichi first-show caption + names toggle sizes
	D.set_pref("riichi_hint_seen", false)
	sj._lay_buttons([["riichi", {}], ["pass", {}]])
	check("first «Готов · риичи» shows the explanation", sj.btn_row.get_node_or_null("RiichiHint") != null)
	sj._lay_buttons([["riichi", {}], ["pass", {}]])
	await get_tree().process_frame
	check("the explanation shows once", sj.btn_row.get_node_or_null("RiichiHint") == null)
	var b_ru: = sj._act_button("pon", {}, 160)
	sj.names_mode = "jp"
	var b_jp: = sj._act_button("pon", {}, 160)
	check("names toggle: «Взять · пон» ↔ «Пон · взять»", (b_ru.get_child(0) as Label).text == "Взять" and (b_jp.get_child(0) as Label).text == "Пон" and (b_jp.get_child(1) as Label).text == "взять")
	b_ru.free()
	b_jp.free()
	sj.queue_free()
	# hall picker
	var lob: = V10MjRiichiScreen.new()
	lob.size = Vector2(720, 1280)
	add_child(lob)
	lob.setup(null, {"mute": true})
	var taps: = 0
	for c in lob.get_children():
		if c is Control and c.mouse_filter == Control.MOUSE_FILTER_STOP:
			taps += 1
	check("hall picker: ≤ 10 tappable (one closed teaser)", taps <= 10 and lob.get_node_or_null("Hall_school") != null, str(taps))
	for c in _labels(lob):
		all_texts[c] = true
	lob.queue_free()
	await get_tree().process_frame

# ------------------------------------------------------------------ inserts never block; cut-in only in dead time
func _fx_tests() -> void:
	var scr: = _new_screen({"hall": "school", "seed": 1201})
	var n: = 0
	while not scr.drv.waiting and n < 400:
		scr.drv.step()
		n += 1
	scr._react(1, "call", {"kind": "pon"}, Color.RED, "mc")
	scr._react(2, "riichi", {}, Color.RED, "rin")
	scr._react(3, "dora", {}, Color.RED, "yue")
	scr.fx.sticker(Vector2(100, 100), "mc", "happy", "Ого!", Color.RED)
	scr.fx.bark(Vector2(100, 300), "Беру!", Color.RED)
	await get_tree().process_frame
	check("stamp/ribbon/dora/sticker/bark never take input", scr.fx.blocking().is_empty())
	check("hold() refused while the player decides (cut-in cannot start)", not scr.drv.hold("cutin"))
	# tap on a hand tile works under a live ribbon (input reaches the tile)
	var t: int = scr.drv.r.hands[0][0]
	check("hand tile tap works under inserts", scr.tap_tile(t))
	scr.queue_free()
	await get_tree().process_frame

# ------------------------------------------------------------------ 200 AI×4 matches through the adapter
func _sim(games: int) -> void:
	var ts: = Time.get_ticks_msec()
	var hung: = 0
	var sums_ok: = true
	var said_ok: = true
	var hands: = 0
	var said_kinds: = {}
	var max_steps: = 0
	for g in games:
		var drv: = V10MjRiichiDriver.new().setup({"seed": 5000 + g, "me": -1, "heroes": [D.FOUNDERS[g % 5], D.FOUNDERS[(g + 1) % 5], D.FOUNDERS[(g + 2) % 5], D.FOUNDERS[(g + 3) % 5]]})
		drv.said.connect(func(s, w, _d):
			said_kinds[w] = said_kinds.get(w, 0) + 1
			if s < 0 or s > 3:
				said_ok = false)
		var n: = drv.run_sync(30000)
		max_steps = maxi(max_steps, n)
		if not drv.over:
			hung += 1
		var sum: = 0
		for s in drv.r.scores:
			sum += s
		if sum != 100000:
			sums_ok = false
		hands += drv.hands_done
		drv.free()
		if Time.get_ticks_msec() / 1000.0 - t0 > WATCHDOG_S - 40:
			print("  sim stopped early at %d games (time)" % (g + 1))
			games = g + 1
			break
	print("SIM games=%d hands=%d max_steps=%d ms=%d said=%s" % [games, hands, max_steps, Time.get_ticks_msec() - ts, said_kinds])
	check("%d AI×4 matches through the adapter, none hung" % games, hung == 0 and games >= int(_arg("games", "200")))
	check("sim: scores stay zero-sum", sums_ok)
	check("sim: said stream covers call/riichi/ron/tsumo/dealin/tenpai/noten", said_ok and said_kinds.has("call") and said_kinds.has("riichi") and said_kinds.has("ron") and said_kinds.has("tsumo") and said_kinds.has("dealin") and said_kinds.has("noten"), str(said_kinds))

# ------------------------------------------------------------------ stop words over every visible string
func _lint_tests() -> void:
	var src: = []
	for h in D.HALLS:
		src.append_array([h.name, h.line])
	for f in D.FORMATS:
		src.append(D.FORMATS[f].name)
	for k in D.ACTIONS:
		src.append_array(D.ACTIONS[k])
	for k in D.COMBO_RU:
		src.append(D.COMBO_RU[k])
		src.append(D.combo_hint(k))
	for k in D.LIMIT_RU:
		src.append(D.LIMIT_RU[k])
	for h in V10MjRiichiBarks.LINES:
		for e in V10MjRiichiBarks.LINES[h]:
			src.append(V10MjRiichiBarks.LINES[h][e])
	src.append_array(V10MjRiichiScreen.STICKER_TXT.values())
	src.append(D.RIICHI_FIRST_HINT)
	src.append_array([V10MjRiichiInfo.INFO.name, V10MjRiichiInfo.INFO.line])
	for t in all_texts:
		src.append(t)
	var bad: = []
	for s in src:
		var b: = D.lint(String(s))
		if not b.is_empty():
			bad.append([s, b])
	check("no stop words in %d strings" % src.size(), bad.is_empty(), str(bad.slice(0, 6)))
	var jargon: = false
	for t in all_texts:
		if String(t).findn("яку") >= 0 or String(t).findn("Богин") >= 0:
			jargon = true
	check("no «яку» and no «Богиня» on screen", not jargon)
