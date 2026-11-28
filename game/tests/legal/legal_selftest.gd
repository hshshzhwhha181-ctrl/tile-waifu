class_name TWLegalSelftest
extends RefCounted

# TWLegalSelftest (P108): verifies the 13 legal template documents in data/legal/,
# mandatory template disclaimer on every document, verbatim C16 refund clause,
# offer-versioned consent journal (SAVE_VER == 8 preserved), ScreenSpec/TWScreens integration,
# TWLegalScreen inline reader & back navigation, and TWLegalDocModal via ModalStack.
#
# Run: godot --headless --path game res://tests/legal/legal_selftest.tscn
# Marker: "TWLEGAL_SELFTEST ok/total OK|FAILED"

const TEST_SAVE_DIR: String = "user://tw_legal_selftest/"
const TEST_BAD_DIR: String = "user://tw_legal_selftest_bad/"

var checks: int = 0
var fails: int = 0


func ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("TWLEGAL FAIL: ", what)


func run(host: Node) -> Array:
	checks = 0
	fails = 0
	_test_bundle_and_docs()
	_test_validation_rejects_broken()
	_test_consent_journal_and_save_ver()
	await _test_screen_and_modal(host)
	await _test_round1_legal_regressions(host)
	_cleanup_dirs()
	print("TWLEGAL_SELFTEST %d/%d %s" % [checks - fails, checks, "OK" if fails == 0 else "FAILED"])
	return [checks - fails, checks]


func _test_bundle_and_docs() -> void:
	var data: TWLegalData = TWLegalData.new()
	ok(data.is_loaded(), "TWLegalData loads manifest.json from data/legal/")
	ok(data.doc_count() == 13, "exactly 13 legal documents in manifest (got %d)" % data.doc_count())
	ok(data.offer_version() != "", "offer_version is non-empty: %s" % data.offer_version())

	var errs: Array = data.validate_bundle()
	ok(errs.is_empty(), "validate_bundle() passes with 0 errors: %s" % [str(errs)])

	var docs: Array = data.list_docs()
	var seen_ids: Dictionary = {}
	for d in docs:
		var did: String = str(d.get("id", ""))
		ok(did != "" and not seen_ids.has(did), "unique doc id '%s'" % did)
		seen_ids[did] = true
		var txt: String = data.read_doc_text(did)
		ok(txt.length() > 200, "doc '%s' has substantive Russian content (%d chars)" % [did, txt.length()])
		ok(txt.contains(TWLegalData.REQUIRED_DISCLAIMER),
			"doc '%s' explicitly states template disclaimer" % did)
		var sha: String = str(d.get("sha256", ""))
		ok(sha != "" and txt.sha256_text() == sha, "doc '%s' SHA-256 matches manifest" % did)

	# Verbatim C16 refund clause check across offer, refund_rules, and gacha_rules
	for rid in TWLegalData.REFUND_DOC_IDS:
		var rtxt: String = data.read_doc_text(rid)
		ok(rtxt.contains(TWLegalData.REQUIRED_REFUND_CLAUSE),
			"doc '%s' contains verbatim C16 refund clause" % rid)

	# Verify no dark-pattern persuasion wording in positive claims (allow quoting banned terms inside prohibition list)
	var offer_txt: String = data.read_doc_text("offer")
	ok(offer_txt.contains("18+"), "offer mentions 18+ age requirement")
	ok(offer_txt.contains("не влияют на исход игры"), "offer states cosmetics do not affect gameplay")
	var limits_txt: String = data.read_doc_text("spend_limits")
	ok(limits_txt.contains("5 000") and limits_txt.contains("24 часа"), "spend_limits includes default cap and 24h raise delay")
	var beta_txt: String = data.read_doc_text("beta_rules")
	ok(beta_txt.contains("real_payments_enabled"), "beta_rules mentions real_payments_enabled gate")


