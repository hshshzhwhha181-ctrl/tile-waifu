class_name TWCoreAuditSelftest
extends RefCounted

# Brief A independent audit test suite:
#   1. Minimal reproducing regression tests for every bug found in game/core/* and game/shell/* (A-01..A-10).
#   2. Property / fuzz tests for TWBoard (150 seeded configs across shapes, specials, re-deals, certificates, replay,
#      snapshot/restore) and TWSave + TWMigrate round-trips (150 random saves spanning ver 0..8).
# Pure test harness: never touches G or the player's live save; uses user://tw_core_audit_selftest/.

const DIR: = "user://tw_core_audit_selftest/"
const FAKE_SCR: = "res://shell/nav/nav_fake_screen.gd"
const EXIT_MODAL_SCR: = "res://tests/core_audit/exit_modal_screen.gd"
const AUDIT_NOW: = 1_795_000_000

var host: Node
var _pass: = 0
var _fail: = 0


class SelfClosingModal extends TWModal:
	func _build(_opts: Dictionary) -> void:
		close("auto", "self_close")


class CustomResolver extends TWAssetResolver:
	func _init() -> void:
		family = "audit_custom"

	func path_of(args: PackedStringArray) -> String:
		return "res://audit/%s.png" % args[0] if args.size() == 1 and args[0] != "" else ""


func check(name: String, ok: bool, info: String = "") -> void:
	if ok:
		_pass += 1
		print("PASS ", name)
	else:
		_fail += 1
		printerr("FAIL ", name, " ", info)


func run(p_host: Node) -> Array:
	host = p_host
	DirAccess.make_dir_recursive_absolute(DIR)
	_test_a01_migrate_determinism()
	_test_a02_invalid_dates_and_now()
	_test_a03_save_utf8_and_semantic_bak()
	_test_a04_board_redeal_clean()
	_test_a05_bomb_blast_unchain()
	await _test_a06_screens_go_tab_and_exit_modal()
	_test_a07_modal_open_order_and_freed_guard()
	_test_a08_bus_leaks_and_batch_order()
	_test_a09_assets_keep_custom_resolvers()
	_test_a10_clock_monotonic_nonnegative()
	_prop_twboard_solvability_and_replay()
	_prop_twsave_migrate_roundtrip()
	var total: = _pass + _fail
	print("CORE_AUDIT_SELFTEST %d/%d" % [_pass, total])
	return [_pass, total]


# ── A-01: TWMigrate._new_profile determinism (no unseeded randi()) ───────────────────────────────────────────

func _test_a01_migrate_determinism() -> void:
	var legacy: = {"gems": 100, "unlocked": 4, "stars": {"0": 2}, "owned": {}, "ver": 5}
	var ctx: = {"now": AUDIT_NOW, "modules": false}
	var r1: = TWMigrate.apply(legacy, ctx)
	var r2: = TWMigrate.apply(legacy, ctx)
	var id1: String = str(r1.state.get("profile", {}).get("id", ""))
	var id2: String = str(r2.state.get("profile", {}).get("id", ""))
	check("A-01: TWMigrate.apply(v5) without new_profile callback is deterministic",
		bool(r1.ok) and bool(r2.ok) and id1 != "" and id1 == id2 and TWState.state_hash_of(r1.state) == TWState.state_hash_of(r2.state),
		"id1=%s id2=%s" % [id1, id2])


# ── A-02: Calendar validation in TWClock & V10Save._latest_key + explicit now ───────────────────────────────

