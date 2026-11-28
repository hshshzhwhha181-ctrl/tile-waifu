extends Control

# Runner for P77 AT-B10: 60 Campaign stages x 3 certified seeds = 180 boards verified on real TWBoard!
# Run via godot_lock.ps1:
#   & $env:GODOT_BIN --headless --audio-driver Dummy --path game res://tests/battle/stages_selftest.tscn

var _ok: int = 0
var _total: int = 0
var _fails: Array = []


func _chk(cond: bool, what: String) -> void:
	_total += 1
	if cond:
		_ok += 1
	else:
		_fails.append(what)
		print("  FAIL ", what)


func _ready() -> void:
	await get_tree().process_frame
	_run_all()
	var tag: String = "OK" if _ok == _total else "FAIL"
	print("BATTLE_STAGES_SELFTEST %d/%d %s" % [_ok, _total, tag])
	get_tree().quit(0 if _ok == _total else 1)


func _run_all() -> void:
	TWBattleData.clear_cache()
	var doc: Dictionary = TWBattleData.stages()
	var bal: Dictionary = TWBattleData.balance()
	_chk(not doc.is_empty(), "stages.json loaded from TWBattleData.STAGES_PATH")

	# Byte parity with canonical data/battle/stages.json
	var mirror_b: PackedByteArray = TWBattleData.raw_bytes(TWBattleData.STAGES_PATH)
	var canon_path: String = "res://../data/battle/stages.json"
	if FileAccess.file_exists(canon_path):
		var canon_b: PackedByteArray = TWBattleData.raw_bytes(canon_path)
		_chk(mirror_b == canon_b and mirror_b.size() > 0,
			"stages.json mirror == data/battle/stages.json (%d bytes)" % mirror_b.size())

	var stages: Array = doc.get("stages", [])
	_chk(stages.size() == 60, "AT-B10: stages count == 60 (got %d)" % stages.size())
	_chk(int(doc.get("first_clear_gems_total", 0)) == 600, "60 stages first_clear_gems_total == 600")
	_chk(int(doc.get("balance_k_normal_bp", 0)) == int(bal.get("shield_and_boss", {}).get("k_normal_bp", -1)),
		"stages.json synced with balance.json k_normal_bp")

	var cert_pass: int = 0
	var cert_total: int = 0
	var suit_min2_pass: int = 0
	var suit_tilt_pass: int = 0
	var suit_tilt_total: int = 0
	var blind_pass: int = 0
	var gems_sum: int = 0
	var boss_chapters_seen: Dictionary = {}

	for idx in stages.size():
		var st: Dictionary = stages[idx]
		var st_num: int = int(st.get("stage", 0))
		var ch: int = int(st.get("chapter", 0))
		for g in st.get("rewards", {}).get("first_clear_gems", []):
			gems_sum += int(g)
		if String(st.get("type", "")) == "boss":
			boss_chapters_seen[ch] = String(st.get("boss_id", ""))
		var sw: Dictionary = st.get("suit_weights", {})
		var seeds: Array = st.get("seeds", [])
		for s_i in seeds.size():
			cert_total += 1
			var bdef: Dictionary = seeds[s_i]
			var board: TWBoard = TWBattleBoardDeal.from_certified_board(bdef)
			var ver: Dictionary = board.verify_certificate()
			if ver.is_empty():
				cert_pass += 1
			else:
				print("  CERT FAIL stage=%d seed=%d: %s" % [st_num, s_i, str(ver)])

			var audit: Dictionary = TWBattleBoardDeal.audit_suit_distribution(board)
			var df: Dictionary = audit.distinct_faces
			var pc: Dictionary = audit.pair_counts
			if int(df.man) >= 2 and int(df.pin) >= 2 and int(df.sou) >= 2:
				suit_min2_pass += 1

			var w_man: int = int(sw.get("man", 0))
			var w_pin: int = int(sw.get("pin", 0))
			var w_sou: int = int(sw.get("sou", 0))
			var w_max: int = maxi(w_man, maxi(w_pin, w_sou))
			var w_min: int = mini(w_man, mini(w_pin, w_sou))
			if w_max - w_min >= 15:
				suit_tilt_total += 1
				var heavy_suit: String = "man" if w_man == w_max else ("pin" if w_pin == w_max else "sou")
				var light_suit: String = "man" if w_man == w_min else ("pin" if w_pin == w_min else "sou")
				if int(pc[heavy_suit]) > int(pc[light_suit]):
					suit_tilt_pass += 1

			# Also run real TWBoard blind solver_move() on seed 0 of every stage (60 full blind solves!)
			if s_i == 0:
				var fb: TWBoard = board.fork_fresh()
				var guard: int = 0
				while not fb.cleared and not fb.failed and guard < 400:
					guard += 1
					var mv: int = fb.solver_move()
					if mv < 0:
						mv = fb.best_move()
					if mv < 0:
						break
					fb.tap(mv)
				if fb.cleared:
					blind_pass += 1

	print("  AT-B10 summary: cert=%d/%d min2_suits=%d/%d tilt=%d/%d blind_solver=%d/60 gems=%d bosses=%s" % [
		cert_pass, cert_total, suit_min2_pass, cert_total, suit_tilt_pass, suit_tilt_total,
		blind_pass, gems_sum, str(boss_chapters_seen)
	])
	_chk(cert_total == 180 and cert_pass == 180, "AT-B10: all boards pass TWBoard.verify_certificate() (%d/%d)" % [cert_pass, cert_total])
	_chk(suit_min2_pass == 180, "AT-B10: >= 2 distinct faces per suit on all 180 boards (%d/180)" % suit_min2_pass)
	_chk(suit_tilt_total > 0 and suit_tilt_pass == suit_tilt_total, "AT-B10: suit_weights tilt honored (%d/%d)" % [suit_tilt_pass, suit_tilt_total])
	_chk(blind_pass == 60, "AT-B10: TWBoard blind solver clears 60/60 stages (%d/60)" % blind_pass)
	_chk(gems_sum == 600, "Campaign first-clear gems sum == 600")
	_chk(boss_chapters_seen.size() == 6, "All 6 chapter bosses present (got %d)" % boss_chapters_seen.size())

	# End-to-end integration: TWBattleBot plays Chapter 1 Boss (stage 10) certified board through TWBattle
	var st10: Dictionary = stages[9]
	var bd10: TWBoard = TWBattleBoardDeal.from_certified_board(st10.seeds[0])
	var sq_specs: Array = TWBattleBot.build_profile_squad("P0 F2P-max", [], bal)
	var bt10: TWBattle = TWBattle.create(7710, sq_specs, {
		"boss_hp": int(st10.boss_hp),
		"ref_team_hp": int(st10.ref_team_hp),
		"weak": String(st10.weak),
		"resist": String(st10.resist),
		"shield_units": int(st10.shield_units),
		"cadence": int(st10.cadence),
		"waves": st10.waves,
	}, bal)
	var r10: Dictionary = TWBattleBot.play_board_fight(bt10, bd10, TWRng.make(7710, 1), true)
	_chk(bool(r10.won) and not bool(r10.saw_full_mode), "End-to-end stage 10 boss certified board beaten by TWBattleBot")