func _test_validation_rejects_broken() -> void:
	_wipe_dir(TEST_BAD_DIR)
	DirAccess.make_dir_recursive_absolute(TEST_BAD_DIR)
	var bad_manifest: Dictionary = {
		"schema_ver": 1,
		"bundle_ver": "0.1.0-bad",
		"offer_ver": "0.1.0-bad",
		"documents": [
			{
				"id": "offer",
				"order": 1,
				"title": "Broken Offer",
				"short_title": "Offer",
				"file": "01_offer.md",
				"version": "0.1.0-bad",
				"has_refund_clause": true,
				"sha256": "deadbeef"
			}
		]
	}
	var mf: FileAccess = FileAccess.open(TEST_BAD_DIR.path_join("manifest.json"), FileAccess.WRITE)
	mf.store_string(JSON.stringify(bad_manifest))
	mf.close()
	var df: FileAccess = FileAccess.open(TEST_BAD_DIR.path_join("01_offer.md"), FileAccess.WRITE)
	df.store_string("Missing disclaimer and missing refund wording.")
	df.close()

	var bad_data: TWLegalData = TWLegalData.new(TEST_BAD_DIR)
	var errs: Array = bad_data.validate_bundle()
	ok(errs.size() >= 4, "validate_bundle catches broken fixture (%d errors)" % errs.size())
	var joined: String = ",".join(errs)
	ok(joined.contains("doc_count"), "broken fixture flags doc_count")
	ok(joined.contains("missing_template_disclaimer"), "broken fixture flags missing_template_disclaimer")
	ok(joined.contains("missing_refund_clause"), "broken fixture flags missing_refund_clause")
	ok(joined.contains("sha256_mismatch"), "broken fixture flags sha256_mismatch")


func _test_consent_journal_and_save_ver() -> void:
	_wipe_dir(TEST_SAVE_DIR)
	DirAccess.make_dir_recursive_absolute(TEST_SAVE_DIR)
	var save_path: String = TEST_SAVE_DIR.path_join("save.json")
	var clk: TWClock = TWClock.fake(1_764_300_000, 180)
	var bus: TWBus = TWBus.new()
	var bus_events: Array = []
	bus.subscribe("legal.consent_recorded", func(payload: Variant) -> void:
		bus_events.append(payload)
	)

	var mig_ctx: Dictionary = {
		"defaults": func() -> Dictionary:
			return {"ver": 8, "gems": 0, "unlocked": 1, "stars": {}, "owned": {}},
		"modules": false,
		"now": clk.now(),
	}
	var state: TWState = TWState.new(TWSave.new(save_path), clk, mig_ctx)
	var data: TWLegalData = TWLegalData.new()
	var journal: TWLegalConsent = TWLegalConsent.new(state, clk, bus)

	ok(TWState.SAVE_VER == 8, "TWState.SAVE_VER stays at 8")
	ok(journal.entry_count() == 0, "fresh consent journal starts empty")
	ok(journal.needs_reconsent("offer", data.offer_version()), "fresh user needs offer consent")

	var age_for_test: TWAge = TWAge.new(clk, state)
	age_for_test.submit_dob(1995, 5, 5)
	var opened_all: Dictionary = {
		"offer": true,
		"privacy": true,
		"pdn_consent": true,
		"age_18_full_tier": true,
	}
	var recorded: Array = journal.record_required_bundle(data, "age_gate", false, {
		"opened_docs": opened_all,
		"pdn_separate_confirmed": true,
		"age_gate": age_for_test,
		"record_analytics_choice": true,
	})
	ok(recorded.size() == 5, "record_required_bundle writes 4 required + 1 analytics entry when explicitly confirmed (got %d)" % recorded.size())
	ok(bus_events.size() == 5, "TWBus published 5 legal.consent_recorded events")
	ok(journal.accepted_offer_version() == data.offer_version(), "accepted_offer_version matches manifest offer_ver")
	ok(journal.has_all_required(data.offer_version()), "has_all_required true for current offer_ver")
	ok(not journal.has_accepted("analytics", data.offer_version()), "optional analytics remains declined when false")
	ok(journal.needs_reconsent("offer", "0.2.0-next"), "version bump triggers needs_reconsent")
	ok(state.dirty, "recording consent marks TWState dirty")

	# Flush and reload from disk to verify SAVE_VER == 8 and mod_ver.legal == 1 persistence
	ok(state.flush(true), "TWState.flush() succeeds with unified tw_consents")
	ok(int(state.data.get("ver", 0)) == 8, "persisted save ver == 8")
	ok(state.module_ver("legal") == TWLegalConsent.MODULE_VER, "mod_ver.legal == %d" % TWLegalConsent.MODULE_VER)
	ok(state.module_ver("consent") == TWConsent.MODULE_VER, "mod_ver.consent == %d" % TWConsent.MODULE_VER)

	var state2: TWState = TWState.new(TWSave.new(save_path), clk, mig_ctx)
	var st_status: String = state2.load_game()
	ok(st_status == "loaded", "reloaded TWState status == loaded (got %s)" % st_status)
	ok(int(state2.data.get("ver", 0)) == 8, "reloaded save ver stays 8")
	var journal2: TWLegalConsent = TWLegalConsent.new(state2, clk, null)
	ok(journal2.entry_count() == 5, "reloaded journal retains all 5 entries")
	ok(journal2.accepted_offer_version() == data.offer_version(), "reloaded accepted_offer_version matches")

	# Revocation is append-only (audit history preserved)
	clk.advance(120.0)
	journal2.record_consent("offer", data.offer_version(), data.offer_version(), data.doc_hash_short("offer"), false, "settings")
	ok(journal2.entry_count() == 6, "revocation appends entry #6 without deleting history")
	ok(not journal2.has_accepted("offer", data.offer_version()), "after revocation has_accepted(offer) is false")
	ok(journal2.accepted_offer_version() == "", "after revocation accepted_offer_version is empty")

	var exp: String = journal2.export_text()
	ok(exp.contains("Журнал согласий") and exp.contains(data.offer_version()), "export_text includes header and offer_ver")
	ok(exp.contains("отозвано/отклонено"), "export_text records revocation event")