func _test_a02_invalid_dates_and_now() -> void:
	# Impossible calendar dates must be rejected by TWClock.bind so day_key() is never frozen forever.
	for bad_key in ["9999-99-99", "2026-13-01", "2026-00-10", "2026-02-30", "2025-02-29", "zzzz-zz-zz"]:
		var clk: = TWClock.fake(1_800_000_000, 0)
		clk.bind({"max_unix": 0, "srv_offset": 0, "last_key": bad_key, "days_seen": 1})
		check("A-02a: TWClock rejects impossible last_key '%s'" % bad_key,
			str(clk.st.last_key) == "" and clk.day_key() == "2027-01-15",
			"st.last_key=%s day=%s" % [str(clk.st.last_key), clk.day_key()])
	# Valid leap day must still be accepted.
	var leap: = TWClock.fake(1_709_200_000, 0)
	leap.bind({"max_unix": 0, "srv_offset": 0, "last_key": "2024-02-29", "days_seen": 1})
	check("A-02b: TWClock accepts valid leap date 2024-02-29", str(leap.st.last_key) == "2024-02-29")
	# V10Save.migrate must ignore garbage dates like "9999-99-99" / "zzzzzzzzzz" AND respect explicit `now`.
	V10Meta.unbind()
	V10Meta.clear_now()
	V10Meta.set_tz(0)
	var s_bad: = {"ver": 7, "gems": 10, "unlocked": 1, "daily_day": "9999-99-99", "tasks": {"day": "zzzzzzzzzz"}, "login": {"n": 3, "last": "2099-99-99"}}
	V10Save.migrate(s_bad, AUDIT_NOW)
	V10Meta.clear_tz()
	var got_key: String = str(s_bad.get("v10_meta", {}).get("last_key", ""))
	# AUDIT_NOW = 1_795_000_000 = 2026-11-18 UTC
	check("A-02c: V10Save.migrate uses explicit `now` and rejects garbage dates",
		got_key == "2026-11-18",
		"got last_key='%s'" % got_key)


# ── A-03: TWSave UTF-8 byte budget + validated backup rotation ──────────────────────────────────────────────

func _test_a03_save_utf8_and_semantic_bak() -> void:
	var p: = DIR + "a03.json"
	var sv: = TWSave.new(p)
	sv.remove_all()
	# Part 1: Semantic validation protects .bak.json when live main is valid JSON `{}` (not a valid save).
	var good1: = JSON.stringify({"gems": 111, "unlocked": 2, "ver": 8, "stars": {}, "owned": {}})
	var good2: = JSON.stringify({"gems": 222, "unlocked": 3, "ver": 8, "stars": {}, "owned": {}})
	sv.write(good1)
	sv.write(good2)   # now main=222, bak=111
	# Overwrite main with semantically broken JSON dict `{}` (syntax OK, missing required keys)
	var f: = FileAccess.open(p, FileAccess.WRITE)
	f.store_string("{}")
	f.close()
	var clk: = TWClock.fake(AUDIT_NOW, 0)
	var st: = TWState.new(TWSave.new(p), clk, {"now": AUDIT_NOW, "modules": false})
	var status: = st.load_game()
	check("A-03a: TWState recovers from bak when main is '{}'", status == "recovered" and int(st.data.gems) == 111, status)
	st.data["gems"] = 333
	st.flush(true)
	var bak_read: = TWSave.read_file(sv.bak_path())
	check("A-03b: flush over semantically invalid '{}' keeps good .bak and moves '{}' to .corrupt.json",
		bool(bak_read.ok) and int(bak_read.data.get("gems", -1)) == 111 and FileAccess.file_exists(sv.corrupt_path()),
		"bak=%s corrupt=%s" % [str(bak_read.data), str(FileAccess.file_exists(sv.corrupt_path()))])
	# Part 2: UTF-8 byte-size limit: a 2-byte Cyrillic char repeated 9_000_000 times has length < 16 MiB
	# but UTF-8 byte length = 18_000_000 > MAX_BYTES (16_777_216). write() must refuse it rather than
	# writing an unreadable >16 MiB file. (Use a smaller custom check via exact MAX_BYTES boundary!)
	var half_plus: int = (TWSave.MAX_BYTES / 2) + 1024   # 8_389_632 chars -> 16_779_264 UTF-8 bytes > MAX_BYTES
	var cyr: = "я".repeat(half_plus)
	var sv2: = TWSave.new(DIR + "a03_utf8.json")
	sv2.remove_all()
	var wrote_big: = sv2.write(cyr)
	check("A-03c: TWSave.write enforces MAX_BYTES on UTF-8 byte length, not String.length()",
		not wrote_big and sv2.last_error == "too big" and not FileAccess.file_exists(sv2.path),
		"wrote=%s err=%s" % [str(wrote_big), sv2.last_error])
	sv.remove_all()
	sv2.remove_all()


# ── A-04: TWBoard.deal() re-deal resets prior specials & flags ──────────────────────────────────────────────

func _test_a04_board_redeal_clean() -> void:
	var cfg1: = {
		"cols": 6, "rows": 7, "layers": 3, "faces": 12, "seed": 42, "deal_seed": 42,
		"gold": 6, "ice": 4, "hidden": true, "shard": "rin",
		"plan": {"lock": 1, "lock_n": 1, "chain": 1, "joker": 1, "bomb": 1, "gift": 1}
	}
	var b: = TWBoard.from_cfg(cfg1)
	var v1: = b.verify_certificate()
	check("A-04a: initial complex deal has valid certificate", v1.is_empty(), str(v1))
	# Re-deal the SAME board object with a plain config (no gold/ice/hidden/shard/specials)
	var cfg2: = {"cols": 6, "rows": 7, "layers": 3, "faces": 10, "seed": 42, "deal_seed": 99, "gold": 0, "ice": 0, "hidden": false}
	b.deal(cfg2, true)
	var leftover: = 0
	for i in b.n:
		if b.gold0[i] != 0 or b.ice0[i] != 0 or b.secret0[i] != 0 or b.shard0[i] != 0 or b.kind[i] != TWBoard.K_NONE or b.arg[i] != 0 or b.mate[i] != -1:
			leftover += 1
	var v2: = b.verify_certificate()
	check("A-04b: TWBoard.deal() clears all prior deal arrays (0 leftovers) and cert stays solvable",
		leftover == 0 and v2.is_empty() and not b.has_locks,
		"leftover=%d cert=%s has_locks=%s" % [leftover, str(v2), str(b.has_locks)])


# ── A-05: TWBoard._pair_gone emits UNCHAIN before bomb blast increments pairs_done ──────────────────────────

func _test_a05_bomb_blast_unchain() -> void:
	# Construct a minimal deterministic 6-tile board on layer 0:
	#   pair 0 (ids 0, 1): BOMB pair at (0,0) and (2,0) — adjacent so blast hits pair 1
	#   pair 1 (ids 2, 3): plain pair at (0,2) and (2,2) — within blast radius of pair 0
	#   pair 2 (ids 4, 5): CHAIN pair at (10,10) and (12,10) with arg = 1 (unlocks at pairs_done == 1)
	var b: = TWBoard.from_positions([
		Vector3i(0, 0, 0), Vector3i(2, 0, 0),
		Vector3i(0, 2, 0), Vector3i(2, 2, 0),
		Vector3i(10, 10, 0), Vector3i(12, 10, 0),
	], 4)
	b.face0 = PackedInt32Array([1, 1, 2, 2, 3, 3])
	b.step0 = PackedInt32Array([0, 0, 1, 1, 2, 2])
	b.kind = PackedByteArray([TWBoard.K_BOMB, TWBoard.K_BOMB, TWBoard.K_NONE, TWBoard.K_NONE, TWBoard.K_CHAIN, TWBoard.K_CHAIN])
	b.arg = PackedInt32Array([0, 0, 0, 0, 1, 1])
	b.mate = PackedInt32Array([1, 0, -1, -1, 5, 4])
	b.reset()
	check("A-05a: chain tiles start locked before match", not b.takeable(4) and not b.takeable(5))
	b.tap(0)
	var ev: Array = b.tap(1)   # matches bomb (pairs_done 0->1), blasts pair 1 (pairs_done 1->2)
	var unchained: Array = []
	for e in TWBoardEvents.of_type(ev, TWBoardEvents.UNCHAIN):
		unchained.append(int(e.id))
	unchained.sort()
	check("A-05b: bomb blast crossing chain threshold still emits UNCHAIN for ids 4 and 5 exactly once",
		b.pairs_done == 2 and b.takeable(4) and b.takeable(5) and unchained == [4, 5],
		"pairs_done=%d unchained=%s events=%s" % [b.pairs_done, str(unchained), str(TWBoardEvents.types(ev))])


# ── A-06: TWScreens.go_tab _pending leak, history wipe on rejection, exit() modal leak ──────────────────────