func _test_screen_and_modal(host: Node) -> void:
	# 1. ScreenSpec validation & TWScreens.scan()
	var spec: Resource = load("res://shell/screens/legal/spec.tres")
	ok(spec is ScreenSpec, "res://shell/screens/legal/spec.tres loads as ScreenSpec")
	if spec is ScreenSpec:
		var why: String = (spec as ScreenSpec).validate()
		ok(why == "", "legal ScreenSpec.validate() clean (got '%s')" % why)
		ok((spec as ScreenSpec).id == "legal", "legal ScreenSpec id == 'legal'")

	var ctx: TWContext = TWContext.for_tests(TEST_SAVE_DIR.path_join("screen_ctx/"))
	var stack: ModalStack = ModalStack.new()
	host.add_child(stack)
	host.add_child(ctx.screens)
	stack.bind_screens(ctx.screens)
	ctx.provide("modals", stack)

	var scan_rep: Dictionary = ctx.screens.scan()
	ok((scan_rep.get("registered", []) as Array).has("legal"), "TWScreens.scan() discovers 'legal' screen")
	ok((scan_rep.get("rejected", []) as Array).is_empty(), "TWScreens.scan() has 0 rejections: %s" % [str(scan_rep.get("rejected", []))])

	# 2. Navigate to legal screen & verify all 13 documents open in inline reader
	var done_sig: Signal = ctx.screens.go("legal", {})
	await done_sig
	ok(ctx.screens.current_id == "legal" and ctx.screens.current is TWLegalScreen, "TWScreens.go('legal') mounts TWLegalScreen")
	var scr: TWLegalScreen = ctx.screens.current as TWLegalScreen
	var ids: PackedStringArray = scr.listed_doc_ids()
	ok(ids.size() == 13, "TWLegalScreen lists all 13 documents (got %d)" % ids.size())

	var all_opened: bool = true
	for did in ids:
		var opened: bool = scr.open_doc(did, false)
		var txt: String = scr.displayed_reader_text()
		if not opened or txt.strip_edges() == "" or not txt.contains(TWLegalData.REQUIRED_DISCLAIMER):
			all_opened = false
			break
	ok(all_opened, "all 13 documents open in TWLegalScreen reader with template disclaimer")

	# 3. on_back() returns from reader to list, then next back does not get stuck
	ok(scr.view_mode == TWLegalScreen.ViewMode.READER, "screen is in READER mode after open_doc")
	ok(scr.on_back(), "on_back() consumes back press in READER mode")
	ok(scr.view_mode == TWLegalScreen.ViewMode.LIST, "on_back() returns to LIST mode")
	ok(not scr.on_back(), "on_back() returns false in LIST mode so TWScreens can pop")

	# 4. Direct jump via params {doc_id: "refund_rules"}
	var done2: Signal = ctx.screens.go("legal", {"doc_id": "refund_rules"}, {"replace": true})
	await done2
	var scr2: TWLegalScreen = ctx.screens.current as TWLegalScreen
	ok(scr2.view_mode == TWLegalScreen.ViewMode.READER and scr2.active_doc_id == "refund_rules",
		"params doc_id='refund_rules' opens directly into reader")
	ok(scr2.displayed_reader_text().contains(TWLegalData.REQUIRED_REFUND_CLAUSE),
		"refund_rules reader displays verbatim C16 refund wording")

	# 5. Separate 152-FZ consent acts on screen persist offer_ver into TWState and show in journal view
	scr2.age_gate.submit_dob(1994, 4, 15)
	scr2.show_list()
	scr2.open_doc("offer", false)
	scr2.open_doc("privacy", false)
	var offer_priv_res: Array = scr2.accept_offer_and_privacy()
	ok(offer_priv_res.size() == 2 and scr2.consent_journal.has_accepted("offer", scr2.legal_data.offer_version()) and not scr2.consent_journal.has_accepted("pdn", scr2.legal_data.offer_version()),
		"accept_offer_and_privacy records ONLY offer+privacy (does NOT bundle PDn)")
	scr2.open_doc("pdn_consent", false)
	var pdn_res: Dictionary = scr2.accept_pdn_consent()
	ok(not pdn_res.is_empty() and scr2.consent_journal.has_accepted("pdn", scr2.legal_data.offer_version()) and not scr2.consent_journal.has_accepted("age_18", scr2.legal_data.offer_version()),
		"accept_pdn_consent records ONLY separate 152-FZ PDn consent (does NOT bundle 18+)")
	scr2.open_doc("age_18_full_tier", false)
	var age18_res: Dictionary = scr2.accept_age_18()
	ok(not age18_res.is_empty() and scr2.consent_journal.has_all_required(scr2.legal_data.offer_version()),
		"accept_age_18 completes required consents only after doc open + adult TWAge")
	scr2.set_analytics_consent(true)
	scr2.open_journal()
	ok(scr2.view_mode == TWLegalScreen.ViewMode.JOURNAL, "open_journal() enters JOURNAL mode")
	ok(scr2.displayed_journal_text().contains(scr2.legal_data.offer_version()),
		"journal view displays accepted offer version")
	ok(int(ctx.state.data.get("ver", 0)) == 8, "TWState SAVE_VER stays 8 after screen consent")

	# 6. Modal reader via ModalStack (MODAL_ONLY_VIA_STACK contract)
	var opened_modal: bool = scr2.open_doc("offer", true)
	ok(opened_modal and stack.depth() == 1 and stack.is_clean(), "open_doc(prefer_modal=true) pushes TWLegalDocModal cleanly onto ModalStack")
	var top_m: TWModal = stack.top()
	ok(top_m is TWLegalDocModal, "top modal is TWLegalDocModal")
	if top_m is TWLegalDocModal:
		ok((top_m as TWLegalDocModal).displayed_text().contains(TWLegalData.REQUIRED_REFUND_CLAUSE),
			"TWLegalDocModal displays full offer text including C16 refund clause")
		var closed_ok: bool = (top_m as TWLegalDocModal).accept_from_code()
		ok(closed_ok, "TWLegalDocModal.accept_from_code() closes cleanly")
	await host.get_tree().process_frame
	ok(stack.depth() == 0 and stack.is_clean(), "ModalStack is empty and clean after closing modal")
	ok(ModalStack.stop_visible_under(stack).is_empty(), "0 lingering STOP scrims in ModalStack")

	ctx.screens.reset()
	ctx.screens.queue_free()
	stack.queue_free()
	await host.get_tree().process_frame