func _test_a06_screens_go_tab_and_exit_modal() -> void:
	var m: = TWScreens.new()
	var stack: = ModalStack.new()
	var ctx: = TWContext.build(null, null, TWBus.new(), m)
	ctx.provide("modals", stack)
	m.ctx = ctx
	host.add_child(m)
	host.add_child(stack)
	stack.bind_screens(m)
	m.register(ScreenSpec.make("home", FAKE_SCR, {"tab": "main", "is_tab_root": true}))
	m.register(ScreenSpec.make("map", FAKE_SCR, {"tab": "main"}))
	m.register(ScreenSpec.make("wish", FAKE_SCR, {"tab": "wish", "is_tab_root": true, "unlock_rule": "wish_open"}))
	m.register(ScreenSpec.make("exiter", EXIT_MODAL_SCR, {"tab": "main"}))
	var allow_wish: Array = [true]
	m.unlock_check = func(rule: String) -> bool: return allow_wish[0] if rule == "wish_open" else true
	# 1. go_tab must not leak _Nav objects into _pending
	m.go("home")
	for i in 10:
		m.go_tab("wish")
		m.go_tab("main")
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	check("A-06a: TWScreens.go_tab() does not leak _Nav entries in _pending",
		m._pending.is_empty(),
		"_pending.size()=%d" % m._pending.size())
	# 2. Rejected go_tab (locked or busy) must NOT wipe existing navigation history
	m.go("home")
	m.go("map")
	allow_wish[0] = false
	m.go_tab("wish")   # rejected as "locked"
	check("A-06b: locked go_tab() preserves history instead of wiping it",
		m.current_id == "map" and Array(m.history_ids()) == ["home"],
		"cur=%s hist=%s" % [m.current_id, str(m.history_ids())])
	# Also test busy go_tab preserves history
	allow_wish[0] = true
	m.go("map", {"intro": "hang"})
	# history still has ["home"] (same-id refresh keeps history)
	m.go_tab("wish")   # rejected as "busy"
	check("A-06c: busy go_tab() preserves history instead of wiping it",
		m.current_id == "map" and Array(m.history_ids()) == ["home"],
		"cur=%s hist=%s" % [m.current_id, str(m.history_ids())])
	m.reset()
	# 3. Modal opened inside outgoing screen's exit() must NOT survive onto the new screen
	m.go("exiter")
	m.go("home")
	check("A-06d: modal opened during outgoing screen exit() is swept before new screen mounts",
		stack.depth() == 0 and stack.get_child_count() == 0 and ModalStack.stop_visible_under(stack).is_empty(),
		"depth=%d children=%d" % [stack.depth(), stack.get_child_count()])
	m.reset()
	host.remove_child(m)
	m.free()
	host.remove_child(stack)
	stack.free()


# ── A-07: ModalStack.open signal order on self-closing _build + return value ────────────────────────────────

func _test_a07_modal_open_order_and_freed_guard() -> void:
	var s: = ModalStack.new()
	host.add_child(s)
	var seq: Array = []
	var depths: Array = []
	s.opened.connect(func(_mm): seq.append("opened"))
	s.closed.connect(func(_mm, reason): seq.append("closed:" + reason))
	s.changed.connect(func(d): depths.append(d))
	var sc: = SelfClosingModal.new()
	var res: = s.open(sc)
	check("A-07a: self-closing _build emits opened BEFORE closed (never opened after closed)",
		seq == ["opened", "closed:self_close"] and depths == [1, 0] and s.depth() == 0 and s.is_clean(),
		"seq=%s depths=%s depth=%d res=%s" % [str(seq), str(depths), s.depth(), str(res)])
	# Confirm queue_free() inside on_close (valid Godot pattern) leaves stack clean with 0 script errors
	var m_qf: = TWModal.new()
	var qf_hits: Array = [0]
	m_qf.on_close = func(_r, _why):
		qf_hits[0] += 1
		if is_instance_valid(m_qf):
			m_qf.queue_free()
	s.open(m_qf)
	var ok_close: = s.close(m_qf, null, "drop")
	check("A-07b: close() handles modal calling queue_free() inside on_close cleanly",
		ok_close and s.depth() == 0 and qf_hits[0] == 1)
	s.clear_all("done")
	host.remove_child(s)
	s.free()


# ── A-08: TWBus signal leak on unsubscribe, freed orphan owner, publish_all batch FIFO order ────────────────

func _test_a08_bus_leaks_and_batch_order() -> void:
	var b: = TWBus.new()
	# 1. Manual unsubscribe must disconnect owner.tree_exiting so connections do not accumulate
	var owner_n: = Node.new()
	host.add_child(owner_n)
	for i in 20:
		var tok: = b.subscribe("PING", func(_ev): pass, owner_n)
		b.unsubscribe(tok)
	var conns: int = owner_n.tree_exiting.get_connections().size()
	check("A-08a: unsubscribe() disconnects owner.tree_exiting (0 leaked connections)",
		conns == 0,
		"connections=%d" % conns)
	host.remove_child(owner_n)
	owner_n.free()
	# 2. Freed orphan Node owner (never entered tree) must not break unsubscribe_owner() or linger
	var orphan: = Node.new()
	var alive_n: = Node.new()
	b.subscribe("X", func(_ev): pass, orphan)
	b.subscribe("X", func(_ev): pass, alive_n)
	orphan.free()
	var removed: = b.unsubscribe_owner(alive_n)
	alive_n.free()
	check("A-08b: unsubscribe_owner() safely prunes freed orphan owners and removes target",
		removed == 1 and b.subscriber_count("X") == 0,
		"removed=%d remaining=%d" % [removed, b.subscriber_count("X")])
	# 3. publish_all([A, B]) must preserve FIFO batch order consistently whether top-level or nested
	var b2: = TWBus.new()
	var top_order: Array = []
	b2.subscribe("A", func(_ev):
		top_order.append("A")
		b2.publish({"t": "A_FOLLOW"}))
	b2.subscribe("B", func(_ev): top_order.append("B"))
	b2.subscribe("A_FOLLOW", func(_ev): top_order.append("A_FOLLOW"))
	b2.publish_all([{"t": "A"}, {"t": "B"}])
	check("A-08c: publish_all([A, B]) delivers full batch before handler-published follow-ups (FIFO)",
		top_order == ["A", "B", "A_FOLLOW"],
		"order=%s" % str(top_order))
	# 4. Single Node owner with multiple subscriptions drops ALL of them on tree_exiting
	var b3: = TWBus.new()
	var multi: = Node.new()
	host.add_child(multi)
	var mh: Array = [0]
	b3.subscribe("E1", func(_ev): mh[0] += 1, multi)
	b3.subscribe("E2", func(_ev): mh[0] += 10, multi)
	b3.subscribe("*", func(_ev): mh[0] += 100, multi)
	var n_conns: int = multi.tree_exiting.get_connections().size()
	host.remove_child(multi)
	multi.free()
	b3.publish_all([{"t": "E1"}, {"t": "E2"}])
	check("A-08d: single Node owner with 3 subscriptions uses 1 tree_exiting hook and drops all 3 on exit",
		n_conns == 1 and b3.subscriber_count() == 0 and mh[0] == 0,
		"conns=%d subs=%d hits=%d" % [n_conns, b3.subscriber_count(), mh[0]])


# ── A-09: TWAssets.install_manifest keeps custom resolvers ──────────────────────────────────────────────────

func _test_a09_assets_keep_custom_resolvers() -> void:
	TWAssets.quiet = true
	var r: = CustomResolver.new()
	TWAssets.register_resolver(r)
	TWAssets.install_manifest({"assets": [{"id": "audit.one", "path": "res://audit/one.png", "kind": "image", "status": "approved"}]})
	var info: = TWAssets.resolve("audit_custom:one")
	TWAssets.reset()
	TWAssets.quiet = false
	check("A-09: TWAssets.install_manifest() preserves registered custom resolvers and updates known map",
		bool(info.ok) and str(info.id) == "audit.one",
		str(info))


# ── A-10: TWClock.Fake.advance_ms monotonic non-decreasing ──────────────────────────────────────────────────

func _test_a10_clock_monotonic_nonnegative() -> void:
	var c: = TWClock.fake(AUDIT_NOW, 0)
	c.advance_ms(500)
	c.advance_ms(-1000)
	check("A-10: TWClock.Fake monotonic clock never moves backwards on negative advance_ms",
		c.mono_msec() == 500,
		"mono_msec=%d" % c.mono_msec())


# ── Property / Fuzz 1: TWBoard solvability, certificates, replay, snapshot/restore, re-deals ───────────────