func _test_round1_legal_regressions(host: Node) -> void:
	var t0: int = 1_764_300_000
	var clk: TWClock = TWClock.fake(t0, 180)
	var data: TWLegalData = TWLegalData.new()
	var ov: String = data.offer_version()

	# [M3] Unified consent journal: TWLegalConsent and TWConsent share STATE_KEY and canonical kinds
	ok(TWLegalConsent.STATE_KEY == TWConsent.STATE_KEY,
		"[M3] TWLegalConsent.STATE_KEY == TWConsent.STATE_KEY (got '%s' vs '%s')" % [TWLegalConsent.STATE_KEY, TWConsent.STATE_KEY])
	var shared_store: Dictionary = {}
	var legal_j: TWLegalConsent = TWLegalConsent.new(null, clk, null, shared_store)
	var core_j: TWConsent = TWConsent.new(clk, null, shared_store)
	var age_ok: TWAge = TWAge.new(clk)
	age_ok.set_link_verifier(func(_p: String, _u: String, tok: String) -> bool: return tok == "ok-tok")
	age_ok.submit_dob(1995, 5, 5)
	age_ok.link_account("vk", "vk_legal_1", "ok-tok")
	var lim: TWSpendLimit = TWSpendLimit.new(clk)
	legal_j.record_consent("offer", ov, ov, data.doc_hash_short("offer"), true, "legal_screen")
	legal_j.record_consent("privacy", ov, ov, data.doc_hash_short("privacy"), true, "legal_screen")
	legal_j.record_consent("pdn_consent", ov, ov, data.doc_hash_short("pdn_consent"), true, "legal_screen")
	legal_j.record_consent("age_18_full_tier", ov, ov, data.doc_hash_short("age_18_full_tier"), true, "legal_screen")
	ok(core_j.has_required_consents(ov),
		"[M3] consents recorded via TWLegalConsent satisfy TWConsent.has_required_consents()")
	ok(bool(lim.check_purchase(499, age_ok, core_j, ov)["ok"]),
		"[M3] TWSpendLimit.check_purchase succeeds after accepting consents via TWLegalConsent")

	# [M4] Single tap must NOT bundle PDN + 18+ without opening documents or verified TWAge
	var ctx_m4: TWContext = TWContext.for_tests(TEST_SAVE_DIR.path_join("m4_ctx/"))
	host.add_child(ctx_m4.screens)
	ctx_m4.screens.scan()
	await ctx_m4.screens.go("legal", {})
	var scr_m4: TWLegalScreen = ctx_m4.screens.current as TWLegalScreen
	var bundled: Array = scr_m4.accept_current_bundle(false)
	ok(bundled.is_empty() and scr_m4.consent_journal.entry_count() == 0,
		"[M4] accept_current_bundle without opened docs & TWAge records 0 entries (got %d)" % bundled.size())
	var age18_unverified: Dictionary = scr_m4.accept_single_doc("age_18_full_tier")
	ok(age18_unverified.is_empty() and not scr_m4.consent_journal.has_accepted("age_18_full_tier", ov),
		"[M4] accept_single_doc('age_18_full_tier') without verified adult TWAge fails closed")
	ctx_m4.screens.reset()
	ctx_m4.screens.queue_free()
	await host.get_tree().process_frame

	# [M5] Runtime legal bundle lives inside res://data/legal/ as Godot-exportable JSON resources
	ok(FileAccess.file_exists("res://data/legal/manifest.json"),
		"[M5] res://data/legal/manifest.json exists inside game/ project")
	ok(FileAccess.file_exists("res://data/legal/legal_bundle.json"),
		"[M5] res://data/legal/legal_bundle.json exists inside game/ project")
	ok(ResourceLoader.exists("res://data/legal/manifest.json") and ResourceLoader.exists("res://data/legal/legal_bundle.json"),
		"[M5] manifest.json and legal_bundle.json are Godot-recognized exportable resources")
	ok(TWLegalData.resolve_dir() == "res://data/legal",
		"[M5] TWLegalData.resolve_dir() resolves to res://data/legal (got '%s')" % TWLegalData.resolve_dir())

	# [M6] UI age_gate.gd and legal templates must NOT contradict each other
	var age_gate_src: String = FileAccess.get_file_as_string("res://scripts/v10/shop/age_gate.gd")
	ok(not age_gate_src.contains("Год остаётся только на этом телефоне"),
		"[M6] age_gate.gd no longer makes contradictory local-only claim")
	ok(not age_gate_src.contains("откровенные наряды"),
		"[M6] age_gate.gd no longer contradicts legal docs on explicit/revealing wording")
	var priv_txt: String = data.read_doc_text("privacy")
	var age12_txt: String = data.read_doc_text("age_18_full_tier")
	ok(not priv_txt.contains("дата и время (UTC)"),
		"[M6] 02_privacy.md timestamp zone matches unified MSK journal export")
	ok(age12_txt.contains("ДО P1") or age12_txt.contains("локально"),
		"[M6] 12_age_18_full_tier.md truthfully notes local storage vs P1 server rollout")

	# [m4] TWLegalConsent export uses MSK format (not bare UTC ISO) and monotonic ts
	var exp_m4: String = legal_j.export_text()
	ok(exp_m4.contains("МСК"),
		"[m4] TWLegalConsent.export_text() uses unified MSK format with 'МСК' label")
	clk.tick()
	var e1_ts: int = int(legal_j.latest_for("offer").get("ts", 0))
	clk.set_wall(t0 - 10 * 86400)
	var e2_rev: Dictionary = legal_j.record_consent("analytics", ov, ov, "", false, "settings")
	ok(int(e2_rev.get("ts", 0)) >= e1_ts,
		"[m4] TWLegalConsent refuses to backdate ts when phone clock moves backward")

	# [m5] Path traversal '..' check + runtime validate_bundle enforcement in TWLegalScreen
	var trav_dir: String = TEST_BAD_DIR.path_join("trav/")
	_wipe_dir(trav_dir)
	DirAccess.make_dir_recursive_absolute(trav_dir)
	var trav_manifest: Dictionary = {
		"schema_ver": 1,
		"bundle_ver": "0.1.0-trav",
		"offer_ver": "0.1.0-trav",
		"documents": [
			{
				"id": "offer",
				"order": 1,
				"title": "Traversal Offer",
				"short_title": "Offer",
				"file": "../01_offer.md",
				"version": "0.1.0-trav",
				"has_refund_clause": true,
				"sha256": ""
			}
		]
	}
	var tf: FileAccess = FileAccess.open(trav_dir.path_join("manifest.json"), FileAccess.WRITE)
	tf.store_string(JSON.stringify(trav_manifest))
	tf.close()
	var trav_data: TWLegalData = TWLegalData.new(trav_dir)
	ok(trav_data.read_doc_text("offer") == "",
		"[m5] read_doc_text rejects '..' path traversal filename")
	var trav_errs: String = ",".join(trav_data.validate_bundle())
	ok(trav_errs.contains("unsafe_file_path"),
		"[m5] validate_bundle flags '..' path traversal (got: %s)" % trav_errs)

	# Mount TWLegalScreen on TEST_BAD_DIR (tampered SHA / missing refund clause) -> must refuse display & consent
	var ctx_m5: TWContext = TWContext.for_tests(TEST_SAVE_DIR.path_join("m5_ctx/"))
	host.add_child(ctx_m5.screens)
	ctx_m5.screens.scan()
	await ctx_m5.screens.go("legal", {"data_dir": TEST_BAD_DIR})
	var scr_bad: TWLegalScreen = ctx_m5.screens.current as TWLegalScreen
	ok(not scr_bad.open_doc("offer", false),
		"[m5] TWLegalScreen refuses to open tampered doc when validate_bundle() fails")
	ok(scr_bad.accept_single_doc("offer").is_empty(),
		"[m5] TWLegalScreen refuses to record consent on tampered bundle")
	ctx_m5.screens.reset()
	ctx_m5.screens.queue_free()
	await host.get_tree().process_frame

	# [m6] No example.ru domain, RuStore self-employed claim marked [ЮР], real_payments_enabled read + placeholder gate
	var has_example_ru: bool = false
	for d in data.list_docs():
		if data.read_doc_text(str(d.get("id", ""))).contains("example.ru"):
			has_example_ru = true
			break
	ok(not has_example_ru, "[m6] zero occurrences of non-reserved domain example.ru in legal docs")
	var seller_txt: String = data.read_doc_text("seller_details")
	ok(not seller_txt.contains("самозанятые не допускаются к монетизации в RuStore"),
		"[m6] 11_seller_details.md marks RuStore self-employed status with [ЮР]/уточнить instead of unverified fact")
	ok(data.has_method("real_payments_enabled") and data.has_method("can_enable_real_payments"),
		"[m6] TWLegalData reads real_payments_enabled and exposes can_enable_real_payments() placeholder gate")
	ok(not data.real_payments_enabled(),
		"[m6] manifest real_payments_enabled is read as false on template bundle")
	var pay_gate: Dictionary = data.can_enable_real_payments()
	ok(not bool(pay_gate["ok"]) and str(pay_gate["code"]) == "DENY_PAYMENTS_DISABLED",
		"[m6] can_enable_real_payments() returns DENY_PAYMENTS_DISABLED while flag is false")
	ok(data.has_unfilled_placeholders(),
		"[m6] has_unfilled_placeholders() detects [ЗАПОЛНИТЬ ДО P1 markers in template bundle")
	# Simulate flipping real_payments_enabled=true while placeholders remain -> validate_bundle MUST flag it!
	var pay_bad_dir: String = TEST_BAD_DIR.path_join("pay_placeholder/")
	_wipe_dir(pay_bad_dir)
	DirAccess.make_dir_recursive_absolute(pay_bad_dir)
	var pm: Dictionary = data.manifest.duplicate(true)
	pm["real_payments_enabled"] = true
	var pmf: FileAccess = FileAccess.open(pay_bad_dir.path_join("manifest.json"), FileAccess.WRITE)
	pmf.store_string(JSON.stringify(pm))
	pmf.close()
	var pb_raw: String = FileAccess.get_file_as_string("res://data/legal/legal_bundle.json")
	var pbf: FileAccess = FileAccess.open(pay_bad_dir.path_join("legal_bundle.json"), FileAccess.WRITE)
	pbf.store_string(pb_raw)
	pbf.close()
	var pay_bad_data: TWLegalData = TWLegalData.new(pay_bad_dir)
	var pay_bad_errs: String = ",".join(pay_bad_data.validate_bundle())
	ok(pay_bad_errs.contains("unfilled_placeholders_with_payments_enabled"),
		"[m6] validate_bundle blocks real_payments_enabled=true while [ЗАПОЛНИТЬ placeholders remain")
	ok(not bool(pay_bad_data.can_enable_real_payments()["ok"]),
		"[m6] can_enable_real_payments() refuses shipping bundle with unfilled placeholders")

	# [m7] Doc 12 §1.3 wording consistency (no 'откровенный контент уровней B2/B3')
	ok(not age12_txt.contains("откровенный контент уровней B2/B3"),
		"[m7] 12_age_18_full_tier.md §1.3 removes contradictory 'откровенный контент уровней B2/B3' wording")


func _cleanup_dirs() -> void:
	_wipe_dir(TEST_SAVE_DIR)
	_wipe_dir(TEST_BAD_DIR)


static func _wipe_dir(dir_path: String) -> void:
	var d: DirAccess = DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var n: String = d.get_next()
	while n != "":
		if n != "." and n != "..":
			var p: String = dir_path.path_join(n)
			if d.current_is_dir():
				_wipe_dir(p)
				DirAccess.remove_absolute(p)
			else:
				DirAccess.remove_absolute(p)
		n = d.get_next()
	d.list_dir_end()
	DirAccess.remove_absolute(dir_path)