func _prop_twboard_solvability_and_replay() -> void:
	var rng: = TWRng.make(20261128, 77)
	var shapes: = ["rect", "heart", "diamond", "butterfly", "cross", "ring", "pyramid", "towers"]
	var total_cases: = 150
	var bad_cert: = 0
	var bad_solver: = 0
	var bad_replay: = 0
	var bad_snap: = 0
	var bad_redeal: = 0
	var first_err: = ""
	for i in total_cases:
		var cfg: = {
			"cols": rng.rand_range(4, 6),
			"rows": rng.rand_range(5, 8),
			"layers": rng.rand_range(2, 4),
			"faces": rng.rand_range(6, 20),
			"fill": 0.55 + rng.rand_f() * 0.35,
			"shape": shapes[i % shapes.size()],
			"slots": rng.rand_range(3, 6),
			"seed": 1000 + i,
			"deal_seed": 20000 + i * 17,
			"gold": rng.rand_range(0, 6) * 2,
			"ice": rng.rand_range(0, 4),
			"hidden": rng.below(2) == 1,
			"shard": "mc" if rng.below(3) == 0 else "",
			"plan": {
				"lock": rng.below(2),
				"lock_n": rng.rand_range(1, 2),
				"chain": rng.below(2),
				"joker": rng.below(2),
				"bomb": rng.below(2),
				"gift": rng.below(2),
			}
		}
		var b: = TWBoard.from_cfg(cfg)
		# 1. Certificate must verify 100%
		var vc: = b.verify_certificate()
		if not vc.is_empty():
			bad_cert += 1
			if first_err == "":
				first_err = "cert case %d (%s): %s" % [i, cfg.shape, str(vc)]
			continue
		# 2. Snapshot / restore round-trip mid-game + replay determinism
		var b_play: = b.fork_fresh()
		var steps: = rng.rand_range(3, 12)
		var snap_mid: Dictionary = {}
		var hash_mid: = 0
		for s in steps:
			var t: = b_play.solver_move()
			if t < 0 or b_play.cleared or b_play.failed:
				break
			b_play.tap(t)
			if s == steps / 2:
				snap_mid = b_play.snapshot()
				hash_mid = b_play.state_hash()
		var rep: = b_play.export_replay()
		var end_hash: = b_play.state_hash()
		# Test snapshot restore back to mid-game
		if not snap_mid.is_empty():
			b_play.restore(snap_mid)
			if b_play.state_hash() != hash_mid:
				bad_snap += 1
				if first_err == "":
					first_err = "snap case %d: hash mismatch" % i
		# Test full replay from export_replay() on a fresh fork
		var b_rep: = b.fork_fresh()
		b_rep.play_replay(rep.taps)
		if b_rep.state_hash() != end_hash:
			bad_replay += 1
			if first_err == "":
				first_err = "replay case %d: hash %d != %d" % [i, b_rep.state_hash(), end_hash]
		# 3. Full solver must clear every board (with bombs enabled)
		var b_sol: = b.fork_fresh()
		var sr: = b_sol.play_solver(3000)
		if not bool(sr.cleared) or int(sr.left) != 0:
			bad_solver += 1
			if first_err == "":
				first_err = "solver case %d: %s" % [i, str(sr)]
		# 4. Re-deal on existing board object must be clean & verifiable (every 5th case)
		if i % 5 == 0:
			var plain_cfg: = {"seed": cfg.seed, "deal_seed": 90000 + i, "faces": 10}
			b_sol.deal(plain_cfg, true)
			var vr: = b_sol.verify_certificate()
			if not vr.is_empty() or b_sol.has_locks:
				bad_redeal += 1
				if first_err == "":
					first_err = "redeal case %d: %s" % [i, str(vr)]
	check("prop(TWBoard): %d/150 diverse seeded boards have 100%% valid certificates" % (total_cases - bad_cert), bad_cert == 0, first_err)
	check("prop(TWBoard): %d/150 diverse boards cleared by solver_move()" % (total_cases - bad_solver), bad_solver == 0, first_err)
	check("prop(TWBoard): 150/150 export_replay -> play_replay exact state_hash parity", bad_replay == 0, first_err)
	check("prop(TWBoard): 150/150 snapshot/restore exact state_hash parity", bad_snap == 0, first_err)
	check("prop(TWBoard): 30/30 re-deals on used boards clean & cert-solvable", bad_redeal == 0, first_err)


# ── Property / Fuzz 2: TWSave + TWMigrate round-trip across ver 0..8 ────────────────────────────────────────

func _prop_twsave_migrate_roundtrip() -> void:
	var rng: = TWRng.make(20261128, 99)
	var p: = DIR + "prop_rt.json"
	var sv_clean: = TWSave.new(p)
	sv_clean.remove_all()
	var n_cases: = 150
	var bad: = 0
	var first_err: = ""
	var heroes: = ["mc", "rin", "hana", "yue", "nova"]
	V10Meta.unbind()
	V10Meta.set_tz(0)
	for i in n_cases:
		var ver: int = i % 9    # covers v0, v1, v2, v3, v4, v5, v6, v7, v8
		var save: Dictionary = {
			"ver": ver,
			"gems": rng.rand_range(0, 50000),
			"coins": rng.rand_range(0, 200000),
			"unlocked": rng.rand_range(1, 48 if ver < 8 else 120),
			"stars": {},
			"owned": {"o_base": true},
			"partner": heroes[rng.below(heroes.size())],
			"fx_level": ["full", "mid", "min", "bogus"][rng.below(4)],
			"ult_cutin": ["full", "short", "off", "bad"][rng.below(4)],
		}
		var n_stars: = rng.rand_range(0, 24)
		for k in n_stars:
			save.stars[str(rng.rand_range(0, 47 if ver < 8 else 99))] = rng.rand_range(1, 3)
		if ver >= 6:
			save["profile"] = {"nick": "Игрок_%d" % i, "avatar": heroes[rng.below(heroes.size())], "frame": "", "created": AUDIT_NOW - 86400, "id": "%08x" % (i + 1)}
			save["profile_done"] = rng.below(2) == 1
		if ver == 6:
			save["v6_fx"] = {"shake": rng.below(2) == 1, "flash": rng.below(2) == 1}
		if ver == 7 and rng.below(3) == 0:
			save["daily_day"] = ["9999-99-99", "2026-11-18", "bad-date"][rng.below(3)]
		var ctx: = {"now": AUDIT_NOW, "modules": true, "levels_size": 1000, "heroes": heroes}
		# 1. Deterministic migration
		var a1: = TWMigrate.apply(save, ctx)
		var a2: = TWMigrate.apply(save, ctx)
		if not bool(a1.ok) or not bool(a2.ok):
			bad += 1
			if first_err == "":
				first_err = "case %d v%d: apply failed %s" % [i, ver, str(a1.reason)]
			continue
		var h1: = TWState.state_hash_of(a1.state)
		var h2: = TWState.state_hash_of(a2.state)
		if h1 != h2:
			bad += 1
			if first_err == "":
				first_err = "case %d v%d: non-deterministic hash %s != %s" % [i, ver, h1, h2]
			continue
		# 2. Idempotency (migrating migrated state changes nothing)
		var again: = TWMigrate.apply(a1.state, ctx)
		if not bool(again.ok) or TWState.state_hash_of(again.state) != h1:
			bad += 1
			if first_err == "":
				first_err = "case %d v%d: not idempotent" % [i, ver]
			continue
		# 3. Disk round-trip via TWSave + TWState
		sv_clean.remove_all()
		var st1: = TWState.new(TWSave.new(p), TWClock.fake(AUDIT_NOW, 0), ctx)
		if not st1.apply_state(save) or not st1.flush(true):
			bad += 1
			if first_err == "":
				first_err = "case %d v%d: flush failed (%s)" % [i, ver, st1.save.last_error]
			continue
		var st2: = TWState.new(TWSave.new(p), TWClock.fake(AUDIT_NOW, 0), ctx)
		var load_st: = st2.load_game()
		if load_st != "loaded" or st2.state_hash() != st1.state_hash() or int(st2.data.ver) != TWMigrate.SAVE_VER:
			bad += 1
			if first_err == "":
				first_err = "case %d v%d: round-trip mismatch status=%s ver=%s" % [i, ver, load_st, str(st2.data.get("ver"))]
			continue
		# 4. Valid last_key in v10_meta (never frozen by garbage)
		var lk: String = str(st2.data.get("v10_meta", {}).get("last_key", ""))
		if not TWClock._valid_key(lk):
			bad += 1
			if first_err == "":
				first_err = "case %d v%d: invalid last_key '%s'" % [i, ver, lk]
	V10Meta.clear_tz()
	sv_clean.remove_all()
	check("prop(TWSave+TWMigrate): %d/%d random v0..v8 saves pass deterministic migration, idempotency, and disk round-trip" % [n_cases - bad, n_cases],
		bad == 0, first_err)
